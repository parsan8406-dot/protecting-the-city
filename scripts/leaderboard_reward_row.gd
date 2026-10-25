extends PanelContainer
## یک ردیف از «پاداش پایان فصل» در تب رتبه‌بندی.
##
## متن پاداش‌ها را سرور می‌دهد (SeasonRewards در handlers_leaderboard.go)،
## نه کلاینت — تا کسی نتواند برای خودش پاداش تعریف کند.
##
## استفاده (اول add_child، بعد setup):
##   var row := preload("res://secense/leaderboard_reward_row.tscn").instantiate()
##   list.add_child(row)
##   row.setup(reward, my_position)
##
## زدن روی ردیف سیگنال `tier_pressed` را می‌فرستد؛ تب با آن جدول را
## روی همان بازه‌ی رتبه می‌برد. چون ردیف داخل ScrollContainer است،
## کشیدن انگشت اسکرول می‌شود و فقط تپِ بدون حرکت «زدن» حساب می‌شود.

signal tier_pressed(reward: Dictionary)

## انگشت اگر بیشتر از این جابه‌جا شود یعنی دارد اسکرول می‌کند، نه اینکه ردیف را زده
const DRAG_THRESHOLD := 12.0

## 🎨 تصویر کاپ پاداش. فعلاً یک فایل داریم؛ اگر برای هر cup_rarity
## تصویر جدا آمد، اینجا به یک نگاشتِ rarity → مسیر تبدیل می‌شود.
const CUP_ART := "res://assets/ranks/cup_trophy.png"

const COLOR_GOLD := Color(0.91, 0.76, 0.29, 1.0)
const COLOR_TEXT := Color(0.96, 0.96, 0.97, 1.0)
const COLOR_RED := Color(0.85, 0.043, 0.075, 1.0)

@onready var _cup_slot: PanelContainer = $Margin/Row/CupSlot
@onready var _cup_art: TextureRect = $Margin/Row/CupSlot/CupArt
@onready var _placeholder: Label = $Margin/Row/CupSlot/Placeholder
@onready var _title_label: Label = $Margin/Row/Info/TitleLabel
@onready var _reward_label: Label = $Margin/Row/Info/RewardLabel

## استایل ردیفِ پاداشِ خودم (طلایی) — یک بار ساخته و کش می‌شود
var _mine_style: StyleBoxFlat = null
## استایل ردیفِ انتخاب‌شده (وقتی رویش زده‌ام)
var _selected_style: StyleBoxFlat = null

var _reward: Dictionary = {}
var _is_mine := false
var _is_selected := false

## اسکرول والد — برای اینکه کشیدن انگشت روی ردیف، لیست را اسکرول کند
var _parent_scroll: ScrollContainer = null
var _touch_start := Vector2.ZERO
var _is_swiping := false

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_parent_scroll = _find_parent_scroll()
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)

## پر کردن ردیف.
##   reward       یک آیتم از `rewards` در پاسخ /leaderboard
##   my_position  رتبه‌ی فعلی خودم (۰ یعنی نامعلوم) — برای برجسته کردن ردیفم
func setup(reward: Dictionary, my_position: int) -> void:
	_reward = reward
	_title_label.text = str(reward.get("title", "—"))
	_reward_label.text = str(reward.get("reward", "—"))

	# پاداشِ بدون کاپ (فقط سکه) اصلاً جای کاپ را اشغال نمی‌کند
	var has_cup := int(reward.get("cups", 0)) > 0
	_cup_slot.visible = has_cup
	if has_cup and ResourceLoader.exists(CUP_ART):
		_cup_art.texture = load(CUP_ART)
		_placeholder.visible = false
	else:
		_cup_art.texture = null
		_placeholder.visible = true

	_is_mine = _covers(reward, my_position)
	_apply_highlight()

## آیا این ردیف همان بازه‌ای است که از رتبه‌ی داده‌شده شروع می‌شود؟
func is_tier(from_position: int) -> bool:
	return int(_reward.get("from_position", -1)) == from_position

## آیا این ردیف الان انتخاب شده است؟ (تب صدا می‌زند)
func set_selected(value: bool) -> void:
	if _is_selected == value:
		return
	_is_selected = value
	_apply_highlight()

## آیا رتبه‌ی من داخل بازه‌ی این پاداش است؟
func _covers(reward: Dictionary, my_position: int) -> bool:
	if my_position <= 0:
		return false

	var from_position := int(reward.get("from_position", 0))
	var to_position := int(reward.get("to_position", 0))
	if my_position < from_position:
		return false
	# صفر یعنی «تا آخر جدول»
	return to_position <= 0 or my_position <= to_position

## ردیف انتخاب‌شده قاب قرمز می‌گیرد، ردیفِ پاداشِ خودم قاب طلایی
func _apply_highlight() -> void:
	if _is_selected:
		if _selected_style == null:
			_selected_style = StyleBoxFlat.new()
			_selected_style.bg_color = Color(0.16, 0.03, 0.04, 0.75)
			_selected_style.set_border_width_all(1)
			_selected_style.border_color = COLOR_RED
			_selected_style.set_corner_radius_all(3)
		add_theme_stylebox_override("panel", _selected_style)
		_title_label.add_theme_color_override("font_color", COLOR_GOLD if _is_mine else COLOR_TEXT)
		return

	if _is_mine:
		if _mine_style == null:
			_mine_style = StyleBoxFlat.new()
			_mine_style.bg_color = Color(0.13, 0.1, 0.02, 0.6)
			_mine_style.set_border_width_all(1)
			_mine_style.border_color = Color(0.91, 0.76, 0.29, 0.8)
			_mine_style.set_corner_radius_all(3)
		add_theme_stylebox_override("panel", _mine_style)
		_title_label.add_theme_color_override("font_color", COLOR_GOLD)
	else:
		remove_theme_stylebox_override("panel")
		_title_label.add_theme_color_override("font_color", COLOR_TEXT)

# ------------------------------------------- زدن / کشیدن انگشت روی ردیف

## کشیدن = اسکرولِ لیستِ پاداش‌ها، تپِ بی‌حرکت = انتخاب این بازه‌ی رتبه
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or (
		event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
	):
		if event.pressed:
			_touch_start = event.position
			_is_swiping = false
		elif not _is_swiping:
			tier_pressed.emit(_reward)
		return

	var dragging: bool = event is InputEventScreenDrag or (
		event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	)
	if not dragging:
		return

	if event.position.distance_to(_touch_start) > DRAG_THRESHOLD:
		_is_swiping = true
	if _is_swiping and _parent_scroll:
		_parent_scroll.scroll_vertical -= int(event.relative.y)

func _find_parent_scroll() -> ScrollContainer:
	var node := get_parent()
	while node != null:
		if node is ScrollContainer:
			return node
		node = node.get_parent()
	return null
