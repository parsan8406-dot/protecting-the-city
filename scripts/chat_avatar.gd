class_name ChatAvatar
extends TextureRect
## آواتار گردِ صفحه‌ی چت با حلقه‌ی رنگی دورش (shaders/circle_avatar.gdshader).
##
## استفاده: این اسکریپت را روی یک TextureRect بگذار و بعد
##   avatar.set_avatar(avatar_id)       # آیدی آواتار از پوشه‌ی profiles
##   avatar.set_ring(ChatAvatar.RING_GOLD)

const SHADER := preload("res://shaders/circle_avatar.gdshader")

## رنگ‌های حلقه
const RING_DEFAULT := Color(0.42, 0.42, 0.46, 1.0)
const RING_BLUE := Color(0.24, 0.62, 1.0, 1.0)
const RING_GOLD := Color(1.0, 0.76, 0.24, 1.0)
const RING_GREEN := Color(0.2, 0.82, 0.38, 1.0)

## متریال‌ها بر اساس رنگ حلقه بین همه‌ی آواتارها مشترک‌اند (نه یکی برای هر نود)
static var _materials: Dictionary = {}

func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ChatAvatar.material_for(RING_DEFAULT)

func set_avatar(avatar_id: String) -> void:
	var tex := AvatarPicker.load_avatar_texture(avatar_id)
	if tex == null:
		var ids := AvatarPicker.list_avatar_ids()
		if not ids.is_empty():
			tex = AvatarPicker.load_avatar_texture(ids[0])
	texture = tex

func set_ring(color: Color) -> void:
	material = ChatAvatar.material_for(color)

static func material_for(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if _materials.has(key):
		return _materials[key]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("ring_color", color)
	_materials[key] = mat
	return mat
