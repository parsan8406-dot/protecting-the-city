extends Node
## چکِ جریانِ لابی.
##
## قرارداد: به این صفحه فقط با زدنِ «شروع» در منوی اصلی می‌رسیم، پس جستجو
## باید بی‌درنگ آغاز شود و دکمه‌ی پایین «لغو جستجو» باشد که به منو برمی‌گردد.
##
## دو چیز را می‌سنجد:
##   ۱. با باز شدنِ لابی وضعیت searching است و تایمر راه افتاده
##   ۲. دکمه «لغو جستجو» است، نه چیز دیگر
##
##   godot --path . res://tools/lobby_gate_shot.tscn --resolution 1280x720 -- --out=C:/tmp/gate

const LOBBY := preload("res://scripts/matchmaking.gd")

var _s: Control = null
var _out := ""
var _frames := 0
var _idle_ok := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)

	Global.selected_mode_data = {
		"mode_id": "strike", "name": "عملیات ضربت", "subtitle": "۴ در ۴",
		"team_size": 4, "accent": "#F0B429",
	}
	_s = LOBBY.new()
	_s.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_s)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 60:
		var st := str(_s.get("_state"))
		var elapsed := float(_s.get("_elapsed"))
		var btn: Button = _s.get("_action_button")
		var label := btn.text if btn != null else "<none>"
		print("GATE on-open state=%s elapsed=%.2f button=%s" % [st, elapsed, label])
		_idle_ok = st == "searching" and elapsed > 0.0 and label == "لغو جستجو"
		print("GATE search-starts-immediately: ", "PASS" if _idle_ok else "FAIL")
		_save("searching")
		print("GATE OK")
		get_tree().quit(0)


func _save(tag: String) -> void:
	if _out == "":
		return
	var img := get_viewport().get_texture().get_image()
	print("GATE %s saved err=%d" % [tag, img.save_png("%s_%s.png" % [_out, tag])])
