extends Control
class_name HudDemonPointer
## فلشِ راهنما به سمتِ شیطان — «برو آن طرف».
##
## مسئله‌ی این حالت این است: هدفِ راند یک نقطه‌ی مشخصِ وسطِ نقشه است، ولی
## دوربین روی خودِ بازیکن قفل است و زمین تاریک. بازیکنی که در گوشه‌ی نقشه
## ظاهر می‌شود هیچ راهی ندارد بفهمد مرکز کدام طرف است — نه شیطان را
## می‌بیند و نه نقشه‌ی کامل را. مینی‌مپ کمک می‌کند ولی گوشه‌ی صفحه است و
## وسطِ درگیری کسی نگاهش نمی‌کند.
##
## پس: یک فلشِ درشت روی لبه‌ی صفحه، دقیقاً در جهتی که باید برود، با فاصله.
## وقتی شیطان واقعاً توی قاب آمد فلش محو می‌شود — کارش تمام است و نباید
## جلوی دید را بگیرد.
##
## چیدمان: داخلِ ناحیه‌ی امن (ناچ/لبه‌ی گرد) و روی بیضی‌ای دورِ مرکزِ صفحه
## می‌نشیند، پس روی ۱۶:۹ تا ۲۱:۹ و ۴:۳ همیشه کاملاً داخلِ کادر است.

const FONT := preload("res://fonts/Lalezar-Regular.ttf")

## همان رنگ‌های نشانِ شیطان روی مینی‌مپ (hud_minimap.gd): یک چیز، یک رنگ —
## و جدا از قرمزِ حریف‌های معمولی  # V1 / V3 similarity
const COL_HOT  := Color(1.0, 0.72, 0.32)
const COL_MAIN := Color(0.86, 0.18, 0.62)
const COL_EDGE := Color(0.20, 0.03, 0.05, 0.92)
const COL_TEXT := Color(0.98, 0.90, 0.72)

## اندازه‌ی فلش (نصفِ طول از نوک تا ته)
const ARROW := 26.0
## فلش روی این کسر از نصف‌عرض/نصف‌ارتفاعِ ناحیه‌ی امن می‌نشیند
const ORBIT := 0.80
## نزدیک‌تر از این، شیطان عملاً جلوی چشم است و فلش کنار می‌رود
const NEAR_FADE := 520.0
## چند ثانیه طول بکشد تا فلش کاملاً بیاید یا برود
const FADE_SPEED := 4.0

## تابعی که جای شیطان را می‌دهد (Vector2) یا null — world.gd ست می‌کند
var demon_source: Callable
## بازیکنِ خودمان، برای حساب کردنِ فاصله
var me: Node2D = null

var _alpha := 0.0
var _phase := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	# مثل نوارِ شیطان: نودِ پنهان هم _process می‌گیرد و در بقیه‌ی حالت‌ها
	# این فلش همیشه پنهان است
	if not visible:
		return
	_phase += delta
	var want := 1.0 if _should_show() else 0.0
	_alpha = move_toward(_alpha, want, delta * FADE_SPEED)
	if _alpha > 0.001 or want > 0.0:
		queue_redraw()


func _should_show() -> bool:
	var target = _demon_pos()
	if target == null or me == null or not is_instance_valid(me):
		return false
	# آن‌قدر نزدیک که خودش در قاب است — فلش دیگر چیزی اضافه نمی‌کند
	return me.global_position.distance_to(target) > NEAR_FADE


func _demon_pos():
	if not demon_source.is_valid():
		return null
	return demon_source.call()


func _draw() -> void:
	if _alpha <= 0.01:
		return
	var target = _demon_pos()
	if target == null or me == null or not is_instance_valid(me):
		return

	var safe := _safe_rect()
	var centre := safe.get_center()
	# جهت در فضای جهانی حساب می‌شود، نه روی صفحه: دوربین نمی‌چرخد، پس
	# همین درست است و ربطی به موقعیتِ دقیقِ دوربین ندارد
	var to: Vector2 = (target as Vector2) - me.global_position
	if to.length() < 1.0:
		return
	var dir := to.normalized()

	# روی بیضیِ ناحیه‌ی امن — نه روی دایره، وگرنه روی صفحه‌ی دراز فلش
	# وسطِ کادر می‌افتد و روی ۴:۳ از لبه بیرون می‌زند
	var at := centre + Vector2(dir.x * safe.size.x * 0.5 * ORBIT,
		dir.y * safe.size.y * 0.5 * ORBIT)

	# نبضِ آرام، تا بینِ شلوغیِ صفحه دیده شود
	var pulse := 1.0 + 0.10 * sin(_phase * 3.4)
	var a := _alpha

	# --- هاله‌ی پشت ---
	draw_circle(at, ARROW * 1.55 * pulse, Color(COL_MAIN.r, COL_MAIN.g, COL_MAIN.b, 0.14 * a))

	# --- خودِ فلش ---
	var side := dir.orthogonal()
	var tip := at + dir * ARROW * pulse
	var tail := at - dir * ARROW * 0.55 * pulse
	var wing := ARROW * 0.72 * pulse
	var body := PackedVector2Array([
		tip,
		at - dir * ARROW * 0.30 * pulse + side * wing,
		tail,
		at - dir * ARROW * 0.30 * pulse - side * wing,
	])
	# خطِ دورِ تیره تا روی هر پس‌زمینه‌ای خوانده شود
	draw_colored_polygon(_grown(body, at, 1.18), Color(COL_EDGE.r, COL_EDGE.g, COL_EDGE.b, a))
	draw_colored_polygon(body, Color(COL_MAIN.r, COL_MAIN.g, COL_MAIN.b, a))
	# مغزِ روشن، هم‌جهت با فلش
	var core := PackedVector2Array([
		at + dir * ARROW * 0.62 * pulse,
		at - dir * ARROW * 0.04 * pulse + side * wing * 0.34,
		at - dir * ARROW * 0.16 * pulse,
		at - dir * ARROW * 0.04 * pulse - side * wing * 0.34,
	])
	draw_colored_polygon(core, Color(COL_HOT.r, COL_HOT.g, COL_HOT.b, a * 0.95))

	# --- فاصله، پشتِ فلش ---
	var metres := int(round(to.length() / 10.0))     # ۱۰ واحدِ جهانی ≈ یک قدم
	var text := "%sم" % _fa(metres)
	var fs := 17
	var tw := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tp := at - dir * (ARROW * 1.5 * pulse) - Vector2(tw * 0.5, -6.0)
	draw_string(FONT, tp + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		Color(0, 0, 0, 0.85 * a))
	draw_string(FONT, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		Color(COL_TEXT.r, COL_TEXT.g, COL_TEXT.b, a))


## چندضلعی را نسبت به مرکزش بزرگ می‌کند (برای خطِ دور)
func _grown(poly: PackedVector2Array, about: Vector2, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(about + (p - about) * k)
	return out


## ناحیه‌ی امنِ صفحه — فلش نباید زیرِ ناچ یا روی لبه‌ی خمیده بیفتد
func _safe_rect() -> Rect2:
	var vp := get_viewport_rect().size
	if not OS.has_feature("mobile"):
		return Rect2(Vector2(24, 24), vp - Vector2(48, 48))
	var safe := DisplayServer.get_display_safe_area()
	var win_pos := DisplayServer.window_get_position()
	var win_size := DisplayServer.window_get_size()
	if safe.size.x <= 0 or win_size.x <= 0:
		return Rect2(Vector2(24, 24), vp - Vector2(48, 48))
	var k := vp / Vector2(win_size)
	var l := maxf(0.0, float(safe.position.x - win_pos.x)) * k.x + 24.0
	var t := maxf(0.0, float(safe.position.y - win_pos.y)) * k.y + 24.0
	var r := maxf(0.0, float(win_pos.x + win_size.x - safe.end.x)) * k.x + 24.0
	var b := maxf(0.0, float(win_pos.y + win_size.y - safe.end.y)) * k.y + 24.0
	return Rect2(Vector2(l, t), vp - Vector2(l + r, t + b))


func _fa(value: int) -> String:
	const DIGITS := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var out := ""
	for ch in str(absi(value)):
		out += DIGITS[int(ch)]
	return out
