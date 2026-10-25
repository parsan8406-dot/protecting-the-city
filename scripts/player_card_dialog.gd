class_name PlayerCardDialog
extends RefCounted
## کارت پروفایل یک بازیکن دیگر (تب دوستان → «پروفایل»).
##
## GET /profile?player_id=... — فقط بخش عمومی پروفایل: رنک، آمار، دستاورد،
## آخرین سلاح، شهر و وضعیت آنلاین.
##
## استفاده: PlayerCardDialog.open(self, player_id, on_message_callable)

static func open(host: Node, player_id: String, on_message: Callable = Callable()) -> void:
	var sheet := MenuUI.ModalSheet.new()
	host.get_tree().root.add_child(sheet)
	var col := sheet.build("پروفایل بازیکن", 640.0)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.custom_minimum_size = Vector2(0, 260)
	col.add_child(body)

	var loading := MenuUI.label("در حال گرفتن پروفایل...", 18, MenuUI.MUTED)
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(loading)

	var http := HTTPRequest.new()
	http.timeout = 12.0
	sheet.add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, raw: PackedByteArray) -> void:
		if not is_instance_valid(body):
			return
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			loading.text = MenuUI.server_error(raw, code if result == HTTPRequest.RESULT_SUCCESS else 0, "پروفایل پیدا نشد")
			return
		loading.queue_free()
		_fill(body, MenuUI.parse_json(raw), sheet, on_message))
	var url := "%s/profile?player_id=%s" % [Global.SERVER_BASE, player_id.uri_encode()]
	if http.request(url, Global.auth_headers()) != OK:
		loading.text = "اتصال به سرور برقرار نشد"
	sheet.open()

static func _fill(body: VBoxContainer, data: Dictionary, sheet: MenuUI.ModalSheet, on_message: Callable) -> void:
	# --- سربرگ: آواتار، اسم، سطح، وضعیت ---
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	body.add_child(head)

	var rank: Dictionary = data.get("rank", {}) if data.get("rank") is Dictionary else {}
	var badge := MenuUI.icon(RankArt.texture_for(str(rank.get("tier_id", "")), str(rank.get("tier_name", ""))), 64)
	head.add_child(badge)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	head.add_child(info)
	var name_label := MenuUI.label(str(data.get("username", "—")), 24)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(name_label)
	var online := bool(data.get("is_online", false))
	var sub := MenuUI.label("سطح %s  •  %s" % [MenuUI.fa(int(data.get("level", 1))),
		MenuUI.last_seen_text(online, str(data.get("last_seen_at", "")))], 16,
		MenuUI.GREEN if online else MenuUI.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(sub)
	var tier_line := MenuUI.label("%s  •  %s کاپ" % [str(rank.get("tier_name", "—")),
		MenuUI.fa_grouped(int(data.get("trophies", 0)))], 16, MenuUI.GOLD)
	tier_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(tier_line)

	var avatar_box := PanelContainer.new()
	avatar_box.custom_minimum_size = Vector2(84, 84)
	avatar_box.add_theme_stylebox_override("panel", MenuUI.box(Color(0.13, 0.13, 0.14), MenuUI.GOLD_DEEP, 2, 6))
	var avatar := TextureRect.new()
	avatar.texture = MenuUI.avatar_texture(str(data.get("avatar_id", "")))
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar_box.add_child(avatar)
	head.add_child(avatar_box)

	# --- آمار ---
	var stats: Dictionary = data.get("stats", {}) if data.get("stats") is Dictionary else {}
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	var cells := [
		["کل بازی‌ها", MenuUI.fa_grouped(int(stats.get("total_matches", 0))), "total_matches"],
		["درصد برد", "%s٪" % MenuUI.fa(int(stats.get("win_rate", 0))), "wins"],
		["نسبت K/D", MenuUI.kd_text(float(stats.get("kd_ratio", 0.0))), "kills"],
		["قربانیان", MenuUI.fa_grouped(int(stats.get("kills", 0))), "kills"],
		["دستاوردها", "%s / %s" % [MenuUI.fa(int(data.get("achievements_unlocked", 0))),
			MenuUI.fa(int(data.get("achievements_total", 0)))], "achievement"],
		["ساعت بازی", MenuUI.fa(int(stats.get("playtime_hours", 0))), "playtime_seconds"],
	]
	for cell in cells:
		grid.add_child(_stat_cell(cell[0], cell[1], cell[2]))

	# --- آخرین سلاح و شهر ---
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	body.add_child(foot)
	var weapon_id := str(stats.get("last_used_weapon", data.get("equipped_weapon", "")))
	var weapon_tex := MenuUI.weapon_texture(weapon_id)
	if weapon_tex != null:
		var w := MenuUI.icon(weapon_tex, 54)
		w.custom_minimum_size = Vector2(120, 54)
		foot.add_child(w)
	var clan_text := "بدون شهر"
	if data.get("clan") is Dictionary:
		clan_text = "شهر : " + str((data["clan"] as Dictionary).get("name", "—"))
	var foot_label := MenuUI.label("آخرین سلاح : %s\n%s" % [MenuUI.weapon_name(weapon_id) if not weapon_id.is_empty() else "—", clan_text], 16, MenuUI.MUTED)
	foot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.add_child(foot_label)

	if on_message.is_valid():
		var msg := MenuUI.button("پیام دادن", "gold")
		msg.pressed.connect(func() -> void:
			sheet.close()
			on_message.call())
		body.add_child(msg)

static func _stat_cell(title: String, value: String, metric: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := MenuUI.box(Color(0.12, 0.12, 0.13, 1.0), Color(0.3, 0.3, 0.33, 0.6), 1, 6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	var v := MenuUI.label(value, 20, MenuUI.TEXT, true)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var t := MenuUI.label(title, 13, MenuUI.MUTED)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	texts.add_child(v)
	texts.add_child(t)
	row.add_child(texts)
	row.add_child(MenuUI.icon(MenuUI.metric_icon(metric), 28, Color(0.72, 0.72, 0.75)))
	return panel
