package main

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// =============================================================================
// پیام کاربر به سازنده‌ی بازی (تنظیمات → دکمه «ارسال پیام»)
//
// کاربر اندرویدی باکس را باز می‌کند، با کیبورد گوشی متن را می‌نویسد و «ثبت»
// را می‌زند. پیام همراه نام کاربری‌اش در کالکشن support_messages ذخیره می‌شود.
// =============================================================================

const (
	supportMinLength = 5
	supportMaxLength = 1000
	// حداکثر تعداد پیام هر کاربر در بازه‌ی زیر — جلوی اسپم را می‌گیرد
	supportRateWindow = 10 * time.Minute
	supportRateLimit  = 5
)

// sendSupportMessageHandler ثبت پیام کاربر
// POST /support/message   بدنه: {"username": "...", "body": "..."}
func sendSupportMessageHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req SupportMessageBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "بدنه‌ی درخواست نامعتبر است", http.StatusBadRequest)
		return
	}

	req.Username = strings.TrimSpace(req.Username)
	req.Body = strings.TrimSpace(req.Body)

	if req.Username == "" {
		httpError(w, "یوزرنیم ارسال نشده", http.StatusBadRequest)
		return
	}
	if len([]rune(req.Body)) < supportMinLength {
		httpError(w, "متن پیام خیلی کوتاه است", http.StatusBadRequest)
		return
	}
	if len([]rune(req.Body)) > supportMaxLength {
		req.Body = string([]rune(req.Body)[:supportMaxLength])
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	// بازیکن باید واقعاً وجود داشته باشد — جلوی پیام با نام جعلی را می‌گیرد
	player, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	// ضد اسپم: چند پیام در چند دقیقه‌ی اخیر
	since := time.Now().Add(-supportRateWindow)
	recent, err := col(ColSupportMsgs).CountDocuments(ctx, bson.M{
		"player_id":  player.PlayerID,
		"created_at": bson.M{"$gte": since},
	})
	if err == nil && recent >= supportRateLimit {
		httpError(w, "تعداد پیام‌هایت زیاد شد — کمی بعد دوباره امتحان کن", http.StatusTooManyRequests)
		return
	}

	ticket := SupportMessageModel{
		TicketID:   newID("ticket"),
		Username:   player.Username,
		PlayerID:   player.PlayerID,
		Body:       req.Body,
		Platform:   strings.TrimSpace(req.Platform),
		AppVersion: strings.TrimSpace(req.AppVersion),
		Status:     SupportStatusNew,
		CreatedAt:  time.Now(),
	}

	if _, err := col(ColSupportMsgs).InsertOne(ctx, ticket); err != nil {
		httpError(w, "ذخیره‌ی پیام ناموفق بود", http.StatusInternalServerError)
		return
	}

	jsonResponse(w, map[string]interface{}{
		"success":   true,
		"ticket_id": ticket.TicketID,
	})
}

// listSupportMessagesHandler لیست پیام‌های رسیده — نمای سازنده
// GET /support/messages?status=new&username=&limit=50
func listSupportMessagesHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	filter := bson.M{}
	if status := r.URL.Query().Get("status"); status != "" {
		filter["status"] = status
	}
	if username := r.URL.Query().Get("username"); username != "" {
		filter["username"] = username
	}

	limit := int64(50)
	if raw := r.URL.Query().Get("limit"); raw != "" {
		if parsed, err := strconv.ParseInt(raw, 10, 64); err == nil && parsed > 0 && parsed <= 500 {
			limit = parsed
		}
	}

	cursor, err := col(ColSupportMsgs).Find(ctx, filter,
		options.Find().SetSort(bson.D{{Key: "created_at", Value: -1}}).SetLimit(limit))
	if err != nil {
		httpError(w, "خطا در خواندن پیام‌ها", http.StatusInternalServerError)
		return
	}
	defer cursor.Close(ctx)

	tickets := []SupportMessageModel{}
	_ = cursor.All(ctx, &tickets)

	unread, _ := col(ColSupportMsgs).CountDocuments(ctx, bson.M{"status": SupportStatusNew})

	jsonResponse(w, map[string]interface{}{
		"messages":     tickets,
		"unread_count": unread,
	})
}
