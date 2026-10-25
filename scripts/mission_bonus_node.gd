extends VBoxContainer
## یک صندوق روی نوار «جایزه‌ی روزانه» بالای صفحه‌ی ماموریت‌ها.
##
## سه پله داریم (۲ / ۴ / ۶ ماموریتِ دریافت‌شده) و هر کدام یکی از این‌هاست.
##
## هیچ تصمیمی اینجا گرفته نمی‌شود: `state` را سرور در پاسخ /missions/daily
## می‌فرستد (locked | ready | claimed) و اینجا فقط رنگ و انیمیشن می‌شود.
## زدن روی صندوق هم فقط سیگنال می‌دهد؛ واریز جایزه با POST /missions/bonus/claim
## سمت سرور انجام می‌شود و سرور خودش دوباره چک می‌کند که واقعاً بازش کرده باشد.

## بازیکن روی صندوقِ آماده زد — `need` همان پله است (۲ / ۴ / ۶)
signal claim_requested(need: int)
## بازیکن روی صندوقِ قفل یا بازشده زد. قبلاً این لمس بی‌صدا نادیده گرفته
## می‌شد و بازیکن فکر می‌کرد صندوق خراب است؛ حالا صفحه توضیح می‌دهد چرا.
signal unavailable_tapped(need: int, state: String)

const COLOR_LOCKED := Color(0.29, 0.34, 0.41, 1.0)

@onready var _glow: Panel = $Slot/Glow
@onready var _button: TextureButton = $Slot/ChestButton
@onready var _need_label: Label = $NeedLabel

## هاله‌ی صندوقِ آماده — یک بار ساخته و بین همه‌ی گره‌ها مشترک است
static var _glow_style: StyleBoxFlat = null

## پله‌ی این صندوق — صفحه با همین عدد درخواست دریافت می‌فرستد
var need: int = 0

var _tier: Dictionary = {}
var _built := false
## نبض صندوقِ آماده — نگه داشته می‌شود تا موقع عوض شدن حالت متوقفش کنیم
var _pulse: Tween = null

func _ready() -> void:
	if _glow_style == null:
		_glow_style = StyleBoxFlat.new()
		_glow_style.bg_color = Color(0.91, 0.76, 0.29, 0.14)
		_glow_style.set_border_width_all(1)
		_glow_style.border_color = Color(0.91, 0.76, 0.29, 0.55)
		_glow_style.set_corner_radius_all(8)
	_glow.add_theme_stylebox_override("panel", _glow_style)

	_button.pressed.connect(func() -> void:
		UIFx.tap(_button)
		var state := str(_tier.get("state", ""))
		if state == "ready":
			claim_requested.emit(need)
		else:
			unavailable_tapped.emit(need, state))

	if not _tier.is_empty():
		_apply(_tier)
	_built = true

## پر کردن از یک آیتم `bonus` در پاسخ /missions/daily
func setup(tier: Dictionary) -> void:
	_tier = tier
	need = int(tier.get("need", 0))
	if is_node_ready() or _built:
		_apply(tier)

func _apply(tier: Dictionary) -> void:
	var state := str(tier.get("state", "locked"))
	var color := MissionArt.chest_color(str(tier.get("icon", "")))

	_button.texture_normal = MissionArt.texture_for(str(tier.get("icon", "chest")))
	_need_label.text = MissionArt.fa_number(need)

	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_pulse = null
	_glow.visible = false
	_button.modulate = Color(1, 1, 1, 1)
	_button.scale = Vector2.ONE

	# صندوق‌ها آرت رنگی‌اند، پس رنگشان را عوض نمی‌کنیم — فقط روشن و تاریکشان
	# می‌کنیم. (اگر یک روز به آیکن سفید برگشتیم، is_art_icon جواب false می‌دهد
	# و همان رنگ‌آمیزی قدیمی برمی‌گردد.)
	var art := MissionArt.is_art_icon(str(tier.get("icon", "")))

	match state:
		"ready":
			# آماده: رنگ کامل، هاله، و یک نبض آرام که چشم را بگیرد
			_button.self_modulate = Color(1, 1, 1, 1) if art else color
			_need_label.add_theme_color_override("font_color", color)
			_glow.visible = true
			_start_pulse()
		"claimed":
			# گرفته‌شده: کم‌جان، تا از قفل قابل تشخیص باشد
			_button.self_modulate = Color(1, 1, 1, 1) if art else color
			_button.modulate = Color(1, 1, 1, 0.4)
			_need_label.add_theme_color_override("font_color", MissionArt.COLOR_DIM)
		_:
			# قفل: تاریک و بی‌رنگ، ولی هنوز شکل صندوق پیداست
			_button.self_modulate = Color(0.34, 0.38, 0.45, 1.0) if art else COLOR_LOCKED
			_need_label.add_theme_color_override("font_color", MissionArt.COLOR_DIM)

func _start_pulse() -> void:
	_button.pivot_offset = _button.size * 0.5
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_button, "scale", Vector2(1.08, 1.08), 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(_button, "scale", Vector2.ONE, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
