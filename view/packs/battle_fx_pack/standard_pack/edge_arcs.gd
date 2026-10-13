## Occasional small sparks jumping off `rect`'s edge (an accent, not the
## main look); `intensity` 0..1 scales how often and how far.
extends Node2D

var color := Color.WHITE
var rect := Rect2()
var intensity := 0.0

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if intensity <= 0.0:
		return
	for i in range(3):
		if randf() > intensity * 0.12:
			continue
		var start := _point_on_edge()
		var outward := (start - rect.get_center()).normalized()
		var length := randf_range(6.0, 18.0) * (0.5 + intensity)
		var points := PackedVector2Array([start])
		for s in range(1, 6):
			var t := s / 5.0
			var jitter := outward.orthogonal() * randf_range(-1.0, 1.0) * length * 0.35
			points.append(start + outward * length * t + jitter * sin(t * PI))
		draw_polyline(points, Color(color, 0.6), 4.0, true)
		draw_polyline(points, Color.WHITE.lerp(color, 0.2), 1.4, true)

func _point_on_edge() -> Vector2:
	var at := randf() * 2.0 * (rect.size.x + rect.size.y)
	if at < rect.size.x:
		return rect.position + Vector2(at, 0.0)
	at -= rect.size.x
	if at < rect.size.y:
		return rect.position + Vector2(rect.size.x, at)
	at -= rect.size.y
	if at < rect.size.x:
		return rect.position + Vector2(rect.size.x - at, rect.size.y)
	return rect.position + Vector2(0.0, rect.size.y - (at - rect.size.x))
