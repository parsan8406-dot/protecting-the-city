class_name ChatRoomRow
extends Button
## یک ردیف در ستون گفتگوهای صفحه‌ی چت.
##
## هم برای گفتگوی خصوصی با یک دوست به کار می‌رود و هم برای کارت چت شهر
## و چت جهانی — هر سه از سرور همان شکل دیتا را دارند:
##
##   {channel, room, peer_id?, username|title, avatar_id, level, is_online,
##    clan_name, tier_name, unread, last_text, last_sender, last_from_me, last_at}
##
## استفاده:
##   var row := preload("res://secense/chat_room_row.tscn").instantiate()
##   list.add_child(row)
##   row.setup(data)

## بازی موبایل است: انتخاب گفتگو با «ضربه» انجام می‌شود نه با سیگنال pressed،
## چون اگر بازیکن انگشتش را روی ردیف بکشد باید لیست اسکرول شود نه اینکه
## گفتگو باز شود. هر جابه‌جایی بیشتر از این مقدار یعنی اسکرول، نه ضربه.
signal tapped(row: Button)

const DRAG_THRESHOLD := 12.0

@onready var _selected_frame: Panel = $SelectedFrame
@onready var _avatar_slot: Control = $Margin/Row/AvatarSlot
@onready var _avatar: ChatAvatar = $Margin/Row/AvatarSlot/Avatar
@onready var _icon: TextureRect = $Margin/Row/AvatarSlot/Icon
@onready var _online_dot: Panel = $Margin/Row/AvatarSlot/OnlineDot
@onready var _level_label: Label = $Margin/Row/AvatarSlot/LevelLabel
@onready var _name_label: Label = $Margin/Row/Info/TopLine/NameLabel
@onready var _time_label: Label = $Margin/Row/Info/TopLine/TimeLabel
@onready var _preview_label: Label = $Margin/Row/Info/PreviewLabel
@onready var _badge: Panel = $Margin/Row/Badge
@onready var _badge_label: Label = $Margin/Row/Badge/Count

## آیکون‌های کارت چت شهر و چت جهانی (گفتگوهای خصوصی آواتار دارند)
const ICON_CITY := preload("res://assets/chat/icons/city.svg")
const ICON_GLOBAL := preload("res://assets/chat/icons/globe.svg")
const ICON_FRIENDS := preload("res://assets/chat/icons/friends.svg")

var channel: String = ""
var room: String = ""
var peer_id: String = ""
var is_online: bool = false
var unread: int = 0

var _data: Dictionary = {}
var _selected := false

## اسکرول‌کانتینری که این ردیف داخلش است — کشیدن انگشت به آن پاس داده می‌شود
var _scroll: ScrollContainer = null
var _touch_start := Vector2.ZERO
var _is_swiping := false

# ------------------------------------------------------------------ چرخه‌ی حیات

func _ready() -> void:
	_scroll = _find_scroll()
	gui_input.connect(_on_gui_input)

	if not _data.is_empty():
		_apply()
	_refresh_selection()

## پیدا کردن نزدیک‌ترین ScrollContainer بالادستی
func _find_scroll() -> ScrollContainer:
	var node: Node = get_parent()
	while node != null:
		if node is ScrollContainer:
			return node
		node = node.get_parent()
	return null

# ------------------------------------------------------------------ لمس

## کشیدن انگشت روی ردیف = اسکرول لیست؛ ضربه‌ی بدون کشیدن = باز کردن گفتگو.
## فقط رویداد تاچ — ماوسِ شبیه‌سازی‌شده از تاچ همان لمس را دوباره می‌فرستد و
## ضربه دو بار و اسکرول دو برابر ثبت می‌شد (روی PC هم emulate_touch_from_mouse روشن است).
func _on_gui_input(event: InputEvent) -> void:
	if disabled:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_is_swiping = false
		elif not _is_swiping:
			UIFx.tap(self)
			tapped.emit(self)
		return

	if event is InputEventScreenDrag:
		if event.position.distance_to(_touch_start) > DRAG_THRESHOLD:
			_is_swiping = true
		if _is_swiping and _scroll != null:
			_scroll.scroll_vertical -= int(event.relative.y)

## پر کردن ردیف با دیتای یک گفتگو
func setup(data: Dictionary) -> void:
	_data = data
	channel = str(data.get("channel", ""))
	room = str(data.get("room", ""))
	peer_id = str(data.get("peer_id", ""))
	is_online = bool(data.get("is_online", false))
	unread = int(data.get("unread", 0))
	if is_node_ready():
		_apply()

func get_data() -> Dictionary:
	return _data

func set_selected(value: bool) -> void:
	_selected = value
	if is_node_ready():
		_refresh_selection()

# ------------------------------------------------------------------ نمایش

func _apply() -> void:
	var is_private := channel == "private"

	# --- اسم گفتگو ---
	if is_private:
		_name_label.text = str(_data.get("username", "—"))
	else:
		_name_label.text = str(_data.get("title", "—"))

	# --- آواتار (خصوصی) یا آیکون (شهر / جهانی) ---
	_avatar.visible = is_private
	_icon.visible = not is_private
	_level_label.visible = is_private
	_online_dot.visible = is_private and is_online

	if is_private:
		_avatar.set_avatar(str(_data.get("avatar_id", "")))
		_avatar.set_ring(ChatAvatar.RING_GREEN if is_online else ChatAvatar.RING_DEFAULT)
		_level_label.text = "Lv.%d" % int(_data.get("level", 1))
	else:
		_icon.texture = ICON_CITY if channel == "city" else ICON_GLOBAL

	# --- خط پیش‌نمایش آخرین پیام ---
	_preview_label.text = _preview_text(is_private)
	_preview_label.add_theme_color_override("font_color",
		MenuUI.GOLD if unread > 0 else MenuUI.MUTED)

	# --- زمان آخرین پیام ---
	var last_at := str(_data.get("last_at", ""))
	_time_label.text = ChatBubble.relative_time(last_at)
	_time_label.visible = not _time_label.text.is_empty()

	# --- نشان پیام‌های خوانده‌نشده ---
	_badge.visible = unread > 0
	_badge_label.text = "99+" if unread > 99 else str(unread)

	# گفتگوی در دسترس نبودن (مثلاً وقتی عضو هیچ شهری نیستی)
	var available := bool(_data.get("available", true))
	disabled = not available
	modulate.a = 1.0 if available else 0.55

## متن خط دوم: آخرین پیام، وضعیت آنلاین، یا راهنمای خالی بودن
func _preview_text(is_private: bool) -> String:
	if not bool(_data.get("available", true)):
		return str(_data.get("hint", "در دسترس نیست"))

	var last_text := ChatEmoji.preview(str(_data.get("last_text", "")))
	if last_text.is_empty():
		if is_private:
			return "آنلاین" if is_online else "هنوز پیامی رد و بدل نشده"
		if channel == "global":
			return "%d بازیکن آنلاین" % int(_data.get("online_count", 0))
		return "%d عضو" % int(_data.get("member_count", 0))

	# در گفتگوهای گروهی اسم گوینده هم می‌آید تا معلوم باشد کی گفته
	if bool(_data.get("last_from_me", false)):
		return "شما : %s" % last_text
	if not is_private:
		var sender := str(_data.get("last_sender", ""))
		if not sender.is_empty():
			return "%s : %s" % [sender, last_text]
	return last_text

func _refresh_selection() -> void:
	_selected_frame.visible = _selected
