extends Control
## صحنه‌ی چت بازی — طرح سه‌ستونه:
##   چپ   : کارت کانال‌ها (جهانی / شهر / دوستان) + تصویر تزئینی
##   وسط  : گفتگوی باز. در کانال «دوستان» اول لیست گفتگوهای خصوصی می‌آید و
##          با ضربه روی هر دوست، گفتگوی خصوصی با او باز می‌شود.
##   راست : «آنلاین» — فقط دوستان و هم‌شهری‌ها (عمداً جهانی ندارد)
##
## سرور (gun_game_server):
##   GET  /chat/overview?username=...                  کانال‌ها، دوستان، هم‌شهری‌ها
##   GET  /chat/history?username=&channel=&peer_id=    تاریخچه‌ی یک اتاق
##        &limit=&before=&after=
##   POST /chat/send   {username, channel, peer_id, text}
##   POST /chat/read   {username, channel, peer_id}
##   POST /friends/request {username, target_id}       دکمه‌ی «+» ستون آنلاین
##
## پیام‌های تازه دو راه به اینجا می‌رسند:
##   ۱) بلادرنگ روی WebSocket (Network.chat_message_received) — راه اصلی
##   ۲) پولینگ سبک هر چند ثانیه با پارامتر after — تور ایمنی برای وقتی
##      اتصال لحظه‌ای قطع بوده و یک پیام از دست رفته
##
## ایموجی‌ها به شکل توکن «:e01:» داخل متن می‌روند (ChatEmoji).

const CHAT_ROOM_ROW_SCENE := preload("res://secense/chat_room_row.tscn")
const CHAT_BUBBLE_SCENE := preload("res://secense/chat_bubble.tscn")
const ONLINE_ROW_SCENE := preload("res://secense/chat_online_row.tscn")
const PROFILE_DIALOG_SCENE := preload("res://secense/chat_profile_dialog.tscn")
const MAIN_MENU_SCENE_PATH := "res://secense/main_menu.tscn"

const ICON_GLOBAL := preload("res://assets/chat/icons/globe.svg")
const ICON_CITY := preload("res://assets/chat/icons/city.svg")
const ICON_FRIENDS := preload("res://assets/chat/icons/friends.svg")

## عکس‌های اختیاری صفحه — تا وقتی ساخته نشده‌اند صفحه با رنگ ساده کار می‌کند
const BG_ART_PATH := "res://assets/chat/chat_bg.png"
const SIDE_ART_PATH := "res://assets/chat/chat_side_art.png"

const CHANNEL_GLOBAL := "global"
const CHANNEL_CITY := "city"
const CHANNEL_PRIVATE := "private"
const CHANNEL_TITLES := {"global": "جهانی", "city": "شهر", "private": "دوستان"}

## تب‌های ستون آنلاین
const PEOPLE_FRIENDS := "friends"
const PEOPLE_CITY := "city"

## هر چند ثانیه لیست کانال‌ها و پیام‌های جامانده دوباره از سرور گرفته شود
const REFRESH_SECONDS := 6.0
## بیشترین طول متن یک پیام (همان عدد سمت سرور)
const MAX_TEXT_LENGTH := 300
## اگر فاصله‌ی دو پیام پشت‌سرهمِ یک نفر کمتر از این باشد، هدر دومی نشان داده نمی‌شود
const GROUP_WINDOW_SECONDS := 180
## سقفِ پیام‌های اتاقِ باز؛ بیشتر از این قدیمی‌ترین حباب آزاد می‌شود
const MAX_MESSAGES := 150
## اندازه‌ی خانه‌های پنل ایموجی (کمتر از ۴۴ برای انگشت سخت است)
const EMOJI_CELL := 48
const EMOJI_PREVIEW_SIZE := 22

@onready var _overview_http: HTTPRequest = $OverviewHTTPRequest
@onready var _history_http: HTTPRequest = $HistoryHTTPRequest
@onready var _send_http: HTTPRequest = $SendHTTPRequest
@onready var _read_http: HTTPRequest = $ReadHTTPRequest
@onready var _friend_http: HTTPRequest = $FriendHTTPRequest
@onready var _refresh_timer: Timer = $RefreshTimer

@onready var _bg_art: TextureRect = $BgArt
@onready var _top_bar: Control = $TopBar
@onready var _header: HBoxContainer = $Header
@onready var _back_button: Button = $Header/BackButton
@onready var _body: MarginContainer = $Body

# --- ستون چپ ---
@onready var _global_card: ChatChannelCard = $Body/Columns/LeftCol/GlobalCard
@onready var _city_card: ChatChannelCard = $Body/Columns/LeftCol/CityCard
@onready var _friends_card: ChatChannelCard = $Body/Columns/LeftCol/FriendsCard
@onready var _side_art: TextureRect = $Body/Columns/LeftCol/ArtPanel/ArtRoot/Art

# --- ستون وسط ---
const _ROOM := "Body/Columns/RoomPanel/Margin/Col/"
@onready var _room_panel: PanelContainer = $Body/Columns/RoomPanel
@onready var _back_chevron: Button = get_node(_ROOM + "Header/BackChevron")
@onready var _room_icon: TextureRect = get_node(_ROOM + "Header/IconSlot/Icon")
@onready var _room_avatar: ChatAvatar = get_node(_ROOM + "Header/IconSlot/Avatar")
@onready var _title_button: Button = get_node(_ROOM + "Header/TitleButton")
@onready var _room_status: Label = get_node(_ROOM + "Header/StatusLabel")
@onready var _messages_scroll: ScrollContainer = get_node(_ROOM + "MessagesScroll")
@onready var _messages_box: VBoxContainer = get_node(_ROOM + "MessagesScroll/Messages")
@onready var _conv_scroll: ScrollContainer = get_node(_ROOM + "ConvScroll")
@onready var _conv_list: VBoxContainer = get_node(_ROOM + "ConvScroll/ConvList")
@onready var _room_hint: Label = get_node(_ROOM + "RoomHint")
@onready var _preview_bar: PanelContainer = get_node(_ROOM + "PreviewBar")
@onready var _preview_text: RichTextLabel = get_node(_ROOM + "PreviewBar/PreviewText")
@onready var _emoji_panel: PanelContainer = get_node(_ROOM + "EmojiPanel")
@onready var _emoji_scroll: ScrollContainer = get_node(_ROOM + "EmojiPanel/EmojiScroll")
@onready var _emoji_grid: GridContainer = get_node(_ROOM + "EmojiPanel/EmojiScroll/EmojiGrid")
@onready var _input_row: HBoxContainer = get_node(_ROOM + "InputRow")
@onready var _emoji_button: Button = get_node(_ROOM + "InputRow/EmojiButton")
@onready var _text_edit: LineEdit = get_node(_ROOM + "InputRow/TextEdit")
@onready var _send_button: Button = get_node(_ROOM + "InputRow/SendButton")

# --- ستون راست ---
const _PEOPLE := "Body/Columns/OnlinePanel/Margin/Col/"
@onready var _people_count: Label = get_node(_PEOPLE + "TitleRow/CountLabel")
@onready var _search_edit: LineEdit = get_node(_PEOPLE + "SearchBox/Row/SearchEdit")
@onready var _city_tab: Button = get_node(_PEOPLE + "Tabs/CityTab")
@onready var _friends_tab: Button = get_node(_PEOPLE + "Tabs/FriendsTab")
@onready var _people_scroll: ScrollContainer = get_node(_PEOPLE + "PeopleScroll")
@onready var _people_list: VBoxContainer = get_node(_PEOPLE + "PeopleScroll/PeopleList")
@onready var _people_empty: Label = get_node(_PEOPLE + "PeopleEmpty")

# --- بقیه ---
@onready var _toast: PanelContainer = $Toast
@onready var _toast_label: Label = $Toast/ToastLabel

## کانال انتخاب‌شده در ستون چپ
var _channel: String = CHANNEL_GLOBAL
## گفتگوی باز: {channel, room, peer_id, ...} — خالی یعنی چیزی باز نیست
## (در کانال دوستان یعنی لیست گفتگوها دیده می‌شود)
var _open_room: Dictionary = {}
## آخرین پاسخ /chat/overview
var _overview: Dictionary = {}
## پیام‌های اتاق باز، از قدیم به جدید
var _messages: Array[Dictionary] = []
## زمانِ هر پیام (یونیکس)، هم‌ترتیب با _messages — یک بار parse می‌شود، نه
## در هر مقایسه‌ی مرتب‌سازی
var _stamps: Array[int] = []
## چند پیامِ اولِ _messages الان حباب دارند (حباب‌ها هم‌ترتیبِ پیام‌ها هستند)
var _shown := 0
## پیامی وسطِ حباب‌های ساخته‌شده نشست یا وضعیتِ آنلاین/رهبرها عوض شد —
## دفعه‌ی بعد همه‌ی حباب‌ها از نو ساخته می‌شوند
var _needs_rebuild := false
## آیدی پیام‌های نمایش‌داده‌شده — جلوی تکراری شدن (WebSocket + پولینگ) را می‌گیرد
var _seen_ids: Dictionary = {}
## وضعیت آنلاین فرستنده‌ها: player_id → bool
var _online: Dictionary = {}
## رهبرهای شهر (برای تاج کنار اسم): player_id → true
var _leaders: Dictionary = {}

## تب ستون آنلاین
var _people_tab: String = PEOPLE_FRIENDS
var _people_signature: String = ""
var _conv_signature: String = ""
## درخواست‌های دوستیِ فرستاده‌شده در همین جلسه: player_id → true
var _requested: Dictionary = {}
var _pending_friend_id: String = ""

## گفتگوی خصوصی‌ای که باید به‌محض رسیدن لیست باز شود (از تب دوستان آمده)
var _pending_peer: String = ""
var _sending := false
var _loading_history := false
## کاربر پایین لیست است؟ اگر بالا اسکرول کرده باشد، پیام جدید صفحه را نمی‌پراند
var _stick_to_bottom := true
var _toast_tween: Tween
var _channel_menu: PopupMenu
var _dialog: Node = null
var _back_frame := -1

# ------------------------------------------------------------------ آماده‌سازی

func _ready() -> void:
	get_tree().set_quit_on_go_back(false)

	_overview_http.request_completed.connect(_on_overview_received)
	_history_http.request_completed.connect(_on_history_received)
	_send_http.request_completed.connect(_on_send_completed)
	_friend_http.request_completed.connect(_on_friend_request_completed)

	# نوار بالا: پروفایل نمی‌خواهیم؛ جایش دکمه‌ی برگشت و عنوان «چت» است
	var profile := _top_bar.get_node_or_null("HBoxContainer/Profile") as Control
	if profile != null:
		profile.visible = false

	_load_optional_art()

	for card in [_global_card, _city_card, _friends_card]:
		card.pressed.connect(_select_channel.bind(card.channel))

	_back_button.pressed.connect(func() -> void: UIFx.tap(_back_button, _go_home))
	_back_chevron.pressed.connect(_close_private_room)
	_title_button.pressed.connect(_open_channel_menu)

	_send_button.pressed.connect(_on_send_pressed)
	_text_edit.text_submitted.connect(func(_t: String) -> void: _on_send_pressed())
	_text_edit.text_changed.connect(_on_text_changed)
	_text_edit.max_length = MAX_TEXT_LENGTH
	UIFx.bind_press_feedback(_send_button)
	UIFx.bind_press_feedback(_emoji_button)
	_emoji_button.toggled.connect(_set_emoji_panel)
	_build_emoji_grid()

	_city_tab.pressed.connect(_select_people_tab.bind(PEOPLE_CITY))
	_friends_tab.pressed.connect(_select_people_tab.bind(PEOPLE_FRIENDS))
	_search_edit.text_changed.connect(func(_t: String) -> void: _build_people_list())

	for scroll in [_messages_scroll, _conv_scroll, _people_scroll, _emoji_scroll]:
		UIScroll.attach(scroll)
	# فهمیدن اینکه بازیکن پایین لیست است یا بالا رفته
	_messages_scroll.get_v_scroll_bar().value_changed.connect(_on_messages_scrolled)
	# عرض ستون که عوض شد (چرخش، تغییر اندازه‌ی پنجره) حباب‌ها دوباره اندازه می‌گیرند؛
	# وگرنه عرض قبلی‌شان ستون را بیرون از صفحه هل می‌دهد
	_messages_scroll.resized.connect(_on_messages_resized)

	_toast.visible = false
	_preview_bar.visible = false

	# پیام بلادرنگ از سرور
	if not Network.chat_message_received.is_connected(_on_chat_message):
		Network.chat_message_received.connect(_on_chat_message)
	# تغییرات اجتماعی (دوست جدید، خروج از شهر، ...) لیست را تازه می‌کند
	if not Global.social_event.is_connected(_on_social_event):
		Global.social_event.connect(_on_social_event)

	_refresh_timer.wait_time = REFRESH_SECONDS
	_refresh_timer.timeout.connect(_on_refresh_tick)
	_refresh_timer.start()

	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()

	# اگر از تب دوستان آمده‌ایم، همان گفتگوی خصوصی باید باز شود
	_pending_peer = str(Global.requested_chat_peer)
	Global.requested_chat_peer = ""

	_select_people_tab(PEOPLE_FRIENDS)
	_select_channel(CHANNEL_PRIVATE if not _pending_peer.is_empty() else CHANNEL_GLOBAL)
	refresh_overview()

func _exit_tree() -> void:
	# نشان قرمز منوی اصلی (فقط پیام‌های دوستان) با آخرین عددی که اینجا دیدیم سینک بماند
	Global.set_chat_unread(int(_overview.get("private_unread", Global.unread_chat)))

## عکس پس‌زمینه و تصویر ستون چپ اختیاری‌اند — اگر هنوز ساخته نشده‌اند
## صفحه بدون آن‌ها هم درست دیده می‌شود.
func _load_optional_art() -> void:
	if ResourceLoader.exists(BG_ART_PATH):
		_bg_art.texture = load(BG_ART_PATH)
	if ResourceLoader.exists(SIDE_ART_PATH):
		_side_art.texture = load(SIDE_ART_PATH)

# ------------------------------------------------------------ ناحیه‌ی امن (ناچ)

## فاصله‌ی ناچ/لبه‌ی خمیده از چهار طرف، به واحدِ ویوپورت. روی دسکتاپ صفر.
func _safe_insets() -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var win_pos := DisplayServer.window_get_position()
	var win_size := DisplayServer.window_get_size()
	if safe.size.x <= 0 or win_size.x <= 0:
		return Vector4.ZERO
	var k := get_viewport_rect().size / Vector2(win_size)
	return Vector4(
		maxf(0.0, float(safe.position.x - win_pos.x)) * k.x,
		maxf(0.0, float(safe.position.y - win_pos.y)) * k.y,
		maxf(0.0, float(win_pos.x + win_size.x - safe.end.x)) * k.x,
		maxf(0.0, float(win_pos.y + win_size.y - safe.end.y)) * k.y)

func _apply_safe_area() -> void:
	var ins := _safe_insets()
	_header.position.x = 12.0 + ins.x
	var bar := _top_bar.get_node_or_null("HBoxContainer") as Control
	if bar != null:
		bar.offset_right = -(12.0 + ins.z)
	_body.add_theme_constant_override("margin_left", int(10.0 + ins.x))
	_body.add_theme_constant_override("margin_right", int(10.0 + ins.z))
	_body.add_theme_constant_override("margin_bottom", int(10.0 + ins.w))

# ------------------------------------------------------------------ کانال‌ها

func _select_channel(channel: String) -> void:
	_channel = channel
	_global_card.set_selected(channel == CHANNEL_GLOBAL)
	_city_card.set_selected(channel == CHANNEL_CITY)
	_friends_card.set_selected(channel == CHANNEL_PRIVATE)
	_set_emoji_panel(false)

	if channel == CHANNEL_PRIVATE:
		# کانال دوستان: اول لیست گفتگوها (مگر اینکه گفتگوی خاصی خواسته شده باشد)
		_open_room = {}
		_show_conversation_list()
		return

	var card = _overview.get(channel, {})
	if card is Dictionary and not (card as Dictionary).is_empty():
		_open_group_room(card as Dictionary)
	else:
		# overview هنوز نرسیده — هدر را می‌چینیم و منتظر می‌مانیم
		_open_room = {}
		_apply_header()
		_set_room_empty("در حال اتصال ...")

## باز کردن اتاق جهانی یا شهر از روی کارت overview
func _open_group_room(card: Dictionary) -> void:
	if not bool(card.get("available", true)):
		_open_room = {}
		_apply_header()
		_set_room_empty(str(card.get("hint", "برای چت شهر باید عضو یک شهر باشی")))
		return
	_open_conversation(card)

## منوی کشویی کنار عنوان — راه دوم عوض کردن کانال
func _open_channel_menu() -> void:
	if _channel_menu == null:
		_channel_menu = PopupMenu.new()
		_channel_menu.add_theme_font_override("font", _title_button.get_theme_font("font"))
		_channel_menu.add_theme_font_size_override("font_size", 19)
		_channel_menu.add_theme_constant_override("v_separation", 18)
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color(0.035, 0.065, 0.11, 0.98)
		panel.border_color = Color(0.25, 0.6, 1.0, 1.0)
		panel.set_border_width_all(1)
		panel.set_corner_radius_all(8)
		panel.set_content_margin_all(8)
		_channel_menu.add_theme_stylebox_override("panel", panel)
		_channel_menu.add_icon_item(ICON_GLOBAL, CHANNEL_TITLES[CHANNEL_GLOBAL], 0)
		_channel_menu.add_icon_item(ICON_CITY, CHANNEL_TITLES[CHANNEL_CITY], 1)
		_channel_menu.add_icon_item(ICON_FRIENDS, CHANNEL_TITLES[CHANNEL_PRIVATE], 2)
		for i in 3:
			_channel_menu.set_item_icon_max_width(i, 24)
		_channel_menu.id_pressed.connect(func(id: int) -> void:
			_select_channel([CHANNEL_GLOBAL, CHANNEL_CITY, CHANNEL_PRIVATE][id]))
		add_child(_channel_menu)

	var rect := _title_button.get_global_rect()
	_channel_menu.popup(Rect2i(Vector2i(rect.position + Vector2(0, rect.size.y + 4)), Vector2i(200, 0)))

# ------------------------------------------------------------------ overview

## گرفتن دوباره‌ی کانال‌ها و آدم‌ها از سرور
func refresh_overview() -> void:
	var username := str(Global.my_username)
	if username.is_empty():
		return
	var url := "%s/chat/overview?username=%s" % [Global.SERVER_BASE, username.uri_encode()]
	var err := _overview_http.request(url, Global.auth_headers())
	# ERR_BUSY یعنی درخواست قبلی هنوز در راه است — همان کافی است
	if err != OK and err != ERR_BUSY:
		push_warning("خطا در درخواست لیست گفتگوها: %d" % err)

## رگبار پیام‌های جهانی نباید رگبار درخواست overview بسازد — چند پیام
## پشت‌سرهم فقط یک درخواست می‌فرستند.
var _overview_queued := false

func _queue_overview_refresh() -> void:
	if _overview_queued:
		return
	_overview_queued = true
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		_overview_queued = false
		if is_inside_tree():
			refresh_overview())

func _on_overview_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		if _overview.is_empty():
			_set_room_empty("اتصال به سرور برقرار نشد — دوباره تلاش می‌کنیم ...")
			_people_empty.text = "اتصال به سرور برقرار نشد"
			_people_empty.visible = true
			_people_scroll.visible = false
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return

	var first := _overview.is_empty()
	_overview = json.data
	Global.set_chat_unread(int(_overview.get("private_unread", 0)))

	var my_id := str(_overview.get("player_id", ""))
	if not my_id.is_empty() and str(Global.player_id) != my_id:
		Global.player_id = my_id

	var old_leaders := _leaders.duplicate()
	_leaders.clear()
	for person in _people():
		if str(person.get("clan_role", "")) == "leader":
			_leaders[str(person.get("player_id", ""))] = true
	# تاجِ کنارِ اسم مثلِ قبل با ساختِ بعدیِ حباب‌ها به‌روز می‌شود
	if old_leaders != _leaders:
		_needs_rebuild = true

	_update_cards()
	_build_people_list()

	match _channel:
		CHANNEL_PRIVATE:
			_build_conversation_list()
			# هدر گفتگوی خصوصیِ باز با تازه‌ترین وضعیت آنلاین هماهنگ می‌شود
			if not _open_room.is_empty():
				var fresh := _find_private(str(_open_room.get("peer_id", "")))
				if not fresh.is_empty():
					_open_room.merge(fresh, true)
					_apply_header()
		_:
			var card = _overview.get(_channel, {})
			if card is Dictionary:
				if _open_room.is_empty() or first \
						or str((card as Dictionary).get("room", "")) != str(_open_room.get("room", "")):
					_open_group_room(card as Dictionary)
				else:
					_open_room.merge(card as Dictionary, true)
					_apply_header()

## نشان‌های قرمز و در دسترس بودن کارت‌های ستون چپ
func _update_cards() -> void:
	var global_card = _overview.get("global", {})
	var city_card = _overview.get("city", {})
	_global_card.set_unread(int(global_card.get("unread", 0)) if global_card is Dictionary else 0)
	_city_card.set_unread(int(city_card.get("unread", 0)) if city_card is Dictionary else 0)
	_city_card.set_available(_in_city())
	_friends_card.set_unread(int(_overview.get("private_unread", 0)))

func _people() -> Array:
	var people = _overview.get("people", [])
	return people if people is Array else []

func _privates() -> Array:
	var privates = _overview.get("privates", [])
	return privates if privates is Array else []

func _find_private(peer_id: String) -> Dictionary:
	for item in _privates():
		if typeof(item) == TYPE_DICTIONARY and str((item as Dictionary).get("peer_id", "")) == peer_id:
			return item
	return {}

func _is_friend(player_id: String) -> bool:
	return not _find_private(player_id).is_empty()

func _in_city() -> bool:
	var city = _overview.get("city", {})
	return city is Dictionary and bool((city as Dictionary).get("available", false))

# ------------------------------------------------------------ لیست گفتگوهای خصوصی

func _show_conversation_list() -> void:
	_clear_messages()
	_messages.clear()
	_stamps.clear()
	_seen_ids.clear()
	_apply_header()
	_input_row.visible = false
	_preview_bar.visible = false
	_messages_scroll.visible = false
	_conv_signature = ""
	_build_conversation_list()

## ردیف‌های گفتگوی خصوصی. تا وقتی ترکیب دوستان عوض نشده، ردیف‌ها به‌جای
## ساخته‌شدن دوباره فقط به‌روز می‌شوند — وگرنه هر رفرش لیست پلک می‌زند.
func _build_conversation_list() -> void:
	if _channel != CHANNEL_PRIVATE:
		return

	var rows := _privates()

	# گفتگوی درخواست‌شده از تب دوستان فقط همان بار اول اولویت دارد
	if not _pending_peer.is_empty() and not _overview.is_empty():
		var requested := _find_private(_pending_peer)
		_pending_peer = ""
		if not requested.is_empty():
			_open_conversation(requested)
			return

	if not _open_room.is_empty():
		_conv_scroll.visible = false
		return

	if rows.is_empty():
		_conv_scroll.visible = false
		_show_room_hint("هنوز دوستی نداری — از منوی کاربر → دوستان، با آیدی دوست اضافه کن"
			if not _overview.is_empty() else "در حال گرفتن لیست دوستان ...")
		return

	_room_hint.visible = false
	_conv_scroll.visible = true

	var keys := PackedStringArray()
	for data in rows:
		keys.append(str((data as Dictionary).get("room", "")))
	var signature := "|".join(keys)

	if signature == _conv_signature and _conv_list.get_child_count() == rows.size():
		for i in rows.size():
			(_conv_list.get_child(i) as ChatRoomRow).setup(rows[i])
		return
	_conv_signature = signature

	for child in _conv_list.get_children():
		_conv_list.remove_child(child)
		child.queue_free()
	for data in rows:
		var row := CHAT_ROOM_ROW_SCENE.instantiate()
		row.setup(data)
		row.tapped.connect(func(r: Button) -> void: _open_conversation(r.get_data()))
		_conv_list.add_child(row)
	_fade_in_children(_conv_list)

## C12 سرور با همین GET /chat/history اتاق را «خوانده» ثبت کرده؛ نشانِ قرمزِ
## کارت/ردیف و عددِ منوی اصلی همین حالا صفر شوند، نه با رفرشِ بعدیِ overview
func _clear_open_room_badge() -> void:
	var channel := str(_open_room.get("channel", ""))
	if channel == CHANNEL_PRIVATE:
		var entry := _find_private(str(_open_room.get("peer_id", "")))
		var n := int(entry.get("unread", 0))
		if n <= 0:
			return
		entry["unread"] = 0
		_overview["private_unread"] = maxi(int(_overview.get("private_unread", 0)) - n, 0)
		Global.set_chat_unread(int(_overview["private_unread"]))
	else:
		var card = _overview.get(channel, {})
		if not (card is Dictionary) or int((card as Dictionary).get("unread", 0)) <= 0:
			return
		(card as Dictionary)["unread"] = 0
	_update_cards()

## از گفتگوی خصوصی به لیست دوستان برمی‌گردد
func _close_private_room() -> void:
	if _channel != CHANNEL_PRIVATE or _open_room.is_empty():
		return
	_open_room = {}
	_set_emoji_panel(false)
	_show_conversation_list()

# ------------------------------------------------------------------ باز کردن گفتگو

func _open_conversation(data: Dictionary) -> void:
	var same_room := str(data.get("room", "")) == str(_open_room.get("room", ""))
	_open_room = data.duplicate()
	_conv_scroll.visible = false
	_apply_header()

	# اتاق که عوض شد تاریخچه از نو گرفته می‌شود؛ اتاق تکراری فقط هدر را تازه می‌کند
	if not same_room or _messages_box.get_child_count() == 0:
		_messages.clear()
		_stamps.clear()
		_seen_ids.clear()
		_online.clear()
		_stick_to_bottom = true
		_clear_messages()
		_show_room_hint("در حال گرفتن پیام‌ها ...")
		# پاسخ درخواست قبلی (اتاق دیگر) دیگر به درد نمی‌خورد
		_history_http.cancel_request()
		_loading_history = false
		_request_history(true)

	_input_row.visible = true
	_text_edit.editable = true
	_send_button.disabled = false
	_on_text_changed(_text_edit.text)

## هدر بالای ستون وسط: آیکون کانال یا آواتار دوست، عنوان، وضعیت
func _apply_header() -> void:
	var is_dm := _channel == CHANNEL_PRIVATE and not _open_room.is_empty()
	_back_chevron.visible = is_dm
	_room_avatar.visible = is_dm
	_room_icon.visible = not is_dm

	if is_dm:
		var online := bool(_open_room.get("is_online", false))
		_room_avatar.set_avatar(str(_open_room.get("avatar_id", "")))
		_room_avatar.set_ring(ChatAvatar.RING_GREEN if online else ChatAvatar.RING_DEFAULT)
		_title_button.text = str(_open_room.get("username", "—"))
		_room_status.text = "آنلاین" if online else ChatBubble.last_seen_text(str(_open_room.get("last_seen_at", "")))
		_room_status.add_theme_color_override("font_color",
			Color(0.2, 0.85, 0.38, 1.0) if online else Color(0.55, 0.62, 0.72, 1.0))
		return

	_room_status.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72, 1.0))
	match _channel:
		CHANNEL_GLOBAL:
			_room_icon.texture = ICON_GLOBAL
			_title_button.text = CHANNEL_TITLES[CHANNEL_GLOBAL]
			var online_count := int(_overview.get("online_count", 0))
			_room_status.text = ("%d بازیکن آنلاین" % online_count) if online_count > 0 else ""
		CHANNEL_CITY:
			_room_icon.texture = ICON_CITY
			var city_title := str(_open_room.get("title", ""))
			_title_button.text = CHANNEL_TITLES[CHANNEL_CITY] if city_title.is_empty() \
				else "%s  «%s»" % [CHANNEL_TITLES[CHANNEL_CITY], city_title]
			var members := int(_open_room.get("member_count", 0))
			_room_status.text = ("%d عضو" % members) if members > 0 else ""
		_:
			_room_icon.texture = ICON_FRIENDS
			_title_button.text = CHANNEL_TITLES[CHANNEL_PRIVATE]
			_room_status.text = ("%d دوست" % _privates().size()) if not _privates().is_empty() else ""

func _set_room_empty(hint: String) -> void:
	_clear_messages()
	_conv_scroll.visible = false
	_show_room_hint(hint)
	_input_row.visible = false
	_preview_bar.visible = false

## راهنمای وسط صفحه (به‌جای لیست پیام‌ها) نشان داده می‌شود
func _show_room_hint(text: String) -> void:
	_room_hint.text = text
	_room_hint.visible = true
	_messages_scroll.visible = false

func _hide_room_hint() -> void:
	_room_hint.visible = false
	_messages_scroll.visible = true

# ------------------------------------------------------------------ تاریخچه

## گرفتن پیام‌ها. اگر full_reload خاموش باشد فقط پیام‌های جدیدتر از آخرین
## پیامی که داریم گرفته می‌شود (پولینگ سبک).
func _request_history(full_reload: bool) -> void:
	if _open_room.is_empty() or _loading_history:
		return

	var username := str(Global.my_username)
	if username.is_empty():
		return

	var url := "%s/chat/history?username=%s&channel=%s" % [
		Global.SERVER_BASE, username.uri_encode(), str(_open_room.get("channel", "")).uri_encode()
	]
	var peer_id := str(_open_room.get("peer_id", ""))
	if not peer_id.is_empty():
		url += "&peer_id=" + peer_id.uri_encode()
	if not full_reload and not _messages.is_empty():
		url += "&after=" + str(_messages[-1].get("created_at", "")).uri_encode()

	_loading_history = true
	var err := _history_http.request(url, Global.auth_headers())
	if err != OK:
		_loading_history = false
		push_warning("خطا در درخواست تاریخچه‌ی چت: %d" % err)

func _on_history_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_loading_history = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		if _messages.is_empty() and not _open_room.is_empty():
			var parsed = JSON.parse_string(body.get_string_from_utf8())
			var reason := "پیام‌ها از سرور نیامد — اینترنت را بررسی کن"
			if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("error"):
				reason = str((parsed as Dictionary)["error"])
			_show_room_hint(reason)
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return

	var data: Dictionary = json.data

	# پاسخِ اتاقی که دیگر باز نیست به درد نمی‌خورد
	if str(data.get("room", "")) != str(_open_room.get("room", "")):
		return

	var online = data.get("online", {})
	if online is Dictionary:
		# نقطه‌ی آنلاینِ حباب‌های قبلی هم باید تازه شود (قبلاً هر پیامِ تازه
		# همه‌ی حباب‌ها را از نو می‌ساخت و این خودبه‌خود اتفاق می‌افتاد)
		for k in online:
			if bool(_online.get(k, false)) != bool(online[k]):
				_needs_rebuild = true
				break
		_online.merge(online, true)

	# هدر با عدد تازه‌ی سرور به‌روز می‌شود (تعداد آنلاین‌ها / اعضای شهر)
	if data.has("online_count"):
		_overview["online_count"] = int(data["online_count"])
	if data.has("member_count"):
		_open_room["member_count"] = int(data["member_count"])
	if data.has("title"):
		_open_room["title"] = str(data["title"])
	if data.has("peer") and data["peer"] is Dictionary:
		_open_room.merge(data["peer"] as Dictionary, true)
	_apply_header()
	_clear_open_room_badge()

	var incoming = data.get("messages", [])
	if not (incoming is Array):
		return

	var added := 0
	for item in incoming:
		if _append_message(item):
			added += 1

	if _messages.is_empty():
		_show_room_hint("هنوز پیامی اینجا نیست — اولین نفر باش")
	else:
		_hide_room_hint()

	if added > 0:
		_rebuild_messages()

# ------------------------------------------------------------------ پیام‌ها

## افزودن یک پیام به لیست (با حفظ ترتیب زمانی و بدون تکرار).
## true یعنی واقعاً پیام جدیدی اضافه شد.
##
## زمانِ پیام یک بار parse می‌شود و پیام با یک جست‌وجوی کوتاه از ته سرِ
## جایش می‌نشیند — به‌جای مرتب کردنِ کلِ تاریخچه (با parseِ ISO داخلِ
## مقایسه‌گر) برای هر پیام. تاریخچه حداکثر MAX_MESSAGES پیام نگه می‌دارد.
func _append_message(item: Variant) -> bool:
	if typeof(item) != TYPE_DICTIONARY:
		return false

	var message: Dictionary = item
	var id := str(message.get("message_id", ""))
	if id.is_empty() or _seen_ids.has(id):
		return false

	_seen_ids[id] = true
	var stamp := ChatBubble.iso_to_unix(str(message.get("created_at", "")))

	# پیام‌ها معمولاً به ترتیب می‌رسند و تهِ لیست می‌نشینند؛ جای عقب‌تر فقط
	# برای وقتی است که پیام WebSocket و پیام پولینگ با هم قاطی شوند
	var at := _messages.size()
	while at > 0 and _stamps[at - 1] > stamp:
		at -= 1
	_messages.insert(at, message)
	_stamps.insert(at, stamp)
	if at < _shown:
		_needs_rebuild = true

	while _messages.size() > MAX_MESSAGES:
		_drop_oldest()
	return true

## قدیمی‌ترین پیام و حبابش می‌روند (سقفِ MAX_MESSAGES)
func _drop_oldest() -> void:
	_messages.remove_at(0)
	_stamps.remove_at(0)
	if _shown <= 0:
		return
	_shown -= 1
	# اگر همه از نو ساخته می‌شوند، دست زدن به حباب‌ها بی‌فایده است
	if _needs_rebuild or _messages_box.get_child_count() == 0:
		return
	var first := _messages_box.get_child(0)
	_messages_box.remove_child(first)
	first.queue_free()
	# حبابِ تازه‌ی اول اگر ادامه‌ی گروهِ پیامِ حذف‌شده بود (بی‌هدر)، حالا
	# اولین پیامِ لیست است و هدر می‌خواهد — فقط همان یکی از نو ساخته می‌شود
	if _shown > 0 and _messages_box.get_child_count() > 0:
		var head := _messages_box.get_child(0)
		if not bool(head.get_meta(&"show_header", true)):
			_messages_box.remove_child(head)
			head.queue_free()
			var fresh := _make_bubble(_messages[0], true, _bubble_width())
			_messages_box.move_child(fresh, 0)

func _clear_messages() -> void:
	for child in _messages_box.get_children():
		_messages_box.remove_child(child)
		child.queue_free()
	_shown = 0
	_needs_rebuild = false

func _bubble_width() -> float:
	var width := _messages_scroll.size.x
	if width <= 0.0:
		width = _room_panel.size.x
	return width

## یک حباب برای یک پیام، تهِ لیست
func _make_bubble(message: Dictionary, show_header: bool, width: float) -> Node:
	var sender_id := str(message.get("sender_id", ""))
	var bubble := CHAT_BUBBLE_SCENE.instantiate()
	bubble.set_meta(&"show_header", show_header)
	_messages_box.add_child(bubble)
	bubble.avatar_pressed.connect(_on_avatar_pressed)
	bubble.set_available_width(width)
	bubble.setup(message, sender_id == str(Global.player_id),
		bool(_online.get(sender_id, false)), show_header, _leaders.has(sender_id))
	return bubble

## حباب‌ها را با _messages هم‌گام می‌کند. پیامِ تازه‌ای که تهِ لیست نشسته
## فقط حبابِ خودش را می‌گیرد؛ از نو ساختنِ همه فقط وقتی لازم است که پیامی
## وسطِ تاریخچه نشسته یا وضعیتِ آنلاین/رهبرها عوض شده.
func _rebuild_messages() -> void:
	if _needs_rebuild or _shown > _messages.size() \
			or _shown != _messages_box.get_child_count():
		_clear_messages()

	var width := _bubble_width()
	for i in range(_shown, _messages.size()):
		var message: Dictionary = _messages[i]
		# پیام‌های پشت‌سرهمِ یک نفر در فاصله‌ی کوتاه، هدر تکراری نمی‌گیرند
		var show_header := true
		if i > 0:
			show_header = str(message.get("sender_id", "")) != str(_messages[i - 1].get("sender_id", "")) \
				or _stamps[i] - _stamps[i - 1] > GROUP_WINDOW_SECONDS
		_make_bubble(message, show_header, width)
	_shown = _messages.size()

	if _stick_to_bottom:
		_scroll_to_bottom()

func _scroll_to_bottom() -> void:
	# دو فریم صبر تا کانتینر ارتفاع نهایی حباب‌ها را حساب کند
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_messages_scroll):
		_messages_scroll.scroll_vertical = int(_messages_scroll.get_v_scroll_bar().max_value)

func _on_messages_resized() -> void:
	var width := _messages_scroll.size.x
	if width <= 0.0:
		return
	for bubble in _messages_box.get_children():
		if bubble is ChatBubble:
			bubble.set_available_width(width)

## اگر بازیکن خودش بالا اسکرول کرده، پیام جدید نباید صفحه را پایین بپراند
func _on_messages_scrolled(value: float) -> void:
	var bar := _messages_scroll.get_v_scroll_bar()
	_stick_to_bottom = value >= bar.max_value - bar.page - 40.0

# ------------------------------------------------------------------ ایموجی

## پنل ایموجی: هر خانه یک عکس. داخل ScrollContainer است، پس هر خانه لمس
## را خودش می‌گیرد: کشیدن = اسکرول پنل، ضربه‌ی بدون جابه‌جایی = درج ایموجی.
func _build_emoji_grid() -> void:
	for id in ChatEmoji.list_ids():
		var cell := TextureRect.new()
		cell.texture = ChatEmoji.texture_of(id)
		cell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cell.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		cell.custom_minimum_size = Vector2(EMOJI_CELL, EMOJI_CELL)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.gui_input.connect(_on_emoji_cell_input.bind(cell, id))
		_emoji_grid.add_child(cell)
	_emoji_button.visible = _emoji_grid.get_child_count() > 0
	_emoji_grid.resized.connect(_fit_emoji_columns)
	_emoji_scroll.resized.connect(_fit_emoji_columns)

## تعداد ستون‌ها به عرض پنل بستگی دارد (گوشی دراز یا تبلت)
func _fit_emoji_columns() -> void:
	var width := _emoji_scroll.size.x - 8.0
	if width <= 0.0:
		return
	_emoji_grid.columns = maxi(3, int(width / float(EMOJI_CELL + 6)))

var _emoji_touch_start := Vector2.ZERO
var _emoji_swiping := false

## فقط رویداد تاچ (ماوسِ شبیه‌سازی‌شده از تاچ نادیده گرفته می‌شود تا ایموجی
## دو بار درج نشود؛ روی PC هم emulate_touch_from_mouse روشن است)
func _on_emoji_cell_input(event: InputEvent, cell: TextureRect, id: String) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_emoji_touch_start = event.position
			_emoji_swiping = false
			UIFx.press_scale(cell, true)
		else:
			UIFx.press_scale(cell, false)
			if not _emoji_swiping:
				UIFx.tap(cell)
				_insert_emoji(id)
		return

	if event is InputEventScreenDrag:
		if not _emoji_swiping and event.position.distance_to(_emoji_touch_start) > 12.0:
			_emoji_swiping = true
			UIFx.press_scale(cell, false)
		if _emoji_swiping:
			_emoji_scroll.scroll_vertical -= int(event.relative.y)

## توکن ایموجی جای مکان‌نما در متن می‌نشیند. اگر متن خالی باشد و بازیکن
## همین را بفرستد، پیام «فقط ایموجی» است و بزرگ نشان داده می‌شود.
func _insert_emoji(id: String) -> void:
	var token := ChatEmoji.token(id)
	if _text_edit.text.length() + token.length() > MAX_TEXT_LENGTH:
		_show_toast("متن پیام خیلی بلند است")
		return
	var caret := _text_edit.caret_column
	_text_edit.text = _text_edit.text.substr(0, caret) + token + _text_edit.text.substr(caret)
	_text_edit.caret_column = caret + token.length()
	_on_text_changed(_text_edit.text)

func _set_emoji_panel(open: bool) -> void:
	if _emoji_button.button_pressed != open:
		_emoji_button.set_pressed_no_signal(open)
	_emoji_panel.visible = open and _input_row.visible
	if _emoji_panel.visible:
		_fit_emoji_columns()
		# کیبورد گوشی جای پنل را می‌گیرد؛ وقتی پنل باز است بسته شود
		_text_edit.release_focus()
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			DisplayServer.virtual_keyboard_hide()
		if _stick_to_bottom:
			_scroll_to_bottom()

## متن با توکن ایموجی داخل LineEdit به شکل «:e01:» دیده می‌شود؛ این نوار
## کوچک بالای ورودی همان متن را با عکس‌ها نشان می‌دهد.
func _on_text_changed(text: String) -> void:
	var has_emoji := ChatEmoji.count(text) > 0
	_preview_bar.visible = has_emoji and _input_row.visible
	if has_emoji:
		var body := ChatEmoji.to_bbcode(text, EMOJI_PREVIEW_SIZE)
		if ChatBubble.is_rtl(ChatEmoji.strip(text)):
			body = "[right]%s[/right]" % body
		_preview_text.text = body

# ------------------------------------------------------------------ ستون آنلاین

func _select_people_tab(tab: String) -> void:
	_people_tab = tab
	_friends_tab.set_pressed_no_signal(tab == PEOPLE_FRIENDS)
	_city_tab.set_pressed_no_signal(tab == PEOPLE_CITY)
	_people_signature = ""
	_build_people_list()

## فقط دوستان یا هم‌شهری‌ها (بسته به تب) + فیلتر جستجو.
## عدد کنار «آنلاین» تعداد آنلاین‌های همین تب است.
func _build_people_list() -> void:
	var query := _search_edit.text.strip_edges().to_lower()
	var rows: Array = []
	var online_count := 0
	for person in _people():
		if typeof(person) != TYPE_DICTIONARY:
			continue
		var in_tab := bool(person.get("is_friend", false)) if _people_tab == PEOPLE_FRIENDS \
			else bool(person.get("is_city", false))
		if not in_tab:
			continue
		if bool(person.get("is_online", false)):
			online_count += 1
		if not query.is_empty() and str(person.get("username", "")).to_lower().find(query) == -1:
			continue
		rows.append(person)

	_people_count.text = "(%d)" % online_count

	if rows.is_empty():
		_people_scroll.visible = false
		_people_empty.visible = true
		if _overview.is_empty():
			_people_empty.text = "در حال بارگذاری ..."
		elif not query.is_empty():
			_people_empty.text = "کسی با این نام پیدا نشد"
		elif _people_tab == PEOPLE_CITY and not _in_city():
			_people_empty.text = "برای دیدن هم‌شهری‌ها باید عضو یک شهر باشی"
		elif _people_tab == PEOPLE_CITY:
			_people_empty.text = "هم‌شهری دیگری نداری"
		else:
			_people_empty.text = "هنوز دوستی نداری"
		for child in _people_list.get_children():
			_people_list.remove_child(child)
			child.queue_free()
		_people_signature = ""
		return

	_people_empty.visible = false
	_people_scroll.visible = true

	var keys := PackedStringArray()
	for person in rows:
		keys.append(str(person.get("player_id", "")))
	var signature := "|".join(keys)

	if signature == _people_signature and _people_list.get_child_count() == rows.size():
		for i in rows.size():
			(_people_list.get_child(i) as ChatOnlineRow).setup(rows[i])
		return
	_people_signature = signature

	for child in _people_list.get_children():
		_people_list.remove_child(child)
		child.queue_free()
	for person in rows:
		var row := ONLINE_ROW_SCENE.instantiate()
		row.setup(person)
		if _requested.has(str(person.get("player_id", ""))):
			row.mark_request_sent()
		row.tapped.connect(_on_person_tapped)
		row.action_pressed.connect(_on_person_action)
		_people_list.add_child(row)
	_fade_in_children(_people_list)

## ضربه روی یک نفر = کارت پروفایل
func _on_person_tapped(person: Dictionary) -> void:
	_open_profile({
		"sender_id": str(person.get("player_id", "")),
		"sender_name": str(person.get("username", "")),
		"sender_avatar": str(person.get("avatar_id", "")),
		"sender_level": int(person.get("level", 1)),
		"sender_tier_id": str(person.get("tier_id", "")),
	}, bool(person.get("is_online", false)), bool(person.get("is_friend", false)))

## دکمه‌ی گرد: دوست → گفتگوی خصوصی، غریبه → درخواست دوستی
func _on_person_action(person: Dictionary) -> void:
	var player_id := str(person.get("player_id", ""))
	if bool(person.get("is_friend", false)):
		var conversation := _find_private(player_id)
		if conversation.is_empty():
			return
		_select_channel(CHANNEL_PRIVATE)
		_open_conversation(conversation)
		return

	if not _pending_friend_id.is_empty():
		return
	var payload := {"username": Global.my_username, "target_id": player_id}
	var err := _friend_http.request(
		Global.SERVER_BASE + "/friends/request",
		Global.json_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload))
	if err != OK:
		_show_toast("ارتباط با سرور برقرار نشد")
		return
	_pending_friend_id = player_id

func _on_friend_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var player_id := _pending_friend_id
	_pending_friend_id = ""

	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		_requested[player_id] = true
		for row in _people_list.get_children():
			if row is ChatOnlineRow and row.player_id == player_id:
				row.mark_request_sent()
		_show_toast("درخواست دوستی فرستاده شد")
		return

	var message := "درخواست فرستاده نشد"
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("error"):
		message = str((parsed as Dictionary)["error"])
	elif result != HTTPRequest.RESULT_SUCCESS:
		message = "ارتباط با سرور برقرار نشد"
	_show_toast(message)

# ------------------------------------------------------------ کارت پروفایل

## بازیکن روی آواتار یک پیام ضربه زد — کارت پروفایل با دکمه‌ی درخواست
## دوستی باز می‌شود. در چت جهانی و شهر این راه اضافه کردن کسی است
## که آیدی‌اش را نداری.
func _on_avatar_pressed(data: Dictionary) -> void:
	var sender_id := str(data.get("sender_id", ""))
	if sender_id.is_empty():
		return
	_open_profile(data, bool(_online.get(sender_id, false)), _is_friend(sender_id))

func _open_profile(data: Dictionary, is_online: bool, is_friend: bool) -> void:
	if _dialog != null and is_instance_valid(_dialog):
		return
	var dialog := PROFILE_DIALOG_SCENE.instantiate()
	add_child(dialog)
	_dialog = dialog
	dialog.friend_requested.connect(func(id: String) -> void:
		_requested[id] = true
		_show_toast("درخواست دوستی فرستاده شد")
		_people_signature = ""
		refresh_overview())
	dialog.open(data, is_online, is_friend)

# ------------------------------------------------------------------ فرستادن پیام

func _on_send_pressed() -> void:
	if _sending or _open_room.is_empty():
		return

	var text := _text_edit.text.strip_edges()
	if text.is_empty():
		return
	if text.length() > MAX_TEXT_LENGTH:
		_show_toast("متن پیام خیلی بلند است")
		return

	UIFx.tap(_send_button)

	var payload := {
		"username": Global.my_username,
		"channel": str(_open_room.get("channel", "")),
		"text": text,
	}
	var peer_id := str(_open_room.get("peer_id", ""))
	if not peer_id.is_empty():
		payload["peer_id"] = peer_id

	var err := _send_http.request(
		Global.SERVER_BASE + "/chat/send",
		Global.json_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if err != OK:
		_show_toast("ارتباط با سرور برقرار نشد")
		return

	_sending = true
	_send_button.disabled = true
	_text_edit.text = ""
	_on_text_changed("")
	_set_emoji_panel(false)
	# کیبورد گوشی باز بماند تا بشود پشت سر هم نوشت (اگر از قبل باز بوده)
	if _text_edit.has_focus():
		_text_edit.grab_focus()

func _on_send_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_sending = false
	_send_button.disabled = false

	var parsed = JSON.parse_string(body.get_string_from_utf8())

	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
		# پیام خودم را همان لحظه نشان می‌دهم (سرور روی WebSocket برای خود
		# فرستنده پیامی نمی‌فرستد)
		if typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("message"):
			var message = (parsed as Dictionary)["message"]
			if message is Dictionary and str((message as Dictionary).get("room", "")) == str(_open_room.get("room", "")):
				_stick_to_bottom = true
				if _append_message(message):
					_hide_room_hint()
					_rebuild_messages()
		refresh_overview()
		return

	var message := "پیام فرستاده نشد (کد %d)" % response_code
	if result != HTTPRequest.RESULT_SUCCESS:
		message = "ارتباط با سرور برقرار نشد — اینترنت را بررسی کن"
	elif typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has("error"):
		message = str((parsed as Dictionary)["error"])
	_show_toast(message)

# ------------------------------------------------------------------ بلادرنگ

## پیام تازه‌ای از سرور روی WebSocket رسید
func _on_chat_message(data: Dictionary) -> void:
	var room := str(data.get("room", ""))

	# اگر همین اتاق باز است، پیام را سر جایش می‌نشانیم
	if room == str(_open_room.get("room", "")):
		if _append_message(data):
			_hide_room_hint()
			_rebuild_messages()
		# بازیکن دارد همین گفتگو را نگاه می‌کند، پس پیام خوانده حساب می‌شود
		_mark_open_room_read()
		return

	# وگرنه فقط کارت‌ها/لیست تازه می‌شوند تا نشان قرمزشان بالا برود
	_queue_overview_refresh()

## به سرور می‌گوید بازیکن گفتگوی باز را تا همین لحظه دیده است، تا نشان
## قرمز همین حالا صفر شود و منتظر رفرش بعدی نماند.
func _mark_open_room_read() -> void:
	if _open_room.is_empty():
		return

	var payload := {
		"username": Global.my_username,
		"channel": str(_open_room.get("channel", "")),
	}
	var peer_id := str(_open_room.get("peer_id", ""))
	if not peer_id.is_empty():
		payload["peer_id"] = peer_id

	_read_http.cancel_request()
	_read_http.request(
		Global.SERVER_BASE + "/chat/read",
		Global.json_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

func _on_social_event(_kind: String) -> void:
	refresh_overview()

## تور ایمنی: هم لیست کانال‌ها تازه می‌شود هم پیام‌های احتمالی جامانده
func _on_refresh_tick() -> void:
	refresh_overview()
	if not _open_room.is_empty():
		_request_history(false)

# ------------------------------------------------------------ چرخه‌ی عمر و Back

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back()
		NOTIFICATION_APPLICATION_PAUSED:
			# اپ رفت پس‌زمینه — پولینگ لازم نیست
			if is_node_ready():
				_refresh_timer.stop()
		NOTIFICATION_APPLICATION_RESUMED:
			# برگشت از پس‌زمینه: هرچه در این فاصله آمده را یکجا بگیر
			if is_node_ready():
				_refresh_timer.start()
				_on_refresh_tick()
		NOTIFICATION_EXIT_TREE:
			get_tree().set_quit_on_go_back(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()

## ترتیب Back: پنجره‌ی پروفایل ← پنل ایموجی ← گفتگوی خصوصی ← منوی اصلی
func _on_back() -> void:
	# Back اندروید هم notification می‌فرستد هم ui_cancel؛ فقط یک بار
	var frame := Engine.get_process_frames()
	if frame == _back_frame:
		return
	_back_frame = frame

	if _dialog != null and is_instance_valid(_dialog):
		_dialog.close()
		return
	if _channel_menu != null and _channel_menu.visible:
		_channel_menu.hide()
		return
	if _emoji_panel.visible:
		_set_emoji_panel(false)
		return
	if _channel == CHANNEL_PRIVATE and not _open_room.is_empty():
		_close_private_room()
		return
	_go_home()

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
	_toast_tween.chain().tween_interval(1.8)
	_toast_tween.chain().tween_property(_toast, "modulate:a", 0.0, 0.28) \
		.set_trans(Tween.TRANS_SINE)
	_toast_tween.chain().tween_callback(func() -> void: _toast.visible = false)

# ------------------------------------------------------------------ انیمیشن و ناوبری

func _fade_in_children(list: Container) -> void:
	var rows := list.get_children()
	for i in mini(rows.size(), 9):
		var row := rows[i] as Control
		if row == null:
			continue
		row.modulate.a = 0.0
		var t := row.create_tween()
		t.tween_interval(0.035 * i)
		t.tween_property(row, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_SINE)

func _go_home() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
