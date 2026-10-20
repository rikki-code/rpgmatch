## Explosion: waits for the detonating tile's fuse, optionally launches a
## projectile and waits for it to land, then flashes the cells. Subclasses add
## the projectile in _launch().
class_name BlastPresenter
extends EffectPresenter

const SHAKE_MIN_CELLS := 8

func play(effect: Effect, stage: BoardView3D) -> void:
	var blast := effect as EffectBlast
	if blast.source != null:
		Audio.play(_charge_cue())
	await stage.tiles.fuse_finished(blast.source)
	var projectile := _launch(blast, stage)
	if projectile != null:
		Audio.play(_launch_cue())
		await projectile.arrived
	Audio.play(_blast_cue())
	if blast.cells.size() >= SHAKE_MIN_CELLS:
		stage.shake()
	await stage.finished(stage.vfx.ripple(blast.cells, blast.origin.position))

func _launch(_blast: EffectBlast, _stage: BoardView3D) -> Vfx:
	return null

func _charge_cue() -> StringName:
	return &"fuse"

func _launch_cue() -> StringName:
	return &""

func _blast_cue() -> StringName:
	return &"bomb_blast"
