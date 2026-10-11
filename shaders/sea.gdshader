shader_type spatial;
// Meer der Hauptbasis (V3, Paket 5): Südwest-Ecke der Karte. Die Uferlinie wird hier genauso berechnet wie in
// base_nature.gd (shore_at); am Ufer läuft eine Schaumkante, die mit den Wellen vor- und zurückrollt.
uniform vec3 col_shallow : source_color = vec3(0.35, 0.82, 0.88);
uniform vec3 col_deep : source_color = vec3(0.12, 0.45, 0.82);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float coast_s = 69.0;
uniform float wet = 0.0;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float shore(vec2 p) {
	float t = (p.x + p.y) * 0.70710678;
	return coast_s + sin(t * 0.13) * 1.2 + sin(t * 0.31 + 1.0) * 0.6;
}

void fragment() {
	float s = (-wpos.x + wpos.z) * 0.70710678;
	float t = (wpos.x + wpos.z) * 0.70710678;
	float wave = sin(TIME * 0.8 + t * 0.05) * 0.5 + 0.5;
	float d = s - shore(wpos.xz) + wave * 0.9 - 0.4;
	if (d < 0.0) {
		discard;
	}
	float a = texture(noise_tex, wpos.xz * 0.05 + TIME * vec2(0.02, 0.012)).r;
	float b = texture(noise_tex, wpos.xz * 0.09 - TIME * vec2(0.015, 0.022)).r;
	float w = a * b * 2.2;
	vec3 c = mix(col_shallow, col_deep, smoothstep(1.0, 14.0, d));
	c = mix(c, c * 1.25, smoothstep(0.3, 0.75, w));
	// Schaumkante am Strand und eine zweite, weiter draußen laufende Welle
	float edge = 1.0 - smoothstep(0.0, 0.9 + (w - 0.5) * 0.6, d);
	float roll = fract(TIME * 0.12 + t * 0.002);
	float line2 = smoothstep(0.25, 0.0, abs(d - (1.5 + (1.0 - roll) * 5.0))) * roll * (0.6 + 0.4 * b);
	float crest = smoothstep(0.045, 0.0, abs(w - 0.58)) * 0.5;
	c = mix(c, vec3(1.0), clamp(edge + line2 * 0.7 + crest, 0.0, 1.0));
	ALBEDO = c * 0.78;
	ROUGHNESS = 0.08;
	SPECULAR = 0.75;
	EMISSION = vec3(1.0) * pow(max(sin(w * 40.0 + TIME * 2.0), 0.0), 18.0) * 0.25;
}
