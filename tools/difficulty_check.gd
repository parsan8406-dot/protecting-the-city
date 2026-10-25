extends SceneTree
## سه سطحِ بازی سریع + صفحه‌ی انتخاب روی منوی اصلی.

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
	# ---------- صفحه‌ی انتخاب سطح ----------
	var menu = load("res://secense/main_menu.tscn").instantiate()
	root.add_child(menu)
	await _wait(1500)
	# اتولودها موقعِ _initialize هنوز ثبت نشده‌اند؛ بعد از اولین await هستند
	var g = root.get_node("/root/Global")
	menu._on_play_button_pressed()
	await _wait(400)
	var picker = menu.get_node_or_null("DifficultyPicker")
	_ok("difficulty picker opens from the play button", picker != null)
	if picker == null:
		print("\nRESULT: FAIL"); quit(1); return
	_ok("picker offers exactly three levels", picker.LEVELS.size() == 3)
	menu._on_play_button_pressed()
	await process_frame
	_ok("pressing play twice does not stack pickers",
		menu.get_children().filter(func(c): return c.name == "DifficultyPicker").size() == 1)
	picker.queue_free()
	menu.queue_free()
	await _wait(400)

	# ---------- خودِ سطح‌ها ----------
	var scene = load("res://secense/quick_play.tscn")
	var prev := {}
	for level in [0, 1, 2]:
		g.quick_play_difficulty = level
		var world = scene.instantiate()
		root.add_child(world)
		await _wait(2600)
		world._spawn_bot()
		await _wait(300)
		var bots: Array = world.get_tree().get_nodes_in_group("bots")
		if bots.is_empty():
			_ok("level %d spawns a bot" % level, false)
			world.queue_free()
			continue
		var b = bots[-1]
		print("    level %d -> hp=%d dmg=%d cd=%.2f miss=%.2f speed=%.0f pacing=%s"
			% [level, b.max_health, b.damage, b.fire_cooldown, b.miss_chance,
			   b.move_speed, str(world._pacing())])
		_ok("level %d bot starts at its own full health" % level,
			b.health == b.max_health, "hp=%d max=%d" % [b.health, b.max_health])
		_ok("level %d shows in the pause stats" % level,
			world._stats().has("سطح"), str(world._stats()))
		prev[level] = {
			"hp": b.max_health, "dmg": b.damage, "cd": b.fire_cooldown,
			"miss": b.miss_chance, "speed": b.move_speed,
			"gap": world._pacing()[0], "cap": world._pacing()[1],
		}
		world.queue_free()
		await _wait(400)

	if prev.size() == 3:
		_ok("harder levels hit harder", prev[0].dmg < prev[1].dmg and prev[1].dmg < prev[2].dmg)
		_ok("harder levels fire faster", prev[0].cd > prev[1].cd and prev[1].cd > prev[2].cd)
		_ok("harder levels are tougher", prev[0].hp < prev[1].hp and prev[1].hp < prev[2].hp)
		_ok("harder levels aim better", prev[0].miss > prev[1].miss and prev[1].miss > prev[2].miss)
		_ok("harder levels send more, sooner",
			prev[0].gap > prev[1].gap and prev[1].gap > prev[2].gap
			and prev[0].cap < prev[1].cap and prev[1].cap < prev[2].cap)
		# «یکم قوی‌تر»، نه کشنده: حتی سخت هم باید از بازیکن ضعیف‌تر بزند
		_ok("even hard hits softer than the player's own gun", prev[2].dmg < 25,
			"bot dmg=%d vs player 25" % prev[2].dmg)

	print("\nRESULT: ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)
