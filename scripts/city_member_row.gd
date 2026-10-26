class_name CityMemberRow
extends CityTapRow
## یک عضو در لیست «اعضا»ی صفحه‌ی شهر — ستون‌ها مثل سرستون لیست:
##   نام بازیکن (آواتار + نام + نقش) · سطح · کاپ · نقش · وضعیت
##
## ضربه روی ردیف پنجره‌ی کارهای عضو را باز می‌کند (دوستی، ارتقا، اخراج، ...)
## که city.gd بر اساس اختیار بیننده می‌چیند.
##
## دیتا: یک آیتم members از GET /clan
##   {player_id, username, role, avatar_id, level, is_online, trophies,
##    tier_id, tier_name, is_me, is_friend, friend_request_sent, joined_at}

## نسبت عرض ستون‌ها — سرستون city.gd هم از همین استفاده می‌کند
const COLUMN_RATIOS := [2.6, 0.9, 1.0, 1.0, 1.0]
const COLUMN_TITLES := ["نام بازیکن", "سطح", "کاپ", "نقش", "وضعیت"]

const ICON_CUP := preload("res://assets/icons/missions/icon_cup.png")
const PsychSocialCity := preload("res://scripts/psych_social_city.gd")

var player_id := ""
var role := "member"
var _data: Dictionary = {}

func get_data() -> Dictionary:
	return _data

func setup(data: Dictionary) -> void:
	_data = data
	player_id = str(data.get("player_id", ""))
	role = str(data.get("role", "member"))
	var is_me := bool(data.get("is_me", false))
	custom_minimum_size = Vector2(0, 54)
	apply_row_style(role == "leader" or is_me)

	for child in get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	var role_color := CityUI.role_color(role)

	# --- نام بازیکن ---
	var name_col := _column(row, 0)
	name_col.add_theme_constant_override("separation", 8)

	var avatar_frame := PanelContainer.new()
	avatar_frame.custom_minimum_size = Vector2(42, 42)
	avatar_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := CityUI.box(Color(0.02, 0.03, 0.06, 1.0),
		role_color if role != "member" else Color(0.3, 0.42, 0.6, 0.8), 2, 21)
	avatar_frame.add_theme_stylebox_override("panel", frame_style)
	name_col.add_child(avatar_frame)

	var avatar := TextureRect.new()
	avatar.texture = CityUI.avatar_texture(str(data.get("avatar_id", "")))
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_frame.add_child(avatar)

	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_theme_constant_override("separation", -2)
	name_col.add_child(names)

	var name_line := HBoxContainer.new()
	name_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_line.add_theme_constant_override("separation", 5)
	names.add_child(name_line)

	# تاج باید درست کنار اسم بچسبد، پس اسم با «…» کوتاه می‌شود نه با clip
	name_line.add_child(CityUI.label(CityUI.short(str(data.get("username", "—")), 14), 16,
		CityUI.GOLD if role == "leader" else CityUI.TEXT))
	if role == "leader":
		name_line.add_child(CityUI.icon(CityUI.ICON_CROWN, 16, CityUI.GOLD))

	var sub := CityUI.role_label(role)
	if is_me:
		sub += " (تو)"
	# E1 ارتباط: تازه‌واردها دیده شوند تا بقیه خوش‌آمد بگویند (طلایی = ارزش)
	var fresh := PsychSocialCity.is_new_member(data)
	if fresh:
		sub += "  •  تازه‌وارد"
	names.add_child(CityUI.label(sub, 12, CityUI.GOLD if fresh else CityUI.MUTED))

	# --- سطح ---
	var level_col := _column(row, 1)
	level_col.alignment = BoxContainer.ALIGNMENT_CENTER
	level_col.add_child(CityUI.label("Lv.%d" % int(data.get("level", 0)), 16, CityUI.TEXT, true))

	# --- کاپ ---
	var cup_col := _column(row, 2)
	cup_col.alignment = BoxContainer.ALIGNMENT_CENTER
	cup_col.add_theme_constant_override("separation", 4)
	cup_col.add_child(CityUI.icon(ICON_CUP, 18, CityUI.GOLD))
	cup_col.add_child(CityUI.label(CityUI.fa_grouped(int(data.get("trophies", 0))), 16, CityUI.TEXT, true))

	# --- نقش ---
	var role_col := _column(row, 3)
	role_col.alignment = BoxContainer.ALIGNMENT_CENTER
	role_col.add_theme_constant_override("separation", 5)
	role_col.add_child(CityUI.icon(CityUI.role_icon(role), 18, role_color))
	role_col.add_child(CityUI.label(CityUI.role_label(role), 15, role_color))

	# --- وضعیت آنلاین ---
	var online := bool(data.get("is_online", false))
	var status_col := _column(row, 4)
	status_col.alignment = BoxContainer.ALIGNMENT_CENTER
	status_col.add_theme_constant_override("separation", 6)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(9, 9)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot_color := CityUI.GREEN if online else Color(0.45, 0.48, 0.55)
	dot.add_theme_stylebox_override("panel", CityUI.box(dot_color, dot_color, 0, 5))
	status_col.add_child(dot)
	status_col.add_child(CityUI.label("آنلاین" if online else "آفلاین", 15,
		CityUI.GREEN if online else CityUI.MUTED))

func _column(row: HBoxContainer, index: int) -> HBoxContainer:
	var col := HBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = COLUMN_RATIOS[index]
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.custom_minimum_size = Vector2(10, 0)
	row.add_child(col)
	return col
