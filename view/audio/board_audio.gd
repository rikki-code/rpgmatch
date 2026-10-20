## Sounds that follow game events on the board and HUD. Effect sounds live in the
## presenters instead (EffectPresenter.cue_for), so they line up with the animation.
class_name BoardAudio
extends RefCounted

const COMBO_PITCH_STEP := 0.06
const COMBO_MAX_STEPS := 8

func _init(ctx: TurnContext, quests: QuestManager, swap_controller: SwapController, detonate_controller: DetonateController) -> void:
	ctx.score_tracker.combo_wave_started.connect(_on_combo_wave)
	swap_controller.swap_applied.connect(_play.bind(&"swap").unbind(2))
	swap_controller.swap_rejected.connect(_play.bind(&"swap_reject").unbind(2))
	swap_controller.tiles_combined.connect(_play.bind(&"combine").unbind(2))
	detonate_controller.detonated.connect(_play.bind(&"detonate").unbind(1))
	ctx.shuffle_controller.shuffled.connect(_play.bind(&"shuffle"))
	quests.quest_progress_changed.connect(_play.bind(&"quest_tick").unbind(1))
	quests.quest_completed.connect(_play.bind(&"quest_done").unbind(1))

func _play(cue: StringName) -> void:
	Audio.play(cue)

# The first group of a turn is x1 and silent; every follow-up climbs a step.
func _on_combo_wave(wave: int) -> void:
	if wave > 1:
		Audio.play(&"combo", 1.0 + COMBO_PITCH_STEP * mini(wave - 2, COMBO_MAX_STEPS))
