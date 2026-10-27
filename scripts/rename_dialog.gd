extends Control
## باکس تغییر نام کاربری.
## روی اندروید کیبورد مجازی را خودش باز و بسته می‌کند.
##
## استفاده:
##   var dialog := preload("res://secense/rename_dialog.tscn").instantiate()
##   dialog.name_confirmed.connect(func(new_name): ...)
##   add_child(dialog)
##   dialog.open(Global.my_username)

signal name_confirmed(new_name: String)
signal cancelled

const MIN_LENGTH := 3
const MAX_LENGTH := 20

@onready var _dim: ColorRect = $Dim
@onready var _dialog: PanelContainer = $Dialog
@onready var _name_edit: LineEdit = $Dialog/Margin/Body/NameEdit
@onready var _error_label: Label = $Dialog/Margin/Body/ErrorLabel
@onready var _save_button: Button = $Dialog/Margin/Body/Buttons/SaveButton
@onready var _cancel_button: Button = $Dialog/Margin/Body/Buttons/CancelButton

var _original_name: String = ""

func _ready() -> void:
	_save_button.pressed.connect(_on_save_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	# V9: فشردنِ دکمه‌ها دیده و شنیده می‌شود
	UIFx.bind_press_feedback(_save_button)
	UIFx.bind_press_feedback(_cancel_button)
	_name_edit.text_submitted.connect(_on_text_submitted)
	_name_edit.text_changed.connect(_on_text_changed)
	_dim.gui_input.connect(_on_dim_input)

func open(current_name: String = "") -> void:
	_original_name = current_name
	_name_edit.text = current_name
	_error_label.visible = false
	_on_text_changed(current_name)
	visible = true

	_dialog.pivot_offset = _dialog.size * 0.5
	_dialog.scale = Vector2(0.88, 0.88)
	_dialog.modulate.a = 0.0
	_dim.modulate.a = 0.0

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_dim, "modulate:a", 1.0, 0.15)
	t.tween_property(_dialog, "modulate:a", 1.0, 0.15)
	t.tween_property(_dialog, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# بعد از تموم شدن انیمیشن، فوکوس + کیبورد موبایل
	await get_tree().create_timer(0.18).timeout
	if not is_instance_valid(self):
		return
	_focus_and_show_keyboard()

## فوکوس روی فیلد و باز کردن کیبورد مجازی (اندروید / iOS)
func _focus_and_show_keyboard() -> void:
	_name_edit.grab_focus()
	_name_edit.select_all()

	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(
			_name_edit.text,
			Rect2(),
			DisplayServer.KEYBOARD_TYPE_DEFAULT,
			MAX_LENGTH,
			0,
			_name_edit.text.length()
		)

func _hide_keyboard() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()

func close() -> void:
	_hide_keyboard()
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_dim, "modulate:a", 0.0, 0.12)
	t.tween_property(_dialog, "modulate:a", 0.0, 0.12)
	t.tween_property(_dialog, "scale", Vector2(0.9, 0.9), 0.12)
	t.chain().tween_callback(queue_free)

## نمایش خطا (مثلاً وقتی سرور می‌گوید این نام گرفته شده است)
func show_error(message: String) -> void:
	_error_label.text = message
	_error_label.visible = true
	_save_button.disabled = false

	# تکون خوردن باکس برای اینکه خطا دیده بشه
	var start_x := _dialog.position.x
	var t := create_tween()
	t.tween_property(_dialog, "position:x", start_x - 10.0, 0.05)
	t.tween_property(_dialog, "position:x", start_x + 10.0, 0.05)
	t.tween_property(_dialog, "position:x", start_x - 6.0, 0.05)
	t.tween_property(_dialog, "position:x", start_x, 0.06)

	_focus_and_show_keyboard()

# ------------------------------------------------------------------ اعتبارسنجی

func _validate(new_name: String) -> String:
	var trimmed := new_name.strip_edges()
	if trimmed.length() < MIN_LENGTH:
		return "نام کاربری باید حداقل %s کاراکتر باشد" % MenuUI.fa(MIN_LENGTH)
	if trimmed.length() > MAX_LENGTH:
		return "نام کاربری نباید بیشتر از %s کاراکتر باشد" % MenuUI.fa(MAX_LENGTH)
	if trimmed == _original_name:
		return "این همان نام فعلی شماست"
	if not trimmed.is_valid_ascii_identifier() and not _is_alnum_underscore(trimmed):
		return "فقط حروف انگلیسی، عدد و آندرلاین مجاز است"
	return ""

func _is_alnum_underscore(value: String) -> bool:
	for c in value:
		var is_digit := c >= "0" and c <= "9"
		var is_lower := c >= "a" and c <= "z"
		var is_upper := c >= "A" and c <= "Z"
		if not (is_digit or is_lower or is_upper or c == "_"):
			return false
	return true

# ------------------------------------------------------------------ رویدادها

## C12/C13 اعتبارسنجی زنده: «ذخیره» فقط وقتی فعال است که اسم قابل قبول باشد،
## و راهنما همان لحظه می‌گوید مشکل چیست (نه بعد از زدن دکمه)
func _on_text_changed(new_text: String) -> void:
	_error_label.visible = false
	var problem := _validate(new_text)
	_save_button.disabled = not problem.is_empty()
	var hint := get_node_or_null("Dialog/Margin/Body/HintLabel") as Label
	if hint == null:
		return
	var n := new_text.strip_edges().length()
	if problem.is_empty():
		hint.text = "✓ اسم قابل قبول است  (%s / %s)" % [MenuUI.fa(n), MenuUI.fa(MAX_LENGTH)]
		hint.add_theme_color_override("font_color", MenuUI.GREEN)
	else:
		hint.text = "%s  (%s / %s)" % [problem, MenuUI.fa(n), MenuUI.fa(MAX_LENGTH)]
		hint.add_theme_color_override("font_color", MenuUI.MUTED)

func _on_text_submitted(_text: String) -> void:
	_on_save_pressed()

func _on_save_pressed() -> void:
	var new_name := _name_edit.text.strip_edges()
	var error := _validate(new_name)
	if not error.is_empty():
		show_error(error)
		return

	_save_button.disabled = true
	_hide_keyboard()
	name_confirmed.emit(new_name)

func _on_cancel_pressed() -> void:
	cancelled.emit()
	close()

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_cancel_pressed()

## Back اندروید از profile_menu
func dismiss() -> void:
	_on_cancel_pressed()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		_on_cancel_pressed()
