class_name GoogleAuthFlow
extends Node
## جریان «اتصال با گوگل» و «ورود با گوگل» سمت کلاینت (سرور: handlers_auth.go).
##
## بدون پلاگین بومی کار می‌کند، روی اندروید و PC یکسان:
##   1. POST /auth/google/start → آدرس صفحه‌ی گوگل + poll_secret
##   2. صفحه در مرورگر سیستم باز می‌شود (OS.shell_open) — Google ورود داخل
##      WebView را قبول نمی‌کند، مرورگر سیستم امن و مجاز است
##   3. هر چند ثانیه POST /auth/google/poll؛ برگشتن به بازی (RESUMED) هم
##      بلافاصله یک poll می‌زند
##   4. نتیجه با سیگنال finished می‌رسد:
##      {status: "done"|"error", intent, email, username, session_token, player_id, code, error}
##
## خودِ poll_secret فقط در حافظه‌ی همین نود است و هیچ‌جا ذخیره نمی‌شود.

signal finished(result: Dictionary)
## "starting" (در حال گرفتن لینک) | "waiting" (منتظر برگشت از گوگل) | "idle"
signal state_changed(state: String)

const POLL_INTERVAL := 2.5

var intent := ""
var state := "idle"

var _poll_secret := ""
var _deadline_ms := 0
var _start_http: HTTPRequest
var _poll_http: HTTPRequest
var _timer: Timer

func _ready() -> void:
	_start_http = HTTPRequest.new()
	_start_http.timeout = 15.0
	add_child(_start_http)
	_start_http.request_completed.connect(_on_start_completed)

	_poll_http = HTTPRequest.new()
	_poll_http.timeout = 15.0
	add_child(_poll_http)
	_poll_http.request_completed.connect(_on_poll_completed)

	_timer = Timer.new()
	_timer.wait_time = POLL_INTERVAL
	add_child(_timer)
	_timer.timeout.connect(poll_now)

func is_busy() -> bool:
	return state != "idle"

## شروع جریان. p_intent: "link" (وصل کردن همین حساب) یا "login" (پیدا کردن حساب)
func start(p_intent: String) -> void:
	if is_busy():
		return
	intent = p_intent
	var payload := {"intent": intent}
	# ورود دنبال حساب دیگری است؛ اسم حسابِ این دستگاه لازم نیست
	if intent == "link":
		payload["username"] = Global.my_username
	var err := _start_http.request(Global.SERVER_BASE + "/auth/google/start",
		Global.json_headers(), HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		_finish({"status": "error", "error": "اتصال به سرور برقرار نشد"})
		return
	_set_state("starting")

func cancel() -> void:
	_timer.stop()
	_start_http.cancel_request()
	_poll_http.cancel_request()
	_poll_secret = ""
	_set_state("idle")

## بلافاصله یک بار نتیجه را بپرس (دکمه‌ی «برگشتم» یا برگشت از پس‌زمینه)
func poll_now() -> void:
	if state != "waiting" or _poll_secret.is_empty():
		return
	if Time.get_ticks_msec() > _deadline_ms:
		_finish({"status": "error", "code": "expired", "error": "زمان ورود تمام شد؛ دوباره امتحان کن"})
		return
	if _poll_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	_poll_http.request(Global.SERVER_BASE + "/auth/google/poll",
		Global.json_headers(), HTTPClient.METHOD_POST, JSON.stringify({"poll_secret": _poll_secret}))

func _notification(what: int) -> void:
	# بازیکن از مرورگر برگشته — منتظر تایمر نمان
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		poll_now()

func _on_start_completed(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if state != "starting":
		return
	var data := MenuUI.parse_json(body)
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_finish({"status": "error", "code": str(data.get("code", "")),
			"error": MenuUI.server_error(body, code if result == HTTPRequest.RESULT_SUCCESS else 0)})
		return
	_poll_secret = str(data.get("poll_secret", ""))
	var url := str(data.get("auth_url", ""))
	if _poll_secret.is_empty() or not url.begins_with("https://"):
		_finish({"status": "error", "error": "پاسخ سرور نامعتبر بود"})
		return
	_deadline_ms = Time.get_ticks_msec() + int(data.get("expires_in", 600)) * 1000
	OS.shell_open(url)
	_set_state("waiting")
	_timer.start()

func _on_poll_completed(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if state != "waiting":
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		return # اینترنت لحظه‌ای قطع شد — poll بعدی دوباره می‌پرسد
	var data := MenuUI.parse_json(body)
	if code != 200:
		_finish({"status": "error", "code": str(data.get("code", "")), "error": MenuUI.server_error(body, code)})
		return
	if str(data.get("status", "")) == "pending":
		return
	_finish(data)

func _finish(data: Dictionary) -> void:
	_timer.stop()
	_poll_secret = ""
	_set_state("idle")
	if not data.has("intent"):
		data["intent"] = intent
	finished.emit(data)

func _set_state(value: String) -> void:
	if state == value:
		return
	state = value
	state_changed.emit(value)
