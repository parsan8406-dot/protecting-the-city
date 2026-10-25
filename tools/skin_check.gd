extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var G = root.get_node_or_null("/root/Global")
	var N = root.get_node_or_null("/root/Network")
	print(">>> Global=", G, "  Network=", N)
	if G == null or N == null:
		quit(); return

	for i in range(300):
		await process_frame
		if str(G.player_id) != "":
			break
	print(">>> my_username       = ", G.my_username)
	print(">>> current_character = ", G.current_character)
	print(">>> current_weapon    = ", G.current_weapon)

	for i in range(600):
		await process_frame
		if N.current_players.has(G.my_username):
			break
	print(">>> is_connected      = ", N.is_connected)
	print(">>> server says       = ", N.current_players.get(G.my_username, {}))

	print(">>> loading World.tscn ...")
	change_scene_to_file("res://secense/World.tscn")
	for i in range(500):
		await process_frame
	var w = current_scene
	if w == null:
		print("!!! World failed to load"); quit(); return
	print(">>> scene = ", w.name)
	print(">>> current_character (after world) = ", G.current_character)
	var sprite = w.get_node_or_null("Player/Sprite2D")
	if sprite == null:
		print("!!! Player/Sprite2D missing"); quit(); return
	for n in ["Body", "Head", "LeftArm", "RightArm"]:
		var node = sprite.get_node_or_null(n)
		print("    ", n, " = ", (node.texture.resource_path if node and node.texture else "<null>"))
	quit()
