extends Node
## عکس و چکِ صفحه‌های «بعد از مسابقه و پیشرفت» (پاسِ روانشناسی، دورِ ۲).
##
##   godot --path . --username=PsychRes1 res://tools/psych_results_shot.tscn \
##         --resolution 1280x720 -- --server=http://127.0.0.1:8791 \
##         --page=missions_switch --out=C:/tmp/shot
##
## صفحه‌ها (--page=):
##   dump              پاسخِ واقعیِ سرورِ محلی (missions/daily، season/pass،
##                     profile) را در --out_*.json می‌ریزد — اکانت تازه می‌سازد
##   missions_daily    تبِ ماموریت‌ها با دیتای ساختگی (یکی آماده، یکی نزدیک)
##   missions_switch   روزانه ← فصل (همان مسیری که روی‌هم‌افتادگی داشت)
##   season            تبِ فصل مستقیم
##   achievements      پنجره‌ی دستاوردها (یکی تازه باز شده)
##   reward            RewardPopup با سه کارت
##   claim_fly         ماموریت‌ها + RewardPopup؛ بستن ← پروازِ سکه به نوارِ بالا و
##                     شمارشِ عدد (عکس وسطِ پرواز: _fly، بعد از شمارش: _claim_fly)
##   missions_loading  حالتِ «در حال بارگذاری» / missions_error حالتِ خطا با «تلاش دوباره»
##
## با --live (فقط صفحه‌های missions_*) دیتا از سرورِ محلی می‌آید نه ساختگی.
## در آخر هر کنترلی که از صفحه بیرون زده یا رویِ نوارِ بالا افتاده چاپ می‌شود.

const MISSIONS_SCENE := "res://secense/missions_screen.tscn"

var _out := ""
var _page := "missions_daily"
var _live := false
var _frames := 0
var _screen: Node = null
var _started := false
var _dump_left := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--page="):
			_page = a.substr(7)
		elif a == "--live":
			_live = true
	if _page == "dump" or _live:
		Global.player_data_loaded.connect(_start, CONNECT_ONE_SHOT)
	else:
		Global.my_username = ""
		_start.call_deferred()


func _start() -> void:
	_started = true
	_frames = 0
	match _page:
		"dump":
			_dump()
		"missions_daily", "missions_switch", "claim_fly":
			_open_missions("daily")
		"missions_loading", "missions_error":
			Global.requested_missions_tab = "daily"
			_screen = load(MISSIONS_SCENE).instantiate()
			add_child(_screen)
			_screen.call("_set_list_state", "loading" if _page == "missions_loading" else "error")
		"season":
			_open_missions("season")
		"achievements":
			# یکی «دیده‌شده»، یکی تازه — تا برچسبِ «جدید!» و کنفتی دیده شوند
			var cfg := ConfigFile.new()
			cfg.load("user://psych_results.cfg")
			cfg.set_value("u_" + str(Global.my_username), "ach_seen", ["ach_first_blood"])
			cfg.save("user://psych_results.cfg")
			AchievementsDialog.open(self, _fake_achievements())
		"reward":
			RewardPopup.show_rewards([
				{"icon": "coin", "amount": 1200}, {"icon": "xp", "amount": 350},
				{"icon": "gem", "amount": 15}], "ماموریت انجام شد")


func _process(_delta: float) -> void:
	if not _started:
		return
	_frames += 1
	if _page == "dump":
		if _frames > 600:
			print("SHOT dump timeout")
			get_tree().quit(1)
		return
	# Global هم دیتای سرور را می‌گیرد و صفحه با آن تازه می‌شود؛ دیتای ساختگی
	# بعد از آن دوباره نشانده می‌شود
	if _page == "claim_fly":
		if _frames == 30:
			RewardPopup.show_rewards([{"icon": "coin", "amount": 1200}, {"icon": "gem", "amount": 15}], "ماموریت انجام شد")
		elif _frames == 34:
			Global.coins = int(Global.coins) + 1200
			Global.gems = int(Global.gems) + 15
			Global.player_data_updated.emit()
		elif _frames == 70:
			var p = RewardPopup._active
			if p != null:
				p._opened_at = -10.0
				p._close()
		elif _frames == 88:
			_save("fly")
		elif _frames == 130:
			print("SHOT coins label=%s" % (_screen.get("_coins_label") as Label).text)
			_report()
			_save(_page)
			get_tree().quit(0)
		return
	if _page.begins_with("missions_") and _page != "missions_daily" and _page != "missions_switch":
		# Global ممکن است دیتای سرور را برساند؛ حالت دوباره نشانده می‌شود
		if _frames == 30:
			_screen.call("_set_list_state", "loading" if _page == "missions_loading" else "error")
		if _frames == 40:
			_report()
			_save(_page)
			get_tree().quit(0)
		return
	if _frames == 25 and _screen != null and not _live and _page != "achievements":
		_screen.call("_apply_missions", _fake_missions())
		_screen.call("_apply_season", _fake_season())
	if _page == "missions_switch" and _frames == 40:
		_screen.call("_on_tab_pressed", "season")
	var end := 100 if _page != "reward" else 70
	if _frames == end:
		_report()
		_save(_page)
		get_tree().quit(0)


func _open_missions(tab: String) -> void:
	Global.requested_missions_tab = tab
	_screen = load(MISSIONS_SCENE).instantiate()
	add_child(_screen)
	if _live:
		return
	_screen.call("_apply_missions", _fake_missions())
	_screen.call("_apply_season", _fake_season())


# ------------------------------------------------------------------ dump

func _dump() -> void:
	var user := str(Global.my_username).uri_encode()
	var paths := {
		"missions": "/missions/daily?username=" + user,
		"season": "/season/pass?username=" + user,
		"profile": "/profile?username=" + user,
	}
	_dump_left = paths.size()
	for key in paths:
		var http := HTTPRequest.new()
		add_child(http)
		http.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
			var f := FileAccess.open("%s_%s.json" % [_out, key], FileAccess.WRITE)
			if f != null:
				f.store_string(body.get_string_from_utf8())
				f.close()
			print("SHOT dump %s code=%d bytes=%d" % [key, code, body.size()])
			_dump_left -= 1
			if _dump_left <= 0:
				get_tree().quit(0))
		http.request(Global.SERVER_BASE + paths[key], Global.auth_headers())


# ------------------------------------------------------------------ دیتای ساختگی

func _fake_missions() -> Dictionary:
	var missions := []
	var defs := [
		["کیل", "kills", 10, 8, false, false],
		["برد", "wins", 3, 3, true, false],
		["بازی", "matches", 5, 1, false, false],
		["هدشات", "headshots", 15, 0, false, false],
		["زمان", "playtime", 20, 20, true, true],
		["گلوله", "damage", 2000, 900, false, false],
	]
	for d in defs:
		missions.append({"mission_id": "m_" + str(d[1]), "title": "%s %s" % [d[0], d[2]],
			"desc": "توضیحِ کوتاهِ ماموریت", "icon": d[1], "target": d[2], "progress": d[3],
			"done": d[4], "claimed": d[5], "coins": 150, "xp": 40})
	return {"seconds_left": 30000, "missions": missions, "total": 6, "claimed": 1, "ready": 1,
		"bonus_ready": 0, "bonus": [
			{"need": 2, "state": "locked", "icon": "chest_common", "coins": 200},
			{"need": 4, "state": "locked", "icon": "chest_rare", "coins": 400},
			{"need": 6, "state": "locked", "icon": "chest_legend", "coins": 800, "gems": 10}]}


func _fake_season() -> Dictionary:
	var tiers := []
	for lv in range(1, 31):
		var unlocked := lv <= 4
		var free_state := "claimed" if lv <= 2 else ("ready" if unlocked else "locked")
		var prem_state := "premium_locked" if unlocked else "locked"
		var icon := "coin" if lv % 5 != 0 else "chest_legend"
		tiers.append({"level": lv, "unlocked": unlocked, "xp_required": lv * 500,
			"free": {"coins": 100 * lv, "gems": 0, "cups": 0, "title": "سکه", "icon": icon, "state": free_state},
			"premium": {"coins": 0, "gems": 5 * lv, "cups": 0, "title": "جم", "icon": "gem", "state": prem_state}})
	var challenges := []
	for i in 5:
		challenges.append({"challenge_id": "c%d" % i, "title": "چالش %d" % i, "icon": "kills",
			"target": 10, "progress": [9, 3, 0, 10, 6][i], "done": i == 3, "claimed": false, "coins": 500})
	return {"season_id": "season_3", "level": 4, "level_xp": 410, "level_max": 500, "max_level": 30,
		"ready": 2, "tiers": tiers, "premium": false, "premium_price": 900,
		"challenges": challenges, "challenges_ready": 1, "season_name": "فصل سوم",
		"season_subtitle": "شهرِ شب", "season_ends_at": "2026-12-01"}


func _fake_achievements() -> Array:
	var now := Time.get_datetime_string_from_system(true)
	return [
		{"achievement_id": "ach_first_match", "name": "اولین مسابقه", "description": "یک مسابقه بازی کن",
			"metric": "total_matches", "target": 1, "progress": 1, "unlocked": true, "unlocked_at": now,
			"reward_coins": 100, "reward_gems": 0},
		{"achievement_id": "ach_first_blood", "name": "اولین خون", "description": "اولین حریف را از پا در بیاور",
			"metric": "kills", "target": 1, "progress": 1, "unlocked": true, "unlocked_at": "2026-01-01T00:00:00Z",
			"reward_coins": 200, "reward_gems": 0},
		{"achievement_id": "ach_hunter", "name": "شکارچی", "description": "۵۰ حریف را از پا در بیاور",
			"metric": "kills", "target": 50, "progress": 46, "unlocked": false, "reward_coins": 1000, "reward_gems": 5},
		{"achievement_id": "ach_fast", "name": "سریع و خشن", "description": "۵۰۰ حریف را از پا در بیاور",
			"metric": "kills", "target": 500, "progress": 46, "unlocked": false, "reward_coins": 3000, "reward_gems": 30},
		{"achievement_id": "ach_wins10", "name": "پیروز", "description": "۱۰ برد",
			"metric": "wins", "target": 10, "progress": 4, "unlocked": false, "reward_coins": 500, "reward_gems": 0},
		{"achievement_id": "ach_time", "name": "کهنه‌کار", "description": "۱۰ ساعت بازی",
			"metric": "playtime_seconds", "target": 36000, "progress": 0, "unlocked": false, "reward_coins": 800, "reward_gems": 0},
	]


# ------------------------------------------------------------------ گزارش

func _report() -> void:
	var vp := get_viewport().get_visible_rect()
	var root: Node = _screen if _screen != null else get_tree().root
	var bad := 0
	var header: Control = _screen.get_node_or_null("Header") if _screen != null else null
	var header_bottom := header.get_global_rect().end.y if header != null else -1.0
	for n in root.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or c.size == Vector2.ZERO:
			continue
		if _inside_scroll(c):
			continue
		var r := c.get_global_rect()
		if r.end.x > vp.end.x + 1 or r.end.y > vp.end.y + 1 or r.position.x < -1 or r.position.y < -1:
			bad += 1
			print("SHOT OVERFLOW %s %s" % [root.get_path_to(c), r])
	if _screen != null and _screen.has_node("Body/Center/SeasonPage"):
		for c in _screen.get_node("Body/Center/SeasonPage").get_children():
			print("SHOT min %s = %s" % [c.name, (c as Control).get_combined_minimum_size()])
		for p in ["Body/Center/SeasonPage/LadderRow/PassCards", "Body/Center/SeasonPage/LadderRow/LadderPanel"]:
			print("SHOT min %s = %s" % [p.get_file(), (_screen.get_node(p) as Control).get_combined_minimum_size()])
	if header != null:
		var body: Control = _screen.get_node_or_null("Body")
		if body != null and body.get_global_rect().position.y < header_bottom - 1:
			bad += 1
			print("SHOT OVERLAP body.y=%.1f header_bottom=%.1f" % [body.get_global_rect().position.y, header_bottom])
	print("SHOT page=%s viewport=%s problems=%d" % [_page, vp.size, bad])


func _inside_scroll(c: Node) -> bool:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


func _save(tag: String) -> void:
	if _out == "":
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s_%s.png" % [_out, tag])
