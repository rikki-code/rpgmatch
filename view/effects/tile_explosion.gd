## Self-contained one-shot flash VFX: instance tile_explosion.tscn, position
## it, call play() — it animates itself and frees itself. Callers (BoardView3D)
## don't need to know what's inside; tweak the light/mesh/material in the
## .tscn/.tres to change the look without touching this script.
class_name TileExplosion
extends Node3D

const DURATION := 0.3

@onready var light: OmniLight3D = $Light
@onready var flash: MeshInstance3D = $Flash

func _ready() -> void:
	# Duplicate so simultaneous explosions (a big bomb's blast) each fade
	# independently instead of fighting over one shared material resource.
	flash.material_override = flash.material_override.duplicate()

func play() -> void:
	var material: StandardMaterial3D = flash.material_override
	var start_energy := light.light_energy
	var start_alpha := material.albedo_color.a
	flash.scale = Vector3.ONE * 0.4

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 1.6, DURATION).set_trans(Tween.TRANS_SINE)
	tween.tween_method(func(e: float) -> void: light.light_energy = e, start_energy, 0.0, DURATION)
	tween.tween_method(func(a: float) -> void: material.albedo_color.a = a, start_alpha, 0.0, DURATION)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
