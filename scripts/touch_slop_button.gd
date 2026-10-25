extends TextureButton
## دکمه‌ی آیکنیِ کوچک با ناحیه‌ی لمسِ بزرگ‌تر از آرتش.
##
## آیکن‌های نوارِ بالا (پیام، دوستان، تنظیمات، +، ویرایش) ۱۳ تا ۳۸ پیکسل‌اند،
## ولی انگشت حداقل ~۴۸dp می‌خواهد. بزرگ کردنِ خودِ دکمه آرت را کش می‌دهد و
## قاب‌هایی که صحنه‌های دیگر (مثلاً city.gd) دورِ همین دکمه‌ها می‌کشند را به
## هم می‌ریزد؛ پس فقط «کجا لمس حساب می‌شود» بزرگ می‌شود، دورِ مرکزِ دکمه.

## کمترین اندازه‌ی ناحیه‌ی لمس (واحدِ ویوپورت؛ ~۴۸dp روی گوشیِ ۱۰۸۰p)
@export var min_touch_size := Vector2(56, 56)


func _has_point(point: Vector2) -> bool:
	var area := Vector2(maxf(size.x, min_touch_size.x), maxf(size.y, min_touch_size.y))
	var rect := Rect2(size * 0.5 - area * 0.5, area)
	return rect.has_point(point)
