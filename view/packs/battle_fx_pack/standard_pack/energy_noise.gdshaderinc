// Value noise + fbm shared by the battle energy shaders.

// Keeps TIME small; 600 s is a whole number of flow cycles, so the wrap is seamless.
float energy_time(float t) {
	return mod(t, 600.0);
}

// Sin-free hash (Dave Hoskins): stays stable for large coordinates.
float energy_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float energy_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(energy_hash(i), energy_hash(i + vec2(1.0, 0.0)), u.x),
			mix(energy_hash(i + vec2(0.0, 1.0)), energy_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float energy_fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		value += amplitude * energy_noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		amplitude *= 0.5;
	}
	return value;
}

// fbm scrolling at `velocity` (noise units/s) with bounded inputs: two copies
// half a cycle apart cross-fade, each restarting while hidden (flow-map trick).
// Scrolling by velocity * time directly loses float precision within minutes.
float energy_flow_fbm(vec2 p, vec2 velocity, float time) {
	const float CYCLE = 1.5;
	float phase_a = fract(time / CYCLE);
	float phase_b = fract(time / CYCLE + 0.5);
	float a = energy_fbm(p - velocity * phase_a * CYCLE);
	float b = energy_fbm(p - velocity * phase_b * CYCLE + vec2(37.2, 11.9));
	return mix(a, b, abs(phase_a * 2.0 - 1.0));
}
