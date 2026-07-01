## Turns one resolved MatchGroup into destroy effects — and, if the group is
## big enough, a bonus tile. A run/blob of BOMB_MATCH_THRESHOLD or more cells
## fully destroys (same on_matched/splash cascade as any normal match,
## drained through `resolver` before returning) and only then spawns a bomb
## on one of its cells (the anchor: whichever cell sits closest to the
## group's centroid, so it reads as "the middle of the match" rather than an
## arbitrary corner) — never the other way around, or a sibling cell's
## splash (it's almost always orthogonally adjacent to the anchor, being
## part of the same connected group) would detonate the bomb the instant it
## spawns. Keeps the "how big a match becomes a bonus tile" policy in one
## place instead of leaking a size check into PhasePhysicsResolve.
class_name EffectResolveMatchGroup
extends Effect

const BOMB_MATCH_THRESHOLD := 5

var group: MatchGroup
var resolver: EffectResolver

func _init(p_group: MatchGroup, p_resolver: EffectResolver) -> void:
	group = p_group
	resolver = p_resolver

func execute(_board: BoardGraph) -> Array[Effect]:
	var cells := group.cells
	if cells.size() < BOMB_MATCH_THRESHOLD:
		var effects: Array[Effect] = []
		for cell in cells:
			effects.append(EffectDestroyTile.new(cell))
		return effects

	var anchor: GridCell = _central_cell(cells)
	var destroy_effects: Array[Effect] = []
	for cell in cells:
		destroy_effects.append(EffectDestroyTile.new(cell))
	# Reentrant on purpose: `resolver` is the same EffectResolver driving the
	# outer loop this effect is itself being executed from — its `resolve()`
	# only touches a local queue variable, so nesting a call is safe, and it
	# means this cascade still emits effect_applied per step (view
	# animations/pacing) instead of vanishing into a throwaway resolver.
	resolver.resolve(destroy_effects)
	return [EffectSpawnBombTile.new(anchor)]

static func _central_cell(cells: Array[GridCell]) -> GridCell:
	var center := Vector2.ZERO
	for cell in cells:
		center += Vector2(cell.position)
	center /= cells.size()

	var best: GridCell = cells[0]
	var best_dist := Vector2(best.position).distance_squared_to(center)
	for cell in cells:
		var dist := Vector2(cell.position).distance_squared_to(center)
		if dist < best_dist:
			best_dist = dist
			best = cell
	return best
