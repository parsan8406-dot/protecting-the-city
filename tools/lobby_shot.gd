extends Node
## عکس‌گرفتن از لابیِ «در جستجوی حریف» در هر سه اندازه‌ی تیم.
##
## هدف: مطمئن شویم در صفحه‌ی افقی هر ۸ نفرِ یک ۴v۴ کامل و بدون اسکرول
## دیده می‌شوند — همان چیزی که خواسته شده — و اینکه حالتِ تک‌به‌تک
## («عملیات انتقام») هم درست چیده می‌شود. دیتا ساختگی است تا لازم نباشد
## واقعاً هفت نفر در صف باشند.
##
##   godot --path . res://tools/lobby_shot.tscn --resolution 1280x720 -- \
##         --out=C:/tmp/lobby

const LOBBY := preload("res://scripts/matchmaking.gd")

## اسم‌ها عمداً مخلوطِ آدم‌وار و Player#### اند — همان چیزی که بات‌ها هم
## دارند، تا ببینیم لابی با هر دو شکل درست به‌نظر می‌رسد.
const FAKE_NAMES := [
	"Ali77", "Player48213", "Nazanin.", "Viper_HD", "Reza302",
	"Player71904", "Storm", "Mahsa11",
]
const FAKE_CHARS := [
	"skin_default", "skin_boy", "skin_girl", "skin_iraqian",
	"skin_angle", "skin_joker", "skin_devil", "skin_engineer",
]

var _out := ""
## یک نفره هم هست: «عملیات انتقام» تک‌به‌تک است
var _sizes := [1, 2, 3, 4]
var _idx := 0
var _lobby: Control = null
var _frames := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	_open(_sizes[_idx])


func _open(team_size: int) -> void:
	if _lobby != null:
		_lobby.queue_free()
	# لابی team_size را از Global می‌خواند، پس قبل از ساختنش ست می‌شود
	Global.selected_mode_data = {
		"mode_id": "strike", "name": "عملیات ضربت",
		"subtitle": "%d در %d" % [team_size, team_size],
		"team_size": team_size, "accent": "#F0B429",
	}
	Global.selected_mode = "strike"
	_lobby = LOBBY.new()
	_lobby.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_lobby)
	_frames = 0


## به‌جای پاسخِ سرور: صف را پر می‌کنیم و مسابقه را «جورشده» اعلام می‌کنیم،
## تا هر دو تیم کامل دیده شوند.
func _fill(team_size: int) -> void:
	var players := []
	for i in team_size * 2:
		players.append({
			"username": Global.my_username if i == 0 else FAKE_NAMES[i % FAKE_NAMES.size()],
			"player_id": str(10000 + i * 731),
			"avatar_id": "avatar_default",
			"character": FAKE_CHARS[i % FAKE_CHARS.size()],
			"trophies": 80 + i * 137,
			"level": 3 + i * 2,
			"rank_id": "gold", "rank_name": "طلا",
			"team": i % 2,
		})
	_lobby.set("_players", players)
	_lobby.set("_state", "ready")
	_lobby.call("_rebuild_slots", players.size())
	# همان متنی که خودِ matchmaking.gd وقتی حریف پیدا می‌شود نشان می‌دهد
	_lobby.call("_set_center", "حریف پیدا شد!", "ورود به میدان...", _lobby.get("COL_GOLD"))


func _process(_delta: float) -> void:
	_frames += 1
	var size: int = _sizes[_idx]
	if _frames == 20:
		_fill(size)
	elif _frames == 30:
		_report(size)
		_save("%dv%d" % [size, size])
		_idx += 1
		if _idx >= _sizes.size():
			print("LOBBY SHOT OK")
			get_tree().quit(0)
			return
		_open(_sizes[_idx])


## مهم‌ترین چک: آیا صندلی‌ها از پایینِ صفحه زده‌اند بیرون؟
func _report(size: int) -> void:
	var vp := get_viewport().get_visible_rect().size
	var overflow := 0
	var seats := 0
	for box_name in ["_ally_box", "_foe_box"]:
		var box: Control = _lobby.get(box_name)
		if box == null:
			continue
		for seat in box.get_children():
			seats += 1
			var bottom: float = (seat as Control).global_position.y + (seat as Control).size.y
			if bottom > vp.y:
				overflow += 1
	print("LOBBY %dv%d: seats=%d viewport=%s offscreen=%d" % [size, size, seats, vp, overflow])
	if overflow > 0:
		print("LOBBY %dv%d FAIL: %d seat(s) fall below the screen" % [size, size, overflow])


func _save(tag: String) -> void:
	if _out == "":
		return
	var img := get_viewport().get_texture().get_image()
	print("LOBBY %s saved err=%d" % [tag, img.save_png("%s_%s.png" % [_out, tag])])
