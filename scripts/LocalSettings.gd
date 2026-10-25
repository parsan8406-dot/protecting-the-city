extends Node

## ============================================================================
## تنظیمات محلی دستگاه — هیچ‌کدام از این مقادیر به دیتابیس نمی‌روند.
##
## دلیل: این‌ها به «دستگاه» وابسته‌اند نه به «اکانت». صدا و روشنایی روی گوشی
## و تبلت باید مستقل باشند. ذخیره‌سازی در user://settings.cfg انجام می‌شود
## که روی اندروید هم دائمی است.
##
## اگر روزی خواستی این‌ها بین دستگاه‌ها سینک شوند، فقط کافی است بعد از
## لاگین گوگل، همین دیکشنری را در فیلد players.device_settings آپلود کنی.
## ============================================================================

const SETTINGS_PATH := "user://settings.cfg"

signal audio_settings_changed
signal video_settings_changed

# --- صدا (منوی تنظیمات → بخش صدا) ---
var master_volume: int = 60   # صدای اصلی
var sfx_volume: int = 50      # صدای افکت ها
var ambient_volume: int = 70  # صدای محیط
var music_volume: int = 50    # صدای موزیک

# --- تصویر (منوی تنظیمات → بخش تصویر) ---
var brightness: int = 70      # روشنایی
var quality: int = 70         # کیفیت

# --- ترجیحات رابط کاربری ---
var language: String = "fa"
var vibration_enabled: bool = true
## E11 لرزش صفحه (تکان دوربین/هیت‌استاپ) — گزینه‌ی دسترس‌پذیری برای کسانی که حالشان بد می‌شود
var screen_shake: bool = true
var show_fps: bool = false
var joystick_side: String = "left"

# --- کش موقت (فقط داخل همین اجرا، ذخیره هم نمی‌شود) ---
var last_opened_menu_tab: int = 0
var selected_friend_id: String = ""
var cached_avatars: Dictionary = {}

const _DEFAULTS := {
	"master_volume": 60,
	"sfx_volume": 50,
	"ambient_volume": 70,
	"music_volume": 50,
	"brightness": 70,
	"quality": 70,
	"language": "fa",
	"vibration_enabled": true,
	"screen_shake": true,
	"show_fps": false,
	"joystick_side": "left",
}


## نام لایه‌ی روشنایی که روی همه‌ی صحنه‌ها کشیده می‌شود
const BRIGHTNESS_LAYER_NAME := "BrightnessOverlay"


func _ready() -> void:
	load_settings()
	apply_audio()
	apply_video()


## خواندن تنظیمات از فایل محلی
func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return  # فایلی نیست — مقادیر پیش‌فرض می‌مانند

	master_volume = config.get_value("audio", "master_volume", _DEFAULTS.master_volume)
	sfx_volume = config.get_value("audio", "sfx_volume", _DEFAULTS.sfx_volume)
	ambient_volume = config.get_value("audio", "ambient_volume", _DEFAULTS.ambient_volume)
	music_volume = config.get_value("audio", "music_volume", _DEFAULTS.music_volume)

	brightness = config.get_value("video", "brightness", _DEFAULTS.brightness)
	quality = config.get_value("video", "quality", _DEFAULTS.quality)

	language = config.get_value("ui", "language", _DEFAULTS.language)
	vibration_enabled = config.get_value("ui", "vibration_enabled", _DEFAULTS.vibration_enabled)
	screen_shake = bool(config.get_value("ui", "screen_shake", _DEFAULTS.screen_shake))
	show_fps = config.get_value("ui", "show_fps", _DEFAULTS.show_fps)
	joystick_side = config.get_value("ui", "joystick_side", _DEFAULTS.joystick_side)


## نوشتن تنظیمات روی فایل محلی
func save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "ambient_volume", ambient_volume)
	config.set_value("audio", "music_volume", music_volume)

	config.set_value("video", "brightness", brightness)
	config.set_value("video", "quality", quality)

	config.set_value("ui", "language", language)
	config.set_value("ui", "vibration_enabled", vibration_enabled)
	config.set_value("ui", "screen_shake", screen_shake)
	config.set_value("ui", "show_fps", show_fps)
	config.set_value("ui", "joystick_side", joystick_side)

	config.save(SETTINGS_PATH)


## تغییر یک مقدار صوتی و اعمال فوری آن روی AudioServer
func set_audio(key: String, value: int) -> void:
	match key:
		"master": master_volume = value
		"sfx": sfx_volume = value
		"ambient": ambient_volume = value
		"music": music_volume = value
		_: return
	apply_audio()
	save_settings()
	audio_settings_changed.emit()


## تغییر یک مقدار تصویری
func set_video(key: String, value: int) -> void:
	match key:
		"brightness": brightness = value
		"quality": quality = value
		_: return
	apply_video()
	save_settings()
	video_settings_changed.emit()


## سه پله‌ی کیفیت. عدد ذخیره‌شده همان درصد قدیمی است تا فایل تنظیماتِ
## نسخه‌های قبل هم درست خوانده شود: زیر ۵۰ کم، زیر ۸۵ متوسط، بقیه زیاد.
const QUALITY_LOW := 0
const QUALITY_MEDIUM := 1
const QUALITY_HIGH := 2
const QUALITY_VALUES := [30, 70, 100]

func quality_level() -> int:
	if quality < 50:
		return QUALITY_LOW
	if quality < 85:
		return QUALITY_MEDIUM
	return QUALITY_HIGH

func set_quality_level(level: int) -> void:
	set_video("quality", int(QUALITY_VALUES[clampi(level, 0, 2)]))

func set_vibration(enabled: bool) -> void:
	vibration_enabled = enabled
	save_settings()

## E11 لرزش صفحه: افکت‌های رزمی (تکان دوربین، هیت‌استاپ، فلش شدید) قبل از
## اجرا این را بپرسند. با video_settings_changed خبر داده می‌شود.
func screen_shake_enabled() -> bool:
	return screen_shake

## ضریب شدت تکان صفحه: ۱ یا ۰ — برای ضرب مستقیم در دامنه‌ی shake
func screen_shake_scale() -> float:
	return 1.0 if screen_shake else 0.0

func set_screen_shake(enabled: bool) -> void:
	if screen_shake == enabled:
		return
	screen_shake = enabled
	save_settings()
	video_settings_changed.emit()

## لرزش کوتاه فقط اگر بازیکن خاموشش نکرده باشد (و فقط روی موبایل)
func vibrate(ms: int) -> void:
	if vibration_enabled and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

## کیفیت واقعاً چیزی را عوض می‌کند:
##   کم     → ۳۰ فریم (باتری و گرمای گوشی)، بدون آنتی‌الیاس
##   متوسط  → ۶۰ فریم
##   زیاد   → ۶۰ فریم + درخشش (glow/HDR) و نورهای بیشتر — Arena و CombatFX
##            خودشان از quality_level() می‌خوانند و با video_settings_changed
##            همان لحظه عوض می‌شوند.
##
## MSAAِ دوبعدی عمداً خاموش است: روی GL Compatibility کلِ صحنه را چند
## نمونه‌ای می‌کشد (پهنای باند و باتری)، در حالی که بیشترِ لبه‌های این بازی
## اسپرایت‌اند و MSAA اصلاً رویشان اثری ندارد.
func _apply_quality() -> void:
	var level := quality_level()
	Engine.max_fps = 30 if level == QUALITY_LOW else 60
	var root := get_tree().root if is_inside_tree() else null
	if root != null:
		root.msaa_2d = Viewport.MSAA_DISABLED

## اعمال روشنایی روی کل بازی.
##
## یک ColorRect تمام‌صفحه روی بالاترین CanvasLayer می‌گذاریم تا هم دنیای بازی
## و هم رابط کاربری (که خودشان CanvasLayer دارند) را پوشش بدهد.
## ۷۰ نقطه‌ی خنثی است: پایین‌ترش تیره می‌کند، بالاترش کمی روشن‌تر.
func apply_video() -> void:
	_apply_quality()
	var tint := _brightness_rect()
	if tint == null:
		return
	var value := clampf(float(brightness) / 100.0, 0.0, 1.0)
	if value < 0.7:
		tint.color = Color(0.0, 0.0, 0.0, (0.7 - value) / 0.7 * 0.6)
	else:
		tint.color = Color(1.0, 1.0, 1.0, (value - 0.7) / 0.3 * 0.12)
	# مستطیلِ تمام‌صفحه حتی با آلفای صفر هم کشیده می‌شود (یک پاسِ کاملِ
	# بلندینگ روی هر فریم) — در روشناییِ خنثی اصلاً نباید باشد
	tint.visible = tint.color.a > 0.002


## ساخت (یا پیدا کردن) لایه‌ی روشنایی
func _brightness_rect() -> ColorRect:
	var root := get_tree().root if is_inside_tree() else null
	if root == null:
		return null

	var layer := root.get_node_or_null(BRIGHTNESS_LAYER_NAME) as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = BRIGHTNESS_LAYER_NAME
		layer.layer = 128

		var rect := ColorRect.new()
		rect.name = "Tint"
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.color = Color(0.0, 0.0, 0.0, 0.0)
		layer.add_child(rect)

		root.add_child.call_deferred(layer)

	return layer.get_node_or_null("Tint") as ColorRect


## اعمال درصدها روی باس‌های صوتی موتور
func apply_audio() -> void:
	_apply_bus("Master", master_volume)
	_apply_bus("SFX", sfx_volume)
	_apply_bus("Ambient", ambient_volume)
	_apply_bus("Music", music_volume)


## باس‌هایی که یک بار دربارهٔ نبودنشان هشدار داده‌ایم (تا لاگ پر نشود)
var _missing_buses := {}

func _apply_bus(bus_name: String, percent: int) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		# باس صوتی در default_bus_layout.tres تعریف نشده — اسلایدرش هیچ اثری ندارد
		if not _missing_buses.has(bus_name):
			_missing_buses[bus_name] = true
			push_warning("باس صوتی «%s» وجود ندارد؛ اسلایدر مربوطه بی‌اثر است." % bus_name)
		return
	if percent <= 0:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(float(percent) / 100.0))


## بازنشانی تنظیمات (دکمه «بازنشانی تنظیمات»)
func reset_to_defaults() -> void:
	master_volume = _DEFAULTS.master_volume
	sfx_volume = _DEFAULTS.sfx_volume
	ambient_volume = _DEFAULTS.ambient_volume
	music_volume = _DEFAULTS.music_volume
	brightness = _DEFAULTS.brightness
	quality = _DEFAULTS.quality
	language = _DEFAULTS.language
	vibration_enabled = _DEFAULTS.vibration_enabled
	screen_shake = _DEFAULTS.screen_shake
	show_fps = _DEFAULTS.show_fps
	joystick_side = _DEFAULTS.joystick_side

	apply_audio()
	apply_video()
	save_settings()
	audio_settings_changed.emit()
	video_settings_changed.emit()
