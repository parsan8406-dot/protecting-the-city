package main

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// =============================================================================
// اندپوینت‌های ماموریت روزانه و پاداش فصل
// =============================================================================
//
// قانون کلی: کلاینت فقط می‌گوید «من کی هستم» و «کدام ماموریت/پله را می‌خواهم
// بگیرم». مقدار جایزه، پیشرفت، و اینکه اصلاً حقش هست یا نه، همه اینجا از
// دیتابیس خوانده می‌شود. هیچ عددی از بدنه‌ی درخواست به موجودی بازیکن نمی‌رسد.

// MissionClaimBody بدنه‌ی POST /missions/claim
type MissionClaimBody struct {
	Username  string `json:"username"`
	MissionID string `json:"mission_id"`
}

// SeasonPassClaimBody بدنه‌ی POST /season/pass/claim
type SeasonPassClaimBody struct {
	Username string `json:"username"`
	Level    int    `json:"level"`
	// Track کدام جایزه‌ی این پله: "free" (پیش‌فرض) یا "premium"
	Track string `json:"track"`
}

// levelFromExperience سطح بازیکن را از تجربه‌ی کل حساب می‌کند.
// همان فرمولی که getPlayerHandler و کلاینت استفاده می‌کنند: هر سطح level*100.
func levelFromExperience(totalXP int) (level, into, need int) {
	level = 1
	into = totalXP
	for {
		need = level * 100
		if into < need {
			return level, into, need
		}
		into -= need
		level++
	}
}

// -----------------------------------------------------------------------------
// GET /missions/daily?username=<username>
// -----------------------------------------------------------------------------

// getDailyMissionsHandler ماموریت‌های امروزِ بازیکن را با تایمر ریست برمی‌گرداند.
//
// تایمر (`seconds_left`) از ساعت سرور می‌آید نه ساعت گوشی، پس عقب/جلو کردن
// ساعت دستگاه هیچ ماموریتی را زودتر ریست نمی‌کند.
func getDailyMissionsHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	username := r.URL.Query().Get("username")
	if username == "" {
		httpError(w, "نام کاربری لازم است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	player, err := getPlayerByUsername(ctx, username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	now := time.Now()
	doc, err := loadOrCreateDailyMissions(ctx, player.PlayerID, now)
	if err != nil {
		httpError(w, "خطا در خواندن ماموریت‌ها", http.StatusInternalServerError)
		return
	}

	jsonResponse(w, buildMissionsResponse(doc, now))
}

// buildMissionsResponse پاسخ /missions/daily را می‌سازد.
// جدا شده تا هندلر «دریافت جایزه» هم بتواند لیست تازه را برگرداند و کلاینت
// مجبور نشود بلافاصله یک درخواست دوم بزند.
func buildMissionsResponse(doc *DailyMissionDoc, now time.Time) map[string]interface{} {
	missions := make([]map[string]interface{}, 0, len(doc.Missions))
	claimed := 0
	ready := 0

	for _, state := range doc.Missions {
		def, ok := missionDefByID[state.MissionID]
		if !ok {
			continue
		}

		done := state.Progress >= def.Target
		if state.Claimed {
			claimed++
		} else if done {
			ready++
		}

		missions = append(missions, map[string]interface{}{
			"mission_id": def.MissionID,
			"title":      def.Title,
			"desc":       def.Desc,
			"icon":       def.Icon,
			"metric":     string(def.Metric),
			"difficulty": int(def.Difficulty),
			"target":     def.Target,
			"progress":   minInt(state.Progress, def.Target),
			"done":       done,
			"claimed":    state.Claimed,
			"xp":         def.XP,
			"coins":      def.Coins,
		})
	}

	bonus, bonusReady := buildDailyBonusView(doc, claimed)

	return map[string]interface{}{
		"day_key":      doc.DayKey,
		"seconds_left": missionSecondsLeft(now),
		"reset_at":     missionDayEnd(now).Format(time.RFC3339),
		"total":        len(missions),
		"claimed":      claimed,
		"ready":        ready,
		"missions":     missions,
		// نوار جایزه‌ی روزانه — پله‌های ۲/۴/۶ و اینکه کدامشان آماده است
		"bonus":       bonus,
		"bonus_ready": bonusReady,
		"bonus_max":   dailyBonusMaxNeed(),
	}
}

// -----------------------------------------------------------------------------
// POST /missions/claim  {username, mission_id}
// -----------------------------------------------------------------------------

// claimDailyMissionHandler جایزه‌ی یک ماموریت تمام‌شده را واریز می‌کند.
//
// امنیت: علامت‌گذاریِ «گرفته شد» با یک آپدیت اتمیک انجام می‌شود که شرطش
// «هنوز گرفته نشده» است. اگر بازیکن همزمان دو بار دکمه را بزند، فقط یکی از
// دو درخواست آپدیت را می‌برد و دومی «جایزه‌ای برای دریافت نیست» می‌گیرد.
func claimDailyMissionHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req MissionClaimBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	def, ok := missionDefByID[req.MissionID]
	if !ok {
		httpError(w, "این ماموریت وجود ندارد", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	player, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	now := time.Now()
	dayKey := missionDayKey(now)

	// مطمئن شویم رکورد امروز ساخته شده (بازیکنی که هنوز صفحه را باز نکرده)
	if _, err := loadOrCreateDailyMissions(ctx, player.PlayerID, now); err != nil {
		httpError(w, "خطا در خواندن ماموریت‌ها", http.StatusInternalServerError)
		return
	}

	// قفل اتمیک: فقط اگر همین ماموریتِ همین روز تمام شده و گرفته نشده باشد،
	// claimed را true می‌کند. شرط progress هم داخل خود کوئری است تا کلاینت
	// نتواند با ادعای «تمام شد» جایزه بگیرد.
	var updated DailyMissionDoc
	err = col(ColDailyMissions).FindOneAndUpdate(ctx,
		bson.M{
			"player_id": player.PlayerID,
			"day_key":   dayKey,
			"missions": bson.M{"$elemMatch": bson.M{
				"mission_id": def.MissionID,
				"claimed":    false,
				"progress":   bson.M{"$gte": def.Target},
			}},
		},
		bson.M{
			"$set": bson.M{
				"missions.$[target].claimed":    true,
				"missions.$[target].claimed_at": now,
				"updated_at":                    now,
			},
		},
		options.FindOneAndUpdate().
			SetReturnDocument(options.After).
			SetArrayFilters(options.ArrayFilters{Filters: []interface{}{
				bson.M{"target.mission_id": def.MissionID},
			}}),
	).Decode(&updated)
	if err != nil {
		httpError(w, "این ماموریت هنوز تمام نشده یا جایزه‌اش گرفته شده", http.StatusBadRequest)
		return
	}

	// واریز جایزه
	_, err = col(ColPlayers).UpdateOne(ctx,
		bson.M{"player_id": player.PlayerID},
		bson.M{
			"$inc": bson.M{
				"coins":               def.Coins,
				"experience":          def.XP,
				"stats.missions_done": 1,
			},
			"$set": bson.M{"updated_at": now},
		})
	if err != nil {
		// جایزه واریز نشد → قفل را برمی‌گردانیم تا بازیکن دوباره بتواند بگیرد
		_, _ = col(ColDailyMissions).UpdateOne(ctx,
			bson.M{"player_id": player.PlayerID, "day_key": dayKey},
			bson.M{"$set": bson.M{"missions.$[target].claimed": false}},
			options.Update().SetArrayFilters(options.ArrayFilters{Filters: []interface{}{
				bson.M{"target.mission_id": def.MissionID},
			}}))
		httpError(w, "خطا در واریز جایزه", http.StatusInternalServerError)
		return
	}

	// تجربه‌ی ماموریت به پاداش فصل هم اضافه می‌شود (بتل‌پس با همین جلو می‌رود)
	_ = addSeasonPassXP(ctx, player.PlayerID, def.XP)

	// موجودی تازه برای نوار بالای کلاینت
	fresh, err := getPlayerByID(ctx, player.PlayerID)
	if err != nil {
		fresh = player
	}
	level, into, need := levelFromExperience(fresh.Experience)

	response := buildMissionsResponse(&updated, now)
	response["success"] = true
	response["reward"] = map[string]interface{}{"coins": def.Coins, "xp": def.XP}
	response["coins"] = fresh.Coins
	response["gems"] = fresh.Gems
	response["experience"] = fresh.Experience
	response["level"] = level
	response["level_xp"] = into
	response["level_max"] = need

	jsonResponse(w, response)
}

// -----------------------------------------------------------------------------
// POST /missions/bonus/claim  {username, need}
// -----------------------------------------------------------------------------

// DailyBonusClaimBody بدنه‌ی POST /missions/bonus/claim
type DailyBonusClaimBody struct {
	Username string `json:"username"`
	Need     int    `json:"need"` // کدام پله — همان Need توی DailyBonusTiers
}

// claimDailyBonusHandler یک پله‌ی جایزه‌ی روزانه (۲ / ۴ / ۶ ماموریت) را واریز می‌کند.
//
// امنیت مثل claimDailyMissionHandler: کلاینت فقط شماره‌ی پله را می‌گوید، مقدار
// جایزه از DailyBonusTiers خوانده می‌شود، و «آیا اصلاً بازش کرده؟» از روی
// شمارشِ خودِ رکورد دیتابیس حساب می‌شود نه ادعای کلاینت.
//
// جلوگیری از دوبار گرفتن با $addToSet + شرط $ne انجام می‌شود؛ اگر بازیکن
// همزمان دو بار بزند فقط یکی از دو درخواست رکورد را عوض می‌کند.
func claimDailyBonusHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req DailyBonusClaimBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	tier, ok := dailyBonusTierByNeed(req.Need)
	if !ok {
		httpError(w, "این پله وجود ندارد", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	player, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	now := time.Now()
	dayKey := missionDayKey(now)

	doc, err := loadOrCreateDailyMissions(ctx, player.PlayerID, now)
	if err != nil {
		httpError(w, "خطا در خواندن ماموریت‌ها", http.StatusInternalServerError)
		return
	}

	// چند ماموریت امروز واقعاً دریافت شده — از خود رکورد، نه از درخواست
	claimedCount := 0
	for _, state := range doc.Missions {
		if state.Claimed {
			claimedCount++
		}
	}
	if claimedCount < tier.Need {
		httpError(w, "هنوز به این پله نرسیده‌ای", http.StatusBadRequest)
		return
	}

	// رکوردهای قدیمی bonus_claimed را null دارند و $addToSet رویش خطا می‌دهد
	dayFilter := bson.M{"player_id": player.PlayerID, "day_key": dayKey}
	if err := ensureArrayFields(ctx, col(ColDailyMissions), dayFilter, "bonus_claimed"); err != nil {
		httpError(w, "خطا در آماده‌سازی جایزه‌ی روزانه", http.StatusInternalServerError)
		return
	}

	// قفل اتمیک: فقط اگر این پله هنوز توی bonus_claimed نباشد اضافه می‌شود
	var updated DailyMissionDoc
	err = col(ColDailyMissions).FindOneAndUpdate(ctx,
		bson.M{
			"player_id":     player.PlayerID,
			"day_key":       dayKey,
			"bonus_claimed": bson.M{"$ne": tier.Need},
		},
		bson.M{
			"$addToSet": bson.M{"bonus_claimed": tier.Need},
			"$set":      bson.M{"updated_at": now},
		},
		options.FindOneAndUpdate().SetReturnDocument(options.After),
	).Decode(&updated)
	if err == mongo.ErrNoDocuments {
		httpError(w, "جایزه‌ی این پله قبلاً گرفته شده", http.StatusBadRequest)
		return
	}
	if err != nil {
		// قبلاً هر خطایی «قبلاً گرفته شده» گزارش می‌شد و همین باگِ null را
		// پنهان کرده بود — خطای واقعی باید خطای واقعی بماند
		httpError(w, "خطا در دریافت جایزه‌ی روزانه", http.StatusInternalServerError)
		return
	}

	// واریز جایزه
	_, err = col(ColPlayers).UpdateOne(ctx,
		bson.M{"player_id": player.PlayerID},
		bson.M{
			"$inc": bson.M{"coins": tier.Coins, "gems": tier.Gems},
			"$set": bson.M{"updated_at": now},
		})
	if err != nil {
		// واریز نشد → قفل را برمی‌گردانیم تا بازیکن دوباره بتواند بگیرد
		_, _ = col(ColDailyMissions).UpdateOne(ctx,
			bson.M{"player_id": player.PlayerID, "day_key": dayKey},
			bson.M{"$pull": bson.M{"bonus_claimed": tier.Need}})
		httpError(w, "خطا در واریز جایزه", http.StatusInternalServerError)
		return
	}

	fresh, err := getPlayerByID(ctx, player.PlayerID)
	if err != nil {
		fresh = player
	}
	level, into, need := levelFromExperience(fresh.Experience)

	response := buildMissionsResponse(&updated, now)
	response["success"] = true
	response["reward"] = map[string]interface{}{
		"coins": tier.Coins,
		"gems":  tier.Gems,
		// کدام صندوق باز شد — عکسش بالای صفحه‌ی جایزه می‌نشیند
		"chest": tier.Icon,
	}
	response["coins"] = fresh.Coins
	response["gems"] = fresh.Gems
	response["experience"] = fresh.Experience
	response["level"] = level
	response["level_xp"] = into
	response["level_max"] = need

	jsonResponse(w, response)
}

// -----------------------------------------------------------------------------
// GET /season/pass?username=<username>
// -----------------------------------------------------------------------------

// getSeasonPassHandler نردبان پاداش فصل و جایگاه بازیکن روی آن را برمی‌گرداند
func getSeasonPassHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	username := r.URL.Query().Get("username")
	if username == "" {
		httpError(w, "نام کاربری لازم است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	player, err := getPlayerByUsername(ctx, username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	jsonResponse(w, buildSeasonPassResponse(player))
}

// buildSeasonPassResponse پاسخ /season/pass را می‌سازد
func buildSeasonPassResponse(player *PlayerModel) map[string]interface{} {
	pass := currentSeasonPass(player)
	level, into, need := seasonPassProgress(pass.XP)

	claimedSet := map[int]bool{}
	for _, l := range pass.ClaimedLevels {
		claimedSet[l] = true
	}

	claimedPremiumSet := map[int]bool{}
	for _, l := range pass.ClaimedPremium {
		claimedPremiumSet[l] = true
	}

	// وضعیت یک جایزه روی یک پله. مسیر طلایی تا وقتی بتل‌پس خریده نشده
	// «قفل طلایی» است، حتی اگر بازیکن از آن پله رد شده باشد.
	rewardView := func(
		reward SeasonPassReward, unlocked bool, taken bool, premium bool,
	) map[string]interface{} {
		state := "locked"
		switch {
		case taken:
			state = "claimed"
		case premium && !pass.Premium:
			// پله باز است ولی بتل‌پس طلایی خریده نشده
			state = "premium_locked"
		case unlocked:
			state = "ready"
		}
		return map[string]interface{}{
			"coins": reward.Coins,
			"gems":  reward.Gems,
			"cups":  reward.Cups,
			"title": reward.Title,
			"icon":  reward.Icon,
			// کلاینت با skin_id تصویر خودِ اسکین را روی کارت پله می‌گذارد
			"skin_id": reward.SkinID,
			"state":   state,
		}
	}

	freeLadder := SeasonPassLadder()
	premiumLadder := SeasonPassPremiumLadder()

	tiers := make([]map[string]interface{}, 0, SeasonPassMaxLevel)
	readyCount := 0
	for i, reward := range freeLadder {
		required := seasonPassXPRequired(reward.Level)
		unlocked := pass.XP >= required

		free := rewardView(reward, unlocked, claimedSet[reward.Level], false)
		premium := rewardView(
			premiumLadder[i], unlocked, claimedPremiumSet[reward.Level], true)

		if free["state"] == "ready" {
			readyCount++
		}
		if premium["state"] == "ready" {
			readyCount++
		}

		tiers = append(tiers, map[string]interface{}{
			"level":       reward.Level,
			"xp_required": required,
			"unlocked":    unlocked,
			"free":        free,
			"premium":     premium,
			// سازگاری با کدی که هنوز مستقیم به فیلدهای پله نگاه می‌کند
			"coins": reward.Coins,
			"gems":  reward.Gems,
			"cups":  reward.Cups,
			"title": reward.Title,
			"icon":  reward.Icon,
			"state": free["state"],
		})
	}

	challenges, challengesReady := buildSeasonChallengeView(pass)

	return map[string]interface{}{
		"season_id":   pass.SeasonID,
		"xp":          pass.XP,
		"level":       level,
		"level_xp":    into,
		"level_max":   need,
		"max_level":   SeasonPassMaxLevel,
		"ready":       readyCount,
		"claimed":     len(pass.ClaimedLevels) + len(pass.ClaimedPremium),
		"tiers":       tiers,
		"end_rewards": SeasonRewards,

		// بتل‌پس طلایی
		"premium":       pass.Premium,
		"premium_price": SeasonPassPremiumPrice,

		// چالش‌های ویژه‌ی فصل
		"challenges":       challenges,
		"challenges_ready": challengesReady,

		// متن بنر بالای صفحه
		"season_name":     SeasonName,
		"season_subtitle": SeasonSubtitle,
		"season_ends_at":  SeasonEndsAt,
	}
}

// -----------------------------------------------------------------------------
// POST /season/pass/claim  {username, level}
// -----------------------------------------------------------------------------

// claimSeasonPassHandler جایزه‌ی یک پله‌ی پاداش فصل را واریز می‌کند.
//
// امنیت: پله فقط وقتی گرفته می‌شود که تجربه‌ی فصلِ ذخیره‌شده در دیتابیس به آن
// رسیده باشد. `$addToSet` روی claimed_levels با شرطِ «هنوز داخلش نیست» یعنی
// دوبار زدن دکمه دوبار جایزه نمی‌دهد.
func claimSeasonPassHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req SeasonPassClaimBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}
	if req.Level < 1 || req.Level > SeasonPassMaxLevel {
		httpError(w, "این پله وجود ندارد", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	player, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	// همان شرطی که /season/pass برای «آماده» بودن استفاده می‌کند
	pass := currentSeasonPass(player)
	if pass.XP < seasonPassXPRequired(req.Level) {
		httpError(w, "هنوز به این پله نرسیده‌ای", http.StatusBadRequest)
		return
	}

	now := time.Now()

	// مسیر طلایی فقط برای کسی که بتل‌پس را خریده. این تنها جای تصمیم‌گیری
	// است — کلاینت فقط اسم مسیر را می‌گوید، نه اینکه حقش را دارد یا نه.
	premium := req.Track == "premium"
	if premium && !pass.Premium {
		httpError(w, "برای این جایزه باید بتل‌پس طلایی داشته باشی", http.StatusForbidden)
		return
	}

	reward := seasonPassReward(req.Level)
	claimedField := "season_pass.claimed_levels"
	if premium {
		reward = seasonPassPremiumReward(req.Level)
		claimedField = "season_pass.claimed_premium"
	}

	// اگر رکورد مال فصل قبل بود، اول وضعیت فصل جاری را می‌نشانیم تا
	// $addToSet روی آرایه‌ی درست کار کند.
	if player.SeasonPass.SeasonID != DefaultSeasonID {
		if _, err := col(ColPlayers).UpdateOne(ctx,
			bson.M{"player_id": player.PlayerID},
			bson.M{"$set": bson.M{"season_pass": pass}}); err != nil {
			httpError(w, "خطا در آماده‌سازی پاداش فصل", http.StatusInternalServerError)
			return
		}
	}

	// آرایه‌ی null (بیشتر بازیکن‌ها) جلوی $addToSet را می‌گیرد
	arrayFields := []string{claimedField}
	if reward.SkinID != "" {
		arrayFields = append(arrayFields, "owned_skins")
	}
	if err := ensureArrayFields(ctx, col(ColPlayers),
		bson.M{"player_id": player.PlayerID}, arrayFields...); err != nil {
		httpError(w, "خطا در آماده‌سازی پاداش فصل", http.StatusInternalServerError)
		return
	}

	// اسکین در همان آپدیت اتمیک واریز می‌شود
	addToSet := bson.M{claimedField: req.Level}
	if reward.SkinID != "" {
		addToSet["owned_skins"] = reward.SkinID
	}

	// قفل اتمیک: فقط اگر این پله داخل claimed_levels نباشد آپدیت می‌شود
	result, err := col(ColPlayers).UpdateOne(ctx,
		bson.M{
			"player_id":             player.PlayerID,
			"season_pass.season_id": DefaultSeasonID,
			claimedField:            bson.M{"$ne": req.Level},
		},
		bson.M{
			"$addToSet": addToSet,
			"$inc": bson.M{
				"coins": reward.Coins,
				"gems":  reward.Gems,
			},
			"$set": bson.M{"updated_at": now},
		})
	if err != nil {
		httpError(w, "خطا در واریز جایزه", http.StatusInternalServerError)
		return
	}
	if result.ModifiedCount == 0 {
		httpError(w, "جایزه‌ی این پله قبلاً گرفته شده", http.StatusBadRequest)
		return
	}

	fresh, err := getPlayerByID(ctx, player.PlayerID)
	if err != nil {
		fresh = player
	}

	response := buildSeasonPassResponse(fresh)
	response["success"] = true
	response["reward"] = map[string]interface{}{
		"coins": reward.Coins,
		"gems":  reward.Gems,
		"cups":  reward.Cups,
		"title": reward.Title,
		// کلاینت با این، اسکین/طرح سلاح را با عکس خودش نشان می‌دهد
		"icon":    reward.Icon,
		"skin_id": reward.SkinID,
	}
	response["owned_skins"] = nonNilStrings(fresh.OwnedSkins)
	response["coins"] = fresh.Coins
	response["gems"] = fresh.Gems
	// سطح خود بازیکن — «level» همین پاسخ پله‌ی بتل‌پس است، نه سطح بازیکن
	playerLevel, playerInto, playerNeed := levelFromExperience(fresh.Experience)
	response["player_level"] = playerLevel
	response["player_level_xp"] = playerInto
	response["player_level_max"] = playerNeed

	jsonResponse(w, response)
}

// minInt کوچک‌ترین از دو عدد
func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// -----------------------------------------------------------------------------
// POST /season/pass/buy  {username}
// -----------------------------------------------------------------------------

// SeasonPassBuyBody بدنه‌ی POST /season/pass/buy
type SeasonPassBuyBody struct {
	Username string `json:"username"`
}

// buySeasonPassHandler بتل‌پس طلایی این فصل را با جم می‌فروشد.
//
// امنیت: قیمت از SeasonPassPremiumPrice خوانده می‌شود نه از بدنه‌ی درخواست، و
// کم کردن جم با یک آپدیت اتمیکِ شرطی (`gems >= price` و `premium != true`)
// انجام می‌شود؛ پس نه می‌شود با جم ناکافی خرید، نه دوبار پول داد.
func buySeasonPassHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req SeasonPassBuyBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	player, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	pass := currentSeasonPass(player)
	if pass.Premium {
		httpError(w, "بتل‌پس طلایی را قبلاً خریده‌ای", http.StatusBadRequest)
		return
	}
	if player.Gems < SeasonPassPremiumPrice {
		httpError(w, "جم کافی نداری", http.StatusBadRequest)
		return
	}

	now := time.Now()

	// اگر رکورد مال فصل قبل بود اول وضعیت فصل جاری نوشته می‌شود، وگرنه
	// آپدیت زیر روی آرایه‌های فصل قبل می‌نشیند.
	if player.SeasonPass.SeasonID != DefaultSeasonID {
		if _, err := col(ColPlayers).UpdateOne(ctx,
			bson.M{"player_id": player.PlayerID},
			bson.M{"$set": bson.M{"season_pass": pass}}); err != nil {
			httpError(w, "خطا در آماده‌سازی پاداش فصل", http.StatusInternalServerError)
			return
		}
	}

	result, err := col(ColPlayers).UpdateOne(ctx,
		bson.M{
			"player_id":             player.PlayerID,
			"season_pass.season_id": DefaultSeasonID,
			"season_pass.premium":   bson.M{"$ne": true},
			"gems":                  bson.M{"$gte": SeasonPassPremiumPrice},
		},
		bson.M{
			"$set": bson.M{"season_pass.premium": true, "updated_at": now},
			"$inc": bson.M{"gems": -SeasonPassPremiumPrice},
		})
	if err != nil {
		httpError(w, "خطا در خرید بتل‌پس", http.StatusInternalServerError)
		return
	}
	if result.ModifiedCount == 0 {
		httpError(w, "خرید انجام نشد", http.StatusBadRequest)
		return
	}

	fresh, err := getPlayerByID(ctx, player.PlayerID)
	if err != nil {
		fresh = player
	}
	level, into, need := levelFromExperience(fresh.Experience)

	response := buildSeasonPassResponse(fresh)
	response["success"] = true
	response["coins"] = fresh.Coins
	response["gems"] = fresh.Gems
	response["experience"] = fresh.Experience
	response["player_level"] = level
	response["player_level_xp"] = into
	response["player_level_max"] = need

	jsonResponse(w, response)
}

// -----------------------------------------------------------------------------
// POST /season/challenges/claim  {username, challenge_id}
// -----------------------------------------------------------------------------

// SeasonChallengeClaimBody بدنه‌ی POST /season/challenges/claim
type SeasonChallengeClaimBody struct {
	Username    string `json:"username"`
	ChallengeID string `json:"challenge_id"`
}

// claimSeasonChallengeHandler جایزه‌ی یک چالش فصل را واریز می‌کند.
//
// امنیت: پیشرفت از PlayerSeasonPass.Stats خوانده می‌شود که فقط از دل نتیجه‌ی
// مسابقه‌ی ثبت‌شده بالا می‌رود؛ کلاینت هیچ‌وقت progress نمی‌فرستد.
func claimSeasonChallengeHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req SeasonChallengeClaimBody
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	challenge, ok := seasonChallengeByID[req.ChallengeID]
	if !ok {
		httpError(w, "این چالش وجود ندارد", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	player, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	pass := currentSeasonPass(player)
	if pass.Stats[string(challenge.Metric)] < challenge.Target {
		httpError(w, "این چالش هنوز تمام نشده", http.StatusBadRequest)
		return
	}

	now := time.Now()

	if player.SeasonPass.SeasonID != DefaultSeasonID {
		if _, err := col(ColPlayers).UpdateOne(ctx,
			bson.M{"player_id": player.PlayerID},
			bson.M{"$set": bson.M{"season_pass": pass}}); err != nil {
			httpError(w, "خطا در آماده‌سازی پاداش فصل", http.StatusInternalServerError)
			return
		}
	}

	if err := ensureArrayFields(ctx, col(ColPlayers),
		bson.M{"player_id": player.PlayerID}, "season_pass.claimed_challenges"); err != nil {
		httpError(w, "خطا در آماده‌سازی پاداش فصل", http.StatusInternalServerError)
		return
	}

	result, err := col(ColPlayers).UpdateOne(ctx,
		bson.M{
			"player_id":                      player.PlayerID,
			"season_pass.season_id":          DefaultSeasonID,
			"season_pass.claimed_challenges": bson.M{"$ne": challenge.ChallengeID},
		},
		bson.M{
			"$addToSet": bson.M{"season_pass.claimed_challenges": challenge.ChallengeID},
			"$inc": bson.M{
				"coins":      challenge.Coins,
				"experience": challenge.XP,
			},
			"$set": bson.M{"updated_at": now},
		})
	if err != nil {
		httpError(w, "خطا در واریز جایزه", http.StatusInternalServerError)
		return
	}
	if result.ModifiedCount == 0 {
		httpError(w, "جایزه‌ی این چالش قبلاً گرفته شده", http.StatusBadRequest)
		return
	}

	// تجربه‌ی چالش به خود بتل‌پس هم اضافه می‌شود
	_ = addSeasonPassXP(ctx, player.PlayerID, challenge.XP)

	fresh, err := getPlayerByID(ctx, player.PlayerID)
	if err != nil {
		fresh = player
	}
	level, into, need := levelFromExperience(fresh.Experience)

	response := buildSeasonPassResponse(fresh)
	response["success"] = true
	response["reward"] = map[string]interface{}{
		"coins": challenge.Coins, "xp": challenge.XP,
	}
	response["coins"] = fresh.Coins
	response["gems"] = fresh.Gems
	response["experience"] = fresh.Experience
	response["player_level"] = level
	response["player_level_xp"] = into
	response["player_level_max"] = need

	jsonResponse(w, response)
}
