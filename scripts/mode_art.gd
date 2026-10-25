class_name ModeArt
extends RefCounted
## هنرِ هر مودِ بازی در یک جا: رنگ، نشان، تصویرِ کارت و جمله‌ی کوتاهِ کارت.
##
## رنگِ کارت از نشانِ خودِ مود می‌آید (آبی/قرمز/بنفش/طلایی)، نه از سرور —
## نشان‌ها تمام‌رنگ‌اند و اگر رنگِ قاب با نشان نخواند کارت به‌هم‌ریخته
## دیده می‌شود. برای مودِ تازه‌ای که اینجا نیست، رنگِ سرور (`accent`) می‌ماند.
##
## فایل‌ها (همه در assets/ui/modes/):
##   <id>.png       نشانِ مود (لوگو)
##   <id>_art.png   تصویرِ عمودیِ بالای کارت (اختیاری — نبود، شیبِ رنگی کشیده می‌شود)

const DIR := "res://assets/ui/modes/"

const ACCENTS := {
	"strike": Color("#2EA6FF"),
	"revenge": Color("#F0342E"),
	"banish": Color("#A34DFF"),
	"citypoint": Color("#F5B42A"),
}

## جمله‌ی کوتاهِ کارت. توضیحِ کاملِ سرور برای کارت زیادی بلند است و در
## پنجره‌ی راهنما نشان داده می‌شود.
const TAGLINES := {
	"strike": "تیم خود را انتخاب کنید و در نبرد ۴ در مقابل ۴ برای پیروزی بجنگید.",
	"revenge": "مهارت و واکنش خود را در نبرد ۱ در مقابل ۱ به چالش بکشید.",
	"banish": "شیطان وسط نقشه ایستاده. هر تیمی بیشتر به او ضربه بزند، برنده است.",
	"citypoint": "نقاط کلیدی را تصاحب کنید و بیشترین امتیاز را در نبرد ۳ در مقابل ۳ کسب کنید.",
}


static func accent(mode: Dictionary) -> Color:
	var id := str(mode.get("mode_id", ""))
	if ACCENTS.has(id):
		return ACCENTS[id]
	var raw := str(mode.get("accent", ""))
	return Color(raw) if raw.is_valid_html_color() else Color("#F0B429")


static func tagline(mode: Dictionary) -> String:
	return TAGLINES.get(str(mode.get("mode_id", "")), str(mode.get("description", "")))


## نشانِ تمام‌رنگ؛ اگر نبود SVGِ تک‌رنگِ قدیمی (که باید تینت شود).
static func emblem(mode_id: String) -> Texture2D:
	for ext in [".png", ".svg"]:
		var path: String = DIR + mode_id + ext
		if ResourceLoader.exists(path):
			return load(path)
	return null


static func card_art(mode_id: String) -> Texture2D:
	var path := DIR + mode_id + "_art.png"
	return load(path) if ResourceLoader.exists(path) else null

