extends CharacterBody2D

## فاصله‌ی دهانه‌ی اسلحه از مرکز بازیکن (همان مقدار player.gd).
const MUZZLE_OFFSET := 50.0

@onready var sprite = $Sprite2D
@onready var weapon_sprite = $gun
@onready var shoot_sound = $ShootSound
const FOE_PLATE := preload("res://scripts/foe_plate.gd")
## V6 حلقه‌ی رنگیِ زیرِ پا (قرمز حریف / آبی هم‌تیمی)
const TEAM_RING := preload("res://scripts/psych_combat_ring.gd")

## لایه‌ی برخورد: حریف روی لایه‌ی ۲ می‌ماند (همان که DetectionZone با ماسک ۲
## و رِی‌کستِ شلیک با ماسک ۳ می‌بینند). هم‌تیمی به لایه‌ی ۳ می‌رود، پس هیچ‌کدام
## از آن دو اصلاً نمی‌بینندش — نه اتوایم رویش قفل می‌شود و نه تیر جلویش
## می‌ایستد. برخوردِ بدنی‌اش با دیوار دست‌نخورده می‌ماند (آن ماسک است نه لایه).
const FOE_LAYER := 2
const ALLY_LAYER := 4

## هم‌تیمی است؟ player.gd از روی همین تصمیم می‌گیرد هدفش بگیرد یا نه.
var is_ally := false

## نامِ کاربریِ سرور. نامِ نود ممکن است عوض شود (اگر جنازه‌ی همین بازیکن
## هنوز در حالِ محو شدن باشد، گودوت نودِ تازه را «Ali2» صدا می‌زند)، ولی
## این همیشه همان چیزی است که سرور می‌شناسد — hit و گنبدِ محافظ با همین
## کار می‌کنند.
var username := ""
var _plate: Node2D = null
var _ring: Node2D = null
## V7 چشمکِ سفیدِ تیر خوردن
var _flash_tw: Tween = null
@onready var health_bar_fill = $HealthBar/Fill
@onready var health_bar_label = $HealthBar/HealthLabel
@onready var anim: AnimationPlayer = get_node_or_null("AnimationPlayer")

## جای مقصد از سرور. با هر بسته‌ی تازه سرعتِ تقریبیِ حریف هم از روی
## فاصله‌ی دو بسته تخمین زده می‌شود تا بینِ بسته‌ها (۲۰ هرتز) کمی جلوتر
## پیش‌بینی شود — وگرنه حریف پله‌پله و تند-کند حرکت می‌کرد.
var target_position := Vector2.ZERO:
	set(value):
		var now := Time.get_ticks_msec() * 0.001
		var gap := now - _last_packet_t
		var step: Vector2 = value - target_position
		# اولین بسته، وقفه‌ی طولانی یا پرش (ریسپاون/اصلاحِ سرور): پیش‌بینی نکن
		if target_position == Vector2.ZERO or gap > 0.3 or step.length() > TELEPORT_DIST:
			_net_vel = Vector2.ZERO
		else:
			var v: Vector2 = (step / maxf(gap, 0.02)).limit_length(MAX_NET_SPEED)
			# بسته‌های به‌هم‌چسبیده (لرزشِ شبکه) سرعت را یک‌باره نپرانند
			_net_vel = _net_vel.lerp(v, 0.6)
		target_position = value
		_last_packet_t = now
var target_rotation = 0.0
## سرعتِ پایه‌ی همین بازیکن (stats.speed از سرور، world.gd ست می‌کند)
var base_speed := 200.0
var _net_vel := Vector2.ZERO
var _last_packet_t := 0.0
var health = 100
var max_health = 100
var _speed := 0.0
var _prev_position = Vector2.ZERO

func _ready():
	add_to_group("enemy")
	# نوار جانِ قدیمی با بدنه می‌چرخید و کج می‌شد؛ جایش را به FoePlate داد
	# که top_level است و همیشه صاف بالای سرِ حریف می‌ایستد.
	$HealthBar.hide()
	_plate = FOE_PLATE.new()
	_plate.name = "FoePlate"
	_plate.setup(self)
	add_child(_plate)
	_ring = TEAM_RING.new()
	_ring.name = "TeamRing"
	add_child(_ring)
	move_child(_ring, 0)     # اولین فرزند = زیرِ بدن کشیده می‌شود
	_ring.set_ally(is_ally)
	update_health_bar(max_health, max_health)

func set_max_health(max_hp: int):
	max_health = max_hp
	health = max_hp
	update_health_bar(health, max_health)

func setup_appearance(character_id: String, weapon_id: String):
	CharacterSkin.apply(sprite, character_id)
	WeaponSkin.apply(weapon_sprite, weapon_id)
	_show_weapon_badge(weapon_id)


## تیمِ این بازیکن را به پلاکش می‌دهد: آبی برای هم‌تیمی، قرمز برای حریف.
## بدونِ این، همه‌ی بازیکن‌های دیگر عیناً یک‌شکل دیده می‌شوند و بازیکن
## نمی‌فهمد کنارش دوست است یا دشمن.
func set_team(ally: bool) -> void:
	is_ally = ally
	if _plate != null and _plate.has_method("set_team"):
		_plate.set_team(ally)
	if _ring != null:
		_ring.set_ally(ally)
	collision_layer = ALLY_LAYER if ally else FOE_LAYER
	# گروهِ enemy هم باید بخواند: combat_fx از همین می‌فهمد تیر به گوشت
	# خورده یا به دیوار، و player.gd از همین لیستِ هدف می‌سازد.
	if ally:
		remove_from_group("enemy")
	elif not is_in_group("enemy"):
		add_to_group("enemy")


## آیکن اسلحه‌ی حریف روی پلاکِ بالای سرش — از assets/items/ همان آیکنی که
## در فروشگاه هم دیده می‌شود، پس فوری معلوم است طرف با چه چیزی آمده.
func _show_weapon_badge(weapon_id: String) -> void:
	if _plate == null:
		return
	var path := "res://assets/items/%s.png" % weapon_id
	if not ResourceLoader.exists(path):
		# اسکین‌ها فقط آرت نمایشی assets/weapons/ دارند
		path = "res://assets/weapons/%s.png" % weapon_id
	if not ResourceLoader.exists(path):
		path = "res://assets/items/%s.png" % WeaponSkin.resolve_id(weapon_id)
	if ResourceLoader.exists(path):
		_plate.set_weapon(load(path))


## هموارسازیِ حریف — نمایی و مستقل از فریم‌ریت (1 - exp(-k·dt)).
## k=16 یعنی ثابتِ زمانیِ ~۶۰ms: با پیش‌بینیِ بینِ بسته‌ها عقب‌ماندگی
## حدودِ ۱۰ پیکسل در سرعتِ عادی است و حرکت یکنواخت می‌ماند.
const SMOOTH_K := 16.0
const ROT_SMOOTH_K := 18.0
## پیش‌بینی حداکثر به‌اندازه‌ی یک بازه‌ی ارسال (۵۰ms) جلو می‌رود
const EXTRAP_MAX := 0.05
## اگر بسته‌ای نیامد (حریف ایستاد) پیش‌بینی آرام صفر می‌شود
const EXTRAP_FADE_START := 0.12
const EXTRAP_FADE_LEN := 0.1
const TELEPORT_DIST := 150.0
const MAX_NET_SPEED := 450.0

func _physics_process(delta):
	if target_position != Vector2.ZERO:
		var since := Time.get_ticks_msec() * 0.001 - _last_packet_t
		var lead := minf(since, EXTRAP_MAX)
		if since > EXTRAP_FADE_START:
			lead = EXTRAP_MAX * clampf(1.0 - (since - EXTRAP_FADE_START) / EXTRAP_FADE_LEN, 0.0, 1.0)
		var goal: Vector2 = target_position + _net_vel * lead
		global_position = global_position.lerp(goal, 1.0 - exp(-SMOOTH_K * delta))
		rotation = lerp_angle(rotation, target_rotation, 1.0 - exp(-ROT_SMOOTH_K * delta))

	# 🌟 حرکت رقیب از روی جابه‌جایی واقعی تشخیص داده می‌شود (سرعتی نداریم چون lerp است)
	var moved = global_position.distance_to(_prev_position)
	_prev_position = global_position
	# سرعتِ خام از جای lerp‌شده می‌آید و فریم‌به‌فریم می‌پرد؛ بدونِ این
	# هموارسازی، رقیب دمِ مرزِ اسپرینت بینِ walk و run لرز می‌زند.
	_speed = lerpf(_speed, moved / maxf(delta, 0.0001), 1.0 - exp(-8.0 * delta))
	update_body_anim(_speed)

## مرزِ دویدن نسبت به سرعتِ پایه‌ی خودِ همین بازیکن. اسپرینت ۱.۲ برابر است
## (abilities.gd → SPRINT_MULT)، پس مرز را وسطِ راه رفتن و دویدن می‌گذاریم.
## قبلاً عددِ ثابتِ ۲۲۰ بود: کاراکترِ کند حتی با اسپرینت هم «راه» می‌رفت و
## کاراکترِ تند بدونِ اسپرینت هم «می‌دوید».
const RUN_SPEED_RATIO := 1.1
const MOVE_SPEED := 20.0

func update_body_anim(speed: float):
	if anim == null:
		return
	# شلیک و تعویضِ خشاب تا آخر نشان داده می‌شوند
	if anim.current_animation == "shoot" or anim.current_animation == "reload":
		return
	var want := "idle"
	if speed > MOVE_SPEED:
		want = "run" if speed > base_speed * RUN_SPEED_RATIO else "walk"
	if anim.current_animation != want:
		anim.play(want, 0.2)

## شلیک رقیب. سرور فقط جا و زاویه را می‌فرستد، پس مسیر تیر را خودمان
## اینجا raycast می‌کنیم تا رد گلوله دقیقاً روی دیوار یا بدنِ درست بایستد.
func fire_gun(pos: Vector2, rot: float):
	var shoot_dir := Vector2.RIGHT.rotated(rot - deg_to_rad(90))
	var muzzle := pos + shoot_dir * MUZZLE_OFFSET
	var hit: Array = CombatFX.resolve_hit(muzzle, shoot_dir, [get_rid()])
	CombatFX.shoot(muzzle, shoot_dir, hit[0], hit[1])

	if shoot_sound != null:
		shoot_sound.play()
	if anim != null:
		anim.play("shoot")

## V7 hit flash: بدن یک لحظه سفید می‌شود — «تیرم خورد» زیرِ ۱۰۰ms دیده می‌شود.
## مقدارِ بیش از ۱ِ modulate روی gl_compatibility رنگِ بافت را به سفید می‌برد.
## mine (تیرِ خودت) کمی پرنورتر است تا با درگیریِ بقیه قاطی نشود.
func flash_hit(mine := false) -> void:
	if sprite == null:
		return
	if _flash_tw != null and _flash_tw.is_valid():
		_flash_tw.kill()
	var k := 2.6 if mine else 1.8
	sprite.modulate = Color(k, k, k)
	_flash_tw = create_tween()
	_flash_tw.tween_property(sprite, "modulate", Color.WHITE, 0.11)


func update_health_bar(current_health: int, max_hp: int):
	if _plate != null and max_hp > 0:
		_plate.set_health(current_health, max_hp)
	if health_bar_fill == null or health_bar_label == null or max_hp <= 0:
		return

	if current_health < 0:
		current_health = 0

	var health_percent = float(current_health) / float(max_hp)
	health_percent = clamp(health_percent, 0.0, 1.0)

	var background = health_bar_fill.get_parent().get_node_or_null("Background")
	var max_width = 60.0
	if background != null and background is Control:
		max_width = float((background as Control).offset_right - (background as Control).offset_left)

	var new_width = max_width * health_percent
	health_bar_fill.anchor_left = 0
	health_bar_fill.anchor_right = 0
	health_bar_fill.offset_left = 0
	health_bar_fill.offset_right = new_width

	if health_percent > 0.6:
		health_bar_fill.color = Color(0, 1, 0)
	elif health_percent > 0.3:
		health_bar_fill.color = Color(1, 1, 0)
	else:
		health_bar_fill.color = Color(1, 0, 0)

	health_bar_label.text = str(current_health) + "/" + str(max_hp)

	# 🌟 تغییر مهم: queue_free() از اینجا حذف شد!
	# کلاینت فقط ظاهر نوار جان رو آپدیت می‌کنه و منتظر دستور سرور می‌مونه.
