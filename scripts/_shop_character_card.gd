extends Control

## کارت نمایش آیتم فروشگاه (سکشن Characters)

signal buy_requested(item_data: Dictionary)
signal card_clicked(item_data: Dictionary)

const GEM_ICON_PATH := "res://assets/ui/gem_icon.png"
const COIN_ICON_PATH := "res://assets/ui/coin_icon.png"

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
var click_tween: Tween
var scroll_fade_tween: Tween

var _touch_start_pos: Vector2 = Vector2.ZERO
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

	if buy_button and not buy_button.pressed.is_connected(_on_buy_button_pressed):
		buy_button.pressed.connect(_on_buy_button_pressed)
	
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


# یافتن هوشمند نود آیکون ارز در صورت تفاوت ساختار صحنه
func _get_currency_icon() -> TextureRect:
	if currency_icon:
		return currency_icon
	
	var icon_node := find_child("TypeIcon", true, false) as TextureRect
	if not icon_node:
		icon_node = find_child("BuyIcon", true, false) as TextureRect
	
	currency_icon = icon_node
	return currency_icon


func _configure_child_mouse_filters() -> void:
	if background: background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if character_image: character_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if border_rect: border_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if name_label: name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rarity_icon: rarity_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup_card(item: Dictionary) -> void:
	current_item_data = item
	_update_name(item)
	_update_character_image(item)
	_update_price(item)
	_update_currency_icon(item)
	
	var raw_rarity: String = str(item.get("rarity", item.get("rarity_type", item.get("item_rarity", "rare")))).to_lower()
	_apply_rarity_style(raw_rarity)


func _apply_rarity_style(rarity: String) -> void:
	var icon_color: Color
	var bg_top_color: Color
	var bg_bottom_color: Color

	match rarity:
		"epic":
			icon_color = Color.html("#f0abfc")
			bg_top_color = Color.html("#581c87")
			bg_bottom_color = Color.html("#1e0a2a")
		"legendary", "legend":
			icon_color = Color.html("#fef08a")
			bg_top_color = Color.html("#854d0e")
			bg_bottom_color = Color.html("#261400")
		_:
			icon_color = Color.html("#bae6fd")
			bg_top_color = Color.html("#0369a1")
			bg_bottom_color = Color.html("#031b2e")

	current_border_color = icon_color

	if rarity_icon:
		rarity_icon.visible = true
		rarity_icon.modulate = icon_color
		_create_icon_shadow(rarity_icon)

	if border_rect:
		border_rect.editor_only = false
		border_rect.border_color = current_border_color

	if background:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		gradient.colors = PackedColorArray([
			bg_top_color,
			bg_top_color.darkened(0.3),
			bg_bottom_color
		])

		var grad_texture := GradientTexture2D.new()
		grad_texture.gradient = gradient
		grad_texture.fill_to = Vector2(1, 1)

		background.texture = grad_texture


func _on_gui_input(event: InputEvent) -> void:
	var event_global_pos: Vector2 = global_position + event.position if "position" in event else Vector2.ZERO

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_start_pos = event_global_pos
			_is_swiping = false
		elif not _is_swiping:
			play_click_animation()
			card_clicked.emit(current_item_data)

	elif event is InputEventScreenTouch:
		if event.pressed:
			_touch_start_pos = event_global_pos
			_is_swiping = false
		elif not _is_swiping:
			play_click_animation()
			card_clicked.emit(current_item_data)

	elif event is InputEventScreenDrag:
		if event_global_pos.distance_to(_touch_start_pos) > DRAG_THRESHOLD:
			_is_swiping = true
		if _is_swiping and _parent_scroll:
			_parent_scroll.scroll_vertical -= int(event.relative.y)
			_parent_scroll.scroll_horizontal -= int(event.relative.x)

	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		if event_global_pos.distance_to(_touch_start_pos) > DRAG_THRESHOLD:
			_is_swiping = true
		if _is_swiping and _parent_scroll:
			_parent_scroll.scroll_vertical -= int(event.relative.y)
			_parent_scroll.scroll_horizontal -= int(event.relative.x)


func _on_buy_button_pressed() -> void:
	buy_requested.emit(current_item_data)


func play_click_animation() -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(25)

	if click_tween and click_tween.is_running():
		click_tween.kill()

	click_tween = create_tween()

	var pop := click_tween.parallel()
	pop.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if character_image:
		pop.tween_property(character_image, "position:y", -14.0, 0.1)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			
	if border_rect:
		pop.tween_property(border_rect, "border_color", Color.WHITE, 0.1)

	var settle := click_tween.chain().parallel()
	settle.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
	if character_image:
		settle.tween_property(character_image, "position:y", 0.0, 0.25)\
			.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
			
	if border_rect:
		settle.tween_property(border_rect, "border_color", current_border_color, 0.25)


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
	tween.tween_interval(5.0)
	
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
		icon_node.add_child(shadow_node)

	shadow_node.texture = icon_node.texture


func _update_name(item: Dictionary) -> void:
	if name_label:
		name_label.text = str(item.get("name", ""))


func _update_character_image(item: Dictionary) -> void:
	if not character_image:
		return

	var raw_path: String = str(item.get("icon", item.get("image_path", "")))
	var texture := load_image_safely(raw_path)
	if texture:
		character_image.texture = texture


# بروزرسانی مستقیم قیمت (دریافتقیمت اصلی بدون اعمال درصد تخفیف)
func _update_price(item: Dictionary) -> void:
	var label := _get_price_label()
	if not label:
		return

	var price: int = int(item.get("original_price", item.get("price", item.get("cost", 0))))
	label.text = str(price)


# بروزرسانی آیکون ارز با بررسی بی‌حساسیت به حروف و پشتیبانی از gem/gems
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

	print("⚠️ عکس در این مسیر یافت نشد: ", path)
	return null
