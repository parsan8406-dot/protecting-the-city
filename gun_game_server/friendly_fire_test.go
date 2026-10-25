package main

import (
	"testing"
	"time"
)

// آتشِ خودی ممنوع است: نه گلوله به هم‌تیمی می‌خورد، نه بمب.
//
// این قانون فقط سمتِ سرور معنی دارد — کلاینت هرچه بفرستد، تصمیمِ نهایی
// این‌جاست. پس تست هم مستقیم روی همین لایه است.

func ffPlayer(h *Hub, name, team, matchID string, x, y float64) *Player {
	p := &Player{
		Username: name, Health: 100, X: x, Y: y,
		Team: team, MatchID: matchID,
		InvulnerableUntil: time.Now().Add(-time.Hour),
		LastMoveTime:      time.Now(),
	}
	applyLoadout(p, "skin_default", "ak47", 1)
	h.players[name] = p
	return p
}

func TestBulletsCannotHitATeammate(t *testing.T) {
	mustArena(t)
	h := NewHub()
	shooter := ffPlayer(h, "me", "0", "m1", 1000, 560)
	mate := ffPlayer(h, "mate", "0", "m1", 1040, 560)
	foe := ffPlayer(h, "foe", "1", "m1", 1080, 560)

	if h.validateHit(shooter, "mate") {
		t.Error("a teammate was a valid target — friendly fire is not blocked")
	}
	if !h.validateHit(shooter, "foe") {
		t.Error("an enemy at the same distance was rejected; the block is too broad")
	}
	_ = mate
	_ = foe
}

// بمب هم نباید هم‌تیمی را بزند
func TestBombDoesNotHurtTeammates(t *testing.T) {
	mustArena(t)
	h := NewHub()
	thrower := ffPlayer(h, "me", "0", "m1", 1000, 560)
	mate := ffPlayer(h, "mate", "0", "m1", 1010, 560)
	foe := ffPlayer(h, "foe", "1", "m1", 1010, 570)

	h.applyBombDamageInternal("m1", "me", 1010, 560, 200, 50)

	if mate.Health != 100 {
		t.Errorf("teammate took %d bomb damage", 100-mate.Health)
	}
	if foe.Health == 100 {
		t.Error("enemy inside the blast took no damage; the bomb hit nobody")
	}
	if thrower.Health != 100 {
		t.Errorf("thrower damaged himself for %d", 100-thrower.Health)
	}
}

// بازیکنِ مسابقه‌ی دیگر نه دیده می‌شود نه زده می‌شود — همان باگی که کاربر
// گزارش داد: اکانتی که اصلاً سرچ نکرده بود در زمین ظاهر می‌شد.
func TestPlayersInAnotherMatchAreUnreachable(t *testing.T) {
	mustArena(t)
	h := NewHub()
	mine := ffPlayer(h, "me", "0", "m1", 1000, 560)
	stranger := ffPlayer(h, "stranger", "1", "m2", 1010, 560)

	if h.validateHit(mine, "stranger") {
		t.Error("a player from another match was a valid target")
	}

	// بمب هم نباید از مرزِ مسابقه رد شود
	h.applyBombDamageInternal("m1", "me", 1010, 560, 300, 50)
	if stranger.Health != 100 {
		t.Errorf("a bomb in match m1 damaged a player in m2 for %d", 100-stranger.Health)
	}
}

// در تمرینِ بی‌تیم (Team خالی) همه حریف‌اند، وگرنه بازیِ تک‌نفره می‌شکند
func TestNoTeamMeansEveryoneIsFairGame(t *testing.T) {
	mustArena(t)
	h := NewHub()
	a := ffPlayer(h, "a", "", "", 1000, 560)
	ffPlayer(h, "b", "", "", 1040, 560)

	if !h.validateHit(a, "b") {
		t.Error("in a team-less practice match players should still be able to hit each other")
	}
}
