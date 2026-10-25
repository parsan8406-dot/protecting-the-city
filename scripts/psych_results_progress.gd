extends RefCounted
## ابزارهای مشترکِ «پیشرفت» برای صفحه‌های نتیجه، ماموریت، فصل و رنک.
##
## C9 شیبِ هدف و پیشرفتِ اهدایی: نوار هیچ‌وقت کاملاً خالی دیده نمی‌شود و
## نزدیکِ پایان طلایی و پُررنگ می‌شود. فقط «ظاهر»ِ نوار عوض می‌شود؛ عددهای
## کنارِ نوار همان عددهای سرورند.
## E7 زیگارنیک: نزدیک‌ترین هدفِ ناتمام از بینِ ماموریت‌ها و چالش‌ها.
##
## استفاده: const PsychProgress := preload("res://scripts/psych_results_progress.gd")

## کمترین پُری‌ای که نوارِ ناتمام نشان می‌دهد (C9 endowed progress)
const ENDOWED := 0.06
const GOLD := Color(0.97, 0.79, 0.32)
const GOLD_HI := Color(1.0, 0.9, 0.5)

## جدولِ رنک‌ها — همان rank_screen.DEFAULT_TIERS (منبع: سرور، matchmaking.go)
## (با load و نه preload، چون rank_screen.gd خودش این فایل را preload می‌کند)
const RANK_SCREEN_PATH := "res://scripts/rank_screen.gd"
static var _tiers_cache: Array = []


## نسبتِ نمایشیِ نوار: ناتمام هرگز زیرِ ENDOWED نمی‌رود
static func visual_ratio(progress: float, target: float) -> float:
	if target <= 0.0:
		return 1.0
	var r := clampf(progress / target, 0.0, 1.0)
	if r >= 1.0:
		return 1.0
	return maxf(r, ENDOWED)


## «تقریباً تمام»: حداقل ۷۵٪ یا فقط یکی مانده
static func is_near(progress: int, target: int) -> bool:
	if target <= 0 or progress >= target or progress <= 0:
		return false
	return target - progress <= 1 or float(progress) / float(target) >= 0.75


## مقدارِ نمایشیِ یک ProgressBar با پیشرفتِ اهدایی (value واقعی را جابه‌جا
## نمی‌کند؛ فقط به max نسبت می‌دهد)
static func bar_value(bar: Range, progress: float, target: float) -> float:
	return visual_ratio(progress, target) * bar.max_value


## نوار را طلایی و براق می‌کند (یا برمی‌گرداند). stylebox «fill» خودِ صحنه
## کپی می‌شود تا شکلش عوض نشود، فقط رنگش.
static func emphasize_bar(bar: ProgressBar, on: bool) -> void:
	if bar == null:
		return
	if not bar.has_meta("psych_fill_base"):
		bar.set_meta("psych_fill_base", bar.get_theme_stylebox("fill"))
	var base: StyleBox = bar.get_meta("psych_fill_base")
	if not on:
		if base != null:
			bar.add_theme_stylebox_override("fill", base)
		if bar.has_meta("psych_pulse"):
			var old: Tween = bar.get_meta("psych_pulse")
			if old != null and old.is_valid():
				old.kill()
			bar.remove_meta("psych_pulse")
		bar.self_modulate = Color.WHITE
		return
	if base is StyleBoxFlat:
		var sb := (base as StyleBoxFlat).duplicate() as StyleBoxFlat
		sb.bg_color = GOLD
		sb.border_color = GOLD_HI
		bar.add_theme_stylebox_override("fill", sb)
	if not bar.has_meta("psych_pulse"):
		# پالسِ ملایم، نه چشمک — فقط تا نگاه رویش بنشیند
		var t := bar.create_tween().set_loops()
		t.tween_property(bar, "self_modulate", Color(1.25, 1.2, 1.05), 0.7).set_trans(Tween.TRANS_SINE)
		t.tween_property(bar, "self_modulate", Color.WHITE, 0.7).set_trans(Tween.TRANS_SINE)
		bar.set_meta("psych_pulse", t)


## «فقط ۲ تا مونده!» — متنِ نزدیک‌برد (C9/E5)
static func remaining_text(progress: int, target: int) -> String:
	var left := maxi(target - progress, 0)
	if left == 1:
		return "فقط ۱ قدم مونده!"
	return "فقط %s تا مونده!" % MissionArt.fa_number(left)


## نزدیک‌ترین هدفِ ناتمام (E7). اولویت: ماموریتِ روزانه (افقِ کوتاه‌تر) و
## بعد چالشِ فصل؛ در هر کدام بیشترین درصدِ پیشرفت. چیزی که هنوز صفر است
## فقط وقتی انتخاب می‌شود که هیچ هدفِ شروع‌شده‌ای نباشد.
## خروجی: {} یا item + "horizon" ("daily" | "season")
static func closest_goal(missions: Array, challenges: Array) -> Dictionary:
	for pool in [[missions, "daily"], [challenges, "season"]]:
		var best: Dictionary = {}
		var best_r := -1.0
		for it in pool[0]:
			if typeof(it) != TYPE_DICTIONARY:
				continue
			if bool(it.get("done", false)) or bool(it.get("claimed", false)):
				continue
			var target := maxi(int(it.get("target", 1)), 1)
			var r := float(int(it.get("progress", 0))) / float(target)
			if r > best_r:
				best_r = r
				best = (it as Dictionary).duplicate()
		if not best.is_empty() and best_r > 0.0:
			best["horizon"] = pool[1]
			return best
	# هیچ هدفِ شروع‌شده‌ای نیست: اولین ماموریتِ روزانه‌ی ناتمام
	for it in missions:
		if typeof(it) == TYPE_DICTIONARY and not bool(it.get("done", false)):
			var d := (it as Dictionary).duplicate()
			d["horizon"] = "daily"
			return d
	return {}


## چند جایزه‌ی آماده‌ی گرفتن هست (ماموریت/چالشِ تمام‌شده‌ای که گرفته نشده)
static func ready_count(items: Array) -> int:
	var n := 0
	for it in items:
		if typeof(it) == TYPE_DICTIONARY and bool(it.get("done", false)) \
				and not bool(it.get("claimed", false)):
			n += 1
	return n


## ترتیبِ نمایش (C14/E7): آماده‌ی دریافت ← نزدیک‌ترین ناتمام ← بقیه‌ی
## ناتمام‌ها ← گرفته‌شده. ترتیبِ سرور در هر گروه تا جای ممکن حفظ می‌شود.
static func sort_for_display(items: Array) -> Array:
	var ready: Array = []
	var open: Array = []
	var claimed: Array = []
	for it in items:
		if typeof(it) != TYPE_DICTIONARY:
			continue
		if bool(it.get("claimed", false)):
			claimed.append(it)
		elif bool(it.get("done", false)):
			ready.append(it)
		else:
			open.append(it)
	open.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _ratio(a) > _ratio(b))
	return ready + open + claimed


static func _ratio(it: Dictionary) -> float:
	return float(int(it.get("progress", 0))) / float(maxi(int(it.get("target", 1)), 1))


## رنکِ هر تعداد کاپ و فاصله تا رنکِ بعدی
## خروجی: index, id, name, min, next_id, next_name, next_min (۰ = آخرین رنک)
static func tier_info(trophies: int) -> Dictionary:
	if _tiers_cache.is_empty():
		var sc := load(RANK_SCREEN_PATH) as GDScript
		if sc != null:
			_tiers_cache = sc.get_script_constant_map().get("DEFAULT_TIERS", [])
	var tiers: Array = _tiers_cache
	if tiers.is_empty():
		return {"index": 0, "id": "", "name": "", "min": 0, "next_id": "", "next_name": "", "next_min": 0}
	var idx := 0
	for i in range(tiers.size() - 1, -1, -1):
		if trophies >= int(tiers[i]["min"]):
			idx = i
			break
	var t: Dictionary = tiers[idx]
	var out := {"index": idx, "id": str(t["id"]), "name": str(t["name"]), "min": int(t["min"]),
		"next_id": "", "next_name": "", "next_min": 0}
	if idx + 1 < tiers.size():
		var n: Dictionary = tiers[idx + 1]
		out["next_id"] = str(n["id"])
		out["next_name"] = str(n["name"])
		out["next_min"] = int(n["min"])
	return out
