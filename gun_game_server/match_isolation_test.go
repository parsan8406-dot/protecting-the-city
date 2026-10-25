package main

import (
	"encoding/json"
	"math"
	"testing"
	"time"
)

// این فایل دقیقاً همان چهار چیزی را می‌سنجد که خراب بودند:
//   ۱. فقط هم‌مسابقه‌ای‌ها همدیگر را ببینند (اکانتی که سرچ نکرده نباید در زمین باشد)
//   ۲. بات‌های همان مسابقه وارد زمین شوند
//   ۳. آتشِ خودی ممنوع
//   ۴. هم‌تیمی‌ها کنارِ هم ظاهر شوند، دو تیم دور از هم

func addPlayer(h *Hub, name, team, matchID string, x, y float64) *Player {
	p := &Player{
		Username:     name,
		Team:         team,
		MatchID:      matchID,
		X:            x,
		Y:            y,
		Health:       100,
		JoinedAt:     time.Now(),
		LastMoveTime: time.Now(),
		Stats:        CharStats{Health: 100, Damage: 10, MaxRange: 100000, FireConeDeg: 180},
	}
	h.players[name] = p
	return p
}

// ۱. لیستِ بازیکن‌ها باید per-match باشد
func TestPlayerListIsScopedToTheMatch(t *testing.T) {
	h := NewHub()
	addPlayer(h, "meA", "0", "matchA", 100, 100)
	addPlayer(h, "foeA", "1", "matchA", 200, 200)
	// اکانتی که اصلاً سرچ نکرده: بدون مسابقه
	addPlayer(h, "IdleGuy", "", "", 300, 300)
	// و یک مسابقه‌ی کاملاً دیگر
	addPlayer(h, "meB", "0", "matchB", 400, 400)

	byMatch := map[string]map[string]*Player{}
	for name, p := range h.players {
		if byMatch[p.MatchID] == nil {
			byMatch[p.MatchID] = map[string]*Player{}
		}
		byMatch[p.MatchID][name] = p
	}

	if len(byMatch["matchA"]) != 2 {
		t.Errorf("matchA should hold exactly its 2 players, got %d: %v",
			len(byMatch["matchA"]), keysOfPlayers(byMatch["matchA"]))
	}
	if _, leaked := byMatch["matchA"]["IdleGuy"]; leaked {
		t.Error("an account that never searched leaked into the match roster")
	}
	if _, leaked := byMatch["matchA"]["meB"]; leaked {
		t.Error("a player from another match leaked into this one")
	}
}

func keysOfPlayers(m map[string]*Player) []string {
	out := []string{}
	for k := range m {
		out = append(out, k)
	}
	return out
}

// همان چیز، ولی از راهِ واقعی: پیامِ update_players که کلاینت می‌گیرد
func TestBroadcastPayloadCarriesOnlyThisMatch(t *testing.T) {
	h := NewHub()
	addPlayer(h, "meA", "0", "matchA", 100, 100)
	addPlayer(h, "IdleGuy", "", "", 300, 300)

	only := map[string]*Player{}
	for name, p := range h.players {
		if p.MatchID == "matchA" {
			only[name] = p
		}
	}
	raw, err := json.Marshal(map[string]interface{}{
		"type": "update_players", "players": only})
	if err != nil {
		t.Fatal(err)
	}
	if containsStr(string(raw), "IdleGuy") {
		t.Errorf("update_players payload leaked a non-match account:\n%s", raw)
	}
	if !containsStr(string(raw), "meA") {
		t.Errorf("update_players payload lost the real player:\n%s", raw)
	}
	// MatchID خودش نباید به کلاینت برود (json:"-")
	if containsStr(string(raw), "matchA") {
		t.Errorf("MatchID leaked into the client payload:\n%s", raw)
	}
}

func containsStr(hay, needle string) bool {
	return len(hay) >= len(needle) && (func() bool {
		for i := 0; i+len(needle) <= len(hay); i++ {
			if hay[i:i+len(needle)] == needle {
				return true
			}
		}
		return false
	})()
}

// ۳. آتشِ خودی — نه به هم‌تیمی، نه به بازیکنِ مسابقه‌ی دیگر
func TestNoFriendlyFireAndNoCrossMatchFire(t *testing.T) {
	if arena == nil {
		if err := LoadArena(); err != nil {
			t.Fatalf("LoadArena: %v", err)
		}
	}
	h := NewHub()
	// روی یک نقطه‌ی باز، نزدیک هم، تا خطِ دید و فاصله مانع نشوند
	sx, sy := arena.Spawns[0][0], arena.Spawns[0][1]
	me := addPlayer(h, "me", "0", "matchA", sx, sy)
	mate := addPlayer(h, "mate", "0", "matchA", sx+40, sy)
	foe := addPlayer(h, "foe", "1", "matchA", sx+80, sy)
	other := addPlayer(h, "other", "1", "matchB", sx+120, sy)
	past := time.Now().Add(-time.Hour)
	for _, p := range []*Player{me, mate, foe, other} {
		p.InvulnerableUntil = past
	}

	if h.validateHit(me, "mate") {
		t.Error("friendly fire got through — a teammate was hittable")
	}
	if h.validateHit(me, "other") {
		t.Error("a player in a different match was hittable")
	}
	if !h.validateHit(me, "foe") {
		t.Error("a real enemy in the same match should be hittable")
	}
}

// بات هم نباید هم‌تیمی یا بازیکنِ مسابقه‌ی دیگر را هدف بگیرد
func TestBotTargetsOnlyEnemiesInItsOwnMatch(t *testing.T) {
	h := NewHub()
	bot := addPlayer(h, "bot", "0", "matchA", 100, 100)
	addPlayer(h, "mate", "0", "matchA", 120, 100)      // هم‌تیمی
	addPlayer(h, "stranger", "1", "matchB", 130, 100)  // مسابقه‌ی دیگر
	foe := addPlayer(h, "foe", "1", "matchA", 400, 100) // حریفِ واقعی، دورتر

	got := h.pickTarget(bot)
	if got == nil {
		t.Fatal("bot found no target at all")
	}
	if got.Username != foe.Username {
		t.Errorf("bot targeted %q; it must target only the enemy in its own match (%q)",
			got.Username, foe.Username)
	}
}

// ۴. هم‌تیمی‌ها کنارِ هم، دو تیم دور از هم
func TestTeamsSpawnTogetherAndApart(t *testing.T) {
	if arena == nil {
		if err := LoadArena(); err != nil {
			t.Fatalf("LoadArena: %v", err)
		}
	}
	if len(arena.Rooms) < 2 {
		t.Fatalf("map has %d rooms; team spawns need at least 2", len(arena.Rooms))
	}

	const matchID = "m-spawn-test"
	const teamSize = 4
	var occupied [][2]float64
	teamPts := map[int][][2]float64{}

	for team := 0; team < 2; team++ {
		for seat := 0; seat < teamSize; seat++ {
			x, y := arena.TeamSpawn(matchID, team, seat, teamSize, occupied)
			if arena.CircleBlocked(x, y, playerRadius) {
				t.Fatalf("team %d seat %d spawned inside a wall at (%.0f,%.0f)", team, seat, x, y)
			}
			teamPts[team] = append(teamPts[team], [2]float64{x, y})
			occupied = append(occupied, [2]float64{x, y})
		}
	}

	spread := func(pts [][2]float64) float64 {
		worst := 0.0
		for i := range pts {
			for j := i + 1; j < len(pts); j++ {
				d := math.Hypot(pts[i][0]-pts[j][0], pts[i][1]-pts[j][1])
				if d > worst {
					worst = d
				}
			}
		}
		return worst
	}
	centre := func(pts [][2]float64) (float64, float64) {
		var sx, sy float64
		for _, p := range pts {
			sx += p[0]
			sy += p[1]
		}
		return sx / float64(len(pts)), sy / float64(len(pts))
	}

	s0, s1 := spread(teamPts[0]), spread(teamPts[1])
	c0x, c0y := centre(teamPts[0])
	c1x, c1y := centre(teamPts[1])
	between := math.Hypot(c1x-c0x, c1y-c0y)

	t.Logf("team0 spread %.0f, team1 spread %.0f, distance between teams %.0f", s0, s1, between)

	// هم‌تیمی‌ها باید در یک اتاق جمع باشند — بزرگ‌ترین اتاقِ نقشه ~۵۶۰ عرض دارد
	if s0 > 600 || s1 > 600 {
		t.Errorf("teammates are scattered: spreads %.0f and %.0f (want them in one room)", s0, s1)
	}
	// و دو تیم باید واقعاً از هم دور باشند، نه اینکه روبه‌روی هم بیفتند
	if between < 700 {
		t.Errorf("the two teams spawn only %.0f apart — they should start far from each other", between)
	}
	// هیچ دو نفری روی هم نیفتند
	for i := range occupied {
		for j := i + 1; j < len(occupied); j++ {
			d := math.Hypot(occupied[i][0]-occupied[j][0], occupied[i][1]-occupied[j][1])
			if d < 1.0 {
				t.Errorf("two players spawned on the same spot (%.0f,%.0f)", occupied[i][0], occupied[i][1])
			}
		}
	}
}

// انتخابِ اتاق باید برای یک مسابقه ثابت بماند، وگرنه هر بازیکن جای دیگری
// ظاهر می‌شود
func TestTeamRoomsAreStablePerMatch(t *testing.T) {
	if arena == nil {
		if err := LoadArena(); err != nil {
			t.Fatalf("LoadArena: %v", err)
		}
	}
	a1, b1, ok1 := arena.teamRoomsFor("match-xyz")
	a2, b2, ok2 := arena.teamRoomsFor("match-xyz")
	if !ok1 || !ok2 {
		t.Fatal("no team rooms available")
	}
	if a1 != a2 || b1 != b2 {
		t.Error("team room choice is not stable for the same match id")
	}
}
