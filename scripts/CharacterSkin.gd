class_name CharacterSkin
extends RefCounted

# اجزای کاراکتر از res://assets/player_characters/<character_id>/ خوانده می‌شود.
# هر پوشه باید Body.png / Head.png / LeftArm.png / RightArm.png داشته باشد.
#
# همه‌ی اسکین‌ها روی یک بوم ۱۰۲۴×۱۰۲۴ مشترک کشیده شده‌اند، پس مش (وکتور) و
# اسکلت برای همه یکی است و فرم کاراکترها یکسان می‌ماند.
# فقط چیزی که بین اسکین‌ها فرق دارد زاویه‌ی باز بودن دست‌هاست؛ آن را با چرخاندن
# استخوان ArmRoot دور مفصل شانه جبران می‌کنیم تا دست‌های همه جلوی سر جمع شوند
# و انگار تفنگ را دو دستی گرفته‌اند. چون تمام وزن‌های بازو زیر همین استخوان‌اند،
# این چرخش کاملاً rigid است و شکل بازو را تغییر نمی‌دهد.

const BASE_DIR := "res://assets/player_characters/"
const FALLBACK_ID := "skin_default"
const PART_FILES := {
	"Body": "Body.png",
	"Head": "Head.png",
	"LeftArm": "LeftArm.png",
	"RightArm": "RightArm.png",
}

const LEFT_ARM_BONE := "Bone2D/Bone2D/Bone2D3/LArmRoot"
const RIGHT_ARM_BONE := "Bone2D/Bone2D/Bone2D2/RArmRoot"

# ضریب تبدیل پیکسل بوم ۱۰۲۴ به واحد محلی Player (همان scale نود Sprite2D).
const ART_TO_LOCAL := 0.158

# چند اسکین بازوهایشان در خود عکس کاملاً عمودی کشیده شده (نه باز به بیرون).
# برای این‌ها فقط چرخاندن دور شانه کافی نیست: هرچه بیشتر بچرخانیم دست‌ها
# روی هم می‌افتند به‌جای اینکه یک زاویه بسازند. پس اول شانه را به بیرون
# می‌بریم (بر حسب پیکسل بوم) و بعد زاویه‌ی جدید را روی آن حل می‌کنیم.
# چون کل وزن‌های بازو زیر ArmRoot است، این جابه‌جایی هم کاملاً rigid است.
const ARM_OUTWARD := {
	# منفی یعنی بازو از شانه‌ی مقابل برمی‌گردد سر شانه‌ی خودش (جابه‌جایی چپ/راست).
	# برای اسنایپر: 256 = لغو کامل جابه‌جایی، به‌علاوه‌ی 40 پیکسل بازشدن شانه‌ها.
	"skin_sniper": -296.0,
}

# چرخش دست چپ و راست بر حسب رادیان — خروجی tools/rig/arm_angles.py
const ARM_SWING := {
	"skin_angle": Vector2(-0.09376, 0.08720),
	"skin_boy": Vector2(-0.11064, 0.10613),
	"skin_default": Vector2(0.11663, -0.00331),
	"skin_default_red": Vector2(0.11737, -0.01246),  # tools/rig/normalize_skin.py
	"skin_devil": Vector2(-0.34752, 0.34236),
	"skin_engineer": Vector2(0.11046, -0.11699),
	"skin_fire": Vector2(0.13911, -0.14552),
	"skin_girl": Vector2(0.07602, 0.04225),
	"skin_iraqian": Vector2(-0.39460, 0.39072),
	"skin_joker": Vector2(-0.25795, 0.25376),
	"skin_lighting": Vector2(0.09847, -0.10401),
	"skin_nature": Vector2(-0.09629, 0.09159),
	"skin_rainbow": Vector2(-0.06116, 0.05674),
	"skin_roman": Vector2(0.01974, -0.02358),
	"skin_smoke": Vector2(-0.05909, 0.05262),
	"skin_sniper": Vector2(-0.29152, 0.28750),   # بازوها جابه‌جا شده‌اند — ARM_OUTWARD را ببین
}

static var _cache: Dictionary = {}


static func has_skin(character_id: String) -> bool:
	if character_id.is_empty():
		return false
	for file in PART_FILES.values():
		if not ResourceLoader.exists(BASE_DIR + character_id + "/" + file):
			return false
	return true


static func resolve_id(character_id: String) -> String:
	return character_id if has_skin(character_id) else FALLBACK_ID


## تکسچر اجزای کاراکتر را روی نودهای زیرمجموعه‌ی sprite_root ست می‌کند.
## sprite_root همان نودی است که Body / Head / LeftArm / RightArm زیرش هستند.
static func apply(sprite_root: Node, character_id: String) -> bool:
	if sprite_root == null:
		return false
	var id := resolve_id(character_id)
	if not has_skin(id):
		push_warning("CharacterSkin: no parts found for '%s' (nor fallback)" % character_id)
		return false

	if not _cache.has(id):
		var parts := {}
		for node_name in PART_FILES:
			parts[node_name] = load(BASE_DIR + id + "/" + PART_FILES[node_name])
		_cache[id] = parts

	for node_name in PART_FILES:
		var node := sprite_root.get_node_or_null(NodePath(node_name))
		if node != null and "texture" in node:
			node.texture = _cache[id][node_name]

	if id != character_id:
		push_warning("CharacterSkin: '%s' پیدا نشد — fallback به '%s'" % [character_id, id])
	print("🎭 skin روی ", sprite_root.get_path(), " = ", id)

	_apply_arm_swing(sprite_root, id)
	return true


## دست‌ها را دور شانه می‌چرخاند تا جلوی سر، روی دسته‌ی اسلحه، جمع شوند.
static func _apply_arm_swing(sprite_root: Node, id: String) -> void:
	var owner_node := sprite_root.get_parent()
	if owner_node == null:
		return
	var skeleton := owner_node.get_node_or_null("Body") as Skeleton2D
	if skeleton == null:
		return
	var swing: Vector2 = ARM_SWING.get(id, ARM_SWING.get(FALLBACK_ID, Vector2.ZERO))
	var outward: float = float(ARM_OUTWARD.get(id, 0.0)) * ART_TO_LOCAL
	var left := skeleton.get_node_or_null(LEFT_ARM_BONE) as Bone2D
	var right := skeleton.get_node_or_null(RIGHT_ARM_BONE) as Bone2D
	# از rest شروع می‌کنیم تا اگر apply چند بار صدا زده شد جابه‌جایی جمع نشود.
	if left != null:
		left.rotation = swing.x
		left.position = left.rest.origin - Vector2(outward, 0.0)
	if right != null:
		right.rotation = swing.y
		right.position = right.rest.origin + Vector2(outward, 0.0)
