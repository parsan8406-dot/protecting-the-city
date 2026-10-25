extends Node2D
## پرتوِ لیزر — سه ثانیه از جلوی بازیکن، رو به هر جا که نگاه می‌کند.
##
## هر فریم از نو تا اولین دیوار ری‌کست می‌شود (لایه‌ی ۱، فقط دیوار): پرتو از
## بدن‌ها رد می‌شود ولی از دیوار نه — همان قانونِ سرور (abilities.go).
## آنلاین فقط نمایش است و خسارت را سرور می‌دهد. آفلاین emit_ticks روشن
## می‌شود و هر ۰.۲۵ ثانیه سیگنالِ tick با همان پاره‌خط می‌آید تا صحنه خودش
## خسارت بزند.
##
## مثلِ گنبدِ محافظ فرزندِ ریشه‌ی صحنه است نه بازیکن، تا تیرگیِ Arena رویش
## نیفتد؛ هر فریم خودش را روی بازیکن می‌نشاند.

signal tick(from: Vector2, to: Vector2)

const MUZZLE := 38.0
const WALL_MASK := 1

var _target: Node2D = null
var _left := 0.0
var _total := 1.0
var _emit_ticks := false
var _tick_in := 0.0
var _ticks_left := 0
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _ray := PhysicsRayQueryParameters2D.new()


func setup(target: Node2D, seconds: float, emit_ticks := false) -> void:
	_target = target
	_left = maxf(seconds, 0.05)
	_total = _left
	_emit_ticks = emit_ticks
	_tick_in = 0.0
	_ticks_left = int(round(seconds / Abilities.LASER_TICK))
	_update_geometry()


func _ready() -> void:
	z_index = 14
	top_level = true
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	_ray.collision_mask = WALL_MASK


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target) or not _target.is_visible_in_tree() \
			or ("is_dead" in _target and _target.is_dead):
		queue_free()
		return
	_update_geometry()
	_left -= delta
	if _emit_ticks:
		_tick_in -= delta
		while _tick_in <= 0.0 and _ticks_left > 0:
			_tick_in += Abilities.LASER_TICK
			_ticks_left -= 1
			tick.emit(_target.global_position, _to)
	if _left <= 0.0:
		queue_free()
		return
	queue_redraw()


func _update_geometry() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var origin := _target.global_position
	var dir := Vector2.RIGHT.rotated(_target.global_rotation - PI * 0.5)
	_from = origin + dir * MUZZLE
	_to = origin + dir * Abilities.LASER_RANGE
	var world := get_world_2d()
	if world != null:
		_ray.from = origin
		_ray.to = _to
		var hit := world.direct_space_state.intersect_ray(_ray)
		if not hit.is_empty():
			_to = hit["position"]


func _draw() -> void:
	# پوشش: باز شدنِ سریع، خاموش شدنِ نرم در آخر
	var t := _total - _left
	var a := clampf(t / 0.12, 0.0, 1.0) * clampf(_left / 0.25, 0.0, 1.0)
	var flick := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.05)
	var w := Abilities.LASER_HALF_WIDTH * 2.0
	draw_line(_from, _to, Color(1.0, 0.18, 0.08, 0.22 * a), w * 2.4)
	draw_line(_from, _to, Color(1.0, 0.45, 0.12, 0.5 * a), w * 1.1)
	draw_line(_from, _to, Color(1.0, 0.85, 0.45, 0.85 * a), w * 0.45 * flick)
	draw_line(_from, _to, Color(1, 1, 1, 0.95 * a), w * 0.16)
	# دهانه
	draw_circle(_from, w * 0.9, Color(1.0, 0.5, 0.15, 0.35 * a))
	draw_circle(_from, w * 0.45, Color(1, 0.95, 0.8, 0.8 * a))
	# محلِ برخورد با دیوار: جرقه
	draw_circle(_to, w * 1.1 * flick, Color(1.0, 0.35, 0.1, 0.35 * a))
	draw_circle(_to, w * 0.5, Color(1, 0.9, 0.7, 0.8 * a))
	var dir := (_to - _from).normalized()
	for i in 5:
		var ang := dir.angle() + PI + randf_range(-1.1, 1.1)
		var len := randf_range(10.0, 28.0)
		draw_line(_to, _to + Vector2.from_angle(ang) * len, Color(1, 0.8, 0.4, 0.7 * a), 2.0)
