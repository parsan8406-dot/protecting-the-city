extends Control
## مینی‌مپِ رادارِ گوشه‌ی بالا-راست.
##
## نقشه دورِ خودت می‌چرخد نه — شمال همیشه بالاست و تو وسطی. دیوارهای زمین،
## جهت‌های N/E/S/W، هم‌تیمی‌ها (آبی) و حریف‌ها (قرمز) کشیده می‌شوند.
##
## قانونِ رادار برای همه یکی است (Abilities.RADAR_RANGE): حریف فقط وقتی دیده
## می‌شود که داخلِ همین برد باشد؛ بیرونش هیچ نشانی ندارد. دایره‌ی خط‌چینِ
## وسط همان برد است تا بازیکن بداند تا کجا را می‌بیند.
##
## دیدِ مینی‌مپ کمی بزرگ‌تر از برد است تا هم‌تیمی‌های نزدیکِ لبه هم جا شوند.
## هم‌تیمی‌ها همیشه دیده می‌شوند؛ اگر بیرونِ قاب باشند روی لبه می‌نشینند.
##
## ده بار در ثانیه کشیده می‌شود، نه هر فریم — روی گوشی ارزان بماند.

const FONT := preload("res://fonts/Lalezar-Regular.ttf")

const COL_BG     := Color(0.04, 0.035, 0.05, 0.8)
const COL_EDGE   := Color(0.83, 0.64, 0.24, 0.9)
const COL_WALL   := Color(0.42, 0.38, 0.36, 0.95)
const COL_FLOOR  := Color(0.13, 0.11, 0.12, 0.9)
const COL_RADAR  := Color(0.96, 0.78, 0.3, 0.55)
const COL_ME     := Color(0.45, 0.85, 1.0)
const COL_ALLY   := Color(0.33, 0.74, 1.0)
const COL_FOE    := Color(0.95, 0.22, 0.26)
const COL_TEXT   := Color(0.95, 0.93, 0.88)
## شیطان: بنفشِ سرخ، تا با حریفِ قرمز و هم‌تیمیِ آبی اشتباه نشود
const COL_DEMON  := Color(0.86, 0.18, 0.62)
const COL_DEMON_HOT := Color(1.0, 0.72, 0.32)

## چند برابرِ بردِ رادار در قاب جا می‌شود (از مرکز تا لبه)
const VIEW_MARGIN := 1.18
const REFRESH := 0.1

## نودِ Arena (برای دیوارها) و بازیکنِ خودمان — world.gd ست می‌کند
var arena: Node = null
var me: Node2D = null
## تابعی که بازیگرانِ دیگر را برمی‌گرداند: [{pos: Vector2, ally: bool}]
var actors_source: Callable
## تابعی که جای شیطان را می‌دهد (Vector2) یا null — فقط «عملیات حذف شیطان».
## برخلافِ حریف‌ها، شیطان همیشه دیده می‌شود و بردِ رادار برایش معنی ندارد:
## هدفِ راند است و پنهان کردنش فقط بازیکن را سرگردان می‌کند.
var demon_source: Callable

var _t := 0.0
## پس‌زمینه و قاب یک بار ساخته می‌شوند، نه در هر _draw (ده بار در ثانیه)
var _sb_bg: StyleBoxFlat
var _sb_edge: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_sb_bg = StyleBoxFlat.new()
	_sb_bg.bg_color = COL_BG
	_sb_bg.set_corner_radius_all(10)
	_sb_edge = StyleBoxFlat.new()
	_sb_edge.bg_color = Color.TRANSPARENT
	_sb_edge.set_corner_radius_all(10)
	_sb_edge.set_border_width_all(2)
	_sb_edge.border_color = COL_EDGE


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = REFRESH
		queue_redraw()


func _scale() -> float:
	return (minf(size.x, size.y) * 0.5) / (Abilities.RADAR_RANGE * VIEW_MARGIN)


func _draw() -> void:
	if _sb_bg == null:
		return
	var half := size * 0.5
	draw_style_box(_sb_bg, Rect2(Vector2.ZERO, size))

	if me == null or not is_instance_valid(me):
		_draw_frame()
		return

	var centre: Vector2 = me.global_position
	var k := _scale()
	var to_map := func(p: Vector2) -> Vector2: return half + (p - centre) * k

	# --- زمین و دیوارها ---
	if arena != null and is_instance_valid(arena) and arena.has_method("wall_rects"):
		var ws: Vector2 = arena.world_size
		draw_rect(Rect2(to_map.call(Vector2.ZERO), ws * k), COL_FLOOR)
		var view := Rect2(centre - half / k, size / k)
		for r: Rect2 in arena.wall_rects():
			if view.intersects(r):
				draw_rect(Rect2(to_map.call(r.position), r.size * k), COL_WALL)

	# --- بردِ رادار ---
	var rr := Abilities.RADAR_RANGE * k
	draw_circle(half, rr, Color(COL_RADAR.r, COL_RADAR.g, COL_RADAR.b, 0.05))
	_dashed_circle(half, rr, COL_RADAR)
	# جاروبِ رادار: یک پرتوِ کم‌رنگ که می‌چرخد
	var sweep := fmod(Time.get_ticks_msec() * 0.0022, TAU)
	draw_line(half, half + Vector2.from_angle(sweep) * rr, Color(COL_RADAR.r, COL_RADAR.g, COL_RADAR.b, 0.35), 2.0)

	# --- شیطان ---
	# قبل از بقیه کشیده می‌شود تا نشانِ بازیکن‌ها رویش بیفتد، نه زیرش.
	_draw_demon(half, k, to_map)

	# --- بقیه ---
	if actors_source.is_valid():
		for a in actors_source.call():
			var pos: Vector2 = a.get("pos", centre)
			var ally: bool = a.get("ally", false)
			var d := pos.distance_to(centre)
			if ally:
				var mp: Vector2 = to_map.call(pos)
				# هم‌تیمیِ بیرونِ قاب روی لبه می‌نشیند
				var lim := half - Vector2(6, 6)
				var off := mp - half
				if absf(off.x) > lim.x or absf(off.y) > lim.y:
					var f := minf(lim.x / maxf(absf(off.x), 0.001), lim.y / maxf(absf(off.y), 0.001))
					mp = half + off * f
				draw_circle(mp, 5.0, Color(0, 0, 0, 0.6))
				draw_circle(mp, 4.0, COL_ALLY)
			elif d <= Abilities.RADAR_RANGE:
				var fp: Vector2 = to_map.call(pos)
				draw_circle(fp, 6.0, Color(COL_FOE.r, COL_FOE.g, COL_FOE.b, 0.3))
				draw_circle(fp, 4.0, COL_FOE)

	# --- خودم: پیکان رو به جهتِ نگاه ---
	var dir := Vector2.RIGHT.rotated(me.global_rotation - PI * 0.5)
	var side := dir.orthogonal()
	var tip := half + dir * 10.0
	draw_colored_polygon(PackedVector2Array([
		tip, half - dir * 6.0 + side * 7.0, half - dir * 2.0, half - dir * 6.0 - side * 7.0]), COL_ME)

	_draw_frame()


## نشانِ شیطان: یک ستاره‌ی تپنده، همیشه دیده می‌شود.
##
## اگر بیرونِ قاب باشد روی لبه می‌نشیند (مثل هم‌تیمی‌ها) و یک مثلثِ کوچک
## کنارش می‌گوید «آن‌طرف‌تر است، نه این‌جا» — تا با شیطانی که واقعاً نزدیک
## است اشتباه نشود.
func _draw_demon(half: Vector2, k: float, to_map: Callable) -> void:
	if not demon_source.is_valid():
		return
	var pos = demon_source.call()
	if pos == null:
		return

	var mp: Vector2 = to_map.call(pos)
	var lim := half - Vector2(10, 10)
	var off := mp - half
	var clamped := false
	if absf(off.x) > lim.x or absf(off.y) > lim.y:
		var f := minf(lim.x / maxf(absf(off.x), 0.001), lim.y / maxf(absf(off.y), 0.001))
		mp = half + off * f
		clamped = true

	var pulse := 0.82 + 0.18 * sin(Time.get_ticks_msec() * 0.004)
	# هاله
	draw_circle(mp, 11.0 * pulse, Color(COL_DEMON.r, COL_DEMON.g, COL_DEMON.b, 0.22))
	# ستاره‌ی پنج‌پر
	var star := PackedVector2Array()
	for i in 10:
		var ang := TAU * float(i) / 10.0 - PI * 0.5
		var r: float = (8.0 if i % 2 == 0 else 3.4) * pulse
		star.append(mp + Vector2(cos(ang), sin(ang)) * r)
	draw_colored_polygon(star, COL_DEMON)
	draw_circle(mp, 2.2, COL_DEMON_HOT)

	# روی لبه: یک مثلثِ کوچکِ رو به بیرون
	if clamped and off.length() > 0.001:
		var dir := off.normalized()
		var side := dir.orthogonal()
		draw_colored_polygon(PackedVector2Array([
			mp + dir * 14.0, mp + side * 4.5 + dir * 8.0, mp - side * 4.5 + dir * 8.0,
		]), COL_DEMON_HOT)


func _draw_frame() -> void:
	draw_style_box(_sb_edge, Rect2(Vector2.ZERO, size))
	# جهت‌ها
	var fs := 13
	var half := size * 0.5
	for item in [["N", Vector2(half.x, 14)], ["S", Vector2(half.x, size.y - 4)],
			["W", Vector2(9, half.y + 5)], ["E", Vector2(size.x - 9, half.y + 5)]]:
		var tw := FONT.get_string_size(item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p: Vector2 = item[1] - Vector2(tw * 0.5, 0)
		draw_string(FONT, p + Vector2(1, 1), item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
		draw_string(FONT, p, item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COL_TEXT)


func _dashed_circle(c: Vector2, r: float, col: Color) -> void:
	var n := 32
	for i in n:
		if i % 2 == 0:
			var a0 := TAU * float(i) / float(n)
			var a1 := TAU * float(i + 1) / float(n)
			draw_arc(c, r, a0, a1, 4, col, 1.5, true)
