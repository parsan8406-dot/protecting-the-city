extends Node2D

@export var ammo_box_scene: PackedScene
@export var other_player_scene: PackedScene
@export var bomb_scene: PackedScene  # 🌟 صحنه بمب رو توی اینسپکتر ست کن

@onready var spawn_points_node = $SpawnPointsChar
@onready var arena = $Arena
@onready var player_sprite = $Player/Sprite2D
@onready var weapon_sprite = $Player/gun
@onready var death_menu = get_node_or_null("UI/DeathMenu")
@onready var joystick = $UI/VirtualJoystick
@onready var bomb_sound = $Player/BombSound

## گنبدِ محافظِ تولد (عملیات انتقام) — سرور می‌گوید چند ثانیه
const SPAWN_SHIELD := preload("res://scripts/spawn_shield.gd")
## افکت‌های توانایی‌ها و پلاکِ بالای سرِ خودمان
const LASER_BEAM := preload("res://scripts/laser_beam.gd")
const SPRINT_TRAIL := preload("res://scripts/sprint_trail.gd")
const PULSE_RING := preload("res://scripts/pulse_ring.gd")
const SELF_PLATE := preload("res://scripts/self_plate.gd")
const INGAME_SETTINGS := preload("res://scripts/ingame_settings.gd")
## شیطانِ وسطِ زمین (عملیات حذف شیطان). فقط وقتی ساخته می‌شود که سرور
## پیامِ demon_state بفرستد — بقیه‌ی حالت‌ها اصلاً خبر ندارند وجود دارد.
const DEMON := preload("res://scripts/demon.gd")
## لایه‌ی «حسِ نبرد»: اعلانِ کیل‌ها، کمانِ جهتِ آسیب، کارتِ قاتل، صداهای نبرد
const PSYCH_FEEL := preload("res://scripts/psych_combat_feel.gd")
## رنگِ حبابِ سپرِ دستی — آبی، تا با گنبدِ طلاییِ تولد اشتباه نشود
const GUARD_TINT := Color(0.4, 0.85, 1.0)
const TEAM_HEAL_COL := Color(0.35, 0.95, 0.55)

## فیوز بمب — همان مدتی که نشانگر محدوده پر می‌شود و بعد منفجر می‌شود.
const BOMB_FUSE := 1.0

## از چند پیکسل جابه‌جایی به بعد، انگشت خودش هدف را تعیین می‌کند
## (کمتر از این یعنی ضربه‌ی ساده، نه کشیدن).
const BOMB_DRAG_DEADZONE := 12.0
## نزدیک‌ترین جایی که می‌شود بمب انداخت (با minBombRange سرور یکی است)
const BOMB_MIN_RANGE := 90.0

## ترازِ کاراکترِ خودمان — سرور می‌فرستد، کلاینت فقط نمایشش می‌دهد.
## تا وقتی نرسیده مقدارهای پیش‌فرضِ متعادل استفاده می‌شود.
var my_stats := {
	"health": 112, "speed": 200.0, "damage": 25,
	"bomb_range": 380.0, "bomb_radius": 104.0, "bomb_damage": 49,
	"fire_cooldown": 0.3, "miss_chance": 0.0, "max_range": 500.0,
	# صفر یعنی «سرور نگفته» — آن‌وقت از روی سرعتِ شلیک حساب می‌شود
	"mag_size": 0, "reload_seconds": 1.6,
	"heal_amount": 25, "heal_cooldown": 12.0,
	"turn_rate": 400.0, "fire_cone_deg": 20.0,
}

# --- وضعیت نشانه‌گیری بمب ---
var bomb_aiming := false
var bomb_aim_dir := Vector2.RIGHT
var bomb_aim_dist := 0.0
## نقطه‌ی هدف در مختصات جهانی — همان‌جایی که انگشت نشان می‌دهد.
## جهت و فاصله همیشه از روی این و موقعیتِ لحظه‌ایِ بازیکن حساب می‌شوند،
## پس اگر وسط نشانه‌گیری حرکت کنی هدف سر جای خودش روی زمین می‌ماند.
var bomb_aim_target := Vector2.ZERO
## آیا انگشت از دکمه فاصله گرفته و خودش هدف را تعیین می‌کند؟
var bomb_aim_positional := false
## اندیس انگشتی که نشانه‌گیری را شروع کرده — تا انگشتِ دیگر قاطی نکند
var bomb_touch_index := -1

var spawned_players = {}
## آخرین جانِ هر حریف — برای تشخیص اینکه ضربه خورده و باید جرقه‌ی ضربه بزند
var _last_health := {}
var max_health = 100
## کلِ رابطِ کاربری (game_hud.gd) و کارتِ پروفایلِ داخلش
var hud: GameHUD = null
var combat_hud: CombatHUD = null
var bomb_button: HudAbilityButton = null
## بمب‌های مانده در این مسابقه — آنلاین سرور می‌گوید (bombs_left)
var bombs_left := Abilities.BOMB_STOCK

## افکت‌های فعالِ توانایی‌ها: نامِ بازیکن -> نود
var _guards: Dictionary = {}
var _trails: Dictionary = {}
## چند ثانیه‌ی دیگر دویدنِ خودمان فعال است
var _sprint_left := 0.0
var _self_plate: Node2D = null
var _settings: CanvasLayer = null
var _back_frame := -1
## مسابقه تمام شده و صفحه‌ی برد/باخت روی زمین است — زمین دیگر لمس نمی‌گیرد
var _match_ended := false
# 🌟 نقطه‌ی شروعی که سرور تعیین کرده (تا کلاینت نتواند هرجا بخواهد ظاهر شود)
var server_spawn = null

## گنبدهای محافظِ تولد: نامِ بازیکن -> نودِ گنبد.
## سرور مدتش را می‌فرستد (respawn.shield_seconds و update_players.shield_left)؛
## این‌جا فقط نمایش داده می‌شود.
var _shields: Dictionary = {}

## نودِ شیطان، اگر این حالت شیطان داشته باشد (وگرنه null).
## مرجعش سرور است؛ این‌جا فقط ساخته و به‌روز می‌شود.
var _demon: Node2D = null

## psych_combat_feel.gd — یک بار در _ready ساخته می‌شود
var feel: CanvasLayer = null
## آخرین جانی که روی HUD رفت — آفلاین از رویش «تیر خوردم» تشخیص داده می‌شود
var _ui_hp := -1

## آیا این صحنه آفلاین است؟ زمینِ چندنفره نه؛ quick_play آن را true می‌کند.
##
## چرا این متغیر لازم است: Global.offline_mode یک پرچمِ سراسری است و بینِ
## صحنه‌ها زنده می‌ماند. بازیِ سریع آن را روشن می‌کرد و اگر به هر دلیلی
## خاموش نمی‌شد، زمینِ چندنفره همان مقدارِ جامانده را باور می‌کرد و
## enter_arena() بی‌صدا برمی‌گشت: سرور هیچ‌وقت نمی‌فهمید بازیکن وارد شده،
## پس نه راندی شروع می‌شد، نه رباتی می‌آمد، نه بازیکنِ دیگری دیده می‌شد —
## و جانِ جامانده‌ی راندِ قبلی روی صفحه می‌ماند. بازسازی شد و دقیقاً همان
## صحنه درآمد: spawned_players=0، تایمر --:--، زنده ۰ ۰.
##
## حالا هر صحنه موقعِ باز شدن حالتِ خودش را اعلام می‌کند و چیزی از صحنه‌ی
## قبلی به ارث نمی‌رسد.
@export var is_offline_scene := false


func _ready():
	# قبل از هر کاری: حالتِ این صحنه را تثبیت کن
	Global.offline_mode = is_offline_scene
	# دکمه‌ی Back اندروید را خودمان جواب می‌دهیم (تنظیمات/توقف)، نه خروج از اپ
	get_tree().set_quit_on_go_back(false)

	# صفحه‌ی بارگذاری تا رسیدنِ دیتای سرور باز می‌ماند: آنلاین منتظرِ اتصال،
	# نقطه‌ی شروع/نقشه و اولین لیستِ بازیکن‌ها؛ آفلاین فقط آماده شدنِ زمین.
	if is_offline_scene:
		LoadingScreen.split(LoadingScreen.SCENE_READY, {"setup": 1.0})
	else:
		LoadingScreen.split(LoadingScreen.SCENE_READY,
			{"link": 1.0, "spawn": 1.5, "players": 1.0, "setup": 1.0})
		if Network.is_connected:
			LoadingScreen.complete("link", "دریافت نقشه از سرور...")
		elif not Network.connected.is_connected(_on_loading_link):
			Network.connected.connect(_on_loading_link, CONNECT_ONE_SHOT)

	Network.spawn_assigned.connect(_on_spawn_assigned)
	# سرور می‌گوید این مسابقه روی کدام زمین است — «عملیات انتقام» زمینِ
	# خودش را دارد و کلاینت نباید نقشه‌ی دیگری بکشد
	if not Network.arena_assigned.is_connected(_on_arena_assigned):
		Network.arena_assigned.connect(_on_arena_assigned)
	if not Network.player_respawned.is_connected(_on_player_respawned):
		Network.player_respawned.connect(_on_player_respawned)

	if death_menu != null:
		death_menu.hide()

	_build_game_hud()
	feel = PSYCH_FEEL.new()
	feel.name = "CombatFeel"
	feel.world = self
	add_child(feel)
	$Player.hide()

	Network.server_players_updated.connect(_on_players_updated)
	Network.player_moved.connect(_on_player_moved)
	Network.player_shot.connect(_on_player_shot)
	if not Network.health_updated.is_connected(_on_health_updated):
		Network.health_updated.connect(_on_health_updated)
	if not Network.player_died.is_connected(_on_player_died):
		Network.player_died.connect(_on_player_died)
	# با پایانِ راند، نوارِ تماشا برود کنار تا زیرِ صفحه‌ی نتیجه نماند
	if not Network.match_over.is_connected(_on_match_over_spectate):
		Network.match_over.connect(_on_match_over_spectate)
	if not Network.heal_success.is_connected(_on_heal_success):
		Network.heal_success.connect(_on_heal_success)
	if not Network.hit_missed.is_connected(_on_hit_missed):
		Network.hit_missed.connect(_on_hit_missed)
	if not Network.heal_cooldown_started.is_connected(_on_heal_cooldown_started):
		Network.heal_cooldown_started.connect(_on_heal_cooldown_started)
	if not Network.bomb_thrown.is_connected(_on_bomb_thrown):
		Network.bomb_thrown.connect(_on_bomb_thrown)
	if not Network.bomb_explosion.is_connected(_on_bomb_explosion):
		Network.bomb_explosion.connect(_on_bomb_explosion)
	if not Network.ability_used.is_connected(_on_ability):
		Network.ability_used.connect(_on_ability)
	if not Network.objectives_received.is_connected(_on_objectives):
		Network.objectives_received.connect(_on_objectives)
	if not Network.objective_updated.is_connected(_on_objective_updated):
		Network.objective_updated.connect(_on_objective_updated)
	# «عملیات حذف شیطان» — سرور می‌گوید شیطان کجاست، چقدر جان دارد و کِی
	# کجا را نفرین می‌کند
	if not Network.demon_state.is_connected(_on_demon_state):
		Network.demon_state.connect(_on_demon_state)
	if not Network.demon_blast_warned.is_connected(_on_demon_blast_warned):
		Network.demon_blast_warned.connect(_on_demon_blast_warned)
	if not Network.demon_blast_fired.is_connected(_on_demon_blast_fired):
		Network.demon_blast_fired.connect(_on_demon_blast_fired)
	if not Network.demon_slain.is_connected(_on_demon_slain):
		Network.demon_slain.connect(_on_demon_slain)

	# ورود به زمین را به سرور اعلام کن — عمداً بعد از وصل کردنِ سیگنال‌ها،
	# تا اولین update_players که جواب می‌آید شنونده داشته باشد.
	#
	# بدونِ این، سرور هیچ‌وقت نمی‌فهمید بازیکن وارد آرنا شده: join فقط یک
	# بار و موقعِ باز شدنِ سوکت (توی منوی اصلی) فرستاده می‌شد، یعنی وقتی
	# هنوز مسابقه‌ای وجود نداشت — و بات‌های همان مسابقه هرگز ساخته نمی‌شدند.
	Network.enter_arena()

	max_health = get_character_max_health(Global.current_character)
	update_player_health_ui(max_health, max_health)

	await get_tree().create_timer(1.0).timeout

	var free_pos = get_free_spawn_point()
	$Player.global_position = free_pos
	$Player.last_sent_pos = free_pos
	$Player.show()

	if Network.is_connected:
		# تجهیزات را قبل از هر چیز سینک کن تا اولین update_players که می‌رسد
		# همان چیزی باشد که بازیکن در منو انتخاب کرده، نه تجهیزات لحظه‌ی اتصال.
		Network.send_equipment_update()
		Network.send_move_data(free_pos, $Player.rotation)

	if not Global.offline_mode and Network.current_players.size() > 0:
		_on_players_updated(Network.current_players)

	spawn_random_ammo(3)

	# ظاهر = اسکین فعال (اگر بازیکن دارد)، وگرنه خود آیتم
	CharacterSkin.apply(player_sprite, Global.visual_id(Global.current_character))

	WeaponSkin.apply(weapon_sprite, Global.visual_id(Global.current_weapon))
	_refresh_hud_identity()
	LoadingScreen.complete("setup")


func _on_loading_link() -> void:
	LoadingScreen.complete("link", "دریافت نقشه از سرور...")

# ==================== SPAWN ====================
func _on_spawn_assigned(pos: Vector2):
	server_spawn = pos
	LoadingScreen.complete("spawn", "دریافت اطلاعات بازیکن‌ها...")
	# اگر بازیکن قبلاً ظاهر شده، همان‌جا منتقلش کن
	if $Player.visible:
		$Player.global_position = pos
		$Player.last_sent_pos = pos


## زمینِ این مسابقه را سرور تعیین می‌کند. اگر با چیزی که کشیده‌ایم فرق
## داشت، Arena همان لحظه نقشه‌ی درست را می‌سازد — وگرنه بازیکن دیوارهایی
## می‌دید که سرور قبولشان ندارد. تم هم همین‌طور (از بالاترین رنکِ مسابقه)؛
## تمِ خالی یعنی مسابقه‌ای نیست و Arena تمِ فعلی‌اش را نگه می‌دارد.
func _on_arena_assigned(map_name: String, shield_seconds: float, theme: String) -> void:
	if arena != null and arena.has_method("load_map"):
		arena.load_map(map_name, theme)
	if shield_seconds > 0.0 and $Player.visible:
		_show_spawn_shield(Global.my_username, shield_seconds)


## یک بازیکن دوباره زنده شد (عملیات انتقام).
##
## برای خودمان یعنی برگشت به بازی: کنترل‌ها برمی‌گردند، جان پر می‌شود و
## گنبدِ محافظ روشن می‌شود. برای بقیه، نودشان با همان update_players که
## بلافاصله بعدش می‌آید دوباره ساخته می‌شود، پس این‌جا فقط گنبد لازم است.
func _on_player_respawned(username: String, pos: Vector2, health: int, shield_seconds: float) -> void:
	if username == Global.my_username:
		_revive_local_player(pos, health, shield_seconds)
	elif spawned_players.has(username) and is_instance_valid(spawned_players[username]):
		# نودش هنوز هست (مثلاً محو نشده بود): همان‌جا بپرد، نه اینکه از
		# آن سرِ نقشه سُر بخورد
		var node = spawned_players[username]
		node.global_position = pos
		if "target_position" in node:
			node.target_position = pos
		if "health" in node:
			node.health = health
		if node.has_method("update_health_bar"):
			node.update_health_bar(health, node.max_health)
		_last_health[username] = health
	_show_spawn_shield(username, shield_seconds)


## برگرداندنِ بازیکنِ محلی به زمین.
##
## کارِ اصلی را خودِ player.gd → revive() می‌کند (خشاب، تویینِ مرگ، لیستِ
## هدف‌ها). این‌جا فقط صحنه و رابط کاربری هماهنگ می‌شوند.
func _revive_local_player(pos: Vector2, health: int, shield_seconds := 0.0) -> void:
	_leave_spectator()

	var me := $Player
	var was_dead: bool = "is_dead" in me and me.is_dead
	if me.has_method("revive"):
		me.revive(pos, health)
	else:
		me.global_position = pos
		me.modulate.a = 1.0
		me.show()

	server_spawn = pos
	update_player_health_ui(health, max_health)
	# زندگیِ تازه = تجهیزاتِ کامل (سرور هم همین را اعمال می‌کند: freshKit)
	if hud != null:
		for kind in ["sprint", "guard", "laser", "team_heal", "heal", "bomb"]:
			var b = hud.button(kind)
			if b != null:
				b.reset()
	_set_bombs_left(Abilities.BOMB_STOCK)
	# E13: صدای برگشت + «محافظ داری» (اگر همین پیام دوباره آمد فقط محافظ)
	if feel != null:
		feel.on_local_respawn(shield_seconds, was_dead)


## گنبدِ محافظ را روی یک بازیکن روشن می‌کند (یا زمانش را تازه می‌کند).
##
## گنبد فرزندِ صحنه است و نه فرزندِ بازیکن: Arena کاراکترها را تیره می‌کند و
## آن تیرگی به فرزندها هم می‌رسد.
func _show_spawn_shield(username: String, seconds: float) -> void:
	if seconds <= 0.0:
		return
	var target: Node2D = null
	if username == Global.my_username:
		target = $Player
	elif spawned_players.has(username) and is_instance_valid(spawned_players[username]):
		target = spawned_players[username]
	if target == null:
		return  # هنوز نودش ساخته نشده؛ update_players بعدی می‌سازدش

	var shield = _shields.get(username, null)
	if shield != null and is_instance_valid(shield):
		shield.refresh(seconds)
		return

	shield = SPAWN_SHIELD.new()
	add_child(shield)
	shield.setup(target, seconds)
	_shields[username] = shield


## زنده/مرده بودنِ بازیکنِ محلی را با حرفِ سرور یکی می‌کند.
##
## چرا لازم است: برگشتن به بازی به یک پیام (respawn) وابسته بود. اگر آن یک
## پیام به هر دلیلی از دست می‌رفت — یا قبل از آماده شدنِ صحنه می‌رسید —
## بازیکن تا آخرِ راند مرده می‌ماند و فقط تماشا می‌کرد. حالا هر پیامِ
## وضعیتی (health_update و update_players) همین را دوباره چک می‌کند، پس
## دیر یا زود، ولی حتماً برمی‌گردد.
func _sync_local_alive(server_health: int, pos: Vector2) -> void:
	if not ("is_dead" in $Player):
		return
	if server_health > 0 and $Player.is_dead:
		_revive_local_player(pos, server_health)


## سپرِ دستیِ یک بازیکن (دکمه‌ی سپر) — همان گنبد با رنگِ آبی.
## سرور مدتش را می‌گوید (پیامِ ability و guard_left در update_players).
func _show_guard(username: String, seconds: float) -> void:
	if seconds <= 0.0:
		return
	var target: Node2D = _actor_node(username)
	if target == null:
		return
	var g = _guards.get(username, null)
	if g != null and is_instance_valid(g) and g.seconds_left() > 0.0:
		g.refresh(seconds)
		return
	g = SPAWN_SHIELD.new()
	add_child(g)
	g.setup(target, seconds, GUARD_TINT)
	_guards[username] = g


func _dismiss_guard(username: String) -> void:
	var g = _guards.get(username, null)
	if g != null and is_instance_valid(g) and g.has_method("dismiss"):
		g.dismiss()
	_guards.erase(username)


## آیا تیر به این بازیکن ثبت نمی‌شود؟ (گنبدِ تولد یا سپرِ دستی)
## player.gd از این می‌فهمد که شلیک به او فقط فشنگ هدر می‌دهد.
func is_protected(username: String) -> bool:
	if has_spawn_shield(username):
		return true
	var g = _guards.get(username, null)
	return g != null and is_instance_valid(g) and g.seconds_left() > 0.0


## نودِ یک بازیکن در صحنه: خودمان یا یکی از spawned_players
func _actor_node(username: String) -> Node2D:
	if username == Global.my_username:
		return $Player
	var n = spawned_players.get(username, null)
	if n != null and is_instance_valid(n):
		return n
	return null


## گنبدِ یک بازیکن را همین حالا برمی‌دارد (سرور گفته دیگر محافظ ندارد)
func _dismiss_spawn_shield(username: String) -> void:
	var shield = _shields.get(username, null)
	if shield != null and is_instance_valid(shield) and shield.has_method("dismiss"):
		shield.dismiss()
	_shields.erase(username)


## آیا این بازیکن همین حالا گنبد دارد؟ player.gd از این می‌فهمد که شلیک
## به او بی‌فایده است.
func has_spawn_shield(username: String) -> bool:
	var shield = _shields.get(username, null)
	return shield != null and is_instance_valid(shield) and shield.seconds_left() > 0.0

# 🌟 نقطه‌ی شروع را سرور می‌دهد. مارکرهای داخل صحنه فقط پشتیبان‌اند
# (و چون نقشه عوض شده ممکن است داخل دیوار باشند، از Arena استفاده می‌کنیم).
func get_free_spawn_point() -> Vector2:
	if server_spawn != null:
		return server_spawn
	if arena != null and not arena.spawn_points.is_empty():
		return arena.random_spawn()
	var all_spawn_points = spawn_points_node.get_children()
	if all_spawn_points.size() == 0:
		return Vector2(1000, 600)
	return all_spawn_points.pick_random().global_position

## سقفِ جانِ کاراکتر. مرجع سرور است؛ این فقط تا رسیدنِ اولین پیام
## به‌کار می‌آید و بعد از _apply_stats با مقدار واقعی جایگزین می‌شود.
func get_character_max_health(_character_id: String) -> int:
	return int(my_stats.get("health", 112))


## سقفِ جانِ یک بازیکنِ دیگر — از ترازی که سرور برای خودِ او فرستاده
## (players[name].stats.health)، نه از ترازِ کاراکترِ ما.
##
## قبلاً نوارِ جانِ حریف با سقفِ جانِ خودمان کشیده می‌شد: حریفی با جانِ
## بیشتر (مثلاً ۱۷۰ در برابرِ ۱۴۰ِ ما) وقتی هنوز ۳۰ جان داشت نوارش خالی
## می‌شد — «جانش صفر است ولی نمی‌میرد».
func _max_hp_of(p_data) -> int:
	if typeof(p_data) == TYPE_DICTIONARY:
		var st = p_data.get("stats", {})
		if typeof(st) == TYPE_DICTIONARY and int(st.get("health", 0)) > 0:
			return int(st["health"])
	return get_character_max_health("")


## ترازی که سرور برای کاراکترِ ما فرستاده را اعمال می‌کند.
func _apply_stats(stats) -> void:
	if typeof(stats) != TYPE_DICTIONARY or stats.is_empty():
		return
	for key in my_stats.keys():
		if stats.has(key):
			my_stats[key] = stats[key]

	var new_max := int(my_stats.get("health", max_health))
	if new_max != max_health:
		max_health = new_max
		update_player_health_ui($Player.health if "health" in $Player else max_health, max_health)

	# سرعتِ حرکت، فاصله‌ی شلیک و دقت هم از تراز می‌آیند — بدون استثنا
	if "move_speed" in $Player:
		$Player.move_speed = float(my_stats.get("speed", 200.0))
	if "fire_cooldown" in $Player:
		$Player.fire_cooldown = float(my_stats.get("fire_cooldown", 0.3))
	if "miss_chance" in $Player:
		$Player.miss_chance = float(my_stats.get("miss_chance", 0.0))
	# سرعتِ چرخش از کاراکتر (hand_speed)، پهنای مخروطِ شلیک از سلاح (control)
	if "turn_rate" in $Player:
		$Player.turn_rate = float(my_stats.get("turn_rate", 400.0))
	if "fire_cone_deg" in $Player:
		$Player.fire_cone_deg = float(my_stats.get("fire_cone_deg", 20.0))
	# بردِ مؤثر: قفل شدن روی هدفی که سرور شلیک به آن را رد می‌کند فقط
	# فشنگ می‌سوزاند
	if "max_range" in $Player:
		$Player.max_range = float(my_stats.get("max_range", 500.0))
	# خشاب و پر کردنِ خودکارش — اندازه‌اش به سرعتِ شلیکِ همان سلاح گره
	# خورده (سرور: balance.go → magazineFor)
	if "max_ammo" in $Player:
		var mag := int(my_stats.get("mag_size", 0))
		if mag <= 0:
			# بازیِ آفلاین سروری ندارد: همان قاعده‌ی سرور (چهار ثانیه
			# شلیکِ پیوسته) این‌جا هم اعمال می‌شود
			var cd: float = maxf(float(my_stats.get("fire_cooldown", 0.3)), 0.05)
			mag = clampi(int(round(4.0 / cd)), 12, 60)
		if mag != int($Player.max_ammo):
			$Player.max_ammo = mag
			$Player.current_ammo = mag
			if $Player.has_method("_sync_ammo_hud"):
				$Player._sync_ammo_hud()
	if "reload_seconds" in $Player:
		$Player.reload_seconds = float(my_stats.get("reload_seconds", 1.6))
	# فقط بازیِ آفلاین از این استفاده می‌کند، ولی همیشه هماهنگ نگهش می‌داریم
	if "damage" in $Player:
		$Player.damage = int(my_stats.get("damage", 25))

## کلِ رابطِ کاربری را می‌سازد (game_hud.gd): کارتِ پروفایل، اهداف، تایمر،
## پینگ، مینی‌مپ، دکمه‌های توانایی و جای جوی‌استیک.
##
## داخلِ UI می‌نشیند تا با دوربین حرکت نکند و همیشه روی صفحه بماند.
func _build_game_hud() -> void:
	if hud != null:
		return
	for old in ["UI/PlayerHealthBar", "UI/AmmoDisplay", "UI/HealButton", "UI/BombButton"]:
		var n := get_node_or_null(old)
		if n != null:
			n.queue_free()

	hud = GameHUD.new()
	hud.name = "GameHUD"
	hud.joystick = joystick
	$UI.add_child(hud)

	combat_hud = hud.profile
	combat_hud.set_health(max_health, max_health)
	_refresh_hud_identity()

	hud.minimap.arena = arena
	hud.minimap.me = $Player
	hud.minimap.actors_source = _minimap_actors
	# نشانِ شیطان روی مینی‌مپ و فلشِ راهنما روی لبه‌ی صفحه. هر دو از یک
	# منبع می‌خوانند و تا وقتی شیطانی نباشد null می‌گیرند و چیزی نمی‌کشند.
	hud.minimap.demon_source = demon_position
	hud.demon_pointer.demon_source = demon_position
	hud.demon_pointer.me = $Player

	hud.ability_pressed.connect(_on_ability_button)
	hud.menu_pressed.connect(_on_menu_pressed)
	# بمب نشانه‌گیری دارد: نگه داشتن و کشیدن. شروعش از gui_inputِ خودِ دکمه
	# گرفته می‌شود و ادامه‌اش در _input
	bomb_button = hud.button("bomb")
	bomb_button.gui_input.connect(_on_bomb_button_input)
	bomb_button.set_badge(bombs_left)

	# پلاکِ بالای سرِ خودمان: سطح، جان و فشنگ
	_self_plate = SELF_PLATE.new()
	_self_plate.name = "SelfPlate"
	add_child(_self_plate)
	_self_plate.setup($Player)
	_self_plate.set_health(max_health, max_health)

	$Player.ammo_changed.connect(_on_ammo_changed)
	$Player._sync_ammo_hud()


func _on_ammo_changed(current: int, maximum: int, reloading: bool) -> void:
	if combat_hud != null:
		combat_hud.set_ammo(current, maximum, reloading)
	if _self_plate != null:
		_self_plate.set_ammo(current, maximum)


## بازیگرانِ دیگر برای مینی‌مپ. مینی‌مپ خودش حریف‌های بیرونِ بردِ رادار را
## کنار می‌گذارد؛ این فقط همه را می‌دهد.
func _minimap_actors() -> Array:
	var out: Array = []
	for name in spawned_players:
		var n = spawned_players[name]
		if is_instance_valid(n) and n.visible:
			out.append({"pos": n.global_position, "ally": "is_ally" in n and n.is_ally})
	return out


## عکسِ پروفایل (آواتار؛ اگر نبود آرتِ کاراکتر) و آیکنِ اسلحه روی کارت
func _refresh_hud_identity() -> void:
	if combat_hud == null:
		return
	var portrait: Texture2D = AvatarPicker.load_avatar_texture(str(Global.avatar_id))
	if portrait == null:
		portrait = _item_icon(Global.visual_id(Global.current_character))
	combat_hud.set_identity(portrait, _item_icon(Global.visual_id(Global.current_weapon)))
	combat_hud.set_level(int(Global.level))
	if _self_plate != null:
		_self_plate.set_level(int(Global.level))


## آیکن کارت از assets/items/ — همان تصویری که در فروشگاه هم دیده می‌شود.
func _item_icon(item_id: String) -> Texture2D:
	if item_id.is_empty():
		return null
	# اسکین‌ها آیکن assets/items/ ندارند؛ آرت نمایشی‌شان در weapons/ و characters/ است
	for folder in ["items", "weapons", "characters"]:
		var path := "res://assets/%s/%s.png" % [folder, item_id]
		if ResourceLoader.exists(path):
			return load(path)
	return null


func update_player_health_ui(current_health: int, max_hp: int):
	if combat_hud != null:
		combat_hud.set_health(current_health, max_hp)
	if _self_plate != null:
		_self_plate.set_health(current_health, max_hp)
	_update_low_health(current_health, max_hp)
	# بازیِ سریع سرور ندارد و جانِ بازیکن فقط از همین‌جا پایین می‌آید؛ پس
	# حسِ تیر خوردن (لرزش، حاشیه، کمانِ جهت) همین‌جا داده می‌شود. آنلاین همین
	# کار در _on_health_updated انجام می‌شود (تا با همگام‌سازیِ update_players
	# دوبار حساب نشود).
	if Global.offline_mode and _ui_hp > current_health and current_health > 0			 and not $Player.is_dead:
		_feel_local_damage()
		if feel != null:
			feel.on_local_damaged(_ui_hp - current_health, max_hp)
	_ui_hp = current_health

func spawn_random_ammo(amount):
	# از نقاط آزادِ نقشه استفاده کن تا جعبه داخل دیوار نیفتد
	var points: Array = []
	if arena != null and not arena.spawn_points.is_empty():
		points = arena.spawn_points.duplicate()
	else:
		for n in spawn_points_node.get_children():
			points.append(n.global_position)
	points.shuffle()
	for i in range(amount):
		if i < points.size():
			var new_ammo_box = ammo_box_scene.instantiate()
			add_child(new_ammo_box)
			new_ammo_box.global_position = points[i]

# ==================== PLAYERS ====================
func _on_players_updated(players_dict):
	LoadingScreen.complete("players")
	# تیمِ خودمان را از خودِ سرور می‌گیریم و نه از صفحه‌ی انتظار.
	#
	# قبلاً فقط لابی آن را ست می‌کرد، پس هر مسیری که از لابی رد نمی‌شد
	# (یا هر باری که پاسخ لابی دیر می‌رسید) بازیکن بی‌تیم می‌ماند و
	# آن‌وقت همه — حتی هم‌تیمی‌ها — حریف نشان داده می‌شدند.
	var me = players_dict.get(Global.my_username, null)
	if typeof(me) == TYPE_DICTIONARY:
		var t := str(me.get("team", ""))
		if t != "":
			Global.my_team = t

	for username in players_dict:
		if username == Global.my_username:
			var pd = players_dict[username]
			# اگر پیامِ respawn به هر دلیلی نرسیده باشد، همین‌جا جبران
			# می‌شود: مرجع، جانی است که سرور می‌گوید.
			if typeof(pd) == TYPE_DICTIONARY:
				_sync_local_alive(int(pd.get("health", 0)),
					Vector2(pd.get("x", $Player.global_position.x),
							pd.get("y", $Player.global_position.y)))
			# 🌟 اول تراز، بعد ظاهر. ترتیبش مهم است: سقفِ جان از my_stats
			# خوانده می‌شود، پس اگر ظاهر زودتر اعمال شود با مقدارِ کهنه
			# حساب می‌کند و نوار جان یک لحظه اشتباه (مثلاً ۱۳۶/۱۱۲) می‌شود.
			if typeof(pd) == TYPE_DICTIONARY:
				_apply_stats(pd.get("stats", {}))
				# موجودیِ بمب مرجعش سرور است (با join دوباره پر نمی‌شود)
				if pd.has("bombs_left"):
					_set_bombs_left(int(pd["bombs_left"]))
			# سرور تجهیزات را از دیتابیس می‌خواند؛ همان حرف آخر است،
			# پس ظاهر خودمان را هم با آن هماهنگ می‌کنیم.
			_apply_local_appearance(pd)
			continue
		if not spawned_players.has(username):
			var new_enemy = other_player_scene.instantiate()
			new_enemy.name = username
			if "username" in new_enemy:
				new_enemy.username = str(username)
			var p_data = players_dict[username]
			var spawn_pos = Vector2(p_data.get("x", 300), p_data.get("y", 200))
			new_enemy.global_position = spawn_pos
			if "target_position" in new_enemy:
				new_enemy.target_position = spawn_pos
			new_enemy.rotation = p_data.get("rot", 0.0)
			if "target_rotation" in new_enemy:
				new_enemy.target_rotation = new_enemy.rotation
			# در زمینِ تاریک، کاراکترها هم باید تاریک باشند وگرنه مثل چراغ
			# از آن سرِ نقشه دیده می‌شوند. نورها روی همین رنگ جمع می‌شوند،
			# پس داخلِ کانونِ نور کاملاً روشن می‌شوند.
			var arena_node := get_node_or_null("Arena")
			if arena_node != null and "actor_tint" in arena_node:
				new_enemy.modulate = arena_node.actor_tint
			add_child(new_enemy)
			spawned_players[username] = new_enemy
			print("✅ بازیکن جدید: ", username)
			if new_enemy.has_method("setup_appearance"):
				new_enemy.setup_appearance(
					_look(p_data, "character_skin", str(p_data.get("character", "skin_default"))),
					_look(p_data, "weapon_skin", str(p_data.get("weapon", "pistol_default"))))
			# هم‌تیمی آبی، حریف قرمز
			if new_enemy.has_method("set_team"):
				new_enemy.set_team(_is_ally(p_data))
			if new_enemy.has_method("set_max_health"):
				new_enemy.set_max_health(_max_hp_of(p_data))
			if "health" in new_enemy:
				new_enemy.health = int(p_data.get("health", new_enemy.max_health))
			if new_enemy.has_method("update_health_bar"):
				new_enemy.update_health_bar(int(p_data.get("health", 100)), _max_hp_of(p_data))
			_last_health[username] = int(p_data.get("health", 100))
	# رنگِ پلاک را هر بار تازه می‌کنیم: ممکن است اولین update_players قبل از
	# ست شدنِ تیمِ خودمان رسیده باشد و آن موقع همه قرمز شده باشند.
	for username in spawned_players.keys():
		if players_dict.has(username) and is_instance_valid(spawned_players[username]):
			var node = spawned_players[username]
			if node.has_method("set_team"):
				node.set_team(_is_ally(players_dict[username]))
			# سرعتِ پایه‌ی هر بازیکن برای مرزِ انیمیشنِ دویدن (player_s.gd)
			var pd_s = players_dict[username]
			# سقفِ جانِ همین بازیکن (با عوض کردنِ کاراکتر/سطح عوض می‌شود)
			if typeof(pd_s) == TYPE_DICTIONARY and "max_health" in node:
				var mh := _max_hp_of(pd_s)
				if mh != int(node.max_health):
					node.max_health = mh
					if node.has_method("update_health_bar"):
						node.update_health_bar(int(node.health) if "health" in node else mh, mh)
			if "base_speed" in node and typeof(pd_s) == TYPE_DICTIONARY:
				var st = pd_s.get("stats", {})
				if typeof(st) == TYPE_DICTIONARY and float(st.get("speed", 0.0)) > 0.0:
					node.base_speed = float(st["speed"])

	# گنبدِ محافظِ تولد: سرور برای هر بازیکن باقی‌ماندهٔ محافظش را می‌فرستد
	# (shield_left). همین‌جا نشان داده می‌شود تا بازیکنی که وسطِ محافظِ حریف
	# تازه او را می‌بیند هم بفهمد چرا تیرش نمی‌گیرد.
	for username in players_dict:
		var pd = players_dict[username]
		if typeof(pd) != TYPE_DICTIONARY:
			continue
		var left := float(pd.get("shield_left", 0.0))
		if left > 0.0:
			_show_spawn_shield(str(username), left)
		else:
			# سرور محافظ را برداشته (وقتش تمام شد یا خودش شلیک کرد) —
			# گنبد نباید یک ثانیه هم بیشتر از چیزی که سرور اعمال می‌کند بماند
			_dismiss_spawn_shield(str(username))
		# سپرِ دستی هم همین‌طور — بازیکنی که وسطِ سپرِ کسی می‌رسد هم ببیندش
		var guard := float(pd.get("guard_left", 0.0))
		if guard > 0.0:
			_show_guard(str(username), guard)
		elif _guards.has(str(username)):
			_dismiss_guard(str(username))

	for username in spawned_players.keys():
		if not players_dict.has(username):
			# بازیکن از بازی رفته — بدون ناک‌اوت، فقط محو می‌شود
			if is_instance_valid(spawned_players[username]):
				CombatFX.death(spawned_players[username], false, 0.35)
			spawned_players.erase(username)
			_last_health.erase(username)

## آیا این بازیکن هم‌تیمیِ من است؟
##
## تیمِ خالی یعنی مسابقه‌ی بی‌تیم (تمرین) — آن‌جا همه حریف‌اند.
func _process(delta: float) -> void:
	if _spectating:
		_spectate_process(delta)
	if _sprint_left > 0.0:
		_sprint_left -= delta
		if _sprint_left <= 0.0:
			$Player.speed_mult = 1.0


# ==================== شیطانِ وسطِ زمین ====================
#
# «عملیات حذف شیطان»: وسطِ نقشه یک شیطان ایستاده و تیمی که بیشتر به او
# آسیب بزند برنده است. سرور (demon.go) تنها مرجع است — جا، جان، نفرین‌ها و برنده همه از
# آن‌جا می‌آیند و این‌جا فقط نشان داده می‌شوند.
#
# شلیک به شیطان کدِ تازه‌ای لازم ندارد: نودش StaticBody2D روی لایه‌ی
# بازیکن‌ها و در گروهِ "enemy" است، پس player.gd دقیقاً مثل یک حریف رویش
# قفل می‌کند و پیامِ hit را با نامِ قراردادیِ سرور می‌فرستد.

## وضعیتِ تازه‌ی شیطان. اولین باری که برسد، نودش ساخته می‌شود.
func _on_demon_state(data: Dictionary) -> void:
	var pos := Vector2(data.get("x", 0.0), data.get("y", 0.0))
	var r := float(data.get("radius", 96.0))
	var hp := int(data.get("health", 0))
	var max_hp := int(data.get("max_health", 1))

	if _demon == null or not is_instance_valid(_demon):
		if not bool(data.get("alive", true)):
			return          # مرده است و ما تازه رسیده‌ایم — ساختنش بی‌معنی است
		_demon = DEMON.new()
		add_child(_demon)
		_demon.setup(pos, r, hp, max_hp)
		# عمداً مثلِ بقیه‌ی کاراکترها با actor_tint تیره نمی‌شود: شیطان خودش
		# منبعِ نور است و هدفِ راند — باید با رنگِ واقعیِ آرتش از دور دیده شود
		if hud != null:
			hud.set_demon_visible(true)
		return

	_demon.apply_state(pos, r, hp, max_hp)


## شیطان ناحیه‌ای را نشانه گرفت — نشانگرِ اخطار روی زمین، با شمارشِ معکوسی
## که دقیقاً با مهلتِ سرور هماهنگ است.
##
## لرزشِ کوتاه هم می‌دهد (در تنظیمات قابلِ خاموش کردن): روی گوشی چشم همیشه
## به کفِ زمین نیست و اخطارِ فقط-بصری راحت از دست می‌رود.
func _on_demon_blast_warned(pos: Vector2, radius: float, delay: float) -> void:
	CombatFX.demon_mark(pos, radius, delay)
	# فقط وقتی به خودمان ربط دارد: نفرینی آن سرِ نقشه نباید گوشی را بلرزاند
	if _local_in_zone(pos, radius):
		LocalSettings.vibrate(60)


## ناحیه ترکید. خسارت را سرور زده (پیامِ health_update)؛ این فقط افکت است.
func _on_demon_blast_fired(pos: Vector2, radius: float) -> void:
	CombatFX.demon_blast(pos, radius)


## شیطان افتاد. نتیجه‌ی راند جدا با match_over می‌آید.
func _on_demon_slain(_team: String, pos: Vector2) -> void:
	if _demon != null and is_instance_valid(_demon):
		_demon.slay()
	else:
		CombatFX.demon_blast(pos, 190.0)
	if hud != null:
		hud.set_demon_visible(false)


## آیا بازیکنِ خودمان داخلِ این محدوده است؟
func _local_in_zone(pos: Vector2, radius: float) -> bool:
	if _match_ended or not is_instance_valid($Player) or $Player.is_dead:
		return false
	return $Player.global_position.distance_to(pos) <= radius


## جای شیطان برای مینی‌مپ و فلشِ راهنما. null یعنی این حالت شیطان ندارد.
func demon_position() -> Variant:
	if _demon != null and is_instance_valid(_demon):
		return _demon.global_position
	return null


# ==================== تماشا بعد از مرگ ====================
#
# مرگِ تو پایانِ بازی نیست: راند تا وقتی ادامه دارد که یک تیم کاملاً از پا
# دربیاید. پس تا وقتی هم‌تیمیِ زنده داری، دوربین می‌رود روی او؛ او هم که
# افتاد، می‌رود روی نفرِ بعدی. صفحه‌ی برد/باخت را round_hub بعد از
# match_over سرور نشان می‌دهد، نه لحظه‌ی مرگِ تو.

var _spectating := false
var _spectate_target := ""
var _spectate_banner: Label = null


## بعد از مرگِ بازیکنِ محلی: کنترل‌ها می‌روند، دوربین آزاد می‌شود.
func _enter_spectator() -> void:
	if _spectating:
		return
	_spectating = true

	# کنترل‌هایی که دیگر معنی ندارند (جوی‌استیک هم همراهشان خاموش می‌شود)
	if hud != null:
		hud.set_controls_visible(false)
	CombatFX.bomb_aim_hide()
	bomb_aiming = false
	_sprint_left = 0.0
	$Player.speed_mult = 1.0

	# دوربین از بدنه‌ی بازیکن جدا می‌شود تا بتواند دنبالِ هم‌تیمی برود.
	# top_level یعنی ترنسفورمِ والد را به ارث نمی‌برد — چرخشِ جنازه هم
	# دیگر دوربین را نمی‌چرخاند.
	var cam := get_node_or_null("Player/Camera2D")
	if cam != null:
		cam.top_level = true
		cam.global_position = $Player.global_position
		cam.rotation = 0.0

	_build_spectate_banner()
	_pick_spectate_target()


## برگشت از تماشا به بازی — فقط در حالت‌های ریسپاون‌دار پیش می‌آید
## (عملیات انتقام). کنترل‌ها و دوربین به حالتِ عادی برمی‌گردند.
func _leave_spectator() -> void:
	if not _spectating:
		return
	_spectating = false
	_spectate_target = ""
	if _spectate_banner != null:
		_spectate_banner.queue_free()
		_spectate_banner = null

	if hud != null:
		hud.set_controls_visible(true)

	# دوربین دوباره به بدنه‌ی بازیکن بچسبد
	var cam := get_node_or_null("Player/Camera2D")
	if cam != null:
		cam.top_level = false
		cam.position = Vector2.ZERO
		cam.rotation = 0.0


## هم‌تیمیِ زنده‌ی بعدی. اگر کسی نمانده باشد، فقط پیام عوض می‌شود و منتظرِ
## match_over می‌مانیم — سرور همان لحظه راند را تمام می‌کند.
func _pick_spectate_target() -> void:
	if not _spectating:
		return
	_spectate_target = ""
	var best_d := INF
	var cam := get_node_or_null("Player/Camera2D")
	var from: Vector2 = cam.global_position if cam != null else $Player.global_position
	for name in spawned_players:
		var n = spawned_players[name]
		if not is_instance_valid(n):
			continue
		if not ("is_ally" in n and n.is_ally):
			continue
		# نزدیک‌ترین هم‌تیمی، تا پرشِ دوربین کم‌ترین باشد
		var d: float = from.distance_squared_to(n.global_position)
		if d < best_d:
			best_d = d
			_spectate_target = name
	_update_spectate_banner()


func _on_match_over_spectate(_winner_team: String, _draw: bool) -> void:
	_spectating = false
	_match_ended = true
	if _spectate_banner != null:
		_spectate_banner.queue_free()
		_spectate_banner = null
	# نوارِ شیطان و فلشِ راهنما دیگر کاری ندارند و نباید پشتِ صفحه‌ی نتیجه
	# بمانند
	if hud != null:
		hud.set_demon_visible(false)

	# صفحه‌ی برد/باخت (round_hud → MatchResultScreen) روی زمین می‌آید. زمین
	# زیرش دیده می‌شود ولی قفل است: پنجره‌ی باز بسته، نشانه‌گیری رها و
	# جوی‌استیک خاموش. لمس‌های دیگر را لایه‌ی خودِ صفحه می‌گیرد.
	if _settings != null and _settings.visible:
		_settings.close()
	if bomb_aiming:
		bomb_aiming = false
		bomb_touch_index = -1
		CombatFX.bomb_aim_hide()
	if joystick != null and joystick.has_method("set_enabled"):
		joystick.set_enabled(false)


func _build_spectate_banner() -> void:
	if _spectate_banner != null:
		return
	var ui := get_node_or_null("UI")
	if ui == null:
		return
	_spectate_banner = Label.new()
	_spectate_banner.name = "SpectateBanner"
	_spectate_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spectate_banner.add_theme_font_size_override("font_size", 20)
	_spectate_banner.add_theme_color_override("font_color", Color(0.95, 0.86, 0.55))
	_spectate_banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_spectate_banner.add_theme_constant_override("shadow_offset_y", 2)
	_spectate_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_spectate_banner.offset_left = -260
	_spectate_banner.offset_right = 260
	_spectate_banner.offset_top = -96
	_spectate_banner.offset_bottom = -60
	_spectate_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_spectate_banner)


func _update_spectate_banner() -> void:
	if _spectate_banner == null:
		return
	# در «عملیات انتقام» مرگ موقتی است؛ گفتنِ «حذف شدید» آن‌جا دروغ است
	if bool(Network.round_info.get("respawn", false)):
		if _spectate_target == "":
			_spectate_banner.text = "کشته شدی — چند ثانیه‌ی دیگر برمی‌گردی"
		else:
			_spectate_banner.text = "کشته شدی — تماشای %s تا برگشتنت" % _spectate_target
		return
	if _spectate_target == "":
		_spectate_banner.text = "شما حذف شدید — منتظرِ پایانِ راند"
	else:
		_spectate_banner.text = "شما حذف شدید — تماشای %s" % _spectate_target


## دوربین هر فریم روی هم‌تیمیِ انتخاب‌شده می‌نشیند. نرم دنبال می‌کند تا
## پرشِ ناگهانی نداشته باشد.
func _spectate_process(delta: float) -> void:
	var cam := get_node_or_null("Player/Camera2D")
	if cam == null:
		return
	if _spectate_target == "" or not spawned_players.has(_spectate_target):
		_pick_spectate_target()
		if _spectate_target == "":
			return
	var n = spawned_players.get(_spectate_target, null)
	if not is_instance_valid(n):
		_pick_spectate_target()
		return
	cam.global_position = cam.global_position.lerp(n.global_position, 1.0 - exp(-8.0 * delta))


func _is_ally(p_data) -> bool:
	if typeof(p_data) != TYPE_DICTIONARY or Global.my_team == "":
		return false
	return str(p_data.get("team", "")) == Global.my_team


## ظاهر بازیکن محلی را با تجهیزاتی که سرور از دیتابیس خوانده ست می‌کند.
func _apply_local_appearance(p_data) -> void:
	if typeof(p_data) != TYPE_DICTIONARY:
		return

	var character_id = str(p_data.get("character", ""))
	if character_id != "" and character_id != Global.current_character:
		Global.current_character = character_id
	if character_id != "":
		CharacterSkin.apply(player_sprite, _look(p_data, "character_skin", character_id))
		max_health = get_character_max_health(character_id)

	# 🌟 جان همیشه با همین پیام هماهنگ می‌شود — نه فقط وقتی سقفش عوض شده.
	# قبلاً این‌جا فقط نوار را (و آن‌هم گاهی) آپدیت می‌کرد، ولی $Player.health
	# را دست نمی‌زد؛ یعنی داخلیِ بازیکن روی پیش‌فرضِ اسکریپت (۱۰۰) می‌ماند تا
	# اولین ضربه یا درمان — حتی وقتی سقفِ واقعی‌اش بیشتر یا کمتر از ۱۰۰ بود.
	# نتیجه‌اش این بود که جانِ اولِ بازی «پر» به نظر نمی‌رسید.
	if "health" in $Player:
		$Player.health = int(p_data.get("health", max_health))
	update_player_health_ui(int(p_data.get("health", max_health)), max_health)

	var weapon_id = str(p_data.get("weapon", ""))
	if weapon_id != "" and weapon_sprite != null:
		if weapon_id != Global.current_weapon:
			Global.current_weapon = weapon_id
		WeaponSkin.apply(weapon_sprite, _look(p_data, "weapon_skin", weapon_id))


## اسکینی که سرور برای این بازیکن فرستاده؛ خالی یعنی ظاهر پیش‌فرض آیتم
func _look(p_data: Dictionary, skin_key: String, base_id: String) -> String:
	var skin := str(p_data.get(skin_key, "")).strip_edges()
	return skin if not skin.is_empty() else base_id

func _on_player_moved(username, new_pos, rot):
	if spawned_players.has(username):
		var enemy = spawned_players[username]
		if is_instance_valid(enemy):
			if "target_position" in enemy:
				enemy.target_position = new_pos
			if "target_rotation" in enemy:
				enemy.target_rotation = rot
		else:
			spawned_players.erase(username)

func _on_player_shot(username, pos, rot):
	if spawned_players.has(username):
		var enemy = spawned_players[username]
		if is_instance_valid(enemy) and enemy.has_method("fire_gun"):
			enemy.fire_gun(pos, rot)

func _on_health_updated(username: String, new_health: int):
	if username == Global.my_username:
		_sync_local_alive(new_health, $Player.global_position)
		if "health" in $Player:
			if new_health < $Player.health:
				CombatFX.hit_burst($Player.global_position, Vector2(0, -1))
				CombatFX.damage_number($Player.global_position, $Player.health - new_health)
				CombatFX.shake(6.0)
				_feel_local_damage()
				# V4: کمانِ قرمزِ جهتِ آسیب دورِ مرکز + صدای ضربه
				if feel != null:
					feel.on_local_damaged($Player.health - new_health, max_health)
			$Player.health = new_health
		update_player_health_ui(new_health, max_health)
		return
	if spawned_players.has(username):
		var p = spawned_players[username]
		if is_instance_valid(p):
			# 🌟 هر بار که جان کم شد: جرقه + عددِ خسارت، تا ضربه دیده شود
			var prev: int = int(_last_health.get(username, new_health))
			if prev > new_health:
				CombatFX.hit_burst(p.global_position, Vector2(0, -1))
				# V1: خسارتِ خودت طلایی، بقیه خنثی، آسیبِ هم‌تیمی قرمز (خطر)
				var ally: bool = "is_ally" in p and p.is_ally
				var mine: bool = not ally and feel != null					 and feel.credit_mine(username, p.global_position, 600)
				var kind: int = CombatFX.DMG_TAKEN if ally else (CombatFX.DMG_MINE if mine else CombatFX.DMG_OTHER)
				CombatFX.damage_number(p.global_position, prev - new_health, false, kind)
				if not ally:
					if p.has_method("flash_hit"):
						p.flash_hit(mine)
					if feel != null:
						feel.on_enemy_hit(mine)
			_last_health[username] = new_health
			if "health" in p:
				p.health = new_health
			if p.has_method("update_health_bar"):
				p.update_health_bar(new_health, p.max_health)

## لرزش و فلشِ قرمزِ تیر خوردن. لرزش حداکثر هر ۱۵۰ms یک بار — رگبارِ
## تیربار وگرنه گوشی را یک‌سره می‌لرزاند (و باتری می‌خورد). خاموش بودنش در
## تنظیمات را خودِ LocalSettings.vibrate رعایت می‌کند.
##
## flash_damage / set_low_health مالِ game_hud.gd است؛ با has_method و call
## صدا زده می‌شوند تا اگر HUD هنوز آن‌ها را ندارد چیزی نشکند.
const HIT_VIBRATE_GAP_MS := 150
var _last_hit_vibrate_ms := -100000

func _feel_local_damage() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hit_vibrate_ms >= HIT_VIBRATE_GAP_MS:
		_last_hit_vibrate_ms = now
		LocalSettings.vibrate(25)
	if hud != null and hud.has_method("flash_damage"):
		hud.call("flash_damage")
	# کارتِ پروفایلِ کم‌رنگ‌شده (game_hud → focus) با هر ضربه بیدار شود
	if hud != null and hud.get("focus") != null and hud.focus.has_method("wake"):
		hud.focus.wake(hud.profile, true)


## حاشیه‌ی «جانِ کم» زیرِ ۳۰٪ — از update_player_health_ui صدا زده می‌شود،
## پس درمان، برگشت به بازی و مرگ هم خاموشش می‌کنند
func _update_low_health(hp: int, max_hp: int) -> void:
	var low := max_hp > 0 and hp > 0 and float(hp) / float(max_hp) < 0.3
	if hud != null and hud.has_method("set_low_health") and max_hp > 0:
		hud.call("set_low_health", low)
	# E11: ضربانِ قلب هم‌گام با همین حاشیه
	if feel != null:
		feel.set_low_health(low)


## کشتنِ حریف توسطِ خودمان. سرور در پیامِ die قاتل را نمی‌فرستد، پس از روی
## آخرین ضربه‌ای که خودمان به همین بازیکن فرستادیم حدس می‌زنیم: اگر
## کمتر از KILL_CREDIT_MS بعد از ضربه‌مان مُرد، کشته‌ی ما حساب می‌شود.
const KILL_CREDIT_MS := 700

func _is_my_kill(username: String, pos := Vector2.INF) -> bool:
	# بمب و لیزرِ خودت هم کیل‌اند، نه فقط تیر (psych_combat_feel.gd)
	if feel != null and pos.is_finite():
		return feel.credit_mine(username, pos, KILL_CREDIT_MS)
	var p = get_node_or_null("Player")
	if p == null or not ("last_hit_target" in p):
		return false
	if str(p.last_hit_target) != username:
		return false
	return Time.get_ticks_msec() - int(p.last_hit_ms) <= KILL_CREDIT_MS


func _on_player_died(username: String):
	if username != Global.my_username:
		var victim = spawned_players.get(username, null)
		var vpos: Vector2 = victim.global_position if is_instance_valid(victim) else Vector2.INF
		var ally: bool = is_instance_valid(victim) and "is_ally" in victim and victim.is_ally
		# C10: اگر سرور قاتل را گفت همان ملاک است؛ وگرنه حدسِ سمتِ کلاینت
		var server_killer: String = Network.death_killer(username)
		var mine: bool = server_killer == Global.my_username if server_killer != "" \
				else _is_my_kill(username, vpos)
		if not ally and mine:
			if not Global.offline_mode:
				# E8: کیلِ آنلاین با سلاح/کاراکترِ فعلی (بازیِ سریع خودش می‌شمارد)
				preload("res://scripts/psych_menu_loadout_stats.gd").record_kills(1)
			# V7/E11: سکه و حلقه‌ی طلایی، دینگ، لرزش، hit-stop و اعلانِ استریک
			if feel != null:
				feel.on_local_kill(username, vpos)
			else:
				LocalSettings.vibrate(40)
	if feel != null:
		feel.note_death()
	if username == Global.my_username:
		if "is_dead" in $Player and not $Player.is_dead and $Player.has_method("die"):
			$Player.die()
		update_player_health_ui(0, max_health)
		_enter_spectator()
	else:
		if spawned_players.has(username):
			var enemy = spawned_players[username]
			# 🌟 ناک‌اوت: پفِ دود و ستاره‌ها، و خود حریف داخلِ دود محو می‌شود.
			# CombatFX.death بعد از محو شدن نود را آزاد می‌کند.
			if is_instance_valid(enemy):
				# جنازه تا نیم‌ثانیه در صحنه می‌ماند. تا آن موقع نه باید
				# هدف باشد و نه اسمِ بازیکن را گرو بگیرد: اگر سرور همان
				# لحظه نودِ تازه‌اش را بسازد، گودوت اسمِ تکراری را عوض
				# می‌کند («Ali» → «Ali2») و از آن به بعد hit با نامِ اشتباه
				# می‌رفت — یعنی شلیک می‌کردی و هیچ‌چیز ثبت نمی‌شد.
				enemy.remove_from_group("enemy")
				enemy.name = "%s_dead" % username
				CombatFX.death(enemy)
			spawned_players.erase(username)
			_last_health.erase(username)
		# اگر داشتم همین را تماشا می‌کردم، برو سراغ هم‌تیمیِ بعدی
		if _spectating and username == _spectate_target:
			_pick_spectate_target()

# ==================== HEAL ====================
func _on_heal_button_pressed():
	if $Player.is_dead or not hud.button("heal").is_ready():
		return
	if $Player.health >= max_health:
		hud.button("heal").deny()   # جان پر است؛ دکمه هدر نرود
		return
	Network.send_heal_request()

func _on_heal_success(username: String, new_health: int):
	if username == Global.my_username:
		var gained: int = new_health - int($Player.health)
		$Player.health = new_health
		update_player_health_ui(new_health, max_health)
		_spawn_heal_effect($Player.global_position)
		CombatFX.damage_number($Player.global_position, gained, true)
	else:
		if spawned_players.has(username):
			var p = spawned_players[username]
			if is_instance_valid(p):
				if "health" in p:
					p.health = new_health
				if p.has_method("update_health_bar"):
					p.update_health_bar(new_health, p.max_health)
				var healed: int = new_health - int(_last_health.get(username, new_health))
				_spawn_heal_effect(p.global_position)
				# درمانِ حریف/هم‌تیمی هم دیده شود، نه فقط نوارش بی‌صدا پر شود
				if healed > 0:
					CombatFX.damage_number(p.global_position, healed, true)
				_last_health[username] = new_health

## سرور تیرِ ما را با تاسِ دقت رد کرد: ردِ تیر کشیده شده بود ولی خسارتی
## نیامد — بدونِ این بازیکن فکر می‌کرد تیرش «گم شده».
func _on_hit_missed(target: String) -> void:
	var p = spawned_players.get(target, null)
	if p != null and is_instance_valid(p):
		CombatFX.float_text(p.global_position, "خطا", Color(0.85, 0.85, 0.85))


func _on_heal_cooldown_started(username: String, seconds: int = 12):
	# طولِ شمارش‌معکوس از تراز خودِ کاراکتر می‌آید (health_regen)
	if username == Global.my_username and hud != null:
		hud.button("heal").run(0.0, float(seconds))

func _spawn_heal_effect(pos: Vector2):
	CombatFX.heal(pos)


# ==================== BOMB ====================
## دکمه‌ی بمب: انگشت را نگه دار و بکش تا هم جهت و هم فاصله را انتخاب کنی.
## ضربه‌ی ساده (بدون کشیدن) = پرتاب با بیشترین بردِ کاراکتر، رو به جلو.
## فقط شروعِ نشانه‌گیری از خودِ دکمه گرفته می‌شود. ادامه‌ی کشیدن و رها
## کردن در _input دنبال می‌شود، چون وقتی انگشت از روی دکمه بیرون می‌رود
## دیگر gui_input رویداد نمی‌گیرد و نشانه‌گیری وسط راه قطع می‌شد.
func _on_bomb_button_input(event: InputEvent) -> void:
	if not bomb_button.is_ready() or $Player.is_dead or bomb_aiming or bombs_left <= 0:
		return
	var started := false
	if event is InputEventScreenTouch and event.pressed:
		bomb_touch_index = event.index
		started = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		bomb_touch_index = -1
		started = true
	if not started:
		return

	bomb_aiming = true
	# تا وقتی انگشت تکان نخورده: پیش‌نمایشِ رو به جلو با بیشترین برد.
	# به محض اینکه انگشت جابه‌جا شود، هدف را خودِ انگشت تعیین می‌کند.
	bomb_aim_positional = false
	bomb_aim_dir = Vector2.RIGHT.rotated($Player.rotation - deg_to_rad(90))
	bomb_aim_dist = float(my_stats.get("bomb_range", 380.0))
	_update_bomb_aim()


func _input(event: InputEvent) -> void:
	if not bomb_aiming:
		return

	# --- کشیدن: جهت و فاصله را تعیین می‌کند ---
	var dragging := false
	var at := Vector2.ZERO
	if event is InputEventScreenDrag:
		# گودوت فقط برای انگشتِ اول ماوسِ شبیه‌سازی‌شده می‌سازد. اگر همان لحظه
		# جوی‌استیک هم گرفته شده باشد، لمسِ بمب انگشتِ دوم است و شماره‌اش با
		# چیزی که موقع فشار دادن دکمه ثبت شده جور در نمی‌آید — قبلاً همین باعث
		# می‌شد کشیدن اصلاً دیده نشود و بمب روی مقدارِ اولیه (بردِ بیشینه) بماند.
		# پس هر کشیدنی که مالِ جوی‌استیک نیست، مالِ نشانه‌گیریِ بمب است.
		var js_idx: int = joystick.touch_index if joystick != null else -1
		var other_finger: bool = bomb_touch_index == -1 and event.index != js_idx
		if event.index == bomb_touch_index or other_finger:
			dragging = true
			at = event.position
			bomb_touch_index = event.index  # از این به بعد همین انگشت را دنبال کن
	elif event is InputEventMouseMotion and bomb_touch_index == -1:
		dragging = true
		at = event.position

	if dragging:
		# بمب همان‌جایی می‌افتد که انگشت نشان می‌دهد — نه بر اساس اینکه
		# چقدر انگشت را کشیده‌ای. اگر جای انگشت دورتر از بردِ کاراکتر باشد،
		# روی همان جهت تا لبه‌ی برد کوتاه می‌شود.
		var center: Vector2 = bomb_button.get_global_rect().get_center()
		if at.distance_to(center) > BOMB_DRAG_DEADZONE:
			bomb_aim_positional = true
			bomb_aim_target = _screen_to_world(at)
		_update_bomb_aim()
		get_viewport().set_input_as_handled()
		return

	# --- رها کردن: پرتاب ---
	var released := false
	if event is InputEventScreenTouch and not event.pressed and event.index == bomb_touch_index:
		released = true
	elif event is InputEventMouseButton and not event.pressed and bomb_touch_index == -1:
		released = true

	if released:
		# ضربه‌ی ساده (بدون کشیدن): تا حالا کورکورانه تا انتهای برد پرت می‌شد،
		# برای همین حس می‌شد بمب همیشه یک فاصله‌ی ثابت می‌رود. حالا اگر دشمنی
		# در دسترس باشد همان را هدف می‌گیرد؛ اگر نبود، مثل قبل رو به جلو.
		if not bomb_aim_positional:
			var enemy = $Player._nearest_target()
			if enemy != null:
				bomb_aim_positional = true
				bomb_aim_target = enemy.global_position
		# بازیکن ممکن است وسط نشانه‌گیری جابه‌جا شده باشد؛ جهت و فاصله را
		# از موقعیتِ همین لحظه دوباره حساب کن تا بمب دقیقاً روی همان نقطه‌ای
		# بیفتد که نشانگر نشان می‌داد.
		_update_bomb_aim()
		bomb_aiming = false
		bomb_aim_positional = false
		bomb_touch_index = -1
		CombatFX.bomb_aim_hide()
		_throw_bomb(bomb_aim_dir, bomb_aim_dist)
		start_bomb_cooldown_ui()
		get_viewport().set_input_as_handled()


## پرتابِ واقعیِ بمب. آنلاین فقط یک درخواست به سرور می‌رود و سرور تصمیم
## می‌گیرد کجا بیفتد؛ بازی سریع این را override می‌کند و خودش می‌اندازد.
func _throw_bomb(dir: Vector2, dist: float) -> void:
	Network.send_bomb_request(dir, dist)


## نقطه‌ی روی صفحه را به مختصات جهانی تبدیل می‌کند (دوربین روی بازیکن است،
## پس بدون این تبدیل، مختصات انگشت هیچ ربطی به زمین بازی ندارد).
func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


## خطِ پرتاب و دایره‌ی محدوده را همان‌جایی که انگشت نشانه گرفته می‌کشد
func _update_bomb_aim() -> void:
	var from: Vector2 = $Player.global_position
	# هدف از روی جای انگشت حساب می‌شود، نه از روی اندازه‌ی کشیدن.
	if bomb_aim_positional:
		var to_target: Vector2 = bomb_aim_target - from
		if to_target.length() > 0.01:
			bomb_aim_dir = to_target.normalized()
			bomb_aim_dist = clampf(to_target.length(), BOMB_MIN_RANGE,
					float(my_stats.get("bomb_range", 380.0)))
	var target := from + bomb_aim_dir * bomb_aim_dist
	# اگر دیواری سر راه است، بمب همان‌جا می‌افتد — پیش‌نمایش هم باید راست بگوید
	var hit: Array = CombatFX.resolve_hit(from, bomb_aim_dir, [$Player.get_rid()])
	var wall: Vector2 = hit[0]
	if from.distance_to(wall) < bomb_aim_dist:
		target = wall
	CombatFX.bomb_aim(from, target, float(my_stats.get("bomb_radius", 104.0)), true)

## شمارش‌معکوسِ دکمه‌ی بمب. آنلاین همین لحظه‌ی رها کردن شروع می‌شود (تا
## پرتابِ دوم پشتِ‌سرِ اولی نرود) و با پیامِ ability سرور دوباره هماهنگ می‌شود.
func start_bomb_cooldown_ui():
	if bomb_button != null:
		bomb_button.run(0.0, Abilities.BOMB_COOLDOWN)


func _set_bombs_left(n: int) -> void:
	bombs_left = maxi(n, 0)
	if bomb_button != null:
		bomb_button.set_badge(bombs_left)


# ==================== توانایی‌ها ====================
# دویدن، سپر، لیزر و درمانِ تیمی. آنلاین فقط درخواست به سرور می‌رود و سرور
# با پیامِ ability جواب می‌دهد (مدتِ فعال و قفل)؛ دکمه و افکت از همان جواب
# ساخته می‌شوند، پس چیزی که دیده می‌شود همان است که سرور اعمال می‌کند.
# بازیِ سریع _request_ability را override می‌کند و خودش همه را انجام می‌دهد.

func _on_ability_button(kind: String) -> void:
	if $Player.is_dead or _spectating:
		return
	match kind:
		"bomb":
			# پرتاب از راهِ نشانه‌گیری است (_on_bomb_button_input)؛ این‌جا فقط
			# وقتی بمبی نمانده دکمه می‌لرزد
			if bombs_left <= 0:
				bomb_button.deny()
			return
		"heal":
			_on_heal_button_pressed()
			return
		"team_heal":
			if not _team_heal_useful():
				hud.button(kind).deny()
				return
	_request_ability(kind)


## آنلاین: فقط درخواست. quick_play.gd این را override می‌کند.
func _request_ability(kind: String) -> void:
	Network.send_ability(kind)


## درمانِ تیمی وقتی معنی دارد که خودم یا هم‌تیمیِ نزدیکی زخمی باشد
func _team_heal_useful() -> bool:
	if int($Player.health) < max_health:
		return true
	for n in spawned_players.values():
		if not is_instance_valid(n) or not ("is_ally" in n and n.is_ally):
			continue
		if $Player.global_position.distance_to(n.global_position) > Abilities.TEAM_HEAL_RADIUS:
			continue
		if "health" in n and "max_health" in n and int(n.health) < int(n.max_health):
			return true
	return false


## سرور: کسی توانایی زد
func _on_ability(data: Dictionary) -> void:
	var user := str(data.get("username", ""))
	var kind := str(data.get("kind", ""))
	var active := float(data.get("active", 0.0))
	var cooldown := float(data.get("cooldown", 0.0))
	if user == Global.my_username and hud != null:
		if kind == "bomb":
			_set_bombs_left(int(data.get("bombs_left", bombs_left)))
			bomb_button.run(0.0, cooldown)
		elif hud.button(kind) != null:
			hud.button(kind).run(active, cooldown)
	play_ability_fx(user, kind, active)


## افکتِ هر توانایی روی نودِ همان بازیکن (برای همه‌ی کلاینت‌ها)
func play_ability_fx(user: String, kind: String, active: float) -> Node:
	var node := _actor_node(user)
	if node == null:
		return null
	match kind:
		"sprint":
			var old = _trails.get(user, null)
			if old != null and is_instance_valid(old):
				old.refresh(active)
			else:
				var trail := SPRINT_TRAIL.new()
				add_child(trail)
				trail.setup(node, active)
				_trails[user] = trail
			if user == Global.my_username:
				# کمی زودتر از سرور تمام می‌شود تا حرکتِ تند اصلاح نخورد
				$Player.speed_mult = Abilities.SPRINT_MULT
				_sprint_left = maxf(active - 0.1, 0.0)
		"guard":
			_show_guard(user, active)
		"laser":
			var beam := LASER_BEAM.new()
			add_child(beam)
			beam.setup(node, active, Global.offline_mode and user == Global.my_username)
			if user == Global.my_username:
				CombatFX.shake(4.0)
			return beam
		"team_heal":
			var ring := PULSE_RING.new()
			add_child(ring)
			ring.setup(node.global_position, Abilities.TEAM_HEAL_RADIUS, TEAM_HEAL_COL)
			CombatFX.heal(node.global_position)
	return null


# ==================== اهداف ====================

func _on_objectives(list: Array) -> void:
	if hud != null:
		hud.objectives.set_objectives(list)


func _on_objective_updated(id: String, progress: int, target: int, done: bool) -> void:
	if hud != null:
		hud.objectives.update_objective(id, progress, target, done)


# ==================== منو، Back و چرخه‌ی عمرِ اپ ====================

## دکمه‌ی بالا-راست. آنلاین فقط تنظیمات است (بازی متوقف نمی‌شود)؛
## بازیِ سریع این را override می‌کند و توقف باز می‌کند.
func _on_menu_pressed() -> void:
	if _settings == null:
		_settings = INGAME_SETTINGS.new()
		add_child(_settings)
		_settings.closed.connect(func():
			if not _spectating and not _match_ended and joystick != null:
				joystick.set_enabled(true))
		_settings.leave_confirmed.connect(_leave_match)
	if _settings.visible:
		_settings.close()
		return
	# زیرِ پنجره جوی‌استیک نباید بازیکن را راه ببرد
	if joystick != null:
		joystick.set_enabled(false)
	_settings.open()


func _leave_match() -> void:
	Network.send_leave_arena()
	get_tree().change_scene_to_file("res://secense/main_menu.tscn")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back()
		NOTIFICATION_APPLICATION_PAUSED:
			_on_app_paused()
		NOTIFICATION_EXIT_TREE:
			get_tree().set_quit_on_go_back(true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()


## Back اندروید: پنجره‌ی باز را می‌بندد، وگرنه منو (تنظیمات/توقف) را باز می‌کند.
## هم notification می‌آید هم ui_cancel؛ فقط یک بار در هر فریم.
func _on_back() -> void:
	var frame := Engine.get_process_frames()
	if frame == _back_frame:
		return
	_back_frame = frame
	# بعد از پایانِ مسابقه Back یعنی همان دکمه‌ی صفحه‌ی نتیجه (برگشت به لابی)
	var result := get_tree().get_first_node_in_group(MatchResultScreen.GROUP) as MatchResultScreen
	if result != null:
		result.handle_back()
		return
	_on_menu_pressed()


## اپ رفت پس‌زمینه (تماس، minimize). آنلاین نمی‌شود بازی را نگه داشت —
## بقیه دارند بازی می‌کنند — فقط دویدن و نشانه‌گیری رها می‌شوند تا انگشتِ
## «گیر کرده» بعد از برگشت بازیکن را راه نبرد. بازیِ سریع توقف می‌کند.
func _on_app_paused() -> void:
	if bomb_aiming:
		bomb_aiming = false
		bomb_touch_index = -1
		CombatFX.bomb_aim_hide()
	var menu_open := _settings != null and _settings.visible
	if joystick != null and joystick.has_method("set_enabled") and not _spectating and not menu_open \
			and not _match_ended:
		joystick.set_enabled(false)
		joystick.set_enabled(true)

# 🌟 وقتی سرور پیام پرتاب بمب رو فرستاد
func _on_bomb_thrown(data: Dictionary):
	var start_pos = Vector2(data.get("start_x", 0), data.get("start_y", 0))
	var exp_pos = Vector2(data.get("explosion_x", 0), data.get("explosion_y", 0))
	var radius = data.get("bomb_radius", 100.0)
	var shooter = data.get("username", "")
	_spawn_bomb_animation(start_pos, exp_pos, radius)

# 🌟 انیمیشن بمب: پرتاب + مکث + انفجار
# 🌟 انیمیشن بمب: پرتاب با فیزیک (کاهش سرعت تدریجی) + مکث + انفجار
func _spawn_bomb_animation(start_pos: Vector2, exp_pos: Vector2, radius: float):
	if bomb_scene == null:
		print("⚠️ bomb_scene ست نشده! توی اینسپکتر World ستش کن")
		return
	
	# ساخت نمونه‌ای از صحنه بمب
	var bomb = bomb_scene.instantiate()
	bomb.global_position = start_pos
	bomb.z_index = 60
	add_child(bomb)
	
	# 🌟 انیمیشن فیزیک‌طور: سرعت تدریجاً کم می‌شه
	# تقسیم مسیر به ۴ بخش با زمان‌های مختلف
	var total_distance = start_pos.distance_to(exp_pos)
	var segment1 = start_pos.lerp(exp_pos, 0.5)  # ۵۰٪ مسیر
	var segment2 = start_pos.lerp(exp_pos, 0.75) # ۷۵٪ مسیر
	var segment3 = start_pos.lerp(exp_pos, 0.875) # ۸۷.۵٪ مسیر
	var segment4 = start_pos.lerp(exp_pos, 0.9375) # ۹۳.۷۵٪ مسیر
	
	var tween = create_tween()
	
	# بخش ۱: ۵۰٪ مسیر در ۰.۲ ثانیه (سریع)
	tween.tween_property(bomb, "global_position", segment1, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# بخش ۲: ۲۵٪ مسیر در ۰.۱۵ ثانیه (کمی کندتر)
	tween.tween_property(bomb, "global_position", segment2, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# بخش ۳: ۱۲.۵٪ مسیر در ۰.۱ ثانیه (کندتر)
	tween.tween_property(bomb, "global_position", segment3, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# بخش ۴: ۶.۲۵٪ مسیر در ۰.۰۵ ثانیه (خیلی کند)
	tween.tween_property(bomb, "global_position", segment4, 0.05).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# بخش نهایی: رسیدن به مقصد
	tween.tween_property(bomb, "global_position", exp_pos, 0.05).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	# 🌟 تا بمب نشست، محدوده‌ی انفجار را علامت بزن — حلقه‌ی خط‌چینِ چرخان با
	# موجی که دقیقاً هم‌زمان با فیوز پر می‌شود، پس بازیکن فرصت فرار دارد.
	tween.tween_callback(func():
		CombatFX.bomb_marker(exp_pos, radius, BOMB_FUSE)
	)

	# مکث فیوز
	tween.tween_interval(BOMB_FUSE)

	# انفجار
	tween.tween_callback(func():
		bomb_sound.play()
		if is_instance_valid(bomb):
			bomb.queue_free()
		CombatFX.explosion(exp_pos, radius)
	)

# 🌟 وقتی سرور پیام انفجار رو فرستاد (برای کلاینت‌های دیگه که انیمیشن پرتاب رو ندیدن)
func _on_bomb_explosion(data: Dictionary):
	var exp_pos = Vector2(data.get("explosion_x", 0), data.get("explosion_y", 0))
	var radius = data.get("explosion_radius", 100.0)
	CombatFX.explosion(exp_pos, radius)
