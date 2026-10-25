extends Node2D
## ردِ دویدن: چند سایه‌ی کم‌رنگ پشتِ بازیکن تا وقتی سرعتش بالاست.
## فقط چند دایره است، نه پارتیکل — روی گوشی تقریباً هزینه‌ای ندارد.

const SAMPLE := 0.035
const MAX_POINTS := 9
const COL := Color(0.35, 0.8, 1.0)

var _target: Node2D = null
var _left := 0.0
var _points: Array[Vector2] = []
var _sample_in := 0.0


func setup(target: Node2D, seconds: float) -> void:
	_target = target
	_left = seconds


func refresh(seconds: float) -> void:
	_left = maxf(_left, seconds)


func _ready() -> void:
	z_index = 3
	top_level = true
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat


func _process(delta: float) -> void:
	var alive := _target != null and is_instance_valid(_target) and _target.is_visible_in_tree()
	_left -= delta
	if alive and _left > 0.0:
		_sample_in -= delta
		if _sample_in <= 0.0:
			_sample_in = SAMPLE
			_points.push_front(_target.global_position)
			if _points.size() > MAX_POINTS:
				_points.pop_back()
	elif not _points.is_empty():
		# تمام شد: سایه‌ها یکی‌یکی محو می‌شوند
		_sample_in -= delta
		if _sample_in <= 0.0:
			_sample_in = SAMPLE
			_points.pop_back()
	else:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	for i in _points.size():
		var f := 1.0 - float(i) / float(MAX_POINTS)
		draw_circle(_points[i], 22.0 * f + 6.0, Color(COL.r, COL.g, COL.b, 0.16 * f))
	for i in range(1, _points.size()):
		var f := 1.0 - float(i) / float(MAX_POINTS)
		draw_line(_points[i - 1], _points[i], Color(1, 1, 1, 0.35 * f), 3.0 * f + 1.0)
