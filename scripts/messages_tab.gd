extends Control
## تب «پیام‌ها» — صندوق پیام بازیکن.
##
## سه جور پیام اینجا می‌نشیند:
##   system / admin  → پیام از بازی
##   friend_request  → درخواست دوستی (پذیرفتن / رد)
##   gift / reward   → هدیه یا جایزه (دریافت جایزه)
##
## سرور (handlers_social.go):
##   GET  /messages?username=...     لیست + unread_count
##   POST /messages/read             {username, message_id}
##   POST /messages/read_all         {username}
##   POST /messages/claim            {username, message_id}
##   POST /messages/claim_all        {username}
##   POST /messages/delete           {username, message_id}
##   POST /friends/respond           {username, request_id, accept}

const MESSAGE_ROW_SCENE := preload("res://secense/message_row.tscn")

const TYPE_FRIEND_REQUEST := "friend_request"
const TYPE_GIFT := "gift"
const TYPE_REWARD := "reward"

## فیلترهای بالای لیست: [شناسه، عنوان]
const FILTERS := [["all", "همه"], ["reward", "جایزه‌ها"], ["friend_request", "درخواست‌ها"], ["system", "سیستم"]]

const TYPE_TITLES := {
	"friend_request": "درخواست دوستی",
	"gift": "هدیه از دوست",
	"reward": "جایزه",
	"admin": "پشتیبانی",
}

## تایمر فقط تور ایمنی است — رفرش اصلی با سیگنال بلادرنگ Global.social_event می‌آید
const AUTO_REFRESH_SECONDS := 20.0

@onready var _http: HTTPRequest = $HTTPRequest
@onready var _action_http: HTTPRequest = $ActionHTTPRequest
@onready var _refresh_timer: Timer = $RefreshTimer

@onready var _claim_all_button: Button = $Columns/ListPanel/Margin/Body/HeaderRow/ClaimAllButton
@onready var _read_all_button: Button = $Columns/ListPanel/Margin/Body/HeaderRow/ReadAllButton
@onready var _count_label: Label = $Columns/ListPanel/Margin/Body/HeaderRow/CountLabel
@onready var _filters_box: HBoxContainer = $Columns/ListPanel/Margin/Body/Filters
@onready var _scroll: ScrollContainer = $Columns/ListPanel/Margin/Body/Scroll
@onready var _list: VBoxContainer = $Columns/ListPanel/Margin/Body/Scroll/List
@onready var _empty_box: VBoxContainer = $Columns/ListPanel/Margin/Body/EmptyBox
@onready var _empty_label: Label = $Columns/ListPanel/Margin/Body/EmptyBox/EmptyLabel
@onready var _retry_button: Button = $Columns/ListPanel/Margin/Body/EmptyBox/RetryButton

@onready var _detail_time: Label = $Columns/DetailPanel/Margin/Body/MetaRow/TimeLabel
@onready var _detail_type: Label = $Columns/DetailPanel/Margin/Body/MetaRow/TypeLabel
@onready var _detail_icon: TextureRect = $Columns/DetailPanel/Margin/Body/MetaRow/TypeIcon
@onready var _detail_title: Label = $Columns/DetailPanel/Margin/Body/TitleLabel
@onready var _detail_sender: Label = $Columns/DetailPanel/Margin/Body/SenderLabel
@onready var _detail_body: Label = $Columns/DetailPanel/Margin/Body/BodyPanel/Margin/Scroll/BodyLabel
@onready var _detail_scroll: ScrollContainer = $Columns/DetailPanel/Margin/Body/BodyPanel/Margin/Scroll
@onready var _read_tick: Label = $Columns/DetailPanel/Margin/Body/BodyPanel/ReadTick
@onready var _reward_box: PanelContainer = $Columns/DetailPanel/Margin/Body/RewardBox
@onready var _reward_chips: HBoxContainer = $Columns/DetailPanel/Margin/Body/RewardBox/Margin/Row/Chips
@onready var _reward_title: Label = $Columns/DetailPanel/Margin/Body/RewardBox/Margin/Row/RewardTitle
@onready var _action_row: HBoxContainer = $Columns/DetailPanel/Margin/Body/ActionRow
@onready var _primary_button: Button = $Columns/DetailPanel/Margin/Body/ActionRow/PrimaryButton
@onready var _secondary_button: Button = $Columns/DetailPanel/Margin/Body/ActionRow/SecondaryButton

@onready var _toast: PanelContainer = $Toast
@onready var _toast_label: Label = $Toast/ToastLabel

var _messages: Array = []
var _selected_id: String = ""
var _filter := "all"
var _filter_buttons: Dictionary = {}
var _busy := false
var _loaded_once := false
var _toast_tween: Tween
## کاری که الان روی سرور در جریان است: {kind, message_id, reward}
var _pending: Dictionary = {}

# ------------------------------------------------------------------ آماده‌سازی

func _ready() -> void:
	_http.request_completed.connect(_on_messages_received)
	_action_http.request_completed.connect(_on_action_completed)

	for pair in [[_claim_all_button, "gold"], [_read_all_button, "dark"], [_retry_button, "dark"],
			[_primary_button, "gold"], [_secondary_button, "ghost"]]:
		MenuUI.style_button(pair[0], pair[1])
		UIFx.bind_press_feedback(pair[0])
	_claim_all_button.pressed.connect(_on_claim_all_pressed)
	_read_all_button.pressed.connect(_on_read_all_pressed)
	_retry_button.pressed.connect(refresh)
	_primary_button.pressed.connect(func() -> void:
		UIFx.press(_primary_button)
		_on_primary_pressed(_selected_id))
	_secondary_button.pressed.connect(func() -> void:
		UIFx.press(_secondary_button)
		_on_dismiss_pressed(_selected_id))

	for f in FILTERS:
		var b := MenuUI.button(f[1], "dark", 16)
		b.custom_minimum_size = Vector2(88, 46)
		b.pressed.connect(_set_filter.bind(f[0]))
		_filters_box.add_child(b)
		_filter_buttons[f[0]] = b
	_refresh_filter_buttons()

	UIScroll.attach(_scroll)
	UIScroll.attach(_detail_scroll)
	_toast.visible = false
	_set_detail_empty()

	_refresh_timer.wait_time = AUTO_REFRESH_SECONDS
	_refresh_timer.timeout.connect(refresh)
	visibility_changed.connect(_on_visibility_changed)

	# سرور روی WebSocket خبر می‌دهد؛ همان لحظه لیست را تازه می‌کنیم
	Global.social_event.connect(_on_social_event)
	Global.account_switched.connect(_on_account_switched)

	refresh()
	if is_visible_in_tree():
		_consume_requested_filter()
		_refresh_timer.start()

func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_consume_requested_filter()
		refresh()
		_refresh_timer.start()
	else:
		_refresh_timer.stop()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and is_inside_tree() and is_visible_in_tree():
		refresh()

## نوار «درخواست‌های در انتظار» تب دوستان این‌جا را با فیلتر درخواست‌ها باز می‌کند
func _consume_requested_filter() -> void:
	var requested := str(Global.requested_messages_filter)
	Global.requested_messages_filter = ""
	if not requested.is_empty():
		_set_filter(requested)

## هر اتفاق اجتماعی (درخواست دوستی، هدیه، دستاورد، ...) صندوق را تازه می‌کند
func _on_social_event(_kind: String) -> void:
	refresh()

func _on_account_switched() -> void:
	_messages.clear()
	_selected_id = ""
	_loaded_once = false
	refresh()

## گرفتن دوباره‌ی صندوق پیام از سرور
func refresh() -> void:
	var username := str(Global.my_username)
	if username.is_empty():
		return
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var url := "%s/messages?username=%s" % [Global.SERVER_BASE, username.uri_encode()]
	if _http.request(url, Global.auth_headers()) != OK:
		_show_list_error("اتصال به سرور برقرار نشد")

# ------------------------------------------------------------------ پاسخ سرور

func _on_messages_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		if _messages.is_empty():
			_show_list_error(MenuUI.server_error(body, response_code if result == HTTPRequest.RESULT_SUCCESS else 0,
				"پیام‌ها از سرور نیامد"))
		return

	var data := MenuUI.parse_json(body)
	var raw = data.get("messages", [])
	_messages = raw if raw is Array else []

	# نشان قرمز TopBar و تب از همین‌جا سینک می‌شود (بدون درخواست اضافه)
	Global.set_unread_count(int(data.get("unread_count", 0)))

	# کارهای مانده بالا (نخوانده / جایزه‌ی دریافت‌نشده / درخواست)، بعد جدیدترین
	_messages.sort_custom(func(a, b) -> bool:
		var a_top := _needs_attention(a)
		var b_top := _needs_attention(b)
		if a_top != b_top:
			return a_top
		return str(a.get("created_at", "")) > str(b.get("created_at", "")))

	_build_list()

func _needs_attention(m) -> bool:
	if not (m is Dictionary):
		return false
	return not bool(m.get("is_read", false)) or MessageRow.reward_pending(m) \
		or str(m.get("type", "")) == TYPE_FRIEND_REQUEST

func _matches_filter(m: Dictionary) -> bool:
	var t := str(m.get("type", ""))
	match _filter:
		"reward": return t == TYPE_GIFT or t == TYPE_REWARD
		"friend_request": return t == TYPE_FRIEND_REQUEST
		"system": return t != TYPE_GIFT and t != TYPE_REWARD and t != TYPE_FRIEND_REQUEST
	return true

func _build_list() -> void:
	var shown: Array = []
	for m in _messages:
		if m is Dictionary and _matches_filter(m):
			shown.append(m)

	_update_header()

	var ids: Array[String] = []
	for m in shown:
		ids.append(str(m.get("message_id", "")))
	var existing: Array[String] = []
	var rows: Array = []
	for child in _list.get_children():
		if child is MessageRow and not child.is_queued_for_deletion():
			existing.append(child.message_id)
			rows.append(child)

	if ids == existing:
		# همان ترکیب — فقط محتوا به‌روز (بدون چشمک و پرش اسکرول)
		for i in rows.size():
			rows[i].setup(shown[i])
	else:
		for child in _list.get_children():
			child.queue_free()
		for m in shown:
			var row: MessageRow = MESSAGE_ROW_SCENE.instantiate()
			row.setup(m)
			row.row_selected.connect(func(r: MessageRow) -> void: _select(r.message_id, true))
			row.primary_pressed.connect(_on_primary_pressed)
			row.dismiss_pressed.connect(_on_dismiss_pressed)
			_list.add_child(row)
		if not _loaded_once:
			_play_intro()
	_loaded_once = true

	var empty := shown.is_empty()
	_scroll.visible = not empty
	_empty_box.visible = empty
	_retry_button.visible = false
	if empty:
		_empty_label.text = "صندوق پیامت خالی است" if _filter == "all" else "پیامی در این دسته نیست"

	if _find_message(_selected_id).is_empty() or not ids.has(_selected_id):
		if not shown.is_empty():
			_select(str(shown[0].get("message_id", "")), false)
		else:
			_set_detail_empty()
	else:
		_apply_detail(_find_message(_selected_id))
	_refresh_row_selection()

func _update_header() -> void:
	var unread := 0
	var claimable := 0
	for m in _messages:
		if not (m is Dictionary):
			continue
		if not bool(m.get("is_read", false)):
			unread += 1
		if MessageRow.reward_pending(m):
			claimable += 1
	var text := "%s پیام" % MenuUI.fa(_messages.size())
	if unread > 0:
		text += "  •  %s نخوانده" % MenuUI.fa(unread)
	_count_label.text = text
	_read_all_button.visible = unread > 0
	_claim_all_button.visible = claimable > 1
	_claim_all_button.text = "دریافت همه (%s)" % MenuUI.fa(claimable)

func _show_list_error(message: String) -> void:
	_scroll.visible = false
	_empty_box.visible = true
	_empty_label.text = message
	_retry_button.visible = true

func _find_message(message_id: String) -> Dictionary:
	if message_id.is_empty():
		return {}
	for item in _messages:
		if item is Dictionary and str(item.get("message_id", "")) == message_id:
			return item
	return {}

func _find_row(message_id: String) -> MessageRow:
	for child in _list.get_children():
		if child is MessageRow and child.message_id == message_id:
			return child
	return null

func _set_filter(value: String) -> void:
	if _filter == value or not _filter_buttons.has(value):
		return
	_filter = value
	_refresh_filter_buttons()
	_loaded_once = false
	_build_list()

func _refresh_filter_buttons() -> void:
	for key in _filter_buttons:
		MenuUI.style_button(_filter_buttons[key], "gold" if key == _filter else "dark")

# ------------------------------------------------------------------ انتخاب پیام

## انتخاب یک پیام؛ اگر خوانده‌نشده باشد به سرور هم خبر می‌دهد
func _select(message_id: String, mark_as_read: bool) -> void:
	var data := _find_message(message_id)
	if data.is_empty():
		return
	var changed := message_id != _selected_id
	_selected_id = message_id
	_refresh_row_selection()
	_apply_detail(data)
	if changed:
		_detail_scroll.scroll_vertical = 0
	if mark_as_read and not bool(data.get("is_read", false)):
		_mark_read(message_id)

func _refresh_row_selection() -> void:
	for child in _list.get_children():
		if child is MessageRow:
			child.set_selected(child.message_id == _selected_id)

func _mark_read(message_id: String) -> void:
	var data := _find_message(message_id)
	if data.is_empty():
		return
	data["is_read"] = true
	var row := _find_row(message_id)
	if row:
		row.mark_read()
	_read_tick.visible = true
	Global.set_unread_count(Global.unread_messages - 1)
	_update_header()
	# جواب این درخواست مهم نیست؛ اگر نرسید، رفرش بعدی درستش می‌کند.
	# از HTTPRequest جدا می‌رود تا کارهای اصلی (دریافت جایزه) منتظرش نمانند.
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r: int, _c: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		http.queue_free())
	if http.request(Global.SERVER_BASE + "/messages/read", Global.json_headers(), HTTPClient.METHOD_POST,
			JSON.stringify({"username": Global.my_username, "message_id": message_id})) != OK:
		http.queue_free()

# ------------------------------------------------------------------ کارت راست

func _apply_detail(data: Dictionary) -> void:
	if data.is_empty():
		_set_detail_empty()
		return
	var msg_type := str(data.get("type", ""))
	_detail_title.text = str(data.get("title", "پیام"))
	_detail_body.text = str(data.get("body", ""))
	_detail_type.text = str(TYPE_TITLES.get(msg_type, "پیام از بازی"))
	_detail_type.add_theme_color_override("font_color", MessageRow.type_color(msg_type))
	_detail_icon.texture = MessageRow.type_icon(msg_type)
	_detail_icon.modulate = MessageRow.type_color(msg_type)
	_detail_icon.visible = true
	_detail_time.text = ChatBubble.relative_time(str(data.get("created_at", "")))

	var sender := str(data.get("sender_name", ""))
	_detail_sender.text = "از طرف : %s" % sender
	_detail_sender.visible = not sender.is_empty()
	_read_tick.visible = bool(data.get("is_read", false))

	_apply_reward(data)
	_apply_actions(data)

func _apply_reward(data: Dictionary) -> void:
	for child in _reward_chips.get_children():
		child.queue_free()
	var reward = data.get("reward", null)
	if not (reward is Dictionary):
		_reward_box.visible = false
		return
	var r: Dictionary = reward
	var chips := 0
	for key in [["coins", "coin"], ["gems", "gem"], ["xp", "xp"]]:
		var amount := int(r.get(key[0], 0))
		if amount <= 0:
			continue
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 4)
		chip.add_child(MenuUI.label(MenuUI.fa_grouped(amount), 20, MenuUI.GOLD, true))
		chip.add_child(MenuUI.icon(MissionArt.texture_for(key[1]), 26))
		_reward_chips.add_child(chip)
		chips += 1
	var items = r.get("items", [])
	if items is Array and not (items as Array).is_empty():
		_reward_chips.add_child(MenuUI.label("%s آیتم" % MenuUI.fa((items as Array).size()), 17, MenuUI.GOLD))
		chips += 1
	_reward_box.visible = chips > 0
	var claimed := bool(data.get("reward_claimed", false))
	_reward_title.text = "دریافت شد ✓" if claimed else "جایزه"
	_reward_box.modulate = Color(1, 1, 1, 0.55) if claimed else Color.WHITE

## دکمه‌های پایین کارت بر اساس نوع پیام
func _apply_actions(data: Dictionary) -> void:
	var msg_type := str(data.get("type", ""))
	_action_row.visible = true
	_primary_button.visible = true
	_secondary_button.visible = true
	_primary_button.disabled = false
	_secondary_button.remove_theme_color_override("font_color")
	match msg_type:
		TYPE_FRIEND_REQUEST:
			_primary_button.text = "پذیرفتن"
			_secondary_button.text = "رد درخواست"
			_secondary_button.add_theme_color_override("font_color", MenuUI.RED_HOT)
		TYPE_GIFT, TYPE_REWARD:
			if MessageRow.reward_pending(data):
				_primary_button.text = "دریافت جایزه"
				_secondary_button.visible = false
			else:
				_primary_button.visible = false
				_secondary_button.text = "حذف پیام"
		_:
			_primary_button.visible = false
			_secondary_button.text = "حذف پیام"

func _set_detail_empty() -> void:
	_selected_id = ""
	_detail_title.text = "—"
	_detail_type.text = ""
	_detail_time.text = ""
	_detail_icon.visible = false
	_detail_body.text = "پیامی را از لیست انتخاب کن"
	_detail_sender.visible = false
	_read_tick.visible = false
	_reward_box.visible = false
	_action_row.visible = false

# ------------------------------------------------------------------ کارها

## دکمه‌ی اصلی: پذیرفتن درخواست / دریافت جایزه / فقط باز کردن پیام
func _on_primary_pressed(message_id: String) -> void:
	var data := _find_message(message_id)
	if data.is_empty():
		return
	_select(message_id, true)

	match str(data.get("type", "")):
		TYPE_FRIEND_REQUEST:
			var request_id := str(data.get("ref_id", ""))
			if request_id.is_empty():
				_show_toast("این درخواست دیگر معتبر نیست")
				return
			_post("/friends/respond",
				{"username": Global.my_username, "request_id": request_id, "accept": true},
				{"kind": "accept", "message_id": message_id})
		TYPE_GIFT, TYPE_REWARD:
			if not MessageRow.reward_pending(data):
				return
			_post("/messages/claim", {"username": Global.my_username, "message_id": message_id},
				{"kind": "claim", "message_id": message_id, "reward": data.get("reward", {})})

## ✕ / دکمه‌ی دوم: رد کردن درخواست دوستی یا حذف پیام
func _on_dismiss_pressed(message_id: String) -> void:
	var data := _find_message(message_id)
	if data.is_empty():
		return
	if str(data.get("type", "")) == TYPE_FRIEND_REQUEST:
		var request_id := str(data.get("ref_id", ""))
		if request_id.is_empty():
			_show_toast("این درخواست دیگر معتبر نیست")
			return
		_post("/friends/respond",
			{"username": Global.my_username, "request_id": request_id, "accept": false},
			{"kind": "reject", "message_id": message_id})
		return
	if MessageRow.reward_pending(data):
		_show_toast("اول جایزه‌ی این پیام را دریافت کن")
		return
	_post("/messages/delete", {"username": Global.my_username, "message_id": message_id},
		{"kind": "delete", "message_id": message_id})

func _on_read_all_pressed() -> void:
	_post("/messages/read_all", {"username": Global.my_username}, {"kind": "read_all"})

func _on_claim_all_pressed() -> void:
	UIFx.press(_claim_all_button)
	_post("/messages/claim_all", {"username": Global.my_username}, {"kind": "claim_all"})

# ------------------------------------------------------------------ سرور

func _post(path: String, payload: Dictionary, pending: Dictionary) -> void:
	if _busy:
		return
	_busy = true
	_pending = pending
	_primary_button.disabled = true
	var err := _action_http.request(Global.SERVER_BASE + path, Global.json_headers(),
		HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		_busy = false
		_primary_button.disabled = false
		_show_toast("ارتباط با سرور برقرار نشد")

func _on_action_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	_primary_button.disabled = false
	var pending := _pending
	_pending = {}

	if result != HTTPRequest.RESULT_SUCCESS or (response_code != 200 and response_code != 201):
		_show_toast(MenuUI.server_error(body, response_code if result == HTTPRequest.RESULT_SUCCESS else 0))
		refresh()
		return

	var data := MenuUI.parse_json(body)
	match str(pending.get("kind", "")):
		"accept":
			LocalSettings.vibrate(25)
			_show_toast("درخواست دوستی قبول شد — حالا با هم دوستید")
		"reject":
			_show_toast("درخواست رد شد")
		"delete":
			_show_toast("پیام حذف شد")
		"read_all":
			_show_toast("همه‌ی پیام‌ها خوانده شد")
		"claim":
			_celebrate(pending.get("reward", {}) if pending.get("reward") is Dictionary else {}, "هدیه دریافت شد")
		"claim_all":
			var total = data.get("reward", {})
			var n := int(data.get("claimed", 0))
			if n == 0:
				_show_toast("جایزه‌ای برای دریافت نبود")
			else:
				_celebrate(total if total is Dictionary else {}, "%s جایزه دریافت شد" % MenuUI.fa(n))
	# سکه/جم تاپ‌بار و نشان‌ها
	if pending.get("kind", "") in ["claim", "claim_all", "accept"]:
		Global.refresh_player_data()
	refresh()

## صفحه‌ی جایزه (همان RewardPopup بقیه‌ی بازی) + لرزش کوتاه
func _celebrate(reward: Dictionary, title: String) -> void:
	var items := RewardPopup.items_from_reward(reward)
	var extra = reward.get("items", [])
	if extra is Array and not (extra as Array).is_empty():
		items.append({"icon": "gift", "amount": (extra as Array).size(), "label": "آیتم"})
	LocalSettings.vibrate(35)
	if items.is_empty():
		_show_toast(title)
	else:
		RewardPopup.show_rewards(items, title)

# ------------------------------------------------------------------ پیام شناور

func _show_toast(message: String) -> void:
	if message.is_empty():
		return
	_toast_label.text = message
	_toast.visible = true
	_toast.modulate.a = 0.0
	_toast.pivot_offset = _toast.size * 0.5
	_toast.scale = Vector2(0.9, 0.9)

	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()

	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.16)
	_toast_tween.tween_property(_toast, "scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.chain().tween_interval(2.0)
	_toast_tween.chain().tween_property(_toast, "modulate:a", 0.0, 0.28) \
		.set_trans(Tween.TRANS_SINE)
	_toast_tween.chain().tween_callback(func() -> void: _toast.visible = false)

# ------------------------------------------------------------------ انیمیشن‌ها

func _play_intro() -> void:
	var rows := _list.get_children()
	for i in rows.size():
		var row := rows[i] as Control
		if row == null or i > 8:
			break
		row.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(0.035 * i)
		t.tween_property(row, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_SINE)
