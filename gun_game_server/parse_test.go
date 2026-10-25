package main

import (
	"encoding/json"
	"math"
	"testing"
)

// دقیقاً همان چیزی که scripts/Network.gd برای بمب می‌فرستد
const clientBombJSON = `{"type":"bomb","username":"ali","dir_x":0.6,"dir_y":-0.8,"dist":137.5}`

// این تست همان باگی را می‌گیرد که بمب را همیشه ته برد می‌انداخت:
// readPump فیلدها را دستی کپی می‌کرد و dist را جا انداخته بود، پس
// msg.Distance صفر می‌ماند و هندلر بمب به BombRange برمی‌گشت.
func TestParseWSMessageReadsBombDistance(t *testing.T) {
	var raw map[string]interface{}
	if err := json.Unmarshal([]byte(clientBombJSON), &raw); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	msg := parseWSMessage(raw)

	if msg.Type != "bomb" || msg.Username != "ali" {
		t.Fatalf("basic fields wrong: %+v", msg)
	}
	if math.Abs(msg.Distance-137.5) > 0.001 {
		t.Errorf("dist not parsed: got %v, want 137.5 — the bomb would fall back to max range", msg.Distance)
	}
	if math.Abs(msg.DirectionX-0.6) > 0.001 || math.Abs(msg.DirectionY-(-0.8)) > 0.001 {
		t.Errorf("direction not parsed: %v, %v", msg.DirectionX, msg.DirectionY)
	}
}

// هر فیلدی که کلاینت واقعاً می‌فرستد باید خوانده شود
func TestParseWSMessageReadsEveryClientField(t *testing.T) {
	raw := map[string]interface{}{
		"type": "move", "username": "ali", "target": "reza",
		"x": 12.5, "y": -3.25, "rot": 1.5,
		"character": "skin_default", "weapon": "ak47",
		"dir_x": 1.0, "dir_y": 2.0, "dist": 300.0,
	}
	m := parseWSMessage(raw)
	for name, ok := range map[string]bool{
		"type": m.Type == "move", "username": m.Username == "ali", "target": m.Target == "reza",
		"x": m.X == 12.5, "y": m.Y == -3.25, "rot": m.Rot == 1.5,
		"character": m.CharID == "skin_default", "weapon": m.Weapon == "ak47",
		"dir_x": m.DirectionX == 1.0, "dir_y": m.DirectionY == 2.0, "dist": m.Distance == 300.0,
	} {
		if !ok {
			t.Errorf("field %q was not parsed from the client message", name)
		}
	}
}

// 🛡️ ضدتقلب: این‌ها هرگز نباید از کلاینت خوانده شوند
func TestParseWSMessageIgnoresServerOwnedFields(t *testing.T) {
	m := parseWSMessage(map[string]interface{}{
		"type": "bomb", "radius": 9999.0, "damage": 9999.0, "health": 9999.0,
	})
	if m.Radius != 0 || m.Damage != 0 || m.Health != 0 {
		t.Errorf("client-supplied radius/damage/health leaked in: %+v", m)
	}
}
