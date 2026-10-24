## Pooled one-shot flash VFX (see VfxPool): position it, call play(); `full`
## adds shockwave, sparks and a light, a plain flash is the cheap variant.
## Layers (all additive): white-hot core, orange fireball (Flash), soft halo.
class_name TileExplosion
extends Vfx

const DURATION := 0.3
const SHOCKWAVE_DURATION := 0.4

@onready var light: OmniLight3D = $Light
@onready var flash: MeshInstance3D = $Flash
@onready var core: MeshInstance3D = $Core
@onready var halo: MeshInstance3D = $Halo
@onready var shockwave: MeshInstance3D = $Shockwave
@onready var sparks: CPUParticles3D = $Sparks

var _flash_material: StandardMaterial3D
var _core_material: StandardMaterial3D
var _halo_material: StandardMaterial3D
var _wave_material: StandardMaterial3D
var _flash_alpha: float
var _core_alpha: float
var _halo_alpha: float
var _wave_alpha: float
var _light_energy: float

func _ready() -> void:
	# Own material per instance so simultaneous flashes fade independently.
	_flash_material = flash.material_override.duplicate()
	flash.material_override = _flash_material
	_core_material = core.material_override.duplicate()
	core.material_override = _core_material
	_halo_material = halo.material_override.duplicate()
	halo.material_override = _halo_material
	_wave_material = shockwave.material_override.duplicate()
	shockwave.material_override = _wave_material
	_flash_alpha = _flash_material.albedo_color.a
	_core_alpha = _core_material.albedo_color.a
	_halo_alpha = _halo_material.albedo_color.a
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
	var grow := sin(flash_t * PI * 0.5)
	var fade := 1.0 - flash_t
	flash.scale = Vector3.ONE * lerpf(0.4, 1.6, grow)
	core.scale = Vector3.ONE * lerpf(0.3, 0.8, grow)
	halo.scale = Vector3.ONE * lerpf(0.8, 2.4, grow)
	_flash_material.albedo_color.a = _flash_alpha * fade
	_core_material.albedo_color.a = _core_alpha * fade
	_halo_material.albedo_color.a = _halo_alpha * fade
	light.light_energy = _light_energy * fade
	if shockwave.visible:
		var wave_t := minf(progress * total / SHOCKWAVE_DURATION, 1.0)
		shockwave.scale = Vector3.ONE * lerpf(0.3, 2.4, sin(wave_t * PI * 0.5))
		_wave_material.albedo_color.a = _wave_alpha * (1.0 - wave_t)

func _reset() -> void:
	sparks.emitting = false
	light.visible = false
