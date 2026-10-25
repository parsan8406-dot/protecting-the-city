extends Node
## خرید درون‌برنامه‌ای قلب — یک رابط برای بازار و مایکت.
##
## بقیه‌ی بازی فقط این را صدا می‌زند:
##   Billing.purchase("gems_100")
##   Billing.purchase_completed.connect(func(product_id, data): ...)
##   Billing.purchase_failed.connect(func(product_id, message): ...)
##
## کدام فروشگاه؟ از روی feature tag خروجی:
##   Export preset بازار  → Custom Features: bazaar
##   Export preset مایکت  → Custom Features: myket
##
## جریان: پرداخت در اپِ فروشگاه ← رسیدِ امضاشده ← POST /iap/verify ← سرور
## امضای فروشگاه را با کلیدِ عمومی‌اش چک می‌کند ← فقط بعد از تأیید سرور consume.
## تأیید **فقط** روی سرور است (gun_game_server/iap_signature.go)؛ این فایل و
## پلاگین هیچ کلید یا تصمیمی ندارند و رسید را دست‌نخورده می‌فرستند.
## رسید با player_id خریدار (developerPayload) به همان حساب گره می‌خورد.
## توکن تا تأیید سرور روی دیسک می‌ماند؛ اگر وسط کار اینترنت قطع شد یا اپ
## بسته شد، دفعه‌ی بعد خودکار دوباره فرستاده می‌شود و قلب از دست نمی‌رود.
##
## قرارداد پلاگین اندروید (سینگلتون BazaarBilling / MyketBilling):
##   متدها:   startConnection() · purchase(product_id, payload) · consume(token) · queryPurchases()
##   سیگنال‌ها: connection_succeeded() · connection_failed(message)
##             purchase_succeeded(product_id, token, purchase_data, signature)
##             purchase_cancelled(product_id) · purchase_failed(product_id, message)
##             purchases_queried(purchases: Array[{product_id, purchase_token, purchase_data, signature}])
##
## فقط روی PC/ادیتور (بیلد دیباگ، بدون پلاگین) پرداخت شبیه‌سازی می‌شود (توکن debug-...)
## که سرور فقط با IAP_ALLOW_DEBUG=1 قبولش می‌کند. روی گوشی همیشه پلاگین لازم است.
##
## ⚠️ برای مایکت/بازار فقط خروجیِ Release بفرستید و قبلش چک کنید:
##   bash tools/check_store_apk.sh build/NirooyeShahr-Myket.apk

signal purchase_completed(product_id: String, data: Dictionary)
signal purchase_failed(product_id: String, message: String)
## مرحله‌ی فعلیِ خرید برای نمایش به بازیکن («در حال اتصال به مایکت...»)
signal purchase_status(product_id: String, message: String)

const STORE_BAZAAR := "bazaar"
const STORE_MYKET := "myket"

const PENDING_PATH := "user://iap_pending.cfg"
## چقدر موقعِ خرید منتظرِ اتصال به فروشگاه بمانیم. پلاگین اول سرویس را
## امتحان می‌کند (۸ ثانیه) و بعد مسیرِ broadcast (ping + billingSupport، هر کدام ۸ ثانیه)
const CONNECT_WAIT := 26.0
const VERIFY_PATH := "/iap/verify"
## بعد از plugin.purchase اگر تا این مدت نه صفحه‌ی پرداخت باز شد نه جوابی آمد،
## خرید را تمام‌شده حساب کن — وگرنه بازی برای همیشه «در حال پردازش» می‌ماند.
const STORE_OPEN_WAIT := 15.0
## بعد از برگشت از صفحه‌ی پرداختِ فروشگاه، چقدر منتظرِ نتیجه‌اش بمانیم
const STORE_RESULT_GRACE := 5.0

var store: String = STORE_BAZAAR
var _plugin: Object = null
var _connected := false
var _connecting := false
var _busy_product := ""
var _verifying := {}  # token -> آیا خریدِ همین الانِ بازیکن است (user_initiated)
var _last_connection_error := ""
var _purchase_seq := 0         # شماره‌ی خریدِ جاری؛ تایمرهای خریدِ قبلی را بی‌اثر می‌کند
var _awaiting_store := false   # plugin.purchase زده شده و فروشگاه هنوز نتیجه نداده
var _left_for_store := false   # صفحه‌ی پرداختِ فروشگاه باز شد (بازی از فوکوس خارج شد)

func _ready() -> void:
	store = STORE_MYKET if OS.has_feature(STORE_MYKET) else STORE_BAZAAR
	var singleton := "MyketBilling" if store == STORE_MYKET else "BazaarBilling"
	if Engine.has_singleton(singleton):
		_plugin = Engine.get_singleton(singleton)
		_plugin.connection_succeeded.connect(_on_connection_succeeded)
		_plugin.connection_failed.connect(_on_connection_failed)
		_plugin.purchase_succeeded.connect(_on_store_purchase_succeeded)
		_plugin.purchase_cancelled.connect(_on_store_purchase_cancelled)
		_plugin.purchase_failed.connect(_on_store_purchase_failed)
		_plugin.purchases_queried.connect(_on_purchases_queried)
		_connect_store()
	elif OS.has_feature("android"):
		# APK بدونِ پلاگینِ پرداخت ساخته شده (export plugin اجرا نشده) — این بیلد
		# نباید به فروشگاه برود. tools/check_store_apk.sh همین را قبل از ارسال چک می‌کند.
		push_error("Billing: %s singleton is missing from this APK — in-app purchase cannot work" % singleton)

	# خریدهای نیمه‌کاره‌ی دفعه‌ی قبل، بعد از اینکه نام کاربری معلوم شد
	Global.player_data_loaded.connect(_retry_pending)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if _awaiting_store:
				_left_for_store = true
		NOTIFICATION_APPLICATION_FOCUS_IN:
			if _awaiting_store and _left_for_store:
				_watch_store_return(_purchase_seq)
		NOTIFICATION_APPLICATION_RESUMED:
			if _awaiting_store and _left_for_store:
				_watch_store_return(_purchase_seq)
			# مثلاً بازیکن رفت در بازار وارد حسابش شد و برگشت — دوباره وصل شو
			if not _connected:
				_connect_store()
			_retry_pending()

func is_busy() -> bool:
	return not _busy_product.is_empty()

## شروع خرید یک محصول (product_id همان شناسه‌ی پیشخوان فروشگاه)
func purchase(product_id: String) -> void:
	if is_busy():
		return
	if Global.my_username.is_empty() or Global.player_id.is_empty():
		purchase_failed.emit(product_id, "هنوز وارد حساب نشدی")
		return

	_busy_product = product_id
	_purchase_seq += 1
	var seq := _purchase_seq

	if _plugin == null:
		# شبیه‌سازی فقط روی PC/ادیتور. قبلاً روی هر بیلدِ Debug (حتی روی گوشی)
		# خرید جعلی می‌ساخت: بیلدهای دیباگی که بدونِ پلاگینِ پرداخت برای مایکت و
		# بازار فرستاده شدند هیچ‌وقت صفحه‌ی پرداخت را باز نکردند، فقط توکنِ debug
		# به سرور رفت و «پرداخت تأیید نشد» گرفت — دلیلِ ردِ برنامه.
		if OS.is_debug_build() and not OS.has_feature("android"):
			await get_tree().create_timer(0.6).timeout
			_on_store_purchase_succeeded(product_id, "debug-%d-%d" % [Time.get_ticks_usec(), randi()])
		else:
			_finish_failed(product_id, "پرداخت در این نسخه فعال نیست؛ نسخه‌ی تازه‌ی بازی را از %s نصب کن (کد: no_billing_plugin)" % store_title())
		return

	if not _connected:
		# قبلاً اینجا بلافاصله خطا می‌داد، حتی وقتی اتصال فقط کمی دیر رسیده بود.
		# حالا دوباره وصل می‌شود و چند ثانیه منتظرِ نتیجه می‌ماند.
		purchase_status.emit(product_id, "در حال اتصال به %s..." % store_title())
		_connect_store()
		var waited := 0.0
		while _connecting and waited < CONNECT_WAIT:
			await get_tree().create_timer(0.25).timeout
			waited += 0.25
		if not _connected:
			_finish_failed(product_id, _connection_error_text(_last_connection_error))
			return
	purchase_status.emit(product_id, "در حال باز کردن صفحه‌ی پرداخت %s..." % store_title())
	_awaiting_store = true
	_left_for_store = false
	# player_id داخلِ رسیدِ امضاشده برمی‌گردد؛ سرور رسیدِ حسابِ دیگری را قبول نمی‌کند
	_plugin.purchase(product_id, Global.player_id)
	_watch_store_open(seq)

## اگر فروشگاه هیچ‌وقت صفحه‌ی پرداخت را باز نکرد و جوابی هم نداد
## (سرویسِ فروشگاه گیر کرد)، خرید را آزاد کن تا بازیکن دوباره امتحان کند.
func _watch_store_open(seq: int) -> void:
	await get_tree().create_timer(STORE_OPEN_WAIT).timeout
	if seq != _purchase_seq or not _awaiting_store or _left_for_store:
		return
	_awaiting_store = false
	_finish_failed(_busy_product, "%s جواب نداد؛ یک بار اپ %s را باز کن و دوباره امتحان کن" % [store_title(), store_title()])

## بازیکن از صفحه‌ی پرداخت برگشت ولی نتیجه‌ای نرسید (مثلاً با دکمه‌ی Home
## بیرون رفت و از لانچر برگشت) — بعد از کمی صبر، خرید را لغوشده حساب کن.
## اگر نتیجه دیرتر برسد هنوز پردازش می‌شود (رسید ذخیره و به سرور فرستاده می‌شود).
func _watch_store_return(seq: int) -> void:
	await get_tree().create_timer(STORE_RESULT_GRACE).timeout
	if seq != _purchase_seq or not _awaiting_store:
		return
	_awaiting_store = false
	_finish_failed(_busy_product, "خرید لغو شد")

## پیامِ قابل‌فهم برای بازیکن + کدِ فنی (برای گزارشِ خطا)
func _connection_error_text(reason: String) -> String:
	var title := store_title()
	var text: String
	if reason == "store_not_installed":
		text = "برای خرید، اپ %s باید روی گوشی نصب باشد" % title
	elif reason.begins_with("billing_not_supported"):
		text = "پرداختِ %s فعال نیست؛ در اپ %s وارد حسابت شو و %s را به‌روز کن" % [title, title, title]
	elif reason in ["timeout", "bind_failed", "disconnected"]:
		text = "%s جواب نداد؛ یک بار اپ %s را باز کن و دوباره امتحان کن" % [title, title]
	else:
		text = "اتصال به %s برقرار نشد، دوباره امتحان کن" % title
	if not reason.is_empty():
		text += " (کد: %s)" % reason
	return text

func store_title() -> String:
	return "مایکت" if store == STORE_MYKET else "بازار"

# ------------------------------------------------------------------ فروشگاه

func _connect_store() -> void:
	if _plugin == null or _connected or _connecting:
		return
	_connecting = true
	_plugin.startConnection()

func _on_connection_succeeded() -> void:
	_connecting = false
	_connected = true
	# خریدهایی که پرداخت شده ولی consume نشده (مثلاً اپ وسط کار بسته شده)
	_plugin.queryPurchases()

func _on_connection_failed(message: String) -> void:
	_connecting = false
	_connected = false
	_last_connection_error = message
	push_warning("Billing: connection failed: " + message)

func _on_store_purchase_succeeded(product_id: String, token: String,
		purchase_data: String = "", signature: String = "") -> void:
	_awaiting_store = false
	_save_pending(token, product_id, purchase_data, signature)
	_verify(token, product_id, purchase_data, signature, true)

func _on_store_purchase_cancelled(product_id: String) -> void:
	if not _awaiting_store and not is_busy():
		return  # نتیجه‌ی دیررسِ خریدی که قبلاً لغوشده حساب شد
	_awaiting_store = false
	_finish_failed(product_id, "خرید لغو شد")

func _on_store_purchase_failed(product_id: String, message: String) -> void:
	push_warning("Billing: purchase failed: " + message)
	_awaiting_store = false
	if message == "already_owned":
		# یک پرداختِ قبلی هنوز تحویل نشده؛ پلاگین queryPurchases زده و همین الان
		# دوباره به سرور فرستاده می‌شود — قلب‌ها بدون پرداختِ دوباره می‌رسند.
		_finish_failed(product_id, "یک خریدِ قبلی هنوز تحویل نشده بود؛ در حال اضافه‌کردنش هستیم")
		return
	if message == "not_connected":
		_connected = false
		_connect_store()
		_finish_failed(product_id, "اتصال به %s قطع شد؛ دوباره امتحان کن" % store_title())
		return
	if message == "launch_failed":
		_finish_failed(product_id, "صفحه‌ی پرداخت %s باز نشد؛ %s را به‌روز کن و دوباره امتحان کن (کد: %s)" % [store_title(), store_title(), message])
		return
	# buy_intent:4 یعنی محصول در پنل فروشگاه تعریف/فعال نیست؛ کد برای گزارش خطا لازم است
	_finish_failed(product_id, "پرداخت انجام نشد (کد: %s)" % message)

func _on_purchases_queried(purchases: Array) -> void:
	for p in purchases:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var token := str(p.get("purchase_token", ""))
		var product_id := str(p.get("product_id", ""))
		if token.is_empty():
			continue
		_save_pending(token, product_id, str(p.get("purchase_data", "")), str(p.get("signature", "")))
	_retry_pending()

# ------------------------------------------------------------------ سرور

func _verify(token: String, product_id: String, purchase_data: String, signature: String,
		user_initiated: bool) -> void:
	if token.is_empty():
		if user_initiated:
			_finish_failed(product_id, "پرداخت انجام نشد")
		return
	if _verifying.has(token):
		# همین رسید از مسیرِ دیگری (queryPurchases بعد از برگشت به بازی) در راه
		# سرور است. قبلاً اینجا بی‌صدا برمی‌گشت و چون جوابِ آن درخواست «خریدِ
		# کاربر» حساب نمی‌شد، _busy_product هیچ‌وقت خالی نمی‌شد و هر خریدِ بعدی
		# «فروشگاه در حال پردازش یک خرید دیگر است» می‌گرفت.
		if user_initiated:
			_verifying[token] = true
		return
	if Global.my_username.is_empty():
		if user_initiated:
			_finish_failed(product_id, "پرداخت ثبت شد؛ بعد از ورود به حساب قلب‌ها اضافه می‌شن")
		return
	_verifying[token] = user_initiated

	var http := HTTPRequest.new()
	http.timeout = 20.0
	add_child(http)
	http.request_completed.connect(_on_verify_response.bind(http, token, product_id))
	var body := JSON.stringify({
		"username": Global.my_username,
		"store": store,
		"product_id": product_id,
		"purchase_token": token,
		"purchase_data": purchase_data,
		"signature": signature,
	})
	var err := http.request(Global.SERVER_BASE + VERIFY_PATH, Global.json_headers(), HTTPClient.METHOD_POST, body)
	if err != OK:
		http.queue_free()
		_verifying.erase(token)
		if user_initiated:
			_finish_failed(product_id, "پرداخت ثبت شد؛ به محض وصل شدن اینترنت قلب‌ها اضافه می‌شن")

func _on_verify_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray,
		http: HTTPRequest, token: String, product_id: String) -> void:
	http.queue_free()
	var user_initiated: bool = _verifying.get(token, false)
	_verifying.erase(token)

	var data: Dictionary = {}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK and typeof(json.data) == TYPE_DICTIONARY:
		data = json.data

	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		_remove_pending(token)
		if _plugin != null:
			_plugin.consume(token)
		Global.apply_purchase_response(data)
		if user_initiated:
			_busy_product = ""
		if user_initiated or not bool(data.get("already_credited", false)):
			purchase_completed.emit(product_id, data)
		return

	# رسید قطعاً نامعتبر است — دوباره فرستادنش فایده ندارد
	if result == HTTPRequest.RESULT_SUCCESS and code in [400, 402, 403]:
		_remove_pending(token)
		if user_initiated:
			_finish_failed(product_id, str(data.get("error", "پرداخت تأیید نشد")))
		return

	# خطای شبکه/سرور: توکن می‌ماند و بعداً دوباره فرستاده می‌شود
	if user_initiated:
		_finish_failed(product_id, "پرداخت ثبت شد؛ به محض وصل شدن اینترنت قلب‌ها اضافه می‌شن")

func _finish_failed(product_id: String, message: String) -> void:
	_busy_product = ""
	purchase_failed.emit(product_id, message)

# ------------------------------------------------------------------ توکن‌های معلق

func _load_pending() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(PENDING_PATH)
	return cfg

func _save_pending(token: String, product_id: String, purchase_data: String = "",
		signature: String = "") -> void:
	var cfg := _load_pending()
	var key := token.md5_text()
	# اگر قبلاً با رسیدِ کامل ذخیره شده، نسخه‌ی ناقص (مثلاً توکنِ debug) رویش ننویسد
	var old = cfg.get_value(store, key, {})
	if purchase_data.is_empty() and typeof(old) == TYPE_DICTIONARY:
		purchase_data = str(old.get("purchase_data", ""))
		signature = str(old.get("signature", ""))
	cfg.set_value(store, key, {"token": token, "product_id": product_id,
		"purchase_data": purchase_data, "signature": signature})
	cfg.save(PENDING_PATH)

func _remove_pending(token: String) -> void:
	var cfg := _load_pending()
	if cfg.has_section_key(store, token.md5_text()):
		cfg.erase_section_key(store, token.md5_text())
		cfg.save(PENDING_PATH)

func _retry_pending() -> void:
	if Global.my_username.is_empty():
		return
	var cfg := _load_pending()
	if not cfg.has_section(store):
		return
	for key in cfg.get_section_keys(store):
		var entry = cfg.get_value(store, key, {})
		if typeof(entry) == TYPE_DICTIONARY:
			_verify(str(entry.get("token", "")), str(entry.get("product_id", "")),
				str(entry.get("purchase_data", "")), str(entry.get("signature", "")), false)
