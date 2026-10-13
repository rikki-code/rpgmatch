## Magic projectile impact: soft colored flash swelling out, shockwave ring,
## a splash of glowing orbs braking to a stop, then motes drifting up. Frees
## itself. `power` 0..1 scales size, orb count/speed and mote count.
extends Node2D

const SECONDS := 0.7

@onready var _glow: Sprite2D = $Glow
@onready var _wave: ColorRect = $Wave
@onready var _splash: CPUParticles2D = $Splash
@onready var _motes: CPUParticles2D = $Motes

func play(color: Color, power: float) -> void:
	var size := lerpf(0.55, 1.6, power)
	_glow.scale *= size
	_wave.scale = Vector2.ONE * size
	_wave.pivot_offset = _wave.size / 2.0
	_splash.amount = roundi(lerpf(14.0, 64.0, power))
	_splash.initial_velocity_min *= size
	_splash.initial_velocity_max *= size
	_motes.amount = roundi(lerpf(6.0, 30.0, power))
	var wave_material := _wave.material as ShaderMaterial
	wave_material.set_shader_parameter("energy_color", color)
	_glow.self_modulate = color.lightened(0.25)
	_splash.color = color.lightened(0.35)
	_motes.color = color.lightened(0.55)
	_splash.emitting = true
	_motes.emitting = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_glow, "scale", Vector2.ONE * 1.3 * size, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_glow, "modulate:a", 0.0, 0.45).set_delay(0.08)
	tween.tween_method(func(p: float) -> void: wave_material.set_shader_parameter("progress", p), 0.0, 1.0, SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(_motes.lifetime)
	tween.chain().tween_callback(queue_free)
