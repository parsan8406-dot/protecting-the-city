extends Node
## عکس‌گرفتن از صفحه‌ی «رنک» با دیتای ساختگی (بدون سرور).
##
##   godot --path . res://tools/rank_shot.tscn --resolution 2400x1080 -- \
##         --out=C:/tmp/rank --trophies=2843
##
## چک می‌کند هیچ کارت درجه‌ای از صفحه بیرون نزده باشد.

const RANK_SCENE := preload("res://secense/rank_screen.tscn")

var _out := ""
var _trophies := 2843
## --rules → صفحه‌ی «قوانین رنک» به‌جای درجه‌ها
var _rules := false
var _screen: Control = null
var _frames := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--trophies="):
			_trophies = a.substr(11).to_int()
		elif a == "--rules":
			_rules = true
	# بدون نام کاربری، صفحه به سرور درخواست نمی‌دهد
	Global.my_username = ""
	_screen = RANK_SCENE.instantiate()
	add_child(_screen)

func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 5:
		_fill()
	elif _frames == 40:
		_report()
		if not _out.is_empty():
			var img := get_viewport().get_texture().get_image()
			print("RANK saved err=%d" % img.save_png("%s.png" % _out))
		get_tree().quit(0)

func _fill() -> void:
	_screen.call("_apply_profile", {
		"username": "ShadowHunter", "level": 72, "avatar_id": "",
		"trophies": _trophies,
		"rank": {"season_id": "season_3", "tier_id": ""},
		"season_ends_at": Time.get_datetime_string_from_unix_time(
			int(Time.get_unix_time_from_system()) + 28 * 86400 + 16 * 3600 + 60) + "Z",
	})
	if _rules:
		_screen.call("_show_page", true)

func _report() -> void:
	var vp := get_viewport().get_visible_rect()
	var bad := 0
	for n in _screen.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or c.size == Vector2.ZERO:
			continue
		var r := c.get_global_rect()
		if r.end.x > vp.end.x + 1 or r.end.y > vp.end.y + 1 or r.position.x < -1:
			if c.get_parent() is ScrollContainer or c.get_parent().get_parent() is ScrollContainer:
				continue
			bad += 1
			print("RANK OVERFLOW %s %s" % [_screen.get_path_to(c), r])
	print("RANK viewport=%s overflow=%d" % [vp.size, bad])
