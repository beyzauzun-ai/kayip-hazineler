shader_type spatial;
// Fener ve pencereler için ucuz sahte ışıltı (gerçek glow kapalı).
// Tüm haleler tek mesh'te: her dörtgenin dört köşesi halenin merkezindedir;
// UV köşeyi, UV2.x halenin dünya birimindeki çapını verir. Köşeler görüş
// uzayında açıldığı için haleler hep kameraya bakar. Toplamsal karışım.

render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// 10. aşama: liman ışıltıları güçlendirildi (1,3 → 1,6).
uniform float intensity = 1.6;

void vertex() {
	vec4 center = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	center.xy += (UV - 0.5) * UV2.x;
	POSITION = PROJECTION_MATRIX * center;
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float glow = pow(clamp(1.0 - d, 0.0, 1.0), 2.2);
	// Vertex renginin alfası her haleye farklı titreme evresi verir.
	float flicker = 0.88 + 0.12 * sin(TIME * 6.0 + COLOR.a * 40.0);
	ALBEDO = COLOR.rgb;
	ALPHA = glow * intensity * flicker;
}
