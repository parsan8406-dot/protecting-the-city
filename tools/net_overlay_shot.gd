extends SceneTree
## اسکرین‌شاتِ حالت‌های پرده/نوارِ «اتصال قطع شد» (net_status_overlay.gd) روی
## پنج نسبتِ صفحه — بدونِ سرور؛ وضعیتِ Network دستی ساخته می‌شود.
##
##   Godot --path . --resolution 1200x540 -s tools/net_overlay_shot.gd -- --server=http://127.0.0.1:8793 --shots=<پوشه>
##
## پنجره از مانیتور بزرگ‌تر نمی‌شود؛ مثلِ game_hud_check هر اندازه با نصفِ
## ابعادش (همان نسبت) امتحان می‌شود.

const SIZES := [Vector2i(2400, 1080), Vector2i(2340, 1080), Vector2i(1920, 1080),
	Vector2i(1280, 720), Vector2i(2048, 1536)]

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


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--shots="):
			_shots = str(a).substr(8)
	await _wait(500)
	var g = root.get_node("/root/Global")
	var net = root.get_node("/root/Network")
	var ov = net.get_node("NetStatusOverlay")
	net.set_process(false)       # وضعیت را خودمان می‌سازیم
	g.offline_mode = false
	net.http_failing = false

	var bg := ColorRect.new()   # پس‌زمینه‌ی روشن تا لبه‌ها دیده شوند
	bg.color = Color(0.35, 0.3, 0.25)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	for sz in SIZES:
		root.size = sz / 2
		await _wait(150)
		var vp: Vector2 = root.get_visible_rect().size
		var tag := "%dx%d" % [sz.x, sz.y]

		# وسطِ مسابقه، در حالِ تلاش
		net.in_match = true
		net.link_down = true
		net.awaiting_rejoin = false
		net.reconnect_attempt = 2
		net.reconnect_grace = 25.0
		net.link_down_since_ms = Time.get_ticks_msec() - 6000
		ov._lost = ""
		ov._refresh()
		await _wait(120)
		_check_panel(ov, vp, tag + " reconnecting")
		await _shot("ov_match_" + tag)

		# مهلت تمام شد
		net.link_down_since_ms = Time.get_ticks_msec() - 30000
		ov._refresh()
		await _wait(120)
		_check_panel(ov, vp, tag + " grace over")
		_ok(tag + " grace over offers the menu", ov._leave.visible and ov._retry.visible)
		await _shot("ov_over_" + tag)

		# سرور گفت جای ما آزاد شد
		ov._lost = "expired"
		ov._refresh()
		await _wait(120)
		_check_panel(ov, vp, tag + " lost")
		_ok(tag + " lost: only the way out", ov._leave.visible and not ov._retry.visible)
		await _shot("ov_lost_" + tag)
		ov._lost = ""

		# منو
		net.in_match = false
		net.link_down_since_ms = Time.get_ticks_msec() - 5000
		net.reconnect_attempt = 3
		ov._refresh()
		await _wait(120)
		var b: Rect2 = ov._banner.get_global_rect()
		_ok(tag + " banner inside the screen", Rect2(Vector2.ZERO, vp).encloses(b), str(b))
		_ok(tag + " banner retry ≥ 48dp", ov._banner_retry.size.y >= 50.0, str(ov._banner_retry.size))
		_ok(tag + " banner is small (top strip)", b.size.y < vp.y * 0.2 and not ov._panel.visible)
		await _shot("ov_menu_" + tag)

		# برگشتی!
		net.link_down = false
		ov._refresh()
		ov._show_toast("برگشتی!", MenuUI.GOLD)
		await _wait(150)
		_ok(tag + " toast inside the screen", Rect2(Vector2.ZERO, vp).encloses(ov._toast.get_global_rect()))
		await _shot("ov_toast_" + tag)

	print("\nRESULT: ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)


func _check_panel(ov, vp: Vector2, tag: String) -> void:
	var p: Rect2 = ov._panel.get_global_rect()
	_ok(tag + ": panel visible and full width", ov._panel.visible and absf(p.size.x - vp.x) < 2.0, str(p))
	_ok(tag + ": panel inside the screen", p.position.y >= 0.0 and p.end.y <= vp.y + 1.0, str(p))
	_ok(tag + ": panel is a strip, not a wall", p.size.y < vp.y * 0.7, str(p.size))
	for btn in [ov._retry, ov._leave]:
		if btn.visible:
			_ok(tag + ": button ≥ 48dp (%s)" % btn.text, btn.size.y >= 50.0 and btn.size.x >= 150.0, str(btn.size))
	var t: Rect2 = ov._title.get_global_rect()
	_ok(tag + ": title on one line inside", t.size.y < 60.0 and t.position.x >= 0.0 and t.end.x <= vp.x, str(t))


func _shot(name: String) -> void:
	if _shots == "":
		return
	await process_frame
	root.get_texture().get_image().save_png(_shots.path_join(name + ".png"))
