extends Node
## تبلیغ جایزه‌دار (Rewarded Video) — «دیدن تبلیغ = ۱۰ قلب».
##
##   Ads.show_rewarded()
##   Ads.reward_granted.connect(func(data): ...)    # data: پاسخ سرور (gems, remaining, ...)
##   Ads.reward_pending.connect(func(message): ...) # جایزه ثبت شد ولی هنوز به سرور نرسیده
##   Ads.reward_failed.connect(func(message): ...)
##
## قلب را سرور می‌دهد (POST /ads/reward/claim) با سقف روزانه و فاصله‌ی حداقلی؛
## کلاینت فقط وقتی درخواست می‌دهد که SDK بگوید ویدیو کامل دیده شد.
##
## روی اندروید تبلیغ توی یک Activity جدا باز می‌شود و درست لحظه‌ای که بسته
## می‌شود بازی تازه دارد resume می‌شود — همان‌جا اولین درخواست HTTP معمولاً
## شکست می‌خورد و قبلاً پیام «ارتباط با سرور برقرار نشد» می‌داد و جایزه کلاً
## از بین می‌رفت. حالا مثل رسید خرید، توکن تبلیغ روی دیسک ذخیره می‌شود و تا
## وقتی سرور جواب قطعی ندهد دوباره فرستاده می‌شود (چند بار با فاصله، با
## resume شدن اپ، و با هر بار باز شدن بازی). سرور همین توکن را dedup می‌کند
## پس ارسال دوباره، جایزه‌ی دوباره نمی‌دهد.
##
## قرارداد پلاگین اندروید (سینگلتون RewardedAds — تپسل یا ادیوری):
##   متدها:   initialize(app_key) · preloadRewarded(zone_id) · showRewarded(zone_id) · setUserId(id)
##   (سورس: android_plugins/rewarded_ads — خروجی: addons/rewarded_ads)
##   سیگنال‌ها: rewarded_completed(ad_token)   ← کاربر ویدیو را تا آخر دید
##             rewarded_closed()               ← بسته شد بدون جایزه
##             rewarded_failed(message)        ← تبلیغی نبود / خطا
##
## روی PC / بیلد دیباگ بدون پلاگین، تبلیغ شبیه‌سازی می‌شود.

signal reward_granted(data: Dictionary)
signal reward_pending(message: String)
signal reward_failed(message: String)

const PROVIDER := "adivery"
const APP_KEY := "f73d60ef-c823-4c01-a64f-c58098b9437d"   # شناسه‌ی اپ در پنل ادیوری
const ZONE_ID := "18a33655-790e-4aa1-8ea0-ed49724eb984"   # شناسه‌ی تبلیغ‌گاه ویدیوی جایزه‌دار
const CLAIM_PATH := "/ads/reward/claim"

const PENDING_PATH := "user://ad_pending.cfg"
const PENDING_SECTION := "rewarded"

## صبر کوتاه بعد از بسته شدن تبلیغ تا Activity بازی کامل resume شود و شبکه بالا بیاید
const RESUME_DELAY := 0.4
## فاصله‌ی تلاش‌های دوباره وقتی شبکه جواب نداد (ثانیه)
const RETRY_DELAYS: Array[float] = [2.0, 5.0, 12.0, 30.0]
## کدهایی که یعنی «سرور تصمیمش را گرفته» — دوباره فرستادن فایده ندارد
const FINAL_CODES: Array[int] = [400, 401, 403, 404, 409, 429]

const PENDING_MESSAGE := "جایزه‌ات ثبت شد، تا چند لحظه‌ی دیگه اضافه می‌شه"

var _plugin: Object = null
var _busy := false
var _claiming := {}   # token -> true (درخواستش در حال رفتن است)
var _attempts := {}   # token -> تعداد تلاش‌های ناموفق

func _ready() -> void:
	if Engine.has_singleton("RewardedAds"):
		_plugin = Engine.get_singleton("RewardedAds")
		_plugin.rewarded_completed.connect(_on_rewarded_completed)
		_plugin.rewarded_closed.connect(_on_rewarded_closed)
		_plugin.rewarded_failed.connect(_on_rewarded_failed)
		_plugin.initialize(APP_KEY)
		# ویدیو از همان اول لود می‌شود تا وقتی بازیکن دکمه را زد منتظر نماند
		_plugin.preloadRewarded(ZONE_ID)

	# جایزه‌های نیمه‌کاره‌ی دفعه‌ی قبل، به محض اینکه نام کاربری معلوم شد
	Global.player_data_loaded.connect(_retry_pending)
	_retry_pending.call_deferred()

func _notification(what: int) -> void:
	# بعد از بسته شدن تبلیغ / برگشتن به اپ، اینترنت دوباره در دسترس است
	if what == NOTIFICATION_APPLICATION_RESUMED:
		_retry_pending()

func is_busy() -> bool:
	return _busy

func show_rewarded() -> void:
	if _busy:
		return
	if Global.my_username.is_empty():
		reward_failed.emit("هنوز وارد حساب نشدی")
		return
	_busy = true

	if _plugin == null:
		if OS.is_debug_build():
			await get_tree().create_timer(1.0).timeout
			_on_rewarded_completed("debug-ad-%d" % Time.get_ticks_usec())
		else:
			_fail("الان تبلیغی برای نمایش نیست")
		return
	_plugin.setUserId(Global.my_username)
	_plugin.showRewarded(ZONE_ID)

func _on_rewarded_completed(ad_token: String) -> void:
	var token := ad_token.strip_edges()
	if token.is_empty():
		# بدون توکن سرور نمی‌تواند تکراری بودن را تشخیص دهد — خودمان یکی می‌سازیم
		token = "local-%d-%d" % [Time.get_ticks_usec(), randi()]
	token = token.left(256)

	# قبل از هر چیز روی دیسک، تا اگر همین‌جا اپ بسته شد جایزه گم نشود
	_save_pending(token)

	# تبلیغ تازه بسته شده و بازی وسط resume است؛ یک لحظه صبر تا شبکه آماده شود
	await get_tree().create_timer(RESUME_DELAY).timeout
	_claim(token, true)

func _on_rewarded_closed() -> void:
	_fail("برای گرفتن جایزه باید ویدیو را تا آخر ببینی")

func _on_rewarded_failed(message: String) -> void:
	push_warning("Ads: " + message)
	_fail("الان تبلیغی برای نمایش نیست، کمی بعد امتحان کن")

# ------------------------------------------------------------------ سرور

func _claim(token: String, user_initiated: bool) -> void:
	if token.is_empty() or _claiming.has(token):
		return
	if Global.my_username.is_empty():
		# هنوز وارد حساب نشده — توکن روی دیسک می‌ماند و بعداً فرستاده می‌شود
		if user_initiated:
			_pending(PENDING_MESSAGE)
		return
	_claiming[token] = true

	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	http.request_completed.connect(_on_claim_response.bind(http, token, user_initiated))
	var body := JSON.stringify({
		"username": Global.my_username,
		"provider": PROVIDER,
		"ad_token": token,
	})
	if http.request(Global.SERVER_BASE + CLAIM_PATH, Global.json_headers(), HTTPClient.METHOD_POST, body) != OK:
		http.queue_free()
		_claiming.erase(token)
		_retry_later(token, user_initiated)

func _on_claim_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray,
		http: HTTPRequest, token: String, user_initiated: bool) -> void:
	http.queue_free()
	_claiming.erase(token)

	var data: Dictionary = {}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK and typeof(json.data) == TYPE_DICTIONARY:
		data = json.data

	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		_forget_pending(token)
		_attempts.erase(token)
		_busy = false
		Global.apply_purchase_response(data)
		# جایزه‌ای که قبلاً واریز شده بود دوباره پاپ‌آپ نشان ندهد
		if user_initiated or not bool(data.get("already_credited", false)):
			reward_granted.emit(data)
		return

	# جواب قطعی سرور (سقف روزانه، تکراری، حساب نامعتبر…) — ارسال دوباره بی‌فایده است
	if result == HTTPRequest.RESULT_SUCCESS and code in FINAL_CODES:
		_forget_pending(token)
		_attempts.erase(token)
		if user_initiated:
			_fail(str(data.get("error", "جایزه ثبت نشد")))
		else:
			_busy = false
		return

	# خطای شبکه یا 5xx: توکن می‌ماند و دوباره فرستاده می‌شود
	push_warning("Ads: claim failed (result=%d code=%d)" % [result, code])
	_retry_later(token, user_initiated)

func _retry_later(token: String, user_initiated: bool) -> void:
	# بازیکن نباید منتظر بماند؛ می‌تواند تبلیغ بعدی را هم ببیند
	_busy = false
	if user_initiated:
		_pending(PENDING_MESSAGE)

	var tries := int(_attempts.get(token, 0))
	if tries >= RETRY_DELAYS.size():
		# فعلاً بس است — با resume شدن اپ یا اجرای بعدی بازی دوباره امتحان می‌شود
		return
	_attempts[token] = tries + 1
	await get_tree().create_timer(RETRY_DELAYS[tries]).timeout
	_claim(token, false)

# ------------------------------------------------------------------ توکن‌های معلق

func _load_pending() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PENDING_PATH)
	return cfg

func _save_pending(token: String) -> void:
	var cfg := _load_pending()
	cfg.set_value(PENDING_SECTION, token.md5_text(), {
		"token": token,
		"username": Global.my_username,
	})
	cfg.save(PENDING_PATH)

func _forget_pending(token: String) -> void:
	var cfg := _load_pending()
	var key := token.md5_text()
	if cfg.has_section_key(PENDING_SECTION, key):
		cfg.erase_section_key(PENDING_SECTION, key)
		cfg.save(PENDING_PATH)

## توکن‌هایی که هنوز سرور تأییدشان نکرده را دوباره می‌فرستد
func _retry_pending() -> void:
	if Global.my_username.is_empty():
		return
	var cfg := _load_pending()
	if not cfg.has_section(PENDING_SECTION):
		return
	for key in cfg.get_section_keys(PENDING_SECTION):
		var entry = cfg.get_value(PENDING_SECTION, key, {})
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		# جایزه مال همان حسابی است که تبلیغ را دیده
		if str(entry.get("username", "")) != Global.my_username:
			continue
		var token := str(entry.get("token", ""))
		_attempts.erase(token)
		_claim(token, false)

# ------------------------------------------------------------------ پیام‌ها

## شکست قطعی — جایزه‌ای در کار نیست
func _fail(message: String) -> void:
	_busy = false
	reward_failed.emit(message)

## شکست موقت — جایزه ثبت شده و خودش بعداً واریز می‌شود
func _pending(message: String) -> void:
	_busy = false
	reward_pending.emit(message)
