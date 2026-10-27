extends CanvasLayer
## وضعیتِ اتصال برای همه‌ی صحنه‌ها — ساخته و نگه‌داشته‌شده توسطِ Network.
##
## دو شکل دارد:
##   - وسطِ مسابقه: نوارِ تمام‌عرضِ وسطِ صفحه (ترسناک نیست: مشکی و طلایی، نه
##     قرمز) با «تلاشِ چندم»، شمارشِ معکوسِ مهلتِ سرور و دکمه‌ی «تلاش دوباره».
##     زیرش یک لایه‌ی نیمه‌شفاف لمسِ دکمه‌های HUD را می‌گیرد؛ جوی‌استیک و شلیک
##     را خودِ world.gd یخ می‌زند. با برگشت: «برگشتی!» (C12 بازخوردِ زیرِ ۴۰۰ms،
##     E13 مدیریتِ ناکامی — بازیکن می‌بیند چه خبر است و چقدر وقت دارد).
##   - منو/لابی/صفِ جستجو: یک قرصِ کوچکِ بالای صفحه «اتصال قطع شد — تلاش
##     دوباره…» با دکمه‌ی دستی؛ بقیه‌ی منو قابلِ استفاده می‌ماند.
##
## همه‌ی منطقِ شبکه در Network است؛ این‌جا فقط خوانده و نمایش داده می‌شود.

## قطعی‌های کوتاه‌تر از این چشمک نزنند (اتصالِ دوباره معمولاً زیرِ یک ثانیه است)
const SHOW_DELAY_MATCH_MS := 600
const SHOW_DELAY_MENU_MS := 1500
const TOAST_SEC := 1.8
const MAIN_MENU := "res://secense/main_menu.tscn"
## ۴۸dp+ در رزولوشنِ پایه‌ی ۶۴۸ (MenuUI.TOUCH_H = 50)
const BTN_H := 64.0

const PANEL_BG := Color(0.05, 0.05, 0.06, 0.95)

var _root: Control
var _blocker: ColorRect
var _panel: PanelContainer
var _panel_pad: MarginContainer
var _icon: HudIconRect
var _title: Label
## «تلاش ۲» جدا از عنوان: رقم با Lalezar (ارقامِ SJADIDBD هم‌تراز نمی‌نشینند)
var _attempt_box: HBoxContainer
var _attempt_num: Label
var _leave_kind := ""
var _sub: Label
var _secs: Label
var _secs_unit: Label
var _sub_row: HBoxContainer
var _note: Label
var _bar: ProgressBar
var _retry: Button
var _leave: Button

var _banner_pad: MarginContainer
var _banner: PanelContainer
var _banner_label: Label
var _banner_num: Label
var _banner_retry: Button

var _toast_pad: MarginContainer
var _toast: PanelContainer
var _toast_label: Label
var _toast_tw: Tween

## مسابقه از دست رفت (سرور گفت expired) — پیامِ صادقانه تا بازیکن خودش برود
var _lost := ""
var _acc := 0.0
## لحظه‌ی آخرین «تلاش دوباره»ی دستی — تا جوابِ زیرِ ۴۰۰ms دیده شود (C12)
var _manual_ms := 0


func _ready() -> void:
	layer = 118   # بالای HUD/تنظیمات (۱۱۰) و صفحه‌ی نتیجه (۱۱۵)، زیرِ لودینگ (۱۲۰)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	var net := get_parent()
	net.rejoin_result.connect(_on_rejoin_result)
	net.link_lost.connect(_refresh)
	if not SafeArea.changed.is_connected(_layout):
		SafeArea.changed.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_hide_all()


func _process(delta: float) -> void:
	_acc += delta
	if _acc < 0.1:
		return
	_acc = 0.0
	_refresh()


# -----------------------------------------------------------------------------
# حالت
# -----------------------------------------------------------------------------

func _refresh() -> void:
	var net := get_parent()
	if Global.offline_mode or LoadingScreen.is_active():
		_hide_all()
		return
	var now := Time.get_ticks_msec()
	var down: bool = net.link_down
	var down_ms: int = now - int(net.link_down_since_ms)

	if net.in_match or _lost != "":
		_banner.visible = false
		var show := _lost != "" or (down and down_ms >= SHOW_DELAY_MATCH_MS)
		_blocker.visible = show
		_panel.visible = show
		if show:
			_fill_match(net, now)
		return

	_blocker.visible = false
	_panel.visible = false
	var show_banner: bool = (down and down_ms >= SHOW_DELAY_MENU_MS) or net.http_failing
	_banner.visible = show_banner
	if show_banner:
		var manual := now - _manual_ms < 1500
		_banner_label.text = "در حال وصل شدن…" if manual else "اتصال قطع شد — تلاش دوباره…"
		var attempt := int(net.reconnect_attempt)
		_banner_num.visible = down and attempt > 1 and not manual
		_banner_num.text = MenuUI.fa(attempt)


func _fill_match(net: Node, now: int) -> void:
	if _lost != "":
		# سرور گفت جای ما آزاد شده — پیامِ صادقانه، بدونِ شمارش و بدونِ تلاشِ بی‌فایده
		_icon.icon_name = "wifi_off"
		_icon.set_tint(MenuUI.MUTED)
		_title.text = "مسابقه بدونِ تو ادامه پیدا کرد"
		_note.text = "اتصال دیر برگشت و جایت در مسابقه آزاد شد. نتیجه بعد از پایانِ مسابقه ثبت می‌شود."
		_note.visible = true
		_sub_row.visible = false
		_attempt_box.visible = false
		_bar.visible = false
		_retry.visible = false
		_leave.visible = true
		_style_leave("gold")
		return

	_retry.visible = true
	_bar.visible = true
	var left: float = net.grace_left()
	var grace: float = maxf(float(net.reconnect_grace), 1.0)
	_bar.value = clampf(left / grace, 0.0, 1.0) * 100.0
	var attempt := maxi(int(net.reconnect_attempt), 1)
	var manual := now - _manual_ms < 1500
	_icon.icon_name = "wifi_off"
	_attempt_num.text = MenuUI.fa(attempt)
	_attempt_box.visible = not net.awaiting_rejoin and not manual
	if left > 0.0:
		_icon.set_tint(MenuUI.GOLD)
		if net.awaiting_rejoin:
			_title.text = "وصل شدیم — برگشت به مسابقه…"
		elif manual:
			_title.text = "در حال وصل شدن…"
		else:
			_title.text = "اتصال قطع شد — در حال اتصالِ دوباره…"
		_sub.text = "جایت در مسابقه محفوظ است و کسی به تو آسیب نمی‌زند — تا"
		_sub_row.visible = true
		_note.visible = false
		_secs.text = MenuUI.fa(int(ceil(left)))
		_leave.visible = false
	else:
		# تخمینِ ما از مهلتِ سرور تمام شد؛ هنوز تلاش می‌کنیم (سرور کمی دیرتر از
		# ما فهمیده) ولی بازیکن حق دارد خودش برود
		_icon.set_tint(MenuUI.MUTED)
		_bar.visible = false
		_title.text = "اتصال هنوز برنگشته"
		_note.text = "احتمالاً جایت در مسابقه آزاد شده؛ هنوز تلاش می‌کنیم، یا به منو برگرد."
		_note.visible = true
		_sub_row.visible = false
		_leave.visible = true
		_style_leave("dark")


func _style_leave(kind: String) -> void:
	if _leave_kind == kind:
		return
	_leave_kind = kind
	MenuUI.style_button(_leave, kind)


func _on_rejoin_result(ok: bool, reason: String) -> void:
	if ok:
		_lost = ""
		_hide_all()
		_show_toast("برگشتی!", MenuUI.GOLD)
		LocalSettings.vibrate(30)
		return
	if reason == "match_over":
		# نتیجه (match_over + match_reward) پشتِ همین پیام می‌رسد و صفحه‌ی پایان باز می‌شود
		_lost = ""
		_hide_all()
		_show_toast("مسابقه در نبودت تمام شد — نتیجه‌ات ثبت شد", MenuUI.GOLD)
		return
	_lost = reason if reason != "" else "expired"
	_refresh()


func _on_retry_pressed() -> void:
	_manual_ms = Time.get_ticks_msec()
	Network.retry_now()
	_refresh()


func _on_leave_pressed() -> void:
	_lost = ""
	_hide_all()
	# اگر هنوز سوکت داریم، سرور همین حالا جای ما را آزاد کند (نه بعد از مهلت)
	Network.send_leave_arena()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)


func _hide_all() -> void:
	if _blocker == null:
		return
	_blocker.visible = false
	_panel.visible = false
	_banner.visible = false


func _show_toast(text: String, col: Color) -> void:
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", col)
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tw != null and _toast_tw.is_valid():
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_interval(TOAST_SEC)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.35)
	_toast_tw.tween_callback(func() -> void: _toast.visible = false)


# -----------------------------------------------------------------------------
# ساخت
# -----------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# لایه‌ی نیمه‌شفاف: دکمه‌های HUD زیرش لمس نمی‌گیرند تا وقتی وصل نیستیم
	_blocker = ColorRect.new()
	_blocker.color = Color(0, 0, 0, 0.45)
	_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_blocker)

	_build_match_panel()
	_build_banner()
	_build_toast()


func _build_match_panel() -> void:
	# تمام‌عرض، وسطِ عمودی؛ ارتفاع را محتوا تعیین می‌کند (هیچ اندازه‌ی ثابتی نیست)
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.border_color = MenuUI.GOLD_DEEP
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 18
	_panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(_panel)

	_panel_pad = MarginContainer.new()
	_panel_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_pad.add_theme_constant_override("margin_top", 22)
	_panel_pad.add_theme_constant_override("margin_bottom", 24)
	_panel.add_child(_panel_pad)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 14)
	_panel_pad.add_child(col)

	# ردیفِ عنوان (راست‌به‌چپ خوانده می‌شود): [تلاش ۲] [عنوان] [آیکن]
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 14)
	col.add_child(head)
	_attempt_box = HBoxContainer.new()
	_attempt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_attempt_box.add_theme_constant_override("separation", 6)
	head.add_child(_attempt_box)
	_attempt_num = MenuUI.label("۱", 28, MenuUI.GOLD, true)
	_attempt_box.add_child(_attempt_num)
	_attempt_box.add_child(MenuUI.label("تلاش", 22, MenuUI.MUTED))
	_title = MenuUI.label("", 28, MenuUI.GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_title.add_theme_constant_override("shadow_offset_y", 2)
	head.add_child(_title)
	_icon = HudIconRect.new().setup("wifi_off", 34, MenuUI.GOLD)
	head.add_child(_icon)

	# ردیفِ توضیح: [ثانیه] [عدد (Lalezar)] [متن] — راست‌به‌چپ: «… تا ۲۰ ثانیه»
	var sub_row := HBoxContainer.new()
	sub_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sub_row.add_theme_constant_override("separation", 8)
	col.add_child(sub_row)
	_secs_unit = MenuUI.label("ثانیه", 20, MenuUI.TEXT)
	sub_row.add_child(_secs_unit)
	_secs = MenuUI.label("", 30, MenuUI.GOLD, true)
	sub_row.add_child(_secs)
	_sub = MenuUI.label("", 20, MenuUI.TEXT)
	sub_row.add_child(_sub)
	_sub_row = sub_row
	# متنِ بلندتر (از دست رفتن / تمام شدنِ مهلت): تمام‌عرض و چندخطی
	_note = MenuUI.label("", 20, MenuUI.TEXT)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note.visible = false
	col.add_child(_note)

	# نوارِ مهلت: کنارِ دو لبه کمی فاصله تا روی هیچ گوشی‌ای زیرِ ناچ نرود
	var bar_row := HBoxContainer.new()
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bar_row)
	bar_row.add_child(_flex(1.0))
	_bar = MenuUI.progress_bar(MenuUI.GOLD, 10.0)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_stretch_ratio = 3.0
	bar_row.add_child(_bar)
	bar_row.add_child(_flex(1.0))

	var buttons := HBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 28)
	col.add_child(buttons)
	_leave = MenuUI.button("بازگشت به منو", "dark", 22)
	_leave.custom_minimum_size = Vector2(240, BTN_H)
	_leave.pressed.connect(_on_leave_pressed)
	buttons.add_child(_leave)
	_retry = MenuUI.button("تلاش دوباره", "gold", 22)
	_retry.custom_minimum_size = Vector2(240, BTN_H)
	_retry.pressed.connect(_on_retry_pressed)
	buttons.add_child(_retry)


func _build_banner() -> void:
	_banner_pad = MarginContainer.new()
	_banner_pad.anchor_left = 0.0
	_banner_pad.anchor_right = 1.0
	_banner_pad.anchor_top = 0.0
	_banner_pad.anchor_bottom = 0.0
	_banner_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_banner_pad)
	var center := HBoxContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner_pad.add_child(center)

	_banner = PanelContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := MenuUI.box(PANEL_BG, MenuUI.GOLD_DEEP, 2, 28)
	sb.content_margin_left = 18
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	_banner.add_theme_stylebox_override("panel", sb)
	center.add_child(_banner)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	_banner.add_child(row)
	_banner_retry = MenuUI.button("تلاش دوباره", "gold", 18)
	_banner_retry.custom_minimum_size = Vector2(150, 54)
	_banner_retry.pressed.connect(_on_retry_pressed)
	row.add_child(_banner_retry)
	# شماره‌ی تلاش جدا و با Lalezar (سمتِ چپِ جمله = انتهای آن در راست‌به‌چپ)
	_banner_num = MenuUI.label("", 22, MenuUI.GOLD, true)
	_banner_num.visible = false
	row.add_child(_banner_num)
	_banner_label = MenuUI.label("اتصال قطع شد — تلاش دوباره…", 20, MenuUI.TEXT)
	row.add_child(_banner_label)
	row.add_child(HudIconRect.new().setup("wifi_off", 26, MenuUI.GOLD))


func _build_toast() -> void:
	_toast_pad = MarginContainer.new()
	_toast_pad.anchor_left = 0.0
	_toast_pad.anchor_right = 1.0
	_toast_pad.anchor_top = 0.0
	_toast_pad.anchor_bottom = 0.0
	_toast_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast_pad)
	var center := HBoxContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	_toast_pad.add_child(center)
	_toast = PanelContainer.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := MenuUI.box(PANEL_BG, MenuUI.GOLD, 2, 24)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_toast.add_theme_stylebox_override("panel", sb)
	center.add_child(_toast)
	_toast_label = MenuUI.label("", 24, MenuUI.GOLD)
	_toast.add_child(_toast_label)
	_toast.visible = false


func _flex(ratio: float) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_stretch_ratio = ratio
	return c


## ناچ و لبه‌ی خمیده: متن و دکمه‌ها داخلِ ناحیه‌ی امن؛ پس‌زمینه‌ی نوار تا لبه می‌رود
func _layout() -> void:
	if _root == null or not _root.is_inside_tree():
		return
	var ins := SafeArea.insets_for(_root)
	_panel_pad.add_theme_constant_override("margin_left", int(ins.x) + 48)
	_panel_pad.add_theme_constant_override("margin_right", int(ins.z) + 48)
	for pad in [_banner_pad, _toast_pad]:
		pad.add_theme_constant_override("margin_top", int(ins.y) + 10)
		pad.add_theme_constant_override("margin_left", int(ins.x) + 16)
		pad.add_theme_constant_override("margin_right", int(ins.z) + 16)
	# «برگشتی!» زیرِ جای نوارِ منو، تا هیچ‌وقت روی هم نیفتند
	_toast_pad.add_theme_constant_override("margin_top", int(ins.y) + 84)
