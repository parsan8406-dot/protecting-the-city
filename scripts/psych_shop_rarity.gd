extends RefCounted
## V2 زبانِ یکسانِ رده‌ی آیتم در کلِ فروشگاه — رنگ + شکل + اسم.
##
## قبلاً هر کارت پالتِ خودش را داشت (کمیابِ آبیِ تیره، آبیِ روشن، آبیِ فیروزه‌ای...)
## و رده فقط با رنگ گفته می‌شد؛ ۸٪ مردان کوررنگ‌اند. حالا یک پالت، و کنارِ رنگ
## تعدادِ لوزی‌ها (۱ کمیاب، ۲ حماسی، ۳ افسانه‌ای) و اسمِ فارسی هم می‌آید.
##
##   const Rarity := preload("res://scripts/psych_shop_rarity.gd")
##   Rarity.color("epic")  /  Rarity.badge("epic")  /  Rarity.pips("legend", 11)

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
		row.add_child(pips(r, roundf(font_size * 0.8)))
	var l := Label.new()
	l.text = NAMES[r]
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", MenuUI.FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", c.lightened(0.25))
	row.add_child(l)
	return pill


## فقط نشانِ رده (برای جاهای خیلی تنگ مثل گوشه‌ی کارت). side = ارتفاعِ هر نگین
static func pips(rarity, side: float = 11.0) -> Control:
	var p := _Pips.new()
	p.side = side
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	set_pips(p, rarity)
	return p


## رده‌ی یک نشانِ ساخته‌شده را عوض می‌کند (اندازه‌اش هم با تعدادِ نگین‌ها جور می‌شود)
static func set_pips(p: Control, rarity) -> void:
	if p == null:
		return
	var r := key(rarity)
	p.set("tier", TIER[r])
	p.set("tint", color(r))
	p.custom_minimum_size = p.call("needed_size")
	p.visible = TIER[r] > 0
	p.queue_redraw()


## نگینِ تراش‌خورده (تاج + کف + برقِ روی تاج) با قابِ تیره، نه لوزیِ ساده: لوزیِ
## کوچکِ کنارِ متنِ فارسی دقیقاً شکلِ «۰» بود و «کمیاب ۰» / «۰۰» خوانده می‌شد
class _Pips extends Control:
	var tier := 1
	var tint := Color.WHITE
	var side := 11.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func gem_w() -> float:
		return side * 1.15

	func step() -> float:
		return gem_w() + maxf(2.0, side * 0.22)

	func needed_size() -> Vector2:
		return Vector2(ceilf(step() * maxi(1, tier) - (step() - gem_w())) + 2.0, ceilf(side) + 2.0)

	func _draw() -> void:
		if tier <= 0:
			return
		var w := gem_w()
		var h := side
		var total := step() * tier - (step() - w)
		var x0 := (size.x - total) * 0.5 + w * 0.5
		var cy := size.y * 0.5
		for i in tier:
			var c := Vector2(x0 + step() * i, cy)
			var top := c.y - h * 0.5
			var girdle := top + h * 0.36
			var pts := PackedVector2Array([Vector2(c.x - w * 0.3, top), Vector2(c.x + w * 0.3, top),
				Vector2(c.x + w * 0.5, girdle), Vector2(c.x, c.y + h * 0.5), Vector2(c.x - w * 0.5, girdle)])
			# قابِ سیاه تا روی هر زمینه‌ای (عکسِ شلوغ، گرادیانِ هم‌رنگ) خوانا بماند
			var outline := PackedVector2Array()
			var k := 1.0 + 2.4 / h
			for v in pts:
				outline.append(c + (v - c) * k)
			draw_colored_polygon(outline, Color(0, 0, 0, 0.85))
			draw_colored_polygon(pts, tint)
			# تاجِ روشن‌تر + خطِ کمربند = «نگین»، نه نقطه
			draw_colored_polygon(PackedVector2Array([pts[0], pts[1], pts[2], pts[4]]), tint.lightened(0.45))
			draw_colored_polygon(PackedVector2Array([Vector2(c.x - w * 0.12, top + h * 0.06),
				Vector2(c.x + w * 0.05, top + h * 0.06), Vector2(c.x - w * 0.05, girdle - h * 0.04),
				Vector2(c.x - w * 0.24, girdle - h * 0.04)]), Color(1, 1, 1, 0.7))
