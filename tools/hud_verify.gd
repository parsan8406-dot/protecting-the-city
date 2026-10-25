extends SceneTree
## بررسی نهایی: همه‌ی اسکریپت‌ها لود می‌شوند و HUD + پلاکِ حریف سالم‌اند.
var bad := 0
func _ok(n: String, c: bool, d: String = "") -> void:
	if c: print("  PASS  ", n)
	else:
		bad += 1
		print("  FAIL  ", n, "  ", d)

func _initialize() -> void:
	for path in ["res://scripts/world.gd", "res://scripts/player.gd",
			"res://scripts/player_s.gd", "res://scripts/combat_hud.gd",
			"res://scripts/foe_plate.gd", "res://scripts/game_hud.gd",
			"res://scripts/hud_ability_button.gd", "res://scripts/hud_minimap.gd",
			"res://scripts/hud_objectives.gd", "res://scripts/self_plate.gd",
			"res://scripts/laser_beam.gd", "res://scripts/ingame_settings.gd"]:
		_ok("loads " + path.get_file(), load(path) != null)

	var world = load("res://secense/World.tscn").instantiate()
	root.add_child(world)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3000:
		await process_frame

	var hud = world.combat_hud
	_ok("CombatHUD exists (inside GameHUD)", hud != null and world.get_node_or_null("UI/GameHUD") != null)
	_ok("legacy health bar is gone (replaced by CombatHUD)",
		world.get_node_or_null("UI/PlayerHealthBar") == null)

	# فشنگ‌ها از خودِ بازیکن به HUD می‌رسند
	var player = world.get_node("Player")
	player.current_ammo = 5
	player._sync_ammo_hud()
	await process_frame
	_ok("ammo row reflects the player", hud._ammo_cur == 5 and hud._ammo_max == player.max_ammo,
		"hud=%d/%d player=%d/%d" % [hud._ammo_cur, hud._ammo_max, player.current_ammo, player.max_ammo])

	# جان
	world.update_player_health_ui(40, 112)
	await process_frame
	_ok("health forwarded to HUD", absf(hud._hp - 40.0 / 112.0) < 0.001, "hp=%f" % hud._hp)

	# حریف
	var foe = load("res://secense/player_s.tscn").instantiate()
	world.add_child(foe)
	foe.global_position = player.global_position + Vector2(60, 0)
	foe.rotation = 1.2
	foe.setup_appearance("skin_devil", "awm")
	foe.set_max_health(120)
	foe.update_health_bar(90, 120)
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 600:
		await process_frame
	var plate = foe.get_node_or_null("FoePlate")
	_ok("foe plate exists", plate != null)
	if plate != null:
		_ok("foe plate stays upright while the foe rotates", absf(plate.global_rotation) < 0.001,
			"rot=%f" % plate.global_rotation)
		_ok("foe weapon icon set", plate._weapon != null,
			str(plate._weapon.resource_path) if plate._weapon else "none")
		_ok("foe health on plate", absf(plate._hp - 0.75) < 0.001, "hp=%f" % plate._hp)

	print("\nRESULT: ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)
