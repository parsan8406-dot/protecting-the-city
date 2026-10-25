extends Node

signal player_moved(username, new_position, new_rotation)
signal server_players_updated(players_dict)
## سوکت باز شد و join فرستاده شد
signal connected
signal player_shot(username, pos, rot)
signal health_updated(username, new_health)
signal player_died(username)
signal game_countdown(seconds)
signal game_started
signal heal_success(username, new_health)
## سرور ضربه‌ی ما را رد کرد (تاسِ دقت) — فقط برای نشان دادنِ «خطا»
signal hit_missed(target: String)
signal heal_cooldown_started(username, seconds)
signal bomb_thrown(data)
signal bomb_explosion(data)
## سرور نقطه‌ی شروع را تعیین کرده — کلاینت باید همان‌جا ظاهر شود
signal spawn_assigned(pos: Vector2)
## سرور گفته این مسابقه روی کدام زمین است و محافظِ تولد چند ثانیه است.
## هر حالت زمینِ خودش را دارد (سرور: arena.go → ArenaForMode)، پس کلاینت
## نقشه را حدس نمی‌زند.
signal arena_assigned(map_name: String, shield_seconds: float, theme: String)
## یک بازیکن (یا بات) دوباره زنده شد — عملیات انتقام.
## shield_seconds همان محافظِ بلوریِ تولد است؛ سرور تا آن لحظه هیچ تیری را
## روی این بازیکن قبول نمی‌کند.
signal player_respawned(username: String, pos: Vector2, health: int, shield_seconds: float)
## سرور حرکت را رد کرد (دیوارگذر / سرعت غیرمجاز) — باید به این نقطه اسنپ کنیم
signal position_corrected(pos: Vector2)
## پیام تازه‌ی چت (خصوصی / شهر / جهانی) از سرور رسید.
## دیکشنری همان شکل پیام است: {room, channel, message_id, sender_id,
## sender_name, sender_avatar, sender_level, sender_clan, text, created_at}
signal chat_message_received(data: Dictionary)

## اگر موقع ورود به آرنا سوکت هنوز باز نشده باشد، join می‌ماند تا باز شود
var _arena_join_pending := false

## --- راندِ حذفی (سرور: match_round.go) ---
## alive نگاشتِ «تیم -> تعداد زنده‌ها» است و seconds_left ثانیه‌های مانده.
signal round_state_updated(alive: Dictionary, seconds_left: int)
## پایانِ مسابقه. draw یعنی وقت تمام شد و هر دو تیم زنده بودند.
signal match_over(winner_team: String, draw: bool)
## پاداشِ نهایی که سرور حساب کرده — کلاینت خودش چیزی حساب نمی‌کند.
signal match_reward(data: Dictionary)
## کسی توانایی زد (sprint / guard / laser / team_heal / bomb). data همان پیامِ
## سرور است: {username, kind, active, cooldown, x, y, ...}
signal ability_used(data: Dictionary)
## ماموریت‌های بازِ این مسابقه (اهداف) — یک بار اولِ مسابقه
signal objectives_received(list: Array)
## یک هدف جلو رفت یا تمام شد
signal objective_updated(id: String, progress: int, target: int, done: bool)
## رفت‌وبرگشتِ پینگ به میلی‌ثانیه
signal ping_measured(ms: int)

## --- عملیات حذف شیطان (سرور: demon.go) ---
## وضعیتِ شیطانِ وسطِ زمین: جا، جان و آسیبی که هر تیم زده.
## data: {x, y, health, max_health, radius, damage: {تیم: آسیب}, alive}
signal demon_state(data: Dictionary)
## شیطان یک ناحیه را نشانه گرفت — حدود دو ثانیه‌ی دیگر می‌ترکد.
## این تنها اخطار است؛ بعدش دیگر فرصتی نیست.
signal demon_blast_warned(pos: Vector2, radius: float, delay: float)
## همان ناحیه ترکید. هر که تویش بوده را سرور خودش زده؛ این فقط افکت است.
signal demon_blast_fired(pos: Vector2, radius: float)
## شیطان افتاد. team تیمی است که ضربه‌ی آخر را زد — فقط برای افکت؛ برنده را
## آسیبِ کل تعیین می‌کند و با match_over می‌آید.
signal demon_slain(team: String, pos: Vector2)

## آخرین وضعیتِ راند، همان‌طور که سرور فرستاده:
##   mode         شناسه‌ی حالت ("revenge" و ...)
##   respawn      مرگ موقتی است؟ (زمینِ انتقام: بله)
##   score_kills  برنده با تعدادِ کشته تعیین می‌شود؟
##   demon        وسطِ زمین شیطان هست؟ (عملیات حذف شیطان)
##   score        {تیم: کشته}
##   alive        {تیم: زنده}
##   seconds_left ثانیه‌های مانده
## سیگنالِ round_state_updated عمداً دست‌نخورده ماند (ابزارهای tools/ به آن
## وصل‌اند)؛ هرچه اضافه شد این‌جا می‌نشیند.
var round_info: Dictionary = {}

## آخرین وضعیتِ شیطان (پیامِ demon_state). خالی یعنی این حالت شیطان ندارد
## یا هنوز چیزی نرسیده. نوارِ بالای صفحه، فلشِ راهنما و مینی‌مپ همه از این
## می‌خوانند تا هرکدام جدا به سیگنال وصل نشوند.
var demon_info: Dictionary = {}

var socket = WebSocketPeer.new()
var is_connected = false
var current_players = {}

## اتصال دوباره بعد از قطع شدن اینترنت موبایل: فاصله‌ی تلاش‌ها کم‌کم بیشتر
## می‌شود تا باتری و سرور با تلاش‌های پشت‌سرهم هدر نروند.
const RECONNECT_MIN := 2.0
const RECONNECT_MAX := 20.0
var _reconnect_delay := RECONNECT_MIN
var _reconnect_at := -1.0
## یک بار اتصال خواسته شده؟ (قبل از رسیدن دیتای بازیکن تلاش دوباره معنی ندارد)
var _wanted := false

## سوکتِ مرده: روی اینترنتِ موبایل (عوض شدنِ وای‌فای/دیتا، تونل، آسانسور)
## اتصالِ TCP اغلب بی‌صدا می‌میرد و وب‌سوکت تا ده‌ها ثانیه «باز» می‌ماند —
## بازیکن وسطِ مسابقه یخ می‌زد و هیچ تلاشی برای اتصالِ دوباره نمی‌شد.
## HUDِ بازی هر ۲ ثانیه پینگ می‌فرستد؛ اگر پینگ داریم می‌فرستیم ولی این‌قدر
## هیچ پیامی نرسیده، سوکت را دور می‌اندازیم و فوراً از نو وصل می‌شویم.
const DEAD_SOCKET_MS := 7000
## پینگی که از این قدیمی‌تر باشد یعنی کسی منتظرِ جواب نیست (منو) — آن‌جا
## سکوتِ طولانی طبیعی است و نباید اتصال را بشکنیم.
const PING_ACTIVE_MS := 3000
var _last_rx_ms := 0
var _last_ping_ms := 0
## اولین پینگی که هنوز بعد از آن هیچ پیامی نرسیده (۰ = منتظرِ جوابی نیستیم).
## سکوت از همین لحظه شمرده می‌شود، نه از آخرین پیامِ دریافتی: توی منو و
## صفحه‌ی جستجو سرور ده‌ها ثانیه چیزی نمی‌فرستد، و قبلاً همان اولین پینگِ
## ورود به آرنا فوراً «سوکتِ مرده» تشخیص داده می‌شد — اتصال از نو ساخته
## می‌شد، سرور بازیکن را از مسابقه بیرون می‌انداخت و زمین خالی می‌ماند.
var _ping_wait_since := 0
## لیستِ بازیکن‌ها با ظاهر و تراز از ۶۴KBِ پیش‌فرض بزرگ‌تر می‌شود
const INBOUND_BUFFER := 1 << 20

func _ready():
	Global.player_data_loaded.connect(connect_to_server)

## آدرس وب‌سوکت از همان آدرس پایه‌ی HTTP ساخته می‌شود (http→ws، https→wss)
func _ws_url() -> String:
	return Global.SERVER_BASE.replace("http", "ws") + "/ws"

func connect_to_server():
	_wanted = true
	set_process(true)
	# player_data_loaded با هر رفرشِ دیتا دوباره فایر می‌شود؛ اتصالِ باز یا در
	# حال باز شدن را نباید از نو ساخت، وگرنه سرور کلاینتی بی‌نام می‌بیند و
	# چت و نوتیف‌ها دیگر به این بازیکن نمی‌رسند
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN or state == WebSocketPeer.STATE_CONNECTING:
		return
	socket = WebSocketPeer.new()
	socket.inbound_buffer_size = INBOUND_BUFFER
	var err = socket.connect_to_url(_ws_url())
	if err != OK:
		print("❌ خطا در اتصال به سرور")
		_schedule_reconnect()

## بعد از عوض شدن حساب (ورود با گوگل): اتصال قبلی بسته و با حساب تازه باز می‌شود
func reset_connection() -> void:
	if socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		socket.close()
	socket = WebSocketPeer.new()
	is_connected = false
	_reconnect_at = -1.0
	_reconnect_delay = RECONNECT_MIN

## سوکت را بی‌معطلی دور می‌اندازد و دوباره وصل می‌شود (بدونِ backoff).
## close() روی اتصالِ مرده تا ده‌ها ثانیه در CLOSING می‌ماند، پس منتظرش
## نمی‌مانیم و یک WebSocketPeerِ تازه می‌سازیم.
func _force_reconnect() -> void:
	print("⚠️ مدتی پیامی از سرور نرسید — اتصالِ دوباره")
	if socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		socket.close()
	socket = WebSocketPeer.new()
	is_connected = false
	_last_ping_ms = 0
	_ping_wait_since = 0
	_reconnect_at = -1.0
	_reconnect_delay = RECONNECT_MIN
	connect_to_server()

func _schedule_reconnect() -> void:
	if not _wanted or _reconnect_at > 0.0:
		return
	_reconnect_at = Time.get_ticks_msec() / 1000.0 + _reconnect_delay
	_reconnect_delay = minf(_reconnect_delay * 2.0, RECONNECT_MAX)

func _notification(what: int) -> void:
	# برگشت از پس‌زمینه (تماس، مینیمایز): اگر اتصال افتاده، همان لحظه وصل شو
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _wanted and not Global.offline_mode \
				and socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_reconnect_at = -1.0
			_reconnect_delay = RECONNECT_MIN
			connect_to_server()

func _process(_delta):
	# بازی سریع آفلاین است — نه چیزی می‌فرستیم نه چیزی می‌خوانیم، وگرنه
	# بازیکن وسطِ تمرینِ تک‌نفره در دنیای آنلاین هم ظاهر می‌شود.
	if Global.offline_mode:
		return
	if _reconnect_at > 0.0 and Time.get_ticks_msec() / 1000.0 >= _reconnect_at:
		_reconnect_at = -1.0
		connect_to_server()
	socket.poll()
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not is_connected:
			is_connected = true
			_reconnect_delay = RECONNECT_MIN
			_last_rx_ms = Time.get_ticks_msec()
			print("✅ متصل با آیدی: ", Global.my_username)
			# ورود به آرنا ممکن است قبل از باز شدنِ سوکت درخواست شده باشد؛ آن‌وقت
			# همان joinِ آرنا کافی است (هویت را هم می‌رساند). قبلاً joinِ منو و
			# joinِ آرنا در یک فریم می‌رفتند و سرور دومی را دور می‌ریخت —
			# زمینِ خالی و تایمرِ --:--.
			send_join_request(_arena_join_pending)
			_arena_join_pending = false
			connected.emit()
		if _arena_join_pending:
			_arena_join_pending = false
			send_join_request(true)
		if socket.get_available_packet_count() > 0:
			_last_rx_ms = Time.get_ticks_msec()
		while socket.get_available_packet_count() > 0:
			var packet = socket.get_packet().get_string_from_utf8()
			var messages = packet.split("\n", false)
			for msg in messages:
				msg = msg.strip_edges()
				if msg == "":
					continue
				var data = JSON.parse_string(msg)
				if typeof(data) == TYPE_DICTIONARY:
					var msg_type = data.get("type", "")
					if msg_type == "update_players":
						current_players = data["players"]
						server_players_updated.emit(current_players)
					elif msg_type == "move":
						var rot = data.get("rot", 0.0)
						player_moved.emit(data["username"], Vector2(data["x"], data["y"]), rot)
					elif msg_type == "shoot":
						player_shot.emit(data["username"], Vector2(data["x"], data["y"]), data["rot"])
					elif msg_type == "health_update":
						health_updated.emit(data["username"], data["health"])
					elif msg_type == "die":
						# C10: killer/weapon از سرورِ جدید (سرورِ قدیمی نمی‌فرستد)
						last_death = data
						player_died.emit(data["username"])
					elif msg_type == "countdown":
						game_countdown.emit(data.get("seconds", 3))
					elif msg_type == "game_start":
						game_started.emit()
					elif msg_type == "heal_success":
						heal_success.emit(data["username"], data["health"])
					elif msg_type == "hit_miss":
						hit_missed.emit(str(data.get("target", "")))
					elif msg_type == "heal_cooldown":
						heal_cooldown_started.emit(data["username"], data.get("seconds", 12))
					elif msg_type == "bomb_thrown":
						bomb_thrown.emit(data)
					elif msg_type == "bomb_explosion":
						bomb_explosion.emit(data)
					elif msg_type == "spawn":
						arena_assigned.emit(
							str(data.get("map", "map")),
							float(data.get("shield_seconds", 0.0)),
							str(data.get("theme", "")))
						spawn_assigned.emit(Vector2(data.get("x", 0.0), data.get("y", 0.0)))
					elif msg_type == "respawn":
						player_respawned.emit(
							str(data.get("username", "")),
							Vector2(data.get("x", 0.0), data.get("y", 0.0)),
							int(data.get("health", 0)),
							float(data.get("shield_seconds", 0.0)))
					elif msg_type == "position_correction":
						position_corrected.emit(Vector2(data.get("x", 0.0), data.get("y", 0.0)))
					elif msg_type == "chat_message":
						# صحنه‌ی چت اگر باز باشد خودش این را می‌گیرد؛
						# در غیر این صورت فقط نشان قرمز منوی اصلی بالا می‌رود
						chat_message_received.emit(data)
						# نشان منوی اصلی فقط پیام دوستان را می‌شمارد؛ رگبار
						# پیام‌های جهانی/شهر نباید درخواست اضافه بفرستد
						if str(data.get("channel", "")) == "private":
							Global.on_chat_message()
					elif msg_type == "round_state":
						round_info = data
						round_state_updated.emit(
							data.get("alive", {}), int(data.get("seconds_left", 0)))
					elif msg_type == "match_over":
						round_info["final_score"] = data.get("score", {})
						# در حالتِ شکار، عددی که روی صفحه‌ی پایان معنی دارد
						# آسیبِ زده‌شده به شیطان است نه تعدادِ کشته
						if data.has("demon_damage"):
							round_info["final_demon_damage"] = data.get("demon_damage", {})
							round_info["demon_slain"] = bool(data.get("demon_slain", false))
						match_over.emit(
							str(data.get("winner_team", "")), bool(data.get("draw", false)))
					elif msg_type == "demon_state":
						demon_info = data
						demon_state.emit(data)
					elif msg_type == "demon_blast_warn":
						demon_blast_warned.emit(
							Vector2(data.get("x", 0.0), data.get("y", 0.0)),
							float(data.get("radius", 190.0)),
							float(data.get("delay", 2.0)))
					elif msg_type == "demon_blast":
						demon_blast_fired.emit(
							Vector2(data.get("x", 0.0), data.get("y", 0.0)),
							float(data.get("radius", 190.0)))
					elif msg_type == "demon_slain":
						demon_slain.emit(str(data.get("team", "")),
							Vector2(data.get("x", 0.0), data.get("y", 0.0)))
					elif msg_type == "match_reward":
						match_reward.emit(data)
					elif msg_type == "ability":
						ability_used.emit(data)
					elif msg_type == "objectives":
						var list = data.get("list", [])
						objectives_received.emit(list if list is Array else [])
					elif msg_type == "objective_update":
						objective_updated.emit(str(data.get("id", "")),
							int(data.get("progress", 0)), int(data.get("target", 1)),
							bool(data.get("done", false)))
					elif msg_type == "pong":
						var sent := int(data.get("t", 0))
						if sent > 0:
							ping_measured.emit(maxi(Time.get_ticks_msec() - sent, 0))
					elif msg_type == "notification":
						# نوتیفیکیشن بلادرنگ سرور (درخواست دوستی، هدیه، ...)
						# مستقیم به Global می‌رود تا تب‌های باز خودشان را رفرش کنند
						# و نشان قرمز تاپ‌بار همان لحظه آپدیت شود.
						Global.on_social_event(str(data.get("kind", "")))
		# سوکتِ مرده (توضیح کنارِ DEAD_SOCKET_MS)
		var now_ms := Time.get_ticks_msec()
		if _ping_wait_since > 0 and _last_rx_ms >= _ping_wait_since:
			_ping_wait_since = 0  # جواب (یا هر پیامی) بعد از پینگ رسید
		if _ping_wait_since > 0 and now_ms - _last_ping_ms < PING_ACTIVE_MS and now_ms - _ping_wait_since > DEAD_SOCKET_MS:
			_force_reconnect()
	elif state == WebSocketPeer.STATE_CLOSED:
		if is_connected:
			print("⚠️ اتصال به سرور قطع شد — تلاش دوباره...")
		is_connected = false
		_schedule_reconnect()

## joinِ معمولی (موقعِ باز شدنِ سوکت) فقط به سرور می‌گوید این کلاینت کیست،
## تا چت و نوتیف برایش مسیر پیدا کند — زمینِ بازی را شروع نمی‌کند.
## joinِ آرنا (arena = true) است که بات‌ها و راند را می‌سازد.
func send_join_request(arena: bool = false):
	if not is_connected:
		return
	var data = {
		"type": "join", "username": Global.my_username,
		"character": Global.current_character, "weapon": Global.current_weapon,
		"arena": arena,
		# حسابِ وصل‌شده به گوگل بدون توکن دستگاه وارد هاب نمی‌شود
		"token": Global.session_token,
	}
	socket.send_text(JSON.stringify(data))


## ورود به زمینِ بازی — دوباره join می‌فرستد.
##
## چرا لازم است: join فقط یک بار و موقعِ باز شدنِ سوکت فرستاده می‌شد، یعنی
## همان اولِ اجرای بازی و توی منوی اصلی. آن لحظه بازیکن هنوز هیچ مسابقه‌ای
## ندارد، پس سرور او را با MatchID خالی ثبت می‌کرد و — مهم‌تر — کدِ آوردنِ
## بات‌های همان مسابقه اصلاً اجرا نمی‌شد. نتیجه: بازیکن وارد زمین می‌شد و
## هیچ رباتی آن‌جا نبود.
##
## حالا با هر ورود به آرنا یک join تازه می‌رود، پس سرور تیم، مسابقه و
## بات‌های همان راند را از نو می‌سازد.
func enter_arena() -> void:
	if Global.offline_mode:
		# بی‌صدا برنگرد: اگر یک صحنه‌ی آنلاین به اینجا برسد، بازیکن هیچ‌وقت
		# وارد زمین نمی‌شود و علتش روی صفحه پیدا نیست — نه راندی، نه رباتی،
		# نه بازیکنِ دیگری. یک بار همین اتفاق افتاد چون offline_mode از
		# بازیِ سریع نشت کرده بود.
		push_warning("enter_arena در حالت آفلاین صدا زده شد — سرور خبردار نمی‌شود")
		return
	# وضعیتِ راندِ قبلی نباید به مسابقه‌ی تازه نشت کند: بدونِ این، بازیکنی
	# که از یک راندِ شیطان مستقیم وارد «عملیات ضربت» می‌شود تا رسیدنِ اولین
	# round_state هنوز نوارِ جانِ شیطان و فلشِ راهنما را روی صفحه دارد.
	round_info.clear()
	demon_info.clear()
	if is_connected:
		send_join_request(true)
	else:
		_arena_join_pending = true

## بعد از عوض کردن کاراکتر/اسلحه در منو، سرور باید همان لحظه خبردار شود.
## join فقط یک بار موقع باز شدن سوکت فرستاده می‌شود، پس بدون این پیام نسخه‌ی
## درون‌حافظه‌ی هاب روی تجهیزاتِ لحظه‌ی اتصال گیر می‌کند و موقع ورود به آرنا
## همان را پخش می‌کند — یعنی انتخاب تازه‌ی بازیکن نادیده گرفته می‌شود.
func send_equipment_update():
	if is_connected:
		var data = {
			"type": "equip",
			"username": Global.my_username,
			"character": Global.current_character,
			"weapon": Global.current_weapon,
		}
		socket.send_text(JSON.stringify(data))

func send_move_data(pos: Vector2, rot: float):
	if is_connected:
		var data = {"type": "move", "x": pos.x, "y": pos.y, "rot": rot}
		socket.send_text(JSON.stringify(data))

func send_shoot_data(pos: Vector2, rot: float):
	if is_connected:
		var data = {"type": "shoot", "x": pos.x, "y": pos.y, "rot": rot}
		socket.send_text(JSON.stringify(data))

func send_hit_data(target_username: String):
	if is_connected:
		var data = {"type": "hit", "target": target_username}
		socket.send_text(JSON.stringify(data))

func send_heal_request():
	if is_connected:
		var data = {"type": "heal", "username": Global.my_username}
		socket.send_text(JSON.stringify(data))

## توانایی‌های دکمه‌ای: "sprint"، "guard"، "laser"، "team_heal".
## سرور قفل و مدت را خودش حساب می‌کند و با پیامِ ability جواب می‌دهد.
func send_ability(kind: String) -> void:
	if is_connected:
		socket.send_text(JSON.stringify({"type": kind}))


## اندازه‌گیریِ پینگ — سرور همان t را برمی‌گرداند
func send_ping() -> void:
	if is_connected:
		_last_ping_ms = Time.get_ticks_msec()
		if _ping_wait_since == 0:
			_ping_wait_since = _last_ping_ms
		socket.send_text(JSON.stringify({"type": "ping", "t": _last_ping_ms}))


## بیرون رفتن از مسابقه وسطِ بازی (سوکت برای چت و منو باز می‌ماند)
func send_leave_arena() -> void:
	if is_connected:
		socket.send_text(JSON.stringify({"type": "leave_arena"}))


## پرتاب بمب. distance فاصله‌ای است که بازیکن نشانه گرفته؛ سرور آن را به
## بردِ کاراکتر محدود می‌کند، پس فرستادنِ عدد بزرگ فایده‌ای ندارد.
func send_bomb_request(direction: Vector2, distance: float = 0.0):
	if is_connected:
		var data = {
			"type": "bomb",
			"username": Global.my_username,
			"dir_x": direction.x,
			"dir_y": direction.y,
			"dist": distance,
		}
		socket.send_text(JSON.stringify(data))


# ==================== E4 peak-end: آمارِ همین مسابقه (psych_results) ====================
## کیل/استریک/مرگِ مسابقه‌ی جاری برای صفحه‌ی پایان، و رکوردهای شخصی.
## خودش به سیگنال‌های همین فایل وصل می‌شود — scripts/psych_results_match_stats.gd
var psych_match_stats = preload("res://scripts/psych_results_match_stats.gd").new(self)

## آخرین پیامِ die — {username, killer?, weapon?}؛ weapon یکی از gun/bomb/laser
var last_death: Dictionary = {}


## قاتلِ اعلام‌شده توسطِ سرور برای این مرگ، یا "" اگر سرور نگفته
func death_killer(username: String) -> String:
	if str(last_death.get("username", "")) != username:
		return ""
	return str(last_death.get("killer", ""))
