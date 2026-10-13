extends RefCounted
## Wetter verändert die Flut (V6 Paket B, Kapitel 4.2). Das Wetter wird beim Flutstart festgelegt und gilt die ganze Flut:
##   Regen  – Türme feuern langsamer, Feuer (Flammenturm, Brennen) wirkt schwächer; es regnet sichtbar.
##   Nebel  – Türme sehen weniger weit; dichter Nebel liegt über der Basis.
##   Nacht  – kommt von der Tageszeit der Basis (weather.gd): Gegner +10 % Leben, Beute +10 %.
## Die Vorhersage im Flut-Dialog ist dieselbe Rechnung (fester Zufall je Woche bzw. Tag), daher stimmt sie mit dem Start überein.
## Tests hängen nicht von Datum/Uhrzeit ab: mit --selftest/--autotest ist das Wetter „klar“ und Tag, außer --fweather=regen|nebel|nacht.
## Forschung „Wetterschutz“ halbiert alle Nachteile (Research.weather_k()).

const DB = preload("res://src/data_basis.gd")
const Research = preload("res://src/research.gd")
const Weather = preload("res://src/weather.gd")

static var force := ""            # Tests/Admin: "klar", "regen", "nebel", "nacht", "regen+nacht" …


## Vorhersage für die nächste Flut: {"kind": klar|regen|nebel, "night": bool}
static func forecast(practice: bool, world = null) -> Dictionary:
	var f := force
	if f == "" and G.arg("fweather") != "":
		f = G.arg("fweather")
	if f != "":
		var kind := "klar"
		for k in DB.WEATHER:
			if f.contains(String(k)):
				kind = String(k)
		return {"kind": kind, "night": f.contains("nacht")}
	if G.selftest or G.autotest != "":
		return {"kind": "klar", "night": false}
	var rng := RandomNumberGenerator.new()
	var seed_v := int(P.d.get("created", 0.0)) % 100000 + int(P.d.week.number) * 7919
	if practice:
		seed_v += P.day_index() * 31
	rng.seed = seed_v
	var r := rng.randf()
	var kind2 := "klar"
	var acc := 0.0
	for k in DB.WEATHER:
		acc += float(DB.WEATHER[k].chance)
		if r < acc:
			kind2 = String(k)
			break
	var night := false
	if world != null and world.get("daytime") != null:
		night = String(world.daytime) == "nacht"
	return {"kind": kind2, "night": night}


## Aus base_world.flood_preview(): Wetter in die Flut eintragen (Nacht: Gegner stärker).
static func apply(fd: Dictionary, practice: bool, world) -> void:
	if bool(fd.get("tutorial", false)):
		fd["weather"] = "klar"
		fd["night"] = false
		return
	var fc := forecast(practice, world)
	fd["weather"] = fc.kind
	fd["night"] = fc.night
	if fc.night:
		fd.hp = float(fd.hp) * (1.0 + float(DB.NIGHT.hp) * Research.weather_k())


## Wirkung als Zahlen: {"rate", "range", "fire", "loot"} (Faktoren, 1 = keine Wirkung).
static func factors(kind: String, night: bool) -> Dictionary:
	var wk := Research.weather_k()
	var w: Dictionary = DB.WEATHER.get(kind, {})
	return {"rate": 1.0 - float(w.get("rate", 0.0)) * wk, "range": 1.0 - float(w.get("range", 0.0)) * wk,
		"fire": 1.0 - float(w.get("fire", 0.0)) * wk, "loot": 1.0 + (float(DB.NIGHT.loot) if night else 0.0),
		"hp": 1.0 + (float(DB.NIGHT.hp) * wk if night else 0.0)}


## Name und Wirkung für Anzeigen: [Bild, Name, Text]
static func rows(kind: String, night: bool) -> Array:
	var out: Array = []
	var w: Dictionary = DB.WEATHER.get(kind, DB.WEATHER.klar)
	if kind != "klar" or not night:
		out.append([String(w.icon), String(w.name), String(w.text)])
	if night:
		out.append([String(DB.NIGHT.icon), String(DB.NIGHT.name), String(DB.NIGHT.text)])
	if Research.weather_k() < 0.99 and (kind != "klar" or night):
		out.append(["ui_shield", "Wetterschutz", "Die Nachteile wirken nur halb so stark."])
	return out


static func label(kind: String, night: bool) -> String:
	var n := String(DB.WEATHER.get(kind, DB.WEATHER.klar).name)
	if night:
		n = "%s, Nacht" % n if kind != "klar" else String(DB.NIGHT.name)
	return n


## Flutstart: Faktoren setzen, Regen/Nebel sichtbar machen.
static func begin(world) -> void:
	var fd: Dictionary = world.flood
	var kind := String(fd.get("weather", "klar"))
	var night := bool(fd.get("night", false))
	var f := factors(kind, night)
	world.flood_rate_k = float(f.rate)
	world.flood_range_k = float(f.range)
	world.horde.fire_mult = float(f.fire)
	var wt = world.weather
	if wt != null:
		if kind == "regen" and not wt.raining and wt.rain_allowed():
			Weather.force_rain = 1
			fd["rain_started"] = true
		wt.fog_extra = float(DB.WEATHER.get(kind, {}).get("fog", 0.0))
		if night and String(world.daytime) != "nacht":
			fd["night_forced"] = Weather.force          # erzwungene Nacht (Test/Admin): auch sichtbar machen
			Weather.force = "nacht"
	if kind != "klar" or night:
		P.toast.emit("Wetter der Flut: %s" % label(kind, night))


## Flutende: alles zurück.
static func finish(world) -> void:
	world.flood_rate_k = 1.0
	world.flood_range_k = 1.0
	if world.horde != null:
		world.horde.fire_mult = 1.0
	var wt = world.weather
	if wt != null:
		wt.fog_extra = 0.0
		if bool(world.flood.get("rain_started", false)):
			Weather.force_rain = 0
		if world.flood.has("night_forced"):
			Weather.force = String(world.flood.night_forced)
