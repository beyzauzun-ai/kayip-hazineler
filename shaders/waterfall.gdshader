shader_type spatial;
// Şelale: aşağı akan beyaz çizgiler, kenarlarda yumuşak geçiş.

render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 water_color : source_color = vec3(0.55, 0.88, 0.97);
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float flow_speed = 0.9;

void fragment() {
	vec2 uv = vec2(UV.x * 0.6, UV.y * 0.35 - TIME * flow_speed * 0.35);
	float n = texture(noise_tex, uv).r;
	float streaks = smoothstep(0.45, 0.7, n);
	vec3 col = mix(water_color, vec3(1.0), streaks * 0.85);
	float side = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x);
	ALBEDO = col;
	ALPHA = 0.92 * side;
}
