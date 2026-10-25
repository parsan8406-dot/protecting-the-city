extends Node2D
## عکس‌گرفتن از دیوارهای زمین، بدون سرور و بدون بقیه‌ی بازی.
##
## فقط چیزهایی را می‌سازد که روی ظاهرِ دیوار اثر دارند — بک‌گراند،
## CanvasModulate با همان رنگِ World.tscn، خودِ Arena، و یک نورِ نقطه‌ای که
## نقشِ چراغِ بازیکن را بازی می‌کند. اگر پخِ لبه‌ها زیرِ این نور برق نزند،
## در بازی هم برق نمی‌زند.
##
## چهار عکس می‌گیرد: نمای کلیِ چیدمانِ اتاق‌ها (wide)، نمای نزدیکِ یک درگاه
## با نورِ بازیکن کنارش (door)، همان دیوار در تاریکیِ مطلق (unlit)، و همان
## قاب در لحظه‌ی شلیک (muzzle). جفتِ unlit/muzzle برای اندازه‌گیریِ عددیِ
## اثرِ نورِ تفنگ است — دو عکس را با هم diff کن.
##
##   godot --path . res://tools/arena_shot.tscn --resolution 1280x720 -- \
##         --out=C:/tmp/arena
## (بدون --headless اجرا شود؛ نورپردازی رندرر واقعی می‌خواهد)

const ARENA := preload("res://scripts/Arena.gd")
const BG := preload("res://assets/Background.png")
const LIGHT_TEX := preload("res://assets/light.png")

## همان رنگی که World.tscn و quick_play.tscn برای CanvasModulate دارند —
## عکس باید با بازی یکی باشد. اگر آن‌جا عوض شد، این‌جا هم عوض کن.
const AMBIENT := Color(0.075, 0.07, 0.105)

var _arena: Node2D = null
var _cam: Camera2D = null
var _light: PointLight2D = null
var _out := ""
var _frames := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)

	var bg := Sprite2D.new()
	bg.texture = BG
	bg.scale = Vector2(0.7022472, 0.7)
	bg.offset = Vector2(1424, 800)
	add_child(bg)

	_arena = ARENA.new()
	_arena.name = "Arena"
	add_child(_arena)

	var cm := CanvasModulate.new()
	cm.color = AMBIENT
	add_child(cm)

	# دقیقاً همان چراغی که World.tscn روی بازیکن دارد — رنگ، انرژی و اندازه.
	# اگر اینجا با نورِ قوی‌ترِ دلخواه تست کنیم، برقِ دیوار در عکس قشنگ
	# می‌افتد ولی در بازی دیده نمی‌شود.
	_light = PointLight2D.new()
	_light.texture = LIGHT_TEX
	_light.color = Color(0.42084792, 0.603903, 1.0)
	_light.energy = 1.0
	_light.scale = Vector2(0.646, 0.466)
	add_child(_light)

	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()

	_frame_whole()


## نمای کلی: کلِ زمین در کادر
func _frame_whole() -> void:
	var vp := get_viewport_rect().size
	var world: Vector2 = _arena.world_size
	_cam.position = world * 0.5
	_cam.zoom = Vector2.ONE * min(vp.x / world.x, vp.y / world.y)
	# در نمای کلی چراغِ بازیکن یک نقطه‌ی کوچک است و چیزی نشان نمی‌دهد؛
	# اینجا فقط چیدمانِ اتاق‌ها را می‌خواهیم، پس نور را پهن می‌کنیم
	_light.position = world * 0.5
	_light.scale = Vector2(6.0, 6.0)


## نمای نزدیک: دوربین و نور کنارِ یک درگاه
func _frame_door() -> void:
	var doors: Array = _arena.get("_doors")
	var focus: Vector2 = _arena.world_size * 0.5
	if doors != null and not doors.is_empty():
		# پهن‌ترین در را انتخاب می‌کنیم تا هر دو تیغه‌ی دیوار در کادر باشند
		var best: Dictionary = doors[0]
		for d in doors:
			if float(d.get("width", 0)) > float(best.get("width", 0)):
				best = d
		if str(best.get("axis", "")) == "v":
			focus = Vector2(float(best.get("x", 0)),
				(float(best.get("y0", 0)) + float(best.get("y1", 0))) * 0.5)
		else:
			focus = Vector2((float(best.get("x0", 0)) + float(best.get("x1", 0))) * 0.5,
				float(best.get("y", 0)))
	# زوم ۲ = همان زومِ دوربینِ بازی، پس اندازه‌ی دیوار روی صفحه واقعی است
	_cam.position = focus
	_cam.zoom = Vector2(2.0, 2.0)
	# چراغ همان‌جایی می‌ایستد که بازیکنِ نزدیک‌شونده به در می‌ایستد،
	# با همان اندازه و انرژیِ چراغِ بازیکن
	_light.position = focus + Vector2(-90, 110)
	_light.scale = Vector2(0.646, 0.466)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 30:
		_save("wide")
		_frame_door()
	elif _frames == 60:
		_save("door")
		_frame_dark_wall()
	elif _frames == 70:
		_save("unlit")
	elif _frames >= 72 and _frames <= 80:
		# پشتِ‌سرِ هم شلیک می‌کنیم: عمرِ هر فلش ۰.۱۲ ثانیه است و خواندنِ
		# بافتِ ویوپورت یکی-دو فریم عقب است، پس با یک شلیکِ تک ممکن است
		# قابِ عکس درست وسطِ خاموشی بیفتد
		CombatFX.muzzle_flash(_muzzle_at, Vector2(0, -1))
		if _frames == 78:
			_save("muzzle")
	elif _frames == 90:
		print("ARENA SHOT OK")
		get_tree().quit(0)


## نمای یک دیوار در تاریکیِ مطلق: چراغِ صحنه خاموش می‌شود تا تنها منبعِ
## نور، شلیک باشد و اثرش قابل اندازه‌گیری بماند.
var _muzzle_at := Vector2.ZERO

func _frame_dark_wall() -> void:
	var rects: Array = _arena.get("_rects")
	var world: Vector2 = _arena.world_size
	var target := world * 0.5
	for r in rects:
		var rect: Rect2 = r
		if rect.position.x < 300.0 or rect.position.y < 300.0:
			continue
		if rect.end.x > world.x - 300.0 or rect.end.y > world.y - 300.0:
			continue
		target = rect.position + rect.size * 0.5
		break
	_cam.position = target
	_cam.zoom = Vector2(2.0, 2.0)
	_light.energy = 0.0                       # تاریکیِ مطلق
	_muzzle_at = target + Vector2(0.0, 70.0)
	print("ARENA dark wall ", target, " muzzle ", _muzzle_at)


func _save(tag: String) -> void:
	var walls := _arena.get_node_or_null("WallArt")
	var glows := _arena.get_node_or_null("DoorGlow")
	print("ARENA %s: wall slabs=%d door glows=%d" % [
		tag,
		walls.get_child_count() if walls != null else -1,
		glows.get_child_count() if glows != null else -1,
	])
	if _out == "":
		return
	var img := get_viewport().get_texture().get_image()
	print("ARENA %s saved err=%d" % [tag, img.save_png("%s_%s.png" % [_out, tag])])

