extends PanelContainer
## یک ردیف اسلایدر در تب تنظیمات (صدای اصلی، روشنایی، ...).
##
## استفاده:
##   row.setup("master", "صدای اصلی", icon_texture, 60)
##   row.value_previewed.connect(...)   # حین کشیدن، برای اعمال زنده
##   row.value_committed.connect(...)   # بعد از رها کردن، برای ذخیره

## حین کشیدن (هر تغییر کوچک) — برای اعمال فوری روی صدا/تصویر
signal value_previewed(key: String, value: int)
## بعد از رها شدن دسته یا مکث کوتاه — برای ذخیره روی فایل
signal value_committed(key: String, value: int)

const FA_DIGITS := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]

const COLOR_IDLE := Color(0.78, 0.78, 0.80, 1.0)
const COLOR_HOT := Color(1.0, 1.0, 1.0, 1.0)
## V1 قرمز فقط برای خطر است؛ مقدارِ انتخاب‌شده طلایی (هم‌رنگ دکمه‌ی کیفیتِ انتخابی)
const COLOR_RED := Color(0.85, 0.64, 0.2, 1.0)
const COLOR_RED_HOT := Color(1.0, 0.86, 0.42, 1.0)

@onready var _slider: HSlider = $Row/Slider
@onready var _value_label: Label = $Row/ValueLabel
@onready var _name_label: Label = $Row/NameLabel
@onready var _icon: TextureRect = $Row/Icon
@onready var _row: HBoxContainer = $Row

## زمان‌سنج ذخیره: تا وقتی کاربر دست نگه نداشته روی فایل نمی‌نویسیم
var _save_timer: Timer

var key: String = ""
var _panel_style: StyleBoxFlat
var _fill_style: StyleBoxFlat
var _dragging := false
## وقتی خودمان مقدار را با انیمیشن عوض می‌کنیم، سیگنال بیرونی نده
var _silent := false

func _ready() -> void:
	_panel_style = get_theme_stylebox("panel").duplicate()
	add_theme_stylebox_override("panel", _panel_style)

	var fill := _slider.get_theme_stylebox("grabber_area")
	if fill is StyleBoxFlat:
		_fill_style = (fill as StyleBoxFlat).duplicate()
		_slider.add_theme_stylebox_override("grabber_area", _fill_style)
		_slider.add_theme_stylebox_override("grabber_area_highlight", _fill_style)

	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.45
	add_child(_save_timer)
	_save_timer.timeout.connect(_commit)

	_slider.value_changed.connect(_on_value_changed)
	_slider.drag_started.connect(_on_drag_started)
	_slider.drag_ended.connect(_on_drag_ended)

	# نکته: این بازی فقط موبایل/اندروید است، پس هیچ حالت hover نداریم؛
	# بازخورد بصری فقط موقع لمس و کشیدن دسته‌ی اسلایدر داده می‌شود.
	_icon.pivot_offset = _icon.custom_minimum_size * 0.5
	_value_label.pivot_offset = _value_label.custom_minimum_size * 0.5

# ------------------------------------------------------------------ API عمومی

func setup(row_key: String, title: String, icon: Texture2D, value: int) -> void:
	key = row_key
	if not is_node_ready():
		await ready
	_name_label.text = title
	if icon:
		_icon.texture = icon
	set_value_silent(value)

## گذاشتن مقدار بدون فایر شدن سیگنال‌ها (مقداردهی اولیه)
func set_value_silent(value: int) -> void:
	_silent = true
	_slider.value = clampf(float(value), _slider.min_value, _slider.max_value)
	_silent = false
	_value_label.text = _to_fa(int(_slider.value))

## رفتن نرم به مقدار جدید — برای دکمه‌ی «بازنشانی تنظیمات»
func animate_to(value: int, delay: float = 0.0) -> void:
	var target := clampf(float(value), _slider.min_value, _slider.max_value)
	var t := create_tween()
	if delay > 0.0:
		t.tween_interval(delay)
	t.tween_property(_slider, "value", target, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_callback(_commit)
	_flash_icon()

func current_value() -> int:
	return int(_slider.value)

## انیمیشن ورود ردیف (از راست به چپ) با تأخیر پلکانی
func play_intro(delay: float) -> void:
	if not is_node_ready():
		await ready
	# از scale استفاده می‌کنیم نه position: کانتینر والد موقعیت را بازنشانی می‌کند
	pivot_offset = Vector2(size.x, size.y * 0.5)
	modulate.a = 0.0
	scale = Vector2(0.82, 0.94)

	var t := create_tween()
	t.tween_interval(delay)
	t.set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "scale", Vector2.ONE, 0.44) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ------------------------------------------------------------------ رویدادها

func _on_value_changed(value: float) -> void:
	_value_label.text = _to_fa(int(value))
	_pop_value_label()
	_pulse_fill()
	if _silent:
		return
	value_previewed.emit(key, int(value))
	_save_timer.start()

func _on_drag_started() -> void:
	_dragging = true
	_tween_panel_alpha(0.10)
	_tween_icon_color(COLOR_RED_HOT)
	_scale_row(1.015)

func _on_drag_ended(value_changed: bool) -> void:
	_dragging = false
	_tween_panel_alpha(0.0)
	_tween_icon_color(COLOR_IDLE)
	_scale_row(1.0)
	if value_changed:
		_commit()

func _commit() -> void:
	_save_timer.stop()
	value_committed.emit(key, int(_slider.value))

# ----------------------------------------------------------------- انیمیشن‌ها

## عدد سمت چپ با هر تغییر یه تکون کوچیک می‌خوره
func _pop_value_label() -> void:
	_value_label.pivot_offset = _value_label.size * 0.5
	_value_label.scale = Vector2(1.18, 1.18)
	var t := create_tween()
	t.tween_property(_value_label, "scale", Vector2.ONE, 0.24) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## قسمت پرشده‌ی اسلایدر یه فلاش قرمز روشن می‌زنه
func _pulse_fill() -> void:
	if _fill_style == null:
		return
	_fill_style.bg_color = COLOR_RED_HOT
	var t := create_tween()
	t.tween_property(_fill_style, "bg_color", COLOR_RED, 0.28) \
		.set_trans(Tween.TRANS_SINE)

func _flash_icon() -> void:
	_icon.pivot_offset = _icon.size * 0.5
	_icon.scale = Vector2(1.3, 1.3)
	var t := create_tween()
	t.tween_property(_icon, "scale", Vector2.ONE, 0.36) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _tween_panel_alpha(alpha: float) -> void:
	if _panel_style == null:
		return
	var target := Color(1.0, 1.0, 1.0, alpha)
	create_tween().tween_property(_panel_style, "bg_color", target, 0.18) \
		.set_trans(Tween.TRANS_SINE)

func _tween_icon_color(color: Color) -> void:
	create_tween().tween_property(_icon, "modulate", color, 0.18)

func _scale_row(target: float) -> void:
	pivot_offset = size * 0.5
	create_tween().tween_property(self, "scale", Vector2(target, target), 0.18) \
		.set_trans(Tween.TRANS_SINE)

# ------------------------------------------------------------------- کمکی‌ها

## تبدیل عدد به رقم فارسی (۶۰ به‌جای 60) — مطابق طرح منو
func _to_fa(value: int) -> String:
	var out := ""
	for ch in str(value):
		var digit := ch.to_int() if ch >= "0" and ch <= "9" else -1
		out += FA_DIGITS[digit] if digit >= 0 else ch
	return out
