extends RefCounted
## Prüfungen für Paket G2 (Gegner, Bosse, Fallen, Deko):
##  - Daten und Modelle: 21 neue Arten (je Familie drei neue Rollen) + 7 Minibosse + Weltboss, Clips je Rolle, Symbole
##  - Verhalten: Heiler, Schildträger, Tunnelgräber, Turmstörer, Dieb, Brutmutter, Miniboss (Bodenmarkierung, Leiste)
##  - Elite (Krone, Aura, Namensschild), Flut-Planung (neue Rollen, Elite ab Woche 4, Miniboss ab Woche 5)
##  - Bosse: Auftritt, Phase 2, Wutphase, Schwachstelle; Weltboss; Trophäe nach dem ersten Sieg
##  - Fallen: Teergrube, Federbrett, Lockköder, Elektrozaun, Eisfalle · Deko-Punkte · Trümmer · Bau-Animation
##  - Fehlerbehebungen: Bach an der Ost-Zufahrt, Vorbereitungs-Clips (knien, aufblähen), Rechenzeit
## Aufruf aus tests.gd (--selftest) oder allein mit --autotest=gegner2. Nutzt die Arena von src/tests_gegner.gd.

const D = preload("res://src/data.gd")
const Vat = preload("res://src/vat.gd")
const AI = preload("res://src/enemy_ai.gd")
const Models = preload("res://src/models.gd")
const Gegner = preload("res://src/tests_gegner.gd")
const BuildFx = preload("res://src/build_fx.gd")
const BaseNature = preload("res://src/base_nature.gd")

var T: Node
var tg                               # Arena-Helfer aus tests_gegner.gd
var w
var h
var hero
var A := Vector2.ZERO

const ROLE_CLIP := {"healer": "heal", "shield": "block", "digger": "dig", "jammer": "jam", "thief": "grab", "brood": "brood", "miniboss": "skill"}


func _init(tests: Node) -> void:
	T = tests


func run() -> void:
	if G.arg("show") != "":
		await show()
		return
	if G.arg("perf") != "":
		# Messung: --autotest=gegner2 --perf=key1,key2 (je 300 Gegner einer Art)
		tg = Gegner.new(T)
		await tg._arena()
		for k in G.arg("perf").split(","):
			var ms: float = await tg._perf_run([k, k, k])
			print("PERF %s %.2f ms" % [k, ms])
		tg._leave()
		return
	_data()
	_models()
	_rules()
	tg = Gegner.new(T)
	await tg._arena()
	w = tg.w
	h = tg.h
	hero = tg.hero
	A = tg.A
	await _healer()
	await _shield()
	await _tunnel()
	await _jammer()
	await _thief()
	await _brood()
	await _miniboss()
	await _elite()
	_flood_plan()
	await _bosses()
	await _world_boss()
	await _traps()
	await _aim_clips()
	await _buildings()
	_brook()
	await _perf()
	tg._leave()


func _sp(key: String, off: Vector2, hpm := 1.0):
	return tg._sp(key, off, hpm)


func _until(cond: Callable, sec: float) -> bool:
	return await tg._until(cond, sec)


# ---------------------------------------------------------------- Daten
func _data() -> void:
	var roles_all := {}
	var n := 0
	for fam in D.AREA_FAMILY:
		var extra := {}
		for i in D.family_all(String(fam)):
			var r := String(D.ENEMIES[i].role)
			if D.ROLES_EXTRA.has(r):
				extra[r] = true
				roles_all[r] = true
				n += 1
		T._check(extra.size() >= 3, "%s: mindestens drei neue Rollen (%s)" % [fam, ", ".join(extra.keys())])
		var mt := D.family_mini(String(fam))
		T._check(mt >= 0 and String(D.ENEMIES[mt].role) == "miniboss", "%s: Miniboss %s" % [fam, String(D.ENEMIES[mt].name) if mt >= 0 else "fehlt"])
		T._check(D.family_enemies(String(fam)).size() == (8 if fam == "schleim" else 6), "%s: Grundrollen unverändert" % fam)
	T._check(n >= 21, "mindestens 21 neue Arten (%d)" % n)
	T._check(roles_all.size() == D.ROLES_EXTRA.size(), "alle sechs neuen Rollen kommen vor (%d)" % roles_all.size())
	T._check(D.ENEMY_INDEX.has("boss_leviathan") and bool(D.enemy("boss_leviathan").get("world", false)), "Weltboss in den Daten")
	for key in D.BOSS_PHASES:
		T._check(D.ENEMY_INDEX.has(key), "Boss-Phasen: %s bekannt" % key)
	for a in ["healer", "shield_front", "tunnel", "jammer", "thief", "brood", "miniboss"]:
		T._check(AI.NAMES.has(a), "Baustein %s bekannt" % a)
	for i in D.ENEMIES.size():
		var e: Dictionary = D.ENEMIES[i]
		if D.ROLES_EXTRA.has(String(e.role)) or e.role == "miniboss":
			T._check(e.has("counter") and e.has("look") and e.has("text") and D.enemy_places(String(e.key)).size() > 0, "%s: Tipp, Beschreibung, Fundort" % e.key)


# ---------------------------------------------------------------- Modelle
func _models() -> void:
	for i in D.ENEMIES.size():
		var e: Dictionary = D.ENEMIES[i]
		var role := String(e.role)
		if not ROLE_CLIP.has(role):
			continue
		var key := String(e.key)
		T._check(Vat.has(key), "%s: eigenes Modell (Animations-Textur)" % key)
		T._check(ResourceLoader.exists("res://icons/e_%s.png" % key), "%s: Symbol" % key)
		if Vat.has(key):
			var d: Dictionary = Vat.data(key)
			T._check(d.clips.has(ROLE_CLIP[role]), "%s: Clip %s" % [key, ROLE_CLIP[role]])
			if role == "digger":
				T._check(d.clips.has("under") and d.clips.has("rise"), "%s: Clips under/rise" % key)
	var bi: Dictionary = Vat.boss_info("boss_leviathan")
	T._check(not bi.is_empty() and bi.clips.has("special") and int(bi.tris) <= 8000, "Schleim-Leviathan: echte Boss-Figur")
	T._check(Vat.data("untote_kanonier").clips.has("kneel") and Vat.data("daemonen_feuerspeier").clips.has("puff"), "Clips „kneel“ und „puff“ vorhanden")
	for m in ["fx_elite_crown", "fx_elite_aura", "fx_weakspot", "fx_boss_rage", "fx_build_parts", "b_rubble_1", "b_rubble_2", "b_rubble_3", "b_rubble_4"]:
		T._check(Models.has_glb(m), "Modell %s" % m)
	for k in D.BUILDINGS:
		var b: Dictionary = D.BUILDINGS[k]
		if D.TRAP.has(k) or b.has("deco") or b.has("trophy"):
			T._check(Models.has_glb("b_" + k) and ResourceLoader.exists("res://icons/b_%s.png" % k), "Gebäude %s: Modell und Symbol" % k)
	for ic in ["ui_bullet", "ui_bomb", "ui_poison"]:
		T._check(ResourceLoader.exists("res://icons/%s.png" % ic), "Symbol %s" % ic)


# ---------------------------------------------------------------- Regeln außerhalb des Kampfes
func _rules() -> void:
	P.new_game()
	P.no_save = true
	var base := P.deco_points()
	var b0 := {"id": 9001, "key": "brunnen", "x": 0, "y": 0, "rot": 0, "level": 1}
	var b1 := {"id": 9002, "key": "bank", "x": 2, "y": 0, "rot": 0, "level": 1}
	P.d.buildings.append(b0)
	P.d.buildings.append(b1)
	T._check(P.deco_points() == base + 10, "Deko-Punkte: Brunnen 8 + Bank 2 (%d)" % (P.deco_points() - base))
	var saw: Dictionary = {}
	for b in P.d.buildings:
		if D.BUILDINGS[b.key].has("prod"):
			saw = b
			break
	if not saw.is_empty():
		var r1 := P.prod_rate(saw)
		P.d.buildings.erase(b0)
		P.d.buildings.erase(b1)
		var r0 := P.prod_rate(saw)
		T._check(r1 > r0, "Deko-Punkte erhöhen die Produktion (%.1f → %.1f)" % [r0, r1])
	P.d.buildings.erase(b0)
	P.d.buildings.erase(b1)
	T._check(P.max_count("trophy_moos") == 0, "Trophäe gesperrt vor dem ersten Sieg")
	P.count_up("boss_win_boss_wald", 1)
	T._check(P.max_count("trophy_moos") == 1, "Trophäe nach dem Sieg baubar")
	T._check(P.deco_bonus() <= D.DECO_BONUS_MAX, "Deko-Bonus begrenzt")


# ---------------------------------------------------------------- Heiler
func _healer() -> void:
	tg._reset()
	var hl = _sp("wald_druide", Vector2(18, 0), 100.0)
	hl.stun = 99.0
	var a = _sp("wald_baumhueter", Vector2(19.5, 0), 10.0)
	a.stun = 99.0
	a.hp = a.mhp * 0.5
	var b = _sp("wald_baumhueter", Vector2(16.5, 0), 10.0)
	b.stun = 99.0
	b.hp = b.mhp * 0.5
	b.poison = 99.0
	hl.ai_t = 0.0
	var def: Dictionary = D.enemy("wald_druide")
	h.ai._heal_pulse(hl, def)
	T._check(a.hp > a.mhp * 0.5, "Heiler: heilt Verbündete im Umkreis")
	T._check(b.hp <= b.mhp * 0.5, "Heiler: Vergiftete werden nicht geheilt")
	var a1: float = a.hp
	hl.poison = 5.0
	h.ai._heal_pulse(hl, def)
	T._check(a.hp == a1, "Heiler: ein vergifteter Heiler heilt nicht")
	# hält Abstand zum Helden
	tg._reset()
	hl = _sp("untote_seehexe", Vector2(4, 0), 100.0)
	var d0: float = hl.p.distance_to(hero.pos2())
	await T._wait(1.5)
	T._check(hl.p.distance_to(hero.pos2()) > d0 + 1.0, "Heiler: bleibt auf Abstand zum Helden")


# ---------------------------------------------------------------- Schildträger
func _shield() -> void:
	tg._reset()
	var e = _sp("untote_schildmatrose", Vector2(15, 0), 100.0)
	e.stun = 99.0
	e.yaw = PI * 0.5                                   # schaut nach +X
	var b: float = e.hp
	h.damage(e, 10.0, Vector2(-1, 0), false, false, "kugel")       # fliegt ihm entgegen: von vorn
	T._check(e.hp == b, "Schildträger: Treffer von vorn prallen ab")
	h.damage(e, 10.0, Vector2(0, 1), false, false, "kugel")        # von der Seite
	T._check(e.hp < b, "Schildträger: von der Seite verwundbar")
	b = e.hp
	h.explode(e.p + Vector2(1.0, 0), 2.0, 10.0)
	T._check(e.hp < b, "Schildträger: Explosionen gehen durch")
	b = e.hp
	h.damage(e, 10.0, Vector2(1, 0), false, false, "kugel")        # von hinten
	T._check(absf((b - e.hp) - 10.0) < 0.01, "Schildträger: von hinten voller Schaden")


# ---------------------------------------------------------------- Tunnelgräber
func _tunnel() -> void:
	if w.walls.size() == 0:
		return
	var wall = tg._outer_wall()
	var outw: Vector2 = wall.mid.normalized()
	h.clear()
	var e = h.spawn(int(D.ENEMY_INDEX["wueste_maulwurf"]), wall.mid + outw * 1.8, 100.0, 1.0, 1.0)
	e.ai_c = 0.0
	e.home = wall.mid - outw * 5.0                      # läuft geradewegs auf die Mauer zu
	e.leash = 1.0
	var went := await _until(func(): return e.under, 5.0)
	var inside := await _until(func(): return not e.under and e.ai_s != AI.S_DIG and e.p.length() < wall.mid.length() - 1.0, 10.0)
	T._check(went and inside, "Tunnelgräber: gräbt sich unter der Mauer durch ins Innere (%.1f m vom Zentrum, Mauer %.1f m)" % [e.p.length(), wall.mid.length()])
	# Erschütterung: eine Explosion holt ihn heraus
	h.clear()
	e = h.spawn(int(D.ENEMY_INDEX["mutanten_maulwurf"]), A + Vector2(20, 0), 100.0, 1.0, 1.0)
	e.ai_c = 0.0
	T._check(h.ai.start_burrow(e, D.enemy("mutanten_maulwurf"), Vector2(-1, 0)), "Tunnelgräber: gräbt sich ein")
	await _until(func(): return e.under, 2.0)
	var hp0: float = e.hp
	h.damage(e, 10.0, Vector2.ZERO, false, false, "kugel")
	T._check(e.under and e.hp == hp0, "Tunnelgräber: unter der Erde nur durch Explosionen verwundbar")
	h.explode(e.p, 2.0, 10.0)
	T._check(not e.under and e.stun > 1.0 and e.hp < hp0, "Tunnelgräber: Explosion erschüttert ihn aus dem Boden")


# ---------------------------------------------------------------- Turmstörer
func _jammer() -> void:
	var tower = tg.tower
	if tower == null:
		return
	tg._reset()
	tower.active = true
	tower.stun_t = 0.0
	var e = h.spawn(int(D.ENEMY_INDEX["mutanten_stoerer"]), tower.pos2() + Vector2(6, 2), 1000.0, 1.0, 1.0)
	e.ai_c = 0.0
	T._check(await _until(func(): return tower.stun_t > 1.5, 6.0), "Turmstörer: legt den Turm lahm (%.1f s)" % tower.stun_t)
	tower.stun_t = 0.0
	tower.active = false


# ---------------------------------------------------------------- Dieb
func _thief() -> void:
	var store = null
	for s in w.structures:
		if s.alive and "key" in s and s.key == "lager":
			store = s
	if store == null:
		store = w.bunker_node
	var old_mode: String = w.mode
	w.mode = "flood"                                   # echte Flut: der Dieb zieht wirklich ab
	tg._reset()
	hero.global_position = Vector3(store.mid.x + 30, 0, store.mid.y + 30)
	for r in ["wood", "stone", "metal", "fuel"]:
		P.d.res[r] = 300
	var spot: Vector2 = store.mid + Vector2(store.radius + 1.2, 0)
	for off in [Vector2(store.radius + 1.2, 0), Vector2(-store.radius - 1.2, 0), Vector2(0, store.radius + 1.2), Vector2(0, -store.radius - 1.2)]:
		if not w.field.is_solid(store.mid + off) and w.field.structure_at(store.mid + off) == null:
			spot = store.mid + off
			break
	var e = h.spawn(int(D.ENEMY_INDEX["untote_pluenderer"]), spot, 100.0, 1.0, 1.0)
	var r0 := _res4()
	T._check(await _until(func(): return not e.loot.is_empty(), 6.0), "Dieb: plündert das Lager (%s)" % str(e.loot))
	T._check(_res4() < r0 and e.ai_s == AI.S_LOOT, "Dieb: Rohstoffe fehlen (%d → %d), er flieht (Zustand %d)" % [r0, _res4(), e.ai_s])
	h.damage(e, 1.0e9)
	T._check(_res4() == r0, "Dieb: besiegt gibt er die Beute zurück")
	# Flucht gelingt: die Beute ist weg
	var e2 = h.spawn(int(D.ENEMY_INDEX["daemonen_gierteufel"]), spot, 100.0, 1.0, 1.0)
	await _until(func(): return not e2.loot.is_empty(), 6.0)
	var r1 := _res4()
	e2.ai_d = 30.0
	T._check(await _until(func(): return e2.st == 2, 2.0) and _res4() == r1, "Dieb: entkommt mit der Beute")
	w.mode = old_mode
	tg._reset()


func _res4() -> int:
	return P.res("wood") + P.res("stone") + P.res("metal") + P.res("fuel")


# ---------------------------------------------------------------- Brutmutter
func _brood() -> void:
	tg._reset()
	var e = _sp("eis_schneemutter", Vector2(20, 0), 100.0)
	e.stun = 99.0
	e.ai_t = 0.0
	var n0: int = h.alive
	h.ai._brood(e, D.enemy("eis_schneemutter"))
	T._check(h.alive == n0 + 3 and tg._count("eis_frostwichtel") == 3, "Brutmutter: drei Frostwichtel")
	var sp = _sp("wald_spinnenmutter", Vector2(-20, 0), 100.0)
	sp.stun = 99.0
	n0 = h.alive
	h.ai._brood(sp, D.enemy("wald_spinnenmutter"))
	var kids := 0
	for o in h.list:
		if o.kid and o.t == sp.t:
			kids += 1
			T._check(o.vs < sp.vs * 0.6 and o.mhp < sp.mhp * 0.2, "Brutmutter: Junge sind klein und schwach")
			break
	T._check(h.alive == n0 + 4, "Moosspinnen-Mutter: vier junge Spinnen")
	# Obergrenze: höchstens brood_n x 3 Junge um eine Mutter
	for k in 6:
		await T._wait(0.05)
		h.ai._brood(e, D.enemy("eis_schneemutter"))
	T._check(tg._count("eis_frostwichtel") <= 9, "Brutmutter: höchstens 9 Junge in der Nähe (%d)" % tg._count("eis_frostwichtel"))
	# Expedition: ferne, ruhige Mutter brütet nicht
	tg._reset()
	var far = _sp("eis_schneemutter", hero.pos2() - A + Vector2(60, 0), 100.0)
	far.stun = 99.0
	far.leash = 14.0
	far.aggro = false
	n0 = h.alive
	h.ai._brood(far, D.enemy("eis_schneemutter"))
	T._check(h.alive == n0, "Brutmutter: brütet nicht, solange sie weit weg und ruhig ist")


# ---------------------------------------------------------------- Miniboss
func _miniboss() -> void:
	tg._reset()
	var e = h.spawn_planned(2000 + D.family_mini("wueste"), A + Vector2(5, 0), 1.0, 1.0)
	T._check(h.mini == e and String(D.ENEMIES[e.t].role) == "miniboss", "Miniboss: eigene Lebensleiste (horde.mini)")
	T._check(h.elite_fx.tagged.has(e), "Miniboss: Namensschild")
	e.sp_t = 0.0
	var hp0: float = hero.hp
	T._check(await _until(func(): return not h.ai.tele.is_empty(), 2.0), "Miniboss: Fähigkeit mit roter Bodenmarkierung")
	T._check(await _until(func(): return h.ai.tele.is_empty(), 2.5), "Miniboss: Markierung läuft ab")
	await T._wait(0.3)
	T._check(hero.hp < hp0 or tg._haz("acid"), "Miniboss: Fähigkeit wirkt (Säure)")
	h.damage(e, 1.0e9)
	T._check(h.mini == null, "Miniboss: Leiste verschwindet beim Tod")
	# alle Minibosse: Fähigkeit auslösen ohne Fehler
	for fam in D.AREA_FAMILY:
		tg._reset()
		var m = h.spawn_planned(2000 + D.family_mini(String(fam)), A + Vector2(4, 0), 1.0, 1.0)
		h.ai._mini_skill(m, D.ENEMIES[m.t], hero.pos2(), true)
		await T._wait(1.3)
		T._check(m.ai_s == AI.S_NONE or m.st == 2 or m.ai_s == AI.S_SKILL, "Miniboss %s: Fähigkeit" % String(D.ENEMIES[m.t].name))
	# Expedition: jede MINI_EXP_EVERY-te Belagerungs-Spawn wird ein Miniboss
	tg._reset()
	h._siege_n = D.MINI_EXP_EVERY - 1
	var s = h.spawn_family("eis", A + Vector2(10, 0), 1.0, 1.0, 1.0, "siege")
	T._check(String(D.ENEMIES[s.t].role) == "miniboss", "Expedition: Miniboss im Großangriff")


# ---------------------------------------------------------------- Elite
func _elite() -> void:
	tg._reset()
	var e = h.spawn_planned(1000 + h.strongest_type("untote"), A + Vector2(14, 0), 1.0, 1.0)
	T._check(e.elite and e.hunter and is_equal_approx(e.mhp, float(D.ENEMIES[e.t].hp) * D.ELITE_HP), "Elite: mehr Leben, jagt den Helden")
	await T._wait(0.2)
	T._check(h.elite_fx.tagged.has(e) and h.elite_fx._crown.visible_instance_count >= 1 and h.elite_fx._labels[0].visible and String(h.elite_fx._labels[0].text).begins_with("Elite"), "Elite: Krone, Aura und Namensschild")
	var el2 = h.spawn_for_area(2, A + Vector2(16, 0), 1.0, 1.0, 1.0, "elite")
	T._check(el2.elite, "Elite: auch aus der Expedition gekennzeichnet")


func _flood_plan() -> void:
	var q: Array = []
	h.plan_wave(q, 3, 2, 6, 100, [])
	T._check(q.is_empty(), "Flut Woche 3: noch keine Elite")
	q.clear()
	h.plan_wave(q, 6, 2, 7, 200, ["untote"])
	var el := 0
	var extra := 0
	for c in q:
		if int(c) >= 1000 and int(c) < 2000:
			el += 1
		elif int(c) < 1000 and D.FLOOD_EXTRA.has(String(D.ENEMIES[int(c)].key)):
			extra += 1
	T._check(el >= 1, "Flut ab Woche 4: Elite-Gegner in der Welle (%d)" % el)
	T._check(extra >= 5, "Flut: neue Schleim-Rollen in der Welle (%d)" % extra)
	q.clear()
	h.plan_wave(q, 6, 4, 7, 200, ["untote"])
	var mini := false
	for c in q:
		if int(c) >= 2000 and String(D.ENEMIES[int(c) - 2000].family) == "untote":
			mini = true
	T._check(mini, "Flut ab Woche 5: Miniboss der Gastfamilie in der mittleren Welle")


# ---------------------------------------------------------------- Bosse
func _bosses() -> void:
	for area in 7:
		tg._reset()
		var li: int = h.bossctl.log_intro
		var b = h.spawn_boss(area, A + Vector2(20, 0), 1.0, 1.0)
		T._check(h.bossctl.log_intro == li + 1, "Boss %d: Auftritt mit Name" % area)
		if area == 6:
			b.shield = 0
			h.damage(b, 1.0e12, Vector2.ZERO, true)
			b = h.boss
			T._check(b != null and b.phase == 2, "Schleimkönig: zweite Gestalt beginnt mit Phase 2")
		b.stun = 99.0
		var lp: int = h.bossctl.log_phase
		b.hp = b.mhp * 0.6
		await T._wait(0.15)
		var cfg: Dictionary = D.BOSS_PHASES.get(String(D.ENEMIES[b.t].key), {})
		if float(cfg.get("p2", 0.0)) > 0.0:
			T._check(b.phase == 2 and h.bossctl.log_phase == lp + 1 and b.specs.has(String(cfg.add)), "Boss %s: Phase 2 mit %s" % [D.ENEMIES[b.t].name, cfg.add])
		b.hp = b.mhp * 0.25
		var sp0: float = b.sp
		await T._wait(0.15)
		T._check(b.rage, "Boss %s: Wutphase unter 30 %%" % D.ENEMIES[b.t].name)
		# Schwachstelle: doppelter Schaden, solange sie offen ist
		b.stun = 0.0
		h.bossctl.expose_now(b)
		var hp1: float = b.hp
		h.damage(b, 10.0, Vector2.ZERO, true)
		var k1: float = hp1 - b.hp
		b.expose = 0.0
		hp1 = b.hp
		h.damage(b, 10.0, Vector2.ZERO, true)
		var k0: float = hp1 - b.hp
		T._check(absf(k1 - k0 * D.BOSS_EXPOSE_DMG) < 0.05, "Boss %s: Schwachstelle doppelter Schaden (%.1f / %.1f)" % [D.ENEMIES[b.t].name, k1, k0])
	# Bodenschlag mit Markierung, danach erschöpft
	tg._reset()
	var bb = h.spawn_boss(0, A + Vector2(4, 0), 1.0, 1.0)
	bb.special = "slam"
	bb.sp_t = 0.0
	T._check(await _until(func(): return not h.ai.tele.is_empty(), 1.0), "Boss: Bodenschlag mit roter Zone")
	T._check(await _until(func(): return bb.expose > 0.0, 2.0), "Boss: nach dem Schlag erschöpft (Schwachstelle)")
	h.damage(bb, 1.0e12, Vector2.ZERO, true)
	T._check(P.boss_beaten("schleim_boss") and P.max_count("trophy_bert") == 1, "Boss besiegt: Trophäe freigeschaltet")
	h.clear()


func _world_boss() -> void:
	tg._reset()
	var e = h.spawn(int(D.ENEMY_INDEX["boss_leviathan"]), A + Vector2(14, 0), 0.1, 1.0, 1.0)
	T._check(h.boss == e and e.fig != null and e.special == "cycle", "Weltboss: echte Figur, Sonderangriffe im Wechsel")
	for kind in ["tide", "rain"]:
		var n0: int = h.ai.tele.size()
		h.ai.boss_special(e, D.ENEMIES[e.t], kind, hero.pos2(), true)
		T._check(h.ai.tele.size() > n0 + 3, "Weltboss: %s mit Bodenmarkierungen" % kind)
	await T._wait(2.0)
	T._check(h.ai.tele.is_empty(), "Weltboss: Angriffe ausgeführt")
	h.clear()


# ---------------------------------------------------------------- Fallen
func _trap(key: String, c: Vector2) -> Dictionary:
	var tr := {"key": key, "s": null, "c": c, "lv": 1, "k": 1.0, "t": 0.0, "cd": 0.0, "uses": int(D.TRAP[key].get("uses", 1000000)), "fire": 0.0, "fire_cd": 0.0, "active": 0.0}
	return tr


func _traps() -> void:
	tg._reset()
	var t2 = load("res://src/traps2.gd").arm(w)
	t2.traps.clear()
	var c := A + Vector2(18, 0)
	# Teergrube: bremst, fängt Feuer
	t2.traps.append(_trap("teer", c))
	var e = _sp("schleim_brocken", Vector2(18, 0), 100.0)
	e.stun = 99.0
	T._check(await _until(func(): return e.slow > 0.0, 1.0), "Teergrube: bremst")
	e.burn = 2.0
	T._check(await _until(func(): return t2.traps[0].fire > 0.0, 1.0), "Teergrube: fängt Feuer")
	tg._reset()
	t2.traps.clear()
	# Federbrett: schleudert zurück
	t2.traps.append(_trap("feder", c))
	e = _sp("schleim_schleimling", Vector2(18, 0), 100.0)
	e.stun = 99.0
	T._check(await _until(func(): return int(t2.log.get("feder", 0)) > 0, 1.0) and e.kn.length() > 1.0, "Federbrett: schleudert zurück")
	tg._reset()
	t2.traps.clear()
	# Lockköder: lockt an
	t2.traps.append(_trap("koeder", c))
	e = _sp("schleim_schleimling", Vector2(18, 10), 100.0)
	T._check(await _until(func(): return e.bait_t > 0.0, 1.0), "Lockköder: lockt Gegner im Umkreis an")
	var d0: float = e.p.distance_to(c)
	await T._wait(1.5)
	T._check(e.p.distance_to(c) < d0 - 1.0, "Lockköder: Gegner laufen zum Köder")
	tg._reset()
	t2.traps.clear()
	# Elektrozaun: Blitzschaden, betäubt; Untote nehmen mehr (Blitz +50 %)
	t2.traps.append(_trap("zaun", c))
	e = _sp("untote_matrose", Vector2(18, 0), 100.0)
	e.root = 99.0
	var hp0: float = e.hp
	T._check(await _until(func(): return e.hp < hp0 and e.stun > 0.0, 1.0), "Elektrozaun: Blitz und Betäubung")
	tg._reset()
	t2.traps.clear()
	# Eisfalle: friert ein, Eiswesen nicht
	t2.traps.append(_trap("eisfalle", c))
	e = _sp("schleim_brocken", Vector2(18, 0.5), 100.0)
	e.root = 99.0
	var ice = _sp("eis_yeti", Vector2(18, -0.5), 100.0)
	ice.root = 99.0
	T._check(await _until(func(): return e.stun > 1.0, 1.0) and ice.stun <= 0.0, "Eisfalle: friert ein, Eiswesen bleiben unberührt")
	t2.traps.clear()
	# Tunnelgräber taucht in einer Falle auf
	t2.traps.append(_trap("teer", c))
	e = _sp("daemonen_hoellengraeber", Vector2(18, 0), 100.0)
	h.ai._tunnel_trap_check(e)
	T._check(e.stun > 2.0 and e.hp < e.mhp, "Tunnelgräber: taucht in der Falle auf und sitzt fest")
	t2.traps.clear()
	tg._reset()


# ---------------------------------------------------------------- Fernkämpfer: knien / aufblähen vor dem Schuss
func _aim_clips() -> void:
	tg._reset()
	var e = _sp("untote_kanonier", Vector2(12, 0), 500.0)
	var kneel: int = int(h._vis[e.t].vat.clips.kneel)
	T._check(await _until(func(): return e.ca == kneel, 6.0), "Kanonier: kniet vor dem Schuss (Clip kneel)")
	tg._reset()
	e = _sp("daemonen_feuerspeier", Vector2(10, 0), 500.0)
	var puff: int = int(h._vis[e.t].vat.clips.puff)
	T._check(await _until(func(): return e.ca == puff, 6.0), "Feuerspeier: bläht sich vor dem Schuss auf (Clip puff)")
	tg._reset()
	e = _sp("eis_yeti", Vector2(8, 0), 500.0)
	var thr: int = int(h._vis[e.t].vat.clips.throw)
	T._check(await _until(func(): return e.ca == thr, 6.0), "Yeti: wirft mit eigenem Clip (throw)")
	tg._reset()


# ---------------------------------------------------------------- Trümmer und Bau-Animation
func _buildings() -> void:
	var s = null
	for x in w.structures:
		if x.alive and "gate" in x and not x.gate and x.key != "bunker" and x.key != "wall" and x.size.x >= 2:
			s = x
			break
	if s == null:
		return
	s._destroy()
	T._check(s._rubble != null and s._rubble.visible and not (s._rubble is MeshInstance3D), "Trümmer-Modell nach der Zerstörung (%s)" % s.key)
	s.restore()
	T._check(not s._rubble.visible, "Trümmer verschwinden beim Wiederaufbau")
	var n0: int = s.get_child_count()
	BuildFx.play(s)
	T._check(s.get_child_count() > n0 + 3, "Bau-Animation: Bauteile fliegen ein")
	await T._wait(2.6)
	T._check(s.get_child_count() <= n0 + 1, "Bau-Animation: Teile sind wieder weg")


# ---------------------------------------------------------------- Bach an der Ost-Zufahrt
func _brook() -> void:
	var f = w.field
	var through := 0
	for y in [-9.0, -6.0, -4.0, 4.0, 6.0, 9.0]:
		var p := Vector2(BaseNature.BRIDGE.x, y)
		if BaseNature.in_brook(p, 1.0) and not f.is_solid(p):
			through += 1
	T._check(through == 0, "Bach: keine Furt neben der Brücke (%d offene Felder)" % through)
	T._check(not f.is_solid(BaseNature.BRIDGE), "Bach: die Brücke bleibt frei")
	# Wegfeld in Scheiben (Expedition): gleiches Ergebnis wie die volle Rechnung
	var Field = load("res://src/field.gd")
	var fa = Field.new(Vector2(-60, -60), 60, 60, 2.0)
	for i in 60 * 60:
		fa.solid[i] = 1 if (i % 60 == 30 and i / 60 != 50) else 0
	fa.set_goal(Vector2(-40, 0))
	fa.rebuild()
	var fb = Field.new(Vector2(-60, -60), 60, 60, 2.0)
	fb.solid = fa.solid.duplicate()
	fb.slice_us = 50
	fb.set_goal(Vector2(-40, 0))
	var steps := 0
	fb.update_if_dirty()
	while fb.rebuilds == 0 and steps < 10000:
		fb.update_if_dirty()
		steps += 1
	var same: bool = fb.dist == fa.dist and fb.dirs == fa.dirs
	T._check(same and steps > 1, "Wegfeld in Scheiben: gleiches Ergebnis wie am Stück (%d Scheiben)" % (steps + 1))
	# Ausweichen: angekündigter Einschlag
	h.ai.incoming.append([Vector2(5, 5), 2.0, 1.0])
	var dg: Vector2 = h.ai.dodge(Vector2(5.5, 5))
	var dg2: Vector2 = h.ai.dodge(Vector2(20, 20))
	h.ai.incoming.clear()
	T._check(dg.x > 0.0 and dg2 == Vector2.ZERO, "Ausweichen: weg vom angekündigten Einschlag")


# ---------------------------------------------------------------- Rechenzeit mit den neuen Rollen
func _perf() -> void:
	# in Echtzeit messen (Zeitraffer würde die Zeitgeber der Heiler je Schritt vervielfachen)
	var ts := Engine.time_scale
	Engine.time_scale = 1.0
	var ms: float = await tg._perf_run(["untote_seehexe", "untote_schildmatrose", "wald_druide"])
	var base: float = await tg._perf_run(["schleim_schleimling", "schleim_flitzer", "schleim_spucker"])
	Engine.time_scale = ts
	T._check(ms < 4.0 or ms < base * 1.8, "Logik mit neuen Rollen unter 4 ms bei 300 Gegnern (%.2f ms, Schleimlinge %.2f ms)" % [ms, base])


# ---------------------------------------------------------------- Bilder: --autotest=gegner2 --show=key1,key2,… [--show_elite=1] [--show_boss=<gebiet>] [--show_trap=key]
## Stellt Arten in einer Reihe vor dem Helden auf (stehen still), für Bildschirmfotos mit --shots/--at.
func show() -> void:
	Engine.time_scale = 1.0
	if G.arg("show") == "base":
		await show_base()
		return
	tg = Gegner.new(T)
	await tg._arena()
	w = tg.w
	h = tg.h
	hero = tg.hero
	A = tg.A
	var keys: Array = Array(G.arg("show").split(","))
	var gap := float(G.arg("show_gap", "3.6"))
	for i in keys.size():
		var k := String(keys[i])
		if not D.ENEMY_INDEX.has(k):
			continue
		var q := A + Vector2((i - 0.5 * (keys.size() - 1)) * gap, -float(G.arg("show_d", "6")))
		var e = h.spawn(int(D.ENEMY_INDEX[k]), q, 1000.0, 0.0, 0.0)
		e.stun = 1.0e6
		e.yaw = 0.0
		if G.arg("show_elite") != "":
			h.make_elite(e)
		print("SHOW %s at %s (Held %s) alive=%d" % [k, str(q), str(hero.pos2()), h.alive])
		if G.arg("show_clip") != "":
			h.loop_clip(e, G.arg("show_clip"))
	if G.arg("show_boss") != "":
		while T._t < float(G.arg("show_at", "5")):          # Auftritt zu einem festen Zeitpunkt (für --at)
			await T._wait(0.1)
		var b = h.spawn_boss(int(G.arg("show_boss")), A + Vector2(0, -9), 1.0, 0.0)
		b.stun = 1.0e6
		if G.arg("show_rage") != "":
			b.hp = b.mhp * 0.2
		if G.arg("show_slam") != "":
			b.stun = 0.0
			b.special = "slam"
			b.sp_t = 0.5
	if G.arg("show_mini") != "":
		var m = h.spawn_planned(2000 + D.family_mini(G.arg("show_mini")), A + Vector2(0, -7), 1000.0, 0.0)
		m.sp_t = 0.3
		hero.hp = hero.max_hp
	G.cam.snap()
	await T._wait(120.0)


## Bilder: alle neuen Fallen, Deko-Teile und Trophäen in der Basis (Bunker 10), dazu ein zerstörtes Gebäude (Trümmer).
func show_base() -> void:
	P.debug_setup(10)
	for k in D.BOSS_PHASES:
		P.count_up("boss_win_" + String(k), 1)
	P.add_many({"coins": 99999, "wood": 9999, "stone": 9999, "metal": 9999, "fuel": 999, "cells": 999})
	var keys: Array = []
	for k in D.BUILDINGS:
		var b: Dictionary = D.BUILDINGS[k]
		if D.TRAP.has(k) or b.has("deco") or b.has("trophy"):
			keys.append(k)
	var o := P.grid_origin()
	var n := P.grid_size()
	var placed := 0
	var cells: Array = []                           # freie Felder nach Abstand zur Bildmitte (vor dem Bunker)
	var cx := D.GRID_MAX * 0.5 + float(G.arg("cx", "0"))
	var cy := D.GRID_MAX * 0.5 + float(G.arg("cy", "8"))
	for y in range(o + 1, o + n - 2):
		for x in range(o + 1, o + n - 2):
			cells.append(Vector2i(x, y))
	cells.sort_custom(func(a, b): return Vector2(a).distance_squared_to(Vector2(cx, cy)) < Vector2(b).distance_squared_to(Vector2(cx, cy)))
	for k in keys:
		var sz: Array = D.BUILDINGS[k].size
		var why := P.can_build(k)
		if why != "":
			print("SHOW base: %s nicht baubar: %s" % [k, why])
			continue
		for c in cells:
			if P.cells_free(c.x - 1, c.y - 1, int(sz[0]) + 2, int(sz[1]) + 2):
				if not P.place(k, c.x, c.y).is_empty():
					placed += 1
					P.speed_up_builds(1.0e9)          # Baudrohne gleich wieder frei
				break
	P.speed_up_builds(1.0e9)
	print("SHOW base: %d von %d gesetzt, Deko-Punkte %d" % [placed, keys.size(), P.deco_points()])
	G.main.goto_base()
	await T._wait(1.0)
	var w2 = G.main.world
	if G.arg("goto") != "":
		var gp := G.arg("goto").split(":")
		w2.hero.global_position = Vector3(float(gp[0]), 0, float(gp[1]))
	for s2 in w2.structures:
		if "key" in s2 and s2.key == "werkstatt":
			s2._destroy()
	await T._wait(120.0)
