package main

import (
	"math"
	"testing"
	"time"
)

// توانایی‌های دکمه‌ای: لیزر، سپر، دویدن، درمانِ تیمی و موجودیِ بمب.
// مثل bomb_test بدون شبکه و دیتابیس، مستقیم روی Hub.

func abilityPlayer(h *Hub, name, team string, x, y float64) *Player {
	p := &Player{Username: name, Team: team, Health: 100, X: x, Y: y,
		InvulnerableUntil: time.Now().Add(-time.Hour), LastMoveTime: time.Now()}
	applyLoadout(p, "skin_default", "ak47", 1)
	p.Health = statsOf(p).Health
	h.players[name] = p
	return p
}

func abilityClient(h *Hub, name string) *Client {
	c := &Client{username: name, send: make(chan []byte, 512)}
	h.clients[c] = true
	return c
}

// یک نقطه‌ی شروع که دستِ‌کم length پیکسل به سمتِ +X باز است
func openCorridor(t *testing.T, a *Arena, length float64) (float64, float64) {
	t.Helper()
	// نقطه‌های شروع کم‌اند؛ کلِ نقشه روی یک توری جست‌وجو می‌شود
	for y := 60.0; y < a.H-60; y += 40 {
		for x := 60.0; x < a.W-length-60; x += 40 {
			if corridorFree(a, x, y, length) {
				return x, y
			}
		}
	}
	t.Skip("no open corridor on this map")
	return 0, 0
}

// corridorFree بدنِ بازیکن در تمامِ طولِ مسیر به دیوار نمی‌خورد
func corridorFree(a *Arena, x, y, length float64) bool {
	for d := 0.0; d <= length; d += 8 {
		if a.CircleBlocked(x+d, y, playerRadius+LaserHalfWidth) {
			return false
		}
	}
	return true
}

// نقطه‌ای که دیوارش به سمتِ +X بینِ min و max پیکسل فاصله دارد
func wallAhead(t *testing.T, a *Arena, min, max float64) (x, y, wallX float64) {
	t.Helper()
	for _, s := range a.Spawns {
		x, y := s[0], s[1]
		hx, _ := a.RayHitPoint(x, y, x+LaserRange, y)
		if d := hx - x; d >= min && d <= max {
			return x, y, hx
		}
	}
	t.Skip("no wall at a suitable distance on this map")
	return 0, 0, 0
}

// runLaser لیزر را می‌زند و تمامِ ضربه‌هایش را یک‌جا اجرا می‌کند
func runLaser(h *Hub, c *Client, p *Player) {
	p.Rot = math.Pi / 2 // رو به +X
	h.handleAbility(c, "laser")
	h.tickAbilities(time.Now().Add(LaserDuration + time.Second))
}

func TestLaserPiercesBodiesAndDealsSixtyPercent(t *testing.T) {
	a := mustArena(t)
	h := NewHub()
	x, y := openCorridor(t, a, 420)
	c := abilityClient(h, "shooter")
	p := abilityPlayer(h, "shooter", "0", x, y)
	near := abilityPlayer(h, "near", "1", x+150, y)
	far := abilityPlayer(h, "far", "1", x+380, y) // پشتِ هدفِ اول
	ally := abilityPlayer(h, "ally", "0", x+250, y)

	runLaser(h, c, p)

	maxHP := statsOf(near).Health
	want := maxHP - laserTicks*laserTickDamage(maxHP)
	if near.Health != want || far.Health != want {
		t.Errorf("laser should pierce both foes for %d total (near=%d far=%d, want %d)",
			maxHP-want, near.Health, far.Health, want)
	}
	if lost := float64(maxHP-near.Health) / float64(maxHP); lost < 0.59 || lost > 0.66 {
		t.Errorf("a full laser took %.0f%% of max health, want ~60%%", lost*100)
	}
	if ally.Health != statsOf(ally).Health {
		t.Error("laser damaged a teammate")
	}
}

func TestLaserStopsAtWalls(t *testing.T) {
	a := mustArena(t)
	h := NewHub()
	x, y, wallX := wallAhead(t, a, 120, 600)
	c := abilityClient(h, "shooter")
	p := abilityPlayer(h, "shooter", "0", x, y)
	behind := abilityPlayer(h, "behind", "1", wallX+LaserHalfWidth+playerRadius+40, y)

	runLaser(h, c, p)

	if behind.Health != statsOf(behind).Health {
		t.Errorf("laser went through a wall (target took %d)", statsOf(behind).Health-behind.Health)
	}
}

func TestLaserCooldownLocksButton(t *testing.T) {
	mustArena(t)
	h := NewHub()
	c := abilityClient(h, "shooter")
	p := abilityPlayer(h, "shooter", "0", 1000, 560)
	h.handleAbility(c, "laser")
	first := p.LaserUntil
	h.handleAbility(c, "laser")
	if p.LaserUntil != first {
		t.Error("laser fired again while locked")
	}
}

func TestGuardBlocksShotsAndBombs(t *testing.T) {
	mustArena(t)
	h := NewHub()
	c := abilityClient(h, "guarded")
	g := abilityPlayer(h, "guarded", "1", 1000, 560)
	shooter := abilityPlayer(h, "shooter", "0", 1050, 560)

	h.handleAbility(c, "guard")
	if !isGuarded(g, time.Now()) {
		t.Fatal("guard did not activate")
	}
	if h.validateHit(shooter, "guarded") {
		t.Error("a guarded player can still be shot")
	}
	before := g.Health
	h.applyBombDamageInternal("", "shooter", g.X, g.Y, 120, 40)
	if g.Health != before {
		t.Error("a guarded player took bomb damage")
	}
	// سپرِ دستی جلوی شلیکِ خودِ صاحبش را نمی‌گیرد
	if !h.validateHit(g, "shooter") {
		t.Error("the guard also stopped its owner from shooting")
	}

	g.GuardUntil = time.Now().Add(-time.Millisecond)
	if !h.validateHit(shooter, "guarded") {
		t.Error("the guard outlived its duration")
	}
}

func TestBombStockIsThreePerMatch(t *testing.T) {
	h, c, _ := bombHub(t)
	throws := 0
	for i := 0; i < BombStock+2; i++ {
		before := len(h.bombsUsed)
		used := h.bombsUsed[":tester"]
		delete(h.bombCooldowns, "tester") // فقط موجودی سنجیده می‌شود، نه کول‌داون
		h.handleAction(c, WSMessage{Type: "bomb", Username: "tester", DirectionX: 1, Distance: 200})
		if h.bombsUsed[":tester"] > used || len(h.bombsUsed) > before {
			throws++
		}
	}
	if throws != BombStock {
		t.Errorf("threw %d bombs, want exactly %d", throws, BombStock)
	}

	// join دوباره موجودی را پر نمی‌کند
	fresh := &Player{Username: "tester", Health: 100, X: 1000, Y: 560,
		InvulnerableUntil: time.Now().Add(-time.Hour), LastMoveTime: time.Now()}
	applyLoadout(fresh, "skin_default", "ak47", 1)
	h.players["tester"] = fresh
	if left := h.bombsLeftFor(fresh); left != 0 {
		t.Errorf("rejoining refilled bombs to %d", left)
	}
}

// زمینِ تمرین پایانِ راند ندارد: بدونِ پاک کردن در join، بعد از سه بمب
// بازیکن تا ابد بی‌بمب می‌ماند
func TestPracticeArenaRefillsBombsOnEntry(t *testing.T) {
	h := NewHub()
	solo := &Player{Username: "solo"}
	h.bombsUsed[":solo"] = BombStock
	h.prepareBombStock(solo, true)
	if solo.BombsLeft != BombStock {
		t.Errorf("practice entry left %d bombs, want %d", solo.BombsLeft, BombStock)
	}

	// در مسابقه، ورودِ دوباره (قطع و وصل) موجودی را پر نمی‌کند
	ranked := &Player{Username: "p1", MatchID: "m1"}
	h.bombsUsed["m1:p1"] = 2
	h.prepareBombStock(ranked, true)
	if ranked.BombsLeft != BombStock-2 {
		t.Errorf("rejoining a match refilled bombs to %d", ranked.BombsLeft)
	}
}

func TestSprintRaisesTheServerSpeedCap(t *testing.T) {
	a := mustArena(t)
	x, y := openCorridor(t, a, 260)
	dt := 0.5
	step := maxMoveSpeed * dt * 1.12 // بیشتر از سقفِ عادی، کمتر از سقفِ دویدن

	move := func(sprint bool) float64 {
		h := NewHub()
		c := abilityClient(h, "runner")
		p := abilityPlayer(h, "runner", "0", x, y)
		if sprint {
			h.handleAbility(c, "sprint")
		}
		p.LastMoveTime = time.Now().Add(-time.Duration(dt * float64(time.Second)))
		h.handleAction(c, WSMessage{Type: "move", X: x + step, Y: y, Rot: p.Rot})
		return p.X - x
	}

	if walked := move(false); walked >= step-1 {
		t.Errorf("without sprint the server accepted %.0fpx in %.1fs", walked, dt)
	}
	if ran := move(true); math.Abs(ran-step) > 1 {
		t.Errorf("sprinting player was cut to %.0fpx, want %.0fpx", ran, step)
	}
}

func TestTeamHealOnlyHealsNearbyTeammates(t *testing.T) {
	mustArena(t)
	h := NewHub()
	c := abilityClient(h, "medic")
	medic := abilityPlayer(h, "medic", "0", 1000, 560)
	near := abilityPlayer(h, "near", "0", 1100, 560)
	farAlly := abilityPlayer(h, "farally", "0", 1000+TeamHealRadius+80, 560)
	foe := abilityPlayer(h, "foe", "1", 1050, 560)
	for _, p := range []*Player{medic, near, farAlly, foe} {
		p.Health = 10
	}

	h.handleAbility(c, "team_heal")

	amount := statsOf(medic).HealAmount
	if medic.Health != 10+amount || near.Health != 10+amount {
		t.Errorf("medic=%d near=%d, want both %d", medic.Health, near.Health, 10+amount)
	}
	if farAlly.Health != 10 {
		t.Error("team heal reached a teammate outside its radius")
	}
	if foe.Health != 10 {
		t.Error("team heal healed an enemy")
	}

	// همه سالم → قفل نمی‌شود
	h2 := NewHub()
	c2 := abilityClient(h2, "medic")
	abilityPlayer(h2, "medic", "0", 1000, 560)
	h2.handleAbility(c2, "team_heal")
	if !h2.abilityReady("medic", "team_heal", time.Now()) {
		t.Error("team heal went on cooldown although nobody needed healing")
	}
}

func TestSegmentHitsCircle(t *testing.T) {
	if !segmentHitsCircle(0, 0, 100, 0, 50, 10, 12) {
		t.Error("point beside the middle of the beam should be hit")
	}
	if segmentHitsCircle(0, 0, 100, 0, 150, 0, 12) {
		t.Error("point past the end of the beam should not be hit")
	}
	if segmentHitsCircle(0, 0, 100, 0, 50, 30, 12) {
		t.Error("point far beside the beam should not be hit")
	}
}
