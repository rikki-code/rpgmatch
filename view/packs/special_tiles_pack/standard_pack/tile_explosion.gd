## Pooled one-shot flash VFX (see VfxPool): position it, call play(); `full`
## adds shockwave, sparks and a light, a plain flash is the cheap variant.
class_name TileExplosion
extends Vfx

const DURATION := 0.3
const SHOCKWAVE_DURATION := 0.4

@onready var light: OmniLight3D = $Light
@onready var flash: MeshInstance3D = $Flash
@onready var shockwave: MeshInstance3D = $Shockwave
@onready var sparks: CPUParticles3D = $Sparks

var _flash_material: StandardMaterial3D
var _wave_material: StandardMaterial3D
var _flash_alpha: float
var _wave_alpha: float
var _light_energy: float

func _ready() -> void:
	# Own material per instance so simultaneous flashes fade independently.
	_flash_material = flash.material_override.duplicate()
	flash.material_override = _flash_material
	_wave_material = shockwave.material_override.duplicate()
	shockwave.material_override = _wave_material
	_flash_alpha = _flash_material.albedo_color.a
	_wave_alpha = _wave_material.albedo_color.a
	_light_energy = light.light_energy
	light.visible = false

func play(full: bool = true) -> void:
	light.visible = full and light_on
	shockwave.visible = full
	if full:
		sparks.restart()
		sparks.emitting = true
	_run(maxf(DURATION, SHOCKWAVE_DURATION), _update)

func _update(progress: float) -> void:
	var total := maxf(DURATION, SHOCKWAVE_DURATION)
	var flash_t := minf(progress * total / DURATION, 1.0)
	flash.scale = Vector3.ONE * lerpf(0.4, 1.6, sin(flash_t * PI * 0.5))
	_flash_material.albedo_color.a = _flash_alpha * (1.0 - flash_t)
	light.light_energy = _light_energy * (1.0 - flash_t)
	if shockwave.visible:
		var wave_t := minf(progress * total / SHOCKWAVE_DURATION, 1.0)
		shockwave.scale = Vector3.ONE * lerpf(0.3, 2.2, sin(wave_t * PI * 0.5))
		_wave_material.albedo_color.a = _wave_alpha * (1.0 - wave_t)

func _reset() -> void:
	sparks.emitting = false
	light.visible = false
