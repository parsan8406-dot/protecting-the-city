extends PanelContainer
## یک ردیف در صفحه‌ی «ماموریت ها».
##
## همه‌ی مقادیر همان‌طور که سرور فرستاده نمایش داده می‌شوند — هیچ عددی اینجا
## حساب نمی‌شود. دکمه فقط سیگنال می‌دهد؛ خودِ واریز جایزه سمت سرور انجام
## می‌شود (POST /missions/claim).
##
## دکمه سه حالت دارد:
##   در حال انجام  → «رفتن» تیره (فرعی)، سیگنال go_requested (می‌رود سراغ حالت‌های بازی)
##   آماده         → «دریافت» طلایی، سیگنال claim_requested
##   گرفته‌شده      → «گرفته شد» خاموش
##
## استفاده (اول add_child، بعد setup):
##   var row := preload("res://secense/mission_row.tscn").instantiate()
##   list.add_child(row)
##   row.setup(mission)

## بازیکن روی دکمه‌ی دریافت زد
signal claim_requested(mission_id: String)
## بازیکن روی «رفتن» زد — ماموریت هنوز تمام نشده و می‌خواهد برود بازی کند
signal go_requested(mission_id: String)

const COLOR_GOLD := MissionArt.COLOR_GOLD
const COLOR_TEXT := MissionArt.COLOR_TEXT
const COLOR_MUTED := MissionArt.COLOR_MUTED
const COLOR_DIM := MissionArt.COLOR_DIM
const COLOR_BLUE := MissionArt.COLOR_BLUE
const PsychProgress := preload("res://scripts/psych_results_progress.gd")

@onready var _done_frame: Panel = $DoneFrame
@onready var _action_button: Button = $Margin/Row/ActionButton
@onready var _coins_label: Label = $Margin/Row/Reward/CoinChip/Box/Value
@onready var _xp_label: Label = $Margin/Row/Reward/XpChip/Box/Value
@onready var _title_label: Label = $Margin/Row/Info/TitleLabel
@onready var _desc_label: Label = $Margin/Row/Info/DescLabel
@onready var _bar: ProgressBar = $Margin/Row/Info/BarRow/Bar
@onready var _amount_label: Label = $Margin/Row/Info/BarRow/AmountLabel
@onready var _icon: TextureRect = $Margin/Row/IconSlot/Icon

## استایل‌های دکمه — یک بار ساخته و بین همه‌ی ردیف‌ها مشترک‌اند.
## static چون شش ردیف صفحه همگی دقیقاً همین سه استایل را می‌خواهند و
## ساختن دوباره‌شان برای هر ردیف فقط حافظه هدر می‌دهد.
static var _style_go: StyleBoxFlat = null
static var _style_go_pressed: StyleBoxFlat = null
static var _style_claim: StyleBoxFlat = null
static var _style_claim_pressed: StyleBoxFlat = null
static var _style_off: StyleBoxFlat = null
## قاب طلاییِ ماموریتِ آماده
static var _style_ready_frame: StyleBoxFlat = null

var mission_id: String = ""

var _mission: Dictionary = {}
var _built := false
## ماموریت تمام شده؟ (تعیین می‌کند دکمه «دریافت» است یا «رفتن»)
var _done := false

func _ready() -> void:
	_build_styles()

	_action_button.pressed.connect(_on_action_pressed)
	UIFx.bind_press_feedback(_action_button)

	if not _mission.is_empty():
		_apply(_mission)
	_built = true

## پر کردن ردیف از یک آیتم `missions` در پاسخ /missions/daily
func setup(mission: Dictionary) -> void:
	_mission = mission
	mission_id = str(mission.get("mission_id", ""))
	if is_node_ready() or _built:
		_apply(mission)

func _on_action_pressed() -> void:
	if _done:
		claim_requested.emit(mission_id)
	else:
		go_requested.emit(mission_id)

func _apply(mission: Dictionary) -> void:
	var target := maxi(int(mission.get("target", 1)), 1)
	var progress := clampi(int(mission.get("progress", 0)), 0, target)
	var done := bool(mission.get("done", false))
	var claimed := bool(mission.get("claimed", false))

	_title_label.text = str(mission.get("title", "—"))
	# سرورهای قدیمی‌تر desc نمی‌فرستند — آن وقت خط توضیح جمع می‌شود
	var desc := str(mission.get("desc", ""))
	_desc_label.text = desc
	_desc_label.visible = not desc.is_empty()

	_icon.texture = MissionArt.texture_for(str(mission.get("icon", "")))

	_coins_label.text = MissionArt.fa_grouped(int(mission.get("coins", 0)))
	_xp_label.text = MissionArt.fa_grouped(int(mission.get("xp", 0)))

	_bar.max_value = float(target)
	_bar.value = 0.0
	# C9 پیشرفتِ اهدایی: نوارِ ناتمام هیچ‌وقت کاملاً خالی دیده نمی‌شود
	var shown := float(target) if done else PsychProgress.bar_value(_bar, progress, target)
	create_tween().tween_property(_bar, "value", shown, 0.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_amount_label.text = "%s / %s" % [
		MissionArt.fa_number(progress), MissionArt.fa_number(target)
	]

	_apply_state(done, claimed)

	# C9/E7 نزدیکِ پایان: نوار طلایی و «فقط ۲ تا مونده!» جای توضیح
	var near := not done and not claimed and PsychProgress.is_near(progress, target)
	# جایزه‌ی آماده هم نوارِ طلایی می‌گیرد (طلایی = پاداش، V1)
	PsychProgress.emphasize_bar(_bar, near or (done and not claimed))
	if near:
		_desc_label.text = PsychProgress.remaining_text(progress, target)
		_desc_label.visible = true
		_desc_label.add_theme_color_override("font_color", COLOR_GOLD)
		_amount_label.add_theme_color_override("font_color", COLOR_GOLD)

## سه حالت ردیف: در حال انجام / آماده‌ی دریافت / گرفته‌شده
## V5: فقط «دریافت» طلایی و زنده است؛ «رفتن» تیره و آرام (فرعی)؛ گرفته‌شده
## تیک می‌خورد و کم‌رنگ می‌شود. رنگ همیشه با شکل همراه است (V2: قاب/تیک).
func _apply_state(done: bool, claimed: bool) -> void:
	_done = done and not claimed
	_stop_ready_pulse()

	_action_button.disabled = claimed
	if claimed:
		_action_button.text = "✓ گرفته شد"
		_set_button_style(_style_off, _style_off)
	elif done:
		_action_button.text = "دریافت"
		_set_button_style(_style_claim, _style_claim_pressed)
		# متن روی طلایی باید تیره باشد وگرنه خوانده نمی‌شود
		_action_button.add_theme_color_override("font_color", Color(0.2, 0.12, 0.0, 1.0))
		_action_button.add_theme_color_override("font_pressed_color", Color(0.2, 0.12, 0.0, 1.0))
	else:
		_action_button.text = "رفتن"
		_set_button_style(_style_go, _style_go_pressed)
		_action_button.add_theme_color_override("font_color", COLOR_TEXT)
		_action_button.add_theme_color_override("font_pressed_color", COLOR_TEXT)

	_done_frame.visible = done and not claimed
	if _done_frame.visible:
		_done_frame.add_theme_stylebox_override("panel", _style_ready_frame)
	(get_node("Margin/Row/IconSlot") as PanelContainer).add_theme_stylebox_override(
		"panel", _style_icon_ready if _done else _style_icon)
	add_theme_stylebox_override("panel", _style_row_ready if _done else _style_row)

	if claimed:
		_title_label.add_theme_color_override("font_color", COLOR_DIM)
		_desc_label.add_theme_color_override("font_color", COLOR_DIM)
		_amount_label.add_theme_color_override("font_color", COLOR_DIM)
		_icon.modulate = MissionArt.COLOR_CLAIMED
		# ماموریتِ تمام‌شده عمداً کم‌رنگ است تا بقیه توی چشم باشند
		modulate = Color(1, 1, 1, 0.55)
		return

	modulate = Color(1, 1, 1, 1)
	_icon.modulate = MissionArt.COLOR_READY if done else MissionArt.COLOR_ACTIVE
	_title_label.add_theme_color_override("font_color", COLOR_GOLD if done else COLOR_TEXT)
	_desc_label.add_theme_color_override("font_color", COLOR_MUTED)
	_amount_label.add_theme_color_override("font_color", COLOR_GOLD if done else COLOR_MUTED)
	if _done:
		_start_ready_pulse()

## V5/E2 جایزه‌ی آماده نفس می‌کشد: قاب طلایی کم‌وزیاد و دکمه کمی بزرگ‌تر
## (فقط Tween، بدون شیدر — روی گوشی ضعیف هم سبک است)
var _ready_pulse: Tween = null

func _start_ready_pulse() -> void:
	if not is_inside_tree():
		return
	_action_button.pivot_offset = _action_button.size * 0.5
	_ready_pulse = create_tween().set_loops()
	_ready_pulse.tween_property(_done_frame, "modulate:a", 0.45, 0.7).set_trans(Tween.TRANS_SINE)
	_ready_pulse.parallel().tween_property(_action_button, "scale", Vector2(1.05, 1.05), 0.7) 		.set_trans(Tween.TRANS_SINE)
	_ready_pulse.tween_property(_done_frame, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	_ready_pulse.parallel().tween_property(_action_button, "scale", Vector2.ONE, 0.7) 		.set_trans(Tween.TRANS_SINE)
	if not _action_button.button_down.is_connected(_stop_ready_pulse):
		_action_button.button_down.connect(_stop_ready_pulse, CONNECT_ONE_SHOT)

func _stop_ready_pulse() -> void:
	if _ready_pulse != null and _ready_pulse.is_valid():
		_ready_pulse.kill()
	_ready_pulse = null
	_done_frame.modulate.a = 1.0

func _set_button_style(normal: StyleBox, pressed: StyleBox) -> void:
	_action_button.add_theme_stylebox_override("normal", normal)
	_action_button.add_theme_stylebox_override("hover", normal)
	_action_button.add_theme_stylebox_override("pressed", pressed)
	_action_button.add_theme_stylebox_override("hover_pressed", pressed)
	_action_button.add_theme_stylebox_override("disabled", _style_off)

## استایل‌های مشترک (پالت MenuUI: سیاه/قرمز/طلایی). فقط بار اول چیزی می‌سازد.
static var _style_row: StyleBoxFlat = null
static var _style_row_ready: StyleBoxFlat = null
static var _style_icon: StyleBoxFlat = null
static var _style_icon_ready: StyleBoxFlat = null

static func _build_styles() -> void:
	if _style_go != null:
		return

	# «رفتن» فرعی است: تیره با حاشیه‌ی خاکستری (V5 — یک CTA طلایی در هر ردیف)
	_style_go = _pill(Color(0.14, 0.14, 0.15, 1.0), Color(0.42, 0.42, 0.46, 0.9))
	_style_go_pressed = _pill(Color(0.22, 0.22, 0.24, 1.0), Color(0.6, 0.6, 0.64, 1.0))
	_style_claim = _pill(MenuUI.GOLD, Color(1.0, 0.93, 0.62, 1.0))
	_style_claim.shadow_color = Color(1.0, 0.75, 0.2, 0.45)
	_style_claim.shadow_size = 8
	_style_claim_pressed = _pill(Color(1.0, 0.9, 0.5, 1.0), Color(1, 1, 1, 1))
	_style_off = _pill(Color(0, 0, 0, 0), Color(0.3, 0.3, 0.32, 0.6))

	_style_ready_frame = StyleBoxFlat.new()
	_style_ready_frame.bg_color = Color(0, 0, 0, 0)
	_style_ready_frame.set_border_width_all(2)
	_style_ready_frame.border_color = MenuUI.GOLD
	_style_ready_frame.set_corner_radius_all(10)
	_style_ready_frame.shadow_color = Color(1.0, 0.75, 0.2, 0.3)
	_style_ready_frame.shadow_size = 10

	_style_row = MenuUI.box(MenuUI.CARD_BG, MenuUI.CARD_BORDER, 1, 8)
	_style_row_ready = MenuUI.box(Color(0.13, 0.1, 0.04, 0.95), Color(0, 0, 0, 0), 0, 8)
	_style_icon = MenuUI.box(Color(0.05, 0.05, 0.055, 1.0), Color(0.3, 0.3, 0.33, 1.0), 1, 8)
	_style_icon.set_content_margin_all(7)
	_style_icon_ready = MenuUI.box(Color(0.22, 0.15, 0.03, 1.0), MenuUI.GOLD, 2, 8)
	_style_icon_ready.set_content_margin_all(6)

static func _pill(color: Color, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

## ورود پلکانی ردیف‌ها وقتی صفحه باز می‌شود
func play_pop(delay: float) -> void:
	var target_alpha := modulate.a
	modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(self, "modulate:a", target_alpha, 0.25)
