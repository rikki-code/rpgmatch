// Charge aura around a card, classic "magic" look: soft flame tongues rising
// (taller above the card), gentle energy strands and a glowing rim.
// `intensity` 0..1 = charge. Rising motes are particles in charge_aura.tscn.
shader_type canvas_item;
render_mode blend_add, unshaded;

#include "res://view/packs/battle_fx_pack/standard_pack/energy_noise.gdshaderinc"

uniform vec4 energy_color : source_color = vec4(1.0, 0.3, 0.25, 1.0);
uniform float intensity = 0.0;
uniform vec2 rect_size = vec2(300.0, 200.0);
uniform float padding = 48.0;
uniform float corner = 10.0;

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	float time = energy_time(TIME);
	vec2 px = UV * rect_size;
	vec2 center = rect_size * 0.5;
	float d = rounded_box(px - center, center - vec2(padding), corner);
	vec2 outward = normalize(px - center + vec2(0.001));
	vec2 rise = vec2(0.0, -2.2);
	float up = clamp(-outward.y, 0.0, 1.0);
	// Longest tongue (up, full charge) stays well inside the padding.
	float reach = padding * 0.6 * (0.3 + 0.7 * intensity) * (1.0 + up * 0.6);
	float falloff = smoothstep(reach, 0.0, d);
	float flame = energy_flow_fbm(px * 0.03, outward * 0.8 + rise, time);
	float body = smoothstep(reach, 0.0, d + (flame - 0.5) * reach * 1.4);
	float wisps = energy_flow_fbm(px * 0.055, outward * 1.2 + rise * 1.4, time);
	float strands = pow(1.0 - abs(wisps * 2.0 - 1.0), 4.0) * falloff;
	float rim = exp(-max(d, 0.0) * 0.18);
	float inside = step(d, 0.0);
	// Fade out before the quad's border so noise never hits a hard clip.
	float border = min(min(px.x, rect_size.x - px.x), min(px.y, rect_size.y - px.y));
	float edge_fade = smoothstep(0.0, padding * 0.3, border);
	float alpha = (body * 0.6 + strands * 0.55 + rim * 0.65) * intensity * (1.0 - inside) * edge_fade;
	vec3 deep = energy_color.rgb * 0.8;
	vec3 bright = mix(energy_color.rgb, vec3(1.0), 0.6);
	vec3 col = mix(deep, bright, clamp(strands * 0.7 + rim * 0.6, 0.0, 1.0));
	COLOR = vec4(col, clamp(alpha, 0.0, 1.0));
}
