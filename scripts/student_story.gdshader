shader_type canvas_item;
render_mode unshaded;
uniform sampler2D image_a : source_color, filter_linear, repeat_disable;
uniform sampler2D image_b : source_color, filter_linear, repeat_disable;
uniform float shot_a = 0.0;
uniform float shot_b = 0.0;
uniform float blend_amount = 0.0;
uniform float film_time = 0.0;
uniform float motion_amount = 1.0;
uniform float zoom = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 shot(sampler2D picture, vec2 p, float index) {
	vec2 uv = p;
	float t = film_time;
	// Local breathing is limited to cloth, below faces and away from fingers.
	vec2 robe = vec2(0.70, 0.53);
	if (index > 0.5 && index < 2.5) robe = vec2(0.30, 0.48);
	float cloth = exp(-pow(abs((p.x - robe.x) / 0.09), 4.0) - pow(abs((p.y - robe.y) / 0.12), 4.0));
	uv.y += sin(t * 1.25) * cloth * 0.0008 * motion_amount;
	// A small sway on the hanging lantern's tassel, without moving its frame.
	vec2 tassel = vec2(0.945, 0.23);
	if (index > 0.5 && index < 1.5) tassel = vec2(0.85, 0.35);
	if (index > 1.5 && index < 2.5) tassel = vec2(0.10, 0.14);
	float thread = exp(-pow(abs((p.x - tassel.x) / 0.012), 4.0) - pow(abs((p.y - tassel.y) / 0.055), 4.0));
	uv.x += sin(t * 0.85) * thread * 0.0012 * motion_amount;
	vec3 color = texture(picture, uv).rgb;
	float gold = smoothstep(0.16, 0.38, color.r - color.b) * smoothstep(0.5, 0.95, color.r);
	color += vec3(1.0, 0.65, 0.25) * gold * (sin(t * 2.8) * 0.012 + sin(t * 7.3) * 0.005) * motion_amount;
	// Dust moves through the corridor light; it does not pass over the faces.
	float corridor = 1.0 - smoothstep(0.12, 0.24, p.x);
	if (index < 0.5 || index > 2.5) corridor = smoothstep(0.86, 0.97, p.x);
	vec2 dust_uv = p * vec2(48.0, 26.0) + vec2(t * 0.035, t * 0.065);
	float dust = (1.0 - smoothstep(0.02, 0.12, length(fract(dust_uv) - 0.5))) * step(0.97, hash(floor(dust_uv)));
	color += vec3(1.0, 0.79, 0.49) * dust * corridor * 0.16 * motion_amount;
	return color;
}

void fragment() {
	// Preserve the full reference composition and aspect ratio, including the brush tip.
	vec2 framed = (UV - vec2(0.08, 0.0)) / 0.84;
	vec2 p = (framed - 0.5) / zoom + 0.5;
	vec3 color;
	if (framed.x >= 0.0 && framed.x <= 1.0 && framed.y >= 0.0 && framed.y <= 1.0) {
		color = mix(shot(image_a, p, shot_a), shot(image_b, p, shot_b), blend_amount);
		float edge = smoothstep(0.3, 0.78, length((framed - 0.5) * vec2(0.9, 1.0)));
		color *= 1.0 - edge * 0.13;
	} else {
		color = mix(texture(image_a, UV).rgb, texture(image_b, UV).rgb, blend_amount) * 0.13;
	}
	COLOR = vec4(color, 1.0);
}
