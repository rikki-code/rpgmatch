## Wires generation params -> BoardGraph -> TurnManager -> view together.
## This is the only place that knows about all the modules at once.
class_name GameRoot
extends Node3D

@export var world_gen_params: WorldGenParams
@export var dev_mode: bool = false

var board: BoardGraph
var ctx: TurnContext
var turn_manager: TurnManager
var swap_controller: SwapController
var detonate_controller: DetonateController
var quest_manager: QuestManager
var current_mode: GameMode
var battle_mode := BattleMode.new()
var available_modes: Array[GameMode] = [InfiniteMode.new(), battle_mode]
var board_view: BoardView3D
var editor_mode_controller: EditorModeController
var score_hud: ScoreHud
var quest_hud: QuestHud
var battle_view: BattleView
var camera: Camera3D
var game_menu: GameMenu
## Mode chosen mid-turn, applied once the turn manager parks (see switch_mode).
var _pending_mode: GameMode

func _ready() -> void:
	if GameSession.params == null:
		GameSession.params = world_gen_params.duplicate() if world_gen_params != null else WorldGenParams.new()
	board = BoardGenerator.generate(GameSession.params)

	ctx = TurnContext.new(board)
	ctx.resolver = EffectResolver.new(board)
	ctx.score_tracker = ScoreTracker.new(ctx.resolver)
	swap_controller = SwapController.new(ctx)
	ctx.swap_controller = swap_controller
	detonate_controller = DetonateController.new(ctx)
	ctx.detonate_controller = detonate_controller

	quest_manager = QuestManager.new(board, ctx.resolver, RandomQuestGenerator.new())
	quest_manager.fill_from_generator()
	quest_manager.quest_completed.connect(func(quest: QuestProgress) -> void:
		ctx.score_tracker.award_bonus(quest.definition.target_count * QUEST_REWARD_PER_TILE)
	)

	board_view = $BoardView3D
	board_view.setup(board)
	ctx.animation_driver = BoardViewAnimationDriver.new(board_view)
	ctx.resolver.effect_applied.connect(func(effect: Effect) -> void: board_view.refresh(effect))
	swap_controller.swap_applied.connect(func(_a: GridCell, _b: GridCell) -> void: _after_board_move())
	swap_controller.swap_rejected.connect(func(_a: GridCell, _b: GridCell) -> void: board_view.refresh())
	swap_controller.tiles_combined.connect(func(_a: GridCell, _b: GridCell) -> void: _after_board_move())
	detonate_controller.detonated.connect(func(_cell: GridCell) -> void: _after_board_move())

	camera = $Camera3D
	get_tree().root.size_changed.connect(_refit_camera)

	var input_controller: InputController = $InputController
	input_controller.setup(camera, board_view, board, swap_controller, detonate_controller)

	editor_mode_controller = $EditorModeController
	editor_mode_controller.setup(camera, board_view, ctx)
	var editor_grid_overlay: EditorGridOverlay = $EditorGridOverlay
	editor_grid_overlay.setup(board)
	var editor_toolbar: EditorToolbar = $UILayer/EditorToolbar

	editor_mode_controller.mode_changed.connect(func(active: bool) -> void:
		input_controller.set_editor_active(active)
		editor_grid_overlay.set_active(active)
		editor_toolbar.set_panel_visible(active)
		if active:
			editor_toolbar.setup(editor_mode_controller.cell_catalog, editor_mode_controller.tile_catalog, available_modes, current_mode)
	)
	editor_toolbar.cell_kind_selected.connect(editor_mode_controller.select_cell_kind)
	editor_toolbar.remove_cell_selected.connect(editor_mode_controller.select_remove_cell)
	editor_toolbar.tile_selected.connect(editor_mode_controller.select_tile)
	editor_toolbar.game_mode_selected.connect(switch_mode)

	var idle_throttle_controller: IdleThrottleController = $IdleThrottleController
	idle_throttle_controller.setup(ctx)

	var fps_counter: FpsCounter = $UILayer/FpsCounter
	fps_counter.set_active(dev_mode)

	score_hud = $UILayer/ScoreHud
	score_hud.setup(ctx.score_tracker)
	quest_hud = $UILayer/QuestHud
	quest_hud.setup(quest_manager)
	battle_view = $UILayer/BattleView
	battle_view.continue_requested.connect(func(victory: bool) -> void:
		if victory:
			GameSession.battle_level += 1
		_restart()
	)
	battle_view.exit_requested.connect(func() -> void: switch_mode(available_modes[0]))

	game_menu = $UILayer/GameMenu
	var mode_names: Array[String] = []
	for mode in available_modes:
		mode_names.append(mode.display_name())
	game_menu.setup(mode_names, GameSession.mode_index, GameSession.params)
	game_menu.editor_selected.connect(func() -> void:
		if not editor_mode_controller.active:
			editor_mode_controller.toggle()
		game_menu.show_selected(GameSession.mode_index, editor_mode_controller.active)
	)
	editor_mode_controller.mode_changed.connect(func(active: bool) -> void:
		game_menu.show_selected(GameSession.mode_index, active)
	)
	game_menu.mode_selected.connect(func(index: int) -> void: switch_mode(available_modes[index]))
	game_menu.settings_applied.connect(func(params: WorldGenParams) -> void:
		GameSession.params = params
		_restart()
	)
	game_menu.reset_requested.connect(_restart)
	game_menu.quit_requested.connect(func() -> void: get_tree().quit())

	_apply_mode(available_modes[GameSession.mode_index])

## Rebuilds the TurnManager from a different mode, reusing the same board/
## resolver/score. Refused mid-turn (same gate the world editor uses) unless
## a battle already ended, so no phase gets orphaned halfway through.
## Switches on the same board. Mid-turn it waits for the turn's animations to
## finish (TurnManager.request_hold) so no phase gets orphaned halfway.
func switch_mode(mode: GameMode) -> void:
	var battle_finished := ctx.battle != null and ctx.battle.ended
	if ctx.awaiting_player_input or battle_finished or editor_mode_controller.active:
		_apply_mode(mode)
		return
	if _pending_mode == null:
		turn_manager.request_hold()
		turn_manager.held.connect(_apply_pending_mode, CONNECT_ONE_SHOT)
	_pending_mode = mode

func _apply_pending_mode() -> void:
	var mode := _pending_mode
	_pending_mode = null
	_apply_mode(mode)

## Reloading the scene is the reset: every module gets rebuilt from GameSession.
func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _apply_mode(mode: GameMode) -> void:
	current_mode = mode
	battle_mode.level = GameSession.battle_level
	GameSession.mode_index = available_modes.find(mode)
	game_menu.show_selected(GameSession.mode_index, editor_mode_controller.active)
	turn_manager = TurnManager.new(ctx, mode.build_phases(ctx))
	ctx.turn_manager = turn_manager
	score_hud.visible = mode.shows_score_hud()
	quest_hud.visible = mode.shows_quest_hud()
	battle_view.visible = mode.shows_battle_view()
	_refit_camera()
	if ctx.battle != null:
		battle_view.setup(ctx)
		ctx.battle.ai_move_chosen.connect(_show_ai_move)
	# With the editor open the new mode must not act (e.g. an AI turn) until
	# the edits are settled.
	if not editor_mode_controller.active:
		turn_manager.start()
	elif not editor_mode_controller.settled.is_connected(_start_turn_manager):
		editor_mode_controller.settled.connect(_start_turn_manager, CONNECT_ONE_SHOT)

func _start_turn_manager() -> void:
	turn_manager.start()

## Highlights what an AI character is about to swap/match/detonate first.
func _show_ai_move(cell_a: GridCell, cell_b: GridCell) -> void:
	if cell_b == null:
		board_view.set_match_preview([cell_a.occupant])
		return
	var tiles: Array = swap_controller.preview_match(cell_a, cell_b)
	if tiles.is_empty():
		tiles = [cell_a.occupant, cell_b.occupant]
	board_view.set_match_preview(tiles)

func _after_board_move() -> void:
	board_view.set_match_preview([])
	board_view.refresh()

const QUEST_REWARD_PER_TILE := 5

const CAMERA_HEIGHT := 15.0
const CAMERA_TILT_DEGREES := 5.0
const CAMERA_MARGIN := 2.0

## Deferred a frame so HUD containers have their final size after a mode switch.
func _refit_camera() -> void:
	await get_tree().process_frame
	_place_camera()

func _place_camera() -> void:
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

	# Fit the board into the screen area the HUD leaves free, then shift the
	# view (h/v_offset, in world units) so the board sits centered in it.
	var viewport_size := get_viewport().get_visible_rect().size
	var free_rect := _free_screen_rect(viewport_size)
	var needed_height := board.height * cell_size + CAMERA_MARGIN
	var needed_width := board.width * cell_size + CAMERA_MARGIN
	camera.size = maxf(needed_height * viewport_size.y / free_rect.size.y, needed_width * viewport_size.y / free_rect.size.x)
	var pixels_per_unit := viewport_size.y / camera.size
	var shift := free_rect.get_center() - viewport_size * 0.5
	camera.h_offset = -shift.x / pixels_per_unit
	camera.v_offset = shift.y / pixels_per_unit

const HUD_GAP := 12.0

## Viewport minus the visible HUD: blockers in the left/right 40% push that
## side in, centered ones push the top or bottom.
func _free_screen_rect(viewport_size: Vector2) -> Rect2:
	var rects: Array[Rect2] = game_menu.hud_rects()
	if score_hud.visible:
		rects.append(score_hud.get_global_rect())
	if quest_hud.visible:
		rects.append(quest_hud.get_global_rect())
	if battle_view.visible:
		rects.append_array(battle_view.hud_rects())
	var left := 0.0
	var right := viewport_size.x
	var top := 0.0
	var bottom := viewport_size.y
	for rect in rects:
		if rect.end.x < viewport_size.x * 0.4:
			left = maxf(left, rect.end.x + HUD_GAP)
		elif rect.position.x > viewport_size.x * 0.6:
			right = minf(right, rect.position.x - HUD_GAP)
		elif rect.get_center().y < viewport_size.y * 0.5:
			top = maxf(top, rect.end.y + HUD_GAP)
		else:
			bottom = minf(bottom, rect.position.y - HUD_GAP)
	var free := Rect2(left, top, right - left, bottom - top)
	return free if free.size.x > 0.0 and free.size.y > 0.0 else Rect2(Vector2.ZERO, viewport_size)
