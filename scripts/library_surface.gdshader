shader_type spatial;
uniform int kind = 2;
uniform vec4 pigment : source_color;
uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
varying vec3 world;
varying vec3 normal_world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	normal_world = normalize((MODEL_MATRIX * vec4(NORMAL,0.0)).xyz);
}
void fragment() {
	vec2 p = abs(normal_world.y)>0.7 ? world.xz : vec2(abs(normal_world.x)>0.7 ? world.z : world.x,world.y);
	vec2 offset = kind == 4 ? vec2(0.5) : vec2(0.0,0.5);
	vec2 tile = kind == 4 ? vec2(3.4,1.3) : vec2(3.8,6.0);
	vec3 texel = texture(atlas,offset+0.003+fract(p/tile)*0.494).rgb;
	float grey = dot(texel,vec3(0.3,0.59,0.11));
	ALBEDO = mix(vec3(grey),texel,0.35) * vec3(0.42,0.39,0.33);
	ROUGHNESS = 0.72;
	SPECULAR = 0.18;
}
