## Self-contained one-shot VFX (same pattern as ArrowBlastBolt/TileExplosion):
## instance, call play(from, to, color), it travels tinted to `color` then
## fades and frees itself. Color varies per shot (the board's current
## majority color) so it can't be baked into the material like ArrowBlastBolt's is.
class_name PrismBolt
extends Node3D

const TRAVEL_TIME := 0.22
const FADE_TIME := 0.14

@onready var bolt: MeshInstance3D = $Bolt
@onready var light: OmniLight3D = $Light

func _ready() -> void:
	bolt.material_override = bolt.material_override.duplicate()

func play(from: Vector3, to: Vector3, color: Color) -> void:
	position = from
	var material: StandardMaterial3D = bolt.material_override
	material.albedo_color = color
	if material.emission_enabled:
		material.emission = color
	light.light_color = color
	var start_alpha := material.albedo_color.a
	var start_energy := light.light_energy

	var tween := create_tween()
	tween.tween_property(self, "position", to, TRAVEL_TIME).set_trans(Tween.TRANS_LINEAR)
	tween.tween_method(func(a: float) -> void: material.albedo_color.a = a, start_alpha, 0.0, FADE_TIME)
	tween.parallel().tween_method(func(e: float) -> void: light.light_energy = e, start_energy, 0.0, FADE_TIME)
	tween.tween_callback(queue_free)
