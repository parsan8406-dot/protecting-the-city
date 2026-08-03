extends TextureRect

# ارجاع به گره‌های داخل کارت
@onready var name_label = $VBoxContainer/MarginContainer/NameLabel
@onready var item_icon = $VBoxContainer/ItemIcon
@onready var price_label = $VBoxContainer/MarginContainer2/BuySection/PriceLabel
@onready var buy_button = $VBoxContainer/MarginContainer2/BuySection/BuyButton

# سیگنالی که وقتی بازیکن روی دکمه خرید کلیک کرد، به صحنه اصلی مغازه خبر می‌دهد
signal buy_pressed

func setup_card(item_data: Dictionary, is_owned: bool):
	name_label.text = item_data["name"]
	
	# ۱. لود کردن عکس آیتم به صورت پویا بر اساس آیدی آن
	# نکته مهم: عکس‌های بازی را در پوشه res://assets/items با نام دقیق item_id ذخیره کن (مثل rifle_m4.png)
	var image_path = "res://assets/items/" + item_data["item_id"] + ".png"
	if ResourceLoader.exists(image_path):
		item_icon.texture = load(image_path)
	
	# ۲. بررسی وضعیت خریداری شده بودن
	if is_owned:
		buy_button.disabled = true
		price_label.text = "دارید"
		buy_button.visible = false
	else:
		buy_button.disabled = false
		buy_button.visible = true
		var currency = " سکه" if item_data["cost_type"] == "coins" else " جم"
		price_label.text = str(item_data["price"]) + currency

		# ۳. اتصال دکمه خرید
		if buy_button.pressed.is_connected(_on_buy_button_pressed):
			buy_button.pressed.disconnect(_on_buy_button_pressed)
		buy_button.pressed.connect(_on_buy_button_pressed)

func _on_buy_button_pressed():
	emit_signal("buy_pressed")
