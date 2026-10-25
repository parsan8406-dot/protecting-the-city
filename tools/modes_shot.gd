extends SceneTree
## عکس از صفحه‌ی انتخاب مود در یک اندازه‌ی دلخواه:
##   godot --path . -s tools/modes_shot.gd -- 1152x648 out.png
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := "user://modes.png"
	if args.size() >= 1:
		var wh := args[0].split("x")
		var sz := Vector2i(int(wh[0]), int(wh[1]))
		DisplayServer.window_set_size(sz)
		root.size = sz
	if args.size() >= 2:
		out = args[1]
	var s = load("res://secense/game_modes.tscn").instantiate()
	root.add_child(s)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("saved cards=", s._list.get_child_count(), " -> ", out)
	quit(0)
