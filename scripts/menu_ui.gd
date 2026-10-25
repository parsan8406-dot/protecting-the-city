class_name MenuUI
extends RefCounted
## ظاهر مشترک منوی کاربر (پروفایل / تنظیمات / دوستان / پیام‌ها) و پنجره‌هایش.
## پالت: سیاه، قرمز و طلایی. همه‌ی توابع static هستند: MenuUI.label("سلام")
##
## همه‌ی دکمه‌ها حالت pressed واضح دارند و هیچ چیز به hover وابسته نیست.

const FONT := preload("res://fonts/SJADIDBD.TTF")
## اعداد با Lalezar — ارقام SJADIDBD هم‌تراز نمی‌شوند
const FONT_NUM := preload("res://fonts/Lalezar-Regular.ttf")

const TEXT := Color(0.96, 0.96, 0.97, 1.0)
const MUTED := Color(0.62, 0.62, 0.66, 1.0)
const DIM := Color(0.42, 0.42, 0.46, 1.0)
const RED := Color(0.85, 0.043, 0.075, 1.0)
const RED_HOT := Color(1.0, 0.22, 0.26, 1.0)
const GOLD := Color(1.0, 0.8, 0.26, 1.0)
const GOLD_DEEP := Color(0.72, 0.53, 0.14, 1.0)
const GREEN := Color(0.3, 0.86, 0.42, 1.0)

const CARD_BG := Color(0.078, 0.078, 0.086, 0.92)
const CARD_BORDER := Color(0.42, 0.42, 0.45, 0.42)

## حداقل ارتفاع دکمه‌های لمسی (~۴۸dp در رزولوشن پایه‌ی ۶۴۸)
const TOUCH_H := 50.0

## نوع دکمه → [زمینه، حاشیه، رنگ متن]
const BUTTON_KINDS := {
	"gold": [Color(0.32, 0.22, 0.03, 0.98), Color(1.0, 0.8, 0.26, 1.0), Color(1.0, 0.92, 0.7, 1.0)],
	"red": [Color(0.62, 0.03, 0.05, 0.98), Color(1.0, 0.3, 0.3, 1.0), Color(1.0, 1.0, 1.0, 1.0)],
	"dark": [Color(0.14, 0.14, 0.15, 0.98), Color(0.42, 0.42, 0.46, 0.9), Color(0.94, 0.94, 0.95, 1.0)],
	"white": [Color(0.96, 0.96, 0.97, 1.0), Color(0.96, 0.96, 0.97, 1.0), Color(0.08, 0.08, 0.09, 1.0)],
	"ghost": [Color(0.0, 0.0, 0.0, 0.0), Color(0.55, 0.55, 0.6, 0.7), Color(0.9, 0.9, 0.92, 1.0)],
}

## آیکن هر متریک دستاورد (از آیکن‌های همین منو)
const METRIC_ICONS := {
	"kills": preload("res://assets/ui/profile_menu/icon_kills.svg"),
	"wins": preload("res://assets/ui/profile_menu/icon_wins.svg"),
	"total_matches": preload("res://assets/ui/profile_menu/icon_matches.svg"),
	"assists": preload("res://assets/ui/profile_menu/icon_assists.svg"),
	"grenade_kills": preload("res://assets/ui/profile_menu/icon_grenade.svg"),
	"heals_given": preload("res://assets/ui/profile_menu/icon_heal.svg"),
	"missions_done": preload("res://assets/ui/profile_menu/icon_missions.svg"),
	"playtime_seconds": preload("res://assets/ui/profile_menu/icon_playtime.svg"),
}
const ICON_ACHIEVEMENT := preload("res://assets/ui/profile_menu/icon_achievement.svg")

static func box(bg: Color, border: Color, width: int = 1, radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.corner_detail = 4
	return s

static func card_box() -> StyleBoxFlat:
	var s := box(CARD_BG, CARD_BORDER, 1, 6)
	s.set_content_margin_all(14)
	return s

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

## دکمه‌ی لمسی با حالت pressed واضح
static func button(text: String, kind: String = "dark", font_size: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, TOUCH_H)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", font_size)
	style_button(b, kind)
	UIFx.bind_press_feedback(b)
	return b

static func style_button(b: Button, kind: String) -> void:
	var colors: Array = BUTTON_KINDS.get(kind, BUTTON_KINDS["dark"])
	var bg: Color = colors[0]
	var border: Color = colors[1]
	var fg: Color = colors[2]
	var normal := box(bg, border, 2 if kind != "white" else 0, 6)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	var pressed := box(bg.lightened(0.16) if kind != "white" else bg.darkened(0.16), border.lightened(0.2), 2, 6)
	pressed.content_margin_left = 14
	pressed.content_margin_right = 14
	var disabled := box(Color(0.1, 0.1, 0.11, 0.9), Color(0.26, 0.26, 0.3, 0.7), 1, 6)
	disabled.content_margin_left = 14
	disabled.content_margin_right = 14
	for state in ["normal", "hover"]:
		b.add_theme_stylebox_override(state, normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_focus_color", "icon_normal_color", "icon_hover_color", "icon_focus_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_pressed_color", fg.lightened(0.1))
	b.add_theme_color_override("icon_pressed_color", fg.lightened(0.1))
	b.add_theme_color_override("font_disabled_color", DIM)
	b.add_theme_color_override("icon_disabled_color", DIM)

## نوار پیشرفت باریک قرمز یا طلایی
static func progress_bar(color: Color = RED, height: float = 8.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, height)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", box(Color(0.22, 0.22, 0.24, 1.0), Color(0, 0, 0, 0), 0, 3))
	bar.add_theme_stylebox_override("fill", box(color, Color(0, 0, 0, 0), 0, 3))
	return bar

static func fa(value: int) -> String:
	return MissionArt.fa_number(value)

static func fa_grouped(value: int) -> String:
	return MissionArt.fa_grouped(value)

## آواتار بازیکن — اگر پیدا نشد اولین آواتار موجود
static func avatar_texture(avatar_id: String) -> Texture2D:
	var texture := AvatarPicker.load_avatar_texture(avatar_id)
	if texture == null:
		var ids := AvatarPicker.list_avatar_ids()
		if not ids.is_empty():
			texture = AvatarPicker.load_avatar_texture(ids[0])
	return texture

## اسم نمایشی سلاح‌ها (کاتالوگ فروشگاه همین شناسه‌ها را دارد)
const WEAPON_NAMES := {
	"ak47": "AK-47",
	"awm": "AWM",
	"f2000": "F2000",
	"fnmag": "FN MAG",
	"fnscare": "FN SCAR",
	"hk416": "HK416",
	"m24sws": "M24 SWS",
	"m82": "M82",
	"mg3": "MG3",
	"mp5": "MP5",
	"tac50": "TAC-50",
	"pistol_default": "کلت",
}

static func weapon_name(weapon_id: String) -> String:
	return str(WEAPON_NAMES.get(weapon_id, weapon_id.to_upper()))

## عکس سلاح: اول آرت فروشگاه، بعد اسپرایت داخل بازی (WeaponSkin)
static func weapon_texture(weapon_id: String) -> Texture2D:
	if weapon_id.is_empty():
		return null
	var path := "res://assets/weapons/%s.png" % weapon_id
	if ResourceLoader.exists(path):
		return load(path)
	return WeaponSkin.get_texture(weapon_id)

## نسبت کشتن به مرگ با یک رقم اعشار («۲٫۳»)
static func kd_text(kd: float) -> String:
	var s := "%.1f" % kd
	var out := ""
	for ch in s:
		out += "٫" if ch == "." else fa(int(ch)) if ch >= "0" and ch <= "9" else ch
	return out

static func metric_icon(metric: String) -> Texture2D:
	return METRIC_ICONS.get(metric, ICON_ACHIEVEMENT)

## «آنلاین» یا «۳ ساعت پیش» از روی زمان ISO سرور
static func last_seen_text(is_online: bool, iso: String) -> String:
	if is_online:
		return "آنلاین"
	var ago := ChatBubble.relative_time(iso)
	if ago.is_empty():
		return "آفلاین"
	return "آخرین بازدید " + ago

## خطای فارسی پاسخ سرور (یا یک پیام پیش‌فرض)
static func server_error(body: PackedByteArray, response_code: int, fallback: String = "") -> String:
	var parsed := parse_json(body)
	if parsed.has("error"):
		return str(parsed["error"])
	if response_code == 0:
		return "اتصال به سرور برقرار نشد — اینترنت را بررسی کن"
	if not fallback.is_empty():
		return fallback
	return "انجام نشد (کد %d)" % response_code

## JSON.new().parse خطا را در لاگ نمی‌ریزد (بدنه‌ی خالیِ پاسخ خطا عادی است)
static func parse_json(body: PackedByteArray) -> Dictionary:
	if body.is_empty():
		return {}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return {}
	return json.data if typeof(json.data) == TYPE_DICTIONARY else {}

# -----------------------------------------------------------------------------
# پنجره‌ی تأیید — برای کارهای برگشت‌ناپذیر (حذف دوست، جدا کردن از گوگل، ...)
# -----------------------------------------------------------------------------

## یک پنجره‌ی تأیید روی کل صفحه باز می‌کند. callback با true/false صدا زده می‌شود.
static func confirm(host: Node, title: String, body: String, ok_text: String,
		on_answer: Callable, danger: bool = false, cancel_text: String = "انصراف") -> Control:
	var sheet := ModalSheet.new()
	host.get_tree().root.add_child(sheet)
	var col := sheet.build(title)

	var text := label(body, 17, MUTED)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	text.custom_minimum_size = Vector2(0, 40)
	col.add_child(text)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var cancel := button(cancel_text, "dark")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ok := button(ok_text, "red" if danger else "gold")
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	row.add_child(ok)
	col.add_child(row)

	var answered := [false]
	var finish := func(value: bool) -> void:
		if answered[0]:
			return
		answered[0] = true
		sheet.close()
		if on_answer.is_valid():
			on_answer.call(value)
	cancel.pressed.connect(func() -> void: finish.call(false))
	ok.pressed.connect(func() -> void: UIFx.tap(ok, func() -> void: finish.call(true)))
	sheet.dismissed.connect(func() -> void: finish.call(false))
	sheet.open()
	return sheet


## پنجره‌ی مودال: دیمِ تمام‌صفحه + کارت وسط. با Back اندروید، ضربه روی دیم
## یا دکمه‌ی بستن بسته می‌شود. عضو گروه «modal» است تا منوی کاربر قبل از
## برگشتن به منوی اصلی اول همین را ببندد.
class ModalSheet extends Control:
	signal dismissed

	var card: PanelContainer
	var _closing := false
	var _max_width := 620.0

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		add_to_group("modal")
		z_index = 50

	func build(title: String, max_width: float = 620.0) -> VBoxContainer:
		_max_width = max_width
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.72)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.gui_input.connect(_on_dim_input)
		add_child(dim)

		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(center)

		card = PanelContainer.new()
		var style := MenuUI.box(Color(0.07, 0.07, 0.08, 0.99), MenuUI.GOLD_DEEP, 1, 10)
		style.border_width_top = 3
		style.border_color = MenuUI.RED
		style.set_content_margin_all(22)
		style.shadow_color = Color(0, 0, 0, 0.6)
		style.shadow_size = 18
		card.add_theme_stylebox_override("panel", style)
		center.add_child(card)

		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 14)
		card.add_child(col)

		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		var close_btn := MenuUI.button("✕", "ghost", 20)
		close_btn.custom_minimum_size = Vector2(MenuUI.TOUCH_H, MenuUI.TOUCH_H)
		close_btn.pressed.connect(func() -> void: dismiss())
		head.add_child(close_btn)
		var t := MenuUI.label(title, 23, MenuUI.TEXT)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(t)
		col.add_child(head)

		resized.connect(_fit)
		_fit()
		return col

	## عرض کارت با صفحه: روی گوشی باریک کم می‌شود، روی تبلت از حد بیشتر نمی‌شود
	func _fit() -> void:
		if card == null:
			return
		var view := get_viewport_rect().size if is_inside_tree() else Vector2(1152, 648)
		card.custom_minimum_size.x = minf(_max_width, view.x - 80.0)

	func open() -> void:
		_fit()
		modulate.a = 0.0
		await get_tree().process_frame
		if not is_instance_valid(card):
			return
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(0.94, 0.94)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)
		tw.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	## بسته شدن به‌خاطر کاربر (Back، دیم، ✕) — سیگنال dismissed می‌دهد
	func dismiss() -> void:
		if _closing:
			return
		dismissed.emit()
		close()

	func close() -> void:
		if _closing:
			return
		_closing = true
		remove_from_group("modal")
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "modulate:a", 0.0, 0.14).set_trans(Tween.TRANS_SINE)
		if is_instance_valid(card):
			tw.tween_property(card, "scale", Vector2(0.94, 0.94), 0.14)
		tw.chain().tween_callback(queue_free)

	func _on_dim_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch and not event.pressed:
			dismiss()

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			dismiss()
