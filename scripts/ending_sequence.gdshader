shader_type canvas_item;
render_mode unshaded;

uniform sampler2D image_a : source_color, filter_linear, repeat_disable;
uniform sampler2D image_b : source_color, filter_linear, repeat_disable;
uniform vec3 camera_a = vec3(0.5, 0.5, 1.04);
uniform vec3 camera_b = vec3(0.5, 0.5, 1.04);
uniform float shot_a = 0.0;
uniform float shot_b = 0.0;
uniform float blend_amount = 0.0;
uniform float film_time = 0.0;
uniform float motion_amount = 1.0;
uniform float darkness = 0.0;
uniform float rain_strength = 0.18;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 scene(sampler2D picture, vec2 uv, vec3 camera, float shot) {
	float t = film_time * motion_amount;
	vec2 p = (uv - 0.5) / camera.z + camera.xy;
	// Only the exposed river moves: keep faces, hands and the scroll rigid.
	float river = smoothstep(0.62, 0.78, p.x) * smoothstep(0.48, 0.62, p.y);
	if (shot > 0.5) river = smoothstep(0.80, 0.94, p.y);
	if (shot > 1.5) river = smoothstep(0.61, 0.72, p.x) * smoothstep(0.32, 0.36, p.y) * (1.0 - smoothstep(0.40, 0.45, p.y));
	if (shot > 2.5) river = 0.0;
	p.x += sin(p.y * 100.0 + t * 1.8) * 0.0015 * river * motion_amount;
	p.y += sin(p.x * 80.0 - t * 1.3) * 0.0008 * river * motion_amount;
	vec3 color = texture(picture, p).rgb;
	// Warm light breathes only in existing gold highlights.
	float gold = smoothstep(0.08, 0.22, color.r - color.b) * smoothstep(0.35, 0.8, color.r);
	color += vec3(1.0, 0.65, 0.28) * gold * sin(t * 2.1) * 0.025 * motion_amount;
	// Slow mist and spectral light stay on the left foreground of the final shot.
	if (shot > 2.5 && shot < 3.5) {
		float soul = (1.0 - smoothstep(0.28, 0.48, p.x)) * smoothstep(0.3, 0.7, p.y);
		float mist = sin(p.x * 15.0 + p.y * 11.0 + t * 0.4) * 0.5 + 0.5;
		color += vec3(0.32, 0.48, 0.68) * soul * mist * 0.08 * motion_amount;
		vec2 particle_uv = p * vec2(40.0, 24.0) + vec2(t * 0.12, t * 0.45);
		vec2 cell = floor(particle_uv);
		float spark = (1.0 - smoothstep(0.025, 0.15, length(fract(particle_uv) - 0.5))) * step(0.94, hash(cell));
		color += vec3(0.5, 0.72, 1.0) * spark * soul * 0.6 * motion_amount;
	}
	if (shot > 7.5) {
		// In the first-person river shot, ink bleeds and the scroll darkens with weight.
		float weight = smoothstep(10.0, 28.0, film_time);
		float paper = smoothstep(0.34, 0.43, p.x) * (1.0 - smoothstep(0.57, 0.65, p.x)) * smoothstep(0.42, 0.53, p.y) * (1.0 - smoothstep(0.73, 0.82, p.y));
		float ink = 0.5 + 0.5 * sin(p.x * 67.0 + sin(p.y * 42.0) * 2.0);
		color *= 1.0 - paper * weight * (0.15 + ink * 0.12);
	}
	if (shot > 3.5 && shot < 7.5) {
		// Steam rises from the food only. No warping of faces, hands or brushwork.
		vec2 bowl = vec2(0.38, 0.53);
		if (shot > 4.5) bowl = vec2(0.23, 0.58);
		if (shot > 5.5) bowl = vec2(0.46, 0.79);
		if (shot > 6.5) bowl = vec2(0.69, 0.82);
		vec2 steam_p = p - bowl;
		float height = clamp(-steam_p.y / 0.17, 0.0, 1.0);
		float sway = sin(height * 8.0 - t * 0.8) * (0.005 + height * 0.008);
		float plume = exp(-pow((steam_p.x - sway) / (0.012 + height * 0.018), 2.0));
		float envelope = smoothstep(0.0, 0.025, -steam_p.y) * (1.0 - smoothstep(0.08, 0.17, -steam_p.y));
		float wisps = 0.55 + 0.45 * sin(height * 20.0 - t * 1.4);
		color += vec3(0.92, 0.84, 0.70) * plume * envelope * wisps * 0.085 * motion_amount;
		// A few soft, slowly drifting dust motes in the lamplight.
		vec2 dust_uv = p * vec2(46.0, 28.0) + vec2(t * 0.055, t * 0.10);
		float dust = (1.0 - smoothstep(0.025, 0.11, length(fract(dust_uv) - 0.5))) * step(0.975, hash(floor(dust_uv)));
		color += vec3(1.0, 0.76, 0.42) * dust * 0.12 * motion_amount;
	}
	return color;
}

void fragment() {
	vec2 uv = UV;
	vec3 color = mix(scene(image_a, uv, camera_a, shot_a), scene(image_b, uv, camera_b, shot_b), blend_amount);
	float t = film_time * motion_amount;
	// Two depths of rain share one clock across cuts.
	float rain = 0.0;
	for (int layer = 0; layer < 2; layer++) {
		float depth = float(layer);
		vec2 q = vec2(uv.x + uv.y * 0.20, uv.y) * vec2(170.0 + depth * 100.0, 25.0 + depth * 20.0);
		q.y -= t * (17.0 + depth * 9.0);
		vec2 cell = floor(q);
		vec2 local = fract(q);
		float streak = (1.0 - smoothstep(0.01, 0.09, abs(local.x - 0.5))) * smoothstep(0.0, 0.35, local.y) * (1.0 - smoothstep(0.65, 1.0, local.y));
		rain += streak * step(0.82, hash(cell)) * (0.07 - depth * 0.025);
	}
	color += rain * vec3(0.72, 0.80, 0.86) * motion_amount * rain_strength * 4.0;
	float vignette = smoothstep(0.25, 0.72, distance(uv, vec2(0.5)));
	color *= 1.0 - vignette * 0.25;
	color *= 1.0 - smoothstep(0.74, 0.96, uv.y) * 0.72;
	color *= 1.0 - darkness;
	// Letterbox without stretching the original 16:9 artwork.
	float image_area = smoothstep(0.055, 0.060, uv.y) * (1.0 - smoothstep(0.91, 0.915, uv.y));
	color = mix(vec3(0.018, 0.027, 0.032), color, image_area);
	COLOR = vec4(color, 1.0);
}
