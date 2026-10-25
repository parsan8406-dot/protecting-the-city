extends SceneTree
## نگهبانِ «سوکتِ مرده» نباید بعد از یک سکوتِ عادی (منو / صفحه‌ی جستجو)
## اولین پینگِ ورود به آرنا را مرگِ سوکت حساب کند.
##
## قبلاً همین اتفاق می‌افتاد: سکوتِ ۲۰ ثانیه‌ایِ صفِ جستجو + اولین پینگِ HUD
## = اتصالِ دوباره‌ی فوری، سرور بازیکن را از مسابقه بیرون می‌انداخت و زمینِ
## بازی خالی می‌ماند («پاسخ سرور دیر رسید»).
##
## فقط روی سرورِ محلی:
##   Godot --headless --path . -s tools/ping_watchdog_check.gd -- --server=http://127.0.0.1:8791

var bad := 0


func _ok(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  PASS  ", name)
	else:
		bad += 1
		print("  FAIL  ", name, "  ", detail)


func _initialize() -> void:
	await _wait(200)
	var glob = root.get_node("/root/Global")
	if str(glob.SERVER_BASE).find("127.0.0.1") < 0 and str(glob.SERVER_BASE).find("localhost") < 0:
		print("refusing to run against ", glob.SERVER_BASE, " — pass -- --server=http://127.0.0.1:8791")
		quit(2)
		return
	var net = root.get_node("/root/Network")
	# بدونِ صفحه‌ی شروع، دیتای بازیکن خودش بار نمی‌شود (اتصال بعد از آن است)
	glob.fetch_player_data()
	await _wait(1500)
	if not net.is_connected:
		net.connect_to_server()   # فقط خودِ سوکت لازم است، نه حساب
	var t0 := Time.get_ticks_msec()
	while not net.is_connected and Time.get_ticks_msec() - t0 < 15000:
		await process_frame
	_ok("connected to the local server", net.is_connected)
	if not net.is_connected:
		quit(1)
		return

	# سکوتِ طولانی مثلِ صفحه‌ی جستجو — سرور در این مدت روی سوکت چیزی نمی‌فرستد
	await _wait(9000)
	var sock_before = net.socket

	# ورود به آرنا: HUD هر ۲ ثانیه پینگ می‌فرستد
	for i in 3:
		net.send_ping()
		await _wait(700)
	_ok("first arena pings do not rebuild the socket", net.socket == sock_before)
	_ok("still connected", net.is_connected)

	# سوکتِ واقعاً مرده هنوز باید تشخیص داده شود. جوابِ پینگ‌های بالا را
	# می‌گذاریم برسد، بعد وضعیتِ «پینگی رفته و ۸ ثانیه هیچ جوابی نیامده» را
	# مستقیم می‌سازیم (بدونِ فرستادنِ پینگِ واقعی که سرور جوابش را بدهد).
	await _wait(1500)
	var now: int = Time.get_ticks_msec()
	net._last_rx_ms = now - 9000
	net._ping_wait_since = now - 8000
	net._last_ping_ms = now
	await _wait(300)
	_ok("an unanswered ping for >7s still forces a reconnect", net.socket != sock_before)

	print("\nRESULT: ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)


func _wait(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame
