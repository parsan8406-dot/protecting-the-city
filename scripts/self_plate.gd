extends Node2D
## پلاکِ بالای سرِ خودِ بازیکن: نشانِ سطح، عددِ جان، نوارِ سبزِ جان و زیرش
## نوارِ آبیِ فشنگ — همان دو چیزی که کارتِ پروفایل نشان می‌دهد، تا وسطِ
## درگیری لازم نباشد چشم از کاراکتر برداری.
##
## مثلِ foe_plate روی top_level است: با چرخیدنِ بازیکن نمی‌چرخد و نورِ صحنه
## تیره‌اش نمی‌کند.

const FONT := preload("res://fonts/Lalezar-Regular.ttf")

const BAR_W := 76.0
const HP_H := 8.0
const AMMO_H := 4.0
const OFFSET_Y := -96.0

const COL_TRACK := Color(0.06, 0.055, 0.07, 0.92)
const COL_HP    := Color(0.35, 0.86, 0.42)
const COL_MID   := Color(0.95, 0.62, 0.18)
const COL_LOW   := Color(0.9, 0.18, 0.2)
const COL_AMMO  := Color(0.25, 0.65, 1.0)
const COL_OFF   := Color(0.2, 0.28, 0.4, 0.6)
const COL_GOLD  := Color(0.96, 0.78, 0.3)
const COL_TEXT  := Color(0.98, 0.96, 0.9)

var _target: Node2D = null
var _hp := 1.0
var _hp_text := ""
var _ammo := 0
var _ammo_max := 0
var _level := 1


func setup(target: Node2D) -> void:
	_target = target
	top_level = true
	z_index = 20
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	_level = maxi(int(Global.level), 1)


func set_health(current: int, maximum: int) -> void:
	_hp = clampf(float(current) / maxf(float(maximum), 1.0), 0.0, 1.0)
	_hp_text = "%s/%s" % [MissionArt.fa_number(maxi(current, 0)), MissionArt.fa_number(maximum)]
	queue_redraw()


func set_ammo(current: int, maximum: int) -> void:
	_ammo = current
	_ammo_max = maximum
	queue_redraw()


func set_level(level: int) -> void:
	_level = maxi(level, 1)
	queue_redraw()


func _process(_delta: float) -> void:
	if not is_instance_valid(_target):
		queue_free()
		return
	visible = _target.visible and _target.modulate.a > 0.05
	global_position = _target.global_position + Vector2(0, OFFSET_Y)
	global_rotation = 0.0


## دو StyleBoxِ ثابت (گوشه‌ی ۴ و ۳)؛ هر _draw فقط رنگشان را عوض می‌کند،
## نه اینکه هر بار Resourceِ تازه بسازد.
var _sb_r4: StyleBoxFlat = null
var _sb_r3: StyleBoxFlat = null


func _box(fill: Color, radius: int) -> StyleBoxFlat:
	if _sb_r4 == null:
		_sb_r4 = StyleBoxFlat.new()
		_sb_r4.set_corner_radius_all(4)
		_sb_r3 = StyleBoxFlat.new()
		_sb_r3.set_corner_radius_all(3)
	var sb := _sb_r4 if radius >= 4 else _sb_r3
	sb.bg_color = fill
	return sb


func _draw() -> void:
	var x := -BAR_W * 0.5 + 8.0
	# عددِ جان بالای نوار
	var fs := 13
	var tw := FONT.get_string_size(_hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tp := Vector2(x + (BAR_W - tw) * 0.5, -4.0)
	draw_string(FONT, tp + Vector2(1, 1), _hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.85))
	draw_string(FONT, tp, _hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COL_TEXT)

	# جان
	draw_style_box(_box(COL_TRACK, 4), Rect2(x - 1, -1, BAR_W + 2, HP_H + AMMO_H + 5))
	var hp_col := COL_HP if _hp > 0.55 else (COL_MID if _hp > 0.25 else COL_LOW)
	if _hp > 0.0:
		draw_style_box(_box(hp_col, 3), Rect2(x, 0, BAR_W * _hp, HP_H))
	if _hp > 0.0 and _hp <= 0.25:
		# جانِ بحرانی فقط با رنگ گفته نشود: مثلثِ «!» کنارِ نوار  # V2 color + shape
		var t := Vector2(x + BAR_W + 9.0, (HP_H + AMMO_H) * 0.5 + 1.0)
		var tri := PackedVector2Array([t + Vector2(0, -8), t + Vector2(7, 5), t + Vector2(-7, 5)])
		draw_colored_polygon(tri, COL_LOW)
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0, 0, 0, 0.85), 1.5, true)
		draw_line(t + Vector2(0, -4), t + Vector2(0, 0.5), COL_TEXT, 1.8)
		draw_circle(t + Vector2(0, 2.8), 1.0, COL_TEXT)

	# فشنگ: تکه‌تکه تا ۱۲ تا، بیشتر از آن پیوسته
	var ay := HP_H + 2.0
	if _ammo_max > 0 and _ammo_max <= 12:
		var gap := 1.5
		var seg := (BAR_W - gap * float(_ammo_max - 1)) / float(_ammo_max)
		for i in _ammo_max:
			draw_rect(Rect2(x + float(i) * (seg + gap), ay, seg, AMMO_H), COL_AMMO if i < _ammo else COL_OFF)
	elif _ammo_max > 0:
		draw_rect(Rect2(x, ay, BAR_W, AMMO_H), COL_OFF)
		draw_rect(Rect2(x, ay, BAR_W * float(_ammo) / float(_ammo_max), AMMO_H), COL_AMMO)

	# نشانِ سطح سمتِ چپ
	var c := Vector2(x - 12.0, (HP_H + AMMO_H) * 0.5 + 1.0)
	draw_circle(c, 11.0, Color(0.08, 0.07, 0.09, 0.95))
	draw_arc(c, 11.0, 0, TAU, 20, COL_GOLD, 2.0, true)
	var lv := MissionArt.fa_number(_level)
	var lw := FONT.get_string_size(lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(FONT, c + Vector2(-lw * 0.5, 5.0), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COL_GOLD)
