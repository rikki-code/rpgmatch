// Impact shockwave: a noise-torn ring expanding with `progress` 0..1, plus a
// fading flash at the center.
shader_type canvas_item;
render_mode blend_add, unshaded;

#include "res://view/packs/battle_fx_pack/standard_pack/energy_noise.gdshaderinc"

uniform vec4 energy_color : source_color = vec4(1.0, 0.3, 0.25, 1.0);
uniform float progress = 0.0;

void fragment() {
	float time = energy_time(TIME);
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float torn = energy_flow_fbm(normalize(p + vec2(0.001)) * 4.0 + vec2(0.0, progress * 6.0), vec2(-3.0, 0.0), time);
	float radius = progress * 0.9;
	float width = 0.06 + 0.12 * (1.0 - progress);
	float ring = smoothstep(width, 0.0, abs(r - radius + (torn - 0.5) * 0.18));
	float flash = smoothstep(0.5 * (1.0 - progress), 0.0, r) * (1.0 - progress);
	float fade = 1.0 - progress;
	float alpha = clamp((ring * (0.6 + torn) + flash) * fade, 0.0, 1.0);
	vec3 col = mix(energy_color.rgb, vec3(1.0), clamp(flash + ring * torn * 0.5, 0.0, 1.0));
	COLOR = vec4(col, alpha);
}
