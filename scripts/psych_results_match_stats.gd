extends RefCounted
## آمارِ مسابقه‌ی جاری و رکوردهای شخصی — برای صفحه‌ی پایان (E4 peak-end).
##
## سرورِ جدید کیلِ قطعی را در match_reward می‌فرستد (commit آن را می‌گیرد)؛
## مرگ و استریک را نمی‌دهد، پس همین‌جا از روی سیگنال‌های Network شمرده می‌شود:
##   کیل        مرگِ حریفی که کمتر از KILL_CREDIT_MS بعد از ضربه‌ی ما مُرد
##              (همان قاعده‌ی world.gd → _is_my_kill)
##   استریک     بیشترین کیلِ پشت‌سرهم بدونِ مردن
##   مرگ        مرگِ خودمان
##
## مرزِ مسابقه از match_id پیامِ round_state می‌آید: match_id تازه یعنی همه
## از صفر. بعد از match_over دیگر چیزی شمرده نمی‌شود.
##
## رکوردهای شخصی (بیشترین کیل، بهترین استریک، برد پیاپی) فقط روی همین
## دستگاه در user:// نگه داشته می‌شوند؛ نمایشی‌اند و هیچ پاداشی به آن‌ها
## وابسته نیست.
##
## Network.gd (آخرِ فایل) یک نمونه از این را می‌سازد: Network.psych_match_stats

const KILL_CREDIT_MS := 700
const SAVE_PATH := "user://psych_results.cfg"

var kills := 0
var deaths := 0
var best_streak := 0
var match_id := ""
## مسابقه‌ای که در جریان است و شمرده می‌شود (بینِ round_state و match_over)
var active := false

var _streak := 0
var _net: Node = null
## match_id هایی که رکوردشان ثبت شده (هر مسابقه فقط یک بار)
var _committed_id := ""
var _last_commit: Dictionary = {}


func _init(net: Node) -> void:
	_net = net
	net.connect("round_state_updated", _on_round_state)
	net.connect("match_over", _on_match_over)
	net.connect("player_died", _on_player_died)


func reset() -> void:
	kills = 0
	deaths = 0
	best_streak = 0
	_streak = 0


func _on_round_state(_alive: Dictionary, _seconds_left: int) -> void:
	var info: Dictionary = _net.get("round_info")
	var id := str(info.get("match_id", ""))
	if id != "" and id != match_id:
		match_id = id
		reset()
		active = true


func _on_match_over(_winner: String, _draw: bool) -> void:
	active = false


func _on_player_died(username: String) -> void:
	if not active:
		return
	var me := str(Global.my_username)
	if username == me:
		deaths += 1
		_streak = 0
		return
	var tree := _net.get_tree()
	var scene := tree.current_scene if tree != null else null
	var p: Node = scene.get_node_or_null("Player") if scene != null else null
	if p == null or not ("last_hit_target" in p):
		return
	if str(p.get("last_hit_target")) != username:
		return
	if Time.get_ticks_msec() - int(p.get("last_hit_ms")) > KILL_CREDIT_MS:
		return
	kills += 1
	_streak += 1
	best_streak = maxi(best_streak, _streak)


## آمارِ این مسابقه را با رکوردهای قبلی مقایسه و ذخیره می‌کند.
## outcome: "win" | "lose" | "draw". هر مسابقه فقط یک بار ثبت می‌شود؛
## صدا زدنِ دوباره همان نتیجه‌ی قبلی را برمی‌گرداند.
## server_kills: کیلِ قطعیِ سرور (match_reward → kills)؛ ‎-1 یعنی سرورِ قدیمی
## که نمی‌فرستد — آن وقت شمارشِ همین کلاینت. رکوردِ کیل با عددِ سرور.
##
## خروجی:
##   kills, deaths, best_streak, tracked (آیا آمارِ این مسابقه را داریم)
##   win_streak       بردِ پیاپی تا همین الان (مساوی زنجیره را نمی‌شکند)
##   records          آرایه‌ی "kills" / "streak" / "win_streak" که رکورد شکستند
func commit(outcome: String, server_kills: int = -1) -> Dictionary:
	var key := match_id if match_id != "" else "local"
	if key == _committed_id and not _last_commit.is_empty():
		return _last_commit
	var from_server := server_kills >= 0
	if from_server:
		kills = server_kills
		# استریک نمی‌تواند از کلِ کیل بیشتر باشد (شمارشِ کلاینت گاهی جا می‌ماند)
		best_streak = mini(best_streak, kills)
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var sec := "u_" + str(Global.my_username)
	var played := int(cfg.get_value(sec, "matches", 0))
	var best_k := int(cfg.get_value(sec, "best_kills", 0))
	var best_s := int(cfg.get_value(sec, "best_streak", 0))
	var ws := int(cfg.get_value(sec, "win_streak", 0))
	var best_ws := int(cfg.get_value(sec, "best_win_streak", 0))
	# «tracked» یعنی مرگ و استریک را خودمان دیدیم؛ کیلِ سرور جدا معتبر است
	var tracked := match_id != ""
	var kills_known := tracked or from_server

	var records: Array[String] = []
	# رکورد فقط وقتی معنی دارد که قبلاً چیزی ثبت شده باشد — اولین مسابقه
	# همیشه «رکورد» است و این دیگر تشویق نیست، شلوغی است
	if kills_known and played > 0 and kills > best_k and kills >= 2:
		records.append("kills")
	if tracked and played > 0 and best_streak > best_s and best_streak >= 2:
		records.append("streak")
	# بازیِ بی‌راند (تمرین/چک‌ها) زنجیره‌ی برد را دست نمی‌زند
	if tracked:
		match outcome:
			"win": ws += 1
			"lose": ws = 0
		if outcome == "win" and ws > best_ws and ws >= 3 and played > 0:
			records.append("win_streak")

	if kills_known:
		cfg.set_value(sec, "matches", played + 1)
		cfg.set_value(sec, "best_kills", maxi(best_k, kills))
	if tracked:
		cfg.set_value(sec, "best_streak", maxi(best_s, best_streak))
	cfg.set_value(sec, "win_streak", ws)
	cfg.set_value(sec, "best_win_streak", maxi(best_ws, ws))
	cfg.save(SAVE_PATH)

	_committed_id = key
	_last_commit = {
		"kills": kills, "deaths": deaths, "best_streak": best_streak,
		"tracked": tracked, "win_streak": ws, "records": records,
		"prev_best_kills": best_k, "kills_from_server": from_server,
	}
	return _last_commit
