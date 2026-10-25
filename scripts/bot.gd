extends CharacterBody2D
## حریفِ هوش‌مصنوعیِ «بازی سریع».
##
## روی همان صحنه‌ی player_s (بازیکنِ دیگر) سوار می‌شود تا دقیقاً مثل یک حریفِ
## واقعی دیده شود — همان اسکلت، همان اسلحه در دست، همان پلاکِ بالای سر.
##
## رفتارش یک ماشینِ حالت ساده است که هر ۰٫۲ ثانیه تصمیم می‌گیرد:
##   CHASE  → دنبال بازیکن می‌رود تا وارد بردِ شلیک شود
##   FIGHT  → در بردِ خوب می‌ماند، می‌چرخد و شلیک می‌کند، کنارکشی می‌کند
##   DODGE  → تیر که خورد، چند لحظه عمود بر خطِ دشمن جاخالی می‌دهد
##   FLEE   → جان کم است: عقب می‌کشد
##   HEAL   → جای امن ایستاده و خودش را درمان می‌کند

signal died(bot)
## چقدر خسارت خورد — صحنه از این برای آمارِ بازیکن استفاده می‌کند
signal hurt(amount)

const PLATE := preload("res://scripts/foe_plate.gd")
## V6 حلقه‌ی قرمزِ زیرِ پا — همان که حریف‌های آنلاین دارند
const TEAM_RING := preload("res://scripts/psych_combat_ring.gd")
## نامی که کارتِ «چه کسی زدت» و اعلان‌ها نشان می‌دهند
const DISPLAY_NAME := "ربات تمرینی"

enum State { CHASE, FIGHT, DODGE, FLEE, HEAL }

# --- تواناییِ پایه (کمی قوی‌تر از بازیکنِ معمولی) ---
@export var move_speed := 195.0
@export var max_health := 130
@export var damage := 14
@export var fire_cooldown := 0.85
## بردِ درگیریِ خودِ بازیکن حدود ۱۶۵ واحد است (مخروطِ DetectionZone با
## مقیاس ۰٫۵). اگر بات دورتر از آن بایستد، بازیکن اصلاً نمی‌تواند جوابش را
## بدهد و بازی نابرابر می‌شود — پس عمداً می‌آید داخلِ همان برد.
@export var fire_range := 280.0      # از این نزدیک‌تر شلیک می‌کند
@export var keep_distance := 140.0   # فاصله‌ی دلخواه در نبرد — داخلِ بردِ بازیکن
@export var turn_rate := 300.0       # درجه بر ثانیه
@export var fire_cone_deg := 16.0    # تا این زاویه رو به هدف نباشد شلیک نمی‌کند
@export var miss_chance := 0.18

# --- بمب ---
@export var bomb_cooldown := 7.0
@export var bomb_range := 360.0
@export var bomb_radius := 100.0
@export var bomb_damage := 26
@export var bomb_min_range := 110.0  # از این نزدیک‌تر بمب نمی‌اندازد

# --- درمان ---
@export var heal_amount := 30
@export var heal_cooldown := 11.0
@export var heal_below := 0.38       # زیر این نسبت به فکر درمان می‌افتد

var health := 130
var is_dead := false
var target: Node2D = null

var _state: int = State.CHASE
var _shot_cd := 0.0
var _bomb_cd := 3.0                  # اولِ بازی بلافاصله بمب نیندازد
var _heal_cd := 0.0
var _dodge_time := 0.0
var _dodge_dir := 1.0
var _strafe_dir := 1.0
var _strafe_time := 0.0
var _think_cd := 0.0
var _plate: Node2D = null
var _weapon_id := ""
var _flash_tw: Tween = null

@onready var sprite: Node2D = $Sprite2D
@onready var weapon_sprite: Node2D = $gun
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var shoot_sound = $ShootSound


func _ready() -> void:
	add_to_group("bots")
	# هدف‌گیریِ خودکارِ بازیکن بدنه‌هایی را می‌بیند که در گروه "enemy" باشند.
	# در صحنه‌ی player_s این گروه روی VisionZone/CollisionPolygon2D نشسته، نه
	# روی خودِ بدنه — برای همین بازیکن بات را اصلاً هدف حساب نمی‌کرد و
	# هیچ‌وقت شلیک نمی‌شد.
	add_to_group("enemy")
	health = max_health
	# نوار جانِ توکارِ صحنه با بدنه می‌چرخد؛ پلاکِ صافِ FoePlate جایش را می‌گیرد
	if has_node("HealthBar"):
		$HealthBar.hide()
	_plate = PLATE.new()
	_plate.name = "FoePlate"
	_plate.setup(self)
	add_child(_plate)
	_plate.set_health(health, max_health)
	var ring := TEAM_RING.new()
	ring.name = "TeamRing"
	add_child(ring)
	move_child(ring, 0)
	_strafe_dir = 1.0 if randf() < 0.5 else -1.0


## جدولِ سه سطح. عددهای پایه (بالا) همان «متوسط» هستند؛ این‌ها رویشان
## نوشته می‌شوند. آسان عمداً کند و کم‌دقت است تا فرصتِ یاد گرفتن بدهد.
const DIFFICULTY := [
	{   # ۰ — آسان
		"health": 90, "damage": 8, "fire_cooldown": 1.30, "miss_chance": 0.32,
		"move_speed": 155.0, "turn_rate": 210.0, "fire_range": 240.0,
		"bomb_cooldown": 15.0, "heal_cooldown": 16.0, "heal_amount": 20,
		"bomb_damage": 16,
	},
	{   # ۱ — متوسط
		"health": 115, "damage": 11, "fire_cooldown": 1.00, "miss_chance": 0.22,
		"move_speed": 178.0, "turn_rate": 270.0, "fire_range": 270.0,
		"bomb_cooldown": 10.0, "heal_cooldown": 12.0, "heal_amount": 26,
		"bomb_damage": 22,
	},
	{   # ۲ — سخت
		"health": 150, "damage": 16, "fire_cooldown": 0.72, "miss_chance": 0.10,
		"move_speed": 205.0, "turn_rate": 330.0, "fire_range": 300.0,
		"bomb_cooldown": 6.0, "heal_cooldown": 9.0, "heal_amount": 34,
		"bomb_damage": 30,
	},
]


## سطح را روی بات می‌نشاند. باید قبل از add_child صدا زده شود تا _ready
## جانِ درست را بردارد.
func apply_difficulty(level: int) -> void:
	var d: Dictionary = DIFFICULTY[clampi(level, 0, DIFFICULTY.size() - 1)]
	max_health = int(d["health"])
	health = max_health
	damage = int(d["damage"])
	fire_cooldown = float(d["fire_cooldown"])
	miss_chance = float(d["miss_chance"])
	move_speed = float(d["move_speed"])
	turn_rate = float(d["turn_rate"])
	fire_range = float(d["fire_range"])
	bomb_cooldown = float(d["bomb_cooldown"])
	bomb_damage = int(d["bomb_damage"])
	heal_cooldown = float(d["heal_cooldown"])
	heal_amount = int(d["heal_amount"])
	# اولین بمب هم به‌اندازه‌ی سطح دیرتر می‌آید
	_bomb_cd = bomb_cooldown * 0.5
	if _plate != null:
		_plate.set_health(health, max_health)


func setup_appearance(character_id: String, weapon_id: String) -> void:
	CharacterSkin.apply(sprite, character_id)
	WeaponSkin.apply(weapon_sprite, weapon_id)
	_weapon_id = weapon_id
	var path := "res://assets/items/%s.png" % WeaponSkin.resolve_id(weapon_id)
	if _plate != null and ResourceLoader.exists(path):
		_plate.set_weapon(load(path))


## بازیکن به بات شلیک کرده. player.gd در حالت آفلاین این را صدا می‌زند.
func take_damage(amount: int) -> void:
	if is_dead:
		return
	var real: int = mini(amount, health)   # خسارتِ اضافه‌ی ضربه‌ی آخر حساب نشود
	health -= real
	hurt.emit(real)
	if _plate != null:
		_plate.set_health(health, max_health)
	CombatFX.hit_burst(global_position, Vector2(0, -1))
	# V1 خسارتِ خودت طلایی است؛ E11 تیکِ برخورد + چشمکِ سفید
	CombatFX.damage_number(global_position, amount, false, CombatFX.DMG_MINE)
	_flash()
	if CombatFX.feel != null:
		CombatFX.feel.on_enemy_hit(true)

	if health <= 0:
		_die()
		return
	# تیر خورد → جاخالی. همین باعث می‌شود بات مثل تخته‌ی هدف نایستد.
	_state = State.DODGE
	_dodge_time = 0.45
	_dodge_dir = 1.0 if randf() < 0.5 else -1.0


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	if _plate != null:
		_plate.queue_free()
	died.emit(self)
	# آفلاین تنها کسی که بات را می‌زند خودِ بازیکن است
	if CombatFX.feel != null:
		CombatFX.feel.on_local_kill("", global_position, false)
	CombatFX.death(self, true, 0.5)


## V7 چشمکِ سفیدِ تیر خوردن (همان player_s.gd → flash_hit)
func _flash() -> void:
	if sprite == null:
		return
	if _flash_tw != null and _flash_tw.is_valid():
		_flash_tw.kill()
	sprite.modulate = Color(2.6, 2.6, 2.6)
	_flash_tw = create_tween()
	_flash_tw.tween_property(sprite, "modulate", Color.WHITE, 0.11)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_shot_cd = maxf(_shot_cd - delta, 0.0)
	_bomb_cd = maxf(_bomb_cd - delta, 0.0)
	_heal_cd = maxf(_heal_cd - delta, 0.0)
	_think_cd -= delta
	_strafe_time -= delta

	# هدف مرده یا رفته: بات باید بایستد. بدون این، بات‌ها بعد از مرگِ بازیکن
	# همچنان به جنازه شلیک می‌کردند و صدای شلیک قطع نمی‌شد.
	if not is_instance_valid(target) or _target_is_down():
		velocity = Vector2.ZERO
		move_and_slide()
		_update_anim()
		return

	var to_target: Vector2 = target.global_position - global_position
	var dist := to_target.length()

	if _think_cd <= 0.0:
		_think_cd = 0.2
		_decide(dist)

	velocity = _move_for_state(to_target, dist, delta) * move_speed
	move_and_slide()

	# رو به هدف می‌چرخد، ولی نه آنی — مثل خودِ بازیکن با نرخِ محدود
	var want_rot := to_target.angle() + deg_to_rad(90)
	rotation = _turn_toward(rotation, want_rot, deg_to_rad(turn_rate) * delta)

	_try_shoot(dist, want_rot)
	_try_bomb(dist)
	_update_anim()


## آیا هدف از پا درآمده؟
func _target_is_down() -> bool:
	return "is_dead" in target and target.is_dead


## انتخابِ حالت — ترتیبِ شرط‌ها یعنی اولویت
func _decide(dist: float) -> void:
	if _dodge_time > 0.0:
		_state = State.DODGE
		return

	var hp_ratio := float(health) / float(max_health)
	# جان کم: اگر درمان آماده است و فاصله امن است بایست و بزن، وگرنه عقب بکش
	if hp_ratio <= heal_below:
		if _heal_cd <= 0.0 and dist > 190.0:
			_state = State.HEAL
			_do_heal()
		else:
			_state = State.FLEE
		return

	if dist > fire_range:
		_state = State.CHASE
	else:
		_state = State.FIGHT
		if _strafe_time <= 0.0:
			# جهتِ کنارکشی هر چند وقت عوض می‌شود تا قابل پیش‌بینی نباشد
			_strafe_time = randf_range(0.7, 1.6)
			_strafe_dir = -_strafe_dir


func _move_for_state(to_target: Vector2, dist: float, delta: float) -> Vector2:
	var dir := to_target.normalized()
	match _state:
		State.DODGE:
			_dodge_time = maxf(_dodge_time - delta, 0.0)
			if _dodge_time <= 0.0:
				_state = State.FIGHT
			# عمود بر خطِ دشمن — کوتاه‌ترین راهِ بیرون رفتن از خطِ شلیک
			return dir.orthogonal() * _dodge_dir

		State.FLEE:
			return -dir

		State.HEAL:
			return Vector2.ZERO

		State.FIGHT:
			# فاصله را حولِ keep_distance نگه می‌دارد و دورِ بازیکن می‌چرخد
			# نوارِ تحمل باریک است: با نوارِ پهن، بات روی لبه‌ی بیرونی می‌ماند
			# و از بردِ درگیریِ بازیکن بیرون می‌افتاد.
			var radial := 0.0
			if dist < keep_distance - 25.0:
				radial = -1.0
			elif dist > keep_distance + 25.0:
				radial = 1.0
			return (dir * radial + dir.orthogonal() * _strafe_dir * 0.9).normalized()

		_:
			return dir


func _try_shoot(dist: float, want_rot: float) -> void:
	if _shot_cd > 0.0 or dist > fire_range or _state == State.HEAL:
		return
	if _target_is_down():
		return
	# مثل خودِ بازیکن: تا چرخش واقعاً به هدف نرسیده، شلیک نمی‌گیرد
	if absf(wrapf(want_rot - rotation, -PI, PI)) > deg_to_rad(fire_cone_deg):
		return
	if not _has_line_of_sight():
		return

	_shot_cd = fire_cooldown
	var shoot_dir := Vector2.RIGHT.rotated(rotation - deg_to_rad(90))
	var muzzle := global_position + shoot_dir * 60.0
	var missed := randf() < miss_chance
	CombatFX.shoot(muzzle, shoot_dir, target.global_position, true, true, not missed)
	if shoot_sound != null:
		shoot_sound.play()
	if anim != null:
		anim.play("shoot")
	if not missed and target.has_method("take_damage"):
		# C10/V4: منبعِ ضربه برای کمانِ جهت و کارتِ «چه کسی زدت»
		if CombatFX.feel != null:
			CombatFX.feel.note_attack(DISPLAY_NAME, global_position, _weapon_id, "gun")
		target.take_damage(damage)


## بمب وقتی می‌ارزد که هدف نه خیلی دور باشد نه چسبیده (خودزنی)
func _try_bomb(dist: float) -> void:
	if _bomb_cd > 0.0 or is_dead or _target_is_down():
		return
	if dist < bomb_min_range or dist > bomb_range:
		return
	if not _has_line_of_sight():
		return
	_bomb_cd = bomb_cooldown

	# کمی جلوترِ هدف می‌اندازد تا اگر داشت می‌آمد وسطِ انفجار بیفتد
	var lead := Vector2.ZERO
	if "velocity" in target:
		lead = target.velocity * 0.35
	var arena := get_parent()
	if arena != null and arena.has_method("spawn_local_bomb"):
		if CombatFX.feel != null:
			CombatFX.feel.note_attack(DISPLAY_NAME, target.global_position + lead, "", "bomb")
		arena.spawn_local_bomb(global_position, target.global_position + lead,
			bomb_radius, bomb_damage, self)


func _do_heal() -> void:
	if _heal_cd > 0.0 or is_dead:
		return
	_heal_cd = heal_cooldown
	health = mini(health + heal_amount, max_health)
	if _plate != null:
		_plate.set_health(health, max_health)
	CombatFX.damage_number(global_position, heal_amount, true)


## دیدِ باز: دیوار بین بات و هدف نباشد. زمینِ فعلی مانع ندارد، ولی اگر دوباره
## مانع اضافه شود بات از پشتِ دیوار شلیک نمی‌کند.
func _has_line_of_sight() -> bool:
	if not is_instance_valid(target):
		return false
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, target.global_position)
	# خودِ هدف هم باید کنار گذاشته شود: نودِ Player روی لایه‌ی ۱ است — همان
	# لایه‌ی دیوار — پس بدونِ این، رِی همیشه به خودِ بازیکن می‌خورد و بات
	# فکر می‌کرد پشتِ دیوار است؛ نه شلیک می‌کرد نه بمب می‌انداخت.
	q.exclude = [get_rid(), target.get_rid()]
	q.collision_mask = 1      # فقط لایه‌ی دیوار
	return space.intersect_ray(q).is_empty()


func _turn_toward(current: float, want: float, max_delta: float) -> float:
	var diff := wrapf(want - current, -PI, PI)
	if absf(diff) <= max_delta:
		return want
	return current + signf(diff) * max_delta


func _update_anim() -> void:
	if anim == null or anim.current_animation == "shoot":
		return
	var want := "walk" if velocity.length() > 5.0 else "idle"
	if anim.current_animation != want:
		anim.play(want, 0.2)
