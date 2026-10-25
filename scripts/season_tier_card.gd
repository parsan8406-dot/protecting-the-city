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
const COLOR_BLUE := MissionArt.COLOR_BLUE_SOFT
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

	_free_button.pressed.connect(func() -> void:
		UIFx.tap(_free_button)
		claim_requested.emit(level, "free"))
	_premium_button.pressed.connect(func() -> void:
		UIFx.tap(_premium_button)
		claim_requested.emit(level, "premium"))
	UIFx.bind_press_feedback(_free_button)
	UIFx.bind_press_feedback(_premium_button)

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

	# قفل روی خانه‌ای که هنوز باز نشده — چه به‌خاطر پله، چه به‌خاطر بتل‌پس
	lock.visible = state == "locked" or state == "premium_locked"
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
	cell.modulate = Color(1, 1, 1, 0.55) if state == "claimed" else Color(1, 1, 1, 1)

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

func _make_ready_style(base: StyleBox, accent: Color) -> StyleBox:
	var flat := base.duplicate() as StyleBoxFlat
	if flat == null:
		return base
	flat.set_border_width_all(2)
	flat.border_color = accent
	return flat

func _make_level_on_style() -> StyleBox:
	var flat := _style_level_off.duplicate() as StyleBoxFlat
	if flat == null:
		return _style_level_off
	flat.bg_color = Color(0.157, 0.118, 0.031, 1.0)
	flat.border_color = COLOR_GOLD
	return flat

## ورود پلکانی ستون‌ها وقتی صفحه باز می‌شود
func play_pop(delay: float) -> void:
	var target_alpha := modulate.a
	modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(self, "modulate:a", target_alpha, 0.25)
