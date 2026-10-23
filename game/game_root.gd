## Wires generation params -> BoardGraph -> TurnManager -> view together.
## This is the only place that knows about all the modules at once.
class_name GameRoot
extends Node3D

@export var dev_mode: bool = false

var board: BoardGraph
var ctx: TurnContext
var turn_manager: TurnManager
var swap_controller: SwapController
var detonate_controller: DetonateController
var quest_manager: QuestManager
var stats_recorder: StatsRecorder
var board_audio: BoardAudio
var battle_audio: BattleAudio
var online_sync: OnlineSync
var current_mode: GameMode
## Debug builds only: one default-settings mode per ModeCatalog entry, for the editor toolbar's mode dropdown.
var dev_modes: Array[GameMode] = []
var board_view: BoardView3D
var editor_mode_controller: EditorModeController
var score_hud: ScoreHud
var quest_hud: QuestHud
var battle_view: BattleView
var camera: Camera3D
var game_menu: GameMenu
var editor_toolbar: EditorToolbar
## Mode chosen mid-turn, applied once the turn manager parks (see switch_mode).
var _pending_mode: GameMode
## Saved game to restore, consumed by the first _apply_mode (the mode builds a fresh battle that must be replaced).
var _resume: Dictionary

func _ready() -> void:
	# Running game_root.tscn directly (F6) has no start screen to come from.
	if GameSession.launch == null:
		GameSession.launch = RunConfig.defaults(ModeCatalog.find(ModeCatalog.BATTLE))
	var launch := GameSession.launch
	var start_mode := launch.create_mode()
	_resume = GameSession.resume
	GameSession.resume = {}
	if _resume.is_empty():
		board = BoardGenerator.generate(start_mode.board_params(launch.world_params(), launch.level))
	else:
		board = BoardGraph.from_dict(_resume["board"])

	ctx = TurnContext.new(board)
	ctx.resolver = EffectResolver.new(board)
	ctx.score_tracker = ScoreTracker.new(ctx.resolver)
	if not _resume.is_empty():
		ctx.score_tracker.restore(_resume["score"])
	swap_controller = SwapController.new(ctx)
	ctx.swap_controller = swap_controller
	detonate_controller = DetonateController.new(ctx)
	ctx.detonate_controller = detonate_controller
	ctx.shuffle_controller = ShuffleController.new(ctx)

	stats_recorder = StatsRecorder.new(ctx.score_tracker, GameSession.profile().stats_for(launch.mode_id))

	quest_manager = QuestManager.new(board, ctx.resolver, RandomQuestGenerator.new())
	board_audio = BoardAudio.new(ctx, quest_manager, swap_controller, detonate_controller)
	if _resume.is_empty():
		quest_manager.fill_from_generator()
	else:
		quest_manager.restore(_resume["quests"])
	quest_manager.quest_completed.connect(func(quest: QuestProgress) -> void:
		ctx.score_tracker.award_bonus(quest.definition.target_count * QUEST_REWARD_PER_TILE)
	)

	board_view = $BoardView3D
	board_view.setup(board)
	ctx.animation_driver = BoardViewAnimationDriver.new(board_view)
	ctx.resolver.effect_applied.connect(board_view.present_effect)
	swap_controller.swap_applied.connect(func(_a: GridCell, _b: GridCell) -> void: _after_board_move())
	swap_controller.swap_rejected.connect(func(a: GridCell, b: GridCell) -> void:
		board_view.refresh()
		board_view.tiles.wobble(a)
		board_view.tiles.wobble(b)
	)
	swap_controller.tiles_combined.connect(func(_a: GridCell, _b: GridCell) -> void: _after_board_move())
	detonate_controller.detonated.connect(func(_cell: GridCell) -> void: _after_board_move())
	ctx.shuffle_controller.shuffled.connect(_after_board_move)

	camera = $Camera3D
	UiScale.fit(get_window())
	get_tree().root.size_changed.connect(func() -> void:
		UiScale.fit(get_window())
		_refit_camera()
	)

	var input_controller: InputController = $InputController
	input_controller.setup(camera, board_view, board, swap_controller, detonate_controller)

	editor_mode_controller = $EditorModeController
	editor_mode_controller.setup(camera, board_view, ctx)
	var editor_grid_overlay: EditorGridOverlay = $EditorGridOverlay
	editor_grid_overlay.setup(board)
	editor_toolbar = $UILayer/EditorToolbar

	editor_mode_controller.mode_changed.connect(func(active: bool) -> void:
		input_controller.set_editor_active(active)
		editor_grid_overlay.set_active(active)
		editor_toolbar.set_panel_visible(active)
		if active:
			editor_toolbar.setup(editor_mode_controller.cell_catalog, editor_mode_controller.tile_catalog, dev_modes)
			editor_toolbar.show_state(_dev_mode_index(), GameSession.launch.level)
	)
	editor_toolbar.cell_kind_selected.connect(editor_mode_controller.select_cell_kind)
	editor_toolbar.remove_cell_selected.connect(editor_mode_controller.select_remove_cell)
	editor_toolbar.tile_selected.connect(editor_mode_controller.select_tile)
	editor_toolbar.game_mode_selected.connect(func(mode: GameMode) -> void: _switch_definition(dev_modes.find(mode)))
	editor_toolbar.battle_level_selected.connect(_set_battle_level)

	var idle_throttle_controller: IdleThrottleController = $IdleThrottleController
	idle_throttle_controller.setup(ctx)

	var fps_counter: FpsCounter = $UILayer/FpsCounter
	fps_counter.set_active(dev_mode)

	score_hud = $UILayer/ScoreHud
	score_hud.setup(ctx.score_tracker)
	quest_hud = $UILayer/QuestHud
	quest_hud.setup(quest_manager)
	battle_view = $UILayer/BattleView
	battle_view.continue_requested.connect(func(advance: bool) -> void:
		if advance:
			GameSession.launch.level += 1
		_restart()
	)
	battle_view.exit_requested.connect(SceneRouter.to_menu)

	var move_assist := MoveAssist.new()
	$UILayer.add_child(move_assist)
	$UILayer.move_child(move_assist, $UILayer/GameMenu.get_index())
	move_assist.setup(ctx, editor_mode_controller)
	move_assist.hint_requested.connect(func(move: MoveFinder.Move) -> void:
		Audio.play(&"hint")
		_highlight_move(move.cell_a, move.cell_b)
	)

	game_menu = $UILayer/GameMenu
	if OS.is_debug_build():
		for definition in ModeCatalog.all():
			dev_modes.append(definition.create_mode(definition.default_settings()))
	game_menu.pack_selected.connect(_apply_pack)
	game_menu.restart_requested.connect(_restart)
	game_menu.exit_requested.connect(SceneRouter.to_menu)

	_apply_mode(start_mode)
	if ctx.battle != null and ctx.battle.is_online():
		_start_online()
	if BenchRunner.mode() != &"":
		var bench := BenchRunner.new()
		add_child(bench)
		bench.setup(ctx)

func _start_online() -> void:
	online_sync = OnlineSync.new()
	online_sync.setup(ctx, int(GameSession.launch.settings[&"seat"]))
	online_sync.outgoing.connect(Net.send_game)
	online_sync.match_lost.connect(battle_view.show_notice)
	Net.game_message.connect(online_sync.receive)
	Net.connection_lost.connect(online_sync.connection_lost)
	for message in Net.attach_game():
		online_sync.receive(message)
	game_menu.set_restart_enabled(false)

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

## Rebuilds the battle at `level` on the current board (an edited board is
## kept — only Next battle/Reset regenerate it for the level).
func _set_battle_level(level: int) -> void:
	GameSession.launch.level = level
	switch_mode(current_mode)

func _dev_mode_index() -> int:
	return ModeCatalog.all().find(GameSession.launch.definition())

## Debug mode switch on the same board: the launch config follows, so Restart keeps the new mode.
func _switch_definition(index: int) -> void:
	var level := GameSession.launch.level
	GameSession.launch = RunConfig.defaults(ModeCatalog.all()[index])
	GameSession.launch.level = level
	switch_mode(dev_modes[index])

# The static scene caches are filled once per process; the live board swaps its models in place.
func _apply_pack(category: StringName, id: String) -> void:
	PackCatalog.apply({category: id})
	PackPaths.refresh()
	if category == PackCatalog.AUDIO:
		Audio.reload()
		return
	TileView.load_packs()
	CellLayer.load_packs()
	VfxPool.load_packs()
	board_view.reskin()
	editor_toolbar.invalidate_icons()
	if quest_hud.visible:
		quest_hud.reskin()

## Restart is a scene reload: every module gets rebuilt from GameSession.launch.
func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _apply_mode(mode: GameMode) -> void:
	current_mode = mode
	turn_manager = TurnManager.new(ctx, mode.build_phases(ctx, GameSession.launch.level))
	if not _resume.is_empty():
		_restore_battle()
	ctx.turn_manager = turn_manager
	turn_manager.turn_cycle_completed.connect(_save_stats)
	turn_manager.turn_cycle_completed.connect(_save_run)
	if ctx.battle != null:
		stats_recorder.note_level(GameSession.launch.level)
		ctx.battle.battle_ended.connect(_on_battle_ended)
	score_hud.visible = mode.shows_score_hud()
	quest_hud.visible = mode.shows_quest_hud()
	battle_view.visible = mode.shows_battle_view()
	_refit_camera()
	Audio.play_music(&"battle" if ctx.battle != null else &"game")
	if ctx.battle != null:
		battle_view.setup(ctx)
		battle_audio = BattleAudio.new(ctx.battle)
		ctx.battle.ai_move_chosen.connect(_highlight_move)
	# With the editor open the new mode must not act (e.g. an AI turn) until
	# the edits are settled.
	if not editor_mode_controller.active:
		_start_turn_manager()
	elif not editor_mode_controller.settled.is_connected(_start_turn_manager):
		editor_mode_controller.settled.connect(_start_turn_manager, CONNECT_ONE_SHOT)

# build_phases rolled a new encounter with the board rng, so the saved battle and the rng state go back in after it.
func _restore_battle() -> void:
	if ctx.battle != null:
		ctx.battle = BattleContext.from_dict(_resume["battle"], board.rng)
	board.restore_rng(_resume["board"]["rng"])
	_resume = {}

func _save_run() -> void:
	if editor_mode_controller.active or (ctx.battle != null and (ctx.battle.is_battle_over() or ctx.battle.is_online())):
		return
	SaveStore.save_run(RunSave.new(GameSession.launch, GameSnapshot.capture(ctx, quest_manager)))

func _on_battle_ended(victory: bool) -> void:
	stats_recorder.note_battle_ended(victory)
	SaveStore.delete_run(GameSession.launch.mode_id)
	_save_stats()

func _save_stats() -> void:
	if stats_recorder.dirty:
		SaveStore.save_profile(GameSession.profile())
		stats_recorder.dirty = false

func _exit_tree() -> void:
	_save_stats()
	if online_sync != null:
		Net.game_message.disconnect(online_sync.receive)
		Net.connection_lost.disconnect(online_sync.connection_lost)
		Net.leave()

# Waits for the opening fill to land: input is open from the first turn, and a move made
# under tiles that are still falling in shows holes.
func _start_turn_manager() -> void:
	var manager := turn_manager
	await board_view.await_settled()
	if manager == turn_manager:
		manager.start()

## Highlights a move: what an AI is about to play, or the idle-player hint.
func _highlight_move(cell_a: GridCell, cell_b: GridCell) -> void:
	if cell_b == null:
		board_view.tiles.set_match_preview([cell_a.occupant])
		return
	var tiles: Array = swap_controller.preview_match(cell_a, cell_b)
	if tiles.is_empty():
		tiles = [cell_a.occupant, cell_b.occupant]
	board_view.tiles.set_match_preview(tiles)

func _after_board_move() -> void:
	board_view.tiles.set_match_preview([])
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
	var cell_size := BoardGeometry.CELL_SIZE
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
	var board_size := Vector2(board.width, board.height) * cell_size * pixels_per_unit
	var board_rect := Rect2(free_rect.get_center() - board_size * 0.5, board_size)
	# New tiles drop in from one cell above the board; each view decides whether to keep clear of it.
	var spawn_lane := cell_size * pixels_per_unit
	for view in _docked_hud():
		view.dock_to_board(board_rect, spawn_lane)

const HUD_GAP := 12.0

## Visible HUD views that reserve screen bands (hud_rects) and then sit against
## the board (dock_to_board).
func _docked_hud() -> Array:
	return [score_hud, quest_hud, battle_view].filter(func(view: Control) -> bool: return view.visible)

## Viewport minus the visible HUD: each blocker cuts the screen from the edge
## that costs the least share of it — side columns cut left/right in
## landscape, top/bottom rows and corner widgets cut top/bottom in portrait.
func _free_screen_rect(viewport_size: Vector2) -> Rect2:
	var rects: Array[Rect2] = game_menu.hud_rects()
	for view in _docked_hud():
		rects.append_array(view.hud_rects())
	var left := 0.0
	var right := viewport_size.x
	var top := 0.0
	var bottom := viewport_size.y
	for rect in rects:
		var cuts := [
			(rect.end.x + HUD_GAP) / viewport_size.x,
			(viewport_size.x - rect.position.x + HUD_GAP) / viewport_size.x,
			(rect.end.y + HUD_GAP) / viewport_size.y,
			(viewport_size.y - rect.position.y + HUD_GAP) / viewport_size.y,
		]
		match cuts.find(cuts.min()):
			0: left = maxf(left, rect.end.x + HUD_GAP)
			1: right = minf(right, rect.position.x - HUD_GAP)
			2: top = maxf(top, rect.end.y + HUD_GAP)
			3: bottom = minf(bottom, rect.position.y - HUD_GAP)
	var free := Rect2(left, top, right - left, bottom - top)
	return free if free.size.x > 0.0 and free.size.y > 0.0 else Rect2(Vector2.ZERO, viewport_size)
