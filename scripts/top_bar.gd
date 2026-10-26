extends TextureRect
## نوار بالای صفحه (پروفایل، سطح، سکه، جم و آیکون‌های چت/دوستان/تنظیمات)
## این صحنه (top_bar.tscn) توی هر منویی که لازمه (main_menu, shop, character_select و...)
## به عنوان instance گذاشته میشه، به جای اینکه هر بار از نو ساخته یا کپی‌پیست بشه.
##
## دیتا مستقیم از Global (autoload) خونده میشه. هر جای دیگه پروژه که Global.coins/gems/...
## آپدیت بشه (مثلاً بعد از خرید توی شاپ با Global.refresh_player_data())، سیگنال
## player_data_updated فایر میشه و همه‌ی نسخه‌های TopBar روی همه‌ی صحنه‌ها خودکار سینک میشن.

const SHOP_SCENE_PATH := "res://secense/shop.tscn"
const SHOP_TAB_CURRENCY := 3  # ترتیب تب‌ها توی shop.gd: 0=ویژه، 1=کاراکتر، 2=سلاح، 3=سکه/جم
const PROFILE_MENU_SCENE_PATH := "res://secense/profile_menu.tscn"
const TOUCH := preload("res://scripts/psych_menu_touch.gd")

## آخرین عددهای نشان‌داده‌شده — برای پالسِ «عوض شد» (V10)
var _shown_coins := -1
var _shown_gems := -1

@onready var name_text: Label = $HBoxContainer/Profile/VBoxContainer/NameLabel
@onready var level_text: Label = $HBoxContainer/Profile/LevelLabel
@onready var xp_text: Label = $HBoxContainer/Profile/XpLabel
# نوار پرشدن تجربه — عرضش با نسبت display_xp/max_xp عوض می‌شود
@onready var level_fill: Control = $HBoxContainer/Profile/LevelManager/LevelFill
@onready var coins_text: Label = $HBoxContainer/Amounts/Coins/Row/CoinsLabel
@onready var gems_text: Label = $HBoxContainer/Amounts/Gems/Row/GemsLabel

@onready var coins_plus_button: TextureButton = $HBoxContainer/Amounts/Coins/Row/PlusButton
@onready var gems_plus_button: TextureButton = $HBoxContainer/Amounts/Gems/Row/PlusButton

# دکمه‌هایی که منوی کاربر (profile_menu) رو روی تب مربوطه باز می‌کنن
@onready var profile_button: TextureButton = $HBoxContainer/Profile/ProfileButton
@onready var edit_button: TextureButton = $HBoxContainer/Profile/VBoxContainer/EditButton
@onready var messages_button: TextureButton = $HBoxContainer/HBoxContainer3/MessagesButton
@onready var friends_button: TextureButton = $HBoxContainer/HBoxContainer3/FriendsButton
@onready var settings_button: TextureButton = $HBoxContainer/HBoxContainer3/SettingsButton

## عکس پیش‌فرض صحنه — اگر آواتاری پیدا نشد به همین برمی‌گردیم
@onready var _default_avatar: Texture2D = (
	$HBoxContainer/Profile/ProfileButton.texture_normal as Texture2D
)

# نشان قرمز روی آیکون پیام‌ها — فقط وقتی پیام خوانده‌نشده هست دیده می‌شود
@onready var unread_badge: TextureRect = $HBoxContainer/HBoxContainer3/MessagesButton/Badge
@onready var unread_label: Label = $HBoxContainer/HBoxContainer3/MessagesButton/Badge/Label

func _ready() -> void:
	if not Global.player_data_updated.is_connected(_on_player_data_updated):
		Global.player_data_updated.connect(_on_player_data_updated)
	if not Global.unread_count_updated.is_connected(_on_unread_count_updated):
		Global.unread_count_updated.connect(_on_unread_count_updated)
	# اگه دیتا از قبل (توسط autoload) لود شده باشه، همین الان نمایشش بده
	_on_player_data_updated()
	_on_unread_count_updated(Global.unread_messages)

	# دکمه‌های + هم مثل بقیه‌ی آیکن‌ها اول انیمیشن فشردن را نشان می‌دهند،
	# بعد به شاپ می‌روند — بدون بازخورد، لمسِ یک دکمه‌ی ۲۲ پیکسلی گم می‌شد
	UIFx.bind_press(coins_plus_button, _on_currency_plus_pressed)
	UIFx.bind_press(gems_plus_button, _on_currency_plus_pressed)

	_wire_profile_menu_button(profile_button, "profile")
	_wire_profile_menu_button(edit_button, "profile")
	_wire_profile_menu_button(settings_button, "settings")
	_wire_profile_menu_button(friends_button, "friends")
	_wire_profile_menu_button(messages_button, "messages")

	# C3 فیتس: پلاس‌ها ۲۲ و آیکن‌ها ۳۴ پیکسل‌اند — ناحیه‌ی لمس حداقل ~۴۸dp
	for b in [coins_plus_button, gems_plus_button, profile_button, edit_button,
			messages_button, friends_button, settings_button]:
		TOUCH.expand(b, self)

## هر آیکون تاپ‌بار رو به یک تب از منوی کاربر وصل می‌کنه:
## اول انیمیشن فشردن پخش میشه، بعد صحنه عوض میشه.
func _wire_profile_menu_button(button: TextureButton, tab_id: String) -> void:
	if button == null:
		return
	UIFx.bind_press(button, _go_to_profile_menu.bind(tab_id))

## رفتن به صحنه‌ی منوی کاربر روی تب خواسته‌شده.
## اگه از قبل توی همین صحنه باشیم، profile_menu.gd با گوش دادن به سیگنال Global
## فقط تب رو عوض می‌کنه و صحنه ریلود نمیشه.
func _go_to_profile_menu(tab_id: String) -> void:
	Global.request_profile_tab(tab_id)
	var current_scene := get_tree().current_scene
	if current_scene and current_scene.scene_file_path == PROFILE_MENU_SCENE_PATH:
		return
	get_tree().change_scene_to_file(PROFILE_MENU_SCENE_PATH)

func _on_player_data_updated() -> void:
	if name_text:
		name_text.text = Global.my_username
	if level_text:
		level_text.text = "سطح " + MissionArt.fa_number(Global.level)
	if xp_text:
		xp_text.text = "%s / %s" % [
			MissionArt.fa_grouped(Global.display_xp), MissionArt.fa_grouped(Global.max_xp)
		]
	if coins_text:
		coins_text.text = MissionArt.fa_grouped(Global.coins)
	if gems_text:
		gems_text.text = MissionArt.fa_grouped(Global.gems)
	# V10: عددِ تازه یک پالسِ کوچک می‌زند تا تغییر (جایزه/خرید) دیده شود
	if _shown_coins >= 0 and Global.coins != _shown_coins:
		_pulse(coins_text, Global.coins > _shown_coins)
	if _shown_gems >= 0 and Global.gems != _shown_gems:
		_pulse(gems_text, Global.gems > _shown_gems)
	_shown_coins = Global.coins
	_shown_gems = Global.gems

	_apply_xp_bar()
	_apply_avatar(str(Global.avatar_id))

## نوار تجربه در تاپ‌بار.
## قبلاً عرضش در صحنه ثابت (۲ پیکسل) بود و هرگز حرکت نمی‌کرد، برای همین
## گرفتن چند تجربه هیچ اثر دیداری‌ای نداشت. حالا با anchor_right پر می‌شود.
func _apply_xp_bar() -> void:
	if level_fill == null:
		return

	var maximum := maxi(Global.max_xp, 1)
	var ratio := clampf(float(Global.display_xp) / float(maximum), 0.0, 1.0)

	# نوار خالی هم یک سرِ نازک داشته باشد تا تکسچرش بد کشیده نشود
	if ratio > 0.0:
		ratio = maxf(ratio, 0.02)

	level_fill.offset_right = 0.0
	if is_equal_approx(level_fill.anchor_right, ratio):
		return

	create_tween().tween_property(level_fill, "anchor_right", ratio, 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## عکس پروفایل تاپ‌بار را با آواتار انتخابی بازیکن سینک می‌کند.
## هر جا Global.avatar_id عوض بشه و player_data_updated فایر بشه،
## این خودکار صدا زده می‌شود (مثلاً بعد از انتخاب آواتار در تب پروفایل).
func _apply_avatar(avatar_id: String) -> void:
	if profile_button == null:
		return

	var avatar_texture := AvatarPicker.load_avatar_texture(avatar_id)
	if avatar_texture == null:
		# آواتار ذخیره‌شده پیدا نشد — عکس پیش‌فرض خود صحنه سر جایش می‌ماند
		if _default_avatar != null:
			profile_button.texture_normal = _default_avatar
		return

	if profile_button.texture_normal == avatar_texture:
		return

	profile_button.texture_normal = avatar_texture

## نشان پیام‌های خوانده‌نشده: صفر یعنی مخفی، بیشتر از ۹ یعنی «۹+»
func _on_unread_count_updated(count: int) -> void:
	if unread_badge == null:
		return

	var had_badge := unread_badge.visible
	unread_badge.visible = count > 0
	if count <= 0:
		return

	if unread_label:
		unread_label.text = "9+" if count > 9 else str(count)

	# وقتی نشان تازه ظاهر می‌شود یک تپش کوچک بزند تا به چشم بیاید
	if not had_badge:
		unread_badge.pivot_offset = unread_badge.size * 0.5
		unread_badge.scale = Vector2(0.4, 0.4)
		create_tween().tween_property(unread_badge, "scale", Vector2.ONE, 0.32) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## وقتی دکمه‌ی + کنار سکه یا جم زده بشه: میره توی شاپ و مستقیم روی تب سکه/جم (Currency) میشینه.
## اگه از قبل توی خود صحنه‌ی شاپ باشیم، shop.gd خودش با گوش‌دادن به سیگنال Global،
## بدون تعویض صحنه، تب رو عوض می‌کنه.
func _on_currency_plus_pressed() -> void:
	Global.request_shop_tab(SHOP_TAB_CURRENCY)
	var current_scene := get_tree().current_scene
	if current_scene and current_scene.scene_file_path == SHOP_SCENE_PATH:
		return
	get_tree().change_scene_to_file(SHOP_SCENE_PATH)


## V10: پالسِ کوتاهِ عدد — افزایش طلایی، کاهش بی‌رنگ (فقط بزرگ و برگشت)
func _pulse(label: Label, gained: bool) -> void:
	if label == null or not label.is_visible_in_tree():
		return
	label.pivot_offset = label.size * 0.5
	var tw := label.create_tween().set_parallel(true)
	tw.tween_property(label, "scale", Vector2(1.22, 1.22), 0.09) 		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if gained:
		tw.tween_property(label, "modulate", Color(1.25, 1.1, 0.6), 0.09)
	tw.chain().tween_property(label, "scale", Vector2.ONE, 0.26) 		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate", Color.WHITE, 0.3)
