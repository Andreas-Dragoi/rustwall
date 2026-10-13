extends RefCounted
## V6 Paket M – Spielmodi: Regeln für den Turm der Prüfungen, den Überlebensmodus, den Clan-Raid und die Höhlen.
## Nur statische Funktionen; der Spielstand liegt in P.d.modi (angelegt in ensure() aus P._ensure_fields()).
## Zahlen und Texte: src/data_modi.gd. Kampfwelten: src/modi_arena.gd (Turm, Überleben), src/cave_world.gd (Höhle),
## Clan-Raid in der gemeinsamen Kampfwelt des Weltbosses (liveops.gd: raid_fight). Server: src/modi_net.gd.
##
## Wochen wie am Server und im Live-Betrieb (Montag 0:00 UTC, LO.week_index()). Ranglisten: vom Server, wenn verbunden
## und aktuell, sonst simuliert (feste Mitspieler je Woche).

const D = preload("res://src/data.gd")
const DM = preload("res://src/data_modi.gd")
const DL = preload("res://src/data_liveops.gd")
const LO = preload("res://src/liveops.gd")

static var last_floor := 0            # zuletzt gespieltes Stockwerk (für „Nächstes Stockwerk“ im Ergebnis)


# ================================================================= Spielstand
static func ensure(d: Dictionary) -> void:
	if not d.has("modi") or not (d.modi is Dictionary):
		d["modi"] = {}
	var m: Dictionary = d.modi
	for k in [["tower", {}], ["surv", {}], ["raid", {}], ["caves", {}], ["srv", {}]]:
		if not m.has(k[0]) or not (m[k[0]] is Dictionary):
			m[k[0]] = k[1]
	var t: Dictionary = m.tower
	for k in [["stars", {}], ["time", {}], ["week_pts", {}]]:
		if not t.has(k[0]) or not (t[k[0]] is Dictionary):
			t[k[0]] = k[1]
	for k in [["claimed", []]]:
		if not t.has(k[0]) or not (t[k[0]] is Array):
			t[k[0]] = k[1]
	for k in [["best", 0], ["week", -1], ["runs", 0], ["sent", 0]]:
		t[k[0]] = int(t.get(k[0], k[1]))
	var s: Dictionary = m.surv
	for k in [["best", 0], ["best_wave", 0], ["runs", 0], ["week", -1], ["week_best", 0], ["sent", 0]]:
		s[k[0]] = int(s.get(k[0], k[1]))
	if not s.has("claimed") or not (s.claimed is Array):
		s["claimed"] = []
	var r: Dictionary = m.raid
	for k in [["week", -1], ["dmg", 0], ["hits", 0], ["day", -1], ["tries", 0], ["best", 0], ["total_hits", 0]]:
		r[k[0]] = int(r.get(k[0], k[1]))
	if not r.has("claimed") or not (r.claimed is Array):
		r["claimed"] = []
	var c: Dictionary = m.caves
	for k in [["done", 0], ["chests", 0], ["ore", 0]]:
		c[k[0]] = int(c.get(k[0], k[1]))


static func st() -> Dictionary:
	if not P.d.has("modi"):
		ensure(P.d)
	return P.d.modi


static func week() -> int:
	return LO.week_index()


static func give(bundle: Dictionary, why: String) -> void:
	if not bundle.is_empty():
		LO.grant(bundle, why)


static func bundle_text(b: Dictionary) -> String:
	return LO.bundle_text(b)


# ================================================================= Turm der Prüfungen
static func tower() -> Dictionary:
	var t: Dictionary = st().tower
	if int(t.week) != week():
		t.week = week()
		t.week_pts = {}
		t.sent = 0
	return t


static func floor_def(f: int) -> Dictionary:
	return DM.FLOORS[clampi(f, 1, DM.TOWER_FLOORS) - 1]


static func block_of(f: int) -> int:
	return clampi(int((f - 1) / 10), 0, DM.TOWER_BLOCKS.size() - 1)


static func floor_stars(f: int) -> int:
	return int(tower().stars.get(str(f), 0))


static func floor_unlocked(f: int) -> bool:
	if f <= 1 or G.ch("nolimit"):
		return true
	return floor_stars(f - 1) > 0


static func total_stars() -> int:
	var n := 0
	for k in tower().stars:
		n += int(tower().stars[k])
	return n


static func best_floor() -> int:
	return int(tower().best)


## Nächstes Stockwerk, das noch nicht geschafft ist (oder 50).
static func next_floor() -> int:
	for f in range(1, DM.TOWER_FLOORS + 1):
		if floor_stars(f) == 0:
			return f
	return DM.TOWER_FLOORS


static func floor_best_time(f: int) -> float:
	return float(tower().time.get(str(f), 0.0))


## Beschreibung der Aufgabe (aus Vorlagen zusammengesetzt, damit die Übersetzung sie erkennt).
static func floor_text(f: int) -> String:
	var fd := floor_def(f)
	var fam := String(D.FAMILIES[String(fd.fam)].name) if D.FAMILIES.has(String(fd.fam)) else ""
	var t := ""
	match String(fd.task):
		"survive":
			t = "Überlebe %d Sekunden gegen %s." % [int(fd.t), fam]
		"defend":
			t = "Verteidige den Generator gegen %d Wellen." % fd.waves.size()
		"timed":
			t = "Besiege alle Gegner in %d Sekunden." % int(fd.t)
		"boss":
			t = "Besiege %s." % String(D.enemy(String(fd.boss)).name)
		_:
			t = "Besiege alle Gegner (%d Wellen)." % fd.waves.size() if fd.waves.size() > 1 else "Besiege alle Gegner."
	var mods: Array = fd.get("mods", [])
	var extra: Array = []
	for mk in mods:
		match String(mk):
			"noskill":
				extra.append("Ohne Fähigkeiten")
			"melee":
				extra.append("Nur Nahkampf")
			"noheal":
				extra.append("Ohne Heilung")
			"fast":
				extra.append("Flinke Gegner")
	if not extra.is_empty():
		t += " " + " · ".join(extra)
	return t


## Sterne-Regeln als Text für die Anzeige.
static func star_rules(f: int) -> Array:
	var fd := floor_def(f)
	var out: Array = ["Stockwerk geschafft"]
	out.append("Am Ende mindestens %d %% Leben" % int(DM.TOWER_STAR2_HP * 100.0))
	if String(fd.task) == "survive":
		out.append("Am Ende mindestens %d %% Leben" % int(DM.TOWER_STAR3_HP * 100.0))
	else:
		out.append("Schneller als %d Sekunden" % int(fd.par))
	return out


static func calc_stars(f: int, win: bool, time_s: float, hp_ratio: float) -> int:
	if not win:
		return 0
	var fd := floor_def(f)
	var s := 1
	if hp_ratio >= DM.TOWER_STAR2_HP:
		s += 1
	if String(fd.task) == "survive":
		if hp_ratio >= DM.TOWER_STAR3_HP:
			s += 1
	elif time_s <= float(fd.par):
		s += 1
	return s


## Ergebnis eines Laufs auf Stockwerk f eintragen. Rückgabe: Angaben für den Ergebnisbildschirm.
static func tower_finish(f: int, win: bool, time_s: float, hp_ratio: float) -> Dictionary:
	var t := tower()
	t.runs = int(t.runs) + 1
	last_floor = f
	var stars := calc_stars(f, win, time_s, hp_ratio)
	var before := floor_stars(f)
	var out := {"floor": f, "stars": stars, "before": before, "first": false, "reward": {}, "pts": 0, "time": time_s, "best_time": floor_best_time(f)}
	if not win:
		return out
	var key := str(f)
	if stars > before:
		t.stars[key] = stars
	var bt := floor_best_time(f)
	if bt <= 0.0 or time_s < bt:
		t.time[key] = snappedf(time_s, 0.1)
		out["record"] = bt > 0.0
	if before == 0:
		out.first = true
		var rw := DM.floor_reward(f)
		give(rw, "Turm Stockwerk %d" % f)
		out.reward = rw
		t.best = maxi(int(t.best), f)
		P.count_up("tower_floors", 1)
	var pts := DM.floor_points(f, stars)
	if pts > int(t.week_pts.get(key, 0)):
		t.week_pts[key] = pts
	out.pts = pts
	out["week_score"] = tower_week_score()
	LO.on_progress("practice", 1)                     # zählt für Ereignisse wie eine Übung
	push_scores()
	P.mark()
	return out


static func tower_week_score() -> int:
	var n := 0
	var wp: Dictionary = tower().week_pts
	for k in wp:
		n += int(wp[k])
	return n


static func star_reward_ready(i: int) -> bool:
	return total_stars() >= int(DM.STAR_REWARDS[i][0]) and not (i in tower().claimed or float(i) in tower().claimed)


static func star_reward_claimed(i: int) -> bool:
	return i in tower().claimed or float(i) in tower().claimed


static func claim_star_reward(i: int) -> String:
	if not star_reward_ready(i):
		return "Noch nicht genug Sterne."
	tower().claimed.append(i)
	give(DM.STAR_REWARDS[i][1], "Turm: %d Sterne" % int(DM.STAR_REWARDS[i][0]))
	P.mark()
	return ""


static func star_rewards_open() -> int:
	var n := 0
	for i in DM.STAR_REWARDS.size():
		if star_reward_ready(i):
			n += 1
	return n


# ================================================================= Überlebensmodus
static func surv() -> Dictionary:
	var s: Dictionary = st().surv
	if int(s.week) != week():
		s.week = week()
		s.week_best = 0
		s.sent = 0
	return s


## Lauf beendet: Punkte, Bestwerte, Münzen und einmalige Wellen-Belohnungen.
static func surv_finish(score: int, wave: int, kills: int) -> Dictionary:
	var s := surv()
	s.runs = int(s.runs) + 1
	var out := {"score": score, "wave": wave, "kills": kills, "record": score > int(s.best), "rewards": [], "coins": 0}
	s.best = maxi(int(s.best), score)
	s.week_best = maxi(int(s.week_best), score)
	s.best_wave = maxi(int(s.best_wave), wave)
	var coins := int(score * DM.SURV_COIN_K)
	if coins > 0:
		P.add("coins", coins)
	out.coins = coins
	for i in DM.SURV_WAVE_REWARDS.size():
		var e: Array = DM.SURV_WAVE_REWARDS[i]
		if wave >= int(e[0]) and not (i in s.claimed or float(i) in s.claimed):
			s.claimed.append(i)
			give(e[1], "Überleben: Welle %d" % int(e[0]))
			out.rewards.append([int(e[0]), e[1]])
	P.count_up("survival_runs", 1)
	LO.on_progress("practice", 1)
	push_scores()
	P.mark()
	return out


# ================================================================= Ranglisten (wöchentlich)
## kind: "tower" | "surv". Vom Server (wenn verbunden und aus dieser Woche), sonst simuliert.
static func board(kind: String) -> Array:
	var srv: Dictionary = st().srv.get(kind, {})
	if int(srv.get("week", -1)) == week() and srv.get("entries") is Array and not (srv.entries as Array).is_empty() and P.social != null and P.social.online():
		var out: Array = []
		for e in srv.entries:
			out.append({"name": String(e.get("name", "?")), "score": int(e.get("score", 0)), "me": bool(e.get("me", false))})
		return out
	var mine := tower_week_score() if kind == "tower" else int(surv().week_best)
	var frac := clampf(1.0 - LO.week_left() / DL.WEEK_S, 0.05, 1.0)
	var out2: Array = []
	var rng := RandomNumberGenerator.new()
	for i in 29:
		rng.seed = hash("rw-modi-%s-%d-%d" % [kind, week(), i])
		var pace := rng.randf_range(0.12, 1.0)
		var sc := 0
		if kind == "tower":
			var reach := int(round(DM.TOWER_FLOORS * pace * clampf(frac * 1.6, 0.2, 1.0)))
			for f in range(1, reach + 1):
				sc += DM.floor_points(f, 2 if rng.randf() < 0.6 else (3 if rng.randf() < 0.5 else 1))
		else:
			sc = int(42000.0 * pace * pace * sqrt(frac) * rng.randf_range(0.8, 1.2))
		out2.append({"name": String(DL.BOT_NAMES[(i + (3 if kind == "tower" else 17) + week() % 7) % DL.BOT_NAMES.size()]), "score": sc, "me": false})
	out2.append({"name": String(P.d.get("name", "Kommandant")), "score": mine, "me": true})
	out2.sort_custom(func(a, b): return int(a.score) > int(b.score) or (int(a.score) == int(b.score) and bool(a.me)))
	return out2


static func my_rank(kind: String) -> int:
	var b := board(kind)
	for i in b.size():
		if bool(b[i].me):
			return i + 1
	return b.size()


static func net_node() -> Node:
	if P.social == null or P.social.get("net") == null:
		return null
	var net: Node = P.social.net
	var n := net.get_node_or_null("Modi")
	if n == null:
		n = load("res://src/modi_net.gd").new()
		n.name = "Modi"
		net.add_child(n)
	return n


## Neue Wochenwerte an den Server schicken (wenn verbunden).
static func push_scores() -> void:
	if P.social == null or not P.social.online():
		return
	var n := net_node()
	if n != null:
		n.push()


static func net_refresh() -> void:
	if P.social == null or not P.social.online():
		return
	var n := net_node()
	if n != null:
		n.pull()


# ================================================================= Clan-Raid
static func raid() -> Dictionary:
	var r: Dictionary = st().raid
	if int(r.week) != week():
		r.week = week()
		r.dmg = 0
		r.hits = 0
		r.claimed = []
	var day := P.day_index()
	if int(r.day) != day:
		r.day = day
		r.tries = 0
	return r


static func has_clan() -> bool:
	return P.social != null and P.social.has_clan()


static func clan_name() -> String:
	return String(P.social.s.clan.get("name", "")) if has_clan() else ""


static func _members() -> Array:
	if not has_clan():
		return []
	return P.social.s.clan.get("members", [])


static func raid_hp() -> int:
	var srv: Dictionary = st().srv.get("raid", {})
	if int(srv.get("week", -1)) == week() and srv.has("hp") and _srv_raid_ok():
		return maxi(1, int(srv.hp))
	return (_members().size() + 1) * DM.RAID_HP_PER_MEMBER


static func _srv_raid_ok() -> bool:
	return P.social != null and P.social.online()


## Simulierter Beitrag eines Mitglieds bis jetzt (fest je Woche und Name).
static func sim_member_dmg(m: Dictionary) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("rw-raid-%s-%d" % [String(m.get("name", "?")), week()])
	var part := rng.randf_range(0.4, 1.0)
	var per := DM.RAID_SIM_BASE + DM.RAID_SIM_LEVEL * float(m.get("level", 10)) * rng.randf_range(0.8, 1.2)
	var days := clampf((1.0 - LO.week_left() / DL.WEEK_S) * 7.0, 0.0, 7.0)
	return int(per * float(DM.RAID_TRIES) * days * part)


## Mitglieder mit Schaden dieser Woche (Server oder simuliert), absteigend; „me“ = du.
static func raid_members() -> Array:
	var out: Array = []
	var srv: Dictionary = st().srv.get("raid", {})
	if int(srv.get("week", -1)) == week() and srv.get("members") is Array and _srv_raid_ok():
		for m in srv.members:
			out.append({"name": String(m.get("name", "?")), "dmg": int(m.get("dmg", 0)), "me": bool(m.get("me", false)), "level": int(m.get("level", 0))})
		var has_me := false
		for m in out:
			if bool(m.me):
				has_me = true
				m.dmg = maxi(int(m.dmg), int(raid().dmg))
		if not has_me:
			out.append({"name": String(P.d.get("name", "Kommandant")), "dmg": int(raid().dmg), "me": true, "level": int(P.d.level)})
	else:
		for m in _members():
			out.append({"name": String(m.get("name", "?")), "dmg": sim_member_dmg(m), "me": false, "level": int(m.get("level", 1))})
		out.append({"name": String(P.d.get("name", "Kommandant")), "dmg": int(raid().dmg), "me": true, "level": int(P.d.level)})
	out.sort_custom(func(a, b): return int(a.dmg) > int(b.dmg))
	return out


static func raid_total() -> int:
	var srv: Dictionary = st().srv.get("raid", {})
	if int(srv.get("week", -1)) == week() and srv.has("dmg") and _srv_raid_ok():
		return maxi(int(srv.dmg), int(raid().dmg))
	var n := 0
	for m in raid_members():
		n += int(m.dmg)
	return n


static func raid_progress() -> float:
	return clampf(float(raid_total()) / float(raid_hp()), 0.0, 1.0)


static func raid_tries_left() -> int:
	return maxi(0, DM.RAID_TRIES - int(raid().tries))


## Darf jetzt angegriffen werden? "" oder der Grund.
static func can_raid() -> String:
	if not has_clan():
		return "Der Clan-Raid braucht einen Clan. Tritt im Funkturm-Menü „Clan“ einem Clan bei."
	if raid_tries_left() <= 0:
		return "Heute keine Angriffe mehr – morgen geht es weiter."
	if raid_progress() >= 1.0:
		return "Der Leviathan ist diese Woche schon besiegt. Holt euch die Belohnungen!"
	var w = G.main.world if G.main != null else null
	if w == null or w.get("mode") != "peace" or w.get("bunker_node") == null or not w.has_method("start_flood"):
		return "Angreifen kannst du nur in deiner Basis."
	return ""


## Startet einen Clan-Angriff in der gemeinsamen Kampfwelt des Weltbosses (liveops.gd). Rückgabe "" oder Grund.
static func start_raid() -> String:
	var why := can_raid()
	if why != "":
		return why
	var r := raid()
	r.tries = int(r.tries) + 1
	r.total_hits = int(r.total_hits) + 1
	LO.raid_fight(G.main.world, "clan")
	P.toast.emit("Clan-Raid: Der Schleim-Leviathan greift an! %d Sekunden – jeder Treffer zählt für %s." % [int(DL.BOSS_TIME), clan_name()])
	return ""


## Abrechnung eines Clan-Angriffs (aus LO.raid_result). Schaden steht in LO.raid_dmg.
static func raid_result(_win: bool, kills: int) -> Dictionary:
	var r := raid()
	var dmg := mini(int(LO.raid_dmg), DM.RAID_HIT_MAX)
	r.dmg = int(r.dmg) + dmg
	r.hits = int(r.hits) + 1
	r.best = maxi(int(r.best), dmg)
	var coins := 60 + int(dmg / 200)
	P.add("coins", coins)
	P.add_xp(30)
	P.d.stats.kills = int(P.d.stats.kills) + kills
	P.count_up("raid_hits", 1)
	if P.social != null and has_clan():
		P.social.add_clan_points(int(dmg / 2000) + 5)        # zählt auch für das Clan-Wochenziel
	var n := net_node()
	if n != null and _srv_raid_ok():
		n.raid_hit(dmg)
	P.mark()
	return {"win": true, "coins": coins, "xp": 30, "practice": true, "raid": true, "clan_raid": true, "title": "Clan-Angriff beendet!",
		"bonus": {"coins": coins}, "dmg": dmg, "progress": raid_progress()}


static func raid_tier_ready(i: int) -> bool:
	return raid_progress() * 100.0 >= float(DM.RAID_TIERS[i]) and int(raid().hits) > 0 and not raid_tier_claimed(i)


static func raid_tier_claimed(i: int) -> bool:
	return i in raid().claimed or float(i) in raid().claimed


static func raid_claim(i: int) -> String:
	if int(raid().hits) <= 0:
		return "Belohnungen gibt es, wenn du diese Woche mindestens einmal angegriffen hast."
	if not raid_tier_ready(i):
		return "Diese Stufe ist noch nicht erreicht."
	raid().claimed.append(i)
	give(DM.RAID_REWARDS[i], "Clan-Raid Stufe %d" % (i + 1))
	Sfx.play("raid_tier", -2.0)
	P.mark()
	return ""


static func raid_open() -> int:
	var n := 0
	for i in DM.RAID_TIERS.size():
		if raid_tier_ready(i):
			n += 1
	return n


# ================================================================= Höhlen
static func cave_theme(area: int) -> String:
	return String(DM.CAVE_THEME.get(String(D.AREAS[clampi(area, 0, D.AREAS.size() - 1)].key), "wurzel"))


static func cave_done(chest: bool, ore: bool) -> void:
	var c: Dictionary = st().caves
	c.done = int(c.done) + 1
	if chest:
		c.chests = int(c.chests) + 1
	if ore:
		c.ore = int(c.ore) + 1
	P.count_up("caves", 1)
	P.mark()


# ================================================================= Übersicht (Menü)
## Offene Belohnungen über alle Modi (Zahl am Menüknopf).
static func open_count() -> int:
	return star_rewards_open() + (raid_open() if has_clan() else 0)
