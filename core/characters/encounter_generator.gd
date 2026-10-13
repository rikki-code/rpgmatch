## One rule for both sides: `budget` (the mode's share of the level) and a
## side size from SLOT_UNLOCK_LEVELS. The side's human-controlled units
## (hero, PvP Devil) go in first and pay their cost like any unit; the rest
## are random unlocked catalog units leaning hard toward the expensive ones
## (weight = cost³) — few strong units over many weak.
class_name EncounterGenerator
extends RefCounted

## Level at which each slot on a side opens: 2nd at L3, 3rd at L10, all 5 at L20.
const SLOT_UNLOCK_LEVELS: Array[int] = [1, 3, 6, 10, 15]

static func build_side(humans: Array[UnitType], catalog: Array[UnitType], side: Character.Side, level: int, budget: int, rng: RandomNumberGenerator) -> Array[Character]:
	var units: Array[Character] = []
	for type in humans:
		units.append(type.roll(level, side, HumanController.new(), rng))
		budget -= type.cost
	var slots := SLOT_UNLOCK_LEVELS.filter(func(at: int) -> bool: return at <= level).size() - units.size()
	units.append_array(_generate(catalog, side, slots, budget, level, rng))
	return units

static func _generate(catalog: Array[UnitType], side: Character.Side, slots: int, budget: int, level: int, rng: RandomNumberGenerator) -> Array[Character]:
	var unlocked := catalog.filter(func(t: UnitType) -> bool: return t.min_level <= level)
	if unlocked.is_empty():
		return []
	var cheapest: int = unlocked.map(func(t: UnitType) -> int: return t.cost).min()
	slots = min(slots, floori(budget / float(cheapest)))
	var picked: Array[UnitType] = []
	for slot in range(slots):
		var reserve := (slots - slot - 1) * cheapest
		var affordable := unlocked.filter(func(t: UnitType) -> bool: return t.cost <= budget - reserve)
		var choice := _weighted_toward_expensive(affordable, rng)
		picked.append(choice)
		budget -= choice.cost

	var units: Array[Character] = []
	var numbered := {}  # UnitType -> copies named so far
	for type in picked:
		var unit := type.roll(level, side, AiController.new(AiController.skill_for_level(level)), rng)
		if picked.count(type) > 1:
			numbered[type] = numbered.get(type, 0) + 1
			unit.display_name += " %d" % numbered[type]
		units.append(unit)
	return units

static func _weighted_toward_expensive(types: Array, rng: RandomNumberGenerator) -> UnitType:
	var total := 0
	for type: UnitType in types:
		total += type.cost ** 3
	var roll := rng.randi_range(1, total)
	for type: UnitType in types:
		roll -= type.cost ** 3
		if roll <= 0:
			return type
	return types.back()
