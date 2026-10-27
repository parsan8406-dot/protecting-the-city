extends Control

# نودهای رابط کاربری (UI)
# نکته: لیبل‌های پروفایل/سکه/جم/سطح دیگه اینجا نیستن — اونا داخل صحنه‌ی
# reusable «TopBar» (res://secense/top_bar.tscn) مدیریت میشن که مستقیم از Global میخونه.
@onready var http_request = $HTTPRequest

# نود جدید کاراکتر که از نوع Polygon2D است
@onready var character_node: Polygon2D = $Node2D/Character
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var SERVER_URL = Global.SERVER_BASE + "/get_player"
const CHARACTERS_FOLDER_PATH: String = "res://assets/characters/"
const CITY_SCENE_PATH := "res://secense/city.tscn"
const CHAT_SCENE_PATH := "res://secense/chat.tscn"
const RANK_SCENE_PATH := "res://secense/rank_screen.tscn"
const RANKING_SCENE_PATH := "res://secense/ranking_screen.tscn"

@onready var leadboard_button: TextureButton = $BottomMenu/HBoxContainer/HBoxContainer/LeadboardButton
@onready var rank_button: TextureButton = $BottomMenu/HBoxContainer/HBoxContainer/RankButton
@onready var city_button: TextureButton = $BottomMenu/HBoxContainer/HBoxContainer/CityButton
@onready var chat_button: TextureButton = $BottomMenu/HBoxContainer/ChatButton
@onready var chat_badge: Panel = $BottomMenu/HBoxContainer/ChatButton/Badge
@onready var chat_badge_count: Label = $BottomMenu/HBoxContainer/ChatButton/Badge/Count

const FONT := preload("res://fonts/Lalezar-Regular.ttf")

# --- ناحیه‌ی امن ---
## کمترین فاصله‌ی هر دکمه از لبه‌ی صفحه، حتی روی گوشیِ بی‌ناچ
const SAFE_EDGE := 16.0
## ارتفاعِ نوارِ بالا (top_bar.tscn) و فاصله‌ی کادرِ ماموریت‌ها از زیرش
const TOP_BAR_H := 54.0
const TOP_BAR_PAD := 6.0
## پهنای ستونِ دکمه‌های اصلیِ سمتِ چپ (کمترین پهنای خودِ دکمه‌ها در صحنه)
const LEFT_COLUMN_W := 470.0
## فاصله‌ی ستونِ راست از لبه‌ی راست در خودِ صحنه — تا وقتی ناچ از این کمتر
## است، ستون جابه‌جا نمی‌شود
const RIGHT_COLUMN_GAP := 21.0
## کادرِ بتل‌پس با این مقیاس کشیده شده (آرتش ۶۴۳×۲۱۸ است)
const PASS_SCALE := 0.6
const PASS_MIN_SCALE := 0.42
## کمترین فاصله‌ی کادرِ بتل‌پس از کادرهای بالا و پایینش
const PASS_MIN_GAP := 6.0

# --- دکمه‌ی Back اندروید ---
## دو بار Back در همین فاصله یعنی خروج از بازی
const EXIT_WINDOW_MS := 2000

## offsetهای اصلیِ صحنه، تا جابه‌جاییِ ناحیه‌ی امن هر بار از همان حساب شود
var _base_offsets: Dictionary = {}
var _back_frame := -1               # جلوی دوبار اجرا شدنِ «بازگشت» در یک فریم
var _last_back_ms := -100000
var _toast: PanelContainer = null
var _toast_tw: Tween = null

# --- V5 فون رستورف: فقط «شروع» دکمه‌ی اصلیِ متمایز است ---
## پسِ‌زمینه‌ی قرمزِ آرتِ «شروع» طلایی/کهربایی می‌شود (متنِ سفید دست نمی‌خورد)
const CTA_GOLD_SHADER := """
shader_type canvas_item;
varying vec4 v_mod;
void vertex() { v_mod = COLOR; }
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float chroma = t.r - max(t.g, t.b);
	vec3 gold = vec3(0.86, 0.58, 0.10) * (0.6 + t.r * 0.6);
	float k = smoothstep(0.18, 0.38, chroma);
	t.rgb = mix(t.rgb, gold, k);
	t.a = mix(t.a, max(t.a, 0.94), k);
	// V5/V8: برقِ باریکی هر چند ثانیه یک بار از روی دکمه رد می‌شود
	float sweep = mod(TIME, 4.2) / 1.1 - 0.25;
	float band = 1.0 - smoothstep(0.0, 0.07, abs(UV.x + UV.y * 0.25 - sweep));
	t.rgb += vec3(1.0, 0.92, 0.7) * band * 0.32 * k;
	COLOR = t * v_mod;
}
"""
## «بازی کردن» قبلاً هم قرمزِ پررنگ بود و با «شروع» رقابت می‌کرد؛ حالا
## زمینه‌اش مثلِ سه دکمه‌ی دیگرِ ستون تیره می‌شود (آیکن و متن سفید می‌مانند)
const DEMOTE_RED_SHADER := """
shader_type canvas_item;
varying vec4 v_mod;
void vertex() { v_mod = COLOR; }
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float chroma = t.r - max(t.g, t.b);
	float base = min(t.g, t.b);
	vec3 dark = vec3(base + 0.078 * (1.0 - smoothstep(0.6, 0.85, chroma)));
	t.rgb = mix(t.rgb, dark, smoothstep(0.18, 0.38, chroma));
	COLOR = t * v_mod;
}
"""
## V9: «تغییر» روی آرتِ دکمه‌ی نوعِ بازی خاکستریِ کم‌رنگ بود و غیرفعال به
## نظر می‌رسید؛ متنِ خاکستریِ ثلثِ راست سفید می‌شود تا «لمس‌کردنی» دیده شود
const TYPE_CHANGE_SHADER := """
shader_type canvas_item;
varying vec4 v_mod;
void vertex() { v_mod = COLOR; }
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float lum = dot(t.rgb, vec3(0.333));
	float chroma = max(t.r, max(t.g, t.b)) - min(t.r, min(t.g, t.b));
	float k = step(0.72, UV.x) * smoothstep(0.32, 0.5, lum) * (1.0 - smoothstep(0.08, 0.16, chroma));
	t.rgb = mix(t.rgb, vec3(0.97, 0.95, 0.9), k);
	COLOR = t * v_mod;
}
"""
const CTA_PULSE_TIME := 1.1
## V8: ورودِ پلکانی و پس‌زمینه‌ی زنده (psych_lobby_intro.gd)
const INTRO := preload("res://scripts/psych_lobby_intro.gd")
## اگر اسکین تا این مدت نرسید (سرورِ کند)، همان آرتِ صحنه نشان داده می‌شود
const CHARACTER_FALLBACK_SEC := 3.0
var _character_shown := false
var _cta_halo: Panel = null

# --- E7/E16: «هدفِ بعدی» زیرِ ستونِ چپ (psych_menu_next_goal.gd) ---
const NEXT_GOAL := preload("res://scripts/psych_menu_next_goal.gd")
## پهنای کادر نسبت به ستونِ دکمه‌ها — کوتاه‌تر از آن، تا ثانویه دیده شود (V5)
const NEXT_GOAL_W := 400.0
const NEXT_GOAL_GAP := 12.0
var _next_goal: Control = null

func _ready():
	# Back در منوی اصلی نباید یک‌باره اپ را ببندد — دو بار پشتِ هم یعنی خروج
	get_tree().set_quit_on_go_back(false)
	if not MusicManager.playing:
		MusicManager.play()
	if not http_request.request_completed.is_connected(_on_http_request_request_completed):
		http_request.request_completed.connect(_on_http_request_request_completed)

	_wire_mode_button()
	_wire_primary_buttons()
	_style_primary_cta()

	# دکمه‌ی رتبه‌بندی پایین صفحه → صحنه‌ی رتبه بندی (جدول دوستان / شهرها / رتبه کلی)
	UIFx.bind_press(leadboard_button, _open_ranking)

	# دکمه‌ی رنک پایین صفحه → صحنه‌ی رنک فصل خودم (نردبان رنک و کاپ‌ها)
	UIFx.bind_press(rank_button, _open_rank_screen)

	# دکمه‌ی شهر پایین صفحه → صحنه‌ی شهر (کلن)
	UIFx.bind_press(city_button, _open_city)

	# دکمه‌ی پیام پایین صفحه → صحنه‌ی چت (خصوصی / شهر / جهانی)
	UIFx.bind_press(chat_button, _open_chat)

	# نشان قرمز پیام‌های خوانده‌نشده‌ی چت
	if not Global.chat_unread_updated.is_connected(_refresh_chat_badge):
		Global.chat_unread_updated.connect(_refresh_chat_badge)
	_refresh_chat_badge(Global.unread_chat)
	Global.refresh_chat_unread()

	fetch_player_data()
	# نوارِ بالا (سکه، الماس، تجربه، سطح) از Global خوانده می‌شود و این صحنه
	# قبلاً فقط عکسِ کاراکتر را از جوابِ خودش برمی‌داشت — بعد از هر مسابقه
	# پاداش‌ها تا رفرشِ بعدیِ یک صفحه‌ی دیگر دیده نمی‌شدند.
	Global.refresh_player_data()
	
	# پخش انیمیشن دفرمه وکتوری
	if anim_player and anim_player.has_animation("idle"):
		anim_player.play("idle")

	_build_toast()
	_build_next_goal()

	# ناحیه‌ی امن: هم با تغییرِ اندازه، هم با چرخشِ ۱۸۰ درجه‌ای (که اندازه را
	# عوض نمی‌کند و فقط ناچ را آن طرف می‌برد — SafeArea خودش چکش می‌کند)
	_store_base_offsets()
	get_viewport().size_changed.connect(_apply_safe_area)
	if not SafeArea.changed.is_connected(_apply_safe_area):
		SafeArea.changed.connect(_apply_safe_area)
	_apply_safe_area()
	_play_intro()


## V8: پس‌زمینه‌ی زنده از همان اول؛ ورودِ پلکانی بعد از اولین فریمِ چیدمان،
## تا جای نهاییِ هر بخش (بعد از ناحیه‌ی امن) معلوم باشد
func _play_intro() -> void:
	INTRO.living_background(self, get_node_or_null("Background") as Control)
	# V8: آرتِ پیش‌فرضِ صحنه یک سیلوئتِ سفید است و تا رسیدنِ اسکینِ واقعی
	# «خراب» به نظر می‌رسید؛ تا آن موقع پنهان، بعد آرام ظاهر می‌شود
	var stage := get_node_or_null("Node2D") as CanvasItem
	if stage != null and not _character_shown:
		stage.modulate.a = 0.0
		get_tree().create_timer(CHARACTER_FALLBACK_SEC).timeout.connect(_reveal_character)
	await get_tree().process_frame
	if is_inside_tree():
		INTRO.play(self)

## شش دکمه‌ی اصلی: انیمیشنِ فشردن (UIFx) و بعد کارِ خودشان.
## قبلاً سیگنال‌ها در خودِ صحنه وصل بودند و هیچ بازخوردِ لمسی نداشتند؛
## آن اتصال‌ها از صحنه برداشته شده‌اند تا هر کار دوبار اجرا نشود.
## (دکمه‌ی نوعِ بازی در _wire_mode_button وصل می‌شود.)
func _wire_primary_buttons() -> void:
	var actions := {
		"VBoxContainer/PlayButton": _on_play_button_pressed,
		"VBoxContainer/MatchButton": _on_match_button_pressed,
		"VBoxContainer/ShopButton": _on_shop_button_pressed,
		"VBoxContainer/SelectitemButton": _on_selectitem_button_pressed,
		"StartButton": _on_start_button_pressed,
	}
	for path in actions:
		var btn := get_node_or_null(path) as BaseButton
		if btn != null:
			btn.focus_mode = Control.FOCUS_NONE
			UIFx.bind_press(btn, actions[path])

## V5 + V9: یک CTAی طلاییِ بزرگ با نفسِ آرام، در محدوده‌ی شستِ راست (C3).
## پالس روی هاله‌ی پشتِ دکمه است نه روی scale خودِ دکمه، تا با انیمیشنِ
## فشردنِ UIFx دعوا نکند.
func _style_primary_cta() -> void:
	var start := get_node_or_null("StartButton") as TextureButton
	if start != null:
		start.material = _shader_material(CTA_GOLD_SHADER)
		_cta_halo = Panel.new()
		_cta_halo.name = "CtaHalo"
		_cta_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cta_halo.show_behind_parent = true
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_border_width_all(3)
		sb.border_color = Color(1.0, 0.82, 0.3, 0.95)
		sb.set_corner_radius_all(6)
		sb.shadow_color = Color(1.0, 0.72, 0.18, 0.55)
		sb.shadow_size = 16
		_cta_halo.add_theme_stylebox_override("panel", sb)
		start.add_child(_cta_halo)
		start.resized.connect(_fit_cta_halo)
		_fit_cta_halo()
		var tw := _cta_halo.create_tween().set_loops()
		tw.tween_property(_cta_halo, "modulate:a", 1.0, CTA_PULSE_TIME) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_cta_halo, "modulate:a", 0.3, CTA_PULSE_TIME) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var play := get_node_or_null("VBoxContainer/PlayButton") as CanvasItem
	if play != null:
		play.material = _shader_material(DEMOTE_RED_SHADER)
	var type_btn := get_node_or_null("TypeButton") as CanvasItem
	if type_btn != null:
		type_btn.material = _shader_material(TYPE_CHANGE_SHADER)


## هاله دقیقاً دورِ خودِ آرت (stretch_mode = keep aspect centered)، نه کلِ دکمه
func _fit_cta_halo() -> void:
	var start := get_node_or_null("StartButton") as TextureButton
	if start == null or _cta_halo == null or start.texture_normal == null:
		return
	var tex := start.texture_normal.get_size()
	var box := start.size
	if tex.x <= 0.0 or tex.y <= 0.0 or box.x <= 0.0:
		return
	var k := minf(box.x / tex.x, box.y / tex.y)
	var drawn := tex * k
	_cta_halo.position = (box - drawn) * 0.5 + Vector2(2, 2)
	_cta_halo.size = drawn - Vector2(4, 4)


func _shader_material(code: String) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat


func fetch_player_data():
	var username = Global.my_username
	if username.is_empty():
		username = "Player1"
		
	# درخواست قبلی هنوز در راه است — دومی خطا می‌دهد و لازم هم نیست
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return

	var url = SERVER_URL + "?username=" + username.uri_encode()
	var err = http_request.request(url, Global.auth_headers())
	
	if err != OK:
		print("❌ خطا در ارسال درخواست HTTP:", err)

func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("❌ خطا در دریافت اطلاعات از سرور. کد status:", response_code)
		return

	var json_string = body.get_string_from_utf8()
	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result == OK:
		var data = json.data
		if typeof(data) == TYPE_DICTIONARY:
			update_ui(data)

func update_ui(data: Dictionary):
	# لود کاراکتر بر اساس دیتای سرور
	if data.has("equipped_character"):
		# اسکین فعال اگر هست، وگرنه ظاهر پیش‌فرض کاراکتر
		var skins: Dictionary = data.get("equipped_skins", {}) if typeof(data.get("equipped_skins")) == TYPE_DICTIONARY else {}
		var char_id := str(data["equipped_character"])
		load_character_by_id(str(skins.get(char_id, char_id)))
	elif data.has("character"):
		load_character_by_id(str(data["character"]))

## شخصیت یک بار و نرم ظاهر می‌شود (اسکینِ واقعی یا بعد از مهلت)
func _reveal_character() -> void:
	if _character_shown or not is_inside_tree():
		return
	_character_shown = true
	var stage := get_node_or_null("Node2D") as CanvasItem
	if stage != null:
		stage.create_tween().tween_property(stage, "modulate:a", 1.0, 0.35) 			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

## لود تصویر جدید روی شبکه وکتوری Polygon2D
func load_character_by_id(char_id: String) -> void:
	if not character_node:
		print("❌ نود Character پیدا نشد!")
		return

	var extensions = ["", ".png", ".jpg", ".webp"]
	var loaded_texture: Texture2D = null

	for ext in extensions:
		var check_path = CHARACTERS_FOLDER_PATH + char_id + ext
		if ResourceLoader.exists(check_path):
			loaded_texture = load(check_path) as Texture2D
			break

	if loaded_texture:
		# جایگزین کردن تصویر روی همان شبکه وکتوری و انیمیشن
		character_node.texture = loaded_texture
		_reveal_character()
		print("✅ تصویر کاراکتر با موفقیت در Polygon2D بارگذاری شد: ", char_id)
	else:
		print("❌ تصویر کاراکتر یافت نشد: ", CHARACTERS_FOLDER_PATH + char_id)

func _open_ranking() -> void:
	get_tree().change_scene_to_file(RANKING_SCENE_PATH)

func _open_rank_screen() -> void:
	get_tree().change_scene_to_file(RANK_SCENE_PATH)

func _open_city() -> void:
	get_tree().change_scene_to_file(CITY_SCENE_PATH)

func _open_chat() -> void:
	get_tree().change_scene_to_file(CHAT_SCENE_PATH)

## نشان قرمز روی دکمه‌ی چت — صفر یعنی اصلاً نشان داده نشود
func _refresh_chat_badge(count: int) -> void:
	if chat_badge == null:
		return
	var had := chat_badge.visible
	chat_badge.visible = count > 0
	# همان قاعده‌ی نشانِ پیام‌های نوارِ بالا: عددِ واقعی، بیش از ۹ یعنی «9+»
	chat_badge_count.text = "9+" if count > 9 else str(count)
	# E16: نشانِ تازه یک تپش کوچک می‌زند تا دیده شود (فقط وقتی ظاهر می‌شود)
	if count > 0 and not had:
		chat_badge.pivot_offset = chat_badge.size * 0.5
		chat_badge.scale = Vector2(0.4, 0.4)
		chat_badge.create_tween().tween_property(chat_badge, "scale", Vector2.ONE, 0.32) 			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## دکمه‌ی «عملیات ضربت / ۴ در ۴» بالای دکمه‌ی شروع — هم نوعِ بازی را نشان
## می‌دهد و هم در را به منوی انتخابِ حالت باز می‌کند.
func _wire_mode_button() -> void:
	var btn := get_node_or_null("TypeButton")
	if btn == null:
		return
	# فشردن با انیمیشنِ UIFx، بعد رفتن به منوی حالت‌ها
	UIFx.bind_press(btn as BaseButton, _on_type_button_pressed)
	if not Global.game_mode_changed.is_connected(_refresh_mode_button):
		Global.game_mode_changed.connect(_refresh_mode_button)
	_refresh_mode_button()


func _refresh_mode_button() -> void:
	var title := get_node_or_null("TypeButton/VBoxContainer/TitleLabel")
	var sub := get_node_or_null("TypeButton/VBoxContainer/TypeLabel")
	if title != null:
		title.text = Global.selected_mode_name
	if sub != null:
		sub.text = Global.selected_mode_subtitle
	_refresh_mode_emblem()


## نشانِ عملیاتِ انتخابی، سمتِ چپِ دکمه. از کد ساخته می‌شود و نه از صحنه،
## چون با هر تعویضِ حالت باید عوض شود — و حالت‌ها از سرور می‌آیند.
func _refresh_mode_emblem() -> void:
	var btn := get_node_or_null("TypeButton")
	if btn == null:
		return
	# قبل از اولین بازدید از منوی حالت‌ها selected_mode خالی است؛
	# selected_mode_info خودش روی حالتِ پیش‌فرض می‌افتد.
	var mode_id := str(Global.selected_mode_info().get("mode_id", "strike"))
	var path := "res://assets/ui/modes/%s.png" % mode_id
	if not ResourceLoader.exists(path):
		return
	var emblem := btn.get_node_or_null("ModeEmblem") as TextureRect
	if emblem == null:
		emblem = TextureRect.new()
		emblem.name = "ModeEmblem"
		emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# لنگر به لبه‌ی چپِ دکمه، جای خالیِ کنارِ متن
		emblem.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		emblem.offset_left = 6.0
		emblem.offset_right = 76.0
		emblem.offset_top = -35.0
		emblem.offset_bottom = 35.0
		btn.add_child(emblem)
	emblem.texture = load(path)


func _on_type_button_pressed():
	get_tree().change_scene_to_file("res://secense/game_modes.tscn")


func _on_play_button_pressed():
	# «مسابقه سریع» — اول سطح را بپرس، بعد برو به زمینِ تمرین
	if get_node_or_null("DifficultyPicker") != null:
		return
	# آموزشِ بارِ اول: بدون سؤالِ سطح، مستقیم زمینِ تمرینِ آسان
	if Tutorial.is_running():
		Global.quick_play_difficulty = 0
		LoadingScreen.change_scene("res://secense/quick_play.tscn")
		return
	var picker = preload("res://scripts/difficulty_picker.gd").new()
	picker.name = "DifficultyPicker"
	add_child(picker)
	picker.chosen.connect(func(_level: int):
		LoadingScreen.change_scene("res://secense/quick_play.tscn"))

func _on_match_button_pressed():
	# TODO: صحنه‌ی مچ‌میکینگ هنوز ساخته نشده
	get_tree().change_scene_to_file("res://secense/game_modes.tscn")

func _on_selectitem_button_pressed():
	get_tree().change_scene_to_file("res://secense/character_select_screen.tscn")

func _on_shop_button_pressed():
	get_tree().change_scene_to_file("res://secense/shop.tscn")

func _on_start_button_pressed():
	# بازیِ چندنفره از صفِ پیدا کردنِ حریف شروع می‌شود، نه مستقیم از زمین
	get_tree().change_scene_to_file("res://secense/matchmaking.tscn")

# ============================ ناحیه‌ی امن (ناچ) ============================

## offsetهای صحنه یک بار خوانده می‌شوند؛ هر چیدمانِ بعدی از روی همین‌ها
## حساب می‌شود تا جابه‌جایی‌ها روی هم جمع نشوند.
func _store_base_offsets() -> void:
	for path in ["dailyMissions", "BattlepassBox", "TypeButton", "StartButton"]:
		var c := get_node_or_null(path) as Control
		if c != null:
			_base_offsets[path] = Vector4(c.offset_left, c.offset_top, c.offset_right, c.offset_bottom)

## هیچ دکمه‌ای زیرِ ناچ یا لبه‌ی خمیده نمی‌افتد: هر طرف حداقل SAFE_EDGE یا
## به اندازه‌ی ناچ فاصله. پس‌زمینه‌ها (نوارِ بالا و نوارِ پایین) تا لبه می‌روند
## و فقط محتوای قابل لمسشان جابه‌جا می‌شود.
func _apply_safe_area() -> void:
	if not is_inside_tree():
		return
	var ins := SafeArea.insets_for(self)
	var left := maxf(ins.x, SAFE_EDGE)
	var right := maxf(ins.z, SAFE_EDGE)
	var top := ins.y
	var vp := get_viewport_rect().size

	# --- نوارِ بالا: پس‌زمینه تا لبه، محتوا داخلِ ناحیه‌ی امن ---
	# (هر صفحه offsetهای نوارِ بالای خودش را می‌دهد، نه خودِ top_bar.gd)
	var bar := get_node_or_null("TopBar") as Control
	if bar != null:
		bar.offset_bottom = TOP_BAR_H + top
		var bar_row := bar.get_node_or_null("HBoxContainer") as Control
		if bar_row != null:
			bar_row.offset_left = left
			bar_row.offset_right = -right
			bar_row.offset_top = TOP_BAR_PAD + top

	# --- ستونِ دکمه‌های اصلیِ چپ ---
	var column := get_node_or_null("VBoxContainer") as Control
	if column != null:
		column.offset_left = left
		column.offset_right = left + LEFT_COLUMN_W

	# --- نوارِ پایین: آرتش تا لبه، دکمه‌ها داخلِ ناحیه‌ی امن ---
	var bottom_menu := get_node_or_null("BottomMenu") as Control
	var bottom_row := get_node_or_null("BottomMenu/HBoxContainer") as Control
	if bottom_row != null:
		bottom_row.offset_left = left
		bottom_row.offset_right = -right
		bottom_row.offset_bottom = -ins.w

	_layout_right_column(vp, top, right, bottom_menu)
	_layout_next_goal(column, bottom_menu, vp, left)


func _build_next_goal() -> void:
	# نگه‌دارنده جا را تعیین می‌کند؛ خودِ کادر هر وقت هدفی نبود پنهان می‌شود
	_next_goal = Control.new()
	_next_goal.name = "NextGoalSlot"
	_next_goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_goal.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_next_goal)
	var chip: Control = NEXT_GOAL.new()
	chip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_next_goal.add_child(chip)
	# زیرِ toast، تا پیامِ «دوباره بزنید» رویش بیفتد
	if _toast != null:
		move_child(_next_goal, _toast.get_index())


## درست زیرِ آخرین دکمه‌ی ستونِ چپ و بالای نوارِ پایین. اگر جا نبود (صفحه‌ی
## خیلی کوتاه) کلاً پنهان می‌ماند، نه این‌که روی دکمه‌ها بیفتد.
func _layout_next_goal(column: Control, bottom_menu: Control, vp: Vector2, left: float) -> void:
	if _next_goal == null or column == null:
		return
	var col_bottom := column.offset_top + column.get_combined_minimum_size().y
	var top := col_bottom + NEXT_GOAL_GAP
	var floor_y := vp.y
	if bottom_menu != null:
		floor_y = bottom_menu.anchor_top * vp.y + bottom_menu.offset_top - 8.0
	var h := 58.0
	_next_goal.visible = floor_y - top >= h
	_next_goal.offset_left = left
	_next_goal.offset_right = left + minf(NEXT_GOAL_W, LEFT_COLUMN_W)
	_next_goal.offset_top = top
	_next_goal.offset_bottom = top + h

## ستونِ راست، از پایین به بالا: شروع و نوعِ بازی روی نوارِ پایین می‌نشینند،
## ماموریت‌ها زیرِ نوارِ بالا، و کادرِ بتل‌پس دقیقاً وسطِ فاصله‌ی این دو.
##
## قبلاً همه با offset ثابت چیده شده بودند و روی ارتفاعِ ۶۴۸ کادرِ بتل‌پس دو
## پیکسل روی ماموریت‌ها می‌افتاد؛ روی تبلت (۴:۳) هم دکمه‌ی شروع روی نوارِ
## پایین می‌رفت، چون آن نوار با ارتفاعِ صفحه بلندتر می‌شود.
func _layout_right_column(vp: Vector2, top: float, right: float, bottom_menu: Control) -> void:
	if _base_offsets.size() < 4:
		return
	var shift := maxf(0.0, right - RIGHT_COLUMN_GAP)

	# --- شروع و نوعِ بازی: لبه‌ی پایینِ شروع درست روی نوارِ پایین ---
	var dy := 0.0
	var start_base: Vector4 = _base_offsets["StartButton"]
	if bottom_menu != null:
		var bar_top := bottom_menu.anchor_top * vp.y + bottom_menu.offset_top
		dy = (bar_top - 1.0 - vp.y) - start_base.w
	var type_top := vp.y
	for path in ["StartButton", "TypeButton"]:
		var c := get_node_or_null(path) as Control
		if c == null:
			continue
		var base: Vector4 = _base_offsets[path]
		c.offset_left = base.x - shift
		c.offset_right = base.z - shift
		c.offset_top = base.y + dy
		c.offset_bottom = base.w + dy
		if path == "TypeButton":
			type_top = vp.y + c.offset_top

	# --- ماموریت‌های روزانه: درست زیرِ نوارِ بالا ---
	var missions_base: Vector4 = _base_offsets["dailyMissions"]
	var missions_h := missions_base.w - missions_base.y
	var missions_top := TOP_BAR_H + top + TOP_BAR_PAD
	var missions := get_node_or_null("dailyMissions") as Control
	if missions != null:
		missions.offset_left = missions_base.x - shift
		missions.offset_right = missions_base.z - shift
		missions.offset_top = missions_top
		missions.offset_bottom = missions_top + missions_h

	# --- بتل‌پس: وسطِ فاصله‌ی ماموریت‌ها و نوعِ بازی ---
	var pass_box := get_node_or_null("BattlepassBox") as Control
	if pass_box == null:
		return
	var pass_base: Vector4 = _base_offsets["BattlepassBox"]
	var pass_h := pass_base.w - pass_base.y
	var gap_top := missions_top + missions_h
	var room := type_top - gap_top
	var k := PASS_SCALE
	if room - pass_h * k < PASS_MIN_GAP * 2.0:
		# صفحه‌ی خیلی کوتاه: کادر کمی کوچک‌تر می‌شود، ولی روی همسایه‌ها نمی‌افتد
		k = clampf((room - PASS_MIN_GAP * 2.0) / pass_h, PASS_MIN_SCALE, PASS_SCALE)
	# محورِ مقیاس گوشه‌ی بالا-چپ، تا جای دیداریِ کادر همان offsetها باشد
	pass_box.pivot_offset = Vector2.ZERO
	pass_box.scale = Vector2(k, k)
	var pass_top := gap_top + maxf((room - pass_h * k) * 0.5, 0.0)
	pass_box.offset_left = pass_base.x - shift
	pass_box.offset_right = pass_base.z - shift
	pass_box.offset_top = pass_top - vp.y
	pass_box.offset_bottom = pass_top - vp.y + pass_h

# ============================ دکمه‌ی Back اندروید ============================

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()
	elif what == NOTIFICATION_EXIT_TREE:
		get_tree().set_quit_on_go_back(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()

## ترتیب Back: پنجره‌ی جایزه ← انتخابِ سطح ← «دوباره بزنید» ← خروج
func _on_back() -> void:
	# Back اندروید هم notification می‌فرستد هم ui_cancel؛ فقط یک بار
	var frame := Engine.get_process_frames()
	if frame == _back_frame:
		return
	_back_frame = frame

	# پنجره‌ی جایزه خودش با Back بسته می‌شود
	if is_instance_valid(RewardPopup._active):
		return

	# انتخابِ سطحِ «بازی سریع» باز است: فقط همان بسته می‌شود
	var picker := get_node_or_null("DifficultyPicker")
	if picker != null and not picker.is_queued_for_deletion():
		if picker.has_signal("cancelled"):
			picker.emit_signal("cancelled")
		picker.queue_free()
		return

	var now := Time.get_ticks_msec()
	if now - _last_back_ms <= EXIT_WINDOW_MS:
		get_tree().quit()
		return
	_last_back_ms = now
	_show_toast("برای خروج دوباره بزنید")

func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.name = "ExitToast"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.05, 0.95)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.96, 0.78, 0.3)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	_toast.add_theme_stylebox_override("panel", sb)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# بالای نوارِ پایین، تا روی دکمه‌هایش نیفتد
	_toast.offset_bottom = -104.0
	_toast.modulate.a = 0.0

	var label := Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.97, 0.95, 0.9))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_child(label)
	add_child(_toast)

## پیامِ کوتاهِ پایینِ صفحه که خودش محو می‌شود
func _show_toast(text: String) -> void:
	if _toast == null:
		return
	(_toast.get_child(0) as Label).text = text
	_toast.reset_size()
	if _toast_tw != null:
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tw.tween_interval(1.6)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.3)
