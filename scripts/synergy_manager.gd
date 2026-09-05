class_name SynergyManager
extends RefCounted

var data
var counts: Dictionary = {}
var levels: Dictionary = {}
var effects: Dictionary = {}

func _init(game_data) -> void:
	data = game_data

func recalculate(state) -> void:
	counts.clear()
	levels.clear()
	effects.clear()
	var ids: Array = []
	for h in state.deployed():
		if not ids.has(h.id): ids.append(h.id)
	for s in data.synergies:
		var count = 0
		for id in ids:
			if s.has("members"):
				if s.members.has(id): count += 1
			elif data.by_id[id].tags.has(s.tag): count += 1
		counts[s.id] = count
		var level = 0
		for threshold in s.thresholds:
			if count >= int(threshold): level += 1
		levels[s.id] = level
		if level > 0:
			for key in s.effects[level - 1]: effects[key] = s.effects[level - 1][key]

func value(key: String) -> float:
	return float(effects.get(key, 0.0))

func stats(hero: Dictionary, state) -> Dictionary:
	var d = data.by_id[hero.id]
	var star_scale = [1.0, 2.25, 5.3][hero.star - 1]
	var damage = float(d.damage) * star_scale * (1.0 + state.training * 0.1 + value("all_damage"))
	if d.kind == "melee": damage *= 1.0 + value("melee")
	else: damage *= 1.0 + value("ranged")
	if d.id == "luban": damage *= 1.0 + value("machine")
	var attack_speed = 1.0 + value("all_speed")
	if d.tags.has("先锋"): attack_speed += value("speed")
	var reach = float(d.range) * (1.0 + value("range"))
	if BoardManager.HIGH_GROUND.has(hero.cell) and d.kind != "melee": reach *= 1.2
	var cooldown = float(d.cooldown)
	if d.tags.has("天庭"): cooldown *= 1.0 - value("cooldown")
	var skill_mult = 1.0
	if d.tags.has("蜀汉"): skill_mult += value("skill")
	var hp = float(d.hp) * [1.0, 1.7, 2.8][hero.star - 1]
	if d.tags.has("武将"): hp *= 1.0 + value("health")
	return {"damage":damage,"interval":float(d.interval) / attack_speed,"range":reach,"cooldown":cooldown,"skill_mult":skill_mult,"hp":hp,"control":1.0 + value("control")}
