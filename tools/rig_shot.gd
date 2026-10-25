extends SceneTree

# چند اسکین را با ریگ واقعی رندر می‌کند تا مطمئن شویم فرم/جهت/مقیاس درست است.
# اجرا:  Godot.exe --path . --script res://tools/rig_shot.gd --  <out.png>

var SKINS := ["skin_default", "skin_girl", "skin_devil", "skin_roman", "skin_engineer"]
var CELL := 260
var ANIM_T := [0.0, 0.0, 1.2, 0.31, 0.04]      # rest, idle start, idle peak, walk peak, shoot peak
var ANIM_N := ["RESET", "idle", "idle", "walk", "shoot"]


func _init() -> void:
	var out_path := "user://rig_shot.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_path = args[0]

	var env_skins := OS.get_environment("RIG_SKINS")
	if not env_skins.is_empty():
		SKINS = env_skins.split(",")
	if OS.get_environment("RIG_REST_ONLY") == "1":
		ANIM_T = [0.0]
		ANIM_N = ["RESET"]
	var env_cell := OS.get_environment("RIG_CELL")
	if not env_cell.is_empty():
		CELL = env_cell.to_int()

	var root := get_root()
	root.transparent_bg = false
	var w := CELL * SKINS.size()
	var h := CELL * ANIM_N.size()
	DisplayServer.window_set_size(Vector2i(w, h))
	root.size = Vector2i(w, h)

	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.11, 0.13)
	bg.size = Vector2(w, h)
	root.add_child(bg)

	var scene: PackedScene = load("res://secense/player_s.tscn")
	for col in range(SKINS.size()):
		for row in range(ANIM_N.size()):
			var p := scene.instantiate()
			root.add_child(p)
			p.set_script(null)                      # اسکریپت گیم‌پلی لازم نیست
			p.position = Vector2(col * CELL + CELL * 0.5, row * CELL + CELL * 0.55)
			var sc := 1.0
			var env_sc := OS.get_environment("RIG_SCALE")
			if not env_sc.is_empty():
				sc = env_sc.to_float()
			p.scale = Vector2(sc, sc)               # 1.0 = همان اندازه‌ی داخل بازی
			var hb := p.get_node_or_null("HealthBar")
			if hb != null:
				hb.hide()
			CharacterSkin.apply(p.get_node("Sprite2D"), SKINS[col])
			# سوییپ دستی برای تنظیم بازو: ARM_TRIAL="outwardPx,rotL,rotR"
			var trial := OS.get_environment("ARM_TRIAL")
			if not trial.is_empty():
					var f := trial.split(",")
					var sk := p.get_node("Body") as Skeleton2D
					var lb := sk.get_node("Bone2D/Bone2D/Bone2D3/LArmRoot") as Bone2D
					var rb := sk.get_node("Bone2D/Bone2D/Bone2D2/RArmRoot") as Bone2D
					var ow := f[0].to_float() * 0.158
					lb.rotation = f[1].to_float()
					rb.rotation = f[2].to_float()
					lb.position = lb.rest.origin - Vector2(ow, 0.0)
					rb.position = rb.rest.origin + Vector2(ow, 0.0)
			var gun := p.get_node_or_null("gun") as Sprite2D
			if gun != null:
				gun.texture = load("res://assets/gunak47-Fighter.png")
				# RIG_WEAPONS="ak47,ak47_fire" → اسپرایت واقعی اسلحه‌ی هر ستون
				var weapons := OS.get_environment("RIG_WEAPONS").split(",", false)
				if col < weapons.size():
					WeaponSkin.apply(gun, weapons[col])
				gun.visible = OS.get_environment("SHOW_GUN") != "0"
			var hs := OS.get_environment("HEAD_SCALE")
			if not hs.is_empty():
				var head := p.get_node("Sprite2D/Head") as Sprite2D
				head.scale = Vector2(hs.to_float(), hs.to_float())
			if OS.get_environment("RIG_TINT") == "1":
					(p.get_node("Sprite2D/LeftArm") as Node2D).modulate = Color(1.0, 0.25, 0.25, 1.0)
					(p.get_node("Sprite2D/RightArm") as Node2D).modulate = Color(0.3, 0.6, 1.0, 1.0)
					(p.get_node("Sprite2D/Body") as Node2D).modulate = Color(1, 1, 1, 0.25)
					(p.get_node("Sprite2D/Head") as Node2D).modulate = Color(1, 1, 1, 0.25)

			var dim := OS.get_environment("DIM_ARMS")
			if dim == "1":
				for n in ["LeftArm", "RightArm"]:
					var a := p.get_node("Sprite2D/" + n) as Node2D
					a.modulate = Color(1, 0.4, 0.4, 0.35)
				(p.get_node("Sprite2D/Head") as Node2D).modulate = Color(0.5, 0.6, 1.0, 0.3)
				var g2 := p.get_node_or_null("gun") as Node2D
				if g2 != null:
					g2.modulate = Color(1, 1, 1, 0.3)
			var ap := p.get_node("AnimationPlayer") as AnimationPlayer
			ap.play(ANIM_N[row])
			ap.seek(ANIM_T[row], true)
			ap.pause()

			var lbl := Label.new()
			lbl.text = "%s / %s" % [SKINS[col].replace("skin_", ""), ANIM_N[row]]
			lbl.position = Vector2(col * CELL + 6, row * CELL + 4)
			lbl.add_theme_font_size_override("font_size", 13)
			root.add_child(lbl)

	await process_frame
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out_path)
	print("saved ", out_path)
	quit()
