class_name GameData
extends RefCounted

var heroes: Array = []
var synergies: Array = []
var enemies: Array = []
var by_id: Dictionary = {}
var enemy_by_id: Dictionary = {}

func _init() -> void:
	heroes = _read("res://data/heroes.json")
	synergies = _read("res://data/synergies.json")
	enemies = _read("res://data/enemies.json")
	for hero in heroes:
		by_id[hero.id] = hero
	for enemy in enemies:
		enemy_by_id[enemy.id] = enemy

func _read(path: String) -> Array:
	var content = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(content is Array, "Invalid game data: " + path)
	return content

func wave_info(number: int) -> Dictionary:
	var pool = ["grunt"]
	if number >= 4: pool.append("runner")
	if number >= 6: pool.append("armor")
	if number >= 11: pool.append("flyer")
	if number >= 13: pool.append("captain")
	var count = 10 + number * 2
	var composition: Array = []
	for i in range(count):
		composition.append(pool[(i + number) % pool.size()])
	if number == 20: composition.insert(8, "boss")
	return {"number":number,"enemies":composition,"interval":maxf(0.85, 1.45 - number * 0.025),"reward":12 + number * 2,"merit":2 + number / 5,"threat":"终局 · 饕餮降临" if number == 20 else ("精锐混编" if number >= 13 else ("空袭将至" if number >= 11 else ("铁甲压境" if number >= 6 else "山道初战")))}
