
extends TextureButton

@onready var item_image = $Img/ItemImage
@onready var rgb_border = $RGBBorder
# آدرس عکسِ وضعیت‌ها (این ۳ عکس را آماده کن)
var card_blue = preload("res://assets/card_blue.png") # انتخاب شده
var card_green = preload("res://assets/card_green.png") # دارد ولی انتخاب نیست
var card_locked = preload("res://assets/card_locked.png") # ندارد (قفل)

var item_id = ""
var item_category = ""
signal card_clicked(i_id, i_category)

func setup_card(id: String, category: String, state: String):
	item_id = id
	item_category = category
	
	# آدرس پوشه جدید را اینجا وارد کردیم
	var image_path = "res://assets/select_icons/" + id + ".png" 
	
	if ResourceLoader.exists(image_path):
		item_image.texture = load(image_path)
	else:
		print("❌ ارور: عکس پیدا نشد! مسیر: ", image_path)
		
	if state == "equipped":
		texture_normal = card_blue
		disabled = true 
		rgb_border.visible = true  # 🌟 افکت را روشن کن!
	elif state == "owned":
		texture_normal = card_green
		disabled = false 
		rgb_border.visible = false # خاموش کردن افکت
	elif state == "locked":
		texture_normal = card_locked
		disabled = true 
		rgb_border.visible = false # خاموش کردن افکت
func _pressed():
	# ارسال اطلاعات به منوی اصلی که بدونه روی چی کلیک شده
	emit_signal("card_clicked", item_id, item_category)
