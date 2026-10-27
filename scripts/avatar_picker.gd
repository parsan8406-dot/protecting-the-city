class_name AvatarPicker
extends Control
## باکس انتخاب عکس پروفایل.
## عکس‌ها را از پوشه‌ی res://assets/profiles می‌خواند — هر چند تا که آنجا باشد.
## سلول‌ها همیشه مربع (۱:۱) هستند.
##
## استفاده:
##   var picker := preload("res://secense/avatar_picker.tscn").instantiate()
##   picker.avatar_selected.connect(func(id): ...)
##   add_child(picker)
##   picker.open(current_avatar_id)

signal avatar_selected(avatar_id: String)
signal cancelled

const AVATARS_DIR := "res://assets/profiles"
const CELL_SIZE := 88.0
const VALID_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "svg"]

@onready var _dim: ColorRect = $Dim
@onready var _dialog: PanelContainer = $Dialog
@onready var _grid: GridContainer = $Dialog/Margin/Body/Scroll/Grid
@onready var _empty_label: Label = $Dialog/Margin/Body/EmptyLabel
@onready var _confirm_button: Button = $Dialog/Margin/Body/Buttons/ConfirmButton
@onready var _cancel_button: Button = $Dialog/Margin/Body/Buttons/CancelButton

var _selected_id: String = ""
var _cells: Dictionary = {}   # avatar_id -> TextureButton

## انگشت بیش از این روی صفحه جابه‌جا شود یعنی اسکرولِ گرید، نه انتخاب
const DRAG_SLOP := 12.0
var _touch_start := Vector2.ZERO
var _cell_dragged := false

func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	# V9: فشردنِ دکمه‌ها دیده و شنیده می‌شود
	UIFx.bind_press_feedback(_confirm_button)
	UIFx.bind_press_feedback(_cancel_button)
	_dim.gui_input.connect(_on_dim_input)
	_build_grid()

## باز کردن باکس با مشخص کردن آواتار فعلی
func open(current_avatar_id: String = "") -> void:
	_select(current_avatar_id)
	visible = true
	_dialog.pivot_offset = _dialog.size * 0.5
	_dialog.scale = Vector2(0.88, 0.88)
	_dialog.modulate.a = 0.0
	_dim.modulate.a = 0.0

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_dim, "modulate:a", 1.0, 0.15)
	t.tween_property(_dialog, "modulate:a", 1.0, 0.15)
	t.tween_property(_dialog, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close() -> void:
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_dim, "modulate:a", 0.0, 0.12)
	t.tween_property(_dialog, "modulate:a", 0.0, 0.12)
	t.tween_property(_dialog, "scale", Vector2(0.9, 0.9), 0.12)
	t.chain().tween_callback(queue_free)

# ------------------------------------------------------------------ ساخت گرید

func _build_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_cells.clear()

	var ids := list_avatar_ids()
	_empty_label.visible = ids.is_empty()

	for avatar_id in ids:
		var texture := load_avatar_texture(avatar_id)
		if texture == null:
			continue

		var button := TextureButton.new()
		button.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)  # مربع ۱:۱
		button.texture_normal = texture
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.modulate = Color(0.62, 0.62, 0.64, 1.0)
		# کشیدن روی سلول‌ها گرید را اسکرول کند (PASS) و اسکرول انتخاب حساب نشود
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.gui_input.connect(_on_cell_input.bind(button))
		button.pressed.connect(_on_cell_pressed.bind(avatar_id))

		_grid.add_child(button)
		_cells[avatar_id] = button

## لیست آیدی آواتارها (نام فایل بدون پسوند) از پوشه‌ی profiles
static func list_avatar_ids() -> Array[String]:
	var ids: Array[String] = []
	var dir := DirAccess.open(AVATARS_DIR)
	if dir == null:
		push_warning("پوشه‌ی آواتارها پیدا نشد: " + AVATARS_DIR)
		return ids

	for file_name in dir.get_files():
		# توی بیلد اکسپورت‌شده فایل‌ها پسوند اضافه دارن (.import / .remap)
		var clean := file_name
		if clean.ends_with(".import"):
			clean = clean.trim_suffix(".import")
		if clean.ends_with(".remap"):
			clean = clean.trim_suffix(".remap")

		if not VALID_EXTENSIONS.has(clean.get_extension().to_lower()):
			continue

		var avatar_id := clean.get_basename()
		if not ids.has(avatar_id):
			ids.append(avatar_id)

	ids.sort()
	return ids

## پیدا کردن تکسچر یک آواتار با هر پسوندی که داشته باشه
static func load_avatar_texture(avatar_id: String) -> Texture2D:
	if avatar_id.is_empty():
		return null
	for ext in VALID_EXTENSIONS:
		var path := "%s/%s.%s" % [AVATARS_DIR, avatar_id, ext]
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null

# ------------------------------------------------------------------ انتخاب

func _on_cell_input(event: InputEvent, button: Control) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_cell_dragged = false
		_touch_start = button.get_global_transform_with_canvas() * event.position
	elif event is InputEventScreenDrag and not _cell_dragged:
		var p: Vector2 = button.get_global_transform_with_canvas() * event.position
		if p.distance_to(_touch_start) > DRAG_SLOP:
			_cell_dragged = true

func _on_cell_pressed(avatar_id: String) -> void:
	if _cell_dragged:
		_cell_dragged = false
		return
	_select(avatar_id)
	var button := _cells.get(avatar_id) as TextureButton
	if button:
		UIFx.press(button)

func _select(avatar_id: String) -> void:
	_selected_id = avatar_id if _cells.has(avatar_id) else ""
	_confirm_button.disabled = _selected_id.is_empty()

	for id in _cells:
		var button := _cells[id] as TextureButton
		var is_selected: bool = id == _selected_id
		button.modulate = Color(1, 1, 1, 1) if is_selected else Color(0.62, 0.62, 0.64, 1)
		# V1/V9 انتخاب با قاب طلایی + تیک، نه فقط روشنایی (رنگ همیشه همراه شکل)
		var frame := button.get_node_or_null("SelFrame") as Panel
		if is_selected and frame == null:
			frame = Panel.new()
			frame.name = "SelFrame"
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var st := StyleBoxFlat.new()
			st.draw_center = false
			st.border_color = Color(1.0, 0.8, 0.26, 1.0)
			st.set_border_width_all(3)
			st.set_corner_radius_all(8)
			frame.add_theme_stylebox_override("panel", st)
			frame.set_anchors_preset(Control.PRESET_FULL_RECT)
			button.add_child(frame)
			var tick := MenuUI.label("✓", 18, Color(0.1, 0.07, 0.0))
			tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var badge := PanelContainer.new()
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			badge.add_theme_stylebox_override("panel", MenuUI.box(Color(1.0, 0.8, 0.26, 1.0), Color(0, 0, 0, 0), 0, 12))
			badge.custom_minimum_size = Vector2(24, 24)
			badge.position = Vector2(4, 4)
			badge.add_child(tick)
			frame.add_child(badge)
		if frame != null:
			frame.visible = is_selected

func _on_confirm_pressed() -> void:
	if _selected_id.is_empty():
		return
	avatar_selected.emit(_selected_id)
	close()

func _on_cancel_pressed() -> void:
	cancelled.emit()
	close()

## Back اندروید از profile_menu
func dismiss() -> void:
	_on_cancel_pressed()

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_cancel_pressed()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		accept_event()
		_on_cancel_pressed()
