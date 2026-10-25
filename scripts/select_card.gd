extends Control
## کارت یک آیتم (کاراکتر یا سلاح) توی صفحه‌ی انتخاب.
##
## سه حالت دارد:
##   equipped — همین الان تجهیز شده: قاب طلایی نفس‌کش + چیپ «انتخاب شده»
##   owned    — خریده شده ولی تجهیز نیست: رنگی و قابل انتخاب
##   locked   — خریده نشده: خاکستری، تیره، غیرفعال (فقط پیام «قفل» می‌دهد)
##
## انیمیشن لمس عمداً «تیز» است نه کِش‌دار: یک فرو رفتن کوتاه، یک جهش کوتاه با
## نور مورب که از روی کارت رد می‌شود و یک حلقه‌ی طلایی که بیرون می‌زند و محو
## می‌شود. هیچ TRANS_ELASTIC ای در کار نیست تا حرکت شل به نظر نرسد.

signal card_selected(item: Dictionary)
signal locked_tapped(item: Dictionary)

const STATE_EQUIPPED := "equipped"
const STATE_OWNED := "owned"
const STATE_LOCKED := "locked"

const DRAG_THRESHOLD := 10.0

# پالت تم بازی: سیاه / قرمز / طلایی
const GOLD := Color("ffc93c")
const GOLD_DIM := Color("8a6a1a")
const LOCK_GRAY := Color("6e6e74")

# رنگ قاب و پس‌زمینه بر اساس کمیابی
const RARITY_STYLES := {
	"rare": {"border": Color("4dd2ff"), "top": Color("0b3c63"), "bottom": Color("04101d")},
	"epic": {"border": Color("e066ff"), "top": Color("46125e"), "bottom": Color("140420")},
	"legend": {"border": Color("ff9f2e"), "top": Color("5c3706"), "bottom": Color("1a0d00")},
	"legendary": {"border": Color("ff9f2e"), "top": Color("5c3706"), "bottom": Color("1a0d00")},
	"common": {"border": Color("8d8d94"), "top": Color("26262b"), "bottom": Color("0b0b0d")},
}

const GRAYSCALE_SHADER := """
shader_type canvas_item;

uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// COLOR از قبل «رنگِ vertex × تکسچر» است؛ ضربِ دوباره در تکسچر عکس را
	// به توانِ دو می‌برد و سیلوئتِ قفل تقریباً سیاه می‌شد (V6/E12)
	vec4 src = COLOR;
	float lum = dot(src.rgb, vec3(0.299, 0.587, 0.114));
	// خاکستریِ کمی تیره‌تر، تا آیتم قفل واقعاً «غیرفعال» دیده شود
	vec3 gray = vec3(lum) * 0.82;
	COLOR = vec4(mix(src.rgb, gray, amount), src.a);
}
"""

const SWEEP_SHADER := """
shader_type canvas_item;

uniform float progress : hint_range(-0.6, 1.6) = -0.6;
uniform vec4 sweep_color : source_color = vec4(1.0, 0.85, 0.45, 0.55);

void fragment() {
	float band = (UV.x + UV.y) * 0.5;
	float d = abs(band - progress);
	float a = smoothstep(0.13, 0.0, d);
	COLOR = vec4(sweep_color.rgb, a * sweep_color.a);
}
"""

@onready var frame: Panel = $Frame
@onready var item_image: TextureRect = $ItemImage
@onready var rarity_icon: TextureRect = $RarityIcon
@onready var name_label: Label = $NameLabel
@onready var status_chip: Panel = $StatusChip
@onready var status_label: Label = $StatusChip/StatusLabel

var item_data: Dictionary = {}
var state: String = STATE_LOCKED
## E12: شرطِ باز شدن روی چیپِ کارتِ قفل («۶٬۰۰۰ سکه») — خالی یعنی فقط «قفل»
var unlock_text := ""
var _padlock: TextureRect = null
const PADLOCK_ART := "res://assets/ui/psych/tease_padlock.png"

var _frame_style: StyleBoxFlat
var _chip_style: StyleBoxFlat
var _accent: Color = GOLD
var _gray_material: ShaderMaterial
var _sweep: ColorRect
var _sweep_material: ShaderMaterial
var _dim_overlay: ColorRect
var _pulse_ring: Panel
var _press_tween: Tween
var _glow_tween: Tween

var _touch_start := Vector2.ZERO
var _is_swiping := false
var _parent_scroll: ScrollContainer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)

	_build_frame_style()
	_build_chip_style()
	_build_grayscale_material()
	_build_dim_overlay()
	_build_sweep_layer()
	_build_pulse_ring()

	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)

	call_deferred("_find_parent_scroll")


# -----------------------------------------------------------------------------
# ساخت لایه‌های تصویری (همه در کد، تا صحنه سبک بماند)
# -----------------------------------------------------------------------------

func _build_frame_style() -> void:
	_frame_style = StyleBoxFlat.new()
	_frame_style.bg_color = Color("101014")
	_frame_style.set_border_width_all(2)
	_frame_style.border_color = GOLD_DIM
	_frame_style.set_corner_radius_all(16)
	_frame_style.shadow_color = Color(0, 0, 0, 0.55)
	_frame_style.shadow_size = 6
	_frame_style.shadow_offset = Vector2(0, 4)
	frame.add_theme_stylebox_override("panel", _frame_style)


func _build_chip_style() -> void:
	_chip_style = StyleBoxFlat.new()
	_chip_style.bg_color = Color(0, 0, 0, 0.6)
	_chip_style.set_border_width_all(1)
	_chip_style.border_color = GOLD_DIM
	_chip_style.set_corner_radius_all(9)
	status_chip.add_theme_stylebox_override("panel", _chip_style)


func _build_grayscale_material() -> void:
	var shader := Shader.new()
	shader.code = GRAYSCALE_SHADER
	_gray_material = ShaderMaterial.new()
	_gray_material.shader = shader
	_gray_material.set_shader_parameter("amount", 0.0)
	item_image.material = _gray_material


## پرده‌ی تیره‌ی روی کارت‌های قفل — زیر چیپ وضعیت می‌نشیند تا متن خوانا بماند
func _build_dim_overlay() -> void:
	_dim_overlay = ColorRect.new()
	_dim_overlay.name = "DimOverlay"
	_dim_overlay.color = Color(0, 0, 0, 0.2)
	_dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim_overlay.visible = false
	add_child(_dim_overlay)
	move_child(_dim_overlay, status_chip.get_index())


## نور موربی که موقع انتخاب از روی کارت رد می‌شود
func _build_sweep_layer() -> void:
	var shader := Shader.new()
	shader.code = SWEEP_SHADER
	_sweep_material = ShaderMaterial.new()
	_sweep_material.shader = shader
	_sweep_material.set_shader_parameter("progress", -0.6)

	_sweep = ColorRect.new()
	_sweep.name = "Sweep"
	_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sweep.material = _sweep_material
	_sweep.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_sweep)


## حلقه‌ای که موقع انتخاب از لبه‌ی کارت بیرون می‌زند و محو می‌شود
func _build_pulse_ring() -> void:
	var ring_style := StyleBoxFlat.new()
	ring_style.draw_center = false
	ring_style.set_border_width_all(3)
	ring_style.border_color = GOLD
	ring_style.set_corner_radius_all(18)

	_pulse_ring = Panel.new()
	_pulse_ring.name = "PulseRing"
	_pulse_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pulse_ring.add_theme_stylebox_override("panel", ring_style)
	_pulse_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pulse_ring.modulate.a = 0.0
	add_child(_pulse_ring)


# -----------------------------------------------------------------------------
# پر کردن کارت
# -----------------------------------------------------------------------------

func setup(data: Dictionary, card_state: String, texture: Texture2D, unlock := "") -> void:
	item_data = data
	state = card_state
	unlock_text = unlock

	if item_image:
		item_image.texture = texture
	if name_label:
		name_label.text = str(data.get("name", "")).strip_edges()

	var rarity: String = str(data.get("rarity", data.get("rarety", "common"))).to_lower().strip_edges()
	var style: Dictionary = RARITY_STYLES.get(rarity, RARITY_STYLES["common"])
	_accent = style["border"]

	_apply_state(style)


func _apply_state(style: Dictionary) -> void:
	var locked := state == STATE_LOCKED
	var equipped := state == STATE_EQUIPPED

	var top: Color = style["top"]
	var bottom: Color = style["bottom"]
	var border: Color = _accent

	if locked:
		# همان رنگ‌ها ولی بدون اشباع — کارت قفل باید بی‌جان دیده شود
		top = _to_gray(top)
		bottom = _to_gray(bottom)
		border = LOCK_GRAY

	_frame_style.bg_color = bottom
	_frame_style.border_color = GOLD if equipped else border
	_frame_style.set_border_width_all(3 if equipped else 2)
	_paint_frame_gradient(top, bottom)

	if rarity_icon:
		rarity_icon.modulate = LOCK_GRAY if locked else _accent
	if name_label:
		name_label.add_theme_color_override("font_color", Color("9d9da4") if locked else Color("f2e6cf"))

	if _gray_material:
		_gray_material.set_shader_parameter("amount", 1.0 if locked else 0.0)
	if item_image:
		# E12/V6: قفل یعنی سیلوئتِ تیزر — کم‌رنگ ولی هنوز قابلِ تشخیص
		item_image.modulate = Color(1, 1, 1, 0.9) if locked else Color.WHITE

	if _dim_overlay:
		_dim_overlay.visible = locked

	_apply_chip(locked, equipped)
	_set_equipped_glow(equipped)

	mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND


## Panel فقط رنگ ثابت می‌گیرد، پس شیب رنگی را با یک TextureRect زیر آن می‌سازیم
func _paint_frame_gradient(top: Color, bottom: Color) -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([top, bottom])

	var grad_texture := GradientTexture2D.new()
	grad_texture.gradient = gradient
	grad_texture.fill_from = Vector2(0.5, 0.0)
	grad_texture.fill_to = Vector2(0.5, 1.0)

	var fill: TextureRect = frame.get_node_or_null("Fill") as TextureRect
	if fill == null:
		fill = TextureRect.new()
		fill.name = "Fill"
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fill.stretch_mode = TextureRect.STRETCH_SCALE
		fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fill.offset_left = 2.0
		fill.offset_top = 2.0
		fill.offset_right = -2.0
		fill.offset_bottom = -2.0
		frame.add_child(fill)
	fill.texture = grad_texture


func _apply_chip(locked: bool, equipped: bool) -> void:
	if not status_label:
		return

	_set_padlock(locked)
	if locked:
		status_label.text = unlock_text if unlock_text != "" else "قفل"
		status_label.add_theme_color_override("font_color", Color("e6d6a8") if unlock_text != "" else Color("b9b9c0"))
		_chip_style.bg_color = Color(0, 0, 0, 0.72)
		_chip_style.border_color = LOCK_GRAY
	elif equipped:
		status_label.text = "انتخاب شده"
		status_label.add_theme_color_override("font_color", Color("101010"))
		_chip_style.bg_color = GOLD
		_chip_style.border_color = GOLD
	else:
		status_label.text = "انتخاب"
		status_label.add_theme_color_override("font_color", GOLD)
		_chip_style.bg_color = Color(0.12, 0.02, 0.03, 0.85)
		_chip_style.border_color = GOLD_DIM


## E12: قفلِ کوچکِ تیزر روی گوشه‌ی کارتِ قفل (اگر آرتش رسیده باشد)
func _set_padlock(on: bool) -> void:
	if _padlock == null:
		if not on or not ResourceLoader.exists(PADLOCK_ART):
			return
		_padlock = TextureRect.new()
		_padlock.name = "Padlock"
		_padlock.texture = load(PADLOCK_ART)
		_padlock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_padlock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_padlock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_padlock.set_anchors_preset(Control.PRESET_CENTER)
		_padlock.offset_left = -22.0
		_padlock.offset_right = 22.0
		_padlock.offset_top = -30.0
		_padlock.offset_bottom = 14.0
		_padlock.modulate = Color(1, 1, 1, 0.92)
		add_child(_padlock)
	_padlock.visible = on


## قاب طلایی کارتِ تجهیزشده آرام نفس می‌کشد تا از بقیه جدا بیفتد
func _set_equipped_glow(equipped: bool) -> void:
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
		_glow_tween = null

	if not equipped:
		_frame_style.shadow_color = Color(0, 0, 0, 0.55)
		_frame_style.shadow_size = 6
		return

	_frame_style.shadow_offset = Vector2.ZERO
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_method(_set_glow_amount, 0.0, 1.0, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glow_tween.tween_method(_set_glow_amount, 1.0, 0.0, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_glow_amount(t: float) -> void:
	if _frame_style == null:
		return
	_frame_style.shadow_color = Color(GOLD.r, GOLD.g, GOLD.b, lerpf(0.22, 0.55, t))
	_frame_style.shadow_size = int(lerpf(7.0, 14.0, t))


func _to_gray(color: Color) -> Color:
	var lum: float = color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	return Color(lum * 0.72, lum * 0.72, lum * 0.76, color.a)


# -----------------------------------------------------------------------------
# ورودی: تفکیک تپ از اسکرول (روی موبایل کل گرید با انگشت بالا/پایین می‌رود)
# -----------------------------------------------------------------------------

func _on_gui_input(event: InputEvent) -> void:
	var pos: Vector2 = global_position + event.position if "position" in event else Vector2.ZERO

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_touch(pos)
		elif not _is_swiping:
			_end_touch()

	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_touch(pos)
		elif not _is_swiping:
			_end_touch()

	elif event is InputEventScreenDrag:
		_handle_drag(pos, event.relative)

	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_handle_drag(pos, event.relative)


func _begin_touch(pos: Vector2) -> void:
	_touch_start = pos
	_is_swiping = false
	if state != STATE_LOCKED:
		_animate_press_down()


func _end_touch() -> void:
	if state == STATE_LOCKED:
		_animate_reject()
		locked_tapped.emit(item_data)
		return
	_animate_select()
	card_selected.emit(item_data)


func _handle_drag(pos: Vector2, relative: Vector2) -> void:
	if pos.distance_to(_touch_start) > DRAG_THRESHOLD and not _is_swiping:
		_is_swiping = true
		_animate_press_release()
	if _is_swiping and _parent_scroll:
		_parent_scroll.scroll_vertical -= int(relative.y)


func _find_parent_scroll() -> void:
	var current: Node = get_parent()
	while current:
		if current is ScrollContainer:
			_parent_scroll = current as ScrollContainer
			return
		current = current.get_parent()


# -----------------------------------------------------------------------------
# انیمیشن‌ها
# -----------------------------------------------------------------------------

func _kill_press_tween() -> void:
	if _press_tween and _press_tween.is_valid():
		_press_tween.kill()
		_press_tween = null


func _animate_press_down() -> void:
	_kill_press_tween()
	_press_tween = create_tween()
	_press_tween.tween_property(self, "scale", Vector2(0.94, 0.94), 0.06) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## انگشت روی کارت بوده ولی تبدیل به اسکرول شده — بی سر و صدا برگرد
func _animate_press_release() -> void:
	_kill_press_tween()
	_press_tween = create_tween()
	_press_tween.tween_property(self, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## انتخاب موفق: جهش کوتاه + نور مورب + حلقه‌ی طلایی
func _animate_select() -> void:
	LocalSettings.vibrate(18)

	_kill_press_tween()
	_press_tween = create_tween()
	_press_tween.tween_property(self, "scale", Vector2(1.07, 1.07), 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(self, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# تصویر آیتم یک پله بالا می‌پرد و سر جایش می‌نشیند
	if item_image:
		var lift := create_tween()
		lift.tween_property(item_image, "position:y", item_image.position.y - 9.0, 0.10) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		lift.tween_property(item_image, "position:y", item_image.position.y, 0.20) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_play_sweep()
	_play_pulse_ring()


func _play_sweep() -> void:
	if _sweep_material == null:
		return
	_sweep_material.set_shader_parameter("progress", -0.6)
	var tween := create_tween()
	tween.tween_method(
		func(value: float) -> void: _sweep_material.set_shader_parameter("progress", value),
		-0.6, 1.6, 0.38
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _play_pulse_ring() -> void:
	if _pulse_ring == null:
		return
	_pulse_ring.pivot_offset = size * 0.5
	_pulse_ring.scale = Vector2.ONE
	_pulse_ring.modulate.a = 0.9

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_pulse_ring, "scale", Vector2(1.16, 1.16), 0.34) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_pulse_ring, "modulate:a", 0.0, 0.34) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


## تپ روی کارت قفل: یک «نه» کوتاه و قاطع، بدون لرزش طولانی
func _animate_reject() -> void:
	LocalSettings.vibrate(25)

	_kill_press_tween()
	var base_x := position.x
	_press_tween = create_tween()
	_press_tween.tween_property(self, "position:x", base_x - 7.0, 0.05).set_trans(Tween.TRANS_SINE)
	_press_tween.tween_property(self, "position:x", base_x + 7.0, 0.07).set_trans(Tween.TRANS_SINE)
	_press_tween.tween_property(self, "position:x", base_x, 0.07).set_trans(Tween.TRANS_SINE)

	if _frame_style:
		var flash := create_tween()
		flash.tween_property(_frame_style, "border_color", Color("d33b3b"), 0.06)
		flash.tween_property(_frame_style, "border_color", LOCK_GRAY, 0.24)
