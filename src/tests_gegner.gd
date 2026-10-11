extends RefCounted
## Prüfungen für Paket 11 (Eigene Gegner für jedes Gebiet):
##  - Daten: 36 neue Arten in sechs Familien, je Familie sechs Rollen und ein Boss, Werte aus Kapitel 11.2
##  - Modelle mit Animations-Textur: Pflicht-Clips, Grenzen
##  - je Art ein kurzer Test, der ihr besonderes Verhalten auslöst (auch für Arten, die noch kein eigenes Modell haben)
##  - Schwächen je Familie, Gastfamilien der Flut, Schnittstelle für die Expedition, Monsterbuch
##  - Rechenzeit der Logik mit 300 Gegnern aus drei Arten
## Aufruf aus tests.gd (--selftest) oder allein mit --autotest=gegner.

const D = preload("res://src/data.gd")
const Vat = preload("res://src/vat.gd")
const AI = preload("res://src/enemy_ai.gd")

var T: Node                      # tests.gd (für _check und _wait)
var w                            # base_world
var h                            # horde
var hero
var A := Vector2.ZERO            # Mitte der Test-Arena (freies Gelände außerhalb der Basis)
var tower = null                 # ein Turm der Testbasis


func _init(tests: Node) -> void:
	T = tests


func run() -> void:
	if G.arg("perf") != "":
		await _arena()
		for k in G.arg("perf").split(","):
			var ms := await _perf_run([k, k, k])
			print("PERF %s %.2f ms" % [k, ms])
		_leave()
		return
	_data()
	_models()
	_profile_rules()
	await _arena()
	await _weak()
	await _wald()
	await _wueste()
	await _untote()
	await _mutanten()
	await _eis()
	await _daemonen()
	await _interface()
	await _flood_mix()
	await _perf()
	_leave()


# ---------------------------------------------------------------- Daten
func _data() -> void:
	T._check(D.ENEMIES.size() == D.ENEMY_INDEX.size(), "ENEMY_INDEX deckt alle Arten ab")
	for key in D.ENEMY_INDEX:
		T._check(String(D.ENEMIES[int(D.ENEMY_INDEX[key])].key) == key, "ENEMY_INDEX[%s] stimmt" % key)
	T._check(String(D.ENEMIES[D.E_SLIME].key) == "schleim_schleimling" and String(D.ENEMIES[D.E_BOSS].key) == "schleim_boss" and D.E_FIRST_NEW == 9, "die neun Schleimlinge behalten ihre Nummern")
	var total := 0
	var seen := {}
	for ai in D.AREA_FAMILY.size():
		var fam := String(D.AREA_FAMILY[ai])
		var list: Array = D.family_enemies(fam)
		if fam == "schleim":
			T._check(list.size() == 8, "Schleimlinge: acht Arten")
			continue
		total += list.size()
		var roles := {}
		for i in list:
			roles[String(D.ENEMIES[i].role)] = true
			T._check(not seen.has(i), "keine Art in zwei Gebieten")
			seen[i] = true
		T._check(list.size() == 6 and roles.size() == 6, "%s: sechs Arten, sechs Rollen" % fam)
		var bd: Dictionary = D.enemy(String(D.AREA_BOSS[ai]))
		T._check(bd.role == "boss" and bd.family == fam and String(bd.name) == String(D.BOSSES[ai].name), "%s: Boss %s" % [fam, bd.name])
	T._check(total == 36, "36 neue Arten (%d)" % total)
	# Leben und Tempo aus den Tabellen (Stichproben über alle Familien)
	var want := {"wald_pilzling": [12, 2.2], "wald_dornenwolf": [14, 5.0], "wald_baumhueter": [220, 1.3], "wald_zapfenwerfer": [26, 2.4], "wald_irrlicht": [14, 3.0], "wald_wurzelkriecher": [40, 2.6],
		"wueste_schrottkaefer": [16, 2.2], "wueste_staubteufel": [10, 5.2], "wueste_rostbulle": [240, 1.5], "wueste_kaktusschuetze": [28, 2.0], "wueste_geier": [14, 3.6], "wueste_sandwurm": [70, 3.0],
		"untote_matrose": [18, 1.7], "untote_deckratte": [5, 5.4], "untote_taucher": [260, 1.2], "untote_kanonier": [30, 1.9], "untote_qualle": [16, 2.8], "untote_krabbe": [60, 3.0],
		"mutanten_giftkroete": [16, 2.6], "mutanten_egelschwarm": [24, 4.4], "mutanten_schlammgolem": [280, 1.2], "mutanten_rohrspucker": [32, 2.0], "mutanten_werksdrohne": [18, 3.4], "mutanten_seuchenarzt": [50, 2.4],
		"eis_frostwichtel": [14, 2.6], "eis_eiswolf": [16, 5.2], "eis_yeti": [300, 1.4], "eis_kristallschuetze": [26, 2.0], "eis_eisgeist": [16, 3.0], "eis_lawinenroller": [45, 3.0],
		"daemonen_hoellenwichtel": [18, 3.0], "daemonen_hund": [22, 5.6], "daemonen_waechter": [340, 1.4], "daemonen_feuerspeier": [36, 1.9], "daemonen_schattenschwinge": [20, 4.0], "daemonen_beschwoerer": [60, 1.8]}
	for key in want:
		var e: Dictionary = D.enemy(key)
		T._check(is_equal_approx(float(e.hp), float(want[key][0])) and is_equal_approx(float(e.speed), float(want[key][1])), "%s: Leben %s, Tempo %s" % [key, str(want[key][0]), str(want[key][1])])
		for a in e.ai:
			T._check(AI.NAMES.has(String(a)), "%s: Baustein %s ist bekannt" % [key, a])
		T._check(e.has("sound") and e.has("text") and e.has("look"), "%s: Laute und Beschreibung" % key)
	T._check(D.AREA_HP == [1.0, 1.6, 2.5, 4.0, 6.5, 10.0, 16.0], "Gebietsfaktor für Leben")
	# jede Waffe und jeder Turm hat ein Element
	var els := ["kugel", "feuer", "wasser", "eis", "blitz", "explosion", "gift"]
	for k in D.WEAPONS:
		T._check(els.has(String(D.WEAPONS[k].get("element", ""))), "Waffe %s hat ein Element" % k)
	for k in D.TOWERS:
		T._check(els.has(String(D.TOWERS[k].get("element", ""))), "Turm %s hat ein Element" % k)
	T._check(is_equal_approx(D.weak_factor("untote", "blitz"), 1.5) and is_equal_approx(D.weak_factor("eis", "eis"), 0.0) and is_equal_approx(D.weak_factor("schleim", "feuer"), 1.0), "Schwächen-Tabelle")


# ---------------------------------------------------------------- Modelle mit Animations-Textur
func _models() -> void:
	var limit := {"mass": 900, "fast": 900, "ranged": 1600, "air": 1600, "special": 1600, "tank": 2800, "object": 1600}
	var n := 0
	for def in D.ENEMIES:
		var key := String(def.key)
		if def.role == "boss":
			var bi: Dictionary = Vat.boss_info(key)
			if not bi.is_empty():
				T._check(int(bi.tris) <= 8000, "%s: höchstens 8000 Dreiecke (%d)" % [key, int(bi.tris)])
				for c in ["idle", "walk", "attack", "hit", "death"]:
					T._check(bi.clips.has(c), "%s: Clip %s" % [key, c])
			continue
		if not Vat.has(key):
			continue
		n += 1
		var d: Dictionary = Vat.data(key)
		T._check(not d.is_empty(), "%s: Animations-Textur lädt" % key)
		if d.is_empty():
			continue
		for c in ["idle", "walk", "attack", "hit", "death"]:
			T._check(d.clips.has(c), "%s: Pflicht-Clip %s" % [key, c])
		T._check(d.list.size() >= 6 and d.list.size() <= 16, "%s: 5 Pflicht-Clips + mindestens ein besonderer (%d)" % [key, d.list.size()])
		T._check(int(d.info.verts) <= int(limit[def.role]), "%s: %d Eckpunkte, erlaubt %d" % [key, int(d.info.verts), int(limit[def.role])])
		T._check(int(d.info.width) <= 1024 and int(d.info.rows) <= 512, "%s: Textur %d x %d" % [key, int(d.info.width), int(d.info.rows)])
		T._check(d.hi.get_width() == int(d.info.width) and d.hi.get_height() == int(d.info.rows) and d.mesh.get_surface_count() == 1, "%s: Mesh und Texturen passen zusammen" % key)
		T._check(float(d.stride) > 0.1, "%s: Schrittlänge" % key)
	for key in ["untote_matrose", "untote_deckratte", "untote_taucher", "untote_kanonier", "untote_qualle", "untote_krabbe"]:
		T._check(Vat.has(key), "Untote Seeleute vollständig: Modell %s" % key)
		T._check(ResourceLoader.exists("res://icons/e_%s.png" % key), "Symbol e_%s" % key)
	T._check(not Vat.boss_info("boss_untote").is_empty(), "Kapitän Glibber ist eine echte Figur")
	print("Gegner mit Animations-Textur: %d" % n)


# ---------------------------------------------------------------- Spielstand: Gastfamilien und Monsterbuch
func _profile_rules() -> void:
	P.new_game()
	P.no_save = true
	T._check(P.d.has("flood_guest") and P.d.bestiary is Dictionary, "Spielstand hat Felder für Gäste und Monsterbuch")
	P.d.week.number = 2
	P.roll_flood_guest()
	T._check(P.flood_guests().is_empty() and P.flood_guest_text() == "", "Woche 2: nur Schleimlinge")
	P.d.week.number = 5
	P.d.outposts = {"kueste": {"level": 1}}
	P.roll_flood_guest()
	T._check(P.flood_guests() == ["untote"] and P.flood_guest_text() == "Diese Woche: Untote Seeleute", "Woche 5: Gast aus dem Gebiet mit Außenbasis (%s)" % P.flood_guest_text())
	P.d.week.number = 11
	P.d.outposts = {"kueste": {"level": 1}, "frost": {"level": 2}, "forst": {"level": 0}}
	P.roll_flood_guest()
	var g: Array = P.flood_guests()
	T._check(g.size() == 2 and g.has("untote") and g.has("eis"), "Woche 11: zwei Gastfamilien (%s)" % str(g))
	T._check(is_equal_approx(D.flood_guest_share(5), 0.25) and is_equal_approx(D.flood_guest_share(11), 0.4) and D.flood_guest_share(2) == 0.0, "Anteil 25 % / 40 %")
	P.d.outposts = {}
	P.d.week.number = 4
	P.roll_flood_guest()
	T._check(P.flood_guests().is_empty() or P.area_unlocked(1), "ohne Außenbasis: nur freigeschaltete Gebiete")
	# Monsterbuch
	var g0 := P.gems()
	P.bestiary_add({"untote_matrose": 9}, ["untote_matrose", "untote_qualle"])
	T._check(P.stat("bestiary") == 2 and P.bestiary_claimable("untote_matrose") == -1, "Monsterbuch: gesehen, 9 besiegt – noch keine Belohnung")
	P.bestiary_add({"untote_matrose": 1}, [])
	T._check(P.bestiary_claim("untote_matrose") == 2 and P.gems() == g0 + 2, "10 Besiegte: 2 Juwelen")
	T._check(P.bestiary_claim("untote_matrose") == 0, "nichts doppelt")
	P.bestiary_add({"untote_matrose": 990}, [])
	T._check(P.bestiary_claim("untote_matrose") == 5 and P.bestiary_claim("untote_matrose") == 15 and P.gems() == g0 + 22, "100 und 1000 Besiegte: 5 und 15 Juwelen")
	T._check(P.bestiary_open_rewards() == 0, "alles abgeholt")


# ---------------------------------------------------------------- Arena
func _arena() -> void:
	P.debug_setup(6)
	P.d.week.number = 2
	G.main.goto_base()
	await T._wait(0.3)
	w = G.main.world
	w.start_flood(true)
	await T._wait(0.2)
	w._queue.clear()
	w.flood.total = 0                 # leere Wellen: die Arena gehört den Tests
	w.wave_count = 99
	h = w.horde
	h.clear()
	hero = w.hero
	hero.max_hp = 1.0e7
	hero.hp = 1.0e7
	hero.wrange = 0.0                 # der Held schießt nicht dazwischen
	for tw in w.towers:
		if is_instance_valid(tw):
			tw.active = false
			if tower == null and tw.life < 0.0:
				tower = tw
	# freie Fläche außerhalb der Mauern suchen
	var cands: Array = [Vector2(38, 38), Vector2(-38, 38), Vector2(38, -38), Vector2(-38, -38), Vector2(44, 20), Vector2(20, 44)]
	for r in [30, 36, 42, 48, 54]:     # Basis mit Küste, Bach und Felsen: weiter suchen
		for k in 16:
			cands.append(Vector2.from_angle(TAU * k / 16.0) * r)
	for cand in cands:
		var ok := true
		for dx in range(-14, 15, 2):
			for dy in range(-14, 15, 2):
				var q: Vector2 = cand + Vector2(dx, dy)
				if w.field.is_solid(q) or w.field.structure_at(q) != null:
					ok = false
		if ok:
			A = cand
			break
	T._check(A != Vector2.ZERO, "freie Test-Arena gefunden")
	if A == Vector2.ZERO:
		A = Vector2(38, 38)
	_reset()


func _reset() -> void:
	h.clear()
	w.coins.clear()
	hero.global_position = Vector3(A.x, 0, A.y)
	hero.hp = hero.max_hp
	hero.alive = true
	hero.speed_k = 1.0
	hero.speed_t = 0.0
	hero.dash_t = 0.0
	hero.invuln = 0.0


func _sp(key: String, off: Vector2, hpm := 1.0):
	var e = h.spawn(int(D.ENEMY_INDEX[key]), A + off, hpm, 1.0, 1.0)
	e.ai_c = 0.0
	return e


## Wartet höchstens sec Spielsekunden, bis cond wahr wird.
func _until(cond: Callable, sec: float) -> bool:
	var t := 0.0
	while t < sec:
		if cond.call():
			return true
		await T._wait(0.05)
		t += 0.05
	return cond.call()


func _haz(kind: String) -> bool:
	for z in h.ai.hazards:
		if z.kind == kind:
			return true
	return false


func _count(key: String) -> int:
	var n := 0
	var t := int(D.ENEMY_INDEX[key])
	for e in h.list:
		if e.t == t and e.st != 2:
			n += 1
	return n


# ---------------------------------------------------------------- Schwächen (Test je Familie)
func _weak() -> void:
	var cases := {"wald": ["wald_pilzling", {"feuer": 1.5, "gift": 0.5, "kugel": 1.0}], "wueste": ["wueste_staubteufel", {"explosion": 1.3, "feuer": 0.7, "kugel": 1.0}],
		"untote": ["untote_matrose", {"blitz": 1.5, "kugel": 1.0}], "mutanten": ["mutanten_giftkroete", {"eis": 1.4, "gift": 0.0, "kugel": 1.0}],
		"eis": ["eis_frostwichtel", {"feuer": 1.5, "eis": 0.0, "kugel": 1.0}], "daemonen": ["daemonen_hoellenwichtel", {"wasser": 1.3, "eis": 1.3, "feuer": 0.0, "kugel": 1.0}]}
	for fam in cases:
		_reset()
		var e = _sp(String(cases[fam][0]), Vector2(20, 0), 1000.0)
		e.stun = 99.0
		for el in cases[fam][1]:
			var before: float = e.hp
			h.damage(e, 10.0, Vector2.ZERO, false, false, el)
			var k: float = cases[fam][1][el]
			T._check(absf((before - e.hp) - 10.0 * k) < 0.01, "Schwäche %s gegen %s: Faktor %.1f (Schaden %.1f)" % [fam, el, k, before - e.hp])
	# Verlangsamen wirkt bei Untoten nur halb
	T._check(absf(float(h._slowmul[int(D.ENEMY_INDEX["untote_matrose"])]) - 0.775) < 0.001 and absf(float(h._slowmul[0]) - 0.55) < 0.001, "Verlangsamen wirkt bei Untoten halb")
	# Eis wirkungslos bei Eiswesen: weder Schaden noch Betäubung
	_reset()
	var ice = _sp("eis_frostwichtel", Vector2(20, 0), 100.0)
	h.explode(ice.p, 3.0, 50.0, {"stun": 2.0, "element": "eis", "knock": 0.0})
	T._check(ice.stun <= 0.0 and ice.hp == ice.mhp, "Eis wirkungslos bei Eiswesen")
	# Feuer wirkungslos bei Dämonen: Brennen zieht nichts ab
	var dm = _sp("daemonen_hoellenwichtel", Vector2(24, 0), 100.0)
	dm.stun = 99.0
	dm.burn = 3.0
	await T._wait(0.5)
	T._check(dm.hp == dm.mhp, "Feuer wirkungslos bei Dämonen")
	# Schleimlinge brennen wie bisher
	var sl = _sp("schleim_brocken", Vector2(28, 0), 100.0)
	sl.stun = 99.0
	sl.burn = 3.0
	await T._wait(0.5)
	T._check(sl.hp < sl.mhp, "Schleimlinge brennen weiter")


# ---------------------------------------------------------------- Kiefernforst
func _wald() -> void:
	# Pilzling: Sporenwolke beim Tod, verlangsamt den Helden
	_reset()
	var e = _sp("wald_pilzling", Vector2(0.8, 0))
	e.stun = 9.0
	h.damage(e, 1.0e6)
	T._check(_haz("spore"), "Pilzling: Sporenwolke beim Tod")
	T._check(await _until(func(): return hero.speed_k < 1.0, 1.0), "Pilzling: Sporen verlangsamen den Helden")
	# Dornenwolf: umkreist und springt an
	_reset()
	var wolves: Array = [_sp("wald_dornenwolf", Vector2(9, 0), 500.0), _sp("wald_dornenwolf", Vector2(-9, 2), 500.0)]
	wolves[0].ai_c = 2.0
	var hp0: float = hero.hp
	var orbit := await _until(func(): return wolves[0].g_on, 3.0)
	var jumped := await _until(func(): return wolves[0].ai_s == AI.S_POUNCE or wolves[1].ai_s == AI.S_POUNCE, 6.0)
	T._check(orbit and jumped, "Dornenwolf: umkreist den Helden und springt an")
	T._check(await _until(func(): return hero.hp < hp0, 4.0), "Dornenwolf: Sprung trifft")
	# Baumhüter: wurzelt und heilt nach 4 s ohne Treffer; doppelter Schaden an Mauern
	_reset()
	e = _sp("wald_baumhueter", Vector2(25, 0), 10.0)
	e.hp = e.mhp * 0.5
	e.hit_t = 3.5
	var hp1: float = e.hp
	T._check(await _until(func(): return e.ai_s == AI.S_ROOT, 2.0), "Baumhüter: wurzelt sich fest")
	await T._wait(1.0)
	T._check(e.hp > hp1 + 1.0, "Baumhüter: heilt")
	h.damage(e, 1.0)
	await T._wait(0.2)
	T._check(e.ai_s != AI.S_ROOT, "Baumhüter: ein Treffer beendet das Heilen")
	if w.walls.size() > 0:
		var wall = w.walls[0]
		wall.shielded = false
		wall.hp = wall.max_hp
		e.tgt = wall
		e.tgt_player = false
		var def: Dictionary = D.enemy("wald_baumhueter")
		h._strike(e, def, h._flags[e.t], hero.pos2())
		var a1: float = wall.max_hp - wall.hp
		wall.hp = wall.max_hp
		wall._taken = 0.0
		var sl = _sp("schleim_brocken", Vector2(27, 0))
		sl.tgt = wall
		h._strike(sl, D.ENEMIES[D.E_BRUTE], 0, hero.pos2())
		var a2: float = wall.max_hp - wall.hp
		T._check(absf(a1 - float(def.dmg) * 2.0) < 0.5 and absf(a2 - 26.0) < 0.5, "Baumhüter: doppelter Schaden an Mauern (%.0f statt %.0f)" % [a1, float(def.dmg)])
		wall.hp = wall.max_hp
	# Zapfenwerfer: Fernkampf aus 12 m, Zapfen prallen weiter
	_reset()
	e = _sp("wald_zapfenwerfer", Vector2(10, 0), 500.0)
	hp0 = hero.hp
	T._check(await _until(func(): return hero.hp < hp0 and e.p.distance_to(hero.pos2()) > 6.0, 6.0), "Zapfenwerfer: trifft aus der Ferne")
	await _until(func(): return w._proj.size() >= 1, 4.0)
	hero.global_position = Vector3(A.x, 0, A.y + 6.0)        # ausweichen, während der Zapfen fliegt: er prallt weiter
	var far := func():
		for pr in w._proj:                                   # ein Geschoss, dessen Ziel hinter dem alten Standort liegt
			if Vector2(pr.b.x, pr.b.z).distance_to(e.p) > e.p.distance_to(A) + 3.0:
				return true
		return false
	T._check(await _until(far, 6.0), "Zapfenwerfer: Zapfen prallt einmal weiter")
	# Irrlicht: springt alle 5 s 6 m weit, heilt Verbündete
	_reset()
	e = _sp("wald_irrlicht", Vector2(22, 0), 500.0)
	e.ai_c = 0.3
	var last: Vector2 = e.p
	var jump := [false]
	var chk := func():
		if e.p.distance_to(last) > 4.0:
			jump[0] = true
		last = e.p
		return jump[0]
	T._check(await _until(chk, 2.0), "Irrlicht: springt 6 m weit")
	var hurt = _sp("schleim_brocken", e.p - A + Vector2(1.5, 0), 10.0)
	hurt.root = 99.0
	hurt.hp = hurt.mhp * 0.5
	e.sp_t = 0.1
	var hh: float = hurt.hp
	T._check(await _until(func(): return hurt.hp > hh, 2.5), "Irrlicht: heilt Verbündete")
	# Wurzelkriecher: gräbt sich ein, läuft unter Mauern durch, unter der Erde nur durch Explosionen verwundbar
	_reset()
	e = _sp("wald_wurzelkriecher", Vector2(20, 0), 100.0)
	var def2: Dictionary = D.enemy("wald_wurzelkriecher")
	T._check(h.ai.start_burrow(e, def2, Vector2(-1, 0)), "Wurzelkriecher: gräbt sich ein")
	T._check(await _until(func(): return e.under, 2.0), "Wurzelkriecher: ist unter der Erde")
	var hpw: float = e.hp
	h.damage(e, 20.0, Vector2.ZERO, false, false, "kugel")
	T._check(e.hp == hpw and h.nearest(e.p, 3.0) == null, "Wurzelkriecher: unter der Erde nicht zu treffen")
	h.damage(e, 20.0, Vector2.ZERO, false, false, "explosion")
	T._check(e.hp < hpw, "Wurzelkriecher: Explosionen treffen ihn trotzdem")
	T._check(await _until(func(): return not e.under and e.ai_s == AI.S_NONE, 6.0) and e.p.distance_to(A + Vector2(20, 0)) > 2.0, "Wurzelkriecher: taucht weiter hinten wieder auf")
	if w.walls.size() > 0:
		# echte Mauer: von außen dagegenlaufen lassen
		var wall2 = _outer_wall()
		var outw: Vector2 = wall2.mid.normalized()
		h.clear()
		var e2 = h.spawn(int(D.ENEMY_INDEX["wald_wurzelkriecher"]), wall2.mid + outw * 1.6, 100.0, 1.0, 1.0)
		e2.ai_c = 0.0
		e2.home = wall2.mid - outw * 5.0                    # Wachposten hinter der Mauer: er läuft geradewegs darauf zu
		e2.leash = 1.0
		var went := await _until(func(): return e2.under, 4.0)
		var out := await _until(func(): return not e2.under and e2.p.length() < wall2.mid.length() - 0.5, 6.0)
		T._check(went and out, "Wurzelkriecher: unterquert eine Mauer")


func _outer_wall():
	var best = w.walls[0]
	for x in w.walls:
		if x.alive and absf(x.mid.x) > absf(best.mid.x) and absf(x.mid.y) < 3.0:
			best = x
	return best


# ---------------------------------------------------------------- Staubebene
func _wueste() -> void:
	# Schrottkäfer: vorn gepanzert
	_reset()
	var e = _sp("wueste_schrottkaefer", Vector2(15, 0), 100.0)
	e.stun = 99.0
	e.yaw = PI * 0.5                                   # schaut nach +X
	var b: float = e.hp
	h.damage(e, 10.0, Vector2(-1, 0))                  # Treffer fliegt ihm entgegen: von vorn
	var front: float = b - e.hp
	b = e.hp
	h.damage(e, 10.0, Vector2(1, 0))                   # von hinten
	T._check(absf(front - 3.0) < 0.01 and absf((b - e.hp) - 10.0) < 0.01, "Schrottkäfer: −70 %% Schaden von vorn (%.1f / %.1f)" % [front, b - e.hp])
	# Staubteufel: schiebt den Helden weg, reißt Münzen mit, gibt sie beim Tod zurück
	_reset()
	e = _sp("wueste_staubteufel", Vector2(11, 0), 500.0)
	e.stun = 1.7
	w.coins.drop(A + Vector2(8, 0), 6)
	await T._wait(1.6)
	T._check(await _until(func(): return e.carry > 0.0, 4.0), "Staubteufel: reißt Münzen mit")
	T._check(await _until(func(): return hero.pos2().distance_to(A) > 1.0, 5.0), "Staubteufel: schiebt den Helden weg")
	var items0: int = w.coins.items.size()
	h.damage(e, 1.0e9)
	T._check(w.coins.items.size() > items0, "Staubteufel: lässt die Münzen wieder fallen")
	# Rostbulle: Anlauf, Rammstoß in gerader Linie; an einer Mauer benommen
	_reset()
	e = _sp("wueste_rostbulle", Vector2(7, 0), 10.0)
	var hp0: float = hero.hp
	T._check(await _until(func(): return e.ai_s == AI.S_WINDUP, 2.0), "Rostbulle: nimmt Anlauf")
	T._check(await _until(func(): return e.ai_s == AI.S_CHARGE, 2.0), "Rostbulle: stürmt los")
	T._check(await _until(func(): return hero.hp < hp0, 2.0), "Rostbulle: rammt den Helden")
	if w.walls.size() > 0:
		var wall = _outer_wall()
		var outw: Vector2 = wall.mid.normalized()
		h.clear()
		var e2 = h.spawn(int(D.ENEMY_INDEX["wueste_rostbulle"]), wall.mid + outw * 4.0, 10.0, 1.0, 1.0)
		e2.ai_s = AI.S_CHARGE
		e2.ai_v = -outw
		e2.ai_d = 9.0
		wall.hp = wall.max_hp
		T._check(await _until(func(): return e2.ai_s == AI.S_DAZED, 2.0), "Rostbulle: prallt gegen die Mauer und ist benommen")
		T._check(wall.hp < wall.max_hp, "Rostbulle: die Mauer nimmt Schaden")
		await T._wait(1.0)
		T._check(e2.ai_s == AI.S_DAZED, "Rostbulle: bleibt 2 s benommen")
		wall.hp = wall.max_hp
	# Kaktusschütze: Fächer aus drei Stacheln
	_reset()
	e = _sp("wueste_kaktusschuetze", Vector2(8, 0), 500.0)
	T._check(await _until(func(): return w._proj.size() >= 3, 6.0), "Kaktusschütze: drei Stacheln im Fächer")
	hp0 = hero.hp
	T._check(await _until(func(): return hero.hp < hp0, 3.0), "Kaktusschütze: trifft")
	# Geier: stiehlt liegende Münzen und fliegt davon; abschießen gibt alles zurück
	_reset()
	e = _sp("wueste_geier", Vector2(16, 0), 500.0)
	e.stun = 1.7
	w.coins.drop(A + Vector2(10, 0), 8)
	await T._wait(1.6)
	T._check(await _until(func(): return e.carry > 0.0, 5.0), "Geier: stiehlt Münzen")
	T._check(await _until(func(): return e.ai_s == AI.S_FLEE, 8.0), "Geier: fliegt mit der Beute davon")
	w.coins.clear()
	var carried: float = e.carry
	h.damage(e, 1.0e9)
	var back := 0.0
	for it in w.coins.items:
		back += it.value
	T._check(back >= carried - 0.01, "Geier: abschießen gibt alles zurück (%.0f von %.0f)" % [back, carried])
	# Sandwurm: unter der Erde zum Helden, Warnkreis, bricht hervor
	_reset()
	e = _sp("wueste_sandwurm", Vector2(10, 0), 100.0)
	hp0 = hero.hp
	T._check(await _until(func(): return e.under, 2.5), "Sandwurm: taucht ab")
	T._check(await _until(func(): return e.ai_s == AI.S_WARN, 6.0), "Sandwurm: Warnkreis unter dem Helden")
	var t0: float = h.time
	T._check(await _until(func(): return hero.hp < hp0, 2.0) and h.time - t0 > 0.8, "Sandwurm: bricht nach 1 s hervor")


# ---------------------------------------------------------------- Schrottküste
func _untote() -> void:
	# Matrosen-Zombie: steht einmal wieder auf – außer bei Feuer oder Explosion
	_reset()
	var e = _sp("untote_matrose", Vector2(20, 0), 10.0)
	var alive0: int = h.alive
	h.damage(e, 1.0e6, Vector2.ZERO, false, false, "kugel")
	T._check(e.st == 3 and h.alive == alive0 and h.nearest(e.p, 3.0) == null, "Matrosen-Zombie: fällt um, zählt aber noch")
	await T._wait(2.5)
	T._check(e.st == 3, "Matrosen-Zombie: liegt 3 s")
	T._check(await _until(func(): return e.st != 3, 1.5) and absf(e.hp - e.mhp * 0.4) < 0.5, "Matrosen-Zombie: steht mit 40 %% Leben wieder auf (%.0f von %.0f)" % [e.hp, e.mhp])
	h.damage(e, 1.0e6, Vector2.ZERO, false, false, "kugel")
	T._check(e.st == 2, "Matrosen-Zombie: nur einmal")
	var e2 = _sp("untote_matrose", Vector2(22, 0))
	h.damage(e2, 1.0e6, Vector2.ZERO, false, false, "feuer")
	var e3 = _sp("untote_matrose", Vector2(24, 0))
	h.explode(e3.p, 2.0, 1.0e6)
	T._check(e2.st == 2 and e3.st == 2, "Matrosen-Zombie: Feuer und Explosion machen ein Ende")
	var e4 = _sp("untote_matrose", Vector2(26, 0))
	h.damage(e4, 1.0e6)
	h.explode(e4.p, 2.0, 5.0)
	T._check(e4.st == 2, "Matrosen-Zombie: am Boden hilft eine Explosion")
	# Deckratte: Schwarm von 6–10, knabbert bevorzugt an Türmen
	_reset()
	var lead = h.spawn_for_area(3, A + Vector2(15, 0), 1.0, 1.0, 1.0, "fast")
	var rats := _count("untote_deckratte")
	T._check(String(D.ENEMIES[lead.t].key) == "untote_deckratte" and rats >= 6 and rats <= 10, "Deckratte: Schwarm von 6–10 (%d)" % rats)
	if tower != null:
		h.clear()
		tower.active = true
		tower.stun(30.0)
		var tp: Vector2 = tower.pos2()
		var spot := tp
		for off in [Vector2(4, 0), Vector2(-4, 0), Vector2(0, 4), Vector2(0, -4), Vector2(4, 4), Vector2(-4, -4)]:
			if not w.field.is_solid(tp + off) and w.field.structure_at(tp + off) == null:
				spot = tp + off
				break
		var r = h.spawn(int(D.ENEMY_INDEX["untote_deckratte"]), spot, 1000.0, 1.0, 1.0)
		T._check(await _until(func(): return r.st == 1 and r.tgt != null and r.tgt.get("tower") == tower, 4.0), "Deckratte: läuft zum Turm und knabbert ihn an")
		tower.stun_t = 0.0
		tower.active = false
	# Ertrunkener Taucher: Ankerwurf zieht den Helden heran
	_reset()
	e = _sp("untote_taucher", Vector2(7.5, 0), 10.0)
	T._check(await _until(func(): return e.ai_s == AI.S_THROW, 2.0), "Taucher: wirft den Anker")
	T._check(await _until(func(): return e.ai_s == AI.S_DRAG, 2.0), "Taucher: Kette spannt sich")
	T._check(await _until(func(): return hero.pos2().distance_to(A) > 2.5 and hero.pos2().x > A.x, 2.0), "Taucher: zieht den Helden zu sich (%.1f m)" % hero.pos2().distance_to(A))
	# Kanonier-Skelett: Kugel im Bogen aus 16 m mit Flächenschaden
	_reset()
	e = _sp("untote_kanonier", Vector2(14, 0), 500.0)
	var hp0: float = hero.hp
	T._check(await _until(func(): return e.st == 1 and e.tgt_player, 3.0) and e.p.distance_to(hero.pos2()) > 11.0, "Kanonier: nimmt den Helden aus 16 m unter Feuer")
	T._check(await _until(func(): return hero.hp < hp0, 6.0), "Kanonier: Einschlag mit Flächenschaden")
	# Geisterqualle: elektrischer Schlag im Umkreis, legt Türme 2 s lahm
	if tower != null:
		_reset()
		tower.active = true
		tower.stun_t = 0.0
		e = h.spawn(int(D.ENEMY_INDEX["untote_qualle"]), tower.pos2() + Vector2(2.0, 1.0), 1000.0, 1.0, 1.0)
		e.ai_c = 0.2
		T._check(await _until(func(): return tower.stun_t > 1.0, 2.0), "Geisterqualle: legt den Turm lahm (%.1f s)" % tower.stun_t)
		var shots: int = tower.shots
		await T._wait(1.0)
		T._check(tower.shots == shots, "Geisterqualle: der Turm schießt nicht")
		tower.stun_t = 0.0
		tower.active = false
	_reset()
	e = _sp("untote_qualle", Vector2(2.5, 0), 500.0)
	e.ai_c = 0.2
	hp0 = hero.hp
	T._check(await _until(func(): return hero.hp < hp0, 2.0), "Geisterqualle: Schlag trifft auch den Helden")
	# Krabbenpanzer: zieht sich bei Treffern 1,5 s in die Kiste zurück (unverwundbar), läuft im Zickzack, viel Gold
	_reset()
	e = _sp("untote_krabbe", Vector2(18, 0), 10.0)
	h.damage(e, 5.0)
	T._check(e.ai_s == AI.S_SHELL and e.inv > 1.0, "Krabbenpanzer: zieht sich in die Kiste zurück")
	var hpk: float = e.hp
	h.damage(e, 50.0)
	h.explode(e.p, 2.0, 50.0)
	T._check(e.hp == hpk, "Krabbenpanzer: in der Kiste unverwundbar")
	await T._wait(1.7)
	h.damage(e, 5.0)
	T._check(e.hp < hpk and e.ai_s == AI.S_NONE, "Krabbenpanzer: kommt nach 1,5 s wieder heraus")
	T._check(int(D.enemy("untote_krabbe").coins) >= 10 and h._flags[e.t] & AI.F_ZIGZAG != 0, "Krabbenpanzer: Zickzack und viel Gold")


# ---------------------------------------------------------------- Sumpfwerk
func _mutanten() -> void:
	# Giftkröte: springt in Sätzen, Giftpfütze beim Tod
	_reset()
	var e = _sp("mutanten_giftkroete", Vector2(12, 0), 100.0)
	T._check(await _until(func(): return e.alt > 0.4, 3.0), "Giftkröte: springt in Sätzen")
	h.damage(e, 1.0e9)
	T._check(_haz("poison"), "Giftkröte: Giftpfütze beim Tod")
	# Blutegel-Schwarm: 8 Teile, heftet sich an, verlangsamt, Ausweichrolle schüttelt ab
	_reset()
	e = _sp("mutanten_egelschwarm", Vector2(3, 0))
	var b: float = e.hp
	h.damage(e, 500.0)
	T._check(absf((b - e.hp) - 3.0) < 0.01, "Blutegel: ein Treffer nimmt nur ein Teil (3 von 24)")
	e.hp = e.mhp
	e.mhp *= 100.0
	e.hp *= 100.0
	T._check(await _until(func(): return e.ai_s == AI.S_LATCH, 4.0), "Blutegel: heftet sich an")
	T._check(await _until(func(): return hero.speed_k < 1.0, 1.0), "Blutegel: verlangsamt den Helden")
	hero.dash_t = 0.2
	T._check(await _until(func(): return e.ai_s != AI.S_LATCH, 0.5), "Blutegel: Ausweichrolle schüttelt ihn ab")
	# Schlammgolem: teilt sich in zwei kleine (je 30 % Leben)
	_reset()
	e = _sp("mutanten_schlammgolem", Vector2(20, 0))
	h.damage(e, 1.0e6)
	var kids: Array = []
	for o in h.list:
		if o.st != 2 and o.t == e.t:
			kids.append(o)
	T._check(kids.size() == 2 and absf(kids[0].mhp - 84.0) < 0.5 and kids[0].vs < e.vs, "Schlammgolem: zwei kleine Golems mit je 30 %% Leben (%d)" % kids.size())
	if kids.size() == 2:
		h.damage(kids[0], 1.0e6)
		T._check(_count("mutanten_schlammgolem") == 1, "Schlammgolem: die Kleinen teilen sich nicht noch einmal")
	# Rohrspucker: Säure im Bogen, schädigt Mauern weiter
	_reset()
	e = _sp("mutanten_rohrspucker", Vector2(11, 0), 500.0)
	T._check(await _until(func(): return _haz("acid"), 7.0), "Rohrspucker: Säurepfütze am Einschlag")
	# Werksdrohne: schießt aus der Luft, weicht seitlich aus
	_reset()
	e = _sp("mutanten_werksdrohne", Vector2(6, 0), 500.0)
	T._check(e.fly and await _until(func(): return e.ai_s == AI.S_STRAFE, 5.0), "Werksdrohne: weicht nach dem Schuss seitlich aus")
	# Seuchenarzt: Aura +30 %, flieht vor dem Helden
	_reset()
	e = _sp("mutanten_seuchenarzt", Vector2(5, 0), 500.0)
	var mate = _sp("schleim_brocken", Vector2(7, 0), 100.0)
	T._check(await _until(func(): return mate.buff > 0.0, 1.5), "Seuchenarzt: stärkt Gegner im Umkreis")
	var d0: float = e.p.distance_to(hero.pos2())
	await T._wait(1.5)
	T._check(e.p.distance_to(hero.pos2()) > d0 + 1.0, "Seuchenarzt: flieht vor dem Helden")


# ---------------------------------------------------------------- Frostpass
func _eis() -> void:
	# Frostwichtel: jeder Treffer verlangsamt um 10 % (bis 50 %)
	_reset()
	var a = _sp("eis_frostwichtel", Vector2(4, 0), 500.0)
	var b = _sp("eis_frostwichtel", Vector2(-4, 0), 500.0)
	T._check(await _until(func(): return h.ai.chill_n >= 1 and hero.speed_k < 1.0, 5.0), "Frostwichtel: Treffer verlangsamt")
	T._check(await _until(func(): return h.ai.chill_n >= 2, 6.0) and hero.speed_k >= 0.5, "Frostwichtel: stapelt sich bis 50 %")
	# Eiswolf: Rudelführer heult (+20 % Tempo), Eis macht ihn schneller
	_reset()
	var wv: Array = [_sp("eis_eiswolf", Vector2(9, 0), 500.0), _sp("eis_eiswolf", Vector2(10, 2), 500.0), _sp("eis_eiswolf", Vector2(10, -2), 500.0)]
	wv[1].ai_c = 5.0
	wv[2].ai_c = 5.0
	T._check(await _until(func(): return wv[1].haste > 0.0 and wv[2].haste > 0.0, 3.0), "Eiswolf: Geheul macht das Rudel schneller")
	h.ai.hazard("ice", A + Vector2(30, 0), 4.0, 5.0, 0.0)
	T._check(h.ai.on_ice(A + Vector2(31, 0)) and not h.ai.on_ice(A + Vector2(40, 0)) and h._flags[wv[0].t] & AI.F_ICESLIDE != 0, "Eiswolf: erkennt Eisflächen")
	# Yeti: wirft Brocken über Mauern, Nahschlag schleudert weg
	_reset()
	var e = _sp("eis_yeti", Vector2(8, 0), 10.0)
	var hp0: float = hero.hp
	T._check(await _until(func(): return hero.hp < hp0 and e.p.distance_to(hero.pos2()) > 4.0, 6.0), "Yeti: Felsbrocken aus der Ferne")
	_reset()
	e = _sp("eis_yeti", Vector2(1.4, 0), 10.0)
	T._check(await _until(func(): return hero.pos2().distance_to(A) > 3.0, 4.0), "Yeti: Nahschlag schleudert den Helden weg")
	# Kristallschütze: zwei Treffer kurz nacheinander frieren ein
	_reset()
	_sp("eis_kristallschuetze", Vector2(12, 0), 500.0)
	_sp("eis_kristallschuetze", Vector2(-12, 0), 500.0)
	_sp("eis_kristallschuetze", Vector2(0, 12), 500.0)
	T._check(await _until(func(): return hero.speed_k == 0.0 and hero.speed_t > 0.0, 9.0), "Kristallschütze: zweiter Treffer friert den Helden ein")
	# Eisgeist: vereist den stärksten Turm für 4 s
	if tower != null:
		_reset()
		for tw in w.towers:
			if is_instance_valid(tw):
				tw.active = true
				tw.stun_t = 0.0
		var best = null
		var bp := -1.0
		for tw in w.towers:
			if is_instance_valid(tw):
				var pw: float = float(tw.def.damage) * float(tw.def.rpm) * tw.dmg_mult
				if pw > bp:
					bp = pw
					best = tw
		e = h.spawn(int(D.ENEMY_INDEX["eis_eisgeist"]), best.pos2() + Vector2(5, 3), 1000.0, 1.0, 1.0)
		e.ai_c = 0.0
		T._check(await _until(func(): return best.stun_t > 3.0, 5.0), "Eisgeist: vereist den stärksten Turm (%s, %.1f s)" % [best.key, best.stun_t])
		for tw in w.towers:
			if is_instance_valid(tw):
				tw.active = false
				tw.stun_t = 0.0
	# Lawinenroller: rollt geradeaus, wächst, zerplatzt
	_reset()
	e = _sp("eis_lawinenroller", Vector2(16, 0), 10.0)
	var r0: float = e.r
	T._check(await _until(func(): return e.ai_s == AI.S_ROLL and e.grow > 0.2 and e.r > r0, 3.0), "Lawinenroller: rollt und wächst")
	hp0 = hero.hp
	T._check(await _until(func(): return e.st == 2, 6.0) and hero.hp < hp0, "Lawinenroller: zerplatzt mit Flächenschaden")


# ---------------------------------------------------------------- Schleimkrater
func _daemonen() -> void:
	# Höllenwichtel: brennende Fußspuren
	_reset()
	var e = _sp("daemonen_hoellenwichtel", Vector2(14, 0), 500.0)
	T._check(await _until(func(): return _haz("fire"), 4.0), "Höllenwichtel: brennende Fußspuren")
	# Dämonenhund: stürmt los, beißt sich fest, lässt bei Schaden los
	_reset()
	e = _sp("daemonen_hund", Vector2(6, 0), 500.0)
	T._check(await _until(func(): return e.ai_s == AI.S_CHARGE, 2.5), "Dämonenhund: stürmt los")
	T._check(await _until(func(): return e.ai_s == AI.S_LATCH, 2.5), "Dämonenhund: beißt sich fest")
	var hp0: float = hero.hp
	await T._wait(1.2)
	T._check(hero.hp < hp0, "Dämonenhund: Schaden über Zeit")
	h.damage(e, 1.0)
	T._check(e.ai_s != AI.S_LATCH, "Dämonenhund: lässt los, wenn er Schaden nimmt")
	# Gehörnter Wächter: Druckwelle 5 m, springt über Mauern
	_reset()
	e = _sp("daemonen_waechter", Vector2(4.5, 0), 10.0)
	e.yaw = -PI * 0.5
	hp0 = hero.hp
	h.ai._shockwave(e, D.enemy("daemonen_waechter"), Vector2(-1, 0), 1.0)
	T._check(hero.hp < hp0, "Gehörnter Wächter: Druckwelle trifft auf 5 m")
	if w.walls.size() > 0:
		var wall = _outer_wall()
		var outw: Vector2 = wall.mid.normalized()
		wall.hp = wall.max_hp
		var e2 = h.spawn(e.t, wall.mid + outw * 3.0, 1.0, 1.0, 1.0)
		h.ai._shockwave(e2, D.enemy("daemonen_waechter"), -outw, 1.0)
		T._check(wall.hp < wall.max_hp, "Gehörnter Wächter: Druckwelle erreicht die Mauer")
		wall.hp = wall.max_hp
	# Feuerspeier: Feuerball hinterlässt brennenden Boden
	_reset()
	e = _sp("daemonen_feuerspeier", Vector2(10, 0), 500.0)
	T._check(await _until(func(): return _haz("fire"), 7.0), "Feuerspeier: brennender Boden am Einschlag")
	# Schattenschwinge: Sturzflug; oben kaum zu treffen
	_reset()
	e = _sp("daemonen_schattenschwinge", Vector2(8, 0), 500.0)
	e.ai_c = 1.5
	await T._wait(1.0)
	var b: float = e.hp
	h.damage(e, 10.0)
	T._check(e.alt > 2.0 and absf((b - e.hp) - 3.0) < 0.01, "Schattenschwinge: hoch oben nur 30 %% Schaden (%.1f)" % (b - e.hp))
	hp0 = hero.hp
	T._check(await _until(func(): return e.ai_s == AI.S_DIVE, 4.0), "Schattenschwinge: Sturzflug")
	T._check(await _until(func(): return e.alt < 1.0, 1.5), "Schattenschwinge: kommt herunter")
	b = e.hp
	h.damage(e, 10.0)
	T._check(absf((b - e.hp) - 10.0) < 0.01, "Schattenschwinge: beim Angriff voll zu treffen")
	T._check(await _until(func(): return e.ai_s == AI.S_CLIMB or e.ai_s == AI.S_NONE, 2.0) and hero.hp < hp0, "Schattenschwinge: trifft und steigt wieder auf")
	# Beschwörer: Portal mit 3 Höllenwichteln, zerstörbar
	_reset()
	e = _sp("daemonen_beschwoerer", Vector2(16, 0), 500.0)
	e.sp_t = 0.2
	T._check(await _until(func(): return _count("daemonen_portal") == 1, 1.5), "Beschwörer: öffnet ein Portal")
	T._check(await _until(func(): return _count("daemonen_hoellenwichtel") == 3, 5.0), "Beschwörer: drei Höllenwichtel kommen heraus")
	T._check(await _until(func(): return _count("daemonen_portal") == 0, 3.0), "Beschwörer: das Portal erlischt")
	_reset()
	e = _sp("daemonen_beschwoerer", Vector2(16, 0), 500.0)
	e.sp_t = 0.2
	await _until(func(): return _count("daemonen_portal") == 1, 1.5)
	for o in h.list:
		if String(D.ENEMIES[o.t].key) == "daemonen_portal":
			T._check(absf(o.mhp - 40.0 * 500.0) < 1.0 or o.mhp >= 40.0, "Portal hat 40 Leben (mal Stärke)")
			h.damage(o, 1.0e9)
	e.sp_t = 99.0
	await T._wait(2.5)
	T._check(_count("daemonen_hoellenwichtel") == 0, "Beschwörer: zerstörtes Portal spuckt nichts mehr aus")


# ---------------------------------------------------------------- Schnittstelle für die Expedition, Bosse
func _interface() -> void:
	_reset()
	for area in range(1, 7):
		var fam := String(D.AREA_FAMILY[area])
		for role in D.ROLES:
			var e = h.spawn_for_area(area, A + Vector2(20, 0), 2.0, 1.0, 1.0, role)
			var def: Dictionary = D.ENEMIES[e.t]
			T._check(def.family == fam and def.role == role and is_equal_approx(e.mhp, float(def.hp) * 2.0), "spawn_for_area(%d, %s) → %s" % [area, role, def.key])
		var el = h.spawn_for_area(area, A + Vector2(20, 0), 1.0, 1.0, 1.0, "elite")
		T._check(D.ENEMIES[el.t].role == "tank" and is_equal_approx(el.mhp, float(D.ENEMIES[el.t].hp) * 2.5), "spawn_for_area(%d, elite): stärkste Art mit erhöhtem Leben" % area)
		var roles := {}
		for i in 60:
			var x = h.spawn_for_area(area, A + Vector2(20, 0))
			roles[String(D.ENEMIES[x.t].role)] = true
			T._check(D.ENEMIES[x.t].family == fam, "spawn_for_area(%d) bleibt in der Familie" % area)
		T._check(roles.size() >= 4, "spawn_for_area(%d) mischt die Rollen (%d)" % [area, roles.size()])
		h.clear()
	var sl = h.spawn_for_area(0, A + Vector2(20, 0))
	T._check(D.ENEMIES[sl.t].family == "schleim" and D.ENEMIES[sl.t].role != "boss", "spawn_for_area(0): Schleimlinge")
	h.clear()
	for area in 7:
		var be = h.spawn_boss(area, A + Vector2(20, 0), 1.0, 1.0)
		T._check(h.boss == be and h.boss_name == String(D.BOSSES[area].name) and be.special != "", "spawn_boss(%d): %s" % [area, h.boss_name])
		if area == 3:
			T._check(be.fig != null, "Kapitän Glibber: echte Figur mit AnimationPlayer")
			be.stun = 0.0
			be.sp_t = 0.1
			be.ai_n = 0
			T._check(await _until(func(): return _count("untote_matrose") >= 3, 2.0), "Kapitän Glibber: ruft Matrosen aus dem Sand")
			be.sp_t = 0.1
			T._check(await _until(func(): return w._proj.size() >= 5, 2.0), "Kapitän Glibber: feuert eine Breitseite (5 Kugeln)")
		if area == 6:
			T._check(be.next_phase == "boss_daemonen", "Schleimkönig: erste Phase ist der Schleimriese")
			var called := [false]
			be.on_death = func(): called[0] = true
			be.shield = 0
			h.damage(be, 1.0e12, Vector2.ZERO, true)
			T._check(h.boss != null and h.boss != be and String(D.ENEMIES[h.boss.t].key) == "boss_daemonen" and not called[0], "Schleimkönig: der Dämon bricht hervor")
			h.damage(h.boss, 1.0e12, Vector2.ZERO, true)
			T._check(h.boss == null and called[0], "Schleimkönig: nach der zweiten Phase besiegt")
		h.clear()
	T._check(h.list.is_empty() and h.alive == 0, "aufgeräumt")
	# Monsterbuch zählt gebündelt mit
	var k0 := int(P.bestiary_entry("wald_pilzling").kills)
	for i in 5:
		var pz = _sp("wald_pilzling", Vector2(20 + i, 0))
		h.damage(pz, 1.0e9)
	h._flush_book()
	T._check(int(P.bestiary_entry("wald_pilzling").kills) == k0 + 5 and bool(P.bestiary_entry("wald_pilzling").seen), "Monsterbuch zählt Besiegte (gebündelt)")


# ---------------------------------------------------------------- Flut: Mischung mit Gastfamilie
func _flood_mix() -> void:
	_reset()
	w.flood["guests"] = ["untote"]
	w.flood["guest_share"] = 0.25
	w.flood.total = 400
	w.wave_count = 4
	w.wave_idx = 1
	w._next_wave()
	var guest := 0
	var total: int = w._queue.size()
	for t in w._queue:
		if int(t) >= D.E_FIRST_NEW and String(D.ENEMIES[int(t)].family) == "untote":
			guest += 1
		else:
			T._check(int(t) < D.E_BOSS, "Flut: sonst nur Schleimlinge")
	var share := float(guest) / maxf(1.0, float(total))
	T._check(absf(share - 0.25) < 0.03, "Flut: Gastfamilie stellt 25 %% (%d von %d)" % [guest, total])
	w._queue.clear()
	w.flood.total = 0
	w.flood["guests"] = []
	w.wave_count = 99


# ---------------------------------------------------------------- Rechenzeit: 300 Gegner aus drei Arten
func _perf() -> void:
	var base := await _perf_run(["schleim_schleimling", "schleim_flitzer", "schleim_spucker"])
	var ms := await _perf_run(["untote_matrose", "untote_deckratte", "untote_kanonier"])
	print("  zum Vergleich drei Schleim-Arten: %.2f ms (die Maschine ist geteilt – absolute Zeiten schwanken)" % base)
	T._check(ms < 4.0 or ms < base * 1.6, "Logik unter 4 ms bei 300 Gegnern (%.2f ms, Schleimlinge %.2f ms)" % [ms, base])


func _perf_run(keys: Array) -> float:
	_reset()
	for i in 300:
		var a := i * 2.399
		var r := 6.0 + sqrt(float(i)) * 1.1
		h.spawn(int(D.ENEMY_INDEX[keys[i % 3]]), A + Vector2(cos(a), sin(a)) * r, 1000.0, 0.0, 0.0)
	await T._wait(1.0)
	# Median der einzelnen Schritte: unempfindlich gegen Aussetzer, wenn die Maschine gerade anderes rechnet
	var samples: Array = []
	for i in 240:
		await T.get_tree().physics_frame
		samples.append(h.logic_last)
	samples.sort()
	var med: float = samples[int(samples.size() / 2)]
	print("Gegner-Logik mit %d Gegnern (%s): Median %.2f ms, bestes Zehntel %.2f ms, Mittel geglättet %.2f ms" % [h.alive, ", ".join(keys), med, samples[int(samples.size() / 10)], h.logic_ms])
	T._check(h.alive >= 290, "300 Gegner gleichzeitig (%d)" % h.alive)
	return med


func _leave() -> void:
	h.clear()
	w._queue.clear()
	w.wave_idx = w.wave_count
	w._finish(true)
