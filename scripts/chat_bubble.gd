class_name ChatBubble
extends MarginContainer
## یک پیام داخل صفحه‌ی چت.
##
## دیتا را دقیقاً به همان شکلی می‌گیرد که سرور می‌فرستد (چه از تاریخچه‌ی
## GET /chat/history و چه از پیام بلادرنگ WebSocket با type = "chat_message"):
##
##   {message_id, sender_id, sender_name, sender_avatar, sender_level,
##    sender_clan, sender_tier, text, created_at}
##
## چیدمان: آواتار گرد سمت چپ، بالای حباب اسم + تاج + «Lv.»، زیرش حباب متن و
## کنارش ساعت. پیام خودم سمت راست، طلایی‌تیره و بدون آواتار/اسم.
##
## ایموجی‌ها (ChatEmoji): پیامی که فقط ایموجی باشد بزرگ و بدون حباب نشان
## داده می‌شود؛ ایموجی کنار متن کوچک و داخل خط.
##
## همه‌چیزِ حباب mouse_filter = IGNORE است تا کشیدن انگشت مستقیم به
## ScrollContainer برسد — به‌جز آواتار، که با ضربه کارت پروفایل فرستنده را
## باز می‌کند (سیگنال avatar_pressed) و کشیدن را خودش به اسکرول پاس می‌دهد.

## بازیکن روی آواتار فرستنده ضربه زد — چت اصلی کارت پروفایل را باز می‌کند
signal avatar_pressed(data: Dictionary)

## بیشترین عرض حباب نسبت به عرض ستون پیام‌ها
const MAX_WIDTH_RATIO := 0.72
## کمترین عرض متن داخل حباب
const MIN_TEXT_WIDTH := 24.0
## فضای داخلی حباب (چپ + راست)
const BUBBLE_PADDING := 28.0
## اندازه‌ی ایموجی داخل متن و ایموجی تنها
const EMOJI_INLINE := 24
const EMOJI_BIG := 72
## جابه‌جایی بیشتر از این مقدار روی آواتار یعنی اسکرول، نه ضربه
const DRAG_THRESHOLD := 12.0

const COLOR_NAME := Color(0.86, 0.86, 0.9, 1.0)
## V2 طلایی فقط برای رهبر (منزلت)، بقیه‌ی اسم‌ها خنثی
const COLOR_NAME_LEADER := Color(1.0, 0.8, 0.26, 1.0)

@onready var _row: HBoxContainer = $Row
@onready var _avatar_slot: Control = $Row/AvatarSlot
@onready var _avatar: ChatAvatar = $Row/AvatarSlot/Avatar
@onready var _online_dot: Panel = $Row/AvatarSlot/OnlineDot
@onready var _col: VBoxContainer = $Row/Col
@onready var _head: HBoxContainer = $Row/Col/Head
@onready var _name_label: Label = $Row/Col/Head/NameLabel
@onready var _crown: TextureRect = $Row/Col/Head/Crown
@onready var _level_label: Label = $Row/Col/Head/LevelLabel
@onready var _line: HBoxContainer = $Row/Col/Line
@onready var _bubble: PanelContainer = $Row/Col/Line/Bubble
@onready var _text: RichTextLabel = $Row/Col/Line/Bubble/Text
@onready var _big_emoji: HBoxContainer = $Row/Col/Line/BigEmoji
@onready var _time_label: Label = $Row/Col/Line/TimeLabel

## استایل حباب پیام دیگران و پیام خودم
var _style_theirs: StyleBox
@export var style_mine: StyleBox

var message_id: String = ""
var sender_id: String = ""
var created_at: String = ""

var _data: Dictionary = {}
var _is_mine := false
var _is_online := false
var _is_leader := false
var _show_header := true
var _max_width := 420.0
var _avatar_tappable := true
var _scroll: ScrollContainer = null
var _touch_start := Vector2.ZERO
var _is_swiping := false
var _day_pill: PanelContainer = null
var _day_label: Label = null
var _unread_line: HBoxContainer = null
var _day_text := ""
var _unread_divider := false

# ------------------------------------------------------------------ چرخه‌ی حیات

func _ready() -> void:
	_scroll = _find_scroll()
	_avatar.gui_input.connect(_on_avatar_input)
	_style_theirs = _bubble.get_theme_stylebox("panel")
	_build_separators()

	if not _data.is_empty():
		_apply()

## C1/V3 جداکننده‌ها جزوِ خودِ حباب‌اند (نه بچه‌ی جدای لیست) تا ترتیبِ
## «یک حباب برای هر پیام» که chat.gd رویش حساب می‌کند به‌هم نخورد:
##   قرصِ روز («امروز» / «دیروز» / «۴ آبان») بالای اولین پیامِ هر روز
##   خطِ «پیام‌های جدید» بالای اولین پیامِ خوانده‌نشده
func _build_separators() -> void:
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 6)
	remove_child(_row)
	add_child(stack)

	_day_pill = PanelContainer.new()
	_day_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.1, 0.1, 0.11, 0.92)
	pill.border_color = Color(0.3, 0.3, 0.33, 0.8)
	pill.set_border_width_all(1)
	pill.set_corner_radius_all(12)
	pill.content_margin_left = 14
	pill.content_margin_right = 14
	pill.content_margin_top = 2
	pill.content_margin_bottom = 2
	_day_pill.add_theme_stylebox_override("panel", pill)
	_day_label = Label.new()
	_day_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day_label.add_theme_font_override("font", MenuUI.FONT)
	_day_label.add_theme_font_size_override("font_size", 13)
	_day_label.add_theme_color_override("font_color", MenuUI.MUTED)
	_day_pill.add_child(_day_label)
	_day_pill.visible = false
	stack.add_child(_day_pill)

	# خطِ قرمزِ «پیام‌های جدید» — قرمز = چیزی که هنوز ندیده‌ای (V1)
	_unread_line = HBoxContainer.new()
	_unread_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unread_line.add_theme_constant_override("separation", 10)
	for i in 3:
		if i == 1:
			var t := Label.new()
			t.text = "پیام‌های جدید"
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			t.add_theme_font_override("font", MenuUI.FONT)
			t.add_theme_font_size_override("font_size", 13)
			t.add_theme_color_override("font_color", MenuUI.RED_HOT)
			_unread_line.add_child(t)
			continue
		var line := ColorRect.new()
		line.color = Color(MenuUI.RED_HOT, 0.6)
		line.custom_minimum_size = Vector2(0, 2)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_unread_line.add_child(line)
	_unread_line.visible = false
	stack.add_child(_unread_line)
	stack.add_child(_row)

## چت اصلی بعد از setup صدا می‌زند: متنِ قرصِ روز (خالی = بدون قرص) و خطِ خوانده‌نشده
func set_separators(day_text: String, unread_divider: bool) -> void:
	_day_text = day_text
	_unread_divider = unread_divider
	if is_node_ready() and _day_pill != null:
		_day_pill.visible = not day_text.is_empty()
		_day_label.text = day_text
		_unread_line.visible = unread_divider

func has_unread_divider() -> bool:
	return _unread_divider

## V7 پیامِ تازه‌ی بلادرنگ نرم بالا می‌آید (تاریخچه بی‌انیمیشن می‌نشیند)
func pop_in() -> void:
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	_bubble.pivot_offset = Vector2(_bubble.size.x if _is_mine else 0.0, _bubble.size.y)
	_bubble.scale = Vector2(0.9, 0.9)
	_bubble.create_tween().tween_property(_bubble, "scale", Vector2.ONE, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## پر کردن حباب.
##   data        : دیکشنری پیام از سرور
##   is_mine     : پیام خودِ بازیکن است یا نه (سمت راست و رنگ متفاوت)
##   is_online   : فرستنده همین الان آنلاین است یا نه
##   show_header : آواتار و اسم نشان داده شود (برای پیام‌های پشت‌سرهمِ
##                 یک نفر خاموش می‌شود تا لیست شلوغ نشود)
##   is_leader   : فرستنده رهبر شهر است (تاج کنار اسم)
func setup(data: Dictionary, is_mine: bool, is_online: bool, show_header: bool = true, is_leader: bool = false) -> void:
	_data = data
	_is_mine = is_mine
	_is_online = is_online
	_show_header = show_header
	_is_leader = is_leader

	message_id = str(data.get("message_id", ""))
	sender_id = str(data.get("sender_id", ""))
	created_at = str(data.get("created_at", ""))

	if is_node_ready():
		_apply()

## بیشترین عرض مجاز حباب — چت اصلی موقع ساختن ردیف این را ست می‌کند
func set_available_width(width: float) -> void:
	_max_width = maxf(160.0, width * MAX_WIDTH_RATIO)
	if is_node_ready() and not _data.is_empty():
		_resize_text()

func get_data() -> Dictionary:
	return _data

# ------------------------------------------------------------------ نمایش

func _apply() -> void:
	var text := str(_data.get("text", ""))

	_name_label.text = str(_data.get("sender_name", "—"))
	_level_label.text = "Lv.%d" % int(_data.get("sender_level", 1))
	_time_label.text = ChatBubble.short_time(created_at)
	_crown.visible = _is_leader

	# --- پیام فقط ایموجی: بزرگ و بدون حباب ---
	for child in _big_emoji.get_children():
		child.queue_free()
	var only := ChatEmoji.emoji_only_ids(text)
	_bubble.visible = only.is_empty()
	_big_emoji.visible = not only.is_empty()
	for id in only:
		var tex_rect := TextureRect.new()
		tex_rect.texture = ChatEmoji.texture_of(id)
		tex_rect.custom_minimum_size = Vector2(EMOJI_BIG, EMOJI_BIG)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_big_emoji.add_child(tex_rect)

	if only.is_empty():
		var body := ChatEmoji.to_bbcode(text, EMOJI_INLINE)
		# متن فارسی راست‌چین؛ لاتین چپ‌چین (برای پیام‌های چندخطی مهم است)
		if ChatBubble.is_rtl(ChatEmoji.strip(text)):
			body = "[right]%s[/right]" % body
		_text.text = body

	# --- هدر: فقط پیام‌های پشت‌سرهمِ یک نفر هدر تکراری نمی‌گیرند ---
	# (پیام خودم هم آواتار و اسم دارد، فقط سمت راست)
	# پیام خودم مثل پیام‌رسان‌های امروزی بی‌آواتار و بی‌اسم است (C1 شلوغی کمتر)
	var header := _show_header and not _is_mine
	_head.visible = header
	_avatar_slot.visible = not _is_mine
	_avatar.visible = header
	_online_dot.visible = header and _is_online
	if header:
		_avatar.set_avatar(str(_data.get("sender_avatar", "")))
		_avatar.set_ring(ChatAvatar.RING_GOLD if _is_leader else ChatAvatar.RING_DEFAULT)
	# V3 مجاورت: پیام‌های پشت‌سرهمِ یک نفر به هم نزدیک‌ترند
	add_theme_constant_override("margin_top", 6 if _show_header else 1)
	add_theme_constant_override("margin_bottom", 1)
	set_separators(_day_text, _unread_divider)

	# روی آواتار خودت زدن معنی ندارد (نه دوستی، نه پروفایل غریبه)
	_avatar_tappable = header and not _is_mine
	_avatar.mouse_filter = Control.MOUSE_FILTER_STOP if _avatar_tappable else Control.MOUSE_FILTER_IGNORE

	_apply_side()
	_resize_text()

## پیام خودم سمت راست (آواتار راست، ساعت چپِ حباب)، بقیه سمت چپ
func _apply_side() -> void:
	_bubble.add_theme_stylebox_override("panel",
		style_mine if _is_mine and style_mine != null else _style_theirs)
	var align := BoxContainer.ALIGNMENT_END if _is_mine else BoxContainer.ALIGNMENT_BEGIN
	_line.alignment = align
	_head.alignment = align
	_name_label.add_theme_color_override("font_color", COLOR_NAME_LEADER if _is_leader else COLOR_NAME)
	_text.add_theme_color_override("default_color",
		Color(1.0, 0.95, 0.84, 1.0) if _is_mine else Color(0.95, 0.95, 0.96, 1.0))
	if _is_mine:
		_row.move_child(_avatar_slot, _row.get_child_count() - 1)
		_line.move_child(_time_label, 0)
	else:
		_row.move_child(_avatar_slot, 0)
		_line.move_child(_time_label, _line.get_child_count() - 1)

## عرض متن به اندازه‌ی خودش (تا سقف مجاز) — پیام کوتاه حباب کوچک می‌گیرد
## و پیام بلند درست می‌شکند. RichTextLabel با fit_content ارتفاع را خودش
## از روی همین عرض حساب می‌کند.
func _resize_text() -> void:
	if not _bubble.visible:
		return
	var font := _text.get_theme_font("normal_font")
	var font_size := _text.get_theme_font_size("normal_font_size")
	if font == null:
		return

	var raw := str(_data.get("text", ""))
	var width := font.get_string_size(ChatEmoji.strip(raw), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	width += ChatEmoji.count(raw) * (EMOJI_INLINE + 4)
	var limit := _max_width - BUBBLE_PADDING
	_text.custom_minimum_size.x = clampf(ceilf(width) + 2.0, MIN_TEXT_WIDTH, limit)

## متن با حرف فارسی/عربی شروع می‌شود؟
static func is_rtl(text: String) -> bool:
	for i in text.length():
		var c := text.unicode_at(i)
		if (c >= 0x0600 and c <= 0x06FF) or (c >= 0xFB50 and c <= 0xFEFF):
			return true
		if (c >= 0x41 and c <= 0x5A) or (c >= 0x61 and c <= 0x7A):
			return false
	return false

# ------------------------------------------------------------------ لمس آواتار

## نزدیک‌ترین ScrollContainer بالادستی — کشیدن انگشت به آن پاس داده می‌شود
func _find_scroll() -> ScrollContainer:
	var node: Node = get_parent()
	while node != null:
		if node is ScrollContainer:
			return node
		node = node.get_parent()
	return null

## ضربه روی آواتار = باز کردن کارت پروفایل، کشیدن = اسکرول لیست.
## فقط رویداد تاچ (ماوسِ شبیه‌سازی‌شده از تاچ نادیده گرفته می‌شود تا
## ضربه دو بار ثبت نشود؛ روی PC هم emulate_touch_from_mouse روشن است).
func _on_avatar_input(event: InputEvent) -> void:
	if not _avatar_tappable:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_is_swiping = false
			UIFx.press_scale(_avatar, true)
		else:
			UIFx.press_scale(_avatar, false)
			if not _is_swiping:
				avatar_pressed.emit(_data)
		return

	if event is InputEventScreenDrag:
		if event.position.distance_to(_touch_start) > DRAG_THRESHOLD:
			if not _is_swiping:
				UIFx.press_scale(_avatar, false)
			_is_swiping = true
		if _is_swiping and _scroll != null:
			_scroll.scroll_vertical -= int(event.relative.y)

# ------------------------------------------------------------------ زمان

## تبدیل رشته‌ی RFC3339 سرور به ثانیه‌ی یونیکس (با احتساب اختلاف ساعت سرور).
## اگر رشته خراب باشد صفر برمی‌گرداند.
static func iso_to_unix(iso: String) -> int:
	if iso.is_empty():
		return 0

	var text := iso.strip_edges()
	var offset_seconds := 0

	# جدا کردن منطقه‌ی زمانی: Z یا ±HH:MM در انتهای رشته
	if text.ends_with("Z") or text.ends_with("z"):
		text = text.substr(0, text.length() - 1)
	else:
		# فقط بعد از 'T' دنبال علامت می‌گردیم تا خط‌تیره‌های تاریخ گیر نکنند
		var t_index := text.find("T")
		if t_index != -1:
			var sign_index := maxi(text.rfind("+"), text.rfind("-"))
			if sign_index > t_index:
				var zone := text.substr(sign_index + 1)
				var parts := zone.split(":")
				var hours := int(parts[0]) if parts.size() > 0 else 0
				var minutes := int(parts[1]) if parts.size() > 1 else 0
				offset_seconds = hours * 3600 + minutes * 60
				if text[sign_index] == "-":
					offset_seconds = -offset_seconds
				text = text.substr(0, sign_index)

	# بریدن کسر ثانیه — Godot آن را نمی‌پذیرد
	var dot_index := text.find(".")
	if dot_index != -1:
		text = text.substr(0, dot_index)

	var unix := int(Time.get_unix_time_from_datetime_string(text))
	if unix == 0:
		return 0
	return unix - offset_seconds

## ساعت پیام به وقت محلیِ خود گوشی، به شکل «۱۴:۰۵»
static func short_time(iso: String) -> String:
	var unix := ChatBubble.iso_to_unix(iso)
	if unix == 0:
		return ""
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var local: int = unix + bias * 60
	var dict := Time.get_datetime_dict_from_unix_time(local)
	return "%02d:%02d" % [int(dict["hour"]), int(dict["minute"])]

## فاصله‌ی زمانی به فارسی برای لیست گفتگوها («الان»، «۵ دقیقه پیش»، ...)
static func relative_time(iso: String) -> String:
	var unix := ChatBubble.iso_to_unix(iso)
	if unix == 0:
		return ""

	var seconds := int(Time.get_unix_time_from_system()) - unix
	if seconds < 60:
		return "الان"
	if seconds < 3600:
		return "%d دقیقه پیش" % int(seconds / 60.0)
	if seconds < 86400:
		return "%d ساعت پیش" % int(seconds / 3600.0)
	if seconds < 604800:
		return "%d روز پیش" % int(seconds / 86400.0)
	return ChatBubble.short_time(iso)

## «آفلاین (۲ ساعت قبل)» برای ستون آنلاین‌ها — مثل طرح
static func last_seen_text(iso: String) -> String:
	var unix := ChatBubble.iso_to_unix(iso)
	if unix == 0:
		return "آفلاین"
	var seconds := int(Time.get_unix_time_from_system()) - unix
	if seconds < 3600:
		return "آفلاین (%d دقیقه قبل)" % maxi(1, int(seconds / 60.0))
	if seconds < 86400:
		return "آفلاین (%d ساعت قبل)" % int(seconds / 3600.0)
	return "آفلاین (%d روز قبل)" % int(seconds / 86400.0)

# ------------------------------------------------------------------ روز

const FA_MONTHS := ["فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور",
	"مهر", "آبان", "آذر", "دی", "بهمن", "اسفند"]

## روزِ محلیِ یک لحظه (برای مقایسه‌ی «همان روز»): شماره‌ی روز از مبدأ یونیکس
static func local_day(unix: int) -> int:
	if unix <= 0:
		return 0
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	@warning_ignore("integer_division")
	return (unix + bias * 60) / 86400

## C1 قرصِ روزِ گفتگو: «امروز»، «دیروز» یا «۴ آبان» (تقویم شمسی)
static func day_label(unix: int) -> String:
	if unix <= 0:
		return ""
	var day := ChatBubble.local_day(unix)
	var now := int(Time.get_unix_time_from_system())
	var today := ChatBubble.local_day(now)
	if day == today:
		return "امروز"
	if day == today - 1:
		return "دیروز"
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var d := Time.get_datetime_dict_from_unix_time(unix + bias * 60)
	var j := ChatBubble.to_jalali(int(d["year"]), int(d["month"]), int(d["day"]))
	var text := "%s %s" % [MissionArt.fa_number(j.z), FA_MONTHS[clampi(j.y - 1, 0, 11)]]
	var n := Time.get_datetime_dict_from_unix_time(now + bias * 60)
	if j.x != ChatBubble.to_jalali(int(n["year"]), int(n["month"]), int(n["day"])).x:
		text += " " + MissionArt.fa_number(j.x)
	return text

## میلادی → شمسی (الگوریتم jalaali). خروجی: (سال، ماه، روز)
static func to_jalali(gy: int, gm: int, gd: int) -> Vector3i:
	var g_d_m := [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
	var gy2 := gy + 1 if gm > 2 else gy
	@warning_ignore("integer_division")
	var days := 355666 + 365 * gy + (gy2 + 3) / 4 - (gy2 + 99) / 100 + (gy2 + 399) / 400 + gd + int(g_d_m[gm - 1])
	@warning_ignore("integer_division")
	var jy := -1595 + 33 * (days / 12053)
	days = days % 12053
	@warning_ignore("integer_division")
	jy += 4 * (days / 1461)
	days = days % 1461
	if days > 365:
		@warning_ignore("integer_division")
		jy += (days - 1) / 365
		days = (days - 1) % 365
	var jm := 0
	var jd := 0
	if days < 186:
		@warning_ignore("integer_division")
		jm = 1 + days / 31
		jd = 1 + days % 31
	else:
		@warning_ignore("integer_division")
		jm = 7 + (days - 186) / 30
		jd = 1 + (days - 186) % 30
	return Vector3i(jy, jm, jd)
