## A tile is generic: color + a list of TileBehavior. Bonus/penalty tiles
## are the same class with a different behavior list, not subclasses.
class_name Tile
extends BoardEntity

var color: int
## Explicit visual override for tiles whose look isn't just "index into
## TileView's shared color palette" (e.g. a plain bomb is always black,
## regardless of the 6-color palette). null = TileView looks `color` up in
## its palette as usual.
var visual_color: Variant = null
var behaviors: Array[TileBehavior] = []

func _init(p_color: int = 0) -> void:
	color = p_color

## Plain color tile: matches by color, splash-damages its 4 neighbors when
## a match destroys it (see SplashDamageBehavior).
static func make_normal(p_color: int) -> Tile:
	var tile := Tile.new(p_color)
	tile.behaviors.append(ColorBehavior.new())
	tile.behaviors.append(SplashDamageBehavior.new())
	return tile

static func make_color_bomb(p_color: int, radius: int = 1) -> Tile:
	var tile := Tile.new(p_color)
	# BombCore is itself a TileBehavior (reacts to on_damage — a direct
	# blast hit always chains, no bomb variant would ever want to opt out).
	var core := BombCore.new(radius, BombCore.Shape.MANHATTAN)
	tile.behaviors.append(ColorBehavior.new())
	tile.behaviors.append(core)
	tile.behaviors.append(MatchTriggerBehavior.new(core))
	return tile

static func make_bomb(radius: int = 1) -> Tile:
	var tile := Tile.new()
	tile.color = -1
	tile.visual_color = Color.BLACK
	var core := BombCore.new(radius, BombCore.Shape.SQUARE)
	tile.behaviors.append(core)
	tile.behaviors.append(ManualTriggerBehavior.new(core))
	tile.behaviors.append(SwapSplashTriggerBehavior.new(core))
	tile.behaviors.append(CombineEffectsBehavior.new(core))
	return tile

static func make_arrow_blaster(axis: ArrowBlasterCore.Axis, extra_lines: int = 0) -> Tile:
	var tile := Tile.new()
	tile.color = -1
	var core := ArrowBlasterCore.new(axis, extra_lines)
	tile.behaviors.append(core)
	tile.behaviors.append(ManualTriggerBehavior.new(core))
	tile.behaviors.append(SwapSplashTriggerBehavior.new(core))
	tile.behaviors.append(CombineEffectsBehavior.new(core))
	return tile

static func make_prism() -> Tile:
	var tile := Tile.new()
	tile.color = -1
	var core := PrismCore.new()
	tile.behaviors.append(core)
	tile.behaviors.append(ManualTriggerBehavior.new(core))
	tile.behaviors.append(SwapSplashTriggerBehavior.new(core))
	tile.behaviors.append(CombineEffectsBehavior.new(core))
	return tile

func display_name() -> String:
	return "tile(color=%d)" % color

func can_match_with(other: BoardEntity) -> bool:
	if not (other is Tile):
		return false
	for behavior in behaviors:
		if behavior.can_match_with(self, other):
			return true
	return false

func can_combine_with(other: Tile) -> bool:
	for behavior in behaviors:
		if behavior.can_combine_with(self, other):
			return true
	return false

func combine_with(other: Tile, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	var effects: Array[Effect] = []
	for behavior in behaviors:
		effects.append_array(behavior.combine_with(self, other, cell, board))
	return effects

func blocks_swap() -> bool:
	for behavior in behaviors:
		if behavior.blocks_swap(self):
			return true
	return false

func is_manually_triggerable() -> bool:
	for behavior in behaviors:
		if behavior.is_manually_triggerable(self):
			return true
	return false

func manual_trigger(cell: GridCell, board: BoardGraph) -> Array[Effect]:
	var effects: Array[Effect] = []
	for behavior in behaviors:
		effects.append_array(behavior.manual_trigger(self, cell, board))
	return effects

func visual_kind() -> StringName:
	for behavior in behaviors:
		var kind := behavior.visual_kind(self)
		if kind != &"":
			return kind
	return &""

func on_matched(cell: GridCell, board: BoardGraph) -> Array[Effect]:
	var effects: Array[Effect] = []
	for behavior in behaviors:
		effects.append_array(behavior.on_matched(self, cell, board))
	return effects

func on_turn_tick(cell: GridCell, board: BoardGraph) -> Array[Effect]:
	var effects: Array[Effect] = []
	for behavior in behaviors:
		effects.append_array(behavior.on_turn_tick(self, cell, board))
	return effects

func on_splash_damage(amount: int, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	var effects: Array[Effect] = []
	for behavior in behaviors:
		effects.append_array(behavior.on_splash_damage(self, amount, cell, board))
	return effects

func on_damage(amount: int, cell: GridCell, board: BoardGraph) -> Array[Effect]:
	for behavior in behaviors:
		var effects := behavior.on_damage(self, amount, cell, board)
		if not effects.is_empty():
			return effects
	return [EffectDestroyTile.new(cell)]
