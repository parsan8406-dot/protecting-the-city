extends HBoxContainer
## یک ردیف در «چالش های ویژه فصل».
##
## نسخه‌ی جمع‌وجورِ mission_row است — چالش فصل همان شکل دیتا را دارد
## (title / desc / icon / target / progress / done / claimed / xp / coins) ولی
## در پایین صفحه‌ی پاداش فصل جا می‌شود، پس آیکنش کوچک‌تر و توضیحش حذف است.
##
## مثل بقیه‌ی صفحه هیچ عددی اینجا حساب نمی‌شود: دکمه فقط سیگنال می‌دهد و
## واریز جایزه با POST /season/challenges/claim سمت سرور انجام می‌شود.
##
## استفاده (اول add_child، بعد setup):
##   var row := preload("res://secense/season_challenge_row.tscn").instantiate()
##   list.add_child(row)
##   row.setup(challenge)

## بازیکن روی دکمه زد. اگر چالش تمام شده باشد یعنی «دریافت»، وگرنه «رفتن».
signal claim_requested(challenge_id: String)
signal play_requested()

const COLOR_GOLD := MissionArt.COLOR_GOLD
const COLOR_TEXT := MissionArt.COLOR_TEXT
const COLOR_MUTED := MissionArt.COLOR_MUTED
const COLOR_DIM := MissionArt.COLOR_DIM
const PsychProgress := preload("res://scripts/psych_results_progress.gd")

@onready var _button: Button = $ActionButton
@onready var _coins_label: Label = $Reward/Value
@onready var _coin_icon: TextureRect = $Reward/Icon
@onready var _amount_label: Label = $AmountLabel
@onready var _title_label: Label = $Info/TitleLabel
@onready var _bar: ProgressBar = $Info/Bar
@onready var _icon: TextureRect = $Icon

var challenge_id: String = ""

var _challenge: Dictionary = {}
var _built := false

func _ready() -> void:
	_button.pressed.connect(func() -> void:
		UIFx.tap(_button)
		# چالشِ تمام‌شده جایزه می‌دهد؛ ناتمام بازیکن را می‌فرستد بازی کند
		if bool(_challenge.get("done", false)) and not bool(_challenge.get("claimed", false)):
			claim_requested.emit(challenge_id)
		else:
			play_requested.emit())
	UIFx.bind_press_feedback(_button)

	if not _challenge.is_empty():
		_apply(_challenge)
	_built = true

## پر کردن ردیف از یک آیتم `challenges` در پاسخ /season/pass
func setup(challenge: Dictionary) -> void:
	_challenge = challenge
	challenge_id = str(challenge.get("challenge_id", ""))
	if is_node_ready() or _built:
		_apply(challenge)

func _apply(challenge: Dictionary) -> void:
	var target := maxi(int(challenge.get("target", 1)), 1)
	var progress := clampi(int(challenge.get("progress", 0)), 0, target)
	var done := bool(challenge.get("done", false))
	var claimed := bool(challenge.get("claimed", false))

	_title_label.text = str(challenge.get("title", "—"))
	_icon.texture = MissionArt.texture_for(str(challenge.get("icon", "")))
	_coins_label.text = MissionArt.fa_grouped(int(challenge.get("coins", 0)))

	_bar.max_value = float(target)
	_bar.value = 0.0
	# C9 پیشرفتِ اهدایی: نوارِ ناتمام هیچ‌وقت کاملاً خالی دیده نمی‌شود
	var shown := float(target) if done else PsychProgress.bar_value(_bar, progress, target)
	create_tween().tween_property(_bar, "value", shown, 0.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_amount_label.text = "%s/%s" % [
		MissionArt.fa_number(progress), MissionArt.fa_number(target)
	]

	_apply_state(done, claimed)

	# C9 نزدیکِ پایان: نوار و عدد طلایی (فضای ردیف برای جمله‌ی کامل کم است)
	var near := not done and not claimed and PsychProgress.is_near(progress, target)
	PsychProgress.emphasize_bar(_bar, near)
	if near:
		_amount_label.add_theme_color_override("font_color", COLOR_GOLD)

## سه حالت: در حال انجام / آماده‌ی دریافت / گرفته‌شده
func _apply_state(done: bool, claimed: bool) -> void:
	_button.disabled = claimed
	if claimed:
		_button.text = "گرفته شد"
	elif done:
		_button.text = "دریافت"
	else:
		_button.text = "رفتن"

	if claimed:
		_title_label.add_theme_color_override("font_color", COLOR_DIM)
		_amount_label.add_theme_color_override("font_color", COLOR_DIM)
		_coins_label.add_theme_color_override("font_color", COLOR_DIM)
		_icon.modulate = COLOR_DIM
		_coin_icon.modulate = Color(1, 1, 1, 0.45)
		modulate = Color(1, 1, 1, 0.6)
		return

	modulate = Color(1, 1, 1, 1)
	_coin_icon.modulate = Color.WHITE
	_icon.modulate = MissionArt.COLOR_READY if done else MissionArt.COLOR_ACTIVE
	_title_label.add_theme_color_override("font_color", COLOR_GOLD if done else COLOR_TEXT)
	_coins_label.add_theme_color_override("font_color", COLOR_GOLD)
	_amount_label.add_theme_color_override("font_color", COLOR_GOLD if done else COLOR_MUTED)

## ورود پلکانی ردیف‌ها
func play_pop(delay: float) -> void:
	var target_alpha := modulate.a
	modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(self, "modulate:a", target_alpha, 0.25)
