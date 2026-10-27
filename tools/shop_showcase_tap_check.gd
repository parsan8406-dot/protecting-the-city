extends SceneTree
## کارت‌های ویترینِ «ویژه» با لمس باید پنجره‌ی پیش‌نمایش را باز کنند — حتی
## وقتی آیتم در کاتالوگِ اسلحه/کاراکتر هم هست (section=weapons/characters).
## قبلاً لمسِ این کارت‌ها پنلِ تبِ اسلحه/کاراکتر را عوض می‌کرد و در تبِ ویژه
## هیچ چیزی دیده نمی‌شد.
##
## فقط روی سرورِ محلی:
##   Godot --path . --resolution 1200x540 -s tools/shop_showcase_tap_check.gd -- --server=http://127.0.0.1:8791

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


func _sheets() -> Array:
	var out := []
	for n in root.get_children():
		if n is CanvasLayer or n is Control:
			if n.get_script() != null and str(n.get_script().resource_path).ends_with("menu_ui.gd"):
				out.append(n)
			elif n.get_class() == "CanvasLayer" and n.has_signal("dismissed"):
				out.append(n)
	return out


func _initialize() -> void:
	await _wait(600)
	var shop: Node = load("res://secense/shop.tscn").instantiate()
	# دادهٔ سرور نباید وسطِ تست جای دادهٔ ساختگی را بگیرد
	shop.set("SHOP_URL", "http://127.0.0.1:9/none")
	root.add_child(shop)
	await _wait(500)

	var items := [
		# همان آیتم هم در کاتالوگِ اسلحه‌ها و هم در ویترینِ «ویژه»
		{"item_id": "awm", "name": "AWM", "category": "weapon", "section": "weapons",
			"featured_section": "weekly", "rarity": "epic", "cost_type": "coins",
			"original_price": 9000, "final_price": 9000},
		{"item_id": "skin_fire", "name": "آتش", "category": "character", "section": "characters",
			"featured_section": "weekly", "rarity": "legendary", "cost_type": "gems",
			"original_price": 300, "final_price": 300},
		# آیتمِ فقط-ویترین (section خالی) — قبلاً هم کار می‌کرد
		{"item_id": "skin_girl", "name": "دختر", "category": "character", "section": "",
			"featured_section": "weekly", "rarity": "epic", "cost_type": "gems",
			"original_price": 200, "final_price": 200},
	]
	shop.render_shop_sections(items)
	await _wait(400)

	var cards: Array = shop.weekly_container.get_children().filter(
		func(c): return c.has_meta("shop_item"))
	_ok("three showcase cards rendered", cards.size() == 3, "count=%d" % cards.size())
	for card in cards:
		var item: Dictionary = card.get_meta("shop_item")
		var before := root.get_child_count()
		card.card_clicked.emit(item)
		await _wait(450)
		var opened := root.get_child_count() > before
		_ok("tap opens the preview for %s (section=%s)" % [item["item_id"], item["section"]], opened,
			"root children %d -> %d" % [before, root.get_child_count()])
		# بستن با cancel تا کارتِ بعدی آزاد باشد
		for n in root.get_children().slice(before):
			if n.has_signal("dismissed"):
				n.emit_signal("dismissed")
		await _wait(400)
		_ok("preview releases its lock after closing (%s)" % item["item_id"], not shop._confirm_open)

	print("\nRESULT: ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)
