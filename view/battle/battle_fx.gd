## Action VFX layer over the battle cards. Visuals come from the active
## battle FX pack (PackPaths.BATTLE_FX_PACK): a bolt flies actor → target,
## then a burst plays at the target. This node only places and starts them.
class_name BattleFx
extends Control

static var BOLT_SCENE: PackedScene
static var BURST_SCENE: PackedScene
static var AURA_SCENE: PackedScene
static var COLORS: ActionColorPalette

static func _static_init() -> void:
	BOLT_SCENE = load(PackPaths.BATTLE_FX_PACK + "action_bolt.tscn")
	BURST_SCENE = load(PackPaths.BATTLE_FX_PACK + "action_burst.tscn")
	AURA_SCENE = load(PackPaths.BATTLE_FX_PACK + "charge_aura.tscn")
	COLORS = load(PackPaths.BATTLE_FX_PACK + "action_colors.tres")

static func color_for(action: BattleAction) -> Color:
	return COLORS.color_for(action.visual_kind())

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_warm_up()

## `power` 0..1 scales both the bolt and the burst. Self-targeted actions
## (own shield) skip the flight, but still burst after `seconds` — the action
## applies (and its number pops) only then.
func play_action(from_rect: Rect2, to_rect: Rect2, color: Color, seconds: float, power: float) -> void:
	var start := from_rect.get_center()
	var end := to_rect.get_center()
	if start.distance_to(end) < 1.0:
		var wait := create_tween()
		wait.tween_interval(seconds)
		wait.tween_callback(_burst.bind(end, color, power, self))
		return
	var bolt := BOLT_SCENE.instantiate()
	add_child(bolt)
	bolt.landed.connect(func() -> void: _burst(end, color, power, self))
	bolt.launch(start, end, color, seconds, power)

func _burst(at: Vector2, color: Color, power: float, parent: Node) -> void:
	var burst := BURST_SCENE.instantiate()
	burst.position = at
	parent.add_child(burst)
	burst.play(color, power)

## Plays every pack effect once inside a tiny offscreen SubViewport: GL
## Compatibility compiles shaders on first draw (shared across viewports),
## which otherwise hitches the first attack (~4 frames measured) and makes its
## tweens skip part of the flight. Nothing reaches the screen.
func _warm_up() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(16, 16)
	stage.transparent_bg = true
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(stage)
	var bolt := BOLT_SCENE.instantiate()
	stage.add_child(bolt)
	bolt.launch(Vector2(2.0, 2.0), Vector2(12.0, 12.0), Color.WHITE, 0.05, 1.0)
	_burst(Vector2(8.0, 8.0), Color.WHITE, 1.0, stage)
	var aura := AURA_SCENE.instantiate()
	stage.add_child(aura)
	aura.set_intensity(1.0)
	aura.fit(Rect2(Vector2(4.0, 4.0), Vector2(8.0, 8.0)))
	var cleanup := stage.create_tween()
	cleanup.tween_interval(1.0)
	cleanup.tween_callback(stage.queue_free)
