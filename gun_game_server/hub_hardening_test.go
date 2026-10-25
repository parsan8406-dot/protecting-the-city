package main

import (
	"math"
	"testing"
	"time"
)

// rot عظیم از یک کلاینتِ دستکاری‌شده نباید هاب را در حلقه‌ی بی‌پایان
// angleDiff قفل کند — جواب همیشه در (-π, π] و فوری است.
func TestAngleDiffHugeInputTerminates(t *testing.T) {
	done := make(chan float64, 1)
	go func() { done <- angleDiff(0, 1e300) }()
	select {
	case d := <-done:
		if math.Abs(d) > math.Pi+1e-9 {
			t.Fatalf("angleDiff out of range: %v", d)
		}
	case <-time.After(time.Second):
		t.Fatal("angleDiff(0, 1e300) did not return")
	}
	if d := angleDiff(0.1, 2*math.Pi-0.1); math.Abs(d+0.2) > 1e-9 {
		t.Fatalf("wraparound wrong: %v", d)
	}
}

// مُرده نه تیر می‌زند نه تیر می‌خورد — وگرنه تیرهای در راه «کشتن» تکراری
// ثبت می‌کردند.
func TestNoHitsOnOrByDeadPlayers(t *testing.T) {
	h := NewHub()
	a := addPlayer(h, "a", "0", "m1", 500, 500)
	b := addPlayer(h, "b", "1", "m1", 520, 500)
	if !h.validateHit(a, "b") {
		t.Fatal("live hit should be valid")
	}
	b.Health = 0
	if h.validateHit(a, "b") {
		t.Fatal("hit on a dead target must be rejected")
	}
	b.Health = 50
	a.Health = 0
	if h.validateHit(a, "b") {
		t.Fatal("hit by a dead shooter must be rejected")
	}
}

// کلاینتی که به‌خاطرِ صفِ پر کنار گذاشته شده: اکشن‌های در صف‌مانده‌اش
// نباید روی کانالِ بسته بنویسند (panic)، و بازیکنش نباید روح بماند.
func TestDroppedClientIsCleanedUpAndIgnored(t *testing.T) {
	h := NewHub()
	c := &Client{hub: h, username: "slow", send: make(chan []byte)}
	h.clients[c] = true
	h.sessions["slow"] = c
	addPlayer(h, "slow", "0", "", 500, 500)

	h.sendTo(c, []byte("x")) // کانالِ بدونِ بافر → پر → drop
	if !c.closed {
		t.Fatal("full client should be closed")
	}
	h.flushDropped()
	if _, ok := h.players["slow"]; ok {
		t.Fatal("dropped client's player must be removed")
	}
	// نباید panic کند
	h.handleAction(c, WSMessage{Type: "ping", RawData: map[string]interface{}{}})
	h.sendTo(c, []byte("y"))
}

// اتصالِ دوباره با سوکتِ تازه: بسته شدنِ سوکتِ قدیمی نباید بازیکنِ تازه را
// پاک کند.
func TestStaleSocketDoesNotWipeNewSession(t *testing.T) {
	h := NewHub()
	old := &Client{hub: h, username: "p", send: make(chan []byte, 4)}
	cur := &Client{hub: h, username: "p", send: make(chan []byte, 4)}
	h.clients[cur] = true
	h.sessions["p"] = cur
	addPlayer(h, "p", "0", "", 500, 500)

	h.cleanupClient(old)
	if _, ok := h.players["p"]; !ok {
		t.Fatal("stale socket cleanup removed the live session's player")
	}
}

// زمینِ آزمایشیِ ۱۰۰۰×۲۰۰ با یک دیوارِ نازکِ عمودی (یک خانه = ۲۰ واحد) در x=500.
func thinWallArena() *Arena {
	a := &Arena{W: 1000, H: 200, cell: 20, cols: 50, rows: 10}
	a.cells = make([]bool, a.cols*a.rows)
	for cy := 0; cy < a.rows; cy++ {
		a.cells[cy*a.cols+25] = true
	}
	return a
}

// یک پرشِ بزرگ (مثلاً بعد از یک ثانیه وقفه) نباید از دیوارِ نازک رد شود.
func TestBigMoveCannotTunnelThroughThinWall(t *testing.T) {
	a := thinWallArena()
	x, _ := a.ResolveMoveMax(400, 100, 700, 100, playerRadius, 340)
	if x > 500 {
		t.Fatalf("player tunneled through the wall: x=%v", x)
	}
}

// پیام‌های move پشتِ‌سرِهم و با فاصله‌ی صفر نباید سرعت‌هک بدهند — قبلاً هر
// پیام حداقل ۸ واحد جابه‌جایی می‌گرفت.
func TestRapidMoveSpamIsSpeedCapped(t *testing.T) {
	h := NewHub()
	a := &Arena{W: 5000, H: 400, cell: 20, cols: 250, rows: 20}
	a.cells = make([]bool, a.cols*a.rows)
	p := addPlayer(h, "speedy", "0", "m1", 100, 200)
	p.Arena = a
	c := &Client{hub: h, username: "speedy", send: make(chan []byte, 4096)}
	h.clients[c] = true
	start := time.Now()
	for i := 0; i < 500; i++ {
		h.handleAction(c, WSMessage{Type: "move", X: p.X + 8, Y: 200, Rot: p.Rot})
	}
	elapsed := time.Since(start).Seconds()
	moved := p.X - 100
	// حداکثر: نیم‌ثانیه ذخیره + سرعتِ مجاز × زمانِ واقعی (با حاشیه برای تیکِ اول)
	limit := maxMoveSpeed*SprintSpeedMult*(0.5+elapsed) + 1
	if moved > limit {
		t.Fatalf("moved %.0f units in %.3fs (limit %.0f)", moved, elapsed, limit)
	}
}

// ماموریتِ «کمک»: هم‌تیمی‌ای که چند ثانیه قبل از کشته شدنِ حریف به او آسیب
// زده یک کمک می‌گیرد؛ خودِ قاتل و حریف‌ها نه.
func TestAssistCreditedToRecentTeammateDamager(t *testing.T) {
	h := NewHub()
	r := newRound(h, "as1", map[string]string{"a": "0", "b": "0", "c": "0", "v": "1"}, nil)
	h.noteDamage("a", "v")
	h.noteDamage("c", "v")
	r.Damagers["v"]["c"] = time.Now().Add(-assistWindow - time.Second) // کهنه
	if !h.creditKill("b", "v") {
		t.Fatal("kill should be credited")
	}
	if r.Assists["a"] != 1 {
		t.Fatalf("a should have 1 assist, got %d", r.Assists["a"])
	}
	if r.Assists["b"] != 0 || r.Assists["c"] != 0 {
		t.Fatalf("killer/stale damager must not get assists: %v", r.Assists)
	}
	if liveDelta(r, "a", MetricAssists) != 1 {
		t.Fatal("assist metric not exposed to live objectives")
	}
}

// زندگیِ تازه = تجهیزاتِ کامل: بمب‌ها پر، قفل‌ها و اثرهای زندگیِ قبلی پاک.
func TestRespawnRestoresFullKit(t *testing.T) {
	h := NewHub()
	r := newRound(h, "kit1", map[string]string{"me": "0", "foe": "1"}, nil)
	p := addPlayer(h, "me", "0", "kit1", 500, 500)
	addPlayer(h, "foe", "1", "kit1", 900, 500)
	h.bombsUsed[bombStockKey(p)] = BombStock
	p.BombsLeft = 0
	now := time.Now()
	h.bombCooldowns["me"] = now
	h.lockAbility("me", "guard", now.Add(time.Minute))
	p.LastHealTime = now
	p.GuardUntil = now.Add(time.Second)
	p.Health = 0
	r.Alive["me"] = false

	h.respawnInRound(r, "me")

	if p.BombsLeft != BombStock || h.bombsLeftFor(p) != BombStock {
		t.Fatalf("bombs not refilled: %d/%d", p.BombsLeft, h.bombsLeftFor(p))
	}
	if !h.abilityReady("me", "guard", time.Now()) {
		t.Fatal("guard cooldown survived the respawn")
	}
	if !p.LastHealTime.IsZero() || isGuarded(p, time.Now()) {
		t.Fatal("heal cooldown / guard survived the respawn")
	}
	if p.Health != statsOf(p).Health {
		t.Fatalf("health not full: %d", p.Health)
	}
}

// راندِ قدیمی وقتی تمام می‌شود نباید باتی را که حالا در مسابقه‌ی دیگری
// است، یا ردِ راندِ تازه‌ی یک آدم را، پاک کند.
func TestEndingOldRoundSparesThingsNowInAnotherMatch(t *testing.T) {
	h := NewHub()
	old := newRound(h, "old1", map[string]string{"human": "0", "bot1": "1"}, nil)
	h.bots["bot1"] = &BotRuntime{}
	addPlayer(h, "bot1", "1", "new1", 0, 0) // بات حالا در مسابقه‌ی تازه است
	h.playerRound["bot1"] = "new1"
	h.playerRound["human"] = "new1"

	h.endRound(old, "0", false)

	if _, ok := h.bots["bot1"]; !ok {
		t.Fatal("bot reused in another match was deleted")
	}
	if h.playerRound["human"] != "new1" || h.playerRound["bot1"] != "new1" {
		t.Fatalf("playerRound of the new match wiped: %v", h.playerRound)
	}
}

// مسابقه‌ای که آخرین آدمش رفته همان لحظه بسته می‌شود.
func TestAbandonedRoundClosesImmediately(t *testing.T) {
	h := NewHub()
	newRound(h, "ab1", map[string]string{"bot1": "1", "bot2": "0"}, nil)
	h.bots["bot1"], h.bots["bot2"] = &BotRuntime{}, &BotRuntime{}
	addPlayer(h, "bot1", "1", "ab1", 0, 0)
	addPlayer(h, "bot2", "0", "ab1", 0, 0)
	h.lockAbility("gone", "laser", time.Now().Add(time.Minute))

	h.releaseAfterLeaving("gone", "ab1")

	if _, ok := h.rounds["ab1"]; ok {
		t.Fatal("abandoned round still alive")
	}
	if len(h.bots) != 0 || len(h.players) != 0 {
		t.Fatalf("bots of the abandoned match left behind: %d bots, %d players", len(h.bots), len(h.players))
	}
}

// joinِ تکراری (یا اتصالِ دوباره) وسطِ همان مسابقه بازیکنِ زنده را از نو
// نمی‌سازد: جان، جا و مرده‌بودن همان می‌ماند.
func TestRepeatedArenaJoinKeepsLivePlayerState(t *testing.T) {
	h := NewHub()
	mmMu.Lock()
	mmMatches["rj"] = &PendingMatch{MatchID: "rjm", ModeID: "strike",
		Players: []QueuedPlayer{{Username: "rj", Team: 0}}}
	mmMu.Unlock()
	defer func() { mmMu.Lock(); delete(mmMatches, "rj"); mmMu.Unlock() }()

	p := addPlayer(h, "rj", "0", "rjm", 321, 654)
	p.InArena = true
	p.Health = 0
	c := &Client{hub: h, send: make(chan []byte, 64)}
	h.clients[c] = true
	msg := WSMessage{Type: "join", Username: "rj", Arena: true,
		loadout: &loadoutInfo{charID: "skin_default", weaponID: "ak47", charLevel: 1}}

	h.handleAction(c, msg)

	got := h.players["rj"]
	if got != p || got.Health != 0 || got.X != 321 || got.Y != 654 {
		t.Fatalf("rejoin rebuilt the player: same=%v hp=%d pos=(%v,%v)", got == p, got.Health, got.X, got.Y)
	}
	if h.sessions["rj"] != c {
		t.Fatal("rejoin must move the session to the new socket")
	}
}
