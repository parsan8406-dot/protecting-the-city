extends PanelContainer
## یک ستون از «درجه‌های رنک» (صفحه‌ی رنک): برنز → نقره → طلا → پلاتین → الماس → لجندری
##
## هر ستون: نشان رنک + اسم + بازه‌ی کاپ «(۱ - ۱۰۰۰)» با آیکن کاپِ هم‌رنگ رنک +
## یک جمله‌ی کوتاه. رنک فعلی بازیکن قاب آبی درخشان می‌گیرد.
##
## استفاده (اول add_child، بعد setup):
##   var chip := preload("res://secense/rank_tier_chip.tscn").instantiate()
##   row.add_child(chip)
##   chip.setup(tier_dictionary, is_current)
##
## tier_dictionary: {id, name, min, max, sub} — max صفر یعنی سقف ندارد.

const COLOR_TEXT := Color(0.94, 0.96, 1.0, 1.0)
const COLOR_GOLD := Color(0.97, 0.78, 0.3, 1.0)

## رنگ آیکن کاپ کنار بازه‌ی هر رنک
const CUP_TINT := {
	"bronze": Color(0.86, 0.52, 0.32),
	"silver": Color(0.84, 0.87, 0.93),
	"gold": Color(1.0, 0.8, 0.3),
	"platinum": Color(0.45, 0.88, 0.95),
	"diamond": Color(0.45, 0.68, 1.0),
	"legend": Color(1.0, 0.76, 0.28),
}

@onready var _current_frame: Panel = $CurrentFrame
@onready var _badge: TextureRect = $Margin/Body/BadgeSlot/Badge
@onready var _name_label: Label = $Margin/Body/NameLabel
@onready var _cup_icon: TextureRect = $Margin/Body/RangeRow/CupIcon
@onready var _range_label: Label = $Margin/Body/RangeRow/RangeLabel
@onready var _sub_label: Label = $Margin/Body/SubLabel

var tier_id: String = ""

func setup(tier: Dictionary, is_current: bool) -> void:
	tier_id = str(tier.get("id", ""))
	_name_label.text = str(tier.get("name", "—"))
	_sub_label.text = str(tier.get("sub", ""))
	_range_label.text = range_text(int(tier.get("min", 0)), int(tier.get("max", 0)))
	_badge.texture = RankArt.texture_for(tier_id, _name_label.text)
	_cup_icon.modulate = CUP_TINT.get(tier_id, COLOR_TEXT)

	# مثل عکس: اسم لجندری طلایی است، بقیه سفید
	_name_label.add_theme_color_override(
		"font_color", COLOR_GOLD if tier_id == "legend" else COLOR_TEXT
	)
	_current_frame.visible = is_current

## «(۱ - ۱۰۰۰)» یا برای رنک آخر «(۳۴۰۱+)».
## کف برنز روی سرور صفر است ولی مثل بقیه از ۱ نوشته می‌شود.
static func range_text(min_value: int, max_value: int) -> String:
	if max_value <= 0:
		return "(%s+)" % MissionArt.fa_number(min_value)
	return "(%s - %s)" % [MissionArt.fa_number(maxi(min_value, 1)), MissionArt.fa_number(max_value)]

## ورود پلکانی ستون‌ها وقتی صفحه باز می‌شود
func play_pop(delay: float) -> void:
	pivot_offset = size * 0.5
	scale = Vector2(0.88, 0.88)
	modulate.a = 0.0

	var t := create_tween()
	t.tween_interval(delay)
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2.ONE, 0.38) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, 0.24)
