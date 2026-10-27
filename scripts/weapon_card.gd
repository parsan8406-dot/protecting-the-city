extends Control

signal card_clicked(item_data: Dictionary)
signal buy_requested(item_data: Dictionary)

const Rarity := preload("res://scripts/psych_shop_rarity.gd")

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
var _border_color := Color.WHITE
var _selected := false
var _pips: Control = null
var _touch_down := false
var click_tween: Tween
var scroll_fade_tween: Tween

# متغیرها و آستانه تفکیک ضربه (کلیک) از درگ (اسکرول)
var _touch_start_pos: Vector2 = Vector2.ZERO
var _is_swiping: bool = false
var _parent_scroll: ScrollContainer = null
const DRAG_THRESHOLD: float = 10.0
const NAME_FONT_SIZE := 17


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
	_build_header()

	# C13: نوارِ قیمت فقط برچسب است؛ لمسِ کارت انتخاب می‌کند و خرید از پنلِ کنار
	# است — وگرنه کشیدنِ انگشت روی لیست از روی دکمه خرید می‌زد و اسکرول گیر می‌کرد
	if buy_button:
		buy_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		buy_button.focus_mode = Control.FOCUS_NONE
		for c in buy_button.find_children("*", "Control", true, false):
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

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
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.text = str(data.get("name", "نامشخص"))

	# ۲. قیمت
	# V10: قیمتِ واقعیِ پرداختی با ارقامِ فارسیِ هم‌تراز
	var price: int = int(data.get("final_price", data.get("original_price", data.get("price", data.get("cost", 0)))))
	var price_node := _get_amount_label()
	if price_node:
		price_node.text = MissionArt.fa_grouped(price)
		price_node.add_theme_font_override("font", MenuUI.FONT_NUM)
	_fit_name.call_deferred()

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
	_apply_rarity_style(Rarity.of(data))


## سرتیترِ کارت یک ردیف است: [آیکنِ رده][نگین‌ها] ... [اسم]؛ اسم فقط جای باقی‌مانده
## را می‌گیرد و هیچ‌وقت روی نگین‌ها نمی‌افتد
func _build_header() -> void:
	if name_label == null or rarity_icon == null or has_node("Header"):
		return
	var header := HBoxContainer.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.z_index = 1
	header.add_theme_constant_override("separation", 4)
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_left = 6.0
	header.offset_right = -6.0
	header.offset_top = 5.0
	header.offset_bottom = 33.0
	add_child(header)
	rarity_icon.reparent(header, false)
	rarity_icon.custom_minimum_size = Vector2(23, 23)
	rarity_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.reparent(header, false)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.custom_minimum_size = Vector2.ZERO
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.resized.connect(func() -> void: _fit_name.call_deferred())


## اسمِ بلند اول تا ۱۲ کوچک می‌شود، بعد «…» می‌خورد
func _fit_name() -> void:
	if name_label == null or not is_instance_valid(name_label):
		return
	var room := name_label.size.x
	if room <= 1.0:
		return
	var font := name_label.get_theme_font("font")
	var fs := NAME_FONT_SIZE
	while fs > 12 and font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	name_label.add_theme_font_size_override("font_size", fs)


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


## V2: پالتِ مشترکِ رده + لوزی‌ها کنارِ آیکن (شکل، نه فقط رنگ)
func _apply_rarity_style(rarity: String) -> void:
	_border_color = Rarity.color(rarity)
	if reference_rect:
		reference_rect.border_color = MenuUI.GOLD if _selected else _border_color
		reference_rect.border_width = 4.0 if _selected else 2.0
	if rarity_icon:
		rarity_icon.modulate = _border_color
		if _pips == null:
			_pips = Rarity.pips(rarity, 11.0)
			_pips.name = "RarityPips"
			var header := rarity_icon.get_parent()
			header.add_child(_pips)
			header.move_child(_pips, rarity_icon.get_index() + 1)
		Rarity.set_pips(_pips, rarity)
		_fit_name.call_deferred()
	if bg_texture:
		bg_texture.texture = Rarity.gradient(rarity)


## کارتی که در پنلِ کنار نشان داده می‌شود: قابِ طلایی (V3)
func set_selected(on: bool) -> void:
	_selected = on
	if reference_rect:
		reference_rect.border_color = MenuUI.GOLD if on else _border_color
		reference_rect.border_width = 4.0 if on else 2.0


## C13: پولش نمی‌رسد → قیمت کم‌رنگ (نه قرمز)
func set_affordable(can: bool) -> void:
	var l := _get_amount_label()
	if l:
		l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7) if can else MenuUI.MUTED)
	var ic := _get_buy_icon()
	if ic:
		ic.modulate = Color.WHITE if can else Color(1, 1, 1, 0.55)


# --- تعاملات ورودی، لمس و اسکرول (Touch, Click & Drag System) ---

func _on_gui_input(event: InputEvent) -> void:
	# فقط تاچ (emulate_touch_from_mouse روی PC همین را می‌سازد) — قبلاً موس هم جدا
	# گرفته می‌شد و هر کلیک دو بار انتخاب می‌زد. اسکرول را خودِ ScrollContainer
	# انجام می‌دهد؛ اینجا فقط تشخیص می‌دهیم لمس «کشیدن» بود نه «زدن».
	if event is InputEventScreenTouch:
		var gp: Vector2 = get_global_transform_with_canvas() * event.position
		if event.pressed:
			_touch_start_pos = gp
			_touch_down = true
			_is_swiping = false
		else:
			if _touch_down and not _is_swiping:
				_play_card_selection_effect()
				card_clicked.emit(item_data)
			_touch_down = false
	elif event is InputEventScreenDrag and _touch_down:
		var gp: Vector2 = get_global_transform_with_canvas() * event.position
		if gp.distance_to(_touch_start_pos) > DRAG_THRESHOLD:
			_is_swiping = true
		# روی گوشی خودِ ScrollContainer با کشیدن اسکرول می‌کند؛ روی PC (بدونِ
		# صفحه‌ی لمسی) نه — آنجا دستی، تا تست روی PC هم مثلِ گوشی باشد
		if _is_swiping and _parent_scroll and not DisplayServer.is_touchscreen_available():
			_parent_scroll.scroll_vertical -= int(event.relative.y)


func _play_card_selection_effect() -> void:
	LocalSettings.vibrate(20)

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
