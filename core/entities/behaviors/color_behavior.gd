## Default matching rule: same color id matches.
class_name ColorBehavior
extends TileBehavior

func can_match_with(self_tile: Tile, other_tile: Tile) -> bool:
	return other_tile.color == self_tile.color
