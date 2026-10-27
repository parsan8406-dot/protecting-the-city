class_name CityEditDialog
extends CityModal
## دیالوگ «ساخت شهر» و «ویرایش شهر» (پروفایل شهر) — یک فرم برای هر دو.
##
##   ساخت   → POST /clan/create  (هزینه CREATE_COST سکه)
##   ویرایش → POST /clan/update  (فقط رهبر؛ فقط فیلدهای عوض‌شده فرستاده
##            می‌شوند و تغییر نام یا تگ RENAME_COST سکه خرج دارد)
##
## بررسی نهایی همه‌ی قوانین روی سرور است (handlers_clan.go).
##
## استفاده:
##   var dialog := CityEditDialog.new()
##   add_child(dialog)
##   dialog.setup({})            # ساخت
##   dialog.setup(clan_data)     # ویرایش
##   dialog.saved.connect(func(result: Dictionary): ...)

signal saved(result: Dictionary)

# --- باید با ثابت‌های models.go یکی باشد ---
const CREATE_COST := 5000
const RENAME_COST := 1000
const MIN_NAME_LEN := 3
const MAX_NAME_LEN := 18
const MIN_TAG_LEN := 2
const MAX_TAG_LEN := 5
const MAX_DESC_LEN := 120
const MAX_MIN_LEVEL := 99

var _editing := false
var _original: Dictionary = {}

var _http: HTTPRequest
var _sending := false

var _preview: CityEmblem
var _name_edit: LineEdit
var _tag_edit: LineEdit
var _desc_edit: TextEdit
var _desc_count: Label
var _symbol_buttons: Array[Button] = []
var _color_buttons: Array[Button] = []
var _public_button: Button
var _private_button: Button
var _min_level_label: Label
var _access_hint: Label
var _cost_label: Label
var _error_label: Label
var _confirm_button: Button
## هزینه‌دار (ساخت ۵۰۰۰، تغییرِ نام ۱۰۰۰ سکه): لمسِ اول فقط «مسلح» می‌کند و
## مبلغ را روی همان دکمه نشان می‌دهد؛ لمسِ دوم در همین چند ثانیه خرج می‌کند.
## قبلاً یک لمس ۵۰۰۰ سکه را بی‌هشدار برمی‌داشت و بازیکن نمی‌فهمید سکه‌هایش
## کجا رفت.
const CONFIRM_WINDOW_MS := 4000
var _armed_until_ms := 0
var _idle_confirm_text := ""
var _idle_confirm_color := Color.WHITE

var _is_public := true
var _min_level := 0

## `data` خالی = ساخت شهر تازه، وگرنه اطلاعات شهر فعلی برای ویرایش
func setup(data: Dictionary) -> void:
	_editing = not data.is_empty()
	_original = data
	dismiss_on_dim = false
	build("ویرایش شهر" if _editing else "ساخت شهر جدید", 560.0)

	_http = HTTPRequest.new()
	_http.timeout = 12.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

	_build_form()

	var icon := CityEmblem.parse(str(data.get("icon_path", "")))
	_preview.set_emblem(icon.x, icon.y)
	_name_edit.text = str(data.get("name", ""))
	_tag_edit.text = str(data.get("tag", ""))
	_desc_edit.text = str(data.get("description", ""))
	_is_public = bool(data.get("is_public", true))
	_min_level = clampi(int(data.get("min_level", 0)), 0, MAX_MIN_LEVEL)

	_refresh_picker()
	_refresh_access()
	_refresh_min_level()
	_on_desc_changed()
	_refresh_cost()
	open()

# ------------------------------------------------------------------ ساخت فرم

func _build_form() -> void:
	# --- نشان + نام و تگ ---
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	body.add_child(top)

	_preview = CityEmblem.new()
	_preview.custom_minimum_size = Vector2(92, 92)
	top.add_child(_preview)

	var fields := VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.alignment = BoxContainer.ALIGNMENT_CENTER
	fields.add_theme_constant_override("separation", 8)
	top.add_child(fields)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	fields.add_child(name_row)

	_name_edit = CityUI.line_edit("نام شهر (%d تا %d حرف)" % [MIN_NAME_LEN, MAX_NAME_LEN])
	_name_edit.max_length = MAX_NAME_LEN
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.size_flags_stretch_ratio = 2.2
	_name_edit.text_changed.connect(func(_t: String) -> void: _on_field_changed())
	name_row.add_child(_name_edit)

	_tag_edit = CityUI.line_edit("تگ")
	_tag_edit.max_length = MAX_TAG_LEN
	_tag_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tag_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag_edit.add_theme_font_override("font", CityUI.FONT_NUM)
	_tag_edit.text_changed.connect(_on_tag_changed)
	name_row.add_child(_tag_edit)

	_name_edit.text_submitted.connect(func(_t: String) -> void: _tag_edit.grab_focus())
	_tag_edit.text_submitted.connect(func(_t: String) -> void: _desc_edit.grab_focus())

	var desc_box := VBoxContainer.new()
	desc_box.add_theme_constant_override("separation", 0)
	fields.add_child(desc_box)

	_desc_edit = TextEdit.new()
	_desc_edit.placeholder_text = "شعار یا توضیح کوتاه شهر..."
	_desc_edit.custom_minimum_size = Vector2(0, 54)
	_desc_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_desc_edit.add_theme_font_override("font", CityUI.FONT)
	_desc_edit.add_theme_font_size_override("font_size", 15)
	_desc_edit.add_theme_color_override("font_color", CityUI.TEXT)
	_desc_edit.add_theme_color_override("font_placeholder_color", CityUI.MUTED.darkened(0.25))
	CityUI.style_input(_desc_edit)
	_desc_edit.text_changed.connect(_on_desc_changed)
	desc_box.add_child(_desc_edit)

	_desc_count = CityUI.label("", 12, CityUI.MUTED, true)
	_desc_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc_box.add_child(_desc_count)

	# --- انتخاب نماد و رنگ نشان ---
	var picker_title := CityUI.label("نشان شهر", 15, CityUI.MUTED)
	body.add_child(picker_title)

	var symbols := HBoxContainer.new()
	symbols.add_theme_constant_override("separation", 8)
	symbols.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(symbols)
	for i in CityEmblem.SYMBOLS.size():
		var b := _make_picker_button(Vector2(52, 48))
		var ic := CityUI.icon(CityEmblem.SYMBOLS[i], 0)
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 10
		ic.offset_top = 9
		ic.offset_right = -10
		ic.offset_bottom = -9
		b.add_child(ic)
		b.pressed.connect(func() -> void:
			UIFx.tap(b)
			_preview.set_emblem(i, _preview.color_index)
			_refresh_picker())
		symbols.add_child(b)
		_symbol_buttons.append(b)

	var colors := HBoxContainer.new()
	colors.add_theme_constant_override("separation", 10)
	colors.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(colors)
	for i in CityEmblem.COLORS.size():
		var b := _make_picker_button(Vector2(56, 44))
		var swatch := Panel.new()
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.add_theme_stylebox_override("panel",
			CityUI.box(CityEmblem.COLORS[i], CityEmblem.COLORS[i].lightened(0.3), 1, 6))
		swatch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		swatch.offset_left = 9
		swatch.offset_top = 9
		swatch.offset_right = -9
		swatch.offset_bottom = -9
		b.add_child(swatch)
		b.pressed.connect(func() -> void:
			UIFx.tap(b)
			_preview.set_emblem(_preview.symbol, i)
			_refresh_picker())
		colors.add_child(b)
		_color_buttons.append(b)

	# --- نوع ورود + حداقل سطح ---
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 8)
	body.add_child(options)

	_public_button = CityUI.button("عمومی", "primary", 15)
	_public_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_public_button.pressed.connect(func() -> void:
		UIFx.tap(_public_button)
		_is_public = true
		_refresh_access())
	options.add_child(_public_button)

	_private_button = CityUI.button("خصوصی", "ghost", 15)
	_private_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_private_button.pressed.connect(func() -> void:
		UIFx.tap(_private_button)
		_is_public = false
		_refresh_access())
	options.add_child(_private_button)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(6, 0)
	options.add_child(spacer)

	options.add_child(CityUI.label("حداقل سطح", 14, CityUI.MUTED))

	var minus := CityUI.button("−", "ghost", 20)
	minus.custom_minimum_size = Vector2(CityUI.TOUCH_H, CityUI.TOUCH_H)
	minus.pressed.connect(func() -> void: _step_min_level(-1))
	options.add_child(minus)

	_min_level_label = CityUI.label("۰", 20, CityUI.TEXT, true)
	_min_level_label.custom_minimum_size = Vector2(34, 0)
	_min_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	options.add_child(_min_level_label)

	var plus := CityUI.button("+", "ghost", 20)
	plus.custom_minimum_size = Vector2(CityUI.TOUCH_H, CityUI.TOUCH_H)
	plus.pressed.connect(func() -> void: _step_min_level(1))
	options.add_child(plus)

	_access_hint = CityUI.label("", 13, CityUI.MUTED)
	body.add_child(_access_hint)

	# --- هزینه، خطا، دکمه‌ها ---
	_cost_label = CityUI.label("", 14, CityUI.GOLD)
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_cost_label)

	_error_label = CityUI.label("", 14, CityUI.RED)
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.visible = false
	body.add_child(_error_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	body.add_child(buttons)

	var cancel := CityUI.button("انصراف", "ghost")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(close)
	buttons.add_child(cancel)

	_confirm_button = CityUI.button("ذخیره تغییرات" if _editing else "ساخت شهر", "gold")
	_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_button.size_flags_stretch_ratio = 1.6
	_confirm_button.pressed.connect(_on_confirm_pressed)
	buttons.add_child(_confirm_button)

func _make_picker_button(min_size: Vector2) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	UIFx.bind_press_feedback(b)
	return b

# ------------------------------------------------------------------ به‌روزرسانی نمایش

func _refresh_picker() -> void:
	var off := CityUI.box(Color(0.08, 0.08, 0.09, 0.9), Color(0.28, 0.28, 0.31, 0.7), 1, 8)
	var on := CityUI.box(Color(0.28, 0.2, 0.04, 0.95), CityUI.GOLD, 2, 8)
	for i in _symbol_buttons.size():
		_apply_picker_style(_symbol_buttons[i], on if i == _preview.symbol else off)
	for i in _color_buttons.size():
		_apply_picker_style(_color_buttons[i], on if i == _preview.color_index else off)
	_refresh_cost()

func _apply_picker_style(b: Button, style: StyleBox) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, style)

func _refresh_access() -> void:
	CityUI.style_button(_public_button, "primary" if _is_public else "ghost")
	CityUI.style_button(_private_button, "primary" if not _is_public else "ghost")
	_access_hint.text = "عمومی: هر کس سطحش کافی باشد مستقیم عضو می‌شود" if _is_public \
		else "خصوصی: درخواست‌های عضویت باید توسط رهبر یا معاون تأیید شوند"
	_clear_error()

func _step_min_level(delta: int) -> void:
	_min_level = clampi(_min_level + delta, 0, MAX_MIN_LEVEL)
	_refresh_min_level()

func _refresh_min_level() -> void:
	_min_level_label.text = CityUI.fa(_min_level)

func _on_field_changed() -> void:
	_clear_error()
	_refresh_cost()

## تگ همیشه با حروف بزرگ — سرور هم همین کار را می‌کند
func _on_tag_changed(_text: String) -> void:
	var caret := _tag_edit.caret_column
	var upper := _tag_edit.text.to_upper()
	if upper != _tag_edit.text:
		_tag_edit.text = upper
		_tag_edit.caret_column = caret
	_on_field_changed()

func _on_desc_changed() -> void:
	_clear_error()
	var text := _desc_edit.text
	if text.length() > MAX_DESC_LEN:
		_desc_edit.text = text.substr(0, MAX_DESC_LEN)
		_desc_edit.set_caret_column(MAX_DESC_LEN)
		text = _desc_edit.text
	_desc_count.text = "%s/%s" % [CityUI.fa(text.length()), CityUI.fa(MAX_DESC_LEN)]

func _is_renaming() -> bool:
	if not _editing:
		return false
	return _name_edit.text.strip_edges() != str(_original.get("name", "")) \
		or _tag_edit.text.strip_edges().to_upper() != str(_original.get("tag", ""))

func _refresh_cost() -> void:
	if _cost_label == null:
		return
	if not _editing:
		_cost_label.text = "هزینه ساخت: %s سکه   •   موجودی تو: %s" % [
			CityUI.fa_grouped(CREATE_COST), CityUI.fa_grouped(Global.coins)]
		_cost_label.add_theme_color_override("font_color",
			CityUI.GOLD if Global.coins >= CREATE_COST else CityUI.RED)
	elif _is_renaming():
		_cost_label.text = "تغییر نام یا تگ: %s سکه   •   موجودی تو: %s" % [
			CityUI.fa_grouped(RENAME_COST), CityUI.fa_grouped(Global.coins)]
		_cost_label.add_theme_color_override("font_color",
			CityUI.GOLD if Global.coins >= RENAME_COST else CityUI.RED)
	else:
		_cost_label.text = "تغییر نشان، شعار و تنظیمات رایگان است"
		_cost_label.add_theme_color_override("font_color", CityUI.MUTED)

func _show_error(message: String) -> void:
	_error_label.text = message
	_error_label.visible = true
	shake()

func _clear_error() -> void:
	if _error_label != null:
		_error_label.visible = false

# ------------------------------------------------------------------ ارسال

## true یعنی بازیکن خرجِ cost سکه را تأیید کرده (لمسِ دوم)؛ لمسِ اول دکمه را
## قرمز و «مسلح» می‌کند و false برمی‌گرداند.
func _confirm_spend(cost: int) -> bool:
	var now := Time.get_ticks_msec()
	if _armed_until_ms > now:
		_disarm_confirm()
		return true
	_armed_until_ms = now + CONFIRM_WINDOW_MS
	_idle_confirm_text = _confirm_button.text
	_idle_confirm_color = _confirm_button.get_theme_color("font_color")
	_confirm_button.text = "تأیید — %s سکه کم می‌شود" % CityUI.fa_grouped(cost)
	_confirm_button.add_theme_color_override("font_color", CityUI.RED)
	_show_error("برای پرداختِ %s سکه دوباره بزن" % CityUI.fa_grouped(cost))
	get_tree().create_timer(CONFIRM_WINDOW_MS / 1000.0).timeout.connect(func() -> void:
		if is_instance_valid(_confirm_button) and _armed_until_ms > 0 and Time.get_ticks_msec() >= _armed_until_ms:
			_disarm_confirm()
			_clear_error())
	return false


func _disarm_confirm() -> void:
	_armed_until_ms = 0
	if _idle_confirm_text != "":
		_confirm_button.text = _idle_confirm_text
	_confirm_button.add_theme_color_override("font_color", _idle_confirm_color)


func _on_confirm_pressed() -> void:
	UIFx.tap(_confirm_button)
	if _sending:
		return

	var name_text := _name_edit.text.strip_edges()
	var tag_text := _tag_edit.text.strip_edges().to_upper()
	var desc_text := _desc_edit.text.strip_edges()

	if name_text.length() < MIN_NAME_LEN:
		_show_error("نام شهر باید حداقل %s حرف باشد" % CityUI.fa(MIN_NAME_LEN))
		return
	if tag_text.length() < MIN_TAG_LEN:
		_show_error("تگ شهر باید حداقل %s حرف باشد" % CityUI.fa(MIN_TAG_LEN))
		return

	var path := "/clan/create"
	var payload := {"username": Global.my_username}

	if not _editing:
		if Global.coins < CREATE_COST:
			_show_error("سکه‌ات برای ساخت شهر کافی نیست")
			return
		if not _confirm_spend(CREATE_COST):
			return
		payload.merge({
			"name": name_text,
			"tag": tag_text,
			"description": desc_text,
			"icon_path": _preview.get_icon_path(),
			"is_public": _is_public,
			"min_level": _min_level,
		})
	else:
		path = "/clan/update"
		if _is_renaming() and Global.coins < RENAME_COST:
			_show_error("سکه‌ات برای تغییر نام شهر کافی نیست")
			return
		if _is_renaming() and not _confirm_spend(RENAME_COST):
			return
		# فقط چیزی که عوض شده
		if name_text != str(_original.get("name", "")):
			payload["name"] = name_text
		if tag_text != str(_original.get("tag", "")):
			payload["tag"] = tag_text
		if desc_text != str(_original.get("description", "")):
			payload["description"] = desc_text
		# نشان خالیِ قدیمی همان emblem:0:0 است — فقط تغییر واقعی فرستاده شود
		var original_icon := CityEmblem.parse(str(_original.get("icon_path", "")))
		if original_icon != Vector2i(_preview.symbol, _preview.color_index):
			payload["icon_path"] = _preview.get_icon_path()
		if _is_public != bool(_original.get("is_public", true)):
			payload["is_public"] = _is_public
		if _min_level != int(_original.get("min_level", 0)):
			payload["min_level"] = _min_level
		if payload.size() == 1:
			close()
			return

	_sending = true
	_confirm_button.disabled = true
	_clear_error()

	var err := _http.request(
		Global.SERVER_BASE + path,
		Global.json_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload))
	if err != OK:
		_sending = false
		_confirm_button.disabled = false
		_show_error("ارتباط با سرور برقرار نشد")

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body_bytes: PackedByteArray) -> void:
	_sending = false
	_confirm_button.disabled = false

	var parsed = JSON.parse_string(body_bytes.get_string_from_utf8())
	var data: Dictionary = parsed if typeof(parsed) == TYPE_DICTIONARY else {}

	if result != HTTPRequest.RESULT_SUCCESS:
		_show_error("ارتباط با سرور برقرار نشد — اینترنتت را چک کن")
		return
	if response_code != 200 and response_code != 201:
		_show_error(str(data.get("error", "انجام نشد (کد %d)" % response_code)))
		return

	# سکه‌ی کم‌شده را فوری روی TopBar منعکس کن
	if data.has("coins"):
		Global.note_wallet_changed()
		Global.coins = int(data["coins"])
		Global.player_data_updated.emit()

	saved.emit(data)
	close()
