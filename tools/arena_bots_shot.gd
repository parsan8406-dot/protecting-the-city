extends Node
## چکِ واقعی: آیا بات‌ها در زمینِ بازی اسپان می‌شوند؟
##
## World.tscn را همان‌طور که خودِ بازی بالا می‌آورد لود می‌کند. قبل از اجرا
## باید اکانتِ همین کلاینت با HTTP وارد صف شده و مسابقه‌اش جور شده باشد،
## وگرنه سرور مسابقه‌ای برایش ندارد و طبیعتاً باتی هم نمی‌سازد.
##
##   godot --path . res://tools/arena_bots_shot.tscn --resolution 1280x720 -- --out=C:/tmp/arena

const WORLD := "res://secense/World.tscn"

var _root: Node = null
var _out := ""
var _frames := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	Network.round_state_updated.connect(func(alive: Dictionary, secs: int) -> void:
		print("BOTS round_state alive=", alive, " secs=", secs))
	Network.match_over.connect(func(winner: String, draw: bool) -> void:
		print("BOTS match_over winner=", winner, " draw=", draw))
	_root = load(WORLD).instantiate()
	add_child(_root)
	print("BOTS harness loaded World.tscn as ", Global.my_username)


func _process(_delta: float) -> void:
	_frames += 1
	# ~۵ ثانیه صبر: یک ثانیه‌اش تایمرِ خودِ world.gd است، بقیه برای رفت‌وبرگشتِ
	# join و رسیدنِ update_players
	if _frames != 45:
		return

	var spawned: Dictionary = _root.get("spawned_players")
	var names := []
	for k in spawned.keys():
		names.append(k)
	names.sort()
	print("BOTS my_team=", Global.my_team)
	# هم‌تیمی‌ها باید آبی و حریف‌ها قرمز باشند
	var allies := []
	var foes := []
	for k in names:
		var node = spawned[k]
		var plate = node.get_node_or_null("FoePlate")
		if plate != null and plate.get("is_ally"):
			allies.append(k)
		else:
			foes.append(k)
	print("BOTS allies=", allies)
	print("BOTS foes=", foes)
	print("BOTS spawned_players count=", names.size())
	print("BOTS spawned=", names)

	var known: Dictionary = Network.current_players
	var kn := []
	for k in known.keys():
		kn.append(k)
	kn.sort()
	print("BOTS server_players count=", kn.size())
	print("BOTS server_players=", kn)

	if _out != "":
		var img := get_viewport().get_texture().get_image()
		print("BOTS shot err=", img.save_png(_out + "_arena.png"))
	print("BOTS OK")
	get_tree().quit(0)
