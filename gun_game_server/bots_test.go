package main

import (
	"encoding/json"
	"math/rand"
	"strings"
	"testing"
	"time"
)

// مهم‌ترین تستِ این فایل: هیچ‌جا نباید معلوم شود کدام حریف بات است.
//
// اگر روزی کسی `json:"-"` را بردارد یا فیلدِ unexported را export کند، همین
// تست می‌شکند — وگرنه نشتی بی‌صدا اتفاق می‌افتد و تا وقتی بازیکنی توی
// کنسولِ مرورگر نگاه نکند کسی نمی‌فهمد.
func TestBotIdentityNeverReachesTheClient(t *testing.T) {
	rng := rand.New(rand.NewSource(1))
	bot := makeBot(rng, "Ali77")
	if !bot.IsBot || bot.BotSkill == "" {
		t.Fatalf("makeBot did not mark the bot: IsBot=%v skill=%q", bot.IsBot, bot.BotSkill)
	}

	raw, err := json.Marshal(bot)
	if err != nil {
		t.Fatalf("marshal PlayerModel: %v", err)
	}
	for _, needle := range []string{"is_bot", "bot_skill", "IsBot", "BotSkill", "\"easy\"", "\"medium\"", "\"hard\""} {
		if strings.Contains(string(raw), needle) {
			t.Errorf("PlayerModel JSON leaks bot identity via %q:\n%s", needle, raw)
		}
	}

	// همان چک برای ورودیِ صف، که مستقیم داخل payloadِ لابی می‌رود
	q := QueuedPlayer{
		Username: "Ali77", PlayerID: "12345", Character: "skin_boy",
		Trophies: 300, Level: 7, RankID: "gold", RankName: "طلا",
		Team: 1, joinedAt: time.Now(), isBot: true, skill: BotSkillHard,
	}
	raw, err = json.Marshal(q)
	if err != nil {
		t.Fatalf("marshal QueuedPlayer: %v", err)
	}
	for _, needle := range []string{"isBot", "is_bot", "skill", "hard"} {
		if strings.Contains(string(raw), needle) {
			t.Errorf("QueuedPlayer JSON leaks bot identity via %q:\n%s", needle, raw)
		}
	}

	// و در PendingMatch که کلاینت کاملش را می‌گیرد
	m := PendingMatch{MatchID: "m1", ModeID: "strike", Players: []QueuedPlayer{q}}
	raw, err = json.Marshal(m)
	if err != nil {
		t.Fatalf("marshal PendingMatch: %v", err)
	}
	for _, needle := range []string{"isBot", "is_bot", "skill", "hard"} {
		if strings.Contains(string(raw), needle) {
			t.Errorf("PendingMatch JSON leaks bot identity via %q:\n%s", needle, raw)
		}
	}
}

// اسمِ بات نباید داد بزند که بات است
func TestBotNamesLookHuman(t *testing.T) {
	rng := rand.New(rand.NewSource(botSeed))
	taken := map[string]bool{}
	for i := 0; i < BotCount*3; i++ {
		name := makeBotName(rng, taken)
		lower := strings.ToLower(name)
		for _, bad := range []string{"bot", "ai", "cpu", "npc", "dummy", "fake"} {
			if strings.Contains(lower, bad) {
				t.Errorf("bot name %q contains the giveaway %q", name, bad)
			}
		}
		if name == "" {
			t.Fatal("empty bot name")
		}
	}
	if len(taken) < BotCount*3 {
		t.Errorf("names collide: wanted %d unique, got %d", BotCount*3, len(taken))
	}
}

// پروفایلِ بات باید با خودش بخواند: کاپِ بالا یعنی سطح و آمارِ بالا.
// یک بازیکن که پروفایلِ حریفش را باز می‌کند نباید عددِ بی‌ربط ببیند.
func TestBotProfilesAreCoherent(t *testing.T) {
	rng := rand.New(rand.NewSource(7))
	for i := 0; i < 200; i++ {
		b := makeBot(rng, "probe")
		if b.Level < 1 {
			t.Fatalf("level %d", b.Level)
		}
		if b.Trophies < 0 {
			t.Fatalf("trophies %d", b.Trophies)
		}
		if b.Stats.Wins+b.Stats.Losses != b.Stats.TotalMatches {
			t.Fatalf("wins+losses (%d+%d) != matches %d",
				b.Stats.Wins, b.Stats.Losses, b.Stats.TotalMatches)
		}
		if b.Stats.Wins < 0 || b.Stats.Losses < 0 {
			t.Fatalf("negative record: %+v", b.Stats)
		}
		if b.EquippedCharacter == "" || b.EquippedWeapon == "" {
			t.Fatalf("bot has no loadout: %q / %q", b.EquippedCharacter, b.EquippedWeapon)
		}
		// آیتمِ تجهیزشده باید واقعاً مالِ خودش باشد، وگرنه فروشگاه/پروفایل
		// یک آیتمِ نداشته را نشان می‌دهد
		if !contains(b.OwnedCharacters, b.EquippedCharacter) {
			t.Fatalf("equipped character %q not owned: %v", b.EquippedCharacter, b.OwnedCharacters)
		}
		if !contains(b.OwnedWeapons, b.EquippedWeapon) {
			t.Fatalf("equipped weapon %q not owned: %v", b.EquippedWeapon, b.OwnedWeapons)
		}
		// کاراکترِ تجهیزشده باید در کاتالوگِ واقعی باشد وگرنه کلاینت آرت ندارد
		if _, ok := characterRarity[b.EquippedCharacter]; !ok {
			t.Fatalf("equipped character %q is not in the shop catalog", b.EquippedCharacter)
		}
		rankID, _ := rankFromTrophies(b.Trophies)
		if b.Rank.TierID != rankID {
			t.Fatalf("rank %q does not match %d trophies (want %q)",
				b.Rank.TierID, b.Trophies, rankID)
		}
	}
}

func contains(list []string, want string) bool {
	for _, v := range list {
		if v == want {
			return true
		}
	}
	return false
}

// سه سطحِ مهارت باید واقعاً از هم فرق داشته باشند و به ترتیب سخت‌تر شوند
func TestSkillProfilesAreOrdered(t *testing.T) {
	easy := profileFor(BotSkillEasy)
	med := profileFor(BotSkillMedium)
	hard := profileFor(BotSkillHard)

	if !(easy.Reaction > med.Reaction && med.Reaction > hard.Reaction) {
		t.Errorf("reaction should shorten with skill: %.2f %.2f %.2f",
			easy.Reaction, med.Reaction, hard.Reaction)
	}
	if !(easy.AimJitter > med.AimJitter && med.AimJitter > hard.AimJitter) {
		t.Errorf("aim should tighten with skill: %.2f %.2f %.2f",
			easy.AimJitter, med.AimJitter, hard.AimJitter)
	}
	// سرعتِ چرخشِ پایه دیگر در پروفایل نیست — از خودِ کاراکتر می‌آید، مثل
	// بازیکنِ آدم (turnStep). چیزی که با مهارت فرق می‌کند سرعتِ قفل شدن
	// روی هدف است.
	if !(easy.AimTurnMul < med.AimTurnMul && med.AimTurnMul < hard.AimTurnMul) {
		t.Errorf("aim turn speed should rise with skill: %.2f %.2f %.2f",
			easy.AimTurnMul, med.AimTurnMul, hard.AimTurnMul)
	}
	if !(easy.ExtraMiss > med.ExtraMiss && med.ExtraMiss >= hard.ExtraMiss) {
		t.Errorf("extra miss should fall with skill: %.2f %.2f %.2f",
			easy.ExtraMiss, med.ExtraMiss, hard.ExtraMiss)
	}
	// هر سه سطح باید در قرعه‌کشی باشند، وگرنه «تصادفی بین سخت و متوسط و کم»
	// عملاً یک سطح می‌شود
	if len(botSkills) != 3 {
		t.Fatalf("expected 3 skill levels, got %d", len(botSkills))
	}
}

// جمعیت باید در همان بازه‌ای باشد که خواسته شده (۳۵ تا ۴۰)
func TestBotRosterSizeIsInRange(t *testing.T) {
	if BotCount < 35 || BotCount > 40 {
		t.Errorf("BotCount = %d, expected 35..40", BotCount)
	}
}

// ۱۵ ثانیه جستجوی آدمِ هم‌سطح، و سرِ ۲۰ ثانیه بات — همان که خواسته شد
func TestBackfillWindowIsTwentySeconds(t *testing.T) {
	if HumanSearchFor != 15*time.Second {
		t.Errorf("HumanSearchFor = %v, expected 15s", HumanSearchFor)
	}
	if BackfillAfter != 20*time.Second {
		t.Errorf("BackfillAfter = %v, expected 20s", BackfillAfter)
	}
	if TrophyWindow != 200 {
		t.Errorf("TrophyWindow = %d, expected 200", TrophyWindow)
	}
}

// وزنِ مهارتِ بات با کاپ: تازه‌کار باتِ سخت نمی‌بیند و کاپ‌بالا بیشتر سخت.
func TestBotSkillScalesWithTrophies(t *testing.T) {
	rng := rand.New(rand.NewSource(1))
	count := func(trophies int) map[string]int {
		c := map[string]int{}
		for i := 0; i < 2000; i++ {
			c[botSkillFor(trophies, rng)]++
		}
		return c
	}
	low, high := count(100), count(1500)
	if low[BotSkillHard] != 0 {
		t.Errorf("new players must never meet hard bots: %v", low)
	}
	if low[BotSkillEasy] < 1200 {
		t.Errorf("low trophies should be mostly easy: %v", low)
	}
	if high[BotSkillHard] < 800 || high[BotSkillEasy] > 400 {
		t.Errorf("high trophies should be mostly hard: %v", high)
	}
}

// باتِ آسان بدونِ تک‌تیرانداز و کاراکترِ افسانه‌ای؛ باتِ سخت دست نمی‌خورد.
func TestEasyBotsCarryNoSnipersOrLegends(t *testing.T) {
	c, w, lv, _, _ := gentleBotLoadout(BotSkillEasy, "skin_devil", "awm", 7, "s1", "s2")
	if characterRarity["skin_devil"] == "legend" && (c != defaultCharacterID || lv != 1) {
		t.Errorf("easy bot kept a legend: %s lv%d", c, lv)
	}
	if w != defaultWeaponID {
		t.Errorf("easy bot kept a sniper: %s", w)
	}
	c, w, _, _, _ = gentleBotLoadout(BotSkillHard, "skin_devil", "awm", 7, "", "")
	if c != "skin_devil" || w != "awm" {
		t.Errorf("hard bot gear must not change: %s %s", c, w)
	}
}

// سه مسابقه‌ی اول: حریف‌های بات آسان، هم‌تیمی‌ها متوسط.
func TestNewbieMatchGetsGentleBots(t *testing.T) {
	m := &PendingMatch{Players: []QueuedPlayer{
		{Username: "me", Team: 0},
		{Username: "mate", Team: 0, isBot: true, skill: BotSkillHard},
		{Username: "foe1", Team: 1, isBot: true, skill: BotSkillHard},
		{Username: "foe2", Team: 1, isBot: true, skill: BotSkillMedium},
	}}
	gentleForNewbie(m, "me")
	want := map[string]string{"mate": BotSkillMedium, "foe1": BotSkillEasy, "foe2": BotSkillEasy}
	for _, p := range m.Players {
		if w, ok := want[p.Username]; ok && p.skill != w {
			t.Errorf("%s skill %s, want %s", p.Username, p.skill, w)
		}
	}
}
