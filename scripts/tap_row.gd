class_name TapRow
extends Button
## پایه‌ی ردیف‌های لیست منوی کاربر (دوستان، پیام‌ها) — همان الگوی
## chat_room_row.gd و city_tap_row.gd:
##   - ضربه‌ی بدون کشیدن = انتخاب ردیف (یا دکمه‌ی کوچکِ داخلش)
##   - کشیدن انگشت روی ردیف = اسکرول لیست، و هیچ ضربه‌ای ثبت نمی‌شود
##
## دکمه‌های داخل ردیف (مثلاً «پیام»، «پذیرفتن») خودشان ورودی نمی‌گیرند
## (mouse_filter = IGNORE) — ردیف با add_hit_target ثبتشان می‌کند و موقع ضربه
## خودش می‌فهمد انگشت روی کدام بوده. این‌طوری کشیدن از روی دکمه هم لیست را
## اسکرول می‌کند و یک کشیدنِ اشتباهی به‌عنوان کلیک ثبت نمی‌شود.

## target یا خودِ ردیف است یا یکی از hit targetها
signal tapped(row: TapRow, target: Control)

## هر جابه‌جایی بیشتر از این مقدار یعنی اسکرول، نه ضربه
const DRAG_THRESHOLD := 12.0
## حاشیه‌ی اضافه‌ی ناحیه‌ی لمس دکمه‌های کوچک
const HIT_SLOP := 8.0

var _scroll: ScrollContainer = null
var _touch_start := Vector2.ZERO
var _is_swiping := false
var _hit_targets: Array[Control] = []
var _pressed_target: Control = null

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

## یک دکمه‌ی داخلی را قابل ضربه می‌کند (ورودیِ خودش خاموش می‌شود)
func add_hit_target(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _hit_targets.has(control):
		_hit_targets.append(control)

func _target_at(local_pos: Vector2) -> Control:
	var global_pos := get_global_transform() * local_pos
	for t in _hit_targets:
		if is_instance_valid(t) and t.is_visible_in_tree() \
				and t.get_global_rect().grow(HIT_SLOP).has_point(global_pos):
			if t is BaseButton and (t as BaseButton).disabled:
				return self
			return t
	return self

## فقط رویداد تاچ — ماوسِ شبیه‌سازی‌شده همان لمس را دوباره می‌فرستد
## (روی PC هم emulate_touch_from_mouse روشن است).
func _on_gui_input(event: InputEvent) -> void:
	if disabled:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_is_swiping = false
			_pressed_target = _target_at(event.position)
			UIFx.press_scale(_pressed_target, true)
		else:
			if _pressed_target != null:
				UIFx.press_scale(_pressed_target, false)
			if not _is_swiping:
				tapped.emit(self, _pressed_target if _pressed_target != null else self)
			_pressed_target = null
		return

	if event is InputEventScreenDrag:
		if event.position.distance_to(_touch_start) > DRAG_THRESHOLD:
			if not _is_swiping and _pressed_target != null:
				UIFx.press_scale(_pressed_target, false)
			_is_swiping = true
		if _is_swiping and _scroll != null:
			_scroll.scroll_vertical -= int(event.relative.y)
