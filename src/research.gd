extends RefCounted
## Forschung (V6 Paket B, Kapitel 4.1): Forschungsbaum im Labor mit drei Ästen (Türme, Wirtschaft, Helden/Expedition).
## Spielstand: P.d.research = {"done": [Schlüssel], "cur": laufender Schlüssel oder "", "t0": Start, "end": fertig um}.
## Ein Forschungsplatz; die Zeit läuft wie eine Bauzeit (auch wenn das Spiel aus ist), Beschleunigen mit Juwelen.
##
## Vorraum (vor dem Labor, das erst mit Bunker 8 kommt): die drei Wurzel-Knoten (Reihe 0, je Ast einer) lassen sich
## schon in der „Tüftelecke“ der Werkstatt (ab Bunker 2) erforschen. So trifft man früh eine erste Richtungsentscheidung
## (welcher Ast zuerst), ohne dass die großen Boni vor dem Labor kommen; alles ab Reihe 1 braucht das Labor
## (tiefe Reihen zusätzlich eine höhere Laborstufe).
##
## Wirkungen: bonus(stat) summiert die fertigen Knoten. Die Werte der Kommandanten-Fähigkeiten (wall_hp, build_time,
## tower_dmg, trap_dmg, carry, fuel, loot, hero_hp, hero_dmg, xp, reload) kommen über P.cmd_bonus() dazu; Reichweite,
## Feuertempo, Lager, Produktion, Bunkerleben, Flutbeute, Reparatur, Funde und Heilung lesen bonus() direkt.

const D = preload("res://src/data.gd")
const DB = preload("res://src/data_basis.gd")

static var _cd: Array = []
static var _cn := -1
static var _sum := {}


static func ensure(d: Dictionary) -> void:
	if not d.has("research") or not (d.research is Dictionary):
		d["research"] = {"done": [], "cur": "", "t0": 0.0, "end": 0.0}
	var r: Dictionary = d.research
	for k in [["done", []], ["cur", ""], ["t0", 0.0], ["end", 0.0]]:
		if not r.has(k[0]):
			r[k[0]] = k[1]
	r.done = (r.done as Array).filter(func(x): return DB.NODES.has(String(x)))
	if String(r.cur) != "" and not DB.NODES.has(String(r.cur)):
		r.cur = ""


static func _rs() -> Dictionary:
	if P.d.is_empty() or not P.d.has("research"):
		return {}
	return P.d.research


static func done_list() -> Array:
	var r := _rs()
	return r.get("done", [])


static func is_done(key: String) -> bool:
	return done_list().has(key)


static func count() -> int:
	return done_list().size()


static func current() -> String:
	return String(_rs().get("cur", ""))


## Summe der Wirkung aller fertigen Knoten mit diesem Wert (0, wenn keiner).
static func bonus(stat: String) -> float:
	var dl: Array = done_list()
	if dl.is_empty():
		return 0.0
	if not is_same(dl, _cd) or dl.size() != _cn:
		_cd = dl
		_cn = dl.size()
		_sum = {}
		for k in dl:
			var n: Dictionary = DB.NODES.get(String(k), {})
			if not n.is_empty():
				_sum[String(n.stat)] = float(_sum.get(String(n.stat), 0.0)) + float(n.val)
	return float(_sum.get(stat, 0.0))


## Produktions-Bonus für einen Rohstoff (Holz/Stein, fortgeschrittene Rohstoffe, alles).
static func prod_bonus(res: String) -> float:
	var k := bonus("prod_all")
	if res in ["wood", "stone"]:
		k += bonus("prod_basic")
	elif res in ["metal", "fuel", "cells"]:
		k += bonus("prod_adv")
	return k


## Wie stark Wetter und Nacht noch wirken (1 = voll, 0.5 mit Wetterschutz).
static func weather_k() -> float:
	return clampf(1.0 - bonus("weather_resist"), 0.0, 1.0)


# ----------------------------------------------------------------- Labor und Vorraum
static func labor_level() -> int:
	var lv := 0
	for b in P.d.buildings:
		if String(b.key) == "labor" and (not P.is_building(b) or bool(b.get("up", false))):
			lv = maxi(lv, int(b.level))
	return lv


static func prelab_ok() -> bool:
	return P.has_built(DB.PRELAB_BUILDING) or labor_level() > 0


## Darf diese Reihe überhaupt erforscht werden? "" = ja, sonst der Grund.
static func tier_why(tier: int) -> String:
	if tier <= 0:
		return "" if prelab_ok() else "Braucht die Werkstatt (ab Bunker 2)"
	var need: int = int(DB.TIER_LAB[clampi(tier, 0, DB.TIER_LAB.size() - 1)])
	var lv := labor_level()
	if lv <= 0:
		return "Braucht das Labor (ab Bunker 8)"
	if lv < need:
		return "Braucht Labor Stufe %d" % need
	return ""


static func node(key: String) -> Dictionary:
	return DB.NODES.get(key, {})


static func branch_of(key: String) -> Dictionary:
	var bk := String(node(key).get("branch", ""))
	for b in DB.BRANCHES:
		if String(b.key) == bk:
			return b
	return {}


static func cost(key: String) -> Dictionary:
	var n := node(key)
	if n.is_empty():
		return {}
	var tc: Dictionary = DB.TIER_COST[int(n.tier)]
	var br := branch_of(key)
	var rs: Array = br.get("res", ["wood", "stone"])
	var out := {"coins": int(tc.coins)}
	if int(tc.a) > 0:
		out[String(rs[0])] = int(tc.a)
	if int(tc.b) > 0:
		out[String(rs[1])] = int(out.get(String(rs[1]), 0)) + int(tc.b)
	if int(tc.shards) > 0:
		out["shards"] = int(tc.shards)
	return out


## Forschungszeit in Sekunden (Laborstufe beschleunigt, Testmodus Schnellbau ebenso).
static func time_for(key: String) -> float:
	var n := node(key)
	if n.is_empty():
		return 0.0
	if G.ch("instant"):
		return 0.0
	var t: float = float(DB.TIER_COST[int(n.tier)].time)
	var lv := labor_level()
	if lv > 1:
		t *= maxf(0.4, 1.0 - DB.LAB_SPEED * (lv - 1))
	return t * preload("res://src/story.gd").research_k() / P.build_speed()     # V6 Paket E: Forscher hilft


static func reqs_missing(key: String) -> Array:
	var out: Array = []
	for r in node(key).get("req", []):
		if not is_done(String(r)):
			out.append(String(r))
	return out


## Zustand eines Knotens: done | running | open (startbar, vielleicht fehlen Rohstoffe) | locked
static func state(key: String) -> String:
	if is_done(key):
		return "done"
	if current() == key:
		return "running"
	if not reqs_missing(key).is_empty() or tier_why(int(node(key).get("tier", 0))) != "":
		return "locked"
	return "open"


## Warum lässt sich dieser Knoten jetzt nicht starten? "" = es geht.
static func why_not(key: String) -> String:
	var n := node(key)
	if n.is_empty():
		return "?"
	if is_done(key):
		return "Schon erforscht"
	if current() != "":
		return "Es läuft schon eine Forschung" if current() != key else "Wird gerade erforscht"
	var miss := reqs_missing(key)
	if not miss.is_empty():
		var names: Array = []
		for m in miss:
			names.append(String(DB.NODES[m].name))
		return "Erst erforschen: %s" % ", ".join(names)
	var tw := tier_why(int(n.tier))
	if tw != "":
		return tw
	var c := cost(key)
	if not P.can_pay(c):
		return P.missing_text(c)
	return ""


static func start(key: String) -> String:
	var why := why_not(key)
	if why != "":
		return why
	var c := cost(key)
	if not P.pay(c):
		return P.missing_text(c)
	var r := _rs()
	r.cur = key
	r.t0 = P.now()
	r.end = P.now() + maxf(time_for(key), 0.01)
	Sfx.play("research_start", -6.0)
	P.count_up("research_started", 1)
	P.mark()
	P.changed.emit()
	if G.ch("instant"):
		tick(P.now())
	return ""


static func left() -> float:
	var r := _rs()
	if String(r.get("cur", "")) == "":
		return 0.0
	return maxf(0.0, float(r.end) - P.now())


static func progress() -> float:
	var r := _rs()
	if String(r.get("cur", "")) == "":
		return 0.0
	var tot := maxf(0.01, float(r.end) - float(r.t0))
	return clampf(1.0 - left() / tot, 0.0, 1.0)


static func speed_cost() -> int:
	if G.ch("freegems"):
		return 0
	return D.gem_cost(left())


static func finish_now() -> bool:
	if current() == "":
		return false
	if not P.spend_gems(speed_cost(), "Forschung beschleunigt"):
		return false
	_rs().end = P.now()
	Sfx.play("ui_buy", -4.0)
	tick(P.now())
	return true


## Aus P._time_passed() (jede Sekunde): fertige Forschung abschließen.
static func tick(t: float) -> void:
	var r := _rs()
	if r.is_empty() or String(r.get("cur", "")) == "":
		return
	if t < float(r.end):
		return
	var key := String(r.cur)
	r.cur = ""
	if not (r.done as Array).has(key) and DB.NODES.has(key):
		(r.done as Array).append(key)
	_cn = -1
	P.toast.emit("Forschung fertig: %s" % String(DB.NODES.get(key, {}).get("name", key)))
	Sfx.play("research_done", -4.0)
	G.vibrate(40)
	P.count_up("research", 1)
	P.mark()
	P.buildings_changed.emit()          # Türme und Mauern übernehmen die neuen Werte
	P.resources_changed.emit()


## Kurztext der Wirkung aller fertigen Knoten (für die Übersicht).
static func summary() -> Array:
	var out: Array = []
	for k in DB.NODES:
		if is_done(k):
			out.append(String(DB.NODES[k].text))
	return out
