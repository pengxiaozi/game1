from pathlib import Path
p=Path(r'H:\games\scripts\main.gd')
s=p.read_text(encoding='utf-8')
s=s.replace('var selected_uid := -1\nvar selected_shop := -1','var selected_uid := -1\nvar selected_shop := -1\nvar in_menu := true')
s=s.replace('''func _process(delta: float) -> void:
	if not state.paused:''','''func _process(delta: float) -> void:
	if in_menu:
		queue_redraw()
		return
	if not state.paused:''')
s=s.replace('''func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:''','''func _input(event: InputEvent) -> void:
	if in_menu:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_SPACE]:
			in_menu = false
			state.notify("点击英灵头像调整阵列，准备好后按 Space 开战。", "deploy")
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and Rect2(510,470,260,58).has_point(event.position):
			in_menu = false
			state.notify("点击英灵头像调整阵列，准备好后按 Space 开战。", "deploy")
			return
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:''')
s=s.replace('''func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	_draw_atmosphere()''','''func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	_draw_atmosphere()
	if in_menu:
		_draw_menu()
		return''')
insert='''
func _draw_menu() -> void:
	var center = Vector2(640, 310)
	draw_circle(center, 185, Color("102f34", 0.65))
	draw_arc(center, 185, 0, TAU, 64, Color(GOLD, 0.24), 2)
	draw_arc(center, 154, 0, TAU, 64, Color(RED, 0.2), 1)
	_draw_text(Vector2(448, 236), "九州英灵录", 52, INK)
	_draw_text(Vector2(502, 282), "山河有灵 · 守关者志", 17, GOLD)
	_draw_text(Vector2(446, 347), "招募英灵，结成羁绊，守住云门关。", 15, MUTED)
	_draw_text(Vector2(473, 382), "一张山道 · 十二英灵 · 二十波妖潮", 13, MUTED)
	_draw_button(Rect2(510,470,260,58), "入阵守关", true)
	_draw_text(Vector2(540, 570), "Enter / Space  开始", 12, MUTED)
	_draw_text(Vector2(501, 620), "原创单机试玩版 · Godot 4.7.2", 11, Color(MUTED,0.65))
'''
s=s.replace('''func _draw_header() -> void:''',insert+'\nfunc _draw_header() -> void:')
p.write_text(s,encoding='utf-8')
