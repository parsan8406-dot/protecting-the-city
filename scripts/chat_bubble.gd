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
## چیدمان (مثل طرح): آواتار گرد سمت چپ، بالای حباب اسم آبی + تاج + «Lv.»،
## زیرش حباب متن و کنارش ساعت. پیام خودم آینه‌ی همین است: سمت راست و آبی.
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

const COLOR_NAME := Color(0.33, 0.7, 1.0, 1.0)

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

# ------------------------------------------------------------------ چرخه‌ی حیات

func _ready() -> void:
	_scroll = _find_scroll()
	_avatar.gui_input.connect(_on_avatar_input)
	_style_theirs = _bubble.get_theme_stylebox("panel")

	if not _data.is_empty():
		_apply()

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
	var header := _show_header
	_head.visible = header
	_avatar.visible = header
	_online_dot.visible = header and _is_online and not _is_mine
	if header:
		_avatar.set_avatar(str(_data.get("sender_avatar", "")))
		var ring := ChatAvatar.RING_BLUE if _is_mine else ChatAvatar.RING_DEFAULT
		_avatar.set_ring(ChatAvatar.RING_GOLD if _is_leader else ring)

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
	_name_label.add_theme_color_override("font_color",
		Color(0.62, 0.84, 1.0, 1.0) if _is_mine else COLOR_NAME)
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
