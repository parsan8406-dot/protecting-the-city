extends SceneTree
## اتصالِ دوباره وسطِ مسابقه — کلاینتِ واقعی روبه‌روی سرورِ واقعی.
##
## ⚠️ اکانت می‌سازد و وارد صفِ مسابقه می‌شود، پس **فقط روی سرورِ محلی**:
##   Godot --path . --resolution 1200x540 -s tools/reconnect_check.gd -- --server=http://127.0.0.1:8793
##
## مراحل:
##   ۱. ورود به یک مسابقه‌ی واقعیِ «ضربت» (صف → پر شدن با بات → World.tscn)
##   ۲. قطعِ شبکه (آدرسِ سرور به پورتِ مرده): کنترل‌ها یخ، پرده با «تلاش N»،
##      تلاش‌ها تکرار می‌شوند؛ با برگشتِ شبکه و «تلاش دوباره» همان مسابقه
##      با همان تیم و جان برمی‌گردد و «برگشتی!»
##   ۳. برگشت از پس‌زمینه بعد از ۹ ثانیه: سوکت همان لحظه از نو + rejoin
##   ۴. قطعیِ طولانی‌تر از مهلت: پیامِ صادقانه و «بازگشت به منو»
##   ۵. منو: نوارِ کوچکِ «اتصال قطع شد» و خطای HTTP با تلاشِ خودکار
## --shots=<پوشه> اسکرین‌شاتِ هر حالت را آن‌جا ذخیره می‌کند.

var bad := 0
var _shots := ""


func _ok(n: String, c: bool, d: String = "") -> void:
	if c:
		print("  PASS  ", n)
	else:
		bad += 1
		print("  FAIL  ", n, "  ", d)


func _wait(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame


func _until(cond: Callable, ms: int) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _shot(name: String) -> void:
	if _shots == "":
		return
	await process_frame
	root.get_texture().get_image().save_png(_shots.path_join(name + ".png"))


func _call(method: int, path: String, payload := "", token := "") -> Dictionary:
	var http := HTTPRequest.new()
	root.add_child(http)
	var got := {}
	http.request_completed.connect(func(_r, code, _h, body):
		got["code"] = code
		got["data"] = JSON.parse_string(body.get_string_from_utf8()))
	var base: String = root.get_node("/root/Global").SERVER_BASE
	var headers := PackedStringArray(["Content-Type: application/json"])
	if token != "":
		headers.append("Authorization: Bearer " + token)
	if method == HTTPClient.METHOD_POST:
		http.request(base + path, headers, method, payload)
	else:
		http.request(base + path, headers)
	await _until(func() -> bool: return got.has("code"), 8000)
	http.queue_free()
	return got


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--shots="):
			_shots = str(a).substr(8)
	await _wait(600)
	var g = root.get_node("/root/Global")
	var net = root.get_node("/root/Network")
	if g.is_production_server() or (str(g.SERVER_BASE).find("127.0.0.1") < 0 and str(g.SERVER_BASE).find("localhost") < 0):
		print("⛔ فقط روی سرورِ محلی: -- --server=http://127.0.0.1:8793")
		print("\nRESULT: SKIPPED")
		quit(2)
		return
	var base: String = g.SERVER_BASE
	var overlay = net.get_node_or_null("NetStatusOverlay")
	_ok("status overlay is built once under Network", overlay != null)

	# --- ۱. یک مسابقه‌ی واقعی ---
	# اول بگذار بارگذاریِ خودکارِ اکانتِ پیش‌فرض تمام شود، بعد اکانتِ تستی
	await _until(func() -> bool: return g._player_loaded_once, 8000)
	var mine := "rcg%d" % (randi() % 90000 + 10000)
	g.my_username = mine
	var me := await _call(HTTPClient.METHOD_GET, "/get_player?username=" + mine)
	if typeof(me.get("data")) == TYPE_DICTIONARY:
		g.session_token = str(me["data"].get("session_token", ""))
	net.reset_connection()
	g.fetch_player_data()
	_ok("socket connects as the test account", await _until(
		func() -> bool: return net.is_connected and g.my_username == mine, 15000), g.my_username)
	var joined := await _call(HTTPClient.METHOD_POST, "/matchmaking/join",
		JSON.stringify({"username": g.my_username, "mode_id": "strike"}), g.session_token)
	_ok("queued", joined.get("code", 0) == 200, str(joined))
	print("  … waiting for bots to fill the match (~20s)")
	var found := {}
	for i in range(45):
		var st := await _call(HTTPClient.METHOD_GET, "/matchmaking/status?username=" + g.my_username, "", g.session_token)
		var d = st.get("data")
		if typeof(d) == TYPE_DICTIONARY and str(d.get("state", "")) == "ready":
			found = d.get("match", {})
			break
		await _wait(1000)
	_ok("matched", not found.is_empty())
	if found.is_empty():
		_finish()
		return
	g.current_match = found
	for p in found.get("players", []):
		if str(p.get("username", "")) == g.my_username:
			g.my_team = str(p.get("team", ""))

	var world = load("res://secense/World.tscn").instantiate()
	root.add_child(world)
	_ok("arena joined (server spawn)", await _until(func() -> bool: return world.server_spawn != null, 10000))
	await _until(func() -> bool: return net.current_players.has(g.my_username), 5000)
	await _wait(2500)
	_ok("in_match is set", net.in_match)
	var before: Dictionary = net.current_players.get(g.my_username, {})
	var team_before := str(before.get("team", ""))
	var hp_before := int(before.get("health", -1))
	print("  me: team=%s hp=%d" % [team_before, hp_before])

	# --- ۲. شبکه قطع می‌شود ---
	g.SERVER_BASE = "http://127.0.0.1:9"     # هیچ‌کس گوش نمی‌دهد
	net._force_reconnect()                    # همان کاری که نگهبانِ پینگ می‌کند
	await _wait(50)
	_ok("link_down right away", net.link_down)
	_ok("controls freeze", world._net_frozen and not world.joystick.enabled
		and not world.get_node("Player").is_physics_processing())
	await _wait(1200)
	_ok("in-match overlay is shown", overlay._panel.visible and overlay._blocker.visible)
	_ok("overlay says reconnecting", "اتصال قطع شد" in overlay._title.text, overlay._title.text)
	_ok("countdown shown (C12)", overlay._sub_row.visible and overlay._secs.text != "" and int(net.grace_left()) > 15,
		"left=%.1f" % net.grace_left())
	await _until(func() -> bool: return net.reconnect_attempt >= 2, 6000)
	_ok("retries repeat with backoff (attempt ≥ 2)", net.reconnect_attempt >= 2,
		"attempt=%d" % net.reconnect_attempt)
	overlay._refresh()   # پرده هر ۰.۱ ثانیه تازه می‌شود؛ همین حالا بخوانش
	_ok("attempt number on screen", overlay._attempt_box.visible
		and overlay._attempt_num.text == MenuUI.fa(net.reconnect_attempt))
	await _shot("rc_overlay_match")

	g.SERVER_BASE = base                       # شبکه برگشت
	var res := {}
	var on_res := func(ok_: bool, reason: String) -> void:
		res["ok"] = ok_
		res["reason"] = reason
	net.rejoin_result.connect(on_res)
	overlay._on_retry_pressed()                # دکمه‌ی «تلاش دوباره»
	_ok("rejoin answered", await _until(func() -> bool: return res.has("ok"), 6000))
	_ok("rejoin ok (same match)", res.get("ok", false) == true, str(res))
	await _wait(400)
	var after: Dictionary = net.current_players.get(g.my_username, {})
	_ok("same team after rejoin", str(after.get("team", "?")) == team_before, str(after.get("team")))
	_ok("same HP after rejoin (invulnerable while away)", int(after.get("health", -2)) == hp_before
		or hp_before <= 0, "%d vs %d" % [int(after.get("health", -2)), hp_before])
	_ok("not marked away anymore", not bool(after.get("away", false)))
	_ok("controls back", not world._net_frozen and world.get_node("Player").is_physics_processing()
		and (world.joystick.enabled or world._spectating))
	_ok("overlay hidden, toast «برگشتی!»", not overlay._panel.visible and overlay._toast.visible
		and overlay._toast_label.text == "برگشتی!")
	_ok("server's remaining grace reached the client", net.reconnect_grace <= 25.0 and net.reconnect_grace > 10.0,
		"grace=%.1f" % net.reconnect_grace)
	await _shot("rc_back_toast")

	# --- ۳. برگشت از پس‌زمینه بعد از ۹ ثانیه ---
	res.clear()
	var sock_before = net.socket
	var now := Time.get_ticks_msec()
	net._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	net._paused_at_ms = now - 9000
	net._last_rx_ms = now - 9000
	net._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	_ok("resume after 9s rebuilds the socket immediately", net.socket != sock_before)
	_ok("rejoin after resume", await _until(func() -> bool: return res.get("ok", false) == true, 6000), str(res))
	await _wait(300)
	_ok("controls back after resume", not world._net_frozen)

	# --- ۴. قطعیِ طولانی‌تر از مهلت ---
	res.clear()
	await _wait(1500)
	g.SERVER_BASE = "http://127.0.0.1:9"
	net._force_reconnect()
	var grace: float = net.reconnect_grace
	print("  … offline for longer than the grace (%.0fs)" % grace)
	await _until(func() -> bool: return net.grace_left() <= 0.0, int(grace * 1000) + 2000)
	await _wait(300)
	_ok("after the countdown: honest text + «بازگشت به منو»", overlay._leave.visible
		and overlay._title.text == "اتصال هنوز برنگشته", overlay._title.text)
	await _shot("rc_grace_over")
	await _wait(2500)                           # سرور هم مطمئناً حذف کرده باشد
	g.SERVER_BASE = base
	overlay._on_retry_pressed()
	_ok("late rejoin answered", await _until(func() -> bool: return res.has("ok"), 8000), str(res))
	_ok("late rejoin refused (expired / match_over)", res.get("ok", true) == false
		and str(res.get("reason", "")) in ["expired", "match_over"], str(res))
	_ok("no longer in a match", not net.in_match)
	if str(res.get("reason", "")) == "expired":
		await _wait(300)
		_ok("lost panel with a way out", overlay._panel.visible and overlay._leave.visible
			and not overlay._retry.visible, overlay._title.text)
		_ok("controls stay frozen", world._net_frozen)
		await _shot("rc_lost")
	world.queue_free()
	overlay._lost = ""
	await _wait(300)
	_ok("leaving the arena clears match state", not net.in_match)

	# --- ۵. منو ---
	g.SERVER_BASE = "http://127.0.0.1:9"
	net._force_reconnect()
	await _wait(300)
	_ok("menu: no banner for a blip (<1.5s)", not overlay._banner.visible)
	await _wait(1600)
	_ok("menu: small banner, no full panel", overlay._banner.visible and not overlay._panel.visible
		and not overlay._blocker.visible)
	await _shot("rc_menu_banner")
	g.SERVER_BASE = base
	overlay._on_retry_pressed()
	_ok("menu: banner clears when the link is back",
		await _until(func() -> bool: return not net.link_down and not overlay._banner.visible, 6000))

	var calls := [0]
	var retry := func() -> void: calls[0] += 1
	net.report_http_failure(retry)
	await _wait(300)
	_ok("http failure shows the banner", overlay._banner.visible)
	_ok("http failure retried automatically", await _until(func() -> bool: return calls[0] >= 1, 5000))
	net.report_http_ok()
	await _wait(300)
	_ok("http success clears the banner", not overlay._banner.visible)

	g.offline_mode = true
	net.report_http_failure()
	await _wait(300)
	_ok("offline quick play never shows network UI", not overlay._banner.visible and not overlay._panel.visible)
	g.offline_mode = false
	net.report_http_ok()
	_finish()


func _finish() -> void:
	print("\nRESULT: ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)
