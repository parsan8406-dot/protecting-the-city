extends Control
## صفحه‌ی انتخاب کاراکتر و سلاح.
##
## کاتالوگ آیتم‌ها از همان /get_shop می‌آید که فروشگاه استفاده می‌کند، ولی
## «مالکیت» از Global خوانده می‌شود (Global با /get_player پرش می‌کند و بعد از
## هر خرید هم تازه می‌شود). پس این صفحه هیچ‌وقت آیتمی را نشان نمی‌دهد که
## بازیکن نتواند بخرد، و هیچ آیتم قفلی هم قابل انتخاب نیست.
##
## پس‌زمینه و انیمیشن نورش عیناً همان پس‌زمینه‌ی فروشگاه است تا دو صفحه یک
## دنیا به نظر برسند؛ بقیه‌ی UI مخصوص همین صفحه است.
##
## چهار تب: کاراکترها · سلاح‌ها · اسکین کاراکتر · اسکین سلاح
##
## چیدمان (V4/V5): چپ گرید کارت‌ها، راست «ویترین» — بالا نام و چیپ‌ها، وسط
## صحنه‌ی بزرگِ آیتم (psych_select_stage.gd)، پایین مشخصات + بلوکِ اطلاعات
## (ارتقا / تسلط / راهِ باز شدن) + تنها دکمه‌ی اصلی، زیرِ شستِ راست.
##
## ارتقا (تب کاراکترها): GET /upgrades وضعیت همه‌ی کاراکترها را می‌دهد و
## POST /upgrade_character با سکه یک سطح بالا می‌برد. سطح سمت سرور روی تراز
## داخل بازی اعمال می‌شود (balance.go → CharacterStatsAtLevel).
##
## اسکین‌ها (GET /skins, POST /skins/equip) فقط ظاهرند و فقط از بتل‌پس به دست
## می‌آیند — هیچ‌وقت در فروشگاه نیستند. اسکینی که بازیکن ندارد قفل است و آیتم
## با ظاهر پیش‌فرض خودش دیده می‌شود. هر تب اسکین یک کارت «پیش‌فرض» هم برای
## برگشت به ظاهر اصلی دارد.

const MAIN_MENU_SCENE := "res://secense/main_menu.tscn"
const SHOP_SCENE := "res://secense/shop.tscn"
const SELECT_CARD_SCENE := preload("res://secense/select_card.tscn")
const STAGE_FX := preload("res://scripts/psych_select_stage.gd")
const GRID_STATES := preload("res://scripts/psych_select_states.gd")

var CATALOG_URL := Global.SERVER_BASE + "/get_shop"
var EQUIP_URL := Global.SERVER_BASE + "/equip_item"

const MISSIONS_SCENE := "res://secense/missions_screen.tscn"

## آرت نمایشی آیتم‌ها — اسکین‌ها فقط در weapons/ و characters/ آرت دارند
const IMAGE_FOLDERS := ["res://assets/items/", "res://assets/weapons/", "res://assets/characters/"]

const CATEGORY_CHARACTER := "character"
const CATEGORY_WEAPON := "weapon"
const CATEGORY_CHAR_SKIN := "char_skin"
const CATEGORY_WEAPON_SKIN := "weapon_skin"

## دسته‌ی تب اسکین → دسته‌ی آیتم پایه‌ای که اسکین رویش می‌نشیند
const SKIN_BASE_CATEGORY := {
	CATEGORY_CHAR_SKIN: CATEGORY_CHARACTER,
	CATEGORY_WEAPON_SKIN: CATEGORY_WEAPON,
}

# ترتیب تب‌های فروشگاه در shop.gd: ۰=ویژه، ۱=کاراکتر، ۲=سلاح، ۳=سکه/جم
const SHOP_TAB_CHARACTERS := 1
const SHOP_TAB_WEAPONS := 2

# تم بازی: سیاه / قرمز / طلایی
const GOLD := Color("ffc93c")
const GOLD_DIM := Color("7d5f16")
const RED := Color("c0182b")
const RED_DEEP := Color("3d060d")
const FONT_NUM := preload("res://fonts/Lalezar-Regular.ttf")
const COIN_ICON := preload("res://assets/ui/coin_icon.png")
const GEM_ICON := preload("res://assets/ui/gem_icon.png")
const KILLS_ICON := preload("res://assets/ui/profile_menu/icon_kills.svg")
const EMPTY_SKINS_ART := "res://assets/ui/psych/chest_closed.png"

const RARITY_LABELS := {
	"rare": "کمیاب",
	"epic": "حماسی",
	"legend": "افسانه‌ای",
	"legendary": "افسانه‌ای",
	"common": "معمولی",
}

const RARITY_COLORS := {
	"rare": Color("4dd2ff"),
	"epic": Color("e066ff"),
	"legend": Color("ff9f2e"),
	"legendary": Color("ff9f2e"),
	"common": Color("9aa0a6"),
}

## ویژگی‌هایی که برای کاراکتر نشان داده می‌شود (کلید سرور → عنوان فارسی)
const CHARACTER_STATS := [
	{"key": "move_speed", "title": "سرعت حرکت"},
	{"key": "aim_accuracy", "title": "دقت شلیک"},
	{"key": "hand_speed", "title": "سرعت دست"},
	{"key": "throw_range", "title": "برد پرتاب"},
	{"key": "health", "title": "جان"},
	{"key": "health_regen", "title": "بازیابی جان"},
]

## C11: همه‌ی نوارها روی یک خط‌کش، تا مقایسه‌ی دو آیتم واقعاً معنا داشته باشد
## (قبلاً سقفِ هر آیتم max_level × 10 بود و نوارِ AK از AWM پرتر دیده می‌شد)
const STAT_SCALE := 100
const COL_BETTER := Color("4cdb6b")
const COL_WORSE := Color("ff5252")
const LOADOUT_STATS := preload("res://scripts/psych_menu_loadout_stats.gd")

## ویژگی‌های سلاح
const WEAPON_STATS := [
	{"key": "power", "title": "قدرت"},
	{"key": "accuracy", "title": "دقت"},
	{"key": "range", "title": "برد"},
	{"key": "fire_rate", "title": "سرعت شلیک"},
	{"key": "control", "title": "کنترل"},
]

## گرید: اندازه‌ی کارت با عرض پنل حساب می‌شود (نسبت ثابت ۱۵۰×۲۰۶)
const CARD_MIN_W := 140.0
const CARD_RATIO := 206.0 / 150.0
const GRID_SEP := 14

@onready var tab_characters: Button = $HeaderTabs/Tabs/CharactersButton
@onready var tab_weapons: Button = $HeaderTabs/Tabs/WeaponsButton
@onready var tab_char_skins: Button = $HeaderTabs/Tabs/CharSkinsButton
@onready var tab_weapon_skins: Button = $HeaderTabs/Tabs/WeaponSkinsButton

@onready var content: Control = $Content
@onready var header_tabs: Control = $HeaderTabs
@onready var cards_panel: Panel = $Content/CardsPanel
@onready var cards_scroll: ScrollContainer = $Content/CardsPanel/CardsScroll
@onready var cards_grid: GridContainer = $Content/CardsPanel/CardsScroll/CardsGrid
@onready var empty_label: Label = $Content/CardsPanel/EmptyLabel

@onready var showcase: Panel = $Content/Showcase
@onready var head_row: HBoxContainer = $Content/Showcase/Layout/Col/HeadRow
@onready var name_label: Label = $Content/Showcase/Layout/Col/HeadRow/NameLabel
@onready var rarity_chip: PanelContainer = $Content/Showcase/Layout/Col/HeadRow/RarityChip
@onready var rarity_label: Label = $Content/Showcase/Layout/Col/HeadRow/RarityChip/RarityLabel
@onready var stage: Control = $Content/Showcase/Layout/Col/Stage
@onready var preview_image: TextureRect = $Content/Showcase/Layout/Col/Stage/PreviewImage
@onready var stats_box: VBoxContainer = $Content/Showcase/Layout/Col/Bottom/StatsBox
@onready var action_col: VBoxContainer = $Content/Showcase/Layout/Col/Bottom/ActionCol
@onready var action_button: Button = $Content/Showcase/Layout/Col/Bottom/ActionCol/ActionButton
@onready var home_button: TextureButton = $HomeButton

var catalog_http: HTTPRequest
var equip_http: HTTPRequest
var skins_http: HTTPRequest
var skin_equip_http: HTTPRequest
var upgrades_http: HTTPRequest
var upgrade_http: HTTPRequest

## آیتم‌ها به تفکیک دسته (چهار تب)
var items_by_category: Dictionary = {
	CATEGORY_CHARACTER: [], CATEGORY_WEAPON: [], CATEGORY_CHAR_SKIN: [], CATEGORY_WEAPON_SKIN: [],
}
## آیتمی که همین الان توی پنل جزییات نشان داده می‌شود (به تفکیک دسته)
var preview_by_category: Dictionary = {
	CATEGORY_CHARACTER: {}, CATEGORY_WEAPON: {}, CATEGORY_CHAR_SKIN: {}, CATEGORY_WEAPON_SKIN: {},
}

## کاتالوگ اسکین‌ها از /skins (خام)
var _skin_catalog: Array = []
var _skins_loaded := false
var _skins_failed := false
var _skin_equip_in_flight := false
## وضعیت ارتقای هر کاراکتر از /upgrades: item_id → {level, max_level, cost, current, next}
var _upgrades: Dictionary = {}
var _upgrades_loaded := false
var _upgrade_in_flight := false
## E17: سطحی که همین الان گرفته شد — دانه‌ی تازه‌ی نوار سطح یک بار «می‌پرد»
var _pop_pip_level := 0

var current_category: String = CATEGORY_CHARACTER
var catalog_loaded: bool = false
var _catalog_failed := false
var _equip_in_flight: bool = false
# آیتمی که همین الان درخواست تجهیزش رفته. C12: کارت‌ها همان لحظه «مجهز» نشانش
# می‌دهند (Optimistic UI) و اگر سرور رد کرد برمی‌گردند.
var _pending_equip_id: String = ""
var _pending_equip_category: String = ""
var _stat_rows: Array[Control] = []

var _stage_fx: Control
var _grid_states: Control
var _own_chip: PanelContainer
var _own_label: Label
var _info_panel: PanelContainer
var _info_col: VBoxContainer
var _cta_tween: Tween
var _card_size := Vector2(150, 206)


func _ready() -> void:
	catalog_http = HTTPRequest.new()
	add_child(catalog_http)
	catalog_http.request_completed.connect(_on_catalog_received)

	equip_http = HTTPRequest.new()
	add_child(equip_http)
	equip_http.request_completed.connect(_on_equip_response)

	skins_http = _make_http(_on_skins_received)
	skin_equip_http = _make_http(_on_skin_equip_response)
	upgrades_http = _make_http(_on_upgrades_received)
	upgrade_http = _make_http(_on_upgrade_response)

	_build_showcase_extras()
	_style_ui()
	_setup_tab_buttons()

	if home_button and not home_button.pressed.is_connected(_on_home_pressed):
		home_button.pressed.connect(_on_home_pressed)
	if action_button and not action_button.pressed.is_connected(_on_action_pressed):
		action_button.pressed.connect(_on_action_pressed)

	# انبار که عوض شد (لود اولیه‌ی بازیکن، خرید، تجهیز) کارت‌ها را رنگ‌آمیزی کن
	if not Global.inventory_updated.is_connected(_refresh_states):
		Global.inventory_updated.connect(_refresh_states)

	# دکمه‌ی Back اندروید → منوی اصلی
	get_tree().set_quit_on_go_back(false)

	# CLAUDE.md: هیچ دکمه‌ای زیر ناچ/لبه‌ی خمیده نیفتد
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	cards_scroll.resized.connect(_relayout_grid)
	# C14: اولین کارت (مجهز) بالا-راست، کنار ویترین و سرِ خطِ خواندنِ فارسی
	cards_grid.layout_direction = Control.LAYOUT_DIRECTION_RTL
	if empty_label:
		empty_label.visible = false

	_switch_category(CATEGORY_CHARACTER, false)
	_fetch_catalog()
	_fetch_skins()
	_fetch_upgrades()


var _leaving := false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Back اول پنجره‌ی تأییدِ باز (بچه‌ی root) را می‌بندد، نه این‌که زیرش
		# صحنه عوض شود و پنجره روی منوی اصلی بماند
		for node in get_tree().get_nodes_in_group("modal"):
			if node is MenuUI.ModalSheet:
				(node as MenuUI.ModalSheet).dismiss()
				return
		_on_home_pressed()
	elif what == NOTIFICATION_EXIT_TREE and is_inside_tree():
		get_tree().set_quit_on_go_back(true)


func _make_http(callback: Callable) -> HTTPRequest:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(callback)
	return http


func _is_skin_category(category: String) -> bool:
	return SKIN_BASE_CATEGORY.has(category)


# =============================================================================
# Safe area و چیدمان واکنش‌گرا
# =============================================================================

## فاصله‌ی ناچ/لبه‌ی خمیده از چهار طرف، به واحدِ ویوپورت. روی دسکتاپ صفر.
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
	content.offset_left = 16.0 + ins.x
	content.offset_right = -(16.0 + ins.z)
	content.offset_bottom = -(14.0 + ins.w)
	header_tabs.offset_left = ins.x
	header_tabs.offset_right = -ins.z
	if home_button:
		home_button.offset_right = -(16.0 + ins.z)
		home_button.offset_left = home_button.offset_right - 62.0


## تعداد ستون و اندازه‌ی کارت از عرضِ واقعی پنل — روی 20:9 کارت درشت‌تر،
## روی 4:3 و 16:9 همان ۳ ستون؛ هیچ اندازه‌ی پیکسلیِ ثابتی برای گرید نیست.
func _relayout_grid() -> void:
	if not cards_scroll or not cards_grid:
		return
	var avail := cards_scroll.size.x - 8.0
	if avail < 50.0:
		return
	var cols := clampi(int(floor((avail + GRID_SEP) / (CARD_MIN_W + GRID_SEP))), 2, 6)
	var w := floorf((avail - GRID_SEP * (cols - 1)) / float(cols))
	_card_size = Vector2(w, roundf(w * CARD_RATIO))
	cards_grid.columns = cols
	for card in cards_grid.get_children():
		(card as Control).custom_minimum_size = _card_size
	if _grid_states and _grid_states.visible and _list_state() == "loading":
		_grid_states.show_loading(cols, _card_size, GRID_SEP)


# =============================================================================
# استایل‌دهی (سیاه / قرمز / طلایی)
# =============================================================================

func _style_ui() -> void:
	_apply_panel_style(cards_panel, Color(0.04, 0.02, 0.02, 0.72), GOLD_DIM, 20)
	_apply_panel_style(showcase, Color(0.05, 0.02, 0.03, 0.80), GOLD_DIM, 20)

	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(0, 0, 0, 0.55)
	chip_style.set_border_width_all(1)
	chip_style.border_color = GOLD_DIM
	chip_style.set_corner_radius_all(10)
	chip_style.content_margin_left = 12.0
	chip_style.content_margin_right = 12.0
	chip_style.content_margin_top = 1.0
	chip_style.content_margin_bottom = 1.0
	if rarity_chip:
		rarity_chip.add_theme_stylebox_override("panel", chip_style)

	if action_button:
		action_button.focus_mode = Control.FOCUS_NONE
	_style_scrollbar()


func _apply_panel_style(panel: Panel, bg: Color, border: Color, radius: int) -> void:
	if not panel:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_border_width_all(2)
	style.border_color = border
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)


## اسکرول‌بار باریک و محو — روی موبایل با انگشت اسکرول می‌شود، نه با گرفتن میله
func _style_scrollbar() -> void:
	if not cards_scroll:
		return
	cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var bar := cards_scroll.get_v_scroll_bar()
	if not bar:
		return
	bar.custom_minimum_size.x = 5.0

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.6)
	grabber.set_corner_radius_all(3)

	var empty := StyleBoxEmpty.new()
	bar.add_theme_stylebox_override("grabber", grabber)
	bar.add_theme_stylebox_override("grabber_highlight", grabber)
	bar.add_theme_stylebox_override("grabber_pressed", grabber)
	bar.add_theme_stylebox_override("scroll", empty)
	bar.add_theme_stylebox_override("scroll_focus", empty)


## ساخت بخش‌های کدیِ ویترین: صحنه‌ی آیتم، چیپ مالکیت، بلوک اطلاعات، حالت‌های گرید
func _build_showcase_extras() -> void:
	_stage_fx = STAGE_FX.new()
	_stage_fx.attach(stage, preview_image)

	# V1/V2: چیپ مالکیت کنار کمیابی — «مجهز» / «مال تو» / «قفل»
	_own_chip = PanelContainer.new()
	_own_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_own_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_own_label = Label.new()
	_own_label.add_theme_font_override("font", FONT_NUM)
	_own_label.add_theme_font_size_override("font_size", 16)
	_own_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_own_chip.add_child(_own_label)
	head_row.add_child(_own_chip)
	head_row.move_child(_own_chip, 1)

	_info_panel = PanelContainer.new()
	_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := MenuUI.box(Color(0, 0, 0, 0.42), Color(1, 1, 1, 0.08), 1, 12)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	_info_panel.add_theme_stylebox_override("panel", s)
	_info_col = VBoxContainer.new()
	_info_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_col.add_theme_constant_override("separation", 5)
	_info_panel.add_child(_info_col)
	action_col.add_child(_info_panel)
	action_col.move_child(_info_panel, 0)

	_grid_states = GRID_STATES.new()
	cards_panel.add_child(_grid_states)
	_grid_states.action_pressed.connect(_on_states_action)


# =============================================================================
# تب‌ها
# =============================================================================

func _setup_tab_buttons() -> void:
	var tabs_box: HBoxContainer = null
	if tab_characters:
		tabs_box = tab_characters.get_parent() as HBoxContainer
	if tabs_box:
		# فارسی از راست خوانده می‌شود: «کاراکترها» سمت راست، کنار دکمه‌ی خانه
		tabs_box.layout_direction = Control.LAYOUT_DIRECTION_RTL
		# C2 هیک: دو تب اصلی بزرگ، دو تب اسکین کوچک‌تر و جدا — گروه‌بندی
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(14, 0)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var line := ColorRect.new()
		line.color = Color(GOLD_DIM, 0.8)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.set_anchors_preset(Control.PRESET_CENTER)
		line.offset_left = -1.0
		line.offset_right = 1.0
		line.offset_top = -14.0
		line.offset_bottom = 14.0
		gap.add_child(line)
		tabs_box.add_child(gap)
		tabs_box.move_child(gap, tab_char_skins.get_index())
	for btn in [tab_char_skins, tab_weapon_skins]:
		if btn:
			btn.custom_minimum_size = Vector2(150, 44)
			btn.add_theme_font_size_override("font_size", 18)

	for btn in _tab_buttons():
		if not btn:
			continue
		btn.focus_mode = Control.FOCUS_NONE
		for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.06, 0.02, 0.03, 0.85)
			style.set_border_width_all(2)
			style.border_color = GOLD_DIM
			style.set_corner_radius_all(13)
			btn.add_theme_stylebox_override(state_name, style)
		btn.resized.connect(func() -> void: btn.pivot_offset = btn.size * 0.5)

	if tab_characters:
		tab_characters.pressed.connect(func() -> void: _switch_category(CATEGORY_CHARACTER, true))
	if tab_weapons:
		tab_weapons.pressed.connect(func() -> void: _switch_category(CATEGORY_WEAPON, true))
	if tab_char_skins:
		tab_char_skins.pressed.connect(func() -> void: _switch_category(CATEGORY_CHAR_SKIN, true))
	if tab_weapon_skins:
		tab_weapon_skins.pressed.connect(func() -> void: _switch_category(CATEGORY_WEAPON_SKIN, true))


func _tab_buttons() -> Array:
	return [tab_characters, tab_weapons, tab_char_skins, tab_weapon_skins]


func _switch_category(category: String, animate: bool) -> void:
	current_category = category
	_paint_tab(tab_characters, category == CATEGORY_CHARACTER, animate)
	_paint_tab(tab_weapons, category == CATEGORY_WEAPON, animate)
	_paint_tab(tab_char_skins, category == CATEGORY_CHAR_SKIN, animate)
	_paint_tab(tab_weapon_skins, category == CATEGORY_WEAPON_SKIN, animate)

	if animate:
		LocalSettings.vibrate(15)
		UIFx.UI_SFX.tap(self)
		Tutorial.notify("category_" + category)

	_render_grid()
	_show_preview(_pick_preview_item(category))

	if animate:
		_play_grid_intro()
		cards_scroll.scroll_vertical = 0


## تب فعال: قاب و متن طلایی + یک پله بزرگ‌تر. تب خاموش: خاکستری و کوچک‌تر.
func _paint_tab(btn: Button, active: bool, animate: bool) -> void:
	if not btn:
		return

	for state_name in ["normal", "hover", "pressed", "focus"]:
		var style: StyleBoxFlat = btn.get_theme_stylebox(state_name) as StyleBoxFlat
		if style:
			style.bg_color = Color(0.28, 0.02, 0.05, 0.92) if active else Color(0.06, 0.02, 0.03, 0.85)
			if state_name == "pressed" and not active:
				style.bg_color = Color(0.16, 0.03, 0.05, 0.92)
			style.border_color = GOLD if active else GOLD_DIM
	btn.add_theme_color_override("font_color", GOLD if active else Color("9c8f7a"))
	btn.add_theme_color_override("font_pressed_color", GOLD)

	btn.pivot_offset = btn.size * 0.5
	var target := Vector2(1.06, 1.06) if active else Vector2.ONE
	if not animate:
		btn.scale = target
		return

	var tween := btn.create_tween()
	if active:
		tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.06) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "scale", target, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# =============================================================================
# گرفتن کاتالوگ
# =============================================================================

func _fetch_catalog() -> void:
	var err := catalog_http.request(CATALOG_URL, Global.auth_headers())
	if err != OK:
		_catalog_failed = true
		_render_grid()


func _on_catalog_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var raw: Array = []
	var ok := false
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			if typeof(json.data) == TYPE_ARRAY:
				raw = json.data
				ok = true
			elif typeof(json.data) == TYPE_DICTIONARY and typeof(json.data.get("items")) == TYPE_ARRAY:
				raw = json.data["items"]
				ok = true

	_catalog_failed = not ok
	_build_item_lists(raw)
	_build_skin_lists()
	catalog_loaded = ok
	# پیش‌نمایشِ قبلی ممکن است مال لیستِ قدیمی باشد (مثلاً بعد از «تلاش دوباره»)
	for category in [CATEGORY_CHARACTER, CATEGORY_WEAPON]:
		var previewed: Dictionary = preview_by_category.get(category, {})
		if not previewed.is_empty():
			preview_by_category[category] = _find_item(str(previewed.get("item_id", "")), category)
	if _is_skin_category(current_category):
		_refresh_states()
		return
	_render_grid()
	_show_preview(_pick_preview_item(current_category))
	_play_grid_intro()


func _build_item_lists(raw_items: Array) -> void:
	items_by_category[CATEGORY_CHARACTER] = []
	items_by_category[CATEGORY_WEAPON] = []
	var seen: Dictionary = {}

	for entry in raw_items:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = entry
		var category := _category_of(item)
		if category.is_empty():
			continue
		var item_id := str(item.get("item_id", item.get("id", ""))).strip_edges()
		if item_id.is_empty():
			continue

		# یک آیتم می‌تواند هم در کاتالوگ باشد هم در ویترین پیشنهاد ویژه — یک بار بس است
		var key := category + ":" + item_id
		if seen.has(key):
			continue
		seen[key] = true

		items_by_category[category].append(item)

	_ensure_default_item(CATEGORY_CHARACTER, Global.DEFAULT_CHARACTER, "سرباز پایه")
	_ensure_default_item(CATEGORY_WEAPON, "ak47", "AK-47")

	# C14: مجهز اول، بعد مال خود بازیکن، بعد قفل‌ها از نزدیک‌ترین به باز شدن
	for category in [CATEGORY_CHARACTER, CATEGORY_WEAPON]:
		var list: Array = items_by_category[category]
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var wa := _sort_weight(a, category)
			var wb := _sort_weight(b, category)
			if wa != wb:
				return wa < wb
			return _price_weight(a) < _price_weight(b)
		)


## آیتم پیش‌فرض ممکن است اصلاً توی فروشگاه نباشد (فروشی نیست)، ولی باید
## توی لیست انتخاب دیده شود چون بازیکن از روز اول داردش.
func _ensure_default_item(category: String, item_id: String, fallback_name: String) -> void:
	for item in items_by_category[category]:
		if str(item.get("item_id", "")).strip_edges() == item_id:
			return
	items_by_category[category].push_front({
		"item_id": item_id,
		"name": fallback_name,
		"rarity": "common",
		"category": category,
		"stats": {},
	})


func _sort_weight(item: Dictionary, category: String) -> int:
	var item_id := str(item.get("item_id", "")).strip_edges()
	if Global.is_equipped(item_id, category):
		return 0
	if Global.owns_item(item_id, category):
		return 1
	return 2


## قلب‌ها بعد از سکه‌ها، هر کدام از ارزان به گران
func _price_weight(item: Dictionary) -> int:
	var price := _price_of(item)
	return price + (10000000 if _is_gem_price(item) else 0)


func _price_of(item: Dictionary) -> int:
	return int(item.get("final_price", item.get("original_price", item.get("price", 0))))


func _is_gem_price(item: Dictionary) -> bool:
	return str(item.get("cost_type", "coins")).to_lower() in ["gems", "gem", "heart"]


## دسته‌ی آیتم را از category یا section تشخیص می‌دهد؛ خالی یعنی به این صفحه ربطی ندارد
func _category_of(item: Dictionary) -> String:
	var category := str(item.get("category", "")).to_lower().strip_edges()
	if category == CATEGORY_CHARACTER or category == CATEGORY_WEAPON:
		return category

	match str(item.get("section", "")).strip_edges():
		"characters":
			return CATEGORY_CHARACTER
		"weapons":
			return CATEGORY_WEAPON
	return ""


## «تلاش دوباره» از حالت خطا
func _retry_fetch() -> void:
	if _is_skin_category(current_category):
		_skins_failed = false
		_fetch_skins()
	else:
		_catalog_failed = false
		catalog_loaded = false
		_fetch_catalog()
		if not _upgrades_loaded:
			_fetch_upgrades()
	_render_grid()
	_show_preview(_pick_preview_item(current_category))


func _on_states_action() -> void:
	match _list_state():
		"error":
			_retry_fetch()
		"empty":
			if _is_skin_category(current_category):
				_go_to_battle_pass()


# =============================================================================
# گرید کارت‌ها
# =============================================================================

## loading | error | empty | ready
func _list_state() -> String:
	var skin := _is_skin_category(current_category)
	if skin:
		if _skins_failed:
			return "error"
		if not _skins_loaded:
			return "loading"
	else:
		if _catalog_failed:
			return "error"
		if not catalog_loaded:
			return "loading"
	return "empty" if items_by_category.get(current_category, []).is_empty() else "ready"


## فقط برای ابزار اسکرین‌شات/تست: حالت لیست را دستی عوض می‌کند
func _set_load_state(state: String) -> void:
	catalog_loaded = state == "ready"
	_catalog_failed = state == "error"
	_skins_loaded = state == "ready"
	_skins_failed = state == "error"
	_render_grid()


func _render_grid() -> void:
	if not cards_grid:
		return

	for child in cards_grid.get_children():
		cards_grid.remove_child(child)
		child.queue_free()

	var state := _list_state()
	match state:
		"loading":
			_grid_states.show_loading(cards_grid.columns, _card_size, GRID_SEP)
			return
		"error":
			_grid_states.show_message(null, "ارتباط با سرور برقرار نشد",
				"اینترنتت را چک کن و دوباره امتحان کن.", "تلاش دوباره")
			return
		"empty":
			if _is_skin_category(current_category):
				var art: Texture2D = load(EMPTY_SKINS_ART) if ResourceLoader.exists(EMPTY_SKINS_ART) else null
				_grid_states.show_message(art, "اسکین‌ها از بتل‌پس می‌آیند",
					"با بالا رفتن در پله‌های بتل‌پس، ظاهرهای تازه این‌جا باز می‌شوند.", "دیدن بتل‌پس")
			else:
				_grid_states.show_message(null, "فعلاً آیتمی نیست", "کمی بعد دوباره سر بزن.", "")
			return
	_grid_states.hide_all()

	var list: Array = items_by_category.get(current_category, [])
	var shown_id := str(preview_by_category.get(current_category, {}).get("item_id", ""))
	for item in list:
		var card: Control = SELECT_CARD_SCENE.instantiate()
		card.custom_minimum_size = _card_size
		card.layout_direction = Control.LAYOUT_DIRECTION_LTR
		cards_grid.add_child(card)
		_setup_card(card, item)
		card.set_previewing(str(item.get("item_id", "")).strip_edges() == shown_id)
		card.card_selected.connect(_on_card_selected)
		card.locked_tapped.connect(_on_locked_card_tapped)


func _setup_card(card: Control, item: Dictionary) -> void:
	var item_id := str(item.get("item_id", "")).strip_edges()
	card.set_meta("item_id", item_id)
	card.setup(item, _state_of(item_id), _texture_for(item, current_category), _unlock_text(item), _owned_chip_text(item_id))


## E8: کارتِ کاراکترِ خودت سطحش را نشان می‌دهد («سطح ۲/۵»)
func _owned_chip_text(item_id: String) -> String:
	if current_category != CATEGORY_CHARACTER:
		return ""
	var info: Dictionary = _upgrades.get(item_id, {})
	if info.is_empty():
		return ""
	return "سطح %s/%s" % [MissionArt.fa_number(int(info.get("level", 1))), MissionArt.fa_number(int(info.get("max_level", 1)))]


func _state_of(item_id: String) -> String:
	if _is_skin_category(current_category):
		return _skin_state(_find_item(item_id, current_category))
	# C12 Optimistic UI: درخواستِ تجهیز در راه است — همان لحظه نشانش بده
	if _pending_equip_id != "" and _pending_equip_category == current_category:
		if item_id == _pending_equip_id:
			return "equipped"
		return "owned" if Global.owns_item(item_id, current_category) else "locked"
	if Global.is_equipped(item_id, current_category):
		return "equipped"
	if Global.owns_item(item_id, current_category):
		return "owned"
	return "locked"


## بدون ساختن دوباره‌ی کارت‌ها، فقط حالتشان را تازه می‌کند
func _refresh_states() -> void:
	if not cards_grid:
		return
	if _list_state() != "ready" or cards_grid.get_child_count() == 0:
		_render_grid()
	for card in cards_grid.get_children():
		var item_id: String = str(card.get_meta("item_id", ""))
		var item: Dictionary = _find_item(item_id, current_category)
		if item.is_empty():
			continue
		card.setup(item, _state_of(item_id), _texture_for(item, current_category), _unlock_text(item), _owned_chip_text(item_id))

	_refresh_showcase_state()


## E12 کنجکاوی: شرطِ باز شدنِ آیتمِ قفل، کوتاه و دقیق («۶٬۰۰۰ سکه»، «بتل‌پس · پله‌ی ۱۲»)
func _unlock_text(item: Dictionary) -> String:
	if _is_skin_category(current_category):
		return _skin_source_text(item)
	var price := _price_of(item)
	if price <= 0:
		return ""
	return "%s %s" % [MissionArt.fa_grouped(price), "قلب" if _is_gem_price(item) else "سکه"]


func _find_item(item_id: String, category: String) -> Dictionary:
	for item in items_by_category.get(category, []):
		if str(item.get("item_id", "")).strip_edges() == item_id:
			return item
	return {}


## آیتمی که موقع باز شدن تب توی پنل جزییات بنشیند: ترجیحاً همانی که تجهیز است
func _pick_preview_item(category: String) -> Dictionary:
	var previewed: Dictionary = preview_by_category.get(category, {})
	if not previewed.is_empty():
		return previewed

	var list: Array = items_by_category.get(category, [])
	for item in list:
		if _is_skin_category(category):
			if _skin_state(item) == "equipped" and not bool(item.get("is_default_look", false)):
				return item
		elif Global.is_equipped(str(item.get("item_id", "")).strip_edges(), category):
			return item
	return list[0] if not list.is_empty() else {}


## ورود پلکانی کارت‌ها. فقط modulate و scale انیمیت می‌شوند — position دست
## GridContainer است و اگر اینجا هم بنویسیمش، کارت‌ها روی هم می‌افتند.
func _play_grid_intro() -> void:
	if not cards_grid:
		return
	var children := cards_grid.get_children()
	for i in range(children.size()):
		var card: Control = children[i] as Control
		if not card:
			continue
		card.modulate.a = 0.0
		card.scale = Vector2(0.9, 0.9)
		var delay: float = mini(i, 8) * 0.03
		var tween := card.create_tween().set_parallel(true)
		tween.tween_property(card, "modulate:a", 1.0, 0.18).set_delay(delay)
		tween.tween_property(card, "scale", Vector2.ONE, 0.24) \
			.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _mark_previewing() -> void:
	var shown_id := str(preview_by_category.get(current_category, {}).get("item_id", ""))
	for card in cards_grid.get_children():
		if card.has_method("set_previewing"):
			card.set_previewing(str(card.get_meta("item_id", "")) == shown_id)


# =============================================================================
# پنل جزییات (ویترین)
# =============================================================================

func _show_preview(item: Dictionary) -> void:
	# در لودینگ/خطا ویترین هم خالی است، نه آیتمِ پیش‌فرضی که گرید نشانش نمی‌دهد
	if _list_state() in ["loading", "error"]:
		item = {}
	preview_by_category[current_category] = item

	if item.is_empty():
		if name_label:
			name_label.text = "—" if _list_state() != "loading" else ""
		rarity_chip.visible = false
		_own_chip.visible = false
		if _list_state() == "loading":
			_stage_fx.set_loading(true)
		else:
			_stage_fx.clear_item()
		_clear_stat_rows()
		_refresh_showcase_state()
		return

	rarity_chip.visible = true
	if name_label:
		name_label.text = str(item.get("name", "بدون نام"))

	var rarity := _rarity_of(item)
	var accent: Color = RARITY_COLORS.get(rarity, RARITY_COLORS["common"])
	if rarity_label:
		rarity_label.text = RARITY_LABELS.get(rarity, RARITY_LABELS["common"])
		rarity_label.add_theme_color_override("font_color", accent)
	var chip_style: StyleBoxFlat = rarity_chip.get_theme_stylebox("panel") as StyleBoxFlat
	if chip_style:
		chip_style.border_color = accent

	var item_id := str(item.get("item_id", "")).strip_edges()
	var locked := _state_of(item_id) == "locked"
	var is_weapon := current_category in [CATEGORY_WEAPON, CATEGORY_WEAPON_SKIN]
	_stage_fx.show_item(_texture_for(item, current_category), accent, locked, is_weapon)

	if _is_skin_category(current_category):
		_build_skin_info_rows(item)
	else:
		_build_stat_rows(item)
	_refresh_showcase_state()
	_mark_previewing()


func _rarity_of(item: Dictionary) -> String:
	return str(item.get("rarity", item.get("rarety", "common"))).to_lower().strip_edges()


## همه‌ی چیزهای ویترین که به «حالت» (مجهز/مال تو/قفل) بستگی دارند
func _refresh_showcase_state() -> void:
	var item: Dictionary = preview_by_category.get(current_category, {})
	_paint_own_chip(item)
	_refresh_mastery_chip(item)
	_refresh_info_block(item)
	_update_action_button()


func _paint_own_chip(item: Dictionary) -> void:
	if item.is_empty():
		_own_chip.visible = false
		return
	_own_chip.visible = true
	var state := _state_of(str(item.get("item_id", "")).strip_edges())
	var bg := Color(0, 0, 0, 0.55)
	var border := Color("6e6e74")
	var fg := Color("b9b9c0")
	var text := "قفل"
	if state == "equipped":
		text = "مجهز"
		bg = GOLD
		border = GOLD
		fg = Color("101010")
	elif state == "owned":
		text = "مال تو"
		bg = Color(0.12, 0.02, 0.03, 0.85)
		border = GOLD_DIM
		fg = GOLD
	var st := MenuUI.box(bg, border, 1, 10)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 1
	st.content_margin_bottom = 1
	_own_chip.add_theme_stylebox_override("panel", st)
	_own_label.text = text
	_own_label.add_theme_color_override("font_color", fg)


## E8 مالکیت: درجه‌ی تسلط + کیل‌های همین اسلحه/کاراکتر روی سکوی صحنه
func _refresh_mastery_chip(item: Dictionary) -> void:
	if item.is_empty() or _is_skin_category(current_category):
		_stage_fx.set_chip("")
		return
	var item_id := str(item.get("item_id", "")).strip_edges()
	if not Global.owns_item(item_id, current_category):
		_stage_fx.set_chip("")
		return
	var m := LOADOUT_STATS.mastery(current_category, item_id)
	if int(m["kills"]) > 0:
		_stage_fx.set_chip("%s · %s کیل" % [m["name"], MissionArt.fa_grouped(int(m["kills"]))])
	elif int(m["matches"]) > 0:
		_stage_fx.set_chip("%s مسابقه با همین" % MissionArt.fa_grouped(int(m["matches"])), false)
	elif _state_of(item_id) == "equipped":
		var noun := "اسلحه" if current_category == CATEGORY_WEAPON else "کاراکتر"
		_stage_fx.set_chip("اولین کیلت با این %s این‌جا ثبت می‌شود" % noun, false)
	else:
		_stage_fx.set_chip("")


func _clear_stat_rows() -> void:
	for row in _stat_rows:
		if is_instance_valid(row):
			row.queue_free()
	_stat_rows.clear()


func _build_stat_rows(item: Dictionary) -> void:
	_clear_stat_rows()
	if not stats_box:
		return

	var stats := _stats_of(item)
	var definitions: Array = CHARACTER_STATS if current_category == CATEGORY_CHARACTER else WEAPON_STATS
	var has_any := false
	for definition in definitions:
		if stats.has(definition["key"]) or item.has(definition["key"]):
			has_any = true
			break
	if not has_any:
		var note := MenuUI.label("مشخصاتِ این آیتم هنوز ثبت نشده", 15, MenuUI.MUTED)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats_box.add_child(note)
		_stat_rows.append(note)
		return

	# C11: آیتمِ تجهیزشده‌ی همین دسته مرجعِ مقایسه است (خطِ طلایی + اختلاف)
	var ref_stats := {}
	var ref_name := ""
	var shown_id := str(item.get("item_id", "")).strip_edges()
	for other in items_by_category.get(current_category, []):
		var other_id := str(other.get("item_id", "")).strip_edges()
		if other_id != shown_id and Global.is_equipped(other_id, current_category):
			ref_stats = _stats_of(other)
			ref_name = str(other.get("name", other_id))
			break

	# راهنمای کوچکِ خطِ طلایی: «مقایسه با مجهزِ فعلی»
	if not ref_stats.is_empty():
		var legend := HBoxContainer.new()
		legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
		legend.add_theme_constant_override("separation", 6)
		var t := MenuUI.label("مقایسه با مجهزِ فعلی: %s" % ref_name, 13, MenuUI.MUTED)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		legend.add_child(t)
		var mark := ColorRect.new()
		mark.color = GOLD
		mark.custom_minimum_size = Vector2(3, 12)
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		legend.add_child(mark)
		stats_box.add_child(legend)
		_stat_rows.append(legend)

	var i := 0
	for definition in definitions:
		var key: String = definition["key"]
		var value := int(stats.get(key, item.get(key, 0)))
		var ref := int(ref_stats.get(key, -1)) if not ref_stats.is_empty() else -1
		_stat_rows.append(_make_stat_row(str(definition["title"]), value, STAT_SCALE, ref, i))
		i += 1


## ویژگی‌ها گاهی Dictionary اند و گاهی رشته‌ی JSON — هر دو را قبول می‌کنیم
func _stats_of(item: Dictionary) -> Dictionary:
	var raw = item.get("stats", {})
	if typeof(raw) == TYPE_DICTIONARY:
		return raw
	if typeof(raw) == TYPE_STRING:
		var json := JSON.new()
		if json.parse(raw) == OK and typeof(json.data) == TYPE_DICTIONARY:
			return json.data
	return {}


func _make_stat_row(title: String, value: int, max_value: int, ref_value: int = -1, index: int = 0) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size.y = 20.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_box.add_child(row)

	# اختلاف با آیتمِ فعلی — سبز بهتر، قرمز ضعیف‌تر، همیشه با علامت (نه فقط رنگ، V2)
	var delta_text := _num_label("", 15, Color.WHITE)
	delta_text.custom_minimum_size.x = 30.0
	delta_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var delta := value - ref_value
	if ref_value >= 0 and delta != 0:
		delta_text.text = ("+%s" % MissionArt.fa_number(delta)) if delta > 0 else ("−%s" % MissionArt.fa_number(-delta))
		delta_text.add_theme_color_override("font_color", COL_BETTER if delta > 0 else COL_WORSE)
	row.add_child(delta_text)

	var value_text := _num_label(MissionArt.fa_number(value), 16, Color("ece4d2"))
	value_text.custom_minimum_size.x = 28.0
	row.add_child(value_text)

	var bar := _StatBar.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.value_ratio = clampf(float(value) / float(max_value), 0.0, 1.0) if max_value > 0 else 0.0
	bar.ref_ratio = clampf(float(ref_value) / float(max_value), 0.0, 1.0) if ref_value >= 0 and max_value > 0 else -1.0
	row.add_child(bar)
	# نوار از صفر تا مقدارش پر می‌شود — پلکانی و کوتاه
	var tween := bar.create_tween()
	tween.tween_property(bar, "progress", 1.0, 0.34).set_delay(index * 0.03) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var title_text := MenuUI.label(title, 15, Color("e8c45a"))
	title_text.custom_minimum_size.x = 86.0
	title_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(title_text)

	return row


func _num_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT_NUM)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## C11: نوارِ مقایسه — بخشِ مشترک روشن، اضافه سبز، کمبود قرمزِ کم‌رنگ،
## و خطِ طلاییِ مقدارِ مجهزِ فعلی. با _draw، بدون چند Panel تودرتو.
class _StatBar extends Control:
	var value_ratio := 0.0
	var ref_ratio := -1.0
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _seg(x0: float, x1: float, color: Color) -> void:
		if x1 - x0 < 0.5:
			return
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		sb.set_corner_radius_all(int(size.y * 0.5))
		draw_style_box(sb, Rect2(x0, 0.0, x1 - x0, size.y))

	func _draw() -> void:
		var w := size.x
		_seg(0.0, w, Color(0, 0, 0, 0.6))
		var v := value_ratio * progress * w
		if ref_ratio < 0.0:
			_seg(0.0, v, Color("e9d9b0"))
			return
		var r := ref_ratio * w
		_seg(0.0, minf(v, r), Color("e9d9b0"))
		if v > r:
			_seg(r - 3.0, v, Color(0.30, 0.86, 0.42, 1.0))
		elif v < r and progress >= 1.0:
			_seg(v, r, Color(1.0, 0.32, 0.32, 0.42))
		draw_rect(Rect2(r - 1.5, -3.0, 3.0, size.y + 6.0), Color("ffc93c"))


# =============================================================================
# بلوکِ اطلاعات (ارتقا / تسلط / راهِ باز شدن)
# =============================================================================

func _clear_info() -> void:
	for c in _info_col.get_children():
		_info_col.remove_child(c)
		c.queue_free()


func _refresh_info_block(item: Dictionary) -> void:
	_clear_info()
	if item.is_empty() or _is_skin_category(current_category):
		_info_panel.visible = false
		return
	_info_panel.visible = true
	var item_id := str(item.get("item_id", "")).strip_edges()
	var state := _state_of(item_id)
	if state == "locked":
		_build_unlock_block(item, item_id)
	elif current_category == CATEGORY_CHARACTER:
		_build_upgrade_block(item_id)
	else:
		_build_mastery_block(item_id)


func _info_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	_info_col.add_child(row)
	return row


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


## E12 + C9: آیتم قفل — قیمت، چقدر داری و چقدر مانده (بدون تایمر یا فشار)
func _build_unlock_block(item: Dictionary, item_id: String) -> void:
	var price := _price_of(item)
	var gem := _is_gem_price(item)
	var title_row := _info_row()
	title_row.add_child(_spacer())
	var t := MenuUI.label("برای باز کردن", 15, MenuUI.MUTED)
	title_row.add_child(t)
	if price <= 0:
		var na := MenuUI.label("فعلاً در فروشگاه نیست", 17, MenuUI.TEXT)
		na.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_info_col.add_child(na)
		return

	var price_row := _info_row()
	price_row.add_child(_spacer())
	price_row.add_child(_num_label(MissionArt.fa_grouped(price), 24, GOLD))
	price_row.add_child(MenuUI.icon(GEM_ICON if gem else COIN_ICON, 24))

	var have := Global.gems if gem else Global.coins
	var bar := MenuUI.progress_bar(GOLD, 8)
	bar.max_value = float(price)
	bar.value = float(mini(have, price))
	_info_col.add_child(bar)
	var unit := "قلب" if gem else "سکه"
	var note: Label
	if have >= price:
		note = MenuUI.label("%s کافی داری — همین الان بازش کن!" % unit, 15, MenuUI.GREEN)
	else:
		note = MenuUI.label("%s %s دیگر لازم داری" % [MissionArt.fa_grouped(price - have), unit], 15, MenuUI.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_info_col.add_child(note)

	# E12: کاراکترِ قفل تا کجا رشد می‌کند
	var info: Dictionary = _upgrades.get(item_id, {})
	if current_category == CATEGORY_CHARACTER and not info.is_empty():
		var grow := MenuUI.label("تا سطح %s ارتقا می‌گیرد" % MissionArt.fa_number(int(info.get("max_level", 1))), 14, MenuUI.DIM)
		grow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_info_col.add_child(grow)


## E8 + C9: درجه‌ی تسلطِ اسلحه و فاصله تا درجه‌ی بعد
func _build_mastery_block(item_id: String) -> void:
	var m := LOADOUT_STATS.mastery(current_category, item_id)
	var row := _info_row()
	row.add_child(_num_label(str(m["name"]), 21, GOLD))
	row.add_child(_spacer())
	row.add_child(MenuUI.label("درجه‌ی تسلط", 15, MenuUI.MUTED))
	row.add_child(MenuUI.icon(KILLS_ICON, 18, GOLD))
	var bar := MenuUI.progress_bar(GOLD, 8)
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = float(m["ratio"])
	_info_col.add_child(bar)
	var text := "به بالاترین درجه رسیدی!"
	if int(m["next_at"]) > 0:
		text = "%s کیل دیگر تا «%s»" % [MissionArt.fa_grouped(int(m["next_at"]) - int(m["kills"])), m["next_name"]]
	var note := MenuUI.label(text, 15, MenuUI.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_info_col.add_child(note)


## C9/E17: نوار سطح (دانه‌ها)، قبل ← بعد با سودِ سبز، و دکمه‌ی ارتقا
func _build_upgrade_block(item_id: String) -> void:
	var info: Dictionary = _upgrades.get(item_id, {})
	var head := _info_row()
	if info.is_empty():
		head.add_child(_spacer())
		head.add_child(_num_label("سطح %s" % MissionArt.fa_number(Global.character_level(item_id)), 19, GOLD))
		var wait := MenuUI.label("در حال گرفتن اطلاعات ارتقا…" if not _upgrades_loaded else "ارتقا فعلاً در دسترس نیست", 14, MenuUI.DIM)
		wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_info_col.add_child(wait)
		return

	var level := int(info.get("level", 1))
	var max_level := int(info.get("max_level", 1))
	var cost := int(info.get("cost", 0))
	var current: Dictionary = info.get("current", {})
	var next: Dictionary = info.get("next", {})

	var pips := HBoxContainer.new()
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.add_theme_constant_override("separation", 3)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in max_level:
		var pip := Panel.new()
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.custom_minimum_size = Vector2(10, 10)
		var filled := i < level
		pip.add_theme_stylebox_override("panel", MenuUI.box(GOLD if filled else Color(0, 0, 0, 0.5),
			GOLD if filled else Color(GOLD_DIM, 0.9), 1, 5))
		pips.add_child(pip)
		if filled and i + 1 == _pop_pip_level:
			pip.pivot_offset = Vector2(5, 5)
			pip.scale = Vector2(2.2, 2.2)
			var pt := pip.create_tween()
			pt.tween_property(pip, "scale", Vector2.ONE, 0.45).set_delay(0.15) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop_pip_level = 0
	head.add_child(pips)
	head.add_child(_spacer())
	head.add_child(_num_label("سطح %s از %s" % [MissionArt.fa_number(level), MissionArt.fa_number(max_level)], 19, GOLD))

	if next.is_empty():
		var maxed := MenuUI.label("حداکثر سطح! جان %s · آسیب %s" % [
			MissionArt.fa_number(int(current.get("health", 0))), MissionArt.fa_number(int(current.get("damage", 0)))], 15, GOLD)
		maxed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_info_col.add_child(maxed)
		return

	for pair in [["جان", "health"], ["آسیب", "damage"]]:
		var a := int(current.get(pair[1], 0))
		var b := int(next.get(pair[1], 0))
		var r := _info_row()
		r.add_child(_spacer())
		if b > a:
			r.add_child(_num_label("+%s" % MissionArt.fa_number(b - a), 15, COL_BETTER))
		r.add_child(_num_label("%s ← %s" % [MissionArt.fa_number(a), MissionArt.fa_number(b)], 16, MenuUI.TEXT))
		r.add_child(MenuUI.label(pair[0], 15, MenuUI.MUTED))

	var owned := Global.owns_item(item_id, CATEGORY_CHARACTER)
	if not owned:
		return
	var enough := Global.coins >= cost
	var equipped := _state_of(item_id) == "equipped"
	var btn := MenuUI.button("", "gold" if (enough and equipped) else "dark", 18)
	btn.add_theme_font_override("font", FONT_NUM)
	btn.icon = COIN_ICON
	btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", 24)
	btn.custom_minimum_size.y = 48.0
	if _upgrade_in_flight:
		btn.text = "در حال ارتقا…"
		btn.disabled = true
	else:
		btn.text = "ارتقا · %s" % MissionArt.fa_grouped(cost)
	if not enough:
		btn.add_theme_color_override("font_color", Color("ff9aa5"))
	elif not equipped:
		btn.add_theme_color_override("font_color", GOLD)
	btn.pressed.connect(_on_upgrade_pressed.bind(btn))
	_info_col.add_child(btn)
	if not enough:
		var need := MenuUI.label("%s سکه کم داری" % MissionArt.fa_grouped(cost - Global.coins), 14, MenuUI.MUTED)
		need.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_info_col.add_child(need)


# =============================================================================
# دکمه‌ی اقدام — V5: در هر حالت حداکثر یک دکمه‌ی طلاییِ اصلی
# =============================================================================

func _update_action_button() -> void:
	if not action_button:
		return

	var item: Dictionary = preview_by_category.get(current_category, {})
	if item.is_empty():
		_set_action("—", "dark", true)
		return

	var item_id := str(item.get("item_id", "")).strip_edges()
	var state := _state_of(item_id)
	match state:
		"equipped":
			# مجهز: دکمه آرام و غیرفعال؛ اگر ارتقا ممکن است، آن طلایی است
			_set_action("مجهز است", "dark", true)
			action_button.add_theme_color_override("font_disabled_color", GOLD)
		"owned":
			_set_action("انتخاب کن", "gold", false)
		_:
			if _is_skin_category(current_category):
				_set_action("دیدن در بتل‌پس", "gold", false)
			else:
				_set_action("باز کردن در فروشگاه", "gold", false)


func _set_action(text: String, kind: String, disabled: bool) -> void:
	action_button.text = text
	action_button.disabled = disabled
	MenuUI.style_button(action_button, kind)
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb := action_button.get_theme_stylebox(st) as StyleBoxFlat
		if sb:
			var copy := sb.duplicate() as StyleBoxFlat
			copy.set_corner_radius_all(12)
			if st == "disabled" and kind == "dark":
				copy.bg_color = Color(0.1, 0.08, 0.03, 0.9)
				copy.border_color = GOLD_DIM
			action_button.add_theme_stylebox_override(st, copy)
	_set_cta_pulse(kind == "gold" and not disabled)


## V5: تنها دکمه‌ی اصلی یک «نفسِ» خیلی ملایم دارد تا چشم پیدایش کند
func _set_cta_pulse(on: bool) -> void:
	if _cta_tween and _cta_tween.is_valid():
		_cta_tween.kill()
	_cta_tween = null
	action_button.self_modulate = Color.WHITE
	if not on:
		return
	_cta_tween = action_button.create_tween().set_loops()
	_cta_tween.tween_property(action_button, "self_modulate", Color(1.22, 1.12, 0.9, 1.0), 0.9) \
		.set_trans(Tween.TRANS_SINE)
	_cta_tween.tween_property(action_button, "self_modulate", Color.WHITE, 0.9).set_trans(Tween.TRANS_SINE)


func _on_action_pressed() -> void:
	var item: Dictionary = preview_by_category.get(current_category, {})
	if item.is_empty():
		return

	LocalSettings.vibrate(18)

	if _is_skin_category(current_category):
		if _skin_state(item) == "locked":
			UIFx.press(action_button, _go_to_battle_pass)
		else:
			UIFx.press(action_button)
			_equip_skin(item)
		return

	var item_id := str(item.get("item_id", "")).strip_edges()
	if Global.owns_item(item_id, current_category):
		UIFx.press(action_button)
		_equip(item)
	else:
		UIFx.press(action_button, _go_to_shop)


func _go_to_shop() -> void:
	Global.request_shop_tab(SHOP_TAB_CHARACTERS if current_category == CATEGORY_CHARACTER else SHOP_TAB_WEAPONS)
	get_tree().change_scene_to_file(SHOP_SCENE)


# =============================================================================
# انتخاب کارت و تجهیز
# =============================================================================

func _on_card_selected(item: Dictionary) -> void:
	_show_preview(item)
	if _is_skin_category(current_category):
		_equip_skin(item)
	else:
		_equip(item)
		# آموزش: لمسِ هر کارتِ بازِ کاراکتر/اسلحه یعنی انتخاب کرد (حتی اگر از قبل تجهیز بود)
		if Global.owns_item(str(item.get("item_id", "")).strip_edges(), current_category):
			Tutorial.notify(current_category + "_picked")


## E12: کارتِ قفل پیش‌نمایش را باز می‌کند؛ راهِ باز شدن در بلوکِ اطلاعات است،
## پس پیامِ شناوری که روی همان را بپوشاند لازم نیست
func _on_locked_card_tapped(item: Dictionary) -> void:
	_show_preview(item)


func _equip(item: Dictionary) -> void:
	var item_id := str(item.get("item_id", "")).strip_edges()
	if item_id.is_empty():
		return
	if not Global.owns_item(item_id, current_category):
		return
	if Global.is_equipped(item_id, current_category) and _pending_equip_id == "":
		return
	if _equip_in_flight:
		return
	if Global.my_username.is_empty():
		_show_toast("هنوز وارد حساب نشدی", false)
		return

	_equip_in_flight = true
	_pending_equip_id = item_id
	_pending_equip_category = current_category

	var payload := {
		"username": Global.my_username,
		"item_id": item_id,
		"category": current_category,
	}
	var err := equip_http.request(
		EQUIP_URL,
		Global.json_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if err != OK:
		_equip_in_flight = false
		_pending_equip_id = ""
		_show_toast("ارتباط با سرور برقرار نشد", false)
		_refresh_states()
		return
	# C12: کارت‌ها و ویترین همین الان «مجهز» را نشان می‌دهند
	_refresh_states()


func _on_equip_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_equip_in_flight = false

	if result != HTTPRequest.RESULT_SUCCESS:
		_pending_equip_id = ""
		_show_toast("ارتباط با سرور برقرار نشد — انتخاب برگشت", false)
		_refresh_states()
		return

	var payload: Dictionary = {}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK and typeof(json.data) == TYPE_DICTIONARY:
		payload = json.data

	if response_code != 200:
		_pending_equip_id = ""
		_show_toast(str(payload.get("error", "انتخاب انجام نشد")), false)
		_refresh_states()
		return

	# سرورهای قدیمی‌تر برای equip فقط ۲۰۰ با بدنه‌ی خالی می‌فرستند. چون خودمان
	# می‌دانیم چه چیزی درخواست شده، هر وقت سرور وضعیت جدید را برنگرداند از روی
	# همان درخواست پُرش می‌کنیم — وگرنه سرور «موفق» می‌گوید ولی UI روی انتخاب
	# قبلی گیر می‌کند.
	if not _pending_equip_id.is_empty():
		var equipped_key := "equipped_" + _pending_equip_category
		if str(payload.get(equipped_key, "")).strip_edges().is_empty():
			payload[equipped_key] = _pending_equip_id
	_pending_equip_id = ""

	# apply_equip_response خودش inventory_updated را می‌زند و _refresh_states اجرا می‌شود
	Global.apply_equip_response(payload)


func _on_home_pressed() -> void:
	# Back + دکمه‌ی خانه با هم: فقط یک بار برگرد
	if _leaving:
		return
	_leaving = true
	if home_button:
		home_button.pivot_offset = home_button.size * 0.5
		var tween := home_button.create_tween()
		tween.tween_property(home_button, "scale", Vector2(0.88, 0.88), 0.06) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(home_button, "scale", Vector2.ONE, 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tween.finished
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


# =============================================================================
# تصویر آیتم
# =============================================================================

func _texture_for(item: Dictionary, category: String) -> Texture2D:
	var item_id := str(item.get("item_id", item.get("id", ""))).strip_edges()
	if _is_skin_category(category):
		# کارت «پیش‌فرض» عکس خود آیتم پایه را نشان می‌دهد
		item_id = str(item.get("base_id", item_id)) if bool(item.get("is_default_look", false)) else item_id
	else:
		# آیتمی که اسکین فعال دارد با همان اسکین دیده می‌شود؛ وگرنه ظاهر پیش‌فرض
		item_id = Global.visual_id(item_id)
	var candidates: Array[String] = []

	if not item_id.is_empty():
		for folder in IMAGE_FOLDERS:
			candidates.append(folder + item_id + ".png")

	var custom_path := str(item.get("image_path", item.get("icon_path", ""))).strip_edges()
	if not custom_path.is_empty():
		if not custom_path.begins_with("res://"):
			custom_path = "res://" + custom_path.trim_prefix("/")
		candidates.append(custom_path)

	for path in candidates:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D

	push_warning("تصویر آیتم پیدا نشد: %s" % item_id)
	return null


# =============================================================================
# اسکین‌ها (فقط از بتل‌پس)
# =============================================================================

func _fetch_skins() -> void:
	if Global.my_username.is_empty():
		_skins_failed = true
		return
	var url := "%s/skins?username=%s" % [Global.SERVER_BASE, Global.my_username.uri_encode()]
	if skins_http.request(url, Global.auth_headers()) != OK:
		_skins_failed = true


func _on_skins_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var data := _parse_body(result, response_code, body)
	if data.is_empty():
		_skins_failed = true
		if _is_skin_category(current_category):
			_render_grid()
			_show_preview({})
		return
	_skins_failed = false
	if typeof(data.get("skins")) == TYPE_ARRAY:
		_skin_catalog = data["skins"]
	Global._apply_skin_data(data)
	_skins_loaded = true
	_build_skin_lists()
	if _is_skin_category(current_category):
		_render_grid()
		_show_preview(_pick_preview_item(current_category))
		_play_grid_intro()
	else:
		_refresh_states()


## هر تب اسکین: اول کارت «پیش‌فرض» هر آیتم پایه، بعد اسکین‌هایش
func _build_skin_lists() -> void:
	for category in SKIN_BASE_CATEGORY:
		var base_category: String = SKIN_BASE_CATEGORY[category]
		var list: Array = []
		var bases_done: Dictionary = {}
		for raw in _skin_catalog:
			if typeof(raw) != TYPE_DICTIONARY or str(raw.get("category", "")) != base_category:
				continue
			var base_id := str(raw.get("base_id", ""))
			if not bases_done.has(base_id):
				bases_done[base_id] = true
				list.append({
					"item_id": "default:" + base_id,
					"base_id": base_id,
					"name": "ظاهر پیش‌فرض",
					"rarity": "common",
					"is_default_look": true,
				})
			list.append({
				"item_id": str(raw.get("skin_id", "")),
				"base_id": base_id,
				"name": str(raw.get("name", raw.get("skin_id", ""))),
				"rarity": str(raw.get("rarity", "legend")),
				"pass_level": int(raw.get("pass_level", 0)),
			})
		items_by_category[category] = list
		# پیش‌نمایش قبلی ممکن است مال لیست قدیمی باشد
		var previewed: Dictionary = preview_by_category.get(category, {})
		if not previewed.is_empty():
			preview_by_category[category] = _find_item(str(previewed.get("item_id", "")), category)


func _skin_state(item: Dictionary) -> String:
	if item.is_empty():
		return "locked"
	var base_id := str(item.get("base_id", ""))
	if bool(item.get("is_default_look", false)):
		return "equipped" if Global.active_skin(base_id).is_empty() else "owned"
	var skin_id := str(item.get("item_id", ""))
	if not Global.owns_skin(skin_id):
		return "locked"
	return "equipped" if Global.active_skin(base_id) == skin_id else "owned"


func _base_name(base_id: String, base_category: String) -> String:
	var base := _find_item(base_id, base_category)
	if not base.is_empty():
		return str(base.get("name", base_id))
	return "AK-47" if base_id == "ak47" else ("سرباز پایه" if base_id == Global.DEFAULT_CHARACTER else base_id)


func _skin_source_text(item: Dictionary) -> String:
	var level := int(item.get("pass_level", 0))
	if level <= 0:
		return "بتل‌پس"
	return "بتل‌پس · پله‌ی %s" % MissionArt.fa_number(level)


## به‌جای نوارهای تراز: اسکین تراز ندارد، فقط می‌گوییم روی چه آیتمی و از کجا
func _build_skin_info_rows(item: Dictionary) -> void:
	_clear_stat_rows()
	if not stats_box or item.is_empty():
		return
	var base_category: String = SKIN_BASE_CATEGORY[current_category]
	var base_name := _base_name(str(item.get("base_id", "")), base_category)
	var is_default := bool(item.get("is_default_look", false))
	var state := _skin_state(item)

	_stat_rows.append(_make_info_row("روی آیتم", base_name, Color("f2e6cf")))
	_stat_rows.append(_make_info_row("منبع", "ظاهر اصلی" if is_default else _skin_source_text(item), GOLD))
	_stat_rows.append(_make_info_row("تراز", "فقط ظاهر — بدون تغییر قدرت", Color("cfcfd4")))
	var status := "مال توست" if state != "locked" else "فقط از بتل‌پس"
	_stat_rows.append(_make_info_row("وضعیت", status, Color("9be29b") if state != "locked" else Color("ff9aa5")))


func _make_info_row(title: String, value: String, value_color: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size.y = 26.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_box.add_child(row)

	var value_text := MenuUI.label(value, 15, value_color)
	value_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(value_text)

	var title_text := MenuUI.label(title, 15, Color("9c8f7a"))
	title_text.custom_minimum_size.x = 70.0
	title_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(title_text)
	return row


func _equip_skin(item: Dictionary) -> void:
	if item.is_empty() or _skin_equip_in_flight:
		return
	var state := _skin_state(item)
	if state == "locked":
		return
	if state == "equipped":
		return
	if Global.my_username.is_empty():
		_show_toast("هنوز وارد حساب نشدی", false)
		return

	var payload := {"username": Global.my_username, "base_id": str(item.get("base_id", ""))}
	payload["skin_id"] = "" if bool(item.get("is_default_look", false)) else str(item.get("item_id", ""))
	var err := skin_equip_http.request("%s/skins/equip" % Global.SERVER_BASE,
		Global.json_headers(), HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		_show_toast("ارتباط با سرور برقرار نشد", false)
		return
	_skin_equip_in_flight = true


func _on_skin_equip_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_skin_equip_in_flight = false
	var data := _parse_body(result, response_code, body, true)
	if data.is_empty():
		return
	# apply_skin_response خودش inventory_updated را می‌زند و کارت‌ها تازه می‌شوند
	Global.apply_skin_response(data)
	_show_toast("ظاهر انتخاب شد", true)


func _go_to_battle_pass() -> void:
	Global.request_missions_tab("season")
	get_tree().change_scene_to_file(MISSIONS_SCENE)


# =============================================================================
# ارتقای کاراکتر
# =============================================================================

func _fetch_upgrades() -> void:
	if Global.my_username.is_empty():
		return
	var url := "%s/upgrades?username=%s" % [Global.SERVER_BASE, Global.my_username.uri_encode()]
	upgrades_http.request(url, Global.auth_headers())


func _on_upgrades_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var data := _parse_body(result, response_code, body)
	_upgrades_loaded = true
	if typeof(data.get("characters")) != TYPE_ARRAY:
		_refresh_showcase_state()
		return
	_upgrades.clear()
	for entry in data["characters"]:
		if typeof(entry) == TYPE_DICTIONARY:
			_upgrades[str(entry.get("item_id", ""))] = entry
	_refresh_states()


func _on_upgrade_pressed(btn: Button) -> void:
	var item: Dictionary = preview_by_category.get(CATEGORY_CHARACTER, {})
	var item_id := str(item.get("item_id", "")).strip_edges()
	var info: Dictionary = _upgrades.get(item_id, {})
	if info.is_empty() or _upgrade_in_flight:
		return

	LocalSettings.vibrate(18)

	var cost := int(info.get("cost", 0))
	if Global.coins < cost:
		_show_toast("%s سکه کم داری — با مسابقه و مأموریت جمعش کن" % MissionArt.fa_grouped(cost - Global.coins), false)
		return

	# C13: ارتقایی که نصف یا بیشترِ سکه‌ها را می‌برد یک بار تأیید می‌خواهد —
	# ارتقاهای کوچک همان یک لمس می‌مانند تا روالِ تکراری کند نشود
	if cost * 2 >= Global.coins:
		if _upgrade_confirm_open:
			return
		_upgrade_confirm_open = true
		var current: Dictionary = info.get("current", {})
		var next: Dictionary = info.get("next", {})
		var body := "سطح %s ← %s: جان %s ← %s، آسیب %s ← %s\nبعد از ارتقا %s سکه برایت می‌ماند." % [
			MissionArt.fa_number(int(info.get("level", 1))), MissionArt.fa_number(int(info.get("level", 1)) + 1),
			MissionArt.fa_number(int(current.get("health", 0))), MissionArt.fa_number(int(next.get("health", 0))),
			MissionArt.fa_number(int(current.get("damage", 0))), MissionArt.fa_number(int(next.get("damage", 0))),
			MissionArt.fa_grouped(Global.coins - cost)]
		MenuUI.confirm(self, "ارتقا با %s سکه؟" % MissionArt.fa_grouped(cost), body,
			"ارتقا — %s سکه" % MissionArt.fa_grouped(cost),
			func(ok: bool) -> void:
				_upgrade_confirm_open = false
				if ok:
					_send_upgrade(item_id))
		return
	_send_upgrade(item_id)


var _upgrade_confirm_open := false


func _send_upgrade(item_id: String) -> void:
	if _upgrade_in_flight:
		return
	var payload := {"username": Global.my_username, "item_id": item_id}
	var err := upgrade_http.request("%s/upgrade_character" % Global.SERVER_BASE,
		Global.json_headers(), HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		_show_toast("ارتباط با سرور برقرار نشد", false)
		return
	_upgrade_in_flight = true
	_refresh_showcase_state()


func _on_upgrade_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_upgrade_in_flight = false
	var data := _parse_body(result, response_code, body, true)
	if data.is_empty():
		_refresh_showcase_state()
		return
	var upgrade: Dictionary = data.get("upgrade", {})
	var before: Dictionary = {}
	if not upgrade.is_empty():
		var uid := str(upgrade.get("item_id", ""))
		before = _upgrades.get(uid, {})
		_upgrades[uid] = upgrade
	var new_level := int(upgrade.get("level", 0))
	_celebrate_upgrade(before, upgrade, new_level)
	# inventory_updated → _refresh_states → بلوکِ ارتقا با سطحِ تازه
	Global.apply_upgrade_response(data)


## E17: لحظه‌ی ارتقا — دانه‌ی تازه می‌پرد، صحنه طلایی می‌درخشد، سود سبز
func _celebrate_upgrade(before: Dictionary, after: Dictionary, new_level: int) -> void:
	_pop_pip_level = new_level
	var a: Dictionary = before.get("current", {})
	var b: Dictionary = after.get("current", {})
	var parts: Array[String] = []
	for pair in [["جان", "health"], ["آسیب", "damage"]]:
		var d := int(b.get(pair[1], 0)) - int(a.get(pair[1], 0))
		if d > 0:
			parts.append("%s +%s" % [pair[0], MissionArt.fa_number(d)])
	if current_category == CATEGORY_CHARACTER:
		_stage_fx.celebrate(new_level, " · ".join(parts))


## بدنه‌ی JSON پاسخ. دیکشنری خالی یعنی خطا (و اگر toast_errors، پیام سرور نشان داده می‌شود)
func _parse_body(result: int, response_code: int, body: PackedByteArray, toast_errors: bool = false) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		if toast_errors:
			_show_toast("ارتباط با سرور برقرار نشد", false)
		return {}
	var data: Dictionary = {}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK and typeof(json.data) == TYPE_DICTIONARY:
		data = json.data
	if response_code != 200:
		if toast_errors:
			_show_toast(str(data.get("error", "انجام نشد")), false)
		return {}
	return data


# =============================================================================
# پیام شناور
# =============================================================================

var _toast_panel: PanelContainer = null
var _toast_label: Label = null
var _toast_tween: Tween = null


func _ensure_toast() -> void:
	if _toast_panel and is_instance_valid(_toast_panel):
		return

	_toast_panel = PanelContainer.new()
	_toast_panel.name = "SelectToast"
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.z_index = 200
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_panel.offset_bottom = -30.0
	_toast_panel.modulate.a = 0.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.04, 0.94)
	style.set_border_width_all(2)
	style.border_color = GOLD
	style.set_corner_radius_all(14)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	_toast_panel.add_theme_stylebox_override("panel", style)

	_toast_label = Label.new()
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_override("font", FONT_NUM)
	_toast_label.add_theme_font_size_override("font_size", 22)
	_toast_panel.add_child(_toast_label)

	add_child(_toast_panel)


func _show_toast(message: String, success: bool) -> void:
	_ensure_toast()

	_toast_label.text = message
	_toast_label.add_theme_color_override("font_color", GOLD if success else Color("ffd0d5"))

	var style: StyleBoxFlat = _toast_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.border_color = GOLD if success else RED

	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast_panel.modulate.a = 0.0
	_toast_panel.offset_bottom = -12.0
	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_property(_toast_panel, "offset_bottom", -30.0, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.set_parallel(false)
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.32) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
