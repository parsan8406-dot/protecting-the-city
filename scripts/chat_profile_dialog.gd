extends Control
## کارت پروفایل یک بازیکن که در چت پیام داده — با دکمه‌ی درخواست دوستی.
##
## در چت جهانی و چت شهر، بازیکن روی آواتار هر پیام ضربه می‌زند و این کارت
## باز می‌شود: عکس، اسم، سطح، وضعیت آنلاین، شهر و رده‌ی رتبه‌بندی، و اگر
## طرف مقابل هنوز دوستش نیست، دکمه‌ی «درخواست دوستی».
##
## سرور: POST /friends/request {username, target_id}
## (همان مسیری که تب دوستان استفاده می‌کند — پیام درخواست در صندوق طرف
## مقابل می‌نشیند و اگر آنلاین باشد همان لحظه هم خبردار می‌شود.)
##
## استفاده:
##   var dialog := preload("res://secense/chat_profile_dialog.tscn").instantiate()
##   add_child(dialog)
##   dialog.open(message_data, is_online, is_friend)

## درخواست دوستی با موفقیت رفت — چت اصلی لیست را تازه می‌کند
signal friend_requested(player_id: String)

@onready var _dim: ColorRect = $Dim
@onready var _card: PanelContainer = $Card
@onready var _avatar: TextureRect = $Card/Margin/Col/TopRow/AvatarSlot/Avatar
@onready var _online_dot: Panel = $Card/Margin/Col/TopRow/AvatarSlot/OnlineDot
@onready var _level_label: Label = $Card/Margin/Col/TopRow/AvatarSlot/LevelLabel
@onready var _name_label: Label = $Card/Margin/Col/TopRow/Info/NameLabel
@onready var _status_label: Label = $Card/Margin/Col/TopRow/Info/StatusLabel
@onready var _clan_label: Label = $Card/Margin/Col/TopRow/Info/ClanLabel
@onready var _tier_row: HBoxContainer = $Card/Margin/Col/TierRow
@onready var _tier_label: Label = $Card/Margin/Col/TierRow/TierValue
@onready var _tier_badge: TextureRect = $Card/Margin/Col/TierRow/TierBadge
@onready var _result_label: Label = $Card/Margin/Col/ResultLabel
@onready var _add_button: Button = $Card/Margin/Col/Actions/AddButton
@onready var _close_button: Button = $Card/Margin/Col/Actions/CloseButton
@onready var _http: HTTPRequest = $HTTPRequest

var _player_id: String = ""
var _busy := false

# ------------------------------------------------------------------ چرخه‌ی حیات

func _ready() -> void:
	_http.request_completed.connect(_on_request_completed)
	_add_button.pressed.connect(_on_add_pressed)
	_close_button.pressed.connect(func() -> void: UIFx.tap(_close_button, close))
	_dim.gui_input.connect(_on_dim_input)

	UIFx.bind_press_feedback(_add_button)
	UIFx.bind_press_feedback(_close_button)

## باز کردن کارت.
##   data      : همان دیکشنری پیام (sender_id, sender_name, sender_avatar, ...)
##   is_online : فرستنده همین الان آنلاین است یا نه
##   is_friend : از قبل دوست هستند یا نه (از لیست گفتگوهای خصوصی می‌آید)
func open(data: Dictionary, is_online: bool, is_friend: bool) -> void:
	_player_id = str(data.get("sender_id", ""))

	_name_label.text = str(data.get("sender_name", "—"))
	_level_label.text = str(int(data.get("sender_level", 1)))
	_online_dot.visible = is_online

	_status_label.text = "آنلاین" if is_online else "آفلاین"
	_status_label.add_theme_color_override("font_color",
		Color(0.36, 0.85, 0.42, 1.0) if is_online else Color(0.65, 0.65, 0.68, 1.0))

	var clan := str(data.get("sender_clan", ""))
	_clan_label.text = "شهر : %s" % (clan if not clan.is_empty() else "بدون شهر")

	var tier := str(data.get("sender_tier", ""))
	_tier_label.text = tier
	_tier_row.visible = not tier.is_empty()

	# چت فقط اسم فارسی رده را می‌فرستد؛ RankArt خودش اسم را به نشان نگاشت می‌کند
	_tier_badge.texture = RankArt.texture_for(str(data.get("sender_tier_id", "")), tier)
	_tier_badge.visible = _tier_badge.texture != null

	var texture := AvatarPicker.load_avatar_texture(str(data.get("sender_avatar", "")))
	if texture == null:
		var ids := AvatarPicker.list_avatar_ids()
		if not ids.is_empty():
			texture = AvatarPicker.load_avatar_texture(ids[0])
	_avatar.texture = texture

	# دکمه فقط وقتی معنی دارد که غریبه باشد
	if _player_id == str(Global.player_id):
		_set_result("این پروفایل خودت است", false)
		_add_button.visible = false
	elif is_friend:
		_set_result("از قبل دوستت است", false)
		_add_button.visible = false
	else:
		_result_label.visible = false
		_add_button.visible = true
		_add_button.disabled = false
		_add_button.text = "درخواست دوستی"

	_play_open()

func close() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_card, "scale", Vector2(0.92, 0.92), 0.14) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.14).set_trans(Tween.TRANS_SINE)
	tween.chain().tween_callback(queue_free)

# ------------------------------------------------------------------ درخواست دوستی

func _on_add_pressed() -> void:
	if _busy or _player_id.is_empty():
		return

	var payload := {"username": Global.my_username, "target_id": _player_id}
	var err := _http.request(
		Global.SERVER_BASE + "/friends/request",
		Global.json_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if err != OK:
		_set_result("ارتباط با سرور برقرار نشد", true)
		return

	_busy = true
	_add_button.disabled = true
	_add_button.text = "در حال ارسال ..."

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false

	if result == HTTPRequest.RESULT_SUCCESS and (response_code == 200 or response_code == 201):
		_add_button.visible = false
		_set_result("درخواست دوستی فرستاده شد", false)
		friend_requested.emit(_player_id)
		return

	# سرور خودش پیام فارسی می‌دهد (از قبل دوست است، قبلاً فرستاده شده، ...)
	var message := "درخواست فرستاده نشد (کد %d)" % response_code
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("error"):
		message = str((parsed as Dictionary)["error"])

	# ۴۰۹ یعنی «از قبل دوست است» یا «قبلاً فرستادی» — تلاش دوباره فایده ندارد
	if response_code == 409:
		_add_button.visible = false
		_set_result(message, false)
		return

	_add_button.disabled = false
	_add_button.text = "درخواست دوستی"
	_set_result(message, true)

## نوشتن پیام نتیجه زیر کارت
func _set_result(text: String, is_error: bool) -> void:
	_result_label.text = text
	_result_label.visible = true
	_result_label.add_theme_color_override("font_color",
		Color(1.0, 0.55, 0.5, 1.0) if is_error else Color(0.85, 0.78, 0.45, 1.0))

# ------------------------------------------------------------------ بستن و انیمیشن

## زدن روی فضای تیره‌ی پشت کارت هم می‌بندد
func _on_dim_input(event: InputEvent) -> void:
	var tapped: bool = event is InputEventScreenTouch and not event.pressed
	var clicked: bool = event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed
	if tapped or clicked:
		close()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _play_open() -> void:
	modulate.a = 0.0
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.94, 0.94)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_card, "scale", Vector2.ONE, 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
