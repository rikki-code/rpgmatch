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
		if groups.is_empty():
			break

		var destroy_effects: Array[Effect] = []
		for group in groups:
			for cell in group.cells:
				destroy_effects.append(EffectDestroyTile.new(cell))
		ctx.resolver.resolve(destroy_effects)
		await ctx.animation_driver.await_settle()

		var gravity_effects: Array[Effect] = []
		for x in range(ctx.board.width):
			gravity_effects.append(EffectGravityColumn.new(x))
		ctx.resolver.resolve(gravity_effects)
		await ctx.animation_driver.await_settle()
