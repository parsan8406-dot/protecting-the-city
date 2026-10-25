extends CanvasLayer
## منوی انتخابِ حالتِ بازیِ چندنفره.
##
## کارت‌ها از سرور می‌آیند (`GET /game_modes`) — نه از کد. پاداشِ برد، جریمه‌ی
## باخت و قفلِ کاپ همه در دیتابیس‌اند، پس بدون آپدیت بازی هم قابل تنظیم‌اند و
## کلاینت نمی‌تواند عددشان را جا بزند.
##
## انتخاب هم با `POST /game_modes/select` ذخیره می‌شود تا دفعه‌ی بعد یادش بماند.

signal mode_selected(mode: Dictionary)
signal closed

const FONT := preload("res://fonts/Lalezar-Regular.ttf")

const COL_SCRIM  := Color(0.015, 0.015, 0.02, 0.90)
const COL_CARD   := Color(0.085, 0.075, 0.095, 0.98)
const COL_CARD_L := Color(0.13, 0.115, 0.145, 0.98)
const COL_GOLD   := Color(0.96, 0.79, 0.32)
const COL_TEXT   := Color(0.96, 0.94, 0.90)
const COL_DIM    := Color(0.60, 0.58, 0.63)
const COL_WIN    := Color(0.38, 0.85, 0.50)
const COL_LOSE   := Color(0.90, 0.30, 0.30)
const COL_LOCK   := Color(0.40, 0.38, 0.43)

var _http: HTTPRequest = null
var _list: VBoxContainer = null
var _trophy_label: Label = null
var _status: Label = null
var _trophies := 0
var _selected_id := ""
var _busy := false


func _ready() -> void:
	layer = 120
	_build_chrome()
	_http = HTTPRequest.new()
	add_child(_http)
	_fetch()


# ---------------------------------------------------------------- ساخت قاب

func _build_chrome() -> void:
	var scrim := ColorRect.new()
	scrim.color = COL_SCRIM
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var root_box := MarginContainer.new()
	root_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_box.add_theme_constant_override("margin_left", 22)
	root_box.add_theme_constant_override("margin_right", 22)
	root_box.add_theme_constant_override("margin_top", 16)
	root_box.add_theme_constant_override("margin_bottom", 16)
	add_child(root_box)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	root_box.add_child(col)

	# --- سربرگ: عنوان + کاپِ فعلی + بستن ---
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	col.add_child(header)

	var close := _pill_button("بستن", COL_DIM)
	close.pressed.connect(func():
		closed.emit()
		queue_free())
	header.add_child(close)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_trophy_label = _label("🏆 ۰", 20, COL_GOLD)
	header.add_child(_trophy_label)

	var title := _label("انتخاب عملیات", 26, COL_GOLD)
	header.add_child(title)

	_status = _label("در حال گرفتن حالت‌ها…", 16, COL_DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_status)

	# لیست کارت‌ها — روی موبایل با انگشت اسکرول می‌شود
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


# ---------------------------------------------------------------- شبکه

func _fetch() -> void:
	var url := "%s/game_modes?username=%s" % [
		Global.SERVER_BASE, Global.my_username.uri_encode()]
	_http.request_completed.connect(_on_modes_received, CONNECT_ONE_SHOT)
	var err := _http.request(url, Global.auth_headers())
	if err != OK:
		_status.text = "به سرور وصل نشد"


func _on_modes_received(_result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray) -> void:
	if code != 200:
		_status.text = "گرفتن حالت‌ها ممکن نشد (%d)" % code
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		_status.text = "پاسخ سرور خوانده نشد"
		return

	_trophies = int(data.get("trophies", 0))
	_selected_id = str(data.get("selected_mode", ""))
	_trophy_label.text = "🏆 %d" % _trophies

	var modes: Array = data.get("modes", [])
	if modes.is_empty():
		_status.text = "هیچ حالتی تعریف نشده"
		return
	_status.hide()

	for c in _list.get_children():
		c.queue_free()
	for m in modes:
		_list.add_child(_mode_card(m))


func _select(mode: Dictionary) -> void:
	if _busy:
		return
	_busy = true
	var req := HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray,
			body: PackedByteArray):
		_busy = false
		if code == 200:
			_selected_id = str(mode.get("mode_id", ""))
			Global.set_selected_mode(mode)
			mode_selected.emit(mode)
			closed.emit()
			queue_free()
		else:
			# سرور حرف آخر را می‌زند — مثلاً کاپ کافی نیست
			var msg := "انتخاب نشد"
			var d = JSON.parse_string(body.get_string_from_utf8())
			if typeof(d) == TYPE_DICTIONARY and d.has("error"):
				msg = str(d["error"])
			_status.text = msg
			_status.show()
		req.queue_free())

	var payload := JSON.stringify({
		"username": Global.my_username,
		"mode_id": mode.get("mode_id", ""),
	})
	var err := req.request("%s/game_modes/select" % Global.SERVER_BASE,
		Global.json_headers(), HTTPClient.METHOD_POST, payload)
	if err != OK:
		_busy = false
		_status.text = "به سرور وصل نشد"
		_status.show()


# ---------------------------------------------------------------- کارت‌ها

func _mode_card(mode: Dictionary) -> Control:
	var accent := _accent_of(mode)
	var gate := int(mode.get("min_trophies", 0))
	var locked := _trophies < gate
	var is_current: bool = str(mode.get("mode_id", "")) == _selected_id

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_CARD_L if is_current else COL_CARD
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(3 if is_current else 2)
	sb.border_color = accent if not locked else COL_LOCK
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 13.0
	sb.content_margin_bottom = 13.0
	card.add_theme_stylebox_override("panel", sb)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	card.add_child(col)

	# --- ردیف عنوان: نام + نشانِ تیم‌بندی ---
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	col.add_child(head)

	var badge := _team_badge(mode, accent, locked)
	head.add_child(badge)

	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(pad)

	if is_current:
		head.add_child(_label("✔ انتخاب‌شده", 15, accent))

	var name_l := _label(str(mode.get("name", "")), 23,
		COL_LOCK if locked else COL_TEXT)
	head.add_child(name_l)

	# --- توضیح ---
	var desc := _label(str(mode.get("description", "")), 15, COL_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(desc)

	# --- پاداش و جریمه ---
	var econ := HBoxContainer.new()
	econ.add_theme_constant_override("separation", 14)
	col.add_child(econ)

	econ.add_child(_chip("باخت", "−%d 🏆" % int(mode.get("lose_trophies", 0)), COL_LOSE))
	econ.add_child(_chip("برد", "+%d 🏆" % int(mode.get("win_trophies", 0)), COL_WIN))
	econ.add_child(_chip("سکه", "+%d" % int(mode.get("win_coins", 0)), COL_GOLD))

	var econ_pad := Control.new()
	econ_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	econ.add_child(econ_pad)

	# --- دکمه ---
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 44)
	if locked:
		btn.text = "قفل — %d 🏆 لازم است" % gate
		btn.disabled = true
	else:
		btn.text = "انتخاب این عملیات"
		btn.pressed.connect(func(): _select(mode))
	_style_button(btn, COL_LOCK if locked else accent)
	col.add_child(btn)

	return card


## نشانِ «۴ در ۴» با رنگِ خودِ حالت
func _team_badge(mode: Dictionary, accent: Color, locked: bool) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(accent.r, accent.g, accent.b, 0.16 if not locked else 0.07)
	sb.set_corner_radius_all(9)
	sb.set_border_width_all(1)
	sb.border_color = accent if not locked else COL_LOCK
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(_label(str(mode.get("subtitle", "")), 17,
		accent if not locked else COL_LOCK))
	return p


func _chip(caption: String, value: String, colour: Color) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var v := _label(value, 18, colour)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var c := _label(caption, 13, COL_DIM)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(v)
	box.add_child(c)
	return box


func _accent_of(mode: Dictionary) -> Color:
	var raw := str(mode.get("accent", ""))
	if raw.is_valid_html_color():
		return Color(raw)
	return COL_GOLD


# ---------------------------------------------------------------- ابزار

func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


func _style_button(b: Button, colour: Color) -> void:
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", colour)
	b.add_theme_color_override("font_hover_color", colour)
	b.add_theme_color_override("font_disabled_color", COL_LOCK)
	b.add_theme_color_override("font_pressed_color", Color(0.09, 0.09, 0.09))
	for state in ["normal", "hover", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.13, 0.12, 0.14)
		s.set_corner_radius_all(11)
		s.set_border_width_all(2)
		s.border_color = colour
		b.add_theme_stylebox_override(state, s)
	var sp := StyleBoxFlat.new()
	sp.bg_color = colour
	sp.set_corner_radius_all(11)
	b.add_theme_stylebox_override("pressed", sp)


func _pill_button(text: String, colour: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(78, 38)
	_style_button(b, colour)
	return b
