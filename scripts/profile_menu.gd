extends Control
## صحنه‌ی منوی کاربر: پروفایل / تنظیمات / دوستان / پیام‌ها
##
## محتوای هر تب داخل نودهای Content/Pages/*Page است.
## رتبه‌بندی دیگر اینجا نیست — صحنه‌ی جدای ranking_screen است، کنار رنک و شهر.
##
## دکمه‌های کناری Fill نامرئی + بُردر سفید دارن و نود قرمز «تفنگی»
## (Sidebar/Highlight) پشت‌شون با انیمیشن بین تب‌ها جابه‌جا میشه.

## اسم تب‌ها به ترتیبِ نودها؛ برای open_tab() و سیگنال بیرونی استفاده میشه.
const TAB_IDS := ["profile", "settings", "friends", "messages"]

## نود قرمز چقدر از دکمه بزرگ‌تر باشه (افقی، عمودی) — تقریباً فیتِ خود دکمه
const HL_PAD := Vector2(4.0, 3.0)
## لگد افقی موقع «شلیک»
const RECOIL_X := 16.0
## زمان سفر عمودی
const TRAVEL_TIME := 0.42

## کیفریم‌های کشیده‌شدن روی محور Y (اسکیل، مدت، ترنزیشن، ایز)
## حجم ثابت می‌مونه: وقتی Y دراز میشه X جمع میشه و برعکس
const STRETCH_KEYS := [
	{"scale": Vector2(0.84, 1.40), "time": 0.13, "trans": Tween.TRANS_CUBIC, "ease": Tween.EASE_OUT},
	{"scale": Vector2(1.16, 0.78), "time": 0.15, "trans": Tween.TRANS_SINE, "ease": Tween.EASE_IN_OUT},
	{"scale": Vector2(0.94, 1.12), "time": 0.13, "trans": Tween.TRANS_SINE, "ease": Tween.EASE_IN_OUT},
	{"scale": Vector2(1.04, 0.96), "time": 0.11, "trans": Tween.TRANS_SINE, "ease": Tween.EASE_IN_OUT},
	{"scale": Vector2(1.00, 1.00), "time": 0.36, "trans": Tween.TRANS_ELASTIC, "ease": Tween.EASE_OUT},
]

const COLOR_ACTIVE := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_IDLE := Color(0.72, 0.72, 0.75, 1.0)

signal tab_changed(tab_id: String, index: int)

@onready var _buttons_box: VBoxContainer = $Sidebar/Buttons
@onready var _highlight: TextureRect = $Sidebar/Highlight
@onready var _muzzle: TextureRect = $Sidebar/MuzzleFlash
@onready var _pages: Control = $Content/Pages
@onready var _home_button: TextureButton = $HomeButton
@onready var _sidebar: Control = $Sidebar
@onready var _content: Control = $Content
@onready var _top_bar: Control = $TopBar

## نشان عددی هر تب (Label داخل یک Panel گرد)
var _badges: Dictionary = {}
## جای اصلی نودها قبل از فاصله‌ی ناچ
var _base_offsets: Dictionary = {}

var _buttons: Array[Button] = []
var _page_list: Array[Control] = []
var _current: int = -1
## تویین‌های فعال نود قرمز؛ با کلیک سریع پشت سر هم کشته می‌شن تا تداخل نکنن
var _hl_tweens: Array[Tween] = []

# ------------------------------------------------------------------ آماده‌سازی

func _ready() -> void:
	for child in _buttons_box.get_children():
		if child is Button:
			_buttons.append(child)

	for child in _pages.get_children():
		if child is Control:
			_page_list.append(child)

	for i in _buttons.size():
		_buttons[i].pressed.connect(_on_tab_pressed.bind(i))

	if _home_button:
		_home_button.pressed.connect(_on_home_pressed)

	_buttons_box.resized.connect(_snap_highlight)

	# اگه وقتی توی همین صحنه هستیم کسی درخواست تب بده (مثلاً آیکون‌های TopBar،
	# که روی همین صحنه هم هستن)، بدون تعویض صحنه تب رو عوض می‌کنیم
	if not Global.open_profile_tab_requested.is_connected(_on_profile_tab_requested):
		Global.open_profile_tab_requested.connect(_on_profile_tab_requested)

	# دکمه‌ی Back اندروید را خودمان جواب می‌دهیم (بستن پنجره یا برگشت به منو)
	get_tree().set_quit_on_go_back(false)

	# نشان‌های عددی روی تب‌ها: پیام‌های نخوانده و درخواست‌های دوستی
	_badges["messages"] = _make_badge(_buttons[TAB_IDS.find("messages")])
	_badges["friends"] = _make_badge(_buttons[TAB_IDS.find("friends")])
	Global.unread_count_updated.connect(func(_c: int) -> void: _refresh_badges())
	Global.friend_requests_updated.connect(func(_c: int) -> void: _refresh_badges())
	_refresh_badges()

	# ناچ و گوشه‌های گرد: هیچ دکمه‌ای زیر لبه نیفتد
	_base_offsets = {
		"sidebar_left": _sidebar.offset_left, "sidebar_right": _sidebar.offset_right,
		"content_left": _content.offset_left, "content_right": _content.offset_right,
		"content_bottom": _content.offset_bottom,
		"home_left": _home_button.offset_left, "home_right": _home_button.offset_right,
		"home_top": _home_button.offset_top, "home_bottom": _home_button.offset_bottom,
	}
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()

	# چند فریم صبر می‌کنیم تا VBoxContainer اندازه‌ی نهایی دکمه‌ها را حساب کند
	await get_tree().process_frame
	await get_tree().process_frame

	# تبی که قبل از اومدن به این صحنه درخواست شده، وگرنه پروفایل
	var start_index := TAB_IDS.find(Global.requested_profile_tab)
	Global.requested_profile_tab = ""
	_select_tab(start_index if start_index != -1 else 0, false)

func _on_profile_tab_requested(tab_id: String) -> void:
	Global.requested_profile_tab = ""
	open_tab(tab_id)

# ------------------------------------------------------------------ API عمومی

## باز کردن تب با آیدی (مثلاً از تاپ‌بار یا از صحنه‌ی دیگر)
func open_tab(tab_id: String) -> void:
	var index := TAB_IDS.find(tab_id)
	if index != -1:
		_select_tab(index, true)

func current_tab_id() -> String:
	return str(TAB_IDS[_current]) if _current >= 0 else ""

# ------------------------------------------------------------------ منطق تب‌ها

func _on_tab_pressed(index: int) -> void:
	_select_tab(index, true)

func _select_tab(index: int, animated: bool) -> void:
	if index < 0 or index >= _buttons.size() or index == _current:
		return

	var previous := _current
	_current = index

	_refresh_button_visuals(animated)

	if animated:
		_animate_highlight(index)
		_animate_pages(previous, index)
	else:
		_snap_highlight()
		for i in _page_list.size():
			var page := _page_list[i]
			page.visible = i == index
			page.modulate.a = 1.0
			page.position = Vector2.ZERO

	tab_changed.emit(str(TAB_IDS[index]), index)

# ------------------------------------------------------- انیمیشن نود قرمز تفنگ

func _animate_highlight(index: int) -> void:
	_kill_highlight_tweens()

	var target := _highlight_position(index)
	var direction := 1.0 if target.y > _highlight.position.y else -1.0

	_highlight.size = _highlight_size(index)
	_highlight.pivot_offset = _highlight.size * 0.5

	# ۱) سفر عمودی با کمی اورشوت
	var move := create_tween()
	move.tween_property(_highlight, "position:y", target.y, TRAVEL_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# ۲) لگد افقی مثل عقب‌نشینی تفنگ، بعد برگشت کشسان
	var kick := create_tween()
	kick.tween_property(_highlight, "position:x", target.x - RECOIL_X, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	kick.tween_property(_highlight, "position:x", target.x, 0.38) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# ۳) کش‌آمدن روی محور Y با کیفریم‌های کرو‌دار و برگشت به سایز خودش
	var stretch := create_tween()
	for key in STRETCH_KEYS:
		stretch.tween_property(_highlight, "scale", key["scale"], key["time"]) \
			.set_trans(key["trans"]).set_ease(key["ease"])

	# ۴) کج شدن مختصر به سمت حرکت
	var tilt := create_tween()
	tilt.tween_property(_highlight, "rotation_degrees", 3.0 * direction, 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tilt.tween_property(_highlight, "rotation_degrees", 0.0, 0.40) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# ۵) فلاش رنگی روی خود نود
	var flash := create_tween()
	flash.tween_property(_highlight, "modulate", Color(1.55, 1.12, 1.12, 1.0), 0.07)
	flash.tween_property(_highlight, "modulate", Color.WHITE, 0.30)

	_hl_tweens.append(move)
	_hl_tweens.append(kick)
	_hl_tweens.append(stretch)
	_hl_tweens.append(tilt)
	_hl_tweens.append(flash)

	_fire_muzzle(index)

func _kill_highlight_tweens() -> void:
	for tw in _hl_tweens:
		if is_instance_valid(tw) and tw.is_valid():
			tw.kill()
	_hl_tweens.clear()

## پرتاب فلاش دهانه‌ی لوله در سر جای جدید
func _fire_muzzle(index: int) -> void:
	if _muzzle == null:
		return

	var hl_size := _highlight_size(index)
	var hl_pos := _highlight_position(index)
	var flash_size := _muzzle.size

	_muzzle.pivot_offset = flash_size * 0.5
	_muzzle.position = hl_pos + Vector2(
		hl_size.x - flash_size.x * 0.5 - 8.0,
		hl_size.y * 0.5 - flash_size.y * 0.5
	)
	_muzzle.scale = Vector2(0.45, 0.45)
	_muzzle.rotation_degrees = randf_range(-30.0, 30.0)
	_muzzle.modulate = Color(1.0, 1.0, 1.0, 1.0)

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_muzzle, "scale", Vector2(1.3, 1.3), 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_muzzle, "modulate:a", 0.0, 0.24) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

# ------------------------------------------------------------ انیمیشن صفحه‌ها

func _animate_pages(previous: int, index: int) -> void:
	var incoming := _page_list[index]
	incoming.visible = true
	incoming.modulate.a = 0.0
	incoming.position = Vector2(-26.0, 0.0)

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(incoming, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_SINE)
	t.tween_property(incoming, "position", Vector2.ZERO, 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if previous >= 0 and previous < _page_list.size():
		var outgoing := _page_list[previous]
		var o := create_tween()
		o.set_parallel(true)
		o.tween_property(outgoing, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
		o.tween_property(outgoing, "position", Vector2(22.0, 0.0), 0.18) \
			.set_trans(Tween.TRANS_SINE)
		o.chain().tween_callback(_hide_page.bind(outgoing))

func _hide_page(page: Control) -> void:
	page.visible = false
	page.position = Vector2.ZERO

# ------------------------------------------------------------- ظاهر دکمه‌ها

func _refresh_button_visuals(animated: bool) -> void:
	for i in _buttons.size():
		var active := i == _current
		var target_color := COLOR_ACTIVE if active else COLOR_IDLE

		var title := _buttons[i].get_node_or_null("Title") as Label
		var icon := _buttons[i].get_node_or_null("Icon") as TextureRect

		if title:
			if animated:
				create_tween().tween_property(title, "modulate", target_color, 0.20)
			else:
				title.modulate = target_color

			if active and animated:
				title.pivot_offset = title.size * 0.5
				title.scale = Vector2(1.14, 1.14)
				create_tween().tween_property(title, "scale", Vector2.ONE, 0.36) \
					.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

		if icon:
			if animated:
				create_tween().tween_property(icon, "modulate", target_color, 0.20)
			else:
				icon.modulate = target_color

# ------------------------------------------------------------------- کمکی‌ها

func _highlight_size(index: int) -> Vector2:
	var btn := _buttons[index]
	return btn.size + HL_PAD * 2.0

func _highlight_position(index: int) -> Vector2:
	var btn := _buttons[index]
	return btn.position - HL_PAD

## قرار دادن آنی نود قرمز روی تب فعلی (بدون انیمیشن) — برای شروع و ری‌سایز
func _snap_highlight() -> void:
	if _current < 0 or _current >= _buttons.size() or _highlight == null:
		return
	_kill_highlight_tweens()
	_highlight.size = _highlight_size(_current)
	_highlight.pivot_offset = _highlight.size * 0.5
	_highlight.position = _highlight_position(_current)
	_highlight.scale = Vector2.ONE
	_highlight.rotation_degrees = 0.0
	_highlight.modulate = Color.WHITE

# ------------------------------------------------------------------- نشان‌ها

func _make_badge(button: Button) -> Label:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := MenuUI.box(MenuUI.RED, Color(1, 1, 1, 0.9), 2, 12)
	style.content_margin_left = 6
	style.content_margin_right = 6
	panel.add_theme_stylebox_override("panel", style)
	var label := MenuUI.label("0", 15, Color.WHITE, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(14, 22)
	panel.add_child(label)
	button.add_child(panel)
	# گوشه‌ی بالا-چپ دکمه (متن تب سمت راست است)
	panel.position = Vector2(-8, -8)
	panel.visible = false
	return label

func _set_badge(tab_id: String, count: int) -> void:
	var label: Label = _badges.get(tab_id)
	if label == null:
		return
	var panel := label.get_parent() as Control
	var was_visible := panel.visible
	panel.visible = count > 0
	label.text = "99+" if count > 99 else str(count)
	if panel.visible and not was_visible:
		panel.pivot_offset = panel.size * 0.5
		panel.scale = Vector2(0.4, 0.4)
		create_tween().tween_property(panel, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _refresh_badges() -> void:
	_set_badge("messages", Global.unread_messages)
	_set_badge("friends", Global.friend_requests_pending)

# ------------------------------------------------------------------- ناحیه‌ی امن

## فاصله‌ی ناچ/لبه‌ی خمیده از چهار طرف، به واحدِ ویوپورت
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
	if _base_offsets.is_empty():
		return
	var ins := _safe_insets()
	_sidebar.offset_left = _base_offsets["sidebar_left"] + ins.x
	_sidebar.offset_right = _base_offsets["sidebar_right"] + ins.x
	_content.offset_left = _base_offsets["content_left"] + ins.x
	_content.offset_right = _base_offsets["content_right"] - ins.z
	_content.offset_bottom = _base_offsets["content_bottom"] - ins.w
	_home_button.offset_left = _base_offsets["home_left"] - ins.z
	_home_button.offset_right = _base_offsets["home_right"] - ins.z
	_home_button.offset_top = _base_offsets["home_top"] - ins.w
	_home_button.offset_bottom = _base_offsets["home_bottom"] - ins.w
	var hb := _top_bar.get_node_or_null("HBoxContainer") as Control
	if hb != null:
		hb.offset_left = 12.0 + ins.x
		hb.offset_right = -(12.0 + ins.z)
	_snap_highlight.call_deferred()

# ------------------------------------------------------------------- ناوبری

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_handle_back()
		NOTIFICATION_EXIT_TREE:
			get_tree().set_quit_on_go_back(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_handle_back()

var _back_frame := -1

## Back اندروید: اول بالاترین پنجره‌ی باز بسته می‌شود، بعد برگشت به منوی اصلی
func _handle_back() -> void:
	# Back اندروید ممکن است هم notification بفرستد هم ui_cancel؛ فقط یک بار
	var frame := Engine.get_process_frames()
	if frame == _back_frame:
		return
	_back_frame = frame
	var modals := get_tree().get_nodes_in_group("modal")
	for i in range(modals.size() - 1, -1, -1):
		var m := modals[i] as CanvasItem
		if m == null or not m.is_visible_in_tree() or m.is_queued_for_deletion():
			continue
		if m.has_method("dismiss"):
			m.dismiss()
		elif m.has_method("close"):
			m.close()
		else:
			m.queue_free()
		return
	_on_home_pressed()

func _on_home_pressed() -> void:
	UIFx.press(_home_button, func() -> void:
		get_tree().change_scene_to_file("res://secense/main_menu.tscn"))
