## Cell <-> world mapping of the board, shared by the board view and input.
class_name BoardGeometry
extends RefCounted

const CELL_SIZE := GeometryConstants.CELL_SIZE
const TILE_LIFT := 0.35

static func cell_to_world(pos: Vector2i) -> Vector3:
	return Vector3(pos.x * CELL_SIZE, 0.0, pos.y * CELL_SIZE)

static func lifted_world(pos: Vector2i) -> Vector3:
	return cell_to_world(pos) + Vector3.UP * TILE_LIFT

static func world_to_cell(world_pos: Vector3) -> Vector2i:
	return Vector2i(roundi(world_pos.x / CELL_SIZE), roundi(world_pos.z / CELL_SIZE))

# Where a screen point hits the ground plane (y = 0).
static func ground_plane_point(camera: Camera3D, screen_pos: Vector2) -> Vector3:
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var denom := dir.y if absf(dir.y) > 0.0001 else 0.0001
	var t := -from.y / denom
	return from + dir * t
