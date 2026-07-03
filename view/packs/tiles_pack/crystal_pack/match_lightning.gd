## One-shot VFX (same pattern as TileExplosion): play(from, to), then self-frees.
## Two-segment bolt with a jittered midpoint reads as electric, no shader needed.
class_name MatchLightning
extends Node3D

const DURATION := 0.22
const JITTER := 0.14

@onready var segment_a: MeshInstance3D = $SegmentA
@onready var segment_b: MeshInstance3D = $SegmentB
@onready var light: OmniLight3D = $Light

func _ready() -> void:
	# Duplicate so simultaneous bolts (a whole match group lighting up) each
	# fade independently instead of fighting over one shared material.
	segment_a.material_override = segment_a.material_override.duplicate()
	segment_b.material_override = segment_b.material_override.duplicate()

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

	var mat_a: StandardMaterial3D = segment_a.material_override
	var mat_b: StandardMaterial3D = segment_b.material_override
	var start_alpha := mat_a.albedo_color.a
	var start_energy := light.light_energy
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(a: float) -> void: mat_a.albedo_color.a = a, start_alpha, 0.0, DURATION)
	tween.tween_method(func(a: float) -> void: mat_b.albedo_color.a = a, start_alpha, 0.0, DURATION)
	tween.tween_method(func(e: float) -> void: light.light_energy = e, start_energy, 0.0, DURATION)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

## Rotates the unit-height cylinder's up axis onto a-to-b, then scales height to length.
func _place_segment(mesh: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var diff := b - a
	var length: float = diff.length()
	mesh.position = (a + b) * 0.5
	if length < 0.001:
		mesh.visible = false
		return
	mesh.quaternion = Quaternion(Vector3.UP, diff / length)
	mesh.scale = Vector3(1.0, length, 1.0)
