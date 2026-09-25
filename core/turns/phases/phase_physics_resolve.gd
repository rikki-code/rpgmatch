## Runs matches -> destroy -> gravity/refill repeatedly until a pass finds
## no new matches (cascades). Each wave fully resolves in the model, then
## awaits ctx.animation_driver before the next wave starts, so the world
## cycle plays out one step at a time instead of the whole cascade landing
## in the model before any of it has been shown.
class_name PhasePhysicsResolve
extends TurnPhase

func execute(ctx: TurnContext) -> void:
	while true:
		var groups := MatchFinder.find_matches(ctx.board)
		if groups.is_empty() and not ctx.board.has_empty_holdable_cell():
			break

		if not groups.is_empty():
			# One begin_wave() per group, not per iteration: a single swap that
			# matches two colors at once escalates the combo same as a
			# cascade would, instead of both groups scoring at the same x.
			for group in groups:
				ctx.score_tracker.begin_wave()
				ctx.resolver.resolve([EffectResolveMatchGroup.new(group, ctx.resolver)])
			await ctx.animation_driver.await_settle()

		var gravity_effects: Array[Effect] = []
		for x in range(ctx.board.width):
			gravity_effects.append(EffectGravityColumn.new(x))
		ctx.resolver.resolve(gravity_effects)
		await ctx.animation_driver.await_settle()
