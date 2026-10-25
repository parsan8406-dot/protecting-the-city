extends SceneTree
## عکس از HUDِ تازه‌ی زمینِ بازی در یک اندازه‌ی دلخواهِ صفحه — بدون سرور.
##
## صحنه داخلِ یک SubViewport به همان اندازه ساخته می‌شود، پس پنجره‌ی خودِ
## گودوت هر اندازه‌ای باشد مهم نیست. پیام‌های سرور (پینگ، اهداف، وضعیتِ
## راند، توانایی‌ها) شبیه‌سازی می‌شوند تا همه‌ی حالت‌ها در عکس دیده شوند.
##
##   Godot --path . -s tools/hud_shot.gd -- --size=2400x1080 --out=C:/tmp/hud
##   (--scene=res://secense/quick_play.tscn برای بازیِ سریع)

var _size := Vector2i(1920, 1080)
var _out := "user://hud_shot"
var _scene := "res://secense/World.tscn"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			var p := a.substr(7).split("x")
			_size = Vector2i(int(p[0]), int(p[1]))
		elif a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--scene="):
			_scene = a.substr(8)

	var sv := SubViewport.new()
	sv.size = _size
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var world = load(_scene).instantiate()
	sv.add_child(world)

	await _frames(90)
	var net = root.get_node("/root/Network")
	var glob = root.get_node("/root/Global")
	var me: String = glob.my_username
	var p: Vector2 = world.get_node("Player").global_position

	if not glob.offline_mode:
		glob.my_team = "0"
		world._on_players_updated({
			me: {"x": p.x, "y": p.y, "health": 90, "team": "0", "bombs_left": 2,
				"character": "skin_default", "weapon": "ak47"},
			"Ally_1": {"x": p.x - 160, "y": p.y + 40, "health": 70, "team": "0",
				"character": "skin_girl", "weapon": "mp5"},
			"Enemy_1": {"x": p.x + 260, "y": p.y - 120, "health": 100, "team": "1",
				"character": "skin_devil", "weapon": "awm"},
			"Enemy_far": {"x": p.x + 1600, "y": p.y, "health": 100, "team": "1",
				"character": "skin_joker", "weapon": "ak47"},
		})
		net.round_info = {"score_kills": false}
		net.round_state_updated.emit({"0": 4, "1": 3}, 178)
		net.ping_measured.emit(48)
		net.objectives_received.emit([
			{"id": "daily:kill_10", "kind": "daily", "title": "تمام دشمنان را از بین ببرید", "target": 10, "progress": 6},
			{"id": "daily:heal_10", "kind": "daily", "title": "۱۰ بار هم‌تیمی را درمان کنید", "target": 10, "progress": 2},
			{"id": "ranked:season_flawless_15", "kind": "ranked", "title": "(رنک) بازی بدون مرگ", "target": 15, "progress": 4},
		])
		net.ability_used.emit({"username": me, "kind": "guard", "active": 4.0, "cooldown": 22.0})
		net.ability_used.emit({"username": me, "kind": "sprint", "active": 0.0, "cooldown": 14.0})
		net.ability_used.emit({"username": "Enemy_1", "kind": "laser", "active": 3.0, "cooldown": 25.0})
		world.update_player_health_ui(90, world.max_health)
	else:
		world._on_ability_button("guard")

	await _frames(50)
	var img: Image = sv.get_texture().get_image()
	var path := "%s_%dx%d.png" % [_out, _size.x, _size.y]
	print("HUD SHOT ", path, " err=", img.save_png(path))
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
