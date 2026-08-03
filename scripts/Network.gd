extends Node

signal player_moved(username, new_position, new_rotation)
signal server_players_updated(players_dict)
signal player_shot(username, pos, rot)
signal health_updated(username, new_health)
signal player_died(username)
signal game_countdown(seconds)
signal game_started
signal heal_success(username, new_health)
signal heal_cooldown_started(username)
signal bomb_thrown(data)
signal bomb_explosion(data)

var socket = WebSocketPeer.new()
var is_connected = false
var current_players = {}

func _ready():
	Global.player_data_loaded.connect(connect_to_server)

func connect_to_server():
	var err = socket.connect_to_url("ws://localhost:8080/ws")
	if err != OK:
		print("❌ خطا در اتصال به سرور")
		set_process(false)

func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not is_connected:
			is_connected = true
			print("✅ متصل با آیدی: ", Global.my_username)
			send_join_request()
		while socket.get_available_packet_count() > 0:
			var packet = socket.get_packet().get_string_from_utf8()
			var messages = packet.split("\n", false)
			for msg in messages:
				msg = msg.strip_edges()
				if msg == "":
					continue
				var data = JSON.parse_string(msg)
				if typeof(data) == TYPE_DICTIONARY:
					var msg_type = data.get("type", "")
					if msg_type == "update_players":
						current_players = data["players"]
						server_players_updated.emit(current_players)
					elif msg_type == "move":
						var rot = data.get("rot", 0.0)
						player_moved.emit(data["username"], Vector2(data["x"], data["y"]), rot)
					elif msg_type == "shoot":
						player_shot.emit(data["username"], Vector2(data["x"], data["y"]), data["rot"])
					elif msg_type == "health_update":
						health_updated.emit(data["username"], data["health"])
					elif msg_type == "die":
						player_died.emit(data["username"])
					elif msg_type == "countdown":
						game_countdown.emit(data.get("seconds", 3))
					elif msg_type == "game_start":
						game_started.emit()
					elif msg_type == "heal_success":
						heal_success.emit(data["username"], data["health"])
					elif msg_type == "heal_cooldown":
						heal_cooldown_started.emit(data["username"])
					elif msg_type == "bomb_thrown":
						bomb_thrown.emit(data)
					elif msg_type == "bomb_explosion":
						bomb_explosion.emit(data)
	elif state == WebSocketPeer.STATE_CLOSED:
		is_connected = false

func send_join_request():
	var data = {"type": "join", "username": Global.my_username, "character": Global.current_character, "weapon": Global.current_weapon}
	socket.send_text(JSON.stringify(data))

func send_move_data(pos: Vector2, rot: float):
	if is_connected:
		var data = {"type": "move", "x": pos.x, "y": pos.y, "rot": rot}
		socket.send_text(JSON.stringify(data))

func send_shoot_data(pos: Vector2, rot: float):
	if is_connected:
		var data = {"type": "shoot", "x": pos.x, "y": pos.y, "rot": rot}
		socket.send_text(JSON.stringify(data))

func send_hit_data(target_username: String):
	if is_connected:
		var data = {"type": "hit", "target": target_username}
		socket.send_text(JSON.stringify(data))

func send_heal_request():
	if is_connected:
		var data = {"type": "heal", "username": Global.my_username}
		socket.send_text(JSON.stringify(data))

func send_bomb_request(direction: Vector2):
	if is_connected:
		var data = {"type": "bomb", "username": Global.my_username, "dir_x": direction.x, "dir_y": direction.y}
		socket.send_text(JSON.stringify(data))