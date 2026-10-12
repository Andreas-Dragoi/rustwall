extends RefCounted
## Paket L – Live-Betrieb: Regeln für Wochen-Ereignisse, Feiertage, Saison und Saison-Pass, Kosmetik und
## Kosmetik-Shop, Wochenaufgaben, Login-Kalender, Nachrichten-Brett und Endspiel (Prestige, Albtraum+,
## Gebietsboss-Herausforderung der Außenbasen).
##
## Nur statische Funktionen; der Spielstand liegt in P.d.lo (angelegt in ensure() aus P._ensure_fields()).
## Zahlen und Texte: src/data_liveops.gd. Welt-Teile (Deko, Schnee, Eier, Hüte, Bunker-Skin, Weltboss-Kampf):
## src/liveops_world.gd. Server: src/liveops_net.gd (Zeitplan, Pass-Fortschritt, Saison-Rangliste, Weltboss).
##
## Andere Dateien rufen nur kleine Haken auf (je eine Zeile, mit „Paket L“ markiert):
##   P: tick, on_progress, on_daily_quest, on_daily_all, on_flood, on_expedition, daily_gift, build_mult, prestige_xp, prestige_bonus
##   horde: kill_coins, on_spawn, on_kill   hero: hero_skin, tint_weapon, nm_noheal   expedition: apply_nightmare, on_boss, outpost_gate
##   exp_world: caravan_mult, caravan_after   base_world: raid_result

const D = preload("res://src/data.gd")
const DL = preload("res://src/data_liveops.gd")
const Models = preload("res://src/models.gd")

static var force_event := ""          # Admin/Tests: dieses Ereignis gilt (überschreibt Server und Kalender)
# ---- Albtraum+ der laufenden Expedition (gesetzt von apply_nightmare / liveops_world.attach)
static var nm_explode := false
static var nm_noheal := false
static var nm_double := false
static var nm_swift := false
# ---- Weltboss-Kampf
static var raid_dmg := 0.0
static var _mats: Dictionary = {}
static var _tick_n := 0
static var _halloween := false
static var force_challenge := false   # Tests: Gebietsboss-Herausforderung auch in automatischen Läufen (sonst dort aus)        # Feiertag Halloween gerade aktiv (für den Haken in horde.spawn, je Welt neu bestimmt)


# ================================================================= Spielstand
static func ensure(d: Dictionary) -> void:
	if not d.has("lo") or not (d.lo is Dictionary):
		d["lo"] = {}
	var lo: Dictionary = d.lo
	for k in [["ev", {}], ["boss", {}], ["season", {}], ["weekly", {}], ["cal", {}], ["cos", {}], ["prestige", {}], ["op_ch", {}],
			["holiday", {}], ["srv", {}], ["srv_board", {}]]:
		if not lo.has(k[0]) or not (lo[k[0]] is Dictionary):
			lo[k[0]] = k[1]
	for k in [["nm", []], ["titles", []]]:
		if not lo.has(k[0]) or not (lo[k[0]] is Array):
			lo[k[0]] = k[1]
	for k in [["boost", 0], ["news_seen", 0], ["nm_wins", 0], ["eggs", 0], ["tick_week", -1]]:
		if not lo.has(k[0]):
			lo[k[0]] = k[1]
		lo[k[0]] = int(lo[k[0]])
	var c: Dictionary = lo.cos
	if not c.has("owned") or not (c.owned is Array):
		c["owned"] = []
	if not c.has("skin") or not (c.skin is Dictionary):
		c["skin"] = {}
	for k in ["wskin", "bskin", "flag", "hat"]:
		if not c.has(k):
			c[k] = ""
	if not lo.cal.has("idx"):
		lo.cal["idx"] = 0
	lo.cal.idx = int(lo.cal.idx)
	for hk in lo.prestige:
		var pr: Dictionary = lo.prestige[hk]
		pr["stars"] = int(pr.get("stars", 0))
		pr["xp"] = float(pr.get("xp", 0.0))


static func st() -> Dictionary:
	if not P.d.has("lo"):
		ensure(P.d)
	return P.d.lo


## Jede Sekunde aus P._time_passed(): Wochenwechsel, Saison-Ende, Erfolgs-Kosmetik, Feiertags-Geschenk.
static func tick(t: float) -> void:
	var lo := st()
	var w := week_index(t)
	if int(lo.tick_week) != w:
		lo.tick_week = w
		weekly()
		season()
	_tick_n += 1
	if _tick_n % 20 == 1:
		check_ach_cosmetics()
		holiday_gift()


# ================================================================= Zeit (Kalenderwochen wie am Server: Montag 0:00 UTC)
static func week_index(t := -1.0) -> int:
	if t < 0.0:
		t = P.now()
	return int(floor((floor(t / 86400.0) + 3.0) / 7.0))


static func week_start(w: int) -> float:
	return (float(w) * 7.0 - 3.0) * 86400.0


static func week_left() -> float:
	return maxf(0.0, week_start(week_index() + 1) - P.now())


# ================================================================= Wochen-Ereignisse
static func event_key() -> String:
	if force_event != "" and DL.EVENTS.has(force_event):
		return force_event
	var w := week_index()
	var srv: Dictionary = st().srv
	if int(srv.get("week", -1)) == w and DL.EVENTS.has(String(srv.get("event", ""))):
		return String(srv.event)
	return String(DL.EVENT_ORDER[posmod(w - DL.EPOCH_WEEK, DL.EVENT_ORDER.size())])


static func event_def(k := "") -> Dictionary:
	return DL.EVENTS[event_key() if k == "" else k]


## Ereignis der Woche w (Kalender; für die Vorschau „Nächste Woche“).
static func event_of_week(w: int) -> String:
	return String(DL.EVENT_ORDER[posmod(w - DL.EPOCH_WEEK, DL.EVENT_ORDER.size())])


static func is_event(k: String) -> bool:
	return event_key() == k


## Stand des Ereignisses dieser Woche (wird zu Wochenbeginn bzw. bei anderem Ereignis neu angelegt).
static func ev_state() -> Dictionary:
	var lo := st()
	var e: Dictionary = lo.ev
	var w := week_index()
	var k := event_key()
	if int(e.get("week", -1)) != w or String(e.get("key", "")) != k:
		lo.ev = {"week": w, "key": k, "pts": 0, "claimed": []}
		e = lo.ev
	return e


static func event_points() -> int:
	if bool(event_def().get("community", false)):
		return int(boss_state().dmg)
	return int(ev_state().pts)


## Fortschritt einer Belohnungsstufe 0..1 (Weltboss: Gemeinschafts-Fortschritt in Prozent).
static func event_tier_ratio(i: int) -> float:
	var def := event_def()
	var need := float(def.tiers[i])
	if bool(def.get("community", false)):
		return clampf(boss_progress() * 100.0 / need, 0.0, 1.0)
	return clampf(float(ev_state().pts) / need, 0.0, 1.0)


static func event_tier_ready(i: int) -> bool:
	if i in ev_state().claimed or float(i) in ev_state().claimed:
		return false
	if bool(event_def().get("community", false)) and int(boss_state().tries_total) <= 0:
		return false                                  # Weltboss: nur wer mitgekämpft hat
	return event_tier_ratio(i) >= 1.0


static func event_claimable() -> int:
	var n := 0
	for i in event_def().tiers.size():
		if event_tier_ready(i):
			n += 1
	return n


static func event_claim(i: int) -> String:
	if not event_tier_ready(i):
		return "Diese Stufe ist noch nicht erreicht."
	var k := event_key()
	ev_state().claimed.append(i)
	grant(DL.EVENT_REWARDS[k][i], "Ereignis %s" % String(event_def().name))
	season_add("event_tier")
	Sfx.play("event_claim", -3.0)
	P.mark()
	return ""


## In automatischen Tests und Bots wirken Ereignisse und Feiertage nur, wenn sie ausdrücklich gesetzt sind
## (force_event / Admin) – sonst hinge das Ergebnis vom Kalenderdatum ab.
static func _neutral() -> bool:
	return force_event == "" and (G.selftest or G.autotest != "")


## Faktor auf Münzen eines besiegten Gegners (Schleimregen, Goldrausch, Elite-Flut). Haken in horde._kill.
static func kill_coins(coins: int, fam: String, elite: bool) -> int:
	var k := "" if _neutral() else event_key()
	var f := 1.0
	if k == "schleimregen" and fam == "schleim":
		f = DL.EVENT_SLIME_LOOT
	elif k == "goldrausch":
		f = DL.EVENT_GOLD
	elif k == "eliteflut" and elite:
		f = DL.EVENT_ELITE_LOOT
	if elite:
		on_progress("elite_kill", 1)
	return int(round(coins * f))


static func extra_elites() -> int:
	return DL.EVENT_ELITES if is_event("eliteflut") and not _neutral() else 0


static func build_mult() -> float:
	return DL.EVENT_BUILD if is_event("bauwoche") and not _neutral() else 1.0


static func caravan_mult() -> float:
	return DL.EVENT_CARAVAN_PRICE if is_event("haendlerwoche") and not _neutral() else 1.0


static func caravan_after(base: float) -> float:
	return DL.EVENT_CARAVAN_AFTER if is_event("haendlerwoche") and not _neutral() else base


# ================================================================= Weltboss (Gemeinschaftskampf)
static func boss_state() -> Dictionary:
	var lo := st()
	var b: Dictionary = lo.boss
	var w := week_index()
	if int(b.get("week", -1)) != w:
		lo.boss = {"week": w, "dmg": 0, "day": -1, "tries": 0, "tries_total": 0, "best": 0}
		b = lo.boss
	if int(b.day) != P.day_index():
		b.day = P.day_index()
		b.tries = 0
	return b


static func boss_tries_left() -> int:
	return maxi(0, DL.BOSS_TRIES - int(boss_state().tries))


## Gemeinschafts-Fortschritt 0..1: vom Server, sonst simuliert (andere Kommandanten) plus eigener Schaden.
static func boss_progress() -> float:
	var srv: Dictionary = st().srv
	var own := float(boss_state().dmg)
	if int(srv.get("week", -1)) == week_index() and srv.has("boss_dmg"):
		return clampf(float(srv.boss_dmg) / float(srv.get("boss_hp", DL.BOSS_COMMUNITY_HP)), 0.0, 1.0)
	var frac := clampf(1.0 - week_left() / DL.WEEK_S, 0.0, 1.0)
	var sim := float(DL.BOSS_COMMUNITY_HP) * DL.BOSS_SIM_PACE * pow(frac, 0.9)
	return clampf((sim + own) / float(DL.BOSS_COMMUNITY_HP), 0.0, 1.0)


## Startet einen Angriff auf den Leviathan in der Basis. Rückgabe "" oder Grund.
static func start_raid() -> String:
	if not is_event("weltboss"):
		return "Der Leviathan erscheint nur in der Weltboss-Woche."
	if boss_tries_left() <= 0:
		return "Heute keine Angriffe mehr – morgen geht es weiter."
	var w = G.main.world if G.main != null else null
	if w == null or w.get("mode") != "peace" or w.get("bunker_node") == null or not w.has_method("start_flood"):
		return "Angreifen kannst du nur in deiner Basis."
	var b := boss_state()
	b.tries = int(b.tries) + 1
	b.tries_total = int(b.tries_total) + 1
	raid_dmg = 0.0
	w.start_flood(true)
	w._queue.clear()
	w.flood.total = 0
	w.flood["raid"] = true
	w.wave_count = 1
	var bn: Node3D = w.bunker_node
	var q: Vector2 = bn.mid + Vector2(0, bn.radius + 16.0)
	if w.field.is_solid(q):
		q = w.hero.pos2() + Vector2(0, -16)
	var e = w.horde.spawn(int(D.ENEMY_INDEX["boss_leviathan"]), q, DL.BOSS_HP_MULT, 1.0, 1.0)
	e.special = "cycle"
	e.coins = 0
	w.horde.boss = e
	w.horde.boss_name = String(D.enemy("boss_leviathan").name)
	w.set_meta("raid_t", 0.0)
	P.toast.emit("Der Schleim-Leviathan greift an! %d Sekunden – richte so viel Schaden an wie möglich." % int(DL.BOSS_TIME))
	Sfx.play("worldboss_horn", -2.0)
	Music.set_mood("boss")
	P.mark()
	return ""


## Ergebnis eines Weltboss-Angriffs (aus base_world._finish). raid_dmg setzt liveops_world.gd.
static func raid_result(_win: bool, kills: int) -> Dictionary:
	var b := boss_state()
	var dmg := int(raid_dmg)
	b.dmg = int(b.dmg) + dmg
	b.best = maxi(int(b.best), dmg)
	on_progress("boss_dmg", dmg)
	season_add("raid")
	var coins := 80 + int(dmg / 150)
	P.add("coins", coins)
	P.add_xp(40)
	P.d.stats.kills = int(P.d.stats.kills) + kills
	var net := net_node()
	if net != null:
		net.boss_hit(dmg)
	P.mark()
	return {"win": true, "coins": coins, "xp": 40, "practice": true, "raid": true, "title": "Angriff beendet!",
		"bonus": {"coins": coins}, "dmg": dmg}


# ================================================================= Feiertage
static func holiday() -> String:
	var f := String(st().holiday.get("force", ""))
	if f == "aus":
		return ""
	if f != "" and DL.HOLIDAYS.has(f):
		return f
	if G.selftest or G.autotest != "":
		return ""                                    # Tests: Feiertage nur erzwungen
	var dt := Time.get_datetime_dict_from_unix_time(int(P.now()))
	var m := int(dt.month)
	var dd := int(dt.day)
	for k in ["halloween", "weihnachten"]:
		var h: Dictionary = DL.HOLIDAYS[k]
		var a: int = int(h.from[0]) * 100 + int(h.from[1])
		var b: int = int(h.to[0]) * 100 + int(h.to[1])
		var x := m * 100 + dd
		if (a <= b and x >= a and x <= b) or (a > b and (x >= a or x <= b)):
			return k
	var e := easter(int(dt.year))
	var doy := _day_of_year(int(dt.year), m, dd)
	var edoy := _day_of_year(int(dt.year), int(e[0]), int(e[1]))
	if absi(doy - edoy) <= int(DL.HOLIDAYS.ostern.days):
		return "ostern"
	return ""


static func set_holiday_force(k: String) -> void:
	st().holiday["force"] = k
	P.mark()


## Ostersonntag [Monat, Tag] (gregorianisch, Gauß/Anonymus).
static func easter(y: int) -> Array:
	var a := y % 19
	var b := int(y / 100)
	var c := y % 100
	var d := int(b / 4)
	var e := b % 4
	var f := int((b + 8) / 25)
	var g := int((b - f + 1) / 3)
	var h := (19 * a + b - d - g + 15) % 30
	var i := int(c / 4)
	var k := c % 4
	var l := (32 + 2 * e + 2 * i - h - k) % 7
	var m := int((a + 11 * h + 22 * l) / 451)
	var month := int((h + l - 7 * m + 114) / 31)
	var day := ((h + l - 7 * m + 114) % 31) + 1
	return [month, day]


static func _day_of_year(y: int, m: int, d: int) -> int:
	var t := Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": 12, "minute": 0, "second": 0})
	var t0 := Time.get_unix_time_from_datetime_dict({"year": y, "month": 1, "day": 1, "hour": 12, "minute": 0, "second": 0})
	return int(round((t - t0) / 86400.0))


static func _holiday_tag(k: String) -> String:
	return "%s_%d" % [k, int(Time.get_datetime_dict_from_unix_time(int(P.now())).year)]


## Einmal je Feiertag und Jahr: Geschenk als Blase am Bunker (Juwelen) und das Feiertags-Kosmetikteil.
static func holiday_gift() -> void:
	var k := holiday()
	if k == "":
		return
	var tag := _holiday_tag(k)
	var hs: Dictionary = st().holiday
	if bool(hs.get(tag, false)):
		return
	hs[tag] = true
	var g: Dictionary = DL.HOLIDAYS[k].gift
	if g.has("gems"):
		P.add_pickup("holiday", "bunker", {"gems": int(g.gems)}, "%s-Geschenk" % String(DL.HOLIDAYS[k].name))
	if g.has("cos"):
		give(String(g.cos), String(DL.HOLIDAYS[k].name))
	P.toast.emit("%s! %s" % [String(DL.HOLIDAYS[k].name), String(DL.HOLIDAYS[k].text)])
	P.mark()


## Fortschritt des Feiertagsziels (Halloween: Schleime besiegen, Weihnachten: Kisten öffnen, Ostern: Eier finden).
const HOLIDAY_GOAL := {"halloween": ["kills", 300, "Besiege %d Gegner während Halloween"], "weihnachten": ["chests", 5, "Öffne %d Kisten an Weihnachten"],
	"ostern": ["eggs", 20, "Finde %d Ostereier"]}


static func holiday_goal_progress(k: String) -> int:
	return int(st().holiday.get(_holiday_tag(k) + "_n", 0))


static func _holiday_progress(key: String, n: int) -> void:
	var k := holiday()
	if k == "" or String(HOLIDAY_GOAL[k][0]) != key:
		return
	var hs: Dictionary = st().holiday
	var nk := _holiday_tag(k) + "_n"
	var before := int(hs.get(nk, 0))
	hs[nk] = before + n
	var goal := int(HOLIDAY_GOAL[k][1])
	if before < goal and before + n >= goal:
		give(String(DL.HOLIDAYS[k].gift2), String(DL.HOLIDAYS[k].name))


## Osterei gefunden (liveops_world.gd). all = alle Eier dieser Expedition gefunden.
static func egg_found(all: bool) -> void:
	st().eggs = int(st().eggs) + 1
	grant(DL.EGG_REWARD, "Osterei")
	_holiday_progress("eggs", 1)
	if all:
		grant(DL.EGG_ALL_REWARD, "Alle Ostereier")
		P.toast.emit("Alle Ostereier gefunden! Eine Geschenkkiste wartet.")
	P.mark()


# ================================================================= Fortschritt (Haken in P.quest_progress und Co.)
## key wie in P.quest_progress (kills, expeditions, wood, chests, builds, coins, skills, practice, donate) und
## eigene Schlüssel: flood_win, elite_kill, boss_dmg, daily_all.
static func on_progress(key: String, n: int) -> void:
	if n <= 0 or not P.d.has("lo"):
		return
	# Ereignis
	var def := event_def()
	var pts: Dictionary = def.points
	if pts.has(key) and not bool(def.get("community", false)):
		var e := ev_state()
		var before := event_claimable()
		e.pts = int(e.pts) + n * int(pts[key])
		if event_claimable() > before:
			P.toast.emit("Ereignis %s: neue Belohnung bereit!" % String(def.name))
			Sfx.play("event_tier", -4.0)
	# Saison
	match key:
		"practice":
			season_add("practice", n)
		"expeditions":
			season_add("expeditions", n)
	# Wochenaufgaben
	var wk := weekly()
	for q in wk.list:
		if String(q.key) == key and not bool(q.done):
			q.progress = mini(int(q.amount), int(q.progress) + n)
			if int(q.progress) >= int(q.amount):
				q.done = true
				grant(DL.WEEKLY_REWARD, "Wochenaufgabe")
				season_add("weekly")
				P.toast.emit("Wochenaufgabe erfüllt: " + String(q.text))
				Sfx.play("weekly_done", -3.0)
	if not bool(wk.get("bonus", false)) and weekly_done() >= wk.list.size() and wk.list.size() > 0:
		wk.bonus = true
		grant(DL.WEEKLY_ALL_REWARD, "Alle Wochenaufgaben")
		season_add("weekly_all")
		P.toast.emit("Alle Wochenaufgaben erfüllt! Große Belohnung erhalten.")
	_holiday_progress(key, n)


static func on_daily_quest() -> void:
	season_add("daily")


static func on_daily_all() -> void:
	season_add("daily_all")
	on_progress("daily_all", 1)


static func on_flood(win: bool, _out: Dictionary) -> void:
	season_add("flood_win" if win else "flood_loss")
	if win:
		on_progress("flood_win", 1)


## Ende einer Expedition (aus P.expedition_end): Albtraum+-Bonus.
static func on_expedition(_area: int, diff: int, success: bool, out: Dictionary) -> void:
	var w = G.game
	if not success or diff < 2 or w == null or not w.has_meta("nm"):
		return
	var mods: Array = w.get_meta("nm")
	if mods.is_empty():
		return
	var shards := DL.NM_SHARDS * mods.size()
	P.add("shards", shards)
	out["nm_shards"] = shards
	st().nm_wins = int(st().nm_wins) + 1
	P.count_up("nightmare_plus", 1)
	season_add("nightmare")
	P.toast.emit("Albtraum+ (%d) geschafft: +%d Sternsplitter" % [mods.size(), shards])


# ================================================================= Belohnungen
## bundle: gems, chest, boost, cos und Rohstoffe.
static func grant(bundle: Dictionary, why: String) -> void:
	for k in bundle:
		match String(k):
			"gems":
				P.add_gems(int(bundle[k]), why)
			"chest":
				P.add_chest(String(bundle[k]))
			"boost":
				st().boost = int(st().boost) + int(bundle[k])
			"cos":
				give(String(bundle[k]), why)
			_:
				P.add(String(k), float(bundle[k]))
	P.resources_changed.emit()
	P.mark()


static func bundle_text(b: Dictionary) -> String:
	var parts: Array = []
	for k in b:
		match String(k):
			"gems":
				parts.append("%d Juwelen" % int(b[k]))
			"chest":
				parts.append(String(D.CHESTS[String(b[k])].name) if D.CHESTS.has(String(b[k])) else "Kiste")
			"boost":
				parts.append("%d× Zeitschub" % int(b[k]))
			"cos":
				parts.append("%s „%s“" % [String(DL.KIND_NAME[cos_kind(String(b[k]))]), cos_name(String(b[k]))])
			_:
				parts.append("%s %s" % [_fmt(int(b[k])), String(D.RES_NAME.get(String(k), String(k)))])
	return ", ".join(parts)


static func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


## Zeitschub einsetzen: alle laufenden Bauten 30 Minuten weiter.
static func use_boost() -> String:
	if int(st().boost) <= 0:
		return "Du hast keinen Zeitschub."
	var any := false
	for b in P.d.buildings:
		if P.is_building(b):
			any = true
			break
	if not any:
		return "Gerade läuft kein Bau."
	st().boost = int(st().boost) - 1
	P.speed_up_builds(DL.BOOST_SECONDS)
	Sfx.play("boost_use", -3.0)
	P.mark()
	return ""


# ================================================================= Saison und Saison-Pass
static func season_n() -> int:
	return maxi(1, int(floor(float(week_index() - DL.EPOCH_WEEK) / DL.SEASON_WEEKS)) + 1)


static func season_def(n := -1) -> Dictionary:
	if n < 1:
		n = season_n()
	return DL.SEASONS[(n - 1) % DL.SEASONS.size()]


static func season_end_t(n := -1) -> float:
	if n < 1:
		n = season_n()
	return week_start(DL.EPOCH_WEEK + n * DL.SEASON_WEEKS)


static func season_left() -> float:
	return maxf(0.0, season_end_t() - P.now())


## Stand der laufenden Saison; beim Wechsel wird die alte Saison nach Rang belohnt.
static func season() -> Dictionary:
	var lo := st()
	var s: Dictionary = lo.season
	var n := season_n()
	if int(s.get("n", 0)) != n:
		if int(s.get("n", 0)) > 0 and int(s.get("n", 0)) < n:
			_season_end(int(s.n), int(s.get("pts", 0)))
		lo.season = {"n": n, "pts": 0, "paid": false, "free": [], "paid_got": [], "sent": 0}
		s = lo.season
	return s


static func season_add(src: String, times := 1) -> void:
	if not P.d.has("lo"):
		return
	var s := season()
	var before := pass_tier()
	s.pts = int(s.pts) + int(DL.SP.get(src, 0)) * times
	var after := pass_tier()
	if after > before:
		P.toast.emit("Saison-Pass: Stufe %d erreicht!" % after)
		Sfx.play("pass_tier", -3.0)
	P.mark()


static func season_points() -> int:
	return int(season().pts)


static func pass_tier() -> int:
	return mini(DL.PASS_TIERS, int(season_points() / DL.PASS_POINTS))


static func pass_paid() -> bool:
	return bool(season().paid)


## Belohnung einer Stufe (1..40) in der Spur "free" oder "paid".
static func pass_reward(track: String, tier: int) -> Dictionary:
	if track == "free":
		if DL.PASS_FREE_COS.has(tier):
			return {"cos": DL.PASS_FREE_COS[tier], "gems": 5}
		if tier % 5 == 0:
			return {"chest": "quest", "gems": 10}
		if tier % 3 == 0:
			return {"boost": 1}
		return {"coins": 200 + 25 * tier}
	if DL.PASS_PAID_COS.has(tier):
		return {"cos": DL.PASS_PAID_COS[tier]}
	if tier % 5 == 0:
		return {"chest": "level", "gems": 10}
	if tier % 2 == 0:
		return {"gems": 15}
	return {"boost": 1, "coins": 300}


static func pass_got(track: String, tier: int) -> bool:
	var arr: Array = season().free if track == "free" else season().paid_got
	return tier in arr or float(tier) in arr


static func pass_can(track: String, tier: int) -> bool:
	if tier > pass_tier() or pass_got(track, tier):
		return false
	return track == "free" or pass_paid()


static func pass_claim(track: String, tier: int) -> String:
	if not pass_can(track, tier):
		if track == "paid" and not pass_paid():
			return "Die Pass-Spur ist noch nicht freigeschaltet."
		return "Diese Stufe ist noch nicht erreicht." if tier > pass_tier() else "Schon abgeholt."
	(season().free if track == "free" else season().paid_got).append(tier)
	grant(pass_reward(track, tier), "Saison-Pass Stufe %d" % tier)
	P.mark()
	return ""


## Alle erreichten Stufen abholen. Rückgabe: Zahl der Belohnungen.
static func pass_claim_all() -> int:
	var n := 0
	for t in range(1, pass_tier() + 1):
		for tr in ["free", "paid"]:
			if pass_can(tr, t):
				pass_claim(tr, t)
				n += 1
	return n


static func pass_open() -> int:
	var n := 0
	for t in range(1, pass_tier() + 1):
		for tr in ["free", "paid"]:
			if pass_can(tr, t):
				n += 1
	return n


## Text der Kaufbestätigung (Kinder- und Widerrufs-Hinweis wie im Juwelen-Laden).
static func pass_confirm_text() -> String:
	var Store = load("res://src/store.gd")
	var t := "Saison-Pass „%s“ für %s freischalten?" % [String(season_def().name), "0 € (Testkauf)" if Store.test_mode() else DL.PASS_PRICE]
	t += "\nDie Pass-Spur bringt nur Aussehen und Komfort – keine Stärke."
	if P.social and P.social.net.child_mode():
		t += "\n\nBitte nur kaufen, wenn deine Eltern es erlaubt haben!"
	return t


## Bezahlte Spur freischalten: nur als Testkauf (wie die Shop-Pakete, kein echtes Geld).
static func buy_pass() -> String:
	if pass_paid():
		return "Der Saison-Pass ist schon freigeschaltet."
	var Store = load("res://src/store.gd")
	if not Store.test_mode():
		return "Der Saison-Pass ist in dieser Version nur als Testkauf verfügbar. " + String(Store.note())
	season().paid = true
	Sfx.play("pass_unlock", -2.0)
	P.toast.emit("Saison-Pass freigeschaltet (Testkauf).")
	P.mark()
	return ""


## Rang in der Saison-Rangliste (1 = Erster).
static func season_rank(n := -1, pts := -1) -> int:
	var b := board(n, pts)
	for i in b.size():
		if bool(b[i].me):
			return i + 1
	return b.size()


## Rangliste: vom Server (wenn verbunden und aktuell), sonst simuliert (feste Mitspieler je Saison).
static func board(n := -1, pts := -1) -> Array:
	if n < 1:
		n = season_n()
	if pts < 0:
		pts = season_points() if n == season_n() else 0
	var sb: Dictionary = st().srv_board
	if int(sb.get("season", -1)) == n and sb.get("entries") is Array and not sb.entries.is_empty() and n == season_n():
		var out: Array = []
		for e in sb.entries:
			out.append({"name": String(e.get("name", "?")), "score": int(e.get("score", 0)), "me": bool(e.get("me", false))})
		return out
	var frac := clampf(1.0 - (season_end_t(n) - P.now()) / (DL.SEASON_WEEKS * DL.WEEK_S), 0.02, 1.0)
	var full := float(DL.PASS_TIERS * DL.PASS_POINTS)
	var out2: Array = []
	var rng := RandomNumberGenerator.new()
	for i in DL.BOARD_SIZE - 1:
		rng.seed = hash("rw-season-%d-%d" % [n, i])
		var pace := rng.randf_range(0.15, 1.45)
		var wob := rng.randf_range(0.85, 1.15)
		out2.append({"name": String(DL.BOT_NAMES[i % DL.BOT_NAMES.size()]), "score": int(full * pace * frac * wob), "me": false})
	out2.append({"name": String(P.d.get("name", "Kommandant")), "score": pts, "me": true})
	out2.sort_custom(func(a, b): return int(a.score) > int(b.score) or (int(a.score) == int(b.score) and bool(a.me)))
	return out2


static func _season_end(n: int, pts: int) -> void:
	var rank := season_rank(n, pts)
	var gems := 0
	var title := ""
	for r in DL.SEASON_RANK_REWARDS:
		if rank <= int(r[0]):
			gems = int(r[1])
			title = String(r[2])
			break
	if gems > 0:
		P.add_pickup("season", "bunker", {"gems": gems}, "Saison %d „%s“: Platz %d" % [n, String(season_def(n).name), rank])
	if title != "":
		var t := "%s (Saison %d)" % [title, n]
		if not (t in st().titles):
			st().titles.append(t)
	P.toast.emit("Saison %d ist vorbei – Platz %d. Deine Belohnung wartet am Bunker." % [n, rank])
	Sfx.play("season_end", -2.0)


# ================================================================= Kosmetik
static func cos_kind(id: String) -> String:
	return id.get_slice(":", 0)


static func cos_key(id: String) -> String:
	return id.get_slice(":", 1)


static func cos_name(id: String) -> String:
	return String(DL.COSMETICS[id].name) if DL.COSMETICS.has(id) else id


static func cos_icon(id: String) -> String:
	match cos_kind(id):
		"skin":
			return "hero_" + cos_key(id)
		"wskin":
			return "lo_wskin_" + cos_key(id)
		"bskin":
			return "lo_bskin_" + cos_key(id)
		"flag":
			return "lo_flag_" + cos_key(id)
		"hat":
			return "lo_hat_" + cos_key(id)
	return "ui_star"


static func owned(id: String) -> bool:
	return id in st().cos.owned


static func give(id: String, why := "") -> bool:
	if not DL.COSMETICS.has(id) or owned(id):
		return false
	st().cos.owned.append(id)
	P.toast.emit("Neu in der Garderobe: %s „%s“%s" % [String(DL.KIND_NAME[cos_kind(id)]), cos_name(id), (" (%s)" % why) if why != "" else ""])
	Sfx.play("cosmetic_get", -3.0)
	P.mark()
	return true


static func list_kind(kind: String, hero := "") -> Array:
	var out: Array = []
	for id in DL.COSMETICS:
		if cos_kind(String(id)) != kind:
			continue
		if hero != "" and String(DL.COSMETICS[id].get("hero", "")) != hero:
			continue
		out.append(String(id))
	return out


## Angelegtes Teil einer Art ("" = Standard). hero nur für Helden-Skins.
static func equipped(kind: String, hero := "") -> String:
	var c: Dictionary = st().cos
	if kind == "skin":
		return String(c.skin.get(hero, ""))
	return String(c.get(kind, ""))


static func equip(id: String) -> String:
	if not owned(id):
		return "Das hast du noch nicht."
	var c: Dictionary = st().cos
	var kind := cos_kind(id)
	if kind == "skin":
		c.skin[String(DL.COSMETICS[id].hero)] = id
	else:
		c[kind] = id
	Sfx.play("cosmetic_equip", -4.0)
	P.mark()
	P.changed.emit()
	_refresh_hero(kind)
	return ""


## Standard wieder anlegen.
static func unequip(kind: String, hero := "") -> void:
	var c: Dictionary = st().cos
	if kind == "skin":
		c.skin.erase(hero)
	else:
		c[kind] = ""
	P.mark()
	P.changed.emit()
	_refresh_hero(kind)


## Helden- oder Waffen-Skin gewechselt: Held in der Basis neu aufbauen (zeigt das neue Aussehen sofort).
static func _refresh_hero(kind: String) -> void:
	if not (kind in ["skin", "wskin"]) or G.main == null or G.main.world == null:
		return
	var w = G.main.world
	if w.get("mode") == "peace" and w.get("hero") != null and G.main.has_method("reload_hero"):
		G.main.reload_hero.call_deferred()


## Modell-Schlüssel des Helden-Skins (z. B. "jona_marine") oder "".
static func hero_skin(hero: String) -> String:
	if not P.d.has("lo"):
		return ""
	var id := equipped("skin", hero)
	return cos_key(id) if id != "" else ""


## Waffe in der Farbe des angelegten Waffen-Skins (Haken in hero.set_weapon und der Vorschau). id "-" = angelegter Skin.
static func tint_weapon(node: Node3D, id := "-") -> Node3D:
	if node == null:
		return node
	if id == "-":
		id = equipped("wskin") if P.d.has("lo") else ""
	if id == "" or not DL.COSMETICS.has(id):
		return node
	var m := weapon_mat(id)
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if not String(mi.name).contains("_glow"):
			(mi as MeshInstance3D).material_override = m
	return node


const _SH_WSKIN := """shader_type spatial;
uniform vec3 tint = vec3(1.0);
uniform float metal = 0.0;
uniform float glow = 0.0;
void fragment() {
	float l = dot(COLOR.rgb, vec3(0.3, 0.59, 0.11));
	vec3 c = tint * (0.3 + 1.6 * l);
	ALBEDO = mix(COLOR.rgb, c, 0.85) * 1.1;
	METALLIC = metal;
	ROUGHNESS = mix(0.6, 0.22, metal);
	EMISSION = c * glow;
}
"""
const _SH_TINT := """shader_type spatial;
uniform vec3 tint = vec3(1.0);
void fragment() {
	ALBEDO = COLOR.rgb * tint * 1.15;
	ROUGHNESS = 0.6;
}
"""


static func weapon_mat(id: String) -> ShaderMaterial:
	var key := "w:" + id
	if not _mats.has(key):
		var sh := Shader.new()
		sh.code = _SH_WSKIN
		var m := ShaderMaterial.new()
		m.shader = sh
		var def: Dictionary = DL.COSMETICS[id]
		var c: Color = (def.tint as Color).srgb_to_linear()
		m.set_shader_parameter("tint", Vector3(c.r, c.g, c.b))
		m.set_shader_parameter("metal", float(def.get("metal", 0.0)))
		m.set_shader_parameter("glow", float(def.get("glow", 0.0)))
		_mats[key] = m
	return _mats[key]


static func tint_mat(col: Color) -> ShaderMaterial:
	var key := "t:" + col.to_html()
	if not _mats.has(key):
		var sh := Shader.new()
		sh.code = _SH_TINT
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("tint", Vector3(col.r, col.g, col.b))
		_mats[key] = m
	return _mats[key]


## Bunker-Skin an ein Bunker-Modell anlegen (Farbe + Anbauten). id "" entfernt ihn. Rückgabe: Liste für Anim.tick.
static func apply_bunker_skin(model: Node3D, id: String) -> Array:
	if model == null:
		return []
	var old := model.get_node_or_null("LoSkin")
	if old != null:
		old.name = "LoSkinAlt"
		old.queue_free()
	var MK = load("res://src/mk.gd")
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if nm.contains("_glow") or nm.begins_with("sway_flag") or nm.contains("banner"):
			continue
		if id != "" and DL.COSMETICS.has(id):
			(mi as MeshInstance3D).material_override = tint_mat(DL.COSMETICS[id].tint)
		else:
			(mi as MeshInstance3D).material_override = MK.mat_lin()
	model.set_meta("lo_skin", id)
	if id == "" or not DL.COSMETICS.has(id) or not Models.has_glb(String(DL.COSMETICS[id].model)):
		return []
	var add := Models.glb(String(DL.COSMETICS[id].model))
	add.name = "LoSkin"
	model.add_child(add)
	return load("res://src/anim.gd").collect(add, false)


## Kosmetik aus Erfolgen vergeben (Zähler erreicht).
static func check_ach_cosmetics() -> void:
	if not P.d.has("lo"):
		return
	for a in DL.ACH_COSMETICS:
		if not owned(String(a[0])) and P.stat(String(a[1])) >= int(a[2]):
			give(String(a[0]), "Erfolg")


## Kosmetik-Shop: täglich wechselnde Angebote (fest je Tag) und ein Angebot der Woche.
static func shop_offers() -> Array:
	var pool: Array = []
	for id in DL.COSMETICS:
		if int(DL.COSMETICS[id].get("price", 0)) > 0:
			pool.append(String(id))
	pool.sort()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("rw-shop-%d" % P.day_index())
	var out: Array = []
	var tries := 0
	while out.size() < mini(DL.SHOP_SLOTS, pool.size()) and tries < 200:
		tries += 1
		var id: String = pool[rng.randi() % pool.size()]
		if not (id in out) and id != shop_deal():
			out.append(id)
	return out


static func shop_deal() -> String:
	var pool: Array = []
	for id in DL.COSMETICS:
		if int(DL.COSMETICS[id].get("price", 0)) > 0:
			pool.append(String(id))
	pool.sort()
	return String(pool[posmod(hash("rw-deal-%d" % week_index()), pool.size())]) if not pool.is_empty() else ""


static func shop_price(id: String) -> int:
	var p := int(DL.COSMETICS[id].get("price", 0))
	if id == shop_deal():
		p = int(round(p * DL.SHOP_DEAL / 5.0) * 5)
	return p


static func shop_buy(id: String) -> String:
	if owned(id):
		return "Das hast du schon."
	if not (id in shop_offers()) and id != shop_deal():
		return "Das gibt es heute nicht im Shop."
	if not P.spend_gems(shop_price(id), "Kosmetik: %s" % cos_name(id)):
		return "Zu wenig Juwelen."
	give(id, "Kosmetik-Shop")
	return ""


static func shop_left() -> float:
	return P.seconds_to_next_day()


# ================================================================= Wochenaufgaben
static func weekly() -> Dictionary:
	var lo := st()
	var wk: Dictionary = lo.weekly
	var w := week_index()
	if int(wk.get("week", -1)) != w or not (wk.get("list") is Array):
		var pool: Array = DL.WEEKLY_POOL.duplicate()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("rw-weekly-%d" % w)
		for i in range(pool.size() - 1, 0, -1):
			var j := rng.randi() % (i + 1)
			var tmp = pool[i]
			pool[i] = pool[j]
			pool[j] = tmp
		var list: Array = []
		for i in mini(DL.WEEKLY_N, pool.size()):
			var q: Dictionary = pool[i]
			var amt := int(q.amount)
			if String(q.key) in ["kills", "coins"]:
				amt = int(round(amt * (1.0 + 0.04 * int(P.d.get("level", 1))) / 50.0) * 50)
			var txt := String(q.text) % amt if String(q.text).contains("%d") else String(q.text)
			list.append({"key": String(q.key), "text": txt, "amount": amt, "progress": 0, "done": false})
		lo.weekly = {"week": w, "list": list, "bonus": false}
		wk = lo.weekly
	return wk


static func weekly_done() -> int:
	var n := 0
	for q in weekly().list:
		if bool(q.done):
			n += 1
	return n


# ================================================================= Login-Kalender (ersetzt das Tagesgeschenk aus P._check_daily)
static func daily_gift() -> void:
	var c: Dictionary = st().cal
	var i := int(c.idx) % DL.CALENDAR.size()
	c.idx = i + 1
	c["day"] = P.day_index()
	var r: Dictionary = DL.CALENDAR[i]
	var bundle := {}
	var now := {}
	for k in r:
		if String(k) in ["boost", "cos"]:
			now[k] = r[k]
		else:
			bundle[k] = r[k]
	if not now.is_empty():
		grant(now, "Login-Kalender")
	var hl := (i + 1) in DL.CAL_HIGHLIGHT
	P.add_pickup("daily", "bunker", bundle, "Login-Kalender: Tag %d von %d%s" % [i + 1, DL.CALENDAR.size(), " – Höhepunkt!" if hl else ""])


## Tag (1..28), der als Nächstes kommt.
static func cal_next() -> int:
	return int(st().cal.idx) % DL.CALENDAR.size() + 1


## Tage, die im laufenden Durchgang schon da waren (0..28).
static func cal_done() -> int:
	var i := int(st().cal.idx)
	if i == 0:
		return 0
	var m := i % DL.CALENDAR.size()
	return DL.CALENDAR.size() if m == 0 else m


# ================================================================= Nachrichten-Brett
static func news() -> Array:
	var srv: Dictionary = st().srv
	if srv.get("news") is Array and not srv.news.is_empty():
		return srv.news
	return DL.NEWS


static func news_unread() -> int:
	return maxi(0, news().size() - int(st().news_seen))


static func news_read() -> void:
	st().news_seen = news().size()
	P.mark()


# ================================================================= Endspiel: Prestige
static func stars(hero: String) -> int:
	if not P.d.has("lo"):
		return 0
	return int(st().prestige.get(hero, {}).get("stars", 0))


static func prestige_xp_now(hero: String) -> float:
	return float(st().prestige.get(hero, {}).get("xp", 0.0))


## Erfahrung über Stufe 40 wird zu Prestige-Sternen (Haken in P.add_hero_xp). Rückgabe: Rest für h.xp (immer 0).
static func prestige_xp(hero: String, xp: float) -> float:
	if xp <= 0.0 or not P.d.has("lo"):
		return 0.0
	var pr: Dictionary = st().prestige
	if not pr.has(hero):
		pr[hero] = {"stars": 0, "xp": 0.0}
	var h: Dictionary = pr[hero]
	if int(h.stars) >= DL.PRESTIGE_MAX:
		return 0.0
	h.xp = float(h.xp) + xp
	while float(h.xp) >= DL.PRESTIGE_XP and int(h.stars) < DL.PRESTIGE_MAX:
		h.xp = float(h.xp) - DL.PRESTIGE_XP
		h.stars = int(h.stars) + 1
		P.toast.emit("%s: Prestige-Stern %d!" % [String(D.HEROES[hero].name), int(h.stars)])
		Sfx.play("prestige_star", -3.0)
		if int(h.stars) % 5 == 0:
			P.add_gems(DL.PRESTIGE_GEMS, "Prestige")
	if int(h.stars) >= DL.PRESTIGE_MAX:
		h.xp = 0.0
	return 0.0


## Dauerboni der Sterne in die Werte des Helden (Haken in P.hero_stats).
static func prestige_bonus(hero: String, m: Dictionary) -> void:
	var s := stars(hero)
	if s <= 0:
		return
	m.dmg = float(m.dmg) + s * DL.PRESTIGE_DMG
	m.hp = float(m.hp) + s * DL.PRESTIGE_HP


# ================================================================= Endspiel: Albtraum+
static func nm_mods() -> Array:
	return st().nm


static func nm_toggle(k: String) -> void:
	var a: Array = st().nm
	if k in a:
		a.erase(k)
	else:
		a.append(k)
	P.mark()


static func nm_open(area: int) -> bool:
	return bool(P.d.areas.boss[area][2])


static func nm_loot(mods: Array) -> float:
	var s := 1.0
	for k in mods:
		s += float(DL.NIGHTMARE_MODS[k].loot)
	return s


## Aus expedition._ready (nach den Schwierigkeitswerten): Albtraum+ anwenden.
static func apply_nightmare(w) -> void:
	nm_explode = false
	nm_noheal = false
	nm_double = false
	nm_swift = false
	if int(w.diff) < 2 or String(w.mission) == "befreiung" or not nm_open(int(w.area)) or nm_mods().is_empty():
		return
	var mods: Array = nm_mods().duplicate()
	w.set_meta("nm", mods)
	if "armored" in mods:
		w.hp_mult *= 1.5
	w.loot_bonus *= nm_loot(mods)
	set_world_flags(w)


static func set_world_flags(w) -> void:
	var mods: Array = w.get_meta("nm", []) if w != null and w.has_meta("nm") else []
	nm_explode = "explode" in mods
	nm_noheal = "noheal" in mods
	nm_double = "doubleboss" in mods
	nm_swift = "swift" in mods
	_halloween = holiday() == "halloween"


## Haken in horde.spawn: Halloween-Färbung der Schleime, Hast.
static func on_spawn(e, def: Dictionary) -> void:
	if _halloween and String(def.family) == "schleim" and String(def.role) != "boss":
		e.tint = Color(e.tint.r * DL.HALLOWEEN_TINT.r, e.tint.g * DL.HALLOWEEN_TINT.g, e.tint.b * DL.HALLOWEEN_TINT.b)
	if nm_swift:
		e.sp *= 1.2


## Haken in horde._kill (nur wenn nm_explode): Explosion beim Tod.
static func on_kill(e) -> void:
	var w = G.game
	if w == null or w.hero == null or G.fx == null:
		return
	G.fx.explosion(Vector3(e.p.x, 0.6, e.p.y), DL.NM_EXPLODE_R, Color(0.75, 0.4, 1.0))
	var h = w.hero
	if h.alive and h.pos2().distance_to(e.p) < DL.NM_EXPLODE_R:
		h.hurt(h.max_hp * DL.NM_EXPLODE_DMG)


## Haken am Ende von expedition.spawn_boss_at: Doppelte Bosse.
static func on_boss(w, e, p: Vector2) -> void:
	if not nm_double or e == null or w.has_meta("nm_twin"):
		return
	w.set_meta("nm_twin", true)
	var t2 = w.horde.spawn(e.t, p + Vector2(3.5, 0), e.hm, e.dm, e.dp)
	t2.home = p
	t2.leash = 12.0
	t2.special = e.special
	t2.coins = e.coins
	w.remove_meta("nm_twin")
	P.toast.emit("Albtraum+: Der Boss kommt zu zweit!")


# ================================================================= Endspiel: Gebietsboss-Herausforderung (Außenbasis Stufe 4 und 5)
## Haken in expedition._on_built: true = Stufe lvl wartet noch auf den Sieg über den Gebietsboss (Kampf läuft oder startet).
static func outpost_gate(w, lvl: int, pad_key: String) -> bool:
	if not DL.OUTPOST_CHALLENGE.has(lvl):
		return false
	if (G.selftest or G.autotest != "") and not force_challenge:
		return false                                 # Bots und fremde Tests bauen ohne Bosskampf durch
	var ak := String(w.adef.key)
	if int(st().op_ch.get(ak, 0)) >= lvl:
		return false
	if w.has_meta("op_ch"):
		return true
	var ch: Dictionary = DL.OUTPOST_CHALLENGE[lvl]
	var c: Vector2 = w.outpost.C
	var p: Vector2 = c + Vector2(0, 16)
	if w.field.blocks_player(p):
		p = c + Vector2(16, 0)
	var e = w.spawn_boss_at(p)
	if e == null:
		return false
	e.hp *= float(ch.hp)
	e.mhp *= float(ch.hp)
	e.leash = 40.0
	e.aggro = true
	w.set_meta("op_ch", lvl)
	var prev: Callable = e.on_death
	e.on_death = func():
		if prev.is_valid():
			prev.call()
		challenge_won(w, ak, lvl, pad_key)
	P.toast.emit("Gebietsboss-Herausforderung: Besiege %s, dann steigt die Außenbasis auf Stufe %d!" % [String(w.horde.boss_name), lvl])
	Sfx.play("challenge_start", -2.0)
	Music.set_mood("boss")
	return true


static func challenge_won(w, ak: String, lvl: int, pad_key: String) -> void:
	st().op_ch[ak] = lvl
	var ch: Dictionary = DL.OUTPOST_CHALLENGE[lvl]
	grant({"gems": int(ch.gems), "chest": String(ch.chest)}, "Gebietsboss-Herausforderung")
	Sfx.play("challenge_won", -2.0)
	P.mark()
	if is_instance_valid(w):
		w.remove_meta("op_ch")
		Music.set_mood("battle")
		w._on_built(pad_key)


## Expedition (liveops_world, je Sekunde): bezahlte Stufe 4/5 ohne Sieg – Herausforderung starten, wenn der Held an der Basis ist.
static func check_outpost(w) -> void:
	if w.get("outpost") == null or w.has_meta("op_ch") or String(w.mission) == "befreiung":
		return
	var ak := String(w.adef.key)
	var lv := P.outpost_level(ak)
	if lv < 3 or lv >= D.OUTPOST_MAX_LEVEL or not DL.OUTPOST_CHALLENGE.has(lv + 1):
		return
	if not w.outpost.has_method("upgrade_done") or not w.outpost.upgrade_done(lv + 1):
		return
	if w.hero == null or w.hero.pos2().distance_to(w.outpost.C) > 14.0:
		return
	for pd in D.OUTPOST_PADS:
		if int(pd.level) == lv + 1:
			outpost_gate(w, lv + 1, String(pd.key))
			return


static func challenge_text(ak: String) -> String:
	var won := int(st().op_ch.get(ak, 0))
	if won >= 5:
		return "Gebietsboss-Herausforderungen: beide bestanden"
	if won >= 4:
		return "Gebietsboss-Herausforderung Stufe 5: Boss mit %d %% Leben" % int(DL.OUTPOST_CHALLENGE[5].hp * 100)
	return "Stufe 4 und 5 verlangen einen Sieg über den Gebietsboss (Leben ×%s / ×%s)" % [str(DL.OUTPOST_CHALLENGE[4].hp).replace(".", ","), str(DL.OUTPOST_CHALLENGE[5].hp).replace(".", ",")]


# ================================================================= Server
static func net_node() -> Node:
	if P.social == null or P.social.get("net") == null:
		return null
	var net: Node = P.social.net
	var n := net.get_node_or_null("LiveOps")
	if n == null:
		n = load("res://src/liveops_net.gd").new()
		n.name = "LiveOps"
		net.add_child(n)
	return n


## Nach dem Verbinden und beim Öffnen der Saison-Seite: Zeitplan, Nachrichten, Weltboss, Rangliste holen.
static func net_refresh() -> void:
	if P.social == null or not P.social.online():
		return
	var n := net_node()
	if n != null:
		n.pull()
