## Turns one resolved MatchGroup into destroy effects — and, if the group is
## big enough, a bonus tile. A run/blob of BOMB_MATCH_THRESHOLD or more cells
## fully destroys (same on_matched/splash cascade as any normal match,
## drained through `resolver` before returning) and only then spawns a bomb
## on one of its cells; a straight run of exactly ARROW_MATCH_SIZE spawns an
## arrow blaster instead, oriented across the match (see
## ArrowBlasterCore.Axis) — a size-4 group is always a pure straight run, no
## L/T branch, since any branch would push a group's size to
## BOMB_MATCH_THRESHOLD or above (two runs of >= 3 sharing one cell already
## total >= 5). Either way the spawn lands on the anchor: whichever cell sits
## closest to the group's centroid, so it reads as "the middle of the match"
## rather than an arbitrary corner — never the other way around, or a
## sibling cell's splash (it's almost always orthogonally adjacent to the
## anchor, being part of the same connected group) would detonate the bonus
## tile the instant it spawns. Keeps the "how big/shaped a match becomes a
## bonus tile" policy in one place instead of leaking a size check into
## PhasePhysicsResolve.
class_name EffectResolveMatchGroup
extends Effect

const NORMAL_MATCH_SIZE := 3
const ARROW_MATCH_SIZE := 4
const BOMB_MATCH_THRESHOLD := 5

var group: MatchGroup
var resolver: EffectResolver

func _init(p_group: MatchGroup, p_resolver: EffectResolver) -> void:
	group = p_group
	resolver = p_resolver

func execute(_board: BoardGraph) -> Array[Effect]:
	var cells := group.cells
	var effects: Array[Effect] = [EffectMatchLightning.new(cells)]
	for cell in cells:
		effects.append(EffectDestroyTile.new(cell))

	if cells.size() == NORMAL_MATCH_SIZE:
		return effects

	var anchor: GridCell = _central_cell(cells)
	# Reentrant on purpose: `resolver` is the same EffectResolver driving the
	# outer loop this effect is itself being executed from — its `resolve()`
	# only touches a local queue variable, so nesting a call is safe, and it
	# means this cascade still emits effect_applied per step (view
	# animations/pacing) instead of vanishing into a throwaway resolver.
	resolver.resolve(effects)

	if cells.size() == ARROW_MATCH_SIZE:
		return [EffectSpawnArrowBlasterTile.new(anchor, _blast_axis_for(cells))]

	return [EffectSpawnBombTile.new(anchor)]

static func _blast_axis_for(cells: Array[GridCell]) -> ArrowBlasterCore.Axis:
	var first_x := cells[0].position.x
	for cell in cells:
		if cell.position.x != first_x:
			return ArrowBlasterCore.Axis.COLUMN
	return ArrowBlasterCore.Axis.ROW

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
