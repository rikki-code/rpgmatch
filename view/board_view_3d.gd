## Board view root: owns the tile and cell layers, the VFX pool and playback of
## queued effects. present_effect() queues, await_settled() plays them through
## WavePlayer; refresh() reconciles tiles with the board for changes that carry
## no effect (opening fill, swap, shuffle, world editor) and after each wave.
class_name BoardView3D
extends Node3D

const SHAKE_STRENGTH := 0.07

var board: BoardGraph
var tiles := TileLayer.new()
var cells := CellLayer.new()
var vfx := VfxPool.new()

var _presenters: Dictionary = {}  # Script -> EffectPresenter
var _wave := WavePlayer.new()
var _tracker := ActivityTracker.new()
var _rest_position: Vector3

func _ready() -> void:
	_rest_position = position
	add_child(cells)
	add_child(tiles)
	add_child(vfx)
	vfx.setup(_tracker)

func setup(p_board: BoardGraph) -> void:
	board = p_board
	_register_presenters()
	cells.build(board)
	tiles.setup(board, _tracker)
	refresh()
	vfx.warm_up(BoardGeometry.lifted_world(Vector2i.ZERO))

func _register_presenters() -> void:
	var appear := AppearTilePresenter.new()
	for effect_script in [EffectSpawnTile, EffectSpawnBombTile, EffectSpawnArrowBlasterTile, EffectSpawnPrismTile, EffectPlaceTile]:
		_presenters[effect_script] = appear
	var destroy := DestroyPresenter.new()
	for effect_script in [EffectDestroyTile, EffectEntityRemoved, EffectConsumeTile]:
		_presenters[effect_script] = destroy
	_presenters[EffectGravityColumn] = GravityPresenter.new()
	_presenters[EffectMatchLightning] = MatchLightningPresenter.new()
	_presenters[EffectBombBlast] = BlastPresenter.new()
	_presenters[EffectArrowBlast] = ArrowBlastPresenter.new()
	_presenters[EffectPrismBlast] = PrismBlastPresenter.new()

func present_effect(effect: Effect) -> void:
	if _presenters.has(effect.get_script()):
		_wave.add(effect)

func await_settled() -> void:
	while true:
		await _wave.play(_presenters, self)
		await _tracker.wait_idle()
		refresh()
		if _tracker.is_idle() and _wave.is_empty():
			return

# Skipped while effects are queued: playing them reconciles afterwards.
func refresh(instant: bool = false) -> void:
	if _wave.is_empty():
		tiles.refresh(instant)

func finished(tween: Tween) -> void:
	await _tracker.wait(tween)

func shake() -> void:
	var tween := _tracker.track(create_tween())
	for i in range(5):
		var offset := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * SHAKE_STRENGTH * (1.0 - i / 5.0)
		tween.tween_property(self, "position", _rest_position + offset, 0.035)
	tween.tween_property(self, "position", _rest_position, 0.035)
