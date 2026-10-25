class_name CityModal
extends Control
## پنجره‌ی مودال ساده‌ی صفحه‌ی شهر: پرده‌ی تیره + کارت وسط صفحه با عنوان
## و دکمه‌ی بستن. محتوا را صدازننده داخل `body` می‌ریزد.
##
## دکمه‌ی Back اندروید را خودِ صفحه‌ی شهر هندل می‌کند (city.gd) تا با
## برگشت صفحه قاطی نشود؛ مودال فقط `close()` را در اختیار می‌گذارد.
##
## استفاده:
##   var modal := CityModal.new()
##   add_child(modal)
##   modal.build("عنوان", 460)
##   modal.body.add_child(...)
##   modal.open()

signal closed

var body: VBoxContainer
var _panel: PanelContainer
var _dim: ColorRect
var _closing := false

## کلیک روی پرده‌ی تیره پنجره را ببندد؟ (دیالوگ فرم‌دار نه — متن تایپ‌شده نپرد)
var dismiss_on_dim := true

func build(title: String, min_width: float = 440.0) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.01, 0.03, 0.72)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(min_width, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := CityUI.box(Color(0.02, 0.05, 0.1, 0.98), Color(0.3, 0.55, 0.9, 0.95), 2, 12)
	style.shadow_color = Color(0.1, 0.4, 1.0, 0.3)
	style.shadow_size = 14
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 18)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	col.add_child(header)

	var title_label := CityUI.label(title, 21, CityUI.TEXT)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	var close_button := CityUI.button("✕", "ghost", 18)
	close_button.custom_minimum_size = Vector2(CityUI.TOUCH_H, CityUI.TOUCH_H)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	col.add_child(CityUI.divider())

	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	col.add_child(body)

func open() -> void:
	_dim.modulate.a = 0.0
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.9, 0.9)
	# اندازه‌ی کارت بعد از چیده شدن محتوا معلوم می‌شود
	await get_tree().process_frame
	if not is_instance_valid(_panel):
		return
	_panel.pivot_offset = _panel.size * 0.5
	var t := create_tween().set_parallel(true)
	t.tween_property(_dim, "modulate:a", 1.0, 0.15)
	t.tween_property(_panel, "modulate:a", 1.0, 0.15)
	t.tween_property(_panel, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close() -> void:
	if _closing:
		return
	_closing = true
	# کیبورد مجازی موبایل باید صریح بسته شود
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()
	DisplayServer.virtual_keyboard_hide()
	closed.emit()
	var t := create_tween().set_parallel(true)
	t.tween_property(_dim, "modulate:a", 0.0, 0.12)
	t.tween_property(_panel, "modulate:a", 0.0, 0.12)
	t.tween_property(_panel, "scale", Vector2(0.92, 0.92), 0.12)
	t.chain().tween_callback(queue_free)

func is_closing() -> bool:
	return _closing

## لرزش کوتاه کارت — برای خطای فرم
func shake() -> void:
	var start_x := _panel.position.x
	var t := create_tween()
	for dx in [-10.0, 10.0, -6.0, 0.0]:
		t.tween_property(_panel, "position:x", start_x + dx, 0.05)

func _on_dim_input(event: InputEvent) -> void:
	if not dismiss_on_dim:
		return
	# فقط تاچ — روی PC هم emulate_touch_from_mouse روشن است
	if event is InputEventScreenTouch and not event.pressed:
		close()
