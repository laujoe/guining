shader_type canvas_item;
render_mode unshaded;
uniform sampler2D image_a : source_color, filter_linear, repeat_disable;
uniform sampler2D image_b : source_color, filter_linear, repeat_disable;
uniform float shot_a = 3.0;
uniform float shot_b = 3.0;
uniform float blend_amount = 1.0;
uniform float film_time = 0.0;
uniform float motion_amount = 1.0;
uniform float ink_strength = 0.4;
uniform float footer = 0.75;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float patch(vec2 p, vec2 center, vec2 radius) {
	vec2 q = (p - center) / radius;
	return exp(-dot(q * q, q * q));
}
vec3 shot(sampler2D picture, vec2 screen_uv, float index) {
	float t = film_time;
	float z = 1.0 + (0.018 + sin(t * 0.09) * 0.009) * motion_amount;
	vec2 p = (screen_uv - vec2(0.55, 0.44)) / z + vec2(0.55, 0.44);
	vec2 uv = p;
	// Local fabric breathing. Faces, hands, jade and report lettering stay rigid.
	vec2 robe_center = index > 4.5 ? vec2(0.81, 0.81) : (index > 3.5 ? vec2(0.37, 0.83) : vec2(0.86, 0.84));
	float robe = patch(p, robe_center, vec2(0.07, 0.09));
	uv.x += sin(t * 1.3 + p.y * 22.0) * robe * 0.0012 * motion_amount;
	vec3 color = texture(picture, uv).rgb;
	float lamps = patch(p, vec2(0.11, 0.27), vec2(0.08, 0.18)) + patch(p, vec2(0.91, 0.44), vec2(0.09, 0.23));
	if (index > 4.5) lamps = patch(p, vec2(0.88, 0.30), vec2(0.085, 0.18)) + patch(p, vec2(0.36, 0.56), vec2(0.06, 0.12));
	color += vec3(1.0, 0.65, 0.30) * lamps * (sin(t * 2.8) * 0.012 + sin(t * 5.9) * 0.005) * motion_amount;
	if (index > 0.5 && index < 1.5) {
		// A slow ink wash over the already stained paper, below the actors' hands.
		float paper = patch(p, vec2(0.65, 0.84), vec2(0.18, 0.07));
		float ink = 0.5 + 0.5 * sin(p.x * 36.0 + sin(p.y * 43.0) - t * 0.4);
		color *= 1.0 - ink * paper * ink_strength * 0.12 * motion_amount;
	}
	if (index > 1.5 && index < 2.5) {
		// Glints and drifting paper flecks stay around the dissolving left silhouette.
		for (int i = 0; i < 28; i++) {
			float n = float(i);
			vec2 seed = vec2(hash(vec2(n, 4.0)), hash(vec2(n, 9.0)));
			vec2 center = vec2(fract(seed.x - t * 0.035) * 0.53, fract(seed.y - t * 0.022) * 0.86);
			vec2 q = (p - center) * vec2(1.0, 0.5625);
			float angle = t * 0.7 + n;
			q = mat2(vec2(cos(angle), sin(angle)), vec2(-sin(angle), cos(angle))) * q;
			q /= vec2(0.003 + seed.x * 0.004, 0.0015);
			float fleck = 1.0 - smoothstep(0.7, 1.3, abs(q.x) + abs(q.y));
			color = mix(color, vec3(0.93, 0.88, 0.73), fleck * 0.48 * motion_amount);
		}
	}
	return color;
}

void fragment() {
	float blend = blend_amount;
	if (shot_a > 1.5 && shot_a < 2.5 && shot_b > 4.5 && motion_amount > 0.0) {
		// The left-hand paper image breaks up before the empty courtyard settles.
		float grain = hash(floor(UV * vec2(120.0, 68.0)));
		float threshold = UV.x * 0.45 + grain * 0.55;
		blend = smoothstep(threshold - 0.18, threshold + 0.18, blend_amount * 1.36 - 0.18);
	}
	vec3 color = mix(shot(image_a, UV, shot_a), shot(image_b, UV, shot_b), blend);
	// Two depths of soft snowfall; face regions receive fewer foreground flakes.
	for (int layer = 0; layer < 2; layer++) {
		float depth = float(layer);
		vec2 grid = vec2(36.0 - depth * 15.0, 20.0 - depth * 8.0);
		vec2 drift = vec2(film_time * (0.10 + depth * 0.07), -film_time * (0.40 + depth * 0.20));
		vec2 coord = UV * grid + drift;
		vec2 cell = floor(coord);
		vec2 seed = vec2(hash(cell), hash(cell + 17.0));
		vec2 q = fract(coord) - vec2(0.2 + seed.x * 0.6, 0.2 + seed.y * 0.6);
		float radius = 0.025 + seed.y * 0.035;
		float snow = (1.0 - smoothstep(radius * 0.2, radius, length(q))) * step(0.35, seed.x);
		float face_guard = 1.0 - patch(UV, vec2(0.67, 0.35), vec2(0.14, 0.23)) * 0.75;
		color = mix(color, vec3(0.92, 0.95, 0.98), snow * (0.42 + depth * 0.15) * face_guard * motion_amount);
	}
	color *= 1.0 - smoothstep(0.33, 0.76, distance(UV, vec2(0.5))) * 0.14;
	color *= 1.0 - smoothstep(0.77, 1.0, UV.y) * footer;
	color *= 1.0 - (1.0 - smoothstep(0.0, 0.16, UV.y)) * 0.18;
	COLOR = vec4(color, 1.0);
}
