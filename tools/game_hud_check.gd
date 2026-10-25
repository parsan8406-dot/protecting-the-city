extends SceneTree
## HUDِ تازه‌ی زمینِ بازی: چیدمان روی پنج اندازه‌ی صفحه، دکمه‌های توانایی
## (آنلاین با پیام‌های شبیه‌سازی‌شده‌ی سرور، آفلاین با قانونِ خودِ بازی سریع)،
## اهداف، مینی‌مپ و تنظیمات.
##
##   Godot --path . --resolution 1200x540 -s tools/game_hud_check.gd
##
## پنجره نمی‌تواند از مانیتور بزرگ‌تر شود، ولی با stretch=canvas_items/expand
## چیدمان فقط به *نسبت* صفحه بستگی دارد؛ پس هر اندازه را با نصفِ ابعادش
## (همان نسبت) امتحان می‌کنیم و همه‌چیز را با ویوپورتِ واقعی می‌سنجیم.

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


const SIZES := [Vector2i(2400, 1080), Vector2i(2340, 1080), Vector2i(1920, 1080),
	Vector2i(1280, 720), Vector2i(2048, 1536)]
const KINDS := ["laser", "bomb", "sprint", "guard", "heal", "team_heal"]


func _initialize() -> void:
	await _online()
	await _offline()
	print("\nRESULT: ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)


# ================================================================ آنلاین

func _online() -> void:
	print("--- online (World.tscn) ---")
	var world = load("res://secense/World.tscn").instantiate()
	root.add_child(world)
	await _wait(1600)
	var net = root.get_node("/root/Network")
	var glob = root.get_node("/root/Global")
	var me: String = glob.my_username
	var hud = world.hud

	_ok("GameHUD built", hud != null)
	_ok("online shows the settings button", world.get_node_or_null("UI/GameHUD/Root/SettingsButton") != null)
	_ok("online has no pause button", world.get_node_or_null("UI/GameHUD/Root/PauseButton") == null)
	for k in KINDS:
		var b = hud.button(k)
		_ok("button %s exists and is excluded from the joystick" % k,
			b != null and b.is_in_group("touch_exclude"))
	_ok("no leftover chat/backpack/stats buttons",
		world.get_node_or_null("UI/HealButton") == null and world.get_node_or_null("UI/BombButton") == null)

	# --- چیدمان روی همه‌ی اندازه‌ها ---
	for sz in SIZES:
		root.size = sz / 2
		await _wait(120)
		# اندازه‌ها باید به واحدِ ویوپورت باشند (همان واحدی که دکمه‌ها با آن
		# چیده شده‌اند)، نه پیکسلِ پنجره — قبلاً ۲۴۰۰ با ۱۴۴۰ مقایسه می‌شد
		_check_layout(world, root.get_visible_rect().size, "%dx%d" % [sz.x, sz.y])

	root.size = Vector2i(960, 540)
	await _wait(120)

	# --- توانایی‌ها از راهِ پیامِ سرور ---
	net.ability_used.emit({"username": me, "kind": "guard", "active": 4.0, "cooldown": 22.0})
	await _wait(80)
	_ok("guard echo locks the shield button", not hud.button("guard").is_ready())
	_ok("guard makes me protected (bubble up)", world.is_protected(me))

	net.ability_used.emit({"username": me, "kind": "sprint", "active": 5.0, "cooldown": 20.0})
	await _wait(80)
	_ok("sprint raises my speed by 20%%", is_equal_approx(world.get_node("Player").speed_mult, 1.2),
		"mult=%.2f" % world.get_node("Player").speed_mult)
	_ok("sprint button shows active + lock", not hud.button("sprint").is_ready())

	net.ability_used.emit({"username": me, "kind": "laser", "active": 3.0, "cooldown": 25.0})
	await _wait(80)
	var beams := 0
	for c in world.get_children():
		if c.get_script() == preload("res://scripts/laser_beam.gd"):
			beams += 1
	_ok("laser echo draws a beam", beams == 1, "beams=%d" % beams)

	net.ability_used.emit({"username": me, "kind": "bomb", "active": 0.0, "cooldown": 5.0, "bombs_left": 2})
	await _wait(50)
	_ok("bomb echo updates the stock badge", world.bombs_left == 2 and hud.button("bomb").badge == 2)
	net.server_players_updated.emit({me: {"x": 500.0, "y": 400.0, "health": 100, "bombs_left": 1,
		"character": "skin_default", "weapon": "ak47"}})
	await _wait(50)
	_ok("update_players is the source of truth for bombs", world.bombs_left == 1)

	# --- اهداف ---
	net.objectives_received.emit([
		{"id": "daily:kill_10", "kind": "daily", "title": "۱۰ کیل داشته باشید", "target": 10, "progress": 3},
		{"id": "ranked:season_wins_10", "kind": "ranked", "title": "۱۰ برد تیمی", "target": 10, "progress": 1},
	])
	await _wait(600)
	var obj = hud.objectives
	_ok("objectives slide in", obj._rows.size() == 2 and obj._header.visible,
		"rows=%d" % obj._rows.size())
	net.objective_updated.emit("daily:kill_10", 10, 10, true)
	await _wait(100)
	_ok("completed objective gets checked", bool(obj._rows["daily:kill_10"].get_meta("done", false)))
	await _wait(int(obj.HOLD_DONE * 1000) + 700)
	_ok("completed objective leaves the screen", not obj._rows.has("daily:kill_10"))

	# --- تنظیمات ---
	world._on_menu_pressed()
	await _wait(50)
	_ok("settings open without pausing", world._settings.visible and not paused)
	_ok("joystick is off under the settings", not world.joystick.enabled)
	world._on_menu_pressed()
	await _wait(50)
	_ok("settings close again", not world._settings.visible and world.joystick.enabled)

	# --- مینی‌مپ ---
	var mm = hud.minimap
	_ok("minimap knows the arena and me", mm.arena != null and mm.me == world.get_node("Player"))

	world.queue_free()
	await _wait(200)


func _rect(c: Control) -> Rect2:
	return c.get_global_rect()


func _check_layout(world, vp: Vector2, tag: String) -> void:
	var hud = world.hud
	var screen := Rect2(Vector2.ZERO, vp)
	var rects := {}
	for k in KINDS:
		rects[k] = _rect(hud.button(k))
	rects["menu"] = _rect(world.get_node("UI/GameHUD/Root/SettingsButton"))

	var inside := true
	var small := ""
	for k in rects:
		if not screen.encloses(rects[k].grow(-1.0)):
			inside = false
		# ~۴۸dp: روی ارتفاعِ ۱۰۸۰ دستِ‌کم ۹۰ پیکسل
		if rects[k].size.x < vp.y * 0.083:
			small += "%s=%.0f " % [k, rects[k].size.x]
	_ok("[%s] every button is on screen" % tag, inside)
	_ok("[%s] every button is at least ~48dp" % tag, small == "", small)

	var overlap := ""
	var keys: Array = rects.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: Rect2 = rects[keys[i]]
			var b: Rect2 = rects[keys[j]]
			var ra := a.size.x * 0.5
			var rb := b.size.x * 0.5
			if a.get_center().distance_to(b.get_center()) < ra + rb + 4.0:
				overlap += "%s/%s " % [keys[i], keys[j]]
	_ok("[%s] buttons do not touch each other" % tag, overlap == "", overlap)

	var profile := _rect(hud.profile)
	var plate: Rect2 = _rect(hud.round_hud._panel)
	var mm := _rect(hud.minimap)
	var ping := _rect(hud._ping_box)
	_ok("[%s] profile card clear of the timer" % tag, not profile.intersects(plate),
		"profile=%s plate=%s" % [profile, plate])
	_ok("[%s] minimap clear of the timer" % tag, not mm.intersects(plate))
	_ok("[%s] ping clear of the timer" % tag, not ping.intersects(plate))
	_ok("[%s] timer centred" % tag, absf(plate.get_center().x - vp.x * 0.5) < 2.0)
	_ok("[%s] minimap above the skill buttons" % tag, mm.end.y < rects["bomb"].position.y)
	var js = world.joystick
	var jr: float = js.BASE_R * hud.ui_scale()
	var jc: Vector2 = js._rest
	_ok("[%s] joystick bottom-left and on screen" % tag,
		jc.x - jr >= 0.0 and jc.y + jr <= vp.y and jc.x < vp.x * 0.3 and jc.y > vp.y * 0.5)
	var potion_left: float = rects["team_heal"].position.x
	_ok("[%s] joystick clear of the potions" % tag, jc.x + jr < potion_left,
		"joy right=%.0f potion left=%.0f" % [jc.x + jr, potion_left])


# ================================================================ آفلاین

func _offline() -> void:
	print("--- offline (quick_play.tscn) ---")
	var world = load("res://secense/quick_play.tscn").instantiate()
	root.add_child(world)
	await _wait(2600)
	var player = world.get_node("Player")
	_ok("quick_play.gd compiled", "hud" in world)
	if not ("hud" in world):
		return
	var hud = world.hud
	_ok("quick play shows pause, not settings",
		world.get_node_or_null("UI/GameHUD/Root/PauseButton") != null
		and world.get_node_or_null("UI/GameHUD/Root/SettingsButton") == null)
	_ok("ping is hidden offline", not hud._ping_box.visible)

	# بات‌ها ساکت، تا فقط توانایی‌ها سنجیده شوند
	for b in world.get_tree().get_nodes_in_group("bots"):
		b.queue_free()
	world._spawn_timer = 999.0
	await _wait(100)

	# --- دویدن ---
	world._on_ability_button("sprint")
	await _wait(50)
	_ok("offline sprint: +20%% speed", is_equal_approx(player.speed_mult, 1.2))
	_ok("offline sprint: button locked", not hud.button("sprint").is_ready())

	# --- سپر ---
	world._on_ability_button("guard")
	var hp: int = player.health
	world._damage_local_player(30)
	await _wait(50)
	_ok("offline guard blocks damage", player.health == hp, "hp %d -> %d" % [hp, player.health])

	# --- درمانِ تیمی ---
	world._guard_until = 0.0
	world._on_ability_button("team_heal")
	await _wait(30)
	_ok("team heal at full health does nothing", hud.button("team_heal").is_ready())
	world._damage_local_player(40)
	var hurt: int = player.health
	world._on_ability_button("team_heal")
	await _wait(50)
	_ok("team heal heals", player.health > hurt, "hp %d -> %d" % [hurt, player.health])
	_ok("team heal locks for 20s", not hud.button("team_heal").is_ready())

	# --- بمب: فقط سه تا ---
	for i in 4:
		world._throw_bomb(Vector2.RIGHT, 200.0)
	_ok("only three bombs per game", world.bombs_left == 0 and hud.button("bomb").badge == 0,
		"left=%d" % world.bombs_left)
	await _wait(1500)   # ترکش‌ها منفجر شوند

	# --- لیزر: از بدن رد می‌شود، ۶۰٪ ---
	world._spawn_bot()
	world._spawn_bot()
	await _wait(100)
	var bots: Array = []
	for b in world.get_tree().get_nodes_in_group("bots"):
		if is_instance_valid(b) and not b.is_dead:
			bots.append(b)
	_ok("two bots for the laser test", bots.size() >= 2, "bots=%d" % bots.size())
	if bots.size() >= 2:
		for b in bots:
			b.target = null
			b.set_physics_process(false)
		player.set_physics_process(false)    # چرخش و جا ثابت بمانند
		# جایی از نقشه که جلویش تا ۳۰۰ پیکسل دیوار نیست
		var fx = root.get_node("/root/CombatFX")
		var clear := false
		var fwd := Vector2.RIGHT
		for p in world.get_node("Arena").spawn_points:
			for rot in [0.0, PI * 0.5, PI, PI * 1.5]:
				var d := Vector2.RIGHT.rotated(rot - PI * 0.5)
				var hit: Array = fx.resolve_hit(p, d, [player.get_rid(), bots[0].get_rid(), bots[1].get_rid()])
				if p.distance_to(hit[0]) > 300.0:
					player.global_position = p
					player.rotation = rot
					fwd = d
					clear = true
					break
			if clear:
				break
		bots[0].global_position = player.global_position + fwd * 120.0
		bots[1].global_position = player.global_position + fwd * 220.0
		await _wait(100)
		var h0: int = bots[0].health
		var h1: int = bots[1].health
		world._on_ability_button("laser")
		await _wait(3400)
		if clear:
			var lost0 := float(h0 - bots[0].health) / float(bots[0].max_health)
			var lost1 := float(h1 - bots[1].health) / float(bots[1].max_health)
			_ok("laser hits the first target ~60%%", lost0 > 0.55 and lost0 < 0.66, "%.2f" % lost0)
			_ok("laser pierces to the one behind", lost1 > 0.55 and lost1 < 0.66, "%.2f" % lost1)
		else:
			print("  SKIP  laser geometry (wall right in front of the spawn)")
		_ok("laser locks for its cooldown", not hud.button("laser").is_ready())
		player.set_physics_process(true)

	world.queue_free()
	await _wait(200)
