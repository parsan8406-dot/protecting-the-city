extends CanvasLayer
## منوی توقف و پایانِ «بازی سریع».
##
## یک صفحه است با دو چهره: با دکمه‌ی توقف باز می‌شود (ادامه/شروع دوباره/خروج)
## و وقتی بازیکن از بین می‌رود خودش باز می‌شود (بدون «ادامه»).
##
## کل درخت روی PROCESS_MODE_ALWAYS است تا وقتی get_tree().paused روشن شد
## خودِ منو زنده بماند — وگرنه دکمه‌هایش هم یخ می‌زدند.
##
## صفحه‌ی پایان (E4 اوج-پایان): حتی در باخت یک نقطه‌ی مثبت برجسته می‌شود —
## رکوردِ جدید یا بهترین لحظه‌ی همین دست — و اگر نزدیکِ رکورد بودی (E5)
## گفته می‌شود؛ یک نکته‌ی کاربردی از روی همین مرگ (C10)؛ و «شروع دوباره»
## تنها دکمه‌ی اصلیِ طلایی و درشت است (V5، E13 شروعِ مجددِ سریع).

signal resume_pressed
signal restart_pressed
signal quit_pressed

const FONT := preload("res://fonts/Lalezar-Regular.ttf")

const COL_SCRIM  := Color(0.02, 0.02, 0.03, 0.82)
const COL_PANEL  := Color(0.07, 0.065, 0.08, 0.98)
const COL_EDGE   := Color(0.83, 0.66, 0.24)
const COL_GOLD   := Color(0.96, 0.79, 0.32)
const COL_TEXT   := Color(0.96, 0.94, 0.90)
const COL_DIM    := Color(0.62, 0.60, 0.64)
const COL_DANGER := Color(0.86, 0.20, 0.22)
const TEXT_FONT_PATH := "res://fonts/SJADIDBD.TTF"
const PSYCH_ICON := "res://assets/ui/psych/%s.png"
const HUD_ICON := "res://assets/ui/hud/%s.png"
const MULTI_NAMES := {2: "دوتایی", 3: "سه‌تایی"}

var _panel: PanelContainer = null
var _title: Label = null
var _stats_box: VBoxContainer = null
var _buttons_box: VBoxContainer = null
var _settings_box: VBoxContainer = null
var _resume_btn: Button = null
var _restart_btn: Button = null
var _is_game_over := false
## E4/E5/C10 بخشِ مخصوصِ صفحه‌ی پایان
var _run_box: VBoxContainer = null
var _text_font: Font = null


func _ready() -> void:
	layer = 128
	# بدون این، خودِ منو هم با بازی متوقف می‌شود و دکمه‌ای کار نمی‌کند
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide()


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = COL_SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP   # کلیک به بازیِ پشتش نرود
	add_child(scrim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(340, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(2)
	sb.border_color = COL_EDGE
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 18.0
	_panel.add_theme_stylebox_override("panel", sb)
	centre.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)

	_title = _make_label("توقف", 30, COL_GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)

	if ResourceLoader.exists(TEXT_FONT_PATH):
		_text_font = load(TEXT_FONT_PATH)
	_run_box = VBoxContainer.new()
	_run_box.add_theme_constant_override("separation", 6)
	_run_box.hide()
	col.add_child(_run_box)

	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 5)
	col.add_child(_stats_box)

	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override("separation", 8)
	_settings_box.hide()
	col.add_child(_settings_box)
	_build_settings()

	_buttons_box = VBoxContainer.new()
	_buttons_box.add_theme_constant_override("separation", 9)
	col.add_child(_buttons_box)

	_resume_btn = _make_button("ادامه", COL_GOLD)
	_resume_btn.pressed.connect(func(): resume_pressed.emit())
	_buttons_box.add_child(_resume_btn)

	var restart := _make_button("شروع دوباره", COL_GOLD)
	restart.pressed.connect(func(): restart_pressed.emit())
	_buttons_box.add_child(restart)
	_restart_btn = restart

	var settings := _make_button("تنظیمات", COL_DIM)
	settings.pressed.connect(_toggle_settings)
	_buttons_box.add_child(settings)

	var quit := _make_button("خروج به منو", COL_DANGER)
	quit.pressed.connect(func(): quit_pressed.emit())
	_buttons_box.add_child(quit)


func _make_label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


func _make_button(text: String, colour: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", colour)
	b.add_theme_color_override("font_hover_color", colour)
	b.add_theme_color_override("font_pressed_color", Color(0.1, 0.1, 0.1))
	for state in ["normal", "hover", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.12, 0.115, 0.13)
		s.set_corner_radius_all(11)
		s.set_border_width_all(2)
		s.border_color = colour
		b.add_theme_stylebox_override(state, s)
	var sp := StyleBoxFlat.new()
	sp.bg_color = colour
	sp.set_corner_radius_all(11)
	b.add_theme_stylebox_override("pressed", sp)
	# V9 حالتِ فشرده‌ی واضح: کوچک شدنِ کوتاه زیرِ انگشت
	UIFx.bind_press_feedback(b)
	return b


## V5 تنها دکمه‌ی اصلی: طلاییِ پُر، متنِ تیره و درشت‌تر. on=false برمی‌گرداند.
func _set_primary(b: Button, on: bool) -> void:
	if b == null:
		return
	b.custom_minimum_size = Vector2(0, 58 if on else 46)
	b.add_theme_font_size_override("font_size", 24 if on else 20)
	var dark := Color(0.08, 0.06, 0.04)
	b.add_theme_color_override("font_color", dark if on else COL_GOLD)
	b.add_theme_color_override("font_hover_color", dark if on else COL_GOLD)
	b.add_theme_color_override("font_focus_color", dark if on else COL_GOLD)
	for state in ["normal", "hover", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = COL_GOLD if on else Color(0.12, 0.115, 0.13)
		s.set_corner_radius_all(11)
		s.set_border_width_all(2)
		s.border_color = COL_GOLD
		b.add_theme_stylebox_override(state, s)


## چند تنظیمِ پرکاربرد، همان‌جا بدون خروج از بازی. مقدارها مستقیم در
## LocalSettings ذخیره می‌شوند، پس با تنظیماتِ منوی اصلی یکی است.
func _build_settings() -> void:
	for row in [["صدای اصلی", "master"], ["صدای افکت", "sfx"], ["موزیک", "music"]]:
		_settings_box.add_child(_make_slider(row[0], row[1]))

	var vib := CheckBox.new()
	vib.text = "لرزش"
	vib.button_pressed = LocalSettings.vibration_enabled
	vib.add_theme_font_override("font", FONT)
	vib.add_theme_font_size_override("font_size", 17)
	vib.add_theme_color_override("font_color", COL_TEXT)
	vib.toggled.connect(func(on: bool):
		LocalSettings.vibration_enabled = on
		LocalSettings.save_settings())
	_settings_box.add_child(vib)


func _make_slider(label_text: String, key: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var l := _make_label(label_text, 16, COL_TEXT)
	box.add_child(l)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.custom_minimum_size = Vector2(0, 20)
	match key:
		"master": slider.value = LocalSettings.master_volume
		"sfx": slider.value = LocalSettings.sfx_volume
		"music": slider.value = LocalSettings.music_volume
	slider.value_changed.connect(func(v: float):
		LocalSettings.set_audio(key, int(v))
		l.text = "%s  %d" % [label_text, int(v)])
	l.text = "%s  %d" % [label_text, int(slider.value)]
	box.add_child(slider)
	return box


func _toggle_settings() -> void:
	_settings_box.visible = not _settings_box.visible
	_stats_box.visible = not _settings_box.visible


## باز کردن به‌عنوان «توقف» — دکمه‌ی ادامه هست
func open_paused(stats: Dictionary) -> void:
	_is_game_over = false
	_title.text = "توقف"
	_title.add_theme_color_override("font_color", COL_GOLD)
	_resume_btn.show()
	_set_primary(_restart_btn, false)
	_run_box.hide()
	_show(stats)


## باز کردن به‌عنوان «باختی» — ادامه‌ای در کار نیست.
## run از psych_play_director.finish_run (+ tip و best_multi از حسِ نبرد).
func open_game_over(stats: Dictionary, run: Dictionary = {}) -> void:
	_is_game_over = true
	_title.text = "از بین رفتی!"
	_title.add_theme_color_override("font_color", COL_DANGER)
	_resume_btn.hide()
	_set_primary(_restart_btn, true)
	_fill_run(run)
	_show(stats)


## E4 نقطه‌ی مثبت + E5 نزدیک‌برد + C10 نکته
func _fill_run(run: Dictionary) -> void:
	for c in _run_box.get_children():
		c.queue_free()
	_run_box.visible = not run.is_empty()
	if run.is_empty():
		return
	var highlight := ""
	var icon := ""
	if bool(run.get("new_record", false)):
		highlight = "رکوردِ جدید! موج %s • %s کیل" % [_fa(int(run.get("wave", 1))), _fa(int(run.get("kills", 0)))]
		icon = "result_new_record"
	elif str(run.get("near", "")) != "":
		highlight = str(run["near"])
	elif int(run.get("best_multi", 0)) >= 2:
		var m := int(run["best_multi"])
		highlight = "بهترین لحظه‌ات: %s!" % str(MULTI_NAMES.get(m, "بی‌مهار"))
		icon = "streak_double" if m == 2 else ("streak_triple" if m == 3 else "streak_rampage")
	elif int(run.get("kills", 0)) > 0:
		highlight = "تا موجِ %s رسیدی" % _fa(int(run.get("wave", 1)))
	if highlight != "":
		_run_box.add_child(_row(highlight, icon, "", COL_GOLD, 21, 46.0))
	var tip = run.get("tip", [])
	if tip is Array and tip.size() >= 3 and str(tip[0]) != "":
		_run_box.add_child(_row(str(tip[0]), str(tip[1]), str(tip[2]), COL_TEXT, 16, 34.0))
	var line := ColorRect.new()
	line.color = Color(COL_EDGE, 0.35)
	line.custom_minimum_size = Vector2(0, 2)
	_run_box.add_child(line)


## یک ردیفِ راست‌چین: متن و آیکن (آرتِ روانشناسی، وگرنه آیکنِ HUD، وگرنه هیچ)
func _row(text: String, psych_icon: String, hud_icon: String, colour: Color, size: int, icon_px: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = text
	if _text_font != null:
		l.add_theme_font_override("font", _text_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.custom_minimum_size = Vector2(260, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var tex: Texture2D = null
	if psych_icon != "" and ResourceLoader.exists(PSYCH_ICON % psych_icon):
		tex = load(PSYCH_ICON % psych_icon)
	elif hud_icon != "" and ResourceLoader.exists(HUD_ICON % hud_icon):
		tex = load(HUD_ICON % hud_icon)
	if tex != null:
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.custom_minimum_size = Vector2(icon_px, icon_px)
		row.add_child(t)
	return row


static func _fa(n: int) -> String:
	var digits := "۰۱۲۳۴۵۶۷۸۹"
	var out := ""
	for ch in str(n):
		out += digits[int(ch)] if ch >= "0" and ch <= "9" else ch
	return out


func _show(stats: Dictionary) -> void:
	_settings_box.hide()
	_stats_box.show()
	for c in _stats_box.get_children():
		c.queue_free()
	for key in stats.keys():
		# راست‌به‌چپ: عدد سمت چپ، عنوان سمت راست
		var row := HBoxContainer.new()
		var val_l := _make_label(str(stats[key]), 19, COL_GOLD)
		var name_l := _make_label(str(key), 17, COL_DIM)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_l)
		row.add_child(name_l)
		_stats_box.add_child(row)
	show()


func close() -> void:
	hide()
