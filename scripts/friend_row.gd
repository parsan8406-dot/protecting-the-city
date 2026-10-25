class_name FriendRow
extends TapRow
## یک ردیف در لیست دوستان — دیتا از `PublicProfile` سرور (GET /friends).
##
## ضربه روی ردیف → انتخاب دوست (کارت کناری)؛ ضربه روی دکمه‌ی پیام → چت.
## کشیدن انگشت روی هر جای ردیف لیست را اسکرول می‌کند (TapRow).
##
## استفاده:
##   var row := preload("res://secense/friend_row.tscn").instantiate()
##   list.add_child(row)
##   row.setup(profile_dictionary)

signal row_selected(row: FriendRow)
signal message_requested(player_id: String)

@onready var _selected_frame: Panel = $SelectedFrame
@onready var _avatar: TextureRect = $Margin/Row/AvatarSlot/Avatar
@onready var _online_dot: Panel = $Margin/Row/AvatarSlot/OnlineDot
@onready var _level_label: Label = $Margin/Row/AvatarSlot/LevelLabel
@onready var _name_label: Label = $Margin/Row/Info/NameLabel
@onready var _status_label: Label = $Margin/Row/Info/StatusLabel
@onready var _badge: Panel = $Margin/Row/Badge
@onready var _badge_art: TextureRect = $Margin/Row/Badge/Art
@onready var _chat_button: Button = $Margin/Row/ChatButton

var player_id: String = ""
var username: String = ""
var is_online: bool = false

var _data: Dictionary = {}
var _selected: bool = false

func _ready() -> void:
	super._ready()
	MenuUI.style_button(_chat_button, "dark")
	add_hit_target(_chat_button)
	tapped.connect(_on_tapped)
	if not _data.is_empty():
		_apply(_data)
	_refresh_selection()

## پر کردن (یا به‌روز کردن) ردیف با دیتای یک دوست
func setup(data: Dictionary) -> void:
	_data = data
	player_id = str(data.get("player_id", ""))
	username = str(data.get("username", ""))
	is_online = bool(data.get("is_online", false))
	if is_node_ready():
		_apply(data)

func get_data() -> Dictionary:
	return _data

func set_selected(value: bool) -> void:
	_selected = value
	if is_node_ready():
		_refresh_selection()

func _on_tapped(_row: TapRow, target: Control) -> void:
	if target == _chat_button:
		message_requested.emit(player_id)
		return
	UIFx.tap(self)
	row_selected.emit(self)

# ------------------------------------------------------------------ نمایش

func _apply(data: Dictionary) -> void:
	_name_label.text = str(data.get("username", "—"))
	_level_label.text = MenuUI.fa(int(data.get("level", 1)))

	# خط دوم: وضعیت آنلاین (سبز) یا آخرین بازدید، و شهر
	var status := MenuUI.last_seen_text(is_online, str(data.get("last_seen_at", "")))
	var clan_name := str(data.get("clan_name", ""))
	_status_label.text = status + ("  •  " + clan_name if not clan_name.is_empty() else "")
	_status_label.add_theme_color_override("font_color",
		MenuUI.GREEN if is_online else Color(0.62, 0.62, 0.66, 1.0))

	# نشان رنک — اگر تصویرش نبود، جای خالی نشان نمی‌دهیم
	var tier := str(data.get("tier_name", ""))
	_badge_art.texture = RankArt.texture_for(str(data.get("tier_id", "")), tier)
	_badge.visible = _badge_art.texture != null

	_online_dot.visible = is_online
	_avatar.texture = MenuUI.avatar_texture(str(data.get("avatar_id", "")))
	_avatar.modulate = Color.WHITE if is_online else Color(0.78, 0.78, 0.8, 1.0)

func _refresh_selection() -> void:
	_selected_frame.visible = _selected
