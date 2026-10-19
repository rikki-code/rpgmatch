## Card charge aura: energy_aura shader + rising motes + rare edge sparks. Top-level, drawn
## behind its card; the card calls fit() every frame it's visible.
extends ColorRect

@onready var _arcs: Node2D = $EdgeArcs
@onready var _motes: CPUParticles2D = $Motes

func set_energy_color(color: Color) -> void:
	(material as ShaderMaterial).set_shader_parameter("energy_color", color)
	_arcs.color = color
	_motes.color = color.lightened(0.4)

func get_intensity() -> float:
	return (material as ShaderMaterial).get_shader_parameter("intensity")

func set_intensity(value: float) -> void:
	(material as ShaderMaterial).set_shader_parameter("intensity", value)
	_arcs.intensity = value
	_motes.emitting = value > 0.05
	_motes.modulate.a = value

func fit(card_rect: Rect2) -> void:
	var padding: float = (material as ShaderMaterial).get_shader_parameter("padding")
	global_position = card_rect.position - Vector2.ONE * padding
	size = card_rect.size + Vector2.ONE * padding * 2.0
	(material as ShaderMaterial).set_shader_parameter("rect_size", size)
	_arcs.rect = Rect2(Vector2.ONE * padding, card_rect.size)
	_motes.position = size / 2.0
	_motes.emission_rect_extents = card_rect.size / 2.0
