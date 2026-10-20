## Battle sounds: each beat of a turn (action flight, hit, shield, death, result).
## An action's launch sound is "action_" + its visual_kind(), so a new BattleAction only needs a cue.
class_name BattleAudio
extends RefCounted

## A hit of this share of the target's max HP (or more) gets the lowest pitch.
const HEAVY_HIT_HP_SHARE := 0.5
const HIT_PITCH_LIGHT := 1.2
const HIT_PITCH_HEAVY := 0.8

func _init(battle: BattleContext) -> void:
	battle.turn_started.connect(_on_turn_started)
	battle.target_selected.connect(_play.bind(&"target_select").unbind(1))
	battle.action_launched.connect(_on_action_launched)
	battle.shield_gained.connect(_play.bind(&"shield").unbind(2))
	battle.resolver.action_resolved.connect(_on_action_resolved)
	battle.battle_ended.connect(_on_battle_ended.bind(battle))

func _play(cue: StringName) -> void:
	Audio.play(cue)

func _on_turn_started(character: Character) -> void:
	if character.controller.is_human():
		Audio.play(&"turn_start")

func _on_action_launched(_actor: Character, _target: Character, action: BattleAction) -> void:
	Audio.play(StringName("action_%s" % action.visual_kind()))

func _on_action_resolved(action: CombatAction, damage: int, is_crit: bool) -> void:
	var weight := clampf(damage / (action.target.max_hp * HEAVY_HIT_HP_SHARE), 0.0, 1.0)
	Audio.play(&"crit" if is_crit else &"hit", lerpf(HIT_PITCH_LIGHT, HIT_PITCH_HEAVY, weight))
	if not action.target.is_alive():
		Audio.play(&"death")

func _on_battle_ended(victory: bool, battle: BattleContext) -> void:
	Audio.play(&"victory" if victory or battle.is_versus() else &"defeat")
