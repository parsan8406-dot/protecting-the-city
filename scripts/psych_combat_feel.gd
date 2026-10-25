extends CanvasLayer
## «حسِ نبرد» — لایه‌ی لحظه‌به‌لحظه‌ی مسابقه (docs/game-psychology.md).
##
## زمینِ بازی (world.gd و بازیِ سریع که از آن ارث می‌برد) یکی از این را می‌سازد
## و خودش را در CombatFX.feel ثبت می‌کند تا بات‌ها و بازیکن هم پیدایش کنند.
## کارهایش:
##   - اعلانِ کیل‌های پشتِ‌سرِ‌هم بالای وسطِ صفحه (اولین حذف، دوتایی، سه‌تایی،
##     بی‌مهار، انتقام) — با صف و ادغام، نه رگبارِ بنر (V7/E15)
##   - تأییدِ هر کیلِ خودت: سکه/حلقه‌ی طلایی، دینگ، لرزش، hit-stop (V7/E11)
##   - کمانِ قرمزِ جهتِ آسیب دورِ مرکزِ صفحه (V4) و صدای ضربه
##   - ضربانِ قلب وقتی جان کم است (E11، هم‌گام با حاشیه‌ی قرمزِ HUD)
##   - کارتِ «چه کسی با چه چیزی زدت» + یک نکته‌ی کوتاهِ کاربردی بعد از مرگ،
##     و شمارشِ برگشت در حالت‌های ریسپاون‌دار (C10/E13)
##   - «برگشتی! محافظ داری» بعد از تولد (E13)
##   - ۳۰ و ۱۰ ثانیه‌ی آخرِ راند + تیک‌تاکِ ۵ ثانیه‌ی آخر (C6)
##
## سرور در پیامِ die قاتل را نمی‌فرستد؛ پس منبعِ هر ضربه از روی آخرین شلیک‌ها،
## بمب‌ها، لیزرها و نفرینِ شیطان که همین کلاینت دیده حدس زده می‌شود (_attribute).
##
## هیچ‌کدام از کنترل‌های این لایه لمس نمی‌گیرد (MOUSE_FILTER_IGNORE)، پس روی
## جوی‌استیک و دکمه‌ها اثری ندارد. همه‌چیز یک بار در _ready ساخته می‌شود.

const SFX := preload("res://scripts/psych_combat_sfx.gd")

## همان واحدِ طراحیِ GameHUD (ارتفاعِ ۷۲۰، عرض آزاد)
const DESIGN_H := 720.0
const LAYER := 20     # بالای HUD (لایه‌ی ۱)، زیرِ تنظیمات (۱۱۰) و صفحه‌ی نتیجه (۱۱۵)

const FONT_TEXT_PATH := "res://fonts/SJADIDBD.TTF"
const FONT_NUM_PATH := "res://fonts/Lalezar-Regular.ttf"
const PSYCH_ICON := "res://assets/ui/psych/%s.png"
const HUD_ICON := "res://assets/ui/hud/%s.png"

const COL_GOLD := Color(0.98, 0.8, 0.3)
const COL_RED := Color(0.94, 0.2, 0.2)
const COL_TEXT := Color(0.96, 0.94, 0.9)
const COL_DIM := Color(0.78, 0.76, 0.72)
const COL_PANEL := Color(0.04, 0.03, 0.04, 0.84)

## دو کیل با فاصله‌ی کمتر از این یعنی «پشتِ‌سرِ‌هم» (مولتی‌کیل)
const MULTI_WINDOW_MS := 4000
## بی‌مهار: هر چند کیل بدونِ مرگ
const STREAK_STEP := 5
const CALLOUT_TIME := 1.6
## سرور برای هر کیل ۵ سکه می‌دهد تا سقفِ ۲۵ (game_modes.go → coinsPerKill)
const COINS_PER_KILL := 5
const KILL_COINS_CAP := 25

## پنجره‌ی حدس زدنِ منبعِ ضربه
const SHOT_WINDOW_MS := 900
const BOMB_WINDOW_MS := 3200
const DEMON_WINDOW_MS := 700
const NOTE_GUN_MS := 700
const NOTE_BOMB_MS := 2800
## کمان‌های جهتِ آسیب
const ARC_LIFE := 1.0
const ARC_R := 128.0
const ARC_HALF := 0.36
const N_ARCS := 4
## مدتِ ماندنِ کارتِ قاتل در حالت‌های بی‌ریسپاون
const CARD_TIME := 6.0
const HEART_PERIOD := 1.2   # دو برابرِ LOW_PULSE_TIMEِ game_hud.gd — هم‌گام با حاشیه

## اعلان‌ها: متن، آیکنِ آرت، اولویت (بزرگ‌تر جای کوچک‌تر را می‌گیرد)، رنگ
const CALLOUTS := {
	"first_blood": {"text": "اولین حذف!", "icon": "streak_first_blood", "prio": 2},
	"revenge": {"text": "انتقام!", "icon": "streak_revenge", "prio": 2},
	"double": {"text": "دوتایی!", "icon": "streak_double", "prio": 3},
	"triple": {"text": "سه‌تایی!", "icon": "streak_triple", "prio": 4},
	"rampage": {"text": "بی‌مهار!", "icon": "streak_rampage", "prio": 5},
	"respawn": {"text": "برگشتی!", "icon": "", "prio": 1},
	"final30": {"text": "۳۰ ثانیه‌ی آخر!", "icon": "", "prio": 1, "red": true},
	"final10": {"text": "۱۰ ثانیه!", "icon": "", "prio": 1, "red": true},
}

## صحنه‌ی زمین (world.gd) — بازیکن، حریف‌ها و آیکنِ آیتم از آن خوانده می‌شود
var world: Node = null

var _font_text: Font = null
var _font_num: Font = null
var _stage: Control = null

# --- اعلان ---
var _callout: HBoxContainer = null
var _co_icon: TextureRect = null
var _co_title: Label = null
var _co_sub: Label = null
var _co_left := 0.0
var _co_prio := -1
var _co_queue: Array = []
var _co_tw: Tween = null

# --- کمانِ آسیب ---
var _arc_layer: Control = null
var _arcs: Array = []          # [{ang, t, k}]

# --- کارتِ قاتل ---
var _card: PanelContainer = null
var _card_weapon: TextureRect = null
var _card_title: Label = null
var _card_name: Label = null
var _card_tip_icon: TextureRect = null
var _card_tip: Label = null
var _card_respawn: Label = null
var _card_left := 0.0
var _respawn_left := 0.0
var _card_tw: Tween = null

# --- صدا ---
var _players: Array[AudioStreamPlayer] = []
var _i_player := 0
var _heart: AudioStreamPlayer = null
var _last_sound_ms := {}

# --- وضعیتِ کیل ---
var _kills_life := 0
var _match_kills := 0
var _multi := 0
var _last_kill_ms := -100000
var _first_seen := false
var _last_killer := ""

# --- منبعِ ضربه ---
var _shots := {}               # نام -> {pos, dir, ms}
var _bombs: Array = []         # [{by, pos, r, ms}]
var _lasers := {}              # نام -> تا چه زمانی (ms) پرتوش روشن است
var _demon_hit := {}
var _noted := {}               # بات‌های آفلاین خودشان می‌گویند (note_attack)
var _last_attack := {}
var _recent_attackers := {}    # نام -> ms

# --- جانِ کم و شمارشِ راند ---
var _low := false
var _low_since_ms := 0
var _heart_t := 0.0
var _round_left := -1.0
var _round_peak := 0.0
var _said_30 := false
var _said_10 := false
var _last_tick := -1


func _ready() -> void:
	layer = LAYER
	if ResourceLoader.exists(FONT_TEXT_PATH):
		_font_text = load(FONT_TEXT_PATH)
	if ResourceLoader.exists(FONT_NUM_PATH):
		_font_num = load(FONT_NUM_PATH)

	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_build_arcs()
	_build_callout()
	_build_card()
	_build_audio()
	_layout()
	get_viewport().size_changed.connect(_layout)
	if not SafeArea.changed.is_connected(_layout):
		SafeArea.changed.connect(_layout)

	# منبعِ ضربه‌ها — همان پیام‌هایی که world.gd هم می‌گیرد
	Network.player_shot.connect(_on_player_shot)
	Network.bomb_thrown.connect(_on_bomb_thrown)
	Network.ability_used.connect(_on_ability)
	Network.demon_blast_fired.connect(_on_demon_blast)
	Network.round_state_updated.connect(_on_round_state)
	Network.match_over.connect(_on_match_over)


func _enter_tree() -> void:
	CombatFX.feel = self


func _exit_tree() -> void:
	if CombatFX.feel == self:
		CombatFX.feel = null


# ============================================================ ساخت

func _label(font: Font, size: int, colour: Color, outline := 8) -> Label:
	var l := Label.new()
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _icon_rect(px: float) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## آیکنِ آرتِ روانشناسی اگر رسیده باشد، وگرنه جایگزینِ HUD، وگرنه null
static func _load_icon(psych_name: String, fallback_hud := "") -> Texture2D:
	if psych_name != "":
		var p := PSYCH_ICON % psych_name
		if ResourceLoader.exists(p):
			return load(p)
	if fallback_hud != "":
		var h := HUD_ICON % fallback_hud
		if ResourceLoader.exists(h):
			return load(h)
	return null


func _build_callout() -> void:
	_callout = HBoxContainer.new()
	_callout.name = "Callout"
	_callout.alignment = BoxContainer.ALIGNMENT_CENTER
	_callout.add_theme_constant_override("separation", 12)
	_callout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_callout.visible = false
	_stage.add_child(_callout)

	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override("separation", -6)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_callout.add_child(texts)
	_co_title = _label(_font_text, 46, COL_GOLD, 12)
	_co_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texts.add_child(_co_title)
	_co_sub = _label(_font_text, 19, COL_TEXT, 6)
	_co_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texts.add_child(_co_sub)

	# متن فارسی است و از راست خوانده می‌شود، پس نشان سمتِ راستِ متن می‌نشیند
	_co_icon = _icon_rect(76.0)
	_callout.add_child(_co_icon)


func _build_arcs() -> void:
	_arc_layer = Control.new()
	_arc_layer.name = "DamageArcs"
	_arc_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arc_layer.draw.connect(_draw_arcs)
	_stage.add_child(_arc_layer)


func _build_card() -> void:
	_card = PanelContainer.new()
	_card.name = "KillerCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.border_color = Color(COL_RED, 0.85)
	sb.border_width_top = 3
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	_card.add_theme_stylebox_override("panel", sb)
	_stage.add_child(_card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(col)

	# ردیفِ اول: [اسلحه] [حذف شدی توسط / نامِ قاتل] — راست‌چین
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 14)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_card_weapon = _icon_rect(64.0)
	top.add_child(_card_weapon)
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", -4)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(who)
	_card_title = _label(_font_text, 18, COL_RED, 5)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	who.add_child(_card_title)
	_card_name = _label(_font_text, 30, COL_TEXT, 7)
	_card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	who.add_child(_card_name)

	var line := ColorRect.new()
	line.color = Color(COL_GOLD, 0.35)
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(line)

	# ردیفِ دوم: نکته‌ی کاربردی (C10)
	var tip := HBoxContainer.new()
	tip.add_theme_constant_override("separation", 10)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tip)
	_card_tip = _label(_font_text, 19, COL_GOLD, 5)
	_card_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_card_tip.custom_minimum_size = Vector2(330, 0)
	_card_tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip.add_child(_card_tip)
	_card_tip_icon = _icon_rect(44.0)
	tip.add_child(_card_tip_icon)

	_card_respawn = _label(_font_num, 24, COL_GOLD, 6)
	_card_respawn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_card_respawn)


func _build_audio() -> void:
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	_heart = AudioStreamPlayer.new()
	_heart.bus = &"SFX"
	_heart.stream = SFX.get_stream("heart")
	add_child(_heart)
	# همه‌ی صداها همین حالا ساخته شوند، نه وسطِ اولین درگیری
	for n in ["hit", "kill", "multi2", "multi3", "multi4", "hurt", "tick", "respawn", "death"]:
		SFX.get_stream(n)


func _layout() -> void:
	if _stage == null or not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	var s := clampf(vp.y / DESIGN_H, 0.6, 2.4)
	_stage.scale = Vector2(s, s)
	_stage.position = Vector2.ZERO
	_stage.size = vp / s
	var W := _stage.size.x
	var H := _stage.size.y
	var ins := SafeArea.insets_for(_stage) / s
	var top := maxf(ins.y, 10.0)

	_arc_layer.position = Vector2.ZERO
	_arc_layer.size = _stage.size

	# زیرِ قابِ تایمر (۱۰۰) و پنلِ جانِ تیم؛ بالاتر از خودِ بازیکن (وسطِ صفحه)
	_callout.position = Vector2(ins.x, top + 150.0)
	_callout.size = Vector2(W - ins.x - ins.z, 92.0)
	_callout.pivot_offset = _callout.size * 0.5

	_place_card()


func _place_card() -> void:
	if _card == null or _stage == null:
		return
	var W := _stage.size.x
	var H := _stage.size.y
	_card.reset_size()
	var sz := _card.get_combined_minimum_size()
	sz.x = maxf(sz.x, 440.0)
	_card.size = sz
	# پایین‌تر از وسط (بازیکن) و بالاتر از نوارِ «تماشا»ی پایینِ صفحه
	_card.position = Vector2((W - sz.x) * 0.5, H * 0.66 - sz.y * 0.5)
	_card.pivot_offset = sz * 0.5


# ============================================================ رابط

## یکی از حریف‌ها با تیرِ هر کسی آسیب دید (world.gd / bot.gd)
func on_enemy_hit(by_me: bool) -> void:
	if by_me:
		_play("hit", 0.0, 55)


## کیلِ خودت. coins_ok یعنی این کیل سکه‌ی واقعی دارد (آنلاین).
func on_local_kill(victim: String, pos: Vector2, coins_ok: bool = true) -> void:
	var now := Time.get_ticks_msec()
	_multi = _multi + 1 if now - _last_kill_ms <= MULTI_WINDOW_MS else 1
	_last_kill_ms = now
	_kills_life += 1
	_match_kills += 1

	var tags: Array = []
	if not _first_seen:
		tags.append("first_blood")
	_first_seen = true
	if victim != "" and victim == _last_killer:
		tags.append("revenge")
		_last_killer = ""
	var sub := ""
	if _multi == 2:
		tags.append("double")
	elif _multi == 3:
		tags.append("triple")
	elif _multi >= 4:
		tags.append("rampage")
	elif _kills_life >= STREAK_STEP and _kills_life % STREAK_STEP == 0:
		tags.append("rampage")
		sub = "%s حذف بدونِ مرگ" % _fa(_kills_life)

	# V7 شدت متناسب با اهمیت: کیل < دوتایی < سه‌تایی < بی‌مهار
	var tier := clampi(_multi, 1, 4)
	if tags.has("rampage"):
		tier = 4
	var coins := 0
	if coins_ok and not Global.offline_mode and _match_kills * COINS_PER_KILL <= KILL_COINS_CAP:
		coins = COINS_PER_KILL
	if pos.is_finite():
		CombatFX.kill_confirm(pos, coins, tier)
	CombatFX.hit_stop(0.04 + 0.02 * float(tier - 1))
	if tier >= 2:
		CombatFX.shake(5.0 + 2.0 * float(tier), 9.0)
		_play("multi%d" % clampi(tier, 2, 4))
	else:
		_play("kill")
	LocalSettings.vibrate(40 + 15 * (tier - 1))

	if not tags.is_empty():
		_callout_for(tags, sub)


## کسی (هر کسی، غیر از خودت) مرد — فقط برای «اولین حذف»
func note_death() -> void:
	_first_seen = true


## بات‌های بازیِ سریع منبعِ ضربه‌شان را خودشان می‌گویند (kind: gun / bomb)
func note_attack(attacker: String, from: Vector2, weapon_id: String, kind: String = "gun") -> void:
	_noted = {"name": attacker, "pos": from, "weapon": weapon_id, "kind": kind,
		"ms": Time.get_ticks_msec(), "window": NOTE_BOMB_MS if kind == "bomb" else NOTE_GUN_MS}


## خودت آسیب خوردی — کمانِ جهت + صدای ضربه (لرزش و حاشیه را world.gd می‌دهد)
func on_local_damaged(amount: int, max_hp: int) -> void:
	if amount <= 0:
		return
	_play("hurt", 0.0, 110)
	var src := _attribute()
	if src.is_empty():
		return
	_last_attack = src
	_last_attack["ms"] = Time.get_ticks_msec()
	_recent_attackers[str(src.get("name", ""))] = Time.get_ticks_msec()
	var me := _me()
	if me == null:
		return
	var to: Vector2 = src.get("pos", me.global_position)
	if to.distance_to(me.global_position) < 8.0:
		return    # وسطِ انفجار ایستاده‌ای: جهتی ندارد، حاشیه‌ی قرمز کافی است
	var ang := (to - me.global_position).angle()
	var k := clampf(float(amount) / maxf(float(max_hp) * 0.25, 1.0), 0.45, 1.0)
	_add_arc(ang, k)


## مرگِ خودت (player.gd → die)
func on_local_death() -> void:
	_kills_life = 0
	_multi = 0
	_co_queue.clear()
	_play("death")
	LocalSettings.vibrate(90)
	_arcs.clear()
	_arc_layer.queue_redraw()
	if Global.offline_mode:
		return   # بازیِ سریع صفحه‌ی پایانِ خودش را دارد
	var src := {}
	if not _last_attack.is_empty() and Time.get_ticks_msec() - int(_last_attack.get("ms", 0)) < 4000:
		src = _last_attack
	# C10: سرورِ جدید قاتل و نوعِ سلاح را می‌گوید — بر حدس مقدم است
	var sk: String = Network.death_killer(str(Global.my_username))
	if sk != "":
		var sw := str(Network.last_death.get("weapon", ""))
		if str(src.get("name", "")) != sk:
			var kn = world.spawned_players.get(sk, null) if world != null and "spawned_players" in world else null
			var me := _me()
			src = {"name": sk, "weapon": "", "kind": sw,
				"pos": kn.global_position if is_instance_valid(kn) else (me.global_position if me else Vector2.ZERO)}
		elif sw != "":
			src = src.duplicate()
			src["kind"] = sw
	_last_killer = str(src.get("name", "")) if str(src.get("kind", "")) != "demon" else ""
	_show_card(src)


## برگشت به زمین (عملیات انتقام / شیطان)
## fresh=false یعنی همین برگشت قبلاً اعلام شده (پیامِ respawn بعد از
## همگام‌سازیِ جان رسید) و فقط محافظ گفته می‌شود.
func on_local_respawn(shield_seconds: float = 0.0, fresh: bool = true) -> void:
	_respawn_left = 0.0
	_hide_card(true)
	if fresh:
		_play("respawn")
		LocalSettings.vibrate(20)
	if shield_seconds > 0.0 and (fresh or _co_left <= 0.0):
		# E13: محافظِ تولد را صریح بگو — قانونش (با شلیک می‌شکند) قبلاً جایی گفته نمی‌شد
		_callout_for(["respawn"], "%s ثانیه محافظ داری — با اولین شلیکت می‌شکند" % _fa(int(ceil(shield_seconds))))


## حاشیه‌ی «جانِ کم» روشن/خاموش شد (world.gd → _update_low_health)
func set_low_health(low: bool) -> void:
	if low == _low:
		return
	_low = low
	if low:
		_low_since_ms = Time.get_ticks_msec()
		_heart_t = 0.0
		LocalSettings.vibrate(50)
	elif _heart != null:
		_heart.stop()


## آیا این آسیب/کیل کارِ خودت بود؟ تیر (آخرین hitِ فرستاده)، بمب یا لیزرت.
func credit_mine(username: String, pos: Vector2, gun_window_ms: int) -> bool:
	var me := _me()
	if me == null:
		return false
	var now := Time.get_ticks_msec()
	if "last_hit_target" in me and str(me.last_hit_target) == username \
			and now - int(me.last_hit_ms) <= gun_window_ms:
		return true
	var mine := str(Global.my_username)
	for b in _bombs:
		if str(b["by"]) == mine and now - int(b["ms"]) <= BOMB_WINDOW_MS \
				and pos.distance_to(b["pos"]) <= float(b["r"]) + 40.0:
			return true
	if int(_lasers.get(mine, 0)) > now:
		var dir := Vector2.UP.rotated(me.rotation)
		if Abilities.segment_hits_circle(me.global_position,
				me.global_position + dir * Abilities.LASER_RANGE, pos, 45.0):
			return true
	return false


# ============================================================ منبعِ ضربه

func _on_player_shot(username, pos, rot) -> void:
	_shots[str(username)] = {"pos": Vector2(pos), "dir": Vector2.UP.rotated(float(rot)),
		"ms": Time.get_ticks_msec()}


func _on_bomb_thrown(data: Dictionary) -> void:
	var now := Time.get_ticks_msec()
	# قدیمی‌ها را دور بریز تا لیست بزرگ نشود
	for i in range(_bombs.size() - 1, -1, -1):
		if now - int(_bombs[i]["ms"]) > BOMB_WINDOW_MS:
			_bombs.remove_at(i)
	_bombs.append({"by": str(data.get("username", "")),
		"pos": Vector2(float(data.get("explosion_x", 0.0)), float(data.get("explosion_y", 0.0))),
		"r": float(data.get("bomb_radius", 100.0)), "ms": now})


func _on_ability(data: Dictionary) -> void:
	if str(data.get("kind", "")) == "laser":
		_lasers[str(data.get("username", ""))] = Time.get_ticks_msec() \
			+ int(float(data.get("active", Abilities.LASER_ACTIVE)) * 1000.0)


func _on_demon_blast(pos: Vector2, radius: float) -> void:
	_demon_hit = {"pos": pos, "r": radius, "ms": Time.get_ticks_msec()}


## بهترین حدس برای اینکه این ضربه از کجا آمد. خروجی: {name, pos, weapon, kind}
## یا خالی. ترتیب از مطمئن به حدسی است.
func _attribute() -> Dictionary:
	var me := _me()
	if me == null:
		return {}
	var mp := me.global_position
	var now := Time.get_ticks_msec()

	if not _noted.is_empty() and now - int(_noted["ms"]) <= int(_noted["window"]):
		return _noted.duplicate()

	if not _demon_hit.is_empty() and now - int(_demon_hit["ms"]) <= DEMON_WINDOW_MS \
			and mp.distance_to(_demon_hit["pos"]) <= float(_demon_hit["r"]) + 40.0:
		return {"name": "شیطان", "pos": _demon_hit["pos"], "weapon": "", "kind": "demon"}

	for i in range(_bombs.size() - 1, -1, -1):
		var b: Dictionary = _bombs[i]
		if str(b["by"]) == str(Global.my_username) or _is_ally_name(str(b["by"])):
			continue
		if now - int(b["ms"]) <= BOMB_WINDOW_MS and mp.distance_to(b["pos"]) <= float(b["r"]) + 40.0:
			return {"name": b["by"], "pos": b["pos"], "weapon": "", "kind": "bomb"}

	for u in _lasers:
		if int(_lasers[u]) <= now or _is_ally_name(str(u)):
			continue
		var n := _actor(str(u))
		if n == null:
			continue
		var dir := Vector2.UP.rotated(n.rotation)
		if Abilities.segment_hits_circle(n.global_position,
				n.global_position + dir * Abilities.LASER_RANGE, mp, 50.0):
			return {"name": u, "pos": n.global_position, "weapon": "", "kind": "laser"}

	var best := ""
	var best_ms := -1
	for u in _shots:
		var s: Dictionary = _shots[u]
		var age := now - int(s["ms"])
		if age > SHOT_WINDOW_MS or _is_ally_name(str(u)) or int(s["ms"]) <= best_ms:
			continue
		var v: Vector2 = mp - Vector2(s["pos"])
		var d: Vector2 = s["dir"]
		var along := v.dot(d)
		if along < -20.0 or along > 1100.0 or absf(v.cross(d)) > 90.0:
			continue
		best = str(u)
		best_ms = int(s["ms"])
	if best != "":
		var n2 := _actor(best)
		var p: Vector2 = n2.global_position if n2 != null else Vector2(_shots[best]["pos"])
		return {"name": best, "pos": p, "weapon": _weapon_of(best), "kind": "gun"}

	# آخرین چاره: نزدیک‌ترین حریفِ دیده‌شده
	var near := ""
	var near_d := 900.0
	var players = world.get("spawned_players") if world != null else null
	if typeof(players) == TYPE_DICTIONARY:
		for u in players:
			var n3 = players[u]
			if not is_instance_valid(n3) or ("is_ally" in n3 and n3.is_ally):
				continue
			var dd: float = mp.distance_to(n3.global_position)
			if dd < near_d:
				near_d = dd
				near = str(u)
	if near != "":
		return {"name": near, "pos": _actor(near).global_position, "weapon": _weapon_of(near), "kind": "gun"}
	return {}


func _me() -> Node2D:
	if world == null or not is_instance_valid(world):
		return null
	return world.get_node_or_null("Player") as Node2D


func _actor(username: String) -> Node2D:
	if world == null:
		return null
	var players = world.get("spawned_players")
	if typeof(players) != TYPE_DICTIONARY or not players.has(username):
		return null
	var n = players[username]
	return n if is_instance_valid(n) else null


func _is_ally_name(username: String) -> bool:
	var n := _actor(username)
	return n != null and "is_ally" in n and n.is_ally


func _weapon_of(username: String) -> String:
	var pd = Network.current_players.get(username, {})
	if typeof(pd) != TYPE_DICTIONARY:
		return ""
	var skin := str(pd.get("weapon_skin", "")).strip_edges()
	return skin if skin != "" else str(pd.get("weapon", ""))


# ============================================================ اعلان

## چند برچسبِ هم‌زمان یکی می‌شوند: مهم‌ترین، تیتر؛ بقیه زیرنویس.
func _callout_for(tags: Array, sub: String = "") -> void:
	var best := ""
	var best_p := -1
	for t in tags:
		var p := int(CALLOUTS[t]["prio"])
		if p > best_p:
			best_p = p
			best = t
	var extra: Array[String] = []
	for t in tags:
		if t != best:
			extra.append(str(CALLOUTS[t]["text"]).trim_suffix("!"))
	if sub != "":
		extra.push_front(sub)
	var item := {"tag": best, "prio": best_p, "sub": " • ".join(PackedStringArray(extra))}
	# بالاتر یا هم‌رده بلافاصله جایگزین می‌شود (دوتایی → سه‌تایی)؛ پایین‌تر صف
	if _co_left <= 0.0 or best_p >= _co_prio:
		_show_callout(item)
	else:
		_co_queue.append(item)
		if _co_queue.size() > 2:
			_co_queue.pop_front()


func _show_callout(item: Dictionary) -> void:
	var def: Dictionary = CALLOUTS[item["tag"]]
	var red := bool(def.get("red", false))
	_co_title.text = str(def["text"])
	_co_title.add_theme_color_override("font_color", COL_RED if red else COL_GOLD)
	_co_sub.text = str(item["sub"])
	_co_sub.visible = _co_sub.text != ""
	var tex: Texture2D = null
	if str(def["icon"]) != "":
		tex = _load_icon(str(def["icon"]), "icon_skull")
	_co_icon.texture = tex
	_co_icon.visible = tex != null
	_co_icon.modulate = Color(1, 1, 1) if tex != null and ResourceLoader.exists(PSYCH_ICON % def["icon"]) \
		else COL_GOLD
	_co_prio = int(item["prio"])
	_co_left = CALLOUT_TIME

	_callout.visible = true
	_callout.pivot_offset = _callout.size * 0.5
	if _co_tw != null and _co_tw.is_valid():
		_co_tw.kill()
	_callout.scale = Vector2(1.45, 1.45)
	_callout.modulate.a = 0.0
	_co_tw = create_tween().set_parallel(true)
	_co_tw.tween_property(_callout, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_co_tw.tween_property(_callout, "modulate:a", 1.0, 0.1)


func _end_callout() -> void:
	_co_prio = -1
	if not _co_queue.is_empty():
		_show_callout(_co_queue.pop_front())
		return
	if _co_tw != null and _co_tw.is_valid():
		_co_tw.kill()
	_co_tw = create_tween()
	_co_tw.tween_property(_callout, "modulate:a", 0.0, 0.22)
	_co_tw.tween_callback(func(): _callout.visible = false)


# ============================================================ کمانِ آسیب

func _add_arc(ang: float, k: float) -> void:
	for a in _arcs:
		if absf(wrapf(float(a["ang"]) - ang, -PI, PI)) < 0.45:
			a["ang"] = ang
			a["t"] = 0.0
			a["k"] = maxf(float(a["k"]), k)
			_arc_layer.queue_redraw()
			return
	if _arcs.size() >= N_ARCS:
		_arcs.pop_front()
	_arcs.append({"ang": ang, "t": 0.0, "k": k})
	_arc_layer.queue_redraw()


func _draw_arcs() -> void:
	if _arcs.is_empty():
		return
	var c := _arc_layer.size * 0.5
	for a in _arcs:
		var u: float = float(a["t"]) / ARC_LIFE
		var alpha: float = float(a["k"]) * (1.0 - u * u)
		var ang: float = a["ang"]
		# کمی به بیرون می‌رود تا حرکت (که دیدِ پیرامونی می‌گیرد) داشته باشد
		var r: float = ARC_R + 10.0 * (1.0 - pow(1.0 - minf(u * 3.0, 1.0), 2.0))
		_arc_layer.draw_arc(c, r, ang - ARC_HALF, ang + ARC_HALF, 20,
			Color(0.0, 0.0, 0.0, 0.45 * alpha), 14.0, true)
		_arc_layer.draw_arc(c, r, ang - ARC_HALF, ang + ARC_HALF, 20,
			Color(COL_RED, 0.9 * alpha), 9.0, true)
		_arc_layer.draw_arc(c, r - 1.0, ang - ARC_HALF * 0.55, ang + ARC_HALF * 0.55, 12,
			Color(1.0, 0.75, 0.7, 0.8 * alpha), 3.0, true)
		# نوکِ پیکان رو به منبع
		var tip := c + Vector2.from_angle(ang) * (r + 20.0)
		var base := c + Vector2.from_angle(ang) * (r + 6.0)
		var side := Vector2.from_angle(ang + PI * 0.5) * 11.0
		_arc_layer.draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]),
			Color(COL_RED, 0.95 * alpha))


# ============================================================ کارتِ قاتل

func _show_card(src: Dictionary) -> void:
	var kind := str(src.get("kind", ""))
	var who := str(src.get("name", ""))
	_card_title.text = "حذف شدی توسطِ"
	if who == "":
		_card_title.text = "حذف شدی"
		_card_name.text = ""
	else:
		_card_name.text = who
	_card_name.visible = _card_name.text != ""

	var wtex: Texture2D = null
	match kind:
		"bomb":
			wtex = _load_icon("", "icon_bomb")
		"laser":
			wtex = _load_icon("", "icon_laser")
		"demon":
			wtex = _load_icon("", "icon_skull")
		_:
			var wid := str(src.get("weapon", ""))
			if wid != "" and world != null and world.has_method("_item_icon"):
				wtex = world.call("_item_icon", wid)
	_card_weapon.texture = wtex
	_card_weapon.visible = wtex != null

	var tip := _pick_tip(src)
	_card_tip.text = tip[0]
	var ttex: Texture2D = _load_icon(tip[1], tip[2])
	_card_tip_icon.texture = ttex
	_card_tip_icon.visible = ttex != null

	# E13: حالت‌های ریسپاون‌دار — دقیقاً چند ثانیه تا برگشت (همان مهلتِ سرور)
	_respawn_left = 0.0
	if bool(Network.round_info.get("respawn", false)) or bool(Network.round_info.get("demon", false)):
		_respawn_left = 5.0 if bool(Network.round_info.get("demon", false)) else 3.0
	_card_respawn.visible = _respawn_left > 0.0
	_update_respawn_text()
	_card_left = CARD_TIME if _respawn_left <= 0.0 else _respawn_left + 2.0

	_place_card()
	_card.visible = true
	if _card_tw != null and _card_tw.is_valid():
		_card_tw.kill()
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.92, 0.92)
	# اول پفِ ناک‌اوت دیده شود، بعد کارت
	_card_tw = create_tween()
	_card_tw.tween_interval(0.35)
	_card_tw.set_parallel(true)
	_card_tw.tween_property(_card, "modulate:a", 1.0, 0.2)
	_card_tw.tween_property(_card, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_card(fast := false) -> void:
	_card_left = 0.0
	if _card == null or not _card.visible:
		return
	if _card_tw != null and _card_tw.is_valid():
		_card_tw.kill()
	if fast:
		_card.visible = false
		return
	_card_tw = create_tween()
	_card_tw.tween_property(_card, "modulate:a", 0.0, 0.3)
	_card_tw.tween_callback(func(): _card.visible = false)


func _update_respawn_text() -> void:
	if _respawn_left > 0.0:
		_card_respawn.text = "برگشت تا %s" % _fa(int(ceil(_respawn_left)))


## یک نکته‌ی کوتاه و قابلِ انجام بر اساسِ همین مرگ: [متن، آیکنِ آرت، جایگزینِ HUD]
func _pick_tip(src: Dictionary) -> Array:
	var kind := str(src.get("kind", ""))
	var now := Time.get_ticks_msec()
	if kind == "bomb":
		return ["بمب که نشست، فوراً از دایره‌اش بیرون بدو", "tip_grenade", "icon_bomb"]
	if kind == "demon":
		return ["دایره‌ی نفرین که روی زمین افتاد، کنار برو", "tip_cover", "icon_shield"]
	if kind == "laser":
		return ["پرتوی لیزر از دیوار رد نمی‌شود — پشتِ دیوار برو", "tip_cover", "icon_shield"]
	var me := _me()
	if me != null and "_reload_left" in me and (float(me._reload_left) > 0.0 or int(me.current_ammo) <= 0):
		return ["خشابت وسطِ درگیری خالی شد؛ قبل از جنگ جعبه‌ی فشنگ بردار", "tip_reload", "icon_bullet"]
	var many := 0
	for u in _recent_attackers:
		if now - int(_recent_attackers[u]) < 4000:
			many += 1
	if many >= 2:
		return ["تنها جلوی چند نفر نرو؛ کنارِ هم‌تیمی‌ها بجنگ", "social_squad", "icon_people"]
	if _low_since_ms > 0 and now - _low_since_ms > 1500 and _heal_was_ready():
		return ["جانت کم بود و درمان آماده — زودتر بزنش", "", "icon_heal"]
	if _match_kills % 2 == 0:
		return ["پشتِ دیوار پناه بگیر و از لبه‌ها بجنگ", "tip_cover", "icon_shield"]
	return ["یک‌جا نایست؛ وسطِ شلیک با جوی‌استیک جابه‌جا شو", "tip_cover", "icon_run"]


func _heal_was_ready() -> bool:
	var hud = world.get("hud") if world != null else null
	if hud == null or not hud.has_method("button"):
		return false
	var b = hud.button("heal")
	return b != null and b.has_method("is_ready") and b.is_ready()


# ============================================================ راند (C6)

func _on_round_state(_alive: Dictionary, seconds_left: int) -> void:
	if Global.offline_mode:
		return
	_round_left = float(seconds_left)
	_round_peak = maxf(_round_peak, _round_left)


func _on_match_over(_winner: String, _draw: bool) -> void:
	_round_left = -1.0
	_co_queue.clear()
	if _co_left > 0.0:
		_co_left = 0.01
	_hide_card(true)
	if _heart != null:
		_heart.stop()
	_low = false


func _tick_round(delta: float) -> void:
	if _round_left <= 0.0:
		return
	_round_left = maxf(_round_left - delta, 0.0)
	# فقط اگر راند واقعاً از این مرزها بلندتر بوده (نه وقتی دیر رسیده‌ایم)
	if not _said_30 and _round_peak > 40.0 and _round_left <= 30.0 and _round_left > 25.0:
		_said_30 = true
		_callout_for(["final30"])
		_play("tick")
	if not _said_10 and _round_peak > 15.0 and _round_left <= 10.0 and _round_left > 7.0:
		_said_10 = true
		_callout_for(["final10"])
		LocalSettings.vibrate(30)
	var sec := int(ceil(_round_left))
	if sec <= 5 and sec >= 1 and sec != _last_tick and _round_peak > 8.0:
		_last_tick = sec
		_play("tick")


# ============================================================ حلقه

func _process(delta: float) -> void:
	if _co_left > 0.0:
		_co_left -= delta
		if _co_left <= 0.0:
			_end_callout()

	if not _arcs.is_empty():
		for i in range(_arcs.size() - 1, -1, -1):
			_arcs[i]["t"] = float(_arcs[i]["t"]) + delta
			if float(_arcs[i]["t"]) >= ARC_LIFE:
				_arcs.remove_at(i)
		_arc_layer.queue_redraw()

	if _card_left > 0.0:
		_card_left -= delta
		if _respawn_left > 0.0:
			_respawn_left = maxf(_respawn_left - delta, 0.0)
			_update_respawn_text()
			if _respawn_left <= 0.0:
				_card_respawn.text = "در حالِ برگشت..."
		if _card_left <= 0.0:
			_hide_card()

	# E11 ضربانِ قلب هم‌گام با تپشِ حاشیه‌ی قرمز
	if _low:
		var me := _me()
		if me != null and "is_dead" in me and not me.is_dead:
			_heart_t -= delta
			if _heart_t <= 0.0:
				_heart_t = HEART_PERIOD
				_heart.play()

	_tick_round(delta)


# ============================================================ کمکی

## پخشِ یک صدای ساخته‌شده. min_gap_ms جلوی رگبارِ همان صدا را می‌گیرد.
func _play(name: String, pitch_jitter: float = 0.0, min_gap_ms: int = 0) -> void:
	var now := Time.get_ticks_msec()
	if min_gap_ms > 0 and now - int(_last_sound_ms.get(name, -100000)) < min_gap_ms:
		return
	_last_sound_ms[name] = now
	var p := _players[_i_player]
	_i_player = (_i_player + 1) % _players.size()
	p.stream = SFX.get_stream(name)
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## عدد با ارقامِ فارسی
static func _fa(n: int) -> String:
	var digits := "۰۱۲۳۴۵۶۷۸۹"
	var s := str(n)
	var out := ""
	for ch in s:
		out += digits[int(ch)] if ch >= "0" and ch <= "9" else ch
	return out
