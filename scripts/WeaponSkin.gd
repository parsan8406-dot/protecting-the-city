class_name WeaponSkin
extends RefCounted

# اسپرایت درون‌بازیِ اسلحه از res://assets/player_weapons/<weapon_id>.png خوانده می‌شود.
#
# قبلاً از res://assets/used_items/ خوانده می‌شد که فقط ۶ فایل قدیمی داشت
# (ak47, uzi, mj4 و سه اسکین)، برای همین هر اسلحه‌ای غیر از ak47 که بازیکن
# انتخاب می‌کرد در بازی عوض نمی‌شد — تکسچر روی همان چیزی می‌ماند که در صحنه بود.
#
# مثل اسکین کاراکترها، همه‌ی ۱۱ اسپرایت روی یک بوم مشترک ۱۲۸۰×۶۴۰ کشیده شده‌اند
# و لوله‌شان هم‌تراز است، پس یک ترنسفورم مشترک برای همه جواب می‌دهد و لازم نیست
# برای هر اسلحه دستی تنظیم شود.

const BASE_DIR := "res://assets/player_weapons/"
const FALLBACK_ID := "ak47"

# --- ترنسفورم مشترک اسپرایت ---
# آرت قدیمی عمودی بود (۵۶×۳۰۲، لوله رو به پایین) و نود با rotation = PI می‌نشست.
# آرت جدید افقی است (~۱۲۲۴×۱۶۲، لوله رو به راست)، پس برای اینکه لوله در همان
# جهتِ قبل (رو به جلوی بازیکن) بایستد، چرخش نود -۹۰ درجه می‌شود.
const SPRITE_ROTATION := -PI / 2.0

# اسلحه عمداً از آرت قدیمی درشت‌تر کشیده می‌شود تا توی بازی خوب دیده شود.
# اسلحه عمداً از آرت قدیمی درشت‌تر کشیده می‌شود تا توی بازی خوب دیده شود.
const SPRITE_SCALE := Vector2(0.095, 0.095)

# اسلحه به سمت بدن کشیده شده تا قنداقش روی دست‌ها بیفتد و حالتِ دست‌ها پیدا
# نباشد؛ x نزدیک صفر است تا بین دو دست وسط بنشیند.
const SPRITE_POSITION := Vector2(2.0, -36.0)

# ⚠ انیمیشن‌های کاراکتر (resources/player_anims.tres) موقعیتِ اسلحه را از
# همین ثابت می‌سازند تا اسلحه با تابِ بدن جابه‌جا شود و از دست‌ها کنده نشود.
# اگر SPRITE_POSITION را عوض کردی، این را هم دوباره اجرا کن:
#   godot --headless --path . --script res://tools/build_player_anims.gd
# (SPRITE_ROTATION دستِ هیچ انیمیشنی نیست — لوله همیشه هم‌راستای بدن می‌ماند.)

static var _cache: Dictionary = {}


static func has_weapon(weapon_id: String) -> bool:
	if weapon_id.is_empty():
		return false
	return ResourceLoader.exists(BASE_DIR + weapon_id + ".png")


## اگر آیدی اسلحه اسپرایت نداشت (مثلاً pistol_default که فقط در دیتابیس هست)
## به اسلحه‌ی پیش‌فرض برمی‌گردیم تا بازیکن بدون اسلحه ظاهر نشود.
static func resolve_id(weapon_id: String) -> String:
	return weapon_id if has_weapon(weapon_id) else FALLBACK_ID


static func get_texture(weapon_id: String) -> Texture2D:
	var id := resolve_id(weapon_id)
	if not has_weapon(id):
		return null
	if not _cache.has(id):
		_cache[id] = load(BASE_DIR + id + ".png")
	return _cache[id]


## تکسچر و ترنسفورم اسلحه را روی نود gun ست می‌کند.
## ترنسفورم عمداً اینجا (و نه در صحنه) ست می‌شود تا بازیکن محلی و بقیه‌ی
## بازیکن‌ها همیشه یک‌جور دیده شوند و تنظیمش فقط یک جا باشد.
static func apply(gun_sprite: Node2D, weapon_id: String) -> bool:
	if gun_sprite == null:
		return false

	var id := resolve_id(weapon_id)
	var texture := get_texture(id)
	if texture == null:
		push_warning("WeaponSkin: اسپرایت اسلحه پیدا نشد: '%s'" % weapon_id)
		return false

	if "texture" in gun_sprite:
		gun_sprite.texture = texture
	gun_sprite.rotation = SPRITE_ROTATION
	gun_sprite.scale = SPRITE_SCALE
	gun_sprite.position = SPRITE_POSITION

	if id != weapon_id:
		push_warning("WeaponSkin: '%s' پیدا نشد — fallback به '%s'" % [weapon_id, id])
	return true
