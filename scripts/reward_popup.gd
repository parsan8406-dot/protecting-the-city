class_name RewardPopup
extends CanvasLayer
## نمایش جوایز — یک صفحه‌ی مشترک برای هر جایی از منوها که به بازیکن چیزی می‌رسد:
## خرید از فروشگاه، باز شدن صندوق، دریافت ماموریت، پله‌ی پاداش فصل، هدیه‌ی پیام و...
##
## شکلش: پس‌زمینه‌ی سیاهِ نسبتاً مات، یک ردیف کارت (آیکن بزرگ، «+عدد»، اسم) که
## یکی‌یکی با انیمیشن بالا می‌آیند، و زیرشان «برای دریافت صفحه را لمس کنید».
## دکمه‌ی جدایی ندارد — لمسِ هر جای صفحه جایزه را می‌گیرد و می‌بندد.
##
## ⚠️ این صفحه فقط «نمایش» است. جایزه قبل از باز شدنش سمت سرور واریز شده (پاسخ
## claim/buy تأیید شده برمی‌گردد و بعد این صفحه باز می‌شود)، پس لمس فقط
## بستن است و هیچ درخواستی نمی‌فرستد. عمداً این‌طور است: اگر اول جایزه را نشان
## می‌دادیم و بعد درخواست می‌زدیم، ممکن بود «+۴۰۰ سکه» نشان بدهیم و سرور رد کند.
##
## استفاده:
##   RewardPopup.show_rewards(RewardPopup.items_from_reward(data["reward"]))
##   RewardPopup.show_rewards([{"texture": tex, "label": "اسکین", "amount": 1}], "خرید موفق")
##
## هر آیتم یک Dictionary است:
##   icon     شناسه‌ی MissionArt (مثل "coin")    — یا —
##   texture  یک Texture2D آماده (عکس آیتم فروشگاه)
##   amount   عدد (۰ یعنی عدد نشان داده نشود، مثل اسکین)
##   label    اسم زیر عدد
##   tint     رنگ قاب (اختیاری؛ از روی icon حدس زده می‌شود)
##
## اگر وقتی یک نمایش باز است دوباره صدا زده شود، جوایز جدید در صف می‌مانند و
## بعد از بسته شدنِ اولی نشان داده می‌شوند.

## بعد از بسته شدن (یعنی بازیکن صفحه را لمس کرد)
signal closed

const FONT_UI := preload("res://fonts/SJADIDBD.TTF")
const FONT_NUM := preload("res://fonts/Lalezar-Regular.ttf")
const CONFETTI := preload("res://scripts/psych_results_confetti.gd")

## بالاتر از هر پاپ‌آپ و تاپ‌بار دیگری
const LAYER := 100

## شفافیت پس‌زمینه‌ی سیاه
const DIM_ALPHA := 0.88

## اندازه‌ی کارت‌ها. اگر تعداد زیاد باشد، کوچک می‌شوند تا یک ردیف بمانند.
const CARD_W := 150.0
const CARD_H := 196.0
const CARD_W_MIN := 104.0
const CARD_GAP := 14.0

## زمان‌بندی انیمیشن ورود
const T_DIM := 0.22
const T_CARD := 0.46
const T_STAGGER := 0.09
const T_COUNT := 0.7

## لمس‌هایی که زودتر از این برسند نادیده گرفته می‌شوند — وگرنه همان انگشتی که
## صندوق را زده، با بلند شدنش صفحه را همان لحظه می‌بندد
const INPUT_GUARD := 0.45

const COLOR_GOLD := Color(0.91, 0.76, 0.29, 1.0)
const COLOR_TEXT := Color(0.95, 0.96, 0.98, 1.0)
const COLOR_MUTED := Color(0.62, 0.67, 0.75, 1.0)

## رنگ قاب هر نوع جایزه — همان حسی که عکس مرجع دارد
const TINTS := {
	"coin": Color(0.91, 0.76, 0.29, 1.0),
	"gem": Color(0.95, 0.36, 0.47, 1.0),
	"xp": Color(0.31, 0.62, 0.97, 1.0),
	"cup": Color(0.98, 0.7, 0.25, 1.0),
	"trophy": Color(0.98, 0.7, 0.25, 1.0),
	"chest_common": Color(0.62, 0.69, 0.78, 1.0),
	"chest_rare": Color(0.66, 0.36, 0.85, 1.0),
	"chest_legend": Color(0.91, 0.76, 0.29, 1.0),
	"char_skin": Color(0.66, 0.36, 0.85, 1.0),
	"weapon_skin": Color(0.66, 0.36, 0.85, 1.0),
	"crown": Color(0.91, 0.76, 0.29, 1.0),
}
const TINT_DEFAULT := Color(0.66, 0.36, 0.85, 1.0)

## اسم فارسی هر نوع — وقتی صدازننده label نداده
const LABELS := {
	"coin": "سکه",
	"gem": "جم",
	"xp": "تجربه بازیکن",
	"cup": "کاپ فصل",
}

## صفحه‌ای که الان باز است و صفِ بعدی‌ها
static var _active: RewardPopup = null
static var _queue: Array = []

var _items: Array = []
var _title := ""
var _header: Texture2D = null

var _root: Control
var _dim: ColorRect
var _title_box: Control
var _cards_row: HBoxContainer
var _cards: Array[Control] = []
var _hint: Label

var _opened_at := 0.0
var _closing := false

# ------------------------------------------------------------------ API عمومی

## نمایش یک دسته جایزه. اگر نمایش دیگری باز است، در صف می‌ماند.
static func show_rewards(
	items: Array, title: String = "جوایز شما", header: Texture2D = null
) -> void:
	var clean: Array = []
	for item in items:
		if typeof(item) == TYPE_DICTIONARY:
			clean.append(item)
	if clean.is_empty():
		return

	if _active != null and is_instance_valid(_active):
		_queue.append([clean, title, header])
		return

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var popup := RewardPopup.new()
	popup._items = clean
	popup._title = title
	popup._header = header
	_active = popup
	# زیر ریشه نه زیر صحنه‌ی فعلی — اگر خرید باعث عوض شدن صحنه شود،
	# صفحه‌ی جایزه با آن نمی‌رود
	tree.root.add_child.call_deferred(popup)

## پاسخ استاندارد سرور ({coins, gems, xp, cups, icon, title}) → آیتم‌های نمایش.
## ترتیب: اول آیتم ویژه (اسکین)، بعد کاپ، جم، سکه، تجربه.
static func items_from_reward(reward: Dictionary) -> Array:
	var items: Array = []
	var icon := str(reward.get("icon", ""))
	if MissionArt.is_cosmetic(icon):
		items.append({"icon": icon, "amount": 0, "label": str(reward.get("title", "")),
			"texture": MissionArt.skin_texture(str(reward.get("skin_id", "")))})

	for key in [["cups", "cup"], ["gems", "gem"], ["coins", "coin"], ["xp", "xp"]]:
		var amount := int(reward.get(key[0], 0))
		if amount > 0:
			items.append({"icon": key[1], "amount": amount})
	return items

# ----------------------------------------------------------------- ساخت صفحه

func _ready() -> void:
	layer = LAYER
	_build()
	_play_in()
	_opened_at = Time.get_ticks_msec() / 1000.0

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# کل صفحه لمس را می‌گیرد: هم برای بستن، هم تا چیزی پشتش کلیک نشود
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_root_input)
	add_child(_root)

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, DIM_ALPHA)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)

	# ستون وسط: عنوان، کارت‌ها، دکمه، راهنما. با anchor و Container چیده
	# می‌شود تا روی هر نسبت صفحه وسط بماند.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 22)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)

	_title_box = _build_title()
	column.add_child(_title_box)

	_cards_row = HBoxContainer.new()
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_row.add_theme_constant_override("separation", int(CARD_GAP))
	_cards_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_cards_row)

	var card_w := _card_width(_items.size())
	# راست‌چین: اولین جایزه سمت راست
	for i in range(_items.size() - 1, -1, -1):
		var card := _build_card(_items[i], card_w)
		# کارت داخل یک Control ساده می‌نشیند نه مستقیم در HBox: شمارشِ عدد عرض
		# برچسب را عوض می‌کند و HBox با هر تغییر اندازه بچه‌هایش را از نو
		# می‌چیند — یعنی وسط انیمیشن کارت‌ها را سر جایشان می‌پراند. نگهدارنده
		# اندازه‌ی ثابت دارد و کاری به جای کارت ندارد.
		var holder := Control.new()
		holder.custom_minimum_size = card.custom_minimum_size
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(card)
		card.set_anchors_preset(Control.PRESET_FULL_RECT)
		_cards_row.add_child(holder)
		_cards.push_front(card)

	_hint = Label.new()
	_hint.text = "برای دریافت صفحه را لمس کنید"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_override("font", FONT_UI)
	# تنها دعوت به عمل صفحه است (دکمه‌ای در کار نیست)، پس باید دیده شود
	_hint.add_theme_font_size_override("font_size", 19)
	_hint.add_theme_color_override("font_color", COLOR_GOLD)
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_hint)

## عرض کارت: اگر همه در ۹۰٪ عرض صفحه جا شوند اندازه‌ی کامل، وگرنه کوچک‌تر
func _card_width(count: int) -> float:
	var screen_w := get_viewport().get_visible_rect().size.x
	var fit := (screen_w * 0.9 - CARD_GAP * float(count - 1)) / float(maxi(count, 1))
	return clampf(fit, CARD_W_MIN, CARD_W)

## عنوان با خط‌های طلایی دو طرفش، مثل تزئین بالای عکس مرجع
func _build_title() -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _header != null:
		var header := TextureRect.new()
		header.texture = _header
		header.custom_minimum_size = Vector2(0, 96)
		header.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		header.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(header)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)

	row.add_child(_ornament_line(true))

	var label := Label.new()
	label.text = _title
	label.add_theme_font_override("font", FONT_UI)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", COLOR_GOLD)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	row.add_child(_ornament_line(false))
	return box

## خط تزئینی: از شفاف به طلایی، با یک لوزی کوچک سمت عنوان
func _ornament_line(left: bool) -> Control:
	var holder := HBoxContainer.new()
	holder.add_theme_constant_override("separation", 6)
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var line := TextureRect.new()
	var grad := Gradient.new()
	var faded := Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.0)
	grad.set_color(0, faded if left else COLOR_GOLD)
	grad.set_color(1, COLOR_GOLD if left else faded)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 128
	tex.height = 2
	line.texture = tex
	line.custom_minimum_size = Vector2(120, 2)
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.stretch_mode = TextureRect.STRETCH_SCALE
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var diamond := Panel.new()
	var d_style := StyleBoxFlat.new()
	d_style.bg_color = COLOR_GOLD
	diamond.add_theme_stylebox_override("panel", d_style)
	diamond.custom_minimum_size = Vector2(7, 7)
	diamond.rotation_degrees = 45.0
	diamond.pivot_offset = Vector2(3.5, 3.5)
	diamond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if left:
		holder.add_child(line)
		holder.add_child(diamond)
	else:
		holder.add_child(diamond)
		holder.add_child(line)
	return holder

## یک کارت جایزه: آیکن بزرگ، «+عدد»، اسم
func _build_card(item: Dictionary, width: float) -> Control:
	var icon_id := str(item.get("icon", ""))
	var tint: Color = item.get("tint", TINTS.get(icon_id, TINT_DEFAULT))
	var scale_k := width / CARD_W

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(width, CARD_H * scale_k)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.05, 0.085, 0.97)
	style.set_border_width_all(2)
	style.border_color = Color(tint.r, tint.g, tint.b, 0.75)
	style.set_corner_radius_all(12)
	# سایه‌ی رنگی = درخشش دور کارت، بدون هیچ شیدری
	style.shadow_color = Color(tint.r, tint.g, tint.b, 0.35)
	style.shadow_size = 12
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", style)

	var body := VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 4)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(body)

	var icon := TextureRect.new()
	var texture: Texture2D = item.get("texture", null)
	icon.texture = texture if texture != null else MissionArt.texture_for(icon_id)
	icon.custom_minimum_size = Vector2(0, 96.0 * scale_k)
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# آیکن‌های سفیدِ تک‌رنگ رنگ قاب را می‌گیرند؛ آرت رنگی دست نمی‌خورد
	if texture == null and not MissionArt.is_art_icon(icon_id):
		icon.self_modulate = tint
	body.add_child(icon)
	card.set_meta("icon", icon)

	var amount := int(item.get("amount", 0))
	var amount_label := Label.new()
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_label.add_theme_font_override("font", FONT_NUM)
	amount_label.add_theme_font_size_override("font_size", int(26.0 * scale_k))
	amount_label.add_theme_color_override("font_color", COLOR_TEXT)
	amount_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	amount_label.add_theme_constant_override("shadow_offset_y", 2)
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount_label.visible = amount > 0
	amount_label.text = "+۰"
	body.add_child(amount_label)
	card.set_meta("amount_label", amount_label)
	card.set_meta("amount", amount)

	var name_label := Label.new()
	name_label.text = str(item.get("label", LABELS.get(icon_id, "")))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_override("font", FONT_UI)
	name_label.add_theme_font_size_override("font_size", int(14.0 * scale_k))
	name_label.add_theme_color_override("font_color", COLOR_MUTED)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(name_label)

	# تا وقتی نوبتش نرسیده دیده نشود
	card.modulate.a = 0.0
	return card

# ------------------------------------------------------------------ انیمیشن

func _play_in() -> void:
	_dim.modulate.a = 0.0
	create_tween().tween_property(_dim, "modulate:a", 1.0, T_DIM)

	_title_box.modulate.a = 0.0
	var t_title := create_tween().set_parallel()
	t_title.tween_property(_title_box, "modulate:a", 1.0, 0.3).set_delay(0.08)

	# چیدمان کارت‌ها یک فریم بعد معلوم می‌شود؛ pivot باید وسط واقعی کارت باشد
	await get_tree().process_frame
	if not is_instance_valid(self):
		return

	for i in _cards.size():
		_animate_card(_cards[i], 0.18 + T_STAGGER * float(i))

	var after_cards := 0.18 + T_STAGGER * float(_cards.size()) + T_CARD * 0.6

	# E17 جشنِ کوتاه فقط برای جایزه‌ی واقعاً ویژه (اسکین، صندوقِ افسانه‌ای، تاج)
	# — اگر برای هر سکه‌ای کنفتی بریزد عادی می‌شود و دیگر حس نمی‌شود
	if _is_special():
		get_tree().create_timer(after_cards).timeout.connect(func() -> void:
			if not is_instance_valid(self):
				return
			var c := CONFETTI.new()
			add_child(c)
			var vp := get_viewport().get_visible_rect().size
			c.burst(Vector2(vp.x * 0.5, vp.y * 0.18), vp.x * 0.5)
			LocalSettings.vibrate(40))

	# راهنمای «لمس کنید» آرام نبض می‌زند
	_hint.modulate.a = 0.0
	var t_hint := create_tween().set_loops()
	t_hint.tween_interval(after_cards)
	t_hint.tween_property(_hint, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	t_hint.tween_property(_hint, "modulate:a", 0.45, 0.7).set_trans(Tween.TRANS_SINE)

func _is_special() -> bool:
	for item in _items:
		var icon := str(item.get("icon", ""))
		if MissionArt.is_cosmetic(icon) or icon in ["chest_legend", "crown"]:
			return true
	return false

## ورود یک کارت: از پایین و کوچک، با پرش نرم به اندازه‌ی واقعی
func _animate_card(card: Control, delay: float) -> void:
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.35, 0.35)
	var rest_y := card.position.y
	card.position.y = rest_y + 34.0

	var t := create_tween().set_parallel()
	t.tween_property(card, "modulate:a", 1.0, T_CARD * 0.5).set_delay(delay)
	t.tween_property(card, "scale", Vector2.ONE, T_CARD).set_delay(delay) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(card, "position:y", rest_y, T_CARD).set_delay(delay) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# لحظه‌ی نشستن: یک فلاش کوتاه
	var t_flash := create_tween()
	t_flash.tween_interval(delay + T_CARD * 0.55)
	t_flash.tween_property(card, "self_modulate", Color(1.5, 1.4, 1.2, 1.0), 0.08)
	t_flash.tween_property(card, "self_modulate", Color.WHITE, 0.3)

	# عدد از صفر بالا می‌رود
	var amount := int(card.get_meta("amount", 0))
	var amount_label := card.get_meta("amount_label") as Label
	if amount > 0 and amount_label != null:
		var t_count := create_tween()
		t_count.tween_interval(delay + T_CARD * 0.4)
		t_count.tween_method(func(v: float) -> void:
			if is_instance_valid(amount_label):
				amount_label.text = "+" + MissionArt.fa_grouped(int(round(v))),
			0.0, float(amount), T_COUNT) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# آیکن بعد از نشستن آرام نفس می‌کشد
	var icon := card.get_meta("icon") as Control
	if icon != null:
		var t_icon := create_tween().set_loops()
		t_icon.tween_interval(delay + T_CARD)
		t_icon.tween_callback(func() -> void:
			if is_instance_valid(icon):
				icon.pivot_offset = icon.size * 0.5)
		t_icon.tween_property(icon, "scale", Vector2(1.06, 1.06), 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t_icon.tween_property(icon, "scale", Vector2.ONE, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ---------------------------------------------------------------- بستن

func _on_root_input(event: InputEvent) -> void:
	# «رها کردن» انگشت می‌بندد نه فشار دادنش — تا کشیدن انگشت روی صفحه
	# به‌عنوان لمس حساب نشود
	var released := false
	if event is InputEventScreenTouch:
		released = not (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		released = mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed
	if released:
		_root.accept_event()
		_close()

## دکمه‌ی Back اندروید هم مثل لمس صفحه می‌بندد
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_close()

func _close() -> void:
	if _closing:
		return
	# لمسی که همان لحظه‌ی باز شدن رسیده (معمولاً بلند شدنِ همان انگشتی که
	# صندوق را زده) حساب نمی‌شود
	if Time.get_ticks_msec() / 1000.0 - _opened_at < INPUT_GUARD:
		return
	_closing = true

	var t := create_tween().set_parallel()
	for i in _cards.size():
		var card := _cards[i]
		t.tween_property(card, "position:y", card.position.y - 40.0, 0.22) \
			.set_delay(0.03 * float(i)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.tween_property(card, "modulate:a", 0.0, 0.2).set_delay(0.03 * float(i))
	t.tween_property(_hint, "modulate:a", 0.0, 0.15)
	t.tween_property(_title_box, "modulate:a", 0.0, 0.18)
	t.tween_property(_dim, "modulate:a", 0.0, 0.26).set_delay(0.08)
	await t.finished

	closed.emit()
	if _active == self:
		_active = null
	queue_free()

	# نوبت دسته‌ی بعدی در صف
	if not _queue.is_empty():
		var next: Array = _queue.pop_front()
		RewardPopup.show_rewards(next[0], next[1], next[2])
