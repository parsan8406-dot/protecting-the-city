extends Control

signal buy_requested(item_data: Dictionary)
## لمسِ هر جای کارت (عکس یا نوارِ قیمت) → پیش‌نمایش + تأیید در shop.gd (C11/C13)
signal card_clicked(item_data: Dictionary)

const Rarity := preload("res://scripts/psych_shop_rarity.gd")
const ART_FOLDERS := ["res://assets/characters/", "res://assets/items/", "res://assets/weapons/"]

@onready var background: TextureRect = $Background
@onready var border: ReferenceRect = $Border
@onready var name_label: Label = $NameLabel
@onready var item_texture: TextureRect = $ItemTexture

# بخش تخفیف
@onready var discount_badge: Control = $DiscountBadge
@onready var discount_label: Label = $DiscountBadge/DiscountLabel

# مسیر نودهای قیمت
@onready var price_bar: PanelContainer = $PriceBar
@onready var old_price_container: Control = $PriceBar/PriceContainer/OriginalPriceContainer
@onready var old_price_label: Label = $PriceBar/PriceContainer/OriginalPriceContainer/OldPriceLabel
@onready var final_price_label: Label = $PriceBar/PriceContainer/FinalPriceLabel
@onready var currency_icon: TextureRect = $PriceBar/PriceContainer/CurrencyIcon

var current_item_data: Dictionary = {}

const RARITY_COLORS = {
	"rare": Color("1565C0"),    # آبی تیره
	"epic": Color("6A1B9A"),    # بنفش تیره
	"legend": Color("E65100")   # طلایی / نارنجی
}

# مسیر فایل شیدر
const BORDER_SHADER = preload("res://shaders/border_spark.gdshader")

## جابه‌جاییِ انگشت بیشتر از این (پیکسلِ صفحه) یعنی اسکرولِ لیست، نه خرید
const TAP_SLOP := 12.0

## جای شروعِ لمس روی صفحه — نه داخلِ کارت: وقتی لیست زیرِ انگشت اسکرول
## می‌شود، کارت هم با انگشت می‌رود و فاصله‌ی محلی تقریباً صفر می‌ماند
var _touch_start := Vector2.ZERO
var _touch_down := false

func _ready():
	clip_contents = true
	# کارت و نوارِ قیمت لمس را به ScrollContainer هم می‌رسانند (PASS) تا
	# کشیدنِ انگشت روی کارت لیست را اسکرول کند؛ بقیه‌ی لایه‌ها اصلاً لمس نمی‌گیرند
	mouse_filter = Control.MOUSE_FILTER_PASS
	if border:
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if discount_badge:
		discount_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if price_bar:
		price_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	if not gui_input.is_connected(_on_card_gui_input):
		gui_input.connect(_on_card_gui_input)

func setup_card(data: Dictionary) -> void:
	current_item_data = data
	
	if name_label:
		name_label.text = data.get("name", "")
	
	# ۱. عکسِ آیتم از روی item_id (سرور image_path را خالی می‌فرستد؛ قبلاً کارت‌های
	# ویترین بی‌عکس بودند — V6)
	var loaded_tex: Texture2D = null
	var item_id := str(data.get("item_id", data.get("id", ""))).strip_edges()
	if item_id != "":
		for folder in ART_FOLDERS:
			if ResourceLoader.exists(folder + item_id + ".png"):
				loaded_tex = load(folder + item_id + ".png")
				break
	if loaded_tex == null:
		loaded_tex = load_image_safely(str(data.get("image_path", data.get("icon", ""))))
	
	if item_texture:
		item_texture.texture = loaded_tex

	# ۲. تنظیم پس‌زمینه و اِعمال شیدر چرخشی استاندارد روی بردر
	# V2 پالتِ مشترکِ رده + لوزی‌ها
	var rarity := Rarity.of(data)
	var base_color := Rarity.color(rarity)
	if background:
		background.texture = Rarity.gradient(rarity, true)
	apply_border_shader_effect(base_color)
	var pips := get_node_or_null("RarityPips") as Control
	if pips == null:
		pips = Rarity.pips(rarity, 11.0)
		pips.name = "RarityPips"
		add_child(pips)
	Rarity.set_pips(pips, rarity)
	pips.size = pips.custom_minimum_size
	pips.position = Vector2(5, 26)
	if name_label:
		name_label.add_theme_font_size_override("font_size", 15)
		# نام روی عکسِ شلوغ هم خوانا بماند
		name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		name_label.add_theme_constant_override("outline_size", 5)
	
	# ۳. قیمت و تخفیف
	var original_price = int(data.get("original_price", data.get("price", 0)))
	var discount_percent = int(data.get("discount_percent", data.get("discount", 0)))
	var final_price = int(data.get("final_price", 0))
	
	if final_price == 0 and original_price > 0 and not data.has("final_price"):
		if discount_percent > 0:
			final_price = original_price - int(original_price * (discount_percent / 100.0))
		else:
			final_price = original_price
			
	# V10: ارقامِ فارسیِ هم‌تراز با جداکننده، مثلِ بقیه‌ی فروشگاه («۲۵۰» نه «250»)
	if final_price_label:
		final_price_label.text = MissionArt.fa_grouped(final_price)
	
	if discount_percent > 0:
		if discount_badge: discount_badge.visible = true
		if discount_label: 
			discount_label.text = "٪%s-" % MissionArt.fa_number(discount_percent)
		if old_price_container: old_price_container.visible = true
		if old_price_label: old_price_label.text = MissionArt.fa_grouped(original_price)
	else:
		if discount_badge: discount_badge.visible = false
		if old_price_container: old_price_container.visible = false

	# ۴. آیکون سکه/الماس
	var cost_type = data.get("cost_type", data.get("currency", "coins"))
	if currency_icon:
		if cost_type == "gems":
			currency_icon.texture = load_image_safely("res://assets/ui/gem_icon.png")
		else:
			currency_icon.texture = load_image_safely("res://assets/ui/coin_icon.png")

# ⚡ اعمال افکت شیدر استاندارد روی بردر
func apply_border_shader_effect(base_color: Color) -> void:
	if not border:
		return
		
	border.border_width = 2.0
	border.border_color = Color.WHITE # رنگ پایه سفید تنظیم می‌شه تا شیدر کنترل رنگ رو دست بگیره
	
	# ساخت ShaderMaterial اختصاصی برای این کارت
	var mat = ShaderMaterial.new()
	mat.shader = BORDER_SHADER
	
	# پارامترهای شیدر:
	mat.set_shader_parameter("border_color", base_color)
	mat.set_shader_parameter("spark_color", Color(2.5, 2.5, 2.5, 0.45)) # نور سفید ملایم و نیمه‌شفاف
	mat.set_shader_parameter("speed", randf_range(0.8, 1.2))            # سرعت چرخشی متغیر
	mat.set_shader_parameter("spark_size", 0.06)                        # عرض نور محو
	mat.set_shader_parameter("time_offset", randf_range(0.0, 1.0))      # تاخیر موقعیت ابتدایی نور
	
	border.material = mat

func load_image_safely(path: String) -> Texture2D:
	path = path.strip_edges()
	if path == "":
		return null
		
	if not path.begins_with("res://"):
		path = "res://" + path

	if ResourceLoader.exists(path):
		return load(path) as Texture2D
		
	print("⚠️ عکس در این مسیر یافت نشد: ", path)
	return null

func apply_dynamic_gradient(main_color: Color) -> void:
	if not background:
		return
		
	var dark_center = main_color.darkened(0.4)
	var dark_edge = main_color.darkened(0.8)
	
	var gradient = Gradient.new()
	gradient.set_color(0, dark_center)
	gradient.set_color(1, dark_edge)
	
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = gradient
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.3)
	background.texture = grad_tex

## لمسِ کارت فقط با «رها کردنِ» انگشت و فقط اگر انگشت تقریباً جابه‌جا نشده باشد —
## شروعِ اسکرول از روی کارت هیچ پنجره‌ای باز نمی‌کند. خرید دیگر مستقیم نیست:
## پیش‌نمایش با قیمت و دکمه‌ی طلایی باز می‌شود (C13).
##
## فقط رویدادِ تاچ: روی PC هم emulate_touch_from_mouse همین را می‌سازد.
func _on_card_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var screen_pos := _screen_pos(event.position)
		if event.pressed:
			_touch_down = true
			_touch_start = screen_pos
			UIFx.press_scale(self, true)
			return
		var was_down := _touch_down
		_touch_down = false
		UIFx.press_scale(self, false)
		if was_down and screen_pos.distance_to(_touch_start) < TAP_SLOP:
			LocalSettings.vibrate(15)
			UIFx.tap(self, func() -> void: card_clicked.emit(current_item_data))
		return

	if event is InputEventScreenDrag and _touch_down:
		if _screen_pos(event.position).distance_to(_touch_start) >= TAP_SLOP:
			_touch_down = false
			UIFx.press_scale(self, false)

## مختصاتِ محلیِ کارت → پیکسلِ صفحه (مستقل از اسکرول)
func _screen_pos(local_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * local_pos
