## Log fence with corner posts and warm lanterns; the lanterns breathe on their own.
extends BoardDecor

const LOG_RADIUS := 0.2
const LOG_Y := -0.05

func fit(width: int, height: int) -> void:
	var size := Vector2(width, height)
	var center := (size - Vector2.ONE) * 0.5
	var half := size * 0.5 + Vector2.ONE * LOG_RADIUS
	_log($Logs/Top, Vector3(center.x, LOG_Y, center.y - half.y), size.x + LOG_RADIUS * 2.0, true)
	_log($Logs/Bottom, Vector3(center.x, LOG_Y, center.y + half.y), size.x + LOG_RADIUS * 2.0, true)
	_log($Logs/Left, Vector3(center.x - half.x, LOG_Y, center.y), size.y, false)
	_log($Logs/Right, Vector3(center.x + half.x, LOG_Y, center.y), size.y, false)

	$Posts/TopLeft.position = Vector3(center.x - half.x, 0.0, center.y - half.y)
	$Posts/TopRight.position = Vector3(center.x + half.x, 0.0, center.y - half.y)
	$Posts/BottomLeft.position = Vector3(center.x - half.x, 0.0, center.y + half.y)
	$Posts/BottomRight.position = Vector3(center.x + half.x, 0.0, center.y + half.y)

func _ready() -> void:
	for post in $Posts.get_children():
		_breathe(post.get_node("Glass"))

# Cylinder axis is local Y, so the length goes into scale.y before it is laid flat.
func _log(node: Node3D, at: Vector3, length: float, along_x: bool) -> void:
	node.position = at
	node.scale = Vector3(1.0, length, 1.0)
	node.rotation = Vector3(0.0, 0.0, PI * 0.5) if along_x else Vector3(PI * 0.5, 0.0, 0.0)

func _breathe(glass: Node3D) -> void:
	var tween := glass.create_tween().set_loops()
	var pace := randf_range(0.7, 1.1)
	tween.tween_property(glass, "scale", Vector3.ONE * 1.12, pace).set_trans(Tween.TRANS_SINE)
	tween.tween_property(glass, "scale", Vector3.ONE * 0.92, pace).set_trans(Tween.TRANS_SINE)
