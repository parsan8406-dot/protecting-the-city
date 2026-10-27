extends VBoxContainer
## یک ستون از نردبان «پاداش های فصل».
##
## هر پله دو جایزه دارد و هر دو در همین ستون‌اند:
##   بالا  → مسیر طلایی (بتل‌پس خریداری‌شده)
##   پایین → مسیر رایگان
##
## هیچ تصمیمی اینجا گرفته نمی‌شود. حالتِ هر خانه (`state`) را سرور در پاسخ
## /season/pass می‌فرستد و اینجا فقط رنگ و قفل و دکمه می‌شود:
##   locked          هنوز به این پله نرسیده
##   premium_locked  به پله رسیده ولی بتل‌پس طلایی ندارد
##   ready           آماده‌ی دریافت
##   claimed         گرفته شده
##
## زدن دکمه فقط سیگنال می‌دهد؛ واریز جایزه با POST /season/pass/claim سمت
## سرور انجام می‌شود و سرور خودش دوباره چک می‌کند.
##
## استفاده (اول add_child، بعد setup):
##   var card := preload("res://secense/season_tier_card.tscn").instantiate()
##   ladder.add_child(card)
##   card.setup(tier)

## بازیکن روی دکمه‌ی دریافت زد — track یکی از "free" یا "premium"
signal claim_requested(level: int, track: String)

const COLOR_GOLD := MissionArt.COLOR_GOLD
## اکسنتِ مسیرِ رایگان — کرمِ روشن (طلایی مالِ مسیرِ طلایی و «آماده» است)
const COLOR_BLUE := Color(0.96, 0.9, 0.78, 1.0)
const COLOR_TEXT := MissionArt.COLOR_TEXT
const COLOR_MUTED := MissionArt.COLOR_MUTED
const COLOR_DIM := MissionArt.COLOR_DIM

## هر چند پله یک‌بار تاجِ «پله‌ی مهم» بگذاریم
const MILESTONE_EVERY := 5

@onready var _level_badge: PanelContainer = $LevelBadge
@onready var _level_label: Label = $LevelBadge/Row/LevelLabel
@onready var _crown: TextureRect = $LevelBadge/Row/Crown

@onready var _premium_cell: PanelContainer = $PremiumCell
@onready var _premium_icon: TextureRect = $PremiumCell/Body/Icon
@onready var _premium_amount: Label = $PremiumCell/Body/Amount
@onready var _premium_title: Label = $PremiumCell/Body/TitleLabel
@onready var _premium_lock: PanelContainer = $PremiumCell/Lock
@onready var _premium_lock_icon: TextureRect = $PremiumCell/Lock/LockIcon
@onready var _premium_button: Button = $PremiumCell/PremiumButton

@onready var _free_cell: PanelContainer = $FreeCell
@onready var _free_icon: TextureRect = $FreeCell/Body/Icon
@onready var _free_amount: Label = $FreeCell/Body/Amount
@onready var _free_title: Label = $FreeCell/Body/TitleLabel
@onready var _free_lock: PanelContainer = $FreeCell/Lock
@onready var _free_lock_icon: TextureRect = $FreeCell/Lock/LockIcon
@onready var _free_button: Button = $FreeCell/FreeButton

## استایل‌های خانه — یک بار از صحنه خوانده و بین همه‌ی کارت‌ها مشترک می‌شوند
var _style_free: StyleBox = null
var _style_gold: StyleBox = null
var _style_free_ready: StyleBox = null
var _style_gold_ready: StyleBox = null
var _style_level_off: StyleBox = null
var _style_level_on: StyleBox = null

## شماره‌ی این پله — صفحه با همین عدد درخواست دریافت می‌فرستد
var level: int = 0

var _tier: Dictionary = {}
var _built := false

func _ready() -> void:
	_style_free = _free_cell.get_theme_stylebox("panel")
	_style_gold = _premium_cell.get_theme_stylebox("panel")
	# استایل «آماده» در خود صحنه نیست چون فقط موقع لازم گذاشته می‌شود؛
	# از روی همان دو تا ساخته می‌شود تا رنگ‌ها یک جا بمانند.
	_style_free_ready = _make_ready_style(_style_free, COLOR_BLUE)
	_style_gold_ready = _make_ready_style(_style_gold, COLOR_GOLD)
	_style_level_off = _level_badge.get_theme_stylebox("panel")
	_style_level_on = _make_level_on_style()

	_crown.texture = MissionArt.texture_for("crown")
	_premium_lock_icon.texture = MissionArt.texture_for("lock")
	_free_lock_icon.texture = MissionArt.texture_for("lock")

	# E2/C9 کلِ خانه‌ی آماده لمس‌شدنی است (نه یک دکمه‌ی ریز ته‌اش). دکمه
	# scroll_safe است تا کشیدنِ نردبان «دریافت» حساب نشود.
	_free_button.pressed.connect(func() -> void:
		UIFx.tap(_free_cell)
		claim_requested.emit(level, "free"))
	_premium_button.pressed.connect(func() -> void:
		UIFx.tap(_premium_cell)
		claim_requested.emit(level, "premium"))
	for b: Button in [_free_button, _premium_button]:
		var empty := StyleBoxEmpty.new()
		var down := MenuUI.box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 0, 8)
		for st in ["normal", "hover", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, empty)
		b.add_theme_stylebox_override("pressed", down)
		b.add_theme_stylebox_override("hover_pressed", down)
	_free_cell.draw.connect(_draw_claim_tag.bind(_free_cell))
	_premium_cell.draw.connect(_draw_claim_tag.bind(_premium_cell))
	draw.connect(_draw_track)

	if not _tier.is_empty():
		_apply(_tier)
	_built = true

## پر کردن کارت از یک آیتم `tiers` در پاسخ /season/pass
func setup(tier: Dictionary) -> void:
	_tier = tier
	level = int(tier.get("level", 0))
	if is_node_ready() or _built:
		_apply(tier)

func _apply(tier: Dictionary) -> void:
	_level_label.text = MissionArt.fa_number(level)
	_unlocked = bool(tier.get("unlocked", false))
	queue_redraw()

	var milestone := level % MILESTONE_EVERY == 0
	_crown.visible = milestone
	_crown.modulate = COLOR_GOLD
	_level_badge.add_theme_stylebox_override(
		"panel", _style_level_on if milestone else _style_level_off)
	_level_label.add_theme_color_override(
		"font_color", COLOR_GOLD if milestone else COLOR_MUTED)

	# سرور دو زیرشیء free و premium می‌فرستد. اگر نسخه‌ی قدیمی سرور بالا بود
	# و نداشتشان، از خود پله می‌سازیم تا صفحه خالی نماند.
	var free: Dictionary = tier.get("free", {})
	if free.is_empty():
		free = tier
	var premium: Dictionary = tier.get("premium", {})

	_apply_cell(free, _free_cell, _free_icon, _free_amount, _free_title,
		_free_lock, _free_button, _style_free, _style_free_ready, COLOR_BLUE)

	# پله‌ای که مسیر طلایی ندارد (سرور قدیمی) خانه‌اش اصلاً نشان داده نمی‌شود
	_premium_cell.visible = not premium.is_empty()
	if _premium_cell.visible:
		_apply_cell(premium, _premium_cell, _premium_icon, _premium_amount,
			_premium_title, _premium_lock, _premium_button,
			_style_gold, _style_gold_ready, COLOR_GOLD)

## یک خانه (رایگان یا طلایی) را از روی حالتی که سرور داده می‌چیند
func _apply_cell(
	data: Dictionary,
	cell: PanelContainer,
	icon: TextureRect,
	amount: Label,
	title: Label,
	lock: PanelContainer,
	button: Button,
	style_normal: StyleBox,
	style_ready: StyleBox,
	accent: Color,
) -> void:
	var state := str(data.get("state", "locked"))

	var icon_id := str(data.get("icon", ""))
	# پله‌ای که اسکین می‌دهد عکس خودِ اسکین را نشان می‌دهد
	icon.texture = MissionArt.reward_texture(data)
	title.text = str(data.get("title", "—"))
	# آیتم آرایشی عدد ندارد؛ نشان دادن سکه‌ی همراهش زیر یک اسکین گیج‌کننده است
	amount.visible = not MissionArt.is_cosmetic(icon_id)
	amount.text = _amount_text(data)

	var ready := state == "ready"
	cell.add_theme_stylebox_override("panel", style_ready if ready else style_normal)
	# حالتِ خانه برای نقاشیِ برچسب («دریافت» / تیک)
	cell.set_meta("state", state)
	cell.queue_redraw()
	_set_glow(cell, ready)
	# جای برچسبِ «دریافت»/تیک در پایینِ خانه — عنوان آن موقع کنار می‌رود
	title.visible = not ready

	# قفل روی خانه‌ای که هنوز باز نشده — چه به‌خاطر پله، چه به‌خاطر بتل‌پس
	lock.visible = state == "locked" or state == "premium_locked"
	lock.modulate = Color.WHITE
	# قفلِ «بتل‌پس نداری» طلایی است تا از قفلِ «هنوز نرسیدی» فرق کند
	if lock.visible:
		var lock_icon := lock.get_child(0) as TextureRect
		if lock_icon != null:
			lock_icon.modulate = COLOR_GOLD if state == "premium_locked" else COLOR_MUTED

	button.visible = ready
	# آیکنِ سکه/جم آرت رنگی است و نباید تینت بخورد
	var art := MissionArt.is_art_icon(str(data.get("icon", "")))
	match state:
		"ready":
			icon.modulate = Color.WHITE
			amount.add_theme_color_override("font_color", accent)
			title.add_theme_color_override("font_color", COLOR_TEXT)
			modulate = Color(1, 1, 1, 1)
		"claimed":
			icon.modulate = Color.WHITE if art else COLOR_DIM
			amount.add_theme_color_override("font_color", COLOR_DIM)
			title.add_theme_color_override("font_color", COLOR_DIM)
		_:
			icon.modulate = Color.WHITE if art else COLOR_MUTED
			amount.add_theme_color_override("font_color", COLOR_MUTED)
			title.add_theme_color_override("font_color", COLOR_DIM)

	# خانه‌ی گرفته‌شده عمداً کم‌رنگ است تا خانه‌ی آماده توی چشم باشد
	cell.self_modulate = Color(1, 1, 1, 0.55) if state == "claimed" else Color(1, 1, 1, 1)
	(cell.get_node("Body") as CanvasItem).modulate = Color(1, 1, 1, 0.45) if state == "claimed" else Color.WHITE

## متن عدد جایزه: بزرگ‌ترین چیزی که این خانه می‌دهد
func _amount_text(data: Dictionary) -> String:
	var gems := int(data.get("gems", 0))
	var cups := int(data.get("cups", 0))
	var coins := int(data.get("coins", 0))
	if gems > 0:
		return MissionArt.fa_grouped(gems)
	if cups > 0:
		return MissionArt.fa_number(cups)
	return MissionArt.fa_grouped(coins)

## E2/V5 خانه‌ی آماده در هر دو مسیر طلایی و درخشان است (طلایی = جایزه)؛
## شکلِ متمایزش برچسبِ «دریافت» پایینِ خانه است (V2: رنگ + شکل)
func _make_ready_style(base: StyleBox, _accent: Color) -> StyleBox:
	var flat := base.duplicate() as StyleBoxFlat
	if flat == null:
		return base
	flat.bg_color = Color(0.2, 0.14, 0.03, 1.0)
	flat.set_border_width_all(2)
	flat.border_color = COLOR_GOLD
	flat.shadow_color = Color(1.0, 0.72, 0.2, 0.45)
	flat.shadow_size = 9
	return flat

func _make_level_on_style() -> StyleBox:
	var flat := _style_level_off.duplicate() as StyleBoxFlat
	if flat == null:
		return _style_level_off
	flat.bg_color = Color(0.157, 0.118, 0.031, 1.0)
	flat.border_color = COLOR_GOLD
	return flat

## E12/C9 «پله‌ی بعدی»: اولین پله‌ای که هنوز باز نشده.
## جایزه‌اش رنگِ کامل می‌گیرد (قفل سرِ جایش می‌ماند — صادقانه، فقط دیدنی‌تر)
## و برچسبِ «بعدی» با نبضِ آرام. شمارش یا تایمرِ فشار در کار نیست.
var _next_pulse: Tween = null
var _is_next := false

func set_next(on: bool) -> void:
	if not is_node_ready() or on == _is_next:
		return
	_is_next = on
	if _next_pulse != null and _next_pulse.is_valid():
		_next_pulse.kill()
	_next_pulse = null
	_level_badge.scale = Vector2.ONE
	if not on:
		_apply(_tier)
		return
	_level_label.text = "بعدی %s" % MissionArt.fa_number(level)
	_level_label.add_theme_color_override("font_color", COLOR_GOLD)
	_level_badge.add_theme_stylebox_override("panel", _style_level_on)
	for pair in [[_free_cell, _free_icon, _free_amount, _free_lock, COLOR_BLUE],
			[_premium_cell, _premium_icon, _premium_amount, _premium_lock, COLOR_GOLD]]:
		var cell: Control = pair[0]
		if not cell.visible:
			continue
		(pair[1] as Control).modulate = Color.WHITE
		(pair[2] as Label).add_theme_color_override("font_color", pair[4])
		# قفل کم‌رنگ‌تر تا خودِ جایزه دیده شود
		(pair[3] as Control).modulate = Color(1, 1, 1, 0.55)
	_level_badge.pivot_offset = _level_badge.size * 0.5
	_next_pulse = create_tween().set_loops()
	_next_pulse.tween_property(_level_badge, "scale", Vector2(1.06, 1.06), 0.8) 		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_next_pulse.tween_property(_level_badge, "scale", Vector2.ONE, 0.8) 		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## ورود پلکانی ستون‌ها وقتی صفحه باز می‌شود
func play_pop(delay: float) -> void:
	var target_alpha := modulate.a
	modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(self, "modulate:a", target_alpha, 0.25)


# ---------------------------------------------------------- مسیر و برچسب‌ها

## پله‌ی باز شده؟ (خطِ مسیر تا اینجا طلایی است)
var _unlocked := false
## نبضِ هاله‌ی خانه‌های آماده (یکی برای هر خانه)
var _glows := {}

## V3/C9 «مسیرِ» نردبان: خطی که از پشتِ نشانِ سطح‌ها رد می‌شود و تا پله‌ی
## فعلی طلایی است — ستون‌های جدا یک مسیرِ پیوسته دیده می‌شوند.
func _draw_track() -> void:
	if not is_node_ready():
		return
	var sep := 8.0
	if get_parent() is BoxContainer:
		sep = float((get_parent() as BoxContainer).get_theme_constant("separation"))
	var y := _level_badge.position.y + _level_badge.size.y * 0.5
	var col := COLOR_GOLD if _unlocked else Color(0.3, 0.29, 0.3, 1.0)
	draw_line(Vector2(-sep * 0.5 - 1.0, y), Vector2(size.x + sep * 0.5 + 1.0, y), col, 3.0)


## برچسبِ پایینِ خانه: «دریافت» طلایی روی خانه‌ی آماده، تیکِ طلایی روی گرفته‌شده
func _draw_claim_tag(cell: PanelContainer) -> void:
	var state := str(cell.get_meta("state", ""))
	var font: Font = MenuUI.FONT
	if state == "ready":
		var h := 24.0
		var r := Rect2(Vector2(6, cell.size.y - h - 6), Vector2(cell.size.x - 12, h))
		cell.draw_style_box(MenuUI.box(COLOR_GOLD, Color(1, 0.95, 0.7), 1, 6), r)
		var fs := 14
		var base := r.position.y + (r.size.y + font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		cell.draw_string(font, Vector2(r.position.x, base), "دریافت", HORIZONTAL_ALIGNMENT_CENTER,
			r.size.x, fs, Color(0.2, 0.12, 0.0))
	elif state == "claimed":
		var c := Vector2(cell.size.x - 15, 15)
		cell.draw_circle(c, 11.0, COLOR_GOLD)
		cell.draw_polyline(PackedVector2Array([c + Vector2(-5, 0), c + Vector2(-1, 4), c + Vector2(5, -4)]),
			Color(0.2, 0.12, 0.0), 2.5, true)


## هاله‌ی خانه‌ی آماده آرام کم‌وزیاد می‌شود (بدون شیدر)
func _set_glow(cell: PanelContainer, on: bool) -> void:
	var old: Tween = _glows.get(cell, null)
	if old != null and old.is_valid():
		old.kill()
	_glows.erase(cell)
	var sb := cell.get_theme_stylebox("panel") as StyleBoxFlat
	if not on or sb == null or not is_inside_tree():
		return
	var t := create_tween().set_loops()
	t.tween_method(func(v: float) -> void:
		sb.shadow_size = int(v)
		cell.queue_redraw(), 5.0, 13.0, 0.75).set_trans(Tween.TRANS_SINE)
	t.tween_method(func(v: float) -> void:
		sb.shadow_size = int(v)
		cell.queue_redraw(), 13.0, 5.0, 0.75).set_trans(Tween.TRANS_SINE)
	_glows[cell] = t
