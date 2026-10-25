package main

import (
	"context"
	"crypto/rand"
	"encoding/json"
	"math/big"
	"net/http"
	"strings"
	"sync"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
)

// =============================================================================
// کد هدیه
// =============================================================================
//
// هر کد یک داکیومنت در gift_codes است که _id آن خودِ کد (حروف بزرگ) است.
// هر بازیکن هر کد را فقط یک بار می‌تواند استفاده کند: _id رکورد
// gift_code_redemptions برابر «کد:آیدی بازیکن» است و یکتایی را خودِ Mongo
// تضمین می‌کند، پس دو تپ هم‌زمان نمی‌تواند دو بار جایزه بگیرد.
//
// ساخت کد (فقط با کلید سرور):
//   POST /admin/gift_codes/create   header: X-Server-Key
//   {"code":"NOROOZ1405","coins":5000,"gems":50,"max_uses":1000,"expires_in_hours":72}
// code خالی = کد تصادفی ۸ حرفی. max_uses صفر = نامحدود.

const (
	ColGiftCodes       = "gift_codes"
	ColGiftRedemptions = "gift_code_redemptions"

	giftCodeMaxLen = 32
	// جلوی حدس‌زدن کد: بیشتر از این تعداد تلاش ناموفق در پنجره‌ی زمانی رد می‌شود
	giftCodeMaxFails   = 8
	giftCodeFailWindow = 10 * time.Minute
)

type GiftCode struct {
	Code      string     `bson:"_id" json:"code"`
	Coins     int        `bson:"coins" json:"coins"`
	Gems      int        `bson:"gems" json:"gems"`
	MaxUses   int        `bson:"max_uses" json:"max_uses"`
	Uses      int        `bson:"uses" json:"uses"`
	Active    bool       `bson:"active" json:"active"`
	ExpiresAt *time.Time `bson:"expires_at,omitempty" json:"expires_at,omitempty"`
	CreatedAt time.Time  `bson:"created_at" json:"created_at"`
}

func normalizeGiftCode(code string) string {
	return strings.ToUpper(strings.TrimSpace(code))
}

// ------------------------------------------------------------ محدودیت تلاش

type giftFailLimiter struct {
	mu    sync.Mutex
	fails map[string][]time.Time
}

var giftFails = &giftFailLimiter{fails: map[string][]time.Time{}}

func (l *giftFailLimiter) blocked(user string, now time.Time) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	recent := l.fails[user][:0]
	for _, t := range l.fails[user] {
		if now.Sub(t) < giftCodeFailWindow {
			recent = append(recent, t)
		}
	}
	if len(recent) == 0 {
		delete(l.fails, user)
		return false
	}
	l.fails[user] = recent
	return len(recent) >= giftCodeMaxFails
}

func (l *giftFailLimiter) fail(user string, now time.Time) {
	l.mu.Lock()
	l.fails[user] = append(l.fails[user], now)
	l.mu.Unlock()
}

// ------------------------------------------------------------ استفاده از کد

type redeemGiftCodeRequest struct {
	Username string `json:"username"`
	Code     string `json:"code"`
}

// redeemGiftCodeHandler
// POST /gift_code/redeem  {"username","code"}
func redeemGiftCodeHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req redeemGiftCodeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Username == "" {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}
	code := normalizeGiftCode(req.Code)
	if code == "" || len(code) > giftCodeMaxLen {
		httpError(w, "کد را درست وارد کن", http.StatusBadRequest)
		return
	}

	now := time.Now()
	if giftFails.blocked(req.Username, now) {
		httpError(w, "تلاش‌های زیادی کردی، چند دقیقه بعد دوباره امتحان کن", http.StatusTooManyRequests)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	var player PlayerModel
	if err := col(ColPlayers).FindOne(ctx, bson.M{"username": req.Username}).Decode(&player); err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	var gift GiftCode
	err := col(ColGiftCodes).FindOne(ctx, bson.M{"_id": code}).Decode(&gift)
	if err != nil || !gift.Active {
		giftFails.fail(req.Username, now)
		httpError(w, "این کد معتبر نیست", http.StatusNotFound)
		return
	}
	if gift.ExpiresAt != nil && now.After(*gift.ExpiresAt) {
		httpError(w, "مهلت این کد تمام شده", http.StatusGone)
		return
	}

	// ۱. رزرو «یک بار برای هر بازیکن»
	redemptionID := code + ":" + player.PlayerID
	_, err = col(ColGiftRedemptions).InsertOne(ctx, bson.M{
		"_id":        redemptionID,
		"code":       code,
		"player_id":  player.PlayerID,
		"coins":      gift.Coins,
		"gems":       gift.Gems,
		"created_at": now,
	})
	if mongo.IsDuplicateKeyError(err) {
		httpError(w, "این کد را قبلاً استفاده کردی", http.StatusConflict)
		return
	}
	if err != nil {
		httpError(w, "خطا در ثبت کد", http.StatusInternalServerError)
		return
	}
	undo := func() { _, _ = col(ColGiftRedemptions).DeleteOne(context.Background(), bson.M{"_id": redemptionID}) }

	// ۲. مصرف ظرفیت کد (اتمیک)
	capFilter := bson.M{"_id": code, "active": true}
	if gift.MaxUses > 0 {
		capFilter["uses"] = bson.M{"$lt": gift.MaxUses}
	}
	res, err := col(ColGiftCodes).UpdateOne(ctx, capFilter, bson.M{"$inc": bson.M{"uses": 1}})
	if err != nil {
		undo()
		httpError(w, "خطا در ثبت کد", http.StatusInternalServerError)
		return
	}
	if res.MatchedCount == 0 {
		undo()
		httpError(w, "ظرفیت این کد تمام شده", http.StatusGone)
		return
	}

	// ۳. جایزه
	if _, err := col(ColPlayers).UpdateOne(ctx, bson.M{"player_id": player.PlayerID},
		bson.M{"$inc": bson.M{"coins": gift.Coins, "gems": gift.Gems}}); err != nil {
		undo()
		_, _ = col(ColGiftCodes).UpdateOne(context.Background(), bson.M{"_id": code}, bson.M{"$inc": bson.M{"uses": -1}})
		httpError(w, "خطا در واریز جایزه", http.StatusInternalServerError)
		return
	}

	jsonResponse(w, map[string]interface{}{
		"success": true,
		"code":    code,
		"reward":  map[string]int{"coins": gift.Coins, "gems": gift.Gems},
		"coins":   player.Coins + gift.Coins,
		"gems":    player.Gems + gift.Gems,
	})
}

// ------------------------------------------------------------ ساخت کد (ادمین)

type createGiftCodeRequest struct {
	Code           string `json:"code"`
	Coins          int    `json:"coins"`
	Gems           int    `json:"gems"`
	MaxUses        int    `json:"max_uses"`
	ExpiresInHours int    `json:"expires_in_hours"`
}

// giftCodeAlphabet بدون حروف گیج‌کننده (O/0، I/1)
const giftCodeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

func randomGiftCode(n int) string {
	b := make([]byte, n)
	for i := range b {
		idx, _ := rand.Int(rand.Reader, big.NewInt(int64(len(giftCodeAlphabet))))
		b[i] = giftCodeAlphabet[idx.Int64()]
	}
	return string(b)
}

// createGiftCode ساختِ کد — مشترک بین مسیرِ کلید سرور و پنل مدیریت.
// پیام خطا و کد HTTP را برمی‌گرداند؛ پیام خالی یعنی موفق.
func createGiftCode(ctx context.Context, req createGiftCodeRequest) (GiftCode, string, int) {
	if req.Coins < 0 || req.Gems < 0 || req.Coins+req.Gems == 0 || req.MaxUses < 0 {
		return GiftCode{}, "جایزه‌ی کد نامعتبر است", http.StatusBadRequest
	}
	code := normalizeGiftCode(req.Code)
	if code == "" {
		code = randomGiftCode(8)
	}
	if len(code) > giftCodeMaxLen {
		return GiftCode{}, "کد خیلی طولانی است", http.StatusBadRequest
	}
	gift := GiftCode{
		Code:      code,
		Coins:     req.Coins,
		Gems:      req.Gems,
		MaxUses:   req.MaxUses,
		Active:    true,
		CreatedAt: time.Now(),
	}
	if req.ExpiresInHours > 0 {
		exp := gift.CreatedAt.Add(time.Duration(req.ExpiresInHours) * time.Hour)
		gift.ExpiresAt = &exp
	}
	if _, err := col(ColGiftCodes).InsertOne(ctx, gift); err != nil {
		if mongo.IsDuplicateKeyError(err) {
			return GiftCode{}, "این کد از قبل وجود دارد", http.StatusConflict
		}
		return GiftCode{}, "خطا در ساخت کد", http.StatusInternalServerError
	}
	return gift, "", http.StatusOK
}

// createGiftCodeHandler
// POST /admin/gift_codes/create (X-Server-Key)
func createGiftCodeHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}
	var req createGiftCodeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	gift, msg, status := createGiftCode(ctx, req)
	if msg != "" {
		httpError(w, msg, status)
		return
	}
	jsonResponse(w, gift)
}
