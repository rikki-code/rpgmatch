## Visual recipe for Tile: colored sphere, shrink-to-zero destroy, and the
## same plain fall for everything else — a brand new tile is just a fall
## that starts higher up (from the empty space above the board), not a
## separate "spawn in place" animation. That's what makes a freshly-spawned
## tile read as "falling in" instead of "popping into existence".
class_name TileView
extends EntityView

## Mesh/material/marker-geometry for a tile live in these scenes (edit them
## in the Godot editor, not here) — this script only ever sets the one
## per-instance thing a .tscn can't know ahead of time: which of the 6
## colors a given tile is.
const DEFAULT_SCENE := preload("res://view/entity_views/tile.tscn")
## Keyed by Tile.visual_kind() (a semantic tag, not a scene reference — core
## doesn't know about view/.tscn). Add an entry here for any future
## TileBehavior that overrides visual_kind(); tags with no entry fall back
## to DEFAULT_SCENE.
const SCENES_BY_VISUAL_KIND := {
	&"bomb": preload("res://view/entity_views/tile_bomb.tscn"),
}

const CELL_SIZE := 1.0
## Must match the SphereMesh radius baked into tile.tscn/tile_bomb.tscn —
## InputController needs this number for its drag-clamp math and has no
## other way to ask a .tscn for it.
const RADIUS := CELL_SIZE * 0.38
## Constant speed, not constant duration: a short settle (1 cell) and a long
## spawn-fall (a whole board height) must move at the same pace, or they
## visibly play back at different speeds and the cascade looks disjointed.
const CELLS_PER_SECOND := 7.0
const DESTROY_TIME := 0.52

var tile_colors: Array[Color] = [
	Color.CRIMSON, Color.ORANGE, Color.GOLD, Color.SEA_GREEN, Color.ROYAL_BLUE, Color.MEDIUM_PURPLE,
]

func build_node(entity: BoardEntity) -> Node3D:
	var tile: Tile = entity
	var scene: PackedScene = SCENES_BY_VISUAL_KIND.get(tile.visual_kind(), DEFAULT_SCENE)
	var node: Node3D = scene.instantiate()
	var mesh: MeshInstance3D = node.get_node("Mesh")
	# Duplicate so each tile gets its own color without repainting every
	# other tile sharing the same .tres material resource.
	var material: StandardMaterial3D = mesh.get_surface_override_material(0).duplicate()
	material.albedo_color = tile.visual_color if tile.visual_color != null else tile_colors[tile.color % tile_colors.size()]
	mesh.set_surface_override_material(0, material)
	return node

func play_spawn(node: Node3D, start: Vector3, reveal: Vector3, target: Vector3, owner_node: Node) -> Tween:
	node.position = start
	node.scale = Vector3.ONE
	node.visible = false
	var tween := owner_node.create_tween()
	var hidden_distance := start.distance_to(reveal) / CELL_SIZE
	if hidden_distance > 0.001:
		# No easing/min-duration floor here: it's invisible, only the total
		# elapsed time (this + the visible leg) matters for staying in sync
		# with the rest of the batch.
		tween.tween_property(node, "position", reveal, hidden_distance / CELLS_PER_SECOND)
	else:
		node.position = reveal
	tween.tween_callback(func() -> void: node.visible = true)
	tween.tween_property(node, "position", target, _fall_duration(reveal, target)).set_trans(Tween.TRANS_LINEAR)
	return tween

func play_move(node: Node3D, target: Vector3, owner_node: Node) -> Tween:
	node.scale = Vector3.ONE

	node.visible = true
	var duration := _fall_duration(node.position, target)
	var tween := owner_node.create_tween()

	tween.tween_property(node, "position", target, duration).set_trans(Tween.TRANS_LINEAR)
	return tween

func play_destroy(node: Node3D, owner_node: Node, on_complete: Callable) -> Tween:
	var tween := owner_node.create_tween()
	tween.tween_property(node, "scale", Vector3.ZERO, DESTROY_TIME)
	tween.tween_callback(on_complete)
	return tween

func _fall_duration(from: Vector3, to: Vector3) -> float:
	var distance_cells := from.distance_to(to) / CELL_SIZE
	return distance_cells / CELLS_PER_SECOND
