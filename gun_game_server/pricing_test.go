package main

import "testing"

// قیمت باید فقط از رده بیاید. اگر روزی کسی برای یک آیتم قیمت دستی بگذارد،
// این تست‌ها نشان می‌دهند کاتالوگ دوباره ناهماهنگ شده.

// هر رده باید قیمت داشته باشد، وگرنه SeedCatalogPrices از رویش رد می‌شود
// و آن آیتم‌ها با قیمتِ قدیمیِ دلبخواهی می‌مانند.
func TestEveryRarityHasAPrice(t *testing.T) {
	for rarity := range rarityPowerBonus {
		if _, ok := characterPrices[rarity]; !ok {
			t.Errorf("کاراکترِ رده‌ی %s قیمت ندارد", rarity)
		}
		if _, ok := weaponPrices[rarity]; !ok {
			t.Errorf("سلاحِ رده‌ی %s قیمت ندارد", rarity)
		}
	}
}

// قیمت باید با رده بالا برود. یک epic نباید از یک legend گران‌تر باشد.
func TestPricesRiseWithRarity(t *testing.T) {
	// نرخ طراحی: هر ۱۰۰ سکه ≈ ۱ جم. برای مقایسه همه را به «سکه» تبدیل می‌کنیم.
	toCoins := func(p catalogPrice) int {
		if p.CostType == "gems" {
			return p.Price * 100
		}
		return p.Price
	}
	order := []string{"rare", "epic", "legend"}

	for _, table := range []struct {
		name  string
		table map[string]catalogPrice
	}{
		{"کاراکتر", characterPrices},
		{"سلاح", weaponPrices},
	} {
		prev := 0
		for _, rarity := range order {
			p, ok := table.table[rarity]
			if !ok {
				continue
			}
			got := toCoins(p)
			if got <= prev {
				t.Errorf("%s: رده‌ی %s (%d سکه) از رده‌ی قبلی (%d) گران‌تر نیست",
					table.name, rarity, got, prev)
			}
			prev = got
		}
	}
}

// سلاح باید از کاراکترِ هم‌رده ارزان‌تر باشد، چون بازیکن برای یک ست کامل
// به هر دو نیاز دارد.
func TestWeaponsCheaperThanCharacters(t *testing.T) {
	for rarity, wp := range weaponPrices {
		cp, ok := characterPrices[rarity]
		if !ok {
			continue
		}
		if wp.CostType != cp.CostType {
			continue // مقایسه‌ی سکه با جم معنی ندارد
		}
		if wp.Price >= cp.Price {
			t.Errorf("رده‌ی %s: سلاح (%d) باید از کاراکتر (%d) ارزان‌تر باشد",
				rarity, wp.Price, cp.Price)
		}
	}
}

// آیتم‌های شروع باید رایگان باشند — نه این‌که بازیکن برای چیزی که از اول
// دارد پول ببیند.
func TestStarterItemsAreFree(t *testing.T) {
	if !freeStarters[defaultCharacterID] {
		t.Errorf("کاراکتر پیش‌فرض (%s) باید جزو آیتم‌های رایگان باشد", defaultCharacterID)
	}
	if !freeStarters[defaultWeaponID] {
		t.Errorf("سلاح پیش‌فرض (%s) باید جزو آیتم‌های رایگان باشد", defaultWeaponID)
	}
}
