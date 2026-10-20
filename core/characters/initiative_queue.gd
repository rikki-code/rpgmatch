## Flat turn order across both sides, sorted by initiative descending.
## Rebuilt each round so it always reflects the current living roster.
class_name InitiativeQueue
extends RefCounted

var _order: Array[Character] = []
var _index: int = 0

func start_round(characters: Array[Character]) -> void:
	_order = characters.duplicate()
	_order.sort_custom(func(a: Character, b: Character) -> bool: return a.initiative > b.initiative)
	_index = 0

## Order as indices into the roster (allies then enemies), plus how far the round has gone.
func to_dict(roster: Array[Character]) -> Dictionary:
	var order := []
	for character in _order:
		order.append(roster.find(character))
	return {"order": order, "index": _index}

func restore(data: Dictionary, roster: Array[Character]) -> void:
	_order.clear()
	for index in data["order"]:
		_order.append(roster[int(index)])
	_index = int(data["index"])

func next_actor() -> Character:
	while _index < _order.size():
		var actor := _order[_index]
		_index += 1
		if actor.is_alive():
			return actor
	return null
