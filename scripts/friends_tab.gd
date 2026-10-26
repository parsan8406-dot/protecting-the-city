extends Control
## تب دوستان.
##
## سرور (gun_game_server/handlers_social.go):
##   GET  /friends?username=...      لیست دوستان + درخواست‌های در انتظار
##   POST /friends/request           {username, target_id}
##   POST /friends/remove            {username, friend_id}
##   POST /friends/gift              (gift_dialog)
##   GET  /profile?player_id=...     کارت پروفایل (PlayerCardDialog)
##
## خودِ درخواست‌های دوستی در تب «پیام‌ها» جواب داده می‌شوند؛ این‌جا فقط یک
## نوار «N درخواست در انتظار» هست که مستقیم به همان‌جا می‌برد.
##
## موبایل: لیست فقط وقتی تب دیده می‌شود دوره‌ای تازه می‌شود (باتری و اینترنت)،
## و ردیف‌ها با کشیدن انگشت اسکرول می‌شوند (FriendRow / TapRow).

const FRIEND_ROW_SCENE := preload("res://secense/friend_row.tscn")
const GIFT_DIALOG_SCENE := preload("res://secense/gift_dialog.tscn")
## E10 یادآوری هدیه‌ی روزانه
const PsychSocialGift := preload("res://scripts/psych_social_gift.gd")
const CHAT_SCENE := "res://secense/chat.tscn"

## وقتی تب باز است، هر چند ثانیه وضعیت آنلاین تازه شود.
## تغییرِ خودِ لیست با سیگنال بلادرنگ Global.social_event می‌آید.
const AUTO_REFRESH_SECONDS := 15.0

@onready var _http: HTTPRequest = $HTTPRequest
@onready var _action_http: HTTPRequest = $ActionHTTPRequest
@onready var _refresh_timer: Timer = $RefreshTimer

# ستون لیست
@onready var _all_chip: Button = $Columns/ListPanel/Margin/Body/HeaderRow/Filters/AllChip
@onready var _online_chip: Button = $Columns/ListPanel/Margin/Body/HeaderRow/Filters/OnlineChip
@onready var _count_label: Label = $Columns/ListPanel/Margin/Body/HeaderRow/CountLabel
@onready var _requests_banner: Button = $Columns/ListPanel/Margin/Body/RequestsBanner
@onready var _scroll: ScrollContainer = $Columns/ListPanel/Margin/Body/Scroll
@onready var _list: VBoxContainer = $Columns/ListPanel/Margin/Body/Scroll/List
@onready var _empty_box: VBoxContainer = $Columns/ListPanel/Margin/Body/EmptyBox
@onready var _empty_label: Label = $Columns/ListPanel/Margin/Body/EmptyBox/EmptyLabel
@onready var _empty_hint: Label = $Columns/ListPanel/Margin/Body/EmptyBox/EmptyHint
@onready var _retry_button: Button = $Columns/ListPanel/Margin/Body/EmptyBox/RetryButton

# کارت دوست انتخاب‌شده
@onready var _detail_avatar: TextureRect = $Columns/SideColumn/DetailPanel/Margin/Body/TopRow/AvatarSlot/Avatar
@onready var _detail_avatar_slot: Control = $Columns/SideColumn/DetailPanel/Margin/Body/TopRow/AvatarSlot
@onready var _detail_name: Label = $Columns/SideColumn/DetailPanel/Margin/Body/TopRow/Info/NameLabel
@onready var _detail_id: Label = $Columns/SideColumn/DetailPanel/Margin/Body/TopRow/Info/IdLabel
@onready var _detail_status: Label = $Columns/SideColumn/DetailPanel/Margin/Body/TopRow/Info/StatusLabel
@onready var _detail_top: Control = $Columns/SideColumn/DetailPanel/Margin/Body/TopRow
@onready var _detail_meta_row: Control = $Columns/SideColumn/DetailPanel/Margin/Body/MetaRow
@onready var _detail_meta: Label = $Columns/SideColumn/DetailPanel/Margin/Body/MetaRow/MetaLabel
@onready var _detail_tier: TextureRect = $Columns/SideColumn/DetailPanel/Margin/Body/MetaRow/TierBadge
@onready var _detail_actions: HBoxContainer = $Columns/SideColumn/DetailPanel/Margin/Body/Actions
@onready var _detail_hint: Label = $Columns/SideColumn/DetailPanel/Margin/Body/HintLabel
@onready var _profile_button: Button = $Columns/SideColumn/DetailPanel/Margin/Body/Actions/ProfileButton
@onready var _gift_button: Button = $Columns/SideColumn/DetailPanel/Margin/Body/Actions/GiftButton
@onready var _message_button: Button = $Columns/SideColumn/DetailPanel/Margin/Body/Actions/MessageButton
@onready var _remove_button: Button = $Columns/SideColumn/DetailPanel/Margin/Body/RemoveButton

# افزودن دوست + آیدی خودم (که به دوستم بدهم)
@onready var _id_edit: LineEdit = $Columns/SideColumn/AddPanel/Margin/Body/AddRow/IdEdit
@onready var _add_button: Button = $Columns/SideColumn/AddPanel/Margin/Body/AddRow/AddButton
@onready var _my_id_label: Label = $Columns/SideColumn/AddPanel/Margin/Body/MyIdRow/MyIdLabel
@onready var _copy_button: Button = $Columns/SideColumn/AddPanel/Margin/Body/MyIdRow/CopyButton

# پیام شناور
@onready var _toast: PanelContainer = $Toast
@onready var _toast_label: Label = $Toast/ToastLabel

var _friends: Array = []
var _selected_id: String = ""
var _filter := "all"
var _busy := false
var _loaded_once := false
var _toast_tween: Tween
var _success_message := ""

# ------------------------------------------------------------------ آماده‌سازی

func _ready() -> void:
	_http.request_completed.connect(_on_friends_received)
	_action_http.request_completed.connect(_on_action_completed)

	for pair in [[_profile_button, "dark"], [_gift_button, "dark"], [_message_button, "gold"],
			[_remove_button, "ghost"], [_add_button, "gold"], [_copy_button, "dark"],
			[_requests_banner, "gold"], [_retry_button, "dark"]]:
		MenuUI.style_button(pair[0], pair[1])
		UIFx.bind_press_feedback(pair[0])
	_remove_button.add_theme_color_override("font_color", MenuUI.RED_HOT)
	_style_input(_id_edit)

	_profile_button.pressed.connect(_on_profile_pressed)
	_gift_button.pressed.connect(_on_gift_pressed)
	_message_button.pressed.connect(_on_message_pressed)
	_remove_button.pressed.connect(_on_remove_pressed)
	_add_button.pressed.connect(_on_add_pressed)
	_copy_button.pressed.connect(_on_copy_id_pressed)
	_retry_button.pressed.connect(refresh)
	_requests_banner.pressed.connect(_on_requests_banner_pressed)
	_all_chip.pressed.connect(_set_filter.bind("all"))
	_online_chip.pressed.connect(_set_filter.bind("online"))
	_id_edit.text_submitted.connect(func(_t: String) -> void: _on_add_pressed())
	_id_edit.text_changed.connect(_on_id_text_changed)

	UIScroll.attach(_scroll)
	_apply_social_art()
	_toast.visible = false
	_set_detail_empty()
	_refresh_filter_chips()
	_refresh_my_id()
	Global.player_data_updated.connect(_refresh_my_id)
	Global.social_event.connect(_on_social_event)
	Global.account_switched.connect(_on_account_switched)

	_refresh_timer.wait_time = AUTO_REFRESH_SECONDS
	_refresh_timer.timeout.connect(refresh)
	visibility_changed.connect(_on_visibility_changed)
	# یک بار حتی اگر تب پنهان است — تا نشان «دوستان» روی تب درست باشد
	refresh()
	if is_visible_in_tree():
		_refresh_timer.start()

## تایمر فقط وقتی تب دیده می‌شود کار می‌کند
func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		refresh()
		_refresh_timer.start()
	else:
		_refresh_timer.stop()

func _notification(what: int) -> void:
	# برگشت از پس‌زمینه — وضعیت آنلاین کهنه است
	if what == NOTIFICATION_APPLICATION_RESUMED and is_inside_tree() and is_visible_in_tree():
		refresh()

## سرور خبر داده لیست دوستان عوض شده (قبول درخواست، حذف دوست، ...)
func _on_social_event(_kind: String) -> void:
	refresh()

func _on_account_switched() -> void:
	_friends.clear()
	_selected_id = ""
	_loaded_once = false
	refresh()

## گرفتن دوباره‌ی لیست دوستان از سرور
func refresh() -> void:
	var username := str(Global.my_username)
	if username.is_empty():
		return
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var url := "%s/friends?username=%s" % [Global.SERVER_BASE, username.uri_encode()]
	if _http.request(url, Global.auth_headers()) != OK:
		_show_list_error("اتصال به سرور برقرار نشد")

# ------------------------------------------------------------------ پاسخ سرور

func _on_friends_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		# لیستِ قبلی (اگر بود) سر جایش می‌ماند؛ فقط وقتی چیزی نداریم خطا نشان بده
		if _friends.is_empty():
			_show_list_error(MenuUI.server_error(body, response_code if result == HTTPRequest.RESULT_SUCCESS else 0,
				"لیست دوستان از سرور نیامد"))
		return

	var data := MenuUI.parse_json(body)
	var raw = data.get("friends", [])
	_friends = raw if raw is Array else []

	# آنلاین‌ها بالا، بعد بر اساس سطح
	_friends.sort_custom(func(a, b) -> bool:
		var a_online := bool(a.get("is_online", false))
		var b_online := bool(b.get("is_online", false))
		if a_online != b_online:
			return a_online
		return int(a.get("level", 0)) > int(b.get("level", 0)))

	# سرور آیدی خودم را هم برمی‌گرداند — اگر Global هنوز نداشت، از همین‌جا پر می‌شود
	var my_id := str(data.get("player_id", ""))
	if not my_id.is_empty() and str(Global.player_id) != my_id:
		Global.player_id = my_id
	_refresh_my_id()

	var pending = data.get("pending_requests", [])
	var pending_count: int = (pending as Array).size() if pending is Array else 0
	Global.set_friend_requests_pending(pending_count)
	_requests_banner.visible = pending_count > 0
	_requests_banner.text = "%s درخواست دوستی در انتظار — مشاهده" % MenuUI.fa(pending_count)

	_build_list()

func _visible_friends() -> Array:
	if _filter != "online":
		return _friends
	return _friends.filter(func(f) -> bool: return f is Dictionary and bool(f.get("is_online", false)))

## ردیف‌ها فقط وقتی دوباره ساخته می‌شوند که ترکیب لیست عوض شده باشد؛
## رفرشِ دوره‌ای فقط ردیف‌های موجود را به‌روز می‌کند (بدون چشمک و پرش اسکرول)
func _build_list() -> void:
	var shown := _visible_friends()
	var online := 0
	for f in _friends:
		if f is Dictionary and bool(f.get("is_online", false)):
			online += 1
	_count_label.text = "%s دوست  •  %s آنلاین" % [MenuUI.fa(_friends.size()), MenuUI.fa(online)]

	var ids: Array[String] = []
	for f in shown:
		if f is Dictionary:
			ids.append(str(f.get("player_id", "")))
	var existing: Array[String] = []
	for child in _list.get_children():
		if child is FriendRow and not child.is_queued_for_deletion():
			existing.append(child.player_id)

	if ids == existing:
		var rows: Array = []
		for child in _list.get_children():
			if child is FriendRow and not child.is_queued_for_deletion():
				rows.append(child)
		var i := 0
		for f in shown:
			if f is Dictionary:
				rows[i].setup(f)
				i += 1
	else:
		for child in _list.get_children():
			child.queue_free()
		for f in shown:
			if not (f is Dictionary):
				continue
			var row: FriendRow = FRIEND_ROW_SCENE.instantiate()
			row.setup(f)
			row.row_selected.connect(_select)
			row.message_requested.connect(_open_chat)
			_list.add_child(row)
		if not _loaded_once:
			_play_intro()
	_loaded_once = true

	# خالی / پر
	var empty := shown.is_empty()
	_scroll.visible = not empty
	_empty_box.visible = empty
	_retry_button.visible = false
	if empty:
		if _friends.is_empty():
			_empty_label.text = "هنوز دوستی اضافه نکرده‌ای"
			_empty_hint.text = "آیدی دوستت را در باکس «افزودن دوست» بزن، یا آیدی خودت را برایش بفرست."
		else:
			_empty_label.text = "الان هیچ دوستی آنلاین نیست"
			_empty_hint.text = "برای دیدن همه، «همه» را بزن."

	# انتخاب قبلی حفظ می‌شود؛ وگرنه اولین دوست
	var selected := _find_friend(_selected_id)
	if selected.is_empty():
		if not _friends.is_empty():
			_apply_detail(_friends[0])
		else:
			_set_detail_empty()
	else:
		_apply_detail(selected)
	_refresh_row_selection()

func _show_list_error(message: String) -> void:
	_scroll.visible = false
	_empty_box.visible = true
	_empty_label.text = message
	_empty_hint.text = ""
	_retry_button.visible = true

func _find_friend(player_id: String) -> Dictionary:
	if player_id.is_empty():
		return {}
	for item in _friends:
		if item is Dictionary and str(item.get("player_id", "")) == player_id:
			return item
	return {}

func _set_filter(value: String) -> void:
	if _filter == value:
		return
	_filter = value
	_refresh_filter_chips()
	_loaded_once = false
	_build_list()

func _refresh_filter_chips() -> void:
	MenuUI.style_button(_all_chip, "gold" if _filter == "all" else "dark")
	MenuUI.style_button(_online_chip, "gold" if _filter == "online" else "dark")

# ------------------------------------------------------------------ انتخاب دوست

func _select(row: FriendRow) -> void:
	_apply_detail(row.get_data())
	_refresh_row_selection()

func _refresh_row_selection() -> void:
	for child in _list.get_children():
		if child is FriendRow:
			child.set_selected(child.player_id == _selected_id)

func _apply_detail(data: Dictionary) -> void:
	if data.is_empty():
		_set_detail_empty()
		return
	var changed := str(data.get("player_id", "")) != _selected_id
	_selected_id = str(data.get("player_id", ""))

	for c in [_detail_top, _detail_meta_row, _detail_actions, _remove_button]:
		c.visible = true
	_detail_hint.visible = false

	var online := bool(data.get("is_online", false))
	_detail_name.text = str(data.get("username", "—"))
	_detail_id.text = "ID : %s" % _selected_id
	_detail_status.text = MenuUI.last_seen_text(online, str(data.get("last_seen_at", "")))
	_detail_status.add_theme_color_override("font_color", MenuUI.GREEN if online else MenuUI.MUTED)

	var tier := str(data.get("tier_name", ""))
	var clan := str(data.get("clan_name", ""))
	var parts: Array[String] = ["سطح " + MenuUI.fa(int(data.get("level", 1)))]
	if not tier.is_empty():
		parts.append("%s (%s کاپ)" % [tier, MenuUI.fa_grouped(int(data.get("trophies", 0)))])
	parts.append("شهر : " + (clan if not clan.is_empty() else "ندارد"))
	_detail_meta.text = "  •  ".join(parts)
	_detail_tier.texture = RankArt.texture_for(str(data.get("tier_id", "")), tier)
	_detail_tier.visible = _detail_tier.texture != null

	_detail_avatar.texture = MenuUI.avatar_texture(str(data.get("avatar_id", "")))
	_refresh_gift_button()
	if changed:
		_detail_avatar_slot.pivot_offset = _detail_avatar_slot.size * 0.5
		_detail_avatar_slot.scale = Vector2(0.9, 0.9)
		create_tween().tween_property(_detail_avatar_slot, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _set_detail_empty() -> void:
	_selected_id = ""
	for c in [_detail_top, _detail_meta_row, _detail_actions, _remove_button]:
		c.visible = false
	_detail_hint.visible = true

# ------------------------------------------------------------------ دکمه‌ها

func _on_message_pressed() -> void:
	UIFx.press(_message_button)
	_open_chat(_selected_id)

## رفتن به صحنه‌ی چت، مستقیم روی گفتگوی خصوصی همین دوست
func _open_chat(player_id: String) -> void:
	if player_id.is_empty():
		return
	Global.request_chat_peer(player_id)
	get_tree().change_scene_to_file(CHAT_SCENE)

func _on_profile_pressed() -> void:
	UIFx.press(_profile_button)
	if _selected_id.is_empty():
		return
	var peer := _selected_id
	# E10 هدیه از خودِ کارت هم در دسترس است (همان دیالوگِ هدیه‌ی تب)
	PlayerCardDialog.open(self, peer, func() -> void: _open_chat(peer),
		func() -> void:
			if _find_friend(peer).is_empty():
				return
			_selected_id = peer
			_on_gift_pressed())

func _on_gift_pressed() -> void:
	UIFx.press(_gift_button)
	if _selected_id.is_empty():
		return
	var friend := _find_friend(_selected_id)
	var dialog := GIFT_DIALOG_SCENE.instantiate()
	dialog.add_to_group("modal")
	add_child(dialog)
	var friend_name := str(friend.get("username", ""))
	dialog.sent.connect(func(_id: String, coins: int, gems: int, xp: int) -> void:
		LocalSettings.vibrate(30)
		PsychSocialGift.record_sent()
		_refresh_gift_button()
		# E10 عمل متقابل: نشان بده هدیه به دست دوست رسید، نه فقط «کم شد»
		_show_toast("هدیه‌ات به صندوق پیام %s رسید (%s سکه، %s جم) — +%s تجربه" % [
			friend_name, MenuUI.fa_grouped(coins), MenuUI.fa(gems), MenuUI.fa(xp)]))
	dialog.failed.connect(func(reason: String) -> void: _show_toast(reason))
	dialog.open(_selected_id, str(friend.get("username", "")))

## E10/E16 «هدیه‌ی امروز» وقتی هدیه‌ی روزانه آماده است (طلایی = پاداش)، وگرنه
## ساعت‌های باقی‌مانده. دکمه قفل نمی‌شود؛ تصمیم نهایی با سرور است.
func _refresh_gift_button() -> void:
	_gift_button.text = PsychSocialGift.button_text()
	var gift_ready := PsychSocialGift.seconds_until_next() <= 0
	_gift_button.add_theme_color_override("font_color", MenuUI.GOLD if gift_ready else MenuUI.MUTED)

## آیکن‌های اجتماعی تازه (اگر رسیده باشند) — بازی بدون آن‌ها هم کار می‌کند
func _apply_social_art() -> void:
	var gift_icon := PsychSocialGift.load_icon()
	if gift_icon != null:
		_gift_button.icon = gift_icon
		_gift_button.expand_icon = true
		_gift_button.add_theme_constant_override("icon_max_width", 30)
	var squad_icon := PsychSocialGift.load_icon(PsychSocialGift.SQUAD_ICON_PATH)
	if squad_icon != null:
		# E1 ارتباط: حالت خالیِ لیست دوستان یک تصویر گرم دارد، نه فقط متن
		var art := TextureRect.new()
		art.texture = squad_icon
		art.custom_minimum_size = Vector2(0, 96)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_empty_box.add_child(art)
		_empty_box.move_child(art, 0)
		# C1 یک تصویر کافی است: آیکنِ خاکستریِ قدیمیِ حالتِ خالی جایش را می‌دهد
		var old_icon := _empty_box.get_node_or_null("EmptyIcon") as CanvasItem
		if old_icon != null:
			old_icon.visible = false

## حذف دوست با پنجره‌ی تأیید (قبلاً «دوباره بزن» بود و هیچ‌وقت ریست نمی‌شد)
func _on_remove_pressed() -> void:
	UIFx.press(_remove_button)
	if _selected_id.is_empty() or _busy:
		return
	var friend := _find_friend(_selected_id)
	var target := _selected_id
	var friend_name := str(friend.get("username", ""))
	var on_answer := func(ok: bool) -> void:
		if ok:
			_post("/friends/remove", {"username": Global.my_username, "friend_id": target},
				"%s از دوستانت حذف شد" % friend_name)
	MenuUI.confirm(self, "حذف از دوستان",
		"«%s» از لیست دوستانت حذف می‌شود و تو هم از لیست او. بعداً می‌توانی دوباره درخواست بدهی." % friend_name,
		"حذف کن", on_answer, true)

func _on_id_text_changed(text: String) -> void:
	# فقط رقم — آیدی بازیکن عددی است (ارقام فارسی هم تبدیل می‌شوند)
	var clean := ""
	for ch in text:
		var fa_index := "۰۱۲۳۴۵۶۷۸۹".find(ch)
		if fa_index != -1:
			clean += str(fa_index)
		elif ch >= "0" and ch <= "9":
			clean += ch
	if clean != text:
		var caret := _id_edit.caret_column
		_id_edit.text = clean
		_id_edit.caret_column = mini(caret, clean.length())

func _on_add_pressed() -> void:
	UIFx.press(_add_button)
	if _busy:
		return
	var target_id := _id_edit.text.strip_edges()
	if target_id.is_empty():
		_show_toast("آیدی عددی دوستت را وارد کن")
		_id_edit.grab_focus()
		return
	if not target_id.is_valid_int() or target_id.length() < 4:
		_show_toast("آیدی باید فقط عدد باشد (مثلاً ۴۵۱۳۵)")
		return
	if target_id == str(Global.player_id):
		_show_toast("این آیدی خودت است")
		return
	if not _find_friend(target_id).is_empty():
		_show_toast("این بازیکن از قبل دوستت است")
		return
	_id_edit.release_focus()
	_post("/friends/request", {"username": Global.my_username, "target_id": target_id}, "درخواست دوستی فرستاده شد ✓")

func _on_requests_banner_pressed() -> void:
	UIFx.tap(_requests_banner, func() -> void:
		Global.requested_messages_filter = "friend_request"
		Global.request_profile_tab("messages"))

# ------------------------------------------------------ آیدی خودم (برای دادن به دوست)

func _refresh_my_id() -> void:
	if _my_id_label == null:
		return
	var my_id := str(Global.player_id)
	_my_id_label.text = ("آیدی من : %s" % my_id) if not my_id.is_empty() else "..."
	_copy_button.disabled = my_id.is_empty()

func _on_copy_id_pressed() -> void:
	UIFx.press(_copy_button)
	var my_id := str(Global.player_id)
	if my_id.is_empty():
		_show_toast("آیدی هنوز از سرور نیامده")
		return
	DisplayServer.clipboard_set(my_id)
	_show_toast("آیدی کپی شد : %s — برای دوستت بفرست" % my_id)

# ------------------------------------------------------------------ ارتباط با سرور

func _post(path: String, payload: Dictionary, success_message: String) -> void:
	if _busy:
		return
	_busy = true
	_success_message = success_message
	_add_button.disabled = true
	var err := _action_http.request(Global.SERVER_BASE + path, Global.json_headers(),
		HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		_busy = false
		_add_button.disabled = false
		_show_toast("ارتباط با سرور برقرار نشد")

func _on_action_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	_add_button.disabled = false
	if result == HTTPRequest.RESULT_SUCCESS and (response_code == 200 or response_code == 201):
		_show_toast(_success_message)
		_id_edit.text = ""
		LocalSettings.vibrate(20)
		refresh()
		return
	_show_toast(MenuUI.server_error(body, response_code if result == HTTPRequest.RESULT_SUCCESS else 0))

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
	_toast_tween.chain().tween_interval(2.2)
	_toast_tween.chain().tween_property(_toast, "modulate:a", 0.0, 0.28) \
		.set_trans(Tween.TRANS_SINE)
	_toast_tween.chain().tween_callback(func() -> void: _toast.visible = false)

# ------------------------------------------------------------------ ظاهر

func _style_input(edit: LineEdit) -> void:
	var normal := MenuUI.box(Color(0.05, 0.05, 0.06, 1.0), Color(0.42, 0.42, 0.46, 0.9), 1, 6)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = MenuUI.GOLD
	focus.set_border_width_all(2)
	edit.add_theme_stylebox_override("normal", normal)
	edit.add_theme_stylebox_override("focus", focus)
	edit.add_theme_color_override("font_color", MenuUI.TEXT)
	edit.add_theme_color_override("font_placeholder_color", MenuUI.DIM)

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
