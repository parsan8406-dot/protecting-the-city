extends Object
class_name RankArt
## نشان‌های شش رنک بازی — یک جای واحد برای همه‌ی صفحه‌ها.
##
## قبلاً هر جا رنک نشان داده می‌شد فقط اسمش نوشته می‌شد (دوستان، اعضای شهر،
## چت، جدول رتبه‌بندی، پروفایل). حالا همه از همین‌جا تصویر می‌گیرند تا اگر
## تصویری عوض شد فقط یک فایل تغییر کند.
##
## استفاده:
##   var tex := RankArt.texture_for(data.get("tier_id", ""), data.get("tier_name", ""))
##   if tex: badge.texture = tex
##
## سرور برای بعضی ردیف‌ها فقط `tier_name` فارسی می‌فرستد، برای همین
## نگاشت اسم فارسی هم نگه داشته شده.

const BASE := "res://assets/ranks/"

## tier_id (همان چیزی که سرور در rank.tier_id می‌گذارد) → فایل نشان
const BY_ID := {
	"bronze": BASE + "rank_bronze.png",
	"silver": BASE + "rank_silver.png",
	"gold": BASE + "rank_gold.png",
	"platinum": BASE + "rank_platinum.png",
	"diamond": BASE + "rank_diamond.png",
	"legend": BASE + "rank_legend.png",
}

## اسم فارسی رنک → tier_id (برای ردیف‌هایی که سرور فقط اسم می‌فرستد)
const ID_BY_NAME := {
	"برنز": "bronze",
	"نقره": "silver",
	"طلا": "gold",
	"پلاتین": "platinum",
	"الماس": "diamond",
	"لجند": "legend",
	"لجندری": "legend",
}

## تصویر کاپ (فعلاً یک فایل برای همه‌ی کاپ‌ها)
const CUP := BASE + "cup_trophy.png"

## کلیدی که سرور برای هر کاپ می‌فرستد (season_cups.icon) → فایل تصویر.
## هر کلید ناشناخته به تصویر پیش‌فرض کاپ می‌افتد.
const CUP_BY_ICON := {
	"cup": CUP,
	"trophy": CUP,
}

## تصویر نشان رنک. اگر رنک ناشناخته بود یا فایلش نبود، null برمی‌گرداند
## تا صدازننده بتواند جای خالی را مخفی کند.
static func texture_for(tier_id: String, tier_name: String = "") -> Texture2D:
	var path := path_for(tier_id, tier_name)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

static func path_for(tier_id: String, tier_name: String = "") -> String:
	var id := tier_id.strip_edges().to_lower()
	if not BY_ID.has(id):
		id = str(ID_BY_NAME.get(tier_name.strip_edges(), ""))
	return str(BY_ID.get(id, ""))

## تصویر کاپ — null اگر فایلش نبود
static func cup_texture(icon: String = "") -> Texture2D:
	var path := str(CUP_BY_ICON.get(icon.strip_edges().to_lower(), CUP))
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
