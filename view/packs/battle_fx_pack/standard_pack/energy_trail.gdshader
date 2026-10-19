// Bolt trail: energy streaming toward the head (UV.x = 1), thin at the tail.
shader_type canvas_item;
render_mode blend_add, unshaded;

#include "res://view/packs/battle_fx_pack/standard_pack/energy_noise.gdshaderinc"

uniform vec4 energy_color : source_color = vec4(1.0, 0.3, 0.25, 1.0);

void fragment() {
	float time = energy_time(TIME);
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float stream = energy_flow_fbm(vec2(UV.x * 6.0, UV.y * 3.0), vec2(9.0, 0.0), time);
	float alpha = smoothstep(0.0, 0.8, across) * UV.x * (0.35 + stream * 1.2);
	vec3 col = mix(energy_color.rgb, vec3(1.0), smoothstep(0.6, 1.0, across) * stream);
	COLOR = vec4(col, clamp(alpha, 0.0, 1.0));
}
