## Wires the reusable board/turn engine into a specific way to play it —
## which TurnPhases run, and what extra state (e.g. ctx.battle) they need.
## GameRoot swaps modes by building a fresh TurnManager from whichever mode
## is selected (see GameRoot.switch_mode, view/editor/editor_toolbar.gd).
class_name GameMode
extends RefCounted

func display_name() -> String:
	return "Mode"

## ctx already has board/resolver/score_tracker set. A mode that needs more
## (e.g. BattleMode setting ctx.battle) does so here before returning.
## `level` = progression level (RunConfig.level); modes that don't scale ignore it.
func build_phases(_ctx: TurnContext, _level: int) -> Array[TurnPhase]:
	return []

## Generation params for a fresh board in this mode; `base` = the player's
## settings (menu), which a mode may scale down from.
func board_params(base: WorldGenParams, _level: int) -> WorldGenParams:
	return base

func shows_score_hud() -> bool:
	return true

func shows_quest_hud() -> bool:
	return true

func shows_battle_view() -> bool:
	return false
