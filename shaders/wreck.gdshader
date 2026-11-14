shader_type spatial;
// Batık silueti: suyun altındaki kısımlar `reveal` düşükken suya karışır ve
// saydamlaşır; gemi yaklaştıkça (reveal → 1) belirginleşir. Su yüzeyinin
// üstünde kalan kırık direkler de uzaktan soluk görünür. Su düzleminden sonra
// çizilir (malzemenin render_priority değeri 1).

render_mode blend_mix, depth_draw_always, cull_back, specular_disabled;

uniform vec3 shadow_color : source_color = vec3(0.46, 0.42, 0.70);
uniform vec3 water_tint : source_color = vec3(0.10, 0.50, 0.66);
uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float band_softness = 0.5;

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float under = smoothstep(0.05, -0.5, world_y);
	// Yakından (reveal → 1) suyun renk karışımı neredeyse kalkar; sıcak ahşap görünür.
	float clarity = mix(0.15, 0.95, reveal);
	ALBEDO = mix(COLOR.rgb, water_tint, under * (1.0 - clarity));
	// Vertex rengi alfası 0 olan parçalar (sandık ışığı) ışık saçar.
	EMISSION = COLOR.rgb * (1.0 - COLOR.a) * 1.6 * reveal;
	ALPHA = mix(mix(0.35, 1.0, reveal), mix(0.22, 0.92, reveal), under);
	ROUGHNESS = 1.0;
}

void light() {
	float lit = smoothstep(0.0, band_softness, dot(NORMAL, LIGHT)) * ATTENUATION;
	DIFFUSE_LIGHT += mix(shadow_color, vec3(1.0), lit) * LIGHT_COLOR / PI;
}
