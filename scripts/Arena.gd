extends Node2D
## سازنده‌ی موانع و دیوارهای زمین بازی.
##
## مستطیل‌های برخورد را از res://resources/arena_map.json می‌سازد — همان فایلی که
## سرور هم می‌خواند. پس چیزی که اینجا می‌بینی دقیقاً همان چیزی است که سرور
## اعتبارسنجی می‌کند و جایی برای اختلاف نیست.
##
## برخورد فقط برای «حسِ درست» حرکت و جلوگیری از رد شدن تیر از دیوار است.
## حرف آخر را همیشه سرور می‌زند (position_correction).
##
## گرافیکِ دیوار: دیوارها TileMap نیستند — مستطیل‌های نقشه‌اند با اندازه‌ها و
## مختصاتِ آزاد (سرور هم همین مستطیل‌ها را می‌خواند). پس «کاشی» اینجا ساخته
## می‌شود: هر مستطیلِ داخلی به خانه‌های تقریباً مربع (ضلع = ضخامتِ دیوار)
## تقسیم می‌شود و هر خانه یکی از سه بافتِ دیوارِ تمِ جاری را می‌گیرد،
## طوری که هیچ دو خانه‌ی هم‌مرز — حتی از دو دیوارِ به‌هم‌چسبیده —
## یکسان نباشند (assign_wall_variants). هر دیوار با یک اسپرایت و
## shaders/wall_tiles.gdshader کشیده می‌شود. دیوارهای دورِ زمین کشیده
## نمی‌شوند — بیرونِ کادرند و رویشان بک‌گراند نیست.
##
## تم: بک‌گراند، بافتِ دیوارها و بافتِ موانع از تمِ مسابقه می‌آیند (ThemeArt).
## سرور تم را از بالاترین رنکِ بازیکن‌ها انتخاب می‌کند و در مسابقه و پیامِ
## spawn می‌فرستد. موانع (کلیدِ obstacles در JSONِ نقشه) جدا از دیوارها و با
## بافتِ مانع کشیده می‌شوند؛ برخوردشان همان rects است.
##
## مشعل: روی هر «سرِ آزادِ» دیوار (find_wall_ends) — معمولاً دو طرفِ هر
## درگاه — یک secense/wall_torch.tscn با فازِ تصادفی می‌نشیند. چون از روی
## مستطیل‌های نقشه پیدا می‌شوند، هر نقشه‌ای که Arena بخواند خودش مشعل‌دار
## می‌شود.
##
## هاله‌ی شعله و مذاب از Glowِ WorldEnvironmentِ صحنه‌ی World می‌آید و
## برای رد شدنِ رنگ از ۱ لازم است viewport در حالتِ HDR 2D باشد؛ Arena تا
## وقتی در صحنه است آن را روشن نگه می‌دارد (hdr_glow) — ولی فقط در کیفیتِ
## زیاد. بافرِ RGBA16F و زنجیره‌ی blurِ Glow گران‌ترین هزینه‌ی GPU روی
## Mali/Adrenoهای ضعیف است، پس در کیفیتِ کم و متوسط:
##   • HDR خاموش و WorldEnvironment بی‌محیط می‌شود (هیچ پاسِ پس‌پردازشی).
##   • هر مشعل یک هاله‌ی افزودنیِ ارزان (اسپرایتِ Halo) جای Glow می‌گیرد.
##   • کانون‌های نورِ زمین به‌جای دو PointLight2D یک کوادِ افزودنی‌اند
##     (shaders/zone_halo.gdshader) که خودش کفِ زمین را «روشن» می‌کند.
##   • شیدرهای دیوار/در/شعله پرچمِ ldr_fix می‌گیرند تا رنگ‌هایی که برای فضای
##     خطیِ HDR تنظیم شده‌اند همان‌طور دیده شوند.
##   • نورِ واقعیِ مشعل‌ها: متوسط حداکثر TORCH_LIT_MEDIUM، کم هیچ (فقط شعله).
## با video_settings_changed همان لحظه عوض می‌شود.
##
## هر حالتِ بازی زمینِ خودش را دارد: «عملیات انتقام» روی زمینِ بازتر و
## ستون‌دارِ خودش، «عملیات حذف شیطان» روی زمینی که حیاطِ چهاردیواریِ وسط و
## راهروهای رو به مرکز دارد، و بقیه روی زمینِ پیش‌فرض. سرور می‌گوید کدام
## (پیامِ spawn → map)، پس کلاینت هیچ‌وقت زمینی غیر از زمینِ سرور نمی‌کشد.
##
## بازسازی نقشه‌ها:  python tools/build_arena.py

## نامِ نقشه -> فایل. باید با mapForMode در gun_game_server/arena.go یکی بماند.
const MAP_PATHS := {
	"map": "res://resources/arena_map.json",
	"revenge": "res://resources/arena_revenge.json",
	"banish": "res://resources/arena_banish.json",
}
const DEFAULT_MAP := "map"
const WALL_SHADER := preload("res://shaders/wall_tiles.gdshader")
const TORCH_SCENE := preload("res://secense/wall_torch.tscn")
const WIND_SCRIPT := preload("res://scripts/wind.gd")
const DOOR_SHADER := preload("res://shaders/door_glow.gdshader")
## بافتِ گردِ نور — همان که چراغِ بازیکن و افکت‌های شلیک هم استفاده می‌کنند
const LIGHT_TEX := preload("res://assets/lightall.png")
## جانشینِ ارزانِ کانون‌های نور در کیفیتِ کم/متوسط
const ZONE_HALO_SHADER := preload("res://shaders/zone_halo.gdshader")
## سقفِ مشعل‌هایی که در کیفیتِ متوسط نورِ واقعی (PointLight2D) دارند
const TORCH_LIT_MEDIUM := 8

## لایه ۱ = دیوار. بازیکن (mask 3)، حریف (mask 1) و تیر (mask 3) همگی می‌بینندش.
const WALL_LAYER := 1

## دیوار روی بک‌گراند می‌نشیند ولی زیرِ کاراکترها و تیرها. بک‌گراند z=0 است و
## بازیکن‌ها بالاتر؛ عددِ کوچکِ مثبت دیوار را بینِ این دو نگه می‌دارد.
const WALL_Z := 4
const DOOR_Z := 2   # آستانه‌ی در روی زمین است، پس زیرِ خودِ دیوار
## مانع روی حاشیه‌ی پهن‌شده‌ی دیوار می‌نشیند (موانعِ چسبیده به دیوار)، پس یک
## پله بالاتر از دیوار؛ مشعل (z=۶) باز هم رویش است.
const OBSTACLE_Z := 5
## حداقل فاصله‌ی دو مشعل (واحد جهانی). دو طرفِ تنگ‌ترین درگاه ~۱۲۰ از هم
## فاصله دارند و باید هر دو مشعل بگیرند؛ کمتر از این یعنی دو شعله روی هم.
const TORCH_MIN_GAP := 64.0
## چقدر بیرون از سرِ دیوار نگاه کنیم تا بفهمیم به دیوارِ دیگری چسبیده یا نه
const END_PROBE := 4.0
## دو خانه وقتی هم‌مرزند که روی ضلع بیش از این مقدار هم‌پوشانی داشته باشند —
## تماسِ فقط گوشه‌ای (قطری) همسایگی حساب نمی‌شود.
const ADJ_EPS := 0.5

## --- مشعل‌ها ---
## روی سرهای آزادِ دیوارها مشعل گذاشته شود؟
@export var show_torches := true
## سقفِ تعدادِ مشعل در هر نقشه. هر مشعل یک PointLight2D دارد و روی رندررِ
## gl_compatibility هر نور آیتم‌های زیرش را یک بارِ دیگر می‌کشد.
@export_range(0, 60) var max_torches := 24
## HDR 2D تا وقتی زمین در صحنه است. بدونِ آن رنگ‌ها در ۱ بریده می‌شوند و
## Glowِ WorldEnvironment روی شعله و مذاب هاله نمی‌سازد.
@export var hdr_glow := true

## --- باد ---
## بادِ دوره‌ای و برگ‌هایی که می‌آورد (scripts/wind.gd). روی هر سه نقشه.
@export var show_wind := true

## دیوار روی صفحه از هر طرفِ ضخامتش این‌قدر پهن‌تر از برخوردش کشیده می‌شود.
## دیوارهای نقشه ۲۴ واحدند و با بافتِ تیره در زمینِ تاریک گم می‌شدند.
## فقط ظاهر است: برخورد و فایلِ نقشه (که سرور هم می‌خواند) دست نمی‌خورند.
## فقط در عرض پهن می‌شود نه در طول، تا دهانه‌ی درها تنگ‌تر به‌نظر نرسد.
@export_range(0.0, 16.0) var wall_visual_pad := 6.0
## کفِ درگاه‌ها روشن شود؟ خوانایی نقشه را زیاد می‌کند.
@export var show_door_glow := true
## عمقِ نوارِ نورِ آستانه (واحد جهانی)
@export_range(8.0, 80.0) var door_glow_depth := 34.0

## --- کانون‌های نورِ زمین ---
## رنگِ لکه‌های روشن. کهربایی‌ست تا با آهنِ سردِ دیوارها تضاد داشته باشد.
@export var zone_light_color := Color(1.0, 0.82, 0.55)
@export_range(0.0, 6.0) var zone_light_energy := 3.1
## هاله‌ی دومِ هر کانون: چند برابرِ مغز، و چقدر کم‌جان‌تر
@export_range(1.0, 3.0) var halo_scale := 1.9
@export_range(0.0, 1.0) var halo_energy := 0.42
## --- تاریکیِ محیط ---
## چرا اینجا و نه CanvasModulate: روی رندررِ gl_compatibility — همانی که این
## پروژه روی اندروید هم با آن اجرا می‌شود — CanvasModulate هیچ اثری ندارد.
## اندازه‌گیری شد: با رنگِ کاملاً سیاه هم میانگینِ روشناییِ قابِ بازی از ۷۰
## تکان نخورد. پس تاریکی مستقیم روی خودِ آیتم‌ها اعمال می‌شود. نورها بعد از
## این روی همین رنگِ تاریک جمع می‌شوند، پس لکه‌های روشن سرِ جایشان می‌مانند.
@export var ambient_tint := Color(0.115, 0.11, 0.155)
## کاراکترها کمی روشن‌تر از کف می‌مانند، وگرنه در تاریکی کاملاً گم می‌شوند و
## حتی داخلِ کانونِ نور هم به‌سختی خوانده می‌شوند.
@export var actor_tint := Color(0.46, 0.45, 0.52)

## برای دیباگ: مستطیل‌های برخورد را روی صفحه بکش
@export var debug_draw := false

var world_size := Vector2(2000, 1120)
var spawn_points: Array[Vector2] = []
## نقشه‌ای که همین حالا کشیده شده. خالی یعنی هنوز چیزی ساخته نشده.
var map_name := ""
## تمِ ظاهریِ همین حالا (شناسه‌های ThemeArt)
var theme := ""

var _rects: Array[Rect2] = []          # همه‌ی مستطیل‌ها، شاملِ مرزِ زمین
var _doors: Array[Dictionary] = []
var _walls_root: Node2D = null
var _doors_root: Node2D = null
var _torch_root: Node2D = null
var _obstacles_root: Node2D = null
var _wind: Node2D = null
var _prev_hdr := false
## Arena خودش HDR را دست زده؟ (فقط آن وقت موقعِ خروج برمی‌گرداند)
var _hdr_touched := false
## محیطِ اصلیِ WorldEnvironment — در کیفیتِ کم/متوسط از نود برداشته می‌شود
var _env: Environment = null
## پله‌ی کیفیتی که الان اعمال شده (-۱ = هنوز هیچ)
var _applied_level := -1
## همه‌ی مشعل‌ها و آن‌هایی که نورِ واقعی دارند (نوع‌نداشته: متدهای wall_torch.gd)
var _torches: Array = []
var _lit_torches: Array = []
## متریال‌هایی که پرچمِ ldr_fix می‌گیرند (دیوار، مانع، در، شعله‌ی مشعل)
var _ldr_mats: Array[ShaderMaterial] = []
## کانون‌های نورِ نقشه — برای ساختنِ دوباره وقتی کیفیت عوض می‌شود
var _zones: Array = []
var _zone_root: Node2D = null
var _zone_halos := false
## بافتِ سفیدِ یک‌پیکسلی، مشترک بینِ دیوار، مانع و در
var _unit_tex: Texture2D = null
## بافت‌های تمِ جاری — یک بار موقعِ ساختنِ نقشه خوانده می‌شوند
var _wall_tex: Array[Texture2D] = []
var _obstacle_tex: Array[Texture2D] = []


func _enter_tree() -> void:
	# فقط برای مدتِ بازی: منوها با HDR 2D تست نشده‌اند و در این حالت رنگِ
	# ثابتِ داخلِ شیدرها خطی تفسیر می‌شود.
	if hdr_glow:
		_prev_hdr = get_viewport().use_hdr_2d
	_apply_render_quality()


func _exit_tree() -> void:
	if _hdr_touched:
		get_viewport().use_hdr_2d = _prev_hdr
		_hdr_touched = false


func _ready() -> void:
	if not LocalSettings.video_settings_changed.is_connected(_on_video_settings_changed):
		LocalSettings.video_settings_changed.connect(_on_video_settings_changed)
	# تا وقتی سرور نگفته، از روی حالتِ انتخاب‌شده حدس می‌زنیم — همان حالتی
	# که ماچ‌میکینگ با آن مسابقه جور کرده. تم هم از خودِ مسابقه (که
	# ماچ‌میکینگ داده) و در نبودش از رنکِ خودِ بازیکن. پیامِ spawn سرور
	# بلافاصله بعدش می‌رسد و اگر فرق داشت، load_map دوباره می‌سازد.
	var t := str(Global.current_match.get("theme", ""))
	if t == "":
		t = ThemeArt.theme_for_rank(Global.rank_id)
	load_map(map_for_mode(str(Global.selected_mode)), t)


## نامِ نقشه‌ی یک حالت (نسخه‌ی کلاینتیِ MapNameForMode در سرور)
static func map_for_mode(mode_id: String) -> String:
	return mode_id if MAP_PATHS.has(mode_id) else DEFAULT_MAP


## نقشه را با یک تم می‌سازد. اگر نقشه یا تمِ دیگری کشیده شده باشد اول پاک
## می‌شود، پس می‌شود وسطِ اجرا زمین را عوض کرد (وقتی سرور چیزِ دیگری اعلام
## می‌کند). themeِ خالی یعنی همان تمِ فعلی بماند.
func load_map(name: String, theme_id := "") -> void:
	if not MAP_PATHS.has(name):
		name = DEFAULT_MAP
	var t := ThemeArt.sanitize(theme_id if theme_id != "" else theme)
	if name == map_name and t == theme:
		return

	_clear_map()
	map_name = name
	theme = t
	_wall_tex = ThemeArt.walls(theme)
	_obstacle_tex = ThemeArt.obstacles(theme)

	var data := _load_map(MAP_PATHS[name])
	if data.is_empty():
		push_error("Arena: نقشه بارگذاری نشد — بازیکن از دیوارها رد خواهد شد!")
		return

	var w: Dictionary = data.get("world", {})
	world_size = Vector2(w.get("width", 2000), w.get("height", 1120))

	for p in data.get("spawns", []):
		if p is Array and p.size() == 2:
			spawn_points.append(Vector2(p[0], p[1]))

	var rects: Array = data.get("rects", [])
	var obstacles: Array = data.get("obstacles", [])
	_build_bodies(rects)
	_build_wall_art(rects, obstacles)
	_build_obstacle_art(obstacles)
	if show_torches:
		_build_torches()

	for d in data.get("doors", []):
		if d is Dictionary:
			_doors.append(d)
	if show_door_glow:
		_build_door_glow()

	_apply_background()
	_darken_world()
	# بعد از بک‌گراند: هاله‌ی کانون‌ها بافت و تاریکیِ کف را از آن می‌خواند.
	# ترتیبِ بچه‌ها همان قبلی می‌ماند (ZoneLights قبل از Wind).
	_build_zone_lights(data.get("lights", []))
	if show_wind:
		_build_wind()
	_applied_level = -1
	_apply_scene_quality()

	queue_redraw()
	print("🗺️ Arena «%s» تم «%s»: %d مستطیل (%d مانع)، %d در، %d نقطه‌ی شروع، اندازه %s"
		% [map_name, theme, _rects.size(), obstacles.size(), _doors.size(),
			spawn_points.size(), world_size])


## هرچه از نقشه‌ی قبلی ساخته شده بود می‌رود: دیوارها، آرت، درها، نورها.
func _clear_map() -> void:
	for child in get_children():
		# اول جدا، بعد آزاد: queue_free تا آخرِ فریم صبر می‌کند و تا آن
		# موقع نودهای تازه با همان نام‌ها ساخته می‌شوند (Walls2, WallArt2 ...)
		remove_child(child)
		child.queue_free()
	_rects.clear()
	_doors.clear()
	spawn_points.clear()
	_walls_root = null
	_doors_root = null
	_torch_root = null
	_obstacles_root = null
	_wind = null
	_torches.clear()
	_lit_torches.clear()
	_ldr_mats.clear()
	_zones.clear()
	_zone_root = null
	set_process(false)


## نقشه را می‌خواند. اول از راه Resource (در بیلد اکسپورت‌شده هم کار می‌کند)
## و اگر نشد مستقیم از فایل.
func _load_map(path: String) -> Dictionary:
	if ResourceLoader.exists(path):
		var res: Variant = load(path)
		if res is JSON and typeof(res.data) == TYPE_DICTIONARY:
			return res.data

	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				return parsed

	push_error("Arena: نقشه خوانده نشد: " + path + "  (اجرا کن: python tools/build_arena.py)")
	return {}


func _rect_from(r: Variant) -> Rect2:
	if not (r is Array) or r.size() != 4:
		return Rect2()
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


# ============================ برخورد ============================

## همه‌ی مستطیل‌ها زیر یک StaticBody2D می‌روند — از ده‌ها نود جدا خیلی سبک‌تر است.
func _build_bodies(rects: Array) -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"
	body.collision_layer = WALL_LAYER
	body.collision_mask = 0  # دیوار دنبال چیزی نمی‌گردد، فقط دیده می‌شود
	add_child(body)

	for r in rects:
		var rect := _rect_from(r)
		if rect.size == Vector2.ZERO:
			continue
		_rects.append(rect)

		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = rect.position + rect.size * 0.5
		body.add_child(cs)


# ============================ گرافیکِ دیوار ============================

## دیوارها را خانه‌بندی می‌کند، به هر خانه بافت می‌دهد و هر دیوار را با یک
## اسپرایت می‌کشد. فقط دیوارهای داخلِ زمین؛ چهار دیوارِ مرزی بیرونِ کادرند.
func _build_wall_art(rects: Array, obstacles: Array) -> void:
	_walls_root = Node2D.new()
	_walls_root.name = "WallArt"
	_walls_root.z_index = WALL_Z
	add_child(_walls_root)

	# ۱. خانه‌بندیِ همه‌ی دیوارها در یک فهرستِ سراسری. ترتیب: دیوار به دیوار،
	#    داخلِ هر دیوار ردیف به ردیف (x سریع‌تر) — همان ترتیبِ variant_map.
	var walls: Array[Rect2] = []
	var grids: Array[Vector2] = []
	var first_cell: Array[int] = []
	var cell_rects: Array[Rect2] = []
	var cell_wall := PackedInt32Array()   # هر خانه مالِ کدام دیوار (= ترتیبِ رسم)
	# موانع هم داخلِ rects اند (برای برخورد) ولی جدا کشیده می‌شوند
	var skip := {}
	for o in obstacles:
		skip[_rect_from(o)] = true
	for r in rects:
		var rect := _rect_from(r)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not _is_interior(rect):
			continue
		if skip.has(rect):
			continue
		rect = _visual_rect(rect)
		var cells := wall_cells(rect.size)
		var cs := rect.size / cells
		walls.append(rect)
		grids.append(cells)
		first_cell.append(cell_rects.size())
		for y in int(cells.y):
			for x in int(cells.x):
				cell_rects.append(Rect2(rect.position + Vector2(x, y) * cs, cs))
				cell_wall.append(walls.size() - 1)

	# ۲. انتخابِ بافت، سراسری: خانه‌های دو دیوارِ به‌هم‌چسبیده هم همسایه‌اند.
	#    بذر از نامِ نقشه، تا هر بار همان نقشه همان‌طور کاشی شود.
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash(map_name + ":walls"))
	var adj := _cell_adjacency(cell_rects, cell_wall, walls)
	var variants := assign_wall_variants(adj, maxi(_wall_tex.size(), 1), rng)

	# ۳. یک اسپرایت برای هر دیوار
	var tex := _unit_texture()
	for i in walls.size():
		_walls_root.add_child(_wall_sprite(walls[i], grids[i], variants, first_cell[i], tex))

	print("🧱 Arena: %d دیوار، %d خانه، %d تداخلِ همسایه"
		% [walls.size(), cell_rects.size(), count_variant_conflicts(adj, variants)])


## مستطیلِ رسمِ دیوار: در جهتِ ضخامت wall_visual_pad از هر طرف پهن‌تر.
## ستون‌ها (نه کشیده) از هر چهار طرف پهن می‌شوند.
func _visual_rect(rect: Rect2) -> Rect2:
	var pad := wall_visual_pad
	if rect.size.y >= rect.size.x * 1.5:        # عمودی — پهن در x
		return rect.grow_individual(pad, 0.0, pad, 0.0)
	if rect.size.x >= rect.size.y * 1.5:        # افقی — پهن در y
		return rect.grow_individual(0.0, pad, 0.0, pad)
	return rect.grow(pad)


## آیا این مستطیل داخلِ زمین است؟ دیوارهای مرزی مختصاتِ منفی دارند یا از
## لبه‌ی زمین بیرون می‌زنند.
func _is_interior(rect: Rect2) -> bool:
	return rect.position.x >= 0.0 and rect.position.y >= 0.0 \
		and rect.end.x <= world_size.x and rect.end.y <= world_size.y


func _wall_sprite(rect: Rect2, cells: Vector2, variants: PackedInt32Array,
		first: int, tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = rect.position
	# بافت ۱×۱ است، پس scale برابرِ اندازه‌ی دیوار می‌شود و UV همیشه ۰..۱
	s.scale = rect.size

	# نقشه‌ی بافتِ این دیوار: یک پیکسل برای هر خانه، مقدار = شماره‌ی بافت
	var cx := int(cells.x)
	var cy := int(cells.y)
	var img := Image.create(cx, cy, false, Image.FORMAT_R8)
	for y in cy:
		for x in cx:
			img.set_pixel(x, y, Color(float(variants[first + y * cx + x]) / 255.0, 0.0, 0.0))

	var mat := ShaderMaterial.new()
	mat.shader = WALL_SHADER
	_set_variant_textures(mat, _wall_tex)
	mat.set_shader_parameter("variant_map", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("cells", cells)
	mat.set_shader_parameter("lava_boost", ThemeArt.lava_glow(theme))
	s.material = mat
	_ldr_mats.append(mat)
	return s


## دیوار به چند خانه تقسیم شود؟ ضلعِ خانه = ضخامتِ دیوار، پس خانه‌ها تقریباً
## مربع‌اند و بافتِ مربعی کش نمی‌آید: دیوارِ ۲۴×۴۲۴ می‌شود ۱۸ خانه و ستونِ
## ۱۱۲×۸۸ یک خانه.
static func wall_cells(size: Vector2) -> Vector2:
	var block := maxf(minf(size.x, size.y), 1.0)
	return Vector2(
		maxf(roundf(size.x / block), 1.0),
		maxf(roundf(size.y / block), 1.0))


## بافتِ یک‌پیکسلیِ سفید، مشترک بینِ همه‌ی دیوارها، موانع و درها.
func _unit_texture() -> Texture2D:
	if _unit_tex == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_unit_tex = ImageTexture.create_from_image(img)
	return _unit_tex


## سه بافت را به variant_0..2 شیدر می‌دهد. اگر تم کمتر از سه فایل داشت، جای
## خالی با اولی پر می‌شود — شیدر هیچ‌وقت نمونه‌ی خالی نمی‌خواند.
func _set_variant_textures(mat: ShaderMaterial, texs: Array[Texture2D]) -> void:
	for v in 3:
		var t: Texture2D = texs[v] if v < texs.size() else (texs[0] if not texs.is_empty() else null)
		mat.set_shader_parameter("variant_%d" % v, t)


# ============================ موانع ============================

## هر مانع یک اسپرایت با یکی از سه بافتِ مانعِ تم، به‌تصادف. همان شیدرِ دیوار
## (یک خانه‌ی تک) تا تاریکی، نورِ چراغ‌ها و درخششِ مذاب با دیوارها یکی باشد.
##
## مانع‌هایی که بافتِ یکسان گرفته‌اند یک متریالِ مشترک دارند (حداکثر سه
## متریال برای کلِ نقشه به‌جای یکی برای هر مانع) تا با هم batch شوند. ظاهر
## عیناً همان است: variant_mapِ یک‌خانه‌ای فقط شماره‌ی بافت را نگه می‌دارد.
func _build_obstacle_art(obstacles: Array) -> void:
	if obstacles.is_empty():
		return
	_obstacles_root = Node2D.new()
	_obstacles_root.name = "ObstacleArt"
	_obstacles_root.z_index = OBSTACLE_Z
	add_child(_obstacles_root)

	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash(map_name + ":" + theme + ":obstacles"))
	var tex := _unit_texture()
	var count := maxi(_obstacle_tex.size(), 1)
	var mats: Array[ShaderMaterial] = []
	for v in count:
		var img := Image.create(1, 1, false, Image.FORMAT_R8)
		img.set_pixel(0, 0, Color(float(v) / 255.0, 0.0, 0.0))
		var mat := ShaderMaterial.new()
		mat.shader = WALL_SHADER
		_set_variant_textures(mat, _obstacle_tex)
		mat.set_shader_parameter("variant_map", ImageTexture.create_from_image(img))
		mat.set_shader_parameter("cells", Vector2.ONE)
		mat.set_shader_parameter("lava_boost", ThemeArt.lava_glow(theme))
		mats.append(mat)
		_ldr_mats.append(mat)
	for o in obstacles:
		var rect := _rect_from(o)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.position = rect.position
		s.scale = rect.size
		# همان دنباله‌ی تصادفیِ قبلی، پس هر مانع همان بافتِ همیشگی را می‌گیرد
		s.material = mats[rng.randi_range(0, count - 1)]
		_obstacles_root.add_child(s)


## بک‌گراندِ زمین (اسپرایتِ کفِ صحنه‌ی World) با بک‌گراندِ تم عوض می‌شود.
## اندازه‌ی همه‌ی بک‌گراندها ۲۸۴۸×۱۶۰۰ است، پس scaleِ اسپرایت دست نمی‌خورد.
## بادِ زمین. بعد از _darken_world ساخته می‌شود چون رنگِ برگ‌ها را از
## همان تاریکیِ محیط می‌گیرد، و بعد از نقشه چون اندازه‌ی زمین را می‌خواهد.
## چون بچه‌ی Arena است، با هر load_map از نو ساخته می‌شود و تمِ تازه را
## می‌گیرد؛ _clear_map هم خودش پاکش می‌کند.
func _build_wind() -> void:
	var w: Node2D = WIND_SCRIPT.new()
	w.name = "Wind"
	w.world_size = world_size
	w.theme = theme
	# برگ‌ها مثلِ کاراکترها روشن‌اند نه مثلِ کفِ زمین، وگرنه در تاریکی گم می‌شوند
	w.tint = actor_tint
	# همه‌ی بازیکن‌های یک مسابقه یک الگوی باد ببینند
	w.seed_text = str(Global.current_match.get("match_id", "")) + map_name
	add_child(w)
	_wind = w


func _apply_background() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var bg := ThemeArt.background(theme)
	if bg == null:
		return
	for child in parent.get_children():
		if child is Sprite2D:
			(child as Sprite2D).texture = bg
			return


# ============================ انتخابِ بافت ============================

## به هر خانه یکی از count بافت را می‌دهد (وزنِ برابر)، طوری که هیچ دو خانه‌ی
## هم‌مرز (بالا/پایین/چپ/راست) یکسان نباشند.
##
## adj خروجیِ _cell_adjacency است: فقط تماس‌هایی که روی صفحه دیده می‌شوند.
##
## روش: رنگ‌آمیزیِ حریصانه با انتخابِ تصادفیِ یکنواخت بینِ بافت‌های مجاز،
## به ترتیبِ «پرهمسایه‌ترین اول». در یک دیوارِ ساده هر خانه حداکثر دو همسایه
## دارد و با سه بافت همیشه جواب هست؛ فقط سرِ تقاطع‌ها ممکن است همسایه‌ها هر
## سه را گرفته باشند. برای آن‌ها چند دورِ ترمیم و در صورتِ نیاز چند تلاش با
## ترتیبِ دیگر؛ کم‌تداخل‌ترین نتیجه برمی‌گردد.
static func assign_wall_variants(adj: Array, count: int,
		rng: RandomNumberGenerator) -> PackedInt32Array:
	var best := PackedInt32Array()
	var best_conf := -1
	for attempt in 8:
		var res := _color_cells(adj, count, rng)
		var conf := count_variant_conflicts(adj, res)
		if best_conf < 0 or conf < best_conf:
			best = res
			best_conf = conf
		if conf == 0:
			break
	return best


## تعدادِ جفت‌خانه‌های هم‌مرزی که بافتِ یکسان گرفته‌اند (باید ۰ باشد).
static func count_variant_conflicts(adj: Array, variants: PackedInt32Array) -> int:
	var n := 0
	for i in adj.size():
		for j in adj[i]:
			if j > i and variants[i] == variants[j]:
				n += 1
	return n


## فهرستِ همسایه‌های هر خانه — فقط تماس‌هایی که روی صفحه دیده می‌شوند.
##
## «هم‌مرز» یعنی دو مستطیل یک ضلعِ مشترک دارند یا سرِ تقاطعِ دو دیوار روی هم
## افتاده‌اند. تماسِ فقط گوشه‌ای حساب نمی‌شود — همان چهار همسایه‌ی TileMap.
##
## تماسی که زیرِ دیوارِ دیگری پنهان است حساب نمی‌شود. سرِ هر چهارراهِ نقشه
## (دیوارِ عمودی که از وسطِ دیوارِ افقی رد می‌شود) خانه‌های بالا و پایین فقط
## روی خطی به هم می‌رسند که دیوارِ افقیِ رویی کاملاً پوشانده؛ اگر آن را هم
## همسایه بگیریم چهار خانه‌ی دورِ تقاطع همه با هم همسایه می‌شوند و با سه بافت
## جوابی وجود ندارد. روی صفحه آن دو هرگز کنارِ هم دیده نمی‌شوند.
##
## برای اینکه روی موبایل n² مقایسه نشود، خانه‌ها اول در سطل‌های ۶۴تایی ریخته
## می‌شوند و فقط هم‌سطل‌ها با هم مقایسه می‌شوند.
static func _cell_adjacency(cells: Array[Rect2], cell_wall: PackedInt32Array,
		walls: Array[Rect2]) -> Array:
	const BUCKET := 64.0
	var adj: Array = []
	adj.resize(cells.size())
	for i in cells.size():
		adj[i] = []

	var grid := {}
	for i in cells.size():
		var r := cells[i].grow(ADJ_EPS)
		for by in range(floori(r.position.y / BUCKET), floori(r.end.y / BUCKET) + 1):
			for bx in range(floori(r.position.x / BUCKET), floori(r.end.x / BUCKET) + 1):
				var key := Vector2i(bx, by)
				if not grid.has(key):
					grid[key] = []
				grid[key].append(i)

	for key in grid:
		var ids: Array = grid[key]
		for a in ids.size():
			for b in range(a + 1, ids.size()):
				var i: int = ids[a]
				var j: int = ids[b]
				# دو خانه‌ی بزرگ ممکن است در چند سطل با هم باشند
				if adj[i].has(j):
					continue
				var contact := _contact(cells[i], cells[j])
				if contact.size.x < 0.0:
					continue
				# دیوارِ بعدی روی دیوارِ قبلی کشیده می‌شود
				if _contact_hidden(contact, walls, maxi(cell_wall[i], cell_wall[j])):
					continue
				adj[i].append(j)
				adj[j].append(i)
	return adj


## ناحیه‌ی تماسِ دو خانه: ضلعِ مشترک (مستطیلِ بی‌ضخامت) یا ناحیه‌ی هم‌پوشانی.
## اگر تماسی نیست یا فقط گوشه‌ای است، اندازه‌ی منفی برمی‌گردد.
static func _contact(a: Rect2, b: Rect2) -> Rect2:
	var x0 := maxf(a.position.x, b.position.x)
	var y0 := maxf(a.position.y, b.position.y)
	var ox := minf(a.end.x, b.end.x) - x0
	var oy := minf(a.end.y, b.end.y) - y0
	if (ox > ADJ_EPS and oy > -ADJ_EPS) or (oy > ADJ_EPS and ox > -ADJ_EPS):
		return Rect2(x0, y0, maxf(ox, 0.0), maxf(oy, 0.0))
	return Rect2(0, 0, -1, -1)


## آیا ناحیه‌ی تماس کاملاً زیرِ دیوارهایی است که بعد از هر دو خانه کشیده
## می‌شوند؟ پوشش ممکن است کارِ اجتماعِ چند دیوار باشد (سرِ چهارراه دو دیوارِ
## افقیِ پشتِ هم)، پس ناحیه روی لبه‌های آن دیوارها برش می‌خورد و مرکزِ هر
## تکه جدا آزموده می‌شود — دقیق، و چون ناحیه‌ها کوچک‌اند فقط چند نقطه.
static func _contact_hidden(contact: Rect2, walls: Array[Rect2], above: int) -> bool:
	var probe := contact.grow(0.01)
	var cover: Array[Rect2] = []
	for k in range(above + 1, walls.size()):
		if walls[k].intersects(probe, true):
			cover.append(walls[k].grow(0.01))
	if cover.is_empty():
		return false
	for x in _cut_centres(contact.position.x, contact.end.x, cover, true):
		for y in _cut_centres(contact.position.y, contact.end.y, cover, false):
			var hit := false
			for w in cover:
				if w.has_point(Vector2(x, y)):
					hit = true
					break
			if not hit:
				return false
	return true


## بازه‌ی [a0, a1] روی لبه‌های دیوارهای پوشاننده برش می‌خورد؛ مرکزِ هر تکه.
## بازه‌ی بی‌طول (ضلعِ مشترک) همان یک نقطه است.
static func _cut_centres(a0: float, a1: float, cover: Array[Rect2], on_x: bool) -> Array[float]:
	if a1 - a0 < 0.01:
		return [a0]
	var cuts: Array[float] = [a0, a1]
	for w in cover:
		for v in ([w.position.x, w.end.x] if on_x else [w.position.y, w.end.y]):
			if v > a0 and v < a1:
				cuts.append(v)
	cuts.sort()
	var out: Array[float] = []
	for k in cuts.size() - 1:
		if cuts[k + 1] - cuts[k] > 0.001:
			out.append((cuts[k] + cuts[k + 1]) * 0.5)
	return out


static func _color_cells(adj: Array, count: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var n := adj.size()
	var res := PackedInt32Array()
	res.resize(n)
	res.fill(-1)

	# ترتیب: بُر خوردن برای تصادفی بودن، بعد پرهمسایه‌ها جلو — مقیدترین
	# خانه‌ها وقتی انتخاب می‌کنند که هنوز بیشترِ همسایه‌هایشان خالی‌اند
	var order: Array[int] = []
	for i in n:
		order.append(i)
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := order[i]
		order[i] = order[j]
		order[j] = tmp
	order.sort_custom(func(a: int, b: int) -> bool: return adj[a].size() > adj[b].size())

	for i in order:
		res[i] = _pick_variant(i, adj, res, count, rng)

	# ترمیم: حالا که همه انتخاب کرده‌اند، خانه‌ی متداخل با اطلاعِ کامل از همه‌ی
	# همسایه‌ها دوباره انتخاب می‌کند
	for pass_i in 4:
		var changed := false
		for i in n:
			var clash := false
			for j in adj[i]:
				if res[j] == res[i]:
					clash = true
					break
			if clash:
				var v := _pick_variant(i, adj, res, count, rng)
				if v != res[i]:
					res[i] = v
					changed = true
		if not changed:
			break
	return res


## بافتی که هیچ همسایه‌ای ندارد، به‌تصادف و یکنواخت. اگر همه گرفته شده‌اند،
## کم‌استفاده‌ترین بینِ همسایه‌ها.
static func _pick_variant(i: int, adj: Array, res: PackedInt32Array, count: int,
		rng: RandomNumberGenerator) -> int:
	var used := PackedInt32Array()
	used.resize(count)
	used.fill(0)
	for j in adj[i]:
		if res[j] >= 0:
			used[res[j]] += 1
	var free: Array[int] = []
	for v in count:
		if used[v] == 0:
			free.append(v)
	if not free.is_empty():
		return free[rng.randi_range(0, free.size() - 1)]
	var best := 0
	for v in count:
		if used[v] < used[best]:
			best = v
	return best


# ============================ مشعل‌ها ============================

## سرهای آزادِ دیوارها — جایی که یک دیوارِ کشیده تمام می‌شود و به دیوارِ
## دیگری نمی‌رسد (معمولاً لبه‌ی یک درگاه). خروجی: مرکزِ خانه‌ی آخرِ دیوار.
##
## • فقط دیوارهای کشیده (نسبتِ ≥ ۱.۵) سر دارند؛ ستون‌ها رد می‌شوند.
## • اگر کمی بیرون از سرِ دیوار داخلِ مستطیلِ دیگری باشد — دیوارِ متقاطع،
##   ادامه‌ی همان دیوار، یا مرزِ زمین — آنجا تقاطع است نه سر.
func find_wall_ends() -> Array[Vector2]:
	var ends: Array[Vector2] = []
	for rect in _rects:
		if not _is_interior(rect):
			continue
		var thin := minf(rect.size.x, rect.size.y)
		var c := rect.get_center()
		var cand: Array = []
		if rect.size.x >= rect.size.y * 1.5:
			cand = [[Vector2(rect.position.x, c.y), Vector2.LEFT],
				[Vector2(rect.end.x, c.y), Vector2.RIGHT]]
		elif rect.size.y >= rect.size.x * 1.5:
			cand = [[Vector2(c.x, rect.position.y), Vector2.UP],
				[Vector2(c.x, rect.end.y), Vector2.DOWN]]
		for e in cand:
			var edge: Vector2 = e[0]
			var out: Vector2 = e[1]
			if _blocked_by_other(edge + out * END_PROBE, rect):
				continue
			# مرکزِ خانه‌ی آخر؛ خانه‌ها به اندازه‌ی ضخامتِ «دیده‌شده» مربع‌اند
			ends.append(edge - out * (thin + wall_visual_pad * 2.0) * 0.5)
	return ends


func _blocked_by_other(point: Vector2, own: Rect2) -> bool:
	for r in _rects:
		if r != own and r.has_point(point):
			return true
	return false


## یک مشعل روی هر سرِ آزاد، هرکدام با فازِ تصادفیِ خودش.
func _build_torches() -> void:
	_torch_root = Node2D.new()
	_torch_root.name = "Torches"
	add_child(_torch_root)

	var rng := RandomNumberGenerator.new()
	rng.seed = abs(hash(map_name + ":torches"))

	# بُر خوردن فقط برای وقتی است که سقفِ تعداد برسد: بدونِ آن سهمیه را
	# دیوارهای اولِ فهرست پُر می‌کنند و نیمه‌ی دیگرِ زمین تاریک می‌ماند.
	var ends := find_wall_ends()
	for i in range(ends.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := ends[i]
		ends[i] = ends[j]
		ends[j] = tmp

	var placed: Array[Vector2] = []
	for pos in ends:
		if placed.size() >= max_torches:
			break
		if _crowded(placed, pos):
			continue
		placed.append(pos)
		var torch: Node2D = TORCH_SCENE.instantiate()
		torch.position = pos
		torch.time_offset = rng.randf() * 100.0
		_torch_root.add_child(torch)
		_torches.append(torch)

	# متریالِ شعله بینِ همه‌ی مشعل‌ها مشترک است — یک بار کافی است
	if not _torches.is_empty():
		var flame := (_torches[0] as Node).get_node_or_null("Flame") as CanvasItem
		if flame != null and flame.material is ShaderMaterial:
			_ldr_mats.append(flame.material as ShaderMaterial)

	print("🔥 Arena: %d مشعل روی %d سرِ دیوار" % [placed.size(), ends.size()])


func _crowded(placed: Array[Vector2], pos: Vector2) -> bool:
	for p in placed:
		if p.distance_to(pos) < TORCH_MIN_GAP:
			return true
	return false


# ============================ آستانه‌ی درها ============================

## نوارِ نورِ کفِ هر درگاه. درِ بزرگ پرنورتر از درِ تنگ در می‌آید.
##
## همه‌ی درها یک متریالِ مشترک دارند تا با هم batch شوند: وزنِ عرضِ در
## (همان mix(0.55, 1.0, scale_hint)ِ قبلی) در آلفای self_modulate می‌رود و
## فازِ نبض را شیدر از جای در درمی‌آورد.
func _build_door_glow() -> void:
	if _doors.is_empty():
		return
	_doors_root = Node2D.new()
	_doors_root.name = "DoorGlow"
	_doors_root.z_index = DOOR_Z
	add_child(_doors_root)

	var widest := 1.0
	for d in _doors:
		widest = max(widest, float(d.get("width", 0)))

	var tex := _unit_texture()
	# blend افزودنی و unshaded بودن داخلِ خودِ شیدر با render_mode ست شده —
	# یک نود فقط یک material می‌گیرد، پس CanvasItemMaterial کنارِ
	# ShaderMaterial جا نمی‌شود.
	var mat := ShaderMaterial.new()
	mat.shader = DOOR_SHADER
	_ldr_mats.append(mat)
	for d in _doors:
		var rect := _door_rect(d)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.position = rect.position
		s.scale = rect.size
		var hint := clampf(float(d.get("width", 0)) / widest, 0.0, 1.0)
		s.self_modulate = Color(1.0, 1.0, 1.0, lerpf(0.55, 1.0, hint))
		s.material = mat
		_doors_root.add_child(s)


## مستطیلِ آستانه: روی محورِ در پهن، عمودش نازک.
func _door_rect(d: Dictionary) -> Rect2:
	var depth := door_glow_depth
	if str(d.get("axis", "")) == "v":
		var x := float(d.get("x", 0))
		var y0 := float(d.get("y0", 0))
		var y1 := float(d.get("y1", 0))
		return Rect2(x - depth * 0.5, y0, depth, y1 - y0)
	var y := float(d.get("y", 0))
	var x0 := float(d.get("x0", 0))
	var x1 := float(d.get("x1", 0))
	return Rect2(x0, y - depth * 0.5, x1 - x0, depth)


# ============================ کانون‌های نور ============================

## چند لکه‌ی بزرگِ روشن روی زمینِ تاریک.
##
## زمین با CanvasModulate تاریک شده و این‌ها تنها منابعِ نورِ ثابت‌اند؛ بقیه‌ی
## نقشه در سایه می‌ماند و فقط با چراغِ بازیکن و نورِ شلیک روشن می‌شود.
##
## هر کانون از دو نور ساخته می‌شود: یک مغزِ روشن و یک هاله‌ی پهن‌ترِ کم‌جان.
## با یک نور، لبه‌ی لکه خیلی زود تمام می‌شود و دایره‌ی مصنوعی به‌چشم می‌آید؛
## هاله‌ی دوم آن مرز را می‌کشد و در تاریکی حل می‌کند.
##
## کانون‌ها هیچ‌وقت جابه‌جا نمی‌شوند. در کیفیتِ کم/متوسط به‌جای دو
## PointLight2D (هرکدام یک پاسِ اضافه روی کلِ بک‌گراند) یک کوادِ افزودنی با
## shaders/zone_halo.gdshader ساخته می‌شود که همان مغز + هاله را روی کف
## می‌اندازد. فرقش: فقط کف را روشن می‌کند، نه کاراکترها و دیوارها را.
func _build_zone_lights(zones: Array) -> void:
	_zones = zones.duplicate()
	_zone_halos = _want_zone_halos()
	_rebuild_zone_lights()


## کانون‌ها را با حالتِ فعلی (_zone_halos) از نو می‌سازد. نودِ ZoneLights سرِ
## همان جای قبلی‌اش در فهرستِ بچه‌ها می‌نشیند تا ترتیبِ رسم عوض نشود.
func _rebuild_zone_lights() -> void:
	var idx := -1
	if _zone_root != null and is_instance_valid(_zone_root):
		idx = _zone_root.get_index()
		remove_child(_zone_root)
		_zone_root.queue_free()
	_zone_root = null
	if _zones.is_empty():
		return
	var tex := LIGHT_TEX
	if tex == null:
		return

	var root := Node2D.new()
	root.name = "ZoneLights"
	add_child(root)
	if idx >= 0:
		move_child(root, idx)
	_zone_root = root

	var halo_mat: ShaderMaterial = _zone_halo_material() if _zone_halos else null
	var i := 0
	for z in _zones:
		if not (z is Array) or z.size() != 3:
			continue
		var pos := Vector2(float(z[0]), float(z[1]))
		var radius := float(z[2])
		# بافتِ نور مربعِ ۲۵۰ است و از مرکزش پخش می‌شود، پس برای پوشاندنِ
		# شعاعِ radius باید قطرش به ۲*radius برسد
		var core_scale := radius * 2.0 / float(tex.get_width())

		if halo_mat != null:
			# یک کواد به اندازه‌ی هاله؛ مغز را شیدر از همان بافت درمی‌آورد
			var s := Sprite2D.new()
			s.texture = tex
			s.position = pos
			s.scale = Vector2.ONE * core_scale * halo_scale
			s.material = halo_mat
			root.add_child(s)
		else:
			root.add_child(_zone_light(tex, pos, core_scale,
				zone_light_color, zone_light_energy))
			# هاله: بزرگ‌تر و کم‌جان‌تر، فقط برای محو شدنِ نرمِ لبه
			root.add_child(_zone_light(tex, pos, core_scale * halo_scale,
				zone_light_color, zone_light_energy * halo_energy))
		i += 1
	print("💡 Arena: %d کانونِ نور (%s)" % [i, "هاله" if _zone_halos else "PointLight2D"])


## متریالِ مشترکِ هاله‌ی کانون‌ها: بافت و مستطیلِ بک‌گراند، تاریکیِ محیط و
## همان رنگ و انرژی‌هایی که PointLight2Dها دارند.
func _zone_halo_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = ZONE_HALO_SHADER
	var bg := _floor_sprite()
	if bg != null and bg.texture != null:
		var r := bg.get_rect()
		var xf := bg.global_transform
		mat.set_shader_parameter("floor_tex", bg.texture)
		mat.set_shader_parameter("floor_origin", xf * r.position)
		mat.set_shader_parameter("floor_size", r.size * xf.get_scale().abs())
	mat.set_shader_parameter("floor_tint",
		Vector3(ambient_tint.r, ambient_tint.g, ambient_tint.b))
	mat.set_shader_parameter("light_color",
		Vector3(zone_light_color.r, zone_light_color.g, zone_light_color.b))
	mat.set_shader_parameter("core_energy", zone_light_energy)
	mat.set_shader_parameter("halo_energy", zone_light_energy * halo_energy)
	mat.set_shader_parameter("halo_scale", halo_scale)
	return mat


## اسپرایتِ کفِ زمین — همانی که _apply_background و _darken_world عوض می‌کنند
func _floor_sprite() -> Sprite2D:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is Sprite2D:
			return child as Sprite2D
	return null


func _zone_light(tex: Texture2D, pos: Vector2, scale_f: float,
		colour: Color, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = tex
	l.position = pos
	l.scale = Vector2(scale_f, scale_f)
	l.color = colour
	l.energy = energy
	# blend افزودنی: چند کانون که روی هم می‌افتند باید جمع شوند، نه اینکه
	# یکی دیگری را بپوشاند
	l.blend_mode = Light2D.BLEND_MODE_ADD
	return l


## کفِ زمین را تاریک می‌کند.
##
## بک‌گراند تنها آیتمِ بزرگِ صحنه است که نورپردازی می‌خورد، پس تاریکیِ کلِ
## زمین عملاً همین یک خط است. CanvasModulate هم ست می‌شود تا اگر روزی رندرر
## عوض شد صحنه دوبار تاریک نشود — مقدارش سفید می‌شود و کار را به این می‌سپارد.
func _darken_world() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var n := 0
	for child in parent.get_children():
		if child is Sprite2D:
			(child as Sprite2D).modulate = ambient_tint
			n += 1
		elif child is CanvasModulate:
			(child as CanvasModulate).color = Color(1, 1, 1)
	print("🌑 Arena: %d آیتمِ کف تاریک شد" % n)


# ============================ کیفیتِ گرافیک ============================

func _quality_level() -> int:
	return LocalSettings.quality_level()


## در کیفیتِ کم/متوسط (بدونِ HDR) کانون‌ها هاله می‌شوند
func _want_zone_halos() -> bool:
	return _quality_level() < LocalSettings.QUALITY_HIGH


## HDR 2D و Glowِ WorldEnvironment فقط در کیفیتِ زیاد. در بقیه محیط کلاً از
## نود برداشته می‌شود: با پس‌زمینه‌ی Canvas حتی بدونِ Glow هم بومِ دوبعدی
## یک بار در بافرِ سه‌بعدی کپی و tonemap می‌شود.
func _apply_render_quality() -> void:
	if not hdr_glow or not is_inside_tree():
		return
	var fancy := _quality_level() >= LocalSettings.QUALITY_HIGH
	get_viewport().use_hdr_2d = fancy
	_hdr_touched = true
	var we := _world_env()
	if we == null:
		return
	if _env == null:
		_env = we.environment
	we.environment = _env if fancy else null


func _world_env() -> WorldEnvironment:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is WorldEnvironment:
			return child as WorldEnvironment
	return null


## چیزهایی از خودِ نقشه که به کیفیت بستگی دارند: نورِ مشعل‌ها، هاله‌ها،
## کانون‌ها و پرچمِ ldr_fixِ شیدرها.
func _apply_scene_quality() -> void:
	var level := _quality_level()
	_applied_level = level
	var ldr := not get_viewport().use_hdr_2d
	for m in _ldr_mats:
		if m != null:
			m.set_shader_parameter("ldr_fix", ldr)

	# مشعل‌ها به ترتیبِ بُرخورده‌ی ساخت‌اند، پس چند تای اول در کلِ زمین پخش‌اند
	var cap := max_torches
	if level == LocalSettings.QUALITY_LOW:
		cap = 0
	elif level == LocalSettings.QUALITY_MEDIUM:
		cap = mini(cap, TORCH_LIT_MEDIUM)
	_lit_torches.clear()
	for i in _torches.size():
		var t: Variant = _torches[i]
		if not is_instance_valid(t):
			continue
		var lit := i < cap
		t.set_lit(lit)
		t.set_halo(ldr)
		if lit:
			_lit_torches.append(t)
	set_process(not _lit_torches.is_empty())

	if not _zones.is_empty() and _want_zone_halos() != _zone_halos:
		_zone_halos = not _zone_halos
		_rebuild_zone_lights()


## روشنایی هم همین سیگنال را می‌فرستد؛ فقط وقتی پله‌ی کیفیت عوض شده کار هست
func _on_video_settings_changed() -> void:
	if _quality_level() == _applied_level:
		return
	_apply_render_quality()
	_apply_scene_quality()


## نبضِ نورِ مشعل‌های روشن — یک حلقه به‌جای یک _process برای هر مشعل
func _process(_delta: float) -> void:
	var now := float(Time.get_ticks_msec()) * 0.001
	for t in _lit_torches:
		t.flicker(now)


# ============================ پرس‌وجو ============================

## بررسی محلی: آیا این نقطه داخل مانع است؟ (فقط برای منطق کلاینت، نه اعتبارسنجی)
func is_blocked(point: Vector2) -> bool:
	for r in _rects:
		if r.has_point(point):
			return true
	return false


func random_spawn() -> Vector2:
	if spawn_points.is_empty():
		return world_size * 0.5
	return spawn_points.pick_random()


## مستطیل‌های دیوار (شاملِ مرزِ زمین) — مینی‌مپ همین‌ها را کوچک می‌کشد
func wall_rects() -> Array[Rect2]:
	return _rects


func _draw() -> void:
	if not debug_draw:
		return
	for r in _rects:
		draw_rect(r, Color(0, 1, 1, 0.25), true)
		draw_rect(r, Color(0, 1, 1, 0.7), false, 2.0)
	for p in spawn_points:
		draw_circle(p, 12.0, Color(1, 1, 0, 0.8))
