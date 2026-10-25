extends TextureRect
## پنل «ماموریت های روزانه» در منوی استارت.
##
## این پنل و سه ردیفش از قبل در main_menu.tscn کشیده شده بودند؛ اینجا فقط
## به سرور وصل می‌شوند. هیچ عددی اینجا حساب نمی‌شود:
##   - پیشرفت و جایزه‌ی هر ماموریت از GET /missions/daily می‌آید
##   - تایمر ریست هم از سرور می‌آید (seconds_left)، نه از ساعت گوشی
##   - «دریافت» فقط POST /missions/claim می‌زند و سرور تصمیم می‌گیرد
##
## سه ردیف بیشتر جا نداریم ولی سرور شش ماموریت می‌دهد، پس مفیدترین‌ها را
## بالا می‌آوریم (آماده‌ی دریافت → در حال انجام → گرفته‌شده) و بقیه در
## صفحه‌ی «همه ماموریت ها» دیده می‌شوند.

const MISSIONS_SCREEN := "res://secense/missions_screen.tscn"
const PsychProgress := preload("res://scripts/psych_results_progress.gd")

## سه ردیفی که در منو جا می‌شوند
const ROWS_IN_MENU := 3

## محل نوار پیشرفت روی تصویر ردیف (startmenu_g43-1.png، ۵۸۶ پیکسل عرض).
## نسبت ذخیره می‌شود نه پیکسل، تا اگر عرض پنل عوض شد نوار هم درست بماند.
const TRACK_LEFT := 63.0 / 586.0
const TRACK_RIGHT := 436.0 / 586.0

## ارتفاع نوار پیشرفت (پیکسل، دور مرکز عمودی ردیف)
const TRACK_HEIGHT := 8.0

## انگشت اگر بیشتر از این جابه‌جا شود یعنی داشته اسکرول/کشیدن می‌کرده
const DRAG_THRESHOLD := 12.0

@onready var _time_label: Label = $TimeLabel
@onready var _all_button: TextureRect = $AllmissionsButton
@onready var _rows_box: VBoxContainer = $VBoxContainer

## HTTPRequest در صحنه نیست؛ در کد ساخته می‌شود تا main_menu.tscn دست نخورد
var _http: HTTPRequest = null
var _claim_http: HTTPRequest = null

var _busy := false
var _claiming := ""
## ماموریت‌هایی که الان روی سه ردیف نشسته‌اند (به همان ترتیب)
var _shown: Array[Dictionary] = []
## ثانیه‌های باقی‌مانده تا ریست — از سرور می‌آید و اینجا فقط کم می‌شود
var _seconds_left := 0
var _tick := 0.0

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_missions_received)

	_claim_http = HTTPRequest.new()
	add_child(_claim_http)
	_claim_http.request_completed.connect(_on_claim_received)

	# AllmissionsButton یک TextureRect است نه دکمه، پس تپ را دستی می‌گیریم
	_all_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_all_button.gui_input.connect(_on_all_button_input)

	for i in ROWS_IN_MENU:
		var row := _row(i)
		if row == null:
			continue
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.gui_input.connect(_on_row_input.bind(i))

	_time_label.text = ""

	# اگر منو زودتر از Global بالا بیاید هنوز نام کاربری نداریم؛ وقتی دیتا
	# لود شد دوباره می‌گیریم.
	if not Global.player_data_loaded.is_connected(refresh):
		Global.player_data_loaded.connect(refresh)

	refresh()

## ردیف i ام (Mission1 / Mission2 / Mission3)
func _row(index: int) -> TextureRect:
	return _rows_box.get_node_or_null("Mission%d" % (index + 1)) as TextureRect

# ------------------------------------------------------------------- تایمر

func _process(delta: float) -> void:
	if _seconds_left <= 0:
		return

	_tick += delta
	if _tick < 1.0:
		return
	var whole := int(_tick)
	_tick -= float(whole)
	_seconds_left = maxi(_seconds_left - whole, 0)
	_time_label.text = MissionArt.format_countdown(_seconds_left)

	# روز عوض شد → ماموریت‌های تازه را از سرور بگیر
	if _seconds_left == 0:
		refresh()

# ------------------------------------------------------------------ گرفتن دیتا

## گرفتن دوباره‌ی ماموریت‌ها از سرور
func refresh() -> void:
	var username: String = str(Global.my_username)
	if username.is_empty() or _busy:
		return

	var url := "%s/missions/daily?username=%s" % [Global.SERVER_BASE, username.uri_encode()]
	if _http.request(url, Global.auth_headers()) != OK:
		push_warning("خطا در درخواست ماموریت‌های روزانه")
		return
	_busy = true

func _on_missions_received(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	_busy = false

	var data := _parse(result, response_code, body)
	if data.is_empty():
		_time_label.text = ""
		return

	_apply(data)

func _parse(result: int, response_code: int, body: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("ماموریت‌های روزانه از سرور نیامد. کد: %d" % response_code)
		return {}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("پاسخ ماموریت‌ها قابل خواندن نبود")
		return {}
	return json.data

# ------------------------------------------------------------------ پر کردن UI

func _apply(data: Dictionary) -> void:
	_seconds_left = int(data.get("seconds_left", 0))
	_tick = 0.0
	_time_label.text = MissionArt.format_countdown(_seconds_left)

	_shown = _pick_rows(data.get("missions", []))

	for i in ROWS_IN_MENU:
		var row := _row(i)
		if row == null:
			continue
		if i >= _shown.size():
			row.visible = false
			continue
		row.visible = true
		_fill_row(row, _shown[i])

## مفیدترین ماموریت‌ها برای سه ردیف منو:
## اول آن‌هایی که جایزه‌شان آماده است، بعد در حال انجام، آخر گرفته‌شده‌ها.
func _pick_rows(missions: Array) -> Array[Dictionary]:
	var ready_list: Array[Dictionary] = []
	var active: Array[Dictionary] = []
	var done: Array[Dictionary] = []

	for item in missions:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var mission: Dictionary = item
		if bool(mission.get("claimed", false)):
			done.append(mission)
		elif bool(mission.get("done", false)):
			ready_list.append(mission)
		else:
			active.append(mission)

	# E7 زیگارنیک: بینِ ناتمام‌ها، نزدیک‌ترین به پایان اول
	active.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(int(a.get("progress", 0))) / float(maxi(int(a.get("target", 1)), 1)) \
			> float(int(b.get("progress", 0))) / float(maxi(int(b.get("target", 1)), 1)))

	var out: Array[Dictionary] = []
	out.append_array(ready_list)
	out.append_array(active)
	out.append_array(done)
	return out.slice(0, ROWS_IN_MENU)

func _fill_row(row: TextureRect, mission: Dictionary) -> void:
	var target := maxi(int(mission.get("target", 1)), 1)
	var progress := clampi(int(mission.get("progress", 0)), 0, target)
	var claimed := bool(mission.get("claimed", false))
	var done := bool(mission.get("done", false))

	var title := row.get_node_or_null("TitleLabel") as Label
	if title:
		title.text = str(mission.get("title", "—"))
		title.add_theme_color_override("font_color", _state_color(done, claimed))

	var amount := row.get_node_or_null("AmountLabel") as Label
	if amount:
		# ماموریتِ گرفته‌شده به‌جای عدد، «✓» نشان می‌دهد
		amount.text = "✓" if claimed else "%s/%s" % [
			MissionArt.fa_number(progress), MissionArt.fa_number(target)
		]
		amount.add_theme_color_override("font_color", _state_color(done, claimed))

	var xp := row.get_node_or_null("XpLabel") as Label
	if xp:
		xp.text = "%sxp" % MissionArt.fa_number(int(mission.get("xp", 0)))
		xp.add_theme_color_override("font_color", _state_color(done, claimed))

	# C9 پیشرفتِ اهدایی: نوارِ ناتمام هیچ‌وقت کاملاً خالی دیده نمی‌شود
	var ratio := 1.0 if done else PsychProgress.visual_ratio(progress, target)
	_set_fill(row, ratio, done, claimed)
	# C9 نزدیکِ پایان: نوار و عدد طلایی‌تر
	if not done and not claimed and PsychProgress.is_near(progress, target):
		var fill := row.get_node_or_null("MissionFill") as CanvasItem
		if fill != null:
			fill.modulate = Color(1.0, 0.86, 0.45)
		if amount:
			amount.add_theme_color_override("font_color", MissionArt.COLOR_GOLD)

	# ماموریتِ آماده کمی می‌تپد تا توی چشم بیاید
	row.modulate = Color(1, 1, 1, 0.55) if claimed else Color(1, 1, 1, 1)

## نوار پیشرفت را روی نسبت داده‌شده می‌نشاند (۰ تا ۱)
func _set_fill(row: TextureRect, ratio: float, done: bool, claimed: bool) -> void:
	var fill := row.get_node_or_null("MissionFill") as TextureRect
	if fill == null:
		return

	ratio = clampf(ratio, 0.0, 1.0)

	# با anchor کار می‌کنیم نه پیکسل، تا اگر عرض پنل عوض شد نوار هم درست بماند
	fill.anchor_left = TRACK_LEFT
	fill.anchor_right = TRACK_LEFT + (TRACK_RIGHT - TRACK_LEFT) * ratio
	fill.offset_left = 0.0
	fill.offset_right = 0.0

	fill.anchor_top = 0.5
	fill.anchor_bottom = 0.5
	fill.offset_top = -TRACK_HEIGHT * 0.5
	fill.offset_bottom = TRACK_HEIGHT * 0.5

	# نوارِ ماموریتِ تمام‌شده طلایی می‌شود، گرفته‌شده کم‌رنگ
	fill.visible = ratio > 0.0
	if claimed:
		fill.modulate = Color(0.55, 0.55, 0.58, 1.0)
	elif done:
		fill.modulate = MissionArt.COLOR_READY
	else:
		fill.modulate = Color(1, 1, 1, 1)

func _state_color(done: bool, claimed: bool) -> Color:
	if claimed:
		return MissionArt.COLOR_CLAIMED
	if done:
		return MissionArt.COLOR_READY
	return MissionArt.COLOR_ACTIVE

# ------------------------------------------------------------------ تپ روی ردیف

var _touch_start := Vector2.ZERO
var _swiping := false

func _on_row_input(event: InputEvent, index: int) -> void:
	if not _is_tap(event):
		return
	if index >= _shown.size():
		return

	var mission: Dictionary = _shown[index]
	# فقط ماموریتِ تمام‌شده‌ی گرفته‌نشده جایزه دارد؛ بقیه صفحه‌ی کامل را باز می‌کنند
	if bool(mission.get("done", false)) and not bool(mission.get("claimed", false)):
		_claim(str(mission.get("mission_id", "")))
	else:
		_open_all_missions()

func _on_all_button_input(event: InputEvent) -> void:
	if _is_tap(event):
		_open_all_missions()

## تپِ بدون کشیدن. (روی موبایل هر لمسی ممکن است شروع یک اسکرول باشد.)
func _is_tap(event: InputEvent) -> bool:
	if event is InputEventScreenTouch or (
		event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
	):
		if event.pressed:
			_touch_start = event.position
			_swiping = false
			return false
		return not _swiping

	var dragging: bool = event is InputEventScreenDrag or (
		event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	)
	if dragging and event.position.distance_to(_touch_start) > DRAG_THRESHOLD:
		_swiping = true
	return false

func _open_all_missions() -> void:
	Global.request_missions_tab("daily")
	get_tree().change_scene_to_file(MISSIONS_SCREEN)

# ------------------------------------------------------------------ دریافت جایزه

func _claim(mission_id: String) -> void:
	if mission_id.is_empty() or not _claiming.is_empty():
		return
	var username: String = str(Global.my_username)
	if username.is_empty():
		return

	var body := JSON.stringify({"username": username, "mission_id": mission_id})
	var err := _claim_http.request(
		"%s/missions/claim" % Global.SERVER_BASE,
		Global.json_headers(),
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		push_warning("خطا در درخواست دریافت جایزه: %d" % err)
		return
	_claiming = mission_id

func _on_claim_received(
	result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	_claiming = ""

	var data := _parse(result, response_code, body)
	if data.is_empty():
		# سرور جایزه را نداد (مثلاً قبلاً گرفته شده) — لیست را تازه می‌کنیم
		refresh()
		return

	# پاسخِ claim خودش لیست تازه را دارد، پس درخواست دوم لازم نیست
	_apply(data)
	_sync_wallet(data)

	# قبلاً اینجا جایزه بی‌صدا واریز می‌شد؛ حالا همان صفحه‌ی جایزه‌ی مشترک
	RewardPopup.show_rewards(
		RewardPopup.items_from_reward(data.get("reward", {})), "ماموریت انجام شد")

## موجودی تازه را در Global می‌نشاند تا نوار بالای صفحه هم به‌روز شود
func _sync_wallet(data: Dictionary) -> void:
	Global.note_wallet_changed()
	if data.has("coins"):
		Global.coins = int(data["coins"])
	if data.has("gems"):
		Global.gems = int(data["gems"])
	if data.has("level"):
		Global.level = int(data["level"])
	if data.has("level_xp"):
		Global.display_xp = int(data["level_xp"])
	if data.has("level_max"):
		Global.max_xp = int(data["level_max"])
	Global.player_data_updated.emit()
