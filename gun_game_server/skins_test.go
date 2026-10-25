package main

import "testing"

func TestSkinsComeOnlyFromBattlePass(t *testing.T) {
	for _, s := range SkinCatalog {
		reward := seasonPassPremiumReward(s.PassLevel)
		if reward.SkinID != s.SkinID {
			t.Errorf("premium level %d should grant %s, got %q", s.PassLevel, s.SkinID, reward.SkinID)
		}
		if free := seasonPassReward(s.PassLevel); free.SkinID != "" {
			t.Errorf("free track must not grant skins, level %d gave %q", s.PassLevel, free.SkinID)
		}
		if _, sold := characterPrices[s.SkinID]; sold {
			t.Errorf("skin %s must not have a shop price", s.SkinID)
		}
	}
	if !isSkinID("ak47_fire") || !isSkinID("skin_default_red") || isSkinID("ak47") {
		t.Fatal("skin ids not recognized")
	}
}

func TestActiveSkinFallsBackToDefault(t *testing.T) {
	p := &PlayerModel{EquippedSkins: map[string]string{"ak47": "ak47_fire", "skin_default": "skin_default_red"}}
	if got := activeSkin(p, "ak47"); got != "" {
		t.Errorf("unowned skin must show default look, got %q", got)
	}
	p.OwnedSkins = []string{"ak47_fire"}
	if got := activeSkin(p, "ak47"); got != "ak47_fire" {
		t.Errorf("owned+equipped skin should be active, got %q", got)
	}
	if got := activeSkin(p, "skin_default"); got != "" {
		t.Errorf("character skin not owned, got %q", got)
	}
	p.EquippedSkins["m82"] = "ak47_fire"
	if got := activeSkin(p, "m82"); got != "" {
		t.Errorf("skin on wrong base must be ignored, got %q", got)
	}
}

func TestUpgradeCostAndLevels(t *testing.T) {
	p := &PlayerModel{ItemLevels: map[string]int{"skin_default": 3}}
	if lv := characterLevel(p, "skin_default"); lv != 3 {
		t.Fatalf("level = %d", lv)
	}
	if lv := characterLevel(&PlayerModel{}, "skin_fire"); lv != 1 {
		t.Fatalf("missing level should be 1, got %d", lv)
	}
	maxLv := MaxLevelOf("skin_default")
	if c := upgradeCost("skin_default", maxLv); c != 0 {
		t.Errorf("max level must have no cost, got %d", c)
	}
	if upgradeCost("skin_default", 2) <= upgradeCost("skin_default", 1) {
		t.Error("each level should cost more than the previous")
	}
	lo := CharacterStatsAtLevel("skin_default", 1)
	hi := CharacterStatsAtLevel("skin_default", maxLv)
	if hi.Health <= lo.Health {
		t.Errorf("upgrading should raise health: %d -> %d", lo.Health, hi.Health)
	}
}
