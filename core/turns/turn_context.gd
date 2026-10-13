## Shared state passed to every TurnPhase.
class_name TurnContext
extends RefCounted

var board: BoardGraph
var resolver: EffectResolver
var turn_manager: TurnManager
var awaiting_player_input: bool = false
## Lets a phase pace itself between world-cycle waves (see PhasePhysicsResolve).
## Defaults to an instant no-op; game_root swaps in a view-backed driver.
var animation_driver: AnimationDriver = AnimationDriver.new()
var score_tracker: ScoreTracker
## Lets a phase make a board move itself (AI turn, see PhaseCharacterInput).
var swap_controller: SwapController
var detonate_controller: DetonateController
var shuffle_controller: ShuffleController
## Null outside battle mode — battle-only phases assume it's set when present.
var battle: BattleContext

func _init(p_board: BoardGraph) -> void:
	board = p_board
