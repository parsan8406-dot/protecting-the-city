extends Control

## کارت نمایش آیتم فروشگاه (سکشن Characters)
##
## لمسِ کارت فقط «انتخاب» است (پنلِ جزئیاتِ کنار پر می‌شود)؛ خرید فقط از دکمه‌ی
## طلاییِ همان پنل — C13: کشیدنِ انگشت روی لیست دیگر نمی‌تواند خرید بزند.

signal buy_requested(item_data: Dictionary)
signal card_clicked(item_data: Dictionary)

const Rarity := preload("res://scripts/psych_shop_rarity.gd")
const GEM_ICON_PATH := "res://assets/ui/gem_icon.png"
const COIN_ICON_PATH := "res://assets/ui/coin_icon.png"
const ART_FOLDERS := ["res://assets/characters/", "res://assets/items/", "res://assets/weapons/"]

@onready var name_label: Label = $NameLabel
@onready var character_image: TextureRect = $CharacterImage
@onready var buy_button: Button = $BuyButton
@onready var price_label: Label = $BuyButton/Control/AmountLabel if has_node("BuyButton/Control/AmountLabel") else null
@onready var currency_icon: TextureRect = $BuyButton/Control/TypeIcon if has_node("BuyButton/Control/TypeIcon") else null

@onready var background: TextureRect = $Background
@onready var border_rect: ReferenceRect = $ReferenceRect
@onready var rarity_icon: TextureRect = $RartyIcon

var current_item_data: Dictionary = {}
var current_border_color: Color = Color.WHITE
var _selected := false
var _pips: Control = null

var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_down := false
var _is_swiping: bool = false
var _parent_scroll: ScrollContainer = null
const DRAG_THRESHOLD: float = 10.0


func _ready() -> void:
	pivot_offset = size / 2.0
	resized.connect(func(): pivot_offset = size / 2.0)

	mouse_filter = Control.MOUSE_FILTER_PASS
	_configure_child_mouse_filters()

	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)

	_setup_shine_effect()
	call_deferred("_setup_parent_scrollbar")


# یافتن هوشمند نود لیبل قیمت در صورت تفاوت ساختار صحنه
func _get_price_label() -> Label:
	if price_label:
		return price_label
	var label_node := find_child("AmountLabel", true, false) as Label
	if not label_node:
		label_node = find_child("Label", true, false) as Label
	price_label = label_node
	return price_label


func _get_currency_icon() -> TextureRect:
	if currency_icon:
		return currency_icon
	var icon_node := find_child("TypeIcon", true, false) as TextureRect
	if not icon_node:
		icon_node = find_child("BuyIcon", true, false) as TextureRect
	currency_icon = icon_node
	return currency_icon


func _configure_child_mouse_filters() -> void:
	for n in [background, character_image, border_rect, name_label, rarity_icon]:
		if n:
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# نوارِ قیمت فقط برچسب است — لمس به کارت می‌رسد (انتخاب + اسکرول)
	if buy_button:
		buy_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		buy_button.focus_mode = Control.FOCUS_NONE
		for c in buy_button.find_children("*", "Control", true, false):
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup_card(item: Dictionary) -> void:
	current_item_data = item
	_update_name(item)
	_update_character_image(item)
	_update_price(item)
	_update_currency_icon(item)
	_apply_rarity_style(Rarity.of(item))


## V2: رنگ + شکل (لوزی‌ها) از پالتِ مشترک
func _apply_rarity_style(rarity: String) -> void:
	current_border_color = Rarity.color(rarity)

	if rarity_icon:
		rarity_icon.visible = true
		rarity_icon.modulate = current_border_color
		_create_icon_shadow(rarity_icon)
		if _pips == null:
			_pips = Rarity.pips(rarity, 8.0)
			_pips.z_index = 1
			add_child(_pips)
		var tier: int = Rarity.TIER[Rarity.key(rarity)]
		_pips.set("tier", tier)
		_pips.set("tint", current_border_color)
		_pips.visible = tier > 0
		_pips.custom_minimum_size.x = maxf(1.0, tier) * 10.0
		_pips.position = rarity_icon.position + Vector2(rarity_icon.size.x + 3.0, 4.0)
		_pips.size = _pips.custom_minimum_size
		_pips.queue_redraw()

	if border_rect:
		border_rect.editor_only = false
		border_rect.border_color = MenuUI.GOLD if _selected else current_border_color
		border_rect.border_width = 4.0 if _selected else 2.0

	if background:
		background.texture = Rarity.gradient(rarity)


## کارتی که الان در پنلِ کنار دیده می‌شود: قابِ طلایی و ضخیم (V3)
func set_selected(on: bool) -> void:
	_selected = on
	if border_rect:
		border_rect.border_color = MenuUI.GOLD if on else current_border_color
		border_rect.border_width = 4.0 if on else 2.0


## V10 + C13: اگر پولش نمی‌رسد قیمت کم‌رنگ می‌شود (نه قرمز — شرم‌سازی نه)
func set_affordable(can: bool) -> void:
	var l := _get_price_label()
	if l:
		l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7) if can else MenuUI.MUTED)
	var ic := _get_currency_icon()
	if ic:
		ic.modulate = Color.WHITE if can else Color(1, 1, 1, 0.55)


func _on_gui_input(event: InputEvent) -> void:
	# فقط تاچ — emulate_touch_from_mouse روی PC همین را می‌سازد (قبلاً موس هم
	# جدا گرفته می‌شد و هر کلیک دو بار انتخاب می‌زد)
	if event is InputEventScreenTouch:
		var gp: Vector2 = get_global_transform_with_canvas() * event.position
		if event.pressed:
			_touch_start_pos = gp
			_touch_down = true
			_is_swiping = false
		else:
			if _touch_down and not _is_swiping:
				play_click_animation()
				card_clicked.emit(current_item_data)
			_touch_down = false
	elif event is InputEventScreenDrag and _touch_down:
		var gp: Vector2 = get_global_transform_with_canvas() * event.position
		if gp.distance_to(_touch_start_pos) > DRAG_THRESHOLD:
			_is_swiping = true
		# روی گوشی خودِ ScrollContainer با کشیدن اسکرول می‌کند؛ روی PC (بدونِ
		# صفحه‌ی لمسی) نه — آنجا دستی، تا تست روی PC هم مثلِ گوشی باشد
		if _is_swiping and _parent_scroll and not DisplayServer.is_touchscreen_available():
			_parent_scroll.scroll_vertical -= int(event.relative.y)


func play_click_animation() -> void:
	LocalSettings.vibrate(20)
	UIFx.tap(self)


func _setup_shine_effect() -> void:
	if not background:
		return

	background.clip_contents = true

	var shader := Shader.new()
	shader.code = """
	shader_type canvas_item;

	uniform float progress : hint_range(-0.5, 1.5) = -0.3;
	uniform float width : hint_range(0.02, 0.4) = 0.12;
	uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 0.4);

	void fragment() {
		float line_pos = (UV.x + UV.y) * 0.5;
		float dist = abs(line_pos - progress);
		float alpha = smoothstep(width, 0.0, dist);
		COLOR = vec4(shine_color.rgb, alpha * shine_color.a);
	}
	"""

	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = shader

	var shine_overlay := ColorRect.new()
	shine_overlay.name = "ShineOverlay"
	shine_overlay.layout_mode = 1
	shine_overlay.anchors_preset = PRESET_FULL_RECT
	shine_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine_overlay.material = shader_mat

	background.add_child(shine_overlay)

	var tween := create_tween().set_loops()
	tween.tween_interval(5.0 + randf() * 2.0)
	tween.tween_method(
		func(val: float): shader_mat.set_shader_parameter("progress", val),
		-0.3,
		1.2,
		0.6
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _setup_parent_scrollbar() -> void:
	_parent_scroll = _find_parent_scroll_container(self)
	if not _parent_scroll or _parent_scroll.has_meta("custom_scrollbar_ready"):
		return

	_parent_scroll.set_meta("custom_scrollbar_ready", true)

	_apply_slim_style(_parent_scroll.get_v_scroll_bar())
	_apply_slim_style(_parent_scroll.get_h_scroll_bar())

	var sc := _parent_scroll
	sc.scroll_started.connect(func(): _animate_scrollbar_opacity(sc, 0.35, 0.15))
	sc.scroll_ended.connect(func():
		sc.get_tree().create_timer(0.6).timeout.connect(func():
			if is_instance_valid(sc):
				_animate_scrollbar_opacity(sc, 0.0, 0.4)
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
	if not is_instance_valid(scroll_container):
		return
	var tw := scroll_container.create_tween().set_parallel(true)
	var v_bar := scroll_container.get_v_scroll_bar()
	var h_bar := scroll_container.get_h_scroll_bar()
	if v_bar:
		tw.tween_property(v_bar, "modulate:a", target_alpha, duration)
	if h_bar:
		tw.tween_property(h_bar, "modulate:a", target_alpha, duration)


func _find_parent_scroll_container(node: Node) -> ScrollContainer:
	var current := node.get_parent()
	while current:
		if current is ScrollContainer:
			return current as ScrollContainer
		current = current.get_parent()
	return null


func _create_icon_shadow(icon_node: TextureRect) -> void:
	var shadow_node: TextureRect = icon_node.get_node_or_null("RarityShadow") as TextureRect
	if not shadow_node:
		shadow_node = TextureRect.new()
		shadow_node.name = "RarityShadow"
		shadow_node.show_behind_parent = true
		shadow_node.layout_mode = 1
		shadow_node.anchors_preset = PRESET_FULL_RECT
		shadow_node.offset_left = 2.0
		shadow_node.offset_top = 2.0
		shadow_node.offset_right = 2.0
		shadow_node.offset_bottom = 2.0
		shadow_node.expand_mode = icon_node.expand_mode
		shadow_node.stretch_mode = icon_node.stretch_mode
		shadow_node.modulate = Color(0, 0, 0, 0.75)
		shadow_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_node.add_child(shadow_node)
	shadow_node.texture = icon_node.texture


func _update_name(item: Dictionary) -> void:
	if name_label:
		name_label.text = str(item.get("name", ""))
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.clip_text = true


## عکسِ واقعیِ هر کاراکتر از روی item_id — قبلاً فقط image_path خوانده می‌شد که
## سرور خالی می‌فرستد، پس همه‌ی کارت‌ها عکسِ پیش‌فرضِ صحنه را داشتند (V6)
func _update_character_image(item: Dictionary) -> void:
	if not character_image:
		return
	var texture: Texture2D = null
	var item_id := str(item.get("item_id", item.get("id", ""))).strip_edges()
	if item_id != "":
		for folder in ART_FOLDERS:
			if ResourceLoader.exists(folder + item_id + ".png"):
				texture = load(folder + item_id + ".png")
				break
	if texture == null:
		texture = load_image_safely(str(item.get("icon", item.get("image_path", ""))))
	if texture:
		character_image.texture = texture


func _update_price(item: Dictionary) -> void:
	var label := _get_price_label()
	if not label:
		return
	var price: int = int(item.get("final_price", item.get("original_price", item.get("price", item.get("cost", 0)))))
	label.text = MissionArt.fa_grouped(price)
	# V10 ارقامِ هم‌تراز
	label.add_theme_font_override("font", MenuUI.FONT_NUM)
	label.add_theme_font_size_override("font_size", 21)


func _update_currency_icon(item: Dictionary) -> void:
	var icon_node := _get_currency_icon()
	if not icon_node:
		return
	var cost_type: String = str(item.get("cost_type", item.get("currency", "coins"))).to_lower().strip_edges()
	var icon_path: String = GEM_ICON_PATH if cost_type in ["gems", "gem"] else COIN_ICON_PATH
	var texture := load_image_safely(icon_path)
	if texture:
		icon_node.texture = texture


func load_image_safely(path: String) -> Texture2D:
	path = path.strip_edges()
	if path == "":
		return null
	if not path.begins_with("res://"):
		path = "res://" + path.trim_prefix("/")
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
