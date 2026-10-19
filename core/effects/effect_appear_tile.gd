## Base of effects that put a tile on `cell`. `fall_distance` is how far above
## the cell it starts (0 = appears in place); `reveal_distance` is how close it
## must get before it is shown (a spawn can start inside the segment above a pit).
class_name EffectAppearTile
extends Effect

var cell: GridCell
var tile: Tile
var fall_distance: int = 0
var reveal_distance: int = 0
