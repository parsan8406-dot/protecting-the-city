extends Node
## کلِ آموزشِ بارِ اول را قدم‌به‌قدم جلو می‌برد و از هر قدم عکس می‌گیرد.
##
## صحنه‌ها را خودش جای current_scene می‌گذارد (همان کاری که change_scene
## می‌کند) تا این نود زنده بماند؛ لمس‌ها و خبرهای صحنه هم مستقیم به Tutorial
## داده می‌شوند.
##
##   godot --path . res://tools/tutorial_shot.tscn --resolution 1600x720 -- --out=C:/tmp/tut

var _out := ""
var _scene: Node = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	Tutorial.reset()
	# autoload قبل از reset خوانده شده؛ از نو شروعش کن
	Tutorial.set("_running", true)
	if Tutorial.get("_root") == null:
		Tutorial.call("_build")
	Tutorial.set_process(true)
	_run()


func _run() -> void:
	await _until(func(): return not LoadingScreen.is_active(), 60.0)
	_swap("res://secense/main_menu.tscn")
	await _until(func(): return Tutorial.get("_scene_ready"), 30.0)
	await _shot("00_hello", 2.2)
	await _tap()
	await _shot("01_intro", 2.5)
	await _tap()
	await _shot("02_select_btn", 2.5)

	_swap("res://secense/character_select_screen.tscn")
	await _until(func(): return Tutorial.get("_scene_ready"), 30.0)
	await _shot("03_cards", 3.0)
	Tutorial.notify("character_picked")
	await _shot("04_char_ok", 2.0)
	await _tap()
	await _shot("05_weapon_tab", 2.0)
	_scene.call("_switch_category", "weapon", true)
	await _shot("06_pick_weapon", 2.5)
	Tutorial.notify("weapon_picked")
	await _shot("07_home", 2.5)

	_swap("res://secense/main_menu.tscn")
	await _until(func(): return Tutorial.get("_scene_ready"), 30.0)
	await _shot("08_play", 2.5)

	Global.quick_play_difficulty = 0
	_swap("res://secense/quick_play.tscn")
	await _until(func(): return Tutorial.get("_scene_ready"), 30.0)
	await _shot("09_game", 2.5)
	for name in ["10_health", "11_ammo", "12_laser", "13_team", "14_team_heal", "15_bomb", "16_guard", "17_joystick"]:
		await _tap()
		await _shot(name, 2.8)
	var j = _scene.get("joystick")
	print("TUT joystick enabled=", j.get("enabled"))
	j.set("joystick_vector", Vector2(1, 0))
	await get_tree().create_timer(1.8).timeout
	j.set("joystick_vector", Vector2.ZERO)
	await _shot("18_done", 2.5)
	await _tap()
	await _shot("19_after", 2.5)
	print("TUT running=", Tutorial.is_running(), " visible=", Tutorial.visible)
	print("TUT OK")
	get_tree().quit(0)


func _swap(path: String) -> void:
	if _scene != null:
		_scene.queue_free()
	_scene = load(path).instantiate()
	get_tree().root.add_child(_scene)
	get_tree().current_scene = _scene


func _tap() -> void:
	# اول تایپ تمام شود، بعد لمس برای رفتن به جمله‌ی بعد
	await _until(func(): return not Tutorial.get("_typing") and Tutorial.get("_input_lock") <= 0.0, 10.0)
	Tutorial.call("_on_tap")


func _shot(name: String, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	print("TUT step=", Tutorial.get("_step"), " ", name)
	if _out != "":
		get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_out, name])


func _until(cond: Callable, timeout: float) -> void:
	var t := 0.0
	while not cond.call() and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()
