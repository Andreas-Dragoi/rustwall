extends RefCounted
## Prüfungen für V6 Paket M (Spielmodi): Daten der 50 Stockwerke, Modelle und Töne, Sterne/Belohnungen/Wochenwertung,
## Kampfwelt Turm (Bot auf den ersten Stockwerken, Zusätze Nur Nahkampf / Ohne Fähigkeiten / Generator), Überleben
## (Wellen, Verstärkungswahl, Punkte, Ende), Clan-Raid in der Weltboss-Kampfwelt (Schaden, Fortschritt, Stufen),
## Höhlen (Eingänge, Höhle betreten, Truhe, Erz, Rückweg, Abbruch über das Hauptmenü), Ladefläche der Pritsche
## (umladen, sichtbare Ladung, am Depot abladen), Bildschirm „Modi“, Server (Testserver: Ranglisten, Raid).
##
## Aufruf aus tests.gd (--selftest) oder allein:
##   --autotest=modi                         alle Prüfungen
##   --autotest=turm --floor=1-3             Bot spielt diese Stockwerke (RESULT-Zeile)
##   --autotest=ueberleben --waves=8         Bot spielt Überleben bis zu dieser Welle oder bis zum Fall (RESULT-Zeile)
##   --autotest=hoehle --area=1              Bot geht in eine Höhle, holt Truhe und Erz und kommt zurück (RESULT-Zeile)

const D = preload("res://src/data.gd")
const DM = preload("res://src/data_modi.gd")
const DL = preload("res://src/data_liveops.gd")
const Modi = preload("res://src/modi.gd")
const ModiUI = preload("res://src/modi_ui.gd")
const LO = preload("res://src/liveops.gd")
const Models = preload("res://src/models.gd")
var PORT: int = 8212 + 2 * (absi(ProjectSettings.globalize_path("res://").hash()) % 300)   # je Arbeitskopie ein eigener Port

var T: Node


func _init(tests: Node) -> void:
	T = tests


func run() -> void:
	_data()
	_rules()
	await _tower_world()
	await _surv_world()
	await _raid()
	await _caves()
	await _bed()
	await _screens()
	await _net()
	_fresh()
	G.main.goto_base()
	await T._wait(0.3)


func _fresh() -> void:
	P.new_game()
	P.no_save = true
	P._ensure_fields()
	LO.force_event = ""
	G.test_args.erase("caves")


func _hero_level(lv: int) -> void:
	var hk := String(P.d.hero_sel)
	P.d.heroes[hk].level = lv


# ---------------------------------------------------------------- Daten, Modelle, Töne
func _data() -> void:
	T._check(DM.FLOORS.size() == DM.TOWER_FLOORS and DM.TOWER_FLOORS == 50, "M: 50 Stockwerke (%d)" % DM.FLOORS.size())
	var tasks := {}
	var roles := ["mass", "fast", "tank", "ranged", "air", "special", "healer", "shield", "brood", "miniboss", "elite"]
	for f in range(1, DM.TOWER_FLOORS + 1):
		var fd: Dictionary = DM.FLOORS[f - 1]
		var t := String(fd.task)
		tasks[t] = true
		T._check(String(fd.name) != "" and D.FAMILIES.has(String(fd.fam)), "M: Stockwerk %d hat Namen und Familie" % f)
		if t == "survive":
			T._check(float(fd.t) > 0.0 and float(fd.rate) > 0.0 and int(fd.max) > 0 and not (fd.spawn as Array).is_empty(), "M: Stockwerk %d: Überleben-Angaben" % f)
		else:
			T._check(not (fd.waves as Array).is_empty() and float(fd.par) > 0.0, "M: Stockwerk %d: Wellen und Zielzeit" % f)
			for w in fd.waves:
				for ent in w:
					T._check(String(ent[0]) in roles and int(ent[1]) > 0 and (ent.size() < 3 or D.FAMILIES.has(String(ent[2]))), "M: Stockwerk %d: Eintrag %s" % [f, str(ent)])
		if t == "boss":
			T._check(f % 10 == 0 and D.AREA_BOSS.has(String(fd.boss)), "M: Bossstockwerk %d mit Gebietsboss" % f)
		if t == "timed":
			T._check(float(fd.t) > 0.0, "M: Stockwerk %d: Zeitlimit" % f)
		T._check(Modi.floor_text(f) != "" and Modi.star_rules(f).size() == 3, "M: Stockwerk %d: Aufgabentext und Sternregeln" % f)
	for t in ["clear", "survive", "defend", "timed", "boss"]:
		T._check(tasks.has(t), "M: Aufgabe %s kommt vor" % t)
	for f in [10, 20, 30, 40, 50]:
		T._check(String(DM.FLOORS[f - 1].task) == "boss", "M: Stockwerk %d ist ein Bossstockwerk" % f)
	var mods := {}
	for fd in DM.FLOORS:
		for mk in fd.get("mods", []):
			mods[mk] = true
	for mk in ["noskill", "melee", "noheal", "fast"]:
		T._check(mods.has(mk), "M: Zusatz %s kommt vor" % mk)
	for b in 5:
		for k in ["mt_floor_%d", "mt_wall_%d", "mt_pillar_%d"]:
			T._check(Models.has_glb(k % (b + 1)), "M: Modell %s" % (k % (b + 1)))
	for k in ["mt_gate", "mt_generator", "sv_barrier", "sv_crates", "sv_wreck", "sv_container", "sv_sandbags", "sv_tower", "sv_fence", "sv_gate", "sv_lamp", "cv_torch", "cv_exit", "v_pickup_rack"]:
		T._check(Models.has_glb(k), "M: Modell %s" % k)
	T._check(DM.CAVE_THEMES.size() >= 3, "M: mindestens 3 Höhlen-Themen")
	for t in DM.CAVE_THEMES:
		for k in ["floor", "hall", "wall_1", "wall_2", "rock", "deco_1", "deco_2", "entry", "ore"]:
			T._check(Models.has_glb("cv_%s_%s" % [t, k]), "M: Höhlen-Baustein cv_%s_%s" % [t, k])
	for a in D.AREAS:
		T._check(DM.CAVE_THEMES.has(String(DM.CAVE_THEME.get(String(a.key), ""))), "M: Gebiet %s hat ein Höhlen-Thema" % String(a.key))
	for k in ["ui_tower", "ui_survival", "ui_raid", "ui_cave"]:
		T._check(ResourceLoader.exists("res://icons/%s.png" % k), "M: Symbol %s" % k)
	for s in ["gen_down", "tower_start", "tower_clear", "surv_start", "surv_end", "upgrade_offer", "upgrade_pick", "raid_tier", "cave_enter", "cave_exit",
			"cave_chest", "cave_ore", "amb_cave", "bed_load", "bed_unload"]:
		T._check(Sfx.has(s), "M: Ton %s" % s)
	T._check(DM.UPGRADE_ORDER.size() >= 10 and DM.UPGRADE_ORDER.size() == DM.UPGRADES.size(), "M: Verstärkungen (%d)" % DM.UPGRADES.size())
	for k in DM.UPGRADE_ORDER:
		T._check(UIpic(String(DM.UPGRADES[k].icon)), "M: Bild der Verstärkung %s" % k)
	T._check(DM.surv_hp(10) > DM.surv_hp(1) and DM.surv_count(10) > DM.surv_count(1) and DM.surv_fam(6) != DM.surv_fam(1), "M: Überleben wird stärker und wechselt die Familie")


func UIpic(n: String) -> bool:
	return ResourceLoader.exists("res://icons/%s.png" % n)


# ---------------------------------------------------------------- Regeln ohne Welt
func _rules() -> void:
	_fresh()
	T._check(Modi.floor_unlocked(1) and not Modi.floor_unlocked(2), "M: nur Stockwerk 1 ist offen")
	T._check(Modi.calc_stars(1, true, 20.0, 0.9) == 3 and Modi.calc_stars(1, true, 200.0, 0.9) == 2 and Modi.calc_stars(1, true, 200.0, 0.2) == 1 and Modi.calc_stars(1, false, 10.0, 1.0) == 0, "M: Sterne nach Zeit und Leben")
	T._check(Modi.calc_stars(2, true, 999.0, 0.85) == 3 and Modi.calc_stars(2, true, 10.0, 0.6) == 2, "M: Sterne beim Überleben nach Leben")
	var c0 := P.res("coins")
	var r := Modi.tower_finish(1, true, 25.0, 0.95)
	T._check(int(r.stars) == 3 and bool(r.first) and P.res("coins") > c0 and Modi.floor_unlocked(2) and Modi.best_floor() == 1, "M: erstes Stockwerk: 3 Sterne, Belohnung, nächstes offen")
	var c1 := P.res("coins")
	var r2 := Modi.tower_finish(1, true, 40.0, 0.95)
	T._check(not bool(r2.first) and P.res("coins") == c1 and Modi.floor_stars(1) == 3, "M: zweiter Lauf: keine zweite Belohnung, Sterne bleiben")
	T._check(Modi.tower_week_score() == DM.floor_points(1, 3), "M: Wochenwertung zählt den besten Lauf je Stockwerk")
	Modi.tower_finish(2, false, 10.0, 0.0)
	T._check(Modi.floor_stars(2) == 0 and not Modi.floor_unlocked(3), "M: verlorener Lauf schaltet nichts frei")
	for f in range(2, 8):
		Modi.tower_finish(f, true, 999.0, 0.6)
	T._check(Modi.total_stars() == 3 + 6 * 2 and Modi.star_reward_ready(0) == (Modi.total_stars() >= int(DM.STAR_REWARDS[0][0])), "M: Sterne zählen zusammen")
	var gems0 := P.res("gems")
	Modi.tower_finish(8, true, 10.0, 1.0)
	Modi.tower_finish(9, true, 10.0, 1.0)
	T._check(Modi.total_stars() >= 20 and Modi.claim_star_reward(0) == "" and P.res("gems") > gems0 and Modi.claim_star_reward(0) != "", "M: Sternstufe einmal abholen")
	# Rangliste (simuliert)
	var b := Modi.board("tower")
	T._check(b.size() == 30 and Modi.my_rank("tower") >= 1 and Modi.my_rank("tower") <= 30, "M: Turm-Rangliste simuliert (%d Einträge, Platz %d)" % [b.size(), Modi.my_rank("tower")])
	# Wochenwechsel setzt die Wochenwertung zurück
	Modi.tower().week = Modi.week() - 1
	T._check(Modi.tower_week_score() == 0 and Modi.floor_stars(1) == 3, "M: neue Woche: Wertung leer, Sterne bleiben")
	# Überleben
	var c2 := P.res("coins")
	var s := Modi.surv_finish(4000, 11, 120)
	T._check(int(Modi.surv().best) == 4000 and int(Modi.surv().best_wave) == 11 and int(s.coins) == 1000 and (s.rewards as Array).size() == 2, "M: Überleben: Bestwert, Münzen, Wellen-Belohnungen 5 und 10 (%d, %s)" % [int(s.coins), str(s.rewards)])
	var s2 := Modi.surv_finish(1000, 3, 10)
	T._check(int(Modi.surv().best) == 4000 and not bool(s2.record) and (s2.rewards as Array).is_empty(), "M: schwächerer Lauf ändert den Bestwert nicht")
	T._check(Modi.board("surv").size() == 30, "M: Überleben-Rangliste simuliert")
	# Höhlen-Thema je Gebiet
	T._check(Modi.cave_theme(1) == "wurzel" and Modi.cave_theme(2) == "sand" and Modi.cave_theme(5) == "eis" and Modi.cave_theme(7) == "glut", "M: Höhlen-Themen je Gebiet")


# ---------------------------------------------------------------- Turm in der Welt
func _wait_end(max_s: float) -> bool:
	var w = G.main.world
	var t := 0.0
	while t < max_s:
		await T._wait(0.25)
		t += 0.25
		if G.main.world != w or w.ended:
			return true
	return false


func _tower_world() -> void:
	_fresh()
	_hero_level(12)
	G.main.goto_base()
	await T._wait(0.4)
	# Stockwerk 1 mit dem Bot
	var at := G.autotest
	var lim := G.arg("limit", "")
	G.test_args["limit"] = str(int(T._t) + 3000)          # der Bot läuft über G.autotest – die Zeitgrenze der Tests verschieben
	G.autotest = "turm"
	await ModiUI.start_tower(1)
	await T._wait(0.3)
	var w = G.main.world
	T._check(w.get("kind") == "tower" and w.mode == "practice" and w.spawn_pts.size() == 4 and w.get_node_or_null("Generator") == null, "M: Turm-Arena mit vier Toren")
	T._check(w.field.is_solid(Vector2(0, DM.TOWER_RADIUS + 2.0)) and not w.field.is_solid(Vector2(0, 5)), "M: Arena-Rand ist fest, Mitte frei")
	var ok: bool = await _wait_end(240.0)
	T._check(ok and w.ended and bool(w.result.get("win", false)), "M: Bot schafft Stockwerk 1 (t=%.0f s, Gegner übrig %d)" % [float(w.t_run), int(w.enemies_left())])
	T._check(Modi.floor_stars(1) >= 1 and w.result.get("tower") is Dictionary, "M: Sterne für Stockwerk 1 eingetragen (%d)" % Modi.floor_stars(1))
	await T._wait(0.3)
	T._check(G.main.hud.modal_open(), "M: Ergebnisfenster offen")
	G.main.hud._close_modal()
	# Stockwerk 5: Generator verteidigen
	await ModiUI.start_tower(5)
	await T._wait(0.4)
	w = G.main.world
	T._check(w.gen != null and w.goal_structure == w.gen and w.bunker_node == w.gen, "M: Stockwerk 5 hat einen Generator als Ziel")
	await T._wait(3.5)
	w.gen.hurt(w.gen.max_hp * 2.0)
	await T._wait(0.6)
	T._check(w.ended and not bool(w.result.get("win", true)), "M: zerstörter Generator = Prüfung verloren")
	G.main.hud._close_modal()
	# Stockwerk 6: Nur Nahkampf
	G.autotest = at
	if lim == "":
		G.test_args.erase("limit")
	else:
		G.test_args["limit"] = lim
	await ModiUI.start_tower(6)
	await T._wait(0.3)
	w = G.main.world
	await T._wait(6.0)
	var far_inv := false
	var near_ok := true
	var pp: Vector2 = w.hero.pos2()
	for e in w.horde.list:
		if e.st != 2:
			if e.p.distance_to(pp) > DM.TOWER_MELEE_R + 0.5 and e.inv > 0.0:
				far_inv = true
			if e.p.distance_to(pp) < DM.TOWER_MELEE_R - 0.5 and e.inv > 0.0:
				near_ok = false
	T._check(w.mods.has("melee") and far_inv and near_ok, "M: Nur Nahkampf: ferne Gegner unverwundbar")
	# Stockwerk 9: Ohne Fähigkeiten
	await ModiUI.start_tower(9)
	await T._wait(0.4)
	w = G.main.world
	T._check(w.mods.has("noskill") and bool(w.hero.skills.slots[0].locked) and not w.hero.skills.use(0), "M: Ohne Fähigkeiten: Fähigkeiten gesperrt")
	# Stockwerk 34: Ohne Heilung
	await ModiUI.start_tower(34)
	await T._wait(0.3)
	w = G.main.world
	T._check(LO.nm_noheal and w.hero.hp < w.hero.max_hp * 0.7, "M: Ohne Heilung: weniger Leben, keine Heilung")
	G.main.goto_base()
	await T._wait(0.3)
	T._check(not LO.nm_noheal, "M: Ohne Heilung endet mit der Prüfung")
	# Held fällt = verloren
	await ModiUI.start_tower(2)
	await T._wait(0.4)
	w = G.main.world
	w.hero.hurt(1.0e7)
	await T._wait(0.5)
	T._check(w.ended and not bool(w.result.get("win", true)), "M: gefallener Held = Prüfung verloren")
	G.main.hud._close_modal()
	G.main.goto_base()
	await T._wait(0.3)


# ---------------------------------------------------------------- Überleben in der Welt
func _surv_world() -> void:
	_fresh()
	_hero_level(15)
	G.main.goto_base()
	await T._wait(0.3)
	await ModiUI.start_surv()
	await T._wait(0.5)
	var w = G.main.world
	T._check(w.get("kind") == "surv" and w.spawn_pts.size() == 4, "M: Schrottplatz mit vier Toren")
	T._check(w.field.is_solid(Vector2(-14, -10)) and w.field.is_solid(Vector2(-14, -12)) and not w.field.is_solid(Vector2(0, 0)), "M: Deckung ist fest (Container)")
	await T._wait(3.0)
	T._check(w.started and w.wave_idx == 1 and w.enemies_left() > 0, "M: Welle 1 läuft (%d Gegner)" % int(w.enemies_left()))
	# bis Welle 5 vorspulen: alles besiegen
	for k in 20:
		w._queue.clear()
		for e in w.horde.list:
			if e.st != 2:
				w.horde.damage(e, 1.0e7, Vector2.ZERO, true)
		await T._wait(0.4)
		if w._pick_open:
			break
		if w.break_left > 0.0:
			w.break_left = 0.01
			await T._wait(0.2)
	T._check(w._pick_open and w.wave_idx == DM.SURV_PICK_EVERY and G.main.hud.modal_open() and T.get_tree().paused, "M: nach Welle 5: Wahl aus drei Verstärkungen (Welle %d)" % int(w.wave_idx))
	T._check(w._pick_opts.size() == 3, "M: drei Angebote")
	var dmg0: float = w.hero.dmg
	w.pick("wucht")
	await T._wait(0.2)
	T._check(not T.get_tree().paused and int(w.buffs.get("wucht", 0)) == 1 and w.hero.dmg > dmg0 * 1.15, "M: Verstärkung Wucht wirkt (%.1f -> %.1f)" % [dmg0, float(w.hero.dmg)])
	w.pick("leben")
	T._check(w.lives == 1, "M: Zweites Leben gibt einen Wiedereinstieg")
	var sc: int = w.score
	T._check(sc > 0, "M: Punkte gesammelt (%d)" % sc)
	w.hero.hurt(1.0e7)
	await T._wait(0.4)
	T._check(not w.ended and w.lives == 0, "M: Wiedereinstieg statt Ende")
	await T._wait(4.0)
	w.hero.invuln = 0.0
	w.hero.hurt(1.0e7)
	await T._wait(0.5)
	T._check(w.ended and w.result.get("surv") is Dictionary and int(Modi.surv().best) >= sc, "M: Lauf endet, Bestwert gespeichert (%d)" % int(Modi.surv().best))
	G.main.hud._close_modal()
	G.main.goto_base()
	await T._wait(0.3)


# ---------------------------------------------------------------- Clan-Raid
func _raid() -> void:
	_fresh()
	P.debug_setup(4)
	P.d.level = 20
	T._check(Modi.can_raid() != "" and not Modi.has_clan(), "M: ohne Clan kein Raid")
	P.social.join_clan(P.social.clan_list()[0])
	T._check(Modi.has_clan() and Modi.raid_hp() == (P.social.s.clan.members.size() + 1) * DM.RAID_HP_PER_MEMBER, "M: Leben des Leviathans nach Clangröße")
	T._check(Modi.raid_members().size() == P.social.s.clan.members.size() + 1, "M: alle Mitglieder in der Liste")
	G.main.goto_base()
	await T._wait(0.6)
	var w = G.main.world
	var tot0 := Modi.raid_total()
	T._check(Modi.start_raid() == "", "M: Clan-Angriff startet")
	await T._wait(0.2)
	var b = w.horde.boss
	T._check(b != null and int(b.t) == int(D.ENEMY_INDEX["boss_leviathan"]) and String(w.flood.get("raid_kind", "")) == "clan", "M: gemeinsame Kampfwelt mit dem Leviathan")
	if b != null:
		b.inv = 0.0
		w.horde.damage(b, 9000.0, Vector2.ZERO, true)
	await T._wait(0.2)
	w.set_meta("raid_t", DL.BOSS_TIME - 0.05)
	await T._wait(0.6)
	T._check(w.ended and bool(w.result.get("clan_raid", false)) and int(Modi.raid().dmg) >= 8000, "M: Clan-Angriff endet, Schaden zählt im Clan (%d)" % int(Modi.raid().dmg))
	T._check(Modi.raid_tries_left() == DM.RAID_TRIES - 1 and Modi.raid_total() >= tot0 + 8000, "M: ein Angriff verbraucht, Gesamtschaden steigt")
	T._check(int(LO.boss_state().dmg) == 0, "M: Clan-Raid zählt nicht für den Weltboss")
	await T._wait(0.3)
	G.main.hud._leave_result("")
	T.get_tree().paused = false
	await T._wait(0.3)
	# Stufen abholen (Leben künstlich erreicht)
	Modi.raid().dmg = Modi.raid_hp()
	var gems0 := P.res("gems")
	var claimed := 0
	for i in DM.RAID_TIERS.size():
		if Modi.raid_claim(i) == "":
			claimed += 1
	T._check(claimed == DM.RAID_TIERS.size() and P.res("gems") > gems0 and Modi.raid_open() == 0, "M: alle Belohnungsstufen abgeholt")
	T._check(Modi.can_raid() != "", "M: besiegter Leviathan: kein weiterer Angriff")
	Modi.raid().week = Modi.week() - 1
	T._check(int(Modi.raid().dmg) == 0 and Modi.raid().claimed.is_empty(), "M: neue Woche, neuer Leviathan")
	Modi.raid().tries = DM.RAID_TRIES
	T._check(Modi.raid_tries_left() == 0 and Modi.can_raid() != "", "M: drei Angriffe je Tag")
	P.social.leave_clan()
	G.main.goto_base()
	await T._wait(0.3)


# ---------------------------------------------------------------- Höhlen
func _caves() -> void:
	_fresh()
	P.debug_setup(4)
	_hero_level(20)
	G.test_args["caves"] = "2"
	G.main.goto_base()
	await T._wait(0.3)
	G.main.start_expedition(1, "expedition", 0)
	await T._wait(1.2)
	var ex = G.main.world
	var mx = ex.get_node_or_null("ModiExp")
	T._check(mx != null and mx.caves.size() == 2, "M: zwei Höhleneingänge im Kiefernforst (%d)" % (mx.caves.size() if mx else -1))
	if mx == null or mx.caves.is_empty():
		return
	var c: Dictionary = mx.caves[0]
	T._check(c.n != null and not ex.field.blocks_player(c.p) and ex.field.is_solid(c.c), "M: Eingang begehbar, Hügel fest")
	var mp: Array = ex.map_points()
	var on_map := false
	for q in mp:
		if String(q[1]) == "chest" and (q[0] as Vector2).distance_to(c.p) < 0.1:
			on_map = true
	ex.hero.dismount()
	ex.add_pack("wood", 30.0)
	var wood0 := float(ex.loot.get("wood", 0.0))
	var coins0: int = ex.field_coins()
	var kills0: int = ex.horde.kills
	# Der Expeditions-Bot lenkt den Helden weiter – im Eingang festhalten, bis die Höhle geladen ist
	var hold := 0.0
	while G.main.world == ex and hold < DM.CAVE_ENTER_HOLD + 3.0:
		ex.hero.global_position = Vector3(c.p.x, 0, c.p.y)
		await T._wait(0.1)
		hold += 0.1
	var cw = G.main.world
	T._check(cw != ex and cw.mode == "exp" and cw.has_method("swap_out") and ex.get_parent() == null, "M: Höhle betreten, Expedition ruht")
	if not cw.has_method("swap_out"):
		return
	T._check(on_map or ex._seen(c.p), "M: Höhle auf der Übersichtskarte")
	T._check(cw.rooms.size() >= int(DM.CAVE_ROOMS[0]) and cw.horde.alive >= cw.rooms.size() - 1, "M: Höhle mit %d Räumen und %d Wächtern" % [cw.rooms.size(), int(cw.horde.alive)])
	T._check(G.game == cw and G.main.hud.world == cw and float(cw.loot.get("wood", 0.0)) == wood0, "M: Rucksack der Expedition gilt in der Höhle")
	T._check(not cw.field.is_solid(cw.exit_p) and not cw.field.is_solid(cw.chest_p + Vector2(0, 1.5)), "M: Wege in der Höhle frei")
	cw.hero.invuln = 1.0e6                                # die Wächter dürfen den Ablauf nicht stören (Tod/Wiedereinstieg: eigener Test)
	# Truhe
	cw.hero.global_position = Vector3(cw.chest_p.x, 0, cw.chest_p.y + 1.2)
	await T._wait(0.4)
	T._check(cw.chest_open and ex.field_coins() > coins0, "M: Truhe geöffnet, Feldmünzen")
	# Erz
	var ore_key := String(cw.tdef.ore.keys()[0])
	var ore0 := float(ex.loot.get(ore_key, 0.0))
	var q: Vector2 = cw.ore_p + (cw.chest_p - cw.ore_p).normalized() * 1.8
	cw.hero.global_position = Vector3(q.x, 0, q.y)
	cw.hero.test_wish = Vector2.ZERO
	await T._wait(DM.CAVE_ORE_TIME + 1.0)
	T._check(float(ex.loot.get(ore_key, 0.0)) > ore0, "M: Erz abgebaut (%s %.0f)" % [ore_key, float(ex.loot.get(ore_key, 0.0))])
	cw.hero.test_wish = null
	# Wächter besiegen (Zähler)
	for e in cw.horde.list:
		if e.st != 2:
			cw.horde.damage(e, 1.0e7, Vector2.ZERO, true)
			break
	await T._wait(0.2)
	# Rückweg
	cw.hero.global_position = Vector3(cw.exit_p.x, 0, cw.exit_p.y + 3.0)
	await T._wait(0.3)
	cw.hero.global_position = Vector3(cw.exit_p.x, 0, cw.exit_p.y)
	cw.hero.test_wish = Vector2.ZERO
	await T._wait(1.6)
	if is_instance_valid(cw) and cw.hero != null:
		cw.hero.test_wish = null
	T._check(G.main.world == ex and ex.get_parent() == G.main and G.game == ex and G.player == ex.hero, "M: zurück in der Expedition")
	T._check(bool(mx.caves[0].done) and int(Modi.st().caves.done) >= 1, "M: Höhle erkundet")
	T._check(ex.horde.kills > kills0 and ex.hero.pos2().distance_to(c.p) < 5.0, "M: Gegner zählen zur Expedition, Held am Eingang")
	T._check(ex.running and not ex.ended and float(ex.loot.get(ore_key, 0.0)) > ore0, "M: Expedition läuft weiter, Beute bleibt im Rucksack")
	await T._wait(0.5)
	# zweite Höhle betreten und über das Hauptmenü verlassen (Expedition wird verworfen, kein Absturz)
	var c2: Dictionary = mx.caves[1]
	mx.enter_cave(1)
	await T._wait(0.5)
	T._check(G.main.world != ex, "M: zweite Höhle betreten")
	var cw2 = G.main.world
	if cw2.has_method("swap_out"):
		var rl := int(ex.respawns_left)
		cw2.hero.invuln = 0.0
		cw2.hero.hurt(1.0e7)
		await T._wait(0.2)
		T._check(not cw2.hero.alive and int(ex.respawns_left) == rl - 1 and G.main.world == cw2, "M: Tod in der Höhle: Wiedereinstieg am Eingang (noch %d×)" % int(ex.respawns_left))
		await T._wait(D.EXP_RESPAWN_TIME + 0.6)
		T._check(cw2.hero.alive and cw2.hero.pos2().distance_to(cw2.exit_p) < 5.0, "M: Held steht wieder am Höhleneingang")
	G.main.goto_base()
	await T._wait(0.6)
	T._check(G.main.world.mode == "peace" and not is_instance_valid(ex) or (is_instance_valid(ex) and ex.is_queued_for_deletion()), "M: Basis nach Abbruch, Expedition aufgeräumt")
	G.test_args.erase("caves")
	if c2.is_empty():
		pass


# ---------------------------------------------------------------- Ladefläche
func _bed() -> void:
	_fresh()
	P.debug_setup(7)
	_hero_level(20)
	P.d.vehicles.pickup.owned = true
	P.d.vehicle_sel = "pickup"
	G.test_args["caves"] = "0"
	G.main.goto_base()
	await T._wait(0.3)
	G.main.start_expedition(2, "expedition", 0)
	await T._wait(1.2)
	var ex = G.main.world
	var mx = ex.get_node_or_null("ModiExp")
	T._check(mx != null and mx.has_bed() and mx._rack != null, "M: Pritsche mit Ladegitter")
	if mx == null or not mx.has_bed():
		G.test_args.erase("caves")
		return
	ex.hero.dismount()
	ex.add_pack("metal", ex.room_for("metal") * 0.8)
	var w0: float = ex.weight
	await T._wait(0.6)
	T._check(not mx.bed.is_empty() and float(ex.weight) < w0 and mx.bed_weight > 0.0, "M: Rucksack auf die Ladefläche umgeladen (%.0f -> %.0f)" % [w0, float(ex.weight)])
	ex.add_pack("wood", ex.room_for("wood"))
	ex.add_pack("stone", ex.room_for("stone"))
	mx.load_bed()
	T._check(mx.bed_weight <= mx.bed_cap + 0.5, "M: Ladefläche nie über ihrer Tragkraft (%.0f / %.0f)" % [mx.bed_weight, mx.bed_cap])
	await T._wait(0.3)
	T._check(mx._cargo_l.get_child_count() + mx._cargo_r.get_child_count() > 0, "M: Ladung auf der Ladefläche sichtbar")
	# Depot bauen und hinfahren
	for k in ["zentrale", "depot"]:
		ex.admin_pay(k)
	await T._wait(1.5)
	var bed_metal := float(mx.bed.get("metal", 0.0))
	var dep0 := float(ex.depot.get("metal", 0.0))
	if ex.outpost.nodes.get("depot") != null:
		ex.hero.mount()
		ex.hero.global_position = Vector3(ex.outpost.depot_pos.x + 2.0, 0, ex.outpost.depot_pos.y + 2.0)
		await T._wait(0.6)
		T._check(mx.bed.is_empty() and float(ex.depot.get("metal", 0.0)) >= dep0 + bed_metal - 0.5, "M: Ladefläche am Depot abgeladen")
	else:
		T._check(false, "M: Depot gebaut")
	# kaputtes Fahrzeug: Ladung fällt herab (weit weg vom Depot)
	ex.hero.mount()
	var far: Vector2 = ex.outpost.C + (ex.outpost.s as Vector2) * 30.0
	ex.hero.global_position = Vector3(far.x, 0, far.y)
	await T._wait(0.2)
	ex.hero.dismount()
	await T._wait(0.2)
	ex.add_pack("metal", ex.room_for("metal") * 0.6)
	ex.hero.global_position = ex.hero.veh_node.global_position + Vector3(1.5, 0, 0)
	await T._wait(0.6)
	var piles0: int = ex.pack.piles.size()
	ex.hero.veh_hp = 0.0
	await T._wait(0.5)
	T._check(mx.bed.is_empty() and ex.pack.piles.size() > piles0, "M: kaputte Pritsche – Ladung liegt am Boden")
	G.test_args.erase("caves")
	G.main.goto_base()
	await T._wait(0.3)


# ---------------------------------------------------------------- Bildschirm
func _screens() -> void:
	_fresh()
	G.main.goto_base()
	await T._wait(0.3)
	var sc = G.main.screens
	for t in 4:
		sc.open("modi", {"tab": t})
		await T._wait(0.15)
		T._check(sc.is_open() and sc.screen == "modi", "M: Bildschirm Modi, Reiter %d" % t)
	sc.open("modi", {"tab": 0, "floor": 12})
	await T._wait(0.15)
	T._check(sc.is_open(), "M: gesperrtes Stockwerk anzeigen")
	sc.close()
	# Menüknopf und Bunker
	var found := false
	for b in G.main.hud.root.find_children("*", "Button", true, false):
		if preload("res://src/ui.gd").btn_get_text(b) == "Modi":
			found = true
	T._check(found, "M: Menüknopf „Modi“ im Kampfbild der Basis")


# ---------------------------------------------------------------- Server (Testserver)
func _net() -> void:
	_fresh()
	P.d.level = 20
	P.social.s = P.d.social
	P.social.ensure()
	var net: Node = P.social.net
	var script := ProjectSettings.globalize_path("res://server/mock_server.py")
	var pid := -1
	for exe in ["python3", "python"]:
		pid = OS.create_process(exe, [script, "--port", str(PORT), "--quit-after", "240"])
		if pid > 0:
			break
	if pid <= 0:
		print("HINWEIS: Server-Prüfungen von Paket M übersprungen (python3 fehlt)")
		return
	var keep: Dictionary = net.cfg.duplicate()
	await _real(1.5)
	net.set_server("http://127.0.0.1:%d" % PORT)
	for i in 100:
		if net.online():
			break
		await _real(0.1)
	T._check(net.online(), "M: mit dem Testserver verbunden")
	if net.online():
		Modi.tower_finish(1, true, 20.0, 1.0)
		var node := Modi.net_node()
		await node.pull()
		var srv: Dictionary = Modi.st().srv
		T._check(srv.get("tower", {}).get("entries") is Array and int(Modi.tower().sent) == Modi.tower_week_score(), "M: Turm-Wochenwert zum Server, Rangliste geholt")
		var b := Modi.board("tower")
		T._check(b.size() >= 1 and bool(b[Modi.my_rank("tower") - 1].me) and int(b[Modi.my_rank("tower") - 1].score) == Modi.tower_week_score(), "M: Rangliste vom Server enthält dich")
		var r: Dictionary = await net.rpc_call("rw_clan_create", {"name": "Prüfturm"})
		T._check(r.ok and bool(r.data.get("ok", false)), "M: Clan am Testserver gegründet")
		await P.social.o.load_clan()
		await node.pull()
		T._check(Modi.has_clan() and Modi.raid_hp() == DM.RAID_HP_PER_MEMBER, "M: Raid-Leben vom Server (1 Mitglied; Clan %s, Leben %d)" % [str(Modi.has_clan()), int(Modi.raid_hp())])
		await node.raid_hit(12345)
		T._check(Modi.raid_total() >= 12345 and int(Modi.st().srv.raid.dmg) == 12345, "M: Raid-Schaden am Server gezählt")
	net.cfg = keep
	net.cfg.url = ""
	net.status = "aus"
	P.server_offset = 0.0
	OS.kill(pid)
	Modi.st().srv = {}
	P.social.s.clan = {}


func _real(sec: float) -> void:
	await T.get_tree().create_timer(sec, true, false, true).timeout


# ================================================================= Bots (--autotest=turm | ueberleben | hoehle)
func autotest(kind: String) -> void:
	match kind:
		"turm":
			await _bot_tower()
		"ueberleben":
			await _bot_surv()
		"hoehle":
			await _bot_cave()


func _bot_tower() -> void:
	_fresh()
	_hero_level(int(G.arg("level", "14")))
	_bot_gear()
	var rg := G.arg("floor", "1-3").split("-")
	var f0 := int(rg[0])
	var f1 := int(rg[1]) if rg.size() > 1 else f0
	var wins := 0
	var stars := 0
	var t0 := Time.get_ticks_msec()
	G.main.goto_base()
	await T._wait(0.3)
	for f in range(f0, f1 + 1):
		for k in range(1, f):
			if Modi.floor_stars(k) == 0:
				Modi.tower().stars[str(k)] = 1                 # Vorgänger als geschafft eintragen
		await ModiUI.start_tower(f)
		await T._wait(0.3)
		var w = G.main.world
		await _wait_end(float(G.arg("max", "300")))
		var win := bool(w.result.get("win", false))
		var st := int(w.result.get("tower", {}).get("stars", 0))
		if win:
			wins += 1
			stars += st
		print("TURM floor=%d win=%s stars=%d t=%.1fs hp=%d%% kills=%d" % [f, win, st, float(w.t_run), int(w.hero.hp / maxf(w.hero.max_hp, 1.0) * 100.0), int(w.horde.kills)])
		if G.main.hud.modal_open():
			G.main.hud._close_modal()
	print("RESULT mode=turm win=%s floors=%d-%d wins=%d stars=%d real=%.1fs" % [wins == f1 - f0 + 1, f0, f1, wins, stars, (Time.get_ticks_msec() - t0) / 1000.0])


func _bot_surv() -> void:
	_fresh()
	_hero_level(int(G.arg("level", "18")))
	_bot_gear()
	var goal := int(G.arg("waves", "8"))
	var t0 := Time.get_ticks_msec()
	G.main.goto_base()
	await T._wait(0.3)
	await ModiUI.start_surv()
	await T._wait(0.3)
	var w = G.main.world
	var t := 0.0
	while not w.ended and t < float(G.arg("max", "900")):
		await T._wait(0.5)
		t += 0.5
		if w.wave_idx > goal:
			w._finish(true)
	await T._wait(0.3)
	var sr: Dictionary = w.result.get("surv", {})
	print("RESULT mode=ueberleben win=%s wave=%d score=%d picks=%d buffs=%s kills=%d t=%.0fs real=%.1fs" % [int(sr.get("wave", 0)) > goal, int(sr.get("wave", 0)), int(sr.get("score", 0)),
		int(w.picks), str(w.buffs), int(w.horde.kills), float(w.t_run), (Time.get_ticks_msec() - t0) / 1000.0])


func _bot_cave() -> void:
	_fresh()
	P.debug_setup(5)
	_hero_level(int(G.arg("level", "22")))
	G.test_args["caves"] = "1"
	var t0 := Time.get_ticks_msec()
	G.main.goto_base()
	await T._wait(0.3)
	G.main.start_expedition(int(G.arg("area", "1")), "expedition", 0)
	await T._wait(1.2)
	var ex = G.main.world
	var mx = ex.get_node_or_null("ModiExp")
	if mx == null or mx.caves.is_empty():
		print("RESULT mode=hoehle win=false grund=keine_hoehle")
		return
	ex.hero.dismount()
	var c: Dictionary = mx.caves[0]
	# Der Expeditions-Bot lenkt den Helden weiter – im Eingang festhalten, bis die Höhle geladen ist
	var hold := 0.0
	while G.main.world == ex and hold < DM.CAVE_ENTER_HOLD + 3.0:
		ex.hero.global_position = Vector3(c.p.x, 0, c.p.y)
		await T._wait(0.1)
		hold += 0.1
	var cw = G.main.world
	var rooms_n: int = cw.rooms.size() if cw.has_method("swap_out") else 0
	var chest := false
	var ore := false
	var t := 0.0
	var max_t := float(G.arg("max", "400"))
	while is_instance_valid(cw) and G.main.world == cw and t < max_t:
		chest = cw.chest_open
		ore = cw.ore_left <= 0.0
		if G.arg("dbg") != "" and int(t * 2.0) % 20 == 0:
			var hp2: Vector2 = cw.hero.pos2()
			print("DBG t=%.0f hero=%s room=%d exit=%s goal=%s alive=%s" % [t, hp2, cw._room_at(hp2), cw.exit_p, cw.bot_goal(), cw.hero.alive])
		await T._wait(0.5)
		t += 0.5
	var back: bool = G.main.world == ex
	print("RESULT mode=hoehle win=%s rooms=%d chest=%s ore=%s kills=%d t=%.0fs real=%.1fs" % [back and bool(c.done), rooms_n, chest, ore, int(ex.horde.kills),
		t, (Time.get_ticks_msec() - t0) / 1000.0])


# ================================================================= Oberflächen-Test und Bilder
## ui_test.gd (reiches Profil): Sterne, Bestwerte, Raid-Schaden für die Bildschirme.
static func ui_rich() -> void:
	for f in range(1, 14):
		Modi.tower_finish(f, true, 30.0 + f * 4.0, 0.9 if f % 3 else 0.55)
	Modi.surv_finish(18450, 17, 640)
	Modi.raid().dmg = 182000
	Modi.raid().hits = 4
	Modi.raid().best = 61000


## Bilder (--do=modi_turm|modi_gen|modi_surv|modi_pick|modi_cave|modi_cave_in|modi_cave_end|modi_bed|modi_raid).
func shot(kind: String) -> void:
	_hero_level(int(G.arg("level", "16")))
	_bot_gear()
	match kind:
		"modi_turm", "modi_gen":
			await ModiUI.start_tower(int(G.arg("floor", "5" if kind == "modi_gen" else "1")))
		"modi_surv", "modi_pick":
			await ModiUI.start_surv()
			if kind == "modi_pick":
				await T._wait(3.0)
				var w = G.main.world
				w.wave_idx = DM.SURV_PICK_EVERY
				w.buffs = {"wucht": 1, "salve": 2}
				w._queue.clear()
				w.horde.clear()
		"modi_cave", "modi_cave_in", "modi_cave_end":
			G.test_args["caves"] = "1"
			G.main.start_expedition(int(G.arg("area", "1")), "expedition", 0)
			await T._wait(1.0)
			var ex = G.main.world
			var mx = ex.get_node_or_null("ModiExp")
			if mx == null or mx.caves.is_empty():
				return
			ex.hero.dismount()
			var c: Dictionary = mx.caves[0]
			var front: Vector2 = (c.p - c.c).normalized()
			var q: Vector2 = c.p + front * 4.0
			ex.hero.global_position = Vector3(q.x, 0, q.y)
			ex.hero.rotation.y = atan2(-front.x, -front.y)
			ex.cam.snap()
			if kind != "modi_cave":
				mx.enter_cave(0)
				await T._wait(0.4)
				var cw = G.main.world
				if kind == "modi_cave_end" and cw.has_method("swap_out"):
					var last: Vector2 = cw.rooms[cw.rooms.size() - 1].c
					for e in cw.horde.list:
						e.stun = 1.0e6
					cw.hero.global_position = Vector3(last.x, 0, last.y + 3.0)
					cw.cam.snap()
		"modi_bed":
			P.d.vehicles.pickup.owned = true
			P.d.vehicle_sel = "pickup"
			G.test_args["caves"] = "0"
			G.main.start_expedition(int(G.arg("area", "2")), "expedition", 0)
			await T._wait(1.0)
			var ex2 = G.main.world
			var mx2 = ex2.get_node_or_null("ModiExp")
			if mx2 == null:
				return
			ex2.hero.dismount()
			for r in ["wood", "metal", "stone", "fuel"]:
				ex2.add_pack(r, ex2.room_for(r) * 0.3)
			mx2.load_bed()
			var vp: Vector3 = ex2.hero.veh_node.global_position
			ex2.hero.global_position = vp + Vector3(2.4, 0, 1.6)
			ex2.cam.snap()
		"modi_raid":
			P.d.level = 20
			P.social.join_clan(P.social.clan_list()[0])
			G.main.goto_base()
			await T._wait(0.6)
			Modi.start_raid()


## Bots: Ausrüstung wie bei einem Spieler dieser Heldenstufe (Seltenheit nach Stufe, Gegenstände voll verbessert).
## --gear=0 schaltet das ab (nur Startwaffe).
func _bot_gear() -> void:
	if G.arg("gear", "1") == "0":
		return
	var hk := String(P.d.hero_sel)
	var lv := int(P.d.heroes[hk].level)
	var rar := 1 if lv < 15 else (2 if lv < 28 else 3)
	var ilv := D.item_cap(lv)
	var wkeys: Array = D.HEROES[hk].weapons
	var wk := String(wkeys[0])
	for i in wkeys.size():
		if lv >= int(D.WEAPON_UNLOCK_LEVELS[i]):
			wk = String(wkeys[i])
	var w: Dictionary = P.make_item("weapon", wk, rar)
	w.level = ilv
	P.d.heroes[hk].weapon = int(w.id)
	for sl in ["helmet", "charm"]:
		var g: Dictionary = P.make_item(sl, "", rar)
		g.level = ilv
		P.d.heroes[hk].gear[sl] = int(g.id)
