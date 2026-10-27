extends RefCounted
## پنجره‌های فروشگاه، همه روی MenuUI.ModalSheet (Back اندروید، دیم و ✕ می‌بندند):
##   item_sheet  — پیش‌نمایشِ آیتم + تأییدِ خرید (C11 مقایسه، C13 پیشگیری از خطا)
##   short_sheet — «X سکه کم داری» بی‌شرم‌سازی، با راهِ بعدی (C13، مرزِ اخلاقی)
##   odds_sheet  — احتمالِ دقیقِ بسته‌ی شانسی قبل از خرج (E3 اخلاقی)
## پاسخ‌ها به on_answer(action: String) می‌رسند: "buy" | "equip" | "go_currency" | "open" | "cancel"

const Rarity := preload("res://scripts/psych_shop_rarity.gd")

const COIN_ICON := "res://assets/ui/coin_icon.png"
const GEM_ICON := "res://assets/ui/gem_icon.png"
const COL_BETTER := Color(0.3, 0.86, 0.42)
const COL_WORSE := Color(1.0, 0.36, 0.36)


static func unit_name(unit: String) -> String:
	return "قلب" if unit == "gems" else "سکه"


static func unit_icon(unit: String) -> Texture2D:
	var p := GEM_ICON if unit == "gems" else COIN_ICON
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


## ردیفِ «[آیکن] ۶٬۰۰۰» با ارقامِ Lalezar (V10)
static func price_row(price: int, unit: String, size: int = 24, color: Color = MenuUI.GOLD) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(MenuUI.icon(unit_icon(unit), size * 1.05))
	row.add_child(MenuUI.label(MenuUI.fa_grouped(price), size, color, true))
	return row


static func _open(host: Node, title: String, width: float) -> Array:
	var sheet := MenuUI.ModalSheet.new()
	host.get_tree().root.add_child(sheet)
	var col := sheet.build(title, width)
	return [sheet, col]


## پاسخ فقط یک بار؛ بستن با Back/دیم/✕ یعنی "cancel"
static func _wire(sheet: MenuUI.ModalSheet, on_answer: Callable) -> Callable:
	var answered := [false]
	var finish := func(action: String) -> void:
		if answered[0]:
			return
		answered[0] = true
		sheet.close()
		if on_answer.is_valid():
			on_answer.call(action)
	sheet.dismissed.connect(func() -> void: finish.call("cancel"))
	return finish


static func _buttons(col: VBoxContainer, finish: Callable, cancel_text: String,
		primary_text: String, primary_action: String, primary_enabled: bool = true) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var cancel := MenuUI.button(cancel_text, "dark", 18)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.size_flags_stretch_ratio = 0.7
	cancel.pressed.connect(func() -> void: finish.call("cancel"))
	row.add_child(cancel)
	# V5: تنها دکمه‌ی طلاییِ پنجره
	var ok := MenuUI.button(primary_text, "gold" if primary_enabled else "dark", 20)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.disabled = not primary_enabled
	ok.pressed.connect(func() -> void: UIFx.tap(ok, func() -> void: finish.call(primary_action)))
	row.add_child(ok)
	col.add_child(row)
	return ok


# -----------------------------------------------------------------------------
# پیش‌نمایشِ آیتم
# -----------------------------------------------------------------------------

## info: name, texture, rarity, price, old_price, unit ("coins"/"gems"), balance,
##       state ("buy"|"short"|"owned"|"equipped"), stats [[title, value, ref], ...],
##       compare_name, kind ("کاراکتر"/"اسلحه")
static func item_sheet(host: Node, info: Dictionary, on_answer: Callable) -> Control:
	var view := host.get_viewport().get_visible_rect().size
	var parts := _open(host, str(info.get("name", "")), 760.0)
	var sheet: MenuUI.ModalSheet = parts[0]
	var col: VBoxContainer = parts[1]
	var finish := _wire(sheet, on_answer)
	var rarity := str(info.get("rarity", "common"))
	var price := int(info.get("price", 0))
	var old_price := int(info.get("old_price", 0))
	var unit := str(info.get("unit", "coins"))
	var state := str(info.get("state", "buy"))
	var balance := int(info.get("balance", 0))
	var stats: Array = info.get("stats", [])

	# رده + نوع + تخفیف، زیرِ عنوان
	var tags := HBoxContainer.new()
	tags.alignment = BoxContainer.ALIGNMENT_END
	tags.add_theme_constant_override("separation", 8)
	if old_price > price and old_price > 0:
		var off := int(round((1.0 - float(price) / float(old_price)) * 100.0))
		var sale := PanelContainer.new()
		sale.add_theme_stylebox_override("panel", _pill(MenuUI.RED, MenuUI.RED_HOT))
		sale.add_child(MenuUI.label("٪%s تخفیف" % MenuUI.fa(off), 14, Color.WHITE))
		tags.add_child(sale)
	var kind := str(info.get("kind", ""))
	if kind != "":
		tags.add_child(MenuUI.label(kind, 14, MenuUI.MUTED))
	tags.add_child(Rarity.badge(rarity, 15))
	col.add_child(tags)

	# بدنه: نوارها چپ، عکس راست (خواندنِ راست‌به‌چپ از عکس شروع می‌شود)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	var img_h := clampf(view.y * 0.36, 150.0, 260.0)
	if not stats.is_empty():
		var stats_col := VBoxContainer.new()
		stats_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_col.alignment = BoxContainer.ALIGNMENT_CENTER
		stats_col.add_theme_constant_override("separation", 6 if stats.size() > 5 else 10)
		var cmp := str(info.get("compare_name", ""))
		var has_ref := false
		for s in stats:
			if float(s[2]) >= 0.0:
				has_ref = true
		if has_ref:
			var cap := MenuUI.label("خطِ طلایی = %s (فعلیِ تو)" % (cmp if cmp != "" else "انتخابِ فعلی"), 13, MenuUI.GOLD)
			cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			stats_col.add_child(cap)
		for s in stats:
			stats_col.add_child(stat_row(str(s[0]), float(s[1]), float(s[2]), Rarity.color(rarity)))
		body.add_child(stats_col)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(img_h * 1.05, img_h)
	if stats.is_empty():
		frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fs := StyleBoxFlat.new()
	fs.bg_color = Rarity.deep(rarity).darkened(0.25)
	fs.border_color = Rarity.color(rarity)
	fs.set_border_width_all(2)
	fs.set_corner_radius_all(10)
	frame.add_theme_stylebox_override("panel", fs)
	var stage := Control.new()
	stage.clip_contents = true
	frame.add_child(stage)
	var glow := TextureRect.new()
	glow.texture = Rarity.glow(rarity, 0.7)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(glow)
	var pic := TextureRect.new()
	pic.texture = info.get("texture", null)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = 8
	pic.offset_right = -8
	pic.offset_top = 8
	pic.offset_bottom = -8
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(pic)
	body.add_child(frame)
	col.add_child(body)

	# قیمت + وضعِ کیف پول
	var money := HBoxContainer.new()
	money.add_theme_constant_override("separation", 10)
	var note := MenuUI.label("", 16, MenuUI.MUTED)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	money.add_child(note)
	var primary_text := ""
	var primary_action := "buy"
	match state:
		"owned":
			note.text = "این %s مالِ توست." % (kind if kind != "" else "آیتم")
			primary_text = "تجهیز کن"
			primary_action = "equip"
		"equipped":
			note.text = "همین الان دستِ توست."
			primary_text = "✓ در دستِ توست"
		"short":
			# C13 بدون شرم‌سازی: فقط مقدار و راهِ بعدی
			note.text = "%s %s دیگه لازم داری" % [MenuUI.fa_grouped(price - balance), unit_name(unit)]
			note.add_theme_color_override("font_color", MenuUI.TEXT)
			primary_text = "گرفتن %s" % unit_name(unit)
			primary_action = "go_currency"
		_:
			note.text = "بعد از خرید %s %s برایت می‌ماند" % [MenuUI.fa_grouped(balance - price), unit_name(unit)]
			primary_text = "خرید"
	if state in ["buy", "short"]:
		if old_price > price:
			var old := MenuUI.label(MenuUI.fa_grouped(old_price), 16, MenuUI.DIM, true)
			old.add_child(_strike())
			money.add_child(old)
		money.add_child(price_row(price, unit, 26))
	col.add_child(money)

	_buttons(col, finish, "بستن", primary_text, primary_action, state != "equipped")
	sheet.open()
	return sheet


## یک ردیفِ آمار: [اختلاف] [عدد] [نوار] [عنوان] — نوار با بخشِ سبز/قرمزِ اختلاف
static func stat_row(title: String, value: float, ref: float, tint: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	var delta := int(round(value - ref))
	var dl := MenuUI.label("", 15, COL_BETTER, true)
	dl.custom_minimum_size.x = 34
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if ref >= 0.0 and delta != 0:
		dl.text = ("+%s" % MenuUI.fa(delta)) if delta > 0 else ("−%s" % MenuUI.fa(-delta))
		dl.add_theme_color_override("font_color", COL_BETTER if delta > 0 else COL_WORSE)
	row.add_child(dl)
	var vl := MenuUI.label(MenuUI.fa(int(value)), 17, MenuUI.TEXT, true)
	vl.custom_minimum_size.x = 30
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(vl)
	var bar := StatBar.new()
	bar.value = clampf(value / 100.0, 0.0, 1.0)
	bar.ref = clampf(ref / 100.0, 0.0, 1.0) if ref >= 0.0 else -1.0
	bar.tint = tint
	bar.custom_minimum_size = Vector2(80, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var tl := MenuUI.label(title, 15, MenuUI.MUTED)
	tl.custom_minimum_size.x = 92
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(tl)
	# V7 نوار از صفر پر می‌شود (کوتاه، بدونِ بلاک کردنِ ورودی)
	var target := bar.value
	bar.value = 0.0
	bar.create_tween().tween_property(bar, "value", target, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.12)
	return row


## نوارِ آمار با رنگِ رده؛ از نقطه‌ی فعلی تا مقدارِ تو سبز (بهتر) یا قرمزِ کم‌رنگ (ضعیف‌تر)
class StatBar extends Control:
	var value := 0.0:
		set(v):
			value = v
			queue_redraw()
	var ref := -1.0
	var tint := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var h := size.y
		var r := Rect2(Vector2.ZERO, size)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(1, 1, 1, 0.09)
		bg.set_corner_radius_all(int(h * 0.5))
		draw_style_box(bg, r)
		var fill := StyleBoxFlat.new()
		fill.bg_color = tint
		fill.set_corner_radius_all(int(h * 0.5))
		var w := size.x * value
		if w > 1.0:
			draw_style_box(fill, Rect2(0, 0, maxf(w, h), h))
		if ref >= 0.0:
			var rx := size.x * ref
			if w > rx + 1.0:
				draw_rect(Rect2(rx, h * 0.2, w - rx, h * 0.6), Color(0.3, 0.86, 0.42, 0.85))
			elif rx > w + 1.0:
				draw_rect(Rect2(w, h * 0.2, rx - w, h * 0.6), Color(1.0, 0.36, 0.36, 0.4))
			draw_rect(Rect2(rx - 1.5, -3.0, 3.0, h + 6.0), MenuUI.GOLD)


static func _pill(bg: Color, border: Color) -> StyleBoxFlat:
	var s := MenuUI.box(bg, border, 1, 10)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	return s


static func _strike() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(1, 0.4, 0.4, 0.8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.anchor_left = 0.0
	line.anchor_right = 1.0
	line.anchor_top = 0.5
	line.anchor_bottom = 0.5
	line.offset_top = -1.0
	line.offset_bottom = 1.0
	return line


# -----------------------------------------------------------------------------
# «کم داری»
# -----------------------------------------------------------------------------

static func short_sheet(host: Node, need: int, unit: String, item_name: String, on_answer: Callable) -> Control:
	var parts := _open(host, "یه کم دیگه مونده", 560.0)
	var sheet: MenuUI.ModalSheet = parts[0]
	var col: VBoxContainer = parts[1]
	var finish := _wire(sheet, on_answer)
	var big := HBoxContainer.new()
	big.alignment = BoxContainer.ALIGNMENT_CENTER
	big.add_theme_constant_override("separation", 10)
	big.add_child(MenuUI.label("دیگه لازم داری", 20, MenuUI.TEXT))
	big.add_child(price_row(need, unit, 34))
	col.add_child(big)
	if item_name != "":
		var why := MenuUI.label("برای «%s»" % item_name, 16, MenuUI.MUTED)
		why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(why)
	var hint := MenuUI.label(
		"سکه از مسابقه، مأموریت‌ها و تب «سکه و قلب» می‌رسه." if unit != "gems"
		else "قلب از تب «سکه و قلب»، تبلیغ و کد هدیه می‌رسه.", 15, MenuUI.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)
	_buttons(col, finish, "بعداً", "گرفتن %s" % unit_name(unit), "go_currency")
	sheet.open()
	return sheet


# -----------------------------------------------------------------------------
# بسته‌ی شانسی
# -----------------------------------------------------------------------------

## odds: {rarity: {"p": 0..1, "n": count}}
static func odds_sheet(host: Node, odds: Dictionary, price: int, balance: int, on_answer: Callable) -> Control:
	var parts := _open(host, "بسته‌ی شانسی", 600.0)
	var sheet: MenuUI.ModalSheet = parts[0]
	var col: VBoxContainer = parts[1]
	var finish := _wire(sheet, on_answer)
	var lead := MenuUI.label("یک کاراکتر یا اسلحه که هنوز نداری — تکراری نمی‌دهد.", 17, MenuUI.TEXT)
	lead.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(lead)
	if not odds.is_empty():
		var bar := odds_bar(odds)
		bar.custom_minimum_size.y = 14
		col.add_child(bar)
		for r in ["legend", "epic", "rare", "common"]:
			if not odds.has(r):
				continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			var pct := MenuUI.label("٪" + MenuUI.fa(int(round(float(odds[r]["p"]) * 100.0))), 22, Rarity.color(r), true)
			row.add_child(pct)
			var n := MenuUI.label("(%s آیتم)" % MenuUI.fa(int(odds[r]["n"])), 14, MenuUI.DIM)
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(n)
			row.add_child(Rarity.badge(r, 16))
			col.add_child(row)
	var fine := MenuUI.label("احتمال‌ها فقط بینِ آیتم‌هایی است که هنوز نداری. افسانه‌ای‌ها داخلِ این بسته نیستند.", 14, MenuUI.DIM)
	fine.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fine.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(fine)
	var money := HBoxContainer.new()
	var note := MenuUI.label("بعد از باز کردن %s قلب برایت می‌ماند" % MenuUI.fa_grouped(balance - price), 15, MenuUI.MUTED)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money.add_child(note)
	money.add_child(price_row(price, "gems", 24))
	col.add_child(money)
	_buttons(col, finish, "بستن", "باز کن", "open")
	sheet.open()
	return sheet


## نوارِ تکه‌تکه‌ی احتمال‌ها به رنگِ هر رده (legend → common از راست)
static func odds_bar(odds: Dictionary) -> Control:
	var b := OddsBar.new()
	for r in ["legend", "epic", "rare", "common"]:
		if odds.has(r):
			b.parts.append([float(odds[r]["p"]), Rarity.color(r)])
	b.custom_minimum_size = Vector2(60, 10)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


class OddsBar extends Control:
	var parts: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var h := size.y
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.6)
		bg.set_corner_radius_all(int(h * 0.5))
		bg.border_color = Color(1, 1, 1, 0.18)
		bg.set_border_width_all(1)
		draw_style_box(bg, Rect2(Vector2.ZERO, size))
		# راست‌به‌چپ: کمیاب‌ترین رده از سمتِ راست
		var x := size.x
		for i in parts.size():
			var w := size.x * float(parts[i][0])
			var seg := StyleBoxFlat.new()
			seg.bg_color = parts[i][1]
			var rad := int(h * 0.5)
			seg.corner_radius_top_right = rad if i == 0 else 0
			seg.corner_radius_bottom_right = rad if i == 0 else 0
			seg.corner_radius_top_left = rad if i == parts.size() - 1 else 0
			seg.corner_radius_bottom_left = rad if i == parts.size() - 1 else 0
			draw_style_box(seg, Rect2(x - w, 1.0, w, h - 2.0))
			if i > 0:
				draw_rect(Rect2(x - 1.0, 0, 2.0, h), Color(0, 0, 0, 0.85))
			x -= w
