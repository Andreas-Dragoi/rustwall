extends RefCounted
## Spielstand des Pakets Welt (V5) in P.d.welt: Tagebuchseiten, entdeckte Wahrzeichen, Werkzeuge, Nebenquests,
## Begleiter-Eier und Bewohner-Wünsche. Nur statische Funktionen; Zahlen und Texte in data_welt.gd.

const D = preload("res://src/data.gd")
const DW = preload("res://src/data_welt.gd")
const CD = preload("res://src/companion_data.gd")

static var force_egg := false          # Tests: seltene Kiste enthält sicher ein Ei


## Legt die Felder an (aus P._ensure_fields): alte Spielstände laden weiter.
static func ensure(d: Dictionary) -> void:
	if not d.has("welt") or not (d.welt is Dictionary):
		d["welt"] = {}
	var w: Dictionary = d.welt
	for k in [["pages", {}], ["landmarks", {}], ["tools", {}], ["quests", {}], ["wishes", {}]]:
		if not w.has(k[0]) or not (w[k[0]] is Dictionary):
			w[k[0]] = k[1]
	if not w.has("eggs") or not (w.eggs is Array):
		w["eggs"] = []
	for k in [["new_pages", 0], ["wish_done", 0], ["eggs_hatched", 0], ["events", 0]]:
		if not w.has(k[0]):
			w[k[0]] = k[1]
		w[k[0]] = int(w[k[0]])
	for ak in w.pages.keys():
		var arr: Array = []
		for i in w.pages[ak]:
			arr.append(int(i))
		w.pages[ak] = arr
	for e in w.eggs:
		e["t"] = float(e.get("t", 0.0))


static func st() -> Dictionary:
	if not P.d.has("welt"):
		ensure(P.d)
	return P.d.welt


# ---------------------------------------------------------------- Tagebuch
static func pages(ak: String) -> Array:
	return st().pages.get(ak, [])


static func has_page(ak: String, i: int) -> bool:
	return pages(ak).has(i)


## Fügt eine Seite hinzu. Rückgabe: war sie neu?
static func add_page(ak: String, i: int) -> bool:
	if has_page(ak, i) or not DW.JOURNAL.has(ak) or i < 0 or i >= DW.JOURNAL[ak].size():
		return false
	if not st().pages.has(ak):
		st().pages[ak] = []
	st().pages[ak].append(i)
	st().new_pages = int(st().new_pages) + 1
	P.count_up("journal", 1)
	P.mark()
	return true


static func page_total() -> int:
	var n := 0
	for ak in st().pages:
		n += st().pages[ak].size()
	return n


static func page_max() -> int:
	var n := 0
	for ak in DW.JOURNAL:
		n += DW.JOURNAL[ak].size()
	return n


## Nächste noch fehlende Seite aus den Fundseiten (1 und 2) oder -1.
static func next_map_page(ak: String) -> int:
	for i in [1, 2]:
		if not has_page(ak, i):
			return i
	return -1


# ---------------------------------------------------------------- Wahrzeichen
static func landmark_seen(ak: String) -> bool:
	return bool(st().landmarks.get(ak, false))


static func see_landmark(ak: String) -> bool:
	if landmark_seen(ak):
		return false
	st().landmarks[ak] = true
	P.mark()
	return true


# ---------------------------------------------------------------- Werkzeuge
static func has_tool(k: String) -> bool:
	return k == "" or bool(st().tools.get(k, false))


static func give_tool(k: String) -> bool:
	if not DW.TOOLS.has(k) or has_tool(k):
		return false
	st().tools[k] = true
	P.mark()
	return true


static func tool_for_area(area: int) -> String:
	for k in DW.TOOLS:
		if int(DW.TOOLS[k].area) == area:
			return k
	return ""


# ---------------------------------------------------------------- Nebenquests
## {state: 0 offen, 1 angenommen, 2 erledigt, got: gefundene Stücke}
static func quest(ak: String) -> Dictionary:
	if not st().quests.has(ak):
		st().quests[ak] = {"state": 0, "got": 0}
	var q: Dictionary = st().quests[ak]
	q["state"] = int(q.get("state", 0))
	q["got"] = int(q.get("got", 0))
	return q


# ---------------------------------------------------------------- Begleiter-Eier
## Legt ein Ei an (höchstens DW.EGG_MAX). key "" = ein Begleiter, den man noch nicht hat (sonst irgendeiner).
## Rückgabe: Schlüssel des Begleiters im Ei oder "" (kein Platz).
static func add_egg(why: String, key := "", rng: RandomNumberGenerator = null) -> String:
	var eggs: Array = st().eggs
	if eggs.size() >= DW.EGG_MAX:
		return ""
	if key == "":
		var cand: Array = []
		for k in CD.ORDER:
			if not CD.owned(k) and not _in_egg(k):
				cand.append(k)
		if cand.is_empty():
			cand = CD.ORDER.duplicate()
		var r := rng if rng != null else RandomNumberGenerator.new()
		if rng == null:
			r.randomize()
		key = String(cand[r.randi() % cand.size()])
	eggs.append({"key": key, "t": P.now(), "why": why})
	P.count_up("eggs", 1)
	P.mark()
	P.changed.emit()
	return key


static func _in_egg(k: String) -> bool:
	for e in st().eggs:
		if String(e.key) == k:
			return true
	return false


static func eggs() -> Array:
	return st().eggs


## Restzeit eines Eis in Sekunden (0 = schlüpfbereit).
static func egg_left(i: int) -> float:
	var e: Dictionary = st().eggs[i]
	return maxf(0.0, float(e.t) + DW.EGG_HATCH_HOURS * 3600.0 - P.now())


## Brütet das Ei aus. Rückgabe: Text für die Meldung ("" = noch nicht so weit).
static func hatch(i: int) -> String:
	var list: Array = st().eggs
	if i < 0 or i >= list.size() or egg_left(i) > 0.0:
		return ""
	var e: Dictionary = list[i]
	list.remove_at(i)
	var k := String(e.key)
	st().eggs_hatched = int(st().eggs_hatched) + 1
	var nm := String(CD.def(k).get("name", k))
	if CD.give(k, "egg"):
		P.mark()
		return "%s ist geschlüpft und gehört jetzt zu deiner Truppe!" % nm
	CD.add_xp(DW.EGG_DUP_XP, k)
	P.mark()
	P.changed.emit()
	return "Aus dem Ei schlüpft ein kleiner %s – dein %s lernt von ihm (+%d Erfahrung)." % [nm, nm, int(DW.EGG_DUP_XP)]


## Begleiter-Ei aus einer seltenen Kiste (DW.EGG_CHEST: Chance je Kistenart). Rückgabe: Eintrag für die Kistenanzeige oder {}.
static func chest_egg(type: String, rng: RandomNumberGenerator) -> Dictionary:
	if not DW.EGG_CHEST.has(type) or eggs().size() >= DW.EGG_MAX:
		return {}
	if rng == null:
		rng = RandomNumberGenerator.new()           # eigener Zufall: die übrigen Ziehungen der Kiste bleiben unverändert
		rng.randomize()
	if rng.randf() >= float(DW.EGG_CHEST[type]) and not force_egg:
		return {}
	var k := add_egg("chest", "", rng)
	if k == "":
		return {}
	return {"rarity": 2, "kind": "egg", "egg": k, "text": "Begleiter-Ei", "sub": "schlüpft im Nest"}
