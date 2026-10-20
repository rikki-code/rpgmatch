## Developer benchmark: `-- --bench[=battle]` natively or `?bench[=battle]` on web starts that mode,
## plays it with the best moves and prints frame statistics (also pushed to window.__bench on web).
## `-- --off=shadows,icons` switches a suspect off to see what it costs.
class_name BenchRunner
extends Node

const MOVE_DELAY := 0.2
const REPORT_SECONDS := 10.0
const NATIVE_REPORTS := 3
const HITCH_MS := 33.0
## Seconds after start at which a frame is saved to user://bench_<n>.png.
const SHOT_TIMES := [0.4, 1.0, 2.0, 4.0, 7.0]

var _ctx: TurnContext
var _frames: Array[float] = []
var _elapsed := 0.0
var _idle := 0.0
var _reports := 0
var _draw_calls := 0.0
var _objects := 0.0
var _primitives := 0.0
var _move_ms: Array[float] = []
var _age := 0.0
var _shots := 0

## Empty = no benchmark requested.
static func mode() -> StringName:
	var arg := ""
	if OS.has_feature("web"):
		arg = str(JavaScriptBridge.eval("(function(){var p=new URLSearchParams(location.search);return p.has('bench')?(p.get('bench')||'infinite'):''})()"))
	else:
		for user_arg in OS.get_cmdline_user_args():
			if user_arg.begins_with("--bench"):
				arg = user_arg.substr(8) if user_arg.length() > 8 else "infinite"
	return StringName(arg)

func setup(ctx: TurnContext) -> void:
	_ctx = ctx
	# Uncapped, so the average frame time is the real cost instead of the display refresh.
	if not OS.has_feature("web"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
	_apply_toggles()
	if ctx.battle != null:
		ctx.battle.battle_ended.connect(_on_battle_ended)

func _apply_toggles() -> void:
	var off: PackedStringArray = []
	for user_arg in OS.get_cmdline_user_args():
		if user_arg.begins_with("--off="):
			off = user_arg.substr(6).split(",")
	if off.has("shadows"):
		var light: DirectionalLight3D = get_parent().get_node("DirectionalLight3D")
		light.shadow_enabled = false
	if off.has("icons"):
		var icons: SubViewport = get_parent().get_node("UILayer/QuestHud/IconViewport")
		icons.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _process(delta: float) -> void:
	_age += delta
	if _shots < SHOT_TIMES.size() and _age >= SHOT_TIMES[_shots]:
		get_viewport().get_texture().get_image().save_png("user://bench_%d.png" % _shots)
		_print_state()
		_shots += 1
	_frames.append(delta * 1000.0)
	_elapsed += delta
	_draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	_primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	if _ctx.awaiting_player_input:
		_idle += delta
		if _idle >= MOVE_DELAY:
			_play_move()
	else:
		_idle = 0.0
	if _elapsed >= REPORT_SECONDS:
		_report()

func _print_state() -> void:
	var empty := 0
	var tiles := 0
	for cell: GridCell in _ctx.board.all_cells():
		if cell.kind.can_hold_tile():
			if cell.occupant == null:
				empty += 1
			else:
				tiles += 1
	var view: BoardView3D = get_parent().board_view
	print("STATE t=%.1f model_tiles=%d model_empty=%d view_nodes=%d awaiting=%s" % [_age, tiles, empty, view.tiles._nodes.size(), _ctx.awaiting_player_input])

func _play_move() -> void:
	_idle = 0.0
	var started := Time.get_ticks_usec()
	var power := _ctx.battle.power_multiplier if _ctx.battle != null else 1.0
	var move := MoveFinder.best_move(_ctx.board, power)
	_move_ms.append((Time.get_ticks_usec() - started) / 1000.0)
	if move == null:
		_ctx.shuffle_controller.perform_shuffle()
	elif move.kind == MoveFinder.Move.Kind.DETONATE:
		_ctx.detonate_controller.try_detonate(move.cell_a)
	else:
		_ctx.swap_controller.try_swap(move.cell_a, move.cell_b)

func _on_battle_ended(victory: bool) -> void:
	await get_tree().create_timer(1.0).timeout
	if victory:
		GameSession.launch.level += 1
	get_tree().reload_current_scene()

func _report() -> void:
	var sorted := _frames.duplicate()
	sorted.sort()
	var count := sorted.size()
	var hitches := 0
	for ms in sorted:
		if ms > HITCH_MS:
			hitches += 1
	var move_avg := 0.0
	var move_max := 0.0
	for ms in _move_ms:
		move_avg += ms / _move_ms.size()
		move_max = maxf(move_max, ms)
	var stats := {
		"fps": snappedf(count / _elapsed, 0.1),
		"ms_avg": snappedf(_elapsed * 1000.0 / count, 0.01),
		"ms_p95": snappedf(sorted[int(count * 0.95)], 0.01),
		"ms_p99": snappedf(sorted[int(count * 0.99)], 0.01),
		"ms_max": snappedf(sorted[count - 1], 0.01),
		"hitches": hitches,
		"draw_calls": roundi(_draw_calls / count),
		"objects": roundi(_objects / count),
		"primitives": roundi(_primitives / count),
		"move_search_ms_avg": snappedf(move_avg, 0.01),
		"move_search_ms_max": snappedf(move_max, 0.01),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
	}
	var json := JSON.stringify(stats)
	print("BENCH ", json)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(window.__bench = window.__bench || []).push(%s)" % json)
	_frames.clear()
	_move_ms.clear()
	_elapsed = 0.0
	_draw_calls = 0.0
	_objects = 0.0
	_primitives = 0.0
	_reports += 1
	if _reports >= NATIVE_REPORTS and not OS.has_feature("web"):
		get_tree().quit()
