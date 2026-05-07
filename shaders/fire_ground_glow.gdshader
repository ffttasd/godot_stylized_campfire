shader_type spatial;

render_mode blend_add, depth_draw_never, unshaded, cull_disabled;

uniform vec4 inner_color : source_color = vec4(1.0, 0.7, 0.24, 1.0);
uniform vec4 outer_color : source_color = vec4(1.0, 0.18, 0.03, 0.45);
uniform float intensity : hint_range(0.0, 8.0, 0.01) = 1.25;
uniform float radius : hint_range(0.1, 1.0, 0.01) = 0.86;
uniform float softness : hint_range(0.01, 1.0, 0.01) = 0.55;
uniform float noise_strength : hint_range(0.0, 1.0, 0.01) = 0.22;
uniform float pulse_speed : hint_range(0.0, 12.0, 0.01) = 2.4;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	centered.y *= 0.74;
	float dist = length(centered);

	float outer = 1.0 - smoothstep(max(radius - softness, 0.0), radius, dist);
	float inner = 1.0 - smoothstep(0.0, radius * 0.36, dist);
	float shimmer = noise(centered * 5.5 + vec2(TIME * 0.42, -TIME * 0.28));
	float pulse = 0.86 + 0.14 * sin(TIME * pulse_speed + shimmer * 5.0);

	float alpha = outer * pulse * intensity;
	alpha *= 1.0 + (shimmer - 0.5) * noise_strength;
	alpha = clamp(alpha, 0.0, 1.0);

	vec3 glow_color = mix(outer_color.rgb, inner_color.rgb, inner);
	ALBEDO = glow_color * alpha * 0.06;
	EMISSION = glow_color * alpha * intensity * 1.45;
	ALPHA = alpha * mix(outer_color.a, inner_color.a, inner);
}
