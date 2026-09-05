class_name BoardManager
extends RefCounted

const ORIGIN = Vector2(250, 132)
const CELL = 46.0
const COLS = 16
const ROWS = 8
const HIGH_GROUND = [Vector2i(5, 1), Vector2i(12, 3)]
const WAYPOINTS = [Vector2i(-1,6), Vector2i(3,6), Vector2i(3,2), Vector2i(7,2), Vector2i(7,5), Vector2i(11,5), Vector2i(11,1), Vector2i(16,1)]
var route: PackedVector2Array = []
var length: float = 0.0

func _init() -> void:
	for cell in WAYPOINTS:
		route.append(center(cell))
	for i in range(1, route.size()):
		length += route[i - 1].distance_to(route[i])

func center(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell) * CELL + Vector2.ONE * CELL / 2.0

func cell_at(pos: Vector2) -> Vector2i:
	var q = (pos - ORIGIN) / CELL
	return Vector2i(floori(q.x), floori(q.y))

func road(cell: Vector2i) -> bool:
	for i in range(1, WAYPOINTS.size()):
		var a = WAYPOINTS[i - 1]
		var b = WAYPOINTS[i]
		if a.x == b.x and cell.x == a.x and cell.y >= mini(a.y,b.y) and cell.y <= maxi(a.y,b.y): return true
		if a.y == b.y and cell.y == a.y and cell.x >= mini(a.x,b.x) and cell.x <= maxi(a.x,b.x): return true
	return false

func valid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < COLS and cell.y >= 0 and cell.y < ROWS and not road(cell)

func at_distance(distance: float) -> Vector2:
	var remaining = maxf(0, distance)
	for i in range(1, route.size()):
		var segment = route[i - 1].distance_to(route[i])
		if remaining <= segment:
			return route[i - 1].lerp(route[i], remaining / segment)
		remaining -= segment
	return route[-1]

func occupant(state, cell: Vector2i) -> Dictionary:
	for h in state.heroes:
		if h.cell == cell: return h
	return {}

func deploy(state, uid: int, cell: Vector2i) -> bool:
	var h = state.hero(uid)
	if h.is_empty() or not valid(cell):
		state.notify("此处无法布阵，请选择道路两侧的阵位。")
		return false
	var other = occupant(state, cell)
	if h.cell.x < 0 and other.is_empty() and state.deployed().size() >= state.capacity:
		state.notify("军令已满：升级统御，或替换场上的英灵。")
		return false
	var old = h.cell
	h.cell = cell
	if not other.is_empty() and other.uid != uid: other.cell = old
	state.notify("英灵已就位 · 阵容羁绊已更新", "deploy")
	return true

func withdraw(state, uid: int) -> bool:
	var h = state.hero(uid)
	if h.is_empty() or h.cell.x < 0: return false
	if state.bench().size() >= 8:
		state.notify("候补席已满，请先出售或合成英灵。")
		return false
	h.cell = Vector2i(-1,-1)
	state.notify("英灵已撤回候补席。")
	return true
