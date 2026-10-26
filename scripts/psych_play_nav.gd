extends RefCounted
## مسیریابیِ بات‌های «بازی سریع» — نسخه‌ی کلاینتیِ pathfind.go در سرور.
##
## بات‌های آفلاین قبلاً مستقیم به سمتِ بازیکن می‌دویدند و پشتِ اولین دیوار
## گیر می‌کردند؛ بازی خالی و بی‌جریان می‌شد (C5). این‌جا یک AStarGrid2D
## (کدِ بومیِ موتور، نه GDScript) یک بار از روی همان مستطیل‌های Arena ساخته
## می‌شود؛ هر خانه‌ای که دایره‌ی بدنِ بات در آن به دیوار بخورد بسته است.
## هر مسیریابی بعد از آن چند ده میکروثانیه است و بات فقط هر نیم‌ثانیه یک
## بار و آن هم فقط وقتی هدف را نمی‌بیند (یا گیر کرده) می‌پرسد.

const CELL := 24.0
## شعاعِ بدنِ بات (CircleShape ۵۸٫۵ × مقیاسِ ۰٫۵) + کمی حاشیه
const CLEARANCE := 34.0

var _grid: AStarGrid2D = null
var _size := Vector2i.ZERO


## از روی مستطیل‌های دیوار (Arena.wall_rects) و اندازه‌ی زمین ساخته می‌شود
func build(rects: Array, world_size: Vector2) -> void:
	_size = Vector2i(int(ceil(world_size.x / CELL)), int(ceil(world_size.y / CELL)))
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(Vector2i.ZERO, _size)
	_grid.cell_size = Vector2(CELL, CELL)
	_grid.offset = Vector2(CELL, CELL) * 0.5   # نقطه‌ها مرکزِ خانه‌اند
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	for r in rects:
		var grown: Rect2 = (r as Rect2).grow(CLEARANCE)
		var c0 := Vector2i(int(floor(grown.position.x / CELL)), int(floor(grown.position.y / CELL)))
		var c1 := Vector2i(int(ceil(grown.end.x / CELL)), int(ceil(grown.end.y / CELL)))
		for cy in range(maxi(c0.y, 0), mini(c1.y, _size.y)):
			for cx in range(maxi(c0.x, 0), mini(c1.x, _size.x)):
				# مرکزِ خانه باید واقعاً در حاشیه‌ی دیوار باشد (فاصله‌ی دایره تا مستطیل)
				var p := Vector2((cx + 0.5) * CELL, (cy + 0.5) * CELL)
				var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
				if p.distance_squared_to(q) < CLEARANCE * CLEARANCE:
					_grid.set_point_solid(Vector2i(cx, cy), true)


func is_ready() -> bool:
	return _grid != null


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / CELL), 0, _size.x - 1), clampi(int(p.y / CELL), 0, _size.y - 1))


## نزدیک‌ترین خانه‌ی باز — مبدأ یا مقصد ممکن است چسبیده به دیوار باشد
func _free_cell(p: Vector2) -> Vector2i:
	var c := _cell_of(p)
	if not _grid.is_point_solid(c):
		return c
	for ring in range(1, 8):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if absi(dx) != ring and absi(dy) != ring:
					continue
				var n := c + Vector2i(dx, dy)
				if _grid.is_in_boundsv(n) and not _grid.is_point_solid(n):
					return n
	return Vector2i(-1, -1)


## آیا این نقطه برای بدنِ یک بات جا دارد؟ (برای انتخابِ جای صندوق و تولد)
func is_free(p: Vector2) -> bool:
	if _grid == null:
		return true
	var c := _cell_of(p)
	return not _grid.is_point_solid(c)


## مسیر از from تا to (مرکزِ خانه‌ها، بدونِ نقطه‌ی اول). خالی یعنی راهی نیست.
func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if _grid == null:
		return PackedVector2Array()
	var a := _free_cell(from)
	var b := _free_cell(to)
	if a.x < 0 or b.x < 0:
		return PackedVector2Array()
	var pts := _grid.get_point_path(a, b, true)
	if pts.size() > 1:
		pts.remove_at(0)
	return pts
