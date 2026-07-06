## Visual recipe for Tile: crystal shape (or bomb), shrink-to-zero destroy, plain fall otherwise.
class_name TileView
extends EntityView

## Mesh/material live in these scenes, edited in the editor. Keyed by
## Tile.visual_kind(); no entry falls back to TILE_SCENES_BY_COLOR.
static var SCENES_BY_VISUAL_KIND: Dictionary
## Plain color tile picks shape by Tile.color, unrelated to visual_kind().
static var TILE_SCENES_BY_COLOR: Array[PackedScene]
## Loaded from the pack's tile_colors.tres — see TileColorPalette.
static var TILE_COLORS: Array[Color]

static func _static_init() -> void:
	SCENES_BY_VISUAL_KIND = {
		&"bomb": load(PackPaths.SPECIAL_TILES_PACK + "tile_bomb.tscn"),
		&"arrow_blaster_row": load(PackPaths.SPECIAL_TILES_PACK + "tile_arrow_blaster.tscn"),
		&"arrow_blaster_column": load(PackPaths.SPECIAL_TILES_PACK + "tile_arrow_blaster.tscn"),
		&"arrow_blaster_both": load(PackPaths.SPECIAL_TILES_PACK + "tile_arrow_blaster.tscn"),
		&"prism": load(PackPaths.SPECIAL_TILES_PACK + "tile_prism.tscn"),
	}
	TILE_SCENES_BY_COLOR = [
		load(PackPaths.TILES_PACK + "tile_0.tscn"),
		load(PackPaths.TILES_PACK + "tile_1.tscn"),
		load(PackPaths.TILES_PACK + "tile_2.tscn"),
		load(PackPaths.TILES_PACK + "tile_3.tscn"),
		load(PackPaths.TILES_PACK + "tile_4.tscn"),
		load(PackPaths.TILES_PACK + "tile_5.tscn"),
	]
	var palette: TileColorPalette = load(PackPaths.TILES_PACK + "tile_colors.tres")
	TILE_COLORS = palette.colors

const CELL_SIZE := GeometryConstants.CELL_SIZE
## Safe general radius for InputController's drag clamp — crystal shapes vary a bit.
const RADIUS := GeometryConstants.DEFAULT_TILE_RADIUS
## Must match tile_material.tres's emission_energy_multiplier.
const BASE_EMISSION_ENERGY := 0.9
const HIGHLIGHT_EMISSION_ENERGY := 3.2
## Same pace for short settles and long spawn-falls, or the cascade looks disjointed.
const CELLS_PER_SECOND := 7.0
const DESTROY_TIME := 0.52
## Fuse-catch beat before a bomb's node shrinks away.
const IGNITE_TIME := 0.15
## Windup beat before a prism's node hides and its blast fires.
const SPIN_TIME := 0.45

func build_node(entity: BoardEntity) -> Node3D:
	var tile: Tile = entity
	var visual_kind := tile.visual_kind()
	var scene: PackedScene = SCENES_BY_VISUAL_KIND.get(visual_kind)
	if scene == null:
		scene = TILE_SCENES_BY_COLOR[tile.color % TILE_SCENES_BY_COLOR.size()]
	var node: Node3D = scene.instantiate()
	node.set_meta(&"visual_kind", visual_kind)

	# Row/column arrow blasters share one asset; column just turns it 90°
	# to point across the other axis (see ArrowBlasterCore.Axis). BOTH (only
	# reachable by combining two arrow blasters) layers a second copy of the
	# same asset, turned 90°, on top instead of needing its own authored
	# cross-shaped scene — a plus made out of the two single arrows.
	if visual_kind == &"arrow_blaster_column":
		node.rotate_y(PI / 2.0)
	elif visual_kind == &"arrow_blaster_both":
		var cross_arm: Node3D = SCENES_BY_VISUAL_KIND[&"arrow_blaster_row"].instantiate()
		cross_arm.rotate_y(PI / 2.0)
		node.add_child(cross_arm)

	if visual_kind == &"prism":
		_paint_prism_balls(node)

	var color: Variant = tile.visual_color
	if color == null and tile.color >= 0:
		color = TILE_COLORS[tile.color % TILE_COLORS.size()]
	if color == null:
		return node

	var mesh: MeshInstance3D = node.get_node("Mesh")
	# Duplicate so each tile gets its own color without repainting every
	# other tile sharing the same .tres material resource.
	var material: StandardMaterial3D = mesh.get_surface_override_material(0).duplicate()
	material.albedo_color = Color(color.r, color.g, color.b, material.albedo_color.a)
	if material.emission_enabled:
		material.emission = color
	mesh.set_surface_override_material(0, material)
	return node

## Colors each ColorBallN marker from the active pack's palette, same
## duplicate-then-override pattern as the per-tile Mesh above — the balls
## aren't one-per-tile-instance colored, but they must still track whichever
## pack is currently active (see PackPaths.TILES_PACK), not a baked-in look.
func _paint_prism_balls(node: Node3D) -> void:
	for i in range(TILE_COLORS.size()):
		var ball: MeshInstance3D = node.get_node_or_null("ColorBall%d" % i)
		if ball == null:
			continue
		var material: StandardMaterial3D = ball.get_surface_override_material(0).duplicate()
		material.albedo_color = TILE_COLORS[i]
		if material.emission_enabled:
			material.emission = TILE_COLORS[i]
		ball.set_surface_override_material(0, material)

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
		tween.tween_callback(func() -> void: node.visible = true)
	else:
		node.position = reveal
		node.visible = true
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
	match node.get_meta(&"visual_kind", &"") as StringName:
		&"bomb":
			# Fuse catches, then pops instantly — no lingering shrink with a lit fuse.
			_ignite_fuse(node, tween)
			tween.tween_callback(func() -> void: node.visible = false)
		&"prism":
			# Spins up in place, then vanishes instantly — no shrink, its blast is about to fire.
			_spin_up(node, tween)
			tween.tween_callback(func() -> void: node.visible = false)
		_:
			tween.tween_property(node, "scale", Vector3.ZERO, DESTROY_TIME)
	tween.tween_callback(on_complete)
	return tween

func _spin_up(node: Node3D, tween: Tween) -> void:
	tween.tween_property(node, "rotation:y", node.rotation.y + TAU * 3.0, SPIN_TIME).set_trans(Tween.TRANS_LINEAR)

## Purely cosmetic — flares Spark/SparkLight (tile_bomb.tscn), doesn't touch detonation timing.
func _ignite_fuse(node: Node3D, tween: Tween) -> void:
	var spark: MeshInstance3D = node.get_node("Spark")
	var light: OmniLight3D = node.get_node("SparkLight")
	spark.visible = true
	tween.set_parallel(true)
	tween.tween_property(spark, "scale", Vector3.ONE * 1.6, IGNITE_TIME)
	tween.tween_property(light, "light_energy", 3.0, IGNITE_TIME)
	tween.set_parallel(false)

## Emission alone washes out on faces catching full direct light (e.g. tile_crystal_2's flat top);
## scale pulse keeps it visible regardless of shape.
const HIGHLIGHT_SCALE := 1.18

func set_highlighted(node: Node3D, on: bool) -> void:
	var mesh: MeshInstance3D = node.get_node_or_null("Mesh")
	if mesh == null:
		return
	var material: StandardMaterial3D = mesh.get_surface_override_material(0)
	if material == null:
		return
	var existing: Tween = node.get_meta(&"highlight_tween") if node.has_meta(&"highlight_tween") else null
	if existing != null and existing.is_valid():
		existing.kill()
	# Cached once so meshes with their own baked scale (e.g. tile_crystal_3) don't reset to Vector3.ONE.
	var base_scale: Vector3 = node.get_meta(&"highlight_base_scale") if node.has_meta(&"highlight_base_scale") else mesh.scale
	node.set_meta(&"highlight_base_scale", base_scale)
	if not on:
		node.remove_meta(&"highlight_tween")
		material.emission_energy_multiplier = BASE_EMISSION_ENERGY
		mesh.scale = base_scale
		return
	# .parallel() is one-shot per tweener; chain()+set_parallel(true) collapsed both phases into one.
	var tween := node.create_tween()
	tween.set_loops()
	tween.tween_property(material, "emission_energy_multiplier", HIGHLIGHT_EMISSION_ENERGY, 0.35).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(mesh, "scale", base_scale * HIGHLIGHT_SCALE, 0.35).set_trans(Tween.TRANS_SINE)
	tween.tween_property(material, "emission_energy_multiplier", BASE_EMISSION_ENERGY, 0.35).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(mesh, "scale", base_scale, 0.35).set_trans(Tween.TRANS_SINE)
	node.set_meta(&"highlight_tween", tween)

func _fall_duration(from: Vector3, to: Vector3) -> float:
	var distance_cells := from.distance_to(to) / CELL_SIZE
	return distance_cells / CELLS_PER_SECOND
