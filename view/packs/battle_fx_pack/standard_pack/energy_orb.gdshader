// Plasma orb: swirling noise inside a soft sphere with a white-hot core.
shader_type canvas_item;
render_mode blend_add, unshaded;

#include "res://view/packs/battle_fx_pack/standard_pack/energy_noise.gdshaderinc"

uniform vec4 energy_color : source_color = vec4(1.0, 0.3, 0.25, 1.0);

void fragment() {
	float time = energy_time(TIME);
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float t = time * 5.0;
	mat2 spin = mat2(vec2(cos(t), -sin(t)), vec2(sin(t), cos(t)));
	float plasma = energy_flow_fbm(spin * p * 3.0, vec2(-2.0, 3.0), time);
	float shell = smoothstep(1.0, 0.25, r + (plasma - 0.5) * 0.6);
	float core = smoothstep(0.3, 0.0, r);
	float alpha = clamp(shell * (0.9 + plasma) + core, 0.0, 1.0);
	vec3 col = mix(energy_color.rgb * 1.3, vec3(1.0), clamp(core * 0.8 + plasma * 0.15, 0.0, 1.0));
	COLOR = vec4(col, alpha);
}
