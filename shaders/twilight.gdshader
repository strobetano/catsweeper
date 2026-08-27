shader_type canvas_item;
render_mode unshaded;

uniform vec4 top_ink : source_color = vec4(0.027, 0.075, 0.145, 1.0);
uniform vec4 bottom_ink : source_color = vec4(0.098, 0.120, 0.230, 1.0);
uniform vec4 mint_glow : source_color = vec4(0.294, 0.690, 0.620, 1.0);
uniform vec4 coral_glow : source_color = vec4(0.925, 0.424, 0.370, 1.0);
uniform float drift_speed : hint_range(0.0, 0.3, 0.01) = 0.055;
uniform float grain_strength : hint_range(0.0, 0.08, 0.002) = 0.018;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * drift_speed;
	vec3 col = mix(top_ink.rgb, bottom_ink.rgb, smoothstep(0.0, 1.0, uv.y));
	float wave_a = sin(uv.x * 5.2 + uv.y * 2.7 + t) * 0.5 + 0.5;
	float wave_b = sin(uv.x * -3.1 + uv.y * 4.4 - t * 0.8) * 0.5 + 0.5;
	float mint_haze = exp(-18.0 * distance(uv, vec2(0.12 + 0.03 * sin(t), 0.78)));
	float coral_haze = exp(-15.0 * distance(uv, vec2(0.88, 0.18 + 0.02 * cos(t))));
	col += mint_glow.rgb * mint_haze * (0.055 + wave_a * 0.025);
	col += coral_glow.rgb * coral_haze * (0.045 + wave_b * 0.02);
	float dust = step(0.996, hash(floor((uv + vec2(t * 0.015, 0.0)) * vec2(94.0, 142.0))));
	col += vec3(dust) * (0.08 + 0.05 * sin(TIME * 1.3));
	float grain = hash(floor(FRAGCOORD.xy * 0.72) + floor(TIME * 4.0)) - 0.5;
	col += grain * grain_strength;
	float vignette = 1.0 - smoothstep(0.42, 0.92, distance(uv, vec2(0.5))) * 0.24;
	COLOR = vec4(col * vignette, 1.0);
}
