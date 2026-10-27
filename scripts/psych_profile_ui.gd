extends RefCounted
## کمک‌های ظاهری مشترک منوی کاربر (پروفایل، دوستان، پیام‌ها، تنظیمات) — دور ۳.
##
## همه چیز با پالت MenuUI ساخته می‌شود؛ این‌جا فقط تکه‌هایی است که چند تب لازم
## دارند: کارت عنوان‌دار، اسکلت بارگذاری، حالت خالی، حلقه‌ی سطح، کاشی آمار،
## سرتیتر گروه‌های لیست و شمارش عدد.

const ICON_EDIT := preload("res://assets/ui/profile_menu/icon_edit.svg")
const ICON_COPY := preload("res://assets/ui/profile_menu/icon_copy.svg")

## فاصله‌ی پایه‌ی چیدمان (ریتم ۸)
const GAP := 8
const RADIUS := 8

# ---------------------------------------------------------------- کارت‌ها

## V3 ناحیه‌ی مشترک: کارت تیره با عنوان. خروجی [panel, body]
static func card(title: String, icon: Texture2D = null, accent: Color = MenuUI.GOLD) -> Array:
	var panel := PanelContainer.new()
	var style := MenuUI.box(MenuUI.CARD_BG, MenuUI.CARD_BORDER, 1, RADIUS)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", GAP)
	panel.add_child(body)
	if not title.is_empty():
		body.add_child(title_row(title, icon, accent))
	return [panel, body]

## عنوان بخش: آیکن طلایی کوچک + متن (راست‌چین)
static func title_row(title: String, icon: Texture2D = null, accent: Color = MenuUI.GOLD) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := MenuUI.label(title, 19, MenuUI.TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	if icon != null:
		row.add_child(MenuUI.icon(icon, 22, accent))
	# نوار کوچک طلایی کنار عنوان — امضای بصری بخش‌ها (V3)
	var bar := ColorRect.new()
	bar.color = accent
	bar.custom_minimum_size = Vector2(4, 20)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	return row

## سرتیتر یک گروه داخل لیست («آنلاین — ۲»). C14/V3
static func group_header(text: String, color: Color = MenuUI.MUTED) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(0, 28)
	var line := ColorRect.new()
	line.color = Color(color, 0.25)
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	var l := MenuUI.label(text, 15, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(l)
	return row

## دکمه‌ی آیکن‌دار مربعی ۴۸dp (ویرایش، کپی، ...)؛ V9 «فشاردادنی» دیده می‌شود
static func icon_button(texture: Texture2D, kind: String = "dark", side: float = MenuUI.TOUCH_H) -> Button:
	var b := MenuUI.button("", kind, 16)
	b.custom_minimum_size = Vector2(side, side)
	b.icon = texture
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", int(side * 0.48))
	return b

# ---------------------------------------------------------------- حالت‌ها

## C12 اسکلت بارگذاری: چند ردیف خاکستری که آرام می‌تپند (بدون _process)
static func skeleton(rows: int, row_height: float = 64.0) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in rows:
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(0, row_height)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_stylebox_override("panel", MenuUI.box(Color(0.13, 0.13, 0.14, 1.0), Color(0, 0, 0, 0), 0, RADIUS))
		var inner := HBoxContainer.new()
		inner.add_theme_constant_override("separation", 12)
		inner.alignment = BoxContainer.ALIGNMENT_END
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lines := VBoxContainer.new()
		lines.alignment = BoxContainer.ALIGNMENT_CENTER
		lines.add_theme_constant_override("separation", 8)
		lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for w in [150.0 - 20.0 * (i % 3), 90.0]:
			var bar := ColorRect.new()
			bar.color = Color(0.2, 0.2, 0.22, 1.0)
			bar.custom_minimum_size = Vector2(w, 10)
			bar.size_flags_horizontal = Control.SIZE_SHRINK_END
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lines.add_child(bar)
		inner.add_child(lines)
		var dot := Panel.new()
		var side := maxf(row_height - 20.0, 24.0)
		dot.custom_minimum_size = Vector2(side, side)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.add_theme_stylebox_override("panel", MenuUI.box(Color(0.2, 0.2, 0.22, 1.0), Color(0, 0, 0, 0), 0, RADIUS))
		inner.add_child(dot)
		var m := MarginContainer.new()
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side_name in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			m.add_theme_constant_override(side_name, 10)
		m.add_child(inner)
		row.add_child(m)
		box.add_child(row)
		# تپش ملایم و پلکانی — تویینِ حلقه‌ای با خودِ ردیف آزاد می‌شود
		var t := row.create_tween().set_loops()
		t.tween_interval(0.08 * i)
		t.tween_property(row, "modulate:a", 0.45, 0.55).set_trans(Tween.TRANS_SINE)
		t.tween_property(row, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	return box

## E1/E10 حالت خالی/خطا: تصویر + عنوان + راهنما + یک دکمه‌ی پیشنهادی.
## خروجی {box, art, title, hint, button}
static func empty_state(texture: Texture2D, title: String, hint: String,
		action_text: String = "", kind: String = "gold") -> Dictionary:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var art := TextureRect.new()
	art.texture = texture
	art.custom_minimum_size = Vector2(0, 92)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.visible = texture != null
	box.add_child(art)
	var t := MenuUI.label(title, 20, MenuUI.TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(t)
	var h := MenuUI.label(hint, 15, MenuUI.MUTED)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.visible = not hint.is_empty()
	box.add_child(h)
	var b := MenuUI.button(action_text, kind, 17)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(220, MenuUI.TOUCH_H)
	b.visible = not action_text.is_empty()
	box.add_child(b)
	return {"box": box, "art": art, "title": t, "hint": h, "button": b}

# ---------------------------------------------------------------- اعداد

## V10 شمارش نرم از عدد قبلی تا عدد تازه + پالس کوچک (برچسب meta «value» دارد)
static func count_to(label: Label, value: int, grouped: bool = true, duration: float = 0.6) -> void:
	var from := int(label.get_meta("value", 0))
	label.set_meta("value", value)
	var fmt := func(v: int) -> String: return MenuUI.fa_grouped(v) if grouped else MenuUI.fa(v)
	if from == value or not label.is_visible_in_tree():
		label.text = fmt.call(value)
		return
	var t := label.create_tween()
	t.tween_method(func(v: float) -> void: label.text = fmt.call(int(round(v))),
		float(from), float(value), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pop(label)

## پالس کوچک هنگام تغییر عدد
static func pop(control: Control, amount: float = 1.12) -> void:
	if control == null or not is_instance_valid(control):
		return
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2(amount, amount)
	control.create_tween().tween_property(control, "scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## ورود پلکانی: محو + کمی بالا آمدن با scale (کانتینر position را بازنشانی می‌کند)
static func stagger_in(controls: Array, step: float = 0.04, start: float = 0.0) -> void:
	var i := 0
	for c in controls:
		var ctl := c as Control
		if ctl == null or not is_instance_valid(ctl):
			continue
		ctl.modulate.a = 0.0
		var t := ctl.create_tween()
		t.tween_interval(start + step * i)
		t.tween_property(ctl, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
		i += 1

# ---------------------------------------------------------------- کاشی آمار

## کاشی آمار بزرگ: آیکن + عدد درشت Lalezar + زیرنویس. خروجی {panel, value, sub}
static func stat_tile(texture: Texture2D, caption: String, tint: Color = MenuUI.GOLD) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := MenuUI.box(Color(0.1, 0.1, 0.11, 0.95), Color(0.3, 0.3, 0.33, 0.55), 1, RADIUS)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", -2)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var value := MenuUI.label("۰", 30, MenuUI.TEXT, true)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	texts.add_child(value)
	var cap := MenuUI.label(caption, 14, MenuUI.MUTED)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cap.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(cap)
	row.add_child(texts)
	var icon_bg := PanelContainer.new()
	icon_bg.custom_minimum_size = Vector2(48, 48)
	icon_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_bg.add_theme_stylebox_override("panel", MenuUI.box(Color(tint, 0.12), Color(tint, 0.35), 1, 24))
	var ic := MenuUI.icon(texture, 26, tint)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_bg.add_child(ic)
	row.add_child(icon_bg)
	return {"panel": panel, "value": value, "sub": cap}


# ---------------------------------------------------------------- حلقه‌ی سطح

## E1 شایستگی / C9 شیب هدف: حلقه‌ی طلایی دور آواتار که پیشرفت تا سطح بعد را
## نشان می‌دهد. فقط وقتی progress عوض می‌شود دوباره کشیده می‌شود.
class LevelRing extends Control:
	var progress: float = 0.0:
		set(value):
			progress = clampf(value, 0.0, 1.0)
			queue_redraw()
	var thickness := 6.0
	var color := MenuUI.GOLD
	var track := Color(1, 1, 1, 0.1)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - thickness * 0.5 - 1.0
		if r <= 2.0:
			return
		draw_arc(c, r, 0.0, TAU, 64, track, thickness, true)
		if progress > 0.0:
			# از بالای حلقه، ساعتگرد
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, color, thickness, true)
			# سرِ روشنِ نوار — نقطه‌ی «الان اینجایی»
			var a := -PI * 0.5 + TAU * progress
			draw_circle(c + Vector2(cos(a), sin(a)) * r, thickness * 0.75, Color(1.0, 0.95, 0.75, 1.0))

	## پر شدن نرم تا مقدار تازه
	func animate_to(value: float, duration: float = 0.8) -> void:
		create_tween().tween_property(self, "progress", clampf(value, 0.0, 1.0), duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## آواتار گرد‌گوشه داخل حلقه‌ی سطح + نشان سطح پایین حلقه. خروجی {root, avatar, ring, level}
## root یک Control با اندازه‌ی ثابت است (side) تا داخل Box ها درست بنشیند.
static func avatar_with_ring(side: float, level_font: int = 18) -> Dictionary:
	var root := Control.new()
	root.custom_minimum_size = Vector2(side, side)
	root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var ring := LevelRing.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.thickness = maxf(4.0, side * 0.045)
	root.add_child(ring)

	var inset := ring.thickness * 2.0 + 3.0
	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = inset
	frame.offset_top = inset
	frame.offset_right = -inset
	frame.offset_bottom = -inset
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	frame.add_theme_stylebox_override("panel", MenuUI.box(Color(0.13, 0.13, 0.14, 1.0), Color(0, 0, 0, 0), 0, int(side)))
	root.add_child(frame)
	var avatar := TextureRect.new()
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(avatar)

	# نشان سطح: قرص طلایی پایین حلقه (V10 عدد درشت Lalezar)
	var badge := PanelContainer.new()
	var bs := MenuUI.box(Color(0.2, 0.13, 0.02, 1.0), MenuUI.GOLD, 2, 14)
	bs.content_margin_left = 10
	bs.content_margin_right = 10
	bs.content_margin_top = 0
	bs.content_margin_bottom = 0
	badge.add_theme_stylebox_override("panel", bs)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	badge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	badge.offset_bottom = 6
	var level := MenuUI.label("۱", level_font, MenuUI.GOLD, true)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(level)
	root.add_child(badge)
	return {"root": root, "avatar": avatar, "ring": ring, "level": level, "badge": badge}


# ---------------------------------------------------------------- کلید روشن/خاموش

static var _toggle_on: Texture2D
static var _toggle_off: Texture2D

## V9 کلید بزرگ‌تر و واضح‌تر از CheckButton پیش‌فرض: روشن = طلایی، خاموش = خاکستری
static func style_toggle(cb: CheckButton) -> void:
	if _toggle_on == null:
		_toggle_on = _pill(true)
		_toggle_off = _pill(false)
	cb.add_theme_icon_override("checked", _toggle_on)
	cb.add_theme_icon_override("unchecked", _toggle_off)
	cb.add_theme_icon_override("checked_mirrored", _toggle_on)
	cb.add_theme_icon_override("unchecked_mirrored", _toggle_off)
	cb.add_theme_color_override("font_pressed_color", MenuUI.GOLD)
	cb.add_theme_color_override("font_hover_pressed_color", MenuUI.GOLD)
	cb.add_theme_color_override("font_color", MenuUI.MUTED)
	cb.add_theme_color_override("font_hover_color", MenuUI.MUTED)
	cb.add_theme_color_override("font_focus_color", MenuUI.MUTED)
	cb.custom_minimum_size.y = maxf(cb.custom_minimum_size.y, MenuUI.TOUCH_H)

## قرص ۶۴×۳۴ با لبه‌ی نرم — یک بار ساخته و کش می‌شود
static func _pill(on: bool) -> Texture2D:
	var w := 64
	var h := 34
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := h * 0.5
	var track := Color(0.85, 0.64, 0.2, 1.0) if on else Color(0.26, 0.26, 0.29, 1.0)
	var knob_x := w - r if on else r
	for y in h:
		for x in w:
			var px := Vector2(x + 0.5, y + 0.5)
			# فاصله تا قرص (کپسول افقی)
			var cx := clampf(px.x, r, w - r)
			var d := px.distance_to(Vector2(cx, r))
			var a := clampf(r - d, 0.0, 1.0)
			var c := Color(track, a)
			var kd := px.distance_to(Vector2(knob_x, r))
			var ka := clampf((r - 4.0) - kd, 0.0, 1.0)
			if ka > 0.0:
				c = c.lerp(Color(1, 1, 1, 1), ka)
				c.a = maxf(a, ka)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
