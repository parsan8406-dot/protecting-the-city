extends RefCounted
## E10 عمل متقابل / E16 عادت — «هدیه‌ی روزانه‌ات آماده است».
##
## سرور هر ۲۴ ساعت یک هدیه اجازه می‌دهد (GiftCooldown در handlers_social.go) و
## در /friends زمانِ هدیه‌ی بعدی را نمی‌فرستد؛ پس بعد از هر ارسال موفق همین‌جا
## روی گوشی (به تفکیک حساب) یادداشت می‌کنیم. این فقط یک یادآوری مثبت است —
## تصمیم نهایی همیشه با سرور است (کد ۴۲۹)، و دکمه هیچ‌وقت قفل نمی‌شود.

const SAVE_PATH := "user://psych_social.cfg"
## باید با GiftCooldown سرور یکی باشد
const COOLDOWN_SEC := 24 * 3600

## آیکن هدیه (هنر تازه)؛ اگر نبود، دکمه بی‌آیکن می‌ماند
const ICON_PATH := "res://assets/ui/psych/social_gift.png"
const SQUAD_ICON_PATH := "res://assets/ui/psych/social_squad.png"


static func _key() -> String:
	return str(Global.my_username)


## بعد از ارسال موفق هدیه
static func record_sent() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("gift_next", _key(), int(Time.get_unix_time_from_system()) + COOLDOWN_SEC)
	cfg.save(SAVE_PATH)


## ثانیه تا هدیه‌ی بعدی؛ ۰ یعنی آماده (یا خبری نداریم ⇒ آماده فرض می‌شود)
static func seconds_until_next() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 0
	var at := int(cfg.get_value("gift_next", _key(), 0))
	return maxi(at - int(Time.get_unix_time_from_system()), 0)


## متن دکمه‌ی هدیه: آماده ⇒ «هدیه‌ی امروز»، وگرنه چند ساعت مانده
static func button_text() -> String:
	var left := seconds_until_next()
	if left <= 0:
		return "هدیه‌ی امروز"
	@warning_ignore("integer_division")
	var hours := maxi(left / 3600, 1)
	return "هدیه (%s ساعت)" % MissionArt.fa_number(hours)


static func load_icon(path: String = ICON_PATH) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
