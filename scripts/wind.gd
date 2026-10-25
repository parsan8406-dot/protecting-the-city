extends Node2D
## بادِ دوره‌ایِ زمینِ بازی و برگ‌هایی که با خودش می‌آورد.
##
## هر زمین (Arena) موقعِ ساختنِ نقشه یکی از این‌ها را می‌سازد، پس هر سه
## نقشه‌ی بازی — و هر نقشه‌ای که بعداً اضافه شود — خودبه‌خود باد دارد.
##
## چرخه: زمین مدتی آرام است (calm_min..calm_max)، بعد یک وزش می‌آید
## (gust_min..gust_max) که شدتش نرم بالا می‌آید، وسطش نبض می‌زند و نرم‌تر از
## آن‌که آمده می‌خوابد. برگ‌ها فقط وقتی باد هست زاده می‌شوند؛ وقتی باد
## می‌خوابد آن‌هایی که در هوا مانده‌اند آرام می‌ایستند و با پایانِ عمرشان
## محو می‌شوند — هیچ برگی وسطِ هوا قفل نمی‌ماند.
##
## چرا نوارِ تولدِ ذره‌ها به دوربین چسبیده و نه به کلِ زمین: زمین ۲۰۰۰x۱۱۲۰
## است ولی دوربینِ بازی (zoom = 2) فقط حدودِ ۹۶۰x۵۴۰ از آن را نشان می‌دهد.
## اگر برگ‌ها روی کلِ زمین پخش شوند سه‌چهارمشان بیرونِ کادر می‌افتند و روی
## صفحه تقریباً هیچ برگی دیده نمی‌شود — یا باید تعدادشان را چند برابر کرد که
## روی موبایل گران است. پس نوارِ تولد هر فریم روی لبه‌ی بالادستِ همین کادر
## می‌ایستد و برگ از «بیرونِ صفحه» وارد می‌شود. چون local_coords خاموش است،
## ذره بعد از تولد دیگر دنبالِ نود نمی‌رود و در مختصاتِ جهان زندگی می‌کند.
##
## خودِ باد هم دیده می‌شود: چند خطِ پیچانِ کم‌رنگ (assets/wind_swirl_*.png)
## که با وزش از لبه‌ی بالادست وارد می‌شوند و سرشان مثلِ نقاشی‌های باد در یک
## مارپیچ جمع است. این‌ها ذره نیستند — چند Sprite2D از یک استخرِ کوچک‌اند که
## دستی جابه‌جا و محو می‌شوند، چون تعدادشان کم و مسیرشان ساده است و یک
## سیستمِ ذره برایشان زیادی است.
##
## عمق: برگ‌های دور زیرِ دیوارها (z=3) کفِ زمین سُر می‌خورند و برگ‌های نزدیک
## بالای سرِ بازیکن‌ها (z=12) رد می‌شوند. همین دو لایه کافی است تا باد تخت
## به نظر نرسد.
##
## این افکت کاملاً ظاهری است: نه برخورد دارد، نه نیرویی به بازیکن و تیر
## وارد می‌کند. پس کلاینت و سرور هیچ‌جا از هم جدا نمی‌شوند.
##
## سبک روی موبایل: دو-سه CPUParticles2D که فقط در لحظه‌ی وزش فعال‌اند و در
## اوج هم رویِ‌هم ~۵۰ ذره دارند. بینِ وزش‌ها emitting خاموش است.

## برگِ نزدیک و برگِ دور. هر دو از assets/Leaf.png ساخته شده‌اند:
##   python tools/make_leaf_textures.py
const LEAF_NEAR_TEX := "res://assets/leaf_a.png"
const LEAF_FAR_TEX := "res://assets/leaf_b.png"
## همان بافتِ گردِ نرمی که Arena و CombatFX هم استفاده می‌کنند
const DUST_TEX := "res://assets/lightall.png"
## خطوطِ پیچانِ باد:  python tools/make_wind_swirls.py
const SWIRL_SHADER := preload("res://shaders/wind_swirl.gdshader")
const SWIRL_TEX := [
	"res://assets/wind_swirl_1.png",
	"res://assets/wind_swirl_2.png",
	"res://assets/wind_swirl_3.png",
]

## برگِ نزدیک بالای بازیکن (z=10)، برگِ دور زیرِ دیوار (z=4) و روی بک‌گراند (z=0)
const Z_NEAR := 12
const Z_FAR := 3
const Z_DUST := 11
## خطوطِ باد زیرِ برگ‌های نزدیک‌اند تا برگ رویشان دیده شود
const Z_SWIRL := 11

## بیشترین کجیِ باد از افق (رادیان، ~۱۱ درجه). باد کمابیش افقی است؛ بال‌زدنِ
## برگ از spread و tangential_accel می‌آید نه از کجِ‌بودنِ خودِ باد.
const TILT_MAX := 0.20
## نوارِ تولد این‌قدر بیرونِ کادر می‌ایستد تا برگ از بیرونِ صفحه وارد شود
const BAND_MARGIN := 90.0
## ضخامتِ نوارِ تولد در راستای باد (نیم‌طول)
const BAND_THICK := 26.0
## شدتِ باد این‌قدر ثانیه طول می‌کشد تا از ۰ به اوج برسد، و این‌قدر تا بخوابد.
## خوابیدن کندتر از آمدن است — بادِ واقعی هم همین‌طور می‌رود.
const RISE := 1.1
const FALL := 2.6
## زیرِ این شدت، وزش آن‌قدر ضعیف است که برگِ تازه نزاید
const LIVE_AT := 0.05
## خطِ پیچانِ باد فقط وقتی رها می‌شود که وزش واقعاً گرفته باشد
const SWIRL_AT := 0.25

@export var enabled := true

## --- زمان‌بندیِ وزش‌ها ---
## فاصله‌ی دو وزش (ثانیه)
@export_range(1.0, 90.0) var calm_min := 9.0
@export_range(1.0, 90.0) var calm_max := 17.0
## طولِ هر وزش (ثانیه) — شاملِ بالا آمدن و خوابیدنش
@export_range(1.0, 30.0) var gust_min := 3.4
@export_range(1.0, 30.0) var gust_max := 6.2
## اولین وزش این‌قدر بعد از شروعِ راند می‌آید، نه توی ثانیه‌های شلوغِ اول
@export_range(0.0, 60.0) var first_gust_delay := 6.0

## --- شدت ---
## سرعتِ اوجِ یک وزش (واحدِ جهانی بر ثانیه). بازیکن با ~۴۰۰ می‌دود.
@export_range(60.0, 1400.0) var speed_min := 300.0
@export_range(60.0, 1400.0) var speed_max := 640.0

## --- ذره‌ها ---
@export_range(0, 60) var leaves_near := 28
@export_range(0, 60) var leaves_far := 20
## گردوخاکِ ریزی که با وزش بلند می‌شود. روی گوشی‌های ضعیف می‌شود خاموشش کرد.
@export var show_dust := true
@export_range(0, 40) var dust_amount := 14

## --- خطوطِ پیچانِ باد ---
@export var show_swirls := true
## بیش‌ترین تعدادِ خطِ هم‌زمان روی صفحه
@export_range(0, 8) var swirl_max := 3
## پررنگیِ اوجِ خطوط. عمداً کم است: باد باید حس شود، نه اینکه روی صفحه بنشیند.
@export_range(0.0, 1.0) var swirl_alpha := 0.22
## اندازه‌ی خط نسبت به بافتِ ۵۱۲ پیکسلی — ~۱/۳ عرضِ کادر
@export_range(0.2, 2.0) var swirl_scale_min := 0.60
@export_range(0.2, 2.0) var swirl_scale_max := 1.15

## تاریکیِ محیطِ زمین. Arena همان actor_tintِ خودش را می‌دهد تا برگ‌ها نه
## توی تاریکی گم شوند نه مثلِ لامپ بدرخشند.
var tint := Color(0.46, 0.45, 0.52)
## تمِ زمین — رنگِ برگ از آن می‌آید (ThemeArt.leaf_colors)
var theme := ""
## اندازه‌ی زمین؛ فقط برای فریم‌هایی که هنوز دوربینی جا نیفتاده
var world_size := Vector2(2000, 1120)
## بذرِ الگوی باد. Arena شناسه‌ی مسابقه را می‌دهد تا همه‌ی بازیکن‌های یک
## مسابقه کمابیش یک باد ببینند. خالی = تصادفی.
var seed_text := ""

var _near: CPUParticles2D = null
var _far: CPUParticles2D = null
var _dust: CPUParticles2D = null
## استخرِ خطوطِ باد: {spr, mat, life, max_life, vel, a0, grow, spin, tail}
var _swirls: Array[Dictionary] = []
var _swirl_wait := 0.0
var _swirl_color := Color(1, 1, 1)
var _rng := RandomNumberGenerator.new()

## نوارِ تولدِ همین فریم (لبه‌ی بالادستِ کادرِ دوربین)
var _band_pos := Vector2.ZERO
var _band_ext := Vector2.ZERO
var _band_perp := Vector2.DOWN
var _band_span := 0.0
var _band_reach := 0.0

var _gusting := false
## تا وزشِ بعدی (در آرامش) یا تا پایانِ وزشِ جاری (در وزش)
var _timer := 0.0
## شدتِ خام ۰..۱ — با move_toward به هدف می‌رسد
var _strength := 0.0
## اوجِ شدتِ همین وزش و سرعتِ متناظرش
var _peak := 0.0
var _peak_speed := 0.0
var _dir := Vector2.RIGHT
## نبضِ داخلِ وزش: باد یک‌نواخت نمی‌وزد
var _pulse_phase := 0.0
var _pulse_rate := 1.6


func _ready() -> void:
	# همه‌ی بازیکن‌های یک مسابقه یک الگو ببینند. ساعتِ مشترکی با سرور در کار
	# نیست، پس وزش‌ها ممکن است یکی-دو ثانیه از هم عقب بیفتند؛ برای افکتی که
	# هیچ‌چیزِ گیم‌پلی به آن بند نیست کافی است.
	if seed_text != "":
		_rng.seed = hash(seed_text)
	else:
		_rng.randomize()

	_timer = first_gust_delay
	var c: Array = ThemeArt.leaf_colors(theme)
	var fresh: Color = c[0] * tint
	var dry: Color = c[1] * tint

	_near = _make_leaves(leaves_near, LEAF_NEAR_TEX, Z_NEAR, 3.6,
			0.11, 0.20, fresh, dry, 0.95)
	# برگِ دور کوچک‌تر، کم‌رنگ‌تر و دیرپاتر است تا کندتر به نظر برسد
	_far = _make_leaves(leaves_far, LEAF_FAR_TEX, Z_FAR, 4.6,
			0.07, 0.13, fresh * 0.8, dry * 0.8, 0.72)
	if show_dust and dust_amount > 0:
		_dust = _make_dust()
	if show_swirls and swirl_max > 0:
		# خطِ باد سفیدِ کم‌رنگ است و فقط کمی به رنگِ تم می‌زند، وگرنه در تمِ
		# جهنمی نارنجی و در تمِ یخی آبی می‌شود و دیگر «باد» نیست.
		_swirl_color = Color(1, 1, 1).lerp(c[0] as Color, 0.35)
		_build_swirls()

	set_process(enabled)


## یک لایه‌ی برگ. scale از روی بافتِ ۹۶ پیکسلی حساب شده: ۰.۱۵ یعنی برگِ
## ~۱۴ واحدِ جهانی، حدودِ یک‌هشتمِ قدِ بازیکن.
func _make_leaves(amount: int, tex_path: String, z: int, life: float,
		scale_min: float, scale_max: float, fresh: Color, dry: Color,
		alpha: float) -> CPUParticles2D:
	if amount <= 0:
		return null
	var p := _base_particles(amount, z, life)
	p.texture = _tex(tex_path)
	p.scale_amount_min = scale_min
	p.scale_amount_max = scale_max
	# برگ با هر زاویه‌ای می‌افتد و دورِ خودش می‌چرخد
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -210.0
	p.angular_velocity_max = 210.0
	# بال‌زدن: شتابِ عمود بر مسیر، پس برگ صاف نمی‌رود
	p.tangential_accel_min = -55.0
	p.tangential_accel_max = 55.0
	# بدونِ این، برگ بعد از خوابیدنِ باد تا آخرِ عمرش شناور می‌ماند
	p.damping_min = 0.4
	p.damping_max = 1.6
	p.spread = 22.0
	p.color_ramp = _ramp(fresh, dry, alpha)
	add_child(p)
	return p


## گردوخاکِ ریز: نقطه‌های محوی که با وزش بلند می‌شوند. جمع‌شونده‌اند
## (BLEND_MODE_ADD) تا کنارِ مشعل‌ها برق بزنند و در تاریکیِ محض دیده نشوند.
func _make_dust() -> CPUParticles2D:
	var p := _base_particles(dust_amount, Z_DUST, 1.5)
	p.texture = _tex(DUST_TEX)
	p.scale_amount_min = 0.02
	p.scale_amount_max = 0.05
	p.spread = 30.0
	p.damping_min = 0.8
	p.damping_max = 2.2
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = m
	var warm := Color(0.85, 0.74, 0.55)
	p.color_ramp = _ramp(warm, warm, 0.09)
	add_child(p)
	return p


## استخرِ خطوط یک بار ساخته می‌شود و بعد فقط جابه‌جا و محو می‌شود — نه نودِ
## تازه‌ای ساخته می‌شود نه چیزی free می‌شود.
func _build_swirls() -> void:
	for i in swirl_max:
		var spr := Sprite2D.new()
		spr.texture = _tex(str(SWIRL_TEX[i % SWIRL_TEX.size()]))
		spr.z_index = Z_SWIRL
		spr.z_as_relative = false
		spr.visible = false
		# شیدر خط را از ته به نوک می‌کشد و بعد از ته جمع می‌کند. هر خط
		# متریالِ خودش را دارد چون head هرکدام جداگانه جلو می‌رود.
		var m := ShaderMaterial.new()
		m.shader = SWIRL_SHADER
		m.set_shader_parameter("head", -1.0)
		m.set_shader_parameter("tail", 0.55)
		m.set_shader_parameter("edge", 0.07)
		spr.material = m
		add_child(spr)
		_swirls.append({"spr": spr, "mat": m, "life": 0.0, "max_life": 0.0,
			"vel": Vector2.ZERO, "a0": 0.0, "grow": 0.0, "spin": 0.0,
			"tail": 0.55})


## یک خطِ آزاد را از لبه‌ی بالادست رها می‌کند
func _spawn_swirl(s: float) -> void:
	var slot: Dictionary = {}
	for w in _swirls:
		if float(w["max_life"]) <= 0.0:
			slot = w
			break
	if slot.is_empty():
		return

	var spr: Sprite2D = slot["spr"]
	# هر بار یکی از سه شکل، گاهی وارونه — سه وزشِ پشتِ هم کپیِ هم نشوند
	spr.texture = _tex(str(SWIRL_TEX[_rng.randi() % SWIRL_TEX.size()]))
	spr.flip_v = _rng.randf() < 0.5
	# خط در راستای باد کشیده می‌شود؛ اگر باد به چپ برود بافت هم باید برگردد
	spr.rotation = _dir.angle() + _rng.randf_range(-0.10, 0.10)
	var sc := _rng.randf_range(swirl_scale_min, swirl_scale_max)
	spr.scale = Vector2(sc, sc)
	# جایی تصادفی روی همان نوارِ تولدِ برگ‌ها
	spr.global_position = _band_pos + _band_perp * _rng.randf_range(-_band_span, _band_span)
	spr.visible = true

	# سرعت از اوجِ همین وزش می‌آید نه از شدتِ همین لحظه — خطِ باد یک تکه از
	# جریانِ باد است و وسطِ راه با نبضِ وزش کُند و تند نمی‌شود.
	var v := _peak_speed * maxf(s, 0.55) * 1.15 * _rng.randf_range(0.9, 1.3)
	slot["vel"] = _dir * v
	slot["life"] = 0.0
	# آن‌قدر که کادر را رد کند، ولی نه بی‌نهایت اگر باد کُند باشد
	slot["max_life"] = clampf(2.3 * _band_reach / maxf(v, 1.0), 0.9, 3.6)
	# sqrt: وزشِ ملایم هم خطش دیده شود، ولی پررنگیِ اوج از کنترل بیرون نرود
	slot["a0"] = swirl_alpha * sqrt(s)
	slot["grow"] = _rng.randf_range(0.05, 0.18)
	# چرخشِ آرامِ خودِ خط در حینِ رفتن — همان «پیچیدنِ» باد
	slot["spin"] = _rng.randf_range(-0.38, 0.38)
	var tail := _rng.randf_range(0.42, 0.78)
	slot["tail"] = tail
	var mat: ShaderMaterial = slot["mat"]
	mat.set_shader_parameter("tail", tail)
	mat.set_shader_parameter("head", -0.02)


## خطوط را جلو می‌برد و محو می‌کند. عمداً مستقل از شدتِ لحظه‌ای است: خطی که
## آخرِ وزش رها شده باید راهش را تمام کند، نه اینکه وسطِ هوا خاموش شود.
func _step_swirls(delta: float) -> void:
	for w in _swirls:
		var max_life := float(w["max_life"])
		if max_life <= 0.0:
			continue
		var spr: Sprite2D = w["spr"]
		var life := float(w["life"]) + delta
		if life >= max_life:
			w["max_life"] = 0.0
			spr.visible = false
			continue
		w["life"] = life

		var f := life / max_life
		spr.global_position += (w["vel"] as Vector2) * delta
		# خط در مسیرش کمی باز می‌شود و آرام می‌چرخد، مثل وزشی که می‌پیچد
		spr.scale *= 1.0 + float(w["grow"]) * delta
		spr.rotation += float(w["spin"]) * delta
		# سرِ خط از ته تا آن‌سویِ نوک می‌رود: اول کشیده می‌شود، بعد از ته
		# جمع می‌شود. کلِ رفت‌وبرگشت در طولِ عمرِ همین خط جا می‌شود.
		var tail := float(w["tail"])
		(w["mat"] as ShaderMaterial).set_shader_parameter(
			"head", -0.02 + f * (1.04 + tail))
		# یک محوِ کلی هم رویش هست تا لحظه‌ی تولد و مرگ هیچ‌جا نپرد
		var env := smoothstep(0.0, 0.10, f) * (1.0 - smoothstep(0.88, 1.0, f))
		spr.modulate = Color(_swirl_color.r, _swirl_color.g, _swirl_color.b,
			float(w["a0"]) * env)


func _base_particles(amount: int, z: int, life: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.amount = amount
	p.lifetime = life
	p.lifetime_randomness = 0.35
	# 🌟 ذره بعد از تولد در مختصاتِ جهان می‌ماند. بدونِ این، نوارِ تولد که هر
	# فریم دنبالِ دوربین می‌رود همه‌ی برگ‌ها را هم با خودش می‌کشد و باد
	# «چسبیده به صفحه» می‌شود.
	p.local_coords = false
	p.z_index = z
	p.z_as_relative = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(BAND_THICK, world_size.y * 0.5)
	return p


func _tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		push_warning("Wind: بافت نیست: " + path)
		return null
	return load(path) as Texture2D


## آلفا از صفر بالا می‌آید و در انتها به صفر برمی‌گردد، وگرنه برگ‌ها وسطِ
## هوا ظاهر و ناپدید می‌شوند.
func _ramp(from: Color, to: Color, alpha: float) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.14, 0.72, 1.0])
	g.colors = PackedColorArray([
		Color(from.r, from.g, from.b, 0.0),
		Color(from.r, from.g, from.b, alpha),
		Color(to.r, to.g, to.b, alpha),
		Color(to.r, to.g, to.b, 0.0),
	])
	return g


func _process(delta: float) -> void:
	_advance(delta)

	# smoothstep روی شدتِ خام: دو سرِ وزش نرم می‌شود بدونِ منحنیِ جداگانه
	var s := _strength * _strength * (3.0 - 2.0 * _strength)
	if s > 0.0:
		_pulse_phase += delta * _pulse_rate
		s *= 0.82 + 0.18 * sin(_pulse_phase)

	var speed := _peak_speed * s
	if s > LIVE_AT:
		_update_band()
	_drive(_near, s, speed)
	_drive(_far, s, speed * 0.62)
	_drive(_dust, s, speed * 1.2)

	if not _swirls.is_empty():
		# خطِ باد تندتر از برگ می‌رود — برگ را باد می‌برد، خط خودِ باد است
		_feed_swirls(delta, s)
		_step_swirls(delta)


## هر چند وقت یک خطِ تازه رها می‌کند؛ وزشِ تندتر خطِ بیشتری دارد.
##
## زیرِ SWIRL_AT خطی رها نمی‌شود: سرِ رمپ سرعتِ باد هنوز نزدیکِ صفر است و
## خطی که آن‌جا زاده شود عملاً سرِ جایش می‌ماند تا عمرش تمام شود.
func _feed_swirls(delta: float, s: float) -> void:
	if s <= SWIRL_AT:
		return
	_swirl_wait -= delta
	if _swirl_wait > 0.0:
		return
	_swirl_wait = _rng.randf_range(0.35, 0.95) / maxf(s, 0.3)
	_spawn_swirl(s)


## چرخه‌ی آرامش ← وزش ← آرامش و شدتی که نرم دنبالش می‌رود
func _advance(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		if _gusting:
			_gusting = false
			_timer = _rng.randf_range(calm_min, calm_max)
		else:
			_begin_gust()

	var target := _peak if _gusting else 0.0
	var rate := (1.0 / RISE) if target > _strength else (1.0 / FALL)
	_strength = move_toward(_strength, target, delta * rate)


func _begin_gust() -> void:
	_gusting = true
	_timer = _rng.randf_range(gust_min, gust_max)
	# چپ یا راست، با کجیِ کمی به بالا یا پایین
	var way := 1.0 if _rng.randf() < 0.5 else -1.0
	var tilt := _rng.randf_range(-TILT_MAX, TILT_MAX)
	_dir = Vector2(way * cos(tilt), sin(tilt)).normalized()
	_peak = _rng.randf_range(0.62, 1.0)
	_peak_speed = _rng.randf_range(speed_min, speed_max)
	_pulse_rate = _rng.randf_range(1.2, 2.4)
	_pulse_phase = _rng.randf_range(0.0, TAU)
	# اولین خطِ باد کمی بعد از شروعِ وزش می‌آید، نه توی همان فریمِ اول که
	# باد هنوز سرعتی ندارد
	_swirl_wait = _rng.randf_range(0.2, 0.7)


## جهت، سرعت و جای نوارِ تولدِ یک لایه را با بادِ همین لحظه تنظیم می‌کند.
func _drive(p: CPUParticles2D, s: float, speed: float) -> void:
	if p == null:
		return
	var live := s > LIVE_AT
	if p.emitting != live:
		p.emitting = live
	if not live:
		# باد خوابید: هرچه در هواست با damping آرام می‌ایستد و با پایانِ
		# عمرش محو می‌شود. نیرو را صفر می‌کنیم تا ذره‌ی زنده هل داده نشود.
		p.gravity = Vector2.ZERO
		return

	p.direction = _dir
	p.initial_velocity_min = speed * 0.55
	p.initial_velocity_max = speed * 1.05
	# gravity اینجا نقشِ «فشارِ باد» را دارد: ذره در طولِ راه هم هل داده
	# می‌شود، پس وسطِ کادر جان نمی‌دهد.
	p.gravity = _dir * speed * 0.7
	p.global_position = _band_pos
	p.emission_rect_extents = _band_ext


## نوارِ تولد را روی لبه‌ی بالادستِ کادرِ دوربین می‌گذارد و به اندازه‌ی
## همان کادر پهن می‌کند — برای هر جهتی از باد. یک بار در فریم، چون هم
## برگ‌ها و هم خطوطِ باد از همین نوار می‌آیند.
func _update_band() -> void:
	var view := _view_rect()
	var half := view.size * 0.5
	_band_perp = Vector2(-_dir.y, _dir.x)
	# فاصله‌ی مرکزِ کادر تا لبه‌اش، یک بار در راستای باد و یک بار عمود بر آن
	var reach := absf(_dir.x) * half.x + absf(_dir.y) * half.y + BAND_MARGIN
	_band_span = absf(_band_perp.x) * half.x + absf(_band_perp.y) * half.y + BAND_MARGIN
	_band_reach = reach

	_band_pos = view.get_center() - _dir * reach
	# نوارِ چرخیده، به‌صورتِ مستطیلِ محور-راست. چون ضخامتش کم است، بزرگ‌ترین
	# خطای این ساده‌سازی هم چند ده واحد بیرونِ کادر است.
	_band_ext = Vector2(
		absf(_band_perp.x) * _band_span + absf(_dir.x) * BAND_THICK,
		absf(_band_perp.y) * _band_span + absf(_dir.y) * BAND_THICK)


## کادرِ دیده‌شده‌ی دوربین در مختصاتِ جهان
func _view_rect() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2(Vector2.ZERO, world_size)
	var world: Rect2 = vp.get_canvas_transform().affine_inverse() * vp.get_visible_rect()
	if world.size.x <= 1.0 or world.size.y <= 1.0:
		return Rect2(Vector2.ZERO, world_size)
	return world


# ============================ بیرون ============================

## شدتِ بادِ همین لحظه (۰..۱) و جهتش — اگر جایی خواست خودش را با باد
## هماهنگ کند (مثلاً شعله‌ی مشعل یا صدای وزش).
func wind_strength() -> float:
	return _strength


func wind_dir() -> Vector2:
	return _dir


## وزشِ فوری — برای تست و برای جاهایی که باد باید با اتفاقِ بازی بیاید.
func gust_now() -> void:
	if not _gusting:
		_begin_gust()
