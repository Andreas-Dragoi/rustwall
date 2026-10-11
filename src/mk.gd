extends RefCounted
## Mesh-Baukasten: baut alle Modelle des Spiels aus einfachen Körpern zusammen.
## Jedes Modell wird zu EINEM Mesh mit Vertex-Farben verschmolzen (wenige Zeichenaufrufe).

static var _unshaded := {}


## Alle farbigen Modelle nutzen eigene kleine Shader. So werden Vertex-Farben in jedem Renderer
## (Mobile, Forward+, Kompatibilität) gleich behandelt – unabhängig von Engine-Schaltern.
const _SH := """shader_type spatial;
%s
uniform float gamma = 1.0;
uniform float boost = 1.0;
uniform float rough = 0.6;
uniform float metal = 0.0;
void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(gamma)) * boost;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.45;
	RIM = 0.2;
	RIM_TINT = 0.4;
}
"""
static var _mats := {}


static func _shader_mat(key: String, mode: String, gamma: float, boost: float, rough: float, metal: float) -> ShaderMaterial:
	if not _mats.has(key):
		var sh := Shader.new()
		sh.code = _SH % mode
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("gamma", gamma)
		m.set_shader_parameter("boost", boost)
		m.set_shader_parameter("rough", rough)
		m.set_shader_parameter("metal", metal)
		_mats[key] = m
	return _mats[key]


const _SH_WIND := """shader_type spatial;
uniform float boost = 1.0;
uniform float wind = 0.004;
void vertex() {
	// Wind: je höher der Punkt, desto stärker wiegt er sich (Bäume, Büsche, Gras)
	float h = max(VERTEX.y, 0.0);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float a = h * h * wind;
	VERTEX.x += sin(TIME * 1.6 + wp.x * 0.35 + wp.z * 0.27) * a;
	VERTEX.z += cos(TIME * 1.25 + wp.x * 0.21 - wp.z * 0.3) * a * 0.7;
}
void fragment() {
	ALBEDO = COLOR.rgb * boost;
	ROUGHNESS = 0.75;
	SPECULAR = 0.3;
	RIM = 0.15;
}
"""


## Material mit Windbewegung für Pflanzen aus Blender. wind = Stärke (Bäume ca. 0.004, Gras ca. 0.3).
static func mat_wind(wind: float) -> ShaderMaterial:
	var key := "wind%f" % wind
	if not _mats.has(key):
		var sh: Shader
		if _mats.has("_wind_shader"):
			sh = _mats["_wind_shader"]
		else:
			sh = Shader.new()
			sh.code = _SH_WIND
			_mats["_wind_shader"] = sh
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("boost", 1.15)
		m.set_shader_parameter("wind", wind)
		_mats[key] = m
	return _mats[key]


## Pflanzen der lebendigen Basis (V3, Paket 5): ein gemeinsamer Wind (Richtung, Stärke, Böen-Wellen), Neigen weg vom
## Helden, platt gedrücktes Gras hinter Fahrzeugen, Ausblenden auf Wegen/unter Gebäuden (Bodenmaske) und flach im
## Baumodus. Eigene Materialien – die Expedition benutzt weiter mat_wind() und bleibt unverändert.
const _SH_WIND3 := """shader_type spatial;
uniform float boost = 1.15;
uniform float wind = 0.3;
uniform float bend = 0.0;
uniform float masked = 0.0;
uniform float flat_ok = 0.0;
uniform float tint = 0.0;
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float wind_str = 0.5;
uniform float wind_phase = 0.0;
uniform float gust = 0.0;
uniform vec3 hero_pos = vec3(0.0, -100.0, 0.0);
uniform vec4 trample[16];
uniform float flat_k = 1.0;
uniform vec4 grid_rect = vec4(-44.0, -44.0, 44.0, 44.0);
uniform sampler2D mask_a : filter_linear, repeat_disable;
uniform sampler2D mask_b : filter_linear, repeat_disable;
uniform float mask_mix = 1.0;
uniform vec2 map_origin = vec2(-66.0);
uniform vec2 map_size = vec2(132.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 col_a : source_color = vec3(0.56, 0.69, 0.16);
uniform vec3 col_b : source_color = vec3(0.43, 0.6, 0.17);
uniform vec3 col_c : source_color = vec3(0.30, 0.52, 0.16);
uniform vec3 col_d : source_color = vec3(0.70, 0.74, 0.22);
varying float v_bright;
varying vec3 v_tint;
void vertex() {
	vec3 org = MODEL_MATRIX[3].xyz;
	float sc = max(length(MODEL_MATRIX[0].xyz), 0.0001);
	float hide = 0.0;
	if (masked > 0.5) {
		vec2 uv = (org.xz - map_origin) / map_size;
		vec4 m = mix(textureLod(mask_a, uv, 0.0), textureLod(mask_b, uv, 0.0), mask_mix);
		float rnd = fract(sin(dot(org.xz, vec2(12.9898, 78.233))) * 43758.5453);
		hide = step(0.3 + 0.45 * rnd, m.r) + step(0.3, m.g) + step(0.4 + 0.3 * rnd, m.b) + step(0.5, m.a);
	}
	v_bright = 0.0;
	v_tint = vec3(1.0);
	if (hide > 0.0) {
		VERTEX = vec3(0.0);
	} else {
		float inside = step(grid_rect.x, org.x) * step(org.x, grid_rect.z) * step(grid_rect.y, org.z) * step(org.z, grid_rect.w);
		VERTEX.y *= mix(1.0, flat_k, inside * flat_ok);
		float h = max(VERTEX.y, 0.0);
		float a = h * h * wind;
		float along = dot(org.xz, wind_dir);
		float band = gust * smoothstep(0.55, 1.0, sin(along * 0.12 - wind_phase));
		float sway = sin(TIME * (1.2 + wind_str * 1.6) + org.x * 0.35 + org.z * 0.27);
		vec2 side = vec2(-wind_dir.y, wind_dir.x);
		vec2 d = wind_dir * (wind_str * (0.55 + 0.45 * sway) + band * 1.3) + side * 0.22 * sin(TIME * 2.1 + org.z * 0.5) * wind_str;
		vec2 disp = d * a * 1.5;
		float squash = 0.0;
		if (bend > 0.0) {
			vec2 dh = org.xz - hero_pos.xz;
			float kh = bend * (1.0 - smoothstep(0.3, 1.5, length(dh)));
			disp += normalize(dh + vec2(0.0013, 0.0007)) * kh * h;
			for (int i = 0; i < 16; i++) {
				vec4 tr = trample[i];
				if (tr.w > 0.0) {
					squash = max(squash, tr.w * (1.0 - smoothstep(tr.z * 0.6, tr.z, length(org.xz - tr.xy))));
				}
			}
		}
		vec3 ld = transpose(mat3(MODEL_MATRIX)) * vec3(disp.x, 0.0, disp.y) / sc;
		VERTEX.xz += ld.xz;
		VERTEX.y *= 1.0 - 0.75 * squash;
		v_bright = band * min(h * 2.5, 1.0);
		if (tint > 0.0) {
			float n = textureLod(noise_tex, org.xz * 0.018, 0.0).r;
			float p1 = textureLod(noise_tex, org.xz * 0.009 + vec2(0.51, 0.23), 0.0).r;
			float p2 = textureLod(noise_tex, org.xz * 0.023 + vec2(0.17, 0.71), 0.0).r;
			vec3 g = mix(col_b, col_a, smoothstep(0.3, 0.7, n));
			g = mix(g, col_c, smoothstep(0.5, 0.64, p1) * 0.85);
			g = mix(g, col_d, smoothstep(0.56, 0.7, p2) * 0.7);
			v_tint = mix(vec3(1.0), g / max(col_a, vec3(0.01)), tint);
		}
	}
}
void fragment() {
	ALBEDO = COLOR.rgb * v_tint * boost * (1.0 + 0.4 * v_bright);
	ROUGHNESS = 0.75;
	SPECULAR = 0.3;
	RIM = 0.15;
}
"""
static var _wind3: Array = []


## Wind-Material der lebendigen Basis. bend = Neigen weg vom Helden, masked = auf Wegen ausblenden,
## flat_ok = im Baumodus flach, tint = Farbe an die Wiesenflecken angleichen.
static func mat_wind3(wind: float, bend := 0.0, masked := 0.0, flat_ok := 0.0, tint := 0.0) -> ShaderMaterial:
	var key := "wind3_%f_%f_%f_%f_%f" % [wind, bend, masked, flat_ok, tint]
	if not _mats.has(key):
		if not _mats.has("_wind3_shader"):
			var s := Shader.new()
			s.code = _SH_WIND3
			_mats["_wind3_shader"] = s
		var m := ShaderMaterial.new()
		m.shader = _mats["_wind3_shader"]
		m.set_shader_parameter("wind", wind)
		m.set_shader_parameter("bend", bend)
		m.set_shader_parameter("masked", masked)
		m.set_shader_parameter("flat_ok", flat_ok)
		m.set_shader_parameter("tint", tint)
		_mats[key] = m
		_wind3.append(m)
	return _mats[key]


## Alle Wind-Materialien der lebendigen Basis (weather.gd setzt Wind, Held und Maske gemeinsam).
static func wind3_mats() -> Array:
	return _wind3


static func mat_lin_metal() -> ShaderMaterial:
	return _shader_mat("lin_metal", "", 1.0, 1.25, 0.35, 0.55)


## Material für im Code gebaute Modelle (Vertex-Farben als sRGB-Werte).
static func mat() -> ShaderMaterial:
	return _shader_mat("mk", "", 2.2, 1.15, 0.62, 0.0)


static func mat_metal() -> ShaderMaterial:
	return _shader_mat("mk_metal", "", 2.2, 1.15, 0.4, 0.6)


## Material für Modelle aus Blender (.glb): Vertex-Farben liegen dort bereits linear vor.
static func mat_lin() -> ShaderMaterial:
	return _shader_mat("lin", "", 1.0, 1.15, 0.6, 0.0)


const _SH_FLAG := """shader_type spatial;
uniform vec3 from_col = vec3(0.0, 0.14, 0.85);
uniform vec3 to_col = vec3(0.0, 0.14, 0.85);
void fragment() {
	// alles, was die blaue Flaggenfarbe hat, bekommt die gewählte Farbe; Stern und Mast bleiben
	vec3 d = COLOR.rgb - from_col;
	float k = 1.0 - smoothstep(0.02, 0.09, dot(d, d));
	float lum = dot(COLOR.rgb, vec3(0.33)) / max(dot(from_col, vec3(0.33)), 0.001);
	ALBEDO = mix(COLOR.rgb, to_col * clamp(lum, 0.6, 1.2), k) * 1.15;
	ROUGHNESS = 0.6;
	SPECULAR = 0.45;
}
"""


## Material für Flaggen und Banner: tauscht das Flaggenblau gegen die Farbe des Spielers.
static func mat_flag() -> ShaderMaterial:
	if not _mats.has("flag"):
		var sh := Shader.new()
		sh.code = _SH_FLAG
		var m := ShaderMaterial.new()
		m.shader = sh
		var f := Color("026AED").srgb_to_linear()
		m.set_shader_parameter("from_col", Vector3(f.r, f.g, f.b))
		_mats["flag"] = m
		set_flag_color(P.flag_color())
	return _mats["flag"]


static func set_flag_color(c: Color) -> void:
	if _mats.has("flag"):
		var l := c.srgb_to_linear()
		(_mats["flag"] as ShaderMaterial).set_shader_parameter("to_col", Vector3(l.r, l.g, l.b))


## Leuchtende Teile von Blender-Modellen (Objektname enthält "_glow").
static func mat_glow() -> ShaderMaterial:
	return _shader_mat("glow", "render_mode unshaded;", 1.0, 1.6, 1.0, 0.0)


## Leuchtendes, unbeleuchtetes Material (für Lichter, Leuchtspuren, Balken).
static func glow(col: Color, transparent := false, on_top := false) -> StandardMaterial3D:
	var key := "%s%s%s" % [col.to_html(), transparent, on_top]
	if not transparent and _unshaded.has(key):
		return _unshaded[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if on_top:
		m.no_depth_test = true
		m.render_priority = 5
	if not transparent:
		_unshaded[key] = m
	return m


static func begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color, uv: Vector2) -> void:
	# Godot erwartet Vorderseiten im Uhrzeigersinn; Reihenfolge wird automatisch korrigiert.
	if (c - a).cross(b - a).dot(n) < 0.0:
		var t := b
		b = c
		c = t
	for p in [a, b, c]:
		st.set_normal(n)
		st.set_color(col)
		st.set_uv(uv)
		st.add_vertex(p)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color, uv: Vector2) -> void:
	_tri(st, a, b, c, n, col, uv)
	_tri(st, a, c, d, n, col, uv)


## Quader. c = Mittelpunkt, s = Größe. basis dreht den Quader um seinen Mittelpunkt.
static func box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, basis := Basis.IDENTITY, uv := Vector2.ZERO) -> void:
	var h := s * 0.5
	var ax := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for i in 3:
		var n: Vector3 = ax[i]
		var u: Vector3 = ax[(i + 1) % 3]
		var v: Vector3 = ax[(i + 2) % 3]
		var hn: float = h[i]
		var hu: float = h[(i + 1) % 3]
		var hv: float = h[(i + 2) % 3]
		for sgn in [1.0, -1.0]:
			var o: Vector3 = n * hn * sgn
			var p0: Vector3 = c + basis * (o - u * hu - v * hv)
			var p1: Vector3 = c + basis * (o + u * hu - v * hv)
			var p2: Vector3 = c + basis * (o + u * hu + v * hv)
			var p3: Vector3 = c + basis * (o - u * hu + v * hv)
			# leichte Abdunklung der Unterseite/Seiten für mehr Plastizität
			var shade := 1.0
			if i == 1 and sgn < 0.0:
				shade = 0.7
			elif i != 1:
				shade = 0.92 if i == 0 else 0.86
			var cc := Color(col.r * shade, col.g * shade, col.b * shade, col.a)
			_quad(st, p0, p1, p2, p3, (basis * (n * sgn)).normalized(), cc, uv)


## Zylinder / Kegelstumpf. base = Mittelpunkt der Unterseite, Achse = +Y (über basis drehbar).
static func cyl(st: SurfaceTool, base: Vector3, r0: float, r1: float, height: float, sides: int, col: Color,
		basis := Basis.IDENTITY, uv := Vector2.ZERO, caps := true) -> void:
	var top := Vector3(0, height, 0)
	for i in sides:
		var a0 := TAU * float(i) / sides
		var a1 := TAU * float(i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var b0 := base + basis * (d0 * r0)
		var b1 := base + basis * (d1 * r0)
		var t0 := base + basis * (d0 * r1 + top)
		var t1 := base + basis * (d1 * r1 + top)
		var n := (basis * (d0 + d1)).normalized()
		var sh := 0.82 + 0.18 * (0.5 + 0.5 * n.dot(Vector3(0.5, 0.3, 0.8).normalized()))
		var cc := Color(col.r * sh, col.g * sh, col.b * sh, col.a)
		_quad(st, b0, b1, t1, t0, n, cc, uv)
		if caps:
			if r1 > 0.001:
				_tri(st, base + basis * top, t0, t1, (basis * Vector3.UP).normalized(), col, uv)
			if r0 > 0.001:
				var cd := Color(col.r * 0.7, col.g * 0.7, col.b * 0.7, col.a)
				_tri(st, base, b0, b1, (basis * Vector3.DOWN).normalized(), cd, uv)


## Grobe Kugel / Felsbrocken. jitter > 0 verformt sie zufällig (für Felsen).
static func ball(st: SurfaceTool, c: Vector3, r: Vector3, col: Color, seed_val := 0, jitter := 0.0,
		rings := 5, segs := 7, uv := Vector2.ZERO) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val * 7919 + 13
	var pts := []
	for y in rings + 1:
		var row := []
		var phi := PI * float(y) / rings
		for x in segs:
			var th := TAU * float(x) / segs
			var d := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var k := 1.0
			if jitter > 0.0 and y > 0 and y < rings:
				k += rng.randf_range(-jitter, jitter)
			row.append(c + Vector3(d.x * r.x, d.y * r.y, d.z * r.z) * k)
		pts.append(row)
	for y in rings:
		for x in segs:
			var x1 := (x + 1) % segs
			var p00: Vector3 = pts[y][x]
			var p01: Vector3 = pts[y][x1]
			var p10: Vector3 = pts[y + 1][x]
			var p11: Vector3 = pts[y + 1][x1]
			for tri in [[p00, p01, p11], [p00, p11, p10]]:
				var a: Vector3 = tri[0]
				var b: Vector3 = tri[1]
				var cc: Vector3 = tri[2]
				var n := (b - a).cross(cc - a)
				if n.length_squared() < 1e-10:
					continue
				n = n.normalized()
				var mid := (a + b + cc) / 3.0
				if n.dot(mid - c) < 0.0:
					n = -n
				var sh := 0.78 + 0.22 * clampf(0.5 + 0.5 * n.y, 0.0, 1.0)
				if jitter > 0.0:
					sh *= rng.randf_range(0.92, 1.06)
				_tri(st, a, b, cc, n, Color(col.r * sh, col.g * sh, col.b * sh, col.a), uv)


## Quader mit abgeschrägten Kanten ("Spielzeug-Look" des Referenzbildes).
## bevel = Breite der Schräge in Metern.
static func rbox(st: SurfaceTool, c: Vector3, s: Vector3, col: Color, bevel := 0.08, basis := Basis.IDENTITY, uv := Vector2.ZERO) -> void:
	var h := s * 0.5
	var bv := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.8)
	var ax := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var hi := [h.x, h.y, h.z]
	var light := Color(minf(col.r * 1.12 + 0.03, 1.0), minf(col.g * 1.12 + 0.03, 1.0), minf(col.b * 1.12 + 0.03, 1.0), col.a)
	# sechs Flächen
	for i in 3:
		var u: int = (i + 1) % 3
		var v: int = (i + 2) % 3
		for sg in [1.0, -1.0]:
			var o: Vector3 = ax[i] * hi[i] * sg
			var du: Vector3 = ax[u] * (hi[u] - bv)
			var dv: Vector3 = ax[v] * (hi[v] - bv)
			var shade := 1.0
			if i == 1:
				shade = 1.06 if sg > 0.0 else 0.66
			else:
				shade = 0.93 if i == 0 else 0.84
			var cc := Color(minf(col.r * shade, 1.0), minf(col.g * shade, 1.0), minf(col.b * shade, 1.0), col.a)
			_quad(st, c + basis * (o - du - dv), c + basis * (o + du - dv), c + basis * (o + du + dv), c + basis * (o - du + dv),
				(basis * (ax[i] * sg)).normalized(), cc, uv)
	# zwölf Kanten (aufgehellt: sie fangen das Glanzlicht)
	for i in 3:
		var j: int = (i + 1) % 3
		var k: int = (i + 2) % 3
		for si in [1.0, -1.0]:
			for sj in [1.0, -1.0]:
				var n: Vector3 = (ax[i] * si + ax[j] * sj).normalized()
				var a0: Vector3 = ax[i] * hi[i] * si + ax[j] * (hi[j] - bv) * sj
				var b0: Vector3 = ax[i] * (hi[i] - bv) * si + ax[j] * hi[j] * sj
				var dk: Vector3 = ax[k] * (hi[k] - bv)
				var cc2 := light if n.y >= -0.1 else Color(col.r * 0.72, col.g * 0.72, col.b * 0.72, col.a)
				_quad(st, c + basis * (a0 - dk), c + basis * (b0 - dk), c + basis * (b0 + dk), c + basis * (a0 + dk), (basis * n).normalized(), cc2, uv)
	# acht Ecken
	for sx in [1.0, -1.0]:
		for sy in [1.0, -1.0]:
			for sz in [1.0, -1.0]:
				var p0 := Vector3(h.x * sx, (h.y - bv) * sy, (h.z - bv) * sz)
				var p1 := Vector3((h.x - bv) * sx, h.y * sy, (h.z - bv) * sz)
				var p2 := Vector3((h.x - bv) * sx, (h.y - bv) * sy, h.z * sz)
				var n2 := Vector3(sx, sy, sz).normalized()
				_tri(st, c + basis * p0, c + basis * p1, c + basis * p2, (basis * n2).normalized(), light if sy > 0.0 else col, uv)


## Kegel / Pyramide mit Spitze oben (Tannen, Dächer).
static func cone(st: SurfaceTool, base: Vector3, r: float, height: float, sides: int, col: Color, basis := Basis.IDENTITY, uv := Vector2.ZERO) -> void:
	cyl(st, base, r, 0.0, height, sides, col, basis, uv, true)


static func lighten(col: Color, k: float) -> Color:
	return Color(clampf(col.r * k, 0, 1), clampf(col.g * k, 0, 1), clampf(col.b * k, 0, 1), col.a)


static func commit(st: SurfaceTool) -> ArrayMesh:
	return st.commit()


## Erzeugt aus einem SurfaceTool eine fertige MeshInstance3D.
static func inst(st: SurfaceTool, parent: Node = null, pos := Vector3.ZERO, metal := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat_metal() if metal else mat()
	m.position = pos
	if parent:
		parent.add_child(m)
	return m


static func glow_box(parent: Node, pos: Vector3, size: Vector3, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = glow(col)
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


static func vary(col: Color, amt: float, rng: RandomNumberGenerator) -> Color:
	var k := 1.0 + rng.randf_range(-amt, amt)
	return Color(clampf(col.r * k, 0, 1), clampf(col.g * k, 0, 1), clampf(col.b * k, 0, 1), col.a)


## Balken (Leben) für die Welt. Rückgabe: Node3D mit Methode-ähnlichem Zugriff über set_meta.
static func make_bar(width: float, col: Color, height := 0.16) -> Node3D:
	var root := Node3D.new()
	var bg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width + 0.08, height + 0.08)
	bg.mesh = q
	bg.material_override = glow(Color(0.05, 0.05, 0.06), false, true)
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bg)
	var fill := MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(width, height)
	fill.mesh = q2
	var fm := glow(col, false, true).duplicate()
	fm.render_priority = 6
	fill.material_override = fm
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fill.position.z = 0.01
	root.add_child(fill)
	root.set_meta("fill", fill)
	root.set_meta("w", width)
	root.top_level = true
	return root


static func set_bar(bar: Node3D, ratio: float) -> void:
	var fill: MeshInstance3D = bar.get_meta("fill")
	var w: float = bar.get_meta("w")
	ratio = clampf(ratio, 0.0, 1.0)
	fill.scale.x = maxf(ratio, 0.001)
	fill.position.x = -w * (1.0 - ratio) * 0.5
