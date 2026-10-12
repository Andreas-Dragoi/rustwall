extends Node3D
## Die Horde: alle Gegner liegen als schlanke Datenobjekte in einer Liste (keine Nodes), werden über ein Raster
## auseinandergehalten und je Art mit EINEM MultiMesh gezeichnet.
##  - Arten mit eigenem Modell (models/e_<key>.glb + _vat.png + .json) spielen echte, in Blender gemachte Animationen
##    aus einer Animations-Textur ab (shaders/vat.gdshader, src/vat.gd).
##  - Arten ohne eigenes Modell sehen vorläufig aus wie der Schleimling ihrer Rolle in der Farbe ihrer Familie.
##  - Schleimlinge ohne Animations-Textur nutzen weiter shaders/slime.gdshader (Hüpfen und Wabbeln im Shader).
## Das besondere Verhalten der Arten steckt als Bausteine in src/enemy_ai.gd; D.ENEMIES[t].ai nennt sie.

const D = preload("res://src/data.gd")
const MK = preload("res://src/mk.gd")
const Models = preload("res://src/models.gd")
const Vat = preload("res://src/vat.gd")
const AI = preload("res://src/enemy_ai.gd")
const BossFig = preload("res://src/boss_fig.gd")
const BossCtrl = preload("res://src/boss_ctrl.gd")
const EliteFx = preload("res://src/elite_fx.gd")
const LO = preload("res://src/liveops.gd")                 # Paket L: Ereignisse, Halloween, Albtraum+

const ST_MOVE := 0
const ST_ATTACK := 1
const ST_DEAD := 2
const ST_DOWN := 3            # liegt am Boden und steht gleich wieder auf (Baustein revive)
const CELL_INV := 1.0 / 1.4
const NEIGH := [0, 1, -1, 1024, -1024, 1025, 1023, -1023, -1025]
const BLEND_T := 0.1          # Überblenden zwischen zwei Clips (Sekunden)
const SINK_T := 0.6           # so lange versinkt eine besiegte Figur nach dem Sterbe-Clip
const FLY_ALT := 2.4


class E:
	var p := Vector2.ZERO      # Position (x, z)
	var v := Vector2.ZERO
	var kn := Vector2.ZERO     # Rückstoß
	var sep := Vector2.ZERO    # Abstoßung von Nachbarn
	var t := 0                 # Typ (Index in D.ENEMIES)
	var hp := 1.0
	var mhp := 1.0
	var st := 0
	var tm := 0.0              # Angriffs-Timer
	var dead_t := 0.0
	var ph := 0.0
	var sp := 1.0
	var sc := 1.0              # Größe gegenüber einem Schleimling (Effekte, Zielhöhe)
	var vs := 1.0              # Maßstab des gezeichneten Modells
	var r := 0.3
	var fl := 0.0              # Trefferblitz
	var yaw := 0.0
	var tgt = null             # angegriffenes Gebäude
	var tgt_player := false
	var tint := Color.WHITE
	var dm := 1.0              # Schadens-Faktor gegen Gebäude
	var dp := 1.0              # Schadens-Faktor gegen den Helden
	var hm := 1.0              # Lebens-Faktor, mit dem er erzeugt wurde (für Beschworene und Teilstücke)
	var key := 0
	var coins := 1
	var shield := 0
	var fly := false
	var alt := 0.0             # Flughöhe (Meter)
	var burn := 0.0
	var burn_d := 5.0
	var poison := 0.0
	var slow := 0.0
	var stun := 0.0
	var mark := 0.0
	var shrink := 0.0
	var root := 0.0
	var taunt := 0.0
	var chase := false
	var home := Vector2.ZERO
	var leash := 0.0           # > 0: bewacht einen Ort (Expedition), sonst folgt er dem Richtungsfeld
	var aggro := false
	var stat := false          # unbeweglich (Nest)
	var hide := false          # wird nicht gezeichnet (eigenes Modell)
	var on_death := Callable()
	var sp_t := 3.0
	var special := ""
	# ---- Animation (Animations-Textur)
	var ca := 0                # Clip A
	var ct := 0.0              # Fortschritt 0..1
	var cb := 0                # Clip B (läuft aus)
	var cbt := 0.0
	var bl := 0.0              # Anteil von Clip B
	var act := 0.0             # Restzeit eines einmaligen Clips (Angriff, Treffer, Sonder-Clip)
	var lc := -1               # Dauer-Clip statt idle/walk (eingegraben, in der Kiste …)
	var swung := false         # Angriffs-Clip für den nächsten Schlag läuft schon
	var dlim := 0.34           # so lange bleibt er nach dem Tod sichtbar
	var look := 0              # Blickrichtung der Pupillen (0 = aus)
	var fig = null             # Boss: echte Figur (BossFig)
	# ---- Verhaltens-Bausteine (src/enemy_ai.gd)
	var rng := 0.0             # Reichweite des Fernangriffs (0 = Nahkämpfer)
	var ai_s := 0              # Zustand des Bausteins
	var ai_t := 0.0            # Timer des Zustands
	var ai_c := 0.0            # Abklingzeit des Sonderangriffs
	var ai_d := 0.0
	var ai_n := 0
	var ai_v := Vector2.ZERO
	var goal := Vector2.ZERO   # eigenes Laufziel statt Richtungsfeld/Held
	var g_on := false
	var g_t := 0.0
	var buff := 0.0            # Aura des Seuchenarztes (Restzeit)
	var haste := 0.0           # Geheul des Rudelführers (Restzeit)
	var under := false         # unter der Erde
	var inv := 0.0             # unverwundbar (Restzeit)
	var carry := 0.0           # gestohlene Münzen
	var grow := 0.0            # Lawinenroller: 0..1
	var hit_t := 0.0           # Zeit seit dem letzten Treffer
	var revived := false
	var no_split := false
	var lead = null            # Schwarm: übernimmt Wachposten/Leine vom ersten Tier
	var hunter := false        # Elitegegner: jagt den Helden auf jede Entfernung, auch ohne Ziel-Gebäude
	var next_phase := ""       # Boss: diese Art bricht beim Tod hervor
	# ---- Paket G2
	var elite := false         # Elite-Gegner: Krone, Aura, Namensschild, eigene Farbe
	var kid := false           # Junges einer Brutmutter (brütet nicht selbst)
	var jam_tw = null          # Turmstörer: Ziel-Turm · Dieb: Ziel-Lager
	var loot := {}             # Dieb: gestohlene Rohstoffe
	var blk_t := -9.0          # Schildträger: letzter Block (Ton, Clip)
	var aimed := false         # Fernkämpfer: Vorbereitungs-Clip (knien, aufblähen) für den nächsten Schuss läuft schon
	var expose := 0.0          # Boss: erschöpft, Schwachstelle offen (Restzeit)
	var rage := false          # Boss: Wutphase
	var phase := 1             # Boss: Phase
	var specs: Array = []      # Boss: Sonderangriffe im Wechsel (ab Phase 2 mit Zusatz)
	var bait_t := 0.0          # Lockköder: läuft so lange zum Köder
	var bait_p := Vector2.ZERO


var list: Array = []
var alive := 0
var kills := 0
var boss: E = null
var boss_name := ""
var mini: E = null            # Miniboss mit eigener Lebensleiste (Paket G2)
var bossctl: RefCounted       # Phasen, Wut, Schwachstelle, Auftritt der Bosse (src/boss_ctrl.gd)
var elite_fx: Node3D          # Krone, Aura und Namensschild der Elite-Gegner und Minibosse (src/elite_fx.gd)
var _aoe := false             # gerade läuft Flächenschaden (explode): Schilde blocken ihn nicht
var _grid_ok := false         # Raster dieses Schritts ist vollständig (kein Gegner seither erzeugt)
var _siege_n := 0             # Expedition: gezählte Belagerungs-Gegner (jeder MINI_EXP_EVERY-te wird ein Miniboss)
var aggro_range := 13.0
var logic_ms := 0.0           # Rechenzeit der Logik je Schritt (geglättet)
var logic_last := 0.0         # … des letzten Schritts
var ai: RefCounted
var time := 0.0
var _vis: Array = []         # je Art: null oder {mm, mi, vat (Dictionary oder null), mat, tint, legacy_t}
var _flags: Array = []       # je Art: Bit-Maske der Bausteine
var _elite: Array = []
var _near: Array = []        # je Art: läuft den Helden an, wenn er sehr nah ist
var _slowmul: Array = []     # je Art: Tempo-Faktor, wenn verlangsamt
var _weak: Array = []        # je Art: Schwächen-Tabelle der Familie
var _grid := {}
var _frame := 0
var _rng := RandomNumberGenerator.new()
var _cnt: Array = []
var _time := 0.0
var _snd_hit := 0.0          # Ton: Zeitsperren für häufige Geräusche
var _snd_hop := 0.0
var _snd_trap := 0.0
var _snd_glue := 0.0
var _snd_roar := -99.0
var _snd_ok := {}
var _book := {}              # Monsterbuch: besiegte je Art seit dem letzten Abgleich
var _seen := {}
var _book_t := 0.0
var _portal_t := -1
var _fam_cache := {}
var _dbg_done := false


func _ready() -> void:
	_rng.seed = 4711
	ai = AI.new(self)
	bossctl = BossCtrl.new(self)
	elite_fx = EliteFx.new()
	add_child(elite_fx)
	_portal_t = int(D.ENEMY_INDEX.get("daemonen_portal", -1))
	for t in D.ENEMIES.size():
		var def: Dictionary = D.ENEMIES[t]
		_vis.append(null)
		_cnt.append(0)
		_flags.append(AI.flags_of(def))
		_elite.append(def.role == "tank" or def.role == "boss" or (t >= D.E_FIRST_NEW and def.role == "special") or t == D.E_SHAMAN
			or ["healer", "jammer", "brood", "thief", "miniboss"].has(String(def.role)))
		_near.append(t == D.E_SLIME or t == D.E_BARREL or (t >= D.E_FIRST_NEW and (def.role == "mass" or def.role == "special")))
		var fam: Dictionary = D.FAMILIES[def.family]
		_slowmul.append(1.0 - 0.45 * float(fam.get("slow", 1.0)))
		_weak.append(fam.weak)


func _exit_tree() -> void:
	_flush_book()


# ---------------------------------------------------------------- Modelle
## Legt das MultiMesh einer Art an, sobald die erste Figur gebraucht wird.
func _ensure_vis(t: int) -> Dictionary:
	if _vis[t] != null:
		return _vis[t]
	var def: Dictionary = D.ENEMIES[t]
	var vis := {"vat": null, "tint": Color.WHITE, "legacy_t": -1, "true_size": false, "src_k": 1.0}
	var key := String(def.key)
	var src_t := t
	if Vat.has(key):
		vis.vat = Vat.data(key)
		vis.true_size = true
	else:
		# Übergang: noch kein eigenes Modell – der Schleimling dieser Rolle in der Farbe der Familie
		if t >= D.E_FIRST_NEW:
			src_t = int(D.ROLE_FALLBACK.get(def.role, 0))
			vis.tint = D.FAMILY_TINT.get(def.family, Color.WHITE)
		var skey := String(D.ENEMIES[src_t].key)
		if Vat.has(skey):
			vis.vat = Vat.data(skey)
			if src_t == t:
				vis.true_size = true
			else:
				# das Schleim-Modell ist in seiner eigenen Spielgröße gebaut: auf die Größe dieser Art umrechnen
				vis.src_k = 1.0 / float(D.ENEMIES[src_t].scale)
		else:
			vis.legacy_t = src_t
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var mat: ShaderMaterial
	if vis.vat != null:
		mm.mesh = vis.vat.mesh
		mat = Vat.material(vis.vat)
	else:
		var lt: int = vis.legacy_t
		mm.mesh = _glb_mesh(lt)
		mat = ShaderMaterial.new()
		mat.shader = load("res://shaders/slime.gdshader")
		mat.set_shader_parameter("hop_speed", [7.0, 11.0, 7.5, 4.5, 6.0, 7.0, 9.0, 6.0, 3.2][lt])
		mat.set_shader_parameter("gamma", 1.0)
		mat.set_shader_parameter("hop_height", [0.3, 0.22, 0.26, 0.2, 0.22, 0.28, 0.0, 0.2, 0.35][lt])
		mat.set_shader_parameter("fly_height", 0.001 if def.get("fly", false) else 0.0)
	mm.instance_count = mini(int(def.max), G.max_alive()) + 8
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.custom_aabb = AABB(Vector3(-140, -6, -140), Vector3(280, 30, 280))
	if G.quality() == 0:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	vis["mm"] = mm
	vis["mi"] = mi
	vis["mat"] = mat
	_vis[t] = vis
	return vis


## Fasst Körper (und Helm) eines Blender-Schleimlings zu EINEM Mesh zusammen.
## Helm-Punkte bekommen UV.x = 1, damit der Shader sie ausblenden kann.
func _glb_mesh(t: int) -> ArrayMesh:
	var src: Node = Models._scene("e_%d" % t).instantiate()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for part in ["body", "helm"]:
		var mi := Models._find_mesh(src, part)
		if mi == null:
			continue
		var xf := mi.transform
		var par := mi.get_parent()
		while par != null and par is Node3D:
			xf = (par as Node3D).transform * xf
			par = par.get_parent()
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var c = arr[Mesh.ARRAY_COLOR]
			var idx = arr[Mesh.ARRAY_INDEX]
			var base := verts.size()
			var uv := Vector2(1, 0) if part == "helm" else Vector2.ZERO
			for k in v.size():
				verts.append(xf * v[k])
				normals.append((xf.basis * n[k]).normalized())
				colors.append(c[k] if c != null else Color.WHITE)
				uvs.append(uv)
			if idx != null:
				for k in idx:
					indices.append(base + k)
			else:
				for k in v.size():
					indices.append(base + k)
	src.free()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return am


# ---------------------------------------------------------------- Erzeugen
func spawn(t: int, pos: Vector2, hp_mult := 1.0, dmg_mult := 1.0, player_dmg := 1.0) -> E:
	var def: Dictionary = D.ENEMIES[t]
	var vis := _ensure_vis(t)
	var e := E.new()
	_grid_ok = false
	e.t = t
	e.p = pos
	e.mhp = def.hp * hp_mult
	e.hp = e.mhp
	e.hm = hp_mult
	e.sp = def.speed * _rng.randf_range(0.9, 1.1)
	var k0 := _rng.randf_range(0.93, 1.08)
	e.sc = def.scale * k0
	e.vs = k0 if vis.true_size else (e.sc * float(vis.src_k) if vis.vat != null else e.sc * D.CHAR_SCALE)
	e.r = def.radius
	e.ph = _rng.randf() * TAU
	e.dm = dmg_mult
	e.dp = player_dmg
	e.coins = int(def.coins)
	e.shield = int(def.get("shield", 0))
	e.fly = def.get("fly", false)
	e.alt = FLY_ALT if e.fly else 0.0
	e.rng = float(def.get("spit", def.get("range", 0.0)))
	e.sp_t = _rng.randf_range(2.0, 5.0)
	e.ai_c = _rng.randf_range(1.0, 3.0)
	var k := _rng.randf_range(0.9, 1.06)
	var tn: Color = vis.tint
	e.tint = Color(tn.r * k, tn.g * k * _rng.randf_range(0.96, 1.03), tn.b * k * _rng.randf_range(0.92, 1.0))
	e.yaw = _rng.randf() * TAU
	e.ct = _rng.randf()
	LO.on_spawn(e, def)                                       # Paket L: Kürbis-Schleime (Halloween), Albtraum+ Hast
	if vis.vat != null:
		e.dlim = float(vis.vat.dur[int(vis.vat.clips.get("death", 0))]) + SINK_T if vis.vat.clips.has("death") else 0.5
	list.append(e)
	alive += 1
	if not _seen.has(t):
		_seen[t] = true
	if def.get("boss", false):
		boss = e
		boss_name = String(def.name)
		if def.has("specials"):
			e.special = "cycle"
		var bi: Dictionary = Vat.boss_info(String(def.key))
		if not bi.is_empty():
			var fig := BossFig.new()
			add_child(fig)
			fig.setup(String(def.key), bi)
			e.fig = fig
			e.vs = k0
			e.dlim = fig.clip_len("death") + 1.0
		bossctl.on_spawn(e)
	elif def.role == "miniboss":
		if mini == null or mini.st == ST_DEAD:
			mini = e
		elite_fx.add(e)
		Sfx.play("miniboss_arrive", -4.0)
	_snd(e, "spawn", -14.0, 0.25)
	return e


## Erzeugt eine Art der Familie des Gebiets (D.AREA_FAMILY[area]). role: "" = beliebig (gewichtet), sonst
## mass | fast | tank | ranged | air | special; "elite" = die stärkste Nicht-Boss-Art mit erhöhtem Leben.
## Den Gebietsfaktor für Leben (D.AREA_HP) wendet der Aufrufer über hp_mult an.
func spawn_for_area(area: int, pos: Vector2, hp_mult := 1.0, dmg_mult := 1.0, player_dmg := 1.0, role := "") -> E:
	var fam := String(D.AREA_FAMILY[clampi(area, 0, D.AREA_FAMILY.size() - 1)])
	return spawn_family(fam, pos, hp_mult, dmg_mult, player_dmg, role)


func spawn_family(fam: String, pos: Vector2, hp_mult := 1.0, dmg_mult := 1.0, player_dmg := 1.0, role := "") -> E:
	prewarm(fam)
	var elite := role == "elite"
	# Rollen der Expedition: guard/raid = gemischt, siege = bevorzugt Brecher und Fernkämpfer
	if role == "guard" or role == "raid":
		role = ""
	if role == "siege" or role == "miniboss":
		# Expedition: der MINI_EXP_EVERY-te Belagerungs-Gegner ist der Miniboss der Familie (einmal je Kampf)
		_siege_n += 1
		var mt := D.family_mini(fam)
		if mt >= 0 and (role == "miniboss" or (_siege_n == D.MINI_EXP_EVERY and (mini == null or mini.st == ST_DEAD))):
			if role == "miniboss":
				return spawn(mt, pos, hp_mult, dmg_mult, player_dmg)
			# mitten im Großangriff: ein Zwischengegner, kein zweiter Endgegner (Leben und Schaden gedämpft)
			return spawn(mt, pos, hp_mult * D.MINI_EXP_HP, dmg_mult * 0.8, player_dmg * 0.8)
		if role == "miniboss":
			role = ""
	if role == "siege":
		role = ["tank", "ranged", ""][_rng.randi() % 3]
	var t := strongest_type(fam) if elite else pick_type(fam, role)
	var def: Dictionary = D.ENEMIES[t]
	var e := spawn(t, pos, hp_mult * (D.ELITE_HP if elite else 1.0), dmg_mult * (1.3 if elite else 1.0), player_dmg * (1.3 if elite else 1.0))
	if elite:
		make_elite(e)
	elif def.has("swarm"):
		# kommt als Schwarm: die übrigen Tiere stehen dicht beim ersten und übernehmen dessen Wachposten
		var n := _rng.randi_range(int(def.swarm[0]), int(def.swarm[1])) - 1
		for i in n:
			if alive >= G.max_alive() - 4:
				break
			var a := _rng.randf() * TAU
			var q := pos + Vector2(cos(a), sin(a)) * _rng.randf_range(0.5, 1.6)
			if G.field != null and G.field.is_solid(q):
				q = pos
			var o := spawn(t, q, hp_mult, dmg_mult, player_dmg)
			o.lead = e
			o.coins = 0 if i % 2 == 1 else o.coins
	return e


var _warm := {}


## Lädt Modelle und Animations-Texturen aller Arten einer Familie vorab (beim ersten Gegner der Familie bzw. beim Planen
## einer Welle), damit später beim Brüten, Teilen oder Beschwören kein Ruckler in der Gegner-Logik entsteht.
func prewarm(fam: String) -> void:
	if _warm.has(fam):
		return
	_warm[fam] = true
	for i in D.family_all(fam):
		_ensure_vis(i)
	var mt := D.family_mini(fam)
	if mt >= 0:
		_ensure_vis(mt)


## Macht einen Gegner zum Elite-Gegner (6.2): mehr Größe, Münzen, eigene Farbe, Krone, Aura und Namensschild; jagt den Helden.
## Das Leben stellt der Aufrufer ein (D.ELITE_HP).
func make_elite(e: E) -> void:
	e.elite = true
	e.sc *= 1.2
	e.vs *= 1.2
	e.r *= 1.15
	e.coins *= 3
	e.hunter = true
	e.tint = Color(e.tint.r * D.ELITE_COLOR.r, e.tint.g * D.ELITE_COLOR.g, e.tint.b * D.ELITE_COLOR.b)
	elite_fx.add(e)


## Flut (Paket G2): ergänzt die Warteschlange einer Welle um die neuen Schleim-Rollen (D.FLOOD_EXTRA), Elite-Gegner
## (ab Woche D.ELITE_WEEK, Welle 2+) und in der mittleren Welle einen Miniboss (ab Woche D.MINI_WEEK).
## Kennung in der Warteschlange: Art + 1000 = Elite, Art + 2000 = Miniboss (spawn_planned löst sie auf).
func plan_wave(queue: Array, week: int, wave: int, waves: int, n: int, guests: Array) -> void:
	prewarm("schleim")
	for g in guests:
		prewarm(String(g))
	for key in D.FLOOD_EXTRA:
		var ex: Array = D.FLOOD_EXTRA[key]
		if week >= int(ex[0]) and wave > 1:
			for i in int(round(n * float(ex[1]))):
				queue.append(int(D.ENEMY_INDEX[key]))
	if wave > 1:
		for i in D.flood_elites(week) + LO.extra_elites():      # Paket L: Elite-Flut
			var fam := String(guests[i % guests.size()]) if not guests.is_empty() and i % 2 == 1 else "schleim"
			queue.append(1000 + strongest_type(fam))
	if week >= D.MINI_WEEK and wave == maxi(1, int(ceil(waves / 2.0))):
		var fam2 := String(guests[0]) if not guests.is_empty() else "schleim"
		var mt := D.family_mini(fam2)
		if mt >= 0:
			queue.append(2000 + mt)


func spawn_planned(code: int, pos: Vector2, hp_mult: float, dmg_mult: float) -> E:
	if code >= 2000:
		var m := spawn(code - 2000, pos, hp_mult, dmg_mult, dmg_mult)
		P.toast.emit("Miniboss: %s!" % String(D.ENEMIES[m.t].name))
		return m
	if code >= 1000:
		var e := spawn(code - 1000, pos, hp_mult * D.ELITE_HP, dmg_mult * 1.3, dmg_mult * 1.3)
		make_elite(e)
		return e
	return spawn(code, pos, hp_mult, dmg_mult, dmg_mult)


## Stärkste Nicht-Boss-Art einer Familie (meistes Leben) – für Elite-Gegner.
func strongest_type(fam: String) -> int:
	var best := -1
	for i in D.family_enemies(fam):
		var r := String(D.ENEMIES[i].role)
		if r == "boss" or D.ENEMIES[i].has("phase_of"):
			continue
		if best < 0 or float(D.ENEMIES[i].hp) > float(D.ENEMIES[best].hp):
			best = i
	return best if best >= 0 else pick_type(fam, "tank")


## Wählt die Nummer einer Art der Familie. role "" würfelt nach D.ROLE_WEIGHT.
func pick_type(fam: String, role := "") -> int:
	if not _fam_cache.has(fam):
		var by := {}
		for i in D.family_all(fam):
			var r := String(D.ENEMIES[i].role)
			if not by.has(r):
				by[r] = []
			by[r].append(i)
		_fam_cache[fam] = by
	var by_role: Dictionary = _fam_cache[fam]
	if role == "" or not by_role.has(role):
		var sum := 0.0
		for r in by_role:
			sum += float(D.ROLE_WEIGHT.get(r, 0.05)) * by_role[r].size()
		var x := _rng.randf() * sum
		for r in by_role:
			for i in by_role[r]:
				x -= float(D.ROLE_WEIGHT.get(r, 0.05))
				if x <= 0.0:
					return i
		return int(by_role.values()[0][0])
	var arr: Array = by_role[role]
	return int(arr[_rng.randi() % arr.size()])


## Boss des Gebiets (Kapitel 11.2). Setzt boss und boss_name.
func spawn_boss(area: int, pos: Vector2, hp_mult := 1.0, dmg_mult := 1.0) -> E:
	var key := String(D.AREA_BOSS[clampi(area, 0, D.AREA_BOSS.size() - 1)])
	var def: Dictionary = D.enemy(key)
	var e: E
	if def.has("phase_of"):
		# zwei Phasen: erst die Hülle (Schleimriese), aus der beim Tod der eigentliche Boss hervorbricht
		e = spawn(int(D.ENEMY_INDEX[String(def.phase_of)]), pos, hp_mult * 0.6, dmg_mult, dmg_mult)
		e.next_phase = key
		e.special = "summon"
		e.tint = Color(1.25, 1.0, 0.55)
	else:
		e = spawn(int(D.ENEMY_INDEX[key]), pos, hp_mult, dmg_mult, dmg_mult)
		if e.special == "":
			e.special = String(D.BOSSES[clampi(area, 0, D.BOSSES.size() - 1)].special)
	boss = e
	boss_name = String(def.name)
	return e


var _line_n := 0


## Test: --spawn=untote_matrose:200[,untote_qualle:20] stellt beim Kampfbeginn Gegner rund um den Helden auf (--spawn_r=Abstand).
func _debug_spawn() -> void:
	var arg := G.arg("spawn")
	if arg == "":
		return
	var pp: Vector2 = G.player.pos2()
	var rad := float(G.arg("spawn_r", "9"))
	for part in arg.split(","):
		var kv := part.split(":")
		if not D.ENEMY_INDEX.has(kv[0]):
			push_error("--spawn: unbekannte Art " + kv[0])
			continue
		var n := int(kv[1]) if kv.size() > 1 else 1
		for i in n:
			var a := _rng.randf() * TAU
			var q := pp + Vector2(cos(a), sin(a)) * (rad + sqrt(float(i)) * 0.5 * _rng.randf_range(0.6, 1.4))
			if G.arg("spawn_line") != "":                  # Bilder: alle Arten nebeneinander vor dem Helden
				var gap := float(G.arg("spawn_line"))
				q = pp + Vector2((_line_n - 0.5 * (arg.split(",").size() - 1)) * gap, -rad)
				_line_n += 1
			if G.field.is_solid(q):
				continue
			var e := spawn(int(D.ENEMY_INDEX[kv[0]]), q, float(G.arg("spawn_hp", "1")), 1.0, 1.0)
			if G.arg("spawn_stun") != "":                  # Bilder: stehen still (idle), schauen zum Helden
				e.stun = 1.0e6
				e.yaw = atan2(pp.x - q.x, pp.y - q.y)
			if G.arg("spawn_elite") != "":
				make_elite(e)
			if G.game.mode == "exp":
				e.home = pp
				e.leash = 14.0
				e.aggro = true


func clear() -> void:
	_flush_book()
	for e: E in list:
		if e.fig != null:
			e.fig.queue_free()
	list.clear()
	alive = 0
	boss = null
	mini = null
	_siege_n = 0
	ai.clear()
	elite_fx.clear()
	bossctl.clear()
	for vis in _vis:
		if vis != null:
			vis.mm.visible_instance_count = 0


func count_alive() -> int:
	return alive


## Nimmt einen Gegner ohne Wertung aus dem Spiel (davongeflogen, Portal erloschen).
func despawn(e: E) -> void:
	if e.st == ST_DEAD:
		return
	e.st = ST_DEAD
	e.dead_t = e.dlim
	e.tgt = null
	alive -= 1
	if e == boss:
		boss = null
	if e == mini:
		mini = null


# ---------------------------------------------------------------- Animation
## Spielt einen einmaligen Clip (falls das Modell ihn hat). Rückgabe: Dauer in Sekunden, sonst 0.
func play(e: E, clip: String) -> float:
	if e.fig != null:
		return e.fig.play(clip)
	var vis = _vis[e.t]
	if vis == null or vis.vat == null:
		return 0.0
	var ci: int = vis.vat.clips.get(clip, -1)
	if ci < 0:
		return 0.0
	_set_clip(e, ci)
	e.ct = 0.0
	e.act = vis.vat.dur[ci]
	return e.act


## Dauer-Clip statt idle/walk (z. B. "under", "hide"); "" hebt ihn auf.
func loop_clip(e: E, clip: String) -> void:
	if e.fig != null:
		e.fig.loop(clip)
		return
	var vis = _vis[e.t]
	if vis == null or vis.vat == null:
		return
	e.lc = vis.vat.clips.get(clip, -1) if clip != "" else -1


func _set_clip(e: E, ci: int) -> void:
	if ci == e.ca:
		return
	e.cb = e.ca
	e.cbt = e.ct
	e.bl = 0.99
	e.ca = ci


func _animate(e: E, dt: float, vat: Dictionary) -> void:
	var clips: Dictionary = vat.clips
	if e.bl > 0.0:
		e.bl = maxf(0.0, e.bl - dt / BLEND_T)
	if e.st == ST_DEAD:
		var di: int = clips.get("death", 0)
		if e.ca != di:
			_set_clip(e, di)
		e.ct = minf(1.0, e.dead_t / float(vat.dur[di]))
		return
	if e.act > 0.0:
		e.act -= dt
		e.ct = minf(1.0, e.ct + dt / float(vat.dur[e.ca]))
		if e.act > 0.0:
			return
	var want: int
	var sp2 := e.v.length_squared()
	if e.st == ST_DOWN:
		want = clips.get("death", 0)
		if e.ca != want:
			_set_clip(e, want)
		e.ct = 1.0
		return
	if e.lc >= 0:
		want = e.lc
	elif e.st == ST_ATTACK and e.tgt != null and clips.has("busy"):
		want = clips.busy                      # Dauer-Clip beim Bearbeiten eines Gebäudes (Ratte knabbert)
	elif e.st == ST_MOVE and sp2 > 0.09 and e.stun <= 0.0 and e.root <= 0.0:
		want = clips.get("walk", 0)
	else:
		want = clips.get("idle", 0)
	if want != e.ca:
		var was_once: bool = not vat.loop[e.ca]
		_set_clip(e, want)
		if was_once:
			e.ct = 0.0
	if not vat.loop[want]:
		e.ct = minf(1.0, e.ct + dt / float(vat.dur[want]))
	elif want == int(clips.get("walk", -1)):
		e.ct = fposmod(e.ct + dt * sqrt(sp2) / (float(vat.stride) * e.vs), 1.0)
	else:
		e.ct = fposmod(e.ct + dt / float(vat.dur[want]), 1.0)


# ---------------------------------------------------------------- Logik
func _physics_process(dt: float) -> void:
	if G.game == null or not G.game.is_running():
		return
	var t0 := Time.get_ticks_usec()
	var field = G.field
	field.update_if_dirty()
	if not _dbg_done:
		_dbg_done = true
		_debug_spawn()
	_frame += 1
	_time += dt
	time = _time
	_grid.clear()
	_grid_ok = true
	for e: E in list:
		if e.st != ST_DEAD:
			var key := int(floor(e.p.x * CELL_INV)) + 512 + (int(floor(e.p.y * CELL_INV)) + 512) * 1024
			e.key = key
			var arr = _grid.get(key)
			if arr == null:
				_grid[key] = [e]
			else:
				arr.append(e)
	var pl = G.player
	var pp: Vector2 = pl.pos2()
	var p_ok: bool = pl.alive and not pl.hidden
	var zones: Array = G.game.zones
	# Hüpf-Schmatzen: ab und zu ein zufälliger Schleimling nahe am Helden, sehr leise
	if _time >= _snd_hop and list.size() > 0:
		_snd_hop = _time + 0.4 + 0.05 * (_frame % 5)      # eigener Takt, der Zufall der Horde bleibt unberührt
		var he: E = list[(_frame * 7919) % list.size()]
		if he.st == ST_MOVE and not he.fly and not he.stat and he.t < D.E_FIRST_NEW and he.p.distance_squared_to(pp) < 196.0:
			Sfx.play_at("slime_hop", Vector3(he.p.x, 0, he.p.y), -21.0, 1.0 / maxf(0.7, sqrt(he.sc)), 0.2)
	ai.tick(dt, pp, p_ok)
	bossctl.tick_ui(dt)
	var i := list.size() - 1
	while i >= 0:
		var e: E = list[i]
		if e.st == ST_DEAD:
			e.dead_t += dt
			if e.alt > 0.0:
				e.alt = maxf(0.0, e.alt - dt * 5.0)        # Flieger fallen zu Boden
			if e.dead_t > e.dlim:
				if e.fig != null:
					e.fig.queue_free()
					e.fig = null
				list[i] = list[list.size() - 1]
				list.pop_back()
		else:
			_step(e, dt, pp, p_ok, i, field, zones)
		i -= 1
	_book_t += dt
	if _book_t > 3.0:
		_flush_book()
	logic_last = (Time.get_ticks_usec() - t0) / 1000.0
	logic_ms = lerpf(logic_ms, logic_last, 0.05)


func _step(e: E, dt: float, pp: Vector2, p_ok: bool, i: int, field, zones: Array) -> void:
	var def: Dictionary = D.ENEMIES[e.t]
	var fl: int = _flags[e.t]
	if e.lead != null:
		var ld: E = e.lead
		e.home = ld.home
		e.leash = ld.leash
		e.aggro = e.aggro or ld.aggro
		e.lead = null
	if e.burn > 0.0:
		e.burn -= dt
		e.hp -= e.burn_d * dt * float(_weak[e.t].get("feuer", 1.0))
		if e.hp <= 0.0:
			_kill(e, Vector2.ZERO, "feuer")
			return
	if e.poison > 0.0:
		e.poison -= dt
		e.hp -= 4.0 * dt * float(_weak[e.t].get("gift", 1.0))
		if e.hp <= 0.0:
			_kill(e, Vector2.ZERO, "gift")
			return
	if e.st == ST_DOWN:
		ai.tick_down(e, def, dt)
		return
	if e.mark > 0.0:
		e.mark -= dt
	if e.shrink > 0.0:
		e.shrink -= dt
	if e.inv > 0.0:
		e.inv -= dt
	e.hit_t += dt
	if e.stat:
		if e.t == _portal_t:
			ai.tick_portal(e, dt)
		return
	var speed := e.sp
	if e.slow > 0.0:
		e.slow -= dt
		speed *= _slowmul[e.t]
	if e.root > 0.0:
		e.root -= dt
		speed = 0.0
	if e.buff > 0.0:
		e.buff -= dt
		speed *= 1.3
	if e.haste > 0.0:
		e.haste -= dt
		speed *= 1.2
	if e.rage:
		speed *= float(D.BOSS_RAGE.speed)
	if def.get("boss", false):
		if bossctl.tick(e, dt):
			return                                          # erschöpft: steht still, Schwachstelle offen
	# Flächen am Boden (Feuer, Gewitter, Fallen) – nur jedes dritte Bild prüfen
	if not e.fly and not e.under and zones.size() > 0 and (i + _frame) % 3 == 0:
		for z in zones:
			var dz: Vector2 = e.p - z.c
			if dz.x * dz.x + dz.y * dz.y < z.r2:
				match z.kind:
					"fire":
						var wf := float(_weak[e.t].get("feuer", 1.0))
						if wf > 0.0:
							e.burn = maxf(e.burn, 2.0)
							e.hp -= z.dps * dt * 3.0 * wf
							e.hit_t = 0.0
					"storm":
						e.slow = maxf(e.slow, 0.6)
						e.hp -= z.dps * dt * 3.0 * float(_weak[e.t].get("blitz", 1.0))
						e.hit_t = 0.0
					"glue":
						e.slow = maxf(e.slow, 0.5)
						speed *= lerpf(1.0, 0.6, float(D.FAMILIES[def.family].get("slow", 1.0)))
						if _time >= _snd_glue:
							_snd_glue = _time + 0.6
							Sfx.play_at("glue_step", Vector3(e.p.x, 0, e.p.y), -15.0)
					"spike":
						if z.uses > 0:
							e.hp -= z.dps * dt * 3.0
							z.uses -= dt * 3.0
							e.hit_t = 0.0
							if _time >= _snd_trap:
								_snd_trap = _time + 0.3
								Sfx.play_at("trap_spike", Vector3(e.p.x, 0, e.p.y), -12.0)
		if e.hp <= 0.0:
			_kill(e, Vector2.ZERO, "feuer" if e.burn > 0.0 else "")
			return
	if e.stun > 0.0:
		e.stun -= dt
		e.v = Vector2.ZERO
		return
	if e.taunt > 0.0:
		e.taunt -= dt
	if def.has("heal"):
		e.sp_t -= dt
		if e.sp_t <= 0.0:
			e.sp_t = 1.0
			for o: E in near(e.p, 5.0):
				if o != e and o.hp < o.mhp:
					o.hp = minf(o.mhp, o.hp + def.heal * o.hm)
			if _rng.randf() < 0.3:
				G.fx.ring(Vector3(e.p.x, 0, e.p.y), 5.0, Color(0.7, 0.5, 1.0, 0.6), 0.5)
				Sfx.play_at("shaman_heal", Vector3(e.p.x, 0, e.p.y), -13.0, 1.0, 1.2)
	elif e.special != "":
		e.sp_t -= dt / (float(D.BOSS_RAGE.special) if e.rage else 1.0)     # Wutphase: Sonderangriffe öfter
		if e.sp_t <= 0.0:
			_boss_special(e, pp, p_ok)
	var d2p := e.p.distance_squared_to(pp)
	# ---- Bausteine, die den Schritt übernehmen (Ansturm, Sprung, Eingraben, Sturzflug …)
	if fl & AI.PRE_MASK != 0:
		if fl & AI.PRE_MASK & ~AI.LIGHT_MASK == 0 and e.ai_s == 0:
			# nur Laufziele und Zeitgeber (Rattenjagd, Heiler, Brutmutter, Turmstörer, Dieb, Miniboss): reicht jedes vierte Bild,
			# das Ziel bleibt dazwischen bestehen (spart Rechenzeit bei großen Horden)
			if (i + _frame) & 3 == 0:
				e.g_on = false
				if ai.pre(e, def, fl, dt * 4.0, pp, p_ok, d2p, speed):
					return
		else:
			e.g_on = false
			if ai.pre(e, def, fl, dt, pp, p_ok, d2p, speed):
				return
	# ---- Angriff
	if e.st == ST_ATTACK:
		var ok := true
		var tp := pp
		if e.tgt_player:
			var reach: float = (e.rng + 1.5) if e.rng > 0.0 else (e.r + 1.5)
			ok = p_ok and d2p < reach * reach
		else:
			ok = e.tgt != null and e.tgt.alive
			if ok:
				tp = e.tgt.mid
		if not ok:
			e.st = ST_MOVE
			e.tgt = null
			e.tgt_player = false
			e.swung = false
		else:
			var to := tp - e.p
			e.yaw = lerp_angle(e.yaw, atan2(to.x, to.y), minf(1.0, dt * 8.0))
			e.v = Vector2.ZERO
			e.tm -= dt
			var clip := _attack_clip(e, def, tp)
			var ld := _lead(e) if clip == "attack" else _lead_clip(e, clip)
			if not e.aimed and not e.swung and e.fig == null and def.has("anims") and def.anims.has("aim") and clip == "attack" and e.rng > 0.0:
				var ad := _clip_dur(e, String(def.anims.aim))
				if ad > 0.0 and e.tm <= ld + ad:
					e.aimed = true
					play(e, String(def.anims.aim))         # kniet zum Schuss / bläht sich auf
			if not e.swung and e.tm <= ld:
				e.swung = true
				play(e, clip)
				if fl & AI.F_SHOCKWAVE != 0:
					ai.warn_line(e.p, (tp - e.p).normalized(), e.r, float(def.wave), maxf(e.tm, 0.0) + 0.15)
			if e.tm <= 0.0:
				e.tm = def.interval
				e.swung = false
				e.aimed = false
				_strike(e, def, fl, pp)
			return
	# ---- Bewegung
	var dir: Vector2
	var chase := false
	if e.g_on:
		var tg0 := e.goal - e.p
		dir = tg0.normalized() if tg0.length_squared() > 0.04 else Vector2.ZERO
	else:
		if p_ok:
			if e.taunt > 0.0:
				chase = true
			elif e.leash > 0.0:
				if e.aggro:
					chase = d2p < 1600.0
					e.aggro = chase
				elif d2p < aggro_range * aggro_range:
					chase = true
					e.aggro = true
			elif e.hunter:
				chase = true
			elif def.get("hunt", false):
				chase = d2p < 256.0
			elif _near[e.t]:
				chase = d2p < (36.0 if e.chase else 9.0)
			elif e.fly and G.game.goal_structure == null:
				chase = true
		e.chase = chase
		if chase:
			dir = ((G.game.lure_p if G.game.lure_t > 0.0 and e.p.distance_squared_to(G.game.lure_p) < 400.0 else pp) - e.p).normalized()   # Köder des Begleiters (Paket Welt)
		elif e.leash > 0.0:
			var th := e.p - e.home
			if th.length_squared() > e.leash * e.leash:
				dir = -th.normalized()
			else:
				var a := e.ph + _time * 0.35
				dir = Vector2(cos(a), sin(a)) * 0.35
		elif e.fly:
			var gs = G.game.goal_structure
			var gp: Vector2 = gs.mid if gs != null else pp
			var tg := gp - e.p
			if gs != null and gs.alive and tg.length() < gs.radius + e.r + 0.6:
				e.st = ST_ATTACK
				e.tgt = gs
				e.tm = _rng.randf_range(0.2, def.interval)
				return
			dir = tg.normalized()
		else:
			dir = field.dir_at(e.p)
	if e.bait_t > 0.0:
		# Lockköder: läuft zum Köder (außer Bosse)
		e.bait_t -= dt
		var tb := e.bait_p - e.p
		if tb.length_squared() > 1.0:
			dir = tb.normalized()
			chase = false
	if fl & AI.F_ZIGZAG != 0:
		dir = dir.rotated(sin(_time * 2.6 + e.ph) * 0.95)
	if fl & AI.F_FLEE != 0 and e.g_on:
		pass                                             # wer flieht, greift den Helden nicht an
	else:
		if e.rng > 0.0 and p_ok and d2p < e.rng * e.rng and d2p >= float(def.get("min_range", 0.0)) ** 2:
			e.st = ST_ATTACK
			e.tgt_player = true
			e.tm = _rng.randf_range(0.4, 1.0)
			return
		if p_ok and d2p < (e.r + 0.8) * (e.r + 0.8) and e.alt < 1.0 + FLY_ALT:
			e.st = ST_ATTACK
			e.tgt_player = true
			e.tm = _rng.randf_range(0.15, 0.5)
			if def.has("burst"):
				Sfx.play_at("fuse", Vector3(e.p.x, 0, e.p.y), -10.0, 1.6, 0.15)
			return
	# Fernkämpfer mit Belagerungsschuss nehmen auch Gebäude aus der Ferne unter Feuer
	if e.rng > 0.0 and fl & AI.F_ARC != 0 and def.get("siege_shot", false) and (i + _frame) % 20 == 0 and not e.g_on and not chase:
		var s2 = field.structure_at(e.p + dir * e.rng * 0.85)
		if s2 == null:
			s2 = field.structure_at(e.p + dir * e.rng * 0.5)
		if s2 != null and not s2.passable:
			e.st = ST_ATTACK
			e.tgt = s2
			e.tm = _rng.randf_range(0.4, 1.2)
			return
	if (i + _frame) % 3 == 0:
		_separate(e)
	e.v = e.v.lerp(dir * speed, minf(1.0, dt * 7.0))
	var np := e.p + (e.v + e.sep + e.kn) * dt
	e.kn *= maxf(0.0, 1.0 - dt * 7.0)
	if e.fly:
		if field.in_bounds(np, 1.0):
			e.p = np
	else:
		if field.is_solid(np):
			var nx := Vector2(np.x, e.p.y)
			var nz := Vector2(e.p.x, np.y)
			if not field.is_solid(nx):
				np = nx
			elif not field.is_solid(nz):
				np = nz
			else:
				np = e.p
		var s = field.structure_at(np)
		if s != null and not s.passable:
			if fl & (AI.F_BURROW | AI.F_TUNNEL) != 0 and ai.start_burrow(e, def, dir):
				return
			e.st = ST_ATTACK
			e.tgt = s
			e.tm = _rng.randf_range(0.2, def.interval)
			if def.has("burst"):
				Sfx.play_at("fuse", Vector3(e.p.x, 0, e.p.y), -10.0, 1.0, 0.15)
			return
		e.p = np
	if e.v.length_squared() > 0.05:
		e.yaw = lerp_angle(e.yaw, atan2(e.v.x, e.v.y), minf(1.0, dt * 9.0))


## So viele Sekunden vor dem Schlag beginnt der Angriffs-Clip (Treffer-Zeitpunkt aus der Blender-Datei).
func _lead(e: E) -> float:
	if e.fig != null:
		return e.fig.hit_time("attack")
	var vis = _vis[e.t]
	if vis.has("lead"):
		return vis.lead
	vis["lead"] = _lead_of(vis)
	return vis.lead


## Clip für den nächsten Schlag: Fernschuss mit eigenem Clip (anims.shot, z. B. Yeti „throw“) oder „attack“.
func _attack_clip(e: E, def: Dictionary, tp: Vector2) -> String:
	if e.rng > 0.0 and def.has("anims") and def.anims.has("shot") and e.p.distance_squared_to(tp) > (e.r + 1.6) ** 2:
		return String(def.anims.shot)
	return "attack"


func _clip_dur(e: E, clip: String) -> float:
	var vis = _vis[e.t]
	if vis == null or vis.vat == null:
		return 0.0
	var ci: int = vis.vat.clips.get(clip, -1)
	return float(vis.vat.dur[ci]) if ci >= 0 else 0.0


func _lead_clip(e: E, clip: String) -> float:
	var vis = _vis[e.t]
	if vis == null or vis.vat == null:
		return -1.0
	var ci: int = vis.vat.clips.get(clip, -1)
	if ci < 0:
		return _lead(e)
	var hh: float = vis.vat.hit[ci]
	return hh if hh >= 0.0 else float(vis.vat.dur[ci]) * 0.5


func _lead_of(vis: Dictionary) -> float:
	if vis.vat == null:
		return -1.0
	var ci: int = vis.vat.clips.get("attack", -1)
	if ci < 0:
		return -1.0
	var h: float = vis.vat.hit[ci]
	return h if h >= 0.0 else float(vis.vat.dur[ci]) * 0.5


func _separate(e: E) -> void:
	var push := Vector2.ZERO
	var cnt := 0
	var k := e.key
	for off in NEIGH:
		var arr = _grid.get(k + off)
		if arr == null:
			continue
		for o: E in arr:
			if o == e:
				continue
			var d := e.p - o.p
			var rr := e.r + o.r
			var l2 := d.length_squared()
			if l2 < rr * rr:
				if l2 < 0.0001:
					d = Vector2(_rng.randf() - 0.5, _rng.randf() - 0.5)
					l2 = d.length_squared() + 0.0001
				var l := sqrt(l2)
				push += d / l * (rr - l) * (o.r / e.r)
				cnt += 1
				if cnt >= 8:
					break
		if cnt >= 8:
			break
	e.sep = (push * 7.0).limit_length(3.5)


func _strike(e: E, def: Dictionary, fl: int, pp: Vector2) -> void:
	var weak := 0.6 if e.shrink > 0.0 else 1.0
	if e.buff > 0.0:
		weak *= 1.3
	if def.has("burst"):
		var c := e.p
		G.fx.explosion(Vector3(c.x, 0.6, c.y), def.burst, Color(1.0, 0.45, 0.1))
		Sfx.play_at("barrel_boom", Vector3(c.x, 0, c.y), -4.0, 1.0, 0.06)
		G.game.damage_structures(c, def.burst, def.dmg * e.dm * weak)
		if G.player.alive and pp.distance_to(c) < def.burst:
			G.player.hurt(def.dmg * 0.4 * e.dp * weak, e)
		e.coins = 0
		_kill(e, Vector2.ZERO)
		return
	_snd(e, "attack", -13.0, 0.12)
	if fl & AI.STRIKE_MASK != 0:
		if ai.strike(e, def, fl, pp, weak):
			return
	if e.tgt_player:
		if def.has("spit"):
			_spit(e, pp, def.dmg * e.dp * weak, 1.4)
		else:
			G.player.hurt(def.dmg * e.dp * weak, e)
	elif e.tgt != null:
		e.tgt.hurt(def.dmg * e.dm * weak, def.get("boss", false))
		if def.get("boss", false):
			G.cam.shake(0.2)
			Sfx.play_at("boss_slam", Vector3(e.p.x, 0, e.p.y), -7.0, 1.2, 0.2)


func _spit(e: E, target: Vector2, dmg: float, radius: float) -> void:
	var from := Vector3(e.p.x, 0.8 * e.sc, e.p.y)
	var to := Vector3(target.x, 0.2, target.y)
	Sfx.play_at("spit", from, -8.0, 1.0 if radius < 2.0 else 0.7)
	G.game.launch(from, to, 0.75, 2.5 + radius, Color(0.7, 0.9, 0.2), func():
		G.fx.puff(to, Color(0.7, 0.9, 0.2), 10)
		Sfx.play_at("spit_land", to, -11.0 if radius < 2.0 else -6.0, 1.0 if radius < 2.0 else 0.7)
		if G.player.alive and G.player.pos2().distance_to(Vector2(to.x, to.z)) < radius:
			G.player.hurt(dmg, e)
		if radius > 2.0:
			G.fx.ring(to, radius, Color(0.7, 0.9, 0.2), 0.4)
			G.game.damage_structures(Vector2(to.x, to.z), radius, dmg * 0.6))


func _boss_special(e: E, pp: Vector2, p_ok: bool) -> void:
	var kind := e.special
	var def: Dictionary = D.ENEMIES[e.t]
	if kind == "all":
		kind = ["summon", "spit", "slam"][_rng.randi() % 3]
	elif kind == "cycle":
		var sl: Array = e.specs if not e.specs.is_empty() else def.specials
		kind = String(sl[e.ai_n % sl.size()])
		e.ai_n += 1
	var pos3 := Vector3(e.p.x, 0, e.p.y)
	if _time - _snd_roar > 7.0:           # der Boss brummt ab und zu (freundlich)
		_snd_roar = _time
		Sfx.play_at("boss_roar", pos3, -4.0)
	match kind:
		"summon":
			e.sp_t = 9.0
			if alive < G.max_alive() - 6:
				var st: int = int(D.ENEMY_INDEX[String(def.summon)]) if def.has("summon") else D.E_SLIME
				var n: int = int(def.get("summon_n", 5))
				play(e, "summon")
				for k in n:
					var a := _rng.randf() * TAU
					var q := e.p + Vector2(cos(a), sin(a)) * (e.r + 1.5 + _rng.randf() * 1.5)
					if not G.field.is_solid(q):
						var m := spawn(st, q, e.hm * (0.45 if st != D.E_SLIME else 1.0), e.dm, e.dp)
						m.leash = e.leash
						m.home = e.home
						m.aggro = true
						m.coins = 0
						m.no_split = true
						m.revived = true
						# steigt aus dem Boden: Aufsteh-Clip, kurz wehrlos
						if play(m, "revive") > 0.0 or play(m, "rise") > 0.0 or play(m, "spawn") > 0.0:
							m.stun = m.act
						G.fx.puff(Vector3(q.x, 0.3, q.y), Color(0.8, 0.7, 0.5), 8, 1.2)
				G.fx.ring(pos3, e.r + 3.0, Color(0.6, 0.9, 0.2), 0.5)
				Sfx.play_at("boss_summon", pos3, -3.0)
		"spit":
			e.sp_t = 4.5
			var tg := pp
			if not p_ok or e.p.distance_to(pp) > 24.0:
				var gs = G.game.goal_structure
				if gs == null:
					return
				tg = gs.mid
			play(e, "special")
			ai.telegraph(tg, 3.5, 0.75, Callable())
			_spit(e, tg, def.dmg * 0.6 * e.dp, 3.5)
		"slam":
			e.sp_t = 6.5
			play(e, "slam")
			# rote Zone kündigt den Bodenschlag an; danach ist der Boss kurz erschöpft (Schwachstelle)
			var c := e.p
			var dmg: float = float(def.dmg)
			ai.telegraph(c, 7.0, 1.0, func():
				var c3 := Vector3(c.x, 0, c.y)
				G.fx.ring(c3, 7.0, Color(1.0, 0.8, 0.3), 0.5)
				G.fx.puff(c3 + Vector3(0, 0.3, 0), Color(0.6, 0.5, 0.4), 24, 2.0)
				G.cam.shake(0.35)
				Sfx.play_at("boss_slam", c3, -1.0)
				G.game.damage_structures(c, 7.0, dmg * 0.7 * e.dm)
				if G.player.alive and G.player.pos2().distance_to(c) < 7.0:
					G.player.hurt(dmg * 0.5 * e.dp, e)
				bossctl.expose_now(e))
		_:
			e.sp_t = 6.0
			ai.boss_special(e, def, kind, pp, p_ok)


# ---------------------------------------------------------------- Schaden
## Fügt einem Gegner Schaden zu. from = Flugrichtung des Treffers. Rückgabe: true, wenn besiegt.
## element: kugel | feuer | wasser | eis | blitz | explosion | gift ("" = neutral) – die Familie des Gegners
## verstärkt oder schwächt den Schaden (D.FAMILIES[fam].weak).
func damage(e: E, amt: float, from := Vector2.ZERO, ap := false, dot := false, element := "") -> bool:
	if e.st == ST_DEAD:
		return false
	var fl: int = _flags[e.t]
	if e.st == ST_DOWN:
		# liegt und will wieder aufstehen: nur Feuer und Explosionen machen ein Ende
		if element == "feuer" or element == "explosion" or G.ch("onehit"):
			e.revived = true
			_kill(e, from, element)
			return true
		return false
	e.aggro = true
	if G.ch("onehit"):
		amt = 1.0e9
		e.shield = 0
		e.inv = 0.0
		e.under = false
		e.revived = true
		e.no_split = true
	if e.inv > 0.0:
		if not dot and _time >= _snd_hit:
			_snd_hit = _time + 0.07
			Sfx.play_at("shield_clank", Vector3(e.p.x, 0, e.p.y), -14.0, 1.2, 0.08)
		return false
	if e.under and element != "explosion":
		return false
	if e.shield > 0 and not dot:
		e.shield -= 1
		e.fl = 1.0
		Sfx.play_at("shield_clank", Vector3(e.p.x, 0, e.p.y), -12.0, 1.0, 0.08)
		return false
	if e == boss or String(D.ENEMIES[e.t].role) == "boss":
		amt *= P.boss_dmg_mult()        # Vorteil einer Außenbasis (Expedition rechnet ihn nicht mehr selbst ein)
	var a: float = D.ENEMIES[e.t].armor
	if a > 0.0 and not ap:
		amt = maxf(amt * 0.3, amt - a)
	if element != "":
		var wk: float = _weak[e.t].get(element, 1.0)
		if wk <= 0.0:
			return false
		amt *= wk
	if fl & AI.DMG_MASK != 0:
		amt = ai.modify_damage(e, D.ENEMIES[e.t], fl, amt, from, element)
		if amt < 0.0:
			return false                                    # vom Schild abgeprallt
	if e.expose > 0.0:
		amt *= D.BOSS_EXPOSE_DMG                            # Schwachstelle offen
	if e.mark > 0.0:
		amt *= 1.4
	if e.shrink > 0.0:
		amt *= 1.3
	e.hp -= amt
	e.fl = 0.45 if (e.elite or e.r > 0.9) else 1.0         # große Gegner blitzen schwächer (Dauerfeuer machte sie sonst weiß)
	e.hit_t = 0.0
	if e.hp <= 0.0:
		_kill(e, from, element)
		return true
	if fl & AI.HIT_MASK != 0:
		ai.on_hit(e, D.ENEMIES[e.t], fl)
	if not dot:
		if e.act <= 0.0 and e.st != ST_ATTACK and e.lc < 0:
			play(e, "hit")
		if _time >= _snd_hit:
			_snd_hit = _time + 0.07
			_snd(e, "hit", -17.0, 0.0)
	return false


## Wie stark wirkt ein Element auf diesen Gegner? (0 = wirkungslos)
func weak_of(e: E, element: String) -> float:
	return float(_weak[e.t].get(element, 1.0))


func _kill(e: E, _from: Vector2, element := "") -> void:
	if e.st == ST_DEAD:
		return
	var fl: int = _flags[e.t]
	var def: Dictionary = D.ENEMIES[e.t]
	# Wiederauferstehen (Matrosen-Zombie): nicht bei Feuer oder Explosion
	if fl & AI.F_REVIVE != 0 and not e.revived and e.st != ST_DOWN and element != "feuer" and element != "explosion" and e.burn <= 0.0:
		ai.go_down(e, def)
		return
	e.st = ST_DEAD
	e.dead_t = 0.001
	e.tgt = null
	e.bl = 0.0
	e.under = false
	alive -= 1
	kills += 1
	_book[e.t] = int(_book.get(e.t, 0)) + 1
	var is_boss := e == boss
	if e == mini:
		mini = null
		Sfx.play("miniboss_defeat", -3.0)
	if G.game != null and not e.hide:
		G.game.add_kill_xp(2 if is_boss else (1 if _elite[e.t] else 0))
	if e.coins > 0 and G.coins:
		G.coins.drop(e.p, LO.kill_coins(e.coins, String(def.family), e.elite))     # Paket L: Schleimregen, Goldrausch, Elite-Flut
	if LO.nm_explode and not is_boss:
		LO.on_kill(e)                                         # Paket L: Albtraum+ – Gegner explodieren
	var big: bool = is_boss or def.role == "tank"
	if not e.hide:
		var vis = _vis[e.t]
		var own: bool = vis != null and vis.true_size
		if not own:
			G.fx.splat(Vector3(e.p.x, 0.5 * e.sc, e.p.y), Color(0.62, 0.78, 0.2) * e.tint, big)
		elif big:
			G.fx.puff(Vector3(e.p.x, 0.5 * e.sc, e.p.y), Color(0.8, 0.75, 0.6), 14, 1.4)
		if is_boss:
			Sfx.play("pop_boss", -1.0)
		elif big:
			_snd(e, "death", -5.0, 0.0, "pop_big")
		else:
			_snd(e, "death", -12.0, 0.05, "pop_small")
	if fl & AI.DEATH_MASK != 0:
		ai.on_death(e, def, fl)
	if is_boss:
		if e.next_phase != "":
			# zweite Phase: der eigentliche Boss bricht hervor und übernimmt Auftrag und Wachposten
			var n := spawn(int(D.ENEMY_INDEX[e.next_phase]), e.p, e.hm / 0.6, e.dm, e.dp)
			n.home = e.home
			n.leash = e.leash
			n.aggro = true
			n.on_death = e.on_death
			n.coins = e.coins
			e.on_death = Callable()
			boss_name = String(D.ENEMIES[n.t].name)
			G.fx.explosion(Vector3(e.p.x, 1.5, e.p.y), 6.0, Color(1.0, 0.3, 0.2))
			G.cam.shake(0.5)
			Sfx.play("boss_arrive", -2.0)
			if e.fig != null:
				e.fig.die()
			return
		boss = null
		bossctl.on_defeat(e)
		Sfx.play("boss_defeat", -2.0)
		G.fx.explosion(Vector3(e.p.x, 1.5, e.p.y), 6.0, Color(0.7, 0.9, 0.2))
		G.cam.shake(0.5)
	if e.fig != null:
		e.fig.die()
	if e.on_death.is_valid():
		e.on_death.call()


func knock(e: E, dir: Vector2, strength: float, force := false) -> void:
	if e.stat or e.under:
		return
	if e.r < 0.6 or force:
		e.kn += dir * strength * 6.0


## Flächenschaden. opts: {"stun", "slow", "root", "burn", "knock", "poison", "element"} – element ist ohne Angabe "explosion".
func explode(c: Vector2, radius: float, dmg: float, opts := {}) -> int:
	var n := 0
	var kn: float = opts.get("knock", 1.5)
	var el: String = opts.get("element", "explosion")
	_aoe = true
	for e: E in list:
		if e.st != ST_DEAD:
			var d := e.p.distance_to(c)
			if d < radius + e.r:
				var fall := 1.0 - 0.5 * clampf(d / radius, 0.0, 1.0)
				var dir := (e.p - c).normalized()
				var wk: float = _weak[e.t].get(el, 1.0)
				if wk > 0.0 and e.st != ST_DOWN and e.inv <= 0.0:
					knock(e, dir, kn)
					if opts.has("stun") and not e.stat and e != boss:
						e.stun = maxf(e.stun, opts.stun)
					if opts.has("slow"):
						e.slow = maxf(e.slow, opts.slow)
					if opts.has("root") and e != boss:
						e.root = maxf(e.root, opts.root)
					if opts.has("burn"):
						e.burn = maxf(e.burn, opts.burn)
					if opts.has("poison"):
						e.poison = maxf(e.poison, opts.poison)
				damage(e, dmg * fall, dir, false, false, el)
				n += 1
	_aoe = false
	return n


# ---------------------------------------------------------------- Abfragen
## air: 0 = alle, 1 = nur Boden, 2 = nur fliegende
func nearest(c: Vector2, rng: float, min_rng := 0.0, prefer_elite := false, air := 0) -> E:
	var best: E = null
	var bd := rng * rng
	var min2 := min_rng * min_rng
	var best_el: E = null
	var bd_el := bd
	for e: E in list:
		if e.st >= ST_DEAD or e.under or (air == 1 and e.fly) or (air == 2 and not e.fly):
			continue
		var d := e.p.distance_squared_to(c) - e.r * e.r
		if d < bd and d >= min2:
			bd = d
			best = e
		if prefer_elite and _elite[e.t] and d < bd_el and d >= min2:
			bd_el = d
			best_el = e
	return best_el if best_el != null else best


func strongest(c: Vector2, rng: float, air := 0) -> E:
	var best: E = null
	var bh := -1.0
	var r2 := rng * rng
	for e: E in list:
		if e.st < ST_DEAD and not e.under and e.hp > bh and e.p.distance_squared_to(c) < r2 and not (air == 1 and e.fly):
			bh = e.hp
			best = e
	return best


## Gegner mit den meisten Nachbarn (für Kanone, Mörser, Granaten).
func densest(c: Vector2, rng: float, min_rng: float, radius: float, air := 1) -> E:
	var cands: Array = []
	var r2 := rng * rng
	var m2 := min_rng * min_rng
	for e: E in list:
		if e.st < ST_DEAD and not (air == 1 and e.fly):
			var d := e.p.distance_squared_to(c)
			if d < r2 and d >= m2:
				cands.append(e)
	if cands.is_empty():
		return null
	var best: E = null
	var bn := -1
	var step := maxi(1, int(cands.size() / 20))
	var j := 0
	while j < cands.size():
		var a: E = cands[j]
		var n := 0
		for b: E in cands:
			if a.p.distance_squared_to(b.p) < radius * radius:
				n += 1
		if _elite[a.t]:
			n += 6
		if n > bn:
			bn = n
			best = a
		j += step
	return best


## Wie in_radius, aber über das Raster der Abstoßung (viel schneller bei großen Horden, für Heiler, Auren und Fallen).
## Fällt auf in_radius zurück, wenn seit dem Aufbau des Rasters Gegner erzeugt wurden.
func near(c: Vector2, radius: float) -> Array:
	if not _grid_ok or radius > 12.0:
		return in_radius(c, radius)
	var out: Array = []
	var x0 := int(floor((c.x - radius - 1.2) * CELL_INV)) + 512
	var x1 := int(floor((c.x + radius + 1.2) * CELL_INV)) + 512
	var z0 := int(floor((c.y - radius - 1.2) * CELL_INV)) + 512
	var z1 := int(floor((c.y + radius + 1.2) * CELL_INV)) + 512
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var arr = _grid.get(x + z * 1024)
			if arr == null:
				continue
			for e: E in arr:
				if e.st < ST_DEAD and not e.under and e.p.distance_to(c) < radius + e.r:
					out.append(e)
	return out


func in_radius(c: Vector2, radius: float) -> Array:
	var out: Array = []
	for e: E in list:
		if e.st < ST_DEAD and not e.under and e.p.distance_to(c) < radius + e.r:
			out.append(e)
	return out


## Strahl: liefert bis zu max_hits Gegner entlang der Linie, sortiert nach Entfernung.
func ray(o: Vector2, dir: Vector2, rng: float, max_hits: int, width := 0.25) -> Array:
	var hits: Array = []
	for e: E in list:
		if e.st >= ST_DEAD or e.under:
			continue
		var rel := e.p - o
		var along := rel.dot(dir)
		if along < 0.0 or along > rng + e.r:
			continue
		var perp := absf(rel.x * dir.y - rel.y * dir.x)
		if perp < e.r + width:
			hits.append([along, e])
	if hits.size() > 1:
		hits.sort_custom(func(a, b): return a[0] < b[0])
	if hits.size() > max_hits:
		hits.resize(max_hits)
	return hits


func cone(o: Vector2, dir: Vector2, rng: float, half_deg: float) -> Array:
	var out: Array = []
	var cs := cos(deg_to_rad(half_deg))
	for e: E in list:
		if e.st >= ST_DEAD or e.under:
			continue
		var rel := e.p - o
		var l := rel.length()
		if l < rng + e.r and (l < 0.9 or rel.dot(dir) / l > cs):
			out.append(e)
	return out


# ---------------------------------------------------------------- Töne und Monsterbuch
## Laut der Familie (<sound>_<what>); fehlt er noch, erklingt der Ersatz (fallback) oder der Schleim-Laut.
func _snd(e: E, what: String, vol: float, gap := 0.05, fallback := "") -> void:
	var def: Dictionary = D.ENEMIES[e.t]
	var nm := "%s_%s" % [String(def.get("sound", "e_schleim")), what]
	var ok = _snd_ok.get(nm)
	if ok == null:
		ok = Sfx.has(nm)
		_snd_ok[nm] = ok
	if not ok:
		nm = fallback
		if nm == "":
			nm = "slime_hit" if what == "hit" else ""
		if nm == "":
			return
	Sfx.play_at(nm, Vector3(e.p.x, 0, e.p.y), vol, 1.0 / maxf(0.7, sqrt(e.sc)), gap)


func sound(e: E, what: String, vol := -10.0, fallback := "") -> void:
	_snd(e, what, vol, 0.1, fallback)


## Besiegte und gesehene Arten gebündelt in den Spielstand schreiben (nicht bei jedem Gegner).
func _flush_book() -> void:
	_book_t = 0.0
	if _book.is_empty() and _seen.is_empty():
		return
	var kd := {}
	for t in _book:
		kd[String(D.ENEMIES[t].key)] = int(_book[t])
	var sd: Array = []
	for t in _seen:
		if _seen[t]:
			sd.append(String(D.ENEMIES[t].key))
			_seen[t] = false
	_book.clear()
	if G.selftest and G.autotest == "":
		pass
	if P.has_method("bestiary_add"):
		P.bestiary_add(kd, sd)


# ---------------------------------------------------------------- Darstellung
func _process(dt: float) -> void:
	for t in _cnt.size():
		_cnt[t] = 0
	var up := Vector3.UP
	var pp := Vector2.ZERO
	var p_ok := false
	if G.player != null:
		pp = G.player.pos2()
		p_ok = G.player.alive
	var fr := Engine.get_process_frames()
	var idx := 0
	for e: E in list:
		idx += 1
		if e.fig != null:
			e.fig.follow(e, dt)
			continue
		if e.hide:
			continue
		var t := e.t
		var vis = _vis[t]
		var n: int = _cnt[t]
		var mm: MultiMesh = vis.mm
		if n >= mm.instance_count:
			continue
		var s: float = e.vs * (0.6 if e.shrink > 0.0 else 1.0)
		var col := e.tint
		if e.burn > 0.0:
			col = Color(1.3, 1.0, 0.72)
		elif e.stun > 0.0 or e.slow > 0.0 or e.root > 0.0:
			col = Color(0.82, 1.0, 1.35)
		elif e.poison > 0.0:
			col = Color(0.8, 1.3, 0.6)
		elif e.mark > 0.0:
			col = Color(1.4, 0.85, 0.85)
		elif e.buff > 0.0:
			col = Color(col.r * 1.15, col.g * 1.2, col.b * 0.8)
		var vat = vis.vat
		if vat != null:
			_animate(e, dt, vat)
			mm.set_instance_transform(n, Transform3D(Basis(up, e.yaw).scaled(Vector3(s, s, s)), Vector3(e.p.x, e.alt, e.p.y)))
			var a := e.fl
			if e.st == ST_DEAD:
				a = 1.002 + clampf((e.dead_t - (e.dlim - SINK_T)) / SINK_T, 0.0, 1.0)
			elif p_ok and (idx + fr) % 6 == 0:
				var to := pp - e.p
				if to.length_squared() < 196.0:
					e.look = 16 + int(round(clampf(angle_difference(e.yaw, atan2(to.x, to.y)), -1.0, 1.0) * 15.0))
				else:
					e.look = 0
			mm.set_instance_color(n, Color(col.r, col.g, col.b, a))
			var hide_acc := 512.0 if (t == D.E_HELM and e.shield <= 0) else 0.0
			mm.set_instance_custom_data(n, Color(float(e.ca + 16 * e.look) + hide_acc, e.ct, float(e.cb) + e.bl, e.cbt))
		else:
			var sy := s
			if e.st == ST_DOWN or e.under:
				sy = s * 0.3
			mm.set_instance_transform(n, Transform3D(Basis(up, e.yaw).scaled(Vector3(s, sy, s)), Vector3(e.p.x, e.alt, e.p.y)))
			mm.set_instance_color(n, col)
			var mode := 0.0
			if e.stun > 0.0 or e.root > 0.0 or e.st == ST_DOWN or e.ai_s != 0:
				mode = 2.0
			elif e.st == ST_ATTACK:
				mode = 1.0
			mm.set_instance_custom_data(n, Color(e.ph, mode, e.dead_t if e.st == ST_DEAD else 0.0, e.fl + (2.0 if vis.legacy_t == D.E_HELM and e.shield <= 0 else 0.0)))
		if e.fl > 0.0:
			e.fl = maxf(0.0, e.fl - dt * 12.0)
		_cnt[t] = n + 1
	for t in _vis.size():
		if _vis[t] != null:
			_vis[t].mm.visible_instance_count = _cnt[t]
	elite_fx.update(self, dt)
