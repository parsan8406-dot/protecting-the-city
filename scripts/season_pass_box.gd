extends TextureRect
## کارت «پاداش فصل» (بتل‌پس) در منوی استارت.
##
## کارت از قبل در main_menu.tscn کشیده شده بود؛ اینجا فقط به سرور وصل می‌شود.
## هیچ عددی سمت کلاینت حساب نمی‌شود — پله، تجربه و جایزه‌ها همه از
## GET /season/pass می‌آیند (handlers_missions.go).
##
## دکمه‌ی پایین کارت صفحه‌ی کامل پاداش فصل را باز می‌کند.

const MISSIONS_SCREEN := "res://secense/missions_screen.tscn"
const PsychProgress := preload("res://scripts/psych_results_progress.gd")

## محل نوار پیشرفت روی تصویر کارت (startmenu_Battlepass.png، ۶۴۳×۲۱۸).
## نود دقیقاً هم‌اندازه‌ی تصویر است (فقط scale=0.6 دارد)، پس مختصات پیکسلی امن است.
const TRACK_LEFT := 131.0
const TRACK_RIGHT := 546.0

@onready var _level_label: Label = $BattlepassnumberLabel
@onready var _season_label: Label = $BattlepassseasonLabel
@onready var _xp_label: Label = $BattlepassexprienceLabel
@onready var _fill: TextureRect = $BattlepassFill
@onready var _see_button: TextureButton = $SeeresultButton

var _http: HTTPRequest = null
var _busy := false

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_pass_received)

	UIFx.bind_press(_see_button, _open_screen)
	_fit_xp_label()

	# مثل پنل ماموریت‌ها: اگر Global هنوز لود نشده، بعدش دوباره می‌گیریم
	if not Global.player_data_loaded.is_connected(refresh):
		Global.player_data_loaded.connect(refresh)

	refresh()

## گرفتن دوباره‌ی وضعیت پاداش فصل از سرور
func refresh() -> void:
	var username: String = str(Global.my_username)
	if username.is_empty() or _busy:
		return

	var url := "%s/season/pass?username=%s" % [Global.SERVER_BASE, username.uri_encode()]
	if _http.request(url, Global.auth_headers()) != OK:
		push_warning("خطا در درخواست پاداش فصل")
		return
	_busy = true

func _on_pass_received(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	_busy = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("پاداش فصل از سرور نیامد. کد: %d" % response_code)
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("پاسخ پاداش فصل قابل خواندن نبود")
		return

	_apply(json.data)

func _apply(data: Dictionary) -> void:
	var level := int(data.get("level", 1))
	_level_label.text = MissionArt.fa_number(level)

	# "season_1" → "۱"
	var season_id := str(data.get("season_id", ""))
	var number := season_id.get_slice("_", season_id.get_slice_count("_") - 1)
	_season_label.text = MissionArt.fa_number(number.to_int()) if number.is_valid_int() else "—"

	var into := int(data.get("level_xp", 0))
	var need := maxi(int(data.get("level_max", 1)), 1)
	_xp_label.text = "%s/%s" % [MissionArt.fa_number(into), MissionArt.fa_number(need)]
	_shrink_xp_to_fit()

	# C9 پیشرفتِ اهدایی: اولِ هر پله نوار کاملاً خالی دیده نمی‌شود
	_set_fill(PsychProgress.visual_ratio(into, need))

## نوار پیشرفت پله‌ی فعلی
func _set_fill(ratio: float) -> void:
	if _fill == null:
		return
	ratio = clampf(ratio, 0.0, 1.0)
	_fill.offset_left = TRACK_LEFT
	var target := TRACK_LEFT + (TRACK_RIGHT - TRACK_LEFT) * ratio
	_fill.visible = ratio > 0.0

	# نوار با انیمیشن پر می‌شود تا حرکتش دیده شود
	_fill.offset_right = TRACK_LEFT
	create_tween().tween_property(_fill, "offset_right", target, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _open_screen() -> void:
	Global.request_missions_tab("season")
	get_tree().change_scene_to_file(MISSIONS_SCREEN)

## V10 «۴۱۰/۵۰۰» در صحنه فقط ۴۳ پیکسل جا داشت و به هم فشرده می‌شد: جا را
## به سمتِ وسطِ کارت باز می‌کنیم (لبه‌ی راست سرِ جایش می‌ماند) و عدد راست‌چین
## می‌شود؛ اگر عددِ خیلی بزرگ باز هم جا نشد، فونت کمی کوچک می‌شود.
func _fit_xp_label() -> void:
	if _xp_label == null:
		return
	_xp_label.offset_left = _xp_label.offset_right - 190.0
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_xp_label.clip_text = false
	_xp_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING


func _shrink_xp_to_fit() -> void:
	var font := _xp_label.get_theme_font("font")
	var fs := 30
	while fs > 20 and font.get_string_size(_xp_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 186.0:
		fs -= 2
	_xp_label.add_theme_font_size_override("font_size", fs)
