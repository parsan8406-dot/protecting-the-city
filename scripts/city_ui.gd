class_name CityUI
extends RefCounted
## ظاهر مشترک صفحه‌ی «شهر» (کلن) و دیالوگ‌هایش — همان پالت آبی صفحه‌ی رنک.
##
## نکته: این «شهر» همان کلن بازیکن‌هاست و هیچ ربطی به مود بازی
## «عملیات امتیاز شهر» (citypoint) ندارد؛ برای همین هیچ‌جا از آرت آن مود
## یا عبارت «امتیاز شهر» استفاده نمی‌شود.
##
## همه‌ی توابع static هستند: CityUI.label("سلام")

const FONT := preload("res://fonts/SJADIDBD.TTF")
## اعداد با Lalezar — ارقام SJADIDBD هم‌تراز نمی‌شوند
const FONT_NUM := preload("res://fonts/Lalezar-Regular.ttf")

const TEXT := Color(0.9, 0.93, 1.0, 1.0)
const MUTED := Color(0.68, 0.74, 0.84, 1.0)
const GOLD := Color(0.97, 0.78, 0.3, 1.0)
const BLUE := Color(0.3, 0.6, 1.0, 1.0)
const GREEN := Color(0.35, 0.86, 0.45, 1.0)
const RED := Color(1.0, 0.36, 0.33, 1.0)

const PANEL_BG := Color(0.02, 0.04, 0.08, 0.82)
const PANEL_BORDER := Color(0.22, 0.36, 0.58, 0.8)

## حداقل ارتفاع دکمه‌های لمسی (~۴۸dp)
const TOUCH_H := 48.0

## نوع دکمه → (زمینه، حاشیه)
const BUTTON_KINDS := {
	"primary": [Color(0.05, 0.2, 0.46, 0.96), Color(0.3, 0.65, 1.0, 1.0)],
	"danger": [Color(0.42, 0.05, 0.05, 0.96), Color(1.0, 0.36, 0.3, 1.0)],
	"gold": [Color(0.3, 0.2, 0.03, 0.96), Color(0.97, 0.78, 0.3, 1.0)],
	"ghost": [Color(0.03, 0.06, 0.12, 0.92), Color(0.3, 0.42, 0.6, 0.8)],
}

const ROLE_LABELS := {"leader": "رهبر", "officer": "معاون", "member": "عضو"}
const ROLE_COLORS := {
	"leader": Color(0.97, 0.78, 0.3, 1.0),
	"officer": Color(0.62, 0.8, 1.0, 1.0),
	"member": Color(0.72, 0.76, 0.84, 1.0),
}

const ICON_CROWN := preload("res://assets/icons/missions/icon_crown.svg")
const ICON_SHIELD := preload("res://assets/icons/missions/icon_emblem.svg")

static func box(bg: Color, border: Color, width: int = 1, radius: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.corner_detail = 3
	return s

static func panel_box() -> StyleBoxFlat:
	return box(PANEL_BG, PANEL_BORDER, 1, 10)

static func label(text: String, size: int = 16, color: Color = TEXT, numeric: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT_NUM if numeric else FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func icon(texture: Texture2D, side: float, tint: Color = Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture
	t.custom_minimum_size = Vector2(side, side)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.modulate = tint
	return t

## دکمه‌ی لمسی با حالت pressed واضح (hover روی موبایل وجود ندارد)
static func button(text: String, kind: String = "primary", font_size: int = 17) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, TOUCH_H)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", font_size)
	style_button(b, kind)
	UIFx.bind_press_feedback(b)
	return b

## رنگ‌بندی دکمه را عوض می‌کند (مثلاً «عضویت» آبی ↔ «ترک شهر» قرمز)
static func style_button(b: Button, kind: String) -> void:
	var colors: Array = BUTTON_KINDS.get(kind, BUTTON_KINDS["primary"])
	var bg: Color = colors[0]
	var border: Color = colors[1]
	var normal := box(bg, border, 2, 8)
	normal.shadow_color = Color(border.r, border.g, border.b, 0.3)
	normal.shadow_size = 6
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	var pressed := box(bg.lightened(0.18), border.lightened(0.25), 2, 8)
	pressed.content_margin_left = 16
	pressed.content_margin_right = 16
	var disabled := box(Color(0.06, 0.08, 0.12, 0.9), Color(0.25, 0.3, 0.38, 0.7), 1, 8)
	disabled.content_margin_left = 16
	disabled.content_margin_right = 16
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", MUTED.darkened(0.2))

## LineEdit با ظاهر صفحه
static func line_edit(placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0, TOUCH_H)
	e.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	e.add_theme_font_override("font", FONT)
	e.add_theme_font_size_override("font_size", 17)
	e.add_theme_color_override("font_color", TEXT)
	e.add_theme_color_override("font_placeholder_color", MUTED.darkened(0.25))
	style_input(e)
	return e

static func style_input(control: Control) -> void:
	var normal := box(Color(0.02, 0.05, 0.1, 0.95), Color(0.22, 0.36, 0.58, 0.9), 1, 8)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = BLUE
	focus.set_border_width_all(2)
	control.add_theme_stylebox_override("normal", normal)
	control.add_theme_stylebox_override("focus", focus)
	control.add_theme_stylebox_override("read_only", normal)

static func divider() -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 1)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", box(Color(0.3, 0.42, 0.6, 0.35), Color(0, 0, 0, 0), 0, 0))
	return p

## کوتاه کردن متن با «…» — برای برچسب‌هایی که کنارشان چیز دیگری
## (تگ، تاج) باید بچسبد و نمی‌شود با clip_text کشیدشان
static func short(text: String, max_chars: int) -> String:
	if text.length() <= max_chars:
		return text
	return text.substr(0, max_chars - 1) + "…"

static func fa(value: int) -> String:
	return MissionArt.fa_number(value)

static func fa_grouped(value: int) -> String:
	return MissionArt.fa_grouped(value)

static func role_label(role: String) -> String:
	return str(ROLE_LABELS.get(role, "عضو"))

static func role_color(role: String) -> Color:
	return ROLE_COLORS.get(role, ROLE_COLORS["member"])

static func role_icon(role: String) -> Texture2D:
	return ICON_CROWN if role == "leader" else ICON_SHIELD

static func role_rank(role: String) -> int:
	match role:
		"leader": return 3
		"officer": return 2
		"member": return 1
	return 0

## آواتار بازیکن — اگر پیدا نشد اولین آواتار موجود (مثل تب دوستان)
static func avatar_texture(avatar_id: String) -> Texture2D:
	var texture := AvatarPicker.load_avatar_texture(avatar_id)
	if texture == null:
		var ids := AvatarPicker.list_avatar_ids()
		if not ids.is_empty():
			texture = AvatarPicker.load_avatar_texture(ids[0])
	return texture
