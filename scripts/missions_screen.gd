extends Control
## صفحه‌ی «ماموریت ها» — از پنل ماموریت‌های روزانه یا کارت پاداش فصل در
## منوی استارت باز می‌شود.
##
## دو تب دارد:
##   ماموریت های روزانه  شش ماموریت امروز + نوار جایزه‌ی روزانه + تایمر ریست
##   پاداش های فصل       نردبان ۳۰ پله‌ای بتل‌پس + پاداش پایان فصل
##
## ⚠️ قانون امنیتی این صفحه: هیچ عددی اینجا حساب نمی‌شود و هیچ جایزه‌ای اینجا
## واریز نمی‌شود. کلاینت فقط می‌گوید «من کی هستم» و «کدام چیز را می‌خواهم
## بگیرم»؛ هر تصمیمی سمت سرور گرفته می‌شود:
##   - لیست و پیشرفت ماموریت‌ها  → GET /missions/daily
##   - نوار جایزه‌ی روزانه         → همان پاسخ، فیلد `bonus` (حالت هر پله)
##   - نردبان و پله‌ی فعلی        → GET /season/pass
##   - دریافت جایزه               → POST /missions/claim
##                                  POST /missions/bonus/claim
##                                  POST /season/pass/claim
##
## یعنی حتی اگر کسی حافظه‌ی بازی را دستکاری کند و دکمه‌ی «دریافت» را روشن کند،
## سرور دوباره از روی رکورد دیتابیس چک می‌کند و دست خالی برمی‌گردد. موجودی
## هم بعد از هر دریافت از پاسخ سرور خوانده می‌شود، نه با جمع زدن محلی.
##
## تایمر ریست هم از سرور می‌آید (seconds_left) و اینجا فقط شمارش معکوس
## می‌شود؛ عوض کردن ساعت گوشی هیچ اثری روی آن ندارد.

const MISSION_ROW_SCENE := preload("res://secense/mission_row.tscn")
const BONUS_NODE_SCENE := preload("res://secense/mission_bonus_node.tscn")
const TIER_CARD_SCENE := preload("res://secense/season_tier_card.tscn")
const CHALLENGE_ROW_SCENE := preload("res://secense/season_challenge_row.tscn")
const PsychProgress := preload("res://scripts/psych_results_progress.gd")

## فونت عددها. قوطی‌های جایزه‌ی کارت کناری در کد ساخته می‌شوند و تم صحنه را
## به ارث نمی‌برند، پس فونت را صریح می‌دهیم تا با بقیه‌ی عددهای صفحه یکی باشد.
const NUM_FONT := preload("res://fonts/Lalezar-Regular.ttf")

const MAIN_MENU_SCENE := "res://secense/main_menu.tscn"
const GAME_MODES_SCENE := "res://secense/game_modes.tscn"
const PROFILE_MENU_SCENE := "res://secense/profile_menu.tscn"
const SHOP_SCENE := "res://secense/shop.tscn"

## ترتیب تب‌ها توی shop.gd: 0=ویژه، 1=کاراکتر، 2=سلاح، 3=سکه/جم
const SHOP_TAB_CURRENCY := 3

const COLOR_TEXT := MissionArt.COLOR_TEXT
const COLOR_MUTED := MissionArt.COLOR_MUTED

@onready var _missions_http: HTTPRequest = $MissionsHTTP
@onready var _mission_claim_http: HTTPRequest = $MissionClaimHTTP
@onready var _bonus_claim_http: HTTPRequest = $BonusClaimHTTP
@onready var _season_http: HTTPRequest = $SeasonHTTP
@onready var _season_claim_http: HTTPRequest = $SeasonClaimHTTP

@onready var _toast: Label = $Toast

# --- نوار بالا ---
@onready var _back_button: TextureButton = $Header/Margin/Row/BackButton
@onready var _help_button: TextureButton = $Header/Margin/Row/HelpButton
@onready var _coins_label: Label = $Header/Margin/Row/CoinPill/Row/Value
@onready var _gems_label: Label = $Header/Margin/Row/GemPill/Row/Value
@onready var _coins_plus: TextureButton = $Header/Margin/Row/CoinPill/Row/PlusButton
@onready var _gems_plus: TextureButton = $Header/Margin/Row/GemPill/Row/PlusButton
@onready var _mail_button: TextureButton = $Header/Margin/Row/MailSlot/MailButton
@onready var _mail_badge: PanelContainer = $Header/Margin/Row/MailSlot/Badge
@onready var _mail_badge_count: Label = $Header/Margin/Row/MailSlot/Badge/Count
@onready var _friends_button: TextureButton = $Header/Margin/Row/FriendsButton
@onready var _settings_button: TextureButton = $Header/Margin/Row/SettingsButton

# --- ساید بار ---
@onready var _daily_icon: TextureRect = $Body/Sidebar/DailySlot/Icon
@onready var _season_icon: TextureRect = $Body/Sidebar/SeasonSlot/Icon
@onready var _daily_button: Button = $Body/Sidebar/DailySlot/DailyButton
@onready var _daily_dot: Panel = $Body/Sidebar/DailySlot/Dot
@onready var _season_button: Button = $Body/Sidebar/SeasonSlot/SeasonButton
@onready var _season_dot: Panel = $Body/Sidebar/SeasonSlot/Dot

# --- تب ماموریت‌های روزانه ---
@onready var _daily_page: VBoxContainer = $Body/Center/DailyPage
@onready var _hero_art: TextureRect = $Body/Center/DailyPage/BannerPanel/Margin/Row/HeroArt
@onready var _timer_label: Label = \
	$Body/Center/DailyPage/BannerPanel/Margin/Row/TimerBox/TimerChip/Row/TimerLabel
@onready var _star_label: Label = \
	$Body/Center/DailyPage/BannerPanel/Margin/Row/Info/TrackRow/StarBox/Value
@onready var _track: HBoxContainer = \
	$Body/Center/DailyPage/BannerPanel/Margin/Row/Info/TrackRow/Track
@onready var _missions_scroll: ScrollContainer = \
	$Body/Center/DailyPage/ListPanel/Margin/Body/Scroll
@onready var _missions_list: VBoxContainer = \
	$Body/Center/DailyPage/ListPanel/Margin/Body/Scroll/List
@onready var _missions_empty: Label = $Body/Center/DailyPage/ListPanel/Margin/Body/EmptyLabel

# --- ستون کناری (جایزه‌ی روزانه) ---
@onready var _bonus_rewards: HBoxContainer = $Body/RightColumn/BonusCard/Margin/Body/Rewards
@onready var _bonus_claim_button: Button = $Body/RightColumn/BonusCard/Margin/Body/ClaimButton
@onready var _bonus_desc: Label = $Body/RightColumn/BonusCard/Margin/Body/DescLabel
@onready var _motive_art: TextureRect = $Body/RightColumn/MotiveCard/Art
@onready var _promo_art: TextureRect = $Footer/PromoStrip/Row/Art

# --- نوار پایین ---
@onready var _score_bar: ProgressBar = $Footer/ScoreCard/Margin/Row/Box/Bar
@onready var _score_count: Label = $Footer/ScoreCard/Margin/Row/CountLabel

# --- تب پاداش فصل ---
@onready var _season_page: VBoxContainer = $Body/Center/SeasonPage
@onready var _right_column: VBoxContainer = $Body/RightColumn
@onready var _footer: HBoxContainer = $Footer
@onready var _body: HBoxContainer = $Body

# --- بنر فصل ---
const _BANNER := "Body/Center/SeasonPage/BannerPanel/Margin/Row"
@onready var _season_hero: TextureRect = get_node(_BANNER + "/HeroArt")
@onready var _season_banner_art: TextureRect = \
	$Body/Center/SeasonPage/BannerPanel/BannerArt
@onready var _season_name: Label = get_node(_BANNER + "/Info/TitleRow/NameLabel")
@onready var _season_subtitle: Label = get_node(_BANNER + "/Info/TitleRow/SubtitleLabel")
@onready var _season_ends: Label = get_node(_BANNER + "/Info/EndsRow/EndsLabel")
@onready var _pass_badge: TextureRect = get_node(_BANNER + "/LevelBox/BadgeArt")
@onready var _pass_level_label: Label = get_node(_BANNER + "/LevelBox/LevelLabel")
@onready var _pass_bar: ProgressBar = get_node(_BANNER + "/LevelBox/Bar")
@onready var _pass_xp_label: Label = get_node(_BANNER + "/LevelBox/XpLabel")

# --- نردبان جایزه ---
const _LADDER := "Body/Center/SeasonPage/LadderRow"
@onready var _ladder: HBoxContainer = get_node(_LADDER + "/LadderPanel/Margin/Scroll/Ladder")
@onready var _ladder_scroll: ScrollContainer = \
	get_node(_LADDER + "/LadderPanel/Margin/Scroll")

# --- کارت‌های بتل‌پس ---
const _PASS_CARDS := "Body/Center/SeasonPage/LadderRow/PassCards"
@onready var _gold_icon: TextureRect = get_node(_PASS_CARDS + "/GoldCard/Margin/Body/Icon")
@onready var _gold_price: Label = \
	get_node(_PASS_CARDS + "/GoldCard/Margin/Body/PriceRow/Value")
@onready var _gold_price_row: HBoxContainer = \
	get_node(_PASS_CARDS + "/GoldCard/Margin/Body/PriceRow")
@onready var _buy_button: Button = get_node(_PASS_CARDS + "/GoldCard/Margin/Body/BuyButton")
@onready var _free_icon: TextureRect = get_node(_PASS_CARDS + "/FreeCard/Margin/Body/Icon")

# --- چالش‌های فصل و کارت تبلیغ ---
const _BOTTOM := "Body/Center/SeasonPage/BottomRow"
@onready var _challenge_scroll: ScrollContainer = \
	get_node(_BOTTOM + "/ChallengesPanel/Margin/Body/Scroll")
@onready var _challenge_list: VBoxContainer = \
	get_node(_BOTTOM + "/ChallengesPanel/Margin/Body/Scroll/List")
@onready var _challenge_crown: TextureRect = \
	get_node(_BOTTOM + "/ChallengesPanel/Margin/Body/HeaderRow/Crown")
@onready var _season_promo_art: TextureRect = get_node(_BOTTOM + "/PromoCard/Art")
@onready var _promo_button: Button = get_node(_BOTTOM + "/PromoCard/Margin/Body/DetailsButton")

## تب فعلی: daily | season
var _tab := "daily"

var _missions_busy := false
var _season_busy := false
## ماموریتی که الان درخواست دریافتش رفته («» یعنی هیچ‌کدام)
var _claiming_mission := ""
## پله‌ی جایزه‌ی روزانه‌ای که الان درخواستش رفته (۰ یعنی هیچ‌کدام)
var _claiming_bonus := 0
## پله‌ی آخرِ نوار جایزه — دکمه‌ی کارت کناری همین را می‌گیرد (۰ یعنی هنوز نداریم)
var _final_bonus_need := 0
## پله‌ی فصلی که الان درخواست دریافتش رفته (۰ یعنی هیچ‌کدام)
var _claiming_level := 0
## چالشی که الان درخواست دریافتش رفته («» یعنی هیچ‌کدام)
var _claiming_challenge := ""
## آیا درخواست خرید بتل‌پس در راه است
var _buying_pass := false
## آخرین درخواستی که روی _season_claim_http رفته: tier | challenge | buy
var _season_action := ""
## چند ماموریت امروز دریافت شده (برای پیام «صندوق هنوز باز نشده»)
var _missions_claimed := 0

## ثانیه تا ریست — از سرور می‌آید و اینجا فقط کم می‌شود
var _seconds_left := 0
var _tick := 0.0

# استایل دکمه‌های تب — از خود صحنه خوانده می‌شوند
var _style_on: StyleBox = null
var _style_on_hover: StyleBox = null
var _style_off: StyleBox = null
var _style_off_hover: StyleBox = null

var _toast_token := 0
## جلوی دوبار اجرا شدنِ «بازگشت» در یک فریم (Back هم notification می‌فرستد هم ui_cancel)
var _back_frame := -1

# ------------------------------------------------------------------ آماده‌سازی

func _ready() -> void:
	# دکمه‌ی Back اندروید اینجا باید به منوی اصلی برگردد، نه اینکه اپ را ببندد
	get_tree().set_quit_on_go_back(false)
	_missions_http.request_completed.connect(_on_missions_received)
	_mission_claim_http.request_completed.connect(_on_mission_claim_received)
	_bonus_claim_http.request_completed.connect(_on_bonus_claim_received)
	_season_http.request_completed.connect(_on_season_received)
	_season_claim_http.request_completed.connect(_on_season_claim_received)

	_style_on = _daily_button.get_theme_stylebox("normal")
	_style_on_hover = _daily_button.get_theme_stylebox("hover")
	_style_off = _season_button.get_theme_stylebox("normal")
	_style_off_hover = _season_button.get_theme_stylebox("hover")

	_wire_header()
	_wire_sidebar()

	_bonus_claim_button.pressed.connect(_on_bonus_card_pressed)
	UIFx.bind_press_feedback(_bonus_claim_button)

	_wire_season_page()

	# اسکرول‌بار پیش‌فرض پهن است و همیشه دیده می‌شود؛ این سه‌تا نوار باریکِ
	# آبی می‌گیرند که فقط موقع اسکرول کردن ظاهر می‌شود
	for scroll in [_missions_scroll, _ladder_scroll, _challenge_scroll]:
		UIScroll.attach(scroll)

	# منوی استارت می‌گوید کدام تب باز شود (کارت پاداش فصل → season)
	var requested := str(Global.requested_missions_tab)
	Global.requested_missions_tab = ""
	if requested == "season":
		_tab = "season"

	_apply_tab()
	_apply_wallet()

	# اگر صحنه زودتر از Global بالا بیاید، هنوز نه نام کاربری داریم نه رکورد
	# بازیکن روی سرور ساخته شده. پس وقتی Global دیتا را لود کرد دوباره می‌گیریم.
	if not Global.player_data_loaded.is_connected(_on_player_data_loaded):
		Global.player_data_loaded.connect(_on_player_data_loaded)
	if not Global.player_data_updated.is_connected(_apply_wallet):
		Global.player_data_updated.connect(_apply_wallet)
	if not Global.unread_count_updated.is_connected(_on_unread_updated):
		Global.unread_count_updated.connect(_on_unread_updated)
	_on_unread_updated(Global.unread_messages)

	# هر دو تب همان اول گرفته می‌شوند تا سوییچ بین تب‌ها بدون تاخیر باشد
	refresh_missions()
	refresh_season()

## آیکن‌ها و دکمه‌های تب «پاداش های فصل».
## آیکن‌ها از MissionArt می‌آیند نه از صحنه، تا اگر فایلشان عوض شد فقط یک جا
## دست بخورد.
func _wire_season_page() -> void:
	# نشان سطح آرت رنگیِ خودش را دارد (در صحنه نشسته)، پس اینجا دست نمی‌خورد
	_gold_icon.texture = MissionArt.texture_for("crown")
	_free_icon.texture = MissionArt.texture_for("gift")
	_challenge_crown.texture = MissionArt.texture_for("crown")

	_buy_button.pressed.connect(_on_buy_pass_pressed)
	UIFx.bind_press_feedback(_buy_button)

	# کارت تبلیغ فعلاً بازیکن را می‌برد سراغ خرید بتل‌پس — همان چیزی که
	# متن کارت وعده‌اش را می‌دهد
	_promo_button.pressed.connect(_on_buy_pass_pressed)
	UIFx.bind_press_feedback(_promo_button)

func _on_player_data_loaded() -> void:
	_apply_wallet()
	refresh_missions()
	refresh_season()

# --------------------------------------------------------------------- نوار بالا

func _wire_header() -> void:
	UIFx.bind_press(_back_button, _on_home_pressed)
	UIFx.bind_tap(_help_button, _on_help_pressed)

	for button: TextureButton in [_coins_plus, _gems_plus]:
		UIFx.bind_press(button, _on_currency_plus_pressed)

	UIFx.bind_press(_mail_button, _go_to_profile_menu.bind("messages"))
	UIFx.bind_press(_friends_button, _go_to_profile_menu.bind("friends"))
	UIFx.bind_press(_settings_button, _go_to_profile_menu.bind("settings"))

## موجودی نوار بالا — از Global خوانده می‌شود و Global هم فقط از سرور پر می‌شود
func _apply_wallet() -> void:
	_coins_label.text = MissionArt.fa_grouped(int(Global.coins))
	_gems_label.text = MissionArt.fa_grouped(int(Global.gems))

func _on_unread_updated(count: int) -> void:
	_mail_badge.visible = count > 0
	_mail_badge_count.text = MissionArt.fa_number(mini(count, 99))

func _on_currency_plus_pressed() -> void:
	Global.request_shop_tab(SHOP_TAB_CURRENCY)
	get_tree().change_scene_to_file(SHOP_SCENE)

func _go_to_profile_menu(tab_id: String) -> void:
	Global.request_profile_tab(tab_id)
	get_tree().change_scene_to_file(PROFILE_MENU_SCENE)

func _on_help_pressed() -> void:
	_show_toast("ماموریت ها را کامل کن تا سکه، تجربه و صندوق بگیری.")

# ---------------------------------------------------------------------- تب‌ها

func _wire_sidebar() -> void:
	_daily_button.pressed.connect(_on_tab_pressed.bind("daily"))
	_season_button.pressed.connect(_on_tab_pressed.bind("season"))
	for button: Button in [_daily_button, _season_button]:
		UIFx.bind_press_feedback(button)

func _on_tab_pressed(tab: String) -> void:
	if tab == _tab:
		return
	_tab = tab
	_apply_tab()

## ظاهر دکمه‌ها و اینکه کدام صفحه دیده شود
func _apply_tab() -> void:
	var daily := _tab == "daily"

	_daily_page.visible = daily
	_season_page.visible = not daily
	# ستون کناری (جایزه‌ی روزانه) فقط به تب روزانه ربط دارد؛ تب فصل خودش
	# کارت‌های بتل‌پس را کنار نردبان دارد و به کل عرض احتیاج دارد.
	_right_column.visible = daily
	# نوار پایین هم امتیاز ماموریت *امروز* را نشان می‌دهد، پس روی تب فصل
	# جایی ندارد — و صفحه‌ی فصل به آن فضا احتیاج دارد.
	_footer.visible = daily
	_body.offset_bottom = -92.0 if daily else -10.0

	# نردبان تا وقتی تب مخفی است اندازه ندارد، پس اسکرولش همین‌جا نشانده
	# می‌شود نه موقع ساخته شدن
	if not daily:
		_park_ladder()

	_style_button(_daily_button, _daily_icon, daily)
	_style_button(_season_button, _season_icon, not daily)

func _style_button(button: Button, icon: TextureRect, active: bool) -> void:
	button.add_theme_stylebox_override("normal", _style_on if active else _style_off)
	button.add_theme_stylebox_override("hover", _style_on_hover if active else _style_off_hover)
	button.add_theme_stylebox_override("pressed", _style_on_hover if active else _style_off_hover)
	button.add_theme_color_override("font_color", COLOR_TEXT if active else COLOR_MUTED)
	# آیکن دیگر Button.icon نیست (آنجا نسبت تصویر حفظ نمی‌شد)، پس مستقیم
	# رنگش می‌کنیم
	icon.modulate = MissionArt.COLOR_BLUE_SOFT if active else COLOR_MUTED

# ------------------------------------------------------------------- تایمر ریست

func _process(delta: float) -> void:
	if _seconds_left <= 0:
		return

	_tick += delta
	if _tick < 1.0:
		return
	var whole := int(_tick)
	_tick -= float(whole)
	_seconds_left = maxi(_seconds_left - whole, 0)
	_apply_countdown()

	# روز عوض شد → ماموریت‌های تازه
	if _seconds_left == 0:
		refresh_missions()

func _apply_countdown() -> void:
	_timer_label.text = MissionArt.format_countdown(_seconds_left)

# ------------------------------------------------------------ ماموریت‌های روزانه

func refresh_missions() -> void:
	var username: String = str(Global.my_username)
	if username.is_empty() or _missions_busy:
		return

	var url := "%s/missions/daily?username=%s" % [Global.SERVER_BASE, username.uri_encode()]
	if _missions_http.request(url, Global.auth_headers()) != OK:
		push_warning("خطا در درخواست ماموریت‌های روزانه")
		return
	_missions_busy = true

func _on_missions_received(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	_missions_busy = false

	var data := _parse(result, response_code, body)
	if data.is_empty():
		_missions_empty.text = "ماموریت ها در دسترس نیستند."
		_missions_empty.visible = true
		_missions_scroll.visible = false
		return

	_apply_missions(data)

func _apply_missions(data: Dictionary) -> void:
	_seconds_left = int(data.get("seconds_left", 0))
	_tick = 0.0
	_apply_countdown()

	var missions: Array = data.get("missions", [])
	var total := maxi(int(data.get("total", missions.size())), 1)
	var claimed := int(data.get("claimed", 0))
	_missions_claimed = claimed
	var ready_count := int(data.get("ready", 0))

	# نوار امتیاز پایین صفحه و ستاره‌ی بالای نوار جایزه، هر دو همین عدد
	var score := "%s/%s" % [MissionArt.fa_number(claimed), MissionArt.fa_number(total)]
	_star_label.text = score
	_score_count.text = score
	_score_bar.max_value = float(total)
	_score_bar.value = 0.0
	# C9 پیشرفتِ اهدایی: اولِ روز هم نوار کاملاً خالی نیست
	create_tween().tween_property(_score_bar, "value", PsychProgress.bar_value(_score_bar, claimed, total), 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# نقطه‌ی قرمز کنار تب: یعنی یک چیزی برای گرفتن هست
	_daily_dot.visible = ready_count > 0 or int(data.get("bonus_ready", 0)) > 0

	_build_bonus_track(data.get("bonus", []))
	_apply_bonus_card(data.get("bonus", []))

	for child in _missions_list.get_children():
		child.queue_free()

	var index := 0
	# C14/E7: آماده ← نزدیک‌ترین ناتمام ← بقیه ← گرفته‌شده
	for item in PsychProgress.sort_for_display(missions):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := MISSION_ROW_SCENE.instantiate()
		_missions_list.add_child(row)
		row.setup(item as Dictionary)
		row.claim_requested.connect(_on_mission_claim_requested)
		row.go_requested.connect(_on_mission_go_requested)
		row.play_pop(0.04 * float(index))
		index += 1

	_missions_empty.visible = index == 0
	_missions_scroll.visible = index > 0

## «رفتن» روی ماموریتِ ناتمام — فقط ناوبری است، هیچ چیزی گرفته نمی‌شود
func _on_mission_go_requested(_mission_id: String) -> void:
	get_tree().change_scene_to_file(GAME_MODES_SCENE)

func _on_mission_claim_requested(mission_id: String) -> void:
	if mission_id.is_empty() or not _claiming_mission.is_empty():
		return
	var username: String = str(Global.my_username)
	if username.is_empty():
		return

	var body := JSON.stringify({"username": username, "mission_id": mission_id})
	var err := _mission_claim_http.request(
		"%s/missions/claim" % Global.SERVER_BASE,
		Global.json_headers(),
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		push_warning("خطا در درخواست دریافت جایزه: %d" % err)
		return
	_claiming_mission = mission_id

func _on_mission_claim_received(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	_claiming_mission = ""

	var data := _parse(result, response_code, body)
	if data.is_empty():
		_show_toast(_error_message(body, "جایزه دریافت نشد."))
		refresh_missions()
		return

	# پاسخِ claim خودش لیست تازه را دارد، پس درخواست دوم لازم نیست
	_apply_missions(data)
	_sync_wallet(data)

	RewardPopup.show_rewards(
		RewardPopup.items_from_reward(data.get("reward", {})), "ماموریت انجام شد")

	# تجربه‌ی ماموریت به بتل‌پس هم اضافه شده، پس آن را هم تازه می‌کنیم
	refresh_season()

# -------------------------------------------------------------- جایزه‌ی روزانه

## نوار صندوق‌های بالای صفحه. حالت هر صندوق را سرور گفته (`state`)؛ اینجا
## فقط چیده می‌شود. خط بین دو صندوق وقتی طلایی است که صندوق سمت راستش
## دیگر قفل نباشد.
func _build_bonus_track(tiers: Array) -> void:
	for child in _track.get_children():
		child.queue_free()

	for tier in tiers:
		if typeof(tier) != TYPE_DICTIONARY:
			continue
		var state := str((tier as Dictionary).get("state", "locked"))
		_track.add_child(_track_line(state != "locked"))

		var node := BONUS_NODE_SCENE.instantiate()
		_track.add_child(node)
		node.setup(tier as Dictionary)
		node.claim_requested.connect(_on_bonus_claim_requested)
		node.unavailable_tapped.connect(_on_bonus_unavailable)

## خط رابط بین صندوق‌ها
func _track_line(filled: bool) -> Control:
	var holder := Control.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.custom_minimum_size = Vector2(16, 0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var line := ColorRect.new()
	line.color = MissionArt.COLOR_GOLD if filled else Color(0.15, 0.2, 0.27, 1.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# وسطِ ارتفاع صندوق (۴۴ پیکسل) بنشیند، نه وسط کل گره
	line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	line.offset_top = 20.0
	line.offset_bottom = 24.0
	holder.add_child(line)
	return holder

## کارت «پاداش روزانه» کنار صفحه = آخرین پله‌ی همان نوار
func _apply_bonus_card(tiers: Array) -> void:
	for child in _bonus_rewards.get_children():
		child.queue_free()

	var final_tier: Dictionary = {}
	for tier in tiers:
		if typeof(tier) == TYPE_DICTIONARY:
			final_tier = tier as Dictionary
	if final_tier.is_empty():
		_final_bonus_need = 0
		_bonus_claim_button.disabled = true
		_bonus_claim_button.text = "دریافت پاداش"
		return

	_final_bonus_need = int(final_tier.get("need", 0))

	_bonus_desc.text = "با تکمیل %s ماموریت روزانه، این پاداش را دریافت کنید." \
		% MissionArt.fa_number(_final_bonus_need)

	if int(final_tier.get("gems", 0)) > 0:
		_bonus_rewards.add_child(
			_reward_chip("gem", int(final_tier["gems"]), Color(0.353, 0.784, 0.98, 1.0)))
	if int(final_tier.get("coins", 0)) > 0:
		_bonus_rewards.add_child(
			_reward_chip("coin", int(final_tier["coins"]), MissionArt.COLOR_GOLD))

	var state := str(final_tier.get("state", "locked"))
	_bonus_claim_button.disabled = state != "ready"
	_bonus_claim_button.text = "دریافت شد" if state == "claimed" else "دریافت پاداش"

## یک قوطی جایزه: آیکن بالا، عدد پایین
func _reward_chip(icon_id: String, value: int, color: Color) -> Control:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(62, 0)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.031, 0.063, 0.106, 0.95)
	style.set_border_width_all(1)
	style.border_color = Color(color.r, color.g, color.b, 0.45)
	style.set_corner_radius_all(7)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	chip.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(box)

	var icon := TextureRect.new()
	icon.texture = MissionArt.texture_for(icon_id)
	# سکه و جم آرت رنگی‌اند؛ تینت زدن رویشان رنگ را خراب می‌کند. بقیه سفیدند
	# و رنگ قوطی را می‌گیرند.
	icon.self_modulate = Color.WHITE if MissionArt.is_art_icon(icon_id) else color
	icon.custom_minimum_size = Vector2(0, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var label := Label.new()
	label.text = MissionArt.fa_grouped(value)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_override("font", NUM_FONT)
	label.add_theme_font_size_override("font_size", 15)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	return chip

## لمس صندوقی که نمی‌شود بازش کرد — دلیلش را می‌گوییم
func _on_bonus_unavailable(need: int, state: String) -> void:
	if state == "claimed":
		_show_toast("این صندوق را امروز باز کرده‌ای")
		return
	var left := maxi(need - _missions_claimed, 1)
	_show_toast("برای باز شدن این صندوق %s ماموریت دیگر را دریافت کن" 		% MissionArt.fa_number(left))

## دکمه‌ی کارت کناری همان آخرین صندوق نوار را می‌گیرد
func _on_bonus_card_pressed() -> void:
	_on_bonus_claim_requested(_final_bonus_need)

func _on_bonus_claim_requested(need: int) -> void:
	if need <= 0 or _claiming_bonus > 0:
		return
	var username: String = str(Global.my_username)
	if username.is_empty():
		return

	# فقط شماره‌ی پله می‌رود؛ مقدار جایزه و اینکه اصلاً حقش هست یا نه،
	# سمت سرور از روی رکورد امروزِ همین بازیکن حساب می‌شود.
	var body := JSON.stringify({"username": username, "need": need})
	var err := _bonus_claim_http.request(
		"%s/missions/bonus/claim" % Global.SERVER_BASE,
		Global.json_headers(),
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		push_warning("خطا در درخواست جایزه‌ی روزانه: %d" % err)
		return
	_claiming_bonus = need

func _on_bonus_claim_received(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	_claiming_bonus = 0

	var data := _parse(result, response_code, body)
	if data.is_empty():
		_show_toast(_error_message(body, "جایزه دریافت نشد."))
		refresh_missions()
		return

	_apply_missions(data)
	_sync_wallet(data)

	# عکس همان صندوقی که باز شد بالای صفحه‌ی جایزه می‌نشیند
	var reward: Dictionary = data.get("reward", {})
	var chest := MissionArt.texture_for(str(reward.get("chest", "chest_common")))
	RewardPopup.show_rewards(RewardPopup.items_from_reward(reward), "صندوق باز شد", chest)

# ------------------------------------------------------------------- پاداش فصل

func refresh_season() -> void:
	var username: String = str(Global.my_username)
	if username.is_empty() or _season_busy:
		return

	var url := "%s/season/pass?username=%s" % [Global.SERVER_BASE, username.uri_encode()]
	if _season_http.request(url, Global.auth_headers()) != OK:
		push_warning("خطا در درخواست پاداش فصل")
		return
	_season_busy = true

func _on_season_received(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	_season_busy = false

	var data := _parse(result, response_code, body)
	if data.is_empty():
		return
	_apply_season(data)

func _apply_season(data: Dictionary) -> void:
	_pass_level_label.text = "سطح %s" % MissionArt.fa_number(int(data.get("level", 1)))

	# نقطه‌ی قرمز کنار تب: هم پله‌ی آماده، هم چالش آماده
	var ready_count := int(data.get("ready", 0)) + int(data.get("challenges_ready", 0))
	_season_dot.visible = ready_count > 0

	var into := int(data.get("level_xp", 0))
	var need := maxi(int(data.get("level_max", 1)), 1)
	_pass_bar.max_value = float(need)
	_pass_bar.value = 0.0
	# C9 اولِ هر پله‌ی فصل نوار خالی دیده نمی‌شود؛ نزدیکِ پله‌ی بعد طلایی می‌شود
	create_tween().tween_property(_pass_bar, "value", PsychProgress.bar_value(_pass_bar, into, need), 0.45) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	PsychProgress.emphasize_bar(_pass_bar, PsychProgress.is_near(into, need))
	_pass_xp_label.text = "%s / %s" % [
		MissionArt.fa_grouped(into), MissionArt.fa_grouped(need)
	]

	# متن بنر از سرور می‌آید تا عوض کردن فصل فقط یک تغییر سمت سرور باشد
	_season_name.text = str(data.get("season_name", ""))
	_season_subtitle.text = str(data.get("season_subtitle", ""))
	var ends := str(data.get("season_ends_at", ""))
	_season_ends.text = "پایان فصل: %s" % ends if not ends.is_empty() else ""

	_apply_pass_cards(data)
	_build_ladder(data.get("tiers", []))
	_apply_next_tease(data, into, need)
	_build_challenges(data.get("challenges", []))

## E12/C9 «پاداش بعدی»: اولین پله‌ای که هنوز باز نشده، در بنر و روی خودِ
## نردبان. فقط اطلاعاتِ واقعیِ سرور — نه شمارش معکوس و نه فشار.
var _next_tease: HBoxContainer = null
var _next_tease_icon: TextureRect = null
var _next_tease_label: Label = null

func _apply_next_tease(data: Dictionary, into: int, need: int) -> void:
	var next: Dictionary = {}
	for tier in data.get("tiers", []):
		if typeof(tier) == TYPE_DICTIONARY and not bool(tier.get("unlocked", false)):
			next = tier
			break
	for card in _ladder.get_children():
		if card.has_method("set_next"):
			card.set_next(not next.is_empty() and int(card.level) == int(next.get("level", 0)))
	if _next_tease == null:
		_build_next_tease()
	_next_tease.visible = not next.is_empty()
	if next.is_empty():
		return
	# اگر بتل‌پس طلایی دارد، جایزه‌ی طلایی همان پله را نشان بده (بزرگ‌تر است)
	var cell: Dictionary = next.get("free", next)
	if bool(data.get("premium", false)) and next.get("premium") is Dictionary:
		cell = next["premium"]
	_next_tease_icon.texture = MissionArt.reward_texture(cell)
	var left := maxi(need - into, 0)
	var near := PsychProgress.is_near(into, need)
	_next_tease_label.text = "پاداش سطح %s: %s  ·  %s%s تجربه مونده" % [
		MissionArt.fa_number(int(next.get("level", 0))), str(cell.get("title", "")),
		"فقط " if near else "", MissionArt.fa_grouped(left)]
	_next_tease_label.add_theme_color_override("font_color",
		MissionArt.COLOR_GOLD if near else COLOR_TEXT)

func _build_next_tease() -> void:
	var info := get_node(_BANNER + "/Info") as VBoxContainer
	_next_tease = HBoxContainer.new()
	_next_tease.alignment = BoxContainer.ALIGNMENT_END
	_next_tease.add_theme_constant_override("separation", 6)
	_next_tease.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_tease_label = Label.new()
	_next_tease_label.add_theme_font_override("font", NUM_FONT)
	_next_tease_label.add_theme_font_size_override("font_size", 15)
	_next_tease_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_next_tease_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_tease_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_next_tease_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_tease.add_child(_next_tease_label)
	_next_tease_icon = TextureRect.new()
	_next_tease_icon.custom_minimum_size = Vector2(24, 24)
	_next_tease_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_next_tease_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_next_tease_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_next_tease_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_tease.add_child(_next_tease_icon)
	info.add_child(_next_tease)

## کارت‌های «بتل پس طلایی» و «بتل پس رایگان» کنار نردبان
func _apply_pass_cards(data: Dictionary) -> void:
	var owned := bool(data.get("premium", false))
	var price := int(data.get("premium_price", 0))

	_gold_price.text = MissionArt.fa_grouped(price)
	# وقتی خریده شده، قیمت دیگر معنی ندارد
	_gold_price_row.visible = not owned and price > 0
	_buy_button.disabled = owned or _buying_pass
	_buy_button.text = "فعال است" if owned else "خرید"

func _build_ladder(tiers: Array) -> void:
	for child in _ladder.get_children():
		child.queue_free()

	# راست‌چین: پله‌ی ۱ سمت راست، پله‌ی آخر سمت چپ
	var cards: Array = []
	for i in range(tiers.size() - 1, -1, -1):
		if typeof(tiers[i]) != TYPE_DICTIONARY:
			continue
		var card := TIER_CARD_SCENE.instantiate()
		_ladder.add_child(card)
		card.setup(tiers[i] as Dictionary)
		card.claim_requested.connect(_on_tier_claim_requested)
		cards.append(card)

	# فقط چند کارت اول پاپ می‌شوند؛ ۳۰ تا انیمیشن همزمان روی موبایل سنگین است
	for i in mini(cards.size(), 8):
		cards[i].play_pop(0.04 * float(i))

	# اسکرول را روی اولین پله‌ی آماده می‌بریم تا بازیکن دنبالش نگردد.
	# اگر هیچ پله‌ای آماده نبود، روی پله‌ی فعلی بازیکن می‌ایستد.
	_scroll_to_first_ready(tiers)

## پله‌ای که نردبان باید رویش بایستد (۰ یعنی هنوز حساب نشده)
var _ladder_target_level := 0

## پیدا کردن پله‌ی هدف: اولین جایزه‌ی آماده، وگرنه آخرین پله‌ی باز‌شده.
##
## خودِ اسکرول اینجا انجام نمی‌شود چون ممکن است تب فصل هنوز مخفی باشد و
## ScrollContainer اندازه‌ای نداشته باشد — در آن حالت هر مقداری بگذاریم به صفر
## گیر می‌کند. فقط هدف را نگه می‌داریم و _park_ladder موقع دیده شدن تب
## کار را تمام می‌کند.
func _scroll_to_first_ready(tiers: Array) -> void:
	var target_level := 0
	var last_unlocked := 0
	for tier in tiers:
		if typeof(tier) != TYPE_DICTIONARY:
			continue
		var t := tier as Dictionary
		if bool(t.get("unlocked", false)):
			last_unlocked = int(t.get("level", 0))
		# هر کدام از دو مسیر که آماده باشد کافی است
		if target_level <= 0:
			for track in ["free", "premium"]:
				var cell: Dictionary = t.get(track, {})
				if str(cell.get("state", "")) == "ready":
					target_level = int(t.get("level", 0))
					break

	# هیچ جایزه‌ای آماده نیست → پله‌ی بعدی (E12: جایزه‌ی بعدی در دید باشد)
	if target_level <= 0:
		target_level = mini(last_unlocked + 1, tiers.size())
	_ladder_target_level = target_level

	if _season_page.visible:
		_park_ladder()

## نردبان را روی پله‌ی هدف می‌نشاند.
##
## نردبان راست‌چین است (پله‌ی ۱ سمت راست، پله‌ی آخر سمت چپ)، پس بازیکنِ تازه
## باید ته *راست* را ببیند نه ته چپ.
func _park_ladder() -> void:
	# اندازه‌ی نهاییِ ردیف بعد از چیده شدن هر ۳۰ ستون معلوم می‌شود
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(_ladder_scroll) or not is_instance_valid(_ladder):
		return

	if _ladder_target_level <= 0:
		# عدد بزرگ را خود ScrollContainer به سقفش می‌بُرد
		_ladder_scroll.scroll_horizontal = 1 << 24
		return

	for card in _ladder.get_children():
		if int(card.level) == _ladder_target_level:
			_ladder_scroll.ensure_control_visible(card)
			return

## چالش های ویژه فصل — ردیف‌های پایین صفحه
func _build_challenges(challenges: Array) -> void:
	for child in _challenge_list.get_children():
		child.queue_free()

	var index := 0
	# C14/E7: آماده ← نزدیک‌ترین ناتمام ← بقیه ← گرفته‌شده
	for item in PsychProgress.sort_for_display(challenges):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := CHALLENGE_ROW_SCENE.instantiate()
		_challenge_list.add_child(row)
		row.setup(item as Dictionary)
		row.claim_requested.connect(_on_challenge_claim_requested)
		row.play_requested.connect(_on_mission_go_requested.bind(""))
		row.play_pop(0.04 * float(index))
		index += 1

func _on_challenge_claim_requested(challenge_id: String) -> void:
	if challenge_id.is_empty() or not _claiming_challenge.is_empty():
		return
	var username: String = str(Global.my_username)
	if username.is_empty():
		return

	var body := JSON.stringify({"username": username, "challenge_id": challenge_id})
	var err := _season_claim_http.request(
		"%s/season/challenges/claim" % Global.SERVER_BASE,
		Global.json_headers(),
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		push_warning("خطا در درخواست دریافت چالش: %d" % err)
		return
	_claiming_challenge = challenge_id
	_season_action = "challenge"

## خرید بتل‌پس طلایی. قیمت و موجودی هر دو سمت سرور چک می‌شوند؛ اینجا فقط
## دکمه قفل می‌شود تا دوبار زدن دو درخواست نفرستد.
func _on_buy_pass_pressed() -> void:
	if _buying_pass:
		return
	var username: String = str(Global.my_username)
	if username.is_empty():
		return

	var body := JSON.stringify({"username": username})
	var err := _season_claim_http.request(
		"%s/season/pass/buy" % Global.SERVER_BASE,
		Global.json_headers(),
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		push_warning("خطا در درخواست خرید بتل‌پس: %d" % err)
		return
	_buying_pass = true
	_season_action = "buy"
	_buy_button.disabled = true

func _on_tier_claim_requested(level: int, track: String) -> void:
	if level <= 0 or _claiming_level > 0:
		return
	var username: String = str(Global.my_username)
	if username.is_empty():
		return

	var body := JSON.stringify({"username": username, "level": level, "track": track})
	var err := _season_claim_http.request(
		"%s/season/pass/claim" % Global.SERVER_BASE,
		Global.json_headers(),
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		push_warning("خطا در درخواست دریافت پله: %d" % err)
		return
	_claiming_level = level
	_season_action = "tier"

func _on_season_claim_received(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	# یک HTTPRequest برای هر سه کار (پله، چالش، خرید) استفاده می‌شود، پس هر
	# سه قفل با هم باز می‌شوند
	_claiming_level = 0
	_claiming_challenge = ""
	_buying_pass = false

	var action := _season_action
	_season_action = ""

	var data := _parse(result, response_code, body)
	if data.is_empty():
		_show_toast(_error_message(body, "جایزه دریافت نشد."))
		refresh_season()
		return

	_apply_season(data)
	# پاسخ‌های فصل «level» را برای پله‌ی بتل‌پس دارند، نه سطح بازیکن
	_sync_wallet(data, true)

	match action:
		"buy":
			RewardPopup.show_rewards([{
				"icon": "crown", "amount": 0, "label": "بتل پس طلایی",
			}], "خرید موفق")
		"challenge":
			RewardPopup.show_rewards(
				RewardPopup.items_from_reward(data.get("reward", {})), "چالش فصل تمام شد")
		_:
			# اسکینِ تازه از همین پاسخ به انبار اضافه می‌شود
			if data.has("owned_skins"):
				Global.apply_skin_response(data)
			RewardPopup.show_rewards(
				RewardPopup.items_from_reward(data.get("reward", {})), "پاداش فصل")

# ------------------------------------------------------------------- کمکی‌ها

func _parse(result: int, response_code: int, body: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("درخواست ناموفق. کد: %d" % response_code)
		return {}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("پاسخ سرور قابل خواندن نبود")
		return {}
	return json.data

## پیام خطای سرور ({"error": "..."}) — اگر نبود، متن پیش‌فرض
func _error_message(body: PackedByteArray, fallback: String) -> String:
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) == OK and typeof(json.data) == TYPE_DICTIONARY:
		var message := str((json.data as Dictionary).get("error", ""))
		if not message.is_empty():
			return message
	return fallback

## موجودی تازه را در Global می‌نشاند تا نوار بالای صفحه هم به‌روز شود.
## عمداً از پاسخ سرور خوانده می‌شود نه با جمع زدن محلی — سرور همیشه مرجع است.
##
## season: پاسخ‌های /season/* فیلد «level» را برای پله‌ی بتل‌پس دارند و سطح خود
## بازیکن را در «player_level» می‌فرستند. قبلاً سطح بتل‌پس روی سطح بازیکن
## نوشته می‌شد و نوار بالا بعد از هر جایزه‌ی فصل سطح اشتباه نشان می‌داد.
func _sync_wallet(data: Dictionary, season: bool = false) -> void:
	Global.note_wallet_changed()
	if data.has("coins"):
		Global.coins = int(data["coins"])
	if data.has("gems"):
		Global.gems = int(data["gems"])

	var prefix := "player_" if season else ""
	if data.has(prefix + "level"):
		Global.level = int(data[prefix + "level"])
	if data.has(prefix + "level_xp"):
		Global.display_xp = int(data[prefix + "level_xp"])
	if data.has(prefix + "level_max"):
		Global.max_xp = int(data[prefix + "level_max"])
	Global.player_data_updated.emit()

## پیام کوتاه پایین صفحه (مثلاً «+۲۰۰ سکه»)
func _show_toast(message: String) -> void:
	_toast_token += 1
	var token := _toast_token

	_toast.text = message
	_toast.visible = true
	_toast.modulate.a = 0.0
	create_tween().tween_property(_toast, "modulate:a", 1.0, 0.18)

	await get_tree().create_timer(2.2).timeout
	# اگر در این فاصله پیام تازه‌ای آمده، این یکی دیگر کاری ندارد
	if not is_instance_valid(_toast) or token != _toast_token:
		return
	create_tween().tween_property(_toast, "modulate:a", 0.0, 0.25)
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(_toast) and token == _toast_token:
		_toast.visible = false

func _on_home_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

# ------------------------------------------------------- دکمه‌ی Back اندروید

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()
	elif what == NOTIFICATION_EXIT_TREE:
		get_tree().set_quit_on_go_back(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()

## Back = همان دکمه‌ی خانه‌ی بالای صفحه؛ اگر پنجره‌ی جایزه باز است، اول
## خودش بسته می‌شود
func _on_back() -> void:
	var frame := Engine.get_process_frames()
	if frame == _back_frame:
		return
	_back_frame = frame
	if is_instance_valid(RewardPopup._active):
		return
	_on_home_pressed()
