extends SceneTree
## دو چیز: بمبِ خودِ بازیکن در بازی سریع، و ساکت شدن بات‌ها بعد از مرگِ بازیکن.

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

	# ---------- ۱) بمبِ بازیکن ----------
	var bots: Array = world.get_tree().get_nodes_in_group("bots")
	if bots.is_empty():
		world._spawn_bot()
		await _wait(300)
		bots = world.get_tree().get_nodes_in_group("bots")
	var bot = bots[0]
	bot.target = null                      # بات دخالت نکند
	bot._bomb_cd = 999.0
	bot.global_position = player.global_position + Vector2(160, 0)
	bot.health = bot.max_health
	var hp_before: int = bot.health

	# دقیقاً همان مسیری که رها کردنِ دکمه‌ی بمب طی می‌کند
	world._throw_bomb(Vector2.RIGHT, 160.0)
	await _wait(int(world.BOMB_FUSE * 1000) + 700)
	_ok("player's bomb explodes and damages a bot in radius",
		bot.health < hp_before, "bot hp %d -> %d" % [hp_before, bot.health])

	# خارج از شعاع نباید آسیب ببیند
	bot.health = bot.max_health
	bot.global_position = player.global_position + Vector2(900, 0)
	var far_hp: int = bot.health
	world._throw_bomb(Vector2.RIGHT, 160.0)
	await _wait(int(world.BOMB_FUSE * 1000) + 700)
	_ok("bomb spares a bot outside the radius", bot.health == far_hp,
		"bot hp=%d" % bot.health)

	# ---------- ۲) بعد از مرگِ بازیکن ----------
	bot.target = player
	bot.global_position = player.global_position + Vector2(140, 0)
	bot._shot_cd = 0.0
	bot._bomb_cd = 0.0
	# بات باید بچرخد، کول‌داونش بگذرد و از شانسِ خطا هم رد شود؛ یک نمونه‌ی
	# ۶۰۰ میلی‌ثانیه‌ای برای این کافی نیست. تا ۴ ثانیه فرصت می‌دهیم.
	var hit := false
	for i in range(240):
		if player.health < world.max_health:
			hit = true
			break
		await process_frame
	_ok("bot shoots while the player is alive", hit,
		"player hp=%d after 4s" % player.health)

	world._damage_local_player(9999)
	await _wait(200)
	_ok("player is dead", player.is_dead)

	var hp_at_death: int = player.health
	bot._shot_cd = 0.0
	bot._bomb_cd = 0.0
	await _wait(2000)
	_ok("bot stops shooting a dead player", player.health == hp_at_death,
		"hp %d -> %d" % [hp_at_death, player.health])
	_ok("bot stands still once the player is down",
		bot.velocity.length() < 1.0, "vel=%.1f" % bot.velocity.length())
	_ok("bot did not throw a bomb at a corpse", bot._bomb_cd <= 0.01,
		"bomb_cd=%.2f" % bot._bomb_cd)

	print("\nRESULT: ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)
