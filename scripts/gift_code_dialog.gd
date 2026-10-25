extends Control
## باکس «اعمال کد هدیه».
##
## استفاده:
##   var dialog := preload("res://secense/gift_code_dialog.tscn").instantiate()
##   add_child(dialog)
##   dialog.redeemed.connect(func(data): ...)   # data: پاسخ سرور (reward, coins, gems)
##   dialog.open()

signal redeemed(data: Dictionary)
signal cancelled

const ENDPOINT := "/gift_code/redeem"
const MIN_LENGTH := 4
const MAX_LENGTH := 32

@onready var _dim: ColorRect = $Dim
@onready var _dialog: PanelContainer = $Dialog
@onready var _code_edit: LineEdit = $Dialog/Margin/Body/CodeEdit
@onready var _error_label: Label = $Dialog/Margin/Body/ErrorLabel
@onready var _submit_button: Button = $Dialog/Margin/Body/Buttons/SubmitButton
@onready var _cancel_button: Button = $Dialog/Margin/Body/Buttons/CancelButton

var _http: HTTPRequest
var _sending := false
var _closing := false

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_response)

	_submit_button.pressed.connect(_on_submit_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_code_edit.text_submitted.connect(func(_t): _on_submit_pressed())
	_code_edit.text_changed.connect(_on_text_changed)
	_dim.gui_input.connect(_on_dim_input)
	UIFx.bind_press_feedback(_submit_button)
	UIFx.bind_press_feedback(_cancel_button)

func open() -> void:
	_code_edit.text = ""
	_error_label.visible = false
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
	if is_instance_valid(self):
		_focus_and_show_keyboard()

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

func _focus_and_show_keyboard() -> void:
	_code_edit.grab_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_show(_code_edit.text, Rect2(),
			DisplayServer.KEYBOARD_TYPE_DEFAULT, MAX_LENGTH, 0, _code_edit.text.length())

func _hide_keyboard() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()

func show_error(message: String) -> void:
	_error_label.text = message
	_error_label.visible = true
	# E11 لرزش خطا هم باید به تنظیم «لرزش گوشی» احترام بگذارد
	LocalSettings.vibrate(45)

	var start_x := _dialog.position.x
	var t := create_tween()
	t.tween_property(_dialog, "position:x", start_x - 10.0, 0.05)
	t.tween_property(_dialog, "position:x", start_x + 10.0, 0.05)
	t.tween_property(_dialog, "position:x", start_x - 6.0, 0.05)
	t.tween_property(_dialog, "position:x", start_x, 0.06)

# ------------------------------------------------------------------ ورودی

## فقط حروف انگلیسی و عدد، همه بزرگ — کاربر نگران حروف کوچک/بزرگ نباشد
func _on_text_changed(new_text: String) -> void:
	_error_label.visible = false
	var clean := ""
	for c in new_text.to_upper():
		if (c >= "A" and c <= "Z") or (c >= "0" and c <= "9"):
			clean += c
	if clean != new_text:
		var caret := _code_edit.caret_column
		_code_edit.text = clean
		_code_edit.caret_column = mini(caret, clean.length())

func _set_sending(sending: bool) -> void:
	_sending = sending
	_submit_button.disabled = sending
	_submit_button.text = "در حال بررسی..." if sending else "ثبت کد"

func _on_submit_pressed() -> void:
	if _sending:
		return
	var code := _code_edit.text.strip_edges()
	if code.length() < MIN_LENGTH:
		show_error("کد را کامل وارد کن")
		return
	if Global.my_username.is_empty():
		show_error("هنوز وارد حساب نشدی")
		return

	_set_sending(true)
	_hide_keyboard()
	var body := JSON.stringify({"username": Global.my_username, "code": code})
	if _http.request(Global.SERVER_BASE + ENDPOINT, Global.json_headers(), HTTPClient.METHOD_POST, body) != OK:
		_set_sending(false)
		show_error("ارتباط با سرور برقرار نشد")

func _on_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_set_sending(false)
	var data: Dictionary = {}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK and typeof(json.data) == TYPE_DICTIONARY:
		data = json.data

	if result != HTTPRequest.RESULT_SUCCESS:
		show_error("ارتباط با سرور برقرار نشد، اینترنتت رو چک کن")
		return
	if code != 200:
		show_error(str(data.get("error", "کد اعمال نشد")))
		return

	Global.apply_purchase_response(data)
	redeemed.emit(data)
	close()

func _on_cancel_pressed() -> void:
	if _sending or _closing:
		return
	cancelled.emit()
	close()

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_cancel_pressed()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		_on_cancel_pressed()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_cancel_pressed()
