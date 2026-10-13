extends RefCounted
## Prüfungen für Paket Z2 (Stadtruinen, Gebiet 9):
##  - Daten: Gebiet, Expedition, Außenbasis, Welt (Gewitter, Wahrzeichen, Quelle + Werkzeug, Tagebuch, Nebenquest, Tipps), Musik, Klänge,
##    Maschinen am Ende von ENEMIES, Boss-Phasen, Trophäe, Geschichte (Akt 3), Spielmodi (Höhlen-Thema, Überleben), Weltkarte
##  - Modelle: Kulissen, Straßen, Dachhäuser, Ampel, Generator, U-Bahn, Quellen, Wahrzeichen, Sperre, Spezialbau, Symbole;
##    Maschinen mit Animations-Textur, Pflicht-Clips und besonderem Clip; Boss-Figur
##  - Zone: Straßen, Dächer (hinauf über die Feuertreppe, Nahkampf-Schutz, Reichweite, Funkenspinnen, Sprung hinunter),
##    Notstrom, U-Bahn (nur mit Strom und offenen Sperren), Ampeln (Rot hält Maschinen an), Gewitter (Stromausfall, Blitze)
##  - Verhalten: Ampelwächter (Rot/Grün), Bagger-Golem (Schutt), Abrisskran (Abrissbirne), Bürgermeister Bolzen (Stromstoß, Phasen)
##  - alter Spielstand bekommt das neunte Gebiet
## Aufruf aus tests.gd (--selftest) oder allein mit --autotest=zone2.

const D = preload("res://src/data.gd")
const DW = preload("res://src/data_welt.gd")
const DG = preload("res://src/data_geschichte.gd")
const DM = preload("res://src/data_modi.gd")
const AI = preload("res://src/enemy_ai.gd")
const MaschAI = preload("res://src/maschinen_ai.gd")
const Vat = preload("res://src/vat.gd")
const Models = preload("res://src/models.gd")
const Stadt = preload("res://src/exp_stadt.gd")

const AREA := 8
const SPECIES := ["maschinen_maeher", "maschinen_funkenspinne", "maschinen_baggergolem", "maschinen_ampelwaechter", "maschinen_drohne", "maschinen_muellpresse"]
const EXTRA := ["maschinen_reparaturbot", "maschinen_schildbot", "maschinen_stoersender", "maschinen_abrisskran"]
const SPECIAL_CLIP := {"maschinen_maeher": "mow", "maschinen_funkenspinne": "climb", "maschinen_baggergolem": "scoop", "maschinen_ampelwaechter": "signal",
	"maschinen_drohne": "zap", "maschinen_muellpresse": "grab", "maschinen_reparaturbot": "repair", "maschinen_schildbot": "block",
	"maschinen_stoersender": "jam", "maschinen_abrisskran": "skill"}

var T: Node


func _init(tests: Node) -> void:
	T = tests


func run() -> void:
	_data()
	_models()
	_old_save()
	var e = await _start()
	_city(e)
	await _roof(e)
	await _subway(e)
	await _ampel(e)
	await _storm(e)
	await _enemies(e)
	await _boss(e)
	G.autotest = ""
	G.main.goto_base()
	await T._wait(0.3)


# ---------------------------------------------------------------- Daten
func _data() -> void:
	T._check(D.AREAS.size() >= 9 and String(D.AREAS[AREA].key) == "stadt" and int(D.AREAS[AREA].level) == 60, "Gebiet 9: Stadtruinen ab Stufe 60")
	for arr in [D.EXP_AREAS, D.AREA_FAMILY, D.AREA_BOSS, D.BOSSES, D.AREA_FACTOR, D.EXP_HERO_LEVEL, DW.AREA_KEYS, Music.AREAS]:
		T._check(arr.size() == D.AREAS.size(), "je Gebiet ein Eintrag (%d)" % arr.size())
	T._check(int(D.AREAS[AREA].boss) == AREA and D.EXP_AREAS[AREA].nodes.has("ewaste") and D.EXP_AREAS[AREA].nodes.has("copper") and D.EXP_AREAS[AREA].nodes.has("akku"), "Expedition: Elektroschrott, Kupferkabel, Akkus")
	T._check(D.EXP_NODES.ewaste.res == "metal" and D.EXP_NODES.copper.res == "parts" and D.EXP_NODES.akku.res == "cells", "Quellen: Metall, Bauteile, Zellen")
	T._check(D.OUTPOSTS.has("stadt") and String(D.OUTPOSTS.stadt.special) == "Umspannwerk" and D.OUTPOSTS.stadt.effects.size() >= 2, "Außenbasis: Umspannwerk")
	T._check(D.AREA_FAMILY[AREA] == "maschinen" and D.AREA_BOSS[AREA] == "boss_maschinen" and String(D.BOSSES[AREA].name) == "Bürgermeister Bolzen", "Familie und Boss")
	T._check(D.BOSS_PHASES.has("boss_maschinen") and D.BUILDINGS.has(String(D.BOSS_PHASES.boss_maschinen.trophy)), "Boss: Phasen und Trophäe")
	T._check(preload("res://src/layout_code.gd").KEYS.has("trophy_bolzen"), "Trophäe im Bauplan-Code")
	for dd in [DW.EVENTS, DW.LANDMARKS, DW.QUESTS, DW.JOURNAL, DW.AREA_TIPS]:
		T._check(dd.has("stadt"), "Welt: Stadtruinen eingetragen")
	T._check(String(DW.EVENTS.stadt.key) == "gewitter" and DW.JOURNAL.stadt.size() == 4, "Gewitter und vier Tagebuchseiten")
	T._check(DW.SOURCES.has("src_stadt") and String(DW.SOURCES.src_stadt.tool) == "cutter" and int(DW.TOOLS.cutter.area) == AREA, "Umspannkasten mit Bolzenschneider")
	T._check(DW.SOURCES.has("blitzakku"), "Fund aus dem Gewitter: geladener Akku")
	T._check(Music.track_index("area_stadt") >= 0, "Gebietsmusik eingetragen")
	T._check(ResourceLoader.exists("res://audio/music/area_stadt.ogg") and ResourceLoader.exists("res://audio/music/area_stadt_fight.ogg"), "Musik und Gefahr-Lage")
	for s in ["amb_x_stadt", "ev_amb_storm", "ev_thunder", "ev_thunder_warn", "ev_lightning_strike", "hit_fuse", "roof_up", "roof_land", "gen_start",
			"ubahn_ride", "ubahn_arrive", "ampel_red", "ampel_green", "spark_zap", "spider_climb", "scoop_impact", "wrecking_ball", "boss_zap", "step_asphalt",
			"e_maschinen_spawn", "e_maschinen_attack", "e_maschinen_hit", "e_maschinen_death", "e_maschinen_special"]:
		T._check(Sfx.has(s), "Klang %s" % s)
	T._check(Sfx.ground(D.AREAS[AREA]) == "step_asphalt" and Sfx.ambience(D.AREAS[AREA]) == "amb_x_stadt", "Schritte und Umgebung der Stadt")
	# Gegner: Nummern am Ende, Rollen, Bausteine
	var fam: Array = D.family_enemies("maschinen")
	var roles := {}
	for i in fam:
		roles[String(D.ENEMIES[i].role)] = true
	T._check(fam.size() == 6 and roles.size() == 6, "Maschinen: sechs Arten, sechs Rollen")
	var extra := {}
	for i in D.family_all("maschinen"):
		if D.ROLES_EXTRA.has(String(D.ENEMIES[i].role)):
			extra[String(D.ENEMIES[i].role)] = true
	T._check(extra.size() >= 3 and D.family_mini("maschinen") >= 0, "drei Rollen aus G2 und ein Miniboss")
	var last := int(D.ENEMY_INDEX["boss_magma"])
	for key in SPECIES + EXTRA + ["boss_maschinen"]:
		var idx: int = int(D.ENEMY_INDEX.get(key, -1))
		T._check(idx == last + 1 and String(D.ENEMIES[idx].key) == key, "%s: Nummer %d am Ende von ENEMIES" % [key, idx])
		last = idx
		var d: Dictionary = D.enemy(key)
		for a in d.ai:
			T._check(AI.NAMES.has(String(a)), "%s: Baustein %s" % [key, a])
		T._check(d.has("counter") and d.has("look") and d.has("text") and String(d.sound) == "e_maschinen", "%s: Tipp, Aussehen, Laute" % key)
		T._check("Stadtruinen" in str(D.enemy_places(key)), "%s: Fundort im Monsterbuch" % key)
	T._check(D.weak_factor("maschinen", "blitz") >= 1.5 and D.weak_factor("maschinen", "gift") == 0.0, "Schwäche: Blitz, Gift wirkungslos")
	T._check(bool(D.enemy("maschinen_funkenspinne").get("climb", false)), "Funkenspinne klettert")
	# Geschichte, Spielmodi, Weltkarte
	T._check(DG.SCENES.has("a8_in") and DG.SCENES.has("a8_boss") and int(DG.SCENES.a8_in.area) == AREA, "Akt 3: Zwischenszenen der Stadtruinen")
	var ch := false
	for c in DG.CHRONICLE:
		if String(c[0]) == "a8_in":
			ch = true
	T._check(ch, "Chronik: Kapitel 9")
	var goal := 0
	for g in DG.GOALS:
		if int(g.get("a", -1)) == AREA:
			goal += 1
	T._check(goal == 2, "Story-Ziele: betreten und Boss")
	for arr2 in [DG.TALK_AREA, DG.AUTO_AREA_EVENTS, DG.AUTO_DANGER]:
		T._check(arr2.size() >= D.AREAS.size(), "Geschichte: je Gebiet ein Eintrag (%d)" % arr2.size())
	T._check(DG.CHAT_STORY.size() >= D.AREAS.size(), "Bewohner erzählen von jedem Gebiet")
	T._check(preload("res://src/modi.gd").cave_theme(AREA) == "sand" and DM.SURV_FAMS.has("maschinen"), "Höhlen-Thema und Überlebensmodus")
	T._check(preload("res://src/screens/expedition.gd").MAP_POS.size() >= D.AREAS.size(), "Weltkarte: Platz für jedes Gebiet")
	T._check(preload("res://src/companion_data.gd").AREA_WORD.has("stadt"), "Begleiter kennen die Stadtruinen")


# ---------------------------------------------------------------- Modelle
func _models() -> void:
	for m in ["p_tree_city_1", "p_tree_city_2", "p_st_rubble_1", "p_st_rubble_2", "p_st_rubble_3", "p_st_road", "p_st_cross", "p_st_car_1", "p_st_car_2",
			"p_st_bushalt", "p_st_litfass", "p_st_laterne", "p_st_weed", "p_st_hochhaus_1", "p_st_hochhaus_2", "p_st_roof_1", "p_st_roof_2",
			"p_st_ampel", "p_st_generator", "p_st_ubahn", "n_ewaste_1", "n_ewaste_2", "n_ewaste_3", "n_copper", "n_akku", "n_src_stadt",
			"lm_stadt", "x_barrier_stadt", "o_special_stadt", "b_trophy_bolzen"]:
		T._check(Models.has_glb(m), "Modell %s" % m)
	for ic in ["area_stadt", "tool_cutter", "o_special_stadt", "o_special_stadt_1", "lm_stadt"]:
		T._check(ResourceLoader.exists("res://icons/%s.png" % ic), "Symbol %s" % ic)
	var amp: Node3D = Models.glb("p_st_ampel")
	T._check(Models.find(amp, "red_glow") != null and Models.find(amp, "green_glow") != null, "Ampel: Lichter schaltbar")
	amp.free()
	var ub: Node3D = Models.glb("p_st_ubahn")
	T._check(Models.find(ub, "gate") != null and Models.find(ub, "sign_glow") != null, "U-Bahn: Gitter und Schild")
	ub.free()
	for key in SPECIES + EXTRA:
		T._check(Vat.has(key) and ResourceLoader.exists("res://icons/e_%s.png" % key), "%s: Animations-Textur und Symbol" % key)
		if Vat.has(key):
			var cl: Dictionary = Vat.data(key).clips
			var ok := true
			for c in ["idle", "walk", "attack", "hit", "death"]:
				ok = ok and cl.has(c)
			T._check(ok and cl.has(SPECIAL_CLIP[key]), "%s: Pflicht-Clips und %s" % [key, SPECIAL_CLIP[key]])
	var bi: Dictionary = Vat.boss_info("boss_maschinen")
	T._check(not bi.is_empty() and bi.clips.has("special") and bi.clips.has("summon") and bi.clips.has("slam") and int(bi.tris) <= 8000, "Bürgermeister Bolzen: Boss-Figur mit Sonder-Clips")


# ---------------------------------------------------------------- alter Spielstand
func _old_save() -> void:
	P.new_game()
	P.no_save = true
	P.d.areas.boss.resize(8)
	P._ensure_fields()
	T._check(P.d.areas.boss.size() == D.AREAS.size(), "alter Stand: neuntes Gebiet ergänzt")
	P.outpost_set_level("stadt", 2)
	T._check(absf(P.outpost_bonus("prod_cells") - 0.15) < 0.001, "Umspannwerk Stufe 2: Zellen +15 %")
	P.d.outposts = {}


# ---------------------------------------------------------------- Expedition
func _start() -> Node:
	P.new_game()
	P.no_save = true
	P.d.level = 60
	for i in D.AREAS.size():
		for dd in 3:
			P.d.areas.boss[i][dd] = true
	P.d.outposts = {}
	P._ensure_fields()
	G.autotest = ""
	G.main.start_expedition(AREA, "expedition", 0)
	await T._wait(0.5)
	var e = G.main.world
	e.admin_outpost_done()
	await T._wait(0.4)
	e.hero.max_hp = 1.0e6
	e.hero.hp = 1.0e6
	e.welt.end_event()
	return e


func _city(e) -> void:
	var st = e.stadt
	T._check(st != null, "Stadtruinen: Zonen-Mechanik angelegt")
	if st == null:
		return
	T._check(st.roads.size() > 60, "Straßenraster (%d Kacheln)" % st.roads.size())
	T._check(st.roofs.size() >= 6, "Dachhäuser (%d)" % st.roofs.size())
	T._check(st.stations.size() == DW.SUBWAY_LINES * 2 and st.gens.size() == DW.SUBWAY_LINES, "U-Bahn: %d Eingänge, %d Generatoren" % [st.stations.size(), st.gens.size()])
	T._check(st.ampels.size() >= 6, "Ampeln an Kreuzungen (%d)" % st.ampels.size())
	var inner := 0
	for s in st.stations:
		if int(s.end) == 0:
			inner += 1
		T._check(s.n != null and s.gate != null, "U-Bahn-Eingang mit Modell")
	T._check(inner == DW.SUBWAY_LINES, "je Linie ein innerer Eingang")
	if st.roofs.is_empty():
		return
	var r: Dictionary = st.roofs[0]
	var roof_p: Vector2 = Stadt.l2w(r.c, int(r.k), 0.0, 0.0)
	var foot: Vector2 = Stadt.l2w(r.c, int(r.k), 3.0, 7.0)
	var f = e.field
	T._check(f.is_solid(roof_p) and f.is_solid(foot), "Dach und Treppe sind für Gegner fest")
	T._check(st.deck_height(roof_p) == DW.ROOF_H and st.deck_height(foot) < DW.ROOF_H * 0.5, "Höhe: Dach %.1f m, Treppenfuß %.1f m" % [st.deck_height(roof_p), st.deck_height(foot)])
	f.deck_up = false
	T._check(not f.blocks_hero(foot) and f.blocks_hero(roof_p), "vom Boden: Treppenfuß frei, Dach gesperrt")
	f.deck_up = true
	T._check(not f.blocks_hero(roof_p), "von der Treppe: Dach begehbar")
	f.deck_up = false


func _walk(e, dir: Vector2, sec: float) -> void:
	e.hero.test_wish = dir
	await T._wait(sec)
	e.hero.test_wish = Vector2.ZERO


func _roof(e) -> void:
	var st = e.stadt
	if st == null or st.roofs.is_empty():
		return
	var h = e.hero
	var r: Dictionary = st.roofs[0]
	var start: Vector2 = Stadt.l2w(r.c, int(r.k), 3.0, 10.0)
	h.global_position = Vector3(start.x, 0, start.y)
	e.horde.clear()
	await T._wait(0.2)
	var w0: float = h.wrange
	var up: Vector2 = Stadt.l2w(r.c, int(r.k), 3.0, 0.0) - start
	h.test_wish = up.normalized()
	var t0 := 0.0
	while t0 < 4.0 and not (st.perched and Stadt.w2l(r.c, int(r.k), h.pos2()).y < 1.5):
		await T._wait(0.05)
		t0 += 0.05
	h.test_wish = Vector2.ZERO
	await T._wait(0.2)
	T._check(st.perched and h.perch >= DW.ROOF_H * 0.85 and st.on_roof(h.pos2()), "über die Feuertreppe aufs Dach (Höhe %.1f)" % h.perch)
	T._check(absf(h.wrange - w0 * DW.ROOF_RANGE) < 0.01 and st.log.has("roof"), "auf dem Dach: Reichweite × %.1f" % DW.ROOF_RANGE)
	# Nahkämpfer treffen nicht, Flieger schon
	var pp: Vector2 = h.pos2()
	var mower = e.horde.spawn(int(D.ENEMY_INDEX["maschinen_maeher"]), pp + Vector2(30, 0), 1.0, 1.0, 1.0)
	var drone = e.horde.spawn(int(D.ENEMY_INDEX["maschinen_drohne"]), pp + Vector2(30, 2), 1.0, 1.0, 1.0)
	var hp0: float = h.hp
	h.hurt(50.0, mower)
	T._check(h.hp == hp0, "Rasenmäher-Bot erreicht den Helden auf dem Dach nicht")
	h.hurt(50.0, drone)
	T._check(h.hp < hp0, "Drohne trifft auch auf dem Dach")
	e.horde.clear()
	# Funkenspinnen klettern an die Kante und schocken
	var edge: Vector2 = Stadt.l2w(r.c, int(r.k), 6.0, 0.5)
	for k in 2:
		var sp = e.horde.spawn(int(D.ENEMY_INDEX["maschinen_funkenspinne"]), edge + Vector2(0, k * 0.8), 1.0, 1.0, 1.0)
		sp.stat = true
	var z0: int = st.zaps
	await T._wait(1.6)
	T._check(st.zaps > z0, "Funkenspinnen schocken den Helden auf dem Dach (%d)" % (st.zaps - z0))
	e.horde.clear()
	# über die Kante hinunter
	var out: Vector2 = Stadt.l2w(r.c, int(r.k), -12.0, 0.0) - h.pos2()
	await _walk(e, out.normalized(), 1.6)
	await T._wait(0.4)
	T._check(not st.perched and h.perch < 0.1 and st.log.has("jump"), "Sprung vom Dach")
	T._check(absf(h.wrange - w0) < 0.01, "unten: Reichweite wieder normal")


func _subway(e) -> void:
	var st = e.stadt
	if st == null or st.stations.is_empty() or st.gens.is_empty():
		return
	var h = e.hero
	T._check(e.phase == "explore", "Erkunden (Sperren offen)")
	var s0: Dictionary = st.stations[0]
	var other: Dictionary = st.stations[int(s0.other)]
	# ohne Strom keine Fahrt
	for gi in st.gens.size():
		st.switch_gen(gi, false)
	h.global_position = Vector3(s0.door.x, 0, s0.door.y)
	await T._wait(1.5)
	T._check(st.rides == 0 and not st.line_powered(int(s0.line)), "ohne Strom fährt keine U-Bahn")
	T._check(s0.gate.visible, "ohne Strom: Rollgitter zu")
	# Generator einschalten: daneben stehen bleiben
	var g: Dictionary = st.gens[int(s0.line)]
	var gp: Vector2 = g.p + Vector2(1.6, 0)
	h.global_position = Vector3(gp.x, 0, gp.y)
	await T._wait(DW.GEN_HOLD + 1.0)
	T._check(bool(g.on) and st.line_powered(int(s0.line)) and st.log.has("gen_on"), "Notstrom-Generator springt an")
	await T._wait(0.3)
	T._check(not s0.gate.visible and s0.sign.visible, "mit Strom: Gitter offen, U leuchtet")
	# Fahrt
	h.global_position = Vector3(s0.door.x, 0, s0.door.y)
	await T._wait(DW.SUBWAY_HOLD + 2.0)
	T._check(st.rides == 1 and h.pos2().distance_to(other.door) < 4.0, "U-Bahn fährt ans andere Ende (%.0f m)" % h.pos2().distance_to(other.door))
	T._check(absf(h.pos2().length() - s0.p.length()) > 30.0, "Abkürzung zwischen den Ringen")


func _ampel(e) -> void:
	var st = e.stadt
	if st == null or st.ampels.is_empty():
		return
	var a: Dictionary = st.ampels[0]
	for gi in st.gens.size():
		st.switch_gen(gi, true)
	var powered: bool = st.powered_at(a.p)
	if not powered:
		st.gens[0].p = a.p + Vector2(4, 4)           # Test: Generator in Reichweite rücken
	T._check(st.powered_at(a.p), "Ampel hat Strom")
	e.horde.clear()
	a.t = DW.AMPEL_CYCLE[0] + DW.AMPEL_CYCLE[1] + 0.05          # gleich Rot
	var m = e.horde.spawn(int(D.ENEMY_INDEX["maschinen_maeher"]), a.p + Vector2(2.5, 1.0), 1.0, 1.0, 1.0)
	m.leash = 20.0
	m.home = a.p + Vector2(15, 0)
	var s0: int = st.stops
	await T._wait(0.6)
	T._check(int(a.ph) == 0 and st.red_near(m.p), "Ampel zeigt Rot")
	T._check(st.stops > s0 and m.stun > 0.0, "bei Rot bleibt die Maschine stehen")
	var lights: Array = a.lights
	T._check(lights[0] != null and lights[0].visible and not lights[2].visible, "rotes Licht an, grünes aus")
	e.horde.clear()


func _storm(e) -> void:
	var st = e.stadt
	if st == null:
		return
	var h = e.hero
	h.global_position = Vector3(e.outpost.C.x, 0, e.outpost.C.y + 14.0)
	for gi in st.gens.size():
		st.switch_gen(gi, true)
	e.welt.start_event()
	await T._wait(0.3)
	T._check(e.welt.event_key() == "gewitter" and st.blackout, "Blitzgewitter: Stromausfall")
	T._check(not st.line_powered(0) and not st.powered_at(st.gens[0].p), "kein Strom während des Gewitters")
	await T._wait(DW.EVENTS.stadt.dur * 0.7)
	T._check(e.welt.log.has("strike"), "Blitze schlagen ein")
	T._check(e.welt.rain_k > 0.5, "es regnet")
	e.welt.end_event()
	await T._wait(0.3)
	T._check(not st.blackout and st.line_powered(0), "nach dem Gewitter: Strom wieder da")


# ---------------------------------------------------------------- Gegner
func _enemies(e) -> void:
	var h = e.horde
	h.clear()
	var hero = e.hero
	hero.global_position = Vector3(e.outpost.C.x + 10.0, 0, e.outpost.C.y + 16.0)
	await T._wait(0.2)
	var pp: Vector2 = hero.pos2()
	# Ampelwächter: Rot bremst den Helden, Grün macht Maschinen schneller
	var ag = h.spawn(int(D.ENEMY_INDEX["maschinen_ampelwaechter"]), pp + Vector2(4, 0), 50.0, 1.0, 1.0)
	ag.stat = true
	var mo = h.spawn(int(D.ENEMY_INDEX["maschinen_maeher"]), pp + Vector2(5, 3), 50.0, 1.0, 1.0)
	mo.stat = true
	var dg: Dictionary = D.enemy("maschinen_ampelwaechter")
	hero.speed_k = 1.0
	MaschAI._signal(h.ai, ag, dg, pp, true)
	T._check(hero.speed_k < 1.0 and ag.ai_s == AI.S_SIGNAL, "Ampelwächter: Rot bremst den Helden")
	ag.ai_s = 0
	MaschAI._signal(h.ai, ag, dg, pp, true)
	T._check(mo.haste > 0.0, "Ampelwächter: Grüne Welle für Maschinen")
	h.clear()
	# Bagger-Golem schleudert Schutt in die rote Zone
	hero.hp = hero.max_hp
	var bg = h.spawn(int(D.ENEMY_INDEX["maschinen_baggergolem"]), pp + Vector2(8, 0), 50.0, 1.0, 1.0)
	bg.stat = true
	var tel0: int = h.ai.tele.size()
	MaschAI._scoop_start(h.ai, bg, D.enemy("maschinen_baggergolem"), pp)
	T._check(h.ai.tele.size() > tel0 and bg.ai_s == AI.S_SCOOP, "Bagger-Golem: rote Zone für den Schutt")
	await T._wait(2.2)
	T._check(hero.hp < hero.max_hp, "Schutt trifft den Helden")
	h.clear()
	# Abrisskran: Abrissbirne
	hero.hp = hero.max_hp
	var mb = h.spawn(D.family_mini("maschinen"), pp + Vector2(5, 0), 1.0, 1.0, 1.0)
	h.ai._mini_skill(mb, D.enemy("maschinen_abrisskran"), pp, true)
	T._check(h.ai.tele.size() > 0, "Abrisskran: rote Bodenmarkierung")
	await T._wait(1.6)
	T._check(hero.hp < hero.max_hp, "Abrissbirne trifft")
	h.clear()


func _boss(e) -> void:
	var h = e.horde
	var pp: Vector2 = e.hero.pos2()
	var b = h.spawn_boss(AREA, pp + Vector2(10, 0), 1.0, 1.0)
	await T._wait(0.3)
	T._check(b != null and String(D.ENEMIES[b.t].key) == "boss_maschinen" and h.boss_name == "Bürgermeister Bolzen", "Boss der Stadtruinen erscheint")
	T._check(h.bossctl.log_intro > 0, "Boss: Auftritt mit Namen")
	var tel0: int = h.ai.tele.size()
	h.ai.boss_special(b, D.enemy("boss_maschinen"), "spannung", pp, true)
	T._check(h.ai.tele.size() >= tel0 + 9 and b.expose > 0.0, "Stromstoß: Linien mit Bodenmarkern, danach Akku offen")
	b.hp = b.mhp * 0.6
	await T._wait(0.3)
	T._check(b.phase >= 2 and b.specs.has("slam"), "Phase 2 bringt den Stampfer")
	b.hp = b.mhp * 0.25
	await T._wait(0.3)
	T._check(b.rage, "Wutphase unter 30 %")
	h.clear()
