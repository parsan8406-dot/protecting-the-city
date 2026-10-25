extends Node2D
## گنبدِ محافظِ تولد — پنج ثانیه‌ی اولِ هر بار زنده شدن (عملیات انتقام).
##
## سرور می‌گوید چند ثانیه (shield_seconds در پیامِ respawn، و shield_left در
## هر update_players)؛ این‌جا فقط همان مدت نشان داده می‌شود. یعنی چیزی که
## بازیکن می‌بیند دقیقاً همان چیزی است که سرور اعمال می‌کند: تا وقتی گنبد
## هست، هیچ تیری روی هدف ثبت نمی‌شود.
##
## چرا فرزندِ خودِ بازیکن نیست: Arena کاراکترها را تیره می‌کند (actor_tint) و
## modulate به فرزندها هم می‌رسد — گنبد زیر آن تیرگی خفه می‌شد. پس زیرِ ریشه‌ی
## صحنه ساخته می‌شود و هر فریم روی بازیکن می‌نشیند.
##
## استفاده:
##   var s := preload("res://scripts/spawn_shield.gd").new()
##   world.add_child(s)
##   s.setup(player_node, 5.0)

const SHADER := preload("res://shaders/spawn_shield.gdshader")

## شعاعِ گنبد. بازیکن روی کلاینت شعاع ~۲۹ دارد؛ کمی بزرگ‌تر تا دورش هاله بماند.
const RADIUS := 52.0

## بالای بازیکن‌ها کشیده می‌شود ولی زیرِ رابط کاربری
const SHIELD_Z := 12

var _rect: ColorRect = null
var _mat: ShaderMaterial = null
var _target: Node2D = null
var _left := 0.0
var _total := 0.0


func _ready() -> void:
	z_index = SHIELD_Z
	# نور صحنه نباید روی خودِ گنبد بیفتد: گنبد خودش منبعِ نور است
	_rect = ColorRect.new()
	_rect.size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	_rect.position = -_rect.size * 0.5
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	add_child(_rect)
	set_process(true)


## گنبد را روی یک بازیکن می‌نشاند (یک بار، با انیمیشنِ باز شدن).
## tint اختیاری است: سپرِ دستی (دکمه‌ی سپر) رنگِ خودش را دارد تا با محافظِ
## تولد اشتباه نشود.
func setup(target: Node2D, seconds: float, tint := Color(0, 0, 0, 0)) -> void:
	_target = target
	if tint.a > 0.0 and _mat != null:
		_mat.set_shader_parameter("tint", tint)
	_left = maxf(seconds, 0.0)
	_total = maxf(_left, 0.001)
	if _target != null and is_instance_valid(_target):
		global_position = _target.global_position
	visible = _left > 0.0
	if _mat != null:
		_mat.set_shader_parameter("progress", 1.0)
	# ورودِ گنبد: از هیچ باز می‌شود، مثل حبابی که دورِ بازیکن بسته می‌شود
	scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## زمانِ گنبد را با عددِ تازه‌ی سرور هماهنگ می‌کند — بدونِ انیمیشنِ باز شدن،
## چون گنبد همین حالا هم روی بازیکن است (update_players هر چند ثانیه
## باقی‌مانده را دوباره می‌فرستد).
func refresh(seconds: float) -> void:
	_left = maxf(seconds, 0.0)
	_total = maxf(_total, _left)


## ثانیه‌های باقی‌مانده — world.gd از این می‌فهمد گنبد هنوز زنده است یا نه
func seconds_left() -> float:
	return _left


## گنبد را همین حالا تمام می‌کند.
##
## سرور محافظ را زودتر از پنج ثانیه هم برمی‌دارد: به‌محضِ اینکه بازیکن
## شلیک کند، گنبدش می‌رود. کلاینت باید همان لحظه پاکش کند، وگرنه چیزی
## نشان می‌داد که دیگر واقعی نیست.
func dismiss() -> void:
	if _left <= 0.0:
		return
	_left = 0.0
	_shatter()


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return

	global_position = _target.global_position

	_left -= delta
	if _left <= 0.0:
		_shatter()
		return
	if _mat != null:
		_mat.set_shader_parameter("progress", clampf(_left / _total, 0.0, 1.0))


## پایانِ محافظ: حباب یک ضربِ کوتاه باز می‌شود و محو می‌شود.
func _shatter() -> void:
	set_process(false)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.35, 1.35), 0.22) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(queue_free)
