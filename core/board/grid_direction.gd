class_name GridDirection
extends RefCounted

enum Dir { UP, DOWN, LEFT, RIGHT }

const OFFSETS := {
	Dir.UP: Vector2i(0, -1),
	Dir.DOWN: Vector2i(0, 1),
	Dir.LEFT: Vector2i(-1, 0),
	Dir.RIGHT: Vector2i(1, 0),
}

const ALL := [Dir.UP, Dir.DOWN, Dir.LEFT, Dir.RIGHT]

static func opposite(dir: Dir) -> Dir:
	match dir:
		Dir.UP:
			return Dir.DOWN
		Dir.DOWN:
			return Dir.UP
		Dir.LEFT:
			return Dir.RIGHT
		Dir.RIGHT:
			return Dir.LEFT
	return dir
