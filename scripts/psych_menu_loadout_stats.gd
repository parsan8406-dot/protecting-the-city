extends RefCounted
## آمارِ شخصیِ هر اسلحه/کاراکتر، روی خودِ دستگاه.
##
## E8 مالکیت/ایکیا: «با این اسلحه ۱۲ مسابقه و ۴۰ کیل داری» — سرور آمارِ
## تفکیکی ندارد، پس همین‌جا (user://) و به تفکیکِ حساب نگه داشته می‌شود.
## فقط برای نمایش است و هیچ پاداشی به آن وصل نیست.
##
## مسابقه‌ها را matchmaking.gd و quick_play.gd ثبت می‌کنند (همان لحظه‌ی
## ورود به زمین، با اسلحه و کاراکترِ تجهیزشده). کیل‌ها از گیم‌پلی می‌آیند:
##   preload("res://scripts/psych_menu_loadout_stats.gd").record_kills(n)
## (با همان اسلحه/کاراکترِ تجهیزشده‌ی Global ثبت می‌شود)

const PATH := "user://psych_loadout_stats.cfg"


static func _key(category: String, item_id: String) -> String:
	return "%s:%s" % [category, item_id]


static func _section() -> String:
	var user := str(Global.my_username).strip_edges()
	return user if user != "" else "_guest"


static func _bump(field: String, amount: int) -> void:
	if amount <= 0:
		return
	var cfg := ConfigFile.new()
	cfg.load(PATH)   # نبودنِ فایل یعنی هنوز آماری نیست
	var sec := _section()
	for pair in [["weapon", str(Global.current_weapon)], ["character", str(Global.current_character)]]:
		if str(pair[1]).strip_edges() == "":
			continue
		var key: String = _key(pair[0], pair[1]) + ":" + field
		cfg.set_value(sec, key, int(cfg.get_value(sec, key, 0)) + amount)
	cfg.save(PATH)


## یک مسابقه با اسلحه و کاراکترِ تجهیزشده‌ی فعلی
static func record_match() -> void:
	_bump("matches", 1)


## کیل‌های بازیکن با اسلحه و کاراکترِ تجهیزشده‌ی فعلی
static func record_kills(count: int = 1) -> void:
	_bump("kills", count)


static func get_stats(category: String, item_id: String) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return {"matches": 0, "kills": 0}
	var sec := _section()
	var base := _key(category, item_id)
	return {
		"matches": int(cfg.get_value(sec, base + ":matches", 0)),
		"kills": int(cfg.get_value(sec, base + ":kills", 0)),
	}


## «۱۲ مسابقه · ۴۰ کیل با این اسلحه» — خالی یعنی هنوز چیزی نیست
static func summary(category: String, item_id: String) -> String:
	var s := get_stats(category, item_id)
	var parts: Array[String] = []
	if int(s["matches"]) > 0:
		parts.append("%s مسابقه" % MissionArt.fa_grouped(int(s["matches"])))
	if int(s["kills"]) > 0:
		parts.append("%s کیل" % MissionArt.fa_grouped(int(s["kills"])))
	if parts.is_empty():
		return ""
	var noun := "این اسلحه" if category == "weapon" else "این کاراکتر"
	return "با %s: %s" % [noun, " · ".join(parts)]
