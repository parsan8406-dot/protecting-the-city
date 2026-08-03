extends Control

const CHAR_CARD_SCENE = preload("res://secense/char_card.tscn")

@onready var char_image_center = $CharImage

@onready var characters_grid = $CharBar2/ScrollContainer/CharactersGrid
@onready var weapons_grid = $CharBar/ScrollContainer/WeaponsGrid
@onready var back_btn = $BackButton
var player_data = {}
var all_items_in_database = [] # این آرایه دیگه دستی نیست، از سرور پر میشه!

func _ready():
	# قدم اول: گرفتن اطلاعات بازیکن (دارایی‌ها و تجهیزات فعال)
	var http_player = HTTPRequest.new()
	add_child(http_player)
	http_player.request_completed.connect(_on_player_data_loaded)
	http_player.request("http://localhost:8080/get_player?username=" + Global.my_username)
	
	

func _on_player_data_loaded(result, response_code, headers, body):
	if response_code == 200:
		var json = JSON.new()
		json.parse(body.get_string_from_utf8())
		player_data = json.get_data()
		Global.current_character = player_data.get("equipped_character", "skin_default")
		Global.current_weapon = player_data.get("equipped_weapon", "pistol_default")
		# قدم دوم: حالا که دیتای بازیکن رو گرفتیم، لیست کل آیتم‌های بازی رو از سرور درخواست می‌کنیم
		var http_catalog = HTTPRequest.new()
		add_child(http_catalog)
		http_catalog.request_completed.connect(_on_catalog_loaded)
		http_catalog.request("http://localhost:8080/get_shop")
		

func _on_catalog_loaded(result, response_code, headers, body):
	if response_code == 200:
		var json = JSON.new()
		json.parse(body.get_string_from_utf8())
		all_items_in_database = json.get_data() 
		
		# --- اضافه کردن آیتم‌های دیفالت به صورت دستی ---
		var has_default_char = false
		var has_default_weapon = false
		
		# بررسی می‌کنیم که یه وقت از قبل تو لیست نباشن
		for item in all_items_in_database:
			if item["item_id"] == "skin_default": has_default_char = true
			if item["item_id"] == "ak47": has_default_weapon = true # اسم دقیق گان دیفالت خودت رو بذار
			
		# اگر تو کاتالوگ فروشگاه نبودن، خودمون به عنوان یه کارت به صفحه معرفیشون می‌کنیم
		if not has_default_char:
			all_items_in_database.append({"item_id": "skin_default", "category": "character"})
		if not has_default_weapon:
			all_items_in_database.append({"item_id": "ak47", "category": "weapon"}) # اسم گان دیفالت
		# ------------------------------------------------
		
		render_all_grids()
func render_all_grids():
	# پاک کردن کارت‌های قبلی
	for child in characters_grid.get_children():
		child.queue_free()
	for child in weapons_grid.get_children():
		child.queue_free()
		
	var owned_chars = player_data.get("owned_characters", [])
	var equipped_char = str(player_data.get("equipped_character", ""))
	if typeof(owned_chars) != TYPE_ARRAY:
		owned_chars = []
	
	# Upload image char
	var image_path = "res://assets/select_icons/" + equipped_char + ".png"
	if ResourceLoader.exists(image_path):
		char_image_center.texture = load(image_path)
	else:
		print("Error load char image: ", image_path)
		char_image_center.texture = null
		
	var owned_weaps = player_data.get("owned_weapons", [])
	var equipped_weap = str(player_data.get("equipped_weapon", "ak47"))
	if typeof(owned_weaps) != TYPE_ARRAY:
		owned_weaps = []
	if not "skin_default" in owned_chars:
		owned_chars.append("skin_default")
	if not "ak47" in owned_weaps: # اسم گان دیفالت
		owned_weaps.append("ak47")
	# ----------------------------------------------------

	# حلقه هوشمند: می‌گرده تو کل دیتابیس سرور و کارت‌ها رو تفکیک می‌کنه
	for item in all_items_in_database:
		var item_id = item["item_id"]
		var category = item["category"]
		
		# اگر آیتم از نوع کاراکتر بود، بفرستش تو گرید کاراکترها
		if category == "character":
			var card = CHAR_CARD_SCENE.instantiate()
			characters_grid.add_child(card)
			
			var state = "locked"
			if item_id == equipped_char:
				state = "equipped"
			elif item_id in owned_chars:
				state = "owned"
				
			card.setup_card(item_id, category, state)
			card.card_clicked.connect(_on_item_equipped)
			
		# اگر آیتم از نوع سلاح بود، بفرستش تو گرید سلاح‌ها
		elif category == "weapon":
			var card = CHAR_CARD_SCENE.instantiate()
			weapons_grid.add_child(card)
			
			var state = "locked"
			if item_id == equipped_weap:
				state = "equipped"
			elif item_id in owned_weaps:
				state = "owned"
				
			card.setup_card(item_id, category, state)
			card.card_clicked.connect(_on_item_equipped)

func _on_item_equipped(selected_id, category):
	var data = {
		"username": player_data["username"],
		"item_id": selected_id,
		"category": category
	}
	var json_query = JSON.stringify(data)
	var headers = ["Content-Type: application/json"]
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(r, c, h, b):
		if c == 200:
			if category == "character":
				player_data["equipped_character"] = selected_id
				Global.current_character = selected_id
			elif category == "weapon":
				player_data["equipped_weapon"] = selected_id
				Global.current_weapon = selected_id
			render_all_grids()
	)
	http.request("http://localhost:8080/equip_item", headers, HTTPClient.METHOD_POST, json_query)


func _on_back_button_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(back_btn, "scale", Vector2(0.8, 0.8), 0.05)
	tween.tween_property(back_btn, "scale", Vector2(1.0, 1.0), 0.05)
	await tween.finished
	get_tree().change_scene_to_file("res://secense/main_menu.tscn")
