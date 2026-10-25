package main

import "testing"

// چهار حالت باید کامل و بی‌تکرار تعریف شده باشند
func TestDefaultGameModesAreWellFormed(t *testing.T) {
	modes := defaultGameModes()
	if len(modes) != 4 {
		t.Fatalf("expected 4 game modes, got %d", len(modes))
	}

	seenID := map[string]bool{}
	seenOrder := map[int]bool{}
	for _, m := range modes {
		if m.ModeID == "" || m.Name == "" || m.Subtitle == "" {
			t.Errorf("mode %+v has an empty identity field", m)
		}
		if seenID[m.ModeID] {
			t.Errorf("duplicate mode_id %q", m.ModeID)
		}
		seenID[m.ModeID] = true

		if seenOrder[m.SortOrder] {
			t.Errorf("duplicate sort_order %d on %q", m.SortOrder, m.ModeID)
		}
		seenOrder[m.SortOrder] = true

		// یک نفر (تک‌به‌تک) تا چهار نفر. کمتر از یک یعنی مسابقه‌ای تشکیل نمی‌شود.
		if m.TeamSize < 1 || m.TeamSize > 4 {
			t.Errorf("%s: team size %d is outside 1..4", m.ModeID, m.TeamSize)
		}
		if !m.IsActive {
			t.Errorf("%s: seeded inactive, it would never appear in the menu", m.ModeID)
		}
	}

	// تیم‌بندی‌هایی که خواسته شده.
	// «عملیات انتقام» تک‌به‌تک است: دو بازیکن روبه‌روی هم، نه دو تیمِ دو نفره.
	want := map[string]int{"strike": 4, "revenge": 1, "banish": 3, "citypoint": 3}
	for id, size := range want {
		found := false
		for _, m := range modes {
			if m.ModeID == id {
				found = true
				if m.TeamSize != size {
					t.Errorf("%s: team size %d, want %d", id, m.TeamSize, size)
				}
			}
		}
		if !found {
			t.Errorf("mode %q is missing", id)
		}
	}
}

// اقتصاد باید معنی‌دار باشد: برد همیشه سود، باخت همیشه ضررِ کاپ
func TestGameModeEconomyIsSane(t *testing.T) {
	for _, m := range defaultGameModes() {
		if m.WinTrophies <= 0 {
			t.Errorf("%s: winning must award trophies, got %d", m.ModeID, m.WinTrophies)
		}
		if m.LoseTrophies <= 0 {
			t.Errorf("%s: losing must cost trophies, got %d", m.ModeID, m.LoseTrophies)
		}
		// جریمه نباید از پاداش بیشتر باشد، وگرنه بازی کردن ضرر خالص است
		if m.LoseTrophies >= m.WinTrophies {
			t.Errorf("%s: losing costs %d but winning gives only %d — playing is a net loss",
				m.ModeID, m.LoseTrophies, m.WinTrophies)
		}
		if m.WinCoins <= 0 || m.WinXP <= 0 {
			t.Errorf("%s: winning should pay coins and xp", m.ModeID)
		}
		// حتی باخت هم باید کمی تجربه بدهد
		if m.LoseXP <= 0 {
			t.Errorf("%s: losing should still grant some xp", m.ModeID)
		}
		if m.MinTrophies < 0 {
			t.Errorf("%s: negative trophy gate", m.ModeID)
		}
	}
}

// تیمِ کوچک‌تر = ریسک بیشتر = پاداش بیشتر. اگر این به‌هم بخورد، انتخابِ
// حالت بی‌معنی می‌شود چون یکی همیشه بهترین است.
func TestSmallerTeamsPayMore(t *testing.T) {
	byID := map[string]GameModeDef{}
	for _, m := range defaultGameModes() {
		byID[m.ModeID] = m
	}
	if byID["revenge"].WinTrophies <= byID["banish"].WinTrophies {
		t.Errorf("2v2 (%d) should pay more than 3v3 (%d)",
			byID["revenge"].WinTrophies, byID["banish"].WinTrophies)
	}
	if byID["banish"].WinTrophies <= byID["strike"].WinTrophies {
		t.Errorf("3v3 (%d) should pay more than 4v4 (%d)",
			byID["banish"].WinTrophies, byID["strike"].WinTrophies)
	}
	// حالتِ ورودی نباید قفل باشد، وگرنه بازیکنِ تازه هیچ‌جا نمی‌تواند برود
	if byID["strike"].MinTrophies != 0 {
		t.Errorf("the entry mode must be unlocked, got gate %d", byID["strike"].MinTrophies)
	}
}
