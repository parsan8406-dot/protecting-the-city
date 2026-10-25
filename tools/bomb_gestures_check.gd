extends SceneTree
## سه حالتِ واقعیِ پرتاب بمب را از راه پایپ‌لاینِ واقعیِ ورودی امتحان می‌کند.
##
## با پنجره اجرا شود، نه --headless: در حالتِ headless رویدادِ ورودی اصلاً به
## پنجره نمی‌رسد و همه‌چیز «شکست» می‌خورد.
##   godot --path . --resolution 1200x540 --script res://tools/bomb_gestures_check.gd

var failures := 0
func _ok(n: String, c: bool, d: String = "") -> void:
	if c: print("  PASS  ", n)
	else:
		failures += 1
		print("  FAIL  ", n, "   ", d)

func _wait(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame

## مختصاتِ داخلِ ویوپورت (بوم) → مختصاتِ پنجره. Input.parse_input_event
## جای لمس را به مختصاتِ پنجره می‌خواهد؛ با stretch این دو یکی نیستند و
## قبلاً لمس جای دیگری از صفحه می‌افتاد و به دکمه نمی‌رسید.
func _scr(p: Vector2) -> Vector2:
	return root.get_final_transform() * p

func _initialize() -> void:
	var world = load("res://secense/World.tscn").instantiate()
	root.add_child(world)
	await _wait(2500)

	var player = world.get_node("Player")
	var btn = world.bomb_button
	var js = world.get_node("UI/VirtualJoystick")
	var vp := root
	var ct := vp.get_canvas_transform()
	var centre: Vector2 = _scr(btn.get_global_rect().get_center())
	var max_range: float = float(world.my_stats.get("bomb_range", 380.0))
	print("max_range=", max_range, "  joystick idx=", js.touch_index)

	# ---------- ۱) کشیدن با یک انگشت ----------
	var wanted: Vector2 = player.global_position + Vector2(150, 0)
	var t := InputEventScreenTouch.new(); t.index = 0; t.pressed = true; t.position = centre
	Input.parse_input_event(t); await process_frame
	# دوربین روی بازیکن است و ممکن است همین فریم جابه‌جا شده باشد
	ct = vp.get_canvas_transform()
	wanted = player.global_position + Vector2(150, 0)
	var d := InputEventScreenDrag.new(); d.index = 0; d.position = _scr(ct * wanted)
	Input.parse_input_event(d); await process_frame
	_ok("single-finger drag aims at the finger",
		world.bomb_aim_positional and abs(world.bomb_aim_dist - 150.0) < 3.0,
		"positional=%s dist=%.1f" % [world.bomb_aim_positional, world.bomb_aim_dist])
	# رها کردن
	var u := InputEventScreenTouch.new(); u.index = 0; u.pressed = false; u.position = _scr(ct * wanted)
	Input.parse_input_event(u); await process_frame
	_ok("release ends aiming", not world.bomb_aiming)

	# ---------- ۲) ضربه‌ی ساده بدون دشمن ----------
	btn.reset()
	var t2 := InputEventScreenTouch.new(); t2.index = 0; t2.pressed = true; t2.position = centre
	Input.parse_input_event(t2); await process_frame
	var u2 := InputEventScreenTouch.new(); u2.index = 0; u2.pressed = false; u2.position = centre
	Input.parse_input_event(u2); await process_frame
	_ok("plain tap with no enemy still throws forward at max range",
		abs(world.bomb_aim_dist - max_range) < 1.0,
		"dist=%.1f" % world.bomb_aim_dist)

	# ---------- ۳) انگشتِ دوم، وقتی جوی‌استیک گرفته شده ----------
	# شمارش‌معکوسِ بمبِ قبلی ممکن است کمی بعد از reset دوباره شروع شود (پیامِ
	# ability)؛ در بازی درست است که وسطِ آن نشود پرتاب کرد، پس صبر می‌کنیم
	# تا دکمه واقعاً آماده بماند.
	for _i in 20:
		btn.reset()
		await _wait(50)
		if btn.is_ready() and not world.bomb_aiming:
			break
	js.touch_index = 0                      # انگشتِ چپ روی جوی‌استیک
	var t3 := InputEventScreenTouch.new(); t3.index = 1; t3.pressed = true; t3.position = centre
	Input.parse_input_event(t3); await process_frame
	if not world.bomb_aiming:               # لمسِ انگشتِ دوم به gui_input نمی‌رسد
		world._on_bomb_button_input(t3)     # همان کاری که دکمه می‌کرد
	# دوربین از اولِ تست تکان خورده؛ تبدیلِ بوم را همین لحظه دوباره بخوان
	ct = vp.get_canvas_transform()
	var wanted3: Vector2 = player.global_position + Vector2(0, -170)
	var d3 := InputEventScreenDrag.new(); d3.index = 1; d3.position = _scr(ct * wanted3)
	Input.parse_input_event(d3); await process_frame
	_ok("second finger (while joystick held) still aims",
		world.bomb_aim_positional and abs(world.bomb_aim_dist - 170.0) < 4.0,
		"positional=%s dist=%.1f" % [world.bomb_aim_positional, world.bomb_aim_dist])
	_ok("joystick's own drag is NOT stolen by the bomb aim",
		world.bomb_touch_index == 1, "bomb_touch_index=%d" % world.bomb_touch_index)

	print("\nRESULT: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
