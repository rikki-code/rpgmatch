## Self-contained one-shot VFX (same pattern as TileExplosion/MatchLightning):
## instance, call play(from, to), it travels then fades and frees itself.
class_name ArrowBlastBolt
extends Node3D

const TRAVEL_TIME := 0.16
const FADE_TIME := 0.12

@onready var bolt: MeshInstance3D = $Bolt
@onready var light: OmniLight3D = $Light

func _ready() -> void:
	bolt.material_override = bolt.material_override.duplicate()

func play(from: Vector3, to: Vector3) -> void:
	position = from
	var material: StandardMaterial3D = bolt.material_override
	var start_alpha := material.albedo_color.a
	var start_energy := light.light_energy

	var tween := create_tween()
	tween.tween_property(self, "position", to, TRAVEL_TIME).set_trans(Tween.TRANS_SINE)
	tween.tween_method(func(a: float) -> void: material.albedo_color.a = a, start_alpha, 0.0, FADE_TIME)
	tween.parallel().tween_method(func(e: float) -> void: light.light_energy = e, start_energy, 0.0, FADE_TIME)
	tween.tween_callback(queue_free)
