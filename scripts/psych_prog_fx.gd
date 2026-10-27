extends RefCounted
## ابزارهای ظاهریِ مشترکِ صفحه‌های پیشرفت (ماموریت، فصل، رنک، جایزه) — دورِ ۳.
##
##   const ProgFx := preload("res://scripts/psych_prog_fx.gd")
##
##   ProgFx.desaturate(texture_rect)            آرتِ آبیِ قدیمی → خاکستریِ گرم (پالت تم)
##   ProgFx.count_label(label, 200, 1400)       شمارشِ عدد + پالسِ کوچک (V10)
##   ProgFx.skeleton(list, 4, 76)               ردیف‌های «در حال بارگذاری» با برق (C12)
##   ProgFx.message_state(list, ...)            حالتِ خالی / خطا با یک دکمه (E1/E10)
##   ProgFx.fly(tex, from, target, 6)           سکه‌ها از کارتِ جایزه تا شمارنده (E17/V7)
##
## همه با Tween و بدون شیدرِ هر فریم؛ روی گوشیِ ضعیف هم سبک‌اند.

const DESAT_SHADER := preload("res://scripts/result_desaturate.gdshader")

## گروهِ شمارنده‌های سکه/جم که پرواز به آن‌ها می‌رسد (نوارِ بالای صفحه)
const COIN_TARGET := "psych_coin_target"
const GEM_TARGET := "psych_gem_target"


## آرتِ پس‌زمینه‌ی سرمه‌ای را به خاکستریِ گرم می‌برد تا با سیاه/قرمز/طلایی بخواند
static func desaturate(item: CanvasItem, tint: Color = Color(0.92, 0.84, 0.84), amount: float = 1.0) -> void:
	if item == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = DESAT_SHADER
	mat.set_shader_parameter("amount", amount)
	mat.set_shader_parameter("silver", tint)
	item.material = mat


## V10 شمارشِ عدد از قبلی تا تازه، با پرشِ کوچک در پایان. format: Callable(int) -> String
static func count_label(label: Label, from: int, to: int, format: Callable = Callable(),
		time: float = 0.6) -> void:
	if label == null or not is_instance_valid(label):
		return
	var fmt := format if format.is_valid() else func(v: int) -> String: return MissionArt.fa_grouped(v)
	if from == to:
		label.text = fmt.call(to)
		return
	var t := label.create_tween()
	t.tween_method(func(v: float) -> void:
		if is_instance_valid(label):
			label.text = fmt.call(roundi(v)), float(from), float(to), time) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void: pulse(label, to > from))


## پرشِ کوچکِ یک کنترل (رسیدنِ سکه، عوض شدنِ عدد). gold: برقِ طلایی
static func pulse(c: Control, gold: bool = true) -> void:
	if c == null or not is_instance_valid(c):
		return
	c.pivot_offset = c.size * 0.5
	var t := c.create_tween()
	t.tween_property(c, "scale", Vector2(1.18, 1.18), 0.08).set_trans(Tween.TRANS_QUAD)
	if gold:
		t.parallel().tween_property(c, "modulate", Color(1.4, 1.25, 0.7), 0.08)
	t.tween_property(c, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(c, "modulate", Color.WHITE, 0.3)


## C12 حالتِ بارگذاری: چند ردیفِ خاکستریِ گرد با برقی که آرام رد می‌شود.
## خروجی: نگه‌دارنده — هر وقت دیتا رسید queue_free کن.
static func skeleton(parent: Control, rows: int, row_h: float) -> Control:
	var box := VBoxContainer.new()
	box.name = "Skeleton"
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in rows:
		var row := Panel.new()
		row.custom_minimum_size = Vector2(0, row_h)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_stylebox_override("panel", MenuUI.box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.06), 1, 8))
		box.add_child(row)
		# برق: ردیف‌ها با کمی تأخیر پشت‌سرِ هم روشن/خاموش می‌شوند
		var t := row.create_tween().set_loops()
		t.tween_interval(0.12 * i)
		t.tween_property(row, "modulate:a", 0.45, 0.6).set_trans(Tween.TRANS_SINE)
		t.tween_property(row, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	parent.add_child(box)
	return box


## حالتِ خالی یا خطا: آیکن + جمله‌ی کوتاه + (اختیاری) یک دکمه
## kind: "gold" برای پیشنهادِ اصلی، "dark" برای «دوباره»
static func message_state(parent: Control, icon: Texture2D, text: String,
		action_text: String = "", action: Callable = Callable(), kind: String = "dark") -> Control:
	var center := CenterContainer.new()
	center.name = "MessageState"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)
	if icon != null:
		var ic := MenuUI.icon(icon, 64.0, Color(1, 1, 1, 0.85))
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(ic)
	var l := MenuUI.label(text, 18, MenuUI.MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(320, 0)
	col.add_child(l)
	if action.is_valid() and action_text != "":
		var b := MenuUI.button(action_text, kind, 18)
		b.custom_minimum_size = Vector2(200, MenuUI.TOUCH_H)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void: UIFx.tap(b, action))
		col.add_child(b)
	parent.add_child(center)
	center.modulate.a = 0.0
	center.create_tween().tween_property(center, "modulate:a", 1.0, 0.2)
	return center


## E17/V7 پروازِ سکه: چند سکه‌ی کوچک از نقطه‌ی from (مختصاتِ صفحه) با قوسِ
## نرم تا وسطِ target می‌روند. on_arrive با رسیدنِ اولین سکه صدا زده می‌شود
## (شمارنده همان لحظه شروع به شمردن کند). روی لایه‌ی جدا، پس اگر صفحه‌ی
## جایزه بسته شد پرواز ادامه می‌دهد. target نامعتبر → هیچ کاری نمی‌کند.
static func fly(tex: Texture2D, from: Vector2, target: Control, count: int = 6,
		on_arrive: Callable = Callable()) -> void:
	if tex == null or target == null or not is_instance_valid(target) or not target.is_visible_in_tree():
		if on_arrive.is_valid():
			on_arrive.call()
		return
	var tree := target.get_tree()
	var layer := CanvasLayer.new()
	layer.layer = 120
	tree.root.add_child(layer)
	var to := target.get_global_rect().get_center()
	var arrived := [false]
	var n := clampi(count, 1, 10)
	for i in n:
		var coin := TextureRect.new()
		coin.texture = tex
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.size = Vector2(34, 34)
		coin.pivot_offset = coin.size * 0.5
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var start := from + Vector2(randf_range(-40, 40), randf_range(-24, 24))
		coin.position = start - coin.size * 0.5
		coin.modulate.a = 0.0
		layer.add_child(coin)
		# قوس: نقطه‌ی کنترل بالاتر از خطِ مستقیم
		var ctrl := (start + to) * 0.5 + Vector2(randf_range(-80, 80), -140.0)
		var t := coin.create_tween()
		t.tween_interval(0.05 * i)
		t.tween_property(coin, "modulate:a", 1.0, 0.08)
		t.tween_method(func(k: float) -> void:
			var a := start.lerp(ctrl, k)
			var b := ctrl.lerp(to, k)
			coin.position = a.lerp(b, k) - coin.size * 0.5
			coin.scale = Vector2.ONE * lerpf(1.0, 0.55, k), 0.0, 1.0, 0.55) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_callback(func() -> void:
			coin.queue_free()
			if is_instance_valid(target):
				pulse(target)
			if not arrived[0]:
				arrived[0] = true
				LocalSettings.vibrate(15)
				if on_arrive.is_valid():
					on_arrive.call())
	var done := layer.create_tween()
	done.tween_interval(0.05 * n + 0.8)
	done.tween_callback(layer.queue_free)
