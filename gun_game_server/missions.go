package main

import (
	"context"
	"hash/fnv"
	"sort"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// =============================================================================
// ماموریت‌های روزانه و پاداش فصل
// =============================================================================
//
// همه چیز سمت سرور است. کلاینت فقط `username` می‌فرستد و لیست را می‌گیرد؛
// هیچ‌وقت progress یا مقدار جایزه نمی‌فرستد. پیشرفت ماموریت‌ها فقط از دل
// نتیجه‌ی مسابقه‌ای که سرور خودش ثبت می‌کند بالا می‌رود (submitMatchResultHandler)،
// پس زدن روی «دریافت» بدون بازی کردن هیچ سکه‌ای نمی‌دهد.
//
// چرا انتخاب ماموریت‌ها deterministic است؟ چون اگر تصادفی ذخیره می‌شد،
// بازیکن می‌توانست با پاک کردن رکورد روزش ماموریت‌های ساده‌تر بگیرد. اینجا
// ماموریت‌های هر روزِ هر بازیکن از hash(player_id + day_key) می‌آید — همیشه
// همان است، حتی اگر رکورد دیتابیس پاک شود.

// MissionsResetOffsetMinutes ساعت شروع «روز» ماموریت‌ها نسبت به UTC.
// ۲۱۰ دقیقه = UTC+3:30 یعنی روز ماموریت‌ها نیمه‌شب به وقت ایران عوض می‌شود.
const MissionsResetOffsetMinutes = 210

// DailyMissionsPerDay تعداد ماموریتی که هر روز به هر بازیکن داده می‌شود
const DailyMissionsPerDay = 6

// MissionMetric چیزی که ماموریت آن را می‌شمارد.
// اسم‌ها باید با فیلدهای MatchParticipant بخوانند (applyMatchToMissions).
type MissionMetric string

const (
	MetricMatches      MissionMetric = "matches"       // تعداد بازی انجام‌شده
	MetricWins         MissionMetric = "wins"          // تعداد برد
	MetricKills        MissionMetric = "kills"         // حذف حریف
	MetricAssists      MissionMetric = "assists"       // کمک
	MetricGrenadeKills MissionMetric = "grenade_kills" // حذف با نارنجک
	MetricHeals        MissionMetric = "heals"         // درمانِ هم‌تیمی
	MetricPlaytime     MissionMetric = "playtime"      // دقیقه‌ی بازی
	MetricFlawless     MissionMetric = "flawless"      // بازی بدون حتی یک مرگ
	MetricXP           MissionMetric = "xp"            // تجربه‌ی به‌دست‌آمده
)

// MissionDifficulty برای اینکه هر روز ترکیبی از آسان/متوسط/سخت داده شود،
// نه اینکه شانسی هر شش تا سخت بیفتد.
type MissionDifficulty int

const (
	MissionEasy MissionDifficulty = iota
	MissionMedium
	MissionHard
)

// DailyMissionDef تعریف ثابت یک ماموریت. جایزه‌ها اینجا تعریف شده‌اند و
// کلاینت هیچ‌وقت مقدارشان را نمی‌فرستد.
type DailyMissionDef struct {
	MissionID  string            `json:"mission_id"`
	Title      string            `json:"title"`  // متن فارسی که در UI نشان داده می‌شود
	Desc       string            `json:"desc"`   // یک خط توضیح زیر عنوان
	Metric     MissionMetric     `json:"metric"` // چه چیزی شمرده می‌شود
	Target     int               `json:"target"` // چند تا لازم است
	XP         int               `json:"xp"`     // تجربه‌ی جایزه
	Coins      int               `json:"coins"`  // سکه‌ی جایزه
	Icon       string            `json:"icon"`   // شناسه‌ی آیکن (کلاینت به فایل نگاشت می‌کند)
	Difficulty MissionDifficulty `json:"difficulty"`
}

// DailyMissionPool کاتالوگ ماموریت‌ها. هر روز شش تا از این‌ها انتخاب می‌شود.
//
// جایزه‌ها عمداً با سختی بالا می‌روند: آسان ~۱۵۰xp، متوسط ~۳۰۰xp، سخت ~۶۰۰xp.
// اگر ماموریت جدیدی اضافه کردی فقط ته لیست بگذار — ترتیب روی انتخابِ
// deterministic اثر ندارد چون بر اساس mission_id مرتب می‌شود، نه ایندکس.
var DailyMissionPool = []DailyMissionDef{
	// --- آسان ---
	{MissionID: "play_2", Title: "۲ بازی انجام دهید",
		Desc:   "در هر حالتی ۲ بازی کامل انجام دهید.",
		Metric: MetricMatches, Target: 2,
		XP: 150, Coins: 200, Icon: "match", Difficulty: MissionEasy},
	{MissionID: "kill_10", Title: "۱۰ کیل داشته باشید",
		Desc:   "در هر حالت ۱۰ حریف را از بین ببرید.",
		Metric: MetricKills, Target: 10,
		XP: 150, Coins: 200, Icon: "kill", Difficulty: MissionEasy},
	{MissionID: "win_1", Title: "۱ بازی را ببرید",
		Desc:   "در یک مسابقه به عنوان برنده خارج شوید.",
		Metric: MetricWins, Target: 1,
		XP: 180, Coins: 250, Icon: "win", Difficulty: MissionEasy},
	{MissionID: "assist_5", Title: "۵ بار به هم‌تیمی کمک کنید",
		Desc:   "۵ اسیست برای هم‌تیمی‌های خود ثبت کنید.",
		Metric: MetricAssists, Target: 5,
		XP: 150, Coins: 200, Icon: "assist", Difficulty: MissionEasy},
	{MissionID: "playtime_15", Title: "۱۵ دقیقه بازی کنید",
		Desc:   "به مدت ۱۵ دقیقه در بازی حضور داشته باشید.",
		Metric: MetricPlaytime, Target: 15,
		XP: 150, Coins: 180, Icon: "time", Difficulty: MissionEasy},

	// --- متوسط ---
	{MissionID: "kill_25", Title: "۲۵ کیل داشته باشید",
		Desc:   "در حالت‌های مختلف ۲۵ حریف را حذف کنید.",
		Metric: MetricKills, Target: 25,
		XP: 300, Coins: 450, Icon: "kill", Difficulty: MissionMedium},
	{MissionID: "win_3", Title: "۳ بازی را ببرید",
		Desc:   "در ۳ مسابقه به عنوان برنده خارج شوید.",
		Metric: MetricWins, Target: 3,
		XP: 320, Coins: 500, Icon: "win", Difficulty: MissionMedium},
	{MissionID: "grenade_5", Title: "۵ حریف را با نارنجک بزنید",
		Desc:   "۵ حریف را با انفجار نارنجک از بین ببرید.",
		Metric: MetricGrenadeKills, Target: 5,
		XP: 300, Coins: 450, Icon: "grenade", Difficulty: MissionMedium},
	{MissionID: "heal_10", Title: "۱۰ بار هم‌تیمی را درمان کنید",
		Desc:   "۱۰ بار جان هم‌تیمی‌های خود را پر کنید.",
		Metric: MetricHeals, Target: 10,
		XP: 280, Coins: 400, Icon: "heal", Difficulty: MissionMedium},
	{MissionID: "play_6", Title: "۶ بازی انجام دهید",
		Desc:   "در حالت‌های مختلف ۶ بازی انجام دهید.",
		Metric: MetricMatches, Target: 6,
		XP: 300, Coins: 420, Icon: "match", Difficulty: MissionMedium},
	{MissionID: "xp_1500", Title: "۱۵۰۰ تجربه جمع کنید",
		Desc:   "در طول امروز ۱۵۰۰ امتیاز تجربه به دست آورید.",
		Metric: MetricXP, Target: 1500,
		XP: 300, Coins: 400, Icon: "xp", Difficulty: MissionMedium},

	// --- سخت ---
	{MissionID: "kill_60", Title: "۶۰ کیل داشته باشید",
		Desc:   "در حالت‌های مختلف ۶۰ حریف را حذف کنید.",
		Metric: MetricKills, Target: 60,
		XP: 600, Coins: 900, Icon: "kill", Difficulty: MissionHard},
	{MissionID: "win_6", Title: "۶ بازی را ببرید",
		Desc:   "در ۶ مسابقه به عنوان برنده خارج شوید.",
		Metric: MetricWins, Target: 6,
		XP: 650, Coins: 1000, Icon: "win", Difficulty: MissionHard},
	{MissionID: "flawless_2", Title: "۲ بازی بدون مرگ تمام کنید",
		Desc:   "۲ مسابقه را بدون حتی یک بار کشته شدن تمام کنید.",
		Metric: MetricFlawless, Target: 2,
		XP: 700, Coins: 1100, Icon: "flawless", Difficulty: MissionHard},
	{MissionID: "playtime_60", Title: "۶۰ دقیقه بازی کنید",
		Desc:   "به مدت ۶۰ دقیقه در بازی حضور داشته باشید.",
		Metric: MetricPlaytime, Target: 60,
		XP: 600, Coins: 850, Icon: "time", Difficulty: MissionHard},
	{MissionID: "grenade_15", Title: "۱۵ حریف را با نارنجک بزنید",
		Desc:   "۱۵ حریف را با انفجار نارنجک از بین ببرید.",
		Metric: MetricGrenadeKills, Target: 15,
		XP: 620, Coins: 900, Icon: "grenade", Difficulty: MissionHard},
}

// DailyMissionShape ترکیب سختی ماموریت‌های هر روز — دو آسان، دو متوسط، دو سخت.
// جمعش باید DailyMissionsPerDay بشود.
var DailyMissionShape = []MissionDifficulty{
	MissionEasy, MissionEasy,
	MissionMedium, MissionMedium,
	MissionHard, MissionHard,
}

// missionDefByID برای پیدا کردن سریع تعریف یک ماموریت
var missionDefByID = func() map[string]DailyMissionDef {
	m := make(map[string]DailyMissionDef, len(DailyMissionPool))
	for _, def := range DailyMissionPool {
		m[def.MissionID] = def
	}
	return m
}()

// -----------------------------------------------------------------------------
// جایزه‌ی روزانه (نوار پله‌ای بالای صفحه‌ی ماموریت‌ها)
// -----------------------------------------------------------------------------
//
// جدا از خودِ ماموریت‌هاست: هر ماموریتی که «دریافت» شود یک امتیاز به شمارنده‌ی
// امروز اضافه می‌کند و روی رسیدن به ۲ / ۴ / ۶ امتیاز یک صندوق باز می‌شود.
// آخرین پله (۶ از ۶) همان کارت «پاداش روزانه» کنار صفحه است.
//
// چرا شمارنده «ماموریت‌های claim شده» است و نه «تمام‌شده»؟ چون همان عددی است
// که buildMissionsResponse قبلاً برمی‌گرداند و بازیکن هم آن را روی نوار می‌بیند؛
// دو منبع حقیقت جدا برای یک عدد درست نمی‌کنیم.

// DailyBonusTier یک پله‌ی جایزه‌ی روزانه.
// State سمت سرور پر می‌شود: locked | ready | claimed
type DailyBonusTier struct {
	Need  int    `json:"need"`  // چند ماموریت باید دریافت شده باشد
	Coins int    `json:"coins"` // سکه‌ی جایزه
	Gems  int    `json:"gems"`  // جم جایزه
	Icon  string `json:"icon"`  // شناسه‌ی آیکن صندوق (کلاینت به فایل نگاشت می‌کند)
	State string `json:"state"`
}

// DailyBonusTiers پله‌های جایزه‌ی روزانه.
// باید بر اساس Need صعودی بماند — کلاینت به همین ترتیب روی نوار می‌چیندشان.
var DailyBonusTiers = []DailyBonusTier{
	{Need: 2, Coins: 400, Gems: 0, Icon: "chest_common"},
	{Need: 4, Coins: 700, Gems: 15, Icon: "chest_rare"},
	{Need: 6, Coins: 1500, Gems: 40, Icon: "chest_legend"},
}

// dailyBonusTierByNeed پیدا کردن یک پله از روی Need
func dailyBonusTierByNeed(need int) (DailyBonusTier, bool) {
	for _, tier := range DailyBonusTiers {
		if tier.Need == need {
			return tier, true
		}
	}
	return DailyBonusTier{}, false
}

// dailyBonusMaxNeed بزرگ‌ترین Need — سقف نوار پیشرفت جایزه‌ی روزانه
func dailyBonusMaxNeed() int {
	max := 0
	for _, tier := range DailyBonusTiers {
		if tier.Need > max {
			max = tier.Need
		}
	}
	if max < 1 {
		return 1
	}
	return max
}

// buildDailyBonusView وضعیت هر پله را از روی «چند ماموریت دریافت شده» می‌سازد.
// همان تابعی که هم پاسخ /missions/daily و هم اعتبارسنجی دریافت از آن می‌آید،
// پس چیزی که UI «آماده» نشان می‌دهد دقیقاً همانی است که سرور اجازه می‌دهد.
func buildDailyBonusView(doc *DailyMissionDoc, claimedCount int) ([]DailyBonusTier, int) {
	taken := map[int]bool{}
	for _, need := range doc.BonusClaimed {
		taken[need] = true
	}

	view := make([]DailyBonusTier, 0, len(DailyBonusTiers))
	ready := 0
	for _, tier := range DailyBonusTiers {
		switch {
		case taken[tier.Need]:
			tier.State = "claimed"
		case claimedCount >= tier.Need:
			tier.State = "ready"
			ready++
		default:
			tier.State = "locked"
		}
		view = append(view, tier)
	}
	return view, ready
}

// -----------------------------------------------------------------------------
// روزِ ماموریت‌ها
// -----------------------------------------------------------------------------

// missionsLocation منطقه‌ی زمانی‌ای که «روز» ماموریت‌ها با آن حساب می‌شود
var missionsLocation = time.FixedZone("missions", MissionsResetOffsetMinutes*60)

// missionDayKey کلید روز جاری ("2026-08-30"). همه‌ی رکوردهای روزانه با این
// کلید ذخیره می‌شوند تا ریست روزانه فقط یعنی «کلید عوض شد».
func missionDayKey(now time.Time) string {
	return now.In(missionsLocation).Format("2006-01-02")
}

// missionDayEnd لحظه‌ی ریست بعدی (نیمه‌شب بعدی به وقت ماموریت‌ها)
func missionDayEnd(now time.Time) time.Time {
	local := now.In(missionsLocation)
	midnight := time.Date(local.Year(), local.Month(), local.Day(), 0, 0, 0, 0, missionsLocation)
	return midnight.Add(24 * time.Hour)
}

// missionSecondsLeft چند ثانیه تا ریست بعدی مانده — تایمر کلاینت از این می‌آید.
// عمداً کلاینت خودش ساعت را حساب نمی‌کند تا عوض کردن ساعت گوشی اثری نداشته باشد.
func missionSecondsLeft(now time.Time) int {
	left := int(missionDayEnd(now).Sub(now).Seconds())
	if left < 0 {
		return 0
	}
	return left
}

// -----------------------------------------------------------------------------
// انتخاب ماموریت‌های روز
// -----------------------------------------------------------------------------

// pickDailyMissions ماموریت‌های امروزِ یک بازیکن را برمی‌گرداند.
//
// deterministic است: برای یک (player_id, day_key) همیشه همان خروجی می‌آید.
// پس اگر کسی رکورد دیتابیسش را هم پاک کند، ماموریت‌های ساده‌تری گیرش نمی‌آید.
func pickDailyMissions(playerID, dayKey string) []DailyMissionDef {
	// ماموریت‌ها را بر اساس سختی دسته می‌کنیم و هر دسته را با mission_id مرتب
	// می‌کنیم تا ترتیبِ تعریف در فایل روی خروجی اثر نگذارد.
	byDifficulty := map[MissionDifficulty][]DailyMissionDef{}
	for _, def := range DailyMissionPool {
		byDifficulty[def.Difficulty] = append(byDifficulty[def.Difficulty], def)
	}
	for difficulty := range byDifficulty {
		bucket := byDifficulty[difficulty]
		sort.Slice(bucket, func(i, j int) bool {
			return bucket[i].MissionID < bucket[j].MissionID
		})
		byDifficulty[difficulty] = bucket
	}

	seed := missionSeed(playerID, dayKey)
	picked := make([]DailyMissionDef, 0, DailyMissionsPerDay)
	used := map[string]bool{}
	usedMetric := map[MissionMetric]bool{}

	// برای هر جای خالی، از دسته‌ی موردنظر یکی برمی‌داریم.
	//
	// دو دور می‌زنیم: دور اول فقط ماموریتی را قبول می‌کنیم که متریکش هنوز
	// استفاده نشده باشد. بدون این کار ممکن بود روزی «۱ برد / ۳ برد / ۶ برد»
	// بیفتد که عملاً یک ماموریت است — با تمام کردن سخت‌ترین، بقیه هم تمام
	// می‌شوند. اگر دسته چیز دیگری نداشت، دور دوم تکرار متریک را می‌پذیرد.
	for slot, difficulty := range DailyMissionShape {
		bucket := byDifficulty[difficulty]
		if len(bucket) == 0 {
			continue
		}
		start := int(seed>>(uint(slot)*8)) % len(bucket)
		if start < 0 {
			start += len(bucket)
		}

		chosen := -1
		for pass := 0; pass < 2 && chosen < 0; pass++ {
			for offset := 0; offset < len(bucket); offset++ {
				index := (start + offset) % len(bucket)
				def := bucket[index]
				if used[def.MissionID] {
					continue
				}
				if pass == 0 && usedMetric[def.Metric] {
					continue
				}
				chosen = index
				break
			}
		}
		if chosen < 0 {
			continue
		}

		def := bucket[chosen]
		used[def.MissionID] = true
		usedMetric[def.Metric] = true
		picked = append(picked, def)
	}

	return picked
}

// missionSeed عدد ثابتِ روزِ یک بازیکن
func missionSeed(playerID, dayKey string) uint64 {
	h := fnv.New64a()
	_, _ = h.Write([]byte(playerID))
	_, _ = h.Write([]byte("|"))
	_, _ = h.Write([]byte(dayKey))
	return h.Sum64()
}

// -----------------------------------------------------------------------------
// خواندن / ساختن رکورد روزانه
// -----------------------------------------------------------------------------

// loadOrCreateDailyMissions رکورد امروزِ بازیکن را می‌آورد و اگر نبود می‌سازد.
//
// رکورد روز قبل دست نمی‌خورد (تاریخچه می‌ماند) — فقط دیگر خوانده نمی‌شود،
// چون کوئری همیشه day_key امروز را می‌خواهد. این یعنی «ریست روزانه» خودش
// اتفاق می‌افتد و به هیچ cron job ای نیاز ندارد.
func loadOrCreateDailyMissions(
	ctx context.Context, playerID string, now time.Time,
) (*DailyMissionDoc, error) {
	dayKey := missionDayKey(now)

	var doc DailyMissionDoc
	err := col(ColDailyMissions).
		FindOne(ctx, bson.M{"player_id": playerID, "day_key": dayKey}).
		Decode(&doc)
	if err == nil {
		// اگر کاتالوگ عوض شده و ماموریتی از رکورد افتاده، جای خالی را پر می‌کنیم
		if repaired := repairMissionStates(&doc, playerID, dayKey); repaired {
			_, _ = col(ColDailyMissions).UpdateOne(ctx,
				bson.M{"player_id": playerID, "day_key": dayKey},
				bson.M{"$set": bson.M{"missions": doc.Missions, "updated_at": now}})
		}
		return &doc, nil
	}
	if err != mongo.ErrNoDocuments {
		return nil, err
	}

	// اولین بار در این روز
	defs := pickDailyMissions(playerID, dayKey)
	states := make([]PlayerMissionState, 0, len(defs))
	for _, def := range defs {
		states = append(states, PlayerMissionState{MissionID: def.MissionID})
	}

	doc = DailyMissionDoc{
		PlayerID: playerID,
		DayKey:   dayKey,
		Missions: states,
		// آرایه‌ی خالی نه nil: Go یک slice خالیِ nil را null ذخیره می‌کند و
		// $addToSet روی null خطا می‌دهد — یعنی صندوق هیچ‌وقت باز نمی‌شد
		BonusClaimed: []int{},
		CreatedAt:    now,
		UpdatedAt:    now,
	}

	if _, err := col(ColDailyMissions).InsertOne(ctx, doc); err != nil {
		// اگر همزمان دو درخواست آمده باشند، یکی‌شان duplicate می‌خورد —
		// آن یکی رکورد را می‌خوانیم، خطا نیست.
		if mongo.IsDuplicateKeyError(err) {
			var existing DailyMissionDoc
			if e := col(ColDailyMissions).
				FindOne(ctx, bson.M{"player_id": playerID, "day_key": dayKey}).
				Decode(&existing); e == nil {
				return &existing, nil
			}
		}
		return nil, err
	}

	return &doc, nil
}

// repairMissionStates اگر ماموریتی از کاتالوگ حذف شده باشد رکورد را با
// انتخابِ امروز هماهنگ می‌کند. true یعنی چیزی عوض شد.
func repairMissionStates(doc *DailyMissionDoc, playerID, dayKey string) bool {
	expected := pickDailyMissions(playerID, dayKey)

	have := map[string]PlayerMissionState{}
	for _, state := range doc.Missions {
		have[state.MissionID] = state
	}

	rebuilt := make([]PlayerMissionState, 0, len(expected))
	changed := len(doc.Missions) != len(expected)
	for _, def := range expected {
		if state, ok := have[def.MissionID]; ok {
			rebuilt = append(rebuilt, state)
			continue
		}
		rebuilt = append(rebuilt, PlayerMissionState{MissionID: def.MissionID})
		changed = true
	}

	if changed {
		doc.Missions = rebuilt
	}
	return changed
}

// -----------------------------------------------------------------------------
// پیشرفت ماموریت‌ها
// -----------------------------------------------------------------------------

// missionDeltas مقدارِ اضافه‌شده به هر متریک از یک مسابقه.
// از روی MatchParticipant ساخته می‌شود، نه از روی چیزی که کلاینت ادعا می‌کند
// (کلاینت اصلاً به این تابع دسترسی ندارد).
func missionDeltas(part MatchParticipant, durationSeconds int64) map[MissionMetric]int {
	deltas := map[MissionMetric]int{
		MetricMatches:      1,
		MetricKills:        part.Kills,
		MetricAssists:      part.Assists,
		MetricGrenadeKills: part.GrenadeKills,
		MetricHeals:        part.HealsGiven,
		MetricXP:           part.XPGained,
		MetricPlaytime:     int(durationSeconds / 60),
	}
	if part.Won {
		deltas[MetricWins] = 1
	}
	if part.Deaths == 0 {
		deltas[MetricFlawless] = 1
	}
	return deltas
}

// applyMatchToMissions پیشرفت ماموریت‌های امروزِ بازیکن را بعد از یک مسابقه بالا می‌برد.
//
// خطا را برمی‌گرداند ولی صدازننده می‌تواند نادیده بگیرد: اگر ماموریت‌ها
// آپدیت نشوند نباید ثبت خودِ مسابقه شکست بخورد.
func applyMatchToMissions(
	ctx context.Context, playerID string, part MatchParticipant, durationSeconds int64,
) error {
	doc, err := loadOrCreateDailyMissions(ctx, playerID, time.Now())
	if err != nil {
		return err
	}

	deltas := missionDeltas(part, durationSeconds)
	prevSeconds := doc.PlaySeconds
	doc.PlaySeconds, deltas[MetricPlaytime] = carryPlaySeconds(prevSeconds, durationSeconds)
	changed := doc.PlaySeconds != prevSeconds

	for i := range doc.Missions {
		state := &doc.Missions[i]
		def, ok := missionDefByID[state.MissionID]
		if !ok {
			continue
		}
		// ماموریتِ گرفته‌شده دیگر پیشرفت نمی‌کند
		if state.Claimed {
			continue
		}
		delta := deltas[def.Metric]
		if delta <= 0 {
			continue
		}
		if state.Progress >= def.Target {
			continue
		}
		state.Progress += delta
		if state.Progress > def.Target {
			state.Progress = def.Target
		}
		changed = true
	}

	if !changed {
		return nil
	}

	now := time.Now()
	_, err = col(ColDailyMissions).UpdateOne(ctx,
		bson.M{"player_id": playerID, "day_key": doc.DayKey},
		bson.M{"$set": bson.M{"missions": doc.Missions, "play_seconds": doc.PlaySeconds, "updated_at": now}})
	return err
}

// carryPlaySeconds ثانیه‌های این مسابقه را به جمعِ قبلی اضافه می‌کند و
// برمی‌گرداند چند «دقیقه‌ی کامل» تازه رد شد — باقی‌مانده‌ی زیرِ یک دقیقه
// برای مسابقه‌ی بعد می‌ماند.
func carryPlaySeconds(prev, add int64) (int64, int) {
	if add < 0 {
		add = 0
	}
	total := prev + add
	return total, int(total/60 - prev/60)
}

// -----------------------------------------------------------------------------
// پاداش فصل (بتل‌پس)
// -----------------------------------------------------------------------------

// SeasonPassMaxLevel تعداد پله‌های پاداش فصل
const SeasonPassMaxLevel = 30

// SeasonPassBaseXP تجربه‌ی لازم برای پله‌ی اول
const SeasonPassBaseXP = 1000

// SeasonPassStepXP هر پله چقدر از پله‌ی قبل سنگین‌تر است
const SeasonPassStepXP = 250

// seasonPassLevelCost تجربه‌ی لازم برای رد کردن یک پله‌ی مشخص (۱-based).
// پله‌ی ۱ → ۱۰۰۰، پله‌ی ۲ → ۱۲۵۰، ... پله‌ی ۳۰ → ۸۲۵۰
func seasonPassLevelCost(level int) int {
	if level < 1 {
		return SeasonPassBaseXP
	}
	return SeasonPassBaseXP + (level-1)*SeasonPassStepXP
}

// seasonPassTotalForLevel مجموع تجربه‌ی لازم برای رسیدن به ابتدای یک پله
func seasonPassTotalForLevel(level int) int {
	total := 0
	for i := 1; i < level; i++ {
		total += seasonPassLevelCost(i)
	}
	return total
}

// seasonPassXPRequired تجربه‌ی لازم برای اینکه یک پله *کامل* شود و جایزه‌اش
// آزاد شود. تنها مرجع این سوال است — هم پاسخ /season/pass و هم هندلر دریافت
// از همین استفاده می‌کنند تا آنچه UI «آماده» نشان می‌دهد دقیقاً همان چیزی
// باشد که سرور اجازه‌ی گرفتنش را می‌دهد.
//
// دقت: پله‌ی ۱ با تجربه‌ی صفر آزاد نیست؛ باید کلِ هزینه‌ی پله‌ی ۱ جمع شود.
func seasonPassXPRequired(level int) int {
	return seasonPassTotalForLevel(level) + seasonPassLevelCost(level)
}

// seasonPassProgress از تجربه‌ی فصل، پله و پیشرفتِ داخل پله را حساب می‌کند.
// خروجی: پله (۱ تا SeasonPassMaxLevel)، تجربه‌ی داخل پله، تجربه‌ی لازم پله.
func seasonPassProgress(seasonXP int) (level, into, need int) {
	if seasonXP < 0 {
		seasonXP = 0
	}
	level = 1
	remaining := seasonXP
	for level < SeasonPassMaxLevel {
		cost := seasonPassLevelCost(level)
		if remaining < cost {
			return level, remaining, cost
		}
		remaining -= cost
		level++
	}
	// پله‌ی آخر: نوار پر می‌ماند
	last := seasonPassLevelCost(SeasonPassMaxLevel)
	return SeasonPassMaxLevel, last, last
}

// SeasonPassReward جایزه‌ی یک پله‌ی پاداش فصل
type SeasonPassReward struct {
	Level int    `json:"level"`
	Coins int    `json:"coins"`
	Gems  int    `json:"gems"`
	Cups  int    `json:"cups"`
	Title string `json:"title"`
	Icon  string `json:"icon"`
	// SkinID اسکینی که این پله می‌دهد (skins.go). خالی یعنی هیچ.
	SkinID string `json:"skin_id,omitempty"`
}

// seasonPassReward جایزه‌ی یک پله را می‌سازد.
//
// الگو عمداً ساده و قابل پیش‌بینی است تا بازیکن بداند دارد به چه می‌رسد:
//   - هر پله سکه می‌دهد (با پله بالا می‌رود)
//   - هر ۵ پله یک کاپ فصل
//   - هر ۱۰ پله جم
func seasonPassReward(level int) SeasonPassReward {
	reward := SeasonPassReward{
		Level: level,
		Coins: 300 + level*50,
		Icon:  "coin",
		Title: "سکه",
	}

	if level%5 == 0 {
		reward.Cups = 1
		reward.Icon = "cup"
		reward.Title = "کاپ فصل + سکه"
	}
	if level%10 == 0 {
		reward.Gems = 25 + (level/10)*15
		reward.Icon = "gem"
		reward.Title = "جم + کاپ فصل"
	}
	if level == SeasonPassMaxLevel {
		reward.Gems = 250
		reward.Cups = 3
		reward.Coins = 5000
		reward.Icon = "trophy"
		reward.Title = "جایزه‌ی بزرگ پایان فصل"
	}

	return reward
}

// SeasonPassLadder همه‌ی پله‌ها — صفحه‌ی پاداش فصل این را نشان می‌دهد
func SeasonPassLadder() []SeasonPassReward {
	ladder := make([]SeasonPassReward, 0, SeasonPassMaxLevel)
	for level := 1; level <= SeasonPassMaxLevel; level++ {
		ladder = append(ladder, seasonPassReward(level))
	}
	return ladder
}

// currentSeasonPass وضعیت پاداش فصل بازیکن را برمی‌گرداند.
//
// اگر بازیکن هنوز فیلد season_pass ندارد یا مال فصل قبل است، یک وضعیت خالیِ
// فصل جاری برمی‌گردد. ریست فصل همین‌جا اتفاق می‌افتد و به cron نیاز ندارد.
func currentSeasonPass(player *PlayerModel) PlayerSeasonPass {
	pass := player.SeasonPass
	if pass.SeasonID != DefaultSeasonID {
		return PlayerSeasonPass{
			SeasonID:          DefaultSeasonID,
			XP:                0,
			ClaimedLevels:     []int{},
			ClaimedPremium:    []int{},
			ClaimedChallenges: []string{},
			Stats:             map[string]int{},
		}
	}
	if pass.ClaimedLevels == nil {
		pass.ClaimedLevels = []int{}
	}
	if pass.ClaimedPremium == nil {
		pass.ClaimedPremium = []int{}
	}
	if pass.ClaimedChallenges == nil {
		pass.ClaimedChallenges = []string{}
	}
	if pass.Stats == nil {
		pass.Stats = map[string]int{}
	}
	return pass
}

// addSeasonPassXP تجربه‌ی فصل بازیکن را بالا می‌برد.
//
// اگر رکورد مال فصل قبل باشد اول صفر می‌شود (نه اینکه روی هم جمع شود).
func addSeasonPassXP(ctx context.Context, playerID string, amount int) error {
	if amount <= 0 {
		return nil
	}
	return incSeasonPass(ctx, playerID, bson.M{"season_pass.xp": amount})
}

// incSeasonPass شمارنده‌های بتل‌پسِ فصلِ جاری را اتمی بالا می‌برد.
//
// قبلاً هر نویسنده کلِ season_pass را می‌خواند، عوض می‌کرد و کامل
// برمی‌گرداند. آخرِ هر مسابقه دو نویسنده هم‌زمان کار می‌کنند (تجربه‌ی بتل‌پس
// در ApplyMatchOutcome و آمارِ چالش‌ها در persistMatchMissions) و هر کدام که
// دیرتر می‌رسید کارِ دیگری را پاک می‌کرد.
func incSeasonPass(ctx context.Context, playerID string, inc bson.M) error {
	if err := ensureSeasonPass(ctx, playerID); err != nil {
		return err
	}
	_, err := col(ColPlayers).UpdateOne(ctx,
		bson.M{"player_id": playerID, "season_pass.season_id": DefaultSeasonID},
		bson.M{"$inc": inc, "$set": bson.M{"updated_at": time.Now()}})
	return err
}

// ensureSeasonPass اگر بتل‌پسِ بازیکن مالِ فصلِ دیگری است (یا هنوز ندارد)
// یک بتل‌پسِ خالیِ فصلِ جاری می‌نشاند، و stats را اگر null است {} می‌کند تا
// $inc رویش کار کند. هر دو شرط‌دارند، پس اجرای هم‌زمان بی‌خطر است.
func ensureSeasonPass(ctx context.Context, playerID string) error {
	fresh := PlayerSeasonPass{
		SeasonID:          DefaultSeasonID,
		ClaimedLevels:     []int{},
		ClaimedPremium:    []int{},
		ClaimedChallenges: []string{},
		Stats:             map[string]int{},
	}
	if _, err := col(ColPlayers).UpdateOne(ctx,
		bson.M{"player_id": playerID, "season_pass.season_id": bson.M{"$ne": DefaultSeasonID}},
		bson.M{"$set": bson.M{"season_pass": fresh}}); err != nil {
		return err
	}
	_, err := col(ColPlayers).UpdateOne(ctx,
		bson.M{"player_id": playerID, "season_pass.season_id": DefaultSeasonID,
			"$or": bson.A{bson.M{"season_pass.stats": nil}, bson.M{"season_pass.stats": bson.M{"$type": "array"}}}},
		bson.M{"$set": bson.M{"season_pass.stats": bson.M{}}})
	return err
}

// -----------------------------------------------------------------------------
// ایندکس‌ها
// -----------------------------------------------------------------------------

// dailyMissionIndexes ایندکس‌های کالکشن ماموریت‌های روزانه.
// (player_id, day_key) یکتاست تا برای یک بازیکن در یک روز دو رکورد ساخته نشود.
func dailyMissionIndexes() []mongo.IndexModel {
	return []mongo.IndexModel{
		{
			Keys:    bson.D{{Key: "player_id", Value: 1}, {Key: "day_key", Value: 1}},
			Options: options.Index().SetUnique(true).SetName("player_day_unique"),
		},
		{
			// رکوردهای قدیمی بعد از ۳۰ روز خودشان پاک می‌شوند
			Keys:    bson.D{{Key: "created_at", Value: 1}},
			Options: options.Index().SetExpireAfterSeconds(30 * 24 * 3600).SetName("daily_missions_ttl"),
		},
	}
}

// =============================================================================
// بتل‌پس طلایی + چالش‌های فصل
// =============================================================================
//
// هر پله دو جایزه دارد: یکی رایگان (seasonPassReward) و یکی طلایی
// (seasonPassPremiumReward). جایزه‌ی طلایی فقط وقتی گرفته می‌شود که بازیکن
// بتل‌پس طلایی این فصل را خریده باشد — و آن هم سمت سرور از روی فیلد
// PlayerSeasonPass.Premium چک می‌شود، نه از روی چیزی که کلاینت می‌گوید.

// SeasonPassPremiumPrice قیمت بتل‌پس طلایی (جم)
const SeasonPassPremiumPrice = 900

// SeasonName و SeasonSubtitle چیزی که روی بنر صفحه نوشته می‌شود
const (
	SeasonName     = "فصل ۱"
	SeasonSubtitle = "جنگ سایه‌ها"
	SeasonEndsAt   = "۱۴۰۴/۰۷/۳۰"
)

// seasonPassPremiumReward جایزه‌ی طلاییِ یک پله.
//
// عمداً سخاوتمندتر از رایگان است (تقریباً دو برابر سکه، جم بیشتر و مرتب‌تر)
// وگرنه خریدنش دلیلی ندارد.
func seasonPassPremiumReward(level int) SeasonPassReward {
	reward := SeasonPassReward{
		Level: level,
		Coins: 500 + level*90,
		Icon:  "coin",
		Title: "سکه",
	}

	if level%3 == 0 {
		reward.Gems = 20 + (level/3)*5
		reward.Icon = "gem"
		reward.Title = "جم + سکه"
	}
	if level%5 == 0 {
		reward.Cups = 1
		reward.Icon = "cup"
		reward.Title = "کاپ فصل + سکه"
	}
	// پله‌های نشانه‌دارِ مسیر طلایی اسکین می‌دهند (کاتالوگ در skins.go).
	// بتل‌پس تنها راه گرفتن اسکین است.
	if skin, ok := skinForPassLevel(level); ok {
		reward.SkinID = skin.SkinID
		if skin.Category == "weapon" {
			reward.Icon = "weapon_skin"
			reward.Title = "اسکین سلاح: " + skin.Name
		} else {
			reward.Icon = "char_skin"
			reward.Title = "اسکین کاراکتر: " + skin.Name
		}
	}

	if level == SeasonPassMaxLevel {
		reward.Gems = 600
		reward.Cups = 5
		reward.Coins = 12000
		reward.Icon = "trophy"
		reward.Title = "جایزه‌ی افسانه‌ای پایان فصل"
	}

	// کفِ مسیر طلایی همیشه جایزه‌ی رایگانِ همان پله است.
	//
	// بدون این، الگوهای دو مسیر روی بعضی پله‌ها همدیگر را قطع می‌کردند و
	// طلایی از رایگان بدتر می‌شد (مثلاً پله‌ی ۱۰: رایگان ۴۰ جم می‌داد و
	// طلایی هیچ). این‌طوری هرکس بعداً جدول رایگان را دست بزند، طلایی
	// خودبه‌خود جلو می‌ماند.
	free := seasonPassReward(level)
	if reward.Gems < free.Gems {
		reward.Gems = free.Gems
		if reward.Icon == "coin" {
			reward.Icon = free.Icon
			reward.Title = free.Title
		}
	}
	if reward.Cups < free.Cups {
		reward.Cups = free.Cups
	}
	if reward.Coins <= free.Coins {
		reward.Coins = free.Coins * 2
	}

	return reward
}

// SeasonPassPremiumLadder همه‌ی پله‌های مسیر طلایی
func SeasonPassPremiumLadder() []SeasonPassReward {
	ladder := make([]SeasonPassReward, 0, SeasonPassMaxLevel)
	for level := 1; level <= SeasonPassMaxLevel; level++ {
		ladder = append(ladder, seasonPassPremiumReward(level))
	}
	return ladder
}

// -----------------------------------------------------------------------------
// چالش‌های ویژه‌ی فصل
// -----------------------------------------------------------------------------
//
// مثل ماموریت‌های روزانه‌اند ولی در طول کل فصل باز می‌مانند و هدف‌های
// بزرگ‌تری دارند. پیشرفتشان از PlayerSeasonPass.Stats خوانده می‌شود که بعد از
// هر مسابقه بالا می‌رود — پس مثل ماموریت‌های روزانه، زدن دکمه بدون بازی کردن
// هیچ سکه‌ای نمی‌دهد.

// SeasonChallenge یک چالش فصل. ساختارش عمداً شبیه DailyMissionDef است تا
// کلاینت بتواند از همان ردیف استفاده کند.
type SeasonChallenge struct {
	ChallengeID string        `json:"challenge_id"`
	Title       string        `json:"title"`
	Desc        string        `json:"desc"`
	Metric      MissionMetric `json:"metric"`
	Target      int           `json:"target"`
	XP          int           `json:"xp"`
	Coins       int           `json:"coins"`
	Icon        string        `json:"icon"`
}

// SeasonChallenges کاتالوگ چالش‌های فصل. همه‌ی بازیکن‌ها همین‌ها را می‌گیرند
// (برخلاف ماموریت روزانه که هر بازیکن شش تای تصادفیِ deterministic دارد) —
// چون چالش فصل قرار است هدف مشترک و قابل مقایسه باشد.
var SeasonChallenges = []SeasonChallenge{
	{ChallengeID: "season_wins_10", Title: "۱۰ بار در حالت تیمی پیروز شوید",
		Desc:   "در طول فصل ۱۰ مسابقه‌ی تیمی را ببرید.",
		Metric: MetricWins, Target: 10, XP: 1200, Coins: 2500, Icon: "win"},
	{ChallengeID: "season_kills_300", Title: "۳۰۰ حریف را از بین ببرید",
		Desc:   "در طول فصل ۳۰۰ کیل ثبت کنید.",
		Metric: MetricKills, Target: 300, XP: 1500, Coins: 3000, Icon: "kill"},
	{ChallengeID: "season_matches_60", Title: "۶۰ مسابقه انجام دهید",
		Desc:   "در طول فصل ۶۰ بازی کامل انجام دهید.",
		Metric: MetricMatches, Target: 60, XP: 1000, Coins: 2000, Icon: "match"},
	{ChallengeID: "season_grenade_40", Title: "۴۰ حریف را با نارنجک بزنید",
		Desc:   "در طول فصل ۴۰ کیل با نارنجک بگیرید.",
		Metric: MetricGrenadeKills, Target: 40, XP: 1400, Coins: 2800, Icon: "grenade"},
	{ChallengeID: "season_flawless_15", Title: "۱۵ مسابقه بدون مرگ تمام کنید",
		Desc:   "در طول فصل ۱۵ بازی را بدون کشته شدن تمام کنید.",
		Metric: MetricFlawless, Target: 15, XP: 2000, Coins: 4000, Icon: "flawless"},
}

// seasonChallengeByID برای پیدا کردن سریع
var seasonChallengeByID = func() map[string]SeasonChallenge {
	m := make(map[string]SeasonChallenge, len(SeasonChallenges))
	for _, c := range SeasonChallenges {
		m[c.ChallengeID] = c
	}
	return m
}()

// buildSeasonChallengeView وضعیت چالش‌ها را از روی آمار فصلِ بازیکن می‌سازد.
// همان تابعی که هم پاسخ /season/pass و هم اعتبارسنجی دریافت از آن می‌آید.
func buildSeasonChallengeView(pass PlayerSeasonPass) ([]map[string]interface{}, int) {
	claimed := map[string]bool{}
	for _, id := range pass.ClaimedChallenges {
		claimed[id] = true
	}

	out := make([]map[string]interface{}, 0, len(SeasonChallenges))
	ready := 0
	for _, c := range SeasonChallenges {
		progress := pass.Stats[string(c.Metric)]
		if progress > c.Target {
			progress = c.Target
		}
		done := progress >= c.Target
		if done && !claimed[c.ChallengeID] {
			ready++
		}
		out = append(out, map[string]interface{}{
			"challenge_id": c.ChallengeID,
			"title":        c.Title,
			"desc":         c.Desc,
			"icon":         c.Icon,
			"metric":       string(c.Metric),
			"target":       c.Target,
			"progress":     progress,
			"done":         done,
			"claimed":      claimed[c.ChallengeID],
			"xp":           c.XP,
			"coins":        c.Coins,
		})
	}
	return out, ready
}

// applyMatchToSeasonStats آمار فصلِ بازیکن را بعد از یک مسابقه بالا می‌برد.
// از همان missionDeltas استفاده می‌کند تا «یک کیل» در ماموریت روزانه و چالش
// فصل دقیقاً یک معنی داشته باشد.
func applyMatchToSeasonStats(
	ctx context.Context, playerID string, part MatchParticipant, durationSeconds int64,
) error {
	player, err := getPlayerByID(ctx, playerID)
	if err != nil {
		return err
	}

	pass := currentSeasonPass(player)
	deltas := missionDeltas(part, durationSeconds)
	// زمانِ بازی هم مثلِ ماموریتِ روزانه با ثانیه جمع می‌شود
	prevSec := int64(pass.Stats["playtime_seconds"])
	newSec, minutes := carryPlaySeconds(prevSec, durationSeconds)
	deltas[MetricPlaytime] = minutes

	inc := bson.M{}
	if newSec != prevSec {
		inc["season_pass.stats.playtime_seconds"] = newSec - prevSec
	}
	for metric, delta := range deltas {
		if delta > 0 {
			inc["season_pass.stats."+string(metric)] = delta
		}
	}
	if len(inc) == 0 {
		return nil
	}
	return incSeasonPass(ctx, playerID, inc)
}

// ensureArrayFields فیلدهایی را که قرار است رویشان $addToSet بخورد، اگر null
// باشند آرایه‌ی خالی می‌کند.
//
// چرا لازم است: Go یک slice خالیِ nil را به‌صورت BSON null ذخیره می‌کند، و
// مونگو $addToSet را روی null اجرا نمی‌کند («Cannot apply $addToSet to
// non-array field»). رکوردهای قدیمی (و بازیکن‌هایی که با PlayerModel خالی
// ساخته شده‌اند) این null را دارند، پس دریافت جایزه برایشان همیشه شکست
// می‌خورد. این تابع قبل از هر $addToSet صدا زده می‌شود تا داده‌ی قدیمی هم
// بدون مایگریشن دستی درست شود.
//
// فقط فیلدِ null را عوض می‌کند؛ آرایه‌ی موجود و فیلدِ ناموجود دست نمی‌خورند
// ($addToSet روی فیلد ناموجود خودش آرایه می‌سازد).
func ensureArrayFields(
	ctx context.Context, coll *mongo.Collection, filter bson.M, fields ...string,
) error {
	for _, field := range fields {
		query := bson.M{field: bson.M{"$type": "null"}}
		for k, v := range filter {
			query[k] = v
		}
		if _, err := coll.UpdateOne(ctx, query,
			bson.M{"$set": bson.M{field: bson.A{}}}); err != nil {
			return err
		}
	}
	return nil
}
