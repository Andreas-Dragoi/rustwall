extends RefCounted
## V6 Paket E – Geschichte: Spielregeln außerhalb des Kampfes (nur statische Funktionen).
## Spielstand P.d.story:
##   seen      gesehene Zwischenszenen (Schlüssel aus DG.SCENES)        visited  betretene Gebiete (Index)
##   boss      Gebiete, deren Boss-Szene lief (Sieg über den Gebietsboss) rescued  befreite Figuren (DG.RESCUES)
##   goal      Index des nächsten Story-Ziels (DG.GOALS)               reports  letzte Berichte der Auto-Expeditionen
##   injured   Held -> verletzt bis (P.now())                           trade    Tauschladen: Tag, benutzte Angebote, Ei-Woche
##   wins      zuletzt gesehene Zahl gewonnener Fluten, win_t = Spielzeit des letzten Siegs (für Lob der Bewohner)
## Hängt sich über attach() an jede neue Welt (main._swap): story_world.gd.
## Eingebunden als const Story = preload("res://src/story.gd").

const D = preload("res://src/data.gd")
const DG = preload("res://src/data_geschichte.gd")


# ================================================================= Spielstand
static func ensure(d: Dictionary) -> void:
	if not d.has("story") or not (d.story is Dictionary):
		d["story"] = {}
	var s: Dictionary = d.story
	for k in [["seen", []], ["visited", []], ["boss", []], ["rescued", []], ["reports", []], ["injured", {}], ["trade", {}]]:
		if not s.has(k[0]):
			s[k[0]] = k[1]
	for k in [["goal", 0], ["wins", -1], ["egg_week", -1]]:
		if not s.has(k[0]):
			s[k[0]] = k[1]
		s[k[0]] = int(s[k[0]])
	if not s.has("win_t"):
		s["win_t"] = -99999.0
	s.visited = (s.visited as Array).map(func(x): return int(x))
	s.boss = (s.boss as Array).map(func(x): return int(x))
	s.rescued = (s.rescued as Array).filter(func(x): return DG.RESCUES.has(String(x)))
	# alte Stände: was schon erreicht ist, gilt als gesehen (keine Szenen nachträglich aufzwingen)
	if d.has("areas") and d.areas is Dictionary and d.areas.has("boss"):
		for i in mini((d.areas.boss as Array).size(), D.AREAS.size()):
			if bool(d.areas.boss[i][0]):
				if not s.visited.has(i):
					s.visited.append(i)
				if not s.boss.has(i):
					s.boss.append(i)
					for sid in ["a%d_in" % i, "a%d_boss" % i]:
						if not s.seen.has(sid):
							s.seen.append(sid)
					if i == 6 and not s.seen.has("end1"):
						s.seen.append("end1")
					if i == 7 and not s.seen.has("end2"):
						s.seen.append("end2")
	# Story-Ziele: bereits erfüllte Ziele alter Stände ohne Belohnung überspringen
	if is_same(d, P.d) and int(s.goal) == 0 and not s.boss.is_empty():
		while int(s.goal) < DG.GOALS.size() and goal_done(DG.GOALS[int(s.goal)]):
			s.goal = int(s.goal) + 1


static func st() -> Dictionary:
	if P.d.is_empty():
		return {}
	if not P.d.has("story"):
		ensure(P.d)
	return P.d.story


static func seen(id: String) -> bool:
	return (st().get("seen", []) as Array).has(id)


static func mark_seen(id: String) -> void:
	var s := st()
	if s.is_empty() or (s.seen as Array).has(id):
		return
	s.seen.append(id)
	P.count_up("story_scenes", 1)
	P.mark()


static func visited(a: int) -> bool:
	return (st().get("visited", []) as Array).has(a)


static func mark_visited(a: int) -> void:
	var s := st()
	if s.is_empty() or (s.visited as Array).has(a):
		return
	s.visited.append(a)
	P.mark()


## Gebietsboss besiegt (offiziell nach der Expedition oder schon während der Expedition gesehen)?
static func boss_done(a: int) -> bool:
	if a < 0 or a >= D.AREAS.size():
		return false
	if (st().get("boss", []) as Array).has(a):
		return true
	return P.d.has("areas") and a < (P.d.areas.boss as Array).size() and bool(P.d.areas.boss[a][0])


static func mark_boss(a: int) -> void:
	var s := st()
	if s.is_empty() or (s.boss as Array).has(a):
		return
	s.boss.append(a)
	P.mark()


## Höchster Gebietsindex, dessen Boss besiegt ist (-1 = keiner).
static func progress() -> int:
	var best := -1
	for i in D.AREAS.size():
		if boss_done(i):
			best = i
	return best


# ================================================================= Gerettete
static func rescued(key: String) -> bool:
	return (st().get("rescued", []) as Array).has(key)


static func rescued_list() -> Array:
	var out: Array = []
	for k in DG.RESCUE_ORDER:
		if rescued(k):
			out.append(k)
	return out


static func rescue(key: String) -> bool:
	var s := st()
	if s.is_empty() or not DG.RESCUES.has(key) or (s.rescued as Array).has(key):
		return false
	s.rescued.append(key)
	P.count_up("story_rescues", 1)
	var r: Dictionary = DG.RESCUES[key]
	P.toast.emit("%s zieht in deine Basis! %s" % [String(r.name), String(r.unlock)])
	P.mark()
	P.changed.emit()
	return true


## Forscher: Faktor für Forschungszeiten (research.gd).
static func research_k() -> float:
	return DG.RESEARCH_K if (not P.d.is_empty() and rescued("forscher")) else 1.0


## Schmied: Faktor für das Verbessern von Waffen (data.gd upgrade_cost).
static func smith_k() -> float:
	return DG.SMITH_K if (not P.d.is_empty() and rescued("schmied")) else 1.0


## Tauschladen: erst nach der Rettung der Händlerin baubar (P.max_count).
static func building_allowed(key: String) -> bool:
	match key:
		"tauschladen":
			return rescued("haendlerin")
	return true


# ================================================================= Verletzte Helden (Auto-Expedition)
static func injured(hk: String) -> bool:
	return injury_left(hk) > 0.0


static func injury_left(hk: String) -> float:
	var inj: Dictionary = st().get("injured", {})
	if not inj.has(hk):
		return 0.0
	return maxf(0.0, float(inj[hk]) - P.now())


static func injure(hk: String, minutes: float) -> void:
	var s := st()
	if s.is_empty():
		return
	s.injured[hk] = P.now() + minutes * 60.0 / P.build_speed()
	if String(P.d.hero_sel) == hk:
		for k in D.HERO_ORDER:
			if k != hk and P.hero_unlocked(k) and not P.hero_busy(k):
				P.d.hero_sel = k
				break
	P.mark()


static func heal(hk: String) -> void:
	var s := st()
	if not s.is_empty():
		s.injured.erase(hk)
		P.mark()


## Juwelenpreis für sofortige Heilung (wie Beschleunigen).
static func heal_cost(hk: String) -> int:
	if G.ch("freegems"):
		return 0
	return D.gem_cost(injury_left(hk))


# ================================================================= Story-Ziele
## Aktuelles Story-Ziel oder {} (alle erledigt).
static func goal() -> Dictionary:
	var i := int(st().get("goal", 0))
	return DG.GOALS[i] if i < DG.GOALS.size() else {}


static func goal_done(g: Dictionary) -> bool:
	match String(g.get("t", "")):
		"visit":
			return visited(int(g.a)) or boss_done(int(g.a))
		"boss":
			return boss_done(int(g.a))
		"rescue":
			return rescued(String(g.k))
		"scene":
			return seen(String(g.k))
	return false


## Hinweis, warum das Ziel noch nicht geht ("" = es geht).
static func goal_lock(g: Dictionary) -> String:
	var a := int(g.get("a", -1))
	if g.has("k"):
		a = int(DG.RESCUES[String(g.k)].area)
	if a >= 0 and not P.area_unlocked(a):
		return P.area_lock_text(a)
	return ""


static func goal_claim() -> Dictionary:
	var g := goal()
	if g.is_empty() or not goal_done(g):
		return {}
	var rw: Dictionary = g.reward
	load("res://src/guide.gd").give(rw, "Geschichte: " + String(g.text))
	st().goal = int(st().goal) + 1
	P.count_up("story_goals", 1)
	Sfx.play("goal_done", -3.0)
	P.mark()
	return rw


## Nummer des aktuellen Kapitels (1..8) für Anzeigen.
static func chapter() -> int:
	for i in D.AREAS.size():
		if not boss_done(i):
			return i + 1
	return D.AREAS.size()


static func act() -> int:
	return 2 if boss_done(6) else 1


# ================================================================= Zwischenszenen
## Szene starten (über der laufenden Welt). on_done wird nach dem Ende aufgerufen. Gibt den Szenen-Knoten zurück.
static func play(id: String, on_done := Callable(), replay := false) -> Node:
	if not DG.SCENES.has(id) or G.main == null:
		if on_done.is_valid():
			on_done.call()
		return null
	var sc = load("res://src/story_scene.gd").new()
	G.main.add_child(sc)
	sc.start(id, on_done, replay)
	return sc


static func playing() -> bool:
	return G.main != null and G.main.get_node_or_null("StoryScene") != null


## In Tests, Bots und Bildern laufen Szenen nicht von selbst (außer mit --story=1).
static func quiet() -> bool:
	return (G.autotest != "" or G.selftest or G.shots_dir != "") and G.arg("story") == ""


# ================================================================= Welt
static func attach(world: Node3D) -> Node:
	var n = load("res://src/story_world.gd").new()
	n.name = "Geschichte"
	n.w = world
	world.add_child(n)
	return n


# ================================================================= Bilder und Vorführung
## --story_demo=1: Spielstand für Bilder (alle gerettet, erste Kapitel gesehen, zwei Berichte, ein Held verletzt).
## Nur mit diesem Schalter; schreibt nichts, wenn P.no_save gilt (Tests und Bilder).
static var _demo_done := false


static func demo() -> void:
	if _demo_done or G.arg("story_demo") == "" or P.d.is_empty():
		return
	_demo_done = true
	for k in DG.RESCUE_ORDER:
		var s := st()
		if not (s.rescued as Array).has(k):
			s.rescued.append(k)
	for i in 4:
		mark_visited(i)
		if i < 3:
			mark_boss(i)
		for sid in ["a%d_in" % i, "a%d_boss" % i]:
			if i < 3 or sid.ends_with("_in"):
				mark_seen(sid)
	st().goal = 7
	for hk in ["mika", "bruno"]:
		if D.HEROES.has(hk):
			P.d.heroes[hk].unlocked = true
	var AR = load("res://src/auto_report.gd")
	P.add_many({"fuel": 500})
	var loot := {"metal": 240, "fuel": 120, "coins": 90}
	AR.finish("mika", 2, 4, loot.duplicate(), 1000.0)
	G.test_args["auto_hurt"] = "1"
	AR.finish("bruno", 1, 8, {"wood": 400, "stone": 260}, 2000.0)
	G.test_args.erase("auto_hurt")
	P.start_auto("jona", 0, 4)
