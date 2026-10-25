package main

import (
	"testing"
	"time"
)

// «عملیات حذف شیطان» (banish) — حالتِ سوم.
//
// چیزی که این‌جا سنجیده می‌شود خودِ قانون است و نه مسیرِ رسیدن به آن، پس
// راند مستقیم ساخته می‌شود و از صف و دیتابیس رد می‌شویم.

// mustBanishArena زمینِ شیطان — نقشه‌ها یک بار برای کلِ پکیج بالا می‌آیند
func mustBanishArena(t *testing.T) *Arena {
	t.Helper()
	if arena == nil {
		if err := LoadArena(); err != nil {
			t.Fatalf("LoadArena: %v", err)
		}
	}
	a := ArenaForMode("banish")
	if a == nil || a.Name != "banish" {
		t.Fatalf("banish has no arena of its own (got %v)", a)
	}
	return a
}

func newDemonRound(h *Hub, id string, teamOf map[string]string) *RoundState {
	rules := rulesForMode("banish")
	r := &RoundState{
		MatchID:   id,
		ModeID:    "banish",
		Rules:     rules,
		Team:      map[string]string{},
		Alive:     map[string]bool{},
		Humans:    map[string]bool{},
		Kills:     map[string]int{},
		RespawnAt: map[string]time.Time{},
		Demon:     newDemon(ArenaForMode("banish")),
		StartedAt: time.Now(),
		Deadline:  time.Now().Add(rules.Duration + rules.Warmup),
	}
	for name, team := range teamOf {
		r.Team[name] = team
		r.Alive[name] = true
		h.playerRound[name] = id
	}
	// Humans عمداً خالی می‌ماند تا endRound به دیتابیس دست نزند
	h.rounds[id] = r
	return r
}

func TestDemonHuntRules(t *testing.T) {
	r := rulesForMode("banish")
	if !r.Demon {
		t.Error("banish must be a demon round")
	}
	if !r.Respawn {
		t.Error("banish needs respawn: without it, losing one player ends the team's damage output")
	}
	if r.RespawnDelay <= 0 || r.RespawnDelay >= r.Duration {
		t.Errorf("respawn delay %v is not sane for a %v round", r.RespawnDelay, r.Duration)
	}
	if r.ScoreByKills {
		t.Error("banish is decided by damage to the demon, not by kills")
	}
	if r.Warmup <= 0 || r.Warmup >= r.Duration {
		t.Errorf("warmup %v is not sane", r.Warmup)
	}
	// آتش‌بس باید دستِ‌کم به‌اندازه‌ی محافظِ تولد باشد، وگرنه بازیکن قبل از
	// اینکه واقعاً وارد بازی شود ممکن است نفرین بخورد
	if r.Warmup < SpawnShieldDuration {
		t.Errorf("warmup %v is shorter than the spawn shield %v", r.Warmup, SpawnShieldDuration)
	}
}

// شیطان باید وسطِ نقشه و روی زمینِ آزاد بایستد — نه داخلِ دیوار
func TestDemonStandsFreeAtTheCentre(t *testing.T) {
	a := mustBanishArena(t)
	d := newDemon(a)
	if a.CircleBlocked(d.X, d.Y, d.Radius) {
		t.Errorf("demon at (%.0f, %.0f) is inside a wall", d.X, d.Y)
	}
	// «وسط» یعنی واقعاً وسط: بیشتر از یک‌دهمِ نقشه فاصله یعنی جای دیگری است
	if dx := absF(d.X - a.W*0.5); dx > a.W*0.1 {
		t.Errorf("demon is %.0f off the horizontal centre", dx)
	}
	if dy := absF(d.Y - a.H*0.5); dy > a.H*0.1 {
		t.Errorf("demon is %.0f off the vertical centre", dy)
	}
	if d.Health != DemonMaxHealth || d.Health <= 0 {
		t.Errorf("demon spawned with %d health", d.Health)
	}
}

// هیچ نقطه‌ی شروعی نباید روی خودِ شیطان بیفتد — وگرنه بازیکن داخلِ او
// ظاهر می‌شود و بلافاصله زیرِ نفرین است
func TestNoSpawnSitsOnTheDemon(t *testing.T) {
	a := mustBanishArena(t)
	d := newDemon(a)
	for _, s := range a.Spawns {
		if distance(s[0], s[1], d.X, d.Y) < d.Radius+playerRadius {
			t.Errorf("spawn (%.0f, %.0f) overlaps the demon", s[0], s[1])
		}
	}
}

// مرگِ شیطان راند را همان‌جا تمام می‌کند — ولی برنده را آسیبِ کل تعیین
// می‌کند، نه ضربه‌ی آخر. این تست دقیقاً همان سناریویی است که قانون برایش
// عوض شد: تیمِ ۱ بیشترِ راند را زده، تیمِ ۰ فقط ضربه‌ی آخر را دزده.
func TestMostDamageWinsEvenIfTheOtherTeamLandsTheKill(t *testing.T) {
	h := NewHub()
	r := newDemonRound(h, "d1", map[string]string{"a": "0", "b": "1"})

	h.damageDemon(r, "1", 8000)
	h.damageDemon(r, "0", 1500)
	if r.Ended {
		t.Fatal("round ended while the demon was still alive")
	}

	// تیمِ ۰ ضربه‌ی آخر را می‌زند
	h.damageDemon(r, "0", DemonMaxHealth)
	if !r.Ended {
		t.Fatal("round did not end when the demon died")
	}
	if r.Demon.Alive() {
		t.Error("demon should be dead")
	}
	if r.Demon.KilledByTeam != "0" {
		t.Errorf("last hit was team 0, got %q", r.Demon.KilledByTeam)
	}
	if r.Draw || r.WinnerTeam != "1" {
		t.Fatalf("team 1 dealt the most damage and must win; got winner=%q draw=%v",
			r.WinnerTeam, r.Draw)
	}
	// خسارتِ ثبت‌شده نباید از جانِ شیطان بیشتر شود: ضربه‌ی آخر سرریز ندارد
	total := 0
	for _, v := range r.Demon.Damage {
		total += v
	}
	if total != DemonMaxHealth {
		t.Errorf("recorded damage %d, demon only had %d health", total, DemonMaxHealth)
	}
}

// شیطان با آسیبِ دقیقاً برابرِ دو تیم بمیرد: مساوی = هر دو برنده
func TestDemonDiesWithEqualDamageIsADraw(t *testing.T) {
	h := NewHub()
	r := newDemonRound(h, "d1b", map[string]string{"a": "0", "b": "1"})
	h.damageDemon(r, "1", DemonMaxHealth/2)
	h.damageDemon(r, "0", DemonMaxHealth/2)
	if !r.Ended {
		t.Fatal("round did not end when the demon died")
	}
	if !r.Draw {
		t.Fatalf("equal damage must be a draw; got winner=%q", r.WinnerTeam)
	}
}

// آخرِ وقت، تیمی که بیشتر آسیب زده برنده است
func TestTimeoutGoesToTheTeamThatHurtTheDemonMost(t *testing.T) {
	h := NewHub()
	r := newDemonRound(h, "d2", map[string]string{"a": "0", "b": "1"})
	h.damageDemon(r, "0", 900)
	h.damageDemon(r, "1", 1500)

	h.finishOnTime(r)
	if !r.Ended {
		t.Fatal("round did not end on time")
	}
	if r.Draw || r.WinnerTeam != "1" {
		t.Errorf("team 1 dealt more damage; got winner=%q draw=%v", r.WinnerTeam, r.Draw)
	}
}

// آسیبِ برابر = مساوی، و مساوی یعنی هر دو تیم برنده‌اند
func TestEqualDemonDamageIsADraw(t *testing.T) {
	h := NewHub()
	r := newDemonRound(h, "d3", map[string]string{"a": "0", "b": "1"})
	h.damageDemon(r, "0", 1200)
	h.damageDemon(r, "1", 1200)

	if _, ok := r.Demon.leadingTeam(); ok {
		t.Error("equal damage must not produce a leader")
	}
	h.finishOnTime(r)
	if !r.Ended {
		t.Fatal("round did not end on time")
	}
}

// هیچ‌کس به شیطان نزده: باز هم مساوی، نه بردِ تیمِ «۰»
func TestUntouchedDemonIsADraw(t *testing.T) {
	h := NewHub()
	r := newDemonRound(h, "d4", map[string]string{"a": "0", "b": "1"})
	if _, ok := r.Demon.leadingTeam(); ok {
		t.Error("nobody dealt damage; there must be no leader")
	}
	h.finishOnTime(r)
	if !r.Ended {
		t.Fatal("round did not end on time")
	}
}

// نفرین باید نزدیکِ شیطان بیفتد و روی زمینِ آزاد — نه داخلِ دیوار و نه
// آن سرِ نقشه
func TestBlastSpotStaysNearTheDemon(t *testing.T) {
	h := NewHub()
	a := mustBanishArena(t)
	r := newDemonRound(h, "d5", map[string]string{"a": "0", "b": "1"})

	for i := 0; i < 200; i++ {
		x, y, ok := h.pickBlastSpot(r, r.Demon)
		if !ok {
			t.Fatal("no blast spot found on an open map")
		}
		if d := distance(x, y, r.Demon.X, r.Demon.Y); d > DemonBlastReach {
			t.Fatalf("blast %.0f away, reach is %.0f", d, DemonBlastReach)
		}
		if a.CircleBlocked(x, y, 24) {
			t.Fatalf("blast spot (%.0f, %.0f) is inside a wall", x, y)
		}
	}
}

// چرخه‌ی نفرین: اول علامت، بعد — و فقط بعدِ مهلت — انفجار
func TestBlastWarnsBeforeItDetonates(t *testing.T) {
	h := NewHub()
	r := newDemonRound(h, "d6", map[string]string{"a": "0", "b": "1"})
	// آتش‌بس را رد کن، وگرنه شیطان اصلاً نفرین نمی‌فرستد
	r.StartedAt = time.Now().Add(-r.Rules.Warmup - time.Second)
	r.Demon.NextBlastAt = time.Now().Add(-time.Millisecond)

	h.tickDemon(r, time.Now())
	if r.Demon.BlastAt.IsZero() {
		t.Fatal("no blast was scheduled")
	}
	warn := time.Until(r.Demon.BlastAt)
	if warn <= 0 || warn > DemonBlastWarn+time.Second {
		t.Errorf("warning window is %v, expected about %v", warn, DemonBlastWarn)
	}

	// قبل از مهلت نباید بترکد
	h.tickDemon(r, time.Now())
	if r.Demon.BlastAt.IsZero() {
		t.Error("blast detonated before its warning window was over")
	}

	// بعد از مهلت می‌ترکد و ناحیه پاک می‌شود
	h.tickDemon(r, r.Demon.BlastAt.Add(time.Millisecond))
	if !r.Demon.BlastAt.IsZero() {
		t.Error("blast did not detonate after the warning window")
	}
}

// در آتش‌بسِ ابتدای راند نه نفرینی هست و نه شیطان آسیب می‌بیند
func TestDemonIsQuietDuringWarmup(t *testing.T) {
	h := NewHub()
	r := newDemonRound(h, "d7", map[string]string{"a": "0", "b": "1"})
	r.Demon.NextBlastAt = time.Now().Add(-time.Second)

	h.tickDemon(r, time.Now())
	if !r.Demon.BlastAt.IsZero() {
		t.Error("the demon cursed during the warmup truce")
	}
}

func absF(v float64) float64 {
	if v < 0 {
		return -v
	}
	return v
}

// ورودِ واقعی به یک مسابقه‌ی banish باید شیطان بسازد.
//
// چرا این تست: در تستِ دستیِ اول «شیطان دیده نمی‌شد». علتش سرورِ قدیمی بود
// که هنوز اجرا می‌شد، ولی همان یک بار کافی بود تا معلوم شود این مسیر —
// از «حالتِ مسابقه» تا «شیطانِ ساخته‌شده روی راند» — هیچ تستی نداشت.
// حالا دارد: اگر روزی rulesForMode یا startRound عوض شود و شیطان ساخته
// نشود، این‌جا می‌شکند و نه در بازیِ کسی.
func TestJoiningABanishMatchCreatesTheDemon(t *testing.T) {
	mustBanishArena(t)
	resetMM()
	defer resetMM()

	// مسابقه‌ی banish، دو نفر در دو تیم
	mmMu.Lock()
	m := &PendingMatch{MatchID: "bm1", ModeID: "banish", MadeAt: time.Now()}
	m.Players = append(m.Players,
		QueuedPlayer{Username: "hunter", Team: 0},
		QueuedPlayer{Username: "rival", Team: 1})
	for _, p := range m.Players {
		mmMatches[p.Username] = m
	}
	mmMu.Unlock()

	h := NewHub()
	r := h.startRound("hunter")
	if r == nil {
		t.Fatal("راندی ساخته نشد")
	}
	if r.ModeID != "banish" {
		t.Fatalf("حالتِ راند %q شد", r.ModeID)
	}
	if r.Demon == nil {
		t.Fatal("راندِ banish بدونِ شیطان ساخته شد — کلاینت هیچ‌وقت demon_state نمی‌گیرد")
	}
	if !r.Demon.Alive() || r.Demon.Health != DemonMaxHealth {
		t.Errorf("شیطان با جانِ %d ساخته شد", r.Demon.Health)
	}
	if !r.Rules.Respawn {
		t.Error("banish باید ریسپاون داشته باشد")
	}

	// و مرگ باید برگشت را زمان‌بندی کند، نه راند را تمام
	h.players["hunter"] = &Player{Username: "hunter", Team: "0", MatchID: "bm1"}
	h.onPlayerEliminated("hunter")
	if r.Ended {
		t.Fatal("راندِ شیطان با مرگِ یک نفر تمام شد — مرگ باید موقتی باشد")
	}
	at, queued := r.RespawnAt["hunter"]
	if !queued {
		t.Fatal("مرگ ثبت شد ولی برگشتی زمان‌بندی نشد — بازیکن تا آخرِ راند تماشاچی می‌ماند")
	}
	if d := time.Until(at); d <= 0 || d > DemonRespawnDelay+time.Second {
		t.Errorf("زمانِ برگشت %v است، انتظار حدودِ %v", d, DemonRespawnDelay)
	}
}

// زمینِ banish باید واقعاً باز باشد. این حالت درباره‌ی رسیدن به یک نقطه
// است، پس هر دیوارِ اضافه یک دورزدنِ اضافه است — و بازخوردِ تستِ دستی هم
// همین بود: «دیوار زیاد است».
func TestBanishArenaIsOpen(t *testing.T) {
	a := mustBanishArena(t)
	def := arenas[DefaultMapName]
	if def == nil {
		t.Fatal("زمینِ پیش‌فرض لود نشد")
	}
	blocked := func(x *Arena) float64 {
		n := 0
		for _, c := range x.cells {
			if c {
				n++
			}
		}
		return 100 * float64(n) / float64(len(x.cells))
	}
	open, dense := blocked(a), blocked(def)
	if open >= dense {
		t.Errorf("زمینِ شیطان (%.1f%% بسته) باید بازتر از زمینِ پیش‌فرض (%.1f%%) باشد", open, dense)
	}
	if open > 9.0 {
		t.Errorf("زمینِ شیطان %.1f%% بسته است — برای حالتی که هدفش رسیدن به مرکز است زیادی شلوغ", open)
	}
}
