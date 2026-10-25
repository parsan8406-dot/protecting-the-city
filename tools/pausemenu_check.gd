extends SceneTree
## منوی توقف و صفحه‌ی پایانِ بازی سریع.

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

	var settings = root.get_node("/root/LocalSettings")
	var player = world.get_node("Player")
	var menu = world.get_node_or_null("QuickPlayMenu")
	var btn = world.get_node_or_null("UI/GameHUD/Root/PauseButton")
	_ok("pause button exists", btn != null)
	_ok("quick play has no settings button (pause only)",
		world.get_node_or_null("UI/GameHUD/Root/SettingsButton") == null)
	_ok("menu exists", menu != null)
	if menu == null:
		print("\nRESULT: FAIL"); quit(1); return
	_ok("menu starts hidden", not menu.visible)
	_ok("menu survives pause (PROCESS_MODE_ALWAYS)",
		menu.process_mode == Node.PROCESS_MODE_ALWAYS)
	_ok("pause button is excluded from the joystick",
		btn != null and btn.is_in_group("touch_exclude"))

	# --- توقف ---
	world._pause()
	await _wait(200)
	_ok("pressing pause freezes the game", paused)
	_ok("pause menu is shown", menu.visible)
	_ok("resume button is available when paused", menu._resume_btn.visible)
	_ok("title says paused", menu._title.text == "توقف", menu._title.text)
	_ok("stats are listed", menu._stats_box.get_child_count() >= 3,
		"rows=%d" % menu._stats_box.get_child_count())

	# --- تنظیمات ---
	var vol_before: int = settings.master_volume
	menu._toggle_settings()
	await process_frame
	_ok("settings panel opens", menu._settings_box.visible)
	_ok("stats hide while settings are open", not menu._stats_box.visible)
	# اولین اسلایدر = صدای اصلی
	var slider: HSlider = menu._settings_box.get_child(0).get_child(1)
	slider.value = 33
	await _wait(150)
	_ok("moving a slider saves the setting", settings.master_volume == 33,
		"master=%d (was %d)" % [settings.master_volume, vol_before])
	settings.set_audio("master", vol_before)
	menu._toggle_settings()

	# --- ادامه ---
	world._resume()
	await _wait(150)
	_ok("resume unfreezes the game", not paused)
	_ok("resume hides the menu", not menu.visible)

	# --- آمار واقعاً پر می‌شود؟ ---
	var bots: Array = world.get_tree().get_nodes_in_group("bots")
	if bots.is_empty():
		world._spawn_bot()
		await _wait(200)
		bots = world.get_tree().get_nodes_in_group("bots")
	bots[0].take_damage(30)
	await _wait(120)
	_ok("damage dealt is tracked", world._damage_dealt >= 30,
		"damage=%d" % world._damage_dealt)
	_ok("survival time is counted", world._alive_time > 0.5,
		"t=%.1f" % world._alive_time)

	# --- مرگ ---
	world._damage_local_player(9999)
	await _wait(400)
	_ok("death opens the menu", menu.visible)
	_ok("death menu hides the resume button", not menu._resume_btn.visible)
	_ok("death menu says you died", menu._title.text != "توقف", menu._title.text)
	# بعد از مرگ، دکمه‌ی توقف نباید صفحه‌ی پایان را با «توقف» عوض کند
	world._pause()
	await process_frame
	_ok("pause is ignored once dead", menu._title.text != "توقف" and not paused,
		"title=%s paused=%s" % [menu._title.text, paused])

	print("\nRESULT: ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)
