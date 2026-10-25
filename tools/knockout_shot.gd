extends SceneTree
## فریم‌به‌فریمِ افکتِ ناک‌اوت (پفِ دودِ کارتونی + ستاره‌ها) و جرقه‌ی ضربه،
## روی یک کاراکترِ واقعی با همان زومِ دوربینِ بازی — برای تنظیمِ اندازه و
## زمان‌بندی. خانه‌ی اول جرقه‌ی ضربه است، بقیه لحظه‌های ناک‌اوت (TIMES).
##
##   Godot --path . -s tools/knockout_shot.gd -- --out=C:/tmp/knockout.png

const CELL := 300
const ZOOM := 2.0                       ## همان zoomِ Camera2Dِ World.tscn
const TIMES := [0.04, 0.10, 0.18, 0.30, 0.45, 0.60, 0.75, 0.88]


func _initialize() -> void:
	var out := "user://knockout_shot.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)

	# autoloadها (CombatFX) و خودِ ریشه یکی دو فریم بعد وارد درخت می‌شوند
	await process_frame
	await process_frame
	var root := get_root()
	root.transparent_bg = false
	DisplayServer.window_set_size(Vector2i(CELL, CELL))
	root.size = Vector2i(CELL, CELL)

	var layer := CanvasLayer.new()
	layer.layer = -1
	root.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.17, 0.20)
	bg.size = Vector2(CELL, CELL)
	layer.add_child(bg)

	var cam := Camera2D.new()
	cam.zoom = Vector2(ZOOM, ZOOM)
	root.add_child(cam)
	cam.make_current()

	var fx: Node = root.get_node("/root/CombatFX")
	var victim := _spawn(root)
	var sheet := Image.create(CELL * (TIMES.size() + 1), CELL, false, Image.FORMAT_RGBA8)

	await _wait(0.2)
	fx.hit_burst(Vector2(6, -4), Vector2(0, -1))
	await _wait(0.05)
	await _grab(root, sheet, 0)

	await _wait(0.5)
	fx.death(victim)
	var t0 := Time.get_ticks_usec()
	for i in TIMES.size():
		while (Time.get_ticks_usec() - t0) / 1e6 < TIMES[i]:
			fx.set("_shake", 0.0)       # لرزشِ دوربین کادر را جابه‌جا نکند
			cam.offset = Vector2.ZERO
			await process_frame
		await _grab(root, sheet, i + 1)
		var poof: Object = fx.get("_poof")[0]
		print("frame %d  t_real=%.3f  poof_t=%.3f  on=%s  processing=%s  drawn=%d" % [
			i + 1, (Time.get_ticks_usec() - t0) / 1e6, poof.t, poof.on,
			fx.is_processing(), Engine.get_frames_drawn()])

	sheet.save_png(out)
	print("saved ", out)
	quit()


func _spawn(root: Node) -> Node2D:
	var p: Node2D = load("res://secense/player_s.tscn").instantiate()
	root.add_child(p)
	p.set_script(null)                  # اسکریپتِ گیم‌پلی لازم نیست
	var hb := p.get_node_or_null("HealthBar")
	if hb != null:
		hb.hide()
	CharacterSkin.apply(p.get_node("Sprite2D"), "skin_default")
	return p


func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_usec()
	while (Time.get_ticks_usec() - t0) / 1e6 < sec:
		await process_frame


func _grab(root: Window, sheet: Image, cell: int) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	sheet.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(cell * CELL, 0))
