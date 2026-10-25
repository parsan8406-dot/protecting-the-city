extends SceneTree
## صفحه‌ی «در جستجوی حریف» با بازیکن‌های واقعیِ داخل صف.
##
## ⚠️ این تست اکانت می‌سازد و وارد صفِ مسابقه می‌شود، پس **فقط روی سرورِ
## محلی** اجرا می‌شود. روی سرورِ اصلی خودش را متوقف می‌کند — قبلاً اکانت‌های
## «lobbyXXXX_n» روی سرورِ بازیکن‌های واقعی ساخته می‌شدند.
##
##   (سرورِ محلی)  PORT=8791 ./gun_game_server.exe
##   Godot --path . --resolution 1200x540 -s tools/matchmaking_check.gd -- --server=http://127.0.0.1:8791

var bad := 0
func _ok(n: String, c: bool, d: String = "") -> void:
	if c: print("  PASS  ", n)
	else:
		bad += 1
		print("  FAIL  ", n, "  ", d)

func _wait(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame

## توکنِ هر اکانتِ تستی (سرور موقعِ ساختن می‌دهد؛ بدونش صف ردش می‌کند)
var _tokens := {}

## یک درخواستِ ساده و منتظرِ جواب — با توکنِ همان اکانت، مثلِ خودِ بازی
func _call(method: int, path: String, payload := "", as_user := "") -> Dictionary:
	var http := HTTPRequest.new()
	root.add_child(http)
	var got := {}
	http.request_completed.connect(func(_r, code, _h, body):
		got["code"] = code
		got["data"] = JSON.parse_string(body.get_string_from_utf8()))
	var base: String = root.get_node("/root/Global").SERVER_BASE
	var headers := PackedStringArray(["Content-Type: application/json"])
	if _tokens.has(as_user):
		headers.append("Authorization: Bearer " + str(_tokens[as_user]))
	if method == HTTPClient.METHOD_POST:
		http.request(base + path, headers, method, payload)
	else:
		http.request(base + path, headers)
	for i in range(100):
		if got.has("code"):
			break
		await _wait(60)
	http.queue_free()
	return got

## اکانت می‌سازد (get_player برای نامِ تازه اکانتِ مهمان می‌سازد) و وارد صف می‌کند
func _join_as(username: String) -> void:
	var made := await _call(HTTPClient.METHOD_GET, "/get_player?username=" + username)
	var data = made.get("data")
	if typeof(data) == TYPE_DICTIONARY and str(data.get("session_token", "")) != "":
		_tokens[username] = str(data["session_token"])
	var joined := await _call(HTTPClient.METHOD_POST, "/matchmaking/join",
		JSON.stringify({"username": username, "mode_id": "strike"}), username)
	if joined.get("code", 0) != 200:
		print("  (join %s → %s %s)" % [username, joined.get("code"), joined.get("data")])


func _initialize() -> void:
	await _wait(900)
	var g = root.get_node("/root/Global")
	if g.is_production_server():
		print("⛔ این تست اکانت می‌سازد و وارد صف می‌شود؛ روی سرورِ اصلی اجرا نمی‌شود.")
		print("   با سرورِ محلی اجرا کن:  ... -s tools/matchmaking_check.gd -- --server=http://127.0.0.1:8791")
		print("\nRESULT: SKIPPED")
		quit(2)
		return

	var tag := randi() % 9000 + 1000
	var mates := []
	for i in range(3):
		mates.append("lobby%d_%d" % [tag, i])

	# بازیکنِ خودِ ما روی سرورِ محلی تازه است — اکانت و توکن بگیرد
	g.my_username = "lobby%d_me" % tag
	var me := await _call(HTTPClient.METHOD_GET, "/get_player?username=" + g.my_username)
	if typeof(me.get("data")) == TYPE_DICTIONARY:
		g.session_token = str(me["data"].get("session_token", ""))

	# سه نفر از قبل در صف، تا صفحه خالی نباشد
	for n in mates:
		await _join_as(n)

	# حالتِ انتخابی را «ضربت» بگذار تا ۴ در ۴ باشد
	g.selected_mode = "strike"
	g.selected_mode_name = "عملیات ضربت"
	g.selected_mode_subtitle = "۴ در ۴"
	g.selected_mode_data = {
		"mode_id": "strike", "name": "عملیات ضربت", "subtitle": "۴ در ۴",
		"team_size": 4, "accent": "#F0B429",
	}

	var screen = load("res://secense/matchmaking.tscn").instantiate()
	root.add_child(screen)
	await _wait(2500)

	_ok("lobby reads the chosen mode", screen._team_size == 4,
		"team_size=%d" % screen._team_size)
	# اسمِ حالت در یک لیبلِ «حالت: …» نوشته می‌شود (matchmaking.gd، _build)
	var mode_label := ""
	for l in screen.find_children("*", "Label", true, false):
		if "عملیات ضربت" in (l as Label).text:
			mode_label = (l as Label).text
	_ok("lobby shows the mode name", mode_label != "", "no label mentions the mode")
	# لابی حالا یک حلقه از جایگاه‌هاست (_slots)، نه دو ستونِ تیمی
	_ok("a slot is drawn for every seat", screen._slots.size() == 8,
		"slots=%d" % screen._slots.size())
	_ok("the player joined the real queue", screen._state == "searching",
		"state=%s" % screen._state)
	var filled := _filled(screen)
	_ok("players already waiting are shown", filled >= 4, "filled=%d" % filled)
	_ok("progress shows found/needed", screen._found_value.text == "%d/%d" % [filled, 8],
		screen._found_value.text)
	_ok("the search timer runs", screen._elapsed > 1.0, "t=%.1f" % screen._elapsed)

	root.get_texture().get_image().save_png("user://lobby_search.png")

	# --- تکمیل تیم: چهار نفر دیگر ---
	for i in range(4):
		await _join_as("lobby%d_r%d" % [tag, i])
	for i in range(60):
		if screen._state == "ready":
			break
		await _wait(200)

	_ok("the lobby flips to ready once the match fills", screen._state == "ready",
		"state=%s" % screen._state)
	_ok("a full roster arrives", _filled(screen) == 8, "filled=%d" % _filled(screen))
	_ok("the player is on one of the teams",
		g.current_match.get("players", []).any(func(p):
			return str(p.get("username", "")) == g.my_username))
	root.get_texture().get_image().save_png("user://lobby_ready.png")

	print("\nRESULT: ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)


## چند جایگاه یک بازیکنِ واقعی را نشان می‌دهد
func _filled(screen) -> int:
	var n := 0
	for s in screen._slots:
		if str(s.username) != "":
			n += 1
	return n
