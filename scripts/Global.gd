extends Node

var current_character = "skin_default"
var current_weapon = "ak47"
var my_username = ""

signal player_data_loaded

func _ready():  # 🌟 اصلاح: ready به _ready تغییر کرد
	randomize()
	my_username = "Player" + str(randi() % 10000)
	fetch_player_data()

func fetch_player_data():
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	var url = "http://localhost:8080/get_player?username=" + my_username
	var err = http_request.request(url)
	if err != OK:
		print("❌ خطا در ارسال درخواست به سرور")

func _on_request_completed(result, response_code, headers, body):
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			var player_data = json.get_data()
			if player_data.has("equipped_character") and player_data["equipped_character"] != "":
				current_character = player_data["equipped_character"]
			if player_data.has("equipped_weapon") and player_data["equipped_weapon"] != "":
				current_weapon = player_data["equipped_weapon"]
			print("✅ دیتا از دیتابیس لود شد! من در دیتابیس هستم: ", my_username)
			player_data_loaded.emit()
		else:
			print("❌ خطا در دریافت اطلاعات. کد ارور: ", response_code)