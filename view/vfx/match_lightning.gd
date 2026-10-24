## Pooled one-shot VFX (same pattern as TileExplosion): play(from, to), then it
## returns to the pool. A kinked chain of segments (bright core inside a wider
## additive glow, both from the pack scene) reads as electric, no shader needed.
class_name MatchLightning
extends Vfx

const DURATION := 0.3
## Sideways kink of the inner joints, plus a little lift so the bolt stays above the tiles.
const JITTER := 0.13
const LIFT_JITTER := 0.03

@onready var light: OmniLight3D = $Light

var _cores: Array[MeshInstance3D] = []
var _glows: Array[MeshInstance3D] = []
var _core_material: StandardMaterial3D
var _glow_material: StandardMaterial3D
var _core_alpha: float
var _glow_alpha: float
var _energy: float

func _ready() -> void:
	# Own materials per instance so simultaneous bolts fade independently.
	for segment: MeshInstance3D in $Core.get_children():
		_cores.append(segment)
	for segment: MeshInstance3D in $Glow.get_children():
		_glows.append(segment)
	_core_material = _cores[0].material_override.duplicate()
	_glow_material = _glows[0].material_override.duplicate()
	for segment in _cores:
		segment.material_override = _core_material
	for segment in _glows:
		segment.material_override = _glow_material
	_core_alpha = _core_material.albedo_color.a
	_glow_alpha = _glow_material.albedo_color.a
	_energy = light.light_energy
	light.visible = false

func play(from: Vector3, to: Vector3) -> void:
	var along := to - from
	var perpendicular := along.cross(Vector3.UP)
	if perpendicular.length() < 0.01:
		perpendicular = Vector3.RIGHT
	else:
		perpendicular = perpendicular.normalized()

	var count := _cores.size()
	var joint := from
	for i in range(count):
		var next := to
		if i < count - 1:
			next = from + along * (float(i + 1) / count) + perpendicular * randf_range(-JITTER, JITTER) + Vector3.UP * randf_range(-LIFT_JITTER, LIFT_JITTER)
		_place_segment(_cores[i], joint, next)
		_place_segment(_glows[i], joint, next)
		joint = next
	light.position = (from + to) * 0.5
	light.visible = light_on
	_core_material.albedo_color.a = _core_alpha
	_glow_material.albedo_color.a = _glow_alpha
	light.light_energy = _energy
	_run(DURATION, _update)

func _update(progress: float) -> void:
	var fade := 1.0 - progress
	_core_material.albedo_color.a = _core_alpha * fade
	_glow_material.albedo_color.a = _glow_alpha * fade
	light.light_energy = _energy * fade

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
