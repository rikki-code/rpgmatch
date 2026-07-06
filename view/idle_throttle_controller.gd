## Drops Engine.max_fps while the board sits in PhasePlayerInput with no
## input for IDLE_SECONDS, and restores it the instant any input arrives or
## the turn leaves that phase (animations need full framerate to read right).
class_name IdleThrottleController
extends Node

const IDLE_SECONDS := 5.0
const IDLE_MAX_FPS := 25

var ctx: TurnContext

var _idle_elapsed: float = 0.0
var _throttled: bool = false
var _active_max_fps: int

func setup(p_ctx: TurnContext) -> void:
	ctx = p_ctx
	_active_max_fps = Engine.max_fps

func _process(delta: float) -> void:
	if not ctx.awaiting_player_input:
		_wake()
		return
	_idle_elapsed += delta
	if _idle_elapsed >= IDLE_SECONDS and not _throttled:
		_throttled = true
		Engine.max_fps = IDLE_MAX_FPS

func _unhandled_input(_event: InputEvent) -> void:
	_wake()

func _wake() -> void:
	_idle_elapsed = 0.0
	if _throttled:
		_throttled = false
		Engine.max_fps = _active_max_fps
