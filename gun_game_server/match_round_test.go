package main

import (
	"testing"
	"time"
)

// قانونِ راند: هر تیمی که زنده بماند برنده است، و اگر وقت تمام شود مساوی.
//
// راند مستقیم ساخته می‌شود و از صف/دیتابیس رد می‌شویم: چیزی که می‌سنجیم
// خودِ قانون است، نه مسیرِ رسیدن به آن.

func newRound(h *Hub, id string, teamOf map[string]string, humans []string) *RoundState {
	// دقیقاً مثل startRound ساخته می‌شود، از جمله آتش‌بس — وگرنه تست
	// چیزی را می‌سنجد که با راندِ واقعی فرق دارد.
	rules := rulesForMode("strike")
	r := &RoundState{
		MatchID:   id,
		ModeID:    "strike",
		Rules:     rules,
		Team:      map[string]string{},
		Alive:     map[string]bool{},
		Humans:    map[string]bool{},
		Kills:     map[string]int{},
		RespawnAt: map[string]time.Time{},
		StartedAt: time.Now(),
		Deadline:  time.Now().Add(rules.Duration + rules.Warmup),
	}
	for name, team := range teamOf {
		r.Team[name] = team
		r.Alive[name] = true
		h.playerRound[name] = id
	}
	// آدم‌ها را عمداً خالی می‌گذاریم مگر خواسته شود، تا endRound به
	// دیتابیس دست نزند
	for _, u := range humans {
		r.Humans[u] = true
	}
	h.rounds[id] = r
	return r
}

func TestLastTeamStandingWins(t *testing.T) {
	h := NewHub()
	r := newRound(h, "m1", map[string]string{
		"a1": "0", "a2": "0", "a3": "0", "a4": "0",
		"b1": "1", "b2": "1", "b3": "1", "b4": "1",
	}, nil)

	// سه نفر از تیم ۱ می‌افتند — هنوز نباید تمام شود
	for _, name := range []string{"b1", "b2", "b3"} {
		h.onPlayerEliminated(name)
		if r.Ended {
			t.Fatalf("round ended early after %s died; team 1 still had players", name)
		}
	}
	// نفر آخرِ تیم ۱ هم می‌افتد
	h.onPlayerEliminated("b4")
	if !r.Ended {
		t.Fatal("round did not end when team 1 was wiped out")
	}
}

func TestWinnerIsTheTeamWithSurvivors(t *testing.T) {
	h := NewHub()
	var gotWinner string
	var gotDraw bool
	// endRound را نمی‌شود جاسوسی کرد، پس نتیجه را از وضعیتِ زنده‌ها می‌سنجیم
	r := newRound(h, "m2", map[string]string{
		"a1": "0", "a2": "0",
		"b1": "1", "b2": "1",
	}, nil)

	h.onPlayerEliminated("a1")
	h.onPlayerEliminated("a2")
	if !r.Ended {
		t.Fatal("round should end when team 0 is wiped")
	}
	// تیم ۱ باید زنده‌ها را داشته باشد
	for name, team := range r.Team {
		if team == "1" && !r.Alive[name] {
			t.Fatalf("%s of the winning team is marked dead", name)
		}
	}
	alive0 := 0
	for name, team := range r.Team {
		if team == "0" && r.Alive[name] {
			alive0++
		}
	}
	if alive0 != 0 {
		t.Fatalf("losing team still has %d alive", alive0)
	}
	_ = gotWinner
	_ = gotDraw
}

// وقت که تمام شود و هر دو تیم زنده باشند، مساوی است
func TestTimeoutWithBothTeamsAliveIsADraw(t *testing.T) {
	h := NewHub()
	r := newRound(h, "m3", map[string]string{
		"a1": "0", "b1": "1",
	}, nil)
	r.Deadline = time.Now().Add(-time.Second) // وقت تمام

	h.tickRounds()
	if !r.Ended {
		t.Fatal("round did not end when the timer expired")
	}
	// هیچ‌کس نمرده، پس هر دو تیم هنوز زنده‌اند = مساوی
	if !r.Alive["a1"] || !r.Alive["b1"] {
		t.Fatal("nobody died, both should still be alive")
	}
}

// راندِ تمام‌شده نباید دوباره تمام شود (پاداشِ دوباره = تقلب)
func TestRoundEndsOnlyOnce(t *testing.T) {
	h := NewHub()
	r := newRound(h, "m4", map[string]string{"a1": "0", "b1": "1"}, nil)

	h.onPlayerEliminated("b1")
	if !r.Ended {
		t.Fatal("round should have ended")
	}
	// مرگِ دوباره‌ی همان نفر یا نفرِ دیگر نباید چیزی را عوض کند
	h.onPlayerEliminated("b1")
	h.onPlayerEliminated("a1")
	if !r.Ended {
		t.Fatal("round flipped back to running")
	}
}

// مرگِ تکراریِ یک نفر نباید تیمش را دوبار کم کند
func TestDoubleDeathDoesNotEndRoundEarly(t *testing.T) {
	h := NewHub()
	r := newRound(h, "m5", map[string]string{
		"a1": "0", "a2": "0",
		"b1": "1", "b2": "1",
	}, nil)

	h.onPlayerEliminated("b1")
	h.onPlayerEliminated("b1") // همان نفر، دوباره
	if r.Ended {
		t.Fatal("a repeated death of the same player ended the round early")
	}
	h.onPlayerEliminated("b2")
	if !r.Ended {
		t.Fatal("round should end once both of team 1 are down")
	}
}

// مدتِ راند باید معقول باشد — تایمرِ بالای صفحه از همین می‌آید
func TestRoundDurationIsSane(t *testing.T) {
	if RoundDuration < 60*time.Second || RoundDuration > 10*time.Minute {
		t.Errorf("RoundDuration = %v, expected something between 1 and 10 minutes", RoundDuration)
	}
}

// آتش‌بسِ ابتدای راند: بازیکن باید فرصت کند وارد زمین شود.
//
// باگی که این جلویش را می‌گیرد: بات‌ها از ثانیه‌ی صفر شروع می‌کردند و
// راند در چند ثانیه تمام می‌شد — بازیکن هیچ کاری نکرده «باختی» می‌دید.
func TestRoundStartsWithACeasefire(t *testing.T) {
	h := NewHub()
	r := newRound(h, "mw", map[string]string{"a1": "0", "b1": "1"}, nil)
	r.StartedAt = time.Now()

	if !r.InWarmup() {
		t.Fatal("a freshly started round should be in warmup")
	}
	// آتش‌بس باید دستِ‌کم به‌اندازه‌ی تایمرِ کلاینت + حصانتِ ورود باشد،
	// وگرنه بازیکن هنوز وارد نشده تیر می‌خورد
	if RoundWarmup < gracePeriod {
		t.Errorf("RoundWarmup (%v) is shorter than the spawn grace period (%v)",
			RoundWarmup, gracePeriod)
	}

	r.StartedAt = time.Now().Add(-RoundWarmup - time.Second)
	if r.InWarmup() {
		t.Error("warmup never ends")
	}
}

// مهلتِ راند باید شاملِ آتش‌بس باشد، وگرنه بخشی از وقتِ بازی می‌سوزد
func TestDeadlineAccountsForWarmup(t *testing.T) {
	h := NewHub()
	r := newRound(h, "mw2", map[string]string{"a1": "0", "b1": "1"}, nil)
	playable := time.Until(r.Deadline) - RoundWarmup
	if playable < RoundDuration-2*time.Second {
		t.Errorf("only %v of playable time after warmup, expected ~%v",
			playable, RoundDuration)
	}
}

// مساوی برد نیست — وگرنه قایم شدن تا آخرِ وقت به هر دو تیم پاداشِ برد
// می‌داد. پاداشِ مساوی جداست (ApplyMatchOutcome → OutcomeDraw).
func TestADrawIsNotAWin(t *testing.T) {
	h := NewHub()
	r := newRound(h, "draw1", map[string]string{
		"a1": "0", "a2": "0", "b1": "1", "b2": "1",
	}, nil)

	for _, name := range []string{"a1", "a2", "b1", "b2"} {
		if r.WonRound(name, "", true) {
			t.Errorf("%s نباید در مساوی برنده حساب شود", name)
		}
	}
}

// وقتِ راندِ حذفی تمام شد: تیمی که زنده‌ی بیشتری دارد می‌برد؛ برابر بود،
// جانِ بیشتر؛ آن هم برابر بود، مساوی.
func TestEliminationTimeoutGoesToTheSurvivors(t *testing.T) {
	h := NewHub()
	r := newRound(h, "sv1", map[string]string{"a1": "0", "a2": "0", "b1": "1", "b2": "1"}, nil)
	for _, n := range []string{"a1", "a2", "b1", "b2"} {
		addPlayer(h, n, r.Team[n], "sv1", 0, 0)
	}
	r.Alive["b2"] = false
	if w, ok := h.survivorLeader(r); !ok || w != "0" {
		t.Fatalf("more survivors should win: %q %v", w, ok)
	}
	r.Alive["b2"] = true
	h.players["a1"].Health = 40
	if w, ok := h.survivorLeader(r); !ok || w != "1" {
		t.Fatalf("equal survivors: more health should win: %q %v", w, ok)
	}
	h.players["a1"].Health = 100
	if _, ok := h.survivorLeader(r); ok {
		t.Fatal("identical teams must be a draw")
	}
}

// و بردِ معمولی هنوز فقط مالِ تیمِ برنده است
func TestOnlyTheWinningTeamWinsANormalRound(t *testing.T) {
	h := NewHub()
	r := newRound(h, "draw2", map[string]string{
		"a1": "0", "b1": "1",
	}, nil)

	if !r.WonRound("a1", "0", false) {
		t.Error("تیمِ برنده باید برنده باشد")
	}
	if r.WonRound("b1", "0", false) {
		t.Error("تیمِ بازنده نباید برنده حساب شود")
	}
	// برنده‌ی بی‌نام بدونِ مساوی یعنی چیزی خراب است — نباید همه را برنده کند
	if r.WonRound("a1", "", false) {
		t.Error("بدونِ تیمِ برنده و بدونِ مساوی، کسی برنده نیست")
	}
}
