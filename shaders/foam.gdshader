shader_type spatial;
// Kıyı halkası. UV.y: 0 = iç kenar (kıyı), 1 = dış kenar.
// Köpük için gürültü ve yavaş nabız kenarı canlı gösterir; aynı shader,
// gürültüsüz ayarlarla adaların çevresindeki açık turkuaz sığ su halesini çizer.

render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 0.85);
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float fade_start = 0.35;
uniform float pulse_amount = 0.2;
uniform float edge_noise = 0.4;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = texture(noise_tex, world_pos.xz * 0.08 + vec2(TIME * 0.03, 0.0)).r;
	float pulse = 0.5 + 0.5 * sin(TIME * 1.6 + world_pos.x * 0.2 + world_pos.z * 0.15);
	float band = 1.0 - smoothstep(fade_start + pulse_amount * pulse, 0.95, UV.y + (n - 0.5) * edge_noise);
	ALBEDO = foam_color.rgb;
	ALPHA = foam_color.a * band;
}
