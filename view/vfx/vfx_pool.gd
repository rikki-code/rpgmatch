## Pooled board VFX. GL Compatibility (web) pays for every instantiate, material
## duplicate, extra light and first-draw shader compile, so instances are built
## up front, reused, capped (acquire() returns null past MAX_LIVE) and only a few
## may carry a light.
class_name VfxPool
extends Node3D

const MAX_LIVE := 24
const MAX_LIGHTS := 4
const PREBUILT := 8
const FULL_PER_BLAST := 6
const RIPPLE_DELAY := 0.03
const RIPPLE_MAX := 0.2

static var EXPLOSION_SCENE: PackedScene
static var LIGHTNING_SCENE: PackedScene
static var ARROW_BOLT_SCENE: PackedScene
static var PRISM_BOLT_SCENE: PackedScene

static func _static_init() -> void:
	load_packs()

static func load_packs() -> void:
	EXPLOSION_SCENE = load(PackPaths.SPECIAL_TILES_PACK + "tile_explosion.tscn")
	LIGHTNING_SCENE = load(PackPaths.TILES_PACK + "match_lightning.tscn")
	ARROW_BOLT_SCENE = load(PackPaths.SPECIAL_TILES_PACK + "arrow_blast_bolt.tscn")
	PRISM_BOLT_SCENE = load(PackPaths.SPECIAL_TILES_PACK + "prism_bolt.tscn")

var tracker: ActivityTracker

var _free: Dictionary = {}  # PackedScene -> Array[Vfx]
var _live: Dictionary = {}  # PackedScene -> int
var _lights := 0

func setup(p_tracker: ActivityTracker) -> void:
	tracker = p_tracker
	for scene: PackedScene in [EXPLOSION_SCENE, LIGHTNING_SCENE, ARROW_BOLT_SCENE, PRISM_BOLT_SCENE]:
		var shelf: Array = []
		for i in range(PREBUILT):
			shelf.append(_create(scene))
		_free[scene] = shelf

# Draws every effect once at near-zero scale so shaders compile on load, not on the first bomb.
func warm_up(at: Vector3) -> void:
	var explosion := acquire(EXPLOSION_SCENE) as TileExplosion
	if explosion != null:
		_tiny(explosion, at)
		explosion.play(true)
	var bolt_lightning := acquire(LIGHTNING_SCENE) as MatchLightning
	if bolt_lightning != null:
		_tiny(bolt_lightning, at)
		bolt_lightning.play(at, at + Vector3.RIGHT)
	var arrow := acquire(ARROW_BOLT_SCENE) as ArrowBlastBolt
	if arrow != null:
		_tiny(arrow, at)
		arrow.play(at, at + Vector3.RIGHT)
	var prism := acquire(PRISM_BOLT_SCENE) as PrismBolt
	if prism != null:
		_tiny(prism, at)
		prism.play(at, at + Vector3.RIGHT, Color.WHITE)

func _tiny(vfx: Vfx, at: Vector3) -> void:
	vfx.position = at
	vfx.scale = Vector3.ONE * 0.001

func acquire(scene: PackedScene) -> Vfx:
	var live: int = _live.get(scene, 0)
	if live >= MAX_LIVE:
		return null
	var shelf: Array = _free.get_or_add(scene, [])
	var vfx: Vfx = shelf.pop_back() if not shelf.is_empty() else _create(scene)
	_live[scene] = live + 1
	vfx.light_on = _lights < MAX_LIGHTS
	if vfx.light_on:
		_lights += 1
	return vfx

func release(vfx: Vfx) -> void:
	if vfx.light_on:
		_lights -= 1
		vfx.light_on = false
	_live[vfx.scene] -= 1
	vfx.visible = false
	vfx.scale = Vector3.ONE
	vfx._reset()
	_free[vfx.scene].append(vfx)

func explode(at: Vector3, full: bool) -> void:
	var vfx := acquire(EXPLOSION_SCENE) as TileExplosion
	if vfx == null:
		return
	vfx.position = at
	vfx.play(full)

# Flashes the cells outward from `origin`, nearest first; only the first few get the full effect.
func ripple(cells: Array[GridCell], origin: Vector2i) -> Tween:
	var ordered := cells.duplicate()
	ordered.sort_custom(func(a: GridCell, b: GridCell) -> bool:
		return _distance(a.position, origin) < _distance(b.position, origin))
	var tween := tracker.track(create_tween()).set_parallel(true)
	for i in range(ordered.size()):
		var pos: Vector2i = ordered[i].position
		var delay := minf(_distance(pos, origin) * RIPPLE_DELAY, RIPPLE_MAX)
		tween.tween_callback(explode.bind(BoardGeometry.lifted_world(pos), i < FULL_PER_BLAST)).set_delay(delay)
	return tween

func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func lightning(from: Vector3, to: Vector3) -> void:
	var vfx := acquire(LIGHTNING_SCENE) as MatchLightning
	if vfx != null:
		vfx.play(from, to)

# Bolts return the instance so a presenter can await its `arrived` signal (null when capped).
func arrow_bolt(from: Vector3, to: Vector3) -> ArrowBlastBolt:
	var vfx := acquire(ARROW_BOLT_SCENE) as ArrowBlastBolt
	if vfx != null:
		vfx.play(from, to)
	return vfx

func prism_bolt(from: Vector3, to: Vector3, color: Color) -> PrismBolt:
	var vfx := acquire(PRISM_BOLT_SCENE) as PrismBolt
	if vfx != null:
		vfx.play(from, to, color)
	return vfx

func _create(scene: PackedScene) -> Vfx:
	var vfx: Vfx = scene.instantiate()
	vfx.pool = self
	vfx.scene = scene
	vfx.visible = false
	add_child(vfx)
	return vfx
