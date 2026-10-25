extends RefCounted
## نکته‌های کوتاهِ گیم‌پلی برای صفحه‌ی بارگذاری و صفِ مسابقه.
##
## C12 Doherty: انتظار با یک چیزِ مفید پر می‌شود، نه با نوارِ خالی.
## C7 داربست: هر نکته فقط یک مکانیک — و همه‌شان واقعاً در همین بازی هستند
## (عددها از abilities.gd / player.gd / ammo_box.gd). اگر مکانیکی عوض شد،
## نکته‌اش را هم این‌جا عوض کن.
##
## آیکن‌ها اختیاری‌اند: اگر assets/ui/psych/tip_*.png هنوز نرسیده باشد،
## از آیکن‌های موجودِ HUD استفاده می‌شود و اگر آن هم نبود، فقط متن.

const PSYCH_DIR := "res://assets/ui/psych/"

## [متن، آیکنِ اصلی (psych)، آیکنِ جایگزین]
const TIPS := [
	["پشتِ دیوار سنگر بگیر — بدونِ دیدِ مستقیم، کسی نمی‌تواند تو را بزند.",
		"tip_cover", "res://assets/ui/hud/icon_shield.png"],
	["خشابِ خالی خودش پر می‌شود؛ از روی جعبه‌ی فشنگ رد شو تا فوراً پر شود.",
		"tip_reload", "res://assets/ui/hud/icon_bullet.png"],
	["سه نارنجک داری؛ برای بیرون کشیدنِ حریف از پشتِ سنگر نگهشان دار.",
		"tip_grenade", "res://assets/ui/hud/icon_bomb.png"],
	["هر اسلحه بردِ مؤثرِ خودش را دارد؛ شلیک به هدفِ دورتر فقط فشنگ هدر می‌دهد.",
		"", "res://assets/ui/hud/icon_bullet.png"],
	["دکمه‌ی دویدن چند ثانیه سرعتت را بیشتر می‌کند — برای رسیدن به سنگر عالی است.",
		"", "res://assets/ui/hud/icon_run.png"],
	["بعد از زنده شدن چند لحظه سپر داری؛ از همین فرصت برای جاگیری استفاده کن.",
		"", "res://assets/ui/hud/icon_shield.png"],
	["حریف فقط وقتی نزدیکت باشد روی نقشه‌ی کوچک دیده می‌شود.",
		"", "res://assets/ui/hud/icon_people.png"],
	["جانت کم شد؟ دکمه‌ی درمان را بزن و تا آماده شدنِ دوباره‌اش عقب بکش.",
		"", "res://assets/ui/hud/icon_heal.png"],
	["کاراکترت را در «انتخاب آیتم‌ها» با سکه ارتقا بده تا قوی‌تر شود.",
		"", ""],
	["با هر برد کاپ می‌گیری و رتبه‌ات بالا می‌رود.",
		"", ""],
]


## ترتیبِ تصادفی، تا هر بار با یک نکته‌ی تازه شروع شود
static func shuffled() -> Array:
	var order: Array = []
	for i in TIPS.size():
		order.append(i)
	order.shuffle()
	return order


static func text(i: int) -> String:
	return str(TIPS[i % TIPS.size()][0])


## آیکنِ نکته یا null (آن‌وقت TextureRect پنهان می‌شود)
static func icon(i: int) -> Texture2D:
	var row: Array = TIPS[i % TIPS.size()]
	var main := str(row[1])
	if main != "":
		var path := PSYCH_DIR + main + ".png"
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	var fallback := str(row[2])
	if fallback != "" and ResourceLoader.exists(fallback):
		return load(fallback) as Texture2D
	return null


## آیکنِ رنگیِ اختصاصی آمده (نه آیکنِ تک‌رنگِ HUD)؟ — رنگ‌آمیزی فقط روی دومی
static func has_art(i: int) -> bool:
	var main := str(TIPS[i % TIPS.size()][1])
	return main != "" and ResourceLoader.exists(PSYCH_DIR + main + ".png")
