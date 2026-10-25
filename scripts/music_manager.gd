extends AudioStreamPlayer

## موزیک قبل از رفتن به پس‌زمینه در حال پخش بود؟ (فقط همان را برمی‌گردانیم)
var _was_playing := false


func start_music():
	if not playing:
		play()


## چرخه‌ی عمر موبایل: minimize، تماس تلفنی یا پایین کشیدن نوار اعلان —
## موزیک نباید پشت تماس پخش شود و بعد از برگشت از همان‌جا ادامه می‌دهد
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_pause_for_background()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			# روی PC فوکوس پنجره مدام عوض می‌شود؛ فقط روی گوشی
			if OS.has_feature("mobile"):
				_pause_for_background()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			if _was_playing:
				_was_playing = false
				stream_paused = false


func _pause_for_background() -> void:
	if playing and not stream_paused:
		_was_playing = true
		stream_paused = true
