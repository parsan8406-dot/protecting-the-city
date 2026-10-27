extends RefCounted
## V2 زبانِ یکسانِ رده‌ی آیتم در کلِ فروشگاه — رنگ + شکل + اسم.
##
## قبلاً هر کارت پالتِ خودش را داشت (کمیابِ آبیِ تیره، آبیِ روشن، آبیِ فیروزه‌ای...)
## و رده فقط با رنگ گفته می‌شد؛ ۸٪ مردان کوررنگ‌اند. حالا یک پالت، و کنارِ رنگ
## تعدادِ لوزی‌ها (۱ کمیاب، ۲ حماسی، ۳ افسانه‌ای) و اسمِ فارسی هم می‌آید.
##
##   const Rarity := preload("res://scripts/psych_shop_rarity.gd")
##   Rarity.color("epic")  /  Rarity.badge("epic")  /  Rarity.pips("legend", 10)

const NAMES := {"common": "معمولی", "rare": "کمیاب", "epic": "حماسی", "legend": "افسانه‌ای"}
## رنگِ روشن (قاب، آیکن، متن)
const BRIGHT := {
	"common": Color("a7adb5"),
	"rare": Color("4dc3ff"),
	"epic": Color("d27bff"),
	"legend": Color("ffb321"),
}
## رنگِ تیره‌ی پس‌زمینه‌ی کارت (بالا) — پایینِ کارت از این تیره‌تر می‌شود
const DEEP := {
	"common": Color("2a2c30"),
	"rare": Color("0d3d6e"),
	"epic": Color("44107a"),
	"legend": Color("7a4306"),
}
## شکل: تعدادِ لوزی‌ها
const TIER := {"common": 0, "rare": 1, "epic": 2, "legend": 3}


## «legendary»، «Legend»، «» → یکی از چهار کلید
static func key(rarity) -> String:
	var r := str(rarity).strip_edges().to_lower()
	match r:
		"legend", "legendary", "افسانه‌ای":
			return "legend"
		"epic", "حماسی":
			return "epic"
		"rare", "کمیاب":
			return "rare"
	return "common"


static func of(item: Dictionary) -> String:
	return key(item.get("rarity", item.get("rarety", item.get("rarity_type", ""))))


static func color(rarity) -> Color:
	return BRIGHT[key(rarity)]


static func deep(rarity) -> Color:
	return DEEP[key(rarity)]


static func name_fa(rarity) -> String:
	return NAMES[key(rarity)]


## گرادیانِ عمودیِ پس‌زمینه‌ی کارت: رنگِ رده بالا، تقریباً سیاه پایین
static func gradient(rarity, radial: bool = false) -> GradientTexture2D:
	var top := deep(rarity)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([top.lightened(0.08), top.darkened(0.35), Color(0.03, 0.03, 0.04)])
	var t := GradientTexture2D.new()
	t.gradient = g
	if radial:
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.35)
		t.fill_to = Vector2(0.5, 1.1)
	else:
		t.fill_from = Vector2(0.5, 0.0)
		t.fill_to = Vector2(0.5, 1.0)
	return t


## هاله‌ی نرمِ پشتِ عکسِ آیتم (V6 سیلوئت روی زمینه‌ی کم‌کنتراست)
static func glow(rarity, strength: float = 0.55) -> GradientTexture2D:
	var c := color(rarity)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(c, strength), Color(c, strength * 0.25), Color(c, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 128
	t.height = 128
	return t


## نشانِ رده: کپسولِ مشکی با قابِ رنگی، لوزی‌ها و اسم. هیچ لمسی نمی‌گیرد.
static func badge(rarity, font_size: int = 13) -> PanelContainer:
	var r := key(rarity)
	var c := color(r)
	var pill := PanelContainer.new()
	pill.name = "RarityBadge"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.03, 0.82)
	sb.border_color = Color(c, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(font_size))
	sb.content_margin_left = font_size * 0.6
	sb.content_margin_right = font_size * 0.6
	sb.content_margin_top = 1.0
	sb.content_margin_bottom = 1.0
	pill.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", int(font_size * 0.4))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	pill.add_child(row)
	if TIER[r] > 0:
		row.add_child(pips(r, font_size * 0.62))
	var l := Label.new()
	l.text = NAMES[r]
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", MenuUI.FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", c.lightened(0.25))
	row.add_child(l)
	return pill


## فقط لوزی‌ها (برای جاهای خیلی تنگ مثل گوشه‌ی کارت)
static func pips(rarity, side: float = 8.0) -> Control:
	var p := _Pips.new()
	p.tier = TIER[key(rarity)]
	p.tint = color(rarity)
	p.side = side
	p.custom_minimum_size = Vector2(maxf(1.0, p.tier) * (side + 2.0), side + 4.0)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


class _Pips extends Control:
	var tier := 1
	var tint := Color.WHITE
	var side := 8.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var h := side * 0.5
		var step := side + 2.0
		var x0 := (size.x - step * tier) * 0.5 + step * 0.5
		var cy := size.y * 0.5
		for i in tier:
			var cx := x0 + step * i
			var pts := PackedVector2Array([Vector2(cx, cy - h - 1.0), Vector2(cx + h, cy),
				Vector2(cx, cy + h + 1.0), Vector2(cx - h, cy)])
			# سایه‌ی سیاه زیرِ لوزی تا روی هر زمینه‌ای خوانا بماند
			draw_colored_polygon(pts, Color(0, 0, 0, 0.7))
			var inner := PackedVector2Array()
			for v in pts:
				inner.append(Vector2(cx, cy) + (v - Vector2(cx, cy)) * 0.72)
			draw_colored_polygon(inner, tint)
