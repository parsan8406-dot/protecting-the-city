extends Node
## عکس‌گرفتن از صفحه‌ی انتخاب کاراکتر با دیتای ساختگی (بدون سرور).
##
##   godot --path . res://tools/select_shot.tscn --resolution 1280x720 -- \
##         --out=C:/tmp/select --tab=character|weapon|char_skin|weapon_skin [--own-skins]

const SCENE := preload("res://secense/character_select_screen.tscn")

var _out := ""
var _tab := "character"
var _own_skins := false
var _screen: Control = null
var _frames := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--tab="):
			_tab = a.substr(6)
		elif a == "--own-skins":
			_own_skins = true
	Global.my_username = ""
	Global.coins = 5000
	Global.current_character = "skin_default"
	Global.current_weapon = "ak47"
	Global.owned_characters = ["skin_fire"]
	if _own_skins:
		Global.owned_skins = ["ak47_fire", "skin_default_red"]
		Global.equipped_skins = {"ak47": "ak47_fire"}
	_screen = SCENE.instantiate()
	add_child(_screen)

func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 5:
		_fill()
	elif _frames == 45:
		_report()
		if not _out.is_empty():
			var img := get_viewport().get_texture().get_image()
			print("SELECT saved err=%d" % img.save_png("%s.png" % _out))
		get_tree().quit(0)

func _fill() -> void:
	var catalog := [
		{"item_id": "skin_fire", "name": "آتش", "category": "character", "rarity": "legend",
			"stats": {"move_speed": 40, "aim_accuracy": 60, "hand_speed": 50, "throw_range": 70, "health": 55, "health_regen": 45}},
		{"item_id": "skin_joker", "name": "جوکر", "category": "character", "rarity": "legend", "stats": {}},
		{"item_id": "ak47", "name": "AK-47", "category": "weapon", "rarity": "epic",
			"stats": {"power": 50, "accuracy": 30, "range": 40, "fire_rate": 40, "control": 30}},
		{"item_id": "m82", "name": "M82", "category": "weapon", "rarity": "legend", "stats": {}},
	]
	_screen.set("_skin_catalog", [
		{"skin_id": "ak47_fire", "base_id": "ak47", "category": "weapon", "name": "AK-47 آتشین", "rarity": "legend", "pass_level": 10},
		{"skin_id": "skin_default_red", "base_id": "skin_default", "category": "character", "name": "سرباز سرخ", "rarity": "legend", "pass_level": 20},
	])
	_screen.set("_skins_loaded", true)
	var headers := PackedStringArray()
	_screen.call("_on_catalog_received", HTTPRequest.RESULT_SUCCESS, 200, headers,
		JSON.stringify(catalog).to_utf8_buffer())
	_screen.call("_on_upgrades_received", HTTPRequest.RESULT_SUCCESS, 200, headers, JSON.stringify({"characters": [
		{"item_id": "skin_default", "level": 2, "max_level": 5, "owned": true, "cost": 1600,
			"current": {"health": 104, "damage": 20}, "next": {"health": 107, "damage": 21}},
		{"item_id": "skin_fire", "level": 1, "max_level": 10, "owned": true, "cost": 1600,
			"current": {"health": 110, "damage": 24}, "next": {"health": 112, "damage": 24}},
	]}).to_utf8_buffer())
	_screen.call("_switch_category", _tab, false)

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
			print("SELECT OVERFLOW %s %s" % [_screen.get_path_to(c), r])
	print("SELECT viewport=%s overflow=%d" % [vp.size, bad])
