extends "res://scripts/world.gd"
## «بازی سریع» — تمرینِ تک‌نفره روی همان زمینِ بازیِ آنلاین.
##
## عمداً از world.gd ارث می‌برد و صحنه‌اش کپیِ مو‌به‌موی World.tscn است، تا
## زمین، دوربین، جوی‌استیک، HUD، نشانه‌گیریِ بمب و دکمه‌ی درمان دقیقاً همان
## چیزی باشند که در بازیِ آنلاین هستند. تنها فرقش این است که سروری در کار
## نیست: Global.offline_mode روشن می‌شود و داورِ تیر و جان و مرگ خودِ کلاینت است.

const MENU := preload("res://scripts/quick_play_menu.gd")
const BOT_SCENE := preload("res://secense/player_s.tscn")
const BOT_SCRIPT := preload("res://scripts/bot.gd")

## ریتمِ اسپاون برای هر سطح: [فاصله‌ی ثانیه, سقفِ همزمان]
## E8: کیل‌های تمرین هم در آمارِ شخصیِ اسلحه/کاراکتر ثبت می‌شوند
const PSYCH_LOADOUT := preload("res://scripts/psych_menu_loadout_stats.gd")
const PACING := [[20.0, 2], [15.0, 3], [11.0, 4]]
## حریف‌ها این‌قدر از بازیکن دور متولد می‌شوند که ناگهانی روی سرش نیفتند
const MIN_SPAWN_DIST := 420.0

var _bots: Array[Node2D] = []
var _spawn_timer := 3.0
var _kills := 0
var _menu: CanvasLayer = null
var _alive_time := 0.0
var _damage_dealt := 0
## سپرِ دستیِ آفلاین: تا این لحظه (ثانیه‌ی موتور) هیچ خسارتی نمی‌رسد
var _guard_until := 0.0
var _hud_refresh := 0.0


func _ready() -> void:
	# باید قبل از super اجرا شود: world.gd در _ready خودش به Network نگاه
	# می‌کند و از روی همین پرچم Global.offline_mode را تثبیت می‌کند.
	is_offline_scene = true
	Global.offline_mode = true
	await super._ready()
	# آنلاین، سرور جانِ واقعی و تواناییِ کاراکتر را می‌فرستد و کلاینت با آن
	# هماهنگ می‌شود. آفلاین کسی نمی‌فرستد، پس بازیکن روی مقدارِ پیش‌فرضِ
	# اسکریپت (۱۰۰) می‌ماند در حالی که سقفش ۱۱۲ است — نوار جان از همان اول
	# دروغ می‌گفت. اینجا خودمان کاملش می‌کنیم.
	_apply_stats(my_stats)
	$Player.health = max_health
	update_player_health_ui(max_health, max_health)
	_refresh_round_hud()
	_menu = MENU.new()
	_menu.name = "QuickPlayMenu"
	add_child(_menu)
	_menu.resume_pressed.connect(_resume)
	_menu.restart_pressed.connect(_restart)
	_menu.quit_pressed.connect(_quit_to_menu)
	_alive_time = 0.0
	# آموزش که تمام شد، اولین حریف زود برسد
	if Tutorial.is_running() and not Tutorial.finished.is_connected(_on_tutorial_finished):
		Tutorial.finished.connect(_on_tutorial_finished)


func _on_tutorial_finished() -> void:
	_spawn_timer = 2.0
	_alive_time = 0.0


func _exit_tree() -> void:
	# برگشت به منو یعنی برگشت به دنیای آنلاین. مکث هم باید برداشته شود،
	# وگرنه صحنه‌ی بعدی (منوی اصلی) یخ‌زده باز می‌شود.
	Global.offline_mode = false
	get_tree().paused = false


## --- منوی توقف ---
## دکمه‌ی توقف همان دکمه‌ی بالا-راستِ GameHUD است (آنلاین جایش تنظیمات است).

func _on_menu_pressed() -> void:
	if _menu == null:
		return
	if _menu.visible:
		# Back روی منوی باز یعنی ادامه — ولی صفحه‌ی باخت «ادامه» ندارد
		if not $Player.is_dead:
			_resume()
		return
	_pause()


## اپ رفت پس‌زمینه (تماس، minimize): بازیِ آفلاین همان‌جا متوقف می‌شود
func _on_app_paused() -> void:
	super._on_app_paused()
	_pause()


func _stats() -> Dictionary:
	var secs := int(_alive_time)
	var names := ["آسان", "متوسط", "سخت"]
	return {
		"سطح": names[clampi(Global.quick_play_difficulty, 0, 2)],
		"کشته": _kills,
		"خسارت": _damage_dealt,
		"دوام": "%d:%02d" % [secs / 60, secs % 60],
	}


func _pause() -> void:
	if _menu == null or _menu.visible or $Player.is_dead:
		return
	# وسطِ آموزش حریفی نیست که بازی را نگه داریم، و منو زیرِ پرده‌ی آموزش گیر می‌کرد
	if Tutorial.is_running():
		return
	get_tree().paused = true
	_menu.open_paused(_stats())


func _resume() -> void:
	if _menu != null:
		_menu.close()
	get_tree().paused = false


func _restart() -> void:
	get_tree().paused = false
	# offline_mode را _exit_tree خودش برمی‌گرداند، و _ready دوباره روشنش می‌کند.
	# زمینِ تازه هم پشتِ صفحه‌ی بارگذاری ساخته می‌شود.
	LoadingScreen.change_scene("res://secense/quick_play.tscn", "در حال شروعِ دوباره")


func _quit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://secense/main_menu.tscn")


func _process(delta: float) -> void:
	super._process(delta)
	if not $Player.is_dead:
		_alive_time += delta
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _pacing()[0]
		_spawn_bot()
	# _bots دیگر هر فریم فیلتر نمی‌شود (یک آرایه‌ی تازه در هر فریم)؛ بات
	# خودش موقعِ بیرون رفتن از درخت از فهرست پاک می‌شود (_forget_bot)
	_hud_refresh -= delta
	if _hud_refresh <= 0.0:
		_hud_refresh = 0.5
		_refresh_round_hud()


## نوارِ وسطِ بالا در بازیِ سریع: خودم در برابرِ حریف‌های زنده، تایمرِ مدتِ
## زنده ماندن، و زیرش تعدادِ کشته‌ها (همان «کشته»ی قبلی)
func _refresh_round_hud() -> void:
	if hud == null or hud.round_hud == null:
		return
	var foes := 0
	for b in _bots:
		if is_instance_valid(b) and not b.is_dead:
			foes += 1
	hud.round_hud.set_local(0 if $Player.is_dead else 1, foes, _alive_time,
		"کشته: %s" % MissionArt.fa_number(_kills))


## مینی‌مپ: بات‌ها حریف‌اند (همان قانونِ رادار رویشان اعمال می‌شود)
func _minimap_actors() -> Array:
	var out: Array = []
	for b in _bots:
		if is_instance_valid(b) and not b.is_dead:
			out.append({"pos": b.global_position, "ally": false})
	return out


## فاصله‌ی اسپاون و سقفِ حریف‌ها، بر اساس سطحِ انتخاب‌شده
func _pacing() -> Array:
	return PACING[clampi(Global.quick_play_difficulty, 0, PACING.size() - 1)]


## یک حریفِ تازه با کاراکترِ پیش‌فرض
func _spawn_bot() -> void:
	if _bots.size() >= _pacing()[1] or $Player.is_dead:
		return
	# تا سارا حرف می‌زند، زمینِ تمرین خالی می‌ماند
	if Tutorial.is_running():
		return
	var bot: Node2D = BOT_SCENE.instantiate()
	bot.set_script(BOT_SCRIPT)
	bot.apply_difficulty(Global.quick_play_difficulty)
	bot.global_position = _pick_spawn()
	add_child(bot)
	bot.target = $Player
	bot.setup_appearance(Global.DEFAULT_CHARACTER, "ak47")
	bot.died.connect(_on_bot_died)
	bot.hurt.connect(func(amount: int): _damage_dealt += amount)
	bot.tree_exiting.connect(_forget_bot.bind(bot))
	_bots.append(bot)


## بات از درخت بیرون رفت (مرد و آزاد شد، یا کلِ صحنه عوض شد)
func _forget_bot(bot: Node2D) -> void:
	_bots.erase(bot)


## نقطه‌ی تولد: از نقاطِ شروعِ همان نقشه‌ی سرور، دورترین‌شان از بازیکن
func _pick_spawn() -> Vector2:
	var arena: Node = get_node_or_null("Arena")
	var best: Vector2 = $Player.global_position + Vector2(MIN_SPAWN_DIST, 0)
	if arena != null and "spawn_points" in arena and not arena.spawn_points.is_empty():
		var far := -1.0
		for p in arena.spawn_points:
			var d: float = $Player.global_position.distance_to(p)
			if d > far:
				far = d
				best = p
	return best


func _on_bot_died(_bot) -> void:
	_kills += 1
	PSYCH_LOADOUT.record_kills(1)
	_refresh_round_hud()
	CombatFX.shake(4.0)


## بمبِ خودِ بازیکن. آنلاین `Network.send_bomb_request` می‌رفت و سرور بمب را
## می‌انداخت؛ آفلاین کسی آن را نمی‌شنید و دکمه بی‌اثر بود.
## موجودی هم همین‌جا کم می‌شود — سه بمب در کلِ بازی، مثلِ آنلاین.
func _throw_bomb(dir: Vector2, dist: float) -> void:
	if bombs_left <= 0:
		return
	_set_bombs_left(bombs_left - 1)
	var from: Vector2 = $Player.global_position
	spawn_local_bomb(from, from + dir * dist,
		float(my_stats.get("bomb_radius", 104.0)),
		int(my_stats.get("bomb_damage", 49)), $Player)


## حمله‌ی خودِ بازیکن (تیر یا لیزر) سپرِ دستی را می‌شکند — همان قانونِ سرور
## (dropSpawnShield). player.gd بعد از هر شلیک صدایش می‌زند.
func on_local_attack() -> void:
	if _now() < _guard_until:
		_guard_until = 0.0
		_dismiss_guard(str(Global.my_username))


## توانایی‌ها بدونِ سرور: همان عددهای abilities.go (Abilities.*) این‌جا اجرا
## می‌شوند و دکمه‌ها همان شمارش‌معکوسی را می‌گیرند که آنلاین از سرور می‌آید.
func _request_ability(kind: String) -> void:
	var me: String = str(Global.my_username)
	match kind:
		"sprint":
			hud.button(kind).run(Abilities.SPRINT_ACTIVE, Abilities.SPRINT_COOLDOWN)
			play_ability_fx(me, kind, Abilities.SPRINT_ACTIVE)
		"guard":
			_guard_until = _now() + Abilities.GUARD_ACTIVE
			hud.button(kind).run(Abilities.GUARD_ACTIVE, Abilities.GUARD_COOLDOWN)
			play_ability_fx(me, kind, Abilities.GUARD_ACTIVE)
		"laser":
			on_local_attack()
			hud.button(kind).run(Abilities.LASER_ACTIVE, Abilities.LASER_COOLDOWN)
			var beam = play_ability_fx(me, kind, Abilities.LASER_ACTIVE)
			if beam != null:
				beam.tick.connect(_laser_tick)
		"team_heal":
			# آفلاین هم‌تیمی‌ای نیست؛ فقط خودِ بازیکن در شعاع است
			var amount: int = int(my_stats.get("heal_amount", 25))
			var new_health: int = mini($Player.health + amount, max_health)
			var gained: int = new_health - $Player.health
			if gained <= 0:
				hud.button(kind).deny()
				return
			$Player.health = new_health
			update_player_health_ui(new_health, max_health)
			CombatFX.damage_number($Player.global_position, gained, true)
			hud.button(kind).run(0.0, Abilities.TEAM_HEAL_COOLDOWN)
			play_ability_fx(me, kind, 0.0)


## هر ضربه‌ی لیزر: هر باتی که بدنش پاره‌خطِ پرتو را قطع کند (تا دیوار)
func _laser_tick(from: Vector2, to: Vector2) -> void:
	var reach := Abilities.LASER_HALF_WIDTH + Abilities.PLAYER_RADIUS
	for b in _bots:
		if not is_instance_valid(b) or b.is_dead:
			continue
		if Abilities.segment_hits_circle(from, to, b.global_position, reach):
			b.take_damage(Abilities.laser_tick_damage(int(b.max_health)))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## انفجار و خسارتِ بمب محلی حساب می‌شود، همان‌طور که سرور آنلاین حساب
## می‌کرد: هرکس داخل شعاع باشد (خودِ پرتاب‌کننده هم) خسارت می‌خورد.
func spawn_local_bomb(from: Vector2, to: Vector2, radius: float, dmg: int, thrower: Node2D) -> void:
	_spawn_bomb_animation(from, to, radius)
	await get_tree().create_timer(BOMB_FUSE).timeout
	CombatFX.explosion(to, radius)
	CombatFX.shake(7.0)

	if not $Player.is_dead and $Player.global_position.distance_to(to) <= radius:
		_damage_local_player(dmg)
	for b in _bots:
		if is_instance_valid(b) and not b.is_dead and b.global_position.distance_to(to) <= radius:
			# بمبِ خودی هم به خودش می‌زند — همان قاعده‌ی سرور
			if b == thrower and b.global_position.distance_to(to) > radius * 0.5:
				continue
			b.take_damage(dmg)


## دکمه‌ی درمان. آنلاین این فقط یک درخواست به سرور می‌فرستد و سرور درمان
## می‌کند؛ آفلاین کسی آن درخواست را نمی‌شنود و دکمه بی‌اثر بود.
## همان قاعده‌های سرور اینجا تکرار می‌شوند: نه در حالت مرگ، نه با جانِ پر،
## نه قبل از تمام شدن کول‌داون — و مقدارش از تراز خودِ کاراکتر می‌آید.
func _on_heal_button_pressed() -> void:
	if $Player.is_dead or not hud.button("heal").is_ready():
		return
	if $Player.health >= max_health:
		hud.button("heal").deny()
		return
	var amount: int = int(my_stats.get("heal_amount", 25))
	var new_health: int = mini($Player.health + amount, max_health)
	var gained: int = new_health - $Player.health
	if gained <= 0:
		return

	$Player.health = new_health
	update_player_health_ui(new_health, max_health)
	_spawn_heal_effect($Player.global_position)
	CombatFX.damage_number($Player.global_position, gained, true)
	_on_heal_cooldown_started(Global.my_username,
		int(my_stats.get("heal_cooldown", 12.0)))


## بات به بازیکن شلیک کرده (bot.gd این را صدا می‌زند)
func take_damage(amount: int) -> void:
	_damage_local_player(amount)


func _damage_local_player(amount: int) -> void:
	if $Player.is_dead:
		return
	# سپرِ دستی: هیچ تیر و ترکشی رد نمی‌شود
	if _now() < _guard_until:
		return
	var new_health: int = maxi($Player.health - amount, 0)
	CombatFX.hit_burst($Player.global_position, Vector2(0, -1))
	CombatFX.damage_number($Player.global_position, amount)
	CombatFX.shake(6.0)
	$Player.health = new_health
	update_player_health_ui(new_health, max_health)
	if new_health <= 0:
		_on_local_death()


func _on_local_death() -> void:
	if $Player.has_method("die"):
		$Player.die()
	# صفحه‌ی پایان با همان آمار — بدون دکمه‌ی «ادامه»
	if _menu != null:
		_menu.open_game_over(_stats())

