extends CanvasLayer
## آموزشِ بارِ اول (autoload با نام Tutorial).
##
## «سارا»، مربیِ بازی، از پایینِ صفحه بالا می‌آید و بازیکن را قدم‌به‌قدم
## می‌برد: انتخابِ کاراکتر ← انتخابِ اسلحه ← برگشت و شروعِ بازیِ سریع ←
## معرفیِ جان، تیر، لیزر، هم‌تیمی‌ها، بمب، سپر و جوی‌استیک.
##
## تا آموزش تمام نشده، یک پرده‌ی تیره روی همه‌چیز است و فقط «سوراخِ روشن»
## (همان چیزی که باید لمس شود) لمس را به صحنه‌ی زیرش می‌رساند. پایانش روی
## دستگاه ذخیره می‌شود و دیگر هیچ‌وقت اجرا نمی‌شود.
##
## صحنه‌ها فقط با Tutorial.notify(event) خبر می‌دهند و با is_running()
## می‌پرسند؛ ترتیبِ قدم‌ها و برگشتن سرِ قدمِ درست (مثلاً اگر بازیکن با Back
## از صفحه‌ی انتخاب بیرون زد) همه این‌جاست.

signal finished

const SAVE_PATH := "user://tutorial.cfg"
const WOMAN_TEX := preload("res://assets/TuturialWoman.png")
const FONT := preload("res://fonts/Lalezar-Regular.ttf")

const SCENE_MENU := "res://secense/main_menu.tscn"
const SCENE_SELECT := "res://secense/character_select_screen.tscn"
const SCENE_GAME := "res://secense/quick_play.tscn"

const COL_PANEL := Color(0.045, 0.035, 0.045, 0.96)
const COL_GOLD := Color(0.96, 0.78, 0.3)
const COL_RED := Color(0.72, 0.08, 0.13)
const COL_TEXT := Color(0.97, 0.95, 0.9)
const COL_DIM := Color(0.74, 0.70, 0.66)

## واحدِ طراحی: ارتفاعِ ۷۲۰ — همه‌ی اندازه‌ها با ارتفاعِ واقعی بزرگ/کوچک می‌شوند
const DESIGN_H := 720.0
## حرف بر ثانیه
const TYPE_SPEED := 45.0
## چند ثانیه جوی‌استیک باید تکان بخورد تا قدمش تمام شود
const MOVE_NEEDED := 1.3
## اگر کارتی نرسید (سرور در دسترس نیست)، بعد از این مدت قدم با لمس رد می‌شود
const CARDS_FALLBACK_SEC := 7.0

## wait: tap (لمسِ هر جا) | event (خبر از صحنه) | scene (رفتن به صحنه‌ی بعد) | move (جوی‌استیک)
##       | do (خودِ بازیکن دکمه را می‌زند و صحنه خبر می‌دهد؛ اگر نشد بعد از مدتی لمس)
##
## C7 داربست‌گذاری / C1 بار شناختی: هر قدم فقط یک چیز، جمله‌ها کوتاه.
## در زمین تمرین اول «راه رفتن» با انجام دادن یاد داده می‌شود (مهم‌ترین
## مکانیک)، بعد دکمه‌ها یکی‌یکی. دو قدمِ معرفی و جان/تیر ادغام شده‌اند.
const STEPS := [
	{"scene": SCENE_MENU, "wait": "tap", "target": "",
		"text": "سلام رفیق! من سارام، مربیِ این‌جا. چند تا چیزِ ساده رو با هم می‌بینیم؛ زود تموم میشه."},
	{"scene": SCENE_MENU, "wait": "scene", "target": "select_btn",
		"text": "اول یه کاراکتر لازم داری. این دکمه رو بزن."},
	{"scene": SCENE_SELECT, "wait": "event", "event": "character_picked", "target": "cards",
		"text": "هر کاراکتری که بازه و به دلت نشست رو لمس کن."},
	{"scene": SCENE_SELECT, "wait": "tap", "target": "",
		"text": "ایول، انتخابِ خوبی بود! حالا یه اسلحه هم لازم داری."},
	{"scene": SCENE_SELECT, "wait": "event", "event": "category_weapon", "target": "weapon_tab",
		"text": "بزن روی تبِ «سلاح‌ها»."},
	{"scene": SCENE_SELECT, "wait": "event", "event": "weapon_picked", "target": "cards",
		"text": "یکی رو انتخاب کن. بعداً هر وقت خواستی عوضش می‌کنی."},
	{"scene": SCENE_SELECT, "wait": "scene", "target": "home",
		"text": "تیپت تکمیله! با این دکمه برگرد منوی اصلی."},
	{"scene": SCENE_MENU, "wait": "scene", "target": "play_btn",
		"text": "بزن این‌جا تا بریم زمینِ تمرین."},
	{"scene": SCENE_GAME, "wait": "tap", "target": "",
		"text": "اینم زمینِ تمرین! تا من حرف می‌زنم هیچ دشمنی نمیاد."},
	{"scene": SCENE_GAME, "wait": "move", "target": "joystick",
		"text": "اول راه رفتن: شستت رو روی جوی‌استیک بذار و یه کم این‌ور اون‌ور برو."},
	{"scene": SCENE_GAME, "wait": "tap", "target": "profile",
		"text": "نوارِ قرمز جونته، آبیِ زیرش تیرهات. شلیک و پر کردنِ خشاب خودکاره."},
	# C7 یادگیری با انجام دادن: سه توانایی را خودِ بازیکن می‌زند (wait=do)؛
	# اگر خبرش نرسید، بعد از DO_FALLBACK_SEC با لمس هم رد می‌شود
	{"scene": SCENE_GAME, "wait": "do", "event": "ability_laser", "target": "btn_laser",
		"praise": "آفرین! دیدی چه کرد؟",
		"text": "این دکمه‌ی بزرگ لیزره: هر کی جلوش باشه رو می‌سوزونه. بزنش ببینم!"},
	{"scene": SCENE_GAME, "wait": "do", "event": "ability_bomb", "target": "btn_bomb",
		"praise": "ایول! پرتابِ تمیزی بود.",
		"text": "بمب: انگشتت رو روش بذار، بکش و ول کن. امتحانش کن!"},
	{"scene": SCENE_GAME, "wait": "do", "event": "ability_guard", "target": "btn_guard",
		"praise": "عالی! حالا رگبار هم حریفت نیست.",
		"text": "سپر: زیرِ رگبار بزنش؛ چند ثانیه تیر بهت کارگر نیست. بزنش!"},
	{"scene": SCENE_GAME, "wait": "tap", "target": "btn_team_heal",
		"text": "معجونِ سبز جونِ خودت و هم‌تیمی‌هات رو پر می‌کنه."},
	{"scene": SCENE_GAME, "wait": "tap", "target": "round",
		"text": "این بالا تعدادِ زنده‌های دو تیم رو می‌بینی."},
	{"scene": SCENE_GAME, "wait": "tap", "target": "",
		"text": "کارت عالی بود! بقیه‌ش با بازی دستت میاد. برو که بترکونی!"},
]
const STEP_SELECT_BTN := 1
const STEP_SELECT := 2
const STEP_WEAPON_TAB := 4
const STEP_HOME := 6
const STEP_PLAY := 7
const STEP_GAME := 8
const STEP_JOYSTICK := 9

## C7 بازیکنِ برگشتی (یا کسی که بلد است) می‌تواند آموزش را رد کند — با دو لمس
## (C13 پیشگیری از خطا) تا اشتباهی رد نشود
const SKIP_CONFIRM_SEC := 3.0
## قدمِ «انجامش بده»: اگر خبرِ توانایی تا این مدت نرسید (دکمه آماده نبود، صحنه
## خبر نداد)، لمسِ هر جا هم قدم را رد می‌کند — بازیکن هیچ‌وقت گیر نمی‌کند
const DO_FALLBACK_SEC := 8.0
## دکمه‌ی هدف اصلاً پیدا نشد: زودتر به لمس برگرد
const DO_MISSING_SEC := 1.2
## بعد از انجام دادن، کمی صبر تا بازیکن افکت را ببیند و «آفرین» را بخواند
const DO_PRAISE_SEC := 0.9

var _running := false
var _step := -1
var _scene: Node = null
## صحنه عوض شده ولی هنوز آماده‌ی نشان دادن نیست (لودینگ، HUD ساخته نشده)
var _scene_ready := false
var _settle := 0.0
var _step_time := 0.0
var _input_lock := 0.0
var _moved := 0.0
var _fallback_tap := false
## قدمِ do انجام شد و منتظرِ رفتن به قدمِ بعدیم
var _praising := false
var _ending := false

var _root: Control
var _spot: Spot
var _woman: TextureRect
var _bubble: PanelContainer
var _name_pill: PanelContainer
var _name_label: Label
var _body: Label
var _hint: Label
var _skip: Button
## زمانِ باقی‌مانده برای لمسِ دوم «رد کردن»
var _skip_armed := 0.0

var _side := "right"
var _woman_in := false
## ۰ یعنی سرِ جایش، ۱ یعنی کامل زیرِ لبه‌ی پایین
var woman_drop := 1.0
var _woman_tween: Tween
var _bubble_tween: Tween
var _typing := false
var _type_pos := 0.0
var _t := 0.0


## اگر سرور تا این مدت جواب نداد، از روی کشِ گوشی تصمیم می‌گیریم
const SERVER_WAIT_SEC := 8.0

var _decided := false


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	# «تمام شده» مالِ حساب است (سرور)، نه گوشی. پس تا دیتای بازیکن نرسیده
	# تصمیم نمی‌گیریم؛ فایلِ گوشی فقط کشی است برای وقتی سرور در دسترس نیست.
	Global.player_data_loaded.connect(_on_player_loaded)
	get_tree().create_timer(SERVER_WAIT_SEC).timeout.connect(_on_server_timeout)


func _on_player_loaded() -> void:
	if Global.tutorial_done:
		_decided = true
		_save_local_done(true)
		return
	if _decided:
		return
	_decided = true
	_start()


func _on_server_timeout() -> void:
	if _decided or Global._player_loaded_once:
		return
	_decided = true
	if not _local_done():
		_start()


func _start() -> void:
	if _running or _ending:
		return
	_running = true
	_build()
	_set_overlay_visible(false)
	set_process(true)


## کشِ گوشی، به تفکیکِ حساب — حسابِ تازه روی همان گوشی هم آموزش را می‌بیند
func _local_done() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	return bool(cfg.get_value("done", Global._session_key(str(Global.my_username)), false))


func _save_local_done(done: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("done", Global._session_key(str(Global.my_username)), done)
	cfg.save(SAVE_PATH)


## پایانِ آموزش روی حساب ثبت می‌شود
func _send_done_to_server() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		http.queue_free()
		if code == 200:
			Global.tutorial_done = true)
	var body := JSON.stringify({"username": Global.my_username})
	if http.request(Global.SERVER_BASE + "/tutorial/done", Global.json_headers(),
			HTTPClient.METHOD_POST, body) != OK:
		http.queue_free()


# ============================ API ============================

## تا آموزش تمام نشده true است — صحنه‌ها با این قفل‌ها را می‌گذارند
func is_running() -> bool:
	return _running


## صحنه‌ها خبر می‌دهند: character_picked، weapon_picked، category_weapon، ...
## HUD برای توانایی‌ها ability_laser / ability_bomb / ability_guard می‌فرستد.
func notify(event: String) -> void:
	if not _running or not _scene_ready or _step < 0 or _ending or _praising:
		return
	# دکمه‌ی سپر در HUD آیکنِ shield دارد؛ هر دو اسم قبول است
	if event == "ability_shield":
		event = "ability_guard"
	var st: Dictionary = STEPS[_step]
	if st.get("event", "") != event:
		return
	if st.wait == "event":
		_advance()
	elif st.wait == "do":
		_praise_then_advance(str(st.get("praise", "")))


## C7/E17 انجامش داد: یک «آفرین» کوتاه روی حباب، چند لحظه تماشای افکت، بعد قدمِ بعد
func _praise_then_advance(text: String) -> void:
	_praising = true
	_input_lock = DO_PRAISE_SEC + 0.2
	_spot.pass_through = false
	LocalSettings.vibrate(25)
	if text != "":
		_typing = false
		_body.text = text
		_body.visible_characters = -1
		_hint.text = ""
		_name_pill.pivot_offset = _name_pill.size * 0.5
		var tw := create_tween()
		tw.tween_property(_name_pill, "scale", Vector2(1.18, 1.18), 0.1)
		tw.tween_property(_name_pill, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	var step_at := _step
	get_tree().create_timer(DO_PRAISE_SEC).timeout.connect(func() -> void:
		_praising = false
		# در این فاصله صحنه عوض شده یا آموزش رد شده: کاری نکن
		if _running and not _ending and _scene_ready and _step == step_at:
			_advance())


## فقط برای تست: آموزش دوباره از اول اجرا شود
func reset() -> void:
	_save_local_done(false)


# ============================ ساخت ============================

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_spot = Spot.new()
	_spot.name = "Spot"
	_spot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spot.tapped.connect(_on_tap)
	_root.add_child(_spot)

	_woman = TextureRect.new()
	_woman.name = "Instructor"
	_woman.texture = WOMAN_TEX
	_woman.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_woman.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_woman.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_woman)

	_bubble = PanelContainer.new()
	_bubble.name = "Bubble"
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.set_border_width_all(3)
	sb.border_color = COL_GOLD
	sb.border_width_right = 8
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	sb.content_margin_left = 22.0
	sb.content_margin_right = 26.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	_bubble.add_theme_stylebox_override("panel", sb)
	_root.add_child(_bubble)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	_bubble.add_child(col)

	_name_pill = PanelContainer.new()
	_name_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_pill.size_flags_horizontal = Control.SIZE_SHRINK_END
	var pill := StyleBoxFlat.new()
	pill.bg_color = COL_RED
	pill.set_corner_radius_all(10)
	pill.set_border_width_all(1)
	pill.border_color = COL_GOLD
	pill.content_margin_left = 14.0
	pill.content_margin_right = 14.0
	pill.content_margin_top = 0.0
	pill.content_margin_bottom = 2.0
	_name_pill.add_theme_stylebox_override("panel", pill)
	col.add_child(_name_pill)
	_name_label = _make_label("سارا · مربی", COL_GOLD)
	_name_pill.add_child(_name_label)

	_body = _make_label("", COL_TEXT)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_body)

	_hint = _make_label("", COL_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(_hint)

	_build_skip()


## دکمه‌ی «رد کردن آموزش» — گوشه‌ی بالا، بیرون از سوراخ؛ عمداً کم‌رنگ‌تر از
## هدفِ اصلی (V5: فقط یک چیز برجسته است)
func _build_skip() -> void:
	_skip = Button.new()
	_skip.name = "SkipButton"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip.text = "رد کردن آموزش"
	_skip.text_direction = Control.TEXT_DIRECTION_RTL
	_skip.add_theme_font_override("font", FONT)
	_skip.add_theme_color_override("font_color", COL_DIM)
	_skip.add_theme_color_override("font_pressed_color", COL_GOLD)
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.03, 0.04, 0.82) if state != "pressed" else Color(0.18, 0.13, 0.03, 0.95)
		sb.set_border_width_all(1)
		sb.border_color = Color(COL_GOLD, 0.45 if state != "pressed" else 0.9)
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 16.0
		sb.content_margin_right = 16.0
		if state == "focus":
			sb.draw_center = false
			sb.border_color = Color(0, 0, 0, 0)
		_skip.add_theme_stylebox_override(state, sb)
	_skip.pressed.connect(_on_skip_pressed)
	UIFx.bind_press_feedback(_skip)
	_root.add_child(_skip)


func _on_skip_pressed() -> void:
	if not _running or _ending:
		return
	if _skip_armed <= 0.0:
		_skip_armed = SKIP_CONFIRM_SEC
		_skip.text = "مطمئنی؟ دوباره بزن"
		_skip.add_theme_color_override("font_color", COL_GOLD)
		LocalSettings.vibrate(15)
		return
	_skip_armed = 0.0
	_finish()


func _make_label(text: String, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text_direction = Control.TEXT_DIRECTION_RTL
	l.add_theme_font_override("font", FONT)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


# ============================ حلقه ============================

func _process(delta: float) -> void:
	if not _running and not _ending:
		return
	_t += delta
	_track_scene(delta)
	if not _scene_ready:
		return

	_step_time += delta
	_input_lock = maxf(_input_lock - delta, 0.0)
	if _skip_armed > 0.0:
		_skip_armed -= delta
		if _skip_armed <= 0.0:
			_reset_skip()
	var st: Dictionary = STEPS[_step] if _step >= 0 and not _ending else {}

	if not st.is_empty():
		_hold_joystick()
		_spot.hole = _target_rect(st.target)
		_spot.pass_through = (st.wait == "event" or st.wait == "scene" or st.wait == "do") \
				and not _praising
		# قدمِ do: خبر نیامد یا دکمه پیدا نشد ← لمسِ هر جا هم ادامه می‌دهد
		if st.wait == "do" and not _fallback_tap and not _praising \
				and (_step_time > DO_FALLBACK_SEC \
					or (_step_time > DO_MISSING_SEC and not _spot.hole.has_area())):
			_fallback_tap = true
			_refresh_hint()
		# کارت‌ها نرسیدند (سرور قطع است): بازیکن نباید پشتِ آموزش گیر کند
		if st.target == "cards" and not _fallback_tap and _step_time > CARDS_FALLBACK_SEC \
				and _cards_count() == 0:
			_fallback_tap = true
			_refresh_hint()
		if st.wait == "move":
			var j := _joystick()
			if j != null and (j.get("joystick_vector") as Vector2).length() > 0.3:
				_moved += delta
				if _moved >= MOVE_NEEDED:
					_advance()
					return

	if _typing:
		_type_pos += delta * TYPE_SPEED
		_body.visible_characters = maxi(int(_type_pos), 0)
		if _type_pos >= float(_body.get_total_character_count()):
			_finish_typing()

	_hint.modulate.a = 0.55 + 0.45 * sin(_t * 4.0)
	_spot.t = _t
	_spot.queue_redraw()
	_layout()


## صحنه‌ی جاری را دنبال می‌کند و بعد از آماده شدنش قدمِ درست را نشان می‌دهد
func _track_scene(delta: float) -> void:
	var cur := get_tree().current_scene
	if cur != _scene:
		_scene = cur
		_scene_ready = false
		_settle = 0.45
		_set_overlay_visible(false)
		return
	if _scene_ready or _scene == null or _ending:
		return
	if LoadingScreen.is_active() or not _scene.is_node_ready():
		_settle = 0.45
		return
	if _scene.scene_file_path == SCENE_GAME and _scene.get("hud") == null:
		return
	_settle -= delta
	if _settle > 0.0:
		return
	var step := _step_for_scene(_scene.scene_file_path)
	if step < 0:
		return
	_scene_ready = true
	_go(step)


## بازیکن هر جا که باشد، کدام قدم مالِ این صحنه است؟ (‎-1 یعنی این صحنه ربطی ندارد)
func _step_for_scene(path: String) -> int:
	var at := maxi(_step, 0)
	match path:
		SCENE_MENU:
			if at <= 1:
				return at
			return STEP_PLAY if at >= STEP_HOME else STEP_SELECT_BTN
		SCENE_SELECT:
			if at <= STEP_SELECT:
				return STEP_SELECT
			# صحنه از نو ساخته شده و تب روی کاراکترهاست
			if at == STEP_SELECT + 1:
				return at
			return STEP_WEAPON_TAB if at < STEP_HOME else STEP_HOME
		SCENE_GAME:
			if at >= STEP_PLAY:
				return maxi(at, STEP_GAME)
	return -1


func _go(i: int) -> void:
	_step = i
	_step_time = 0.0
	_moved = 0.0
	_fallback_tap = false
	_input_lock = 0.35
	var st: Dictionary = STEPS[i]
	_spot.hole = _target_rect(st.target)
	_set_overlay_visible(true)
	_hold_joystick()
	_say(st.text)


func _advance() -> void:
	LocalSettings.vibrate(20)
	if _step + 1 >= STEPS.size():
		_finish()
		return
	var next: Dictionary = STEPS[_step + 1]
	if next.scene != STEPS[_step].scene:
		# قدمِ بعدی در صحنه‌ی دیگری است؛ همان‌جا شروع می‌شود
		return
	_go(_step + 1)


func _on_tap(touch_index: int = -1) -> void:
	if not _scene_ready or _input_lock > 0.0 or _ending or _step < 0 or _praising:
		return
	# C1 انگشتی که جوی‌استیک را گرفته «لمس برای ادامه» حساب نمی‌شود — وگرنه
	# راه رفتن وسطِ توضیح، جمله‌ها را بی‌آنکه خوانده شوند رد می‌کرد
	var j := _joystick()
	if j != null and bool(j.get("enabled")):
		var held := int(j.get("touch_index"))
		if held != -1 and (touch_index == held or touch_index < 0):
			return
	if _typing:
		_finish_typing()
		return
	var st: Dictionary = STEPS[_step]
	if st.wait == "tap" or _fallback_tap:
		_advance()
	elif st.wait != "move":
		# لمسِ جای اشتباه: حباب یک تکانِ کوچک می‌خورد تا چشم برگردد سمتش
		_nudge_bubble()


func _finish() -> void:
	_running = false
	_ending = true
	_save_local_done(true)
	_send_done_to_server()
	_release_joystick()
	_spot.pass_through = true
	_spot.hole = Rect2()
	_spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.text = ""
	_skip.visible = false

	# یک دست تکان دادنِ کوچک، بعد پایین می‌رود و پرده باز می‌شود
	_woman.pivot_offset = Vector2(_woman.size.x * 0.5, _woman.size.y)
	var wave := create_tween()
	for k in 2:
		wave.tween_property(_woman, "rotation", 0.05, 0.12).set_trans(Tween.TRANS_SINE)
		wave.tween_property(_woman, "rotation", -0.05, 0.12).set_trans(Tween.TRANS_SINE)
	wave.tween_property(_woman, "rotation", 0.0, 0.1)
	wave.tween_interval(0.5)
	wave.tween_property(_bubble, "modulate:a", 0.0, 0.25)
	wave.parallel().tween_property(_bubble, "scale", Vector2(0.8, 0.8), 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	wave.tween_property(self, "woman_drop", 1.0, 0.55) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	wave.parallel().tween_property(_spot, "shade", 0.0, 0.45)
	wave.tween_callback(func():
		_ending = false
		visible = false
		set_process(false)
		finished.emit())


# ============================ گفتار و انیمیشن ============================

func _say(text: String) -> void:
	_body.text = text
	_body.visible_characters = 0
	_type_pos = 0.0
	_typing = true
	_hint.text = ""
	_layout()

	var side := _pick_side(_spot.hole)
	var delay := 0.0
	if not _woman_in:
		delay = 0.45
		_side = side
		_woman_in = true
		_slide_woman_in(0.15)
	elif side != _side:
		# جا عوض می‌کند: پایین می‌رود، آن طرف دوباره بالا می‌آید
		_kill(_woman_tween)
		_woman_tween = create_tween()
		_woman_tween.tween_property(self, "woman_drop", 1.0, 0.28) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_woman_tween.tween_callback(func(): _side = side)
		delay = 0.32
		_woman_tween.tween_property(self, "woman_drop", 0.0, 0.6) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop_bubble(delay)


func _slide_woman_in(delay: float) -> void:
	woman_drop = 1.0
	_kill(_woman_tween)
	_woman_tween = create_tween()
	_woman_tween.tween_interval(delay)
	_woman_tween.tween_property(self, "woman_drop", 0.0, 0.75) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## حباب از سمتِ سارا باز می‌شود؛ کمی کشسان، و متن حرف‌به‌حرف تایپ می‌شود
func _pop_bubble(delay: float) -> void:
	_kill(_bubble_tween)
	_bubble.modulate.a = 0.0
	_bubble.scale = Vector2(0.6, 0.6)
	_bubble.rotation = 0.0
	_type_pos = -delay * TYPE_SPEED
	_bubble_tween = create_tween()
	_bubble_tween.tween_interval(delay)
	_bubble_tween.tween_property(_bubble, "modulate:a", 1.0, 0.16)
	_bubble_tween.parallel().tween_property(_bubble, "scale", Vector2.ONE, 0.42) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _nudge_bubble() -> void:
	if _bubble_tween != null and _bubble_tween.is_running():
		return
	_bubble_tween = create_tween()
	for a in [0.03, -0.03, 0.018, 0.0]:
		_bubble_tween.tween_property(_bubble, "rotation", a, 0.06)


func _finish_typing() -> void:
	_typing = false
	_body.visible_characters = -1
	_refresh_hint()
	# سرِ هر جمله یک «پرشِ» کوچکِ اسم، که حس کنی تمام شد
	_name_pill.pivot_offset = _name_pill.size * 0.5
	var tw := create_tween()
	tw.tween_property(_name_pill, "scale", Vector2(1.12, 1.12), 0.08)
	tw.tween_property(_name_pill, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)


func _refresh_hint() -> void:
	if _step < 0 or _typing:
		return
	var st: Dictionary = STEPS[_step]
	# C9 شیب هدف: بازیکن می‌بیند چقدر مانده
	var count := "%s/%s   " % [_fa(_step + 1), _fa(STEPS.size())]
	if st.wait == "do":
		_hint.text = count + ("بزنش، یا برای ادامه جای دیگه رو لمس کن ◂" if _fallback_tap \
			else "خودت امتحانش کن ◂")
	elif st.wait == "tap" or _fallback_tap:
		_hint.text = count + "برای ادامه لمس کن ◂"
	elif st.wait == "move":
		_hint.text = count + "جوی‌استیک رو تکون بده ◂"
	else:
		_hint.text = count + "روی قسمتِ روشن بزن ◂"


func _fa(n: int) -> String:
	const DIGITS := "۰۱۲۳۴۵۶۷۸۹"
	var out := ""
	for ch in str(n):
		out += DIGITS[int(ch)]
	return out


func _reset_skip() -> void:
	_skip_armed = 0.0
	if _skip == null:
		return
	_skip.text = "رد کردن آموزش"
	_skip.add_theme_color_override("font_color", COL_DIM)


func _kill(tw: Tween) -> void:
	if tw != null and tw.is_valid():
		tw.kill()


func _set_overlay_visible(on: bool) -> void:
	if _spot == null:
		return
	visible = on or _ending
	_spot.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	if on:
		var tw := create_tween()
		tw.tween_property(_spot, "shade", 1.0, 0.3)
	else:
		_spot.shade = 0.0
		_reset_skip()
		_woman_in = false
		woman_drop = 1.0
		_bubble.modulate.a = 0.0


# ============================ چیدمان ============================

func _k() -> float:
	return clampf(_root.size.y / DESIGN_H, 0.6, 2.4)


func _woman_size() -> Vector2:
	var h := _root.size.y * 0.6
	return Vector2(h * WOMAN_TEX.get_width() / WOMAN_TEX.get_height(), h)


func _woman_rect(side: String) -> Rect2:
	var ins := _safe_insets()
	var ws := _woman_size()
	var x := _root.size.x - ins.z - ws.x * 0.95 if side == "right" else ins.x - ws.x * 0.05
	return Rect2(Vector2(x, _root.size.y - ws.y * 0.97), ws)


## سارا طرفی می‌ایستد که کمتر جلوی سوراخ را بگیرد
func _pick_side(hole: Rect2) -> String:
	if not hole.has_area():
		return "right"
	var r := _overlap(_woman_rect("right"), hole)
	var l := _overlap(_woman_rect("left"), hole)
	if is_equal_approx(r, l):
		return "right" if hole.get_center().x < _root.size.x * 0.5 else "left"
	return "right" if r < l else "left"


func _overlap(a: Rect2, b: Rect2) -> float:
	var i := a.intersection(b)
	return i.get_area() if i.has_area() else 0.0


func _layout() -> void:
	var k := _k()
	var vp := _root.size
	var ins := _safe_insets()
	var margin := 12.0 * k

	# --- سارا: نفسِ آرام، و موقعِ حرف زدن یک لرزشِ ریز ---
	var wr := _woman_rect(_side)
	_woman.size = wr.size
	_woman.pivot_offset = Vector2(wr.size.x * 0.5, wr.size.y)
	var bob := sin(_t * 2.2) * wr.size.y * 0.006
	_woman.position = wr.position + Vector2(0, woman_drop * (wr.size.y + 40.0) + bob)
	var talk := 0.006 * absf(sin(_t * 16.0)) if _typing else 0.0
	_woman.scale = Vector2(1.0, 1.0 + 0.004 * sin(_t * 2.2) + talk)

	# --- حباب ---
	for l in [_body, _hint]:
		l.add_theme_font_size_override("font_size", int(round((24.0 if l == _body else 19.0) * k)))
	_name_label.add_theme_font_size_override("font_size", int(round(18.0 * k)))
	var room := vp.x - ins.x - ins.z - wr.size.x * 0.8 - margin * 3.0
	var bw := clampf(room, 260.0 * k, 560.0 * k)
	_body.custom_minimum_size.x = bw - 48.0
	_bubble.size = Vector2(bw, 0)
	_bubble.reset_size()
	_bubble.size.x = bw
	var bh := _bubble.get_combined_minimum_size().y

	var bx: float
	if _side == "right":
		bx = wr.position.x + wr.size.x * 0.2 - bw
	else:
		bx = wr.end.x - wr.size.x * 0.2
	bx = clampf(bx, ins.x + margin, vp.x - ins.z - margin - bw)

	# سه جای ممکن: کنارِ شانه، پایین، بالا — هر کدام که کمتر روی سوراخ بیفتد
	var top := ins.y + margin * 2.0
	var bottom := vp.y - ins.w - margin - bh
	var chest := wr.position.y + wr.size.y * 0.35 - bh * 0.5
	var best := chest
	var best_cost := INF
	var hole := _spot.hole.grow(14.0 * k)
	for y in [chest, bottom, top]:
		var yy := clampf(y, top, bottom)
		var cost := _overlap(Rect2(bx, yy, bw, bh), hole) if hole.has_area() else 0.0
		if cost < best_cost - 1.0:
			best_cost = cost
			best = yy
	_bubble.position = Vector2(bx, best)
	_bubble.pivot_offset = Vector2(bw if _side == "right" else 0.0, bh)
	_spot.k = k
	_layout_skip(k, vp, ins)


## گوشه‌ی بالا-راست داخل ناحیه‌ی امن؛ اگر روی سوراخ افتاد، بالا-چپ
func _layout_skip(k: float, vp: Vector2, ins: Vector4) -> void:
	if _skip == null:
		return
	_skip.visible = visible and not _ending and _spot.shade > 0.05
	_skip.add_theme_font_size_override("font_size", int(round(17.0 * k)))
	_skip.custom_minimum_size = Vector2(0, 60.0 * k)
	_skip.reset_size()
	var sz := _skip.get_combined_minimum_size()
	var m := 14.0 * k
	var pos := Vector2(vp.x - ins.z - m - sz.x, ins.y + m)
	if _spot.hole.has_area() and Rect2(pos, sz).intersects(_spot.hole.grow(6.0 * k)):
		pos.x = ins.x + m
	_skip.position = pos
	_skip.size = sz


## فاصله‌ی ناچ و لبه‌های خمیده (چپ، بالا، راست، پایین) به واحدِ viewport
func _safe_insets() -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var win_pos := DisplayServer.window_get_position()
	var win_size := DisplayServer.window_get_size()
	if safe.size.x <= 0 or win_size.x <= 0:
		return Vector4.ZERO
	var s := _root.size / Vector2(win_size)
	return Vector4(
		maxf(0.0, float(safe.position.x - win_pos.x)) * s.x,
		maxf(0.0, float(safe.position.y - win_pos.y)) * s.y,
		maxf(0.0, float(win_pos.x + win_size.x - safe.end.x)) * s.x,
		maxf(0.0, float(win_pos.y + win_size.y - safe.end.y)) * s.y)


# ============================ هدف‌ها ============================

func _target_rect(key: String) -> Rect2:
	if key == "" or _scene == null:
		return Rect2()
	var pad := 8.0 * _k()
	match key:
		"select_btn":
			return _ctrl_rect(_scene.get_node_or_null("VBoxContainer/SelectitemButton"), pad)
		"play_btn":
			return _ctrl_rect(_scene.get_node_or_null("VBoxContainer/PlayButton"), pad)
		"cards":
			return _ctrl_rect(_scene.get_node_or_null("Content/CardsPanel"), pad * 0.5)
		"weapon_tab":
			return _ctrl_rect(_scene.get_node_or_null("HeaderTabs/Tabs/WeaponsButton"), pad)
		"home":
			return _ctrl_rect(_scene.get_node_or_null("HomeButton"), pad)
		"profile":
			return _ctrl_rect(_hud_part("profile"), pad)
		"round":
			var rh = _hud_part("round_hud")
			return _ctrl_rect(rh.get_node_or_null("TimerPlate") if rh != null else null, pad)
		"joystick":
			var j := _joystick()
			if j == null:
				return Rect2()
			var xf := j.get_global_transform_with_canvas()
			var r := 92.0 * float(j.get("_ui_scale")) + pad * 2.0
			return Rect2(xf.origin - Vector2(r, r), Vector2(r, r) * 2.0)
	if key.begins_with("btn_"):
		var hud = _scene.get("hud")
		if hud != null:
			return _ctrl_rect(hud.button(key.trim_prefix("btn_")), pad)
	return Rect2()


func _ctrl_rect(c: Control, pad: float) -> Rect2:
	if c == null or not c.is_visible_in_tree():
		return Rect2()
	var xf := c.get_global_transform_with_canvas()
	return Rect2(xf.origin, c.size * xf.get_scale()).grow(pad)


func _hud_part(prop: String) -> Control:
	var hud = _scene.get("hud") if _scene != null else null
	return hud.get(prop) if hud != null else null


func _cards_count() -> int:
	var grid := _scene.get_node_or_null("Content/CardsPanel/CardsScroll/CardsGrid") if _scene != null else null
	return grid.get_child_count() if grid != null else 0


func _joystick() -> Control:
	if _scene == null or _scene.scene_file_path != SCENE_GAME:
		return null
	return _scene.get("joystick") as Control


## قبل از قدمِ جوی‌استیک بازیکن نباید راه بیفتد. هر فریم چک می‌شود چون
## world.gd بعد از برگشتن از پس‌زمینه جوی‌استیک را دوباره روشن می‌کند.
func _hold_joystick() -> void:
	var j := _joystick()
	if j == null:
		return
	var want: bool = _step >= STEP_JOYSTICK
	if bool(j.get("enabled")) != want:
		j.call("set_enabled", want)


func _release_joystick() -> void:
	var j := _joystick()
	if j != null and not bool(j.get("enabled")):
		j.call("set_enabled", true)


# ============================ پرده با سوراخ ============================

## پرده‌ی تیره‌ی تمام‌صفحه. لمس بیرونِ سوراخ همین‌جا گرفته می‌شود؛ لمسِ
## داخلِ سوراخ (وقتی pass_through روشن است) به صحنه‌ی زیرش می‌رسد، چون
## _has_point برایش false برمی‌گرداند.
class Spot extends Control:
	## touch_index: اندیس انگشت؛ برای کلیک ماوس -1
	signal tapped(touch_index: int)

	var hole := Rect2()
	var pass_through := false
	var shade := 0.0
	var t := 0.0
	var k := 1.0
	var _last_tap := -1000

	func _has_point(point: Vector2) -> bool:
		if pass_through and hole.has_area() and hole.has_point(point):
			return false
		return true

	func _gui_input(event: InputEvent) -> void:
		var down: bool = (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
		if not down:
			return
		accept_event()
		# شبیه‌سازیِ لمس از ماوس (و برعکس) یک لمس را دوبار می‌فرستد
		var now := Time.get_ticks_msec()
		if now - _last_tap < 180:
			return
		_last_tap = now
		tapped.emit(event.index if event is InputEventScreenTouch else -1)

	func _draw() -> void:
		if shade <= 0.001:
			return
		var col := Color(0.0, 0.0, 0.0, 0.66 * shade)
		var w := size.x
		var h := size.y
		if not hole.has_area():
			draw_rect(Rect2(Vector2.ZERO, size), col)
			return
		var r := hole
		draw_rect(Rect2(0, 0, w, maxf(r.position.y, 0.0)), col)
		draw_rect(Rect2(0, r.end.y, w, maxf(h - r.end.y, 0.0)), col)
		draw_rect(Rect2(0, r.position.y, maxf(r.position.x, 0.0), r.size.y), col)
		draw_rect(Rect2(r.end.x, r.position.y, maxf(w - r.end.x, 0.0), r.size.y), col)

		var gold := Color(0.96, 0.78, 0.3, shade)
		# قابِ طلاییِ تپنده
		var p := 0.5 + 0.5 * sin(t * 5.0)
		var frame := StyleBoxFlat.new()
		frame.draw_center = false
		frame.set_border_width_all(int(maxf(3.0 * k, 2.0)))
		frame.border_color = gold
		frame.set_corner_radius_all(int(14.0 * k))
		draw_style_box(frame, r.grow(2.0 + p * 4.0 * k))
		# موجی که از قاب بیرون می‌زند
		var q := fmod(t, 1.3) / 1.3
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.set_border_width_all(int(maxf(2.0 * k, 1.0)))
		ring.border_color = Color(gold.r, gold.g, gold.b, (1.0 - q) * 0.7 * shade)
		ring.set_corner_radius_all(int(18.0 * k))
		draw_style_box(ring, r.grow(4.0 + q * 26.0 * k))

		# فلشِ بالا-پایین پرنده، از سمتِ وسطِ صفحه به سوراخ
		var bounce := sin(t * 6.0) * 7.0 * k
		var s := 18.0 * k
		var from_above := r.get_center().y > h * 0.5
		var tip: Vector2
		var dir: float
		if from_above:
			tip = Vector2(r.get_center().x, r.position.y - 12.0 * k - absf(bounce))
			dir = -1.0
		else:
			tip = Vector2(r.get_center().x, r.end.y + 12.0 * k + absf(bounce))
			dir = 1.0
		tip.x = clampf(tip.x, s * 2.0, w - s * 2.0)
		var pts := PackedVector2Array([tip,
			tip + Vector2(-s, dir * s * 1.3), tip + Vector2(s, dir * s * 1.3)])
		draw_colored_polygon(pts, gold)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0, 0, 0, 0.7 * shade), 2.0)
