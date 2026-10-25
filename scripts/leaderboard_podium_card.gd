extends VBoxContainer
## یکی از سه نفر بالای سکوی رتبه‌بندی.
##
## جای هر کارت را خودِ تب تعیین می‌کند (راست‌چین: ۳ چپ، ۱ وسط، ۲ راست)؛
## این اسکریپت فقط ظاهرِ نفر اول/دوم/سوم را از هم جدا می‌کند.
##
## استفاده (اول add_child، بعد setup):
##   var card := preload("res://secense/leaderboard_podium_card.tscn").instantiate()
##   podium.add_child(card)
##   card.setup(entry)

## رنگ قاب هر جایگاه: طلا، نقره، برنز
const PLACE_COLORS := {
	1: Color(0.91, 0.76, 0.29, 1.0),
	2: Color(0.78, 0.78, 0.82, 1.0),
	3: Color(0.78, 0.5, 0.26, 1.0),
}

const COLOR_TEXT := Color(0.96, 0.96, 0.97, 1.0)

## نفر اول بزرگ‌تر و بالاتر از بقیه می‌نشیند
const AVATAR_SIZE_FIRST := Vector2(70, 70)
const AVATAR_SIZE_OTHER := Vector2(54, 54)
const PLATE_HEIGHT_FIRST := 62.0
const PLATE_HEIGHT_OTHER := 44.0
const TOP_OFFSET_OTHER := 30.0

@onready var _top_spacer: Control = $TopSpacer
@onready var _avatar_slot: PanelContainer = $AvatarSlot
@onready var _avatar: TextureRect = $AvatarSlot/Avatar
@onready var _placeholder: Label = $AvatarSlot/Placeholder
@onready var _name_label: Label = $NameLabel
@onready var _tier_label: Label = $TierLabel
@onready var _tier_badge: TextureRect = $TierBadge
@onready var _plate: PanelContainer = $Plate
@onready var _position_label: Label = $Plate/Body/PositionLabel
@onready var _points_label: Label = $Plate/Body/PointsLabel

var player_id: String = ""

## پر کردن کارت از یک آیتم `entries` (سه ردیف اول جدول)
func setup(entry: Dictionary) -> void:
	player_id = str(entry.get("player_id", ""))

	var place := int(entry.get("position", 0))
	var color: Color = PLACE_COLORS.get(place, Color(0.42, 0.42, 0.45, 1.0))

	_name_label.text = str(entry.get("username", "—"))
	_position_label.text = _fa(place)
	_points_label.text = _fa(int(entry.get("points", 0)))

	var tier := str(entry.get("tier_name", ""))
	var division := int(entry.get("division", 0))
	_tier_label.text = "%s • رتبه %s" % [tier, _fa(division)] if division > 0 else tier

	_tier_badge.texture = RankArt.texture_for(str(entry.get("tier_id", "")), tier)
	_tier_badge.visible = _tier_badge.texture != null

	var texture := AvatarPicker.load_avatar_texture(str(entry.get("avatar_id", "")))
	_avatar.texture = texture
	_placeholder.visible = texture == null

	_apply_place(place, color)

func _apply_place(place: int, color: Color) -> void:
	var is_first := place == 1

	_top_spacer.custom_minimum_size = Vector2(0, 0.0 if is_first else TOP_OFFSET_OTHER)
	_avatar_slot.custom_minimum_size = AVATAR_SIZE_FIRST if is_first else AVATAR_SIZE_OTHER
	_plate.custom_minimum_size = Vector2(
		0, PLATE_HEIGHT_FIRST if is_first else PLATE_HEIGHT_OTHER
	)

	_avatar_slot.add_theme_stylebox_override("panel", _framed_style(color, 0.7, 3))
	_plate.add_theme_stylebox_override("panel", _framed_style(color, 0.85, 3))

	_position_label.add_theme_color_override("font_color", color)
	_position_label.add_theme_font_size_override("font_size", 26 if is_first else 21)
	_name_label.add_theme_color_override("font_color", color if is_first else COLOR_TEXT)
	_name_label.add_theme_font_size_override("font_size", 19 if is_first else 16)

## پس‌زمینه‌ی تیره با قاب رنگیِ جایگاه
func _framed_style(color: Color, border_alpha: float, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.12, color.g * 0.1, color.b * 0.06, 0.85)
	style.set_border_width_all(1)
	style.border_color = Color(color.r, color.g, color.b, border_alpha)
	style.set_corner_radius_all(radius)
	return style

## ورود کارت‌ها با کمی تأخیر پلکانی
func play_pop(delay: float) -> void:
	pivot_offset = size * 0.5
	scale = Vector2(0.86, 0.86)
	modulate.a = 0.0

	var t := create_tween()
	t.tween_interval(delay)
	t.set_parallel(true)
	t.tween_property(self, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 1.0, 0.26)

# ------------------------------------------------------------------- کمکی‌ها

## عدد با رقم فارسی و جداکننده‌ی هزارگان (۱۲۳۴۵ → ۱۲٬۳۴۵)
func _fa(value: int) -> String:
	const DIGITS := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
	var digits := str(absi(value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = DIGITS[digits[i].to_int()] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "٬" + out
	return ("-" if value < 0 else "") + out
