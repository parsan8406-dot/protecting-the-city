extends Control
## صحنه‌ی نمایش بزرگِ آیتم در صفحه‌ی انتخاب کاراکتر/سلاح.
##
## V8 زیبایی-کاربردپذیری: هاله‌ی رنگِ کمیابی پشتِ آیتم، سکوی نوری زیرش و یک
## حرکتِ آرامِ «نفس کشیدن» تا صفحه زنده دیده شود. همه با Tween و _draw — نه
## شیدری در _process، نه پارتیکل.
## E17: لحظه‌ی ارتقا (حلقه‌ی طلایی + آیکن + «سطح ۳!») و E8: چیپ تسلط زیر آیتم.
##
## این نود اولین بچه‌ی Stage است (زیرِ عکس)؛ لایه‌ی جشن و چیپ‌ها را خودش
## بالای عکس می‌سازد. هیچ‌کدام لمس را نمی‌گیرند.
##
##   var fx := preload("res://scripts/psych_select_stage.gd").new()
##   fx.attach(stage, preview_image)

const GOLD := Color("ffc93c")
const PADLOCK_ART := "res://assets/ui/psych/tease_padlock.png"
const LEVEL_UP_ART := "res://assets/ui/psych/result_level_up.png"
const KILLS_ICON := preload("res://assets/ui/profile_menu/icon_kills.svg")
const FONT_NUM := preload("res://fonts/Lalezar-Regular.ttf")
const SFX := preload("res://scripts/psych_combat_sfx.gd")

## حاشیه‌ی عکس داخلِ صحنه (پایین جا برای چیپ تسلط)
const IMG_MARGIN := Vector4(18.0, 6.0, 18.0, 30.0)
## بزرگ‌نماییِ آرتِ کاراکتر روی صحنه
const CHAR_SCALE := 1.32

var _stage: Control
var _image: TextureRect
var _glow: TextureRect
var _glow_grad: Gradient
var _accent := GOLD
var _is_weapon := false
var _locked := false
var _loading := false

var _overlay: Control
var _chip: PanelContainer
var _chip_icon: TextureRect
var _chip_label: Label
var _lock_badge: TextureRect
var _celebrate_layer: _Burst

var _idle_tween: Tween
var _glow_tween: Tween
var _swap_tween: Tween
var _sfx_player: AudioStreamPlayer


func attach(stage: Control, image: TextureRect) -> void:
	_stage = stage
	_image = image
	name = "StageFx"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(self)
	stage.move_child(self, 0)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# هاله‌ی شعاعی پشت آیتم
	_glow_grad = Gradient.new()
	_glow_grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	_glow_grad.colors = PackedColorArray([Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.24), Color(1, 1, 1, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = _glow_grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	_glow = TextureRect.new()
	_glow.texture = tex
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_glow)
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_image_offsets(0.0)
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_overlay()
	resized.connect(func() -> void:
		queue_redraw()
		if _idle_tween == null:
			_apply_image_offsets(0.0))


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.name = "StageOverlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# E8: چیپ تسلط پایینِ صحنه، روی سکو
	_chip = PanelContainer.new()
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cs := MenuUI.box(Color(0.03, 0.02, 0.02, 0.86), Color(GOLD, 0.55), 1, 14)
	cs.content_margin_left = 12
	cs.content_margin_right = 12
	cs.content_margin_top = 3
	cs.content_margin_bottom = 3
	_chip.add_theme_stylebox_override("panel", cs)
	var chip_holder := CenterContainer.new()
	chip_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(chip_holder)
	chip_holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	chip_holder.offset_top = -30.0
	chip_holder.offset_bottom = -2.0
	chip_holder.add_child(_chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.add_child(row)
	_chip_label = Label.new()
	_chip_label.add_theme_font_override("font", FONT_NUM)
	_chip_label.add_theme_font_size_override("font_size", 16)
	_chip_label.add_theme_color_override("font_color", GOLD)
	_chip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_chip_label)
	_chip_icon = MenuUI.icon(KILLS_ICON, 18, GOLD)
	row.add_child(_chip_icon)
	_chip.visible = false

	# E12: قفلِ تیزر گوشه‌ی صحنه
	if ResourceLoader.exists(PADLOCK_ART):
		_lock_badge = TextureRect.new()
		_lock_badge.texture = load(PADLOCK_ART)
		_lock_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lock_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_lock_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_overlay.add_child(_lock_badge)
		_lock_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_lock_badge.offset_left = -50.0
		_lock_badge.offset_right = -4.0
		_lock_badge.offset_top = 2.0
		_lock_badge.offset_bottom = 48.0
		_lock_badge.visible = false

	_celebrate_layer = _Burst.new()
	_overlay.add_child(_celebrate_layer)
	_celebrate_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# -----------------------------------------------------------------------------
# نمایش آیتم
# -----------------------------------------------------------------------------

## آیتم تازه روی صحنه: ورود کوتاه از پایین + رنگ هاله + حالت قفل
func show_item(texture: Texture2D, accent: Color, locked: bool, is_weapon: bool) -> void:
	_loading = false
	_accent = accent
	_locked = locked
	_is_weapon = is_weapon
	_image.texture = texture
	_set_glow_color(accent, locked)
	if _lock_badge:
		_lock_badge.visible = locked
	# E12: قفل = دیده می‌شود ولی هنوز «مال تو» نیست — کمی خاموش‌تر
	_image.self_modulate = Color(0.72, 0.72, 0.76, 1.0) if locked else Color.WHITE
	queue_redraw()

	if _swap_tween and _swap_tween.is_valid():
		_swap_tween.kill()
	_image.modulate.a = 0.0
	_swap_tween = create_tween().set_parallel(true)
	_swap_tween.tween_property(_image, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE)
	_swap_tween.tween_method(_apply_image_offsets, 14.0, 0.0, 0.26) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_swap_tween.chain().tween_callback(_start_idle)


func clear_item() -> void:
	_image.texture = null
	if _lock_badge:
		_lock_badge.visible = false
	set_chip("")
	_stop_idle()


## C12: اسکلتِ لودینگ — هاله‌ی خاکستری که آرام نفس می‌کشد
func set_loading(on: bool) -> void:
	_loading = on
	if on:
		clear_item()
		_set_glow_color(Color(0.6, 0.6, 0.65), true)
	queue_redraw()


## چیپ تسلط («کارکشته · ۴۰ کیل»). خالی = مخفی.
func set_chip(text: String, show_icon: bool = true) -> void:
	_chip.visible = text != ""
	_chip_label.text = text
	_chip_icon.visible = show_icon


func _set_glow_color(accent: Color, dim: bool) -> void:
	var c := accent.lerp(Color(0.55, 0.55, 0.58), 0.75) if dim else accent
	_glow.modulate = Color(c.r, c.g, c.b, 0.55 if dim else 0.9)
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	# هاله آرام بالا و پایین می‌رود (۲.۴ ثانیه) — حرکتِ پیرامونیِ کم، نه چشمک
	var base := _glow.modulate.a
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(_glow, "modulate:a", base * 0.62, 1.2).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_property(_glow, "modulate:a", base, 1.2).set_trans(Tween.TRANS_SINE)


# -----------------------------------------------------------------------------
# حرکتِ ایستا (idle)
# -----------------------------------------------------------------------------

func _apply_image_offsets(dy: float) -> void:
	if _image == null:
		return
	_image.offset_left = IMG_MARGIN.x
	_image.offset_top = IMG_MARGIN.y + dy
	_image.offset_right = -IMG_MARGIN.z
	_image.offset_bottom = -IMG_MARGIN.w + dy
	# آرتِ کاراکترها حاشیه‌ی شفافِ زیادی دارد: از پایین-وسط بزرگ‌تر کشیده
	# می‌شود تا روی سکو بایستد و صحنه را پر کند (V8)
	_image.pivot_offset = Vector2(_image.size.x * 0.5, _image.size.y)
	var k := 1.0
	if not _is_weapon:
		# روی صحنه‌ی بلند (4:3) آرت خودش بزرگ است — از بالای صحنه بیرون نزند
		var h := size.y
		k = clampf(h / maxf(1.0, h - IMG_MARGIN.y - IMG_MARGIN.w), 1.0, CHAR_SCALE) if h > 1.0 else 1.0
	_image.scale = Vector2(k, k)


## V7: آیتم آرام بالا و پایین می‌رود — اسلحه کمتر، کاراکتر کمی بیشتر
func _start_idle() -> void:
	_stop_idle()
	if not is_inside_tree():
		return
	var amp := 2.5 if _is_weapon else 4.0
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_method(_apply_image_offsets, 0.0, -amp, 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_method(_apply_image_offsets, -amp, 0.0, 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_idle() -> void:
	if _idle_tween and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null
	_apply_image_offsets(0.0)


## سکوی نوری بیضی زیر آیتم
func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 4.0 or h < 4.0:
		return
	var c := _accent if not (_locked or _loading) else Color(0.55, 0.55, 0.6)
	var center := Vector2(w * 0.5, h - IMG_MARGIN.w * 0.55)
	var rx := minf(w * 0.30, 190.0)
	var ry := maxf(6.0, rx * 0.15)
	draw_set_transform(center, 0.0, Vector2(1.0, ry / rx))
	# سایه‌ی نرم: چند دایره‌ی هم‌مرکز کم‌رنگ
	for i in 5:
		var t := float(i) / 4.0
		draw_circle(Vector2.ZERO, rx * (1.0 - t * 0.55), Color(c.r, c.g, c.b, 0.03 + t * 0.04))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# لبه‌ی سکو: بیضیِ نازک (بدون transform تا ضخامت خط یکسان بماند)
	var pts := PackedVector2Array()
	for i in 49:
		var ang := TAU * float(i) / 48.0
		pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_polyline(pts, Color(c.r, c.g, c.b, 0.45), 2.0, true)


# -----------------------------------------------------------------------------
# جشنِ ارتقا (E17) — کوتاه، طلایی، بدون بلاک کردن لمس
# -----------------------------------------------------------------------------

func celebrate(level: int, gains: String) -> void:
	LocalSettings.vibrate(40)
	_play_sfx("multi3")

	# آیتم یک لحظه طلایی می‌درخشد و کمی بزرگ می‌شود
	var flash := create_tween()
	flash.tween_property(_image, "modulate", Color(1.7, 1.45, 0.9, 1.0), 0.08)
	flash.tween_property(_image, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE)
	_image.pivot_offset = _image.size * 0.5
	var pop := create_tween()
	pop.tween_property(_image, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_image, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_CUBIC)

	_celebrate_layer.play()

	# چیپِ تسلط چند لحظه کنار می‌رود تا «سطح ۳!» تنها پیامِ صحنه باشد (C1)
	var holder := _chip.get_parent() as Control
	var ch := holder.create_tween()
	ch.tween_property(holder, "modulate:a", 0.0, 0.1)
	ch.tween_interval(1.35)
	ch.tween_property(holder, "modulate:a", 1.0, 0.3)

	# آیکن «ارتقا» + «سطح ۳!» + سودی که گرفت
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	_overlay.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists(LEVEL_UP_ART):
		var icon := MenuUI.icon(load(LEVEL_UP_ART), minf(96.0, size.y * 0.42))
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)
	var title := Label.new()
	title.text = "سطح %s!" % MissionArt.fa_number(level)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT_NUM)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.0, 1.0))
	title.add_theme_constant_override("outline_size", 10)
	box.add_child(title)
	if gains != "":
		var sub := Label.new()
		sub.text = gains
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_override("font", FONT_NUM)
		sub.add_theme_font_size_override("font_size", 20)
		sub.add_theme_color_override("font_color", Color("9be29b"))
		sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		sub.add_theme_constant_override("outline_size", 7)
		box.add_child(sub)

	box.modulate.a = 0.0
	box.pivot_offset = size * 0.5
	box.scale = Vector2(0.6, 0.6)
	var t := box.create_tween().set_parallel(true)
	t.tween_property(box, "modulate:a", 1.0, 0.12)
	t.tween_property(box, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(0.9)
	t.chain().tween_property(box, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	t.chain().tween_callback(box.queue_free)


func _play_sfx(sound: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _sfx_player == null:
		_sfx_player = AudioStreamPlayer.new()
		_sfx_player.volume_db = -4.0
		if AudioServer.get_bus_index(&"SFX") >= 0:
			_sfx_player.bus = &"SFX"
		add_child(_sfx_player)
	_sfx_player.stream = SFX.get_stream(sound)
	_sfx_player.play()


## حلقه‌ی طلایی که از مرکز بیرون می‌زند + چند جرقه‌ی کوچک
class _Burst extends Control:
	var progress := 1.0:
		set(v):
			progress = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func play() -> void:
		progress = 0.0
		var t := create_tween()
		t.tween_property(self, "progress", 1.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func _draw() -> void:
		if progress >= 1.0:
			return
		var c := size * 0.5
		var r_max := minf(size.x, size.y) * 0.55
		var a := (1.0 - progress)
		var gold := Color(1.0, 0.8, 0.26)
		draw_arc(c, r_max * (0.25 + progress * 0.75), 0.0, TAU, 64, Color(gold, a * 0.9), lerpf(6.0, 1.5, progress), true)
		draw_arc(c, r_max * (0.1 + progress * 0.5), 0.0, TAU, 48, Color(1, 1, 1, a * 0.5), lerpf(3.0, 1.0, progress), true)
		for i in 10:
			var ang := TAU * float(i) / 10.0 + 0.3
			var d := r_max * (0.2 + progress * 0.85)
			draw_circle(c + Vector2(cos(ang), sin(ang)) * d, lerpf(4.0, 1.0, progress), Color(gold, a))
