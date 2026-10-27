extends HBoxContainer
## V8/E17 سکوی سه نفر اول صفحه‌ی «رتبه بندی» — اولین بچه‌ی لیست جدول در صفحه‌ی اول،
## پس با بقیه‌ی ردیف‌ها با انگشت اسکرول می‌شود و جای ثابتی نمی‌گیرد.
##
## چیدمان (چپ به راست): دوم · اول (بزرگ‌تر، با تاج) · سوم — مثل سکوی واقعی.
## همه‌ی اعداد همان entries سرور است (handlers_leaderboard.go)؛ چیزی ساخته نمی‌شود.
##
## استفاده: var p := Podium.new(); list.add_child(p); p.setup(top3, is_cities); p.play()

const ICON_CROWN := preload("res://assets/icons/missions/icon_crown.svg")
const ICON_CUP := preload("res://assets/icons/missions/icon_cup.png")

const PLACE_COLORS := {
	1: Color(1.0, 0.8, 0.26, 1.0),
	2: Color(0.82, 0.84, 0.88, 1.0),
	3: Color(0.88, 0.56, 0.3, 1.0),
}
const PEDESTAL_H := {1: 58.0, 2: 42.0, 3: 32.0}
const AVATAR_SIDE := {1: 70.0, 2: 56.0, 3: 56.0}

## ردیف‌های جدول این را می‌پرسند (ranking_screen._focus_me)
var position_in_table := 0

var _pedestals: Array[Control] = []
var _points: Array = []   # [label, value]
var _heads: Array[Control] = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 10)

func setup(top: Array, cities: bool) -> void:
	var by_place := {}
	for e in top:
		if typeof(e) == TYPE_DICTIONARY:
			by_place[int(e.get("position", 0))] = e
	for place in [2, 1, 3]:
		if by_place.has(place):
			add_child(_column(by_place[place], place, cities))
		else:
			var gap := Control.new()
			gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(gap)

## سازگار با ردیف‌ها: صفحه‌ی باریک چیزی را جمع نمی‌کند
func set_compact(_compact: bool) -> void:
	pass

func _column(e: Dictionary, place: int, cities: bool) -> Control:
	var color: Color = PLACE_COLORS[place]
	var is_me := bool(e.get("is_me", false)) or bool(e.get("is_mine", false))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1.2 if place == 1 else 1.0
	col.alignment = BoxContainer.ALIGNMENT_END
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)

	var head := VBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 2)
	col.add_child(head)
	_heads.append(head)

	if place == 1:
		var crown := MenuUI.icon(ICON_CROWN, 28, color)
		crown.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		head.add_child(crown)

	var side: float = AVATAR_SIDE[place]
	if cities:
		var emblem := CityEmblem.new()
		emblem.custom_minimum_size = Vector2(side, side)
		emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		emblem.set_icon(str(e.get("icon_path", "")))
		head.add_child(emblem)
	else:
		var avatar := ChatAvatar.new()
		avatar.custom_minimum_size = Vector2(side, side)
		avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		avatar.set_avatar(str(e.get("avatar_id", "")))
		avatar.set_ring(color)
		head.add_child(avatar)

	var name_text := str(e.get("name" if cities else "username", "—"))
	var name_label := MenuUI.label(name_text + ("  (تو)" if is_me else ""), 15 if place == 1 else 14,
		MenuUI.GOLD if is_me or place == 1 else MenuUI.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	name_label.custom_minimum_size = Vector2(60, 0)
	head.add_child(name_label)

	var pts_row := HBoxContainer.new()
	pts_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pts_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pts_row.add_theme_constant_override("separation", 4)
	pts_row.add_child(MenuUI.icon(ICON_CUP, 18))
	var pts := MenuUI.label("۰", 20 if place == 1 else 18, color, true)
	pts_row.add_child(pts)
	head.add_child(pts_row)
	_points.append([pts, int(e.get("points", 0))])

	# پایه‌ی سکو با عدد درشتِ جایگاه
	var ped := PanelContainer.new()
	ped.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ped.custom_minimum_size = Vector2(0, PEDESTAL_H[place])
	var st := MenuUI.box(Color(color.r * 0.22, color.g * 0.2, color.b * 0.16, 0.95), Color(color, 0.85), 1, 6)
	st.border_width_top = 3
	st.corner_radius_bottom_left = 0
	st.corner_radius_bottom_right = 0
	if is_me:
		st.shadow_color = Color(1.0, 0.75, 0.2, 0.35)
		st.shadow_size = 8
	ped.add_theme_stylebox_override("panel", st)
	var num := MenuUI.label(MenuUI.fa(place), 26 if place == 1 else 22, color, true)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ped.add_child(num)
	col.add_child(ped)
	_pedestals.append(ped)
	return col

## E17 ورود: سکوها از پایین بالا می‌آیند (سوم، دوم، بعد اول)، امتیازها طلایی شمرده می‌شوند.
## کوتاه (≤۰.۷ ثانیه) و بدون مسدود کردن لمس.
func play() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	# ترتیب ساخت: ۲، ۱، ۳ → تأخیرها طوری که ۳ اول و ۱ آخر برسد
	var delays := [0.08, 0.16, 0.0]
	for i in _pedestals.size():
		var ped := _pedestals[i]
		ped.pivot_offset = Vector2(ped.size.x * 0.5, ped.size.y)
		ped.scale = Vector2(1, 0)
		var head := _heads[i]
		head.modulate.a = 0.0
		var d: float = delays[i] if i < delays.size() else 0.0
		var t := create_tween().set_parallel(true)
		t.tween_property(ped, "scale", Vector2.ONE, 0.32).set_delay(d) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(head, "modulate:a", 1.0, 0.22).set_delay(d + 0.12)
	for p in _points:
		var label: Label = p[0]
		var value: int = p[1]
		var setter := func(v: float) -> void:
			if is_instance_valid(label):
				label.text = MenuUI.fa_grouped(int(v))
		create_tween().tween_method(setter, 0.0, float(value), 0.6) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
