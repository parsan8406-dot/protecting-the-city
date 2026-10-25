package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// ColGameModes کاتالوگ حالت‌های بازی چندنفره.
//
// عمداً در دیتابیس نگه داشته می‌شود و نه در کد کلاینت: پاداش و جریمه‌ی هر
// حالت باید بدون آپدیت بازی قابل تنظیم باشد، و مهم‌تر اینکه کلاینت نتواند
// بگوید «من ۵۰ کاپ بردم». حرف آخر را همیشه همین سند می‌زند.
const ColGameModes = "game_modes"

// GameModeDef یک حالت بازی و اقتصادش
type GameModeDef struct {
	ModeID   string `bson:"mode_id" json:"mode_id"`
	Name     string `bson:"name" json:"name"`
	Subtitle string `bson:"subtitle" json:"subtitle"`
	Desc     string `bson:"description" json:"description"`
	TeamSize int    `bson:"team_size" json:"team_size"` // ۴ یعنی ۴ در ۴

	// رنگِ کارت در منو (کلاینت فقط نمایشش می‌دهد)
	Accent string `bson:"accent" json:"accent"`

	// --- پاداشِ برد ---
	WinTrophies int `bson:"win_trophies" json:"win_trophies"`
	WinCoins    int `bson:"win_coins" json:"win_coins"`
	WinXP       int `bson:"win_xp" json:"win_xp"`

	// --- جریمه‌ی باخت (عدد مثبت؛ سرور کمش می‌کند) ---
	LoseTrophies int `bson:"lose_trophies" json:"lose_trophies"`
	LoseCoins    int `bson:"lose_coins" json:"lose_coins"`
	// حتی با باخت هم کمی تجربه می‌دهد تا بازی کردن همیشه ارزش داشته باشد
	LoseXP int `bson:"lose_xp" json:"lose_xp"`

	// حداقل کاپِ لازم برای ورود — قفلِ حالت‌های سخت‌تر
	MinTrophies int `bson:"min_trophies" json:"min_trophies"`

	SortOrder int  `bson:"sort_order" json:"sort_order"`
	IsActive  bool `bson:"is_active" json:"is_active"`

	// هنوز ساخته نشده: کارتش در منو «به زودی...» نشان داده می‌شود ولی نه
	// انتخاب می‌شود و نه وارد صفِ ماچ‌میکینگ.
	ComingSoon bool `bson:"coming_soon" json:"coming_soon"`
}

// defaultGameModes چهار حالتِ فعلی.
//
// اقتصادش عمداً این‌طور چیده شده: هرچه تیم کوچک‌تر، سهمِ هر نفر از نتیجه
// بیشتر است، پس هم پاداش و هم جریمه‌اش سنگین‌تر می‌شود. ۲ در ۲ بیشترین
// نوسان را دارد و ۴ در ۴ امن‌ترین حالت برای شروع است.
func defaultGameModes() []GameModeDef {
	return []GameModeDef{
		{
			ModeID: "strike", Name: "عملیات ضربت", Subtitle: "۴ در ۴",
			Desc:     "نبردِ تیمیِ کلاسیک. هر تیم چهار نفر؛ هر که بیشتر بزند می‌برد.",
			TeamSize: 4, Accent: "#F0B429",
			WinTrophies: 24, WinCoins: 120, WinXP: 60,
			LoseTrophies: 12, LoseCoins: 30, LoseXP: 15,
			MinTrophies: 0, SortOrder: 1, IsActive: true,
		},
		{
			ModeID: "revenge", Name: "عملیات انتقام", Subtitle: "۱ در ۱",
			Desc:     "دو نفره و رو در رو. دو دقیقه وقت داری؛ کشته که شدی چند ثانیه بعد برمی‌گردی و پنج ثانیه محافظ داری. آخرِ وقت هر که بیشتر زده باشد می‌برد.",
			TeamSize: 1, Accent: "#E0453F",
			WinTrophies: 40, WinCoins: 200, WinXP: 95,
			LoseTrophies: 26, LoseCoins: 50, LoseXP: 20,
			MinTrophies: 150, SortOrder: 2, IsActive: true,
		},
		{
			ModeID: "banish", Name: "عملیات حذف شیطان", Subtitle: "۳ در ۳",
			Desc:     "وسطِ نقشه یک شیطان ایستاده. تیمی که بیشتر به او آسیب بزند برنده است — چه شیطان بمیرد، چه وقت تمام شود. مرگ موقتی است — چند ثانیه بعد برمی‌گردی. مراقبِ نفرین‌هایش باش: هر چند ثانیه یک‌جا را نشانه می‌گیرد و دو ثانیه بعد می‌ترکاند.",
			TeamSize: 3, Accent: "#8E44D0",
			WinTrophies: 32, WinCoins: 165, WinXP: 80,
			LoseTrophies: 20, LoseCoins: 40, LoseXP: 18,
			MinTrophies: 80, SortOrder: 3, IsActive: true,
		},
		{
			ModeID: "citypoint", Name: "عملیات امتیاز شهر", Subtitle: "۳ در ۳",
			Desc:     "نقطه‌ی شهر را نگه دار. کشتن مهم است، ولی ماندن مهم‌تر.",
			TeamSize: 3, Accent: "#2E9E7B",
			WinTrophies: 28, WinCoins: 150, WinXP: 70,
			LoseTrophies: 16, LoseCoins: 35, LoseXP: 18,
			MinTrophies: 80, SortOrder: 4, IsActive: true, ComingSoon: true,
		},
	}
}

// seedGameModes حالت‌ها را یک بار می‌نویسد و بعد از آن دست نمی‌زند، تا اگر
// اعدادِ اقتصاد را دستی در دیتابیس تنظیم کردی با هر ری‌استارت پاک نشود.
func seedGameModes(ctx context.Context) error {
	for _, m := range defaultGameModes() {
		count, err := col(ColGameModes).CountDocuments(ctx, bson.M{"mode_id": m.ModeID})
		if err != nil {
			return err
		}
		if count > 0 {
			continue
		}
		if _, err := col(ColGameModes).InsertOne(ctx, m); err != nil {
			return err
		}
	}
	return nil
}

// MigrateGameModes ساختارِ حالت‌هایی که عوض شده‌اند را روی داکیومنت‌های
// قدیمی هم اعمال می‌کند.
//
// seedGameModes عمداً داکیومنتِ موجود را دست نمی‌زند تا اعدادِ اقتصاد که
// دستی تنظیم شده‌اند پاک نشوند. ولی «چند نفره بودنِ» یک حالت اقتصاد نیست،
// خودِ قانونِ بازی است: «عملیات انتقام» دو نفره است (تک به تک) و اگر
// team_size روی ۲ بماند، ماچ‌میکینگ چهار نفر را وارد یک زمینِ دو نفره می‌کند.
func MigrateGameModes(ctx context.Context) error {
	res, err := col(ColGameModes).UpdateOne(ctx,
		bson.M{"mode_id": "revenge", "team_size": bson.M{"$ne": 1}},
		bson.M{"$set": bson.M{
			"team_size": 1,
			"subtitle":  "۱ در ۱",
		}})
	if err != nil {
		return err
	}
	if res.ModifiedCount > 0 {
		fmt.Println("🔁 عملیات انتقام به حالتِ تک‌به‌تک تبدیل شد")
	}

	// «عملیات حذف شیطان» قبلاً فقط اسمش شیطان داشت و در عمل یک راندِ حذفی
	// بود. حالا واقعاً شیطان دارد (demon.go)، پس توضیحِ قدیمی — «تیمِ
	// حذف‌شده برنمی‌گردد» — دقیقاً برعکسِ قانونِ تازه است و باید عوض شود.
	// توضیح اقتصاد نیست، خودِ قانونِ بازی است؛ مثل team_size اینجا جایش است.
	banishDesc := ""
	for _, m := range defaultGameModes() {
		if m.ModeID == "banish" {
			banishDesc = m.Desc
		}
	}

	// «به زودی» خودِ دسترسی به حالت است، نه اقتصاد؛ روی داکیومنتِ قدیمی هم
	// اعمال می‌شود تا حالتِ نیمه‌کاره از دیتابیسِ قبلی باز نماند.
	for _, m := range defaultGameModes() {
		res, err = col(ColGameModes).UpdateOne(ctx,
			bson.M{"mode_id": m.ModeID, "coming_soon": bson.M{"$ne": m.ComingSoon}},
			bson.M{"$set": bson.M{"coming_soon": m.ComingSoon}})
		if err != nil {
			return err
		}
		if res.ModifiedCount > 0 {
			fmt.Printf("🔁 %s: coming_soon=%v\n", m.ModeID, m.ComingSoon)
		}
	}

	if banishDesc != "" {
		res, err = col(ColGameModes).UpdateOne(ctx,
			bson.M{"mode_id": "banish", "description": bson.M{"$ne": banishDesc}},
			bson.M{"$set": bson.M{"description": banishDesc}})
		if err != nil {
			return err
		}
		if res.ModifiedCount > 0 {
			fmt.Println("🔁 عملیات حذف شیطان: توضیحِ حالت با قانونِ تازه هماهنگ شد")
		}
	}
	return nil
}

// loadGameModes حالت‌های فعال را به ترتیب می‌خواند
func loadGameModes(ctx context.Context) ([]GameModeDef, error) {
	opts := options.Find().SetSort(bson.D{{Key: "sort_order", Value: 1}})
	cur, err := col(ColGameModes).Find(ctx, bson.M{"is_active": true}, opts)
	if err != nil {
		return nil, err
	}
	defer cur.Close(ctx)

	var out []GameModeDef
	if err := cur.All(ctx, &out); err != nil {
		return nil, err
	}
	return out, nil
}

// gameModeByID یک حالت را برمی‌دارد
func gameModeByID(ctx context.Context, modeID string) (*GameModeDef, error) {
	var m GameModeDef
	err := col(ColGameModes).FindOne(ctx, bson.M{"mode_id": modeID, "is_active": true}).Decode(&m)
	if err != nil {
		return nil, err
	}
	return &m, nil
}

// getGameModesHandler لیست حالت‌ها + کاپِ فعلی بازیکن و حالتِ انتخابی‌اش.
//
// کاپ را هم می‌فرستیم تا کلاینت بتواند بدون درخواستِ دوم بگوید کدام حالت
// هنوز قفل است — ولی تصمیمِ نهایی‌اش را باز هم سرور در select می‌گیرد.
func getGameModesHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	modes, err := loadGameModes(ctx)
	if err != nil {
		httpError(w, "خواندن حالت‌های بازی ممکن نشد", http.StatusInternalServerError)
		return
	}

	resp := map[string]interface{}{"modes": modes}

	if username := r.URL.Query().Get("username"); username != "" {
		var p PlayerModel
		if err := col(ColPlayers).FindOne(ctx, bson.M{"username": username}).Decode(&p); err == nil {
			resp["trophies"] = p.Trophies
			// صفحه‌ی انتخابِ حالت بک‌گراندِ تمِ همین رنک را نشان می‌دهد
			resp["rank_id"], _ = rankFromTrophies(p.Trophies)
			resp["selected_mode"] = p.SelectedMode
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

// selectGameModeHandler حالتِ انتخابیِ بازیکن را ذخیره می‌کند.
//
// اینجا هم قفلِ کاپ چک می‌شود: کلاینت ممکن است دکمه‌ی قفل‌شده را دور بزند،
// ولی سرور حالتی را که کاپش نمی‌رسد ذخیره نمی‌کند.
func selectGameModeHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "متد اشتباه است", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		Username string `json:"username"`
		ModeID   string `json:"mode_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Username == "" || req.ModeID == "" {
		httpError(w, "درخواست ناقص است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()

	mode, err := gameModeByID(ctx, req.ModeID)
	if err != nil {
		httpError(w, "این حالت بازی وجود ندارد", http.StatusNotFound)
		return
	}
	if mode.ComingSoon {
		httpError(w, "این حالت به زودی می‌آید", http.StatusForbidden)
		return
	}

	var p PlayerModel
	if err := col(ColPlayers).FindOne(ctx, bson.M{"username": req.Username}).Decode(&p); err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}
	if p.Trophies < mode.MinTrophies {
		httpError(w, "برای این حالت هنوز کاپ کافی نداری", http.StatusForbidden)
		return
	}

	if _, err := col(ColPlayers).UpdateOne(ctx,
		bson.M{"username": req.Username},
		bson.M{"$set": bson.M{"selected_mode": mode.ModeID}},
	); err != nil {
		httpError(w, "ذخیره نشد", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true, "selected_mode": mode.ModeID, "mode": mode,
	})
}

// ApplyMatchResult نتیجه‌ی یک مسابقه را روی بازیکن اعمال می‌کند.
//
// همه‌ی اعداد از سندِ حالت می‌آیند، نه از کلاینت. کاپ هیچ‌وقت زیر صفر
// نمی‌رود — باختِ پشتِ سرِ هم نباید بازیکن را به عددِ منفی برساند.
func ApplyMatchResult(ctx context.Context, username, modeID string, won bool) (map[string]interface{}, error) {
	o := OutcomeLoss
	if won {
		o = OutcomeWin
	}
	return ApplyMatchOutcome(ctx, username, modeID, o, 0)
}

// MatchOutcome نتیجه‌ی یک مسابقه برای یک بازیکن
type MatchOutcome int

const (
	OutcomeLoss MatchOutcome = iota
	OutcomeWin
	OutcomeDraw
)

const (
	// coinsPerKill سکه‌ی هر کشته، در هر نتیجه‌ای — سقفش killCoinsCap
	coinsPerKill = 5
	killCoinsCap = 25
)

// lossCoinsOf سکه‌ی باخت. عددِ دیتابیس (lose_coins) اگر ست شده باشد برنده
// است؛ صفر یعنی «تنظیم نشده» و یک‌چهارمِ سکه‌ی برد داده می‌شود — چون
// seedGameModes داکیومنت‌های موجود را دست نمی‌زند و همه‌شان صفر دارند.
func lossCoinsOf(mode *GameModeDef) int {
	if mode.LoseCoins > 0 {
		return mode.LoseCoins
	}
	return mode.WinCoins / 4
}

// ApplyMatchOutcome پاداشِ یک مسابقه را ثبت می‌کند.
//
//	برد:    کاپ + سکه + تجربه‌ی برد
//	مساوی:  بدونِ کاپ، نصفِ سکه‌ی برد، تجربه‌ی باخت
//	باخت:   کاپ کم می‌شود، سکه‌ی باخت، تجربه‌ی باخت
//
// به هر سه، به ازای هر کشته coinsPerKill سکه (تا killCoinsCap) اضافه می‌شود.
// قبلاً باخت هیچ پاداشی نداشت و نیمی از بازی‌ها حسِ «هیچ» می‌داد.
func ApplyMatchOutcome(ctx context.Context, username, modeID string, outcome MatchOutcome, kills int) (map[string]interface{}, error) {
	won := outcome == OutcomeWin
	mode, err := gameModeByID(ctx, modeID)
	if err != nil {
		return nil, err
	}

	var p PlayerModel
	if err := col(ColPlayers).FindOne(ctx, bson.M{"username": username}).Decode(&p); err != nil {
		return nil, err
	}

	trophyDelta := mode.WinTrophies
	coinDelta := mode.WinCoins
	xpDelta := mode.WinXP
	switch outcome {
	case OutcomeDraw:
		trophyDelta = 0
		coinDelta = mode.WinCoins / 2
		xpDelta = mode.LoseXP
	case OutcomeLoss:
		trophyDelta = -mode.LoseTrophies
		coinDelta = lossCoinsOf(mode)
		xpDelta = mode.LoseXP
	}
	if kills > 0 {
		coinDelta += min(kills*coinsPerKill, killCoinsCap)
	}

	// کف صفر برای کاپ و سکه
	if p.Trophies+trophyDelta < 0 {
		trophyDelta = -p.Trophies
	}
	if p.Coins+coinDelta < 0 {
		coinDelta = -p.Coins
	}

	inc := bson.M{
		"trophies":            trophyDelta,
		"coins":               coinDelta,
		"experience":          xpDelta,
		"stats.total_matches": 1,
	}
	switch outcome {
	case OutcomeWin:
		inc["stats.wins"] = 1
	case OutcomeLoss:
		inc["stats.losses"] = 1
	}

	// سطح از تجربه‌ی کل حساب می‌شود و همان‌جا ذخیره — وگرنه تجربه بالا
	// می‌رفت ولی عددِ سطح در پروفایل هیچ‌وقت تکان نمی‌خورد.
	newXP := p.Experience + xpDelta
	newLevel, _, _ := levelFromExperience(newXP)
	set := bson.M{"level": newLevel, "updated_at": time.Now()}

	// رتبه هم با کاپِ تازه هماهنگ شود
	newTrophies := p.Trophies + trophyDelta
	rankID, rankName := rankFromTrophies(newTrophies)
	set["rank.tier_id"] = rankID
	set["rank.tier_name"] = rankName
	if tierIndexOf(rankID) > tierIndexOf(p.Rank.BestTierID) {
		set["rank.best_tier_id"] = rankID
	}

	if _, err := col(ColPlayers).UpdateOne(ctx,
		bson.M{"username": username},
		bson.M{"$inc": inc, "$set": set}); err != nil {
		return nil, err
	}

	// تجربه‌ی مسابقه به نوارِ پاداشِ فصل هم می‌رود. قبلاً فقط /match/result
	// این کار را می‌کرد که کلاینتِ آنلاین هیچ‌وقت صدایش نمی‌زند — پس بازیِ
	// واقعی نوارِ فصل را اصلاً جلو نمی‌برد.
	if xpDelta > 0 && p.PlayerID != "" {
		_ = addSeasonPassXP(ctx, p.PlayerID, xpDelta)
	}

	// دستاوردها را همین‌جا هم بررسی کن.
	//
	// چرا دو جا: آخرِ راند دو گوروتینِ موازی راه می‌افتند — این یکی که
	// «برد/باخت/کاپ/تعداد بازی» را می‌نویسد، و persistProfileStats که
	// «کشته/مرگ/زمان» را. هرکدام ممکن است اول تمام شود، پس اگر بررسی فقط
	// در یکی باشد ممکن است با داده‌ی نیمه اجرا شود و دستاوردی مثل «اولین
	// مسابقه» یک راند دیر باز شود. بررسی خودش idempotent است (چیزی که یک
	// بار باز شده دوباره باز نمی‌شود)، پس اجرای دوباره بی‌ضرر است و هر
	// کدام که دیرتر تمام شود داده‌ی کامل را می‌بیند.
	if p, err := getPlayerByUsername(ctx, username); err == nil {
		checkAndUnlockAchievements(ctx, p)
	}

	return map[string]interface{}{
		"mode_id":      mode.ModeID,
		"won":          won,
		"draw":         outcome == OutcomeDraw,
		"trophy_delta": trophyDelta,
		"coin_delta":   coinDelta,
		"xp_delta":     xpDelta,
		"trophies":     newTrophies,
		"level":        newLevel,
		"level_up":     newLevel > p.Level,
	}, nil
}
