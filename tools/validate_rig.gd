extends SceneTree

# اعتبارسنجی ریگ کاراکتر: هر دو صحنه لود می‌شوند و مش/وزن‌ها/انیمیشن‌ها چک می‌شوند.
# اجرا:  Godot.exe --headless --path . --script res://tools/validate_rig.gd

const SCENES := {
	"res://secense/player_s.tscn": "",
	"res://secense/World.tscn": "Player",
}

var errors := 0


func fail(msg: String) -> void:
	errors += 1
	print("  ERROR: ", msg)


func check_rig(root: Node, prefix: String) -> void:
	var player: Node = root if prefix == "" else root.get_node_or_null(prefix)
	if player == null:
		fail("player node '%s' not found" % prefix)
		return

	var skel := player.get_node_or_null("Body") as Skeleton2D
	if skel == null:
		fail("Skeleton2D 'Body' missing")
		return
	print("  bones: ", skel.get_bone_count())

	for part in ["Body", "LeftArm", "RightArm"]:
		var p := player.get_node_or_null("Sprite2D/" + part) as Polygon2D
		if p == null:
			fail("Polygon2D '%s' missing" % part)
			continue
		var n := p.polygon.size()
		if p.uv.size() != n:
			fail("%s: uv/polygon size mismatch (%d vs %d)" % [part, p.uv.size(), n])
		if p.internal_vertex_count >= n:
			fail("%s: bad internal_vertex_count" % part)
		var used := {}
		for tri in p.polygons:
			for idx in tri:
				if idx < 0 or idx >= n:
					fail("%s: triangle index %d out of range" % [part, idx])
				used[idx] = true
		var missing := 0
		for i in range(n):
			if not used.has(i):
				missing += 1
		if missing > 0:
			fail("%s: %d vertices belong to no triangle" % [part, missing])
		# skinning weights
		var total := PackedFloat32Array()
		total.resize(n)
		var bone_count := p.get_bone_count()
		for b in range(bone_count):
			var path := p.get_bone_path(b)
			if skel.get_node_or_null(path) == null:
				fail("%s: bone path '%s' does not resolve" % [part, path])
			var w := p.get_bone_weights(b)
			if w.size() != n:
				fail("%s: weight array %d has %d entries, expected %d" % [part, b, w.size(), n])
				continue
			for i in range(n):
				total[i] += w[i]
		var unweighted := 0
		for i in range(n):
			if absf(total[i] - 1.0) > 0.01:
				unweighted += 1
		if unweighted > 0:
			fail("%s: %d vertices whose weights do not sum to 1" % [part, unweighted])
		print("    %-9s verts=%d (internal %d) tris=%d bones=%d  OK" %
			[part, n, p.internal_vertex_count, p.polygons.size(), bone_count])

	var head := player.get_node_or_null("Sprite2D/Head") as Sprite2D
	if head == null:
		fail("Head sprite missing")

	var ap := player.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap == null:
		fail("AnimationPlayer missing")
		return
	for name in ["RESET", "idle", "walk", "shoot"]:
		if not ap.has_animation(name):
			fail("animation '%s' missing" % name)
			continue
		var a := ap.get_animation(name)
		for t in range(a.get_track_count()):
			var np := a.track_get_path(t)
			if player.get_node_or_null(NodePath(str(np).get_slice(":", 0))) == null:
				fail("animation '%s' track %d -> '%s' does not resolve" % [name, t, np])
	print("  animations: ", ap.get_animation_list())


# _initialize نه _init: در _init هنوز autoloadها (Global، Network، CombatFX) ساخته
# نشده‌اند و اسکریپت‌های بازی که به آن‌ها ارجاع دارند اصلاً کامپایل نمی‌شوند.
func _initialize() -> void:
	for path in SCENES:
		print("== ", path)
		var packed := ResourceLoader.load(path) as PackedScene
		if packed == null:
			fail("could not load scene")
			continue
		var inst := packed.instantiate()
		check_rig(inst, SCENES[path])
		inst.free()
	print("")
	print("errors: ", errors)
	quit(1 if errors > 0 else 0)
