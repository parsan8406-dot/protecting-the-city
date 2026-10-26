extends Node
## کارگردانِ «بازی سریع» (docs/game-psychology.md) — موج‌ها، سختیِ نامرئی و صندوقِ تدارکات.
##
## قبلاً بازیِ سریع یک جریانِ بی‌وقفه و یکنواخت از بات‌ها بود: نه اوجی داشت،
## نه نفس‌کشیدنی، نه هدفی جز «زنده بمان». حالا:
##   - C6 موج‌ها: آرام → فشار → اوجِ آخرِ موج (تولدهای تند) → استراحتِ کوتاه.
##     هر سه موج، آخرین حریف «فرمانده» است (اوجِ بزرگ‌تر).
##   - C7/E15 هر موج حداکثر یک تیپِ تازه معرفی می‌کند (یورشی، تک‌تیرانداز،
##     دورزن) و اسمش را همان لحظه می‌گوید.
##   - C5/E13 سختیِ نامرئی: وقتی بازیکن زیرِ فشار است بات‌ها کمی بدتر نشانه
##     می‌گیرند و دیرتر می‌آیند؛ وقتی راحت می‌کُشد کمی تیزتر می‌شوند. اگر دو
##     دستِ آخر زود باخته، دستِ بعد کمی نرم‌تر شروع می‌شود. هرگز به بازیکن
##     گفته نمی‌شود و خسارت/جانِ بات دست نمی‌خورد.
##   - E2 صندوقِ تدارکات: پایانِ هر موج (و گاهی وسطش) یک صندوقِ طلایی جایی
##     دیده‌شدنی می‌افتد، با پیکانِ لبه‌ی صفحه اگر بیرونِ کادر است. محتوایش
##     متغیر است (درمان+فشنگ، رگبار، بمب، دویدن) و گاهی جایزه‌ی دوتایی.
##   - E4/E5 رکورد: بهترین موج و کیلِ هر سطح روی دستگاه نگه داشته می‌شود.
##
## خودِ صحنه (quick_play.gd) بات می‌سازد و جایزه را اعمال می‌کند؛ این‌جا فقط
## تصمیم گرفته می‌شود. هیچ کارِ سنگینی هر فریم انجام نمی‌شود.

const SUPPLY := preload("res://scripts/psych_play_supply.gd")
const SAVE_PATH := "user://psych_play.cfg"

enum Phase { INTRO, FIGHT, BREATHER }

## اولین حریفِ موجِ اول همان ۳ ثانیه‌ی قدیمی می‌رسد
const FIRST_SPAWN := 3.0
const BREATHER := 7.0
const INTRO_LEAD := 1.6
## سهمِ آخرِ موج که تند می‌رسد (اوج)
const SURGE_SHARE := 0.4
const SURGE_GAP_MUL := 0.45
const ELITE_EVERY := 3
## کدام تیپ از کدام موج باز می‌شود (C7: هر بار یکی)
const UNLOCK := {"soldier": 1, "rusher": 2, "marksman": 3, "flanker": 4}
const INTRO_TEXT := {
	"rusher": "حریفِ تازه: یورشی — نزدیک می‌آید و تند می‌زند",
	"marksman": "حریفِ تازه: تک‌تیرانداز — دور می‌ایستد و سنگین می‌زند",
	"flanker": "حریفِ تازه: دورزن — از پهلو می‌آید",
}
const SUPPLY_LIFE := 25.0

## صحنه‌ی بازیِ سریع
var world: Node = null

var wave := 0
var assist := 0.0
var _phase: int = Phase.INTRO
var _timer := FIRST_SPAWN
var _announced := false
var _wave_size := 0
var _spawned := 0
var _introduced := {}
var _bias := 0.0
var _hurt: Array = []          # [ms, amount]
var _kill_ms: Array = []
var _dda_t := 1.0
var _mid_drop_done := false
var _supply: Node2D = null
var _arrow_layer: CanvasLayer = null
var _arrow: Control = null
var _chest_tex: Texture2D = null


func _ready() -> void:
	_bias = _history_bias()
	assist = _bias
	_arrow_layer = CanvasLayer.new()
	_arrow_layer.name = "SupplyArrow"
	_arrow_layer.layer = 19        # زیرِ لایه‌ی حسِ نبرد (۲۰)
	add_child(_arrow_layer)
	_arrow = Control.new()
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arrow.draw.connect(_draw_arrow)
	_arrow_layer.add_child(_arrow)
	var p := "res://assets/ui/psych/chest_closed.png"
	if ResourceLoader.exists(p):
		_chest_tex = load(p)


# ============================================================ رابط

## خسارتی که بازیکن خورد (quick_play._damage_local_player)
func note_player_hurt(amount: int) -> void:
	_hurt.append([Time.get_ticks_msec(), amount])


## یک بات به دستِ بازیکن افتاد
func note_kill() -> void:
	_kill_ms.append(Time.get_ticks_msec())


## آموزش تمام شد: اولین حریف زود برسد
func restart_intro(delay: float) -> void:
	if wave <= 1 and _phase == Phase.INTRO:
		_timer = delay
		_announced = false


## سقفِ حریف‌های هم‌زمان در موجِ فعلی
func cap() -> int:
	var base: int = int(world._pacing()[1]) if world != null else 3
	var w := maxi(wave, 1)
	return mini(base + (1 if w >= 4 else 0) + (1 if w >= 8 else 0), 6)


# ============================================================ حلقه

func _process(delta: float) -> void:
	if world == null or not is_instance_valid(world):
		return
	var player = world.get_node_or_null("Player")
	if player == null or player.is_dead:
		return
	if _supply != null and is_instance_valid(_supply):
		_arrow.queue_redraw()
	if Tutorial.is_running():
		return

	_dda_t -= delta
	if _dda_t <= 0.0:
		_dda_t = 1.0
		_update_assist(player)

	match _phase:
		Phase.INTRO:
			_timer -= delta
			if not _announced and _timer <= INTRO_LEAD:
				_start_wave()
			if _timer <= 0.0:
				_phase = Phase.FIGHT
				_timer = 0.0
		Phase.FIGHT:
			_fight(delta)
		Phase.BREATHER:
			_timer -= delta
			if _timer <= 0.0:
				_phase = Phase.INTRO
				_timer = INTRO_LEAD
				_announced = false


func _start_wave() -> void:
	_announced = true
	wave += 1
	_wave_size = mini(3 + wave, 12)
	_spawned = 0
	_mid_drop_done = false
	var sub := ""
	for kind in UNLOCK:
		if int(UNLOCK[kind]) == wave and INTRO_TEXT.has(kind):
			sub = INTRO_TEXT[kind]
	if wave % ELITE_EVERY == 0:
		sub = (sub + " • " if sub != "" else "") + "آخرِ این موج فرمانده می‌آید"
	_announce("wave", "موج %s" % _fa(wave), sub)
	_sfx("wave")
	if world.has_method("_refresh_round_hud"):
		world._refresh_round_hud()


func _fight(delta: float) -> void:
	_timer -= delta
	var live := _live_bots()
	if _spawned < _wave_size and _timer <= 0.0:
		if live < cap():
			var kind := _pick_kind()
			var is_elite := wave % ELITE_EVERY == 0 and _spawned == _wave_size - 1
			var bot: Node2D = world._spawn_bot(kind, is_elite)
			if bot != null:
				_spawned += 1
				bot.set_assist(assist)
				if is_elite:
					_announce("elite", "", bot.display_name())
			_timer = _gap()
		else:
			# جا که باز شد، نفرِ بعدی بلافاصله نه — یک نفس فاصله
			_timer = 1.4
		# E2 گاهی وسطِ اوج هم صندوقی می‌افتد (نه قابلِ پیش‌بینی، نه زیاد)
		if not _mid_drop_done and wave >= 2 and _spawned == int(ceil(_wave_size * (1.0 - SURGE_SHARE))):
			_mid_drop_done = true
			if randf() < 0.25:
				_drop_supply(false)
	elif _spawned >= _wave_size and live == 0:
		_wave_clear()


## فاصله‌ی دو تولد: پایه از سطح، اوجِ آخرِ موج تندتر، کمکِ نامرئی کندترش می‌کند
func _gap() -> float:
	var base: float = float(world._pacing()[0]) * 0.5
	if _spawned >= int(ceil(_wave_size * (1.0 - SURGE_SHARE))):
		base *= SURGE_GAP_MUL
	return base * (1.0 + 0.3 * maxf(assist, 0.0))


func _wave_clear() -> void:
	_phase = Phase.BREATHER
	_timer = BREATHER
	_announce("wave_clear", "موج %s پاک شد!" % _fa(wave), "صندوقِ تدارکات رسید")
	_sfx("clear")
	LocalSettings.vibrate(35)
	_drop_supply(true)


func _pick_kind() -> String:
	var open: Array = []
	for kind in UNLOCK:
		if wave >= int(UNLOCK[kind]):
			open.append(kind)
	# C7 تیپِ تازه‌ی همین موج نفرِ دوم می‌آید تا حتماً دیده شود
	for kind in open:
		if int(UNLOCK[kind]) == wave and not _introduced.has(kind) and _spawned >= 1:
			_introduced[kind] = true
			return kind
	if open.size() == 1:
		return open[0]
	# سرباز کم‌کم کم‌رنگ می‌شود تا تیپ‌ها بیشتر دیده شوند
	return "soldier" if randf() < 0.25 else open[randi_range(1, open.size() - 1)]


func _live_bots() -> int:
	var n := 0
	for b in world._bots:
		if is_instance_valid(b) and not b.is_dead:
			n += 1
	return n


# ============================================================ C5 سختیِ نامرئی

func _update_assist(player) -> void:
	var now := Time.get_ticks_msec()
	while not _hurt.is_empty() and now - int(_hurt[0][0]) > 6000:
		_hurt.pop_front()
	while not _kill_ms.is_empty() and now - int(_kill_ms[0]) > 15000:
		_kill_ms.pop_front()
	var max_hp := maxf(float(world.max_health), 1.0)
	var hp := float(player.health) / max_hp
	var recent := 0.0
	for h in _hurt:
		recent += float(h[1])
	var sit := 0.0
	if hp < 0.35:
		sit += 0.5
	if recent / max_hp > 0.45:
		sit += 0.4
	if hp > 0.7 and _kill_ms.size() >= 3:
		sit -= 0.5
	var target := clampf(_bias + sit, -0.6, 1.0)
	# آرام جابه‌جا شود تا هیچ پرشِ محسوسی نباشد
	assist = move_toward(assist, target, 0.12)
	for b in world._bots:
		if is_instance_valid(b) and not b.is_dead:
			b.set_assist(assist)


# ============================================================ E2 صندوق

func _drop_supply(end_of_wave: bool) -> void:
	if _supply != null and is_instance_valid(_supply):
		return   # یکی کافی است؛ دوتا روی زمین یعنی انتخابِ بی‌معنی
	var player = world.get_node_or_null("Player")
	if player == null:
		return
	var pos := _supply_spot(player.global_position)
	_supply = SUPPLY.new()
	_supply.name = "SupplyCrate"
	world.add_child(_supply)
	_supply.global_position = pos
	_supply.setup(player, SUPPLY_LIFE)
	_supply.collected.connect(_on_supply_collected)
	if not end_of_wave:
		_announce("supply_drop", "", "دنبالِ پیکانِ طلایی برو")
		_sfx("supply")


## جای صندوق: نه زیرِ پای بازیکن، نه آن سرِ زمین؛ جای باز و بی‌دیوار
func _supply_spot(from: Vector2) -> Vector2:
	var nav = world.bot_nav() if world.has_method("bot_nav") else null
	var arena: Node = world.get_node_or_null("Arena")
	var size: Vector2 = arena.world_size if arena != null else Vector2(2000, 1120)
	for i in 30:
		var p := from + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(260.0, 560.0)
		if p.x < 80.0 or p.y < 80.0 or p.x > size.x - 80.0 or p.y > size.y - 80.0:
			continue
		if nav != null and not nav.is_free(p):
			continue
		if arena != null and arena.has_method("is_blocked") and arena.is_blocked(p):
			continue
		return p
	if arena != null and not arena.spawn_points.is_empty():
		return arena.spawn_points.pick_random()
	return from + Vector2(200, 0)


func _on_supply_collected(pos: Vector2) -> void:
	_arrow.queue_redraw()
	var kinds := [_roll_reward()]
	# E2 گاهی (۱۲٪) جایزه‌ی دوتایی — سورپرایز روی پایه‌ی قابلِ پیش‌بینی
	var jackpot := randf() < 0.12
	if jackpot:
		var second := "rapid" if kinds[0] != "rapid" else "patch"
		kinds.append(second)
	var names: Array[String] = []
	for k in kinds:
		var txt: String = world._grant_supply(k)
		if txt != "":
			names.append(txt)
	CombatFX.plus_burst(pos, 12)
	_sfx("supply")
	LocalSettings.vibrate(30)
	_announce("supply", "جایزه‌ی ویژه!" if jackpot else "", " + ".join(PackedStringArray(names)))


## جایزه با وزن: کم‌جان‌ها بیشتر درمان می‌گیرند (انصاف)، بمب فقط اگر جا هست
func _roll_reward() -> String:
	var player = world.get_node_or_null("Player")
	var hp := float(player.health) / maxf(float(world.max_health), 1.0) if player != null else 1.0
	var table := {"patch": 5.0 if hp < 0.7 else 2.5, "rapid": 2.0, "sprint": 1.0}
	if int(world.bombs_left) < Abilities.BOMB_STOCK:
		table["bomb"] = 2.0
	var total := 0.0
	for k in table:
		total += float(table[k])
	var r := randf() * total
	for k in table:
		r -= float(table[k])
		if r <= 0.0:
			return k
	return "patch"


## پیکانِ لبه‌ی صفحه به سمتِ صندوقی که بیرونِ کادر است
func _draw_arrow() -> void:
	if _supply == null or not is_instance_valid(_supply):
		return
	var vp := _arrow.get_viewport_rect().size
	var sp: Vector2 = _arrow.get_viewport().get_canvas_transform() * _supply.global_position
	var margin := 70.0
	var inner := Rect2(Vector2(margin, margin), vp - Vector2(margin, margin) * 2.0)
	if inner.has_point(sp):
		return
	var c := vp * 0.5
	var d := sp - c
	if d.length() < 1.0:
		return
	# روی لبه‌ی مستطیلِ داخلی
	var t := minf(absf((inner.size.x * 0.5) / maxf(absf(d.x), 0.001)),
		absf((inner.size.y * 0.5) / maxf(absf(d.y), 0.001)))
	var at := c + d * t
	var dir := d.normalized()
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.008)
	var gold := Color(0.98, 0.8, 0.3, pulse)
	var tip := at + dir * 26.0
	var side := dir.orthogonal() * 16.0
	_arrow.draw_circle(at, 30.0, Color(0.04, 0.03, 0.04, 0.78))
	_arrow.draw_arc(at, 30.0, 0.0, TAU, 32, gold, 3.0, true)
	_arrow.draw_colored_polygon(PackedVector2Array([tip + dir * 12.0, tip + side, tip - side]), gold)
	if _chest_tex != null:
		_arrow.draw_texture_rect(_chest_tex, Rect2(at - Vector2(22, 22), Vector2(44, 44)), false)


# ============================================================ E4/E5/E13 تاریخچه

static func _section() -> String:
	var u := str(Global.my_username).strip_edges()
	return u if u != "" else "_guest"


## E13 دو دستِ آخر زود تمام شد → شروعِ نرم‌تر (بی‌صدا)؛ دو دستِ خیلی خوب → کمی تیزتر
static func _history_bias() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 0.0
	var runs: Array = cfg.get_value(_section(), "d%d_runs" % Global.quick_play_difficulty, [])
	if runs.size() >= 3 and int(runs[-1]) <= 2 and int(runs[-2]) <= 2 and int(runs[-3]) <= 2:
		return 0.5
	if runs.size() >= 2 and int(runs[-1]) <= 2 and int(runs[-2]) <= 2:
		return 0.35
	if runs.size() >= 2 and int(runs[-1]) >= 7 and int(runs[-2]) >= 7:
		return -0.2
	return 0.0


## پایانِ دست: ثبت در تاریخچه و رکورد. خروجی برای صفحه‌ی پایان (E4/E5).
func finish_run(kills: int) -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var sec := _section()
	var d := Global.quick_play_difficulty
	var best_wave := int(cfg.get_value(sec, "d%d_best_wave" % d, 0))
	var best_kills := int(cfg.get_value(sec, "d%d_best_kills" % d, 0))
	var reached := maxi(wave, 1)
	var out := {"wave": reached, "kills": kills, "best_wave": best_wave, "best_kills": best_kills,
		"new_record": false, "near": ""}
	# اولین دست «رکورد» حساب نمی‌شود — چیزی برای شکستن نبود
	var had_record := best_kills > 0 or best_wave > 1
	if kills > best_kills or reached > best_wave:
		out["new_record"] = had_record
		cfg.set_value(sec, "d%d_best_wave" % d, maxi(best_wave, reached))
		cfg.set_value(sec, "d%d_best_kills" % d, maxi(best_kills, kills))
	elif had_record:
		# E5 نزدیک‌برد: فقط وقتی واقعاً نزدیک بود
		if best_kills - kills <= 3 and best_kills > 0:
			out["near"] = "فقط %s کیل تا رکوردت (%s)" % [_fa(best_kills - kills + 1), _fa(best_kills)]
		elif best_wave - reached == 1:
			out["near"] = "یک موج تا رکوردت (موج %s)" % _fa(best_wave)
	var runs: Array = cfg.get_value(sec, "d%d_runs" % d, [])
	runs.append(reached)
	while runs.size() > 3:
		runs.pop_front()
	cfg.set_value(sec, "d%d_runs" % d, runs)
	cfg.save(SAVE_PATH)
	if _supply != null and is_instance_valid(_supply):
		_supply.queue_free()
	return out


# ============================================================ کمکی

func _announce(tag: String, title: String, sub: String) -> void:
	var feel = world.get("feel") if world != null else null
	if feel != null and feel.has_method("announce"):
		feel.announce(tag, title, sub)


func _sfx(name: String) -> void:
	var feel = world.get("feel") if world != null else null
	if feel != null and feel.has_method("play_sfx"):
		feel.play_sfx(name)


static func _fa(n: int) -> String:
	var digits := "۰۱۲۳۴۵۶۷۸۹"
	var out := ""
	for ch in str(n):
		out += digits[int(ch)] if ch >= "0" and ch <= "9" else ch
	return out
