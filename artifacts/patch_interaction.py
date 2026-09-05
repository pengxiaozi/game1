from pathlib import Path
p=Path(r'H:\games\scripts\main.gd')
s=p.read_text(encoding='utf-8')
s=s.replace('''func _buy_shop(index: int) -> void:
	if index < 0 or index >= state.shop.size(): return
	if state.gold < 6:''','''func _buy_shop(index: int) -> void:
	if index < 0 or index >= state.shop.size(): return
	if state.shop[index] == "bought":
		state.notify("这张英灵签已收入阵中。")
		return
	if state.gold < 6:''')
s=s.replace('''		if board.withdraw(state, selected_uid): synergies.recalculate(state); selected_uid = -1''','''		if board.withdraw(state, selected_uid):
			synergies.recalculate(state)
			state.notify("英灵已撤回候补席 · 点击空阵位可重新部署。")''')
p.write_text(s,encoding='utf-8')
