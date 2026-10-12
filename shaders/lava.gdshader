shader_type spatial;
render_mode unshaded, cull_disabled;
// Lavastrom der Vulkaninsel (Paket Z). UV.x = Meter entlang des Stroms, UV.y = quer (0..1).
// heat: 0 = erkaltete Kruste (begehbar), 1 = fließende Lava. warn: Risse der Kruste glühen auf (gleich kommt die Lava).
uniform float heat : hint_range(0.0, 1.0) = 1.0;
uniform float warn : hint_range(0.0, 1.0) = 0.0;
uniform float flow = 0.55;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;
	vec2 q = vec2(UV.x * 0.45 - TIME * flow, UV.y * 2.0);
	float n = vnoise(q * 1.7) * 0.6 + vnoise(q * 4.3 + 7.0) * 0.4;
	vec3 lava = mix(vec3(0.78, 0.13, 0.02), vec3(1.0, 0.52, 0.07), smoothstep(0.32, 0.72, n));
	lava = mix(lava, vec3(1.0, 0.88, 0.42), smoothstep(0.76, 0.95, n));
	float spots = smoothstep(0.58, 0.72, vnoise(q * 2.3 + 3.0)) * smoothstep(0.35, 1.0, across);
	lava = mix(lava, vec3(0.18, 0.1, 0.08), spots * 0.85);
	float cr = vnoise(vec2(UV.x * 1.4, UV.y * 3.0) * 2.0);
	float crack = smoothstep(0.07, 0.0, abs(cr - 0.5));
	vec3 crust = mix(vec3(0.16, 0.13, 0.13), vec3(0.25, 0.21, 0.2), vnoise(UV * vec2(3.0, 6.0)));
	float glow = 0.18 + 0.82 * warn;
	crust = mix(crust, vec3(1.0, 0.36, 0.05) * (0.5 + 0.7 * warn + 0.15 * sin(TIME * 6.0 + UV.x)), crack * glow);
	vec3 c = mix(crust, lava, heat);
	c *= mix(1.0, 0.5, smoothstep(0.72, 1.0, across));
	ALBEDO = c;
}
