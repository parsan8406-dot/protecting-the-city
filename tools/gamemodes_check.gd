extends SceneTree
## منوی حالت‌های بازی: خواندن از سرور، قفلِ کاپ، انتخاب و اثرش روی منوی اصلی.

var bad := 0
func _ok(n: String, c: bool, d: String = "") -> void:
	if c: print("  PASS  ", n)
	else:
		bad += 1
		print("  FAIL  ", n, "  ", d)

## نشان هرجای درختِ کارت باشد پیدایش می‌کند — تست نباید به چیدمانِ دقیق
## وابسته باشد، وگرنه با هر تغییرِ ظاهری می‌شکند.
func _find_icon(n: Node) -> bool:
	if n is TextureRect and n.texture != null:
		return true
	for c in n.get_children():
		if _find_icon(c):
			return true
	return false


func _wait(ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame

func _initialize() -> void:
	var screen = load("res://secense/game_modes.tscn").instantiate()
	root.add_child(screen)
	await _wait(1200)
	var g = root.get_node("/root/Global")

	# صبر تا پاسخ سرور
	for i in range(150):
		if not screen._modes.is_empty():
			break
		await _wait(100)

	_ok("modes arrive from the server", screen._modes.size() == 4,
		"got %d" % screen._modes.size())
	if screen._modes.is_empty():
		print("\nRESULT: FAIL"); quit(1); return

	var ids := []
	for m in screen._modes:
		ids.append(str(m.get("mode_id", "")))
	_ok("all four operations are present",
		ids.has("strike") and ids.has("revenge") and ids.has("banish") and ids.has("citypoint"),
		str(ids))

	var by_id := {}
	for m in screen._modes:
		by_id[str(m.get("mode_id", ""))] = m
	_ok("team sizes match the design",
		int(by_id["strike"]["team_size"]) == 4
		and int(by_id["revenge"]["team_size"]) == 1  # انتقام ۱ در ۱ است (game_modes.go)
		and int(by_id["banish"]["team_size"]) == 3
		and int(by_id["citypoint"]["team_size"]) == 3)
	_ok("every mode carries a win reward and a loss penalty",
		by_id.values().all(func(m):
			return int(m["win_trophies"]) > 0 and int(m["lose_trophies"]) > 0))

	# کارت‌ها ساخته شده‌اند؟
	_ok("a card is drawn for each mode", screen._list.get_child_count() == 4,
		"cards=%d" % screen._list.get_child_count())

	# --- نشانِ هر عملیات ---
	var with_icon := 0
	for card in screen._list.get_children():
		if _find_icon(card):
			with_icon += 1
	_ok("every mode card draws its own emblem", with_icon == 4,
		"cards with an icon: %d/4" % with_icon)

	# --- قفل ---
	# کاپِ اکانت تست معمولاً صفر است، پس حالت‌های دروازه‌دار باید قفل باشند.
	# کارت دیگر دکمه‌ی جدا ندارد — کلِ کارت هدفِ لمس است — پس وضعیتِ قفل را
	# از خودِ کارت می‌پرسیم.
	print("    [dbg] trophies=%d selected=%s" % [screen._trophies, screen._selected])
	if screen._trophies < 80:
		var card = screen._list.get_child(2)      # حذف شیطان، دروازه ۸۰
		_ok("a gated mode is locked when trophies are short",
			card.locked,
			"card not locked at %d trophies" % screen._trophies)

	# --- انتخاب ---
	# «ضربت» همیشه باز است
	var before := str(g.selected_mode)
	screen._choose("strike")
	for i in range(80):
		if g.selected_mode == "strike":
			break
		await _wait(100)
	_ok("choosing an unlocked mode is saved", g.selected_mode == "strike",
		"selected=%s (was %s)" % [g.selected_mode, before])
	_ok("mode name cached for the main menu", g.selected_mode_name == "عملیات ضربت",
		g.selected_mode_name)

	# سرور هم باید ذخیره کرده باشد. چون POSTِ انتخاب ممکن است هنوز در راه
	# باشد، تا چند بار می‌پرسیم به‌جای یک نمونه‌ی لحظه‌ای.
	var saved := ""
	for attempt in range(20):
		await _wait(300)
		var got := {}
		var http := HTTPRequest.new()
		root.add_child(http)
		http.request_completed.connect(func(_r, code, _h, body):
			got["code"] = code
			got["data"] = JSON.parse_string(body.get_string_from_utf8()))
		# مثلِ خودِ بازی با توکنِ دستگاه — authGuard حسابِ دارای نشست را بدون آن رد می‌کند
		http.request("%s/game_modes?username=%s" % [g.SERVER_BASE, g.my_username.uri_encode()], g.auth_headers())
		for i in range(60):
			if got.has("code"):
				break
			await _wait(60)
		http.queue_free()
		if got.get("code", 0) == 200:
			saved = str(got.get("data", {}).get("selected_mode", ""))
			if saved == "strike":
				break
	_ok("the server persisted the choice", saved == "strike",
		"server says '%s'" % saved)

	# --- منوی اصلی باید همان را نشان بدهد ---
	screen.queue_free()
	await _wait(300)
	var menu = load("res://secense/main_menu.tscn").instantiate()
	root.add_child(menu)
	await _wait(1600)
	var title = menu.get_node_or_null("TypeButton/VBoxContainer/TitleLabel")
	var sub = menu.get_node_or_null("TypeButton/VBoxContainer/TypeLabel")
	_ok("main menu shows the chosen operation", title != null and title.text == "عملیات ضربت",
		title.text if title else "no label")
	_ok("main menu shows its team size", sub != null and sub.text == "۴ در ۴",
		sub.text if sub else "no label")
	_ok("the mode button opens the modes screen",
		menu.get_node("TypeButton").pressed.get_connections().size() > 0)

	print("\nRESULT: ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)
