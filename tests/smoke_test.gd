extends SceneTree

const GameDataScript = preload("res://scripts/game_data.gd")
const GameStateScript = preload("res://scripts/game_state.gd")
const BoardManagerScript = preload("res://scripts/board_manager.gd")
const SynergyManagerScript = preload("res://scripts/synergy_manager.gd")

func _init() -> void:
	var data = GameDataScript.new()
	assert(data.heroes.size() == 12, "Expected 12 heroes")
	assert(data.synergies.size() == 8, "Expected 8 synergies")
	assert(data.enemy_by_id.has("boss"), "Boss data missing")
	assert(data.wave_info(20).enemies.has("boss"), "Wave 20 boss missing")

	var state = GameStateScript.new()
	var board = BoardManagerScript.new()
	for i in range(3):
		var d = data.by_id[["zhuge", "wukong", "change"][i]]
		state.heroes.append({"uid":i + 1,"id":d.id,"name":d.name,"cell":[Vector2i(2,1),Vector2i(5,3),Vector2i(8,4)][i],"star":1,"cooldown":0.0,"skill_cd":0.0,"hp":float(d.hp),"max_hp":float(d.hp)})
	var synergy = SynergyManagerScript.new(data)
	synergy.recalculate(state)
	assert(synergy.levels["trinity"] == 1, "Trinity synergy should activate")
	assert(is_equal_approx(synergy.value("all_damage"), 0.2), "Trinity damage bonus missing")
	assert(board.valid(Vector2i(2,1)), "Expected deployment cell to be valid")
	assert(board.road(Vector2i(3,2)), "Expected route cell to be road")
	assert(board.at_distance(0).is_equal_approx(board.route[0]), "Route start mismatch")

	var first = state.heroes[0]
	var first_stats = synergy.stats(first, state)
	assert(first_stats.damage > data.by_id[first.id].damage, "Synergy stats should increase damage")
	print("SMOKE TEST PASSED: data, board, synergies, stat modifiers")
	quit(0)
