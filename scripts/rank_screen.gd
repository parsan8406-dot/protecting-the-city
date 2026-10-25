extends Control
## صحنه‌ی «رنک» — از دکمه‌ی رنک در نوار پایین منوی اصلی باز می‌شود.
##
## رنک فقط از تعداد کاپ (trophies) می‌آید. کاپ مقدار ثابتی ندارد: هر برد در
## بازی کاپ اضافه می‌کند و هر باخت کم می‌کند، و هرچه کاپ بیشتر باشد نشان رنک
## بالاتری نمایش داده می‌شود:
##   برنز ۱-۱۰۰۰ · نقره ۱۰۰۱-۱۶۰۰ · طلا ۱۶۰۱-۲۲۰۰ · پلاتین ۲۲۰۱-۲۸۰۰
##   الماس ۲۸۰۱-۳۴۰۰ · لجندری ۳۴۰۱+
## منبع این اعداد trophyTiers در gun_game_server/matchmaking.go است و سرور
## همان جدول را در /profile → rank_tiers می‌فرستد. DEFAULT_TIERS فقط برای
## وقتی است که سرور هنوز جواب نداده.
##
## چیدمان (مثل طرح):
##   بالا-چپ     دکمه‌ی برگشت + «رنک» + راهنما — سکه/جم/پیام از TopBar
##   ستون چپ     منوی کناری: رنک · رتبه بندی · شهر — «؟» قوانین رنک را نشان می‌دهد
##               (صفحه‌های رتبه بندی و شهر هم همین منو را دارند:
##                ranking_screen.tscn و city.tscn)
##   بالا        کارت بازیکن (آواتار، رتبه فعلی، کاپ، نوار تا رنک بعدی) | کارت فصل
##   وسط         «درجه‌های رنک»: ۶ ستون برنز → لجندری  (یا صفحه‌ی قوانین)
##   پایین       نکات رنک | شعار
##
## دیتا: GET /profile → trophies · rank · rank_tiers · season_number · season_ends_at

const TIER_CHIP_SCENE := preload("res://secense/rank_tier_chip.tscn")
const PsychProgress := preload("res://scripts/psych_results_progress.gd")

const DEFAULT_TIERS := [
	{"id": "bronze", "name": "برنز", "min": 0, "max": 1000},
	{"id": "silver", "name": "نقره", "min": 1001, "max": 1600},
	{"id": "gold", "name": "طلا", "min": 1601, "max": 2200},
	{"id": "platinum", "name": "پلاتین", "min": 2201, "max": 2800},
	{"id": "diamond", "name": "الماس", "min": 2801, "max": 3400},
	{"id": "legend", "name": "لجندری", "min": 3401, "max": 0},
]

## جمله‌ی زیر هر ستون درجه
const TIER_SUBS := {
	"bronze": "آغاز مسیر قهرمانی",
	"silver": "قدرت در حال رشد",
	"gold": "آزمون واقعی",
	"platinum": "نخبه‌های میدان",
	"diamond": "فقط بهترین‌ها",
	"legend": "اسطوره‌ها",
}

const RULES := [
	"رنک تو فقط از روی تعداد کاپ‌هایت مشخص می‌شود.",
	"کاپ مقدار ثابتی ندارد: هر برد در بازی‌های چندنفره کاپ اضافه می‌کند و هر باخت کاپ کم می‌کند.",
	"مقدار کاپ برد و باخت در هر حالت بازی فرق دارد.",
	"با بالا رفتن کاپ رنکت بالا می‌رود و با کم شدنش پایین می‌آید.",
	"کاپ هیچ‌وقت از صفر کمتر نمی‌شود.",
]

const COLOR_TEXT := Color(0.9, 0.93, 1.0, 1.0)
const COLOR_MUTED := Color(0.68, 0.74, 0.84, 1.0)
const COLOR_GOLD := Color(0.97, 0.78, 0.3, 1.0)
const COLOR_BLUE := Color(0.3, 0.6, 1.0, 1.0)

const MAIN_MENU_SCENE := "res://secense/main_menu.tscn"
const RANKING_SCENE := "res://secense/ranking_screen.tscn"
const CITY_SCENE := "res://secense/city.tscn"

const _CARD := "Content/Body/TopArea/RightCol/HeaderRow/ProfileCard/Margin/Row/"
const _SEASON := "Content/Body/TopArea/RightCol/HeaderRow/SeasonCard/Margin/Row/Body/"
const _PAGES := "Content/Body/TopArea/RightCol/Pages/"
const _NAV := "Content/Body/TopArea/Sidebar/"

@onready var _http: HTTPRequest = $HTTPRequest
@onready var _top_bar: Control = $TopBar
@onready var _content: MarginContainer = $Content
@onready var _header_left: Control = $HeaderLeft
@onready var _back_button: Button = $HeaderLeft/BackButton
@onready var _help_button: TextureButton = $HeaderLeft/HelpButton

# --- کارت بازیکن ---
@onready var _avatar: TextureRect = get_node(_CARD + "AvatarFrame/Avatar")
@onready var _level_label: Label = get_node(_CARD + "AvatarFrame/LevelTag/LevelLabel")
@onready var _name_label: Label = get_node(_CARD + "Info/NameRow/NameLabel")
@onready var _tier_badge: TextureRect = get_node(_CARD + "Info/TierRow/TierBadge")
@onready var _tier_label: Label = get_node(_CARD + "Info/TierRow/TierCol/TierLabel")
@onready var _trophies_label: Label = get_node(_CARD + "Info/TierRow/TierCol/TrophyRow/TrophiesLabel")
@onready var _progress_value: Label = get_node(_CARD + "Progress/ValueLabel")
@onready var _progress_bar: ProgressBar = get_node(_CARD + "Progress/Bar")
@onready var _next_label: Label = get_node(_CARD + "Progress/NextRow/NextText/NextLabel")
@onready var _remain_label: Label = get_node(_CARD + "Progress/NextRow/NextText/RemainLabel")
@onready var _up_icon: TextureRect = get_node(_CARD + "Progress/NextRow/UpIcon")

# --- کارت فصل ---
@onready var _season_label: Label = get_node(_SEASON + "SeasonLabel")
@onready var _days_label: Label = get_node(_SEASON + "DaysLabel")

# --- صفحه‌ها ---
@onready var _tiers_page: Control = get_node(_PAGES + "TiersPage")
@onready var _rules_page: Control = get_node(_PAGES + "RulesPage")
@onready var _tiers_row: HBoxContainer = get_node(_PAGES + "TiersPage/Panel/Margin/TiersRow")
@onready var _rules_tiers: VBoxContainer = get_node(_PAGES + "RulesPage/Margin/Body/Columns/TierList")
@onready var _rules_list: VBoxContainer = get_node(_PAGES + "RulesPage/Margin/Body/Columns/RuleList")

# --- منوی کناری ---
@onready var _nav_rank: Button = get_node(_NAV + "NavRank")
@onready var _nav_ranking: Button = get_node(_NAV + "NavRanking")
@onready var _nav_city: Button = get_node(_NAV + "NavCity")

@onready var _slogan: Control = $Content/Body/BottomRow/SloganArea/Slogan

## جدول رنک‌ها (از سرور، یا DEFAULT_TIERS تا جواب بیاید)
var _tiers: Array = DEFAULT_TIERS.duplicate(true)
var _tier_chips: Array = []
var _trophies := 0
var _current_index := 0

## یک درخواست در راه است (جلوی درخواست دوباره را می‌گیرد)
var _busy := false

## استایل دکمه‌ی فعال منوی کناری (یک بار ساخته می‌شود)
var _nav_active_style: StyleBoxFlat = null
var _nav_base_style: StyleBox = null
var _toast: Label = null
var _toast_tween: Tween = null

# ------------------------------------------------------------------ آماده‌سازی

func _ready() -> void:
	# دکمه‌ی Back اینجا باید به منوی اصلی برگردد، نه اینکه اپ را ببندد
	get_tree().set_quit_on_go_back(false)
	_http.request_completed.connect(_on_profile_received)

	_style_top_bar()
	UIFx.bind_press(_back_button, _go_back)
	# «؟» صفحه‌ی قوانین رنک را باز/بسته می‌کند
	UIFx.bind_press(_help_button, func() -> void: _show_page(not _rules_page.visible))
	_bind_nav(_nav_rank, _show_page.bind(false))
	_bind_nav(_nav_ranking, _open_ranking)
	_bind_nav(_nav_city, _open_city)

	visibility_changed.connect(_on_visibility_changed)
	get_viewport().size_changed.connect(_apply_safe_area)
	_slogan.resized.connect(func() -> void: _slogan.pivot_offset = _slogan.size * 0.5)
	_apply_safe_area()

	# تا جواب سرور بیاید، از چیزی که Global دارد پر شود
	_name_label.text = str(Global.my_username)
	_level_label.text = "سطح %s" % MissionArt.fa_number(int(Global.level))
	_apply_avatar(str(Global.avatar_id))

	_build_ladder()
	_build_rules()
	_apply_trophies(0, "")
	_show_page(false)
	refresh()

## دکمه‌ی Back اندروید → برگشت به منوی اصلی (مثل game_modes.gd)
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()
	elif what == NOTIFICATION_EXIT_TREE:
		get_tree().set_quit_on_go_back(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()

func refresh() -> void:
	var username: String = str(Global.my_username)
	if username.is_empty() or _busy:
		return

	var url := "%s/profile?username=%s" % [Global.SERVER_BASE, username.uri_encode()]
	var err := _http.request(url, Global.auth_headers())
	if err != OK:
		push_warning("خطا در درخواست پروفایل برای صفحه‌ی رنک: %d" % err)
	else:
		_busy = true

func _on_profile_received(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("پروفایل از سرور نیامد. کد: %d" % response_code)
		_show_toast("اتصال به سرور برقرار نشد")
		return
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("پاسخ پروفایل قابل خواندن نبود")
		return
	_apply_profile(json.data)

# ------------------------------------------------------------------ نوار بالا

## TopBar مشترک (سکه، جم، پیام، دوستان، تنظیمات) با ظاهر این صفحه:
## بخش پروفایلش مخفی می‌شود چون جایش دکمه‌ی برگشت و عنوان «رنک» است،
## زمینه‌اش شفاف می‌شود و دکمه‌ها قاب آبی می‌گیرند.
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

	# قاب مربعی پشت آیکن‌های پیام/دوستان/تنظیمات (پشت خود دکمه کشیده می‌شود)
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

## فاصله‌ی ناچ/لبه‌ی خمیده از چهار طرف، به واحدِ ویوپورت (مثل game_modes.gd)
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

# ------------------------------------------------------------------ منوی کناری

func _bind_nav(button: Button, action: Callable) -> void:
	UIFx.bind_press_feedback(button)
	button.pressed.connect(action)

## «درجه‌های رنک» یا «قوانین رنک» (از دکمه‌ی ؟) در همین صفحه
func _show_page(rules: bool) -> void:
	_tiers_page.visible = not rules
	_rules_page.visible = rules
	_set_active_nav(_nav_rank)

func _set_active_nav(active: Button) -> void:
	if _nav_active_style == null:
		_nav_active_style = _make_box(Color(0.05, 0.2, 0.45, 0.92), Color(0.3, 0.65, 1.0), 2, 6)
		_nav_active_style.shadow_color = Color(0.15, 0.5, 1.0, 0.45)
		_nav_active_style.shadow_size = 8
		_nav_active_style.content_margin_left = 14
		_nav_active_style.content_margin_right = 12
	if _nav_base_style == null:
		# استایل عادی همان SB_nav صحنه است
		_nav_base_style = _nav_rank.get_theme_stylebox("normal")
	for button in [_nav_rank, _nav_ranking, _nav_city]:
		var style: StyleBox = _nav_active_style if button == active else _nav_base_style
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)

## «رتبه بندی» — صفحه‌ی جدول رتبه‌بندی (ranking_screen)
func _open_ranking() -> void:
	get_tree().change_scene_to_file(RANKING_SCENE)

## «شهر» — صفحه‌ی شهر (کلن)، همان که دکمه‌ی شهر منوی اصلی باز می‌کند
func _open_city() -> void:
	get_tree().change_scene_to_file(CITY_SCENE)

func _go_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

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

# ------------------------------------------------------------------ پر کردن UI

func _apply_profile(data: Dictionary) -> void:
	var rank: Dictionary = data.get("rank", {})

	var server_tiers := _parse_tiers(data.get("rank_tiers", []))
	if not server_tiers.is_empty() and server_tiers != _tiers:
		_tiers = server_tiers
		_build_ladder()
		_build_rules()

	_name_label.text = str(data.get("username", Global.my_username))
	_level_label.text = "سطح %s" % MissionArt.fa_number(int(data.get("level", Global.level)))
	_apply_avatar(str(data.get("avatar_id", Global.avatar_id)))

	var trophies := int(data.get("trophies", rank.get("points", 0)))
	_apply_trophies(trophies, str(rank.get("tier_id", "")))
	_apply_season(data, rank)

## جدول rank_tiers سرور → آرایه‌ی دیکشنری. خالی یعنی قابل استفاده نبود.
func _parse_tiers(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for t in raw:
		if typeof(t) != TYPE_DICTIONARY or str(t.get("id", "")).is_empty():
			return []
		out.append({
			"id": str(t.get("id", "")),
			"name": str(t.get("name", "")),
			"min": int(t.get("min", 0)),
			"max": int(t.get("max", 0)),
		})
	return out

## رنک فعلی، کاپ‌ها، نوار تا رنک بعدی و ستون فعلی در «درجه‌های رنک»
func _apply_trophies(trophies: int, server_tier_id: String) -> void:
	_trophies = trophies
	var index := _tier_index_for(trophies)
	# اگر سرور tier فرستاده همان ملاک است (هر دو از یک جدول می‌آیند)
	var by_id := _tier_index_by_id(server_tier_id)
	if by_id >= 0:
		index = by_id
	_current_index = index
	var tier: Dictionary = _tiers[index]

	_tier_label.text = str(tier.get("name", "—"))
	_trophies_label.text = MissionArt.fa_grouped(trophies)
	_tier_badge.texture = RankArt.texture_for(str(tier.get("id", "")), _tier_label.text)

	var bar_value := 1.0
	var bar_max := 1.0
	var near := false
	if index + 1 < _tiers.size():
		var next: Dictionary = _tiers[index + 1]
		var lo := int(tier.get("min", 0))
		var hi := int(next.get("min", lo + 1))
		bar_max = float(maxi(hi - lo, 1))
		# C9 پیشرفتِ اهدایی: اولِ هر رنک نوار کاملاً خالی دیده نمی‌شود
		bar_value = PsychProgress.visual_ratio(float(clampi(trophies - lo, 0, hi - lo)), bar_max) * bar_max
		near = PsychProgress.is_near(trophies - lo, hi - lo)
		_progress_value.text = "%s / %s" % [MissionArt.fa_grouped(trophies), MissionArt.fa_grouped(hi)]
		_next_label.text = "تا ارتقا به %s" % str(next.get("name", ""))
		var left := maxi(hi - trophies, 0)
		# C9/E5 نزدیکِ پایان: «فقط ۴۰ کاپ مونده!» به طلایی
		_remain_label.text = ("فقط %s کاپ مونده!" if near else "%s کاپ باقی مانده") % MissionArt.fa_grouped(left)
		if near:
			_remain_label.add_theme_color_override("font_color", COLOR_GOLD)
		else:
			_remain_label.add_theme_color_override("font_color", COLOR_MUTED)
		_up_icon.visible = true
	else:
		_progress_value.text = MissionArt.fa_grouped(trophies)
		_next_label.text = "به بالاترین رنک بازی رسیده‌ای"
		_remain_label.text = ""
		_up_icon.visible = false

	_progress_bar.max_value = bar_max
	_progress_bar.value = 0.0
	create_tween().tween_property(_progress_bar, "value", bar_value, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	PsychProgress.emphasize_bar(_progress_bar, near)

	_refresh_ladder()

func _apply_avatar(avatar_id: String) -> void:
	var texture := AvatarPicker.load_avatar_texture(avatar_id)
	if texture == null:
		var ids := AvatarPicker.list_avatar_ids()
		if not ids.is_empty():
			texture = AvatarPicker.load_avatar_texture(ids[0])
	_avatar.texture = texture

## کارت فصل: شماره‌ی فصل و زمان باقی‌مانده تا پایانش
func _apply_season(data: Dictionary, rank: Dictionary) -> void:
	var number := int(data.get("season_number", 0))
	if number <= 0:
		# "season_1" → ۱
		var season_id := str(rank.get("season_id", ""))
		var tail := season_id.get_slice("_", season_id.get_slice_count("_") - 1)
		number = tail.to_int() if tail.is_valid_int() else 0
	_season_label.text = "فصل %s" % (MissionArt.fa_number(number) if number > 0 else "—")

	_days_label.text = "—"
	var end_unix := _parse_iso(str(data.get("season_ends_at", "")))
	if end_unix <= 0:
		return
	var left := end_unix - int(Time.get_unix_time_from_system())
	if left <= 0:
		_days_label.text = "پایان یافته"
		return
	var days := left / 86400
	var hours := (left % 86400) / 3600
	_days_label.text = "%s روز %s ساعت" % [MissionArt.fa_number(days), MissionArt.fa_number(hours)]

# ------------------------------------------------------------------ درجه‌های رنک

## ستون‌ها از چپ به راست: برنز → لجندری، با خط جداکننده و فلش بین هر دو.
func _build_ladder() -> void:
	for child in _tiers_row.get_children():
		child.queue_free()
	_tier_chips.clear()

	for i in _tiers.size():
		if i > 0:
			_tiers_row.add_child(_make_separator())
		var chip := TIER_CHIP_SCENE.instantiate()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tiers_row.add_child(chip)
		chip.setup(_tier_view(i), false)
		_tier_chips.append(chip)

func _refresh_ladder() -> void:
	for i in _tier_chips.size():
		_tier_chips[i].setup(_tier_view(i), i == _current_index)
	for i in _tier_chips.size():
		_tier_chips[i].play_pop(0.04 * float(i))

func _tier_view(index: int) -> Dictionary:
	var tier: Dictionary = _tiers[index].duplicate()
	tier["sub"] = TIER_SUBS.get(str(tier.get("id", "")), "")
	return tier

## خط عمودی بین دو ستون با فلش «›» آبی وسطش — با draw کشیده می‌شود
func _make_separator() -> Control:
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(18, 0)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.draw.connect(func() -> void:
		var c := sep.size * 0.5
		var line := Color(0.3, 0.42, 0.6, 0.4)
		sep.draw_line(Vector2(c.x, 6), Vector2(c.x, c.y - 14), line, 1.0)
		sep.draw_line(Vector2(c.x, c.y + 14), Vector2(c.x, sep.size.y - 6), line, 1.0)
		var points := PackedVector2Array([
			c + Vector2(-4, -9), c + Vector2(4, 0), c + Vector2(-4, 9)
		])
		sep.draw_polyline(points, COLOR_BLUE, 3.0, true)
	)
	return sep

func _tier_index_for(trophies: int) -> int:
	for i in range(_tiers.size() - 1, -1, -1):
		if trophies >= int(_tiers[i].get("min", 0)):
			return i
	return 0

func _tier_index_by_id(tier_id: String) -> int:
	for i in _tiers.size():
		if str(_tiers[i].get("id", "")) == tier_id:
			return i
	return -1

# ------------------------------------------------------------------ قوانین رنک

## ستون چپ: بازه‌ی کاپ هر رنک با نشانش · ستون راست: قوانین
func _build_rules() -> void:
	for child in _rules_tiers.get_children():
		child.queue_free()
	for child in _rules_list.get_children():
		child.queue_free()

	var font: Font = (_nav_rank.get_node("Row/Label") as Label).get_theme_font("font")
	var num_font: Font = _trophies_label.get_theme_font("font")

	for i in _tiers.size():
		var tier: Dictionary = _tiers[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var badge := TextureRect.new()
		badge.texture = RankArt.texture_for(str(tier.get("id", "")), str(tier.get("name", "")))
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.custom_minimum_size = Vector2(30, 30)
		row.add_child(badge)

		var range_label := Label.new()
		range_label.text = _range_words(int(tier.get("min", 0)), int(tier.get("max", 0)))
		range_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		range_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		range_label.add_theme_font_override("font", num_font)
		range_label.add_theme_font_size_override("font_size", 16)
		range_label.add_theme_color_override("font_color", COLOR_MUTED)
		row.add_child(range_label)

		var name_label := Label.new()
		name_label.text = str(tier.get("name", ""))
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_font_override("font", font)
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override(
			"font_color", COLOR_GOLD if i == _tiers.size() - 1 else COLOR_TEXT
		)
		row.add_child(name_label)
		_rules_tiers.add_child(row)

	for rule in RULES:
		var label := Label.new()
		label.text = "• " + rule
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", COLOR_TEXT)
		_rules_list.add_child(label)

func _range_words(min_value: int, max_value: int) -> String:
	if max_value <= 0:
		return "%s کاپ و بیشتر" % MissionArt.fa_number(min_value)
	return "%s تا %s کاپ" % [MissionArt.fa_number(maxi(min_value, 1)), MissionArt.fa_number(max_value)]

# ------------------------------------------------------------------- کمکی‌ها

## تاریخ ISO سرور ("2026-08-26T12:00:00Z") → یونیکس. صفر یعنی نشد.
func _parse_iso(value: String) -> int:
	var clean := value.strip_edges()
	if clean.is_empty():
		return 0
	var dot := clean.find(".")
	if dot != -1:
		clean = clean.substr(0, dot) + "Z"
	return int(Time.get_unix_time_from_datetime_string(clean))
