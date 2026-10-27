extends SceneTree
## شروعِ بازی بدونِ اینترنت دیگر بازی را نمی‌بندد: صفحه‌ی بارگذاری پیامِ
## صادقانه، دکمه‌ی «تلاش دوباره» و تلاشِ خودکار نشان می‌دهد (C12/E13).
##
## عمداً با سرورِ مرده (هیچ‌کس روی پورتِ ۹ گوش نمی‌دهد):
##   Godot --path . --resolution 1200x540 -s tools/boot_retry_check.gd -- --server=http://127.0.0.1:9 [--shots=<پوشه>]

var bad := 0


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


func _initialize() -> void:
	var shots := ""
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--shots="):
			shots = str(a).substr(8)
	await _wait(400)
	var g = root.get_node("/root/Global")
	var net = root.get_node("/root/Network")
	var ls = root.get_node("/root/LoadingScreen")
	if str(g.SERVER_BASE).find("127.0.0.1") < 0:
		print("⛔ فقط با سرورِ محلی/مرده: -- --server=http://127.0.0.1:9")
		print("\nRESULT: SKIPPED")
		quit(2)
		return

	# همان صفحه‌ی شروعِ بازی (ابزارها صحنه‌ی اصلی را باز نمی‌کنند، پس دستی)
	ls.begin({"boot": 0.4, "player": 2.0, "modes": 1.0, "link": 1.0}, "در حال بارگذاری")
	ls._boot_generation = ls._generation
	ls.complete("boot")

	# دریافتِ دیتای بازیکن به‌خاطرِ شبکه شکست خورد
	g._on_request_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
	await _wait(200)
	_ok("network failure is reported centrally", net.http_failing)
	_ok("boot does not quit the game", not ls._quitting)
	_ok("boot shows «تلاش دوباره»", ls._retry_btn.visible)
	_ok("boot status explains it", "دوباره تلاش می‌کنیم" in ls._status.text, ls._status.text)
	_ok("network overlay stays hidden under the loading screen",
		not net.get_node("NetStatusOverlay")._banner.visible)
	if shots != "":
		root.get_texture().get_image().save_png(shots.path_join("boot_retry.png"))

	# مهلتِ ۲۵ ثانیه‌ای هم دیگر یعنی «بستن» نیست
	ls._elapsed = ls.TIMEOUT_SEC + 1.0
	await _wait(200)
	_ok("boot timeout does not quit either", not ls._quitting and ls._retry_btn.visible)

	# تلاشِ خودکار: Network دوباره fetch_player_data را صدا می‌زند
	var before: int = net._http_retries.size()
	_ok("automatic retry is scheduled", before >= 1 and net._http_retry_at_ms > 0)
	ls._on_boot_retry_pressed()
	await _wait(200)
	_ok("manual retry fires the queued request now", net._http_retries.size() == 0, str(net._http_retries.size()))

	# شبکه برگشت
	g.player_data_loaded.emit()
	await _wait(200)
	_ok("success hides the retry button", not ls._retry_btn.visible)

	print("\nRESULT: ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)
