extends PanelContainer
## یک ردیف از جدول صفحه‌ی «رتبه بندی» (ranking_screen).
##
## ستون‌ها از چپ به راست (مثل طرح):  رتبه | بازیکن | شهر | امتیاز | مدال
## در تب «شهرها» همین ردیف یک شهر را نشان می‌دهد:
##                                     رتبه | شهر   | رهبر | امتیاز | اعضا
##
## همه‌ی مقادیر همان‌طور که سرور فرستاده نمایش داده می‌شوند — هیچ عددی
## اینجا حساب نمی‌شود (handlers_leaderboard.go).
##
## ردیف و بچه‌هایش mouse_filter = IGNORE دارند تا کشیدن انگشت مستقیم به
## ScrollContainer برسد و جدول روی موبایل با انگشت اسکرول شود.
##
## استفاده (اول add_child، بعد setup):
##   var row := preload("res://secense/ranking_row.tscn").instantiate()
##   list.add_child(row)
##   row.setup_player(entry)   یا   row.setup_city(entry)

const COLOR_TEXT := Color(0.94, 0.96, 1.0, 1.0)
const COLOR_MUTED := Color(0.62, 0.7, 0.82, 1.0)
const COLOR_GOLD := Color(0.97, 0.78, 0.3, 1.0)
const COLOR_SILVER := Color(0.8, 0.86, 0.95, 1.0)
const COLOR_BRONZE := Color(0.88, 0.56, 0.3, 1.0)

## رنگ تاج و قاب سه رتبه‌ی اول
const PLACE_COLORS := {1: COLOR_GOLD, 2: COLOR_SILVER, 3: COLOR_BRONZE}

@onready var _crown: TextureRect = $Margin/Row/PosCell/Crown
@onready var _pos_label: Label = $Margin/Row/PosCell/PosLabel
@onready var _avatar: TextureRect = $Margin/Row/AvatarFrame/Avatar
@onready var _emblem: CityEmblem = $Margin/Row/AvatarFrame/Emblem
@onready var _name_label: Label = $Margin/Row/NameCol/NameRow/NameLabel
@onready var _top_crown: TextureRect = $Margin/Row/NameCol/NameRow/TopCrown
@onready var _me_badge: Control = $Margin/Row/NameCol/NameRow/MeBadge
@onready var _sub_label: Label = $Margin/Row/NameCol/SubLabel
@onready var _city_cell: Control = $Margin/Row/CityCell
@onready var _city_emblem: CityEmblem = $Margin/Row/CityCell/CityEmblem
@onready var _city_label: Label = $Margin/Row/CityCell/CityLabel
@onready var _points_label: Label = $Margin/Row/PointsLabel
@onready var _medal: TextureRect = $Margin/Row/MedalCell/Medal
@onready var _members_label: Label = $Margin/Row/MedalCell/MembersLabel

## رتبه‌ی این ردیف در جدول
var position_in_table := 0

## استایل‌ها بین همه‌ی ردیف‌ها مشترک‌اند — یک بار ساخته می‌شوند
static var _styles: Dictionary = {}
## آواتار جایگزین برای بازیکن‌هایی که آواتارشان پیدا نشد
static var _fallback_avatar: Texture2D = null

## ردیف بازیکن — یک آیتم `entries` در تب‌های «رتبه کلی» و «دوستان»
func setup_player(entry: Dictionary) -> void:
	var pos := int(entry.get("position", 0))
	var is_me := bool(entry.get("is_me", false))
	_apply_place(pos, is_me)

	_avatar.visible = true
	_emblem.visible = false
	_avatar.texture = _avatar_texture(str(entry.get("avatar_id", "")))

	_name_label.text = str(entry.get("username", "—"))
	_sub_label.text = "سطح %s" % MissionArt.fa_number(int(entry.get("level", 1)))

	var clan_name := str(entry.get("clan_name", ""))
	_city_emblem.visible = not clan_name.is_empty()
	_city_emblem.set_icon(str(entry.get("clan_icon", "")))
	_city_label.text = clan_name if not clan_name.is_empty() else "بدون شهر"
	_city_label.add_theme_color_override("font_color", COLOR_TEXT if not clan_name.is_empty() else COLOR_MUTED)

	_points_label.text = MissionArt.fa_grouped(int(entry.get("points", 0)))

	_medal.visible = true
	_members_label.visible = false
	_medal.texture = RankArt.texture_for(str(entry.get("tier_id", "")), str(entry.get("tier_name", "")))

	# بازیکن آفلاین کمی کم‌رنگ‌تر
	modulate.a = 1.0 if bool(entry.get("is_online", false)) or is_me else 0.85

## ردیف شهر — یک آیتم `entries` در تب «شهرها»
func setup_city(entry: Dictionary) -> void:
	var pos := int(entry.get("position", 0))
	var is_mine := bool(entry.get("is_mine", false))
	_apply_place(pos, is_mine)

	_avatar.visible = false
	_emblem.visible = true
	_emblem.set_icon(str(entry.get("icon_path", "")))

	var tag := str(entry.get("tag", ""))
	_name_label.text = str(entry.get("name", "—"))
	_sub_label.text = "[%s]" % tag if not tag.is_empty() else ""

	# ستون «شهر» در این تب رهبر شهر را نشان می‌دهد
	var leader := str(entry.get("leader_name", ""))
	_city_emblem.visible = false
	_city_label.text = leader if not leader.is_empty() else "—"
	_city_label.add_theme_color_override("font_color", COLOR_TEXT)

	_points_label.text = MissionArt.fa_grouped(int(entry.get("points", 0)))

	_medal.visible = false
	_members_label.visible = true
	_members_label.text = "%s/%s" % [
		MissionArt.fa_number(int(entry.get("member_count", 0))),
		MissionArt.fa_number(int(entry.get("max_members", 0))),
	]
	modulate.a = 1.0

## صفحه‌ی باریک (مثلاً تبلت 4:3): ستون شهر جمع می‌شود تا اسم جا شود
func set_compact(compact: bool) -> void:
	_city_cell.visible = not compact

## یک چشمک کوتاه — وقتی به جایگاه خودم پریده‌ایم
func flash() -> void:
	var base := modulate
	var t := create_tween()
	t.tween_property(self, "modulate", Color(1.3, 1.3, 1.5, base.a), 0.16)
	t.tween_property(self, "modulate", base, 0.42)

# ------------------------------------------------------------------ ظاهر

## آواتار بازیکن؛ اگر پیدا نشد (مثلاً avatar_default) اولین آواتار بازی،
## مثل کارت بازیکن در صفحه‌ی رنک — تا جای عکس خالی نماند
static func _avatar_texture(avatar_id: String) -> Texture2D:
	var texture := AvatarPicker.load_avatar_texture(avatar_id)
	if texture != null:
		return texture
	# پوشه‌ی آواتارها فقط یک بار خوانده می‌شود، نه برای هر ردیف
	if _fallback_avatar == null:
		var ids := AvatarPicker.list_avatar_ids()
		if not ids.is_empty():
			_fallback_avatar = AvatarPicker.load_avatar_texture(ids[0])
	return _fallback_avatar

## تاج و رنگ سه رتبه‌ی اول، قاب آبی ردیف خودم
func _apply_place(pos: int, is_me: bool) -> void:
	position_in_table = pos
	_pos_label.text = MissionArt.fa_number(pos) if pos > 0 else "—"

	var place_color: Color = PLACE_COLORS.get(pos, COLOR_TEXT)
	var is_top := PLACE_COLORS.has(pos)
	_crown.visible = is_top
	_crown.modulate = place_color
	_pos_label.add_theme_color_override("font_color", place_color)
	_top_crown.visible = pos == 1
	_me_badge.visible = is_me
	_name_label.add_theme_color_override("font_color", COLOR_GOLD if pos == 1 else COLOR_TEXT)

	var key := "normal"
	if is_top:
		key = "top%d" % pos
	elif is_me:
		key = "me"
	add_theme_stylebox_override("panel", _style(key))

static func _style(key: String) -> StyleBoxFlat:
	if _styles.has(key):
		return _styles[key]
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(6)
	s.corner_detail = 2
	s.set_border_width_all(1)
	match key:
		"top1":
			s.bg_color = Color(0.3, 0.21, 0.05, 0.88)
			s.border_color = COLOR_GOLD
			s.set_border_width_all(2)
			s.shadow_color = Color(0.97, 0.7, 0.2, 0.28)
			s.shadow_size = 6
		"top2":
			s.bg_color = Color(0.07, 0.13, 0.25, 0.92)
			s.border_color = Color(COLOR_SILVER, 0.85)
		"top3":
			s.bg_color = Color(0.2, 0.11, 0.05, 0.88)
			s.border_color = Color(COLOR_BRONZE, 0.85)
		"me":
			s.bg_color = Color(0.05, 0.2, 0.45, 0.92)
			s.border_color = Color(0.3, 0.65, 1.0)
			s.set_border_width_all(2)
			s.shadow_color = Color(0.15, 0.5, 1.0, 0.35)
			s.shadow_size = 6
		_:
			s.bg_color = Color(0.03, 0.06, 0.12, 0.85)
			s.border_color = Color(0.2, 0.32, 0.5, 0.55)
	_styles[key] = s
	return s
