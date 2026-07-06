## Dev-only FPS readout. set_active(false) turns processing off entirely
## (not just hidden) so a disabled counter costs nothing.
class_name FpsCounter
extends Label

func _ready() -> void:
	set_process(false)

func set_active(active: bool) -> void:
	visible = active
	set_process(active)

func _process(_delta: float) -> void:
	text = "FPS: %d" % Engine.get_frames_per_second()
