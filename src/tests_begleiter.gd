extends RefCounted
## Prüfungen für Paket B (Begleiter): Daten und Modelle, alter Spielstand, Kaufen/Herstellen/Finden, Tragkraft und
## Besonderheiten, Folgen ohne Feststecken (Basis mit Mauern/Toren und Expedition), Ladung sichtbar (Begleiter und
## Kraxe), Umfallen und Aufstehen, Rechenzeit, Bildschirm und Laden, Admin-Knopf.
## Aufruf aus tests.gd (--selftest).

const D = preload("res://src/data.gd")
const CD = preload("res://src/companion_data.gd")
const Models = preload("res://src/models.gd")
const UI = preload("res://src/ui.gd")

var T: Node                      # tests.gd (für _check und _wait)


func _init(tests: Node) -> void:
	T = tests


func run() -> void:
	_data()
	_rules()
	_old_save()
	await _base()
	await _expedition()
	await _find()
	await _screens()


func _fresh() -> void:
	P.new_game()
	P.no_save = true
	P.d.level = 60
	P._ensure_fields()


# ---------------------------------------------------------------- Daten und Modelle
func _data() -> void:
	T._check(CD.ORDER.size() >= 10 and CD.ORDER.size() == CD.COMPANIONS.size(), "mindestens 10 Begleiter (%d)" % CD.ORDER.size())
	var ways := {}
	var finds := {}
	for k in CD.ORDER:
		var d: Dictionary = CD.COMPANIONS[k]
		T._check(String(d.name) != "" and String(d.text) != "" and float(d.carry) > 0.0 and float(d.speed) > 0.0 and float(d.hp) > 0.0, "Werte: %s" % k)
		var ab: Dictionary = d.abil
		T._check(ab.size() >= 1 and ab.size() <= 2, "1–2 Besonderheiten: %s" % k)
		for a in ab:
			T._check(CD.ABIL.has(a), "Besonderheit bekannt: %s.%s" % [k, a])
		var g: Dictionary = d["get"]
		T._check(g.has("craft") or g.has("buy") or g.has("find") or g.has("start"), "%s ist zu bekommen" % k)
		for w in g:
			ways[w] = true
		if g.has("find"):
			finds[int(g.find)] = true
		T._check(CD.how_lines(k).size() >= 1 and CD.abil_lines(k).size() == ab.size(), "Texte: %s" % k)
		T._check(Models.has_glb("comp_" + k), "Modell comp_%s.glb" % k)
		T._check(UI.has_pic("comp_" + k), "Symbol comp_%s.png" % k)
		if Models.has_glb("comp_" + k):
			var m := Models.glb("comp_" + k)
			T._check(Models.find(m, "body") != null and Models.find(m, "cargo") != null, "comp_%s hat body und cargo" % k)
			var moving := 0
			for nm in ["head", "tail", "leg_fl", "leg_l", "wing_l", "spin_rotor_1", "arm_l"]:
				if Models.find(m, nm) != null:
					moving += 1
			T._check(moving >= 1, "comp_%s hat bewegliche Teile (%d)" % [k, moving])
			m.free()
	T._check(ways.has("craft") and ways.has("buy") and ways.has("find"), "kaufen, herstellen und finden kommen vor")
	T._check(finds.size() >= 5, "Begleiter in %d Gebieten zu finden" % finds.size())
	T._check(CD.COMPANIONS[CD.START]["get"].has("start"), "erster Begleiter ist ein Geschenk")
	for r in CD.CARGO:
		T._check(Models.has_glb(String(CD.CARGO[r])), "Ladungs-Modell %s" % CD.CARGO[r])
	T._check(Models.has_glb("cg_kraxe"), "Kraxe des Helden")


# ---------------------------------------------------------------- Regeln
func _rules() -> void:
	_fresh()
	T._check(CD.owned(CD.START) and CD.active() == CD.START, "neues Spiel: erster Begleiter ist dabei")
	# Kaufen mit Münzen
	P.d.res.coins = 100
	T._check(CD.can_buy("schnecke") != "" and CD.buy("schnecke") != "", "zu wenig Münzen: kein Kauf")
	P.d.res.coins = 5000
	T._check(CD.buy("schnecke") == "" and CD.owned("schnecke") and P.res("coins") == 2500, "Lastschnecke für 2500 Münzen gekauft")
	T._check(CD.buy("schnecke") != "", "nicht doppelt kaufen")
	# Kaufen mit Juwelen
	P.d.res.gems = 10
	T._check(CD.buy("husky") != "" and not CD.owned("husky"), "zu wenig Juwelen")
	P.d.res.gems = 500
	T._check(CD.buy("husky") == "" and CD.owned("husky") and P.gems() == 100, "Husky für 400 Juwelen")
	# Herstellen
	P.d.res.metal = 0
	T._check(CD.craft("esel") != "" and not CD.owned("esel"), "ohne Metall kein Blechesel")
	P.add_many({"metal": 400, "parts": 100, "fuel": 100})
	var m0 := P.res("metal")
	T._check(CD.craft("esel") == "" and CD.owned("esel") and P.res("metal") == m0 - 200, "Blechesel hergestellt")
	T._check(CD.craft("eule") != "", "Eule nur zu finden")
	# Aktiv wählen
	T._check(CD.set_active("esel") and CD.active() == "esel", "Blechesel mitnehmen")
	T._check(not CD.set_active("golem") and CD.active() == "esel", "fremden Begleiter nicht wählbar")
	# Tragkraft, Stufen, Besonderheiten
	var c1 := CD.carry("esel")
	T._check(absf(c1 - 90.0) < 0.01, "Tragkraft Stufe 1 = 90")
	var lv := CD.add_xp(float(CD.XP_NEED[4]) + 1.0, "esel")
	T._check(lv == 5 and CD.level("esel") == 5 and absf(CD.carry("esel") - 90.0 * (1.0 + 4 * CD.CARRY_PER_LEVEL)) < 0.01, "Stufe 5 trägt mehr (%.0f)" % CD.carry("esel"))
	CD.add_xp(1.0e6, "esel")
	T._check(CD.level("esel") == CD.MAX_LEVEL, "höchstens Stufe %d" % CD.MAX_LEVEL)
	T._check(absf(CD.weight_k("metal") - 0.7) < 0.001 and CD.weight_k("wood") == 1.0, "Starker Rücken: Metall wiegt 30 % weniger")
	CD.set_active("schnecke")
	T._check(absf(CD.death_keep() - 0.85) < 0.001, "Lastschnecke schützt 85 % der Ladung")
	CD.set_active("")
	T._check(CD.death_keep() == 0.5 and CD.weight_k("metal") == 1.0 and CD.active_carry() == 0.0, "ohne Begleiter: wie bisher")
	CD.give("ziege", "admin")
	T._check(absf(CD.carry("ziege", "frost") - CD.carry("ziege") * 1.5) < 0.01, "Bergziege trägt im Frostpass mehr")
	T._check(CD.findable(0) == ["eule"] and CD.findable(5).is_empty(), "zu finden: Eule im Grüntal, Ziege schon da")
	# Ladung: Stückzahl
	var counts := CD.cargo_counts({"wood": 100.0, "stone": 20.0, "cells": 5.0}, 134.0, 220.0, 8, func(r): return float(D.RES_WEIGHT.get(r, 1.0)))
	var tot := 0
	for r in counts:
		tot += int(counts[r])
	T._check(counts.has("wood") and counts.has("stone") and counts.has("cells") and tot <= 8 and int(counts.wood) >= int(counts.stone), "Ladungsteile nach Anteil: %s" % str(counts))
	T._check(CD.cargo_counts({}, 0.0, 220.0, 8, func(r): return 1.0).is_empty(), "leerer Rucksack: nichts zu tragen")


## Ein Stand ohne Begleiter-Feld (vor Paket B) lädt und bekommt den ersten Begleiter.
func _old_save() -> void:
	_fresh()
	P.d.erase("companions")
	P.d = JSON.parse_string(JSON.stringify(P.d))
	P._after_load()
	T._check(CD.owned(CD.START) and CD.active() == CD.START, "alter Stand: erster Begleiter geschenkt")
	# kaputte Einträge werden aufgeräumt, Stufen bleiben Zahlen
	P.d.companions.own["gibtsnicht"] = {"lv": 3, "xp": 1}
	P.d.companions.own[CD.START] = {"lv": 4.0, "xp": "12"}
	P.d.companions.active = "gibtsnicht"
	P.d = JSON.parse_string(JSON.stringify(P.d))
	P._after_load()
	T._check(not CD.owned("gibtsnicht") and CD.level(CD.START) == 4 and CD.active() == "", "alter Stand: unbekannte Begleiter entfernt")
	# wer schon einmal einen hatte und ihn abgewählt hat, bekommt nicht noch einen geschenkt
	P.d.companions.own.clear()
	P._ensure_fields()
	T._check(CD.owned_count() == 0, "Geschenk nur einmal")


# ---------------------------------------------------------------- Hauptbasis: Folgen durch Tore, nie durch Mauern
func _base() -> void:
	_fresh()
	P.debug_setup(6)
	P.no_save = true
	CD.give("golem", "admin")
	CD.set_active("golem")
	G.main.goto_base()
	await T._wait(0.6)
	var w = G.main.world
	var c = w.companion
	T._check(c != null and c.key == "golem" and c.model != null and c.visible, "Begleiter in der Basis")
	if c == null:
		return
	T._check(c.pos.distance_to(w.hero.pos2()) < 5.0, "steht beim Helden")
	# einmal rund um den Bunker und durch das Tor hinaus (Held läuft selbst, der Begleiter folgt)
	var h = w.hero
	var b0: int = c.blocked_frames
	var us_sum := 0.0
	var us_n := 0
	var max_d := 0.0
	for dir in [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(0, 1)]:
		h.test_wish = dir
		for i in 40:
			await T.get_tree().physics_frame
			us_sum += c.last_us
			us_n += 1
			max_d = maxf(max_d, c.pos.distance_to(h.pos2()))
	h.test_wish = Vector2.ZERO
	await T._wait(1.5)
	T._check(c.blocked_frames == b0, "Begleiter nie in Mauern oder Gebäuden (%d Bilder)" % (c.blocked_frames - b0))
	T._check(c.pos.distance_to(h.pos2()) < 4.5, "Begleiter hat aufgeholt (%.1f m, höchstens %.1f m)" % [c.pos.distance_to(h.pos2()), max_d])
	T._check(not w.field.blocks_player(c.pos), "steht frei")
	var avg := us_sum / maxf(us_n, 1.0)
	T._check(avg < 200.0, "Rechenzeit Begleiter %.0f µs je Bild (Ziel < 200)" % avg)
	print("BEGLEITER Rechenzeit %.0f µs je Bild, max. Abstand %.1f m, Sprünge %d" % [avg, max_d, c.teleports])
	# weit weg: springt zum Helden
	var tp0: int = c.teleports
	h.global_position = Vector3(h.global_position.x + 30.0, 0, h.global_position.z)
	await T._wait(0.5)
	if w.field.blocks_player(h.pos2()):
		h.global_position = Vector3(w.respawn_point().x, 0, w.respawn_point().y)
		await T._wait(0.5)
	T._check(c.teleports > tp0 and c.pos.distance_to(h.pos2()) < 6.0, "zu weit weg: Begleiter springt zum Helden")
	# Wechsel ohne neue Welt
	CD.set_active("kistenbein")
	await T._wait(0.7)
	T._check(c.key == "kistenbein" and c.model != null, "Wechsel des Begleiters in der Basis")
	CD.set_active("")
	await T._wait(0.7)
	T._check(c.key == "" and not c.visible, "ohne Begleiter: keiner zu sehen")
	CD.set_active("golem")
	await T._wait(0.7)
	# Kampf in der Flut: der Golem schlägt zu, kann umfallen und steht wieder auf
	w.start_flood(true)
	await T._wait(0.3)
	T._check(w.is_running(), "Übungsflut läuft (für den Kampftest)")
	if w.is_running():
		var e = w.horde.spawn(0, c.pos + Vector2(1.5, 0))
		var hp0: float = e.hp
		await T._wait(1.6)
		T._check(e.hp < hp0 or e.st >= 2, "Mini-Golem schlägt nahe Gegner")
	c.hurt(1.0e6)
	T._check(c.is_down(), "Begleiter fällt um")
	c.down_t = 0.2
	await T._wait(0.5)
	T._check(not c.is_down() and c.hp > 0.0, "Begleiter steht wieder auf")
	T._check(CD.owned("golem"), "umgefallen, aber nicht verloren")


# ---------------------------------------------------------------- Expedition: Tragkraft, Ladung, Kraxe
func _expedition() -> void:
	_fresh()
	P.d.vehicle_sel = ""
	CD.give("esel", "admin")
	CD.set_active("esel")
	G.autotest = ""
	G.main.start_expedition(0, "expedition", 0)
	await T._wait(0.6)
	var e = G.main.world
	var base: float = P.backpack_cap(e.hero.key, "")
	T._check(absf(e.cap - (base + CD.carry("esel", "gruental"))) < 0.5, "Tragkraft mit Blechesel %.0f (ohne %.0f)" % [e.cap, base])
	var c = e.companion
	T._check(c != null and c.key == "esel", "Blechesel in der Expedition")
	e.add_pack("wood", 60.0)
	e.add_pack("metal", 30.0)
	e.add_pack("cells", 5.0)
	await T._wait(0.6)
	var kinds: Dictionary = c.cargo_kinds()
	T._check(c.cargo_pieces >= 3, "Ladung auf dem Begleiter sichtbar (%d Teile)" % c.cargo_pieces)
	T._check(e.pack != null and not e.pack._stack.visible, "mit Begleiter: Kraxe leer und unsichtbar")
	T._check(e.pack.load_point().distance_to(c.load_point()) < 0.01, "Brocken fliegen zum Begleiter")
	# Starker Rücken: Metall wiegt weniger
	T._check(absf(e.unit_weight("metal") - D.RES_WEIGHT.metal * 0.7) < 0.001, "Metall wiegt beim Blechesel weniger")
	# Abwerfen geht weiter, Ladung schrumpft
	var n0: int = c.cargo_pieces
	e.pack.drop_all()
	await T._wait(0.5)
	T._check(c.cargo_pieces == 0 and e.pack.piles.size() >= 1 and n0 > 0, "Abwerfen: Haufen liegt, Begleiter leer")
	# ohne Begleiter: Kraxe mit Teil-Modellen, höchstens etwa eine Kopflänge über dem Kopf
	CD.set_active("")
	await T._wait(0.7)
	T._check(absf(e.cap - base) < 0.5, "ohne Begleiter: Tragkraft wie bisher")
	e.add_pack("wood", 80.0)
	e.add_pack("stone", 20.0)
	await T._wait(0.4)
	T._check(e.pack._stack.visible and e.pack._load.get_child_count() >= 2, "Kraxe trägt Teil-Modelle (%d)" % e.pack._load.get_child_count())
	var top := 0.0
	for gi in e.pack._load.find_children("*", "MeshInstance3D", true, false):
		var ab: AABB = (gi as MeshInstance3D).get_aabb()
		top = maxf(top, ((gi as MeshInstance3D).global_transform * ab.end).y)
	var head_top: float = e.hero.global_position.y + 1.6 * D.CHAR_SCALE
	var kl: Vector3 = e.hero.global_transform.affine_inverse() * e.pack._kraxe.global_position
	print("BEGLEITER Kraxe: Oberkante %.2f m, Lage am Helden %s" % [top, str(kl)])
	T._check(top > 0.5 and top < head_top + 0.75, "Kraxe nicht zu hoch (%.2f m, Kopf etwa %.2f m)" % [top, head_top])
	# Sturz: Sichere Ladung (Lastschnecke)
	CD.give("schnecke", "admin")
	CD.set_active("schnecke")
	await T._wait(0.6)
	e.loot = {"wood": 100.0}
	e._recalc_weight()
	e._on_hero_died()
	e.hero._respawn = 0.0
	T._check(absf(float(e.loot.wood) - 85.0) < 0.01, "Lastschnecke: 85 von 100 Holz bleiben")
	await T._wait(0.6)
	# Käfer baut selbst ab
	CD.give("kaefer", "admin")
	CD.set_active("kaefer")
	await T._wait(0.7)
	c = e.companion
	var node = null
	for n in e.nodes:
		if n.ring == 0 and not n.gone and n.res in ["wood", "stone"]:
			node = n
			break
	if node != null:
		var stand: Vector2 = e._stand(node, node.p + Vector2(3, 0)) + Vector2(1.5, 0)
		e.hero.global_position = Vector3(stand.x, 0, stand.y)
		e.hero.test_wish = Vector2.ZERO
		await T._wait(0.4)
		e.mining = null
		c.pos = stand + Vector2(-0.5, 1.0)
		var w0: float = c.mined
		await T._wait(4.5)
		T._check(c.mined > w0, "Kistenkäfer baut selbst ab (%.1f)" % (c.mined - w0))
		e.hero.test_wish = null
	# Drohne sammelt Münzen
	CD.give("drohne", "admin")
	CD.set_active("drohne")
	await T._wait(0.7)
	c = e.companion
	var cp: Vector2 = c.pos + Vector2(3.0, 3.0)
	e.coins.drop(cp, 12)
	await T._wait(1.6)
	T._check(c.coins_got > 0.0 or float(e.loot.get("coins", 0.0)) > 0.0, "Flugdrohne sammelt Münzen")
	# Folgen in der Expedition (Held läuft weg)
	e.hero.test_wish = Vector2(1, 0.3).normalized()
	var b0: int = c.blocked_frames
	await T._wait(2.5)
	e.hero.test_wish = Vector2.ZERO
	await T._wait(1.5)
	T._check(c.pos.distance_to(e.hero.pos2()) < 5.0, "Begleiter folgt in der Expedition")
	CD.set_active("kistenbein")
	await T._wait(0.7)
	c = e.companion
	e.hero.test_wish = Vector2(-1, 0.2).normalized()
	b0 = c.blocked_frames
	await T._wait(3.0)
	e.hero.test_wish = null
	await T._wait(1.0)
	T._check(c.blocked_frames == b0, "Laufender Begleiter nie auf gesperrtem Feld (Expedition)")


# ---------------------------------------------------------------- Finden
func _find() -> void:
	_fresh()
	P.d.vehicle_sel = ""
	G.main.start_expedition(0, "expedition", 0)
	await T._wait(0.5)
	var e = G.main.world
	var pet = null
	for q in e.pois:
		if q.kind == "pet":
			pet = q
	T._check(pet != null and pet.who == "eule", "Grüntal: gefangene Eule als Fund-Ort")
	if pet == null:
		return
	T._check(pet.status_text().contains("Eule"), "Aufgabenliste nennt den Begleiter")
	e.phase = "explore"
	e.hero.global_position = Vector3(pet.p.x + 1.0, 0, pet.p.y)
	await T._wait(3.2)
	T._check(pet.done and CD.owned("eule"), "Käfig geöffnet: Eule gehört dir")
	T._check(int(CD.state().found) >= 1, "Fund gezählt")
	# zweiter Besuch: nichts mehr zu finden
	G.main.start_expedition(0, "expedition", 0)
	await T._wait(0.4)
	var again := false
	for q in G.main.world.pois:
		if q.kind == "pet":
			again = true
	T._check(not again, "schon gefunden: kein Fund-Ort mehr")


# ---------------------------------------------------------------- Bildschirm, Laden, Admin
func _screens() -> void:
	_fresh()
	G.main.goto_base()
	await T._wait(0.4)
	var sc = G.main.screens
	sc.open("begleiter")
	await T._wait(0.2)
	T._check(sc.is_open() and sc.screen == "begleiter", "Bildschirm Begleiter öffnet")
	for k in [""] + CD.ORDER:
		sc.st["sel"] = k
		sc.refresh()
		await T._wait(0.05)
	T._check(sc.is_open(), "alle Begleiter angezeigt")
	sc.close()
	sc.open("shop")
	await T._wait(0.2)
	T._check(sc.is_open(), "Laden mit Begleitern")
	sc.close()
	G.main.admin.give_companions()
	T._check(CD.owned_count() == CD.ORDER.size(), "Admin: alle Begleiter")
	CD.set_active("waschbaer")
	G.main.admin.companion_level()
	T._check(CD.level("waschbaer") == 2, "Admin: Begleiter +1 Stufe")
