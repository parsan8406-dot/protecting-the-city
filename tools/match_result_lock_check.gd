extends Node
## چکِ قفل شدنِ زمین زیرِ صفحه‌ی برد/باخت، روی صحنه‌ی واقعیِ بازی.
##
## quick_play (که از world.gd ارث می‌برد) را بالا می‌آورد، match_over را دستی
## شلیک می‌کند و بررسی می‌کند:
##   - صفحه‌ی نتیجه ساخته شد و لایه‌اش همه‌ی لمس‌ها را می‌گیرد
##   - جوی‌استیک خاموش شد
##   - Back اندروید وسطِ انیمیشن کاری نمی‌کند و بعدش به صفحه می‌رسد
##
##   godot --path . res://tools/match_result_lock_check.tscn --resolution 1280x720 --fixed-fps 60

var _world: Node = null
var _frames := 0
var _fail := false


func _ready() -> void:
	_world = load("res://secense/quick_play.tscn").instantiate()
	add_child(_world)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 40:
		Global.my_team = "0"
		Network.match_over.emit("0", false)
	elif _frames == 45:
		var screen := get_tree().get_first_node_in_group(MatchResultScreen.GROUP) as MatchResultScreen
		_expect(screen != null, "result screen created")
		var js = _world.get("joystick")
		_expect(js != null and not js.enabled, "joystick disabled")
		var blocker := screen.get_node_or_null("Blocker") as Control
		_expect(blocker != null and blocker.mouse_filter == Control.MOUSE_FILTER_STOP, "blocker stops touches")
		# وسطِ انیمیشن: Back نباید کاری بکند
		_world.call("_on_back")
		_expect(not bool(screen.get("_leaving")), "back ignored during intro")
	elif _frames == 200:
		var screen := get_tree().get_first_node_in_group(MatchResultScreen.GROUP) as MatchResultScreen
		_expect(bool(screen.get("_ready_for_back")), "back ready after intro")
		_world.call("_on_back")
		_expect(bool(screen.get("_leaving")), "back routed to result screen")
		print("LOCK %s" % ("FAIL" if _fail else "OK"))
		get_tree().quit(1 if _fail else 0)


func _expect(ok: bool, what: String) -> void:
	print("LOCK %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fail = true
