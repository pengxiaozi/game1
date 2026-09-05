extends Control

var data: GameData
var state: GameState
var board: BoardManager
var synergies: SynergyManager
var save_manager: SaveManager
var rng := RandomNumberGenerator.new()
var selected_uid := -1
var selected_shop := -1
var in_menu := true
var hover_cell := Vector2i(-99, -99)
var spawn_timer := 0.0
var wave_queue: Array = []
var wave_spawned := 0
var wave_total := 0
var wave_clear_wait := 0.0
var toast_time := 0.0
var particle_time := 0.0
var font: Font

const BG = Color("091b21")
const PANEL = Color("102b32")
const PANEL_2 = Color("153a40")
const LINE = Color("3b6667")
const INK = Color("f1e6cc")
const MUTED = Color("9bb4aa")
const JADE = Color("65c4ae")
const RED = Color("bd5748")
const GOLD = Color("d5b579")
const ROAD = Color("233f3d")
const ROAD_EDGE = Color("56756a")
const ORIGIN = Vector2(250,132)
const CELL = 46.0

func _ready() -> void:
	data = GameData.new()
	state = GameState.new()
	board = BoardManager.new()
	synergies = SynergyManager.new(data)
	save_manager = SaveManager.new()
	var settings = save_manager.load_settings()
	state.speed = int(settings.get("speed", 1))
	font = ThemeDB.fallback_font
	rng.randomize()
	var opening_cells = [Vector2i(2,4), Vector2i(4,1), Vector2i(8,3), Vector2i(13,2)]
	for i in range(4):
		_add_hero(data.heroes[i], opening_cells[i])
	_refresh_shop()
	synergies.recalculate(state)
	queue_redraw()

func _process(delta: float) -> void:
	if in_menu:
		queue_redraw()
		return
	if not state.paused:
		var dt = delta * state.speed
		state.elapsed += dt
		particle_time += dt
		_tick_effects(dt)
		if state.phase == "battle": _battle_tick(dt)
		if toast_time > 0: toast_time -= dt
	queue_redraw()

func _battle_tick(dt: float) -> void:
	if wave_queue.size() > 0:
		spawn_timer -= dt
		if spawn_timer <= 0:
			_spawn_enemy(wave_queue.pop_front())
			spawn_timer = data.wave_info(state.wave).interval if state.wave > 0 else 1.0
	else:
		if state.enemies.is_empty():
			wave_clear_wait += dt
			if wave_clear_wait >= 1.2:
				_end_wave()
	for enemy in state.enemies.duplicate():
		_enemy_tick(enemy, dt)
	for hero in state.deployed():
		_hero_tick(hero, dt)

func _hero_tick(hero: Dictionary, dt: float) -> void:
	var stats = synergies.stats(hero, state)
	hero.cooldown -= dt
	hero.skill_cd -= dt
	if hero.cooldown <= 0:
		var target = _nearest_target(hero)
		if not target.is_empty():
			var applied_damage = stats.damage * (1.0 - target.armor)
			target.hp -= applied_damage
			state.damage += applied_damage
			hero.cooldown = stats.interval
			_add_burst(target.pos, Color.from_string(data.by_id[hero.id].color, GOLD), 0.22)
	if hero.skill_cd <= 0:
		var target = _nearest_target(hero)
		if not target.is_empty():
			var effect = data.by_id[hero.id].effect
			var skill_damage = stats.damage * 2.1 * stats.skill_mult
			var hero_pos = board.center(hero.cell)
			if effect in ["cleave","blast","storm","stun","break","frost","charm","barrage"]:
				for other in state.enemies:
					if other.pos.distance_to(hero_pos) <= 105:
						var applied_skill = skill_damage * (1.0 - other.armor)
						other.hp -= applied_skill
						state.damage += applied_skill
						if effect in ["stun","charm"]: other.stun = maxf(other.stun, 1.0 * stats.control)
			if effect == "heal":
				for ally in state.deployed(): ally.hp = min(ally.max_hp, ally.hp + 18.0)
			if effect == "snipe":
				var farthest = _nearest_target(hero, true)
				if not farthest.is_empty():
					var snipe_damage = stats.damage * 4.0 * (1.0 - farthest.armor)
					farthest.hp -= snipe_damage
					state.damage += snipe_damage
			hero.skill_cd = stats.cooldown
			state.notify(hero.name + " · " + data.by_id[hero.id].skill, "skill")
	_cleanup_enemies()

func _enemy_tick(enemy: Dictionary, dt: float) -> void:
	if enemy.stun > 0:
		enemy.stun -= dt
		return
	enemy.dist += float(enemy.speed) * dt
	enemy.pos = board.at_distance(enemy.dist)
	if enemy.dist >= board.length:
		state.lives -= enemy.leak
		state.enemies.erase(enemy)
		state.notify("敌人突破山道 · 关隘受损", "danger")
		if state.lives <= 0: _finish(false)

func _nearest_target(hero: Dictionary, farthest := false) -> Dictionary:
	var stats = synergies.stats(hero, state)
	var targets: Array = []
	var hero_pos = board.center(hero.cell)
	for enemy in state.enemies:
		if enemy.pos.distance_to(hero_pos) <= stats.range: targets.append(enemy)
	if targets.is_empty(): return {}
	targets.sort_custom(func(a,b): return a.dist < b.dist)
	return targets[-1] if farthest else targets[0]

func _cleanup_enemies() -> void:
	for enemy in state.enemies.duplicate():
		if enemy.hp <= 0:
			state.gold += int(enemy.bounty)
			state.kills += 1
			state.enemies.erase(enemy)
			_add_burst(enemy.pos, Color("e8c276"), 0.5)

func _spawn_enemy(id: String) -> void:
	var d = data.enemy_by_id[id]
	state.enemies.append({"id":id,"name":d.name,"hp":float(d.hp) * (1.0 + state.wave * 0.045),"max_hp":float(d.hp) * (1.0 + state.wave * 0.045),"speed":d.speed,"armor":d.armor,"bounty":d.bounty,"leak":d.leak,"pos":board.at_distance(0),"dist":0.0,"stun":0.0})

func _start_wave() -> void:
	if state.phase == "battle": return
	if state.wave >= 20:
		_finish(true)
		return
	state.wave += 1
	var info = data.wave_info(state.wave)
	wave_queue = info.enemies.duplicate()
	wave_total = wave_queue.size()
	wave_spawned = 0
	spawn_timer = 0.1
	wave_clear_wait = 0
	state.phase = "battle"
	state.notify("第 %02d 波 · %s" % [state.wave, info.threat], "wave")

func _end_wave() -> void:
	state.phase = "prep"
	var info = data.wave_info(state.wave)
	var income = int(info.reward) + int(synergies.value("income"))
	state.gold += income
	state.merit += int(info.merit)
	state.capacity = min(12, state.capacity + (1 if state.wave % 4 == 0 else 0))
	state.notify("第 %02d 波守住 · 灵石 +%d · 战功 +%d" % [state.wave, income, int(info.merit)], "reward")
	_refresh_shop()
	if state.wave >= 20: _finish(true)

func _finish(win: bool) -> void:
	state.phase = "win" if win else "lose"
	state.paused = true
	state.notify("关隘守护成功 · 九州英灵永镇山河" if win else "关隘失守 · 重整阵列再战", "finish")

func _add_hero(d: Dictionary, cell: Vector2i) -> Dictionary:
	var h = {"uid":state.next_uid,"id":d.id,"name":d.name,"title":d.title,"cell":cell,"star":1,"cooldown":0.0,"skill_cd":float(d.cooldown) * 0.45,"hp":float(d.hp),"max_hp":float(d.hp)}
	state.next_uid += 1
	state.heroes.append(h)
	return h

func _refresh_shop() -> void:
	state.shop.clear()
	for i in range(5): state.shop.append(data.heroes[rng.randi_range(0, data.heroes.size() - 1)].id)
	state.shop_locked = false

func _buy_shop(index: int) -> void:
	if index < 0 or index >= state.shop.size(): return
	if state.shop[index] == "bought":
		state.notify("这张英灵签已收入阵中。")
		return
	if state.gold < 6:
		state.notify("灵石不足 · 波次奖励或出售英灵可补充资源。")
		return
	if state.bench().size() >= 8:
		state.notify("候补席已满 · 先合成或出售英灵。")
		return
	var d = data.by_id[state.shop[index]]
	state.gold -= 6
	var recruited = _add_hero(d, Vector2i(-1,-1))
	selected_uid = recruited.uid
	selected_shop = -1
	state.shop.remove_at(index)
	state.shop.insert(index, "bought")
	state.notify("招募 " + d.name + " · 点击头像后部署到阵位", "buy")
	_try_merge(d.id)

func _try_merge(id: String) -> void:
	for star in [1,2]:
		var same = state.heroes.filter(func(h): return h.id == id and h.star == star)
		if same.size() >= 3:
			var keep = same[0]
			keep.star += 1
			keep.max_hp = data.by_id[id].hp * [1.0,1.7,2.8][keep.star - 1]
			keep.hp = keep.max_hp
			for i in range(1,3): state.heroes.erase(same[i])
			state.notify("合成成功 · " + data.by_id[id].name + " 晋升 " + ("★★" if keep.star == 2 else "★★★"), "merge")
			synergies.recalculate(state)
			return

func _select_hero(uid: int) -> void:
	selected_uid = uid
	selected_shop = -1

func _select_shop(index: int) -> void:
	selected_shop = index
	selected_uid = -1

func _deploy_selected(cell: Vector2i) -> void:
	if selected_uid < 0: return
	if board.deploy(state, selected_uid, cell):
		synergies.recalculate(state)

func _input(event: InputEvent) -> void:
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
		if event.keycode == KEY_SPACE:
			if state.phase == "prep": _start_wave()
			elif state.phase == "battle": state.paused = not state.paused
			queue_redraw()
		elif event.keycode == KEY_1:
			state.speed = 1
			save_manager.save_settings(state.speed)
		elif event.keycode == KEY_2:
			state.speed = 2
			save_manager.save_settings(state.speed)
		elif event.keycode == KEY_ESCAPE: state.paused = not state.paused
	if event is InputEventMouseMotion:
		hover_cell = board.cell_at(event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_click(event.position)

func _handle_click(pos: Vector2) -> void:
	if state.phase in ["win","lose"]:
		if Rect2(535,430,210,52).has_point(pos): get_tree().reload_current_scene()
		return
	if Rect2(1082,18,84,34).has_point(pos): state.paused = not state.paused; return
	if Rect2(1172,18,84,34).has_point(pos):
		state.speed = 1 if state.speed == 2 else 2
		save_manager.save_settings(state.speed)
		return
	if Rect2(1082,600,174,48).has_point(pos):
		if state.phase == "prep": _start_wave()
		return
	if Rect2(1008,630,58,68).has_point(pos):
		if state.gold >= 4:
			state.gold -= 4; _refresh_shop(); state.notify("候补英灵已重新洗牌。")
		else: state.notify("刷新需要 4 灵石。")
		return
	for i in range(5):
		if Rect2(246 + i*106, 630, 98, 68).has_point(pos): _buy_shop(i); return
	for h in state.heroes:
		if h.cell.x >= 0 and board.center(h.cell).distance_to(pos) < 23:
			_select_hero(h.uid); return
	if board.valid(hover_cell) and Rect2(246,120,736,380).has_point(pos): _deploy_selected(hover_cell)
	if selected_uid >= 0 and Rect2(1082,520,174,44).has_point(pos):
		if board.withdraw(state, selected_uid):
			synergies.recalculate(state)
			state.notify("英灵已撤回候补席 · 点击空阵位可重新部署。")

func _add_burst(pos: Vector2, color: Color, duration: float) -> void:
	state.effects.append({"pos":pos,"color":color,"time":duration,"max":duration})

func _tick_effects(dt: float) -> void:
	for fx in state.effects.duplicate():
		fx.time -= dt
		if fx.time <= 0: state.effects.erase(fx)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and save_manager:
		save_manager.save_settings(state.speed)
		get_tree().quit()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	_draw_atmosphere()
	if in_menu:
		_draw_menu()
		return
	_draw_header()
	_draw_left_panel()
	_draw_battlefield()
	_draw_right_panel()
	_draw_shop()
	_draw_toast()
	if state.phase in ["win","lose"]: _draw_finish()

func _draw_atmosphere() -> void:
	for i in range(7):
		var y = 105 + i*72
		var pts = PackedVector2Array([Vector2(0,y+50),Vector2(170,y-15),Vector2(340,y+25),Vector2(500,y-30),Vector2(720,y+30),Vector2(980,y-18),Vector2(1280,y+15),Vector2(1280,720),Vector2(0,720)])
		draw_colored_polygon(pts, Color(0.05 + i*0.006,0.13 + i*0.006,0.15 + i*0.006,0.5))
	for i in range(10):
		var p = Vector2(44 + i*139, 90 + sin(particle_time*0.15+i)*10)
		draw_circle(p, 1.5, Color(0.65,0.82,0.7,0.22))


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

func _draw_header() -> void:
	draw_rect(Rect2(0,0,1280,82), Color("0b2228"))
	draw_line(Vector2(0,81),Vector2(1280,81),Color("416b68"),1)
	_draw_text(Vector2(28,31),"九州英灵录",26,INK)
	_draw_text(Vector2(29,58),"山河有灵 · 守关者志",12,MUTED)
	_draw_text(Vector2(276,31),"第 %02d / 20 波" % state.wave,20,INK)
	_draw_text(Vector2(276,58),"下一波：" + (data.wave_info(state.wave + 1).threat if state.wave < 20 else "终局已至"),12,MUTED)
	_draw_stat(Vector2(548,18),"▣",str(state.lives),"关隘",RED)
	_draw_stat(Vector2(670,18),"✦",str(state.gold),"灵石",GOLD)
	_draw_stat(Vector2(792,18),"⚑",str(state.deployed().size()) + " / " + str(state.capacity),"军令",JADE)
	_draw_stat(Vector2(914,18),"◈",str(state.merit),"战功",Color("d69bca"))
	_draw_button(Rect2(1082,18,84,34),"暂停" if not state.paused else "继续",false)
	_draw_button(Rect2(1172,18,84,34),"◈ %dx" % state.speed,false)

func _draw_stat(pos: Vector2, icon: String, value: String, label: String, color: Color) -> void:
	draw_circle(pos + Vector2(12,17), 12, Color(color,0.12))
	_draw_text(pos+Vector2(5,23),icon,15,color)
	_draw_text(pos+Vector2(31,20),value,18,INK)
	_draw_text(pos+Vector2(31,37),label,10,MUTED)

func _draw_left_panel() -> void:
	_draw_panel(Rect2(18,99,214,500))
	_draw_text(Vector2(36,131),"阵 · 羁绊",18,INK)
	_draw_text(Vector2(36,151),"已上场英灵的共鸣",11,MUTED)
	var y = 181
	for s in data.synergies:
		var count = int(synergies.counts.get(s.id,0))
		var level = int(synergies.levels.get(s.id,0))
		var active = level > 0
		var col = GOLD if active else Color("52706d")
		draw_rect(Rect2(34,y-15,182,48),Color(col,0.08 if active else 0.025))
		draw_rect(Rect2(34,y-15,3,48),col)
		draw_circle(Vector2(53,y+8),15,Color(col,0.16))
		_draw_text(Vector2(43,y+13),s.mark,12,col)
		_draw_text(Vector2(76,y+2),s.name,13,INK if active else MUTED)
		_draw_text(Vector2(76,y+19),str(count)+" / "+str(s.thresholds[-1]),10,col)
		if active: _draw_text(Vector2(181,y+6),"Lv"+str(level),10,GOLD)
		y += 56
	_draw_text(Vector2(36,570),"羁绊会随阵容即时变化",10,MUTED)

func _draw_battlefield() -> void:
	_draw_text(Vector2(252,104),"玄武山道",14,Color("b8c9b4"))
	_draw_text(Vector2(358,104),"云门关 · 守住最后一道山口",11,MUTED)
	for x in range(board.COLS):
		for y in range(board.ROWS):
			var cell = Vector2i(x,y)
			var rect = Rect2(board.center(cell)-Vector2.ONE*21,Vector2.ONE*42)
			if board.road(cell):
				draw_rect(rect,ROAD)
				draw_line(rect.position+Vector2(0,21),rect.end-Vector2(0,21),Color(ROAD_EDGE,0.27),1)
			else:
				var valid = board.valid(cell)
				draw_rect(rect,Color("17393a",0.76) if valid else Color("0e292e",0.35))
				draw_rect(rect,Color(LINE,0.26) if valid else Color(LINE,0.08),false,1)
			if board.HIGH_GROUND.has(cell):
				draw_circle(board.center(cell),12,Color(GOLD,0.14)); _draw_text(board.center(cell)+Vector2(-7,5),"高台",10,GOLD)
	var route_pts = board.route
	for i in range(route_pts.size()-1): draw_line(route_pts[i],route_pts[i+1],Color("799d83",0.5),4)
	for i in range(route_pts.size()-1): draw_line(route_pts[i],route_pts[i+1],Color("b8c18e",0.14),13)
	_draw_text(board.route[0]+Vector2(-8,34),"来敌",11,RED)
	_draw_text(board.route[-1]+Vector2(-68,-18),"云门关",13,GOLD)
	draw_circle(board.route[-1],23,Color(RED,0.16)); draw_arc(board.route[-1],23,0,TAU,32,RED,2)
	if board.valid(hover_cell) and Rect2(246,120,736,380).has_point(get_local_mouse_position()):
		var hc = board.center(hover_cell)
		draw_rect(Rect2(hc-Vector2.ONE*21,Vector2.ONE*42),Color(JADE,0.25),true)
		if selected_uid >= 0: draw_arc(hc,25,0,TAU,24,JADE,2)
	for h in state.deployed(): _draw_hero(h)
	for enemy in state.enemies: _draw_enemy(enemy)
	for fx in state.effects:
		var ratio = fx.time / fx.max
		draw_circle(fx.pos, 28 + (1-ratio)*32, Color(fx.color,0.22*ratio))
		draw_arc(fx.pos, 18 + (1-ratio)*25,0,TAU,20,Color(fx.color,0.8*ratio),2)

func _draw_hero(h: Dictionary) -> void:
	var d = data.by_id[h.id]
	var p = board.center(h.cell)
	var col = Color.from_string(d.color,GOLD)
	var selected = h.uid == selected_uid
	if selected: draw_arc(p,25,0,TAU,32,GOLD,2)
	draw_circle(p,18,Color("071419",0.8)); draw_circle(p,14,Color(col,0.9))
	draw_circle(p+Vector2(0,-11),6,Color("f0d7b5"))
	_draw_weapon(p,d.weapon,col)
	_draw_text(p+Vector2(-20,34),h.name,11,INK)
	_draw_text(p+Vector2(-20,-26),"★".repeat(h.star),12,GOLD)
	var hp_ratio = clampf(h.hp / maxf(1,h.max_hp),0,1)
	draw_rect(Rect2(p+Vector2(-19,22),Vector2(38,4)),Color("351d24"))
	draw_rect(Rect2(p+Vector2(-19,22),Vector2(38*hp_ratio,4)),JADE)

func _draw_weapon(p: Vector2, weapon: String, col: Color) -> void:
	if weapon == "blade": draw_line(p+Vector2(8,8),p+Vector2(18,-12),col,3)
	elif weapon == "fan":
		for i in range(3): draw_line(p+Vector2(6,5),p+Vector2(17-i*4,-10+i*2),col,2)
	elif weapon == "spear": draw_line(p+Vector2(6,10),p+Vector2(19,-13),col,2); draw_colored_polygon(PackedVector2Array([p+Vector2(16,-10),p+Vector2(23,-15),p+Vector2(21,-6)]),col)
	elif weapon == "staff": draw_line(p+Vector2(4,12),p+Vector2(5,-16),col,3); draw_circle(p+Vector2(6,-17),4,col)
	elif weapon == "bow": draw_arc(p+Vector2(7,0),13,-1.1,1.1,12,col,2); draw_line(p+Vector2(7,-11),p+Vector2(7,11),col,1)
	else: draw_circle(p+Vector2(11,-7),5,col)

func _draw_enemy(e: Dictionary) -> void:
	var d = data.enemy_by_id[e.id]
	var p = e.pos
	var col = Color.from_string(d.color,RED)
	var r = 14.0 if e.id != "boss" else 25.0
	draw_circle(p, r+4, Color("071419",0.7)); draw_circle(p,r,col)
	if e.id == "boss": draw_arc(p,r+7,0,TAU,28,GOLD,3)
	_draw_text(p+Vector2(-18,r+18),e.name,10,INK if e.id != "boss" else GOLD)
	var hp_ratio = clampf(e.hp/e.max_hp,0,1)
	draw_rect(Rect2(p-Vector2(r, r+10),Vector2(r*2,4)),Color("351d24"))
	draw_rect(Rect2(p-Vector2(r, r+10),Vector2(r*2*hp_ratio,4)),RED)

func _draw_right_panel() -> void:
	_draw_panel(Rect2(1000,99,262,500))
	_draw_text(Vector2(1020,132),"英灵册",18,INK)
	if selected_uid >= 0:
		var h = state.hero(selected_uid)
		if not h.is_empty():
			var d = data.by_id[h.id]; var col=Color.from_string(d.color,GOLD)
			draw_circle(Vector2(1051,185),30,Color(col,0.85)); draw_circle(Vector2(1051,169),10,Color("f0d7b5"))
			_draw_text(Vector2(1095,178),h.name+"  "+"★".repeat(h.star),20,INK)
			_draw_text(Vector2(1095,198),d.title,11,col)
			_draw_text(Vector2(1020,250),"标签",11,MUTED); _draw_text(Vector2(1020,272),"  ".join(PackedStringArray(d.tags)),14,GOLD)
			_draw_text(Vector2(1020,310),"技能 · "+d.skill,14,INK)
			_draw_text(Vector2(1020,334),d.description,11,MUTED)
			var st=synergies.stats(h,state)
			_draw_text(Vector2(1020,390),"攻击  %d     射程  %d" % [int(st.damage),int(st.range)],12,INK)
			_draw_text(Vector2(1020,412),"攻速  %.1fs    技能  %.1fs" % [st.interval,st.cooldown],12,INK)
			_draw_button(Rect2(1020,520,174,44),"撤回候补",false)
			_draw_text(Vector2(1020,583),"点击空阵位可换位部署",10,MUTED)
	else:
		_draw_text(Vector2(1020,178),"选择一位英灵查看详情",14,MUTED)
		_draw_text(Vector2(1020,210),"招募后点击头像，再点击发光阵位",11,MUTED)
		_draw_text(Vector2(1020,250),"战斗提示",13,GOLD)
		_draw_text(Vector2(1020,276),"Space  开始 / 暂停",12,INK)
		_draw_text(Vector2(1020,298),"1 / 2    切换速度",12,INK)
		_draw_text(Vector2(1020,320),"Esc      暂停战局",12,INK)
		_draw_text(Vector2(1020,370),"守关记录",13,GOLD)
		_draw_text(Vector2(1020,396),"斩敌  %03d" % state.kills,12,INK)
		_draw_text(Vector2(1020,418),"伤害  %06d" % int(state.damage),12,INK)

func _draw_shop() -> void:
	draw_rect(Rect2(232,604,760,96),Color("0b2429"))
	draw_line(Vector2(232,604),Vector2(992,604),Color("486c68"),1)
	_draw_text(Vector2(248,621),"候补英灵",12,MUTED)
	for i in range(5):
		var rect=Rect2(246+i*106,630,98,68)
		draw_rect(rect,Color(PANEL_2,0.85)); draw_rect(rect,Color(LINE,0.7),false,1)
		if i < state.shop.size() and state.shop[i] != "bought":
			var d=data.by_id[state.shop[i]]; var col=Color.from_string(d.color,GOLD)
			draw_circle(rect.position+Vector2(24,34),15,Color(col,0.9)); draw_circle(rect.position+Vector2(24,26),5,Color("f0d7b5"))
			_draw_text(rect.position+Vector2(45,25),d.name,12,INK); _draw_text(rect.position+Vector2(45,43),"6 灵石",10,GOLD)
		else: _draw_text(rect.position+Vector2(28,40),"已招募",11,MUTED)
	_draw_button(Rect2(1008,630,58,68),"刷新\n4✦",false)
	var wave_label = "开战 · 第 %02d 波" % (state.wave + 1) if state.phase == "prep" else ("战斗中 · %02d" % state.wave)
	_draw_button(Rect2(1082,600,174,48),wave_label,state.phase == "prep")

func _draw_toast() -> void:
	if toast_time <= 0 and state.last_event == "": return
	var col = GOLD if state.last_event in ["wave","reward","merge","skill","buy","deploy"] else RED
	draw_rect(Rect2(350,92,570,32),Color("09171b",0.93)); draw_rect(Rect2(350,92,4,32),col)
	_draw_text(Vector2(370,114),state.message,12,INK)

func _draw_finish() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("041014",0.7))
	draw_rect(Rect2(400,170,480,350),Color("102b32")); draw_rect(Rect2(400,170,480,350),GOLD,false,2)
	var win=state.phase=="win"
	_draw_text(Vector2(535,260),"山河安" if win else "关隘失守",38,GOLD if win else RED)
	_draw_text(Vector2(493,310),"九州英灵永镇山河" if win else "再集英灵，重整阵列",15,INK)
	_draw_text(Vector2(520,360),"守至第 %02d 波 · 斩敌 %03d" % [state.wave,state.kills],13,MUTED)
	_draw_button(Rect2(535,430,210,52),"再战一局",true)

func _draw_panel(rect: Rect2) -> void:
	draw_rect(rect,Color(PANEL,0.9)); draw_rect(rect,Color(LINE,0.45),false,1)

func _draw_button(rect: Rect2, label: String, accent: bool) -> void:
	var col=RED if accent else PANEL_2
	draw_rect(rect,Color(col,0.95)); draw_rect(rect,Color(GOLD if accent else LINE,0.9),false,1)
	var lines=label.split("\n")
	for i in range(lines.size()): _draw_text(rect.position+Vector2((rect.size.x - font.get_string_size(lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,13).x)/2, 22+i*16),lines[i],13,INK)

func _draw_text(pos: Vector2, text: String, size_px: int, color: Color) -> void:
	draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)
