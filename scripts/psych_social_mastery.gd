extends RefCounted
## E8 مالکیت + E1 شایستگی — آمار شخصی به زبان «مهارت»، نه فقط عدد خام.
##
## همه از recent_matches پروفایل (ده مسابقه‌ی آخر، جدیدترین اول — handlers_social.go)
## خوانده می‌شود؛ هیچ عددی ساخته نمی‌شود. سرور دقت شلیک، هدشات یا بهترین
## استریک کل دوران را ذخیره نمی‌کند، پس فقط «اخیر» گفته می‌شود.


## {win_streak, best_kills, matches, fav_weapon, fav_kills, fav_matches}
static func from_recent(recent: Array) -> Dictionary:
	var out := {"win_streak": 0, "best_kills": 0, "matches": 0,
		"fav_weapon": "", "fav_kills": 0, "fav_matches": 0}
	var streak_open := true
	var uses := {}
	var kills := {}
	for item in recent:
		if not (item is Dictionary):
			continue
		var m: Dictionary = item
		out.matches += 1
		var won := bool(m.get("won", false)) and not bool(m.get("draw", false))
		if streak_open and won:
			out.win_streak += 1
		else:
			streak_open = false
		var k := int(m.get("kills", 0))
		out.best_kills = maxi(int(out.best_kills), k)
		var w := str(m.get("weapon", ""))
		if not w.is_empty():
			uses[w] = int(uses.get(w, 0)) + 1
			kills[w] = int(kills.get(w, 0)) + k
	for w in uses:
		var n := int(uses[w])
		if n > int(out.fav_matches) or (n == int(out.fav_matches) and int(kills[w]) > int(out.fav_kills)):
			out.fav_weapon = w
			out.fav_matches = n
			out.fav_kills = int(kills[w])
	return out


## یک خط کوتاه «شایستگی» برای زیر فرم اخیر؛ خالی یعنی چیزی برای گفتن نیست
static func mastery_line(m: Dictionary) -> String:
	var parts: Array[String] = []
	if int(m.get("win_streak", 0)) >= 2:
		parts.append("%s برد پشت‌سرهم" % MissionArt.fa_number(int(m.win_streak)))
	if int(m.get("best_kills", 0)) > 0:
		parts.append("رکورد اخیر: %s کیل در یک مسابقه" % MissionArt.fa_number(int(m.best_kills)))
	return "  •  ".join(parts)
