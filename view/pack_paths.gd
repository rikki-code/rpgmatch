## Base directory for the active pack of each category (see view/packs/).
## Swapping a pack = changing one line here. preload() needs a literal path
## (can't take a const), so consumers use load(PackPaths.X + "file.tscn")
## inside a static _static_init() instead — see TileView, BoardView3D.
class_name PackPaths
extends RefCounted

const TILES_PACK := "res://view/packs/tiles_pack/crystal_pack/"
const BOARD_PACK := "res://view/packs/board_pack/earth_pack/"
const SPECIAL_TILES_PACK := "res://view/packs/special_tiles_pack/standard_pack/"
const BACKGROUND_PACK := "res://view/packs/background_pack/standard_pack/"
