extends Control

# ارجاع به دکمه‌های تب
@onready var btn_special: Button = $AllAboveButtons/AboveButtons/specialButton
@onready var btn_characters: Button = $AllAboveButtons/AboveButtons/CharacterButton
@onready var btn_weapons: Button = $AllAboveButtons/AboveButtons/WeaponButton
@onready var btn_currencies: Button = $AllAboveButtons/AboveButtons/CoingemButton

# ارجاع به پنل‌های اصلی محتوای هر تب
@onready var special_tab: Control = $SectionMenu/SpecialTab
@onready var characters_tab: Control = $SectionMenu/CharactersTab
@onready var weapons_tab: Control = $SectionMenu/WeaponsTab
@onready var currencies_tab: Control = $SectionMenu/GemandcoinTab

# ارجاع به المان‌های پنل پیشنهاد ویژه
@onready var suggest_name_label: Label = $SectionMenu/SpecialTab/SuggestUp/VBoxContainer/NameLabel
@onready var suggest_item_img: TextureRect = $SectionMenu/SpecialTab/SuggestUp/ItemImg
@onready var suggest_first_amount: RichTextLabel = $SectionMenu/SpecialTab/SuggestUp/BuyButton/FirstamountLabel
@onready var suggest_last_amount: Label = $SectionMenu/SpecialTab/SuggestUp/BuyButton/LastamountLabel
@onready var suggest_percent_label: Label = $SectionMenu/SpecialTab/SuggestUp/PercentBg/Label
@onready var suggest_buy_button: TextureButton = $SectionMenu/SpecialTab/SuggestUp/BuyButton

# ارجاع به المان‌های پنل نمایش کاراکتر
@onready var cs_name_label: Label = $SectionMenu/CharactersTab/CardShow/NameLabel
@onready var cs_character_image: TextureRect = $SectionMenu/CharactersTab/CardShow/CharacterImage
@onready var cs_rarity_icon: TextureRect = $SectionMenu/CharactersTab/CardShow/RaretyIcon
@onready var cs_background: TextureRect = $SectionMenu/CharactersTab/CardShow/Background
@onready var cs_reference_rect: ReferenceRect = $SectionMenu/CharactersTab/CardShow/ReferenceRect
@onready var cs_buy_button: Button = $SectionMenu/CharactersTab/CardShow/BuyButton
@onready var cs_buy_price_label: Label = $SectionMenu/CharactersTab/CardShow/BuyButton/HBoxContainer/Label
@onready var cs_buy_type_icon: TextureRect = $SectionMenu/CharactersTab/CardShow/BuyButton/HBoxContainer/TypeIcon

# ارجاع به ویژگی‌های کاراکتر
@onready var cs_stat_movement: HBoxContainer = $SectionMenu/CharactersTab/CardShow/VBoxContainer/MovementSpeed
@onready var cs_stat_accuracy: HBoxContainer = $SectionMenu/CharactersTab/CardShow/VBoxContainer/ShootingAccuracy
@onready var cs_stat_hand_speed: HBoxContainer = $SectionMenu/CharactersTab/CardShow/VBoxContainer/HandSpeed
@onready var cs_stat_throwing: HBoxContainer = $SectionMenu/CharactersTab/CardShow/VBoxContainer/ThrowingRange
@onready var cs_stat_health: HBoxContainer = $SectionMenu/CharactersTab/CardShow/VBoxContainer/Health
@onready var cs_stat_regen: HBoxContainer = $SectionMenu/CharactersTab/CardShow/VBoxContainer/HealthRegen

# ارجاع به المان‌های پنل نمایش سلاح
@onready var ws_name_label: Label = $SectionMenu/WeaponsTab/Control2/NameLabel
@onready var ws_weapon_image: TextureRect = $SectionMenu/WeaponsTab/Control2/WeaponImage
@onready var ws_background: TextureRect = $SectionMenu/WeaponsTab/Control2/Background
@onready var ws_reference_rect: ReferenceRect = $SectionMenu/WeaponsTab/Control2/ReferenceRect
@onready var ws_rarity_icon: TextureRect = $SectionMenu/WeaponsTab/Control2/RaretyIcon
@onready var ws_buy_button: Button = $SectionMenu/WeaponsTab/Control2/BuyButton
@onready var ws_buy_price_label: Label = $SectionMenu/WeaponsTab/Control2/BuyButton/HBoxContainer/AmountLabel
@onready var ws_buy_type_icon: TextureRect = $SectionMenu/WeaponsTab/Control2/BuyButton/HBoxContainer/TypeIcon

# ارجاع به ویژگی‌های سلاح
@onready var ws_stat_power: HBoxContainer = $SectionMenu/WeaponsTab/Control2/VBoxContainer/Power
@onready var ws_stat_accuracy: HBoxContainer = $SectionMenu/WeaponsTab/Control2/VBoxContainer/Accuracy
@onready var ws_stat_range: HBoxContainer = $SectionMenu/WeaponsTab/Control2/VBoxContainer/Range
@onready var ws_stat_fire_rate: HBoxContainer = $SectionMenu/WeaponsTab/Control2/VBoxContainer/Speed
@onready var ws_stat_control: HBoxContainer = $SectionMenu/WeaponsTab/Control2/VBoxContainer/Control

# نودهای ارتباطی
@onready var shop_http_request: HTTPRequest = HTTPRequest.new()
@onready var buy_http_request: HTTPRequest = HTTPRequest.new()

# کانتینرهای تب ویژه
@onready var weekly_container: HBoxContainer = $SectionMenu/SpecialTab/SuggestSec/WeeklyContainer
@onready var special_container: HBoxContainer = $SectionMenu/SpecialTab/SuggestBottom/SpecialContainer

# بسته‌ی شانسی
@onready var lucky_panel: Control = $SectionMenu/SpecialTab/VipControl
@onready var lucky_button: Button = $SectionMenu/SpecialTab/VipControl/OpenButton
@onready var lucky_price_label: Label = $SectionMenu/SpecialTab/VipControl/Bg/Label

# ویترین بسته‌های قلب داخل تب ویژه
@onready var gem_offer_container: VBoxContainer = $SectionMenu/SpecialTab/GemControl/VBoxContainer

# کانتینرهای تب سکه / قلب
@onready var coin_currency_container: HBoxContainer = $SectionMenu/GemandcoinTab/Control/VBoxContainer3/VBoxContainer/HBoxContainer
@onready var gem_currency_container: HBoxContainer = $SectionMenu/GemandcoinTab/Control/VBoxContainer3/VBoxContainer2/HBoxContainer
@onready var video_button: TextureButton = $SectionMenu/GemandcoinTab/Control2/VBoxContainer/HBoxContainer/VideoButton
@onready var code_button: TextureButton = $SectionMenu/GemandcoinTab/Control2/VBoxContainer/HBoxContainer/CodeButton

const GIFT_CODE_DIALOG_SCENE := preload("res://secense/gift_code_dialog.tscn")

# صحنه‌ها
@export var shop_card_scene: PackedScene = preload("res://secense/shop_card.tscn")
@export var shop_character_card_scene: PackedScene = preload("res://secense/ShopCharacterCard.tscn")
@export var shop_weapon_card_scene: PackedScene = preload("res://secense/shop_card.tscn")

# مقادیر ثابت
const ACTIVE_COLOR: Color = Color("e74c3c")
const INACTIVE_COLOR: Color = Color("ffffff")

const BG_COLOR_RARE: Color = Color("004488")
const BG_COLOR_EPIC: Color = Color("5500aa")
const BG_COLOR_LEGEND: Color = Color("854d0e")
const BG_COLOR_COMMON: Color = Color("1a1a1a")

const BORDER_COLOR_RARE: Color = Color("4dd2ff")
const BORDER_COLOR_EPIC: Color = Color("e066ff")
const BORDER_COLOR_LEGEND: Color = Color("ff9900")
const BORDER_COLOR_COMMON: Color = Color("888888")

var SHOP_URL := Global.SERVER_BASE + "/get_shop"
var BUY_URL := Global.SERVER_BASE + "/buy_item"
var LUCKY_URL := Global.SERVER_BASE + "/lucky_box"

const SECTION_CHARACTERS := "characters"
const SECTION_WEAPONS := "weapons"
const SECTION_WEEKLY := "weekly"
const SECTION_VERY_SPECIAL := "very_special"
const SECTION_CURRENCY := "currency"

const CARD_DEFAULT_MIN_SIZE := Vector2(120, 120)
const CHARACTER_CARD_MIN_SIZE := Vector2(140, 176)
const WEAPON_CARD_MIN_SIZE := Vector2(260, 160)

const GEM_ICON_PATH := "res://assets/ui/gem_icon.png"
const COIN_ICON_PATH := "res://assets/ui/coin_icon.png"

const CHARACTERS_FOLDER_PATH := "res://assets/characters/"
const WEAPONS_FOLDER_PATH := "res://assets/items/"
const CURRENCY_ASSETS_FOLDER_PATH := "res://assets/"
const CURRENCY_ART_FOLDER_PATH := "res://assets/ui/Arz/"

const CURRENCY_BTN_HOVER_SCALE := Vector2(1.07, 1.07)
const CURRENCY_BTN_NORMAL_SCALE := Vector2(1.0, 1.0)
const CURRENCY_BTN_DOWN_SCALE := Vector2(0.90, 0.90)

var buttons: Array[Button] = []
var tabs: Array[Control] = []
var current_tab_index: int = 0

var character_container: Node = null
var weapon_container: Node = null

var selected_character_data: Dictionary = {}
var selected_weapon_data: Dictionary = {}

var _buy_in_flight: bool = false
var _pending_buy_item: Dictionary = {}

# --- C13 پیشگیری از خطا: تأییدِ خرج کردنِ قلب (ارزِ ویژه) ---
## خریدِ قلبی از این مبلغ به بالا یک پنجره‌ی تأیید دارد؛ بسته‌های کوچکِ سکه نه
const GEM_CONFIRM_MIN := 50
## C13: کارت‌های ویترین با یک لمس روی نوارِ قیمت خرید می‌زنند؛ خریدِ سکه‌ایِ
## از این مبلغ به بالا (کاراکتر/اسلحه، معمولاً چند هزار) هم یک بار تأیید می‌خواهد
const COIN_CONFIRM_MIN := 1000
## یک پنجره‌ی تأیید در هر لحظه — لمسِ دوباره پنجره‌ی دوم باز نمی‌کند
var _confirm_open := false

# --- C11 انتخاب معنادار: مقایسه با آیتمِ تجهیزشده روی یک مقیاسِ مشترک ---
## قبلاً هر آیتم نوارش را روی سقفِ خودش (max_level × 10) می‌کشید؛ AK با ۶۰/۸۰
## از AWM با ۶۸/۱۰۰ پرتر دیده می‌شد. حالا همه روی یک خط‌کش‌اند.
const STAT_SCALE := 100.0
const COL_BETTER := Color(0.3, 0.86, 0.42)
const COL_WORSE := Color(1.0, 0.32, 0.32)
const COL_REF := Color(1.0, 0.8, 0.26)
## همه‌ی آیتم‌های کاتالوگ (برای پیدا کردنِ آمارِ آیتمِ تجهیزشده)
var _catalog_items: Array = []


func _ready() -> void:
	print("--- 🔍 شروع آماده‌سازی صحنه فروشگاه ---")

	add_child(shop_http_request)
	add_child(buy_http_request)

	if not buy_http_request.request_completed.is_connected(_on_buy_response):
		buy_http_request.request_completed.connect(_on_buy_response)

	if not Global.inventory_updated.is_connected(_refresh_ownership_ui):
		Global.inventory_updated.connect(_refresh_ownership_ui)

	if not Global.open_shop_tab_requested.is_connected(_on_shop_tab_requested):
		Global.open_shop_tab_requested.connect(_on_shop_tab_requested)

	if not shop_http_request.request_completed.is_connected(_on_shop_data_received):
		shop_http_request.request_completed.connect(_on_shop_data_received)

	if cs_buy_button and not cs_buy_button.pressed.is_connected(_on_card_show_buy_pressed):
		cs_buy_button.pressed.connect(_on_card_show_buy_pressed)

	if ws_buy_button and not ws_buy_button.pressed.is_connected(_on_weapon_buy_pressed):
		ws_buy_button.pressed.connect(_on_weapon_buy_pressed)

	if characters_tab:
		character_container = characters_tab.find_child("CharacterGrid", true, false)
		if character_container:
			_disable_horizontal_scroll(character_container)
			_make_grid_responsive(character_container, CHARACTER_CARD_MIN_SIZE.x)
		else:
			print("⚠️ CharacterGrid درون تب کاراکترها پیدا نشد!")

	if weapons_tab:
		weapon_container = weapons_tab.find_child("WeaponGrid", true, false)
		if weapon_container:
			_disable_horizontal_scroll(weapon_container)
			_make_grid_responsive(weapon_container, WEAPON_CARD_MIN_SIZE.x)
		else:
			print("⚠️ WeaponGrid درون تب تفنگ‌ها پیدا نشد!")

	_connect_existing_currency_cards(coin_currency_container)
	_connect_existing_currency_cards(gem_currency_container)
	_setup_currency_buy_button_animations()
	_setup_reward_buttons()
	_setup_lucky_box()

	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()

	fetch_shop_data()
	_setup_tab_buttons()


# ==========================================================
# ناحیه‌ی امن
# ==========================================================

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
		maxf(0.0, float(win_pos.y + win_size.y - safe.end.y)) * k.y
	)


func _apply_safe_area() -> void:
	var ins := _safe_insets()

	var tabs_row := $AllAboveButtons/AboveButtons as Control
	if tabs_row:
		tabs_row.offset_left = 14.0 + ins.x
		tabs_row.offset_right = -(14.0 + ins.z)

	var section := $SectionMenu as Control
	if section:
		section.offset_left = 23.0 + ins.x
		section.offset_right = -(25.0 + ins.z)
		section.offset_bottom = -(34.0 + ins.w)

	var home := $HomeButton as Control
	if home:
		home.offset_left = -(80.0 + ins.z)
		home.offset_right = -ins.z
		home.offset_top = -(80.0 + ins.w)
		home.offset_bottom = -ins.w


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	_go_back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _go_back() -> void:
	# پنجره‌ی تأیید/جایزه باز است: Back فقط همان را می‌بندد، نه فروشگاه را
	if _close_open_modal():
		return
	var dialog := get_node_or_null("GiftCodeDialog")
	if dialog:
		dialog.queue_free()
		return
	_on_home_button_pressed()


## پنجره‌ی مودال (MenuUI.confirm) یا جایزه باز است؟ اگر بله می‌بندد و true.
## پنجره‌ای که در حالِ بسته شدن است هم حساب می‌شود، چون Back هم ui_cancel
## می‌فرستد هم notification — یکی می‌بنددش، دومی نباید از فروشگاه بیرون ببرد.
func _close_open_modal() -> bool:
	if is_instance_valid(RewardPopup._active):
		return true
	for node in get_tree().root.get_children():
		if node is MenuUI.ModalSheet:
			(node as MenuUI.ModalSheet).dismiss()
			return true
	return false


func _make_grid_responsive(grid: Node, card_width: float) -> void:
	var g := grid as GridContainer
	if not g:
		return

	var scroll: ScrollContainer = null
	var current: Node = g.get_parent()
	while current:
		if current is ScrollContainer:
			scroll = current
			break
		current = current.get_parent()

	if not scroll:
		return

	var apply := func() -> void:
		var gap: float = float(g.get_theme_constant("h_separation"))
		var usable: float = scroll.size.x - 14.0
		g.columns = clampi(int(floor((usable + gap) / (card_width + gap))), 1, 8)

	scroll.resized.connect(apply)
	apply.call_deferred()


func _disable_horizontal_scroll(node: Node) -> void:
	if not node:
		return

	var current: Node = node.get_parent()
	while current:
		if current is ScrollContainer:
			current.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			break
		current = current.get_parent()


func _center_pivot(btn: Control) -> void:
	btn.pivot_offset = btn.size / 2.0


func _setup_tab_buttons() -> void:
	buttons = [btn_special, btn_characters, btn_weapons, btn_currencies]
	tabs = [special_tab, characters_tab, weapons_tab, currencies_tab]

	for i in range(buttons.size()):
		var btn := buttons[i]
		if btn:
			_center_pivot(btn)
			btn.resized.connect(_center_pivot.bind(btn))
			btn.focus_mode = Control.FOCUS_NONE
			btn.pressed.connect(_on_tab_button_pressed.bind(i))
			btn.button_down.connect(_on_button_down.bind(btn))
			btn.button_up.connect(_on_button_up.bind(btn))

	var initial_tab := 0
	if Global.requested_shop_tab >= 0 and Global.requested_shop_tab < tabs.size():
		initial_tab = Global.requested_shop_tab
		Global.requested_shop_tab = -1

	switch_tab(initial_tab, false)


func _on_shop_tab_requested(tab_index: int) -> void:
	if tabs.is_empty():
		return
	if tab_index >= 0 and tab_index < tabs.size():
		switch_tab(tab_index, true)


func switch_tab(target_index: int, _animate: bool = true) -> void:
	current_tab_index = target_index

	for i in range(buttons.size()):
		var btn := buttons[i]
		var tab := tabs[i]

		if i == target_index:
			if tab:
				tab.visible = true
			if btn:
				var tween_color := create_tween().set_parallel(true)
				tween_color.tween_property(btn, "self_modulate", ACTIVE_COLOR, 0.15)
				create_tween().tween_property(btn, "scale", Vector2(1.05, 1.05), 0.15)
		else:
			if tab:
				tab.visible = false
			if btn:
				var tween_color := create_tween().set_parallel(true)
				tween_color.tween_property(btn, "self_modulate", INACTIVE_COLOR, 0.15)
				create_tween().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15)


func _on_tab_button_pressed(index: int) -> void:
	if index == current_tab_index:
		return

	LocalSettings.vibrate(20)

	switch_tab(index, true)


func _on_button_down(btn: Button) -> void:
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.08)


func _on_button_up(btn: Button) -> void:
	var target_scale := Vector2(1.05, 1.05) if buttons.find(btn) == current_tab_index else Vector2(1.0, 1.0)
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(btn, "scale", target_scale, 0.25)


# ==========================================================
# دریافت اطلاعات فروشگاه
# ==========================================================

func fetch_shop_data() -> void:
	var err := shop_http_request.request(SHOP_URL, Global.auth_headers())
	if err != OK:
		print("❌ خطا در ارسال درخواست HTTP فروشگاه:", err)


func _on_shop_data_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return

	var raw_data = _normalize_data(json.data)
	var items_list: Array = []

	if typeof(raw_data) == TYPE_ARRAY:
		items_list = raw_data
	elif typeof(raw_data) == TYPE_DICTIONARY:
		if raw_data.has("items") and typeof(raw_data["items"]) == TYPE_ARRAY:
			items_list = raw_data["items"]
		if raw_data.has("suggest_up") and typeof(raw_data["suggest_up"]) == TYPE_DICTIONARY:
			_setup_suggest_up(raw_data["suggest_up"])

	render_shop_sections(items_list)


func render_shop_sections(items: Array) -> void:
	_catalog_items = items
	_apply_weekly_deadline(items)
	clear_container(weekly_container)
	clear_container(special_container)
	clear_container(character_container)
	clear_container(weapon_container)

	var first_character: Dictionary = {}
	var first_weapon: Dictionary = {}
	var suggest_up_filled := false

	for item in items:
		var section: String = str(item.get("section", ""))

		if section == SECTION_CHARACTERS and first_character.is_empty():
			first_character = item
		elif section == SECTION_WEAPONS and first_weapon.is_empty():
			first_weapon = item

		if not suggest_up_filled and _get_featured_section(item) == SECTION_VERY_SPECIAL:
			_setup_suggest_up(item)
			suggest_up_filled = true

		_render_single_item(item)

	_render_currency_sections(items)

	if not first_character.is_empty():
		display_selected_character(first_character)

	if not first_weapon.is_empty():
		update_weapon_card_show(first_weapon)


## E3: «X روز تا اتمام» فقط وقتی دیده می‌شود که سرور واقعاً پایانِ ویترین را
## بفرستد. قبلاً یک «۷» ثابت در صحنه بود که هیچ‌وقت کم نمی‌شد — تایمرِ جعلی.
func _apply_weekly_deadline(items: Array) -> void:
	var days_label := get_node_or_null("SectionMenu/SpecialTab/SuggestSec/Label") as Label
	var caption := get_node_or_null("SectionMenu/SpecialTab/SuggestSec/Label2") as Label
	var end_unix := 0
	for it in items:
		if typeof(it) != TYPE_DICTIONARY or _get_featured_section(it) != SECTION_WEEKLY:
			continue
		for key in ["featured_ends_at", "ends_at", "expires_at", "end_time"]:
			var v = it.get(key, null)
			if v == null:
				continue
			var t := 0
			if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
				t = int(v)
			else:
				t = int(Time.get_unix_time_from_datetime_string(str(v).substr(0, 19)))
			if t > 0 and (end_unix == 0 or t < end_unix):
				end_unix = t
	var left := end_unix - int(Time.get_unix_time_from_system())
	var show := end_unix > 0 and left > 0
	if days_label:
		days_label.visible = show
	if caption:
		caption.visible = show
	if not show or days_label == null or caption == null:
		return
	if left >= 86400:
		days_label.text = MissionArt.fa_number(int(ceil(left / 86400.0)))
		caption.text = " روز تا اتمام"
	else:
		days_label.text = MissionArt.fa_number(maxi(1, int(ceil(left / 3600.0))))
		caption.text = " ساعت تا اتمام"


func _setup_suggest_up(item: Dictionary) -> void:
	if suggest_name_label:
		suggest_name_label.text = str(item.get("name", "پیشنهاد ویژه"))

	if suggest_item_img:
		suggest_item_img.texture = _get_character_texture(item)

	var orig_price: int = int(item.get("original_price", item.get("price", 0)))
	var final_price: int = int(item.get("final_price", item.get("price", orig_price)))
	if final_price <= 0:
		final_price = orig_price

	var discounted: bool = orig_price > 0 and final_price < orig_price

	if suggest_first_amount:
		suggest_first_amount.text = _struck(MissionArt.fa_grouped(orig_price)) if discounted else ""
		suggest_first_amount.visible = discounted

	if suggest_last_amount:
		suggest_last_amount.text = MissionArt.fa_grouped(final_price)

	if suggest_percent_label:
		var discount: int = int(round((1.0 - float(final_price) / float(orig_price)) * 100.0)) if discounted else 0
		suggest_percent_label.text = ("٪" + MissionArt.fa_number(discount)) if discounted else ""

	var percent_bg := suggest_percent_label.get_parent() as Control if suggest_percent_label else null
	if percent_bg:
		percent_bg.visible = discounted

	if suggest_buy_button:
		suggest_buy_button.set_meta("item_data", item)
		suggest_buy_button.focus_mode = Control.FOCUS_NONE
		if not suggest_buy_button.has_meta("offer_connected"):
			suggest_buy_button.pressed.connect(_on_gem_offer_pressed.bind(suggest_buy_button))
			UIFx.bind_press_feedback(suggest_buy_button)
			suggest_buy_button.set_meta("offer_connected", true)

	_refresh_suggest_up_ownership()


func _refresh_suggest_up_ownership() -> void:
	if not suggest_buy_button:
		return

	var item: Dictionary = suggest_buy_button.get_meta("item_data", {})
	if item.is_empty():
		return

	var category: String = _resolve_purchase_category(item)
	if category != "character" and category != "weapon":
		return

	var owned: bool = Global.owns_item(str(item.get("item_id", "")).strip_edges(), category)
	suggest_buy_button.disabled = owned
	suggest_buy_button.modulate = Color(0.78, 0.78, 0.78, 1.0) if owned else Color.WHITE


func _get_featured_section(item: Dictionary) -> String:
	var featured: String = str(item.get("featured_section", "")).strip_edges()
	if not featured.is_empty():
		return featured

	var section: String = str(item.get("section", "")).strip_edges()
	if section == SECTION_WEEKLY or section == SECTION_VERY_SPECIAL:
		return section

	return ""


func _render_single_item(item: Dictionary) -> void:
	var section: String = str(item.get("section", ""))

	match section:
		SECTION_CHARACTERS:
			if character_container and shop_character_card_scene:
				var card := instantiate_character_card()
				character_container.add_child(card)
				setup_card_data(card, item)
		SECTION_WEAPONS:
			if weapon_container and shop_weapon_card_scene:
				var card := instantiate_weapon_card()
				weapon_container.add_child(card)
				setup_card_data(card, item)

	_render_featured_item(item)


func _render_featured_item(item: Dictionary) -> void:
	var featured: String = _get_featured_section(item)
	if featured.is_empty():
		return

	var target: Node = null
	match featured:
		SECTION_WEEKLY:
			target = weekly_container
		SECTION_VERY_SPECIAL:
			target = special_container

	if target and shop_card_scene:
		var card := instantiate_card()
		target.add_child(card)
		setup_card_data(card, item)


func instantiate_card() -> Control:
	var card: Control = shop_card_scene.instantiate()
	_lock_card_size(card, CARD_DEFAULT_MIN_SIZE)
	return card


func instantiate_character_card() -> Control:
	var card: Control = shop_character_card_scene.instantiate()
	_lock_card_size(card, CHARACTER_CARD_MIN_SIZE)
	return card


func instantiate_weapon_card() -> Control:
	var card: Control = shop_weapon_card_scene.instantiate()
	_lock_card_size(card, WEAPON_CARD_MIN_SIZE)
	return card


func _lock_card_size(card: Control, size: Vector2) -> void:
	card.custom_minimum_size = size
	# کارتِ اسلحه anchorهای نابرابر دارد و ستِ size رویش فقط هشدار می‌داد
	if is_equal_approx(card.anchor_left, card.anchor_right) and is_equal_approx(card.anchor_top, card.anchor_bottom):
		card.size = size
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func setup_card_data(card: Node, item: Dictionary) -> void:
	if card.has_method("setup_card"):
		card.setup_card(item)

	card.set_meta("shop_item", item)
	_apply_card_ownership(card)

	if card.has_signal("buy_requested"):
		if not card.buy_requested.is_connected(_on_card_buy_requested):
			card.buy_requested.connect(_on_card_buy_requested)

	if card.has_signal("card_clicked"):
		var section: String = str(item.get("section", ""))
		if section == SECTION_WEAPONS:
			if not card.card_clicked.is_connected(update_weapon_card_show):
				card.card_clicked.connect(update_weapon_card_show)
		else:
			if not card.card_clicked.is_connected(display_selected_character):
				card.card_clicked.connect(display_selected_character)


# ==========================================================
# دریافت عکس آیتم
# ==========================================================

func _get_character_texture(item: Dictionary) -> Texture2D:
	var item_id: String = str(item.get("item_id", item.get("id", ""))).strip_edges()
	var section: String = str(item.get("section", "")).strip_edges()
	var category: String = str(item.get("category", "")).strip_edges()

	if section.is_empty():
		match category:
			"weapon":
				section = SECTION_WEAPONS
			"coin_pack", "gem_pack":
				section = SECTION_CURRENCY
			_:
				section = SECTION_CHARACTERS

	if not item_id.is_empty():
		var full_path: String = ""

		if section == SECTION_WEAPONS:
			full_path = WEAPONS_FOLDER_PATH + item_id + ".png"
		elif section == SECTION_CURRENCY:
			full_path = CURRENCY_ASSETS_FOLDER_PATH + item_id + ".png"
		else:
			full_path = CHARACTERS_FOLDER_PATH + item_id + ".png"

		if ResourceLoader.exists(full_path):
			return load(full_path) as Texture2D
		else:
			print("⚠️ عکس آیتم پیدا نشد در مسیر: ", full_path)
	else:
		print("⚠️ شناسه item_id از سرور دریافت نشد!")

	var image_path: String = str(item.get("image_path", item.get("icon_path", ""))).strip_edges()
	if image_path != "" and ResourceLoader.exists(image_path):
		return load(image_path) as Texture2D

	return null


# ==========================================================
# تم Rarity
# ==========================================================

func _apply_rarity_style(rarity_str: String, bg_rect: TextureRect, ref_rect: ReferenceRect, rarity_icon: TextureRect) -> void:
	var rarity: String = rarity_str.to_lower()
	var bg_color: Color = BG_COLOR_COMMON
	var bright_color: Color = BORDER_COLOR_COMMON

	match rarity:
		"rare":
			bg_color = BG_COLOR_RARE
			bright_color = BORDER_COLOR_RARE
		"epic":
			bg_color = BG_COLOR_EPIC
			bright_color = BORDER_COLOR_EPIC
		"legend", "legendary":
			bg_color = BG_COLOR_LEGEND
			bright_color = BORDER_COLOR_LEGEND
		_:
			bg_color = BG_COLOR_COMMON
			bright_color = BORDER_COLOR_COMMON

	if ref_rect:
		ref_rect.border_color = bright_color

	if rarity_icon:
		rarity_icon.modulate = bright_color
		_apply_icon_shadow(rarity_icon)

	if bg_rect:
		if bg_rect.texture is GradientTexture2D:
			var grad_tex := bg_rect.texture.duplicate() as GradientTexture2D
			if grad_tex.gradient:
				grad_tex.gradient = grad_tex.gradient.duplicate()
				grad_tex.gradient.set_color(0, bg_color)
			bg_rect.texture = grad_tex
		else:
			bg_rect.modulate = bg_color


func _apply_icon_shadow(icon: TextureRect) -> void:
	if not icon:
		return

	var shadow := icon.get_node_or_null("RarityShadow") as TextureRect
	if not shadow:
		shadow = TextureRect.new()
		shadow.name = "RarityShadow"
		shadow.show_behind_parent = true
		shadow.expand_mode = icon.expand_mode
		shadow.stretch_mode = icon.stretch_mode
		shadow.position = Vector2(3, 3)
		shadow.modulate = Color(0, 0, 0, 0.75)
		icon.add_child(shadow)

	shadow.texture = icon.texture
	shadow.size = icon.size


# ==========================================================
# نمایش کاراکتر
# ==========================================================

func display_selected_character(item: Dictionary) -> void:
	selected_character_data = item

	if cs_name_label:
		cs_name_label.text = str(item.get("name", item.get("Name", "آیتم")))

	if cs_character_image:
		cs_character_image.texture = _get_character_texture(item)

	var rarity: String = str(item.get("rarity", item.get("rarety", "rare")))
	_apply_rarity_style(rarity, cs_background, cs_reference_rect, cs_rarity_icon)

	var price: int = int(item.get("final_price", item.get("original_price", item.get("price", item.get("cost", 0)))))
	var cost_type: String = str(item.get("cost_type", item.get("currency", "coins"))).to_lower()

	if cs_buy_price_label:
		cs_buy_price_label.text = str(price)

	if cs_buy_type_icon:
		if cost_type in ["gems", "gem"]:
			cs_buy_type_icon.texture = load(GEM_ICON_PATH)
		else:
			cs_buy_type_icon.texture = load(COIN_ICON_PATH)

	var max_level: int = int(item.get("max_level", 10))
	if max_level <= 0:
		max_level = 10

	var max_stat_value: int = max_level * 10
	var stats: Dictionary = {}
	var raw_stats = item.get("stats", {})

	if typeof(raw_stats) == TYPE_DICTIONARY:
		stats = raw_stats
	elif typeof(raw_stats) == TYPE_STRING:
		var json := JSON.new()
		if json.parse(raw_stats) == OK and typeof(json.data) == TYPE_DICTIONARY:
			stats = json.data

	var move_spd: int = int(stats.get("move_speed", item.get("move_speed", 0)))
	var accuracy: int = int(stats.get("aim_accuracy", item.get("aim_accuracy", 0)))
	var hand_spd: int = int(stats.get("hand_speed", item.get("hand_speed", 0)))
	var throwing: int = int(stats.get("throw_range", item.get("throw_range", 0)))
	var health: int = int(stats.get("health", item.get("health", 0)))
	var regen: int = int(stats.get("health_regen", item.get("health_regen", 0)))

	var char_id: String = str(item.get("item_id", item.get("id", ""))).strip_edges()
	# C11: کنارِ هر نوار، اختلاف با کاراکترِ فعلی و خطِ طلاییِ مقدارِ او
	var ref := _equipped_stats("character", char_id)
	_update_stat_row(cs_stat_movement, move_spd, max_stat_value, ref.get("move_speed", -1))
	_update_stat_row(cs_stat_accuracy, accuracy, max_stat_value, ref.get("aim_accuracy", -1))
	_update_stat_row(cs_stat_hand_speed, hand_spd, max_stat_value, ref.get("hand_speed", -1))
	_update_stat_row(cs_stat_throwing, throwing, max_stat_value, ref.get("throw_range", -1))
	_update_stat_row(cs_stat_health, health, max_stat_value, ref.get("health", -1))
	_update_stat_row(cs_stat_regen, regen, max_stat_value, ref.get("health_regen", -1))
	_set_compare_caption(cs_stat_movement, "character", char_id)

	_set_buy_button_owned(cs_buy_button, Global.owns_item(char_id, "character"))


func _update_stat_row(container: HBoxContainer, value: int, _max_value: int, ref_value = -1) -> void:
	_update_weapon_stat_bar(container, float(value), STAT_SCALE, float(ref_value))


# ==========================================================
# نمایش سلاح
# ==========================================================

func update_weapon_card_show(data: Dictionary) -> void:
	selected_weapon_data = data

	if ws_name_label:
		ws_name_label.text = str(data.get("name", "سلاح"))

	if ws_weapon_image:
		ws_weapon_image.texture = _get_character_texture(data)

	if ws_stat_fire_rate and ws_stat_fire_rate.has_node("TitleLabel"):
		ws_stat_fire_rate.get_node("TitleLabel").text = "سرعت"

	var rarity: String = str(data.get("rarity", data.get("rarety", "rare")))
	_apply_rarity_style(rarity, ws_background, ws_reference_rect, ws_rarity_icon)

	var price: int = int(data.get("final_price", data.get("original_price", data.get("price", data.get("cost", 0)))))
	var cost_type: String = str(data.get("cost_type", data.get("currency", "coins"))).to_lower()

	if ws_buy_price_label:
		ws_buy_price_label.text = str(price)

	if ws_buy_type_icon:
		if cost_type in ["gems", "gem"]:
			ws_buy_type_icon.texture = load(GEM_ICON_PATH)
		else:
			ws_buy_type_icon.texture = load(COIN_ICON_PATH)

	var stats: Dictionary = {}
	var raw_stats = data.get("stats", {})

	if typeof(raw_stats) == TYPE_DICTIONARY:
		stats = raw_stats
	elif typeof(raw_stats) == TYPE_STRING:
		var json := JSON.new()
		if json.parse(raw_stats) == OK and typeof(json.data) == TYPE_DICTIONARY:
			stats = json.data

	var fire_rate_val: float = float(stats.get("fire_rate", data.get("fire_rate", stats.get("speed", data.get("speed", 0)))))

	var weapon_id: String = str(data.get("item_id", data.get("id", ""))).strip_edges()
	# C11: مقایسه با اسلحه‌ی فعلی، روی مقیاسِ مشترکِ STAT_SCALE
	var ref := _equipped_stats("weapon", weapon_id)
	_update_weapon_stat_bar(ws_stat_power, float(stats.get("power", data.get("power", 0))), STAT_SCALE, float(ref.get("power", -1)))
	_update_weapon_stat_bar(ws_stat_accuracy, float(stats.get("accuracy", data.get("accuracy", 0))), STAT_SCALE, float(ref.get("accuracy", -1)))
	_update_weapon_stat_bar(ws_stat_range, float(stats.get("range", data.get("range", 0))), STAT_SCALE, float(ref.get("range", -1)))
	_update_weapon_stat_bar(ws_stat_fire_rate, fire_rate_val, STAT_SCALE, float(ref.get("fire_rate", ref.get("speed", -1))))
	_update_weapon_stat_bar(ws_stat_control, float(stats.get("control", data.get("control", 0))), STAT_SCALE, float(ref.get("control", -1)))
	_set_compare_caption(ws_stat_power, "weapon", weapon_id)

	_set_buy_button_owned(ws_buy_button, Global.owns_item(weapon_id, "weapon"))


## ref_value < 0 یعنی مقایسه‌ای در کار نیست (همین آیتم تجهیز است، یا آمارش نیامده)
func _update_weapon_stat_bar(container: HBoxContainer, value: float, max_value: float = 100.0, ref_value: float = -1.0) -> void:
	if not container:
		return

	var value_label: Label = container.get_node_or_null("ValueLabel")
	if value_label:
		value_label.text = str(int(value))

	# اختلاف با آیتمِ فعلی: سبز بهتر، قرمز ضعیف‌تر (همیشه با علامتِ + / − هم)
	var delta_label := container.get_node_or_null("DeltaLabel") as Label
	if delta_label == null:
		delta_label = Label.new()
		delta_label.name = "DeltaLabel"
		delta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		delta_label.custom_minimum_size.x = 34.0
		delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		delta_label.add_theme_font_override("font", MenuUI.FONT_NUM)
		delta_label.add_theme_font_size_override("font_size", 15)
		container.add_child(delta_label)
		container.move_child(delta_label, 0)
	var delta := int(round(value - ref_value))
	delta_label.visible = ref_value >= 0.0 and delta != 0
	if delta_label.visible:
		delta_label.text = ("+%d" % delta) if delta > 0 else ("−%d" % -delta)
		delta_label.add_theme_color_override("font_color", COL_BETTER if delta > 0 else COL_WORSE)

	var bg_rect: ColorRect = container.get_node_or_null("ColorRect")
	if bg_rect:
		var fill_rect: ColorRect = bg_rect.get_node_or_null("ColorRect")
		if fill_rect:
			var ratio: float = clamp(value / max_value, 0.0, 1.0) if max_value > 0 else 0.0
			fill_rect.anchor_right = ratio
			fill_rect.offset_right = 0.0
		# خطِ طلاییِ مقدارِ آیتمِ فعلی روی همان نوار
		var mark := bg_rect.get_node_or_null("RefMark") as ColorRect
		if mark == null:
			mark = ColorRect.new()
			mark.name = "RefMark"
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mark.color = COL_REF
			mark.anchor_top = 0.0
			mark.anchor_bottom = 1.0
			mark.offset_top = -3.0
			mark.offset_bottom = 3.0
			bg_rect.add_child(mark)
		mark.visible = ref_value >= 0.0
		if mark.visible:
			var r: float = clamp(ref_value / max_value, 0.0, 1.0) if max_value > 0 else 0.0
			mark.anchor_left = r
			mark.anchor_right = r
			mark.offset_left = -1.5
			mark.offset_right = 1.5


## آمارِ آیتمِ تجهیزشده‌ی همین دسته — خالی اگر همین آیتم تجهیز است یا پیدا نشد
func _equipped_stats(category: String, shown_id: String) -> Dictionary:
	var equipped := str(Global.current_weapon if category == "weapon" else Global.current_character)
	if equipped.is_empty() or equipped == shown_id:
		return {}
	for it in _catalog_items:
		if typeof(it) == TYPE_DICTIONARY and str(it.get("item_id", "")).strip_edges() == equipped:
			var raw = it.get("stats", {})
			if typeof(raw) == TYPE_STRING:
				raw = JSON.parse_string(raw)
			return raw if typeof(raw) == TYPE_DICTIONARY else {}
	return {}


func _equipped_name(category: String) -> String:
	var equipped := str(Global.current_weapon if category == "weapon" else Global.current_character)
	for it in _catalog_items:
		if typeof(it) == TYPE_DICTIONARY and str(it.get("item_id", "")).strip_edges() == equipped:
			return str(it.get("name", "")).strip_edges()
	return MenuUI.weapon_name(equipped) if category == "weapon" else ""


## راهنمای کوچکِ بالای نوارها: «خطِ طلایی: AK-47 (فعلیِ تو)»
func _set_compare_caption(first_row: HBoxContainer, category: String, shown_id: String) -> void:
	if first_row == null or first_row.get_parent() == null:
		return
	var box := first_row.get_parent() as Control
	var host := box.get_parent() as Control
	if box == null or host == null:
		return
	# روی پنل و درست بالای نوارها، نه داخلِ VBox — وگرنه ردیفِ آخر را روی
	# دکمه‌ی خرید هل می‌دهد (روی 20:9 جا تنگ است)
	var cap := host.get_node_or_null("CompareCaption") as Label
	if cap == null:
		cap = MenuUI.label("", 14, COL_REF)
		cap.name = "CompareCaption"
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		host.add_child(cap)
		var place := func() -> void:
			cap.size = Vector2(box.size.x, 20.0)
			cap.position = box.position - Vector2(0, 22.0)
		box.resized.connect(place)
		box.item_rect_changed.connect(place)
		place.call_deferred()
	var compare := not _equipped_stats(category, shown_id).is_empty()
	var equipped_name := _equipped_name(category)
	if compare:
		cap.text = ("خطِ طلایی: %s (فعلیِ تو)" % equipped_name) if equipped_name != "" else "خطِ طلایی: انتخابِ فعلیِ تو"
	else:
		cap.text = "همین الان دستِ توست" if Global.is_equipped(shown_id, category) else ""
	cap.visible = cap.text != ""


# ==========================================================
# تب سکه و قلب / جم
# ==========================================================

func _render_currency_sections(items: Array) -> void:
	var coin_items: Array = []
	var gem_items: Array = []

	for item in items:
		if str(item.get("section", "")) != SECTION_CURRENCY:
			continue

		if _get_currency_category(item) == "gem":
			gem_items.append(item)
		else:
			coin_items.append(item)

	coin_items.sort_custom(_compare_currency_amount)
	gem_items.sort_custom(_compare_currency_amount)

	_fill_existing_currency_container(coin_currency_container, coin_items)
	_fill_existing_currency_container(gem_currency_container, gem_items)
	_fill_gem_offers(gem_items)


func _compare_currency_amount(a: Dictionary, b: Dictionary) -> bool:
	return _guess_currency_amount(a) < _guess_currency_amount(b)


func _fill_gem_offers(gem_items: Array) -> void:
	if not gem_offer_container:
		return

	var rows := gem_offer_container.get_children()

	for i in range(rows.size()):
		var row := rows[i] as BaseButton
		if not row:
			continue

		if i >= gem_items.size():
			row.visible = false
			continue

		var item: Dictionary = gem_items[i]
		row.visible = true
		row.set_meta("item_data", item)
		row.focus_mode = Control.FOCUS_NONE

		if not row.has_meta("offer_connected"):
			row.pressed.connect(_on_gem_offer_pressed.bind(row))
			UIFx.bind_press_feedback(row)
			row.set_meta("offer_connected", true)

		var full_price: int = int(item.get("original_price", item.get("price", 0)))
		var final_price: int = int(item.get("final_price", full_price))
		if final_price <= 0:
			final_price = full_price

		var discount: int = int(item.get("discount_percent", 0))
		if discount <= 0 and full_price > 0 and final_price < full_price:
			discount = int(round((1.0 - float(final_price) / float(full_price)) * 100.0))

		var discounted: bool = discount > 0 and final_price < full_price

		var count_label := row.get_node_or_null("CountLabel") as Label
		if count_label:
			count_label.text = MissionArt.fa_grouped(_guess_currency_amount(item))

		var bonus_label := row.get_node_or_null("BonusLabel") as Label
		if bonus_label:
			var bonus: int = _currency_bonus(item)
			bonus_label.text = ("+" + MissionArt.fa_grouped(bonus)) if bonus > 0 else ""

		var old_price_label := row.get_node_or_null("OldPriceLabel") as RichTextLabel
		if old_price_label:
			old_price_label.text = _struck(_format_toman(full_price, false)) if discounted else ""
			old_price_label.visible = discounted

		var price_label := row.get_node_or_null("PriceLabel") as Label
		if price_label:
			price_label.text = _format_toman(final_price)


func _struck(text: String) -> String:
	return "[center][s]%s[/s][/center]" % text


# ==========================================================
# بسته شانس
# ==========================================================

const LUCKY_FALLBACK_PRICE := 200
## وزنِ هر رده در قرعه — کپیِ gun_game_server/lucky_box.go (luckyBoxWeight).
## اگر سرور برای هر جایزه "weight" بفرستد، همان استفاده می‌شود.
const LUCKY_WEIGHTS := {"rare": 3, "epic": 1}
const LUCKY_RARITY_NAMES := {"rare": "کمیاب", "epic": "حماسی", "legend": "افسانه‌ای", "common": "معمولی"}
## جایزه‌های ممکن (ویترینِ GET /lucky_box)
var _lucky_pool: Array = []
var _lucky_odds_label: Label = null
var _lucky_price: int = LUCKY_FALLBACK_PRICE
var _lucky_in_flight: bool = false
var _lucky_info_request: HTTPRequest = null
var _lucky_open_request: HTTPRequest = null


func _setup_lucky_box() -> void:
	if not lucky_button:
		print("⚠️ دکمه‌ی بسته‌ی شانسی پیدا نشد!")
		return

	lucky_button.focus_mode = Control.FOCUS_NONE
	lucky_button.pressed.connect(_on_lucky_box_pressed)

	if lucky_panel:
		lucky_button.button_down.connect(UIFx.press_scale.bind(lucky_panel, true))
		lucky_button.button_up.connect(UIFx.press_scale.bind(lucky_panel, false))

	_show_lucky_price(_lucky_price)

	_lucky_info_request = HTTPRequest.new()
	add_child(_lucky_info_request)
	_lucky_info_request.request_completed.connect(_on_lucky_info_received)
	_lucky_info_request.request(LUCKY_URL, Global.auth_headers())

	_lucky_open_request = HTTPRequest.new()
	add_child(_lucky_open_request)
	_lucky_open_request.request_completed.connect(_on_lucky_box_opened)


func set_lucky_pool(pool: Array) -> void:
	_lucky_pool = pool
	_refresh_lucky_odds()


## E3: احتمالِ هر رده بینِ جایزه‌هایی که بازیکن هنوز ندارد (سرور تکراری نمی‌دهد)
## → {rarity: {"p": 0..1, "n": تعداد}}
func _lucky_odds() -> Dictionary:
	var weights := {}
	var counts := {}
	var total := 0.0
	for entry in _lucky_pool:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id := str(entry.get("item_id", ""))
		var cat := str(entry.get("category", ""))
		if Global.owns_item(id, cat):
			continue
		var rarity := str(entry.get("rarity", "")).to_lower()
		var w := float(entry.get("weight", LUCKY_WEIGHTS.get(rarity, 0)))
		if w <= 0.0:
			continue
		weights[rarity] = float(weights.get(rarity, 0.0)) + w
		counts[rarity] = int(counts.get(rarity, 0)) + 1
		total += w
	var out := {}
	if total <= 0.0:
		return out
	for r in weights:
		out[r] = {"p": float(weights[r]) / total, "n": int(counts[r])}
	return out


func _odds_line(odds: Dictionary) -> String:
	var parts: Array[String] = []
	for r in ["legend", "epic", "rare", "common"]:
		if odds.has(r):
			parts.append("%s ٪%s" % [LUCKY_RARITY_NAMES.get(r, r),
				MissionArt.fa_number(int(round(float(odds[r]["p"]) * 100.0)))])
	# جداکننده «|» نه «·» — نقطه‌ی وسط در Lalezar شبیهِ «۰» است و ٪۴۰ · ٪۶۰ گیج می‌کرد
	return "  |  ".join(parts)


func _lucky_odds_body(odds: Dictionary) -> String:
	if odds.is_empty():
		return "یک کاراکتر یا اسلحه‌ی تصادفی (کمیاب یا حماسی) که هنوز نداری.\nتکراری نمی‌دهد."
	var lines: Array[String] = ["احتمالِ هر رده برای تو:"]
	for r in ["legend", "epic", "rare", "common"]:
		if odds.has(r):
			lines.append("• %s: ٪%s (%s آیتم)" % [LUCKY_RARITY_NAMES.get(r, r),
				MissionArt.fa_number(int(round(float(odds[r]["p"]) * 100.0))),
				MissionArt.fa_number(int(odds[r]["n"]))])
	lines.append("تکراری نمی‌دهد؛ افسانه‌ای‌ها داخلِ این بسته نیستند.")
	return "\n".join(lines)


## نوارِ کوچکِ «شانس: حماسی ٪۲۵ · کمیاب ٪۷۵» روی کادرِ بسته — همیشه پیدا
func _refresh_lucky_odds() -> void:
	if lucky_panel == null:
		return
	if _lucky_odds_label == null:
		var pill := PanelContainer.new()
		pill.name = "OddsPill"
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.82)
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(1)
		sb.border_color = Color(1.0, 0.8, 0.26, 0.6)
		sb.content_margin_left = 8.0
		sb.content_margin_right = 8.0
		sb.content_margin_top = 1.0
		sb.content_margin_bottom = 1.0
		pill.add_theme_stylebox_override("panel", sb)
		pill.anchor_left = 0.06
		pill.anchor_right = 0.94
		pill.anchor_top = 0.66
		pill.anchor_bottom = 0.66
		pill.grow_vertical = Control.GROW_DIRECTION_BOTH
		# Lalezar: ارقامِ فارسیِ هم‌تراز (V10)
		_lucky_odds_label = MenuUI.label("", 17, MenuUI.TEXT, true)
		_lucky_odds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pill.add_child(_lucky_odds_label)
		lucky_panel.add_child(pill)
		# دکمه‌ی کلِ کادر روی همه بماند تا لمس همچنان به آن برسد
		if lucky_button:
			lucky_panel.move_child(lucky_button, -1)
	var odds := _lucky_odds()
	var line := _odds_line(odds)
	if line == "" and not _lucky_pool.is_empty():
		line = "همه‌ی جایزه‌ها را داری"
	elif line != "":
		line = "شانس: " + line
	_lucky_odds_label.text = line
	_lucky_odds_label.get_parent().visible = line != ""


func _show_lucky_price(price: int) -> void:
	if lucky_price_label:
		lucky_price_label.text = MissionArt.fa_grouped(price)


func _on_lucky_info_received(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return

	var price := int(json.data.get("price", 0))
	if price > 0:
		_lucky_price = price
		_show_lucky_price(price)
	var pool = json.data.get("pool", [])
	if typeof(pool) == TYPE_ARRAY:
		set_lucky_pool(pool)


func _on_lucky_box_pressed() -> void:
	if _lucky_in_flight or _lucky_open_request == null:
		return

	if Global.my_username.is_empty():
		_show_toast("هنوز وارد حساب نشدی", false)
		return

	if Global.gems < _lucky_price:
		_show_toast("قلب کافی نداری", false)
		Global.request_shop_tab(3)
		return

	# E3 + C13: صندوقِ شانسی — قبل از خرج کردن، احتمالِ دقیقِ هر رده دیده می‌شود
	if _confirm_open:
		return
	var odds := _lucky_odds()
	if not _lucky_pool.is_empty() and odds.is_empty():
		_show_toast("همه‌ی جایزه‌های این بسته را داری", true)
		return
	_confirm_open = true
	MenuUI.confirm(self, "بسته‌ی شانسی", _lucky_odds_body(odds),
		"باز کن — %s قلب" % MissionArt.fa_grouped(_lucky_price),
		func(ok: bool) -> void:
			_confirm_open = false
			if ok:
				_open_lucky_box_now())


func _open_lucky_box_now() -> void:
	if _lucky_in_flight or _lucky_open_request == null:
		return
	_lucky_in_flight = true
	var err := _lucky_open_request.request(
		LUCKY_URL,
		Global.json_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify({"username": Global.my_username})
	)

	if err != OK:
		_lucky_in_flight = false
		_show_toast("ارتباط با سرور برقرار نشد", false)


func _on_lucky_box_opened(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_lucky_in_flight = false

	if result != HTTPRequest.RESULT_SUCCESS:
		_show_toast("ارتباط با سرور برقرار نشد", false)
		return

	var payload: Dictionary = {}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK and typeof(json.data) == TYPE_DICTIONARY:
		payload = json.data

	if code != 200:
		_show_toast(str(payload.get("error", "بسته باز نشد")), false)
		return

	Global.apply_purchase_response(payload)
	_refresh_lucky_odds()

	var prize := {
		"item_id": str(payload.get("item_id", "")),
		"category": str(payload.get("category", "")),
		"section": SECTION_CHARACTERS if str(payload.get("category", "")) == "character" else SECTION_WEAPONS,
	}

	var prize_name := str(payload.get("name", "")).strip_edges()
	if prize_name.is_empty():
		prize_name = str(prize["item_id"])

	LocalSettings.vibrate(35)

	RewardPopup.show_rewards([{
		"texture": _get_character_texture(prize),
		"amount": 0,
		"label": prize_name,
		"tint": _rarity_border_color(str(payload.get("rarity", ""))),
	}], "بسته‌ی شانسی")

	_refresh_ownership_ui()


func _rarity_border_color(rarity: String) -> Color:
	match rarity.to_lower():
		"epic":
			return BORDER_COLOR_EPIC
		"legend", "legendary":
			return BORDER_COLOR_LEGEND
		"rare":
			return BORDER_COLOR_RARE
	return BORDER_COLOR_COMMON


func _on_gem_offer_pressed(row: BaseButton) -> void:
	var item: Dictionary = row.get_meta("item_data", {})
	if not item.is_empty():
		_on_card_buy_requested(item)


func _fill_existing_currency_container(container: HBoxContainer, items: Array) -> void:
	if not container:
		return

	var children := container.get_children()

	for i in range(children.size()):
		var card := children[i] as Control
		if not card:
			continue

		if i < items.size():
			card.visible = true
			_setup_existing_currency_card(card, items[i], i)
		else:
			card.visible = false


func _setup_existing_currency_card(card: Control, item: Dictionary, rank: int = -1) -> void:
	card.set_meta("item_data", item)

	var item_img := card.get_node_or_null("TextureButton") as TextureRect
	var title_label := card.get_node_or_null("HBoxContainer/Label") as Label
	var type_icon := card.get_node_or_null("HBoxContainer/TextureRect") as TextureRect
	var buy_button := card.get_node_or_null("BuyButton") as Button
	var category := _get_currency_category(item)

	if title_label:
		var title := _make_currency_title(item, category)
		if _guess_currency_amount(item) <= 0:
			title = str(item.get("name", item.get("title", ""))).strip_edges()
		title_label.text = title

	if buy_button:
		buy_button.disabled = false
		buy_button.text = _get_currency_price_text(item, category)

	if type_icon:
		if category == "gem":
			type_icon.texture = load(GEM_ICON_PATH)
		else:
			type_icon.texture = load(COIN_ICON_PATH)

	if item_img:
		var texture := _get_currency_texture(item, category, rank)
		if texture:
			item_img.texture = texture


func _connect_existing_currency_cards(container: HBoxContainer) -> void:
	if not container:
		return

	for card in container.get_children():
		var buy_button := card.get_node_or_null("BuyButton") as BaseButton

		if buy_button == null:
			buy_button = card.find_child("BuyButton", true, false) as BaseButton

		if buy_button == null:
			buy_button = card as BaseButton

		if buy_button:
			buy_button.focus_mode = Control.FOCUS_NONE
			buy_button.disabled = false

			if not card.has_meta("buy_connected"):
				buy_button.pressed.connect(_on_existing_currency_buy_pressed.bind(card))
				card.set_meta("buy_connected", true)


func _on_existing_currency_buy_pressed(card: Control) -> void:
	var item: Dictionary = card.get_meta("item_data", {})
	if not item.is_empty():
		_on_card_buy_requested(item)


func _get_currency_category(item: Dictionary) -> String:
	var category := str(item.get("category", item.get("currency_category", item.get("currency_type", item.get("currency", ""))))).to_lower().strip_edges()

	if category in ["gems", "gem", "gem_pack", "قلب", "جم", "heart"]:
		return "gem"

	if category in ["coins", "coin", "coin_pack", "gold", "سکه", "طلا"]:
		return "coin"

	var item_id := str(item.get("item_id", item.get("id", ""))).to_lower()
	var item_name := str(item.get("name", "")).to_lower()

	if item_id.contains("gem") or item_name.contains("gem") or item_name.contains("قلب") or item_name.contains("جم"):
		return "gem"

	if item_id.contains("coin") or item_name.contains("سکه") or item_name.contains("coin"):
		return "coin"

	return "coin"


func _get_currency_texture(item: Dictionary, category: String = "", rank: int = -1) -> Texture2D:
	var image_path := str(item.get("image_path", item.get("icon_path", ""))).strip_edges()
	if image_path != "" and ResourceLoader.exists(image_path):
		return load(image_path) as Texture2D

	if rank >= 0:
		var prefix := "gems" if category == "gem" else "coins"
		var ranked := "%s%s%d.png" % [CURRENCY_ART_FOLDER_PATH, prefix, mini(rank, 3) + 1]
		if ResourceLoader.exists(ranked):
			return load(ranked) as Texture2D

	var item_id := str(item.get("item_id", item.get("id", ""))).strip_edges()
	if item_id.is_empty():
		return null

	var possible_paths: Array = [
		CURRENCY_ART_FOLDER_PATH + item_id + ".png",
		CURRENCY_ASSETS_FOLDER_PATH + item_id + ".png",
		"res://assets/currency/" + item_id + ".png",
		"res://assets/ui/" + item_id + ".png"
	]

	for path in possible_paths:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D

	print("⚠️ تصویر آیتم ارز پیدا نشد: ", item_id)
	return null


func _make_currency_title(item: Dictionary, category: String) -> String:
	var amount := _guess_currency_amount(item) + _currency_bonus(item)

	if amount > 0:
		if category == "gem":
			return MissionArt.fa_grouped(amount) + " قلب"
		return MissionArt.fa_grouped(amount) + " سکه"

	return str(item.get("item_id", "آیتم"))


func _char_to_digit(ch: String) -> String:
	if ch >= "0" and ch <= "9":
		return ch

	match ch:
		"۰", "٠":
			return "0"
		"۱", "١":
			return "1"
		"۲", "٢":
			return "2"
		"۳", "٣":
			return "3"
		"۴", "٤":
			return "4"
		"۵", "٥":
			return "5"
		"۶", "٦":
			return "6"
		"۷", "٧":
			return "7"
		"۸", "٨":
			return "8"
		"۹", "٩":
			return "9"

	return ""


func _extract_first_number(text: String) -> String:
	var out := ""
	var started := false

	for ch in text.strip_edges():
		var d := _char_to_digit(ch)
		if d != "":
			out += d
			started = true
		elif started:
			break

	return out


func _guess_currency_amount(item: Dictionary) -> int:
	var amount := int(item.get("amount", item.get("value", 0)))
	if amount > 0:
		return amount

	var name_text := str(item.get("name", ""))
	var digits := _extract_first_number(name_text)
	if digits != "":
		return int(digits)

	var id_text := str(item.get("item_id", item.get("id", "")))
	digits = _extract_first_number(id_text)
	if digits != "":
		return int(digits)

	return 0


func _get_currency_price_text(item: Dictionary, category: String) -> String:
	var price_text := str(item.get("price_text", "")).strip_edges()
	if not price_text.is_empty():
		return price_text

	var price := int(item.get("original_price", item.get("final_price", item.get("price", item.get("cost", 0)))))
	if price <= 0:
		price = int(item.get("final_price", 0))

	var raw_cost := str(item.get("cost_type", item.get("currency", ""))).to_lower().strip_edges()
	var cost_type := _item_cost_type(item)

	if cost_type == "toman":
		# پول واقعی: باید دقیقاً همان مبلغی باشد که صفحه‌ی پرداختِ مایکت/بازار
		# کم می‌کند (قانونِ مایکت: «قیمت بسته‌ها باید با مبلغ پرداختی برابر باشد»).
		# فروشگاه قیمتِ تخفیف‌خورده (final_price) را می‌گیرد، نه قیمتِ کامل.
		var charged := int(item.get("final_price", 0))
		return _format_toman(charged if charged > 0 else price)

	if cost_type == "gems":
		return MissionArt.fa_grouped(price) + " قلب"

	if raw_cost in ["coins", "coin"]:
		return MissionArt.fa_grouped(price) + " سکه"

	if category == "gem":
		return MissionArt.fa_grouped(price) + " قلب"

	return MissionArt.fa_grouped(price)


func _format_toman(price: int, with_unit: bool = true) -> String:
	var unit := " تومان" if with_unit else ""

	if price <= 0:
		return "۰" + unit

	if price >= 1000 and price % 1000 == 0:
		return MissionArt.fa_grouped(int(price / 1000)) + " هزار" + unit

	if price >= 1000 and price % 500 == 0:
		return MissionArt.fa_grouped(int(price / 1000)) + "٫۵ هزار" + unit

	return MissionArt.fa_grouped(price) + unit


func _currency_bonus(item: Dictionary) -> int:
	return maxi(0, int(item.get("bonus_amount", 0)))


# ==========================================================
# انیمیشن دکمه‌های خرید سکه / جم
# ==========================================================

func _setup_currency_buy_button_animations() -> void:
	_setup_currency_container_button_animations(coin_currency_container)
	_setup_currency_container_button_animations(gem_currency_container)


func _setup_currency_container_button_animations(container: HBoxContainer) -> void:
	if not container:
		return

	for card in container.get_children():
		var btn := card.get_node_or_null("BuyButton") as Button
		if btn:
			_setup_currency_button_animation(btn)

	_play_currency_container_intro.call_deferred(container)


func _setup_currency_button_animation(btn: Button) -> void:
	if not btn:
		return

	_prepare_currency_buy_button(btn)

	if btn.has_meta("currency_anim_connected"):
		return

	btn.mouse_entered.connect(_on_currency_button_entered.bind(btn))
	btn.mouse_exited.connect(_on_currency_button_exited.bind(btn))
	btn.button_down.connect(_on_currency_button_down.bind(btn))
	btn.button_up.connect(_on_currency_button_up.bind(btn))
	btn.pressed.connect(_on_currency_button_pressed_fx.bind(btn))
	btn.set_meta("currency_anim_connected", true)


func _prepare_currency_buy_button(btn: Button) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_contents = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_make_currency_buy_button_style_unique(btn)
	_update_currency_button_pivot(btn)

	if not btn.has_meta("currency_resized_connected"):
		btn.resized.connect(_on_currency_button_resized.bind(btn))
		btn.set_meta("currency_resized_connected", true)


func _make_currency_buy_button_style_unique(btn: Button) -> void:
	if btn.has_meta("currency_style"):
		return

	var style := btn.get_theme_stylebox("normal")

	if style is StyleBoxFlat:
		var unique_style := (style as StyleBoxFlat).duplicate()

		btn.add_theme_stylebox_override("normal", unique_style)
		btn.add_theme_stylebox_override("hover", unique_style)
		btn.add_theme_stylebox_override("pressed", unique_style)
		btn.add_theme_stylebox_override("hover_pressed", unique_style)

		btn.set_meta("currency_style", unique_style)
		btn.set_meta("currency_base_bg", unique_style.bg_color)
		btn.set_meta("currency_base_border", unique_style.border_color)
	else:
		btn.set_meta("currency_style", null)


func _update_currency_button_pivot(btn: Control) -> void:
	if btn.size != Vector2.ZERO:
		btn.pivot_offset = btn.size / 2.0


func _on_currency_button_resized(btn: Button) -> void:
	_update_currency_button_pivot(btn)


func _on_currency_button_entered(btn: Button) -> void:
	btn.set_meta("currency_hover", true)
	_tween_currency_button_scale(btn, CURRENCY_BTN_HOVER_SCALE, 0.12, Tween.TRANS_BACK, Tween.EASE_OUT)
	_tween_currency_button_style(btn, true)
	_play_currency_button_shine(btn)


func _on_currency_button_exited(btn: Button) -> void:
	btn.set_meta("currency_hover", false)
	_tween_currency_button_scale(btn, CURRENCY_BTN_NORMAL_SCALE, 0.12, Tween.TRANS_QUAD, Tween.EASE_OUT)
	_tween_currency_button_style(btn, false)


func _on_currency_button_down(btn: Button) -> void:
	btn.set_meta("currency_down", true)
	_tween_currency_button_scale(btn, CURRENCY_BTN_DOWN_SCALE, 0.05, Tween.TRANS_QUAD, Tween.EASE_OUT)


func _on_currency_button_up(btn: Button) -> void:
	btn.set_meta("currency_down", false)

	var target_scale: Vector2 = CURRENCY_BTN_NORMAL_SCALE
	if btn.is_hovered():
		target_scale = CURRENCY_BTN_HOVER_SCALE

	_tween_currency_button_scale(btn, target_scale, 0.26, Tween.TRANS_BACK, Tween.EASE_OUT)
	_tween_currency_button_style(btn, btn.is_hovered())


func _on_currency_button_pressed_fx(btn: Button) -> void:
	LocalSettings.vibrate(15)

	_play_currency_button_flash(btn)
	_play_currency_button_shine(btn)
	_play_currency_button_style_burst(btn)
	_play_currency_button_press(btn)


func _tween_currency_button_scale(btn: Control, target: Vector2, duration: float, trans: int, ease_type: int) -> void:
	_kill_meta_tween(btn, "currency_scale_tween")

	var tween := btn.create_tween()
	tween.set_trans(trans)
	tween.set_ease(ease_type)
	tween.tween_property(btn, "scale", target, duration)

	btn.set_meta("currency_scale_tween", tween)


func _tween_currency_button_style(btn: Button, hovered: bool) -> void:
	var style = btn.get_meta("currency_style", null)
	if not style is StyleBoxFlat:
		return

	var base_bg: Color = btn.get_meta("currency_base_bg", style.bg_color)
	var base_border: Color = btn.get_meta("currency_base_border", style.border_color)

	var target_bg := base_bg
	var target_border := base_border

	if hovered:
		target_bg = base_bg.lightened(0.20)
		target_border = base_border.lightened(0.45)

	_kill_meta_tween(btn, "currency_style_tween")

	var tween := btn.create_tween().set_parallel(true)
	tween.tween_property(style, "bg_color", target_bg, 0.12)
	tween.tween_property(style, "border_color", target_border, 0.12)

	btn.set_meta("currency_style_tween", tween)


func _play_currency_button_style_burst(btn: Button) -> void:
	var style = btn.get_meta("currency_style", null)
	if not style is StyleBoxFlat:
		return

	var base_bg: Color = btn.get_meta("currency_base_bg", style.bg_color)
	var base_border: Color = btn.get_meta("currency_base_border", style.border_color)

	var hover_bg := base_bg.lightened(0.16)
	var hover_border := base_border.lightened(0.30)

	if not btn.is_hovered():
		hover_bg = base_bg
		hover_border = base_border

	_kill_meta_tween(btn, "currency_style_tween")

	var tween := btn.create_tween().set_parallel(true)
	tween.tween_property(style, "bg_color", base_bg.lightened(0.45), 0.05)
	tween.tween_property(style, "border_color", base_border.lightened(0.75), 0.05)
	tween.tween_property(style, "bg_color", hover_bg, 0.18).set_delay(0.05)
	tween.tween_property(style, "border_color", hover_border, 0.18).set_delay(0.05)

	btn.set_meta("currency_style_tween", tween)


func _play_currency_button_press(btn: Button) -> void:
	_kill_meta_tween(btn, "currency_scale_tween")

	var target_scale: Vector2 = CURRENCY_BTN_NORMAL_SCALE
	if btn.is_hovered():
		target_scale = CURRENCY_BTN_HOVER_SCALE

	var tween := btn.create_tween()

	tween.tween_property(btn, "scale", CURRENCY_BTN_DOWN_SCALE, UIFx.PRESS_DOWN_TIME)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	tween.tween_property(btn, "scale", target_scale * 1.03, UIFx.PRESS_RISE_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.tween_property(btn, "scale", target_scale, UIFx.PRESS_SETTLE_TIME)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)

	btn.set_meta("currency_scale_tween", tween)


func _get_currency_button_flash(btn: Button) -> ColorRect:
	var flash := btn.get_node_or_null("CurrencyFlashOverlay") as ColorRect
	if flash:
		return flash

	flash = ColorRect.new()
	flash.name = "CurrencyFlashOverlay"
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(flash)

	return flash


func _play_currency_button_flash(btn: Button) -> void:
	var flash := _get_currency_button_flash(btn)
	if not flash:
		return

	_kill_meta_tween(flash, "currency_flash_tween")

	flash.color = Color(1, 1, 1, 0)
	var tween := flash.create_tween()
	tween.tween_property(flash, "color", Color(1, 1, 1, 0.35), 0.04)
	tween.tween_property(flash, "color", Color(1, 1, 1, 0.0), 0.22)

	flash.set_meta("currency_flash_tween", tween)


func _get_currency_button_shine(btn: Button) -> ColorRect:
	var shine := btn.get_node_or_null("CurrencyShineEffect") as ColorRect
	if shine:
		return shine

	shine = ColorRect.new()
	shine.name = "CurrencyShineEffect"
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.color = Color(1, 1, 1, 0.18)
	shine.anchor_left = 0.0
	shine.anchor_top = 0.0
	shine.anchor_right = 0.0
	shine.anchor_bottom = 1.0
	shine.offset_left = -40.0
	shine.offset_right = -18.0
	shine.offset_top = 0.0
	shine.offset_bottom = 0.0
	btn.add_child(shine)

	return shine


func _play_currency_button_shine(btn: Button) -> void:
	var shine := _get_currency_button_shine(btn)
	if not shine:
		return

	_kill_meta_tween(shine, "currency_shine_tween")

	shine.modulate.a = 1.0
	shine.offset_left = -40.0
	shine.offset_right = -18.0

	var target_left := btn.size.x + 10.0
	var target_right := btn.size.x + 32.0

	var tween := shine.create_tween().set_parallel(true)
	tween.tween_property(shine, "offset_left", target_left, 0.35)
	tween.tween_property(shine, "offset_right", target_right, 0.35)
	tween.tween_property(shine, "modulate:a", 0.0, 0.35)

	shine.set_meta("currency_shine_tween", tween)


func _play_currency_container_intro(container: HBoxContainer) -> void:
	if not container:
		return

	if container.has_meta("currency_intro_played"):
		return

	container.set_meta("currency_intro_played", true)
	var children := container.get_children()

	for i in range(children.size()):
		var btn := children[i].get_node_or_null("BuyButton") as Button
		if not btn:
			continue

		btn.modulate.a = 0.0
		btn.scale = Vector2(0.7, 0.7)

		var delay: float = i * 0.06
		var tween := btn.create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(btn, "modulate:a", 1.0, 0.20).set_delay(delay)
		tween.tween_property(btn, "scale", Vector2.ONE, 0.28).set_delay(delay)


func _kill_meta_tween(node: Node, meta_key: String) -> void:
	if not node:
		return

	var old_tween: Tween = node.get_meta(meta_key, null)
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()


# ==========================================================
# اکشن‌های خرید
# ==========================================================

func _on_card_show_buy_pressed() -> void:
	if not selected_character_data.is_empty():
		_on_card_buy_requested(selected_character_data)


func _on_weapon_buy_pressed() -> void:
	if not selected_weapon_data.is_empty():
		_on_card_buy_requested(selected_weapon_data)


func clear_container(container: Node) -> void:
	if container:
		for child in container.get_children():
			child.queue_free()


# ==========================================================
# منطق خرید
# ==========================================================

func _resolve_purchase_category(item: Dictionary) -> String:
	var category: String = str(item.get("category", "")).to_lower().strip_edges()

	if category in ["character", "weapon", "coin_pack", "gem_pack"]:
		return category

	if category in ["gem", "heart"]:
		return "gem_pack"

	if category in ["coin", "gold"]:
		return "coin_pack"

	match str(item.get("section", "")).strip_edges():
		SECTION_CHARACTERS:
			return "character"
		SECTION_WEAPONS:
			return "weapon"
		SECTION_CURRENCY:
			return "gem_pack" if _get_currency_category(item) == "gem" else "coin_pack"

	return "character"


func _item_price(item: Dictionary) -> int:
	return int(item.get("final_price", item.get("original_price", item.get("price", item.get("cost", 0)))))


func _item_cost_type(item: Dictionary) -> String:
	var raw := str(item.get("cost_type", item.get("currency", ""))).to_lower().strip_edges()

	if raw in ["gems", "gem", "قلب", "جم", "heart"]:
		return "gems"

	if raw in ["toman", "تومان", "rial", "ریال", "money", "cash", "irr"]:
		return "toman"

	if raw in ["coins", "coin", "gold", "سکه", "طلا"]:
		return "coins"

	var price_text := str(item.get("price_text", "")).to_lower().strip_edges()
	if price_text.contains("تومان") or price_text.contains("ریال"):
		return "toman"

	return "coins"


func _get_explicit_store_product_id(item: Dictionary) -> String:
	for key in ["product_id", "sku", "store_id", "bazaar_id", "myket_id", "market_product_id"]:
		var v := str(item.get(key, "")).strip_edges()
		if not v.is_empty():
			return v
	return ""


func _get_store_product_id(item: Dictionary) -> String:
	var explicit := _get_explicit_store_product_id(item)
	if not explicit.is_empty():
		return explicit
	return str(item.get("item_id", item.get("id", ""))).strip_edges()


func _is_store_purchase(item: Dictionary) -> bool:
	var category := _resolve_purchase_category(item)

	if category != "gem_pack" and category != "coin_pack":
		return false

	if _item_cost_type(item) == "toman":
		return true

	if not _get_explicit_store_product_id(item).is_empty():
		return true

	if category == "gem_pack":
		return true

	return false


func _on_card_buy_requested(item_data: Dictionary) -> void:
	if item_data.is_empty():
		return

	if _buy_in_flight:
		return

	if Global.my_username.is_empty():
		_show_toast("هنوز وارد حساب نشدی", false)
		return

	var category := _resolve_purchase_category(item_data)

	# بسته‌های سکه/جم اگر پول واقعی باشند، باید به بازار/مایکت بروند.
	if _is_store_purchase(item_data):
		_start_store_purchase(item_data)
		return

	var item_id: String = str(item_data.get("item_id", item_data.get("id", ""))).strip_edges()
	if item_id.is_empty():
		_show_toast("این آیتم شناسه‌ی معتبری ندارد", false)
		return

	if category == "character" or category == "weapon":
		if Global.owns_item(item_id, category):
			_show_toast("این آیتم را قبلاً خریده‌ای", false)
			return

	var price: int = _item_price(item_data)
	var cost_type := _item_cost_type(item_data)

	if cost_type == "toman":
		_start_store_purchase(item_data)
		return

	if cost_type == "gems":
		if Global.gems < price:
			_show_toast("قلب کافی نداری", false)
			return
	else:
		if Global.coins < price:
			_show_toast("سکه کافی نداری", false)
			return

	# C13: خرج کردنِ قلب (ارزِ ویژه) قبلش یک بار تأیید می‌خواهد؛ قیمت، مانده‌ی
	# بعد از خرید و دکمه‌ی انصرافِ هم‌اندازه — بدونِ فشار و بدونِ دکمه‌ی پنهان
	var gem_buy := cost_type == "gems"
	if (gem_buy and price >= GEM_CONFIRM_MIN) or (not gem_buy and price >= COIN_CONFIRM_MIN):
		if _confirm_open:
			return
		_confirm_open = true
		var item_name := str(item_data.get("name", "")).strip_edges()
		var unit := "قلب" if gem_buy else "سکه"
		var left := (Global.gems if gem_buy else Global.coins) - price
		var body := "«%s» را با %s %s می‌خری؟\nبعد از خرید %s %s برایت می‌ماند." % [
			item_name if item_name != "" else "این آیتم",
			MissionArt.fa_grouped(price), unit, MissionArt.fa_grouped(left), unit]
		MenuUI.confirm(self, "تأییدِ خرید", body, "خرید با %s %s" % [MissionArt.fa_grouped(price), unit],
			func(ok: bool) -> void:
				_confirm_open = false
				if ok:
					_send_buy(item_data, item_id, category))
		return

	_send_buy(item_data, item_id, category)


func _send_buy(item_data: Dictionary, item_id: String, category: String) -> void:
	if _buy_in_flight:
		return
	_buy_in_flight = true
	_pending_buy_item = item_data

	var payload := {
		"username": Global.my_username,
		"item_id": item_id,
		"category": category,
	}

	var err := buy_http_request.request(
		BUY_URL,
		Global.json_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	if err != OK:
		_buy_in_flight = false
		_pending_buy_item = {}
		_show_toast("ارتباط با سرور برقرار نشد", false)


func _on_buy_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_buy_in_flight = false

	var bought_item: Dictionary = _pending_buy_item
	_pending_buy_item = {}

	if result != HTTPRequest.RESULT_SUCCESS:
		_show_toast("ارتباط با سرور برقرار نشد", false)
		return

	var payload: Dictionary = {}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK and typeof(json.data) == TYPE_DICTIONARY:
		payload = json.data

	if response_code != 200:
		_show_toast(str(payload.get("error", "خرید انجام نشد")), false)
		return

	if payload.is_empty():
		Global.refresh_player_data()
	else:
		Global.apply_purchase_response(payload)

	_show_purchase_reward(bought_item)
	_refresh_ownership_ui()


func _show_purchase_reward(item: Dictionary) -> void:
	var item_name: String = str(item.get("name", "")).strip_edges()
	var category := _resolve_purchase_category(item)
	var reward: Dictionary = {}

	if category == "coin_pack" or category == "gem_pack":
		var amount := int(item.get("amount", item.get("value", 0)))
		if amount <= 0:
			amount = _guess_currency_amount(item)

		amount += _currency_bonus(item)

		reward = {
			"icon": "gem" if category == "gem_pack" else "coin",
			"amount": amount,
		}

		if amount <= 0:
			reward["label"] = item_name
	else:
		reward = {
			"texture": _get_character_texture(item),
			"amount": 0,
			"label": item_name if not item_name.is_empty() else "آیتم جدید",
		}

	RewardPopup.show_rewards([reward], "خرید موفق")


# ==========================================================
# خرید فروشگاهی / تبلیغ / کد هدیه
# ==========================================================

func _setup_reward_buttons() -> void:
	for btn in [video_button, code_button]:
		var texture_btn := btn as TextureButton
		if texture_btn:
			texture_btn.focus_mode = Control.FOCUS_NONE
			UIFx.bind_press_feedback(texture_btn)

	if video_button:
		video_button.pressed.connect(_on_video_button_pressed)

	if code_button:
		code_button.pressed.connect(_on_code_button_pressed)

	if not Billing.purchase_completed.is_connected(_on_store_purchase_completed):
		Billing.purchase_completed.connect(_on_store_purchase_completed)

	if not Billing.purchase_failed.is_connected(_on_store_purchase_failed):
		Billing.purchase_failed.connect(_on_store_purchase_failed)

	if not Billing.purchase_status.is_connected(_on_store_purchase_status):
		Billing.purchase_status.connect(_on_store_purchase_status)

	if not Ads.reward_granted.is_connected(_on_ad_reward_granted):
		Ads.reward_granted.connect(_on_ad_reward_granted)

	if not Ads.reward_pending.is_connected(_on_ad_reward_pending):
		Ads.reward_pending.connect(_on_ad_reward_pending)

	if not Ads.reward_failed.is_connected(_on_ad_reward_failed):
		Ads.reward_failed.connect(_on_ad_reward_failed)


func _start_store_purchase(item: Dictionary) -> void:
	if Billing.is_busy():
		_show_toast("خرید قبلی هنوز در جریان است؛ چند لحظه صبر کن", true)
		return

	var product_id := _get_store_product_id(item)

	if product_id.is_empty():
		_show_toast("این بسته هنوز در فروشگاه تعریف نشده", false)
		return

	_pending_buy_item = item
	Billing.purchase(product_id)


func _on_store_purchase_completed(_product_id: String, data: Dictionary) -> void:
	var bought_item: Dictionary = _pending_buy_item
	_pending_buy_item = {}

	var reward_data: Dictionary = {}
	if typeof(data.get("reward", {})) == TYPE_DICTIONARY:
		reward_data = data["reward"]

	var coins := int(reward_data.get("coins", 0))
	var gems := int(reward_data.get("gems", 0))

	if coins <= 0 and gems <= 0:
		coins = int(data.get("coins", 0))
		gems = int(data.get("gems", 0))

	var rewards: Array = []

	if coins > 0:
		rewards.append({
			"icon": "coin",
			"amount": coins,
		})

	if gems > 0:
		rewards.append({
			"icon": "gem",
			"amount": gems,
		})

	if rewards.is_empty():
		var category := _resolve_purchase_category(bought_item)
		var amount := _guess_currency_amount(bought_item) + _currency_bonus(bought_item)

		if amount > 0:
			rewards.append({
				"icon": "gem" if category == "gem_pack" else "coin",
				"amount": amount,
			})
		else:
			var item_name := str(bought_item.get("name", "")).strip_edges()
			if item_name.is_empty():
				item_name = "بسته خریداری شد"

			rewards.append({
				"label": item_name,
				"amount": 0,
			})

	RewardPopup.show_rewards(rewards, "خرید موفق")

	if typeof(data.get("payload", {})) == TYPE_DICTIONARY and not data["payload"].is_empty():
		Global.apply_purchase_response(data["payload"])
	else:
		Global.refresh_player_data()

	_refresh_ownership_ui()


## بازخوردِ فوری بعد از لمسِ دکمه‌ی خرید، تا بازیکن تا باز شدنِ فروشگاه
## دوباره دکمه را نزند
func _on_store_purchase_status(_product_id: String, message: String) -> void:
	_show_toast(message, true)


func _on_store_purchase_failed(_product_id: String, message: String) -> void:
	_pending_buy_item = {}
	if message.strip_edges().is_empty():
		_show_toast("خرید انجام نشد", false)
	else:
		_show_toast(message, false)


func _on_video_button_pressed() -> void:
	if Ads.is_busy():
		return

	_show_toast("در حال آماده‌سازی تبلیغ...", true)
	Ads.show_rewarded()


func _on_ad_reward_granted(data: Dictionary) -> void:
	var reward: Dictionary = {}
	if typeof(data.get("reward", {})) == TYPE_DICTIONARY:
		reward = data["reward"]

	var gems := int(reward.get("gems", 0))
	var coins := int(reward.get("coins", 0))

	var rewards: Array = []

	if gems > 0:
		rewards.append({"icon": "gem", "amount": gems})

	if coins > 0:
		rewards.append({"icon": "coin", "amount": coins})

	if rewards.is_empty():
		rewards.append({"label": "جایزه دریافت شد", "amount": 0})

	RewardPopup.show_rewards(rewards, "جایزه‌ی تبلیغ")

	var remaining := int(data.get("remaining", -1))
	if remaining >= 0:
		_show_toast("امروز %d بار دیگه می‌تونی تبلیغ ببینی" % remaining, true)


func _on_ad_reward_pending(message: String) -> void:
	_show_toast(message, true)


func _on_ad_reward_failed(message: String) -> void:
	_show_toast(message, false)


func _on_code_button_pressed() -> void:
	if get_node_or_null("GiftCodeDialog"):
		return

	var dialog := GIFT_CODE_DIALOG_SCENE.instantiate()
	dialog.name = "GiftCodeDialog"
	dialog.z_index = 150
	add_child(dialog)
	dialog.redeemed.connect(_on_gift_code_redeemed)
	dialog.open()


func _on_gift_code_redeemed(data: Dictionary) -> void:
	var reward: Dictionary = data.get("reward", {})
	var items: Array = []

	if int(reward.get("coins", 0)) > 0:
		items.append({"icon": "coin", "amount": int(reward["coins"])})

	if int(reward.get("gems", 0)) > 0:
		items.append({"icon": "gem", "amount": int(reward["gems"])})

	RewardPopup.show_rewards(items, "کد هدیه اعمال شد")


# ==========================================================
# وضعیت مالکیت
# ==========================================================

func _set_buy_button_owned(btn: Button, owned: bool) -> void:
	if not btn:
		return

	btn.disabled = owned

	var price_row: Control = btn.get_node_or_null("HBoxContainer") as Control
	if not price_row:
		price_row = btn.get_node_or_null("Control") as Control

	if price_row:
		price_row.visible = not owned

	var badge: Label = btn.get_node_or_null("OwnedLabel") as Label

	if badge == null and owned:
		badge = Label.new()
		badge.name = "OwnedLabel"
		badge.text = "خریداری شده"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		badge.add_theme_color_override("font_color", Color("ffd257"))

		var owned_font := load("res://fonts/Lalezar-Regular.ttf")
		if owned_font:
			badge.add_theme_font_override("font", owned_font)

		badge.add_theme_font_size_override("font_size", 22)
		btn.add_child(badge)

	if badge:
		badge.visible = owned

	btn.modulate = Color(0.78, 0.78, 0.78, 1.0) if owned else Color.WHITE


func _apply_card_ownership(card: Node) -> void:
	if card == null or not is_instance_valid(card):
		return

	var item: Dictionary = card.get_meta("shop_item", {})
	if item.is_empty():
		return

	var category: String = _resolve_purchase_category(item)
	if category != "character" and category != "weapon":
		return

	var item_id: String = str(item.get("item_id", item.get("id", ""))).strip_edges()
	var owned: bool = Global.owns_item(item_id, category)

	var btn: Button = card.find_child("BuyButton", true, false) as Button
	if btn:
		_set_buy_button_owned(btn, owned)
		return

	var price_bar: Control = card.find_child("PriceBar", true, false) as Control
	if price_bar:
		_set_price_bar_owned(price_bar, owned)


func _set_price_bar_owned(price_bar: Control, owned: bool) -> void:
	var price_container: Control = price_bar.get_node_or_null("PriceContainer") as Control
	if price_container:
		price_container.visible = not owned

	var badge: Label = price_bar.get_node_or_null("OwnedLabel") as Label

	if badge == null and owned:
		badge = Label.new()
		badge.name = "OwnedLabel"
		badge.text = "خریداری شده"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		badge.add_theme_color_override("font_color", Color("ffd257"))

		var owned_font := load("res://fonts/Lalezar-Regular.ttf")
		if owned_font:
			badge.add_theme_font_override("font", owned_font)

		badge.add_theme_font_size_override("font_size", 18)
		price_bar.add_child(badge)

	if badge:
		badge.visible = owned


func _refresh_ownership_ui() -> void:
	for container in [character_container, weapon_container, weekly_container, special_container]:
		if container:
			for card in container.get_children():
				_apply_card_ownership(card)

	if not selected_character_data.is_empty():
		var char_id: String = str(selected_character_data.get("item_id", "")).strip_edges()
		_set_buy_button_owned(cs_buy_button, Global.owns_item(char_id, "character"))

	if not selected_weapon_data.is_empty():
		var weapon_id: String = str(selected_weapon_data.get("item_id", "")).strip_edges()
		_set_buy_button_owned(ws_buy_button, Global.owns_item(weapon_id, "weapon"))

	_refresh_suggest_up_ownership()


# ==========================================================
# Toast
# ==========================================================

const TOAST_OK_COLOR := Color("1d7a3c")
const TOAST_ERR_COLOR := Color("8e1420")

var _toast_panel: PanelContainer = null
var _toast_label: Label = null
var _toast_tween: Tween = null


func _ensure_toast() -> void:
	if _toast_panel and is_instance_valid(_toast_panel):
		return

	_toast_panel = PanelContainer.new()
	_toast_panel.name = "ShopToast"
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.z_index = 200
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_panel.offset_top = 96.0
	_toast_panel.modulate.a = 0.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.92)
	style.set_border_width_all(2)
	style.border_color = TOAST_OK_COLOR
	style.set_corner_radius_all(14)
	style.content_margin_left = 26.0
	style.content_margin_right = 26.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_toast_panel.add_theme_stylebox_override("panel", style)

	_toast_label = Label.new()
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var toast_font := load("res://fonts/Lalezar-Regular.ttf")
	if toast_font:
		_toast_label.add_theme_font_override("font", toast_font)

	_toast_label.add_theme_font_size_override("font_size", 24)
	_toast_panel.add_child(_toast_label)

	add_child(_toast_panel)


func _show_toast(message: String, success: bool) -> void:
	_ensure_toast()

	_toast_label.text = message
	_toast_label.add_theme_color_override("font_color", Color("d7ffd9") if success else Color("ffd7dc"))

	var style: StyleBoxFlat = _toast_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.border_color = TOAST_OK_COLOR if success else TOAST_ERR_COLOR

	LocalSettings.vibrate(20 if success else 45)

	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast_panel.modulate.a = 0.0
	_toast_panel.offset_top = 72.0

	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)

	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.16)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_toast_tween.tween_property(_toast_panel, "offset_top", 96.0, 0.28)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_toast_tween.set_parallel(false)
	_toast_tween.tween_interval(1.7)

	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


# ==========================================================
# نرمال‌سازی JSON
# ==========================================================

func _normalize_data(data):
	var data_type := typeof(data)

	if data_type == TYPE_DICTIONARY:
		var result := {}
		for key in data.keys():
			result[str(key).strip_edges()] = _normalize_data(data[key])
		return result

	if data_type == TYPE_ARRAY:
		var result := []
		for value in data:
			result.append(_normalize_data(value))
		return result

	if data_type == TYPE_STRING:
		return str(data).strip_edges()

	return data


func _on_home_button_pressed() -> void:
	get_tree().change_scene_to_file("res://secense/main_menu.tscn")
