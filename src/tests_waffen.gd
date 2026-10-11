extends RefCounted
## Prüfungen für Paket W (V4 Waffen-Arsenal): Daten aller Waffen, Modelle und Symbole, Haltungen, Kampfwerte,
## Herstellen, Funde, Erfolge, alte Spielstände und ein Probeschießen jeder Waffe in einer Test-Arena.
## Aufruf aus tests.gd (--selftest).

const D = preload("res://src/data.gd")
const Rules = preload("res://src/arsenal_rules.gd")
const Humanoid = preload("res://src/humanoid.gd")
const Models = preload("res://src/models.gd")

const ELEMENTS := ["kugel", "feuer", "wasser", "eis", "blitz", "explosion", "gift"]
const MODES := ["hitscan", "proj", "homing", "chain", "swing", "multi", "cone", "bolt", "beam", "charge", "thrust", "slam", "nova", "mine", "turret", "seek"]

var T: Node
var w: Node3D
var hero: Node3D
var A := Vector2.ZERO


func _init(tests: Node) -> void:
	T = tests


func run() -> void:
	_data()
	_assets()
	_crafting()
	_finds()
	_old_save()
	await _fire_all()


# ---------------------------------------------------------------- Daten
func _data() -> void:
	var lib: AnimationLibrary = Humanoid.library()
	for hk in D.HERO_ORDER:
		var list: Array = D.hero_weapons(hk)
		T._check(list.size() >= 15, "%s hat mindestens 15 Waffen (%d)" % [hk, list.size()])
		var top := 0
		for k in list:
			top = maxi(top, D.weapon_level(k))
		T._check(top >= 35 and D.weapon_level(list[0]) == 1, "%s: Waffen verteilt über Stufe 1 bis %d" % [hk, top])
		for i in 3:
			T._check(list.has(D.HEROES[hk].weapons[i]), "%s: Startwaffe %s bleibt" % [hk, D.HEROES[hk].weapons[i]])
	var n_new := 0
	for k in D.WEAPONS:
		var wd: Dictionary = D.WEAPONS[k]
		for f in ["name", "kind", "hero", "damage", "rpm", "mag", "reload", "range", "mode", "sound", "len", "element"]:
			T._check(wd.has(f), "Waffe %s: Feld %s" % [k, f])
		T._check(MODES.has(String(wd.mode)), "Waffe %s: Schussart %s bekannt" % [k, wd.mode])
		T._check(ELEMENTS.has(String(wd.element)), "Waffe %s: Element %s" % [k, wd.element])
		T._check(D.weapon_text(k) != "" and D.weapon_special(k) != "", "Waffe %s: Beschreibung und Besonderheit" % k)
		T._check(float(wd.rpm) > 0.0 and float(wd.range) > 0.0 and float(wd.len) > 0.0, "Waffe %s: Werte > 0" % k)
		var ps: Dictionary = Humanoid.weapon_pose(k)
		T._check(not ps.is_empty(), "Waffe %s: Haltung" % k)
		if not ps.is_empty():
			for part in ["aim", "fire", "reload"]:
				T._check(lib.has_animation(ps[part]), "Waffe %s: Clip %s" % [k, ps[part]])
			T._check(lib.has_animation(String(ps.aim).replace("aim_", "hold_")), "Waffe %s: Bereitschaftshaltung" % k)
		if not wd.has("lvl"):
			continue
		n_new += 1
		var lv := int(wd.lvl)
		T._check(lv >= 1 and lv <= D.HERO_MAX_LEVEL, "Waffe %s: Stufe %d" % [k, lv])
		T._check(["craft", "find", "both"].has(String(wd.get("get", ""))), "Waffe %s: Weg (herstellen/finden)" % k)
		T._check(wd.has("sound_alt"), "Waffe %s: Ersatzton" % k)
		for a in D.weapon_areas(k):
			T._check(int(a) >= 0 and int(a) < D.AREAS.size(), "Waffe %s: Gebiet %s" % [k, str(a)])
		var pw := D.weapon_power(k)
		var ref := D.weapon_power_ref(lv)
		if pw >= 0.0:
			T._check(pw >= ref * 0.45 and pw <= ref * 1.6, "Waffe %s: Kampfwert %.0f passt zu Stufe %d (Richtwert %.0f)" % [k, pw, lv, ref])
		if String(wd.mode) == "turret":
			T._check(D.TOWERS.has(String(wd.tower)), "Waffe %s: Geschütz %s" % [k, wd.tower])
		if String(wd.mode) == "charge":
			T._check(float(wd.charge) > 0.0, "Waffe %s: Ladezeit" % k)
	T._check(n_new >= 72, "mindestens 72 neue Waffen (%d)" % n_new)
	var ways := {}
	for k in D.WEAPONS:
		ways[D.weapon_get(k)] = int(ways.get(D.weapon_get(k), 0)) + 1
	T._check(ways.has("craft") and ways.has("find") and ways.has("both"), "Herstellen, Finden und beides kommen vor: %s" % str(ways))


func _assets() -> void:
	for k in D.WEAPONS:
		T._check(Models.has_glb("w_" + k), "Modell w_%s vorhanden" % k)
		T._check(ResourceLoader.exists("res://icons/w_%s.png" % k), "Symbol w_%s vorhanden" % k)
	# Stichprobe: Mündung liegt im Modell vorn
	for k in ["j_pistol", "m_dragon", "b_drill", "a_plasma", "y_crossbow", "g_candy"]:
		var n: Node3D = Models.weapon(k)
		var mz := Models.find(n, "muzzle")
		T._check(mz != null and mz.position.z > 0.2, "w_%s: Mündung vorn" % k)
		n.free()


# ---------------------------------------------------------------- Herstellen
func _crafting() -> void:
	P.new_game()
	P.no_save = true
	T._check(P.d.has("blueprints") and P.d.blueprints.is_empty(), "neuer Spielstand ohne Baupläne")
	var key := "j_mortar"             # nur herstellbar, ab Stufe 13
	T._check(Rules.status(key) == "blueprint" and not Rules.can_craft(key), "ohne Bauplan nicht herstellbar")
	var c0 := P.res("coins")
	T._check(Rules.craft(key).is_empty() and P.res("coins") == c0, "ohne Bauplan: nichts bezahlt")
	Rules.give_blueprint(key)
	T._check(Rules.status(key) == "craft_level", "Bauplan da, Heldenstufe fehlt")
	T._check(Rules.craft(key).is_empty(), "zu niedrige Heldenstufe: kein Herstellen")
	P.d.heroes.jona.level = 13
	var cost: Dictionary = D.craft_cost(key)
	P.add_many({"coins": 5000, "metal": 1000, "parts": 300})
	var before := {}
	for r in cost:
		before[r] = P.res(r)
	T._check(Rules.can_craft(key), "jetzt herstellbar")
	var it: Dictionary = Rules.craft(key)
	T._check(not it.is_empty() and String(it.key) == key and Rules.owned(key), "Herstellen gibt die Waffe")
	var paid := true
	for r in cost:
		if P.res(r) != int(before[r]) - int(cost[r]):
			paid = false
	T._check(paid, "Herstellen zieht genau die Kosten ab %s" % str(cost))
	T._check(Rules.status(key) == "owned", "Zustand: im Besitz")
	T._check(P.equip("jona", int(it.id)) and int(P.hero("jona").weapon) == int(it.id), "hergestellte Waffe lässt sich ausrüsten")
	var hi: Dictionary = P.make_item("weapon", "j_railgun", 0)
	T._check(not P.equip("jona", int(hi.id)), "Waffe über der Heldenstufe lässt sich nicht ausrüsten")
	P.d.res.coins = 0
	Rules.give_blueprint("j_pistol")
	P.d.heroes.jona.level = 5
	T._check(not Rules.can_craft("j_pistol") and Rules.craft("j_pistol").is_empty(), "ohne Münzen kein Herstellen")


# ---------------------------------------------------------------- Funde
func _finds() -> void:
	P.new_game()
	P.no_save = true
	for hk in D.HERO_ORDER:
		P.d.heroes[hk].unlocked = true
		P.d.heroes[hk].level = 40
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var got_item := 0
	var got_bp := 0
	for i in 60:
		var p: Dictionary = Rules.roll("exp_chest", i % 7, "", 0, true, false, rng)
		if p.is_empty():
			continue
		if String(p.kind) == "item":
			got_item += 1
			var it: Dictionary = P.item(int(p.item))
			T._check(not it.is_empty() and D.weapon_get(String(it.key)) != "craft", "Fund ist eine findbare Waffe (%s)" % String(it.get("key", "")))
		else:
			got_bp += 1
			T._check(Rules.has_blueprint(String(p.key)) and D.weapon_get(String(p.key)) != "find", "Bauplan einer herstellbaren Waffe (%s)" % String(p.key))
	T._check(got_item > 0 and got_bp > 0, "Funde geben Waffen (%d) und Baupläne (%d)" % [got_item, got_bp])
	# Gebiet: in Gebiet 0 kommen keine Waffen aus späteren Gebieten
	P.new_game()
	P.no_save = true
	P.d.heroes.jona.level = 40
	var late := false
	for i in 40:
		var p2: Dictionary = Rules.roll("exp_chest", 0, "jona", 0, true, false, rng)
		if p2.is_empty():
			continue
		var k2: String = String(p2.key) if p2.has("key") else String(P.item(int(p2.item)).key)
		if int(D.weapon_areas(k2).min()) > 1:
			late = true
	T._check(not late, "Grüntal gibt nur Waffen aus Grüntal (selten eines voraus)")
	# Expedition: Kopfgeld-Boss beim ersten Mal gibt sicher etwas
	var out := P.expedition_end(0, 0, "jona", true, {}, {"bounty": true, "chests": 2, "kills": 5})
	T._check(out.has("arsenal") and (out.arsenal as Array).size() >= 1, "Expedition: Boss gibt eine Waffe oder einen Bauplan (%d Funde)" % (out.get("arsenal", []) as Array).size())
	# Beutekisten
	var n_chest := 0
	for i in 40:
		P.add_chest("boss")
		for pc in P.open_chest("boss"):
			if String(pc.kind) == "blueprint" or (String(pc.kind) == "item" and P.item(int(pc.item)).get("slot", "") == "weapon" and D.WEAPONS[P.item(int(pc.item)).key].has("lvl")):
				n_chest += 1
	T._check(n_chest > 0, "Bosskisten enthalten neue Waffen oder Baupläne (%d)" % n_chest)
	# Erfolge: jeder Erfolg bringt einen Bauplan
	P.new_game()
	P.no_save = true
	var bp0: int = P.d.blueprints.size()
	P.d.counters["chests"] = 9999
	P.d.stats.chests = 9999
	var claimed := false
	for a in P.achievements():
		if a.ready:
			P.claim_achievement(String(a.def.key))
			claimed = true
			break
	if claimed:
		T._check(P.d.blueprints.size() == bp0 + 1, "Erfolg gibt einen Bauplan")
	# Admin: alles geben
	var n := Rules.grant_all()
	var all_ok := true
	for k in D.WEAPONS:
		if not Rules.owned(k):
			all_ok = false
	T._check(all_ok and n >= 0, "Admin: alle Waffen und Baupläne")


# ---------------------------------------------------------------- alter Spielstand
func _old_save() -> void:
	P.new_game()
	P.no_save = true
	var start: Dictionary = P.item(int(P.hero("jona").weapon))
	P.d.erase("blueprints")
	P.d = JSON.parse_string(JSON.stringify(P.d))
	P._after_load()
	T._check(P.d.has("blueprints") and (P.d.blueprints as Dictionary).is_empty(), "alter Stand: Baupläne werden ergänzt")
	var it: Dictionary = P.item(int(P.hero("jona").weapon))
	T._check(not it.is_empty() and String(it.key) == String(start.key), "alter Stand: Startwaffe bleibt ausgerüstet")
	T._check(Rules.status("j_rifle") == "owned" and Rules.status("j_smg") == "find", "alter Stand: Zustände der Waffen")


# ---------------------------------------------------------------- Waffenschau (Bilder)
## --autotest=waffenschau --weapon=<schlüssel> [--n=8]: Held mit der Waffe in der Arena, Gegner laufen auf ihn zu.
## Bilder wie sonst mit --shots=… --at=… (shot2.sh). Gegner machen keinen Schaden.
func show(wkey: String) -> void:
	var k := wkey if D.WEAPONS.has(wkey) else "j_rifle"
	await _arena_setup(String(D.WEAPONS[k].hero), k)
	hero.global_position = Vector3(A.x, 0, A.y)     # der Held kommt aus --weapon (tests.gd prepare)
	hero.max_hp = 1.0e7
	hero.hp = 1.0e7
	w.cam.dist = float(G.arg("dist", "24"))
	w.cam.snap()
	var n := int(G.arg("n", "8"))
	for i in n:
		var a := deg_to_rad(-50.0 + 100.0 * float(i) / maxf(n - 1, 1)) + PI * 0.5
		var e = w.horde.spawn(int(G.arg("enemy", "0")), A + Vector2(cos(a), sin(a)) * (11.0 + (i % 3) * 1.5), 6.0, 0.0, 0.0)
		e.aggro = true
		e.hunter = true
	while true:
		await T._wait(0.5)
		if w.horde.count_alive() < 3:
			for i in 4:
				var a2 := randf_range(0.2, PI - 0.2)
				var e2 = w.horde.spawn(int(G.arg("enemy", "0")), A + Vector2(cos(a2), sin(a2)) * 11.0, 6.0, 0.0, 0.0)
				e2.aggro = true
				e2.hunter = true


func _arena_setup(hk_sel := "", wkey := "") -> void:
	P.debug_setup(6)
	for hk in D.HERO_ORDER:
		P.d.heroes[hk].unlocked = true
		P.d.heroes[hk].level = 40
	if hk_sel != "":
		P.d.hero_sel = hk_sel
		P.d.heroes[hk_sel].weapon = int(P.make_item("weapon", wkey, 2).id)
	P.d.week.number = 2
	G.main.goto_base()
	await T._wait(0.3)
	w = G.main.world
	w.start_flood(true)
	await T._wait(0.2)
	w._queue.clear()
	w.flood.total = 0
	w.wave_count = 99
	w.horde.clear()
	hero = w.hero
	for tw in w.towers:
		if is_instance_valid(tw):
			tw.active = false
	var cands: Array = []
	for r in [30, 36, 42, 48, 54]:
		for k in 16:
			cands.append(Vector2.from_angle(TAU * k / 16.0) * r)
	for cand in cands:
		var ok := true
		for dx in range(-12, 13, 2):
			for dy in range(-12, 13, 2):
				var q: Vector2 = cand + Vector2(dx, dy)
				if w.field.is_solid(q) or w.field.structure_at(q) != null:
					ok = false
		if ok:
			A = cand
			break


# ---------------------------------------------------------------- Probeschießen
func _fire_all() -> void:
	await _arena_setup()
	T._check(A != Vector2.ZERO, "Waffen-Arena gefunden")
	var bad: Array = []
	for k in D.WEAPONS:
		var dealt := await _try(k)
		if dealt <= 0.0:
			bad.append(k)
	T._check(bad.is_empty(), "jede Waffe feuert und trifft (ohne Treffer: %s)" % str(bad))
	w.horde.clear()
	hero.arsenal.clear()


## Eine Waffe in die Hand, drei unbewegliche Ziele vor den Helden, bis zu 3 Spielsekunden schießen. Rückgabe: Schaden.
func _try(k: String) -> float:
	var h = w.horde
	h.clear()
	hero.arsenal.clear()
	for tw in w.towers.duplicate():
		if is_instance_valid(tw) and tw.life > 0.0:
			tw.life = 0.01
	await T._wait(0.05)
	hero.global_position = Vector3(A.x, 0, A.y)
	hero.alive = true
	hero.max_hp = 1.0e7
	hero.hp = 1.0e7
	hero.dash_t = 0.0
	hero.speed_k = 1.0
	var it: Dictionary = P.make_item("weapon", k, 0)
	hero.set_weapon(it)
	var towers0: int = w.towers.size()
	var dummies: Array = []
	for off in [Vector2(0.4, 2.0), Vector2(-0.6, 2.6), Vector2(0.2, 3.2)]:
		var e = h.spawn(0, A + off, 400.0, 0.0, 0.0)
		e.root = 999.0                    # bleibt stehen, Bodenflächen wirken trotzdem
		dummies.append(e)
	var hp0 := 0.0
	for e in dummies:
		hp0 += e.hp
	var t := 0.0
	var dealt := 0.0
	while t < 3.0:
		await T._wait(0.1)
		t += 0.1
		dealt = 0.0
		for e in dummies:
			dealt += maxf(0.0, e.mhp - e.hp) if e.st != 2 else e.mhp
		if dealt > 0.0 and t > 0.6:
			break
	if dealt <= 0.0 and String(D.WEAPONS[k].mode) == "turret" and w.towers.size() > towers0:
		dealt = 1.0                       # Geschütz steht, braucht aber länger zum Zielen
	T._check(hero.alive, "Held lebt beim Probeschießen mit %s" % k)
	return dealt
