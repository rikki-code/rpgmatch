## Base directory for the active pack of each category (see view/packs/).
## Selectable categories (tiles, board) follow PackCatalog; the rest are fixed.
## preload() needs a literal path, so consumers use load(PackPaths.X + "file.tscn")
## in a static load_packs() instead — see TileView, CellLayer, VfxPool.
class_name PackPaths
extends RefCounted

const SPECIAL_TILES_PACK := "res://view/packs/special_tiles_pack/standard_pack/"
const BACKGROUND_PACK := "res://view/packs/background_pack/standard_pack/"
const BATTLE_FX_PACK := "res://view/packs/battle_fx_pack/standard_pack/"
## Its ui_font.woff2 is also set as project gui/theme/custom_font (bundled for web,
## which has no system font fallback) — swapping this pack means updating that too.
const UI_PACK := "res://view/packs/ui_pack/standard_pack/"

static var TILES_PACK: String = PackCatalog.selected_path(PackCatalog.TILES)
static var BOARD_PACK: String = PackCatalog.selected_path(PackCatalog.BOARD)

static func refresh() -> void:
	TILES_PACK = PackCatalog.selected_path(PackCatalog.TILES)
	BOARD_PACK = PackCatalog.selected_path(PackCatalog.BOARD)
