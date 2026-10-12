## Battle state shared by the battle phases and BattleView: rosters,
## initiative, whose turn it is and what they picked. Lives alongside
## TurnContext as ctx.battle (null outside battle mode).
class_name BattleContext
extends RefCounted

enum ActionType { ATTACK, DEFEND }

## Cards per column BattleView is laid out for.
const MAX_PER_SIDE := 5

signal turn_started(character: Character)
signal action_selected(character: Character, type: ActionType)
signal target_selected(character: Character)
signal shield_gained(character: Character, amount: int)
## cell_b is null for a detonation (see AiMovePicker.Move).
signal ai_move_chosen(cell_a: GridCell, cell_b: GridCell)
signal battle_ended(victory: bool)

var allies: Array[Character] = []
var enemies: Array[Character] = []
var queue := InitiativeQueue.new()
var resolver: CombatResolver
var active_character: Character
## Resets to ATTACK at the start of every turn.
var pending_action: ActionType = ActionType.ATTACK
## Human's chosen attack target (clicked enemy card), see HumanController.
var human_target: Character
var ended := false
var level := 1

func _init(p_resolver: CombatResolver) -> void:
	resolver = p_resolver

func all_characters() -> Array[Character]:
	var result: Array[Character] = []
	result.append_array(allies)
	result.append_array(enemies)
	return result

func opponents_of(character: Character) -> Array[Character]:
	return enemies if character.side == Character.Side.ALLY else allies

func first_living(characters: Array[Character]) -> Character:
	for character in characters:
		if character.is_alive():
			return character
	return null

func begin_turn(character: Character) -> void:
	active_character = character
	pending_action = ActionType.ATTACK
	turn_started.emit(character)

func select_action(type: ActionType) -> void:
	pending_action = type
	action_selected.emit(active_character, type)

func select_target(character: Character) -> void:
	if character.is_alive():
		human_target = character
		target_selected.emit(character)

func is_battle_over() -> bool:
	return first_living(allies) == null or first_living(enemies) == null

func is_victory() -> bool:
	return first_living(enemies) == null

func finish() -> void:
	if ended:
		return
	ended = true
	battle_ended.emit(is_victory())
