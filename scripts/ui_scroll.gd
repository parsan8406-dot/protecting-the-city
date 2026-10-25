class_name UIScroll
extends RefCounted
## اسکرول‌بار باریکِ خودمان — نازک، طلایی، مستطیلی، و معمولاً نامرئی.
##
## اسکرول‌بار پیش‌فرض Godot پهن است و همیشه دیده می‌شود؛ روی موبایل هم فضا
## می‌گیرد هم توی چشم است. این یکی:
##   - ۴ پیکسل عرض، بدون گردی (مستطیل)
##   - وقتی دست به اسکرول نخورده کاملاً محو است
##   - به محض کشیدن/اسکرول ظاهر می‌شود و بعد از کمی مکث دوباره محو می‌شود
##
## خودِ کشیدن با انگشت دست نمی‌خورد — ScrollContainer همان‌طور که بود کار
## می‌کند، فقط نوارش دیده نمی‌شود.
##
## استفاده (یک بار، معمولاً در _ready):
##   UIScroll.attach(my_scroll_container)

## عرض نوار (پیکسل)
const THICKNESS := 4

## رنگ دستگیره — طلاییِ تمِ بازی (سیاه/قرمز/طلایی)
const COLOR_GRABBER := Color(0.96, 0.78, 0.3, 1.0)
## رنگ دستگیره زیر انگشت — طلاییِ روشن‌تر
const COLOR_GRABBER_ACTIVE := Color(1.0, 0.86, 0.45, 1.0)
## ریلِ پشت نوار — خیلی کم‌رنگ، فقط برای اینکه مسیر معلوم باشد
const COLOR_RAIL := Color(0.96, 0.78, 0.3, 0.12)

## چقدر بعد از آخرین حرکت، نوار محو شود
const FADE_DELAY := 0.7
## مدت محو شدن
const FADE_TIME := 0.35

## کلید متادیتای توییِن محو — روی خود نوار ذخیره می‌شود تا هر نوار
## توییِن خودش را داشته باشد و کنسل کردنش بقیه را خراب نکند
const META_TWEEN := "ui_scroll_fade"

## اسکرول‌بارهای یک ScrollContainer را باریک و خودمحوکن می‌کند.
## چند بار صدا زدنش بی‌خطر است.
static func attach(scroll: ScrollContainer) -> void:
	if scroll == null or not is_instance_valid(scroll):
		return
	_setup(scroll.get_v_scroll_bar(), true)
	_setup(scroll.get_h_scroll_bar(), false)

static func _setup(bar: ScrollBar, vertical: bool) -> void:
	if bar == null or not is_instance_valid(bar):
		return
	# جلوی دوباره وصل شدن سیگنال‌ها موقع attach دوم
	if bar.has_meta(META_TWEEN + "_ready"):
		return
	bar.set_meta(META_TWEEN + "_ready", true)

	bar.custom_minimum_size = Vector2(THICKNESS, 0) if vertical else Vector2(0, THICKNESS)

	bar.add_theme_stylebox_override("scroll", _rail_style(vertical))
	var grabber := _grabber_style(vertical, COLOR_GRABBER)
	var grabber_active := _grabber_style(vertical, COLOR_GRABBER_ACTIVE)
	bar.add_theme_stylebox_override("grabber", grabber)
	bar.add_theme_stylebox_override("grabber_highlight", grabber_active)
	bar.add_theme_stylebox_override("grabber_pressed", grabber_active)

	# اول کار نامرئی
	bar.modulate.a = 0.0

	# هر حرکتی روی محتوا یا خود نوار، نوار را نشان می‌دهد
	bar.value_changed.connect(func(_v: float) -> void: _flash(bar))
	bar.scrolling.connect(func() -> void: _flash(bar))

## نوار را نشان می‌دهد و بعد از مکث دوباره محو می‌کند
static func _flash(bar: ScrollBar) -> void:
	if bar == null or not is_instance_valid(bar):
		return

	# نواری که اصلاً جای اسکرول ندارد نباید سوسو بزند
	if bar.max_value - bar.min_value <= bar.page:
		bar.modulate.a = 0.0
		return

	# get_meta با پیش‌فرض null خطا می‌دهد (null یعنی «پیش‌فرض ندارد»)
	var previous := (bar.get_meta(META_TWEEN) if bar.has_meta(META_TWEEN) else null) as Tween
	if previous != null and previous.is_valid():
		previous.kill()

	bar.modulate.a = 1.0
	var tween := bar.create_tween()
	tween.tween_interval(FADE_DELAY)
	tween.tween_property(bar, "modulate:a", 0.0, FADE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	bar.set_meta(META_TWEEN, tween)

static func _rail_style(vertical: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_RAIL
	style.set_corner_radius_all(0)
	# ریل عمداً از دستگیره نازک‌تر است تا فقط یک خط راهنما باشد
	if vertical:
		style.content_margin_left = 1.0
		style.content_margin_right = 1.0
	else:
		style.content_margin_top = 1.0
		style.content_margin_bottom = 1.0
	return style

static func _grabber_style(vertical: bool, color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	# مستطیل، بدون گردی
	style.set_corner_radius_all(0)
	if vertical:
		style.content_margin_left = 0.0
		style.content_margin_right = 0.0
	else:
		style.content_margin_top = 0.0
		style.content_margin_bottom = 0.0
	return style
