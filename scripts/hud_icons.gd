extends Object
class_name HudIcons
## آیکن‌های HUDِ زمینِ بازی.
##
## هر آیکن اول از res://assets/ui/hud/icon_<name>.png خوانده می‌شود؛ اگر آن
## فایل هنوز ساخته نشده، همین‌جا با چند خط و چندضلعی کشیده می‌شود تا HUD
## همین حالا کامل باشد. یعنی کافی است آرتِ نهایی را با همان اسم در آن پوشه
## بگذاری — هیچ کدی عوض نمی‌شود.
##
## نام‌ها: laser, bomb, run, shield, heal, team_heal, settings, pause, wifi,
## skull, people, hourglass, target, check, bullet

const DIR := "res://assets/ui/hud/"

## آرتِ این‌ها تمام‌رنگی است و رنگ نمی‌خورد؛ بقیه سفیدِ تک‌رنگ‌اند و با tint
## رنگ می‌گیرند (مثلاً وای‌فای با وضعیتِ پینگ سبز/زرد/قرمز می‌شود)
const FULL_COLOR := ["laser", "bomb", "run", "shield", "heal", "team_heal"]

static var _cache: Dictionary = {}


## آرتِ واقعیِ تمام‌رنگی دارد؟ (آن‌وقت فقط شفافیت اعمال می‌شود، نه رنگ)
static func is_full_color_art(name: String) -> bool:
	return name in FULL_COLOR and texture(name) != null


## آرتِ واقعیِ آیکن اگر ساخته شده باشد، وگرنه null
static func texture(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var path := "%sicon_%s.png" % [DIR, name]
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[name] = tex
	return tex


## آیکن را داخلِ rect می‌کشد. tint روی آرتِ واقعی هم اعمال می‌شود (سفید = بی‌تغییر).
static func draw(ci: CanvasItem, name: String, rect: Rect2, col: Color = Color.WHITE) -> void:
	var tex := texture(name)
	if tex != null:
		# آرت را با حفظِ نسبت داخلِ قاب جا بده
		var ts := tex.get_size()
		var k := minf(rect.size.x / maxf(ts.x, 1.0), rect.size.y / maxf(ts.y, 1.0))
		var d := ts * k
		ci.draw_texture_rect(tex, Rect2(rect.position + (rect.size - d) * 0.5, d), false, col)
		return
	match name:
		"laser": _laser(ci, rect, col)
		"bomb": _bomb(ci, rect, col)
		"run": _run(ci, rect, col)
		"shield": _shield(ci, rect, col)
		"heal": _potion(ci, rect, Color(0.93, 0.16, 0.2), false)
		"team_heal": _potion(ci, rect, Color(0.2, 0.62, 1.0), true)
		"settings": _gear(ci, rect, col)
		"pause": _pause(ci, rect, col)
		"wifi": _wifi(ci, rect, col)
		"skull": _skull(ci, rect, col)
		"people": _people(ci, rect, col)
		"hourglass": _hourglass(ci, rect, col)
		"target": _target(ci, rect, col)
		"check": _check(ci, rect, col)
		"bullet": _bullet(ci, rect, col)


# ------------------------------------------------------------------ ابزار

## نقطه‌ی (u, v) در مختصاتِ ۰..۱ داخلِ rect
static func _p(r: Rect2, u: float, v: float) -> Vector2:
	return r.position + Vector2(u * r.size.x, v * r.size.y)


static func _poly(r: Rect2, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(_p(r, q[0], q[1]))
	return out


static func _w(r: Rect2, f: float) -> float:
	return maxf(1.0, minf(r.size.x, r.size.y) * f)


# ------------------------------------------------------------------ آیکن‌ها

## تیغه‌ی نیزه‌ای رو به بالا-راست با ترکش‌های سرعت — دکمه‌ی لیزر
static func _laser(ci: CanvasItem, r: Rect2, c: Color) -> void:
	var blade := _poly(r, [[0.92, 0.08], [0.62, 0.22], [0.2, 0.7], [0.3, 0.8], [0.78, 0.38]])
	ci.draw_colored_polygon(blade, c)
	ci.draw_colored_polygon(_poly(r, [[0.92, 0.08], [0.66, 0.24], [0.76, 0.34]]), Color(1, 1, 1, c.a))
	# دسته
	ci.draw_line(_p(r, 0.25, 0.75), _p(r, 0.1, 0.9), c, _w(r, 0.09))
	# ترکش‌ها
	for s in [[0.12, 0.42, 0.3, 0.3], [0.5, 0.88, 0.66, 0.72], [0.05, 0.62, 0.16, 0.55]]:
		ci.draw_line(_p(r, s[0], s[1]), _p(r, s[2], s[3]), Color(c.r, c.g, c.b, c.a * 0.7), _w(r, 0.045))


## نارنجک: بدنه‌ی گرد، اهرم، حلقه‌ی ضامن
static func _bomb(ci: CanvasItem, r: Rect2, c: Color) -> void:
	var centre := _p(r, 0.46, 0.6)
	var rad := minf(r.size.x, r.size.y) * 0.3
	ci.draw_circle(centre, rad, c)
	ci.draw_circle(centre + Vector2(-rad * 0.35, -rad * 0.35), rad * 0.22, Color(1, 1, 1, 0.35 * c.a))
	ci.draw_colored_polygon(_poly(r, [[0.38, 0.2], [0.6, 0.2], [0.6, 0.34], [0.38, 0.34]]), c)
	ci.draw_polyline(_poly(r, [[0.6, 0.22], [0.8, 0.3], [0.78, 0.5]]), c, _w(r, 0.06))
	ci.draw_arc(_p(r, 0.3, 0.2), minf(r.size.x, r.size.y) * 0.09, 0, TAU, 14, c, _w(r, 0.04))


## آدمکِ دونده با خط‌های سرعت
static func _run(ci: CanvasItem, r: Rect2, c: Color) -> void:
	var w := _w(r, 0.08)
	ci.draw_circle(_p(r, 0.62, 0.16), minf(r.size.x, r.size.y) * 0.09, c)
	ci.draw_line(_p(r, 0.58, 0.3), _p(r, 0.46, 0.56), c, w)                        # تنه
	ci.draw_polyline(_poly(r, [[0.36, 0.3], [0.56, 0.32], [0.72, 0.46]]), c, w)      # دست‌ها
	ci.draw_polyline(_poly(r, [[0.46, 0.56], [0.64, 0.7], [0.58, 0.9]]), c, w)       # پای جلو
	ci.draw_polyline(_poly(r, [[0.46, 0.56], [0.34, 0.74], [0.18, 0.76]]), c, w)     # پای عقب
	var faint := Color(c.r, c.g, c.b, c.a * 0.6)
	for y in [0.38, 0.5, 0.62]:
		ci.draw_line(_p(r, 0.06, y), _p(r, 0.24, y), faint, _w(r, 0.04))


## سپر با خطِ میانی
static func _shield(ci: CanvasItem, r: Rect2, c: Color) -> void:
	var outer := _poly(r, [[0.5, 0.06], [0.86, 0.2], [0.82, 0.56], [0.5, 0.94], [0.18, 0.56], [0.14, 0.2]])
	ci.draw_colored_polygon(outer, c)
	var inner := _poly(r, [[0.5, 0.16], [0.76, 0.26], [0.73, 0.54], [0.5, 0.82], [0.27, 0.54], [0.24, 0.26]])
	ci.draw_colored_polygon(inner, Color(0, 0, 0, 0.28 * c.a))
	ci.draw_line(_p(r, 0.5, 0.2), _p(r, 0.5, 0.78), Color(1, 1, 1, 0.8 * c.a), _w(r, 0.05))
	ci.draw_line(_p(r, 0.32, 0.42), _p(r, 0.68, 0.42), Color(1, 1, 1, 0.8 * c.a), _w(r, 0.05))


## شیشه‌ی معجون — رنگی، مثلِ عکسِ مرجع. team=true یک «+» و دو سر هم دارد.
static func _potion(ci: CanvasItem, r: Rect2, liquid: Color, team: bool) -> void:
	var glass := Color(0.85, 0.9, 1.0, 0.35)
	var body := _p(r, 0.5, 0.64)
	var rad := minf(r.size.x, r.size.y) * 0.3
	ci.draw_circle(body, rad, glass)
	ci.draw_circle(body + Vector2(0, rad * 0.12), rad * 0.84, liquid)
	ci.draw_circle(body + Vector2(-rad * 0.35, -rad * 0.25), rad * 0.2, Color(1, 1, 1, 0.55))
	ci.draw_colored_polygon(_poly(r, [[0.42, 0.18], [0.58, 0.18], [0.58, 0.38], [0.42, 0.38]]), glass)
	ci.draw_colored_polygon(_poly(r, [[0.4, 0.1], [0.6, 0.1], [0.6, 0.2], [0.4, 0.2]]), Color(0.55, 0.36, 0.2))
	if team:
		var w := _w(r, 0.07)
		ci.draw_line(_p(r, 0.5, 0.52), _p(r, 0.5, 0.76), Color.WHITE, w)
		ci.draw_line(_p(r, 0.38, 0.64), _p(r, 0.62, 0.64), Color.WHITE, w)


## چرخ‌دنده‌ی تنظیمات
static func _gear(ci: CanvasItem, r: Rect2, c: Color) -> void:
	var centre := r.get_center()
	var s := minf(r.size.x, r.size.y)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var dir := Vector2.from_angle(a)
		ci.draw_line(centre + dir * s * 0.24, centre + dir * s * 0.44, c, s * 0.14)
	ci.draw_circle(centre, s * 0.3, c)
	ci.draw_circle(centre, s * 0.13, Color(0.06, 0.05, 0.07, 1.0))


static func _pause(ci: CanvasItem, r: Rect2, c: Color) -> void:
	ci.draw_rect(Rect2(_p(r, 0.28, 0.2), Vector2(r.size.x * 0.14, r.size.y * 0.6)), c)
	ci.draw_rect(Rect2(_p(r, 0.58, 0.2), Vector2(r.size.x * 0.14, r.size.y * 0.6)), c)


static func _wifi(ci: CanvasItem, r: Rect2, c: Color) -> void:
	var base := _p(r, 0.5, 0.86)
	var s := minf(r.size.x, r.size.y)
	ci.draw_circle(base, s * 0.08, c)
	for i in 3:
		var rad := s * (0.26 + 0.2 * float(i))
		ci.draw_arc(base, rad, -PI * 0.78, -PI * 0.22, 16, c, s * 0.09)


static func _skull(ci: CanvasItem, r: Rect2, c: Color) -> void:
	var s := minf(r.size.x, r.size.y)
	ci.draw_circle(_p(r, 0.5, 0.44), s * 0.36, c)
	ci.draw_colored_polygon(_poly(r, [[0.3, 0.62], [0.7, 0.62], [0.66, 0.88], [0.34, 0.88]]), c)
	var hole := Color(0.05, 0.04, 0.05, 1.0)
	ci.draw_circle(_p(r, 0.36, 0.46), s * 0.11, hole)
	ci.draw_circle(_p(r, 0.64, 0.46), s * 0.11, hole)
	ci.draw_colored_polygon(_poly(r, [[0.5, 0.58], [0.44, 0.7], [0.56, 0.7]]), hole)
	# دندان‌ها
	for u in [0.43, 0.57]:
		ci.draw_line(_p(r, u, 0.76), _p(r, u, 0.88), hole, maxf(1.0, s * 0.05))


## دو آدمک (سر و نیم‌تنه‌ی توپُر) — هم‌تیمی‌ها
static func _people(ci: CanvasItem, r: Rect2, c: Color) -> void:
	var s := minf(r.size.x, r.size.y)
	var back := Color(c.r * 0.7, c.g * 0.7, c.b * 0.7, c.a)
	_bust(ci, _p(r, 0.66, 0.3), s * 0.84, back)
	_bust(ci, _p(r, 0.4, 0.36), s, c)


## یک آدمک: سرِ گرد و شانه‌ی نیم‌دایره‌ای، با ابعادِ نسبی به s
static func _bust(ci: CanvasItem, head: Vector2, s: float, c: Color) -> void:
	ci.draw_circle(head, s * 0.16, c)
	var base := head + Vector2(0, s * 0.52)
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		pts.append(base + Vector2(cos(a) * s * 0.28, sin(a) * s * 0.3))
	ci.draw_colored_polygon(pts, c)


static func _hourglass(ci: CanvasItem, r: Rect2, c: Color) -> void:
	var w := _w(r, 0.08)
	ci.draw_line(_p(r, 0.22, 0.1), _p(r, 0.78, 0.1), c, w)
	ci.draw_line(_p(r, 0.22, 0.9), _p(r, 0.78, 0.9), c, w)
	ci.draw_polyline(_poly(r, [[0.3, 0.12], [0.3, 0.26], [0.5, 0.5], [0.3, 0.74], [0.3, 0.88]]), c, w * 0.6)
	ci.draw_polyline(_poly(r, [[0.7, 0.12], [0.7, 0.26], [0.5, 0.5], [0.7, 0.74], [0.7, 0.88]]), c, w * 0.6)
	ci.draw_colored_polygon(_poly(r, [[0.36, 0.84], [0.64, 0.84], [0.5, 0.64]]), c)


static func _target(ci: CanvasItem, r: Rect2, c: Color) -> void:
	var centre := r.get_center()
	var s := minf(r.size.x, r.size.y)
	ci.draw_arc(centre, s * 0.38, 0, TAU, 24, c, s * 0.08)
	ci.draw_arc(centre, s * 0.18, 0, TAU, 18, c, s * 0.08)
	ci.draw_circle(centre, s * 0.05, c)
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		ci.draw_line(centre + d * s * 0.3, centre + d * s * 0.5, c, s * 0.07)


static func _check(ci: CanvasItem, r: Rect2, c: Color) -> void:
	ci.draw_polyline(_poly(r, [[0.18, 0.52], [0.42, 0.76], [0.84, 0.26]]), c, _w(r, 0.16))


static func _bullet(ci: CanvasItem, r: Rect2, c: Color) -> void:
	ci.draw_colored_polygon(_poly(r, [[0.3, 0.35], [0.5, 0.05], [0.7, 0.35], [0.7, 0.95], [0.3, 0.95]]), c)
