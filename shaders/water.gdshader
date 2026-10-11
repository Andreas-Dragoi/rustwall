shader_type spatial;
// Wasser: zwei gegeneinander laufende Wellenmuster, helle Schaumlinien und Glitzern.
uniform vec3 col_deep : source_color = vec3(0.18, 0.5, 0.85);
uniform vec3 col_light : source_color = vec3(0.45, 0.78, 0.98);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float a = texture(noise_tex, wpos.xz * 0.06 + TIME * vec2(0.02, 0.012)).r;
	float b = texture(noise_tex, wpos.xz * 0.11 - TIME * vec2(0.015, 0.022)).r;
	float w = a * b * 2.2;
	vec3 c = mix(col_deep, col_light, smoothstep(0.25, 0.75, w));
	float foam = smoothstep(0.045, 0.0, abs(w - 0.55));
	c = mix(c, vec3(1.0), foam * 0.7);
	ALBEDO = c * 0.75;
	ROUGHNESS = 0.12;
	SPECULAR = 0.8;
	EMISSION = vec3(1.0) * pow(max(sin(w * 40.0 + TIME * 2.0), 0.0), 18.0) * 0.25;
}
