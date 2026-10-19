## Explosion: waits for the detonating tile's fuse, optionally launches a
## projectile and waits for it to land, then flashes the cells. Subclasses add
## the projectile in _launch().
class_name BlastPresenter
extends EffectPresenter

const SHAKE_MIN_CELLS := 8

func play(effect: Effect, stage: BoardView3D) -> void:
	var blast := effect as EffectBlast
	await stage.tiles.fuse_finished(blast.source)
	var projectile := _launch(blast, stage)
	if projectile != null:
		await projectile.arrived
	if blast.cells.size() >= SHAKE_MIN_CELLS:
		stage.shake()
	await stage.finished(stage.vfx.ripple(blast.cells, blast.origin.position))

func _launch(_blast: EffectBlast, _stage: BoardView3D) -> Vfx:
	return null
