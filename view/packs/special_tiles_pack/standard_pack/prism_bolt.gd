## Pooled projectile: play(from, to, color) flies tinted, emits `arrived`, fades.
class_name PrismBolt
extends Vfx

const TRAVEL_TIME := 0.22
const FADE_TIME := 0.14

@onready var bolt: MeshInstance3D = $Bolt
@onready var light: OmniLight3D = $Light

var _material: StandardMaterial3D
var _from: Vector3
var _to: Vector3
var _alpha: float
var _energy: float
var _arrived := false

func _ready() -> void:
	_material = bolt.material_override.duplicate()
	bolt.material_override = _material
	_alpha = _material.albedo_color.a
	_energy = light.light_energy
	light.visible = false

func play(from: Vector3, to: Vector3, color: Color) -> void:
	_from = from
	_to = to
	position = from
	_material.albedo_color = Color(color.r, color.g, color.b, _alpha)
	if _material.emission_enabled:
		_material.emission = color
	light.light_color = color
	light.visible = light_on
	light.light_energy = _energy
	_arrived = false
	_run(TRAVEL_TIME + FADE_TIME, _update)

func _update(progress: float) -> void:
	var elapsed := progress * (TRAVEL_TIME + FADE_TIME)
	position = _from.lerp(_to, minf(elapsed / TRAVEL_TIME, 1.0))
	if not _arrived and elapsed >= TRAVEL_TIME:
		_arrived = true
		arrived.emit()
	var fade := clampf((elapsed - TRAVEL_TIME) / FADE_TIME, 0.0, 1.0)
	_material.albedo_color.a = _alpha * (1.0 - fade)
	light.light_energy = _energy * (1.0 - fade)

func _reset() -> void:
	light.visible = false
