extends CharacterBody2D

@onready var sprite = $Sprite2D
@onready var weapon_sprite = $gun
@onready var muzzle_flash = $MuzzleFlash
@onready var shoot_sound = $ShootSound
@onready var health_bar_fill = $HealthBar/Fill
@onready var health_bar_label = $HealthBar/HealthLabel

@export var bullet_scene: PackedScene

var target_position = Vector2.ZERO
var target_rotation = 0.0
var health = 100
var max_health = 100

func _ready():
	add_to_group("enemy")
	$HealthBar.show()
	$HealthBar.z_index = 10
	update_health_bar(max_health, max_health)

func set_max_health(max_hp: int):
	max_health = max_hp
	health = max_hp
	update_health_bar(health, max_health)

func setup_appearance(character_id: String, weapon_id: String):
	var image_path = "res://assets/used_items/" + character_id + ".png"
	if ResourceLoader.exists(image_path):
		sprite.texture = load(image_path)
	if weapon_sprite != null:
		var weapon_path = "res://assets/used_items/" + weapon_id + ".png"
		if ResourceLoader.exists(weapon_path):
			weapon_sprite.texture = load(weapon_path)

func _physics_process(delta):
	if target_position != Vector2.ZERO:
		global_position = global_position.lerp(target_position, 15 * delta)
		rotation = lerp_angle(rotation, target_rotation, 15 * delta)

func fire_gun(pos: Vector2, rot: float):
	if bullet_scene == null:
		print("⚠️ صحنه تیر رو به رقیب ندادی!")
		return
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	
	# 🌟 این خط اضافه شده: اسم رقیب به عنوان صاحب تیر ثبت میشه
	if "shooter_name" in bullet:
		bullet.shooter_name = name 
		
	bullet.global_position = pos
	var shoot_dir = Vector2.RIGHT.rotated(rot - deg_to_rad(90))
	
	# اگر متغیر direction داخل تیر تعریف شده باشه بهش میدیم
	if "direction" in bullet:
		bullet.direction = shoot_dir
		
	bullet.rotation = shoot_dir.angle()
	
	if muzzle_flash != null:
		muzzle_flash.restart()
	if shoot_sound != null:
		shoot_sound.play()

func update_health_bar(current_health: int, max_hp: int):
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
	# کلاینت فقط ظاهر نوار خون رو آپدیت می‌کنه و منتظر دستور سرور می‌مونه.