from pathlib import Path
p=Path(r'H:\games\scripts\main.gd')
s=p.read_text(encoding='utf-8')
s=s.replace('''			var skill_damage = stats.damage * 2.1 * stats.skill_mult
			if effect in ["cleave","blast","storm","stun","break","frost","charm","barrage"]:
				for other in state.enemies:
					if other.pos.distance_to(hero.pos) <= 105:''','''			var skill_damage = stats.damage * 2.1 * stats.skill_mult
			var hero_pos = board.center(hero.cell)
			if effect in ["cleave","blast","storm","stun","break","frost","charm","barrage"]:
				for other in state.enemies:
					if other.pos.distance_to(hero_pos) <= 105:''')
p.write_text(s,encoding='utf-8')
