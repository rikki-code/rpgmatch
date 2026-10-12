## An enemy archetype: level-1 stat ranges, how they grow per level, and its
## encounter cost / unlock level (see EncounterGenerator).
class_name EnemyType
extends RefCounted

const HP_GROWTH_PER_LEVEL := 0.10
const POWER_GROWTH_PER_LEVEL := 0.06

var display_name: String
var cost: int
var min_level: int
var hp_range: Vector2i
var initiative_range: Vector2i
var power_range: Vector2

func _init(p_name: String, p_cost: int, p_min_level: int, p_hp: Vector2i, p_initiative: Vector2i, p_power: Vector2) -> void:
	display_name = p_name
	cost = p_cost
	min_level = p_min_level
	hp_range = p_hp
	initiative_range = p_initiative
	power_range = p_power

func roll(level: int, rng: RandomNumberGenerator) -> Character:
	var steps := level - 1
	var hp := roundi(rng.randi_range(hp_range.x, hp_range.y) * (1.0 + HP_GROWTH_PER_LEVEL * steps))
	var power := rng.randf_range(power_range.x, power_range.y) * (1.0 + POWER_GROWTH_PER_LEVEL * steps)
	var initiative := rng.randi_range(initiative_range.x, initiative_range.y)
	return Character.new(display_name, Character.Side.ENEMY, hp, initiative, power, AiController.new())

static func catalog() -> Array[EnemyType]:
	return [
		EnemyType.new("Slime", 1, 1, Vector2i(35, 45), Vector2i(4, 7), Vector2(0.12, 0.16)),
		EnemyType.new("Bat", 1, 2, Vector2i(25, 32), Vector2i(13, 16), Vector2(0.14, 0.18)),
		EnemyType.new("Goblin", 2, 3, Vector2i(50, 60), Vector2i(9, 11), Vector2(0.18, 0.22)),
		EnemyType.new("Skeleton", 3, 5, Vector2i(65, 80), Vector2i(7, 9), Vector2(0.20, 0.25)),
		EnemyType.new("Orc", 4, 7, Vector2i(95, 120), Vector2i(3, 6), Vector2(0.25, 0.30)),
	]
