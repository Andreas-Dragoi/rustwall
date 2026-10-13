extends RefCounted
## Begleiter (Paket B): alle Zahlen und Texte, die Spielregeln außerhalb der Welt (Besitz, Stufen, Kaufen,
## Herstellen, Finden) und das Stapeln der Ladung (Teil-Modelle aus blender/cargo.py).
## Der Spielstand liegt in P.d.companions = {active: Schlüssel oder "", own: {schlüssel: {lv, xp}}, hello: bool}.
## Die Figur in der Welt steuert src/companion.gd, den Fund-Ort in der Expedition src/companion_find.gd.

const D = preload("res://src/data.gd")
const Models = preload("res://src/models.gd")

const ORDER := ["kistenbein", "esel", "schnecke", "kaefer", "ziege", "drohne", "biber", "waschbaer", "golem", "husky", "eule", "gluehwurm"]
const START := "kistenbein"                     # bekommt jeder Spieler sofort
const MAX_LEVEL := 10
const XP_NEED := [0, 30, 80, 150, 250, 380, 550, 760, 1020, 1350]   # Gesamterfahrung für Stufe 1 … 10
const CARRY_PER_LEVEL := 0.08                   # Tragkraft je Stufe (+8 % der Grund-Tragkraft)
const HP_PER_LEVEL := 0.1
const POWER_PER_LEVEL := 0.12                   # Kampf, Heilen, Münzradius je Stufe
const XP_PER_WEIGHT := 0.08                     # Erfahrung je eingesammelter Gewichtseinheit
const XP_PER_COIN := 0.02
const XP_PER_KILL := 1.0
const DOWN_TIME := 6.0                          # so lange liegt ein umgefallener Begleiter, dann steht er wieder auf
const FOLLOW_DIST := 2.6
const MODEL_SCALE := 1.5                        # Modelle sind in echter Größe gebaut; im Spiel etwas größer (wie die Tiere)
const TELEPORT_DIST := 22.0
const FIND_AREA_TEXT := "Expedition"
## Ladung: Teil-Modell und Höhe (Meter bei Maßstab 1) je Rohstoff
const CARGO := {"wood": "cg_wood", "stone": "cg_stone", "metal": "cg_metal", "fuel": "cg_fuel", "cells": "cg_cells", "parts": "cg_parts", "shards": "cg_shards"}
const CARGO_H := {"wood": 0.27, "stone": 0.28, "metal": 0.23, "fuel": 0.36, "cells": 0.32, "parts": 0.15, "shards": 0.3}
const HEAVY := ["stone", "metal", "cells", "parts"]
const CHOP := ["wood"]
const DIG := ["stone", "metal", "cells", "shards"]

## Begleiter. carry = zusätzliche Tragkraft (Gewichtseinheiten, Rucksack 220), speed = Laufen (m/s), hp = Leben,
## move = Art der Bewegung (quad, hex, biped, slither, fly, box), slots = Ladefläche [Spalten, Reihen, Lagen, Abstand m],
## abil = Besonderheiten (siehe ABIL), get = wie man ihn bekommt (start, craft, buy, find = Gebietsnummer).
const COMPANIONS := {
	"kistenbein": {"name": "Kistenbein", "kind": "Laufkiste mit Beinchen", "carry": 50.0, "speed": 6.0, "hp": 120.0, "move": "quad",
		"text": "Eine alte Obstkiste, die eines Morgens Beine bekam. Trägt alles brav und freut sich über jede Münze.",
		"slots": [2, 2, 2, 0.26], "abil": {"coins": 3.5}, "get": {"start": true, "craft": {"wood": 120, "stone": 40}}, "color": Color("C8823C")},
	"esel": {"name": "Blechesel", "kind": "Packesel-Roboter", "carry": 90.0, "speed": 5.6, "hp": 180.0, "move": "quad",
		"text": "Ein genieteter Lastesel aus Schrott und Federn. Schwere Sachen spürt er kaum.",
		"slots": [2, 2, 2, 0.24], "abil": {"heavy": 0.3}, "get": {"craft": {"metal": 200, "parts": 25, "fuel": 40}}, "color": Color("6F8FC0")},
	"schnecke": {"name": "Lastschnecke Lotte", "kind": "Riesenschnecke mit Korb", "carry": 110.0, "speed": 4.2, "hp": 260.0, "move": "slither",
		"text": "Langsam, aber nichts fällt aus ihrem Korb. Stürzt dein Held, bleibt fast die ganze Ladung heil.",
		"slots": [2, 2, 2, 0.22], "abil": {"protect": 0.85}, "get": {"buy": {"coins": 2500}}, "color": Color("E08A2E")},
	"kaefer": {"name": "Kistenkäfer", "kind": "Panzerkäfer", "carry": 60.0, "speed": 5.0, "hp": 160.0, "move": "hex",
		"text": "Knabbert selbst Holz, Stein und Schrott ab, wenn du in der Nähe arbeitest. In der Staubebene trägt er mehr.",
		"slots": [2, 2, 1, 0.24], "abil": {"mine": 2.6, "area": ["staub", 0.3]}, "get": {"find": 2, "buy": {"coins": 6000}}, "color": Color("2F9A5A")},
	"ziege": {"name": "Bergziege Zilli", "kind": "Bergziege mit Satteltaschen", "carry": 70.0, "speed": 6.5, "hp": 150.0, "move": "quad",
		"text": "Klettert, wo andere rutschen. Hilft beim Steineklopfen und trägt im Frostpass viel mehr.",
		"slots": [2, 1, 3, 0.24], "abil": {"dig": 0.35, "area": ["frost", 0.5]}, "get": {"find": 5, "buy": {"gems": 200}}, "color": Color("F2E8D5")},
	"drohne": {"name": "Flugdrohne Summ", "kind": "Lastdrohne mit Korb", "carry": 40.0, "speed": 8.5, "hp": 90.0, "move": "fly",
		"text": "Saust über alles hinweg, sammelt Münzen in weitem Umkreis und sieht weiter durch den Nebel.",
		"slots": [2, 2, 1, 0.16], "abil": {"coins": 7.0, "scout": 0.25}, "get": {"craft": {"metal": 150, "parts": 40, "cells": 25}}, "color": Color("FFD23E")},
	"biber": {"name": "Biber Balduin", "kind": "Biber mit Weidenkorb", "carry": 55.0, "speed": 5.0, "hp": 150.0, "move": "quad",
		"text": "Nagt mit: Bäume fällst du viel schneller. Im Sumpfwerk fühlt er sich zu Hause.",
		"slots": [2, 2, 2, 0.17], "abil": {"chop": 0.5, "area": ["sumpf", 0.3]}, "get": {"find": 1}, "color": Color("8A5A30")},
	"waschbaer": {"name": "Waschbär Wusel", "kind": "Waschbär mit Rucksack", "carry": 50.0, "speed": 6.2, "hp": 130.0, "move": "quad",
		"text": "Findet überall etwas: seltene Beute doppelt so oft, und versteckte Truhen zeigt er dir.",
		"slots": [2, 2, 2, 0.17], "abil": {"luck": 2.0, "chests": 1.0}, "get": {"find": 3, "buy": {"gems": 150}}, "color": Color("8C8C9A")},
	"golem": {"name": "Mini-Golem Klotz", "kind": "Steingolem", "carry": 130.0, "speed": 4.4, "hp": 340.0, "move": "biped",
		"text": "Ein wandelnder Felsen mit Tragegestell. Trägt am meisten und haut Schleimlinge weg, die zu nahe kommen.",
		"slots": [2, 2, 2, 0.26], "abil": {"fight": 14.0}, "get": {"craft": {"stone": 500, "cells": 40, "parts": 60}, "find": 6}, "color": Color("9A8F96")},
	"husky": {"name": "Schlittenhund Kufe", "kind": "Husky mit Schlitten", "carry": 80.0, "speed": 7.5, "hp": 170.0, "move": "quad",
		"text": "Zieht einen kleinen Schlitten und spornt dich an: du läufst schneller. Im Frostpass in seinem Element.",
		"slots": [2, 2, 2, 0.22], "abil": {"run": 0.1, "area": ["frost", 0.4]}, "get": {"buy": {"gems": 400}}, "color": Color("7A8494")},
	"eule": {"name": "Eule Ulla", "kind": "Späher-Eule", "carry": 30.0, "speed": 7.0, "hp": 80.0, "move": "fly",
		"text": "Sieht alles von oben: der Nebel weicht viel weiter zurück und versteckte Truhen leuchten auf.",
		"slots": [2, 2, 1, 0.13], "abil": {"scout": 0.6, "chests": 1.0}, "get": {"find": 0}, "color": Color("A8743A")},
	"gluehwurm": {"name": "Glühwürmchen Funzel", "kind": "Laternen-Glühwürmchen", "carry": 30.0, "speed": 7.0, "hp": 80.0, "move": "fly",
		"text": "Leuchtet in Dämmerung und Nacht und heilt deinen Helden langsam, wenn gerade niemand angreift.",
		"slots": [2, 2, 1, 0.12], "abil": {"glow": 9.0, "heal": 0.012}, "get": {"find": 4, "buy": {"gems": 250}}, "color": Color("D8FF6A")},
}
## Besonderheiten: Name und Beschreibung (%s = Wert)
const ABIL := {
	"coins": ["Münzsammler", "sammelt Münzen im Umkreis von %s m"],
	"heavy": ["Starker Rücken", "Stein, Metall, Zellen und Bauteile wiegen %s weniger"],
	"protect": ["Sichere Ladung", "stürzt der Held, bleiben %s der Ladung (sonst die Hälfte)"],
	"mine": ["Baut selbst ab", "knabbert alle %s s an einer Quelle in deiner Nähe"],
	"dig": ["Steinbrecher", "Stein, Metall und Kristalle baust du %s schneller ab"],
	"chop": ["Nagezähne", "Bäume fällst du %s schneller"],
	"scout": ["Späher", "Nebel weicht %s weiter zurück"],
	"luck": ["Spürnase", "seltene Beute ×%s"],
	"chests": ["Schatzsucher", "zeigt versteckte Truhen in der Nähe"],
	"fight": ["Kämpfer", "schlägt nahe Gegner (%s Schaden je Schlag)"],
	"run": ["Antreiber", "dein Held läuft %s schneller"],
	"glow": ["Laterne", "leuchtet nachts (%s m)"],
	"heal": ["Heiler", "heilt den Helden um %s des Lebens je Sekunde, wenn niemand angreift"],
	"area": ["Gebietsvorteil", "%s"],
}
const AREA_WORD := {"gruental": "Grüntal", "forst": "Kiefernforst", "staub": "Staubebene", "kueste": "Schrottküste", "sumpf": "Sumpfwerk", "frost": "Frostpass", "krater": "Schleimkrater", "vulkan": "Vulkaninsel", "stadt": "Stadtruinen"}


# ================================================================= Spielstand
## Legt die Felder an (aus P._ensure_fields) und schenkt den ersten Begleiter.
static func ensure(d: Dictionary) -> void:
	if not d.has("companions") or not (d.companions is Dictionary):
		d["companions"] = {}
	var c: Dictionary = d.companions
	if not c.has("own") or not (c.own is Dictionary):
		c["own"] = {}
	if not c.has("active"):
		c["active"] = ""
	if not c.has("hello"):
		c["hello"] = false
	if not c.has("found"):
		c["found"] = 0
	if c.own.is_empty() and not bool(c.get("start_given", false)):
		c.own[START] = {"lv": 1, "xp": 0.0}
		c["active"] = START
	c["start_given"] = true
	for k in c.own.keys():
		if not COMPANIONS.has(k):
			c.own.erase(k)
			continue
		var o: Dictionary = c.own[k]
		o["lv"] = clampi(int(o.get("lv", 1)), 1, MAX_LEVEL)
		o["xp"] = float(o.get("xp", 0.0))
	if String(c.active) != "" and not c.own.has(String(c.active)):
		c["active"] = ""


static func state() -> Dictionary:
	if not P.d.has("companions"):
		ensure(P.d)
	return P.d.companions


static func owned(key: String) -> bool:
	return state().own.has(key)


static func owned_count() -> int:
	return state().own.size()


static func active() -> String:
	var a := String(state().active)
	return a if COMPANIONS.has(a) and owned(a) else ""


static func set_active(key: String) -> bool:
	if key != "" and not owned(key):
		return false
	state()["active"] = key
	P.mark()
	P.changed.emit()
	return true


static func level(key: String) -> int:
	if not owned(key):
		return 1
	return int(state().own[key].lv)


static func xp(key: String) -> float:
	return float(state().own[key].xp) if owned(key) else 0.0


## Erfahrung bis zur nächsten Stufe: [jetzt in dieser Stufe, nötig für diese Stufe]
static func xp_progress(key: String) -> Array:
	var lv := level(key)
	if lv >= MAX_LEVEL:
		return [1.0, 1.0]
	var a: float = XP_NEED[lv - 1]
	var b: float = XP_NEED[lv]
	return [xp(key) - a, b - a]


## Gibt einen Begleiter. why: "buy", "craft", "find", "admin", "start". Rückgabe: war er neu?
static func give(key: String, why := "") -> bool:
	if not COMPANIONS.has(key):
		return false
	var c := state()
	if c.own.has(key):
		return false
	c.own[key] = {"lv": 1, "xp": 0.0}
	if why == "find":
		c["found"] = int(c.get("found", 0)) + 1
	if active() == "":
		c["active"] = key
	P.count_up("companions", 1)
	P.mark()
	P.changed.emit()
	return true


## Erfahrung für den aktiven Begleiter. Rückgabe: neue Stufe (0 = kein Aufstieg).
static func add_xp(n: float, key := "") -> int:
	if key == "":
		key = active()
	if key == "" or n <= 0.0:
		return 0
	var o: Dictionary = state().own[key]
	var lv0 := int(o.lv)
	o.xp = float(o.xp) + n
	var lv := lv0
	while lv < MAX_LEVEL and float(o.xp) >= float(XP_NEED[lv]):
		lv += 1
	if lv != lv0:
		o.lv = lv
		P.mark()
		return lv
	return 0


# ================================================================= Werte
static func def(key: String) -> Dictionary:
	return COMPANIONS.get(key, {})


static func abil_of(key: String, name: String) -> float:
	var a: Dictionary = def(key).get("abil", {})
	if not a.has(name) or a[name] is Array:
		return 0.0
	return float(a[name])


## Wert einer Besonderheit des aktiven Begleiters (0, wenn er sie nicht hat). Kampf, Heilen und Münzradius wachsen mit der Stufe.
static func abil(name: String) -> float:
	var k := active()
	if k == "":
		return 0.0
	var v := abil_of(k, name)
	if v != 0.0 and name in ["fight", "heal", "coins", "glow"]:
		v *= 1.0 + POWER_PER_LEVEL * (level(k) - 1)
	return v


## Zusätzliche Tragkraft (Gewichtseinheiten) eines Begleiters; area_key = Gebiet der Expedition ("" = ohne Gebietsvorteil).
static func carry(key: String, area_key := "") -> float:
	var d: Dictionary = def(key)
	if d.is_empty():
		return 0.0
	var c: float = float(d.carry) * (1.0 + CARRY_PER_LEVEL * (level(key) - 1))
	var ar = d.get("abil", {}).get("area", null)
	if ar is Array and area_key != "" and String(ar[0]) == area_key:
		c *= 1.0 + float(ar[1])
	return c


static func active_carry(area_key := "") -> float:
	var k := active()
	return carry(k, area_key) if k != "" else 0.0


static func max_hp(key: String) -> float:
	return float(def(key).get("hp", 100.0)) * (1.0 + HP_PER_LEVEL * (level(key) - 1))


## Gewichtsfaktor eines Rohstoffs (Starker Rücken).
static func weight_k(r: String) -> float:
	if r in HEAVY:
		return 1.0 - abil("heavy")
	return 1.0


## Abbautempo des Helden (Nagezähne, Steinbrecher).
static func mine_k(r: String) -> float:
	var k := 1.0
	if r in CHOP:
		k += abil("chop")
	if r in DIG:
		k += abil("dig")
	return k


## Anteil des Rucksacks, der beim Sturz des Helden bleibt.
static func death_keep() -> float:
	return maxf(0.5, abil("protect"))


static func luck() -> float:
	return maxf(1.0, abil("luck"))


static func scout_k() -> float:
	return 1.0 + abil("scout")


# ================================================================= Texte
static func abil_lines(key: String) -> Array:
	var out: Array = []
	var a: Dictionary = def(key).get("abil", {})
	for n in a:
		var t: Array = ABIL.get(n, [n, "%s"])
		var v = a[n]
		var vs := ""
		match n:
			"heavy", "dig", "chop", "scout", "run":
				vs = "%d %%" % int(round(float(v) * 100.0))
			"protect":
				vs = "%d %%" % int(round(float(v) * 100.0))
			"heal":
				vs = ("%.1f %%" % (float(v) * 100.0)).replace(".", ",")
			"luck":
				vs = ("%.1f" % float(v)).replace(".", ",").replace(",0", "")
			"mine", "coins":
				vs = ("%.1f" % float(v)).replace(".", ",").replace(",0", "")
			"area":
				vs = "im Gebiet %s Tragkraft +%d %%" % [String(AREA_WORD.get(String(v[0]), String(v[0]))), int(round(float(v[1]) * 100.0))]
			"chests":
				vs = ""
			_:
				vs = str(int(round(float(v))))
		var txt := String(t[1])
		if txt.contains("%s"):
			txt = txt % vs
		out.append([String(t[0]), txt])
	return out


## Wie man ihn bekommt (eine Zeile je Weg).
static func how_lines(key: String) -> Array:
	var g: Dictionary = def(key).get("get", {})
	var out: Array = []
	if g.has("start"):
		out.append("Geschenk zum Start")
	if g.has("craft"):
		out.append("Herstellen: " + cost_text(g.craft))
	if g.has("buy"):
		out.append("Kaufen: " + cost_text(g.buy))
	if g.has("find"):
		var ai := int(g.find)
		out.append("Finden: in der %s „%s“ befreien" % [FIND_AREA_TEXT, String(D.AREAS[ai].name)])
	return out


static func cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for r in cost:
		parts.append("%d %s" % [int(cost[r]), String(D.RES_NAME.get(r, r))])
	return ", ".join(parts)


# ================================================================= Bekommen
## Kaufen im Laden. Rückgabe: "" = gekauft, sonst der Grund.
static func can_buy(key: String) -> String:
	var g: Dictionary = def(key).get("get", {})
	if not g.has("buy"):
		return "Nicht zu kaufen"
	if owned(key):
		return "Schon in deiner Truppe"
	var cost: Dictionary = g.buy
	var gems := int(cost.get("gems", 0))
	var rest := cost.duplicate()
	rest.erase("gems")
	if gems > 0 and P.gems() < gems and not G.ch("freegems"):
		return "Es fehlen %d Juwelen" % (gems - P.gems())
	if not rest.is_empty() and not P.can_pay(rest):
		return "Es fehlt: " + P.missing_text(rest)
	return ""


static func buy(key: String) -> String:
	var why := can_buy(key)
	if why != "":
		return why
	var cost: Dictionary = def(key)["get"]["buy"]
	var rest := cost.duplicate()
	rest.erase("gems")
	if int(cost.get("gems", 0)) > 0 and not P.spend_gems(int(cost.gems), "Begleiter: %s" % String(def(key).name)):
		return "Zu wenig Juwelen"
	if not rest.is_empty() and not P.pay(rest):
		return "Zu wenig Rohstoffe"
	give(key, "buy")
	return ""


static func can_craft(key: String) -> String:
	var g: Dictionary = def(key).get("get", {})
	if not g.has("craft"):
		return "Kann nicht hergestellt werden"
	if owned(key):
		return "Schon in deiner Truppe"
	if not P.can_pay(g.craft):
		return "Es fehlt: " + P.missing_text(g.craft)
	return ""


static func craft(key: String) -> String:
	var why := can_craft(key)
	if why != "":
		return why
	if not P.pay(def(key)["get"]["craft"]):
		return "Zu wenig Rohstoffe"
	give(key, "craft")
	return ""


## Begleiter, die in diesem Gebiet noch zu finden sind.
static func findable(area: int) -> Array:
	var out: Array = []
	for k in ORDER:
		var g: Dictionary = COMPANIONS[k].get("get", {})
		if g.has("find") and int(g.find) == area and not owned(k):
			out.append(k)
	return out


# ================================================================= Ladung stapeln
## Wie viele Teile von jedem Rohstoff (nach Gewichtsanteil am Rucksack), höchstens n_max.
static func cargo_counts(loot: Dictionary, weight: float, cap: float, n_max: int, unit_weight: Callable) -> Dictionary:
	var out := {}
	if cap <= 0.0 or weight <= 0.5 or n_max <= 0:
		return out
	var fill: float = clampf(weight / cap, 0.0, 1.0)
	var n_total := clampi(int(ceil(fill * n_max)), 1, n_max)
	var parts: Array = []
	for r in loot:
		if not CARGO.has(String(r)):
			continue
		var w: float = float(loot[r]) * float(unit_weight.call(String(r)))
		if w > 0.01:
			parts.append([String(r), w])
	parts.sort_custom(func(a, b): return a[1] > b[1])
	n_total = maxi(n_total, mini(parts.size(), n_max))       # jeder Rohstoff ist zu sehen
	var left := n_total
	for i in parts.size():
		var share: float = parts[i][1] / maxf(weight, 0.001)
		var rest_needed := parts.size() - 1 - i
		var n := maxi(1, int(round(share * n_total)))
		n = mini(n, maxi(1, left - rest_needed))
		n = mini(n, left)
		if n > 0:
			out[parts[i][0]] = n
			left -= n
	return out


static func slot_count(slots: Array) -> int:
	return int(slots[0]) * int(slots[1]) * int(slots[2])


## Baut die Teile unter root auf: Spalten (X) × Reihen (Z) × Lagen; Abstand slots[3] in Metern.
## Rückgabe: Anzahl der Teile.
static func build_cargo(root: Node3D, counts: Dictionary, slots: Array) -> int:
	for c in root.get_children():
		root.remove_child(c)
		c.queue_free()
	var cols := int(slots[0])
	var rows := int(slots[1])
	var cell := float(slots[3])
	var k := cell / 0.33
	var list: Array = []
	for r in counts:
		for i in int(counts[r]):
			list.append(String(r))
	var heights := {}
	var n := 0
	for i in list.size():
		var r: String = list[i]
		var ci := n % cols
		var ri := int(n / cols) % rows
		var key := "%d:%d" % [ci, ri]
		var z: float = float(heights.get(key, 0.0))
		var m: Node3D = Models.glb(String(CARGO[r]))
		root.add_child(m)
		var x := (ci - (cols - 1) * 0.5) * cell
		var y := (ri - (rows - 1) * 0.5) * cell
		var yaw := sin(i * 2.3) * 0.25
		if r == "wood":
			yaw = PI * 0.5 * float(rows > cols) + sin(i * 1.7) * 0.08
		m.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * k), Vector3(x, z, y))
		for gi in m.find_children("*", "GeometryInstance3D", true, false):
			(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		heights[key] = z + float(CARGO_H.get(r, 0.3)) * k
		n += 1
	return n
