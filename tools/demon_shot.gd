extends Node2D
## چکِ تصویریِ «عملیات حذف شیطان» — بدونِ سرور و بدونِ دیتابیس.
##
## زمینِ banish را با همان Arena.gd خودِ بازی می‌سازد، شیطان را وسطش
## می‌گذارد و چرخه‌ی نفرین (اخطار → انفجار) را دستی اجرا می‌کند. یعنی
## دقیقاً همان نودها و همان شیدرهایی که در بازیِ واقعی اجرا می‌شوند.
##
##   godot --path . res://tools/demon_shot.tscn --resolution 1280x720 \
##         -- --out=C:/tmp/demon --seconds=14
##
## چه چیزی را ثابت می‌کند:
##   DEMON map=banish walls=...    زمینِ شیطان واقعاً لود و ساخته می‌شود
##   DEMON demon pos=... hp=...    نودِ شیطان سرِ جایش است و شعاعش درست
##   DEMON mark / blast            چرخه‌ی نفرین بدونِ خطا اجرا می‌شود
##   عکس‌ها                        هاله، نشانگرِ اخطار و انفجار واقعاً دیده می‌شوند

const ARENA := preload("res://scripts/Arena.gd")
const DEMON := preload("res://scripts/demon.gd")

## شعاعِ نفرین — همان عددِ سرور (demon.go → DemonBlastRadius)
const BLAST_RADIUS := 190.0
const BLAST_WARN := 2.0

var _arena: Node2D = null
var _demon: Node2D = null
var _cam: Camera2D = null
var _hud: GameHUD = null
## جای «بازیکن» برای مینی‌مپ و فلش. یک Node2D ساده کافی است — هر دو فقط
## global_position و (مینی‌مپ) global_rotation را می‌خوانند.
var _eye: Node2D = null
var _out := ""
var _limit := 14.0
var _t := 0.0
var _shot := 0
## لحظه‌های عکس‌برداری. مهم‌ترین‌شان دو فریمِ اولِ انفجارند: انفجار ۰.۶
## ثانیه بیشتر نیست و اگر دیر عکس بگیری فقط دودش را می‌بینی، نه خودش.
##   ۱.۲  هاله‌ی تنها (شیطانِ آرام)
##   ۳.۴  وسطِ اخطار — حلقه‌ی فروریزنده
##   ۴.۵۵ لحظه‌ی اخطارِ آخر، قبل از انفجار
##   ۴.۷۰ اوجِ انفجار (۷۰ میلی‌ثانیه بعد)
##   ۴.۹۵ موجِ ضربه در حالِ باز شدن
##   ۵.۶  دود و اخگرهای باقی‌مانده
var _shot_at := [1.2, 3.4, 4.55, 4.70, 4.95, 5.6]
## مرحله‌ی بعدیِ چرخه‌ی نفرین
var _cycle := 0
var _cycle_at := [2.6, 4.6, 7.6, 9.6]


func _ready() -> void:
	# بی‌سرور: اگر سرورِ محلی بالا باشد، Network وصل می‌شود و update_players
	# واقعی لیستِ ساختگیِ بازیکن‌ها را همان لحظه پاک می‌کند
	Global.offline_mode = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--seconds="):
			_limit = float(a.substr(10))

	# کفِ صحنه، تا Arena چیزی برای تاریک کردن و بک‌گراند گذاشتن داشته باشد
	var floor_spr := Sprite2D.new()
	floor_spr.name = "Floor"
	floor_spr.centered = false
	floor_spr.texture = load("res://assets/Background.png")
	add_child(floor_spr)

	_arena = ARENA.new()
	_arena.name = "Arena"
	add_child(_arena)
	_arena.load_map("banish", "")

	var ws: Vector2 = _arena.world_size
	floor_spr.scale = ws / Vector2(floor_spr.texture.get_size())

	# «بازیکن» را گوشه‌ی میدانِ غرب می‌گذاریم: هم فلشِ راهنما کارِ واقعی‌اش
	# را نشان می‌دهد (شیطان بیرونِ دیدِ نزدیک است) و هم مینی‌مپ نشانِ لبه را
	_eye = Node2D.new()
	_eye.name = "Eye"
	_eye.global_position = Vector2(ws.x * 0.16, ws.y * 0.5)
	add_child(_eye)

	_demon = DEMON.new()
	add_child(_demon)
	# نیمه‌جان، تا نوار و امتیازِ دو تیم عددِ واقعی نشان بدهند
	_demon.setup(ws * 0.5, 96.0, 7400, 12000)

	_cam = Camera2D.new()
	# دوربین را جایی می‌گذاریم که سؤالِ واقعی را جواب بدهد: از داخلِ
	# راهروی غرب، آیا اصلاً شیطان پیداست؟ (زومِ ۱ = همان زومی که بازیکن دارد)
	_cam.position = Vector2(ws.x * 0.34, ws.y * 0.5)
	_cam.zoom = Vector2(0.80, 0.80)
	add_child(_cam)
	_cam.make_current()

	# --- رابطِ کاربری ---
	#
	# کلِ GameHUD ساخته می‌شود و نه فقط نوارِ شیطان: چیزی که باید ثابت شود
	# این است که نوار و فلش کنارِ تایمر و مینی‌مپ جا می‌شوند و روی هم
	# نمی‌افتند — همان چیزی که با ساختنِ تک‌تکشان معلوم نمی‌شد.
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)
	_hud = GameHUD.new()
	_hud.name = "GameHUD"
	layer.add_child(_hud)
	_hud.minimap.arena = _arena
	_hud.minimap.me = _eye
	_hud.minimap.actors_source = func() -> Array: return []
	_hud.minimap.demon_source = func(): return _demon.global_position
	_hud.demon_pointer.demon_source = func(): return _demon.global_position
	_hud.demon_pointer.me = _eye
	_hud.set_demon_visible(true)
	# نوار و فلش از Network.demon_info می‌خوانند، پس همان‌جا پرش می‌کنیم —
	# دقیقاً همان دیکشنری‌ای که سرور می‌فرستد
	_push_demon_info()
	_push_roster()

	print("DEMON map=%s walls=%d spawns=%d world=%s"
		% [_arena.map_name, _arena.wall_rects().size(),
			_arena.spawn_points.size(), ws])
	print("DEMON demon pos=%s r=%.0f hp=%d" % [_demon.global_position, _demon.radius, _demon.health])


func _process(delta: float) -> void:
	_t += delta

	# چرخه‌ی نفرین، همان‌طور که سرور می‌فرستد: اخطار، بعد انفجار
	if _cycle < _cycle_at.size() and _t >= float(_cycle_at[_cycle]):
		var step := _cycle
		_cycle += 1
		var at: Vector2 = _demon.global_position + Vector2(
			randf_range(-260.0, 260.0), randf_range(-190.0, 190.0))
		if step % 2 == 0:
			_pending = at
			CombatFX.demon_mark(at, BLAST_RADIUS, BLAST_WARN)
			print("DEMON mark t=%.2f at=%s" % [_t, at])
		else:
			CombatFX.demon_blast(_pending, BLAST_RADIUS)
			print("DEMON blast t=%.2f at=%s" % [_t, _pending])
			# هر انفجار کمی هم به خودِ شیطان بزند تا نوار و تپشِ هاله دیده شود
			_demon.apply_state(_demon.global_position, _demon.radius,
				_demon.health - 2600, _demon.max_health)
			_push_demon_info()

	if _shot < _shot_at.size() and _t >= float(_shot_at[_shot]):
		_shot += 1
		_snapshot(_shot)

	if _t >= _limit:
		print("DEMON DONE")
		get_tree().quit(0)


var _pending := Vector2.ZERO


## همان پیامی که سرور با demon_state می‌فرستد. نوارِ بالای صفحه از این
## می‌خواند، پس با پر کردنش دقیقاً مسیرِ واقعی آزموده می‌شود.
func _push_demon_info() -> void:
	var dealt: int = int(_demon.max_health) - int(_demon.health)
	Network.demon_info = {
		"x": _demon.global_position.x, "y": _demon.global_position.y,
		"health": _demon.health, "max_health": _demon.max_health,
		"radius": _demon.radius, "alive": _demon.health > 0,
		# تیمِ ما جلوتر است، تا سهمِ نامتقارن هم دیده شود
		"damage": {"0": int(dealt * 0.62), "1": dealt - int(dealt * 0.62)},
	}
	Global.my_team = "0"
	# امتیازِ قابِ تایمر از round_info.demon می‌فهمد که این حالت شیطان دارد
	Network.round_info = {
		"mode": "banish", "demon": true, "respawn": true,
		"score_kills": false, "seconds_left": 214,
	}
	Network.round_state_updated.emit({"0": 3, "1": 2}, 214)


## یک ۳ در ۳ واقعی، همان شکلی که سرور با update_players می‌فرستد.
## جانِ متفاوت و یک نفرِ افتاده، تا هر چهار حالتِ پنلِ جان دیده شود.
func _push_roster() -> void:
	# Global نامِ حساب را ناهمزمان حل می‌کند و ممکن است بعد از _ready عوض
	# شود؛ پس ردیفِ «خودم» همیشه با نامِ همین لحظه ساخته می‌شود — همان
	# چیزی که در بازیِ واقعی کلیدِ current_players است
	var me: String = str(Global.my_username)
	if me == "":
		me = "Tester"
		Global.my_username = me
	var roster := {
		me: {"team": "0", "health": 74},
		"Reza": {"team": "0", "health": 112},
		"Omid": {"team": "0", "health": 0},
		"Ali": {"team": "1", "health": 96},
		"Sara": {"team": "1", "health": 28},
		"KianTheLongName": {"team": "1", "health": 112},
	}
	var out := {}
	for name in roster:
		var r: Dictionary = roster[name]
		out[name] = {
			"username": name, "team": r["team"], "health": r["health"],
			"stats": {"health": 112},
		}
	Network.current_players = out


func _snapshot(index: int) -> void:
	_push_roster()
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	print("DEMON t=%.2f hp=%d shot%d me=%s" % [_t, _demon.health, index, Global.my_username])
	if _out == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	print("DEMON shot%d err=%d" % [index, img.save_png("%s_%d.png" % [_out, index])])
