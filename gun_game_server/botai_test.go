package main

import (
	"math"
	"testing"
	"time"
)

// تستِ رفتارِ واقعیِ بات: آیا از پشتِ دیوار راهِ رسیدن به بازیکن را پیدا
// می‌کند؟
//
// این تست عمداً hub را مستقیم تیک می‌زند و به دیتابیس و وب‌سوکت کاری ندارد:
// چیزی که می‌خواهیم بسنجیم ناوبری است، نه شبکه.

// makeTestPlayer یک بازیکنِ آماده‌ی بازی، بدون نیاز به دیتابیس.
// AddBot عمداً استفاده نمی‌شود چون equippedFor به مونگو می‌خورد.
func makeTestPlayer(name string, x, y float64, team string, health int) *Player {
	p := &Player{
		Username:     name,
		X:            x,
		Y:            y,
		Team:         team,
		JoinedAt:     time.Now(),
		LastMoveTime: time.Now(),
	}
	applyLoadout(p, "skin_default", "ak47", 1)
	p.Health = health
	return p
}

func newBotHub(t *testing.T) *Hub {
	t.Helper()
	if arena == nil {
		if err := LoadArena(); err != nil {
			t.Fatalf("LoadArena: %v", err)
		}
	}
	return NewHub()
}

// دورترین جفتِ اسپاون که دیوار بینشان است — یعنی بات مجبور است دور بزند
// و از در رد شود، نه اینکه مستقیم برود.
func blockedSpawnPair(t *testing.T) (bot [2]float64, human [2]float64) {
	t.Helper()
	best := -1.0
	found := false
	for _, a := range arena.Spawns {
		for _, b := range arena.Spawns {
			if a == b {
				continue
			}
			if arena.HasLineOfSight(a[0], a[1], b[0], b[1]) {
				continue // خطِ دید باز است؛ این جفت ناوبری را تست نمی‌کند
			}
			d := math.Hypot(b[0]-a[0], b[1]-a[1])
			if d > best {
				best, bot, human, found = d, a, b, true
			}
		}
	}
	if !found {
		t.Skip("no spawn pair separated by a wall on this map")
	}
	return bot, human
}

// مهم‌ترین تست: بات از پشتِ دیوار به بازیکن می‌رسد و از دیوار رد نمی‌شود.
//
// به بات یک «رد» داده می‌شود (مثل وقتی صدای شلیک را می‌شنود)، نه علمِ غیب:
// از وقتی ادراک اضافه شد، باتی که نه چیزی دیده و نه شنیده اصلاً دنبالِ کسی
// راه نمی‌افتد — می‌گردد. چیزی که اینجا سنجیده می‌شود ناوبری است: وقتی
// مقصدی دارد، آیا از درها ردش می‌کند یا در دیوار گیر می‌کند.
func TestBotNavigatesWallsToReachThePlayer(t *testing.T) {
	h := newBotHub(t)
	botAt, humanAt := blockedSpawnPair(t)

	// بازیکن جانِ خیلی زیاد دارد تا وسطِ تست نمیرد و تمرکز روی ناوبری بماند
	human := makeTestPlayer("Human", humanAt[0], humanAt[1], "1", 1000000)
	h.players["Human"] = human

	bot := makeTestPlayer("Bot", botAt[0], botAt[1], "0", 500)
	h.players["Bot"] = bot
	br := &BotRuntime{
		Username: "Bot", Skill: BotSkillHard,
		prof: profileFor(BotSkillHard), strafeDir: 1,
	}
	h.bots["Bot"] = br

	start := distance(bot.X, bot.Y, human.X, human.Y)
	if arena.HasLineOfSight(bot.X, bot.Y, human.X, human.Y) {
		t.Fatalf("test setup is wrong: the pair is not wall-separated")
	}
	t.Logf("bot starts %.0f away at (%.0f,%.0f), player at (%.0f,%.0f), no line of sight",
		start, bot.X, bot.Y, human.X, human.Y)

	const dt = 1.0 / botTickRate
	closest := start
	engage := statsOf(bot).BombRange * 0.55 * profileFor(BotSkillHard).EngageMul
	if engage < 180 {
		engage = 180
	}

	reachedAt := -1.0
	for i := 0; i < botTickRate*25; i++ { // تا ۲۵ ثانیه فرصت
		// ردِ تازه را زنده نگه می‌داریم: شبیه‌سازیِ بازیکنی که مدام شلیک
		// می‌کند و بات صدایش را دنبال می‌کند
		if br.memory <= 0.5 {
			br.noteSighting(human.X, human.Y)
		}
		h.stepBots(dt)

		// هیچ لحظه‌ای نباید داخلِ دیوار باشد
		if arena.CircleBlocked(bot.X, bot.Y, playerRadius) {
			t.Fatalf("tick %d: bot walked into a wall at (%.0f,%.0f)", i, bot.X, bot.Y)
		}
		d := distance(bot.X, bot.Y, human.X, human.Y)
		if d < closest {
			closest = d
		}
		if d <= engage && arena.HasLineOfSight(bot.X, bot.Y, human.X, human.Y) {
			reachedAt = float64(i) * dt
			break
		}
	}

	if reachedAt < 0 {
		t.Fatalf("bot never reached the player: started %.0f away, got no closer than %.0f "+
			"(engage range %.0f) — pathfinding through the doors is not working",
			start, closest, engage)
	}
	t.Logf("bot reached the player in %.1fs (closed %.0f units through doorways)",
		reachedAt, start-closest)
}

// بات نباید به هم‌تیمی‌اش شلیک کند یا دنبالش بیفتد
func TestBotIgnoresItsOwnTeam(t *testing.T) {
	h := newBotHub(t)
	if len(arena.Spawns) < 2 {
		t.Skip("need 2 spawns")
	}
	mate := makeTestPlayer("Mate", arena.Spawns[0][0], arena.Spawns[0][1], "0", 500)
	h.players["Mate"] = mate

	bot := makeTestPlayer("Bot", arena.Spawns[1][0], arena.Spawns[1][1], "0", 500)
	h.players["Bot"] = bot
	h.bots["Bot"] = &BotRuntime{Username: "Bot", Skill: BotSkillHard,
		prof: profileFor(BotSkillHard), strafeDir: 1}

	if got := h.pickTarget(bot); got != nil {
		t.Fatalf("bot targeted its own teammate %q", got.Username)
	}

	// حریف که اضافه شود، باید همان را انتخاب کند
	foe := makeTestPlayer("Foe", arena.Spawns[0][0], arena.Spawns[0][1], "1", 500)
	h.players["Foe"] = foe
	got := h.pickTarget(bot)
	if got == nil || got.Username != "Foe" {
		t.Fatalf("bot should target the enemy, picked %v", got)
	}
}

// وقتی همه‌ی آدم‌ها رفتند، بات‌ها هم باید بروند — نه اینکه سرور تا ابد
// مسابقه‌ی خالی را شبیه‌سازی کند
func TestBotsLeaveWhenNoHumansRemain(t *testing.T) {
	h := newBotHub(t)
	bot := makeTestPlayer("Bot", arena.Spawns[0][0], arena.Spawns[0][1], "0", 500)
	h.players["Bot"] = bot
	h.bots["Bot"] = &BotRuntime{Username: "Bot", Skill: BotSkillEasy,
		prof: profileFor(BotSkillEasy), strafeDir: 1}

	h.stepBots(1.0 / botTickRate)

	if len(h.bots) != 0 || len(h.players) != 0 {
		t.Fatalf("bots stayed with no humans: bots=%d players=%d", len(h.bots), len(h.players))
	}
}

// بات نباید داخلِ دیوار respawn شود
func TestBotRespawnsSomewhereValid(t *testing.T) {
	h := newBotHub(t)
	human := makeTestPlayer("Human", arena.Spawns[0][0], arena.Spawns[0][1], "1", 1000)
	h.players["Human"] = human

	bot := makeTestPlayer("Bot", arena.Spawns[1][0], arena.Spawns[1][1], "0", 500)
	h.players["Bot"] = bot
	rt := &BotRuntime{Username: "Bot", Skill: BotSkillMedium,
		prof: profileFor(BotSkillMedium), strafeDir: 1}
	h.bots["Bot"] = rt

	for i := 0; i < 40; i++ {
		bot.Health = 0
		rt.deadFor = 99 // مجبورش کن همین تیک برگردد
		h.stepBots(1.0 / botTickRate)
		if bot.Health <= 0 {
			t.Fatalf("bot did not respawn (health %d)", bot.Health)
		}
		if arena.CircleBlocked(bot.X, bot.Y, playerRadius) {
			t.Fatalf("bot respawned inside a wall at (%.0f,%.0f)", bot.X, bot.Y)
		}
	}
}
