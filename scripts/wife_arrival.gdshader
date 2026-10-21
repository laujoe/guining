shader_type canvas_item;
render_mode unshaded;
uniform sampler2D image_a : source_color, filter_linear, repeat_disable;
uniform sampler2D image_b : source_color, filter_linear, repeat_disable;
uniform float shot_a = 0.0;
uniform float shot_b = 1.0;
uniform float blend_amount = 0.0;
uniform float film_time = 0.0;
uniform float motion_amount = 1.0;
uniform float darkness = 0.0;
uniform float footer = 0.28;

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }
float patch(vec2 p, vec2 center, vec2 radius) {
	vec2 q = (p - center) / radius;
	return exp(-dot(q * q, q * q));
}

vec3 shot(sampler2D picture, vec2 screen_uv, float index) {
	float t = film_time;
	float local_t = max(0.0, t - (index < 0.5 ? 0.0 : (index < 1.5 ? 5.5 : 11.4)));
	float progress = smoothstep(0.0, 7.0, local_t);
	float z = 1.018 + 0.026 * progress * motion_amount;
	vec2 focus = index < 0.5 ? vec2(0.66, 0.48) : vec2(0.66, 0.44);
	vec2 p = (screen_uv - focus) / z + focus;
	vec2 uv = p;
	// Only trailing fabric/foliage moves. Keep faces, reins and architecture stable.
	float cloth = index < 0.5 ? patch(p, vec2(0.29, 0.36), vec2(0.12, 0.10)) :
		(index < 1.5 ? patch(p, vec2(0.21, 0.52), vec2(0.15, 0.10)) + patch(p, vec2(0.79, 0.78), vec2(0.09, 0.13)) :
		patch(p, vec2(0.12, 0.53), vec2(0.12, 0.15)) + patch(p, vec2(0.83, 0.79), vec2(0.10, 0.12)));
	float foliage = patch(p, vec2(0.23, 0.06), vec2(0.19, 0.055));
	float gust = index > 1.5 ? 1.7 : 1.0;
	uv.x += sin(p.y * 34.0 - t * 2.1) * (cloth * 0.0015 * gust + foliage * 0.0008) * motion_amount;
	uv.y += sin(t * 1.7 + p.x * 26.0) * cloth * 0.0007 * motion_amount;
	vec3 color = texture(picture, clamp(uv, vec2(0.001), vec2(0.999))).rgb;
	if (index < 0.5) {
		float valley = patch(p, vec2(0.74, 0.48), vec2(0.27, 0.18));
		float mist = sin(p.x * 16.0 - t * 0.20 + sin(p.y * 26.0)) * 0.5 + 0.5;
		color = mix(color, vec3(0.82, 0.83, 0.79), valley * mist * 0.075 * motion_amount);
		// Hoof dust stays on the road beneath the horse.
		float dust = patch(p, vec2(0.22, 0.90), vec2(0.27, 0.12));
		color += vec3(0.55, 0.46, 0.33) * dust * (0.5 + 0.5 * sin(p.x * 41.0 + p.y * 35.0 - t * 2.6)) * 0.06 * motion_amount;
	} else {
		float lanterns = patch(p, vec2(0.51, 0.26), vec2(0.065, 0.13)) + patch(p, vec2(0.95, 0.12), vec2(0.06, 0.15));
		color += vec3(1.0, 0.61, 0.23) * lanterns * (sin(t * 3.1) * 0.014 + sin(t * 6.7) * 0.006) * motion_amount;
	}
	// Sparse foreground petals/leaves drift with the wind, without masking faces.
	for (int i = 0; i < 16; i++) {
		float n = float(i);
		float speed = (0.022 + hash(n + 8.0) * 0.026) * gust;
		vec2 center = vec2(fract(hash(n + 1.0) + t * speed), fract(hash(n + 30.0) - t * speed * 0.35));
		center.y += sin(t * 1.2 + n) * 0.016;
		vec2 q = p - center;
		float angle = t * 1.1 + n;
		q = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * q;
		q /= vec2(0.0035 + hash(n + 10.0) * 0.003, 0.0017);
		float leaf = (1.0 - smoothstep(0.5, 1.25, dot(q, q))) * 0.35 * motion_amount;
		color = mix(color, mix(vec3(0.64, 0.49, 0.27), vec3(0.93, 0.88, 0.73), hash(n + 2.0)), leaf);
	}
	return color;
}

void fragment() {
	vec3 color = mix(shot(image_a, UV, shot_a), shot(image_b, UV, shot_b), blend_amount);
	float vignette = smoothstep(0.30, 0.78, distance(UV, vec2(0.5)));
	color *= 1.0 - vignette * 0.18;
	color *= 1.0 - smoothstep(0.76, 1.0, UV.y) * footer;
	color *= 1.0 - darkness;
	COLOR = vec4(color, 1.0);
}
