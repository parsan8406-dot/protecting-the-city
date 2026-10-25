extends SceneTree
## بازیِ سریع را بالا می‌آورد و رفتار بات را زیر نظر می‌گیرد.

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

## نقطه‌ای در فاصله‌ی dist که خودش آزاد است و راهِ صافش تا بازیکن (با پهنای
## بدنِ بات) به چیزی نمی‌خورد؛ اگر هیچ جهتی نبود، همان جهتِ مرکزِ زمین.
func _clear_spot(player: Node2D, bot: Node2D, dist: float) -> Vector2:
	var space := player.get_world_2d().direct_space_state
	var skip := [player.get_rid(), bot.get_rid()]
	var from := player.global_position
	for i in 16:
		var dir := Vector2.RIGHT.rotated(TAU * i / 16.0)
		var spot := from + dir * dist
		var pq := PhysicsPointQueryParameters2D.new()
		pq.position = spot
		pq.exclude = skip
		if not space.intersect_point(pq, 1).is_empty():
			continue
		var side := dir.orthogonal() * 26.0
		var clear := true
		for off in [Vector2.ZERO, side, -side]:
			var rq := PhysicsRayQueryParameters2D.create(spot + off, from + off)
			rq.exclude = skip
			if not space.intersect_ray(rq).is_empty():
				clear = false
				break
		if clear:
			return spot
	return from + (Vector2(1000, 560) - from).normalized() * dist

func _initialize() -> void:
	var scene = load("res://secense/quick_play.tscn")
	_ok("quick_play.tscn loads", scene != null)
	if scene == null:
		quit(1); return
	var world = scene.instantiate()
	root.add_child(world)
	# تا تمام شدنِ _readyِ بازی سریع (منوی توقف آخرِ آن ساخته می‌شود) — نه
	# زمانِ ثابت: _ready یک تایمرِ ۱ ثانیه‌ای و بارگذاریِ زمین دارد و با ۲.۵
	# ثانیه‌ی ثابت فقط چند ده میلی‌ثانیه فاصله داشت
	var t0 := Time.get_ticks_msec()
	while world.get("_menu") == null and Time.get_ticks_msec() - t0 < 10000:
		await process_frame
	await _wait(300)
	# اتولودها قبل از اولین await هنوز ثبت نشده‌اند
	root.get_node("/root/Global").quick_play_difficulty = 1   # مقدارِ معلوم

	_ok("offline mode is on", root.get_node("/root/Global").offline_mode)
	var player = world.get_node("Player")
	_ok("player exists", player != null)
	_ok("HUD built (same as online)", world.combat_hud != null)
	_ok("kill counter shown under the timer", world.hud.round_hud._mode_label.text.begins_with("کشته"),
		world.hud.round_hud._mode_label.text)
	_ok("arena present", world.get_node_or_null("Arena") != null)
	_ok("player starts at full health offline", player.health == world.max_health,
		"hp=%d max=%d" % [player.health, world.max_health])

	# اولین بات بعد از ۳ ثانیه
	await _wait(2500)
	var bots: Array = world.get_tree().get_nodes_in_group("bots")
	_ok("a bot spawned", bots.size() >= 1, "count=%d" % bots.size())
	if bots.is_empty():
		print("\nRESULT: FAIL"); quit(1); return

	var bot = bots[0]
	_ok("bot targets the player", bot.target == player)
	# خودِ نقطه‌ی تولد را می‌سنجیم، نه جای فعلی — بات تا اینجا راه افتاده
	var spawn_pt: Vector2 = world._pick_spawn()
	_ok("spawn point is far from the player",
		spawn_pt.distance_to(player.global_position) > 300.0,
		"dist=%.0f" % spawn_pt.distance_to(player.global_position))
	_ok("bot has a weapon in hand", bot.get_node("gun").texture != null)
	_ok("bot has an upright plate", bot.get_node_or_null("FoePlate") != null)

	# --- از دور باید تعقیب کند تا برسد به بردِ نبرد ---
	# بات مسیریابی ندارد و مستقیم می‌دود، پس نقطه‌ای ۷۰۰ پیکسل دورتر
	# می‌خواهیم که خطِ صافش تا بازیکن به دیوار نخورد — وگرنه پشتِ دیوار گیر
	# می‌کند و تست به‌جای تعقیب، چیدمانِ نقشه را می‌سنجد.
	bot.global_position = _clear_spot(player, bot, 700.0)
	await _wait(400)
	var d0: float = bot.global_position.distance_to(player.global_position)
	_ok("far away the bot is chasing", bot._state == bot.State.CHASE,
		"state=%d dist=%.0f" % [bot._state, d0])
	await _wait(2000)
	var d1: float = bot.global_position.distance_to(player.global_position)
	_ok("bot closes in on the player", d1 < d0 - 100.0, "%.0f -> %.0f" % [d0, d1])

	# --- تیر خوردن باید جاخالی راه بیندازد ---
	var hp_before: int = bot.health
	bot.take_damage(20)
	await process_frame
	_ok("bot takes damage", bot.health == hp_before - 20, "hp=%d" % bot.health)
	_ok("bot dodges after being hit", bot._state == bot.State.DODGE,
		"state=%d" % bot._state)

	# --- جان کم → درمان یا فرار ---
	bot.health = int(bot.max_health * 0.25)
	bot._dodge_time = 0.0
	bot._heal_cd = 0.0
	bot._think_cd = 0.0
	var hurt: int = bot.health
	await _wait(500)
	# یا خودش را درمان کرده (جان بالا رفته) یا دارد عقب می‌کشد
	_ok("low HP makes the bot heal or flee",
		bot.health > hurt or bot._state == bot.State.FLEE,
		"state=%d hp=%d->%d" % [bot._state, hurt, bot.health])

	# --- بمب ---
	bot.health = bot.max_health
	bot._bomb_cd = 0.0
	bot.global_position = player.global_position + Vector2(200, 0)
	bot._dodge_time = 0.0
	bot._think_cd = 0.0
	# بات در حال حرکت است و ممکن است یک فریمِ خاص شرایطش جور نباشد؛
	# تا دو ثانیه فرصت می‌دهیم به‌جای یک نمونه‌ی لحظه‌ای.
	var threw := false
	for i in range(120):
		if bot._bomb_cd > 0.0:
			threw = true
			break
		await process_frame
	_ok("bot throws a bomb when in range", threw,
		"dist=%.0f los=%s state=%d" % [
			bot.global_position.distance_to(player.global_position),
			bot._has_line_of_sight(), bot._state])

	# --- بات به بازیکن خسارت می‌زند ---
	# اول بگذار بمبِ مرحله‌ی قبل منفجر شود و کارش تمام شود؛ وگرنه خسارتش
	# وسطِ اندازه‌گیری می‌نشیند (۱۵ + ۲۲ = ۳۷ و تست بی‌دلیل قرمز می‌شد).
	await _wait(int(world.BOMB_FUSE * 1000) + 800)
	# بات‌ها را هم لحظه‌ای ساکت کن، وگرنه تیرِ همزمانشان عدد را جابه‌جا می‌کند.
	var silenced := []
	for b in world.get_tree().get_nodes_in_group("bots"):
		if is_instance_valid(b):
			silenced.append(b)
			b.target = null
	await process_frame
	var php: int = player.health
	world._damage_local_player(15)
	await process_frame
	_ok("bot damage reaches the player", player.health == php - 15,
		"hp %d -> %d" % [php, player.health])
	var hud = world.combat_hud
	_ok("HUD reflects the player's real health",
		absf(hud._hp - float(player.health) / float(world.max_health)) < 0.01,
		"hud=%.3f expected=%.3f (%d/%d)" % [hud._hp,
			float(player.health) / float(world.max_health), player.health, world.max_health])

	for b in silenced:
		if is_instance_valid(b):
			b.target = player

	# --- مرگ بات باید شمارنده را بالا ببرد ---
	var kills_before: int = world._kills
	bot.take_damage(9999)
	await _wait(300)
	_ok("killing a bot bumps the counter", world._kills == kills_before + 1,
		"kills=%d" % world._kills)

	# --- آیا بازیکن هم می‌تواند جواب بدهد؟ ---
	# هدف‌گیریِ بازیکن خودکار است و فقط بدنه‌هایی را می‌بیند که در گروه
	# "enemy" باشند و داخلِ مخروطِ جلوی رویش بیفتند.
	# میدان را خلوت کن: با چند بات، بازیکن ممکن است به یکی دیگر بچرخد و
	# باتی که جلویش می‌گذاریم بیرونِ مخروطِ هدف‌گیری بیفتد.
	for b in world.get_tree().get_nodes_in_group("bots"):
		if is_instance_valid(b):
			b.queue_free()
	await _wait(300)
	world._spawn_bot()
	await _wait(300)
	var live = null
	for b in world.get_tree().get_nodes_in_group("bots"):
		if is_instance_valid(b) and not b.is_dead:
			live = b
	_ok("a live bot is available for the aim test", live != null)
	if live == null:
		print("\nRESULT: FAIL"); quit(1); return

	live.target = null                        # بات ساکت بماند تا فقط بازیکن سنجیده شود
	var fwd: Vector2 = Vector2.RIGHT.rotated(player.rotation - deg_to_rad(90))
	live.global_position = player.global_position + fwd * 130.0
	player.current_ammo = player.max_ammo
	player.is_dead = false
	live.health = live.max_health              # از صفرِ تمیز، وگرنه تست توخالی است
	var hp0: int = live.health
	# مخروطِ هدف‌گیری باریک است (حدود ±۱۴ درجه) و بازیکن هم می‌چرخد، پس یک
	# نمونه‌ی لحظه‌ای گمراه‌کننده است. در طول پنجره نمونه می‌گیریم: کافی است
	# یک بار وارد فهرست شود.
	var seen := false
	for i in range(120):
		if live in player.enemies_in_range:
			seen = true
			break
		await process_frame
	_ok("bot is targetable by the player", seen, "never entered enemies_in_range")

	await _wait(1500)
	# اگر بات در همین فاصله ناک‌اوت شده باشد نودش آزاد شده — یعنی قطعاً ضربه خورده
	var knocked_out := not is_instance_valid(live)
	_ok("player's auto-aim damages the bot", knocked_out or live.health < hp0,
		"bot hp %d -> %d" % [hp0, -1 if knocked_out else live.health])

	print("\nRESULT: ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)
