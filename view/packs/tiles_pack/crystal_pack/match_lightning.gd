## Pooled one-shot VFX (same pattern as TileExplosion): play(from, to), then it
## returns to the pool. Two-segment bolt with a jittered midpoint reads as
## electric, no shader needed.
class_name MatchLightning
extends Vfx

const DURATION := 0.22
const JITTER := 0.14

@onready var segment_a: MeshInstance3D = $SegmentA
@onready var segment_b: MeshInstance3D = $SegmentB
@onready var light: OmniLight3D = $Light

var _mat_a: StandardMaterial3D
var _mat_b: StandardMaterial3D
var _alpha: float
var _energy: float

func _ready() -> void:
	# Own material per instance so simultaneous bolts fade independently.
	_mat_a = segment_a.material_override.duplicate()
	segment_a.material_override = _mat_a
	_mat_b = segment_b.material_override.duplicate()
	segment_b.material_override = _mat_b
	_alpha = _mat_a.albedo_color.a
	_energy = light.light_energy
	light.visible = false

func play(from: Vector3, to: Vector3) -> void:
	var perpendicular := (to - from).cross(Vector3.UP)
	if perpendicular.length() < 0.01:
		perpendicular = Vector3.RIGHT
	else:
		perpendicular = perpendicular.normalized()
	var mid := (from + to) * 0.5 + perpendicular * randf_range(-JITTER, JITTER)

	_place_segment(segment_a, from, mid)
	_place_segment(segment_b, mid, to)
	light.position = mid
	light.visible = light_on
	_mat_a.albedo_color.a = _alpha
	_mat_b.albedo_color.a = _alpha
	light.light_energy = _energy
	_run(DURATION, _update)

func _update(progress: float) -> void:
	var alpha := _alpha * (1.0 - progress)
	_mat_a.albedo_color.a = alpha
	_mat_b.albedo_color.a = alpha
	light.light_energy = _energy * (1.0 - progress)

func _reset() -> void:
	light.visible = false

## Rotates the unit-height cylinder's up axis onto a-to-b, then scales height to length.
func _place_segment(mesh: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var diff := b - a
	var length: float = diff.length()
	mesh.position = (a + b) * 0.5
	if length < 0.001:
		mesh.visible = false
		return
	mesh.visible = true
	mesh.quaternion = Quaternion(Vector3.UP, diff / length)
	mesh.scale = Vector3(1.0, length, 1.0)
