extends RefCounted
## Prüfungen für Paket H (V6): Ausrüstungs-Sets, Waffenmodule, Gift, Mündung, Wurfwaffen, Gesichter, Siegerposen,
## Laufstile, Nachschwingen, Nele (Daten, Rettung, Fähigkeiten), Tier-Clips. Aufruf aus tests.gd (--selftest) oder allein
## mit --autotest=helden. Dazu der Messlauf --autotest=dps: Schaden je Sekunde jeder Waffe gegen jede Familie
## (Einzelziel und Gruppe, im Spiel gemessen) -> docs/balance/waffen.md + waffen.csv, Begleiter -> docs/balance/begleiter.md.

const D = preload("res://src/data.gd")
const DH = preload("res://src/data_helden.gd")
const HS = preload("res://src/helden.gd")
const Humanoid = preload("res://src/humanoid.gd")
const Models = preload("res://src/models.gd")
const AD = preload("res://src/anim_human_data.gd")
const AA = preload("res://src/animal_anim.gd")
const CD = preload("res://src/companion_data.gd")

var T: Node
var w: Node3D
var hero: Node3D
var A := Vector2.ZERO


func _init(tests: Node) -> void:
	T = tests


func run() -> void:
	_data()
	_sets()
	_modules()
	_poison_rules()
	_figures()
	_nele_rules()
	await _world_checks()


# ---------------------------------------------------------------- Daten und Modelle
func _data() -> void:
	T._check(DH.SET_ORDER.size() >= 6, "mindestens 6 Ausrüstungs-Sets (%d)" % DH.SET_ORDER.size())
	for sk in DH.SET_ORDER:
		var sd: Dictionary = DH.SETS[sk]
		T._check(sd.pieces.size() == 3 and not sd.b2.is_empty() and not sd.b3.is_empty(), "Set %s: 3 Teile, Boni für 2 und 3" % sk)
		T._check(D.HEROES.has(String(sd.hero)), "Set %s passt zu einem Helden" % sk)
		for slot in ["helmet", "vest", "charm"]:
			T._check(Models.has_glb("gear_%s_%s" % [sk, slot]), "Modell gear_%s_%s" % [sk, slot])
			T._check(ResourceLoader.exists("res://icons/gear_%s_%s.png" % [sk, slot]), "Symbol gear_%s_%s" % [sk, slot])
	T._check(DH.MODULE_ORDER.size() >= 8, "mindestens 8 Waffenmodule")
	for mk in DH.MODULE_ORDER:
		var md: Dictionary = DH.MODULES[mk]
		T._check(md.has("name") and md.has("text") and not (md.fx as Dictionary).is_empty() and not (md.cost as Dictionary).is_empty(), "Modul %s: Name, Text, Wirkung, Kosten" % mk)
		T._check(Models.has_glb("mod_" + mk) and ResourceLoader.exists("res://icons/mod_%s.png" % mk), "Modell und Symbol mod_%s" % mk)
	for k in ["core_feuer", "core_eis", "core_gift", "core_blitz", "silencer", "scope", "loader", "drum"]:
		T._check(DH.MODULES.has(k), "Modul %s vorhanden" % k)
	for s in ["module_fit", "module_remove", "module_craft", "module_found", "w_bubble", "w_ice_harpoon", "w_torpedo", "w_net", "w_kraken", "w_wave", "w_ink_loop",
			"sk_strudel", "sk_luftblase", "sk_springflut"]:
		T._check(Sfx.has(s), "Ton %s" % s)
	for k in ["a_dog_rig", "a_cat_rig", "a_bird_rig"]:
		T._check(Models.has_glb(k), "Tiermodell mit Skelett %s" % k)


# ---------------------------------------------------------------- Sets
func _sets() -> void:
	P.new_game()
	P.no_save = true
	var hk := "mika"
	P.d.heroes[hk].unlocked = true
	P.d.heroes[hk].level = 20
	var base: Dictionary = P.hero_stats(hk).m.duplicate()
	var hel: Dictionary = P.make_item("helmet", "feuerwehr", 0)
	var ves: Dictionary = P.make_item("vest", "feuerwehr", 0)
	var cha: Dictionary = P.make_item("charm", "feuerwehr", 0)
	T._check(P.item_name(hel) == "Feuerwehrhelm" and P.item_name(cha) == "Florian-Medaille", "Set-Teile tragen ihren Namen (%s)" % P.item_name(hel))
	T._check(P.equip(hk, int(hel.id)), "Set-Helm anlegen")
	var m1: Dictionary = P.hero_stats(hk).m
	T._check(is_equal_approx(float(m1.burn), float(base.burn)), "ein Teil: noch kein Set-Bonus")
	P.equip(hk, int(ves.id))
	var m2: Dictionary = P.hero_stats(hk).m
	T._check(absf(float(m2.burn) - float(base.burn) - 0.25) < 0.001, "zwei Teile: +25 %% Brenndauer (%.2f)" % (float(m2.burn) - float(base.burn)))
	P.equip(hk, int(cha.id))
	var m3: Dictionary = P.hero_stats(hk).m
	T._check(absf(float(m3.get("elem_feuer", 0.0)) - 0.15) < 0.001, "drei Teile: Feuer-Waffen +15 %")
	T._check(HS.set_counts(hk).get("feuerwehr", 0) == 3 and HS.set_lines(hk).size() == 1, "Set-Zählung und Bonus-Text")
	# Glücksbringer zählt erst ab seiner Heldenstufe
	P.d.heroes[hk].level = D.HERO_CHARM_LEVEL - 1
	T._check(int(HS.set_counts(hk).get("feuerwehr", 0)) == 2, "Glücksbringer zählt erst ab Stufe %d" % D.HERO_CHARM_LEVEL)
	P.d.heroes[hk].level = 20
	# gemischte Sets geben keinen Bonus
	var other: Dictionary = P.make_item("vest", "bau", 0)
	P.equip(hk, int(other.id))
	T._check(int(HS.set_counts(hk).get("feuerwehr", 0)) == 2 and int(HS.set_counts(hk).get("bau", 0)) == 1, "Teile verschiedener Sets zählen getrennt")
	# Modelle am Helden
	var gm := HS.gear_models(hk)
	T._check(String(gm.get("helmet", "")) == "gear_feuerwehr_helmet" and String(gm.get("vest", "")) == "gear_bau_vest", "Modelle der angelegten Teile")
	# Alte Stände: Ausrüstung ohne Set bekommt eines
	var old: Dictionary = P.make_item("helmet", "", 1)
	HS.ensure(P.d)
	T._check(DH.SETS.has(String(old.key)), "alte Ausrüstung bekommt ein Set (%s)" % String(old.key))
	# Kisten: neue Ausrüstung gehört immer zu einem Set
	var n_gear := 0
	var n_set := 0
	for i in 60:
		var pc: Dictionary = P._grant_piece(1, 1.0)
		if String(pc.kind) == "item":
			var it := P.item(int(pc.item))
			if D.GEAR.has(String(it.slot)):
				n_gear += 1
				if DH.SETS.has(String(it.key)):
					n_set += 1
	T._check(n_gear > 0 and n_set == n_gear, "Ausrüstung aus Kisten mit Set (%d/%d)" % [n_set, n_gear])


# ---------------------------------------------------------------- Module
func _modules() -> void:
	P.new_game()
	P.no_save = true
	P.d.heroes.jona.level = 40
	var g0: Dictionary = P.make_item("weapon", "j_rifle", 0)
	var g2: Dictionary = P.make_item("weapon", "j_rifle", 2)
	var g3: Dictionary = P.make_item("weapon", "j_burst", 3)
	T._check(HS.sockets(g0).size() == 1 and HS.sockets(g2).size() == 2 and HS.sockets(g3).size() == 3, "Sockel nach Seltenheit 1/2/3")
	T._check(HS.fits("scope", "j_rifle") == "" and HS.fits("weight", "j_rifle") != "" and HS.fits("loader", "b_ball") != "", "passt / passt nicht (Wuchtgewicht, Magazin)")
	T._check(HS.fits("scope", "j_turret") != "", "Geschütze haben keine Sockel")
	T._check(not HS.insert(int(g2.id), 0, "scope"), "ohne Modul im Lager kein Einsetzen")
	P.add_many({"coins": 20000, "parts": 500, "metal": 2000, "fuel": 500, "cells": 300, "wood": 2000, "stone": 2000})
	var c0 := P.res("coins")
	T._check(HS.craft_module("scope") and HS.module_count("scope") == 1 and P.res("coins") == c0 - int(DH.MODULES.scope.cost.coins), "Modul herstellen kostet genau den Preis")
	HS.craft_module("core_feuer")
	HS.craft_module("core_gift")
	T._check(HS.insert(int(g2.id), 0, "scope") and HS.module_count("scope") == 0, "Modul einsetzen nimmt es aus dem Lager")
	T._check(HS.insert(int(g2.id), 1, "core_feuer"), "Element-Kern einsetzen")
	HS.add_module("core_eis", 1)
	T._check(not HS.insert(int(g2.id), 0, "core_eis") and HS.module_count("core_eis") == 1, "nur ein Element-Kern je Waffe")
	T._check(HS.modules_of(g2) == ["scope", "core_feuer"], "Module der Waffe: %s" % str(HS.modules_of(g2)))
	var wm := HS.weapon_with_modules("j_rifle", g2)
	T._check(float(wm.get("burn", 0.0)) >= 2.0 and not D.WEAPONS.j_rifle.has("burn"), "Feuer-Kern gibt Brennen (D.WEAPONS bleibt unverändert)")
	T._check(absf(float(HS.module_fx(g2).range) - 0.15) < 0.001, "Zielfernrohr +15 % Reichweite")
	T._check(HS.remove(int(g2.id), 0) and HS.module_count("scope") == 1, "Modul ausbauen gibt es zurück")
	HS.insert(int(g2.id), 0, "scope")
	var sc0 := HS.module_count("scope") + HS.module_count("core_feuer")
	T._check(P.dismantle(int(g2.id)) > 0 and HS.module_count("scope") + HS.module_count("core_feuer") == sc0 + 2, "Zerlegen gibt die Module zurück")
	# Verschmelzen
	var ms: Array = []
	for i in 3:
		ms.append(P.make_item("weapon", "j_parcel", 0))
	HS.add_module("loader", 1)
	HS.insert(int(ms[0].id), 0, "loader")
	var l0 := HS.module_count("loader")
	var nw: Dictionary = P.merge(int(ms[0].id))
	T._check(not nw.is_empty() and HS.module_count("loader") == l0 + 1 and HS.sockets(nw).size() == 1, "Verschmelzen gibt Module zurück, neues Stück hat Sockel")
	# Kisten: Modul ersetzt ein Stück
	P.d.chests["boss"] = 40
	var found := 0
	var sizes_ok := true
	for i in 40:
		var out: Array = P.open_chest("boss")
		for pc in out:
			if String(pc.kind) == "module":
				found += 1
		if out.size() != int(D.CHESTS.boss.count):
			sizes_ok = false
	T._check(found >= 5 and sizes_ok, "Bosskisten: Module als Fund, Stückzahl bleibt (%d Module)" % found)
	# Alte Stände: sockets werden zu Text-Listen
	g3["sockets"] = [1, ""]
	HS.ensure(P.d)
	T._check(HS.sockets(g3).size() == 3, "Sockel alter Stände werden ergänzt")


# ---------------------------------------------------------------- Gift
func _poison_rules() -> void:
	P.new_game()
	P.no_save = true
	var lo: Dictionary = P.make_item("weapon", "y_blowpipe", 0)
	var hi: Dictionary = P.make_item("weapon", "y_blowpipe", 3)
	hi.level = 10
	T._check(HS.poison_dps(hi, 1.0) > HS.poison_dps(lo, 1.0) * 2.0, "Gift: legendär Stufe 10 > doppelt so stark wie gewöhnlich")
	T._check(HS.poison_dps(lo, 2.0) > HS.poison_dps(lo, 1.0), "Gift wächst mit der Heldenstärke")
	T._check(is_equal_approx(HS.poison_dps(lo, 1.0), DH.POISON_DPS), "Grundwert Gift %.1f/s" % DH.POISON_DPS)


# ---------------------------------------------------------------- Figuren (ohne Welt)
func _figures() -> void:
	# Siegerposen, Laufstile, Nele-Clips
	var lib: AnimationLibrary = Humanoid.library()
	for hk in D.HERO_ORDER:
		T._check(lib.has_animation(hk + "_victory"), "Siegerpose %s_victory" % hk)
		T._check(lib.has_animation("gait_" + hk), "Laufstil gait_%s" % hk)
	T._check(Humanoid.clip_len("fire_slam") >= 0.5, "Überkopf-Schlag fire_slam")
	# Gesichter, Kopfbedeckung, Federn
	for hk in D.HERO_ORDER:
		var sc: Node = Models._scene("hero_" + hk).instantiate()
		var sk: Skeleton3D = sc.get_node_or_null("rw_human/Skeleton3D")
		var faces := 0
		var hat := false
		var springs := 0
		if sk != null:
			for c in sk.get_children():
				if String(c.name).begins_with("face_"):
					faces += 1
				if String(c.name) == "hat":
					hat = true
			for i in sk.get_bone_count():
				if String(sk.get_bone_name(i)).begins_with("spring_"):
					springs += 1
		T._check(faces == 5 and hat, "hero_%s: 5 Gesichter und eigene Kopfbedeckung (%d)" % [hk, faces])
		T._check(springs >= 1, "hero_%s: nachschwingende Teile (%d)" % [hk, springs])
		sc.free()


func _nele_rules() -> void:
	var def: Dictionary = D.HEROES.nele
	T._check(D.HERO_ORDER.has("nele") and int(def.unlock_area) == 3, "Nele gehört zur Schrottküste")
	T._check(D.hero_weapons("nele").size() == 15 and (def.chapters as Array).size() == 5 and (def.skills as Array).size() == 3, "Nele: 15 Waffen, 5 Kapitel, 3 Fähigkeiten")
	for sk in def.skills:
		T._check(D.SKILLS.has(sk) and Sfx.has("sk_" + String(sk)), "Nele: Fähigkeit %s mit Ton" % sk)
	for k in Sfx.VOICE_KINDS:
		T._check(Sfx.has("v_nele_%s" % k), "Nele ruft: v_nele_%s" % k)
	T._check(Models.has_glb("hero_nele") and ResourceLoader.exists("res://icons/hero_nele.png"), "Modell und Bild hero_nele")
	# Rettung an der Schrottküste: erst Yuki, dann Nele
	P.new_game()
	P.no_save = true
	P.expedition_end(3, 0, "jona", true, {}, {"rescued": true})
	T._check(P.hero_unlocked("yuki") and not P.hero_unlocked("nele"), "erste Rettung an der Schrottküste: Yuki")
	P.expedition_end(3, 0, "jona", true, {}, {"rescued": true})
	T._check(P.hero_unlocked("nele"), "zweite Rettung an der Schrottküste: Nele")
	T._check(P.hero("nele").weapon > 0 and String(P.item(int(P.hero("nele").weapon)).key) == "n_harpoon", "Nele kommt mit ihrer Harpune")
	# alter Spielstand ohne Nele
	P.d.heroes.erase("nele")
	P.d.badges.erase("nele")
	HS.ensure(P.d)
	T._check(P.d.heroes.has("nele") and P.d.badges.has("nele") and not P.hero_unlocked("nele"), "alte Stände bekommen Nele (gesperrt)")


# ---------------------------------------------------------------- in der Welt
func _arena() -> void:
	P.debug_setup(6)
	for hk in D.HERO_ORDER:
		P.d.heroes[hk].unlocked = true
		P.d.heroes[hk].level = 40
		P.d.heroes[hk].gear = {"helmet": 0, "vest": 0, "charm": 0}
	P.d.hero_sel = "jona"
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
	A = Vector2.ZERO
	for r in [30, 36, 42, 48, 54]:
		for k in 16:
			var cand: Vector2 = Vector2.from_angle(TAU * k / 16.0) * r
			var ok := true
			for dx in range(-12, 13, 2):
				for dy in range(-12, 13, 2):
					var q: Vector2 = cand + Vector2(dx, dy)
					if w.field.is_solid(q) or w.field.structure_at(q) != null:
						ok = false
			if ok:
				A = cand
				break
		if A != Vector2.ZERO:
			break


func _world_checks() -> void:
	await _arena()
	T._check(A != Vector2.ZERO, "Arena für Paket H gefunden")
	hero.global_position = Vector3(A.x, 0, A.y)
	hero.max_hp = 1.0e7
	hero.hp = 1.0e7
	# Mündung am Leerobjekt des Modells
	var it: Dictionary = P.make_item("weapon", "j_rifle", 0)
	hero.set_weapon(it)
	var wn: Node3D = Models.weapon("j_rifle")
	var mz := Models.find(wn, "muzzle")
	var want: Vector3 = mz.position if mz != null else Vector3.ZERO
	wn.free()
	T._check(hero.body.muzzle.position.distance_to(want) < 0.01 and hero.body.muzzle.position.z < float(D.WEAPONS.j_rifle.len) - 0.05,
		"Mündung sitzt am Lauf des Modells (%s statt Länge %.2f)" % [str(hero.body.muzzle.position), float(D.WEAPONS.j_rifle.len)])
	# Wurfwaffen größer in der Hand
	hero.set_weapon(P.make_item("weapon", "j_boomerang", 0))
	T._check(absf(hero.body._weapon_node.scale.x - DH.TOSS_SCALE) < 0.01, "Bumerang in der Hand %.1f-fach" % DH.TOSS_SCALE)
	# Module am Modell und Wirkung
	var g: Dictionary = P.make_item("weapon", "j_rifle", 3)
	hero.set_weapon(g)                     # dasselbe Stück ohne Module messen (Zufallswerte der Stücke würden den Vergleich verfälschen)
	var r0: float = hero.wrange
	HS.add_module("scope", 1)
	HS.add_module("silencer", 1)
	HS.add_module("core_gift", 1)
	HS.insert(int(g.id), 0, "scope")
	HS.insert(int(g.id), 1, "silencer")
	HS.insert(int(g.id), 2, "core_gift")
	hero.set_weapon(g)
	T._check(hero.wrange > r0 * 1.1 and float(hero.weapon.spread) < float(D.WEAPONS.j_rifle.spread) and hero.weapon.has("poison"), "Module wirken (Reichweite, Streuung, Gift)")
	T._check(hero.body.module_nodes().size() == 3, "drei Module sitzen am Waffenmodell (%d)" % hero.body.module_nodes().size())
	# Gift skaliert im Kampf
	var e = w.horde.spawn(0, A + Vector2(0, 3), 50.0, 0.0, 0.0)
	e.root = 999.0
	hero._hit(e, 1.0, Vector2(0, 1))
	T._check(e.poison > 0.0 and absf(e.poison_d - hero.poison_d) < 0.01 and hero.poison_d > 4.0, "Gift: Gegner nimmt %.1f/s (Held Stufe 40)" % hero.poison_d)
	w.horde.clear()
	# Ausrüstung am Modell, Helm ersetzt die Kopfbedeckung
	var hel: Dictionary = P.make_item("helmet", "bau", 0)
	P.equip("jona", int(hel.id))
	HS.dress(hero.body, "jona")
	T._check(hero.body.gear_model("helmet") == "gear_bau_helmet" and hero.body._hat != null and not hero.body._hat.visible, "Bauhelm sitzt am Kopf, eigene Kopfbedeckung aus")
	P.d.heroes.jona.gear.helmet = 0
	HS.dress(hero.body, "jona")
	T._check(hero.body.gear_model("helmet") == "" and hero.body._hat.visible, "Helm ablegen: eigene Kopfbedeckung wieder da")
	# Gesichter
	var body = hero.body
	T._check(body.has_faces() and body._faces.size() == 5, "Held hat 5 Gesichter")
	body.play("hit_light")
	for i in 3:
		body.tick(0.05)
	T._check(body.face == "pain", "Treffer: Schmerz im Gesicht (%s)" % body.face)
	body.stop_clip()
	body._blink_t = -0.01
	body._face_t = 0.0
	body.tick(0.05)
	T._check(body.face == "blink", "Blinzeln (%s)" % body.face)
	# Siegerpose nach gewonnenem Kampf
	w.result = {"win": true}
	hero._on_battle_ended()
	for i in 4:
		body.tick(0.05)
	var vc := ""
	for ch in body._ch:
		if ch.on:
			vc = String(ch.clip)
	T._check(vc == "jona_victory" and body.face in ["joy", "blink"], "Sieg: Siegerpose %s und Freude" % vc)
	body.stop_clip()
	# Wurfbahn beim Zielen mit Bogenwurf-Waffe
	hero.set_weapon(P.make_item("weapon", "j_parcel", 0))
	hero._aim = Vector2(0, 1)
	hero._process(0.016)
	T._check(hero._arc.shown, "Wurfbahn sichtbar beim Zielen mit dem Paketwerfer")
	hero._aim = Vector2.ZERO
	hero._process(0.016)
	T._check(not hero._arc.shown, "Wurfbahn aus ohne Ziel")
	# Laufstil wirkt beim Laufen
	body.speed_mps = 4.0
	body.move_amount = 0.6
	for i in 10:
		body.tick(0.05)
	T._check(body._gait_w > 0.3, "Laufstil wird beim Laufen eingeblendet (%.2f)" % body._gait_w)
	body.speed_mps = 0.0
	body.move_amount = 0.0
	# Nele: Fähigkeiten in der Welt
	P.d.hero_sel = "nele"
	var hp2: Vector2 = hero.pos2()
	hero.queue_free()
	w.spawn_hero("nele", hp2)
	await T._wait(0.2)
	hero = w.hero
	T._check(hero.key == "nele" and hero.body.kind == "nele", "Nele spielbar")
	hero.global_position = Vector3(A.x, 0, A.y)
	for i in 5:
		var e2 = w.horde.spawn(0, A + Vector2(-1.0 + i * 0.5, 4.0), 50.0, 0.0, 0.0)
		e2.root = 999.0
	for s in [0, 1, 2]:
		hero.skills.slots[s].locked = false
		hero.skills.slots[s].left = 0.0
		T._check(hero.skills.use(s), "Nele: Fähigkeit %d" % (s + 1))
	await T._wait(0.5)
	var hurt := 0
	for e3 in w.horde.list:
		if e3.hp < e3.mhp:
			hurt += 1
	T._check(hurt >= 3, "Springflut trifft (%d Gegner)" % hurt)
	w.horde.clear()
	# Neles Passiv: Wasser-Waffen stärker
	var nb: Dictionary = P.make_item("weapon", "n_bubble", 0)
	hero.set_weapon(nb)
	var dn: float = hero.dmg
	T._check(dn > float(D.WEAPONS.n_bubble.damage) * (1.0 + float(hero.m.dmg)) * 1.1, "Nele: Wasser-Waffe +15 %")
	# Tiere mit Clips
	var wl = w.get("wildlife")
	if wl == null:
		for c in w.get_children():
			if c.get("animals") != null:
				wl = c
	T._check(wl != null, "Tiere der Basis gefunden")
	if wl != null:
		var n_ap := 0
		var dog = null
		for a in wl.animals:
			if a.has("ap"):
				n_ap += 1
			if a.kind == "dog":
				dog = a
		T._check(n_ap >= 2, "Tiere mit Blender-Clips (%d)" % n_ap)
		if dog != null and dog.has("ap"):
			dog.st = "walk"
			dog.n.position += Vector3(0.05, 0, 0)
			AA.update(dog, 0.016)
			dog.n.position += Vector3(0.05, 0, 0)
			AA.update(dog, 0.016)
			T._check(String(dog.get("clip", "")) in ["walk", "run"], "Hund läuft mit Lauf-Clip (%s)" % String(dog.get("clip", "")))
			dog.st = "sit"
			AA.update(dog, 0.016)
			T._check(String(dog.get("clip", "")) == "sit", "Hund sitzt (Clip sit)")
	P.d.hero_sel = "jona"


# ================================================================= Messlauf: Waffen-Balance (--autotest=dps)
const GROUP := 6
const MEASURE_T := 4.0


func dps() -> void:
	await _arena()
	hero.max_hp = 1.0e9
	hero.hp = 1.0e9
	P.d.hero_sel = "jona"
	var fams: Array = D.AREA_FAMILY
	var keys: Array = []
	for hk in D.HERO_ORDER:
		keys.append_array(D.hero_weapons(hk))
	if G.arg("weapons") != "":
		keys = Array(G.arg("weapons").split(","))
	# Zwischenstand: jede gemessene Waffe kommt sofort in docs/balance/dps_roh.csv (Lauf lässt sich fortsetzen)
	var raw := _read_raw()
	if G.arg("fresh") == "1":
		raw.clear()
	var t0 := Time.get_ticks_msec()
	for k in keys:
		if raw.has(k) and G.arg("remeasure") == "":
			var sum := 0.0
			for fam in fams:
				sum += float(raw[k].single.get(fam, 0.0)) + float(raw[k].group.get(fam, 0.0))
			if sum > 0.0 or D.WEAPONS[k].mode == "turret":
				continue
		var res := {"single": {}, "group": {}}
		for fam in fams:
			res.single[fam] = await _measure(k, fam, 1)
			res.group[fam] = await _measure(k, fam, GROUP)
		raw[k] = res
		_write_raw(raw, fams)
		print("DPS %-14s %s" % [k, str(res.single.values().map(func(x): return int(x)))])
	var rows: Array = []
	for hk in D.HERO_ORDER:
		for k in D.hero_weapons(hk):
			if raw.has(k):
				rows.append({"key": k, "hero": String(D.WEAPONS[k].hero), "lvl": D.weapon_level(k), "mode": String(D.WEAPONS[k].mode),
					"el": String(D.WEAPONS[k].element), "single": raw[k].single, "group": raw[k].group})
	_write_tables(rows, fams)
	_write_companions()
	print("DPS fertig: %d Waffen in der Tabelle, %d s" % [rows.size(), int((Time.get_ticks_msec() - t0) / 1000)])


func _read_raw() -> Dictionary:
	var out := {}
	var f := FileAccess.open("res://docs/balance/dps_roh.csv", FileAccess.READ)
	if f == null:
		return out
	var head := f.get_csv_line(";")
	while not f.eof_reached():
		var ln := f.get_csv_line(";")
		if ln.size() < 4 or ln[0] == "":
			continue
		if not D.WEAPONS.has(ln[0]):
			continue
		if not out.has(ln[0]):
			out[ln[0]] = {"single": {}, "group": {}}
		out[ln[0]]["single" if ln[2] == "1" else "group"][ln[1]] = float(ln[3])
	return out


func _write_raw(raw: Dictionary, fams: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/balance"))
	var lines := ["waffe;familie;ziele;dps"]
	for k in raw:
		for fam in fams:
			lines.append("%s;%s;1;%.2f" % [k, fam, float(raw[k].single.get(fam, 0.0))])
			lines.append("%s;%s;%d;%.2f" % [k, fam, GROUP, float(raw[k].group.get(fam, 0.0))])
	_save("res://docs/balance/dps_roh.csv", "\n".join(lines) + "\n")


## Mittlerer Schaden je Sekunde einer Waffe gegen n Gegner (Masse-Art der Familie), Held Jona auf der Stufe der Waffe.
func _measure(k: String, fam: String, n: int) -> float:
	var h = w.horde
	h.clear()
	hero.arsenal.clear()
	w.wave_idx = 0                          # die Übungsflut darf während der Messung nicht enden
	w._idle_t = 0.0
	w.break_left = 0.0
	for tw in w.towers.duplicate():
		if is_instance_valid(tw) and tw.life > 0.0:
			tw.life = 0.01
	await T._wait(0.05)
	var lv := D.weapon_level(k)
	P.d.heroes.jona.level = lv
	hero.refresh_stats()
	hero.global_position = Vector3(A.x, 0, A.y)
	hero.alive = true
	hero.hp = hero.max_hp
	hero.dash_t = 0.0
	hero.speed_k = 1.0
	hero.test_wish = Vector2.ZERO
	var it: Dictionary = P.make_item("weapon", k, 0)
	hero.set_weapon(it)
	var et := -1
	for i in D.family_enemies(fam):
		if String(D.ENEMIES[i].role) == "mass":
			et = i
			break
	if et < 0:
		et = int(D.family_enemies(fam)[0])
	var wr := float(D.WEAPONS[k].range)
	var dist := clampf(wr * 0.6, 1.8, 7.0)
	var c := A + Vector2(0, dist)
	var spots: Array = [c]
	if n > 1:
		spots.clear()
		for i in n:
			spots.append(c + Vector2.from_angle(TAU * i / n) * (1.3 if i > 0 else 0.0) + Vector2(0, 0.4 * (i % 2)))
	var dummies: Array = []
	for sp in spots:
		var e = h.spawn(et, sp, 5000.0 / maxf(float(D.ENEMIES[et].hp), 1.0), 0.0, 0.0)
		e.root = 999.0
		e.aggro = false
		dummies.append(e)
	var t := 0.0
	await T._wait(0.25)
	var hp0 := 0.0
	for e in dummies:
		hp0 += maxf(0.0, e.hp)
	while t < MEASURE_T:
		await T._wait(0.25)
		t += 0.25
		for i in dummies.size():               # Rückstoß und Sog zurücknehmen: alle bleiben an ihrem Platz
			var e = dummies[i]
			if e.st != 2:
				e.p = spots[i]
		hero.global_position = Vector3(A.x, 0, A.y)
		hero.hp = hero.max_hp
	var hp1 := 0.0
	for e in dummies:
		hp1 += maxf(0.0, e.hp) if e.st != 2 else 0.0
	return (hp0 - hp1) / MEASURE_T


## Klasse für den Vergleich: Einzelziel, Fläche oder Geschütz.
static func weapon_class(k: String) -> String:
	var wd: Dictionary = D.WEAPONS[k]
	var m := String(wd.mode)
	if m == "turret":
		return "Geschütz"
	if float(wd.get("splash", 0.0)) > 0.0 or m in ["cone", "nova", "slam", "mine", "seek", "chain", "multi"] or wd.has("cluster") or int(wd.get("pierce", 0)) >= 3 or wd.get("ret", false) or int(wd.get("bounce", 0)) > 0:
		return "Fläche"
	return "Einzelziel"


static func band(lv: int) -> String:
	if lv <= 10:
		return "1-10"
	if lv <= 20:
		return "11-20"
	if lv <= 30:
		return "21-30"
	return "31-40"


func _write_tables(rows: Array, fams: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/balance"))
	# Kennzahl: Mittel über alle Familien aus Einzelziel-DPS und Gruppen-DPS je 3 Ziele, geteilt durch den Richtwert der Stufe
	var groups := {}
	for r in rows:
		var s := 0.0
		var g := 0.0
		for fam in fams:
			s += float(r.single[fam])
			g += float(r.group[fam])
		s /= fams.size()
		g /= fams.size()
		r["s_avg"] = s
		r["g_avg"] = g
		r["score"] = (0.5 * s + 0.5 * g / 3.0) / D.weapon_power_ref(int(r.lvl))
		r["cls"] = weapon_class(String(r.key))
		var gk := "%s|%s" % [band(int(r.lvl)), String(r.cls)]
		if not groups.has(gk):
			groups[gk] = []
		groups[gk].append(float(r.score))
	var mean := {}
	for gk in groups:
		var sum := 0.0
		for v in groups[gk]:
			sum += float(v)
		mean[gk] = sum / maxf(1.0, (groups[gk] as Array).size())
	var csv := ["waffe;held;stufe;klasse;schussart;element;" + ";".join(fams.map(func(f): return "einzel_" + f)) + ";" + ";".join(fams.map(func(f): return "gruppe_" + f)) + ";kennzahl;mittel_klasse;abweichung_%"]
	var md := ["# Waffen-Balance – gemessener Schaden je Sekunde", "",
		"Erzeugt mit `godot --headless --path . -- --autotest=dps` (src/tests_helden.gd). Jona trägt jede Waffe (gewöhnlich, Stufe 1)",
		"auf der Heldenstufe, ab der die Waffe nutzbar ist, ohne Talente, Ausrüstung und Module. Ziele: die Masse-Art jeder Familie,",
		"festgehalten an ihrem Platz, %.0f Sekunden Messzeit (Nachladen eingerechnet). **Einzel** = ein Ziel, **Gruppe** = %d Ziele dicht beieinander." % [MEASURE_T, GROUP],
		"Schwächen und Resistenzen der Familien, Brennen, Gift, Flächen und Geschütze wirken wie im Spiel.", "",
		"**Kennzahl** = (½ · Einzel-DPS + ½ · Gruppen-DPS ÷ 3) ÷ Richtwert der Stufe (D.weapon_power_ref), Mittel über alle Familien.",
		"Verglichen wird mit dem Mittel derselben Stufen-Spanne und Klasse (Einzelziel / Fläche / Geschütz); **Ausreißer** liegen mehr als ±35 % daneben.", ""]
	var out_n := 0
	var lines_out: Array = []
	for r in rows:
		var gk := "%s|%s" % [band(int(r.lvl)), String(r.cls)]
		var dev := (float(r.score) / maxf(float(mean[gk]), 0.001) - 1.0) * 100.0
		r["dev"] = dev
		var cells: Array = [String(r.key), String(r.hero), str(r.lvl), String(r.cls), String(r.mode), String(r.el)]
		for fam in fams:
			cells.append("%.1f" % float(r.single[fam]))
		for fam in fams:
			cells.append("%.1f" % float(r.group[fam]))
		cells.append_array(["%.2f" % float(r.score), "%.2f" % float(mean[gk]), "%.0f" % dev])
		csv.append(";".join(cells))
		if absf(dev) > 35.0 and String(r.cls) != "Geschütz":
			out_n += 1
			lines_out.append("| %s (%s) | %s | %d | %s | %+.0f %% |" % [String(D.WEAPONS[r.key].name), String(r.key), String(r.hero), int(r.lvl), String(r.cls), dev])
	md.append("## Ausreißer (%d)" % out_n)
	md.append("")
	if lines_out.is_empty():
		md.append("Keine Waffe liegt mehr als 35 % neben dem Mittel ihrer Stufe und Klasse.")
	else:
		md.append("| Waffe | Held | Stufe | Klasse | Abweichung |")
		md.append("|---|---|---|---|---|")
		md.append_array(lines_out)
	md.append("")
	md.append("## Alle Waffen (Mittel über die Familien)")
	md.append("")
	var head := "| Waffe | Held | Stufe | Klasse | Element |"
	var sepl := "|---|---|---|---|---|"
	for fam in fams:
		head += " %s |" % String(D.FAMILIES[fam].name).split(" ")[0]
		sepl += "---|"
	head += " Gruppe Ø | Kennzahl | Abw. |"
	sepl += "---|---|---|"
	md.append("Spalten je Familie: Einzel-DPS. Gruppe Ø = Gruppen-DPS (alle %d Ziele zusammen) im Mittel über die Familien." % GROUP)
	md.append("")
	md.append(head)
	md.append(sepl)
	for r in rows:
		var ln := "| %s | %s | %d | %s | %s |" % [String(D.WEAPONS[r.key].name), String(r.hero), int(r.lvl), String(r.cls), String(D.ELEMENT_NAME.get(r.el, r.el))]
		for fam in fams:
			ln += " %.0f |" % float(r.single[fam])
		ln += " %.0f | %.2f | %+.0f %% |" % [float(r.g_avg), float(r.score), float(r.dev)]
		md.append(ln)
	_save("res://docs/balance/waffen.csv", "\n".join(csv) + "\n")
	_save("res://docs/balance/waffen_messung.md", "\n".join(md) + "\n")
	print("DPS Ausreißer: %d" % out_n)


func _write_companions() -> void:
	## Begleiter: Nutzwert je Stufe 1 und 10 (Tragkraft, Leben, Tempo, Kampf, Besonderheit) – kein Kampf außer dem Golem.
	var md := ["# Begleiter – Kennzahlen", "", "Erzeugt mit `--autotest=dps` (src/tests_helden.gd) aus src/companion_data.gd.",
		"Tragkraft in Gewichtseinheiten (Rucksack 220), Kampf = Schaden je Sekunde des Golems (wächst mit der Stufe wie alle Fähigkeiten).", "",
		"| Begleiter | Tragkraft St. 1 / 10 | Leben St. 1 / 10 | Tempo m/s | Besonderheit | Bekommen |", "|---|---|---|---|---|---|"]
	var csv := ["begleiter;tragkraft1;tragkraft10;leben1;leben10;tempo;faehigkeiten"]
	for ck in CD.ORDER:
		var c: Dictionary = CD.COMPANIONS[ck]
		var c1 := float(c.carry)
		var c10 := c1 * (1.0 + CD.CARRY_PER_LEVEL * 9)
		var h1 := float(c.hp)
		var h10 := h1 * (1.0 + CD.HP_PER_LEVEL * 9)
		var ab: Array = []
		for a in c.abil:
			ab.append("%s %s" % [String(CD.ABIL[a][0]) if CD.ABIL.has(a) else String(a), str(c.abil[a])])
		var gets: Array = []
		for g in c.get:
			gets.append(String(g))
		md.append("| %s | %d / %d | %d / %d | %.1f | %s | %s |" % [String(c.name), int(c1), int(c10), int(h1), int(h10), float(c.speed), ", ".join(ab), ", ".join(gets)])
		csv.append("%s;%d;%d;%d;%d;%.1f;%s" % [ck, int(c1), int(c10), int(h1), int(h10), float(c.speed), ", ".join(ab)])
	_save("res://docs/balance/begleiter.csv", "\n".join(csv) + "\n")
	_save("res://docs/balance/begleiter_kennzahlen.md", "\n".join(md) + "\n")


func _save(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(text)
