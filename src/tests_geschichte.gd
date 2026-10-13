extends RefCounted
## Prüfungen für Paket E (V6): Geschichte, Zwischenszenen, Chronik, Story-Ziele, Rettungen (Gegnerlager, Schleimfalle,
## Eiskäfig), Gerettete in der Basis, Tauschladen, Forscher und Schmied, Bewohner-Sprechblasen, Helden-Gespräche,
## Auto-Expeditionen mit Bericht und Verletzung. Aufruf aus tests.gd (--selftest) oder allein mit --autotest=geschichte.

const D = preload("res://src/data.gd")
const DG = preload("res://src/data_geschichte.gd")
const Story = preload("res://src/story.gd")
const Models = preload("res://src/models.gd")
const AutoRep = preload("res://src/auto_report.gd")
const Chatter = preload("res://src/chatter.gd")
const SW = preload("res://src/story_world.gd")
const R = preload("res://src/research.gd")
const DB = preload("res://src/data_basis.gd")
const Tausch = preload("res://src/screens/tausch.gd")

var T: Node


func _init(tests: Node) -> void:
	T = tests


func run() -> void:
	_data()
	_assets()
	_rules()
	_auto()
	_talk_and_chat()
	await _scenes()
	await _expedition()
	await _base()
	await _screens()
	P.new_game()
	P.no_save = true


func _fresh() -> void:
	P.new_game()
	P.no_save = true
	P.d.level = 60
	for hk in D.HERO_ORDER:
		P.d.heroes[hk].unlocked = true
		P.d.heroes[hk].level = 30
	P.d.hero_sel = "jona"
	P.d.vehicle_sel = ""


# ---------------------------------------------------------------- Daten
func _data() -> void:
	T._check(FileAccess.file_exists("res://docs/geschichte.md"), "docs/geschichte.md vorhanden")
	for i in D.AREAS.size():
		for k in ["a%d_in" % i, "a%d_boss" % i]:
			T._check(DG.SCENES.has(k), "Szene %s vorhanden" % k)
	T._check(DG.SCENES.has("end1") and DG.SCENES.has("end2"), "Abschlussszenen Akt 1 und Akt 2")
	var roles := ["lead", "ally", "ally2", "jona", "settler", "haendlerin", "forscher", "schmied", "boss", "slime", "heart", "prop"]
	for id in DG.SCENES:
		var sd: Dictionary = DG.SCENES[id]
		T._check((sd.panels as Array).size() >= 3 and (sd.panels as Array).size() <= 5, "Szene %s: 3–5 Tafeln" % id)
		for pn in sd.panels:
			T._check(DG.SHOTS.has(String(pn[2])) and String(pn[0]).length() <= 64 and String(pn[1]).length() <= 120, "Szene %s: Kamerapose und Textlänge (%s)" % [id, String(pn[0])])
		for c in sd.cast:
			T._check(roles.has(String(c[0])), "Szene %s: bekannte Rolle %s" % [id, String(c[0])])
	var listed := {}
	for e in DG.CHRONICLE:
		listed[String(e[0])] = true
	T._check(listed.size() == DG.SCENES.size(), "Chronik listet alle Szenen (%d/%d)" % [listed.size(), DG.SCENES.size()])
	for g in DG.GOALS:
		T._check(String(g.t) in ["visit", "boss", "rescue", "scene"] and not (g.reward as Dictionary).is_empty(), "Story-Ziel gültig: %s" % String(g.text))
	T._check(DG.RESCUE_ORDER.size() >= 3, "mindestens drei Gerettete")
	var areas := {}
	for k in DG.RESCUE_ORDER:
		areas[int(DG.RESCUES[k].area)] = true
	T._check(areas.size() == DG.RESCUE_ORDER.size(), "jede Rettung in einem anderen Gebiet")
	var n := 0
	for cat in DG.CHAT:
		n += (DG.CHAT[cat] as Array).size()
	for l in DG.CHAT_STORY:
		n += (l as Array).size()
	for k in DG.FIG_LINES:
		n += (DG.FIG_LINES[k] as Array).size()
	T._check(n >= 120, "mindestens 120 Sätze für Sprechblasen (%d)" % n)
	for t in DG.TALKS:
		T._check(D.HEROES.has(String(t.a)) and D.HEROES.has(String(t.b)) and String(t.a) != String(t.b), "Helden-Gespräch %s–%s gültig" % [String(t.a), String(t.b)])
	T._check(DG.AUTO_AREA_EVENTS.size() == D.AREAS.size() and DG.AUTO_DANGER.size() == D.AREAS.size(), "Auto-Ereignisse je Gebiet")
	T._check(D.BUILDINGS.has("tauschladen") and String(D.BUILDINGS.tauschladen.screen) == "tausch", "Gebäude Tauschladen öffnet den Tauschladen")
	T._check(preload("res://src/layout_code.gd").KEYS.has("tauschladen"), "Layout-Code kennt den Tauschladen")


func _assets() -> void:
	for k in DG.RESCUE_ORDER:
		T._check(Models.has_glb("hero_" + k) and ResourceLoader.exists("res://icons/hero_%s.png" % k), "Figur hero_%s mit Symbol" % k)
	for m in ["b_tauschladen", "st_camp", "st_cocoon", "st_icecage", "st_heart", "st_heart_red"]:
		T._check(Models.has_glb(m), "Modell %s" % m)
	for ic in ["ui_chronik", "ui_trade", "ui_report", "b_tauschladen"]:
		T._check(ResourceLoader.exists("res://icons/%s.png" % ic), "Symbol %s" % ic)
	for a in D.AREAS:
		T._check(ResourceLoader.exists("res://icons/scene_%s.png" % String(a.key)), "Gebietsbild scene_%s" % String(a.key))
	for s in ["story_open", "story_page", "speech_pop", "radio_blip", "trade_deal", "auto_back", "ice_hack", "rescue_ice_break", "rescue_cocoon_pop", "anvil_ring"]:
		T._check(Sfx.has(s), "Ton %s" % s)
	# die Figuren haben Gesichter wie die Helden
	var h = preload("res://src/humanoid.gd").new()
	T.add_child(h)
	h.build({"kind": "schmied"})
	T._check(h.kind == "schmied" and h.has_faces(), "Schmied: eigenes Modell mit Gesichtern")
	h.queue_free()


# ---------------------------------------------------------------- Regeln
func _rules() -> void:
	_fresh()
	var s := Story.st()
	T._check(s.has("seen") and s.has("rescued") and int(s.goal) == 0, "Spielstand: Geschichte angelegt")
	# Story-Ziele
	var g := Story.goal()
	T._check(String(g.t) == "visit" and int(g.a) == 0 and not Story.goal_done(g), "erstes Story-Ziel: Grüntal betreten")
	Story.mark_visited(0)
	T._check(Story.goal_done(g) and preload("res://src/guide.gd").story_goal_ready(), "Ziel erfüllt nach dem Betreten")
	var gems := int(P.d.res.gems)
	var rw := Story.goal_claim()
	T._check(not rw.is_empty() and int(P.d.res.gems) > gems and int(Story.st().goal) == 1, "Belohnung abgeholt, nächstes Ziel")
	T._check(String(Story.goal().t) == "boss", "zweites Ziel: Dicker Bert")
	P.d.areas.boss[0][0] = true
	T._check(Story.boss_done(0) and Story.progress() == 0 and Story.chapter() == 2, "Boss besiegt: Kapitel 2")
	T._check(SW.pending_scenes() == ["a0_boss"], "verpasste Boss-Szene wird in der Basis nachgeholt (%s)" % str(SW.pending_scenes()))
	Story.mark_seen("a0_boss")
	# alte Stände: Erreichtes gilt als gesehen
	var d2 := {"areas": {"boss": [[true, false, false], [true, false, false], [false, false, false]]}}
	Story.ensure(d2)
	T._check((d2.story.seen as Array).has("a1_boss") and (d2.story.visited as Array).has(1), "alter Stand: erreichte Kapitel gelten als gesehen")
	# Gerettete: Tauschladen, Forscher, Schmied
	T._check(P.max_count("tauschladen") == 0 and P.can_build("tauschladen") != "", "Tauschladen vor der Rettung gesperrt")
	var it := P.make_item("weapon", "j_rifle", 1)
	it.level = 3
	var c0: Dictionary = D.upgrade_cost(it)
	var key := ""
	for k in DB.NODES:
		key = String(k)
		break
	var t0 := R.time_for(key)
	T._check(Story.rescue("haendlerin") and Story.rescued("haendlerin") and not Story.rescue("haendlerin"), "Händlerin befreit (nur einmal)")
	T._check(P.max_count("tauschladen") == 1, "Tauschladen nach der Rettung baubar")
	Story.rescue("forscher")
	T._check(absf(R.time_for(key) - t0 * DG.RESEARCH_K) < 0.01, "Forscher: Forschung %.0f %% schneller" % ((1.0 - DG.RESEARCH_K) * 100.0))
	Story.rescue("schmied")
	var c1: Dictionary = D.upgrade_cost(it)
	T._check(int(c1.coins) < int(c0.coins) and int(c1.parts) <= int(c0.parts), "Schmied: Waffen verbessern günstiger (%d → %d Münzen)" % [int(c0.coins), int(c1.coins)])
	var gear := P.make_item("helmet", "", 1)
	gear.level = 3
	var cg: Dictionary = D.upgrade_cost(gear)
	T._check(int(cg.coins) == int(40 * pow(1.28, 3) * (1.0 + int(gear.rarity) * 0.5)), "Ausrüstung bleibt beim alten Preis")
	# Tauschladen
	var offs := Tausch.offers()
	T._check(offs.size() == DG.TRADES_PER_DAY and offs == Tausch.offers(), "Tauschladen: %d feste Angebote je Tag" % DG.TRADES_PER_DAY)
	var i0 := int(offs[0])
	var tr: Dictionary = DG.TRADES[i0]
	P.add_many({"coins": 99999, "wood": 9999, "stone": 9999, "metal": 9999, "fuel": 999, "cells": 999, "parts": 99, "shards": 99})
	var before := {}
	for r in tr.get:
		before[r] = P.res(String(r))
	var n0 := Tausch.left(i0)
	T._check(Tausch.trade(i0) == "" and Tausch.left(i0) == n0 - 1, "Tausch geklappt, Angebot zählt herunter")
	var got_ok := true
	for r in tr.get:
		if P.res(String(r)) <= int(before[r]) and P.res(String(r)) < P.cap(String(r)):
			got_ok = false
	T._check(got_ok, "Tausch: Ware erhalten")
	while Tausch.left(i0) > 0:
		Tausch.trade(i0)
	T._check(Tausch.trade(i0) != "", "ausverkauft: kein weiterer Tausch")
	var eggs: int = preload("res://src/welt_state.gd").eggs().size()
	T._check(Tausch.egg_ready() and Tausch.buy_egg() == "" and preload("res://src/welt_state.gd").eggs().size() == eggs + 1, "Begleiter-Ei der Woche gekauft")
	T._check(not Tausch.egg_ready() and Tausch.buy_egg() != "", "nur ein Ei je Woche")


# ---------------------------------------------------------------- Auto-Expedition
func _auto() -> void:
	_fresh()
	T._check(AutoRep.risk("mika", 7, 8) > AutoRep.risk("mika", 0, 1), "Gefahr steigt mit Gebiet und Dauer")
	P.d.heroes.mika.level = 1
	var low := AutoRep.risk("mika", 7, 8)
	P.d.heroes.mika.level = 40
	T._check(low > AutoRep.risk("mika", 7, 8) and AutoRep.danger_level(low) == 2, "niedrige Stufe = hohe Gefahr")
	P.add_many({"fuel": 999})
	T._check(P.start_auto("mika", 0, 4) and P.start_auto("bruno", 0, 1), "zwei Helden gleichzeitig unterwegs")
	T._check(P.hero_busy("mika") and P.hero_busy("bruno") and not P.hero_busy("jona"), "beide unterwegs, Jona bleibt")
	P.d.heroes.mika.auto_until = P.now() - 1.0
	var chests := P.chest_count("find")
	var loot := P.collect_auto("mika")
	var rep := AutoRep.latest("mika")
	T._check(not rep.is_empty() and int(rep.area) == 0 and int(rep.hours) == 4, "Bericht nach der Rückkehr")
	T._check((rep.events as Array).size() == int(DG.EVENTS_N[4]) + 1, "Bericht: %d Ereignisse und Ausgang" % (rep.events as Array).size())
	T._check(String(rep.events[0][1]) == "area", "erstes Ereignis passt zum Gebiet")
	T._check(P.chest_count("find") == chests + int(rep.extra.get("chests", 0)), "Fundkisten aus Ereignissen gutgeschrieben")
	T._check(loot is Dictionary, "Beute zurückgegeben")
	var pic := AutoRep.picture(0, "mika")
	T._check(pic.get_child_count() >= 3, "Bild: Gebiet, Held, Rahmen")
	pic.free()
	var cd := AutoRep.card(rep)
	T._check(cd != null, "Berichtskarte gebaut")
	cd.free()
	# Verletzung: Held kurz nicht einsetzbar
	Story.injure("mika", 30.0)
	T._check(Story.injured("mika") and Story.injury_left("mika") > 60.0, "Mika ist verletzt")
	P.select_hero("mika")
	T._check(String(P.d.hero_sel) != "mika", "verletzt: nicht auswählbar")
	T._check(not P.start_auto("mika", 0, 1), "verletzt: kann nicht losziehen")
	P.d.hero_sel = "mika"
	Story.injure("mika", 30.0)
	T._check(String(P.d.hero_sel) != "mika", "Verletzung wechselt den gespielten Helden")
	Story.heal("mika")
	T._check(not Story.injured("mika"), "geheilt")
	# erzwungene Verletzung im Bericht
	P.d.heroes.bruno.auto_until = P.now() - 1.0
	G.test_args["auto_hurt"] = "1"
	P.collect_auto("bruno")
	G.test_args.erase("auto_hurt")
	var rb := AutoRep.latest("bruno")
	T._check(float(rb.hurt) > 0.0 and String(rb.events[-1][1]) == "hurt" and Story.injured("bruno"), "Bericht meldet Verletzung")
	T._check(AutoRep.reports().size() == 2 and AutoRep.unseen() == 2, "zwei neue Berichte")
	AutoRep.mark_read()
	T._check(AutoRep.unseen() == 0, "Berichte gelesen")


# ---------------------------------------------------------------- Helden-Gespräche, Sprechblasen
func _talk_and_chat() -> void:
	_fresh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var t := SW.build_talk("jona", 0, rng)
	T._check(t.size() >= 2, "Helden-Gespräch hat mindestens zwei Zeilen")
	var both := false
	for ln in t:
		if String(ln[0]) == "b" and D.HEROES.has(String(ln[1])):
			both = true
	T._check(both, "zweiter Held spricht per Funk")
	t = SW.build_talk("ada", 2, rng)
	T._check(t.size() >= 2, "Ada in der Staubebene: Gespräch")
	# nur Jona: Funk aus der Basis mit Gebietshinweis
	P.new_game()
	P.no_save = true
	var t2 := SW.build_talk("jona", 5, rng)
	T._check(t2.size() == 2 and String(t2[0][1]) == "" and String(t2[1][0]) == "a", "allein: Bewohner funkt, Held antwortet")
	_fresh()
	# Lage der Sprechblasen
	P.d.week.start_day = P.day_index() - 6
	var ms := Chatter.moods(null, null)
	var cats := ms.map(func(m): return String(m[0]))
	T._check(cats.has("flut_heute"), "Fluttag: Bewohner reden über die Flut")
	P.d.week.start_day = P.day_index()
	Story.st().win_t = P.now()
	cats = Chatter.moods(null, null).map(func(m): return String(m[0]))
	T._check(cats.has("sieg") and not cats.has("flut_heute"), "nach einem Sieg: Lob")
	var line := Chatter.line_for(null, null, rng)
	T._check(line != "", "Satz gefunden: %s" % line)
	var seen := {}
	for i in 30:
		seen[Chatter.line_for(null, null, rng)] = true
	T._check(seen.size() >= 12, "abwechslungsreich (%d verschiedene Sätze in 30)" % seen.size())


# ---------------------------------------------------------------- Zwischenszenen
func _scenes() -> void:
	_fresh()
	Story.rescue("haendlerin")
	G.main.goto_base()
	await T._wait(0.4)
	var done := [0]
	var sc = Story.play("a2_in", func(): done[0] += 1)
	await _frames(4)
	T._check(sc != null and Story.playing() and T.get_tree().paused, "Szene läuft, Spiel angehalten")
	T._check(sc.stage.actor_count() >= 4, "Bühne mit Figuren (%d)" % sc.stage.actor_count())
	T._check(not G.main.world.visible, "Welt dahinter wird nicht gezeichnet")
	T._check(Story.seen("a2_in"), "Szene als gesehen gemerkt")
	var p0: int = sc.panel
	sc._tap_t = 1.0
	sc._on_input(_click())
	T._check(sc.panel == p0 + 1, "Tippen: nächste Tafel")
	sc._skip()
	for i in 240:
		await T.get_tree().process_frame
		if done[0] > 0:
			break
	await _frames(2)
	T._check(done[0] == 1 and not Story.playing() and not T.get_tree().paused and G.main.world.visible, "Überspringen beendet die Szene, Spiel läuft weiter")
	# alle Szenen einmal aufbauen
	var built := 0
	for id in DG.SCENES:
		var s2 = Story.play(id, Callable(), true)
		await _frames(2)
		if s2 != null and s2.stage != null and s2.stage.actor_count() > 0:
			built += 1
		s2.stop()
		await _frames(2)
	T._check(built == DG.SCENES.size(), "alle %d Szenen mit Bühne und Figuren" % built)
	T._check(not T.get_tree().paused and G.main.world.visible, "nach den Szenen läuft das Spiel")


func _frames(n: int) -> void:
	for i in n:
		await T.get_tree().process_frame


func _click() -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	return ev


# ---------------------------------------------------------------- Expedition: Rettungen, Boss-Szene
func _start(area: int) -> Node:
	G.main.start_expedition(area, "expedition", 0)
	await T._wait(0.5)
	return G.main.world


func _rescue_poi(e: Node):
	for q in e.pois:
		if q.kind == "story":
			return q
	return null


func _expedition() -> void:
	_fresh()
	var e = await _start(2)
	T._check(Story.visited(2), "Staubebene als betreten gemerkt")
	var q = _rescue_poi(e)
	T._check(q != null and q.who == "haendlerin" and q.mode == "camp", "Staubebene: Gegnerlager mit der Händlerin")
	if q != null:
		T._check(q.guards_left() > 0 and q.status_text().contains("Wachen"), "Lager bewacht (%d)" % q.guards_left())
		T._check(e.map_points().size() > 0, "Karte zeigt Punkte")
		e.phase = "explore"
		e.hero.global_position = Vector3(q.p.x + 1.0, 0, q.p.y)
		await T._wait(0.5)
		T._check(not q.done, "mit Wachen geht der Käfig nicht auf")
		for en in e.horde.in_radius(q.p, DG.CAMP_CLEAR_R + 2.0):
			e.horde.damage(en, 999999.0)
		e.hero.global_position = Vector3(q.p.x + 1.0, 0, q.p.y)
		await T._wait(DG.CAMP_OPEN_TIME + 1.5)
		T._check(q.done and Story.rescued("haendlerin"), "Lager geräumt, Käfig offen: Händlerin gerettet")
	# Boss-Sieg in der Expedition: Szene (in Tests nur gemerkt)
	e.bounty_done = true
	await T._wait(0.8)
	T._check(Story.boss_done(2), "Boss-Sieg gemerkt")
	e = await _start(2)
	T._check(_rescue_poi(e) == null, "Händlerin gerettet: kein Lager mehr")
	# Schleimfalle
	e = await _start(4)
	q = _rescue_poi(e)
	T._check(q != null and q.who == "forscher" and q.enemy != null, "Sumpfwerk: Kokon mit dem Professor")
	if q != null:
		e.horde.damage(q.enemy, 9999999.0)
		await T._wait(0.6)
		T._check(q.done and Story.rescued("forscher"), "Kokon zerschossen: Professor gerettet")
	# Eiskäfig
	e = await _start(5)
	q = _rescue_poi(e)
	T._check(q != null and q.who == "schmied" and q.mode == "ice", "Frostpass: Schmied im Eis")
	if q != null:
		e.phase = "explore"
		var guard := 0
		while not q.done and guard < 200:
			guard += 1
			q.tick(0.1, q.p)
		T._check(q.done and Story.rescued("schmied"), "Eis aufgehackt: Schmied gerettet")
		T._check(e.horde.alive > 0, "beim Aufhacken greifen Eiswesen an")
	var sw = e.get_node_or_null("Geschichte")
	T._check(sw != null and sw.is_exp and sw.speech != null, "Geschichte hängt an der Expedition")


# ---------------------------------------------------------------- Basis: Gerettete, Sprechblasen, Antippen
func _base() -> void:
	G.main.goto_base()
	await T._wait(0.6)
	var w = G.main.world
	var sw = w.get_node_or_null("Geschichte")
	for i in 40:
		if sw == null or sw.town != null:
			break
		await T._wait(0.1)
	T._check(sw != null and sw.town != null and sw.chatter != null, "Geschichte hängt an der Basis (angehalten: %s)" % T.get_tree().paused)
	if sw == null or sw.town == null:
		return
	T._check(sw.town.npcs.size() == 3, "drei Gerettete wohnen in der Basis (%d)" % sw.town.npcs.size())
	var kinds := {}
	for n in sw.town.npcs:
		kinds[String(n.h.kind)] = true
	T._check(kinds.has("haendlerin") and kinds.has("forscher") and kinds.has("schmied"), "jede mit eigenem Aussehen")
	await T._wait(3.0)
	var moved := 0
	for n in sw.town.npcs:
		if n.state != "idle" or not n.task.is_empty():
			moved += 1
	T._check(moved >= 2, "Gerettete haben einen Tagesablauf (%d beschäftigt)" % moved)
	# Sprechblase über einer Figur
	var n0 = sw.town.npcs[0]
	n0.show_at(n0.pos)
	var b = sw.speech.say(n0.h, "Testsatz")
	await T._wait(0.2)
	T._check(b != null and sw.speech.count() >= 1, "Sprechblase gezeigt")
	sw.speech.clear()
	var said: int = sw.speech.said
	var line: String = sw.chatter.speak_once(true)
	T._check(line == "" or sw.speech.said == said + 1, "Bewohner spricht: „%s“" % line)
	# Antippen einer Geretteten
	var cam: Camera3D = w.get_viewport().get_camera_3d()
	n0.show_at(n0.pos)
	w.cam.override_target = n0.h.global_position
	w.cam.snap()
	await T._wait(0.2)
	var sp := cam.unproject_position(n0.h.global_position + Vector3(0, 1.1, 0))
	T._check(sw.tap(sp), "Antippen einer Geretteten zeigt Name und Satz")
	T._check(n0._sign != null and String(n0._sign.text).contains(String(n0.name)), "Schild mit Namen")
	w.cam.override_target = null
	# Antippen eines Bewohners: Satz je nach Lage
	if not w.npc_board.npcs.is_empty():
		var bn = w.npc_board.npcs[0]
		var tl: String = Chatter.tap_line(bn, w.npc_board)
		T._check(tl != "", "Bewohner hat beim Antippen etwas zu sagen")
	# Ziele-Leiste: Zeile „Geschichte“
	var row = G.main.hud.find_child("StoryGoal", true, false)
	T._check(row != null, "Ziele-Leiste hat die Zeile „Geschichte“")
	# Lob nach Sieg
	P.d.stats.floods_won = int(P.d.stats.floods_won) + 1
	await T._wait(1.3)
	T._check(P.now() - float(Story.st().win_t) < 5.0, "Flut-Sieg bemerkt (Lob der Bewohner)")


# ---------------------------------------------------------------- Bildschirme
func _screens() -> void:
	var S = G.main.screens
	for sc in ["chronik", "tausch", "auto"]:
		for tab in [0, 1]:
			S.open(sc, {"tab": tab})
			await T._wait(0.15)
			T._check(S.is_open() and S.screen == sc, "Bildschirm %s (Reiter %d)" % [sc, tab])
	S.close()
	S.open("heroes", "auto")
	await T._wait(0.15)
	T._check(S.is_open(), "Helden: Reiter Auto-Expedition")
	S.close()
	S.open("expedition")
	await T._wait(0.15)
	T._check(S.is_open(), "Expedition mit Auto-Expeditionen-Knopf")
	S.close()
