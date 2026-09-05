extends SceneTree
func _init() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.in_menu = false
	scene._start_wave()
	for i in range(500):
		scene._process(0.1)
	print("BATTLE SIM PASSED phase=", scene.state.phase, "wave=", scene.state.wave, "enemies=", scene.state.enemies.size())
	quit(0)
