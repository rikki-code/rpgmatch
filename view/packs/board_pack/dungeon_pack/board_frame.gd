## Stone frame with gold trim and corner braziers; the flames flicker on their own.
extends BoardDecor

const THICKNESS := 0.42
const BEAM_HEIGHT := 0.46
const BEAM_Y := -0.12
const TRIM_WIDTH := 0.06
const TRIM_HEIGHT := 0.04

func fit(width: int, height: int) -> void:
	var size := Vector2(width, height)
	var center := Vector2(size.x - 1.0, size.y - 1.0) * 0.5
	var outer := size + Vector2.ONE * THICKNESS * 2.0
	var edge := THICKNESS * 0.5
	_place($Beams/Top, Vector3(center.x, BEAM_Y, center.y - size.y * 0.5 - edge), Vector3(outer.x, BEAM_HEIGHT, THICKNESS))
	_place($Beams/Bottom, Vector3(center.x, BEAM_Y, center.y + size.y * 0.5 + edge), Vector3(outer.x, BEAM_HEIGHT, THICKNESS))
	_place($Beams/Left, Vector3(center.x - size.x * 0.5 - edge, BEAM_Y, center.y), Vector3(THICKNESS, BEAM_HEIGHT, size.y))
	_place($Beams/Right, Vector3(center.x + size.x * 0.5 + edge, BEAM_Y, center.y), Vector3(THICKNESS, BEAM_HEIGHT, size.y))

	var trim_y := BEAM_Y + BEAM_HEIGHT * 0.5 + TRIM_HEIGHT * 0.5
	var inner_offset := size * 0.5 + Vector2.ONE * (TRIM_WIDTH * 0.5)
	_place($Trims/Top, Vector3(center.x, trim_y, center.y - inner_offset.y), Vector3(size.x + TRIM_WIDTH * 2.0, TRIM_HEIGHT, TRIM_WIDTH))
	_place($Trims/Bottom, Vector3(center.x, trim_y, center.y + inner_offset.y), Vector3(size.x + TRIM_WIDTH * 2.0, TRIM_HEIGHT, TRIM_WIDTH))
	_place($Trims/Left, Vector3(center.x - inner_offset.x, trim_y, center.y), Vector3(TRIM_WIDTH, TRIM_HEIGHT, size.y))
	_place($Trims/Right, Vector3(center.x + inner_offset.x, trim_y, center.y), Vector3(TRIM_WIDTH, TRIM_HEIGHT, size.y))

	var post_x := size.x * 0.5 + THICKNESS * 0.5
	var post_z := size.y * 0.5 + THICKNESS * 0.5
	$Braziers/TopLeft.position = Vector3(center.x - post_x, 0.0, center.y - post_z)
	$Braziers/TopRight.position = Vector3(center.x + post_x, 0.0, center.y - post_z)
	$Braziers/BottomLeft.position = Vector3(center.x - post_x, 0.0, center.y + post_z)
	$Braziers/BottomRight.position = Vector3(center.x + post_x, 0.0, center.y + post_z)

func _ready() -> void:
	for brazier in $Braziers.get_children():
		_flicker(brazier.get_node("Flame"))

func _place(node: Node3D, at: Vector3, size: Vector3) -> void:
	node.position = at
	node.scale = size

# Each flame gets its own pace so the four never pulse together.
func _flicker(flame: Node3D) -> void:
	var tween := flame.create_tween().set_loops()
	var pace := randf_range(0.12, 0.2)
	for i in range(4):
		var stretch := Vector3(randf_range(0.85, 1.1), randf_range(0.8, 1.3), randf_range(0.85, 1.1))
		tween.tween_property(flame, "scale", stretch, pace).set_trans(Tween.TRANS_SINE)
