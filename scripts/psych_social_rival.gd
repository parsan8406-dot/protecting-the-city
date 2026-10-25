extends RefCounted
## E9 مقایسه‌ی اجتماعی + E5 نزدیک‌برد — «چند نفر بالا و پایینِ تو» در جدول.
##
## سرور فقط صفحه‌بندی دارد (GET /leaderboard?page=&limit=، skip = page*limit)
## و پارامتری مثل around=me ندارد. پس پنجره‌ی دور و بر بازیکن را با یک
## درخواست عادی می‌گیریم: یک limit (بین سقف پایین و ۵۰) پیدا می‌کنیم که
## صفحه‌ای از آن کل بازه‌ی [رتبه‌ی من - بالا، رتبه‌ی من + پایین] را در بر بگیرد.
## برای هر رتبه‌ای تا میلیون‌ها چنین limitی وجود دارد (با اسکریپت چک شد).
##
## هیچ عددی این‌جا ساخته نمی‌شود — فقط فاصله‌ی دو امتیازی که سرور داده.

## سقف limit سرور (LeaderboardMaxLimit در handlers_leaderboard.go)
const SERVER_MAX_LIMIT := 50

## فاصله‌ای که «نزدیک» حساب می‌شود (حدود یکی دو برد)
const NEAR_GAP := 30

const COLOR_GOLD := Color(0.97, 0.78, 0.3, 1.0)
const COLOR_GREEN := Color(0.45, 0.85, 0.5, 1.0)


## صفحه و اندازه‌ی صفحه‌ای که رتبه‌های pos-above تا pos+below را با هم دارد.
## خروجی Vector2i(page, limit)؛ اگر پیدا نشد (0, 0).
static func window_request(pos: int, above: int, below: int) -> Vector2i:
	if pos <= 0:
		return Vector2i.ZERO
	var first := maxi(pos - 1 - above, 0)   # اندیس صفرمبنا
	var last := pos - 1 + below
	var need := last - first + 1
	for limit in range(need, SERVER_MAX_LIMIT + 1):
		@warning_ignore("integer_division")
		var page := first / limit
		if page * limit + limit - 1 >= last:
			return Vector2i(page, limit)
	return Vector2i.ZERO


## از ردیف‌های یک صفحه فقط بازه‌ی دور و بر pos را برمی‌دارد
static func slice_around(entries: Array, pos: int, above: int, below: int) -> Array:
	var out: Array = []
	for e in entries:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var p := int((e as Dictionary).get("position", 0))
		if p >= pos - above and p <= pos + below:
			out.append(e)
	return out


## ردیف با رتبه‌ی مشخص (یا دیکشنری خالی)
static func entry_at(entries: Array, pos: int) -> Dictionary:
	for e in entries:
		if typeof(e) == TYPE_DICTIONARY and int((e as Dictionary).get("position", 0)) == pos:
			return e
	return {}


static func _display_name(entry: Dictionary) -> String:
	var n := str(entry.get("username", entry.get("name", "")))
	return n if not n.is_empty() else "نفر بالایی"


## متن یک‌خطی «رقیب بعدی». unit = «کاپ» یا «امتیاز».
## [متن، رنگ] — رنگ طلایی یعنی هدف/پاداش، سبز یعنی «تو جلویی» (مثبت، بدون شرم‌سازی)
static func rival_line(me: Dictionary, above: Dictionary, below: Dictionary, unit: String) -> Array:
	var pos := int(me.get("position", 0))
	if pos <= 0:
		return ["", COLOR_GOLD]
	var mine := int(me.get("points", 0))
	if pos == 1:
		if below.is_empty():
			return ["تو صدرنشین جدولی!", COLOR_GOLD]
		var lead := maxi(mine - int(below.get("points", 0)), 0)
		if lead <= 0:
			return ["تو صدرنشینی! نفر دوم هم‌امتیازته", COLOR_GOLD]
		return ["تو صدرنشینی! %s %s جلوتر از نفر دوم" % [MissionArt.fa_grouped(lead), unit], COLOR_GREEN]
	if above.is_empty():
		return ["", COLOR_GOLD]
	# برای رد شدن از نفر بالایی یک واحد بیشتر از او لازم است (ترتیب برابرها با آیدی است)
	var gap := maxi(int(above.get("points", 0)) - mine + 1, 1)
	# «فقط» فقط وقتی واقعاً نزدیک است — اغراق نمی‌کنیم
	# اسم لاتین آخر جمله تا ترتیب راست‌به‌چپ به هم نریزد
	var text := "▲ %s%s %s تا رتبه‌ی %s — رد شدن از %s" % [
		"فقط " if gap <= NEAR_GAP else "", MissionArt.fa_grouped(gap), unit,
		MissionArt.fa_number(pos - 1), _display_name(above)]
	return [text, COLOR_GOLD]
