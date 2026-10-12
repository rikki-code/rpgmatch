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
func build_phases(_ctx: TurnContext) -> Array[TurnPhase]:
	return []

func shows_score_hud() -> bool:
	return true

func shows_quest_hud() -> bool:
	return true

func shows_battle_view() -> bool:
	return false
