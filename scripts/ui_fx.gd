class_name UIFx
extends RefCounted
## افکت‌های کوچک UI که همه‌جای پروژه استفاده می‌شن.
## همه‌ی توابع static ان، پس بدون ساختن نمونه صداشون بزن: UIFx.press(button)

# -----------------------------------------------------------------------------
# press — انیمیشن اصلی لمس دکمه
# -----------------------------------------------------------------------------
# سه لایه‌ی هم‌زمان، همه بدون چرخش و بدون لرزش کشسان:
#   ۱) فرو رفتن سریع و تمیز، بعد برگشت نرم با یه اورشوت خیلی کم که آروم می‌شینه
#   ۲) یه حلقه‌ی نازک طلایی که از لبه‌ی دکمه بیرون می‌زنه و محو میشه
#   ۳) یه روشن شدن گرم و ملایم (نه فلاش)

## چقدر دکمه موقع فشرده شدن جمع بشه
const PRESS_DOWN_SCALE := Vector2(0.93, 0.93)
## اورشوت ریز موقع برگشت — فقط در حدی که حرکت زنده به نظر بیاد
const PRESS_OVERSHOOT_SCALE := Vector2(1.03, 1.03)
const PRESS_DOWN_TIME := 0.08
const PRESS_RISE_TIME := 0.14
const PRESS_SETTLE_TIME := 0.24
## روشنایی گرم لحظه‌ی لمس (کمی به سمت طلایی)
const PRESS_GLOW := Color(1.16, 1.10, 0.98, 1.0)
## رنگ حلقه‌ی بیرون‌زننده — طلایی تم
const RING_COLOR := Color(1.0, 0.80, 0.30, 0.9)
## حلقه چند پیکسل از لبه‌ی دکمه بیرون می‌ره
const RING_SPREAD := 16.0
const RING_TIME := 0.42
## اکشن بعدی (مثلاً تعویض صحنه) کِی اجرا بشه — بعد از فرو رفتن و وسط برگشت
const PRESS_CALLBACK_DELAY := 0.15
## V9 + E11: تیکِ صوتیِ لمس، کنارِ انیمیشن (باس SFX، با تنظیمات بی‌صدا می‌شود)
const UI_SFX := preload("res://scripts/psych_menu_ui_sfx.gd")

## انیمیشن لمس اصلی. اگه on_finished داده بشه، بعد از حرکت صدا زده میشه
## (مثلاً برای عوض کردن صحنه، تا بازیکن انیمیشن رو ببینه).
static func press(control: Control, on_finished: Callable = Callable()) -> void:
	if control == null or not is_instance_valid(control):
		if on_finished.is_valid():
			on_finished.call()
		return

	# لمس‌های پشت‌سرهم: تویین قبلی رو می‌کشیم تا با هم دعوا نکنن
	_kill_press_tweens(control)
	control.pivot_offset = control.size * 0.5

	var scale_tween := control.create_tween()
	scale_tween.tween_property(control, "scale", PRESS_DOWN_SCALE, PRESS_DOWN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(control, "scale", PRESS_OVERSHOOT_SCALE, PRESS_RISE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(control, "scale", Vector2.ONE, PRESS_SETTLE_TIME) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)

	var glow_tween := control.create_tween()
	glow_tween.tween_property(control, "modulate", PRESS_GLOW, PRESS_DOWN_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	glow_tween.tween_property(control, "modulate", Color.WHITE, 0.32) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	control.set_meta("_press_tweens", [scale_tween, glow_tween])
	_spawn_ring(control)
	UI_SFX.tap(control)

	if on_finished.is_valid():
		var delay_tween := control.create_tween()
		delay_tween.tween_interval(PRESS_CALLBACK_DELAY)
		delay_tween.tween_callback(on_finished)

## وصل کردن انیمیشن press به یه دکمه، با یه اکشن اختیاری بعدش.
static func bind_press(button: BaseButton, on_finished: Callable = Callable()) -> void:
	if button == null:
		return
	var handler := func() -> void:
		press(button, on_finished)
	if not button.pressed.is_connected(handler):
		button.pressed.connect(handler)

static func _kill_press_tweens(control: Control) -> void:
	if not control.has_meta("_press_tweens"):
		return
	for tw in control.get_meta("_press_tweens"):
		if tw is Tween and tw.is_valid():
			tw.kill()
	control.remove_meta("_press_tweens")

## حلقه‌ی طلایی دور دکمه. روی Containerها ساخته نمیشه، چون بچه‌ی جدید
## وارد چیدمانشون میشه و جای بقیه رو به هم می‌ریزه.
static func _spawn_ring(control: Control) -> void:
	if control is Container or not control.is_visible_in_tree():
		return
	if control.size.x < 1.0 or control.size.y < 1.0:
		return

	var old := control.get_node_or_null("_PressRing")
	if old:
		old.queue_free()
		control.remove_child(old)

	var ring := _PressRing.new()
	ring.name = "_PressRing"
	control.add_child(ring)
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var t := ring.create_tween()
	t.tween_property(ring, "progress", 1.0, RING_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_callback(ring.queue_free)

## یه Control سبک که فقط یه خط دور دکمه می‌کشه؛ با بزرگ شدن progress
## بیرون می‌ره، نازک میشه و محو میشه.
class _PressRing extends Control:
	var progress: float = 0.0:
		set(value):
			progress = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE

	func _draw() -> void:
		var spread := UIFx.RING_SPREAD * progress
		var alpha := UIFx.RING_COLOR.a * (1.0 - progress) * (1.0 - progress)
		if alpha <= 0.01:
			return
		var color := Color(UIFx.RING_COLOR, alpha)
		var width := lerpf(3.0, 1.0, progress)

		# دکمه‌های تقریباً مربعی (آیکون‌ها) حلقه‌ی دایره‌ای می‌گیرن،
		# دکمه‌های کشیده یه قاب گرد‌گوشه
		var aspect := size.x / maxf(size.y, 1.0)
		if aspect > 0.8 and aspect < 1.25:
			var radius := maxf(size.x, size.y) * 0.5 + spread
			draw_arc(size * 0.5, radius, 0.0, TAU, 48, color, width, true)
		else:
			var box := StyleBoxFlat.new()
			box.draw_center = false
			box.anti_aliasing = true
			box.border_color = color
			box.set_border_width_all(int(ceilf(width)))
			box.set_corner_radius_all(int(minf(size.y * 0.3, 28.0) + spread))
			draw_style_box(box, Rect2(Vector2(-spread, -spread), size + Vector2(spread, spread) * 2.0))

# -----------------------------------------------------------------------------
# tap — نسخه‌ی کم‌صدای press برای دکمه‌های کوچیک و متراکم
# -----------------------------------------------------------------------------
# روی لیست‌ها، کارت‌ها و دیالوگ‌ها حلقه‌ی بیرون‌زننده شلوغ میشه.
# tap فقط همون فرو رفتن کم‌عمق و یه روشن شدن ملایم رو داره.

## چقدر دکمه موقع فشرده شدن جمع بشه
const TAP_DOWN_SCALE := Vector2(0.965, 0.965)
## روشنایی لحظه‌ای موقع لمس — عمداً نزدیک سفیده که فلاش نزنه
const TAP_GLOW := Color(1.14, 1.14, 1.17, 1.0)

## انیمیشن لمس نرم. مثل press، اگه on_finished داده بشه بعد از حرکت صدا زده میشه.
static func tap(control: Control, on_finished: Callable = Callable()) -> void:
	if control == null or not is_instance_valid(control):
		if on_finished.is_valid():
			on_finished.call()
		return

	control.pivot_offset = control.size * 0.5
	UI_SFX.tap(control)

	# فرو رفتن کوتاه، بعد برگشت با اورشوت ملایم — یه بار می‌پره بیرون و می‌شینه
	var scale_tween := control.create_tween()
	scale_tween.tween_property(control, "scale", TAP_DOWN_SCALE, 0.07) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(control, "scale", Vector2.ONE, 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# روشن شدن سریع و محو شدن آروم
	var glow_tween := control.create_tween()
	glow_tween.tween_property(control, "modulate", TAP_GLOW, 0.07) \
		.set_trans(Tween.TRANS_SINE)
	glow_tween.tween_property(control, "modulate", Color.WHITE, 0.26) \
		.set_trans(Tween.TRANS_SINE)

	if on_finished.is_valid():
		var delay_tween := control.create_tween()
		delay_tween.tween_interval(0.12)
		delay_tween.tween_callback(on_finished)

## وصل کردن انیمیشن لمس نرم به یه دکمه.
static func bind_tap(button: BaseButton, on_finished: Callable = Callable()) -> void:
	if button == null:
		return
	var handler := func() -> void:
		tap(button, on_finished)
	if not button.pressed.is_connected(handler):
		button.pressed.connect(handler)

## بازخورد نگه‌داشتن انگشت روی دکمه: تا وقتی پایینه جمع می‌مونه، با رها شدن
## نرم برمی‌گرده. این با tap فرق داره — tap روی «کلیک کامل» اجرا میشه.
##
## جای تکرار کردن _press_visual توی هر اسکریپت، یه بار اینو صدا بزن.
static func bind_press_feedback(button: BaseButton) -> void:
	if button == null:
		return
	button.button_down.connect(func() -> void: press_scale(button, true))
	button.button_up.connect(func() -> void: press_scale(button, false))
	button.pressed.connect(func() -> void: UI_SFX.tap(button))

## جمع/باز شدن دکمه زیر انگشت
static func press_scale(control: Control, down: bool) -> void:
	if control == null or not is_instance_valid(control):
		return

	control.pivot_offset = control.size * 0.5
	var t := control.create_tween()

	if down:
		t.tween_property(control, "scale", TAP_DOWN_SCALE, 0.08) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		t.tween_property(control, "scale", Vector2.ONE, 0.28) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
