extends "res://src/world.gd"
## V6 Paket M – Kampfwelt der Spielmodi „Turm der Prüfungen“ und „Überleben“ (eigene kleine Welt wie training_ground.gd).
##
## Turm:      runde Arena (Radius 15 m) je 10er-Block mit eigenem Saal aus Blender (mt_floor_/mt_wall_/mt_pillar_<n>), vier
##            Tore. Aufgaben aus data_modi.gd (FLOORS): clear, survive, defend (Generator), timed, boss; Zusätze noskill, melee,
##            noheal, fast. Fällt der Held, ist die Prüfung verloren. Sterne: geschafft, Leben am Ende, Zeit (src/modi.gd).
## Überleben: Schrottplatz 60 × 60 m mit Deckung (sv_*), endlose Wellen aus vier Toren, alle 5 Wellen eine von drei
##            Verstärkungen (roguelike), Punkte für die Wochen-Rangliste. Wiedereinstiege nur über die Verstärkung „Zweites Leben“.
##
## Für hud.gd gibt es dieselben Felder wie bei der Flut (mode = "practice"); die Zeilen für Welle/Bunker blendet die Welt aus
## und zeigt rechts eine eigene Tafel. Ergebnis: result (practice) + Zusatz über modi_ui.gd (result_extra).
## Bots: --autotest=turm --floor=N, --autotest=ueberleben (siehe tests_modi.gd).

const DM = preload("res://src/data_modi.gd")
const Modi = preload("res://src/modi.gd")
const UI = preload("res://src/ui.gd")
const LO = preload("res://src/liveops.gd")

signal state_changed
signal battle_ended

var kind := "tower"              # tower | surv
var floor_n := 1
var fd: Dictionary = {}
var mods := {}
# ---- wie die Flut (für hud.gd)
var wave_idx := 0
var wave_count := 0
var break_left := 0.0
var flood := {}
var result := {}
var bunker_node: Object
# ---- Ablauf
var gen = null                   # Generator (Aufgabe defend)
var t_run := 0.0                 # Kampfzeit (ab der ersten Welle)
var started := false
var lives := 0                   # Wiedereinstiege (Überleben)
var score := 0                   # Punkte (Überleben)
var buffs := {}                  # Verstärkung -> Stufe
var picks := 0                   # gewählte Verstärkungen
var spawn_pts: Array = []        # Tore (Positionen am Boden)
var _queue: Array = []           # [role, fam] oder [code, "boss"]
var _spawn_t := 0.0
var _rate_acc := 0.0             # Aufgabe survive: angesammelte Gegner (rate je Sekunde)
var _gate_i := 0
var _start_t := 2.5
var _goal_t := 0.0
var _goal_p := Vector2(9999, 9999)
var _pick_open := false
var _pick_opts: Array = []
var _kills0 := 0
var _vamp_kills := 0
var _turrets: Array = []
var _melee_ring: MeshInstance3D
var _panel: Control
var _l_title: Label
var _l_task: Label
var _l_prog: Label
var _l_star: Label
var _gen_bar: ProgressBar
var _buff_box: HFlowContainer
var _skip_btn: Button
var _buff_sig := "-"
var _bot_t := 0.0
var _bot_skill_t := 0.0
var _bot_ang := 0.0
var _half := 20.0


class FakeBunker:
	var hp := 1.0
	var max_hp := 1.0
	var alive := true


## Generator der Aufgabe „Verteidige den Generator“: Ziel der Horde (Feld, goal_structure), Leben, Modell aus Blender.
class Generator extends Node3D:
	var hp := 900.0
	var max_hp := 900.0
	var alive := true
	var mid := Vector2.ZERO
	var radius := 1.4
	var passable := false
	var blocks_player := true
	var cost := 40.0
	var key := "generator"
	var _flash := 0.0
	var model: Node3D

	func hurt(d: float, _boss := false) -> void:
		if not alive or G.ch("god_base"):
			return
		hp -= d
		_flash = 0.25
		if hp <= 0.0:
			hp = 0.0
			alive = false
			if G.fx != null:
				G.fx.explosion(global_position + Vector3(0, 1.2, 0), 3.5)
			Sfx.play("gen_down", -2.0)

	func _process(dt: float) -> void:
		if model == null:
			return
		_flash = maxf(0.0, _flash - dt)
		model.scale = Vector3.ONE * (1.0 + _flash * 0.25)


# ================================================================= Aufbau
## Vor dem Einhängen aufrufen: k = "tower" (f = Stockwerk) oder "surv".
func init(k: String, f := 1) -> void:
	kind = k
	floor_n = clampi(f, 1, DM.TOWER_FLOORS)


func _ready() -> void:
	mode = "practice"
	flood = {"total": 0, "mix": [], "boss": false}          # hud.gd liest die Wellen-Vorschau daraus (bleibt leer)
	bunker_node = FakeBunker.new()
	if kind == "tower":
		fd = Modi.floor_def(floor_n)
		for mk in fd.get("mods", []):
			mods[String(mk)] = true
		_build_tower()
	else:
		_build_surv()
	hero.died.connect(_on_hero_died)
	state_changed.connect(func(): _hide_flood_rows.call_deferred())      # hud baut das Kampfbild bei jedem Wechsel neu
	G.next_wave_pressed.connect(skip_break)
	running = true
	xp_factor = (1.0 + 0.08 * floor_n) if kind == "tower" else 1.0
	Music.set_mood("battle")
	_make_panel.call_deferred()
	_hide_flood_rows.call_deferred()
	if kind == "tower":
		wave_count = fd.waves.size() if fd.has("waves") and String(fd.task) != "survive" else 1
		if mods.has("noheal"):
			LO.nm_noheal = true
			hero.hp = hero.max_hp * DM.TOWER_NOHEAL_HP
		Sfx.play("tower_start", -3.0)
		P.toast.emit("Stockwerk %d: %s – %s" % [floor_n, String(fd.name), Modi.floor_text(floor_n)])
	else:
		lives = DM.SURV_START_LIVES
		Sfx.play("surv_start", -3.0)
		P.toast.emit("Überleben: Halte so viele Wellen wie möglich durch! Alle %d Wellen wählst du eine Verstärkung." % DM.SURV_PICK_EVERY)
	state_changed.emit()


func _theme(area_key: String, over: Dictionary) -> Dictionary:
	var th: Dictionary = {}
	for a in D.AREAS:
		if String(a.key) == area_key:
			th = a.duplicate()
	for k in over:
		th[k] = over[k]
	return th


func _build_tower() -> void:
	var b := Modi.block_of(floor_n)
	var bd: Dictionary = DM.TOWER_BLOCKS[b]
	var ak: String = ["forst", "staub", "frost", "sumpf", "vulkan"][b]
	var th := _theme(ak, {"fog": bd.fog, "ground": bd.ground, "ground2": bd.ground2, "path": bd.ground, "sun": bd.sun})
	_half = 20.0
	setup_common(th, Vector2(-_half, -_half), int(_half), int(_half), 2.0)
	world_env.fog_density = 0.006
	var R := DM.TOWER_RADIUS
	# alles außerhalb des Kreises ist fest
	for i in field.solid.size():
		if field.center(i).length() > R + 0.4:
			field.solid[i] = 1
	field.dirty = true
	make_ground(Vector2(-_half, -_half), Vector2(_half * 2, _half * 2), [], 1.0)
	var n := b + 1
	if Models.has_glb("mt_floor_%d" % n):
		place_model("mt_floor_%d" % n, Vector3.ZERO)
	for i in 24:
		var a := deg_to_rad(i * 15.0)
		var p := Vector2(cos(a), sin(a)) * (R + 2.1)
		var gate := i % 6 == 3
		var mdl := "mt_gate" if gate else "mt_wall_%d" % n
		if Models.has_glb(mdl):
			var nd := place_model(mdl, Vector3(p.x, 0, p.y), atan2(-p.x, -p.y))
			_no_shadow(nd, gate)
		if gate:
			spawn_pts.append(Vector2(cos(a), sin(a)) * (R - 1.0))
	for i in 4:
		var a2 := deg_to_rad(i * 90.0)
		var q := Vector2(cos(a2), sin(a2)) * (R - 0.6)
		if Models.has_glb("mt_pillar_%d" % n):
			place_model("mt_pillar_%d" % n, Vector3(q.x, 0, q.y), atan2(-q.x, -q.y))
		field.block_circle(q, 0.9)
	cam.bounds = Rect2(-R * 0.55, -R * 0.55, R * 1.1, R * 1.1)
	make_ambient(String(bd.amb))
	spawn_hero(String(P.d.hero_sel), Vector2(0, 3))
	field.set_goal(Vector2(0, 3))
	if String(fd.task) == "defend":
		_make_generator()


func _no_shadow(n: Node3D, _gate: bool) -> void:
	if G.quality() >= 2:
		return
	for gi in n.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _make_generator() -> void:
	gen = Generator.new()
	gen.name = "Generator"
	add_child(gen)
	gen.mid = Vector2(0, -2)
	gen.position = Vector3(0, 0, -2)
	gen.max_hp = DM.TOWER_GEN_HP * (1.0 + 0.1 * (floor_n - 1))
	gen.hp = gen.max_hp
	if Models.has_glb("mt_generator"):
		gen.model = Models.glb("mt_generator")
		gen.add_child(gen.model)
		_anims.append_array(Anim.collect(gen.model))
	field.add_structure(gen, gen.mid - Vector2(1.2, 1.2), gen.mid + Vector2(1.2, 1.2))
	field.set_goal(gen.mid)
	goal_structure = gen
	bunker_node = gen


func _build_surv() -> void:
	var th := _theme("staub", {"fog": Color("C9B48E"), "ground": Color("9A8A72"), "ground2": Color("857560"), "path": Color("6E6250")})
	_half = DM.SURV_HALF + 2.0
	setup_common(th, Vector2(-_half, -_half), int(_half), int(_half), 2.0)
	var H := DM.SURV_HALF
	field.block_rect(Vector2(-_half, -_half), Vector2(_half, -H + 1.0))
	field.block_rect(Vector2(-_half, H - 1.0), Vector2(_half, _half))
	field.block_rect(Vector2(-_half, -_half), Vector2(-H + 1.0, _half))
	field.block_rect(Vector2(H - 1.0, -_half), Vector2(_half, _half))
	make_ground(Vector2(-_half, -_half), Vector2(_half * 2, _half * 2), [PackedVector2Array([Vector2(0, -H), Vector2(0, H)]), PackedVector2Array([Vector2(-H, 0), Vector2(H, 0)])], 2.2)
	# Zaun mit vier Toren in der Mitte jeder Seite
	for side in 4:
		var rot_y := side * PI * 0.5
		var axis := Vector2(cos(rot_y), sin(rot_y))
		var along := axis.orthogonal()
		for k in range(-7, 8):
			var c: Vector2 = axis * (H - 0.5) + along * (k * 4.0)
			if absf(c.x) > H + 0.1 or absf(c.y) > H + 0.1:
				continue
			if k == 0:
				place_model("sv_gate", Vector3(c.x, 0, c.y), atan2(-axis.x, -axis.y))
				spawn_pts.append(axis * (H - 3.0))
			else:
				scatter("sv_fence", Vector3(c.x, 0, c.y), atan2(-axis.x, -axis.y))
	# Deckung (feste Karte)
	var cover := [["sv_container", Vector2(-14, -10), 0.0, Vector2(2.4, 6.0)], ["sv_container", Vector2(16, 12), 90.0, Vector2(2.4, 6.0)],
		["sv_wreck", Vector2(8, -15), 30.0, Vector2(1.9, 3.9)], ["sv_wreck", Vector2(-10, 15), -60.0, Vector2(1.9, 3.9)],
		["sv_barrier", Vector2(-5, -4), 0.0, Vector2(3.0, 0.8)], ["sv_barrier", Vector2(5, 4), 0.0, Vector2(3.0, 0.8)],
		["sv_barrier", Vector2(0, -20), 90.0, Vector2(3.0, 0.8)], ["sv_barrier", Vector2(-20, 2), 90.0, Vector2(3.0, 0.8)], ["sv_barrier", Vector2(20, -3), 0.0, Vector2(3.0, 0.8)],
		["sv_crates", Vector2(12, -4), 15.0, Vector2(2.0, 2.0)], ["sv_crates", Vector2(-16, 20), -20.0, Vector2(2.0, 2.0)], ["sv_crates", Vector2(22, 22), 0.0, Vector2(2.0, 2.0)],
		["sv_crates", Vector2(-22, -22), 40.0, Vector2(2.0, 2.0)], ["sv_sandbags", Vector2(0, 9), 180.0, Vector2(3.4, 1.2)],
		["sv_sandbags", Vector2(-8, -16), 20.0, Vector2(3.4, 1.2)], ["sv_sandbags", Vector2(17, -18), 45.0, Vector2(3.4, 1.2)],
		["sv_tower", Vector2(-22, 10), 0.0, Vector2(2.8, 2.8)], ["sv_tower", Vector2(22, -12), 0.0, Vector2(2.8, 2.8)]]
	for cv in cover:
		var p: Vector2 = cv[1]
		place_model(String(cv[0]), Vector3(p.x, 0, p.y), deg_to_rad(float(cv[2])))
		_block_box(p, cv[3], deg_to_rad(float(cv[2])))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			place_model("sv_lamp", Vector3(sx * (H - 4.0), 0, sz * (H - 4.0)), atan2(-sx, -sz))
	# Schrott als zusätzliche Deckung
	var junk := [["n_wreck", Vector2(-3, 19), 20.0, Vector2(3.6, 1.8)], ["n_scrap_2", Vector2(14, 3), 0.0, Vector2(2.4, 2.4)],
		["n_scrap_1", Vector2(-19, -9), 40.0, Vector2(2.4, 2.4)], ["p_wreck_1", Vector2(7, 23), -30.0, Vector2(3.0, 1.6)],
		["n_barrel_fuel", Vector2(-9, 4), 0.0, Vector2(1.6, 1.6)], ["p_container_1", Vector2(-24, -14), 90.0, Vector2(2.4, 5.6)],
		["n_scrap_3", Vector2(23, 8), 0.0, Vector2(2.0, 2.0)], ["p_wreck_2", Vector2(-12, -21), 60.0, Vector2(3.0, 1.6)]]
	for jk in junk:
		var jp: Vector2 = jk[1]
		if Models.has_glb(String(jk[0])):
			scatter(String(jk[0]), Vector3(jp.x, 0, jp.y), deg_to_rad(float(jk[2])))
			_block_box(jp, jk[3], deg_to_rad(float(jk[2])))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 26:
		var q := Vector2(rng.randf_range(-H + 3, H - 3), rng.randf_range(-H + 3, H - 3))
		if not field.is_solid(q) and q.length() > 5.0:
			scatter_var("p_rock", 3, Vector3(q.x, 0, q.y), rng, 0.4, 0.7)
	for i in 70:                                         # trockene Grasbüschel, Schrottstücke
		var q2 := Vector2(rng.randf_range(-H + 2, H - 2), rng.randf_range(-H + 2, H - 2))
		if not field.is_solid(q2):
			scatter_var("p_gtuft", 2, Vector3(q2.x, 0, q2.y), rng, 0.7, 1.1)
	for i in 18:
		var q3 := Vector2(rng.randf_range(-H + 3, H - 3), rng.randf_range(-H + 3, H - 3))
		if not field.is_solid(q3) and q3.length() > 4.0:
			scatter("p_pile_metal" if i % 3 else "p_barrel_1", Vector3(q3.x, 0, q3.y), rng.randf() * TAU, rng.randf_range(0.6, 0.9))
	# Schrottberge hinter dem Zaun
	for i in 64:
		var a := TAU * i / 64.0 + rng.randf_range(-0.03, 0.03)
		var r := rng.randf_range(H + 3.0, H + 11.0)
		var q4 := Vector2(cos(a), sin(a)) * r
		q4 = q4.clamp(Vector2(-_half - 6, -_half - 6), Vector2(_half + 6, _half + 6))
		var pick: String = ["n_scrap_1", "n_scrap_2", "n_scrap_3", "p_wreck_1", "p_container_1", "p_tree_dead_1", "n_scrap_2", "p_wreck_2"][i % 8]
		if Models.has_glb(pick):
			scatter(pick, Vector3(q4.x, 0, q4.y), rng.randf() * TAU, rng.randf_range(1.0, 1.6))
	scatter_commit()
	make_ambient("staub")
	cam.bounds = Rect2(-H + 6, -H + 6, (H - 6) * 2, (H - 6) * 2)
	spawn_hero(String(P.d.hero_sel), Vector2(0, 2))
	field.set_goal(Vector2(0, 2))
	wave_count = 1


## Rechteckige Deckung (Größe in Blender-Maßen: x = Breite, y = Tiefe) gedreht ins Feld eintragen.
func _block_box(c: Vector2, size: Vector2, yaw: float) -> void:
	var ax := Vector2(cos(yaw), -sin(yaw))
	var az := Vector2(sin(yaw), cos(yaw))
	var nx := maxi(1, int(ceil(size.x / 1.0)))
	var nz := maxi(1, int(ceil(size.y / 1.0)))
	for i in nx + 1:
		for j in nz + 1:
			var q: Vector2 = c + ax * ((float(i) / nx - 0.5) * size.x) + az * ((float(j) / nz - 0.5) * size.y)
			field.block_circle(q, 0.5)


# ================================================================= Ablauf
func _physics_process(dt: float) -> void:
	tick_common(dt)
	if ended or hero == null:
		return
	if _pick_open:
		if G.main != null and not G.main.hud.modal_open() and G.autotest == "":
			_show_pick()                            # Auswahl wurde weggeklickt: noch einmal zeigen
		return
	_rules(dt)
	_follow_goal(dt)
	if not started:
		_start_t -= dt
		if _start_t <= 0.0:
			started = true
			_next_wave()
		_update_panel_soon()
		return
	t_run += dt
	if kind == "tower":
		_tick_tower(dt)
	else:
		_tick_surv(dt)
	_tick_spawn(dt)
	if G.autotest != "":
		_bot_skills(dt)
	_update_panel_soon()


var _panel_t := 0.0


func _update_panel_soon() -> void:
	_panel_t -= get_physics_process_delta_time()
	if _panel_t <= 0.0:
		_panel_t = 0.2
		_update_panel()


## Zusätze der Stockwerke und Verstärkungen jedes Bild durchsetzen (sie überleben so auch einen Stufenaufstieg).
func _rules(dt: float) -> void:
	if mods.has("noheal"):
		LO.nm_noheal = true                     # liveops_world setzt die Albtraum-Schalter je Welt zurück
	if mods.has("noskill"):
		for i in mini(3, hero.skills.slots.size()):
			hero.skills.slots[i].locked = true
			hero.skills.slots[i].why = "Diese Prüfung verbietet Fähigkeiten."
	if mods.has("melee"):
		var pp: Vector2 = hero.pos2()
		var r2 := DM.TOWER_MELEE_R * DM.TOWER_MELEE_R
		for e in horde.list:
			if e.st != 2:
				e.inv = 0.2 if e.p.distance_squared_to(pp) > r2 else 0.0
		if _melee_ring == null:
			_melee_ring = MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = DM.TOWER_MELEE_R
			cm.bottom_radius = DM.TOWER_MELEE_R
			cm.height = 0.04
			cm.radial_segments = 40
			cm.rings = 1
			_melee_ring.mesh = cm
			_melee_ring.material_override = MK.glow(Color(1.0, 0.85, 0.3, 0.16), true)
			_melee_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(_melee_ring)
		_melee_ring.position = Vector3(pp.x, 0.07, pp.y)
	var fk := float(buffs.get("fokus", 0))
	if fk > 0.0:
		for sl in hero.skills.slots:
			if float(sl.left) > 0.0:
				sl.left = maxf(0.0, float(sl.left) - dt * 0.3 * fk)
	if buffs.has("vampir"):
		var k: int = horde.kills - _vamp_kills
		if k > 0:
			hero.heal(hero.max_hp * 0.02 * float(buffs.vampir) * k)
	_vamp_kills = horde.kills


## Die Horde läuft zum Helden (Feld-Ziel folgt ihm), außer beim Generator.
func _follow_goal(dt: float) -> void:
	if gen != null:
		return
	_goal_t -= dt
	if _goal_t > 0.0:
		return
	_goal_t = 0.5
	var pp: Vector2 = hero.pos2()
	if pp.distance_to(_goal_p) > 1.5:
		_goal_p = pp
		field.set_goal(pp)


func _next_wave() -> void:
	wave_idx += 1
	if kind == "tower":
		var t := String(fd.task)
		if t == "survive":
			return
		var w: Array = fd.waves[wave_idx - 1]
		for ent in w:
			var fam := String(ent[2]) if ent.size() > 2 else String(fd.fam)
			for i in int(ent[1]):
				_queue.append([String(ent[0]), fam])
		if t == "boss" and wave_idx == 1:
			_queue.append(["boss", String(fd.boss)])
		if wave_idx > 1:
			Sfx.play("wave", -6.0)
	else:
		_plan_surv_wave()
		Sfx.play("wave", -5.0)
		if wave_idx > 1:
			P.toast.emit("Welle %d!" % wave_idx)
	state_changed.emit()


func _tick_tower(dt: float) -> void:
	var t := String(fd.task)
	if t == "survive":
		_rate_acc += dt * float(fd.rate)
		var spawn: Array = fd.spawn
		while _rate_acc >= 1.0:
			_rate_acc -= 1.0
			if horde.alive + _queue.size() < int(fd.max):
				_queue.append([String(spawn[randi() % spawn.size()]), String(fd.fam)])
		if t_run >= float(fd.t):
			_finish(true)
		return
	if t == "timed" and t_run >= float(fd.t):
		P.toast.emit("Die Zeit ist um!")
		_finish(false)
		return
	if gen != null and not gen.alive:
		P.toast.emit("Der Generator ist zerstört!")
		_finish(false)
		return
	if break_left > 0.0:
		break_left -= dt
		if break_left <= 0.0:
			_next_wave()
		return
	if _queue.is_empty() and horde.alive <= 0:
		if wave_idx >= fd.waves.size():
			_finish(true)
		else:
			break_left = DM.TOWER_BREAK
			Sfx.play("wave_clear", -6.0)


func _tick_surv(dt: float) -> void:
	if break_left > 0.0:
		break_left -= dt
		if break_left <= 0.0:
			_next_wave()
		return
	if _queue.is_empty() and horde.alive <= 0:
		var gain := int(DM.SURV_PTS.wave * wave_idx * _score_k())
		score += gain
		fx.float_text(hero.global_position + Vector3(0, 3.2, 0), "+%d" % gain, D.C_GOLD)
		Sfx.play("wave_clear", -5.0)
		if wave_idx % DM.SURV_PICK_EVERY == 0:
			_open_pick()
		break_left = DM.SURV_BREAK
		for tw in _turrets:
			if is_instance_valid(tw):
				tw.life = 0.01
		_turrets.clear()


func _score_k() -> float:
	return 1.0 + 0.25 * float(buffs.get("gold", 0))


## Welle des Überlebensmodus planen: Familie wechselt alle 5 Wellen, Miniboss in Welle 5, 15 …, Boss alle 10 Wellen.
func _plan_surv_wave() -> void:
	var w := wave_idx
	var fam := DM.surv_fam(w)
	var n := DM.surv_count(w)
	var roles := ["mass", "mass", "mass", "mass", "fast", "ranged"]
	if w >= 3:
		roles.append("tank")
	if w >= 4:
		roles.append("air")
	if w >= 6:
		roles.append_array(["special", "shield", "healer"])
	for i in n:
		_queue.append([String(roles[(i * 7 + w) % roles.size()]), fam])
	for i in maxi(0, int((w - 6) / 3)):
		_queue.append(["elite", fam])
	if w % 10 == 5:
		_queue.append(["miniboss", fam])
	if w % 10 == 0:
		var bk := String(D.AREA_BOSS[D.AREA_FAMILY.find(fam)]) if D.AREA_FAMILY.find(fam) >= 0 else "schleim_boss"
		_queue.append(["boss", bk])
	for i in buffs.get("geschuetz", 0):
		var a := TAU * (float(i) / 2.0) + 0.6
		var q: Vector2 = hero.pos2() + Vector2(cos(a), sin(a)) * 2.5
		if not field.is_solid(q):
			_turrets.append(spawn_tower("mg", q, 9999.0, clampi(1 + int(w / 4), 1, 10)))


func _tick_spawn(dt: float) -> void:
	if _queue.is_empty() or spawn_pts.is_empty():
		return
	_spawn_t -= dt
	if _spawn_t > 0.0:
		return
	_spawn_t = 0.22 if kind == "tower" else maxf(0.08, 0.3 - wave_idx * 0.01)
	var cap := DM.SURV_MAX_ALIVE if kind == "surv" else 40
	if horde.alive >= mini(cap, G.max_alive() - 4):
		return
	var ent: Array = _queue.pop_front()
	_gate_i = (_gate_i + 1) % spawn_pts.size()
	var sp: Vector2 = spawn_pts[_gate_i] + Vector2(randf_range(-1.2, 1.2), randf_range(-1.2, 1.2))
	if field.is_solid(sp):
		sp = spawn_pts[_gate_i]
	_spawn_one(String(ent[0]), String(ent[1]), sp)


func _hp_k() -> float:
	return DM.floor_hp(floor_n) if kind == "tower" else DM.surv_hp(wave_idx)


func _dmg_k() -> float:
	return DM.floor_dmg(floor_n) if kind == "tower" else DM.surv_dmg(wave_idx)


func _spawn_one(role: String, fam: String, p: Vector2) -> void:
	var hm := _hp_k()
	var dm := _dmg_k()
	var e
	if role == "boss":
		var ai := D.AREA_BOSS.find(fam)
		e = horde.spawn_boss(maxi(ai, 0), p, hm * 0.25, 1.0 + 0.5 * (dm - 1.0))   # Gebietsbosse sind schon für ihr Gebiet stark
		Music.set_mood("boss")
		Sfx.play("boss_arrive", -2.0)
		P.toast.emit("%s betritt die Arena!" % horde.boss_name)
	elif role == "elite":
		# Elite-Faktoren der Expedition (×2,5 Leben) sind für die kleine Arena zu hart → abgeschwächt
		e = horde.spawn_family(fam, p, hm * DM.TOWER_ELITE_HP, dm * DM.TOWER_ELITE_DMG, dm * DM.TOWER_ELITE_DMG, role)
	else:
		e = horde.spawn_family(fam, p, hm, dm, dm, role)
	if e == null:
		return
	e.coins = maxi(1, int(e.coins * 0.5)) if kind == "tower" else e.coins
	if mods.has("fast"):
		e.sp *= DM.TOWER_FAST
	if buffs.has("frost"):
		e.sp *= 1.0 - 0.12 * float(buffs.frost)
	e.aggro = true


# ================================================================= Verstärkungen (Überleben)
func _open_pick() -> void:
	var pool: Array = []
	for k in DM.UPGRADE_ORDER:
		if int(buffs.get(k, 0)) < int(DM.UPGRADES[k].max):
			pool.append(k)
	pool.shuffle()
	_pick_opts = pool.slice(0, 3)
	if _pick_opts.is_empty():
		return
	_pick_open = true
	Sfx.play("upgrade_offer", -3.0)
	if G.autotest != "":
		pick(String(_pick_opts[0]))
		return
	_show_pick()


func _show_pick() -> void:
	var hud = G.main.hud
	var v := UI.vbox(16)
	var t := UI.label("Wähle eine Verstärkung", 46, UI.GOLD)
	t.add_theme_constant_override("outline_size", 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UI.label("Welle %d geschafft – sie gilt bis zum Ende dieses Laufs." % wave_idx, 24, UI.TEXT, false))
	var row := UI.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for k in _pick_opts:
		var ud: Dictionary = DM.UPGRADES[k]
		var lv := int(buffs.get(k, 0))
		var inner := UI.vbox(8, [UI.pic(String(ud.icon), 84.0, "ui_star"), UI.label(String(ud.name), 30, UI.GOLD), UI.text(String(ud.text), 22, UI.WHITE, 250),
			UI.label("Stufe %d/%d" % [lv + 1, int(ud.max)], 19, UI.TEXT, false)])
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		var key: String = k
		var b := UI.row_button(false, func(): pick(key), inner, 300.0, "dark")
		b.custom_minimum_size = Vector2(290, 300)
		row.add_child(b)
	v.add_child(row)
	hud._show_modal(v, 0.55, UI.GOLD)
	get_tree().paused = true


## Verstärkung übernehmen (auch für Tests).
func pick(k: String) -> void:
	if not DM.UPGRADES.has(k):
		return
	buffs[k] = int(buffs.get(k, 0)) + 1
	picks += 1
	_pick_open = false
	_pick_opts = []
	if G.main != null and G.main.hud.modal_open():
		G.main.hud._close_modal()
	get_tree().paused = false
	match k:
		"leben":
			lives += 1
		"panzer":
			pass
	apply_buffs()
	if k == "panzer":
		hero.hp = hero.max_hp
	Sfx.play("upgrade_pick", -3.0)
	fx.ring(hero.global_position, 3.0, D.C_GOLD, 0.6)
	P.toast.emit("%s (Stufe %d)" % [String(DM.UPGRADES[k].name), int(buffs[k])])
	_buff_sig = "-"


## Werte des Helden neu setzen (nach Wahl, Stufenaufstieg oder Wiedereinstieg).
func apply_buffs() -> void:
	if hero == null:
		return
	var ratio: float = hero.hp / maxf(hero.max_hp, 1.0)
	hero.refresh_stats()
	hero.dmg *= 1.0 + 0.2 * float(buffs.get("wucht", 0))
	hero.max_hp *= 1.0 + 0.25 * float(buffs.get("panzer", 0))
	hero.hp = hero.max_hp * ratio
	hero.base_speed *= 1.0 + 0.1 * float(buffs.get("tempo", 0))
	hero.rpm *= 1.0 + 0.15 * float(buffs.get("salve", 0))
	hero.crit += 0.08 * float(buffs.get("krit", 0))


func _on_hero_level(key: String, lvl: int) -> void:
	super._on_hero_level(key, lvl)
	if not buffs.is_empty():
		apply_buffs()


## Punkte für Besiegte (Überleben) – kommt aus horde._kill über world.add_kill_xp.
func add_kill_xp(k: int) -> void:
	super.add_kill_xp(k)
	if kind == "surv" and not ended:
		var base := int(DM.SURV_PTS.kill)
		if k == 1:
			base = int(DM.SURV_PTS.elite)
		elif k == 2:
			base = int(DM.SURV_PTS.boss)
		score += int(base * _score_k())


# ================================================================= Held fällt
func _on_hero_died() -> void:
	if ended:
		return
	if kind == "tower":
		P.toast.emit("Dein Held ist gefallen – die Prüfung ist verloren.")
		_finish.call_deferred(false)
		return
	if lives > 0:
		lives -= 1
		hero._respawn = 3.0
		P.toast.emit("Wiedereinstieg in 3 s (noch %d×)." % lives)
		return
	_finish.call_deferred(false)


func can_respawn() -> bool:
	return kind == "surv" and not ended


func respawn_point() -> Vector2:
	return Vector2(0, 2)


# ================================================================= Ende
func _finish(win: bool) -> void:
	if ended:
		return
	ended = true
	running = false
	LO.nm_noheal = false
	break_left = 0.0
	var kills: int = horde.kills
	if kind == "tower":
		var hp_ratio := clampf(hero.hp / maxf(hero.max_hp, 1.0), 0.0, 1.0) if hero.alive else 0.0
		var tr := Modi.tower_finish(floor_n, win, t_run, hp_ratio)
		var coins := 0
		var pxp := (10 + 2 * floor_n) if win else 0
		if pxp > 0:
			P.add_xp(pxp)
		result = {"win": win, "practice": true, "modi": "tower", "kills": kills, "coins": coins, "xp": pxp, "tower": tr,
			"title": ("Stockwerk %d geschafft!" % floor_n) if win else ("Stockwerk %d nicht geschafft" % floor_n)}
		if win:
			Sfx.play("tower_clear", -2.0)
			if hero.alive:
				hero.body.cheer(3.0)
		else:
			Sfx.play("lose", -3.0)
	else:
		var sr := Modi.surv_finish(score, wave_idx, kills)
		var sxp := 5 * maxi(0, wave_idx - 1)
		if sxp > 0:
			P.add_xp(sxp)
		result = {"win": wave_idx > 1, "practice": true, "modi": "surv", "kills": kills, "coins": int(sr.coins), "xp": sxp, "surv": sr,
			"title": "Überleben: Welle %d" % wave_idx}
		Sfx.play("surv_end", -2.0)
	_flush_coins()
	_flush_xp()
	if _panel != null and is_instance_valid(_panel):
		_panel.visible = false
	battle_ended.emit()
	state_changed.emit()


# ================================================================= wie die Flut (für hud.gd)
func enemies_left() -> int:
	return horde.alive + _queue.size()


func skip_break() -> void:
	if break_left > 0.0 and not _pick_open:
		break_left = 0.01


func back_to_peace() -> void:
	G.main.goto_base("modi")


func leave() -> void:
	LO.nm_noheal = false
	if G.next_wave_pressed.is_connected(skip_break):
		G.next_wave_pressed.disconnect(skip_break)
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	if get_tree() != null and get_tree().paused:
		get_tree().paused = false
	super.leave()


# ================================================================= Anzeige
func _hud_root() -> Control:
	return G.main.hud.root if G.main != null and G.main.hud != null else null


func _hide_flood_rows() -> void:
	var hud = G.main.hud if G.main != null else null
	if hud == null:
		return
	for nm in ["_wave_label", "_bunker_bar"]:
		var c = hud.get(nm)
		if c != null and is_instance_valid(c) and c.get_parent() != null:
			c.get_parent().visible = false
	var bb = hud.get("_break_box")
	if bb != null and is_instance_valid(bb):
		bb.modulate.a = 0.0                     # eigene Anzeige der Pause (die der Flut nennt Schleimlinge)


func _make_panel() -> void:
	var root := _hud_root()
	if root == null:
		return
	var v := UI.vbox(6)
	var icon := "ui_tower" if kind == "tower" else "ui_survival"
	_l_title = UI.label("", 26, UI.GOLD)
	v.add_child(UI.hbox(10, [UI.pic(icon, 48.0, "ui_flag"), _l_title]))
	_l_task = UI.label("", 20, UI.WHITE, false)
	_l_task.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_l_task.custom_minimum_size = Vector2(330, 0)
	v.add_child(_l_task)
	_l_prog = UI.label("", 22, UI.SKY)
	v.add_child(_l_prog)
	_l_star = UI.label("", 19, UI.TEXT, false)
	_l_star.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_l_star.custom_minimum_size = Vector2(330, 0)
	v.add_child(_l_star)
	if gen != null:
		_gen_bar = UI.bar(1.0, UI.SKY, Vector2(300, 22))
		v.add_child(UI.hbox(8, [UI.pic("mt_generator", 40.0, "ui_bolt"), _gen_bar]))
	if kind == "surv":
		_buff_box = UI.flow(6)
		_buff_box.custom_minimum_size = Vector2(330, 0)
		v.add_child(_buff_box)
	var p := UI.panel(v, Color(0.07, 0.19, 0.37, 0.94), UI.EDGE, 18, 12)
	UI.ignore_mouse(p)
	_skip_btn = UI.button("Sofort weiter (N)" if not G.is_touch else "Sofort weiter", skip_break, "green", 20, "ui_play")
	_skip_btn.custom_minimum_size = Vector2(0, 56)
	_skip_btn.visible = false
	v.add_child(_skip_btn)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top", 112)
	p.size_flags_horizontal = Control.SIZE_SHRINK_END
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	m.add_child(p)
	root.add_child(m)
	_panel = m
	_update_panel()


func _update_panel() -> void:
	if _panel == null or not is_instance_valid(_panel) or _l_title == null:
		return
	if kind == "tower":
		_l_title.text = "Stockwerk %d · %s" % [floor_n, String(fd.name)]
		_l_task.text = Modi.floor_text(floor_n)
		var t := String(fd.task)
		var prog := ""
		if not started:
			prog = "Gleich geht es los …"
		elif t == "survive":
			prog = "Noch %d s" % int(ceil(maxf(0.0, float(fd.t) - t_run)))
		else:
			prog = "Welle %d/%d · Gegner: %d" % [wave_idx, wave_count, enemies_left()]
			if t == "timed":
				prog += " · noch %d s" % int(ceil(maxf(0.0, float(fd.t) - t_run)))
		if break_left > 0.0:
			prog = "Welle geschafft! Nächste in %d s" % int(ceil(break_left))
		_l_prog.text = prog
		var hp := int(round(hero.hp / maxf(hero.max_hp, 1.0) * 100.0))
		var s3 := ("Zeit %d s (Ziel %d s)" % [int(t_run), int(fd.par)]) if t != "survive" else ("Leben ≥ %d %%" % int(DM.TOWER_STAR3_HP * 100.0))
		_l_star.text = "Sterne: Leben %d %% (≥ %d %%) · %s" % [hp, int(DM.TOWER_STAR2_HP * 100.0), s3]
	else:
		_l_title.text = "Überleben · Welle %d" % maxi(wave_idx, 1)
		_l_task.text = "Punkte: %s · Bestwert: %s" % [UI.fmt(score), UI.fmt(int(Modi.surv().best))]
		var prog2 := "Gegner: %d · Familie: %s" % [enemies_left(), String(D.FAMILIES[DM.surv_fam(maxi(wave_idx, 1))].name)]
		if not started:
			prog2 = "Gleich geht es los …"
		elif break_left > 0.0:
			prog2 = "Welle geschafft! Nächste in %d s" % int(ceil(break_left))
		_l_prog.text = prog2
		var nxt := (DM.SURV_PICK_EVERY - wave_idx % DM.SURV_PICK_EVERY) % DM.SURV_PICK_EVERY if wave_idx > 0 else DM.SURV_PICK_EVERY - 1
		if nxt == 0:
			_l_star.text = "Wiedereinstiege: %d · Verstärkung nach dieser Welle" % lives
		else:
			_l_star.text = "Wiedereinstiege: %d · Verstärkung in %d Wellen" % [lives, nxt + 1]
		var sig := str(buffs)
		if sig != _buff_sig and _buff_box != null:
			_buff_sig = sig
			UI.clear(_buff_box)
			for k in DM.UPGRADE_ORDER:
				if buffs.has(k):
					var chip := UI.pill(UI.hbox(4, [UI.pic(String(DM.UPGRADES[k].icon), 28.0, "ui_star"), UI.label("%d" % int(buffs[k]), 18, UI.GOLD)]), 8, 2)
					chip.tooltip_text = "%s: %s" % [String(DM.UPGRADES[k].name), String(DM.UPGRADES[k].text)]
					_buff_box.add_child(chip)
	if _gen_bar != null and gen != null:
		_gen_bar.value = gen.hp / gen.max_hp
	if _skip_btn != null:
		_skip_btn.visible = break_left > 0.3 and not ended and not _pick_open


# ================================================================= Testbetrieb
func bot_goal():
	if hero == null or not hero.alive:
		return null
	var pp: Vector2 = hero.pos2()
	var e = horde.nearest(pp, 40.0)
	if mods.has("melee"):
		if e == null:
			return Vector2.ZERO
		var to: Vector2 = e.p - pp
		var want := DM.TOWER_MELEE_R * 0.6
		if to.length() < want - 1.0:                    # zu nah: seitlich ausweichen, aber im Nahkampf-Ring bleiben
			return pp - to.normalized() * 2.0 + to.normalized().orthogonal() * 2.0
		return pp + to.normalized() * maxf(0.0, to.length() - want)
	var center: Vector2 = Vector2.ZERO if gen == null else gen.mid + Vector2(0, 3.5)
	_bot_ang += get_physics_process_delta_time() * 0.35
	var orbit: Vector2 = center + Vector2(cos(_bot_ang), sin(_bot_ang)) * (6.0 if kind == "tower" else 8.0)
	if gen != null:
		orbit = center + Vector2(cos(_bot_ang), sin(_bot_ang)) * 3.0
	if e != null and e.p.distance_to(pp) < 4.0 and gen == null:
		var away: Vector2 = (pp - e.p).normalized()
		var q: Vector2 = pp + away * 4.0
		if not field.is_solid(q):
			return q
	return orbit


func _bot_skills(dt: float) -> void:
	_bot_skill_t -= dt
	if _bot_skill_t > 0.0:
		return
	_bot_skill_t = 1.0
	var pp: Vector2 = hero.pos2()
	for i in 4:
		if hero.skills.ready(i) and horde.nearest(pp, 12.0) != null:
			hero.skills.use(i)
