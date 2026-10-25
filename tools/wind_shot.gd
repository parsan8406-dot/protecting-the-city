extends Node2D
## عکس‌گرفتن از بادِ زمین، بدون سرور و بدون بقیه‌ی بازی.
##
## فقط چیزهایی را می‌سازد که روی ظاهرِ باد اثر دارند — بک‌گراند، خودِ Arena
## (که خودش Wind را می‌سازد)، و یک نورِ نقطه‌ای به جای چراغِ بازیکن. دوربین
## با همان zoom = 2 و همان اندازه‌ی کادرِ بازی می‌ایستد، پس چیزی که در عکس
## می‌بینی همان‌قدر برگ است که بازیکن روی گوشی می‌بیند.
##
## چهار عکس: قبل از وزش (calm)، سرِ بالا آمدنش (rise)، اوجِ وزش (peak) و
## چند ثانیه بعد از خوابیدنش (after). عکسِ calm و after باید تقریباً یکی
## باشند و هیچ برگِ قفل‌شده‌ای در after نماند.
##
##   godot --path . res://tools/wind_shot.tscn --resolution 1280x720 -- \
##         --out=C:/tmp/wind --theme=hell
## (بدون --headless اجرا شود؛ ذره و نور رندررِ واقعی می‌خواهند)

const ARENA := preload("res://scripts/Arena.gd")
const BG := preload("res://assets/Background.png")
const LIGHT_TEX := preload("res://assets/light.png")

var _arena: Node2D = null
var _wind: Node2D = null
var _cam: Camera2D = null
var _out := ""
var _theme := "hell"
## --plain: مشعل و نور خاموش. تنها چیزِ متحرکِ قاب برگ‌ها می‌مانند، پس
## می‌شود با diffِ دو عکس شمردشان.
var _plain := false
## بذرِ الگوی باد — برای تستِ جهت‌های مختلفِ وزش
var _seed := "map"
## کدام زمین: map / revenge / banish
var _map := "map"
## --strip: به‌جای چهار عکسِ کلیدی، یک عکس هر ۰.۳ ثانیه در طولِ وزش —
## برای دیدنِ خودِ انیمیشنِ کشیده‌شدن و پیچیدنِ خطوط
var _strip := false
var _shots: Array = []
var _t := 0.0
var _shot := 0

## [ثانیه, نام]. وزش در ثانیه‌ی ۰.۵ دستی شروع می‌شود.
const SHOTS := [
	[0.40, "calm"],
	[1.60, "rise"],
	[3.20, "peak"],
	[3.32, "peak2"],
	[13.0, "after"],
]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--theme="):
			_theme = a.substr(8)
		elif a == "--plain":
			_plain = true
		elif a.begins_with("--seed="):
			_seed = a.substr(7)
		elif a.begins_with("--map="):
			_map = a.substr(6)
		elif a == "--strip":
			_strip = true

	_shots = SHOTS.duplicate()
	if _strip:
		_shots = []
		for i in 14:
			_shots.append([0.7 + 0.3 * i, "f%02d" % i])

	var bg := Sprite2D.new()
	bg.texture = BG
	bg.scale = Vector2(0.7022472, 0.7)
	bg.offset = Vector2(1424, 800)
	add_child(bg)

	_arena = ARENA.new()
	_arena.name = "Arena"
	if _plain:
		_arena.show_torches = false
		_arena.zone_light_energy = 0.0
		_arena.halo_energy = 0.0
	add_child(_arena)
	_arena.load_map(_map, _theme)
	_wind = _arena.get_node_or_null("Wind")
	if _wind != null and _seed != "map":
		_wind.seed_text = _seed
		_wind._rng.seed = hash(_seed)

	if not _plain:
		_add_player_light()

	# همان کادرِ بازی: zoom ۲ روی وسطِ زمین
	_cam = Camera2D.new()
	_cam.zoom = Vector2(2.0, 2.0)
	_cam.position = _arena.world_size * 0.5
	add_child(_cam)
	_cam.make_current()

	print("WIND harness: wind=%s theme=%s plain=%s" % [str(_wind != null), _theme, str(_plain)])


func _add_player_light() -> void:
	var light := PointLight2D.new()
	light.texture = LIGHT_TEX
	light.color = Color(0.42084792, 0.603903, 1.0)
	light.energy = 1.0
	light.scale = Vector2(0.646, 0.466)
	light.position = _arena.world_size * 0.5
	add_child(light)


func _process(delta: float) -> void:
	_t += delta
	if _t >= 0.5 and _wind != null and _wind.wind_strength() <= 0.0 and _shot <= 1:
		# منتظرِ ۹ تا ۱۷ ثانیه آرامش نمی‌مانیم
		_wind.gust_now()

	while _shot < _shots.size() and _t >= float(_shots[_shot][0]):
		_save(str(_shots[_shot][1]))
		_shot += 1

	if _shot >= _shots.size():
		print("WIND SHOT OK")
		get_tree().quit(0)


func _save(tag: String) -> void:
	var alive := 0
	var emitting := 0
	if _wind != null:
		for c in _wind.get_children():
			if c is CPUParticles2D:
				alive += 1
				if (c as CPUParticles2D).emitting:
					emitting += 1
	var sw := 0
	var sw_txt := ""
	if _wind != null:
		for w in _wind.get("_swirls"):
			if float(w["max_life"]) > 0.0:
				sw += 1
				var spr: Sprite2D = w["spr"]
				sw_txt += " [%s a=%.3f s=%.2f]" % [str(spr.global_position.round()),
					spr.modulate.a, spr.scale.x]
	print("WIND %s t=%.2f strength=%.3f dir=%s layers=%d emitting=%d swirls=%d%s" % [
		tag, _t,
		_wind.wind_strength() if _wind != null else -1.0,
		str(_wind.wind_dir()) if _wind != null else "-",
		alive, emitting, sw, sw_txt,
	])
	if _out == "":
		return
	var img := get_viewport().get_texture().get_image()
	print("WIND %s saved err=%d" % [tag, img.save_png("%s_%s.png" % [_out, tag])])
