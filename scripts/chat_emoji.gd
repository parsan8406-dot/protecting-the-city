class_name ChatEmoji
extends RefCounted
## ایموجی‌های اختصاصی چت.
##
## هر ایموجی یک عکس در assets/chat/emojies است (emoji_01.png, emoji_02.png, ...)
## و داخل متن پیام به شکل یک توکن کوتاه ذخیره می‌شود: «:e01:». سرور چیزی از
## ایموجی نمی‌داند — فقط متن را نگه می‌دارد — و کلاینت موقع نمایش توکن‌ها را
## به عکس تبدیل می‌کند.
##
## قانون نمایش:
##   - پیامی که فقط ایموجی است (بدون متن)  → عکس بزرگ، بدون حباب
##   - ایموجی کنار متن                     → عکس کوچک داخل خط
##
## عکس خام‌ها در assets/chat/emojies_src هستند (Godot ایمپورتشان نمی‌کند) و
## tools/prepare_chat_emojis.py نسخه‌ی سبک بازی را از روی آن‌ها می‌سازد.

const DIR := "res://assets/chat/emojies"
const PREFIX := "emoji_"
## بیشترین تعداد ایموجیِ تنها که هنوز «بزرگ» نمایش داده می‌شود
const MAX_BIG := 3

static var _ids: Array[String] = []
static var _regex: RegEx = null

## آیدی همه‌ی ایموجی‌ها به ترتیب («01»، «02»، ...)
static func list_ids() -> Array[String]:
	if not _ids.is_empty():
		return _ids

	var dir := DirAccess.open(DIR)
	if dir == null:
		push_warning("پوشه‌ی ایموجی‌ها پیدا نشد: " + DIR)
		return _ids

	for file_name in dir.get_files():
		# توی بیلد اکسپورت‌شده فایل‌ها پسوند اضافه دارن (.import / .remap)
		var clean := file_name.trim_suffix(".import").trim_suffix(".remap")
		if not clean.begins_with(PREFIX) or clean.get_extension().to_lower() != "png":
			continue
		var id := clean.get_basename().trim_prefix(PREFIX)
		if not _ids.has(id):
			_ids.append(id)

	_ids.sort()
	return _ids

static func path_of(id: String) -> String:
	return "%s/%s%s.png" % [DIR, PREFIX, id]

static func texture_of(id: String) -> Texture2D:
	var path := path_of(id)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

## توکنی که داخل متن پیام نوشته می‌شود
static func token(id: String) -> String:
	return ":e%s:" % id

static func _pattern() -> RegEx:
	if _regex == null:
		_regex = RegEx.new()
		_regex.compile(":e(\\d{2,3}):")
	return _regex

## اگر پیام فقط از ایموجی تشکیل شده باشد (حداکثر MAX_BIG تا) آیدی‌هایشان
## را برمی‌گرداند؛ وگرنه آرایه‌ی خالی — یعنی پیام معمولی است.
static func emoji_only_ids(text: String) -> Array[String]:
	var ids: Array[String] = []
	var matches := _pattern().search_all(text)
	if matches.is_empty() or matches.size() > MAX_BIG:
		return ids

	var rest := _pattern().sub(text, "", true).strip_edges()
	if not rest.is_empty():
		return ids

	for m in matches:
		var id := m.get_string(1)
		if not ResourceLoader.exists(path_of(id)):
			ids.clear()
			return ids
		ids.append(id)
	return ids

## تعداد توکن‌های ایموجی داخل متن
static func count(text: String) -> int:
	return _pattern().search_all(text).size()

## متن بدون توکن‌ها — برای اندازه‌گیری عرض و تشخیص جهت (فارسی/لاتین)
static func strip(text: String) -> String:
	return _pattern().sub(text, "", true)

## متن پیام → BBCode برای RichTextLabel. متن کاربر اول escape می‌شود تا
## کسی نتواند با نوشتن [img] یا [url] در چت چیزی تزریق کند.
static func to_bbcode(text: String, size: int) -> String:
	var safe := text.replace("[", "[lb]")
	var out := ""
	var last := 0
	for m in _pattern().search_all(safe):
		out += safe.substr(last, m.get_start() - last)
		var path := path_of(m.get_string(1))
		if ResourceLoader.exists(path):
			out += "[img=%dx%d]%s[/img]" % [size, size, path]
		else:
			out += m.get_string()
		last = m.get_end()
	out += safe.substr(last)
	return out

## متن کوتاه برای پیش‌نمایش (لیبل ساده نمی‌تواند عکس نشان دهد)
static func preview(text: String) -> String:
	return _pattern().sub(text, "(ایموجی)", true).strip_edges()
