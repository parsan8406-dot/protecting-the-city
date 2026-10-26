extends Node2D
## صندوقِ تدارکاتِ «بازی سریع» (E2 پاداشِ متغیر، V1 طلایی = ارزش).
##
## کارگردان (psych_play_director.gd) جایش را انتخاب می‌کند؛ این‌جا فقط دیده
## می‌شود و برداشته می‌شود: صندوقِ طلایی با حلقه‌ی تپنده و کمی بالا-پایین
## رفتن (حرکت را دیدِ پیرامونی هم می‌گیرد — V4). بازیکن که رویش رفت
## collected می‌آید. اگر برداشته نشد بعد از مدتی، با چشمک زدن در ۵ ثانیه‌ی
## آخر، می‌رود. برخورد و فیزیک ندارد؛ فقط یک مقایسه‌ی فاصله در هر فریم.

signal collected(pos: Vector2)

const ICON := "res://assets/ui/psych/chest_closed.png"
const PICK_RADIUS := 54.0
const SIZE := 62.0
const COL_GOLD := Color(0.98, 0.8, 0.3)

var _player: Node2D = null
var _life := 25.0
var _t := 0.0
var _sprite: Sprite2D = null
var _done := false


func setup(player: Node2D, life: float) -> void:
	_player = player
	_life = life


func _ready() -> void:
	z_index = 6   # روی کف و زیرِ پلاک‌ها
	# نورِ تاریکِ صحنه نباید طلایی را کدر کند
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	_sprite = Sprite2D.new()
	_sprite.material = mat
	if ResourceLoader.exists(ICON):
		var tex: Texture2D = load(ICON)
		_sprite.texture = tex
		_sprite.scale = Vector2.ONE * (SIZE / maxf(float(tex.get_width()), 1.0))
	add_child(_sprite)
	# فرود: از بالا می‌افتد و کمی جا می‌افتد
	_sprite.position = Vector2(0, -70)
	scale = Vector2(0.4, 0.4)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_sprite, "position", Vector2.ZERO, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_life -= delta
	if _sprite != null:
		_sprite.position.y = -4.0 * absf(sin(_t * 3.2))
	# ۵ ثانیه‌ی آخر چشمک می‌زند تا رفتنش ناگهانی نباشد
	modulate.a = 1.0 if _life > 5.0 else (0.45 + 0.55 * absf(sin(_t * 9.0)))
	queue_redraw()
	if _life <= 0.0:
		_done = true
		queue_free()
		return
	if is_instance_valid(_player) and not _player.get("is_dead") \
			and _player.global_position.distance_to(global_position) <= PICK_RADIUS:
		_done = true
		collected.emit(global_position)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.18)
		tw.tween_property(self, "modulate:a", 0.0, 0.18)
		tw.chain().tween_callback(queue_free)


func _draw() -> void:
	var u := fmod(_t, 1.2) / 1.2
	# حلقه‌ای که باز می‌شود و محو می‌شود + حلقه‌ی ثابت زیرِ صندوق
	draw_arc(Vector2.ZERO, 30.0 + 26.0 * u, 0.0, TAU, 40, Color(COL_GOLD, 0.7 * (1.0 - u)), 3.0, true)
	draw_circle(Vector2(0, 14), 26.0, Color(0, 0, 0, 0.35))
	draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 40, Color(COL_GOLD, 0.85), 2.5, true)
	if _sprite == null or _sprite.texture == null:
		# آرت نرسیده: یک جعبه‌ی طلاییِ ساده
		draw_rect(Rect2(-18, -16, 36, 30), COL_GOLD)
		draw_rect(Rect2(-18, -16, 36, 30), Color(0, 0, 0, 0.9), false, 3.0)
