extends Control

signal buy_requested(item_data: Dictionary)

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
		if not price_bar.gui_input.is_connected(_on_price_bar_gui_input):
			price_bar.gui_input.connect(_on_price_bar_gui_input)

func setup_card(data: Dictionary) -> void:
	current_item_data = data
	
	if name_label:
		name_label.text = data.get("name", "")
	
	# ۱. بارگذاری عکس آیتم
	var raw_img_path: String = data.get("image_path", data.get("icon", ""))
	var loaded_tex: Texture2D = load_image_safely(raw_img_path)
	
	if item_texture:
		item_texture.texture = loaded_tex

	# ۲. تنظیم پس‌زمینه و اِعمال شیدر چرخشی استاندارد روی بردر
	var rarity = data.get("rarity", "rare")
	var base_color = RARITY_COLORS.get(rarity, Color.WHITE)
	
	apply_dynamic_gradient(base_color)
	apply_border_shader_effect(base_color)
	
	# ۳. قیمت و تخفیف
	var original_price = int(data.get("original_price", data.get("price", 0)))
	var discount_percent = int(data.get("discount_percent", data.get("discount", 0)))
	var final_price = int(data.get("final_price", 0))
	
	if final_price == 0 and original_price > 0:
		if discount_percent > 0:
			final_price = original_price - int(original_price * (discount_percent / 100.0))
		else:
			final_price = original_price
			
	if final_price_label:
		final_price_label.text = str(final_price)
	
	if discount_percent > 0:
		if discount_badge: discount_badge.visible = true
		if discount_label: 
			discount_label.text = "%d%%-" % discount_percent
		if old_price_container: old_price_container.visible = true
		if old_price_label: old_price_label.text = str(original_price)
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
	mat.set_shader_parameter("border_color", base_color.lightened(0.2))
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

## خرید فقط با «رها کردنِ» انگشت روی نوارِ قیمت، و فقط اگر انگشت تقریباً
## جابه‌جا نشده باشد — قبلاً همان لحظه‌ی فشردن خرید می‌زد، پس شروعِ اسکرول
## از روی کارت پنجره‌ی خرید را باز می‌کرد.
##
## فقط رویدادِ تاچ: روی PC هم emulate_touch_from_mouse همین را می‌سازد.
func _on_price_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var screen_pos := _screen_pos(event.position)
		if event.pressed:
			_touch_down = true
			_touch_start = screen_pos
			UIFx.press_scale(price_bar, true)
			return
		var was_down := _touch_down
		_touch_down = false
		UIFx.press_scale(price_bar, false)
		if was_down and screen_pos.distance_to(_touch_start) < TAP_SLOP:
			UIFx.tap(self, func() -> void: buy_requested.emit(current_item_data))
		return

	if event is InputEventScreenDrag and _touch_down:
		if _screen_pos(event.position).distance_to(_touch_start) >= TAP_SLOP:
			# این یک اسکرول است؛ رها کردنِ بعدی دیگر خرید حساب نمی‌شود
			_touch_down = false
			UIFx.press_scale(price_bar, false)

## مختصاتِ محلیِ نوارِ قیمت → پیکسلِ صفحه (مستقل از اسکرولِ لیست)
func _screen_pos(local_pos: Vector2) -> Vector2:
	return price_bar.get_global_transform_with_canvas() * local_pos
