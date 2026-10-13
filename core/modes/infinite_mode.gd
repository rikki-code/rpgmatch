## The original endless play: swap, cascade, chase score/quests forever.
class_name InfiniteMode
extends GameMode

func display_name() -> String:
	return "Infinite"

func build_phases(ctx: TurnContext) -> Array[TurnPhase]:
	ctx.battle = null
	ctx.score_tracker.combo_step = 1.0
	return [
		PhasePlayerInput.new(),
		PhaseEnvironmentStub.new(),
		PhaseEnemyStub.new(),
		PhasePhysicsResolve.new(),
	]
