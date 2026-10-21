shader_type spatial;
render_mode specular_disabled;
uniform vec4 pigment : source_color = vec4(0.25, 0.28, 0.27, 1.0);
uniform int kind = 0;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
varying vec3 world;
varying vec3 world_normal;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec2 p = abs(world_normal.y) > 0.7 ? world.xz : vec2(abs(world_normal.x) > 0.7 ? world.z : world.x, world.y);
	float grain = hash(floor(p * 390.0));
	vec3 col = pigment.rgb;
	if (kind == 0 || kind == 1) {
		vec2 unit = kind == 0 ? vec2(0.64, 0.24) : vec2(0.85, 1.4);
		vec2 grid = p / unit;
		grid.x += mod(floor(grid.y), 2.0) * 0.5;
		vec2 f = fract(grid);
		float edge = min(min(f.x, 1.0-f.x) * unit.x, min(f.y, 1.0-f.y) * unit.y);
		float seam = smoothstep(0.008, 0.022, edge);
		col *= mix(0.3, 0.85 + hash(floor(grid)) * 0.23, seam);
		col += smoothstep(0.019, 0.024, edge) * (1.0-smoothstep(0.024, 0.035, edge)) * 0.028;
	} else if (kind == 2) {
		float rings = sin(p.x * 110.0 + sin(p.y * 3.2 + p.x * 8.0) * 2.3);
		col *= 0.86 + rings * 0.1 + sin(p.x * 310.0 + p.y) * 0.035;
	}
	if (kind != 3) {
		vec2 tile = vec2(2.8);
		vec2 quadrant = vec2(0.0);
		if (kind == 1) { quadrant = vec2(0.5, 0.0); }
		if (kind == 2) { quadrant = vec2(0.0, 0.5); tile = vec2(1.2, 3.8); }
		if (kind == 4) { quadrant = vec2(0.5); tile = vec2(2.8, 0.65); }
		vec2 uv = quadrant + vec2(0.002) + fract(p / tile) * 0.496;
		vec3 texel = texture(atlas, uv).rgb;
		col = texel * (kind == 2 ? mix(vec3(0.55), vec3(1.1), pigment.rgb / vec3(0.29, 0.17, 0.13)) : vec3(1.12));
	}
	ALBEDO = col * (0.97 + grain * 0.06);
	ROUGHNESS = 0.85;
}
