class_name AchievementsDialog
extends RefCounted
## پنجره‌ی «همه‌ی دستاوردها» (پروفایل → دستاوردها → همه).
##
## کل کاتالوگ با پیشرفت هر دستاورد از همان پاسخ GET /profile می‌آید
## (achievement_catalog)، پس درخواست اضافه‌ای نمی‌رود. ردیف‌ها ورودی نمی‌گیرند
## تا ScrollContainer خودش با کشیدن انگشت اسکرول کند.

static func open(host: Node, catalog: Array) -> void:
	var unlocked := 0
	for item in catalog:
		if item is Dictionary and bool(item.get("unlocked", false)):
			unlocked += 1

	var sheet := MenuUI.ModalSheet.new()
	host.get_tree().root.add_child(sheet)
	var col := sheet.build("دستاوردها  •  %s از %s" % [MenuUI.fa(unlocked), MenuUI.fa(catalog.size())], 700.0)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var view_h := host.get_viewport().get_visible_rect().size.y
	scroll.custom_minimum_size = Vector2(0, clampf(view_h - 200.0, 220.0, 520.0))
	col.add_child(scroll)
	UIScroll.attach(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	# باز شده‌ها اول (جدیدترین)، بعد نزدیک‌ترین‌ها به باز شدن
	var sorted := catalog.duplicate()
	sorted.sort_custom(func(a, b) -> bool:
		var ua := bool(a.get("unlocked", false))
		var ub := bool(b.get("unlocked", false))
		if ua != ub:
			return ua
		if ua:
			return str(a.get("unlocked_at", "")) > str(b.get("unlocked_at", ""))
		return _ratio(a) > _ratio(b))

	for item in sorted:
		if item is Dictionary:
			list.add_child(_row(item))
	if sorted.is_empty():
		list.add_child(MenuUI.label("فهرست دستاوردها از سرور نیامد", 17, MenuUI.MUTED))
	sheet.open()

static func _ratio(item: Dictionary) -> float:
	var target := maxi(1, int(item.get("target", 1)))
	return float(int(item.get("progress", 0))) / float(target)

static func _row(item: Dictionary) -> Control:
	var done := bool(item.get("unlocked", false))
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := MenuUI.box(Color(0.15, 0.11, 0.03, 0.9) if done else Color(0.11, 0.11, 0.12, 0.95),
		MenuUI.GOLD_DEEP if done else Color(0.3, 0.3, 0.33, 0.6), 1, 6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	# جایزه (سمت چپ)
	var reward := VBoxContainer.new()
	reward.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward.custom_minimum_size = Vector2(96, 0)
	reward.alignment = BoxContainer.ALIGNMENT_CENTER
	for key in [["reward_coins", "coin"], ["reward_gems", "gem"]]:
		var amount := int(item.get(key[0], 0))
		if amount <= 0:
			continue
		var chip := HBoxContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_constant_override("separation", 4)
		chip.add_child(MenuUI.label(MenuUI.fa_grouped(amount), 16, MenuUI.GOLD if not done else MenuUI.MUTED, true))
		chip.add_child(MenuUI.icon(MissionArt.texture_for(key[1]), 20))
		reward.add_child(chip)
	row.add_child(reward)

	# متن و پیشرفت
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 3)
	var title := MenuUI.label(str(item.get("name", "—")) + ("  ✓" if done else ""), 19,
		MenuUI.GOLD if done else MenuUI.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	texts.add_child(title)
	var desc := MenuUI.label(str(item.get("description", "")), 14, MenuUI.MUTED)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	texts.add_child(desc)

	var progress_row := HBoxContainer.new()
	progress_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_row.add_theme_constant_override("separation", 8)
	var target := int(item.get("target", 1))
	var progress := int(item.get("progress", 0))
	var is_time := str(item.get("metric", "")) == "playtime_seconds"
	var numbers := MenuUI.label("%s / %s%s" % [
		MenuUI.fa_grouped(int(progress / 3600.0) if is_time else progress),
		MenuUI.fa_grouped(int(target / 3600.0) if is_time else target),
		" ساعت" if is_time else ""], 14, MenuUI.MUTED, true)
	progress_row.add_child(numbers)
	var bar := MenuUI.progress_bar(MenuUI.GOLD if done else MenuUI.RED, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = maxf(1.0, float(target))
	bar.value = float(progress)
	progress_row.add_child(bar)
	texts.add_child(progress_row)
	row.add_child(texts)

	# آیکن متریک
	var icon_box := PanelContainer.new()
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.custom_minimum_size = Vector2(58, 58)
	icon_box.add_theme_stylebox_override("panel", MenuUI.box(Color(0.08, 0.08, 0.09), MenuUI.GOLD if done else Color(0.3, 0.3, 0.33), 2, 29))
	icon_box.add_child(MenuUI.icon(MenuUI.metric_icon(str(item.get("metric", ""))), 34,
		MenuUI.GOLD if done else Color(0.45, 0.45, 0.5)))
	row.add_child(icon_box)
	return panel
