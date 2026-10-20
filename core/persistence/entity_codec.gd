## Board entity <-> plain data for saves. A new BoardEntity subtype adds its case here
## (a tile is saved by its factory recipe, see Tile.from_recipe).
class_name EntityCodec
extends RefCounted

static func encode(entity: BoardEntity) -> Variant:
	if entity == null:
		return null
	if entity is Tile:
		if entity.recipe.is_empty():
			push_error("Tile without a recipe cannot be saved")
			return null
		return entity.recipe
	push_error("Entity type has no save format: %s" % entity.display_name())
	return null

static func decode(data: Variant) -> BoardEntity:
	if data == null:
		return null
	return Tile.from_recipe(data)
