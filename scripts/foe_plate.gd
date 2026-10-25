extends Node2D
## پلاکِ بالای سرِ حریف: نوار جان + آیکن اسلحه‌اش.
##
## top_level روشن است، پس ترنسفورمِ بازیکنِ حریف را به ارث نمی‌برد — نوار جان
## دیگر با چرخیدنِ حریف نمی‌چرخد و آیکن اسلحه همیشه صاف و خوانا می‌ماند.
## (نوار جانِ قدیمی بچه‌ی بدنه بود و با هر چرخش کج می‌شد.)

const FONT := preload("res://fonts/Lalezar-Regular.ttf")

const COL_TRACK := Color(0.06, 0.055, 0.07, 0.92)
const COL_EDGE  := Color(0.83, 0.66, 0.24, 0.75)
const COL_HIGH  := Color(0.35, 0.84, 0.45)
const COL_MID   := Color(0.95, 0.62, 0.18)
const COL_LOW   := Color(0.88, 0.17, 0.19)
const COL_TEXT  := Color(0.98, 0.96, 0.9)

## رنگِ قابِ پلاک بر اساس تیم. بدونِ این، هم‌تیمی و حریف عیناً یک‌شکل
## دیده می‌شوند و بازیکن اصلاً نمی‌فهمد کنارش دوست است یا دشمن.
const COL_ALLY_EDGE := Color(0.33, 0.74, 1.00, 0.95)
const COL_FOE_EDGE  := Color(0.93, 0.27, 0.32, 0.95)

## آیا این پلاک مالِ هم‌تیمی است؟ world.gd بعد از ساخت ست می‌کند.
var is_ally := false
var _edge_col := COL_EDGE

const BAR_W := 68.0
const BAR_H := 9.0
const OFFSET_Y := -98.0     # چقدر بالای سرِ حریف بنشیند

var _target: Node2D = null
var _hp := 1.0
var _text := ""
var _weapon: Texture2D = null


func setup(target: Node2D) -> void:
	_target = target
	top_level = true
	z_index = 20
	# نورِ صحنه نباید پلاک را تیره کند
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat


## تیمِ این بازیکن را ست می‌کند: آبی برای هم‌تیمی، قرمز برای حریف.
func set_team(ally: bool) -> void:
	is_ally = ally
	_edge_col = COL_ALLY_EDGE if ally else COL_FOE_EDGE
	queue_redraw()


func set_weapon(tex: Texture2D) -> void:
	_weapon = tex
	queue_redraw()


func set_health(current: int, maximum: int) -> void:
	var m := maxf(float(maximum), 1.0)
	_hp = clampf(float(current) / m, 0.0, 1.0)
	_text = "%d" % maxi(current, 0)
	queue_redraw()


func _process(_delta: float) -> void:
	if not is_instance_valid(_target):
		queue_free()
		return
	# صاف و بدون چرخش، همیشه بالای سرِ حریف
	global_position = _target.global_position + Vector2(0, OFFSET_Y)
	global_rotation = 0.0


func _fill_color() -> Color:
	if _hp > 0.55:
		return COL_HIGH
	elif _hp > 0.25:
		return COL_MID
	return COL_LOW


## StyleBoxها بینِ همه‌ی پلاک‌ها مشترک‌اند و هر _draw فقط رنگشان را عوض
## می‌کند. draw_style_box رأس‌ها را همان لحظه با رنگِ فعلی می‌سازد، پس
## عوض کردنِ رنگ برای پلاکِ بعدی روی کشیده‌ی قبلی اثری ندارد.
static var _sb_fill: StyleBoxFlat = null
static var _sb_frame: StyleBoxFlat = null


static func _boxes() -> void:
	if _sb_fill != null:
		return
	_sb_fill = StyleBoxFlat.new()
	_sb_fill.set_corner_radius_all(5)
	_sb_frame = StyleBoxFlat.new()
	_sb_frame.bg_color = Color(0, 0, 0, 0)
	_sb_frame.set_corner_radius_all(5)
	_sb_frame.set_border_width_all(3)


func _box(fill: Color) -> StyleBoxFlat:
	_sb_fill.bg_color = fill
	return _sb_fill


func _draw() -> void:
	_boxes()
	var x := -BAR_W * 0.5
	var track := Rect2(x, 0.0, BAR_W, BAR_H)
	draw_style_box(_box(COL_TRACK), track)

	# نشانِ تیم: مثلثِ رنگی درست بالای نوار.
	#
	# فقط قابِ نوار کافی نبود — در زمینِ تاریک و از فاصله، یک خطِ نازکِ
	# رنگی تقریباً دیده نمی‌شود. این مثلث از دور هم می‌گوید حریف است یا
	# هم‌تیمی، و همان رنگِ قاب را دارد پس دو تا زبانِ جدا نمی‌شود.
	var mk := 7.0
	var my := -30.0
	var tri := PackedVector2Array([
		Vector2(-mk, my - mk), Vector2(mk, my - mk), Vector2(0.0, my + mk)])
	draw_colored_polygon(tri, _edge_col)
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]),
		Color(0, 0, 0, 0.55), 1.5)
	if _hp > 0.0:
		draw_style_box(_box(_fill_color()), Rect2(x, 0.0, BAR_W * _hp, BAR_H))
	# قابِ رنگیِ تیم آخر از همه کشیده می‌شود، وگرنه با جانِ کامل نوارِ پر
	# رویش می‌افتد و رنگِ تیم اصلاً دیده نمی‌شود — دقیقاً همان چیزی که در
	# عکسِ آزمایش دیده شد: نوار سبزِ بی‌قاب.
	_sb_frame.border_color = _edge_col
	draw_style_box(_sb_frame, track)

	# عدد جان، کوچک و کنارِ نوار
	var fs := 12
	var tw := FONT.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tp := Vector2(-tw * 0.5, -3.0)
	draw_string(FONT, tp + Vector2(1, 1), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
	draw_string(FONT, tp, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, COL_TEXT)

	# آیکن اسلحه‌ی حریف، درست بالای نوار
	if _weapon != null:
		var ws := _weapon.get_size()
		var sc := minf(56.0 / maxf(ws.x, 1.0), 18.0 / maxf(ws.y, 1.0))
		var d := ws * sc
		draw_texture_rect(_weapon,
			Rect2(-d.x * 0.5, -d.y - 13.0, d.x, d.y), false, Color(1, 1, 1, 0.95))
