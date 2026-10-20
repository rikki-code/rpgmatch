## Per-entity-type visual recipe: builds the node and plays its destroy
## animation. A new BoardEntity subclass gets a new EntityView, not a branch in
## BoardView3D, which owns the generic spawn, fall and slide.
class_name EntityView
extends RefCounted

func build_node(_entity: BoardEntity) -> Node3D:
	return null

## Must call `on_complete` once the animation is done.
func play_destroy(_node: Node3D, _owner_node: Node, _on_complete: Callable) -> Tween:
	return null

func release_node(node: Node3D) -> void:
	node.queue_free()

## Drops pooled nodes: the view is being replaced (new pack).
func dispose() -> void:
	pass

func set_highlighted(_node: Node3D, _on: bool) -> void:
	pass
