extends Node
## چکِ نوارِ راند: تایمر، شمارشِ زنده‌ها و صفحه‌ی پایان.
##
## سیگنال‌های Network را دستی شلیک می‌کند، پس نه سرور لازم دارد نه مسابقه‌ی
## واقعی. سه عکس می‌گیرد: وسطِ راند، ثانیه‌های آخر، و صفحه‌ی نتیجه.
##
##   godot --path . res://tools/round_hud_shot.tscn --resolution 1280x720 -- --out=C:/tmp/hud

const HUD := preload("res://scripts/round_hud.gd")

var _hud: Control = null
var _out := ""
var _frames := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)

	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	Global.my_team = "0"
	_hud = HUD.new()
	add_child(_hud)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 20:
		# وسطِ راند: ۴v۴ کامل، ۱۳۵ ثانیه مانده
		Network.round_state_updated.emit({"0": 4, "1": 4}, 135)
	elif _frames == 30:
		print("HUD mid timer=%s ally=%s foe=%s" % [
			_hud.get("_timer_label").text,
			_hud.get("_ally_label").text,
			_hud.get("_foe_label").text])
		_save("mid")
	elif _frames == 40:
		# ثانیه‌های آخر و تیمِ حریف تا یک نفر کم شده
		Network.round_state_updated.emit({"0": 3, "1": 1}, 12)
	elif _frames == 50:
		print("HUD urgent timer=%s ally=%s foe=%s" % [
			_hud.get("_timer_label").text,
			_hud.get("_ally_label").text,
			_hud.get("_foe_label").text])
		_save("urgent")
	elif _frames == 60:
		Network.match_over.emit("0", false)
		Network.match_reward.emit({
			"trophy_delta": 24, "coin_delta": 120, "xp_delta": 60,
			"level": 7, "level_up": true,
		})
	elif _frames == 260:
		# صفحه‌ی برد/باخت (match_result_screen.gd) — بعد از انیمیشنِ ورود
		var res := _hud.get_node_or_null("Result") as MatchResultScreen
		print("HUD result-shown=", res != null)
		if res != null:
			print("HUD result outcome=%s reward=%s" % [
				MatchResultScreen.Outcome.keys()[res.outcome], res.get("_reward")])
		_save("result")
		print("HUD OK")
		get_tree().quit(0)


func _save(tag: String) -> void:
	if _out == "":
		return
	var img := get_viewport().get_texture().get_image()
	print("HUD %s saved err=%d" % [tag, img.save_png("%s_%s.png" % [_out, tag])])
