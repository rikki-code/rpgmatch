## A unit archetype (enemy, recruitable ally, the hero): level-1 stat
## ranges, how they grow per level, and its encounter cost / unlock level
## (see EncounterGenerator).
class_name UnitType
extends RefCounted

var display_name: String
var cost: int
var min_level: int
var hp_range: Vector2i
var initiative_range: Vector2i
var power_range: Vector2
## Share of the level-1 value gained per level (LevelCurve.percent).
var hp_growth: float
var power_growth: float

func _init(p_name: String, p_cost: int, p_min_level: int, p_hp: Vector2i, p_initiative: Vector2i, p_power: Vector2, p_hp_growth := 0.10, p_power_growth := 0.06) -> void:
	display_name = p_name
	cost = p_cost
	min_level = p_min_level
	hp_range = p_hp
	initiative_range = p_initiative
	power_range = p_power
	hp_growth = p_hp_growth
	power_growth = p_power_growth

func roll(level: int, side: Character.Side, controller: CharacterController, rng: RandomNumberGenerator) -> Character:
	var hp := roundi(LevelCurve.percent(rng.randi_range(hp_range.x, hp_range.y), hp_growth, level))
	var power := LevelCurve.percent(rng.randf_range(power_range.x, power_range.y), power_growth, level)
	var initiative := rng.randi_range(initiative_range.x, initiative_range.y)
	return Character.new(display_name, side, hp, initiative, power, controller)

## Balance: every unit is one board move per round, so N cheap units out-act
## one big one — stats can't just scale with cost. Costs are in half-steps
## (cheap unit = 2) and were set by equal-cost AI duels (docs/plan.md):
## tier 2 ~ 2 cheap, tier 3 ~ 2.5, tier 4 ~ slightly over 3. Each side has
## its own profiles; same-cost units unlock at the same level on both sides.

## Sturdier than the Devil, hits softer; worth ~2 cheap units.
static func hero() -> UnitType:
	return UnitType.new("Hero", 4, 1, Vector2i(154, 154), Vector2i(12, 12), Vector2(0.25, 0.25), 0.12, 0.08)

## Glassier than the hero, hits harder; one initiative lower so the hero opens.
static func devil() -> UnitType:
	return UnitType.new("Devil", 4, 1, Vector2i(126, 126), Vector2i(11, 11), Vector2(0.31, 0.31), 0.12, 0.08)

static func enemy_catalog() -> Array[UnitType]:
	return [
		UnitType.new("Slime", 2, 1, Vector2i(37, 43), Vector2i(4, 7), Vector2(0.13, 0.15)),
		UnitType.new("Bat", 2, 2, Vector2i(26, 30), Vector2i(13, 16), Vector2(0.186, 0.214)),
		UnitType.new("Goblin", 4, 3, Vector2i(52, 60), Vector2i(9, 11), Vector2(0.186, 0.214)),
		UnitType.new("Skeleton", 5, 5, Vector2i(90, 106), Vector2i(7, 9), Vector2(0.31, 0.36)),
		UnitType.new("Orc", 6, 7, Vector2i(201, 236), Vector2i(3, 6), Vector2(0.36, 0.42)),
	]

static func ally_catalog() -> Array[UnitType]:
	return [
		UnitType.new("Squire", 2, 1, Vector2i(46, 54), Vector2i(8, 10), Vector2(0.104, 0.12)),
		UnitType.new("Archer", 2, 2, Vector2i(29, 35), Vector2i(12, 15), Vector2(0.163, 0.187)),
		UnitType.new("Knight", 4, 3, Vector2i(74, 86), Vector2i(6, 8), Vector2(0.13, 0.15)),
		UnitType.new("Mage", 5, 5, Vector2i(73, 84), Vector2i(10, 12), Vector2(0.39, 0.45)),
		UnitType.new("Paladin", 6, 7, Vector2i(179, 211), Vector2i(5, 7), Vector2(0.41, 0.47)),
	]
