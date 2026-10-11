shader_type spatial;
// Boden: zwei Grundfarben mit weichem Rauschen, Pfade aus einer Abstands-Textur,
// optional ein Raster (Baumodus der Hauptbasis).
// Lebendige Basis (V3, Paket 5): wahlweise vier Grüntöne in großen Flecken, eine Bodenmaske
// (R Weg, G Bach, B Sand, A Gebäudefläche) mit weicher Überblendung, Böen-Wellen, Nässe und Pfützen.
// Alle neuen Werte stehen standardmäßig auf „aus“ – die Expedition sieht aus wie bisher.

uniform sampler2D path_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 map_origin = vec2(-60.0);
uniform vec2 map_size = vec2(120.0);
uniform vec3 col_a : source_color = vec3(0.56, 0.69, 0.16);
uniform vec3 col_b : source_color = vec3(0.43, 0.6, 0.17);
uniform vec3 col_path : source_color = vec3(0.93, 0.66, 0.4);
uniform float use_path = 1.0;
uniform float grid_alpha = 0.0;
uniform float grid_cell = 2.0;
uniform vec2 grid_min = vec2(-24.0);
uniform vec2 grid_max = vec2(24.0);
// ---- lebendige Basis
uniform float patches = 0.0;
uniform vec3 col_c : source_color = vec3(0.30, 0.52, 0.16);
uniform vec3 col_d : source_color = vec3(0.70, 0.74, 0.22);
uniform float use_mask = 0.0;
uniform sampler2D mask_a : filter_linear, repeat_disable;
uniform sampler2D mask_b : filter_linear, repeat_disable;
uniform float mask_mix = 1.0;
uniform vec3 col_sand : source_color = vec3(0.93, 0.80, 0.55);
uniform vec3 col_water : source_color = vec3(0.25, 0.62, 0.88);
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float wind_phase = 0.0;
uniform float gust = 0.0;
uniform float wet = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = texture(noise_tex, wpos.xz * 0.018).r;
	float n2 = texture(noise_tex, wpos.xz * 0.11 + vec2(0.37, 0.11)).r;
	float n3 = texture(noise_tex, wpos.xz * 0.47).r;
	vec3 g = mix(col_b, col_a, smoothstep(0.3, 0.7, n));
	if (patches > 0.0) {
		// große, weiche Flecken in vier Grüntönen
		float p1 = texture(noise_tex, wpos.xz * 0.009 + vec2(0.51, 0.23)).r;
		float p2 = texture(noise_tex, wpos.xz * 0.023 + vec2(0.17, 0.71)).r;
		g = mix(g, col_c, smoothstep(0.5, 0.64, p1) * 0.85 * patches);
		g = mix(g, col_d, smoothstep(0.56, 0.7, p2) * 0.7 * patches);
		g *= 1.0 + (texture(noise_tex, wpos.xz * 0.06 + vec2(0.7, 0.2)).r - 0.5) * 0.25 * patches;
	}
	g *= 0.9 + 0.2 * n2;
	g *= 0.95 + 0.1 * n3;
	vec2 uv = (wpos.xz - map_origin) / map_size;
	float pd = texture(path_tex, uv).r * 8.0;
	float pe = (1.0 - smoothstep(1.6, 2.8, pd + (n2 - 0.5) * 1.2)) * use_path;
	vec3 pc = col_path * (0.9 + 0.2 * n3);
	// dunkler Saum am Wegrand wie im Referenzbild
	float rim = smoothstep(2.2, 2.8, pd + (n2 - 0.5) * 1.2) * (1.0 - smoothstep(2.8, 3.8, pd)) * use_path;
	vec3 c = mix(g, pc, pe);
	c = mix(c, g * 0.78, rim * 0.5);
	float puddle = 0.0;
	float water = 0.0;
	if (use_mask > 0.0) {
		vec4 m = mix(texture(mask_a, uv), texture(mask_b, uv), mask_mix);
		// Sand (Strand) mit feiner Körnung
		float sd = smoothstep(0.35, 0.65, m.b + (n2 - 0.5) * 0.3);
		c = mix(c, col_sand * (0.92 + 0.12 * n3), sd);
		// Trampelpfad: ausgefranster Rand aus feinem Rauschen, dunkler Saum, Steinchen
		float fr = m.r + (n3 - 0.5) * 0.42 + (n2 - 0.5) * 0.25;
		float pm = smoothstep(0.42, 0.55, fr);
		float prim = smoothstep(0.3, 0.42, fr) * (1.0 - pm);
		vec3 sandy = mix(col_path, col_sand, 0.45) * (0.86 + 0.24 * n3) * mix(1.0, 0.9, smoothstep(0.6, 0.75, n2));
		c = mix(c, c * 0.8, prim * 0.6);
		c = mix(c, sandy, pm);
		puddle = pm;
		// Bach: bewegtes Wasser mit hellen Kräuseln und Uferstreifen
		float bw = smoothstep(0.45, 0.6, m.g + (n2 - 0.5) * 0.2);
		float bank = smoothstep(0.2, 0.45, m.g) * (1.0 - bw);
		float wv = texture(noise_tex, wpos.xz * 0.2 + TIME * vec2(0.05, 0.03)).r * texture(noise_tex, wpos.xz * 0.33 - TIME * vec2(0.03, 0.06)).r;
		vec3 wc = mix(col_water * 0.8, col_water * 1.25, smoothstep(0.15, 0.4, wv));
		wc = mix(wc, vec3(1.0), smoothstep(0.38, 0.45, wv) * 0.6);
		c = mix(c, col_sand * 0.8, bank * 0.7);
		c = mix(c, wc, bw);
		water = bw;
	}
	// helle Böen-Wellen über die Wiese
	if (gust > 0.0) {
		float along = dot(wpos.xz, wind_dir);
		float side = texture(noise_tex, vec2(dot(wpos.xz, vec2(-wind_dir.y, wind_dir.x)) * 0.02, 0.3)).r;
		float band = gust * smoothstep(0.55, 1.0, sin(along * 0.12 - wind_phase)) * smoothstep(0.3, 0.6, side);
		c *= 1.0 + 0.16 * band * (1.0 - puddle) * (1.0 - water);
	}
	// Raster im Baumodus
	if (grid_alpha > 0.001) {
		vec2 gp = wpos.xz / grid_cell;
		vec2 f = abs(fract(gp) - 0.5);
		float line = smoothstep(0.46, 0.49, max(f.x, f.y));
		float inside = step(grid_min.x, wpos.x) * step(wpos.x, grid_max.x) * step(grid_min.y, wpos.z) * step(wpos.z, grid_max.y);
		c = mix(c, vec3(1.0), line * grid_alpha * inside);
		c = mix(c, c * 0.72, (1.0 - inside) * grid_alpha);
	}
	// ziehende Wolkenschatten
	float cl = texture(noise_tex, wpos.xz * 0.005 + TIME * vec2(0.007, 0.004)).r;
	c *= mix(0.8, 1.0, smoothstep(0.38, 0.6, cl));
	float rough = 0.95;
	float spec = 0.1;
	if (wet > 0.0) {
		// Nässe: dunkler; Pfützen (vor allem auf Wegen) glänzen
		float pz = smoothstep(0.66, 0.7, texture(noise_tex, wpos.xz * 0.13 + vec2(0.3, 0.6)).r + puddle * 0.08) * wet;
		c *= 1.0 - 0.2 * wet;
		c = mix(c, c * vec3(0.7, 0.8, 0.95), pz * 0.6);
		rough = mix(rough, 0.05, max(pz, water));
		spec = mix(spec, 0.9, pz);
	}
	if (water > 0.0) {
		rough = mix(rough, 0.1, water);
		spec = mix(spec, 0.7, water);
	}
	ALBEDO = c * 0.6;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
