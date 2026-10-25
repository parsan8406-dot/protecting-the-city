extends Control
class_name CombatHUD
## کارتِ پروفایلِ بالای صفحه: عکس، سطح، نوارِ جانِ قرمز، نوارِ آبیِ فشنگ‌ها
## و قابِ اسلحه — به سبکِ عکسِ مرجع.
##
## همه‌چیز با _draw کشیده می‌شود، پس نه به صحنه وابسته است و نه با عوض
## شدنِ رزولوشن به‌هم می‌ریزد (GameHUD کلِ لایه را با ارتفاعِ صفحه بزرگ و
## کوچک می‌کند). تم: سیاه، قرمز، طلایی.
##
## نوارِ جان دو لایه دارد: «ردِ ضربه»ی روشن که آرام عقب می‌آید و لایه‌ی اصلی
## که فوری جابه‌جا می‌شود — همان چیزی که ضربه خوردن را حس‌دار می‌کند.
## نوارِ آبی خشاب است (بخشِ آبیِ عکسِ مرجع): تا ۱۲ گلوله تکه‌تکه، بیشتر از
## آن یک نوارِ پیوسته با عدد.

## هر تغییرِ عددِ جان/فشنگ؛ critical یعنی جانِ کم یا خشابِ رو به اتمام.
## GameHUD با این کارت را روشن/کم‌رنگ می‌کند.  # C1
signal readout_changed(critical: bool)

const FONT := preload("res://fonts/Lalezar-Regular.ttf")

# --- تم ---
const COL_PANEL   := Color(0.045, 0.04, 0.05, 0.86)
const COL_EDGE    := Color(0.83, 0.64, 0.24, 0.9)
const COL_TRACK   := Color(0.12, 0.1, 0.12, 1.0)
const COL_HP      := Color(0.9, 0.14, 0.17)
const COL_HP_HI   := Color(1.0, 0.36, 0.34)
const COL_TRAIL   := Color(1.0, 0.86, 0.6, 0.85)
const COL_AMMO    := Color(0.2, 0.62, 1.0)
const COL_AMMO_HI := Color(0.55, 0.85, 1.0)
const COL_AMMO_OFF := Color(0.2, 0.3, 0.42, 0.45)
const COL_TEXT    := Color(0.99, 0.97, 0.92)
const COL_GOLD    := Color(0.96, 0.78, 0.3)
## فشنگِ کم: قرمز + مثلثِ هشدار (رنگ همیشه همراهِ شکل)  # V2
const COL_WARN    := Color(1.0, 0.32, 0.28)

# --- اندازه‌ها (واحدِ طراحی؛ GameHUD بزرگش می‌کند) ---
const PAD := 8.0
const PORTRAIT := 70.0
const BAR_W := 168.0
const HP_H := 20.0
const AMMO_H := 16.0
const WEAPON_W := 76.0
## بیشتر از این تعداد فشنگ دیگر تکه‌تکه کشیده نمی‌شود
const SEGMENT_CAP := 12
## نوشته‌ی چشمک‌زنِ «پر کردن...» بیشتر از این در ثانیه دوباره کشیده نمی‌شود
const RELOAD_REDRAW_HZ := 15.0
## ضخامتِ خطِ دورِ نوشته‌ها (همان سایه‌ی ۱ پیکسلیِ چهارطرفه‌ی قبلی)
const TEXT_OUTLINE := 4
## زیرِ این کسر جان «بحرانی» است — همان آستانه‌ی لبه‌ی قرمزِ world.gd
const LOW_HP := 0.3
## خشاب وقتی این کسر یا کمتر مانده «کم» است (فقط برای خشاب‌های ۴ تایی به بالا)
const LOW_AMMO := 0.25

var _hp := 1.0
var _hp_trail := 1.0
var _hp_text := ""
var _portrait: Texture2D = null
var _weapon: Texture2D = null
var _ammo_cur := 0
var _ammo_max := 0
var _reloading := false
var _level := 1
var _flash := 0.0
var _reload_redraw_t := 0.0
## پالسِ کوتاهِ عدد بعد از هر تغییر (۱ → ۰)  # V10
var _hp_pop := 0.0
var _ammo_pop := 0.0
var _hp_cur := -1
var _hp_maxv := -1

# StyleBoxها یک بار ساخته می‌شوند؛ هر _draw فقط bg_color را عوض می‌کند.
# draw_style_box رأس‌ها را همان لحظه با رنگِ فعلی می‌سازد، پس عوض کردنِ رنگِ
# همان StyleBox برای کشیدنِ بعدی روی کشیده‌های قبلی اثری ندارد.
var _sb_panel: StyleBoxFlat
var _sb_portrait: StyleBoxFlat
var _sb_portrait_rim: StyleBoxFlat
var _sb_level: StyleBoxFlat
var _sb_hp_track: StyleBoxFlat
var _sb_r8: StyleBoxFlat
var _sb_r5: StyleBoxFlat
var _sb_ammo_track: StyleBoxFlat
var _sb_r4: StyleBoxFlat
var _sb_r6: StyleBoxFlat
var _sb_weapon: StyleBoxFlat
var _sb_rim: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(panel_w(), panel_h())
	size = custom_minimum_size
	_level = maxi(int(Global.level), 1)
	_sb_panel = _make_box(COL_PANEL, 12, 2.0, COL_EDGE)
	_sb_portrait = _make_box(Color(0.1, 0.09, 0.11), 10)
	_sb_portrait_rim = _make_box(Color.TRANSPARENT, 10, 2.0, COL_GOLD)
	_sb_level = _make_box(Color(0.08, 0.07, 0.09, 0.95), 6, 1.5, COL_GOLD)
	_sb_hp_track = _make_box(COL_TRACK, 8, 1.0, Color(0, 0, 0, 0.7))
	_sb_r8 = _make_box(COL_HP, 8)
	_sb_r5 = _make_box(COL_HP_HI, 5)
	_sb_ammo_track = _make_box(COL_TRACK, 7, 1.0, Color(0, 0, 0, 0.7))
	_sb_r4 = _make_box(COL_AMMO, 4)
	_sb_r6 = _make_box(COL_AMMO, 6)
	_sb_weapon = _make_box(Color(0.08, 0.07, 0.09, 0.9), 8, 1.5,
		Color(COL_EDGE.r, COL_EDGE.g, COL_EDGE.b, 0.6))
	_sb_rim = _make_box(Color.TRANSPARENT, 10, 2.0, COL_HP_HI)
	_sb_rim.draw_center = false
	set_process(true)


func _process(delta: float) -> void:
	var dirty := false
	if absf(_hp_trail - _hp) > 0.001:
		# رد فقط رو به پایین کند است؛ درمان باید فوری دیده شود
		_hp_trail = _hp if _hp > _hp_trail else move_toward(_hp_trail, _hp, delta * 0.55)
		dirty = true
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 3.0, 0.0)
		dirty = true
	if _hp_pop > 0.0 or _ammo_pop > 0.0:
		_hp_pop = maxf(_hp_pop - delta * 4.0, 0.0)
		_ammo_pop = maxf(_ammo_pop - delta * 4.0, 0.0)
		dirty = true
	elif _reloading or hp_critical() or ammo_low():
		# چشمکِ نوشته / تپشِ هشدار آرام است؛ ۱۵ بار در ثانیه کاملاً نرم دیده می‌شود
		_reload_redraw_t += delta
		if _reload_redraw_t >= 1.0 / RELOAD_REDRAW_HZ:
			_reload_redraw_t = 0.0
			dirty = true
	if dirty:
		queue_redraw()


static func panel_w() -> float:
	return PAD + PORTRAIT + PAD + BAR_W + PAD + WEAPON_W + PAD


static func panel_h() -> float:
	return PAD + PORTRAIT + 14.0 + PAD


## تصویرِ بازیکن (آواتار یا آرتِ کاراکتر) و آیکنِ اسلحه
func set_identity(portrait: Texture2D, weapon: Texture2D = null) -> void:
	_portrait = portrait
	_weapon = weapon
	queue_redraw()


func set_level(level: int) -> void:
	_level = maxi(level, 1)
	queue_redraw()


func set_health(current: int, maximum: int) -> void:
	# world.gd همین عدد را بارها می‌فرستد؛ فقط تغییرِ واقعی پالس و «بیدار» می‌کند
	var changed := current != _hp_cur or maximum != _hp_maxv
	_hp_cur = current
	_hp_maxv = maximum
	var m := maxf(float(maximum), 1.0)
	var new_hp := clampf(float(current) / m, 0.0, 1.0)
	if new_hp < _hp:
		_flash = 1.0
	_hp = new_hp
	_hp_text = "%s/%s" % [MissionArt.fa_number(maxi(current, 0)), MissionArt.fa_number(maximum)]
	if changed:
		_hp_pop = 1.0   # V10 pulse on change
		readout_changed.emit(is_critical())
	queue_redraw()


func set_ammo(current: int, maximum: int, reloading := false) -> void:
	var new_max := maxi(maximum, 0)
	var new_cur := clampi(current, 0, new_max)
	var changed := new_max != _ammo_max or new_cur != _ammo_cur or reloading != _reloading
	var was_low := ammo_low()
	# خشاب پر شد (ریلود تمام شد): عدد یک بار می‌پرد  # V10
	if new_cur > _ammo_cur and not reloading:
		_ammo_pop = 1.0
	_ammo_max = new_max
	_ammo_cur = new_cur
	_reloading = reloading
	if ammo_low() and not was_low:
		_ammo_pop = 1.0
	if changed:
		readout_changed.emit(is_critical())
	queue_redraw()


## جانِ کم (ولی نه مرده)  # V2
func hp_critical() -> bool:
	return _hp > 0.0 and _hp < LOW_HP


## خشاب رو به اتمام یا در حالِ پر شدن
func ammo_low() -> bool:
	if _reloading:
		return true
	return _ammo_max >= 4 and float(_ammo_cur) <= ceilf(float(_ammo_max) * LOW_AMMO)


func is_critical() -> bool:
	return hp_critical() or ammo_low()


## جان و خشاب هر دو پر — چیزی برای دیدن نیست، کارت می‌تواند کم‌رنگ‌تر شود  # C1
func is_calm() -> bool:
	return _hp >= 0.999 and not _reloading and _ammo_cur >= _ammo_max


func _make_box(fill: Color, radius: int, border := 0.0, border_col := Color.TRANSPARENT) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	if border > 0.0:
		sb.set_border_width_all(int(border))
		sb.border_color = border_col
	return sb


## یک StyleBoxِ از قبل ساخته‌شده با رنگِ تازه
func _fill(sb: StyleBoxFlat, fill: Color) -> StyleBoxFlat:
	sb.bg_color = fill
	return sb


func _text(pos: Vector2, txt: String, fs: int, col: Color, width := -1.0) -> void:
	var tw := FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := pos
	if width > 0.0:
		p.x += (width - tw) * 0.5
	# یک خطِ دور به‌جای چهار بار کشیدنِ سایه
	draw_string_outline(FONT, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TEXT_OUTLINE, Color(0, 0, 0, 0.8))
	draw_string(FONT, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw() -> void:
	if _sb_panel == null:
		return
	var w := panel_w()
	var h := panel_h()

	# --- بدنه ---
	draw_style_box(_sb_panel, Rect2(0, 0, w, h))

	# --- عکس ---
	var pr := Rect2(PAD, PAD, PORTRAIT, PORTRAIT)
	draw_style_box(_sb_portrait, pr)
	if _portrait != null:
		# آرتِ کاراکتر تمام‌قد است؛ مربعی از بالایش (سر و شانه) بریده می‌شود.
		# آواتار خودش مربع است و همین برش کلِ آن را نشان می‌دهد.
		var ts := _portrait.get_size()
		var side := minf(ts.x, ts.y)
		var top := 0.0 if absf(ts.x - ts.y) < 2.0 else ts.y * 0.04
		draw_texture_rect_region(_portrait, pr.grow(-3.0),
			Rect2((ts.x - side) * 0.5, top, side, side))
	draw_style_box(_sb_portrait_rim, pr)

	# نوارِ سطح زیرِ عکس: «Lv. ۵»
	var lv := Rect2(PAD + 6.0, PAD + PORTRAIT - 6.0, PORTRAIT - 12.0, 18.0)
	draw_style_box(_sb_level, lv)
	_text(Vector2(lv.position.x, lv.position.y + 15.0), "Lv. %s" % MissionArt.fa_number(_level),
		14, COL_GOLD, lv.size.x)

	# --- نوارِ جان ---
	var bx := PAD * 2.0 + PORTRAIT
	var hy := PAD + 8.0
	var track := Rect2(bx, hy, BAR_W, HP_H)
	draw_style_box(_sb_hp_track, track)
	if _hp_trail > _hp:
		draw_style_box(_fill(_sb_r8, COL_TRAIL), Rect2(bx, hy, BAR_W * _hp_trail, HP_H))
	if _hp > 0.0:
		var c := COL_HP.lerp(Color.WHITE, _flash * 0.55)
		draw_style_box(_fill(_sb_r8, c), Rect2(bx, hy, maxf(BAR_W * _hp, 8.0), HP_H))
		draw_style_box(_fill(_sb_r5, Color(COL_HP_HI.r, COL_HP_HI.g, COL_HP_HI.b, 0.45)),
			Rect2(bx + 3, hy + 3, maxf(BAR_W * _hp - 6.0, 0.0), HP_H * 0.3))
	var low_hp := hp_critical()
	var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.009)
	if low_hp:
		# جانِ بحرانی: قابِ قرمزِ تپنده دورِ نوار + مثلثِ هشدار  # V2 color + shape
		_sb_rim.border_color = Color(COL_HP_HI.r, COL_HP_HI.g, COL_HP_HI.b, 0.45 + 0.55 * beat)
		draw_style_box(_sb_rim, track.grow(2.0))
		_warn_icon(Vector2(bx + 11.0, hy + HP_H * 0.5), 15.0, Color.WHITE)
	_text(Vector2(bx, hy + HP_H - 4.0), _hp_text, int(16.0 * (1.0 + 0.3 * _hp_pop)), COL_TEXT, BAR_W)

	# --- نوارِ آبیِ فشنگ ---
	var ay := hy + HP_H + 10.0
	var at := Rect2(bx, ay, BAR_W, AMMO_H)
	draw_style_box(_sb_ammo_track, at)
	if _ammo_max > 0 and _ammo_max <= SEGMENT_CAP:
		var gap := 3.0
		var seg := (BAR_W - 4.0 - gap * float(_ammo_max - 1)) / float(_ammo_max)
		for i in _ammo_max:
			var r := Rect2(bx + 2.0 + float(i) * (seg + gap), ay + 2.0, seg, AMMO_H - 4.0)
			draw_style_box(_fill(_sb_r4, COL_AMMO if i < _ammo_cur else COL_AMMO_OFF), r)
	elif _ammo_max > 0:
		var ratio := float(_ammo_cur) / float(_ammo_max)
		if ratio > 0.0:
			draw_style_box(_fill(_sb_r6, COL_AMMO), Rect2(bx + 2.0, ay + 2.0, maxf((BAR_W - 4.0) * ratio, 6.0), AMMO_H - 4.0))
	# برقِ بالای نوارِ آبی
	draw_style_box(_fill(_sb_r4, Color(COL_AMMO_HI.r, COL_AMMO_HI.g, COL_AMMO_HI.b, 0.18)),
		Rect2(bx + 3.0, ay + 2.0, BAR_W - 6.0, AMMO_H * 0.28))
	var ammo_txt := "%s/%s" % [MissionArt.fa_number(_ammo_cur), MissionArt.fa_number(_ammo_max)]
	var ammo_col := COL_TEXT
	var ammo_fs := int(14.0 * (1.0 + 0.3 * _ammo_pop))
	if ammo_low() and not _reloading:
		ammo_col = COL_WARN
		_warn_icon(Vector2(bx + 10.0, ay + AMMO_H * 0.5), 12.0, COL_WARN)
	if _reloading:
		ammo_txt = "پر کردن..."
		ammo_col = Color(COL_AMMO_HI.r, COL_AMMO_HI.g, COL_AMMO_HI.b,
			0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.012))
	_text(Vector2(bx, ay + AMMO_H - 2.0), ammo_txt, ammo_fs, ammo_col, BAR_W)

	# --- قابِ اسلحه ---
	var wx := bx + BAR_W + PAD
	var wr := Rect2(wx, PAD, WEAPON_W, PORTRAIT)
	draw_style_box(_sb_weapon, wr)
	if _weapon != null:
		var ws := _weapon.get_size()
		var sc := minf((WEAPON_W - 10.0) / maxf(ws.x, 1.0), 34.0 / maxf(ws.y, 1.0))
		var d := ws * sc
		draw_texture_rect(_weapon, Rect2(wx + (WEAPON_W - d.x) * 0.5, PAD + 6.0 + (34.0 - d.y) * 0.5, d.x, d.y), false)
	# ذخیره‌ی بی‌پایان: خشاب خودش پر می‌شود
	HudIcons.draw(self, "bullet", Rect2(wx + 14.0, PAD + PORTRAIT - 24.0, 10.0, 18.0), COL_GOLD)
	# «∞» دستی کشیده می‌شود؛ فونتِ Lalezar این نویسه را ندارد
	var inf_c := Vector2(wx + 46.0, PAD + PORTRAIT - 15.0)
	for side in [-1.0, 1.0]:
		draw_arc(inf_c + Vector2(6.0 * side, 0), 6.0, 0, TAU, 20, COL_TEXT, 2.5, true)


## مثلثِ «!» — نشانه‌ی شکلیِ هشدار کنارِ رنگ، برای کوررنگ‌ها  # V2
func _warn_icon(centre: Vector2, side: float, col: Color) -> void:
	var h := side * 0.9
	var pts := PackedVector2Array([
		centre + Vector2(0, -h * 0.55), centre + Vector2(side * 0.55, h * 0.45),
		centre + Vector2(-side * 0.55, h * 0.45)])
	draw_colored_polygon(pts, Color(0, 0, 0, 0.85))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(centre + (p - centre) * 0.72)
	draw_colored_polygon(inner, col)
	var ex := Color(0.35, 0.02, 0.04)
	draw_line(centre + Vector2(0, -h * 0.2), centre + Vector2(0, h * 0.08), ex, maxf(side * 0.14, 1.5))
	draw_circle(centre + Vector2(0, h * 0.24), maxf(side * 0.07, 1.0), ex)
