shader_type spatial;
// Masalsı toon gölgeleme. Renk vertex renginden gelir (MeshBatcher).
// Vertex renginin alfası 0 ise parça ışık saçar (pencere, fener).

render_mode cull_back, specular_disabled;

uniform vec3 shadow_color : source_color = vec3(0.46, 0.42, 0.70);
uniform float band_softness : hint_range(0.01, 0.6) = 0.5;
uniform float emission_strength = 2.2;
uniform float rim_strength = 0.10;
// Compatibility renderer vertex rengini olduğu gibi kullanır; Forward+'a
// geçilirse true yapılmalıdır.
uniform bool vertex_color_srgb = false;

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void fragment() {
	vec3 base = vertex_color_srgb ? srgb_to_linear(COLOR.rgb) : COLOR.rgb;
	ALBEDO = base;
	ROUGHNESS = 1.0;
	EMISSION = base * (1.0 - COLOR.a) * emission_strength;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION += vec3(1.0, 0.96, 0.88) * rim * rim_strength;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, band_softness, ndl) * ATTENUATION;
	// LIGHT_COLOR, Godot'da enerji × PI içerir.
	DIFFUSE_LIGHT += mix(shadow_color, vec3(1.0), lit) * LIGHT_COLOR / PI;
}
