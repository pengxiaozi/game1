class_name SaveManager
extends RefCounted

const PATH := "user://jiuzhou_settings.json"

func save_settings(speed: int, reduced_motion: bool = false) -> void:
	var file = FileAccess.open(PATH, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"speed":speed,"reduced_motion":reduced_motion}))

func load_settings() -> Dictionary:
	if not FileAccess.file_exists(PATH): return {"speed":1,"reduced_motion":false}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if parsed is Dictionary else {"speed":1,"reduced_motion":false}
