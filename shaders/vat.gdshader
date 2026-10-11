shader_type spatial;
// Gegner mit Animations-Textur (Vertex-Animation-Texture): Die Form jedes Bildes steht in drei Texturen
// (Position obere 8 Bit, untere 8 Bit, Normale); eine Spalte je Eckpunkt, eine Zeile(ngruppe) je gespeichertem Bild.
// Kein Skelett zur Laufzeit – Hunderte Figuren laufen in EINEM MultiMesh.
//
// Je Instanz:
//   INSTANCE_CUSTOM.x = Clip A + 16 * Blick (0 = aus, 1..31 = Pupillen von links nach rechts) + 512 * Zubehör weg
//   INSTANCE_CUSTOM.y = Fortschritt in Clip A (0..1)
//   INSTANCE_CUSTOM.z = Clip B + Mischung (0..0,99: so viel von Clip B ist noch zu sehen – Überblenden)
//   INSTANCE_CUSTOM.w = Fortschritt in Clip B
//   Instanzfarbe rgb  = Färbung (Zustand: brennt, vereist, vergiftet, markiert; Familienfarbe), a = Trefferblitz 0..1,
//                       über 1: Figur ist besiegt und versinkt (a - 1 = Fortschritt)
// Mesh: UV = (Leuchten, Kennung: 1/3 Pupille, 2/3 Zubehör, 1 durchscheinend), UV2 = Spalte / Zeile in der Textur.
// Bewusst nur texelFetch ohne Filter und ohne Mipmaps: läuft gleich im Mobile- und im Kompatibilitäts-Renderer.

uniform sampler2D vat_hi : filter_nearest, repeat_disable;
uniform sampler2D vat_lo : filter_nearest, repeat_disable;
uniform sampler2D vat_n : filter_nearest, repeat_disable;
uniform vec3 pos_min = vec3(-1.0);
uniform vec3 pos_size = vec3(2.0);
uniform float tex_w = 256.0;
uniform float rpf = 1.0;                 // Zeilen je Bild (mehr als 1024 Eckpunkte)
uniform vec4 clips[16];                  // x = erste Bildnummer, y = Anzahl Bilder, z = 1 Schleife
uniform float look_amt = 0.035;          // so weit wandern Pupillen (Meter)
uniform float sink_depth = 1.0;
uniform float fly_height = 0.0;
uniform float rough = 0.55;

varying float v_flash;
varying float v_glow;
varying float v_ghost;

vec3 vat_pos(ivec2 vc, int frame) {
	ivec2 tc = ivec2(vc.x, frame * int(rpf) + vc.y);
	vec3 hi = texelFetch(vat_hi, tc, 0).rgb;
	vec3 lo = texelFetch(vat_lo, tc, 0).rgb;
	return (hi * 65280.0 + lo * 255.0) / 65535.0 * pos_size + pos_min;
}

vec3 vat_nrm(ivec2 vc, int frame) {
	ivec2 tc = ivec2(vc.x, frame * int(rpf) + vc.y);
	return texelFetch(vat_n, tc, 0).rgb * 2.0 - 1.0;
}

void clip_sample(ivec2 vc, int ci, float phase, out vec3 p, out vec3 n) {
	vec4 c = clips[ci];
	float cnt = max(c.y, 1.0);
	bool loop = c.z > 0.5;
	float f = clamp(phase, 0.0, 1.0) * (loop ? cnt : cnt - 1.0);
	float f0 = floor(f);
	float fr = f - f0;
	int i0 = int(f0);
	int i1 = i0 + 1;
	int icnt = int(cnt);
	if (loop) {
		i0 = i0 % icnt;
		i1 = i1 % icnt;
	} else {
		i0 = min(i0, icnt - 1);
		i1 = min(i1, icnt - 1);
	}
	int base = int(c.x);
	p = mix(vat_pos(vc, base + i0), vat_pos(vc, base + i1), fr);
	n = vat_nrm(vc, base + (fr < 0.5 ? i0 : i1));
}

void vertex() {
	ivec2 vc = ivec2(int(UV2.x * tex_w), int(UV2.y * rpf));
	float cx = INSTANCE_CUSTOM.x + 0.5;
	float hide = floor(cx / 512.0);
	cx -= hide * 512.0;
	float look = floor(cx / 16.0);
	int clip_a = int(cx - look * 16.0);
	float cz = INSTANCE_CUSTOM.z;
	int clip_b = int(floor(cz));
	float blend = cz - floor(cz);
	vec3 p;
	vec3 n;
	clip_sample(vc, clip_a, INSTANCE_CUSTOM.y, p, n);
	if (blend > 0.01) {
		vec3 p2;
		vec3 n2;
		clip_sample(vc, clip_b, INSTANCE_CUSTOM.w, p2, n2);
		p = mix(p, p2, blend);
		n = mix(n, n2, blend);
	}
	float code = UV.y * 3.0;
	// Pupillen folgen dem Helden (seitlich verschieben)
	if (code > 0.5 && code < 1.5 && look > 0.5) {
		p.x += ((look - 16.0) / 15.0) * look_amt;
	}
	// Zubehör (Helm) ausblenden
	if (code > 1.5 && code < 2.5 && hide > 0.5) {
		p = vec3(0.0);
	}
	float a = COLOR.a;
	float sink = clamp(a - 1.0, 0.0, 1.0);
	p.y += fly_height * (1.0 - sink) - sink * sink_depth;
	VERTEX = p;
	NORMAL = normalize(n);
	v_flash = a > 1.0 ? 0.0 : a;
	v_glow = UV.x;
	v_ghost = step(2.5, code);
}

void fragment() {
	vec3 c = COLOR.rgb;
	if (v_ghost > 0.5) {
		// durchscheinend ohne Sortier-Probleme: Schachbrett aus Bildpunkten
		ivec2 px = ivec2(FRAGCOORD.xy);
		if (((px.x + px.y) & 1) == 0) {
			discard;
		}
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = 0.4;
	RIM = 0.25;
	RIM_TINT = 0.5;
	EMISSION = vec3(1.0) * v_flash * 0.5 + c * (0.05 + v_glow * 1.6 + v_ghost * 0.3);
}
