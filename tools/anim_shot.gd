extends Node2D
## عکس‌گرفتن از انیمیشن‌های کاراکتر، بدون سرور و بدون زمینِ بازی.
##
## یک player_s.tscn را با همان مقیاس و همان زومِ دوربینِ بازی (۲) می‌آورد،
## یک انیمیشن را پخش می‌کند و در چند لحظه‌ی مشخص از آن عکس می‌گیرد. پس
## اندازه‌ی حرکتی که در عکس می‌بینی دقیقاً همان است که بازیکن روی گوشی
## می‌بیند — و این مهم‌ترین نکته است، چون انیمیشن‌های قبلی روی کاغذ درست
## بودند ولی در این مقیاس دیده نمی‌شدند.
##
##   godot --path . res://tools/anim_shot.tscn --resolution 1280x720 -- \
##         --out=C:/tmp/anim --anim=reload --frames=10
##
## پس‌زمینه عمداً خاکستریِ ساده است تا فقط خودِ کاراکتر دیده شود.

const PLAYER := preload("res://secense/player_s.tscn")
## 🌟 اسکینِ کاراکتر و اسلحه هم مثلِ بازیِ واقعی اعمال می‌شود.
##
## قبلاً فقط یک بافتِ اسلحه روی نود گذاشته می‌شد و ترنسفورمِ کهنه‌ی صحنه
## می‌ماند؛ نتیجه این شد که عکس درست به‌نظر می‌رسید ولی در بازی اسلحه کج و
## جابه‌جا بود — چون WeaponSkin.apply() ترنسفورمِ دیگری می‌نشاند. حالا
## هرچه اینجا می‌بینی همان است که بازیکن می‌بیند.
const SKIN_ID := "skin_default"
const WEAPON_ID := "ak47"

var _p: Node2D = null
var _anim: AnimationPlayer = null
var _name := "idle"
var _out := ""
var _frames := 8
var _t := 0.0
var _shot := 0
var _len := 1.0
var _loop := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--anim="):
			_name = a.substr(7)
		elif a.begins_with("--frames="):
			_frames = maxi(int(a.substr(9)), 2)

	# پس‌زمینه با رنگِ پاک‌کننده‌ی رندرر، نه یک ColorRect: ColorRect در
	# مختصاتِ جهان می‌نشیند و با دوربینِ وسط، فقط یک‌چهارمِ کادر را می‌پوشاند.
	RenderingServer.set_default_clear_color(Color(0.20, 0.21, 0.24))

	_p = PLAYER.instantiate()
	_p.set_physics_process(false)
	_p.set_process(false)
	add_child(_p)
	_p.global_position = Vector2.ZERO
	# نوارِ جان و پلاکِ اسم جلوی خودِ کاراکتر را می‌گیرند و به انیمیشن
	# ربطی ندارند
	for n in ["HealthBar", "HealthLabel", "FoePlate"]:
		var x := _p.get_node_or_null(n)
		if x != null:
			x.visible = false

	if _p.has_method("setup_appearance"):
		_p.setup_appearance(SKIN_ID, WEAPON_ID)

	_anim = _p.get_node_or_null("AnimationPlayer")
	if _anim == null:
		print("ANIM harness: AnimationPlayer نیست")
		get_tree().quit(1)
		return
	if not _anim.has_animation(_name):
		print("ANIM harness: انیمیشنِ «%s» نیست. هست: %s"
			% [_name, str(_anim.get_animation_list())])
		get_tree().quit(1)
		return

	var res := _anim.get_animation(_name)
	_len = res.length
	_loop = res.loop_mode != Animation.LOOP_NONE
	# 🌟 حالتِ دستی: مخلوط‌کن خودش هیچ‌وقت جلو نمی‌رود و فقط با seekِ ما
	# ژست عوض می‌شود. با pause() تنها کافی نبود — صحنه autoplay = idle دارد
	# و فریم‌های بعدی باز هم جلو می‌رفتند، پس عکسِ هر فریم مالِ زمانِ دیگری
	# بود و مقایسه بی‌معنی می‌شد.
	_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_anim.stop()
	_anim.play(_name)

	var cam := Camera2D.new()
	cam.zoom = Vector2(2.0, 2.0)   # همان زومِ دوربینِ بازی
	cam.position = Vector2(0, 14)  # وسطِ بدنِ کاراکتر، نه ریشه‌اش
	add_child(cam)
	cam.make_current()

	print("ANIM %s: length=%.3f loop=%d" % [_name, _len,
		_anim.get_animation(_name).loop_mode])


## ژستِ خواسته‌شده را می‌نشاند، دو فریم صبر می‌کند تا هم پوستِ Polygon2D
## به‌روز شود و هم بافتِ ویوپورت همان قاب را داشته باشد، بعد عکس می‌گیرد.
##
## با await داخلِ _process این کار غلط از آب درآمد: موتور هر فریم دوباره
## _process را صدا می‌زند و چند نسخه‌ی نیمه‌کاره هم‌زمان می‌شدند، پس شماره‌ی
## فریم و ژست به هم نمی‌خوردند. اینجا هیچ awaitای نیست.
var _wait := 0
var _pending := false

func _process(delta: float) -> void:
	if _t < 0.25:
		_t += delta
		return
	if _wait > 0:
		_wait -= 1
		return
	if _pending:
		_save("%02d" % _shot, _at(_shot))
		_pending = false
		_shot += 1
		return
	if _shot >= _frames:
		print("ANIM SHOT OK")
		get_tree().quit(0)
		return

	# در حالتِ دستی تنها راهِ نشاندنِ ژست advance است: از صفر شروع می‌کنیم و
	# دقیقاً به اندازه‌ی زمانِ این فریم جلو می‌رویم. (seek در این حالت فقط
	# زمان را می‌برد و ترک‌ها را روی نودها نمی‌نشاند.)
	_anim.play(_name)
	_anim.seek(0.0, false)
	_anim.advance(_at(_shot))
	_pending = true
	_wait = 2


## زمانِ فریمِ iام. برای انیمیشنِ حلقه‌ای فریمِ آخر با فریمِ اول یکی می‌شد،
## پس یک گام کمتر برمی‌داریم و چرخه کامل ولی بدونِ تکرار دیده می‌شود.
func _at(i: int) -> float:
	var span := float(_frames) if _loop else float(_frames - 1)
	return clampf(_len * float(i) / span, 0.0, _len - 0.0005)


func _save(tag: String, at: float) -> void:
	var g := _p.get_node_or_null("gun")
	var head := _p.get_node_or_null("Sprite2D/Head")
	# مقدارِ خودِ Animation هم چاپ می‌شود: اگر با مقدارِ نود یکی نبود، یعنی
	# چیزی جز این انیمیشن دارد روی ژست اثر می‌گذارد
	var want := "-"
	var res := _anim.get_animation(_name)
	for i in res.get_track_count():
		if str(res.track_get_path(i)) == "Sprite2D/Head:position":
			want = str((res.value_track_interpolate(i, at) as Vector2).round())
	print("ANIM %s f%s t=%.3f gun=%s rot=%.3f head=%s (انتظار %s)" % [
		_name, tag, at,
		str(g.position.round()) if g != null else "-",
		g.rotation if g != null else 0.0,
		str(head.position.round()) if head != null else "-",
		want,
	])
	if _out == "":
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s_%s_%s.png" % [_out, _name, tag])
