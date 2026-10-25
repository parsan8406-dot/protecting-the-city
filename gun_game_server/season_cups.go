package main

import (
	"context"
	"sort"
	"sync"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// =============================================================================
// کاپ‌های فصل — منبع حقیقت: کالکشن season_cups در دیتابیس
//
// قبلاً لیست کاپ‌ها داخل scripts/rank_screen.gd هاردکد بود و دکمه‌ی «دریافت»
// هیچ اندپوینتی نداشت. یعنی هر کسی می‌توانست با دست بردن در کلاینت، کاپ‌ها را
// باز نشان بدهد. حالا:
//
//   ۱) تعریف کاپ‌ها (اسم، تجربه‌ی لازم، جایزه) فقط از دیتابیس می‌آید
//   ۲) تجربه‌ی فصل هم فقط از سند بازیکن خوانده می‌شود، نه از بدنه‌ی درخواست
//   ۳) گرفتن جایزه با یک آپدیت شرطیِ اتمیک انجام می‌شود تا دوبار گرفته نشود
//
// کلاینت فقط نمایش می‌دهد؛ هیچ عددی از سمت او پذیرفته نمی‌شود.
// =============================================================================

// SeasonCupPerSeason تعداد کاپ‌های هر فصل (شبکه‌ی صفحه‌ی رنک ۶ خانه دارد)
const SeasonCupPerSeason = 6

// seasonCupCacheTTL کاپ‌ها کاتالوگ‌اند و کم عوض می‌شوند؛ برای اینکه هر ردیفِ
// جدول رتبه‌بندی یک کوئری نزند، نتیجه چند ثانیه کش می‌شود.
const seasonCupCacheTTL = 60 * time.Second

var (
	seasonCupMu      sync.RWMutex
	seasonCupCache   []SeasonCupDef
	seasonCupCacheAt time.Time
)

// defaultSeasonCups کاپ‌های پیش‌فرض یک فصل.
//
// این فقط بذرِ اولیه‌ی کالکشن است — بعد از seed، دیتابیس منبع حقیقت است و
// عوض کردن اعداد اینجا روی فصلی که قبلاً ساخته شده اثری ندارد.
func defaultSeasonCups(seasonID string) []SeasonCupDef {
	rows := []struct {
		name  string
		xp    int
		coins int
		gems  int
	}{
		{"کاپ ۰۱", 250, 500, 0},
		{"کاپ ۰۲", 750, 900, 10},
		{"کاپ ۰۳", 1500, 1500, 15},
		{"کاپ ۰۴", 3000, 2500, 25},
		{"کاپ ۰۵", 6000, 4000, 40},
		{"کاپ ۰۶", 12000, 7500, 80},
	}

	cups := make([]SeasonCupDef, 0, len(rows))
	for i, r := range rows {
		cups = append(cups, SeasonCupDef{
			CupID:       seasonCupID(i + 1),
			SeasonID:    seasonID,
			Name:        r.name,
			XPRequired:  r.xp,
			RewardCoins: r.coins,
			RewardGems:  r.gems,
			Icon:        "cup",
			SortOrder:   i + 1,
		})
	}
	return cups
}

// seasonCupID شناسه‌ی ثابت کاپ شماره‌ی n ("cup_01")
func seasonCupID(n int) string {
	if n < 10 {
		return "cup_0" + string(rune('0'+n))
	}
	return "cup_" + string(rune('0'+n/10)) + string(rune('0'+n%10))
}

// seedSeasonCups کاپ‌های فصل جاری را یک بار داخل دیتابیس می‌نویسد.
// با $setOnInsert کار می‌کند تا اگر ادمین بعداً جایزه‌ای را در دیتابیس عوض
// کرد، ری‌استارت سرور آن را به مقدار کد برنگرداند.
func seedSeasonCups(ctx context.Context) error {
	for _, cup := range defaultSeasonCups(DefaultSeasonID) {
		filter := bson.M{"season_id": cup.SeasonID, "cup_id": cup.CupID}
		update := bson.M{"$setOnInsert": bson.M{
			"cup_id":       cup.CupID,
			"season_id":    cup.SeasonID,
			"name":         cup.Name,
			"xp_required":  cup.XPRequired,
			"reward_coins": cup.RewardCoins,
			"reward_gems":  cup.RewardGems,
			"icon":         cup.Icon,
			"sort_order":   cup.SortOrder,
		}}
		if _, err := col(ColSeasonCups).UpdateOne(ctx, filter, update,
			options.Update().SetUpsert(true)); err != nil {
			return err
		}
	}

	// کش را باطل می‌کنیم تا اولین درخواست، لیستِ تازه‌ی دیتابیس را بخواند
	invalidateSeasonCupCache()
	return nil
}

// invalidateSeasonCupCache کش کاتالوگ را دور می‌ریزد (بعد از seed یا تغییر
// دستی کاپ‌ها در دیتابیس)
func invalidateSeasonCupCache() {
	seasonCupMu.Lock()
	seasonCupCache = nil
	seasonCupCacheAt = time.Time{}
	seasonCupMu.Unlock()
}

// seasonCupDefs کاپ‌های فصل جاری را از دیتابیس می‌دهد (مرتب‌شده).
//
// اگر دیتابیس جواب نداد، آخرین لیستِ کش‌شده و در نهایت لیست پیش‌فرض
// برگردانده می‌شود تا صفحه‌ی رنک خالی نماند.
func seasonCupDefs(ctx context.Context) []SeasonCupDef {
	seasonCupMu.RLock()
	cached := seasonCupCache
	freshUntil := seasonCupCacheAt.Add(seasonCupCacheTTL)
	seasonCupMu.RUnlock()

	if len(cached) > 0 && time.Now().Before(freshUntil) {
		return cached
	}

	cursor, err := col(ColSeasonCups).Find(ctx,
		bson.M{"season_id": DefaultSeasonID},
		options.Find().SetSort(bson.D{{Key: "sort_order", Value: 1}, {Key: "xp_required", Value: 1}}),
	)
	if err != nil {
		return fallbackSeasonCups(cached)
	}
	defer cursor.Close(ctx)

	cups := []SeasonCupDef{}
	if err := cursor.All(ctx, &cups); err != nil || len(cups) == 0 {
		return fallbackSeasonCups(cached)
	}

	// ترتیب باید همیشه صعودی باشد؛ «کاپ بعدی» و شمارش به همین تکیه می‌کنند
	sort.SliceStable(cups, func(i, j int) bool {
		if cups[i].SortOrder != cups[j].SortOrder {
			return cups[i].SortOrder < cups[j].SortOrder
		}
		return cups[i].XPRequired < cups[j].XPRequired
	})

	seasonCupMu.Lock()
	seasonCupCache = cups
	seasonCupCacheAt = time.Now()
	seasonCupMu.Unlock()

	return cups
}

// fallbackSeasonCups وقتی دیتابیس در دسترس نیست
func fallbackSeasonCups(cached []SeasonCupDef) []SeasonCupDef {
	if len(cached) > 0 {
		return cached
	}
	return defaultSeasonCups(DefaultSeasonID)
}

// seasonCupThresholds تجربه‌ی لازم هر کاپ، بدون context.
// جدول رتبه‌بندی برای هر ردیف فقط به همین عددها نیاز دارد.
func seasonCupThresholds() []int {
	seasonCupMu.RLock()
	cached := seasonCupCache
	seasonCupMu.RUnlock()

	cups := fallbackSeasonCups(cached)
	out := make([]int, 0, len(cups))
	for _, c := range cups {
		out = append(out, c.XPRequired)
	}
	return out
}

// currentSeasonCups وضعیت کاپ‌های بازیکن در فصل جاری.
// اگر رکورد مال فصل قبل باشد، وضعیتِ خالیِ فصل جاری برمی‌گردد (ریست فصل
// همین‌جا اتفاق می‌افتد و به cron نیاز ندارد — مثل currentSeasonPass).
func currentSeasonCups(player *PlayerModel) PlayerSeasonCups {
	state := player.SeasonCups
	if state.SeasonID != DefaultSeasonID {
		return PlayerSeasonCups{SeasonID: DefaultSeasonID, Claimed: []string{}}
	}
	if state.Claimed == nil {
		state.Claimed = []string{}
	}
	return state
}
