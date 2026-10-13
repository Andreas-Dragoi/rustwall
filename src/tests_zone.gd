extends RefCounted
## Prüfungen für Paket Z (Vulkaninsel, Gebiet 8):
##  - Daten: Gebiet, Expedition, Außenbasis, Welt (Ereignis, Wahrzeichen, Quelle + Werkzeug, Tagebuch, Nebenquest, Tipps), Musik, Klänge
##  - Modelle: Kulissen, Quellen, Wahrzeichen, Sperre, Spezialbau, Symbole; Magma-Wesen mit Animations-Textur und Pflicht-Clips
##  - Zone: Lavaströme (fest, Wechsel, Wegstoßen), Hitze-Leiste (Lava, Quelle, Überhitzen), Ausbruch (alle Arme, Asche, Lavabomben)
##  - Verhalten: Lavabad, harte Kruste (Wasser sprengt sie), Miniboss-Lava, Boss-Ausbruch und Phasen
##  - alter Spielstand bekommt das achte Gebiet
## Aufruf aus tests.gd (--selftest) oder allein mit --autotest=zone.

const D = preload("res://src/data.gd")
const DW = preload("res://src/data_welt.gd")
const AI = preload("res://src/enemy_ai.gd")
const Vat = preload("res://src/vat.gd")
const Models = preload("res://src/models.gd")

const AREA := 7
const SPECIES := ["magma_lavaschnecke", "magma_feuerkaefer", "magma_obsidiangolem", "magma_glutspucker", "magma_aschegeist", "magma_schlackenkriecher"]
const EXTRA := ["magma_glutpriesterin", "magma_basaltschild", "magma_lavamutter", "magma_glutbrecher"]
const SPECIAL_CLIP := {"magma_lavaschnecke": "steam", "magma_feuerkaefer": "pounce", "magma_obsidiangolem": "harden", "magma_glutspucker": "erupt",
	"magma_aschegeist": "blink", "magma_schlackenkriecher": "steam", "magma_glutpriesterin": "heal", "magma_basaltschild": "block",
	"magma_lavamutter": "brood", "magma_glutbrecher": "skill"}

var T: Node


func _init(tests: Node) -> void:
	T = tests


func run() -> void:
	_data()
	_models()
	_old_save()
	var e = await _start()
	await _lava(e)
	await _heat(e)
	await _eruption(e)
	await _enemies(e)
	await _boss(e)
	G.autotest = ""
	G.main.goto_base()
	await T._wait(0.3)


# ---------------------------------------------------------------- Daten
func _data() -> void:
	T._check(D.AREAS.size() >= 8 and String(D.AREAS[AREA].key) == "vulkan" and int(D.AREAS[AREA].level) == 55, "Gebiet 8: Vulkaninsel ab Stufe 55")
	T._check(D.EXP_AREAS.size() == D.AREAS.size() and D.EXP_AREAS[AREA].nodes.has("obsidian"), "Expedition: Obsidian als Quelle")
	T._check(D.EXP_NODES.obsidian.res == "stone" and D.EXP_NODES.obsidian.rare == "shards" and D.EXP_NODES.sulfur.res == "fuel", "Obsidian gibt Stein (selten Splitter), Schwefel Treibstoff")
	T._check(D.OUTPOSTS.has("vulkan") and D.OUTPOST_DELIVER.has("deliver_cells"), "Außenbasis: Obsidianschmiede mit Lieferung")
	T._check(D.AREA_FAMILY[AREA] == "magma" and D.AREA_BOSS[AREA] == "boss_magma" and D.BOSSES.size() == D.AREAS.size(), "Familie und Boss je Gebiet")
	T._check(D.BOSS_PHASES.has("boss_magma") and D.BUILDINGS.has(String(D.BOSS_PHASES.boss_magma.trophy)), "Boss: Phasen und Trophäe")
	for dd in [DW.EVENTS, DW.LANDMARKS, DW.QUESTS, DW.JOURNAL]:
		T._check(dd.has("vulkan"), "Welt: Vulkaninsel eingetragen")
	T._check(DW.JOURNAL.vulkan.size() == 4 and DW.SOURCES.has("src_vulkan") and DW.TOOLS.has(String(DW.SOURCES.src_vulkan.tool)), "Tagebuch, Quelle und Werkzeug")
	T._check(int(DW.TOOLS.tongs.area) == AREA and DW.AREA_TIPS.has("vulkan"), "Glutzange gehört zu Gebiet 8; Ladetipps")
	T._check(Music.track_index("area_vulkan") >= 0, "Gebietsmusik eingetragen")
	for s in ["amb_x_vulkan", "ev_eruption", "ev_amb_eruption", "ev_lavabomb_fall", "ev_lavabomb_impact", "lava_shift", "lava_crack", "lava_burst",
			"heat_warn", "heat_overheat", "hit_geode", "e_magma_spawn", "e_magma_attack", "e_magma_hit", "e_magma_death", "e_magma_special"]:
		T._check(Sfx.has(s), "Klang %s" % s)
	T._check(ResourceLoader.exists("res://audio/music/area_vulkan.ogg") and ResourceLoader.exists("res://audio/music/area_vulkan_fight.ogg"), "Musik und Gefahr-Lage")
	# Gegner: Nummern, Rollen, Bausteine
	var fam: Array = D.family_enemies("magma")
	var roles := {}
	for i in fam:
		roles[String(D.ENEMIES[i].role)] = true
	T._check(fam.size() == 6 and roles.size() == 6, "Magma-Wesen: sechs Arten, sechs Rollen")
	var extra := {}
	for i in D.family_all("magma"):
		if D.ROLES_EXTRA.has(String(D.ENEMIES[i].role)):
			extra[String(D.ENEMIES[i].role)] = true
	T._check(extra.size() >= 3 and D.family_mini("magma") >= 0, "drei Rollen aus G2 und ein Miniboss")
	var last := -1
	for key in SPECIES + EXTRA + ["boss_magma"]:
		var idx: int = int(D.ENEMY_INDEX.get(key, -1))
		T._check(idx > last and String(D.ENEMIES[idx].key) == key, "%s: Nummer %d am Ende von ENEMIES" % [key, idx])
		last = idx
		var d: Dictionary = D.enemy(key)
		for a in d.ai:
			T._check(AI.NAMES.has(String(a)), "%s: Baustein %s" % [key, a])
		T._check(d.has("counter") and d.has("look") and d.has("text") and String(d.sound) == "e_magma", "%s: Tipp, Aussehen, Laute" % key)
		T._check(not D.enemy_places(key).is_empty() and "Vulkaninsel" in str(D.enemy_places(key)), "%s: Fundort im Monsterbuch" % key)
	T._check(last == D.ENEMIES.size() - 1 or String(D.ENEMIES[last + 1].family) != "magma", "Magma-Wesen stehen hinter allen älteren Arten")      # Paket Z2: danach folgen die Maschinen
	T._check(D.weak_factor("magma", "wasser") > 1.4 and D.weak_factor("magma", "feuer") == 0.0, "Schwäche: Wasser, Feuer wirkungslos")


# ---------------------------------------------------------------- Modelle
func _models() -> void:
	for m in ["p_tree_lava_1", "p_tree_lava_2", "p_rock_lava_1", "p_rock_lava_2", "p_rock_lava_3", "p_vk_ashgrass", "p_vk_firebloom", "p_vk_fumarole",
			"p_vk_spring", "n_obsidian_1", "n_obsidian_2", "n_obsidian_3", "n_sulfur", "n_src_vulkan", "n_lavabomb", "lm_vulkan", "x_barrier_vulkan",
			"o_special_vulkan", "b_trophy_brodel"]:
		T._check(Models.has_glb(m), "Modell %s" % m)
	for ic in ["area_vulkan", "tool_tongs", "o_special_vulkan", "o_special_vulkan_1", "lm_vulkan"]:
		T._check(ResourceLoader.exists("res://icons/%s.png" % ic), "Symbol %s" % ic)
	for key in SPECIES + EXTRA:
		T._check(Vat.has(key) and ResourceLoader.exists("res://icons/e_%s.png" % key), "%s: Animations-Textur und Symbol" % key)
		if Vat.has(key):
			var cl: Dictionary = Vat.data(key).clips
			var ok := true
			for c in ["idle", "walk", "attack", "hit", "death"]:
				ok = ok and cl.has(c)
			T._check(ok and cl.has(SPECIAL_CLIP[key]), "%s: Pflicht-Clips und %s" % [key, SPECIAL_CLIP[key]])
	var bi: Dictionary = Vat.boss_info("boss_magma")
	T._check(not bi.is_empty() and bi.clips.has("special") and bi.clips.has("summon") and bi.clips.has("slam") and int(bi.tris) <= 8000, "Magmafürst Brodel: Boss-Figur mit Sonder-Clips")


# ---------------------------------------------------------------- alter Spielstand
func _old_save() -> void:
	P.new_game()
	P.no_save = true
	P.d.areas.boss.resize(7)
	P._ensure_fields()
	T._check(P.d.areas.boss.size() == D.AREAS.size(), "alter Stand: achtes Gebiet ergänzt")
	P.new_game()
	T._check(P.d.areas.boss.size() == D.AREAS.size(), "neuer Stand: alle Gebiete")
	P.outpost_set_level("vulkan", 1)
	T._check(absf(P.outpost_bonus("heat_resist") - 0.15) < 0.001, "Obsidianschmiede: 15 % weniger Hitzeanstieg")
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
	return e


func _lava(e) -> void:
	var vk = e.vulkan
	T._check(vk != null and vk.streams.size() >= 3, "Vulkaninsel: Lavaströme angelegt (%d)" % (vk.streams.size() if vk != null else 0))
	if vk == null or vk.streams.is_empty():
		return
	T._check(e.phase == "explore", "Erkunden")
	var s: Dictionary = vk.streams[0]
	var on: Dictionary = s.arms[int(s.act)]
	var off: Dictionary = s.arms[1 - int(s.act)]
	var on_cell: int = on.cells[on.cells.size() / 2]
	var off_cell: int = -1
	for i in off.cells:
		if vk.own[i] == 1 and not on.cells.has(i) and not s.trunk.cells.has(i):
			off_cell = i
			break
	T._check(e.field.solid[on_cell] == 1 and vk.lava[on_cell] == 1, "fließende Lava sperrt den Weg")
	T._check(off_cell >= 0 and e.field.solid[off_cell] == 0 and vk.lava[off_cell] == 0, "erkaltete Kruste ist begehbar")
	# Held steht auf der Kruste, die gleich zu Lava wird: er wird verbrannt und zur Seite gestoßen
	var q: Vector2 = e.field.center(off_cell)
	e.hero.global_position = Vector3(q.x, 0, q.y)
	var hp0: float = e.hero.hp
	var n0: int = vk.shifts
	vk.shift(s)
	await T._wait(0.1)
	T._check(vk.shifts == n0 + 1 and e.field.solid[off_cell] == 1 and e.field.solid[on_cell] == 0, "Strom wechselt den Arm (Weg öffnet und schließt sich)")
	T._check(not vk.lava_cell(e.hero.pos2()) and not e.field.blocks_player(e.hero.pos2()), "Held wird aus der Lava gestoßen")
	T._check(e.hero.hp < hp0 and vk.log.has("lava_hit"), "Lava verbrennt den Held")
	# Warnung vor dem Wechsel
	s.next = DW.LAVA_WARN - 0.2
	s.warn = false
	await T._wait(0.3)
	T._check(bool(s.warn) and vk.log.has("warn"), "Risse glühen vor dem Wechsel auf")
	await _until(func(): return vk.shifts >= n0 + 2, 10.0)
	T._check(vk.shifts >= n0 + 2, "Strom wechselt nach der Warnung von selbst")


func _heat(e) -> void:
	var vk = e.vulkan
	if vk == null or vk.streams.is_empty():
		return
	var s: Dictionary = vk.streams[1 % vk.streams.size()]
	var arm: Dictionary = s.arms[int(s.act)]
	var mid: Vector2 = arm.pts[arm.pts.size() / 2]
	var q: Vector2 = vk._free_near(mid)
	e.hero.global_position = Vector3(q.x, 0, q.y)
	vk.heat = 10.0
	await T._wait(1.5)
	T._check(vk.lava_dist(e.hero.pos2()) < 5.0 and vk.heat > 20.0, "Hitze steigt nahe der Lava (%.0f)" % vk.heat)
	vk.heat = 99.5
	var hp0: float = e.hero.hp
	await T._wait(1.0)
	T._check(vk.hot and e.hero.hp < hp0 and vk.log.has("overheat"), "volle Hitze: Schaden über Zeit")
	T._check(vk.bot_cool(e.hero.pos2()) != null, "Testbot sucht Abkühlung")
	if vk.springs.size() > 0:
		var sp: Vector2 = vk.springs[0].p
		e.hero.global_position = Vector3(sp.x + 1.0, 0, sp.y)
		await T._wait(2.5)
		T._check(vk.heat < 80.0 and not vk.hot, "kühle Quelle senkt die Hitze (%.0f)" % vk.heat)
	else:
		T._check(false, "kühle Quellen vorhanden")
	T._check(vk.in_shade(e.outpost.C), "Außenbasis spendet Schatten")


func _eruption(e) -> void:
	var vk = e.vulkan
	if vk == null:
		return
	var sp: Vector2 = vk.springs[0].p if vk.springs.size() > 0 else e.outpost.C
	e.hero.global_position = Vector3(sp.x + 1.0, 0, sp.y)
	e.welt.start_event()
	await T._wait(0.3)
	T._check(e.welt.event_key() == "ausbruch" and vk.erupt, "Vulkanausbruch beginnt")
	var all_on := true
	for s in vk.streams:
		for arm in s.arms:
			var c: int = arm.cells[arm.cells.size() / 2]
			if vk.own[c] == 1 and e.field.solid[c] == 0:
				all_on = false
	T._check(all_on, "beim Ausbruch fließen alle Arme")
	T._check(vk._ash.emitting, "Asche fällt")
	await T._wait(DW.EVENTS.vulkan.dur * 0.6)
	T._check(e.welt.log.has("strike"), "Lavabomben schlagen ein")
	var bomb := false
	for n in e.welt.bonus_nodes:
		if is_instance_valid(n) and n.kind == "lavabomb":
			bomb = true
	T._check(bomb, "Lavabombe bleibt als Fund liegen")
	e.welt.end_event()
	await T._wait(0.2)
	T._check(not vk.erupt and not vk._ash.emitting, "Ausbruch vorbei: Ströme wieder normal")


# ---------------------------------------------------------------- Gegner
func _enemies(e) -> void:
	var vk = e.vulkan
	var h = e.horde
	h.clear()
	var pp: Vector2 = e.hero.pos2()
	# Lavabad: nahe fließender Lava heilt die Lavaschnecke
	if vk != null and vk.streams.size() > 0:
		var s: Dictionary = vk.streams[0]
		var arm: Dictionary = s.arms[int(s.act)]
		var q: Vector2 = vk._free_near(arm.pts[arm.pts.size() / 2])
		var sn = h.spawn(int(D.ENEMY_INDEX["magma_lavaschnecke"]), q, 1.0, 1.0, 1.0)
		sn.leash = 3.0
		sn.home = q
		sn.hp = sn.mhp * 0.3
		await T._wait(2.0)
		T._check(sn.st != 2 and sn.hp > sn.mhp * 0.4, "Lavaschnecke heilt nahe der Lava (%.0f %%)" % (100.0 * sn.hp / sn.mhp))
		var far = h.spawn(int(D.ENEMY_INDEX["magma_lavaschnecke"]), e.outpost.C + Vector2(0, 4), 1.0, 1.0, 1.0)
		T._check(not vk.near_lava(far.p, 4.0), "weit weg von der Lava kein Lavabad")
	# harte Kruste des Obsidian-Golems
	var g = h.spawn(int(D.ENEMY_INDEX["magma_obsidiangolem"]), pp + Vector2(8, 0), 50.0, 1.0, 1.0)
	g.stat = true
	g.ai_c = 0.0
	h.damage(g, g.mhp * 0.2, Vector2(-1, 0))
	T._check(g.ai_s == AI.S_HARD, "Golem: Kruste verhärtet nach dem Treffer")
	var hp1: float = g.hp
	h.damage(g, 1000.0, Vector2(-1, 0), true)
	T._check(hp1 - g.hp < 450.0 and hp1 - g.hp > 250.0, "harte Kruste: nur gut ein Drittel Schaden (%.0f)" % (hp1 - g.hp))
	h.damage(g, 10.0, Vector2(-1, 0), true, false, "wasser")
	T._check(g.ai_s != AI.S_HARD, "Wasser sprengt die Kruste")
	# Miniboss: Lava an der roten Zone
	var mb = h.spawn(D.family_mini("magma"), pp + Vector2(5, 0), 1.0, 1.0, 1.0)
	h.ai._mini_skill(mb, D.enemy("magma_glutbrecher"), pp, true)
	T._check(h.ai.tele.size() > 0, "Glutbrecher: rote Bodenmarkierung")
	await T._wait(1.4)
	var fire := false
	for z in h.ai.hazards:
		if z.kind == "fire":
			fire = true
	T._check(fire, "Glutbrecher: Lava quillt aus dem Boden")
	h.clear()


func _boss(e) -> void:
	var h = e.horde
	var pp: Vector2 = e.hero.pos2()
	var b = h.spawn_boss(AREA, pp + Vector2(10, 0), 1.0, 1.0)
	await T._wait(0.3)
	T._check(b != null and String(D.ENEMIES[b.t].key) == "boss_magma" and h.boss_name == "Magmafürst Brodel", "Boss der Vulkaninsel erscheint")
	T._check(h.bossctl.log_intro > 0, "Boss: Auftritt mit Namen")
	var tel0: int = h.ai.tele.size()
	h.ai.boss_special(b, D.enemy("boss_magma"), "eruption", pp, true)
	T._check(h.ai.tele.size() >= tel0 + 6 and b.expose > 0.0, "Ausbruch: Lavabomben mit Bodenmarkern, danach Schwachstelle offen")
	b.hp = b.mhp * 0.6
	await T._wait(0.3)
	T._check(b.phase >= 2 and b.specs.has("slam"), "Phase 2 bringt den Stampfer")
	b.hp = b.mhp * 0.25
	await T._wait(0.3)
	T._check(b.rage, "Wutphase unter 30 %")
	h.clear()


func _until(cond: Callable, sec: float) -> bool:
	var t := 0.0
	while t < sec:
		if cond.call():
			return true
		await T._wait(0.05)
		t += 0.05
	return cond.call()
