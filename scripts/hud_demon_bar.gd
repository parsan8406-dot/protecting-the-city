extends Control
class_name HudDemonBar
## نوارِ جانِ شیطان و کارنامه‌ی آسیبِ دو تیم — بالای صفحه، زیرِ تایمر.
##
## فقط در «عملیات حذف شیطان» دیده می‌شود (GameHUD روشن/خاموشش می‌کند).
##
## چرا هر دو عدد کنارِ هم: جانِ شیطان فقط می‌گوید راند کِی تمام می‌شود؛
## برنده را آسیبِ کلِ هر تیم تعیین می‌کند، نه ضربه‌ی آخر. پس نوارِ پایین
## همان مسابقه‌ی واقعی است.
##
## همه‌ی اعداد از Network.demon_info می‌آیند که مستقیماً پیامِ سرور است؛
## این‌جا هیچ‌چیز حساب نمی‌شود.

const FONT := preload("res://fonts/Lalezar-Regular.ttf")

const COL_GOLD  := Color(0.96, 0.78, 0.28)
const COL_TEXT  := Color(0.97, 0.95, 0.90)
const COL_DIM   := Color(0.66, 0.62, 0.62)
const COL_ALLY  := Color(0.33, 0.74, 1.00)
const COL_FOE   := Color(0.93, 0.27, 0.32)
const COL_PANEL := Color(0.07, 0.05, 0.07, 0.88)
const COL_HP    := Color(0.90, 0.14, 0.18)
const COL_HP_LOW := Color(1.0, 0.62, 0.20)
const COL_TRACK := Color(0.17, 0.10, 0.12, 0.95)

## متن‌های زیرِ نوار روی گوشی ۱۳-۱۵ ریز بودند؛ حالا ۱۶-۱۷ و قاب کمی پهن‌تر
const BAR_W := 420.0
const BAR_H := 86.0
const LABEL_FS := 16
const NUMBER_FS := 17
## ارتفاعِ نوارِ جان و نوارِ سهمِ آسیب
const HP_H := 18.0
const SPLIT_H := 9.0

## ده بار در ثانیه بس است — هر فریم کشیدن روی گوشیِ ارزان بی‌خود است
const REFRESH := 0.1
## زیرِ این کسر شیطان «نزدیکِ افتادن» است: قاب می‌تپد و کنارِ نامش نوشته
## می‌شود — آخرِ کار باید از همه جا برجسته‌تر باشد  # C9 goal-gradient
const NEAR_FRAC := 0.25

var _t := 0.0
## جانِ نمایشی، که نرم به مقدارِ واقعی می‌رسد. بدونِ آن نوار با هر تیر
## می‌پرد و عملاً خوانده نمی‌شود.
var _shown := -1.0
## تپشِ سفید بعد از هر ضربه
var _flash := 0.0
var _last_hp := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(BAR_W, BAR_H)
	size = Vector2(BAR_W, BAR_H)


func _process(delta: float) -> void:
	# نودِ پنهان هم _process می‌گیرد؛ در بقیه‌ی حالت‌ها این نوار همیشه
	# پنهان است و نباید هر فریم باتری بسوزاند
	if not visible:
		return
	var info := Network.demon_info
	if info.is_empty():
		return
	var hp := int(info.get("health", 0))
	if _last_hp >= 0 and hp < _last_hp:
		_flash = 1.0
	_last_hp = hp

	if _shown < 0.0:
		_shown = float(hp)
	else:
		# نرم ولی نه کند: عقب ماندنِ نوار از واقعیت خودش گمراه‌کننده است
		_shown = lerpf(_shown, float(hp), clampf(delta * 9.0, 0.0, 1.0))
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 3.2, 0.0)

	_t -= delta
	if _t <= 0.0:
		# تپشِ «نزدیکه» با ده فریم در ثانیه پله‌پله دیده می‌شد
		_t = REFRESH * (0.5 if _near(info) else 1.0)
		queue_redraw()


func _near(info: Dictionary) -> bool:
	var max_hp: float = maxf(float(info.get("max_health", 1)), 1.0)
	var hp := float(info.get("health", 0))
	return hp > 0.0 and hp / max_hp <= NEAR_FRAC


func _draw() -> void:
	var info := Network.demon_info
	if info.is_empty():
		return

	var w := size.x
	var max_hp: float = maxf(float(info.get("max_health", 1)), 1.0)
	var hp: float = clampf(_shown, 0.0, max_hp)
	var frac: float = hp / max_hp

	# --- قاب ---
	var box := StyleBoxFlat.new()
	box.bg_color = COL_PANEL
	box.set_corner_radius_all(10)
	box.set_border_width_all(2)
	box.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.75)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var near := _near(info)
	if near:
		var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.009)
		var glow := StyleBoxFlat.new()
		glow.draw_center = false
		glow.set_corner_radius_all(12)
		glow.set_border_width_all(3)
		glow.border_color = Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.35 + 0.6 * beat)
		draw_style_box(glow, Rect2(Vector2.ZERO, size).grow(1.0 + 2.0 * beat))

	# --- سطرِ بالا: نام و عدد ---
	var pad := 12.0
	_text("شیطان", Vector2(pad, 21.0), 19, COL_GOLD)
	if near:
		# وسطِ سطر، بینِ نام و عدد — همان‌جا که چشم از نام به عدد می‌رود
		var near_txt := "تقریباً تمومه!"
		var nw := FONT.get_string_size(near_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		_text(near_txt, Vector2((w - nw) * 0.5, 21.0), 17, COL_HP_LOW)
	var hp_text := "%s / %s" % [_fa(int(round(hp))), _fa(int(max_hp))]
	var tw := FONT.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	_text(hp_text, Vector2(w - pad - tw, 21.0), 17, COL_TEXT)

	# --- نوارِ جان ---
	var track := Rect2(pad, 27.0, w - pad * 2.0, HP_H)
	draw_rect(track, COL_TRACK, true)
	if frac > 0.0:
		var fill := Rect2(track.position, Vector2(track.size.x * frac, track.size.y))
		# هرچه جانش کمتر، رنگ گرم‌تر — «نزدیک است» باید در یک نگاه معلوم باشد
		var col := COL_HP.lerp(COL_HP_LOW, 1.0 - frac)
		if _flash > 0.0:
			col = col.lerp(Color(1, 1, 1), _flash * 0.55)
		draw_rect(fill, col, true)
		# برقِ بالای نوار، تا تخت نباشد
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, fill.size.y * 0.38)),
			Color(1, 1, 1, 0.16), true)
	# خط‌های ربع، تا اندازه‌ی «چقدر مانده» قابلِ تخمین باشد
	for i in range(1, 4):
		var x := track.position.x + track.size.x * float(i) * 0.25
		draw_line(Vector2(x, track.position.y), Vector2(x, track.end.y),
			Color(0, 0, 0, 0.35), 1.5)
	draw_rect(track, Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.5), false, 1.5)

	# --- سهمِ آسیبِ دو تیم ---
	_draw_damage(info, w, pad)


## نوارِ دوم: چه سهمی از آسیب مالِ ماست و چه سهمی مالِ حریف.
## اگر شیطان زنده بماند، همین برنده را تعیین می‌کند — پس عمداً هم‌اندازه‌ی
## نوارِ جان و درست زیرش است، نه یک عددِ ریز در گوشه.
func _draw_damage(info: Dictionary, w: float, pad: float) -> void:
	var damage: Dictionary = info.get("damage", {})
	var mine := Global.my_team
	var ally := 0
	var foe := 0
	for team in damage.keys():
		var n := int(damage[team])
		if mine != "" and str(team) == mine:
			ally += n
		else:
			foe += n

	var y := 52.0
	var total: float = float(ally + foe)
	var track := Rect2(pad, y, w - pad * 2.0, SPLIT_H)
	draw_rect(track, COL_TRACK, true)
	if total > 0.0:
		var k: float = float(ally) / total
		draw_rect(Rect2(track.position, Vector2(track.size.x * k, track.size.y)),
			COL_ALLY, true)
		draw_rect(Rect2(Vector2(track.position.x + track.size.x * k, track.position.y),
			Vector2(track.size.x * (1.0 - k), track.size.y)), COL_FOE, true)
	draw_rect(track, Color(0, 0, 0, 0.45), false, 1.0)

	# عددها زیرِ نوار، هرکدام سمتِ خودش
	var ty := y + SPLIT_H + 18.0
	_text(_fa(ally), Vector2(pad, ty), NUMBER_FS, COL_ALLY)
	var label := "آسیب به شیطان"
	var lw := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FS).x
	_text(label, Vector2((w - lw) * 0.5, ty), LABEL_FS, COL_DIM)
	var fw := FONT.get_string_size(_fa(foe), HORIZONTAL_ALIGNMENT_LEFT, -1, NUMBER_FS).x
	_text(_fa(foe), Vector2(w - pad - fw, ty), NUMBER_FS, COL_FOE)


func _text(s: String, at: Vector2, px: int, col: Color) -> void:
	draw_string(FONT, at + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px,
		Color(0, 0, 0, 0.85))
	draw_string(FONT, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _fa(value: int) -> String:
	const DIGITS := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var out := ""
	for ch in str(absi(value)):
		out += DIGITS[int(ch)]
	return out
