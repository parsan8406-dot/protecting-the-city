extends PanelContainer
## یک ردیف از جدول رتبه‌بندی فصل.
##
## همه‌ی مقادیر همان‌طور که سرور فرستاده نمایش داده می‌شوند — هیچ عددی
## اینجا حساب نمی‌شود (رتبه، امتیاز، کاپ‌ها همه سمت سرور محاسبه شده‌اند).
##
## ردیف عمداً mouse_filter = IGNORE دارد تا کشیدن انگشت مستقیم به
## ScrollContainer برسد و جدول روی موبایل با انگشت اسکرول شود.
##
## استفاده (اول add_child، بعد setup):
##   var row := preload("res://secense/leaderboard_row.tscn").instantiate()
##   list.add_child(row)
##   row.setup(entry)

const COLOR_TEXT := Color(0.96, 0.96, 0.97, 1.0)
const COLOR_GOLD := Color(0.91, 0.76, 0.29, 1.0)
const COLOR_MUTED := Color(0.72, 0.72, 0.75, 1.0)

@onready var _me_frame: Panel = $MeFrame
@onready var _me_badge: PanelContainer = $Margin/Row/Player/MeBadge
@onready var _name_label: Label = $Margin/Row/Player/NameLabel
@onready var _avatar: TextureRect = $Margin/Row/Player/AvatarSlot/Avatar
@onready var _tier_label: Label = $Margin/Row/TierLabel
@onready var _tier_badge: TextureRect = $Margin/Row/TierBadge
@onready var _cups_label: Label = $Margin/Row/CupsLabel
@onready var _xp_label: Label = $Margin/Row/XpLabel
@onready var _points_label: Label = $Margin/Row/PointsLabel
@onready var _position_label: Label = $Margin/Row/PositionLabel

var player_id: String = ""
## رتبه‌ی این ردیف در جدول (تب برای پیدا کردن ردیف استفاده می‌کند)
var position_in_table := 0

## پر کردن ردیف از یک آیتم `entries` در پاسخ /leaderboard
func setup(entry: Dictionary) -> void:
	player_id = str(entry.get("player_id", ""))

	var pos := int(entry.get("position", 0))
	position_in_table = pos
	_position_label.text = _fa(pos)
	_name_label.text = str(entry.get("username", "—"))
	var tier := str(entry.get("tier_name", "—"))
	_tier_label.text = tier
	_tier_badge.texture = RankArt.texture_for(str(entry.get("tier_id", "")), tier)
	_tier_badge.visible = _tier_badge.texture != null
	_cups_label.text = _fa(int(entry.get("cups", 0)))
	_xp_label.text = _fa(int(entry.get("season_xp", 0)))
	_points_label.text = _fa(int(entry.get("points", 0)))

	_avatar.texture = AvatarPicker.load_avatar_texture(str(entry.get("avatar_id", "")))

	# سه نفر اول با اسم طلایی
	var is_top := pos > 0 and pos <= 3
	_name_label.add_theme_color_override("font_color", COLOR_GOLD if is_top else COLOR_TEXT)
	_position_label.add_theme_color_override("font_color", COLOR_GOLD if is_top else COLOR_TEXT)

	# ردیف خودم: قاب قرمز و نشان «شما»
	var is_me := bool(entry.get("is_me", false))
	_me_frame.visible = is_me
	_me_badge.visible = is_me

	# بازیکن آفلاین کمی کم‌رنگ‌تر
	modulate.a = 1.0 if bool(entry.get("is_online", false)) or is_me else 0.82

## یک چشمک کوتاه — وقتی از پنل پاداش‌ها روی این بازه پریده‌ایم
func flash() -> void:
	var base := modulate
	var t := create_tween()
	t.tween_property(self, "modulate", Color(1.35, 1.15, 0.75, base.a), 0.16)
	t.tween_property(self, "modulate", base, 0.42)

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
