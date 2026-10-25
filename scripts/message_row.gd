class_name MessageRow
extends TapRow
## یک ردیف در صندوق پیام‌ها: پیام سیستمی، درخواست دوستی، هدیه و جایزه.
##
## ضربه روی ردیف → باز شدن پیام در کارت کناری؛ دکمه‌ی اصلی → پذیرفتن /
## دریافت جایزه؛ ✕ → رد درخواست یا حذف پیام. کشیدن انگشت = اسکرول (TapRow).

signal row_selected(row: MessageRow)
signal primary_pressed(message_id: String)
signal dismiss_pressed(message_id: String)

const TYPE_FRIEND_REQUEST := "friend_request"
const TYPE_GIFT := "gift"
const TYPE_REWARD := "reward"

const ICON_SYSTEM := preload("res://assets/ui/profile_menu/icon_messages.svg")
const ICON_FRIEND := preload("res://assets/ui/profile_menu/icon_friends.svg")
const ICON_GIFT := preload("res://assets/ui/profile_menu/friend_icon_gift.svg")
const ICON_REWARD := preload("res://assets/ui/profile_menu/icon_achievement.svg")

@onready var _selected_frame: Panel = $SelectedFrame
@onready var _dismiss_button: Button = $Margin/Row/DismissButton
@onready var _action_button: Button = $Margin/Row/ActionButton
@onready var _title_label: Label = $Margin/Row/Info/TopLine/TitleLabel
@onready var _time_label: Label = $Margin/Row/Info/TopLine/TimeLabel
@onready var _preview_label: Label = $Margin/Row/Info/PreviewLabel
@onready var _type_icon: TextureRect = $Margin/Row/IconSlot/TypeIcon
@onready var _unread_dot: Panel = $Margin/Row/IconSlot/UnreadDot

var message_id: String = ""
var message_type: String = ""
var is_read: bool = true

var _data: Dictionary = {}
var _selected := false

func _ready() -> void:
	super._ready()
	MenuUI.style_button(_dismiss_button, "ghost")
	_dismiss_button.add_theme_color_override("font_color", MenuUI.RED_HOT)
	add_hit_target(_action_button)
	add_hit_target(_dismiss_button)
	tapped.connect(_on_tapped)
	if not _data.is_empty():
		_apply(_data)
	_refresh_selection()

func setup(data: Dictionary) -> void:
	_data = data
	message_id = str(data.get("message_id", ""))
	message_type = str(data.get("type", ""))
	is_read = bool(data.get("is_read", false))
	if is_node_ready():
		_apply(data)

func get_data() -> Dictionary:
	return _data

func set_selected(value: bool) -> void:
	_selected = value
	if is_node_ready():
		_refresh_selection()

## بعد از خوانده‌شدن، فقط نقطه‌ی قرمز خاموش می‌شود (بدون ساختن دوباره‌ی ردیف)
func mark_read() -> void:
	is_read = true
	_data["is_read"] = true
	if is_node_ready():
		_unread_dot.visible = false
		_title_label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.85, 1.0))

func _on_tapped(_row: TapRow, target: Control) -> void:
	if target == _action_button:
		primary_pressed.emit(message_id)
	elif target == _dismiss_button:
		dismiss_pressed.emit(message_id)
	else:
		UIFx.tap(self)
		row_selected.emit(self)

## جایزه‌ای که هنوز گرفته نشده؟
func has_unclaimed_reward() -> bool:
	return MessageRow.reward_pending(_data)

static func reward_pending(data: Dictionary) -> bool:
	var reward = data.get("reward", null)
	if not (reward is Dictionary) or bool(data.get("reward_claimed", false)):
		return false
	var r: Dictionary = reward
	var items = r.get("items", [])
	return int(r.get("coins", 0)) > 0 or int(r.get("gems", 0)) > 0 or int(r.get("xp", 0)) > 0 \
		or (items is Array and not (items as Array).is_empty())

static func type_icon(msg_type: String) -> Texture2D:
	match msg_type:
		TYPE_FRIEND_REQUEST: return ICON_FRIEND
		TYPE_GIFT: return ICON_GIFT
		TYPE_REWARD: return ICON_REWARD
	return ICON_SYSTEM

static func type_color(msg_type: String) -> Color:
	match msg_type:
		TYPE_FRIEND_REQUEST: return MenuUI.GREEN
		TYPE_GIFT, TYPE_REWARD: return MenuUI.GOLD
	return Color(0.8, 0.8, 0.84, 1.0)

# ------------------------------------------------------------------ نمایش

func _apply(data: Dictionary) -> void:
	_title_label.text = str(data.get("title", "پیام"))
	_title_label.add_theme_color_override("font_color",
		MenuUI.TEXT if not is_read else Color(0.82, 0.82, 0.85, 1.0))
	_preview_label.text = str(data.get("body", "")).replace("\n", " ").strip_edges()
	_time_label.text = ChatBubble.relative_time(str(data.get("created_at", "")))
	_unread_dot.visible = not is_read
	_type_icon.texture = MessageRow.type_icon(message_type)
	_type_icon.modulate = MessageRow.type_color(message_type)

	var pending := has_unclaimed_reward()
	match message_type:
		TYPE_FRIEND_REQUEST:
			_action_button.text = "پذیرفتن"
			MenuUI.style_button(_action_button, "gold")
			_dismiss_button.visible = true
		TYPE_GIFT, TYPE_REWARD:
			_action_button.text = "دریافت جایزه" if pending else "مشاهده"
			MenuUI.style_button(_action_button, "gold" if pending else "dark")
			# پیامِ جایزه‌دار قبل از دریافت قابل حذف نیست (سرور هم قبول نمی‌کند)
			_dismiss_button.visible = not pending
		_:
			_action_button.text = "مشاهده"
			MenuUI.style_button(_action_button, "dark")
			_dismiss_button.visible = true

func _refresh_selection() -> void:
	_selected_frame.visible = _selected
