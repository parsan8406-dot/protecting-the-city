extends CanvasLayer
## منوی توقف و پایانِ «بازی سریع».
##
## یک صفحه است با دو چهره: با دکمه‌ی توقف باز می‌شود (ادامه/شروع دوباره/خروج)
## و وقتی بازیکن از بین می‌رود خودش باز می‌شود (بدون «ادامه»).
##
## کل درخت روی PROCESS_MODE_ALWAYS است تا وقتی get_tree().paused روشن شد
## خودِ منو زنده بماند — وگرنه دکمه‌هایش هم یخ می‌زدند.

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

var _panel: PanelContainer = null
var _title: Label = null
var _stats_box: VBoxContainer = null
var _buttons_box: VBoxContainer = null
var _settings_box: VBoxContainer = null
var _resume_btn: Button = null
var _is_game_over := false


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
	return b


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
	_show(stats)


## باز کردن به‌عنوان «باختی» — ادامه‌ای در کار نیست
func open_game_over(stats: Dictionary) -> void:
	_is_game_over = true
	_title.text = "از بین رفتی!"
	_title.add_theme_color_override("font_color", COL_DANGER)
	_resume_btn.hide()
	_show(stats)


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
