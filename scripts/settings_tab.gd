extends Control
## تب تنظیمات (منوی کاربر → تنظیمات).
##
## ستون راست: صدا، تصویر، کیفیت و لرزش — همه در LocalSettings و فایل
## user://settings.cfg (به دستگاه وابسته‌اند نه به اکانت).
##
## ستون چپ: اکانت — اتصال با گوگل (سرور: handlers_auth.go).
##   مهمان        → «اتصال با گوگل»: همین حساب به گوگل وصل و محافظت می‌شود
##   وصل‌شده      → ایمیل گوگل + «جدا کردن»؛ «ورود با حساب گوگل دیگر»
##   قفل (401)    → حساب محافظت‌شده است و این دستگاه توکن ندارد: «ورود با گوگل»
## ورود/بازیابی: روی گوشی تازه «ورود با گوگل» حسابِ وصل‌شده را پیدا می‌کند و
## همه‌ی پیشرفت برمی‌گردد.

## آدرس کانال/اکانت پشتیبانی — هر وقت عوض شد فقط همین خط را تغییر بده
const SUPPORT_TELEGRAM := "https://t.me/gun_game_support"

## باکس نوشتن پیام (کیبورد اندروید) — با دکمه‌ی «ارسال پیام» باز می‌شود
const MESSAGE_DIALOG := preload("res://secense/message_dialog.tscn")

const ICON_MASTER := preload("res://assets/ui/profile_menu/settings_icon_master.svg")
const ICON_SFX := preload("res://assets/ui/profile_menu/settings_icon_sfx.svg")
const ICON_AMBIENT := preload("res://assets/ui/profile_menu/settings_icon_ambient.svg")
const ICON_MUSIC := preload("res://assets/ui/profile_menu/settings_icon_music.svg")
const ICON_BRIGHTNESS := preload("res://assets/ui/profile_menu/settings_icon_brightness.svg")
const ICON_SHIELD_ON := preload("res://assets/ui/profile_menu/settings_icon_shield.svg")
const ICON_SHIELD_OFF := preload("res://assets/ui/profile_menu/settings_icon_shield_off.svg")

## مقادیر پیش‌فرض دکمه‌ی «بازنشانی تنظیمات» — هم‌ارز با _DEFAULTS در LocalSettings
const DEFAULTS := {
	"master": 60,
	"sfx": 50,
	"ambient": 70,
	"music": 50,
	"brightness": 70,
}
const QUALITY_TITLES := ["کم", "متوسط", "زیاد"]

const COLOR_GUEST := Color(1.0, 0.42, 0.4, 1.0)
const COLOR_SAFE := Color(1.0, 0.8, 0.26, 1.0)

@onready var _status_http: HTTPRequest = $StatusHTTP
@onready var _action_http: HTTPRequest = $ActionHTTP
@onready var _flow: GoogleAuthFlow = $GoogleFlow

# --- ستون اکانت ---
@onready var _account_panel: PanelContainer = $Columns/AccountPanel
@onready var _id_label: Label = $Columns/AccountPanel/Margin/Body/TitleRow/IdLabel
@onready var _status_card: PanelContainer = $Columns/AccountPanel/Margin/Body/StatusCard
@onready var _status_title: Label = $Columns/AccountPanel/Margin/Body/StatusCard/Margin/Row/Info/StatusTitle
@onready var _status_detail: Label = $Columns/AccountPanel/Margin/Body/StatusCard/Margin/Row/Info/StatusDetail
@onready var _shield_icon: TextureRect = $Columns/AccountPanel/Margin/Body/StatusCard/Margin/Row/ShieldIcon
@onready var _google_button: Button = $Columns/AccountPanel/Margin/Body/GoogleButton
@onready var _recover_button: Button = $Columns/AccountPanel/Margin/Body/RecoverButton
@onready var _waiting_panel: PanelContainer = $Columns/AccountPanel/Margin/Body/WaitingPanel
@onready var _wait_label: Label = $Columns/AccountPanel/Margin/Body/WaitingPanel/Margin/Col/WaitLabel
@onready var _cancel_wait_button: Button = $Columns/AccountPanel/Margin/Body/WaitingPanel/Margin/Col/Buttons/CancelWaitButton
@onready var _returned_button: Button = $Columns/AccountPanel/Margin/Body/WaitingPanel/Margin/Col/Buttons/ReturnedButton
@onready var _unlink_button: Button = $Columns/AccountPanel/Margin/Body/UnlinkButton
@onready var _message_button: Button = $Columns/AccountPanel/Margin/Body/SupportRow/MessageButton
@onready var _telegram_button: Button = $Columns/AccountPanel/Margin/Body/SupportRow/TelegramButton

# --- ستون صدا و تصویر ---
@onready var _audio_panel: PanelContainer = $Columns/SideColumn/AudioPanel
@onready var _video_panel: PanelContainer = $Columns/SideColumn/VideoPanel
@onready var _master_row := $Columns/SideColumn/AudioPanel/Margin/Body/Rows/MasterRow
@onready var _sfx_row := $Columns/SideColumn/AudioPanel/Margin/Body/Rows/SfxRow
@onready var _ambient_row := $Columns/SideColumn/AudioPanel/Margin/Body/Rows/AmbientRow
@onready var _music_row := $Columns/SideColumn/AudioPanel/Margin/Body/Rows/MusicRow
@onready var _brightness_row := $Columns/SideColumn/VideoPanel/Margin/Body/Rows/BrightnessRow
@onready var _quality_choices: HBoxContainer = $Columns/SideColumn/VideoPanel/Margin/Body/QualityRow/Choices
@onready var _vibration_toggle: CheckButton = $Columns/SideColumn/VideoPanel/Margin/Body/VibrationRow/VibrationToggle
## E11 لرزش صفحه (تکان دوربین) — جدا از لرزش گوشی
@onready var _shake_toggle: CheckButton = $Columns/SideColumn/VideoPanel/Margin/Body/ShakeRow/ShakeToggle
@onready var _reset_button: Button = $Columns/SideColumn/VideoPanel/Margin/Body/ResetRow/ResetButton

# --- پیام شناور ---
@onready var _toast: PanelContainer = $Toast
@onready var _toast_label: Label = $Toast/ToastLabel

## همه‌ی ردیف‌های اسلایدر به ترتیب نمایش (برای انیمیشن پلکانی و بازنشانی)
var _rows: Array = []
var _quality_buttons: Array[Button] = []
var _toast_tween: Tween

## آخرین پاسخ /auth/status
var _status: Dictionary = {}
var _status_failed := false
## کار در جریان روی سرور (جدا کردن از گوگل) — جلوی تپ دوباره
var _busy := false

# ------------------------------------------------------------------ آماده‌سازی

func _ready() -> void:
	_rows = [_master_row, _sfx_row, _ambient_row, _music_row, _brightness_row]

	_master_row.setup("master", "صدای اصلی", ICON_MASTER, LocalSettings.master_volume)
	_sfx_row.setup("sfx", "صدای افکت ها", ICON_SFX, LocalSettings.sfx_volume)
	_ambient_row.setup("ambient", "صدای محیط", ICON_AMBIENT, LocalSettings.ambient_volume)
	_music_row.setup("music", "صدای موزیک", ICON_MUSIC, LocalSettings.music_volume)
	_brightness_row.setup("brightness", "روشنایی", ICON_BRIGHTNESS, LocalSettings.brightness)

	for row in _rows:
		row.value_previewed.connect(_on_value_previewed)
		row.value_committed.connect(_on_value_committed)

	_build_quality_choices()
	_vibration_toggle.button_pressed = LocalSettings.vibration_enabled
	_refresh_vibration_text()
	_vibration_toggle.toggled.connect(_on_vibration_toggled)
	_shake_toggle.button_pressed = LocalSettings.screen_shake_enabled()
	_shake_toggle.toggled.connect(_on_shake_toggled)
	_refresh_vibration_text()

	MenuUI.style_button(_google_button, "white")
	MenuUI.style_button(_recover_button, "dark")
	MenuUI.style_button(_unlink_button, "ghost")
	MenuUI.style_button(_cancel_wait_button, "dark")
	MenuUI.style_button(_returned_button, "gold")
	MenuUI.style_button(_message_button, "white")
	MenuUI.style_button(_telegram_button, "white")
	MenuUI.style_button(_reset_button, "red")

	_google_button.pressed.connect(_on_google_pressed)
	_recover_button.pressed.connect(_on_recover_pressed)
	_unlink_button.pressed.connect(_on_unlink_pressed)
	_cancel_wait_button.pressed.connect(_on_cancel_wait_pressed)
	_returned_button.pressed.connect(_on_returned_pressed)
	_message_button.pressed.connect(_on_message_pressed)
	_telegram_button.pressed.connect(_on_telegram_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)

	# بازی فقط موبایل است: به‌جای hover، بازخورد «فشرده شدن» با انگشت
	for button in [_google_button, _recover_button, _unlink_button, _cancel_wait_button,
			_returned_button, _message_button, _telegram_button, _reset_button]:
		UIFx.bind_press_feedback(button)

	_status_http.request_completed.connect(_on_status_received)
	_action_http.request_completed.connect(_on_action_completed)
	_flow.state_changed.connect(_on_flow_state_changed)
	_flow.finished.connect(_on_flow_finished)

	Global.player_data_updated.connect(_refresh_id_label)
	Global.auth_required.connect(_on_auth_required)
	Global.account_switched.connect(refresh_status)

	# هر بار که تب دوباره نشان داده می‌شود: همگام‌سازی + انیمیشن ورود
	visibility_changed.connect(_on_visibility_changed)

	_toast.visible = false
	_refresh_id_label()
	_apply_account_view()
	if is_visible_in_tree():
		refresh_status()
		_play_intro()

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_refresh_from_settings()
		refresh_status()
		_play_intro()

## اگر جای دیگری (مثلاً منوی داخل بازی) مقدارها را عوض کرده، همگام شو
func _refresh_from_settings() -> void:
	_master_row.set_value_silent(LocalSettings.master_volume)
	_sfx_row.set_value_silent(LocalSettings.sfx_volume)
	_ambient_row.set_value_silent(LocalSettings.ambient_volume)
	_music_row.set_value_silent(LocalSettings.music_volume)
	_brightness_row.set_value_silent(LocalSettings.brightness)
	_vibration_toggle.set_pressed_no_signal(LocalSettings.vibration_enabled)
	_shake_toggle.set_pressed_no_signal(LocalSettings.screen_shake_enabled())
	_refresh_vibration_text()
	_refresh_quality_buttons()

# --------------------------------------------------------------- صدا و تصویر

## حین کشیدن اسلایدر: فوری اعمال کن ولی روی فایل ننویس
func _on_value_previewed(key: String, value: int) -> void:
	match key:
		"master": LocalSettings.master_volume = value
		"sfx": LocalSettings.sfx_volume = value
		"ambient": LocalSettings.ambient_volume = value
		"music": LocalSettings.music_volume = value
		"brightness":
			LocalSettings.brightness = value
			LocalSettings.apply_video()
			return
		_:
			return
	LocalSettings.apply_audio()

## بعد از رها کردن اسلایدر: ذخیره روی user://settings.cfg
func _on_value_committed(key: String, value: int) -> void:
	if key == "brightness":
		LocalSettings.set_video(key, value)
	else:
		LocalSettings.set_audio(key, value)

## سه دکمه‌ی کیفیت به‌جای اسلایدر — اسلایدر ۰ تا ۱۰۰ برای کیفیت معنی نداشت
func _build_quality_choices() -> void:
	for child in _quality_choices.get_children():
		child.queue_free()
	_quality_buttons.clear()
	for level in QUALITY_TITLES.size():
		var b := MenuUI.button(QUALITY_TITLES[level], "dark", 16)
		b.custom_minimum_size = Vector2(0, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_quality_pressed.bind(level))
		_quality_choices.add_child(b)
		_quality_buttons.append(b)
	_refresh_quality_buttons()

func _refresh_quality_buttons() -> void:
	var current := LocalSettings.quality_level()
	for i in _quality_buttons.size():
		MenuUI.style_button(_quality_buttons[i], "gold" if i == current else "dark")

func _on_quality_pressed(level: int) -> void:
	if level == LocalSettings.quality_level():
		return
	LocalSettings.set_quality_level(level)
	UIFx.tap(_quality_buttons[level])
	_refresh_quality_buttons()
	var notes := ["کم‌مصرف: ۳۰ فریم، مناسب باتری", "متوسط: ۶۰ فریم", "زیاد: ۶۰ فریم با لبه‌های نرم"]
	_show_toast("کیفیت → " + notes[level])

func _on_vibration_toggled(on: bool) -> void:
	LocalSettings.set_vibration(on)
	_refresh_vibration_text()
	# E11 یک لرزش نمونه تا بازیکن بفهمد این گزینه دقیقاً چه چیزی را روشن کرد
	if on:
		LocalSettings.vibrate(40)
	_show_toast("لرزش گوشی هنگام تیر خوردن و انفجار " + ("روشن شد" if on else "خاموش شد"))

func _on_shake_toggled(on: bool) -> void:
	LocalSettings.set_screen_shake(on)
	_refresh_vibration_text()
	UIFx.tap(_shake_toggle)
	_show_toast("تکان تصویر هنگام شلیک و انفجار " + ("روشن شد" if on else "خاموش شد"))

func _refresh_vibration_text() -> void:
	_vibration_toggle.text = "روشن" if _vibration_toggle.button_pressed else "خاموش"
	_shake_toggle.text = "روشن" if _shake_toggle.button_pressed else "خاموش"

# ------------------------------------------------------------ بازنشانی تنظیمات

func _on_reset_pressed() -> void:
	UIFx.press(_reset_button)
	MenuUI.confirm(self, "بازنشانی تنظیمات", "صدا، تصویر، کیفیت، لرزش گوشی و لرزش صفحه به حالت اولیه برمی‌گردند.",
		"بازنشانی", func(ok: bool) -> void:
			if ok:
				_do_reset())

func _do_reset() -> void:
	_pulse_card(_video_panel)
	LocalSettings.reset_to_defaults()

	# اسلایدرها یکی‌یکی به مقدار پیش‌فرض برمی‌گردند
	var order := ["master", "sfx", "ambient", "music", "brightness"]
	for i in _rows.size():
		_rows[i].animate_to(int(DEFAULTS[order[i]]), 0.05 * i)
	_vibration_toggle.set_pressed_no_signal(LocalSettings.vibration_enabled)
	_shake_toggle.set_pressed_no_signal(LocalSettings.screen_shake_enabled())
	_refresh_vibration_text()
	_refresh_quality_buttons()
	_show_toast("تنظیمات به حالت اولیه برگشت")

# ------------------------------------------------------------ وضعیت اکانت

func _refresh_id_label() -> void:
	var pid := str(Global.player_id)
	_id_label.text = "ID : %s" % (pid if not pid.is_empty() else "—")

## گرفتن وضعیت اکانت از سرور (وصل بودن، ایمیل، تأیید دستگاه)
func refresh_status() -> void:
	if str(Global.my_username).is_empty():
		return
	if _status_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var url := "%s/auth/status?username=%s" % [Global.SERVER_BASE, str(Global.my_username).uri_encode()]
	if _status_http.request(url, Global.auth_headers()) != OK:
		_status_failed = true
		_apply_account_view()

func _on_status_received(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 401:
		Global.account_locked = true
		_status_failed = false
		_apply_account_view()
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_status_failed = true
		_apply_account_view()
		return
	_status_failed = false
	_status = MenuUI.parse_json(body)
	Global.google_linked = bool(_status.get("linked", false))
	Global.device_verified = bool(_status.get("device_verified", false))
	Global.account_locked = false
	_apply_account_view()

func _on_auth_required() -> void:
	_apply_account_view()

## کارت وضعیت و دکمه‌ها را بر اساس حالت اکانت می‌چیند
func _apply_account_view() -> void:
	var waiting := _flow.is_busy()
	var locked := Global.account_locked
	var linked := Global.google_linked and not locked
	var available := bool(_status.get("google_available", true))

	_waiting_panel.visible = waiting
	_unlink_button.visible = linked and not waiting

	if locked:
		_set_status("ورود لازم است", "این حساب به گوگل وصل است و این دستگاه آن را نمی‌شناسد. با همان حساب گوگل وارد شو.", false)
		_google_button.visible = false
		_recover_button.visible = not waiting
		_recover_button.text = "ورود با گوگل"
		MenuUI.style_button(_recover_button, "gold")
	elif linked:
		var email := str(_status.get("email", ""))
		_set_status("حساب محافظت‌شده",
			("وصل به %s — اگر گوشی عوض شد، با «ورود با گوگل» همه‌چیز برمی‌گردد." % email) if not email.is_empty()
				else "حسابت به گوگل وصل است و پیشرفتت محافظت می‌شود.", true)
		_google_button.visible = false
		_recover_button.visible = not waiting
		_recover_button.text = "ورود با حساب گوگل دیگر"
		MenuUI.style_button(_recover_button, "dark")
	else:
		var detail := "پیشرفتت فقط روی همین گوشی است. با اتصال به گوگل، اگر گوشی عوض شد یا بازی پاک شد، همه‌چیز برمی‌گردد."
		if _status_failed:
			detail = "وضعیت حساب از سرور نیامد — اینترنت را بررسی کن."
		elif not _status.is_empty() and not bool(_status.get("device_verified", true)):
			detail = "این دستگاه برای این حساب تأیید نشده؛ فقط دستگاه اصلی می‌تواند آن را به گوگل وصل کند."
		_set_status("حساب مهمان", detail, false)
		_google_button.visible = not waiting
		_google_button.text = "اتصال با گوگل"
		_google_button.disabled = _status_failed or not Global.device_verified
		_recover_button.visible = not waiting
		_recover_button.text = "حساب دیگری داری؟ ورود با گوگل"
		MenuUI.style_button(_recover_button, "dark")

	if not available and not waiting:
		_status_detail.text += "\nورود با گوگل هنوز روی سرور فعال نشده."
		_google_button.disabled = true
		_recover_button.disabled = true
	else:
		_recover_button.disabled = false

func _set_status(title: String, detail: String, safe: bool) -> void:
	var color := COLOR_SAFE if safe else COLOR_GUEST
	_status_title.text = title
	_status_title.add_theme_color_override("font_color", color)
	_status_detail.text = detail
	_shield_icon.texture = ICON_SHIELD_ON if safe else ICON_SHIELD_OFF
	_shield_icon.modulate = color
	var style := _status_card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if style != null:
		style.border_color = Color(color, 0.85)
		style.bg_color = Color(0.14, 0.11, 0.03, 0.9) if safe else Color(0.16, 0.05, 0.06, 0.9)
		_status_card.add_theme_stylebox_override("panel", style)

# ------------------------------------------------------------- دکمه‌های اکانت

## مهمان → همین حساب به گوگل وصل شود
func _on_google_pressed() -> void:
	UIFx.press(_google_button)
	if not Global.device_verified:
		_show_toast("این دستگاه برای این حساب تأیید نشده")
		return
	_flow.start("link")

## ورود با گوگل: پیدا کردن حسابِ وصل‌شده (گوشی تازه / حساب دیگر)
func _on_recover_pressed() -> void:
	UIFx.press(_recover_button)
	# حساب مهمانی که پیشرفت دارد با ورود به حساب دیگر از این دستگاه جدا
	# می‌شود؛ قبلش بپرس و راهِ درست (اتصال همین حساب) را پیشنهاد بده
	if not Global.google_linked and not Global.account_locked and Global.level > 1:
		var on_answer := func(ok: bool) -> void:
			if ok:
				_flow.start("login")
		MenuUI.confirm(self, "ورود با حساب دیگر",
			"حساب مهمان فعلی (%s، سطح %s) از این دستگاه جدا می‌شود و بدون اتصال به گوگل دیگر برنمی‌گردد.\nاگر می‌خواهی همین حساب را نگه داری، «اتصال با گوگل» را بزن." \
				% [Global.my_username, MenuUI.fa(Global.level)],
			"ادامه", on_answer, true)
		return
	_flow.start("login")

func _on_cancel_wait_pressed() -> void:
	_flow.cancel()
	_show_toast("ورود با گوگل لغو شد")

func _on_returned_pressed() -> void:
	UIFx.tap(_returned_button)
	_flow.poll_now()

func _on_flow_state_changed(state: String) -> void:
	match state:
		"starting":
			_wait_label.text = "در حال آماده کردن صفحه‌ی گوگل..."
		"waiting":
			_wait_label.text = "صفحه‌ی گوگل در مرورگر باز شد؛ بعد از انتخاب حساب به بازی برگرد."
	_apply_account_view()

func _on_flow_finished(result: Dictionary) -> void:
	_apply_account_view()
	if str(result.get("status", "")) != "done":
		_on_flow_error(result)
		return

	if str(result.get("intent", "")) == "link":
		Global.google_linked = true
		LocalSettings.vibrate(40)
		_show_toast("حسابت به گوگل وصل شد ✓ پیشرفتت حالا محافظت می‌شود")
		refresh_status()
		Global.refresh_player_data()
		return

	# ورود: این دستگاه روی حساب پیدا شده می‌نشیند
	var username := str(result.get("username", ""))
	var token := str(result.get("session_token", ""))
	if username.is_empty() or token.is_empty():
		_show_toast("پاسخ سرور ناقص بود؛ دوباره امتحان کن")
		return
	var same := username == str(Global.my_username)
	Global.switch_account(username, token)
	LocalSettings.vibrate(40)
	_show_toast("خوش برگشتی %s! حسابت بارگذاری شد" % username if not same else "این دستگاه دوباره تأیید شد ✓")
	refresh_status()

func _on_flow_error(result: Dictionary) -> void:
	var code := str(result.get("code", ""))
	match code:
		"no_account":
			# حساب گوگل تازه است: پیشنهاد اتصال همین حساب
			if not Global.google_linked and Global.device_verified and not Global.account_locked:
				MenuUI.confirm(self, "حسابی پیدا نشد",
					"این حساب گوگل به هیچ حسابی در بازی وصل نیست. حساب فعلی‌ات (%s) را به آن وصل کنیم؟" % Global.my_username,
					"اتصال همین حساب", func(ok: bool) -> void:
						if ok:
							_flow.start("link"))
				return
		"cancelled":
			_show_toast("ورود با گوگل لغو شد")
			return
	_show_toast(str(result.get("error", "ورود با گوگل انجام نشد")))

## جدا کردن از گوگل — حساب دوباره مهمان و بی‌محافظ می‌شود
func _on_unlink_pressed() -> void:
	UIFx.press(_unlink_button)
	var on_answer := func(ok: bool) -> void:
		if ok:
			_send_unlink()
	MenuUI.confirm(self, "جدا کردن از گوگل",
		"بعد از جدا کردن، حسابت دوباره مهمان می‌شود؛ اگر گوشی را گم کنی یا بازی پاک شود، پیشرفتت قابل بازیابی نیست.",
		"جدا کن", on_answer, true)

func _send_unlink() -> void:
	if _busy:
		return
	_busy = true
	var err := _action_http.request(Global.SERVER_BASE + "/auth/google/unlink", Global.json_headers(),
		HTTPClient.METHOD_POST, JSON.stringify({"username": Global.my_username}))
	if err != OK:
		_busy = false
		_show_toast("اتصال به سرور برقرار نشد")

func _on_action_completed(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		Global.google_linked = false
		_status.erase("email")
		_show_toast("حساب از گوگل جدا شد")
		_apply_account_view()
		refresh_status()
		return
	_show_toast(MenuUI.server_error(body, code if result == HTTPRequest.RESULT_SUCCESS else 0))

# ------------------------------------------------------------------ پشتیبانی

## «ارسال پیام» یک باکس باز می‌کند تا کاربر با کیبورد گوشی متنش را بنویسد.
## متن با نام کاربری‌اش در کالکشن support_messages دیتابیس ذخیره می‌شود.
func _on_message_pressed() -> void:
	UIFx.press(_message_button, func() -> void:
		_open_message_dialog()
	)

func _open_message_dialog() -> void:
	var dialog := MESSAGE_DIALOG.instantiate()
	dialog.add_to_group("modal")
	dialog.sent.connect(func(_text: String) -> void:
		_show_toast("پیامت ارسال شد — ممنون!")
	)
	dialog.failed.connect(func(reason: String) -> void:
		_show_toast(reason)
	)
	# روی بالاترین لایه تا کیبورد و دیم روی کل صفحه بیفتد
	get_tree().root.add_child(dialog)
	dialog.open()

func _on_telegram_pressed() -> void:
	UIFx.press(_telegram_button, func() -> void:
		OS.shell_open(SUPPORT_TELEGRAM)
	)
	_show_toast("تلگرام پشتیبانی باز شد")

# ------------------------------------------------------------------ پیام شناور

func _show_toast(message: String) -> void:
	_toast_label.text = message
	_toast.visible = true
	_toast.modulate.a = 0.0
	_toast.pivot_offset = _toast.size * 0.5
	_toast.scale = Vector2(0.9, 0.9)

	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.16)
	_toast_tween.tween_property(_toast, "scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.chain().tween_interval(2.4)
	_toast_tween.chain().tween_property(_toast, "modulate:a", 0.0, 0.28) \
		.set_trans(Tween.TRANS_SINE)
	_toast_tween.chain().tween_callback(func() -> void: _toast.visible = false)

# ----------------------------------------------------------------- انیمیشن‌ها

## ورود صفحه: کارت‌ها باز می‌شوند، بعد ردیف‌ها پلکانی
func _play_intro() -> void:
	var cards: Array[Control] = [_account_panel, _audio_panel, _video_panel]
	for i in cards.size():
		var card := cards[i]
		card.pivot_offset = card.size * 0.5
		card.modulate.a = 0.0
		card.scale = Vector2(0.97, 0.97)

		var t := create_tween()
		t.tween_interval(0.06 * i)
		t.set_parallel(true)
		t.tween_property(card, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_SINE)
		t.tween_property(card, "scale", Vector2.ONE, 0.42) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	for i in _rows.size():
		_rows[i].play_intro(0.10 + 0.05 * i)

## پالس نرم کارت — موقع بازنشانی.
## با scale نه position، چون کانتینر والد موقعیت را بازنشانی می‌کند.
func _pulse_card(card: Control) -> void:
	card.pivot_offset = card.size * 0.5

	var pop := create_tween()
	pop.tween_property(card, "scale", Vector2(0.985, 0.985), 0.09) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pop.tween_property(card, "scale", Vector2(1.008, 1.008), 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	pop.tween_property(card, "scale", Vector2.ONE, 0.24) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)

	var glow := create_tween()
	glow.tween_property(card, "modulate", UIFx.PRESS_GLOW, 0.09) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	glow.tween_property(card, "modulate", Color.WHITE, 0.36) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
