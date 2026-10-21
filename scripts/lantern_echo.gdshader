shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D frames : source_color;
uniform float age = 0.0;
void fragment() {
	vec3 ready = texture(frames, vec2(UV.x / 3.0, UV.y)).rgb;
	vec3 pour = texture(frames, vec2((UV.x + 1.0) / 3.0, UV.y)).rgb;
	vec3 rest = texture(frames, vec2((UV.x + 2.0) / 3.0, UV.y)).rgb;
	vec3 col = mix(ready, pour, smoothstep(1.65, 2.1, age));
	col = mix(col, rest, smoothstep(3.7, 4.15, age));
	float border = smoothstep(0.0, 0.18, UV.x) * smoothstep(0.0, 0.18, 1.0-UV.x) * smoothstep(0.0, 0.15, UV.y) * smoothstep(0.0, 0.15, 1.0-UV.y);
	float fade = smoothstep(0.6, 1.5, age) * (1.0-smoothstep(4.6, 5.8, age));
	ALBEDO = col * vec3(0.9, 0.79, 0.61);
	ALPHA = border * fade * 0.85;
}
