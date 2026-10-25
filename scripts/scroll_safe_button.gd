extends Button
## دکمه‌ی داخلِ لیستِ اسکرولی که کشیدنِ انگشت را «کلیک» حساب نمی‌کند.
##
## mouse_filter = PASS است تا کشیدن از روی دکمه هم لیست را اسکرول کند. ولی
## Button خودش فقط می‌پرسد «انگشت موقعِ رها کردن هنوز روی من است؟» — و چون
## دکمه هم با لیست زیرِ انگشت جابه‌جا می‌شود، جوابش تقریباً همیشه «بله» است
## و یک اسکرولِ معمولی کلیک ثبت می‌کرد.
##
## این‌جا جابه‌جاییِ انگشت روی «صفحه» سنجیده می‌شود (نه داخلِ دکمه). اگر از
## DRAG_THRESHOLD بیشتر شد، تا رها کردنِ انگشت _has_point منفی برمی‌گرداند؛
## Button آن را «انگشت از روی دکمه رفت» می‌فهمد، حالتِ فشرده را برمی‌دارد و
## موقعِ رها کردن pressed نمی‌فرستد. همان آستانه‌ی tap_row.gd.

const DRAG_THRESHOLD := 12.0

var _touch_start := Vector2.ZERO
var _dragged := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	button_up.connect(func() -> void: _dragged = false)


func _has_point(point: Vector2) -> bool:
	if _dragged:
		return false
	return Rect2(Vector2.ZERO, size).has_point(point)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_dragged = false
			_touch_start = _screen_pos(touch.position)
		else:
			# رها شد — دکمه‌ی بعدی دوباره عادی لمس می‌شود
			_dragged = false
		return
	if event is InputEventScreenDrag and not _dragged:
		var drag := event as InputEventScreenDrag
		if _screen_pos(drag.position).distance_to(_touch_start) > DRAG_THRESHOLD:
			_dragged = true


## مختصاتِ محلی → پیکسلِ صفحه (مستقل از اسکرولِ لیست)
func _screen_pos(local_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * local_pos
