extends RefCounted
## لابی در چند ثانیه‌ی اول «زنده» و مرتب دیده شود (V8 زیبایی-کاربردپذیری).
##
## دو کار، هر دو ارزان (فقط Tween روی transform و modulate — هیچ چیزی در
## _process نیست):
##   ۱) play(): ورودِ پلکانیِ بخش‌های منو — ستونِ چپ از چپ، ستونِ راست از
##      راست، نوارِ پایین از پایین. هر قطعه ≤۲۵۰ms و ورودی را قفل نمی‌کند (V7).
##   ۲) living_background(): پس‌زمینه خیلی آرام زوم/جابه‌جا می‌شود و یک هاله‌ی
##      گرمِ کم‌رنگ از جلویش رد می‌شود — دید پیرامونی حرکت را می‌گیرد ولی
##      حواس را از «شروع» نمی‌برد (V4).
##
##   const INTRO := preload("res://scripts/psych_lobby_intro.gd")
##   INTRO.play(self)                 # بعد از اولین چیدمانِ ناحیه‌ی امن
##   INTRO.living_background(self, $Background)

const SLIDE := 44.0
const PIECE_TIME := 0.24
const STAGGER := 0.045

## زومِ آرامِ پس‌زمینه (Ken Burns) — یک رفت‌وبرگشتِ کامل ~۴۰ ثانیه
const DRIFT_SCALE := 1.055
const DRIFT_TIME := 20.0
## هاله‌ی گرمی که از چپ به راست رد می‌شود
const HAZE_TIME := 26.0
const HAZE_ALPHA := 0.10


## ورودِ پلکانیِ لابی. مسیرها نسبت به خودِ menu هستند؛ هر کدام نبود رد می‌شود.
static func play(menu: Control) -> void:
	if menu == null or not menu.is_inside_tree():
		return
	var delay := 0.0
	# نوارِ بالا: فقط محو → دیده (اطلاعاتِ ثابت، حرکت لازم ندارد)
	_fade(menu.get_node_or_null("TopBar") as CanvasItem, 0.0, 0.2)

	# ستونِ چپ: کلِ ستون از چپ می‌لغزد و دکمه‌ها یکی‌یکی روشن می‌شوند
	var column := menu.get_node_or_null("VBoxContainer") as Control
	if column != null:
		_slide(column, Vector2(-SLIDE, 0), 0.0)
		for child in column.get_children():
			if child is CanvasItem:
				_fade(child, delay, PIECE_TIME)
				delay += STAGGER

	# شخصیت را خودِ منو بعد از رسیدنِ اسکینِ واقعی نشان می‌دهد (main_menu.gd)

	# ستونِ راست، از بالا به پایین؛ «شروع» آخر از همه و با یک پاپِ کوچک (V5)
	var right_delay := 0.04
	for path in ["dailyMissions", "BattlepassBox", "TypeButton"]:
		var c := menu.get_node_or_null(path) as Control
		if c != null:
			_slide(c, Vector2(SLIDE, 0), right_delay)
			_fade(c, right_delay, PIECE_TIME)
			right_delay += STAGGER
	var start := menu.get_node_or_null("StartButton") as Control
	if start != null:
		_slide(start, Vector2(SLIDE, 0), right_delay)
		_fade(start, right_delay, PIECE_TIME)
		_pop(start, right_delay + 0.12)

	var bottom := menu.get_node_or_null("BottomMenu") as Control
	if bottom != null:
		_slide(bottom, Vector2(0, 26), 0.08)
		_fade(bottom, 0.08, PIECE_TIME)

	var goal := menu.get_node_or_null("NextGoalSlot") as CanvasItem
	if goal != null:
		_fade(goal, delay + 0.05, PIECE_TIME)


## پس‌زمینه‌ی زنده: زومِ خیلی آرام + هاله‌ی گرمِ رونده. bg باید تمام‌صفحه باشد.
static func living_background(menu: Control, bg: Control) -> void:
	if menu == null or bg == null:
		return
	var fit := func() -> void: bg.pivot_offset = bg.size * Vector2(0.55, 0.45)
	bg.resized.connect(fit)
	fit.call()
	var tw := bg.create_tween().set_loops()
	tw.tween_property(bg, "scale", Vector2(DRIFT_SCALE, DRIFT_SCALE), DRIFT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(bg, "scale", Vector2.ONE, DRIFT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# هاله: یک گرادیانِ شعاعیِ کوچک (۶۴px) که کشیده می‌شود — حجمِ تکسچر ناچیز
	var haze := TextureRect.new()
	haze.name = "LobbyHaze"
	haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haze.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	haze.stretch_mode = TextureRect.STRETCH_SCALE
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.62, 0.22, 1.0))
	grad.set_color(1, Color(0.85, 0.1, 0.08, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	haze.texture = gt
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	haze.material = mat
	haze.modulate.a = HAZE_ALPHA
	haze.anchor_top = 0.05
	haze.anchor_bottom = 0.95
	haze.anchor_left = -0.35
	haze.anchor_right = 0.25
	menu.add_child(haze)
	menu.move_child(haze, bg.get_index() + 1)
	var htw := haze.create_tween().set_loops()
	htw.tween_property(haze, "anchor_left", 0.75, HAZE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	htw.parallel().tween_property(haze, "anchor_right", 1.35, HAZE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	htw.tween_property(haze, "anchor_left", -0.35, HAZE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	htw.parallel().tween_property(haze, "anchor_right", 0.25, HAZE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ============================ قطعه‌ها ============================

static func _fade(c: CanvasItem, delay: float, time: float) -> void:
	if c == null:
		return
	c.modulate.a = 0.0
	var tw := c.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(c, "modulate:a", 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## از جای فعلی + offset به جای فعلی. جای نهایی همان لحظه خوانده می‌شود، پس
## باید بعد از چیدمانِ ناحیه‌ی امن صدا زده شود.
static func _slide(c: Control, offset: Vector2, delay: float) -> void:
	var target := c.position
	c.position = target + offset
	var tw := c.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(c, "position", target, PIECE_TIME + 0.04) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## پاپِ کوچکِ CTA بعد از رسیدن — یک بار، بعد فقط همان نفسِ هاله می‌ماند
static func _pop(c: Control, delay: float) -> void:
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void: c.pivot_offset = c.size * 0.5)
	tw.tween_property(c, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
