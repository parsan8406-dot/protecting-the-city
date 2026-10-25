class_name ChatOnlineRow
extends PanelContainer
## یک نفر در ستون «آنلاین» صفحه‌ی چت (فقط دوستان و هم‌شهری‌ها).
##
## دیتا از GET /chat/overview → people:
##   {player_id, username, avatar_id, level, is_online, last_seen_at,
##    is_friend, is_city, clan_role}
##
## دکمه‌ی گرد سمت راست:
##   دوست     → آیکون پیام: گفتگوی خصوصی باز می‌شود
##   غیر دوست → «+»: درخواست دوستی
##
## ردیف داخل ScrollContainer است، پس کل لمس را خودش مدیریت می‌کند:
## کشیدن = اسکرول، ضربه روی دکمه = اکشن، ضربه روی بقیه = کارت پروفایل.

signal tapped(data: Dictionary)
signal action_pressed(data: Dictionary)

const ICON_ADD := preload("res://assets/chat/icons/plus.svg")
const ICON_MESSAGE := preload("res://assets/chat/icons/message.svg")
const DRAG_THRESHOLD := 12.0

const COLOR_ONLINE := Color(0.2, 0.85, 0.38, 1.0)
const COLOR_OFFLINE := Color(0.5, 0.55, 0.62, 1.0)

@onready var _avatar: ChatAvatar = $Margin/Row/AvatarSlot/Avatar
@onready var _name_label: Label = $Margin/Row/Info/Head/NameLabel
@onready var _crown: TextureRect = $Margin/Row/Info/Head/Crown
@onready var _level_label: Label = $Margin/Row/Info/Head/LevelLabel
@onready var _dot: Panel = $Margin/Row/Info/Status/Dot
@onready var _status_label: Label = $Margin/Row/Info/Status/StatusLabel
@onready var _action: TextureRect = $Margin/Row/Action

var player_id: String = ""
var _data: Dictionary = {}
var _request_sent := false
var _scroll: ScrollContainer = null
var _touch_start := Vector2.ZERO
var _is_swiping := false
var _press_target: Control = null

func _ready() -> void:
	_scroll = _find_scroll()
	gui_input.connect(_on_gui_input)
	if not _data.is_empty():
		_apply()

func setup(data: Dictionary) -> void:
	_data = data
	player_id = str(data.get("player_id", ""))
	if is_node_ready():
		_apply()

func get_data() -> Dictionary:
	return _data

## بعد از فرستادن درخواست دوستی، «+» کم‌رنگ می‌شود تا دوباره زده نشود
func mark_request_sent() -> void:
	_request_sent = true
	if is_node_ready():
		_apply()

func _apply() -> void:
	var online := bool(_data.get("is_online", false))
	var is_friend := bool(_data.get("is_friend", false))
	var is_leader := str(_data.get("clan_role", "")) == "leader"

	_name_label.text = str(_data.get("username", "—"))
	_level_label.text = "Lv.%d" % int(_data.get("level", 1))
	_crown.visible = is_leader

	_avatar.set_avatar(str(_data.get("avatar_id", "")))
	_avatar.set_ring(ChatAvatar.RING_GOLD if is_leader else (ChatAvatar.RING_GREEN if online else ChatAvatar.RING_DEFAULT))
	_avatar.modulate = Color.WHITE if online else Color(0.72, 0.74, 0.78, 1.0)

	_dot.self_modulate = COLOR_ONLINE if online else COLOR_OFFLINE
	_status_label.text = "آنلاین" if online else ChatBubble.last_seen_text(str(_data.get("last_seen_at", "")))
	_status_label.add_theme_color_override("font_color", COLOR_ONLINE if online else COLOR_OFFLINE)

	_action.texture = ICON_MESSAGE if is_friend else ICON_ADD
	_action.modulate.a = 0.35 if _request_sent and not is_friend else 1.0

# ------------------------------------------------------------------ لمس

func _find_scroll() -> ScrollContainer:
	var node: Node = get_parent()
	while node != null:
		if node is ScrollContainer:
			return node
		node = node.get_parent()
	return null

## فقط رویداد تاچ: روی گوشی هر لمس یک رویداد ماوسِ شبیه‌سازی‌شده هم می‌سازد و
## روی PC هم emulate_touch_from_mouse روشن است؛ اگر هر دو را بگیریم ضربه دو
## بار ثبت می‌شود و اسکرول دو برابر سریع می‌شود.
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_is_swiping = false
			_press_target = _action if _hit_action(event.position) else self
			UIFx.press_scale(_press_target, true)
		else:
			if _press_target != null:
				UIFx.press_scale(_press_target, false)
			if not _is_swiping:
				if _press_target == _action:
					if not (_request_sent and not bool(_data.get("is_friend", false))):
						action_pressed.emit(_data)
				else:
					tapped.emit(_data)
			_press_target = null
		return

	if event is InputEventScreenDrag:
		if event.position.distance_to(_touch_start) > DRAG_THRESHOLD and not _is_swiping:
			_is_swiping = true
			if _press_target != null:
				UIFx.press_scale(_press_target, false)
		if _is_swiping and _scroll != null:
			_scroll.scroll_vertical -= int(event.relative.y)

## لمس روی دکمه‌ی گرد؟ ناحیه‌ی لمس کمی بزرگ‌تر از خود آیکون است (انگشت)
func _hit_action(local_pos: Vector2) -> bool:
	var rect := Rect2(_action.global_position - global_position, _action.size).grow(12.0)
	return rect.has_point(local_pos)
