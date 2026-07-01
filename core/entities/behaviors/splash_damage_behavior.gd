## Every ordinary tile chip-damages its 4 orthogonal neighbors when a match
## destroys it. Most neighbors just ignore this (no HP, no on_damage
## override) — it exists so a bomb sitting next to an unrelated match still
## gets triggered (see BombBehavior.on_damage) without this tile needing to
## know a bomb is there.
class_name SplashDamageBehavior
extends TileBehavior

const SPLASH_AMOUNT := 1

func on_matched(_self_tile: Tile, cell: GridCell, _board: BoardGraph) -> Array[Effect]:
	var effects: Array[Effect] = []
	for dir in GridDirection.ALL:
		var neighbor := cell.neighbor(dir)
		if neighbor != null:
			effects.append(EffectDamageEntity.new(neighbor, SPLASH_AMOUNT))
	return effects
