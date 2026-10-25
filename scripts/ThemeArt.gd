extends Object
class_name ThemeArt
## تم‌های ظاهریِ زمین — بک‌گراند، سه بافتِ دیوار و سه بافتِ مانع برای هر تم.
##
## هر تم یک پوشه در assets/themes/ است با همین هفت فایل:
##   background.png, wall_1..3.png, obstacle_1..3.png
##
## انتخابِ تم با سرور است (gun_game_server/themes.go): تمِ هر مسابقه از
## بالاترین رنکِ بازیکن‌هایش می‌آید و در پیامِ spawn و خودِ مسابقه می‌رسد.
## جدولِ RANK_THEMES اینجا فقط برای جاهایی است که مسابقه‌ای در کار نیست —
## بک‌گراندِ صفحه‌ی انتخابِ حالت و تمرینِ آفلاین — و باید با rankThemesِ
## سرور یکی بماند.

const BASE := "res://assets/themes/"

## شناسه‌ی تم (همان که سرور می‌فرستد) → پوشه
const FOLDERS := {
	"hell": "01_hell",
	"heaven": "02_heaven",
	"ocean": "03_ocean",
	"ice": "04_ice",
	"pirate_ship": "05_pirate_ship",
	"magic": "06_magic",
	"underworld": "07_underworld",
}

## رنک → تم‌های ممکن. چندتایی یعنی به‌تصادف یکی.
const RANK_THEMES := {
	"bronze": ["hell"],
	"silver": ["heaven"],
	"gold": ["ocean"],
	"platinum": ["ice"],
	"diamond": ["pirate_ship"],
	"legend": ["magic", "underworld"],
}

const DEFAULT_THEME := "hell"

## درخششِ HDRِ پیکسل‌های نارنجی-قرمزِ روشنِ بافت (wall_tiles.gdshader).
## فقط برای مذابِ تمِ جهنمی ساخته شده؛ روی دیوارهای شنیِ دریایی، کرمیِ
## بهشتی و طلاییِ کشتی همان پیکسل‌ها «روشنِ گرم»اند و کلِ دیوار می‌سوزد.
const LAVA_GLOW := {"hell": 1.5}

## رنگِ برگ‌هایی که بادِ زمین می‌آورد (scripts/wind.gd): [رنگِ تازه، رنگِ پژمرده].
## خودِ بافتِ برگ خاکستریِ خنثی است، پس رنگ کاملاً از اینجا می‌آید و هر تم
## برگِ خودش را دارد. Arena این‌ها را در تاریکیِ محیط ضرب می‌کند.
const LEAF_COLORS := {
	"hell":        [Color(0.98, 0.46, 0.18), Color(0.52, 0.13, 0.06)],  # سوخته
	"heaven":      [Color(1.00, 0.93, 0.66), Color(0.80, 0.64, 0.32)],  # طلاییِ روشن
	"ocean":       [Color(0.58, 0.88, 0.72), Color(0.18, 0.50, 0.48)],  # سبزِ دریایی
	"ice":         [Color(0.84, 0.93, 1.00), Color(0.50, 0.67, 0.90)],  # یخ‌زده
	"pirate_ship": [Color(0.88, 0.68, 0.38), Color(0.44, 0.28, 0.13)],  # خشک و چوبی
	"magic":       [Color(0.80, 0.60, 1.00), Color(0.38, 0.20, 0.66)],  # بنفشِ جادویی
	"underworld":  [Color(0.82, 0.26, 0.26), Color(0.30, 0.07, 0.11)],  # سرخِ تیره
}


## یکی از تم‌های این رنک. رنکِ ناشناخته = تمِ پیش‌فرض.
static func theme_for_rank(rank_id: String) -> String:
	var opts: Array = RANK_THEMES.get(rank_id, [])
	if opts.is_empty():
		return DEFAULT_THEME
	return str(opts.pick_random())


## تمِ معتبر یا پیش‌فرض — ورودی از سرور می‌آید و ممکن است خالی یا ناشناخته باشد.
static func sanitize(theme: String) -> String:
	return theme if FOLDERS.has(theme) else DEFAULT_THEME


static func lava_glow(theme: String) -> float:
	return float(LAVA_GLOW.get(sanitize(theme), 0.0))


static func background(theme: String) -> Texture2D:
	return _tex(theme, "background")


## سه بافتِ دیوار، به ترتیب
static func walls(theme: String) -> Array[Texture2D]:
	return _load_set(theme, "wall")


## سه بافتِ مانع، به ترتیب
static func obstacles(theme: String) -> Array[Texture2D]:
	return _load_set(theme, "obstacle")


static func _load_set(theme: String, prefix: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in range(1, 4):
		var t := _tex(theme, "%s_%d" % [prefix, i])
		if t != null:
			out.append(t)
	return out


static func _tex(theme: String, name: String) -> Texture2D:
	var path := "%s%s/%s.png" % [BASE, FOLDERS[sanitize(theme)], name]
	if not ResourceLoader.exists(path):
		push_warning("ThemeArt: فایل نیست: " + path)
		return null
	return load(path) as Texture2D


## دو رنگِ برگِ این تم: [تازه، پژمرده]. برگ در طولِ عمرش از اولی به دومی می‌رود.
static func leaf_colors(theme: String) -> Array:
	var c: Array = LEAF_COLORS.get(sanitize(theme), [])
	if c.size() != 2:
		return [Color(0.86, 0.72, 0.42), Color(0.42, 0.26, 0.14)]
	return c
