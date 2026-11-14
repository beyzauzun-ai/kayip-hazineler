shader_type spatial;
// Stilize deniz: sol alttan (liman) sağ üste (Derin Mavi) turkuaz → mavi → lavanta
// renk geçişi ve iki kayan gürültüden üretilen ince dalga ışıltıları.
// Gölgelemesiz ve yarı saydam: su altındaki raf, mercan ve batıklar görünür.

render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled;

uniform vec3 shallow_color : source_color = vec3(0.243, 0.847, 0.812);
uniform vec3 mid_color : source_color = vec3(0.110, 0.651, 0.855);
uniform vec3 deep_color : source_color = vec3(0.357, 0.357, 0.839);
uniform float alpha : hint_range(0.0, 1.0) = 0.8;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float wave_scale = 0.02;
uniform float wave_speed = 0.01;
uniform float highlight_strength = 0.13;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = clamp((world_pos.x * 0.55 - world_pos.z * 0.85) / 140.0 + 0.5, 0.0, 1.0);
	vec3 col = mix(shallow_color, mid_color, smoothstep(0.2, 0.65, t));
	col = mix(col, deep_color, smoothstep(0.62, 1.0, t));
	// Üst kenar (uzak deniz) hafif lavantaya kayar.
	col = mix(col, deep_color, smoothstep(-15.0, -45.0, world_pos.z) * 0.4);

	vec2 uv = world_pos.xz * wave_scale;
	float n1 = texture(noise_tex, uv + TIME * wave_speed * vec2(1.0, 0.6)).r;
	float n2 = texture(noise_tex, uv * 1.3 - TIME * wave_speed * vec2(0.7, 1.0)).r;
	float lines = 1.0 - smoothstep(0.0, 0.025, abs(n1 - n2));
	col += lines * highlight_strength;

	ALBEDO = col;
	ALPHA = alpha;
}
