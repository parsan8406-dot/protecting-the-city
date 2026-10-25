extends Control
class_name HudAbilityButton
## دکمه‌ی گردِ توانایی (لیزر، بمب، دویدن، سپر، درمان‌ها).
##
## سه حالت دارد و همه با _draw کشیده می‌شوند:
##   آماده   قابِ طلایی و آیکن روشن
##   فعال    حلقه‌ی درخشانی که با گذشتِ زمانِ فعال خالی می‌شود (مثلاً ۴ ثانیه سپر)
##   قفل     پرده‌ی تیره‌ی عقربه‌ای + عددِ شمارش‌معکوس وسطِ دکمه
##
## ورودی فقط لمس است: InputEventScreenTouch با اندیسِ انگشتِ خودش، پس با
## انگشتِ جوی‌استیک قاطی نمی‌شود. hover طراحی نشده؛ به‌جایش لمس یک «فشردن»
## کوتاه و برق می‌دهد تا کاربر بفهمد ثبت شد.

signal activated

const FONT := preload("res://fonts/Lalezar-Regular.ttf")

const COL_DISC   := Color(0.07, 0.06, 0.08, 0.86)
const COL_GOLD   := Color(0.96, 0.78, 0.3)
const COL_EDGE   := Color(0.83, 0.62, 0.22, 0.95)
const COL_LOCK   := Color(0.0, 0.0, 0.0, 0.62)
const COL_TEXT   := Color(1.0, 0.97, 0.88)
const COL_BADGE  := Color(0.72, 0.1, 0.12)

## شناسه‌ی آیکن (HudIcons)
var icon_name := ""
## رنگِ درخششِ حالتِ فعال و قابِ دکمه
var accent := COL_GOLD
## دکمه‌ی بزرگِ اصلی (لیزر) قابِ دوگانه و هاله دارد
var hero := false
## عددِ گوشه (مثلاً بمب‌های مانده). منفی یعنی بدونِ نشان.
var badge := -1
## ناحیه‌ی لمس این‌قدر (واحدِ طراحی) از لبه‌ی دایره بزرگ‌تر است. GameHUD
## برای هر دکمه کمتر از نصفِ فاصله تا همسایه می‌دهد تا هم‌پوشانی نشود.  # C3 Fitts
var touch_pad := 8.0

var _active_left := 0.0
var _active_total := 0.0
var _lock_left := 0.0
var _lock_total := 0.0
var _press := 0.0          # ۱ → ۰ بعد از هر لمس (کوچک شدن و برق)
var _deny := 0.0           # لرزشِ «هنوز آماده نیست»
var _ready_glow := 0.0     # ۱ → ۰ وقتی قفل تمام شد (حلقه‌ی طلاییِ «آماده»)
var _last_fire := 0

## لرزشِ کوتاهِ «دوباره آماده شد» (میلی‌ثانیه)؛ از تنظیماتِ لرزش پیروی می‌کند
const READY_VIBRATE_MS := 10


func setup(p_icon: String, diameter: float, p_accent: Color = COL_GOLD, p_hero := false) -> HudAbilityButton:
	icon_name = p_icon
	accent = p_accent
	hero = p_hero
	custom_minimum_size = Vector2(diameter, diameter)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	return self


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# جوی‌استیک لمسی را که روی این دکمه افتاده برنمی‌دارد
	add_to_group("touch_exclude")
	set_process(false)


## لمس دایره‌ای است (نه مستطیلِ دورِ دکمه) و کمی بزرگ‌تر از ظاهر؛ گوشه‌های
## مستطیل دیگر لمسِ دکمه‌ی کناری را نمی‌قاپند.  # C3 Fitts
func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= minf(size.x, size.y) * 0.5 + touch_pad


## آیا الان می‌شود زدش؟ (نه فعال، نه قفل)
func is_ready() -> bool:
	return _active_left <= 0.0 and _lock_left <= 0.0


## active ثانیه حالتِ فعال، بعد cooldown ثانیه قفل — همان عددهای سرور
func run(active: float, cooldown: float) -> void:
	_active_left = maxf(active, 0.0)
	_active_total = maxf(_active_left, 0.001)
	_lock_left = maxf(cooldown, 0.0)
	_lock_total = maxf(_lock_left, 0.001)
	set_process(true)
	queue_redraw()


## قفلِ فعلی را همین حالا برمی‌دارد (مثلاً بعد از ریسپاون)
func reset() -> void:
	_active_left = 0.0
	_lock_left = 0.0
	queue_redraw()


func set_badge(n: int) -> void:
	badge = n
	queue_redraw()


## لرزشِ کوتاه وقتی دکمه هنوز آماده نیست یا کاری نمی‌کند
func deny() -> void:
	_deny = 1.0
	set_process(true)


func _gui_input(event: InputEvent) -> void:
	var down := false
	if event is InputEventScreenTouch and event.pressed:
		down = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		down = true
	if not down:
		return
	accept_event()
	# emulate_touch_from_mouse روی PC هم لمس می‌سازد هم کلیک؛ یک بار کافی است
	var now := Time.get_ticks_msec()
	if now - _last_fire < 150:
		return
	_last_fire = now
	_press = 1.0
	set_process(true)
	if not is_ready():
		deny()
		return
	activated.emit()


func _process(delta: float) -> void:
	if _active_left > 0.0:
		_active_left = maxf(_active_left - delta, 0.0)
	elif _lock_left > 0.0:
		_lock_left = maxf(_lock_left - delta, 0.0)
		if _lock_left <= 0.0:
			_on_ready_again()
	_press = maxf(_press - delta * 5.0, 0.0)
	_deny = maxf(_deny - delta * 3.0, 0.0)
	_ready_glow = maxf(_ready_glow - delta * 2.5, 0.0)
	var s := 1.0 - 0.1 * _press
	scale = Vector2(s, s)
	queue_redraw()
	if _active_left <= 0.0 and _lock_left <= 0.0 and _press <= 0.0 and _deny <= 0.0 \
			and _ready_glow <= 0.0:
		scale = Vector2.ONE
		set_process(false)


## قفل همین الان تمام شد: همان «فشردن» کوتاه + حلقه‌ی طلایی و یک لرزشِ ریز،
## تا بازیکن بدونِ نگاه کردن به عدد بفهمد دکمه دوباره آماده است.
func _on_ready_again() -> void:
	_press = 1.0
	_ready_glow = 1.0
	# موقعِ تماشا بعد از مرگ دکمه‌ها پنهان‌اند — آن‌جا لرزش بی‌معنی است
	if is_visible_in_tree():
		LocalSettings.vibrate(READY_VIBRATE_MS)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var shake := sin(_deny * 40.0) * 4.0 * _deny
	c.x += shake

	# هاله‌ی دکمه‌ی اصلی
	if hero:
		for i in 3:
			draw_circle(c, r + 4.0 + float(i) * 3.0, Color(accent.r, accent.g, accent.b, 0.10 - 0.03 * float(i)))

	draw_circle(c, r - 1.0, COL_DISC)
	# برقِ بالایی برای حجم
	draw_circle(c + Vector2(0, -r * 0.35), r * 0.55, Color(1, 1, 1, 0.04))

	var locked := _lock_left > 0.0 and _active_left <= 0.0
	var icon_col := Color(1, 1, 1, 0.42) if locked else Color.WHITE
	var ir := r * (0.62 if hero else 0.58)
	var tint := Color(accent.r, accent.g, accent.b, icon_col.a).lerp(Color(1, 1, 1, icon_col.a), 0.35)
	if HudIcons.is_full_color_art(icon_name):
		tint = Color(1, 1, 1, icon_col.a) if not locked else Color(0.55, 0.55, 0.55, 1.0)
	HudIcons.draw(self, icon_name, Rect2(c - Vector2(ir, ir), Vector2(ir, ir) * 2.0), tint)

	# قاب
	var edge := accent if not locked else Color(0.45, 0.42, 0.4, 0.9)
	draw_arc(c, r - 2.0, 0, TAU, 48, edge, 3.0 if not hero else 4.0, true)
	if hero:
		draw_arc(c, r - 9.0, 0, TAU, 48, Color(edge.r, edge.g, edge.b, 0.45), 2.0, true)

	# فعال: حلقه‌ای که خالی می‌شود
	if _active_left > 0.0:
		var f := _active_left / _active_total
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.012)
		draw_arc(c, r - 2.0, -PI * 0.5, -PI * 0.5 + TAU * f, 48,
			Color(accent.r, accent.g, accent.b, pulse), 6.0, true)
		_draw_number(c, ceili(_active_left), r * 0.42, accent)

	# قفل: پرده‌ی عقربه‌ای + عدد
	elif locked:
		var f2 := _lock_left / _lock_total
		var pts := PackedVector2Array([c])
		var steps := 40
		for i in steps + 1:
			var a := -PI * 0.5 + TAU * f2 * float(i) / float(steps)
			pts.append(c + Vector2.from_angle(a) * (r - 3.0))
		if pts.size() >= 3:
			draw_colored_polygon(pts, COL_LOCK)
		_draw_number(c, ceili(_lock_left), r * 0.5, COL_TEXT)

	# برقِ لمس
	if _press > 0.0:
		draw_circle(c, r - 2.0, Color(1, 1, 1, 0.22 * _press))

	# «آماده شد»: حلقه‌ی طلایی که کمی بیرون می‌زند و محو می‌شود
	if _ready_glow > 0.0:
		var spread := (1.0 - _ready_glow) * 10.0
		draw_arc(c, r + spread, 0, TAU, 48,
			Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.9 * _ready_glow), 4.0, true)

	# نشانِ عدد (بمب‌های مانده)
	if badge >= 0:
		var bp := c + Vector2(r * 0.68, r * 0.68)
		var br := maxf(r * 0.3, 12.0)
		draw_circle(bp, br, COL_BADGE if badge > 0 else Color(0.25, 0.24, 0.26))
		draw_arc(bp, br, 0, TAU, 20, COL_GOLD, 2.0, true)
		_draw_number(bp, badge, br * 1.3, COL_TEXT)


func _draw_number(centre: Vector2, n: int, size_px: float, col: Color) -> void:
	var txt := MissionArt.fa_number(n)
	var fs := int(size_px)
	var tw := FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var p := centre + Vector2(-tw.x * 0.5, fs * 0.36)
	for off in [Vector2(1.5, 1.5), Vector2(-1.5, 1.5), Vector2(1.5, -1.5), Vector2(-1.5, -1.5)]:
		draw_string(FONT, p + off, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.85))
	draw_string(FONT, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
