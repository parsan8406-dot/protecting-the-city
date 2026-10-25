package main

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
)

// =============================================================================
// جایزه‌ی دیدن تبلیغ
// =============================================================================
//
// کلاینت بعد از اینکه SDK تبلیغ گفت «ویدیو کامل دیده شد»، این‌جا را صدا
// می‌زند. چون تبلیغ سمت گوشی نمایش داده می‌شود، سرور نمی‌تواند ۱۰۰٪ مطمئن
// شود؛ برای همین جایزه سقف روزانه و فاصله‌ی حداقلی دارد تا حتی با درخواست
// جعلی هم نشود بیشتر از سقف روزانه قلب گرفت. توکن تبلیغ هم ذخیره می‌شود
// تا یک تبلیغ دو بار جایزه ندهد.
//
// روی اندروید تبلیغ توی یک Activity جدا باز می‌شود و همان لحظه که بسته
// می‌شود اولین درخواست کلاینت ممکن است به سرور نرسد؛ کلاینت همان توکن را
// بعداً دوباره می‌فرستد. پس این هندلر idempotent است: توکنی که قبلاً جایزه
// گرفته، جواب ۲۰۰ با already_credited می‌گیرد نه خطا.
//
// یک رکورد برای هر بازیکن در هر روز: _id = «آیدی بازیکن:روز»

const (
	ColAdRewards = "ad_rewards"

	adRewardGems       = 10
	adRewardDailyLimit = 10
	adRewardCooldown   = 30 * time.Second
)

type adRewardDay struct {
	ID     string    `bson:"_id"`
	Count  int       `bson:"count"`
	LastAt time.Time `bson:"last_at"`
}

type adRewardRequest struct {
	Username string `json:"username"`
	Provider string `json:"provider"`
	AdToken  string `json:"ad_token"`
}

func adRewardStatus(ctx context.Context, playerID string, now time.Time) (remaining int, cooldownLeft int) {
	var day adRewardDay
	err := col(ColAdRewards).FindOne(ctx, bson.M{"_id": playerID + ":" + missionDayKey(now)}).Decode(&day)
	if err != nil {
		return adRewardDailyLimit, 0
	}
	remaining = adRewardDailyLimit - day.Count
	if remaining < 0 {
		remaining = 0
	}
	if left := adRewardCooldown - now.Sub(day.LastAt); left > 0 {
		cooldownLeft = int(left.Seconds()) + 1
	}
	return remaining, cooldownLeft
}

// adTokenRewarded می‌گوید جایزه‌ی این توکن امروز قبلاً داده شده یا نه.
func adTokenRewarded(ctx context.Context, dayID, token string) bool {
	if token == "" {
		return false
	}
	n, err := col(ColAdRewards).CountDocuments(ctx, bson.M{"_id": dayID, "tokens": token})
	return err == nil && n > 0
}

// adAlreadyCredited جواب موفقِ یک درخواست تکراری: جایزه دوباره حساب نمی‌شود
// ولی کلاینت ۲۰۰ می‌گیرد تا توکن معلقش را پاک کند و دوباره نفرستد.
func adAlreadyCredited(ctx context.Context, w http.ResponseWriter, player PlayerModel, now time.Time) {
	remaining, cooldown := adRewardStatus(ctx, player.PlayerID, now)
	jsonResponse(w, map[string]interface{}{
		"success":          true,
		"already_credited": true,
		"reward":           map[string]int{"gems": adRewardGems},
		"coins":            player.Coins,
		"gems":             player.Gems,
		"remaining":        remaining,
		"cooldown_left":    cooldown,
	})
}

// adRewardStatusHandler
// GET /ads/reward/status?username=
func adRewardStatusHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	username := r.URL.Query().Get("username")
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	var player PlayerModel
	if err := col(ColPlayers).FindOne(ctx, bson.M{"username": username}).Decode(&player); err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}
	remaining, cooldown := adRewardStatus(ctx, player.PlayerID, time.Now())
	jsonResponse(w, map[string]interface{}{
		"reward_gems":   adRewardGems,
		"daily_limit":   adRewardDailyLimit,
		"remaining":     remaining,
		"cooldown_left": cooldown,
	})
}

// adRewardClaimHandler
// POST /ads/reward/claim {"username","provider","ad_token"}
func adRewardClaimHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req adRewardRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Username == "" || len(req.AdToken) > 256 {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	var player PlayerModel
	if err := col(ColPlayers).FindOne(ctx, bson.M{"username": req.Username}).Decode(&player); err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	now := time.Now()
	dayID := player.PlayerID + ":" + missionDayKey(now)
	days := col(ColAdRewards)

	// همین توکن قبلاً جایزه گرفته — تلاش دوباره‌ی کلاینت بعد از قطعی شبکه
	if adTokenRewarded(ctx, dayID, req.AdToken) {
		adAlreadyCredited(ctx, w, player, now)
		return
	}

	// شمارنده‌ی روز را فقط وقتی جلو می‌برد که سقف و فاصله رعایت شده باشد
	filter := bson.M{
		"_id":     dayID,
		"count":   bson.M{"$lt": adRewardDailyLimit},
		"last_at": bson.M{"$lte": now.Add(-adRewardCooldown)},
	}
	update := bson.M{
		"$inc": bson.M{"count": 1},
		"$set": bson.M{"last_at": now},
	}
	if req.AdToken != "" {
		filter["tokens"] = bson.M{"$ne": req.AdToken}
		update["$push"] = bson.M{"tokens": req.AdToken}
	}

	res, err := days.UpdateOne(ctx, filter, update)
	if err != nil {
		httpError(w, "خطای دیتابیس", http.StatusInternalServerError)
		return
	}
	if res.MatchedCount == 0 {
		// شاید اولین تبلیغ امروز است
		doc := bson.M{"_id": dayID, "count": 1, "last_at": now, "player_id": player.PlayerID}
		if req.AdToken != "" {
			doc["tokens"] = []string{req.AdToken}
		}
		if _, err := days.InsertOne(ctx, doc); err != nil {
			if !mongo.IsDuplicateKeyError(err) {
				httpError(w, "خطای دیتابیس", http.StatusInternalServerError)
				return
			}
			// بین دو تلاشِ هم‌زمانِ همین توکن، آن یکی برنده شده
			if adTokenRewarded(ctx, dayID, req.AdToken) {
				adAlreadyCredited(ctx, w, player, now)
				return
			}
			remaining, cooldown := adRewardStatus(ctx, player.PlayerID, now)
			switch {
			case remaining <= 0:
				httpError(w, "سقف جایزه‌ی تبلیغ امروز پر شده، فردا دوباره بیا", http.StatusTooManyRequests)
			case cooldown > 0:
				httpError(w, "کمی صبر کن و دوباره امتحان کن", http.StatusTooManyRequests)
			default:
				httpError(w, "جایزه‌ی این تبلیغ قبلاً داده شده", http.StatusConflict)
			}
			return
		}
	}

	if _, err := col(ColPlayers).UpdateOne(ctx, bson.M{"player_id": player.PlayerID},
		bson.M{"$inc": bson.M{"gems": adRewardGems}}); err != nil {
		// توکن هم باید آزاد شود وگرنه تلاش دوباره‌ی کلاینت «تکراری» حساب
		// می‌شود و جایزه برای همیشه می‌سوزد
		rollback := bson.M{"$inc": bson.M{"count": -1}}
		if req.AdToken != "" {
			rollback["$pull"] = bson.M{"tokens": req.AdToken}
		}
		_, _ = days.UpdateOne(context.Background(), bson.M{"_id": dayID}, rollback)
		httpError(w, "خطا در واریز جایزه", http.StatusInternalServerError)
		return
	}

	remaining, cooldown := adRewardStatus(ctx, player.PlayerID, now)
	jsonResponse(w, map[string]interface{}{
		"success":       true,
		"reward":        map[string]int{"gems": adRewardGems},
		"coins":         player.Coins,
		"gems":          player.Gems + adRewardGems,
		"remaining":     remaining,
		"cooldown_left": cooldown,
	})
}
