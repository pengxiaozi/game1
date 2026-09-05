extends SceneTree
func _init() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	print("MAIN SCENE INSTANTIATED")
	quit(0)
