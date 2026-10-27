extends Control
## باکس «ارسال پیام به پشتیبانی».
##
## کاربر اندرویدی روی فیلد می‌زند، کیبورد مجازی باز می‌شود، متن را می‌نویسد و
## «ثبت» را می‌زند. پیام با نام کاربری‌اش به سرور می‌رود و در کالکشن
## support_messages دیتابیس ذخیره می‌شود تا سازنده‌ی بازی ببیندش.
##
## استفاده:
##   var dialog := preload("res://secense/message_dialog.tscn").instantiate()
##   add_child(dialog)
##   dialog.open()
##
## سیگنال‌ها:
##   sent(text)        — سرور پیام را ذخیره کرد
##   failed(reason)    — ارسال نشد (اینترنت/سرور)
##   cancelled         — کاربر بست

signal sent(text: String)
signal failed(reason: String)
signal cancelled

const MIN_LENGTH := 5
const MAX_LENGTH := 1000

## مسیر اندپوینت روی سرور — آدرس پایه از Global می‌آید
const ENDPOINT := "/support/message"

@onready var _dim: ColorRect = $Dim
@onready var _dialog: PanelContainer = $Dialog
@onready var _text_edit: TextEdit = $Dialog/Margin/Body/TextEdit
@onready var _counter_label: Label = $Dialog/Margin/Body/CounterRow/CounterLabel
@onready var _user_label: Label = $Dialog/Margin/Body/CounterRow/UserLabel
@onready var _error_label: Label = $Dialog/Margin/Body/ErrorLabel
@onready var _send_button: Button = $Dialog/Margin/Body/Buttons/SendButton
@onready var _cancel_button: Button = $Dialog/Margin/Body/Buttons/CancelButton

var _http: HTTPRequest
var _sending := false
var _closing := false


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

	_send_button.pressed.connect(_on_send_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_text_edit.text_changed.connect(_on_text_changed)
	_dim.gui_input.connect(_on_dim_input)

	# بازخورد لمسی (بدون hover — بازی فقط موبایل است)
	for button in [_send_button, _cancel_button]:
		button.button_down.connect(_press_visual.bind(button, true))
		button.button_up.connect(_press_visual.bind(button, false))


func open(prefill: String = "") -> void:
	_text_edit.text = prefill
	_error_label.visible = false
	_sending = false
	_send_button.disabled = false
	_user_label.text = "از طرف: " + Global.my_username
	_update_counter()
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

	await get_tree().create_timer(0.18).timeout
	if not is_instance_valid(self):
		return
	_focus_and_show_keyboard()


## فوکوس روی فیلد + باز کردن کیبورد مجازی اندروید (حالت چندخطی)
func _focus_and_show_keyboard() -> void:
	_text_edit.grab_focus()
	_text_edit.set_caret_line(_text_edit.get_line_count() - 1)
	_text_edit.set_caret_column(_text_edit.get_line(_text_edit.get_line_count() - 1).length())

	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(
			_text_edit.text,
			Rect2(),
			DisplayServer.KEYBOARD_TYPE_MULTILINE,
			MAX_LENGTH,
			_text_edit.text.length()
		)


func _hide_keyboard() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()


func close() -> void:
	if _closing:
		return
	_closing = true
	_hide_keyboard()
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_dim, "modulate:a", 0.0, 0.12)
	t.tween_property(_dialog, "modulate:a", 0.0, 0.12)
	t.tween_property(_dialog, "scale", Vector2(0.9, 0.9), 0.12)
	t.chain().tween_callback(queue_free)


func show_error(message: String) -> void:
	_error_label.text = message
	_error_label.visible = true
	_send_button.disabled = false
	_sending = false

	var start_x := _dialog.position.x
	var t := create_tween()
	t.tween_property(_dialog, "position:x", start_x - 10.0, 0.05)
	t.tween_property(_dialog, "position:x", start_x + 10.0, 0.05)
	t.tween_property(_dialog, "position:x", start_x - 6.0, 0.05)
	t.tween_property(_dialog, "position:x", start_x, 0.06)

# ------------------------------------------------------------------ رویدادها

func _on_text_changed() -> void:
	# محدود کردن طول متن (TextEdit خودش max_length ندارد)
	if _text_edit.text.length() > MAX_LENGTH:
		var caret_line := _text_edit.get_caret_line()
		var caret_col := _text_edit.get_caret_column()
		_text_edit.text = _text_edit.text.substr(0, MAX_LENGTH)
		_text_edit.set_caret_line(min(caret_line, _text_edit.get_line_count() - 1))
		_text_edit.set_caret_column(caret_col)

	_error_label.visible = false
	_update_counter()


func _update_counter() -> void:
	var n := _text_edit.text.strip_edges().length()
	_counter_label.text = "%s / %s" % [_to_fa(n), _to_fa(MAX_LENGTH)]
	# C12/C13 شمارنده می‌گوید کِی پیام قابل ارسال است (طلایی) و کِی نه (کم‌رنگ)
	_counter_label.add_theme_color_override("font_color", MenuUI.GOLD if n >= MIN_LENGTH else MenuUI.DIM)
	_send_button.disabled = _sending or n < MIN_LENGTH


func _on_send_pressed() -> void:
	if _sending:
		return

	var body := _text_edit.text.strip_edges()
	if body.length() < MIN_LENGTH:
		show_error("متن پیام خیلی کوتاه است (حداقل %s کاراکتر)" % _to_fa(MIN_LENGTH))
		return
	if Global.my_username.is_empty():
		show_error("نام کاربری هنوز از سرور نیامده — چند لحظه بعد دوباره امتحان کن")
		return

	_sending = true
	_send_button.disabled = true
	_hide_keyboard()

	var payload := {
		"username": Global.my_username,
		"player_id": Global.player_id,
		"body": body,
		"platform": OS.get_name(),
		"app_version": ProjectSettings.get_setting("application/config/version", ""),
	}

	var err := _http.request(
		Global.SERVER_BASE + ENDPOINT,
		Global.json_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if err != OK:
		show_error("ارسال نشد — اتصال اینترنت را بررسی کن")
		failed.emit("request_failed")


func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200 or response_code == 201:
		sent.emit(_text_edit.text.strip_edges())
		close()
		return

	var message := "ارسال پیام ناموفق بود (کد %d)" % response_code
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("error"):
		message = str(parsed["error"])

	show_error(message)
	failed.emit(message)


func _on_cancel_pressed() -> void:
	if _closing:
		return
	cancelled.emit()
	close()


## فقط تاچ (ماوسِ شبیه‌سازی‌شده همان لمس را دوباره می‌فرستد)
func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_on_cancel_pressed()


## Back اندروید از profile_menu
func dismiss() -> void:
	_on_cancel_pressed()


func _unhandled_input(event: InputEvent) -> void:
	# دکمه‌ی بازگشت گوشی اندروید
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()


func _press_visual(button: Button, down: bool) -> void:
	button.pivot_offset = button.size * 0.5
	var target := Vector2(0.96, 0.96) if down else Vector2.ONE
	create_tween().tween_property(button, "scale", target, 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# ------------------------------------------------------------------- کمکی‌ها

const FA_DIGITS := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]

func _to_fa(value: int) -> String:
	var out := ""
	for ch in str(value):
		var digit := ch.to_int() if ch >= "0" and ch <= "9" else -1
		out += FA_DIGITS[digit] if digit >= 0 else ch
	return out
