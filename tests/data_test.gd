class_name DataIntegrityTest
extends SceneTree

func _init() -> void:
	var data = preload("res://scripts/game_data.gd").new()
	var ids = {}
	for hero in data.heroes:
		assert(not ids.has(hero.id), "Duplicate hero id")
		ids[hero.id] = true
		assert(hero.tags.size() >= 2, "Hero needs at least two tags")
	for synergy in data.synergies:
		assert(synergy.thresholds.size() == synergy.effects.size(), "Synergy effect tiers mismatch")
	for number in range(1,21):
		assert(data.wave_info(number).enemies.size() > 0, "Wave is empty")
	print("DATA TEST PASSED: heroes, synergies, waves")
	quit(0)
