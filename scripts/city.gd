extends Control
## صحنه‌ی «شهر» (کلن) — از دکمه‌ی شهر در نوار پایین منوی اصلی و از منوی
## کناری صفحه‌ی رنک («رنک · رتبه بندی · شهر») باز می‌شود.
##
## توجه: این شهر هیچ ربطی به مود بازی «عملیات امتیاز شهر» ندارد.
##
## چیدمان (مثل صفحه‌ی رنک):
##   بالا-چپ   برگشت + «شهرها» + ؟ (قوانین شهر) — سکه/جم/پیام از TopBar
##   ستون چپ   منوی کناری: رنک · رتبه بندی · شهر
##   وسط       یکی از دو صفحه:
##               BrowsePage  لیست شهرها + جستجو (وقتی عضو هیچ شهری نیستم)
##               CityPage    کارت شهر + بنر (عضویت / ترک شهر) + فقط لیست اعضا
##   ستون راست پاداش‌های شهر (تجربه و سکه) · اطلاعات شهر یا ساخت شهر · مزایا
##
## سه حالت:
##   BROWSE  عضو نیستم          → لیست شهرها؛ ضربه روی یک شهر → VIEW
##   VIEW    عضو نیستم، یک شهر را نگاه می‌کنم → CityPage با دکمه‌ی عضویت
##   MINE    عضو یک شهرم        → CityPage با دکمه‌ی قرمز «ترک شهر»
##                                  رهبر: ویرایش شهر (نام، تگ، نشان، ...)
##                                  رهبر و معاون: درخواست‌های عضویت
##
## سرور (gun_game_server/handlers_clan.go و handlers_social.go):
##   GET  /clan?username=[&clan_id=]      شهر من (یا یک شهر مشخص) + اعضا
##   GET  /clans?username=&search=&page=  لیست شهرها
##   GET  /clan/requests?username=        صف درخواست عضویت
##   POST /clan/create /clan/update /clan/join /clan/leave /clan/respond
##        /clan/kick /clan/role /clan/transfer   ·   POST /friends/request

const MAIN_MENU_SCENE := "res://secense/main_menu.tscn"
const RANK_SCENE := "res://secense/rank_screen.tscn"
const RANKING_SCENE := "res://secense/ranking_screen.tscn"

## اندازه‌ی هر صفحه‌ی لیست — باید با ClanBrowsePageSize در models.go یکی باشد
const PAGE_SIZE := 30

## E1/E9 سهم من و تازه‌واردها
const PsychSocialCity := preload("res://scripts/psych_social_city.gd")
const ICON_XP := preload("res://assets/icons/missions/icon_xp.png")
const ICON_COIN := preload("res://assets/ui/coin_icon.png")
const ICON_CROWN := preload("res://assets/icons/missions/icon_crown.svg")
const ICON_FRIENDS := preload("res://assets/ui/profile_menu/icon_friends.svg")
const ICON_SHIELD := preload("res://assets/icons/missions/icon_emblem.svg")
const ICON_STAR := preload("res://assets/icons/missions/icon_star.svg")
const ICON_LOCK := preload("res://assets/icons/missions/icon_lock.svg")
const ICON_CHAT := preload("res://assets/ui/profile_menu/icon_global_chat.svg")
const ICON_RANKING := preload("res://assets/ui/profile_menu/icon_ranking.svg")
const ICON_CLAN := preload("res://assets/ui/profile_menu/icon_clan.svg")

const RULES := [
	"هر بازیکن در یک زمان فقط عضو یک شهر می‌تواند باشد.",
	"ساخت شهر %s سکه هزینه دارد و سازنده‌اش رهبر شهر می‌شود.",
	"شهر عمومی: هر کس سطحش کافی باشد مستقیم عضو می‌شود.",
	"شهر خصوصی: درخواست عضویت باید توسط رهبر یا معاون تأیید شود.",
	"رهبر می‌تواند نام، تگ، شعار، نشان و شرایط ورود شهر را عوض کند (تغییر نام یا تگ %s سکه).",
	"رهبر و معاون می‌توانند اعضای پایین‌تر از خودشان را اخراج کنند؛ ارتقا و سپردن رهبری فقط دست رهبر است.",
	"اگر رهبر شهر را ترک کند، رهبری به قدیمی‌ترین معاون (یا عضو) می‌رسد؛ با رفتن آخرین نفر شهر منحل می‌شود.",
]

const BENEFITS := [
	["friends", "هم‌تیمی و دوست‌های جدید"],
	["chat", "چت اختصاصی شهر"],
	["ranking", "رقابت در رتبه‌بندی شهرها"],
	["shield", "نشان شهر کنار اسمت"],
]

enum Mode { BROWSE, VIEW, MINE }

const _NAV := "Content/Body/Sidebar/"
const _BROWSE := "Content/Body/Main/BrowsePage/"
const _CITY := "Content/Body/Main/CityPage/"
const _HEADER := _CITY + "HeaderCard/Margin/Row/"
const _BANNER := _CITY + "Banner/Margin/Row/"
const _SIDE := "Content/Body/Side/"

@onready var _http: HTTPRequest = $HTTPRequest
@onready var _action_http: HTTPRequest = $ActionHTTPRequest
@onready var _requests_http: HTTPRequest = $RequestsHTTPRequest
@onready var _refresh_timer: Timer = $RefreshTimer
@onready var _search_timer: Timer = $SearchTimer

@onready var _top_bar: Control = $TopBar
@onready var _content: MarginContainer = $Content
@onready var _header_left: Control = $HeaderLeft
@onready var _back_button: Button = $HeaderLeft/BackButton
@onready var _title_label: Label = $HeaderLeft/TitleLabel
@onready var _help_button: TextureButton = $HeaderLeft/HelpButton

@onready var _nav_rank: Button = get_node(_NAV + "NavRank")
@onready var _nav_ranking: Button = get_node(_NAV + "NavRanking")
@onready var _nav_city: Button = get_node(_NAV + "NavCity")

# --- لیست شهرها ---
@onready var _browse_page: Control = get_node(_BROWSE.trim_suffix("/"))
@onready var _search_edit: LineEdit = get_node(_BROWSE + "Toolbar/SearchEdit")
@onready var _count_label: Label = get_node(_BROWSE + "Toolbar/CountLabel")
@onready var _browse_scroll: ScrollContainer = get_node(_BROWSE + "ListPanel/Margin/Body/Scroll")
@onready var _browse_list: VBoxContainer = get_node(_BROWSE + "ListPanel/Margin/Body/Scroll/List")
@onready var _browse_empty: Label = get_node(_BROWSE + "ListPanel/Margin/Body/EmptyLabel")

# --- صفحه‌ی شهر ---
@onready var _city_page: Control = get_node(_CITY.trim_suffix("/"))
@onready var _emblem: CityEmblem = get_node(_HEADER + "Emblem")
@onready var _name_label: Label = get_node(_HEADER + "Info/NameRow/NameLabel")
@onready var _tag_label: Label = get_node(_HEADER + "Info/NameRow/TagLabel")
@onready var _slogan_label: Label = get_node(_HEADER + "Info/SloganLabel")
@onready var _rank_value: Label = get_node(_HEADER + "Info/StatsRow/RankStat/Col/Value")
@onready var _members_value: Label = get_node(_HEADER + "Info/StatsRow/MembersStat/Col/Value")
@onready var _level_value: Label = get_node(_HEADER + "Info/StatsRow/LevelStat/Col/Value")
@onready var _tools: Control = get_node(_HEADER + "Tools")
@onready var _edit_button: Button = get_node(_HEADER + "Tools/EditButton")
@onready var _requests_button: Button = get_node(_HEADER + "Tools/RequestsButton")
@onready var _requests_badge: Control = get_node(_HEADER + "Tools/RequestsButton/Badge")
@onready var _requests_badge_label: Label = get_node(_HEADER + "Tools/RequestsButton/Badge/Count")
@onready var _banner_title: Label = get_node(_BANNER + "TextCol/TitleLabel")
@onready var _banner_sub: Label = get_node(_BANNER + "TextCol/SubLabel")
@onready var _action_button: Button = get_node(_BANNER + "ActionButton")
@onready var _column_header: HBoxContainer = get_node(_CITY + "MembersPanel/Margin/Body/ColumnHeader")
@onready var _member_scroll: ScrollContainer = get_node(_CITY + "MembersPanel/Margin/Body/Scroll")
@onready var _member_list: VBoxContainer = get_node(_CITY + "MembersPanel/Margin/Body/Scroll/List")
@onready var _member_empty: Label = get_node(_CITY + "MembersPanel/Margin/Body/EmptyLabel")

# --- ستون راست ---
@onready var _reward_tiles: HBoxContainer = get_node(_SIDE + "RewardsPanel/Margin/Body/Tiles")
@onready var _info_panel: Control = get_node(_SIDE + "InfoPanel")
@onready var _info_rows: VBoxContainer = get_node(_SIDE + "InfoPanel/Margin/Body/Rows")
@onready var _create_panel: Control = get_node(_SIDE + "CreatePanel")
@onready var _create_cost: Label = get_node(_SIDE + "CreatePanel/Margin/Body/CostLabel")
@onready var _create_button: Button = get_node(_SIDE + "CreatePanel/Margin/Body/CreateButton")
@onready var _benefit_rows: VBoxContainer = get_node(_SIDE + "BenefitsPanel/Margin/Body/Rows")

var _mode: Mode = Mode.BROWSE
## شهری که از لیست باز کرده‌ام (حالت VIEW). خالی = شهر خودم / لیست
var _viewing_id := ""
## کدام درخواست روی _http در راه است: "mine" · "view" · "list"
var _pending_kind := ""

var _clan: Dictionary = {}
var _members: Array = []
var _members_signature := ""
var _clans: Array = []
var _pending_clan_ids: Array = []
var _page := 0
var _has_more := false
var _requests: Array = []

var _busy := false
var _success_message := ""
var _after_action: Callable = Callable()

var _modal: CityModal = null
var _requests_modal: CityModal = null
var _toast: Label = null
var _toast_tween: Tween = null
var _nav_active_style: StyleBoxFlat = null
var _nav_base_style: StyleBox = null

# ------------------------------------------------------------------ آماده‌سازی

func _ready() -> void:
	# دکمه‌ی Back اینجا باید پنجره/صفحه را ببندد، نه اینکه اپ را ببندد
	get_tree().set_quit_on_go_back(false)

	_http.request_completed.connect(_on_data_received)
	_action_http.request_completed.connect(_on_action_completed)
	_requests_http.request_completed.connect(_on_requests_received)

	_style_top_bar()
	UIFx.bind_press(_back_button, _go_back)
	UIFx.bind_press(_help_button, _open_rules)
	_bind_nav(_nav_rank, _open_rank)
	_bind_nav(_nav_ranking, _open_ranking)
	_bind_nav(_nav_city, _on_nav_city)
	_set_active_nav(_nav_city)

	CityUI.style_input(_search_edit)
	_search_edit.text_changed.connect(func(_t: String) -> void: _search_timer.start())
	_search_edit.text_submitted.connect(func(_t: String) -> void: _search_now())
	_search_timer.timeout.connect(_search_now)

	CityUI.style_button(_create_button, "gold")
	UIFx.bind_press_feedback(_create_button)
	_create_button.pressed.connect(_open_create)

	UIFx.bind_press_feedback(_action_button)
	_action_button.pressed.connect(_on_action_pressed)
	UIFx.bind_press_feedback(_edit_button)
	_edit_button.pressed.connect(_open_edit)
	UIFx.bind_press_feedback(_requests_button)
	_requests_button.pressed.connect(_open_requests)

	UIScroll.attach(_browse_scroll)
	UIScroll.attach(_member_scroll)

	_build_column_header()
	_build_rewards()
	_build_benefits()
	_refresh_create_cost()

	_refresh_timer.timeout.connect(refresh)
	_refresh_timer.start()

	if not Global.social_event.is_connected(_on_social_event):
		Global.social_event.connect(_on_social_event)
	if not Global.player_data_updated.is_connected(_refresh_create_cost):
		Global.player_data_updated.connect(_refresh_create_cost)

	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()

	_show_mode(Mode.BROWSE)
	_browse_empty.text = "در حال بارگذاری..."
	_browse_empty.visible = true
	refresh()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_handle_back()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			# برگشت از پس‌زمینه — دیتا ممکن است کهنه باشد
			if is_inside_tree():
				refresh()
		NOTIFICATION_EXIT_TREE:
			get_tree().set_quit_on_go_back(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_handle_back()

var _back_frame := -1

## Back اندروید: اول پنجره‌ی باز، بعد برگشت از شهرِ در حال مشاهده، بعد منوی اصلی
func _handle_back() -> void:
	# Back اندروید ممکن است هم notification بفرستد هم ui_cancel؛ فقط یک بار
	var frame := Engine.get_process_frames()
	if frame == _back_frame:
		return
	_back_frame = frame
	if _modal != null and is_instance_valid(_modal) and not _modal.is_closing():
		_modal.close()
		return
	_go_back()

func _go_back() -> void:
	if _mode == Mode.VIEW:
		_viewing_id = ""
		_show_mode(Mode.BROWSE)
		return
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _on_social_event(kind: String) -> void:
	if kind == "clan_changed" or kind == "clan_request" or kind.is_empty():
		refresh()

# ------------------------------------------------------------------ منوی کناری

func _bind_nav(button: Button, action: Callable) -> void:
	UIFx.bind_press_feedback(button)
	button.pressed.connect(action)

func _set_active_nav(active: Button) -> void:
	if _nav_active_style == null:
		_nav_active_style = CityUI.box(Color(0.05, 0.2, 0.45, 0.92), Color(0.3, 0.65, 1.0), 2, 6)
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

## «رتبه بندی» — صفحه‌ی جدول رتبه‌بندی (ranking_screen)
func _open_ranking() -> void:
	get_tree().change_scene_to_file(RANKING_SCENE)

## «شهر» — اگر شهر دیگری را نگاه می‌کنم برگرد به لیست، وگرنه تازه کن
func _on_nav_city() -> void:
	if _mode == Mode.VIEW:
		_viewing_id = ""
		_show_mode(Mode.BROWSE)
	refresh()

# ------------------------------------------------------------------ نوار بالا و ناحیه‌ی امن

## TopBar مشترک با ظاهر این صفحه (مثل rank_screen.gd): بخش پروفایلش مخفی
## است چون جایش دکمه‌ی برگشت و عنوان است.
func _style_top_bar() -> void:
	var bg := _top_bar.get_node_or_null("Background") as CanvasItem
	if bg:
		bg.visible = false
	var profile := _top_bar.get_node_or_null("HBoxContainer/Profile") as CanvasItem
	if profile:
		profile.visible = false

	var pill := CityUI.box(Color(0.02, 0.05, 0.1, 0.88), Color(0.22, 0.36, 0.58, 0.9), 1, 8)
	pill.content_margin_left = 10
	pill.content_margin_right = 6
	pill.content_margin_top = 3
	pill.content_margin_bottom = 3
	for path in ["HBoxContainer/Amounts/Coins", "HBoxContainer/Amounts/Gems"]:
		var p := _top_bar.get_node_or_null(path) as Control
		if p:
			p.add_theme_stylebox_override("panel", pill)

	var box := CityUI.box(Color(0.02, 0.05, 0.1, 0.88), Color(0.22, 0.36, 0.58, 0.9), 1, 7)
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

# ------------------------------------------------------------------ گرفتن دیتا

## اگر شهری را از لیست باز کرده‌ام همان را می‌گیرد؛ وگرنه اول شهر خودم را
## می‌پرسد و اگر عضو نبودم (۴۰۰/۴۰۴) لیست شهرها را.
func refresh() -> void:
	var username := str(Global.my_username)
	if username.is_empty():
		return
	# همین نود برای هر سه درخواست است — درخواست در راه لغو می‌شود
	_http.cancel_request()
	var url := "%s/clan?username=%s" % [Global.SERVER_BASE, username.uri_encode()]
	if not _viewing_id.is_empty():
		url += "&clan_id=" + _viewing_id.uri_encode()
		_pending_kind = "view"
	else:
		_pending_kind = "mine"
	if _http.request(url, Global.auth_headers()) != OK:
		_show_error("ارتباط با سرور برقرار نشد")

func _fetch_clan_list(page: int = 0) -> void:
	_http.cancel_request()
	_page = page
	_pending_kind = "list"
	var url := "%s/clans?username=%s&page=%d" % [
		Global.SERVER_BASE, str(Global.my_username).uri_encode(), page]
	var search := _search_edit.text.strip_edges()
	if not search.is_empty():
		url += "&search=" + search.uri_encode()
	if _http.request(url, Global.auth_headers()) != OK:
		_show_error("ارتباط با سرور برقرار نشد")

func _search_now() -> void:
	_search_timer.stop()
	if _mode == Mode.BROWSE:
		_fetch_clan_list(0)

func _on_data_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var kind := _pending_kind
	_pending_kind = ""
	if result != HTTPRequest.RESULT_SUCCESS:
		_show_error("ارتباط با سرور برقرار نشد — اینترنتت را چک کن")
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	var data: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

	match kind:
		"mine":
			# ۴۰۰ = عضو هیچ شهری نیستم · ۴۰۴ = شهرم دیگر وجود ندارد
			if response_code == 400 or response_code == 404 \
					or (response_code == 200 and not bool(data.get("is_member", false))):
				_show_mode(Mode.BROWSE)
				_fetch_clan_list(0)
			elif response_code == 200:
				_apply_clan(data, Mode.MINE)
			else:
				_show_error("دیتای شهر از سرور نیامد (کد %d)" % response_code)
		"view":
			if response_code == 404:
				_show_toast("این شهر دیگر وجود ندارد")
				_viewing_id = ""
				_show_mode(Mode.BROWSE)
				_fetch_clan_list(0)
			elif response_code == 200:
				# اگر همین الان عضوش شده باشم، دیگر «مشاهده» نیست
				if bool(data.get("is_member", false)):
					_viewing_id = ""
					_apply_clan(data, Mode.MINE)
				else:
					_apply_clan(data, Mode.VIEW)
			else:
				_show_error("دیتای شهر از سرور نیامد (کد %d)" % response_code)
		"list":
			if response_code == 200:
				_apply_clan_list(data)
			else:
				_show_error("لیست شهرها از سرور نیامد (کد %d)" % response_code)

func _show_error(message: String) -> void:
	if _mode == Mode.BROWSE:
		_browse_empty.text = message
		_browse_empty.visible = _clans.is_empty()
		_browse_scroll.visible = not _clans.is_empty()
	_show_toast(message)

# ------------------------------------------------------------------ حالت‌ها

func _show_mode(mode: Mode) -> void:
	var changed := mode != _mode or not (_browse_page.visible or _city_page.visible)
	_mode = mode
	var in_city := mode != Mode.BROWSE
	_browse_page.visible = not in_city
	_city_page.visible = in_city
	_info_panel.visible = in_city
	_create_panel.visible = mode == Mode.BROWSE
	_title_label.text = "شهر" if mode == Mode.VIEW else "شهرها"
	if not changed:
		return
	var incoming: Control = _city_page if in_city else _browse_page
	incoming.modulate.a = 0.0
	create_tween().tween_property(incoming, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)

# ------------------------------------------------------------------ لیست شهرها

func _apply_clan_list(data: Dictionary) -> void:
	var items: Array = data.get("clans", []) if data.get("clans", []) is Array else []
	_pending_clan_ids = data.get("my_pending_clan_ids", []) if data.get("my_pending_clan_ids", []) is Array else []
	var my_id := str(data.get("player_id", ""))
	if not my_id.is_empty() and str(Global.player_id) != my_id:
		Global.player_id = my_id

	# اگر در همین فاصله عضو شهری شده باشم، صفحه‌ی شهرم را نشان بده
	if not str(data.get("my_clan_id", "")).is_empty():
		_pending_kind = ""
		refresh()
		return

	if _page == 0:
		_clans = items
	else:
		_clans.append_array(items)
	_has_more = items.size() >= PAGE_SIZE
	_show_mode(Mode.BROWSE)
	_build_browse_list()

func _build_browse_list() -> void:
	var keep_scroll := _browse_scroll.scroll_vertical if _page > 0 else 0
	for child in _browse_list.get_children():
		child.queue_free()

	var searching := not _search_edit.text.strip_edges().is_empty()
	_count_label.text = "%s شهر" % CityUI.fa(_clans.size())
	_browse_empty.text = "شهری با این نام پیدا نشد" if searching \
		else "هنوز شهری ساخته نشده — اولین شهر را تو بساز!"
	_browse_empty.visible = _clans.is_empty()
	_browse_scroll.visible = not _clans.is_empty()

	for i in _clans.size():
		var item = _clans[i]
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := CityRow.new()
		_browse_list.add_child(row)
		# جایگاه واقعی فقط وقتی جستجو نمی‌کنم معنا دارد (لیست بر اساس سطح مرتب است)
		row.setup(item, i + 1, _pending_clan_ids.has(str(item.get("clan_id", ""))))
		row.tapped.connect(_on_city_row_tapped)

	if _has_more:
		var more := CityUI.button("نمایش شهرهای بیشتر", "ghost", 16)
		more.pressed.connect(func() -> void:
			UIFx.tap(more)
			_fetch_clan_list(_page + 1))
		_browse_list.add_child(more)

	if keep_scroll > 0:
		_restore_scroll.call_deferred(_browse_scroll, keep_scroll)
	else:
		_play_intro(_browse_list)

func _on_city_row_tapped(row: CityTapRow) -> void:
	var city_row := row as CityRow
	if city_row == null or city_row.clan_id.is_empty():
		return
	UIFx.tap(row)
	_viewing_id = city_row.clan_id
	# تا جواب بیاید، از همان دیتای لیست پر شود که صفحه خالی نماند
	var preview := city_row.get_data().duplicate()
	preview["members"] = []
	_members_signature = ""
	_apply_clan(preview, Mode.VIEW)
	_member_empty.text = "در حال بارگذاری اعضا..."
	refresh()

# ------------------------------------------------------------------ صفحه‌ی شهر

func _apply_clan(data: Dictionary, mode: Mode) -> void:
	_clan = data
	_show_mode(mode)

	var clan_name := str(data.get("name", "—"))
	var tag := str(data.get("tag", ""))
	var count := int(data.get("member_count", 0))
	var capacity := int(data.get("max_members", 0))

	_emblem.set_icon(str(data.get("icon_path", "")))
	_name_label.text = clan_name
	_tag_label.text = "[%s]" % tag if not tag.is_empty() else ""

	var desc := str(data.get("description", "")).strip_edges()
	_slogan_label.text = desc if not desc.is_empty() else "با هم قوی‌تر، با هم تا پیروزی"

	var world_rank := int(data.get("world_rank", 0))
	_rank_value.text = "#%s" % CityUI.fa(world_rank) if world_rank > 0 else "—"
	_members_value.text = "%s/%s" % [CityUI.fa(count), CityUI.fa(capacity)]
	_level_value.text = CityUI.fa(int(data.get("level", 1)))

	# ابزار مدیریت: ویرایش فقط رهبر، درخواست‌ها رهبر و معاون
	var can_lead := mode == Mode.MINE and bool(data.get("can_lead", false))
	var can_manage := mode == Mode.MINE and bool(data.get("can_manage", false))
	_edit_button.visible = can_lead
	_requests_button.visible = can_manage
	_tools.visible = can_lead or can_manage
	var pending := int(data.get("pending_requests", 0))
	_requests_badge.visible = can_manage and pending > 0
	_requests_badge_label.text = "9+" if pending > 9 else CityUI.fa(pending)

	_apply_banner(data, mode)
	_build_info(data)

	var members: Array = data.get("members", []) if data.get("members", []) is Array else []
	_members = members
	# لیست فقط وقتی دوباره ساخته می‌شود که واقعاً عوض شده (رفرش هر ۲۰ ثانیه)
	var signature := JSON.stringify(members) + str(mode) + str(data.get("my_role", ""))
	if signature != _members_signature:
		_members_signature = signature
		_build_member_list()

	if _requests_modal != null and is_instance_valid(_requests_modal) and can_manage:
		_fetch_requests()

## بنر وسط: عضو نیستم → دکمه‌ی عضویت · عضوم → دکمه‌ی قرمز «ترک شهر»
func _apply_banner(data: Dictionary, mode: Mode) -> void:
	if mode == Mode.MINE:
		var role := str(data.get("my_role", "member"))
		var st := PsychSocialCity.standing(data)
		# متنِ زیرِ بنر می‌شکند تا روی گوشیِ باریک «...» نشود (سهم + جایگاه طولانی است)
		_banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_banner_sub.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		if bool(st.me_new):
			# E1 ارتباط: عضوِ تازه خوش‌آمد می‌شنود و اولین قدمِ اجتماعی را می‌بیند
			_banner_title.text = "به شهر خوش اومدی!"
			_banner_sub.text = "توی چتِ شهر سلام کن — هر کاپی که می‌گیری امتیازِ شهر رو بالا می‌بره."
		else:
			_banner_title.text = "شهر تو"
			_banner_sub.text = "نقش تو: %s" % CityUI.role_label(role)
			# E1/E10 ارتباط: سهم خودم از امتیاز شهر (امتیاز شهر = جمع کاپ اعضا، handlers_leaderboard.go)
			# E9 مقایسه در گروهِ کوچک: جایگاهم بینِ همشهری‌ها، نه بینِ همه‌ی دنیا
			if int(st.mine) > 0:
				_banner_sub.text += "  •  سهم تو: %s کاپ (%s٪ امتیاز شهر)  •  نفرِ %s از %s" % [
					CityUI.fa_grouped(int(st.mine)), CityUI.fa(int(st.pct)),
					CityUI.fa(int(st.place)), CityUI.fa(int(st.count))]
			if int(st.new_count) > 0:
				_banner_sub.text += "  •  %s تازه‌وارد — خوش‌آمد بگو!" % CityUI.fa(int(st.new_count))
		_set_action("ترک شهر", "danger", true)
		return
	_banner_sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	_banner_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	_banner_title.text = "به شهر ما بپیوندید!"
	_banner_sub.text = "یک تیم، یک هدف؛ پیروزی در میدان نبرد."

	var min_level := int(data.get("min_level", 0))
	var my_level := int(data.get("my_level", Global.level))
	var has_viewer_info := data.has("my_level")
	if not str(data.get("my_clan_id", "")).is_empty():
		_set_action("عضو شهر دیگری هستی", "ghost", false)
	elif bool(data.get("request_pending", false)) or _pending_clan_ids.has(str(data.get("clan_id", ""))):
		_set_action("درخواست فرستاده شد", "ghost", false)
	elif bool(data.get("is_full", false)):
		_set_action("ظرفیت تکمیل است", "ghost", false)
	elif has_viewer_info and my_level < min_level:
		_set_action("سطح %s لازم است" % CityUI.fa(min_level), "ghost", false)
	elif bool(data.get("is_public", true)):
		_set_action("عضویت در شهر", "primary", true)
	else:
		_set_action("درخواست عضویت", "primary", true)

func _set_action(text: String, kind: String, enabled: bool) -> void:
	_action_button.text = text
	_action_button.disabled = not enabled
	CityUI.style_button(_action_button, kind)

func _on_action_pressed() -> void:
	UIFx.tap(_action_button)
	if _busy:
		return
	if _mode == Mode.MINE:
		_confirm_leave()
	elif _mode == Mode.VIEW:
		var clan_id := str(_clan.get("clan_id", ""))
		if clan_id.is_empty():
			return
		_post("/clan/join", {"username": Global.my_username, "clan_id": clan_id}, "",
			func(data: Dictionary) -> void:
				# شهر عمومی: همین الان عضو شدم → صفحه‌ی شهر خودم
				if not bool(data.get("pending", false)):
					_viewing_id = ""
					# E11 لرزش فقط از مسیر تنظیمات (روی PC هم بی‌اثر)
					LocalSettings.vibrate(40))

## کارت «اطلاعات شهر»
func _build_info(data: Dictionary) -> void:
	for child in _info_rows.get_children():
		child.queue_free()

	var leader := str(data.get("leader_name", ""))
	var officers := int(data.get("officer_count", 0))
	var tag := str(data.get("tag", ""))
	var min_level := int(data.get("min_level", 0))
	var is_public := bool(data.get("is_public", true))

	_info_rows.add_child(_info_row(ICON_CROWN, "رهبر", leader if not leader.is_empty() else "—", CityUI.GOLD, false))
	_info_rows.add_child(_info_row(ICON_FRIENDS, "معاونان", "%s نفر" % CityUI.fa(officers), CityUI.TEXT, false))
	_info_rows.add_child(_info_row(ICON_SHIELD, "تگ", tag if not tag.is_empty() else "—", CityUI.BLUE, true))
	_info_rows.add_child(_info_row(ICON_STAR, "حداقل سطح",
		"آزاد" if min_level <= 0 else "سطح %s" % CityUI.fa(min_level), CityUI.TEXT, false))
	_info_rows.add_child(_info_row(ICON_LOCK, "نوع شهر",
		"عمومی" if is_public else "خصوصی", CityUI.GREEN if is_public else CityUI.GOLD, false))

func _info_row(icon: Texture2D, caption: String, value: String, value_color: Color, numeric: bool) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 30)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	row.add_child(CityUI.icon(icon, 18, CityUI.MUTED))
	row.add_child(CityUI.label(caption, 14, CityUI.MUTED))
	var value_label := CityUI.label(value, 15, value_color, numeric)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value_label.clip_text = true
	row.add_child(value_label)
	return row

# ------------------------------------------------------------------ لیست اعضا

func _build_column_header() -> void:
	for child in _column_header.get_children():
		child.queue_free()
	# همان حاشیه‌ی داخلی ردیف‌ها تا ستون‌ها زیر هم بیفتند
	var lead := Control.new()
	lead.custom_minimum_size = Vector2(2, 0)
	_column_header.add_child(lead)
	for i in CityMemberRow.COLUMN_TITLES.size():
		var label := CityUI.label(CityMemberRow.COLUMN_TITLES[i], 13, CityUI.MUTED)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_stretch_ratio = CityMemberRow.COLUMN_RATIOS[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(10, 0)
		_column_header.add_child(label)
	var trail := Control.new()
	trail.custom_minimum_size = Vector2(6, 0)
	_column_header.add_child(trail)

func _build_member_list() -> void:
	var keep_scroll := _member_scroll.scroll_vertical
	for child in _member_list.get_children():
		child.queue_free()

	_member_empty.text = "این شهر هنوز عضوی ندارد"
	_member_empty.visible = _members.is_empty()
	_member_scroll.visible = not _members.is_empty()

	for item in _members:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := CityMemberRow.new()
		_member_list.add_child(row)
		row.setup(item)
		row.tapped.connect(_on_member_tapped)

	if keep_scroll > 0:
		_restore_scroll.call_deferred(_member_scroll, keep_scroll)
	else:
		_play_intro(_member_list)

func _restore_scroll(scroll: ScrollContainer, value: int) -> void:
	if is_instance_valid(scroll):
		scroll.scroll_vertical = value

# ------------------------------------------------------------------ کارهای عضو

func _on_member_tapped(row: CityTapRow) -> void:
	var member_row := row as CityMemberRow
	if member_row == null:
		return
	UIFx.tap(row)
	_open_member(member_row.get_data())

## پنجره‌ی یک عضو: اطلاعات + دکمه‌هایی که بیننده اختیارش را دارد
func _open_member(data: Dictionary) -> void:
	var player_id := str(data.get("player_id", ""))
	var role := str(data.get("role", "member"))
	var is_me := bool(data.get("is_me", false))
	var viewer_role := str(_clan.get("my_role", "")) if _mode == Mode.MINE else ""

	var modal := _new_modal(str(data.get("username", "—")), 420.0)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	modal.body.add_child(top)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(76, 76)
	frame.add_theme_stylebox_override("panel", CityUI.box(Color(0.02, 0.03, 0.06), CityUI.role_color(role), 2, 38))
	top.add_child(frame)
	var avatar := TextureRect.new()
	avatar.texture = CityUI.avatar_texture(str(data.get("avatar_id", "")))
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.add_child(avatar)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(info)
	info.add_child(CityUI.label("%s  •  سطح %s" % [CityUI.role_label(role), CityUI.fa(int(data.get("level", 0)))],
		16, CityUI.role_color(role)))
	var tier := str(data.get("tier_name", ""))
	info.add_child(CityUI.label("رنک: %s   •   کاپ: %s" % [
		tier if not tier.is_empty() else "—", CityUI.fa_grouped(int(data.get("trophies", 0)))], 14, CityUI.MUTED))
	info.add_child(CityUI.label("آنلاین" if bool(data.get("is_online", false)) else "آفلاین", 14,
		CityUI.GREEN if bool(data.get("is_online", false)) else CityUI.MUTED))

	var badge := TextureRect.new()
	badge.texture = RankArt.texture_for(str(data.get("tier_id", "")), tier)
	badge.custom_minimum_size = Vector2(56, 56)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.visible = badge.texture != null
	top.add_child(badge)

	if is_me:
		modal.body.add_child(_hint("این تویی! برای رفتن از شهر از دکمه‌ی «ترک شهر» استفاده کن."))
		modal.open()
		return

	# --- دوستی ---
	var friend := CityUI.button("افزودن به دوستان", "primary")
	if bool(data.get("is_friend", false)):
		friend.text = "دوست تو است"
		friend.disabled = true
	elif bool(data.get("friend_request_sent", false)):
		friend.text = "درخواست دوستی فرستاده شد"
		friend.disabled = true
	friend.pressed.connect(func() -> void:
		_post("/friends/request", {"username": Global.my_username, "target_id": player_id},
			"درخواست دوستی فرستاده شد")
		modal.close())
	modal.body.add_child(friend)

	# --- مدیریت: فقط روی نقش‌های پایین‌تر از بیننده ---
	var viewer_rank := CityUI.role_rank(viewer_role)
	var can_act := viewer_rank >= CityUI.role_rank("officer") and CityUI.role_rank(role) < viewer_rank

	if viewer_role == "leader" and role != "leader":
		var promote_to := "member" if role == "officer" else "officer"
		var promote := CityUI.button("تنزل به عضو عادی" if role == "officer" else "ارتقا به معاون", "ghost")
		promote.pressed.connect(func() -> void:
			_post("/clan/role", {"username": Global.my_username, "target_id": player_id, "role": promote_to},
				"نقش عضو به %s تغییر کرد" % CityUI.role_label(promote_to))
			modal.close())
		modal.body.add_child(promote)

		var transfer := CityUI.button("سپردن رهبری شهر", "gold")
		_arm_confirm(transfer, "مطمئنی؟ تو معاون می‌شوی — دوباره بزن", func() -> void:
			_post("/clan/transfer", {"username": Global.my_username, "target_id": player_id}, "")
			modal.close())
		modal.body.add_child(transfer)

	if can_act:
		var kick := CityUI.button("اخراج از شهر", "danger")
		_arm_confirm(kick, "مطمئنی؟ دوباره بزن تا اخراج شود", func() -> void:
			_post("/clan/kick", {"username": Global.my_username, "target_id": player_id}, "عضو از شهر اخراج شد")
			modal.close())
		modal.body.add_child(kick)

	modal.open()

## دکمه‌ی خطرناک دو مرحله‌ای: ضربه‌ی اول متن تأیید، ضربه‌ی دوم اجرا
func _arm_confirm(button: Button, confirm_text: String, action: Callable) -> void:
	var armed := [false]
	button.pressed.connect(func() -> void:
		UIFx.tap(button)
		if not armed[0]:
			armed[0] = true
			button.text = confirm_text
			return
		action.call())

# ------------------------------------------------------------------ ترک شهر

func _confirm_leave() -> void:
	var modal := _new_modal("ترک شهر", 420.0)
	var alone := str(_clan.get("my_role", "")) == "leader" and _members.size() <= 1
	var text := "مطمئنی می‌خواهی از شهر «%s» خارج شوی؟" % str(_clan.get("name", ""))
	if alone:
		text += "\nتو تنها عضو این شهری — با رفتنت شهر منحل می‌شود."
	elif str(_clan.get("my_role", "")) == "leader":
		text += "\nرهبری به قدیمی‌ترین معاون (یا عضو) می‌رسد."
	modal.body.add_child(_hint(text))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	modal.body.add_child(buttons)
	var cancel := CityUI.button("ماندن", "ghost")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(modal.close)
	buttons.add_child(cancel)
	var leave := CityUI.button("منحل کردن و خروج" if alone else "ترک شهر", "danger")
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(func() -> void:
		UIFx.tap(leave)
		_post("/clan/leave", {"username": Global.my_username}, "از شهر خارج شدی",
			func(_d: Dictionary) -> void:
				_viewing_id = ""
				_clan = {})
		modal.close())
	buttons.add_child(leave)
	modal.open()

# ------------------------------------------------------------------ ساخت و ویرایش شهر

func _open_create() -> void:
	UIFx.tap(_create_button)
	var dialog := CityEditDialog.new()
	_track_modal(dialog)
	add_child(dialog)
	dialog.setup({})
	dialog.saved.connect(func(_r: Dictionary) -> void:
		_viewing_id = ""
		_show_toast("شهرت ساخته شد — حالا رهبرش هستی")
		refresh())

func _open_edit() -> void:
	if _mode != Mode.MINE or not bool(_clan.get("can_lead", false)):
		return
	var dialog := CityEditDialog.new()
	_track_modal(dialog)
	add_child(dialog)
	dialog.setup(_clan)
	dialog.saved.connect(func(result: Dictionary) -> void:
		_show_toast(str(result.get("message", "تغییرات شهر ذخیره شد")))
		refresh())

func _refresh_create_cost() -> void:
	if _create_cost == null:
		return
	var cost := CityEditDialog.CREATE_COST
	_create_cost.text = "هزینه ساخت: %s سکه" % CityUI.fa_grouped(cost)
	_create_cost.add_theme_color_override("font_color", CityUI.GOLD if Global.coins >= cost else CityUI.RED)

# ------------------------------------------------------------------ درخواست‌های عضویت

func _open_requests() -> void:
	var modal := _new_modal("درخواست‌های عضویت", 480.0)
	_requests_modal = modal
	modal.closed.connect(func() -> void: _requests_modal = null)
	modal.body.add_child(_hint("در حال بارگذاری..."))
	modal.open()
	_fetch_requests()

func _fetch_requests() -> void:
	var username := str(Global.my_username)
	if username.is_empty():
		return
	_requests_http.cancel_request()
	var url := "%s/clan/requests?username=%s" % [Global.SERVER_BASE, username.uri_encode()]
	if _requests_http.request(url, Global.auth_headers()) != OK:
		_show_toast("ارتباط با سرور برقرار نشد")

func _on_requests_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_show_toast("درخواست‌ها از سرور نیامد")
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_requests = parsed.get("requests", []) if parsed.get("requests", []) is Array else []
	var count := _requests.size()
	_requests_badge.visible = _requests_button.visible and count > 0
	_requests_badge_label.text = "9+" if count > 9 else CityUI.fa(count)
	_build_requests()

func _build_requests() -> void:
	var modal := _requests_modal
	if modal == null or not is_instance_valid(modal) or modal.is_closing():
		return
	for child in modal.body.get_children():
		child.queue_free()

	if _requests.is_empty():
		modal.body.add_child(_hint("فعلاً درخواست عضویتی در صف نیست."))
		return

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# حداکثر حدود ۵ ردیف — بیشتر شد با انگشت اسکرول می‌شود
	scroll.custom_minimum_size = Vector2(0, mini(_requests.size(), 5) * 62)
	modal.body.add_child(scroll)
	UIScroll.attach(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for item in _requests:
		if typeof(item) == TYPE_DICTIONARY:
			list.add_child(_request_row(item))

func _request_row(item: Dictionary) -> Control:
	var request_id := str(item.get("request_id", ""))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CityUI.box(Color(0.03, 0.06, 0.12, 0.8), Color(0.2, 0.3, 0.46, 0.5), 1, 8))
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 6)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)

	var avatar := TextureRect.new()
	avatar.texture = CityUI.avatar_texture(str(item.get("from_avatar_id", "")))
	avatar.custom_minimum_size = Vector2(44, 44)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	row.add_child(avatar)

	var name_label := CityUI.label(str(item.get("from_username", "—")), 16)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	row.add_child(name_label)
	row.add_child(CityUI.label("Lv.%d" % int(item.get("from_level", 0)), 16, CityUI.MUTED, true))

	var reject := CityUI.button("رد", "danger", 15)
	reject.custom_minimum_size = Vector2(64, CityUI.TOUCH_H)
	reject.pressed.connect(func() -> void:
		UIFx.tap(reject)
		_respond_request(request_id, false))
	row.add_child(reject)

	var accept := CityUI.button("تأیید", "primary", 15)
	accept.custom_minimum_size = Vector2(76, CityUI.TOUCH_H)
	accept.pressed.connect(func() -> void:
		UIFx.tap(accept)
		_respond_request(request_id, true))
	row.add_child(accept)
	return panel

func _respond_request(request_id: String, accept: bool) -> void:
	if request_id.is_empty():
		return
	_post("/clan/respond", {"username": Global.my_username, "request_id": request_id, "accept": accept},
		"درخواست پذیرفته شد" if accept else "درخواست رد شد")

# ------------------------------------------------------------------ قوانین

func _open_rules() -> void:
	var modal := _new_modal("قوانین شهر", 560.0)
	for rule in RULES:
		var text: String = rule
		if text.contains("%s"):
			text = text % CityUI.fa_grouped(
				CityEditDialog.CREATE_COST if text.begins_with("ساخت") else CityEditDialog.RENAME_COST)
		modal.body.add_child(_hint("• " + text))
	modal.open()

# ------------------------------------------------------------------ ستون راست

## «پاداش‌های شهر» — فقط تجربه و سکه
func _build_rewards() -> void:
	for child in _reward_tiles.get_children():
		child.queue_free()
	# آیکن تجربه سفید و خطی است — به رنگ قاب درمی‌آید؛ سکه رنگ خودش را دارد
	_reward_tiles.add_child(_reward_tile(ICON_XP, "تجربه", Color(0.55, 0.45, 1.0), Color(0.75, 0.68, 1.0)))
	_reward_tiles.add_child(_reward_tile(ICON_COIN, "سکه", CityUI.GOLD, Color.WHITE))

func _reward_tile(icon: Texture2D, caption: String, glow: Color, tint: Color) -> Control:
	var tile := PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.custom_minimum_size = Vector2(0, 76)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := CityUI.box(Color(0.03, 0.07, 0.15, 0.95), Color(glow.r, glow.g, glow.b, 0.75), 1, 8)
	style.shadow_color = Color(glow.r, glow.g, glow.b, 0.25)
	style.shadow_size = 5
	tile.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	tile.add_child(col)
	var ic := CityUI.icon(icon, 44, tint)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ic)
	var label := CityUI.label(caption, 14, CityUI.TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(label)
	return tile

func _build_benefits() -> void:
	for child in _benefit_rows.get_children():
		child.queue_free()
	var icons := {"friends": ICON_FRIENDS, "chat": ICON_CHAT, "ranking": ICON_RANKING, "shield": ICON_CLAN}
	for entry in BENEFITS:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 28)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		row.add_child(CityUI.icon(icons[entry[0]], 18, Color(0.62, 0.8, 1.0)))
		var label := CityUI.label(entry[1], 14, CityUI.TEXT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.clip_text = true
		row.add_child(label)
		_benefit_rows.add_child(row)

# ------------------------------------------------------------------ مودال‌ها

func _new_modal(title: String, width: float) -> CityModal:
	var modal := CityModal.new()
	_track_modal(modal)
	add_child(modal)
	modal.build(title, width)
	return modal

## فقط یک پنجره در هر لحظه — قبلی بسته می‌شود
func _track_modal(modal: CityModal) -> void:
	if _modal != null and is_instance_valid(_modal) and not _modal.is_closing():
		_modal.close()
	_modal = modal
	modal.closed.connect(func() -> void:
		if _modal == modal:
			_modal = null)

func _hint(text: String) -> Label:
	var label := CityUI.label(text, 15, CityUI.TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.custom_minimum_size = Vector2(200, 0)
	return label

# ------------------------------------------------------------------ سرور

## درخواست POST کارها. `after` (اختیاری) بعد از موفقیت و قبل از رفرش صدا
## زده می‌شود و پاسخ سرور را می‌گیرد.
func _post(path: String, payload: Dictionary, success_message: String, after: Callable = Callable()) -> void:
	if _busy:
		return
	_busy = true
	_success_message = success_message
	_after_action = after
	var err := _action_http.request(
		Global.SERVER_BASE + path,
		Global.json_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload))
	if err != OK:
		_busy = false
		_show_toast("ارتباط با سرور برقرار نشد")

func _on_action_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	var data: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

	if result != HTTPRequest.RESULT_SUCCESS:
		_show_toast("ارتباط با سرور برقرار نشد — اینترنتت را چک کن")
		return
	if response_code != 200 and response_code != 201:
		_show_toast(str(data.get("error", "انجام نشد (کد %d)" % response_code)))
		return

	# اگر سرور خودش پیام داده (مثل «به شهر خوش آمدی») همان را نشان بده
	_show_toast(str(data.get("message", _success_message)))
	if _after_action.is_valid():
		_after_action.call(data)
	_after_action = Callable()
	_members_signature = ""
	refresh()
	if _requests_modal != null and is_instance_valid(_requests_modal):
		_fetch_requests()

# ------------------------------------------------------------------ نمایش

func _show_toast(text: String) -> void:
	if text.is_empty():
		return
	if _toast == null:
		_toast = Label.new()
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast.z_index = 10
		_toast.add_theme_font_override("font", CityUI.FONT)
		_toast.add_theme_font_size_override("font_size", 16)
		_toast.add_theme_color_override("font_color", CityUI.TEXT)
		var style := CityUI.box(Color(0.03, 0.08, 0.18, 0.95), CityUI.BLUE, 1, 8)
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		_toast.add_theme_stylebox_override("normal", style)
		add_child(_toast)
	move_child(_toast, get_child_count() - 1)
	_toast.text = text
	_toast.reset_size()
	var vp := get_viewport_rect().size
	_toast.position = Vector2((vp.x - _toast.size.x) * 0.5, vp.y * 0.84)
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)

## ردیف‌ها یکی‌یکی محو‌شونده بالا می‌آیند
func _play_intro(container: VBoxContainer) -> void:
	var rows := container.get_children()
	for i in rows.size():
		var row := rows[i] as Control
		if row == null or i > 8:
			break
		row.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(0.035 * i)
		t.tween_property(row, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
