## A battle FX pack's action colors, keyed by BattleAction.visual_kind() —
## e.g. view/packs/battle_fx_pack/standard_pack/action_colors.tres.
class_name ActionColorPalette
extends Resource

@export var colors: Dictionary = {}

func color_for(kind: StringName) -> Color:
	return colors.get(kind, Color.WHITE)
