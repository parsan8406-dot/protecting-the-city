extends Control
class_name GameHUD
## کلِ رابطِ کاربریِ زمینِ بازی، به سبکِ عکسِ مرجع:
##
##   بالا-چپ     کارتِ پروفایل (CombatHUD) و زیرش «اهداف»
##   بالا-وسط    تایمر؛ چپش حریف‌های زنده، راستش هم‌تیمی‌های زنده (RoundHUD)
##   بالا-راست   پینگ + تنظیمات (آنلاین) یا توقف (بازی سریع)، زیرش مینی‌مپ
##   پایین-چپ    جوی‌استیک (virtual_joystick.gd — فقط جایش را این‌جا می‌دهیم)
##   پایین-راست  دکمه‌ی بزرگِ لیزر و دورش بمب، دویدن، سپر؛ کنارشان دو معجون
##               (درمانِ خودم و درمانِ تیمی)
##
## همه‌چیز در واحدِ «طراحی» با ارتفاعِ ۷۲۰ چیده می‌شود و کلِ لایه با ارتفاعِ
## واقعیِ صفحه بزرگ/کوچک می‌شود؛ عرض آزاد است، پس روی ۱۶:۹ تا ۲۱:۹ و ۴:۳ هر
## گروه به گوشه‌ی خودش می‌چسبد. روی گوشی فاصله‌ی ناچ/لبه‌ی گرد
## (get_display_safe_area) هم از هر طرف کنار گذاشته می‌شود.

signal ability_pressed(kind: String)
signal menu_pressed

const DESIGN_H := 720.0
const EDGE := 16.0

const LASER_D := 150.0
const SKILL_D := 84.0
const POTION_D := 78.0
const MENU_D := 62.0
const ARC_R := 142.0
const MINIMAP := 196.0

const COL_GOLD := Color(0.96, 0.78, 0.3)
const COL_TEXT := Color(0.95, 0.94, 0.9)

var profile: CombatHUD = null
var round_hud: Control = null
var objectives: VBoxContainer = null
var minimap: Control = null
var joystick: Control = null
## فقط «عملیات حذف شیطان»: جانِ تک‌تکِ بازیکن‌ها، زیرش نوارِ جانِ شیطان، و
## فلشِ راهنما روی لبه‌ی صفحه. تا وقتی سرور نگفته شیطانی هست، هر سه پنهان‌اند.
var squad_health: HudSquadHealth = null
var demon_bar: HudDemonBar = null
var demon_pointer: HudDemonPointer = null

var _root: Control = null
var _buttons: Dictionary = {}
var _menu_btn: HudAbilityButton = null
var _ping_box: HBoxContainer = null
var _ping_label: Label = null
var _ping_icon: HudIconRect = null
var _ping_timer := 0.0
var _last_pong := 0
## ۰ خوب، ۱ متوسط، ۲ بد/قطع — پینگ فقط با عوض شدنِ این «بیدار» می‌شود
var _ping_grade := -1
## کم‌رنگ کردنِ خودکارِ کارت، اهداف و پینگ وقتی چیزی عوض نشده  # C1
## (با preload، تا به کشِ class_nameِ ادیتور وابسته نباشد)
var focus: Node = null

## لایه‌ی قرمزِ لبه‌های صفحه: تیر خوردن (flash_damage) و جانِ کم (set_low_health)
const VIGNETTE_EDGE := Color(0.8, 0.0, 0.0, 0.55)
const FLASH_ALPHA := 0.5
const FLASH_TIME := 0.35
const LOW_ALPHA_MIN := 0.12
const LOW_ALPHA_MAX := 0.3
## نصفِ یک تپش (کم → زیاد)
const LOW_PULSE_TIME := 0.6
var _vignette: TextureRect = null
var _flash_tw: Tween = null
var _low_tw: Tween = null
var _low_health := false
var _flash_alpha := 0.0
var _pulse_alpha := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# اولین بچه، تا همه‌ی دکمه‌ها و پنل‌ها رویش کشیده شوند
	_build_vignette()

	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	profile = CombatHUD.new()
	profile.name = "CombatHUD"
	_root.add_child(profile)

	objectives = preload("res://scripts/hud_objectives.gd").new()
	objectives.name = "Objectives"
	_root.add_child(objectives)

	round_hud = preload("res://scripts/round_hud.gd").new()
	round_hud.name = "RoundHUD"
	_root.add_child(round_hud)

	minimap = preload("res://scripts/hud_minimap.gd").new()
	minimap.name = "Minimap"
	minimap.size = Vector2(MINIMAP, MINIMAP)
	_root.add_child(minimap)

	squad_health = preload("res://scripts/hud_squad_health.gd").new()
	squad_health.name = "SquadHealth"
	squad_health.visible = false
	# با کم و زیاد شدنِ بازیکن‌ها قدِ پنل عوض می‌شود و نوارِ شیطانِ زیرش
	# باید جابه‌جا شود
	squad_health.height_changed.connect(_layout)
	_root.add_child(squad_health)

	demon_bar = preload("res://scripts/hud_demon_bar.gd").new()
	demon_bar.name = "DemonBar"
	demon_bar.visible = false
	_root.add_child(demon_bar)

	# فلش عمداً بیرونِ _root است: _root با نسبتِ صفحه اسکیل می‌شود و فلش
	# باید با پیکسلِ واقعیِ صفحه کار کند تا لبه‌ی ناحیه‌ی امن را درست بگیرد.
	demon_pointer = preload("res://scripts/hud_demon_pointer.gd").new()
	demon_pointer.name = "DemonPointer"
	demon_pointer.visible = false
	add_child(demon_pointer)

	_build_top_right()
	_build_buttons()
	_build_focus()

	get_viewport().size_changed.connect(_layout)
	# چرخشِ ۱۸۰ درجه‌ای گوشی ناچ را آن طرف می‌برد بی‌آنکه اندازه عوض شود
	if not SafeArea.changed.is_connected(_layout):
		SafeArea.changed.connect(_layout)
	if not Network.ping_measured.is_connected(_on_pong):
		Network.ping_measured.connect(_on_pong)
	_layout()
	# اگر world.gd قبل از آماده شدنِ HUD «جانِ کم» گفته بود، همین حالا اعمال شود
	if _low_health:
		_apply_low_health()


# ============================ ساخت ============================

func _build_top_right() -> void:
	_ping_box = HBoxContainer.new()
	_ping_box.add_theme_constant_override("separation", 5)
	_ping_box.alignment = BoxContainer.ALIGNMENT_END
	_ping_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ping_icon = HudIconRect.new().setup("wifi", 22, Color(0.4, 0.9, 0.5))
	_ping_box.add_child(_ping_icon)
	_ping_label = Label.new()
	_ping_label.text = "--ms"
	_ping_label.add_theme_font_override("font", preload("res://fonts/Lalezar-Regular.ttf"))
	_ping_label.add_theme_font_size_override("font_size", 19)
	_ping_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	_ping_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_ping_label.add_theme_constant_override("shadow_offset_y", 1)
	_ping_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ping_box.add_child(_ping_label)
	_root.add_child(_ping_box)
	# بازیِ سریع آفلاین است؛ پینگ آن‌جا معنی ندارد
	_ping_box.visible = not Global.offline_mode

	# آنلاین فقط تنظیمات (بازی متوقف نمی‌شود)، بازیِ سریع فقط توقف
	var icon := "pause" if Global.offline_mode else "settings"
	_menu_btn = HudAbilityButton.new().setup(icon, MENU_D)
	_menu_btn.name = "PauseButton" if Global.offline_mode else "SettingsButton"
	_menu_btn.activated.connect(func(): menu_pressed.emit())
	_root.add_child(_menu_btn)


## C1 cognitive load: وسطِ درگیری فقط چیزی پررنگ است که همین الان عوض شده
## یا بحرانی است؛ بقیه کم‌رنگ ولی خوانا می‌مانند. تایمر، مینی‌مپ و دکمه‌ها
## هیچ‌وقت کم‌رنگ نمی‌شوند.
func _build_focus() -> void:
	focus = preload("res://scripts/psych_hud_focus.gd").new()
	focus.name = "Focus"
	add_child(focus)
	focus.track(profile, 0.55, 3.0)
	focus.track(objectives, 0.5, 4.0)
	focus.track(_ping_box, 0.45, 2.5)
	profile.readout_changed.connect(func(critical: bool):
		# جان/خشابِ پر کم‌رنگ‌تر از نیمه‌پر  # C1
		focus.set_idle_alpha(profile, 0.55 if profile.is_calm() else 0.8)
		focus.wake(profile, critical))
	if objectives.has_signal("activity"):
		objectives.activity.connect(func(near: bool):
			# هدفی که نزدیکِ تمام شدن است کم‌رنگ‌تر از بقیه نمی‌شود  # C9
			focus.set_idle_alpha(objectives, 0.75 if near else 0.5)
			focus.wake(objectives))


func _build_buttons() -> void:
	# لیزر: دکمه‌ی بزرگِ اصلی
	_add_button("laser", "laser", LASER_D, Color(1.0, 0.72, 0.22), true)
	_add_button("bomb", "bomb", SKILL_D, Color(1.0, 0.62, 0.25))
	_add_button("sprint", "run", SKILL_D, Color(0.35, 0.8, 1.0))
	_add_button("guard", "shield", SKILL_D, Color(1.0, 0.84, 0.3))
	# دو معجونِ کنارِ هم: قرمز برای خودم، سبز برای تیم (همرنگِ آرتِ معجون‌ها)
	_add_button("heal", "heal", POTION_D, Color(0.95, 0.3, 0.3))
	_add_button("team_heal", "team_heal", POTION_D, Color(0.45, 0.92, 0.35))
	_buttons["bomb"].set_badge(Abilities.BOMB_STOCK)
	# C3 Fitts: لمس بزرگ‌تر از ظاهر، ولی کمتر از نصفِ فاصله تا همسایه
	_buttons["laser"].touch_pad = 14.0
	_menu_btn.touch_pad = 10.0


func _add_button(kind: String, icon: String, d: float, accent: Color, hero := false) -> void:
	var b := HudAbilityButton.new().setup(icon, d, accent, hero)
	b.name = kind.capitalize().replace(" ", "") + "Button"
	b.activated.connect(func(): ability_pressed.emit(kind))
	_root.add_child(b)
	_buttons[kind] = b


# ============================ API ============================

func button(kind: String) -> HudAbilityButton:
	return _buttons.get(kind, null)


## مقیاسِ لایه نسبت به طراحیِ ۷۲۰
func ui_scale() -> float:
	return clampf(get_viewport_rect().size.y / DESIGN_H, 0.6, 2.4)


## نوارِ شیطان و فلشِ راهنما — فقط در «عملیات حذف شیطان».
##
## world.gd با اولین پیامِ demon_state روشنش می‌کند و با مرگِ شیطان
## خاموش. بقیه‌ی حالت‌ها اصلاً صدایش نمی‌زنند، پس هیچ‌وقت دیده نمی‌شود.
func set_demon_visible(on: bool) -> void:
	if squad_health != null:
		squad_health.visible = on
	if demon_bar != null:
		demon_bar.visible = on
	if demon_pointer != null:
		demon_pointer.visible = on
	if on:
		_layout()


## دکمه‌های گیم‌پلی (موقعِ تماشا بعد از مرگ پنهان می‌شوند)
func set_controls_visible(on: bool) -> void:
	for b in _buttons.values():
		b.visible = on
	if joystick != null and joystick.has_method("set_enabled"):
		joystick.set_enabled(on)


# ============================ چیدمان ============================

func _layout() -> void:
	var s := ui_scale()
	var vp := get_viewport_rect().size
	_root.scale = Vector2(s, s)
	_root.size = vp / s
	var W := _root.size.x
	var H := _root.size.y
	var ins := _safe_insets() / s
	var left := maxf(ins.x, EDGE)
	var top := maxf(ins.y, 10.0)
	var right := maxf(ins.z, EDGE)
	var bottom := maxf(ins.w, 10.0)

	# --- بالا-چپ ---
	# روی صفحه‌ی باریک (۴:۳) کارت کمی کوچک می‌شود تا به تایمر نخورد
	var plate_w: float = round_hud.PLATE_W
	var room := W * 0.5 - plate_w * 0.5 - 12.0 - left
	var pk := clampf(room / CombatHUD.panel_w(), 0.72, 1.0)
	profile.scale = Vector2(pk, pk)
	profile.position = Vector2(left, top)
	objectives.position = Vector2(left, top + CombatHUD.panel_h() * pk + 10.0)

	# --- بالا-وسط ---
	round_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	round_hud.top_inset = top

	# زیرِ قابِ تایمر، از بالا به پایین: جانِ بازیکن‌ها، بعد جانِ شیطان.
	#
	# ترتیب عمدی است: جانِ خودت و تیمت چیزی است که هر ثانیه تصمیمت را عوض
	# می‌کند (بروم جلو یا عقب بکشم)، جانِ شیطان تصمیمِ بلندمدت است. پس
	# نزدیک‌ترین به مرکزِ صفحه باید تیم باشد.
	#
	# هر دو روی صفحه‌ی باریک (۴:۳) به‌اندازه‌ی جای موجود کوچک می‌شوند تا به
	# کارتِ پروفایل/«اهداف» (چپ) و مینی‌مپ (راست) نخورند: هر دو هم‌ارتفاعِ
	# همین پنل‌ها هستند، پس جای مجاز فقط باریکه‌ی بینِ آن دوتاست.
	var stack_y: float = top + float(round_hud.PLATE_H) + 6.0
	var objectives_w: float = maxf(objectives.size.x, objectives.get_combined_minimum_size().x)
	var lane_l: float = left + maxf(CombatHUD.panel_w() * pk, objectives_w) + 12.0
	var lane_r: float = W - right - MINIMAP - 12.0
	var room_w: float = maxf(lane_r - lane_l, 0.0)
	if squad_health != null and squad_health.visible:
		var sk: float = clampf(room_w / HudSquadHealth.PANEL_W, 0.62, 1.0)
		squad_health.scale = Vector2(sk, sk)
		squad_health.position = Vector2(
			_lane_x(HudSquadHealth.PANEL_W * sk, lane_l, lane_r, W), stack_y)
		stack_y += squad_health.panel_h() * sk + 5.0
	if demon_bar != null and demon_bar.visible:
		var dk: float = clampf(room_w / HudDemonBar.BAR_W, 0.62, 1.0)
		demon_bar.scale = Vector2(dk, dk)
		demon_bar.position = Vector2(
			_lane_x(HudDemonBar.BAR_W * dk, lane_l, lane_r, W), stack_y)

	# --- بالا-راست ---
	_menu_btn.position = Vector2(W - right - MENU_D, top)
	_ping_box.size = Vector2(130, MENU_D)
	_ping_box.position = Vector2(_menu_btn.position.x - 136.0, top)
	minimap.position = Vector2(W - right - MINIMAP, top + MENU_D + 8.0)

	# --- پایین-راست: لیزر و کمانِ دکمه‌ها ---
	var laser_c := Vector2(W - right - LASER_D * 0.5 - 6.0, H - bottom - LASER_D * 0.5 - 6.0)
	_place("laser", laser_c)
	_place("bomb", laser_c + Vector2.from_angle(deg_to_rad(-95.0)) * ARC_R)
	_place("sprint", laser_c + Vector2.from_angle(deg_to_rad(-137.5)) * ARC_R)
	_place("guard", laser_c + Vector2.from_angle(deg_to_rad(-180.0)) * ARC_R)
	var potion_y := H - bottom - POTION_D * 0.5 - 4.0
	var guard_x: float = laser_c.x - ARC_R
	_place("heal", Vector2(guard_x - 100.0, potion_y))
	# فاصله‌ی ۲۰ بینِ دو معجون تا شستِ عجول دومی را نزند  # C3 / C13
	_place("team_heal", Vector2(guard_x - 100.0 - POTION_D - 20.0, potion_y))

	# --- پایین-چپ: جوی‌استیک (خارج از این لایه؛ به پیکسلِ صفحه) ---
	if joystick != null and joystick.has_method("configure"):
		var rest := Vector2(left + 130.0, H - bottom - 124.0) * s
		joystick.configure(rest, s)


func _place(kind: String, centre: Vector2) -> void:
	var b: HudAbilityButton = _buttons[kind]
	b.position = centre - b.size * 0.5


## جای افقیِ پنل‌های زیرِ تایمر: وسطِ صفحه اگر داخلِ باریکه‌ی مجاز جا شود،
## وگرنه تا جایی که لازم است به داخلِ باریکه هل داده می‌شود.
func _lane_x(w: float, lane_l: float, lane_r: float, full_w: float) -> float:
	var x := (full_w - w) * 0.5
	if lane_r - lane_l >= w:
		return clampf(x, lane_l, lane_r - w)
	return lane_l + (lane_r - lane_l - w) * 0.5


## فاصله‌ی ناچ و لبه‌های خمیده (چپ، بالا، راست، پایین) به پیکسلِ viewport.
## فقط روی گوشی؛ حسابش در autoloadِ SafeArea است تا همه‌ی صفحه‌ها یکی باشند.
func _safe_insets() -> Vector4:
	return SafeArea.insets_for(self)


# ============================ لبه‌ی قرمزِ آسیب ============================

## بافتِ شعاعی: وسط کاملاً شفاف، لبه‌ها قرمز. فقط یک TextureRect و یک
## گرادیانِ کوچک — روی گوشیِ ضعیف هم هزینه‌ای ندارد (شیدر لازم نیست).
func _build_vignette() -> void:
	if _vignette != null:
		return
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([
		Color(VIGNETTE_EDGE.r, VIGNETTE_EDGE.g, VIGNETTE_EDGE.b, 0.0),
		Color(VIGNETTE_EDGE.r, VIGNETTE_EDGE.g, VIGNETTE_EDGE.b, 0.0),
		VIGNETTE_EDGE])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	# شعاعِ ۰٫۵: وسطِ هر لبه کاملاً قرمز، گوشه‌ها هم (بیرون از شعاع) همان رنگِ آخر
	tex.fill_to = Vector2(0.5, 0.0)

	_vignette = TextureRect.new()
	_vignette.name = "DamageVignette"
	_vignette.texture = tex
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	_vignette.visible = false
	add_child(_vignette)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## تیر خوردن: لبه‌ها یک لحظه قرمز می‌شوند و زود محو.
## world.gd هر جا صدایش بزند امن است، حتی قبل از آماده شدنِ HUD.
func flash_damage() -> void:
	if _vignette == null or not is_inside_tree():
		return
	if _flash_tw != null and _flash_tw.is_valid():
		_flash_tw.kill()
	_flash_tw = create_tween()
	_flash_tw.tween_method(_set_flash_alpha, FLASH_ALPHA, 0.0, FLASH_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## جانِ کم: تپشِ آرام و دائمیِ لبه‌ها تا جان برگردد (یا بازیکن بمیرد).
## world.gd ممکن است هر فریم صدایش بزند؛ تکرارِ همان مقدار کاری نمی‌کند.
func set_low_health(low: bool) -> void:
	if low == _low_health:
		return
	_low_health = low
	if _vignette == null or not is_inside_tree():
		return   # _ready خودش اعمال می‌کند
	_apply_low_health()


func _apply_low_health() -> void:
	if _low_tw != null and _low_tw.is_valid():
		_low_tw.kill()
	_low_tw = create_tween()
	if _low_health:
		_low_tw.set_loops()
		_low_tw.tween_method(_set_pulse_alpha, LOW_ALPHA_MIN, LOW_ALPHA_MAX, LOW_PULSE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_low_tw.tween_method(_set_pulse_alpha, LOW_ALPHA_MAX, LOW_ALPHA_MIN, LOW_PULSE_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		_low_tw.tween_method(_set_pulse_alpha, _pulse_alpha, 0.0, 0.3)


func _set_flash_alpha(a: float) -> void:
	_flash_alpha = a
	_update_vignette()


func _set_pulse_alpha(a: float) -> void:
	_pulse_alpha = a
	_update_vignette()


## دو منبع (ضربه و جانِ کم) روی یک لایه: هرکدام قوی‌تر است دیده می‌شود
func _update_vignette() -> void:
	if _vignette == null:
		return
	var a := maxf(_flash_alpha, _pulse_alpha)
	_vignette.modulate.a = a
	_vignette.visible = a > 0.005


# ============================ پینگ ============================

func _process(delta: float) -> void:
	if Global.offline_mode:
		return
	_ping_timer -= delta
	if _ping_timer <= 0.0:
		_ping_timer = 2.0
		Network.send_ping()
		# پنج ثانیه بی‌جواب یعنی ارتباط قطع است
		if _last_pong > 0 and Time.get_ticks_msec() - _last_pong > 5000:
			_show_ping(-1)


func _on_pong(ms: int) -> void:
	_last_pong = Time.get_ticks_msec()
	_show_ping(ms)


func _show_ping(ms: int) -> void:
	var col := Color(0.4, 0.9, 0.5)
	if ms < 0:
		col = Color(0.95, 0.3, 0.3)
		_ping_label.text = "قطع"
	else:
		if ms >= 160:
			col = Color(0.95, 0.3, 0.3)
		elif ms >= 80:
			col = Color(0.98, 0.8, 0.3)
		_ping_label.text = "%dms" % ms
	_ping_label.add_theme_color_override("font_color", col)
	_ping_icon.set_tint(col)
	# پینگِ خوب کم‌رنگ است؛ بد شدنش روشن و بحرانی  # C1
	var grade := 2 if (ms < 0 or ms >= 160) else (1 if ms >= 80 else 0)
	if focus != null and grade != _ping_grade:
		_ping_grade = grade
		focus.wake(_ping_box, grade == 2)
