extends SceneTree
## بازیِ سریعِ دورِ دوم: مسیریابیِ بات، تیپ‌ها، موج‌ها، صندوقِ تدارکات،
## سختیِ نامرئی، رکورد و آیکنِ اعلان‌ها.
##
##   godot --headless --path . -s res://tools/psych_play_check.gd -- --server=http://127.0.0.1:8791
## با --shot=<پوشه> (بدونِ headless) یک عکس از اعلانِ «دوتایی» هم می‌گیرد.

var bad := 0
var _shot_dir := ""

func _ok(n: String, c: bool, d: String = "") -> void:
	if c: print("  PASS  ", n)
	else:
		bad += 1
		print("  FAIL  ", n, "  ", d)

func _wait(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame


func _silence_all(world) -> void:
	for b in world.get_tree().get_nodes_in_group("bots"):
		if is_instance_valid(b):
			b.queue_free()


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_dir = a.substr(7)
	var scene = load("res://secense/quick_play.tscn")
	var world = scene.instantiate()
	root.add_child(world)
	var t0 := Time.get_ticks_msec()
	while world.get("_menu") == null and Time.get_ticks_msec() - t0 < 10000:
		await process_frame
	await _wait(200)
	var g = root.get_node("/root/Global")
	g.quick_play_difficulty = 1
	var player = world.get_node("Player")
	var director = world.director
	_ok("director exists", director != null)
	# کارگردان را موقتاً از کار می‌اندازیم تا تست‌ها بات‌های خودشان را بسازند
	director.set_process(false)

	# ---------------- مسیریابی ----------------
	var nav = world.bot_nav()
	_ok("nav grid built from the arena", nav != null and nav.is_ready())
	var arena = world.get_node("Arena")
	# یک جفت نقطه‌ی آزاد که خطِ صافشان از دیوار رد می‌شود
	var space = player.get_world_2d().direct_space_state
	var pair := []
	var pts: Array = arena.spawn_points
	for i in pts.size():
		for j in pts.size():
			if i == j or not pair.is_empty():
				continue
			var q := PhysicsRayQueryParameters2D.create(pts[i], pts[j])
			q.collision_mask = 1
			q.exclude = [player.get_rid()]
			if not space.intersect_ray(q).is_empty() and pts[i].distance_to(pts[j]) > 300.0 \
					and pts[i].distance_to(pts[j]) < 900.0:
				pair = [pts[i], pts[j]]
	_ok("found two spawn points with a wall between", not pair.is_empty())
	if not pair.is_empty():
		var path: PackedVector2Array = nav.path(pair[0], pair[1])
		_ok("path exists around the wall", path.size() >= 2, "len=%d" % path.size())
		var all_free := true
		for p in path:
			if arena.is_blocked(p):
				all_free = false
		_ok("path waypoints are never inside a wall", all_free)

		# بات پشتِ دیوار: باید راه پیدا کند و نزدیک شود (قبلاً گیر می‌کرد)
		_silence_all(world)
		await _wait(200)
		player.global_position = pair[1]
		var bot = world._spawn_bot("soldier")
		await process_frame
		bot.global_position = pair[0]
		var d0: float = bot.global_position.distance_to(player.global_position)
		var best := d0
		var saw := false
		for i in 360:   # تا ۶ ثانیه
			await physics_frame
			if not is_instance_valid(bot):
				break
			best = minf(best, bot.global_position.distance_to(player.global_position))
			if bot._los:
				saw = true
		_ok("a bot behind a wall finds a way (gets line of sight or closes in)",
			saw and best < d0 - 150.0, "d0=%.0f best=%.0f los=%s" % [d0, best, saw])
		_silence_all(world)
		await _wait(200)

	# ---------------- تیپ‌ها ----------------
	var soldier = world._spawn_bot("soldier")
	var rusher = world._spawn_bot("rusher")
	var marks = world._spawn_bot("marksman")
	await process_frame
	_ok("three personalities spawn", soldier != null and rusher != null and marks != null)
	if soldier != null and rusher != null and marks != null:
		_ok("rusher is faster and frailer than a soldier",
			rusher.move_speed > soldier.move_speed and rusher.max_health < soldier.max_health)
		_ok("rusher keeps closer, marksman further",
			rusher.keep_distance < soldier.keep_distance and marks.keep_distance > soldier.keep_distance)
		_ok("marksman hits harder but slower", marks.damage > soldier.damage and marks.fire_cooldown > soldier.fire_cooldown)
		_ok("no bot outguns the player's own 25 damage", marks.damage < 25, "dmg=%d" % marks.damage)
		_ok("personality shows in the weapon", rusher._weapon_id == "mp5" and marks._weapon_id == "m24sws",
			"%s / %s" % [rusher._weapon_id, marks._weapon_id])
		_ok("personality has its own name", rusher.display_name() != soldier.display_name())
		# C5 کمکِ نامرئی: نرم‌تر یعنی خطای بیشتر و شلیکِ کندتر — خسارت دست نمی‌خورد
		var m0: float = soldier.miss_chance
		var c0: float = soldier.fire_cooldown
		var dmg0: int = soldier.damage
		soldier.set_assist(1.0)
		_ok("assist eases aim and rhythm, never damage",
			soldier.miss_chance > m0 and soldier.fire_cooldown > c0 and soldier.damage == dmg0)
		soldier.set_assist(-0.6)
		_ok("negative assist sharpens", soldier.miss_chance < m0 and soldier.fire_cooldown < c0)
		soldier.set_assist(0.0)
		# پایه‌ی واقعی، نه m0: کارگردان ممکن است از اجراهای قبلی (psych_play.cfg)
		# با کمکِ غیرصفر شروع کرده باشد و m0 همان مقدارِ کمک‌خورده باشد
		_ok("assist 0 restores the base",
			is_equal_approx(soldier.miss_chance, clampf(soldier._base_miss, 0.03, 0.6)))
		var elite = null
		var soldier_hp: int = soldier.max_health
		_silence_all(world)
		await _wait(200)
		elite = world._spawn_bot("soldier", true)
		await process_frame
		_ok("elite is tougher", elite != null and elite.max_health > soldier_hp * 1.5)

	# ---------------- بمبِ بات کیلِ بازیکن نیست ----------------
	_silence_all(world)
	await _wait(200)
	var victim = world._spawn_bot("soldier")
	await process_frame
	var k0: int = world._kills
	victim.take_damage(9999, false)
	await _wait(100)
	_ok("a bot killed by another bot's bomb is not the player's kill", world._kills == k0,
		"kills %d -> %d" % [k0, world._kills])

	# ---------------- سختیِ نامرئی (C5) ----------------
	_silence_all(world)
	await _wait(200)
	var b2 = world._spawn_bot("soldier")
	await process_frame
	b2.target = null
	director._bias = 0.0
	director.assist = 0.0
	player.health = int(world.max_health * 0.25)
	director.note_player_hurt(int(world.max_health * 0.6))
	for i in 5:
		director._update_assist(player)
	_ok("under pressure the director quietly eases", director.assist > 0.3, "assist=%.2f" % director.assist)
	_ok("and the live bots follow", b2._assist > 0.3, "bot=%.2f" % b2._assist)
	player.health = world.max_health
	director._hurt.clear()
	for i in 3:
		director.note_kill()
	for i in 12:
		director._update_assist(player)
	_ok("dominating sharpens the bots", director.assist < 0.0, "assist=%.2f" % director.assist)
	director.assist = 0.0

	# ---------------- موج و صندوق (C6/E2) ----------------
	_silence_all(world)
	await _wait(300)
	director.wave = 0
	director._phase = director.Phase.INTRO
	director._timer = 0.05
	director._announced = false
	director.set_process(true)
	await _wait(400)
	_ok("wave 1 is announced", director.wave == 1 and world.feel._co_title.text.find("موج") >= 0,
		"wave=%d title=%s" % [director.wave, world.feel._co_title.text])
	_ok("HUD label shows the wave", world.hud.round_hud._mode_label.text.find("موج") >= 0,
		world.hud.round_hud._mode_label.text)
	# همه‌ی بات‌های موج را فوراً بساز و بکش
	var guard := 0
	while director._phase == director.Phase.FIGHT and guard < 400:
		guard += 1
		director._timer = 0.0
		for b in world.get_tree().get_nodes_in_group("bots"):
			if is_instance_valid(b) and not b.is_dead:
				b.take_damage(9999)
		await process_frame
	_ok("killing the whole wave clears it", director._phase == director.Phase.BREATHER,
		"phase=%d spawned=%d/%d" % [director._phase, director._spawned, director._wave_size])
	await _wait(200)
	var crate = director._supply
	_ok("a supply crate drops at the end of the wave", crate != null and is_instance_valid(crate))
	if crate != null and is_instance_valid(crate):
		var cpos: Vector2 = crate.global_position
		_ok("the crate lands somewhere open", not arena.is_blocked(cpos))
		_ok("the crate is not under the player",
			cpos.distance_to(player.global_position) > 200.0, "d=%.0f" % cpos.distance_to(player.global_position))
		player.health = int(world.max_health * 0.4)
		world.update_player_health_ui(player.health, world.max_health)
		player.current_ammo = 0
		var hp_before: int = player.health
		var cd_before: float = player.fire_cooldown
		var bombs_before: int = world.bombs_left
		var spd_before: float = player.speed_mult
		player.global_position = cpos
		await _wait(300)
		_ok("walking onto the crate collects it", not is_instance_valid(crate) or crate._done)
		var got: bool = player.health > hp_before or player.fire_cooldown < cd_before \
			or world.bombs_left > bombs_before or player.speed_mult > spd_before
		_ok("the crate grants a real buff", got, "hp %d->%d cd %.2f->%.2f bombs %d->%d" % [
			hp_before, player.health, cd_before, player.fire_cooldown, bombs_before, world.bombs_left])
		_ok("the supply callout shows", world.feel._co_icon.visible and world.feel._co_icon.texture != null)
	# رگبار برمی‌گردد
	world._grant_supply("rapid")
	var fast: float = player.fire_cooldown
	world._rapid_left = 0.05
	await _wait(200)
	_ok("rapid fire wears off", player.fire_cooldown > fast, "%.2f -> %.2f" % [fast, player.fire_cooldown])

	# ---------------- اعلان‌های کیل: آیکنِ آرت ----------------
	director.set_process(false)
	_silence_all(world)
	await _wait(200)
	var feel = world.feel
	feel._co_left = 0.0
	feel._multi = 0
	feel._last_kill_ms = -100000
	feel._kills_life = 0
	feel.on_local_kill("", player.global_position, false)
	feel.on_local_kill("", player.global_position, false)
	await process_frame
	_ok("double-kill callout uses the streak_double art",
		feel._co_icon.visible and feel._co_icon.texture != null
		and feel._co_icon.texture.resource_path.ends_with("streak_double.png"),
		str(feel._co_icon.texture.resource_path if feel._co_icon.texture else "none"))
	if _shot_dir != "":
		await _wait(350)
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(_shot_dir.path_join("callout_double.png"))
		var r: Rect2 = feel._co_icon.get_global_rect()
		var s: float = feel._stage.scale.x
		print("ICON_RECT %d %d %d %d" % [int(r.position.x), int(r.position.y), int(r.size.x * s), int(r.size.y * s)])

	# ---------------- رکورد و صفحه‌ی پایان (E4/E5/C10) ----------------
	var cfg_path: String = director.SAVE_PATH
	var backup := ""
	if FileAccess.file_exists(cfg_path):
		backup = FileAccess.get_file_as_string(cfg_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg_path))
	director.wave = 3
	var r1: Dictionary = director.finish_run(6)
	_ok("first run is not a fake 'new record'", not r1["new_record"])
	director.wave = 4
	var r2: Dictionary = director.finish_run(9)
	_ok("beating it is a new record", r2["new_record"])
	director.wave = 4
	var r3: Dictionary = director.finish_run(7)
	_ok("near miss is spelled out", str(r3["near"]) != "", str(r3))
	director.wave = 1
	director.finish_run(0)
	director.wave = 1
	director.finish_run(1)
	_ok("two quick losses ease the next run quietly", director._history_bias() > 0.0)
	# فایلِ رکوردِ واقعیِ کاربر برگردد
	if backup != "":
		var f := FileAccess.open(cfg_path, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg_path))

	world._menu.open_game_over(world._stats(), {"new_record": true, "wave": 4, "kills": 9,
		"tip": feel.death_tip(), "best_multi": 2})
	await process_frame
	_ok("game over shows the run highlight", world._menu._run_box.visible and world._menu._run_box.get_child_count() >= 2)
	_ok("restart is the one primary button", world._menu._restart_btn.custom_minimum_size.y > 50.0)
	_ok("pause stats include the wave", world._stats().has("موج"))

	print("\nRESULT: ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)
