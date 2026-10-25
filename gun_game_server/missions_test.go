package main

import (
	"testing"
	"time"
)

// ماموریت‌های یک بازیکن در یک روز باید همیشه یکی باشند، وگرنه کسی می‌تواند
// با پاک کردن رکوردش ماموریت ساده‌تر بگیرد.
func TestPickDailyMissionsIsDeterministic(t *testing.T) {
	first := pickDailyMissions("player_1", "2026-08-30")
	for i := 0; i < 20; i++ {
		again := pickDailyMissions("player_1", "2026-08-30")
		if len(again) != len(first) {
			t.Fatalf("تعداد ماموریت‌ها عوض شد: %d ≠ %d", len(again), len(first))
		}
		for j := range first {
			if again[j].MissionID != first[j].MissionID {
				t.Fatalf("ماموریت %d عوض شد: %s ≠ %s", j, again[j].MissionID, first[j].MissionID)
			}
		}
	}
}

func TestPickDailyMissionsShape(t *testing.T) {
	// چند بازیکن و چند روز مختلف را چک می‌کنیم
	for _, playerID := range []string{"p1", "p2", "p3", "45135", ""} {
		for _, day := range []string{"2026-08-30", "2026-08-31", "2027-01-01"} {
			picked := pickDailyMissions(playerID, day)

			if len(picked) != DailyMissionsPerDay {
				t.Fatalf("%s/%s: %d ماموریت آمد، %d انتظار می‌رفت",
					playerID, day, len(picked), DailyMissionsPerDay)
			}

			// تکراری نباشد
			seen := map[string]bool{}
			counts := map[MissionDifficulty]int{}
			for _, def := range picked {
				if seen[def.MissionID] {
					t.Fatalf("%s/%s: ماموریت تکراری %s", playerID, day, def.MissionID)
				}
				seen[def.MissionID] = true
				counts[def.Difficulty]++
			}

			// ترکیب سختی باید با DailyMissionShape بخواند
			want := map[MissionDifficulty]int{}
			for _, d := range DailyMissionShape {
				want[d]++
			}
			for difficulty, n := range want {
				if counts[difficulty] != n {
					t.Fatalf("%s/%s: سختی %d → %d تا آمد، %d انتظار می‌رفت",
						playerID, day, difficulty, counts[difficulty], n)
				}
			}
		}
	}
}

// روزهای مختلف باید ماموریت‌های متفاوتی بدهند، وگرنه بازی تکراری می‌شود.
func TestPickDailyMissionsVariesByDay(t *testing.T) {
	sets := map[string]bool{}
	for day := 1; day <= 20; day++ {
		key := ""
		for _, def := range pickDailyMissions("player_1", time.Date(2026, 8, day, 0, 0, 0, 0, time.UTC).Format("2006-01-02")) {
			key += def.MissionID + ","
		}
		sets[key] = true
	}
	if len(sets) < 5 {
		t.Fatalf("در ۲۰ روز فقط %d ترکیب مختلف آمد — تنوع کم است", len(sets))
	}
}

func TestMissionDayBoundary(t *testing.T) {
	// ۲۳:۵۹ به وقت ماموریت‌ها هنوز همان روز است
	late := time.Date(2026, 8, 30, 23, 59, 0, 0, missionsLocation)
	if got := missionDayKey(late); got != "2026-08-30" {
		t.Fatalf("۲۳:۵۹ باید 2026-08-30 باشد، شد %s", got)
	}
	if left := missionSecondsLeft(late); left != 60 {
		t.Fatalf("۲۳:۵۹ باید ۶۰ ثانیه مانده باشد، شد %d", left)
	}

	// یک دقیقه بعد، روز عوض شده و تایمر full شده
	next := late.Add(time.Minute)
	if got := missionDayKey(next); got != "2026-08-31" {
		t.Fatalf("۰۰:۰۰ باید 2026-08-31 باشد، شد %s", got)
	}
	if left := missionSecondsLeft(next); left != 24*3600 {
		t.Fatalf("۰۰:۰۰ باید ۲۴ ساعت مانده باشد، شد %d", left)
	}
}

// تایمر هیچ‌وقت نباید منفی یا بزرگ‌تر از ۲۴ ساعت باشد
func TestMissionSecondsLeftRange(t *testing.T) {
	base := time.Date(2026, 8, 30, 0, 0, 0, 0, time.UTC)
	for minute := 0; minute < 24*60; minute++ {
		left := missionSecondsLeft(base.Add(time.Duration(minute) * time.Minute))
		if left < 0 || left > 24*3600 {
			t.Fatalf("دقیقه %d: تایمر خارج از بازه شد: %d", minute, left)
		}
	}
}

func TestSeasonPassProgress(t *testing.T) {
	// صفر تجربه → پله ۱، هیچ پیشرفتی
	level, into, need := seasonPassProgress(0)
	if level != 1 || into != 0 || need != SeasonPassBaseXP {
		t.Fatalf("تجربه ۰ → پله %d (%d/%d)", level, into, need)
	}

	// دقیقاً به اندازه‌ی پله‌ی اول → پله ۲ با پیشرفت صفر
	level, into, _ = seasonPassProgress(SeasonPassBaseXP)
	if level != 2 || into != 0 {
		t.Fatalf("تجربه %d → پله %d با %d", SeasonPassBaseXP, level, into)
	}

	// یک واحد کمتر → هنوز پله ۱
	level, into, _ = seasonPassProgress(SeasonPassBaseXP - 1)
	if level != 1 || into != SeasonPassBaseXP-1 {
		t.Fatalf("تجربه %d → پله %d با %d", SeasonPassBaseXP-1, level, into)
	}

	// تجربه‌ی خیلی زیاد نباید از سقف رد شود
	level, _, _ = seasonPassProgress(100_000_000)
	if level != SeasonPassMaxLevel {
		t.Fatalf("تجربه‌ی زیاد → پله %d، انتظار %d", level, SeasonPassMaxLevel)
	}

	// تجربه‌ی منفی (نباید بشود، ولی نباید کرش کند)
	level, into, _ = seasonPassProgress(-500)
	if level != 1 || into != 0 {
		t.Fatalf("تجربه‌ی منفی → پله %d با %d", level, into)
	}
}

// seasonPassTotalForLevel باید با پیمایش پله‌به‌پله بخواند، وگرنه عددِ
// «چقدر تا این پله مانده» در UI با نوار پیشرفت جور در نمی‌آید.
func TestSeasonPassTotalMatchesProgress(t *testing.T) {
	// پله‌ی آخر عمداً مستثناست: آنجا نوار پر می‌ماند (into = need) به‌جای
	// اینکه صفر شود، چون پله‌ی بعدی‌ای وجود ندارد که پیشرفتش را نشان دهد.
	for level := 1; level < SeasonPassMaxLevel; level++ {
		total := seasonPassTotalForLevel(level)
		gotLevel, into, _ := seasonPassProgress(total)
		if gotLevel != level || into != 0 {
			t.Fatalf("پله %d: با %d تجربه شد پله %d با %d", level, total, gotLevel, into)
		}
	}
}

func TestSeasonPassRewardsAlwaysGiveSomething(t *testing.T) {
	for level := 1; level <= SeasonPassMaxLevel; level++ {
		reward := seasonPassReward(level)
		if reward.Coins <= 0 && reward.Gems <= 0 && reward.Cups <= 0 {
			t.Fatalf("پله %d هیچ جایزه‌ای ندارد", level)
		}
		if reward.Level != level {
			t.Fatalf("پله %d شماره‌اش %d است", level, reward.Level)
		}
	}
}

func TestMissionDeltas(t *testing.T) {
	part := MatchParticipant{
		Kills: 7, Deaths: 0, Assists: 3,
		GrenadeKills: 2, HealsGiven: 4, Won: true, XPGained: 500,
	}
	deltas := missionDeltas(part, 600) // ۱۰ دقیقه

	checks := map[MissionMetric]int{
		MetricMatches:      1,
		MetricKills:        7,
		MetricAssists:      3,
		MetricGrenadeKills: 2,
		MetricHeals:        4,
		MetricXP:           500,
		MetricPlaytime:     10,
		MetricWins:         1,
		MetricFlawless:     1,
	}
	for metric, want := range checks {
		if deltas[metric] != want {
			t.Fatalf("%s → %d، انتظار %d", metric, deltas[metric], want)
		}
	}

	// باخت با مرگ: نه برد می‌دهد نه flawless
	lost := missionDeltas(MatchParticipant{Deaths: 3}, 60)
	if lost[MetricWins] != 0 {
		t.Fatalf("باخت نباید برد بشمارد")
	}
	if lost[MetricFlawless] != 0 {
		t.Fatalf("بازی با مرگ نباید flawless بشمارد")
	}
}

func TestLevelFromExperience(t *testing.T) {
	// همان فرمول getPlayerHandler: هر سطح level*100
	cases := []struct{ xp, level, into int }{
		{0, 1, 0},
		{99, 1, 99},
		{100, 2, 0},   // ۱۰۰ تجربه = سطح ۲
		{300, 3, 0},   // ۱۰۰ + ۲۰۰
		{299, 2, 199}, // یکی کمتر
	}
	for _, c := range cases {
		level, into, _ := levelFromExperience(c.xp)
		if level != c.level || into != c.into {
			t.Fatalf("تجربه %d → سطح %d با %d، انتظار سطح %d با %d",
				c.xp, level, into, c.level, c.into)
		}
	}
}

// در پله‌ی آخر نوار پیشرفت باید پر بماند، نه اینکه صفر شود
func TestSeasonPassMaxLevelBarStaysFull(t *testing.T) {
	total := seasonPassTotalForLevel(SeasonPassMaxLevel)
	level, into, need := seasonPassProgress(total)
	if level != SeasonPassMaxLevel {
		t.Fatalf("با %d تجربه باید پله‌ی آخر باشد، شد %d", total, level)
	}
	if into != need {
		t.Fatalf("پله‌ی آخر باید نوار پر داشته باشد: %d/%d", into, need)
	}

	// حتی با تجربه‌ی خیلی بیشتر هم همان است
	level2, into2, need2 := seasonPassProgress(total * 10)
	if level2 != SeasonPassMaxLevel || into2 != need2 {
		t.Fatalf("تجربه‌ی اضافه پله‌ی آخر را خراب کرد: پله %d، %d/%d", level2, into2, need2)
	}
}

// پله‌ی ۱ نباید با تجربه‌ی صفر آزاد باشد — وگرنه هر بازیکن تازه‌وارد
// بدون بازی کردن جایزه‌ی اولین پله را می‌گیرد.
func TestSeasonPassTierNotFreeAtZeroXP(t *testing.T) {
	if seasonPassXPRequired(1) != SeasonPassBaseXP {
		t.Fatalf("پله ۱ باید %d تجربه بخواهد، می‌خواهد %d",
			SeasonPassBaseXP, seasonPassXPRequired(1))
	}

	player := &PlayerModel{Rank: NewDefaultRank()}
	player.SeasonPass = PlayerSeasonPass{SeasonID: DefaultSeasonID, XP: 0, ClaimedLevels: []int{}}

	response := buildSeasonPassResponse(player)
	if response["ready"].(int) != 0 {
		t.Fatalf("با تجربه‌ی صفر نباید هیچ پله‌ای آماده باشد، %v تا آماده است", response["ready"])
	}

	tiers := response["tiers"].([]map[string]interface{})
	if tiers[0]["state"] != "locked" {
		t.Fatalf("پله ۱ با تجربه‌ی صفر باید قفل باشد، شد %v", tiers[0]["state"])
	}

	// دقیقاً با تجربه‌ی لازم، پله باز می‌شود
	player.SeasonPass.XP = SeasonPassBaseXP
	tiers = buildSeasonPassResponse(player)["tiers"].([]map[string]interface{})
	if tiers[0]["state"] != "ready" {
		t.Fatalf("پله ۱ با %d تجربه باید آماده باشد، شد %v", SeasonPassBaseXP, tiers[0]["state"])
	}
	if tiers[1]["state"] != "locked" {
		t.Fatalf("پله ۲ نباید هنوز آماده باشد، شد %v", tiers[1]["state"])
	}
}

// ماموریت‌های یک روز نباید همه یک متریک باشند (مثلاً ۱ برد / ۳ برد / ۶ برد)،
// چون تمام کردن سخت‌ترینشان بقیه را هم تمام می‌کند و روز بی‌مزه می‌شود.
func TestPickDailyMissionsMetricVariety(t *testing.T) {
	worst := 0
	for _, playerID := range []string{"p1", "p2", "p3", "p4", "45135", "abc"} {
		for day := 1; day <= 28; day++ {
			key := time.Date(2026, 9, day, 0, 0, 0, 0, time.UTC).Format("2006-01-02")
			picked := pickDailyMissions(playerID, key)

			counts := map[MissionMetric]int{}
			for _, def := range picked {
				counts[def.Metric]++
			}
			for metric, n := range counts {
				if n > 2 {
					t.Fatalf("%s/%s: متریک %s در یک روز %d بار آمد", playerID, key, metric, n)
				}
				if n > worst {
					worst = n
				}
			}
		}
	}
	t.Logf("بیشترین تکرار یک متریک در یک روز: %d", worst)
}

// -----------------------------------------------------------------------------
// جایزه‌ی روزانه (نوار صندوق‌ها)
// -----------------------------------------------------------------------------

// پله‌ها باید صعودی بمانند، وگرنه کلاینت نوار را وارونه می‌چیند.
func TestDailyBonusTiersAreAscending(t *testing.T) {
	if len(DailyBonusTiers) == 0 {
		t.Fatal("هیچ پله‌ی جایزه‌ی روزانه‌ای تعریف نشده")
	}
	previous := 0
	for _, tier := range DailyBonusTiers {
		if tier.Need <= previous {
			t.Fatalf("پله‌ها صعودی نیستند: %d بعد از %d آمد", tier.Need, previous)
		}
		if tier.Coins <= 0 && tier.Gems <= 0 {
			t.Fatalf("پله‌ی %d هیچ جایزه‌ای ندارد", tier.Need)
		}
		previous = tier.Need
	}
	if dailyBonusMaxNeed() != previous {
		t.Fatalf("سقف نوار %d است ولی آخرین پله %d", dailyBonusMaxNeed(), previous)
	}
}

// حالتی که کلاینت می‌بیند باید دقیقاً همانی باشد که سرور اجازه‌ی گرفتنش را
// می‌دهد؛ اگر این دو از هم جدا شوند بازیکن دکمه‌ی روشن می‌بیند و خطا می‌گیرد.
func TestBuildDailyBonusViewStates(t *testing.T) {
	doc := &DailyMissionDoc{BonusClaimed: []int{2}}

	// با ۳ ماموریتِ گرفته‌شده: پله‌ی ۲ گرفته شده، ۴ و ۶ هنوز قفل‌اند
	view, ready := buildDailyBonusView(doc, 3)
	if len(view) != len(DailyBonusTiers) {
		t.Fatalf("%d پله برگشت، %d انتظار می‌رفت", len(view), len(DailyBonusTiers))
	}
	want := map[int]string{2: "claimed", 4: "locked", 6: "locked"}
	for _, tier := range view {
		if tier.State != want[tier.Need] {
			t.Fatalf("پله‌ی %d حالتش %q شد، %q انتظار می‌رفت",
				tier.Need, tier.State, want[tier.Need])
		}
	}
	if ready != 0 {
		t.Fatalf("هیچ پله‌ای نباید آماده باشد، %d آماده شد", ready)
	}

	// با ۶ ماموریت: ۴ و ۶ آماده می‌شوند ولی ۲ همچنان گرفته‌شده می‌ماند
	view, ready = buildDailyBonusView(doc, 6)
	if ready != 2 {
		t.Fatalf("۲ پله باید آماده باشد، %d شد", ready)
	}
	for _, tier := range view {
		if tier.Need == 2 && tier.State != "claimed" {
			t.Fatalf("پله‌ی گرفته‌شده دوباره آماده شد: %q", tier.State)
		}
	}
}

// buildDailyBonusView نباید جدول اصلی را دستکاری کند — اگر با کپی کار نکند،
// State یک بازیکن روی بازیکن بعدی هم می‌نشیند.
func TestBuildDailyBonusViewDoesNotMutateTable(t *testing.T) {
	before := make([]DailyBonusTier, len(DailyBonusTiers))
	copy(before, DailyBonusTiers)

	_, _ = buildDailyBonusView(&DailyMissionDoc{}, 6)

	for i, tier := range DailyBonusTiers {
		if tier != before[i] {
			t.Fatalf("جدول پله‌ها عوض شد: %+v ≠ %+v", tier, before[i])
		}
	}
}

// پله‌ای که در جدول نیست نباید پیدا شود — هندلر دریافت روی همین تکیه می‌کند
// تا کلاینت نتواند need دلخواه بفرستد.
func TestDailyBonusTierByNeedRejectsUnknown(t *testing.T) {
	for _, need := range []int{-1, 0, 1, 3, 5, 7, 999} {
		if _, ok := dailyBonusTierByNeed(need); ok {
			t.Fatalf("پله‌ی ناموجود %d پیدا شد", need)
		}
	}
	for _, tier := range DailyBonusTiers {
		if _, ok := dailyBonusTierByNeed(tier.Need); !ok {
			t.Fatalf("پله‌ی موجود %d پیدا نشد", tier.Need)
		}
	}
}

// هر ماموریت باید توضیح داشته باشد — ردیف بدون توضیح در UI نصفه دیده می‌شود.
func TestEveryMissionHasDescription(t *testing.T) {
	for _, def := range DailyMissionPool {
		if def.Desc == "" {
			t.Fatalf("ماموریت %s توضیح ندارد", def.MissionID)
		}
		if def.Title == "" {
			t.Fatalf("ماموریت %s عنوان ندارد", def.MissionID)
		}
	}
}

// -----------------------------------------------------------------------------
// بتل‌پس طلایی و چالش‌های فصل
// -----------------------------------------------------------------------------

// اگر مسیر طلایی از رایگان بهتر نباشد، خریدنش بی‌معنی است.
func TestPremiumLadderBeatsFree(t *testing.T) {
	free := SeasonPassLadder()
	premium := SeasonPassPremiumLadder()
	if len(free) != len(premium) {
		t.Fatalf("طول دو مسیر یکی نیست: %d ≠ %d", len(free), len(premium))
	}
	for i := range free {
		f, p := free[i], premium[i]
		if p.Coins <= f.Coins {
			t.Fatalf("پله %d: سکه‌ی طلایی (%d) از رایگان (%d) بیشتر نیست",
				f.Level, p.Coins, f.Coins)
		}
		if p.Gems < f.Gems || p.Cups < f.Cups {
			t.Fatalf("پله %d: جم/کاپ طلایی کمتر از رایگان است", f.Level)
		}
	}
}

// چالش تمام‌نشده نباید «آماده» شمرده شود، و چالشِ گرفته‌شده نباید دوباره
// آماده شود — هر دو حالت جایی است که بازیکن می‌تواند سوءاستفاده کند.
func TestSeasonChallengeView(t *testing.T) {
	first := SeasonChallenges[0]

	pass := PlayerSeasonPass{Stats: map[string]int{}, ClaimedChallenges: []string{}}
	view, ready := buildSeasonChallengeView(pass)
	if len(view) != len(SeasonChallenges) {
		t.Fatalf("%d چالش برگشت، %d انتظار می‌رفت", len(view), len(SeasonChallenges))
	}
	if ready != 0 {
		t.Fatalf("با آمار صفر هیچ چالشی نباید آماده باشد، %d شد", ready)
	}

	// دقیقاً به هدف رسیده → آماده
	pass.Stats[string(first.Metric)] = first.Target
	view, ready = buildSeasonChallengeView(pass)
	if ready < 1 {
		t.Fatal("چالشِ رسیده به هدف آماده نشد")
	}
	if view[0]["done"] != true {
		t.Fatalf("done باید true باشد: %v", view[0]["done"])
	}
	// پیشرفت نباید از هدف بیشتر نشان داده شود
	pass.Stats[string(first.Metric)] = first.Target * 5
	view, _ = buildSeasonChallengeView(pass)
	if view[0]["progress"].(int) != first.Target {
		t.Fatalf("پیشرفت از هدف بیشتر شد: %v", view[0]["progress"])
	}

	// گرفته‌شده → دیگر آماده نیست
	pass.ClaimedChallenges = []string{first.ChallengeID}
	view, ready = buildSeasonChallengeView(pass)
	if view[0]["claimed"] != true {
		t.Fatal("چالشِ گرفته‌شده claimed نشد")
	}
	beforeReady := ready
	view2, ready2 := buildSeasonChallengeView(pass)
	if ready2 != beforeReady || view2[0]["claimed"] != true {
		t.Fatal("خواندن دوباره نتیجه را عوض کرد")
	}
}

// currentSeasonPass باید فیلدهای جدید را همیشه غیر-nil برگرداند، وگرنه
// نوشتن روی Stats پنیک می‌دهد.
func TestCurrentSeasonPassNormalisesNewFields(t *testing.T) {
	// رکورد فصل قبل
	old := &PlayerModel{SeasonPass: PlayerSeasonPass{SeasonID: "season_old", XP: 5000}}
	pass := currentSeasonPass(old)
	if pass.XP != 0 || pass.Premium {
		t.Fatal("فصل قبل باید کامل ریست شود (تجربه و بتل‌پس طلایی)")
	}
	// رکورد فصل جاری ولی خالی
	cur := &PlayerModel{SeasonPass: PlayerSeasonPass{SeasonID: DefaultSeasonID}}
	pass = currentSeasonPass(cur)
	for name, isNil := range map[string]bool{
		"Stats":             pass.Stats == nil,
		"ClaimedLevels":     pass.ClaimedLevels == nil,
		"ClaimedPremium":    pass.ClaimedPremium == nil,
		"ClaimedChallenges": pass.ClaimedChallenges == nil,
	} {
		if isNil {
			t.Fatalf("%s نباید nil باشد", name)
		}
	}
	pass.Stats["kills"] = 1 // نباید پنیک بدهد
}

// زمانِ بازی با ثانیه جمع می‌شود: سه مسابقه‌ی ۴۰ ثانیه‌ای ۲ دقیقه است، نه صفر.
func TestPlaytimeAccumulatesSecondsAcrossShortMatches(t *testing.T) {
	var secs int64
	total := 0
	for i := 0; i < 3; i++ {
		var m int
		secs, m = carryPlaySeconds(secs, 40)
		total += m
	}
	if total != 2 || secs != 120 {
		t.Fatalf("3×40s should be 2 minutes (got %d min, %d s)", total, secs)
	}
	if _, m := carryPlaySeconds(0, -5); m != 0 {
		t.Fatal("negative duration must not count")
	}
}
