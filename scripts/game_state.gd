class_name GameState
extends RefCounted

var gold: int = 24
var merit: int = 0
var capacity: int = 4
var training: int = 0
var wave: int = 0
var lives: int = 30
var phase: String = "prep"
var paused: bool = false
var speed: int = 1
var elapsed: float = 0.0
var kills: int = 0
var damage: float = 0.0
var heroes: Array = []
var enemies: Array = []
var shop: Array = []
var shop_locked: bool = false
var next_uid: int = 1
var message: String = "点击候补英灵，再点击发光阵位部署。相同英灵三合一自动升星。"
var effects: Array = []
var event_serial: int = 0
var last_event: String = ""

func deployed() -> Array:
	return heroes.filter(func(h): return h.cell.x >= 0)

func bench() -> Array:
	return heroes.filter(func(h): return h.cell.x < 0)

func hero(uid: int) -> Dictionary:
	for h in heroes:
		if h.uid == uid: return h
	return {}

func notify(text: String, event: String = "click") -> void:
	message = text
	last_event = event
	event_serial += 1
