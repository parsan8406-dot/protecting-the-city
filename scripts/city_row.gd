class_name CityRow
extends CityTapRow
## یک شهر در لیست «شهرها» (حالت بدون شهر). ضربه روی ردیف صفحه‌ی همان
## شهر را باز می‌کند که دکمه‌ی عضویت آنجاست.
##
## دیتا: یک آیتم لیست GET /clans
##   {clan_id, name, tag, description, icon_path, level, member_count,
##    max_members, is_public, min_level, is_full}
##
## استفاده:
##   var row := CityRow.new()
##   list.add_child(row)
##   row.setup(item, position, request_pending)

const ICON_MEMBERS := preload("res://assets/ui/profile_menu/icon_friends.svg")
const ICON_LOCK := preload("res://assets/icons/missions/icon_lock.svg")

var clan_id := ""
var _data: Dictionary = {}

func get_data() -> Dictionary:
	return _data

## `position_in_list` جایگاه در رتبه‌بندی (۱ = بهترین)
## `suggested` = C2 پیشنهادِ هوشمندِ city.gd (شلوغ‌ترین شهری که الان می‌شود مستقیم عضوش شد)
func setup(data: Dictionary, position_in_list: int, request_pending: bool, suggested: bool = false) -> void:
	_data = data
	clan_id = str(data.get("clan_id", ""))
	custom_minimum_size = Vector2(0, 68)
	apply_row_style(suggested)

	for child in get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	# جایگاه — سه تای اول طلایی
	var rank := CityUI.label("#%s" % CityUI.fa(position_in_list), 18,
		CityUI.GOLD if position_in_list <= 3 else CityUI.MUTED, true)
	rank.custom_minimum_size = Vector2(40, 0)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(rank)

	var emblem := CityEmblem.new()
	emblem.custom_minimum_size = Vector2(54, 54)
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	emblem.set_icon(str(data.get("icon_path", "")))
	row.add_child(emblem)

	# نام، تگ و شعار
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)

	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_theme_constant_override("separation", 8)
	info.add_child(name_row)

	name_row.add_child(CityUI.label(CityUI.short(str(data.get("name", "—")), 18), 18, CityUI.TEXT))

	var tag := str(data.get("tag", ""))
	if not tag.is_empty():
		name_row.add_child(CityUI.label("[%s]" % tag, 15, CityUI.MUTED, true))
	if suggested:
		# V5 یک برچسبِ طلایی، فقط روی یک ردیف
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var st := CityUI.box(Color(0.32, 0.22, 0.03, 0.95), CityUI.GOLD, 1, 10)
		st.content_margin_left = 8
		st.content_margin_right = 8
		chip.add_theme_stylebox_override("panel", st)
		chip.add_child(CityUI.label("پیشنهاد برای تو", 12, CityUI.GOLD))
		name_row.add_child(chip)

	var desc := str(data.get("description", "")).strip_edges()
	var desc_label := CityUI.label(desc if not desc.is_empty() else "بدون شعار",
		13, CityUI.MUTED if not desc.is_empty() else CityUI.MUTED.darkened(0.35))
	desc_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc_label.clip_text = true
	desc_label.custom_minimum_size = Vector2(60, 0)
	info.add_child(desc_label)

	# سطح و اعضا
	var stats := VBoxContainer.new()
	stats.custom_minimum_size = Vector2(86, 0)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_theme_constant_override("separation", 0)
	row.add_child(stats)

	var level := CityUI.label("سطح %s" % CityUI.fa(int(data.get("level", 1))), 15, CityUI.TEXT, true)
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_child(level)

	var members := HBoxContainer.new()
	members.alignment = BoxContainer.ALIGNMENT_CENTER
	members.mouse_filter = Control.MOUSE_FILTER_IGNORE
	members.add_theme_constant_override("separation", 4)
	stats.add_child(members)
	members.add_child(CityUI.icon(ICON_MEMBERS, 16, CityUI.MUTED))
	var count := int(data.get("member_count", 0))
	var capacity := int(data.get("max_members", 0))
	members.add_child(CityUI.label("%s/%s" % [CityUI.fa(count), CityUI.fa(capacity)], 14,
		CityUI.RED if bool(data.get("is_full", false)) else CityUI.MUTED, true))

	# وضعیت عضویت: عمومی / خصوصی / پر / درخواست داده‌ای
	var status_box := HBoxContainer.new()
	status_box.custom_minimum_size = Vector2(92, 0)
	status_box.alignment = BoxContainer.ALIGNMENT_CENTER
	status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_box.add_theme_constant_override("separation", 4)
	row.add_child(status_box)

	var is_public := bool(data.get("is_public", true))
	var status_text := "عمومی"
	var status_color := CityUI.GREEN
	# C8/C11 شرطِ ورود همین‌جا روشن است: سطحِ لازم اگر از سطحِ من بیشتر است
	var need := int(data.get("min_level", 0))
	if request_pending:
		status_text = "در انتظار"
		status_color = CityUI.BLUE
	elif bool(data.get("is_full", false)):
		status_text = "تکمیل"
		status_color = CityUI.RED
	elif need > int(Global.level):
		status_text = "سطح %s+" % CityUI.fa(need)
		status_color = CityUI.MUTED
		status_box.add_child(CityUI.icon(ICON_LOCK, 14, CityUI.MUTED))
	elif not is_public:
		status_text = "خصوصی"
		status_color = CityUI.GOLD
		status_box.add_child(CityUI.icon(ICON_LOCK, 14, CityUI.GOLD))
	status_box.add_child(CityUI.label(status_text, 14, status_color))

	# راهنمای «ضربه بزن» — شبیه فلش
	var chevron := CityUI.label("›", 26, CityUI.BLUE)
	chevron.text_direction = Control.TEXT_DIRECTION_LTR
	row.add_child(chevron)
