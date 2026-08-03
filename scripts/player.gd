extends CharacterBody2D

const SPEED = 200.0
var max_ammo = 12
var current_ammo = 12
var health = 100
var is_dead = false
var last_sent_pos = Vector2.ZERO
var last_sent_rot = 0.0

@onready var sight_ray = $SightRay
@onready var joystick = $"../UI/VirtualJoystick"
@onready var muzzle_flash = $MuzzleFlash
@onready var shoot_sound = $ShootSound
@onready var reload_sound = $ReloadAmmo
@onready var ammo_display = $"../UI/AmmoDisplay"
@export var bullet_icon: Texture2D
@export var bullet_scene: PackedScene

var enemies_in_range: Array[Node2D] = []
var can_shoot = true  # 🌟 جلوگیری از spam

func _ready():
	if ammo_display != null:
		for i in range(max_ammo):
			var icon = TextureRect.new()
			icon.texture = bullet_icon
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.custom_minimum_size = Vector2(50,50)
			ammo_display.add_child(icon)

func _physics_process(delta):
	if is_dead: return
	
	var move_direction = joystick.joystick_vector
	if move_direction != Vector2.ZERO:
		velocity = move_direction * SPEED
		rotation = move_direction.angle() + deg_to_rad(90)
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	
	var pos_changed = global_position.distance_to(last_sent_pos) > 1.0
	var rot_changed = abs(rotation - last_sent_rot) > 0.1
	
	if pos_changed or rot_changed:
		if Network.is_connected:
			Network.send_move_data(global_position, rotation)
			last_sent_pos = global_position
			last_sent_rot = rotation
	
	clean_enemies_list()
	
	# 🌟 حذف fire_timer - فقط وقتی can_shoot فعاله
	if enemies_in_range.size() > 0 and can_shoot:
		shoot()

func shoot():
	if current_ammo <= 0 or is_dead:
		print("❌ شلیک لغو شد.")
		return
	
	can_shoot = false  # 🌟 جلوگیری از spam
	var hit_registered = false
	
	for target in enemies_in_range:
		if is_instance_valid(target):
			sight_ray.target_position = sight_ray.to_local(target.global_position)
			sight_ray.force_raycast_update()
			if sight_ray.is_colliding():
				var collider = sight_ray.get_collider()
				if collider == target:
					hit_registered = true
					print("💥 هدف تایید شد! شلیک به سرور...")
					current_ammo -= 1
					if ammo_display != null and current_ammo >= 0 and current_ammo < ammo_display.get_child_count():
						var icon = ammo_display.get_child(current_ammo)
						icon.hide()
					
					# 🌟 انیمیشن شلیک
					var bullet = bullet_scene.instantiate()
					if "shooter_name" in bullet:
						bullet.shooter_name = name 
					get_tree().current_scene.add_child(bullet)
					var shoot_dir = Vector2.RIGHT.rotated(rotation - deg_to_rad(90))
					if "direction" in bullet:
						bullet.direction = shoot_dir
					bullet.rotation = shoot_dir.angle()
					bullet.global_position = global_position + (shoot_dir * 40.0)
					muzzle_flash.restart() 
					shoot_sound.play()
					
					# 🌟 ارسال به سرور
					Network.send_shoot_data(global_position, rotation)
					
					# 🌟 مهم: collider.name باید username باشه
					var target_username = collider.name
					print("🎯 ارسال hit به سرور برای: ", target_username)
					Network.send_hit_data(target_username)
					
					# 🌟 بعد از 0.3 ثانیه دوباره اجازه شلیک بده
					await get_tree().create_timer(0.3).timeout
					can_shoot = true
					return

	if not hit_registered:
		can_shoot = true

func clean_enemies_list():
	var valid_enemies: Array[Node2D] = []
	for enemy in enemies_in_range:
		if is_instance_valid(enemy):
			valid_enemies.append(enemy)
	enemies_in_range = valid_enemies

func _on_detection_zone_body_entered(body):
	if body.is_in_group("enemy") and body != self:
		if not enemies_in_range.has(body):
			enemies_in_range.append(body)

func _on_detection_zone_body_exited(body):
	if body in enemies_in_range:
		enemies_in_range.erase(body)

func reload_full_ammo() -> bool:
	if current_ammo >= max_ammo or is_dead: return false
	current_ammo = max_ammo
	reload_sound.play()
	if ammo_display != null:
		for child in ammo_display.get_children():
			child.show()
	return true

func die():
	is_dead = true
	hide()
	var canvas = CanvasLayer.new()
	get_tree().current_scene.add_child(canvas)
	var panel = ColorRect.new()
	panel.color = Color(0, 0, 0, 0.8)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(panel)
	var label = Label.new()
	label.text = "شما باختید!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 60)
	label.add_theme_color_override("font_color", Color.RED)
	panel.add_child(label)
	var btn = Button.new()
	btn.text = "بازگشت به خانه"
	btn.custom_minimum_size = Vector2(200, 60)
	btn.set_anchors_preset(Control.PRESET_CENTER)
	btn.position.y += 100
	btn.pressed.connect(_on_return_home_pressed)
	panel.add_child(btn)

func _on_return_home_pressed():
	if Network.socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		Network.socket.close()
	Network.is_connected = false
	get_tree().change_scene_to_file("res://secense/main_menu.tscn")