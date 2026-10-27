extends PanelContainer
## «هدفِ بعدی» — یک خطِ کوچک زیرِ ستونِ دکمه‌های منوی اصلی.
##
## E7 زیگارنیک + E16 عادت: وقتی بازیکن به لابی برمی‌گردد، نزدیک‌ترین کارِ
## نیمه‌تمام یا جایزه‌ی آماده‌اش را می‌بیند — محرّکِ «یک دستِ دیگر».
## C9 شیبِ هدف: «فقط ۲ تا مانده» به‌جای عددِ خشک.
## V5: عمداً آرام است — تیره با حاشیه‌ی نازکِ طلایی، بدونِ پالس؛ تنها دکمه‌ی
## متمایزِ صفحه همان «شروع» می‌ماند.
##
## اولویت (فقط یکی نشان داده می‌شود، C1):
##   ۱) جایزه‌ی ماموریتِ آماده‌ی دریافت        → صفحه‌ی ماموریت‌ها
##   ۲) ماموریتی که بیش از نصفش انجام شده      → صفحه‌ی ماموریت‌ها
##   ۳) نزدیک‌ترین مودِ قفل (کاپِ لازم)          → صفحه‌ی مودها (E12)
##   ۴) هر ماموریتِ در حال انجام
## هیچ‌کدام نبود (یا آموزش در جریان است) → پنهان.
##
## E16 محرّکِ برگشت: اولین باری که در یک روزِ تازه لابی باز می‌شود و
## ماموریت‌های امروز هنوز دست نخورده‌اند، به‌جای (۲) تا (۴) یک بار خبرِ مثبتِ
## «ماموریت‌های امروز رسید» می‌آید — فقط واقعیت (ریستِ روزانه)، بدونِ تایمرِ فشار.
## C9: زیرِ کادر یک نوارِ باریکِ طلایی پیشرفتِ همان هدف را نشان می‌دهد (از
## راست پر می‌شود)؛ برای مودِ قفل یعنی کاپِ فعلی نسبت به کاپِ لازم.
##
## داده‌ها همان دو درخواستِ سبکی است که بقیه‌ی منو هم می‌زند؛ هیچ عددی این‌جا
## ساخته نمی‌شود.

const MISSIONS_SCENE := "res://secense/missions_screen.tscn"
const MODES_SCENE := "res://secense/game_modes.tscn"
const FONT_NUM := preload("res://fonts/Lalezar-Regular.ttf")
const CHEST_ART := "res://assets/ui/psych/chest_closed.png"
const PADLOCK_ART := "res://assets/ui/psych/tease_padlock.png"

const GOLD := Color(0.96, 0.79, 0.32)
const TEXT := Color(0.95, 0.95, 0.96)
const MUTED := Color(0.70, 0.70, 0.74)
const TAP_SLOP := 14.0
## «روزِ تازه» یک بار در روز (روی همین دستگاه و حساب)
const PREFS_PATH := "user://psych_menu.cfg"
const BAR_H := 3.0
## پشتِ هم رفرش نکن (player_data_updated چند بار پشتِ هم می‌آید)
const MIN_REFRESH_MS := 1500

var _http_missions: HTTPRequest = null
var _http_modes: HTTPRequest = null
var _icon: TextureRect = null
var _title: Label = null
var _sub: Label = null
var _style: StyleBoxFlat = null
var _target := ""
var _missions: Array = []
var _modes: Array = []
var _trophies := -1
var _last_refresh := -100000
var _touch_down := false
var _touch_start := Vector2.ZERO
var _shown_once := false
## پیشرفتِ هدفِ نمایش‌داده‌شده ۰..۱ — منفی یعنی نوار نکش
var _progress := -1.0
var _shown_bar := 0.0
var _fresh_day_used := false


func _ready() -> void:
	name = "NextGoal"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 56)
	_build()

	_http_missions = HTTPRequest.new()
	_http_missions.timeout = 8.0
	add_child(_http_missions)
	_http_missions.request_completed.connect(_on_missions)
	_http_modes = HTTPRequest.new()
	_http_modes.timeout = 8.0
	add_child(_http_modes)
	_http_modes.request_completed.connect(_on_modes)

	if not Global.player_data_loaded.is_connected(refresh):
		Global.player_data_loaded.connect(refresh)
	# جایزه‌ی ماموریت در خودِ منو گرفته شد → کیف پول عوض می‌شود → دوباره بپرس
	if not Global.player_data_updated.is_connected(refresh):
		Global.player_data_updated.connect(refresh)
	refresh()


func _build() -> void:
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.03, 0.03, 0.035, 0.80)
	_style.set_corner_radius_all(10)
	_style.set_border_width_all(1)
	_style.border_color = Color(GOLD, 0.45)
	_style.content_margin_left = 12.0
	_style.content_margin_right = 10.0
	_style.content_margin_top = 6.0
	_style.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", _style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	# فلشِ «برو» سمتِ چپ (رو به محتوا در راست‌به‌چپ)
	# V9: فلشِ کشیده‌شده — گلیفِ «‹» در Lalezar شبیهِ پرانتز دیده می‌شد
	var chevron := Control.new()
	chevron.custom_minimum_size = Vector2(14, 24)
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.draw.connect(func() -> void:
		var c := chevron.size * 0.5
		chevron.draw_polyline(PackedVector2Array([
			c + Vector2(4, -8), c + Vector2(-4, 0), c + Vector2(4, 8)]),
			Color(GOLD, 0.85), 3.0, true))
	row.add_child(chevron)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_title = _label(18, TEXT)
	col.add_child(_title)
	_sub = _label(15, MUTED)
	col.add_child(_sub)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(42, 42)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)


func _label(size: int, colour: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", FONT_NUM)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ============================ داده ============================

func refresh() -> void:
	var user := str(Global.my_username)
	if user.is_empty() or not is_inside_tree():
		return
	var now := Time.get_ticks_msec()
	if now - _last_refresh < MIN_REFRESH_MS:
		return
	_last_refresh = now
	if _http_missions.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_http_missions.request("%s/missions/daily?username=%s" % [
			Global.SERVER_BASE, user.uri_encode()], Global.auth_headers())
	if _http_modes.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_http_modes.request("%s/game_modes?username=%s" % [
			Global.SERVER_BASE, user.uri_encode()], Global.auth_headers())


func _parse(result: int, code: int, body: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return {}
	var data = JSON.parse_string(body.get_string_from_utf8())
	return data if typeof(data) == TYPE_DICTIONARY else {}


func _on_missions(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var data := _parse(result, code, body)
	if data.is_empty():
		return   # اینترنتِ ناپایدار: همان هدفِ قبلی می‌ماند
	var list = data.get("missions", [])
	_missions = list if typeof(list) == TYPE_ARRAY else []
	_pick()


func _on_modes(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var data := _parse(result, code, body)
	if data.is_empty():
		return
	var list = data.get("modes", [])
	_modes = list if typeof(list) == TYPE_ARRAY else []
	_trophies = int(data.get("trophies", Global.trophies))
	_pick()


# ============================ انتخابِ هدف ============================

func _pick() -> void:
	if _tutorial_running():
		_hide()
		return

	var ready_list: Array = []
	var best: Dictionary = {}
	var best_ratio := -1.0
	for item in _missions:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var m: Dictionary = item
		if bool(m.get("claimed", false)):
			continue
		if bool(m.get("done", false)):
			ready_list.append(m)
			continue
		var target := maxi(int(m.get("target", 1)), 1)
		var ratio := float(int(m.get("progress", 0))) / float(target)
		if ratio > best_ratio:
			best_ratio = ratio
			best = m

	# ۱) جایزه‌ی آماده
	if not ready_list.is_empty():
		var first: Dictionary = ready_list[0]
		var title := "جایزه‌ی ماموریت آماده است!" if ready_list.size() == 1 \
			else "%s جایزه‌ی ماموریت آماده است!" % MissionArt.fa_number(ready_list.size())
		_show(title, "«%s» — بزن و بگیر" % str(first.get("title", "")),
			_art(CHEST_ART, MissionArt.texture_for(str(first.get("icon", "")))), MISSIONS_SCENE, true)
		return

	# E16) روزِ تازه، ماموریت‌های دست‌نخورده — یک بار در روز
	if _fresh_day_used or _is_fresh_day():
		var total_xp := 0
		for item in _missions:
			if typeof(item) == TYPE_DICTIONARY:
				total_xp += int((item as Dictionary).get("xp", 0))
		var sub_fresh := "%s ماموریتِ تازه" % MissionArt.fa_number(_missions.size())
		if total_xp > 0:
			sub_fresh += " — تا %sxp جایزه" % MissionArt.fa_grouped(total_xp)
		_show("ماموریت‌های امروز رسید!", sub_fresh,
			_art(CHEST_ART, null), MISSIONS_SCENE, false)
		return

	# ۲) ماموریتِ نزدیک به پایان (C9)
	if not best.is_empty() and best_ratio >= 0.5:
		_show_mission(best)
		return

	# ۳) مودِ قفلِ بعدی (E12)
	var gate := _next_locked_mode()
	if not gate.is_empty():
		var need := int(gate.get("min_trophies", 0)) - _trophies
		var per_win := _win_trophies()
		var sub := "هر برد +%s کاپ" % MissionArt.fa_number(per_win)
		if per_win > 0:
			var wins := int(ceil(float(need) / float(per_win)))
			sub = "حدودِ %s برد — هر برد +%s کاپ" % [MissionArt.fa_number(wins), MissionArt.fa_number(per_win)]
		var emblem := ModeArt.emblem(str(gate.get("mode_id", "")))
		_show("%s کاپ تا باز شدنِ «%s»" % [MissionArt.fa_grouped(need), str(gate.get("name", ""))],
			sub, emblem if emblem != null else _art(PADLOCK_ART, null), MODES_SCENE, false,
			float(_trophies) / float(maxi(int(gate.get("min_trophies", 1)), 1)))
		return

	# ۴) هر ماموریتِ در حال انجام
	if not best.is_empty():
		_show_mission(best)
		return
	_hide()


func _show_mission(m: Dictionary) -> void:
	var target := maxi(int(m.get("target", 1)), 1)
	var left := maxi(target - int(m.get("progress", 0)), 1)
	var xp := int(m.get("xp", 0))
	var sub := "فقط %s تا مانده" % MissionArt.fa_number(left)
	if xp > 0:
		sub += " — جایزه %sxp" % MissionArt.fa_number(xp)
	_show(str(m.get("title", "ماموریتِ روزانه")), sub,
		MissionArt.texture_for(str(m.get("icon", ""))), MISSIONS_SCENE, false,
		float(int(m.get("progress", 0))) / float(target))


## مودِ قفلی که کمترین کاپِ اضافه را لازم دارد («به زودی»ها حساب نیستند)
func _next_locked_mode() -> Dictionary:
	if _trophies < 0:
		return {}
	var out: Dictionary = {}
	for m in _modes:
		if typeof(m) != TYPE_DICTIONARY or bool(m.get("coming_soon", false)):
			continue
		var gate := int(m.get("min_trophies", 0))
		if gate <= _trophies:
			continue
		if out.is_empty() or gate < int(out.get("min_trophies", 0)):
			out = m
	return out


## کاپِ بردِ مودی که الان انتخاب شده (همان که با «شروع» بازی می‌شود)
func _win_trophies() -> int:
	var sel := str(Global.selected_mode)
	var fallback := 0
	for m in _modes:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		if str(m.get("mode_id", "")) == sel:
			return int(m.get("win_trophies", 0))
		if fallback == 0 and _trophies >= int(m.get("min_trophies", 0)) \
				and not bool(m.get("coming_soon", false)):
			fallback = int(m.get("win_trophies", 0))
	return fallback


func _art(path: String, fallback: Texture2D) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return fallback


## اولین لابیِ امروز و هیچ ماموریتی هنوز شروع نشده؟ (همان لحظه «دیده شد»
## ثبت می‌شود؛ تا آخرِ همین صفحه همان خبر می‌ماند و بارِ بعد دیگر نمی‌آید)
func _is_fresh_day() -> bool:
	if _missions.is_empty():
		return false
	for item in _missions:
		if typeof(item) != TYPE_DICTIONARY:
			return false
		var m: Dictionary = item
		if int(m.get("progress", 0)) > 0 or bool(m.get("done", false)) or bool(m.get("claimed", false)):
			return false
	var today := Time.get_date_string_from_system()
	var key := str(Global.my_username)
	var cfg := ConfigFile.new()
	cfg.load(PREFS_PATH)
	if str(cfg.get_value("lobby_fresh_day", key, "")) == today:
		return false
	cfg.set_value("lobby_fresh_day", key, today)
	cfg.save(PREFS_PATH)
	_fresh_day_used = true
	return true


func _tutorial_running() -> bool:
	var tut := get_node_or_null("/root/Tutorial")
	return tut != null and tut.has_method("is_running") and tut.is_running()


# ============================ نمایش ============================

func _show(title: String, sub: String, icon: Texture2D, target: String, reward_ready: bool,
		progress: float = -1.0) -> void:
	_set_progress(progress)
	var was_ready := _style.get_border_width(SIDE_TOP) == 2
	_title.text = title
	_sub.text = sub
	_sub.visible = sub != ""
	_icon.texture = icon
	_icon.visible = icon != null
	_target = target
	# جایزه‌ی آماده: عنوان طلایی و حاشیه پررنگ‌تر — هنوز بدونِ پالس (V5)
	_title.add_theme_color_override("font_color", GOLD if reward_ready else TEXT)
	_style.border_color = Color(GOLD, 0.85 if reward_ready else 0.45)
	_style.set_border_width_all(2 if reward_ready else 1)
	if not visible:
		visible = true
		if not _shown_once:
			_shown_once = true
			modulate.a = 0.0
			create_tween().tween_property(self, "modulate:a", 1.0, 0.3)
	# E2/V7: جایزه‌ی تازه آماده شد → یک درخششِ گرمِ کوتاه، یک بار (نه پالسِ دائمی، V5)
	if reward_ready and not was_ready:
		var tw := create_tween()
		tw.tween_interval(0.3)
		tw.tween_property(self, "self_modulate", Color(1.35, 1.2, 0.85), 0.16)
		tw.tween_property(self, "self_modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_SINE)


## نوارِ پیشرفتِ پایینِ کادر: نرم تا مقدارِ تازه می‌رود
func _set_progress(p: float) -> void:
	_progress = p
	if p < 0.0:
		_shown_bar = 0.0
		queue_redraw()
		return
	var target := clampf(p, 0.0, 1.0)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		_shown_bar = v
		queue_redraw(), _shown_bar, target, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	if _progress < 0.0 or _style == null:
		return
	var x0 := _style.content_margin_left + 2.0
	var x1 := size.x - _style.content_margin_right - 2.0
	var y := size.y - BAR_H - 2.0
	if x1 <= x0:
		return
	draw_rect(Rect2(x0, y, x1 - x0, BAR_H), Color(1, 1, 1, 0.10))
	# راست‌به‌چپ: از لبه‌ی راست پر می‌شود
	var w := (x1 - x0) * _shown_bar
	if w > 0.5:
		draw_rect(Rect2(x1 - w, y, w, BAR_H), Color(GOLD, 0.95))


func _hide() -> void:
	visible = false
	_target = ""


# ============================ لمس ============================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		accept_event()
		var pos := get_global_transform_with_canvas() * (event as InputEventScreenTouch).position
		if event.pressed:
			_touch_down = true
			_touch_start = pos
			UIFx.press_scale(self, true)
			return
		if not _touch_down:
			return
		_touch_down = false
		UIFx.press_scale(self, false)
		if pos.distance_to(_touch_start) <= TAP_SLOP and _target != "":
			UIFx.tap(self, _open)
	elif event is InputEventScreenDrag and _touch_down:
		var p2 := get_global_transform_with_canvas() * (event as InputEventScreenDrag).position
		if p2.distance_to(_touch_start) > TAP_SLOP:
			_touch_down = false
			UIFx.press_scale(self, false)
	elif event is InputEventMouseButton:
		accept_event()


func _open() -> void:
	if _target == "" or not is_inside_tree():
		return
	if _target == MISSIONS_SCENE and Global.has_method("request_missions_tab"):
		Global.request_missions_tab("daily")
	get_tree().change_scene_to_file(_target)
