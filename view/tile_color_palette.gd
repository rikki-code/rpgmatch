## A pack's color palette, e.g. view/packs/tiles_pack/crystal_pack/tile_colors.tres —
## a different pack swaps in a different palette without touching TileView.
class_name TileColorPalette
extends Resource

@export var colors: Array[Color] = []
