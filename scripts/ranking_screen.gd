extends Control
## صحنه‌ی «رتبه بندی» — جدول مقایسه‌ی بازیکن‌ها و شهرها.
##
## کنار صفحه‌ی رنک و شهر زندگی می‌کند و همان منوی کناری را دارد:
##   رنک (rank_screen) · رتبه بندی (همین) · شهر (city)
## از دکمه‌ی رتبه‌بندی نوار پایین منوی اصلی هم باز می‌شود.
##
## چیدمان (مثل طرح):
##   بالا-چپ    برگشت + «رتبه بندی» + ؟ — سکه/جم/پیام از TopBar
##   ستون چپ    منوی کناری: رنک · رتبه بندی · شهر
##   وسط        تب‌ها (رتبه کلی · شهرها · دوستان) + جدول + صفحه‌بندی
##   ستون راست  رتبه فعلی شما · پاداش هفتگی (فقط نفرات ۱ تا ۳) · پایان هفته · شعار
##
## سرور (gun_game_server/handlers_leaderboard.go و weekly_rewards.go):
##   GET /leaderboard?username=&scope=global|cities|friends&page=&limit=
##   → { scope, page, page_size, total, entries, me, my_rank, week, weekly_rewards, no_city? }
## هیچ رتبه، امتیاز یا پاداشی سمت کلاینت حساب نمی‌شود.

const ROW_SCENE := preload("res://secense/ranking_row.tscn")
## E9/E5 پنجره‌ی نزدیک من و فاصله تا نفر بالایی
const PsychSocialRival := preload("res://scripts/psych_social_rival.gd")

const MAIN_MENU_SCENE := "res://secense/main_menu.tscn"
const RANK_SCENE := "res://secense/rank_screen.tscn"
const CITY_SCENE := "res://secense/city.tscn"

const ICON_GEM := preload("res://assets/ui/gem_icon.png")
const ICON_COIN := preload("res://assets/ui/coin_icon.png")
const ICON_XP := preload("res://assets/icons/missions/icon_xp.png")
const ICON_CROWN := preload("res://assets/icons/missions/icon_crown.svg")

## ردیف‌های هر صفحه‌ی جدول
const PAGE_SIZE := 10

## E9 پنجره‌ی «نزدیک من»: چند نفر بالا و پایین بازیکن (به‌جای فقط صدر جدول)
const NEAR_ABOVE := 4
const NEAR_BELOW := 4

## جدول کمتر از این عرض داشت، ستون شهر جمع می‌شود (مثلاً تبلت 4:3)
const COMPACT_TABLE_WIDTH := 540.0

const COLOR_TEXT := Color(0.94, 0.96, 1.0, 1.0)
const COLOR_MUTED := Color(0.62, 0.7, 0.82, 1.0)
const COLOR_GOLD := Color(0.97, 0.78, 0.3, 1.0)
const COLOR_BLUE := Color(0.3, 0.6, 1.0, 1.0)
const PLACE_COLORS := {1: Color(0.97, 0.78, 0.3), 2: Color(0.8, 0.86, 0.95), 3: Color(0.88, 0.56, 0.3)}

const RULES := [
	"امتیاز هر بازیکن همان تعداد کاپ‌های اوست؛ با برد کاپ می‌گیری و با باخت کاپ کم می‌شود.",
	"رتبه کلی: همه‌ی بازیکن‌ها · دوستان: تو و دوستانت · شهرها: مجموع کاپ اعضای هر شهر.",
	"هر هفته (شنبه ساعت ۰۰:۰۰) فقط سه نفر اول «رتبه کلی» پاداش می‌گیرند: جم، تجربه و سکه‌ی زیاد.",
	"پاداش به صندوق پیام‌هایت می‌آید و از همان‌جا دریافتش می‌کنی.",
]

## متن سرستون‌ها در هر تب: [بازیکن، شهر، مدال]
const HEADERS := {
	"global": ["بازیکن", "شهر", "مدال"],
	"friends": ["بازیکن", "شهر", "مدال"],
	"cities": ["شهر", "رهبر", "اعضا"],
}

const _NAV := "Content/Body/Sidebar/"
const _MAIN := "Content/Body/Main/"
const _TABLE := _MAIN + "TablePanel/Margin/Body/"
const _SIDE := "Content/Body/Side/"
const _CARD := _SIDE + "RankCard/Margin/Body/"

@onready var _http: HTTPRequest = $HTTPRequest
@onready var _top_bar: Control = $TopBar
@onready var _content: MarginContainer = $Content
@onready var _header_left: Control = $HeaderLeft
@onready var _back_button: Button = $HeaderLeft/BackButton
@onready var _help_button: TextureButton = $HeaderLeft/HelpButton

# --- منوی کناری ---
@onready var _nav_rank: Button = get_node(_NAV + "NavRank")
@onready var _nav_ranking: Button = get_node(_NAV + "NavRanking")
@onready var _nav_city: Button = get_node(_NAV + "NavCity")

# --- تب‌ها و جدول ---
@onready var _tab_global: Button = get_node(_MAIN + "Tabs/GlobalTab")
@onready var _tab_cities: Button = get_node(_MAIN + "Tabs/CitiesTab")
@onready var _tab_friends: Button = get_node(_MAIN + "Tabs/FriendsTab")
@onready var _table_panel: Control = get_node(_MAIN + "TablePanel")
@onready var _head_name: Label = get_node(_TABLE + "Header/NameHead")
@onready var _head_city: Label = get_node(_TABLE + "Header/CityHead")
@onready var _head_medal: Label = get_node(_TABLE + "Header/MedalHead")
@onready var _scroll: ScrollContainer = get_node(_TABLE + "Scroll")
@onready var _list: VBoxContainer = get_node(_TABLE + "Scroll/List")
@onready var _empty_label: Label = get_node(_TABLE + "EmptyLabel")
@onready var _pinned_me: Button = get_node(_TABLE + "PinnedMe")
@onready var _prev_button: Button = get_node(_TABLE + "Footer/PrevButton")
@onready var _next_button: Button = get_node(_TABLE + "Footer/NextButton")
@onready var _page_label: Label = get_node(_TABLE + "Footer/PageLabel")
@onready var _refresh_button: Button = get_node(_TABLE + "Footer/RefreshButton")

# --- کارت «رتبه فعلی شما» ---
@onready var _badge: TextureRect = get_node(_CARD + "Badge")
@onready var _tier_label: Label = get_node(_CARD + "TierLabel")
@onready var _trophies_label: Label = get_node(_CARD + "TrophyRow/TrophiesLabel")
@onready var _rank_bar: ProgressBar = get_node(_CARD + "Bar")
@onready var _next_label: Label = get_node(_CARD + "NextLabel")
@onready var _standing_label: Label = get_node(_CARD + "StandingLabel")

# --- پاداش هفتگی و پایان هفته ---
@onready var _reward_rows: VBoxContainer = get_node(_SIDE + "RewardsCard/Margin/Body/Rows")
@onready var _rewards_help: TextureButton = get_node(_SIDE + "RewardsCard/Margin/Body/HeaderRow/HelpButton")
@onready var _week_label: Label = get_node(_SIDE + "WeekCard/Margin/Row/Col/WeekLabel")

# --- پنجره‌ی قوانین ---
@onready var _rules_overlay: Control = $RulesOverlay
@onready var _rules_dim: Button = $RulesOverlay/Dim
@onready var _rules_list: VBoxContainer = $RulesOverlay/Center/Panel/Margin/Body/Rules
@onready var _rules_close: Button = $RulesOverlay/Center/Panel/Margin/Body/CloseButton

## تب فعلی: global | cities | friends
var _scope := "global"
var _page := 0
var _total := 0
## آخرین «جایگاه من» که سرور داد (برای ردیف چسبیده به پایین جدول)
var _me: Dictionary = {}

## درخواستی در راه است؛ اگر وسطش تب/صفحه عوض شد، جوابش دور ریخته می‌شود
var _busy := false
var _dirty := false
var _request_key := ""

## لحظه‌ی پایان هفته (یونیکس) — شمارنده هر ۳۰ ثانیه از روی همین به‌روز می‌شود
var _week_end_unix := 0
var _week_timer: Timer = null

var _tab_on: StyleBoxFlat = null
var _tab_off: StyleBoxFlat = null
var _tab_pressed: StyleBoxFlat = null
var _nav_active_style: StyleBoxFlat = null
var _nav_base_style: StyleBox = null
var _toast: Label = null
var _toast_tween: Tween = null
var _compact := false

## E9 حالت «نزدیک من»: جدول به‌جای صفحه‌ی عادی دور و بر جایگاه من را نشان می‌دهد
var _near_mode := false
## پنجره‌ی دور و بر من که در پس‌زمینه گرفته شده: {scope, pos, entries}
var _near_cache: Dictionary = {}
var _near_http: HTTPRequest = null
var _near_key := ""
## ردیف‌هایی که الان در جدول دیده می‌شوند (برای پیدا کردن نفر بالایی)
var _shown_entries: Array = []
## E5 خط «X کاپ تا رد شدن از نفر بالایی» — بالای ردیف چسبیده‌ی من
var _rival_label: Label = null
## دکمه‌ی «جایگاه من» / «صدر جدول» در پایین جدول
var _near_button: Button = null

# ------------------------------------------------------------------ آماده‌سازی

func _ready() -> void:
	# دکمه‌ی Back اینجا باید پنجره را ببندد یا به منوی اصلی برگردد، نه اینکه اپ را ببندد
	get_tree().set_quit_on_go_back(false)
	_http.request_completed.connect(_on_leaderboard_received)

	_style_top_bar()
	UIFx.bind_press(_back_button, _go_back)
	UIFx.bind_press(_help_button, _open_rules)
	UIFx.bind_press(_rewards_help, _open_rules)

	_bind_nav(_nav_rank, _open_rank)
	_bind_nav(_nav_ranking, refresh)
	_bind_nav(_nav_city, _open_city)
	_set_active_nav(_nav_ranking)

	_bind_tab(_tab_global, "global")
	_bind_tab(_tab_cities, "cities")
	_bind_tab(_tab_friends, "friends")
	_apply_tab_styles()

	for button: Button in [_prev_button, _next_button, _refresh_button, _pinned_me, _rules_close]:
		UIFx.bind_press_feedback(button)
	_prev_button.pressed.connect(_change_page.bind(-1))
	_next_button.pressed.connect(_change_page.bind(1))
	_refresh_button.pressed.connect(refresh)
	_pinned_me.pressed.connect(_jump_to_me)
	_rules_close.pressed.connect(_close_rules)
	# لمس بیرون پنجره (روی زمینه‌ی تیره) هم آن را می‌بندد
	_rules_dim.pressed.connect(_close_rules)

	UIScroll.attach(_scroll)
	_build_near_ui()
	_build_rules()
	_rules_overlay.visible = false

	_week_timer = Timer.new()
	_week_timer.wait_time = 30.0
	_week_timer.timeout.connect(_refresh_week_label)
	add_child(_week_timer)
	_week_timer.start()

	_table_panel.resized.connect(_on_table_resized)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()

	_apply_rank_card({})
	_set_loading()
	refresh()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_handle_back()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			# برگشت از پس‌زمینه — جدول ممکن است کهنه باشد
			if is_inside_tree():
				refresh()
		NOTIFICATION_EXIT_TREE:
			get_tree().set_quit_on_go_back(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_handle_back()

var _back_frame := -1

## Back اندروید: اول پنجره‌ی قوانین، بعد منوی اصلی
func _handle_back() -> void:
	# Back اندروید ممکن است هم notification بفرستد هم ui_cancel؛ فقط یک بار
	var frame := Engine.get_process_frames()
	if frame == _back_frame:
		return
	_back_frame = frame
	if _rules_overlay.visible:
		_close_rules()
		return
	_go_back()

func _go_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

# ------------------------------------------------------------------ منوی کناری

func _bind_nav(button: Button, action: Callable) -> void:
	UIFx.bind_press_feedback(button)
	button.pressed.connect(action)

func _set_active_nav(active: Button) -> void:
	if _nav_active_style == null:
		_nav_active_style = _make_box(Color(0.05, 0.2, 0.45, 0.92), Color(0.3, 0.65, 1.0), 2, 6)
		_nav_active_style.shadow_color = Color(0.15, 0.5, 1.0, 0.45)
		_nav_active_style.shadow_size = 8
		_nav_active_style.content_margin_left = 14
		_nav_active_style.content_margin_right = 12
	if _nav_base_style == null:
		_nav_base_style = _nav_rank.get_theme_stylebox("normal")
	for button in [_nav_rank, _nav_ranking, _nav_city]:
		var style: StyleBox = _nav_active_style if button == active else _nav_base_style
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)

func _open_rank() -> void:
	get_tree().change_scene_to_file(RANK_SCENE)

func _open_city() -> void:
	get_tree().change_scene_to_file(CITY_SCENE)

# ------------------------------------------------------------------ تب‌ها

func _bind_tab(button: Button, scope: String) -> void:
	UIFx.bind_press_feedback(button)
	button.pressed.connect(_on_tab_pressed.bind(scope))

func _on_tab_pressed(scope: String) -> void:
	if scope == _scope:
		return
	_scope = scope
	_page = 0
	_near_mode = false
	_apply_tab_styles()
	_set_loading()
	refresh()

## فقط تب فعال آبیِ روشن است (مثل طرح)
func _apply_tab_styles() -> void:
	if _tab_on == null:
		_tab_on = _make_box(Color(0.07, 0.3, 0.72, 0.95), Color(0.45, 0.75, 1.0), 2, 8)
		_tab_on.shadow_color = Color(0.15, 0.5, 1.0, 0.45)
		_tab_on.shadow_size = 8
		_tab_off = _make_box(Color(0.02, 0.05, 0.1, 0.88), Color(0.22, 0.36, 0.58, 0.85), 1, 8)
		_tab_pressed = _make_box(Color(0.05, 0.18, 0.4, 0.95), Color(0.35, 0.7, 1.0), 2, 8)

	var tabs := {"global": _tab_global, "cities": _tab_cities, "friends": _tab_friends}
	for scope: String in tabs:
		var button: Button = tabs[scope]
		var style := _tab_on if scope == _scope else _tab_off
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", _tab_pressed)
		var tint := COLOR_TEXT if scope == _scope else COLOR_MUTED
		for child in button.get_node("Row").get_children():
			(child as CanvasItem).modulate = tint

	var head: Array = HEADERS[_scope]
	_head_name.text = head[0]
	_head_city.text = head[1]
	_head_medal.text = head[2]

# ------------------------------------------------------------------- گرفتن دیتا

func refresh() -> void:
	if _busy:
		_dirty = true
		return

	var page := _page
	var limit := PAGE_SIZE
	if _near_mode:
		var w := PsychSocialRival.window_request(int(_me.get("position", 0)), NEAR_ABOVE, NEAR_BELOW)
		if w.y > 0:
			page = w.x
			limit = w.y
		else:
			_near_mode = false
	var key := _view_key()
	var url := "%s/leaderboard?scope=%s&page=%d&limit=%d" % [Global.SERVER_BASE, _scope, page, limit]
	var username: String = str(Global.my_username)
	if not username.is_empty():
		url += "&username=%s" % username.uri_encode()

	var err := _http.request(url, Global.auth_headers())
	if err != OK:
		push_warning("خطا در درخواست رتبه‌بندی: %d" % err)
		_show_message("اتصال به سرور برقرار نشد")
		return
	_busy = true
	_request_key = key
	_refresh_button.disabled = true

func _on_leaderboard_received(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	_busy = false
	_refresh_button.disabled = false

	# وسط درخواست تب یا صفحه عوض شد — این جواب مال حالت قبلی است
	if _dirty or _request_key != _view_key():
		_dirty = false
		refresh()
		return

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("جدول رتبه‌بندی از سرور نیامد. کد: %d" % response_code)
		_show_message("اتصال به سرور برقرار نشد")
		_show_toast("اتصال به سرور برقرار نشد")
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("پاسخ رتبه‌بندی قابل خواندن نبود")
		_show_message("جدول رتبه‌بندی در دسترس نیست")
		return

	_apply_data(json.data)

# ------------------------------------------------------------------ پر کردن UI

func _apply_data(data: Dictionary) -> void:
	# اگر سرور حالت دیگری برگرداند (مثلاً «دوستان» بدون نام کاربری) همان را نشان می‌دهیم
	var scope := str(data.get("scope", _scope))
	if scope != _scope and HEADERS.has(scope):
		_scope = scope
		_apply_tab_styles()

	_total = int(data.get("total", 0))
	_me = _dict(data.get("me"))
	var entries := _array(data.get("entries"))
	if _near_mode:
		# صفحه‌ی گرفته‌شده اندازه‌ی دیگری دارد؛ فقط دور و بر من نمایش داده می‌شود
		var pos := int(_me.get("position", 0))
		var near := PsychSocialRival.slice_around(entries, pos, NEAR_ABOVE, NEAR_BELOW)
		if not near.is_empty():
			entries = near
			_near_cache = {"scope": _scope, "pos": pos, "entries": near.duplicate()}
		_me["in_page"] = not PsychSocialRival.entry_at(entries, pos).is_empty()
	else:
		_page = int(data.get("page", _page))

	_apply_table(entries, data)
	_apply_pager()
	_apply_rank_card(_dict(data.get("my_rank")))
	_apply_standing(data)
	_apply_rewards(_array(data.get("weekly_rewards")))
	_apply_week(_dict(data.get("week")))

## JSON سرور ممکن است null بفرستد — همیشه دیکشنری/آرایه‌ی معتبر برمی‌گردد
func _dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}

func _array(value: Variant) -> Array:
	return value if typeof(value) == TYPE_ARRAY else []

func _apply_table(entries: Array, data: Dictionary) -> void:
	for child in _list.get_children():
		child.queue_free()

	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row := ROW_SCENE.instantiate()
		_list.add_child(row)
		_setup_row(row, entry)

	_list.modulate.a = 1.0
	_scroll.scroll_vertical = 0
	var empty := entries.is_empty()
	_scroll.visible = not empty
	_empty_label.visible = empty
	if empty:
		_empty_label.text = _empty_message(data)

	_shown_entries = entries
	_apply_pinned_me()
	_update_rival()
	if _near_mode:
		_focus_me()

func _setup_row(row: Node, entry: Dictionary) -> void:
	if _scope == "cities":
		row.setup_city(entry)
	else:
		row.setup_player(entry)
	row.set_compact(_compact)

## اگر جایگاه من در این صفحه نیست، چسبیده به پایین جدول نشانش می‌دهیم.
## زدن رویش جدول را به صفحه‌ی خودم می‌برد.
func _apply_pinned_me() -> void:
	for child in _pinned_me.get_children():
		child.queue_free()
	var pos := int(_me.get("position", 0))
	if _me.is_empty() or pos <= 0 or bool(_me.get("in_page", false)):
		_pinned_me.visible = false
		return
	var row := ROW_SCENE.instantiate()
	_pinned_me.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_setup_row(row, _me)
	_pinned_me.visible = true

func _apply_pager() -> void:
	_refresh_near_button()
	if _near_mode:
		var lo := 0
		var hi := 0
		for e in _shown_entries:
			var p := int((e as Dictionary).get("position", 0))
			lo = p if lo == 0 else mini(lo, p)
			hi = maxi(hi, p)
		_page_label.text = "%s-%s از %s" % [
			MissionArt.fa_number(lo), MissionArt.fa_number(hi), MissionArt.fa_grouped(_total)]
		_prev_button.disabled = lo <= 1
		_next_button.disabled = hi >= _total
		return
	var pages := maxi(1, ceili(float(_total) / float(PAGE_SIZE)))
	var first := _page * PAGE_SIZE + 1
	var last := mini((_page + 1) * PAGE_SIZE, _total)
	if _total <= 0:
		_page_label.text = "۰ از ۰"
	else:
		_page_label.text = "%s-%s از %s" % [
			MissionArt.fa_number(first), MissionArt.fa_number(last), MissionArt.fa_grouped(_total)
		]
	_prev_button.disabled = _page <= 0
	_next_button.disabled = _page >= pages - 1

func _change_page(delta: int) -> void:
	if _near_mode:
		# از «نزدیک من» به صفحه‌بندی عادی، از صفحه‌ی خودم
		_near_mode = false
		@warning_ignore("integer_division")
		_page = maxi(int(_me.get("position", 1)) - 1, 0) / PAGE_SIZE
	var pages := maxi(1, ceili(float(_total) / float(PAGE_SIZE)))
	var target := clampi(_page + delta, 0, pages - 1)
	if target == _page:
		return
	_page = target
	_list.modulate.a = 0.5
	refresh()

## زدن روی ردیف چسبیده‌ی «من» یا «جایگاه من» → E9 پنجره‌ی نزدیک من:
## چند نفر درست بالا و پایین من، با ردیف خودم وسط
func _jump_to_me() -> void:
	var pos := int(_me.get("position", 0))
	if pos <= 0:
		return
	_near_mode = true
	# C12 اگر پنجره در پس‌زمینه گرفته شده، همان لحظه نشان بده
	if _near_cache.get("scope", "") == _scope and int(_near_cache.get("pos", 0)) == pos:
		_me["in_page"] = true
		_apply_table(_near_cache.get("entries", []), {})
		_apply_pager()
		return
	_list.modulate.a = 0.5
	refresh()

## کارت «رتبه فعلی شما» — رنک و کاپ خودم، مستقل از تب جدول
func _apply_rank_card(rank: Dictionary) -> void:
	if rank.is_empty():
		_badge.texture = null
		_tier_label.text = "—"
		_trophies_label.text = "۰"
		_rank_bar.value = 0.0
		_next_label.text = ""
		return

	var tier_id := str(rank.get("tier_id", ""))
	var tier_name := str(rank.get("tier_name", "—"))
	var trophies := int(rank.get("trophies", 0))
	_badge.texture = RankArt.texture_for(tier_id, tier_name)
	_tier_label.text = tier_name
	_trophies_label.text = MissionArt.fa_grouped(trophies)

	var bar_value := 1.0
	var bar_max := 1.0
	if rank.has("next_min"):
		var lo := int(rank.get("tier_min", 0))
		var hi := int(rank.get("next_min", lo + 1))
		bar_max = float(maxi(hi - lo, 1))
		bar_value = float(clampi(trophies - lo, 0, hi - lo))
		_next_label.text = "تا %s: %s کاپ" % [
			str(rank.get("next_tier_name", "رنک بعدی")), MissionArt.fa_grouped(int(rank.get("to_next", 0)))
		]
	else:
		_next_label.text = "بالاترین رنک بازی"
	_rank_bar.max_value = bar_max
	_rank_bar.value = 0.0
	create_tween().tween_property(_rank_bar, "value", bar_value, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## خط پایین کارت: جایگاه من (یا شهرم) در تب فعلی
func _apply_standing(data: Dictionary) -> void:
	if _scope == "cities":
		if bool(data.get("no_city", false)):
			_standing_label.text = "عضو هیچ شهری نیستی"
		elif not _me.is_empty():
			_standing_label.text = "شهر %s: رتبه %s" % [
				str(_me.get("name", "")), MissionArt.fa_grouped(int(_me.get("position", 0)))
			]
		else:
			_standing_label.text = ""
		return
	if _me.is_empty():
		_standing_label.text = ""
		return
	_standing_label.text = "جایگاه تو: %s از %s" % [
		MissionArt.fa_grouped(int(_me.get("position", 0))), MissionArt.fa_grouped(_total)
	]

## «پاداش هفتگی» — فقط نفرات اول تا سوم: جم، تجربه و سکه (اعداد از سرور)
func _apply_rewards(rewards: Array) -> void:
	for child in _reward_rows.get_children():
		child.queue_free()

	var my_position := 0
	if _scope == "global" and not _me.is_empty():
		my_position = int(_me.get("position", 0))

	for reward in rewards:
		if typeof(reward) != TYPE_DICTIONARY:
			continue
		var place := int(reward.get("position", 0))
		_reward_rows.add_child(_make_reward_row(place, reward, place == my_position))

func _make_reward_row(place: int, reward: Dictionary, is_mine: bool) -> Control:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color: Color = PLACE_COLORS.get(place, COLOR_TEXT)
	var style := _make_box(
		Color(0.05, 0.2, 0.45, 0.9) if is_mine else Color(0.02, 0.05, 0.1, 0.85),
		Color(0.3, 0.65, 1.0) if is_mine else Color(color, 0.55), 1, 6)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)

	# تاج رنگی + شماره‌ی رتبه
	var place_box := HBoxContainer.new()
	place_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place_box.add_theme_constant_override("separation", 1)
	place_box.custom_minimum_size = Vector2(34, 0)
	var crown := _make_icon(ICON_CROWN, 18)
	crown.modulate = color
	place_box.add_child(crown)
	place_box.add_child(_make_number(MissionArt.fa_number(place), color, 16))
	row.add_child(place_box)

	row.add_child(_make_chip(ICON_GEM, int(reward.get("gems", 0))))
	row.add_child(_make_chip(ICON_XP, int(reward.get("xp", 0))))
	row.add_child(_make_chip(ICON_COIN, int(reward.get("coins", 0))))
	return panel

func _make_chip(icon: Texture2D, amount: int) -> Control:
	var chip := HBoxContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_theme_constant_override("separation", 2)
	chip.add_child(_make_icon(icon, 16))
	chip.add_child(_make_number(MissionArt.fa_grouped(amount), COLOR_TEXT, 14))
	return chip

func _make_icon(texture: Texture2D, side: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(side, side)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect

func _make_number(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _trophies_label.get_theme_font("font"))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

## کارت «پایان هفته» — زمان تا پرداخت پاداش سه نفر اول
func _apply_week(week: Dictionary) -> void:
	var left := int(week.get("seconds_left", -1))
	_week_end_unix = int(Time.get_unix_time_from_system()) + left if left >= 0 else 0
	_refresh_week_label()

func _refresh_week_label() -> void:
	if _week_end_unix <= 0:
		_week_label.text = "—"
		return
	var left := maxi(_week_end_unix - int(Time.get_unix_time_from_system()), 0)
	@warning_ignore("integer_division")
	var days := left / 86400
	@warning_ignore("integer_division")
	var hours := (left % 86400) / 3600
	@warning_ignore("integer_division")
	var minutes := (left % 3600) / 60
	if days > 0:
		_week_label.text = "%s روز %s ساعت باقی مانده" % [MissionArt.fa_number(days), MissionArt.fa_number(hours)]
	else:
		_week_label.text = "%s ساعت %s دقیقه باقی مانده" % [MissionArt.fa_number(hours), MissionArt.fa_number(minutes)]

# ------------------------------------------------------------- حالت‌های خالی

func _set_loading() -> void:
	for child in _list.get_children():
		child.queue_free()
	_scroll.visible = false
	_pinned_me.visible = false
	_empty_label.visible = true
	_empty_label.text = "در حال گرفتن جدول..."

func _show_message(message: String) -> void:
	_list.modulate.a = 1.0
	if _list.get_child_count() > 0:
		return
	_scroll.visible = false
	_empty_label.visible = true
	_empty_label.text = message

func _empty_message(_data: Dictionary) -> String:
	match _scope:
		"friends":
			return "هنوز دوستی نداری که با او مقایسه شوی."
		"cities":
			return "هنوز شهری در جدول نیست."
		_:
			return "هنوز کسی در جدول نیست."

# ------------------------------------------------- E9/E5 نزدیک من و رقیب بعدی

func _view_key() -> String:
	return "%s:%s" % [_scope, "near" if _near_mode else str(_page)]

func _build_near_ui() -> void:
	var font: Font = (_nav_rank.get_node("Row/Label") as Label).get_theme_font("font")
	_rival_label = Label.new()
	_rival_label.name = "RivalLabel"
	_rival_label.visible = false
	_rival_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rival_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_rival_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rival_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_rival_label.clip_text = true
	_rival_label.add_theme_font_override("font", font)
	_rival_label.add_theme_font_size_override("font_size", 16)
	var body := _pinned_me.get_parent()
	body.add_child(_rival_label)
	body.move_child(_rival_label, _pinned_me.get_index())

	_near_button = _refresh_button.duplicate() as Button
	_near_button.name = "NearButton"
	_near_button.disabled = false
	_near_button.visible = false
	_near_button.custom_minimum_size = Vector2(0, 48)
	# C3 حداقل ناحیه‌ی لمس ~۴۸dp برای دکمه‌های پایین جدول
	for b: Button in [_refresh_button, _prev_button, _next_button]:
		b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 48.0)
	var footer := _refresh_button.get_parent()
	footer.add_child(_near_button)
	footer.move_child(_near_button, _refresh_button.get_index())
	UIFx.bind_press_feedback(_near_button)
	_near_button.pressed.connect(_on_near_button)

	_near_http = HTTPRequest.new()
	_near_http.timeout = 10.0
	add_child(_near_http)
	_near_http.request_completed.connect(_on_near_received)

## «جایگاه من» (رفتن به نزدیک من) ↔ «صدر جدول» (برگشت به صفحه‌ی اول)
func _on_near_button() -> void:
	if _near_mode:
		_near_mode = false
		_page = 0
		_list.modulate.a = 0.5
		refresh()
	else:
		_jump_to_me()

func _refresh_near_button() -> void:
	if _near_button == null:
		return
	var pos := int(_me.get("position", 0))
	var on_first_page := not _near_mode and _page == 0 and pos > 0 and pos <= PAGE_SIZE
	_near_button.visible = pos > 0 and not on_first_page
	_near_button.text = "صدر جدول" if _near_mode else "جایگاه من"

## E5 «فقط X کاپ تا رد شدن از نفر بالایی» — از ردیف‌های همین صفحه یا پنجره‌ی پس‌زمینه
func _update_rival() -> void:
	if _rival_label == null:
		return
	var pos := int(_me.get("position", 0))
	if _me.is_empty() or pos <= 0:
		_rival_label.visible = false
		return
	var above := PsychSocialRival.entry_at(_shown_entries, pos - 1)
	var below := PsychSocialRival.entry_at(_shown_entries, pos + 1)
	var cached: bool = _near_cache.get("scope", "") == _scope and int(_near_cache.get("pos", 0)) == pos
	if cached:
		var near: Array = _near_cache.get("entries", [])
		if above.is_empty():
			above = PsychSocialRival.entry_at(near, pos - 1)
		if below.is_empty():
			below = PsychSocialRival.entry_at(near, pos + 1)
	elif (pos > 1 and above.is_empty()) or (pos == 1 and below.is_empty() and _total > 1):
		_fetch_near(pos)
	var line: Array = PsychSocialRival.rival_line(_me, above, below, "امتیاز" if _scope == "cities" else "کاپ")
	_rival_label.text = str(line[0])
	_rival_label.add_theme_color_override("font_color", line[1])
	_rival_label.visible = not _rival_label.text.is_empty()

## پنجره‌ی دور و بر من در پس‌زمینه — جدولِ نمایش‌داده‌شده دست نمی‌خورد
func _fetch_near(pos: int) -> void:
	var key := "%s:%d" % [_scope, pos]
	if _near_http == null or _near_key == key \
			or _near_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var w := PsychSocialRival.window_request(pos, NEAR_ABOVE, NEAR_BELOW)
	if w.y <= 0:
		return
	var url := "%s/leaderboard?scope=%s&page=%d&limit=%d" % [Global.SERVER_BASE, _scope, w.x, w.y]
	var username: String = str(Global.my_username)
	if not username.is_empty():
		url += "&username=%s" % username.uri_encode()
	if _near_http.request(url, Global.auth_headers()) == OK:
		_near_key = key

func _on_near_received(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var key := _near_key
	_near_key = ""
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		return
	var scope := str(data.get("scope", ""))
	var me := _dict(data.get("me"))
	var pos := int(me.get("position", 0))
	# تب عوض شده یا جایگاهم جابه‌جا شده — این جواب به درد نمی‌خورد
	if scope != _scope or key != "%s:%d" % [scope, int(_me.get("position", 0))]:
		return
	_near_cache = {"scope": scope, "pos": pos,
		"entries": PsychSocialRival.slice_around(_array(data.get("entries")), pos, NEAR_ABOVE, NEAR_BELOW)}
	_update_rival()

## در حالت نزدیک من، ردیف خودم وسط دید بیاید و یک چشمک بزند
func _focus_me() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_scroll):
		return
	var pos := int(_me.get("position", 0))
	for row in _list.get_children():
		if int(row.get("position_in_table")) == pos and not row.is_queued_for_deletion():
			_scroll.ensure_control_visible(row)
			row.flash()
			return

# ------------------------------------------------------------------ قوانین

func _build_rules() -> void:
	var font: Font = (_nav_rank.get_node("Row/Label") as Label).get_theme_font("font")
	for rule in RULES:
		var label := Label.new()
		label.text = "• " + rule
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", COLOR_TEXT)
		_rules_list.add_child(label)

func _open_rules() -> void:
	_rules_overlay.visible = true
	_rules_overlay.modulate.a = 0.0
	create_tween().tween_property(_rules_overlay, "modulate:a", 1.0, 0.18)

func _close_rules() -> void:
	if not _rules_overlay.visible:
		return
	var t := create_tween()
	t.tween_property(_rules_overlay, "modulate:a", 0.0, 0.14)
	t.tween_callback(func() -> void: _rules_overlay.visible = false)

# ------------------------------------------------------------------ نوار بالا

## TopBar مشترک با ظاهر صفحه‌های رنک و شهر: بخش پروفایلش مخفی است چون
## جایش دکمه‌ی برگشت و عنوان است، زمینه شفاف و دکمه‌ها قاب آبی می‌گیرند.
func _style_top_bar() -> void:
	var bg := _top_bar.get_node_or_null("Background") as CanvasItem
	if bg:
		bg.visible = false
	var profile := _top_bar.get_node_or_null("HBoxContainer/Profile") as CanvasItem
	if profile:
		profile.visible = false

	var pill := _make_box(Color(0.02, 0.05, 0.1, 0.88), Color(0.22, 0.36, 0.58, 0.9), 1, 8)
	pill.content_margin_left = 10
	pill.content_margin_right = 6
	pill.content_margin_top = 3
	pill.content_margin_bottom = 3
	for path in ["HBoxContainer/Amounts/Coins", "HBoxContainer/Amounts/Gems"]:
		var p := _top_bar.get_node_or_null(path) as Control
		if p:
			p.add_theme_stylebox_override("panel", pill)

	var box := _make_box(Color(0.02, 0.05, 0.1, 0.88), Color(0.22, 0.36, 0.58, 0.9), 1, 7)
	for path in ["HBoxContainer/HBoxContainer3/MessagesButton",
			"HBoxContainer/HBoxContainer3/FriendsButton",
			"HBoxContainer/HBoxContainer3/SettingsButton"]:
		var button := _top_bar.get_node_or_null(path) as Control
		if button == null:
			continue
		var frame := Panel.new()
		frame.show_behind_parent = true
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel", box)
		button.add_child(frame)
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.offset_left = -5
		frame.offset_top = -5
		frame.offset_right = 5
		frame.offset_bottom = 5

func _make_box(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.corner_detail = 1
	return s

# ------------------------------------------------------------------ ناحیه‌ی امن

## فاصله‌ی ناچ/لبه‌ی خمیده از چهار طرف، به واحدِ ویوپورت (مثل rank_screen.gd)
func _safe_insets() -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var win_pos := DisplayServer.window_get_position()
	var win_size := DisplayServer.window_get_size()
	if safe.size.x <= 0 or win_size.x <= 0:
		return Vector4.ZERO
	var k := get_viewport_rect().size / Vector2(win_size)
	return Vector4(
		maxf(0.0, float(safe.position.x - win_pos.x)) * k.x,
		maxf(0.0, float(safe.position.y - win_pos.y)) * k.y,
		maxf(0.0, float(win_pos.x + win_size.x - safe.end.x)) * k.x,
		maxf(0.0, float(win_pos.y + win_size.y - safe.end.y)) * k.y)

func _apply_safe_area() -> void:
	var ins := _safe_insets()
	var hb := _top_bar.get_node_or_null("HBoxContainer") as Control
	if hb != null:
		hb.offset_left = 12.0 + ins.x
		hb.offset_right = -(12.0 + ins.z)
	var bar_h := _top_bar.offset_bottom - _top_bar.offset_top
	_header_left.position = Vector2(12.0 + ins.x, 5.0 + ins.y)
	_header_left.size = Vector2(_header_left.get_combined_minimum_size().x, bar_h - 8.0)
	_content.add_theme_constant_override("margin_left", int(12.0 + ins.x))
	_content.add_theme_constant_override("margin_right", int(12.0 + ins.z))
	_content.add_theme_constant_override("margin_top", int(bar_h + 10.0 + ins.y))
	_content.add_theme_constant_override("margin_bottom", int(10.0 + ins.w))

## جدول باریک شد (تبلت 4:3) → ستون شهر در سرستون و همه‌ی ردیف‌ها جمع می‌شود
func _on_table_resized() -> void:
	var compact := _table_panel.size.x < COMPACT_TABLE_WIDTH
	if compact == _compact:
		return
	_compact = compact
	_head_city.visible = not compact
	for row in _list.get_children():
		row.set_compact(compact)
	for row in _pinned_me.get_children():
		row.set_compact(compact)

## پیام کوتاه پایین صفحه که خودش محو می‌شود
func _show_toast(text: String) -> void:
	if _toast == null:
		_toast = Label.new()
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast.add_theme_font_override("font", (_nav_rank.get_node("Row/Label") as Label).get_theme_font("font"))
		_toast.add_theme_font_size_override("font_size", 16)
		_toast.add_theme_color_override("font_color", COLOR_TEXT)
		var style := _make_box(Color(0.03, 0.08, 0.18, 0.95), COLOR_BLUE, 1, 8)
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		_toast.add_theme_stylebox_override("normal", style)
		add_child(_toast)
	_toast.text = text
	_toast.reset_size()
	var vp := get_viewport_rect().size
	_toast.position = Vector2((vp.x - _toast.size.x) * 0.5, vp.y * 0.82)
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
