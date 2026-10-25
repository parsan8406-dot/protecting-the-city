extends Node
## عکس‌گرفتن از صفحه‌ی «فروشگاه» با دیتای ساختگی (بدون سرور).
##
##   godot --path . res://tools/shop_shot.tscn --resolution 2400x1080 -- \
##         --out=C:/tmp/shop --tab=0
##
## --tab: 0=ویژه 1=کاراکترها 2=تفنگ‌ها 3=سکه و قلب
## چک می‌کند هیچ عنصری از کادر بیرون نزده و پنل‌های دو ستون روی هم نیفتاده باشند.

const SHOP_SCENE := preload("res://secense/shop.tscn")

var _out := ""
var _tab := 0
var _shop: Control = null
var _frames := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--tab="):
			_tab = a.substr(6).to_int()
	Global.my_username = ""
	Global.coins = 12500
	Global.gems = 340
	_shop = SHOP_SCENE.instantiate()
	# سرور را از دسترس خارج می‌کنیم تا دیتای واقعی وسطِ عکس‌گرفتن جای دیتای
	# ساختگی را نگیرد (وگرنه قیمت‌ها از سرورِ در حال اجرا خوانده می‌شوند)
	_shop.set("SHOP_URL", "http://127.0.0.1:1/get_shop")
	_shop.set("BUY_URL", "http://127.0.0.1:1/buy_item")
	_shop.set("LUCKY_URL", "http://127.0.0.1:1/lucky_box")
	add_child(_shop)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 5:
		_shop.call("render_shop_sections", _fake_items())
		_shop.call("switch_tab", _tab, false)
	elif _frames == 40:
		_report()
		if not _out.is_empty():
			var img := get_viewport().get_texture().get_image()
			print("SHOP saved err=%d" % img.save_png("%s.png" % _out))
		get_tree().quit(0)


func _fake_items() -> Array:
	var items: Array = []
	var rarities := ["rare", "epic", "legend"]
	for i in range(9):
		items.append({
			"item_id": "skin_%d" % i, "name": "کاراکتر %d" % i,
			"category": "character", "section": "characters",
			"rarity": rarities[i % 3], "cost_type": "coins",
			"original_price": 6000, "final_price": 6000, "discount_percent": 0,
			"stats": {"speed": 60, "accuracy": 70, "health": 80},
		})
	for i in range(6):
		items.append({
			"item_id": "gun_%d" % i, "name": "تفنگ %d" % i,
			"category": "weapon", "section": "weapons",
			"rarity": rarities[i % 3], "cost_type": "gems",
			"original_price": 150, "final_price": 150, "discount_percent": 0,
			"stats": {"power": 55, "accuracy": 65, "range": 75},
		})
	# پیشنهاد ویژه‌ها (ویترینِ هفتگی و خیلی‌ویژه)
	for i in range(4):
		items.append({
			"item_id": "weekly_%d" % i, "name": "هفتگی %d" % i,
			"category": "character", "section": "", "featured_section": "weekly",
			"rarity": "epic", "cost_type": "gems",
			"original_price": 200, "final_price": 140, "discount_percent": 30,
		})
	for i in range(4):
		items.append({
			"item_id": "vspecial_%d" % i, "name": "ویژه %d" % i,
			"category": "weapon", "section": "", "featured_section": "very_special",
			"rarity": "legend", "cost_type": "gems",
			"original_price": 450, "final_price": 250, "discount_percent": 44,
		})
	# بسته‌های ارز — دقیقاً همان جدولِ store_currency.go
	var coin_packs := [[1000, 20], [2500, 35], [5000, 60], [10000, 100]]
	for pack in coin_packs:
		items.append({
			"item_id": "coins%d" % pack[0], "name": "%d سکه" % pack[0],
			"category": "coins", "section": "currency", "amount": pack[0],
			"cost_type": "gems", "original_price": pack[1], "final_price": pack[1],
			"discount_percent": 0,
		})
	var gem_packs := [[100, 85000, 10, 10], [200, 155000, 20, 20],
		[300, 225000, 24, 30], [400, 280000, 30, 50]]
	for pack in gem_packs:
		var full: int = pack[1]
		var off: int = pack[2]
		items.append({
			"item_id": "%dgems" % pack[0], "name": "%d قلب" % pack[0],
			"category": "gems", "section": "currency", "amount": pack[0],
			"bonus_amount": pack[3],
			"cost_type": "toman", "original_price": full,
			"final_price": full - (full * off) / 100, "discount_percent": off,
			"product_id": "gems_%d" % pack[0],
		})
	return items


func _report() -> void:
	var vp := get_viewport().get_visible_rect()
	var bad := 0
	for n in _shop.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or c.size == Vector2.ZERO:
			continue
		if _inside_scroll(c) or _decorative(c):
			continue
		var r := c.get_global_rect()
		if r.end.x > vp.end.x + 1 or r.end.y > vp.end.y + 1 or r.position.x < -1 or r.position.y < -1:
			bad += 1
			print("SHOP OVERFLOW %s %s" % [_shop.get_path_to(c), r])

	# دو ستونِ هر تب نباید روی هم بیفتند (باگِ قبلی روی گوشی‌های دراز)
	var pairs := [
		["SectionMenu/CharactersTab/CharacterCards", "SectionMenu/CharactersTab/CardShow"],
		["SectionMenu/WeaponsTab/Control", "SectionMenu/WeaponsTab/Control2"],
		["SectionMenu/GemandcoinTab/Control", "SectionMenu/GemandcoinTab/Control2"],
		["SectionMenu/SpecialTab/SuggestUp", "SectionMenu/SpecialTab/VipControl"],
		["SectionMenu/SpecialTab/SuggestBottom", "SectionMenu/SpecialTab/GemControl"],
	]
	for pair in pairs:
		var a := _shop.get_node_or_null(pair[0]) as Control
		var b := _shop.get_node_or_null(pair[1]) as Control
		if a == null or b == null:
			print("SHOP MISSING %s / %s" % [pair[0], pair[1]])
			bad += 1
			continue
		if a.get_global_rect().intersects(b.get_global_rect()):
			bad += 1
			print("SHOP OVERLAP %s %s / %s %s" % [pair[0], a.get_global_rect(), pair[1], b.get_global_rect()])

	print("SHOP viewport=%s tab=%d problems=%d" % [vp.size, _tab, bad])


## پس‌زمینه و نورِ متحرک عمداً از کادر بیرون می‌زنند — دکمه نیستند
func _decorative(c: Control) -> bool:
	var path := str(_shop.get_path_to(c))
	return path.begins_with("BackgroundAction") or path == "AllAboveButtons/TextureRect"


func _inside_scroll(c: Control) -> bool:
	var p: Node = c.get_parent()
	while p != null and p != _shop:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false
