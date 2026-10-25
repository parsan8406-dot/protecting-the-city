package main

import (
	"math"
	"testing"
	"time"
)

// یک هاب و یک بازیکن آماده‌ی تست، بدون شبکه و دیتابیس
func bombHub(t *testing.T) (*Hub, *Client, *Player) {
	t.Helper()
	mustArena(t)
	h := NewHub()
	c := &Client{username: "tester", send: make(chan []byte, 256)}
	h.clients[c] = true
	p := &Player{Username: "tester", Health: 100, X: 1000, Y: 560,
		InvulnerableUntil: time.Now().Add(-time.Hour), LastMoveTime: time.Now()}
	applyLoadout(p, "skin_default", "ak47", 1)
	h.players["tester"] = p
	return h, c, p
}

// همسایه‌ای دور از محل انفجار که نباید آسیب ببیند
func addVictim(h *Hub, name string, x, y float64) *Player {
	v := &Player{Username: name, Health: 100, X: x, Y: y,
		InvulnerableUntil: time.Now().Add(-time.Hour), LastMoveTime: time.Now()}
	applyLoadout(v, "skin_default", "ak47", 1)
	h.players[name] = v
	return v
}

// 🛡️ اکسپلویت NaN: با dir_x = NaN مختصات انفجار NaN می‌شد و چون
// `NaN > radius` همیشه false است، بررسی فاصله هیچ‌کس را رد نمی‌کرد.
func TestBombRejectsNonFiniteInput(t *testing.T) {
	for _, bad := range []struct {
		name             string
		dx, dy, distance float64
	}{
		{"NaN dir_x", math.NaN(), 0, 300},
		{"NaN dir_y", 0, math.NaN(), 300},
		{"+Inf dir", math.Inf(1), 0, 300},
		{"NaN dist", 1, 0, math.NaN()},
		{"-Inf dist", 1, 0, math.Inf(-1)},
	} {
		t.Run(bad.name, func(t *testing.T) {
			h, c, _ := bombHub(t)
			far := addVictim(h, "faraway", 1900, 100)

			h.handleAction(c, WSMessage{
				Type: "bomb", Username: "tester",
				DirectionX: bad.dx, DirectionY: bad.dy, Distance: bad.distance,
			})

			if _, thrown := h.bombCooldowns["tester"]; thrown {
				t.Error("a bomb with non-finite input should be rejected outright")
			}
			if far.Health != 100 {
				t.Errorf("far player took %d damage from a malformed bomb", 100-far.Health)
			}
		})
	}
}

// خط دفاعی دوم: مختصات خراب نباید تا حلقه‌ی خسارت برسد
func TestApplyBombDamageIgnoresBadGeometry(t *testing.T) {
	h, _, _ := bombHub(t)
	far := addVictim(h, "faraway", 1900, 100)
	near := addVictim(h, "nearby", 1010, 560)

	h.applyBombDamageInternal("", "tester", math.NaN(), math.NaN(), 104, 50)
	if far.Health != 100 || near.Health != 100 {
		t.Errorf("NaN explosion damaged players (far=%d near=%d)", far.Health, near.Health)
	}
	h.applyBombDamageInternal("", "tester", 1000, 560, math.Inf(1), 50)
	if far.Health != 100 {
		t.Errorf("infinite radius damaged the whole map (far=%d)", far.Health)
	}
}

// برد بمب همیشه به بردِ کاراکتر محدود می‌شود، هرچه کلاینت ادعا کند
func TestBombRangeIsClamped(t *testing.T) {
	h, c, p := bombHub(t)
	st := statsOf(p)
	victim := addVictim(h, "victim", p.X+st.BombRange+400, p.Y)

	h.handleAction(c, WSMessage{
		Type: "bomb", Username: "tester",
		DirectionX: 1, DirectionY: 0, Distance: 99999,
	})
	h.applyBombDamageInternal("", "tester", p.X+st.BombRange, p.Y, st.BombRadius, st.BombDamage)

	if victim.Health != 100 {
		t.Errorf("player beyond bomb range (%.0f) was hit; client distance was not clamped", st.BombRange)
	}
}

// کول‌داون نباید با join دوباره ریست شود
func TestBombCooldownSurvivesRejoin(t *testing.T) {
	h, c, _ := bombHub(t)
	throw := func() {
		h.handleAction(c, WSMessage{
			Type: "bomb", Username: "tester", DirectionX: 1, DirectionY: 0, Distance: 300})
	}

	throw()
	first, ok := h.bombCooldowns["tester"]
	if !ok {
		t.Fatal("first bomb should have been accepted")
	}

	// شبیه‌سازی قطع اتصال و ورود دوباره: Player تازه با LastBombTime صفر
	fresh := &Player{Username: "tester", Health: 100, X: 1000, Y: 560,
		InvulnerableUntil: time.Now().Add(-time.Hour), LastMoveTime: time.Now()}
	applyLoadout(fresh, "skin_default", "ak47", 1)
	h.players["tester"] = fresh

	throw()
	if h.bombCooldowns["tester"] != first {
		t.Error("rejoining reset the bomb cooldown — bombs can be spammed by reconnecting")
	}
}

// جهت صفر نباید بمب را زیر پای خود بازیکن بیندازد
func TestBombZeroDirectionThrowsForward(t *testing.T) {
	h, c, p := bombHub(t)
	p.Rot = math.Pi / 2 // رو به +X
	h.handleAction(c, WSMessage{
		Type: "bomb", Username: "tester", DirectionX: 0, DirectionY: 0, Distance: 300})
	if _, ok := h.bombCooldowns["tester"]; !ok {
		t.Fatal("a zero-direction bomb should still be thrown, not dropped")
	}
}
