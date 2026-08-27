shader_type canvas_item;
render_mode unshaded;

uniform vec4 top_ink : source_color = vec4(0.035, 0.090, 0.170, 1.0);
uniform vec4 bottom_ink : source_color = vec4(0.110, 0.135, 0.265, 1.0);
uniform vec4 lavender_glow : source_color = vec4(0.560, 0.470, 0.820, 1.0);
uniform vec4 mint_glow : source_color = vec4(0.520, 0.850, 0.760, 1.0);
uniform vec4 coral_glow : source_color = vec4(0.950, 0.620, 0.590, 1.0);
uniform vec4 star_color : source_color = vec4(1.0, 0.965, 0.855, 1.0);
uniform float drift_speed : hint_range(0.0, 0.25, 0.005) = 0.045;
uniform float glow_strength : hint_range(0.0, 1.5, 0.01) = 0.72;
uniform float star_strength : hint_range(0.0, 1.0, 0.01) = 0.52;
uniform float grain_strength : hint_range(0.0, 0.03, 0.001) = 0.006;
uniform float vignette_strength : hint_range(0.0, 0.5, 0.01) = 0.18;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash22(vec2 p) {
	return fract(sin(vec2(
		dot(p, vec2(127.1, 311.7)),
		dot(p, vec2(269.5, 183.3))
	)) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

float soft_blob(vec2 uv, vec2 center, vec2 scale_value) {
	vec2 delta = (uv - center) / scale_value;
	return exp(-dot(delta, delta) * 2.2);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * drift_speed;
	float vertical = smoothstep(0.0, 1.0, uv.y);
	vec3 col = mix(top_ink.rgb, bottom_ink.rgb, vertical);

	float flow_a = value_noise(uv * vec2(2.4, 2.0) + vec2(t * 0.13, -t * 0.08));
	float flow_b = value_noise(uv * vec2(2.0, 2.7) + vec2(-t * 0.09, t * 0.11));
	float ribbon_y_a = 0.22 + sin(uv.x * 4.2 + t * 1.4) * 0.045 + (flow_a - 0.5) * 0.15;
	float ribbon_y_b = 0.78 + sin(uv.x * 3.2 - t * 1.1) * 0.055 + (flow_b - 0.5) * 0.14;
	float ribbon_a = exp(-pow((uv.y - ribbon_y_a) / 0.14, 2.0));
	float ribbon_b = exp(-pow((uv.y - ribbon_y_b) / 0.16, 2.0));
	col += lavender_glow.rgb * ribbon_a * glow_strength * 0.070;
	col += mint_glow.rgb * ribbon_b * glow_strength * 0.065;

	vec2 mint_center = vec2(0.10 + sin(t * 0.8) * 0.025, 0.70);
	vec2 coral_center = vec2(0.90, 0.24 + cos(t * 0.7) * 0.025);
	col += mint_glow.rgb * soft_blob(uv, mint_center, vec2(0.38, 0.32)) * glow_strength * 0.055;
	col += coral_glow.rgb * soft_blob(uv, coral_center, vec2(0.34, 0.28)) * glow_strength * 0.050;

	vec2 star_grid = uv * vec2(44.0, 70.0) + vec2(t * 0.10, -t * 0.035);
	vec2 star_cell = floor(star_grid);
	vec2 star_local = fract(star_grid) - 0.5;
	vec2 star_offset = (hash22(star_cell + vec2(9.3, 4.7)) - 0.5) * 0.66;
	float star_seed = hash21(star_cell + vec2(41.0, 17.0));
	float star_mask = step(0.955, star_seed);
	float star_shape = 1.0 - smoothstep(0.025, 0.080, length(star_local - star_offset));
	float twinkle = 0.58 + 0.42 * sin(TIME * (0.65 + star_seed * 1.15) + star_seed * 6.283185);
	col += star_color.rgb * star_mask * star_shape * twinkle * star_strength * 0.32;

	float grain = hash21(floor(FRAGCOORD.xy)) - 0.5;
	col += grain * grain_strength;
	float vignette = smoothstep(0.34, 0.82, distance(uv, vec2(0.5)));
	col *= 1.0 - vignette * vignette_strength;
	COLOR = vec4(col, 1.0);
}
