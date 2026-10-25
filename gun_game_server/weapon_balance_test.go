package main

import (
	"math"
	"testing"
)

// همان اصلِ کاراکترها: درون یک رده هیچ سلاحی بودجه‌ی بیشتری ندارد.
func TestWeaponPipsShareSamePipBudget(t *testing.T) {
	if len(weaponPips) == 0 {
		t.Fatal("جدول تراز سلاح‌ها خالی است")
	}
	for id, p := range weaponPips {
		rarity, ok := weaponRarity[id]
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

// هر ویژگیِ سلاح هم باید در دامنه‌ی نایابیِ خودش بماند — همان جدولِ
// کاراکترها (rarityPipRange) دوباره‌استفاده می‌شود.
func TestWeaponPipsRespectRarityRange(t *testing.T) {
	for id, p := range weaponPips {
		rarity := weaponRarity[id]
		rng, ok := rarityPipRange[rarity]
		if !ok {
			t.Errorf("%s: نایابی ناشناخته %q", id, rarity)
			continue
		}
		vals := map[string]int{
			"power": p.Power, "accuracy": p.Accuracy, "range": p.Range,
			"fire_rate": p.FireRate, "control": p.Control,
		}
		for name, v := range vals {
			if v < rng[0] || v > rng[1] {
				t.Errorf("%s (%s): %s=%d خارج از دامنه‌ی %v است", id, rarity, name, v, rng)
			}
		}
	}
}

// نمایشِ فروشگاهیِ سلاح هم نباید از سقفِ نوارش رد شود.
func TestWeaponShopRatingsNeverExceedTheirBar(t *testing.T) {
	for id := range weaponPips {
		rarity := weaponRarity[id]
		cap := maxLevelFor[rarity] * 10
		for key, v := range shopWeaponRatings(id) {
			if v > cap {
				t.Errorf("%s.%s = %d رد شده از سقفِ نوار %d", id, key, v, cap)
			}
			if v < 1 {
				t.Errorf("%s.%s = %d باید مثبت باشد", id, key, v)
			}
		}
	}
}

// اثرِ سلاح باید «لایه‌ی نازک» بماند — ولی روی قدرت، نه روی ریتم.
//
// سرعتِ شلیک عمداً از این قاعده بیرون است: تیربار باید ثانیه‌ای ۱۰ تیر
// بریزد و تک‌تیرانداز ۲ تیر. چیزی که نباید جابه‌جا شود قدرتِ خالص است، و
// آن با خسارت-در-ثانیه سنجیده می‌شود: DamageMult ÷ FireRateMult (هرچه
// FireRateMult کمتر، شلیک تندتر، پس تقسیم می‌شود نه ضرب).
func TestWeaponModifiersStayModerate(t *testing.T) {
	const maxSwing = 0.16 // ۱۶٪ حاشیه‌ی خطا روی هدفِ ۱۵٪
	for id := range weaponPips {
		wm := WeaponStatsFor(id)
		if wm.MissMult < 1-maxSwing || wm.MissMult > 1+maxSwing {
			t.Errorf("%s: MissMult=%.2f خیلی از ۱٫۰ فاصله دارد", id, wm.MissMult)
		}
		dps := wm.DamageMult / wm.FireRateMult
		if dps < 0.82 || dps > 1.35 {
			t.Errorf("%s: خسارت-در-ثانیه‌ی سلاح ×%.2f است — لایه‌ی سلاح باید نازک بماند",
				id, dps)
		}
	}
}

// سلاحِ ناشناس نباید سرور را بترکاند و باید مقدارِ متعادل بگیرد.
func TestUnknownWeaponFallsBackToBalanced(t *testing.T) {
	wm := WeaponStatsFor("weapon_does_not_exist")
	if wm.Pips.Sum() != totalPips {
		t.Errorf("سلاح ناشناس مجموع %d گرفت، باید %d باشد", wm.Pips.Sum(), totalPips)
	}
	// خنثی بودن یعنی قدرتِ خالصِ خنثی. خودِ DamageMult خنثی نیست و نباید
	// باشد: با سرعتِ شلیکِ متوسط (pip ۳) گلوله‌ها ریزتر و پرتعدادترند.
	if dps := wm.DamageMult / wm.FireRateMult; dps < 0.95 || dps > 1.15 {
		t.Errorf("سلاح ناشناس باید قدرتِ تقریباً خنثی بدهد، گرفت ×%.2f", dps)
	}
}

// هر سلاحِ کاتالوگ باید در جدول تراز باشد و برعکس.
func TestWeaponRarityTableCoversEveryWeapon(t *testing.T) {
	for id := range weaponPips {
		if _, ok := weaponRarity[id]; !ok {
			t.Errorf("%s در جدول تراز هست ولی نایابی ندارد", id)
		}
	}
	for id := range weaponRarity {
		if _, ok := weaponPips[id]; !ok {
			t.Errorf("%s نایابی دارد ولی امتیازهایش تعریف نشده", id)
		}
	}
}

// عددهای نهاییِ ترکیبیِ (کاراکتر+سلاح) باید همچنان در بازه‌ی معقول بمانند.
//
// «معقول» بعد از بازکردنِ دامنه‌ی سرعتِ شلیک عوض شده: حالا عمداً یک سلاح
// ثانیه‌ای ۲ تیر می‌زند و یکی ۱۰ تیر. چیزی که نباید تکان بخورد
// خسارت-در-ثانیه است — تیربار باید رگبار باشد، نه سه برابر کشنده‌تر.
func TestCombinedCharacterWeaponStaysReasonable(t *testing.T) {
	for cid := range characterPips {
		cs := CharacterStats(cid)
		for wid := range weaponPips {
			wm := WeaponStatsFor(wid)
			dmg := float64(cs.Damage) * wm.DamageMult
			// خسارتِ هر گلوله با سرعتِ شلیک بالا و پایین می‌رود: گلوله‌ی
			// تیربار ریز است و گلوله‌ی قناصه سنگین. دو سرِ این بازه فقط
			// نباید بی‌معنی شوند.
			if dmg < 6 || dmg > 140 {
				t.Errorf("%s+%s: خسارتِ ترکیبی %.0f از بازه‌ی معقول بیرون است", cid, wid, dmg)
			}
			miss := clampUnit(cs.MissChance * wm.MissMult)
			if miss > 0.16 {
				t.Errorf("%s+%s: احتمالِ خطا %.0f%% خیلی زیاد است", cid, wid, miss*100)
			}
			fc := cs.FireCooldown * wm.FireRateMult
			if fc < 0.08 || fc > 1.90 {
				t.Errorf("%s+%s: فاصله‌ی شلیک %.2f از بازه‌ی معقول بیرون است", cid, wid, fc)
			}
			// همان تعادلِ قبلی، فقط با شکلِ تازه
			if dps := dmg / fc; dps < 55 || dps > 135 {
				t.Errorf("%s+%s: خسارت-در-ثانیه %.0f از تعادل خارج است", cid, wid, dps)
			}
			// خشاب نباید وسطِ رگبار خشک شود. برای سلاحِ کند، کفِ ۱۲ تایی
			// می‌ماند (که خیلی بیشتر از چهار ثانیه دوام می‌آورد) — مهم
			// این است که هیچ سلاحی زیر این کف نیفتد.
			mag := magazineFor(fc)
			if mag < 12 || mag > 60 {
				t.Errorf("%s+%s: خشابِ %d تایی از بازه بیرون است", cid, wid, mag)
			}
			if sustain := float64(mag) * fc; sustain < 3.0 {
				t.Errorf("%s+%s: خشاب فقط %.1f ثانیه شلیکِ پیوسته می‌دهد", cid, wid, sustain)
			}
		}
	}
}

// خواسته‌ی صریح: تیربار باید واقعاً تیربار باشد — نه اینکه همه‌ی سلاح‌ها
// تقریباً یک‌جور شلیک کنند (مشکلی که قبلاً بود: ۲.۳ تا ۳.۸ تیر در ثانیه).
func TestFireRatePipActuallyChangesTheFeel(t *testing.T) {
	slow := fireRateMult(1)
	fast := fireRateMult(5)
	if slow/fast < 3.0 {
		t.Errorf("سریع‌ترین سلاح فقط %.1f برابرِ کندترین است — رگبار حس نمی‌شود",
			slow/fast)
	}

	cs := CharacterStats("skin_default")
	shotsPerSecond := func(wid string) float64 {
		return 1.0 / (cs.FireCooldown * WeaponStatsFor(wid).FireRateMult)
	}
	// تیربارِ سبک: دستِ‌کم ۸ تیر در ثانیه
	if got := shotsPerSecond("fnmag"); got < 8.0 {
		t.Errorf("fnmag فقط %.1f تیر در ثانیه می‌زند", got)
	}
	// مسلسل: دستِ‌کم ۵ تیر در ثانیه
	if got := shotsPerSecond("mg3"); got < 5.0 {
		t.Errorf("mg3 فقط %.1f تیر در ثانیه می‌زند", got)
	}
	// قناصه باید واقعاً کند باشد: نزدیکِ یک‌ونیم ثانیه بین دو تیر
	for _, wid := range []string{"awm", "m24sws"} {
		cd := cs.FireCooldown * WeaponStatsFor(wid).FireRateMult
		if cd < 1.2 || cd > 1.9 {
			t.Errorf("%s هر %.2f ثانیه یک تیر می‌زند — هدف حدود ۱٫۵ ثانیه است", wid, cd)
		}
	}
}

// قناصه: کند ولی کوبنده.
//
// خواسته‌ی صریح بود که سرعتش خیلی کم و خسارتش به همان اندازه زیاد شود —
// یعنی یک تیر باید کاراکترِ سبک را بیندازد. تنها سقفی که می‌گذاریم این
// است که سنگین‌ترین ضربه هم نتواند مقاوم‌ترین کاراکتر را یک‌ضربه‌ای کند،
// وگرنه هیچ ساختی جلوی قناصه دوام نمی‌آورد.
func TestSniperHitsHard(t *testing.T) {
	weakest, toughest := 9999, 0
	for cid := range characterPips {
		hp := CharacterStats(cid).Health
		if hp < weakest {
			weakest = hp
		}
		if hp > toughest {
			toughest = hp
		}
	}

	for _, wid := range []string{"awm", "m24sws"} {
		wm := WeaponStatsFor(wid)
		hardest := 0.0
		for cid := range characterPips {
			dmg := float64(CharacterStats(cid).Damage) * wm.DamageMult
			if dmg < 90 {
				t.Errorf("%s+%s: قناصه فقط %.0f خسارت می‌زند — کم است", cid, wid, dmg)
			}
			if dmg > hardest {
				hardest = dmg
			}
		}
		// کاراکترِ سبک باید با یک تیر بیفتد (خواسته‌ی خودِ حالت)
		if hardest < float64(weakest) {
			t.Errorf("%s حتی ضعیف‌ترین کاراکتر (%d جان) را با یک تیر نمی‌اندازد (%.0f)",
				wid, weakest, hardest)
		}
		// ولی نه همه را
		if hardest > float64(toughest) {
			t.Errorf("%s با یک تیر (%.0f) مقاوم‌ترین کاراکتر (%d جان) را هم می‌کشد",
				wid, hardest, toughest)
		}
	}
}

// -----------------------------------------------------------------------------
// تست‌های ضدِ تقلب — همه‌چیزِ تعیین‌کننده باید سمتِ سرور باشد
// -----------------------------------------------------------------------------

// چرخش سمتِ سرور سقف دارد: کلاینتِ دستکاری‌شده نمی‌تواند فوری بچرخد و
// مکانیزمِ hand_speed/control را دور بزند.
func TestServerClampsRotationSpeed(t *testing.T) {
	// بازیکنی رو به شرق (۰ رادیان) که ادعا می‌کند یک‌دفعه ۱۸۰ درجه چرخیده
	const dt = 0.05 // ۵۰ میلی‌ثانیه بین دو پیام
	turnRate := 400.0
	maxDelta := degToRad(turnRate) * dt // حدود ۲۰ درجه

	got := clampRotation(0, math.Pi, maxDelta)
	if math.Abs(got) > maxDelta+1e-9 {
		t.Errorf("چرخشِ ادعاییِ ۱۸۰ درجه باید به %.1f درجه محدود می‌شد، شد %.1f",
			maxDelta*180/math.Pi, got*180/math.Pi)
	}

	// چرخشِ کوچک و قانونی باید کامل قبول شود
	small := degToRad(5.0)
	if got := clampRotation(0, small, maxDelta); math.Abs(got-small) > 1e-9 {
		t.Errorf("چرخشِ کوچکِ قانونی نباید محدود شود: %.2f", got*180/math.Pi)
	}
}

// هیچ ترکیبِ کاراکتر/سلاحی نباید چرخشی بدهد که از بازه‌ی معقول بیرون بزند
// (وگرنه سقفِ سرور یا خیلی سخت‌گیر می‌شود یا بی‌اثر).
func TestCombinedTurnRateStaysInRange(t *testing.T) {
	for cid := range characterPips {
		cs := CharacterStats(cid)
		for wid := range weaponPips {
			wm := WeaponStatsFor(wid)
			combined := (cs.TurnRate + wm.TurnRateContribution) / 2.0
			if combined < 300 || combined > 570 {
				t.Errorf("%s+%s: چرخشِ ترکیبی %.0f درجه/ثانیه از بازه بیرون است",
					cid, wid, combined)
			}
		}
	}
}

// مخروطِ شلیک هرگز نباید آن‌قدر باز شود که عملاً بی‌اثر شود، یا آن‌قدر تنگ
// که شلیک غیرممکن شود.
func TestFireConeStaysUsable(t *testing.T) {
	for wid := range weaponPips {
		cone := WeaponStatsFor(wid).FireConeDeg
		if cone < 12 || cone > 30 {
			t.Errorf("%s: مخروطِ شلیک %.0f درجه غیرمنطقی است", wid, cone)
		}
	}
}
