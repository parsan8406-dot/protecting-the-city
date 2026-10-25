extends CharacterBody2D

## شمارِ فشنگ عوض شد — کارتِ پروفایل و پلاکِ بالای سر به این وصل‌اند
signal ammo_changed(current: int, maximum: int, reloading: bool)

## سرعتِ پایه. سرور بعد از join سرعتِ واقعیِ کاراکتر را می‌فرستد و
## world.gd آن را در move_speed می‌گذارد (balance.go → CharacterStats).
const SPEED = 200.0
var move_speed := SPEED
## ضریبِ دکمه‌ی دویدن (۱.۲ تا وقتی فعال است). سرور هم در همان مدت سقفِ
## سرعت را همین‌قدر بالا می‌برد، پس حرکتِ تند اصلاحِ موقعیت نمی‌خورد.
var speed_mult := 1.0

## فاصله‌ی دهانه‌ی اسلحه از مرکز بازیکن (در مختصات جهانی).
const MUZZLE_OFFSET := 50.0

## فاصله‌ی زمانی بین دو شلیک — از world.gd روی تراز کاراکتر ست می‌شود
## (hand_speed → balance.go → CharStats.FireCooldown). ۰.۳ فقط پیش‌فرض
## است تا سرور نرسیده بازی خراب نشود.
var fire_cooldown := 0.3

## احتمال این‌که شلیک با وجودِ دیدِ باز خطا برود — از world.gd روی تراز
## کاراکتر ست می‌شود (aim_accuracy → balance.go → CharStats.MissChance).
var miss_chance := 0.0

## سرعتِ چرخش (درجه بر ثانیه) — hand_speed: «نسبت چرخش و راحتیِ چرخش».
## چرخش دیگر آنی نیست؛ باید واقعاً به این سرعت طول بکشد. از world.gd روی
## تراز کاراکتر ست می‌شود (balance.go → CharStats.TurnRate).
var turn_rate := 400.0

## پهنای مخروطی که باید داخلش رو به هدف باشی تا شلیک ثبت شود — از سلاح
## می‌آید (balance.go → WeaponMods.FireConeDeg، از world.gd ست می‌شود).
var fire_cone_deg := 20.0

## بردِ مؤثرِ سلاح. سرور شلیکِ دورتر از این را رد می‌کند، پس قفل شدن روی
## هدفِ دور فقط فشنگ می‌سوزاند.
var max_range := 500.0

## خسارتِ هر گلوله. آنلاین سرور داوری می‌کند و این دست نمی‌خورد؛ آفلاین
## (بازی سریع) خودِ کلاینت با همین عدد خسارت می‌زند.
var damage := 25

## خشاب. اندازه‌اش از سرور می‌آید و به سرعتِ شلیکِ همان سلاح گره خورده
## (balance.go → magazineFor): تیربارِ ثانیه‌ای ۱۰ تیر خشابِ بزرگ‌تری دارد،
## وگرنه رگبارش یک ثانیه‌ونیم بیشتر دوام نمی‌آورد.
var max_ammo = 12
var current_ammo = 12
## پر شدنِ خودکارِ خشابِ خالی (ثانیه). سرور می‌فرستدش؛ جعبه‌ی فشنگِ روی
## زمین همچنان فوری پرش می‌کند.
var reload_seconds := 1.6
var _reload_left := 0.0
var health = 100
var is_dead = false
var last_sent_pos = Vector2.ZERO
var last_sent_rot = 0.0

@onready var sight_ray = $SightRay
@onready var joystick = $"../UI/VirtualJoystick"
@onready var shoot_sound = $ShootSound
@onready var reload_sound = $ReloadAmmo
@onready var anim: AnimationPlayer = get_node_or_null("AnimationPlayer")
@export var bullet_icon: Texture2D

var enemies_in_range: Array[Node2D] = []

## هدفی که همین حالا رویش قفل شده‌ایم.
##
## چرا قفل: قبلاً هر فریم «اولین هدفِ قابلِ‌قبولِ لیست» انتخاب می‌شد و بدن
## هم فقط به سمتِ جهتِ حرکت می‌چرخید. نتیجه این بود که با حرکت کردن، هدف
## از مخروطِ شلیک بیرون می‌افتاد و رگبار قطع می‌شد — بازیکن باید اسلحه را
## دوباره روی حریف می‌آورد. حالا تا وقتی این هدف معتبر است، بدن رو به او
## می‌ماند و شلیک پشتِ‌سرِ‌هم ادامه دارد.
var _locked_target: Node2D = null

## شمارنده‌ی شلیک. قبلاً با await/Timer بود که برای هر شلیک یک Timer و یک
## coroutine می‌ساخت؛ حالا فقط یک float است.
var _shot_cooldown := 0.0

# 🌟 وقتی سرور موقعیت را اصلاح می‌کند، چند فریم چیزی نفرست تا رفت‌وبرگشت نشود
var _correction_cooldown := 0.0

## بسته‌ی move حداکثر هر ۵۰ میلی‌ثانیه (۲۰ هرتز) — _send_move_if_needed
const MOVE_SEND_INTERVAL := 0.05
var _send_accum := 0.0
var _was_moving := false

## آخرین ضربه‌ای که به سرور فرستادیم — world.gd از رویش «کشته‌ی خودم» را
## حدس می‌زند (پیامِ die قاتل ندارد) تا لرزشِ کشتن بدهد
var last_hit_target := ""
var last_hit_ms := 0

## تویینِ محو شدنِ مرگ. موقعِ زنده شدن باید کشته شود، وگرنه callbackِ hide
## بعد از برگشت اجرا می‌شود و بازیکن نامرئی می‌ماند.
var _death_tween: Tween = null

## هر چند وقت لیستِ هدف‌ها از نو از روی دایره‌ی دید ساخته شود.
##
## چرا لازم است: لیست فقط با سیگنالِ body_entered پر می‌شد. حریفی که همین
## حالا داخلِ دایره ایستاده دیگر «وارد» نمی‌شود، پس اگر لیست یک بار خالی
## شود (مرگ، ریسپاون، یا نودی که سرور از نو ساخته) هیچ‌وقت پر نمی‌شد و
## بازیکن تا آخرِ راند شلیک نمی‌کرد.
const TARGET_RESCAN := 0.4
var _rescan_in := 0.0

func _ready():
	# سرور حرف آخر را می‌زند: اگر حرکتی از دیوار رد شود یا سرعتش غیرمجاز باشد،
	# سرور موقعیت درست را می‌فرستد و ما بی‌چون‌وچرا همان‌جا می‌پریم.
	if not Network.position_corrected.is_connected(_on_position_corrected):
		Network.position_corrected.connect(_on_position_corrected)

	_sync_ammo_hud()

## شمارِ فشنگ را خبر می‌دهد. world.gd سیگنال را به کارتِ پروفایل و پلاکِ
## بالای سر وصل می‌کند، پس این‌جا لازم نیست بداند HUD کجاست.
func _sync_ammo_hud() -> void:
	ammo_changed.emit(int(current_ammo), int(max_ammo), _reload_left > 0.0)


func _on_position_corrected(pos: Vector2):
	global_position = pos
	last_sent_pos = pos
	velocity = Vector2.ZERO
	_correction_cooldown = 0.15


func _physics_process(delta):
	if is_dead: return

	if _correction_cooldown > 0.0:
		_correction_cooldown -= delta
	if _shot_cooldown > 0.0:
		_shot_cooldown -= delta

	_rescan_in -= delta
	if _rescan_in <= 0.0:
		_rescan_in = TARGET_RESCAN
		refresh_targets()

	var move_direction = joystick.joystick_vector
	var desired_rot := rotation
	velocity = move_direction * move_speed * speed_mult if move_direction != Vector2.ZERO else Vector2.ZERO

	# 🌟 هدف مقدم بر جهتِ حرکت است: تا وقتی حریفی قفل است، بدن رو به او
	# می‌ماند و پاها هرجا که جوی‌استیک می‌گوید می‌روند. این همان چیزی است
	# که «بگیر روی حریف و پشتِ‌سرِ‌هم بزن» را ممکن می‌کند؛ قبلاً چرخش
	# دنبالِ جهتِ حرکت بود و هدف مدام از مخروطِ شلیک بیرون می‌افتاد.
	_update_lock()
	if _locked_target != null:
		desired_rot = (_locked_target.global_position - global_position).angle() + deg_to_rad(90)
	elif move_direction != Vector2.ZERO:
		desired_rot = move_direction.angle() + deg_to_rad(90)

	# 🌟 چرخش دیگر آنی نیست: با سرعتِ hand_speed به سمتِ جهتِ مطلوب می‌رود.
	rotation = _turn_toward(rotation, desired_rot, deg_to_rad(turn_rate) * delta)

	move_and_slide()
	update_body_anim()

	_send_move_if_needed(delta)

	# خشابِ خالی خودش پر می‌شود، وگرنه اولین رگبار آخرین رگبار بود
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			current_ammo = max_ammo
			_sync_ammo_hud()
			if reload_sound != null:
				reload_sound.play()
	elif current_ammo <= 0:
		_reload_left = reload_seconds
		_sync_ammo_hud()   # «در حال پر کردن» روی کارت
		play_reload_anim()

	# 🌟 شلیک پشتِ‌سرِ‌هم: تا وقتی هدف قفل است و کول‌داونِ سلاح تمام شده،
	# هر فریم دوباره امتحان می‌شود. سرعتش را فقط fire_cooldown تعیین می‌کند
	# (سرور از روی تراز سلاح می‌فرستدش)، پس تیربار واقعاً رگبار می‌ریزد.
	if _shot_cooldown <= 0.0 and _locked_target != null:
		shoot()

## موقعیت و چرخش را با سقفِ ۲۰ بار در ثانیه به سرور می‌فرستد.
##
## چرا: قبلاً هر تیکِ فیزیک (۶۰ بار در ثانیه) یک بسته می‌رفت — روی اینترنتِ
## موبایل سه برابرِ لازم ترافیک و باتری. سرور فاصله‌ی زمانیِ دو بسته را
## خودش می‌سنجد (سقفِ سرعت و چرخش با dt)، پس بسته‌ی کم‌تر هیچ اصلاحی
## نمی‌خورد و ریموت‌ها هم هموارش می‌کنند.
##
## دو استثنا بی‌درنگ می‌روند/حتماً می‌روند:
##   - لحظه‌ی ایستادن: وگرنه بقیه تا ۵۰ میلی‌ثانیه بازیکن را جلوتر می‌بینند
##   - آخرین چرخش: قبلاً فقط تغییرِ بیش از ۰.۱ رادیان فرستاده می‌شد، پس
##     وقتی چرخش آرام به هدف می‌نشست، زاویه‌ی سرور کهنه می‌ماند و مخروطِ
##     شلیکِ سرور ضربه‌ی درست را رد می‌کرد. حالا هر اختلافی، دیر یا زود
##     (حداکثر یک بازه‌ی ۵۰ میلی‌ثانیه‌ای) فرستاده می‌شود.
func _send_move_if_needed(delta: float) -> void:
	_send_accum = minf(_send_accum + delta, MOVE_SEND_INTERVAL)
	var moving := velocity != Vector2.ZERO
	var just_stopped := _was_moving and not moving
	_was_moving = moving

	if _correction_cooldown > 0.0 or not Network.is_connected:
		return

	var moved := global_position.distance_to(last_sent_pos)
	# لحظه‌ی ایستادن هر جابه‌جاییِ کوچکی هم مهم است: جای نهایی باید دقیق باشد
	var pos_changed := moved > (0.05 if not moving else 1.0)
	var rot_changed := absf(wrapf(rotation - last_sent_rot, -PI, PI)) > 0.005
	if not (pos_changed or rot_changed):
		return
	# کمی کم‌تر از ۵۰ms تا جمعِ سه تیکِ ۱/۶۰ (۰.۰۴۹۹۹…) بسته را یک تیک عقب نیندازد
	if _send_accum < MOVE_SEND_INTERVAL - 0.001 and not just_stopped:
		return

	Network.send_move_data(global_position, rotation)
	last_sent_pos = global_position
	last_sent_rot = rotation
	_send_accum = 0.0


## طولِ خودِ انیمیشنِ reload (باید با tools/build_player_anims.gd یکی بماند).
## هر سلاحی reload_seconds خودش را دارد، پس انیمیشن با custom_speed کِش
## می‌آید یا جمع می‌شود تا دقیقاً وقتی تمام شود که خشاب پر شده.
const RELOAD_ANIM_LEN := 1.6

# 🌟 انیمیشن بدنه: بین idle / walk / run سوییچ می‌کند و اجازه می‌دهد
# shoot و reload موقتاً رویشان بیایند.
func update_body_anim():
	if anim == null or is_dead:
		return
	# این دوتا تا آخر نشان داده می‌شوند و راه رفتن قطعشان نمی‌کند
	if anim.current_animation == "shoot" or anim.current_animation == "reload":
		return
	var want := "idle"
	if velocity.length() > 5.0:
		# دویدن (اسپرینت) قدم‌های درشت‌تر و تندتری دارد تا از راه رفتن جدا باشد
		want = "run" if speed_mult > 1.05 else "walk"
	if anim.current_animation != want:
		anim.play(want, 0.2)

func play_shoot_anim():
	if anim != null and not is_dead:
		anim.play("shoot")

## انیمیشنِ تعویضِ خشاب، کِش‌آمده به اندازه‌ی reload_secondsِ همین سلاح
func play_reload_anim():
	if anim == null or is_dead or not anim.has_animation("reload"):
		return
	var speed := RELOAD_ANIM_LEN / maxf(reload_seconds, 0.15)
	anim.play("reload", 0.15, speed)

func shoot():
	if current_ammo <= 0 or is_dead or _reload_left > 0.0:
		return

	var target := _locked_target
	if target == null or not is_instance_valid(target):
		return
	# زیرِ گنبدِ تولد: سرور تا آخرِ محافظ هیچ ضربه‌ای را قبول نمی‌کند، پس
	# شلیک کردن فقط فشنگ و کول‌داون می‌سوزاند
	if _is_shielded(target):
		return

	# دیوار وسط نباشد
	sight_ray.target_position = sight_ray.to_local(target.global_position)
	sight_ray.force_raycast_update()
	if not sight_ray.is_colliding() or sight_ray.get_collider() != target:
		return

	# 🌟 سرعتِ دست (hand_speed) + مخروطِ سلاح (control): تا وقتی چرخش
	# واقعاً به سمتِ هدف نرسیده شلیک نمی‌گیرد — نه تیر و نه cooldown
	# مصرف می‌شود، همین فریم‌های بعد که چرخش رسید امتحان می‌شود.
	var to_target := (target.global_position - global_position).angle() + deg_to_rad(90)
	var facing_off := absf(wrapf(to_target - rotation, -PI, PI))
	if facing_off > deg_to_rad(fire_cone_deg):
		return

	# هدف تایید شد
	# باقی‌مانده‌ی منفیِ کول‌داون (تا یک فریم) دور ریخته نمی‌شود، وگرنه هر
	# شلیک به فریمِ بعدی گرد می‌شد و سلاحِ تند ۷ تا ۱۰٪ کندتر از عددش می‌زد.
	# سقفِ ۱۰٪ دو کار می‌کند: شلیک انبار نمی‌شود، و فاصله‌ی دو شلیک هیچ‌وقت
	# از ۰.۹ fire_cooldown کم‌تر نمی‌شود (سرور ضربه‌ی زیرِ ۰.۸۵ را رد می‌کند).
	_shot_cooldown = clampf(_shot_cooldown, -fire_cooldown * 0.1, 0.0) + fire_cooldown
	current_ammo -= 1
	_sync_ammo_hud()

	# 🌟 دقتِ کاراکتر: حتی با دیدِ کاملاً باز، ممکن است شلیک خطا برود.
	# آماری است، نه فیزیکی (چون سیستم auto-lock است نه نشانه‌روی دستی).
	# آنلاین تاس فقط سمتِ سرور ریخته می‌شود؛ قبلاً هر دو طرف جدا تاس
	# می‌ریختند و خطای واقعی تقریباً دو برابرِ عددِ کاراکتر می‌شد (۱−(۱−p)²).
	var missed := Global.offline_mode and randf() < miss_chance

	# 🌟 افکت شلیک: hitscan است، پس نه نود تیر ساخته می‌شود نه فیزیک اضافه
	var shoot_dir := Vector2.RIGHT.rotated(rotation - deg_to_rad(90))
	var muzzle := global_position + shoot_dir * MUZZLE_OFFSET
	CombatFX.shoot(muzzle, shoot_dir, sight_ray.get_collision_point(), true, true, not missed)
	shoot_sound.play()
	play_shoot_anim()

	Network.send_shoot_data(global_position, rotation)
	# آفلاین سپرِ دستی با شلیکِ خودت می‌شکند (آنلاین سرور همین را اعمال می‌کند)
	var scene := get_parent()
	if scene != null and scene.has_method("on_local_attack"):
		scene.on_local_attack()
	if not missed:
		if Global.offline_mode:
			# آفلاین: داورِ خسارت خودِ کلاینت است
			if target.has_method("take_damage"):
				target.take_damage(damage)
		else:
			last_hit_target = username_of(target)
			last_hit_ms = Time.get_ticks_msec()
			Network.send_hit_data(last_hit_target)


## قفلِ هدف را تازه می‌کند: تا وقتی هدفِ فعلی معتبر است همان می‌ماند،
## وگرنه نزدیک‌ترین هدفِ معتبرِ تازه قفل می‌شود.
##
## «معتبر» یعنی زنده، حریف، داخلِ دایره‌ی دید و داخلِ بردِ سلاح.
##
## استثنا: شیطانِ «عملیات حذف شیطان» هدفِ درجه‌دوم است. او هم در گروهِ
## enemy است و بدنه‌اش بزرگ، پس به‌راحتی نزدیک‌ترین هدف می‌شود — و بدونِ
## این استثنا، بازیکنی که کنارِ شیطان درگیرِ حریف است ناگهان می‌دید که
## تفنگش به شیطان قفل شده و حریف داشت آزادانه او را می‌زد.
func _update_lock() -> void:
	if _is_lockable(_locked_target):
		if not _is_demon(_locked_target):
			return
		# روی شیطان قفلیم؛ اگر حریفِ واقعی‌ای پیدا شد، او مقدم است
		var foe := _nearest_target(true)
		if foe != null:
			_locked_target = foe
		return
	_locked_target = _nearest_target()


## شیطانِ وسطِ زمین است؟ (scripts/demon.gd خودش را در این گروه می‌گذارد)
func _is_demon(node) -> bool:
	return node != null and is_instance_valid(node) and node.is_in_group("demon")


func _is_lockable(node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if _is_teammate(node) or not enemies_in_range.has(node):
		return false
	if "health" in node and int(node.health) <= 0:
		return false
	return global_position.distance_to(node.global_position) <= max_range


## نزدیک‌ترین هدفِ معتبر در enemies_in_range — برای چرخیدنِ به سمتش وقتی
## ایستاده‌ای (بدون این‌که به دیدِ باز نیاز باشد؛ همین که بدانی کجاست کافی
## است تا شروع به چرخیدن کنی).
##
## بازیکن‌ها همیشه مقدم بر شیطان‌اند: شیطان جایی نمی‌رود و هر وقت فرصت شد
## می‌شود زدش، ولی حریفی که روبه‌رویت است همین حالا دارد می‌زند.
## players_only = true یعنی اصلاً شیطان را حساب نکن.
func _nearest_target(players_only := false) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	var demon: Node2D = null
	var demon_d := INF
	for e in enemies_in_range:
		if not _is_lockable(e) or _is_shielded(e):
			continue
		var d := global_position.distance_squared_to(e.global_position)
		if _is_demon(e):
			if players_only:
				continue
			if d < demon_d:
				demon_d = d
				demon = e
			continue
		if d < best_d:
			best_d = d
			best = e
	return best if best != null else demon


## چرخشِ رفته‌رفته به سمتِ زاویه‌ی مطلوب، حداکثر به‌اندازه‌ی max_delta در
## این فریم — همان چیزی که hand_speed کنترلش می‌کند.
func _turn_toward(current: float, target: float, max_delta: float) -> float:
	var diff := wrapf(target - current, -PI, PI)
	if absf(diff) <= max_delta:
		return target
	return current + sign(diff) * max_delta


## نودهای آزادشده را از لیست بیرون می‌اندازد.
## در جا انجام می‌شود؛ قبلاً هر فریم یک آرایه‌ی تازه می‌ساخت.
## هم‌تیمی است؟
##
## تیم بعد از ساخته شدنِ نود ست می‌شود (اولین update_players از سرور)، پس
## ممکن است یک هم‌تیمی قبل از آن وارد DetectionZone شده باشد و در لیست
## مانده باشد. تکیه کردن به لایه‌ی برخورد به‌تنهایی کافی نیست — این بررسی
## همان حالت را هم می‌گیرد.
func _is_teammate(node) -> bool:
	return node != null and "is_ally" in node and node.is_ally


## زیرِ گنبدِ محافظِ تولد است؟ (عملیات انتقام — پنج ثانیه‌ی اولِ هر تولد)
##
## مرجع سرور است؛ این فقط جلوی شلیکِ بی‌فایده را می‌گیرد. صحنه‌ی زمین
## (world.gd) گنبدها را نگه می‌دارد چون خودش آن‌ها را از سرور می‌گیرد.
func _is_shielded(node) -> bool:
	if node == null:
		return false
	var scene := get_parent()
	if scene == null or not scene.has_method("is_protected"):
		return false
	# گنبدِ تولد یا سپرِ دستی — هر دو یعنی تیر ثبت نمی‌شود
	return scene.is_protected(username_of(node))


## نامِ کاربریِ یک نودِ حریف.
##
## عمداً از node.name استفاده نمی‌شود: اگر جنازه‌ی همان بازیکن هنوز در حالِ
## محو شدن باشد و سرور نودِ تازه‌اش را بسازد، گودوت نامِ تکراری را عوض
## می‌کند («Ali» → «Ali2»). آن‌وقت hit با نامِ اشتباه به سرور می‌رفت و
## هیچ تیری ثبت نمی‌شد — بازیکن شلیک می‌کرد و هیچ اتفاقی نمی‌افتاد.
static func username_of(node) -> String:
	if node == null:
		return ""
	if "username" in node and str(node.username) != "":
		return str(node.username)
	return str(node.name)


## لیستِ هدف‌ها را از روی چیزی می‌سازد که همین حالا داخلِ دایره‌ی دید است.
##
## این جایگزینِ تکیه‌ی صرف به body_entered است: هر بار که لیست از دست برود
## (مرگ، ریسپاون، یا نودِ حریف که سرور از نو ساخته) خودش را درست می‌کند.
func refresh_targets() -> void:
	var zone := get_node_or_null("DetectionZone") as Area2D
	if zone == null:
		return
	enemies_in_range.clear()
	for body in zone.get_overlapping_bodies():
		if body == self or not is_instance_valid(body):
			continue
		if not body.is_in_group("enemy") or _is_teammate(body):
			continue
		enemies_in_range.append(body)


func clean_enemies_list():
	for i in range(enemies_in_range.size() - 1, -1, -1):
		var e = enemies_in_range[i]
		if not is_instance_valid(e) or _is_teammate(e):
			enemies_in_range.remove_at(i)

func _on_detection_zone_body_entered(body):
	if body.is_in_group("enemy") and body != self and not _is_teammate(body):
		if not enemies_in_range.has(body):
			enemies_in_range.append(body)

func _on_detection_zone_body_exited(body):
	if body in enemies_in_range:
		enemies_in_range.erase(body)

func reload_full_ammo() -> bool:
	if current_ammo >= max_ammo or is_dead: return false
	current_ammo = max_ammo
	reload_sound.play()
	_sync_ammo_hud()
	return true

## خسارت گرفتن در بازیِ آفلاین. آنلاین هرگز صدا زده نمی‌شود، چون آنجا داورِ
## خسارت سرور است و از راه health_update می‌آید.
## کار را به صحنه واگذار می‌کند تا افکت، HUD و مرگ همه از یک مسیر رد شوند.
func take_damage(amount: int) -> void:
	if is_dead or not Global.offline_mode:
		return
	var arena := get_parent()
	if arena != null and arena.has_method("_damage_local_player"):
		arena._damage_local_player(amount)


## مرگِ بازیکنِ محلی — فقط افکتِ بصری.
##
## عمداً هیچ صفحه‌ای نشان نمی‌دهد: راند با مرگِ تو تمام نمی‌شود، تا وقتی
## هم‌تیمی زنده داری بازی ادامه دارد و تو تماشا می‌کنی. صفحه‌ی برد/باخت را
## round_hud بعد از match_over سرور می‌سازد و world.gd تماشا را می‌گرداند.
##
## قبلاً همین‌جا یک پرده‌ی سیاهِ «شما باختید!» ساخته می‌شد — به محضِ مرگ،
## قبل از اینکه راند اصلاً تمام شود.
func die():
	is_dead = true
	velocity = Vector2.ZERO
	speed_mult = 1.0
	enemies_in_range.clear()
	_locked_target = null
	CombatFX.knockout(global_position)
	CombatFX.shake(9.0, 9.0)
	# C10/E11: صدای مرگ، لرزش و کارتِ «چه کسی با چه چیزی زدت»
	if CombatFX.feel != null:
		CombatFX.feel.on_local_death()
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	# پفِ دود در KO_HIDE_TIME کامل شده؛ کاراکتر همان‌قدر سریع پشتش گم می‌شود
	_death_tween = create_tween()
	_death_tween.tween_property(self, "modulate:a", 0.0, CombatFX.KO_HIDE_TIME).set_ease(Tween.EASE_IN)
	_death_tween.tween_callback(hide)


## برگشت به بازی (عملیات انتقام). سرور جا و جان را می‌دهد؛ این‌جا فقط
## همه‌ی چیزهایی که مرگ خاموش کرده بود دوباره روشن می‌شود.
##
## سه چیزی که اگر فراموش شوند بازیکن «برمی‌گردد ولی نمی‌تواند بازی کند»:
##   ۱. تویینِ مرگ باید کشته شود، وگرنه hideِ آخرش بعد از برگشت اجرا می‌شود
##   ۲. خشاب باید پر شود — با خشابِ خالی مرده بودی، با همان هم برمی‌گشتی و
##      هیچ تیری در نمی‌رفت
##   ۳. لیستِ هدف‌ها باید از نو ساخته شود؛ حریفی که داخلِ دایره ایستاده
##      دیگر body_entered نمی‌دهد
func revive(pos: Vector2, new_health: int) -> void:
	if _death_tween != null and _death_tween.is_valid():
		_death_tween.kill()
	_death_tween = null

	is_dead = false
	health = new_health
	velocity = Vector2.ZERO
	global_position = pos
	last_sent_pos = pos
	last_sent_rot = rotation
	_correction_cooldown = 0.0
	_shot_cooldown = 0.0

	current_ammo = max_ammo
	_reload_left = 0.0
	_sync_ammo_hud()
	_locked_target = null

	modulate.a = 1.0
	show()
	set_physics_process(true)

	refresh_targets()
	_rescan_in = TARGET_RESCAN
	if anim != null:
		anim.play("idle")


func _on_return_home_pressed():
	if Network.socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		Network.socket.close()
	Network.is_connected = false
	get_tree().change_scene_to_file("res://secense/main_menu.tscn")
