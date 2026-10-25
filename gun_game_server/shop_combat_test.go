package main

import (
	"context"
	"testing"

	"go.mongodb.org/mongo-driver/bson"
)

// عددهای واقعیِ بازی باید در سندِ فروشگاه هم بنشینند.
//
// ستاره‌های فروشگاه (۵ ویژگیِ نمایشی) تصویرِ درشتِ ماجرا هستند؛ این تست
// مطمئن می‌شود عددِ دقیقِ همان چیزی که سرور موقعِ بازی اعمال می‌کند —
// خسارت، فاصله‌ی شلیک، خشاب، برد — کنارشان در دیتابیس ثبت شده و با
// منبعِ حقیقت یکی است.
//
// اگر مونگو بالا نباشد رد می‌شود.
func TestShopCarriesTheRealCombatNumbers(t *testing.T) {
	ctx := withDB(t)

	if err := SeedCharacterStats(ctx); err != nil {
		t.Fatalf("seed characters: %v", err)
	}
	if err := SeedWeaponStats(ctx); err != nil {
		t.Fatalf("seed weapons: %v", err)
	}

	// --- سلاح ---
	for _, wid := range []string{"awm", "fnmag", "ak47"} {
		var doc struct {
			Combat struct {
				Damage         int     `bson:"damage"`
				FireCooldown   float64 `bson:"fire_cooldown"`
				ShotsPerSecond float64 `bson:"shots_per_second"`
				MagSize        int     `bson:"mag_size"`
				MaxRange       float64 `bson:"max_range"`
				RefCharacter   string  `bson:"reference_character"`
			} `bson:"combat"`
		}
		err := col(ColShopItems).FindOne(ctx, bson.M{"item_id": wid}).Decode(&doc)
		if err != nil {
			t.Skipf("سلاح %s در کاتالوگِ این دیتابیس نیست: %v", wid, err)
		}

		// همان چیزی که بازی اعمال می‌کند
		p := &Player{}
		applyLoadout(p, CombatReferenceCharacter, wid, 1)

		if doc.Combat.RefCharacter != CombatReferenceCharacter {
			t.Errorf("%s: کاراکترِ مرجع %q است", wid, doc.Combat.RefCharacter)
		}
		if doc.Combat.Damage != p.Stats.Damage {
			t.Errorf("%s: خسارتِ فروشگاه %d ولی بازی %d",
				wid, doc.Combat.Damage, p.Stats.Damage)
		}
		if diff := doc.Combat.FireCooldown - p.Stats.FireCooldown; diff > 0.01 || diff < -0.01 {
			t.Errorf("%s: فاصله‌ی شلیکِ فروشگاه %.3f ولی بازی %.3f",
				wid, doc.Combat.FireCooldown, p.Stats.FireCooldown)
		}
		if doc.Combat.MagSize != p.Stats.MagSize {
			t.Errorf("%s: خشابِ فروشگاه %d ولی بازی %d",
				wid, doc.Combat.MagSize, p.Stats.MagSize)
		}
		if doc.Combat.MaxRange != round2(p.Stats.MaxRange) {
			t.Errorf("%s: بردِ فروشگاه %.0f ولی بازی %.0f",
				wid, doc.Combat.MaxRange, p.Stats.MaxRange)
		}
		if doc.Combat.ShotsPerSecond <= 0 {
			t.Errorf("%s: تیر در ثانیه ثبت نشده", wid)
		}
	}

	// --- کاراکتر ---
	var ch struct {
		Combat struct {
			Health       int     `bson:"health"`
			Damage       int     `bson:"damage"`
			MaxHealth    int     `bson:"max_health"`
			MaxLevel     int     `bson:"max_level"`
			FireCooldown float64 `bson:"fire_cooldown"`
		} `bson:"combat"`
	}
	err := col(ColShopItems).FindOne(ctx, bson.M{"item_id": "skin_default"}).Decode(&ch)
	if err != nil {
		t.Skipf("کاراکترِ پیش‌فرض در کاتالوگ نیست: %v", err)
	}
	want := CharacterStatsAtLevel("skin_default", 1)
	if ch.Combat.Health != want.Health || ch.Combat.Damage != want.Damage {
		t.Errorf("کاراکتر: فروشگاه %d جان/%d خسارت، بازی %d/%d",
			ch.Combat.Health, ch.Combat.Damage, want.Health, want.Damage)
	}
	top := CharacterStatsAtLevel("skin_default", MaxLevelOf("skin_default"))
	if ch.Combat.MaxHealth != top.Health {
		t.Errorf("کاراکتر: جانِ سقفِ سطح در فروشگاه %d، در بازی %d",
			ch.Combat.MaxHealth, top.Health)
	}
	if ch.Combat.MaxLevel != MaxLevelOf("skin_default") {
		t.Errorf("کاراکتر: سقفِ سطح %d ثبت شده", ch.Combat.MaxLevel)
	}

	_ = context.Background
}
