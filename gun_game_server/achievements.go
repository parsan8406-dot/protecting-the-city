package main

import (
	"context"
	"sort"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// =============================================================================
// دستاوردها و آمار پروفایل
//
// آمارِ پروفایل (کشته، مرگ، نارنجک، درمان، زمان بازی، آخرین سلاح) از خودِ
// راند در هاب ثبت می‌شود — persistProfileStats — نه از /match/result. قبلاً
// فقط برد و باخت ذخیره می‌شد و کارت آمار و «آخرین سلاح» هیچ‌وقت تکان نمی‌خورد.
//
// دستاورد وقتی باز می‌شود که شمارنده‌ی متریکش به هدف برسد. باز شدن اتمیک و
// یک‌بار است (شرط $ne روی خودِ آپدیت)، پس جایزه‌اش هم فقط یک بار می‌آید.
// =============================================================================

// RecentMatchLimit چند مسابقه‌ی آخر برای «فرم اخیر» پروفایل نگه داشته شود
const RecentMatchLimit = 10

// achievementCatalog کاتالوگ پیش‌فرض. سرور با $setOnInsert می‌نویسد، پس جایزه
// و هدفی که دستی در دیتابیس عوض شده با ری‌استارت برنمی‌گردد. پله‌های اول عمداً
// نزدیک‌اند تا بازیکن تازه همان روز اول چیزی باز کند.
var achievementCatalog = []AchievementDef{
	// --- شروع راه ---
	{AchievementID: "ach_first_match", Name: "اولین قدم", Description: "اولین مسابقه‌ات را بازی کن", Metric: "total_matches", Target: 1, RewardCoins: 150, SortOrder: 10},
	{AchievementID: "ach_first_blood", Name: "اولین خون", Description: "اولین حریف را از پا در بیاور", Metric: "kills", Target: 1, RewardCoins: 200, SortOrder: 11},
	{AchievementID: "ach_first_win", Name: "اولین پیروزی", Description: "اولین مسابقه‌ات را ببر", Metric: "wins", Target: 1, RewardCoins: 300, SortOrder: 12},

	// --- مسابقه ---
	{AchievementID: "ach_rookie", Name: "تازه‌نفس", Description: "۱۰ مسابقه بازی کن", Metric: "total_matches", Target: 10, RewardCoins: 500, SortOrder: 20},
	{AchievementID: "ach_regular", Name: "پای ثابت", Description: "۱۰۰ مسابقه بازی کن", Metric: "total_matches", Target: 100, RewardCoins: 2500, RewardGems: 20, SortOrder: 21},

	// --- برد ---
	{AchievementID: "ach_winner_25", Name: "جنگجوی پیروز", Description: "۲۵ مسابقه را ببر", Metric: "wins", Target: 25, RewardCoins: 1500, RewardGems: 10, SortOrder: 30},
	{AchievementID: "ach_field_king", Name: "سلطان میدان", Description: "۱۰۰ بازی را ببر", Metric: "wins", Target: 100, RewardCoins: 5000, RewardGems: 50, SortOrder: 31},

	// --- کشته ---
	{AchievementID: "ach_hunter", Name: "شکارچی", Description: "۵۰ حریف را از پا در بیاور", Metric: "kills", Target: 50, RewardCoins: 1000, RewardGems: 5, SortOrder: 40},
	{AchievementID: "ach_fast_furious", Name: "سریع و خشن", Description: "۵۰۰ حریف را از پا در بیاور", Metric: "kills", Target: 500, RewardCoins: 3000, RewardGems: 30, SortOrder: 41},
	{AchievementID: "ach_sharpshooter", Name: "تیرانداز ماهر", Description: "۱۰۰۰ حریف را از پا در بیاور", Metric: "kills", Target: 1000, RewardCoins: 8000, RewardGems: 80, SortOrder: 42},

	// --- نارنجک ---
	{AchievementID: "ach_grenadier", Name: "نارنجک‌انداز", Description: "۱۰ کشته با نارنجک", Metric: "grenade_kills", Target: 10, RewardCoins: 800, SortOrder: 50},
	{AchievementID: "ach_silent_killer", Name: "قاتل خاموش", Description: "۱۰۰ کشته با نارنجک", Metric: "grenade_kills", Target: 100, RewardCoins: 4000, RewardGems: 40, SortOrder: 51},

	// --- درمان ---
	{AchievementID: "ach_first_aid", Name: "کمک‌های اولیه", Description: "۲۰ بار هم‌تیمی را درمان کن", Metric: "heals_given", Target: 20, RewardCoins: 800, SortOrder: 60},
	{AchievementID: "ach_medic", Name: "امدادگر", Description: "۲۰۰ بار هم‌تیمی را درمان کن", Metric: "heals_given", Target: 200, RewardCoins: 2500, RewardGems: 25, SortOrder: 61},

	// --- ماموریت ---
	{AchievementID: "ach_mission_10", Name: "ماموریت‌گرا", Description: "۱۰ ماموریت روزانه را تمام کن", Metric: "missions_done", Target: 10, RewardCoins: 1000, RewardGems: 5, SortOrder: 70},
	{AchievementID: "ach_mission_100", Name: "مامور ویژه", Description: "۱۰۰ ماموریت روزانه را تمام کن", Metric: "missions_done", Target: 100, RewardCoins: 5000, RewardGems: 40, SortOrder: 71},

	// --- زمان بازی ---
	{AchievementID: "ach_hours_10", Name: "پرتلاش", Description: "۱۰ ساعت بازی کن", Metric: "playtime_seconds", Target: 36000, RewardCoins: 2000, RewardGems: 15, SortOrder: 80},
	{AchievementID: "ach_veteran", Name: "کهنه‌کار", Description: "۱۰۰ ساعت بازی کن", Metric: "playtime_seconds", Target: 360000, RewardCoins: 10000, RewardGems: 100, SortOrder: 81},
}

func seedAchievements(ctx context.Context) error {
	for _, def := range achievementCatalog {
		filter := bson.M{"achievement_id": def.AchievementID}
		update := bson.M{
			"$setOnInsert": bson.M{
				"achievement_id": def.AchievementID,
				"name":           def.Name,
				"description":    def.Description,
				"icon_path":      def.IconPath,
				"metric":         def.Metric,
				"target":         def.Target,
				"reward_coins":   def.RewardCoins,
				"reward_gems":    def.RewardGems,
			},
			// ترتیب نمایش اقتصاد نیست؛ همیشه از کد می‌آید تا پله‌های تازه
			// کنار هم‌گروه‌هایشان بنشینند
			"$set": bson.M{"sort_order": def.SortOrder},
		}
		if _, err := col(ColAchievements).UpdateOne(ctx, filter, update, options.Update().SetUpsert(true)); err != nil {
			return err
		}
	}
	return nil
}

// achievementMetrics مقدار فعلی هر متریک برای یک بازیکن
func achievementMetrics(p *PlayerModel) map[string]int {
	return map[string]int{
		"kills":            p.Stats.Kills,
		"wins":             p.Stats.Wins,
		"total_matches":    p.Stats.TotalMatches,
		"assists":          p.Stats.Assists,
		"grenade_kills":    p.Stats.GrenadeKills,
		"heals_given":      p.Stats.HealsGiven,
		"missions_done":    p.Stats.MissionsDone,
		"playtime_seconds": int(p.Stats.PlaytimeSeconds),
	}
}

func loadAchievementDefs(ctx context.Context) ([]AchievementDef, error) {
	cursor, err := col(ColAchievements).Find(ctx, bson.M{},
		options.Find().SetSort(bson.D{{Key: "sort_order", Value: 1}}))
	if err != nil {
		return nil, err
	}
	defer cursor.Close(ctx)
	defs := []AchievementDef{}
	if err := cursor.All(ctx, &defs); err != nil {
		return nil, err
	}
	return defs, nil
}

// checkAndUnlockAchievements دستاوردهای واجد شرایط را باز می‌کند، جایزه را
// به‌صورت پیام می‌فرستد و فهرستِ تازه‌بازشده‌ها را برمی‌گرداند.
func checkAndUnlockAchievements(ctx context.Context, player *PlayerModel) []UnlockedAchievement {
	defs, err := loadAchievementDefs(ctx)
	if err != nil {
		return nil
	}
	unlocked := map[string]bool{}
	for _, a := range player.Achievements {
		unlocked[a.AchievementID] = true
	}
	metrics := achievementMetrics(player)

	fresh := []UnlockedAchievement{}
	now := time.Now()
	for _, def := range defs {
		if unlocked[def.AchievementID] || def.Target <= 0 {
			continue
		}
		value, ok := metrics[def.Metric]
		if !ok || value < def.Target {
			continue
		}
		entry := UnlockedAchievement{AchievementID: def.AchievementID, Progress: value, UnlockedAt: now}
		// شرطِ «هنوز ندارد» روی خودِ آپدیت: دو بررسیِ هم‌زمان (پایان راند و
		// باز کردن پروفایل) نمی‌توانند یک دستاورد را دو بار باز کنند
		res, err := col(ColPlayers).UpdateOne(ctx,
			bson.M{"player_id": player.PlayerID, "achievements.achievement_id": bson.M{"$ne": def.AchievementID}},
			bson.M{"$push": bson.M{"achievements": entry}, "$set": bson.M{"updated_at": now}})
		if err != nil || res.ModifiedCount == 0 {
			continue
		}
		fresh = append(fresh, entry)

		if def.RewardCoins > 0 || def.RewardGems > 0 {
			_ = insertMessage(ctx, MessageModel{
				RecipientID: player.PlayerID,
				SenderID:    "system",
				SenderName:  "بازی",
				Type:        MsgTypeReward,
				Title:       "دستاورد جدید: " + def.Name,
				Body:        def.Description,
				Reward:      &MessageReward{Coins: def.RewardCoins, Gems: def.RewardGems},
			})
		}
		NotifyUser(player.Username, map[string]interface{}{
			"type": "notification",
			"kind": "achievement",
			"name": def.Name,
		})
	}
	player.Achievements = append(player.Achievements, fresh...)
	return fresh
}

// buildAchievementView دستاوردهای باز شده (جدیدترین اول) با اطلاعات کاتالوگ
// + کل کاتالوگ با پیشرفت هر کدام، برای کارت دستاوردها و پنجره‌ی «همه‌ی دستاوردها»
func buildAchievementView(ctx context.Context, player *PlayerModel) (recent, catalog []map[string]interface{}) {
	recent = []map[string]interface{}{}
	catalog = []map[string]interface{}{}
	defs, err := loadAchievementDefs(ctx)
	if err != nil {
		return
	}
	byID := map[string]AchievementDef{}
	for _, d := range defs {
		byID[d.AchievementID] = d
	}
	unlockedAt := map[string]time.Time{}
	for _, a := range player.Achievements {
		unlockedAt[a.AchievementID] = a.UnlockedAt
	}

	for i := len(player.Achievements) - 1; i >= 0; i-- {
		a := player.Achievements[i]
		def, ok := byID[a.AchievementID]
		if !ok {
			continue
		}
		recent = append(recent, map[string]interface{}{
			"achievement_id": a.AchievementID,
			"name":           def.Name,
			"description":    def.Description,
			"icon_path":      def.IconPath,
			"metric":         def.Metric,
			"unlocked_at":    a.UnlockedAt,
		})
	}

	metrics := achievementMetrics(player)
	for _, def := range defs {
		progress := metrics[def.Metric]
		if progress > def.Target {
			progress = def.Target
		}
		item := map[string]interface{}{
			"achievement_id": def.AchievementID,
			"name":           def.Name,
			"description":    def.Description,
			"metric":         def.Metric,
			"target":         def.Target,
			"progress":       progress,
			"reward_coins":   def.RewardCoins,
			"reward_gems":    def.RewardGems,
			"unlocked":       false,
		}
		if at, ok := unlockedAt[def.AchievementID]; ok {
			item["unlocked"] = true
			item["unlocked_at"] = at
			item["progress"] = def.Target
		}
		catalog = append(catalog, item)
	}
	return
}

// nextAchievement نزدیک‌ترین دستاوردِ باز نشده (بیشترین درصد پیشرفت) — «هدف بعدی»
func nextAchievement(catalog []map[string]interface{}) map[string]interface{} {
	candidates := []map[string]interface{}{}
	for _, item := range catalog {
		if unlocked, _ := item["unlocked"].(bool); !unlocked {
			candidates = append(candidates, item)
		}
	}
	if len(candidates) == 0 {
		return nil
	}
	ratio := func(m map[string]interface{}) float64 {
		t, _ := m["target"].(int)
		p, _ := m["progress"].(int)
		if t <= 0 {
			return 0
		}
		return float64(p) / float64(t)
	}
	sort.SliceStable(candidates, func(i, j int) bool { return ratio(candidates[i]) > ratio(candidates[j]) })
	return candidates[0]
}

// persistProfileStats آمار پروفایل را از نتیجه‌ی یک راند ثبت می‌کند و بعد
// دستاوردها را بررسی می‌کند. برد و باخت و کاپ را ApplyMatchResult جدا می‌نویسد؛
// این‌جا فقط مساوی به «کل بازی‌ها» اضافه می‌شود تا دو بار شمرده نشود.
func persistProfileStats(ctx context.Context, playerID, modeID string, part MatchParticipant, secs int64, draw bool) error {
	inc := bson.M{
		"stats.kills":            part.Kills,
		"stats.deaths":           part.Deaths,
		"stats.assists":          part.Assists,
		"stats.grenade_kills":    part.GrenadeKills,
		"stats.heals_given":      part.HealsGiven,
		"stats.playtime_seconds": secs,
	}
	// 🌟 «تعداد بازی» عمداً این‌جا شمرده نمی‌شود — حتی در مساوی.
	//
	// قبلاً مساوی استثنا بود: endRound در مساوی اصلاً ApplyMatchResult را
	// صدا نمی‌زد، پس total_matches جایی زیاد نمی‌شد و این‌جا جبرانش
	// می‌کردیم. حالا که مساوی هم بردِ کامل است و ApplyMatchResult برای هر
	// دو تیم اجرا می‌شود، این خط همان مسابقه را دوباره می‌شمرد — یعنی هر
	// مساوی دو بازی ثبت می‌شد و درصدِ برد را خراب می‌کرد.
	now := time.Now()
	set := bson.M{"updated_at": now}
	if part.WeaponUsed != "" {
		set["stats.last_used_weapon"] = part.WeaponUsed
	}
	recent := RecentMatch{
		ModeID: modeID, Won: part.Won && !draw, Draw: draw,
		Kills: part.Kills, Deaths: part.Deaths, Weapon: part.WeaponUsed, At: now,
	}
	_, err := col(ColPlayers).UpdateOne(ctx, bson.M{"player_id": playerID}, bson.M{
		"$inc": inc,
		"$set": set,
		"$push": bson.M{"recent_matches": bson.M{
			"$each": []RecentMatch{recent}, "$slice": -RecentMatchLimit,
		}},
	})
	if err != nil {
		return err
	}
	if p, err := getPlayerByID(ctx, playerID); err == nil {
		checkAndUnlockAchievements(ctx, p)
	}
	return nil
}
