// Crisp meadow: mowed diagonal stripes, pixel tufts and rare flowers, darkened toward the edges.
shader_type spatial;
render_mode unshaded;

uniform vec3 stripe_a : source_color = vec3(0.11, 0.2, 0.07);
uniform vec3 stripe_b : source_color = vec3(0.125, 0.225, 0.08);
uniform vec3 tuft_light : source_color = vec3(0.16, 0.28, 0.09);
uniform vec3 tuft_dark : source_color = vec3(0.085, 0.16, 0.055);
uniform float tuft_density = 9.0;

varying vec2 local_xz;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	local_xz = VERTEX.xz;
}

void fragment() {
	float band = floor((local_xz.x + local_xz.y) / 1.5);
	vec3 col = mod(band, 2.0) < 1.0 ? stripe_a : stripe_b;

	vec2 cell = floor(local_xz * tuft_density);
	float h = hash(cell);
	if (h > 0.94) {
		col = tuft_light;
	} else if (h < 0.05) {
		col = tuft_dark;
	}
	if (hash(cell + 7.0) > 0.9985) {
		col = mix(vec3(0.95, 0.9, 0.5), vec3(0.95, 0.6, 0.75), step(0.5, hash(cell + 3.0)));
	}

	float edge = smoothstep(4.0, 16.0, length(local_xz));
	ALBEDO = mix(col, col * 0.2, edge);
}
