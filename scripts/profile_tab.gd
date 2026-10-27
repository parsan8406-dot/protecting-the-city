extends Control
## تب پروفایل — صفحه‌ی «هویت بازیکن». تمام اطلاعات از سرور (GET /profile).
## تغییر آواتار و نام کاربری از طریق POST /profile/update ذخیره می‌شود.
##
## چیدمان (دور ۳ — همه در کد ساخته می‌شود تا روی هر نسبت تصویر جا بیفتد):
##   سربرگ قهرمان   آواتار با حلقه‌ی سطح، نام (+ویرایش)، آیدی (+کپی)، وضعیت حساب،
##                   نشان رنک و کاپ، سلاح امضا
##   کاشی‌ها        چهار عدد مهارت: قربانیان، بردها، K/D، مسابقه‌ها
##   پایین          دستاوردها (ویترین + هدف بعدی) • فرم اخیر و آمار ریز • شهر
##
## E8 مالکیت / E1 شایستگی / E14 پاداش = تأیید مهارت: صفحه درباره‌ی «کیستی»
## بازیکن است، نه موجودی‌اش.

const AVATAR_PICKER_SCENE := preload("res://secense/avatar_picker.tscn")
const RENAME_DIALOG_SCENE := preload("res://secense/rename_dialog.tscn")
## E8 آمار شایستگی از مسابقه‌های اخیر
const PsychSocialMastery := preload("res://scripts/psych_social_mastery.gd")
const UI := preload("res://scripts/psych_profile_ui.gd")

const CITY_SCENE_PATH := "res://secense/city.tscn"
const RANK_SCENE_PATH := "res://secense/rank_screen.tscn"

const ICON_CLAN := preload("res://assets/ui/profile_menu/icon_clan.svg")
const ICON_RANK := preload("res://assets/ui/profile_menu/icon_ranking.svg")
const ICON_FORM := preload("res://assets/ui/profile_menu/icon_matches.svg")
const ICON_FRIENDS := preload("res://assets/ui/profile_menu/icon_friends.svg")
const WEAPON_BG := preload("res://assets/ui/profile_menu/weapon_card_bg.svg")
## E12 جای خالیِ دستاوردهای قفل
const PADLOCK_PATH := "res://assets/ui/psych/tease_padlock.png"

## کاشی‌های بزرگ: [کلید، عنوان، متریک آیکن]
const TILES := [
	["kills", "قربانیان", "kills"],
	["wins", "بردها", "wins"],
	["kd", "نسبت K/D", "kd"],
	["total_matches", "مسابقه‌ها", "total_matches"],
]
## آمار ریز داخل کارت فرم: [کلید، عنوان، متریک آیکن]
const MINI_STATS := [
	["assists", "کمک", "assists"],
	["grenade_kills", "نارنجک", "grenade_kills"],
	["heals_given", "درمان", "heals_given"],
	["missions_done", "ماموریت", "missions_done"],
	["playtime_hours", "ساعت بازی", "playtime_seconds"],
	["friends", "دوستان", "friends"],
]

const ACHIEVEMENT_SLOTS := 4
const FORM_DOTS := 10
## اندازه‌ی آواتار سربرگ
const AVATAR_SIDE := 140.0
const NAME_FONT := 30

@onready var _http: HTTPRequest = $HTTPRequest

var _update_http: HTTPRequest
var _profile: Dictionary = {}
var _rename_dialog: Control = null
var _pending_username: String = ""
var _error_banner: Button = null
var _loaded := false
var _loading_tweens: Array[Tween] = []

# --- سربرگ ---
var _hero: Control
var _avatar_button: Button
var _avatar_parts: Dictionary = {}
var _name_label: Label
var _rename_button: Button
var _id_label: Label
var _copy_id_button: Button
var _account_badge: Button
var _xp_label: Label
var _rank_button: Button
var _rank_icon: TextureRect
var _tier_label: Label
var _trophy_label: Label
var _rank_bar: ProgressBar
var _rank_note: Label
var _weapon_texture: TextureRect
var _weapon_title: Label
var _weapon_name: Label
var _weapon_sub: Label

# --- کاشی‌ها و کارت‌ها ---
var _tiles_row: HBoxContainer
var _tiles: Dictionary = {}
var _bottom_row: HBoxContainer
var _form_title: Label
var _form_dots: HBoxContainer
var _mastery_label: Label
var _mini_values: Dictionary = {}
var _achievement_count: Label
var _achievements_all: Button
var _achievement_slots: HBoxContainer
var _next_label: Label
var _next_bar: ProgressBar
var _next_note: Label
var _clan_name: Label
var _clan_detail: Label
var _clan_view_button: Button
var _cards: Array[Control] = []

# ------------------------------------------------------------------ آماده‌سازی

func _ready() -> void:
	_http.request_completed.connect(_on_profile_received)

	_update_http = HTTPRequest.new()
	_update_http.timeout = 12.0
	add_child(_update_http)
	_update_http.request_completed.connect(_on_update_completed)

	_build()
	_build_error_banner()

	Global.account_switched.connect(refresh)
	Global.social_event.connect(func(kind: String) -> void:
		if kind == "achievement":
			refresh())
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree():
			refresh())

	# تا جواب سرور برسد، دیتای کش‌شده‌ی Global را نشان بده (C12: صفحه هیچ‌وقت خالی نیست)
	_apply_avatar(Global.avatar_id)
	_set_name(str(Global.my_username))
	_apply_id(str(Global.player_id))
	_apply_account_badge()
	_avatar_parts.level.text = MenuUI.fa(int(Global.level))
	_apply_weapon(str(Global.current_weapon), "سلاح تجهیزشده", "")
	_set_loading(true)

	refresh()

## گرفتن دوباره‌ی پروفایل از سرور
func refresh() -> void:
	var username: String = str(Global.my_username)
	if username.is_empty():
		return
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var url := "%s/profile?username=%s" % [Global.SERVER_BASE, username.uri_encode()]
	if _http.request(url, Global.auth_headers()) != OK:
		_show_error("اتصال به سرور برقرار نشد")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and is_inside_tree() and is_visible_in_tree():
		refresh()

func _on_profile_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_show_error(MenuUI.server_error(body, response_code if result == HTTPRequest.RESULT_SUCCESS else 0,
			"پروفایل از سرور نیامد"))
		return
	var data := MenuUI.parse_json(body)
	if data.is_empty():
		_show_error("پاسخ پروفایل قابل خواندن نبود")
		return
	_error_banner.visible = false
	_profile = data
	_set_loading(false)
	_apply_profile(_profile)

# ------------------------------------------------------------------ ساخت صفحه

func _build() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 10
	scroll.offset_top = 10
	scroll.offset_right = -10
	scroll.offset_bottom = -10
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	UIScroll.attach(scroll)

	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	scroll.add_child(page)

	page.add_child(_build_hero())

	# V10 چهار عدد بزرگ مهارت
	_tiles_row = HBoxContainer.new()
	_tiles_row.add_theme_constant_override("separation", 10)
	for spec in TILES:
		var tile := UI.stat_tile(_icon_for(spec[2]), spec[1])
		_tiles_row.add_child(tile.panel)
		_tiles[spec[0]] = tile
	page.add_child(_tiles_row)

	_bottom_row = HBoxContainer.new()
	_bottom_row.add_theme_constant_override("separation", 10)
	_bottom_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_bottom_row)
	# چپ به راست روی صفحه؛ خواندن راست‌به‌چپ از دستاوردها شروع می‌شود
	var clan := _build_clan_card()
	clan.size_flags_stretch_ratio = 0.78
	_bottom_row.add_child(clan)
	var form := _build_form_card()
	form.size_flags_stretch_ratio = 1.1
	_bottom_row.add_child(form)
	var ach := _build_achievements_card()
	ach.size_flags_stretch_ratio = 1.3
	_bottom_row.add_child(ach)
	for c in [clan, form, ach]:
		(c as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards = [_hero, _tiles_row, ach, form, clan]
	resized.connect(_adapt_height)

## ۴:۳ و تبلت ارتفاع بیشتری دارند: سربرگ، کاشی‌ها و مدال‌ها بزرگ‌تر می‌شوند
## تا کارت‌های پایین خالی و کشیده نمانند (پایه: ارتفاع ۱۶:۹)
func _adapt_height() -> void:
	var extra := clampf(size.y - 568.0, 0.0, 320.0)
	_hero.custom_minimum_size.y = 168.0 + extra * 0.22
	for key in _tiles:
		(_tiles[key].panel as Control).custom_minimum_size.y = 70.0 + extra * 0.12
	for slot in _achievement_slots.get_children():
		var box := slot.get_child(0) as Control
		if box != null:
			box.custom_minimum_size.y = 64.0 + extra * 0.3

## سربرگ قهرمان — نقطه‌ی کانونی صفحه (V4/V8)
func _build_hero() -> Control:
	var hero := PanelContainer.new()
	var hs := MenuUI.box(Color(0.085, 0.06, 0.055, 0.97), Color(MenuUI.GOLD_DEEP, 0.7), 1, 10)
	hs.border_width_bottom = 3
	hs.border_color = Color(MenuUI.GOLD_DEEP, 0.9)
	hs.set_content_margin_all(0)
	hero.add_theme_stylebox_override("panel", hs)
	hero.custom_minimum_size = Vector2(0, 168)
	_hero = hero

	# درخشش قرمز ملایم پشت آواتار (سمت راست) — عمق بدون شیدر
	var glow := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.55, 0.04, 0.06, 0.0))
	grad.set_color(1, Color(0.55, 0.04, 0.06, 0.32))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0.35, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 8
	glow.texture = gt
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(glow)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 16)
	for side in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	hero.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	row.add_child(_build_weapon_block())
	row.add_child(_vsep())
	row.add_child(_build_rank_block())
	row.add_child(_vsep())
	row.add_child(_build_identity_block())
	row.add_child(_build_avatar())
	return hero

func _icon_for(metric: String) -> Texture2D:
	match metric:
		"kd": return ICON_RANK
		"friends": return ICON_FRIENDS
	return MenuUI.metric_icon(metric)

func _vsep() -> Control:
	var s := ColorRect.new()
	s.color = Color(1, 1, 1, 0.07)
	s.custom_minimum_size = Vector2(1, 0)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s

## آواتار داخل حلقه‌ی سطح + نشان مداد (V9: معلوم است قابل تغییر است)
func _build_avatar() -> Control:
	_avatar_button = Button.new()
	_avatar_button.flat = true
	_avatar_button.focus_mode = Control.FOCUS_NONE
	_avatar_button.custom_minimum_size = Vector2(AVATAR_SIDE, AVATAR_SIDE)
	_avatar_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		_avatar_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_avatar_parts = UI.avatar_with_ring(AVATAR_SIDE, 20)
	var root: Control = _avatar_parts.root
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_avatar_button.add_child(root)
	var pencil := PanelContainer.new()
	pencil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pencil.add_theme_stylebox_override("panel", MenuUI.box(Color(0.12, 0.12, 0.13, 1.0), MenuUI.GOLD, 2, 16))
	pencil.custom_minimum_size = Vector2(32, 32)
	pencil.position = Vector2(2, 2)
	pencil.add_child(MenuUI.icon(UI.ICON_EDIT, 16, MenuUI.GOLD))
	_avatar_button.add_child(pencil)
	_avatar_button.pressed.connect(_on_avatar_pressed)
	return _avatar_button

## نام، آیدی، وضعیت حساب و تجربه تا سطح بعد
func _build_identity_block() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_row.alignment = BoxContainer.ALIGNMENT_END
	_rename_button = UI.icon_button(UI.ICON_EDIT, "ghost", 44)
	_rename_button.pressed.connect(_on_rename_pressed)
	name_row.add_child(_rename_button)
	# نام کنار مدادِ ویرایش؛ نام بلند به‌جای بریده‌شدن کمی کوچک‌تر می‌شود (_fit_name)
	_name_label = MenuUI.label("", NAME_FONT, MenuUI.TEXT, true)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.clip_text = true
	name_row.add_child(_name_label)
	col.add_child(name_row)
	col.resized.connect(_fit_name)

	var id_row := HBoxContainer.new()
	id_row.add_theme_constant_override("separation", 8)
	id_row.alignment = BoxContainer.ALIGNMENT_END
	_copy_id_button = UI.icon_button(UI.ICON_COPY, "ghost", 44)
	_copy_id_button.pressed.connect(_on_copy_id_pressed)
	id_row.add_child(_copy_id_button)
	_id_label = MenuUI.label("", 17, MenuUI.MUTED, true)
	_id_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	id_row.add_child(_id_label)
	col.add_child(id_row)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	_account_badge = MenuUI.button("", "red", 13)
	_account_badge.custom_minimum_size = Vector2(0, 44)
	_account_badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_account_badge.pressed.connect(_on_account_badge_pressed)
	status_row.add_child(_account_badge)
	# C9 شیب هدف: «۸۶۰ تجربه تا سطح ۲۸» کنار حلقه‌ی سطح
	_xp_label = MenuUI.label("", 15, MenuUI.GOLD)
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_xp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_xp_label.clip_text = true
	status_row.add_child(_xp_label)
	col.add_child(status_row)
	return col

## نشان رنک + کاپ + فاصله تا رنک بعد. لمس → صفحه‌ی رنک (E9/E15 مسیر Achiever)
func _build_rank_block() -> Control:
	_rank_button = Button.new()
	_rank_button.flat = true
	_rank_button.focus_mode = Control.FOCUS_NONE
	_rank_button.custom_minimum_size = Vector2(152, 0)
	for state in ["normal", "hover", "focus", "disabled"]:
		_rank_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var pressed_style := MenuUI.box(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 0, 8)
	_rank_button.add_theme_stylebox_override("pressed", pressed_style)
	_rank_button.add_theme_stylebox_override("hover_pressed", pressed_style)
	UIFx.bind_press_feedback(_rank_button)
	_rank_button.pressed.connect(_on_rank_pressed)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rank_button.add_child(col)
	_rank_icon = MenuUI.icon(null, 64)
	_rank_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_rank_icon)
	_tier_label = MenuUI.label("—", 19, MenuUI.GOLD)
	_tier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_tier_label)
	_trophy_label = MenuUI.label("", 16, MenuUI.TEXT, true)
	_trophy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_trophy_label)
	_rank_bar = MenuUI.progress_bar(MenuUI.GOLD, 6)
	col.add_child(_rank_bar)
	_rank_note = MenuUI.label("", 13, MenuUI.MUTED)
	_rank_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_rank_note.clip_text = true
	col.add_child(_rank_note)
	return _rank_button

## E8 سلاح امضا: سلاحی که بیشتر از همه با آن بازی کرده + کیل‌هایش
func _build_weapon_block() -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(196, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ws := MenuUI.box(Color(0, 0, 0, 0), Color(MenuUI.GOLD, 0.35), 1, 8)
	ws.set_content_margin_all(0)
	box.add_theme_stylebox_override("panel", ws)
	var bg := TextureRect.new()
	bg.texture = WEAPON_BG
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.modulate = Color(1, 1, 1, 0.55)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bg)
	var m := MarginContainer.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 8)
	box.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(col)
	_weapon_title = MenuUI.label("سلاح امضای تو", 14, Color(1, 0.93, 0.78, 0.9))
	_weapon_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_weapon_title)
	_weapon_texture = TextureRect.new()
	_weapon_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weapon_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_weapon_texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_weapon_texture.custom_minimum_size = Vector2(0, 60)
	_weapon_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_weapon_texture)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_sub = MenuUI.label("", 13, Color(1, 1, 1, 0.82))
	_weapon_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_weapon_sub.clip_text = true
	name_row.add_child(_weapon_sub)
	_weapon_name = MenuUI.label("", 20, Color.WHITE, true)
	_weapon_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_row.add_child(_weapon_name)
	col.add_child(name_row)
	return box

## E7/E12 ویترین دستاوردها: تازه‌ترین‌ها طلایی، جای خالی قفل، و هدف بعدی
func _build_achievements_card() -> Control:
	var parts := UI.card("دستاوردها", MenuUI.ICON_ACHIEVEMENT)
	var body: VBoxContainer = parts[1]
	var title_row: HBoxContainer = body.get_child(0)
	_achievement_count = MenuUI.label("", 18, MenuUI.GOLD, true)
	title_row.add_child(_achievement_count)
	title_row.move_child(_achievement_count, 0)
	_achievements_all = MenuUI.button("همه", "dark", 15)
	_achievements_all.custom_minimum_size = Vector2(76, 44)
	_achievements_all.pressed.connect(_on_all_achievements_pressed)
	title_row.add_child(_achievements_all)
	title_row.move_child(_achievements_all, 0)

	_achievement_slots = HBoxContainer.new()
	_achievement_slots.add_theme_constant_override("separation", 8)
	_achievement_slots.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	body.add_child(_achievement_slots)

	_next_label = MenuUI.label("", 14, MenuUI.TEXT)
	_next_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_next_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_next_label.clip_text = true
	body.add_child(_next_label)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 8)
	_next_note = MenuUI.label("", 13, MenuUI.GOLD, true)
	bar_row.add_child(_next_note)
	_next_bar = MenuUI.progress_bar(MenuUI.GOLD, 8)
	_next_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_row.add_child(_next_bar)
	body.add_child(bar_row)
	_fill_achievement_slots([], 0)
	return parts[0]

## فرم ۱۰ مسابقه‌ی اخیر + خط شایستگی + آمار ریز
func _build_form_card() -> Control:
	var parts := UI.card("فرم اخیر", ICON_FORM)
	var body: VBoxContainer = parts[1]
	var title_row: HBoxContainer = body.get_child(0)
	_form_title = MenuUI.label("", 14, MenuUI.MUTED)
	title_row.add_child(_form_title)
	title_row.move_child(_form_title, 0)

	_form_dots = HBoxContainer.new()
	_form_dots.add_theme_constant_override("separation", 5)
	_form_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(_form_dots)
	_build_form_dots([])

	_mastery_label = MenuUI.label("", 14, MenuUI.GOLD)
	_mastery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mastery_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mastery_label.visible = false
	body.add_child(_mastery_label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	for spec in MINI_STATS:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", -2)
		var top := HBoxContainer.new()
		top.alignment = BoxContainer.ALIGNMENT_CENTER
		top.add_theme_constant_override("separation", 4)
		var v := MenuUI.label("۰", 19, MenuUI.TEXT, true)
		top.add_child(v)
		top.add_child(MenuUI.icon(_icon_for(spec[2]), 16, MenuUI.MUTED))
		cell.add_child(top)
		var t := MenuUI.label(spec[1], 12, MenuUI.DIM)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(t)
		grid.add_child(cell)
		_mini_values[spec[0]] = v
	body.add_child(grid)
	return parts[0]

## E1 ارتباط: شهر یا دعوت به پیدا کردن شهر
func _build_clan_card() -> Control:
	var parts := UI.card("شهر", ICON_CLAN)
	var body: VBoxContainer = parts[1]
	var mid := VBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 4)
	body.add_child(mid)
	var icon := MenuUI.icon(ICON_CLAN, 44, MenuUI.GOLD)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mid.add_child(icon)
	_clan_name = MenuUI.label("—", 18, MenuUI.TEXT)
	_clan_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clan_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(_clan_name)
	_clan_detail = MenuUI.label("", 13, MenuUI.MUTED)
	_clan_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clan_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(_clan_detail)
	_clan_view_button = MenuUI.button("مشاهده", "dark", 16)
	_clan_view_button.pressed.connect(_on_clan_view_pressed)
	body.add_child(_clan_view_button)
	return parts[0]

func _build_form_dots(recent: Array) -> void:
	for child in _form_dots.get_children():
		child.queue_free()
	var wins := 0
	# جدیدترین سمت راست (خواندن راست‌به‌چپ)
	for i in FORM_DOTS:
		var index := FORM_DOTS - 1 - i
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(18, 18)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var color := Color(0.2, 0.2, 0.22, 1.0)
		var border := Color(0, 0, 0, 0.4)
		if index < recent.size() and recent[index] is Dictionary:
			var m: Dictionary = recent[index]
			if bool(m.get("draw", false)):
				color = Color(0.6, 0.6, 0.64, 1.0)
			elif bool(m.get("won", false)):
				color = MenuUI.GREEN
				wins += 1
			else:
				color = MenuUI.RED_HOT
			if index == 0:
				border = Color.WHITE
		dot.add_theme_stylebox_override("panel", MenuUI.box(color, border, 2 if index == 0 else 1, 9))
		_form_dots.add_child(dot)
	if recent.is_empty():
		_form_title.text = "هنوز مسابقه‌ای نیست"
	else:
		_form_title.text = "%s برد از %s" % [MenuUI.fa(wins), MenuUI.fa(mini(recent.size(), FORM_DOTS))]

func _build_error_banner() -> void:
	_error_banner = MenuUI.button("", "red", 16)
	_error_banner.visible = false
	_error_banner.z_index = 5
	_error_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_error_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_error_banner.offset_top = 10
	_error_banner.pressed.connect(func() -> void:
		_error_banner.visible = false
		refresh())
	add_child(_error_banner)

func _show_error(message: String) -> void:
	_error_banner.text = message + " — تلاش دوباره"
	_error_banner.visible = true
	_error_banner.reset_size()
	UI.pop(_error_banner, 1.06)

# ------------------------------------------------------------------ حالت بارگذاری

## C12 تا رسیدن پاسخ اول، کاشی‌ها و کارت‌ها آرام می‌تپند (نه صفحه‌ی یخ‌زده)
func _set_loading(on: bool) -> void:
	for t in _loading_tweens:
		if t != null and t.is_valid():
			t.kill()
	_loading_tweens.clear()
	if on and not _loaded:
		for c in [_tiles_row, _bottom_row]:
			var ctl := c as Control
			var t := ctl.create_tween().set_loops()
			t.tween_property(ctl, "modulate:a", 0.45, 0.6).set_trans(Tween.TRANS_SINE)
			t.tween_property(ctl, "modulate:a", 0.85, 0.6).set_trans(Tween.TRANS_SINE)
			_loading_tweens.append(t)
		for key in _tiles:
			_tiles[key].value.text = "—"
		return
	for c in [_tiles_row, _bottom_row]:
		(c as Control).modulate.a = 1.0

# ------------------------------------------------------------------ پر کردن UI

func _apply_profile(data: Dictionary) -> void:
	var first := not _loaded
	_loaded = true

	# --- هویت ---
	_set_name(str(data.get("username", Global.my_username)))
	_apply_avatar(str(data.get("avatar_id", "")))
	_apply_id(str(data.get("player_id", Global.player_id)))
	if data.has("google_linked"):
		Global.google_linked = bool(data["google_linked"])
	_apply_account_badge()

	var level := int(data.get("level", 1))
	var into := int(data.get("display_xp", 0))
	var need := maxi(1, int(data.get("max_xp", level * 100)))
	_avatar_parts.level.text = MenuUI.fa(level)
	(_avatar_parts.ring as UI.LevelRing).animate_to(float(into) / float(need))
	_xp_label.text = "%s تجربه تا سطح %s" % [MenuUI.fa_grouped(maxi(need - into, 0)), MenuUI.fa(level + 1)]

	# --- کاشی‌ها ---
	var stats: Dictionary = data.get("stats", {}) if data.get("stats") is Dictionary else {}
	UI.count_to(_tiles["kills"].value, int(stats.get("kills", 0)))
	UI.count_to(_tiles["wins"].value, int(stats.get("wins", 0)))
	_tiles["wins"].sub.text = "بردها  •  %s٪" % MenuUI.fa(int(stats.get("win_rate", 0)))
	_tiles["kd"].value.text = MenuUI.kd_text(float(stats.get("kd_ratio", 0.0)))
	UI.count_to(_tiles["total_matches"].value, int(stats.get("total_matches", 0)))
	for spec in MINI_STATS:
		var key: String = spec[0]
		var v := int(data.get("friend_count", 0)) if key == "friends" else int(stats.get(key, 0))
		UI.count_to(_mini_values[key], v)

	var recent = data.get("recent_matches", [])
	var recent_list: Array = recent if recent is Array else []
	_build_form_dots(recent_list)
	var mastery := PsychSocialMastery.from_recent(recent_list)
	_mastery_label.text = PsychSocialMastery.mastery_line(mastery)
	_mastery_label.visible = not _mastery_label.text.is_empty()

	# --- رنک (از روی کاپ) ---
	var rank: Dictionary = data.get("rank", {}) if data.get("rank") is Dictionary else {}
	var tier_name := str(rank.get("tier_name", "—"))
	_tier_label.text = tier_name
	_rank_icon.texture = RankArt.texture_for(str(rank.get("tier_id", "")), tier_name)
	var points := int(rank.get("points", data.get("trophies", 0)))
	var points_max := int(rank.get("points_max", 0))
	_trophy_label.text = "%s کاپ" % MenuUI.fa_grouped(points)
	_rank_bar.max_value = maxf(1.0, float(points_max))
	_tween_bar(_rank_bar, float(points))
	_rank_bar.visible = points_max > points
	if points_max > points:
		# E6 قاب مثبت: فاصله تا رنک بعد، نه «چقدر عقبی»
		_rank_note.text = "%s کاپ تا رنک بعد" % MenuUI.fa_grouped(points_max - points + 1)
	else:
		_rank_note.text = "بهترین رنک: %s" % str(data.get("best_tier_name", tier_name))

	# --- دستاوردها ---
	_apply_achievements(data)

	# --- شهر ---
	_apply_clan(data.get("clan", null))

	# --- سلاح امضا: پرکاربردترین سلاح مسابقه‌های اخیر، وگرنه آخرین/تجهیزشده ---
	if int(mastery.fav_matches) >= 2:
		_apply_weapon(str(mastery.fav_weapon), "سلاح امضای تو", "%s کیل در %s مسابقه" % [
			MenuUI.fa_grouped(int(mastery.fav_kills)), MenuUI.fa(int(mastery.fav_matches))])
	else:
		var last_weapon := str(stats.get("last_used_weapon", ""))
		if last_weapon.is_empty():
			last_weapon = str(data.get("equipped_weapon", Global.current_weapon))
		var played := int(stats.get("total_matches", 0)) > 0
		_apply_weapon(last_weapon, "آخرین سلاح" if played else "سلاح تجهیزشده",
			"" if played else "به‌زودی امضای تو")

	if first:
		_play_intro()

func _set_name(username: String) -> void:
	_name_label.text = username
	_fit_name()

## نام بلند (تا ۲۰ حرف) روی گوشی ۴:۳ و ۱۶:۹ جا شود — فونت تا ۱۸ پایین می‌آید
func _fit_name() -> void:
	if _name_label == null:
		return
	var col := _name_label.get_parent().get_parent() as Control
	var room := col.size.x - _rename_button.size.x - 12.0
	if room <= 10.0:
		return
	var font := _name_label.get_theme_font("font")
	var fs := NAME_FONT
	while fs > 18 and font.get_string_size(_name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 2
	_name_label.add_theme_font_size_override("font_size", fs)
	# clip_text حداقل عرض را صفر می‌کند؛ عرض واقعی را خودمان می‌دهیم (تا سقف جا)
	var w := font.get_string_size(_name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 4.0
	_name_label.custom_minimum_size.x = minf(w, room)

func _apply_id(pid: String) -> void:
	_id_label.text = "ID : %s" % (pid if not pid.is_empty() else "—")
	_copy_id_button.disabled = pid.is_empty()

## نشان وضعیت حساب — مهمان (قرمز = خطر از دست رفتن پیشرفت) با یک ضربه به تنظیمات می‌رود
func _apply_account_badge() -> void:
	if Global.google_linked:
		_account_badge.text = "حساب محافظت‌شده ✓"
		MenuUI.style_button(_account_badge, "ghost")
		_account_badge.add_theme_color_override("font_color", MenuUI.GOLD)
	else:
		_account_badge.text = "مهمان — محافظت از حساب"
		MenuUI.style_button(_account_badge, "red")

func _tween_bar(bar: ProgressBar, value: float) -> void:
	create_tween().tween_property(bar, "value", value, 0.7) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _apply_avatar(avatar_id: String) -> void:
	(_avatar_parts.avatar as TextureRect).texture = MenuUI.avatar_texture(avatar_id)

func _apply_achievements(data: Dictionary) -> void:
	var unlocked := int(data.get("achievements_unlocked", 0))
	var total := int(data.get("achievements_total", 0))
	_achievement_count.text = "%s / %s" % [MenuUI.fa(unlocked), MenuUI.fa(total)]
	_achievements_all.disabled = total == 0

	var recent = data.get("achievements", [])
	var items: Array = recent if recent is Array else []
	_fill_achievement_slots(items, total)

	var next = data.get("next_achievement", null)
	if next is Dictionary:
		var n: Dictionary = next
		var target := maxi(1, int(n.get("target", 1)))
		var progress := int(n.get("progress", 0))
		var is_time := str(n.get("metric", "")) == "playtime_seconds"
		var shown_progress := int(progress / 3600.0) if is_time else progress
		var shown_target := int(target / 3600.0) if is_time else target
		_next_label.text = "هدف بعدی : %s" % str(n.get("name", ""))
		_next_note.text = "%s / %s%s" % [MenuUI.fa_grouped(shown_progress), MenuUI.fa_grouped(shown_target),
			" ساعت" if is_time else ""]
		_next_bar.max_value = float(target)
		_tween_bar(_next_bar, float(progress))
		# C9 نزدیک پایان برجسته‌تر — فقط وقتی واقعاً نزدیک است
		var left := shown_target - shown_progress
		if float(progress) / float(target) >= 0.75 and left > 0:
			_next_label.text += "  —  فقط %s تا مونده!" % MenuUI.fa_grouped(left)
		_next_label.visible = true
		_next_bar.get_parent().visible = true
	elif total > 0:
		_next_label.text = "همه‌ی دستاوردها را باز کرده‌ای!"
		_next_label.visible = true
		_next_bar.get_parent().visible = false
	else:
		_next_label.visible = false
		_next_bar.get_parent().visible = false

## چهار جایگاه: تازه‌ترین دستاوردها طلایی؛ بقیه قفل و نیمه‌پیدا (E12)
func _fill_achievement_slots(items: Array, total: int) -> void:
	for child in _achievement_slots.get_children():
		child.queue_free()
	var shown := 0
	for i in mini(items.size(), ACHIEVEMENT_SLOTS):
		if items[i] is Dictionary:
			_achievement_slots.add_child(_achievement_slot(items[i]))
			shown += 1
	var locked_left := ACHIEVEMENT_SLOTS - shown
	if total > 0:
		locked_left = mini(locked_left, maxi(total - shown, 0))
	for i in locked_left:
		_achievement_slots.add_child(_locked_slot())
	_adapt_height.call_deferred()

func _achievement_slot(item: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(0, 64)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := MenuUI.box(Color(0.2, 0.14, 0.03, 0.95), MenuUI.GOLD, 2, 10)
	st.shadow_color = Color(1.0, 0.75, 0.2, 0.18)
	st.shadow_size = 6
	box.add_theme_stylebox_override("panel", st)
	var icon := MenuUI.icon(MenuUI.metric_icon(str(item.get("metric", ""))), 34, MenuUI.GOLD)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	col.add_child(box)
	var name_label := MenuUI.label(str(item.get("name", "—")), 12, MenuUI.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	col.add_child(name_label)
	return col

func _locked_slot() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(0, 64)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_stylebox_override("panel", MenuUI.box(Color(0.1, 0.1, 0.11, 0.9), Color(0.3, 0.3, 0.33, 0.6), 1, 10))
	var tex: Texture2D = load(PADLOCK_PATH) if ResourceLoader.exists(PADLOCK_PATH) else MenuUI.ICON_ACHIEVEMENT
	var icon := MenuUI.icon(tex, 34, Color(1, 1, 1, 0.45))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(icon)
	col.add_child(box)
	var l := MenuUI.label("؟", 12, MenuUI.DIM)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	return col

func _apply_clan(clan: Variant) -> void:
	if clan is Dictionary and not (clan as Dictionary).is_empty():
		var c: Dictionary = clan
		_clan_name.text = str(c.get("name", "—"))
		var role := str(c.get("role", ""))
		var role_text := {"leader": "رهبر", "officer": "معاون"}.get(role, "عضو") as String
		_clan_detail.text = "%s  •  سطح %s  •  %s/%s نفر" % [role_text, MenuUI.fa(int(c.get("level", 0))),
			MenuUI.fa(int(c.get("member_count", 0))), MenuUI.fa(int(c.get("max_members", 0)))]
		_clan_view_button.text = "مشاهده‌ی شهر"
		MenuUI.style_button(_clan_view_button, "dark")
	else:
		_clan_name.text = "هنوز شهری نداری"
		_clan_detail.text = "با هم‌شهری‌ها چت کن و در جدول شهرها بالا برو"
		_clan_view_button.text = "پیدا کردن شهر"
		MenuUI.style_button(_clan_view_button, "gold")

func _apply_weapon(weapon_id: String, title: String, sub: String) -> void:
	_weapon_title.text = title
	if weapon_id.is_empty():
		_weapon_texture.texture = null
		_weapon_name.text = ""
		_weapon_sub.text = sub
		return
	_weapon_texture.texture = MenuUI.weapon_texture(weapon_id)
	_weapon_name.text = MenuUI.weapon_name(weapon_id)
	_weapon_sub.text = sub

# ------------------------------------------------------------------ انیمیشن ورود

## V7 ورود پلکانی کوتاه (≤۲۵۰ms برای هر بخش، ورودی را قفل نمی‌کند)
func _play_intro() -> void:
	UI.stagger_in(_cards, 0.05)
	var ring_root: Control = _avatar_parts.root
	UI.pop(ring_root, 0.9)

# ------------------------------------------------------------------ دکمه‌ها

func _on_avatar_pressed() -> void:
	UIFx.press(_avatar_button)
	var picker := AVATAR_PICKER_SCENE.instantiate()
	picker.add_to_group("modal")
	add_child(picker)
	picker.avatar_selected.connect(_on_avatar_selected)
	picker.open(str(_profile.get("avatar_id", Global.avatar_id)))

func _on_avatar_selected(avatar_id: String) -> void:
	Global.avatar_id = avatar_id
	_apply_avatar(avatar_id)
	UI.pop(_avatar_parts.root, 1.08)
	LocalSettings.vibrate(20)
	# بدون منتظر ماندنِ جوابِ سرور (C12 Optimistic UI)، تاپ‌بار همان لحظه عوض می‌شود
	Global.player_data_updated.emit()
	_send_update({"avatar_id": avatar_id})

func _on_rename_pressed() -> void:
	UIFx.press(_rename_button)
	_rename_dialog = RENAME_DIALOG_SCENE.instantiate()
	_rename_dialog.add_to_group("modal")
	add_child(_rename_dialog)
	_rename_dialog.name_confirmed.connect(_on_name_confirmed)
	_rename_dialog.open(str(_profile.get("username", Global.my_username)))

func _on_name_confirmed(new_name: String) -> void:
	_pending_username = new_name.strip_edges()
	_send_update({"new_username": _pending_username})

func _on_copy_id_pressed() -> void:
	UIFx.press(_copy_id_button)
	var pid := str(_profile.get("player_id", Global.player_id))
	if pid.is_empty():
		return
	DisplayServer.clipboard_set(pid)
	LocalSettings.vibrate(15)
	# C12 بازخورد فوری: آیدی لحظه‌ای طلایی می‌شود و «کپی شد» می‌گوید
	_id_label.text = "کپی شد ✓"
	_id_label.add_theme_color_override("font_color", MenuUI.GOLD)
	UI.pop(_id_label)
	get_tree().create_timer(1.4).timeout.connect(func() -> void:
		if is_instance_valid(_id_label):
			_id_label.add_theme_color_override("font_color", MenuUI.MUTED)
			_apply_id(pid))

func _on_all_achievements_pressed() -> void:
	UIFx.press(_achievements_all)
	var catalog = _profile.get("achievement_catalog", [])
	AchievementsDialog.open(self, catalog if catalog is Array else [])

func _on_account_badge_pressed() -> void:
	UIFx.tap(_account_badge, func() -> void: Global.request_profile_tab("settings"))

func _on_rank_pressed() -> void:
	UIFx.tap(_rank_button, func() -> void:
		get_tree().change_scene_to_file(RANK_SCENE_PATH))

## هر دو حالت دکمه («مشاهده» و «پیدا کردن شهر») به یک جا می‌روند —
## خودِ صحنه‌ی شهر تشخیص می‌دهد باید لیست شهرها را نشان دهد یا شهر بازیکن را.
func _on_clan_view_pressed() -> void:
	UIFx.press(_clan_view_button, func() -> void:
		get_tree().change_scene_to_file(CITY_SCENE_PATH))

# ------------------------------------------------------------------ ذخیره روی سرور

func _send_update(fields: Dictionary) -> void:
	var payload := fields.duplicate()
	payload["username"] = Global.my_username
	var err := _update_http.request(Global.SERVER_BASE + "/profile/update", Global.json_headers(),
		HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		_pending_username = ""
		if is_instance_valid(_rename_dialog) and _rename_dialog.visible:
			_rename_dialog.show_error("اتصال به سرور برقرار نشد")
		else:
			_show_error("اتصال به سرور برقرار نشد")

func _on_update_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var message := MenuUI.server_error(body, response_code if result == HTTPRequest.RESULT_SUCCESS else 0,
			"تغییرات ذخیره نشد")
		_pending_username = ""
		# اگر باکس تغییر نام باز است، خطا را همان‌جا نشان بده
		if is_instance_valid(_rename_dialog) and _rename_dialog.visible:
			_rename_dialog.show_error(message)
		else:
			_show_error(message)
		return

	# موفق: نام تازه روی دستگاه هم ذخیره می‌شود (قبلاً فقط در حافظه عوض می‌شد
	# و اجرای بعدی با اسم قدیمی یک حساب خالیِ تازه می‌ساخت)
	if not _pending_username.is_empty():
		var confirmed := str(MenuUI.parse_json(body).get("username", _pending_username))
		Global.apply_rename(confirmed)
		_set_name(confirmed)
		UI.pop(_name_label, 1.1)
		_pending_username = ""
		LocalSettings.vibrate(25)

	if is_instance_valid(_rename_dialog):
		_rename_dialog.close()
		_rename_dialog = null

	Global.refresh_player_data()
	refresh()
