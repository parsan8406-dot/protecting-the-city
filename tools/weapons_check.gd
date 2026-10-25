extends SceneTree
## هر اسلحه‌ای که در فروشگاه هست باید اسپرایتِ درون‌بازی هم داشته باشد.
##
## یک بار فایل‌های assets/player_weapons/ بدون .import کنار پروژه افتاده بودند؛
## گودوت واردشان نکرده بود، پس ResourceLoader.exists برای همه false می‌شد و
## هیچ‌کس تفنگ در دستش دیده نمی‌شد. این تست دقیقاً همان را می‌گیرد.

func _initialize() -> void:
	var bad := 0
	var fallback: Array[String] = []

	var ids: Array[String] = []
	var d := DirAccess.open("res://assets/items")
	if d != null:
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if f.ends_with(".png") and not f.begins_with("skin_"):
				ids.append(f.get_basename())
			f = d.get_next()

	print("weapons found in assets/items: ", ids.size())
	for id in ids:
		var tex := WeaponSkin.get_texture(id)
		if tex == null:
			print("  FAIL  %s -> no usable sprite at all" % id)
			bad += 1
			continue
		if not WeaponSkin.has_weapon(id):
			fallback.append(id)
			continue
		# باید روی یک نود واقعی هم بنشیند
		var s := Sprite2D.new()
		root.add_child(s)
		if not WeaponSkin.apply(s, id):
			print("  FAIL  %s -> WeaponSkin.apply refused it" % id)
			bad += 1
		elif s.texture == null:
			print("  FAIL  %s -> applied but texture stayed null" % id)
			bad += 1
		else:
			print("  PASS  %s -> %s" % [id, s.texture.resource_path.get_file()])
		s.queue_free()

	if not fallback.is_empty():
		print("  NOTE  no own sprite, falls back to ak47: ", fallback)

	print("\nRESULT: ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(0 if bad == 0 else 1)
