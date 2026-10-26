extends Control
class_name HudSquadHealth
## جانِ تک‌تکِ بازیکن‌های مسابقه — بالای نوارِ جانِ شیطان.
##
## چرا در «عملیات حذف شیطان» لازم است: در بقیه‌ی حالت‌ها عددِ «زنده» بالای
## صفحه کافی است، چون مرگ حذفِ دائمی است و همان عدد همه‌چیز را می‌گوید. این‌جا
## مرگ موقتی است و هدف یک کیسه‌ی جانِ بزرگ وسطِ نقشه — یعنی سؤالِ واقعی
## «چند نفر زنده‌اند» نیست، «چه کسی الان می‌تواند شلیک کند و چه کسی دارد
## می‌افتد» است. عددِ زنده این را جواب نمی‌دهد، این نوارها می‌دهند.
##
## دو ستون: تیمِ خودمان چپ (آبی)، حریف راست (قرمز). خودمان همیشه ردیفِ اولِ
## ستونِ چپ‌ایم تا چشم دنبالش نگردد.
##
## همه‌ی داده از Network.current_players می‌آید — همان لیستی که سرور هر بار
## با update_players می‌فرستد. هیچ عددی این‌جا حساب نمی‌شود.

## ارتفاعِ پنل با تعدادِ بازیکن‌ها عوض می‌شود (بک‌فیل، قطعِ اتصال)، و نوارِ
## شیطان دقیقاً زیرِ آن می‌نشیند — پس GameHUD باید همان لحظه دوباره بچیند،
## وگرنه دو پنل روی هم می‌افتند یا یک شکافِ خالی بینشان می‌ماند.
signal height_changed
## کسی تیر خورد، افتاد یا برگشت. critical یعنی یک هم‌تیمی (یا خودم) جانش کم
## است. GameHUD با این پنل را روشن/کم‌رنگ می‌کند.  # C1
signal activity(critical: bool)

const FONT := preload("res://fonts/Lalezar-Regular.ttf")

const COL_ALLY  := Color(0.33, 0.74, 1.00)
const COL_FOE   := Color(0.93, 0.27, 0.32)
const COL_TEXT  := Color(0.93, 0.91, 0.88)
const COL_DIM   := Color(0.50, 0.47, 0.50)
const COL_GOLD  := Color(0.96, 0.78, 0.28)
const COL_PANEL := Color(0.07, 0.05, 0.07, 0.86)
const COL_TRACK := Color(0.16, 0.13, 0.15, 0.95)
## جانِ کم — نوار به این رنگ می‌رسد تا «دارد می‌افتد» از دور دیده شود
const COL_LOW   := Color(1.0, 0.62, 0.20)
## زیرِ این کسر، تهِ نوارِ هم‌تیمی مثلثِ «!» می‌آید — همان آستانه‌ی کارتِ
## پروفایل؛ یعنی «درمانِ تیمی لازم است»  # V2 color + shape
const LOW_FRAC := 0.3

## نام‌ها با فونتِ ۱۶ (روی گوشی ۱۳ ریز بود)، پس پنل و ردیف‌ها هم بزرگ‌ترند
const PANEL_W := 420.0
const ROW_H := 23.0
const NAME_FS := 16
const PAD := 8.0
## بیشتر از این ردیف در هر ستون جا نمی‌شود (۴ در ۴ بزرگ‌ترین حالتِ بازی است)
const MAX_ROWS := 4

## نمایشِ جانِ حریف‌ها.
##
## ⚠️ این یک تصمیمِ گیم‌پلی است و نه فقط ظاهری: بقیه‌ی بازی عمداً اطلاعاتِ
## حریف را محدود می‌کند (مینی‌مپ حریفِ بیرونِ بردِ رادار را نشان نمی‌دهد).
## با روشن بودنِ این، جانِ هر حریف همیشه معلوم است — حتی حریفی که اصلاً
## ندیده‌ای. خواسته‌ی صریح همین بود، ولی خاموش کردنش یک خط است.
@export var show_enemies := true

const REFRESH := 0.12
var _t := 0.0
## جانِ نمایشی برای هر بازیکن، تا نوار با هر تیر نپرد: نام -> کسر
var _shown: Dictionary = {}
## آخرین جانِ واقعیِ هر بازیکن (نام -> کسر) برای فهمیدنِ «چیزی عوض شد»
var _last: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(PANEL_W, panel_h())
	size = Vector2(PANEL_W, panel_h())


## ارتفاعِ لازم برای تعدادِ بازیکن‌های همین مسابقه. GameHUD برای چیدنِ
## نوارِ شیطان زیرِ این، همین را می‌پرسد.
func panel_h() -> float:
	return PAD * 2.0 + ROW_H * float(maxi(_rows_needed(), 1))


func _rows_needed() -> int:
	var ally := 0
	var foe := 0
	for name in Network.current_players:
		if _is_ally(Network.current_players[name]):
			ally += 1
		elif show_enemies:
			foe += 1
	return mini(maxi(ally, foe), MAX_ROWS)


func _process(delta: float) -> void:
	if not visible:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = REFRESH

	# جانِ نمایشی نرم به مقدارِ واقعی می‌رسد
	var changed := false
	var critical := false
	for name in Network.current_players:
		var pd = Network.current_players[name]
		if typeof(pd) != TYPE_DICTIONARY:
			continue
		var target := _health_fraction(pd)
		if absf(float(_last.get(name, target)) - target) > 0.01:
			changed = true
		_last[name] = target
		if _is_ally(pd) and target > 0.0 and target < LOW_FRAC:
			critical = true
		var cur: float = _shown.get(name, target)
		_shown[name] = lerpf(cur, target, clampf(REFRESH * 9.0, 0.0, 1.0))
	# بازیکن‌هایی که رفته‌اند نباید در حافظه بمانند
	for name in _shown.keys():
		if not Network.current_players.has(name):
			_shown.erase(name)
			_last.erase(name)
	if changed or critical:
		activity.emit(critical)

	var want := panel_h()
	if not is_equal_approx(want, size.y):
		size.y = want
		custom_minimum_size.y = want
		height_changed.emit()
	queue_redraw()


func _is_ally(pd) -> bool:
	if typeof(pd) != TYPE_DICTIONARY:
		return false
	# تیمِ خالی (تمرینِ بی‌تیم) یعنی هم‌تیمی‌ای در کار نیست
	return Global.my_team != "" and str(pd.get("team", "")) == Global.my_team


func _health_fraction(pd: Dictionary) -> float:
	var hp := float(pd.get("health", 0))
	var stats = pd.get("stats", {})
	var max_hp := 100.0
	if typeof(stats) == TYPE_DICTIONARY:
		max_hp = maxf(float(stats.get("health", 100)), 1.0)
	return clampf(hp / max_hp, 0.0, 1.0)


func _draw() -> void:
	var players: Dictionary = Network.current_players
	if players.is_empty():
		return

	# --- دسته‌بندی ---
	var allies: Array = []
	var foes: Array = []
	for name in players:
		var pd = players[name]
		if typeof(pd) != TYPE_DICTIONARY:
			continue
		if _is_ally(pd):
			allies.append(name)
		elif show_enemies:
			foes.append(name)
	allies.sort()
	foes.sort()
	# خودمان همیشه ردیفِ اول — وسطِ درگیری نباید دنبالِ اسمِ خودت بگردی
	var me: String = str(Global.my_username)
	if allies.has(me):
		allies.erase(me)
		allies.push_front(me)

	# --- قاب ---
	var box := StyleBoxFlat.new()
	box.bg_color = COL_PANEL
	box.set_corner_radius_all(9)
	box.set_border_width_all(2)
	box.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.45)
	draw_style_box(box, Rect2(Vector2.ZERO, size))

	var col_w := (size.x - PAD * 3.0) * 0.5
	_draw_column(allies, Vector2(PAD, PAD), col_w, COL_ALLY)
	if show_enemies:
		_draw_column(foes, Vector2(PAD * 2.0 + col_w, PAD), col_w, COL_FOE)
		# خطِ جداکننده‌ی دو تیم
		var x := PAD * 1.5 + col_w
		draw_line(Vector2(x, PAD * 0.6), Vector2(x, size.y - PAD * 0.6),
			Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.22), 1.5)


func _draw_column(names: Array, at: Vector2, col_w: float, accent: Color) -> void:
	var rows := mini(names.size(), MAX_ROWS)
	for i in rows:
		var name: String = str(names[i])
		var pd = Network.current_players.get(name, {})
		var frac: float = _shown.get(name, _health_fraction(pd) if typeof(pd) == TYPE_DICTIONARY else 0.0)
		var dead := frac <= 0.001
		var y := at.y + float(i) * ROW_H

		# --- نام ---
		var label := "شما" if name == Global.my_username else name
		var name_w := col_w * 0.42
		var fs := NAME_FS
		# اسمِ بلند بریده می‌شود تا نوار را عقب نراند
		while label.length() > 3 and FONT.get_string_size(
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > name_w:
			label = label.substr(0, label.length() - 1)
		var name_col := COL_DIM if dead else COL_TEXT
		draw_string(FONT, Vector2(at.x + 1.0, y + 18.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
		draw_string(FONT, Vector2(at.x, y + 17.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, name_col)

		# --- نوار ---
		var bx := at.x + name_w + 6.0
		var bw := col_w - name_w - 6.0
		var track := Rect2(bx, y + 5.0, bw, ROW_H - 11.0)
		draw_rect(track, COL_TRACK, true)
		if not dead:
			var col := accent.lerp(COL_LOW, clampf(1.0 - frac, 0.0, 1.0) * 0.8)
			draw_rect(Rect2(track.position, Vector2(track.size.x * frac, track.size.y)),
				col, true)
			# برقِ بالای نوار
			draw_rect(Rect2(track.position,
				Vector2(track.size.x * frac, track.size.y * 0.4)),
				Color(1, 1, 1, 0.15), true)
			if accent == COL_ALLY and frac < LOW_FRAC:
				_warn(Vector2(track.end.x - 8.0, track.get_center().y), 13.0)
		else:
			# مرده: ضربدرِ کوچک به‌جای نوار — در حالتی با ریسپاون یعنی
			# «چند ثانیه‌ی دیگر برمی‌گردد»، نه «برای همیشه رفت»
			var c := track.get_center()
			var r := track.size.y * 0.42
			var dim := Color(COL_DIM.r, COL_DIM.g, COL_DIM.b, 0.9)
			draw_line(c + Vector2(-r, -r), c + Vector2(r, r), dim, 2.0)
			draw_line(c + Vector2(-r, r), c + Vector2(r, -r), dim, 2.0)
		draw_rect(track, Color(0, 0, 0, 0.45), false, 1.0)


## مثلثِ «!» روی تهِ نوار — همان شکلِ هشدارِ کارتِ پروفایل  # V2
func _warn(c: Vector2, side: float) -> void:
	var h := side * 0.9
	var tri := PackedVector2Array([c + Vector2(0, -h * 0.55),
		c + Vector2(side * 0.55, h * 0.45), c + Vector2(-side * 0.55, h * 0.45)])
	draw_colored_polygon(tri, Color(0, 0, 0, 0.85))
	var inner := PackedVector2Array()
	for p in tri:
		inner.append(c + (p - c) * 0.72)
	draw_colored_polygon(inner, COL_LOW)
	draw_line(c + Vector2(0, -h * 0.2), c + Vector2(0, h * 0.08), Color(0.3, 0.05, 0.02), 1.6)
	draw_circle(c + Vector2(0, h * 0.24), 1.0, Color(0.3, 0.05, 0.02))
