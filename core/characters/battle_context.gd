## Battle state shared by the battle phases and BattleView: rosters,
## initiative, whose turn it is and what they picked. Lives alongside
## TurnContext as ctx.battle (null outside battle mode).
class_name BattleContext
extends RefCounted

## Cards per column BattleView is laid out for.
const MAX_PER_SIDE := 5

signal turn_started(character: Character)
signal action_selected(character: Character, action: BattleAction)
## The active character's target for its pending action (set ahead so the view can show it).
signal target_selected(character: Character)
## Emitted right before the action applies (PhaseResolveCombatAction waits LAUNCH_SECONDS between).
signal action_launched(actor: Character, target: Character, action: BattleAction)
## `character` = who received the shield (the actor or an ally).
signal shield_gained(character: Character, amount: int)
## cell_b is null for a detonation (see MoveFinder.Move).
signal ai_move_chosen(cell_a: GridCell, cell_b: GridCell)
signal battle_ended(victory: bool)

var allies: Array[Character] = []
var enemies: Array[Character] = []
var queue := InitiativeQueue.new()
var resolver: CombatResolver
var active_character: Character
## Everything a character may do with its turn; the first is the default.
var actions: Array[BattleAction] = [AttackAction.new(), DefendAction.new()]
## Resets to the default action at the start of every turn.
var pending_action: BattleAction
## Who the pending action will hit — the controller's pick, or a human's
## click on any card (friendly fire / shielding an enemy are allowed).
var pending_target: Character
var ended := false
var level := 1
## Board-dependent scale for match points only — few colors = self-feeding
## cascades (see BattleMode.POWER_MULTIPLIER_BY_COLORS). Blasts aren't cascades.
var power_multiplier := 1.0

func _init(p_resolver: CombatResolver) -> void:
	resolver = p_resolver

func all_characters() -> Array[Character]:
	var result: Array[Character] = []
	result.append_array(allies)
	result.append_array(enemies)
	return result

func opponents_of(character: Character) -> Array[Character]:
	return enemies if character.side == Character.Side.ALLY else allies

func allies_of(character: Character) -> Array[Character]:
	return allies if character.side == Character.Side.ALLY else enemies

func living(characters: Array[Character]) -> Array[Character]:
	var result: Array[Character] = []
	for character in characters:
		if character.is_alive():
			result.append(character)
	return result

func first_living(characters: Array[Character]) -> Character:
	var alive := living(characters)
	return null if alive.is_empty() else alive[0]

## The turn's board points as this actor's attack/shield power.
func power_of(actor: Character, score: ScoreTracker) -> int:
	var points := score.turn_match_points * power_multiplier + score.turn_blast_points * ScoreTracker.BLAST_POWER_FACTOR
	return actor.power_from_points(roundi(points))

func begin_turn(character: Character) -> void:
	active_character = character
	pending_action = actions[0]
	_choose_target()
	turn_started.emit(character)

func select_action(action: BattleAction) -> void:
	pending_action = action
	_choose_target()
	action_selected.emit(active_character, action)

func select_target(character: Character) -> void:
	if character != null and character.is_alive():
		pending_target = character
		target_selected.emit(character)

func _choose_target() -> void:
	select_target(active_character.controller.choose_target(active_character, pending_action, self))

func is_battle_over() -> bool:
	return first_living(allies) == null or first_living(enemies) == null

func is_victory() -> bool:
	return first_living(enemies) == null

func finish() -> void:
	if ended:
		return
	ended = true
	battle_ended.emit(is_victory())
