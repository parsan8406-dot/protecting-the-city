extends Control

signal card_clicked(item_data: Dictionary)
signal buy_requested(item_data: Dictionary)

# ارجاع به نودهای اصلی کارت
@onready var bg_texture: TextureRect = $TextureRect
@onready var reference_rect: ReferenceRect = $ReferenceRect
@onready var rarity_icon: TextureRect = $RaretyIcon
@onready var weapon_image: TextureRect = $WeaponImage
@onready var fire_icon: TextureRect = $Fire
@onready var name_label: Label = $NameLabel
@onready var buy_button: Button = $BuyButton
@onready var buy_icon: TextureRect = $BuyButton/HBoxContainer/BuyIcon
@onready var amount_label: Label = $BuyButton/HBoxContainer/AmountLabel
@onready var anim_player: AnimationPlayer = $AnimationPlayer

# مسیر ثابت آیکون‌های ارز
const COIN_ICON_PATH := "res://assets/ui/coin_icon.png"
const GEM_ICON_PATH := "res://assets/ui/gem_icon.png"
const WEAPONS_FOLDER_PATH := "res://assets/items/"

# رنگ‌های تم نایابی (Rarity)
const COLOR_RARE_BORDER := Color("4dd2ff")
const COLOR_EPIC_BORDER := Color("e066ff")
const COLOR_LEGEND_BORDER := Color("ff9900")

var item_data: Dictionary = {}
var click_tween: Tween
var scroll_fade_tween: Tween

# متغیرها و آستانه تفکیک ضربه (کلیک) از درگ (اسکرول)
var _touch_start_pos: Vector2 = Vector2.ZERO
var _is_swiping: bool = false
var _parent_scroll: ScrollContainer = null
const DRAG_THRESHOLD: float = 10.0


func _ready() -> void:
	# غیرفعال کردن نمایش افکت آتش در حالت عادی
	if fire_icon:
		fire_icon.visible = false

	# اتصال سیگنال اتمام انیمیشن
	if anim_player and not anim_player.animation_finished.is_connected(_on_animation_finished):
		anim_player.animation_finished.connect(_on_animation_finished)

	# ۱. تنظیم نقطه مرکزی برای بزرگ‌نمایی نرم از مرکز کارت
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)
	
	# ۲. فعال‌سازی دریافت ورودی لمس و اجازه عبور ورودی به نود والد
	mouse_filter = Control.MOUSE_FILTER_PASS
	_configure_child_mouse_filters()
	
	if buy_button:
		buy_button.pivot_offset = buy_button.size / 2.0
		if not buy_button.pressed.is_connected(_on_buy_button_pressed):
			buy_button.pressed.connect(_on_buy_button_pressed)

	# ۳. اتصال سیگنال ورودی
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)

	# ۴. تنظیم هوشمند اسکرول‌بار والد
	call_deferred("_setup_parent_scrollbar")


## تنظیم نودهای داخلی روی IGNORE تا مانع کلیک و درگ روی کارت نشوند
func _configure_child_mouse_filters() -> void:
	if bg_texture: bg_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if reference_rect: reference_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rarity_icon: rarity_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if weapon_image: weapon_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if fire_icon: fire_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if name_label: name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


# مقداردهی پویای کارت بر اساس دیتای دریافتی
func setup_card(data: Dictionary) -> void:
	item_data = data

	# ۱. نام سلاح
	if name_label:
		name_label.text = str(data.get("name", "نامشخص"))

	# ۲. قیمت
	var price: int = int(data.get("original_price", data.get("price", data.get("cost", 0))))
	var price_node := _get_amount_label()
	if price_node:
		price_node.text = str(price)

	# ۳. تنظیم نوع ارز (سکه / الماس)
	var currency: String = str(data.get("currency", data.get("cost_type", "coins"))).to_lower().strip_edges()
	var icon_node := _get_buy_icon()
	if icon_node:
		if currency in ["gem", "gems"]:
			icon_node.texture = load(GEM_ICON_PATH)
		else:
			icon_node.texture = load(COIN_ICON_PATH)

	# ۴. بارگذاری تصویر سلاح
	_load_weapon_texture(data)

	# ۵. اعمال استایل نایابی (Rarity)
	var rarity: String = str(data.get("rarity", data.get("rarety", "rare"))).to_lower()
	_apply_rarity_style(rarity)


func _get_amount_label() -> Label:
	if amount_label:
		return amount_label
	amount_label = find_child("AmountLabel", true, false) as Label
	return amount_label


func _get_buy_icon() -> TextureRect:
	if buy_icon:
		return buy_icon
	buy_icon = find_child("BuyIcon", true, false) as TextureRect
	return buy_icon


func _load_weapon_texture(data: Dictionary) -> void:
	if not weapon_image:
		return

	var item_id: String = str(data.get("item_id", data.get("id", "")))
	var custom_path: String = str(data.get("image_path", ""))

	var final_path: String = ""
	if not custom_path.is_empty() and ResourceLoader.exists(custom_path):
		final_path = custom_path
	elif not item_id.is_empty():
		var possible_path := WEAPONS_FOLDER_PATH + item_id + ".png"
		if ResourceLoader.exists(possible_path):
			final_path = possible_path

	if not final_path.is_empty():
		weapon_image.texture = load(final_path)


func _apply_rarity_style(rarity: String) -> void:
	var border_color: Color = COLOR_RARE_BORDER

	match rarity:
		"epic":
			border_color = COLOR_EPIC_BORDER
		"legend", "legendary":
			border_color = COLOR_LEGEND_BORDER
		"rare", _:
			border_color = COLOR_RARE_BORDER

	# رنگ کادر و آیکون نایابی
	if reference_rect:
		reference_rect.border_color = border_color
	if rarity_icon:
		rarity_icon.modulate = border_color
	# تغییر گرادینت پس‌زمینه با رنگ نایابی
	if bg_texture and bg_texture.texture is GradientTexture2D:
		var grad_tex := bg_texture.texture.duplicate() as GradientTexture2D
		if grad_tex.gradient:
			grad_tex.gradient = grad_tex.gradient.duplicate()
			grad_tex.gradient.set_color(1, border_color * 0.35)
		bg_texture.texture = grad_tex


# --- تعاملات ورودی، لمس و اسکرول (Touch, Click & Drag System) ---

func _on_gui_input(event: InputEvent) -> void:
	var event_global_pos: Vector2 = global_position + event.position if "position" in event else Vector2.ZERO

	# ۱. ورودی موس
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_start_pos = event_global_pos
			_is_swiping = false
		elif not _is_swiping:
			_play_card_selection_effect()
			card_clicked.emit(item_data)

	# ۲. ورودی لمسی (صفحات لمسی و موبایل)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touch_start_pos = event_global_pos
			_is_swiping = false
		elif not _is_swiping:
			_play_card_selection_effect()
			card_clicked.emit(item_data)

	# ۳. حرکت انگشت روی موبایل (انتقال جابجایی به اسکرول‌بار والد)
	elif event is InputEventScreenDrag:
		if event_global_pos.distance_to(_touch_start_pos) > DRAG_THRESHOLD:
			_is_swiping = true
		if _is_swiping and _parent_scroll:
			_parent_scroll.scroll_vertical -= int(event.relative.y)
			_parent_scroll.scroll_horizontal -= int(event.relative.x)

	# ۴. حرکت موس در حالت فشردن (تست اسکرول با درگ موس)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if event_global_pos.distance_to(_touch_start_pos) > DRAG_THRESHOLD:
			_is_swiping = true
		if _is_swiping and _parent_scroll:
			_parent_scroll.scroll_vertical -= int(event.relative.y)
			_parent_scroll.scroll_horizontal -= int(event.relative.x)


func _play_card_selection_effect() -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(25)

	# روشن کردن visible افکت آتش قبل از شروع انیمیشن
	if fire_icon:
		fire_icon.visible = true

	if anim_player and anim_player.has_animation("select_card_animation"):
		anim_player.stop()
		anim_player.play("select_card_animation")

	if click_tween and click_tween.is_running():
		click_tween.kill()

	click_tween = create_tween()

	var pop := click_tween.parallel()
	pop.tween_property(self, "scale", Vector2(1.08, 1.08), 0.08)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var settle := click_tween.chain().parallel()
	settle.tween_property(self, "scale", Vector2(1.0, 1.0), 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# خاموش کردن visible افکت آتش پس از اتمام انیمیشن
func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"select_card_animation":
		if fire_icon:
			fire_icon.visible = false


func _on_buy_button_pressed() -> void:
	if buy_button:
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(buy_button, "scale", Vector2(0.92, 0.92), 0.06)
		tween.tween_property(buy_button, "scale", Vector2(1.0, 1.0), 0.1)

	buy_requested.emit(item_data)


# --- تنظیم هوشمند اسکرول‌بار ScrollContainer والد ---

func _setup_parent_scrollbar() -> void:
	_parent_scroll = _find_parent_scroll_container(self)
	if not _parent_scroll or _parent_scroll.has_meta("custom_scrollbar_ready"):
		return

	_parent_scroll.set_meta("custom_scrollbar_ready", true)

	var v_bar := _parent_scroll.get_v_scroll_bar()
	var h_bar := _parent_scroll.get_h_scroll_bar()

	_apply_slim_style(v_bar)
	_apply_slim_style(h_bar)

	_parent_scroll.scroll_started.connect(func(): _animate_scrollbar_opacity(_parent_scroll, 0.35, 0.15))
	_parent_scroll.scroll_ended.connect(func():
		get_tree().create_timer(0.6).timeout.connect(func():
			_animate_scrollbar_opacity(_parent_scroll, 0.0, 0.4)
		)
	)


func _apply_slim_style(bar: ScrollBar) -> void:
	if not bar:
		return
	bar.custom_minimum_size.x = 4.0
	bar.custom_minimum_size.y = 4.0
	bar.modulate.a = 0.0

	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(1.0, 1.0, 1.0, 0.8)
	grabber.set_corner_radius_all(2)

	var empty := StyleBoxEmpty.new()

	bar.add_theme_stylebox_override("grabber", grabber)
	bar.add_theme_stylebox_override("grabber_highlight", grabber)
	bar.add_theme_stylebox_override("grabber_pressed", grabber)
	bar.add_theme_stylebox_override("scroll", empty)
	bar.add_theme_stylebox_override("scroll_focus", empty)


func _animate_scrollbar_opacity(scroll_container: ScrollContainer, target_alpha: float, duration: float) -> void:
	if scroll_fade_tween and scroll_fade_tween.is_running():
		scroll_fade_tween.kill()

	scroll_fade_tween = create_tween().set_parallel(true)
	var v_bar := scroll_container.get_v_scroll_bar()
	var h_bar := scroll_container.get_h_scroll_bar()

	if v_bar:
		scroll_fade_tween.tween_property(v_bar, "modulate:a", target_alpha, duration)
	if h_bar:
		scroll_fade_tween.tween_property(h_bar, "modulate:a", target_alpha, duration)


func _find_parent_scroll_container(node: Node) -> ScrollContainer:
	var current := node.get_parent()
	while current:
		if current is ScrollContainer:
			return current as ScrollContainer
		current = current.get_parent()
	return null
