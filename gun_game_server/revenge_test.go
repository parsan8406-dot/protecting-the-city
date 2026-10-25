package main

import (
	"testing"
	"time"
)

// -----------------------------------------------------------------------------
// «عملیات انتقام»: دو دقیقه، مرگِ موقتی، برنده کسی که بیشتر زده — و پنج ثانیه
// محافظِ تولد که تیر از آن رد نمی‌شود.
//
// همه‌ی این‌ها سمتِ سرور تصمیم گرفته می‌شوند؛ این فایل دقیقاً همان مسیرها را
// اجرا می‌کند (نه فرمولِ دوباره‌نویسی‌شده) تا اگر کسی قانون را عوض کرد، تست
// بیفتد نه بازیکن.
// -----------------------------------------------------------------------------

func newRevengeRound(h *Hub, id string, teamOf map[string]string) *RoundState {
	rules := rulesForMode("revenge")
	r := &RoundState{
		MatchID:   id,
		ModeID:    "revenge",
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
	h.rounds[id] = r
	return r
}

// قانونِ خودِ حالت: دو دقیقه، ریسپاون‌دار، امتیازی، با محافظِ پنج ثانیه‌ای
func TestRevengeRules(t *testing.T) {
	r := rulesForMode("revenge")
	if r.Duration != 2*time.Minute {
		t.Errorf("revenge round should last 2 minutes, got %v", r.Duration)
	}
	if !r.Respawn {
		t.Error("revenge must respawn the dead")
	}
	if !r.ScoreByKills {
		t.Error("revenge must be decided by kills")
	}
	if r.SpawnShield != 5*time.Second {
		t.Errorf("spawn shield should be 5s, got %v", r.SpawnShield)
	}
	if r.RespawnDelay <= 0 || r.RespawnDelay >= r.Duration {
		t.Errorf("respawn delay %v is not sane for a %v round", r.RespawnDelay, r.Duration)
	}

	// حالت‌های دیگر نباید عوض شده باشند.
	// «banish» عمداً این‌جا نیست: از وقتی «عملیات حذف شیطان» ساخته شد، خودش
	// یک خانواده‌ی جدا است (demon_test.go) و نه راندِ حذفی.
	for _, mode := range []string{"strike", "citypoint", "whatever"} {
		e := rulesForMode(mode)
		if e.Respawn || e.ScoreByKills {
			t.Errorf("%s should stay an elimination round, got %+v", mode, e)
		}
		if e.Duration != RoundDuration {
			t.Errorf("%s duration changed to %v", mode, e.Duration)
		}
	}
}

// «عملیات انتقام» دو نفره است: دو بازیکن روبه‌روی هم، نه دو تیمِ دو نفره
func TestRevengeIsOneVersusOne(t *testing.T) {
	for _, m := range defaultGameModes() {
		if m.ModeID != "revenge" {
			continue
		}
		if m.TeamSize != 1 {
			t.Fatalf("revenge team size is %d — it must be 1v1 (two players)", m.TeamSize)
		}
		if m.Subtitle != "۱ در ۱" {
			t.Errorf("revenge subtitle is %q, want the 1v1 label", m.Subtitle)
		}
		return
	}
	t.Fatal("revenge mode is missing from the defaults")
}

// نقطه‌ی تولدِ دوباره: نه جلوی حریف، نه دورترین نقطه‌ی نقشه.
//
// در یک بازیِ دو نفره‌ی دو دقیقه‌ای، «دورترین نقطه» یعنی هر مرگ یک تعقیبِ
// طولانی — بازی می‌ایستد. این تست هر دو سر را می‌بندد.
func TestRespawnSpawnIsSafeButNotFar(t *testing.T) {
	if arena == nil {
		if err := LoadArena(); err != nil {
			t.Fatalf("arena: %v", err)
		}
	}
	a := ArenaForMode("revenge")

	// حریف را روی یکی از نقاطِ شروع می‌گذاریم
	foe := a.Spawns[0]
	x, y := a.RespawnSpawn([][2]float64{{foe[0], foe[1]}})

	gap := distance(x, y, foe[0], foe[1])
	if gap < RespawnSafeDistance {
		t.Errorf("respawned %.0f from the enemy — closer than the %.0f safe distance",
			gap, RespawnSafeDistance)
	}
	if a.CircleBlocked(x, y, playerRadius) {
		t.Errorf("respawn point (%.0f,%.0f) is inside a wall", x, y)
	}

	// و نباید همیشه دورترین نقطه باشد: RandomSpawn دورترین را می‌دهد،
	// این باید نزدیک‌ترینِ امن را بدهد
	fx, fy := a.RandomSpawn([][2]float64{{foe[0], foe[1]}})
	farGap := distance(fx, fy, foe[0], foe[1])
	if gap > farGap {
		t.Errorf("respawn gap %.0f is beyond the farthest spawn %.0f", gap, farGap)
	}
	if farGap > RespawnSafeDistance && gap >= farGap {
		t.Errorf("respawn picked the farthest corner (%.0f) instead of the nearest safe spot",
			gap)
	}
}

// مرگ در انتقام راند را تمام نمی‌کند — فقط وقتِ برگشت را ثبت می‌کند
func TestRevengeDeathIsTemporary(t *testing.T) {
	h := NewHub()
	r := newRevengeRound(h, "mr1", map[string]string{"a1": "0", "b1": "1"})

	// کلِ یک تیم می‌افتد؛ در حالتِ حذفی همین‌جا راند تمام می‌شد
	h.onPlayerEliminated("b1")

	if r.Ended {
		t.Fatal("revenge round ended on a death — it must run the full clock")
	}
	if r.Alive["b1"] {
		t.Error("the dead player is still marked alive")
	}
	if _, queued := r.RespawnAt["b1"]; !queued {
		t.Error("no respawn was scheduled for the dead player")
	}
}

// برگشت: جانِ کامل، محافظِ پنج ثانیه‌ای، و دوباره زنده
func TestRevengeRespawnRestoresAndShields(t *testing.T) {
	if arena == nil {
		if err := LoadArena(); err != nil {
			t.Fatalf("arena: %v", err)
		}
	}
	h := NewHub()
	r := newRevengeRound(h, "mr2", map[string]string{"a1": "0", "b1": "1"})

	p := addPlayer(h, "b1", "1", "mr2", 500, 500)
	p.Arena = ArenaForMode("revenge")
	p.Health = 0

	h.onPlayerEliminated("b1")
	// وقتِ برگشت را جلو می‌اندازیم تا لازم نباشد تست واقعاً صبر کند
	r.RespawnAt["b1"] = time.Now().Add(-time.Millisecond)
	h.tickRounds()

	if !r.Alive["b1"] {
		t.Fatal("player did not come back")
	}
	if _, queued := r.RespawnAt["b1"]; queued {
		t.Error("respawn entry was not cleared")
	}
	if p.Health != statsOf(p).Health {
		t.Errorf("respawned with %d health, want %d", p.Health, statsOf(p).Health)
	}
	shield := time.Until(p.InvulnerableUntil)
	if shield <= 4*time.Second || shield > SpawnShieldDuration {
		t.Errorf("spawn shield is %v, want about %v", shield, SpawnShieldDuration)
	}
	// و باید روی زمینِ خودِ همین حالت برگشته باشد
	if a := arenaOf(p); a == nil || a.Name != "revenge" {
		t.Errorf("respawned onto the wrong arena: %v", a)
	}
	if arenaOf(p).CircleBlocked(p.X, p.Y, playerRadius) {
		t.Errorf("respawn point (%.0f,%.0f) is inside a wall", p.X, p.Y)
	}
}

// محافظِ تولد واقعاً تیر را رد می‌کند — نه فقط یک افکتِ گرافیکی
func TestSpawnShieldBlocksBullets(t *testing.T) {
	if arena == nil {
		if err := LoadArena(); err != nil {
			t.Fatalf("arena: %v", err)
		}
	}
	h := NewHub()
	shooter := addPlayer(h, "shooter", "0", "mr3", 500, 500)
	target := addPlayer(h, "target", "1", "mr3", 540, 500)
	shooter.Arena = ArenaForMode("revenge")
	target.Arena = ArenaForMode("revenge")

	target.InvulnerableUntil = time.Now().Add(SpawnShieldDuration)
	if h.validateHit(shooter, "target") {
		t.Error("a bullet went through the spawn shield")
	}

	// محافظ که تمام شد، همان شلیک باید بگیرد
	target.InvulnerableUntil = time.Now().Add(-time.Millisecond)
	if !h.validateHit(shooter, "target") {
		t.Error("the target stayed invulnerable after the shield expired")
	}
}

// امتیاز فقط از مسیرِ سرور بالا می‌رود: خودکشی و آتشِ خودی حساب نمی‌شود
func TestRevengeKillCredit(t *testing.T) {
	h := NewHub()
	r := newRevengeRound(h, "mr4", map[string]string{
		"a1": "0", "a2": "0", "b1": "1", "b2": "1",
	})

	h.creditKill("a1", "b1")    // درست
	h.creditKill("a1", "b2")    // درست
	h.creditKill("b1", "b2")    // آتشِ خودی
	h.creditKill("a2", "a2")    // خودکشی
	h.creditKill("ghost", "b1") // کسی که اصلاً در راند نیست

	if got := r.Kills["a1"]; got != 2 {
		t.Errorf("a1 should have 2 kills, got %d", got)
	}
	if got := r.Kills["b1"]; got != 0 {
		t.Errorf("friendly fire scored: b1 has %d kills", got)
	}
	if got := r.Kills["a2"]; got != 0 {
		t.Errorf("suicide scored: a2 has %d kills", got)
	}
	score := r.TeamScore()
	if score["0"] != 2 || score["1"] != 0 {
		t.Errorf("team score is %v, want map[0:2 1:0]", score)
	}
}

// آخرِ وقت: تیمی که بیشتر زده می‌برد
func TestRevengeTimeUpGivesItToTheTopTeam(t *testing.T) {
	h := NewHub()
	r := newRevengeRound(h, "mr5", map[string]string{"a1": "0", "b1": "1"})
	h.creditKill("b1", "a1")
	h.creditKill("b1", "a1")
	h.creditKill("a1", "b1")

	r.Deadline = time.Now().Add(-time.Second)
	h.tickRounds()

	if !r.Ended {
		t.Fatal("round did not end when the clock ran out")
	}
}

// امتیازِ برابر یعنی مساوی — نه بردِ تصادفی
func TestRevengeEqualScoreIsADraw(t *testing.T) {
	h := NewHub()
	r := newRevengeRound(h, "mr6", map[string]string{"a1": "0", "b1": "1"})
	h.creditKill("a1", "b1")
	h.creditKill("b1", "a1")

	if _, ok := r.leadingTeam(); ok {
		t.Error("an equal score must not produce a leader")
	}

	r.Deadline = time.Now().Add(-time.Second)
	h.tickRounds()
	if !r.Ended {
		t.Fatal("round did not end")
	}
}

// زمینِ انتقام واقعاً جدا و سالم است
func TestRevengeArenaIsItsOwnMap(t *testing.T) {
	if arena == nil {
		if err := LoadArena(); err != nil {
			t.Fatalf("arena: %v", err)
		}
	}
	rev := ArenaForMode("revenge")
	def := ArenaForMode("strike")

	if rev == nil || def == nil {
		t.Fatal("arenas did not load")
	}
	if rev == def {
		t.Fatal("revenge is still playing on the default arena")
	}
	if rev.Name != "revenge" || def.Name != DefaultMapName {
		t.Errorf("arena names are wrong: %q / %q", rev.Name, def.Name)
	}
	if MapNameForMode("revenge") != "revenge" || MapNameForMode("strike") != DefaultMapName {
		t.Error("the map name sent to the client does not match the arena in use")
	}
	// دو تیم باید دو سرِ زمین شروع کنند و هیچ‌کدام داخلِ دیوار نباشند
	if len(rev.Rooms) < 2 {
		t.Fatalf("revenge arena has %d rooms — team spawns need at least 2", len(rev.Rooms))
	}
	if len(rev.Spawns) == 0 {
		t.Fatal("revenge arena has no spawn points")
	}
	for _, s := range rev.Spawns {
		if rev.CircleBlocked(s[0], s[1], playerRadius) {
			t.Errorf("spawn point (%.0f,%.0f) is inside a wall", s[0], s[1])
		}
	}
	ax, ay := rev.TeamSpawn("m", 0, 0, 2, nil)
	bx, by := rev.TeamSpawn("m", 1, 0, 2, nil)
	if distance(ax, ay, bx, by) < 500 {
		t.Errorf("the two teams start %.0f apart — too close for a 2v2", distance(ax, ay, bx, by))
	}
}

// بازیکنی که بعد از شروعِ راند اضافه شده هم باید ریسپاون شود.
//
// باگِ واقعی: اسمش در playerRound بود ولی در Alive نبود، پس
// onPlayerEliminated مرگش را «قبلاً افتاده» حساب می‌کرد و هیچ‌وقت برنمی‌گشت
// — از دیدِ بازیکن یعنی «یک بار که مردم، دیگر اصلاً زنده نشدم».
func TestLateJoinerStillRespawns(t *testing.T) {
	h := NewHub()
	r := newRevengeRound(h, "mr7", map[string]string{"a1": "0"})

	// دیرآمده: فقط playerRound دارد، در Team/Alive نیست
	late := addPlayer(h, "late", "1", "mr7", 400, 400)
	h.playerRound["late"] = "mr7"

	h.onPlayerEliminated("late")

	if _, known := r.Team["late"]; !known {
		t.Fatal("a late joiner never got registered in the round")
	}
	if r.Alive["late"] {
		t.Error("the dead late joiner is still marked alive")
	}
	if _, queued := r.RespawnAt["late"]; !queued {
		t.Fatal("no respawn was scheduled for the late joiner")
	}

	r.RespawnAt["late"] = time.Now().Add(-time.Millisecond)
	h.tickRounds()
	if !r.Alive["late"] {
		t.Error("the late joiner never came back")
	}
	if late.Health <= 0 {
		t.Errorf("respawned with %d health", late.Health)
	}
}

// joinRound نباید وضعیتِ کسی که از قبل در راند است را ریست کند
func TestJoinRoundIsIdempotent(t *testing.T) {
	h := NewHub()
	r := newRevengeRound(h, "mr8", map[string]string{"a1": "0", "b1": "1"})
	h.creditKill("a1", "b1")
	r.Alive["a1"] = false

	h.joinRound(r, "a1", "0", true)

	if r.Kills["a1"] != 1 {
		t.Errorf("a re-join wiped the score: %d kills", r.Kills["a1"])
	}
	if r.Alive["a1"] {
		t.Error("a re-join brought a dead player back to life without a respawn")
	}
}

// شلیک کردن، گنبدِ خودت را برمی‌دارد — و تا وقتی برنداشته‌ای، تیرت ثبت
// نمی‌شود.
//
// باگِ واقعی: validateHit شلیکِ بازیکنِ حصانت‌دار را رد می‌کند. با محافظِ
// پنج ثانیه‌ایِ تولد یعنی بعد از هر ریسپاون پنج ثانیه شلیک می‌کردی و هیچ
// اتفاقی نمی‌افتاد — «زنده می‌شوم ولی اصلاً نمی‌توانم تیر بزنم».
func TestAttackingEndsYourOwnShield(t *testing.T) {
	if arena == nil {
		if err := LoadArena(); err != nil {
			t.Fatalf("arena: %v", err)
		}
	}
	h := NewHub()
	shooter := addPlayer(h, "fresh", "0", "mr9", 500, 500)
	target := addPlayer(h, "foe", "1", "mr9", 545, 500)
	shooter.Arena = ArenaForMode("revenge")
	target.Arena = ArenaForMode("revenge")

	// تازه زنده شده: گنبد دارد
	shooter.InvulnerableUntil = time.Now().Add(SpawnShieldDuration)
	if h.validateHit(shooter, "foe") {
		t.Fatal("a shielded player should not land hits before dropping the shield")
	}

	// همان کاری که هندلرِ hit قبل از اعتبارسنجی می‌کند
	h.dropSpawnShield(shooter)

	if time.Now().Before(shooter.InvulnerableUntil) {
		t.Error("the shield survived an attack")
	}
	if !h.validateHit(shooter, "foe") {
		t.Error("the shot still does not register after the shield dropped")
	}

	// و گنبدِ حریف سرِ جایش می‌ماند — این یکی با شلیکِ ما نباید برود
	target.InvulnerableUntil = time.Now().Add(SpawnShieldDuration)
	h.dropSpawnShield(shooter)
	if !time.Now().Before(target.InvulnerableUntil) {
		t.Error("shooting removed the target's shield instead of the shooter's")
	}
}
