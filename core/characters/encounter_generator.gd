## Builds a level's enemy group and recruited allies by the same rule:
## budget = level, a slot count that grows with level, each slot a random
## unlocked UnitType (weight = cost², so the budget gets spent) that still
## leaves room for the remaining slots. Allies pay ALLY_COST_FACTOR x cost,
## so they arrive later and weaker than enemies.
class_name EncounterGenerator
extends RefCounted

const ALLY_COST_FACTOR := 2
## The hero always takes one ally slot.
const MAX_RECRUITS := BattleContext.MAX_PER_SIDE - 1

## L1 one slime, L2 two weak, L3 goblin + a weak one ... L8+ five.
static func enemies(level: int, rng: RandomNumberGenerator) -> Array[Character]:
	var slots := mini(1 + floori(level / 2.0), BattleContext.MAX_PER_SIDE)
	return _generate(UnitType.enemy_catalog(), 1, Character.Side.ENEMY, slots, level, rng)

## First recruit at L3, one more every 3 levels.
static func allies(level: int, rng: RandomNumberGenerator) -> Array[Character]:
	var slots := mini(floori(level / 3.0), MAX_RECRUITS)
	return _generate(UnitType.ally_catalog(), ALLY_COST_FACTOR, Character.Side.ALLY, slots, level, rng)

static func _generate(catalog: Array[UnitType], cost_factor: int, side: Character.Side, slots: int, level: int, rng: RandomNumberGenerator) -> Array[Character]:
	var unlocked := catalog.filter(func(t: UnitType) -> bool: return t.min_level <= level)
	if unlocked.is_empty() or slots <= 0:
		return []
	var cheapest: int = unlocked.map(func(t: UnitType) -> int: return t.cost * cost_factor).min()
	var budget := level
	var picked: Array[UnitType] = []
	for slot in range(slots):
		var reserve := (slots - slot - 1) * cheapest
		var affordable := unlocked.filter(func(t: UnitType) -> bool: return t.cost * cost_factor <= budget - reserve)
		if affordable.is_empty():
			break
		var choice := _weighted_by_cost_sq(affordable, rng)
		picked.append(choice)
		budget -= choice.cost * cost_factor

	var units: Array[Character] = []
	var numbered := {}  # UnitType -> copies named so far
	for type in picked:
		var unit := type.roll(level, side, AiController.new(AiController.skill_for_level(level)), rng)
		if picked.count(type) > 1:
			numbered[type] = numbered.get(type, 0) + 1
			unit.display_name += " %d" % numbered[type]
		units.append(unit)
	return units

static func _weighted_by_cost_sq(types: Array, rng: RandomNumberGenerator) -> UnitType:
	var total := 0
	for type: UnitType in types:
		total += type.cost * type.cost
	var roll := rng.randi_range(1, total)
	for type: UnitType in types:
		roll -= type.cost * type.cost
		if roll <= 0:
			return type
	return types.back()
