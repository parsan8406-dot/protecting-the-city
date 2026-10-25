extends Control
## تب پروفایل — تمام اطلاعات از سرور (GET /profile) خوانده می‌شود.
## تغییر آواتار و نام کاربری از طریق POST /profile/update ذخیره می‌شود.
##
## بخش‌ها:
##   سربرگ    آواتار، نام، آیدی (کپی)، سطح و تجربه، وضعیت حساب (مهمان/محافظت‌شده)
##            و چهار عدد کلیدی: کاپ، درصد برد، K/D، دوستان
##   آمار     فرم ۱۰ مسابقه‌ی اخیر + ۸ آمار تجمعی (از خودِ راندهای بازی)
##   شهر      شهر عضو شده یا «پیدا کردن شهر»
##   رنک      رنک فصل از روی کاپ + بهترین رنک
##   دستاورد  X از Y، چهار تازه‌ترین، «هدف بعدی» و پنجره‌ی همه‌ی دستاوردها
##   سلاح     آخرین سلاحی که در مسابقه دستت بوده (یا سلاح تجهیزشده)

const AVATAR_PICKER_SCENE := preload("res://secense/avatar_picker.tscn")
const RENAME_DIALOG_SCENE := preload("res://secense/rename_dialog.tscn")
## E8 آمار شایستگی از مسابقه‌های اخیر
const PsychSocialMastery := preload("res://scripts/psych_social_mastery.gd")

## صحنه‌ی شهر — از کارت «شهر» این تب هم قابل باز شدن است
const CITY_SCENE_PATH := "res://secense/city.tscn"

## کارت‌های آمار: [کلید در stats، عنوان، متریک آیکن، قالب]
const STAT_CELLS := [
	["playtime_hours", "ساعت بازی", "playtime_seconds", ""],
	["total_matches", "کل بازی‌ها", "total_matches", ""],
	["wins", "بردها", "wins", ""],
	["missions_done", "ماموریت‌ها", "missions_done", ""],
	["assists", "کمک‌ها", "assists", ""],
	["kills", "قربانیان", "kills", ""],
	["grenade_kills", "کشته با نارنجک", "grenade_kills", ""],
	["heals_given", "درمان", "heals_given", ""],
]

const ACHIEVEMENT_SLOTS := 4
const FORM_DOTS := 10

@onready var _http: HTTPRequest = $HTTPRequest

# سربرگ
@onready var _header_panel: PanelContainer = $Columns/MainColumn/HeaderPanel
@onready var _avatar_button: TextureButton = $Columns/MainColumn/HeaderPanel/Margin/Row/AvatarSlot/AvatarButton
@onready var _name_label: Label = $Columns/MainColumn/HeaderPanel/Margin/Row/Info/NameRow/NameLabel
@onready var _rename_button: TextureButton = $Columns/MainColumn/HeaderPanel/Margin/Row/Info/NameRow/RenameButton
@onready var _account_badge: Button = $Columns/MainColumn/HeaderPanel/Margin/Row/Info/NameRow/AccountBadge
@onready var _id_label: Label = $Columns/MainColumn/HeaderPanel/Margin/Row/Info/IdRow/IdLabel
@onready var _copy_id_button: Button = $Columns/MainColumn/HeaderPanel/Margin/Row/Info/IdRow/CopyIdButton
@onready var _level_label: Label = $Columns/MainColumn/HeaderPanel/Margin/Row/Info/LevelRow/LevelLabel
@onready var _xp_bar: ProgressBar = $Columns/MainColumn/HeaderPanel/Margin/Row/Info/LevelRow/XpBar
@onready var _xp_label: Label = $Columns/MainColumn/HeaderPanel/Margin/Row/Info/LevelRow/XpLabel
@onready var _quick_stats: HBoxContainer = $Columns/MainColumn/HeaderPanel/Margin/Row/Info/QuickStats

# کارت آمار
@onready var _stats_panel: PanelContainer = $Columns/MainColumn/StatsPanel
@onready var _form_dots: HBoxContainer = $Columns/MainColumn/StatsPanel/Margin/Body/FormRow/FormDots
@onready var _form_title: Label = $Columns/MainColumn/StatsPanel/Margin/Body/FormRow/FormTitle
@onready var _stats_grid: GridContainer = $Columns/MainColumn/StatsPanel/Margin/Body/Grid

# شهر
@onready var _clan_panel: PanelContainer = $Columns/MainColumn/ClanPanel
@onready var _clan_name: Label = $Columns/MainColumn/ClanPanel/Margin/Row/ClanInfo/ClanNameLabel
@onready var _clan_detail: Label = $Columns/MainColumn/ClanPanel/Margin/Row/ClanInfo/ClanDetailLabel
@onready var _clan_view_button: Button = $Columns/MainColumn/ClanPanel/Margin/Row/ViewButton

# فصل و رتبه
@onready var _season_panel: PanelContainer = $Columns/SideColumn/SeasonPanel
@onready var _tier_label: Label = $Columns/SideColumn/SeasonPanel/Margin/Body/Row/RankInfo/TierLabel
@onready var _best_label: Label = $Columns/SideColumn/SeasonPanel/Margin/Body/Row/RankInfo/BestLabel
@onready var _rank_icon: TextureRect = $Columns/SideColumn/SeasonPanel/Margin/Body/Row/RankIconSlot/RankIcon
@onready var _rank_bar: ProgressBar = $Columns/SideColumn/SeasonPanel/Margin/Body/RankBar
@onready var _points_label: Label = $Columns/SideColumn/SeasonPanel/Margin/Body/PointsLabel

# دستاوردها
@onready var _achievements_panel: PanelContainer = $Columns/SideColumn/AchievementsPanel
@onready var _achievement_count: Label = $Columns/SideColumn/AchievementsPanel/Margin/Body/HeaderRow/CountLabel
@onready var _achievements_all: Button = $Columns/SideColumn/AchievementsPanel/Margin/Body/HeaderRow/AllButton
@onready var _achievement_slots: HBoxContainer = $Columns/SideColumn/AchievementsPanel/Margin/Body/Slots
@onready var _achievements_empty: Label = $Columns/SideColumn/AchievementsPanel/Margin/Body/EmptyLabel
@onready var _next_label: Label = $Columns/SideColumn/AchievementsPanel/Margin/Body/NextLabel
@onready var _next_bar: ProgressBar = $Columns/SideColumn/AchievementsPanel/Margin/Body/NextBar

# سلاح
@onready var _weapon_panel: Control = $Columns/SideColumn/WeaponPanel
@onready var _weapon_texture: TextureRect = $Columns/SideColumn/WeaponPanel/WeaponTexture
@onready var _weapon_name: Label = $Columns/SideColumn/WeaponPanel/WeaponNameLabel
@onready var _weapon_sub: Label = $Columns/SideColumn/WeaponPanel/WeaponSubLabel
@onready var _weapon_title: Label = $Columns/SideColumn/WeaponPanel/Title

var _update_http: HTTPRequest
var _profile: Dictionary = {}
var _rename_dialog: Control = null
var _pending_username: String = ""
## مقدار عددی هر کارت (برای شمارش انیمیشنی)؛ کلید → Label
var _stat_values: Dictionary = {}
var _quick_values: Dictionary = {}
var _error_banner: Button = null
var _intro_played := false
## E8/E1 خط «شایستگی» زیر فرم اخیر (برد پشت‌سرهم، رکورد کیل)
var _mastery_label: Label = null

# ------------------------------------------------------------------ آماده‌سازی

func _ready() -> void:
	_http.request_completed.connect(_on_profile_received)

	_update_http = HTTPRequest.new()
	_update_http.timeout = 12.0
	add_child(_update_http)
	_update_http.request_completed.connect(_on_update_completed)

	_build_quick_stats()
	_build_stat_grid()
	_build_form_dots([])
	_build_mastery_label()
	_build_error_banner()

	for pair in [[_copy_id_button, "dark"], [_achievements_all, "dark"], [_clan_view_button, "gold"]]:
		MenuUI.style_button(pair[0], pair[1])
		UIFx.bind_press_feedback(pair[0])

	_avatar_button.pressed.connect(_on_avatar_pressed)
	_rename_button.pressed.connect(_on_rename_pressed)
	_clan_view_button.pressed.connect(_on_clan_view_pressed)
	_copy_id_button.pressed.connect(_on_copy_id_pressed)
	_achievements_all.pressed.connect(_on_all_achievements_pressed)
	_account_badge.pressed.connect(_on_account_badge_pressed)

	Global.account_switched.connect(refresh)
	Global.social_event.connect(func(kind: String) -> void:
		if kind == "achievement":
			refresh())
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree():
			refresh())

	# تا جواب سرور برسد، دیتای کش‌شده‌ی Global را نشان بده تا صفحه خالی نباشد
	_apply_avatar(Global.avatar_id)
	_name_label.text = str(Global.my_username)
	_apply_id(str(Global.player_id))
	_apply_account_badge()
	_apply_weapon(str(Global.current_weapon), false)

	refresh()

## گرفتن دوباره‌ی پروفایل از سرور
func refresh() -> void:
	var username: String = str(Global.my_username)
	if username.is_empty():
		return
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var url := "%s/profile?username=%s" % [Global.SERVER_BASE, username.uri_encode()]
	if _http.request(url, Global.auth_headers()) != OK:
		_show_error("اتصال به سرور برقرار نشد")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and is_inside_tree() and is_visible_in_tree():
		refresh()

func _on_profile_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_show_error(MenuUI.server_error(body, response_code if result == HTTPRequest.RESULT_SUCCESS else 0,
			"پروفایل از سرور نیامد"))
		return
	var data := MenuUI.parse_json(body)
	if data.is_empty():
		_show_error("پاسخ پروفایل قابل خواندن نبود")
		return
	_error_banner.visible = false
	_profile = data
	_apply_profile(_profile)

# ------------------------------------------------------------------ ساخت بخش‌های تکراری

func _build_quick_stats() -> void:
	for child in _quick_stats.get_children():
		child.queue_free()
	for spec in [["trophies", "کاپ"], ["win_rate", "درصد برد"], ["kd", "نسبت K/D"], ["friends", "دوستان"]]:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 0)
		var value := MenuUI.label("—", 21, MenuUI.TEXT, true)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var title := MenuUI.label(spec[1], 12, Color(0.6, 0.6, 0.63))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(value)
		box.add_child(title)
		_quick_stats.add_child(box)
		_quick_values[spec[0]] = value

func _build_stat_grid() -> void:
	for child in _stats_grid.get_children():
		child.queue_free()
	for spec in STAT_CELLS:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 1)
		var icon := MenuUI.icon(MenuUI.metric_icon(spec[2]), 30, Color(0.62, 0.62, 0.64))
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(icon)
		var value := MenuUI.label("۰", 20, MenuUI.TEXT, true)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(value)
		var title := MenuUI.label(spec[1], 12, Color(0.55, 0.55, 0.58))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(title)
		_stats_grid.add_child(cell)
		_stat_values[spec[0]] = value

## فرم ۱۰ مسابقه‌ی اخیر: سبز برد، قرمز باخت، خاکستری مساوی (جدیدترین سمت راست)
func _build_form_dots(recent: Array) -> void:
	for child in _form_dots.get_children():
		child.queue_free()
	var wins := 0
	for i in FORM_DOTS:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(20, 20)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var color := Color(0.22, 0.22, 0.24, 1.0)
		var index := FORM_DOTS - 1 - i
		if index < recent.size() and recent[index] is Dictionary:
			var m: Dictionary = recent[index]
			if bool(m.get("draw", false)):
				color = Color(0.6, 0.6, 0.64, 1.0)
			elif bool(m.get("won", false)):
				color = MenuUI.GREEN
				wins += 1
			else:
				color = MenuUI.RED_HOT
		dot.add_theme_stylebox_override("panel", MenuUI.box(color, Color(0, 0, 0, 0.4), 1, 10))
		_form_dots.add_child(dot)
	if recent.is_empty():
		_form_title.text = "فرم اخیر — هنوز مسابقه‌ای نیست"
	else:
		_form_title.text = "فرم اخیر  %s برد از %s" % [MenuUI.fa(wins), MenuUI.fa(mini(recent.size(), FORM_DOTS))]

func _build_mastery_label() -> void:
	_mastery_label = MenuUI.label("", 14, MenuUI.GOLD)
	_mastery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mastery_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_mastery_label.clip_text = true
	_mastery_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mastery_label.visible = false
	var body := _form_dots.get_parent().get_parent()
	body.add_child(_mastery_label)
	body.move_child(_mastery_label, _form_dots.get_parent().get_index() + 1)

func _build_error_banner() -> void:
	_error_banner = MenuUI.button("", "red", 16)
	_error_banner.visible = false
	_error_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_error_banner.position = Vector2(-220, 10)
	_error_banner.custom_minimum_size = Vector2(440, 48)
	_error_banner.pressed.connect(func() -> void:
		_error_banner.visible = false
		refresh())
	add_child(_error_banner)

func _show_error(message: String) -> void:
	_error_banner.text = message + " — تلاش دوباره"
	_error_banner.visible = true
	_error_banner.position = Vector2((size.x - _error_banner.custom_minimum_size.x) * 0.5, 10)

# ------------------------------------------------------------------ پر کردن UI

func _apply_profile(data: Dictionary) -> void:
	# --- هویت ---
	var username := str(data.get("username", Global.my_username))
	_name_label.text = username
	_apply_avatar(str(data.get("avatar_id", "")))
	_apply_id(str(data.get("player_id", Global.player_id)))
	if data.has("google_linked"):
		Global.google_linked = bool(data["google_linked"])
	_apply_account_badge()

	var level := int(data.get("level", 1))
	_level_label.text = "سطح %s" % MenuUI.fa(level)
	var into := int(data.get("display_xp", 0))
	var need := maxi(1, int(data.get("max_xp", level * 100)))
	_xp_bar.max_value = float(need)
	_tween_bar(_xp_bar, float(into))
	_xp_label.text = "%s / %s" % [MenuUI.fa_grouped(into), MenuUI.fa_grouped(need)]

	# --- آمار ---
	var stats: Dictionary = data.get("stats", {}) if data.get("stats") is Dictionary else {}
	_set_number(_quick_values["trophies"], int(data.get("trophies", 0)))
	_quick_values["win_rate"].text = "%s٪" % MenuUI.fa(int(stats.get("win_rate", 0)))
	_quick_values["kd"].text = MenuUI.kd_text(float(stats.get("kd_ratio", 0.0)))
	_set_number(_quick_values["friends"], int(data.get("friend_count", 0)))

	for spec in STAT_CELLS:
		_set_number(_stat_values[spec[0]], int(stats.get(spec[0], 0)))

	var recent = data.get("recent_matches", [])
	_build_form_dots(recent if recent is Array else [])
	var mastery := PsychSocialMastery.from_recent(recent if recent is Array else [])
	_mastery_label.text = PsychSocialMastery.mastery_line(mastery)
	_mastery_label.visible = not _mastery_label.text.is_empty()

	# --- رنک فصل (از روی کاپ) ---
	var rank: Dictionary = data.get("rank", {}) if data.get("rank") is Dictionary else {}
	var tier_name := str(rank.get("tier_name", "—"))
	_tier_label.text = tier_name
	var badge := RankArt.texture_for(str(rank.get("tier_id", "")), tier_name)
	if badge != null:
		_rank_icon.texture = badge
		_rank_icon.modulate = Color.WHITE
	_best_label.text = "بهترین رنک : %s" % str(data.get("best_tier_name", tier_name))
	var points := int(rank.get("points", data.get("trophies", 0)))
	var points_max := int(rank.get("points_max", 0))
	_rank_bar.max_value = maxf(1.0, float(points_max))
	_tween_bar(_rank_bar, float(points))
	if points_max > points:
		_points_label.text = "%s / %s کاپ — %s کاپ تا رنک بعد" % [
			MenuUI.fa_grouped(points), MenuUI.fa_grouped(points_max), MenuUI.fa_grouped(points_max - points + 1)]
	else:
		_points_label.text = "%s کاپ — بالاترین رنک" % MenuUI.fa_grouped(points)

	# --- دستاوردها ---
	_apply_achievements(data)

	# --- شهر ---
	_apply_clan(data.get("clan", null))

	# --- آخرین سلاح (سرور خودش به سلاح تجهیزشده برمی‌گردد اگر هنوز مسابقه‌ای نبوده) ---
	var last_weapon := str(stats.get("last_used_weapon", ""))
	var from_match := int(stats.get("total_matches", 0)) > 0 or (recent is Array and not (recent as Array).is_empty())
	if last_weapon.is_empty():
		last_weapon = str(data.get("equipped_weapon", Global.current_weapon))
	_apply_weapon(last_weapon, from_match)
	# E8 مالکیت: سلاحی که در مسابقه‌های اخیر بیشتر از همه دستش بوده + کیل‌هایش
	if int(mastery.fav_matches) >= 2:
		_apply_weapon(str(mastery.fav_weapon), true)
		_weapon_title.text = "سلاح محبوب تو"
		_weapon_sub.text = "%s کیل در %s مسابقه‌ی اخیر" % [
			MenuUI.fa_grouped(int(mastery.fav_kills)), MenuUI.fa(int(mastery.fav_matches))]
	else:
		_weapon_title.text = "آخرین سلاح مورد استفاده"

	if not _intro_played:
		_intro_played = true
		_play_intro()

func _apply_id(pid: String) -> void:
	_id_label.text = "ID : %s" % (pid if not pid.is_empty() else "—")
	_copy_id_button.disabled = pid.is_empty()

## نشان وضعیت حساب کنار اسم — مهمان‌ها با یک ضربه به تنظیمات می‌روند
func _apply_account_badge() -> void:
	if Global.google_linked:
		_account_badge.text = "حساب محافظت‌شده"
		MenuUI.style_button(_account_badge, "gold")
	else:
		_account_badge.text = "مهمان — اتصال به گوگل"
		MenuUI.style_button(_account_badge, "red")

## عدد با شمارش کوتاه (از عدد قبلی تا عدد تازه)
func _set_number(label: Label, value: int) -> void:
	var from := int(label.get_meta("value", 0))
	label.set_meta("value", value)
	if from == value or not is_visible_in_tree():
		label.text = MenuUI.fa_grouped(value)
		return
	var t := create_tween()
	t.tween_method(func(v: float) -> void: label.text = MenuUI.fa_grouped(int(round(v))),
		float(from), float(value), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _tween_bar(bar: ProgressBar, value: float) -> void:
	create_tween().tween_property(bar, "value", value, 0.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _apply_avatar(avatar_id: String) -> void:
	_avatar_button.texture_normal = MenuUI.avatar_texture(avatar_id)

func _apply_achievements(data: Dictionary) -> void:
	var unlocked := int(data.get("achievements_unlocked", 0))
	var total := int(data.get("achievements_total", 0))
	_achievement_count.text = "%s / %s" % [MenuUI.fa(unlocked), MenuUI.fa(total)]
	_achievements_all.disabled = total == 0

	var recent = data.get("achievements", [])
	var items: Array = recent if recent is Array else []
	for child in _achievement_slots.get_children():
		child.queue_free()
	_achievements_empty.visible = items.is_empty()
	_achievement_slots.visible = not items.is_empty()
	for i in mini(items.size(), ACHIEVEMENT_SLOTS):
		if items[i] is Dictionary:
			_achievement_slots.add_child(_achievement_slot(items[i]))

	var next = data.get("next_achievement", null)
	if next is Dictionary:
		var n: Dictionary = next
		var target := maxi(1, int(n.get("target", 1)))
		var progress := int(n.get("progress", 0))
		var is_time := str(n.get("metric", "")) == "playtime_seconds"
		_next_label.text = "هدف بعدی : %s  (%s / %s%s)" % [str(n.get("name", "")),
			MenuUI.fa_grouped(int(progress / 3600.0) if is_time else progress),
			MenuUI.fa_grouped(int(target / 3600.0) if is_time else target), " ساعت" if is_time else ""]
		_next_bar.max_value = float(target)
		_tween_bar(_next_bar, float(progress))
		_next_label.visible = true
		_next_bar.visible = true
	elif total > 0:
		_next_label.text = "همه‌ی دستاوردها را باز کرده‌ای!"
		_next_bar.visible = false
	else:
		_next_label.visible = false
		_next_bar.visible = false

func _achievement_slot(item: Dictionary) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size = Vector2(0, 76)
	col.add_theme_constant_override("separation", 2)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(0, 48)
	box.add_theme_stylebox_override("panel", MenuUI.box(Color(0.15, 0.11, 0.03, 0.95), MenuUI.GOLD_DEEP, 1, 6))
	box.add_child(MenuUI.icon(MenuUI.metric_icon(str(item.get("metric", ""))), 32, MenuUI.GOLD))
	col.add_child(box)
	var name_label := MenuUI.label(str(item.get("name", "—")), 12, MenuUI.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	col.add_child(name_label)
	return col

func _apply_clan(clan: Variant) -> void:
	if clan is Dictionary and not (clan as Dictionary).is_empty():
		var c: Dictionary = clan
		_clan_name.text = str(c.get("name", "—"))
		var role := str(c.get("role", ""))
		var role_text := {"leader": "رهبر", "officer": "معاون"}.get(role, "عضو") as String
		_clan_detail.text = "سطح %s  •  اعضا %s/%s  •  %s" % [MenuUI.fa(int(c.get("level", 0))),
			MenuUI.fa(int(c.get("member_count", 0))), MenuUI.fa(int(c.get("max_members", 0))), role_text]
		_clan_view_button.text = "مشاهده"
		MenuUI.style_button(_clan_view_button, "dark")
	else:
		_clan_name.text = "عضو هیچ شهری نیستی"
		_clan_detail.text = "با عضویت در یک شهر، در چت شهر و جدول شهرها شرکت کن"
		_clan_view_button.text = "پیدا کردن شهر"
		MenuUI.style_button(_clan_view_button, "gold")

func _apply_weapon(weapon_id: String, from_match: bool) -> void:
	if weapon_id.is_empty():
		_weapon_texture.texture = null
		_weapon_name.text = ""
		_weapon_sub.text = ""
		return
	_weapon_texture.texture = MenuUI.weapon_texture(weapon_id)
	_weapon_name.text = MenuUI.weapon_name(weapon_id)
	_weapon_sub.text = "در آخرین مسابقه" if from_match else "سلاح تجهیزشده"

# ------------------------------------------------------------------ انیمیشن ورود

func _play_intro() -> void:
	var cards: Array[Control] = [_header_panel, _stats_panel, _clan_panel, _season_panel,
		_achievements_panel, _weapon_panel]
	for i in cards.size():
		var card := cards[i]
		card.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(0.05 * i)
		t.tween_property(card, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE)

# ------------------------------------------------------------------ باکس‌ها

func _on_avatar_pressed() -> void:
	UIFx.press(_avatar_button)
	var picker := AVATAR_PICKER_SCENE.instantiate()
	picker.add_to_group("modal")
	add_child(picker)
	picker.avatar_selected.connect(_on_avatar_selected)
	picker.open(str(_profile.get("avatar_id", Global.avatar_id)))

func _on_avatar_selected(avatar_id: String) -> void:
	Global.avatar_id = avatar_id
	_apply_avatar(avatar_id)
	# بدون منتظر ماندنِ جوابِ سرور، تاپ‌بار (و هر جای دیگری که به این سیگنال
	# گوش می‌دهد) همان لحظه عکس جدید را نشان می‌دهد
	Global.player_data_updated.emit()
	_send_update({"avatar_id": avatar_id})

func _on_rename_pressed() -> void:
	UIFx.press(_rename_button)
	_rename_dialog = RENAME_DIALOG_SCENE.instantiate()
	_rename_dialog.add_to_group("modal")
	add_child(_rename_dialog)
	_rename_dialog.name_confirmed.connect(_on_name_confirmed)
	_rename_dialog.open(str(_profile.get("username", Global.my_username)))

func _on_name_confirmed(new_name: String) -> void:
	_pending_username = new_name.strip_edges()
	_send_update({"new_username": _pending_username})

func _on_copy_id_pressed() -> void:
	UIFx.press(_copy_id_button)
	var pid := str(_profile.get("player_id", Global.player_id))
	if pid.is_empty():
		return
	DisplayServer.clipboard_set(pid)
	_copy_id_button.text = "کپی شد ✓"
	get_tree().create_timer(1.6).timeout.connect(func() -> void:
		if is_instance_valid(_copy_id_button):
			_copy_id_button.text = "کپی آیدی")

func _on_all_achievements_pressed() -> void:
	UIFx.press(_achievements_all)
	var catalog = _profile.get("achievement_catalog", [])
	AchievementsDialog.open(self, catalog if catalog is Array else [])

func _on_account_badge_pressed() -> void:
	UIFx.tap(_account_badge, func() -> void: Global.request_profile_tab("settings"))

## هر دو حالت دکمه («مشاهده» و «پیدا کردن شهر») به یک جا می‌روند —
## خودِ صحنه‌ی شهر تشخیص می‌دهد باید لیست شهرها را نشان دهد یا شهر بازیکن را.
func _on_clan_view_pressed() -> void:
	UIFx.press(_clan_view_button, func() -> void:
		get_tree().change_scene_to_file(CITY_SCENE_PATH))

# ------------------------------------------------------------------ ذخیره روی سرور

func _send_update(fields: Dictionary) -> void:
	var payload := fields.duplicate()
	payload["username"] = Global.my_username
	var err := _update_http.request(Global.SERVER_BASE + "/profile/update", Global.json_headers(),
		HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		_pending_username = ""
		if is_instance_valid(_rename_dialog) and _rename_dialog.visible:
			_rename_dialog.show_error("اتصال به سرور برقرار نشد")

func _on_update_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var message := MenuUI.server_error(body, response_code if result == HTTPRequest.RESULT_SUCCESS else 0,
			"تغییرات ذخیره نشد")
		_pending_username = ""
		# اگر باکس تغییر نام باز است، خطا را همان‌جا نشان بده
		if is_instance_valid(_rename_dialog) and _rename_dialog.visible:
			_rename_dialog.show_error(message)
		else:
			_show_error(message)
		return

	# موفق: نام تازه روی دستگاه هم ذخیره می‌شود (قبلاً فقط در حافظه عوض می‌شد
	# و اجرای بعدی با اسم قدیمی یک حساب خالیِ تازه می‌ساخت)
	if not _pending_username.is_empty():
		var confirmed := str(MenuUI.parse_json(body).get("username", _pending_username))
		Global.apply_rename(confirmed)
		_name_label.text = confirmed
		_pending_username = ""
		LocalSettings.vibrate(25)

	if is_instance_valid(_rename_dialog):
		_rename_dialog.close()
		_rename_dialog = null

	Global.refresh_player_data()
	refresh()
