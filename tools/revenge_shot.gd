extends Node
## چکِ واقعیِ «عملیات انتقام»: زمینِ خودش، ریسپاون، و گنبدِ محافظِ تولد.
##
## World.tscn را همان‌طور که خودِ بازی بالا می‌آورد لود می‌کند. قبل از اجرا باید
## اکانتِ همین کلاینت با HTTP وارد صفِ حالتِ revenge شده و مسابقه‌اش جور شده
## باشد، وگرنه سرور مسابقه‌ای برایش ندارد.
##
##   godot --path . res://tools/revenge_shot.tscn --resolution 1280x720 \
##         --username=RevTester -- --out=C:/tmp/revenge --seconds=30
##
## چه چیزی را ثابت می‌کند:
##   REV arena=revenge          سرور زمینِ انتقام را اعلام کرده و کلاینت همان را کشیده
##   REV respawn <user> ...     مرگ موقتی بوده و سرور بازیکن را برگردانده
##   REV shields=[...]          گنبدِ محافظ روی همان بازیکنِ تازه‌متولد نشسته
##   REV round ... score=...    امتیاز کشته‌محور است، نه زنده‌محور

const WORLD := "res://secense/World.tscn"

var _root: Node = null
var _out := ""
var _limit := 30.0
var _t := 0.0
var _next_shot := 0
var _shot_at := [4.0, 14.0, 24.0]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--seconds="):
			_limit = float(a.substr(10))

	Network.arena_assigned.connect(func(map_name: String, shield: float, theme: String) -> void:
		print("REV arena=", map_name, " spawn_shield=", shield, " theme=", theme))
	Network.player_respawned.connect(
		func(user: String, pos: Vector2, hp: int, shield: float) -> void:
			print("REV respawn user=", user, " pos=", pos, " hp=", hp, " shield=", shield))
	Network.player_died.connect(func(user: String) -> void:
		print("REV died user=", user))
	Network.round_state_updated.connect(func(alive: Dictionary, secs: int) -> void:
		print("REV round alive=", alive, " secs=", secs,
			" score=", Network.round_info.get("score", {}),
			" respawn=", Network.round_info.get("respawn", false),
			" by_kills=", Network.round_info.get("score_kills", false)))
	Network.match_over.connect(func(winner: String, draw: bool) -> void:
		print("REV over winner=", winner, " draw=", draw,
			" score=", Network.round_info.get("final_score", {})))

	_root = load(WORLD).instantiate()
	add_child(_root)
	print("REV harness loaded World.tscn as ", Global.my_username)


func _process(delta: float) -> void:
	_t += delta
	if _next_shot < _shot_at.size() and _t >= float(_shot_at[_next_shot]):
		_next_shot += 1
		_snapshot(_next_shot)
	if _t >= _limit:
		print("REV DONE")
		get_tree().quit(0)


func _snapshot(index: int) -> void:
	var arena_node := _root.get_node_or_null("Arena")
	var map_name := "?"
	var walls := 0
	if arena_node != null:
		map_name = str(arena_node.map_name)
		walls = int(arena_node.get("_rects").size())

	var spawned: Dictionary = _root.get("spawned_players")
	var names := []
	for k in spawned.keys():
		names.append(k)
	names.sort()

	var shields := []
	var shield_dict: Dictionary = _root.get("_shields")
	for user in shield_dict.keys():
		var s = shield_dict[user]
		if s != null and is_instance_valid(s) and s.seconds_left() > 0.0:
			shields.append("%s:%.1f" % [user, s.seconds_left()])
	shields.sort()

	var me := _root.get_node_or_null("Player")
	var dead := false
	if me != null and "is_dead" in me:
		dead = bool(me.is_dead)

	print("REV t=%.1f map=%s walls=%d players=%d %s" % [_t, map_name, walls, names.size(), names])
	print("REV t=%.1f me_dead=%s shields=%s" % [_t, dead, shields])

	if _out == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	print("REV shot%d err=%d" % [index, img.save_png("%s_%d.png" % [_out, index])])
