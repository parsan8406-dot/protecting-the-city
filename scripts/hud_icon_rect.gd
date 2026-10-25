extends Control
class_name HudIconRect
## یک آیکنِ HudIcons که مثلِ TextureRect داخلِ کانتینرها جا می‌گیرد.

var icon_name := ""
var tint := Color.WHITE


func setup(p_icon: String, px: float, p_tint: Color = Color.WHITE) -> HudIconRect:
	icon_name = p_icon
	tint = p_tint
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return self


func set_tint(c: Color) -> void:
	tint = c
	queue_redraw()


func _draw() -> void:
	HudIcons.draw(self, icon_name, Rect2(Vector2.ZERO, size), tint)
