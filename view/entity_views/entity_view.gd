## Per-entity-type visual recipe: how a BoardEntity subtype builds its mesh
## and plays its own spawn/move/destroy animations. BoardView3D only decides
## *when* to call these (new entity vs moved vs gone) — it never hardcodes
## what an animation looks like for a given entity type. A new BoardEntity
## subclass (rock, enemy...) gets a new EntityView subclass, not a branch
## here or in BoardView3D.
class_name EntityView
extends RefCounted

func build_node(_entity: BoardEntity) -> Node3D:
	return null

## Entity just appeared on the board. `start` is where BoardView3D wants it
## placed before animating in (e.g. one or more cells above its target, so a
## batch of new tiles reads as one continuous fall together with whatever
## is already falling into the same column) — not a fixed drop height, so
## it lines up exactly with the rest of the cascade instead of overlapping
## it. `owner_node` is only used to open a Tween (needs a live scene node).
func play_spawn(_node: Node3D, _start: Vector3, _target: Vector3, _owner_node: Node) -> Tween:
	return null

## Entity is already on the board and moved to a new cell (fall, swap-settle).
func play_move(_node: Node3D, _target: Vector3, _owner_node: Node) -> Tween:
	return null

## Entity left the board (matched, destroyed...). Must eventually call
## `on_complete` (typically frees the node) once the animation is done.
func play_destroy(_node: Node3D, _owner_node: Node, _on_complete: Callable) -> Tween:
	return null
