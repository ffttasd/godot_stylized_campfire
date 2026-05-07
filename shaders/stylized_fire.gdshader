shader_type spatial;

render_mode blend_mix, depth_draw_never, unshaded, cull_disabled;

uniform float detail_strength = 3.0;
uniform float scroll_speed = 1.2;
uniform float fire_height = 1.0;
uniform float fire_shape = 1.5;
uniform float fire_thickness = 0.55;
uniform float fire_sharpness = 1.0;
uniform float intensity = 1.0;
uniform float emission_energy = 1.8;
uniform float edge_glow_strength = 0.45;
uniform float color_variation_strength = 0.14;
uniform vec3 shadow_color : source_color = vec3(0.98, 0.36, 0.08);
uniform vec3 mid_color : source_color = vec3(1.0, 0.68, 0.2);
uniform vec3 light_color : source_color = vec3(1.0, 0.95, 0.8);
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.12;
uniform float mid_threshold : hint_range(0.0, 1.0) = 0.34;
uniform float light_threshold : hint_range(0.0, 1.0) = 0.7;
uniform float top_cutoff : hint_range(0.8, 1.0) = 0.985;

uniform int noise_octaves = 6;
uniform float noise_lacunarity = 3.0;
uniform float noise_gain = 0.5;
uniform float noise_amplitude = 1.0;
uniform float noise_frequency = 1.5;

float hash(vec2 p) {
	p = fract(p * 0.3183099 + vec2(0.1, 0.1));
	p *= 17.0;
	return fract(p.x * p.y * (p.x + p.y));
}

float noise(vec2 x) {
	vec2 p = floor(x);
	vec2 f = fract(x);

	float n =
		hash(p) * (1.0 - f.x) * (1.0 - f.y) +
		hash(p + vec2(1.0, 0.0)) * f.x * (1.0 - f.y) +
		hash(p + vec2(0.0, 1.0)) * (1.0 - f.x) * f.y +
		hash(p + vec2(1.0, 1.0)) * f.x * f.y;

	return n;
}

float fbm(vec2 p) {
	int octaves = noise_octaves;
	float lacunarity = noise_lacunarity;
	float gain = noise_gain;
	float amplitude = noise_amplitude;
	float frequency = noise_frequency;
	float total = 0.0;

	for (int i = 0; i < octaves; i++) {
		total += noise(p * frequency) * amplitude;
		frequency *= lacunarity;
		amplitude *= gain;
	}

	return total * 0.5;
}

void fragment() {
	vec2 uv = UV;

	vec2 modified_uv = -uv;
	modified_uv.x = mod(modified_uv.x, 1.0) - 0.5;
	modified_uv.y += 0.84;

	float scroll = scroll_speed * detail_strength * TIME;
	float fire_noise = fbm(detail_strength * modified_uv - vec2(0.0, scroll));

	float fire_intensity = intensity - 16.0 * fire_sharpness * pow(
		max(
			0.0,
			length(
				modified_uv * vec2((1.0 / fire_thickness) + modified_uv.y * fire_shape, 1.0 / fire_height)
			) - fire_noise * max(0.0, modified_uv.y + 0.25)
		),
		1.2
	);

	float fire_intensity1 = fire_noise * fire_intensity * (1.5 - pow(1.0 * uv.y, 14.0));
	fire_intensity1 = clamp(fire_intensity1, 0.0, 1.0);

	float shadow_band = step(shadow_threshold, fire_intensity1);
	float mid_band = step(mid_threshold, fire_intensity1);
	float light_band = step(light_threshold, fire_intensity1);

	vec3 fire_color = shadow_color;
	fire_color = mix(fire_color, mid_color, mid_band);
	fire_color = mix(fire_color, light_color, light_band);
	float color_variation = fbm(modified_uv * 2.35 + vec2(TIME * 0.17, -TIME * 0.31));
	fire_color *= 1.0 + (color_variation - 0.5) * color_variation_strength;

	float alpha = shadow_band * 0.38;
	alpha = max(alpha, mid_band * 0.7);
	alpha = max(alpha, light_band);
	float soft_edge = smoothstep(0.015, max(shadow_threshold, 0.08), fire_intensity1);
	float edge_glow = soft_edge * (1.0 - light_band * 0.45) * edge_glow_strength;
	alpha = max(alpha, edge_glow * 0.34);
	alpha *= step(uv.y, top_cutoff);

	if (alpha < 0.01) {
		discard;
	}

	vec4 final_color = vec4(
		mix(vec3(0.0), fire_color, alpha),
		alpha
	);

	ALBEDO = final_color.rgb;
	EMISSION = fire_color * emission_energy * clamp(fire_intensity1 + edge_glow, 0.0, 1.0);
	ALPHA = final_color.a;
}
