class_name AchievementsDialog
extends RefCounted
## پنجره‌ی «همه‌ی دستاوردها» (پروفایل → دستاوردها → همه).
##
## کل کاتالوگ با پیشرفت هر دستاورد از همان پاسخ GET /profile می‌آید
## (achievement_catalog)، پس درخواست اضافه‌ای نمی‌رود. ردیف‌ها ورودی نمی‌گیرند
## تا ScrollContainer خودش با کشیدن انگشت اسکرول کند.
##
## ترتیب (C14 موقعیتِ سریالی / E7 زیگارنیک / C9 شیبِ هدف):
##   ۱. تازه باز شده      دستاوردی که از آخرین باز کردنِ این پنجره باز شده —
##                         برچسبِ «جدید!» و یک کنفتیِ کوتاه (E17)
##   ۲. نزدیک به باز شدن  ناتمام‌ها، بیشترین درصد اول؛ نزدیک‌ها نوارِ طلایی
##                         و «فقط X مونده!»
##   ۳. باز شده           قدیمی‌ها در انتها، جدیدترین اول
## «دیده‌شده»ها فقط روی همین دستگاه (user://) نگه داشته می‌شوند و نمایشی‌اند.

const PsychProgress := preload("res://scripts/psych_results_progress.gd")
const CONFETTI := preload("res://scripts/psych_results_confetti.gd")
const SAVE_PATH := "user://psych_results.cfg"

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

	var seen := _load_seen()
	# بارِ اولِ باز کردنِ پنجره، همه‌ی قبلی‌ها «دیده‌شده» حساب می‌شوند
	var first_time := not _has_seen_key()
	var fresh: Array = []
	var open_items: Array = []
	var done_items: Array = []
	var all_unlocked: Array = []
	for item in catalog:
		if not (item is Dictionary):
			continue
		var id := str(item.get("achievement_id", ""))
		if bool(item.get("unlocked", false)):
			all_unlocked.append(id)
			if not first_time and not seen.has(id):
				fresh.append(item)
			else:
				done_items.append(item)
		else:
			open_items.append(item)
	open_items.sort_custom(func(a, b) -> bool: return _ratio(a) > _ratio(b))
	var by_new := func(a, b) -> bool: return str(a.get("unlocked_at", "")) > str(b.get("unlocked_at", ""))
	fresh.sort_custom(by_new)
	done_items.sort_custom(by_new)

	if not fresh.is_empty():
		list.add_child(_section("تازه باز شده"))
		for item in fresh:
			list.add_child(_row(item, true))
	if not open_items.is_empty():
		list.add_child(_section("نزدیک به باز شدن"))
		for item in open_items:
			list.add_child(_row(item, false))
	if not done_items.is_empty():
		list.add_child(_section("باز شده"))
		for item in done_items:
			list.add_child(_row(item, false))
	if catalog.is_empty():
		list.add_child(MenuUI.label("فهرست دستاوردها از سرور نیامد", 17, MenuUI.MUTED))
	sheet.open()

	if not catalog.is_empty():
		_save_seen(all_unlocked)
	if not fresh.is_empty():
		_celebrate(sheet)

static func _ratio(item: Dictionary) -> float:
	var target := maxi(1, int(item.get("target", 1)))
	return float(int(item.get("progress", 0))) / float(target)

## عنوانِ کوچکِ هر بخش
static func _section(text: String) -> Control:
	var l := MenuUI.label(text, 15, MenuUI.GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l

## E17 جشنِ کوتاه برای دستاوردِ تازه — یک بار، همان لحظه‌ی باز شدن
static func _celebrate(sheet: Control) -> void:
	var t := sheet.get_tree().create_timer(0.35)
	t.timeout.connect(func() -> void:
		if not is_instance_valid(sheet):
			return
		var c := CONFETTI.new()
		c.z_index = 60
		sheet.add_child(c)
		var vp := sheet.get_viewport_rect().size
		c.burst(Vector2(vp.x * 0.5, vp.y * 0.12), minf(vp.x * 0.5, 620.0))
		LocalSettings.vibrate(40))

static func _section_key() -> String:
	return "u_" + str(Global.my_username)

static func _has_seen_key() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return false
	return cfg.has_section_key(_section_key(), "ach_seen")

static func _load_seen() -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return []
	var v = cfg.get_value(_section_key(), "ach_seen", [])
	return v if v is Array else []

static func _save_seen(ids: Array) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value(_section_key(), "ach_seen", ids)
	cfg.save(SAVE_PATH)

static func _row(item: Dictionary, fresh: bool) -> Control:
	var done := bool(item.get("unlocked", false))
	var target := maxi(1, int(item.get("target", 1)))
	var progress := clampi(int(item.get("progress", 0)), 0, target)
	var near := not done and PsychProgress.is_near(progress, target)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border: Color = MenuUI.GOLD if fresh else (MenuUI.GOLD_DEEP if done or near else Color(0.3, 0.3, 0.33, 0.6))
	var style := MenuUI.box(Color(0.15, 0.11, 0.03, 0.9) if done else Color(0.11, 0.11, 0.12, 0.95),
		border, 2 if fresh or near else 1, 6)
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
		chip.add_child(MenuUI.label(MenuUI.fa_grouped(amount), 16,
			MenuUI.GOLD if not done or fresh else MenuUI.MUTED, true))
		chip.add_child(MenuUI.icon(MissionArt.texture_for(key[1]), 20))
		reward.add_child(chip)
	if fresh:
		# جایزه‌ی دستاورد به صندوقِ پیام‌ها می‌رود — همین را بگوییم
		var note := MenuUI.label("در پیام‌ها", 12, MenuUI.MUTED)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward.add_child(note)
	row.add_child(reward)

	# متن و پیشرفت
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 3)
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.alignment = BoxContainer.ALIGNMENT_END
	title_row.add_theme_constant_override("separation", 8)
	if fresh:
		title_row.add_child(_new_tag())
	var title := MenuUI.label(str(item.get("name", "—")) + ("  ✓" if done else ""), 19,
		MenuUI.GOLD if done or near else MenuUI.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(title)
	texts.add_child(title_row)
	var is_time := str(item.get("metric", "")) == "playtime_seconds"
	var desc_text := str(item.get("description", ""))
	# C9 نزدیکِ پایان: «فقط ۴ تا مونده!» (برای ساعتِ بازی همان توضیح می‌ماند)
	var near_text := near and not is_time
	if near_text:
		desc_text = PsychProgress.remaining_text(progress, target)
	var desc := MenuUI.label(desc_text, 14, MenuUI.GOLD if near_text else MenuUI.MUTED)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	texts.add_child(desc)

	var progress_row := HBoxContainer.new()
	progress_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_row.add_theme_constant_override("separation", 8)
	var numbers := MenuUI.label("%s / %s%s" % [
		MenuUI.fa_grouped(int(progress / 3600.0) if is_time else progress),
		MenuUI.fa_grouped(int(target / 3600.0) if is_time else target),
		" ساعت" if is_time else ""], 14, MenuUI.GOLD if near else MenuUI.MUTED, true)
	progress_row.add_child(numbers)
	var bar := MenuUI.progress_bar(MenuUI.GOLD if done else MenuUI.RED, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = float(target)
	# C9 پیشرفتِ اهدایی: نوارِ ناتمام هیچ‌وقت کاملاً خالی دیده نمی‌شود
	bar.value = float(target) if done else PsychProgress.bar_value(bar, progress, target)
	progress_row.add_child(bar)
	texts.add_child(progress_row)
	row.add_child(texts)
	if near:
		PsychProgress.emphasize_bar(bar, true)

	# آیکن متریک
	var icon_box := PanelContainer.new()
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.custom_minimum_size = Vector2(58, 58)
	icon_box.add_theme_stylebox_override("panel", MenuUI.box(Color(0.08, 0.08, 0.09),
		MenuUI.GOLD if done or near else Color(0.3, 0.3, 0.33), 2, 29))
	icon_box.add_child(MenuUI.icon(MenuUI.metric_icon(str(item.get("metric", ""))), 34,
		MenuUI.GOLD if done or near else Color(0.45, 0.45, 0.5)))
	row.add_child(icon_box)
	return panel

## برچسبِ طلاییِ «جدید!»
static func _new_tag() -> Control:
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := MenuUI.box(MenuUI.GOLD, MenuUI.GOLD, 0, 6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	tag.add_theme_stylebox_override("panel", sb)
	tag.add_child(MenuUI.label("جدید!", 13, Color(0.12, 0.08, 0.02)))
	return tag
