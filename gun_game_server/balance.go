package main

import (
	"context"
	"fmt"
	"math"

	"go.mongodb.org/mongo-driver/bson"
)

// -----------------------------------------------------------------------------
// تراز کاراکترها (Character Balance)
// -----------------------------------------------------------------------------
//
// دو قانون این فایل را می‌سازند:
//
// ۱) **درون یک نایابی، هیچ‌کس از دیگری قوی‌تر نیست.** همه‌ی کاراکترهای rare
//    دقیقاً totalPips امتیاز دارند، همه‌ی epicها هم، همه‌ی legendها هم. فرقشان
//    فقط در «پخشِ» این امتیاز است — نقطه‌قوت و نقطه‌ضعفِ متفاوت، نه قدرتِ بیشتر.
//    پس بین دو اسکینِ هم‌رده، خرید گران‌تر برتری نمی‌خرد؛ سبکِ بازی می‌خرد.
//
// ۲) **بین نایابی‌ها یک برتریِ خیلی کم هست.** اپیک ۳٪ و لجند ۶٪ قوی‌تر است.
//    این ضریب فقط روی «قدرت» اعمال می‌شود (سلامت، خسارت گلوله، خسارت بمب) و
//    عمداً روی سرعت و برد اعمال *نمی‌شود*: اختلافِ سرعت و برد توی شوتر خیلی
//    توی چشم می‌زند و بازی را ناعادلانه نشان می‌دهد، ولی ۶٪ سلامت بیشتر در
//    عمل یعنی «گاهی یک تیر بیشتر دوام می‌آورد» — حس می‌شود ولی تعیین‌کننده نیست.
//
// دامنه‌ی مجازِ هر ویژگی هم با نایابی باز می‌شود، یعنی لجند «تخصصی‌تر» است:
//
//	rare   → هر ویژگی بین ۲ تا ۴  (متعادل و بی‌دردسر، مناسب تازه‌کار)
//	epic   → هر ویژگی بین ۲ تا ۵
//	legend → هر ویژگی بین ۱ تا ۵  (سقف بلندتر، ولی کفِ پایین‌تر)
//
// سیستم ارتقا که بعداً اضافه می‌شود می‌تواند به امتیازِ هر کاراکتر اضافه کند؛
// همه‌ی فرمول‌ها همین‌جاست، پس جای دست‌بردن یک‌جاست.
//
// نکته‌ی امنیتی: عددهای گیم‌پلی از همین‌جا خوانده می‌شوند، نه از دیتابیس.
// دیتابیس فقط برای نمایش در فروشگاه پر می‌شود (SeedCharacterStats). این‌طوری
// دست‌کاری دیتابیس یا کلاینت روی تعادلِ بازی اثر نمی‌گذارد.

// بودجه‌ی امتیازِ هر نایابی — درون هر رده یکسان است.
var pipBudget = map[string]int{
	"rare":   15,
	"epic":   15,
	"legend": 15,
}

// totalPips بودجه‌ی پایه (rare). تست‌ها به آن تکیه می‌کنند.
const totalPips = 15

// rarityPowerBonus برتریِ خیلی کمِ رده‌های بالاتر.
// فقط روی سلامت / خسارت گلوله / خسارت بمب اعمال می‌شود.
var rarityPowerBonus = map[string]float64{
	"rare":   1.00,
	"epic":   1.03,
	"legend": 1.06,
}

// characterRarity نایابیِ هر کاراکتر — باید با کاتالوگ فروشگاه یکی باشد.
var characterRarity = map[string]string{
	"skin_default": "rare", "skin_boy": "rare", "skin_girl": "rare",
	"skin_iraqian": "epic", "skin_angle": "epic", "skin_smoke": "epic",
	"skin_sniper": "epic", "skin_engineer": "epic",
	"skin_joker": "legend", "skin_devil": "legend", "skin_roman": "legend",
	"skin_nature": "legend", "skin_lighting": "legend",
	"skin_rainbow": "legend", "skin_fire": "legend",
}

// maxLevelFor سقف سطحِ ارتقا برای هر رده — باید با max_level کاتالوگ یکی باشد.
// وقتی سیستم ارتقا اضافه شود، بازیکن آیتم را از سطح ۱ تا همین سقف بالا می‌برد.
var maxLevelFor = map[string]int{
	"rare":   5,
	"epic":   8,
	"legend": 10,
}

// levelGainAtMax کلِ رشدی که ارتقا تا سقفِ رده می‌دهد.
// عمداً کم است: ارتقا باید حس پیشرفت بدهد، نه این‌که بازیکنِ قدیمی را
// شکست‌ناپذیر کند. یک لجندِ فول‌آپدیت در مجموع حدود ۱۰٪ از یک rareِ
// فول‌آپدیت جلوتر است — محسوس، ولی نه تعیین‌کننده.
var levelGainAtMax = map[string]float64{
	"rare":   0.10,
	"epic":   0.12,
	"legend": 0.14,
}

// rarityPipRange دامنه‌ی مجازِ هر ویژگی به تفکیک نایابی
var rarityPipRange = map[string][2]int{
	"rare":   {2, 4},
	"epic":   {2, 5},
	"legend": {1, 5},
}

// CharPips امتیازهای خام یک کاراکتر (هر کدام ۱ تا ۵، جمعشان بودجه‌ی رده)
type CharPips struct {
	Vitality  int // سلامت
	Speed     int // سرعت حرکت
	Firepower int // خسارت هر گلوله
	BombReach int // برد پرتاب بمب
	BombPower int // شعاع و خسارت انفجار
}

// Sum مجموع امتیازها
func (p CharPips) Sum() int {
	return p.Vitality + p.Speed + p.Firepower + p.BombReach + p.BombPower
}

// CharStats عددهای واقعیِ گیم‌پلی که از روی امتیازها حساب می‌شوند
type CharStats struct {
	Rarity   string   `json:"rarity"`
	Level    int      `json:"level"`
	MaxLevel int      `json:"max_level"`
	Pips     CharPips `json:"pips"`
	Health   int      `json:"health"`
	Speed    float64  `json:"speed"`
	Damage   int      `json:"damage"`
	// damageExact خسارتِ گردنشده. خسارت یک بار، آخرِ زنجیره (رده × سطح ×
	// سلاح) گرد می‌شود؛ گرد کردنِ سه‌باره باعث می‌شد بعضی سطح‌های ارتقا
	// هیچ خسارتی اضافه نکنند و بعضی دو برابرِ قرار.
	damageExact float64
	BombRange   float64 `json:"bomb_range"`
	BombRadius  float64 `json:"bomb_radius"`
	BombDamage  int     `json:"bomb_damage"`
	// این چهارتا همان چیزی را که در فروشگاه دیده می‌شود واقعاً روی بازی
	// اعمال می‌کنند — بدون استثنا، هر شش ویژگیِ نمایشیِ کاراکتر یک اثرِ
	// واقعی در بازی دارد (move_speed→Speed, throw_range→BombRange,
	// health→Health از قبل بودند؛ این سه‌تا رفتار تازه‌اند):
	FireCooldown float64 `json:"fire_cooldown"` // ثانیه بین دو شلیک (بعد از ضریبِ سلاح)
	MissChance   float64 `json:"miss_chance"`   // احتمال خطا حتی با دید باز (بعد از ضریبِ سلاح)
	HealAmount   int     `json:"heal_amount"`   // مقدار هر بار درمان — health_regen
	HealCooldown float64 `json:"heal_cooldown"` // ثانیه بین دو درمان — health_regen
	// TurnRate → hand_speed: «نسبت چرخش و راحتیِ چرخش». فقط از کاراکتر
	// می‌آید. سلاح رویش اثر ندارد؛ آن‌چه سلاح اضافه می‌کند FireConeDeg است
	// (پهنای مخروطی که همین چرخش باید داخلش برسد تا شلیک ثبت شود).
	TurnRate float64 `json:"turn_rate"` // درجه بر ثانیه

	// این دوتا خالص از سلاح می‌آیند (applyLoadout در hub.go پرشان می‌کند)؛
	// این‌جا فقط پیش‌فرضِ معقول دارند تا CharacterStats() تنها هم قابلِ‌استفاده بماند.
	MaxRange    float64 `json:"max_range"`     // بردِ مؤثرِ شلیک — از سلاح
	FireConeDeg float64 `json:"fire_cone_deg"` // پهنای مخروطِ لازم برای شلیک — از سلاح

	// --- خشاب ---
	// خشاب به سرعتِ شلیکِ همان سلاح گره خورده، نه یک عددِ ثابت: با تیرباری
	// که ثانیه‌ای ۱۰ تیر می‌زند، خشابِ ۱۲تایی یک ثانیه‌ونیم بیشتر دوام
	// نمی‌آورد و رگبار بی‌معنی می‌شود. هر دو را applyLoadout پر می‌کند.
	MagSize       int     `json:"mag_size"`       // تعدادِ گلوله‌ی یک خشاب
	ReloadSeconds float64 `json:"reload_seconds"` // پر کردنِ خودکارِ خشابِ خالی
}

// MagSustainSeconds یک خشاب چند ثانیه شلیکِ پیوسته دوام بیاورد.
//
// همین یک عدد باعث می‌شود همه‌ی سلاح‌ها «یک اندازه» حس شوند: تک‌تیرانداز
// خشابِ کوچک دارد و تیربار خشابِ بزرگ، ولی هر دو تقریباً به‌اندازه‌ی هم
// می‌توانند پشتِ‌سرِ‌هم بزنند.
const MagSustainSeconds = 4.0

// MagReloadSeconds پر شدنِ دوباره‌ی خشابِ خالی (خودکار).
// جعبه‌ی فشنگِ روی زمین همچنان فوری پرش می‌کند.
const MagReloadSeconds = 1.6

// magazineFor اندازه‌ی خشاب از روی فاصله‌ی بین دو شلیک
func magazineFor(fireCooldown float64) int {
	if fireCooldown <= 0 {
		return 30
	}
	n := int(math.Round(MagSustainSeconds / fireCooldown))
	if n < 12 {
		n = 12
	}
	if n > 60 {
		n = 60
	}
	return n
}

// characterPips جدول تراز. جمع هر ردیف دقیقاً بودجه‌ی رده‌ی خودش است
// (تست تضمینش می‌کند).
//
//	تندرستی  سرعت  آتش  بردِ‌بمب  قدرتِ‌بمب
var characterPips = map[string]CharPips{
	// --- rare: متعادل، بدون ضعف شدید (دامنه ۲..۴) ---
	"skin_default": {3, 3, 3, 3, 3}, // همه‌فن‌حریفِ پیش‌فرض
	"skin_boy":     {2, 4, 3, 3, 3}, // چابک
	"skin_girl":    {3, 4, 2, 3, 3}, // چابک و بادوام، آتشِ کمتر

	// --- epic: یک تخصص مشخص (دامنه ۲..۵) ---
	"skin_iraqian":  {4, 2, 4, 3, 2}, // جنگاورِ کهنه‌کار: جان و آتش
	"skin_angle":    {2, 5, 3, 3, 2}, // فرشته: سریع‌ترینِ اپیک‌ها
	"skin_smoke":    {3, 3, 2, 2, 5}, // تخریب‌چی: انفجارِ سنگین
	"skin_sniper":   {2, 2, 5, 4, 2}, // تک‌تیرانداز: بیشترین خسارتِ گلوله
	"skin_engineer": {3, 2, 2, 5, 3}, // مهندس: دورترین پرتابِ بمب

	// --- legend: تخصصی‌ترین‌ها (دامنه ۱..۵) ---
	"skin_joker":    {2, 4, 4, 4, 1}, // جوکر: همه‌چیز جز بمب
	"skin_devil":    {5, 2, 4, 2, 2}, // شیطان: گوشتی و پرآتش، کُند
	"skin_roman":    {5, 1, 3, 3, 3}, // رومی: سپرِ متحرک، خیلی کُند
	"skin_nature":   {4, 3, 2, 3, 3}, // طبیعت: بادوام و متعادل
	"skin_lighting": {1, 5, 4, 3, 2}, // رعدوبرق: شیشه‌ای ولی برق‌آسا
	"skin_rainbow":  {3, 3, 3, 3, 3}, // رنگین‌کمان: بدون ضعف، بدون اوج
	"skin_fire":     {2, 2, 3, 3, 5}, // آتش: توپخانه
}

// defaultPips وقتی آیدی ناشناس باشد (کاراکتر تازه‌ای که هنوز در جدول نیست)
var defaultPips = CharPips{3, 3, 3, 3, 3}

// --- فرمول‌های تبدیل امتیاز به عدد ---
//
// دامنه‌ها عمداً باریک‌اند: اختلاف کاراکترها باید حس شود ولی مهارتِ بازیکن
// همچنان حرف اول را بزند. (اعداد قبل از ضریبِ نایابی)
//
//	سلامت      ۹۶ .. ۱۲۸   (پایه ۱۱۲)
//	سرعت       ۱۸۴ .. ۲۱۶  (پایه ۲۰۰) — بدون ضریب نایابی
//	خسارت      ۲۱ .. ۲۹    (پایه ۲۵)
//	بردِ بمب    ۲۶۰ .. ۵۰۰  (پایه ۳۸۰) — بدون ضریب نایابی
//	شعاعِ بمب   ۸۸ .. ۱۲۰   (پایه ۱۰۴) — بدون ضریب نایابی
//	خسارتِ بمب  ۳۹ .. ۵۹    (پایه ۴۹)
//
// avgPip میانگینِ دو امتیاز را گرد می‌کند — هم برای عددِ نمایشی در فروشگاه
// استفاده می‌شود هم برای فرمولِ واقعیِ گیم‌پلی، تا این دو هیچ‌وقت از هم
// جدا نیفتند (چیزی که در فروشگاه دیده می‌شود همان چیزی است که اتفاق می‌افتد).
func avgPip(a, b int) int {
	return int(math.Round(float64(a+b) / 2.0))
}

func statsFromPips(p CharPips, rarity string) CharStats {
	bonus, ok := rarityPowerBonus[rarity]
	if !ok {
		bonus = 1.0
	}
	handSpeedPip := avgPip(p.Speed, p.Firepower) // همان منبعِ hand_speed در فروشگاه
	regenPip := avgPip(p.Vitality, p.BombPower)  // همان منبعِ health_regen در فروشگاه

	return CharStats{
		Rarity: rarity,
		Pips:   p,
		// ضریب نایابی فقط روی این سه‌تا:
		// جان و درمان و بمب ×۱.۲۵ نسبت به قبل (۸۸+۸V): دوئل از ~۱.۲ ثانیه به
		// ~۲ ثانیه رسید تا سپر، درمان و بمب فرصتِ اثر داشته باشند، و AWM
		// دیگر کاراکترِ rare را با یک تیر نمی‌اندازد.
		Health:      int(math.Round(float64(110+p.Vitality*10) * bonus)),
		Damage:      int(math.Round(float64(19+p.Firepower*2) * bonus)),
		damageExact: float64(19+p.Firepower*2) * bonus,
		BombDamage:  int(math.Round(float64(34+p.BombPower*5) * 1.25 * bonus)),
		// این‌ها فقط از امتیاز می‌آیند — سرعت و برد نباید با پول بهتر شود:
		Speed:      float64(176 + p.Speed*8),
		BombRange:  float64(200 + p.BombReach*60),
		BombRadius: float64(80 + p.BombPower*8),

		// hand_speed → فاصله‌ی بین دو شلیک: ۰.۴۲ ثانیه (کندترین) تا ۰.۳۰ (سریع‌ترین)
		FireCooldown: 0.45 - float64(handSpeedPip)*0.03,
		// hand_speed → «نسبت چرخش و راحتیِ چرخش»: ۳۲۰ (کندترین) تا ۵۶۰ درجه/ثانیه
		TurnRate: 260.0 + float64(handSpeedPip)*60.0,
		// پیش‌فرضِ خنثی؛ applyLoadout در hub.go با ضریبِ سلاح جایگزینش می‌کند
		MaxRange:    500.0,
		FireConeDeg: 20.0,
		// aim_accuracy → احتمال خطا حتی وقتی دید باز است: از ۱۰٪ (بدترین Firepower) تا ۰٪ (بهترین)
		MissChance: float64(5-p.Firepower) * 0.025,
		// health_regen → مقدار و فاصله‌ی درمان
		HealAmount:   int(math.Round(float64(17+regenPip*3) * 1.25)), // ۲۵ تا ۴۰
		HealCooldown: 15.0 - float64(regenPip),                       // ۱۴ تا ۱۰ ثانیه
	}
}

// MaxLevelOf سقف سطحِ یک کاراکتر
func MaxLevelOf(characterID string) int {
	rarity, ok := characterRarity[characterID]
	if !ok {
		rarity = "rare"
	}
	if lv, ok := maxLevelFor[rarity]; ok {
		return lv
	}
	return 1
}

// levelFactor ضریبِ رشدِ ارتقا: در سطح ۱ برابرِ ۱.۰ و در سقفِ رده برابرِ
// ۱+levelGainAtMax. بینشان خطی بالا می‌رود، پس هر سطح یک قدمِ یکنواخت است.
func levelFactor(rarity string, level int) float64 {
	maxLv, ok := maxLevelFor[rarity]
	if !ok || maxLv <= 1 {
		return 1.0
	}
	if level < 1 {
		level = 1
	}
	if level > maxLv {
		level = maxLv
	}
	t := float64(level-1) / float64(maxLv-1) // ۰ در سطح ۱، ۱ در سقف
	return 1.0 + levelGainAtMax[rarity]*t
}

// CharacterStats عددهای گیم‌پلیِ یک کاراکتر در سطح ۱.
func CharacterStats(characterID string) CharStats {
	return CharacterStatsAtLevel(characterID, 1)
}

// CharacterStatsAtLevel عددهای گیم‌پلیِ یک کاراکتر در سطحِ داده‌شده.
// حرفِ آخر همین است — سطح هم مثل بقیه‌ی چیزها سمت سرور نگه داشته می‌شود.
func CharacterStatsAtLevel(characterID string, level int) CharStats {
	p, ok := characterPips[characterID]
	if !ok {
		p = defaultPips
	}
	rarity, ok := characterRarity[characterID]
	if !ok {
		rarity = "rare"
	}
	st := statsFromPips(p, rarity)
	st.Level = level
	st.MaxLevel = MaxLevelOf(characterID)

	// ارتقا فقط «قدرت و برد» را بالا می‌برد، نه سرعت را: اختلافِ سرعت
	// بین بازیکن‌ها زشت‌ترین نوعِ نابرابری در یک شوتر است.
	lf := levelFactor(rarity, level)
	if lf != 1.0 {
		st.Health = int(math.Round(float64(st.Health) * lf))
		st.damageExact *= lf
		st.Damage = int(math.Round(st.damageExact))
		st.BombDamage = int(math.Round(float64(st.BombDamage) * lf))
		st.BombRange = math.Round(st.BombRange * lf)
		st.BombRadius = math.Round(st.BombRadius * lf)
	}
	return st
}

// -----------------------------------------------------------------------------
// نمایشِ فروشگاه (Shop Display Stats)
// -----------------------------------------------------------------------------
//
// هر دو صفحه‌ی فروشگاه (character_select_screen.gd و shop.gd) از قبل یک
// سیستمِ نوار-امتیاز آماده دارند: شش ویژگیِ کاراکتر را از یک Dictionary به
// نام‌های ثابت می‌خوانند —
//
//	move_speed, aim_accuracy, hand_speed, throw_range, health, health_regen
//
// و هرکدام را به‌صورت «مقدار / (max_level×۱۰)» نشان می‌دهند. یعنی سقفِ نوار
// از رده می‌آید: rare تا ۵۰، epic تا ۸۰، legend تا ۱۰۰ — همین max_level که
// از قبل روی هر آیتمِ کاتالوگ نشسته و دست نمی‌خورد.
//
// وظیفه‌ی این بخش فقط پر کردنِ همان شش عدد است، از روی همان امتیازهای
// balance.go (تا چیزی که در فروشگاه می‌بینی با رفتارِ واقعیِ کاراکتر توی
// بازی یکی باشد) — بدون افزودن هیچ فیلد تازه‌ای به دیتابیس.
//
// فرمول: rating = پایه + امتیازِ خام×گام + پاداشِ رده
//
//	rare   (پایه ۲۰): امتیاز ۱..۵ → ۲۶..۵۰   (سقفِ نوار ۵۰ — بهترین حالت پر می‌شود)
//	epic   (پایه ۳۰): امتیاز ۱..۵ → ۳۶..۶۰   (سقفِ نوار ۸۰)
//	legend (پایه ۳۸): امتیاز ۱..۵ → ۴۴..۶۸   (سقفِ نوار ۱۰۰)
//
// یعنی بهترین ویژگیِ یک rare (۵۰) از ضعیف‌ترین ویژگیِ یک legend (۴۴) هم
// جلوتر است — بازیکنِ رده‌ی پایین هیچ‌وقت زمین تا آسمان با بازیکنِ رده‌ی
// بالا فرق نمی‌بیند، فقط یک پله‌ی معقول. سقفِ ۸۰/۱۰۰ درِ رده‌های بالاتر هم
// عمداً کامل پر نمی‌شود — همان جایی است که سیستم ارتقا (که بعداً اضافه
// می‌شود) با بالا بردنِ سطح آیتم، این عدد را به سمتِ سقف واقعی می‌برد.
var ratingBase = map[string]int{"rare": 20, "epic": 30, "legend": 38}

const ratingStep = 6 // به‌ازای هر واحدِ امتیازِ خام (۱..۵)

// shopRating یک امتیازِ خامِ ۱..۵ را به عددِ نمایشیِ فروشگاه تبدیل می‌کند.
func shopRating(pip int, rarity string) int {
	base, ok := ratingBase[rarity]
	if !ok {
		base = ratingBase["rare"]
	}
	if pip < 1 {
		pip = 1
	}
	if pip > 5 {
		pip = 5
	}
	return base + pip*ratingStep
}

// shopCharacterRatings شش عددِ نمایشیِ فروشگاه را از همان امتیازهای
// balance.go می‌سازد. دو ویژگی (hand_speed و health_regen) معادلِ مستقیمی
// در جدولِ ۵تایی ندارند، پس از میانگینِ دو ویژگیِ نزدیک ساخته می‌شوند —
// هم برای تنوعِ ظاهری، هم چون واقعاً بی‌ربط نیستند (دستِ سریع = واکنشِ سریع،
// بازیابیِ جانِ خوب = بادوامی).
func shopCharacterRatings(characterID string) map[string]int {
	p, ok := characterPips[characterID]
	if !ok {
		p = defaultPips
	}
	rarity, ok := characterRarity[characterID]
	if !ok {
		rarity = "rare"
	}
	return map[string]int{
		"move_speed":   shopRating(p.Speed, rarity),
		"aim_accuracy": shopRating(p.Firepower, rarity),
		"hand_speed":   shopRating(avgPip(p.Speed, p.Firepower), rarity),
		"throw_range":  shopRating(p.BombReach, rarity),
		"health":       shopRating(p.Vitality, rarity),
		"health_regen": shopRating(avgPip(p.Vitality, p.BombPower), rarity),
	}
}

// شش کلیدِ دقیقی که character_select_screen.gd و shop.gd می‌خوانند — برای
// پاک‌سازیِ هر فیلدِ اضافیِ قدیمی از شماها استفاده می‌شود (پایین را ببین).
var shopStatKeys = []string{"move_speed", "aim_accuracy", "hand_speed", "throw_range", "health", "health_regen"}

// characterCombatDoc عددهای واقعیِ گیم‌پلیِ یک کاراکتر — در سطح ۱ و در
// سقفِ سطحش، تا کارتِ فروشگاه بتواند «الان» و «بعد از ارتقا» را نشان بدهد.
//
// مستقیم از CharacterStatsAtLevel می‌آید، پس با هر تغییرِ تراز خودش تازه
// می‌شود (SeedStaticData در هر بالا آمدنِ سرور صدایش می‌زند).
func characterCombatDoc(characterID string) bson.M {
	lv1 := CharacterStatsAtLevel(characterID, 1)
	maxLv := MaxLevelOf(characterID)
	top := CharacterStatsAtLevel(characterID, maxLv)

	return bson.M{
		"rarity":    lv1.Rarity,
		"max_level": maxLv,
		// سلاح روی این‌ها ضریب می‌زند؛ این‌ها عددِ خالصِ کاراکترند
		"health":           lv1.Health,
		"damage":           lv1.Damage,
		"speed":            round2(lv1.Speed),
		"fire_cooldown":    round2(lv1.FireCooldown),
		"shots_per_second": round2(1.0 / lv1.FireCooldown),
		"turn_rate":        round2(lv1.TurnRate),
		"miss_chance":      round3(lv1.MissChance),
		"heal_amount":      lv1.HealAmount,
		"heal_cooldown":    round2(lv1.HealCooldown),
		"bomb_damage":      lv1.BombDamage,
		"bomb_range":       round2(lv1.BombRange),
		"bomb_radius":      round2(lv1.BombRadius),
		// در سقفِ سطح — همان چیزی که ارتقا به آن می‌رساند
		"max_health":      top.Health,
		"max_damage":      top.Damage,
		"max_bomb_damage": top.BombDamage,
	}
}

// round2 و round3 فقط برای خوانا ماندنِ سند در دیتابیس‌اند؛ خودِ بازی با
// عددِ کاملِ float کار می‌کند.
func round2(v float64) float64 { return math.Round(v*100) / 100 }

func round3(v float64) float64 { return math.Round(v*1000) / 1000 }

// SeedCharacterStats شش عددِ نمایشیِ فروشگاه را برای هر کاراکتر می‌نویسد.
// فقط همین شش کلیدِ از قبل موجود دست‌کاری می‌شوند — نه max_level (که خودِ
// کاتالوگ از قبل دارد) و نه هیچ فیلدِ تازه‌ای.
func SeedCharacterStats(ctx context.Context) error {
	items := col(ColShopItems)
	for id := range characterPips {
		ratings := shopCharacterRatings(id)

		set := bson.M{}
		for k, v := range ratings {
			set["stats."+k] = v
		}
		// فیلدهایی که نسخه‌ی قبلی این تابع اشتباهی نوشته بود (pip_*، max_*،
		// damage، bomb_range و ...) اگر روی سندی مانده باشند پاک می‌شوند.
		unset := bson.M{}
		for _, k := range []string{
			"stats.speed", // نسخه‌ی خیلی اولِ این تابع «speed» به‌جای «move_speed» می‌نوشت
			"stats.pip_vitality", "stats.pip_speed", "stats.pip_firepower",
			"stats.pip_bomb_reach", "stats.pip_bomb_power", "stats.pip_total",
			"stats.damage", "stats.bomb_range", "stats.bomb_radius", "stats.bomb_damage",
			"stats.max_level", "stats.max_health", "stats.max_damage",
			"stats.max_bomb_range", "stats.max_bomb_radius", "stats.max_bomb_damage",
		} {
			unset[k] = ""
		}

		// عددهای واقعیِ بازی هم کنارِ ستاره‌ها می‌نشینند
		for k, v := range characterCombatDoc(id) {
			set["combat."+k] = v
		}

		if _, err := items.UpdateOne(ctx,
			bson.M{"item_id": id},
			bson.M{"$set": set, "$unset": unset}); err != nil {
			return fmt.Errorf("نوشتن تراز فروشگاهیِ %s: %w", id, err)
		}
	}
	return nil
}
