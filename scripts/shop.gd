extends Control

@onready var coins_label = $VBoxContainer/CoinsPanel/CoinsLabel
@onready var gems_label = $VBoxContainer/GemsPanel/GemsLabel
@onready var level_label = $VBoxContainer/LevelPanel/LevelLabel
@onready var items_grid = $ScrollContainer/ItemsRow

# دکمه‌های دسته‌بندی
@onready var weapons_tab = $HBoxContainer/WeaponsTab
@onready var characters_tab = $HBoxContainer/CharactersTab
@onready var coins_tab = $HBoxContainer/CoinsTab
@onready var gems_tab = $HBoxContainer/GemsTab # دکمه دسته‌بندی جم‌ها
const ITEM_CARD_SCENE = preload("res://secense/shop_item_card.tscn")

@onready var items_row = $ScrollContainer/ItemsRow
@onready var back_btn = $BackButton
var player_data = {}
var shop_items = []
var current_category = "weapon" # پیش‌فرض سلاح‌ها را نشان دهد

func _ready():
	$ShopHTTPRequest.request_completed.connect(_on_shop_loaded)
	$BuyHTTPRequest.request_completed.connect(_on_buy_completed)
	
	weapons_tab.pressed.connect(func(): change_category("weapon"))
	characters_tab.pressed.connect(func(): change_category("character"))
	coins_tab.pressed.connect(func(): change_category("coin_pack"))
	gems_tab.pressed.connect(func(): change_category("gem_pack")) # اضافه شد
	
	load_data_from_server()
	
func load_data_from_server():
	# ابتدا اطلاعات بازیکن را می‌گیریم تا بدانیم چقدر پول و چه دارایی‌هایی دارد
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(r, c, h, b):
		var json = JSON.new()
		json.parse(b.get_string_from_utf8())
		player_data = json.get_data()
		update_currency_ui()
		# حالا لیست کل مغازه را درخواست می‌کنیم
		$ShopHTTPRequest.request("http://localhost:8080/get_shop")
	)
	http.request("http://localhost:8080/get_player?username=" + Global.my_username)

func update_currency_ui():
	if player_data == null or typeof(player_data) != TYPE_DICTIONARY:
		return
	coins_label.text = str(int(player_data.get("coins", 0)))
	gems_label.text = str(int(player_data.get("gems", 0)))
	level_label.text = str(int(player_data.get("level", 1)))
	
func _on_shop_loaded(result, response_code, headers, body):
	if response_code == 200:
		var json = JSON.new()
		json.parse(body.get_string_from_utf8())
		
		# دیتای دریافتی از سرور را می‌گیریم
		var received_data = json.get_data()
		
		# سپر امنیتی: اگر دیتا پوچ بود (Nil) یا اصلاً آرایه نبود، آن را یک لیست خالی در نظر بگیر
		if typeof(received_data) == TYPE_ARRAY:
			shop_items = received_data
		else:
			shop_items = []
			print("مغازه خالی است یا سرور دیتایی نفرستاده!")
			
		render_shop()
	else:
		print("ارتباط با سرور برای دریافت لیست مغازه قطع است!")

func change_category(category):
	current_category = category
	render_shop()

# ساخت کارت‌های آیتم به صورت کاملاً پویا روی صفحه
# ساخت کارت‌های آیتم به صورت کاملاً پویا روی صفحه
func render_shop():
	for child in items_row.get_children():
		child.queue_free()
		
	if player_data == null or typeof(player_data) != TYPE_DICTIONARY:
		player_data = {}

	# بررسی دسته‌های بسته‌ای (جم و سکه)
	if current_category == "coin_pack" or current_category == "gem_pack":
		render_packages()
		return

	for item in shop_items:
		if item["category"] != current_category:
			continue
			
		var card_instance = ITEM_CARD_SCENE.instantiate()
		items_row.add_child(card_instance)
		
		var owned_list = player_data.get("owned_weapons", [])
		if item["category"] == "character":
			owned_list = player_data.get("owned_characters", [])
		
		if owned_list == null or typeof(owned_list) != TYPE_ARRAY:
			owned_list = []
			
		var is_owned = item["item_id"] in owned_list
		card_instance.setup_card(item, is_owned)
		card_instance.buy_pressed.connect(func(): send_buy_request(item["item_id"], item["category"]))
func render_coin_packages():
	var item_panel = PanelContainer.new()
	item_panel.custom_minimum_size = Vector2(250, 80)
	var vbox = VBoxContainer.new()
	item_panel.add_child(vbox)
	
	var name_lbl = Label.new()
	name_lbl.text = "بسته ۱۰۰۰ عددی سکه"
	vbox.add_child(name_lbl)
	
	var buy_btn = Button.new()
	buy_btn.text = "۱۰ جم"
	buy_btn.pressed.connect(func(): send_buy_request("coins_1000", "coin_pack"))
	vbox.add_child(buy_btn)
	
	items_grid.add_child(item_panel)

# ارسال درخواست خرید به سرور Go
func send_buy_request(item_id, category):
	var data = {
		"username": player_data["username"],
		"item_id": item_id,
		"category": category
	}
	var json_query = JSON.stringify(data)
	var headers = ["Content-Type: application/json"]
	$BuyHTTPRequest.request("http://localhost:8080/buy_item", headers, HTTPClient.METHOD_POST, json_query)

func _on_buy_completed(result, response_code, headers, body):
	if response_code == 200:
		print("خرید موفقیت‌آمیز بود!")
		# رفرش کردن اطلاعات بازیکن پس از خرید
		load_data_from_server()
	else:
		# نمایش ارور فرستاده شده از سمت سرور Go
		var err_msg = body.get_string_from_utf8()
		print("خطا در خرید: ", err_msg)

# ساخت پویای کارت‌های خرید سکه و جم
func render_packages():
	for item in shop_items:
		if item["category"] != current_category:
			continue
			
		var card_instance = ITEM_CARD_SCENE.instantiate()
		items_row.add_child(card_instance)
		
		# بسته‌های ارزی هیچ وقت از قبل خریداری شده نیستند، پس همیشه فعالند
		card_instance.setup_card(item, false)
		
		# در صورت کلیک، درخواست خرید بسته به سرور فرستاده می‌شود
		card_instance.buy_pressed.connect(func(): send_buy_request(item["item_id"], item["category"]))


func _on_back_button_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(back_btn, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(back_btn, "scale", Vector2(1.0, 1.0), 0.05)
	await tween.finished
	get_tree().change_scene_to_file("res://secense/main_menu.tscn")
	
