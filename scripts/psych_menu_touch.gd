extends RefCounted
## C3 فیتس: ناحیه‌ی لمسِ دکمه‌های ریز بزرگ‌تر از ظاهرشان.
##
## بعضی دکمه‌ها (پلاسِ کنارِ سکه، آیکن‌های نوارِ بالا، برگشتِ سربرگ) در
## آرت ۱۳ تا ۴۲ پیکسل‌اند و جا برای بزرگ کردنِ خودشان نیست. این‌جا یک
## «پد»ِ نامرئی هم‌مرکز با دکمه گذاشته می‌شود که حداقل MIN_SIDE است و
## لمس را به خودِ دکمه می‌رساند (button_down / button_up / pressed)، پس
## هر چه به دکمه وصل است — UIFx، تغییرِ صحنه — بدونِ تغییر کار می‌کند.
##
## پد بچه‌ی `host` است، نه خودِ دکمه: Godot لمسی را که بیرونِ مستطیلِ والد
## بیفتد به بچه‌ها نمی‌رساند، پس پدِ بچه‌ی دکمه‌ی ۲۲ پیکسلی عملاً همان ۲۲
## پیکسل می‌ماند. host باید ظرفِ بزرگی مثلِ خودِ نوارِ بالا باشد؛ پد داخلِ
## مستطیلِ host بریده می‌شود.
##
## فقط تاچ خوانده می‌شود (روی PC هم emulate_touch_from_mouse روشن است).
## کشیدنِ انگشت بیش از DRAG_SLOP یعنی کلیک نیست.
##
##   preload("res://scripts/psych_menu_touch.gd").expand(button, top_bar)

## ۴۸dp ≈ ۹۰ پیکسل در 1080p = ۵۴ واحد روی ارتفاعِ ۶۴۸ِ ویوپورت
const MIN_SIDE := 54.0
const DRAG_SLOP := 14.0


static func expand(button: BaseButton, host: Control, min_side: float = MIN_SIDE) -> void:
	if button == null or host == null or not is_instance_valid(button):
		return
	if button.has_meta("_hit_pad"):
		return
	var pad := _HitPad.new()
	pad.name = "_HitPad_%s_%d" % [button.name, button.get_instance_id()]
	pad.target = button
	pad.host = host
	pad.min_side = min_side
	button.set_meta("_hit_pad", pad)
	# آخرین بچه = اولین گیرنده‌ی لمس در همان ناحیه
	host.add_child.call_deferred(pad)


class _HitPad extends Control:
	var target: BaseButton = null
	var host: Control = null
	var min_side := 54.0
	var _down := false
	var _start := Vector2.ZERO

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		target.item_rect_changed.connect(_fit)
		target.visibility_changed.connect(_fit)
		target.tree_exiting.connect(queue_free)
		host.item_rect_changed.connect(_fit)
		_fit.call_deferred()

	## هم‌مرکز با دکمه، حداقل min_side، داخلِ مستطیلِ host
	func _fit() -> void:
		if not is_instance_valid(target) or not target.is_inside_tree() or not is_inside_tree():
			return
		var on := target.is_visible_in_tree()
		visible = on
		mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
		if not on:
			return
		var to_host := host.get_global_transform().affine_inverse()
		var r := target.get_global_rect()
		var c := to_host * r.get_center()
		var want := Vector2(maxf(r.size.x, min_side), maxf(r.size.y, min_side))
		# نزدیکِ لبه‌ی host به‌جای بریدن جابه‌جا می‌شود، تا اندازه کم نشود
		want = want.min(host.size)
		position = (c - want * 0.5).clamp(Vector2.ZERO, host.size - want)
		size = want

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			accept_event()
			if target.disabled or not target.is_visible_in_tree():
				_down = false
				return
			var pos := get_global_transform_with_canvas() * (event as InputEventScreenTouch).position
			if event.pressed:
				_down = true
				_start = pos
				target.button_down.emit()
				return
			if not _down:
				return
			_down = false
			target.button_up.emit()
			if pos.distance_to(_start) <= DRAG_SLOP:
				target.pressed.emit()
		elif event is InputEventScreenDrag and _down:
			accept_event()
			var pos2 := get_global_transform_with_canvas() * (event as InputEventScreenDrag).position
			if pos2.distance_to(_start) > DRAG_SLOP:
				_down = false
				target.button_up.emit()
		elif event is InputEventMouseButton:
			# ماوسِ شبیه‌سازی‌شده از تاچ (اندروید) — همان لمس است، دوباره حساب نشود
			accept_event()
