extends RefCounted
## صدای کوتاهِ لمسِ دکمه‌های منو.
##
## V9 + E11: هر لمس سه بازخورد هم‌زمان دارد — فرو رفتنِ دکمه (UIFx)، روشن
## شدن، و این «تیک»ِ نرم. بازی تا حالا هیچ صدای UI نداشت؛ فایلی هم به APK
## اضافه نمی‌شود: صدا یک بار با چند خط ریاضی ساخته و کش می‌شود (PCMِ ۱۶ بیتی
## ۲۲ کیلوهرتز، حدودِ ۲ کیلوبایت). روی باس SFX پخش می‌شود تا با «صدای
## افکت‌ها»ی تنظیمات کم/زیاد یا بی‌صدا شود.
##
##   preload("res://scripts/psych_menu_ui_sfx.gd").tap(some_node)

const RATE := 22050
## دو لمس در کمتر از این فاصله فقط یک صدا دارند (press + tap روی یک دکمه)
const MIN_GAP_MS := 60
const BUS := &"SFX"

static var _stream: AudioStreamWAV = null
static var _player: AudioStreamPlayer = null
static var _last_ms := -1000


## تیکِ لمس. any_node فقط برای پیدا کردنِ SceneTree است.
static func tap(any_node: Node) -> void:
	if any_node == null or not is_instance_valid(any_node) or not any_node.is_inside_tree():
		return
	var now := Time.get_ticks_msec()
	if now - _last_ms < MIN_GAP_MS:
		return
	_last_ms = now
	if DisplayServer.get_name() == "headless":
		return
	if _player == null or not is_instance_valid(_player):
		_player = AudioStreamPlayer.new()
		_player.name = "PsychMenuUiSfx"
		_player.stream = _get_stream()
		_player.max_polyphony = 3
		_player.volume_db = -6.0
		if AudioServer.get_bus_index(BUS) >= 0:
			_player.bus = BUS
		# بچه‌ی root، نه صحنه: با عوض شدنِ صحنه (که اغلب همان لحظه است) قطع نشود
		any_node.get_tree().root.add_child.call_deferred(_player)
		_player.play.call_deferred()
		return
	if _player.is_inside_tree():
		_player.pitch_scale = randf_range(0.96, 1.04)
		_player.play()


## «تیک»: ضربه‌ی خیلی کوتاهِ زیر که سریع پایین می‌آید + کمی بدنه‌ی بم
static func _get_stream() -> AudioStreamWAV:
	if _stream != null:
		return _stream
	var length := 0.06
	var n := int(length * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var phase2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := float(i) / float(n - 1)
		phase += TAU * lerpf(1700.0, 900.0, u) / RATE
		phase2 += TAU * 320.0 / RATE
		var env := minf(t / 0.0015, 1.0) * exp(-t / 0.012)
		env *= clampf((length - t) / 0.004, 0.0, 1.0)
		var s := 0.32 * env * sin(phase) + 0.18 * env * sin(phase2)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	_stream = AudioStreamWAV.new()
	_stream.format = AudioStreamWAV.FORMAT_16_BITS
	_stream.mix_rate = RATE
	_stream.stereo = false
	_stream.data = data
	return _stream
