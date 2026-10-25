class_name CityTapRow
extends Button
## پایه‌ی ردیف‌های لیست صفحه‌ی شهر (شهرها و اعضا).
##
## بازی موبایل است: انتخاب ردیف با «ضربه» انجام می‌شود نه با سیگنال pressed،
## چون اگر بازیکن انگشتش را روی ردیف بکشد باید لیست اسکرول شود نه اینکه
## ردیف باز شود (همان الگوی chat_room_row.gd).

signal tapped(row: CityTapRow)

## هر جابه‌جایی بیشتر از این مقدار یعنی اسکرول، نه ضربه
const DRAG_THRESHOLD := 12.0

var _scroll: ScrollContainer = null
var _touch_start := Vector2.ZERO
var _is_swiping := false

func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE

func _ready() -> void:
	_scroll = _find_scroll()
	gui_input.connect(_on_gui_input)

func _find_scroll() -> ScrollContainer:
	var node: Node = get_parent()
	while node != null:
		if node is ScrollContainer:
			return node
		node = node.get_parent()
	return null

## فقط رویداد تاچ — ماوسِ شبیه‌سازی‌شده همان لمس را دوباره می‌فرستد
## (روی PC هم emulate_touch_from_mouse روشن است).
func _on_gui_input(event: InputEvent) -> void:
	if disabled:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_is_swiping = false
			UIFx.press_scale(self, true)
		else:
			UIFx.press_scale(self, false)
			if not _is_swiping:
				tapped.emit(self)
		return

	if event is InputEventScreenDrag:
		if event.position.distance_to(_touch_start) > DRAG_THRESHOLD:
			if not _is_swiping:
				UIFx.press_scale(self, false)
			_is_swiping = true
		if _is_swiping and _scroll != null:
			_scroll.scroll_vertical -= int(event.relative.y)

## استایل ردیف: زمینه‌ی تیره، و در حالت برجسته (رهبر / خودم) قاب طلایی
func apply_row_style(highlight: bool) -> void:
	var normal: StyleBoxFlat
	if highlight:
		normal = CityUI.box(Color(0.16, 0.12, 0.03, 0.55), Color(0.97, 0.78, 0.3, 0.55), 1, 8)
	else:
		normal = CityUI.box(Color(0.03, 0.06, 0.12, 0.7), Color(0.2, 0.3, 0.46, 0.45), 1, 8)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = normal.bg_color.lightened(0.12)
	pressed.border_color = CityUI.BLUE
	for state in ["normal", "hover", "disabled"]:
		add_theme_stylebox_override(state, normal)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("hover_pressed", pressed)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
