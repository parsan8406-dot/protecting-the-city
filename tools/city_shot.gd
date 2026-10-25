extends Node
## عکس‌گرفتن از صفحه‌ی «شهر» با دیتای ساختگی (بدون سرور).
##
##   godot --path . res://tools/city_shot.tscn --resolution 2400x1080 -- \
##         --out=C:/tmp/city --mode=mine [--modal=edit|member|requests|rules|leave|create]
##
##   --mode=browse  لیست شهرها (عضو نیستم)
##   --mode=view    مشاهده‌ی یک شهر دیگر (دکمه‌ی عضویت)
##   --mode=mine    شهر خودم به‌عنوان رهبر (دکمه‌ی قرمز ترک شهر)
##
## چک می‌کند هیچ کنترلی از صفحه بیرون نزده باشد.

const CITY_SCENE := preload("res://secense/city.tscn")

var _out := ""
var _mode := "mine"
var _modal := ""
var _screen: Control = null
var _frames := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--mode="):
			_mode = a.substr(7)
		elif a.begins_with("--modal="):
			_modal = a.substr(8)
	# بدون نام کاربری، صفحه به سرور درخواست نمی‌دهد
	Global.my_username = ""
	Global.coins = 12450
	_screen = CITY_SCENE.instantiate()
	add_child(_screen)

func _process(_delta: float) -> void:
	_frames += 1
	# Global نام کاربری ذخیره‌شده را کمی بعد از شروع برمی‌گرداند؛ خالی نگهش
	# می‌داریم تا صفحه سراغ سرور واقعی نرود و دیتای ساختگی را عوض نکند
	Global.my_username = ""
	if _frames == 5:
		_fill()
	elif _frames == 12 and not _modal.is_empty():
		_open_modal()
	elif _frames == 60:
		_report()
		if not _out.is_empty():
			var img := get_viewport().get_texture().get_image()
			print("CITY saved err=%d" % img.save_png("%s.png" % _out))
		get_tree().quit(0)

func _members() -> Array:
	var names := ["ShadowHunter", "King_Snipe", "Arman_Killer", "SilentWolf", "RezaGamer", "Parsa", "Nima_77"]
	var roles := ["leader", "officer", "officer", "member", "member", "member", "member"]
	var out: Array = []
	for i in names.size():
		out.append({
			"player_id": "p%d" % i, "username": names[i], "role": roles[i],
			"avatar_id": "", "level": 72 - i * 4, "is_online": i < 5,
			"trophies": 2843 - i * 250, "tier_id": "gold", "tier_name": "طلا",
			"is_me": i == 0 and _mode == "mine", "is_friend": i == 2,
			"friend_request_sent": false,
		})
	return out

func _clan() -> Dictionary:
	return {
		"clan_id": "clan_1", "name": "شهر شوالیه‌ها", "tag": "KNT",
		"description": "با هم قوی‌تر، با هم تا پیروزی", "icon_path": "emblem:3:0",
		"level": 5, "experience": 1200, "member_count": 48, "max_members": 50,
		"is_public": false, "min_level": 10, "is_full": false,
		"members": _members(), "my_role": "leader" if _mode == "mine" else "",
		"is_member": _mode == "mine", "can_manage": _mode == "mine", "can_lead": _mode == "mine",
		"pending_requests": 3, "leader_name": "ShadowHunter", "officer_count": 2,
		"world_rank": 12, "my_level": 30, "my_clan_id": "", "request_pending": false,
	}

func _fill() -> void:
	match _mode:
		"browse":
			var clans: Array = []
			var names := ["شهر عقاب", "شهر تندر", "شهر اژدها", "شهر شوالیه‌ها", "Wolf Pack", "شهر نور"]
			for i in names.size():
				clans.append({
					"clan_id": "c%d" % i, "name": names[i], "tag": ["EGL", "THN", "DRG", "KNT", "WLF", "NUR"][i],
					"description": "با هم تا پیروزی" if i % 2 == 0 else "",
					"icon_path": "emblem:%d:%d" % [i % 8, i % 6], "level": 6 - i / 2,
					"member_count": 42 - i * 3, "max_members": 50, "is_public": i % 3 != 1,
					"min_level": 0, "is_full": i == 4,
				})
			_screen.call("_apply_clan_list", {"clans": clans, "my_pending_clan_ids": ["c2"]})
		"view":
			_screen.set("_viewing_id", "clan_1")
			_screen.call("_apply_clan", _clan(), 1)
		_:
			_screen.call("_apply_clan", _clan(), 2)

func _open_modal() -> void:
	match _modal:
		"edit":
			_screen.call("_open_edit")
		"create":
			_screen.call("_open_create")
		"member":
			_screen.call("_open_member", _members()[3])
		"rules":
			_screen.call("_open_rules")
		"leave":
			_screen.call("_confirm_leave")
		"requests":
			_screen.call("_open_requests")
			_screen.set("_requests", [
				{"request_id": "r1", "from_username": "NewPlayer", "from_level": 14, "from_avatar_id": ""},
				{"request_id": "r2", "from_username": "Sniper_IR", "from_level": 33, "from_avatar_id": ""},
			])
			_screen.call("_build_requests")

func _report() -> void:
	var vp := get_viewport().get_visible_rect()
	var bad := 0
	for n in _screen.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or c.size == Vector2.ZERO:
			continue
		var inside_scroll := false
		var p := c.get_parent()
		while p != null and p != _screen:
			if p is ScrollContainer:
				inside_scroll = true
				break
			p = p.get_parent()
		if inside_scroll:
			continue
		var r := c.get_global_rect()
		if r.end.x > vp.end.x + 1 or r.end.y > vp.end.y + 1 or r.position.x < -1 or r.position.y < -1:
			bad += 1
			print("CITY OVERFLOW %s %s" % [_screen.get_path_to(c), r])
	print("CITY viewport=%s overflow=%d" % [vp.size, bad])
