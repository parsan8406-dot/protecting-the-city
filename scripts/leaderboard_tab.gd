extends Control
## تب «رتبه بندی» در منوی کاربر — جدول مقایسه‌ی بازیکن‌ها در فصل جاری.
##
## این با صحنه‌ی «رنک» (rank_screen) فرق دارد:
##   رنک        وضعیت فصلی خودم — نردبان رنک و کاپ‌ها
##   رتبه بندی  جدول: من کجای این فصل ایستاده‌ام نسبت به بقیه
##
## چیدمان (راست‌چین):
##   ستون راست  → نوار بالا (سه حالت جهانی/دوستان/کشور)، سکوی سه نفر اول، جدول
##   ستون چپ    → «جایگاه شما» و «پاداش پایان فصل»
##
## همه‌ی اعداد از سرور می‌آیند:
##   GET /leaderboard?username=<me>&scope=global|friends|country&limit=50
##   → { scope, season, total_players, refresh_hours, rewards, entries, me }
##
## هیچ رتبه، امتیاز یا پاداشی سمت کلاینت حساب نمی‌شود — این عمدی است تا
## دستکاری کلاینت روی جدول اثر نداشته باشد (handlers_leaderboard.go).

const ROW_SCENE := preload("res://secense/leaderboard_row.tscn")
const PODIUM_CARD_SCENE := preload("res://secense/leaderboard_podium_card.tscn")
const REWARD_ROW_SCENE := preload("res://secense/leaderboard_reward_row.tscn")

## چند ردیف از سرور خواسته شود (سرور خودش سقف ۱۰۰ دارد)
const ROW_LIMIT := 50

## ترتیب سکو از چپ به راست: سوم، اول، دوم (راست‌چین ⇒ اول وسط، دوم سمت راستش)
const PODIUM_ORDER := [3, 1, 2]

const COLOR_TEXT := Color(0.96, 0.96, 0.97, 1.0)
const COLOR_MUTED := Color(0.72, 0.72, 0.75, 1.0)
const COLOR_GREEN := Color(0.45, 0.82, 0.45, 1.0)
const COLOR_RED := Color(0.85, 0.043, 0.075, 1.0)

@onready var _http: HTTPRequest = $HTTPRequest

# --- نوار بالا ---
@onready var _country_button: Button = $Columns/MainColumn/HeaderPanel/Margin/Row/Tabs/CountryButton
@onready var _friends_button: Button = $Columns/MainColumn/HeaderPanel/Margin/Row/Tabs/FriendsButton
@onready var _global_button: Button = $Columns/MainColumn/HeaderPanel/Margin/Row/Tabs/GlobalButton
@onready var _days_label: Label = $Columns/MainColumn/HeaderPanel/Margin/Row/DaysLabel
@onready var _title_label: Label = $Columns/MainColumn/HeaderPanel/Margin/Row/TitleLabel

# --- سکوی سه نفر اول ---
@onready var _podium: HBoxContainer = $Columns/MainColumn/PodiumPanel/Margin/Podium
@onready var _podium_empty: Label = $Columns/MainColumn/PodiumPanel/Margin/EmptyLabel

# --- جدول ---
@onready var _table_scroll: ScrollContainer = $Columns/MainColumn/TablePanel/Margin/Body/Scroll
@onready var _table_list: VBoxContainer = $Columns/MainColumn/TablePanel/Margin/Body/Scroll/List
@onready var _table_empty: Label = $Columns/MainColumn/TablePanel/Margin/Body/EmptyLabel
@onready var _pinned_me: VBoxContainer = $Columns/MainColumn/TablePanel/Margin/Body/PinnedMe
@onready var _footer_label: Label = $Columns/MainColumn/TablePanel/Margin/Body/FooterLabel

# --- جایگاه شما ---
@onready var _standing_body: VBoxContainer = $Columns/SideColumn/StandingPanel/Margin/Body
@onready var _position_label: Label = $Columns/SideColumn/StandingPanel/Margin/Body/PositionRow/PositionLabel
@onready var _total_label: Label = $Columns/SideColumn/StandingPanel/Margin/Body/PositionRow/TotalLabel
@onready var _standing_bar: ProgressBar = $Columns/SideColumn/StandingPanel/Margin/Body/Bar
@onready var _next_label: Label = $Columns/SideColumn/StandingPanel/Margin/Body/NextLabel

# --- پاداش پایان فصل ---
@onready var _rewards_list: VBoxContainer = $Columns/SideColumn/RewardsPanel/Margin/Body/Scroll/List

## حالت فعلی جدول: global | friends | country
var _scope := "global"
var _busy := false
## آخرین پاسخ سرور (برای اینکه بدانیم چه چیزی نمایش داده شده)
var _data: Dictionary = {}

# استایل دکمه‌های حالت — از خود صحنه خوانده می‌شوند
var _style_on: StyleBox = null
var _style_on_hover: StyleBox = null
var _style_off: StyleBox = null
var _style_off_hover: StyleBox = null

# ------------------------------------------------------------------ آماده‌سازی

func _ready() -> void:
	_http.request_completed.connect(_on_leaderboard_received)

	_style_on = _global_button.get_theme_stylebox("normal")
	_style_on_hover = _global_button.get_theme_stylebox("hover")
	_style_off = _country_button.get_theme_stylebox("normal")
	_style_off_hover = _country_button.get_theme_stylebox("hover")

	_global_button.pressed.connect(_on_scope_pressed.bind("global"))
	_friends_button.pressed.connect(_on_scope_pressed.bind("friends"))
	_country_button.pressed.connect(_on_scope_pressed.bind("country"))

	for button: Button in [_global_button, _friends_button, _country_button]:
		UIFx.bind_press_feedback(button)

	# صفحه‌ها در profile_menu فقط مخفی/نمایان می‌شوند، پس هر بار که تب
	# باز شد جدول را تازه می‌گیریم
	visibility_changed.connect(_on_visibility_changed)

	_apply_tab_styles()
	refresh()

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()

func _on_scope_pressed(scope: String) -> void:
	if scope == _scope:
		return
	_scope = scope
	_apply_tab_styles()
	refresh()

## ظاهر سه دکمه‌ی حالت — فقط حالت فعال قرمز است
func _apply_tab_styles() -> void:
	var buttons := {
		"global": _global_button,
		"friends": _friends_button,
		"country": _country_button,
	}
	for scope: String in buttons:
		var button: Button = buttons[scope]
		var active := scope == _scope
		button.add_theme_stylebox_override("normal", _style_on if active else _style_off)
		button.add_theme_stylebox_override("hover", _style_on_hover if active else _style_off_hover)
		button.add_theme_stylebox_override("pressed", _style_on_hover if active else _style_off_hover)
		button.add_theme_color_override("font_color", COLOR_TEXT if active else COLOR_MUTED)

# ------------------------------------------------------------------- گرفتن دیتا

## گرفتن دوباره‌ی جدول از سرور
func refresh() -> void:
	if _busy:
		return

	var url := "%s/leaderboard?scope=%s&limit=%d" % [Global.SERVER_BASE, _scope, ROW_LIMIT]
	var username: String = str(Global.my_username)
	if not username.is_empty():
		url += "&username=%s" % username.uri_encode()

	var err := _http.request(url, Global.auth_headers())
	if err != OK:
		push_warning("خطا در درخواست رتبه‌بندی: %d" % err)
		return
	_busy = true

func _on_leaderboard_received(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	_busy = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("جدول رتبه‌بندی از سرور نیامد. کد: %d" % response_code)
		_show_message("جدول رتبه‌بندی در دسترس نیست.")
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("پاسخ رتبه‌بندی قابل خواندن نبود")
		_show_message("جدول رتبه‌بندی در دسترس نیست.")
		return

	_data = json.data
	_apply_data(_data)

# ------------------------------------------------------------------ پر کردن UI

func _apply_data(data: Dictionary) -> void:
	_apply_header(data)
	_apply_rewards(data)

	var entries: Array = data.get("entries", [])
	_apply_podium(entries)
	_apply_table(entries)
	_apply_standing(data)

	if entries.is_empty():
		_show_message(_empty_message(data))

## عنوان، شماره‌ی فصل و روزهای باقی‌مانده
func _apply_header(data: Dictionary) -> void:
	var season: Dictionary = data.get("season", {})

	var number := int(season.get("number", 0))
	_title_label.text = "رتبه بندی فصل %s" % _fa(number) if number > 0 else "رتبه بندی فصل"

	var days := int(season.get("days_left", 0))
	_days_label.text = "%s روز تا پایان فصل" % _fa(days) if days > 0 else ""

	var hours := int(data.get("refresh_hours", 0))
	var footer := "کاپ ها با تعداد تجربه ها و پیشرفت های حاصل از فصل بدست می آیند."
	if hours > 0:
		footer += " هر %s ساعت به‌روزرسانی می‌شود." % _fa(hours)
	_footer_label.text = footer

## سکوی سه نفر اول — چیدمان راست‌چین: ۳ چپ، ۱ وسط، ۲ راست
func _apply_podium(entries: Array) -> void:
	for child in _podium.get_children():
		child.queue_free()

	var top: Dictionary = {}
	for entry in entries:
		var pos := int((entry as Dictionary).get("position", 0))
		if pos >= 1 and pos <= 3:
			top[pos] = entry

	_podium.visible = not top.is_empty()
	_podium_empty.visible = top.is_empty()

	var shown := 0
	for place: int in PODIUM_ORDER:
		if not top.has(place):
			continue
		var card := PODIUM_CARD_SCENE.instantiate()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_podium.add_child(card)
		card.setup(top[place])
		# نفر اول اول از همه ظاهر شود
		card.play_pop(0.05 * float(0 if place == 1 else place))
		shown += 1

	if shown == 0:
		_podium.visible = false
		_podium_empty.visible = true

## ردیف‌های جدول
func _apply_table(entries: Array) -> void:
	for child in _table_list.get_children():
		child.queue_free()

	for entry in entries:
		var row := ROW_SCENE.instantiate()
		_table_list.add_child(row)
		row.setup(entry as Dictionary)

	_table_empty.visible = entries.is_empty()
	_table_scroll.visible = not entries.is_empty()
	_table_scroll.scroll_vertical = 0

	_apply_pinned_me()

## اگر ردیف من داخل صفحه‌ی گرفته‌شده نبود، جدا و چسبیده به پایین جدول نشانش می‌دهیم
func _apply_pinned_me() -> void:
	for child in _pinned_me.get_children():
		child.queue_free()

	var me = _data.get("me")
	if typeof(me) != TYPE_DICTIONARY:
		_pinned_me.visible = false
		return

	var standing: Dictionary = me
	if bool(standing.get("in_list", false)) or int(standing.get("position", 0)) <= 0:
		_pinned_me.visible = false
		return

	var entry := standing.duplicate()
	entry["is_me"] = true
	entry["is_online"] = true

	var row := ROW_SCENE.instantiate()
	_pinned_me.add_child(row)
	row.setup(entry)
	_pinned_me.visible = true

## کارت «جایگاه شما»
func _apply_standing(data: Dictionary) -> void:
	var me = data.get("me")
	var total := int(data.get("total_players", 0))

	if typeof(me) != TYPE_DICTIONARY:
		_position_label.text = "—"
		_total_label.text = "از %s بازیکن" % _fa(total)
		_standing_bar.value = 0.0
		_next_label.text = ""
		_set_tile("CupsTile", "—", COLOR_TEXT)
		_set_tile("BestTile", "—", COLOR_TEXT)
		_set_tile("WeekTile", "—", COLOR_TEXT)
		return

	var standing: Dictionary = me
	var pos := int(standing.get("position", 0))
	_position_label.text = _fa(pos) if pos > 0 else "—"
	_total_label.text = "از %s بازیکن" % _fa(total)

	# نوار: چقدر به رتبه‌ی بالاتر نزدیکم
	var points := int(standing.get("points", 0))
	var gap := int(standing.get("points_to_next", 0))
	if standing.has("points_to_next") and points + gap > 0:
		_standing_bar.max_value = float(points + gap)
		_standing_bar.value = 0.0
		create_tween().tween_property(_standing_bar, "value", float(points), 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_next_label.text = "%s امتیاز تا رتبه %s" % [
			_fa(gap), _fa(int(standing.get("next_position", maxi(pos - 1, 1))))
		]
	else:
		# یا اول جدولم یا سرور فاصله را نداد
		_standing_bar.max_value = 1.0
		_standing_bar.value = 1.0 if pos == 1 else 0.0
		_next_label.text = "بالاترین رتبه‌ی جدول" if pos == 1 else ""

	_set_tile("CupsTile", _fa(int(standing.get("cups", 0))), Color(0.91, 0.76, 0.29, 1.0))

	var best := int(standing.get("best_position", 0))
	_set_tile("BestTile", _fa(best) if best > 0 else "—", COLOR_TEXT)

	# تغییر هفته: مثبت یعنی بالا رفته‌ام. سرور تا وقتی اسنپ‌شات هفتگی
	# نداشته باشد این را نمی‌فرستد و اینجا «—» می‌ماند.
	if standing.has("week_delta"):
		var delta := int(standing.get("week_delta", 0))
		var text := "۰"
		var color := COLOR_TEXT
		if delta > 0:
			text = "+%s" % _fa(delta)
			color = COLOR_GREEN
		elif delta < 0:
			text = "-%s" % _fa(absi(delta))
			color = COLOR_RED
		_set_tile("WeekTile", text, color)
	else:
		_set_tile("WeekTile", "—", COLOR_TEXT)

func _set_tile(tile_name: String, value: String, color: Color) -> void:
	var label := _standing_body.get_node_or_null(
		"Tiles/%s/Margin/Body/ValueLabel" % tile_name
	) as Label
	if label == null:
		return
	label.text = value
	label.add_theme_color_override("font_color", color)

## ردیف‌های «پاداش پایان فصل» — متن‌ها از سرور می‌آیند
func _apply_rewards(data: Dictionary) -> void:
	for child in _rewards_list.get_children():
		child.queue_free()

	var my_position := 0
	var me = data.get("me")
	if typeof(me) == TYPE_DICTIONARY:
		my_position = int((me as Dictionary).get("position", 0))

	for reward in data.get("rewards", []):
		var row := REWARD_ROW_SCENE.instantiate()
		_rewards_list.add_child(row)
		row.setup(reward as Dictionary, my_position)
		row.tier_pressed.connect(_on_reward_pressed)

## زدن روی یک ردیف پاداش، جدول را روی همان بازه‌ی رتبه می‌برد.
## اگر آن بازه در صفحه‌ی گرفته‌شده نباشد (مثلاً رتبه ۱۰۱ به بعد وقتی فقط
## ۵۰ ردیف اول آمده) فقط یک توضیح کوتاه در پانویس نشان می‌دهیم.
func _on_reward_pressed(reward: Dictionary) -> void:
	var from_position := int(reward.get("from_position", 0))
	var to_position := int(reward.get("to_position", 0))

	for row in _rewards_list.get_children():
		row.set_selected(row.is_tier(from_position))

	var target: Control = null
	for row in _table_list.get_children():
		var pos := int(row.position_in_table)
		if pos < from_position:
			continue
		if to_position > 0 and pos > to_position:
			break
		target = row
		break

	if target == null:
		_flash_footer("رتبه %s به بعد در این صفحه‌ی جدول نیست." % _fa(from_position))
		return

	_table_scroll.ensure_control_visible(target)
	target.flash()

## پانویس جدول را چند ثانیه با یک پیام کوتاه عوض می‌کند
func _flash_footer(message: String) -> void:
	var previous := _footer_label.text
	_footer_label.text = message
	await get_tree().create_timer(2.5).timeout
	# اگر در این فاصله جدول دوباره ساخته شده باشد، دست نمی‌زنیم
	if is_instance_valid(_footer_label) and _footer_label.text == message:
		_footer_label.text = previous

# ------------------------------------------------------------- حالت‌های خالی

func _show_message(message: String) -> void:
	_table_empty.text = message
	_table_empty.visible = true
	_table_scroll.visible = false
	_podium.visible = false
	_podium_empty.visible = true
	_podium_empty.text = message

func _empty_message(data: Dictionary) -> String:
	if str(data.get("empty_reason", "")) == "country_unset":
		return "کشورت را انتخاب نکرده‌ای، پس جدول کشوری نداری."
	match _scope:
		"friends":
			return "هنوز دوستی نداری که با او مقایسه شوی."
		"country":
			return "هنوز بازیکنی از کشور تو در جدول نیست."
		_:
			return "هنوز کسی در جدول این فصل نیست."

# ------------------------------------------------------------------- کمکی‌ها

## عدد با رقم فارسی و جداکننده‌ی هزارگان (۱۲۳۴۵ → ۱۲٬۳۴۵)
func _fa(value: int) -> String:
	const DIGITS := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var digits := str(absi(value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = DIGITS[digits[i].to_int()] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "٬" + out
	return ("-" if value < 0 else "") + out
