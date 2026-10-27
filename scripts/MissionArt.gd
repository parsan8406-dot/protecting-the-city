extends Object
class_name MissionArt
## آیکن و رنگ‌های صفحه‌ی «ماموریت ها» — یک جای واحد برای همه‌ی صفحه‌ها.
##
## سرور در هر ماموریت/پله یک `icon` می‌فرستد (مثل "kill" یا "chest_rare") و
## اینجا به فایل نگاشت می‌شود. اگر سرور آیکن جدیدی فرستاد که اینجا نیست،
## به‌جای خطا آیکن پیش‌فرض برمی‌گردد تا صفحه خالی نماند.
##
## استفاده:
##   icon_rect.texture = MissionArt.texture_for(mission.get("icon", ""))
##
## 🎨 همه‌ی SVGها عمداً *سفید* کشیده شده‌اند تا با modulate بشود هر رنگی‌شان
## کرد (طلایی برای جایزه، روشن برای فعال، خاکستری برای قفل). اگر آیکن جدیدی
## اضافه می‌کنی هم سفید بکش، وگرنه modulate رنگش را کثیف می‌کند.

const BASE := "res://assets/icons/missions/"
## آرت رنگی (برخلاف BASE که آیکن سفیدِ modulate-شونده است)
const ART := "res://assets/ui/missions/"

## شناسه‌ی آیکن (همان چیزی که سرور در missions.go → Icon می‌گذارد) → فایل
const BY_ID := {
	# ماموریت‌های روزانه — PNG سفیدِ تک‌رنگ، پس modulate رویشان کار می‌کند
	"match": BASE + "icon_match.png",
	"kill": BASE + "icon_kill.png",
	"win": BASE + "icon_win.png",
	"assist": BASE + "icon_assist.png",
	"time": BASE + "icon_time.png",
	"grenade": BASE + "icon_grenade.png",
	"heal": BASE + "icon_heal.png",
	"xp": BASE + "icon_xp.png",
	"flawless": BASE + "icon_flawless.png",
	"headshot": BASE + "icon_headshot.png",
	# جایزه‌ها
	"cup": BASE + "icon_cup.png",
	"trophy": BASE + "icon_trophy.png",
	# سکه و جم آرت رنگیِ خود بازی‌اند (همان‌هایی که بقیه‌ی صفحه‌ها استفاده
	# می‌کنند)، پس رنگ نمی‌خورند — is_art_icon جلویش را می‌گیرد.
	"coin": "res://assets/ui/coin_icon.png",
	"gem": "res://assets/ui/gem_icon.png",
	# آیتم‌های آرایشیِ نردبان فصل — آرت رنگی
	"char_skin": ART + "reward_char_skin.png",
	"weapon_skin": ART + "reward_weapon_skin.png",
	# صندوق‌های نوار جایزه‌ی روزانه — آرت رنگی
	"chest_common": ART + "chest_common.png",
	"chest_rare": ART + "chest_rare.png",
	"chest_legend": ART + "chest_legend.png",
	# آیکن‌های خود صفحه (سرور نمی‌فرستدشان، صحنه مستقیم استفاده می‌کند)
	"back": BASE + "icon_back.png",
	"gift": BASE + "icon_gift.png",
	"chest": BASE + "icon_chest.png",
	# این پنج‌تا هنوز SVG دست‌سازند؛ اگر PNGشان آمد فقط همین خط عوض می‌شود
	"lock": BASE + "icon_lock.svg",
	"crown": BASE + "icon_crown.svg",
	"help": BASE + "icon_help.svg",
	"calendar": BASE + "icon_calendar.svg",
	"star": BASE + "icon_star.svg",
	"clock": BASE + "icon_clock.svg",
	"emblem": BASE + "icon_emblem.svg",
}

## آیکنی که وقتی شناسه ناشناخته بود استفاده می‌شود
const FALLBACK := BASE + "icon_match.png"

# ------------------------------------------------------------------- رنگ صفحه
#
# پالت صفحه‌ی ماموریت‌ها — همان پالت MenuUI (سیاه، قرمز، طلایی). قبلاً این
# صفحه سرمه‌ای/آبی بود و با بقیه‌ی منوها نمی‌خواند؛ اسم ثابت‌ها برای سازگاری
# مانده ولی «BLUE» حالا یعنی «اکسنتِ اصلی» (قرمز). طلایی فقط برای جایزه.
# هر جای دیگری از این فایل رنگ بردار، نه از عدد دستی توی صحنه — تا اگر
# تم عوض شد یک جا عوض شود.

const COLOR_BLUE := Color(0.85, 0.043, 0.075, 1.0)       # اکسنت اصلی (قرمز تم)
const COLOR_BLUE_SOFT := Color(1.0, 0.36, 0.38, 1.0)     # اکسنتِ روشن / خط‌های نازک
const COLOR_GOLD := Color(1.0, 0.8, 0.26, 1.0)           # سکه و جایزه (MenuUI.GOLD)
const COLOR_PURPLE := Color(0.66, 0.36, 0.85, 1.0)       # تجربه (XP)
const COLOR_TEXT := Color(0.96, 0.96, 0.97, 1.0)
const COLOR_MUTED := Color(0.62, 0.62, 0.66, 1.0)
const COLOR_DIM := Color(0.42, 0.42, 0.46, 1.0)
const COLOR_RED := Color(0.898, 0.078, 0.169, 1.0)       # بج و هشدار

## رنگ آیکن ماموریت بر حسب حالتش
const COLOR_READY := COLOR_GOLD                          # آماده‌ی دریافت
const COLOR_ACTIVE := Color(0.86, 0.86, 0.88, 1.0)       # در حال انجام
const COLOR_CLAIMED := Color(0.42, 0.42, 0.46, 1.0)      # گرفته شده

## رنگِ عددِ زیر هر صندوق (خود صندوق آرت رنگی است و رنگ نمی‌خورد)
const CHEST_COLORS := {
	"chest_common": Color(0.62, 0.69, 0.78, 1.0),  # نقره‌ای
	"chest_rare": Color(0.66, 0.55, 0.96, 1.0),    # بنفش
	"chest_legend": COLOR_GOLD,                    # طلایی
}

## آیا این جایزه آیتم آرایشی است؟ (اسکین/طرح سلاح — عدد ندارد)
const COSMETIC_ICONS := ["char_skin", "weapon_skin"]

static func is_cosmetic(icon_id: String) -> bool:
	return icon_id.strip_edges().to_lower() in COSMETIC_ICONS

## رنگ رده‌ی صندوق. اگر شناسه ناشناخته بود، نقره‌ای.
static func chest_color(icon_id: String) -> Color:
	var id := icon_id.strip_edges().to_lower()
	if CHEST_COLORS.has(id):
		return CHEST_COLORS[id]
	return CHEST_COLORS["chest_common"]

## شناسه‌هایی که آرت رنگی دارند (نه SVG سفید)
const ART_ICONS := ["coin", "gem", "chest_common", "chest_rare", "chest_legend",
	"char_skin", "weapon_skin"]

## آیا این شناسه آرت رنگی است؟ آرت رنگی نباید modulate رنگی بخورد، وگرنه
## رنگِ تصویر در رنگِ modulate ضرب می‌شود و کثیف درمی‌آید.
static func is_art_icon(icon_id: String) -> bool:
	return icon_id.strip_edges().to_lower() in ART_ICONS

# ------------------------------------------------------------------ آیکن‌ها

## تصویر نمایشی یک اسکین (همان پوشه‌ای که آرت سلاح‌ها و کاراکترها هست).
## اگر پیدا نشد null — صدازننده به آیکن عمومی char_skin/weapon_skin برمی‌گردد.
static func skin_texture(skin_id: String) -> Texture2D:
	var id := skin_id.strip_edges()
	if id.is_empty():
		return null
	for folder in ["res://assets/weapons/", "res://assets/characters/"]:
		var path: String = folder + id + ".png"
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null

## آیکن یک جایزه: اگر اسکین است عکس خودِ اسکین، وگرنه آیکن معمولی
static func reward_texture(reward: Dictionary) -> Texture2D:
	var skin := skin_texture(str(reward.get("skin_id", "")))
	return skin if skin != null else texture_for(str(reward.get("icon", "")))

## تصویر آیکن. اگر فایلش نبود null برمی‌گرداند تا صدازننده جای خالی را مخفی کند.
static func texture_for(icon_id: String) -> Texture2D:
	var path := path_for(icon_id)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

static func path_for(icon_id: String) -> String:
	var id := icon_id.strip_edges().to_lower()
	if BY_ID.has(id):
		return str(BY_ID[id])
	return FALLBACK

# ------------------------------------------------------------------ عددها

## تایمر ریست: ثانیه → "۱۲:۳۴:۵۶"
## عدد از سرور می‌آید (seconds_left)، کلاینت فقط هر ثانیه یکی کم می‌کند.
static func format_countdown(total_seconds: int) -> String:
	if total_seconds < 0:
		total_seconds = 0
	# تقسیم صحیح عمداً است — ساعت و دقیقه‌ی کامل می‌خواهیم
	@warning_ignore("integer_division")
	var hours := total_seconds / 3600
	@warning_ignore("integer_division")
	var minutes := (total_seconds % 3600) / 60
	var seconds := total_seconds % 60
	return "%s:%s:%s" % [_two(hours), _two(minutes), _two(seconds)]

static func _two(value: int) -> String:
	return fa_number(value) if value >= 10 else "۰" + fa_number(value)

## عدد با رقم فارسی (۱۲۳۴۵ → ۱۲۳۴۵ فارسی، بدون جداکننده)
static func fa_number(value: int) -> String:
	const DIGITS := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var digits := str(absi(value))
	var out := ""
	for i in digits.length():
		out += DIGITS[digits[i].to_int()]
	return ("-" if value < 0 else "") + out

## عدد با رقم فارسی و جداکننده‌ی هزارگان (۱۲۳۴۵ → ۱۲٬۳۴۵)
static func fa_grouped(value: int) -> String:
	const DIGITS := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var digits := str(absi(value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = DIGITS[digits[i].to_int()] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "٬" + out
	return ("-" if value < 0 else "") + out
