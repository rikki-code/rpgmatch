## Builds a level's enemy group: budget = level, slots grow 1 -> BattleContext.MAX_PER_SIDE (one more every 2 levels), each slot
## a random unlocked EnemyType (weight = cost², so the budget gets spent) that still leaves
## room for the remaining slots. L1 one slime, L2 two weak, L3 slime+goblin...
class_name EncounterGenerator
extends RefCounted

static func generate(level: int, rng: RandomNumberGenerator) -> Array[Character]:
	var unlocked := EnemyType.catalog().filter(func(t: EnemyType) -> bool: return t.min_level <= level)
	var cheapest: int = unlocked.map(func(t: EnemyType) -> int: return t.cost).min()
	var slots := mini(1 + floori(level / 2.0), BattleContext.MAX_PER_SIDE)
	var budget := level
	var picked: Array[EnemyType] = []
	for slot in range(slots):
		var reserve := (slots - slot - 1) * cheapest
		var affordable := unlocked.filter(func(t: EnemyType) -> bool: return t.cost <= budget - reserve)
		if affordable.is_empty():
			break
		var choice := _weighted_by_cost_sq(affordable, rng)
		picked.append(choice)
		budget -= choice.cost

	var enemies: Array[Character] = []
	for type in picked:
		var enemy := type.roll(level, rng)
		if picked.count(type) > 1:
			enemy.display_name += " %d" % (enemies.filter(func(e: Character) -> bool: return e.display_name.begins_with(type.display_name)).size() + 1)
		enemies.append(enemy)
	return enemies

static func _weighted_by_cost_sq(types: Array, rng: RandomNumberGenerator) -> EnemyType:
	var total := 0
	for type: EnemyType in types:
		total += type.cost * type.cost
	var roll := rng.randi_range(1, total)
	for type: EnemyType in types:
		roll -= type.cost * type.cost
		if roll <= 0:
			return type
	return types.back()
