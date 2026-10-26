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

const PSYCH := "res://assets/ui/psych/"
## نشانه‌ی گوشه‌ی نشان: سپر روی رنکِ فعلی، قفل روی رنک‌های دورتر (ساخته در کد)
var _mark: TextureRect = null

## state (اختیاری، از صفحه‌ی رنک):
##   ""        فقط ستون (رفتارِ قدیمی)
##   "passed"  رنکی که از آن رد شده — عادی
##   "current" رنکِ فعلی — قاب آبی + سپرِ طلایی
##   "next"    رنکِ بعدی — C9 «فقط X کاپ مونده!» به‌جای جمله‌ی زیرش
##   "locked"  دورتر — E12 تیزر: نشانِ کم‌رنگ با قفل، ولی اسم و بازه پیداست
## left: کاپِ باقی‌مانده تا رنکِ بعدی (فقط برای "next")
func setup(tier: Dictionary, is_current: bool, state: String = "", left: int = 0, near: bool = false) -> void:
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

	_badge.modulate = Color.WHITE
	_sub_label.remove_theme_color_override("font_color")
	var mark_path := ""
	match state:
		"current":
			mark_path = PSYCH + "result_rank_shield.png"
		"next":
			_sub_label.text = ("فقط %s کاپ مونده!" if near else "%s کاپ تا اینجا") % MissionArt.fa_grouped(left)
			_sub_label.add_theme_color_override("font_color", COLOR_GOLD)
		"locked":
			_badge.modulate = Color(0.42, 0.42, 0.48, 0.75)
			mark_path = PSYCH + "tease_padlock.png"
	_set_mark(mark_path, state == "locked")

func _set_mark(path: String, centered: bool) -> void:
	if path == "" or not ResourceLoader.exists(path):
		if _mark != null:
			_mark.visible = false
		return
	if _mark == null:
		_mark = TextureRect.new()
		_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_badge.get_parent().add_child(_mark)
	_mark.texture = load(path)
	_mark.visible = true
	# قفل وسطِ نشان؛ سپر گوشه‌ی بالا-راست
	if centered:
		_mark.anchor_left = 0.5
		_mark.anchor_right = 0.5
		_mark.anchor_top = 0.5
		_mark.anchor_bottom = 0.5
		_mark.offset_left = -15
		_mark.offset_right = 15
		_mark.offset_top = -12
		_mark.offset_bottom = 18
	else:
		_mark.anchor_left = 0.5
		_mark.anchor_right = 0.5
		_mark.anchor_top = 0.0
		_mark.anchor_bottom = 0.0
		_mark.offset_left = 14
		_mark.offset_right = 40
		_mark.offset_top = -2
		_mark.offset_bottom = 24

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
