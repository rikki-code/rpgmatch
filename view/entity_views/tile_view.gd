## Visual recipe for Tile: colored sphere, shrink-to-zero destroy, and the
## same plain fall for everything else — a brand new tile is just a fall
## that starts higher up (from the empty space above the board), not a
## separate "spawn in place" animation. That's what makes a freshly-spawned
## tile read as "falling in" instead of "popping into existence".
class_name TileView
extends EntityView

const CELL_SIZE := 1.0
## Constant speed, not constant duration: a short settle (1 cell) and a long
## spawn-fall (a whole board height) must move at the same pace, or they
## visibly play back at different speeds and the cascade looks disjointed.
const CELLS_PER_SECOND := 7.0
const MIN_FALL_TIME := 0.12
const DESTROY_TIME := 0.52

var tile_colors: Array[Color] = [
	Color.CRIMSON, Color.ORANGE, Color.GOLD, Color.SEA_GREEN, Color.ROYAL_BLUE, Color.MEDIUM_PURPLE,
]

func build_node(entity: BoardEntity) -> Node3D:
	var tile: Tile = entity
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = CELL_SIZE * 0.38
	sphere.height = CELL_SIZE * 0.76
	node.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = tile_colors[tile.color % tile_colors.size()]
	material.metallic = 0.35
	material.roughness = 0.25
	material.rim_enabled = true
	material.rim = 0.4
	node.material_override = material
	return node

func play_spawn(node: Node3D, start: Vector3, target: Vector3, owner_node: Node) -> Tween:
	node.position = start
	return play_move(node, target, owner_node)

func play_move(node: Node3D, target: Vector3, owner_node: Node) -> Tween:
	node.scale = Vector3.ONE
	var duration := _fall_duration(node.position, target)
	var tween := owner_node.create_tween()
	tween.tween_property(node, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tween

func play_destroy(node: Node3D, owner_node: Node, on_complete: Callable) -> Tween:
	var tween := owner_node.create_tween()
	tween.tween_property(node, "scale", Vector3.ZERO, DESTROY_TIME)
	tween.tween_callback(on_complete)
	return tween

func _fall_duration(from: Vector3, to: Vector3) -> float:
	var distance_cells := from.distance_to(to) / CELL_SIZE
	return maxf(distance_cells / CELLS_PER_SECOND, MIN_FALL_TIME)
