## One battle participant — player, ally, or enemy all use this same class.
## Side and control are composition (side, CharacterController), not
## subclassing, so a future networked/ally-controlled character reuses this
## unchanged.
class_name Character
extends RefCounted

enum Side { ALLY, ENEMY }

var display_name: String
var side: Character.Side
var max_hp: int
var hp: int
var initiative: int
## Board points earned on its turn -> action power. Everyone plays the same
## board, so this is what makes one character hit harder than another.
var power_scale: float
var base_crit_chance: float
var controller: CharacterController
## Absorbs incoming damage before HP (banked by DEFEND).
var shield: int = 0

func _init(p_display_name: String, p_side: Character.Side, p_max_hp: int, p_initiative: int, p_power_scale: float, p_controller: CharacterController, p_base_crit_chance: float = 0.05) -> void:
	display_name = p_display_name
	side = p_side
	max_hp = p_max_hp
	hp = p_max_hp
	initiative = p_initiative
	power_scale = p_power_scale
	base_crit_chance = p_base_crit_chance
	controller = p_controller

func is_alive() -> bool:
	return hp > 0

func power_from_points(points: int) -> int:
	if points <= 0:
		return 0
	return maxi(roundi(points * power_scale), 1)

func apply_damage(amount: int) -> void:
	var absorbed := mini(shield, amount)
	shield -= absorbed
	hp = maxi(hp - (amount - absorbed), 0)
