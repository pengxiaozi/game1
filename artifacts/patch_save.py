from pathlib import Path
p=Path(r'H:\games\scripts\main.gd')
s=p.read_text(encoding='utf-8')
s=s.replace('var synergies: SynergyManager\nvar rng', 'var synergies: SynergyManager\nvar save_manager: SaveManager\nvar rng')
s=s.replace('''	synergies = SynergyManager.new(data)
	font = ThemeDB.fallback_font''','''	synergies = SynergyManager.new(data)
	save_manager = SaveManager.new()
	var settings = save_manager.load_settings()
	state.speed = int(settings.get("speed", 1))
	font = ThemeDB.fallback_font''')
s=s.replace('''		elif event.keycode == KEY_1: state.speed = 1
		elif event.keycode == KEY_2: state.speed = 2''','''		elif event.keycode == KEY_1:
			state.speed = 1
			save_manager.save_settings(state.speed)
		elif event.keycode == KEY_2:
			state.speed = 2
			save_manager.save_settings(state.speed)''')
s=s.replace('''	if Rect2(1172,18,84,34).has_point(pos): state.speed = 1 if state.speed == 2 else 2; return''','''	if Rect2(1172,18,84,34).has_point(pos):
		state.speed = 1 if state.speed == 2 else 2
		save_manager.save_settings(state.speed)
		return''')
# Insert notification before _draw
s=s.replace('''func _draw() -> void:''','''func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and save_manager:
		save_manager.save_settings(state.speed)
		get_tree().quit()

func _draw() -> void:''')
p.write_text(s,encoding='utf-8')
