extends Node2D
## حلقه‌ای که از یک نقطه باز می‌شود و محو می‌شود — مثلاً محدوده‌ی درمانِ تیمی،
## تا بازیکن ببیند چه کسانی داخلش بودند.

var _radius := 100.0
var _col := Color.WHITE
var _t := 0.0
const LIFE := 0.6


func setup(pos: Vector2, radius: float, col: Color) -> void:
	global_position = pos
	_radius = radius
	_col = col


func _ready() -> void:
	z_index = 3
	top_level = true
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var f := _t / LIFE
	var r := _radius * (1.0 - pow(1.0 - f, 3.0))
	var a := 1.0 - f
	draw_circle(Vector2.ZERO, r, Color(_col.r, _col.g, _col.b, 0.12 * a))
	draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(_col.r, _col.g, _col.b, 0.9 * a), 5.0 * a + 1.0, true)
