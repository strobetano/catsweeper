shader_type canvas_item;
render_mode unshaded;

uniform vec4 top_dusk : source_color = vec4(0.310, 0.373, 0.475, 1.0);
uniform vec4 bottom_dusk : source_color = vec4(0.380, 0.357, 0.475, 1.0);
uniform vec4 lavender_glow : source_color = vec4(0.788, 0.725, 0.898, 1.0);
uniform vec4 mint_glow : source_color = vec4(0.659, 0.863, 0.796, 1.0);
uniform vec4 coral_glow : source_color = vec4(0.949, 0.647, 0.620, 1.0);
uniform vec4 gold_glow : source_color = vec4(0.961, 0.851, 0.557, 1.0);
uniform vec4 paper_glow : source_color = vec4(0.953, 0.922, 0.867, 1.0);
uniform vec4 mote_color : source_color = vec4(1.0, 0.976, 0.941, 1.0);
uniform float drift_speed : hint_range(0.0, 0.25, 0.005) = 0.065;
uniform float glow_strength : hint_range(0.0, 1.5, 0.01) = 1.0;
uniform float mote_strength : hint_range(0.0, 1.0, 0.01) = 0.44;
uniform float grain_strength : hint_range(0.0, 0.03, 0.001) = 0.004;
uniform float vignette_strength : hint_range(0.0, 0.5, 0.01) = 0.14;

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
	float phase = TIME * drift_speed * 6.283185;
	float vertical = smoothstep(-0.08, 1.08, uv.y);
	vec3 col = mix(top_dusk.rgb, bottom_dusk.rgb, vertical);

	float flow_a = value_noise(uv * vec2(2.35, 2.05) + vec2(phase * 0.10, -phase * 0.07));
	float flow_b = value_noise(uv * vec2(2.05, 2.65) + vec2(-phase * 0.08, phase * 0.09));
	float breathe_a = 0.80 + 0.20 * (0.5 + 0.5 * sin(phase * 1.05));
	float breathe_b = 0.80 + 0.20 * (0.5 + 0.5 * sin(phase * 0.86 + 2.1));
	float ribbon_y_a = 0.20 + sin(uv.x * 4.2 + phase * 0.78) * 0.052 + (flow_a - 0.5) * 0.14;
	float ribbon_y_b = 0.79 + sin(uv.x * 3.3 - phase * 0.66) * 0.062 + (flow_b - 0.5) * 0.13;
	float ribbon_a = exp(-pow((uv.y - ribbon_y_a) / 0.16, 2.0));
	float ribbon_b = exp(-pow((uv.y - ribbon_y_b) / 0.18, 2.0));
	col = mix(col, lavender_glow.rgb, ribbon_a * glow_strength * 0.16 * breathe_a);
	col = mix(col, mint_glow.rgb, ribbon_b * glow_strength * 0.14 * breathe_b);

	float board_halo = soft_blob(uv, vec2(0.50, 0.57), vec2(0.67, 0.56));
	col = mix(col, paper_glow.rgb, board_halo * glow_strength * 0.13 * mix(breathe_a, breathe_b, 0.5));

	vec2 mint_center = vec2(0.08 + sin(phase * 0.62) * 0.035, 0.68);
	vec2 coral_center = vec2(0.92, 0.25 + cos(phase * 0.56) * 0.035);
	float mint_blob = soft_blob(uv, mint_center, vec2(0.36, 0.32));
	float coral_blob = soft_blob(uv, coral_center, vec2(0.34, 0.30));
	col = mix(col, mint_glow.rgb, mint_blob * glow_strength * 0.105 * breathe_b);
	col = mix(col, coral_glow.rgb, coral_blob * glow_strength * 0.100 * breathe_a);

	float veil_wave = sin((uv.x * 0.72 + uv.y) * 7.0 - phase * 0.58 + (flow_a - 0.5) * 0.9);
	float veil = smoothstep(0.58, 0.98, veil_wave) * smoothstep(0.02, 0.24, uv.y) * (1.0 - smoothstep(0.78, 0.99, uv.y));
	col = mix(col, gold_glow.rgb, veil * glow_strength * 0.042 * breathe_a);

	vec2 mote_grid = uv * vec2(18.0, 28.0) + vec2(phase * 0.075, -phase * 0.032);
	vec2 mote_cell = floor(mote_grid);
	vec2 mote_local = fract(mote_grid) - 0.5;
	vec2 mote_offset = (hash22(mote_cell + vec2(9.3, 4.7)) - 0.5) * 0.64;
	float mote_seed = hash21(mote_cell + vec2(41.0, 17.0));
	float mote_mask = step(0.93, mote_seed);
	float mote_distance = length(mote_local - mote_offset);
	float mote_soft = 1.0 - smoothstep(0.035, 0.15, mote_distance);
	float mote_core = 1.0 - smoothstep(0.010, 0.045, mote_distance);
	float twinkle = 0.58 + 0.42 * sin(TIME * (0.62 + mote_seed * 0.74) + mote_seed * 6.283185);
	float mote_amount = mote_mask * (mote_soft * 0.10 + mote_core * 0.55) * twinkle * mote_strength;
	col = mix(col, mote_color.rgb, clamp(mote_amount, 0.0, 0.30));

	float grain = hash21(floor(FRAGCOORD.xy)) - 0.5;
	col += grain * grain_strength;
	float vignette = smoothstep(0.36, 0.80, distance(uv, vec2(0.5)));
	col = mix(col, top_dusk.rgb * 0.82, vignette * vignette_strength);
	COLOR = vec4(clamp(col, vec3(0.0), vec3(1.0)), 1.0);
}
