extends SceneTree
## دکمه‌ی افزایش جان در بازی سریع (آفلاین) — آنلاین سرور درمان می‌کند،
## آفلاین باید خودِ صحنه این کار را بکند.

var bad := 0
func _ok(n: String, c: bool, d: String = "") -> void:
	if c: print("  PASS  ", n)
	else:
		bad += 1
		print("  FAIL  ", n, "  ", d)

func _wait(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame

func _initialize() -> void:
	var world = load("res://secense/quick_play.tscn").instantiate()
	root.add_child(world)
	await _wait(2600)

	var player = world.get_node("Player")
	var btn = world.hud.button("heal")
	var hud = world.combat_hud
	_ok("heal button exists", btn != null)
	_ok("heal button is wired", btn != null and btn.activated.get_connections().size() > 0)

	# با جانِ کامل نباید کاری کند
	world._on_heal_button_pressed()
	await process_frame
	_ok("no heal at full health", btn.is_ready(),
		"cooldown started at full hp")

	# حالا زخمی‌اش می‌کنیم
	world._damage_local_player(60)
	await _wait(150)
	var hurt: int = player.health
	world._on_heal_button_pressed()
	await _wait(200)
	var amount: int = int(world.my_stats.get("heal_amount", 25))
	_ok("heal button actually heals", player.health == hurt + amount,
		"hp %d -> %d (expected +%d)" % [hurt, player.health, amount])
	_ok("HUD follows the heal",
		absf(hud._hp - float(player.health) / float(world.max_health)) < 0.01,
		"hud=%.3f" % hud._hp)
	_ok("cooldown starts after healing", not btn.is_ready())

	# در کول‌داون نباید دوباره کار کند
	var after: int = player.health
	world._damage_local_player(20)
	await _wait(120)
	var before_second: int = player.health
	world._on_heal_button_pressed()
	await _wait(150)
	_ok("no second heal during cooldown", player.health == before_second,
		"hp %d -> %d" % [before_second, player.health])

	# سقفِ جان رعایت شود
	btn.reset()
	player.health = world.max_health - 3
	world._on_heal_button_pressed()
	await _wait(150)
	_ok("heal never exceeds max health", player.health == world.max_health,
		"hp=%d max=%d" % [player.health, world.max_health])

	# در حالت مرگ نباید کار کند
	btn.reset()
	player.is_dead = true
	var dead_hp: int = player.health
	world._on_heal_button_pressed()
	await process_frame
	_ok("no heal while dead", player.health == dead_hp)

	print("
RESULT: ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)
