class_name ChatChannelCard
extends Button
## کارت یک کانال در ستون چپ صفحه‌ی چت (جهانی / شهر / دوستان).
## کارت انتخاب‌شده آبیِ درخشان می‌شود و نشان قرمز تعداد پیام‌های خوانده‌نشده را
## نشان می‌دهد.

@export var channel: String = ""
@export var title: String = "":
	set(value):
		title = value
		if is_node_ready():
			_title_label.text = value
@export var subtitle: String = "":
	set(value):
		subtitle = value
		if is_node_ready():
			_sub_label.text = value
@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_node_ready():
			_icon.texture = value
## استایل کارت انتخاب‌شده (استایل عادی همان normal دکمه است)
@export var style_selected: StyleBox

@onready var _icon: TextureRect = $Margin/Row/Icon
@onready var _title_label: Label = $Margin/Row/Text/Title
@onready var _sub_label: Label = $Margin/Row/Text/Subtitle
@onready var _badge: Panel = $Margin/Row/Badge
@onready var _badge_label: Label = $Margin/Row/Badge/Count

var _style_idle: StyleBox
var _selected := false

func _ready() -> void:
	_style_idle = get_theme_stylebox("normal")
	_title_label.text = title
	_sub_label.text = subtitle
	_icon.texture = icon_texture
	set_unread(0)
	_refresh()
	UIFx.bind_press_feedback(self)

func set_selected(value: bool) -> void:
	_selected = value
	_refresh()

func set_unread(count: int) -> void:
	_badge.visible = count > 0
	_badge_label.text = "99+" if count > 99 else str(count)
	_badge.custom_minimum_size.x = 26.0 if _badge_label.text.length() <= 2 else 36.0

## کانالی که در دسترس نیست (مثلاً عضو هیچ شهری نیستی) کم‌رنگ می‌شود،
## ولی هنوز قابل لمس است تا راهنمایش نشان داده شود.
func set_available(value: bool) -> void:
	modulate.a = 1.0 if value else 0.6

func _refresh() -> void:
	var style := style_selected if _selected and style_selected != null else _style_idle
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("hover", style)
	_icon.modulate = Color.WHITE if _selected else Color(0.78, 0.85, 0.95, 1.0)
