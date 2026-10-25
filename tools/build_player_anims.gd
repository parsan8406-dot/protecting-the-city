extends SceneTree
## انیمیشن‌های کاراکتر را می‌سازد: res://resources/player_anims.tres
##
## چرا اسکریپت و نه ویرایش دستیِ صحنه: همین رگِ کاراکتر در سه صحنه تکرار
## شده (World، quick_play، player_s). قبلاً هر سه یک کپیِ جداگانه از
## انیمیشن‌ها داشتند و هر تغییری باید سه بار انجام می‌شد — و یادت می‌رفت.
## حالا هر سه به یک AnimationLibrary اشاره می‌کنند و این فایل تنها جایی
## است که عددها عوض می‌شوند.
##
## اجرا:
##   godot --headless --path . --script res://tools/build_player_anims.gd
##
## دیدنِ نتیجه:
##   godot --path . res://tools/anim_shot.tscn --resolution 1280x720 -- \
##         --out=C:/tmp/anim --anim=reload
##
## نکته‌ی مهمِ مقیاس — نگاهِ بازی از بالاست و کاراکتر کوچک است:
##   ۱ واحدِ استخوان  = ۱ پیکسلِ صفحه   (scale بدنه ۰.۵ × zoom دوربین ۲)
##   ۱ واحدِ Head/gun = ۰.۱۶ پیکسلِ صفحه (چون داخلِ Sprite2Dِ ۰.۱۵۸ هستند)
## برای همین جابه‌جاییِ سر عددهای بزرگ دارد و چرخشِ استخوان عددهای کوچک.
## بازوی کاراکتر ~۵۳ واحد است، پس ۰.۲ رادیان روی شانه یعنی ~۱۱ پیکسل
## جابه‌جاییِ دست. انیمیشن‌های قبلی ۰.۰۲ رادیان بودند (~۱ پیکسل) و عملاً
## دیده نمی‌شدند.

const OUT := "res://resources/player_anims.tres"

# --- مسیرِ استخوان‌ها و نودها (در هر سه صحنه یکی است) ---
const ROOT := "Body/Bone2D"
const TORSO := "Body/Bone2D/Bone2D"
const RSH := "Body/Bone2D/Bone2D/Bone2D2"
const LSH := "Body/Bone2D/Bone2D/Bone2D3"
const RUP := "Body/Bone2D/Bone2D/Bone2D2/RArmRoot/RArmUpper"
const RFORE := RUP + "/RForearm"
const RHAND := RFORE + "/RHand"
const LUP := "Body/Bone2D/Bone2D/Bone2D3/LArmRoot/LArmUpper"
const LFORE := LUP + "/LForearm"
const LHAND := LFORE + "/LHand"
const HEAD := "Sprite2D/Head"
const GUN := "gun"

# --- حالتِ استراحتِ رگ. اگر در صحنه عوض شد، اینجا هم باید عوض شود. ---
const ROOT_REST := Vector2(0, -12.424)
const HEAD_REST := Vector2(-11, 68)
## 🌟 رستِ اسلحه از WeaponSkin می‌آید نه از صحنه.
##
## WeaponSkin.apply() موقعِ بازی rotation، scale و position نودِ gun را
## خودش می‌نشاند (آرتِ جدیدِ اسلحه‌ها افقی است و نود ۹۰ درجه می‌چرخد).
## عددهای داخلِ صحنه مالِ آرتِ قدیمی‌اند و دیگر درست نیستند. اگر انیمیشن
## آن عددهای قدیمی را بنویسد، اسلحه ۲۷۰ درجه کج و جابه‌جا می‌شود.
##
## پس: هیچ ترکی rotationِ اسلحه را دست نمی‌زند — لوله همیشه هم‌راستای بدن و
## رو به بیرون می‌ماند — و positionش فقط به اندازه‌ی همان جابه‌جاییِ بدن
## تکان می‌خورد تا از دست‌ها جدا نیفتد.
##
## ⚠ اگر WeaponSkin.SPRITE_POSITION عوض شد، این فایل را دوباره اجرا کن.
const GUN_REST: Vector2 = preload("res://scripts/WeaponSkin.gd").SPRITE_POSITION

## جهت‌ها (بدنه رو به بالای صفحه است):
##   استخوان: y کمتر = جلوتر،  x بیشتر = راست
##   Head داخلِ Sprite2Dِ ۱۸۰ درجه چرخیده، پس برعکس: y بیشتر = جلوتر،
##   x کمتر = راست
##   gun بچه‌ی مستقیمِ بدنه است، پس مثلِ استخوان: y کمتر = جلوتر


func _initialize() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation("RESET", _reset())
	lib.add_animation("idle", _idle())
	lib.add_animation("walk", _walk())
	lib.add_animation("run", _run())
	lib.add_animation("shoot", _shoot())
	lib.add_animation("reload", _reload())

	var err := ResourceSaver.save(lib, OUT)
	print("player_anims: %s  err=%d  انیمیشن‌ها: %s"
		% [OUT, err, str(lib.get_animation_list())])
	quit(0 if err == OK else 1)


# ============================ ابزار ============================

func _anim(length: float, loop := false) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	return a


## یک ترکِ value. cubic برای حرکتِ نرمِ ارگانیک، linear برای ضربه‌های تند.
func _t(a: Animation, path: String, times: Array, values: Array,
		cubic := true) -> void:
	var i := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(i, NodePath(path))
	a.value_track_set_update_mode(i, Animation.UPDATE_CONTINUOUS)
	a.track_set_interpolation_type(i, Animation.INTERPOLATION_CUBIC
		if cubic else Animation.INTERPOLATION_LINEAR)
	# در انیمیشنِ غیرِ حلقه‌ای، loop_wrap باعث می‌شود منحنیِ cubic سرِ آخرین
	# کلید از کلیدِ اولِ همان ترک تانژانت بگیرد و از حالتِ استراحت رد کند —
	# یعنی shoot و reload یک ژستِ کج به جا می‌گذارند.
	a.track_set_interpolation_loop_wrap(i, a.loop_mode != Animation.LOOP_NONE)
	for k in times.size():
		a.track_insert_key(i, float(times[k]), values[k])


## جابه‌جاییِ ریشه‌ی بدن: dy منفی = جلو، dx مثبت = راست
func _root(dx: float, dy: float) -> Vector2:
	return ROOT_REST + Vector2(dx, dy)


## سر: fwd مثبت = جلو، right مثبت = راست (هر دو در واحدِ Sprite2D)
func _head(right: float, fwd: float) -> Vector2:
	return HEAD_REST + Vector2(-right, fwd)


## اسلحه با بدن می‌رود: همان dx و dy که به _root داده‌ای را بده تا اسلحه
## روی دست‌ها بماند. (فقط جابه‌جایی — چرخش هیچ‌وقت.)
func _gun(dx: float, dy: float) -> Vector2:
	return GUN_REST + Vector2(dx, dy)


# ============================ RESET ============================

## همه‌ی چیزهایی که هر انیمیشنی دست می‌زند اینجا به حالتِ استراحت برمی‌گردد،
## وگرنه پریدن از reload به idle یک دستِ کج جا می‌گذارد.
func _reset() -> Animation:
	var a := _anim(0.001)
	_t(a, ROOT + ":position", [0], [ROOT_REST])
	_t(a, ROOT + ":rotation", [0], [0.0])
	_t(a, TORSO + ":rotation", [0], [0.0])
	_t(a, TORSO + ":scale", [0], [Vector2.ONE])
	_t(a, RSH + ":rotation", [0], [0.0])
	_t(a, LSH + ":rotation", [0], [0.0])
	_t(a, RUP + ":rotation", [0], [0.0])
	_t(a, RFORE + ":rotation", [0], [0.0])
	_t(a, RHAND + ":rotation", [0], [0.0])
	_t(a, LUP + ":rotation", [0], [0.0])
	_t(a, LFORE + ":rotation", [0], [0.0])
	_t(a, LHAND + ":rotation", [0], [0.0])
	_t(a, HEAD + ":position", [0], [HEAD_REST])
	_t(a, HEAD + ":rotation", [0], [0.0])
	# چرخشِ اسلحه عمداً اینجا هم نیست: مالِ WeaponSkin است و RESET نباید
	# آن را به عددِ کهنه‌ی صحنه برگرداند.
	_t(a, GUN + ":position", [0], [GUN_REST])
	return a


# ============================ idle ============================

## ایستادنِ آماده‌باش: نفس کشیدن (قفسه‌ی سینه باز و بسته می‌شود) روی یک
## چرخه‌ی ۳.۲ ثانیه‌ای، و یک تابِ کندترِ وزن روی پاها که اسلحه را آرام
## چپ و راست می‌برد. اسلحه و سر با همان تاب می‌روند تا جدا به‌نظر نرسند.
func _idle() -> Animation:
	var a := _anim(3.2, true)
	# نفس: سینه باز می‌شود و بدن کمی جلو می‌آید
	_t(a, TORSO + ":scale", [0.0, 1.6, 3.2],
		[Vector2.ONE, Vector2(1.055, 1.075), Vector2.ONE])
	_t(a, ROOT + ":position", [0.0, 1.6, 3.2],
		[_root(0, 0), _root(0, -2.8), _root(0, 0)])
	# تابِ وزن روی پاها — عمداً کم‌دامنه‌تر از راه رفتن، وگرنه ایستادن هم
	# شبیهِ قدم زدن می‌شود و دو حالت از هم جدا نمی‌شوند
	_t(a, ROOT + ":rotation", [0.0, 0.8, 1.6, 2.4, 3.2],
		[0.0, 0.018, 0.0, -0.018, 0.0])
	_t(a, TORSO + ":rotation", [0.0, 0.8, 1.6, 2.4, 3.2],
		[0.0, -0.024, 0.0, 0.024, 0.0])
	_t(a, RSH + ":rotation", [0.0, 1.6, 3.2], [0.0, -0.030, 0.0])
	_t(a, LSH + ":rotation", [0.0, 1.6, 3.2], [0.0, 0.030, 0.0])
	# دو بازو با هم می‌روند — اسلحه دو دستی است و باید یک‌پارچه تاب بخورد
	for p in [RUP, LUP]:
		_t(a, p + ":rotation", [0.0, 0.8, 1.6, 2.4, 3.2],
			[0.0, 0.042, 0.0, -0.042, 0.0])
	for p in [RFORE, LFORE]:
		_t(a, p + ":rotation", [0.0, 0.8, 1.6, 2.4, 3.2],
			[0.0, -0.028, 0.0, 0.028, 0.0])
	for p in [RHAND, LHAND]:
		_t(a, p + ":rotation", [0.0, 0.8, 1.6, 2.4, 3.2],
			[0.0, 0.014, 0.0, -0.014, 0.0])
	# اسلحه فقط با نفسِ بدن جلو و عقب می‌رود — هم‌راستا و بی‌چرخش
	_t(a, GUN + ":position", [0.0, 1.6, 3.2],
		[_gun(0, 0), _gun(0, -2.8), _gun(0, 0)])
	# سر: کمی جلو با نفس، و تابِ ملایم با بدن
	_t(a, HEAD + ":position", [0.0, 0.8, 1.6, 2.4, 3.2],
		[_head(0, 0), _head(6, 16), _head(0, 32), _head(-6, 16), _head(0, 0)])
	_t(a, HEAD + ":rotation", [0.0, 0.8, 1.6, 2.4, 3.2],
		[0.0, 0.032, 0.0, -0.032, 0.0])
	return a


# ============================ راه رفتن ============================

## چرخه‌ی دو قدمی. چون اسلحه دو دستی است، بازوها مثلِ راه‌رفتنِ معمولی
## متناوب تاب نمی‌خورند (آن‌وقت دست‌ها از اسلحه جدا می‌شوند)؛ به‌جایش کلِ
## بالاتنه با هر قدم چپ و راست می‌شود و بدن بالا-پایین می‌زند — همان حسِ
## «راه رفتن با اسلحه‌ی آماده».
##
## step = طولِ یک قدم. بدن در هر قدم یک بار به پهلو می‌رود و در هر نیم‌قدم
## یک بار بالا-پایین (فرکانسِ دوبرابر) — همین دوگانگی است که قدم را قدم
## نشان می‌دهد نه تابِ ساده.
func _stride(a: Animation, step: float, sway: float, bob: float,
		roll: float, arm: float, head_sway: float, lean: float) -> void:
	var t2 := step * 2.0
	var q := step * 0.5
	_t(a, ROOT + ":position", [0.0, q, step, step + q, t2],
		[_root(0, lean), _root(sway, lean - bob), _root(0, lean),
			_root(-sway, lean - bob), _root(0, lean)])
	_t(a, ROOT + ":rotation", [0.0, q, step, step + q, t2],
		[0.0, roll, 0.0, -roll, 0.0])
	_t(a, TORSO + ":rotation", [0.0, q, step, step + q, t2],
		[0.0, -roll * 0.7, 0.0, roll * 0.7, 0.0])
	# فشرده شدنِ بدن در لحظه‌ی فرود آمدنِ قدم
	_t(a, TORSO + ":scale", [0.0, q, step, step + q, t2],
		[Vector2.ONE, Vector2(1.03, 0.975), Vector2.ONE,
			Vector2(1.03, 0.975), Vector2.ONE])
	_t(a, RSH + ":rotation", [0.0, q, step, step + q, t2],
		[0.0, -arm * 0.5, 0.0, arm * 0.5, 0.0])
	_t(a, LSH + ":rotation", [0.0, q, step, step + q, t2],
		[0.0, -arm * 0.5, 0.0, arm * 0.5, 0.0])
	for p in [RUP, LUP]:
		_t(a, p + ":rotation", [0.0, q, step, step + q, t2],
			[0.0, arm, 0.0, -arm, 0.0])
	for p in [RFORE, LFORE]:
		_t(a, p + ":rotation", [0.0, q, step, step + q, t2],
			[0.0, -arm * 0.55, 0.0, arm * 0.55, 0.0])
	# اسلحه عینِ همان مسیرِ ریشه‌ی بدن را می‌رود، نه یک واحد کم‌تر و نه
	# بیش‌تر: اگر بدن تاب بخورد و اسلحه سرِ جایش بماند، از دست‌ها کنده
	# به‌نظر می‌رسد. چرخشش هیچ‌وقت عوض نمی‌شود.
	_t(a, GUN + ":position", [0.0, q, step, step + q, t2],
		[_gun(0, lean), _gun(sway, lean - bob), _gun(0, lean),
			_gun(-sway, lean - bob), _gun(0, lean)])
	# سر با تأخیرِ نیم‌قدم دنبالِ بدن می‌رود. دامنه‌اش عمداً خیلی کمتر از
	# تابِ بدن است: سر روی گردن است و مثلِ تنه تکان نمی‌خورد؛ با عددِ بزرگ
	# انگار از بدن جدا می‌شود و می‌لرزد.
	_t(a, HEAD + ":position", [0.0, q, step, step + q, t2],
		[_head(0, 0), _head(head_sway, -6), _head(0, 0),
			_head(-head_sway, -6), _head(0, 0)])
	_t(a, HEAD + ":rotation", [0.0, q, step, step + q, t2],
		[0.0, -roll * 0.55, 0.0, roll * 0.55, 0.0])


func _walk() -> Animation:
	var a := _anim(0.72, true)
	_stride(a, 0.36, 4.2, 3.0, 0.085, 0.10, 15.0, 0.0)
	return a


## دویدن: همان چرخه، تندتر و درشت‌تر، با کمی خم شدن به جلو
func _run() -> Animation:
	var a := _anim(0.52, true)
	_stride(a, 0.26, 6.4, 5.0, 0.135, 0.165, 24.0, -3.0)
	return a


# ============================ شلیک ============================

## لگدِ شلیک. کلیدش تندیِ رفت و کندیِ برگشت است: در ۳ صدمِ ثانیه همه‌چیز
## عقب می‌پرد و بعد در ربع ثانیه با یک سرریزِ کوچک سرِ جایش می‌نشیند.
## اسلحه بیشتر از بدن عقب می‌رود و دماغه‌اش بالا می‌زند — همان چیزی که
## «شلیک شد» را بدونِ صدا هم می‌فهماند.
func _shoot() -> Animation:
	var a := _anim(0.28)
	var kick := 0.035   # لحظه‌ی اوجِ لگد
	# بدن عقب می‌پرد، کمی سرریز به جلو، بعد استراحت
	_t(a, ROOT + ":position", [0.0, kick, 0.12, 0.20, 0.28],
		[_root(0, 0), _root(0, 8.5), _root(0, -1.6), _root(0, 0.5), _root(0, 0)],
		false)
	_t(a, TORSO + ":scale", [0.0, kick, 0.14, 0.28],
		[Vector2.ONE, Vector2(1.06, 0.93), Vector2(0.985, 1.02), Vector2.ONE])
	# شانه‌ها جمع می‌شوند
	_t(a, RSH + ":rotation", [0.0, kick, 0.16, 0.28], [0.0, 0.085, -0.02, 0.0])
	_t(a, LSH + ":rotation", [0.0, kick, 0.16, 0.28], [0.0, -0.085, 0.02, 0.0])
	# بازوها عقب می‌آیند و بعد برمی‌گردند
	for p in [RUP, LUP]:
		_t(a, p + ":rotation", [0.0, kick, 0.15, 0.28], [0.0, 0.26, -0.05, 0.0])
	for p in [RFORE, LFORE]:
		_t(a, p + ":rotation", [0.0, kick, 0.15, 0.28], [0.0, -0.20, 0.04, 0.0])
	for p in [RHAND, LHAND]:
		_t(a, p + ":rotation", [0.0, kick, 0.15, 0.28], [0.0, 0.14, -0.03, 0.0])
	# اسلحه با بدن عقب می‌نشیند و کمی بیشتر از آن — لگد از خودِ اسلحه
	# می‌آید. لوله نمی‌چرخد؛ فقط در راستای خودش عقب و جلو می‌رود.
	_t(a, GUN + ":position", [0.0, kick, 0.12, 0.20, 0.28],
		[_gun(0, 0), _gun(0, 10.5), _gun(0, -1.8), _gun(0, 0.5), _gun(0, 0)],
		false)
	# سر عقب می‌رود
	_t(a, HEAD + ":position", [0.0, kick, 0.14, 0.28],
		[_head(0, 0), _head(0, -52), _head(0, 8), _head(0, 0)], false)
	_t(a, HEAD + ":rotation", [0.0, kick, 0.16, 0.28], [0.0, 0.05, -0.012, 0.0])
	return a


# ============================ تعویضِ خشاب ============================

## یک و نیم ثانیه، در پنج تکه:
##   ۱. اسلحه کج می‌شود و بدن کمی عقب می‌کشد          (۰ تا ۰.۲۵)
##   ۲. دستِ چپ پایین می‌رود و خشاب را می‌کشد بیرون    (۰.۲۵ تا ۰.۵۵)
##   ۳. دست تا کمر می‌رود و خشابِ تازه را می‌گیرد       (۰.۵۵ تا ۰.۹)
##   ۴. برمی‌گردد بالا و خشاب را می‌کوبد داخل          (۰.۹ تا ۱.۲۵)
##   ۵. گلنگدن کشیده و رها می‌شود، بدن سرِ جایش می‌نشیند (۱.۲۵ تا ۱.۶)
##
## دستِ راست تمامِ مدت اسلحه را نگه داشته و فقط کجش می‌کند — همان کاری که
## آدم واقعی می‌کند. طولِ انیمیشن ۱.۶ ثانیه است، برابرِ reload_seconds؛
## player.gd با custom_speed با هر سلاحی جورش می‌کند.
func _reload() -> Animation:
	var a := _anim(1.6)
	# بدن: عقب می‌کشد، پایینِ کار خم می‌ماند، آخرش صاف می‌شود
	_t(a, ROOT + ":position", [0.0, 0.25, 0.9, 1.25, 1.35, 1.6],
		[_root(0, 0), _root(0, 4.0), _root(0, 5.0), _root(0, 2.0),
			_root(0, 6.5), _root(0, 0)])
	_t(a, ROOT + ":rotation", [0.0, 0.3, 0.9, 1.3, 1.6],
		[0.0, -0.05, -0.07, -0.03, 0.0])
	_t(a, TORSO + ":rotation", [0.0, 0.3, 0.9, 1.3, 1.6],
		[0.0, 0.07, 0.09, 0.04, 0.0])
	_t(a, TORSO + ":scale", [0.0, 0.3, 1.25, 1.32, 1.6],
		[Vector2.ONE, Vector2(1.02, 0.98), Vector2(1.02, 0.98),
			Vector2(1.05, 0.95), Vector2.ONE])

	# --- دستِ چپ: خشاب ---
	# مثبت = از اسلحه فاصله می‌گیرد و پایین می‌رود
	_t(a, LSH + ":rotation", [0.0, 0.3, 0.9, 1.15, 1.6],
		[0.0, 0.16, 0.22, 0.04, 0.0])
	_t(a, LUP + ":rotation", [0.0, 0.25, 0.55, 0.9, 1.1, 1.2, 1.6],
		[0.0, 0.34, 0.86, 0.95, 0.10, -0.06, 0.0])
	_t(a, LFORE + ":rotation", [0.0, 0.25, 0.55, 0.9, 1.1, 1.2, 1.6],
		[0.0, 0.30, 0.72, 0.80, 0.08, -0.05, 0.0])
	_t(a, LHAND + ":rotation", [0.0, 0.25, 0.55, 0.9, 1.15, 1.6],
		[0.0, -0.22, -0.45, -0.40, 0.06, 0.0])

	# --- دستِ راست: اسلحه را نگه می‌دارد، آخرش گلنگدن را می‌کشد ---
	_t(a, RSH + ":rotation", [0.0, 0.3, 1.25, 1.35, 1.6],
		[0.0, -0.05, -0.05, 0.06, 0.0])
	_t(a, RUP + ":rotation", [0.0, 0.3, 1.2, 1.35, 1.45, 1.6],
		[0.0, -0.11, -0.11, 0.16, -0.05, 0.0])
	_t(a, RFORE + ":rotation", [0.0, 0.3, 1.2, 1.35, 1.45, 1.6],
		[0.0, 0.09, 0.09, -0.24, 0.05, 0.0])
	_t(a, RHAND + ":rotation", [0.0, 0.3, 1.35, 1.45, 1.6],
		[0.0, -0.06, 0.18, -0.04, 0.0])

	# --- اسلحه: با بدن عقب کشیده می‌شود و سرِ کوبیدنِ خشاب و گلنگدن تکان
	# می‌خورد. نه می‌چرخد و نه به پهلو می‌رود — لوله همیشه رو به بیرون.
	_t(a, GUN + ":position", [0.0, 0.25, 0.9, 1.25, 1.3, 1.35, 1.44, 1.6],
		[_gun(0, 0), _gun(0, 4.0), _gun(0, 5.0), _gun(0, 2.0),
			_gun(0, 7.5), _gun(0, 6.5), _gun(0, 3.5), _gun(0, 0)])

	# --- سر: نگاه می‌کند به کاری که دست می‌کند ---
	_t(a, HEAD + ":position", [0.0, 0.35, 0.9, 1.25, 1.35, 1.6],
		[_head(0, 0), _head(-26, -30), _head(-34, -38), _head(-14, -12),
			_head(0, -26), _head(0, 0)])
	_t(a, HEAD + ":rotation", [0.0, 0.35, 0.9, 1.3, 1.6],
		[0.0, -0.13, -0.17, -0.06, 0.0])
	return a
