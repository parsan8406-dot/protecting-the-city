extends Control
## باکس «ارسال هدیه به دوست».
##
## بازیکن هر مقدار سکه/جم که بخواهد وارد می‌کند (تا سقف سرور)، و بابتش
## مقدار خیلی کمی تجربه می‌گیرد. هر ۲۴ ساعت فقط یک هدیه مجاز است —
## این محدودیت روی سرور اعمال می‌شود (`POST /friends/gift` → کد ۴۲۹)
## و اینجا فقط پیامش نشان داده می‌شود.
##
## استفاده:
##   var dialog := preload("res://secense/gift_dialog.tscn").instantiate()
##   add_child(dialog)
##   dialog.sent.connect(func(id, coins, gems, xp): ...)
##   dialog.open(friend_id, friend_username)

signal sent(friend_id: String, coins: int, gems: int, xp: int)
signal failed(reason: String)
signal cancelled

const ENDPOINT := "/friends/gift"

# --- باید با ثابت‌های handlers_social.go یکی باشد ---
const MAX_COINS := 5000
const MAX_GEMS := 200
const XP_PER_COINS := 500  # هر ۵۰۰ سکه → ۱ تجربه
const XP_PER_GEMS := 10    # هر ۱۰ جم    → ۱ تجربه
const XP_MAX := 15

@onready var _dim: ColorRect = $Dim
@onready var _dialog: PanelContainer = $Dialog
@onready var _title_label: Label = $Dialog/Margin/Body/TitleLabel
@onready var _balance_label: Label = $Dialog/Margin/Body/BalanceLabel
@onready var _coin_edit: LineEdit = $Dialog/Margin/Body/CoinRow/AmountEdit
@onready var _coin_max_button: Button = $Dialog/Margin/Body/CoinRow/MaxButton
@onready var _gem_edit: LineEdit = $Dialog/Margin/Body/GemRow/AmountEdit
@onready var _gem_max_button: Button = $Dialog/Margin/Body/GemRow/MaxButton
@onready var _xp_label: Label = $Dialog/Margin/Body/XpLabel
@onready var _error_label: Label = $Dialog/Margin/Body/ErrorLabel
@onready var _send_button: Button = $Dialog/Margin/Body/Buttons/SendButton
@onready var _cancel_button: Button = $Dialog/Margin/Body/Buttons/CancelButton

var _friend_id: String = ""
var _http: HTTPRequest
var _sending := false

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

	_send_button.pressed.connect(_on_send_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_dim.gui_input.connect(_on_dim_input)

	_coin_edit.text_changed.connect(_on_amount_changed)
	_gem_edit.text_changed.connect(_on_amount_changed)
	_coin_edit.text_submitted.connect(func(_t: String) -> void: _gem_edit.grab_focus())
	_gem_edit.text_submitted.connect(func(_t: String) -> void: _on_send_pressed())

	_coin_max_button.pressed.connect(func() -> void:
		UIFx.press(_coin_max_button)
		_coin_edit.text = str(mini(Global.coins, MAX_COINS))
		_on_amount_changed(""))
	_gem_max_button.pressed.connect(func() -> void:
		UIFx.press(_gem_max_button)
		_gem_edit.text = str(mini(Global.gems, MAX_GEMS))
		_on_amount_changed(""))

	for button: Button in [_send_button, _cancel_button, _coin_max_button, _gem_max_button]:
		button.button_down.connect(_press_visual.bind(button, true))
		button.button_up.connect(_press_visual.bind(button, false))

func open(friend_id: String, friend_username: String) -> void:
	_friend_id = friend_id
	_sending = false
	_error_label.visible = false
	_coin_edit.text = ""
	_gem_edit.text = ""
	# E10 عمل متقابل: هدیه با پیام به صندوق دوست می‌رسد
	_title_label.text = "هدیه‌ی امروز برای %s" % friend_username
	_balance_label.text = "موجودی تو : %d سکه  |  %d جم" % [Global.coins, Global.gems]
	_refresh_preview()

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

func close() -> void:
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
	_sending = false
	_refresh_preview()

	var start_x := _dialog.position.x
	var t := create_tween()
	t.tween_property(_dialog, "position:x", start_x - 10.0, 0.05)
	t.tween_property(_dialog, "position:x", start_x + 10.0, 0.05)
	t.tween_property(_dialog, "position:x", start_x - 6.0, 0.05)
	t.tween_property(_dialog, "position:x", start_x, 0.06)

# ------------------------------------------------------------------ ورودی‌ها

## فقط رقم قبول می‌کند و از سقف‌ها جلوتر نمی‌رود
func _on_amount_changed(_text: String) -> void:
	_error_label.visible = false
	_sanitize(_coin_edit, MAX_COINS, Global.coins)
	_sanitize(_gem_edit, MAX_GEMS, Global.gems)
	_refresh_preview()

func _sanitize(edit: LineEdit, hard_max: int, balance: int) -> void:
	var digits := ""
	for ch in edit.text:
		if ch >= "0" and ch <= "9":
			digits += ch

	# صفرهای ابتدایی حذف شوند («007» → «7»)
	while digits.length() > 1 and digits.begins_with("0"):
		digits = digits.substr(1)

	if not digits.is_empty():
		var value := mini(int(digits), mini(hard_max, maxi(balance, 0)))
		digits = str(value)

	if digits != edit.text:
		var caret := edit.caret_column
		edit.text = digits
		edit.caret_column = mini(caret, digits.length())

func _coins() -> int:
	return int(_coin_edit.text) if _coin_edit.text.is_valid_int() else 0

func _gems() -> int:
	return int(_gem_edit.text) if _gem_edit.text.is_valid_int() else 0

## همان فرمول سرور (`giftXP` در handlers_social.go) — فقط برای پیش‌نمایش.
## تقسیم صحیح عمدی است (بخش اعشاری دور ریخته می‌شود، دقیقاً مثل Go).
func _preview_xp(coins: int, gems: int) -> int:
	@warning_ignore("integer_division")
	var xp := coins / XP_PER_COINS + gems / XP_PER_GEMS
	if xp < 1 and (coins > 0 or gems > 0):
		xp = 1
	return mini(xp, XP_MAX)

func _refresh_preview() -> void:
	var coins := _coins()
	var gems := _gems()
	var empty := coins == 0 and gems == 0

	_send_button.disabled = _sending or empty
	_xp_label.text = "هدیه‌ای انتخاب نشده" if empty \
		else "به صندوق پیام دوستت می‌رسد — تو هم %d تجربه می‌گیری" % _preview_xp(coins, gems)

# ------------------------------------------------------------------ ارسال

func _on_send_pressed() -> void:
	UIFx.press(_send_button)
	if _sending:
		return

	var coins := _coins()
	var gems := _gems()
	if coins == 0 and gems == 0:
		show_error("مقدار هدیه را وارد کن")
		return
	if coins > Global.coins or gems > Global.gems:
		show_error("موجودی کافی نداری")
		return

	_sending = true
	_send_button.disabled = true
	_hide_keyboard()

	var payload := {
		"username": Global.my_username,
		"friend_id": _friend_id,
		"coins": coins,
		"gems": gems,
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
	var parsed = JSON.parse_string(body.get_string_from_utf8())

	if response_code == 200 or response_code == 201:
		var xp := 0
		if typeof(parsed) == TYPE_DICTIONARY:
			xp = int((parsed as Dictionary).get("xp_gained", 0))
		Global.refresh_player_data()
		sent.emit(_friend_id, _coins(), _gems(), xp)
		close()
		return

	# ۴۲۹ یعنی هنوز ۲۴ ساعت از هدیه‌ی قبلی نگذشته — متن دقیقش از سرور می‌آید
	var message := "ارسال هدیه ناموفق بود (کد %d)" % response_code
	if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("error"):
		message = str((parsed as Dictionary)["error"])
	show_error(message)
	failed.emit(message)

# ------------------------------------------------------------------ کمکی‌ها

func _hide_keyboard() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()

func _on_cancel_pressed() -> void:
	UIFx.press(_cancel_button)
	cancelled.emit()
	close()

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_on_cancel_pressed()
	elif event is InputEventMouseButton and event.pressed:
		_on_cancel_pressed()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# accept_event فقط برای gui_input است؛ این‌جا باید خودِ ویوپورت خبر شود
		# تا Back پروفایل‌منو همین پنجره را دوباره نبندد
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()

func _press_visual(button: Button, down: bool) -> void:
	button.pivot_offset = button.size * 0.5
	var target := Vector2(0.96, 0.96) if down else Vector2.ONE
	create_tween().tween_property(button, "scale", target, 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
