extends StaticBody2D
class_name Demon
## شیطانِ وسطِ زمین — «عملیات حذف شیطان» (banish).
##
## مرجعِ همه‌چیز سرور است (gun_game_server/demon.go): جا، جان، نفرین‌ها و
## اینکه چه کسی برنده شد. این نود فقط آن را نشان می‌دهد و هیچ عددی را خودش
## حساب نمی‌کند.
##
## چرا StaticBody2D و نه یک اسپرایتِ ساده: با همین یک انتخاب، کلِ سیستمِ
## نشانه‌گیریِ بازیکن (player.gd) بدونِ یک خط تغییر رویش کار می‌کند —
##   • لایه‌ی برخوردِ ۲ یعنی DetectionZone (ماسک ۲) پیدایش می‌کند
##   • گروهِ "enemy" یعنی refresh_targets() قبولش می‌کند
##   • is_ally = false یعنی هم‌تیمی حساب نمی‌شود
##   • SightRay (ماسک ۳) رویش برخورد می‌کند، پس «دیوار وسط نباشد» هم صادق است
##   • username یعنی پیامِ hit با نامِ قراردادیِ سرور می‌رود
## یعنی بازیکن دقیقاً همان‌طور رویش قفل می‌کند که روی یک حریف.
##
## ظاهر سه لایه است:
##   ۱. هاله‌ی شیدری (shaders/demon_aura.gdshader) پشتِ بدنه — حلقه‌های رونیِ
##      چرخان، زبانه‌های انرژی و نفسِ آرام
##   ۲. بدنه: assets/Setin.png
##   ۳. نورِ واقعیِ قرمز، تا در زمینِ تاریک از دور پیدا باشد و دیوارهای
##      حیاط را روشن کند

## تصویرِ شیطان. preload است و نه load: نسخه‌ی قبلی اگر فایل نبود یک پیکرِ
## چندضلعیِ جایگزین می‌کشید و همین باعث شد شیطانِ «ساختگی» بی‌صدا در بازی
## بماند. حالا اگر این فایل نباشد پروژه همان لحظه خطای کامپایل می‌دهد.
##
## تصویر از قبل پس‌زمینه‌ی شفاف دارد و حلقه‌ی سرخِ دورش جزوِ خودِ آرت است.
const ART := preload("res://assets/Setin.png")
const AURA_SHADER := "res://shaders/demon_aura.gdshader"
const LIGHT_TEX := preload("res://assets/lightall.png")
const FONT := preload("res://fonts/Lalezar-Regular.ttf")

## نامی که سرور با آن شیطان را می‌شناسد (demon.go → DemonTarget).
## player.gd همین را در پیامِ hit می‌فرستد.
const DEMON_USERNAME := "__demon__"

## لایه‌بندی، هم‌راستا با Arena.gd:
##   ۰ کف   ۱ هاله   ۲ آستانه‌ی درها   ۳ بدنه   ۴ دیوار   ۵ مانع   ۶ مشعل
##
## بدنه عمداً زیرِ دیوار است: اگر روزی حیاطِ شیطان ستون بگیرد، شیطان نباید
## روی ستون کشیده شود. هاله پایین‌تر از همه می‌نشیند و چون افزودنی است،
## کفِ اطراف را روشن می‌کند نه اینکه رویش بیفتد.
const DEMON_Z := 3
const AURA_Z := 1

## قطرِ بدنه‌ی کشیده‌شده نسبت به شعاعِ برخوردی که سرور می‌گوید.
##
## از یک بزرگ‌تر است چون آرتِ شیطان (مثل هر کاراکترِ دیگری) حاشیه و بال و
## حلقه دارد که برخورد نیستند — بدنه‌ی سفتش همان شعاعی است که سرور می‌گوید.
const ART_SCALE := 1.6
## هاله چند برابرِ بدنه پهن می‌شود
const AURA_SCALE := 3.6

## --- چیزهایی که سرور می‌گوید ---
var radius := 96.0
var health := 12000
var max_health := 12000
## player.gd این دو را می‌خواند
var username := DEMON_USERNAME
var is_ally := false

var _art: Sprite2D = null
var _aura: Sprite2D = null
var _aura_mat: ShaderMaterial = null
var _lamp: PointLight2D = null
var _shape: CollisionShape2D = null
var _bar: Node2D = null

## ۰ تا ۱ — تپشِ سفیدِ «ضربه خورد»، هر فریم آب می‌رود
var _hurt := 0.0
## ۰ تا ۱ — فروریختنِ هاله بعد از مرگ
var _death := 0.0
var _dying := false
## فازِ تصادفی تا دو مسابقه دقیقاً یک‌شکل شروع نشوند
var _phase := 0.0


func _ready() -> void:
	name = "Demon"
	add_to_group("enemy")
	# گروهِ جدا تا player.gd بتواند «هدفِ درجه‌دوم» بودنش را بفهمد: تا وقتی
	# حریفِ زنده‌ای در دسترس است، تفنگ نباید روی شیطان قفل بماند
	add_to_group("demon")
	# لایه ۲ = بازیکن‌ها. بازیکن با ماسک ۲ می‌بیندش و تیر (ماسک ۳) هم
	# رویش برخورد می‌کند. خودش دنبال چیزی نمی‌گردد.
	collision_layer = 2
	collision_mask = 0
	z_index = DEMON_Z
	z_as_relative = false
	_phase = randf() * 100.0
	_build()


## جا و اندازه را سرور می‌دهد. یک بار موقعِ ساخت صدا زده می‌شود.
func setup(pos: Vector2, r: float, hp: int, max_hp: int) -> void:
	global_position = pos
	radius = maxf(r, 1.0)
	max_health = maxi(max_hp, 1)
	health = clampi(hp, 0, max_health)
	_apply_radius()
	_refresh_bar()


# ============================ ساخت ============================

func _build() -> void:
	# --- برخورد ---
	var circle := CircleShape2D.new()
	circle.radius = radius
	_shape = CollisionShape2D.new()
	_shape.shape = circle
	add_child(_shape)

	# --- هاله ---
	if ResourceLoader.exists(AURA_SHADER):
		_aura = Sprite2D.new()
		_aura.name = "Aura"
		_aura.texture = _white_quad()
		_aura.z_index = AURA_Z
		_aura.z_as_relative = false
		_aura_mat = ShaderMaterial.new()
		_aura_mat.shader = load(AURA_SHADER)
		_aura.material = _aura_mat
		add_child(_aura)

	# --- نورِ واقعی ---
	# زمین تاریک است و حیاطِ شیطان باید از دهانه‌ی هر راهرو دیده شود.
	# نورش عمداً از خودِ حیاط بزرگ‌تر است تا از دهانه‌ی هر چهار دروازه
	# بیرون بزند: در زمینِ تاریک، اولین چیزی که بازیکن از شیطان می‌بیند
	# این تابشِ قرمز است، نه خودش. بدونِ آن، تا وسطِ حیاط نروی نمی‌فهمی
	# آن‌جا چیزی هست.
	_lamp = PointLight2D.new()
	_lamp.name = "Glow"
	_lamp.texture = LIGHT_TEX
	_lamp.color = Color(1.0, 0.30, 0.22)
	_lamp.energy = 2.8
	_lamp.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(_lamp)

	# --- بدنه ---
	_art = _build_art()
	_art.z_index = DEMON_Z
	_art.z_as_relative = false
	add_child(_art)

	# --- نوارِ جانِ بالای سر ---
	_bar = _build_bar()
	add_child(_bar)

	_apply_radius()


## بدنه: تصویرِ شیطان (assets/Setin.png).
func _build_art() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "Art"
	sprite.texture = ART
	# با زومِ دوربین بزرگ/کوچک می‌شود؛ بدونِ mipmap لبه‌های حلقه دندانه‌دار
	# می‌شوند (import همین فایل mipmap می‌سازد)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# بدونِ نور: نورِ قرمزِ خودِ شیطان (_lamp) و HDRِ صحنه روی همین تصویر جمع
	# می‌شدند و آرت را می‌سوزاندند — موها سفیدِ خالص و لباس یک لکه‌ی قرمز. آرت
	# خودش رنگ و سایه‌ی کامل دارد، پس باید همان‌طور که کشیده شده دیده شود.
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	sprite.material = mat
	return sprite


## نوارِ جانِ بالای سر. نوارِ بزرگِ بالای صفحه را RoundHUD می‌کشد؛ این یکی
## برای وقتی است که بازیکن دارد مستقیم به او شلیک می‌کند و چشمش پایین است.
func _build_bar() -> Node2D:
	var root := Node2D.new()
	root.name = "HealthBar"
	root.z_index = DEMON_Z + 2
	root.z_as_relative = false
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	var back := Polygon2D.new()
	back.name = "Back"
	back.color = Color(0.05, 0.03, 0.05, 0.85)
	back.material = mat
	root.add_child(back)

	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.color = Color(0.93, 0.17, 0.20)
	fill.material = mat
	root.add_child(fill)

	var label := Label.new()
	label.name = "Text"
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.6))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = "شیطان"
	root.add_child(label)
	return root


## اندازه‌ها همه از شعاعی می‌آیند که سرور گفته، پس اگر روزی شعاع عوض شد
## هیچ عددی این‌جا دستی نمی‌ماند.
func _apply_radius() -> void:
	if _shape != null and _shape.shape is CircleShape2D:
		(_shape.shape as CircleShape2D).radius = radius

	if _art != null:
		_art.scale = _art_base_scale()

	if _aura != null:
		var span := radius * 2.0 * AURA_SCALE
		var k := span / 64.0                # بافتِ کوآد ۶۴ پیکسل است
		_aura.scale = Vector2(k, k)

	if _lamp != null:
		# ضریبِ ۱۱ یعنی شعاعِ روشنایی حدود ۵۲۰ واحد — بزرگ‌تر از نصفِ حیاط،
		# پس نور از دروازه‌ها بیرون می‌زند و از داخلِ راهرو دیده می‌شود
		var lk := (radius * 11.0) / float(LIGHT_TEX.get_width())
		_lamp.scale = Vector2(lk, lk)

	if _bar != null:
		_layout_bar()


func _layout_bar() -> void:
	var w := radius * 2.4
	var h := 14.0
	var y := _bar_y()
	var back := _bar.get_node_or_null("Back") as Polygon2D
	if back != null:
		back.polygon = _rect_poly(-w * 0.5 - 3.0, y - 3.0, w + 6.0, h + 6.0)
	var label := _bar.get_node_or_null("Text") as Label
	if label != null:
		label.size = Vector2(w + 120.0, 30.0)
		label.position = Vector2(-(w + 120.0) * 0.5, y - 38.0)
	_refresh_bar()


## ارتفاعِ نوارِ بالای سر: کمی بالاتر از لبه‌ی بالاییِ تصویر.
## نیمه‌ارتفاعِ آرت radius × ART_SCALE است (قطرش radius × ۲ × ART_SCALE) —
## نسخه‌ی قبلی نصفِ همین را می‌گرفت و نوار روی شاخ‌ها می‌افتاد.
func _bar_y() -> float:
	return -radius * ART_SCALE - 22.0


func _refresh_bar() -> void:
	if _bar == null:
		return
	var fill := _bar.get_node_or_null("Fill") as Polygon2D
	if fill == null:
		return
	var w := radius * 2.4
	var h := 14.0
	var y := _bar_y()
	var frac: float = clampf(float(health) / float(maxi(max_health, 1)), 0.0, 1.0)
	if frac <= 0.0:
		fill.polygon = PackedVector2Array()
		return
	fill.polygon = _rect_poly(-w * 0.5, y, w * frac, h)
	# سرخ‌تر و روشن‌تر هرچه جانش کمتر — «دارد می‌افتد» باید از دور دیده شود
	fill.color = Color(0.93, 0.17 + 0.45 * (1.0 - frac), 0.20).lerp(
		Color(1.0, 0.75, 0.25), 1.0 - frac)


# ============================ سرور ============================

## وضعیتِ تازه از سرور (پیامِ demon_state).
func apply_state(pos: Vector2, r: float, hp: int, max_hp: int) -> void:
	global_position = pos
	if not is_equal_approx(r, radius) and r > 0.0:
		radius = r
		_apply_radius()
	max_health = maxi(max_hp, 1)
	var before := health
	health = clampi(hp, 0, max_health)
	if health < before:
		_on_hurt(before - health)
	_refresh_bar()


## ضربه خورد: هاله یک تپشِ سفید می‌زند و عددِ خسارت بالا می‌رود.
func _on_hurt(amount: int) -> void:
	_hurt = 1.0
	if amount > 0:
		# عدد کمی بالاتر از بدنه، وگرنه زیرِ نوارِ جان گم می‌شود
		CombatFX.damage_number(global_position + Vector2(
			randf_range(-radius * 0.6, radius * 0.6), -radius * 0.7), amount)
		CombatFX.hit_burst(global_position + Vector2(
			randf_range(-radius * 0.5, radius * 0.5),
			randf_range(-radius * 0.5, radius * 0.5)), Vector2(0, -1))


## شیطان افتاد. راند را سرور تمام می‌کند؛ این‌جا فقط رفتنش نشان داده می‌شود.
func slay() -> void:
	if _dying:
		return
	_dying = true
	health = 0
	_refresh_bar()
	if _bar != null:
		_bar.visible = false
	# دیگر نه هدف است و نه جلوی تیر را می‌گیرد
	remove_from_group("enemy")
	set_deferred("collision_layer", 0)
	# انفجارِ کامل روی خودش، بعد فرو ریختنِ هاله (در _process)
	CombatFX.demon_blast(global_position, radius * 2.0)
	CombatFX.knockout(global_position, 2.4)


# ============================ حرکتِ همیشگی ============================

func _process(delta: float) -> void:
	var t := float(Time.get_ticks_msec()) * 0.001 + _phase

	if _hurt > 0.0:
		_hurt = maxf(_hurt - delta * 4.5, 0.0)
	if _dying:
		_death = minf(_death + delta * 1.6, 1.0)

	# نفسِ آرامِ بدنه: بالا-پایینِ خیلی کم + تنفسِ اندازه. عمداً ریز است —
	# چیزی که باید تکان بخورد هاله است، نه خودِ بدنه.
	if _art != null and not _dying:
		var bob := sin(t * 1.15) * radius * 0.045
		_art.position = Vector2(0.0, bob)
		var breathe := 1.0 + sin(t * 1.5) * 0.022 + _hurt * 0.06
		var base: Vector2 = _art_base_scale()
		_art.scale = base * breathe
		# تپشِ سفیدِ ضربه
		_art.modulate = Color(1, 1, 1).lerp(Color(2.0, 1.4, 1.2), _hurt * 0.8)

	if _aura_mat != null:
		# هاله با کم شدنِ جانِ شیطان بی‌قرارتر می‌شود: پرنورتر و تندچرخ‌تر.
		# یعنی بدونِ نگاه کردن به نوارِ جان هم می‌فهمی نزدیک است.
		var frac: float = clampf(float(health) / float(maxi(max_health, 1)), 0.0, 1.0)
		var rage := 1.0 - frac
		_aura_mat.set_shader_parameter("energy",
			(0.85 + 0.45 * rage) * (1.0 + _hurt * 0.8))
		_aura_mat.set_shader_parameter("spin", 0.45 + 0.85 * rage)
		_aura_mat.set_shader_parameter("hurt", _hurt)
		_aura_mat.set_shader_parameter("death", _death)

	if _lamp != null:
		# نور هم‌فاز با نفسِ هاله می‌زند، و با مرگ خاموش می‌شود
		var flicker := 2.8 + sin(t * 2.3) * 0.45 + sin(t * 7.1) * 0.15
		_lamp.energy = maxf((flicker + _hurt * 3.0) * (1.0 - _death), 0.0)

	if _dying and _death >= 1.0:
		queue_free()


## مقیاسِ پایه‌ی بدنه (بدونِ نفس) — هر بار از روی شعاع حساب می‌شود تا با
## تغییرِ شعاعِ سرور خودش هماهنگ بماند.
func _art_base_scale() -> Vector2:
	var k := radius * 2.0 * ART_SCALE / float(maxi(ART.get_width(), 1))
	return Vector2(k, k)


# ============================ کمکی‌ها ============================

func _white_quad() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func _rect_poly(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
