extends Control

@onready var level_label = $VBoxContainer/LevelPanel/LevelLabel
@onready var coins_label = $VBoxContainer/CoinsPanel/CoinsLabel
@onready var name_label = $VBoxContainer/NameLabel
@onready var gems_label = $VBoxContainer/GemsPanel/GemsLabel
@onready var xp_label = $VBoxContainer/LevelPanel/XPLabel
@onready var xp_bar = $VBoxContainer/LevelPanel/ProgressBar
@onready var char_select_btn = $CharSelectBtn
@onready var start_btn = $StartBtn
@onready var shop_btn = $ShopButton
@onready var addcoin_btn = $VBoxContainer/CoinsPanel/AddCoinButton
@onready var addgem_btn = $VBoxContainer/GemsPanel/AddGemButton
@onready var selected_char = $CharSelectBtn/TextureRect
func _ready():
	$HTTPRequest.request_completed.connect(_on_request_completed)
	level_label.text = "..."
	xp_label.text = "..."
	
	# اتصال دهنده‌های دکمه‌ها
	char_select_btn.pressed.connect(_on_char_select_btn_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	shop_btn.pressed.connect(_on_shop_button_pressed)
	addcoin_btn.pressed.connect(_on_add_coin_button_pressed)
	addgem_btn.pressed.connect(_on_add_gem_button_pressed)
	
	$HTTPRequest.request("http://localhost:8080/get_player?username=" + Global.my_username)


# انیمیشن و رفتن به صفحه انتخاب کاراکتر
func _on_char_select_btn_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(char_select_btn, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(char_select_btn, "scale", Vector2(1.0, 1.0), 0.05)
	await tween.finished
	get_tree().change_scene_to_file("res://secense/character_select_screen.tscn")


# رفتن مستقیم به داخل بازی اصلی
func _on_start_pressed():
	# به جای World.tscn، اسم فایل صحنه بازی خودت رو بنویس
	var tween = create_tween()
	tween.tween_property(start_btn, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(start_btn, "scale", Vector2(1.0, 1.0), 0.05)
	await tween.finished
	get_tree().change_scene_to_file("res://secense/World.tscn")

func _on_request_completed(result, response_code, headers, body):
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var data = json.get_data()
			# خواندن مستقیم اطلاعات از سرور
			level_label.text = str(int(data.get("level", 0)))
			# نمایش باقیمانده تجربه / گنجایش این لول
			xp_label.text = str(int(data.get("display_xp", 0))) + " / " + str(int(data.get("max_xp", 0)))
			gems_label.text = str(int(data.get("gems", 0)))
			coins_label.text = str(int(data.get("coins", 0)))
			var image_path = "res://assets/select_icons/" + str(data.get("equipped_character", "")) + ".png"
			if ResourceLoader.exists(image_path):
				selected_char.texture = load(image_path)
			else:
				print("Error load char: ", image_path)
		else:
			print("❌ Invalid JSON from server:", body.get_string_from_utf8())
			level_label.text = "خطا در داده"
	else:
		level_label.text = "خطا در اتصال"


func _on_shop_button_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(shop_btn, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(shop_btn, "scale", Vector2(1.0, 1.0), 0.05)
	await tween.finished
	get_tree().change_scene_to_file("res://secense/Shop.tscn")


func _on_add_coin_button_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(addcoin_btn, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(addcoin_btn, "scale", Vector2(1.0, 1.0), 0.05)
	await tween.finished
	get_tree().change_scene_to_file("res://secense/Shop.tscn")

func _on_add_gem_button_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(addgem_btn, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(addgem_btn, "scale", Vector2(1.0, 1.0), 0.05)
	await tween.finished
	get_tree().change_scene_to_file("res://secense/Shop.tscn")
