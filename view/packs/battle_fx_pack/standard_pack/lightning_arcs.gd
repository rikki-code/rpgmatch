## Jagged lightning arcs from the origin outward, re-rolled every frame.
extends Node2D

const SEGMENTS := 6

@export var count := 3
@export var reach := 34.0
@export var start_radius := 10.0
var color := Color.WHITE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	for i in range(count):
		var direction := Vector2.from_angle(randf() * TAU)
		var length := reach * randf_range(0.6, 1.0)
		var points := PackedVector2Array()
		for s in range(SEGMENTS + 1):
			var t := float(s) / SEGMENTS
			var jitter := direction.orthogonal() * randf_range(-1.0, 1.0) * length * 0.18 * sin(t * PI)
			points.append(direction * (start_radius + length * t) + jitter)
		draw_polyline(points, Color(color, 0.55), 5.0, true)
		draw_polyline(points, Color.WHITE.lerp(color, 0.25), 1.6, true)
