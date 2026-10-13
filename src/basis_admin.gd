extends RefCounted
## V6 Paket B – Zeilen im Admin-Menü (Taste „-“): Forschung, Wetter der Flut, Belagerung, Schäden, Funde, Verletzte, Rückblick.

const DB = preload("res://src/data_basis.gd")
const R = preload("res://src/research.gd")
const FW = preload("res://src/flood_weather.gd")
const BState = preload("res://src/basis_state.gd")
const Replay = preload("res://src/flood_replay.gd")
const D = preload("res://src/data.gd")

const WEATHERS := ["", "klar", "regen", "nebel", "nacht", "regen+nacht"]


static func fill(ad) -> void:
	ad._section("Basis und Flut (Forschung, Wetter, Belagerung)")
	ad._row([ad._btn("Alles erforschen", func():
		R.ensure(P.d)
		for k in DB.NODES:
			if not R.is_done(k):
				P.d.research.done.append(k)
		P.d.research.cur = ""
		P.buildings_changed.emit()
		ad._say("Alle %d Knoten erforscht" % DB.NODES.size()), "gold"), ad._btn("Forschung zurücksetzen", func():
		P.d.research = {"done": [], "cur": "", "t0": 0.0, "end": 0.0}
		P.buildings_changed.emit()
		ad._say("Forschung zurückgesetzt")), ad._btn("Laufende Forschung fertig", func():
		if R.current() != "":
			P.d.research.end = P.now()
			R.tick(P.now())
		ad._say("Forschung fertig"))])
	var wr: Array = []
	for k in WEATHERS:
		var key := String(k)
		wr.append(ad._btn("Wetter: " + (key if key != "" else "Vorhersage"), func():
			FW.force = key
			ad._refill()
			ad._say("Wetter der nächsten Flut: %s" % (key if key != "" else "nach Vorhersage")), "gold" if FW.force == key else "dark"))
	ad._row(wr)
	ad._row([ad._btn("Mauern beschädigen", func():
		var n := 0
		for b in P.d.buildings:
			if String(b.key) == "wall" and n % 2 == 0:
				b["dmg"] = 0.6
			n += 1
		P.buildings_changed.emit()
		ad._say("Jedes zweite Mauerstück beschädigt")), ad._btn("Hindernis mit Fund", func():
		P._grow_obstacles(true)
		for b in P.d.buildings:
			if String(D.BUILDINGS.get(String(b.key), {}).get("cat", "")) == "obstacle" and not b.has("find"):
				b["find"] = ["chest", "gems", "bp"][randi() % 3]
		P.buildings_changed.emit()
		ad._say("Hindernisse glitzern")), ad._btn("3 Bewohner verletzen", func():
		var got := BState.injure(3)
		ad._say("Verletzt: %s" % ", ".join(got))), ad._btn("Verpasste Flut berechnen", func():
		P.d.week.flood_done = false
		P._auto_flood()
		ad._say("Rückblick der berechneten Flut gespeichert")), ad._btn("Bewertungs-Hinweis", func():
		P.d.rate = {"asked": 0, "answer": "", "pending": false}
		if G.hud != null:
			preload("res://src/basis_ui.gd").ask_rating(G.hud)
		ad._say("„Gefällt dir Rustwall?“"))])
