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
## E8/C8: رکوردِ شخصیِ هر سطح (psych_play_director.gd ثبتش می‌کند؛ این‌جا فقط خوانده می‌شود)
const PLAY_SAVE := "user://psych_play.cfg"
## C3: کارتِ هر سطح بلندتر از ۴۸dp
const CARD_H := 66.0


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
	# C4: لمسِ بیرونِ پنجره یعنی بستن — مثلِ بقیه‌ی پنجره‌های بازی (ModalSheet)
	scrim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventScreenTouch and not e.pressed:
			_cancel())
	add_child(scrim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	# V3: همان قابِ پنجره‌های MenuUI (گوشه‌ی ۱۰، حاشیه‌ی طلاییِ تیره، سایه)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	var sb := MenuUI.box(Color(0.07, 0.07, 0.08, 0.99), MenuUI.GOLD_DEEP, 1, 10)
	sb.border_width_top = 3
	sb.set_content_margin_all(20)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 18
	panel.add_theme_stylebox_override("panel", sb)
	centre.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var title := _label("بازی سریع — سطح را انتخاب کن", 26, COL_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	# C10 شفافیت: بازیکن بداند این دست چه چیزی را عوض می‌کند و چه چیزی را نه
	var note := MenuUI.label("تمرینِ آفلاین با ربات‌ها، موج به موج — کاپ و رتبه تغییر نمی‌کند",
		15, MenuUI.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(note)

	var rec := recommended_level()
	for i in LEVELS.size():
		col.add_child(_level_button(i, i == rec))

	# C13: کمی فاصله از گزینه‌ها تا اشتباهی زده نشود
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 2)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	var cancel := MenuUI.button("انصراف", "ghost", 18)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel.custom_minimum_size = Vector2(180, MenuUI.TOUCH_H)
	cancel.pressed.connect(_cancel)
	col.add_child(cancel)

	# V7: ورودِ کوتاه — دیم محو، پنل با کمی بزرگ‌شدن (ورودی قفل نمی‌شود)
	scrim.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.94, 0.94)
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size * 0.5)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(scrim, "modulate:a", 1.0, 0.16)
	tw.tween_property(panel, "modulate:a", 1.0, 0.16)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _cancel() -> void:
	if _done:
		return
	_done = true
	cancelled.emit()
	queue_free()


## رکوردِ همین سطح، یا خالی اگر هنوز دستی بازی نشده
static func _record_text(level: int) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(PLAY_SAVE) != OK:
		return ""
	var sec := str(Global.my_username).strip_edges()
	if sec == "":
		sec = "_guest"
	var wave := int(cfg.get_value(sec, "d%d_best_wave" % level, 0))
	var kills := int(cfg.get_value(sec, "d%d_best_kills" % level, 0))
	# دستِ بی‌کیل در موجِ اول «رکورد» نیست — چیزی برای افتخار ندارد (E14)
	if wave <= 1 and kills <= 0:
		return ""
	return "رکوردت: موج %s · %s کیل" % [MenuUI.fa(maxi(wave, 1)), MenuUI.fa(kills)]


## کارتِ هر سطح: اسمِ درشت، توضیح و رکوردِ شخصی، و ۱ تا ۳ نشانه‌ی شدت
## (رنگ همیشه با شکل، V2). متن روی خودِ Button نیست تا دو خط داشته باشد.
func _level_button(level: int, recommended: bool) -> Button:
	var name_text: String = LEVELS[level][0]
	var hint: String = LEVELS[level][1]
	var colour: Color = LEVELS[level][2]

	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, CARD_H)
	# V5: گزینه‌ی پیشنهادی قابِ ضخیم‌تر و زمینه‌ی رنگی دارد، بقیه آرام‌ترند
	var normal := MenuUI.box(colour.darkened(0.8) if recommended else Color(0.11, 0.105, 0.12),
		Color(colour, 0.95 if recommended else 0.45), 3 if recommended else 1, 10)
	var pressed := MenuUI.box(colour.darkened(0.55), colour, 3, 10)
	for state in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(state, normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled",
		MenuUI.box(Color(0.08, 0.08, 0.09, 0.9), Color(0.25, 0.25, 0.28, 0.6), 1, 10))

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12.0
	row.offset_right = -12.0
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)

	# چپ: برچسبِ «پیشنهادی» (یا جای خالیِ هم‌اندازه تا متن‌ها هم‌تراز بمانند)
	var left := Control.new()
	left.custom_minimum_size = Vector2(92, 0)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)
	if recommended:
		var tag := _label("آخرین انتخاب" if _has_saved_choice() else "پیشنهادی", 14, Color(0.08, 0.07, 0.06))
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cs := MenuUI.box(COL_GOLD, COL_GOLD, 0, 8)
		cs.content_margin_left = 8.0
		cs.content_margin_right = 8.0
		chip.add_theme_stylebox_override("panel", cs)
		chip.add_child(tag)
		chip.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		chip.grow_vertical = Control.GROW_DIRECTION_BOTH
		left.add_child(chip)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", -2)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(texts)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(top)
	var record := _record_text(level)
	if record != "":
		top.add_child(MenuUI.label(record, 14, Color(COL_GOLD, 0.9), true))
	top.add_child(_label(name_text, 23, colour))
	var hint_l := MenuUI.label(hint, 15, MenuUI.MUTED)
	hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	texts.add_child(hint_l)

	# V2: شدت با شکل هم دیده می‌شود، نه فقط با رنگ — ۱ تا ۳ خانه‌ی روشن
	var pips := Control.new()
	pips.custom_minimum_size = Vector2(16, 0)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.draw.connect(func() -> void:
		var h := pips.size.y
		for i in 3:
			var y := h * 0.5 + (1.0 - float(i)) * 14.0
			pips.draw_rect(Rect2(2, y - 4, 12, 8),
				Color(colour, 0.95) if i <= level else Color(1, 1, 1, 0.12)))
	row.add_child(pips)

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
	return b


func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l
