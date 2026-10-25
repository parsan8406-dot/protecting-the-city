extends CanvasLayer
## انتخاب سطح سختی، قبل از شروع «بازی سریع».
##
## روی منوی اصلی باز می‌شود و سطح انتخاب‌شده را در Global.quick_play_difficulty
## می‌گذارد. خودِ اعداد در bot.gd و quick_play.gd هستند، اینجا فقط انتخاب است.

signal chosen(level: int)
signal cancelled

const FONT := preload("res://fonts/Lalezar-Regular.ttf")

const COL_SCRIM := Color(0.02, 0.02, 0.03, 0.85)
const COL_PANEL := Color(0.07, 0.065, 0.08, 0.98)
const COL_EDGE  := Color(0.83, 0.66, 0.24)
const COL_GOLD  := Color(0.96, 0.79, 0.32)
const COL_DIM   := Color(0.62, 0.60, 0.64)

## نام، توضیح کوتاه، رنگ
## C2 هیک: آخرین سطحی که بازیکن زده (روی دستگاه) پیش‌فرض و «پیشنهادی» است
const PREFS_PATH := "user://psych_menu.cfg"

const LEVELS := [
	["آسان", "حریفِ کندتر، ضربه‌ی کم‌تر", Color(0.35, 0.84, 0.45)],
	["متوسط", "درگیریِ متعادل", Color(0.96, 0.79, 0.32)],
	["سخت", "سریع، دقیق و پرتعداد", Color(0.88, 0.20, 0.22)],
]


var _buttons: Array[Button] = []
var _done := false


func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


## سطحِ پیشنهادی: آخرین انتخابِ همین حساب؛ بارِ اول برای تازه‌کار «آسان»
static func recommended_level() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(PREFS_PATH) == OK:
		var v := int(cfg.get_value("difficulty", str(Global.my_username), -1))
		if v >= 0 and v < LEVELS.size():
			return v
	return 0 if Global.level < 5 else 1


static func _remember(level: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PREFS_PATH)
	cfg.set_value("difficulty", str(Global.my_username), level)
	cfg.save(PREFS_PATH)


func _has_saved_choice() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(PREFS_PATH) == OK and cfg.has_section_key("difficulty", str(Global.my_username))


func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = COL_SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(2)
	sb.border_color = COL_EDGE
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", sb)
	centre.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var title := _label("سطح بازی", 28, COL_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var rec := recommended_level()
	for i in LEVELS.size():
		col.add_child(_level_button(i, i == rec))

	var cancel := Button.new()
	cancel.text = "انصراف"
	cancel.focus_mode = Control.FOCUS_NONE
	# C3: حداقل ~۴۸dp و کمی فاصله از گزینه‌ها تا اشتباهی زده نشود
	cancel.custom_minimum_size = Vector2(0, 50)
	cancel.add_theme_font_override("font", FONT)
	cancel.add_theme_font_size_override("font_size", 18)
	cancel.add_theme_color_override("font_color", COL_DIM)
	cancel.add_theme_color_override("font_hover_color", COL_DIM)
	cancel.flat = true
	UIFx.bind_press_feedback(cancel)
	cancel.pressed.connect(func():
		if _done:
			return
		_done = true
		cancelled.emit()
		queue_free())
	col.add_child(cancel)


func _level_button(level: int, recommended: bool) -> Button:
	var name_text: String = LEVELS[level][0]
	var hint: String = LEVELS[level][1]
	var colour: Color = LEVELS[level][2]

	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 62)
	b.text = "%s — %s" % [name_text, hint]
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", colour)
	b.add_theme_color_override("font_hover_color", colour)
	b.add_theme_color_override("font_pressed_color", Color(0.1, 0.1, 0.1))
	for state in ["normal", "hover", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.12, 0.115, 0.13) if not recommended else colour.darkened(0.72)
		s.set_corner_radius_all(12)
		# V5: گزینه‌ی پیشنهادی قابِ ضخیم‌تر دارد، بقیه آرام‌ترند
		s.set_border_width_all(4 if recommended else 2)
		s.border_color = colour
		b.add_theme_stylebox_override(state, s)
	var sp := StyleBoxFlat.new()
	sp.bg_color = colour
	sp.set_corner_radius_all(12)
	b.add_theme_stylebox_override("pressed", sp)

	UIFx.bind_press_feedback(b)
	# C13: یک بار انتخاب — لمسِ دوم تا عوض شدنِ صحنه کاری نمی‌کند
	b.pressed.connect(func():
		if _done:
			return
		_done = true
		for other in _buttons:
			other.disabled = other != b
		_remember(level)
		Global.quick_play_difficulty = level
		chosen.emit(level))
	_buttons.append(b)
	if recommended:
		var tag := _label("آخرین انتخاب" if _has_saved_choice() else "پیشنهادی", 14, Color(0.08, 0.07, 0.06))
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cs := StyleBoxFlat.new()
		cs.bg_color = COL_GOLD
		cs.set_corner_radius_all(8)
		cs.content_margin_left = 8.0
		cs.content_margin_right = 8.0
		chip.add_theme_stylebox_override("panel", cs)
		chip.add_child(tag)
		chip.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		chip.grow_vertical = Control.GROW_DIRECTION_BOTH
		chip.offset_left = 10.0
		b.add_child(chip)
	return b


func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l
