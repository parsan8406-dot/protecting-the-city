extends CanvasLayer
class_name MatchResultScreen
## صفحه‌ی پایانِ مسابقه: «پیروزی»، «شکست» و «پیروزی مشترک».
##
## مساوی برنده‌ی مشترک است و نه بی‌برنده: سرور در این حالت پاداشِ کاملِ برد
## را به هر دو تیم می‌دهد (match_round.go → endRound)، پس این صفحه هم باید
## دقیقاً همان جوایز را نشان بدهد. قبلاً «این مسابقه برنده‌ای نداشت» می‌گفت
## و هیچ جایزه‌ای هم نمی‌آمد.
##
## round_hud بعد از match_over سرور می‌سازدش. پاداش (match_reward) ممکن است
## کمی بعدتر برسد؛ هر وقت رسید با set_reward داخلِ صفحه می‌نشیند و صفحه
## منتظرش نمی‌ماند.
##
## ترتیبِ انیمیشن:
##   ۱. پس‌زمینه یک‌باره کاملاً تار و پُررنگ می‌شود و هم‌زمان با بالا آمدنِ
##      منو آرام نیمه‌شفاف می‌شود تا زمینِ بازی (تار) از زیرش دیده شود
##   ۲. منو از پایینِ صفحه بالا می‌آید
##   ۳. وقتی کاملاً نشست: پیروزی ← بال‌ها رو به بالا باز می‌شوند،
##      شکست ← بال‌ها رو به پایین می‌افتند
##   ۴. جایزه‌ها (پیروزی) یا کاپِ قبل/بعد (شکست) با شمارشِ عدد، و آخر دکمه
##
## زمینِ بازی زیرِ صفحه قفل است: لایه‌ی Blocker همه‌ی لمس‌ها را می‌گیرد و
## world.gd جوی‌استیک و نشانه‌گیری را خاموش می‌کند. Back اندروید را هم
## world.gd به handle_back همین صفحه می‌دهد.
##
## همه‌چیز در واحدِ طراحی با ارتفاعِ ۷۲۰ چیده می‌شود و کلِ صحنه با ارتفاعِ
## واقعیِ صفحه بزرگ/کوچک می‌شود (مثل GameHUD). عرض آزاد است و محتوا وسط
## می‌نشیند، پس از ۴:۳ تا ۲۱:۹ درست دیده می‌شود؛ ناچ هم کنار گذاشته می‌شود.
##
## ردیفِ «بینش‌ها» زیرِ جوایز (docs/game-psychology.md):
##   بهترین لحظه   E4  کیل/استریک/بدون مرگ/برد پیاپی + «رکورد جدید»
##                     (آمار: psych_results_match_stats.gd از طریقِ Network)
##   رنک           E5/E6/C9  «فقط X کاپ تا طلا» / «یه برد تا ارتقا» / ارتقا + کنفتی
##   نزدیک‌ترین هدف E7/C8  ماموریتِ روزانه یا چالشِ فصلِ ناتمام از سرور
## و دو دکمه: «دوباره بازی» (طلایی، اصلی — V5/E5) و «لابی» (فرعی).
## نشانِ بالا اگر جا کم باشد کمی کوچک می‌شود تا همه در ارتفاعِ ۷۲۰ جا شوند.

const GROUP := "match_result"

enum Outcome { WIN, LOSE, DRAW }

const FONT_NUM := preload("res://fonts/Lalezar-Regular.ttf")
const FONT_TEXT := preload("res://fonts/SJADIDBD.TTF")
const BACKDROP_SHADER := preload("res://scripts/result_backdrop.gdshader")
const TITLE_SHADER := preload("res://scripts/result_title.gdshader")
const DESAT_SHADER := preload("res://scripts/result_desaturate.gdshader")

## آرت‌ها با load (نه preload) خوانده می‌شوند تا در طولِ بازی حافظه نگیرند
const ART := "res://assets/ui/WinDefeatMenu/"
const CUP_ICON := "res://assets/ranks/cup_trophy.png"
const COIN_ICON := "res://assets/ui/coin_icon.png"
const LOBBY_SCENE := "res://secense/main_menu.tscn"
## «دوباره بازی»: صفِ همان حالت (matchmaking از Global.selected_mode می‌خواند)
const REPLAY_SCENE := "res://secense/matchmaking.tscn"
## آیکن‌های روانشناسی (ممکن است هنوز نباشند — همه fallback دارند)
const PSYCH := "res://assets/ui/psych/"
const PsychProgress := preload("res://scripts/psych_results_progress.gd")
const CONFETTI := preload("res://scripts/psych_results_confetti.gd")
const INSIGHT_H := 80.0
const CHIP_W := 286.0

const DESIGN_H := 720.0
const EMBLEM := Vector2(640, 300)
const CREST_C := Vector2(320, 122)
const CARD := Vector2(158, 184)
const ICON := 96.0

## پس‌زمینه: شروع (کاملاً تار و پُررنگ) → پایان (نیمه‌شفاف و کمی تار)
const BLUR_START := 30.0
const BLUR_END := 9.0
const ART_LOD_START := 5.5
const ART_LOD_END := 1.0
const ART_ALPHA_END := 0.5

const SLIDE_DELAY := 0.06
const SLIDE_TIME := 0.8
const SETTLE_TIME := 0.85

## زاویه‌ی بال‌ها (درجه، برای بالِ چپ؛ راست قرینه است)
const WING_FOLDED := -28.0   # پیروزی قبل از باز شدن
const WING_DROOP := -16.0    # شکست بعد از افتادن

const GOLD := Color(0.97, 0.79, 0.32)
const GOLD_EDGE := Color(0.86, 0.64, 0.24)
const CREAM := Color(0.99, 0.94, 0.80)
const TEXT := Color(0.96, 0.94, 0.90)
const DIM := Color(0.80, 0.76, 0.70)
const RED := Color(0.93, 0.18, 0.20)
const ICE := Color(0.62, 0.80, 1.0)
const BROWN := Color(0.24, 0.12, 0.02)

var outcome: Outcome = Outcome.WIN
## نتیجه‌ی امتیازی («۷ − ۵») در حالت‌هایی که با کشته برنده تعیین می‌شود
var score_text := ""

var _reward: Dictionary = {}
var _body_shown := false
var _reward_applied := false
var _sliding := false
var _leaving := false
var _ready_for_back := false

var _backdrop_mat: ShaderMaterial = null
## دنیای بازی که زیرِ پس‌زمینه‌ی کاملاً پوشا پنهان شده (برای برگرداندن)
var _hidden_world: CanvasItem = null
var _stage: Control = null
var _slider: Control = null
var _margin: MarginContainer = null
var _wing_l: TextureRect = null
var _wing_r: TextureRect = null
var _cup: Control = null
var _glow: TextureRect = null
var _rays: Control = null
var _sparks: CPUParticles2D = null
var _title: Label = null
var _title_mat: ShaderMaterial = null
var _body: Control = null
var _ornaments: Array[Control] = []
var _cards_row: HBoxContainer = null
var _placeholder: Label = null
var _before_label: Label = null
var _after_label: Label = null
var _after_cup_mat: ShaderMaterial = null
var _after_tri: Control = null
var _arrow: Control = null
var _pill: Control = null
var _pill_label: Label = null
## شکست هم دست‌خالی نیست: «+N سکه · +M تجربه» زیرِ قرصِ کاپ
var _consolation_label: Label = null
var _pill_tri: Control = null
var _button: Button = null
var _button_plate: Control = null
## دکمه‌ی اصلی «دوباره بازی» (فقط آنلاین)؛ _button آن وقت «لابی» است
var _replay_button: Button = null
var _column: VBoxContainer = null
var _emblem: Control = null
var _emblem_holder: Control = null
var _insights: HBoxContainer = null
var _chip_moment: Dictionary = {}
var _chip_rank: Dictionary = {}
var _chip_goal: Dictionary = {}
## آمارِ همین مسابقه + رکوردها (PsychResultsMatchStats.commit)
var _stats: Dictionary = {}
var _goal_http: HTTPRequest = null
var _season_http: HTTPRequest = null
var _goal_missions: Array = []
var _goal_challenges: Array = []
var _goal_pending := 0


func _ready() -> void:
	layer = 115   # بالای HUD و تنظیماتِ داخلِ بازی (۱۱۰)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_play_intro()


func _exit_tree() -> void:
	# اگر صفحه بدونِ عوض شدنِ صحنه بسته شد، دنیا دوباره دیده شود
	if _hidden_world != null and is_instance_valid(_hidden_world):
		_hidden_world.visible = true
	_hidden_world = null


## پاداشِ سرور (پیامِ match_reward). قبل یا بعد از باز شدنِ صفحه فرقی ندارد.
func set_reward(data: Dictionary) -> void:
	# پاداش همین الان در دیتابیس نشسته؛ نوارِ بالا را هم تازه کن
	Global.refresh_player_data()
	_reward = data
	if _body_shown and not _reward_applied:
		_apply_reward()


## Back اندروید: همان کارِ دکمه‌ی صفحه — ولی نه وسطِ انیمیشنِ ورود
func handle_back() -> void:
	if _ready_for_back:
		_on_leave_pressed()


func _is_win_look() -> bool:
	return outcome != Outcome.LOSE


# ============================ ساخت ============================

func _build() -> void:
	var win := _is_win_look()

	var blocker := Control.new()
	blocker.name = "Blocker"
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# همه‌ی لمس‌ها همین‌جا می‌مانند و به زمینِ بازیِ زیرش نمی‌رسند
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop_mat = ShaderMaterial.new()
	_backdrop_mat.shader = BACKDROP_SHADER
	var art := _tex(ART + ("Win_BG.png" if win else "Defeat_BG.png"))
	if art != null:
		_backdrop_mat.set_shader_parameter("art_tex", art)
		_backdrop_mat.set_shader_parameter("art_size", Vector2(art.get_size()))
	else:
		_backdrop_mat.set_shader_parameter("art_alpha", 0.0)
	_backdrop_mat.set_shader_parameter("art_focus", Vector2(0.4, 0.5) if win else Vector2(0.42, 0.55))
	_backdrop_mat.set_shader_parameter("tint",
		Color(0.03, 0.02, 0.02, 0.32) if win else Color(0.05, 0.0, 0.01, 0.36))
	_backdrop_mat.set_shader_parameter("accent",
		Color(1.0, 0.72, 0.25, 0.22) if win else Color(0.95, 0.12, 0.12, 0.26))
	backdrop.material = _backdrop_mat
	blocker.add_child(backdrop)
	_capture_world()

	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blocker.add_child(_stage)

	# فقط همین لایه بالا می‌آید؛ Container نیست تا جایش را خودمان انیمیت کنیم
	_slider = Control.new()
	_slider.name = "Slider"
	_slider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_slider)

	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slider.add_child(_margin)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(column)
	_column = column

	# نشان داخلِ یک نگه‌دارنده تا بشود با scale کوچکش کرد (چیدمانِ داخلش
	# پیکسلی است) و جای ستون هم به همان اندازه کم شود — _fit_emblem
	_emblem_holder = Control.new()
	_emblem_holder.name = "EmblemHolder"
	_emblem_holder.custom_minimum_size = EMBLEM
	_emblem_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_emblem_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emblem = _build_emblem()
	_emblem_holder.add_child(_emblem)
	column.add_child(_emblem_holder)
	column.add_child(_build_subtitle())

	match outcome:
		# مساوی کاپ ندارد ولی نصفِ سکه‌ی برد را می‌دهد (سرور: OutcomeDraw)،
		# پس همان نوارِ جوایز را نشان می‌دهد
		Outcome.WIN, Outcome.DRAW:
			_body = _build_reward_band()
		Outcome.LOSE:
			_body = _build_trophy_panel()
	if _body != null:
		_body.modulate.a = 0.0
		column.add_child(_body)

	column.add_child(_build_insights())

	# V5 فقط یک دکمه‌ی اصلی: آنلاین «دوباره بازی» طلایی است و «لابی»
	# کوچک و سرمه‌ای کنارش (E5/E13: شروعِ دوباره‌ی فوری، حتی بعد از باخت)
	if _can_replay():
		var row := HBoxContainer.new()
		row.name = "Buttons"
		row.layout_direction = Control.LAYOUT_DIRECTION_LTR
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 28)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_button = _make_button("لابی", true, _on_leave_pressed, Vector2(200, 64))
		_replay_button = _make_button("دوباره بازی", false, _on_replay_pressed, Vector2(320, 74))
		# لابی سمتِ چپ، «دوباره» زیرِ شستِ راست
		row.add_child(_button)
		row.add_child(_replay_button)
		for b in [_button, _replay_button]:
			b.modulate.a = 0.0
			b.disabled = true
		column.add_child(row)
	else:
		if win:
			_button = _make_button("ادامه", false, _on_leave_pressed)
		else:
			_button = _make_button("بازگشت به لابی", true, _on_leave_pressed)
		_button.modulate.a = 0.0
		_button.disabled = true
		column.add_child(_button)


## نشانِ بالا: پرتوها، هاله، دو بال، جام/عقاب، قابِ عنوان و عنوان
func _build_emblem() -> Control:
	var win := _is_win_look()
	var e := Control.new()
	e.name = "Emblem"
	e.custom_minimum_size = EMBLEM
	e.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var accent := GOLD if win else RED

	_rays = Control.new()
	_rays.size = Vector2(640, 640)
	_rays.position = CREST_C - _rays.size * 0.5
	_rays.pivot_offset = _rays.size * 0.5
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.modulate.a = 0.0
	_rays.draw.connect(_draw_rays.bind(_rays, accent))
	e.add_child(_rays)

	_glow = TextureRect.new()
	_glow.texture = _radial(accent, 0.9)
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.size = Vector2(600, 360)
	_glow.position = CREST_C - _glow.size * 0.5 + Vector2(0, 26)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.modulate.a = 0.45
	e.add_child(_glow)

	# بال‌ها — pivot همان ریشه‌ی بال است (از روی آلفای عکس اندازه گرفته شده)
	var wing_size := Vector2(200, 200) if win else Vector2(250, 208)
	var root := Vector2(0.82, 0.85) if win else Vector2(0.80, 0.88)
	var spread := Vector2(40, 26) if win else Vector2(70, 28)
	_wing_l = _make_wing(ART + ("Leftwing_win.png" if win else "Leftwing_defeat.png"),
		wing_size, root, CREST_C + Vector2(-spread.x, spread.y))
	_wing_r = _make_wing(ART + ("Rightwing_win.png" if win else "Rightwing_defeat.png"),
		wing_size, Vector2(1.0 - root.x, root.y), CREST_C + spread)
	if outcome == Outcome.WIN:
		_wing_l.rotation_degrees = WING_FOLDED
		_wing_r.rotation_degrees = -WING_FOLDED
	e.add_child(_wing_l)
	e.add_child(_wing_r)

	var crest := _tex(ART + ("cup_win.png" if win else "Cup_defeat.png"))
	var crest_h := 156.0 if win else 166.0
	var aspect := 1.0
	if crest != null:
		aspect = float(crest.get_width()) / float(crest.get_height())
	var cup := TextureRect.new()
	cup.texture = crest
	cup.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cup.stretch_mode = TextureRect.STRETCH_SCALE
	cup.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	cup.size = Vector2(crest_h * aspect, crest_h)
	cup.position = CREST_C - cup.size * 0.5
	cup.pivot_offset = cup.size * 0.5
	cup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cup = cup
	e.add_child(cup)

	_sparks = _make_sparks(win)
	_sparks.position = CREST_C + Vector2(0, 30)
	e.add_child(_sparks)

	var plate := Control.new()
	plate.size = Vector2(440, 84)
	plate.position = Vector2(EMBLEM.x * 0.5 - 220.0, 198)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.draw.connect(_draw_title_plate.bind(plate, accent if not win else GOLD_EDGE, win))
	e.add_child(plate)

	_title = Label.new()
	_title.name = "Title"
	match outcome:
		Outcome.WIN: _title.text = "پیروزی"
		Outcome.LOSE: _title.text = "شکست"
		# مساوی یعنی هیچ‌کدام نباختند، نه اینکه هیچ‌کدام نبردند
		Outcome.DRAW: _title.text = "مساوی"
	_title.add_theme_font_override("font", FONT_NUM)
	_title.add_theme_font_size_override("font_size", 96)
	_title.add_theme_color_override("font_color", Color.WHITE)
	_title.add_theme_constant_override("outline_size", 14)
	_title.add_theme_color_override("font_outline_color",
		Color(0.26, 0.12, 0.02) if win else Color(0.28, 0.02, 0.03))
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.add_theme_constant_override("shadow_offset_y", 5)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.size = Vector2(EMBLEM.x, 150)
	_title.position = Vector2(0, 165)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_mat = ShaderMaterial.new()
	_title_mat.shader = TITLE_SHADER
	_title_mat.set_shader_parameter("rect_size", _title.size)
	# تا مقدار نگیرد، Tween این پارامتر را «ناموجود» می‌بیند
	_title_mat.set_shader_parameter("shine", -1.0)
	if win:
		_title_mat.set_shader_parameter("top_color", Color(1.0, 0.97, 0.70))
		_title_mat.set_shader_parameter("bottom_color", Color(0.90, 0.56, 0.12))
	else:
		_title_mat.set_shader_parameter("top_color", Color(1.0, 0.95, 0.95))
		_title_mat.set_shader_parameter("bottom_color", Color(0.80, 0.50, 0.53))
	_title.material = _title_mat
	e.add_child(_title)
	return e


func _build_subtitle() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# در «عملیات انتقام» نتیجه یک عدد است، نه فقط برد و باخت
	if score_text != "":
		row.add_child(_num_label(score_text, 30, GOLD))
	var text := "تیم شما پیروز شد!"
	var near := ""
	match outcome:
		Outcome.LOSE:
			text = "متأسفانه این بار پیروز نشدید!"
			near = _near_miss_text()
		Outcome.DRAW: text = "مساوی شد — کاپی کم نشد!"
	if near != "":
		# E5 نزدیک‌برد: باختِ نزدیک «تقریباً بردی» است، نه «باختی»
		row.add_child(_num_label(near, 26, GOLD))
	else:
		row.add_child(_text_label(text, 26, TEXT if outcome == Outcome.LOSE else CREAM))
	return row


## «فقط ۲ کیل تا پیروزی فاصله داشتید!» — فقط وقتی واقعاً نزدیک بود.
## عددها همان امتیازِ نهاییِ سرور (match_over) هستند.
func _near_miss_text() -> String:
	var info: Dictionary = Network.round_info
	var score: Dictionary = info.get("final_demon_damage", {})
	var demon := not score.is_empty()
	if not demon:
		if not bool(info.get("score_kills", false)):
			return ""
		score = info.get("final_score", {})
	if score.is_empty() or Global.my_team == "":
		return ""
	var ally := 0
	var foe := 0
	for team in score.keys():
		if str(team) == Global.my_team:
			ally += int(score[team])
		else:
			foe = maxi(foe, int(score[team]))
	var gap := foe - ally
	if gap <= 0:
		return ""
	if demon:
		# آسیب عددِ بزرگی است: «نزدیک» یعنی کمتر از ۱۵٪ فاصله
		if float(gap) > float(maxi(foe, 1)) * 0.15:
			return ""
		return "فقط %s آسیب تا پیروزی فاصله داشتید!" % _fa(gap)
	if gap > 2:
		return ""
	return "فقط %s کیل تا پیروزی فاصله داشتید!" % _fa(gap)


## پیروزی: نوارِ تیره‌ی تمام‌عرض با «جوایز دریافت شد» و کارت‌های جایزه
func _build_reward_band() -> Control:
	var band := PanelContainer.new()
	band.name = "RewardBand"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.025, 0.03, 0.74)
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(GOLD_EDGE, 0.85)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 12
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 16.0
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	band.add_theme_stylebox_override("panel", sb)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(v)
	# E14 پاداش «تأییدِ مهارت» است، نه مزد
	v.add_child(_make_header("پاداشِ عملکردت", GOLD_EDGE))

	_cards_row = HBoxContainer.new()
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_row.add_theme_constant_override("separation", 18)
	_cards_row.custom_minimum_size = Vector2(0, CARD.y)
	_cards_row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_cards_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_cards_row)

	# تا پیامِ پاداش برسد (معمولاً کسری از ثانیه)
	_placeholder = _text_label("در حال دریافت جوایز…", 22, DIM)
	_placeholder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_cards_row.add_child(_placeholder)
	return band


## شکست: کاپِ قبل ← بعد، و قرصِ «کاپ شما N واحد کاهش یافت»
func _build_trophy_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "TrophyPanel"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.025, 0.03, 0.9)
	sb.set_border_width_all(2)
	sb.border_color = Color(RED, 0.85)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(RED, 0.28)
	sb.shadow_size = 16
	sb.content_margin_left = 28.0
	sb.content_margin_right = 28.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(620, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)

	# چپ: قبل (جامِ طلایی)؛ راست: بعد (جامِ نقره‌ای) — مثلِ طرح
	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)

	var before := HBoxContainer.new()
	before.add_theme_constant_override("separation", 12)
	before.mouse_filter = Control.MOUSE_FILTER_IGNORE
	before.add_child(_icon_rect(_tex(CUP_ICON), 84))
	var bcol := _stack()
	bcol.add_child(_text_label("قبل از شکست", 20, DIM))
	_before_label = _num_label("…", 46, CREAM)
	bcol.add_child(_before_label)
	before.add_child(bcol)
	row.add_child(before)

	row.add_child(_expander())
	_arrow = Control.new()
	_arrow.custom_minimum_size = Vector2(44, 56)
	_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.draw.connect(_draw_chevron.bind(_arrow))
	row.add_child(_arrow)
	row.add_child(_expander())

	var after := HBoxContainer.new()
	after.add_theme_constant_override("separation", 12)
	after.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var acol := _stack()
	acol.add_child(_text_label("بعد از شکست", 20, DIM))
	var anum := HBoxContainer.new()
	anum.alignment = BoxContainer.ALIGNMENT_CENTER
	anum.add_theme_constant_override("separation", 8)
	anum.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_after_label = _num_label("…", 46, RED)
	anum.add_child(_after_label)
	_after_tri = _triangle(RED, Vector2(20, 14))
	_after_tri.modulate.a = 0.0
	anum.add_child(_after_tri)
	acol.add_child(anum)
	after.add_child(acol)
	var after_cup := _icon_rect(_tex(CUP_ICON), 84)
	_after_cup_mat = ShaderMaterial.new()
	_after_cup_mat.shader = DESAT_SHADER
	_after_cup_mat.set_shader_parameter("amount", 0.0)
	after_cup.material = _after_cup_mat
	after.add_child(after_cup)
	row.add_child(after)

	var divider := Control.new()
	divider.custom_minimum_size = Vector2(0, 12)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.draw.connect(_draw_divider.bind(divider, RED))
	v.add_child(divider)

	_pill = PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.32, 0.03, 0.05, 0.55)
	psb.set_border_width_all(2)
	psb.border_color = Color(RED, 0.75)
	psb.set_corner_radius_all(24)
	psb.content_margin_left = 26.0
	psb.content_margin_right = 26.0
	psb.content_margin_top = 4.0
	psb.content_margin_bottom = 4.0
	_pill.add_theme_stylebox_override("panel", psb)
	_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.modulate.a = 0.0
	var prow := HBoxContainer.new()
	prow.layout_direction = Control.LAYOUT_DIRECTION_LTR
	prow.add_theme_constant_override("separation", 10)
	prow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill_tri = _triangle(RED, Vector2(16, 12))
	prow.add_child(_pill_tri)
	_pill_label = _text_label("کاپ شما تغییری نکرد", 21, CREAM)
	prow.add_child(_pill_label)
	_pill.add_child(prow)
	v.add_child(_pill)

	_consolation_label = _num_label("", 22, GOLD)  # عدد دارد → Lalezar
	_consolation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_consolation_label.modulate.a = 0.0
	v.add_child(_consolation_label)
	return panel


# ============================ بینش‌ها ============================

## ردیفِ سه کارتِ کوچک زیرِ جوایز. جایش از اول نگه داشته می‌شود (INSIGHT_H)
## تا وقتی کارت‌ها دیرتر پر می‌شوند، بقیه‌ی صفحه جابه‌جا نشود.
func _build_insights() -> Control:
	_insights = HBoxContainer.new()
	_insights.name = "Insights"
	_insights.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_insights.alignment = BoxContainer.ALIGNMENT_CENTER
	_insights.add_theme_constant_override("separation", 12)
	_insights.custom_minimum_size = Vector2(0, INSIGHT_H)
	_insights.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# چپ‌به‌راست ساخته می‌شوند؛ ترتیبِ خواندن (راست‌به‌چپ): لحظه ← رنک ← هدف
	_chip_goal = _make_chip("Goal")
	_chip_rank = _make_chip("Rank")
	_chip_moment = _make_chip("Moment")
	return _insights


## یک کارت: آیکن، عنوانِ کوچک، متنِ اصلی و نوارِ باریک. تا پر نشده پنهان است.
func _make_chip(id: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.name = "Chip" + id
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.035, 0.86)
	sb.set_border_width_all(2)
	sb.border_color = Color(GOLD_EDGE, 0.55)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(CHIP_W, INSIGHT_H)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false

	var row := HBoxContainer.new()
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	# Lalezar هم فارسی دارد و هم ارقامش هم‌تراز است (V10)
	# عنوان و شمارنده جدا، تا متنِ فارسی و عددِ لاتین در یک خط به‌هم نریزند
	var head := HBoxContainer.new()
	head.layout_direction = Control.LAYOUT_DIRECTION_LTR
	head.add_theme_constant_override("separation", 6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var count := _num_label("", 17, GOLD)
	count.visible = false
	head.add_child(count)
	var title := _num_label("", 17, DIM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var value := _num_label("", 21, CREAM)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.clip_text = true
	value.custom_minimum_size = Vector2(CHIP_W - 100, 0)
	col.add_child(value)

	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_meta("r", 0.0)
	bar.set_meta("gold", false)
	bar.visible = false
	bar.draw.connect(_draw_mini_bar.bind(bar))
	col.add_child(bar)

	# آیکن سمتِ راست، کنارِ شروعِ متنِ فارسی
	var icon := _icon_rect(null, 58)
	row.add_child(icon)

	_insights.add_child(panel)
	return {"panel": panel, "sb": sb, "icon": icon, "title": title, "value": value, "bar": bar,
		"count": count}


## کارت را پر می‌کند و با پرشِ کوچک نشان می‌دهد.
##   gold      قابِ طلایی‌تر (رکورد، ارتقا، نزدیک به هدف)
##   from/to   نوار از کجا تا کجا پر شود (۰..۱)؛ to < ۰ یعنی بی‌نوار
func _show_chip(chip: Dictionary, tex: Texture2D, title: String, value: String,
		gold: bool, from: float = 0.0, to: float = -1.0, count: String = "") -> void:
	if chip.is_empty():
		return
	var panel: PanelContainer = chip["panel"]
	(chip["count"] as Label).text = count
	(chip["count"] as Label).visible = count != ""
	(chip["count"] as Label).add_theme_color_override("font_color", GOLD if gold else CREAM)
	(chip["icon"] as TextureRect).texture = tex
	(chip["icon"] as TextureRect).visible = tex != null
	(chip["title"] as Label).text = title
	(chip["title"] as Label).add_theme_color_override("font_color", GOLD if gold else DIM)
	(chip["value"] as Label).text = value
	var sb: StyleBoxFlat = chip["sb"]
	sb.border_color = Color(GOLD, 0.95) if gold else Color(GOLD_EDGE, 0.55)
	sb.shadow_color = Color(GOLD, 0.35) if gold else Color(0, 0, 0, 0)
	sb.shadow_size = 10 if gold else 0
	var bar: Control = chip["bar"]
	bar.visible = to >= 0.0
	bar.set_meta("gold", gold)
	bar.set_meta("r", from)
	bar.queue_redraw()

	var first := not panel.visible
	panel.visible = true
	if first:
		panel.modulate.a = 0.0
	panel.pivot_offset = Vector2(CHIP_W, INSIGHT_H) * 0.5
	var t := panel.create_tween()
	if first:
		panel.scale = Vector2(0.85, 0.85)
		t.tween_property(panel, "modulate:a", 1.0, 0.22)
		t.parallel().tween_property(panel, "scale", Vector2.ONE, 0.4) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if to >= 0.0:
		t.tween_method(func(v: float) -> void:
			bar.set_meta("r", v)
			bar.queue_redraw(), from, to, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if gold:
		t.tween_callback(func() -> void: UIFx.tap(panel))


func _psych_tex(name: String, fallback: String = "") -> Texture2D:
	var t := _tex(PSYCH + name + ".png")
	if t == null and fallback != "":
		t = _tex(fallback)
	return t


## پاداش و آمار هر دو رسیده‌اند: «بهترین لحظه» و «رنک»
func _fill_insights() -> void:
	var stats_node = Network.get("psych_match_stats")
	if stats_node != null and _stats.is_empty():
		var key := "draw"
		match outcome:
			Outcome.WIN: key = "win"
			Outcome.LOSE: key = "lose"
		_stats = stats_node.commit(key)
	_fill_moment()
	_fill_rank()
	_request_goals()


## E4 peak-end: یک لحظه‌ی خوب از همین مسابقه — حتی در باخت
func _fill_moment() -> void:
	var s := _stats
	var kills := int(s.get("kills", 0))
	var streak := int(s.get("best_streak", 0))
	var deaths := int(s.get("deaths", 0))
	var ws := int(s.get("win_streak", 0))
	var tracked := bool(s.get("tracked", false))
	var records: Array = s.get("records", [])
	var rec_tex := _psych_tex("result_new_record", CUP_ICON)
	var ws_tex := _psych_tex("result_win_streak", CUP_ICON)
	if records.has("kills"):
		_show_chip(_chip_moment, rec_tex, "رکورد جدید!", "%s کیل در یک مسابقه" % _fa(kills), true)
	elif records.has("streak"):
		_show_chip(_chip_moment, rec_tex, "رکورد جدید!", "%s کیل پشت‌سرهم" % _fa(streak), true)
	elif records.has("win_streak"):
		_show_chip(_chip_moment, ws_tex, "رکورد جدید!", "%s برد پیاپی" % _fa(ws), true)
	elif outcome == Outcome.WIN and ws >= 2:
		_show_chip(_chip_moment, ws_tex, "زنجیره‌ی برد", "%s برد پیاپی — ادامه بده!" % _fa(ws), true)
	elif streak >= 2:
		_show_chip(_chip_moment, _psych_tex("streak_double", CUP_ICON), "بهترین لحظه‌ی تو",
			"%s کیل پشت‌سرهم" % _fa(streak), false)
	elif kills > 0 and deaths == 0:
		_show_chip(_chip_moment, _psych_tex("streak_mvp", CUP_ICON), "بهترین لحظه‌ی تو",
			"%s کیل بدونِ حتی یک مرگ" % _fa(kills), true)
	elif kills > 0:
		_show_chip(_chip_moment, _psych_tex("streak_first_blood", CUP_ICON), "بهترین لحظه‌ی تو",
			"%s کیل در این مسابقه" % _fa(kills), false)
	elif tracked and deaths == 0:
		_show_chip(_chip_moment, _psych_tex("streak_mvp", CUP_ICON), "بهترین لحظه‌ی تو",
			"تا آخر زنده ماندی!", false)
	elif int(_reward.get("xp_delta", 0)) > 0:
		# هیچ آمارِ خاصی نبود: تجربه‌ای که واقعاً گرفت، به‌عنوانِ قدمِ رو به جلو
		var xp_tex := _psych_tex("result_level_up")
		if xp_tex == null:
			xp_tex = MissionArt.texture_for("xp")
		_show_chip(_chip_moment, xp_tex, "یک قدم جلوتر",
			"%s تجربه گرفتی" % _group(int(_reward.get("xp_delta", 0))), false)


## E5/E6/C9: رنک و فاصله تا بعدی — همیشه با جمله‌ی مثبت
func _fill_rank() -> void:
	if not _reward.has("trophies"):
		return
	var after := int(_reward.get("trophies", 0))
	var delta := int(_reward.get("trophy_delta", 0))
	var before := after - delta
	var ta := PsychProgress.tier_info(after)
	var tb := PsychProgress.tier_info(before)
	var badge := RankArt.texture_for(str(ta["id"]), str(ta["name"]))
	var r_to := 1.0
	var r_from := 1.0
	if int(ta["next_min"]) > 0:
		var span := float(maxi(int(ta["next_min"]) - int(ta["min"]), 1))
		r_to = PsychProgress.visual_ratio(after - int(ta["min"]), span)
		r_from = PsychProgress.visual_ratio(before - int(ta["min"]), span) if tb["index"] == ta["index"] else 0.0

	if int(ta["index"]) > int(tb["index"]):
		# E17 ارتقا: کنفتیِ کوتاه + لرزش
		_show_chip(_chip_rank, badge, "ارتقای رنک!", "به %s رسیدی" % str(ta["name"]), true, 0.0, 1.0)
		_celebrate(0.35)
		return
	if int(ta["next_min"]) <= 0:
		_show_chip(_chip_rank, badge, "رنک %s" % str(ta["name"]),
			"%s کاپ — اوجِ میدان" % _fa(after), true, 1.0, 1.0)
		return
	var left := int(ta["next_min"]) - after
	var win_t := _mode_win_trophies()
	var next_name := str(ta["next_name"])
	if outcome == Outcome.DRAW:
		var shield := _psych_tex("result_rank_shield")
		_show_chip(_chip_rank, shield if shield != null else badge, "کاپت کم نشد", "%s کاپ تا %s" % [_fa(left), next_name], false, r_from, r_to)
	elif win_t > 0 and left <= win_t:
		# E6 قابِ مثبت: «یه برد تا ارتقا» به‌جای «کاپ از دست دادی»
		_show_chip(_chip_rank, badge, "فقط یه برد تا %s!" % next_name,
			"%s کاپ مونده" % _fa(left), true, r_from, r_to)
	elif PsychProgress.is_near(after - int(ta["min"]), int(ta["next_min"]) - int(ta["min"])):
		_show_chip(_chip_rank, badge, "تا رنک %s" % next_name,
			"فقط %s کاپ مونده!" % _fa(left), true, r_from, r_to)
	else:
		_show_chip(_chip_rank, badge, "تا رنک %s" % next_name,
			"%s کاپ مونده" % _fa(left), false, r_from, r_to)


## کاپِ بردِ همین حالت (از /game_modes که Global نگه داشته)؛ ۰ = نامعلوم
func _mode_win_trophies() -> int:
	var m: Dictionary = Global.selected_mode_data
	var mode_id := str(_reward.get("mode_id", ""))
	if m.is_empty() or (mode_id != "" and str(m.get("mode_id", "")) != mode_id):
		return 0
	return int(m.get("win_trophies", 0))


## E7 زیگارنیک: نزدیک‌ترین ماموریت/چالشِ ناتمام. سرور پیشرفتِ این مسابقه
## را همزمان با پاداش می‌نویسد، پس کمی بعد از رسیدنِ پاداش پرسیده می‌شود.
func _request_goals() -> void:
	if Global.offline_mode or str(Global.my_username).is_empty() or _goal_http != null:
		return
	_goal_http = HTTPRequest.new()
	_goal_http.timeout = 6.0
	add_child(_goal_http)
	_season_http = HTTPRequest.new()
	_season_http.timeout = 6.0
	add_child(_season_http)
	_goal_http.request_completed.connect(_on_goal_data.bind("missions"))
	_season_http.request_completed.connect(_on_goal_data.bind("challenges"))
	var user := str(Global.my_username).uri_encode()
	var t := create_tween()
	t.tween_interval(0.6)
	t.tween_callback(func() -> void:
		_goal_pending = 0
		if _goal_http.request("%s/missions/daily?username=%s" % [Global.SERVER_BASE, user],
				Global.auth_headers()) == OK:
			_goal_pending += 1
		if _season_http.request("%s/season/pass?username=%s" % [Global.SERVER_BASE, user],
				Global.auth_headers()) == OK:
			_goal_pending += 1)


func _on_goal_data(result: int, code: int, _h: PackedStringArray, body: PackedByteArray,
		kind: String) -> void:
	_goal_pending -= 1
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data) == TYPE_DICTIONARY:
			var list = data.get(kind, [])
			if list is Array:
				if kind == "missions":
					_goal_missions = list
				else:
					_goal_challenges = list
	if _goal_pending <= 0:
		_fill_goal()


func _fill_goal() -> void:
	var ready := PsychProgress.ready_count(_goal_missions) + PsychProgress.ready_count(_goal_challenges)
	var goal := PsychProgress.closest_goal(_goal_missions, _goal_challenges)
	if goal.is_empty():
		if ready > 0:
			_show_chip(_chip_goal, _psych_tex("chest_closed", COIN_ICON), "جایزه‌ی آماده",
				"%s جایزه در لابی منتظرته" % MissionArt.fa_number(ready), true)
		return
	var target := maxi(int(goal.get("target", 1)), 1)
	var progress := clampi(int(goal.get("progress", 0)), 0, target)
	var near := PsychProgress.is_near(progress, target)
	# C8 سه افق: این مسابقه (بهترین لحظه) / روزانه / فصل
	var title := "ماموریت روزانه" if str(goal.get("horizon", "")) == "daily" else "چالش فصل"
	if near:
		title = PsychProgress.remaining_text(progress, target)
	var tex := MissionArt.texture_for(str(goal.get("icon", "")))
	if tex == null:
		tex = _psych_tex("chest_closed", COIN_ICON)
	_show_chip(_chip_goal, tex, title, str(goal.get("title", "")), near,
		0.0, PsychProgress.visual_ratio(progress, target), "%d/%d" % [progress, target])


## E17: کنفتیِ طلاییِ کوتاه بالای نشان (ارتقای رنک یا سطح) — فقط یک بار
func _celebrate(delay: float) -> void:
	if has_meta("celebrated"):
		return
	set_meta("celebrated", true)
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_callback(func() -> void:
		var c := CONFETTI.new()
		_stage.add_child(c)
		c.burst(Vector2(_stage.size.x * 0.5, _stage.size.y * 0.12), minf(_stage.size.x * 0.6, 760.0))
		_vibrate(60))


## «—◆ جوایز دریافت شد ◆—»
func _make_header(text: String, colour: Color) -> Control:
	var h := HBoxContainer.new()
	h.layout_direction = Control.LAYOUT_DIRECTION_LTR
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for left in [true, false]:
		var o := Control.new()
		o.custom_minimum_size = Vector2(170, 22)
		o.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		o.mouse_filter = Control.MOUSE_FILTER_IGNORE
		o.draw.connect(_draw_ornament.bind(o, colour, left))
		# از سمتِ متن به بیرون کشیده می‌شود
		o.pivot_offset = Vector2(170 if left else 0, 11)
		_ornaments.append(o)
		h.add_child(o)
		if left:
			h.add_child(_text_label(text, 24, CREAM))
	return h


func _make_wing(path: String, wing_size: Vector2, root: Vector2, at: Vector2) -> TextureRect:
	var w := TextureRect.new()
	w.texture = _tex(path)
	w.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	w.stretch_mode = TextureRect.STRETCH_SCALE
	w.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	w.size = wing_size
	w.pivot_offset = wing_size * root
	w.position = at - w.pivot_offset
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return w


func _make_sparks(win: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.local_coords = true
	p.amount = 22 if win else 18
	p.lifetime = 2.4
	p.texture = _radial(Color.WHITE, 1.0, 32)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(200, 60)
	p.direction = Vector2(0, -1)
	p.spread = 30.0
	p.gravity = Vector2(0, -18)
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 55.0
	p.scale_amount_min = 0.18
	p.scale_amount_max = 0.5
	var ramp := Gradient.new()
	var c := Color(1.0, 0.86, 0.45) if win else Color(1.0, 0.32, 0.18)
	ramp.set_color(0, Color(c, 0.0))
	ramp.set_color(1, Color(c, 0.0))
	ramp.add_point(0.2, Color(c, 1.0))
	ramp.add_point(0.7, Color(c, 0.6))
	p.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	return p


## یک کارتِ جایزه: قاب، هاله، آیکن، عدد و عنوان — و نوارِ براقی که رد می‌شود
func _make_card(item: Dictionary) -> Control:
	var card := Control.new()
	card.custom_minimum_size = CARD
	card.pivot_offset = CARD * 0.5
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow: Color = item["glow"]

	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.075, 0.94)
	sb.set_border_width_all(2)
	sb.border_color = Color(GOLD_EDGE, 0.95)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(glow, 0.3)
	sb.shadow_size = 10
	panel.add_theme_stylebox_override("panel", sb)
	card.add_child(panel)

	var halo := TextureRect.new()
	halo.texture = _radial(glow, 0.55)
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.stretch_mode = TextureRect.STRETCH_SCALE
	halo.size = Vector2(CARD.x - 8, 120)
	halo.position = Vector2(4, 4)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(halo)

	var icon := _card_icon(item)
	icon.position = Vector2((CARD.x - icon.size.x) * 0.5, 12.0 + (ICON - icon.size.y) * 0.5)
	icon.pivot_offset = icon.size * 0.5
	card.add_child(icon)

	var value := _num_label(str(item["prefix"]) + _group(int(item["from"])), 36, Color.WHITE)
	value.add_theme_constant_override("outline_size", 6)
	value.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.size = Vector2(CARD.x, 46)
	value.position = Vector2(0, 104)
	value.pivot_offset = value.size * 0.5
	card.add_child(value)

	var caption := _text_label(str(item["caption"]), 19, CREAM)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.size = Vector2(CARD.x, 32)
	caption.position = Vector2(0, 146)
	card.add_child(caption)

	var shine := Control.new()
	shine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.set_meta("t", -1.0)
	shine.draw.connect(_draw_shine.bind(shine, false))
	card.add_child(shine)

	card.set_meta("icon", icon)
	card.set_meta("value", value)
	card.set_meta("shine", shine)
	return card


func _card_icon(item: Dictionary) -> Control:
	match str(item["kind"]):
		"cup":
			return _icon_rect(_tex(CUP_ICON), ICON)
		"coin":
			return _icon_rect(_tex(COIN_ICON), ICON * 0.9)
		"xp":
			return _hex_badge("EXP", Color(0.62, 0.50, 1.0), Color(0.14, 0.36, 0.98),
				Color(0.78, 0.92, 1.0), Color(0.07, 0.06, 0.24, 0.95))
		_:
			return _hex_badge(str(item["level"]), Color(1.0, 0.9, 0.5), Color(0.82, 0.5, 0.08),
				Color(1.0, 0.95, 0.7), Color(0.26, 0.14, 0.02, 0.95))


func _hex_badge(text: String, top: Color, bottom: Color, edge: Color, inner: Color) -> Control:
	var c := Control.new()
	c.size = Vector2(ICON, ICON)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_hex_badge.bind(c, text, top, bottom, edge, inner))
	return c


## دکمه‌ی پایین: طلایی («ادامه») یا سرمه‌ای با آیکنِ خانه («بازگشت به لابی»)
func _make_button(text: String, navy: bool, action: Callable,
		min_size := Vector2.ZERO) -> Button:
	var b := Button.new()
	b.name = "LeaveButton" if action == _on_leave_pressed else "ReplayButton"
	b.custom_minimum_size = min_size if min_size != Vector2.ZERO else Vector2(340 if navy else 300, 70)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())

	var plate := Control.new()
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.set_meta("t", -1.0)
	plate.draw.connect(_draw_button_plate.bind(plate, b, navy))
	b.add_child(plate)
	b.set_meta("plate", plate)
	# برقِ گاه‌به‌گاه فقط روی دکمه‌ی اصلی (طلایی) — V5
	if not navy or _button_plate == null:
		_button_plate = plate

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.layout_direction = Control.LAYOUT_DIRECTION_LTR
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	if navy:
		var home := Control.new()
		home.custom_minimum_size = Vector2(30, 30)
		home.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		home.mouse_filter = Control.MOUSE_FILTER_IGNORE
		home.draw.connect(_draw_home.bind(home))
		row.add_child(home)
	var l := _text_label(text, 28 if navy else 32, Color.WHITE if navy else BROWN)
	if not navy:
		l.add_theme_color_override("font_shadow_color", Color(1, 0.95, 0.7, 0.45))
	row.add_child(l)

	# حالتِ «فشرده»: تیره‌تر شدنِ قاب و جمع شدنِ کوتاه (hover نداریم)
	b.button_down.connect(func() -> void:
		plate.queue_redraw()
		UIFx.press_scale(b, true))
	b.button_up.connect(func() -> void:
		plate.queue_redraw()
		UIFx.press_scale(b, false))
	b.pressed.connect(action)
	return b


# ============================ انیمیشن ============================

func _play_intro() -> void:
	_backdrop_mat.set_shader_parameter("fade", 0.0)
	_backdrop_mat.set_shader_parameter("blur_px", BLUR_START)
	_backdrop_mat.set_shader_parameter("art_lod", ART_LOD_START)
	_backdrop_mat.set_shader_parameter("art_alpha", 1.0 if _backdrop_mat.get_shader_parameter("art_tex") != null else 0.0)

	# پس‌زمینه: سریع تا «کاملاً تار»، بعد هم‌زمان با بالا آمدنِ منو نیمه‌شفاف
	var bg := create_tween()
	bg.tween_property(_backdrop_mat, "shader_parameter/fade", 1.0, 0.18)
	bg.tween_callback(_hide_world)
	var settle := create_tween().set_parallel()
	var ease_bg := func(t: PropertyTweener) -> void:
		t.set_delay(0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ease_bg.call(settle.tween_property(_backdrop_mat, "shader_parameter/blur_px", BLUR_END, SETTLE_TIME))
	ease_bg.call(settle.tween_property(_backdrop_mat, "shader_parameter/art_lod", ART_LOD_END, SETTLE_TIME))
	if _backdrop_mat.get_shader_parameter("art_tex") != null:
		ease_bg.call(settle.tween_property(_backdrop_mat, "shader_parameter/art_alpha", ART_ALPHA_END, SETTLE_TIME))

	# منو از پایینِ صفحه
	_sliding = true
	_slider.position.y = _stage.size.y
	var slide := create_tween()
	slide.tween_interval(SLIDE_DELAY)
	slide.tween_property(_slider, "position:y", 0.0, SLIDE_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide.tween_callback(_on_slide_done)


## یک عکس از صفحه، همان لحظه‌ی باز شدن — زمینه‌ی تاریِ پس‌زمینه.
##
## قبلاً شیدر هر فریم hint_screen_texture می‌خواند: کپیِ کاملِ صفحه و
## ساختنِ mipmapش در هر فریم، با دنیایی که زیرش کامل کشیده می‌شد. حالا
## یک بار عکس گرفته می‌شود (هنوز صفحه‌ی نتیجه کشیده نشده، پس فقط زمینِ بازی
## است)، نصف می‌شود (تاری هیچ‌وقت سطحِ ۰ را نمی‌خواند) و mipmap می‌گیرد.
## اگر به هر دلیلی عکس نیامد، یک زمینه‌ی تیره‌ی یکدست جایش می‌نشیند.
func _capture_world() -> void:
	var img: Image = null
	var vt := get_viewport().get_texture()
	if vt != null:
		img = vt.get_image()
	var lod_offset := 1.0
	if img == null or img.is_empty():
		img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.05, 0.045, 0.06))
		lod_offset = 0.0
	else:
		img.resize(maxi(int(img.get_width() * 0.5), 1), maxi(int(img.get_height() * 0.5), 1),
			Image.INTERPOLATE_BILINEAR)
	img.generate_mipmaps()
	_backdrop_mat.set_shader_parameter("world_tex", ImageTexture.create_from_image(img))
	_backdrop_mat.set_shader_parameter("world_lod_offset", lod_offset)


## پس‌زمینه حالا کاملاً پوشاست (fade = ۱) و تاری از عکس می‌آید، پس دنیای
## زیرش — نورها، دیوارها، مشعل‌ها — دیگر لازم نیست هر فریم کشیده شود.
## فقط خودِ نودِ دنیا پنهان می‌شود؛ CanvasLayerها (همین صفحه و HUD) از
## پنهان شدنِ والدشان اثر نمی‌گیرند و منطقِ بازی هم مثلِ قبل اجرا می‌شود.
func _hide_world() -> void:
	var scene := get_tree().current_scene
	if scene is CanvasItem and (scene as CanvasItem).visible:
		_hidden_world = scene as CanvasItem
		_hidden_world.visible = false


## منو کاملاً نشست: حالا نوبتِ بال‌هاست، بعد جایزه‌ها و دکمه
func _on_slide_done() -> void:
	_sliding = false
	_slider.position.y = 0.0
	match outcome:
		# مساوی هم بال‌هایش بالا می‌رود: بردِ مشترک است، نه «هیچی»
		Outcome.WIN, Outcome.DRAW: _wings_rise()
		Outcome.LOSE: _wings_drop()
	_impact()

	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_callback(_reveal_body)
	t.tween_interval(0.55 if _body != null else 0.1)
	t.tween_callback(_reveal_button)


## پیروزی: بال‌ها از حالتِ جمع رو به بالا باز می‌شوند (کمی جلوتر می‌روند و برمی‌گردند)
func _wings_rise() -> void:
	var t := create_tween().set_parallel()
	t.tween_property(_wing_l, "rotation_degrees", 0.0, 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_wing_r, "rotation_degrees", 0.0, 0.7) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(_wings_idle.bind(0.0, 3.0))


## شکست: بال‌ها سنگین رو به پایین می‌افتند و کمی بالا-پایین می‌پرند
func _wings_drop() -> void:
	var t := create_tween().set_parallel()
	t.tween_property(_wing_l, "rotation_degrees", WING_DROOP, 0.9) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_property(_wing_r, "rotation_degrees", -WING_DROOP, 0.9) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(_wings_idle.bind(WING_DROOP, 1.6))


## تکانِ آرامِ همیشگی دورِ زاویه‌ی rest (برای بالِ چپ؛ راست قرینه)
func _wings_idle(rest: float, amp: float) -> void:
	for w in [_wing_l, _wing_r]:
		var sgn := 1.0 if w == _wing_l else -1.0
		var t := (w as Node).create_tween().set_loops()
		t.tween_property(w, "rotation_degrees", (rest + amp) * sgn, 1.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(w, "rotation_degrees", rest * sgn, 1.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## لحظه‌ی «نشستن»: ضربه روی نشان، هاله و پرتوها، جرقه‌ها و لرزشِ کوتاه
func _impact() -> void:
	var win := _is_win_look()
	var c := create_tween()
	if win:
		c.tween_property(_cup, "scale", Vector2(1.12, 1.12), 0.14) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		c.tween_property(_cup, "scale", Vector2.ONE, 0.45) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	else:
		# عقابِ ترک‌خورده تکان می‌خورد، همان لحظه‌ای که بال‌ها می‌افتند
		var home := _cup.position
		for k in 6:
			var dx := (7.0 - k) * (1.0 if k % 2 == 0 else -1.0)
			c.tween_property(_cup, "position", home + Vector2(dx, absf(dx) * 0.3), 0.045)
		c.tween_property(_cup, "position", home, 0.06)

	var g := _glow.create_tween()
	g.tween_property(_glow, "modulate:a", 1.0, 0.12)
	g.tween_property(_glow, "modulate:a", 0.7, 0.6)
	g.tween_callback(func() -> void:
		var loop := _glow.create_tween().set_loops()
		loop.tween_property(_glow, "modulate:a", 1.0, 1.6).set_trans(Tween.TRANS_SINE)
		loop.tween_property(_glow, "modulate:a", 0.7, 1.6).set_trans(Tween.TRANS_SINE))

	_rays.create_tween().tween_property(_rays, "modulate:a", 1.0 if win else 0.55, 0.6)
	var spin := _rays.create_tween().set_loops()
	spin.tween_property(_rays, "rotation", TAU, 48.0).from(0.0)
	_sparks.emitting = true

	if win:
		var s := _title.create_tween().set_loops()
		s.tween_property(_title_mat, "shader_parameter/shine", 1.5, 0.9).from(-0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		s.tween_interval(2.6)
	else:
		var f := _title.create_tween()
		f.tween_property(_title, "modulate", Color(1.5, 0.75, 0.75), 0.06)
		f.tween_property(_title, "modulate", Color.WHITE, 0.4)
	_vibrate(45 if win else 120)


func _reveal_body() -> void:
	_body_shown = true
	if _body != null:
		_body.pivot_offset = _body.size * 0.5
		var t := _body.create_tween().set_parallel()
		t.tween_property(_body, "modulate:a", 1.0, 0.3)
		if outcome == Outcome.LOSE:
			_body.scale = Vector2(0.94, 0.94)
			t.tween_property(_body, "scale", Vector2.ONE, 0.4) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for o in _ornaments:
		o.scale = Vector2(0.0, 1.0)
		o.create_tween().tween_property(o, "scale", Vector2.ONE, 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _placeholder != null:
		var p := _placeholder.create_tween().set_loops()
		p.tween_property(_placeholder, "modulate:a", 0.45, 0.6)
		p.tween_property(_placeholder, "modulate:a", 1.0, 0.6)
	if _arrow != null:
		_arrow.pivot_offset = _arrow.custom_minimum_size * 0.5
		var a := _arrow.create_tween().set_loops()
		a.tween_property(_arrow, "scale", Vector2(1.15, 1.15), 0.5).set_trans(Tween.TRANS_SINE)
		a.tween_property(_arrow, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)
	if not _reward.is_empty() and not _reward_applied:
		_apply_reward()
	# اگر پاداش اصلاً نرسید، «بهترین لحظه» و هدف‌ها بدونِ آن هم بیایند
	var fb := create_tween()
	fb.tween_interval(4.0)
	fb.tween_callback(func() -> void:
		if not _reward_applied:
			_fill_insights())


func _reveal_button() -> void:
	var buttons: Array[Button] = [_button]
	if _replay_button != null:
		buttons.append(_replay_button)
	for b in buttons:
		b.pivot_offset = b.size * 0.5
		b.scale = Vector2(0.85, 0.85)
		var t := b.create_tween().set_parallel()
		t.tween_property(b, "modulate:a", 1.0, 0.25)
		t.tween_property(b, "scale", Vector2.ONE, 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.chain().tween_callback(func() -> void:
			b.disabled = false
			_ready_for_back = true)
	# برقِ گاه‌به‌گاه روی دکمه‌ی اصلی تا چشم به آن بیفتد
	var s := _button_plate.create_tween().set_loops()
	s.tween_interval(1.4)
	s.tween_method(_set_shine.bind(_button_plate), -0.3, 1.3, 0.7)
	# V5 پالسِ ملایمِ دکمه‌ی «دوباره» (فقط مقیاسِ خیلی کم، نه چشمک)
	if _replay_button != null:
		var p := _replay_button.create_tween().set_loops()
		p.tween_interval(0.6)
		p.tween_property(_replay_button, "scale", Vector2(1.04, 1.04), 0.6).set_trans(Tween.TRANS_SINE)
		p.tween_property(_replay_button, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
		_replay_button.set_meta("pulse", p)
		_replay_button.button_down.connect(func() -> void:
			if p.is_valid():
				p.kill())


func _apply_reward() -> void:
	_reward_applied = true
	match outcome:
		Outcome.WIN, Outcome.DRAW: _fill_cards()
		Outcome.LOSE: _animate_trophies()
	# بینش‌ها کمی بعد از جوایز، تا چشم اول پاداش را ببیند
	var t := create_tween()
	t.tween_interval(0.7)
	t.tween_callback(_fill_insights)


## همان پاداش‌های سرور: کاپ، سکه، تجربه — و اگر سطح بالا رفت، سطحِ تازه
func _reward_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var t := int(_reward.get("trophy_delta", 0))
	var c := int(_reward.get("coin_delta", 0))
	var x := int(_reward.get("xp_delta", 0))
	if t != 0:
		items.append({"kind": "cup", "value": t, "from": 0, "prefix": "+" if t > 0 else "-",
			"caption": "جام قهرمانی", "glow": GOLD})
	if c != 0:
		items.append({"kind": "coin", "value": c, "from": 0, "prefix": "+" if c > 0 else "-",
			"caption": "سکه", "glow": GOLD})
	if x != 0:
		items.append({"kind": "xp", "value": x, "from": 0, "prefix": "+",
			"caption": "تجربه بازیکن", "glow": Color(0.45, 0.45, 1.0)})
	if bool(_reward.get("level_up", false)):
		var lv := int(_reward.get("level", 0))
		items.append({"kind": "level", "value": 1, "from": 0, "prefix": "+", "level": lv,
			"caption": "سطح جدید", "glow": Color(1.0, 0.7, 0.2)})
	return items


func _fill_cards() -> void:
	var items := _reward_items()
	if items.is_empty():
		_placeholder.text = "این بار جایزه‌ای ثبت نشد"
		return
	_placeholder.queue_free()
	_placeholder = null
	var cards: Array[Control] = []
	for it in items:
		var card := _make_card(it)
		card.modulate.a = 0.0
		card.scale = Vector2(0.5, 0.5)
		_cards_row.add_child(card)
		cards.append(card)
	# راست‌به‌چپ، به ترتیبِ خواندن
	for i in cards.size():
		var k := cards.size() - 1 - i
		_pop_card(cards[k], items[k], 0.13 * i)
	# E17 سطحِ تازه: جشنِ کوتاه بعد از نشستنِ کارت‌ها
	if bool(_reward.get("level_up", false)):
		_celebrate(0.13 * cards.size() + 0.5)


func _pop_card(card: Control, item: Dictionary, delay: float) -> void:
	var value: Label = card.get_meta("value")
	var icon: Control = card.get_meta("icon")
	var shine: Control = card.get_meta("shine")
	var t := card.create_tween()
	t.tween_interval(delay)
	t.tween_property(card, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(card, "modulate:a", 1.0, 0.18)
	t.tween_method(_set_count.bind(value, str(item["prefix"])),
		float(item["from"]), float(absi(int(item["value"]))), 0.8) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_method(_set_shine.bind(shine), -0.3, 1.3, 0.6)
	t.tween_callback(func() -> void:
		UIFx.tap(value)
		var bob := icon.create_tween().set_loops()
		bob.tween_property(icon, "scale", Vector2(1.06, 1.06), 1.1).set_trans(Tween.TRANS_SINE)
		bob.tween_property(icon, "scale", Vector2.ONE, 1.1).set_trans(Tween.TRANS_SINE))


## شکست: عددِ «بعد» از کاپِ قبلی پایین می‌آید و جامش هم‌زمان نقره‌ای می‌شود
func _animate_trophies() -> void:
	var delta := int(_reward.get("trophy_delta", 0))
	var after := int(_reward.get("trophies", -1))
	var lost := absi(mini(delta, 0))
	var before := after - delta
	if after >= 0:
		_before_label.text = _group(before)
		_after_label.text = _group(before)
	else:
		_before_label.text = "—"
		_after_label.text = "—"
	if lost > 0:
		_pill_label.text = "کاپ شما %d واحد کاهش یافت" % lost
	else:
		_pill_label.text = "کاپ شما تغییری نکرد"
		_pill_tri.visible = false
	var coins := int(_reward.get("coin_delta", 0))
	var xp := int(_reward.get("xp_delta", 0))
	if _consolation_label != null and (coins > 0 or xp > 0):
		# E4 شمارشِ طلایی حتی در باخت: «+N سکه · +M تجربه» از صفر بالا می‌رود
		_set_consolation(0.0, coins, xp)
		var ct := _consolation_label.create_tween()
		ct.tween_interval(0.9)
		ct.tween_property(_consolation_label, "modulate:a", 1.0, 0.3)
		ct.tween_method(_set_consolation.bind(coins, xp), 0.0, 1.0, 0.8) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		ct.tween_callback(func() -> void: UIFx.tap(_consolation_label))

	var t := create_tween()
	t.tween_interval(0.25)
	if after >= 0 and before != after:
		t.tween_method(_set_count.bind(_after_label, ""), float(before), float(after), 1.0) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_after_cup_mat, "shader_parameter/amount", 1.0, 1.0)
	t.tween_callback(func() -> void:
		if lost > 0:
			_after_tri.modulate.a = 1.0
			_after_tri.pivot_offset = _after_tri.size * 0.5
			_after_tri.scale = Vector2(1.8, 1.8)
			_after_tri.create_tween().tween_property(_after_tri, "scale", Vector2.ONE, 0.35) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			UIFx.tap(_after_label)
			_vibrate(40)
		_pill.pivot_offset = _pill.size * 0.5
		_pill.scale = Vector2(0.8, 0.8))
	t.tween_property(_pill, "modulate:a", 1.0, 0.3)
	t.parallel().tween_property(_pill, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_consolation(k: float, coins: int, xp: int) -> void:
	var parts: PackedStringArray = []
	if coins > 0:
		parts.append("+%s سکه" % _group(roundi(coins * k)))
	if xp > 0:
		parts.append("+%s تجربه" % _group(roundi(xp * k)))
	_consolation_label.text = " · ".join(parts)


func _set_count(v: float, label: Label, prefix: String) -> void:
	label.text = prefix + _group(roundi(v))


func _set_shine(v: float, c: Control) -> void:
	c.set_meta("t", v)
	c.queue_redraw()


func _on_leave_pressed() -> void:
	_leave_to(_button, LOBBY_SCENE)


## E5 «دوباره»: مستقیم به صفِ همان حالت، بدونِ رفتن به لابی
func _on_replay_pressed() -> void:
	_leave_to(_replay_button, REPLAY_SCENE)


func _leave_to(b: Button, scene: String) -> void:
	if _leaving or b == null or b.disabled:
		return
	_leaving = true
	_ready_for_back = false
	var pulse: Tween = b.get_meta("pulse") if b.has_meta("pulse") else null
	if pulse != null and pulse.is_valid():
		pulse.kill()
	UIFx.press(b, func() -> void:
		# سرور هم بداند از زمین بیرون آمدیم (سوکت برای منو باز می‌ماند)
		if not Global.offline_mode:
			Network.send_leave_arena()
		get_tree().change_scene_to_file(scene))


## «دوباره» فقط آنلاین معنی دارد (صفِ مسابقه)؛ بازیِ آفلاین همان یک دکمه را دارد
func _can_replay() -> bool:
	return not Global.offline_mode and ResourceLoader.exists(REPLAY_SCENE)


# ============================ چیدمان ============================

func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.y <= 0.0:
		return
	var s := clampf(vp.y / DESIGN_H, 0.4, 4.0)
	_stage.position = Vector2.ZERO
	_stage.scale = Vector2(s, s)
	_stage.size = vp / s
	_slider.size = _stage.size
	if not _sliding:
		_slider.position = Vector2.ZERO
	var ins := _safe_insets() / s
	_margin.add_theme_constant_override("margin_left", int(maxf(ins.x, 24.0)))
	_margin.add_theme_constant_override("margin_top", int(maxf(ins.y, 10.0)))
	_margin.add_theme_constant_override("margin_right", int(maxf(ins.z, 24.0)))
	_margin.add_theme_constant_override("margin_bottom", int(maxf(ins.w, 14.0)))
	_backdrop_mat.set_shader_parameter("rect_size", vp)
	_fit_emblem(_stage.size.y - maxf(ins.y, 10.0) - maxf(ins.w, 14.0))


## نشانِ بالا تا جایی کوچک می‌شود که بقیه‌ی ستون (جوایز، بینش‌ها، دکمه‌ها)
## در ارتفاعِ موجود جا شود. ارتفاعِ طراحی ثابت است، پس فقط ناچ اثر دارد.
func _fit_emblem(avail: float) -> void:
	if _column == null or _emblem_holder == null:
		return
	var rest := _column.get_combined_minimum_size().y - _emblem_holder.custom_minimum_size.y
	var k := clampf((avail - rest) / EMBLEM.y, 0.55, 1.0)
	_emblem.scale = Vector2(k, k)
	_emblem_holder.custom_minimum_size = EMBLEM * k


## فاصله‌ی ناچ و لبه‌های خمیده (چپ، بالا، راست، پایین) به پیکسلِ viewport.
## فقط روی گوشی؛ روی PC پنجره هر جای صفحه می‌تواند باشد.
func _safe_insets() -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var win_pos := DisplayServer.window_get_position()
	var win_size := DisplayServer.window_get_size()
	if safe.size.x <= 0 or win_size.x <= 0:
		return Vector4.ZERO
	var k := get_viewport().get_visible_rect().size / Vector2(win_size)
	return Vector4(
		maxf(0.0, float(safe.position.x - win_pos.x)) * k.x,
		maxf(0.0, float(safe.position.y - win_pos.y)) * k.y,
		maxf(0.0, float(win_pos.x + win_size.x - safe.end.x)) * k.x,
		maxf(0.0, float(win_pos.y + win_size.y - safe.end.y)) * k.y)


# ============================ نقاشی ============================

func _draw_rays(c: Control, colour: Color) -> void:
	var ctr := c.size * 0.5
	var r := c.size.x * 0.5
	const N := 18
	for i in N:
		var a := TAU * i / N
		var half := 0.06 if i % 2 == 0 else 0.035
		c.draw_polygon(PackedVector2Array([ctr,
			ctr + Vector2.from_angle(a - half) * r, ctr + Vector2.from_angle(a + half) * r]),
			PackedColorArray([Color(colour, 0.2), Color(colour, 0.0), Color(colour, 0.0)]))


func _draw_title_plate(c: Control, edge: Color, win: bool) -> void:
	var pts := _plate_points(c.size, 0.5)
	var top := Color(0.12, 0.08, 0.03, 0.9) if win else Color(0.14, 0.03, 0.04, 0.9)
	var mid := Color(0.05, 0.035, 0.03, 0.92)
	var bot := Color(0.02, 0.015, 0.015, 0.94)
	c.draw_polygon(pts, PackedColorArray([top, top, mid, bot, bot, mid]))
	_outline(c, pts, Color(edge, 0.95), 2.0)
	var inner := Geometry2D.offset_polygon(pts, -6.0)
	if not inner.is_empty():
		_outline(c, inner[0], Color(edge, 0.35), 1.2)
	var h := c.size.y
	_diamond(c, Vector2(-10, h * 0.5), 7.0, edge)
	_diamond(c, Vector2(c.size.x + 10, h * 0.5), 7.0, edge)


## «—◆» کنارِ عنوانِ بخش؛ left یعنی سمتِ چپِ متن (سرِ درخشانش سمتِ راست)
func _draw_ornament(c: Control, colour: Color, left: bool) -> void:
	var w := c.size.x
	var y := c.size.y * 0.5
	var near := w - 10.0 if left else 10.0
	var far := 0.0 if left else w
	c.draw_polygon(PackedVector2Array([
		Vector2(near, y - 1.5), Vector2(far, y - 0.5), Vector2(far, y + 0.5), Vector2(near, y + 1.5)]),
		PackedColorArray([colour, Color(colour, 0.0), Color(colour, 0.0), colour]))
	_diamond(c, Vector2(near, y), 6.0, colour)
	_diamond(c, Vector2(lerpf(near, far, 0.45), y), 3.5, Color(colour, 0.8))


func _draw_divider(c: Control, colour: Color) -> void:
	var w := c.size.x
	var y := c.size.y * 0.5
	var cx := w * 0.5
	for dir in [-1.0, 1.0]:
		var end: float = cx + dir * w * 0.45
		c.draw_polygon(PackedVector2Array([
			Vector2(cx, y - 1.2), Vector2(end, y - 0.4), Vector2(end, y + 0.4), Vector2(cx, y + 1.2)]),
			PackedColorArray([Color(colour, 0.9), Color(colour, 0.0), Color(colour, 0.0), Color(colour, 0.9)]))
	_diamond(c, Vector2(cx, y), 5.0, colour)


func _draw_chevron(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	for pass_i in 2:
		var off := -14.0 if pass_i == 0 else 0.0
		var col := Color(RED, 0.35) if pass_i == 0 else RED
		var pts := PackedVector2Array([
			Vector2(off + w * 0.15, 0), Vector2(off + w * 0.5, 0), Vector2(off + w * 0.95, h * 0.5),
			Vector2(off + w * 0.5, h), Vector2(off + w * 0.15, h), Vector2(off + w * 0.6, h * 0.5)])
		c.draw_colored_polygon(pts, col)


func _draw_hex_badge(c: Control, text: String, top: Color, bottom: Color, edge: Color, inner: Color) -> void:
	var s := c.size
	var ctr := s * 0.5
	var r := s.x * 0.47
	var outer := PackedVector2Array()
	var cols := PackedColorArray()
	var core := PackedVector2Array()
	for i in 6:
		var p := ctr + Vector2.from_angle(deg_to_rad(60.0 * i - 90.0)) * r
		outer.append(p)
		cols.append(top.lerp(bottom, (p.y - (ctr.y - r)) / (2.0 * r)))
		core.append(ctr + (p - ctr) * 0.74)
	c.draw_polygon(outer, cols)
	_outline(c, outer, edge, 3.0)
	c.draw_colored_polygon(core, inner)
	_outline(c, core, Color(edge, 0.55), 1.5)
	var fs := int(s.x * (0.28 if text.length() > 2 else 0.4))
	var base := ctr.y + (FONT_NUM.get_ascent(fs) - FONT_NUM.get_descent(fs)) * 0.5
	c.draw_string_outline(FONT_NUM, Vector2(0, base), text, HORIZONTAL_ALIGNMENT_CENTER, s.x, fs, 5, Color(0, 0, 0, 0.6))
	c.draw_string(FONT_NUM, Vector2(0, base), text, HORIZONTAL_ALIGNMENT_CENTER, s.x, fs, Color.WHITE)


func _draw_button_plate(c: Control, b: Button, navy: bool) -> void:
	var pts := _plate_points(c.size, 0.42)
	var down := b.get_draw_mode() == BaseButton.DRAW_PRESSED
	var k := 0.78 if down else 1.0
	var top: Color
	var mid: Color
	var bot: Color
	var edge: Color
	if navy:
		top = Color(0.14, 0.2, 0.34)
		mid = Color(0.08, 0.11, 0.2)
		bot = Color(0.04, 0.06, 0.12)
		edge = ICE
	else:
		top = Color(1.0, 0.9, 0.5)
		mid = Color(0.95, 0.72, 0.26)
		bot = Color(0.78, 0.5, 0.12)
		edge = Color(0.42, 0.24, 0.04)
	top = Color(top.r * k, top.g * k, top.b * k)
	mid = Color(mid.r * k, mid.g * k, mid.b * k)
	bot = Color(bot.r * k, bot.g * k, bot.b * k)
	c.draw_polygon(pts, PackedColorArray([top, top, mid, bot, bot, mid]))
	# براقیِ نیمه‌ی بالا
	var gloss := Geometry2D.intersect_polygons(pts, PackedVector2Array([
		Vector2(0, 0), Vector2(c.size.x, 0), Vector2(c.size.x, c.size.y * 0.45), Vector2(0, c.size.y * 0.45)]))
	for g in gloss:
		c.draw_colored_polygon(g, Color(1, 1, 1, 0.1 if navy else 0.22))
	_outline(c, pts, edge, 3.0)
	var inner := Geometry2D.offset_polygon(pts, -6.0)
	if not inner.is_empty():
		_outline(c, inner[0], Color(ICE, 0.35) if navy else Color(1, 0.97, 0.8, 0.55), 1.5)
	_draw_shine_band(c, pts)


func _draw_home(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.5, h * 0.04), Vector2(w, h * 0.5), Vector2(w * 0.86, h * 0.5),
		Vector2(w * 0.86, h * 0.96), Vector2(w * 0.14, h * 0.96), Vector2(w * 0.14, h * 0.5),
		Vector2(0, h * 0.5)]), Color.WHITE)
	c.draw_rect(Rect2(w * 0.41, h * 0.6, w * 0.18, h * 0.36), Color(0.08, 0.11, 0.2))


func _draw_shine(c: Control, _hex: bool) -> void:
	_draw_shine_band(c, PackedVector2Array([Vector2.ZERO, Vector2(c.size.x, 0), c.size, Vector2(0, c.size.y)]))


## نوارِ براقِ مورب، فقط داخلِ شکلِ clip (meta "t" جای نوار روی عرض است)
func _draw_shine_band(c: Control, clip: PackedVector2Array) -> void:
	var t: float = c.get_meta("t", -1.0)
	if t < -0.25 or t > 1.25:
		return
	var w := c.size.x
	var h := c.size.y
	var x := lerpf(-0.2 * w, 1.2 * w, t)
	var sk := h * 0.35
	for band in [[26.0, 0.1], [9.0, 0.22]]:
		var half: float = band[0]
		var poly := PackedVector2Array([
			Vector2(x - half + sk, 0), Vector2(x + half + sk, 0),
			Vector2(x + half - sk, h), Vector2(x - half - sk, h)])
		for p in Geometry2D.intersect_polygons(poly, clip):
			c.draw_colored_polygon(p, Color(1, 1, 1, band[1]))


# ============================ ابزار ============================

## شش‌ضلعیِ کشیده با دو سرِ تیز (قابِ عنوان و دکمه)
func _plate_points(sz: Vector2, tip_k: float) -> PackedVector2Array:
	var tip := sz.y * tip_k
	return PackedVector2Array([
		Vector2(tip, 0), Vector2(sz.x - tip, 0), Vector2(sz.x, sz.y * 0.5),
		Vector2(sz.x - tip, sz.y), Vector2(tip, sz.y), Vector2(0, sz.y * 0.5)])


func _outline(c: CanvasItem, pts: PackedVector2Array, colour: Color, width: float) -> void:
	var loop := pts.duplicate()
	loop.append(pts[0])
	c.draw_polyline(loop, colour, width, true)


func _diamond(c: CanvasItem, at: Vector2, r: float, colour: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([
		at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)]), colour)


func _triangle(colour: Color, sz: Vector2) -> Control:
	var c := Control.new()
	c.custom_minimum_size = sz
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		c.draw_colored_polygon(PackedVector2Array([
			Vector2.ZERO, Vector2(c.size.x, 0), Vector2(c.size.x * 0.5, c.size.y)]), colour))
	return c


## هاله‌ی گردِ نرم (بدون فایلِ آرت)
func _radial(colour: Color, alpha: float, px := 128) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(colour, alpha))
	g.set_color(1, Color(colour, 0.0))
	g.add_point(0.45, Color(colour, alpha * 0.35))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = px
	t.height = px
	return t


func _icon_rect(tex: Texture2D, px: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.custom_minimum_size = Vector2(px, px)
	r.size = Vector2(px, px)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _stack() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _expander() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## متنِ فارسی (SJADIDBD)
func _text_label(text: String, font_size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT_TEXT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## عدد (Lalezar — ارقامش مرتب ردیف می‌شوند)
func _num_label(text: String, font_size: int, colour: Color) -> Label:
	var l := _text_label(text, font_size, colour)
	l.add_theme_font_override("font", FONT_NUM)
	return l


func _tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _vibrate(ms: int) -> void:
	LocalSettings.vibrate(ms)


## ارقامِ فارسی (Lalezar) برای متن‌های بینش‌ها
func _fa(value: int) -> String:
	return MissionArt.fa_number(value)


## نوارِ باریکِ کارتِ بینش: زمینه‌ی تیره و پُریِ طلایی/کرم (meta "r")
func _draw_mini_bar(c: Control) -> void:
	var r := clampf(float(c.get_meta("r", 0.0)), 0.0, 1.0)
	var rect := Rect2(Vector2.ZERO, c.size)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.1)
	bg.set_corner_radius_all(4)
	c.draw_style_box(bg, rect)
	if r <= 0.0:
		return
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD if bool(c.get_meta("gold", false)) else Color(CREAM, 0.75)
	fill.set_corner_radius_all(4)
	# RTL: از راست پر می‌شود
	var w := maxf(c.size.x * r, 8.0)
	c.draw_style_box(fill, Rect2(Vector2(c.size.x - w, 0), Vector2(w, c.size.y)))


## ۴۸۰۰ → «4,800» (مثلِ طرح)
static func _group(value: int) -> String:
	var s := str(absi(value))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if value < 0 else "") + s + out
