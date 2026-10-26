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
const PADLOCK_ART := "res://assets/ui/psych/tease_padlock.png"

## ویژگی‌های سلاح
const WEAPON_STATS := [
	{"key": "power", "title": "قدرت"},
	{"key": "accuracy", "title": "دقت"},
	{"key": "range", "title": "برد"},
	{"key": "fire_rate", "title": "سرعت شلیک"},
	{"key": "control", "title": "کنترل"},
]

@onready var tab_characters: Button = $HeaderTabs/Tabs/CharactersButton
@onready var tab_weapons: Button = $HeaderTabs/Tabs/WeaponsButton
@onready var tab_char_skins: Button = $HeaderTabs/Tabs/CharSkinsButton
@onready var tab_weapon_skins: Button = $HeaderTabs/Tabs/WeaponSkinsButton

@onready var cards_panel: Panel = $Content/CardsPanel
@onready var cards_scroll: ScrollContainer = $Content/CardsPanel/CardsScroll
@onready var cards_grid: GridContainer = $Content/CardsPanel/CardsScroll/CardsGrid
@onready var empty_label: Label = $Content/CardsPanel/EmptyLabel

@onready var showcase: Panel = $Content/Showcase
@onready var preview_image: TextureRect = $Content/Showcase/PreviewImage
@onready var name_label: Label = $Content/Showcase/NameLabel
@onready var rarity_chip: Panel = $Content/Showcase/RarityChip
@onready var rarity_label: Label = $Content/Showcase/RarityChip/RarityLabel
@onready var stats_box: VBoxContainer = $Content/Showcase/StatsBox
@onready var action_button: Button = $Content/Showcase/ActionButton
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
var _skin_equip_in_flight := false
## وضعیت ارتقای هر کاراکتر از /upgrades: item_id → {level, max_level, cost, current, next}
var _upgrades: Dictionary = {}
var _upgrade_in_flight := false

# پنل ارتقا (در کد ساخته می‌شود، فقط در تب کاراکترها دیده می‌شود)
var _upgrade_row: HBoxContainer
var _upgrade_level_label: Label
var _upgrade_delta_label: Label
var _upgrade_button: Button

var current_category: String = CATEGORY_CHARACTER
var catalog_loaded: bool = false
var _equip_in_flight: bool = false
# آیتمی که همین الان درخواست تجهیزش رفته. اگر سرور وضعیت جدید را در پاسخ
# برنگرداند، از روی همین درخواست UI را آپدیت می‌کنیم.
var _pending_equip_id: String = ""
var _pending_equip_category: String = ""
var _stat_rows: Array[Control] = []


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

	_style_ui()
	_build_upgrade_row()
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
	chip_style.content_margin_left = 14.0
	chip_style.content_margin_right = 14.0
	if rarity_chip:
		rarity_chip.add_theme_stylebox_override("panel", chip_style)

	_style_action_button()
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


func _style_action_button() -> void:
	if not action_button:
		return
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = RED_DEEP
		style.set_border_width_all(2)
		style.border_color = GOLD_DIM
		style.set_corner_radius_all(14)
		action_button.add_theme_stylebox_override(state_name, style)
	action_button.focus_mode = Control.FOCUS_NONE


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


# =============================================================================
# تب‌ها
# =============================================================================

func _setup_tab_buttons() -> void:
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
	_layout_showcase()

	if animate:
		LocalSettings.vibrate(15)
	if animate:
		Tutorial.notify("category_" + category)

	_render_grid()
	_show_preview(_pick_preview_item(category))

	if animate:
		_play_grid_intro()


## تب فعال: قاب و متن طلایی + یک پله بزرگ‌تر. تب خاموش: خاکستری و کوچک‌تر.
func _paint_tab(btn: Button, active: bool, animate: bool) -> void:
	if not btn:
		return

	var style: StyleBoxFlat = btn.get_theme_stylebox("normal") as StyleBoxFlat
	if style:
		style.bg_color = Color(0.28, 0.02, 0.05, 0.92) if active else Color(0.06, 0.02, 0.03, 0.85)
		style.border_color = GOLD if active else GOLD_DIM
	btn.add_theme_color_override("font_color", GOLD if active else Color("9c8f7a"))

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
		_show_toast("ارتباط با سرور برقرار نشد", false)


func _on_catalog_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var raw: Array = []
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			if typeof(json.data) == TYPE_ARRAY:
				raw = json.data
			elif typeof(json.data) == TYPE_DICTIONARY and typeof(json.data.get("items")) == TYPE_ARRAY:
				raw = json.data["items"]
	else:
		_show_toast("لیست آیتم‌ها از سرور نیامد", false)

	_build_item_lists(raw)
	_build_skin_lists()
	catalog_loaded = true
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

	# آیتم‌های مال خود بازیکن بالای لیست، بعد بقیه — قفل‌ها ته صف
	for category in [CATEGORY_CHARACTER, CATEGORY_WEAPON]:
		var list: Array = items_by_category[category]
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _sort_weight(a, category) < _sort_weight(b, category)
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


# =============================================================================
# گرید کارت‌ها
# =============================================================================

func _render_grid() -> void:
	if not cards_grid:
		return

	for child in cards_grid.get_children():
		child.queue_free()

	var list: Array = items_by_category.get(current_category, [])
	if empty_label:
		empty_label.visible = list.is_empty()
		var loaded := _skins_loaded if _is_skin_category(current_category) else catalog_loaded
		empty_label.text = "در حال گرفتن لیست..." if not loaded else "آیتمی برای نمایش نیست"

	for item in list:
		var card: Control = SELECT_CARD_SCENE.instantiate()
		cards_grid.add_child(card)
		_setup_card(card, item)
		card.card_selected.connect(_on_card_selected)
		card.locked_tapped.connect(_on_locked_card_tapped)


func _setup_card(card: Control, item: Dictionary) -> void:
	var item_id := str(item.get("item_id", "")).strip_edges()
	card.set_meta("item_id", item_id)
	card.setup(item, _state_of(item_id), _texture_for(item, current_category), _unlock_text(item))


func _state_of(item_id: String) -> String:
	if _is_skin_category(current_category):
		return _skin_state(_find_item(item_id, current_category))
	if Global.is_equipped(item_id, current_category):
		return "equipped"
	if Global.owns_item(item_id, current_category):
		return "owned"
	return "locked"


## بدون ساختن دوباره‌ی کارت‌ها، فقط حالتشان را تازه می‌کند
func _refresh_states() -> void:
	if not cards_grid:
		return
	for card in cards_grid.get_children():
		var item_id: String = str(card.get_meta("item_id", ""))
		var item: Dictionary = _find_item(item_id, current_category)
		if item.is_empty():
			continue
		card.setup(item, _state_of(item_id), _texture_for(item, current_category), _unlock_text(item))

	_update_action_button()


## E12 کنجکاوی: شرطِ باز شدنِ آیتمِ قفل، کوتاه و دقیق («۶٬۰۰۰ سکه»، «بتل‌پس · پله‌ی ۱۲»)
func _unlock_text(item: Dictionary) -> String:
	if _is_skin_category(current_category):
		return _skin_source_text(item)
	var price := int(item.get("final_price", item.get("original_price", item.get("price", 0))))
	if price <= 0:
		return ""
	var cost_type := str(item.get("cost_type", "coins")).to_lower()
	var unit := "قلب" if cost_type in ["gems", "gem", "heart"] else "سکه"
	return "%s %s" % [MissionArt.fa_grouped(price), unit]


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
		card.scale = Vector2(0.88, 0.88)
		var delay: float = mini(i, 12) * 0.035
		var tween := card.create_tween().set_parallel(true)
		tween.tween_property(card, "modulate:a", 1.0, 0.20).set_delay(delay)
		tween.tween_property(card, "scale", Vector2.ONE, 0.28) \
			.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# =============================================================================
# پنل جزییات
# =============================================================================

func _show_preview(item: Dictionary) -> void:
	preview_by_category[current_category] = item

	if item.is_empty():
		if name_label:
			name_label.text = "—"
		if preview_image:
			preview_image.texture = null
		_clear_stat_rows()
		_update_action_button()
		return

	if name_label:
		name_label.text = str(item.get("name", "بدون نام"))

	var rarity := str(item.get("rarity", item.get("rarety", "common"))).to_lower().strip_edges()
	if rarity_label:
		rarity_label.text = RARITY_LABELS.get(rarity, RARITY_LABELS["common"])
		rarity_label.add_theme_color_override("font_color", RARITY_COLORS.get(rarity, RARITY_COLORS["common"]))
	if rarity_chip:
		var chip_style: StyleBoxFlat = rarity_chip.get_theme_stylebox("panel") as StyleBoxFlat
		if chip_style:
			chip_style.border_color = RARITY_COLORS.get(rarity, RARITY_COLORS["common"])

	if preview_image:
		preview_image.texture = _texture_for(item, current_category)
		_play_preview_swap()

	if _is_skin_category(current_category):
		_build_skin_info_rows(item)
	else:
		_build_stat_rows(item)
	_refresh_personal_stats(item)
	_update_action_button()


## عوض شدن آیتم توی پنل: یک ورود کوتاه از پایین، بدون کش آمدن
func _play_preview_swap() -> void:
	if not preview_image:
		return
	preview_image.modulate.a = 0.0
	preview_image.scale = Vector2(0.94, 0.94)
	preview_image.pivot_offset = preview_image.size * 0.5

	var tween := preview_image.create_tween().set_parallel(true)
	tween.tween_property(preview_image, "modulate:a", 1.0, 0.18) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(preview_image, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	# C11: آیتمِ تجهیزشده‌ی همین دسته مرجعِ مقایسه است (خطِ طلایی + اختلاف)
	var ref_stats := {}
	var shown_id := str(item.get("item_id", "")).strip_edges()
	for other in items_by_category.get(current_category, []):
		var other_id := str(other.get("item_id", "")).strip_edges()
		if other_id != shown_id and Global.is_equipped(other_id, current_category):
			ref_stats = _stats_of(other)
			break

	var definitions: Array = CHARACTER_STATS if current_category == CATEGORY_CHARACTER else WEAPON_STATS
	for definition in definitions:
		var key: String = definition["key"]
		var value := int(stats.get(key, item.get(key, 0)))
		var ref := int(ref_stats.get(key, -1)) if not ref_stats.is_empty() else -1
		_stat_rows.append(_make_stat_row(str(definition["title"]), value, STAT_SCALE, ref))


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


func _make_stat_row(title: String, value: int, max_value: int, ref_value: int = -1) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size.y = 22.0
	stats_box.add_child(row)

	var ui_font := load("res://fonts/Lalezar-Regular.ttf")

	# اختلاف با آیتمِ فعلی — سبز بهتر، قرمز ضعیف‌تر، همیشه با علامت (نه فقط رنگ، V2)
	var delta_text := Label.new()
	delta_text.custom_minimum_size.x = 34.0
	delta_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	delta_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if ui_font:
		delta_text.add_theme_font_override("font", ui_font)
	delta_text.add_theme_font_size_override("font_size", 15)
	var delta := value - ref_value
	if ref_value >= 0 and delta != 0:
		delta_text.text = ("+%s" % MissionArt.fa_number(delta)) if delta > 0 else ("−%s" % MissionArt.fa_number(-delta))
		delta_text.add_theme_color_override("font_color", COL_BETTER if delta > 0 else COL_WORSE)
	row.add_child(delta_text)

	var value_text := Label.new()
	value_text.text = MissionArt.fa_number(value)
	value_text.custom_minimum_size.x = 34.0
	value_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if ui_font:
		value_text.add_theme_font_override("font", ui_font)
	value_text.add_theme_font_size_override("font_size", 16)
	value_text.add_theme_color_override("font_color", Color("cfcfd4"))
	row.add_child(value_text)

	var track := Panel.new()
	track.custom_minimum_size = Vector2(0, 12)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track_style := StyleBoxFlat.new()
	track_style.bg_color = Color(0, 0, 0, 0.55)
	track_style.set_corner_radius_all(6)
	track.add_theme_stylebox_override("panel", track_style)
	row.add_child(track)

	var fill := Panel.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = RED
	fill_style.set_corner_radius_all(6)
	fill.add_theme_stylebox_override("panel", fill_style)
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ratio: float = clampf(float(value) / float(max_value), 0.0, 1.0) if max_value > 0 else 0.0
	fill.anchor_right = 0.0
	fill.offset_right = 0.0
	track.add_child(fill)

	# خطِ طلاییِ مقدارِ آیتمِ تجهیزشده روی همین نوار
	if ref_value >= 0 and max_value > 0:
		var mark := ColorRect.new()
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.color = GOLD
		var r := clampf(float(ref_value) / float(max_value), 0.0, 1.0)
		mark.anchor_left = r
		mark.anchor_right = r
		mark.anchor_top = 0.0
		mark.anchor_bottom = 1.0
		mark.offset_left = -1.5
		mark.offset_right = 1.5
		mark.offset_top = -3.0
		mark.offset_bottom = 3.0
		track.add_child(mark)

	# نوار از صفر تا مقدارش پر می‌شود — حرکت کوتاه و قاطع
	var tween := fill.create_tween()
	tween.tween_property(fill, "anchor_right", ratio, 0.34) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var title_text := Label.new()
	title_text.text = title
	title_text.custom_minimum_size.x = 108.0
	title_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if ui_font:
		title_text.add_theme_font_override("font", ui_font)
	title_text.add_theme_font_size_override("font_size", 17)
	title_text.add_theme_color_override("font_color", GOLD)
	row.add_child(title_text)

	return row


# =============================================================================
# دکمه‌ی اقدام (انتخاب / انتخاب شده / خرید)
# =============================================================================

func _update_action_button() -> void:
	if not action_button:
		return

	var item: Dictionary = preview_by_category.get(current_category, {})
	if item.is_empty():
		action_button.disabled = true
		action_button.text = "—"
		_paint_action_button(Color(0.1, 0.1, 0.1, 0.8), Color("5a5a5a"), Color("8a8a8a"))
		return

	var item_id := str(item.get("item_id", "")).strip_edges()
	_refresh_upgrade_row()

	if _is_skin_category(current_category):
		match _skin_state(item):
			"equipped":
				action_button.disabled = true
				action_button.text = "انتخاب شده"
				_paint_action_button(Color(0.22, 0.16, 0.0, 0.9), GOLD, GOLD)
			"owned":
				action_button.disabled = false
				action_button.text = "انتخاب کن"
				_paint_action_button(RED_DEEP, GOLD, GOLD)
			_:
				action_button.disabled = false
				action_button.text = "دریافت از بتل‌پس"
				_paint_action_button(Color(0.09, 0.09, 0.11, 0.9), Color("8b8b93"), Color("d5d5dc"))
		return

	if Global.is_equipped(item_id, current_category):
		action_button.disabled = true
		action_button.text = "انتخاب شده"
		_paint_action_button(Color(0.22, 0.16, 0.0, 0.9), GOLD, GOLD)
	elif Global.owns_item(item_id, current_category):
		action_button.disabled = false
		action_button.text = "انتخاب کن"
		_paint_action_button(RED_DEEP, GOLD, GOLD)
	else:
		action_button.disabled = false
		# E12: قیمتِ باز شدن همین‌جا هم پیداست، نه فقط بعد از رفتن به فروشگاه
		var cond := _unlock_text(item)
		action_button.text = ("خرید از فروشگاه · %s" % cond) if cond != "" else "خرید از فروشگاه"
		_paint_action_button(Color(0.09, 0.09, 0.11, 0.9), Color("8b8b93"), Color("d5d5dc"))


func _paint_action_button(bg: Color, border: Color, text_color: Color) -> void:
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style: StyleBoxFlat = action_button.get_theme_stylebox(state_name) as StyleBoxFlat
		if style:
			style.bg_color = bg
			style.border_color = border
	action_button.add_theme_color_override("font_color", text_color)
	action_button.add_theme_color_override("font_disabled_color", text_color)


func _on_action_pressed() -> void:
	var item: Dictionary = preview_by_category.get(current_category, {})
	if item.is_empty():
		return

	_animate_action_button()

	if _is_skin_category(current_category):
		if _skin_state(item) == "locked":
			_go_to_battle_pass()
		else:
			_equip_skin(item)
		return

	var item_id := str(item.get("item_id", "")).strip_edges()
	if Global.owns_item(item_id, current_category):
		_equip(item)
	else:
		_go_to_shop()


## فشرده شدن دکمه‌ی اقدام: کوتاه، تیز، با یک برق طلایی — نه لرزش کشسان
func _animate_action_button() -> void:
	LocalSettings.vibrate(18)

	action_button.pivot_offset = action_button.size * 0.5

	var tween := action_button.create_tween()
	tween.tween_property(action_button, "scale", Vector2(0.95, 0.95), 0.06) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(action_button, "scale", Vector2(1.04, 1.04), 0.09) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(action_button, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var flash := action_button.create_tween()
	flash.tween_property(action_button, "modulate", Color(1.5, 1.35, 1.0, 1.0), 0.06)
	flash.tween_property(action_button, "modulate", Color.WHITE, 0.22)


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


func _on_locked_card_tapped(item: Dictionary) -> void:
	_show_preview(item)
	# E12: به‌جای «قفله» بگو دقیقاً با چه چیزی باز می‌شود
	if _is_skin_category(current_category):
		_show_toast("در %s باز می‌شود" % _skin_source_text(item), false)
	else:
		var cond := _unlock_text(item)
		_show_toast(("در فروشگاه با %s باز می‌شود" % cond) if cond != "" else "از فروشگاه باز می‌شود", false)


## E8 مالکیت: آمارِ شخصیِ همین اسلحه/کاراکتر روی پایینِ عکسِ پیش‌نمایش
var _personal_label: Label = null


func _refresh_personal_stats(item: Dictionary) -> void:
	if preview_image == null:
		return
	if _personal_label == null:
		_personal_label = Label.new()
		_personal_label.name = "PersonalStats"
		_personal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_personal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_personal_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		var f := load("res://fonts/Lalezar-Regular.ttf")
		if f:
			_personal_label.add_theme_font_override("font", f)
		_personal_label.add_theme_font_size_override("font_size", 17)
		_personal_label.add_theme_color_override("font_color", GOLD)
		_personal_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		_personal_label.add_theme_constant_override("outline_size", 6)
		preview_image.add_child(_personal_label)
		_personal_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_personal_label.offset_top = -26.0
	var item_id := str(item.get("item_id", "")).strip_edges()
	var text := ""
	if not _is_skin_category(current_category) and Global.owns_item(item_id, current_category):
		text = LOADOUT_STATS.summary(current_category, item_id)
		if text == "" and Global.is_equipped(item_id, current_category):
			text = "مسابقه‌ی بعدی را با همین بزن تا آمارش این‌جا ثبت شود"
	_personal_label.text = text
	_personal_label.visible = text != ""


func _equip(item: Dictionary) -> void:
	var item_id := str(item.get("item_id", "")).strip_edges()
	if item_id.is_empty():
		return
	if not Global.owns_item(item_id, current_category):
		_show_toast("این آیتم قفله — اول از فروشگاه بخرش", false)
		return
	if Global.is_equipped(item_id, current_category):
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


func _on_equip_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_equip_in_flight = false

	if result != HTTPRequest.RESULT_SUCCESS:
		_show_toast("ارتباط با سرور برقرار نشد", false)
		return

	var payload: Dictionary = {}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK and typeof(json.data) == TYPE_DICTIONARY:
		payload = json.data

	if response_code != 200:
		_pending_equip_id = ""
		_show_toast(str(payload.get("error", "انتخاب انجام نشد")), false)
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
	_show_toast("انتخاب شد", true)


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
		return
	var url := "%s/skins?username=%s" % [Global.SERVER_BASE, Global.my_username.uri_encode()]
	if skins_http.request(url, Global.auth_headers()) != OK:
		_show_toast("ارتباط با سرور برقرار نشد", false)


func _on_skins_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var data := _parse_body(result, response_code, body)
	if data.is_empty():
		return
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
	return "بتل‌پس طلایی · پله‌ی %s" % MissionArt.fa_number(level)


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
	_stat_rows.append(_make_info_row("تراز", "همان آیتم پایه — فقط ظاهر", Color("cfcfd4")))
	var status := "در اختیار داری" if state != "locked" else "قفل — در فروشگاه فروخته نمی‌شود"
	_stat_rows.append(_make_info_row("وضعیت", status, Color("9be29b") if state != "locked" else Color("ff9aa5")))


func _make_info_row(title: String, value: String, value_color: Color) -> Control:
	var ui_font := load("res://fonts/Lalezar-Regular.ttf")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size.y = 28.0
	stats_box.add_child(row)

	var value_text := Label.new()
	value_text.text = value
	value_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if ui_font:
		value_text.add_theme_font_override("font", ui_font)
	value_text.add_theme_font_size_override("font_size", 17)
	value_text.add_theme_color_override("font_color", value_color)
	row.add_child(value_text)

	var title_text := Label.new()
	title_text.text = title
	title_text.custom_minimum_size.x = 80.0
	title_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if ui_font:
		title_text.add_theme_font_override("font", ui_font)
	title_text.add_theme_font_size_override("font_size", 17)
	title_text.add_theme_color_override("font_color", Color("9c8f7a"))
	row.add_child(title_text)
	return row


func _equip_skin(item: Dictionary) -> void:
	if item.is_empty() or _skin_equip_in_flight:
		return
	var state := _skin_state(item)
	if state == "locked":
		_show_toast(_skin_source_text(item) + " — فقط از بتل‌پس", false)
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
	if typeof(data.get("characters")) != TYPE_ARRAY:
		return
	_upgrades.clear()
	for entry in data["characters"]:
		if typeof(entry) == TYPE_DICTIONARY:
			_upgrades[str(entry.get("item_id", ""))] = entry
	_refresh_upgrade_row()


## ردیف ارتقا بالای دکمه‌ی انتخاب: «سطح ۲/۵ · جان ۱۲۰ ← ۱۲۶» + دکمه‌ی ارتقا
func _build_upgrade_row() -> void:
	if not showcase:
		return
	var ui_font := load("res://fonts/Lalezar-Regular.ttf")

	_upgrade_row = HBoxContainer.new()
	_upgrade_row.name = "UpgradeRow"
	_upgrade_row.add_theme_constant_override("separation", 10)
	showcase.add_child(_upgrade_row)
	_upgrade_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_upgrade_row.offset_left = 24.0
	_upgrade_row.offset_right = -24.0
	_upgrade_row.offset_top = -126.0
	_upgrade_row.offset_bottom = -74.0

	_upgrade_button = Button.new()
	_upgrade_button.custom_minimum_size = Vector2(150, 50)
	_upgrade_button.focus_mode = Control.FOCUS_NONE
	_upgrade_button.icon = load("res://assets/ui/coin_icon.png")
	_upgrade_button.expand_icon = true
	_upgrade_button.add_theme_constant_override("icon_max_width", 26)
	if ui_font:
		_upgrade_button.add_theme_font_override("font", ui_font)
	_upgrade_button.add_theme_font_size_override("font_size", 20)
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.28, 0.2, 0.02, 0.95) if state_name != "pressed" else Color(0.45, 0.32, 0.03, 1.0)
		style.set_border_width_all(2)
		style.border_color = GOLD
		style.set_corner_radius_all(12)
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		_upgrade_button.add_theme_stylebox_override(state_name, style)
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	_upgrade_row.add_child(_upgrade_button)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.add_theme_constant_override("separation", 0)
	_upgrade_row.add_child(text_box)

	_upgrade_level_label = Label.new()
	_upgrade_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if ui_font:
		_upgrade_level_label.add_theme_font_override("font", ui_font)
	_upgrade_level_label.add_theme_font_size_override("font_size", 20)
	_upgrade_level_label.add_theme_color_override("font_color", GOLD)
	text_box.add_child(_upgrade_level_label)

	_upgrade_delta_label = Label.new()
	_upgrade_delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_upgrade_delta_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if ui_font:
		_upgrade_delta_label.add_theme_font_override("font", ui_font)
	_upgrade_delta_label.add_theme_font_size_override("font_size", 15)
	_upgrade_delta_label.add_theme_color_override("font_color", Color("cfcfd4"))
	text_box.add_child(_upgrade_delta_label)


## پنل جزییات در تب کاراکترها برای ردیف ارتقا جا باز می‌کند
func _layout_showcase() -> void:
	var with_upgrade := current_category == CATEGORY_CHARACTER
	if _upgrade_row:
		_upgrade_row.visible = with_upgrade
	if preview_image:
		preview_image.offset_bottom = 212.0 if with_upgrade else 284.0
	if stats_box:
		stats_box.offset_top = 216.0 if with_upgrade else 290.0
		stats_box.offset_bottom = -132.0 if with_upgrade else -72.0
		stats_box.add_theme_constant_override("separation", 3 if with_upgrade else 6)


func _refresh_upgrade_row() -> void:
	if not _upgrade_row or current_category != CATEGORY_CHARACTER:
		return
	var item: Dictionary = preview_by_category.get(CATEGORY_CHARACTER, {})
	var item_id := str(item.get("item_id", "")).strip_edges()
	var info: Dictionary = _upgrades.get(item_id, {})

	if info.is_empty():
		_upgrade_level_label.text = "سطح %s" % MissionArt.fa_number(Global.character_level(item_id))
		_upgrade_delta_label.text = ""
		_upgrade_button.text = "ارتقا"
		_upgrade_button.disabled = true
		return

	var level := int(info.get("level", 1))
	var max_level := int(info.get("max_level", 1))
	var cost := int(info.get("cost", 0))
	var current: Dictionary = info.get("current", {})
	var next: Dictionary = info.get("next", {})
	_upgrade_level_label.text = "سطح %s / %s" % [MissionArt.fa_number(level), MissionArt.fa_number(max_level)]

	if next.is_empty():
		_upgrade_delta_label.text = "جان %s  |  آسیب %s" % [
			MissionArt.fa_number(int(current.get("health", 0))), MissionArt.fa_number(int(current.get("damage", 0)))]
		_upgrade_button.text = "حداکثر"
		_upgrade_button.icon = null
		_upgrade_button.disabled = true
		return

	_upgrade_delta_label.text = "جان %s ← %s  |  آسیب %s ← %s" % [
		MissionArt.fa_number(int(current.get("health", 0))), MissionArt.fa_number(int(next.get("health", 0))),
		MissionArt.fa_number(int(current.get("damage", 0))), MissionArt.fa_number(int(next.get("damage", 0)))]
	_upgrade_button.icon = load("res://assets/ui/coin_icon.png")
	if not Global.owns_item(item_id, CATEGORY_CHARACTER):
		_upgrade_button.text = "قفل"
		_upgrade_button.disabled = true
		return
	_upgrade_button.text = MissionArt.fa_grouped(cost)
	_upgrade_button.disabled = _upgrade_in_flight
	# سکه‌ی ناکافی: دکمه فعال می‌ماند تا پیام بدهد، ولی عدد قرمز می‌شود
	_upgrade_button.add_theme_color_override("font_color", GOLD if Global.coins >= cost else Color("ff7a86"))


func _on_upgrade_pressed() -> void:
	var item: Dictionary = preview_by_category.get(CATEGORY_CHARACTER, {})
	var item_id := str(item.get("item_id", "")).strip_edges()
	var info: Dictionary = _upgrades.get(item_id, {})
	if info.is_empty() or _upgrade_in_flight:
		return

	_upgrade_button.pivot_offset = _upgrade_button.size * 0.5
	var tween := _upgrade_button.create_tween()
	tween.tween_property(_upgrade_button, "scale", Vector2(0.93, 0.93), 0.06)
	tween.tween_property(_upgrade_button, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK)
	LocalSettings.vibrate(18)

	var cost := int(info.get("cost", 0))
	if Global.coins < cost:
		_show_toast("سکه کافی نیست", false)
		return

	# C13: ارتقایی که نصف یا بیشترِ سکه‌ها را می‌برد یک بار تأیید می‌خواهد —
	# ارتقاهای کوچک همان یک لمس می‌مانند تا روالِ تکراری کند نشود
	if cost * 2 >= Global.coins:
		if _upgrade_confirm_open:
			return
		_upgrade_confirm_open = true
		var body := "%s\nبعد از ارتقا %s سکه برایت می‌ماند." % [
			_upgrade_delta_label.text if _upgrade_delta_label else "",
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
	_upgrade_button.disabled = true


func _on_upgrade_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_upgrade_in_flight = false
	var data := _parse_body(result, response_code, body, true)
	if data.is_empty():
		_refresh_upgrade_row()
		return
	var upgrade: Dictionary = data.get("upgrade", {})
	if not upgrade.is_empty():
		_upgrades[str(upgrade.get("item_id", ""))] = upgrade
	Global.apply_upgrade_response(data)
	_refresh_upgrade_row()
	_show_toast("ارتقا به سطح %s" % MissionArt.fa_number(int(upgrade.get("level", 0))), true)


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
	var toast_font := load("res://fonts/Lalezar-Regular.ttf")
	if toast_font:
		_toast_label.add_theme_font_override("font", toast_font)
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
