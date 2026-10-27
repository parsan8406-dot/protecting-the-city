extends Control
## صفحه‌ی «جستجوی بازیکن» — رادارِ دایره‌ای.
##
## بازیکن را در صفِ سرور می‌گذارد و تا جور شدنِ مسابقه وضعیت را می‌پرسد.
## هر صندلی یک پروفایل دورِ دایره است: تعدادِ صندلی‌ها = کلِ بازیکن‌های
## مسابقه (team_size × 2) و دایره به همان تعداد تقسیمِ مساوی می‌شود.
##
## حلقه‌های دایره می‌چرخند ولی پروفایل‌ها ثابت سرِ جایشان می‌مانند: حلقه‌ها
## لایه‌های جدا با `rotation` هستند و پروفایل‌ها بچه‌ی مستقیمِ ناحیه‌ی دایره.
## چرخش فقط transform را عوض می‌کند و هیچ نقاشیِ دوباره‌ای در هر فریم نیست.
##
## صندلی‌ها پایدارند: هر بازیکن وقتی آمد در اولین صندلیِ خالی می‌نشیند و تا
## وقتی در صف است جابه‌جا نمی‌شود. صندلیِ اول (بالا) همیشه مالِ خودِ بازیکن است.
##
## بعد از ۱۰ ثانیه اگر آدمِ کافی پیدا نشود، سرور صندلی‌های خالی را با بات پر
## می‌کند (gun_game_server/mm_backfill.go). این‌جا هیچ کدی برای تشخیصشان
## نیست و عمداً هم نباید باشد: سرور هیچ نشانه‌ای نمی‌فرستد و بات‌ها دقیقاً
## مثل بقیه رندر می‌شوند.
##
## هنرِ اختیاری (همه در assets/ui/matchmaking/). هر کدام نبود، نسخه‌ی
## کدی‌اش کشیده می‌شود:
##   bg.png          پس‌زمینه‌ی تمام‌صفحه
##   ring_outer.png  حلقه‌ی بیرونی (ساعت‌گرد می‌چرخد)
##   ring_inner.png  حلقه‌ی داخلی (پادساعت‌گرد می‌چرخد)
##   globe.png       کره‌ی وسطِ دایره
## حلقه‌ها و کره با blend=add کشیده می‌شوند: روی زمینه‌ی سیاهِ خالص بسازیدشان،
## سیاه خودش شفاف می‌شود و فقط نورِ نئون می‌ماند.

const FONT := preload("res://fonts/Lalezar-Regular.ttf")
const ART_DIR := "res://assets/ui/matchmaking/"
const ITEMS_DIR := "res://assets/items"

# --- پالت ---
# هولوگرامِ آبی روی پایه‌ی تقریباً سیاه؛ طلایی برای «خودت» و لحظه‌ی پیدا شدنِ
# مسابقه، قرمز برای حریف و لغو. رنگِ کلِ رادار فقط همین COL_HOLO است.
const COL_BG      := Color(0.02, 0.035, 0.07)
const COL_PANEL   := Color(0.025, 0.05, 0.10, 0.84)
const COL_HOLO    := Color(0.16, 0.60, 1.00)
const COL_HOLO_HI := Color(0.58, 0.86, 1.00)
const COL_GOLD    := Color(0.96, 0.78, 0.28)
const COL_TEXT    := Color(0.95, 0.97, 1.00)
const COL_DIM     := Color(0.52, 0.62, 0.76)
const COL_ALLY    := Color(0.33, 0.74, 1.00)
const COL_FOE     := Color(0.93, 0.27, 0.32)
const COL_OK      := Color(0.35, 0.90, 0.45)
const COL_WARN    := Color(0.98, 0.76, 0.25)

const POLL_EVERY := 1.0
## چقدر بعد از «حریف پیدا شد» وارد زمین شویم — فرصتِ دیدنِ همه‌ی بازیکن‌ها
const ENTER_DELAY := 2.2
## سرعتِ چرخشِ حلقه‌ها (رادیان بر ثانیه)
const SPIN_OUTER := 0.35
const SPIN_INNER := -0.55
## پهنای ستونِ اسم کنارِ عکس. کارت‌های نیمه‌ی چپ اسم را سمتِ چپ می‌گذارند و
## نیمه‌ی راست سمتِ راست — همیشه رو به بیرون، تا وسطِ دایره خلوت بماند.
const NAME_W := 120.0
## پهنای ستون‌های کناری (پنلِ اطلاعات در چپ و قرینه‌اش در راست) — دایره
## همیشه دقیقاً وسطِ صفحه می‌نشیند.
const SIDE_W := 210.0
const TOUCH_H := 58.0

## C12: نکته‌های واقعیِ گیم‌پلی، همان فهرستِ صفحه‌ی بارگذاری
const PSYCH_TIPS := preload("res://scripts/psych_menu_tips.gd")
var TIPS: Array = PSYCH_TIPS.TIPS.map(func(row: Array) -> String: return str(row[0]))
const TIP_EVERY := 6.0
const PSYCH_LOADOUT := preload("res://scripts/psych_menu_loadout_stats.gd")


## یک صندلیِ دورِ دایره
class Slot:
	var root: HBoxContainer
	var frame: Control
	var frame_bg: Panel
	var style: StyleBoxFlat
	var art: TextureRect
	var mark: Label
	var level_badge: PanelContainer
	var level_label: Label
	var rank: TextureRect
	var name_label: Label
	var status: Label
	var text_col: VBoxContainer
	var username := ""
	var names_left := false


var _http_join: HTTPRequest = null
var _http_poll: HTTPRequest = null
var _http_leave: HTTPRequest = null

var _mode: Dictionary = {}
var _team_size := 2
var _need := 4
## وضعیت: searching / ready / dropped
##
## dropped یعنی دیگر در صف نیستیم (سرور ری‌استارت شده، یا اپ رفت پس‌زمینه).
## آن حالت بن‌بست نیست: دکمه تبدیل به «جستجوی دوباره» می‌شود.
var _state := "searching"
var _elapsed := 0.0
var _poll_cd := 0.0
var _poll_sent_ms := 0
var _fail_count := 0
var _tip_i := 0
var _tip_cd := TIP_EVERY
var _dots := -1
## جلوگیری از دو بار عوض کردنِ صحنه (پاسخِ status هر ثانیه می‌آید)
var _entering := false
var _back_frame := -1

# --- نودها ---
var _safe: MarginContainer = null
var _right_spacer: Control = null
var _ring_area: Control = null
var _ring_back: Control = null
var _ring_outer: Control = null
var _ring_inner: Control = null
var _globe: Control = null
var _center_title: Label = null
var _center_sub: Label = null
var _timer_label: Label = null
var _found_value: Label = null
var _elapsed_value: Label = null
var _ping_dot: Control = null
var _ping_label: Label = null
var _tip_label: Label = null
var _tip_icon: TextureRect = null
var _search_text: Label = null
## C12/C9: نوارِ باریکِ «تکمیلِ تیم» زیرِ متنِ وضعیت — تا bots_at ثانیه‌ی سرور
var _team_bar: Control = null
var _team_ratio := 0.0
var _bots_at := 20.0
var _server_waited := -1.0
var _waited_sync := 0.0
var _spinner: Control = null
var _action_button: Button = null
var _slots: Array[Slot] = []

## شعاعِ دایره‌ای که مرکزِ عکس‌ها رویش می‌نشیند و اندازه‌ی عکس‌ها؛ هر دو از
## اندازه‌ی واقعیِ ناحیه حساب می‌شوند، نه عددِ ثابت.
var _r := 150.0
var _avatar := 72.0
var _ring_tint := COL_HOLO
var _ping_colour := COL_DIM


func _ready() -> void:
	# دکمه‌ی Back اینجا یعنی «لغو جستجو»، نه بستنِ اپ
	get_tree().set_quit_on_go_back(false)
	_mode = Global.selected_mode_info()
	_team_size = maxi(1, int(_mode.get("team_size", 2)))
	_need = _team_size * 2

	_build()
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()

	_http_join = HTTPRequest.new(); add_child(_http_join)
	_http_poll = HTTPRequest.new(); add_child(_http_poll)
	_http_leave = HTTPRequest.new(); add_child(_http_leave)
	# بدونِ سقفِ زمانی، یک درخواستِ گیرکرده روی اینترنتِ موبایل صفحه‌ی جستجو
	# را برای همیشه نگه می‌داشت: poll تا تمام نشدنِ قبلی چیزی نمی‌فرستد و
	# join هم هیچ‌وقت به شاخه‌ی تلاشِ دوباره نمی‌رسید. با timeout نتیجه
	# RESULT_TIMEOUT می‌شود و همان مسیرِ خطای معمولی اجرا می‌شود.
	_http_join.timeout = 8.0
	_http_poll.timeout = 5.0
	_http_leave.timeout = 5.0
	_http_join.request_completed.connect(_on_joined)
	_http_poll.request_completed.connect(_on_status)
	# به این صفحه فقط با زدنِ «شروع» می‌رسیم، پس جستجو بی‌درنگ آغاز می‌شود.
	_start_search()


func _process(delta: float) -> void:
	# چرخشِ حلقه‌ها — فقط transform، بدون نقاشیِ دوباره
	var spin := 0.25 if _state == "ready" else 1.0
	if _ring_outer != null:
		_ring_outer.rotation = wrapf(_ring_outer.rotation + SPIN_OUTER * spin * delta, 0.0, TAU)
	if _ring_inner != null:
		_ring_inner.rotation = wrapf(_ring_inner.rotation + SPIN_INNER * spin * delta, 0.0, TAU)
	if _spinner != null and _spinner.visible:
		_spinner.rotation = wrapf(_spinner.rotation + 5.0 * delta, 0.0, TAU)
	if _globe != null and not (_globe is TextureRect):
		_globe.queue_redraw()   # فقط چند خطِ کوچک؛ نصف‌النهارها می‌لغزند

	_tip_cd -= delta
	if _tip_cd <= 0.0:
		_tip_cd = TIP_EVERY
		_tip_i = (_tip_i + 1) % TIPS.size()
		_show_tip()

	if _state != "searching":
		return

	_elapsed += delta
	if _team_bar != null:
		var waited := _elapsed if _server_waited < 0.0 else _server_waited + (_elapsed - _waited_sync)
		var r := clampf(waited / maxf(_bots_at, 1.0), 0.0, 1.0)
		if absf(r - _team_ratio) > 0.002:
			_team_ratio = r
			_team_bar.queue_redraw()
	var t := _fmt_time(_elapsed)
	_timer_label.text = t
	_elapsed_value.text = t

	# سه‌نقطه‌ی متحرکِ «در حال جستجو» — متن فقط وقتی عوض می‌شود که لازم است
	var d := int(_elapsed * 2.5) % 4
	if d != _dots:
		_dots = d
		_center_title.text = "در حال جستجو" + ".".repeat(d)

	# نبضِ ملایمِ صندلی‌های خالی — نشان می‌دهد جستجو زنده است
	var pulse := 0.45 + 0.4 * (0.5 + 0.5 * sin(_elapsed * 3.0))
	for s in _slots:
		if s.username == "":
			s.frame.modulate.a = pulse

	_poll_cd -= delta
	if _poll_cd <= 0.0:
		_poll_cd = POLL_EVERY
		_poll_status()


func _fmt_time(t: float) -> String:
	var s := int(t)
	return "%02d:%02d" % [s / 60, s % 60]


# ============================ بازگشت و چرخه‌ی عمرِ اپ ============================

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back()
		NOTIFICATION_APPLICATION_PAUSED:
			# اپ رفت پس‌زمینه (تماس، minimize). اگر در صف بمانیم ممکن است
			# مسابقه‌ای بدونِ ما جور شود؛ پس از صف بیرون می‌آییم و با برگشتن
			# دکمه‌ی «جستجوی دوباره» منتظر است.
			if _state == "searching":
				_leave_queue()
				_show_dropped("جستجو متوقف شد")
		NOTIFICATION_EXIT_TREE:
			get_tree().set_quit_on_go_back(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()


func _on_back() -> void:
	# Back اندروید هم notification می‌فرستد هم ui_cancel؛ فقط یک بار
	var frame := Engine.get_process_frames()
	if frame == _back_frame or _entering:
		return
	_back_frame = frame
	_leave_to_menu()


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


## پس‌زمینه تا لبه می‌رود؛ همه‌ی دکمه‌ها و متن‌ها داخلِ ناحیه‌ی امن
func _apply_safe_area() -> void:
	var ins := _safe_insets()
	_safe.add_theme_constant_override("margin_left", int(16.0 + ins.x))
	_safe.add_theme_constant_override("margin_right", int(16.0 + ins.z))
	_safe.add_theme_constant_override("margin_top", int(10.0 + ins.y))
	_safe.add_theme_constant_override("margin_bottom", int(10.0 + ins.w))
	# قرینه‌ی خالیِ راست فقط برای وسط ماندنِ دایره است. روی صفحه‌های کم‌عرض
	# (تبلتِ 4:3 و 16:10) آن جا را به دایره می‌دهیم — دایره‌ی کمی کنار از
	# وسط خیلی بهتر از دایره‌ی کوچکی است که کارت‌ها رویش تلنبار شوند.
	var vs := get_viewport_rect().size
	_right_spacer.visible = vs.x >= vs.y * 1.65


# ============================ ساختِ صفحه ============================

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_background()

	_safe = MarginContainer.new()
	_safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_safe)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 6)
	root_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(root_box)

	root_box.add_child(_build_header())

	# سه ستون: پنلِ اطلاعات | دایره | قرینه‌ی خالی. ستون‌های کناری هم‌پهنا
	# هستند تا دایره همیشه دقیقاً وسطِ صفحه باشد، روی هر نسبتی.
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_box.add_child(body)

	body.add_child(_build_left_column())

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 8)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(center)

	_ring_area = Control.new()
	_ring_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ring_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring_area.resized.connect(_layout_ring)
	center.add_child(_ring_area)
	_build_ring()

	center.add_child(_build_search_bar())

	_action_button = _button("لغو جستجو", COL_FOE)
	_action_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_action_button.custom_minimum_size = Vector2(250, TOUCH_H)
	_action_button.pressed.connect(_on_action_pressed)
	UIFx.bind_press_feedback(_action_button)
	center.add_child(_action_button)

	_right_spacer = Control.new()
	_right_spacer.custom_minimum_size = Vector2(SIDE_W, 0)
	_right_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_right_spacer)

	_rebuild_slots(_need)
	_fill_me_placeholder()


func _build_background() -> void:
	var base := ColorRect.new()
	base.color = COL_BG
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	var bg_tex := _art("bg")
	if bg_tex != null:
		# COVERED: روی گوشیِ دراز کناره خالی نمی‌ماند و روی 4:3 فقط لبه‌ها
		# بریده می‌شوند — محتوای مهمِ عکس باید وسط باشد.
		var bg := TextureRect.new()
		bg.texture = bg_tex
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg)

	# وینیت و هاله‌ی آبیِ وسط — یک بار کشیده می‌شود، فقط با تغییرِ اندازه دوباره
	var shade := Control.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.resized.connect(shade.queue_redraw)
	shade.draw.connect(func() -> void:
		var w := shade.size.x
		var h := shade.size.y
		var has_bg := bg_tex != null
		# روی عکس، یک لایه‌ی تیره تا دایره و متن‌ها خوانا بمانند
		if has_bg:
			shade.draw_rect(Rect2(Vector2.ZERO, shade.size), Color(0, 0, 0, 0.35))
		var c := shade.size * 0.5
		for i in 12:
			var t := float(i) / 11.0
			shade.draw_circle(c, h * (0.18 + t * 0.55),
				Color(COL_HOLO, (0.02 if has_bg else 0.035) * (1.0 - t)))
		# تیرگیِ بالا و پایین — نوارِ بالا و دکمه‌ها روی زمینه‌ی آرام بنشینند
		var band := h * 0.2
		for i in 10:
			var t := float(i) / 10.0
			var a := 0.08 * (1.0 - t)
			shade.draw_rect(Rect2(0, t * band, w, band / 10.0 + 1.0), Color(0, 0, 0, a))
			shade.draw_rect(Rect2(0, h - t * band - band / 10.0, w, band / 10.0 + 1.0), Color(0, 0, 0, a))
	)
	add_child(shade)


## نوارِ بالا: برگشت + عنوان در چپ، حالتِ بازی وسط، پینگ در راست.
## برگشت و قرینه‌اش هم‌وزن‌اند تا چیپِ حالت دقیقاً وسط بماند.
func _build_header() -> Control:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.layout_direction = Control.LAYOUT_DIRECTION_LTR

	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	left.layout_direction = Control.LAYOUT_DIRECTION_LTR
	var back := _icon_button(_draw_back_arrow)
	back.pressed.connect(_on_back)
	left.add_child(back)
	var title := _label("جستجوی بازیکن", 26, COL_TEXT)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_child(title)
	head.add_child(left)

	head.add_child(_mode_chip())

	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 6)
	right.layout_direction = Control.LAYOUT_DIRECTION_LTR
	var ping_panel := _panel(COL_PANEL, Color(COL_HOLO, 0.35), 12)
	ping_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ping_row := HBoxContainer.new()
	ping_row.add_theme_constant_override("separation", 6)
	_ping_dot = Control.new()
	_ping_dot.custom_minimum_size = Vector2(20, 20)
	_ping_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ping_dot.draw.connect(_draw_ping_bars)
	ping_row.add_child(_ping_dot)
	_ping_label = _label("-- ms", 17, COL_DIM)
	ping_row.add_child(_ping_label)
	ping_panel.add_child(ping_row)
	right.add_child(ping_panel)
	head.add_child(right)
	return head


## چیپِ وسطِ بالا: نشانِ حالت + «حالت: …» + تیم‌بندی
func _mode_chip() -> Control:
	var chip := _panel(COL_PANEL, Color(COL_HOLO, 0.55), 14)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	var emblem := ModeArt.emblem(str(_mode.get("mode_id", "")))
	if emblem != null:
		row.add_child(_tex(emblem, 38))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	var name_l := _label("حالت: %s" % str(_mode.get("name", "عملیات")), 18, COL_TEXT)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(name_l)
	var sub := str(_mode.get("subtitle", ""))
	if sub == "":
		sub = "%d در %d" % [_team_size, _team_size]
	var sub_l := _label(sub, 15, COL_HOLO_HI)
	sub_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(sub_l)
	row.add_child(col)
	chip.add_child(row)
	return chip


## ستونِ چپ: آمارِ جستجو بالا، نکته پایین
func _build_left_column() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(SIDE_W, 0)
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var stats := _panel(COL_PANEL, Color(COL_HOLO, 0.35), 14)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	_found_value = _stat_row(rows, "بازیکن‌های پیدا شده", "1/%d" % _need)
	rows.add_child(_divider())
	_elapsed_value = _stat_row(rows, "زمان سپری شده", "00:00")
	rows.add_child(_divider())
	_stat_row(rows, "تیم‌بندی", "%d در %d" % [_team_size, _team_size])
	stats.add_child(rows)
	col.add_child(stats)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)

	var tip := _panel(COL_PANEL, Color(COL_GOLD, 0.35), 14)
	var tip_box := VBoxContainer.new()
	tip_box.add_theme_constant_override("separation", 2)
	# C12: سرِ نکته آیکنِ همان مکانیک (tip_*.png) — نبود، فقط متن
	var tip_head_row := HBoxContainer.new()
	tip_head_row.add_theme_constant_override("separation", 8)
	tip_head_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tip_head := _label("نکته:", 17, COL_GOLD)
	tip_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tip_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip_head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tip_head_row.add_child(tip_head)
	_tip_icon = _tex(null, 40)
	tip_head_row.add_child(_tip_icon)
	tip_box.add_child(tip_head_row)
	_tip_i = randi() % TIPS.size()
	_tip_label = _label(TIPS[_tip_i], 15, COL_TEXT)
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_box.add_child(_tip_label)
	tip.add_child(tip_box)
	col.add_child(tip)
	_show_tip()
	return col


## متن و آیکنِ نکته‌ی جاری. آیکنِ رنگیِ اختصاصی همان‌طور می‌ماند؛ آیکنِ
## تک‌رنگِ HUD (جایگزین) طلایی می‌شود تا با سرِ نکته هم‌رنگ باشد.
func _show_tip() -> void:
	if _tip_label == null:
		return
	_tip_label.text = TIPS[_tip_i]
	if _tip_icon == null:
		return
	var tex := PSYCH_TIPS.icon(_tip_i)
	_tip_icon.texture = tex
	_tip_icon.visible = tex != null
	_tip_icon.modulate = Color.WHITE if PSYCH_TIPS.has_art(_tip_i) else COL_GOLD


## یک ردیفِ آمار: عدد چپ، عنوان راست. لیبلِ عدد را برمی‌گرداند.
func _stat_row(parent: Control, caption: String, value: String) -> Label:
	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	var v := _label(value, 19, COL_HOLO_HI)
	row.add_child(v)
	var cap := _label(caption, 16, COL_DIM)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(cap)
	parent.add_child(row)
	return v


func _divider() -> Control:
	var d := ColorRect.new()
	d.color = Color(COL_HOLO, 0.14)
	d.custom_minimum_size = Vector2(0, 1)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d


## نوارِ «در حال جستجو…» زیرِ دایره. دکمه نیست — فقط نشانگرِ وضعیت، پس
## لمس هم نمی‌گیرد تا کسی خیال نکند کاری انجام می‌دهد.
## V9: قبلاً قابِ درخشانِ ضخیم داشت و از دکمه‌ی واقعیِ «لغو» دکمه‌تر دیده
## می‌شد؛ حالا تخت و بی‌قاب است و زیرش نوارِ پیشرفتِ «تکمیلِ تیم» می‌آید.
func _build_search_bar() -> Control:
	var bar := _panel(Color(0.0, 0.0, 0.0, 0.0), Color(0, 0, 0, 0), 14)
	var sb := bar.get_theme_stylebox("panel") as StyleBoxFlat
	sb.set_border_width_all(0)
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(320, 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(stack)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(30, 30)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_spinner = Control.new()
	_spinner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spinner.resized.connect(func() -> void: _spinner.pivot_offset = _spinner.size * 0.5)
	_spinner.draw.connect(func() -> void:
		var c := _spinner.size * 0.5
		var r := minf(c.x, c.y) - 2.0
		_spinner.draw_arc(c, r, 0.0, TAU, 32, Color(COL_HOLO, 0.25), 3.0, true)
		_spinner.draw_arc(c, r, 0.0, TAU * 0.7, 32, COL_HOLO_HI, 3.0, true)
	)
	holder.add_child(_spinner)
	row.add_child(holder)
	_search_text = _label("در حال جستجو...", 22, COL_TEXT)
	row.add_child(_search_text)
	stack.add_child(row)

	# راست‌به‌چپ پر می‌شود؛ رنگِ رادار، و طلایی وقتی مسابقه جور شد
	_team_bar = Control.new()
	_team_bar.custom_minimum_size = Vector2(300, 6)
	_team_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_team_bar.draw.connect(func() -> void:
		var w := _team_bar.size.x
		var h := _team_bar.size.y
		_team_bar.draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.08))
		var fw := w * clampf(_team_ratio, 0.0, 1.0)
		if fw > 0.5:
			var col := COL_GOLD if _state == "ready" else COL_HOLO_HI
			_team_bar.draw_rect(Rect2(w - fw, 0, fw, h), col))
	stack.add_child(_team_bar)
	return bar


# ============================ دایره ============================

func _build_ring() -> void:
	# لایه‌ی ثابت: دیسکِ وسط، راهنمای مدار و نقطه‌ی هر صندلی
	_ring_back = Control.new()
	_ring_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ring_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring_back.draw.connect(_draw_ring_back)
	_ring_area.add_child(_ring_back)

	_ring_outer = _ring_layer("ring_outer", _draw_ring_outer)
	_ring_inner = _ring_layer("ring_inner", _draw_ring_inner)

	# محتوای وسط: کره، عنوان، توضیح، زمان
	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 0)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	_ring_area.add_child(center)

	var globe_tex := _art("globe")
	if globe_tex != null:
		var g := _tex(globe_tex, 56)
		g.material = _additive()
		_globe = g
	else:
		_globe = Control.new()
		_globe.custom_minimum_size = Vector2(52, 52)
		_globe.draw.connect(_draw_globe)
	_globe.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_globe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_globe)

	_center_title = _label("در حال جستجو", 24, COL_TEXT)
	_center_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_center_title)
	_center_sub = _label("بازیکن‌های هم‌سطحِ تو پیدا می‌شوند", 14, COL_DIM)
	_center_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_center_sub)
	_timer_label = _label("00:00", 40, COL_HOLO_HI)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_timer_label)


## یک حلقه‌ی چرخان: اگر عکسش بود TextureRect با blend=add، وگرنه نقاشیِ کدی.
## مربعی است و pivot وسطش، تا دورِ مرکزِ دایره بچرخد.
func _ring_layer(art_name: String, painter: Callable) -> Control:
	var layer: Control
	var t := _art(art_name)
	if t != null:
		var tr := TextureRect.new()
		tr.texture = t
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.material = _additive()
		layer = tr
	else:
		layer = Control.new()
		layer.draw.connect(painter.bind(layer))
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring_area.add_child(layer)
	return layer


## شعاع و اندازه‌ی عکس‌ها را از ناحیه‌ی موجود حساب می‌کند و همه چیز را
## دوباره می‌چیند. فقط با تغییرِ اندازه صدا زده می‌شود.
func _layout_ring() -> void:
	var sz := _ring_area.size
	if sz.x <= 1.0 or sz.y <= 1.0:
		return
	var c := sz * 0.5
	_avatar = clampf(minf(sz.x, sz.y) * 0.17, 54.0, 96.0)
	# بلندترین فاصله‌ی عمودی و افقیِ صندلی‌ها از مرکز (به نسبتِ شعاع). عکسِ
	# بالا و پایین نباید بیرون بزند و اسمِ کارت‌های کناری هم باید جا شود.
	var max_sin := 0.3
	var max_cos := 0.3
	for i in _slots.size():
		var a := _slot_angle(i)
		max_sin = maxf(max_sin, absf(sin(a)))
		max_cos = maxf(max_cos, absf(cos(a)))
	var r_v := (c.y - _avatar * 0.5 - 4.0) / max_sin
	var r_h := (c.x - _avatar * 0.5 - NAME_W - 14.0) / max_cos
	# خودِ حلقه هم نباید از ناحیه بزند بیرون
	_r = maxf(minf(minf(r_v, r_h), minf(c.x, c.y) - 2.0), 70.0)

	# حلقه‌ی بیرونی تا خودِ مدار می‌رود، داخلی تا ۰٫۷۶ آن
	_place_square(_ring_outer, c, _r * 1.0)
	_place_square(_ring_inner, c, _r * 0.76)
	_ring_back.queue_redraw()

	# کره و متن‌ها با اندازه‌ی دایره بزرگ و کوچک می‌شوند
	var gs := clampf(_r * 0.34, 40.0, 84.0)
	_globe.custom_minimum_size = Vector2(gs, gs)
	_timer_label.add_theme_font_size_override("font_size", int(clampf(_r * 0.24, 28.0, 52.0)))
	_center_title.add_theme_font_size_override("font_size", int(clampf(_r * 0.14, 19.0, 30.0)))

	for i in _slots.size():
		_place_slot(_slots[i], i, c)


func _place_square(layer: Control, c: Vector2, half: float) -> void:
	layer.size = Vector2(half, half) * 2.0
	layer.position = c - Vector2(half, half)
	layer.pivot_offset = Vector2(half, half)
	layer.queue_redraw()


## زاویه‌ی صندلیِ i: دایره به تعدادِ کلِ بازیکن‌ها تقسیمِ مساوی می‌شود.
##
## شروع نیم‌قدم بعد از بالاست، نه خودِ بالا: این‌طوری هیچ صندلی دقیقاً بالا
## یا پایین نمی‌افتد و همه‌ی کارت‌ها یا نیمه‌ی چپ‌اند یا راست — اسمِ کارتِ
## بالایی روی عکسِ کناری‌اش نمی‌افتد. دو نفره هم خودبه‌خود چپ و راست می‌شود
## که در صفحه‌ی افقی بیشترین جا را دارد.
func _slot_angle(i: int) -> float:
	var n := maxi(1, _slots.size())
	return -PI * 0.5 + PI / float(n) + float(i) * TAU / float(n)


func _place_slot(s: Slot, i: int, c: Vector2) -> void:
	var a := _slot_angle(i)
	var p := c + Vector2(cos(a), sin(a)) * _r
	# کارت‌های نیمه‌ی چپ اسم را سمتِ چپِ عکس می‌گذارند (رو به بیرون)
	var left := cos(a) < -0.01
	if left != s.names_left:
		s.names_left = left
		s.root.move_child(s.text_col, 0 if left else 1)
		var align := HORIZONTAL_ALIGNMENT_RIGHT if left else HORIZONTAL_ALIGNMENT_LEFT
		s.name_label.horizontal_alignment = align
		s.status.horizontal_alignment = align
		var row := s.name_label.get_parent() as HBoxContainer
		row.alignment = BoxContainer.ALIGNMENT_END if left else BoxContainer.ALIGNMENT_BEGIN
		row.move_child(s.rank, row.get_child_count() - 1 if left else 0)
	s.frame.custom_minimum_size = Vector2(_avatar, _avatar)
	s.frame.pivot_offset = Vector2(_avatar, _avatar) * 0.5
	s.style.set_corner_radius_all(int(_avatar * 0.2))
	s.mark.add_theme_font_size_override("font_size", int(_avatar * 0.5))
	s.root.reset_size()
	var ms := s.root.get_combined_minimum_size()
	var x := p.x - (ms.x - _avatar * 0.5 if left else _avatar * 0.5)
	s.root.position = Vector2(x, p.y - ms.y * 0.5)


## لایه‌ی ثابت — هاله و دیسکِ وسط، مدار و نقطه‌های صندلی
func _draw_ring_back() -> void:
	var c := _ring_back.size * 0.5
	var r := _r
	var col := _ring_tint
	for i in 10:
		var t := float(i) / 9.0
		_ring_back.draw_circle(c, r * (0.6 + t * 0.55), Color(col, 0.03 * (1.0 - t)))
	# مدارِ صندلی‌ها
	_ring_back.draw_arc(c, r, 0.0, TAU, 96, Color(col, 0.16), 1.0, true)
	# دیسکِ وسط — پشتِ متن‌ها تیره تا خوانا بمانند
	var disc := r * 0.6
	_ring_back.draw_circle(c, disc, Color(0.01, 0.03, 0.07, 0.88))
	for w in [10.0, 5.0]:
		_ring_back.draw_arc(c, disc, 0.0, TAU, 96, Color(col, 0.07 if w > 6.0 else 0.14), w, true)
	_ring_back.draw_arc(c, disc, 0.0, TAU, 96, Color(col, 0.9), 2.0, true)
	# نقطه‌ی درخشانِ بینِ هر دو صندلی روی حلقه
	var n := _slots.size()
	for i in n:
		var a := _slot_angle(i) + PI / float(maxi(n, 1))
		var p := c + Vector2(cos(a), sin(a)) * r * 0.84
		_ring_back.draw_circle(p, 7.0, Color(col, 0.18))
		_ring_back.draw_circle(p, 3.0, COL_HOLO_HI if col == COL_HOLO else col)


## حلقه‌ی بیرونیِ چرخان — درجه‌ها، سه قوسِ درخشان و جاروی رادار
func _draw_ring_outer(layer: Control) -> void:
	var c := layer.size * 0.5
	var r := _r
	var col := _ring_tint
	# درجه‌ها
	for i in 72:
		var a := float(i) * TAU / 72.0
		var major := i % 6 == 0
		var dir := Vector2(cos(a), sin(a))
		var r0 := r * 0.88
		var r1 := r0 + (r * 0.07 if major else r * 0.03)
		layer.draw_line(c + dir * r0, c + dir * r1, Color(col, 0.55 if major else 0.25), 1.5 if major else 1.0, true)
	# حلقه‌ی نازک و سه قوسِ درخشان
	var ra := r * 0.8
	layer.draw_arc(c, ra, 0.0, TAU, 96, Color(col, 0.28), 1.0, true)
	for k in 3:
		var a0 := float(k) * TAU / 3.0
		layer.draw_arc(c, ra, a0, a0 + 0.6, 24, Color(col, 0.14), 9.0, true)
		layer.draw_arc(c, ra, a0, a0 + 0.6, 24, COL_HOLO_HI if col == COL_HOLO else col, 3.0, true)
	# جاروی رادار: گُوِه‌ای که از لبه‌ی جلو پررنگ است و به عقب محو می‌شود
	var steps := 22
	var span := 0.9
	var r_in := r * 0.62
	for k in steps:
		var t := float(k) / float(steps)
		var a1 := -t * span
		var a2 := -(t + 1.0 / float(steps)) * span
		var quad := PackedVector2Array([
			c + Vector2(cos(a1), sin(a1)) * r_in, c + Vector2(cos(a1), sin(a1)) * ra,
			c + Vector2(cos(a2), sin(a2)) * ra, c + Vector2(cos(a2), sin(a2)) * r_in,
		])
		layer.draw_colored_polygon(quad, Color(col, 0.16 * (1.0 - t)))


## حلقه‌ی داخلیِ پادساعت‌گرد — خط‌چین و دو نشانگر
func _draw_ring_inner(layer: Control) -> void:
	var c := layer.size * 0.5
	var r := _r
	var col := _ring_tint
	var rd := r * 0.68
	for i in 36:
		var a := float(i) * TAU / 36.0
		layer.draw_arc(c, rd, a, a + deg_to_rad(6.0), 4, Color(col, 0.5), 2.0, true)
	layer.draw_arc(c, r * 0.73, 0.0, TAU, 80, Color(col, 0.14), 1.0, true)
	for a in [0.0, PI]:
		var dir := Vector2(cos(a), sin(a))
		var side := Vector2(-dir.y, dir.x)
		var tip := c + dir * r * 0.735
		layer.draw_colored_polygon(PackedVector2Array([
			tip, tip - dir * 7.0 + side * 5.0, tip - dir * 7.0 - side * 5.0]), Color(col, 0.9))


## کره‌ی وسط: دایره + نصف‌النهارهایی که آرام می‌لغزند تا کره بچرخد
func _draw_globe() -> void:
	var c := _globe.size * 0.5
	var r := minf(c.x, c.y) - 1.0
	var col := _ring_tint
	_globe.draw_circle(c, r, Color(col, 0.18))
	_globe.draw_arc(c, r, 0.0, TAU, 40, Color(col, 0.95), 2.0, true)
	var phase := fmod(Time.get_ticks_msec() / 1000.0 * 0.35, 1.0)
	for k in 4:
		# x-شعاعِ بیضیِ هر نصف‌النهار از -r تا r حرکت می‌کند
		var u := fmod(float(k) / 4.0 + phase, 1.0)
		var rx := r * cos(u * PI)
		var pts := PackedVector2Array()
		for j in 17:
			var a := -PI * 0.5 + float(j) * PI / 16.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * r))
		_globe.draw_polyline(pts, Color(col, 0.6), 1.2, true)
	for y in [-0.45, 0.0, 0.45]:
		var hw := r * sqrt(1.0 - y * y)
		_globe.draw_line(c + Vector2(-hw, y * r), c + Vector2(hw, y * r), Color(col, 0.5), 1.0, true)


func _draw_ping_bars() -> void:
	var s := _ping_dot.size
	var bars := 0
	if _ping_colour == COL_OK:
		bars = 3
	elif _ping_colour == COL_WARN:
		bars = 2
	elif _ping_colour == COL_FOE:
		bars = 1
	for i in 3:
		var h := s.y * (0.35 + 0.3 * float(i))
		var rect := Rect2(float(i) * s.x / 3.0 + 1.0, s.y - h, s.x / 3.0 - 2.0, h)
		_ping_dot.draw_rect(rect, _ping_colour if i < bars else Color(1, 1, 1, 0.15))


func _draw_back_arrow(ctl: Control) -> void:
	var c := ctl.size * 0.5
	var w := minf(ctl.size.x, ctl.size.y) * 0.22
	var col := COL_TEXT
	ctl.draw_line(c + Vector2(w, 0), c + Vector2(-w, 0), col, 3.0, true)
	ctl.draw_line(c + Vector2(-w, 0), c + Vector2(-w * 0.2, -w * 0.8), col, 3.0, true)
	ctl.draw_line(c + Vector2(-w, 0), c + Vector2(-w * 0.2, w * 0.8), col, 3.0, true)


# ============================ صندلی‌ها ============================

func _rebuild_slots(n: int) -> void:
	for s in _slots:
		s.root.queue_free()
	_slots.clear()
	for i in n:
		var s := _make_slot()
		_slots.append(s)
		_ring_area.add_child(s.root)
		_set_slot(s, {}, false)
	_update_found()
	_layout_ring()


func _make_slot() -> Slot:
	var s := Slot.new()
	s.root = HBoxContainer.new()
	s.root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	s.root.add_theme_constant_override("separation", 10)
	s.root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# قابِ عکس: پنلِ گرد + عکس + علامت + نشانِ سطح در گوشه
	s.frame = Control.new()
	s.frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.root.add_child(s.frame)

	s.frame_bg = Panel.new()
	s.frame_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.frame_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.style = StyleBoxFlat.new()
	s.style.set_border_width_all(2)
	s.style.anti_aliasing = true
	s.frame_bg.add_theme_stylebox_override("panel", s.style)
	s.frame.add_child(s.frame_bg)

	s.art = TextureRect.new()
	s.art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	s.art.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.art.offset_left = 4.0
	s.art.offset_top = 4.0
	s.art.offset_right = -4.0
	s.art.offset_bottom = -4.0
	s.art.clip_contents = true
	s.art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.frame.add_child(s.art)

	s.mark = _label("?", 34, COL_DIM)
	s.mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	s.frame.add_child(s.mark)

	s.level_badge = PanelContainer.new()
	s.level_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	s.level_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	s.level_badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	s.level_badge.offset_right = 6.0
	s.level_badge.offset_bottom = 6.0
	s.level_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lb := StyleBoxFlat.new()
	lb.bg_color = Color(0.06, 0.05, 0.02, 0.95)
	lb.set_corner_radius_all(9)
	lb.set_border_width_all(1)
	lb.border_color = COL_GOLD
	lb.content_margin_left = 5.0
	lb.content_margin_right = 5.0
	lb.content_margin_top = -1.0
	lb.content_margin_bottom = -1.0
	s.level_badge.add_theme_stylebox_override("panel", lb)
	s.level_label = _label("1", 14, COL_GOLD)
	s.level_badge.add_child(s.level_label)
	s.frame.add_child(s.level_badge)

	# ستونِ اسم و وضعیت
	s.text_col = VBoxContainer.new()
	s.text_col.custom_minimum_size = Vector2(NAME_W, 0)
	s.text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.text_col.add_theme_constant_override("separation", -2)
	s.text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.root.add_child(s.text_col)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 4)
	name_row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	s.rank = TextureRect.new()
	s.rank.custom_minimum_size = Vector2(22, 22)
	s.rank.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.rank.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	s.rank.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(s.rank)
	s.name_label = _label("", 17, COL_TEXT)
	s.name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	s.name_label.clip_text = true
	name_row.add_child(s.name_label)
	s.text_col.add_child(name_row)

	s.status = _label("", 14, COL_HOLO)
	s.text_col.add_child(s.status)
	return s


## نقش در لحظه‌ی آماده: me / ally / foe. در حالِ جستجو هنوز تیمی نیست.
func _set_slot(s: Slot, p: Dictionary, animate: bool, role := "") -> void:
	var uname := str(p.get("username", ""))
	var was_empty := s.username == ""
	var changed := uname != s.username
	s.username = uname

	if uname == "":
		s.style.bg_color = Color(0.02, 0.05, 0.10, 0.75)
		s.style.border_color = Color(COL_HOLO, 0.28)
		s.style.shadow_size = 0
		s.art.texture = null
		s.art.visible = false
		s.mark.text = "?"
		s.mark.add_theme_color_override("font_color", Color(COL_HOLO, 0.7))
		s.mark.visible = true
		s.level_badge.visible = false
		s.rank.texture = null
		s.rank.visible = false
		s.name_label.text = "در انتظار..."
		s.name_label.add_theme_color_override("font_color", COL_DIM)
		# متنِ خالی به‌جای مخفی کردن: ارتفاعِ کارت ثابت می‌ماند و عکس از
		# جای خودش روی مدار تکان نمی‌خورد
		s.status.text = ""
		return

	var is_me: bool = uname == Global.my_username
	var colour := COL_HOLO
	var status_text := "متصل"
	if is_me:
		colour = COL_GOLD
		status_text = "تو"
	if role == "ally":
		colour = COL_ALLY
		status_text = "هم‌تیمی"
	elif role == "foe":
		colour = COL_FOE
		status_text = "حریف"

	s.frame.modulate.a = 1.0
	s.style.bg_color = Color(0.03, 0.07, 0.13, 0.95)
	s.style.border_color = colour
	s.style.shadow_color = Color(colour, 0.45)
	s.style.shadow_size = 8
	s.frame_bg.queue_redraw()

	var tex := _profile_texture(p)
	s.art.texture = tex
	s.art.visible = tex != null
	s.mark.visible = tex == null
	s.mark.text = _initial(uname)
	s.mark.add_theme_color_override("font_color", colour)

	var level := int(p.get("level", 0))
	s.level_badge.visible = level > 0
	s.level_label.text = str(level)

	var rank_tex: Texture2D = null
	if p.has("rank_id") or p.has("rank_name"):
		rank_tex = RankArt.texture_for(str(p.get("rank_id", "")), str(p.get("rank_name", "")))
	s.rank.texture = rank_tex
	s.rank.visible = rank_tex != null

	s.name_label.text = uname
	s.name_label.add_theme_color_override("font_color", COL_TEXT)
	s.status.text = status_text
	s.status.add_theme_color_override("font_color", colour)

	# پروفایلِ تازه با یک «پاپ» وارد می‌شود — تنها حرکتِ صندلی‌ها
	if animate and (was_empty or changed):
		s.frame.scale = Vector2(0.4, 0.4)
		var tw := s.frame.create_tween()
		tw.tween_property(s.frame, "scale", Vector2.ONE, 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _slot_of(uname: String) -> Slot:
	for s in _slots:
		if s.username == uname:
			return s
	return null


## صندلیِ اول از همان لحظه‌ی اول مالِ خودِ بازیکن است، قبل از جوابِ سرور
func _fill_me_placeholder() -> void:
	if _slots.is_empty() or Global.my_username == "":
		return
	_set_slot(_slots[0], {
		"username": Global.my_username,
		"avatar_id": Global.avatar_id,
		"character": Global.current_character,
		"level": Global.level,
	}, false)
	_update_found()


## لیستِ بازیکن‌ها را روی صندلی‌ها می‌نشاند بدون اینکه کسی جابه‌جا شود.
## roles: username -> me/ally/foe (فقط در لحظه‌ی آماده).
func _apply_roster(players: Array, roles: Dictionary = {}) -> void:
	var by_name := {}
	for p in players:
		if p is Dictionary and str(p.get("username", "")) != "":
			by_name[str(p["username"])] = p

	# کسی که از صف رفته، صندلی‌اش خالی می‌شود
	for s in _slots:
		if s.username != "" and not by_name.has(s.username):
			_set_slot(s, {}, false)

	# صندلیِ اول همیشه مالِ خودم
	var me: String = Global.my_username
	if by_name.has(me):
		_set_slot(_slots[0], by_name[me], false, roles.get(me, ""))

	for uname in by_name:
		if uname == me:
			continue
		var s := _slot_of(uname)
		if s != null:
			_set_slot(s, by_name[uname], false, roles.get(uname, ""))
			continue
		for i in range(1, _slots.size()):
			if _slots[i].username == "":
				_set_slot(_slots[i], by_name[uname], true, roles.get(uname, ""))
				break

	_update_found()


func _update_found() -> void:
	var filled := 0
	for s in _slots:
		if s.username != "":
			filled += 1
	_found_value.text = "%d/%d" % [filled, _slots.size()]


## آواتارِ واقعی اگر بود، وگرنه آرتِ کاراکتر، وگرنه هیچ (حرفِ اول نشان داده می‌شود).
func _profile_texture(p: Dictionary) -> Texture2D:
	var avatar := AvatarPicker.load_avatar_texture(str(p.get("avatar_id", "")))
	if avatar != null:
		return avatar
	var character := str(p.get("character", ""))
	var char_path := "%s/%s.png" % [ITEMS_DIR, character]
	if character != "" and ResourceLoader.exists(char_path):
		return load(char_path)
	return null


static func _initial(who: String) -> String:
	var t := who.strip_edges()
	return t.substr(0, 1).to_upper() if t.length() > 0 else "؟"


# ============================ شبکه ============================

func _join_queue() -> void:
	var body := JSON.stringify({
		"username": Global.my_username,
		"mode_id": str(_mode.get("mode_id", "")),
	})
	var err := _http_join.request(Global.SERVER_BASE + "/matchmaking/join",
		Global.json_headers(), HTTPClient.METHOD_POST, body)
	if err != OK:
		_set_center("اتصال ممکن نشد", "اینترنت را بررسی کن", COL_FOE)


func _on_joined(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_set_center("اتصال ممکن نشد", "در حال تلاشِ دوباره...", COL_FOE)
		_join_retry()
		return
	var d = JSON.parse_string(body.get_string_from_utf8())
	if code != 200:
		var msg := "ورود به صف ممکن نشد"
		if typeof(d) == TYPE_DICTIONARY and d.has("error"):
			msg = str(d["error"])
		_show_dropped(msg)
		return
	if typeof(d) == TYPE_DICTIONARY:
		var need := int(d.get("need", _need))
		if need > 0 and need != _slots.size():
			_need = need
			_rebuild_slots(need)
		if d.get("you") is Dictionary:
			_apply_roster([d["you"]])
	_poll_status()


## اینترنتِ موبایل ناپایدار است؛ اگر ورود به صف شکست خورد، چند ثانیه بعد
## دوباره تلاش می‌کنیم به‌جای اینکه صفحه گیر کند.
func _join_retry() -> void:
	var t := get_tree().create_timer(2.0)
	t.timeout.connect(func() -> void:
		if is_inside_tree() and _state == "searching":
			_join_queue())


func _poll_status() -> void:
	if _http_poll.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return    # درخواستِ قبلی هنوز تمام نشده
	_poll_sent_ms = Time.get_ticks_msec()
	_http_poll.request("%s/matchmaking/status?username=%s" % [
		Global.SERVER_BASE, Global.my_username.uri_encode()], Global.auth_headers())


func _on_status(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail_count += 1
		if _fail_count >= 3:
			_set_ping(-1)
			if _state == "searching":
				_center_sub.text = "اتصال ضعیف است، در حال تلاش..."
				_center_sub.add_theme_color_override("font_color", COL_WARN)
		return
	if _fail_count >= 3 and _state == "searching":
		_center_sub.text = "بازیکن‌های هم‌سطحِ تو پیدا می‌شوند"
		_center_sub.add_theme_color_override("font_color", COL_DIM)
	_fail_count = 0
	# زمانِ رفت‌وبرگشتِ همین درخواست = پینگِ واقعی تا سرور
	_set_ping(Time.get_ticks_msec() - _poll_sent_ms)

	var d = JSON.parse_string(body.get_string_from_utf8())
	if typeof(d) != TYPE_DICTIONARY:
		return

	# پاسخِ دیرهنگام را دور بینداز: اگر بازیکن همین بین جستجو را لغو کرده،
	# نباید یک پاسخِ در راه صفحه را به حالتِ جستجو برگرداند.
	if _state != "searching":
		return

	var server_state := str(d.get("state", "searching"))
	if server_state == "ready":
		var match_data: Dictionary = d.get("match", {})
		_on_match_ready(match_data)
	elif server_state == "searching":
		var need := int(d.get("need", _need))
		if need > 0 and need != _slots.size():
			_need = need
			_rebuild_slots(need)
		var roster: Array = d.get("players", [])
		_apply_roster(roster)
		# سرور ۱۵ ثانیه فقط دنبالِ هم‌سطح (±۲۰۰ کاپ) می‌گردد، بعد هر آدمِ صف را
		# کنارت می‌نشاند و سرِ ۲۰ ثانیه صندلی‌های خالی را با بات پر می‌کند.
		# لیست فقط کسانی است که واقعاً با تو می‌افتند (سرورِ جدید)، پس اگر
		# آدمی پیدا شده نباید بگوییم «هم‌سطحی پیدا نشد».
		_bots_at = maxf(float(d.get("bots_at", 20)), 1.0)
		_server_waited = float(d.get("waited", 0))
		_waited_sync = _elapsed
		var others := maxi(roster.size() - 1, 0)
		var left := maxi(int(d.get("bots_at", 20)) - int(d.get("waited", 0)), 0)
		if str(d.get("phase", "human")) == "bots":
			if others > 0:
				_center_sub.text = "%d بازیکن پیدا شد — بقیه‌ی تیم تا %d ثانیه‌ی دیگر" % [others, left]
			else:
				_center_sub.text = "هم‌سطحی پیدا نشد — تکمیلِ تیم تا %d ثانیه‌ی دیگر" % left
		elif others > 0:
			_center_sub.text = "%d بازیکن پیدا شد — در انتظارِ بقیه" % others
		else:
			_center_sub.text = "بازیکن‌های هم‌سطحِ تو پیدا می‌شوند"
	else:
		# سرور می‌گوید در صف نیستیم (مثلاً ری‌استارت شده)
		_show_dropped("از صف بیرون آمدی")


func _on_match_ready(match_data: Dictionary) -> void:
	_state = "ready"
	Global.current_match = match_data
	# تیمِ خودمان را نگه می‌داریم تا زمینِ بازی بداند برد و باخت را چطور نشان بدهد
	Global.my_team = _my_team_from(match_data)

	var players: Array = match_data.get("players", [])
	var roles := {}
	for p in players:
		if p is Dictionary:
			var u := str(p.get("username", ""))
			if u == Global.my_username:
				roles[u] = "me"
			else:
				roles[u] = "ally" if str(p.get("team", "")) == Global.my_team else "foe"
	if players.size() != _slots.size() and players.size() > 0:
		_rebuild_slots(players.size())
	_apply_roster(players, roles)

	_set_center("حریف پیدا شد!", "ورود به میدان...", COL_GOLD)
	_search_text.text = "حریف پیدا شد!"
	_search_text.add_theme_color_override("font_color", COL_GOLD)
	_spinner.visible = false
	_team_ratio = 1.0
	if _team_bar != null:
		_team_bar.queue_redraw()
	_tint_ring(COL_GOLD)
	# دیگر راهِ برگشتی نیست؛ دکمه نباید «لغو» بماند
	_set_action("در حال ورود...", COL_GOLD)
	_action_button.disabled = true
	LocalSettings.vibrate(60)
	# E8: یک مسابقه با اسلحه و کاراکترِ فعلی (آمارِ شخصیِ صفحه‌ی انتخاب)
	PSYCH_LOADOUT.record_match()
	_enter_arena()


func _set_ping(ms: int) -> void:
	if ms < 0:
		_ping_label.text = "قطع"
		_ping_colour = COL_FOE
	else:
		_ping_label.text = "%dms" % ms
		_ping_colour = COL_OK if ms < 90 else (COL_WARN if ms < 180 else COL_FOE)
	_ping_label.add_theme_color_override("font_color", _ping_colour)
	_ping_dot.queue_redraw()


## دکمه‌ی اصلی: در حال جستجو یعنی «لغو» و برگشت به منوی اصلی؛ اگر از صف
## افتاده باشیم یعنی «دوباره جستجو کن».
func _on_action_pressed() -> void:
	match _state:
		"searching":
			_leave_to_menu()
		"dropped":
			_start_search()


## دیگر در صف نیستیم. به‌جای بن‌بست، امکانِ جستجوی دوباره.
func _show_dropped(reason: String) -> void:
	_state = "dropped"
	_elapsed = 0.0
	_timer_label.text = "00:00"
	_elapsed_value.text = "00:00"
	_apply_roster([])
	_fill_me_placeholder()
	_set_center(reason, "برای ادامه «جستجوی دوباره» را بزن", COL_DIM)
	_search_text.text = "جستجو متوقف شد"
	_search_text.add_theme_color_override("font_color", COL_DIM)
	_spinner.visible = false
	_team_ratio = 0.0
	_server_waited = -1.0
	if _team_bar != null:
		_team_bar.queue_redraw()
	_set_action("جستجوی دوباره", COL_GOLD)
	_action_button.disabled = false


func _start_search() -> void:
	_state = "searching"
	_elapsed = 0.0
	_dots = -1
	_poll_cd = POLL_EVERY
	_set_center("در حال جستجو", "بازیکن‌های هم‌سطحِ تو پیدا می‌شوند", COL_TEXT)
	_search_text.text = "در حال جستجو..."
	_search_text.add_theme_color_override("font_color", COL_TEXT)
	_spinner.visible = true
	_team_ratio = 0.0
	_server_waited = -1.0
	_tint_ring(COL_HOLO)
	_set_action("لغو جستجو", COL_FOE)
	_action_button.disabled = false
	_join_queue()


func _set_center(title: String, sub: String, colour: Color) -> void:
	_center_title.text = title
	_center_title.add_theme_color_override("font_color", colour)
	_center_sub.text = sub
	_center_sub.add_theme_color_override("font_color", COL_DIM)
	_timer_label.add_theme_color_override("font_color", COL_GOLD if colour == COL_GOLD else COL_HOLO_HI)


## رنگِ رادار. نسخه‌ی کدی دوباره کشیده می‌شود؛ عکس‌ها با modulate روشن‌تر
## می‌شوند ولی رنگشان حفظ می‌شود (ضربِ آبی در طلایی رنگِ کدری می‌سازد).
func _tint_ring(colour: Color) -> void:
	_ring_tint = colour
	for layer in [_ring_back, _ring_outer, _ring_inner, _globe]:
		if layer is TextureRect:
			layer.modulate = Color(1.25, 1.25, 1.25) if colour == COL_GOLD else Color.WHITE
		elif layer != null:
			layer.queue_redraw()


func _leave_queue() -> void:
	if Global.my_username == "":
		return
	_http_leave.cancel_request()
	_http_leave.request(Global.SERVER_BASE + "/matchmaking/leave",
		Global.json_headers(), HTTPClient.METHOD_POST,
		JSON.stringify({"username": Global.my_username}))


## تیمِ خودم در این مسابقه («0» یا «1»)
func _my_team_from(match_data: Dictionary) -> String:
	for p in match_data.get("players", []):
		if p is Dictionary and str(p.get("username", "")) == Global.my_username:
			return str(p.get("team", ""))
	return ""


## ورود به زمینِ بازی — با مکثی کوتاه تا بازیکن همه را ببیند.
func _enter_arena() -> void:
	if _entering:
		return
	_entering = true
	var t := get_tree().create_timer(ENTER_DELAY)
	t.timeout.connect(func() -> void:
		LoadingScreen.change_scene("res://secense/World.tscn"))


func _leave_to_menu() -> void:
	# خروج از صف را _exit_tree می‌فرستد؛ اینجا فقط صحنه عوض می‌شود
	get_tree().change_scene_to_file("res://secense/main_menu.tscn")


## متن و رنگِ دکمه‌ی اصلی. استایل‌باکس‌ها رنگ را داخل خودشان دارند، پس از
## نو ساخته می‌شوند.
func _set_action(text: String, colour: Color) -> void:
	if _action_button == null:
		return
	_action_button.text = text
	_style_button(_action_button, colour)


func _exit_tree() -> void:
	# اگر صفحه بسته شد، صف را هم ترک کن تا جای کسی را اشغال نکنیم.
	# درخواست روی Global ساخته می‌شود: اینجا root مشغولِ عوض‌کردنِ صحنه است و
	# add_child رویش شکست می‌خورد، پس «ترک صف» هیچ‌وقت به سرور نمی‌رسید و
	# بازیکن به‌صورت روح در صف می‌ماند.
	if _state == "searching" and Global.my_username != "":
		Global.post_detached("/matchmaking/leave", {"username": Global.my_username})


# ============================ ابزار ============================

func _art(art_name: String) -> Texture2D:
	var path := ART_DIR + art_name + ".png"
	return load(path) if ResourceLoader.exists(path) else null


## blend=add: سیاهِ عکس شفاف می‌شود و فقط نور می‌ماند
func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _tex(t: Texture2D, px: int) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = t
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _panel(bg: Color, border: Color, radius: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	p.add_theme_stylebox_override("panel", sb)
	return p


## دکمه‌ی مربعیِ آیکن‌دار (برگشت). آیکن با کد کشیده می‌شود.
func _icon_button(painter: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(TOUCH_H, TOUCH_H)
	_style_button(b, COL_HOLO)
	var icon := Control.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(painter.bind(icon))
	b.add_child(icon)
	UIFx.bind_press_feedback(b)
	return b


func _button(text: String, colour: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 20)
	_style_button(b, colour)
	return b


## حالتِ pressed واضح (پرِ رنگ) — روی تاچ hover نداریم
func _style_button(b: Button, colour: Color) -> void:
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", COL_TEXT)
	b.add_theme_color_override("font_focus_color", COL_TEXT)
	b.add_theme_color_override("font_pressed_color", Color(0.05, 0.05, 0.06))
	b.add_theme_color_override("font_disabled_color", Color(colour, 0.8))
	for state in ["normal", "hover", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.03, 0.05, 0.09, 0.9)
		s.set_corner_radius_all(12)
		s.set_border_width_all(2)
		s.border_color = Color(colour, 0.5) if state == "disabled" else colour
		s.content_margin_left = 18.0
		s.content_margin_right = 18.0
		b.add_theme_stylebox_override(state, s)
	var sp := StyleBoxFlat.new()
	sp.bg_color = colour
	sp.set_corner_radius_all(12)
	b.add_theme_stylebox_override("pressed", sp)
