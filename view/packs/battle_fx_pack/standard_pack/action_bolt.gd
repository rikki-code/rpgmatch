## Plasma bolt flying actor → target on an arc: shader orb, crackling arcs,
## spark stream, streaming trail (top-level, world coords). Emits `landed`
## on arrival, then fades its trail and frees itself. `power` 0..1 scales
## orb, arcs, trail width and spark count.
extends Node2D

signal landed

const ARC_HEIGHT := 90.0
## How long the trail streams behind the orb (seconds, so it looks the same at any frame rate).
const TRAIL_SECONDS := 0.65

@onready var _orb: ColorRect = $Orb
@onready var _arcs: Node2D = $Arcs
@onready var _sparks: CPUParticles2D = $Sparks
@onready var _trail: Line2D = $Trail
var _flying := false
var _age := 0.0
var _point_ages: Array[float] = []

func launch(start: Vector2, end: Vector2, color: Color, seconds: float, power: float) -> void:
	var size := lerpf(0.6, 1.5, power)
	_orb.scale = Vector2.ONE * size
	_orb.pivot_offset = _orb.size / 2.0
	_arcs.scale = Vector2.ONE * size
	_trail.width *= size
	_sparks.amount = roundi(lerpf(10.0, 40.0, power))
	(_orb.material as ShaderMaterial).set_shader_parameter("energy_color", color)
	(_trail.material as ShaderMaterial).set_shader_parameter("energy_color", color)
	_arcs.color = color
	_sparks.color = color.lightened(0.3)
	position = start
	_trail.clear_points()
	_point_ages.clear()
	_flying = true
	_sparks.emitting = true
	var bend := (end - start).orthogonal().normalized() * ARC_HEIGHT
	var control := start.lerp(end, 0.5) + (bend if bend.y < 0.0 else -bend)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void: position = _bezier(start, control, end, t), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(_land)

func _process(delta: float) -> void:
	if not _flying:
		return
	_age += delta
	_trail.add_point(global_position)
	_point_ages.append(_age)
	while _age - _point_ages[0] > TRAIL_SECONDS:
		_trail.remove_point(0)
		_point_ages.remove_at(0)

func _land() -> void:
	_flying = false
	_orb.visible = false
	_arcs.visible = false
	_sparks.emitting = false
	landed.emit()
	var fade := create_tween()
	fade.tween_property(_trail, "modulate:a", 0.0, 0.2)
	fade.tween_interval(_sparks.lifetime)
	fade.tween_callback(queue_free)

static func _bezier(a: Vector2, control: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(control, t).lerp(control.lerp(b, t), t)
