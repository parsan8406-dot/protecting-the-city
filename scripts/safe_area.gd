extends Node
## ناحیه‌ی امنِ صفحه (ناچ، پانچ‌هول، لبه‌ی خمیده) — autoload با نامِ SafeArea.
##
## حسابِ فاصله‌ی ناچ از چهار طرف قبلاً در هر صفحه جدا تکرار شده بود؛ این‌جا
## یک بار نوشته می‌شود و صفحه‌ها فقط می‌پرسند:
##   var ins := SafeArea.insets_for(self)   # Vector4(چپ، بالا، راست، پایین) به واحدِ ویوپورت
##
## چرخاندنِ ۱۸۰ درجه‌ای گوشی (sensor_landscape) ناچ را از چپ به راست می‌برد
## بی‌آنکه اندازه‌ی پنجره عوض شود — پس size_changed فایر نمی‌شود. برای همین
## هر نیم ثانیه ناحیه‌ی امن دوباره خوانده می‌شود و اگر فرق کرد سیگنالِ
## changed می‌آید تا صفحه‌ها دوباره بچینند.

signal changed

## هر چند ثانیه یک بار ناحیه‌ی امن چک شود (فقط روی گوشی)
const POLL_INTERVAL := 0.5

var _last := Vector4(-1.0, -1.0, -1.0, -1.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last = raw_insets()
	# روی PC ناحیه‌ی امن همیشه صفر است؛ تایمر بی‌خود باتری نمی‌سوزاند
	if not OS.has_feature("mobile"):
		return
	var timer := Timer.new()
	timer.wait_time = POLL_INTERVAL
	timer.autostart = true
	timer.timeout.connect(_poll)
	add_child(timer)
	get_tree().root.size_changed.connect(_poll)


func _notification(what: int) -> void:
	# برگشت از پس‌زمینه: شاید گوشی در این فاصله چرخیده باشد
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if is_inside_tree():
			_poll()


## فاصله‌ی ناچ/لبه‌ی خمیده از چهار طرف، به پیکسلِ واقعیِ پنجره.
## روی دسکتاپ صفر — آن‌جا safe area یعنی «صفحه منهای تسک‌بار» و ربطی به
## پنجره ندارد.
func raw_insets() -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var win_pos := DisplayServer.window_get_position()
	var win_size := DisplayServer.window_get_size()
	if safe.size.x <= 0 or win_size.x <= 0:
		return Vector4.ZERO
	return Vector4(
		maxf(0.0, float(safe.position.x - win_pos.x)),
		maxf(0.0, float(safe.position.y - win_pos.y)),
		maxf(0.0, float(win_pos.x + win_size.x - safe.end.x)),
		maxf(0.0, float(win_pos.y + win_size.y - safe.end.y)))


## همان فاصله‌ها به واحدِ ویوپورتِ item (همان واحدی که offsetها با آن نوشته می‌شوند)
func insets_for(item: CanvasItem) -> Vector4:
	var raw := raw_insets()
	if raw == Vector4.ZERO or item == null or not item.is_inside_tree():
		return Vector4.ZERO
	var win_size := DisplayServer.window_get_size()
	if win_size.x <= 0 or win_size.y <= 0:
		return Vector4.ZERO
	var k := item.get_viewport_rect().size / Vector2(win_size)
	return Vector4(raw.x * k.x, raw.y * k.y, raw.z * k.x, raw.w * k.y)


func _poll() -> void:
	var now := raw_insets()
	if now.is_equal_approx(_last):
		return
	_last = now
	changed.emit()
