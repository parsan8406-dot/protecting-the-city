extends Node2D

@export var ammo_box_scene: PackedScene
@export var other_player_scene: PackedScene
@export var bomb_scene: PackedScene  # 🌟 صحنه بمب رو توی اینسپکتر ست کن

@onready var spawn_points_node = $SpawnPointsChar
@onready var player_sprite = $Player/Sprite2D
@onready var weapon_sprite = $Player/gun
@onready var death_menu = $UI/DeathMenu
@onready var player_health_fill = $UI/PlayerHealthBar/Fill
@onready var player_health_label = $UI/PlayerHealthBar/HealthLabel
@onready var heal_button = $UI/HealButton
@onready var heal_cooldown_label = $UI/HealButton/CooldownLabel
@onready var bomb_button = $UI/BombButton
@onready var bomb_cooldown_label = $UI/BombButton/BombCooldownLabel
@onready var bomb_sound = $Player/BombSound

var spawned_players = {}
var max_health = 100
var heal_cooldown_active = false
var bomb_cooldown_active = false
var countdown_label: Label = null

func _ready():
	if death_menu != null:
		death_menu.hide()

	_create_countdown_ui()
	$Player.hide()

	Network.server_players_updated.connect(_on_players_updated)
	Network.player_moved.connect(_on_player_moved)
	Network.player_shot.connect(_on_player_shot)
	Network.game_countdown.connect(_on_game_countdown)
	Network.game_started.connect(_on_game_started)
	if not Network.health_updated.is_connected(_on_health_updated):
		Network.health_updated.connect(_on_health_updated)
	if not Network.player_died.is_connected(_on_player_died):
		Network.player_died.connect(_on_player_died)
	if not Network.heal_success.is_connected(_on_heal_success):
		Network.heal_success.connect(_on_heal_success)
	if not Network.heal_cooldown_started.is_connected(_on_heal_cooldown_started):
		Network.heal_cooldown_started.connect(_on_heal_cooldown_started)
	if not Network.bomb_thrown.is_connected(_on_bomb_thrown):
		Network.bomb_thrown.connect(_on_bomb_thrown)
	if not Network.bomb_explosion.is_connected(_on_bomb_explosion):
		Network.bomb_explosion.connect(_on_bomb_explosion)

	max_health = get_character_max_health(Global.current_character)
	update_player_health_ui(max_health, max_health)

	await get_tree().create_timer(1.0).timeout

	var free_pos = get_free_spawn_point()
	$Player.global_position = free_pos
	$Player.last_sent_pos = free_pos
	$Player.show()

	if Network.is_connected:
		Network.send_move_data(free_pos, $Player.rotation)

	if Network.current_players.size() > 0:
		_on_players_updated(Network.current_players)

	spawn_random_ammo(3)

	var image_path = "res://assets/used_items/" + Global.current_character + ".png"
	if ResourceLoader.exists(image_path):
		player_sprite.texture = load(image_path)

	var image_path_w = "res://assets/used_items/" + Global.current_weapon + ".png"
	if ResourceLoader.exists(image_path_w):
		weapon_sprite.texture = load(image_path_w)

	# اتصال دکمه Heal
	if heal_button != null:
		heal_button.pressed.connect(_on_heal_button_pressed)
		heal_button.modulate = Color(1, 1, 1, 1)
		if heal_cooldown_label != null:
			heal_cooldown_label.hide()

	# اتصال دکمه Bomb
	if bomb_button != null:
		bomb_button.pressed.connect(_on_bomb_button_pressed)
		bomb_button.modulate = Color(1, 1, 1, 1)
		if bomb_cooldown_label != null:
			bomb_cooldown_label.hide()

# ==================== COUNTDOWN UI ====================
func _create_countdown_ui():
	var canvas = CanvasLayer.new()
	canvas.name = "CountdownCanvas"
	canvas.layer = 100
	add_child(canvas)
	countdown_label = Label.new()
	countdown_label.text = "3"
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	countdown_label.add_theme_font_size_override("font_size", 120)
	countdown_label.add_theme_color_override("font_color", Color(1, 1, 0))
	countdown_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	countdown_label.add_theme_constant_override("shadow_offset_x", 3)
	countdown_label.add_theme_constant_override("shadow_offset_y", 3)
	countdown_label.hide()
	canvas.add_child(countdown_label)

func _on_game_countdown(seconds: int):
	if countdown_label == null:
		return
	countdown_label.show()
	countdown_label.text = str(seconds)
	_start_countdown_animation(seconds)

func _start_countdown_animation(seconds: int):
	for i in range(seconds, 0, -1):
		countdown_label.text = str(i)
		countdown_label.scale = Vector2(2.0, 2.0)
		var tween = create_tween()
		tween.tween_property(countdown_label, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(1.0).timeout

func _on_game_started():
	if countdown_label != null:
		countdown_label.text = "⚔️ شروع!"
		countdown_label.add_theme_color_override("font_color", Color(0, 1, 0))
		await get_tree().create_timer(0.8).timeout
		var tween = create_tween()
		tween.tween_property(countdown_label, "modulate:a", 0.0, 0.3)
		await tween.finished
		countdown_label.hide()
		countdown_label.modulate.a = 1.0

# ==================== SPAWN ====================
func get_free_spawn_point() -> Vector2:
	var all_spawn_points = spawn_points_node.get_children()
	if all_spawn_points.size() == 0:
		return Vector2.ZERO
	all_spawn_points.shuffle()
	for spawn_node in all_spawn_points:
		var is_free = true
		var spawn_pos = spawn_node.global_position
		for username in Network.current_players:
			if username == Global.my_username:
				continue
			var p_data = Network.current_players[username]
			if spawn_pos.distance_to(Vector2(p_data.get("x", 0), p_data.get("y", 0))) < 100.0:
				is_free = false
				break
		if is_free:
			return spawn_pos
	return all_spawn_points.pick_random().global_position

func get_character_max_health(character_id: String) -> int:
	match character_id:
		"skin_default": return 75
		"skin_heavy": return 150
		"skin_fast": return 75
		_: return 100

func update_player_health_ui(current_health: int, max_hp: int):
	if player_health_fill == null or player_health_label == null:
		return
	var health_percent = clamp(float(current_health) / float(max_hp), 0.0, 1.0)
	player_health_fill.size.x = 250.0 * health_percent
	if health_percent > 0.6:
		player_health_fill.color = Color(0, 1, 0)
	elif health_percent > 0.3:
		player_health_fill.color = Color(1, 1, 0)
	else:
		player_health_fill.color = Color(1, 0, 0)
	player_health_label.text = str(current_health) + " / " + str(max_hp)

func spawn_random_ammo(amount):
	var all_points = spawn_points_node.get_children()
	all_points.shuffle()
	for i in range(amount):
		if i < all_points.size():
			var new_ammo_box = ammo_box_scene.instantiate()
			add_child(new_ammo_box)
			new_ammo_box.global_position = all_points[i].global_position

# ==================== PLAYERS ====================
func _on_players_updated(players_dict):
	for username in players_dict:
		if username == Global.my_username:
			continue
		if not spawned_players.has(username):
			var new_enemy = other_player_scene.instantiate()
			new_enemy.name = username
			var p_data = players_dict[username]
			var spawn_pos = Vector2(p_data.get("x", 300), p_data.get("y", 200))
			new_enemy.global_position = spawn_pos
			if "target_position" in new_enemy:
				new_enemy.target_position = spawn_pos
			new_enemy.rotation = p_data.get("rot", 0.0)
			if "target_rotation" in new_enemy:
				new_enemy.target_rotation = new_enemy.rotation
			add_child(new_enemy)
			spawned_players[username] = new_enemy
			print("✅ بازیکن جدید: ", username)
			if new_enemy.has_method("setup_appearance"):
				new_enemy.setup_appearance(p_data.get("character", "skin_default"), p_data.get("weapon", "pistol_default"))
			if new_enemy.has_method("set_max_health"):
				new_enemy.set_max_health(get_character_max_health(p_data.get("character", "skin_default")))
			if new_enemy.has_method("update_health_bar"):
				new_enemy.update_health_bar(p_data.get("health", 100), get_character_max_health(p_data.get("character", "skin_default")))
	for username in spawned_players.keys():
		if not players_dict.has(username):
			if is_instance_valid(spawned_players[username]):
				spawned_players[username].queue_free()
			spawned_players.erase(username)

func _on_player_moved(username, new_pos, rot):
	if spawned_players.has(username):
		var enemy = spawned_players[username]
		if is_instance_valid(enemy):
			if "target_position" in enemy:
				enemy.target_position = new_pos
			if "target_rotation" in enemy:
				enemy.target_rotation = rot
		else:
			spawned_players.erase(username)

func _on_player_shot(username, pos, rot):
	if spawned_players.has(username):
		var enemy = spawned_players[username]
		if is_instance_valid(enemy) and enemy.has_method("fire_gun"):
			enemy.fire_gun(pos, rot)

func _on_health_updated(username: String, new_health: int):
	if username == Global.my_username:
		if "health" in $Player:
			$Player.health = new_health
		update_player_health_ui(new_health, max_health)
		return
	if spawned_players.has(username):
		var p = spawned_players[username]
		if is_instance_valid(p):
			if "health" in p:
				p.health = new_health
			if p.has_method("update_health_bar"):
				p.update_health_bar(new_health, p.max_health)

func _on_player_died(username: String):
	print("💀 مرگ: ", username)
	if username == Global.my_username:
		if "is_dead" in $Player and not $Player.is_dead and $Player.has_method("die"):
			$Player.die()
		update_player_health_ui(0, max_health)
	else:
		if spawned_players.has(username):
			var enemy = spawned_players[username]
			if is_instance_valid(enemy):
				enemy.queue_free()
			spawned_players.erase(username)

# ==================== HEAL ====================
func _on_heal_button_pressed():
	if heal_cooldown_active or $Player.is_dead or $Player.health >= max_health:
		return
	Network.send_heal_request()

func _on_heal_success(username: String, new_health: int):
	print("🏥 Heal: ", username, " HP: ", new_health)
	if username == Global.my_username:
		$Player.health = new_health
		update_player_health_ui(new_health, max_health)
		_spawn_heal_effect($Player.global_position)
	else:
		if spawned_players.has(username):
			var p = spawned_players[username]
			if is_instance_valid(p):
				if "health" in p:
					p.health = new_health
				if p.has_method("update_health_bar"):
					p.update_health_bar(new_health, p.max_health)
				_spawn_heal_effect(p.global_position)

func _on_heal_cooldown_started(username: String):
	if username == Global.my_username:
		heal_cooldown_active = true
		if heal_button != null:
			heal_button.modulate.a = 0.4
		if heal_cooldown_label != null:
			heal_cooldown_label.show()
		for i in range(12, 0, -1):
			if heal_cooldown_label != null:
				heal_cooldown_label.text = str(i)
			await get_tree().create_timer(1.0).timeout
		heal_cooldown_active = false
		if heal_button != null:
			heal_button.modulate.a = 1.0
		if heal_cooldown_label != null:
			heal_cooldown_label.hide()

func _spawn_heal_effect(pos: Vector2):
	var particles = CPUParticles2D.new()
	particles.global_position = pos
	particles.z_index = 100
	particles.amount = 20
	particles.lifetime = 1.0
	particles.explosiveness = 0.9
	particles.one_shot = true
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 200.0
	particles.gravity = Vector2(0, 200)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = Color(0, 1, 0, 1)
	add_child(particles)
	particles.emitting = true
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(particles):
		particles.queue_free()

# ==================== BOMB ====================
func _on_bomb_button_pressed():
	if bomb_cooldown_active or $Player.is_dead:
		print("⏳ بمب در cooldown است یا مرده‌ای!")
		return
	
	# محاسبه جهت پرتاب بر اساس جهت بازیکن
	var bomb_dir = Vector2.RIGHT.rotated($Player.rotation - deg_to_rad(90))
	print("💣 درخواست پرتاب بمب! جهت: ", bomb_dir)
	Network.send_bomb_request(bomb_dir)
	start_bomb_cooldown_ui()

func start_bomb_cooldown_ui():
	bomb_cooldown_active = true
	if bomb_button != null:
		bomb_button.modulate.a = 0.4
	if bomb_cooldown_label != null:
		bomb_cooldown_label.show()
	for i in range(5, 0, -1):
		if bomb_cooldown_label != null:
			bomb_cooldown_label.text = str(i)
		await get_tree().create_timer(1.0).timeout
	bomb_cooldown_active = false
	if bomb_button != null:
		bomb_button.modulate.a = 1.0
	if bomb_cooldown_label != null:
		bomb_cooldown_label.hide()
	print("✅ بمب دوباره آماده است!")

# 🌟 وقتی سرور پیام پرتاب بمب رو فرستاد
func _on_bomb_thrown(data: Dictionary):
	var start_pos = Vector2(data.get("start_x", 0), data.get("start_y", 0))
	var exp_pos = Vector2(data.get("explosion_x", 0), data.get("explosion_y", 0))
	var radius = data.get("bomb_radius", 100.0)
	var shooter = data.get("username", "")
	print("💣 بمب پرتاب شد توسط ", shooter, " از ", start_pos, " به ", exp_pos)
	
	_spawn_bomb_animation(start_pos, exp_pos, radius)

# 🌟 انیمیشن بمب: پرتاب + مکث + انفجار
# 🌟 انیمیشن بمب: پرتاب با فیزیک (کاهش سرعت تدریجی) + مکث + انفجار
func _spawn_bomb_animation(start_pos: Vector2, exp_pos: Vector2, radius: float):
	if bomb_scene == null:
		print("⚠️ bomb_scene ست نشده! توی اینسپکتر World ستش کن")
		return
	
	# ساخت نمونه‌ای از صحنه بمب
	var bomb = bomb_scene.instantiate()
	bomb.global_position = start_pos
	bomb.z_index = 60
	add_child(bomb)
	
	# 🌟 انیمیشن فیزیک‌طور: سرعت تدریجاً کم می‌شه
	# تقسیم مسیر به ۴ بخش با زمان‌های مختلف
	var total_distance = start_pos.distance_to(exp_pos)
	var segment1 = start_pos.lerp(exp_pos, 0.5)  # ۵۰٪ مسیر
	var segment2 = start_pos.lerp(exp_pos, 0.75) # ۷۵٪ مسیر
	var segment3 = start_pos.lerp(exp_pos, 0.875) # ۸۷.۵٪ مسیر
	var segment4 = start_pos.lerp(exp_pos, 0.9375) # ۹۳.۷۵٪ مسیر
	
	var tween = create_tween()
	
	# بخش ۱: ۵۰٪ مسیر در ۰.۲ ثانیه (سریع)
	tween.tween_property(bomb, "global_position", segment1, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# بخش ۲: ۲۵٪ مسیر در ۰.۱۵ ثانیه (کمی کندتر)
	tween.tween_property(bomb, "global_position", segment2, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# بخش ۳: ۱۲.۵٪ مسیر در ۰.۱ ثانیه (کندتر)
	tween.tween_property(bomb, "global_position", segment3, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# بخش ۴: ۶.۲۵٪ مسیر در ۰.۰۵ ثانیه (خیلی کند)
	tween.tween_property(bomb, "global_position", segment4, 0.05).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# بخش نهایی: رسیدن به مقصد
	tween.tween_property(bomb, "global_position", exp_pos, 0.05).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# مکث ۱ ثانیه‌ای
	tween.tween_interval(1.0)
	
	# انفجار
	tween.tween_callback(func():
		bomb_sound.play()
		if is_instance_valid(bomb):
			bomb.queue_free()
		_spawn_bomb_explosion_visual(exp_pos, radius)
	)

# 🌟 وقتی سرور پیام انفجار رو فرستاد (برای کلاینت‌های دیگه که انیمیشن پرتاب رو ندیدن)
func _on_bomb_explosion(data: Dictionary):
	var exp_pos = Vector2(data.get("explosion_x", 0), data.get("explosion_y", 0))
	var radius = data.get("explosion_radius", 100.0)
	_spawn_bomb_explosion_visual(exp_pos, radius)

# 🌟 انیمیشن انفجار: دایره قرمز کمرنگ + هسته نارنجی
func _spawn_bomb_explosion_visual(pos: Vector2, radius: float):
	print("💥 انفجار بمب در: ", pos, " شعاع: ", radius)
	
	# دایره قرمز کمرنگ (محدوده انفجار)
	var circle = Polygon2D.new()
	var pts = PackedVector2Array()
	var segments = 32
	for i in range(segments):
		var angle = (2 * PI * i) / segments
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	circle.polygon = pts
	circle.color = Color(1, 0, 0, 0.3)
	circle.global_position = pos
	circle.z_index = 50
	circle.scale = Vector2(0.01, 0.01)
	add_child(circle)
	
	# انیمیشن بزرگ شدن دایره قرمز
	var tween = create_tween()
	tween.tween_property(circle, "scale", Vector2(1, 1), 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.3)
	tween.tween_property(circle, "color:a", 0.0, 0.3)
	tween.tween_callback(circle.queue_free)
	
	# دایره کوچک مرکزی (هسته انفجار نارنجی)
	var core = Polygon2D.new()
	var core_pts = PackedVector2Array()
	for i in range(16):
		var angle = (2 * PI * i) / 16
		core_pts.append(Vector2(cos(angle), sin(angle)) * 15)
	core.polygon = core_pts
	core.color = Color(1, 0.5, 0, 0.9)
	core.global_position = pos
	core.z_index = 55
	core.scale = Vector2(0.01, 0.01)
	add_child(core)
	
	var tween2 = create_tween()
	tween2.tween_property(core, "scale", Vector2(3, 3), 0.3).set_ease(Tween.EASE_OUT)
	tween2.tween_property(core, "color:a", 0.0, 0.4)
	tween2.tween_callback(core.queue_free)