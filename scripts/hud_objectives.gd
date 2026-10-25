extends VBoxContainer
## «اهداف» — ماموریت‌های روزانه و رنک که همین مسابقه جلو می‌برد.
##
## سرور فهرست را می‌فرستد (objectives) و هر پیشرفت را جدا (objective_update)؛
## این‌جا فقط نمایش است و هیچ عددی ساخته نمی‌شود.
##
## هر هدف با انیمیشن از کنارِ صفحه وارد می‌شود. وقتی تمام شد تیک می‌خورد،
## «ثبت شد» زیرش می‌آید (سرور آخرِ مسابقه در صفحه‌ی ماموریت‌ها ذخیره‌اش
## می‌کند) و بعد با انیمیشن بیرون می‌رود. هم‌زمان بیشتر از MAX_VISIBLE تا
## روی صفحه نیست؛ بقیه در صف می‌مانند و جای خالی را پر می‌کنند.

## هر پیشرفت/فهرستِ تازه؛ near یعنی دست‌کم یک هدف نزدیکِ تمام شدن است.
## GameHUD با این پنل را روشن/کم‌رنگ می‌کند.  # C1
signal activity(near: bool)

const FONT := preload("res://fonts/Lalezar-Regular.ttf")

const MAX_VISIBLE := 3
const ROW_W := 300.0
const ROW_H := 40.0
const HOLD_DONE := 2.2

const COL_BG    := Color(0.04, 0.035, 0.05, 0.78)
const COL_GOLD  := Color(0.96, 0.78, 0.3)
const COL_TEXT  := Color(0.97, 0.95, 0.9)
const COL_DIM   := Color(0.66, 0.64, 0.68)
const COL_DAILY := Color(0.33, 0.74, 1.0)
const COL_DONE  := Color(0.42, 0.9, 0.5)
## هدفِ نزدیک به پایان: طلاییِ روشن  # C9 goal-gradient
const COL_NEAR  := Color(1.0, 0.86, 0.36)
## «فقط N تا مونده!» این‌قدر جای عنوان می‌نشیند و بعد عنوان برمی‌گردد
const NEAR_CALLOUT_TIME := 2.6

var _header: Control = null
## هدف‌های منتظر: [{id, kind, title, icon, progress, target, done}]
var _queue: Array = []
## id → ردیفِ روی صفحه
var _rows: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	custom_minimum_size = Vector2(ROW_W, 0)
	_header = _build_header()
	add_child(_header)
	_header.hide()


func _build_header() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(HudIconRect.new().setup("target", 24, COL_GOLD))
	var t := _label("اهداف", 20, COL_GOLD)
	h.add_child(t)
	return h


func _label(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ============================ از سرور ============================

## فهرستِ کامل (اولِ مسابقه)
func set_objectives(list: Array) -> void:
	for id in _rows.keys():
		_rows[id].queue_free()
	_rows.clear()
	_queue.clear()
	for o in list:
		if typeof(o) == TYPE_DICTIONARY:
			_queue.append(o.duplicate())
	_fill()
	activity.emit(_any_near())


## یک هدف جلو رفت (یا تمام شد)
func update_objective(id: String, progress: int, target: int, done: bool) -> void:
	if _rows.has(id):
		_apply(_rows[id], progress, target, done)
		activity.emit(_any_near())
		return
	for o in _queue:
		if str(o.get("id", "")) == id:
			o["progress"] = progress
			o["target"] = target
			o["done"] = done
			# تمام‌شده‌ها جلوی صف می‌روند تا بازیکن تیک خوردنشان را ببیند
			if done:
				_queue.erase(o)
				_queue.push_front(o)
				_make_room_for_done()
			activity.emit(_any_near())
			return


# ============================ ردیف‌ها ============================

## جای خالی را از صف پر می‌کند
func _fill() -> void:
	while _rows.size() < MAX_VISIBLE and not _queue.is_empty():
		var o: Dictionary = _queue.pop_front()
		_show_row(o)
	_header.visible = not _rows.is_empty()


## اگر هدفی در صف تمام شد و جا نیست، قدیمی‌ترین ردیفِ نیمه‌کاره موقتاً کنار
## می‌رود (به تهِ صف) تا تیک خوردن دیده شود
func _make_room_for_done() -> void:
	if _rows.size() < MAX_VISIBLE:
		_fill()
		return
	for id in _rows.keys():
		var row: Control = _rows[id]
		if not bool(row.get_meta("done", false)):
			_queue.push_back(row.get_meta("data"))
			_rows.erase(id)
			_slide_out(row)
			break
	_fill()


func _show_row(o: Dictionary) -> void:
	var id := str(o.get("id", ""))
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(ROW_W, ROW_H)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set_meta("data", o)
	add_child(slot)

	var card := Control.new()
	card.name = "Card"
	card.size = Vector2(ROW_W, ROW_H)
	card.pivot_offset = card.size * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.draw.connect(_draw_card.bind(card, slot))
	slot.add_child(card)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 40.0
	row.offset_right = -8.0
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var title := _label(str(o.get("title", "")), 16, COL_TEXT)
	title.name = "Title"
	slot.set_meta("title", title.text)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)

	var prog := _label("", 17, COL_GOLD)   # V10 عددِ درشت‌تر
	prog.name = "Progress"
	prog.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(prog)

	_rows[id] = slot
	_apply(slot, int(o.get("progress", 0)), int(o.get("target", 1)), false)

	# ورود از کنار
	card.position.x = -ROW_W - 30.0
	card.modulate.a = 0.0
	var tw := card.create_tween().set_parallel(true)
	tw.tween_property(card, "position:x", 0.0, 0.42) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.set_delay(0.12 * float(_rows.size() - 1))
	tw.tween_property(card, "modulate:a", 1.0, 0.25)

	if bool(o.get("done", false)):
		_apply(slot, int(o.get("progress", 0)), int(o.get("target", 1)), true)


func _apply(slot: Control, progress: int, target: int, done: bool) -> void:
	var o: Dictionary = slot.get_meta("data")
	var before := int(slot.get_meta("shown_progress", -1))
	o["progress"] = progress
	o["target"] = target
	slot.set_meta("shown_progress", progress)
	var card := slot.get_node("Card")
	var prog := _find_label(card, "Progress")
	var near := _is_near(progress, target, done)
	slot.set_meta("near", near)
	if prog != null:
		prog.text = "%s/%s" % [MissionArt.fa_number(mini(progress, target)), MissionArt.fa_number(target)]
		prog.add_theme_color_override("font_color", COL_NEAR if near else COL_GOLD)
		if before >= 0 and progress != before:
			_pop(prog)   # V10 pulse on change
	# C9 goal-gradient: نزدیکِ خط پایان، «فقط N تا مونده!» جای عنوان می‌نشیند
	if near and progress != before:
		_near_callout(slot, target - progress)
	card.queue_redraw()
	if done and not bool(slot.get_meta("done", false)):
		slot.set_meta("done", true)
		_complete(slot)


func _find_label(root: Node, name: String) -> Label:
	for c in root.get_children():
		if c.name == name and c is Label:
			return c
		var deep := _find_label(c, name)
		if deep != null:
			return deep
	return null


## تیک خوردن: برق، «ثبت شد»، و بعد بیرون رفتن
func _complete(slot: Control) -> void:
	var card: Control = slot.get_node("Card")
	var title := _find_label(card, "Title")
	if title != null:
		# اگر «فقط N تا مونده!» روی عنوان بود، همین حالا کنار برود
		slot.set_meta("callout_n", int(slot.get_meta("callout_n", 0)) + 1)
		title.text = str(slot.get_meta("title", title.text))
		title.add_theme_color_override("font_color", COL_DONE)
	var prog := _find_label(card, "Progress")
	if prog != null:
		prog.text = "ثبت شد"
		prog.add_theme_color_override("font_color", COL_DONE)
	card.set_meta("flash", 1.0)
	var tw := card.create_tween()
	tw.tween_method(func(v: float):
		card.set_meta("flash", v)
		card.queue_redraw(), 1.0, 0.0, 0.8)
	var pulse := card.create_tween()
	pulse.tween_property(card, "scale", Vector2(1.04, 1.04), 0.12)
	pulse.tween_property(card, "scale", Vector2.ONE, 0.18)
	LocalSettings.vibrate(35)

	get_tree().create_timer(HOLD_DONE).timeout.connect(func():
		if not is_instance_valid(slot):
			return
		for id in _rows.keys():
			if _rows[id] == slot:
				_rows.erase(id)
				break
		_slide_out(slot)
		_fill())


func _slide_out(slot: Control) -> void:
	var card: Control = slot.get_node("Card")
	var tw := card.create_tween().set_parallel(true)
	tw.tween_property(card, "position:x", -ROW_W - 30.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(card, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(func():
		slot.queue_free()
		# queue_free یک فریم طول می‌کشد؛ سرتیتر همین حالا تصمیم بگیرد
		_header.visible = not _rows.is_empty())


func _draw_card(card: Control, slot: Control) -> void:
	var o: Dictionary = slot.get_meta("data")
	var done := bool(slot.get_meta("done", false))
	var w := card.size.x
	var h := card.size.y
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_BG
	sb.set_corner_radius_all(8)
	card.draw_style_box(sb, Rect2(0, 0, w, h))

	var flash := float(card.get_meta("flash", 0.0))
	if flash > 0.0:
		var fb := StyleBoxFlat.new()
		fb.bg_color = Color(COL_DONE.r, COL_DONE.g, COL_DONE.b, 0.35 * flash)
		fb.set_corner_radius_all(8)
		card.draw_style_box(fb, Rect2(0, 0, w, h))

	# نوارِ رنگیِ نوع: آبی برای روزانه، طلایی برای رنک
	var ranked := str(o.get("kind", "")) == "ranked"
	var tag := COL_GOLD if ranked else COL_DAILY
	card.draw_rect(Rect2(0, 6, 3, h - 12), tag)

	# چک‌باکس
	var cb := Rect2(10, (h - 20) * 0.5, 20, 20)
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(4)
	box.set_border_width_all(2)
	box.border_color = COL_DONE if done else Color(0.8, 0.78, 0.72)
	box.bg_color = Color(COL_DONE.r, COL_DONE.g, COL_DONE.b, 0.9) if done else Color(0, 0, 0, 0.4)
	card.draw_style_box(box, cb)
	if done:
		HudIcons.draw(card, "check", cb.grow(-2.0), Color(0.05, 0.12, 0.05))
	elif ranked:
		# ستاره‌ی کوچکِ رنک، مثلِ عکسِ مرجع
		_star(card, cb.get_center(), 7.0, COL_GOLD)

	# نوارِ پیشرفتِ زیرِ ردیف؛ نزدیکِ پایان طلاییِ روشن و قابِ طلایی  # C9
	var near := bool(slot.get_meta("near", false))
	if near:
		var nb := StyleBoxFlat.new()
		nb.draw_center = false
		nb.set_corner_radius_all(8)
		nb.set_border_width_all(2)
		nb.border_color = Color(COL_NEAR.r, COL_NEAR.g, COL_NEAR.b, 0.85)
		card.draw_style_box(nb, Rect2(0, 0, w, h))
	var target := maxf(float(o.get("target", 1)), 1.0)
	var ratio := clampf(float(o.get("progress", 0)) / target, 0.0, 1.0)
	card.draw_rect(Rect2(40, h - 6, w - 48, 3), Color(1, 1, 1, 0.12))
	card.draw_rect(Rect2(40, h - 6, (w - 48) * ratio, 3), COL_DONE if done else (COL_NEAR if near else tag))


func _star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rad := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * float(i) / 10.0) * rad)
	ci.draw_colored_polygon(pts, col)


## «نزدیکِ تمام شدن»: کمتر از ۲۰٪ (حداقل ۱ تا) مانده و از صفر جلو رفته  # C9
func _is_near(progress: int, target: int, done: bool) -> bool:
	if done or progress <= 0 or progress >= target:
		return false
	return target - progress <= maxi(1, ceili(float(target) * 0.2))


func _any_near() -> bool:
	for id in _rows.keys():
		if bool(_rows[id].get_meta("near", false)):
			return true
	return false


## عدد یک لحظه بزرگ می‌شود  # V10
func _pop(l: Label, k := 1.3) -> void:
	l.pivot_offset = l.size * 0.5
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(k, k), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## C9 goal-gradient: «فقط ۱ تا مونده!» چند ثانیه جای عنوان، بعد عنوان برمی‌گردد
func _near_callout(slot: Control, left: int) -> void:
	var title := _find_label(slot.get_node("Card"), "Title")
	if title == null:
		return
	var n := int(slot.get_meta("callout_n", 0)) + 1
	slot.set_meta("callout_n", n)
	title.text = "فقط %s تا مونده!" % MissionArt.fa_number(left)
	title.add_theme_color_override("font_color", COL_NEAR)
	_pop(title, 1.08)
	get_tree().create_timer(NEAR_CALLOUT_TIME).timeout.connect(func():
		if not is_instance_valid(slot) or int(slot.get_meta("callout_n", 0)) != n:
			return
		title.text = str(slot.get_meta("title", ""))
		title.add_theme_color_override("font_color",
			COL_DONE if bool(slot.get_meta("done", false)) else COL_TEXT))
