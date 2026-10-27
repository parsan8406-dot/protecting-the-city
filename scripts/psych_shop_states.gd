extends RefCounted
## وضعیت‌های فروشگاه: اسکلتِ در حالِ بارگذاری (C12)، خطا با «دوباره» (شبکه‌ی ناپایدار)،
## خالی (E1/E10) و ورودِ پله‌ای کارت‌ها (V7). همه با Tween، بدون _process.

## کارت‌های خاکستریِ چشمک‌زن داخلِ یک کانتینر — با clear_container خودشان پاک می‌شوند
static func skeleton(container: Node, count: int, card_size: Vector2) -> void:
	if container == null:
		return
	for i in count:
		var p := Panel.new()
		p.name = "Skeleton%d" % i
		p.custom_minimum_size = card_size
		p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		p.add_theme_stylebox_override("panel", MenuUI.box(Color(0.13, 0.13, 0.15, 0.9), Color(1, 1, 1, 0.06), 1, 8))
		p.set_meta("skeleton", true)
		container.add_child(p)
		p.modulate.a = 0.45
		var tw := p.create_tween().set_loops()
		tw.tween_interval(0.08 * i)
		tw.tween_property(p, "modulate:a", 0.9, 0.55).set_trans(Tween.TRANS_SINE)
		tw.tween_property(p, "modulate:a", 0.45, 0.55).set_trans(Tween.TRANS_SINE)


## پنلِ وسطِ parent: آیکن، عنوان، توضیح و یک دکمه (اختیاری). قبلی را جایگزین می‌کند.
static func notice(parent: Control, title: String, body: String, button_text: String = "",
		on_button: Callable = Callable(), icon_path: String = "") -> Control:
	clear_notice(parent)
	var root := Control.new()
	root.name = "ShopNotice"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.z_index = 5
	# پشتِ پیام کم‌رنگ شود تا جای‌خالی‌های پشتش «خراب» دیده نشوند (V3 شکل-زمینه)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var card := PanelContainer.new()
	var st := MenuUI.box(Color(0.05, 0.05, 0.06, 0.96), MenuUI.GOLD_DEEP, 1, 10)
	st.border_width_top = 3
	st.border_color = MenuUI.RED
	st.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", st)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var ic := MenuUI.icon(load(icon_path), 72)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(ic)
	var t := MenuUI.label(title, 24, MenuUI.TEXT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var b := MenuUI.label(body, 16, MenuUI.MUTED)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.x = 380
	col.add_child(b)
	if button_text != "":
		var btn := MenuUI.button(button_text, "gold", 20)
		btn.custom_minimum_size.x = 220
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(func() -> void: UIFx.tap(btn, on_button))
		col.add_child(btn)
	parent.add_child(root)
	root.modulate.a = 0.0
	root.create_tween().tween_property(root, "modulate:a", 1.0, 0.2)
	return root


static func clear_notice(parent: Control) -> void:
	if parent == null:
		return
	var old := parent.get_node_or_null("ShopNotice")
	if old:
		parent.remove_child(old)
		old.queue_free()


## V7 ورودِ پله‌ای: محو + کمی بزرگ شدن؛ هر کارت ≤ ۲۲۰ms، ورودی بلاک نمی‌شود
static func stagger_in(container: Node, max_items: int = 10) -> void:
	if container == null:
		return
	var i := 0
	for c in container.get_children():
		var ctl := c as Control
		if ctl == null or ctl.is_queued_for_deletion() or not ctl.visible:
			continue
		if i >= max_items:
			break
		var delay := 0.035 * i
		ctl.modulate.a = 0.0
		ctl.pivot_offset = ctl.custom_minimum_size * 0.5 if ctl.size == Vector2.ZERO else ctl.size * 0.5
		ctl.scale = Vector2(0.94, 0.94)
		var tw := ctl.create_tween().set_parallel(true)
		tw.tween_property(ctl, "modulate:a", 1.0, 0.18).set_delay(delay)
		tw.tween_property(ctl, "scale", Vector2.ONE, 0.22).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1


## «−۶٬۰۰۰» که از روی دکمه‌ی خرید بالا می‌رود و محو می‌شود (V7 بازخوردِ صادقانه‌ی خرج)
static func spend_float(host: Control, from: Control, amount: int, icon: Texture2D) -> void:
	if host == null or not host.is_inside_tree() or amount <= 0:
		return
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.z_index = 60
	row.add_theme_constant_override("separation", 4)
	var l := MenuUI.label("−" + MenuUI.fa_grouped(amount), 26, MenuUI.GOLD, true)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	row.add_child(l)
	if icon:
		row.add_child(MenuUI.icon(icon, 26))
	host.add_child(row)
	row.reset_size()
	# دکمه‌ی مبدأ در تبِ دیگری است (خرید از پنجره‌ی پیش‌نمایش) → وسطِ صفحه
	var r := from.get_global_rect() if from != null and from.is_visible_in_tree() 		else Rect2(host.get_global_rect().get_center(), Vector2.ZERO)
	var to_local := host.get_global_transform_with_canvas().affine_inverse()
	row.position = to_local * Vector2(r.get_center().x - row.size.x * 0.5, r.position.y - row.size.y * 0.2)
	var tw := row.create_tween().set_parallel(true)
	tw.tween_property(row, "position:y", row.position.y - 56.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(row, "modulate:a", 0.0, 0.35).set_delay(0.6)
	tw.chain().tween_callback(row.queue_free)
