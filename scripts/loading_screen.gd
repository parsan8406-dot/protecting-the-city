extends CanvasLayer
## صفحه‌ی بارگذاری (autoload با نام LoadingScreen).
##
## پس‌زمینه‌ی StartBG، یک پنلِ شیشه‌ای و نواری که تا رسیدنِ کاملِ دیتای سرور
## کم‌کم پر می‌شود. دو جا خودش را نشان می‌دهد:
##   ۱) باز شدنِ بازی — تا دیتای بازیکن، حالتِ بازی و اتصالِ سوکت برسند
##   ۲) ورود به زمینِ بازی — با LoadingScreen.change_scene(path)
##
## کار بر اساسِ «مرحله» است: هر مرحله وزنی دارد و وقتی کامل شد سهمش از نوار
## پر می‌شود. صحنه‌ای که خودش هنوز منتظرِ سرور است، مرحله‌ی scene_ready را
## با split() به زیرمرحله‌های خودش تقسیم می‌کند و هرکدام را با complete()
## می‌بندد. اگر صفحه باز نباشد split/complete کاری نمی‌کنند، پس ابزارهای
## tools/ که صحنه را مستقیم لود می‌کنند دست نمی‌خورند.

signal finished

const BG_PATH := "res://assets/StartBG.png"
const GLASS_SHADER := preload("res://shaders/loading_glass.gdshader")
const FILL_SHADER := preload("res://shaders/loading_fill.gdshader")

## مرحله‌ی مشترکِ «صحنه‌ی تازه آماده شد» — صحنه‌ها با split تقسیمش می‌کنند
const SCENE_READY := "scene_ready"

## بعد از این مدت پیامِ «کند است» نشان داده می‌شود
const SLOW_HINT_SEC := 8.0
## بعد از این مدت دیگر منتظر نمی‌مانیم؛ بازیکن نباید پشتِ لودینگ گیر کند
const TIMEOUT_SEC := 25.0
## وقتی مرحله‌ای کامل نشده، نوار تا این سهم از آن مرحله آرام جلو می‌خزد
const CREEP_SHARE := 0.85
const CREEP_TIME := 4.0
const FILL_SPEED := 2.2
const FADE_TIME := 0.35
## C12 Doherty: هر چند ثانیه یک نکته‌ی واقعیِ گیم‌پلی (psych_menu_tips.gd)
const TIPS := preload("res://scripts/psych_menu_tips.gd")
const TIP_EVERY := 4.5
const TIP_FADE := 0.25

var _steps: Dictionary = {}          # id -> {"w": float, "p": float}
var _value := 0.0                    # مقدارِ نمایشی ۰..۱ (هیچ‌وقت عقب نمی‌رود)
var _since_progress := 0.0
var _elapsed := 0.0
var _active := false
var _closing := false
var _hold := 0.0
var _slow_shown := false
var _loading_path := ""
var _load_progress: Array = []
## هر begin یک نسلِ تازه است؛ بستنِ نیمه‌کاره‌ی نسلِ قبلی نباید صفحه‌ی تازه را ببندد
var _generation := 0
var _fade: Tween
## نسلِ صفحه‌ی شروعِ بازی — خبرهای دیررسِ /get_player نباید لودینگِ زمین را ببندند
var _boot_generation := -1
## شروعِ بازی بدونِ سرور شکست خورد و بازی در حالِ بسته شدن است
var _quitting := false
## چند ثانیه پیامِ قطعی دیده شود و بعد بازی بسته شود
const QUIT_DELAY_SEC := 3.0
## شروعِ بازی بدونِ اینترنت: به‌جای بستنِ بازی، تلاشِ دوباره (خودکار + دکمه)
var _boot_retrying := false
var _boot_attempt := 1
var _retry_btn: Button

var _root: Control
var _safe: MarginContainer
var _glass_fx: ColorRect
var _title: Label
var _status: Label
var _percent: Label
var _track: Panel
var _fill_glow: Panel
var _fill: ColorRect
var _tip_row: HBoxContainer
var _tip_icon: TextureRect
var _tip_label: Label
var _tip_order: Array = []
var _tip_pos := -1
var _tip_clock := 0.0
var _tip_tw: Tween


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_start_boot()


# -----------------------------------------------------------------------------
# API
# -----------------------------------------------------------------------------

## صفحه را با مرحله‌های داده‌شده باز می‌کند. steps: {id: وزن}
func begin(steps: Dictionary, title: String = "در حال بارگذاری") -> void:
	_generation += 1
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_steps.clear()
	for id in steps:
		_steps[id] = {"w": maxf(float(steps[id]), 0.001), "p": 0.0}
	_value = 0.0
	_since_progress = 0.0
	_elapsed = 0.0
	_closing = false
	_hold = 0.0
	_slow_shown = false
	_active = true
	_title.text = title
	_status.text = "لطفاً صبر کنید..."
	_status.add_theme_color_override("font_color", MenuUI.MUTED)
	if _retry_btn != null:
		_retry_btn.visible = false
	_root.modulate.a = 1.0
	visible = true
	_redraw_bar()
	_next_tip(false)


func is_active() -> bool:
	return _active


## یک مرحله را به چند زیرمرحله تقسیم می‌کند (وزنِ کلِ همان مرحله حفظ می‌شود)
func split(parent: String, children: Dictionary) -> void:
	if not _active or not _steps.has(parent) or children.is_empty():
		return
	var parent_w: float = _steps[parent]["w"]
	var sum := 0.0
	for id in children:
		sum += maxf(float(children[id]), 0.001)
	_steps.erase(parent)
	for id in children:
		_steps[id] = {"w": parent_w * maxf(float(children[id]), 0.001) / sum, "p": 0.0}


func set_progress(id: String, fraction: float, status: String = "") -> void:
	if not _active or not _steps.has(id):
		return
	var p := clampf(fraction, 0.0, 1.0)
	if p > _steps[id]["p"]:
		_steps[id]["p"] = p
		_since_progress = 0.0
	if status != "" and not _closing:
		_status.text = status


func complete(id: String, status: String = "") -> void:
	set_progress(id, 1.0, status)


## چیزی نرسید (سرور در دسترس نیست و ...). پیام نشان داده و صفحه بسته می‌شود.
func fail(message: String) -> void:
	if not _active:
		return
	_status.text = message
	_status.add_theme_color_override("font_color", MenuUI.RED_HOT)
	_hold = 1.4
	for id in _steps:
		_steps[id]["p"] = 1.0


## صحنه را پشتِ صفحه‌ی بارگذاری عوض می‌کند: لودِ صحنه در ترد جدا (نوار زنده
## می‌ماند) و بعد منتظرِ مرحله‌هایی که خودِ صحنه‌ی تازه با split اضافه کند.
func change_scene(path: String, title: String = "در حال آماده‌سازی میدان نبرد") -> void:
	if _loading_path != "":
		return
	get_tree().paused = false
	begin({"scene": 0.35, SCENE_READY: 0.65}, title)
	_status.text = "بارگذاری زمینِ بازی..."
	if ResourceLoader.load_threaded_request(path) != OK:
		_active = false
		visible = false
		get_tree().change_scene_to_file(path)
		return
	_loading_path = path


# -----------------------------------------------------------------------------
# شروعِ بازی
# -----------------------------------------------------------------------------

func _start_boot() -> void:
	begin({"boot": 0.4, "player": 2.0, "modes": 1.0, "link": 1.0}, "در حال بارگذاری")
	_boot_generation = _generation
	_status.text = "در حال دریافت اطلاعات از سرور..."
	Global.player_data_loaded.connect(_on_boot_player_loaded, CONNECT_ONE_SHOT)
	# نه ONE_SHOT: هر تلاشِ دوباره‌ی ناموفق دوباره همین را صدا می‌زند
	Global.player_data_failed.connect(_on_boot_player_failed)
	Global.modes_synced.connect(func() -> void:
		if _generation == _boot_generation:
			complete("modes", "اتصال به سرور بازی..."), CONNECT_ONE_SHOT)
	Network.connected.connect(func() -> void:
		if _generation == _boot_generation:
			complete("link"), CONNECT_ONE_SHOT)
	_check_boot_scene.call_deferred()


## صفحه فقط وقتی بازی از صحنه‌ی اصلی باز شده معنی دارد؛ ابزارهای تست و
## اسکرین‌شات (tools/) صحنه‌ی خودشان را باز می‌کنند و نباید پوشیده شوند.
func _check_boot_scene() -> void:
	var main_path := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main_path.begins_with("uid://"):
		main_path = ResourceUID.get_id_path(ResourceUID.text_to_id(main_path))
	var current := get_tree().current_scene
	if current == null or current.scene_file_path != main_path \
			or OS.get_cmdline_args().has("--autostart"):
		_active = false
		visible = false
		return
	complete("boot")


func _on_boot_player_loaded() -> void:
	if _generation != _boot_generation:
		return
	_boot_retrying = false
	_retry_btn.visible = false
	_status.add_theme_color_override("font_color", MenuUI.MUTED)
	complete("player", "دریافت تنظیمات بازی...")


func _on_boot_player_failed() -> void:
	if _generation != _boot_generation or not _active:
		return
	# حسابِ قفل‌شده خودش به صفحه‌ی تنظیمات می‌رود؛ پیامِ خطا فقط برای قطعی است
	if Global.account_locked:
		for id in _steps:
			_steps[id]["p"] = 1.0
		return
	if not Global.ban_message.is_empty():
		_fail_and_quit(Global.ban_message)
		return
	# E13: قطعیِ اینترنت دیگر یعنی «بازی بسته می‌شود» نیست — تلاشِ خودکار
	# (Network.report_http_failure → Global.fetch_player_data) + دکمه‌ی دستی
	_enter_boot_retry("اتصال به سرور برقرار نشد — دوباره تلاش می‌کنیم")


## C12: وضعیتِ صادقانه («تلاشِ چندم») به‌جای بستنِ بازی؛ نوار عقب نمی‌رود
func _enter_boot_retry(message: String) -> void:
	if _quitting:
		return
	_boot_attempt += 1
	_boot_retrying = true
	_elapsed = 0.0
	_slow_shown = true
	_status.text = message
	_status.add_theme_color_override("font_color", MenuUI.GOLD)
	_retry_btn.visible = true


func _on_boot_retry_pressed() -> void:
	_status.text = "در حال تلاشِ دوباره..."
	if Network.http_failing:
		Network.retry_now()
	else:
		Global.fetch_player_data()


## بدونِ سرور بازی قابل‌استفاده نیست: پیام را نشان بده و از بازی خارج شو
func _fail_and_quit(message: String) -> void:
	if _quitting:
		return
	_quitting = true
	fail(message)
	_hold = QUIT_DELAY_SEC
	await get_tree().create_timer(QUIT_DELAY_SEC, true).timeout
	get_tree().quit()


# -----------------------------------------------------------------------------
# حلقه
# -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not _active:
		return
	_poll_scene_load()
	_elapsed += delta
	_tip_clock += delta
	if _tip_clock >= TIP_EVERY:
		_next_tip(true)
	_since_progress += delta

	if not _closing:
		if not _slow_shown and _elapsed > SLOW_HINT_SEC:
			_slow_shown = true
			_status.text = "کمی بیشتر طول کشید، لطفاً صبر کنید..."
		if _elapsed > TIMEOUT_SEC and _loading_path == "":
			if _generation == _boot_generation:
				if _steps.has("player") and float(_steps["player"]["p"]) >= 1.0:
					# دیتای بازیکن رسیده و فقط سوکت/حالت‌ها مانده: وارد منو شو؛
					# نوارِ «اتصال قطع شد» آن‌جا خودش تلاش می‌کند (C12)
					for id in _steps:
						_steps[id]["p"] = 1.0
				else:
					_enter_boot_retry("پاسخ سرور دیر رسید — دوباره تلاش می‌کنیم")
			else:
				fail("پاسخ سرور دیر رسید")

	var target := _target()
	var goal := target
	if target < 1.0:
		var creep := 1.0 - exp(-_since_progress / CREEP_TIME)
		goal += _pending_share() * CREEP_SHARE * creep
	# وقتی همه چیز رسید، باقیِ نوار سریع پر شود تا بازیکن بی‌خود منتظر نماند
	var min_gap := 0.35 if target >= 1.0 else 0.08
	_value = maxf(_value, move_toward(_value, goal, delta * FILL_SPEED * maxf(goal - _value, min_gap)))
	if target >= 1.0 and _value > 0.995:
		_value = 1.0
	_redraw_bar()

	if _value >= 1.0 and not _closing:
		_closing = true
		_close()


func _poll_scene_load() -> void:
	if _loading_path == "":
		return
	var status := ResourceLoader.load_threaded_get_status(_loading_path, _load_progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if not _load_progress.is_empty():
				set_progress("scene", float(_load_progress[0]))
		ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(_loading_path) as PackedScene
			_loading_path = ""
			complete("scene", "در انتظار سرور...")
			_swap_scene(packed)
		_:
			var path := _loading_path
			_loading_path = ""
			_active = false
			visible = false
			get_tree().change_scene_to_file(path)


func _swap_scene(packed: PackedScene) -> void:
	get_tree().change_scene_to_packed(packed)
	await get_tree().scene_changed
	await get_tree().process_frame
	# صحنه‌ای که مرحله‌ی خودش را اعلام نکرده همین حالا آماده است
	complete(SCENE_READY)


func _target() -> float:
	var total := 0.0
	var done := 0.0
	for id in _steps:
		total += _steps[id]["w"]
		done += _steps[id]["w"] * _steps[id]["p"]
	return 1.0 if total <= 0.0 else done / total


## سهمِ باقی‌مانده‌ی اولین مرحله‌ی ناتمام (برای خزیدنِ آرامِ نوار)
func _pending_share() -> float:
	var total := 0.0
	for id in _steps:
		total += _steps[id]["w"]
	if total <= 0.0:
		return 0.0
	for id in _steps:
		if _steps[id]["p"] < 1.0:
			return _steps[id]["w"] * (1.0 - _steps[id]["p"]) / total
	return 0.0


func _close() -> void:
	var gen := _generation
	await get_tree().create_timer(_hold + 0.15, true).timeout
	# در همین فاصله ممکن است بارگذاریِ تازه‌ای شروع شده باشد
	if gen != _generation:
		return
	_fade = create_tween()
	_fade.tween_property(_root, "modulate:a", 0.0, FADE_TIME)
	await _fade.finished
	if gen != _generation:
		return
	_active = false
	visible = false
	finished.emit()


# -----------------------------------------------------------------------------
# ظاهر
# -----------------------------------------------------------------------------

func _redraw_bar() -> void:
	if _fill == null:
		return
	var v := clampf(_value, 0.0, 1.0)
	_fill.anchor_right = v
	_fill_glow.anchor_right = v
	_fill.visible = v > 0.005
	_fill_glow.visible = _fill.visible
	_percent.text = "٪" + MenuUI.fa(int(round(v * 100.0)))


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# لمس‌ها به صحنه‌ی زیرین نرسند
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(BG_PATH):
		bg.texture = load(BG_PATH)
	_root.add_child(bg)

	# تیرگیِ پایینِ صفحه تا پنل و متن روی هر بخشِ عکس خوانا بمانند
	var shade := TextureRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.0))
	grad.set_color(1, Color(0, 0, 0, 0.7))
	grad.set_offset(0, 0.45)
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 128
	shade.texture = gt
	_root.add_child(shade)

	_safe = MarginContainer.new()
	_safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_safe)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	_safe.add_child(column)
	column.add_child(_spacer(true, 5.0))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 0)
	column.add_child(row)
	row.add_child(_spacer(false, 1.0))
	var glass := _build_glass()
	glass.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	glass.size_flags_stretch_ratio = 2.6
	row.add_child(glass)
	row.add_child(_spacer(false, 1.0))

	column.add_child(_spacer(true, 1.0))


func _build_glass() -> Control:
	var glass := MarginContainer.new()
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_glass_fx = ColorRect.new()
	_glass_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = GLASS_SHADER
	_glass_fx.material = mat
	_glass_fx.resized.connect(func() -> void: mat.set_shader_parameter("rect_size", _glass_fx.size))
	glass.add_child(_glass_fx)

	# لبه‌ی روشن و سایه‌ی بیرونیِ شیشه
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.03)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.22)
	sb.set_corner_radius_all(22)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 24
	sb.shadow_offset = Vector2(0, 8)
	sb.anti_aliasing = true
	frame.add_theme_stylebox_override("panel", sb)
	glass.add_child(frame)

	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 36)
	pad.add_theme_constant_override("margin_right", 36)
	pad.add_theme_constant_override("margin_top", 24)
	pad.add_theme_constant_override("margin_bottom", 28)
	glass.add_child(pad)

	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 14)
	pad.add_child(body)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(head)
	_percent = MenuUI.label("٪۰", 34, MenuUI.GOLD, true)
	_percent.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_percent.add_theme_constant_override("shadow_offset_y", 2)
	head.add_child(_percent)
	_title = MenuUI.label("در حال بارگذاری", 30, MenuUI.TEXT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_title.add_theme_constant_override("shadow_offset_y", 2)
	head.add_child(_title)

	body.add_child(_build_bar())

	_status = MenuUI.label("", 20, MenuUI.MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.clip_text = true
	body.add_child(_status)
	# فقط وقتی شروعِ بازی به سرور نرسید دیده می‌شود (۴۸dp+، طلایی = اقدام)
	_retry_btn = MenuUI.button("تلاش دوباره", "gold", 22)
	_retry_btn.custom_minimum_size = Vector2(240, 64)
	_retry_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_retry_btn.visible = false
	_retry_btn.pressed.connect(_on_boot_retry_pressed)
	body.add_child(_retry_btn)
	body.add_child(_build_tip_row())
	return glass


## ردیفِ نکته: آیکن + یک جمله. آیکنِ نبود پنهان می‌شود و متن جایش را می‌گیرد.
func _build_tip_row() -> Control:
	_tip_row = HBoxContainer.new()
	_tip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_row.add_theme_constant_override("separation", 12)
	_tip_label = MenuUI.label("", 20, MenuUI.TEXT)
	_tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_tip_label.add_theme_constant_override("shadow_offset_y", 1)
	_tip_row.add_child(_tip_label)
	# آیکن‌های رنگیِ tip_* در ۴۰ پیکسل ریز و گنگ بودند
	_tip_icon = MenuUI.icon(null, 50.0, MenuUI.GOLD)
	_tip_row.add_child(_tip_icon)
	return _tip_row


func _next_tip(animate: bool) -> void:
	if _tip_label == null:
		return
	_tip_clock = 0.0
	if _tip_order.is_empty():
		_tip_order = TIPS.shuffled()
	_tip_pos = (_tip_pos + 1) % _tip_order.size()
	var i: int = _tip_order[_tip_pos]
	if _tip_tw != null and _tip_tw.is_valid():
		_tip_tw.kill()
	if not animate:
		_show_tip(i)
		_tip_row.modulate.a = 1.0
		return
	_tip_tw = create_tween()
	_tip_tw.tween_property(_tip_row, "modulate:a", 0.0, TIP_FADE)
	_tip_tw.tween_callback(_show_tip.bind(i))
	_tip_tw.tween_property(_tip_row, "modulate:a", 1.0, TIP_FADE)


func _show_tip(i: int) -> void:
	_tip_label.text = "نکته: " + TIPS.text(i)
	var tex := TIPS.icon(i)
	_tip_icon.texture = tex
	_tip_icon.visible = tex != null
	_tip_icon.modulate = Color.WHITE if TIPS.has_art(i) else MenuUI.GOLD


func _build_bar() -> Control:
	_track = Panel.new()
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.custom_minimum_size = Vector2(0, 26)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0, 0, 0, 0.55)
	tsb.set_border_width_all(1)
	tsb.border_color = Color(1, 1, 1, 0.14)
	tsb.set_corner_radius_all(13)
	tsb.shadow_color = Color(0, 0, 0, 0.35)
	tsb.shadow_size = 6
	tsb.shadow_offset = Vector2(0, 3)
	tsb.anti_aliasing = true
	_track.add_theme_stylebox_override("panel", tsb)

	# هاله/سایه‌ی زیرِ پرکننده
	_fill_glow = Panel.new()
	_fill_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0, 0, 0, 0)
	gsb.set_corner_radius_all(13)
	gsb.shadow_color = Color(1.0, 0.55, 0.12, 0.45)
	gsb.shadow_size = 12
	gsb.shadow_offset = Vector2(0, 2)
	_fill_glow.add_theme_stylebox_override("panel", gsb)
	_track.add_child(_fill_glow)

	_fill = ColorRect.new()
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fmat := ShaderMaterial.new()
	fmat.shader = FILL_SHADER
	_fill.material = fmat
	_fill.resized.connect(func() -> void: fmat.set_shader_parameter("rect_size", _fill.size))
	_track.add_child(_fill)

	for c in [_fill_glow, _fill]:
		c.anchor_left = 0.0
		c.anchor_top = 0.0
		c.anchor_bottom = 1.0
		c.anchor_right = 0.0
		c.offset_left = 3.0
		c.offset_top = 3.0
		c.offset_right = -3.0
		c.offset_bottom = -3.0
	return _track


func _spacer(vertical: bool, ratio: float) -> Control:
	var s := Control.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vertical:
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_stretch_ratio = ratio
	return s


## ناچ و گوشه‌های گرد: پنل داخلِ ناحیه‌ی امن می‌ماند، پس‌زمینه تا لبه می‌رود
func _apply_safe_area() -> void:
	if _safe == null:
		return
	var vp := get_viewport()
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var ratio := Vector2.ONE
	if win.x > 0 and win.y > 0:
		ratio = vp.get_visible_rect().size / win
	var left := 0.0
	var right := 0.0
	var bottom := 0.0
	if safe.size.x > 0 and safe.size.y > 0 and win.x > 0:
		left = maxf(safe.position.x, 0.0) * ratio.x
		right = maxf(win.x - safe.end.x, 0.0) * ratio.x
		bottom = maxf(win.y - safe.end.y, 0.0) * ratio.y
	_safe.add_theme_constant_override("margin_left", int(left) + 24)
	_safe.add_theme_constant_override("margin_right", int(right) + 24)
	_safe.add_theme_constant_override("margin_bottom", int(bottom) + 16)
