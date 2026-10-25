extends Control
## جوی‌استیکِ پایین-چپ، به سبکِ عکسِ مرجع: حلقه‌ی تیره با چهار فلشِ جهت و
## یک دستگیره‌ی نقره‌ای.
##
## همیشه سرِ جایش دیده می‌شود (کم‌رنگ). هر لمس در نیمه‌ی چپ و پایینِ صفحه
## آن را زیرِ همان انگشت می‌آورد — تا شست مجبور نباشد دقیقاً روی دایره
## بیفتد — و با برداشتنِ انگشت به جای اولش برمی‌گردد.
##
## فقط انگشتِ خودش را دنبال می‌کند (touch_index)، پس هم‌زمان با شلیک و
## دکمه‌ها با انگشتِ دیگر قاطی نمی‌شود. لمسی که روی دکمه‌های گروهِ
## touch_exclude بیفتد (بمب، درمان، ...) اصلاً به جوی‌استیک نمی‌رسد.

const COL_BASE   := Color(0.05, 0.045, 0.06, 0.55)
const COL_RING   := Color(0.85, 0.82, 0.78, 0.55)
const COL_ARROW  := Color(0.92, 0.9, 0.86, 0.75)
const COL_KNOB   := Color(0.86, 0.86, 0.88, 0.95)
const COL_KNOB_D := Color(0.55, 0.55, 0.6, 1.0)

## اندازه‌ها به واحدِ طراحی؛ ui_scale از GameHUD می‌آید
const BASE_R := 92.0
const KNOB_R := 36.0
## کسری از عرض/ارتفاعِ صفحه که لمس در آن جوی‌استیک را فعال می‌کند
const ZONE_W := 0.45
const ZONE_TOP := 0.3
## کسری از max_length که در آن جوی‌استیک صفر حساب می‌شود (لرزشِ انگشت)
const DEAD_ZONE := 0.15

## بیشترین فاصله‌ی دستگیره از مرکز (پیکسلِ صفحه)
var max_length := 70.0
var touch_index := -1
## جهتِ نهایی — player.gd از این می‌خواند
var joystick_vector := Vector2.ZERO
## false یعنی لمس‌ها نادیده گرفته می‌شوند (مرگ، پنجره‌ی باز)
var enabled := true

var _ui_scale := 1.0
var _rest := Vector2(160, 520)
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# اسپرایت‌های قدیمیِ صحنه اگر مانده باشند دیگر لازم نیستند
	for n in ["Base", "Knob"]:
		var old := get_node_or_null(n)
		if old != null:
			old.hide()
	global_position = _rest


## GameHUD با هر تغییرِ اندازه‌ی صفحه جا و مقیاس را می‌دهد (پیکسلِ صفحه)
func configure(rest: Vector2, ui_scale: float) -> void:
	_rest = rest
	_ui_scale = ui_scale
	max_length = 70.0 * ui_scale
	if touch_index == -1:
		global_position = _rest
	queue_redraw()


func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		_release()
	visible = on


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1:
			if not _in_zone(event.position) or _is_touch_excluded(event.position):
				return
			touch_index = event.index
			# اگر انگشت روی خودِ دایره افتاده همان‌جا بماند؛ وگرنه زیرِ انگشت بیاید
			if event.position.distance_to(_rest) > BASE_R * _ui_scale:
				global_position = event.position
			else:
				global_position = _rest
			_drag_to(event.position)
		elif not event.pressed and event.index == touch_index:
			_release()

	elif event is InputEventScreenDrag and event.index == touch_index:
		_drag_to(event.position)


func _drag_to(pos: Vector2) -> void:
	var v := pos - global_position
	if v.length() > max_length:
		v = v.normalized() * max_length
	_knob = v
	# ناحیه‌ی مرده: لرزشِ ریزِ شست نزدیکِ مرکز کاراکتر را دور خودش نچرخاند.
	# بیرون از آن دوباره از صفر تا یک کِش می‌آید تا حرکتِ آرام هم ممکن بماند.
	var raw := v / max_length
	var l := raw.length()
	if l < DEAD_ZONE:
		joystick_vector = Vector2.ZERO
	else:
		joystick_vector = raw.normalized() * minf((l - DEAD_ZONE) / (1.0 - DEAD_ZONE), 1.0)
	queue_redraw()


func _release() -> void:
	touch_index = -1
	joystick_vector = Vector2.ZERO
	_knob = Vector2.ZERO
	global_position = _rest
	queue_redraw()


func _in_zone(pos: Vector2) -> bool:
	var vp := get_viewport_rect().size
	return pos.x <= vp.x * ZONE_W and pos.y >= vp.y * ZONE_TOP


## آیا لمس روی یکی از دکمه‌هایی افتاده که نباید جوی‌استیک قاپشان بزند؟
## دکمه‌ها با add_to_group("touch_exclude") خودشان را معرفی می‌کنند.
func _is_touch_excluded(pos: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("touch_exclude"):
		if node is Control and node.is_visible_in_tree():
			if (node as Control).get_global_rect().has_point(pos):
				return true
	return false


func _draw() -> void:
	var s := _ui_scale
	var active := touch_index != -1
	var r := BASE_R * s
	draw_circle(Vector2.ZERO, r, COL_BASE if active else Color(COL_BASE.r, COL_BASE.g, COL_BASE.b, 0.35))
	draw_arc(Vector2.ZERO, r, 0, TAU, 56, COL_RING, 2.5 * s, true)
	draw_arc(Vector2.ZERO, r * 0.72, 0, TAU, 48, Color(COL_RING.r, COL_RING.g, COL_RING.b, 0.18), 1.5 * s, true)

	# چهار فلشِ جهت
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var tip: Vector2 = d * r * 0.86
		var back: Vector2 = d * r * 0.7
		var side: Vector2 = d.orthogonal() * r * 0.1
		draw_polyline(PackedVector2Array([back + side, tip, back - side]),
			COL_ARROW if active else Color(COL_ARROW.r, COL_ARROW.g, COL_ARROW.b, 0.45), 3.0 * s, true)

	# دستگیره
	var kr := KNOB_R * s
	draw_circle(_knob + Vector2(0, 3.0 * s), kr, Color(0, 0, 0, 0.35))
	draw_circle(_knob, kr, COL_KNOB_D)
	draw_circle(_knob + Vector2(0, -kr * 0.12), kr * 0.86, COL_KNOB)
	draw_circle(_knob + Vector2(-kr * 0.3, -kr * 0.35), kr * 0.28, Color(1, 1, 1, 0.55))
