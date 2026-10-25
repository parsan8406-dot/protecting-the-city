package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// =============================================================================
// پاداش هفتگی رتبه‌بندی
// =============================================================================
//
// هر هفته فقط سه نفر اول جدول «رتبه کلی» پاداش می‌گیرند: جم، تجربه و مقدار
// زیادی سکه. هفته شنبه ساعت ۰۰:۰۰ (همان منطقه‌ی زمانی ریست ماموریت‌ها)
// شروع می‌شود؛ لحظه‌ی شروع هفته‌ی جدید، سه نفر اول جدول برنده‌ی هفته‌ی قبل‌اند.
//
// پاداش به صورت پیام قابل دریافت در صندوق پیام برنده می‌نشیند
// (/messages/claim) — همان راهی که هدیه‌ها و دستاوردها می‌رسند.
//
// اجرای دوباره بی‌خطر است:
//   - هر هفته یک رکورد با _id = کلید هفته در weekly_rewards دارد؛ درج آن اتمیک
//     است، پس حتی با چند نسخه‌ی سرور فقط یکی برنده‌ها را ثبت می‌کند.
//   - برنده‌ها همان لحظه در رکورد ذخیره می‌شوند و پیام هر برنده شناسه‌ی ثابت
//     weekly_<هفته>_<رتبه> دارد (message_id یکتاست). اگر وسط واریز خطا شد،
//     تیک بعدی همان برنده‌ها را دوباره می‌فرستد و پیام تکراری ساخته نمی‌شود.
//   - اولین باری که سرور روی یک دیتابیس خالی بالا می‌آید فقط هفته‌ی جاری را
//     علامت می‌زند و چیزی نمی‌دهد، چون هفته‌ی قبلش اصلاً ثبت نشده بود.

// WeeklyReward پاداش یک رتبه در پایان هفته
type WeeklyReward struct {
	Position int `json:"position" bson:"position"`
	Gems     int `json:"gems" bson:"gems"`
	XP       int `json:"xp" bson:"xp"`
	Coins    int `json:"coins" bson:"coins"`
}

// WeeklyRewards پاداش سه نفر اول جدول کلی — تنها منبع این اعداد.
// کلاینت همین لیست را در /leaderboard → weekly_rewards می‌گیرد.
var WeeklyRewards = []WeeklyReward{
	{Position: 1, Gems: 500, XP: 5000, Coins: 50000},
	{Position: 2, Gems: 300, XP: 3000, Coins: 30000},
	{Position: 3, Gems: 150, XP: 1500, Coins: 15000},
}

// WeeklyRewardCheckEvery هر چند وقت یک بار شروع هفته‌ی جدید چک شود
const WeeklyRewardCheckEvery = 5 * time.Minute

// وضعیت رکورد هفتگی
const (
	weeklyStatusPaying = "paying" // برنده‌ها ثبت شده‌اند، پیام‌ها هنوز کامل نرفته‌اند
	weeklyStatusDone   = "done"
)

// WeeklyRewardWinner یک برنده‌ی هفته
type WeeklyRewardWinner struct {
	Position int    `bson:"position"`
	PlayerID string `bson:"player_id"`
	Username string `bson:"username"`
	Trophies int    `bson:"trophies"`
}

// WeeklyRewardRun رکورد پرداخت یک هفته (کالکشن weekly_rewards)
type WeeklyRewardRun struct {
	WeekKey   string               `bson:"_id"` // تاریخ شنبه‌ی شروع هفته: "2026-09-12"
	Status    string               `bson:"status"`
	Baseline  bool                 `bson:"baseline,omitempty"` // اولین اجرا — پرداختی نداشت
	Winners   []WeeklyRewardWinner `bson:"winners"`
	CreatedAt time.Time            `bson:"created_at"`
	DoneAt    *time.Time           `bson:"done_at,omitempty"`
}

// weekStart شروع هفته‌ی جاری: شنبه ۰۰:۰۰ به وقت ریست ماموریت‌ها
func weekStart(now time.Time) time.Time {
	local := now.In(missionsLocation)
	back := (int(local.Weekday()) - int(time.Saturday) + 7) % 7
	day := time.Date(local.Year(), local.Month(), local.Day(), 0, 0, 0, 0, missionsLocation)
	return day.AddDate(0, 0, -back)
}

// weekKey کلید هفته‌ی جاری ("2026-09-12")
func weekKey(now time.Time) string {
	return weekStart(now).Format("2006-01-02")
}

// weekSummary زمان پایان هفته‌ی جاری برای کارت «پایان هفته» در کلاینت
func weekSummary(now time.Time) map[string]interface{} {
	end := weekStart(now).AddDate(0, 0, 7)
	left := int(end.Sub(now).Seconds())
	if left < 0 {
		left = 0
	}
	return map[string]interface{}{
		"week_key":     weekKey(now),
		"ends_at":      end.UTC().Format(time.RFC3339),
		"seconds_left": left,
	}
}

// weeklyRewardFor پاداش یک رتبه؛ false یعنی این رتبه پاداش ندارد
func weeklyRewardFor(position int) (WeeklyReward, bool) {
	for _, r := range WeeklyRewards {
		if r.Position == position {
			return r, true
		}
	}
	return WeeklyReward{}, false
}

// StartWeeklyRewardLoop یک بار همین حالا و بعد هر WeeklyRewardCheckEvery
// چک می‌کند هفته‌ی جدید شروع شده یا نه
func StartWeeklyRewardLoop() {
	go func() {
		runWeeklyRewards(time.Now())
		ticker := time.NewTicker(WeeklyRewardCheckEvery)
		defer ticker.Stop()
		for now := range ticker.C {
			runWeeklyRewards(now)
		}
	}()
}

func runWeeklyRewards(now time.Time) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	key := weekKey(now)
	var run WeeklyRewardRun
	err := col(ColWeeklyRewards).FindOne(ctx, bson.M{"_id": key}).Decode(&run)
	if errors.Is(err, mongo.ErrNoDocuments) {
		run, err = createWeeklyRun(ctx, key, now)
	}
	if err != nil {
		log.Printf("⚠️ weekly rewards %s: %v", key, err)
		return
	}
	if run.Status == weeklyStatusDone {
		return
	}
	if err := payWeeklyRun(ctx, &run); err != nil {
		log.Printf("⚠️ weekly rewards %s: %v (retrying next tick)", key, err)
	}
}

// createWeeklyRun برنده‌های هفته‌ای که همین حالا تمام شد را ثبت می‌کند
func createWeeklyRun(ctx context.Context, key string, now time.Time) (WeeklyRewardRun, error) {
	run := WeeklyRewardRun{WeekKey: key, Status: weeklyStatusPaying, CreatedAt: now, Winners: []WeeklyRewardWinner{}}

	previous, err := col(ColWeeklyRewards).CountDocuments(ctx, bson.M{})
	if err != nil {
		return run, err
	}
	if previous == 0 {
		// اولین اجرا: هفته‌ی قبل ثبت نشده بود، پس کسی برنده نیست
		run.Status = weeklyStatusDone
		run.Baseline = true
		run.DoneAt = &now
	} else {
		winners, err := weeklyWinners(ctx)
		if err != nil {
			return run, err
		}
		run.Winners = winners
	}

	if _, err := col(ColWeeklyRewards).InsertOne(ctx, run); err != nil {
		if !mongo.IsDuplicateKeyError(err) {
			return run, err
		}
		// نسخه‌ی دیگری از سرور زودتر ثبت کرد — همان را ادامه می‌دهیم
		var existing WeeklyRewardRun
		if err := col(ColWeeklyRewards).FindOne(ctx, bson.M{"_id": key}).Decode(&existing); err != nil {
			return run, err
		}
		return existing, nil
	}
	return run, nil
}

// weeklyWinners سه نفر اول جدول کلی با همان ترتیب /leaderboard
func weeklyWinners(ctx context.Context) ([]WeeklyRewardWinner, error) {
	cursor, err := col(ColPlayers).Find(ctx, playerLeaderboardFilter("global", nil),
		options.Find().
			SetSort(leaderboardSort).
			SetLimit(int64(len(WeeklyRewards))).
			SetProjection(bson.M{"player_id": 1, "username": 1, "trophies": 1}))
	if err != nil {
		return nil, err
	}
	var players []PlayerModel
	if err := cursor.All(ctx, &players); err != nil {
		return nil, err
	}

	winners := make([]WeeklyRewardWinner, 0, len(players))
	for i, p := range players {
		winners = append(winners, WeeklyRewardWinner{
			Position: i + 1, PlayerID: p.PlayerID, Username: p.Username, Trophies: p.Trophies,
		})
	}
	return winners, nil
}

// payWeeklyRun پیام پاداش هر برنده را می‌فرستد و رکورد را «تمام» می‌کند
func payWeeklyRun(ctx context.Context, run *WeeklyRewardRun) error {
	expires := time.Now().AddDate(0, 0, 30)
	for _, winner := range run.Winners {
		reward, ok := weeklyRewardFor(winner.Position)
		if !ok {
			continue
		}
		err := insertMessage(ctx, MessageModel{
			MessageID:   fmt.Sprintf("weekly_%s_%d", run.WeekKey, winner.Position),
			RecipientID: winner.PlayerID,
			SenderID:    "system",
			SenderName:  "بازی",
			Type:        MsgTypeReward,
			Title:       fmt.Sprintf("پاداش هفتگی — رتبه %s", persianDigits(winner.Position)),
			Body: fmt.Sprintf("تبریک! هفته را در رتبه %s جدول کلی تمام کردی. پاداشت را دریافت کن.",
				persianDigits(winner.Position)),
			Reward:    &MessageReward{Coins: reward.Coins, Gems: reward.Gems, XP: reward.XP},
			ExpiresAt: &expires,
		})
		if err != nil && !mongo.IsDuplicateKeyError(err) {
			return err
		}
		if err == nil {
			NotifyUser(winner.Username, map[string]interface{}{
				"type": "notification",
				"kind": MsgTypeReward,
			})
		}
	}

	now := time.Now()
	_, err := col(ColWeeklyRewards).UpdateOne(ctx, bson.M{"_id": run.WeekKey},
		bson.M{"$set": bson.M{"status": weeklyStatusDone, "done_at": now}})
	return err
}

// persianDigits عدد با رقم‌های فارسی (۱، ۲، ۳)
func persianDigits(n int) string {
	digits := []rune("۰۱۲۳۴۵۶۷۸۹")
	out := []rune{}
	for _, r := range fmt.Sprintf("%d", n) {
		if r >= '0' && r <= '9' {
			out = append(out, digits[r-'0'])
		} else {
			out = append(out, r)
		}
	}
	return string(out)
}
