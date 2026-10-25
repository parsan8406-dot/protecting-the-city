package main

import (
	"context"
	"fmt"

	"go.mongodb.org/mongo-driver/bson"
)

// -----------------------------------------------------------------------------
// تراز سلاح‌ها (Weapon Balance)
// -----------------------------------------------------------------------------
//
// همان فلسفه‌ی balance.go برای کاراکترها، اینجا برای سلاح‌ها: هر سلاح ۱۵
// امتیاز دارد که بین پنج ویژگیِ نمایشیِ فروشگاه پخش شده — power, accuracy,
// range, fire_rate, control (همان کلیدهایی که shop.gd و
// character_select_screen.gd از قبل می‌خوانند).
//
// اثرِ سلاح روی بازی «یک لایه‌ی نازک» روی تراز کاراکتر است، نه یک ضربِ
// دوباره‌ی قدرت: هر ضریب حداکثر حدود ±۱۵٪ عوض می‌کند. کاراکتر می‌گوید «چقدر
// قدرتمندی»، سلاح می‌گوید «این ابزار مشخصاً برای چه کاری بهتر است».
//
//	Power    → ضریبِ خسارت روی همان Damage ای که کاراکتر دارد
//	Accuracy → ضریبی که MissChance کاراکتر را کم/زیاد می‌کند
//	Range    → حداکثر فاصله‌ی مؤثرِ شلیک (به‌جای عددِ ثابتِ قدیمی)
//	FireRate → ضریبی که FireCooldown کاراکتر را کم/زیاد می‌کند
//	Control  → پهنای مخروطِ نشانه‌روی لازم برای شلیک (fire_cone_deg)
//
// (دو تای آخر — Range و Control — دقیقاً روی همان مکانیزم‌هایی می‌نشینند که
// برای hand_speed کاراکتر ساخته شده: مخروطِ نشانه‌روی و برد.)

type WeaponPips struct {
	Power    int // خسارت
	Accuracy int // کاهشِ احتمالِ خطا
	Range    int // بردِ مؤثر
	FireRate int // فاصله‌ی بین دو شلیک
	Control  int // سهولتِ نگه‌داشتنِ نشانه روی هدف
}

func (p WeaponPips) Sum() int {
	return p.Power + p.Accuracy + p.Range + p.FireRate + p.Control
}

var weaponRarity = map[string]string{
	"m82": "rare", "mg3": "rare",
	"fnmag": "epic", "ak47": "epic", "f2000": "epic", "mp5": "epic",
	"m24sws": "legend", "awm": "legend", "fnscare": "legend", "hk416": "legend",
}

// weaponPips جدول تراز سلاح‌ها. جمع هر ردیف دقیقاً ۱۵ است (تست تضمینش
// می‌کند) و هر عدد در دامنه‌ی نایابیِ خودش می‌ماند — همان rarityPipRange
// که برای کاراکترها هم استفاده می‌شود.
//
//	قدرت دقت برد سرعت‌شلیک کنترل
var weaponPips = map[string]WeaponPips{
	"m82": {4, 2, 4, 2, 3}, // ضدِ زره: کوبنده و دوربرد، کند
	"mg3": {4, 2, 2, 4, 3}, // مسلسل: تندشلیک، بی‌دقت

	"fnmag": {4, 2, 2, 5, 2}, // مسلسلِ سبک: سریع‌ترین آتش
	"ak47":  {5, 2, 3, 3, 2}, // کلاسیکِ پرقدرت
	"f2000": {3, 3, 3, 3, 3}, // متعادل
	"mp5":   {2, 4, 2, 4, 3}, // نزدیک‌زن: دقیق و تندشلیک

	"m24sws":  {4, 5, 4, 1, 1}, // تک‌تیرانداز: دقیق‌ترین
	"awm":     {5, 4, 4, 1, 1}, // تک‌تیرانداز: کوبنده‌ترین
	"fnscare": {4, 3, 3, 3, 2}, // تفنگِ نبرد: همه‌کاره
	"hk416":   {3, 3, 3, 3, 3}, // همه‌کاره‌ی درجه‌یک
}

var defaultWeaponPips = WeaponPips{3, 3, 3, 3, 3}

// WeaponMods ضریب‌هایی که سلاح روی عددهای نهاییِ کاراکتر اعمال می‌کند.
// همه‌شان حول یک مقدارِ خنثی نوسان می‌کنند و دامنه‌شان کوچک است — «معتدل».
type WeaponMods struct {
	Rarity       string     `json:"rarity"`
	Pips         WeaponPips `json:"pips"`
	DamageMult   float64    `json:"-"` // بعد از جبرانِ سرعتِ شلیک: ~۰٫۳۲ تا ~۳٫۱
	MissMult     float64    `json:"-"` // ۰٫۸۵ تا ۱٫۰۹ (کمتر بهتر)
	FireRateMult float64    `json:"-"` // ۰٫۳۰ (تیربار) تا ۴٫۲۰ (قناصه) — کمتر = تندتر
	MaxRange     float64    `json:"-"` // ۴۷۵ تا ۶۱۵ پیکسل
	FireConeDeg  float64    `json:"-"` // ۱۶ تا ۲۴ درجه
	// Control هم مثلِ hand_speدِ کاراکتر روی چرخش و آزادیِ حرکت اثر دارد —
	// همان فرمولِ TurnRate کاراکتر (balance.go) با pipِ Control اینجا دوباره
	// حساب می‌شود تا در applyLoadout (hub.go) با همدیگر میانگین گرفته شوند
	// و یکی شوند، نه این‌که سلاح یک مسیرِ جداگانه داشته باشد.
	TurnRateContribution float64 `json:"-"` // ۳۲۰ تا ۵۶۰ درجه/ثانیه
}

// -----------------------------------------------------------------------------
// سرعتِ شلیک
// -----------------------------------------------------------------------------
//
// قبلاً دامنه‌ی fire_rate خیلی باریک بود (۱٫۰۷ تا ۰٫۸۷): قناصه و تیربار
// عملاً یک‌جور شلیک می‌کردند و هیچ سلاحی حسِ خودش را نداشت. حالا این عدد
// طبقه‌ی سلاح را تعیین می‌کند، نه یک تنظیمِ ریز:
//
//	pip ۱ (قناصه)      ×۴٫۲۰  →  حدود ۱٫۵ ثانیه بین دو تیر، ضربِ خیلی سنگین
//	pip ۲ (سنگین)      ×۱٫۱۰  →  حدود ۲ تا ۳ تیر در ثانیه
//	pip ۳ (همه‌کاره)   ×۰٫۷۰  →  حدود ۳ تا ۵ تیر در ثانیه
//	pip ۴ (مسلسل)     ×۰٫۵۰  →  حدود ۵ تا ۷ تیر در ثانیه
//	pip ۵ (تیربارِ سبک) ×۰٫۳۰  →  حدود ۸ تا ۱۱ تیر در ثانیه
//
// جدول است و نه فرمول، چون این‌ها تصمیمِ طراحی‌اند نه نتیجه‌ی یک منحنی:
// فاصله‌ی قناصه تا بقیه عمداً بزرگ است.
var fireRateMultByPip = map[int]float64{
	1: 4.20,
	2: 1.10,
	3: 0.70,
	4: 0.50,
	5: 0.30,
}

// fireRateMult ضریبِ فاصله‌ی بین دو شلیک (کمتر = تندتر)
func fireRateMult(fireRatePip int) float64 {
	if m, ok := fireRateMultByPip[fireRatePip]; ok {
		return m
	}
	// pipِ خارج از جدول: نزدیک‌ترین سرِ جدول
	if fireRatePip < 1 {
		return fireRateMultByPip[1]
	}
	return fireRateMultByPip[5]
}

// fireRateDamageComp خسارتِ هر گلوله را با سرعتِ شلیک جبران می‌کند.
//
// چرا: سرعتِ شلیک حالا تا ×۱۰ بین سلاح‌ها فرق می‌کند. بدونِ این ضریب،
// تیربار سه برابر کشنده می‌شد و قناصه عملاً بی‌خاصیت. با این ضریب،
// خسارت-در-ثانیه‌ی هر سلاح همان چیزی می‌ماند که تراز شده؛ فقط شکلش عوض
// می‌شود:
//
//	قناصه  یک ضربِ خیلی سنگین (نزدیکِ ۱۱۰ خسارت — کاراکترِ سبک با یک تیر)
//	تیربار رگبارِ گلوله‌های ریز (نزدیکِ ۹ خسارت)
//
// نسبت، همان نسبتِ ضریبِ قدیمی به جدید است.
func fireRateDamageComp(fireRatePip int) float64 {
	old := 1.12 - float64(fireRatePip)*0.05
	if old <= 0 {
		return 1.0
	}
	return fireRateMult(fireRatePip) / old
}

// WeaponStatsFor ضریب‌های یک سلاح را برمی‌گرداند. سلاحِ ناشناس مقدارِ
// متعادل (defaultWeaponPips) می‌گیرد، درست مثل کاراکترِ ناشناس.
func WeaponStatsFor(weaponID string) WeaponMods {
	p, ok := weaponPips[weaponID]
	if !ok {
		p = defaultWeaponPips
	}
	rarity := weaponRarity[weaponID]
	if rarity == "" {
		rarity = "rare"
	}
	return WeaponMods{
		Rarity: rarity,
		Pips:   p,
		// خسارتِ هر گلوله عمداً با سرعتِ شلیک جبران می‌شود (fireRateDamageComp)
		DamageMult:   (0.85 + float64(p.Power)*0.06) * fireRateDamageComp(p.FireRate),
		MissMult:     1.15 - float64(p.Accuracy)*0.06,
		FireRateMult: fireRateMult(p.FireRate),
		MaxRange:     440.0 + float64(p.Range)*35.0,
		FireConeDeg:  14.0 + float64(p.Control)*2.0,
		// همان فرمولِ TurnRate در balance.go (260 + pip×60) — عمداً یکی است
		// تا میانگین‌گیری در applyLoadout معنی‌دار بماند.
		TurnRateContribution: 260.0 + float64(p.Control)*60.0,
	}
}

// shopWeaponRatings پنج عددِ نمایشیِ فروشگاه را می‌سازد — همان shopRating
// که برای کاراکترها هم استفاده می‌شود، پس روی همان سقفِ max_level×۱۰ می‌نشیند.
func shopWeaponRatings(weaponID string) map[string]int {
	p, ok := weaponPips[weaponID]
	if !ok {
		p = defaultWeaponPips
	}
	rarity := weaponRarity[weaponID]
	if rarity == "" {
		rarity = "rare"
	}
	return map[string]int{
		"power":     shopRating(p.Power, rarity),
		"accuracy":  shopRating(p.Accuracy, rarity),
		"range":     shopRating(p.Range, rarity),
		"fire_rate": shopRating(p.FireRate, rarity),
		"control":   shopRating(p.Control, rarity),
	}
}

// SeedWeaponStats پنج عددِ نمایشیِ فروشگاه را برای هر سلاح می‌نویسد —
// فقط همین پنج کلیدِ از قبل موجود، هیچ فیلدِ تازه‌ای اضافه نمی‌شود.
func SeedWeaponStats(ctx context.Context) error {
	items := col(ColShopItems)
	for id := range weaponPips {
		ratings := shopWeaponRatings(id)
		set := bson.M{}
		for k, v := range ratings {
			set["stats."+k] = v
		}
		// عددهای واقعیِ بازی هم کنارِ ستاره‌ها می‌نشینند
		for k, v := range weaponCombatDoc(id) {
			set["combat."+k] = v
		}
		if _, err := items.UpdateOne(ctx,
			bson.M{"item_id": id},
			bson.M{"$set": set}); err != nil {
			return fmt.Errorf("نوشتن تراز فروشگاهیِ سلاح %s: %w", id, err)
		}
	}
	return nil
}

// CombatReferenceCharacter کاراکترِ مرجع برای عددهای سلاح در فروشگاه.
//
// خسارت و سرعتِ شلیک همیشه ترکیبِ کاراکتر و سلاح‌اند، پس یک عددِ تنها برای
// سلاح بی‌معنی است. کارتِ فروشگاه عدد را با همین کاراکترِ متعادل نشان
// می‌دهد و خودِ سند هم می‌گوید مرجعش که بوده.
const CombatReferenceCharacter = "skin_default"

// weaponCombatDoc عددهای واقعیِ گیم‌پلیِ یک سلاح — همان چیزی که سرور
// موقعِ بازی اعمال می‌کند، نه یک کپیِ دستی.
//
// از همان applyLoadout عبور می‌کند تا هیچ‌وقت از منبعِ حقیقت عقب نماند:
// اگر فردا ضریبی عوض شود، اولین بالا آمدنِ سرور سندِ فروشگاه را هم تازه
// می‌کند (SeedStaticData هر بار این را صدا می‌زند).
func weaponCombatDoc(weaponID string) bson.M {
	p := &Player{}
	applyLoadout(p, CombatReferenceCharacter, weaponID, 1)
	st := p.Stats
	wm := WeaponStatsFor(weaponID)

	return bson.M{
		"reference_character": CombatReferenceCharacter,
		"damage":              st.Damage,
		"fire_cooldown":       round2(st.FireCooldown),
		"shots_per_second":    round2(1.0 / st.FireCooldown),
		"dps":                 round2(float64(st.Damage) / st.FireCooldown),
		"mag_size":            st.MagSize,
		"reload_seconds":      round2(st.ReloadSeconds),
		"max_range":           round2(st.MaxRange),
		"fire_cone_deg":       round2(st.FireConeDeg),
		"miss_chance":         round3(st.MissChance),
		"turn_rate":           round2(st.TurnRate),
		// ضریب‌های خامِ سلاح، برای اینکه معلوم باشد این عددها از کجا آمده‌اند
		"damage_mult":    round3(wm.DamageMult),
		"fire_rate_mult": round3(wm.FireRateMult),
		"miss_mult":      round3(wm.MissMult),
	}
}
