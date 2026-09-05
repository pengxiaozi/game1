from pathlib import Path
p=Path(r'H:\games\scripts\main.gd')
s=p.read_text(encoding='utf-8')
s=s.replace('''	for enemy in state.enemies:
		if enemy.pos.distance_to(hero.pos) <= stats.range: targets.append(enemy)''','''	var hero_pos = board.center(hero.cell)
	for enemy in state.enemies:
		if enemy.pos.distance_to(hero_pos) <= stats.range: targets.append(enemy)''')
p.write_text(s,encoding='utf-8')
