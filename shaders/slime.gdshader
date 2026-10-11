shader_type spatial;
// Schleimlinge: Hüpfen, Wabbeln, Angreifen und Zerplatzen komplett im Vertex-Shader,
// damit Hunderte gleichzeitig flüssig laufen.
// INSTANCE_CUSTOM = (Phase, Modus 0 laufen / 1 angreifen / 2 betäubt, Zeit seit Tod, Trefferblitz)

uniform float hop_speed = 7.0;
uniform float hop_height = 0.3;
uniform float fly_height = 0.0;
uniform float body_height = 0.9;
uniform float gamma = 2.2;

varying float v_dead;
varying float v_flash;

void vertex() {
	float phase = INSTANCE_CUSTOM.x;
	float mode = INSTANCE_CUSTOM.y;
	float dead = INSTANCE_CUSTOM.z;
	float alive = 1.0 - step(0.001, dead);
	float moving = (1.0 - clamp(mode, 0.0, 1.0)) * alive;
	float t = TIME * hop_speed + phase;
	vec3 v = VERTEX;
	// Helm (UV.x = 1) verschwindet, sobald der Schild gebrochen ist (Kennung im vierten Kanal)
	float w4 = INSTANCE_CUSTOM.w;
	float nohelm = step(1.5, w4);
	v *= 1.0 - nohelm * step(0.5, UV.x);
	// Stauchen und Strecken im Takt des Hüpfens
	float s = sin(t * 2.0);
	float squash = 1.0 + 0.16 * s * alive * (1.0 - step(1.5, mode));
	v.y *= squash;
	v.xz *= 1.0 / sqrt(max(squash, 0.5));
	// Wabbeln: oben stärker als unten
	float hgt = clamp(v.y / body_height, 0.0, 1.5);
	v.x += sin(t * 1.3 + v.y * 4.0) * 0.04 * hgt * alive;
	// Hüpfen
	v.y += abs(sin(t)) * hop_height * moving;
	v.y += fly_height * alive + sin(t * 0.7) * 0.2 * step(0.01, fly_height) * alive;
	// Angriff: nach vorn schnappen
	float atk = step(0.5, mode) * (1.0 - step(1.5, mode)) * alive;
	v.z += max(0.0, sin(TIME * 9.0 + phase)) * 0.35 * atk * hgt;
	// Tod: aufblähen und zerplatzen
	float d = clamp(dead / 0.3, 0.0, 1.0);
	float pop = mix(1.0, 1.45, smoothstep(0.0, 0.5, d)) * (1.0 - smoothstep(0.5, 1.0, d));
	v *= mix(1.0, pop, step(0.001, dead));
	VERTEX = v;
	v_dead = d;
	v_flash = w4 - 2.0 * nohelm;
}

void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(gamma)) * 1.15;
	ALBEDO = mix(c, vec3(1.0), v_dead * 0.25);
	ROUGHNESS = 0.28;
	SPECULAR = 0.7;
	RIM = 0.35;
	RIM_TINT = 0.6;
	EMISSION = vec3(1.0) * v_flash * 0.9 * (1.0 - v_dead) + c * 0.06;
}
