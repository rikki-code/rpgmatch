## Wires generation params -> BoardGraph -> TurnManager -> view together.
## This is the only place that knows about all the modules at once.
class_name GameRoot
extends Node3D

@export var world_gen_params: WorldGenParams

var board: BoardGraph
var ctx: TurnContext
var turn_manager: TurnManager
var swap_controller: SwapController

func _ready() -> void:
	var params := world_gen_params if world_gen_params != null else WorldGenParams.new()
	board = BoardGenerator.generate(params)

	ctx = TurnContext.new(board)
	ctx.resolver = EffectResolver.new(board)
	swap_controller = SwapController.new(ctx)

	var phases: Array[TurnPhase] = [
		PhasePlayerInput.new(),
		PhaseEnvironmentStub.new(),
		PhaseEnemyStub.new(),
		PhasePhysicsResolve.new(),
	]
	turn_manager = TurnManager.new(ctx, phases)
	ctx.turn_manager = turn_manager

	var board_view: BoardView3D = $BoardView3D
	board_view.setup(board)
	ctx.animation_driver = BoardViewAnimationDriver.new(board_view)
	ctx.resolver.effect_applied.connect(func(effect: Effect) -> void: board_view.refresh(effect))
	swap_controller.swap_applied.connect(func(_a: GridCell, _b: GridCell) -> void: board_view.refresh())
	swap_controller.swap_rejected.connect(func(_a: GridCell, _b: GridCell) -> void: board_view.refresh())

	var camera: Camera3D = $Camera3D
	_place_camera(camera)
	get_tree().root.size_changed.connect(func() -> void: _place_camera(camera))

	var input_controller: InputController = $InputController
	input_controller.setup(camera, board_view, board, swap_controller)

	turn_manager.start()

const CAMERA_HEIGHT := 15.0
const CAMERA_TILT_DEGREES := 5.0
const CAMERA_MARGIN := 2.0

func _place_camera(camera: Camera3D) -> void:
	var cell_size := BoardView3D.CELL_SIZE
	var center := Vector3((board.width - 1) * 0.5 * cell_size, 0.0, (board.height - 1) * 0.5 * cell_size)
	# Tilted `CAMERA_TILT_DEGREES` off straight-down: solve where a ray from
	# the camera actually lands on the ground (y=0) and shift the camera by
	# the same amount so that point is the board center, not just an
	# approximation — an earlier version had this offset backwards, which
	# pushed the look-at point off-center instead of correcting for it.
	var theta := deg_to_rad(-90.0 + CAMERA_TILT_DEGREES)
	var ground_offset := CAMERA_HEIGHT * cos(theta) / sin(theta)
	camera.position = center + Vector3(0.0, CAMERA_HEIGHT, -ground_offset)
	camera.rotation_degrees = Vector3(-90.0 + CAMERA_TILT_DEGREES, 0, 0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT

	# `size` under KEEP_HEIGHT only guarantees vertical fit; a narrow window
	# would otherwise clip board width, so also solve for the size that
	# makes the (size * aspect) horizontal span cover the board.
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect: float = viewport_size.x / viewport_size.y if viewport_size.y > 0 else 1.0
	var needed_height := board.height * BoardView3D.CELL_SIZE + CAMERA_MARGIN
	var needed_width := board.width * BoardView3D.CELL_SIZE + CAMERA_MARGIN
	camera.size = maxf(needed_height, needed_width / aspect)
