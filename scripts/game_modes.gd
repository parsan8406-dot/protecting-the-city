extends Control
## صفحه‌ی «انتخاب مود بازی» (آنلاین).
##
## چیدمان: نوارِ بالا (بازگشت، عنوان، راهنما | سکه، جم، پیام، دوستان، تنظیمات)،
## ردیفِ کارت‌های عمودیِ مودها کنارِ هم، و نوارِ اطلاعاتِ پایین.
##
## کارت‌ها از سرور می‌آیند (`/game_modes`) و نه از کد — پاداش، جریمه و قفلِ
## هر مود در دیتابیس است. کلاینت فقط نمایش می‌دهد؛ انتخابِ نهایی را هم سرور
## تایید می‌کند (کاپِ کافی را چک می‌کند). رنگ و تصویرِ هر مود از ModeArt است.

const FONT := preload("res://fonts/Lalezar-Regular.ttf")
const TOP_BAR := preload("res://secense/top_bar.tscn")
const MAIN_MENU := "res://secense/main_menu.tscn"

# --- پالت: سرمه‌ایِ تیره مثلِ نوارِ بالا؛ رنگِ هر کارت از مودِ خودش ---
const COL_LINE   := Color(0.11, 0.176, 0.259)
const COL_TEXT   := Color(0.95, 0.96, 0.98)
const COL_DIM    := Color(0.62, 0.67, 0.75)
const COL_GOLD   := Color(0.96, 0.79, 0.32)
const COL_WIN    := Color(0.38, 0.86, 0.48)
const COL_LOSE   := Color(0.90, 0.27, 0.27)

var _http: HTTPRequest = null
var _list: HBoxContainer = null
var _scroll: ScrollContainer = null
var _status: Label = null
var _top_bar: Control = null
var _content: MarginContainer = null
var _help: Control = null           # پنجره‌ی راهنما، وقتی باز است
var _toast: PanelContainer = null
var _toast_tw: Tween = null

var _modes: Array = []
var _trophies := 0
var _selected := ""
var _pending_mode := ""             # مودی که منتظر تاییدِ سرور است
var _back_frame := -1               # جلوی دوبار اجرا شدنِ «بازگشت» در یک فریم
## C2/C12: لمسِ کارت یعنی «همین را بازی می‌کنم» — بعد از تاییدِ سرور یک‌راست
## به لابی برمی‌گردیم که «شروع» آن‌جا منتظر است (قبلاً باید دستی برمی‌گشت)
var _return_after_select := false
const RETURN_DELAY := 0.35
const TOUCH := preload("res://scripts/psych_menu_touch.gd")


func _ready() -> void:
	# دکمه‌ی Back اینجا باید به منوی اصلی برگردد، نه اینکه اپ را ببندد
	get_tree().set_quit_on_go_back(false)
	_build()
	# رنک از بازدیدِ قبلی کش شده؛ پاسخِ /game_modes اگر عوض شده بود درستش می‌کند
	_apply_theme_background()
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_modes_received)
	_fetch()


# ============================ بک‌گراندِ تم ============================

## تمی که همین حالا پشتِ صفحه است، و رنکی که از رویش انتخاب شد
var _bg_theme := ""
var _bg_rank := ""


## بک‌گراندِ این صفحه تمِ رنکِ بازیکن را نشان می‌دهد (برنز جهنمی، نقره بهشتی،
## ... لجندری جادویی یا سرزمینِ مردگان).
##
## جلوه‌های مذاب (نورِ گدازه، سنگ‌های مذاب و لایه‌ی قرمز) مالِ تمِ جهنمی‌اند؛
## روی تم‌های دیگر فقط یک لایه‌ی تیره‌ی خنثی می‌ماند تا کارت‌ها روی
## بک‌گراندِ شلوغ خوانا بمانند. تا رنک معلوم نشده همان بک‌گراندِ صحنه می‌ماند.
func _apply_theme_background() -> void:
	if Global.rank_id == "" or Global.rank_id == _bg_rank:
		return   # لجندری دو تم دارد — نباید با هر پاسخِ سرور عوض شود
	_bg_rank = Global.rank_id
	_bg_theme = ThemeArt.theme_for_rank(Global.rank_id)

	var bg := get_node_or_null("BackgroundAction/RedBG") as TextureRect
	var tex := ThemeArt.background(_bg_theme)
	if bg != null and tex != null:
		bg.texture = tex
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	var hell := _bg_theme == "hell"
	for n in ["BackgroundAction/LavaLight", "BackgroundAction/MoltenRocks"]:
		var fx := get_node_or_null(n) as CanvasItem
		if fx != null:
			fx.visible = hell
	var tint := get_node_or_null("BackgroundAction/ColorRect") as ColorRect
	if tint != null:
		if not tint.has_meta("hell_color"):
			tint.set_meta("hell_color", tint.color)
		tint.color = tint.get_meta("hell_color") if hell else Color(0, 0, 0, 0.42)


# ============================ بازگشت (دکمه‌ی Back اندروید) ============================

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()
	elif what == NOTIFICATION_EXIT_TREE:
		get_tree().set_quit_on_go_back(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()


## اول پنجره‌ی باز بسته می‌شود، بعد به منوی اصلی برمی‌گردیم
func _on_back() -> void:
	var frame := Engine.get_process_frames()
	if frame == _back_frame:
		return
	_back_frame = frame
	if _help != null:
		_close_help()
		return
	_go_back()


func _go_back() -> void:
	if _leaving or not is_inside_tree():
		return
	_leaving = true
	get_tree().change_scene_to_file(MAIN_MENU)


var _leaving := false


# ============================ ناحیه‌ی امن (ناچ) ============================

## فاصله‌ی ناچ/لبه‌ی خمیده از چهار طرف، به واحدِ ویوپورت. روی دسکتاپ صفر —
## آنجا safe area یعنی «صفحه منهای تسک‌بار» و ربطی به پنجره ندارد.
func _safe_insets() -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var win_pos := DisplayServer.window_get_position()
	var win_size := DisplayServer.window_get_size()
	if safe.size.x <= 0 or win_size.x <= 0:
		return Vector4.ZERO
	var k := get_viewport_rect().size / Vector2(win_size)
	return Vector4(
		maxf(0.0, float(safe.position.x - win_pos.x)) * k.x,
		maxf(0.0, float(safe.position.y - win_pos.y)) * k.y,
		maxf(0.0, float(win_pos.x + win_size.x - safe.end.x)) * k.x,
		maxf(0.0, float(win_pos.y + win_size.y - safe.end.y)) * k.y)


func _apply_safe_area() -> void:
	var ins := _safe_insets()
	var hb := _top_bar.get_node_or_null("HBoxContainer") as Control
	if hb != null:
		hb.offset_left = 12.0 + ins.x
		hb.offset_right = -(12.0 + ins.z)
	var bar_h := _top_bar.offset_bottom - _top_bar.offset_top
	_content.add_theme_constant_override("margin_left", int(16.0 + ins.x))
	_content.add_theme_constant_override("margin_right", int(16.0 + ins.z))
	_content.add_theme_constant_override("margin_top", int(bar_h + 14.0 + ins.y))
	_content.add_theme_constant_override("margin_bottom", int(12.0 + ins.w))


# ============================ ساختِ صفحه ============================

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_top_bar = TOP_BAR.instantiate()
	add_child(_top_bar)
	_customize_top_bar()

	_content = MarginContainer.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(col)

	_status = _label("در حال گرفتن مودها…", 18, COL_DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_status)

	# کارت‌ها کنارِ هم. اگر صفحه باریک بود (یا مودها بیشتر شدند) با کشیدنِ
	# انگشت افقی جابه‌جا می‌شوند؛ اسکرول‌بار فقط جا می‌گیرد، پس مخفی است.
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	col.add_child(_scroll)

	_list = HBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	_scroll.add_child(_list)

	col.add_child(_info_bar())
	_build_toast()


## نوارِ بالای مشترکِ بازی (سکه، جم، پیام، دوستان، تنظیمات) را دوباره
## استفاده می‌کنیم، ولی جای پروفایل «بازگشت + عنوان + راهنما» می‌نشیند.
func _customize_top_bar() -> void:
	var hb := _top_bar.get_node_or_null("HBoxContainer") as HBoxContainer
	if hb == null:
		return
	var profile := hb.get_node_or_null("Profile") as Control
	if profile != null:
		profile.hide()

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var back := _icon_button(_draw_back_arrow)
	back.pressed.connect(_go_back)
	head.add_child(back)

	var title := _label("انتخاب مود بازی", 24, COL_TEXT)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)

	var help := _icon_button(_draw_help_mark, true)
	help.pressed.connect(_open_help)
	head.add_child(help)

	hb.add_child(head)
	hb.move_child(head, 0)


## دکمه‌ی آیکونیِ سربرگ. آیکون دستی کشیده می‌شود چون فونت گلیفِ فلش ندارد.
## hover همان normal است — بازی موبایلی است و هاور ندارد.
func _icon_button(painter: Callable, round := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(42, 42)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "focus", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.36, 0.52, 0.75, 0.30) if state == "pressed" \
			else Color(0.03, 0.06, 0.1, 0.85)
		s.set_corner_radius_all(21 if round else 9)
		s.set_border_width_all(2 if round else 1)
		s.border_color = Color(0.45, 0.55, 0.68, 0.9) if round else COL_LINE.lightened(0.25)
		b.add_theme_stylebox_override(state, s)
	b.draw.connect(func() -> void: painter.call(b))
	UIFx.bind_press_feedback(b)
	# C3: آرت ۴۲ پیکسل است ولی ناحیه‌ی لمس ~۴۸dp
	TOUCH.expand(b, _top_bar)
	return b


func _draw_back_arrow(b: Control) -> void:
	var c := b.size * 0.5
	var col := COL_TEXT
	b.draw_line(Vector2(c.x - 10, c.y), Vector2(c.x + 11, c.y), col, 3.0, true)
	b.draw_polyline(PackedVector2Array([
		Vector2(c.x - 1, c.y - 9), Vector2(c.x - 10, c.y), Vector2(c.x - 1, c.y + 9),
	]), col, 3.0, true)


func _draw_help_mark(b: Control) -> void:
	var fs := 24
	var w := FONT.get_string_size("؟", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	b.draw_string(FONT, Vector2((b.size.x - w) * 0.5, b.size.y * 0.5 + fs * 0.36), "؟",
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.75, 0.8, 0.88))


## نوارِ پایین: نشانِ اطلاعات، دو خط راهنما و «Choose Your Battle!»
func _info_bar() -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.022, 0.04, 0.07, 0.88)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(1)
	sb.border_color = COL_LINE
	sb.content_margin_left = 14.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(row)

	var info := Control.new()
	info.custom_minimum_size = Vector2(34, 34)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.draw.connect(func() -> void:
		var c := info.size * 0.5
		var col := Color(0.62, 0.68, 0.78)
		info.draw_arc(c, 15.0, 0.0, TAU, 32, col, 2.0, true)
		info.draw_circle(Vector2(c.x, c.y - 7.0), 2.2, col)
		info.draw_line(Vector2(c.x, c.y - 2.0), Vector2(c.x, c.y + 8.0), col, 3.0))
	row.add_child(info)

	var sep := ColorRect.new()
	sep.color = COL_LINE
	sep.custom_minimum_size = Vector2(1, 0)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(sep)

	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	lines.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# C4/C7: دقیقاً بگو لمس چه می‌کند — بعد از انتخاب به لابی برمی‌گردی
	lines.add_child(_label("مود را لمس کن؛ انتخاب می‌شود و به لابی برمی‌گردی.", 15, COL_DIM))
	lines.add_child(_label("جزئیاتِ برد، باخت و شرطِ ورودِ هر مود: دکمه‌ی «؟»", 15, COL_DIM))
	row.add_child(lines)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	row.add_child(_battle_tagline())
	return pc


## «Choose Your Battle!» کج و درخشان، با یک خطِ قلم‌مویی زیرش.
## Label کج نمی‌شود، پس با ترنسفورمِ skew دستی کشیده می‌شود.
func _battle_tagline() -> Control:
	const TEXT := "Choose Your Battle!"
	const FS := 26
	var c := Control.new()
	var tw := FONT.get_string_size(TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x
	c.custom_minimum_size = Vector2(tw + 24.0, 42)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var base := Vector2(14.0, c.size.y * 0.5 + FS * 0.30)
		var col := Color(0.62, 0.80, 1.0)
		c.draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-0.28, 1), base))
		for o in [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, -1.5), Vector2(0, 1.5)]:
			c.draw_string(FONT, o, TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FS,
				Color(0.2, 0.5, 1.0, 0.22))
		c.draw_string(FONT, Vector2.ZERO, TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, col)
		c.draw_set_transform_matrix(Transform2D.IDENTITY)
		# خطِ زیر: باریک در دو سر، پهن در وسط
		var y := c.size.y - 4.0
		var w := c.size.x - 10.0
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(w * 0.30, y), Vector2(w * 0.7, y - 2.2), Vector2(w, y - 5.0),
			Vector2(w * 0.7, y - 0.4),
		]), Color(col.r, col.g, col.b, 0.7)))
	return c


func _build_toast() -> void:
	_toast = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.09, 0.95)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = COL_LOSE
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	_toast.add_theme_stylebox_override("panel", sb)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.offset_bottom = -96.0
	_toast.modulate.a = 0.0
	_toast.add_child(_label("", 17, COL_TEXT))
	add_child(_toast)


## پیامِ کوتاهِ پایینِ صفحه (مثلاً «کاپ کافی نیست») که خودش محو می‌شود
func _show_toast(text: String) -> void:
	(_toast.get_child(0) as Label).text = text
	_toast.reset_size()
	if _toast_tw != null:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tw.tween_interval(2.2)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.35)


func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ============================ پنجره‌ی راهنما ============================

## همه‌ی جزئیاتِ اقتصادیِ مودها اینجاست (پاداش، جریمه، شرطِ ورود) تا
## کارت‌ها خلوت بمانند.
func _open_help() -> void:
	if _help != null:
		return
	_help = Control.new()
	_help.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_help)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventScreenTouch or e is InputEventMouseButton) and not e.pressed:
			_close_help())
	_help.add_child(dim)

	# اندازه نسبی است، نه پیکسلی — روی ۴:۳ و ۲۱:۹ هر دو جا می‌شود
	var panel := PanelContainer.new()
	panel.anchor_left = 0.14
	panel.anchor_right = 0.86
	panel.anchor_top = 0.1
	panel.anchor_bottom = 0.92
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.085, 0.99)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = COL_LINE.lightened(0.3)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", sb)
	_help.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)
	var close := Button.new()
	close.text = "بستن"
	close.custom_minimum_size = Vector2(110, MenuUI.TOUCH_H)
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_override("font", FONT)
	close.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "focus", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.36, 0.52, 0.75, 0.35) if state == "pressed" else Color(1, 1, 1, 0.05)
		s.set_corner_radius_all(9)
		s.set_border_width_all(1)
		s.border_color = COL_LINE.lightened(0.3)
		close.add_theme_stylebox_override(state, s)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		close.add_theme_color_override(c, COL_TEXT)
	UIFx.bind_press_feedback(close)
	close.pressed.connect(_close_help)
	head.add_child(close)
	var cups := _label("کاپ شما: %s" % _fa(_trophies), 18, COL_GOLD)
	cups.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(cups)
	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(pad)
	var title := _label("راهنمای مودها", 24, COL_TEXT)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)

	# ScrollContainer خودش کشیدنِ انگشت را می‌فهمد؛ ردیف‌ها ورودی را
	# نمی‌گیرند تا جلوی drag را نبندند.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	scroll.add_child(rows)
	for m in _modes:
		rows.add_child(_help_row(m))

	panel.pivot_offset = panel.size * 0.5
	panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)


func _close_help() -> void:
	if _help == null:
		return
	_help.queue_free()
	_help = null


func _help_row(m: Dictionary) -> Control:
	var accent := ModeArt.accent(m)
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r, accent.g, accent.b, 0.07)
	sb.set_corner_radius_all(9)
	sb.set_border_width_all(1)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	pc.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(row)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)

	var name_l := _label("%s   (%s)" % [str(m.get("name", "")), str(m.get("subtitle", ""))],
		21, accent.lightened(0.25))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text.add_child(name_l)
	var desc := _label(str(m.get("description", "")), 15, COL_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text.add_child(desc)

	var econ := HBoxContainer.new()
	econ.alignment = BoxContainer.ALIGNMENT_END
	econ.add_theme_constant_override("separation", 18)
	econ.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gate := int(m.get("min_trophies", 0))
	if bool(m.get("coming_soon", false)):
		econ.add_child(_label("به زودی...", 16, COL_GOLD))
	elif gate > 0:
		econ.add_child(_label("شرط ورود: %s کاپ" % _fa(gate), 16,
			COL_GOLD if _trophies >= gate else COL_DIM))
	econ.add_child(_label("باخت: −%s کاپ" % _fa(int(m.get("lose_trophies", 0))), 16, COL_LOSE))
	econ.add_child(_label("برد: +%s کاپ  +%s سکه" % [
		_fa(int(m.get("win_trophies", 0))), _fa(int(m.get("win_coins", 0)))], 16, COL_WIN))
	text.add_child(econ)

	var icon := TextureRect.new()
	icon.texture = ModeArt.emblem(str(m.get("mode_id", "")))
	icon.custom_minimum_size = Vector2(72, 72)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	return pc


## عددِ فارسی با جداکننده‌ی هزارگان (۱۲۳۴۵ → ۱۲٬۳۴۵)
static func _fa(value: int) -> String:
	const DIGITS := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var out := ""
	var digits := str(absi(value))
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = DIGITS[int(digits[i])] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "٬" + out
	return ("−" if value < 0 else "") + out


# ============================ داده ============================

func _fetch() -> void:
	var url := "%s/game_modes?username=%s" % [
		Global.SERVER_BASE, Global.my_username.uri_encode()]
	var err := _http.request(url, Global.auth_headers())
	if err != OK:
		_status.text = "اتصال به سرور ممکن نشد"


func _on_modes_received(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	# همین سیگنال برای پاسخِ «انتخاب» هم می‌آید
	if _pending_mode != "":
		_on_select_answered(code, body)
		return

	if code != 200:
		_status.text = "مودهای بازی خوانده نشد — اینترنت را چک کن (کد %d)" % code
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		_status.text = "پاسخ سرور خوانده نشد"
		return

	_modes = data.get("modes", [])
	_trophies = int(data.get("trophies", 0))
	# آخرین حالتی که بازیکن زده بود می‌ماند؛ فقط اگر نبود یا «به زودی» شده
	# بود سراغِ اولین حالتِ قابل‌بازی می‌رویم. اسم و دیتای کامل هم باید
	# کش شود، وگرنه دکمه‌ی منوی اصلی روی «عملیات ضربت» می‌ماند.
	var saved := str(data.get("selected_mode", ""))
	if saved == "":
		saved = Global.selected_mode
	var picked := Global.pick_selected_mode(_modes, saved, _trophies)
	_selected = str(picked.get("mode_id", ""))
	if not picked.is_empty() and (_selected != Global.selected_mode
			or Global.selected_mode_data != picked):
		Global.apply_selected_mode(picked)
	Global.trophies = _trophies
	Global.rank_id = str(data.get("rank_id", Global.rank_id))
	_apply_theme_background()
	_status.hide()
	_rebuild_list(true)


func _rebuild_list(intro := false) -> void:
	for c in _list.get_children():
		c.queue_free()

	var idx := 0
	var recommended := _recommended_id()
	for m in _modes:
		var mode_id := str(m.get("mode_id", ""))
		var card := ModeCard.new()
		card.recommended = mode_id == recommended
		card.setup(m, _trophies, mode_id == _selected, FONT)
		card.chosen.connect(_on_card_chosen)
		card.blocked.connect(_on_blocked)
		_list.add_child(card)
		if intro:
			# ورودِ پلکانی: هر کارت کمی دیرتر از قبلی می‌آید
			card.play_intro(float(idx) * 0.07)
		idx += 1


## C2 هیک: فقط یک کارت برچسبِ «پیشنهادی» می‌گیرد. اگر سرور خودش مودی را
## recommended بفرستد همان؛ وگرنه اولین مودِ بازشده به ترتیبِ سرور (ضربت —
## کلاسیک و سریع‌ترین صف).
func _recommended_id() -> String:
	for m in _modes:
		if bool(m.get("recommended", false)) and not bool(m.get("coming_soon", false)) \
				and _trophies >= int(m.get("min_trophies", 0)):
			return str(m.get("mode_id", ""))
	return str(Global.pick_selected_mode(_modes, "", _trophies).get("mode_id", ""))


# ============================ انتخاب ============================

## لمسِ کارت: مودِ تازه را انتخاب کن و برگرد؛ مودِ فعلی را لمس کردن یعنی
## «همین خوب است» — فوراً برگرد.
func _on_card_chosen(mode_id: String) -> void:
	if _pending_mode != "":
		return
	if mode_id == _selected:
		_go_back()
		return
	_return_after_select = true
	_choose(mode_id)
	if _pending_mode == "":
		_return_after_select = false


func _choose(mode_id: String) -> void:
	if _pending_mode != "":
		return
	_pending_mode = mode_id
	var body := JSON.stringify({
		"username": Global.my_username, "mode_id": mode_id,
	})
	var err := _http.request(Global.SERVER_BASE + "/game_modes/select",
		Global.json_headers(), HTTPClient.METHOD_POST, body)
	if err != OK:
		_pending_mode = ""
		_show_toast("اتصال به سرور ممکن نشد")


func _on_blocked(mode_id: String) -> void:
	for m in _modes:
		if str(m.get("mode_id", "")) == mode_id:
			if bool(m.get("coming_soon", false)):
				_show_toast("این مود به زودی اضافه می‌شود")
				return
			_show_toast("برای این مود %s کاپ لازم است — الان %s کاپ داری" % [
				_fa(int(m.get("min_trophies", 0))), _fa(_trophies)])
			return


func _on_select_answered(code: int, body: PackedByteArray) -> void:
	var mode_id := _pending_mode
	_pending_mode = ""
	if code != 200:
		var msg := "انتخاب ذخیره نشد"
		var d = JSON.parse_string(body.get_string_from_utf8())
		if typeof(d) == TYPE_DICTIONARY and d.has("error"):
			msg = str(d["error"])
		_return_after_select = false
		_show_toast(msg)
		return

	_selected = mode_id
	# اسم و تیم‌بندی را هم نگه می‌داریم (و روی دستگاه ذخیره) تا منوی اصلی
	# بدون درخواستِ دوباره بتواند رویِ دکمه بنویسدشان
	for m in _modes:
		if str(m.get("mode_id", "")) == mode_id:
			Global.apply_selected_mode(m)
	for card in _list.get_children():
		card.set_active(card.mode_id == mode_id)
	if _return_after_select:
		_return_after_select = false
		# فرصتِ دیدنِ تیک و درخششِ کارتِ تازه، بعد لابی
		get_tree().create_timer(RETURN_DELAY).timeout.connect(func() -> void:
			if is_inside_tree() and _help == null:
				_go_back())


# ============================================================================
# کارتِ یک مود
# ============================================================================
## کارتِ عمودی: تصویرِ مود بالا، نشانِ مود روی مرزِ تصویر، اسم، جمله‌ی
## کوتاه و قابِ تیم‌بندی («4 vs 4») پایین. کارتِ انتخابی قابِ درخشان و
## تیکِ گوشه دارد.
##
## لمسِ کلِ کارت یعنی انتخاب — روی موبایل هدفِ لمسِ بزرگ بهتر است. کشیدنِ
## انگشت روی کارت به ScrollContainer پاس داده می‌شود تا ردیف زیرِ دست قفل نشود.
class ModeCard extends Control:

	signal chosen(mode_id: String)
	signal blocked(mode_id: String)   # لمسِ مودِ قفل

	const MIN_W := 226.0
	const DRAG_THRESHOLD := 12.0
	const ART_BOTTOM := 0.62          # تصویر تا کجای ارتفاعِ کارت می‌آید

	const COL_BASE   := Color(0.018, 0.026, 0.045)
	const COL_TEXT   := Color(0.97, 0.97, 0.99)
	const COL_DIM    := Color(0.70, 0.73, 0.80)
	const COL_LOCKED := Color(0.42, 0.42, 0.46)

	var accent := Color.WHITE
	var mode_id := ""
	var locked := false
	var coming_soon := false          # هنوز ساخته نشده — قفل، با برچسبِ «به زودی...»
	var is_active := false
	var recommended := false          # C2: برچسبِ «پیشنهادی» — فقط یک کارت

	var _font: Font = null
	var _mode: Dictionary = {}
	var _trophies := 0
	var _min_trophies := 0

	var _panel_sb: StyleBoxFlat = null
	var _glow: Control = null         # هاله‌ی بیرونِ قابِ کارتِ انتخابی
	var _fx: Control = null           # تیکِ گوشه و قفل، رویِ همه‌چیز
	var _emblem_slot: Control = null
	var _emblem_rect: TextureRect = null

	var _t := 0.0
	var _src := -1                    # منبعِ لمسِ جاری: ۰ تاچ، ۱ ماوس، -۱ هیچ
	var _touch_start := Vector2.ZERO
	var _is_swiping := false
	var _scroll: ScrollContainer = null


	func setup(m: Dictionary, trophies: int, selected: bool, font: Font) -> void:
		_mode = m
		mode_id = str(m.get("mode_id", ""))
		accent = ModeArt.accent(m)
		_font = font
		_trophies = trophies
		_min_trophies = int(m.get("min_trophies", 0))
		coming_soon = bool(m.get("coming_soon", false))
		locked = coming_soon or trophies < _min_trophies
		is_active = selected and not locked
		_build()
		_apply_state()


	func _ready() -> void:
		gui_input.connect(_on_gui_input)
		_scroll = _find_parent_scroll()
		# Godot پردازش را موقعِ ready خودش روشن می‌کند؛ کارت‌های غیرفعال خاموش
		set_process(is_active and not locked)


	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			# مبدأ مقیاس وسطِ کارت، وگرنه انیمیشن‌ها از گوشه باز و بسته می‌شوند
			pivot_offset = size * 0.5
			if _emblem_slot != null:
				var h := clampf(size.x * 0.44, 80.0, 150.0)
				_emblem_slot.custom_minimum_size = Vector2(0, h)


	## فقط کارتِ انتخابی انیمیشن دارد؛ بقیه اصلاً پردازش نمی‌شوند (باتری)
	func _process(delta: float) -> void:
		_t += delta
		_glow.queue_redraw()
		if _emblem_rect != null:
			_emblem_rect.pivot_offset = _emblem_rect.size * 0.5
			var k := 1.0 + 0.025 * sin(_t * 2.2)
			_emblem_rect.scale = Vector2(k, k)


	func set_active(active: bool) -> void:
		if active == is_active:
			return
		is_active = active
		_apply_state()
		if active:
			UIFx.tap(self)


	# ---------------------------------------------------------- ساخت

	func _build() -> void:
		custom_minimum_size = Vector2(MIN_W, 0)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP

		var tint := _tint()
		var base := COL_BASE.lerp(tint, 0.13)

		_glow = _layer(_draw_glow)

		var panel := Panel.new()
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel_sb = StyleBoxFlat.new()
		_panel_sb.bg_color = base
		_panel_sb.set_corner_radius_all(10)
		_panel_sb.anti_aliasing = true
		panel.add_theme_stylebox_override("panel", _panel_sb)
		add_child(panel)

		# تصویرِ بالای کارت، بریده در قابِ خودش
		var art_clip := Control.new()
		art_clip.anchor_right = 1.0
		art_clip.anchor_bottom = ART_BOTTOM
		art_clip.offset_left = 3.0
		art_clip.offset_top = 3.0
		art_clip.offset_right = -3.0
		art_clip.clip_contents = true
		art_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(art_clip)

		var art_tex := ModeArt.card_art(mode_id)
		if art_tex != null:
			var art := TextureRect.new()
			art.texture = art_tex
			art.set_anchors_preset(Control.PRESET_FULL_RECT)
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art_clip.add_child(art)
		else:
			var fallback := Control.new()
			fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
			fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fallback.draw.connect(_draw_art_fallback.bind(fallback, tint, base))
			art_clip.add_child(fallback)

		# محو شدنِ پایینِ تصویر در رنگِ کارت — نشان روی همین مرز می‌نشیند
		var grad := Gradient.new()
		grad.set_color(0, Color(base.r, base.g, base.b, 0.0))
		grad.set_color(1, base)
		grad.add_point(0.5, Color(base.r, base.g, base.b, 0.35))
		var gt := GradientTexture2D.new()
		gt.gradient = grad
		gt.width = 4
		gt.height = 64
		gt.fill_from = Vector2(0, 0.35)
		gt.fill_to = Vector2(0, 1)
		var fade := TextureRect.new()
		fade.texture = gt
		fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fade.stretch_mode = TextureRect.STRETCH_SCALE
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art_clip.add_child(fade)

		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 12)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(margin)

		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(col)

		var push := Control.new()      # همه‌چیز را به پایینِ کارت هل می‌دهد
		push.size_flags_vertical = Control.SIZE_EXPAND_FILL
		push.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(push)

		col.add_child(_emblem())

		var name_l := _label(str(_mode.get("name", "")), 25, COL_DIM if locked else COL_TEXT)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		name_l.add_theme_constant_override("outline_size", 6)
		col.add_child(name_l)

		var desc_text := ModeArt.tagline(_mode)
		if coming_soon:
			desc_text = "این مود به زودی اضافه می‌شود"
		elif locked:
			desc_text = "با %s کاپ باز می‌شود — الان %s کاپ داری" % [
				_fa(_min_trophies), _fa(_trophies)]
		var desc := _label(desc_text, 14, COL_DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.custom_minimum_size = Vector2(0, 44)
		col.add_child(desc)

		if locked and not coming_soon:
			col.add_child(_progress_bar())

		# C8/C11: «چه می‌بری» روی خودِ کارت — طلایی = پاداش (V1). جریمه‌ی باخت
		# همچنان در راهنمای «؟» است تا کارت شلوغ نشود.
		if not coming_soon:
			col.add_child(_reward_line())

		col.add_child(_team_frame())

		_fx = _layer(_draw_front)
		if recommended and not locked:
			_add_recommended_badge()


	## رنگِ کارت. مودِ قفل رنگِ خودش را نگه می‌دارد ولی کم‌جان — خاکستریِ
	## کامل همه‌ی کارت‌ها را شبیهِ هم می‌کند و صفحه رنگش را از دست می‌دهد.
	func _tint() -> Color:
		return accent.lerp(COL_LOCKED, 0.5) if locked else accent


	func _layer(painter: Callable) -> Control:
		var c := Control.new()
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.draw.connect(painter)
		add_child(c)
		return c


	## قاب و درخشش بسته به «انتخاب‌شده/قفل» — بدون ساختنِ دوباره‌ی کارت
	func _apply_state() -> void:
		var tint := _tint()
		if is_active and not locked:
			_panel_sb.set_border_width_all(3)
			_panel_sb.border_color = tint.lightened(0.3)
			_panel_sb.shadow_color = Color(tint.r, tint.g, tint.b, 0.55)
			_panel_sb.shadow_size = 16
		else:
			_panel_sb.set_border_width_all(2)
			_panel_sb.border_color = Color(tint.r, tint.g, tint.b, 0.85)
			_panel_sb.shadow_color = Color(0, 0, 0, 0.5)
			_panel_sb.shadow_size = 8
		var animate := is_active and not locked
		set_process(animate)
		if not animate and _emblem_rect != null:
			_emblem_rect.scale = Vector2.ONE
		_glow.queue_redraw()
		_fx.queue_redraw()


	func _emblem() -> Control:
		_emblem_slot = Control.new()
		_emblem_slot.custom_minimum_size = Vector2(0, 110)
		_emblem_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex := ModeArt.emblem(mode_id)
		if tex != null:
			_emblem_rect = TextureRect.new()
			_emblem_rect.texture = tex
			_emblem_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			_emblem_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_emblem_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_emblem_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# SVGهای قدیمی تک‌رنگ‌اند و باید تینت شوند؛ PNGها هنرِ تمام‌رنگ‌اند
			if tex.resource_path.ends_with(".svg"):
				_emblem_rect.modulate = accent
			if locked:
				_emblem_rect.modulate = Color(0.62, 0.62, 0.66)
			_emblem_slot.add_child(_emblem_rect)
		return _emblem_slot


	## قابِ تیم‌بندی: «‹  👥 4 vs 4  ›». فلش‌ها تزئینی‌اند؛ لمسشان هم مثلِ
	## لمسِ بقیه‌ی کارت همین مود را انتخاب می‌کند.
	func _team_frame() -> Control:
		var tint := _tint()
		var pc := PanelContainer.new()
		pc.custom_minimum_size = Vector2(0, 46)
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.32)
		sb.set_corner_radius_all(7)
		sb.set_border_width_all(1)
		sb.border_color = Color(tint.r, tint.g, tint.b, 0.55)
		sb.content_margin_left = 10.0
		sb.content_margin_right = 10.0
		pc.add_theme_stylebox_override("panel", sb)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pc.add_child(row)

		row.add_child(_chevron(tint, false))
		row.add_child(_expander())
		row.add_child(_people_icon(tint))
		var n := int(_mode.get("team_size", 0))
		var team_text := ("%d vs %d" % [n, n]) if n > 0 else str(_mode.get("subtitle", ""))
		var l := _label(team_text, 21, tint.lightened(0.15))
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
		row.add_child(_expander())
		row.add_child(_chevron(tint, true))
		return pc


	func _expander() -> Control:
		var c := Control.new()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return c


	func _chevron(col: Color, right: bool) -> Control:
		var c := Control.new()
		c.custom_minimum_size = Vector2(12, 0)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.draw.connect(func() -> void:
			var m := c.size * 0.5
			var d := 4.0 if right else -4.0
			c.draw_polyline(PackedVector2Array([
				Vector2(m.x - d, m.y - 7), Vector2(m.x + d, m.y), Vector2(m.x - d, m.y + 7),
			]), col, 2.5, true))
		return c


	## دو آدمکِ کنارِ هم (فونت گلیفِ آیکون ندارد)
	func _people_icon(col: Color) -> Control:
		var c := Control.new()
		c.custom_minimum_size = Vector2(28, 0)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.draw.connect(func() -> void:
			var m := c.size * 0.5
			for f in [[-5.5, 0.75], [5.5, 1.0]]:
				var x: float = m.x + float(f[0])
				var k: float = f[1]
				var shade := Color(col.r, col.g, col.b, k)
				c.draw_circle(Vector2(x, m.y - 5.0), 4.2, shade)
				var body := PackedVector2Array()
				for i in 13:
					var a := PI + PI * float(i) / 12.0
					body.append(Vector2(x + cos(a) * 7.5, m.y + 9.0 + sin(a) * 7.0))
				c.draw_colored_polygon(body, shade))
		return c


	## «برد: +۲۴ کاپ   +۱۲۰ سکه» (نقطه‌ی وسط در Lalezar شبیهِ «۰» است) — اعداد Lalezar، طلایی؛ مودِ قفل کم‌رنگ‌تر
	func _reward_line() -> Control:
		var cups := int(_mode.get("win_trophies", 0))
		var coins := int(_mode.get("win_coins", 0))
		var text := "برد: +%s کاپ   +%s سکه" % [_fa(cups), _fa(coins)]
		var gold := Color(0.96, 0.79, 0.32)
		var l := _label(text, 16, gold.darkened(0.35) if locked else gold)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		l.add_theme_constant_override("outline_size", 4)
		return l


	## برچسبِ طلاییِ «پیشنهادی» گوشه‌ی بالا-چپِ تصویر (گوشه‌ی راست مالِ تیکِ انتخاب است)
	func _add_recommended_badge() -> void:
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.96, 0.79, 0.32)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 9.0
		sb.content_margin_right = 9.0
		sb.content_margin_top = 1.0
		sb.content_margin_bottom = 2.0
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_size = 4
		chip.add_theme_stylebox_override("panel", sb)
		chip.add_child(_label("پیشنهادی", 15, Color(0.09, 0.07, 0.04)))
		chip.position = Vector2(8, 8)
		add_child(chip)


	## نوارِ «چقدر تا باز شدن» — عددِ خالی حسِ نزدیک بودن را نمی‌رساند
	func _progress_bar() -> Control:
		var ratio := 0.0
		if _min_trophies > 0:
			ratio = clampf(float(_trophies) / float(_min_trophies), 0.0, 1.0)
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(0, 7)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.draw.connect(func() -> void:
			var w := bar.size.x
			var h := bar.size.y
			bar.draw_rect(Rect2(0.0, 0.0, w, h), Color(1, 1, 1, 0.08), true)
			# راست‌به‌چپ پر می‌شود، هم‌جهتِ متنِ فارسی
			bar.draw_rect(Rect2(w * (1.0 - ratio), 0.0, w * ratio, h),
				Color(accent.r, accent.g, accent.b, 0.85), true))
		return bar


	# ---------------------------------------------------------- نقاشی

	## وقتی تصویرِ کارت هنوز ساخته نشده: شیبِ رنگِ مود + نوارهای نورِ مورب
	func _draw_art_fallback(c: Control, tint: Color, base: Color) -> void:
		var s := c.size
		var steps := 12
		for i in steps:
			var t := float(i) / float(steps)
			c.draw_rect(Rect2(0.0, s.y * t, s.x, s.y / float(steps) + 1.0),
				tint.darkened(0.55).lerp(base, t))
		for i in 3:
			var x := s.x * (0.15 + 0.32 * float(i))
			c.draw_colored_polygon(PackedVector2Array([
				Vector2(x, 0.0), Vector2(x + 26.0, 0.0),
				Vector2(x - s.x * 0.25 + 26.0, s.y), Vector2(x - s.x * 0.25, s.y),
			]), Color(tint.r, tint.g, tint.b, 0.07))


	## درخششِ بیرونِ قاب برای کارتِ انتخابی — آرام نفس می‌کشد
	func _draw_glow() -> void:
		if not is_active or locked:
			return
		var s := _glow.size
		var pulse := 0.75 + 0.25 * sin(_t * 2.2)
		for i in range(1, 6):
			var g := float(i) * 2.0
			_glow.draw_rect(Rect2(-g, -g, s.x + g * 2.0, s.y + g * 2.0),
				Color(accent.r, accent.g, accent.b, 0.10 * pulse * (1.0 - float(i) / 6.0)),
				false, 2.0)


	func _draw_front() -> void:
		var s := _fx.size
		if s.x <= 0.0:
			return
		if locked:
			_draw_lock(s)
		elif is_active:
			# گوشه‌ی بالا-راست: مثلثِ رنگِ مود با تیکِ سفید
			var r := 46.0
			_fx.draw_colored_polygon(PackedVector2Array([
				Vector2(s.x - r, 0.0), Vector2(s.x, 0.0), Vector2(s.x, r),
			]), accent.lightened(0.15))
			_fx.draw_polyline(PackedVector2Array([
				Vector2(s.x - 25.0, 13.0), Vector2(s.x - 19.0, 19.0), Vector2(s.x - 8.0, 7.0),
			]), Color.WHITE, 3.0, true)


	## قفل: پرده‌ی تیره + قفلی که دستی کشیده می‌شود
	func _draw_lock(s: Vector2) -> void:
		# کلِ کارت، نه فقط تصویر — پرده‌ی نیمه‌کاره لبه‌ی تیزِ افقی می‌انداخت
		_fx.draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, 0.28), true)
		if _emblem_slot == null:
			return
		var to_fx := _fx.get_global_transform().affine_inverse() * _emblem_slot.get_global_transform()
		var c := to_fx * (_emblem_slot.size * 0.5)
		_fx.draw_circle(c, 30.0, Color(0, 0, 0, 0.55))
		var col := Color(0.88, 0.86, 0.9, 0.95)
		_fx.draw_rect(Rect2(c.x - 15.0, c.y - 4.0, 30.0, 22.0), col, true)
		_fx.draw_arc(Vector2(c.x, c.y - 4.0), 9.5, PI, TAU, 18, col, 4.0)
		_fx.draw_circle(Vector2(c.x, c.y + 6.0), 3.5, Color(0.1, 0.08, 0.1))
		if coming_soon:
			_draw_coming_soon(s)


	## نوارِ مورب «به زودی...» روی تصویرِ کارت، به رنگِ طلاییِ تمِ بازی
	func _draw_coming_soon(s: Vector2) -> void:
		const TEXT := "به زودی..."
		var fs := clampi(int(s.x * 0.12), 22, 34)
		var band_h := float(fs) * 1.7
		var center := Vector2(s.x * 0.5, s.y * ART_BOTTOM * 0.42)
		# نوار کج است ولی دو سرش دقیقاً روی لبه‌ی کارت بریده می‌شود
		var slope := s.x * 0.5 * tan(0.12)
		var top := center.y - band_h * 0.5
		var bottom := center.y + band_h * 0.5
		var a := Vector2(0.0, top + slope)
		var b := Vector2(s.x, top - slope)
		var c := Vector2(s.x, bottom - slope)
		var d := Vector2(0.0, bottom + slope)
		_fx.draw_colored_polygon(PackedVector2Array([a, b, c, d]), Color(0.05, 0.03, 0.03, 0.88))
		var gold := Color(0.96, 0.79, 0.32)
		_fx.draw_line(a, b, gold, 2.0, true)
		_fx.draw_line(d, c, gold, 2.0, true)
		_fx.draw_set_transform(center, -0.12, Vector2.ONE)
		var tw := _font.get_string_size(TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_fx.draw_string_outline(_font, Vector2(-tw * 0.5, fs * 0.36), TEXT,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.9))
		_fx.draw_string(_font, Vector2(-tw * 0.5, fs * 0.36), TEXT,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, gold)
		_fx.draw_set_transform_matrix(Transform2D.IDENTITY)


	# ---------------------------------------------------------- ورودی

	## ورودِ کارت: روشن می‌شود و کمی باز می‌شود. عمداً `scale` و نه
	## `position` — کارت فرزندِ HBoxContainer است و جایش را کانتینر تعیین می‌کند.
	func play_intro(delay: float) -> void:
		modulate.a = 0.0
		scale = Vector2(0.9, 0.9)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(self, "modulate:a", 1.0, 0.28).set_delay(delay)
		tw.tween_property(self, "scale", Vector2.ONE, 0.36) \
			.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


	## تاچ و ماوسِ شبیه‌سازی‌شده هر دو می‌رسند (emulate_mouse_from_touch /
	## emulate_touch_from_mouse). منبعِ اولین لمس را نگه می‌داریم و بقیه را
	## تا رها شدن نادیده می‌گیریم، وگرنه یک لمس دو بار حساب می‌شود و کشیدن
	## دوبرابر اسکرول می‌کند.
	func _on_gui_input(event: InputEvent) -> void:
		var is_touch := event is InputEventScreenTouch
		var is_click: bool = event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT
		if is_touch or is_click:
			var src := 0 if is_touch else 1
			if event.pressed:
				if _src != -1:
					return
				_src = src
				_touch_start = event.position
				_is_swiping = false
				# V9: کارتِ فعلی هم زیرِ انگشت فرو می‌رود (قبلاً بی‌واکنش بود)
				UIFx.press_scale(self, true)
			elif src == _src:
				_src = -1
				UIFx.press_scale(self, false)
				if _is_swiping:
					return
				# رها کردن بدونِ کشیدن = انتخاب (کارتِ فعلی = «همین، برگرد»)
				if locked:
					blocked.emit(mode_id)
				else:
					UIFx.tap(self, func() -> void: chosen.emit(mode_id))
			accept_event()
			return

		var dragging: bool = (event is InputEventScreenDrag and _src == 0) or (
			event is InputEventMouseMotion and _src == 1
			and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0)
		if not dragging:
			return
		if not _is_swiping and event.position.distance_to(_touch_start) > DRAG_THRESHOLD:
			_is_swiping = true
			UIFx.press_scale(self, false)
		if _is_swiping and _scroll != null:
			_scroll.scroll_horizontal -= int(event.relative.x)
		accept_event()


	func _find_parent_scroll() -> ScrollContainer:
		var node := get_parent()
		while node != null:
			if node is ScrollContainer:
				return node
			node = node.get_parent()
		return null


	# ---------------------------------------------------------- کمکی‌ها

	func _label(text: String, size: int, colour: Color) -> Label:
		var l := Label.new()
		l.text = text
		l.add_theme_font_override("font", _font)
		l.add_theme_font_size_override("font_size", size)
		l.add_theme_color_override("font_color", colour)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return l


	static func _fa(value: int) -> String:
		const DIGITS := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
		var out := ""
		for ch in str(absi(value)):
			out += DIGITS[int(ch)]
		return out
