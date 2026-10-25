extends SceneTree
## بررسی «شلیکِ پشتِ‌سرِ‌هم»: بازیکن باید تا وقتی حریف در دیدرس است با
## ریتمِ خودِ سلاح رگبار بزند — نه یک تیر و بعد سکوت.
##
## صحنه‌ی واقعیِ بازی (World.tscn) بالا می‌آید، یک حریف جلوی بازیکن گذاشته
## می‌شود و شمرده می‌شود که در یک ثانیه چند فشنگ خرج شد. انتظار: نزدیکِ
## ۱÷fire_cooldown.
##
## اجرا:
##   godot --headless --path . --script tools/autofire_check.gd

var bad := 0


func _ok(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  PASS  ", name)
	else:
		bad += 1
		print("  FAIL  ", name, "  ", detail)


func _initialize() -> void:
	# سروری در کار نیست: کلاینت خودش داورِ خسارت است و چیزی نمی‌فرستد.
	# اتولودها موقعِ کامپایلِ همین اسکریپت هنوز ثبت نشده‌اند، پس Global
	# باید از روی درختِ صحنه گرفته شود، نه با نامِ مستقیم.
	var g = root.get_node_or_null("Global")
	if g != null:
		g.offline_mode = true
		g.my_username = "autofire_probe"

	var world = load("res://secense/World.tscn").instantiate()
	root.add_child(world)
	var player = world.get_node("Player")
	# World صحنه‌ی آنلاین است و بازیکن با پیامِ spawnِ سرور جا می‌افتد (نه
	# بعد از زمانِ ثابت). اگر حریف قبل از آن گذاشته شود، بازیکن بعداً به
	# نقطه‌ی شروعِ دیگری می‌پرد و حریف بیرونِ دیدش می‌ماند.
	await _wait(200)
	var start_pos: Vector2 = player.global_position
	var t0 := Time.get_ticks_msec()
	while player.global_position.distance_to(start_pos) < 1.0 			and Time.get_ticks_msec() - t0 < 8000:
		await process_frame
	await _wait(400)

	player.show()
	player.is_dead = false
	player.rotation = 0.0

	# حریف، درست جلوی بازیکن (مخروطِ دید رو به بالای محلی است)
	var foe = load("res://secense/player_s.tscn").instantiate()
	world.add_child(foe)
	foe.username = "dummy"
	foe.global_position = player.global_position + Vector2(0, -110)
	foe.target_position = foe.global_position
	foe.setup_appearance("skin_default", "ak47")
	foe.set_max_health(9999)
	foe.set_team(false)
	await _wait(700)

	_ok("foe is inside the detection cone", player.enemies_in_range.has(foe),
		"targets=%d" % player.enemies_in_range.size())
	_ok("the player locked onto the foe", player._locked_target == foe,
		str(player._locked_target))

	# --- ریتمِ شلیک ---
	for cooldown in [0.36, 0.12]:
		player.fire_cooldown = cooldown
		player.miss_chance = 0.0
		player.max_ammo = 200
		player.current_ammo = 200
		player.rotation = 0.0
		await _wait(400) # چرخش به سمتِ هدف تمام شود

		var before: int = player.current_ammo
		await _wait(1000)
		var shots: int = before - player.current_ammo
		var want := int(round(1.0 / cooldown))
		# ±۲ تیر رواداری برای گِردِ فریم‌ها
		_ok("fires ~%d shots/s at cooldown %.2f" % [want, cooldown],
			abs(shots - want) <= 2, "got %d" % shots)

	# --- قفل باید وسطِ حرکت هم نگه دارد ---
	var joy = world.get_node_or_null("UI/VirtualJoystick")
	if joy != null:
		joy.joystick_vector = Vector2(1, 0) # حرکتِ عمود بر خطِ دید
		await _wait(500)
		var to_foe: float = (foe.global_position - player.global_position).angle() + deg_to_rad(90)
		var off: float = absf(wrapf(to_foe - player.rotation, -PI, PI))
		_ok("keeps aiming at the foe while strafing", off < deg_to_rad(25),
			"off=%.1f deg" % rad_to_deg(off))
		joy.joystick_vector = Vector2.ZERO

	# --- خشابِ خالی خودش پر شود ---
	# حریف را برمی‌داریم، وگرنه بازیکن بلافاصله بعد از پر شدن دوباره
	# شروع می‌کند به خالی کردنِ خشاب و عدد هیچ‌وقت سرِ جایش دیده نمی‌شود
	foe.queue_free()
	await _wait(300)
	player.reload_seconds = 0.4
	player.max_ammo = 8
	player.current_ammo = 0
	await _wait(900)
	_ok("an empty magazine reloads itself", player.current_ammo == 8,
		"ammo=%d" % player.current_ammo)

	print("\nRESULT: ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)


func _wait(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame
