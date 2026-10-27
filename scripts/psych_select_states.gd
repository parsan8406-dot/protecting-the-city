extends Control
## حالت‌های «لودینگ / خالی / خطا»ی گرید کارت‌های صفحه‌ی انتخاب.
##
## C12 دوهرتی: به‌جای متنِ ثابتِ «در حال گرفتن…» اسکلتِ کارت‌ها که آرام
## موج می‌خورند، تا صفحه هیچ‌وقت یخ‌زده دیده نشود.
## E1/E10: حالت خالی/خطا = آیکن + جمله‌ی دوستانه + یک اقدامِ پیشنهادی.
##
## روی CardsPanel و بیرونِ CardsGrid می‌نشیند (آموزش تعداد بچه‌های گرید را
## می‌شمارد، اسکلت نباید کارت حساب شود).

signal action_pressed

const GOLD := Color("ffc93c")

var _skeleton: GridContainer
var _shimmer: Tween
var _msg_box: VBoxContainer
var _msg_icon: TextureRect
var _msg_title: Label
var _msg_body: Label
var _msg_button: Button
var _phase := 0.0


func _init() -> void:
	name = "GridStates"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_skeleton = GridContainer.new()
	_skeleton.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skeleton.layout_direction = Control.LAYOUT_DIRECTION_RTL
	add_child(_skeleton)
	_skeleton.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skeleton.offset_left = 14.0
	_skeleton.offset_top = 14.0
	_skeleton.offset_right = -14.0
	_skeleton.visible = false

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_msg_box = VBoxContainer.new()
	_msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_msg_box.add_theme_constant_override("separation", 10)
	center.add_child(_msg_box)
	_msg_icon = MenuUI.icon(null, 84)
	_msg_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_msg_box.add_child(_msg_icon)
	_msg_title = MenuUI.label("", 22, MenuUI.TEXT)
	_msg_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_box.add_child(_msg_title)
	_msg_body = MenuUI.label("", 16, MenuUI.MUTED)
	_msg_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg_body.custom_minimum_size.x = 300.0
	_msg_box.add_child(_msg_body)
	_msg_button = MenuUI.button("", "gold", 18)
	_msg_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_msg_button.custom_minimum_size.x = 200.0
	_msg_button.pressed.connect(func() -> void: action_pressed.emit())
	_msg_box.add_child(_msg_button)
	_msg_box.visible = false


## اسکلتِ کارت‌ها با همان اندازه و تعداد ستونِ گرید واقعی
func show_loading(columns: int, card_size: Vector2, separation: int) -> void:
	_msg_box.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skeleton.columns = maxi(1, columns)
	_skeleton.add_theme_constant_override("h_separation", separation)
	_skeleton.add_theme_constant_override("v_separation", separation)
	var want := _skeleton.columns * 2
	while _skeleton.get_child_count() < want:
		var p := Panel.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_theme_stylebox_override("panel", MenuUI.box(Color(1, 1, 1, 0.07), Color(1, 1, 1, 0.08), 1, 16))
		_skeleton.add_child(p)
	for i in _skeleton.get_child_count():
		var c := _skeleton.get_child(i) as Control
		c.visible = i < want
		c.custom_minimum_size = card_size
	_skeleton.visible = true
	visible = true
	if _shimmer == null or not _shimmer.is_valid():
		_shimmer = create_tween().set_loops()
		_shimmer.tween_method(_apply_shimmer, 0.0, 1.0, 1.1)


## موجِ روشنایی که از راست به چپ (جهت خواندن) روی اسکلت‌ها رد می‌شود
func _apply_shimmer(t: float) -> void:
	var n := _skeleton.get_child_count()
	var cols := maxi(1, _skeleton.columns)
	for i in n:
		var c := _skeleton.get_child(i) as Control
		var k := float(i % cols) / float(cols) * 0.5 + float(i / cols) * 0.18
		c.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin((t - k) * TAU))


## حالت خالی/خطا. button_text خالی = بدون دکمه.
func show_message(icon: Texture2D, title: String, body: String, button_text: String) -> void:
	_stop_shimmer()
	_skeleton.visible = false
	_msg_icon.texture = icon
	_msg_icon.visible = icon != null
	_msg_title.text = title
	_msg_body.text = body
	_msg_body.visible = body != ""
	_msg_button.text = button_text
	_msg_button.visible = button_text != ""
	_msg_box.visible = true
	# فقط دکمه لمس را می‌گیرد؛ بقیه‌ی پنل لمس را به اسکرول می‌دهد
	visible = true
	_msg_box.modulate.a = 0.0
	var t := _msg_box.create_tween()
	t.tween_property(_msg_box, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)


func hide_all() -> void:
	_stop_shimmer()
	visible = false
	_skeleton.visible = false
	_msg_box.visible = false


func _stop_shimmer() -> void:
	if _shimmer and _shimmer.is_valid():
		_shimmer.kill()
	_shimmer = null
