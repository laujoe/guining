shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec2 p = (UV - vec2(0.56, 0.58)) * vec2(1.28, 1.0);
	float vignette = smoothstep(0.30, 0.73, length(p));
	COLOR = vec4(0.0, 0.0, 0.0, vignette * 0.98);
}
