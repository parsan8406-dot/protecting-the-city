package main

import "testing"

// مهم‌ترین تستِ تعادل: درون یک رده هیچ‌کس بودجه‌ی بیشتری ندارد، وگرنه بین
// دو اسکینِ هم‌قیمت یکی آشکارا بهتر می‌شود.
func TestSameRaritySharesSamePipBudget(t *testing.T) {
	if len(characterPips) == 0 {
		t.Fatal("جدول تراز خالی است")
	}
	for id, p := range characterPips {
		rarity, ok := characterRarity[id]
		if !ok {
			t.Errorf("%s: نایابی‌اش تعریف نشده", id)
			continue
		}
		want, ok := pipBudget[rarity]
		if !ok {
			t.Errorf("%s: بودجه‌ی رده‌ی %q تعریف نشده", id, rarity)
			continue
		}
		if got := p.Sum(); got != want {
			t.Errorf("%s (%s): مجموع امتیاز %d است، باید %d باشد", id, rarity, got, want)
		}
	}
}

// هر ویژگی باید در دامنه‌ی نایابیِ خودش بماند: افسانه‌ای تخصصی‌تر است،
// نه این‌که همه‌ی ویژگی‌هایش بالاتر باشد.
func TestPipsRespectRarityRange(t *testing.T) {
	for id, p := range characterPips {
		rarity := characterRarity[id]
		rng, ok := rarityPipRange[rarity]
		if !ok {
			t.Errorf("%s: نایابی ناشناخته %q", id, rarity)
			continue
		}
		vals := map[string]int{
			"vitality": p.Vitality, "speed": p.Speed, "firepower": p.Firepower,
			"bomb_reach": p.BombReach, "bomb_power": p.BombPower,
		}
		for name, v := range vals {
			if v < rng[0] || v > rng[1] {
				t.Errorf("%s (%s): %s=%d خارج از دامنه‌ی %v است", id, rarity, name, v, rng)
			}
		}
	}
}

// برتریِ رده‌های بالاتر باید «خیلی کم» بماند. اگر روزی کسی ضریب را زیاد کند
// این تست جلویش را می‌گیرد.
func TestRarityAdvantageStaysSmall(t *testing.T) {
	const maxAdvantage = 1.08 // حداکثر ۸٪
	base := rarityPowerBonus["rare"]
	for rarity, bonus := range rarityPowerBonus {
		if bonus < base {
			t.Errorf("رده‌ی %s ضریبش از rare کمتر است (%.2f)", rarity, bonus)
		}
		if bonus > maxAdvantage {
			t.Errorf("رده‌ی %s برتری %.0f٪ دارد — بیش از حدِ مجاز است", rarity, (bonus-1)*100)
		}
	}
}

// سرعت و برد نباید با نایابی بهتر شوند — این دو توی شوتر بیش از همه به
// چشم می‌آیند و اگر با پول بهتر شوند بازی ناعادلانه حس می‌شود.
func TestSpeedAndRangeIgnoreRarityBonus(t *testing.T) {
	pips := CharPips{3, 3, 3, 3, 3}
	rare := statsFromPips(pips, "rare")
	legend := statsFromPips(pips, "legend")

	if rare.Speed != legend.Speed {
		t.Errorf("سرعت نباید با نایابی فرق کند: rare=%.0f legend=%.0f", rare.Speed, legend.Speed)
	}
	if rare.BombRange != legend.BombRange {
		t.Errorf("برد بمب نباید با نایابی فرق کند: rare=%.0f legend=%.0f", rare.BombRange, legend.BombRange)
	}
	if rare.BombRadius != legend.BombRadius {
		t.Errorf("شعاع بمب نباید با نایابی فرق کند: rare=%.0f legend=%.0f", rare.BombRadius, legend.BombRadius)
	}
	// ولی قدرت باید کمی بالاتر باشد
	if legend.Health <= rare.Health {
		t.Error("لجند باید کمی سلامت بیشتری داشته باشد")
	}
}

// عددهای نهایی باید در محدوده‌ی معقولی بمانند تا هیچ کاراکتری غیرقابل‌کشتن
// یا بی‌مصرف نشود.
func TestResolvedStatsStayInSaneBounds(t *testing.T) {
	toughest := 0
	for other := range characterPips {
		if h := CharacterStats(other).Health; h > toughest {
			toughest = h
		}
	}

	for id := range characterPips {
		st := CharacterStats(id)
		// بازه ×۱.۲۵ شد وقتی جان بالا رفت تا دوئل ~۲ ثانیه طول بکشد
		if st.Health < 112 || st.Health > 175 {
			t.Errorf("%s: سلامت %d از بازه‌ی معقول بیرون است", id, st.Health)
		}
		if st.Speed < 180 || st.Speed > 220 {
			t.Errorf("%s: سرعت %.0f از بازه‌ی معقول بیرون است", id, st.Speed)
		}
		// سقف سرعتِ سرور نباید رد شود وگرنه حرکتِ قانونی به‌عنوان تقلب
		// تشخیص داده و اصلاح می‌شود.
		if st.Speed >= maxMoveSpeed {
			t.Errorf("%s: سرعت %.0f از سقف سرور %.0f رد شده", id, st.Speed, maxMoveSpeed)
		}
		if st.Damage < 18 || st.Damage > 32 {
			t.Errorf("%s: خسارت %d از بازه‌ی معقول بیرون است", id, st.Damage)
		}
		// کشتنِ سرسخت‌ترین حریف باید بین ۵ تا ۹ تیر بماند
		shots := (toughest + st.Damage - 1) / st.Damage
		if shots < 5 || shots > 9 {
			t.Errorf("%s: برای کشتن سرسخت‌ترین حریف %d تیر لازم است (باید ۵ تا ۹ باشد)", id, shots)
		}
	}
}

// کاراکتر ناشناس نباید سرور را بترکاند و باید مقدارِ متعادل بگیرد.
func TestUnknownCharacterFallsBackToBalanced(t *testing.T) {
	st := CharacterStats("skin_does_not_exist")
	if st.Pips.Sum() != totalPips {
		t.Errorf("کاراکتر ناشناس مجموع %d گرفت، باید %d باشد", st.Pips.Sum(), totalPips)
	}
	if st.Health != CharacterStats("skin_default").Health {
		t.Error("کاراکتر ناشناس باید مثل پیش‌فرض متعادل باشد")
	}
}

// هر کاراکترِ کاتالوگ باید در جدول تراز باشد و برعکس.
func TestRarityTableCoversEveryCharacter(t *testing.T) {
	for id := range characterPips {
		if _, ok := characterRarity[id]; !ok {
			t.Errorf("%s در جدول تراز هست ولی نایابی ندارد", id)
		}
	}
	for id := range characterRarity {
		if _, ok := characterPips[id]; !ok {
			t.Errorf("%s نایابی دارد ولی امتیازهایش تعریف نشده", id)
		}
	}
}

// نمایشِ فروشگاه نباید هیچ‌وقت از سقفِ نوارش (max_level×۱۰) رد شود، وگرنه
// همان باگِ «۱۳۶/۱۰۰» که این تست از رویش ساخته شده دوباره برمی‌گردد.
func TestShopRatingsNeverExceedTheirBar(t *testing.T) {
	for id := range characterPips {
		rarity := characterRarity[id]
		maxLv := maxLevelFor[rarity]
		cap := maxLv * 10
		for key, v := range shopCharacterRatings(id) {
			if v > cap {
				t.Errorf("%s.%s = %d رد شده از سقفِ نوار %d (رده %s)", id, key, v, cap, rarity)
			}
			if v < 1 {
				t.Errorf("%s.%s = %d باید مثبت باشد", id, key, v)
			}
		}
	}
}

// بهترین ویژگیِ یک rare نباید از ضعیف‌ترین ویژگیِ یک legend عقب بیفتد —
// همان «فاصله‌ی کم» که خواسته شد.
func TestShopRatingGapStaysSmallAcrossRarities(t *testing.T) {
	worstLegend := shopRating(1, "legend")
	bestRare := shopRating(5, "rare")
	if bestRare < worstLegend {
		t.Errorf("بهترینِ rare (%d) از ضعیف‌ترینِ legend (%d) عقب است — فاصله زیاد شده",
			bestRare, worstLegend)
	}
}

// رده‌ی بالاتر باید میانگینِ بالاتری داشته باشد (سیستم باید همچنان معنی‌دار
// باشد)، ولی رشدش معتدل بماند.
func TestShopRatingRisesModeratelyWithRarity(t *testing.T) {
	mid := 3
	rare, epic, legend := shopRating(mid, "rare"), shopRating(mid, "epic"), shopRating(mid, "legend")
	if !(rare < epic && epic < legend) {
		t.Errorf("رده‌ها باید صعودی باشند: rare=%d epic=%d legend=%d", rare, epic, legend)
	}
	if legend-rare > 30 {
		t.Errorf("فاصله‌ی legend تا rare خیلی زیاد است: %d امتیاز", legend-rare)
	}
}

// چهار ویژگیِ تازه (fire_cooldown, miss_chance, heal_amount, heal_cooldown)
// هم باید در بازه‌ی معتدل بمانند — دقیقاً همان چیزی که در فروشگاه دیده
// می‌شود باید در بازی هم رخ دهد، نه بیشتر.
func TestNewGameplayHooksStayModerate(t *testing.T) {
	for id := range characterPips {
		st := CharacterStats(id)
		if st.FireCooldown < 0.28 || st.FireCooldown > 0.45 {
			t.Errorf("%s: fire_cooldown=%.3f خارج از بازه‌ی معقول است", id, st.FireCooldown)
		}
		if st.MissChance < 0.0 || st.MissChance > 0.12 {
			t.Errorf("%s: miss_chance=%.3f خارج از بازه‌ی معقول است (نباید خیلی تنبیهی باشد)", id, st.MissChance)
		}
		if st.HealAmount < 22 || st.HealAmount > 42 {
			t.Errorf("%s: heal_amount=%d خارج از بازه‌ی معقول است", id, st.HealAmount)
		}
		if st.HealCooldown < 9.0 || st.HealCooldown > 15.0 {
			t.Errorf("%s: heal_cooldown=%.1f خارج از بازه‌ی معقول است", id, st.HealCooldown)
		}
	}
}

// هیچ ترکیبِ کاراکتر/سلاحی در سطحِ ۱ نباید ضعیف‌ترین کاراکترِ سطحِ ۱ را با یک
// تیر بیندازد — یک‌تیر یعنی هیچ‌کدام از سپر، درمان و جابه‌جایی معنی ندارد.
func TestNoLevelOneLoadoutOneShotsAnyone(t *testing.T) {
	weakest := 1 << 30
	for id := range characterPips {
		if h := CharacterStats(id).Health; h < weakest {
			weakest = h
		}
	}
	for cid := range characterPips {
		for wid := range weaponPips {
			p := &Player{}
			applyLoadout(p, cid, wid, 1)
			if p.Stats.Damage >= weakest {
				t.Errorf("%s + %s: %d damage one-shots %d HP", cid, wid, p.Stats.Damage, weakest)
			}
		}
	}
}
