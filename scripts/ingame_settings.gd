extends CanvasLayer
## تنظیماتِ داخلِ مسابقه‌ی آنلاین (دکمه‌ی چرخ‌دنده‌ی بالا-راست).
##
## بازیِ آنلاین متوقف نمی‌شود — بقیه دارند بازی می‌کنند — پس این فقط یک
## پنجره‌ی کوچک روی بازی است: صدا، لرزش، ادامه، و خروج از مسابقه (با تأیید).
## مقدارها مستقیم در LocalSettings ذخیره می‌شوند، همان تنظیماتِ منوی اصلی.

signal closed
signal leave_confirmed

const FONT := preload("res://fonts/Lalezar-Regular.ttf")

const COL_SCRIM  := Color(0.02, 0.02, 0.03, 0.66)
const COL_PANEL  := Color(0.07, 0.065, 0.08, 0.98)
const COL_EDGE   := Color(0.83, 0.66, 0.24)
const COL_GOLD   := Color(0.96, 0.79, 0.32)
const COL_TEXT   := Color(0.96, 0.94, 0.90)
const COL_DIM    := Color(0.62, 0.60, 0.64)
const COL_DANGER := Color(0.86, 0.20, 0.22)

var _leave_btn: Button = null
var _leave_armed := false


func _ready() -> void:
	layer = 110
	_build()
	hide()


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = COL_SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	# لمسِ بیرونِ پنجره یعنی بستن
	scrim.gui_input.connect(func(e: InputEvent):
		if (e is InputEventScreenTouch and e.pressed) or \
				(e is InputEventMouseButton and e.pressed):
			close())
	add_child(scrim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(2)
	sb.border_color = COL_EDGE
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", sb)
	centre.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var title := _label("تنظیمات", 30, COL_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	for row in [["صدای اصلی", "master"], ["صدای افکت", "sfx"], ["موزیک", "music"]]:
		col.add_child(_slider(row[0], row[1]))

	# E11: دو لرزش جدا، کنارِ هم تا پنل روی 16:9 و 4:3 بلند نشود
	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 24)
	col.add_child(toggles)

	var vib := _toggle("لرزش گوشی", LocalSettings.vibration_enabled)
	vib.toggled.connect(func(on: bool):
		LocalSettings.vibration_enabled = on
		LocalSettings.save_settings())
	toggles.add_child(vib)

	var shake := _toggle("لرزش صفحه", LocalSettings.screen_shake_enabled())
	shake.toggled.connect(func(on: bool): LocalSettings.set_screen_shake(on))
	toggles.add_child(shake)

	var resume := _button("ادامه", COL_GOLD)
	resume.pressed.connect(close)
	col.add_child(resume)

	_leave_btn = _button("خروج از مسابقه", COL_DANGER)
	_leave_btn.pressed.connect(_on_leave)
	col.add_child(_leave_btn)


func _toggle(text: String, on: bool) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.custom_minimum_size = Vector2(0, 52)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIFx.bind_press_feedback(c)   # V9
	c.button_pressed = on
	c.add_theme_font_override("font", FONT)
	c.add_theme_font_size_override("font_size", 18)
	c.add_theme_color_override("font_color", COL_TEXT)
	return c


func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


func _button(text: String, colour: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_color_override("font_color", colour)
	b.add_theme_color_override("font_pressed_color", Color(0.1, 0.1, 0.1))
	b.add_theme_color_override("font_hover_color", colour)
	for state in ["normal", "hover", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.12, 0.115, 0.13)
		s.set_corner_radius_all(12)
		s.set_border_width_all(2)
		s.border_color = colour
		b.add_theme_stylebox_override(state, s)
	var sp := StyleBoxFlat.new()
	sp.bg_color = colour
	sp.set_corner_radius_all(12)
	b.add_theme_stylebox_override("pressed", sp)
	# زیرِ انگشت فوری جمع می‌شود، نه بعد از رها کردن  # V9 pressed state / C12
	UIFx.bind_press_feedback(b)
	return b


func _slider(label_text: String, key: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var l := _label(label_text, 17, COL_TEXT)
	box.add_child(l)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.custom_minimum_size = Vector2(0, 48)   # ناحیه‌ی لمسِ ۴۸dp  # C3
	match key:
		"master": slider.value = LocalSettings.master_volume
		"sfx": slider.value = LocalSettings.sfx_volume
		"music": slider.value = LocalSettings.music_volume
	slider.value_changed.connect(func(v: float):
		LocalSettings.set_audio(key, int(v))
		l.text = "%s  %s" % [label_text, MissionArt.fa_number(int(v))])
	l.text = "%s  %s" % [label_text, MissionArt.fa_number(int(slider.value))]
	box.add_child(slider)
	return box


## خروج دو مرحله دارد: اولی فقط می‌پرسد، دومی واقعاً می‌رود
func _on_leave() -> void:
	if not _leave_armed:
		_leave_armed = true
		_leave_btn.text = "مطمئنی؟ دوباره بزن"
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(_leave_btn):
				_leave_armed = false
				_leave_btn.text = "خروج از مسابقه")
		return
	leave_confirmed.emit()


func open() -> void:
	_leave_armed = false
	if _leave_btn != null:
		_leave_btn.text = "خروج از مسابقه"
	show()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()
