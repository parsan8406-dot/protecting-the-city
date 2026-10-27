extends Node

## آدرس پایه‌ی سرور — همه‌جای پروژه از همین استفاده کنه تا موقع دیپلوی
## فقط یک خط عوض بشه.
const PRODUCTION_SERVER := "https://api.gungamecb.ir"

## آدرسی که واقعاً استفاده می‌شود. در بیلدِ release همیشه سرورِ اصلی است.
## فقط در بیلدِ debug می‌شود با `-- --server=http://127.0.0.1:8791` عوضش کرد،
## تا تست‌هایی که اکانت می‌سازند و وارد صف می‌شوند روی سرورِ محلی بخورند،
## نه روی بازیکن‌های واقعی. (قبلاً ثابت بود و tools/matchmaking_check.gd
## ناچار اکانت‌های تستی را روی سرورِ اصلی می‌ساخت.)
var SERVER_BASE := _pick_server_base()

static func _pick_server_base() -> String:
	if OS.is_debug_build():
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--server="):
				var url := arg.substr(9).strip_edges().trim_suffix("/")
				if url.begins_with("http://") or url.begins_with("https://"):
					return url
	return PRODUCTION_SERVER

## آیا به سرورِ اصلی (بازیکن‌های واقعی) وصلیم؟
func is_production_server() -> bool:
	return SERVER_BASE == PRODUCTION_SERVER

## نام کاربری روی همین دستگاه ذخیره می‌شود تا با هر بار اجرا عوض نشود.
const ACCOUNT_PATH := "user://account.cfg"

## آیتم‌های پیش‌فرضی که هر اکانت از روز اول دارد و هیچ‌وقت قفل نیستند.
## سرور هم دقیقاً همین‌ها را در equip_item مجاز می‌داند.
const DEFAULT_CHARACTER := "skin_default"
const DEFAULT_WEAPONS: Array[String] = ["ak47", "pistol_default"]

## در «بازی سریع» هیچ سروری در کار نیست: تیر و جان و مرگ همه محلی حساب
## می‌شوند. Network با دیدن این پرچم چیزی نمی‌فرستد تا بازیِ آفلاین با دنیای
## آنلاین قاطی نشود.
var offline_mode := false

## سطحِ «بازی سریع»: ۰ آسان، ۱ متوسط، ۲ سخت. صفحه‌ی انتخابِ سطح این را
## پر می‌کند و quick_play.gd هنگام ساختِ هر بات به‌کارش می‌برد.
var quick_play_difficulty := 1

## --- حالتِ بازیِ چندنفره‌ی انتخاب‌شده ---
## مرجعِ واقعی دیتابیس است؛ این‌ها فقط نسخه‌ی کش‌شده برای نمایش روی منو هستند.
signal game_mode_changed

var selected_mode := ""
var selected_mode_name := "عملیات ضربت"
var selected_mode_subtitle := "۴ در ۴"
var trophies := 0
## رنکِ بازیکن (bronze..legend) — از /game_modes. بک‌گراندِ صفحه‌ی انتخابِ
## حالت و تمِ تمرینِ بی‌مسابقه از روی همین انتخاب می‌شود (ThemeArt).
var rank_id := ""

## نسخه‌ی کاملِ حالتِ انتخابی (از /game_modes). صفحه‌ی انتظار از این
## می‌خواند تا برای اسم و تیم‌بندی و نشان دوباره از سرور نپرسد.
var selected_mode_data: Dictionary = {}

## مسابقه‌ای که ماچ‌میکینگ جور کرده — لیست بازیکن‌ها و تیم‌هایشان
var current_match: Dictionary = {}

## تیمِ خودم در مسابقه‌ی جاری («۰» یا «۱»). صفحه‌ی انتظار پرش می‌کند و زمینِ
## بازی از آن می‌فهمد نتیجه‌ی راند برای این بازیکن برد بوده یا باخت.
var my_team := ""


const MODE_CACHE_PATH := "user://selected_mode.cfg"

## حالتِ انتخابی را همه‌جا یکسان می‌کند: کش، دیتای کامل و دکمه‌ی منو.
## روی دستگاه هم ذخیره می‌شود تا با باز شدنِ دوباره‌ی بازی، پیش از رسیدنِ
## پاسخِ سرور، دکمه‌ی منو روی «عملیات ضربت» نپرد.
func apply_selected_mode(m: Dictionary) -> void:
	var mode_id := str(m.get("mode_id", ""))
	if mode_id == "":
		return
	selected_mode = mode_id
	selected_mode_name = str(m.get("name", selected_mode_name))
	selected_mode_subtitle = str(m.get("subtitle", selected_mode_subtitle))
	selected_mode_data = m
	var config := ConfigFile.new()
	config.set_value(_session_key(str(my_username)), "mode", m)
	config.save(MODE_CACHE_PATH)
	game_mode_changed.emit()


func _load_cached_mode() -> void:
	var config := ConfigFile.new()
	if config.load(MODE_CACHE_PATH) != OK:
		return
	var m = config.get_value(_session_key(str(my_username)), "mode", {})
	if typeof(m) != TYPE_DICTIONARY or str(m.get("mode_id", "")) == "":
		return
	selected_mode = str(m["mode_id"])
	selected_mode_name = str(m.get("name", selected_mode_name))
	selected_mode_subtitle = str(m.get("subtitle", selected_mode_subtitle))
	selected_mode_data = m


## از بین حالت‌های سرور، حالتی که باید انتخاب‌شده باشد: همانی که بازیکن
## آخرین بار زده؛ اگر نبود یا «به زودی» شده بود، اولین حالتِ قابل‌بازی.
static func pick_selected_mode(modes: Array, saved_id: String, trophies: int) -> Dictionary:
	var fallback: Dictionary = {}
	for m in modes:
		if bool(m.get("coming_soon", false)):
			continue
		if str(m.get("mode_id", "")) == saved_id:
			return m
		if fallback.is_empty() and trophies >= int(m.get("min_trophies", 0)):
			fallback = m
	return fallback


## بعد از لود شدنِ بازیکن، حالتِ ذخیره‌شده در دیتابیس را می‌گیرد تا منوی
## اصلی و ماچ‌میکینگ همان حالتِ آخر را داشته باشند، نه پیش‌فرض را.
func sync_selected_mode() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(
		func(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
			http.queue_free()
			if code != 200:
				modes_synced.emit()
				return
			var data = JSON.parse_string(body.get_string_from_utf8())
			if typeof(data) != TYPE_DICTIONARY:
				modes_synced.emit()
				return
			trophies = int(data.get("trophies", trophies))
			rank_id = str(data.get("rank_id", rank_id))
			var saved := str(data.get("selected_mode", ""))
			if saved == "":
				saved = selected_mode
			var m := pick_selected_mode(data.get("modes", []), saved, trophies)
			if not m.is_empty():
				apply_selected_mode(m)
			modes_synced.emit())
	var url := "%s/game_modes?username=%s" % [SERVER_BASE, str(my_username).uri_encode()]
	if http.request(url, auth_headers()) != OK:
		http.queue_free()
		modes_synced.emit()


## حالتِ انتخابی با مقدارهای امنِ پیش‌فرض، حتی اگر هنوز از سرور نیامده باشد
func selected_mode_info() -> Dictionary:
	if not selected_mode_data.is_empty():
		return selected_mode_data
	return {
		"mode_id": selected_mode if selected_mode != "" else "strike",
		"name": selected_mode_name,
		"subtitle": selected_mode_subtitle,
		"team_size": 4,
		"accent": "#F0B429",
	}

var current_character = "skin_default"
var current_weapon = "ak47"
var my_username = ""
var player_id: String = ""
var avatar_id: String = ""
## آموزشِ بارِ اول روی همین حساب تمام شده؟ (از /get_player)
var tutorial_done := false

# --- اکانت و امنیت (سرور: handlers_auth.go) ---
# «توکن دستگاه» یک بار موقع ساخت حساب از سرور می‌رسد و این‌جا نگه داشته
# می‌شود. هر درخواستی با auth_headers() همراهش می‌رود. حسابی که به گوگل وصل
# است بدون همین توکن اصلاً قابل استفاده نیست — پس اگر کسی فقط اسم کاربری را
# بداند، به پیشرفت بازیکن دسترسی ندارد.
var session_token: String = ""
## حساب به گوگل وصل است (از /get_player و /auth/status)
var google_linked := false
## سرور این دستگاه را مالکِ حساب می‌شناسد؟ فقط دستگاه تأییدشده می‌تواند
## حساب را به گوگل وصل کند.
var device_verified := false
## سرور گفت حساب محافظت‌شده است و توکن این دستگاه معتبر نیست (401)
var account_locked := false
## دیتای بازیکن حداقل یک بار رسیده؟ (برای تشخیص «موقع باز شدن بازی»)
var _player_loaded_once := false

## حساب محافظت‌شده بدون توکن معتبر — تنظیمات دکمه‌ی «ورود با گوگل» را نشان می‌دهد
signal auth_required
## بعد از ورود با گوگل روی حساب دیگری جابه‌جا شدیم
signal account_switched

const PROFILE_MENU_SCENE := "res://secense/profile_menu.tscn"
const _SESSION_SECTION := "sessions"

## هدرهای هر درخواست HTTP: توکن دستگاه + اسم دستگاه (برای لیست دستگاه‌ها)
func auth_headers(extra: Array = []) -> PackedStringArray:
	var headers := PackedStringArray(extra)
	if not session_token.is_empty():
		headers.append("Authorization: Bearer " + session_token)
	headers.append("X-Device: " + _device_label())
	return headers

## هدر درخواست‌های POST با بدنه‌ی JSON
func json_headers() -> PackedStringArray:
	return auth_headers(["Content-Type: application/json"])

## POSTِ «بفرست و فراموش کن» که صاحبش Global است، نه صحنه.
## برای جاهایی مثل _exit_tree: آن لحظه خودِ صحنه (و root) در حال پاک‌شدن است
## و add_child رویش شکست می‌خورد — درخواست هیچ‌وقت فرستاده نمی‌شد.
func post_detached(path: String, payload: Dictionary) -> void:
	if not is_inside_tree():
		return
	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	http.request_completed.connect(func(_r, _c, _h, _b) -> void: http.queue_free())
	if http.request(SERVER_BASE + path, json_headers(), HTTPClient.METHOD_POST, JSON.stringify(payload)) != OK:
		http.queue_free()

func _device_label() -> String:
	var label := OS.get_name()
	var model := OS.get_model_name()
	if not model.is_empty() and model != "GenericDevice":
		label += " " + model
	# هدر HTTP فقط ASCII قبول می‌کند
	var clean := ""
	for ch in label:
		var code := ch.unicode_at(0)
		if code >= 32 and code < 127:
			clean += ch
	return clean.strip_edges().left(40)

## کلید امن ConfigFile برای هر نام کاربری (اسم فارسی/فاصله‌دار کلید خراب نسازد)
func _session_key(username: String) -> String:
	return "t_" + username.md5_text()

func _load_session_token(username: String) -> String:
	var config := ConfigFile.new()
	if config.load(ACCOUNT_PATH) != OK:
		return ""
	return str(config.get_value(_SESSION_SECTION, _session_key(username), ""))

func _save_session_token(username: String, token: String) -> void:
	var config := ConfigFile.new()
	config.load(ACCOUNT_PATH)
	if token.is_empty():
		if config.has_section_key(_SESSION_SECTION, _session_key(username)):
			config.erase_section_key(_SESSION_SECTION, _session_key(username))
	else:
		config.set_value(_SESSION_SECTION, _session_key(username), token)
	config.save(ACCOUNT_PATH)

## بعد از ورود با گوگل: این دستگاه روی حسابِ پیدا شده می‌نشیند.
## اگر همان حساب فعلی بود فقط توکن تازه ذخیره می‌شود.
func switch_account(username: String, token: String) -> void:
	var clean := username.strip_edges()
	if clean.is_empty() or token.is_empty():
		return
	var same := clean == str(my_username)
	my_username = clean
	session_token = token
	account_locked = false
	google_linked = true
	device_verified = true
	# اسلات‌های دیباگ چندنفره حساب اصلی را بازنویسی نکنند
	if _can_persist_username():
		_save_username(clean)
	_save_session_token(clean, token)
	if not same:
		player_id = ""
		avatar_id = ""
		Network.reset_connection()
		_load_cached_mode()
		sync_selected_mode()
	fetch_player_data()
	account_switched.emit()

## بعد از تغییر نام موفق: اسم تازه روی دستگاه ذخیره می‌شود (وگرنه اجرای
## بعدی با اسم قدیمی یک حساب خالیِ تازه می‌ساخت) و توکن هم با اسم جابه‌جا می‌شود.
func apply_rename(new_name: String) -> void:
	var clean := new_name.strip_edges()
	if clean.is_empty() or clean == str(my_username):
		return
	var old := str(my_username)
	my_username = clean
	if _can_persist_username():
		_save_username(clean)
	if not session_token.is_empty():
		_save_session_token(clean, session_token)
		_save_session_token(old, "")
	# هاب بازیکن‌ها را با اسم می‌شناسد؛ join تازه اسم جدید را ثبت می‌کند
	Network.send_join_request()
	player_data_updated.emit()

## یک بار در هر اجرا اجازه‌ی گرفتنِ اسمِ تازه — وگرنه اگر سرور همیشه ۴۰۱
## بدهد، بازی بی‌نهایت حساب می‌سازد.
var _guest_reroll_used := false

## آیا این ۴۰۱ همان «برخوردِ اسم» است؟ سه شرط با هم:
##   ۱. هنوز اسمِ تازه نگرفته‌ایم،
##   ۲. برای این اسم هیچ توکنی روی دستگاه نداریم (پس هیچ‌وقت مالِ ما نبوده)،
##   ۳. سرور کدِ device_token_required داده، نه auth_required (یعنی حسابِ
##      مهمان است و با گوگل قابل پس‌گرفتن نیست).
func _should_reroll_username(body: PackedByteArray) -> bool:
	if _guest_reroll_used or not session_token.is_empty():
		return false
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return str(data.get("code", "")) == "device_token_required"


func _reroll_guest_username() -> void:
	_guest_reroll_used = true
	var fresh := _new_guest_username()
	push_warning("اسمِ مهمان با حسابِ دیگری برخورد کرد؛ اسمِ تازه: " + fresh)
	my_username = fresh
	session_token = ""
	if _can_persist_username():
		_save_username(fresh)
	fetch_player_data()


## حسابِ محافظت‌شده این دستگاه را نشناخت (توکن نیست یا کنار رفته).
## موقع باز شدن بازی مستقیم به تنظیمات می‌رویم تا «ورود با گوگل» جلوی چشم باشد.
func _on_account_locked() -> void:
	var was_locked := account_locked
	account_locked = true
	auth_required.emit()
	if was_locked or _player_loaded_once:
		return
	requested_profile_tab = "settings"
	var current := get_tree().current_scene
	if current != null and current.scene_file_path == PROFILE_MENU_SCENE:
		open_profile_tab_requested.emit("settings")
	else:
		get_tree().change_scene_to_file.call_deferred(PROFILE_MENU_SCENE)

# انبار بازیکن — چه کاراکترها و سلاح‌هایی را خریده. صفحه‌ی انتخاب کاراکتر و
# فروشگاه از همین می‌خونن که بفهمن یه آیتم قفله یا نه. با هر /get_player و هر
# خرید موفق تازه میشه و inventory_updated فایر میشه.
var owned_characters: Array[String] = []
var owned_weapons: Array[String] = []

# اسکین‌ها (فقط از بتل‌پس) و سطح ارتقای کاراکترها — سرور: skins.go
# owned_skins      اسکین‌هایی که بازیکن دارد
# equipped_skins   آیتم پایه → اسکین انتخاب‌شده (سرور فقط اسکینِ معتبر و مالِ خودش را می‌فرستد)
# item_levels      کاراکتر → سطح ارتقا (نبودن کلید یعنی سطح ۱)
var owned_skins: Array[String] = []
var equipped_skins: Dictionary = {}
var item_levels: Dictionary = {}

# دیتای نمایشی بازیکن — منبع واحد (single source of truth) برای TopBar
# توی همه‌ی صحنه‌ها. هر جا این مقادیر عوض بشن، player_data_updated فایر میشه
# و هر TopBar که روی هر صحنه‌ای instance شده باشه خودکار آپدیت میشه.
var coins: int = 0
var gems: int = 0
var level: int = 1
var display_xp: int = 0
var max_xp: int = 100

# تعداد پیام‌های خوانده‌نشده — نشان قرمز روی آیکون پیام‌ها در TopBar از این می‌خواند.
# صفر یعنی نشان اصلاً نمایش داده نشود.
var unread_messages: int = 0

# تعداد پیام‌های خوانده‌نشده‌ی چت خصوصی (فقط دوستان) — نشان قرمز روی دکمه‌ی
# چت در پایین منوی اصلی از این می‌خواند. این با unread_messages بالا فرق دارد:
# آن یکی صندوق پیام سیستمی است، این یکی گفتگوهای زنده‌ی بازیکن‌هاست.
var unread_chat: int = 0

## تعداد درخواست‌های دوستیِ در انتظار (تب دوستان پرش می‌کند)
var friend_requests_pending: int = 0

func set_friend_requests_pending(count: int) -> void:
	var value := maxi(0, count)
	if value == friend_requests_pending:
		return
	friend_requests_pending = value
	friend_requests_updated.emit(value)

signal player_data_loaded
## /get_player جواب نداد یا خطا داد (صفحه‌ی بارگذاری با این بسته می‌شود)
signal player_data_failed
## درخواستِ /game_modes تمام شد — موفق یا ناموفق
signal modes_synced
signal player_data_updated
## وقتی لیست مالکیت یا آیتم تجهیزشده عوض شد (لود اولیه، خرید، انتخاب کاراکتر)
signal inventory_updated
signal unread_count_updated(count: int)
## درخواست‌های دوستیِ در انتظار — نشان روی تب «دوستان» (از /friends)
signal friend_requests_updated(count: int)
signal chat_unread_updated(count: int)
## وقتی سرور روی WebSocket خبر می‌دهد اتفاقی اجتماعی افتاده
## (درخواست دوستی، پذیرفته‌شدن، هدیه، حذف دوست). تب‌های باز با این
## سیگنال بلافاصله خودشان را رفرش می‌کنند — بدون منتظر ماندنِ تایمر.
signal social_event(kind: String)
signal open_shop_tab_requested(tab_index: int)
signal open_profile_tab_requested(tab_id: String)

# وقتی از یه صحنه‌ی دیگه (مثلاً main_menu) دکمه‌ی پلاس سکه/جم زده میشه، این مقدار
# ست میشه تا shop.gd بدونه موقع باز شدن کدوم تب رو نشون بده. -1 یعنی درخواستی نیست.
var requested_shop_tab: int = -1

# همون منطق برای صحنه‌ی منوی کاربر (profile_menu). رشته‌ی خالی یعنی درخواستی نیست.
# مقادیر معتبر: profile / settings / friends / messages
# (رتبه‌بندی صحنه‌ی جدای ranking_screen است، نه تب این منو)
var requested_profile_tab: String = ""

# تب پیام‌ها با کدام فیلتر باز شود (مثلاً «friend_request» از نوار درخواست‌های
# تب دوستان). رشته‌ی خالی یعنی «همه». تب پیام‌ها مصرفش می‌کند و خالی‌اش می‌کند.
var requested_messages_filter: String = ""

# وقتی از جای دیگری (مثلاً دکمه‌ی پیام در تب دوستان) گفته می‌شود «برو چت و
# گفتگوی این دوست را باز کن»، player_id او اینجا می‌نشیند. صحنه‌ی چت آن را
# مصرف و خالی می‌کند. رشته‌ی خالی یعنی درخواستی نیست.
var requested_chat_peer: String = ""

## باز کردن صحنه‌ی چت روی گفتگوی خصوصی یک دوست
func request_chat_peer(peer_id: String) -> void:
	requested_chat_peer = peer_id

## هر جا (مثلاً آیکون‌های TopBar) که بخواد بگه
## "وقتی رفتیم منوی کاربر، این تب باز باشه" این تابع رو صدا میزنه.
func request_profile_tab(tab_id: String) -> void:
	requested_profile_tab = tab_id
	open_profile_tab_requested.emit(tab_id)

## وقتی از منوی استارت صفحه‌ی ماموریت‌ها باز می‌شه، این می‌گه کدوم تب جلو باشه.
## مقادیر معتبر: daily / season. رشته‌ی خالی یعنی پیش‌فرض (daily).
var requested_missions_tab: String = ""

## کارت پاداش فصل و پنل ماموریت‌های منوی استارت با این می‌گن صفحه‌ی
## ماموریت‌ها روی کدوم تب باز بشه.
func request_missions_tab(tab_id: String) -> void:
	requested_missions_tab = tab_id

## هر جا (مثلاً TopBar) که بخواد بگه "وقتی رفتیم شاپ، این تب باز باشه" این تابع رو صدا میزنه.
func request_shop_tab(tab_index: int) -> void:
	requested_shop_tab = tab_index
	open_shop_tab_requested.emit(tab_index)

## صحنه‌ی آرنا — برای دیباگ چندنفره با آرگومان --autostart مستقیم باز می‌شود
const WORLD_SCENE_PATH := "res://secense/World.tscn"

func _ready():  # 🌟 اصلاح: ready به _ready تغییر کرد
	randomize()
	my_username = _resolve_username()
	session_token = _load_session_token(my_username)
	_load_cached_mode()
	print("👤 username: ", my_username)

	# دیباگ چندنفره: با --autostart به‌جای منوی اصلی مستقیم می‌رویم توی آرنا،
	# تا برای تست شبکه لازم نباشد توی هر نسخه دستی کلیک کنی. بدون این آرگومان
	# هیچ تغییری در رفتار عادی بازی نمی‌دهد.
	if OS.get_cmdline_args().has("--autostart"):
		player_data_loaded.connect(_autostart_world, CONNECT_ONE_SHOT)

	fetch_player_data()


## بعد از رسیدن دیتای بازیکن می‌پریم توی آرنا. یک فریم صبر می‌کنیم تا صحنه‌ی
## فعلی کامل آماده شده باشد، وگرنه change_scene وسط _ready اجرا می‌شود.
func _autostart_world() -> void:
	await get_tree().process_frame
	print("🚀 autostart: ", WORLD_SCENE_PATH)
	LoadingScreen.change_scene(WORLD_SCENE_PATH)


## نام کاربری باید بین اجراها ثابت بماند، وگرنه هر بار یک اکانت تازه در
## دیتابیس ساخته می‌شود و کاراکتر/اسلحه‌ی انتخاب‌شده‌ی دفعه‌ی قبل گم می‌شود.
## ترتیب: آرگومان خط فرمان (برای تست) ← فایل ذخیره‌شده ← ساخت نام جدید.
##
## نامی که از خط فرمان می‌آید عمداً ذخیره *نمی‌شود*: موقع دیباگ چندنفره دو
## نسخه‌ی بازی همزمان روی همین یک فایل می‌نویسند (هم ریسک خراب شدن فایل، هم
## اکانت اصلی‌ات با اکانت دیباگ عوض می‌شد و دفعه‌ی بعد که عادی اجرا می‌کردی
## با اکانت تستی بالا می‌آمد).
func _resolve_username() -> String:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--username="):
			var forced := arg.substr("--username=".length()).strip_edges()
			if forced != "":
				_username_forced = true
				return forced

	var base := ""
	var config := ConfigFile.new()
	if config.load(ACCOUNT_PATH) == OK:
		base = str(config.get_value("account", "username", ""))

	if base == "":
		base = _new_guest_username()
		_save_username(base)

	return _apply_debug_slot(base)


## طولِ دنباله‌ی تصادفیِ اسمِ مهمان. با ۳۶ حرفِ ممکن، ۸ حرف یعنی حدود
## ۲٫۸ هزار میلیارد حالت.
const GUEST_SUFFIX_LEN := 8
const GUEST_ALPHABET := "abcdefghijklmnopqrstuvwxyz0123456789"

## اسمِ حسابِ مهمان.
##
## قبلاً "Player" + randi() % 100000 بود و دو مشکل داشت:
##
## ۱. برخورد: فقط صد هزار اسمِ ممکن. طبق پارادوکسِ تولد، حدودِ چهارصد نصب
##    کافی بود تا دو بازیکن یک اسم بگیرند — و حالا که سرور برای هر حساب
##    توکنِ دستگاه می‌خواهد، نفرِ دوم پشتِ درِ حسابی می‌ماند که مالِ او نیست.
##
## ۲. شمردن: کلِ حساب‌های مهمان با صد هزار درخواست پیدا می‌شدند.
##
## randi() هم مناسبِ این کار نیست (مولدِ بازی، قابلِ پیش‌بینی)، پس از
## Crypto استفاده می‌کنیم که همان مولدِ امنِ سیستم‌عامل است.
func _new_guest_username() -> String:
	var crypto := Crypto.new()
	var bytes := crypto.generate_random_bytes(GUEST_SUFFIX_LEN)
	var suffix := ""
	for b in bytes:
		suffix += GUEST_ALPHABET[b % GUEST_ALPHABET.length()]
	# "Player" + ۸ حرف = ۱۴ حرف، داخلِ سقفِ ۲۰ حرفیِ سرور (handlers_social.go)
	return "Player" + suffix


# -----------------------------------------------------------------------------
# اسلات دیباگ چندنفره
# -----------------------------------------------------------------------------
# وقتی از ادیتور با «Run Multiple Instances» چند نسخه همزمان بالا می‌آید، همه‌شان
# یک user://account.cfg را می‌خوانند و با یک یوزرنیم وارد می‌شوند. سرور بازیکن‌ها
# را با username کلید می‌زند (h.players[username])، پس نسخه‌ی دوم روی اولی
# بازنویسی می‌شود و عملاً یک بازیکن می‌بینی نه دو تا.
#
# برای همین هر نسخه موقع بالا آمدن یک «اسلات» می‌گیرد: اولی اسلات ۰ و اکانت
# اصلی خودت، دومی اسلات ۱ و اکانت «<اسم>_2» و همین‌طور جلو. اینطوری فقط با زدن
# Play دو اکانت مختلف داری، بدون اینکه لازم باشد آرگومان دستی ست کنی.
#
# قفلِ بین‌پروسه‌ای یک پورت لوکال است: اولین نسخه پورت را می‌گیرد، بعدی چون
# نمی‌تواند همان را بگیرد می‌رود سراغ پورت بعدی. تا وقتی پروسه زنده است پورت
# در اختیارش می‌ماند، پس بستن یک نسخه اسلاتش را آزاد می‌کند.

const DEBUG_SLOT_BASE_PORT := 49900
const DEBUG_SLOT_MAX := 8

## سرور را نگه می‌داریم تا پورت آزاد نشود؛ اگر آزاد شود اسلات از دست می‌رود.
var _debug_slot_lock: TCPServer = null
var debug_slot: int = 0
## اسم از --username آمده (دیباگ) — نباید روی account.cfg ذخیره شود
var _username_forced := false

## اسم حساب را روی دستگاه نگه داریم؟ اسلات‌های دیباگ و اسم‌های خط فرمان
## حساب اصلیِ ذخیره‌شده را بازنویسی نمی‌کنند.
func _can_persist_username() -> bool:
	return debug_slot == 0 and not _username_forced


func _apply_debug_slot(base_name: String) -> String:
	# فقط موقع اجرا از ادیتور. بازی منتشرشده هیچ‌وقت اسم اکانت را دستکاری نمی‌کند.
	if not OS.has_feature("editor"):
		return base_name

	debug_slot = _acquire_debug_slot()
	if debug_slot <= 0:
		return base_name

	var name := "%s_%d" % [base_name, debug_slot + 1]
	print("🧪 نسخه‌ی دیباگ #%d — اکانت: %s" % [debug_slot + 1, name])
	return name


func _acquire_debug_slot() -> int:
	var server := TCPServer.new()
	for slot in range(DEBUG_SLOT_MAX):
		if server.listen(DEBUG_SLOT_BASE_PORT + slot, "127.0.0.1") == OK:
			_debug_slot_lock = server
			return slot
	return 0


func _save_username(name: String) -> void:
	var config := ConfigFile.new()
	config.load(ACCOUNT_PATH)  # اگر فایل نبود، خالی می‌ماند
	config.set_value("account", "username", name)
	config.save(ACCOUNT_PATH)


## تعویض اکانت — نام را ذخیره و دیتای بازیکن را دوباره از سرور می‌گیرد.
func set_username(name: String) -> void:
	var clean := name.strip_edges()
	if clean == "" or clean == my_username:
		return
	my_username = clean
	_save_username(clean)
	session_token = _load_session_token(clean)
	fetch_player_data()

## هر بار که موجودی از پاسخِ یک claim/خرید/پاداش (مرجعِ تازه‌ی سرور) ست
## می‌شود یک واحد بالا می‌رود — note_wallet_changed().
##
## چرا: یک /get_player که *قبل* از claim فرستاده شده ولی *بعد* از آن جواب
## می‌دهد، موجودیِ قدیمی را روی موجودیِ تازه می‌نوشت؛ بازیکن صندوق را باز
## می‌کرد، سکه بالا می‌رفت و بلافاصله برمی‌گشت («جایزه نداد»)، و تا رفرشِ
## بعدی همان عددِ کهنه می‌ماند.
var _wallet_epoch := 0

func note_wallet_changed() -> void:
	_wallet_epoch += 1


func fetch_player_data():
	var http_request := HTTPRequest.new()
	add_child(http_request)
	var epoch := _wallet_epoch
	# هر درخواست نود خودش را دارد؛ بعد از جواب آزاد می‌شود تا با هر رفرش
	# یک HTTPRequest تازه روی Global انبار نشود
	http_request.request_completed.connect(
		func(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
			http_request.queue_free()
			if code == 200 and epoch != _wallet_epoch:
				# وسطِ راه موجودی از جای تازه‌تری ست شد؛ این جواب کهنه است
				fetch_player_data()
				return
			_on_request_completed(result, code, headers, body))
	# اینترنتِ موبایل گاهی درخواست را بی‌جواب نگه می‌دارد؛ بی‌نهایت منتظر نمان
	http_request.timeout = 15.0
	var url := SERVER_BASE + "/get_player?username=" + str(my_username).uri_encode()
	var err := http_request.request(url, auth_headers())
	if err != OK:
		http_request.queue_free()
		print("❌ خطا در ارسال درخواست به سرور")
		player_data_failed.emit()

## هر جای دیگه پروژه (مثلاً بعد از خرید موفق توی شاپ) کافیه این تابع صدا زده بشه
## تا آخرین دیتای بازیکن از سرور بیاد و همه‌ی TopBar های روی همه‌ی صحنه‌ها آپدیت بشن.
func refresh_player_data():
	fetch_player_data()

## متنِ مسدودیت از سرور (پنل مدیریت) — صفحه‌ی بارگذاری همین را نشان می‌دهد
var ban_message := ""

func _on_request_completed(result, response_code, headers, body):
	if response_code == 403:
		var err = JSON.parse_string(body.get_string_from_utf8())
		if typeof(err) == TYPE_DICTIONARY and str(err.get("code", "")) == "banned":
			ban_message = str(err.get("error", "حساب تو مسدود شده است"))
			player_data_failed.emit()
			return
	if response_code == 401:
		# سرور این حساب را مالِ دستگاهِ دیگری می‌داند. اگر حسابِ گوگلی باشد
		# راهش «ورود با گوگل» است؛ ولی حسابِ مهمان راهِ بازگشتی ندارد، و
		# تنها حالتی که این‌جا می‌رسیم این است که اسمِ تصادفیِ ما با اسمِ
		# بازیکنِ دیگری یکی شده باشد. در آن صورت یک اسمِ تازه می‌گیریم،
		# چون این حساب از اول هم مالِ ما نبوده.
		if _should_reroll_username(body):
			_reroll_guest_username()
			return
		_on_account_locked()
		player_data_failed.emit()
		return
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var player_data = json.get_data()
			# توکن دستگاه فقط همین یک بار (حساب تازه) در پاسخ می‌آید
			var first_load := not _player_loaded_once
			var fresh_token := str(player_data.get("session_token", ""))
			if not fresh_token.is_empty():
				session_token = fresh_token
				_save_session_token(str(player_data.get("username", my_username)), fresh_token)
			google_linked = bool(player_data.get("google_linked", false))
			device_verified = bool(player_data.get("device_verified", not session_token.is_empty()))
			account_locked = false
			_player_loaded_once = true
			if player_data.has("equipped_character") and player_data["equipped_character"] != "":
				current_character = player_data["equipped_character"]
			if player_data.has("equipped_weapon") and player_data["equipped_weapon"] != "":
				current_weapon = player_data["equipped_weapon"]
			if player_data.has("username") and str(player_data["username"]) != "":
				my_username = str(player_data["username"])
			if player_data.has("player_id"):
				player_id = str(player_data["player_id"])
			if player_data.has("avatar_id"):
				avatar_id = str(player_data["avatar_id"])
			if player_data.has("coins"):
				coins = int(player_data["coins"])
			if player_data.has("gems"):
				gems = int(player_data["gems"])
			if player_data.has("level"):
				level = int(player_data["level"])
			if player_data.has("display_xp"):
				display_xp = int(player_data["display_xp"])
			if player_data.has("max_xp"):
				max_xp = int(player_data["max_xp"])
			if player_data.has("unread_messages"):
				set_unread_count(int(player_data["unread_messages"]))
			tutorial_done = bool(player_data.get("tutorial_done", false))
			owned_characters = _to_id_array(player_data.get("owned_characters", []))
			owned_weapons = _to_id_array(player_data.get("owned_weapons", []))
			_apply_skin_data(player_data)
			if typeof(player_data.get("item_levels")) == TYPE_DICTIONARY:
				item_levels = player_data["item_levels"]
			print("✅ دیتا از دیتابیس لود شد! من در دیتابیس هستم: ", my_username)
			if first_load:
				sync_selected_mode()
			player_data_loaded.emit()
			player_data_updated.emit()
			inventory_updated.emit()
			refresh_unread_count()
			refresh_chat_unread()
		else:
			print("❌ خطا در دریافت اطلاعات. کد ارور: ", response_code)
			player_data_failed.emit()
	else:
		player_data_failed.emit()

# -----------------------------------------------------------------------------
# انبار بازیکن (مالکیت آیتم‌ها)
# -----------------------------------------------------------------------------
# فروشگاه و صفحه‌ی انتخاب کاراکتر هر دو باید بدونن یه آیتم خریده شده یا نه.
# به‌جای اینکه هرکدوم جدا /get_player بزنن، همه از همین‌جا می‌خونن و بعد از
# خرید موفق فقط apply_purchase_response() صدا زده میشه.

## تبدیل خروجی JSON (که Array عمومیه) به لیست رشته‌ی تمیز
func _to_id_array(raw) -> Array[String]:
	var out: Array[String] = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for value in raw:
		var id := str(value).strip_edges()
		if id != "" and not out.has(id):
			out.append(id)
	return out


## آیا بازیکن این آیتم را دارد؟ category یکی از "character" یا "weapon".
## آیتم‌های پیش‌فرض همیشه true برمی‌گردانند.
func owns_item(item_id: String, category: String) -> bool:
	var id := item_id.strip_edges()
	if id.is_empty():
		return false
	if category == "character":
		return id == DEFAULT_CHARACTER or owned_characters.has(id)
	if category == "weapon":
		return DEFAULT_WEAPONS.has(id) or owned_weapons.has(id)
	return false


## آیا این آیتم همین الان تجهیز شده؟
func is_equipped(item_id: String, category: String) -> bool:
	if category == "character":
		return str(current_character) == item_id
	if category == "weapon":
		return str(current_weapon) == item_id
	return false


## بعد از پاسخ موفق /buy_item — سکه/جم و لیست مالکیت را از همان پاسخ به‌روز
## می‌کند تا TopBar و کارت‌ها بدون یک رفت‌وبرگشت اضافه سینک شوند.
func apply_purchase_response(data: Dictionary) -> void:
	if data.has("coins"):
		coins = int(data["coins"])
	if data.has("gems"):
		gems = int(data["gems"])
	if data.has("owned_characters"):
		owned_characters = _to_id_array(data["owned_characters"])
	if data.has("owned_weapons"):
		owned_weapons = _to_id_array(data["owned_weapons"])
	player_data_updated.emit()
	inventory_updated.emit()


# -----------------------------------------------------------------------------
# اسکین‌ها و ارتقا
# -----------------------------------------------------------------------------

func _apply_skin_data(data: Dictionary) -> void:
	if data.has("owned_skins"):
		owned_skins = _to_id_array(data["owned_skins"])
	if typeof(data.get("equipped_skins")) == TYPE_DICTIONARY:
		equipped_skins = {}
		for base in data["equipped_skins"]:
			equipped_skins[str(base)] = str(data["equipped_skins"][base])


func owns_skin(skin_id: String) -> bool:
	return owned_skins.has(skin_id.strip_edges())


## اسکینِ فعال روی یک آیتم پایه. اگر انتخاب نشده یا مال بازیکن نیست خالی
## برمی‌گردد و آیتم با ظاهر پیش‌فرض خودش دیده می‌شود.
func active_skin(base_id: String) -> String:
	var skin := str(equipped_skins.get(base_id, ""))
	return skin if not skin.is_empty() and owns_skin(skin) else ""


## شناسه‌ای که برای «ظاهر» یک آیتم استفاده می‌شود: اسکین فعال یا خود آیتم
func visual_id(base_id: String) -> String:
	var skin := active_skin(base_id)
	return skin if not skin.is_empty() else base_id


func character_level(character_id: String) -> int:
	return maxi(1, int(item_levels.get(character_id, 1)))


## بعد از پاسخ /skins یا /skins/equip
func apply_skin_response(data: Dictionary) -> void:
	_apply_skin_data(data)
	if data.has("equipped_character") and str(data["equipped_character"]) != "":
		current_character = str(data["equipped_character"])
	if data.has("equipped_weapon") and str(data["equipped_weapon"]) != "":
		current_weapon = str(data["equipped_weapon"])
	inventory_updated.emit()
	Network.send_equipment_update()


## بعد از پاسخ موفق /upgrade_character
func apply_upgrade_response(data: Dictionary) -> void:
	if data.has("coins"):
		coins = int(data["coins"])
	if data.has("gems"):
		gems = int(data["gems"])
	if typeof(data.get("item_levels")) == TYPE_DICTIONARY:
		item_levels = data["item_levels"]
	player_data_updated.emit()
	inventory_updated.emit()
	# سطح تازه روی تراز داخل بازی هم اثر دارد
	Network.send_equipment_update()


## بعد از پاسخ موفق /equip_item
func apply_equip_response(data: Dictionary) -> void:
	if data.has("equipped_character") and str(data["equipped_character"]) != "":
		current_character = str(data["equipped_character"])
	if data.has("equipped_weapon") and str(data["equipped_weapon"]) != "":
		current_weapon = str(data["equipped_weapon"])
	inventory_updated.emit()
	# سرور را همان لحظه سینک کن، وگرنه موقع ورود به آرنا تجهیزات قدیمی را
	# پخش می‌کند و انتخاب تازه روی صفحه بازنویسی می‌شود.
	Network.send_equipment_update()

# -----------------------------------------------------------------------------
# پیام‌های خوانده‌نشده
# -----------------------------------------------------------------------------
# سرور تعداد را در همان پاسخ GET /messages برمی‌گرداند (`unread_count`).
# هر جای بازی که چیزی روی پیام‌ها عوض شد (خواندن، حذف، دریافت جایزه)،
# کافی است refresh_unread_count() صدا زده شود تا نشان قرمز TopBar سینک شود.

var _unread_http: HTTPRequest

## گرفتن دوباره‌ی تعداد پیام‌های خوانده‌نشده از سرور
func refresh_unread_count() -> void:
	if my_username.is_empty():
		return

	if _unread_http == null or not is_instance_valid(_unread_http):
		_unread_http = HTTPRequest.new()
		add_child(_unread_http)
		_unread_http.request_completed.connect(_on_unread_received)

	var url := "%s/messages?username=%s" % [SERVER_BASE, my_username.uri_encode()]
	var err := _unread_http.request(url, auth_headers())
	if err != OK:
		push_warning("خطا در گرفتن تعداد پیام‌های خوانده‌نشده: %d" % err)

## وقتی خودِ تب پیام‌ها لیست را گرفت، عدد را از همان‌جا ست می‌کند
## تا یک درخواست اضافه به سرور نرود.
func set_unread_count(count: int) -> void:
	var value := maxi(0, count)
	if value == unread_messages:
		return
	unread_messages = value
	unread_count_updated.emit(unread_messages)

func _on_unread_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return
	set_unread_count(int((json.data as Dictionary).get("unread_count", 0)))

## Network.gd وقتی پیام `notification` از سرور می‌رسد این را صدا می‌زند.
func on_social_event(kind: String) -> void:
	refresh_unread_count()
	refresh_chat_unread()
	social_event.emit(kind)

# -----------------------------------------------------------------------------
# چت زنده
# -----------------------------------------------------------------------------
# نشان قرمز دکمه‌ی چت در منوی اصلی از `unread_chat` می‌خواند. عدد از
# GET /chat/overview می‌آید (فیلد total_unread). صحنه‌ی چت خودش وقتی لیست را
# می‌گیرد این را با set_chat_unread() به‌روز می‌کند تا درخواست اضافه نرود.

var _chat_http: HTTPRequest
## وقتی درخواستِ قبلی هنوز در راه بود دوباره خواسته شد
var _chat_refresh_again := false
## چند ثانیه بعد از آخرین پیام، عدد دوباره از سرور گرفته شود. اگر چند پیام
## پشت سر هم برسد فقط یک درخواست می‌رود.
var _chat_refresh_timer: SceneTreeTimer = null

## گرفتن دوباره‌ی تعداد پیام‌های خوانده‌نشده‌ی چت از سرور
func refresh_chat_unread() -> void:
	if my_username.is_empty():
		return

	if _chat_http == null or not is_instance_valid(_chat_http):
		_chat_http = HTTPRequest.new()
		add_child(_chat_http)
		_chat_http.request_completed.connect(_on_chat_unread_received)

	# منوی اصلی و لودِ دیتای بازیکن هر دو این را تقریباً هم‌زمان صدا می‌زنند.
	# اگر درخواستِ قبلی هنوز در راه است، دومی خطا می‌داد (ERR_BUSY)؛ حالا فقط
	# یادداشت می‌شود و بعد از رسیدنِ جوابِ اولی یک بار دیگر فرستاده می‌شود.
	if _chat_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		_chat_refresh_again = true
		return

	var url := "%s/chat/overview?username=%s" % [SERVER_BASE, my_username.uri_encode()]
	var err := _chat_http.request(url, auth_headers())
	if err != OK:
		push_warning("خطا در گرفتن تعداد پیام‌های چت: %d" % err)

## وقتی صحنه‌ی چت خودش لیست را گرفت، عدد را از همان‌جا ست می‌کند
func set_chat_unread(count: int) -> void:
	var value := maxi(0, count)
	if value == unread_chat:
		return
	unread_chat = value
	chat_unread_updated.emit(unread_chat)

func _on_chat_unread_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _chat_refresh_again:
		_chat_refresh_again = false
		refresh_chat_unread.call_deferred()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return
	# نشان منوی اصلی فقط پیام‌های دوستان را می‌شمارد، نه جهانی و شهر
	set_chat_unread(int((json.data as Dictionary).get("private_unread", 0)))

## Network.gd وقتی پیام چت از سرور می‌رسد این را صدا می‌زند.
## با کمی تأخیر عدد را می‌گیریم تا رگبار پیام‌های چت جهانی
## تبدیل به رگبار درخواست HTTP نشود.
func on_chat_message() -> void:
	if _chat_refresh_timer != null:
		return
	_chat_refresh_timer = get_tree().create_timer(2.0)
	_chat_refresh_timer.timeout.connect(func() -> void:
		_chat_refresh_timer = null
		refresh_chat_unread())

# r3 social (E1): صفحه‌ی شهر با «چت شهر» صحنه‌ی چت را روی کانال شهر باز می‌کند.
# صحنه‌ی چت مصرف و خالی‌اش می‌کند. مقادیر: "" / "global" / "city" / "private"
var requested_chat_channel: String = ""
