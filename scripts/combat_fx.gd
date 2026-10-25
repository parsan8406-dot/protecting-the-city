extends Node2D
##
## CombatFX — افکت شلیک، برخورد و ناک‌اوت.
##
## بازی برای همه‌ی سنین است: هیچ پاشش، مایع یا لکه‌ای روی زمین نمی‌ماند.
## ضربه یک جرقه‌ی طلاییِ کارتونی است و ناک‌اوت یک پفِ دودِ کارتونی با
## ستاره‌هایی که از آن بیرون می‌پرند — کاراکتر داخلِ دود ناپدید می‌شود.
##
## قانون اصلی این فایل: در طول بازی هیچ نود، Tween یا Resource تازه‌ای ساخته
## نمی‌شود. همه‌چیز یک بار در _ready ساخته و pool می‌شود و بعد فقط جای نود
## عوض می‌شود. برای همین شلیک پشت‌سرهم روی موبایل هم لگ نمی‌زند.
##
## این اسکریپت autoload است (نام: CombatFX) و روی همان canvas دنیا می‌کشد،
## پس مختصات ورودی همان global_position صحنه است.
##
## تمام متریال‌ها unshaded هستند چون صحنه‌ی بازی یک CanvasModulate تقریباً
## سیاه دارد؛ بدون unshaded افکت‌ها اصلاً دیده نمی‌شوند.

# ------------------------------------------------------------------ تنظیمات

const TRACER_RANGE := 1600.0     ## اگر تیر به چیزی نخورد تا این فاصله می‌رود
const TRACER_SPEED := 7000.0     ## سرعت قطعه‌ی درخشان رد گلوله
const TRACER_SEG := 120.0        ## طول قطعه‌ی درخشان
const FLASH_LIFE := 0.12

## --- نورِ دهانه‌ی لوله ---
## زمینِ بازی تاریک است، پس شلیک باید واقعاً محیط را روشن کند و نه فقط یک
## نقاشیِ افزودنی باشد. رنگ عمداً کهربایی-گرم است (شعله، نه سفیدِ خنثی).
const MUZZLE_LIGHT_COLOR := Color(1.0, 0.72, 0.34)
## اوجِ روشنایی در لحظه‌ی شلیک؛ بعدش سریع خاموش می‌شود
const MUZZLE_LIGHT_ENERGY := 2.4
## بافتِ نور ۲۵۰ پیکسل است؛ این ضریب شعاعِ روشنایی را حدود ۲۵۰ واحد می‌کند
const MUZZLE_LIGHT_SCALE := 2.0
## چند نورِ لوله هم‌زمان روشن بماند. هر PointLight2D روی gl_compatibility یک
## پاسِ اضافه روی هرچه زیرش است می‌کشد؛ با مسلسل و چند ربات ده نورِ هم‌زمان
## می‌شد. نوبتی (round-robin): نورِ تازه قدیمی‌ترین را خاموش می‌کند.
## کیفیتِ کم: هیچ — فلشِ افزودنی خودش سرِ جایش است.
const MUZZLE_LAMPS_HIGH := 3
const MUZZLE_LAMPS_MEDIUM := 2
## لرزشِ شلیکِ خودی بر اساسِ فاصله‌ی دو شلیک (همان fire_cooldownِ سلاح):
## clampf(فاصله × ۱۲, ۱, ۶). مسلسل دیگر کلِ تصویر را مدام نمی‌لرزاند و
## سلاحِ کُند ضربه‌ی محکم‌تری حس می‌شود. شلیکِ تکی بعد از مکثِ طولانی‌تر از
## SHOT_SHAKE_IDLE همان لرزشِ قدیمی را می‌گیرد.
const SHOT_SHAKE_PER_SEC := 12.0
const SHOT_SHAKE_MIN := 1.0
const SHOT_SHAKE_MAX := 6.0
const SHOT_SHAKE_IDLE := 2.0
const SHOT_SHAKE_SINGLE := 5.0
const POP_LIFE := 0.20           ## جرقه‌ی «پاو»ِ برخورد، کمی بیشتر از فلش شلیک
const TRAIL_LIFE := 0.070
const SHELL_LIFE := 0.70
const SCORCH_FADE := 2.0         ## چند ثانیه‌ی آخرِ جای سوختگی که محو می‌شود
const BOOM_LIFE := 0.40          ## گلوله‌ی آتشِ انفجار
const WAVE_LIFE := 0.55          ## موج ضربه
const ZONE_FADE := 0.18          ## محو شدنِ نشانگر محدوده بعد از انفجار
const SCORCH_LIFE := 9.0         ## جای سوختگیِ روی زمین
const PLUS_LIFE := 1.0           ## علامت‌های + درمان
const DMG_LIFE := 0.9            ## عددِ شناورِ خسارت

## --- ناک‌اوت: پفِ دودِ کارتونی + ستاره‌ها ---
const KO_LIFE := 0.95            ## عمرِ کلِ ابر تا آخرین تکه‌اش خورده شود
const KO_POP_TIME := 0.16        ## پف‌ها در همین مدت از ریز به اندازه‌ی کامل می‌پرند
const KO_SPREAD_TIME := 0.38     ## پرتابِ پف‌ها به بیرون در همین مدت ترمز می‌کند
const KO_RISE := 16.0            ## کلِ ابر در طولِ عمرش این‌قدر بالا می‌رود
const KO_HIDE_TIME := 0.2        ## کاراکتر تا این زمان داخلِ دود ناپدید شده
const KO_OUTLINE := 1.16         ## پفِ خطِ دور چند برابرِ پفِ اصلی است
const KO_STAR_LIFE := 0.85
const KO_STAR_PX := 22.0         ## اندازه‌ی ستاره در دنیای بازی (با زومِ ۲ دوربین، ۴۴ پیکسل)
const KO_STAR_GRAVITY := 420.0
const KO_STARS := 5              ## ستاره‌های هر ناک‌اوت
const STAR_TEX_PATH := "res://assets/star_knowout.png"
const PUFF_SHADER_PATH := "res://shaders/toon_puff.gdshader"

const FONT_PATH := "res://fonts/Lalezar-Regular.ttf"

const Z_FX := 90                 ## بالای بازیکن‌ها
const Z_DECAL := 2               ## زیر بازیکن‌ها، روی زمین

## ضلع بافتِ نقطه‌ی ذرات. هر scale_amount نسبت به همین است:
## scale ۱.۰ یعنی یک قطره‌ی ۳۲ پیکسلی، ۰.۲۵ یعنی ۸ پیکسل.
const DOT_TEX_SIZE := 32

## ضلع مربعی که شیدرهای دایره‌ای (محدوده‌ی بمب و موج ضربه) روی آن کشیده
## می‌شوند. خود بافت دیده نمی‌شود؛ فقط UV صفر تا یک را فراهم می‌کند.
const QUAD_TEX_SIZE := 64

const AOE_SHADER_PATH := "res://shaders/aoe_zone.gdshader"
const WAVE_SHADER_PATH := "res://shaders/shockwave.gdshader"
## --- نفرینِ شیطان (حالتِ «عملیات حذف شیطان») ---
const MARK_SHADER_PATH := "res://shaders/demon_mark.gdshader"
const HEAT_SHADER_PATH := "res://shaders/heat_wave.gdshader"

## عمرِ لایه‌های انفجارِ نفرین. عمداً همه با هم تمام نمی‌شوند: فلش می‌رود،
## گلوله‌ی آتش بعدش، موج بعد از آن، و خاکستر تا آخر می‌ماند. همین اختلاف
## است که انفجار را «عمیق» نشان می‌دهد نه یک پفِ تخت.
const BLAST_FLASH_LIFE := 0.16   ## ترکشِ سفیدِ اولِ کار
const BLAST_LIGHT_LIFE := 0.42   ## نورِ واقعی‌ای که صحنه را روشن می‌کند
const BLAST_HEAT_LIFE := 0.46    ## موجِ گرما (کج شدنِ تصویرِ پشت)
const BLAST_RING_LIFE := 0.62    ## حلقه‌ی ضربه
## اوجِ روشناییِ انفجار. زمین تاریک است، پس این عدد بزرگ لازم است تا
## واقعاً یک لحظه کلِ محدوده روشن شود.
const BLAST_LIGHT_ENERGY := 7.0

const COL_HOT := Color(1.0, 0.97, 0.84)
const COL_WARM := Color(1.0, 0.52, 0.08)
const COL_TRACER := Color(1.0, 0.86, 0.45)
## جرقه‌ی برخورد به بدن: سفیدِ داغ در مرکز، طلایی در لبه‌ها (هم‌رنگِ تمِ بازی)
const COL_HIT_HOT := Color(1.0, 0.99, 0.88)
const COL_HIT := Color(1.0, 0.80, 0.22)
const COL_BRASS := Color(0.86, 0.66, 0.24)
const COL_HEAL := Color(0.36, 1.0, 0.46)        ## سبزِ روشنِ درمان
const COL_HEAL_HOT := Color(0.80, 1.0, 0.85)
const COL_DMG := Color(1.0, 0.32, 0.24)
## V1/V2: خسارتِ خودت طلایی (پاداش)، درگیریِ بقیه خنثی
const COL_DMG_MINE := Color(1.0, 0.84, 0.28)
const COL_DMG_OTHER := Color(0.86, 0.84, 0.8)
const COL_KILL := Color(1.0, 0.8, 0.26)

## نوعِ عددِ خسارت (damage_number)
const DMG_TAKEN := 0
const DMG_MINE := 1
const DMG_OTHER := 2

## V7: سقفِ دامنه‌ی لرزش (واحدِ دنیا؛ با زومِ ۲ دو برابر روی صفحه) — بیشتر از
## این روی گوشی دیگر «ضربه» نیست، سرگیجه است
const SHAKE_CAP := 20.0
## لرزشِ انفجار تا PROX_NEAR کامل است و تا PROX_FAR به صفر می‌رسد
const PROX_NEAR := 260.0
const PROX_FAR := 1100.0

## تأییدِ کیل (kill_confirm)
const KILL_LIFE := 0.9
const N_KILL := 3
const COIN_TEX_PATH := "res://assets/ui/coin_icon.png"

## اندازه‌ی استخرها؛ سقف تعداد افکت هم‌زمان است. بیشتر از این، قدیمی‌ترین
## افکت دوباره استفاده می‌شود (به‌جای اینکه نود تازه ساخته شود).
const N_FLASH := 10
const N_POP := 8
const N_POOF := 4                ## ابرهای ناک‌اوتِ هم‌زمان
const N_KO_STAR := N_POOF * KO_STARS
const N_ZONE := 4                ## نشانگر محدوده‌ی بمب
const N_WAVE := 4                ## موج ضربه
const N_BOOM := 4                ## گلوله‌ی آتش
const N_SCORCH := 5              ## جای سوختگی
const N_DEBRIS := 4
const N_PLUS := 28               ## علامت‌های + که موقع درمان بالا می‌روند
const N_DMG := 10                ## عددهای شناورِ خسارت
const N_TRACER := 14
const N_SHELL := 14
const N_SPARK := 8
const N_SMOKE := 6
const N_HIT := 6
const N_KO_SPARK := N_POOF
const N_HEAL := 3
## نفرینِ شیطان هم‌زمان یکی بیشتر نیست (سرور یکی‌یکی می‌فرستد)، ولی دوتا
## نگه می‌داریم تا اگر دو نفرین نزدیکِ هم افتادند اولی وسطِ کار قطع نشود.
const N_MARK := 2
const N_HEAT := 2
const N_BLAST_FLASH := 2
const N_BLAST_LIGHT := 2
const N_EMBER := 2
const N_ASH := 2

## چیدمانِ پف‌های یک ابرِ ناک‌اوت: یک پفِ درشتِ وسط، یک حلقه دورش و چند
## تکه‌ی ریز که دورتر پرت می‌شوند (همان «پوف!» کارتون‌ها).
const KO_RING := 7
const KO_WISPS := 3
const KO_PUFFS := 1 + KO_RING + KO_WISPS


## یک افکت فعال. از قبل ساخته می‌شود تا موقع شلیک چیزی allocate نشود.
class Slot extends RefCounted:
	var node: Node2D
	var t := 0.0
	var life := 1.0
	var on := false
	var a := Vector2.ZERO   # نقطه‌ی شروع / سرعت
	var b := Vector2.ZERO   # نقطه‌ی پایان / موقعیت
	var f := 0.0            # پارامتر عمومی (طول، مقیاس، ...)
	var g := 0.0
	# فرزندهایی که هر فریم لازم‌اند، یک بار موقعِ ساخت پیدا می‌شوند
	# (به‌جای get_node_or_null در هر _step)
	var lamp: PointLight2D = null   # نورِ لوله‌ی فلش
	var hot: Sprite2D = null        # مغزِ سفیدِ ترکشِ انفجار


## ابرِ ناک‌اوت: یک Slot به‌علاوه‌ی داده‌ی تک‌تکِ پف‌هایش. پف‌ها هر بار
## از نو چیده می‌شوند ولی نودهایشان همان نودهای از قبل ساخته‌شده‌اند.
class PoofSlot extends Slot:
	var fills: Array[Sprite2D] = []
	var lines: Array[Sprite2D] = []           # نسخه‌ی خطِ دورِ هر پف، پشتِ آن
	var dir := PackedVector2Array()           # جهتِ پرتاب
	var dist := PackedFloat32Array()          # فاصله‌ی نهایی از مرکز
	var rad := PackedFloat32Array()           # شعاعِ نهایی
	var spin := PackedFloat32Array()          # سرعتِ چرخش (الگوی نویز هم با آن می‌چرخد)
	var delay := PackedFloat32Array()         # از چه کسری از عمر خورده‌شدن شروع شود
	var noise_seed := PackedFloat32Array()    # بذرِ نویزِ شیدر


var _flash: Array[Slot] = []
var _pop: Array[Slot] = []
var _poof: Array[Slot] = []
var _ko_star: Array[Slot] = []
var _zone: Array[Slot] = []
var _wave: Array[Slot] = []
var _boom: Array[Slot] = []
var _scorch: Array[Slot] = []
var _plus: Array[Slot] = []
var _dmg: Array[Slot] = []
var _tracer: Array[Slot] = []
var _shell: Array[Slot] = []
var _mark: Array[Slot] = []
var _heat: Array[Slot] = []
var _blast_flash: Array[Slot] = []
var _blast_light: Array[Slot] = []
var _kill: Array[Slot] = []
var _i_kill := 0

## لایه‌ی «حس نبرد» (psych_combat_feel.gd) که زمینِ بازی می‌سازد — بات‌ها و
## صحنه از این‌جا پیدایش می‌کنند. null یعنی الان زمینی باز نیست.
var feel: Node = null

var _hit_stop_until := 0.0
var _hit_stopping := false

var _ember: Array[CPUParticles2D] = []
var _ash: Array[CPUParticles2D] = []
var _spark: Array[CPUParticles2D] = []
var _smoke: Array[CPUParticles2D] = []
var _hit: Array[CPUParticles2D] = []
var _ko_spark: Array[CPUParticles2D] = []
var _heal: Array[CPUParticles2D] = []
var _debris: Array[CPUParticles2D] = []

var _i_flash := 0
var _i_pop := 0
var _i_poof := 0
var _i_ko_star := 0
var _i_ko_spark := 0
var _i_zone := 0
var _i_wave := 0
var _i_boom := 0
var _i_scorch := 0
var _i_plus := 0
var _i_dmg := 0
var _i_debris := 0
var _i_tracer := 0
var _i_shell := 0
var _i_spark := 0
var _i_smoke := 0
var _i_hit := 0
var _i_heal := 0
var _i_mark := 0
var _i_heat := 0
var _i_blast_flash := 0
var _i_blast_light := 0
var _i_ember := 0
var _i_ash := 0

var _rng := RandomNumberGenerator.new()

var _mat_add: CanvasItemMaterial
var _mat_flat: CanvasItemMaterial
var _decal_root: Node2D
var _glow_tex: Texture2D
## نقطه‌ی گردِ نرم برای ذرات. اندازه‌اش ثابت است (DOT_TEX_SIZE) تا مقدارهای
## scale_amount معنی مشخصی داشته باشند و به ابعاد یک فایل بیرونی وابسته نباشند.
var _dot_tex: Texture2D
## مربعِ ساده‌ای که شیدرهای دایره‌ای رویش رسم می‌شوند
var _quad_tex: Texture2D
## ویجتِ نشانه‌گیریِ بمب — چون هم‌زمان فقط یکی لازم است، pool نمی‌خواهد
var _aim_root: Node2D

## فلش‌هایی که نورشان الان روشن است، قدیمی‌ترین اول (سقف: _muzzle_lamp_cap)
var _lit_flashes: Array[Slot] = []
## زمانِ آخرین شلیکِ خودی (ثانیه) — برای اندازه‌ی لرزش
var _last_local_shot := -100.0

# لرزش دوربین
var _shake := 0.0
var _shake_decay := 12.0
var _cam: Camera2D = null

# پارامترهای raycast یک بار ساخته می‌شوند و هر شلیک فقط مقادیرشان عوض می‌شود
var _ray := PhysicsRayQueryParameters2D.new()


func _ready() -> void:
	z_index = Z_FX
	z_as_relative = false
	_rng.randomize()

	_mat_add = CanvasItemMaterial.new()
	_mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_mat_add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	_mat_flat = CanvasItemMaterial.new()
	_mat_flat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	if ResourceLoader.exists("res://assets/lightall.png"):
		_glow_tex = load("res://assets/lightall.png")

	_dot_tex = _make_dot_texture()
	_quad_tex = _make_quad_texture()

	_decal_root = Node2D.new()
	_decal_root.name = "Decals"
	_decal_root.z_index = Z_DECAL
	_decal_root.z_as_relative = false
	add_child(_decal_root)

	_ray.collide_with_areas = false
	_ray.collide_with_bodies = true

	_build_flashes()
	_build_hit_pops()
	_build_poofs()
	_build_ko_stars()
	_build_zones()
	_build_waves()
	_build_booms()
	_build_scorches()
	_build_pluses()
	_build_damage_numbers()
	_build_aim()
	_build_tracers()
	_build_shells()
	_build_demon_blast()
	_build_particles()
	_build_kill_marks()

	set_process(false)


# ============================================================ ساخت استخرها

func _build_flashes() -> void:
	# طرح دقیقاً از روی رفرنس (انفجار ستاره‌ای Godot): یک هاله‌ی نرم پشت،
	# دو لایه ستاره‌ی جاگ‌دار (شاخه‌های تیز و نامساوی — نه چندضلعیِ صاف/چهارگوش)
	# با رنگ‌بندی از مرکز روشن به نوک تیره، به‌علاوه‌ی یک مغز داغ سفید.
	# طول شاخه‌ها هر بار در muzzle_flash() از نو رندوم می‌شود تا هیچ دو شلیکی
	# عین هم نباشند، بدون این‌که نودی ساخته شود (فقط داده‌ی پلیگان عوض می‌شود).
	for i in N_FLASH:
		# نکته: در Godot متریالِ والد به فرزند ارث نمی‌رسد، پس متریال روی
		# تک‌تک نودهای رسم‌شونده ست می‌شود (همان کاری که خود صحنه‌ها می‌کنند).
		var root := Node2D.new()
		root.visible = false
		add_child(root)

		# هاله‌ی نرم و بزرگ پشت شعله (قرمز-نارنجیِ عمیق) — همان بافت نور بازی
		if _glow_tex != null:
			var glow := Sprite2D.new()
			glow.name = "Glow"
			glow.texture = _glow_tex
			glow.material = _mat_add
			glow.scale = Vector2(0.62, 0.62)
			glow.modulate = Color(1.0, 0.30, 0.06, 0.65)
			root.add_child(glow)

			# هاله‌ی دومِ کوچک‌تر و روشن‌تر، دقیقاً زیر مغز سفید
			var glow_hot := Sprite2D.new()
			glow_hot.name = "GlowHot"
			glow_hot.texture = _glow_tex
			glow_hot.material = _mat_add
			glow_hot.scale = Vector2(0.30, 0.30)
			glow_hot.modulate = Color(1.0, 0.75, 0.35, 0.85)
			root.add_child(glow_hot)

		# لایه‌ی بیرونی: ستاره‌ی جاگ‌دارِ بزرگ‌تر، نارنجی به قرمز
		var outer := Polygon2D.new()
		outer.name = "StarOuter"
		outer.material = _mat_add
		root.add_child(outer)

		# لایه‌ی درونی: ستاره‌ی جاگ‌دارِ کوچک‌تر و روشن‌تر، با زاویه‌ی متفاوت
		# روی لایه‌ی بیرونی — همان جلوه‌ی «دو ستاره‌ی روی هم» که در رفرنس دیده می‌شود
		var inner := Polygon2D.new()
		inner.name = "StarInner"
		inner.material = _mat_add
		root.add_child(inner)

		# مغز داغِ سفید در مرکز (صاف/گرد، نه جاگ‌دار)
		var core := Polygon2D.new()
		core.name = "Core"
		core.polygon = _star(10, 7.0, 7.0)
		core.material = _mat_add
		core.color = Color(1, 1, 1)
		root.add_child(core)

		# نورِ واقعیِ دهانه‌ی لوله. تا اینجا فلش فقط یک نقاشیِ افزودنی بود و
		# صحنه را روشن نمی‌کرد؛ حالا که زمین تاریک است، هر شلیک باید واقعاً
		# دیوارها و کفِ اطراف را یک لحظه روشن کند.
		# انرژی در _step_flash با عمرِ فلش پایین می‌آید.
		if _glow_tex != null:
			var lamp := PointLight2D.new()
			lamp.name = "Lamp"
			lamp.texture = _glow_tex
			lamp.color = MUZZLE_LIGHT_COLOR
			lamp.energy = 0.0
			lamp.blend_mode = Light2D.BLEND_MODE_ADD
			lamp.scale = Vector2(MUZZLE_LIGHT_SCALE, MUZZLE_LIGHT_SCALE)
			lamp.visible = false
			root.add_child(lamp)

		var s := Slot.new()
		s.node = root
		s.lamp = root.get_node_or_null("Lamp") as PointLight2D
		_flash.append(s)


func _build_hit_pops() -> void:
	# «پاو»ِ کارتونیِ برخورد به بدن: ستاره‌ی جاگ‌دارِ سفید-طلایی، مثل حباب‌های
	# «POW!» کمیک — یک جرقه‌ی نورانی، نه پاششِ مایع.
	for i in N_POP:
		var root := Node2D.new()
		root.visible = false
		add_child(root)

		if _glow_tex != null:
			var glow := Sprite2D.new()
			glow.name = "Glow"
			glow.texture = _glow_tex
			glow.material = _mat_add
			glow.scale = Vector2(0.45, 0.45)
			glow.modulate = Color(1.0, 0.78, 0.25, 0.5)
			root.add_child(glow)

		var burst := Polygon2D.new()
		burst.name = "Burst"
		burst.material = _mat_add
		root.add_child(burst)

		# مغز سفیدِ داغ در مرکز (صاف/گرد)
		var core := Polygon2D.new()
		core.name = "Core"
		core.polygon = _star(10, 7.0, 7.0)
		core.material = _mat_add
		core.color = COL_HIT_HOT
		root.add_child(core)

		var s := Slot.new()
		s.node = root
		_pop.append(s)


func _build_poofs() -> void:
	# ابرِ ناک‌اوت. هر پف دو اسپرایت است با یک شیدرِ مشترک: نسخه‌ی خطِ دور
	# (کمی بزرگ‌تر، یکدست تیره) زیرِ همه و نسخه‌ی اصلی رویش. چون همه‌ی
	# خطِ دورها زودتر از همه‌ی پف‌ها کشیده می‌شوند، خط فقط دورِ کلِ ابر
	# دیده می‌شود و وسطِ پف‌های روی‌هم‌افتاده خطی نمی‌افتد.
	if not ResourceLoader.exists(PUFF_SHADER_PATH):
		push_warning("CombatFX: شیدرِ پفِ دود پیدا نشد: " + PUFF_SHADER_PATH)
		return
	var sh: Shader = load(PUFF_SHADER_PATH)
	var mat_fill := ShaderMaterial.new()
	mat_fill.shader = sh
	var mat_line := ShaderMaterial.new()
	mat_line.shader = sh
	mat_line.set_shader_parameter("outline_only", true)

	for i in N_POOF:
		var root := Node2D.new()
		root.name = "Poof%d" % i
		root.visible = false
		root.z_index = Z_FX + 1
		root.z_as_relative = false
		add_child(root)

		var lines := Node2D.new()
		lines.name = "Lines"
		root.add_child(lines)
		var fills := Node2D.new()
		fills.name = "Fills"
		root.add_child(fills)

		var s := PoofSlot.new()
		s.node = root
		for j in KO_PUFFS:
			var line := Sprite2D.new()
			line.texture = _quad_tex
			line.material = mat_line
			lines.add_child(line)
			s.lines.append(line)

			var fill := Sprite2D.new()
			fill.texture = _quad_tex
			fill.material = mat_fill
			fills.add_child(fill)
			s.fills.append(fill)
		s.dir.resize(KO_PUFFS)
		s.dist.resize(KO_PUFFS)
		s.rad.resize(KO_PUFFS)
		s.spin.resize(KO_PUFFS)
		s.delay.resize(KO_PUFFS)
		s.noise_seed.resize(KO_PUFFS)
		_poof.append(s)


func _build_ko_stars() -> void:
	# ستاره‌هایی که از ابرِ ناک‌اوت بیرون می‌پرند. بافت با size_limit
	# موقعِ import به ۱۲۸ پیکسل کوچک می‌شود و mipmap دارد تا در اندازه‌ی
	# ریزِ صفحه دندانه‌دار نشود.
	if not ResourceLoader.exists(STAR_TEX_PATH):
		push_warning("CombatFX: بافتِ ستاره‌ی ناک‌اوت پیدا نشد: " + STAR_TEX_PATH)
		return
	var tex: Texture2D = load(STAR_TEX_PATH)
	for i in N_KO_STAR:
		var star := Sprite2D.new()
		star.visible = false
		star.texture = tex
		star.material = _mat_flat
		star.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		star.z_index = Z_FX + 2
		star.z_as_relative = false
		add_child(star)

		var s := Slot.new()
		s.node = star
		_ko_star.append(s)


func _build_aim() -> void:
	# پیش‌نمایشِ نشانه‌گیری: خطِ پرتاب + همان شیدرِ محدوده در نقطه‌ی هدف.
	if not ResourceLoader.exists(AOE_SHADER_PATH):
		return
	_aim_root = Node2D.new()
	_aim_root.name = "BombAim"
	_aim_root.visible = false
	_aim_root.z_index = Z_DECAL + 2
	_aim_root.z_as_relative = false
	add_child(_aim_root)

	var line := Line2D.new()
	line.name = "Path"
	line.material = _mat_add
	line.width = 5.0
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.add_point(Vector2.ZERO)
	line.add_point(Vector2.ZERO)
	_aim_root.add_child(line)

	var zone := Sprite2D.new()
	zone.name = "Zone"
	zone.texture = _quad_tex
	var mat := ShaderMaterial.new()
	mat.shader = load(AOE_SHADER_PATH)
	zone.material = mat
	_aim_root.add_child(zone)

	# نشانِ ضربدریِ کوچک وسطِ هدف
	var cross := Polygon2D.new()
	cross.name = "Cross"
	cross.polygon = _plus_shape(13.0, 4.0)
	cross.rotation = PI / 4.0
	cross.material = _mat_add
	cross.color = Color(1, 1, 1)
	_aim_root.add_child(cross)


func _build_zones() -> void:
	# نشانگر محدوده‌ی بمب. هر اسلات ShaderMaterial خودش را دارد چون progress
	# هر بمب جداست؛ ولی خودِ Shader بین همه مشترک است.
	if not ResourceLoader.exists(AOE_SHADER_PATH):
		push_warning("CombatFX: شیدر محدوده پیدا نشد: " + AOE_SHADER_PATH)
		return
	var sh: Shader = load(AOE_SHADER_PATH)
	for i in N_ZONE:
		var spr := Sprite2D.new()
		spr.visible = false
		spr.texture = _quad_tex
		spr.z_index = Z_DECAL + 1        # روی زمین، زیر بازیکن‌ها
		spr.z_as_relative = false
		var mat := ShaderMaterial.new()
		mat.shader = sh
		spr.material = mat
		add_child(spr)

		var s := Slot.new()
		s.node = spr
		_zone.append(s)


func _build_waves() -> void:
	if not ResourceLoader.exists(WAVE_SHADER_PATH):
		push_warning("CombatFX: شیدر موج ضربه پیدا نشد: " + WAVE_SHADER_PATH)
		return
	var sh: Shader = load(WAVE_SHADER_PATH)
	for i in N_WAVE:
		var spr := Sprite2D.new()
		spr.visible = false
		spr.texture = _quad_tex
		spr.z_index = Z_FX
		spr.z_as_relative = false
		var mat := ShaderMaterial.new()
		mat.shader = sh
		spr.material = mat
		add_child(spr)

		var s := Slot.new()
		s.node = spr
		_wave.append(s)


func _build_booms() -> void:
	# گلوله‌ی آتشِ انفجار: همان ستاره‌ی جاگ‌دارِ فلش شلیک ولی بزرگ‌تر و
	# چندلایه‌تر، به‌علاوه‌ی هاله‌های داغ.
	for i in N_BOOM:
		var root := Node2D.new()
		root.visible = false
		add_child(root)

		if _glow_tex != null:
			var glow := Sprite2D.new()
			glow.name = "Glow"
			glow.texture = _glow_tex
			glow.material = _mat_add
			glow.scale = Vector2(1.6, 1.6)
			glow.modulate = Color(1.0, 0.32, 0.05, 0.75)
			root.add_child(glow)

			var glow_hot := Sprite2D.new()
			glow_hot.name = "GlowHot"
			glow_hot.texture = _glow_tex
			glow_hot.material = _mat_add
			glow_hot.scale = Vector2(0.8, 0.8)
			glow_hot.modulate = Color(1.0, 0.80, 0.42, 0.9)
			root.add_child(glow_hot)

		var outer := Polygon2D.new()
		outer.name = "StarOuter"
		outer.material = _mat_add
		root.add_child(outer)

		var inner := Polygon2D.new()
		inner.name = "StarInner"
		inner.material = _mat_add
		root.add_child(inner)

		var core := Polygon2D.new()
		core.name = "Core"
		core.polygon = _star(12, 16.0, 16.0)
		core.material = _mat_add
		core.color = Color(1, 1, 1)
		root.add_child(core)

		var s := Slot.new()
		s.node = root
		_boom.append(s)


func _build_scorches() -> void:
	# جای سوختگی که بعد از انفجار روی زمین می‌ماند
	for i in N_SCORCH:
		var root := Node2D.new()
		root.visible = false
		_decal_root.add_child(root)

		var main := Polygon2D.new()
		main.polygon = _blob(1.0, 24, 0.18)     # شعاع ۱ — موقع استفاده اسکیل می‌شود
		main.material = _mat_flat
		main.color = Color(0.05, 0.03, 0.02, 0.8)
		root.add_child(main)

		var rim := Polygon2D.new()
		rim.polygon = _blob(0.6, 20, 0.22)
		rim.material = _mat_flat
		rim.color = Color(0.16, 0.07, 0.02, 0.75)
		root.add_child(rim)

		var s := Slot.new()
		s.node = root
		_scorch.append(s)


func _build_pluses() -> void:
	# علامت‌های + درمان. هر کدام دو لایه است: یک + بزرگ‌ترِ سبزِ درخشان و
	# یک + کوچک‌ترِ تقریباً سفید رویش، تا وسطش داغ و لبه‌اش سبز دیده شود.
	for i in N_PLUS:
		var root := Node2D.new()
		root.visible = false
		add_child(root)

		if _glow_tex != null:
			var glow := Sprite2D.new()
			glow.name = "Glow"
			glow.texture = _glow_tex
			glow.material = _mat_add
			glow.scale = Vector2(0.22, 0.22)
			glow.modulate = Color(0.30, 1.0, 0.42, 0.55)
			root.add_child(glow)

		var outer := Polygon2D.new()
		outer.name = "Outer"
		outer.polygon = _plus_shape(15.0, 9.0)
		outer.material = _mat_add
		outer.color = COL_HEAL
		root.add_child(outer)

		var core := Polygon2D.new()
		core.name = "Core"
		core.polygon = _plus_shape(11.0, 4.6)
		core.material = _mat_add
		core.color = COL_HEAL_HOT
		root.add_child(core)

		var s := Slot.new()
		s.node = root
		_plus.append(s)


func _build_damage_numbers() -> void:
	# عددِ خسارت که از روی حریف بالا می‌رود. Label یک Control است و در
	# Slot.node که Node2D است جا نمی‌شود، پس داخل یک Node2D پیچیده می‌شود.
	var font: Font = null
	if ResourceLoader.exists(FONT_PATH):
		font = load(FONT_PATH)
	for i in N_DMG:
		var root := Node2D.new()
		root.visible = false
		root.z_index = Z_FX + 5
		root.z_as_relative = false
		add_child(root)

		var lbl := Label.new()
		lbl.name = "Text"
		if font != null:
			lbl.add_theme_font_override("font", font)
		lbl.add_theme_font_size_override("font_size", 34)
		lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.0, 0.0, 0.95))
		lbl.add_theme_constant_override("outline_size", 7)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size = Vector2(160, 48)
		lbl.position = Vector2(-80, -24)     # وسطِ نودِ والد
		root.add_child(lbl)

		var s := Slot.new()
		s.node = root
		_dmg.append(s)


func _build_tracers() -> void:
	# منحنی باریک‌شونده‌ی رد گلوله — یک بار ساخته و بین همه مشترک است
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.15))
	curve.add_point(Vector2(0.55, 1.0))
	curve.add_point(Vector2(1.0, 0.25))

	for i in N_TRACER:
		var root := Node2D.new()
		root.visible = false
		add_child(root)

		# رد کم‌رنگِ کل مسیر (یک لحظه دیده می‌شود و می‌رود)
		var trail := Line2D.new()
		trail.name = "Trail"
		trail.material = _mat_add
		trail.width = 2.5
		trail.default_color = Color(1.0, 0.80, 0.42, 0.5)
		trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		trail.end_cap_mode = Line2D.LINE_CAP_ROUND
		trail.add_point(Vector2.ZERO)
		trail.add_point(Vector2.ZERO)
		root.add_child(trail)

		# خودِ گلوله‌ی درخشان که در مسیر جلو می‌رود
		var bolt := Line2D.new()
		bolt.name = "Bolt"
		bolt.material = _mat_add
		bolt.width = 6.0
		bolt.width_curve = curve
		bolt.default_color = COL_TRACER
		bolt.begin_cap_mode = Line2D.LINE_CAP_ROUND
		bolt.end_cap_mode = Line2D.LINE_CAP_ROUND
		bolt.add_point(Vector2.ZERO)
		bolt.add_point(Vector2.ZERO)
		root.add_child(bolt)

		var s := Slot.new()
		s.node = root
		_tracer.append(s)


func _build_shells() -> void:
	for i in N_SHELL:
		var shell := Polygon2D.new()
		shell.visible = false
		shell.material = _mat_flat
		shell.polygon = PackedVector2Array([
			Vector2(-5, -2), Vector2(5, -2), Vector2(6, 0), Vector2(5, 2), Vector2(-5, 2),
		])
		shell.color = COL_BRASS
		add_child(shell)

		var s := Slot.new()
		s.node = shell
		_shell.append(s)


# ==================== نفرینِ شیطان: اخطار و انفجار ====================

## استخرهای مخصوصِ نفرین. همه‌شان مثل بقیه‌ی این فایل یک بار ساخته می‌شوند
## و بعد فقط جا و پارامترشان عوض می‌شود — وسطِ بازی هیچ نودی ساخته نمی‌شود.
func _build_demon_blast() -> void:
	# --- ۱) نشانگرِ اخطار ---
	if ResourceLoader.exists(MARK_SHADER_PATH):
		var mark_sh: Shader = load(MARK_SHADER_PATH)
		for i in N_MARK:
			var spr := Sprite2D.new()
			spr.visible = false
			spr.texture = _quad_tex
			spr.z_index = Z_DECAL + 1        # روی زمین، زیرِ بازیکن‌ها
			spr.z_as_relative = false
			var mat := ShaderMaterial.new()
			mat.shader = mark_sh
			spr.material = mat
			add_child(spr)
			var s := Slot.new()
			s.node = spr
			_mark.append(s)
	else:
		push_warning("CombatFX: شیدرِ اخطارِ نفرین پیدا نشد: " + MARK_SHADER_PATH)

	# --- ۲) موجِ گرما ---
	#
	# این تنها لایه‌ای است که به تصویرِ پشتِ خودش دست می‌زند (SCREEN_TEXTURE).
	# اگر شیدر نبود فقط همین لایه نمی‌آید و بقیه‌ی انفجار سرِ جایش است.
	if ResourceLoader.exists(HEAT_SHADER_PATH):
		var heat_sh: Shader = load(HEAT_SHADER_PATH)
		for i in N_HEAT:
			var spr := Sprite2D.new()
			spr.visible = false
			spr.texture = _quad_tex
			spr.z_index = Z_FX - 1           # زیرِ آتش، روی صحنه
			spr.z_as_relative = false
			var mat := ShaderMaterial.new()
			mat.shader = heat_sh
			spr.material = mat
			add_child(spr)
			var s := Slot.new()
			s.node = spr
			_heat.append(s)

	# --- ۳) ترکشِ سفیدِ اولِ کار ---
	# دو هاله‌ی روی‌هم: یکی پهن و کم‌جان، یکی کوچک و سفیدِ سوزان.
	for i in N_BLAST_FLASH:
		var root := Node2D.new()
		root.visible = false
		root.z_index = Z_FX + 3
		root.z_as_relative = false
		add_child(root)
		if _glow_tex != null:
			var wide := Sprite2D.new()
			wide.name = "Wide"
			wide.texture = _glow_tex
			wide.material = _mat_add
			wide.modulate = Color(1.0, 0.42, 0.20, 0.9)
			root.add_child(wide)

			var hot := Sprite2D.new()
			hot.name = "Hot"
			hot.texture = _glow_tex
			hot.material = _mat_add
			hot.scale = Vector2(0.45, 0.45)
			hot.modulate = Color(1.0, 0.97, 0.90, 1.0)
			root.add_child(hot)
		var s := Slot.new()
		s.node = root
		s.hot = root.get_node_or_null("Hot") as Sprite2D
		_blast_flash.append(s)

	# --- ۴) نورِ واقعیِ انفجار ---
	# زمینِ بازی تاریک است؛ بدونِ این، انفجار فقط یک نقاشی روی صحنه بود و
	# دیوارهای اطرافش تکان نمی‌خوردند.
	if _glow_tex != null:
		for i in N_BLAST_LIGHT:
			var lamp := PointLight2D.new()
			lamp.visible = false
			lamp.texture = _glow_tex
			lamp.color = Color(1.0, 0.56, 0.26)
			lamp.energy = 0.0
			lamp.blend_mode = Light2D.BLEND_MODE_ADD
			add_child(lamp)
			var s := Slot.new()
			s.node = lamp
			_blast_light.append(s)


func _build_particles() -> void:
	# مقدارهای scale نسبت به DOT_TEX_SIZE (۳۲ پیکسل) هستند:
	# ۰.۱ ≈ ۳ پیکسل، ۰.۲۵ ≈ ۸ پیکسل، ۰.۵ ≈ ۱۶ پیکسل.
	for i in N_SPARK:
		var p := _make_particles(10, 0.30, 0.10, 0.20)
		p.initial_velocity_min = 260.0
		p.initial_velocity_max = 720.0
		p.spread = 20.0
		p.gravity = Vector2(0, 520)
		p.damping_min = 1.0
		p.damping_max = 3.0
		p.material = _mat_add
		p.color_ramp = _ramp(Color(1, 1, 0.85, 1), Color(1, 0.45, 0.05, 0.0))
		_spark.append(p)

	for i in N_SMOKE:
		var p := _make_particles(6, 0.75, 0.20, 0.55)
		p.initial_velocity_min = 40.0
		p.initial_velocity_max = 130.0
		p.spread = 28.0
		p.gravity = Vector2(0, -30)
		p.damping_min = 2.0
		p.damping_max = 4.0
		p.material = _mat_flat
		p.scale_amount_curve = _grow_curve()
		p.color_ramp = _ramp(Color(0.65, 0.62, 0.58, 0.42), Color(0.45, 0.43, 0.42, 0.0))
		_smoke.append(p)

	# جرقه‌های ریزِ برخورد به بدن: بدون جاذبه (چکه نمی‌کنند)، فقط با ترمزِ
	# هوا می‌ایستند و طلایی محو می‌شوند.
	for i in N_HIT:
		var p := _make_particles(14, 0.36, 0.10, 0.22)
		p.initial_velocity_min = 170.0
		p.initial_velocity_max = 400.0
		p.spread = 60.0
		p.gravity = Vector2.ZERO
		p.damping_min = 380.0
		p.damping_max = 700.0
		p.material = _mat_add
		p.color_ramp = _ramp(COL_HIT_HOT, Color(COL_HIT.r, COL_HIT.g, COL_HIT.b, 0.0))
		_hit.append(p)

	# برقِ طلاییِ دورِ ابرِ ناک‌اوت
	for i in N_KO_SPARK:
		var p := _make_particles(18, 0.6, 0.08, 0.18)
		p.initial_velocity_min = 120.0
		p.initial_velocity_max = 280.0
		p.spread = 180.0
		p.gravity = Vector2(0, -60)
		p.damping_min = 300.0
		p.damping_max = 520.0
		p.material = _mat_add
		p.color_ramp = _ramp(Color(1.0, 0.96, 0.7, 1.0), Color(1.0, 0.72, 0.12, 0.0))
		_ko_spark.append(p)

	for i in N_DEBRIS:
		var p := _make_particles(38, 0.85, 0.12, 0.45)
		p.initial_velocity_min = 220.0
		p.initial_velocity_max = 780.0
		p.spread = 180.0
		p.gravity = Vector2(0, 700)
		p.damping_min = 0.8
		p.damping_max = 2.5
		p.material = _mat_add
		p.color_ramp = _ramp(Color(1.0, 0.92, 0.62, 1.0), Color(0.85, 0.16, 0.02, 0.0))
		_debris.append(p)

	for i in N_HEAL:
		var p := _make_particles(18, 0.85, 0.10, 0.20)
		p.initial_velocity_min = 90.0
		p.initial_velocity_max = 200.0
		p.spread = 180.0
		p.direction = Vector2(0, -1)
		p.gravity = Vector2(0, 180)
		p.material = _mat_add
		p.color_ramp = _ramp(Color(0.4, 1.0, 0.5, 1.0), Color(0.1, 0.8, 0.3, 0.0))
		_heal.append(p)

	# --- نفرینِ شیطان ---
	# اخگرها: تندتر، بیشتر و دیرپاتر از ترکشِ بمب، با دنباله‌ی سرخ.
	# عمرِ متفاوتِ ذرات (lifetime_randomness) مهم است: با عمرِ یکسان همه‌شان
	# دقیقاً با هم خاموش می‌شوند و انفجار «بریده» به نظر می‌رسد.
	for i in N_EMBER:
		var p := _make_particles(64, 1.05, 0.10, 0.42)
		p.lifetime_randomness = 0.55
		p.initial_velocity_min = 300.0
		p.initial_velocity_max = 1150.0
		p.spread = 180.0
		p.gravity = Vector2(0, 620)
		p.damping_min = 1.2
		p.damping_max = 3.4
		p.material = _mat_add
		p.color_ramp = _ramp(Color(1.0, 0.95, 0.72, 1.0), Color(0.92, 0.10, 0.05, 0.0))
		_ember.append(p)

	# خاکسترِ سنگین که بعد از آتش بالا می‌رود و آخرین چیزی است که می‌ماند
	for i in N_ASH:
		var p := _make_particles(22, 1.6, 0.35, 0.95)
		p.lifetime_randomness = 0.4
		p.initial_velocity_min = 60.0
		p.initial_velocity_max = 220.0
		p.spread = 180.0
		p.gravity = Vector2(0, -45)
		p.damping_min = 2.0
		p.damping_max = 4.5
		p.material = _mat_flat
		p.scale_amount_curve = _grow_curve()
		p.angular_velocity_min = -60.0
		p.angular_velocity_max = 60.0
		p.color_ramp = _ramp(Color(0.34, 0.20, 0.18, 0.75), Color(0.16, 0.13, 0.14, 0.0))
		_ash.append(p)


## تأییدِ کیل: حلقه‌ی طلایی + ستاره‌ی کوتاه + سکه و عددش (kill_confirm)
func _build_kill_marks() -> void:
	var coin_tex: Texture2D = null
	if ResourceLoader.exists(COIN_TEX_PATH):
		coin_tex = load(COIN_TEX_PATH)
	var font: Font = null
	if ResourceLoader.exists(FONT_PATH):
		font = load(FONT_PATH)
	for i in N_KILL:
		var root := Node2D.new()
		root.visible = false
		root.z_index = Z_FX + 6
		root.z_as_relative = false
		add_child(root)

		var ring := Line2D.new()
		ring.name = "Ring"
		ring.material = _mat_add
		ring.default_color = COL_KILL
		ring.width = 4.0
		ring.joint_mode = Line2D.LINE_JOINT_ROUND
		for k in 33:
			ring.add_point(Vector2.from_angle(TAU * float(k) / 32.0) * 30.0)
		root.add_child(ring)

		var star := Polygon2D.new()
		star.name = "Star"
		star.material = _mat_add
		star.polygon = _star(4, 34.0, 7.0)
		star.color = Color(1.0, 0.93, 0.62, 0.9)
		root.add_child(star)

		var coin := Sprite2D.new()
		coin.name = "Coin"
		coin.material = _mat_flat
		coin.texture = coin_tex
		if coin_tex != null:
			var k := 26.0 / float(maxi(coin_tex.get_width(), 1))
			coin.scale = Vector2(k, k)
		coin.set_meta("base_scale", coin.scale.x)
		root.add_child(coin)

		var lbl := Label.new()
		lbl.name = "Amount"
		if font != null:
			lbl.add_theme_font_override("font", font)
		lbl.add_theme_color_override("font_color", COL_DMG_MINE)
		lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.0, 0.95))
		lbl.add_theme_constant_override("outline_size", 8)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# اندازه‌ی برچسب در مقیاسِ سکه است؛ فونت را برعکسِ همان مقیاس بزرگ می‌کنیم
		var inv := 1.0 / maxf(coin.scale.x, 0.001)
		lbl.add_theme_font_size_override("font_size", int(26.0 * inv))
		lbl.size = Vector2(90.0, 40.0) * inv
		lbl.position = Vector2(16.0, -20.0) * inv
		coin.add_child(lbl)

		var s := Slot.new()
		s.node = root
		_kill.append(s)


func _make_particles(amount: int, life: float, smin: float, smax: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false          # ذرات دنبال نود نمی‌روند، سر جایشان می‌مانند
	p.amount = amount
	p.lifetime = life
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	p.z_index = Z_FX
	p.z_as_relative = false
	# 🌟 مهم: بدون texture هر ذره یک مربعِ تخت رسم می‌شود (پیش‌فرض CPUParticles2D)
	# — دلیل اصلیِ «مربعی و بی‌ریخت» بودنِ افکت قبلی. با این نقطه‌ی گردِ نرم،
	# هر ذره یک قطره‌ی گرد با لبه‌ی محو می‌شود.
	# توجه: scale_amount نسبت به DOT_TEX_SIZE است، پس ۰.۲۵ یعنی ۸ پیکسل.
	if _dot_tex != null:
		p.texture = _dot_tex
	add_child(p)
	return p


## مربعِ سفیدِ ساده. فقط برای این است که شیدرهای دایره‌ای یک quad با
## UV صفر تا یک داشته باشند؛ خودِ رنگش هیچ‌جا استفاده نمی‌شود.
func _make_quad_texture() -> ImageTexture:
	var img := Image.create(QUAD_TEX_SIZE, QUAD_TEX_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)


## نقطه‌ی گردِ نرم (سفید، با آلفای محوشونده به لبه) — یک بار ساخته می‌شود.
func _make_dot_texture() -> ImageTexture:
	var size := DOT_TEX_SIZE
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) * 0.5
	var half := size * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(x - c, y - c).length() / half
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			a = a * a                       # لبه‌ی نرم‌تر و مرکز پرتر
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------ کمکی‌های شکل

func _star(points: int, outer: float, inner: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := points * 2
	for i in n:
		var ang := TAU * float(i) / float(n)
		var r := outer if i % 2 == 0 else inner
		out.append(Vector2(cos(ang), sin(ang)) * r)
	return out


## ستاره‌ی جاگ‌دار برای انفجار/فلش شلیک: طول هر شاخه جدا رندوم می‌شود (بین
## outer_min و outer_max) تا شکل نامنظم و طبیعی باشد — نه یک چندضلعیِ صاف که
## از دور شبیه مربع/لوزی دیده شود. رنگ هر رأس هم برمی‌گردد تا با
## Polygon2D.vertex_colors یک گرادیانِ مرکز-روشن به نوک-تیره ساخته شود.
func _jagged_star(points: int, outer_min: float, outer_max: float, inner: float,
		inner_color: Color, outer_color: Color) -> Dictionary:
	var poly := PackedVector2Array()
	var colors := PackedColorArray()
	var n := points * 2
	for i in n:
		var ang := TAU * float(i) / float(n)
		if i % 2 == 0:
			var r := _rng.randf_range(outer_min, outer_max)
			poly.append(Vector2(cos(ang), sin(ang)) * r)
			colors.append(outer_color)
		else:
			poly.append(Vector2(cos(ang), sin(ang)) * inner)
			colors.append(inner_color)
	return {"polygon": poly, "colors": colors}


## شکل علامت «+» با بازوی arm و ضخامت thick، وسطش روی (۰،۰).
func _plus_shape(arm: float, thick: float) -> PackedVector2Array:
	var t := thick * 0.5
	return PackedVector2Array([
		Vector2(-t, -arm), Vector2(t, -arm), Vector2(t, -t), Vector2(arm, -t),
		Vector2(arm, t), Vector2(t, t), Vector2(t, arm), Vector2(-t, arm),
		Vector2(-t, t), Vector2(-arm, t), Vector2(-arm, -t), Vector2(-t, -t),
	])


func _blob(radius: float, segments: int, rough: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in segments:
		var ang := TAU * float(i) / float(segments)
		var r: float = radius * (1.0 - rough * _rng.randf())
		out.append(Vector2(cos(ang), sin(ang)) * r)
	return out


func _ramp(from: Color, to: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, from)
	g.set_color(1, to)
	return g


func _grow_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.35))
	c.add_point(Vector2(1.0, 1.0))
	return c


## صفر تا یک، با کمی رد شدن از یک و برگشتن — همان «پاپ»ِ کشسانِ کارتونی.
func _ease_out_back(x: float) -> float:
	var c1 := 1.9
	var t := x - 1.0
	return 1.0 + (c1 + 1.0) * t * t * t + c1 * t * t


# =================================================================== API

## مسیر تیر را پیدا می‌کند: تا اولین دیوار یا بازیکن، وگرنه تا برد بیشینه.
## خروجی: [نقطه‌ی برخورد, آیا به بدن خورده]
func resolve_hit(from: Vector2, dir: Vector2, exclude: Array = []) -> Array:
	var world := get_world_2d()
	if world == null or dir == Vector2.ZERO:
		return [from + dir * TRACER_RANGE, false]
	_ray.from = from
	_ray.to = from + dir * TRACER_RANGE
	_ray.collision_mask = 3          # لایه ۱ دیوار + لایه ۲ بازیکن‌ها
	_ray.exclude = exclude
	var hit := world.direct_space_state.intersect_ray(_ray)
	if hit.is_empty():
		return [from + dir * TRACER_RANGE, false]
	var body: Variant = hit.get("collider")
	var on_body: bool = body is Node and (body as Node).is_in_group("enemy")
	return [hit["position"], on_body]


## کل افکت یک شلیک: فلش دهانه + رد گلوله + پوکه + دود + برخورد.
## register_hit=false یعنی این شلیک طبق دقتِ کاراکتر خطا رفته: تیر تا مقصد
## می‌رود ولی هیچ جرقه‌ای نمی‌زند (نه از دیوار، نه از بدن) — همان اثرِ
## بصریِ aim_accuracy.
func shoot(muzzle: Vector2, dir: Vector2, hit_pos: Vector2, on_body: bool, local: bool = false, register_hit: bool = true) -> void:
	if dir == Vector2.ZERO:
		return
	dir = dir.normalized()
	muzzle_flash(muzzle, dir)
	# جرقه‌ی برخورد وقتی پخش می‌شود که گلوله واقعاً به مقصد برسد،
	# نه همان لحظه‌ی شلیک — وگرنه انفجار جلوتر از گلوله دیده می‌شود.
	var on_arrive := 0
	if register_hit:
		on_arrive = 2 if on_body else 1
	tracer(muzzle, hit_pos, on_arrive)
	eject_shell(muzzle, dir)
	if local:
		shake(_shot_shake_amount(), 14.0)


## اندازه‌ی لرزشِ یک شلیکِ خودی. fire_cooldownِ سلاح همان فاصله‌ی دو شلیکِ
## پشتِ‌سرِ‌هم است؛ از همین‌جا اندازه می‌گیریم تا به اسکریپتِ شلیک‌کننده
## (بازیکن یا ربات) وابسته نباشیم.
func _shot_shake_amount() -> float:
	var now := float(Time.get_ticks_msec()) * 0.001
	var gap := now - _last_local_shot
	_last_local_shot = now
	if gap > SHOT_SHAKE_IDLE:
		return SHOT_SHAKE_SINGLE
	return clampf(gap * SHOT_SHAKE_PER_SEC, SHOT_SHAKE_MIN, SHOT_SHAKE_MAX)


## چند نورِ لوله‌ی هم‌زمان در کیفیتِ فعلی مجاز است
func _muzzle_lamp_cap() -> int:
	var level := LocalSettings.quality_level()
	if level == LocalSettings.QUALITY_LOW:
		return 0
	if level == LocalSettings.QUALITY_MEDIUM:
		return MUZZLE_LAMPS_MEDIUM
	return MUZZLE_LAMPS_HIGH


func _lamp_off(s: Slot) -> void:
	if s.lamp != null:
		s.lamp.visible = false
		s.lamp.energy = 0.0
	_lit_flashes.erase(s)


## فلش دهانه‌ی اسلحه.
func muzzle_flash(pos: Vector2, dir: Vector2) -> void:
	var s := _take(_flash, _i_flash)
	_i_flash = (_i_flash + 1) % N_FLASH
	var n := s.node
	n.global_position = pos
	n.rotation = dir.angle()
	# هر شلیک کمی فرق داشته باشد وگرنه تکراری به نظر می‌رسد
	s.f = _rng.randf_range(0.9, 1.2)

	# شکل ستاره هر بار از نو ساخته می‌شود (فقط داده‌ی پلیگان، نه نود تازه)
	# تا طول شاخه‌ها هر شلیک فرق کند — دقیقاً حس رفرنس که هیچ دو انفجاری
	# عین هم نبودند.
	var outer := n.get_node("StarOuter") as Polygon2D
	var od := _jagged_star(8, 20.0, 34.0, 4.0,
		Color(1.0, 0.62, 0.15, 0.95), Color(0.85, 0.10, 0.02, 0.85))
	outer.polygon = od["polygon"]
	outer.vertex_colors = od["colors"]
	outer.rotation = _rng.randf_range(-0.3, 0.3)

	var inr := n.get_node("StarInner") as Polygon2D
	var idata := _jagged_star(7, 10.0, 18.0, 2.5,
		Color(1.0, 0.96, 0.75, 1.0), Color(1.0, 0.55, 0.10, 0.9))
	inr.polygon = idata["polygon"]
	inr.vertex_colors = idata["colors"]
	inr.rotation = _rng.randf_range(-0.6, 0.6)

	n.scale = Vector2(s.f, s.f)
	n.modulate = Color(1, 1, 1, 1)
	n.visible = true

	# نور همین‌جا روشن می‌شود و نه در _step_flash: عمرِ فلش ۰.۱۲ ثانیه (~۷
	# فریم) است، پس یک فریم تاخیر یعنی اولین و درخشان‌ترین فریمِ شلیک بی‌نور
	_lamp_off(s)   # اگر همین اسلات هنوز نورِ شلیکِ قبلی را داشت
	if s.lamp != null:
		var cap := _muzzle_lamp_cap()
		while _lit_flashes.size() >= cap and not _lit_flashes.is_empty():
			_lamp_off(_lit_flashes[0])
		if cap > 0:
			s.lamp.energy = MUZZLE_LIGHT_ENERGY
			s.lamp.visible = true
			_lit_flashes.append(s)

	_start(s, FLASH_LIFE)

	# پف دود کوچک جلوی لوله
	var sm := _aim(_smoke, _i_smoke, pos + dir * 30.0, dir)
	_i_smoke = (_i_smoke + 1) % N_SMOKE
	sm.restart()


## رد گلوله از دهانه تا نقطه‌ی برخورد.
## on_arrive: 0 هیچ، 1 جرقه‌ی دیوار، 2 جرقه‌ی بدن — وقتی گلوله رسید اجرا می‌شود.
func tracer(from: Vector2, to: Vector2, on_arrive: int = 0) -> void:
	var s := _take(_tracer, _i_tracer)
	_i_tracer = (_i_tracer + 1) % N_TRACER
	s.a = from
	s.b = to
	s.f = from.distance_to(to)
	s.g = float(on_arrive)
	var n := s.node
	n.position = Vector2.ZERO        # خطوط با مختصات جهانی رسم می‌شوند
	n.rotation = 0.0
	n.modulate = Color(1, 1, 1, 1)
	n.visible = true

	var trail := n.get_node("Trail") as Line2D
	trail.set_point_position(0, from)
	trail.set_point_position(1, to)
	trail.width = 3.0

	var bolt := n.get_node("Bolt") as Line2D
	bolt.set_point_position(0, from)
	bolt.set_point_position(1, from)
	bolt.width = 6.0

	# زنده می‌ماند تا گلوله به مقصد برسد و رد هم محو شود
	_start(s, maxf(TRAIL_LIFE, s.f / TRACER_SPEED + 0.035))


## برخورد: به دیوار جرقه‌ی نارنجی، به بدن «پاو»ِ طلایی.
func impact(pos: Vector2, back_dir: Vector2, on_body: bool) -> void:
	if on_body:
		hit_burst(pos, back_dir)
		return
	var p := _aim(_spark, _i_spark, pos, back_dir)
	_i_spark = (_i_spark + 1) % N_SPARK
	p.spread = 34.0
	p.restart()


## ضربه خوردنِ کاراکتر: چند جرقه‌ی طلایی + «پاو»ِ کارتونی — بدون هیچ مایعی.
## big برای ضربه‌ی محکم‌تر است: فقط پاو بزرگ‌تر و جرقه‌ها همه‌طرفه می‌شوند.
func hit_burst(pos: Vector2, dir: Vector2, big: bool = false) -> void:
	var p := _aim(_hit, _i_hit, pos, dir)
	_i_hit = (_i_hit + 1) % N_HIT
	p.spread = 180.0 if big else 60.0
	p.restart()
	hit_pop(pos, dir, big)


## ستاره‌ی جاگ‌دارِ سفید-طلاییِ لحظه‌ی ضربه (کوتاه و پرانرژی، مثل فلش شلیک).
func hit_pop(pos: Vector2, dir: Vector2, big: bool = false) -> void:
	var s := _take(_pop, _i_pop)
	_i_pop = (_i_pop + 1) % N_POP
	var n := s.node
	n.global_position = pos
	n.rotation = dir.angle() if dir != Vector2.ZERO else _rng.randf_range(0.0, TAU)
	s.f = _rng.randf_range(1.1, 1.4) if big else _rng.randf_range(0.7, 0.95)

	# شکل هر پاو از نو ساخته می‌شود تا دوتا شبیه هم نباشند
	var burst := n.get_node("Burst") as Polygon2D
	var bd := _jagged_star(8, 14.0, 28.0, 6.0,
		Color(COL_HIT_HOT.r, COL_HIT_HOT.g, COL_HIT_HOT.b, 0.95),
		Color(COL_HIT.r, COL_HIT.g, COL_HIT.b, 0.6))
	burst.polygon = bd["polygon"]
	burst.vertex_colors = bd["colors"]
	burst.rotation = _rng.randf_range(-0.4, 0.4)

	n.scale = Vector2(s.f, s.f)
	n.modulate = Color(1, 1, 1, 1)
	n.visible = true
	_start(s, POP_LIFE)


## ناک‌اوت: پفِ دودِ کارتونی + ستاره‌هایی که از آن بیرون می‌پرند + برقِ طلایی.
## فقط افکت است و به هیچ نودی دست نمی‌زند؛ ناپدید کردنِ خودِ کاراکتر با
## death() یا خودِ صدازننده است. size = ۱ یعنی اندازه‌ی کاراکترِ معمولی.
func knockout(pos: Vector2, size: float = 1.0) -> void:
	if not _poof.is_empty():
		var s := _take(_poof, _i_poof) as PoofSlot
		_i_poof = (_i_poof + 1) % _poof.size()
		s.f = size
		s.b = pos
		s.node.global_position = pos
		var base_ang := _rng.randf_range(0.0, TAU)
		for i in KO_PUFFS:
			if i == 0:
				# پفِ درشتِ وسط آخر از همه خورده می‌شود تا کاراکتر پشتش گم شود
				s.dir[i] = Vector2.ZERO
				s.dist[i] = 0.0
				s.rad[i] = _rng.randf_range(18.0, 21.0)
				s.delay[i] = 0.5
			elif i <= KO_RING:
				var ang := base_ang + TAU * float(i - 1) / float(KO_RING) + _rng.randf_range(-0.25, 0.25)
				s.dir[i] = Vector2.from_angle(ang)
				s.dist[i] = _rng.randf_range(15.0, 24.0)
				s.rad[i] = _rng.randf_range(11.0, 15.0)
				s.delay[i] = _rng.randf_range(0.28, 0.42)
			else:
				# تکه‌های ریزی که دورتر پرت می‌شوند و زودتر از همه می‌روند
				s.dir[i] = Vector2.from_angle(_rng.randf_range(0.0, TAU))
				s.dist[i] = _rng.randf_range(34.0, 46.0)
				s.rad[i] = _rng.randf_range(5.0, 7.5)
				s.delay[i] = _rng.randf_range(0.1, 0.22)
			s.spin[i] = _rng.randf_range(-2.2, 2.2)
			s.noise_seed[i] = _rng.randf()
		_start(s, KO_LIFE)
		s.node.visible = true
		_step_poof(s, 0.0)                   # همین فریم درست چیده شود، نه یک فریم بعد

	# ستاره‌ها بادبزنی رو به بالا پرت می‌شوند و با جاذبه قوس می‌زنند
	for i in mini(KO_STARS, _ko_star.size()):
		var s := _take(_ko_star, _i_ko_star)
		_i_ko_star = (_i_ko_star + 1) % _ko_star.size()
		var star := s.node as Sprite2D
		var ang := -PI * 0.5 + lerpf(-1.2, 1.2, (float(i) + 0.5) / float(KO_STARS)) \
			+ _rng.randf_range(-0.15, 0.15)
		s.a = Vector2.from_angle(ang) * _rng.randf_range(160.0, 230.0) * size
		s.b = pos + Vector2(0.0, -6.0 * size)
		s.f = KO_STAR_PX / float(star.texture.get_width()) * _rng.randf_range(0.8, 1.15) * size
		s.g = _rng.randf_range(-7.0, 7.0)    # چرخش
		star.global_position = s.b
		star.rotation = _rng.randf_range(-0.4, 0.4)
		star.scale = Vector2.ZERO
		star.modulate = Color(1, 1, 1, 1)
		star.visible = false                 # تا نوبتش نرسیده دیده نشود
		_start(s, KO_STAR_LIFE)
		s.t = -0.035 * float(i)              # پلکانی بیرون بپرند

	if not _ko_spark.is_empty():
		var p := _ko_spark[_i_ko_spark]
		_i_ko_spark = (_i_ko_spark + 1) % _ko_spark.size()
		p.global_position = pos
		p.restart()


## پوکه‌ای که از کنار اسلحه بیرون می‌پرد.
func eject_shell(pos: Vector2, dir: Vector2) -> void:
	var s := _take(_shell, _i_shell)
	_i_shell = (_i_shell + 1) % N_SHELL
	s.a = dir.orthogonal() * _rng.randf_range(150.0, 250.0) - dir * _rng.randf_range(20.0, 70.0)
	s.b = pos - dir * 18.0
	s.f = _rng.randf_range(-14.0, 14.0)
	var n := s.node
	n.global_position = s.b
	n.rotation = dir.angle()
	n.modulate = Color(1, 1, 1, 1)
	n.visible = true
	_start(s, SHELL_LIFE)


## ناک‌اوت شدنِ حریف: ابرِ دود و ستاره‌ها، و خودِ کاراکتر همان اولِ کار
## داخلِ دود جمع و ناپدید می‌شود. with_knockout=false (مثلاً بازیکنی که از
## بازی رفته) یعنی بی‌افکت، فقط محو شدنِ آرام.
## نود بعد از محو شدن خودش آزاد می‌شود، پس queue_free جدا لازم نیست.
func death(victim: Node2D, with_knockout: bool = true, fade_time: float = 0.55) -> void:
	if victim == null or not is_instance_valid(victim):
		return
	var shrink := 0.72
	if with_knockout:
		knockout(victim.global_position)
		shake(6.0, 10.0)
		# پفِ دود در همین مدت کامل شده؛ کاراکتر باید پشتش گم شود، نه بعدش
		fade_time = minf(fade_time, KO_HIDE_TIME)
		shrink = 0.5

	# برخورد و نوار جان را همان لحظه ببند تا وسط محو شدن مزاحم نشوند
	if victim is CollisionObject2D:
		var co := victim as CollisionObject2D
		co.set_deferred("collision_layer", 0)
		co.set_deferred("collision_mask", 0)
	victim.set_physics_process(false)
	var bar := victim.get_node_or_null("HealthBar")
	if bar is CanvasItem:
		(bar as CanvasItem).visible = false

	var tw := victim.create_tween()
	tw.set_parallel(true)
	tw.tween_property(victim, "modulate:a", 0.0, fade_time).set_ease(Tween.EASE_IN)
	tw.tween_property(victim, "scale", victim.scale * shrink, fade_time).set_ease(Tween.EASE_IN)
	tw.tween_property(victim, "rotation", victim.rotation + 0.5, fade_time)
	tw.chain().tween_callback(victim.queue_free)


# ------------------------------------------------------------------- بمب

## پیش‌نمایش نشانه‌گیریِ بمب: خطِ پرتاب + دایره‌ی محدوده در نقطه‌ی هدف.
## تا وقتی انگشت روی دکمه است هر فریم صدا زده می‌شود.
## in_range اگر false باشد (بیرون از بردِ کاراکتر) رنگ خاکستری می‌شود.
func bomb_aim(from: Vector2, target: Vector2, radius: float, in_range: bool = true) -> void:
	if _aim_root == null:
		return
	_aim_root.visible = true

	var col: Color = Color(1.0, 0.78, 0.20) if in_range else Color(0.55, 0.55, 0.58)

	var line := _aim_root.get_node("Path") as Line2D
	line.set_point_position(0, from)
	line.set_point_position(1, target)
	line.default_color = Color(col.r, col.g, col.b, 0.55)

	var zone := _aim_root.get_node("Zone") as Sprite2D
	zone.global_position = target
	var k := (radius * 2.0) / float(QUAD_TEX_SIZE)
	zone.scale = Vector2(k, k)
	var mat := zone.material as ShaderMaterial
	# progress = 0 یعنی هنوز شمارش معکوسی شروع نشده: فقط حلقه و بدنه‌ی کم‌رنگ
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("fade", 1.0 if in_range else 0.6)
	mat.set_shader_parameter("col_edge", col)

	var cross := _aim_root.get_node("Cross") as Node2D
	cross.global_position = target
	cross.modulate = col


## بستنِ پیش‌نمایش نشانه‌گیری
func bomb_aim_hide() -> void:
	if _aim_root != null:
		_aim_root.visible = false

## نشانگر محدوده‌ی بمب: حلقه‌ی خط‌چینِ چرخان + موجِ پرشونده‌ای که با فیوز
## هماهنگ است، پس بازیکن دقیقاً می‌بیند کجا و کِی منفجر می‌شود.
## fuse ثانیه‌ی باقی‌مانده تا انفجار است.
func bomb_marker(pos: Vector2, radius: float, fuse: float) -> void:
	if _zone.is_empty():
		return
	var s := _take(_zone, _i_zone)
	_i_zone = (_i_zone + 1) % _zone.size()
	var n := s.node as Sprite2D
	n.global_position = pos
	# مربعِ نود باید دقیقاً قطر محدوده باشد تا لبه‌ی شیدر روی شعاع واقعی بیفتد
	var k := (radius * 2.0) / float(QUAD_TEX_SIZE)
	n.scale = Vector2(k, k)
	n.visible = true
	var mat := n.material as ShaderMaterial
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("fade", 1.0)
	# g = ۰ یعنی هنوز در حال شمارش معکوس؛ بعد از انفجار می‌شود ۱ (در حال محو)
	s.g = 0.0
	_start(s, maxf(fuse, 0.05))


## انفجار کامل: گلوله‌ی آتش + موج ضربه + ترکش + دود + لرزش + جای سوختگی.
func explosion(pos: Vector2, radius: float) -> void:
	# ۱) گلوله‌ی آتش
	if not _boom.is_empty():
		var s := _take(_boom, _i_boom)
		_i_boom = (_i_boom + 1) % _boom.size()
		var n := s.node
		n.global_position = pos
		n.rotation = _rng.randf_range(0.0, TAU)
		# اندازه نسبت به شعاع واقعی انفجار (ستاره‌ها حدود ۵۰ واحد پایه‌اند)
		s.f = radius / 55.0

		var outer := n.get_node("StarOuter") as Polygon2D
		var od := _jagged_star(9, 34.0, 58.0, 9.0,
			Color(1.0, 0.66, 0.18, 0.95), Color(0.80, 0.09, 0.02, 0.75))
		outer.polygon = od["polygon"]
		outer.vertex_colors = od["colors"]
		outer.rotation = _rng.randf_range(-0.4, 0.4)

		var inr := n.get_node("StarInner") as Polygon2D
		var idata := _jagged_star(8, 18.0, 34.0, 6.0,
			Color(1.0, 0.97, 0.80, 1.0), Color(1.0, 0.52, 0.08, 0.9))
		inr.polygon = idata["polygon"]
		inr.vertex_colors = idata["colors"]
		inr.rotation = _rng.randf_range(-0.7, 0.7)

		n.scale = Vector2(s.f, s.f)
		n.modulate = Color(1, 1, 1, 1)
		n.visible = true
		_start(s, BOOM_LIFE)

	# ۲) موج ضربه — کمی از خود محدوده بزرگ‌تر باز می‌شود
	if not _wave.is_empty():
		var s := _take(_wave, _i_wave)
		_i_wave = (_i_wave + 1) % _wave.size()
		var n := s.node as Sprite2D
		n.global_position = pos
		var span := radius * 2.6
		var k := (span * 2.0) / float(QUAD_TEX_SIZE)
		n.scale = Vector2(k, k)
		# مدولیت را صریح سفید می‌کنیم: همین اسلات ممکن است دفعه‌ی قبل حلقه‌ی
		# رنگیِ نفرینِ شیطان بوده باشد و رنگش جا مانده باشد
		n.modulate = Color(1, 1, 1, 1)
		n.visible = true
		# نسبتِ شعاع محدوده به نصف پهنای نود — موج تا همین‌جا باز می‌شود
		s.f = radius / span
		var mat := n.material as ShaderMaterial
		mat.set_shader_parameter("radius", 0.0)
		mat.set_shader_parameter("thickness", 0.12)
		mat.set_shader_parameter("fade", 1.0)
		_start(s, WAVE_LIFE)

	# ۳) ترکش و دود
	if not _debris.is_empty():
		var p := _aim(_debris, _i_debris, pos, Vector2.RIGHT)
		_i_debris = (_i_debris + 1) % _debris.size()
		p.restart()
	var sm := _aim(_smoke, _i_smoke, pos, Vector2(0, -1))
	_i_smoke = (_i_smoke + 1) % N_SMOKE
	sm.spread = 180.0
	sm.restart()

	# ۴) جای سوختگی
	scorch(pos, radius)

	# ۵) لرزش سنگین — V7: با فاصله از دوربین کم می‌شود؛ انفجارِ آن سرِ نقشه
	# نباید تصویرِ تو را بلرزاند (و سرگیجه بیاورد)
	shake(16.0 * _proximity(pos), 7.0)


# ==================== نفرینِ شیطان ====================

## اخطارِ نفرین: محدوده روی زمین علامت می‌خورد و حلقه‌اش در طولِ fuse به
## سمتِ مرکز فرو می‌ریزد. رسیدنش به مرکز یعنی همین حالا می‌ترکد.
##
## fuse همان مهلتی است که سرور می‌دهد (demon.go → DemonBlastWarn)، پس چیزی
## که بازیکن می‌بیند دقیقاً با لحظه‌ی واقعیِ انفجار یکی است.
func demon_mark(pos: Vector2, radius: float, fuse: float) -> void:
	if _mark.is_empty():
		# شیدر نبود — دستِ‌کم نشانگرِ معمولی را نشان بده، وگرنه بازیکن
		# بدونِ هیچ اخطاری خسارت می‌خورد
		bomb_marker(pos, radius, fuse)
		return
	var s := _take(_mark, _i_mark)
	_i_mark = (_i_mark + 1) % _mark.size()
	var n := s.node as Sprite2D
	n.global_position = pos
	# کوآد باید دقیقاً قطرِ محدوده باشد تا لبه‌ی شیدر روی شعاعِ واقعی بیفتد
	var k := (radius * 2.0) / float(QUAD_TEX_SIZE)
	n.scale = Vector2(k, k)
	n.visible = true
	var mat := n.material as ShaderMaterial
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("fade", 1.0)
	# f مقیاسِ پایه است — _step_mark جمع‌شدن و پاره شدنِ آخر را نسبت به آن
	# حساب می‌کند، پس باید همین‌جا ثبت شود
	s.f = k
	# g = ۰ یعنی در حال شمارشِ معکوس، ۱ یعنی ترکیده و در حال محو شدن
	s.g = 0.0
	_start(s, maxf(fuse, 0.05))


## انفجارِ نفرینِ شیطان — نسخه‌ی سنگینِ explosion().
##
## هشت لایه که عمداً هم‌زمان تمام نمی‌شوند، به همان ترتیبی که یک انفجارِ
## واقعی جلو می‌رود:
##
##   ۰ms    ترکشِ سفید + نورِ تندِ صحنه (چشم اول این را می‌گیرد)
##   ۰ms    گلوله‌ی آتشِ جاگ‌دار، با کمی رد شدن از اندازه و برگشتن
##   ۲۰ms   موجِ گرما — تصویرِ پشتش کج می‌شود، پس انفجار «روی» صحنه نیست
##   ۰ms    دو حلقه‌ی ضربه با تاخیرِ کوتاه (یکی پرنور، یکی پهن‌تر و کم‌جان)
##   ۰ms    اخگرها به همه طرف
##   ۱۲۰ms  خاکستر که بالا می‌رود و آخرین چیزی است که می‌ماند
##   ۰ms    لرزشِ سنگینِ دوربین
##   بعد    جای سوختگیِ روی زمین (چند ثانیه می‌ماند)
##
## همه‌ی زمان‌بندی روی Slotها است و نه Tween/await، پس حتی وقتی چند انفجار
## پشتِ هم می‌آید نه نودی ساخته می‌شود نه کوروتینی باز می‌ماند.
func demon_blast(pos: Vector2, radius: float) -> void:
	# ۱) ترکشِ سفیدِ اولِ کار
	if not _blast_flash.is_empty():
		var s := _take(_blast_flash, _i_blast_flash)
		_i_blast_flash = (_i_blast_flash + 1) % _blast_flash.size()
		var n := s.node
		n.global_position = pos
		n.rotation = _rng.randf_range(0.0, TAU)
		# بافتِ نور ۲۵۰ پیکسل است و از مرکزش پخش می‌شود
		s.f = (radius * 2.2) / 250.0
		n.scale = Vector2(s.f, s.f)
		n.modulate = Color(1, 1, 1, 1)
		n.visible = true
		_start(s, BLAST_FLASH_LIFE)

	# ۲) نورِ واقعی
	if not _blast_light.is_empty():
		var s := _take(_blast_light, _i_blast_light)
		_i_blast_light = (_i_blast_light + 1) % _blast_light.size()
		var lamp := s.node as PointLight2D
		lamp.global_position = pos
		# شعاعِ روشنایی کمی از خودِ انفجار بزرگ‌تر، تا محیط هم روشن شود
		var lk := (radius * 3.0) / 250.0
		lamp.scale = Vector2(lk, lk)
		lamp.energy = BLAST_LIGHT_ENERGY
		lamp.visible = true
		_start(s, BLAST_LIGHT_LIFE)

	# ۳) گلوله‌ی آتش + حلقه + ترکش + سوختگی + لرزش (همان انفجارِ پایه)
	explosion(pos, radius)

	# ۴) حلقه‌ی دومِ پهن‌تر و کم‌جان‌تر، کمی عقب‌تر از اولی.
	# یک حلقه‌ی تنها تخت به نظر می‌رسد؛ دوتا با تاخیر، عمق می‌سازد.
	if not _wave.is_empty():
		var s := _take(_wave, _i_wave)
		_i_wave = (_i_wave + 1) % _wave.size()
		var n := s.node as Sprite2D
		n.global_position = pos
		var span := radius * 3.4
		var k := (span * 2.0) / float(QUAD_TEX_SIZE)
		n.scale = Vector2(k, k)
		n.modulate = Color(1.0, 0.72, 0.58, 0.55)
		n.visible = true
		s.f = radius / span
		var mat := n.material as ShaderMaterial
		mat.set_shader_parameter("radius", 0.0)
		mat.set_shader_parameter("thickness", 0.20)
		mat.set_shader_parameter("fade", 1.0)
		_start(s, BLAST_RING_LIFE)
		s.t = -0.09          # کمی دیرتر از حلقه‌ی اول راه بیفتد

	# ۵) موجِ گرما
	if not _heat.is_empty():
		var s := _take(_heat, _i_heat)
		_i_heat = (_i_heat + 1) % _heat.size()
		var n := s.node as Sprite2D
		n.global_position = pos
		var span := radius * 2.8
		var k := (span * 2.0) / float(QUAD_TEX_SIZE)
		n.scale = Vector2(k, k)
		n.visible = true
		s.f = radius / span
		var mat := n.material as ShaderMaterial
		mat.set_shader_parameter("radius", 0.0)
		mat.set_shader_parameter("thickness", 0.16)
		mat.set_shader_parameter("strength", 0.045)
		mat.set_shader_parameter("glow", 0.55)
		_start(s, BLAST_HEAT_LIFE)
		s.t = -0.02

	# ۶) اخگرها و خاکستر
	if not _ember.is_empty():
		var p := _aim(_ember, _i_ember, pos, Vector2.RIGHT)
		_i_ember = (_i_ember + 1) % _ember.size()
		p.restart()
	if not _ash.is_empty():
		var p := _aim(_ash, _i_ash, pos, Vector2(0, -1))
		_i_ash = (_i_ash + 1) % _ash.size()
		p.restart()

	# ۷) لرزشِ اضافه — این انفجار باید از بمب سنگین‌تر حس شود (V7: نزدیکی
	# مهم است؛ سقفِ کلیِ دامنه را خودِ shake می‌گذارد)
	shake(24.0 * _proximity(pos), 6.0)


## جای سوختگیِ روی زمین بعد از انفجار.
func scorch(pos: Vector2, radius: float) -> void:
	if _scorch.is_empty():
		return
	var s := _take(_scorch, _i_scorch)
	_i_scorch = (_i_scorch + 1) % _scorch.size()
	var n := s.node
	n.global_position = pos
	n.rotation = _rng.randf_range(0.0, TAU)
	var k := radius * _rng.randf_range(0.55, 0.75)
	n.scale = Vector2(k, k * _rng.randf_range(0.85, 1.0))
	n.modulate = Color(1, 1, 1, 1)
	n.visible = true
	_start(s, SCORCH_LIFE)


## افکت درمان: کلی علامت + سبزِ روشن که بالا می‌روند و محو می‌شوند،
## به‌علاوه‌ی یک پفِ ذراتِ سبز پشتشان.
func heal(pos: Vector2) -> void:
	var p := _heal[_i_heal]
	_i_heal = (_i_heal + 1) % N_HEAL
	p.global_position = pos
	p.restart()
	plus_burst(pos, 9)


## دسته‌ای علامت + که با تأخیرِ پلکانی از پایین بالا می‌آیند.
func plus_burst(pos: Vector2, count: int = 9) -> void:
	if _plus.is_empty():
		return
	for i in count:
		var s := _take(_plus, _i_plus)
		_i_plus = (_i_plus + 1) % _plus.size()
		var n := s.node
		s.b = pos + Vector2(_rng.randf_range(-34.0, 34.0), _rng.randf_range(-10.0, 22.0))
		s.a = Vector2(_rng.randf_range(-26.0, 26.0), _rng.randf_range(-170.0, -105.0))
		s.f = _rng.randf_range(0.7, 1.25)
		s.g = _rng.randf_range(-1.6, 1.6)        # چرخش آرام
		n.global_position = s.b
		n.rotation = _rng.randf_range(-0.25, 0.25)
		n.scale = Vector2.ZERO
		n.modulate = Color(1, 1, 1, 1)
		n.visible = false                        # تا نوبتش نرسیده دیده نشود
		_start(s, PLUS_LIFE)
		s.t = -0.055 * float(i)                  # پلکانی ظاهر شوند


## عددِ خسارت که از روی هدف بالا می‌رود و محو می‌شود.
## kind — V1/V2 هر رنگ فقط یک معنی:
##   DMG_TAKEN  قرمز: خسارتی که خودت خوردی = خطر (پیش‌فرض، رفتارِ قدیمی)
##   DMG_MINE   طلاییِ درشت: خسارتی که خودت زدی = تأییدِ مهارت (E14)
##   DMG_OTHER  سفیدِ کوچک: درگیریِ بقیه، تا نگاهت را ندزدد (C1)
func damage_number(pos: Vector2, amount: int, healing: bool = false, kind: int = DMG_TAKEN) -> void:
	if amount <= 0:
		return
	if healing:
		float_text(pos, "+" + str(amount), COL_HEAL)
		return
	match kind:
		DMG_MINE:
			float_text(pos, "-" + str(amount), COL_DMG_MINE, 1.2)
		DMG_OTHER:
			float_text(pos, "-" + str(amount), COL_DMG_OTHER, 0.8)
		_:
			float_text(pos, "-" + str(amount), COL_DMG)


## متنِ کوتاهِ شناور بالای سرِ یک بازیکن (مثلاً «خطا» وقتی سرور تیر را رد
## کرد) — همان استخر و حرکتِ عددِ خسارت. size اندازه‌ی نسبی است.
func float_text(pos: Vector2, text: String, colour: Color, size: float = 1.0) -> void:
	if _dmg.is_empty():
		return
	var s := _take(_dmg, _i_dmg)
	_i_dmg = (_i_dmg + 1) % _dmg.size()
	var n := s.node
	s.b = pos + Vector2(_rng.randf_range(-14.0, 14.0), -34.0)
	s.a = Vector2(_rng.randf_range(-30.0, 30.0), -125.0)
	s.f = size
	n.global_position = s.b
	n.scale = Vector2.ZERO
	n.modulate = Color(1, 1, 1, 1)
	n.visible = true

	var lbl := n.get_node("Text") as Label
	lbl.text = text
	lbl.add_theme_color_override("font_color", colour)
	_start(s, DMG_LIFE)


## لرزش دوربین. amount بر حسب پیکسل، decay سرعت خوابیدن لرزش.
## V7: سقفِ SHAKE_CAP دارد (با زومِ ۲ هر واحد دو پیکسلِ صفحه است) و اگر
## بازیکن «لرزش صفحه» را در تنظیمات خاموش کرده باشد اصلاً نمی‌لرزد.
func shake(amount: float, decay: float = 12.0) -> void:
	amount = minf(amount * _shake_setting(), SHAKE_CAP)
	if amount <= 0.01:
		return
	_shake = maxf(_shake, amount)
	_shake_decay = decay
	_wake()


## ۱ یا ۰ از تنظیماتِ «لرزش صفحه» (اگر این نسخه‌ی LocalSettings آن را داشت)
func _shake_setting() -> float:
	if LocalSettings.has_method("screen_shake_scale"):
		return float(LocalSettings.call("screen_shake_scale"))
	return 1.0


## نزدیکیِ یک نقطه به مرکزِ تصویر: ۱ داخلِ قاب، تا ۰ در فاصله‌ی PROX_FAR
func _proximity(pos: Vector2) -> float:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return 1.0
	var d := cam.get_screen_center_position().distance_to(pos)
	return clampf(1.0 - maxf(d - PROX_NEAR, 0.0) / (PROX_FAR - PROX_NEAR), 0.0, 1.0)


## V7 hit-stop: چند ده میلی‌ثانیه دنیا تقریباً می‌ایستد تا ضربه‌ی مهم «وزن»
## داشته باشد. فقط برای کیل (نه هر تیر — رگبار وگرنه لکنت می‌گرفت). زمانش
## با ساعتِ واقعی است (ignore_time_scale) و با خاموش بودنِ لرزشِ صفحه هم
## خاموش می‌شود. اگر صحنه وسطش عوض شود، _exit_tree سرعت را برمی‌گرداند.
func hit_stop(seconds: float, scale: float = 0.08) -> void:
	if seconds <= 0.0 or _shake_setting() <= 0.0 or not is_inside_tree():
		return
	_hit_stop_until = maxf(_hit_stop_until, Time.get_ticks_msec() * 0.001 + seconds)
	if _hit_stopping:
		return
	_hit_stopping = true
	Engine.time_scale = scale
	while Time.get_ticks_msec() * 0.001 < _hit_stop_until and is_inside_tree():
		await get_tree().create_timer(0.016, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stopping = false


## E4/V1 تأییدِ کیل: حلقه‌ی طلایی که باز می‌شود + سکه‌ای که بالا می‌پرد.
## coins > 0 یعنی این کیل واقعاً سکه دارد (سرور: ۵ سکه برای هر کیل تا سقف) و
## عددش کنارِ سکه می‌آید؛ صفر یعنی فقط حلقه و ستاره (مثلاً بازیِ تمرینی که
## پاداشی ندارد — سکه‌ی دروغی نشان نمی‌دهیم). tier: ۱ کیلِ ساده، ۲ به بالا
## مولتی‌کیل که حلقه‌اش درشت‌تر و پرنورتر است.
func kill_confirm(pos: Vector2, coins: int = 0, tier: int = 1) -> void:
	if _kill.is_empty():
		return
	var s := _take(_kill, _i_kill)
	_i_kill = (_i_kill + 1) % _kill.size()
	s.b = pos
	s.f = 1.0 + 0.25 * float(clampi(tier - 1, 0, 3))
	s.g = float(coins)
	var n := s.node
	n.global_position = pos
	n.modulate = Color(1, 1, 1, 1)
	n.visible = true
	var coin := n.get_node_or_null("Coin") as Sprite2D
	if coin != null:
		coin.visible = coins > 0 and coin.texture != null
	var lbl := n.get_node_or_null("Coin/Amount") as Label
	if lbl != null:
		lbl.text = "+" + str(coins)
	_start(s, KILL_LIFE)
	_step_kill(s, 0.0)


func _exit_tree() -> void:
	if _hit_stopping:
		Engine.time_scale = 1.0
		_hit_stopping = false


# ========================================================= موتور به‌روزرسانی

func _take(pool: Array[Slot], idx: int) -> Slot:
	var s: Slot = pool[idx]
	s.on = true
	s.t = 0.0
	_wake()
	return s


func _start(s: Slot, life: float) -> void:
	s.life = maxf(life, 0.001)
	s.t = 0.0


func _aim(pool: Array[CPUParticles2D], idx: int, pos: Vector2, dir: Vector2) -> CPUParticles2D:
	var p := pool[idx]
	p.global_position = pos
	if dir != Vector2.ZERO:
		p.direction = dir
	return p


func _wake() -> void:
	if not is_processing():
		set_process(true)


func _process(delta: float) -> void:
	var busy := false

	for s in _flash:
		if s.on:
			busy = true
			_step_flash(s, delta)
	for s in _pop:
		if s.on:
			busy = true
			_step_pop(s, delta)
	for s in _poof:
		if s.on:
			busy = true
			_step_poof(s, delta)
	for s in _ko_star:
		if s.on:
			busy = true
			_step_ko_star(s, delta)
	for s in _zone:
		if s.on:
			busy = true
			_step_zone(s, delta)
	for s in _wave:
		if s.on:
			busy = true
			_step_wave(s, delta)
	for s in _boom:
		if s.on:
			busy = true
			_step_boom(s, delta)
	for s in _scorch:
		if s.on:
			busy = true
			_step_scorch(s, delta)
	for s in _plus:
		if s.on:
			busy = true
			_step_plus(s, delta)
	for s in _dmg:
		if s.on:
			busy = true
			_step_dmg(s, delta)
	for s in _tracer:
		if s.on:
			busy = true
			_step_tracer(s, delta)
	for s in _shell:
		if s.on:
			busy = true
			_step_shell(s, delta)
	for s in _mark:
		if s.on:
			busy = true
			_step_mark(s, delta)
	for s in _heat:
		if s.on:
			busy = true
			_step_heat(s, delta)
	for s in _blast_flash:
		if s.on:
			busy = true
			_step_blast_flash(s, delta)
	for s in _blast_light:
		if s.on:
			busy = true
			_step_blast_light(s, delta)
	for s in _kill:
		if s.on:
			busy = true
			_step_kill(s, delta)

	if _shake > 0.01:
		busy = true
		_step_shake(delta)

	if not busy:
		set_process(false)


func _finish(s: Slot) -> void:
	s.on = false
	s.node.visible = false
	if s.lamp != null:
		_lamp_off(s)


func _step_flash(s: Slot, delta: float) -> void:
	s.t += delta
	var u := s.t / s.life
	if u >= 1.0:
		_finish(s)
		return
	# شعله فوری کامل ظاهر می‌شود (اوج نزدیک شروع) و بعد کمی جمع و محو می‌شود.
	# مدولیت سفید می‌ماند تا گرادیانِ رنگیِ خودِ ستاره‌ها (vertex_colors) دست
	# نخورد — رنگ‌آمیزی این‌جا انجام نمی‌شود، فقط شفافیت و کمی جمع‌شدگی.
	var grow: float = 1.0 if u < 0.25 else 1.0 - ((u - 0.25) / 0.75) * 0.4
	var k: float = s.f * grow
	s.node.scale = Vector2(k, k)
	s.node.modulate = Color(1.0, 1.0, 1.0, 1.0 - u * u)

	# نورِ لوله جدا از modulate خاموش می‌شود — روشناییِ Light2D به modulateِ
	# والد کاری ندارد، پس باید دستی پایین بیاید. افتِ توان‌سه‌ای یعنی یک
	# «تق»ِ کوتاه نور، نه یک چراغِ روشن‌مانده.
	if s.lamp != null and s.lamp.visible:
		var fade := 1.0 - u
		s.lamp.energy = MUZZLE_LIGHT_ENERGY * fade * fade * fade


func _step_pop(s: Slot, delta: float) -> void:
	s.t += delta
	var u := s.t / s.life
	if u >= 1.0:
		_finish(s)
		return
	# برخلاف فلش شلیک که فوری کامل می‌شود، پاو کمی «باز می‌شود» بعد جمع می‌شود
	var grow: float = (0.55 + 0.45 * (u / 0.25)) if u < 0.25 else 1.0 - ((u - 0.25) / 0.75) * 0.2
	var k: float = s.f * grow
	s.node.scale = Vector2(k, k)
	s.node.modulate = Color(1.0, 1.0, 1.0, 1.0 - u * u)


## ابرِ ناک‌اوت. هر پف: پاپِ کشسان از ریز به اندازه‌ی کامل، پرتاب به بیرون
## با ترمزِ ease-out، چرخشِ آرام، و در نیمه‌ی دوم «خورده شدن» با نویزِ شیدر.
## میزانِ خوردگی از راهِ modulate.a به شیدر می‌رسد (توضیحش در toon_puff).
func _step_poof(s: Slot, delta: float) -> void:
	s.t += delta
	var u := s.t / s.life
	if u >= 1.0:
		_finish(s)
		return
	var ps := s as PoofSlot
	var k := s.f
	var pop := _ease_out_back(minf(s.t / KO_POP_TIME, 1.0))
	var spread: float = 1.0 - pow(1.0 - minf(s.t / KO_SPREAD_TIME, 1.0), 3.0)
	var rise := Vector2(0.0, -KO_RISE * k * u)
	for i in KO_PUFFS:
		var r: float = ps.rad[i] * k * (0.3 + 0.7 * pop) * (1.0 + 0.12 * u)
		var sc := r * 2.0 / float(QUAD_TEX_SIZE)
		var at := ps.dir[i] * ps.dist[i] * k * spread + rise
		var e: float = clampf((u - ps.delay[i]) / (1.0 - ps.delay[i]), 0.0, 1.0)
		e = pow(e, 0.8)                      # خوردن زود شروع شود و یکنواخت پیش برود
		var data := Color(ps.noise_seed[i], 1.0, 1.0, 1.0 - e)
		var rot := ps.spin[i] * s.t

		var fill := ps.fills[i]
		fill.position = at
		fill.rotation = rot
		fill.scale = Vector2(sc, sc)
		fill.modulate = data

		var line := ps.lines[i]
		line.position = at
		line.rotation = rot
		line.scale = Vector2(sc, sc) * KO_OUTLINE
		line.modulate = data


## ستاره‌ی ناک‌اوت: پاپ، پرتابِ قوس‌دار با جاذبه، چرخش و محو شدن در آخر.
func _step_ko_star(s: Slot, delta: float) -> void:
	s.t += delta
	if s.t < 0.0:
		return                                   # هنوز نوبتِ این ستاره نشده
	var u := s.t / s.life
	if u >= 1.0:
		_finish(s)
		return
	s.node.visible = true
	s.a.y += KO_STAR_GRAVITY * delta
	s.a *= 1.0 - 1.2 * delta                     # اصطکاکِ هوا
	s.b += s.a * delta
	s.node.global_position = s.b
	s.node.rotation += s.g * delta
	var k: float = s.f * _ease_out_back(minf(s.t / 0.14, 1.0)) * (1.0 - 0.35 * u)
	s.node.scale = Vector2(k, k)
	s.node.modulate.a = 1.0 - maxf(u - 0.6, 0.0) / 0.4


## نشانگر محدوده: تا لحظه‌ی انفجار progress را بالا می‌برد، بعد سریع محو می‌شود.
func _step_zone(s: Slot, delta: float) -> void:
	s.t += delta
	var mat := (s.node as Sprite2D).material as ShaderMaterial
	if s.g < 0.5:
		# فاز شمارش معکوس
		var u: float = clampf(s.t / s.life, 0.0, 1.0)
		mat.set_shader_parameter("progress", u)
		if u >= 1.0:
			s.g = 1.0                  # از حالا وارد فاز محو شدن می‌شویم
			s.t = 0.0
			s.life = ZONE_FADE
		return
	# فاز محو شدن (بعد از انفجار)
	var f: float = 1.0 - clampf(s.t / s.life, 0.0, 1.0)
	mat.set_shader_parameter("fade", f)
	if f <= 0.0:
		_finish(s)


func _step_wave(s: Slot, delta: float) -> void:
	s.t += delta
	# زمانِ منفی یعنی این حلقه عمداً با تاخیر راه می‌افتد (حلقه‌ی دومِ
	# نفرینِ شیطان). تا نوبتش نرسیده نباید کشیده شود.
	if s.t < 0.0:
		s.node.visible = false
		return
	s.node.visible = true
	var u := s.t / s.life
	if u >= 1.0:
		_finish(s)
		return
	var mat := (s.node as Sprite2D).material as ShaderMaterial
	# سریع باز می‌شود و آخرش کند — حس «موج ضربه»
	var ease_out := 1.0 - pow(1.0 - u, 2.4)
	mat.set_shader_parameter("radius", s.f * ease_out)
	mat.set_shader_parameter("thickness", maxf(0.13 * (1.0 - u * 0.85), 0.008))
	mat.set_shader_parameter("fade", 1.0 - u * u)


func _step_boom(s: Slot, delta: float) -> void:
	s.t += delta
	var u := s.t / s.life
	if u >= 1.0:
		_finish(s)
		return
	# گلوله‌ی آتش باز می‌شود و بعد فرو می‌نشیند
	var grow: float = (0.45 + 0.55 * (u / 0.2)) if u < 0.2 else 1.0 - ((u - 0.2) / 0.8) * 0.25
	var k: float = s.f * grow
	s.node.scale = Vector2(k, k)
	s.node.modulate = Color(1.0, 1.0, 1.0, 1.0 - u * u)


## اخطارِ نفرین: حلقه در طولِ فیوز به مرکز فرو می‌ریزد، و لحظه‌ی انفجار
## یک تکانِ کوتاه می‌خورد و محو می‌شود.
##
## همان دو-فازیِ _step_zone، ولی محوشدنش هم‌زمان با بزرگ شدنِ ناگهانی است:
## نشانگر با انفجار «پاره» می‌شود، نه اینکه آرام کم‌رنگ شود.
func _step_mark(s: Slot, delta: float) -> void:
	s.t += delta
	var n := s.node as Sprite2D
	var mat := n.material as ShaderMaterial
	if s.g < 0.5:
		var u: float = clampf(s.t / s.life, 0.0, 1.0)
		mat.set_shader_parameter("progress", u)
		# چند صدمِ آخر، کلِ نشانگر کمی جمع می‌شود — مثل نفسی که حبس می‌شود
		var squeeze: float = 1.0 - 0.06 * pow(u, 8.0)
		n.scale = Vector2(s.f * squeeze, s.f * squeeze)
		if u >= 1.0:
			s.g = 1.0
			s.t = 0.0
			s.life = ZONE_FADE
		return
	# فاز پاره شدن: با انفجار باز می‌شود و هم‌زمان محو
	var f: float = 1.0 - clampf(s.t / s.life, 0.0, 1.0)
	mat.set_shader_parameter("fade", f)
	var burst: float = s.f * (1.0 + (1.0 - f) * 0.35)
	n.scale = Vector2(burst, burst)
	if f <= 0.0:
		n.scale = Vector2(s.f, s.f)
		_finish(s)


## موجِ گرما: مثل حلقه‌ی ضربه باز می‌شود، ولی شدتِ کج کردنِ تصویر سریع‌تر
## از خودش می‌خوابد — وگرنه لبه‌ی موج تا آخر تصویر را می‌کشد و مصنوعی می‌شود.
func _step_heat(s: Slot, delta: float) -> void:
	s.t += delta
	if s.t < 0.0:
		s.node.visible = false
		return
	s.node.visible = true
	var u := s.t / s.life
	if u >= 1.0:
		_finish(s)
		return
	var mat := (s.node as Sprite2D).material as ShaderMaterial
	var ease_out := 1.0 - pow(1.0 - u, 2.2)
	mat.set_shader_parameter("radius", s.f * ease_out)
	mat.set_shader_parameter("thickness", maxf(0.17 * (1.0 - u * 0.8), 0.01))
	var damp := (1.0 - u) * (1.0 - u) * (1.0 - u)
	mat.set_shader_parameter("strength", 0.048 * damp)
	mat.set_shader_parameter("glow", 0.6 * damp)


## ترکشِ سفیدِ اولِ انفجار: در یک چشم‌برهم‌زدن باز می‌شود و می‌رود.
func _step_blast_flash(s: Slot, delta: float) -> void:
	s.t += delta
	var u := s.t / s.life
	if u >= 1.0:
		_finish(s)
		return
	# اوج در ۱۵٪ اولِ عمر، بعد افتِ تند — همان «تق»ِ نور
	var grow: float = (0.35 + 0.85 * (u / 0.15)) if u < 0.15 else 1.2 + (u - 0.15) * 0.5
	var k: float = s.f * grow
	s.node.scale = Vector2(k, k)
	var a: float = 1.0 - pow(u, 0.65)
	s.node.modulate = Color(1, 1, 1, a)
	# مغزِ سفید زودتر از هاله‌ی پهن خاموش می‌شود
	if s.hot != null:
		s.hot.modulate = Color(1.0, 0.97, 0.90, maxf(1.0 - u * 3.0, 0.0))


## نورِ انفجار. افتِ توان‌چهارم: خیلی تند خاموش می‌شود، وگرنه شبیه چراغی
## می‌شود که یک نفر وسطِ زمین روشن گذاشته.
func _step_blast_light(s: Slot, delta: float) -> void:
	s.t += delta
	var u := s.t / s.life
	if u >= 1.0:
		var off := s.node as PointLight2D
		off.energy = 0.0
		_finish(s)
		return
	var lamp := s.node as PointLight2D
	var f := 1.0 - u
	lamp.energy = BLAST_LIGHT_ENERGY * f * f * f * f


func _step_scorch(s: Slot, delta: float) -> void:
	s.t += delta
	if s.t >= s.life:
		_finish(s)
		return
	var left := s.life - s.t
	if left < SCORCH_FADE:
		s.node.modulate.a = left / SCORCH_FADE


func _step_plus(s: Slot, delta: float) -> void:
	s.t += delta
	if s.t < 0.0:
		return                                   # هنوز نوبتِ این + نشده
	var u := s.t / s.life
	if u >= 1.0:
		_finish(s)
		return
	s.node.visible = true

	# بالا رفتن با کمی موجِ افقی، و کند شدنِ تدریجی
	s.a.y += 55.0 * delta
	s.b += s.a * delta
	s.b.x += sin(s.t * 6.0 + s.g * 3.0) * 22.0 * delta
	s.node.global_position = s.b
	s.node.rotation += s.g * delta * 0.35

	# پاپِ سریعِ اول، بعد محو شدن در نیمه‌ی دوم
	var pop: float = minf(u / 0.16, 1.0)
	var k: float = s.f * pop * (1.0 + 0.18 * u)
	s.node.scale = Vector2(k, k)
	s.node.modulate.a = 1.0 - maxf(u - 0.45, 0.0) / 0.55


func _step_dmg(s: Slot, delta: float) -> void:
	s.t += delta
	var u := s.t / s.life
	if u >= 1.0:
		_finish(s)
		return
	s.a.y += 130.0 * delta                       # کم‌کم از سرعتش کم می‌شود
	s.b += s.a * delta
	s.node.global_position = s.b
	# پاپِ کشدار: کمی بزرگ‌تر از اندازه می‌رود و برمی‌گردد
	var pop: float = 1.0 if u > 0.18 else (u / 0.18)
	var k: float = s.f * (pop * 1.25 - 0.25 * minf(u / 0.18, 1.0))
	s.node.scale = Vector2(k, k)
	s.node.modulate.a = 1.0 - maxf(u - 0.5, 0.0) / 0.5


func _step_tracer(s: Slot, delta: float) -> void:
	s.t += delta
	var u := s.t / s.life
	var dir := (s.b - s.a) / s.f if s.f > 0.001 else Vector2.RIGHT
	var travelled: float = minf(TRACER_SPEED * s.t, s.f)

	# گلوله رسید — همین‌جا برخورد را بزن (فقط یک بار).
	# این چک باید *قبل* از پایان اسلات باشد: اگر یک فریم سنگین شود و کل
	# عمر رد گلوله را یک‌جا رد کند، برخورد نباید از قلم بیفتد.
	if s.g > 0.0 and travelled >= s.f:
		impact(s.b, -dir, s.g >= 2.0)
		s.g = 0.0

	if u >= 1.0:
		_finish(s)
		return

	var n := s.node
	var head := s.a + dir * travelled
	var tail := s.a + dir * maxf(travelled - TRACER_SEG, 0.0)

	var bolt := n.get_node("Bolt") as Line2D
	bolt.set_point_position(0, tail)
	bolt.set_point_position(1, head)

	# رد کم‌رنگ خیلی زودتر از خود گلوله محو می‌شود
	var trail := n.get_node("Trail") as Line2D
	var tu: float = clampf(s.t / TRAIL_LIFE, 0.0, 1.0)
	trail.width = maxf(2.5 * (1.0 - tu), 0.01)
	trail.default_color = Color(1.0, 0.80, 0.42, 0.5 * (1.0 - tu))

	n.modulate.a = 1.0 - u * u * u


func _step_shell(s: Slot, delta: float) -> void:
	s.t += delta
	var u := s.t / s.life
	if u >= 1.0:
		_finish(s)
		return
	s.a.y += 700.0 * delta          # جاذبه
	s.a *= 1.0 - 2.2 * delta        # اصطکاک هوا
	s.b += s.a * delta
	s.node.global_position = s.b
	s.node.rotation += s.f * delta
	s.node.modulate.a = 1.0 - maxf(u - 0.6, 0.0) / 0.4


func _step_kill(s: Slot, delta: float) -> void:
	s.t += delta
	var u := s.t / s.life
	if u >= 1.0:
		_finish(s)
		return
	var n := s.node
	# حلقه در ثلثِ اول باز می‌شود و محو می‌شود
	var ru: float = clampf(u / 0.4, 0.0, 1.0)
	var ring := n.get_node("Ring") as Line2D
	var rk: float = s.f * (0.35 + 1.25 * (1.0 - pow(1.0 - ru, 3.0)))
	ring.scale = Vector2(rk, rk)
	ring.width = 5.0 * s.f / maxf(rk, 0.01)
	ring.modulate.a = 1.0 - ru
	# ستاره فقط یک چشمک است
	var su: float = clampf(u / 0.22, 0.0, 1.0)
	var star := n.get_node("Star") as Polygon2D
	var sk: float = s.f * (0.4 + 0.9 * su)
	star.scale = Vector2(sk, sk)
	star.rotation = su * 0.6
	star.modulate.a = 1.0 - su
	# سکه می‌پرد بالا، کمی می‌ماند و محو می‌شود
	var coin := n.get_node("Coin") as Node2D
	if coin.visible:
		var cu: float = minf(u / 0.25, 1.0)
		coin.position = Vector2(0.0, -26.0 - 34.0 * (1.0 - pow(1.0 - cu, 2.0)) - 10.0 * u)
		var pop: float = _ease_out_back(cu)
		coin.modulate.a = 1.0 - maxf(u - 0.65, 0.0) / 0.35
		var base: float = float(coin.get_meta("base_scale", 1.0))
		coin.scale = Vector2(base, base) * maxf(pop, 0.01)


func _step_shake(delta: float) -> void:
	if _cam == null or not is_instance_valid(_cam):
		_cam = get_viewport().get_camera_2d()
		if _cam == null:
			_shake = 0.0
			return
	_shake = maxf(_shake - _shake_decay * _shake * delta - 6.0 * delta, 0.0)
	if _shake <= 0.01:
		_cam.offset = Vector2.ZERO
		_cam = null
		return
	_cam.offset = Vector2(_rng.randf_range(-_shake, _shake), _rng.randf_range(-_shake, _shake))
