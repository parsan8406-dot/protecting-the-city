extends Control
## نوارِ راند: تایمرِ وسطِ بالا، زنده‌های حریف سمتِ چپ و زنده‌های تیمِ خودمان
## سمتِ راستش، و صفحه‌ی پایانِ مسابقه.
##
## دو خانواده قانون داریم و سرور می‌گوید کدام است (round_state → score_kills):
##   حذفی           زیرِ تایمر تعدادِ «زنده»ی هر تیم نوشته می‌شود
##   عملیات انتقام  تعدادِ «کشته»ی هر تیم — چون برنده را همین تعیین می‌کند
##
## همه‌ی حساب‌ها روی سرور انجام می‌شود (gun_game_server/match_round.go) و
## این‌جا فقط نمایش داده می‌شود؛ کلاینت هیچ عددی را خودش حساب نمی‌کند.
##
## تایمر بین دو پیامِ سرور خودش می‌شمارد تا تکان‌تکان نشود، ولی هر بار که
## round_state می‌آید دوباره با سرور هماهنگ می‌شود.

const FONT := preload("res://fonts/Lalezar-Regular.ttf")

const COL_GOLD  := Color(0.96, 0.78, 0.28)
const COL_TEXT  := Color(0.97, 0.95, 0.90)
const COL_DIM   := Color(0.62, 0.60, 0.66)
const COL_ALLY  := Color(0.33, 0.74, 1.00)
const COL_FOE   := Color(0.93, 0.27, 0.32)
const COL_PANEL := Color(0.07, 0.06, 0.09, 0.88)

## زیر این مقدار تایمر قرمز می‌شود
const URGENT_AT := 30.0
## ده ثانیه‌ی آخر: هر ثانیه یک تپشِ طلایی → قرمز
const FINAL_AT := 10
## روشنیِ لحظه‌ی تپش و مدتِ برگشتش
const PULSE_GLOW := Color(1.35, 1.3, 1.2, 1.0)
const PULSE_TIME := 0.45

var _timer_label: Label = null
var _ally_label: Label = null
var _foe_label: Label = null
var _mode_label: Label = null
var _panel: Control = null
var _ally_icon: HudIconRect = null
var _foe_icon: HudIconRect = null

var _seconds_left := 0.0
var _running := false
var _over := false
## آخرین «زنده»ی هر تیم که سرور فرستاده. نگه داشته می‌شود چون امتیازِ
## حالتِ شیطان از پیامِ دیگری (demon_state) می‌آید و هر بار که آن می‌رسد
## باید بدونِ round_state تازه هم بتوانیم عددها را دوباره بکشیم.
var _alive: Dictionary = {}
## صفحه‌ی برد/باخت (match_result_screen.gd) و پاداشی که شاید زودتر از آن رسیده
var _result: MatchResultScreen = null
var _pending_reward: Dictionary = {}
## بازیِ سریع وقتِ تمام‌شدنی ندارد: تایمر بالا می‌رود (مدتِ زنده ماندن)
var _count_up := false
## آخرین ثانیه‌ای که روی تایمر نوشته شد — متن فقط با عوض شدنِ ثانیه
## دوباره ساخته می‌شود، نه هر فریم (هر بار ساختنِ متن یعنی شکل‌دهیِ دوباره‌ی فونت)
var _shown_second := -1
var _shown_count_up := false
var _pulse_tw: Tween = null
## اولین شمارش پالس نمی‌خورد (فقط تغییرِ واقعی)
var _counts_shown := false

## فاصله‌ی ناچ/لبه‌ی بالا — GameHUD ست می‌کند
var top_inset := 12.0:
	set(v):
		top_inset = v
		if _panel != null:
			_panel.offset_top = v
			_panel.offset_bottom = v + PLATE_H

## قابِ طلایی-آبیِ تایمر (آرتِ بازی). نسبتش ۳ به ۱ است، پس قاب هم همین
## نسبت را دارد تا کشیده نشود. اگر فایل نبود، همان ذوزنقه‌ی کدی کشیده می‌شود.
const PLATE_TEX_PATH := "res://assets/ui/hud/show_time.png"
const PLATE_W := 300.0
const PLATE_H := 100.0

var _plate_tex: Texture2D = null


func _ready() -> void:
	# set_anchors_and_offsets_preset و نه set_anchors_preset: دومی فقط لنگرها
	# را ست می‌کند و اندازه را دست نمی‌زند، پس ریشه صفر می‌ماند و هرچه
	# داخلش لنگر انداخته روی گوشه‌ی (۰,۰) جمع می‌شود.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

	if not Network.round_state_updated.is_connected(_on_round_state):
		Network.round_state_updated.connect(_on_round_state)
	if not Network.match_over.is_connected(_on_match_over):
		Network.match_over.connect(_on_match_over)
	if not Network.match_reward.is_connected(_on_match_reward):
		Network.match_reward.connect(_on_match_reward)
	# «عملیات حذف شیطان»: امتیاز از این پیام می‌آید، نه از round_state
	if not Network.demon_state.is_connected(_on_demon_state):
		Network.demon_state.connect(_on_demon_state)


func _process(delta: float) -> void:
	if not _running or _over:
		return
	if _count_up:
		_seconds_left += delta
	else:
		_seconds_left = maxf(_seconds_left - delta, 0.0)
	_refresh_timer()


# ============================ ساخت ============================

## قابِ وسطِ بالا به سبکِ عکسِ مرجع:
##   [جمجمه‌ی قرمز + حریف‌های زنده]  [ساعت‌شنی + تایمر / زیرنویس]  [آدمکِ آبی + هم‌تیمی‌های زنده]
func _build() -> void:
	if ResourceLoader.exists(PLATE_TEX_PATH):
		_plate_tex = load(PLATE_TEX_PATH)
	_panel = Control.new()
	_panel.name = "TimerPlate"
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_left = -PLATE_W * 0.5
	_panel.offset_right = PLATE_W * 0.5
	_panel.offset_top = top_inset
	_panel.offset_bottom = top_inset + PLATE_H
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.draw.connect(_draw_plate)
	add_child(_panel)

	# محتوا داخلِ قسمتِ تیره‌ی قاب می‌نشیند: بالای نگینِ پایین، بینِ دو گوشه‌ی تیز
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = PLATE_W * 0.13
	row.offset_right = -PLATE_W * 0.13
	# قسمتِ تیره‌ی آرت از ۲۶٪ تا ۷۰٪ ارتفاع است؛ زیرش نگینِ آبی می‌نشیند
	row.offset_top = PLATE_H * 0.17
	row.offset_bottom = -PLATE_H * 0.37
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)

	# چپ: حریف‌های زنده
	var foe := _count_box(COL_FOE)
	_foe_icon = HudIconRect.new().setup("skull", 22, COL_FOE)
	foe.add_child(_foe_icon)
	_foe_label = _label("۰", 24, COL_FOE)
	foe.add_child(_foe_label)
	row.add_child(foe)

	# وسط: تایمر و زیرنویس
	var mid := VBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", -15)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(mid)

	var clock := HBoxContainer.new()
	clock.alignment = BoxContainer.ALIGNMENT_CENTER
	clock.add_theme_constant_override("separation", 6)
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock.add_child(HudIconRect.new().setup("hourglass", 20, COL_TEXT))
	_timer_label = _label("--:--", 30, COL_TEXT)
	clock.add_child(_timer_label)
	mid.add_child(clock)

	# زیرنویس: «زنده» یا «کشته» (با قانونِ راند)، یا متنی که بازی می‌دهد
	# (۱۷ و نه ریزتر — روی گوشی باید از گوشه‌ی چشم هم خوانده شود)
	_mode_label = _label("زنده", 17, COL_TEXT)
	_mode_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_mode_label.add_theme_constant_override("shadow_offset_y", 1)
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(_mode_label)

	# راست: هم‌تیمی‌های زنده
	var ally := _count_box(COL_ALLY)
	_ally_label = _label("۰", 24, COL_ALLY)
	ally.add_child(_ally_label)
	_ally_icon = HudIconRect.new().setup("people", 22, COL_ALLY)
	ally.add_child(_ally_icon)
	row.add_child(ally)


func _count_box(colour: Color) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_theme_constant_override("separation", 3)
	b.custom_minimum_size = Vector2(52, 0)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_meta("colour", colour)
	return b


## بدنه‌ی قاب: آرتِ show_time.png، یا (اگر نبود) ذوزنقه‌ی تیره با لبه‌ی طلایی
func _draw_plate() -> void:
	var w := _panel.size.x
	var h := _panel.size.y
	if _plate_tex != null:
		_panel.draw_texture_rect(_plate_tex, Rect2(0, 0, w, h), false)
		# رنگِ دو تیم، کم‌رنگ زیرِ عددها — تا در یک نگاه معلوم باشد کدام طرفِ کیست
		_panel.draw_rect(Rect2(w * 0.16, h * 0.27, w * 0.16, h * 0.42),
			Color(COL_FOE.r, COL_FOE.g, COL_FOE.b, 0.13))
		_panel.draw_rect(Rect2(w * 0.68, h * 0.27, w * 0.16, h * 0.42),
			Color(COL_ALLY.r, COL_ALLY.g, COL_ALLY.b, 0.13))
		return
	var body := PackedVector2Array([
		Vector2(0, 0), Vector2(w, 0), Vector2(w - 22, h), Vector2(22, h)])
	_panel.draw_colored_polygon(body, COL_PANEL)
	# دو خانه‌ی کناری با رنگِ تیم
	var side_w := 66.0
	_panel.draw_colored_polygon(PackedVector2Array([
		Vector2(8, 6), Vector2(8 + side_w, 6), Vector2(side_w + 2, h - 8), Vector2(24, h - 8)]),
		Color(COL_FOE.r, COL_FOE.g, COL_FOE.b, 0.14))
	_panel.draw_colored_polygon(PackedVector2Array([
		Vector2(w - 8 - side_w, 6), Vector2(w - 8, 6), Vector2(w - 24, h - 8), Vector2(w - side_w - 2, h - 8)]),
		Color(COL_ALLY.r, COL_ALLY.g, COL_ALLY.b, 0.14))
	var edge := Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, 0.85)
	_panel.draw_polyline(PackedVector2Array([
		Vector2(0, 0), Vector2(22, h), Vector2(w - 22, h), Vector2(w, 0)]), edge, 2.5, true)
	_panel.draw_line(Vector2(0, 1), Vector2(w, 1), edge, 2.0)
	# نگینِ طلایی وسطِ لبه‌ی پایین
	var gem := Vector2(w * 0.5, h)
	_panel.draw_colored_polygon(PackedVector2Array([
		gem + Vector2(0, -7), gem + Vector2(9, 0), gem + Vector2(0, 7), gem + Vector2(-9, 0)]), COL_GOLD)


func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ============================ سرور ============================

func _on_round_state(alive: Dictionary, seconds_left: int) -> void:
	if _over:
		return
	_running = true
	_seconds_left = float(seconds_left)
	_alive = alive
	_refresh_timer()
	_refresh_counts()


## امتیازِ «حذف شیطان» با هر تیر عوض می‌شود و در پیامِ demon_state می‌آید،
## نه round_state (که فقط سرِ مرگ و تولد فرستاده می‌شود). بدونِ این، عددِ
## بالای صفحه تا مرگِ بعدیِ یک نفر سرِ جایش خشک می‌ماند.
func _on_demon_state(_data: Dictionary) -> void:
	if _over:
		return
	_refresh_counts()


## دو عددِ کنارِ تایمر — کدام عدد، به قانونِ حالت بستگی دارد.
func _refresh_counts() -> void:
	if _ally_label == null or _foe_label == null:
		return
	var alive := _alive

	# عددِ زیرِ تایمر به قانونِ حالت بستگی دارد و سرور خودش می‌گوید کدام
	# است (score_kills / demon)، پس کلاینت قانون را حدس نمی‌زند:
	#   حذفی   «زنده»   — چند نفر از هر تیم هنوز سرِ پا هستند
	#   انتقام «کشته»   — همان چیزی که برنده را تعیین می‌کند
	#   شیطان  «امتیاز» — آسیبی که هر تیم به شیطان زده. مرگ این‌جا موقتی
	#            است، پس «زنده» عملاً همیشه پر بود و چیزی نمی‌گفت؛ امتیاز
	#            همان چیزی است که آخرِ وقت برنده را تعیین می‌کند. جانِ
	#            تک‌تکِ نفرات را پنلِ زیرِ همین قاب نشان می‌دهد.
	var by_kills := bool(Network.round_info.get("score_kills", false))
	var by_demon := bool(Network.round_info.get("demon", false))
	var source: Dictionary = alive
	var compact := false
	if by_demon:
		source = Network.demon_info.get("damage", {})
		compact = true          # آسیب چهار پنج رقمی است و در قاب جا نمی‌شود
	elif by_kills:
		source = Network.round_info.get("score", {})
	if _mode_label != null:
		_mode_label.text = "امتیاز" if by_demon else ("کشته" if by_kills else "زنده")

	var mine := Global.my_team
	var ally := 0
	var foe := 0
	for team in source.keys():
		var n := int(source[team])
		if str(team) == mine:
			ally += n
		else:
			foe += n
	# در تمرینِ بی‌تیم همه حریف‌اند؛ آن‌وقت این نمایش معنی ندارد
	if mine == "":
		ally = 0
		foe = 0
		for team in source.keys():
			foe += int(source[team])
	var ally_txt := _fa_short(ally) if compact else _fa(ally)
	var foe_txt := _fa_short(foe) if compact else _fa(foe)
	# امتیازِ شیطان با هر تیر عوض می‌شود؛ پالس فقط برای شمارشِ زنده/کشته  # V10
	if not compact and _counts_shown:
		if _ally_label.text != ally_txt:
			_pop(_ally_label)
		if _foe_label.text != foe_txt:
			_pop(_foe_label)
	_counts_shown = true
	_ally_label.text = ally_txt
	_foe_label.text = foe_txt
	# امتیاز چند حرفی است («۴٫۲ک») و با فونتِ عددِ تک‌رقمی، تایمرِ وسط را
	# له می‌کند — خانه‌های کناری فقط ۵۲ پیکسل عرض دارند
	var fs := 19 if compact else 24
	_ally_label.add_theme_font_size_override("font_size", fs)
	_foe_label.add_theme_font_size_override("font_size", fs)


## بازیِ سریعِ آفلاین سروری ندارد که round_state بفرستد؛ صحنه خودش عددها را
## می‌دهد. تایمر بالا می‌رود (مدتِ زنده ماندن) و subtitle مثلاً «کشته: ۳» است.
func set_local(ally_alive: int, foe_alive: int, seconds: float, subtitle: String) -> void:
	if _over:
		return
	_count_up = true
	_running = true
	_seconds_left = seconds
	_ally_label.text = _fa(ally_alive)
	_foe_label.text = _fa(foe_alive)
	_mode_label.text = subtitle
	_refresh_timer()


func _refresh_timer() -> void:
	var s := int(floor(_seconds_left)) if _count_up else int(ceil(_seconds_left))
	if s == _shown_second and _count_up == _shown_count_up:
		return
	_shown_second = s
	_shown_count_up = _count_up
	_timer_label.text = "%s:%s" % [_fa2(s / 60), _fa2(s % 60)]

	if _count_up or s > URGENT_AT:
		_stop_pulse()
		_set_timer_colour(COL_GOLD)
	elif s > FINAL_AT:
		# آخرین نیم‌دقیقه قرمز — بازیکن باید بفهمد وقت دارد تمام می‌شود
		_stop_pulse()
		_set_timer_colour(COL_FOE)
	else:
		_pulse_timer()


## ده ثانیه‌ی آخر: هر ثانیه یک بار طلایی و روشن می‌شود و نرم به قرمز برمی‌گردد.
## رنگ و modulate تویین می‌شوند و نه scale — لیبل داخلِ HBox است و هر بار
## که چیدمان به‌روز شود scale آن را به ۱ برمی‌گرداند.
func _pulse_timer() -> void:
	_stop_pulse()
	_set_timer_colour(COL_GOLD)
	_timer_label.modulate = PULSE_GLOW
	_pulse_tw = create_tween().set_parallel()
	_pulse_tw.tween_method(_set_timer_colour, COL_GOLD, COL_FOE, PULSE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tw.tween_property(_timer_label, "modulate", Color.WHITE, PULSE_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _stop_pulse() -> void:
	if _pulse_tw != null and _pulse_tw.is_valid():
		_pulse_tw.kill()
	_pulse_tw = null
	if _timer_label != null:
		_timer_label.modulate = Color.WHITE


func _set_timer_colour(c: Color) -> void:
	_timer_label.add_theme_color_override("font_color", c)


func _on_match_over(winner_team: String, draw: bool) -> void:
	if _over:
		return
	_over = true
	_running = false

	# مساوی یعنی هر دو تیم برنده‌اند (سرور: match_round.go → endRound، که
	# پاداشِ برد را هم به هر دو می‌دهد)، پس صفحه‌ی پایان هم باید همین را
	# بگوید — نه «برنده‌ای نداشت».
	var outcome := MatchResultScreen.Outcome.DRAW
	if not draw:
		if Global.my_team != "" and winner_team == Global.my_team:
			outcome = MatchResultScreen.Outcome.WIN
		else:
			outcome = MatchResultScreen.Outcome.LOSE
	_show_result(outcome, _final_score_text())


## نتیجه‌ی امتیازی («۷ − ۵») برای حالت‌هایی که با عدد تصمیم می‌گیرند.
## رشته‌ی خالی یعنی این حالت امتیازی نیست و چیزی نشان داده نمی‌شود.
##
## در «عملیات حذف شیطان» عددِ معنادار آسیبِ زده‌شده به شیطان است، نه
## تعدادِ کشته — همان چیزی که آخرِ وقت برنده را تعیین کرده.
func _final_score_text() -> String:
	var score: Dictionary = Network.round_info.get("final_demon_damage", {})
	if score.is_empty():
		if not bool(Network.round_info.get("score_kills", false)):
			return ""
		score = Network.round_info.get("final_score", {})
		if score.is_empty():
			score = Network.round_info.get("score", {})
	if score.is_empty():
		return ""

	var mine := Global.my_team
	var ally := 0
	var foe := 0
	for team in score.keys():
		var n := int(score[team])
		if str(team) == mine:
			ally += n
		else:
			foe += n
	return "%s − %s" % [_fa(ally), _fa(foe)]


## پاداشِ سرور. ممکن است کمی بعد از match_over برسد، پس جدا به صفحه داده
## می‌شود و صفحه منتظرش نمی‌ماند؛ اگر زودتر رسید نگه داشته می‌شود.
func _on_match_reward(data: Dictionary) -> void:
	_pending_reward = data
	if _result != null:
		_result.set_reward(data)


## صفحه‌ی پایان: «پیروزی» / «شکست» روی زمینِ بازی (match_result_screen.gd)
func _show_result(outcome: MatchResultScreen.Outcome, score_text: String = "") -> void:
	if _result != null:
		return
	_result = MatchResultScreen.new()
	_result.name = "Result"
	_result.outcome = outcome
	_result.score_text = score_text
	add_child(_result)
	if not _pending_reward.is_empty():
		_result.set_reward(_pending_reward)


# ============================ ابزار ============================

func _fa(value: int) -> String:
	const DIGITS := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var out := ""
	for ch in str(absi(value)):
		out += DIGITS[int(ch)]
	return out


## عددِ کوتاه‌شده برای خانه‌های تنگِ قابِ تایمر.
##
## امتیازِ «حذف شیطان» تا ۱۲۰۰۰ می‌رود و با فونتِ ۲۴ در خانه‌ی ۵۲ پیکسلی
## اصلاً جا نمی‌شود. پس از هزار به بالا به «ک» کوتاه می‌شود: ۴۲۰۰ → ۴.۲ک.
## زیرِ هزار عددِ کامل می‌ماند، چون همان‌جاست که تفاوتِ چند صدتایی مهم است.
func _fa_short(value: int) -> String:
	var v := absi(value)
	if v < 1000:
		return _fa(v)
	if v < 10000:
		var whole := v / 1000
		var tenth := (v % 1000) / 100
		if tenth == 0:
			return _fa(whole) + "ک"
		return "%s٫%sک" % [_fa(whole), _fa(tenth)]
	return _fa(v / 1000) + "ک"


## دو رقمی، برای ثانیه‌ها (۰۹ به‌جای ۹)
func _fa2(value: int) -> String:
	var s := _fa(value)
	return s if value >= 10 else "۰" + s


## عدد یک لحظه بزرگ می‌شود تا تغییرش از گوشه‌ی چشم هم دیده شود  # V10
func _pop(l: Label) -> void:
	l.pivot_offset = l.size * 0.5
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(1.35, 1.35), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
