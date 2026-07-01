## Procedural generation knobs. allow_enemies/allow_penalties are wired
## ahead of the mechanics that will use them (see docs/plan.md) so
## BoardGenerator already has a place to check them once those exist.
class_name WorldGenParams
extends Resource

@export var width: int = 8
@export var height: int = 8
@export var color_count: int = 5
@export var pit_count: int = 2
@export var seed_value: int = 0
@export var difficulty: int = 1
@export var allow_enemies: bool = false
@export var allow_penalties: bool = false
