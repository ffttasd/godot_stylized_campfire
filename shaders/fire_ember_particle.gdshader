shader_type spatial;

render_mode blend_add, depth_draw_never, unshaded, cull_disabled;

uniform vec4 hot_color : source_color = vec4(1.0, 0.84, 0.34, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.28, 0.05, 1.0);
uniform float radius : hint_range(0.1, 1.0, 0.01) = 0.76;
uniform float softness : hint_range(0.01, 0.5, 0.01) = 0.18;
uniform float emission_energy : hint_range(0.0, 12.0, 0.01) = 3.2;
uniform float alpha_multiplier : hint_range(0.0, 2.0, 0.01) = 0.82;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float dist = length(centered);
	float disc = 1.0 - smoothstep(radius - softness, radius, dist);
	float core = 1.0 - smoothstep(0.0, radius * 0.46, dist);

	vec4 particle_color = COLOR;
	vec3 ember_color = mix(rim_color.rgb, hot_color.rgb, core);
	ember_color = mix(ember_color, particle_color.rgb, 0.35);

	float alpha = disc * particle_color.a * alpha_multiplier;
	if (alpha < 0.01) {
		discard;
	}

	ALBEDO = ember_color * alpha * 0.08;
	EMISSION = ember_color * alpha * emission_energy;
	ALPHA = alpha;
}
