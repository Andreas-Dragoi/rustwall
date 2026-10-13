extends RefCounted
## V6 Paket B: Spielregeln außerhalb der Welt (wie welt_state.gd).
##  - Spielstand-Felder anlegen (ensure), Layout-Test nach einem Absturz zurücksetzen
##  - seltene Funde beim Räumen von Hindernissen (Truhe, Juwelen, Bauplan-Splitter; das Hindernis glitzert vorher)
##  - verletzte Bewohner nach verlorener oder harter Flut (Heilzeit, Feldlazarett)
##  - Abschluss jeder Flut: Zusatzbeute (Nacht, Forschung „Plünderer“), Rückblick speichern, Bewertungs-Hinweis vormerken
##  - Reparaturkosten der Mauern und Gebäude, Mitteilungs-Einstellungen

const D = preload("res://src/data.gd")
const DB = preload("res://src/data_basis.gd")
const Research = preload("res://src/research.gd")
const Replay = preload("res://src/flood_replay.gd")

static var find_events: Array = []      # [Vector2i Feld, Art] – die Welt zeigt dazu Glitzer (basis_life.gd)


static func ensure(d: Dictionary) -> void:
	Research.ensure(d)
	for k in [["replays", []], ["injured", {}], ["bp_frags", 0], ["layout_test", {}], ["rate", {"asked": 0, "answer": "", "pending": false}],
			["notify", {"on": true, "build": true, "flood": true, "gift": true, "research": true}]]:
		if not d.has(k[0]):
			d[k[0]] = k[1]
	d.bp_frags = int(d.bp_frags)
	for nk in DB.NOTIFY_KINDS:
		if not (d.notify as Dictionary).has(String(nk[0])):
			d.notify[String(nk[0])] = true
	# Hindernisse aus älteren Ständen bekommen einmal ihren Fund-Wurf
	for b in d.get("buildings", []):
		if String(D.BUILDINGS.get(String(b.key), {}).get("cat", "")) == "obstacle" and not b.has("find_roll"):
			roll_find(b)
	# Layout-Test wurde nicht beendet (Spiel geschlossen): alten Aufbau wiederherstellen
	var lt: Dictionary = d.layout_test
	if lt.has("backup") and d.has("buildings"):
		restore_backup(d, lt.backup)
		d.layout_test = {}


static func restore_backup(d: Dictionary, backup: Array) -> void:
	var pos := {}
	for e in backup:
		pos[int(e[0])] = e
	for b in d.buildings:
		if pos.has(int(b.id)):
			var e: Array = pos[int(b.id)]
			b.x = int(e[1])
			b.y = int(e[2])
			b.rot = int(e[3])


# ================================================================= Funde beim Räumen
static func roll_find(b: Dictionary) -> void:
	if b.is_empty():
		return
	b["find_roll"] = true
	var ch := DB.FIND_CHANCE * (1.0 + Research.bonus("find_luck"))
	if randf() >= ch:
		return
	var r := randf()
	var acc := 0.0
	for k in DB.FIND_KINDS:
		acc += float(k[1])
		if r < acc:
			b["find"] = String(k[0])
			return
	b["find"] = "gems"


## Aus P._complete: das weggeräumte Hindernis enthielt vielleicht einen Fund.
static func obstacle_cleared(b: Dictionary) -> void:
	var kind := String(b.get("find", ""))
	if kind == "":
		return
	var txt := ""
	match kind:
		"chest":
			P.add_chest("find")
			txt = "Fund beim Räumen: eine Fundkiste!"
		"gems":
			var n := randi_range(int(DB.FIND_GEMS[0]), int(DB.FIND_GEMS[1]))
			P.add_gems(n, "Fund beim Räumen")
			txt = "Fund beim Räumen: %d Juwelen!" % n
		"bp":
			P.d.bp_frags = int(P.d.get("bp_frags", 0)) + 1
			txt = "Fund beim Räumen: Bauplan-Splitter (%d/%d)" % [mini(int(P.d.bp_frags), DB.BP_FRAGS), DB.BP_FRAGS]
			if int(P.d.bp_frags) >= DB.BP_FRAGS:
				P.d.bp_frags = int(P.d.bp_frags) - DB.BP_FRAGS
				var key := _blueprint_candidate()
				if key != "":
					preload("res://src/arsenal_rules.gd").give_blueprint(key, "Bauplan-Splitter")
					txt = "Bauplan-Splitter vollständig: %s!" % String(D.WEAPONS[key].name)
				else:
					P.add("shards", 2)
					txt = "Bauplan-Splitter vollständig – alle Baupläne da: +2 Sternsplitter"
	P.count_up("finds", 1)
	find_events.append([Vector2i(int(b.x), int(b.y)), kind])
	if find_events.size() > 8:
		find_events.pop_front()
	Sfx.play("find_sparkle", -4.0)
	P.toast.emit.call_deferred(txt)
	P.mark()


static func _blueprint_candidate() -> String:
	var Ars = preload("res://src/arsenal_rules.gd")
	var cands: Array = []
	for k in D.WEAPONS:
		var g := D.weapon_get(String(k))
		if (g == "craft" or g == "both") and not Ars.has_blueprint(String(k)) and not Ars.owned(String(k)):
			cands.append(String(k))
	if cands.is_empty():
		return ""
	cands.sort()
	return String(cands[randi() % cands.size()])


# ================================================================= Verletzte Bewohner
## Namen der Bewohner, die es gibt (wie npc_board._spawn: der Reihe nach aus D.NPC_NAMES).
static func settler_names() -> Array:
	var n := mini(3 + P.bunker_level(), 13)
	var out: Array = []
	for i in n:
		out.append(String(D.NPC_NAMES[i % D.NPC_NAMES.size()]))
	return out


static func injure(count: int) -> Array:
	var inj: Dictionary = P.d.injured
	var names := settler_names()
	names.shuffle()
	var out: Array = []
	var dur := DB.INJURY_TIME / (1.0 + Research.bonus("heal_speed"))
	for nm in names:
		if out.size() >= count:
			break
		if inj.has(nm):
			continue
		inj[nm] = {"until": P.now() + dur, "dur": dur, "care": 0.0}
		out.append(nm)
	P.mark()
	return out


static func injured_now() -> Array:
	var inj: Dictionary = P.d.get("injured", {})
	var t := P.now()
	var out: Array = []
	for nm in inj.keys():
		if float(inj[nm].until) <= t:
			inj.erase(nm)
			P.toast.emit("%s ist wieder gesund." % String(nm))
			continue
		out.append(String(nm))
	return out


static func is_injured(nm: String) -> bool:
	var inj: Dictionary = P.d.get("injured", {})
	return inj.has(nm) and float(inj[nm].until) > P.now()


static func heal_left(nm: String) -> float:
	var inj: Dictionary = P.d.get("injured", {})
	return maxf(0.0, float(inj[nm].until) - P.now()) if inj.has(nm) else 0.0


## Ein Besuch beim Verarzten im Bunker verkürzt die Heilzeit.
static func cared(nm: String) -> void:
	var inj: Dictionary = P.d.get("injured", {})
	if not inj.has(nm):
		return
	var e: Dictionary = inj[nm]
	e.until = float(e.until) - float(e.get("dur", DB.INJURY_TIME)) * DB.INJURY_CARE
	e.care = P.now()
	P.mark()


## War die Flut hart? Dann gibt es Verletzte (verloren: mehr).
static func injuries_after(win: bool, hp_ratio: float, lost: int, walls: int) -> int:
	var n := 0
	if not win:
		n = 2 + int(P.bunker_level() / 3)
	elif hp_ratio < DB.INJURY_HARD_HP or lost >= DB.INJURY_HARD_LOST or walls >= DB.INJURY_HARD_WALLS:
		n = 1 + int(P.bunker_level() / 5)
	if n <= 0:
		return 0
	var got := injure(n)
	if got.size() > 0:
		P.toast.emit.call_deferred("Verletzt: %s – sie brauchen Zeit (Verband) und gehen zum Verarzten in den Bunker." % ", ".join(got))
	return got.size()


# ================================================================= Abschluss einer Flut
## Aus base_world._finish (nach P.flood_result bzw. practice_done): Zusatzbeute, Verletzte, Bewertungs-Hinweis.
static func flood_end(world, result: Dictionary) -> void:
	var fd: Dictionary = world.flood
	var real: bool = world.mode == "flood" and not bool(world.get("layout_test")) and not fd.has("raid")
	var win := bool(result.get("win", false))
	if real or world.mode == "practice":
		var k := 0.0
		var why: Array = []
		if bool(fd.get("night", false)) and win:
			k += float(DB.NIGHT.loot)
			why.append("Nacht")
		if real and win and Research.bonus("flood_loot") > 0.0:
			k += Research.bonus("flood_loot")
			why.append("Plünderer")
		if k > 0.0:
			var base := 100 * int(P.d.week.number) + 50 * int(result.get("stars", 1)) if real else int(result.get("coins", 0))
			var extra := int(round(float(base) * k))
			if extra > 0:
				P.add("coins", extra)
				result["extra"] = {"coins": extra, "why": " + ".join(why)}
	if real and win and int(P.d.rate.get("asked", 0)) < DB.RATE_MAX_ASK and String(P.d.rate.get("answer", "")) == "":
		P.d.rate.pending = true
	P.mark()


## Aus P._auto_flood: berechneter Rückblick der verpassten Flut, Verletzte, Zusatzbeute.
static func auto_flood(out: Dictionary, fd: Dictionary, ratio: float) -> void:
	var win := bool(out.get("win", false))
	var r := Replay.simulate(fd, win, ratio, out)
	Replay.store(r)
	var lost := 0
	var br := 0
	for wv in r.waves:
		lost += (wv.lost as Array).size()
		br += (wv.br as Array).size()
	injuries_after(win, float(out.get("hp_ratio", 0.0)), lost, br)
	if win and Research.bonus("flood_loot") > 0.0:
		P.add("coins", int(round((100 * int(P.d.week.number) + 50 * int(out.get("stars", 1))) * Research.bonus("flood_loot"))))


# ================================================================= Reparatur
## Kosten, um alle beschädigten Mauern, Tore und Gebäude voll zu reparieren: {kosten, walls, buildings}
static func repair_quote() -> Dictionary:
	var cost := {}
	var nw := 0
	var nb := 0
	var k := maxf(0.0, 1.0 - Research.bonus("repair_cost"))
	for b in P.d.buildings:
		var miss := float(b.get("dmg", 0.0))
		if miss <= 0.0 or P.is_building(b):
			continue
		var key := String(b.key)
		if key == "wall" or key == "tor":
			var rc: Dictionary = DB.REPAIR_WALL[clampi(int(b.level) - 1, 0, 2)]
			for r in rc:
				cost[r] = float(cost.get(r, 0.0)) + float(rc[r]) * miss * k * (3.0 if key == "tor" else 1.0)
			nw += 1
		else:
			var cc: Dictionary = P.cost_for(key, int(b.level))
			cost["coins"] = float(cost.get("coins", 0.0)) + float(cc.get("coins", 50)) * DB.REPAIR_BUILDING_COINS * miss * k
			nb += 1
	var out := {}
	for r in cost:
		var v := int(ceil(float(cost[r])))
		if v > 0:
			out[r] = v
	return {"cost": out, "walls": nw, "buildings": nb}


# ================================================================= Mitteilungen
static func notify_on(kind: String) -> bool:
	var n: Dictionary = P.d.get("notify", {})
	return bool(n.get("on", true)) and bool(n.get(kind, true))
