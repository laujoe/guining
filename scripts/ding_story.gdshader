shader_type canvas_item;
render_mode unshaded;
uniform sampler2D image_a : source_color, filter_linear, repeat_disable;
uniform sampler2D image_b : source_color, filter_linear, repeat_disable;
uniform float shot_a = 2.0;
uniform float shot_b = 2.0;
uniform float blend_amount = 0.0;
uniform float film_time = 0.0;
uniform float motion_amount = 1.0;
uniform float zoom = 1.015;
uniform float darkness = 0.0;
uniform float footer = 0.4;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 shot(sampler2D picture, vec2 p, float index) {
	float t = film_time;
	vec2 uv = p;
	if (index < 1.5) {
		// Local breathing in the fabric; faces, hands and the manuscript stay rigid.
		float robe = exp(-pow(abs((p.x - 0.23) / 0.15), 4.0) - pow(abs((p.y - 0.42) / 0.14), 4.0));
		uv.y += sin(t * 1.15) * robe * 0.0007 * motion_amount;
	}
	if (index > 2.5) {
		// Disturb water behind the envelope, never the lettering or wax seal.
		float water = 1.0 - smoothstep(0.20, 0.28, p.y);
		uv.x += sin(p.y * 95.0 + t * 1.8) * water * 0.0012 * motion_amount;
	}
	vec3 color = texture(picture, uv).rgb;
	if (index < 2.5) {
		vec2 flame = index > 1.5 ? vec2(0.858, 0.636) : vec2(0.868, 0.67);
		float light = exp(-dot((p - flame) * vec2(4.5, 3.0), (p - flame) * vec2(4.5, 3.0)));
		float flutter = sin(t * 3.7) * 0.016 + sin(t * 8.9) * 0.007;
		color += vec3(1.0, 0.64, 0.25) * light * flutter * motion_amount;
		// Narrow, rising wisps start on the rice, with no fog over the faces.
		vec2 bowl = index > 1.5 ? vec2(0.631, 0.756) : vec2(0.602, 0.79);
		float h = bowl.y - p.y;
		float x = p.x - bowl.x - sin(h * 55.0 - t * 0.7) * 0.008;
		float steam = exp(-pow(abs(x / 0.016), 2.0)) * smoothstep(0.0, 0.025, h) * (1.0 - smoothstep(0.06, 0.17, h));
		steam *= 0.55 + 0.45 * sin(h * 95.0 - t * 1.9);
		color += vec3(0.92, 0.85, 0.70) * steam * 0.13 * motion_amount;
		vec2 dust_uv = p * vec2(58.0, 32.0) + vec2(t * 0.025, t * 0.045);
		float dust = (1.0 - smoothstep(0.02, 0.10, length(fract(dust_uv) - 0.5))) * step(0.98, hash(floor(dust_uv)));
		color += vec3(1.0, 0.75, 0.4) * dust * light * 0.12 * motion_amount;
	} else {
		// Slanting rain, with sparse expanding ripples on the exposed ground.
		vec2 rain_uv = p * vec2(135.0, 12.0) + vec2(p.y * 14.0, -t * 5.0);
		float streak = (1.0 - smoothstep(0.01, 0.06, abs(fract(rain_uv.x) - 0.5))) * (1.0 - smoothstep(0.15, 0.85, fract(rain_uv.y)));
		streak *= step(0.85, hash(vec2(floor(rain_uv.x), 2.0)));
		color += vec3(0.64, 0.75, 0.85) * streak * 0.055 * motion_amount;
		vec2 cells = p * vec2(13.0, 32.0);
		float phase = fract(t * 0.5 + hash(floor(cells)));
		float ring = 1.0 - smoothstep(0.01, 0.035, abs(length(fract(cells) - 0.5) - phase * 0.4));
		float ground = smoothstep(0.19, 0.23, p.y) * (1.0 - smoothstep(0.26, 0.30, p.y));
		ground *= step(0.70, hash(floor(cells)));
		color += vec3(0.4, 0.55, 0.65) * ring * (1.0 - phase) * ground * 0.07 * motion_amount;
	}
	return color;
}

void fragment() {
	vec2 p = (UV - 0.5) / zoom + vec2(0.5, 0.5);
	vec3 color = mix(shot(image_a, p, shot_a), shot(image_b, p, shot_b), blend_amount);
	float edge = smoothstep(0.30, 0.78, length((UV - 0.5) * vec2(0.9, 1.0)));
	color *= 1.0 - edge * 0.24;
	color *= 1.0 - smoothstep(0.79, 0.98, UV.y) * footer;
	color *= 1.0 - darkness;
	COLOR = vec4(color, 1.0);
}
