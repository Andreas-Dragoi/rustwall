extends RefCounted
## Paket L – Zeilen im Admin-Menü (Taste „-“): Ereignis und Feiertag erzwingen, Saison, Kosmetik, Endspiel.

const DL = preload("res://src/data_liveops.gd")
const LO = preload("res://src/liveops.gd")


static func fill(ad) -> void:
	ad._section("Live-Betrieb (Ereignisse, Saison, Kosmetik)")
	var evs: Array = []
	for k in DL.EVENTS:
		var key := String(k)
		evs.append(ad._btn(String(DL.EVENTS[k].name), func():
			LO.force_event = key
			_refresh(ad, "Ereignis: %s" % String(DL.EVENTS[key].name)), "gold" if LO.force_event == key else "dark"))
	evs.append(ad._btn("Kalender", func():
		LO.force_event = ""
		_refresh(ad, "Ereignis nach Kalender: %s" % String(LO.event_def().name)), "gold" if LO.force_event == "" else "dark"))
	ad._row(evs)
	var hs: Array = []
	var cur := String(LO.st().holiday.get("force", ""))
	for k in ["halloween", "weihnachten", "ostern"]:
		var key := String(k)
		hs.append(ad._btn("Fest: " + String(DL.HOLIDAYS[key].name), func():
			LO.set_holiday_force(key)
			_refresh(ad, "Feiertag %s (gilt ab dem nächsten Betreten der Basis oder Expedition)" % String(DL.HOLIDAYS[key].name)), "gold" if cur == key else "dark"))
	hs.append(ad._btn("Fest: nach Datum", func():
		LO.set_holiday_force("")
		_refresh(ad, "Feiertage nach Datum"), "gold" if cur == "" else "dark"))
	hs.append(ad._btn("Fest: aus", func():
		LO.set_holiday_force("aus")
		_refresh(ad, "Keine Feiertage"), "gold" if cur == "aus" else "dark"))
	ad._row(hs)
	ad._row([ad._btn("+1 000 Saisonpunkte", func():
		LO.season().pts = int(LO.season().pts) + 1000
		_refresh(ad, "Pass-Stufe %d" % LO.pass_tier())), ad._btn("Pass-Spur freischalten", func():
		LO.season().paid = true
		_refresh(ad, "Saison-Pass freigeschaltet"), "gold"), ad._btn("Saison jetzt beenden", func():
		LO.season().n = LO.season_n() - 1
		LO.season()
		_refresh(ad, "Saison abgerechnet")), ad._btn("Alle Kosmetik", func():
		for id in DL.COSMETICS:
			LO.give(String(id), "Admin")
		_refresh(ad, "Alle Kosmetik in der Garderobe"), "gold"), ad._btn("+5 Zeitschub", func():
		LO.st().boost = int(LO.st().boost) + 5
		_refresh(ad, "Zeitschub: %d" % int(LO.st().boost)))])
	ad._row([ad._btn("+500 Ereignispunkte", func():
		LO.ev_state().pts = int(LO.ev_state().pts) + 500
		_refresh(ad, "Ereignispunkte: %d" % LO.event_points())), ad._btn("Weltboss-Angriff", func():
		var why := LO.start_raid()
		_refresh(ad, why if why != "" else "Leviathan greift an")), ad._btn("Wochenaufgaben erfüllen", func():
		for q in LO.weekly().list:
			LO.on_progress(String(q.key), int(q.amount))
		_refresh(ad, "Wochenaufgaben erfüllt")), ad._btn("Kalender +1 Tag", func():
		P.d.daily_gift.day = -1
		P._check_daily()
		_refresh(ad, "Login-Kalender: nächster Tag liegt am Bunker")), ad._btn("Prestige +1 Stern", func():
		var hk := String(P.d.hero_sel)
		LO.prestige_xp(hk, DL.PRESTIGE_XP)
		_refresh(ad, "%s: %d Sterne" % [hk, LO.stars(hk)]))])


static func _refresh(ad, text: String) -> void:
	ad._say(text)
	ad._refill()
	if G.main != null and G.main.hud != null and G.main.world != null and G.main.world.mode == "peace":
		G.main.hud._rebuild()
