## Tile animations: gravity falls, swap slides, pop-ins, wobble. Each node has
## at most one driving tween; starting another replaces it.
class_name TileMotion
extends RefCounted

const FALL_ACCEL := 70.0
const MIN_FALL_TIME := 0.1
const SLIDE_SPEED := 8.0
const MIN_SLIDE_TIME := 0.08
const POP_TIME := 0.18

var _owner: Node
var _tracker: ActivityTracker
var _by_node: Dictionary = {}  # Node3D -> Tween

func _init(p_owner: Node, p_tracker: ActivityTracker) -> void:
	_owner = p_owner
	_tracker = p_tracker

# Constant acceleration from rest is a quadratic ease-in. A tile starting out of sight
# (above a pit) is shown on reaching reveal_z.
func fall(node: Node3D, from: Vector3, to: Vector3, reveal_z: float = NAN) -> Tween:
	var duration := maxf(sqrt(2.0 * from.distance_to(to) / BoardGeometry.CELL_SIZE / FALL_ACCEL), MIN_FALL_TIME)
	node.position = from
	node.scale = Vector3.ONE
	node.visible = is_nan(reveal_z)
	var tween := adopt(node, _owner.create_tween())
	tween.tween_property(node, "position", to, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if not is_nan(reveal_z):
		var progress := sqrt(clampf((reveal_z - from.z) / (to.z - from.z), 0.0, 1.0))
		tween.parallel().tween_callback(node.show).set_delay(duration * progress)
	return tween

func slide(node: Node3D, to: Vector3) -> Tween:
	var duration := maxf(node.position.distance_to(to) / BoardGeometry.CELL_SIZE / SLIDE_SPEED, MIN_SLIDE_TIME)
	var tween := adopt(node, _owner.create_tween())
	tween.tween_property(node, "position", to, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tween

func pop(node: Node3D) -> Tween:
	node.scale = Vector3.ZERO
	node.visible = true
	var tween := adopt(node, _owner.create_tween())
	tween.tween_property(node, "scale", Vector3.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween

# Rotation only, so it can run next to a slide.
func wobble(node: Node3D) -> void:
	var base := node.rotation.y
	var tween := _tracker.track(_owner.create_tween())
	for angle in [0.25, -0.25, 0.12, 0.0]:
		tween.tween_property(node, "rotation:y", base + angle, 0.06)

func adopt(node: Node3D, tween: Tween) -> Tween:
	stop(node)
	_by_node[node] = tween
	tween.finished.connect(_on_finished.bind(node, tween))
	return _tracker.track(tween)

func stop(node: Node3D) -> void:
	_tracker.cancel(_by_node.get(node))

func _on_finished(node: Node3D, tween: Tween) -> void:
	if _by_node.get(node) == tween:
		_by_node.erase(node)
