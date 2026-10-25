class_name CityEmblem
extends Control
## نشان (پروفایل) شهر — یک سپر شش‌ضلعی رنگی با یک نماد وسطش.
##
## تصویر جدا ندارد؛ با draw کشیده می‌شود تا حجم APK بالا نرود. رهبر شهر
## نماد و رنگ را در دیالوگ «ویرایش شهر» انتخاب می‌کند و روی سرور در
## فیلد icon_path به شکل "emblem:<نماد>:<رنگ>" ذخیره می‌شود
## (سرور همین الگو را در validClanIcon چک می‌کند). خالی = نشان پیش‌فرض.

const SYMBOLS: Array[Texture2D] = [
	preload("res://assets/ui/profile_menu/icon_clan.svg"),
	preload("res://assets/icons/missions/icon_crown.svg"),
	preload("res://assets/icons/missions/icon_star.svg"),
	preload("res://assets/icons/missions/icon_emblem.svg"),
	preload("res://assets/ui/profile_menu/icon_kills.svg"),
	preload("res://assets/ui/profile_menu/icon_wins.svg"),
	preload("res://assets/ui/profile_menu/icon_grenade.svg"),
	preload("res://assets/ui/profile_menu/icon_achievement.svg"),
]

const COLORS: Array[Color] = [
	Color(0.24, 0.55, 1.0),
	Color(0.96, 0.7, 0.16),
	Color(0.95, 0.27, 0.25),
	Color(0.25, 0.8, 0.42),
	Color(0.65, 0.42, 1.0),
	Color(0.18, 0.8, 0.84),
]

var symbol := 0
var color_index := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

## "emblem:3:1" → Vector2i(3, 1). هر چیز نامعتبر → نشان پیش‌فرض (0, 0)
static func parse(icon_path: String) -> Vector2i:
	var parts := icon_path.strip_edges().split(":")
	if parts.size() != 3 or parts[0] != "emblem":
		return Vector2i.ZERO
	if not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return Vector2i.ZERO
	return Vector2i(
		clampi(parts[1].to_int(), 0, SYMBOLS.size() - 1),
		clampi(parts[2].to_int(), 0, COLORS.size() - 1))

static func encode(symbol_index: int, color: int) -> String:
	return "emblem:%d:%d" % [symbol_index, color]

func set_icon(icon_path: String) -> void:
	var v := parse(icon_path)
	set_emblem(v.x, v.y)

func set_emblem(symbol_index: int, color: int) -> void:
	symbol = clampi(symbol_index, 0, SYMBOLS.size() - 1)
	color_index = clampi(color, 0, COLORS.size() - 1)
	queue_redraw()

func get_icon_path() -> String:
	return encode(symbol, color_index)

func _hex(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(60.0 * i - 90.0)
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	return points

func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 2.0:
		return
	var c := size * 0.5
	var r := side * 0.5
	var tint: Color = COLORS[color_index]

	# هاله، حاشیه‌ی رنگی، حاشیه‌ی تیره‌ی داخلی، و زمینه
	draw_colored_polygon(_hex(c, r), Color(tint.r, tint.g, tint.b, 0.22))
	draw_colored_polygon(_hex(c, r * 0.9), tint)
	draw_colored_polygon(_hex(c, r * 0.8), Color(0.02, 0.04, 0.08, 1.0))
	draw_colored_polygon(_hex(c, r * 0.72), tint.darkened(0.72))

	# نیمه‌ی بالایی کمی روشن‌تر — حس برجستگی
	var top := _hex(c, r * 0.72)
	var shine := PackedVector2Array([top[5], top[0], top[1], c])
	draw_colored_polygon(shine, Color(1, 1, 1, 0.06))

	var tex: Texture2D = SYMBOLS[symbol]
	var icon_side := side * 0.44
	var rect := Rect2(c - Vector2(icon_side, icon_side) * 0.5, Vector2(icon_side, icon_side))
	draw_texture_rect(tex, rect, false, Color.WHITE.lerp(tint, 0.25))
