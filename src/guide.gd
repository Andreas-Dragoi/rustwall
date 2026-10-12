extends RefCounted
## Spielerführung und Komfort (Paket F): Spielregeln außerhalb des Kampfes, die im Spielstand P.d stehen.
##   Tutorial (P.d.tut), Ziele-Leiste (P.d.goals), Rückkehr-Zusammenfassung (P.d.last_seen), Bau-Warteschlange (P.d.build_queue),
##   Flut-Schwierigkeit (P.d.flood_diff), Turmziel je Turm (Gebäude-Eintrag "aim"), gespeicherter Gebäudeschaden ("dmg"),
##   Mauer-Reihe verbessern, Wellen-Vorschau, Vorschau der Werte beim Stufenaufstieg.
## Nur statische Funktionen; Zahlen und Texte in data_fuehrung.gd.

const D = preload("res://src/data.gd")
const DF = preload("res://src/data_fuehrung.gd")

const QUEUE_MAX := 4

## Stand vor dem Nachholen der Abwesenheit (für „Während du weg warst …“). Leer = nichts anzuzeigen.
static var away := {}


# ================================================================= Felder im Spielstand
## Aus P._ensure_fields(): ergänzt fehlende Felder. Neues Spiel (noch keine Gebäude) beginnt das Tutorial,
## alte Stände bekommen es als erledigt und starten die Ziele-Leiste beim ersten offenen Ziel.
static func ensure(d: Dictionary) -> void:
	var fresh: bool = (d.get("buildings", []) as Array).is_empty()
	if not d.has("tut"):
		d["tut"] = {"step": 0 if fresh else DF.TUT_STEPS.size(), "skipped": [], "flood": not fresh, "start": []}
	d.tut.step = int(d.tut.step)
	if not d.has("goals"):
		d["goals"] = {"idx": 0, "gen": {}, "claimed": 0}
		if not fresh:
			_skip_done_goals(d)
	d.goals.idx = int(d.goals.idx)
	if not d.has("build_queue"):
		d["build_queue"] = []
	if not d.has("flood_diff"):
		d["flood_diff"] = {"week": -1, "lvl": 0}
	# Rückkehr: wie lange war der Spieler weg? (Zeit wird danach in P._time_passed nachgeholt)
	away = {}
	var last := float(d.get("last_seen", 0.0))
	if not fresh and last > 0.0 and is_same(d, P.d):
		var gone := P.now() - last
		if gone >= DF.RETURN_DAYS * D.DAY_SECONDS:
			var done: Array = []
			for b in d.buildings:
				var t := float(b.get("done_at", 0.0))
				if t > 0.0 and t <= P.now() and not b.get("clear", false):
					done.append([String(b.key), int(b.level) + (1 if b.get("up", false) else 0)])
			away = {"gone": gone, "week": int(d.week.number), "won": int(d.stats.floods_won), "lost": int(d.stats.get("floods_lost", 0)),
				"done": done, "kills": int(d.stats.kills)}


## Alte Stände: bereits erfüllte Ziele ohne Belohnung überspringen.
static func _skip_done_goals(d: Dictionary) -> void:
	if not is_same(d, P.d):
		return
	while int(d.goals.idx) < DF.GOALS.size():
		var g: Dictionary = DF.GOALS[int(d.goals.idx)]
		if goal_value(g) < int(g.n):
			break
		d.goals.idx = int(d.goals.idx) + 1


## Jede Sekunde aus P._time_passed().
static func tick(t: float) -> void:
	if P.d.is_empty() or not P.d.has("build_queue"):
		return
	queue_tick()
	if not P.no_save and t - float(P.d.get("last_seen", 0.0)) > 300.0:
		P.mark()                       # gelegentlich speichern, damit „zuletzt gesehen“ stimmt


# ================================================================= Tutorial
static func tut_step() -> int:
	return int(P.d.tut.step) if P.d.has("tut") else DF.TUT_STEPS.size()


## Schlüssel des laufenden Schritts oder "" (fertig).
static func tut_key() -> String:
	var i := tut_step()
	return String(DF.TUT_STEPS[i].key) if i < DF.TUT_STEPS.size() else ""


static func tut_def() -> Dictionary:
	var i := tut_step()
	return DF.TUT_STEPS[i] if i < DF.TUT_STEPS.size() else {}


static func tut_next(skipped := false) -> void:
	var k := tut_key()
	if k == "":
		return
	if skipped:
		(P.d.tut.skipped as Array).append(k)
	P.d.tut.step = tut_step() + 1
	P.d.tut.start = []
	P.mark()
	if not skipped:
		Sfx.play("tut_step", -4.0)
	if tut_key() == "":
		P.toast.emit("Tutorial geschafft! Die Ziele-Leiste zeigt dir, wie es weitergeht.")
		Sfx.play("tut_done", -3.0)


static func tut_skip_all() -> void:
	while tut_key() != "":
		tut_next(true)


static func tut_restart() -> void:
	P.d.tut.step = 0
	P.d.tut.skipped = []
	P.d.tut.start = []
	P.mark()


## Prüft, ob der laufende Schritt erledigt ist (aus dem HUD, viermal je Sekunde). world: laufende Welt.
static func tut_check(world: Node) -> void:
	var k := tut_key()
	if k == "":
		return
	var done := false
	match k:
		"laufen":
			if world != null and world.hero != null and world.mode == "peace":
				var p: Vector2 = world.hero.pos2()
				var st: Array = P.d.tut.start
				if st.size() < 2:
					P.d.tut.start = [p.x, p.y]
				elif p.distance_to(Vector2(float(st[0]), float(st[1]))) >= DF.TUT_WALK_DIST:
					done = true
		"blase":
			done = not P.has_pickup("daily") or P.stat("collected") > 0
		"bauen":
			done = P.count("saege") >= 1
		"beschleunigen":
			var any := false
			for b in P.d.buildings:
				if b.key == "saege" and P.is_building(b):
					any = true
			done = P.count("saege") >= 1 and not any
		"uebung":
			done = bool(P.d.tut.flood)
		"expedition":
			done = int(P.d.stats.expeditions) > 0 or (world != null and world.mode == "exp")
	if done:
		tut_next()


## Tutorial-Flut am ersten Tag: noch nicht gespielt und die echte Flut ist nicht dran.
static func tut_flood_open() -> bool:
	return P.d.has("tut") and not bool(P.d.tut.flood) and not P.flood_available()


## Testbetrieb ohne Spielerführung (Bots, Selbsttest, Bildschirmfotos), außer mit --tut=1.
static func quiet() -> bool:
	return (G.autotest != "" or G.selftest or G.shots_dir != "") and G.arg("tut") == ""


# ================================================================= Ziele-Leiste
static func goal() -> Dictionary:
	var i := int(P.d.goals.idx)
	if i < DF.GOALS.size():
		return DF.GOALS[i]
	var gen: Dictionary = P.d.goals.gen
	if gen.is_empty() or int(gen.get("idx", -1)) != i:
		var k := i - DF.GOALS.size()
		var tpl: Dictionary = DF.GOAL_GEN[k % DF.GOAL_GEN.size()]
		var round_n := int(k / DF.GOAL_GEN.size())
		var step := int(round(float(tpl.step) * (1.0 + 0.5 * round_n)))
		gen = tpl.duplicate(true)
		gen["idx"] = i
		gen["base"] = goal_value(tpl)
		gen["n"] = step
		gen["reward"] = _scale_reward(tpl.reward, 1.0 + 0.25 * round_n)
		P.d.goals.gen = gen
		P.mark()
	return gen


static func _scale_reward(r: Dictionary, k: float) -> Dictionary:
	var out := {}
	for key in r:
		out[key] = r[key] if key == "chest" else int(round(float(r[key]) * k))
	return out


## Stand eines Ziels (ohne Abzug eines Grundwerts).
static func goal_value(g: Dictionary) -> int:
	var key := String(g.key)
	match String(g.t):
		"built":
			var n := 0
			for b in P.d.buildings:
				if b.key == key and (not P.is_building(b) or b.get("up", false)):
					n += 1
			return n
		"level":
			if key == "bunker":
				return P.bunker_level()
			var mx := 0
			for b in P.d.buildings:
				if b.key == key and (not P.is_building(b) or b.get("up", false)):
					mx = maxi(mx, int(b.level))
			return mx
		"stat":
			return P.stat(key)
	return 0


## [erreicht, nötig] für die Anzeige.
static func goal_progress(g: Dictionary) -> Array:
	var v := goal_value(g) - int(g.get("base", 0))
	return [clampi(v, 0, int(g.n)), int(g.n)]


static func goal_text(g: Dictionary) -> String:
	var t := String(g.text)
	return t % int(g.n) if t.contains("%d") else t


static func goal_ready() -> bool:
	var pr := goal_progress(goal())
	return int(pr[0]) >= int(pr[1])


## Belohnung abholen und das nächste Ziel zeigen. Rückgabe: Belohnung (leer = noch nicht erfüllt).
static func goal_claim() -> Dictionary:
	var g := goal()
	if not goal_ready():
		return {}
	var rw: Dictionary = g.reward
	give(rw, "Ziel: " + goal_text(g))
	P.d.goals.idx = int(P.d.goals.idx) + 1
	P.d.goals.claimed = int(P.d.goals.get("claimed", 0)) + 1
	P.count_up("goals", 1)
	Sfx.play("goal_done", -3.0)
	P.mark()
	return rw


static func give(rw: Dictionary, why: String) -> void:
	for r in rw:
		if r == "gems":
			P.add_gems(int(rw[r]), why)
		elif r == "chest":
			P.add_chest(String(rw[r]))
		else:
			P.add(String(r), float(rw[r]))
	P.resources_changed.emit()


static func reward_text(rw: Dictionary) -> String:
	var parts: Array = []
	for r in rw:
		if r == "chest":
			parts.append(String(D.CHESTS[String(rw[r])].name))
		elif r == "gems":
			parts.append("%d Juwelen" % int(rw[r]))
		else:
			parts.append("%d %s" % [int(rw[r]), String(D.RES_NAME[r])])
	return ", ".join(parts)


# ================================================================= Rückkehr-Zusammenfassung
## Zeilen für „Während du weg warst …“ (nach dem Laden einmal). Leer = nichts zu zeigen.
static func away_report() -> Dictionary:
	if away.is_empty():
		return {}
	var out := {"days": float(away.gone) / D.DAY_SECONDS, "lines": []}
	var lines: Array = out.lines
	var done: Array = away.done
	if done.size() > 0:
		var names: Array = []
		for e in done:
			var nm := String(D.BUILDINGS[String(e[0])].name)
			if String(e[0]) != "wall" and not names.has(nm):
				names.append(nm)
		var walls := 0
		for e in done:
			if String(e[0]) == "wall":
				walls += 1
		var t := ", ".join(names.slice(0, 4))
		if names.size() > 4:
			t += " und %d weitere" % (names.size() - 4)
		if walls > 0:
			t += ("" if t == "" else ", ") + "%d Mauerstücke" % walls
		lines.append(["ui_build", "Fertig geworden: " + t])
	var store := {}
	for b in P.d.buildings:
		var def: Dictionary = D.BUILDINGS[b.key]
		if def.has("prod"):
			var n: int = P.prod_stored(b)
			if n > 0:
				store[String(def.prod)] = int(store.get(String(def.prod), 0)) + n
	if store.size() > 0:
		var parts: Array = []
		for r in store:
			parts.append("%s %s" % [_fmt(int(store[r])), String(D.RES_NAME[r])])
		lines.append(["ui_crate", "In den Speichern wartet: " + ", ".join(parts)])
	var weeks := int(P.d.week.number) - int(away.week)
	var won := int(P.d.stats.floods_won) - int(away.won)
	var lost := int(P.d.stats.get("floods_lost", 0)) - int(away.lost)
	if won + lost > 0:
		var ft := ("Die Basis hat sich allein verteidigt: %d Flut abgewehrt" if won == 1 else "Die Basis hat sich allein verteidigt: %d Fluten abgewehrt") % won
		if lost > 0:
			ft += ", %d nicht gehalten (Rohstoffe verloren)" % lost
		lines.append(["ui_flood", ft])
	elif weeks > 0:
		lines.append(["ui_flood", ("%d neue Woche hat begonnen." if weeks == 1 else "%d neue Wochen haben begonnen.") % weeks])
	for hk in D.HERO_ORDER:
		if P.hero_unlocked(hk) and P.auto_ready(hk):
			lines.append(["ui_expedition", "%s ist von der Auto-Expedition zurück." % String(D.HEROES[hk].name)])
	if P.has_pickup("daily"):
		lines.append(["res_gems", "Dein tägliches Geschenk liegt am Bunker."])
	var days := mini(int(floor(out.days)), DF.RETURN_GIFT_MAX_DAYS)
	out["gift"] = days * DF.RETURN_GIFT_PER_DAY
	away = {}
	return out


static func _fmt(n: int) -> String:
	return preload("res://src/ui.gd").fmt(n)


# ================================================================= Bau-Warteschlange
static func queue() -> Array:
	return P.d.get("build_queue", [])


## Neues Gebäude vormerken (Platz wird beim Start erneut geprüft). Rückgabe: "" oder Grund.
static func queue_build(key: String, x: int, y: int, rot: int) -> String:
	if queue().size() >= QUEUE_MAX:
		return "Die Warteschlange ist voll (%d Aufträge)" % QUEUE_MAX
	var why := P.can_build(key)
	if why != "" and why != "Alle Baudrohnen sind beschäftigt" and not why.begins_with("Es fehl"):
		return why
	var s := P.size_of(key, rot)
	if not P.cells_free(x, y, s.x, s.y) or _queued_at(x, y, s):
		return "Hier ist kein Platz"
	queue().append({"kind": "build", "key": key, "x": x, "y": y, "rot": rot})
	Sfx.play("queue_add", -6.0)
	P.mark()
	P.changed.emit()
	return ""


static func _queued_at(x: int, y: int, s: Vector2i) -> bool:
	var r := Rect2i(x, y, s.x, s.y)
	for q in queue():
		if String(q.kind) == "build":
			var qs := P.size_of(String(q.key), int(q.rot))
			if r.intersects(Rect2i(int(q.x), int(q.y), qs.x, qs.y)):
				return true
	return false


static func queue_upgrade(id: int) -> String:
	if queue().size() >= QUEUE_MAX:
		return "Die Warteschlange ist voll (%d Aufträge)" % QUEUE_MAX
	for q in queue():
		if String(q.kind) == "up" and int(q.id) == id:
			return "Schon vorgemerkt"
	var b := P.get_building(id)
	if b.is_empty():
		return "?"
	queue().append({"kind": "up", "id": id, "key": String(b.key), "level": int(b.level) + 1})
	Sfx.play("queue_add", -6.0)
	P.mark()
	P.changed.emit()
	return ""


static func queued_upgrade(id: int) -> bool:
	for q in queue():
		if String(q.kind) == "up" and int(q.id) == id:
			return true
	return false


static func queue_remove(i: int) -> void:
	if i >= 0 and i < queue().size():
		queue().remove_at(i)
		P.mark()
		P.changed.emit()


static func queue_name(q: Dictionary) -> String:
	var nm := String(D.BUILDINGS[String(q.key)].name)
	return "%s → Stufe %d" % [nm, int(q.level)] if String(q.kind) == "up" else nm


## Startet vorgemerkte Aufträge der Reihe nach, sobald eine Drohne frei ist und die Rohstoffe reichen.
static func queue_tick() -> void:
	var q := queue()
	var guard := 0
	while q.size() > 0 and guard < QUEUE_MAX:
		guard += 1
		var e: Dictionary = q[0]
		if String(e.kind) == "build":
			var key := String(e.key)
			var s := P.size_of(key, int(e.rot))
			if not P.cells_free(int(e.x), int(e.y), s.x, s.y):
				q.remove_at(0)
				P.toast.emit("Vorgemerkt: %s – der Platz ist inzwischen belegt" % String(D.BUILDINGS[key].name))
				continue
			var why := P.can_build(key)
			if why != "":
				if why == "Alle Baudrohnen sind beschäftigt" or why.begins_with("Es fehl"):
					return
				q.remove_at(0)
				P.toast.emit("Vorgemerkt: %s – %s" % [String(D.BUILDINGS[key].name), why])
				continue
			q.remove_at(0)
			if not P.place(key, int(e.x), int(e.y), int(e.rot)).is_empty():
				P.toast.emit("Vorgemerkter Bau startet: %s" % String(D.BUILDINGS[key].name))
				Sfx.play("queue_start", -5.0)
		else:
			var b := P.get_building(int(e.id))
			if b.is_empty() or int(b.level) + 1 != int(e.level):
				q.remove_at(0)
				continue
			var why2 := P.can_upgrade(int(e.id))
			if why2 != "":
				if why2 == "Alle Baudrohnen sind beschäftigt" or why2.begins_with("Es fehl") or why2 == "Wird gerade gebaut":
					return
				q.remove_at(0)
				P.toast.emit("Vorgemerkt: %s – %s" % [String(D.BUILDINGS[String(b.key)].name), why2])
				continue
			q.remove_at(0)
			if P.upgrade(int(e.id)):
				P.toast.emit("Vorgemerkte Verbesserung startet: %s" % String(D.BUILDINGS[String(b.key)].name))
				Sfx.play("queue_start", -5.0)
		P.mark()
		P.changed.emit()


# ================================================================= Mauer-Reihe verbessern
## Zusammenhängende Mauerstücke in einer Reihe (waagerecht oder senkrecht, die längere) mit gleicher Art wie dieses Stück.
static func wall_row(id: int) -> Array:
	var b := P.get_building(id)
	if b.is_empty() or b.key != "wall" or P.is_building(b):
		return []
	var at := {}
	for w in P.d.buildings:
		if w.key == "wall" and not P.is_building(w) and int(w.level) == int(b.level):
			at[Vector2i(int(w.x), int(w.y))] = w
	var best: Array = []
	for dir: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
		var line: Array = [b]
		for sg: int in [1, -1]:
			var c: Vector2i = Vector2i(int(b.x), int(b.y)) + dir * sg
			while at.has(c):
				line.append(at[c])
				c += dir * sg
		if line.size() > best.size():
			best = line
	return best


## Vorschau für eine Liste von Mauerstücken: {n, cost, hp0, hp1, time}
static func wall_row_preview(list: Array) -> Dictionary:
	if list.is_empty():
		return {}
	var lv := int(list[0].level)
	var c1: Dictionary = P.cost_for("wall", lv + 1)
	var cost := {}
	for r in c1:
		cost[r] = int(c1[r]) * list.size()
	var base: float = float(D.BUILDINGS.wall.hp) * (1.0 + P.cmd_bonus("wall_hp")) * (1.0 + P.outpost_bonus("wall_hp"))
	return {"n": list.size(), "cost": cost, "hp0": int(base * float(D.WALL_TIERS[clampi(lv - 1, 0, 2)].hp)),
		"hp1": int(base * float(D.WALL_TIERS[clampi(lv, 0, 2)].hp)), "time": P.time_for("wall", lv + 1) * list.size(),
		"name1": String(D.WALL_TIERS[clampi(lv, 0, 2)].name), "ok": lv < P.max_level("wall")}


## Verbessert genau diese Stücke als einen Auftrag (eine Drohne). Rückgabe: Zahl der gestarteten Stücke.
static func upgrade_wall_list(list: Array) -> int:
	if list.is_empty():
		return 0
	var lvl := int(list[0].level)
	if lvl >= P.max_level("wall"):
		P.toast.emit("Bessere Mauern erst mit höherem Bunker")
		return 0
	if P.drones_busy() >= P.drones_total() and not G.ch("nolimit"):
		P.toast.emit("Alle Baudrohnen sind beschäftigt")
		return 0
	var per := P.time_for("wall", lvl + 1)
	var cost := P.cost_for("wall", lvl + 1)
	var job: int = P._new_job()
	var start := P.now()
	var n := 0
	for b in list:
		if int(b.level) != lvl or P.is_building(b) or n >= D.WALL_JOB_MAX:
			continue
		if not P.pay(cost):
			if n == 0:
				P.toast.emit(P.missing_text(cost))
			break
		if per <= 0.0:
			b.level = lvl + 1
		else:
			b.job = job
			b.up = true
			b.t0 = start
			start += per
			b.done_at = start
		n += 1
	if n > 0:
		Sfx.play("upgrade_start", -6.0, 1.0, 0.2)
		P.buildings_changed.emit()
		P.mark()
	return n


# ================================================================= Vorschau der Werte bei Stufenaufstieg
## Zeilen [Bild, Name, vorher, nachher] für das Auswahlfenster.
static func upgrade_preview(key: String, lv: int) -> Array:
	var def: Dictionary = D.BUILDINGS[key]
	var out: Array = []
	if def.has("tower"):
		var t: Dictionary = D.TOWERS[def.tower]
		var d0: float = float(t.damage) * float(t.rpm) / 60.0 * pow(D.TOWER_DMG_GROWTH, lv - 1)
		out.append(["ui_sword", "Schaden pro Sekunde", str(int(d0)), str(int(d0 * D.TOWER_DMG_GROWTH))])
	if def.has("prod"):
		var r0: float = float(def.rate) * pow(1.3, lv - 1) * (1.0 + P.outpost_bonus("prod_" + String(def.prod)))
		out.append(["res_" + String(def.prod), "%s pro Stunde" % String(D.RES_NAME[def.prod]), "+%d" % int(r0), "+%d" % int(r0 * 1.3)])
	if key == "bunker":
		out.append(["ui_heart", "Haltbarkeit", str(int(D.bunker_hp(lv))), str(int(D.bunker_hp(lv + 1)))])
		if int(D.DRONES_BY_BUNKER[clampi(lv, 1, 10) - 1]) != int(D.DRONES_BY_BUNKER[clampi(lv + 1, 1, 10) - 1]):
			out.append(["ui_drone", "Baudrohnen", str(int(D.DRONES_BY_BUNKER[clampi(lv, 1, 10) - 1])), str(int(D.DRONES_BY_BUNKER[clampi(lv + 1, 1, 10) - 1]))])
		out.append(["ui_grid", "Baufeld", "%d × %d" % [D.GRID_BY_BUNKER[clampi(lv, 1, 10) - 1], D.GRID_BY_BUNKER[clampi(lv, 1, 10) - 1]],
			"%d × %d" % [D.GRID_BY_BUNKER[clampi(lv + 1, 1, 10) - 1], D.GRID_BY_BUNKER[clampi(lv + 1, 1, 10) - 1]]])
	elif float(def.get("hp", 0.0)) > 0.0 and def.cat != "wall":
		var hp := float(def.hp) * pow(1.18, lv - 1)
		out.append(["ui_heart", "Haltbarkeit", str(int(round(hp))), str(int(round(hp * 1.18)))])
	if key == "lager":
		for r in ["wood", "stone"]:
			var c0 := P.cap(r)
			var c1 := int(round(float(D.CAP_BASE[r]) * 0.6)) + c0
			out.append(["res_" + r, "Lager %s" % String(D.RES_NAME[r]), _fmt(c0), _fmt(c1)])
	if key == "training":
		out.append(["ui_star", "Erfahrung pro Stunde", "+%d" % int(D.TRAIN_XP_PER_HOUR + D.TRAIN_XP_PER_LEVEL * (lv - 1)), "+%d" % int(D.TRAIN_XP_PER_HOUR + D.TRAIN_XP_PER_LEVEL * lv)])
	return out


# ================================================================= Flut: Schwierigkeit, Wellen-Vorschau, Tutorial-Flut
static func flood_diff() -> int:
	var fd: Dictionary = P.d.get("flood_diff", {})
	if int(fd.get("week", -1)) != int(P.d.week.number):
		return 0
	return clampi(int(fd.get("lvl", 0)), 0, DF.FLOOD_DIFFS.size() - 1)


static func set_flood_diff(i: int) -> void:
	P.d.flood_diff = {"week": int(P.d.week.number), "lvl": clampi(i, 0, DF.FLOOD_DIFFS.size() - 1)}
	P.mark()


## Aus base_world.flood_preview(): Schwierigkeit (echte Flut) bzw. Tutorial-Flut einrechnen.
static func apply_flood(fd: Dictionary, practice: bool, tutorial: bool) -> void:
	if tutorial:
		fd.waves = int(DF.TUT_FLOOD.waves)
		fd.total = int(DF.TUT_FLOOD.total)
		fd.hp = float(DF.TUT_FLOOD.hp)
		fd.dmg = float(DF.TUT_FLOOD.dmg)
		fd.boss = false
		fd["guests"] = []
		fd["guest_text"] = ""
		fd["tutorial"] = true
		return
	if practice:
		return
	var df: Dictionary = DF.FLOOD_DIFFS[flood_diff()]
	fd.total = int(round(float(fd.total) * float(df.count)))
	fd.hp = float(fd.hp) * float(df.hp)
	fd["diff"] = flood_diff()


## Aus base_world._finish(): Zusatzbeute der schweren Flut, Ende der Tutorial-Flut, Zähler für Übungen.
## Ergänzt das Ergebnis um "bonus" (Rohstoffe) bzw. "tutorial".
static func flood_end(result: Dictionary, mode: String, win: bool, tutorial: bool) -> void:
	if tutorial:
		P.d.tut.flood = true
		var rw: Dictionary = DF.TUT_FLOOD_REWARD
		give(rw, "Übungsflut")
		result["tutorial"] = true
		result["bonus"] = rw.duplicate()
		P.mark()
		return
	if mode == "practice":
		if win:
			P.count_up("practice", 1)
		return
	var lvl := flood_diff()
	if lvl <= 0 or not win:
		return
	var k := float(DF.FLOOD_DIFFS[lvl].loot)
	var wk := int(P.d.week.number)
	var bonus := {"coins": int(round((100 * wk + 50 * int(result.get("stars", 1))) * k)), "gems": int(round(float(D.GEM_REWARD.flood) * k))}
	if int(DF.FLOOD_DIFF_SHARDS[lvl]) > 0:
		bonus["shards"] = int(DF.FLOOD_DIFF_SHARDS[lvl])
	give(bonus, "Flut (%s)" % String(DF.FLOOD_DIFFS[lvl].name))
	result["bonus"] = bonus
	result["diff"] = lvl
	result["points"] = int(round(float(result.get("points", 0)) * (1.0 + k * 0.5)))


## Welche Gegnerarten kommen in Welle idx (1 …)? Ohne Zufall, gleiche Regeln wie base_world._next_wave().
static func wave_types(fl: Dictionary, idx: int, count: int) -> Array:
	var out: Array = []
	var mix: Array = fl.get("mix", D.flood_mix(int(P.d.week.number)))
	var wsum := 0.0
	for i in count:
		wsum += 1.0 + i * 0.5
	var n := int(round(float(fl.total) * (1.0 + (idx - 1) * 0.5) / maxf(wsum, 1.0)))
	var guests: Array = fl.get("guests", [])
	var gn := int(round(n * float(fl.get("guest_share", 0.0)) * (0.5 if idx == 1 else 1.0))) if not guests.is_empty() else 0
	var sn := n - gn
	var msum := 0.0
	for v in mix:
		msum += float(v)
	var order: Array = []
	for t in mix.size():
		var cnt := int(round(sn * float(mix[t]) / maxf(msum, 0.001)))
		if t > 0 and idx == 1:
			cnt = int(cnt / 2)
		if cnt > 0:
			order.append([cnt if t > 0 else 1000000, t])     # Schleimlinge zuerst, dann die häufigsten Sonderarten
	order.sort_custom(func(a, b): return a[0] > b[0])
	for k in order.size():
		if k >= 5:
			out.append("%d weitere" % (order.size() - 5))
			break
		out.append(String(D.ENEMIES[int(order[k][1])].name))
	for g in guests:
		if gn > 0:
			out.append("Gäste: " + String(D.FAMILIES[String(g)].name))
	if idx == count and bool(fl.get("boss", false)):
		out.append("Boss")
	return out


static func wave_text(fl: Dictionary, idx: int, count: int) -> String:
	var t: Array = wave_types(fl, idx, count)
	return " + ".join(t) if t.size() > 0 else "Schleimlinge"


# ================================================================= Gebäudeschaden nach der Flut speichern (Kapitel 16)
## Aus base_world (Friedensbetrieb, jede Sekunde): Schaden der Gebäude in den Spielstand schreiben.
static func store_damage(world: Node) -> void:
	var changed := false
	for id in world.nodes:
		var s: Node3D = world.nodes[id]
		if s.b.is_empty() or s == world.bunker_node:
			continue
		var b: Dictionary = s.b
		var miss := 0.0
		if s.max_hp > 0.0 and s.hp < s.max_hp - 0.5:
			miss = snappedf(1.0 - s.hp / s.max_hp, 0.01)
		if miss > 0.0:
			if absf(float(b.get("dmg", 0.0)) - miss) >= 0.01:
				b["dmg"] = miss
				changed = true
		elif b.has("dmg"):
			b.erase("dmg")
			changed = true
	if changed:
		P.mark()


## Beim Aufbau eines Gebäudes: gespeicherten Schaden wieder anlegen.
static func apply_damage(s: Node3D, b: Dictionary) -> void:
	var miss := float(b.get("dmg", 0.0))
	if miss <= 0.0 or s.max_hp <= 0.0:
		return
	s.hp = clampf(s.max_hp * (1.0 - miss), 1.0, s.max_hp)
	s._update_damage()
	s._show_bar()
