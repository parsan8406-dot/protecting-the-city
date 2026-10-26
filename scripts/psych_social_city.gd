extends RefCounted
## E1 ارتباط / E9 مقایسه‌ی اجتماعیِ کوچک / E10 — حسابِ «سهم من» و «تازه‌واردها»
## در صفحه‌ی شهر.
##
## همه از لیست members همان پاسخ GET /clan خوانده می‌شود (handlers_clan.go:
## trophies, joined_at, player_id)؛ عددی ساخته نمی‌شود. امتیاز شهر = جمع کاپ
## اعضا (handlers_leaderboard.go → cityStanding).

## عضوی که کمتر از این مدت پیش آمده «تازه‌وارد» نشان داده می‌شود
const NEW_MEMBER_SEC := 72 * 3600
## خودم کمتر از این مدت پیش عضو شده‌ام ⇒ بنرِ خوش‌آمد به‌جای بنرِ معمولی
const WELCOME_SEC := 24 * 3600


static func joined_ago(member: Dictionary) -> int:
	var at := ChatBubble.iso_to_unix(str(member.get("joined_at", "")))
	if at <= 0:
		return -1
	return maxi(int(Time.get_unix_time_from_system()) - at, 0)


static func is_new_member(member: Dictionary) -> bool:
	var ago := joined_ago(member)
	return ago >= 0 and ago < NEW_MEMBER_SEC


## {mine, pct, place, count, new_count, me_new}
##   place: جایگاه من بین اعضا بر اساس کاپ (۱ = بیشترین سهم)
##   new_count: تعداد تازه‌واردها (به‌جز خودم)
static func standing(data: Dictionary) -> Dictionary:
	var out := {"mine": 0, "pct": 0, "place": 0, "count": 0, "new_count": 0, "me_new": false}
	var members = data.get("members", [])
	if not (members is Array):
		return out
	var my_id := str(Global.player_id)
	var total := 0
	var cups: Array[int] = []
	for m in members:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = m
		var c := maxi(int(d.get("trophies", 0)), 0)
		var is_me := bool(d.get("is_me", false)) or (not my_id.is_empty() and str(d.get("player_id", "")) == my_id)
		total += c
		cups.append(c)
		if is_me:
			out.mine = c
			var ago := joined_ago(d)
			out.me_new = ago >= 0 and ago < WELCOME_SEC
		elif is_new_member(d):
			out.new_count += 1
	out.count = cups.size()
	if total > 0 and int(out.mine) > 0:
		out.pct = roundi(100.0 * float(out.mine) / float(total))
		var place := 1
		for c in cups:
			if c > int(out.mine):
				place += 1
		out.place = place
	return out
