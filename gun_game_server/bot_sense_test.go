package main

import (
	"math"
	"sort"
	"testing"
	"time"
)

// ادراکِ بات: چه می‌بیند و چه نمی‌بیند.
//
// باگی که این‌ها جلویش را می‌گیرند: pickTarget نزدیک‌ترین حریفِ زنده‌ی کلِ
// نقشه را برمی‌گرداند — بدونِ خطِ دید، بدونِ برد، بدونِ جهتِ نگاه. یعنی هر
// باتی از ثانیه‌ی صفر می‌دانست حریف کجاست و مستقیم راه می‌افتاد. همه به یک
// نقطه سرازیر می‌شدند و بقیه‌ی نقشه خالی می‌ماند.

// senseHub یک هاب با دو بازیکنِ رودررو در یک مسابقه.
//
// نقشه برای این تست‌ها کنار گذاشته می‌شود (و سرِ تست برمی‌گردد): چیزی که
// اینجا می‌سنجیم برد و زاویه‌ی دید است، نه دیوارها. خطِ دید تستِ خودش را
// دارد و آن‌جا نقشه‌ی واقعی به کار می‌رود.
func senseHub(t *testing.T) (*Hub, *Player, *Player) {
	t.Helper()
	saved := arena
	arena = nil
	t.Cleanup(func() { arena = saved })
	h := NewHub()
	me := &Player{Username: "bot", Team: "0", MatchID: "m1", Health: 100, X: 500, Y: 500}
	foe := &Player{Username: "foe", Team: "1", MatchID: "m1", Health: 100, X: 500, Y: 500}
	h.players["bot"] = me
	h.players["foe"] = foe
	return h, me, foe
}

// رو به هدف و در برد → می‌بیندش
func TestBotSeesEnemyInFrontWithinRange(t *testing.T) {
	h, me, foe := senseHub(t)
	foe.X, foe.Y = 500, 200 // مستقیم بالای سرش
	// قراردادِ زاویه‌ی بازی: جلوی کاراکتر رو به بالا، پس +π/۲
	me.Rot = math.Atan2(foe.Y-me.Y, foe.X-me.X) + math.Pi/2

	if got := h.senseTarget(me); got == nil {
		t.Fatal("an enemy standing in front, well inside vision range, was not seen")
	}
}

// دورتر از بردِ دید → نمی‌بیندش، هرچقدر هم رو به او باشد
func TestBotDoesNotSeeBeyondVisionRange(t *testing.T) {
	h, me, foe := senseHub(t)
	foe.X, foe.Y = 500, 500-(botVision+120)
	me.Rot = math.Atan2(foe.Y-me.Y, foe.X-me.X) + math.Pi/2

	if got := h.senseTarget(me); got != nil {
		t.Fatalf("saw %s at %.0f units away; vision range is %.0f",
			got.Username, botVision+120, botVision)
	}
}

// پشتِ سر و دور → نمی‌بیندش. این همان چیزی است که «گشتن» را معنادار می‌کند.
func TestBotDoesNotSeeBehindItself(t *testing.T) {
	h, me, foe := senseHub(t)
	foe.X, foe.Y = 500, 500-400 // ۴۰۰ واحد بالاتر، داخلِ برد
	// رو به پایین می‌ایستد، یعنی درست خلافِ جهتِ حریف.
	// (قرارداد: Rot=0 یعنی رو به بالا، پس π یعنی رو به پایین)
	me.Rot = math.Pi

	if got := h.senseTarget(me); got != nil {
		t.Fatal("saw an enemy standing directly behind it")
	}
}

// اما اگر بغلِ دستش باشد، از هر طرف حسش می‌کند
func TestBotSensesVeryCloseEnemyFromAnyDirection(t *testing.T) {
	h, me, foe := senseHub(t)
	foe.X, foe.Y = 500, 500-(botCloseVision-40)
	me.Rot = math.Pi // پشتش به حریف

	if got := h.senseTarget(me); got == nil {
		t.Fatalf("an enemy %.0f units away (close-range sense is %.0f) went unnoticed",
			botCloseVision-40, botCloseVision)
	}
}

// هم‌تیمی هیچ‌وقت هدف نیست
func TestBotNeverSensesATeammateAsTarget(t *testing.T) {
	h, me, foe := senseHub(t)
	foe.Team = me.Team
	foe.X, foe.Y = 500, 400
	me.Rot = math.Atan2(foe.Y-me.Y, foe.X-me.X) + math.Pi/2

	if got := h.senseTarget(me); got != nil {
		t.Fatal("picked a teammate as a target")
	}
}

// بازیکنِ مسابقه‌ی دیگر اصلاً وجود ندارد
func TestBotDoesNotSenseAcrossMatches(t *testing.T) {
	h, me, foe := senseHub(t)
	foe.MatchID = "m2"
	foe.X, foe.Y = 500, 400
	me.Rot = math.Atan2(foe.Y-me.Y, foe.X-me.X) + math.Pi/2

	if got := h.senseTarget(me); got != nil {
		t.Fatal("sensed a player from a different match")
	}
}

// دیوار جلوی دید را می‌گیرد — با نقشه‌ی واقعی.
func TestBotDoesNotSeeThroughWalls(t *testing.T) {
	if arena == nil {
		t.Skip("نقشه بارگذاری نشده")
	}
	h := NewHub()
	me := &Player{Username: "bot", Team: "0", MatchID: "m1", Health: 100}
	foe := &Player{Username: "foe", Team: "1", MatchID: "m1", Health: 100}
	h.players["bot"], h.players["foe"] = me, foe

	// دو نقطه‌ی آزاد که دیوار بینشان است و از هم دورتر از دیدِ نزدیک‌اند
	found := false
	for i := 0; i < len(arena.Spawns) && !found; i++ {
		for j := 0; j < len(arena.Spawns); j++ {
			a, b := arena.Spawns[i], arena.Spawns[j]
			d := distance(a[0], a[1], b[0], b[1])
			if d <= botCloseVision || d > botVision {
				continue
			}
			if arena.HasLineOfSight(a[0], a[1], b[0], b[1]) {
				continue
			}
			me.X, me.Y = a[0], a[1]
			foe.X, foe.Y = b[0], b[1]
			found = true
			break
		}
	}
	if !found {
		t.Skip("جفت‌نقطه‌ای با دیوارِ بینشان در این برد پیدا نشد")
	}
	me.Rot = math.Atan2(foe.Y-me.Y, foe.X-me.X) + math.Pi/2

	if got := h.senseTarget(me); got != nil {
		t.Fatal("saw an enemy through a wall")
	}
}

// صدای شلیکِ حریف: بات می‌شنود و می‌رود سراغش.
// بدونِ این، بازیکنی که در تاریکی کمین کرده هیچ‌وقت پیدا نمی‌شود.
func TestGunfireAlertsNearbyEnemyBots(t *testing.T) {
	h, _, shooter := senseHub(t)
	shooter.X, shooter.Y = 500+300, 500
	b := &BotRuntime{Username: "bot", Skill: BotSkillMedium, prof: profileFor(BotSkillMedium)}
	h.bots["bot"] = b

	h.alertBotsToShot("foe")

	if b.memory <= 0 {
		t.Fatal("a gunshot 300 units away left the bot with no lead to follow")
	}
	// ردِ صدا باید حدودِ جای تیرانداز باشد، نه دقیقاً روی سرش
	d := distance(b.lastSeenX, b.lastSeenY, shooter.X, shooter.Y)
	if d > botNoiseError*2 {
		t.Errorf("noise lead landed %.0f units from the shooter; error budget is %.0f", d, botNoiseError*2)
	}
}

// صدای تفنگِ هم‌تیمی نباید بات را به دویدن بیندازد
func TestBotIgnoresFriendlyGunfire(t *testing.T) {
	h, me, shooter := senseHub(t)
	shooter.Team = me.Team
	shooter.X, shooter.Y = 500+300, 500
	b := &BotRuntime{Username: "bot", Skill: BotSkillMedium, prof: profileFor(BotSkillMedium)}
	h.bots["bot"] = b

	h.alertBotsToShot("foe")

	if b.memory > 0 {
		t.Fatal("the bot chased its own teammate's gunfire")
	}
}

// شلیکِ خیلی دور شنیده نمی‌شود
func TestDistantGunfireIsNotHeard(t *testing.T) {
	h, _, shooter := senseHub(t)
	shooter.X, shooter.Y = 500+botHearing+400, 500
	b := &BotRuntime{Username: "bot", Skill: BotSkillMedium, prof: profileFor(BotSkillMedium)}
	h.bots["bot"] = b

	h.alertBotsToShot("foe")

	if b.memory > 0 {
		t.Fatalf("heard a shot %.0f units away; hearing range is %.0f", botHearing+400, botHearing)
	}
}

// ردِ دیده‌شده با چشم نباید با یک صدای دورتر خراب شود
func TestFreshSightingSurvivesADistantNoise(t *testing.T) {
	h, _, shooter := senseHub(t)
	shooter.X, shooter.Y = 900, 900
	b := &BotRuntime{Username: "bot", Skill: BotSkillMedium, prof: profileFor(BotSkillMedium)}
	h.bots["bot"] = b
	b.noteSighting(120, 120) // همین الان با چشم دید

	h.alertBotsToShot("foe")

	if distance(b.lastSeenX, b.lastSeenY, 120, 120) > 1 {
		t.Error("a gunshot overwrote a sighting the bot had just made with its own eyes")
	}
}

// قطعِ اتصالِ آخرین آدم باید کلِ مسابقه را آزاد کند، نه فقط سهمِ خودش.
//
// باگی که این جلویش را می‌گیرد: ReleasePlayer فقط ورودیِ همان بازیکن را پاک
// می‌کرد. بات‌های همان مسابقه در mmMatches می‌ماندند و busyNamesLocked تا ابد
// «مشغول» می‌دیدشان. استخرِ ۳۸تایی با هر نشستِ ناتمام آب می‌رفت — گاهی همه
// اسپان می‌شدند، گاهی هیچ‌کس.
func TestLeavingAMatchFreesItsBots(t *testing.T) {
	resetMM()
	defer resetMM()

	seedMatch("m1", "human1", "botA", "botB", "botC")

	ReleaseMatchOf("human1")

	mmMu.Lock()
	busy := busyNamesLocked()
	mmMu.Unlock()
	for _, name := range []string{"botA", "botB", "botC"} {
		if busy[name] {
			t.Errorf("%s is still marked busy after the last human left the match", name)
		}
	}
}

// مسابقه‌ای که هیچ‌وقت آزاد نشد نباید تا ابد بات‌ها را نگه دارد
func TestStaleMatchesAreSweptEventually(t *testing.T) {
	resetMM()
	defer resetMM()

	seedMatch("old", "ghost", "botX", "botY")
	mmMu.Lock()
	for _, m := range mmMatches {
		m.MadeAt = time.Now().Add(-matchTTL - time.Minute)
	}
	n := sweepStaleMatchesLocked()
	busy := busyNamesLocked()
	mmMu.Unlock()

	if n == 0 {
		t.Fatal("the sweep found nothing to release")
	}
	for _, name := range []string{"botX", "botY"} {
		if busy[name] {
			t.Errorf("%s is still busy after its match aged past the TTL", name)
		}
	}
}

// مسابقه‌ی تازه نباید قربانیِ جاروی TTL شود
func TestFreshMatchesSurviveTheSweep(t *testing.T) {
	resetMM()
	defer resetMM()

	seedMatch("live", "player", "botZ")
	mmMu.Lock()
	sweepStaleMatchesLocked()
	still := mmMatches["player"] != nil
	mmMu.Unlock()

	if !still {
		t.Fatal("the sweep released a match that was only just made")
	}
}

// بات باید رو به همان سمتی باشد که دارد می‌رود — مثل بازیکنِ آدم.
//
// باگی که این جلویش را می‌گیرد: چرخش جدا از حرکت حساب می‌شد و همیشه به
// سمتِ حریف بود. نتیجه این بود که بات پهلو و عقب راه می‌رفت در حالی که
// صورتش جای دیگری بود — از بیرون اصلاً شبیه یک بازیکن نبود.
func TestBotFacesTheDirectionItWalks(t *testing.T) {
	if arena == nil {
		t.Skip("نقشه بارگذاری نشده")
	}
	h := NewHub()
	start := arena.Spawns[0]
	goal := arena.Spawns[len(arena.Spawns)-1]

	p := makeTestPlayer("Walker", start[0], start[1], "0", 500)
	h.players["Walker"] = p
	b := &BotRuntime{Username: "Walker", Skill: BotSkillMedium,
		prof: profileFor(BotSkillMedium), strafeDir: 1}
	h.bots["Walker"] = b

	const dt = 1.0 / botTickRate
	worst, samples := 0.0, 0
	var errs []float64
	for i := 0; i < botTickRate*8; i++ {
		px, py := p.X, p.Y
		h.advanceAlongPath(b, p, goal[0], goal[1], dt)

		moved := distance(px, py, p.X, p.Y)
		if moved < 1.0 {
			continue // نایستاده یا به دیوار خورده؛ چیزی برای سنجیدن نیست
		}
		// جهتِ جابه‌جاییِ واقعی، با همان قراردادِ زاویه‌ی بازی
		went := math.Atan2(p.Y-py, p.X-px) + math.Pi/2
		off := math.Abs(angleDiff(p.Rot, went))
		if off > worst {
			worst = off
		}
		errs = append(errs, off)
		samples++
	}

	if samples < 20 {
		t.Fatalf("bot barely moved (%d samples) — cannot judge its facing", samples)
	}
	sort.Float64s(errs)
	pc := func(f float64) float64 { return errs[int(f*float64(len(errs)-1))] * 180 / math.Pi }
	t.Logf("heading error: p50=%.1f° p90=%.1f° p99=%.1f° max=%.1f° over %d steps",
		pc(0.5), pc(0.9), pc(0.99), worst*180/math.Pi, samples)

	// روی رفتارِ پایدار قضاوت می‌کنیم، نه روی تکْ‌فریمِ سرِ پیچ.
	//
	// چرخش با TurnRate نرم انجام می‌شود (۱۴.۵ درجه در هر تیک)، پس سرِ یک
	// پیچِ تند صورت دو-سه فریم عقب می‌ماند — بازیکنِ آدم هم دقیقاً همین
	// است (player.gd/_turn_toward). چیزی که باگ بود این نیست: باگ این بود
	// که بات *همیشه* رو به حریف بود و پهلو راه می‌رفت، یعنی خطا در p50 هم
	// بزرگ می‌ماند. پس p50/p90 را می‌سنجیم.
	if pc(0.5) > 5 || pc(0.9) > 25 {
		t.Errorf("bot is not facing where it walks: p50=%.0f° p90=%.0f° (limits 5°/25°)",
			pc(0.5), pc(0.9))
	}
}
