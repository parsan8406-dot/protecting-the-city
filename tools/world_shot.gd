extends Node
## عکس‌گرفتن از صحنه‌ی واقعیِ بازی (quick_play) — نه یک ماکتِ جدا.
##
## این تنها راهِ دیدنِ نتیجه‌ی واقعیِ نورپردازی است: تاریکیِ CanvasModulate،
## کانون‌های نورِ زمین، دیوارهای آهنی و خودِ بازیکن، همه با هم. مخصوصاً برای
## چکِ اینکه بازیکن در تاریکی گم نشده — اسپرایتِ بازیکن unshaded است، پس
## نور رویش اثر ندارد و فقط CanvasModulate تیره‌اش می‌کند.
##
##   godot --path . res://tools/world_shot.tscn --resolution 1280x720 -- \
##         --scene=res://secense/quick_play.tscn --out=C:/tmp/world

const SHOT_ARG := "--out="
const SCENE_ARG := "--scene="

var _scene_path := "res://secense/quick_play.tscn"
var _out := ""
var _root: Node = null
var _frames := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(SHOT_ARG):
			_out = a.substr(SHOT_ARG.length())
		elif a.begins_with(SCENE_ARG):
			_scene_path = a.substr(SCENE_ARG.length())

	if not ResourceLoader.exists(_scene_path):
		print("WORLD SHOT: missing scene ", _scene_path)
		get_tree().quit(1)
		return
	_root = load(_scene_path).instantiate()
	add_child(_root)
	print("WORLD SHOT: loaded ", _scene_path)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 50:
		_report()
		_lock_on_player()
	elif _frames == 60:
		_save("player")
		_aim_at_dark_wall()
	elif _frames == 70:
		_save("wall_unlit")
		_fire()
	elif _frames == 72:
		# فلش ۰.۱۲ ثانیه عمر دارد (~۷ فریم)، پس دو فریم بعدِ شلیک نور در
		# اوجِ خودش است
		_save("wall_muzzle")
	elif _frames == 90:
		_look_at_lights()
	elif _frames == 130:
		_save("zones")
		print("WORLD SHOT OK")
		get_tree().quit(0)


## دوربین را روی یک دیوارِ داخلی در تاریک‌ترین جای ممکن می‌برد — جایی که
## هیچ کانونِ نوری نمی‌رسد، تا اثرِ نورِ شلیک خالص دیده شود.
var _dark_spot := Vector2.ZERO

func _aim_at_dark_wall() -> void:
	var arena := _root.get_node_or_null("Arena")
	var cam := _root.get_node_or_null("Player/Camera2D") as Camera2D
	if arena == null or cam == null:
		return
	var rects: Array = arena.get("_rects")
	var zone_root := _root.get_node_or_null("Arena/ZoneLights")
	var zone_pos: Array[Vector2] = []
	if zone_root != null:
		for zl in zone_root.get_children():
			zone_pos.append((zl as Node2D).position)

	# دورترین دیوارِ داخلی از همه‌ی کانون‌های نور. دیوارهای نزدیکِ مرزِ زمین
	# رد می‌شوند، وگرنه کادر نصفش بیرونِ نقشه می‌افتد و عکس بی‌فایده است.
	var world: Vector2 = arena.world_size
	var margin := 320.0
	var best := world * 0.5
	var best_d := -1.0
	for r in rects:
		var rect: Rect2 = r
		if rect.position.x < 0.0 or rect.position.y < 0.0:
			continue
		var c := rect.position + rect.size * 0.5
		if c.x < margin or c.y < margin \
				or c.x > world.x - margin or c.y > world.y - margin:
			continue
		var d := 1.0e12
		for zp in zone_pos:
			d = minf(d, c.distance_squared_to(zp))
		if d > best_d:
			best_d = d
			best = c
	_dark_spot = best
	cam.top_level = true
	cam.position_smoothing_enabled = false
	cam.limit_left = -10000
	cam.limit_top = -10000
	cam.limit_right = 10000
	cam.limit_bottom = 10000
	cam.global_position = best
	cam.zoom = Vector2(2, 2)
	print("WORLD dark wall at ", best)


## شلیکِ ساختگی درست زیرِ همان دیوار، تا نورِ دهانه‌ی لوله سنجیده شود.
## فاصله کم است تا دیوار داخلِ شعاعِ روشناییِ فلش باشد.
func _fire() -> void:
	var muzzle := _dark_spot + Vector2(0, 80)
	CombatFX.muzzle_flash(muzzle, Vector2(0, -1))
	print("WORLD muzzle flash at ", muzzle)
	# توجه: دوربینِ خودِ بازی scale عجیبی دارد (حدود ۳۸۶×۱۲)، پس نگاشتِ
	# «مختصاتِ جهانی به پیکسلِ عکس» در این هارنس قابل اعتماد نیست و برای
	# اندازه‌گیریِ عددیِ نورِ شلیک از tools/arena_shot.gd استفاده کن که
	# دوربینش را خودش می‌سازد. این عکس فقط برای نگاه کردن است.


## دوربین را سختِ روی بازیکن قفل می‌کند و روشناییِ خودِ بازیکن را اندازه
## می‌گیرد. این مهم‌ترین چکِ تاریک کردنِ زمین است: اسپرایتِ بازیکن unshaded
## است، پس هیچ نوری روشنش نمی‌کند و اگر CanvasModulate هم رویش اثر بگذارد
## بازیکن برای همیشه یک سایه‌ی سیاه می‌شود.
func _lock_on_player() -> void:
	var player := _root.get_node_or_null("Player") as Node2D
	var cam := _root.get_node_or_null("Player/Camera2D") as Camera2D
	if player == null or cam == null:
		print("WORLD: no player/camera")
		return
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(2, 2)
	print("WORLD player at ", player.global_position)


## دوربینِ بازیکن را رها می‌کند و کلِ زمین را در کادر می‌آورد تا کانون‌های
## نور و تاریکیِ بینشان با هم دیده شوند
func _look_at_lights() -> void:
	var arena := _root.get_node_or_null("Arena")
	var cam := _root.get_node_or_null("Player/Camera2D") as Camera2D
	if arena == null or cam == null:
		return
	var world: Vector2 = arena.world_size
	var vp := get_viewport().get_visible_rect().size
	cam.position_smoothing_enabled = false
	cam.top_level = true          # از بازیکن جدا شود وگرنه دنبالش می‌رود
	cam.limit_left = -10000
	cam.limit_top = -10000
	cam.limit_right = 10000
	cam.limit_bottom = 10000
	cam.global_position = world * 0.5
	cam.zoom = Vector2.ONE * min(vp.x / world.x, vp.y / world.y)


func _report() -> void:
	var arena := _root.get_node_or_null("Arena")
	if arena == null:
		print("WORLD SHOT: no Arena node")
		return
	for n in ["WallArt", "DoorGlow", "ZoneLights"]:
		var node := arena.get_node_or_null(n)
		print("WORLD %s = %d" % [n, node.get_child_count() if node != null else -1])
	var cm := _root.get_node_or_null("CanvasModulate") as CanvasModulate
	if cm != null:
		print("WORLD ambient = ", cm.color)


func _save(tag: String) -> void:
	if _out == "":
		return
	var img := get_viewport().get_texture().get_image()
	print("WORLD %s saved err=%d" % [tag, img.save_png("%s_%s.png" % [_out, tag])])
