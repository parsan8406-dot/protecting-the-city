extends Node
## چکِ صفحه‌ی برد/باخت (match_result_screen.gd) روی یک زمینِ بازیِ ساختگی.
##
## نه سرور لازم دارد نه مسابقه؛ صفحه را مستقیم می‌سازد، پاداش را کمی بعد
## می‌دهد (مثلِ سرورِ واقعی) و در چند لحظه‌ی انیمیشن عکس می‌گیرد:
##   start  همه‌چیز تار، منو هنوز پایین
##   slide  وسطِ بالا آمدن
##   landed منو نشسته، بال‌ها تازه شروع کرده‌اند
##   cards  جایزه‌ها / شمارشِ کاپ
##   final  حالتِ پایانی
##
##   godot --path . res://tools/match_result_shot.tscn --resolution 1280x720 --fixed-fps 60 -- --outcome=win --out=C:/tmp/res
##
## اختیاری: --kills=N (کیلِ سرور در match_reward؛ ‎-1 = سرورِ قدیمی)،
## --tracked (آمارِ کلاینت فعال — برای زنجیره‌ی برد/رکورد)، --goal=ready
## (کارتِ هدف با «جایزه‌ی آماده»). outcome: win | lose | lose0 | draw

var _out := ""
var _outcome := "win"
var _frames := 0
var _screen: MatchResultScreen = null
var _movers: Array[Node2D] = []
var _kills := 7
var _tracked := false
var _goal := ""

const SHOTS := {6: "start", 30: "slide", 50: "landed", 110: "cards", 240: "final"}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--outcome="):
			_outcome = a.substr(10)
		elif a.begins_with("--kills="):
			_kills = a.substr(8).to_int()
		elif a == "--tracked":
			_tracked = true
		elif a.begins_with("--goal="):
			_goal = a.substr(7)
	_build_board()


func _build_board() -> void:
	# زمینِ ساختگی: کاشی + چند «بازیکن» که تکان می‌خورند + دکمه‌های HUD
	var tex: Texture2D = load("res://assets/asphalt.png")
	var bg := TextureRect.new()
	bg.texture = tex
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var colours := [Color(0.3, 0.7, 1.0), Color(0.95, 0.3, 0.3), Color(0.4, 0.9, 0.4), Color(1, 0.8, 0.2)]
	for i in 8:
		var n := Node2D.new()
		var c: Color = colours[i % colours.size()]
		n.draw.connect(func() -> void: n.draw_circle(Vector2.ZERO, 26.0, c))
		n.position = Vector2(150 + i * 140, 200 + (i % 3) * 160)
		add_child(n)
		_movers.append(n)
	var hud := preload("res://scripts/game_hud.gd").new()
	add_child(hud)


func _process(_delta: float) -> void:
	_frames += 1
	for i in _movers.size():
		_movers[i].position.x += sin(_frames * 0.05 + i) * 3.0

	if _frames == 3:
		Global.my_team = "0"
		var st = Network.get("psych_match_stats")
		if _tracked and st != null:
			st.match_id = "shot_%d" % Time.get_ticks_usec()
			st.reset()
			st.active = true
		_screen = MatchResultScreen.new()
		match _outcome:
			"lose", "lose0": _screen.outcome = MatchResultScreen.Outcome.LOSE
			"draw": _screen.outcome = MatchResultScreen.Outcome.DRAW
			_: _screen.outcome = MatchResultScreen.Outcome.WIN
		add_child(_screen)
	elif _frames == 20:
		# سرورِ واقعی پاداش را کمی بعد از match_over می‌فرستد
		var r := {}
		if _outcome == "lose":
			r = {"won": false, "trophy_delta": -21, "coin_delta": 60,
				"xp_delta": 40, "trophies": 2822, "level": 12, "level_up": false}
		elif _outcome == "lose0":
			r = {"won": false, "trophy_delta": 0, "coin_delta": 60,
				"xp_delta": 40, "trophies": 40, "level": 2, "level_up": false}
		else:
			r = {"won": true, "trophy_delta": 25, "coin_delta": 4800,
				"xp_delta": 2500, "trophies": 2868, "level": 13, "level_up": true}
		if _kills >= 0:
			r["kills"] = _kills
			r["win_trophies"] = 25
		_screen.set_reward(r)
	elif _frames == 200 and _goal == "ready":
		_screen.set("_goal_missions", [{"done": true, "claimed": false, "target": 1, "progress": 1}])
		_screen.set("_goal_challenges", [])
		_screen.call("_fill_goal")

	if SHOTS.has(_frames):
		var wl = _screen.get("_wing_l")
		var wr = _screen.get("_wing_r")
		var slider = _screen.get("_slider")
		print("RESULT %s wingL=%.1f wingR=%.1f slideY=%.1f" % [SHOTS[_frames],
			wl.rotation_degrees, wr.rotation_degrees, slider.position.y])
		_save(SHOTS[_frames])
	if _frames == 240:
		for chip in ["_chip_moment", "_chip_rank", "_chip_goal"]:
			var d: Dictionary = _screen.get(chip)
			var icon: TextureRect = d["icon"]
			var tex_path: String = icon.texture.resource_path if icon.texture != null else "-"
			print("RESULT %s visible=%s icon=%s rect=%s title=%s value=%s" % [chip,
				(d["panel"] as Control).visible, tex_path.get_file(), icon.get_global_rect(),
				(d["title"] as Label).text, (d["value"] as Label).text])
		var btn: Button = _screen.get("_button")
		print("RESULT button disabled=%s back_ready=%s" % [btn.disabled, _screen.get("_ready_for_back")])
		print("RESULT OK")
		get_tree().quit(0)


func _save(tag: String) -> void:
	if _out == "":
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s_%s_%s.png" % [_out, _outcome, tag])
