extends RefCounted
## Alle Spielwerte von Rustwall (Version 2). Entspricht den Tabellen im Spielkonzept.
## Balancing: hier Zahlen ändern, der Code liest alles von hier.

const CELL := 2.0                                   # 1 Rasterfeld = 2 x 2 Meter
const GRID_BY_BUNKER := [24, 26, 28, 30, 32, 34, 36, 38, 40, 44]
const GRID_MAX := 44
const CHAR_SCALE := 1.5

# ---------------------------------------------------------------- Farben (aus dem Referenzbild gemessen)
const C_NAVY := Color("0F2742")
const C_SKY := Color("38A9F5")
const C_GOLD := Color("FFD23E")
const C_BAR_BLUE := Color("02A6FD")
const C_BAR_RED := Color("FB3D54")
const C_COIN := Color("FDCA14")
const C_GRASS := Color("8FB02A")
const C_GRASS_D := Color("4F7A2A")
const C_PINE := Color("3D6B3A")
const C_PATH := Color("EDA865")
const C_ROCK := Color("9A8F96")
const C_ROCK_D := Color("5E5868")
const C_WATER := Color("5DB2EA")
const C_STONE := Color("A7ADC6")
const C_BLUE_METAL := Color("3C5CA4")
const C_GLOW := Color("FFD23E")
const C_SAND := Color("E8AE64")
const C_WOOD := Color("A9622F")
const C_WOOD_D := Color("7A4522")
const C_OLIVE := Color("9C9A4A")
const C_HELM_BLUE := Color("0469CC")
const C_SUIT := Color("E08A2E")
const C_RED := Color("D54144")
const C_RED_D := Color("9D2A35")
const C_SLIME := Color("94B128")
const C_SLIME_L := Color("C4DB45")
const C_FIRE := Color("FD932C")
const C_FLAG := Color("026AED")
const C_SKIN := Color("F2C29B")
const C_DARK := Color("2A2D3A")
const C_STEEL := Color("7C879C")

# ---------------------------------------------------------------- Rohstoffe
const RES := ["coins", "wood", "stone", "metal", "fuel", "cells", "parts", "shards", "gems"]
const RES_NAME := {"coins": "Münzen", "wood": "Holz", "stone": "Stein", "metal": "Metall", "fuel": "Treibstoff",
	"cells": "Energiezellen", "parts": "Bauteile", "shards": "Sternsplitter", "gems": "Juwelen"}
const RES_COLOR := {"coins": Color("FDCA14"), "wood": Color("B8742F"), "stone": Color("A7ADC6"), "metal": Color("6F8FC0"),
	"fuel": Color("E0473C"), "cells": Color("3FD2F5"), "parts": Color("C9CED8"), "shards": Color("FFE98A"), "gems": Color("4FB8FF")}
const CAP_BASE := {"wood": 1500.0, "stone": 1500.0, "metal": 1200.0, "fuel": 400.0, "cells": 200.0}
const START_RES := {"coins": 350, "wood": 300, "stone": 60, "metal": 0, "fuel": 80, "cells": 0, "parts": 10, "shards": 0, "gems": 100}
const SENDABLE := ["wood", "stone", "metal", "fuel"]

# ---------------------------------------------------------------- Gebäude
## size: Felder (Breite, Tiefe). max: erlaubte Anzahl je Bunker-Stufe 1..10.
## cost: Grundkosten Stufe 1; jede weitere Stufe x COST_GROWTH. Bauzeiten stehen in BUILD_TIME (nach Zielstufe).
const COST_GROWTH := 1.6

## Bauzeit in Sekunden nach Gruppe und Zielstufe 1..10. Niemand wartet in der ersten Viertelstunde länger als eine Minute.
const BUILD_TIME := {
	"def": [20, 120, 600, 1800, 5400, 10800, 21600, 36000, 50400, 72000],          # Türme, Tore, Fallen
	"prod": [30, 180, 900, 2700, 7200, 14400, 28800, 43200, 64800, 86400],         # Produktion, Lager
	"special": [45, 300, 1200, 3600, 9000, 18000, 32400, 50400, 72000, 100800],    # besondere Gebäude
	"core": [0, 60, 600, 3600, 10800, 28800, 57600, 86400, 129600, 172800],        # Bunker
}
## Mauern: Sekunden je Stück für Holz (neu bauen), Stein und Metall (verbessern). Ein Auftrag fasst mehrere Stücke zusammen.
const WALL_TIME := [4.0, 30.0, 180.0]
const WALL_UP_COST := [{}, {"stone": 20}, {"metal": 20}]
const WALL_JOB_MAX := 25
## Schmuck, der ohne Baudrohne aufgestellt wird (ein Bewohner trägt ihn hin).
const NO_DRONE := ["laterne", "flagge", "blumen"]

static func build_group(key: String) -> String:
	var cat: String = BUILDINGS[key].cat
	if cat == "core":
		return "core"
	if cat == "prod":
		return "prod"
	if cat == "special":
		return "special"
	return "def"

## Reine Bauzeit ohne Boni. level = Zielstufe.
static func build_time(key: String, level: int) -> float:
	var def: Dictionary = BUILDINGS[key]
	if key == "wall":
		return float(WALL_TIME[clampi(level - 1, 0, 2)])
	if def.cat == "deco" or def.cat == "obstacle":
		return float(def.get("time", 5))
	return float(BUILD_TIME[build_group(key)][clampi(level - 1, 0, 9)])

# ---------------------------------------------------------------- Gegnerfamilien (je Gebiet eine)
## weak: Schadens-Faktor je Element (kugel, feuer, wasser, eis, blitz, explosion, gift); fehlende Einträge = 1,0.
const AREA_FAMILY := ["schleim", "wald", "wueste", "untote", "mutanten", "eis", "daemonen", "magma", "maschinen"]
const FAMILIES := {
	"schleim": {"name": "Schleimlinge", "mood": "frech, hüpfend, grün", "weak": {}, "weak_text": "keine Schwäche"},
	"wald": {"name": "Waldgeister und Pilzvolk", "mood": "unheimlich, moosig, leuchtende Augen", "weak": {"feuer": 1.5, "gift": 0.5}, "weak_text": "Feuer +50 % · Gift −50 %"},
	"wueste": {"name": "Wüstenmonster und Schrottvieh", "mood": "rostig, sandig, gepanzert", "weak": {"explosion": 1.3, "feuer": 0.7}, "weak_text": "Explosion +30 % · Feuer −30 %"},
	"untote": {"name": "Untote Seeleute", "mood": "nass, algig, Piraten", "weak": {"blitz": 1.5}, "slow": 0.5, "weak_text": "Blitz +50 % · Verlangsamen wirkt halb"},
	"mutanten": {"name": "Mutanten und kaputte Maschinen", "mood": "giftgrün, Rohre, Blasen", "weak": {"eis": 1.4, "gift": 0.0}, "weak_text": "Eis +40 % · Gift wirkungslos"},
	"eis": {"name": "Eiswesen", "mood": "bläulich, kristallin, Atemwolken", "weak": {"feuer": 1.5, "eis": 0.0}, "weak_text": "Feuer +50 % · Eis wirkungslos"},
	"daemonen": {"name": "Dämonen", "mood": "rot-schwarz, Hörner, Glut", "weak": {"wasser": 1.3, "eis": 1.3, "feuer": 0.0}, "weak_text": "Wasser/Eis +30 % · Feuer wirkungslos"},
	"magma": {"name": "Magma-Wesen", "mood": "Basalt, Glut, Asche, Obsidian", "weak": {"wasser": 1.6, "eis": 1.3, "feuer": 0.0}, "weak_text": "Wasser +60 % · Eis +30 % · Feuer wirkungslos"},
	"maschinen": {"name": "Maschinen", "mood": "Blech, Baustellengelb, Leuchtdioden, Funken", "weak": {"blitz": 1.5, "wasser": 1.3, "gift": 0.0}, "weak_text": "Blitz +50 % · Wasser +30 % · Gift wirkungslos"},
}

# ---------------------------------------------------------------- Außenbasen
## Je Gebiet (Schlüssel wie in AREAS): Spezialbau und Vorteile. effects: stat, base (Stufe 1), step (je weitere Stufe).
const OUTPOSTS := {
	"gruental": {"special": "Holzfällerlager", "effects": [{"stat": "prod_wood", "base": 0.10, "step": 0.025}, {"stat": "deliver_wood", "base": 100.0, "step": 50.0}]},
	"forst": {"special": "Jägerhütte", "effects": [{"stat": "hero_xp", "base": 0.08, "step": 0.03}, {"stat": "heal_ooc", "base": 1.0, "step": 0.5}]},
	"staub": {"special": "Tankstelle", "effects": [{"stat": "fuel", "base": 0.10, "step": 0.025}, {"stat": "vehicle_speed", "base": 0.04, "step": 0.01}]},
	"kueste": {"special": "Schrotthafen", "effects": [{"stat": "prod_metal", "base": 0.10, "step": 0.025}, {"stat": "deliver_parts", "base": 2.0, "step": 1.0}]},
	"sumpf": {"special": "Pumpwerk", "effects": [{"stat": "prod_fuel", "base": 0.10, "step": 0.025}, {"stat": "prod_cells", "base": 0.10, "step": 0.025}, {"stat": "tower_rate", "base": 0.03, "step": 0.01}]},
	"frost": {"special": "Bergwacht", "effects": [{"stat": "wall_hp", "base": 0.10, "step": 0.025}, {"stat": "prod_stone", "base": 0.10, "step": 0.025}]},
	"krater": {"special": "Forschungsstation", "effects": [{"stat": "boss_dmg", "base": 0.08, "step": 0.03}, {"stat": "deliver_shards", "base": 0.5, "step": 0.375}]},
	"vulkan": {"special": "Obsidianschmiede", "effects": [{"stat": "heat_resist", "base": 0.15, "step": 0.05}, {"stat": "deliver_cells", "base": 6.0, "step": 3.0}]},
	"stadt": {"special": "Umspannwerk", "effects": [{"stat": "prod_cells", "base": 0.12, "step": 0.03}, {"stat": "deliver_parts", "base": 4.0, "step": 2.0}]},
}
## Anzeige der Vorteile: Text und Art (pct = Anteil als Prozent, num = Menge, rate = je Sekunde, minus = Prozent weniger).
const OUTPOST_STAT_TEXT := {
	"prod_wood": ["Holzproduktion", "pct"], "prod_stone": ["Steinproduktion", "pct"], "prod_metal": ["Metallproduktion", "pct"],
	"prod_fuel": ["Treibstoffproduktion", "pct"], "prod_cells": ["Energiezellen-Produktion", "pct"], "hero_xp": ["Helden-Erfahrung", "pct"],
	"heal_ooc": ["Heilung außerhalb des Kampfes (Leben/s)", "rate"], "fuel": ["Treibstoff für Expeditionen", "minus"],
	"vehicle_speed": ["Fahrzeugtempo", "pct"], "tower_rate": ["Feuertempo der Türme", "pct"], "wall_hp": ["Leben von Mauern und Toren", "pct"],
	"boss_dmg": ["Schaden gegen Bosse", "pct"], "deliver_wood": ["Holz täglich", "num"], "deliver_parts": ["Bauteile täglich", "num"],
	"deliver_shards": ["Sternsplitter täglich", "num"], "deliver_cells": ["Energiezellen täglich", "num"], "heat_resist": ["Hitzeanstieg auf der Vulkaninsel", "minus"],
}
const OUTPOST_DELIVER := {"deliver_wood": "wood", "deliver_parts": "parts", "deliver_shards": "shards", "deliver_cells": "cells"}
const OUTPOST_MAX_LEVEL := 5
const OUTPOST_DELIVER_DAYS := 3                     # höchstens so viele Tage Lieferung sammeln sich an
const OUTPOST_PACK_BONUS := 0.05                    # Rucksack je Außenbasis
const OUTPOST_PACK_MAX := 0.35
const OUTPOST_AUTO_BONUS := 0.2                     # Auto-Expeditionen in ein Gebiet mit Außenbasis
const OUTPOST_TALBUND_LEVEL := 3                    # alle Außenbasen mindestens auf dieser Stufe: Titel „Talbund“
const OUTPOST_TALBUND_FLOOD := 0.1                  # Belohnung der Flut +10 %
const OUTPOST_SIEGE_FUEL := 0.5                     # Befreiung kostet halben Treibstoff
const OUTPOST_SIEGE_WAVES := 3
const OUTPOST_SIEGE_TIME := 240.0

# ---------------------------------------------------------------- Juwelen
## Preis fürs Beschleunigen: Stützpunkte (Sekunden, Juwelen), dazwischen gerade gerechnet und aufgerundet.
const GEM_FREE_SECONDS := 60.0
const GEM_CURVE := [[60.0, 1.0], [3600.0, 20.0], [86400.0, 260.0], [172800.0, 460.0]]
const GEM_CONFIRM := 50
const GEM_DRONE_COST := [500, 1200]
const DAILY_GIFT := [5, 5, 8, 8, 10, 10, 25]
const GEM_PACKS := [
	{"key": "gems_80", "name": "Handvoll", "gems": 80, "price": "0,99 €"},
	{"key": "gems_500", "name": "Beutel", "gems": 500, "price": "4,99 €"},
	{"key": "gems_1200", "name": "Kiste", "gems": 1200, "price": "9,99 €"},
	{"key": "gems_2500", "name": "Truhe", "gems": 2500, "price": "19,99 €"},
	{"key": "gems_6500", "name": "Tresor", "gems": 6500, "price": "49,99 €"},
	{"key": "gems_14000", "name": "Schatzkammer", "gems": 14000, "price": "99,99 €"},
]
const GEM_REWARD := {"quest": 3, "quests_all": 10, "flood": 20, "practice": 3, "level": 10, "hero5": 5, "outpost": 30, "outpost_up": 15}
const FLAG_COLORS := [["Blau", "026AED", 0], ["Rot", "D54144", 60], ["Grün", "3FA35A", 60], ["Gold", "F5B41E", 120], ["Violett", "9658E8", 120], ["Schwarz", "2A2D3A", 200]]

static func gem_cost(seconds: float) -> int:
	if seconds <= GEM_FREE_SECONDS:
		return 0
	var prev: Array = GEM_CURVE[0]
	for i in range(1, GEM_CURVE.size()):
		var nx: Array = GEM_CURVE[i]
		if seconds <= float(nx[0]):
			var k := (seconds - float(prev[0])) / (float(nx[0]) - float(prev[0]))
			return int(ceil(float(prev[1]) + (float(nx[1]) - float(prev[1])) * k - 0.0001))
		prev = nx
	var last: Array = GEM_CURVE[GEM_CURVE.size() - 1]
	var before: Array = GEM_CURVE[GEM_CURVE.size() - 2]
	var slope := (float(last[1]) - float(before[1])) / (float(last[0]) - float(before[0]))
	return int(ceil(float(last[1]) + (seconds - float(last[0])) * slope))

## Erfolge: stat = Zähler in P.stat(), tiers = Schwellen, gems = Belohnung je Schwelle.
const ACHIEVEMENTS := [
	{"key": "kills", "name": "Schleimjäger", "text": "Besiege %s Gegner", "tiers": [100, 1000, 5000, 20000, 100000], "gems": [10, 15, 25, 40, 100]},
	{"key": "floods_won", "name": "Deichgraf", "text": "Gewinne %s Fluten", "tiers": [1, 5, 15, 40], "gems": [15, 25, 40, 100]},
	{"key": "expeditions", "name": "Entdecker", "text": "Schließe %s Expeditionen ab", "tiers": [1, 10, 40, 150], "gems": [10, 15, 30, 80]},
	{"key": "chests", "name": "Kistenknacker", "text": "Öffne %s Beutekisten", "tiers": [5, 30, 120, 500], "gems": [10, 15, 30, 80]},
	{"key": "walls", "name": "Maurer", "text": "Baue %s Mauern", "tiers": [10, 50, 100, 250], "gems": [10, 15, 25, 50]},
	{"key": "builds", "name": "Baumeister", "text": "Baue oder verbessere %s Gebäude", "tiers": [5, 25, 80, 200], "gems": [10, 15, 30, 60]},
	{"key": "bunker", "name": "Festung", "text": "Erreiche Bunker-Stufe %s", "tiers": [3, 5, 8, 10], "gems": [15, 25, 50, 100]},
	{"key": "heroes", "name": "Mannschaft", "text": "Habe %s Helden", "tiers": [2, 4, 6], "gems": [15, 30, 60]},
	{"key": "hero_level", "name": "Veteran", "text": "Bringe einen Helden auf Stufe %s", "tiers": [10, 20, 30, 40], "gems": [15, 25, 50, 100]},
	{"key": "hero_levels", "name": "Ausbilder", "text": "Sammle %s Heldenstufen (alle Helden zusammen)", "tiers": [20, 60, 120, 200], "gems": [10, 20, 40, 80]},
	{"key": "level", "name": "Kommandant", "text": "Erreiche Spielerstufe %s", "tiers": [10, 25, 45, 60], "gems": [15, 25, 50, 100]},
	{"key": "vehicles", "name": "Fuhrpark", "text": "Besitze %s Fahrzeuge", "tiers": [1, 3, 5], "gems": [10, 25, 50]},
	{"key": "outposts", "name": "Talbund", "text": "Errichte %s Außenbasen", "tiers": [1, 3, 5, 7], "gems": [20, 30, 50, 100]},
	{"key": "collected", "name": "Sammler", "text": "Sammle %s Rohstoffe an Gebäuden ein", "tiers": [1000, 10000, 100000, 1000000], "gems": [10, 15, 30, 60]},
	{"key": "obstacles", "name": "Gärtner", "text": "Räume %s Hindernisse weg", "tiers": [5, 25, 100], "gems": [10, 20, 40]},
	{"key": "merges", "name": "Tüftler", "text": "Verschmelze %s Gegenstände", "tiers": [1, 10, 40], "gems": [10, 20, 40]},
	{"key": "bestiary", "name": "Monsterkundler", "text": "Entdecke %s Gegnerarten", "tiers": [8, 20, 32, 44], "gems": [10, 20, 40, 80]},
]
const BUILDINGS := {
	"bunker": {"name": "Bunker", "cat": "core", "size": [4, 4], "unlock": 1, "max": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1], "hp": 500.0,
		"desc": "Das Herz der Basis. Seine Stufe bestimmt, was gebaut werden darf."},
	"mg": {"name": "MG-Turm", "cat": "def", "size": [2, 2], "unlock": 1, "max": [2, 2, 3, 3, 4, 4, 5, 5, 6, 6], "hp": 320.0,
		"cost": {"coins": 60, "wood": 40}, "tower": "mg", "desc": "Schnelles Feuer gegen einzelne Gegner."},
	"kanone": {"name": "Kanone", "cat": "def", "size": [3, 3], "unlock": 2, "max": [0, 1, 1, 2, 2, 3, 3, 4, 4, 4], "hp": 450.0,
		"cost": {"coins": 180, "stone": 120}, "tower": "cannon", "desc": "Langsamer, starker Schuss mit Flächenschaden."},
	"wachturm": {"name": "Wachturm", "cat": "def", "size": [2, 2], "unlock": 3, "max": [0, 0, 1, 2, 2, 3, 3, 4, 4, 4], "hp": 280.0,
		"cost": {"coins": 220, "wood": 180}, "tower": "watch", "desc": "Ein Schütze trifft weit entfernte, starke Gegner."},
	"flammenturm": {"name": "Flammenturm", "cat": "def", "size": [2, 2], "unlock": 4, "max": [0, 0, 0, 1, 1, 2, 2, 3, 3, 3], "hp": 400.0,
		"cost": {"coins": 380, "metal": 120, "fuel": 50}, "tower": "flame", "desc": "Kurzer Feuerstrahl, ideal hinter Mauern."},
	"moerser": {"name": "Mörser", "cat": "def", "size": [3, 3], "unlock": 5, "max": [0, 0, 0, 0, 1, 1, 2, 2, 3, 3], "hp": 300.0,
		"cost": {"coins": 600, "stone": 300, "metal": 150}, "tower": "mortar", "desc": "Bogenschuss mit großem Flächenschaden."},
	"tesla": {"name": "Tesla-Spule", "cat": "def", "size": [2, 2], "unlock": 6, "max": [0, 0, 0, 0, 0, 1, 1, 2, 3, 3], "hp": 360.0,
		"cost": {"coins": 900, "metal": 300, "cells": 40}, "tower": "tesla", "desc": "Kettenblitz über mehrere Gegner, verlangsamt."},
	"rakete": {"name": "Raketenturm", "cat": "def", "size": [3, 3], "unlock": 7, "max": [0, 0, 0, 0, 0, 0, 1, 1, 2, 2], "hp": 380.0,
		"cost": {"coins": 1600, "metal": 600, "fuel": 200}, "tower": "rocket", "desc": "Gegen Brocken und Bosse."},
	"schild": {"name": "Schildgenerator", "cat": "def", "size": [3, 3], "unlock": 8, "max": [0, 0, 0, 0, 0, 0, 0, 1, 1, 1], "hp": 500.0,
		"cost": {"coins": 2500, "metal": 800, "cells": 150}, "desc": "Halbiert den Schaden an allen Gebäuden im Umkreis von 8 Feldern."},
	"eis": {"name": "Eiskanone", "cat": "def", "size": [3, 3], "unlock": 9, "max": [0, 0, 0, 0, 0, 0, 0, 0, 1, 2], "hp": 380.0,
		"cost": {"coins": 3200, "metal": 900, "cells": 200}, "tower": "ice", "desc": "Friert Gruppen für 2 Sekunden ein."},
	"luftabwehr": {"name": "Luftabwehr", "cat": "def", "size": [2, 2], "unlock": 9, "max": [0, 0, 0, 0, 0, 0, 0, 0, 1, 2], "hp": 320.0,
		"cost": {"coins": 2600, "metal": 800}, "tower": "aa", "desc": "Nur gegen fliegende Schleimlinge, dafür sehr stark."},
	"wall": {"name": "Mauer", "cat": "wall", "size": [1, 1], "unlock": 1, "max": [50, 70, 90, 110, 130, 150, 175, 200, 225, 250], "hp": 260.0,
		"cost": {"wood": 12}, "desc": "Sperrt Gegner, Helden und Fahrzeuge. Aus Holz; ab Bunker 4 zu Stein, ab Bunker 7 zu Metall verbesserbar."},
	"tor": {"name": "Tor", "cat": "wall", "size": [2, 1], "unlock": 1, "max": [2, 2, 3, 3, 4, 4, 5, 5, 6, 6], "hp": 572.0,
		"cost": {"coins": 60, "wood": 40}, "desc": "Öffnet sich für Helden, Bewohner und Fahrzeuge. Für Gegner ist es eine Mauer."},
	"stachel": {"name": "Stachelfalle", "cat": "trap", "size": [1, 1], "unlock": 2, "max": [0, 2, 3, 4, 4, 5, 5, 6, 6, 6], "hp": 0.0,
		"cost": {"coins": 80, "wood": 60}, "desc": "Schadet allen, die darüberlaufen. Hält 30 Auslösungen pro Flut."},
	"kleb": {"name": "Klebefalle", "cat": "trap", "size": [2, 2], "unlock": 5, "max": [0, 0, 0, 0, 1, 1, 2, 2, 3, 3], "hp": 0.0,
		"cost": {"coins": 300, "fuel": 60}, "desc": "Verlangsamt alle Gegner auf der Fläche stark."},
	"mine": {"name": "Sprengmine", "cat": "trap", "size": [1, 1], "unlock": 6, "max": [0, 0, 0, 0, 0, 1, 2, 2, 3, 3], "hp": 0.0,
		"cost": {"coins": 400, "metal": 120}, "desc": "Explodiert einmal pro Flut mit großem Radius."},
	"saege": {"name": "Sägewerk", "cat": "prod", "size": [3, 3], "unlock": 1, "max": [1, 1, 2, 2, 2, 3, 3, 3, 3, 3], "hp": 300.0,
		"cost": {"coins": 80, "wood": 30}, "prod": "wood", "rate": 70.0, "desc": "Erzeugt Holz über Zeit."},
	"steinbruch": {"name": "Steinbruch", "cat": "prod", "size": [3, 3], "unlock": 2, "max": [0, 1, 1, 2, 2, 2, 3, 3, 3, 3], "hp": 300.0,
		"cost": {"coins": 150, "wood": 120}, "prod": "stone", "rate": 55.0, "desc": "Erzeugt Stein über Zeit."},
	"presse": {"name": "Schrottpresse", "cat": "prod", "size": [3, 3], "unlock": 4, "max": [0, 0, 0, 1, 1, 1, 2, 2, 2, 2], "hp": 320.0,
		"cost": {"coins": 400, "wood": 250, "stone": 200}, "prod": "metal", "rate": 40.0, "desc": "Erzeugt Metall über Zeit."},
	"raffinerie": {"name": "Raffinerie", "cat": "prod", "size": [3, 3], "unlock": 5, "max": [0, 0, 0, 0, 1, 1, 1, 2, 2, 2], "hp": 320.0,
		"cost": {"coins": 600, "stone": 300, "metal": 150}, "prod": "fuel", "rate": 14.0, "desc": "Erzeugt Treibstoff über Zeit."},
	"generator": {"name": "Generator", "cat": "prod", "size": [2, 2], "unlock": 6, "max": [0, 0, 0, 0, 0, 1, 1, 1, 2, 2], "hp": 280.0,
		"cost": {"coins": 900, "metal": 350, "fuel": 80}, "prod": "cells", "rate": 5.0, "desc": "Erzeugt Energiezellen über Zeit."},
	"lager": {"name": "Lager", "cat": "prod", "size": [3, 3], "unlock": 1, "max": [1, 1, 2, 2, 3, 3, 4, 4, 4, 4], "hp": 400.0,
		"cost": {"coins": 100, "wood": 80}, "desc": "Erhöht die Obergrenze für Rohstoffe."},
	"quartier": {"name": "Quartier", "cat": "special", "size": [3, 2], "unlock": 1, "max": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1], "hp": 350.0,
		"cost": {"coins": 50}, "screen": "heroes", "desc": "Helden auswählen, ausrüsten, Talente verteilen."},
	"kistenlager": {"name": "Kistenlager", "cat": "special", "size": [2, 2], "unlock": 1, "max": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1], "hp": 250.0,
		"cost": {"coins": 50}, "screen": "chests", "desc": "Hier werden Beutekisten geöffnet."},
	"werkstatt": {"name": "Werkstatt", "cat": "special", "size": [3, 3], "unlock": 2, "max": [0, 1, 1, 1, 1, 1, 1, 1, 1, 1], "hp": 350.0,
		"cost": {"coins": 200, "wood": 150, "stone": 80}, "screen": "workshop", "desc": "Waffen verbessern, zerlegen und verschmelzen."},
	"garage": {"name": "Garage", "cat": "special", "size": [4, 3], "unlock": 3, "max": [0, 0, 1, 1, 1, 1, 1, 1, 1, 1], "hp": 400.0,
		"cost": {"coins": 350, "wood": 200, "stone": 200}, "screen": "garage", "desc": "Fahrzeuge freischalten und verbessern."},
	"funkturm": {"name": "Funkturm", "cat": "special", "size": [2, 2], "unlock": 3, "max": [0, 0, 1, 1, 1, 1, 1, 1, 1, 1], "hp": 250.0,
		"cost": {"coins": 250, "wood": 150}, "screen": "social", "desc": "Freunde, Post und Ranglisten."},
	"clanhalle": {"name": "Clanhalle", "cat": "special", "size": [4, 4], "unlock": 5, "max": [0, 0, 0, 0, 1, 1, 1, 1, 1, 1], "hp": 500.0,
		"cost": {"coins": 1200, "wood": 600, "stone": 600}, "screen": "clan", "desc": "Clan gründen oder beitreten."},
	"labor": {"name": "Labor", "cat": "special", "size": [3, 3], "unlock": 8, "max": [0, 0, 0, 0, 0, 0, 0, 1, 1, 1], "hp": 350.0,
		"cost": {"coins": 3000, "metal": 600, "cells": 100}, "screen": "forschung", "desc": "Forschung: Türme, Wirtschaft und Helden dauerhaft verbessern. Höhere Laborstufen öffnen tiefere Reihen und forschen schneller."},
	"training": {"name": "Trainingsplatz", "cat": "special", "size": [3, 3], "unlock": 3, "max": [0, 0, 1, 1, 1, 1, 1, 1, 1, 1], "hp": 300.0,
		"cost": {"coins": 300, "wood": 250}, "desc": "Ein Held, der gerade nicht gespielt wird, sammelt hier Erfahrung."},
	# V6 Paket E: Rosas Tauschladen – erst nach der Rettung der Händlerin baubar (Story.building_allowed)
	"tauschladen": {"name": "Tauschladen", "cat": "special", "size": [2, 2], "unlock": 1, "max": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1], "hp": 260.0,
		"cost": {"coins": 400, "wood": 200, "stone": 100}, "screen": "tausch", "story": "haendlerin", "desc": "Rosa, die Händlerin, tauscht hier Rohstoffe – jeden Tag neue Angebote, einmal in der Woche ein Begleiter-Ei."},
	"laterne": {"name": "Laterne", "cat": "deco", "size": [1, 1], "unlock": 1, "max": [8, 10, 12, 14, 16, 18, 20, 22, 24, 26], "hp": 0.0, "cost": {"coins": 30}, "time": 5, "desc": "Warmes Licht für die Basis."},
	"flagge": {"name": "Flagge", "cat": "deco", "size": [1, 1], "unlock": 1, "max": [4, 5, 6, 7, 8, 9, 10, 11, 12, 12], "hp": 0.0, "cost": {"coins": 40}, "time": 5, "desc": "Zeigt deine Farbe."},
	"blumen": {"name": "Blumenbeet", "cat": "deco", "size": [1, 1], "unlock": 1, "max": [8, 10, 12, 14, 16, 18, 20, 22, 24, 26], "hp": 0.0, "cost": {"coins": 20}, "time": 5, "desc": "Macht die Basis freundlicher."},
	"statue": {"name": "Heldenstatue", "cat": "deco", "size": [2, 2], "unlock": 4, "max": [0, 0, 0, 1, 1, 2, 2, 3, 3, 4], "hp": 0.0, "cost": {"coins": 500, "stone": 300}, "time": 120, "desc": "Zu Ehren deiner Helden."},
	# ---- Paket G2: fünf neue Fallen (4.1)
	"teer": {"name": "Teergrube", "cat": "trap", "size": [2, 2], "unlock": 3, "max": [0, 0, 1, 1, 2, 2, 2, 3, 3, 3], "hp": 0.0,
		"cost": {"coins": 250, "fuel": 40}, "desc": "Zäher Teer bremst Gegner um 70 %. Läuft ein Brennender hinein, fängt die Grube Feuer."},
	"feder": {"name": "Federbrett", "cat": "trap", "size": [1, 1], "unlock": 4, "max": [0, 0, 0, 2, 2, 3, 3, 4, 4, 4], "hp": 0.0,
		"cost": {"coins": 300, "wood": 120, "metal": 40}, "desc": "Schleudert Gegner zurück (alle 3 s). Brocken und Bosse sind zu schwer."},
	"koeder": {"name": "Lockköder", "cat": "trap", "size": [1, 1], "unlock": 5, "max": [0, 0, 0, 0, 1, 1, 2, 2, 2, 3], "hp": 0.0,
		"cost": {"coins": 200, "fuel": 20}, "desc": "Lockt Gegner im Umkreis von 14 m für 8 s an – dreimal pro Flut."},
	"zaun": {"name": "Elektrozaun", "cat": "trap", "size": [2, 1], "unlock": 6, "max": [0, 0, 0, 0, 0, 1, 2, 2, 3, 3], "hp": 0.0,
		"cost": {"coins": 450, "metal": 100, "cells": 10}, "desc": "Schlägt alle 1,5 s Funken: Blitzschaden und kurze Betäubung. Hält 40 Entladungen pro Flut."},
	"eisfalle": {"name": "Eisfalle", "cat": "trap", "size": [1, 1], "unlock": 7, "max": [0, 0, 0, 0, 0, 0, 1, 2, 2, 3], "hp": 0.0,
		"cost": {"coins": 600, "metal": 150, "cells": 30}, "desc": "Friert alle Gegner im Umkreis von 2,5 m für 2,5 s ein und lädt 8 s nach. Eiswesen bleiben unberührt."},
	# ---- Paket G2: Deko (4.1 / 7.2); deco = Deko-Punkte (Summe gibt Bewohner-Zufriedenheit → Produktion +%)
	"bank": {"name": "Gartenbank", "cat": "deco", "size": [1, 1], "unlock": 1, "max": [4, 6, 8, 10, 12, 14, 16, 18, 20, 22], "hp": 0.0, "cost": {"coins": 60, "wood": 20}, "time": 5, "deco": 2, "desc": "Hier ruhen sich die Bewohner aus."},
	"gartenzaun": {"name": "Gartenzaun", "cat": "deco", "size": [1, 1], "unlock": 1, "max": [12, 16, 20, 24, 28, 32, 36, 40, 44, 48], "hp": 0.0, "cost": {"coins": 15, "wood": 10}, "time": 5, "deco": 1, "desc": "Ein weißer Lattenzaun. Gegner laufen einfach durch."},
	"platte": {"name": "Fundament-Platte", "cat": "deco", "size": [1, 1], "unlock": 1, "max": [12, 16, 20, 24, 28, 32, 36, 40, 44, 48], "hp": 0.0, "cost": {"coins": 10, "stone": 10}, "time": 5, "deco": 1, "desc": "Steinplatten für Wege und Plätze."},
	"holzstapel": {"name": "Holzstapel", "cat": "deco", "size": [1, 1], "unlock": 1, "max": [3, 4, 5, 6, 7, 8, 9, 10, 11, 12], "hp": 0.0, "cost": {"coins": 30, "wood": 40}, "time": 5, "deco": 1, "desc": "Ordentlich gestapeltes Brennholz."},
	"heu": {"name": "Heuballen", "cat": "deco", "size": [1, 1], "unlock": 1, "max": [3, 4, 5, 6, 7, 8, 9, 10, 11, 12], "hp": 0.0, "cost": {"coins": 25}, "time": 5, "deco": 1, "desc": "Ein runder Heuballen mit Mistgabel."},
	"waesche": {"name": "Wäscheleine", "cat": "deco", "size": [2, 1], "unlock": 2, "max": [0, 2, 2, 3, 3, 4, 4, 5, 5, 6], "hp": 0.0, "cost": {"coins": 50, "wood": 20}, "time": 5, "deco": 2, "desc": "Frische Wäsche flattert im Wind."},
	"beet": {"name": "Gemüsebeet", "cat": "deco", "size": [2, 1], "unlock": 2, "max": [0, 2, 3, 4, 5, 6, 7, 8, 9, 10], "hp": 0.0, "cost": {"coins": 80, "wood": 30}, "time": 10, "deco": 3, "desc": "Kohl, Möhren und Kürbisse für die Küche."},
	"kuebel": {"name": "Blumenkübel", "cat": "deco", "size": [1, 1], "unlock": 2, "max": [0, 4, 6, 8, 10, 12, 14, 16, 18, 20], "hp": 0.0, "cost": {"coins": 40, "stone": 10}, "time": 5, "deco": 2, "desc": "Ein Steinkübel voller Blumen."},
	"vogelhaus": {"name": "Vogelhaus", "cat": "deco", "size": [1, 1], "unlock": 3, "max": [0, 0, 2, 3, 3, 4, 4, 5, 5, 6], "hp": 0.0, "cost": {"coins": 70, "wood": 25}, "time": 10, "deco": 2, "desc": "Lockt Vögel in die Basis."},
	"picknick": {"name": "Picknicktisch", "cat": "deco", "size": [2, 2], "unlock": 3, "max": [0, 0, 1, 2, 2, 3, 3, 4, 4, 5], "hp": 0.0, "cost": {"coins": 120, "wood": 60}, "time": 20, "deco": 4, "desc": "Tisch mit Bänken und Sonnenschirm."},
	"windrad": {"name": "Windrad", "cat": "deco", "size": [1, 1], "unlock": 4, "max": [0, 0, 0, 1, 2, 2, 3, 3, 4, 4], "hp": 0.0, "cost": {"coins": 150, "wood": 50, "metal": 20}, "time": 30, "deco": 4, "desc": "Ein buntes Windrad, das sich im Wind dreht."},
	"brunnen": {"name": "Brunnen", "cat": "deco", "size": [2, 2], "unlock": 3, "max": [0, 0, 1, 1, 1, 2, 2, 2, 3, 3], "hp": 0.0, "cost": {"coins": 400, "stone": 150}, "time": 60, "deco": 8, "desc": "Ein plätschernder Steinbrunnen – Mittelpunkt jedes Dorfes."},
	# ---- Boss-Trophäen (6.5): je Boss eine, nach dem ersten Sieg baubar (boss = Schlüssel der Gegnerart)
	"trophy_bert": {"name": "Trophäe: Dicker Bert", "cat": "deco", "size": [2, 2], "unlock": 1, "max": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1], "hp": 0.0, "cost": {"coins": 100}, "time": 10, "deco": 10, "trophy": "schleim_boss", "desc": "Die Krone von Dicker Bert auf einem Sockel."},
	"trophy_moos": {"name": "Trophäe: Mooskönigin", "cat": "deco", "size": [2, 2], "unlock": 1, "max": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1], "hp": 0.0, "cost": {"coins": 100}, "time": 10, "deco": 10, "trophy": "boss_wald", "desc": "Der Pilzhut der Mooskönigin unter einer Glasglocke."},
	"trophy_rost": {"name": "Trophäe: Rostbrocken", "cat": "deco", "size": [2, 2], "unlock": 1, "max": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1], "hp": 0.0, "cost": {"coins": 100}, "time": 10, "deco": 10, "trophy": "boss_wueste", "desc": "Die Abrissbirne des Rostbrocken."},
	"trophy_glibber": {"name": "Trophäe: Kapitän Glibber", "cat": "deco", "size": [2, 2], "unlock": 1, "max": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1], "hp": 0.0, "cost": {"coins": 100}, "time": 10, "deco": 10, "trophy": "boss_untote", "desc": "Steuerrad und Dreispitz von Kapitän Glibber."},
	"trophy_schlund": {"name": "Trophäe: Der Schlund", "cat": "deco", "size": [2, 2], "unlock": 1, "max": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1], "hp": 0.0, "cost": {"coins": 100}, "time": 10, "deco": 10, "trophy": "boss_mutanten", "desc": "Ein Zahn und ein Ventilrad aus dem Schlund."},
	"trophy_frost": {"name": "Trophäe: Frostbrocken", "cat": "deco", "size": [2, 2], "unlock": 1, "max": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1], "hp": 0.0, "cost": {"coins": 100}, "time": 10, "deco": 10, "trophy": "boss_eis", "desc": "Die Kristallkrone des Frostbrocken – sie schmilzt nie."},
	"trophy_koenig": {"name": "Trophäe: Schleimkönig", "cat": "deco", "size": [2, 2], "unlock": 1, "max": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1], "hp": 0.0, "cost": {"coins": 100}, "time": 10, "deco": 10, "trophy": "boss_daemonen", "desc": "Die glühenden Hörner des Schleimkönigs."},
	"trophy_brodel": {"name": "Trophäe: Magmafürst Brodel", "cat": "deco", "size": [2, 2], "unlock": 1, "max": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1], "hp": 0.0, "cost": {"coins": 100}, "time": 10, "deco": 10, "trophy": "boss_magma", "desc": "Die Obsidiankrone des Magmafürsten – sie glüht noch."},
	"trophy_bolzen": {"name": "Trophäe: Bürgermeister Bolzen", "cat": "deco", "size": [2, 2], "unlock": 1, "max": [1, 1, 1, 1, 1, 1, 1, 1, 1, 1], "hp": 0.0, "cost": {"coins": 100}, "time": 10, "deco": 10, "trophy": "boss_maschinen", "desc": "Blech-Zylinder und Amtskette des Bürgermeisters – der Akku summt noch leise."},
	# Wildwuchs: wächst von selbst nach und wird für Juwelen weggeräumt (nicht im Baumenü)
	"hind_busch": {"name": "Gestrüpp", "cat": "obstacle", "size": [1, 1], "unlock": 1, "max": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "hp": 0.0, "cost": {"wood": 20}, "time": 10, "prop": "p_bush_1", "gems": [1, 2], "desc": "Wildwuchs. Wegräumen bringt Juwelen."},
	"hind_stumpf": {"name": "Baumstumpf", "cat": "obstacle", "size": [1, 1], "unlock": 1, "max": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "hp": 0.0, "cost": {"wood": 40}, "time": 30, "prop": "p_stump_1", "gems": [1, 3], "desc": "Ein alter Stumpf. Wegräumen bringt Juwelen."},
	"hind_stein": {"name": "Findling", "cat": "obstacle", "size": [1, 1], "unlock": 1, "max": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "hp": 0.0, "cost": {"stone": 40}, "time": 60, "prop": "p_rock_1", "gems": [2, 3], "desc": "Ein großer Stein. Wegräumen bringt Juwelen."},
}
## Deko-Punkte der älteren Schmuck-Gebäude (die neuen tragen "deco" im Eintrag) und Bonus: je Punkt +0,2 % Produktion, höchstens +10 %.
const DECO_POINTS_OLD := {"laterne": 1, "flagge": 1, "blumen": 2, "statue": 6}
const DECO_BONUS_PER := 0.002
const DECO_BONUS_MAX := 0.1
## Fallen (Paket G2): Stellwerte
const TRAP := {"teer": {"r": 2.0, "slow": 0.3, "burn_t": 6.0, "burn_dps": 18.0},
	"feder": {"r": 1.2, "cd": 3.0, "push": 9.0, "dmg": 20.0},
	"koeder": {"r": 14.0, "t": 8.0, "uses": 3, "near": 1.6},
	"zaun": {"r": 1.8, "cd": 1.5, "dmg": 22.0, "stun": 0.7, "uses": 40},
	"eisfalle": {"r": 2.5, "cd": 8.0, "stun": 2.5, "dmg": 12.0}}
const BUILD_CATS := [["def", "Verteidigung"], ["wall", "Mauern"], ["trap", "Fallen"], ["prod", "Produktion"], ["special", "Besonderes"], ["deco", "Schmuck"]]
const DRONES_BY_BUNKER := [2, 2, 2, 3, 3, 3, 4, 4, 5, 5]
const WALL_TIERS := [{"name": "Holzzaun", "hp": 1.0}, {"name": "Steinmauer", "hp": 2.6}, {"name": "Metallmauer", "hp": 5.5}]
const PROD_STORE_HOURS := 8.0
const BUNKER_UNLOCK_TEXT := ["MG-Turm, Mauer, Sägewerk, Lager, Quartier", "Kanone, Steinbruch, Werkstatt, Stachelfalle", "Garage, Funkturm, Wachturm",
	"Flammenturm, Schrottpresse, Steinmauer, 3. Drohne", "Mörser, Raffinerie, Clanhalle, Klebefalle", "Tesla-Spule, Generator, Sprengmine",
	"Raketenturm, Metallmauer, 4. Drohne", "Schildgenerator, Labor", "Eiskanone, Luftabwehr, 5. Drohne", "Goldener Bunker"]

static func bunker_cost(next_level: int) -> Dictionary:
	var c := 400.0 * pow(2.15, next_level - 2)
	var out := {"coins": int(round(c / 10.0) * 10)}
	# Paket Q (Wirtschaftssimulation): ab Stufe 8 wachsen Holz und Stein langsamer – vorher passten die Kosten für
	# Stufe 10 (91 000 Holz) in kein noch so großes Lager (höchstens etwa 50 000), Stufe 10 war unerreichbar.
	var late := pow(BUNKER_LATE_RES, maxi(0, next_level - 7))
	out["wood"] = int(round(c * 0.5 * late / 10.0) * 10)
	if next_level >= 3:
		out["stone"] = int(round(c * 0.4 * late / 10.0) * 10)
	if next_level >= 6:
		out["metal"] = int(round(c * 0.12 / 10.0) * 10)
	return out

const BUNKER_LATE_RES := 0.7                       # Paket Q: Faktor je Stufe über 7 für Holz/Stein des Bunkers

static func bunker_hp(level: int) -> float:
	return 500.0 * pow(1.55, level - 1)

# ---------------------------------------------------------------- Türme (Kampfwerte, Reichweite in Metern)
## target: nearest | strongest | densest | air     mode: hitscan | pierce | cannon | cone | mortar | chain | rocket | ice
const TOWER_DMG_GROWTH := 1.13
const TOWERS := {
	"mg": {"damage": 6.0, "rpm": 300.0, "range": 14.0, "target": "nearest", "mode": "hitscan", "sound": "t_mg", "element": "kugel"},
	"watch": {"damage": 55.0, "rpm": 34.0, "range": 26.0, "target": "strongest", "mode": "pierce", "pierce": 2, "sound": "t_watch", "element": "kugel"},
	"cannon": {"damage": 38.0, "rpm": 32.0, "range": 16.0, "target": "densest", "mode": "cannon", "splash": 2.4, "sound": "t_cannon", "element": "explosion"},
	"flame": {"damage": 5.0, "rpm": 600.0, "range": 7.5, "target": "nearest", "mode": "cone", "cone": 45.0, "burn": 3.0, "sound": "flame_loop", "element": "feuer"},
	"mortar": {"damage": 70.0, "rpm": 14.0, "range": 34.0, "min_range": 9.0, "target": "densest", "mode": "mortar", "splash": 4.0, "sound": "t_mortar", "element": "explosion"},
	"tesla": {"damage": 24.0, "rpm": 60.0, "range": 11.0, "target": "nearest", "mode": "chain", "chain": 6, "slow": 1.0, "sound": "t_tesla", "element": "blitz"},
	"rocket": {"damage": 150.0, "rpm": 12.0, "range": 28.0, "target": "strongest", "mode": "rocket", "splash": 4.0, "sound": "t_rocket", "element": "explosion"},
	"ice": {"damage": 12.0, "rpm": 10.0, "range": 18.0, "target": "densest", "mode": "ice", "splash": 4.5, "stun": 2.0, "sound": "t_ice", "element": "eis"},
	"aa": {"damage": 34.0, "rpm": 150.0, "range": 24.0, "target": "air", "mode": "hitscan", "sound": "t_aa", "element": "kugel"},
	"mini": {"damage": 9.0, "rpm": 120.0, "range": 11.0, "target": "nearest", "mode": "chain", "chain": 2, "slow": 0.5, "sound": "t_mini", "element": "blitz"},
}

# ---------------------------------------------------------------- Gegner
## Die neun Schleimlinge behalten ihre Nummern (0–8); die 36 Arten der sechs neuen Familien folgen (9–44), danach die Bosse.
## Leben und Tempo sind Grundwerte VOR dem Gebietsfaktor (AREA_HP); den wendet der Aufrufer an (hp_mult).
##   key      Schlüssel, zugleich Dateiname: models/e_<key>.glb (+ _vat.png + .json), icons/e_<key>.png
##   family   Familie (FAMILIES)            role   mass | fast | tank | ranged | air | special | boss | object
##   hp, speed (m/s), dmg (je Treffer), interval (s zwischen Treffern), armor (fester Abzug je Treffer), coins, radius (m)
##   scale    Größe gegenüber einem Schleimling (für Effekte und für das vorläufige Ersatzmodell)
##   max      höchstens so viele gleichzeitig gezeichnet
##   ai       Verhaltens-Bausteine (src/enemy_ai.gd); weitere Felder sind deren Stellwerte:
##     range (Fernangriff, m) · splash (Radius des Einschlags) · shots (Fächer) · bounce (prallt weiter) · zone/zone_t (Fläche am Einschlag)
##     fly (schwebt, überfliegt Mauern) · swarm [von, bis] (kommt als Schwarm) · hunt (jagt den Helden auf 16 m)
##   anims    Namen besonderer Clips, die die Bausteine abspielen (falls das Modell sie hat)
##   sound    Vorsilbe der Laute: <sound>_spawn / _attack / _hit / _death / _special
const E_SLIME := 0
const E_RUNNER := 1
const E_BARREL := 2
const E_BRUTE := 3
const E_SPITTER := 4
const E_HELM := 5
const E_FLYER := 6
const E_SHAMAN := 7
const E_BOSS := 8
const E_FIRST_NEW := 9
const AREA_HP := [1.0, 1.6, 2.5, 4.0, 6.5, 10.0, 16.0]      # Gebietsfaktor für Leben (Gebiet 1–7)
const ROLES := ["mass", "fast", "tank", "ranged", "air", "special"]
const ROLE_NAME := {"mass": "Masse", "fast": "Flitzer", "tank": "Brocken", "ranged": "Fernkämpfer", "air": "Flieger", "special": "Sonderling", "boss": "Boss", "object": "Objekt",
	"healer": "Heiler", "shield": "Schildträger", "digger": "Tunnelgräber", "jammer": "Turmstörer", "thief": "Dieb", "brood": "Brutmutter", "miniboss": "Miniboss"}
## Gewicht je Rolle, wenn eine Gruppe ohne Vorgabe gewürfelt wird (Minibosse nie zufällig)
const ROLE_WEIGHT := {"mass": 1.0, "fast": 0.22, "tank": 0.05, "ranged": 0.12, "air": 0.1, "special": 0.06,
	"healer": 0.04, "shield": 0.07, "digger": 0.04, "jammer": 0.04, "thief": 0.04, "brood": 0.025, "miniboss": 0.0}
## Rollen aus Paket G2 (6.3): verändern das Verhalten des Spielers; je Familie drei davon plus ein Miniboss
const ROLES_EXTRA := ["healer", "shield", "digger", "jammer", "thief", "brood"]
## Ersatzmodell (Schleimling dieser Rolle), solange models/e_<key>.glb fehlt, und Farbton der Familie dafür
const ROLE_FALLBACK := {"mass": 0, "fast": 1, "tank": 3, "ranged": 4, "air": 6, "special": 7, "boss": 8, "object": 7,
	"healer": 7, "shield": 5, "digger": 0, "jammer": 4, "thief": 1, "brood": 3, "miniboss": 3}
const FAMILY_TINT := {"schleim": Color(1, 1, 1), "wald": Color(0.55, 0.8, 0.5), "wueste": Color(1.35, 0.85, 0.5), "untote": Color(0.6, 0.95, 1.1),
	"mutanten": Color(0.85, 1.25, 0.35), "eis": Color(0.75, 1.1, 1.7), "daemonen": Color(1.7, 0.42, 0.38), "magma": Color(1.6, 0.7, 0.3),
	"maschinen": Color(1.35, 1.15, 0.55)}
const ENEMIES := [
	# ---- Grüntal: Schleimlinge (Grundlage jeder Flut)
	{"key": "schleim_schleimling", "family": "schleim", "role": "mass", "name": "Schleimling", "hp": 10.0, "speed": 2.3, "dmg": 4.0, "interval": 1.0, "armor": 0.0, "coins": 1, "radius": 0.42, "scale": 1.0, "max": 420, "ai": [], "sound": "e_schleim",
		"look": "grün, rund, frech", "text": "Hüpft geradewegs auf den Bunker zu. Allein harmlos, in Massen gefährlich."},
	{"key": "schleim_flitzer", "family": "schleim", "role": "fast", "name": "Flitzer", "hp": 8.0, "speed": 4.6, "dmg": 3.0, "interval": 0.8, "armor": 0.0, "coins": 1, "radius": 0.36, "scale": 0.8, "max": 120, "hunt": true, "ai": [], "sound": "e_schleim",
		"look": "gelb, spitz, schnell", "text": "Jagt den Helden, sobald er ihn sieht."},
	{"key": "schleim_fass", "family": "schleim", "role": "special", "name": "Fass-Schleim", "hp": 20.0, "speed": 3.0, "dmg": 60.0, "interval": 1.0, "armor": 0.0, "coins": 2, "radius": 0.45, "scale": 1.05, "max": 60, "burst": 2.8, "ai": [], "sound": "e_schleim",
		"look": "orange mit rotem Sprengfass", "text": "Sprengt sich an Mauern in die Luft."},
	{"key": "schleim_brocken", "family": "schleim", "role": "tank", "name": "Brocken", "hp": 160.0, "speed": 1.6, "dmg": 26.0, "interval": 1.2, "armor": 3.0, "coins": 6, "radius": 0.95, "scale": 2.3, "max": 40, "ai": [], "sound": "e_schleim",
		"look": "dunkelgrün, Steine auf dem Rücken", "text": "Langsam, zäh und stark gegen Mauern."},
	{"key": "schleim_spucker", "family": "schleim", "role": "ranged", "name": "Spucker", "hp": 30.0, "speed": 2.0, "dmg": 12.0, "interval": 2.0, "armor": 0.0, "coins": 3, "radius": 0.45, "scale": 1.1, "max": 40, "spit": 11.0, "ai": [], "sound": "e_schleim",
		"look": "türkis mit Rüssel", "text": "Spuckt aus 11 Metern auf den Helden."},
	{"key": "schleim_helm", "family": "schleim", "role": "mass", "name": "Helm-Schleim", "hp": 16.0, "speed": 2.2, "dmg": 5.0, "interval": 1.0, "armor": 0.0, "coins": 2, "radius": 0.44, "scale": 1.05, "max": 120, "shield": 2, "ai": [], "sound": "e_schleim",
		"look": "grün mit Stahlhelm", "text": "Der Helm fängt die ersten zwei Treffer ab."},
	{"key": "schleim_flatter", "family": "schleim", "role": "air", "name": "Flatterschleim", "hp": 12.0, "speed": 3.2, "dmg": 4.0, "interval": 1.0, "armor": 0.0, "coins": 2, "radius": 0.4, "scale": 0.9, "max": 80, "fly": true, "ai": [], "sound": "e_schleim",
		"look": "hellgrün mit Flügelchen", "text": "Fliegt über Mauern hinweg."},
	{"key": "schleim_schamane", "family": "schleim", "role": "special", "name": "Schamane", "hp": 45.0, "speed": 2.0, "dmg": 4.0, "interval": 1.2, "armor": 0.0, "coins": 5, "radius": 0.48, "scale": 1.15, "max": 20, "heal": 6.0, "ai": [], "sound": "e_schleim",
		"look": "lila mit Federschmuck und Stab", "text": "Heilt alle Schleimlinge in seiner Nähe."},
	{"key": "schleim_boss", "family": "schleim", "role": "boss", "name": "Dicker Bert", "hp": 2200.0, "speed": 1.3, "dmg": 70.0, "interval": 1.6, "armor": 2.0, "coins": 50, "radius": 2.0, "scale": 4.6, "max": 4, "boss": true, "ai": [], "sound": "e_schleim",
		"look": "Riesenschleim mit Krone", "text": "Der Boss der Schleimlinge."},
	# ---- Kiefernforst: Waldgeister und Pilzvolk
	{"key": "wald_pilzling", "family": "wald", "role": "mass", "name": "Pilzling", "hp": 12.0, "speed": 2.2, "dmg": 4.0, "interval": 1.0, "armor": 0.0, "coins": 1, "radius": 0.4, "scale": 0.9, "max": 300,
		"ai": ["death_cloud"], "cloud": "spore", "cloud_r": 2.0, "cloud_t": 3.0, "sound": "e_wald",
		"look": "kniehoher Pilz mit Beinchen und rotem Hut", "text": "Platzt beim Tod in eine Sporenwolke (2 m, 3 s), die den Helden verlangsamt."},
	{"key": "wald_dornenwolf", "family": "wald", "role": "fast", "name": "Dornenwolf", "hp": 14.0, "speed": 5.0, "dmg": 6.0, "interval": 0.9, "armor": 0.0, "coins": 1, "radius": 0.42, "scale": 1.0, "max": 100,
		"ai": ["pack", "pounce"], "hunt": true, "swarm": [2, 4], "pounce": 5.0, "sound": "e_wald", "anims": {"pounce": "pounce"},
		"look": "Wolf aus Ranken und Dornen, glühend gelbe Augen", "text": "Umkreist den Helden im Rudel und springt ihn von der Seite an (5 m)."},
	{"key": "wald_baumhueter", "family": "wald", "role": "tank", "name": "Baumhüter", "hp": 220.0, "speed": 1.3, "dmg": 24.0, "interval": 1.4, "armor": 3.0, "coins": 7, "radius": 1.0, "scale": 2.4, "max": 30,
		"ai": ["siege", "regen"], "siege": 2.0, "regen": 0.05, "regen_wait": 4.0, "sound": "e_wald", "anims": {"regen": "root"},
		"look": "wandelnder Baumstamm mit Astarmen und Vogelnest", "text": "Doppelter Schaden an Mauern. Wurzelt sich fest und heilt, wenn er 4 s nicht getroffen wird."},
	{"key": "wald_zapfenwerfer", "family": "wald", "role": "ranged", "name": "Zapfenwerfer", "hp": 26.0, "speed": 2.4, "dmg": 9.0, "interval": 2.0, "armor": 0.0, "coins": 3, "radius": 0.42, "scale": 1.0, "max": 60,
		"ai": ["ranged_line"], "range": 12.0, "bounce": 1, "sound": "e_wald",
		"look": "Kobold mit Tannenzapfen-Rucksack und Schleuder", "text": "Schießt aus 12 m; die Zapfen prallen einmal weiter."},
	{"key": "wald_irrlicht", "family": "wald", "role": "air", "name": "Irrlicht", "hp": 14.0, "speed": 3.0, "dmg": 4.0, "interval": 1.0, "armor": 0.0, "coins": 2, "radius": 0.38, "scale": 0.85, "max": 60,
		"ai": ["blink", "heal"], "fly": true, "blink": 6.0, "blink_cd": 5.0, "heal": 2.0, "sound": "e_wald", "anims": {"blink": "blink"},
		"look": "schwebende blaue Flamme mit Gesicht", "text": "Springt alle 5 s 6 m weit und heilt Verbündete in der Nähe leicht."},
	{"key": "wald_wurzelkriecher", "family": "wald", "role": "special", "name": "Wurzelkriecher", "hp": 40.0, "speed": 2.6, "dmg": 8.0, "interval": 1.0, "armor": 0.0, "coins": 4, "radius": 0.5, "scale": 1.1, "max": 40,
		"ai": ["burrow"], "burrow": "walls", "sound": "e_wald", "anims": {"dig": "dig", "under": "under", "rise": "rise"},
		"look": "Knäuel aus Wurzeln, nur der Buckel ist sichtbar", "text": "Gräbt sich unter Mauern hindurch; unter der Erde nur durch Explosionen verwundbar."},
	# ---- Staubebene: Wüstenmonster und Schrottvieh
	{"key": "wueste_schrottkaefer", "family": "wueste", "role": "mass", "name": "Schrottkäfer", "hp": 16.0, "speed": 2.2, "dmg": 5.0, "interval": 1.0, "armor": 0.0, "coins": 1, "radius": 0.44, "scale": 1.0, "max": 300,
		"ai": ["front_armor"], "front_armor": 0.7, "sound": "e_wueste",
		"look": "Käfer mit Autotür als Panzer, Auspuff-Fühler", "text": "Vorn gepanzert (−70 % Schaden von vorn), hinten weich."},
	{"key": "wueste_staubteufel", "family": "wueste", "role": "fast", "name": "Staubteufel", "hp": 10.0, "speed": 5.2, "dmg": 2.0, "interval": 0.8, "armor": 0.0, "coins": 1, "radius": 0.4, "scale": 0.9, "max": 100,
		"ai": ["push", "steal"], "hunt": true, "push": 3.0, "steal": "drag", "sound": "e_wueste",
		"look": "kleiner Wirbelwind mit Schrottteilen und zwei Augen", "text": "Schiebt den Helden weg und reißt Münzen vom Boden mit."},
	{"key": "wueste_rostbulle", "family": "wueste", "role": "tank", "name": "Rostbulle", "hp": 240.0, "speed": 1.5, "dmg": 28.0, "interval": 1.4, "armor": 4.0, "coins": 7, "radius": 1.0, "scale": 2.3, "max": 30,
		"ai": ["charge"], "charge": 8.0, "charge_stun": 2.0, "sound": "e_wueste", "anims": {"charge_start": "windup", "charge": "charge", "dazed": "dazed"},
		"look": "Stier aus Blechplatten mit Stoßstangen-Hörnern", "text": "Nimmt Anlauf und rammt 8 m geradeaus; prallt er gegen eine Mauer, ist er 2 s benommen."},
	{"key": "wueste_kaktusschuetze", "family": "wueste", "role": "ranged", "name": "Kaktusschütze", "hp": 28.0, "speed": 2.0, "dmg": 7.0, "interval": 2.2, "armor": 0.0, "coins": 3, "radius": 0.44, "scale": 1.1, "max": 60,
		"ai": ["ranged_line"], "range": 10.0, "shots": 3, "sound": "e_wueste",
		"look": "laufender Kaktus mit Sombrero-Blüte", "text": "Schießt einen Fächer aus drei Stacheln (10 m)."},
	{"key": "wueste_geier", "family": "wueste", "role": "air", "name": "Geier", "hp": 14.0, "speed": 3.6, "dmg": 4.0, "interval": 1.0, "armor": 0.0, "coins": 2, "radius": 0.42, "scale": 1.0, "max": 60,
		"ai": ["steal", "flee"], "fly": true, "steal": "carry", "sound": "e_wueste",
		"look": "zerzauster Geier mit Fliegerbrille", "text": "Stiehlt liegende Münzen und fliegt davon; abschießen gibt alles zurück."},
	{"key": "wueste_sandwurm", "family": "wueste", "role": "special", "name": "Sandwurm", "hp": 70.0, "speed": 3.0, "dmg": 18.0, "interval": 1.2, "armor": 0.0, "coins": 5, "radius": 0.6, "scale": 1.4, "max": 30,
		"ai": ["burrow"], "burrow": "ambush", "hunt": true, "sound": "e_wueste", "anims": {"dig": "dig", "under": "under", "rise": "rise"},
		"look": "Wurm aus Reifen-Segmenten, Maul mit Zahnrädern", "text": "Zieht eine Sandspur unter der Erde und bricht unter dem Helden hervor (Warnkreis 1 s vorher)."},
	# ---- Schrottküste: Untote Seeleute
	{"key": "untote_matrose", "family": "untote", "role": "mass", "name": "Matrosen-Zombie", "hp": 18.0, "speed": 1.7, "dmg": 5.0, "interval": 1.1, "armor": 0.0, "coins": 1, "radius": 0.45, "scale": 1.6, "max": 300,
		"ai": ["revive"], "revive": 0.4, "revive_wait": 3.0, "sound": "e_untote", "anims": {"revive": "revive"},
		"look": "aufgedunsener Matrose mit Ringelhemd, ein Arm fehlt, schlurft", "text": "Steht einmal wieder auf (nach 3 s mit 40 % Leben), wenn er nicht durch Feuer oder Explosion stirbt."},
	{"key": "untote_deckratte", "family": "untote", "role": "fast", "name": "Deckratte", "hp": 5.0, "speed": 5.4, "dmg": 2.0, "interval": 0.6, "armor": 0.0, "coins": 1, "radius": 0.3, "scale": 0.7, "max": 160,
		"ai": ["tower_hunter"], "swarm": [6, 10], "tower_range": 14.0, "tower_dmg": 2.0, "sound": "e_untote",
		"look": "Skelett-Ratte mit Piratentuch", "text": "Kommt in Schwärmen von 6–10 und knabbert bevorzugt an Türmen."},
	{"key": "untote_taucher", "family": "untote", "role": "tank", "name": "Ertrunkener Taucher", "hp": 260.0, "speed": 1.2, "dmg": 30.0, "interval": 1.5, "armor": 4.0, "coins": 8, "radius": 1.0, "scale": 2.5, "max": 30,
		"ai": ["pull"], "pull": 9.0, "pull_cd": 7.0, "sound": "e_untote", "anims": {"pull": "throw"},
		"look": "Zombie im alten Tauchanzug mit Anker an Kette", "text": "Wirft den Anker (9 m) und zieht den Helden zu sich."},
	{"key": "untote_kanonier", "family": "untote", "role": "ranged", "name": "Kanonier-Skelett", "hp": 30.0, "speed": 1.9, "dmg": 14.0, "interval": 3.0, "armor": 0.0, "coins": 3, "radius": 0.45, "scale": 1.7, "max": 60,
		"ai": ["ranged_arc"], "range": 16.0, "splash": 2.2, "siege_shot": true, "sound": "e_untote", "anims": {"aim": "kneel"},
		"look": "Skelett mit Dreispitz, trägt eine kleine Kanone auf der Schulter", "text": "Schießt aus 16 m eine Kugel im Bogen mit Flächenschaden; kniet zum Schuss."},
	{"key": "untote_qualle", "family": "untote", "role": "air", "name": "Geisterqualle", "hp": 16.0, "speed": 2.8, "dmg": 6.0, "interval": 1.2, "armor": 0.0, "coins": 2, "radius": 0.45, "scale": 1.3, "max": 60,
		"ai": ["stun_tower"], "fly": true, "zap": 4.0, "zap_cd": 5.0, "zap_stun": 2.0, "sound": "e_untote", "anims": {"zap": "zap"},
		"look": "durchscheinende Qualle mit Kapitänsmütze", "text": "Elektrischer Schlag im Umkreis; legt Türme 2 s lahm."},
	{"key": "untote_krabbe", "family": "untote", "role": "special", "name": "Krabbenpanzer", "hp": 60.0, "speed": 3.0, "dmg": 9.0, "interval": 1.0, "armor": 0.0, "coins": 14, "radius": 0.6, "scale": 1.0, "max": 30,
		"ai": ["zigzag", "shell"], "shell": 1.5, "shell_cd": 4.0, "sound": "e_untote", "anims": {"shell": "hide"},
		"look": "große Krabbe mit Schatzkiste als Panzer", "text": "Läuft seitwärts im Zickzack, zieht sich bei Treffern 1,5 s in die Kiste zurück (unverwundbar); lässt viel Gold fallen."},
	# ---- Sumpfwerk: Mutanten und kaputte Maschinen
	{"key": "mutanten_giftkroete", "family": "mutanten", "role": "mass", "name": "Giftkröte", "hp": 16.0, "speed": 2.6, "dmg": 5.0, "interval": 1.0, "armor": 0.0, "coins": 1, "radius": 0.45, "scale": 1.0, "max": 300,
		"ai": ["leap", "death_cloud"], "leap": 3.0, "cloud": "poison", "cloud_r": 1.8, "cloud_t": 4.0, "sound": "e_mutanten",
		"look": "fette Kröte mit drei Augen und leuchtenden Warzen", "text": "Springt in Sätzen (3 m); hinterlässt beim Tod eine Giftpfütze (4 s)."},
	{"key": "mutanten_egelschwarm", "family": "mutanten", "role": "fast", "name": "Blutegel-Schwarm", "hp": 24.0, "speed": 4.4, "dmg": 2.0, "interval": 0.7, "armor": 0.0, "coins": 2, "radius": 0.45, "scale": 0.9, "max": 80,
		"ai": ["segments", "latch"], "hunt": true, "segments": 8, "latch": "slow", "sound": "e_mutanten",
		"look": "8 fingerlange Egel, die als Teppich kriechen", "text": "Ein Gegner aus 8 Teilen (je 3 Leben); heftet sich an und verlangsamt, bis er abgeschüttelt ist (Ausweichrolle)."},
	{"key": "mutanten_schlammgolem", "family": "mutanten", "role": "tank", "name": "Schlammgolem", "hp": 280.0, "speed": 1.2, "dmg": 30.0, "interval": 1.5, "armor": 3.0, "coins": 6, "radius": 1.05, "scale": 2.4, "max": 30,
		"ai": ["split"], "split": 2, "split_hp": 0.3, "sound": "e_mutanten",
		"look": "Berg aus Schlamm mit Rohrstücken und Ventilrad im Bauch", "text": "Teilt sich beim Tod in zwei kleine Golems (je 30 % Leben)."},
	{"key": "mutanten_rohrspucker", "family": "mutanten", "role": "ranged", "name": "Rohrspucker", "hp": 32.0, "speed": 2.0, "dmg": 10.0, "interval": 2.6, "armor": 0.0, "coins": 3, "radius": 0.46, "scale": 1.15, "max": 60,
		"ai": ["ranged_arc"], "range": 14.0, "splash": 2.0, "zone": "acid", "zone_t": 5.0, "siege_shot": true, "sound": "e_mutanten",
		"look": "Mutant, dem ein Rohr aus dem Rücken wächst", "text": "Spuckt Säure in hohem Bogen (14 m), die Mauern 5 s lang zusätzlich schädigt."},
	{"key": "mutanten_werksdrohne", "family": "mutanten", "role": "air", "name": "Werksdrohne", "hp": 18.0, "speed": 3.4, "dmg": 6.0, "interval": 1.6, "armor": 0.0, "coins": 2, "radius": 0.4, "scale": 0.95, "max": 60,
		"ai": ["ranged_line", "strafe"], "fly": true, "range": 8.0, "sound": "e_mutanten",
		"look": "verrostete Flugdrohne mit rotem Auge und Funkenschweif", "text": "Schießt aus der Luft (8 m) und weicht nach jedem Schuss seitlich aus."},
	{"key": "mutanten_seuchenarzt", "family": "mutanten", "role": "special", "name": "Seuchenarzt", "hp": 50.0, "speed": 2.4, "dmg": 5.0, "interval": 1.2, "armor": 0.0, "coins": 5, "radius": 0.46, "scale": 1.3, "max": 20,
		"ai": ["aura_buff", "flee"], "aura": 6.0, "aura_k": 1.3, "flee": 7.0, "sound": "e_mutanten",
		"look": "Gestalt mit Schnabelmaske, Laterne und Kanister", "text": "Macht Gegner im Umkreis von 6 m 30 % schneller und stärker; flieht vor dem Helden."},
	# ---- Frostpass: Eiswesen
	{"key": "eis_frostwichtel", "family": "eis", "role": "mass", "name": "Frostwichtel", "hp": 14.0, "speed": 2.6, "dmg": 3.0, "interval": 1.2, "armor": 0.0, "coins": 1, "radius": 0.4, "scale": 0.9, "max": 300,
		"ai": ["ranged_line", "chill"], "range": 6.0, "chill": 0.1, "chill_max": 0.5, "sound": "e_eis",
		"look": "kleiner Kobold mit Eiszapfen-Mütze, wirft Schneebälle", "text": "Jeder Treffer verlangsamt den Helden um 10 % (bis 50 %)."},
	{"key": "eis_eiswolf", "family": "eis", "role": "fast", "name": "Eiswolf", "hp": 16.0, "speed": 5.2, "dmg": 6.0, "interval": 0.9, "armor": 0.0, "coins": 1, "radius": 0.42, "scale": 1.0, "max": 100,
		"ai": ["pack", "pounce", "howl", "ice_slide"], "hunt": true, "swarm": [2, 4], "pounce": 4.0, "howl": 1.2, "howl_cd": 9.0, "sound": "e_eis", "anims": {"howl": "howl", "pounce": "pounce"},
		"look": "weißer Wolf mit Kristallrücken, Atemwolke", "text": "Schlittert über Eisflächen doppelt so schnell; der Rudelführer heult (+20 % Tempo für alle)."},
	{"key": "eis_yeti", "family": "eis", "role": "tank", "name": "Yeti", "hp": 300.0, "speed": 1.4, "dmg": 30.0, "interval": 1.5, "armor": 3.0, "coins": 8, "radius": 1.05, "scale": 2.5, "max": 30,
		"ai": ["ranged_arc", "knockback"], "range": 10.0, "min_range": 4.0, "splash": 2.4, "siege_shot": true, "knockback": 6.0, "sound": "e_eis", "anims": {"shot": "throw"},
		"look": "zotteliger Riese mit Eisbrocken in der Faust", "text": "Wirft Felsbrocken über Mauern (10 m); sein Nahschlag schleudert den Helden weg."},
	{"key": "eis_kristallschuetze", "family": "eis", "role": "ranged", "name": "Kristallschütze", "hp": 26.0, "speed": 2.0, "dmg": 9.0, "interval": 1.8, "armor": 0.0, "coins": 3, "radius": 0.42, "scale": 1.3, "max": 60,
		"ai": ["ranged_line", "double_freeze"], "range": 18.0, "freeze": 0.8, "freeze_window": 3.0, "sound": "e_eis",
		"look": "schlanke Eisfigur mit Bogen aus Eis", "text": "Schießt aus 18 m. Treffen zwei Pfeile kurz nacheinander, friert der Held 0,8 s ein."},
	{"key": "eis_eisgeist", "family": "eis", "role": "air", "name": "Eisgeist", "hp": 16.0, "speed": 3.0, "dmg": 4.0, "interval": 1.0, "armor": 0.0, "coins": 2, "radius": 0.42, "scale": 1.0, "max": 60,
		"ai": ["freeze_tower"], "fly": true, "freeze_tower": 4.0, "freeze_cd": 8.0, "sound": "e_eis", "anims": {"freeze": "freeze"},
		"look": "wehender Schleier mit hohlen Augen", "text": "Vereist einen Turm für 4 s (er schießt nicht); bevorzugt den stärksten Turm."},
	{"key": "eis_lawinenroller", "family": "eis", "role": "special", "name": "Lawinenroller", "hp": 45.0, "speed": 3.0, "dmg": 14.0, "interval": 1.0, "armor": 0.0, "coins": 4, "radius": 0.5, "scale": 1.1, "max": 40,
		"ai": ["roll_grow"], "roll_max": 6.0, "roll_grow": 1.2, "splash": 2.5, "sound": "e_eis", "anims": {"roll": "roll"},
		"look": "Schneekugel mit Gesicht, wächst beim Rollen", "text": "Rollt in gerader Linie (3–6 m/s), wird größer und stärker; zerplatzt an Mauern mit Flächenschaden."},
	# ---- Schleimkrater: Dämonen
	{"key": "daemonen_hoellenwichtel", "family": "daemonen", "role": "mass", "name": "Höllenwichtel", "hp": 18.0, "speed": 3.0, "dmg": 5.0, "interval": 1.0, "armor": 0.0, "coins": 1, "radius": 0.4, "scale": 0.95, "max": 300,
		"ai": ["trail_fire", "laugh"], "trail": 1.3, "sound": "e_daemonen",
		"look": "roter Wicht mit Hörnchen, Dreizack und Grinsen", "text": "Hinterlässt brennende Fußspuren; lacht, wenn er trifft."},
	{"key": "daemonen_hund", "family": "daemonen", "role": "fast", "name": "Dämonenhund", "hp": 22.0, "speed": 5.6, "dmg": 4.0, "interval": 0.5, "armor": 0.0, "coins": 2, "radius": 0.45, "scale": 1.1, "max": 80,
		"ai": ["charge", "latch"], "hunt": true, "charge": 7.0, "charge_cd": 5.0, "latch": "bite", "sound": "e_daemonen", "anims": {"charge": "charge"},
		"look": "schwarzer Hund mit Glutadern und zwei Köpfen", "text": "Stürmt los und beißt sich fest (Schaden über Zeit, bis er selbst Schaden nimmt)."},
	{"key": "daemonen_waechter", "family": "daemonen", "role": "tank", "name": "Gehörnter Wächter", "hp": 340.0, "speed": 1.4, "dmg": 34.0, "interval": 1.8, "armor": 4.0, "coins": 9, "radius": 1.1, "scale": 2.7, "max": 30,
		"ai": ["shockwave"], "wave": 5.0, "sound": "e_daemonen",
		"look": "drei Meter großer Dämon mit Stierhörnern und Zweihandhammer", "text": "Der Hammerschlag erzeugt eine Druckwelle (5 m Linie), die Mauern überspringt."},
	{"key": "daemonen_feuerspeier", "family": "daemonen", "role": "ranged", "name": "Feuerspeier", "hp": 36.0, "speed": 1.9, "dmg": 12.0, "interval": 2.8, "armor": 0.0, "coins": 3, "radius": 0.5, "scale": 1.3, "max": 60,
		"ai": ["ranged_arc"], "range": 13.0, "splash": 2.0, "zone": "fire", "zone_t": 4.0, "sound": "e_daemonen", "anims": {"aim": "puff"},
		"look": "dicker Dämon mit Glutbauch, bläht sich vor dem Schuss auf", "text": "Sein Feuerball (13 m) hinterlässt 4 s brennenden Boden."},
	{"key": "daemonen_schattenschwinge", "family": "daemonen", "role": "air", "name": "Schattenschwinge", "hp": 20.0, "speed": 4.0, "dmg": 9.0, "interval": 1.0, "armor": 0.0, "coins": 2, "radius": 0.45, "scale": 1.1, "max": 60,
		"ai": ["dive"], "fly": true, "hunt": true, "dive": 10.0, "dive_cd": 4.0, "high_k": 0.3, "sound": "e_daemonen", "anims": {"dive": "dive"},
		"look": "Fledermausdämon mit zerfetzten Flügeln", "text": "Stößt im Sturzflug auf den Helden herab und steigt wieder auf; nur beim Angriff gut zu treffen."},
	{"key": "daemonen_beschwoerer", "family": "daemonen", "role": "special", "name": "Beschwörer", "hp": 60.0, "speed": 1.8, "dmg": 5.0, "interval": 1.2, "armor": 0.0, "coins": 6, "radius": 0.46, "scale": 1.4, "max": 20,
		"ai": ["summon_portal", "flee"], "portal_cd": 8.0, "portal_n": 3, "portal_key": "daemonen_hoellenwichtel", "flee": 5.0, "sound": "e_daemonen", "anims": {"summon": "summon"},
		"look": "hagerer Dämon in Robe, schwebendes Buch, Kreis aus Runen", "text": "Öffnet alle 8 s ein Portal, aus dem 3 Höllenwichtel kommen; das Portal ist zerstörbar (40 Leben)."},
	# ---- Bosse der sechs neuen Familien (specials: Sonderangriffe im Wechsel)
	{"key": "boss_wald", "family": "wald", "role": "boss", "name": "Mooskönigin", "hp": 2200.0, "speed": 1.2, "dmg": 60.0, "interval": 1.6, "armor": 2.0, "coins": 50, "radius": 2.0, "scale": 4.6, "max": 2, "boss": true,
		"ai": [], "specials": ["summon", "spores"], "summon": "wald_pilzling", "sound": "e_wald",
		"look": "riesige Pilzdame mit Krone", "text": "Lässt Pilzlinge aus dem Boden wachsen und legt Sporenfelder."},
	{"key": "boss_wueste", "family": "wueste", "role": "boss", "name": "Rostbrocken", "hp": 2400.0, "speed": 1.2, "dmg": 75.0, "interval": 1.7, "armor": 3.0, "coins": 50, "radius": 2.0, "scale": 4.6, "max": 2, "boss": true,
		"ai": [], "specials": ["slam", "wreck"], "sound": "e_wueste",
		"look": "Schrottgolem mit Abrissbirne", "text": "Bodenschlag und geworfene Autowracks."},
	{"key": "boss_untote", "family": "untote", "role": "boss", "name": "Kapitän Glibber", "hp": 2300.0, "speed": 1.2, "dmg": 65.0, "interval": 1.6, "armor": 2.0, "coins": 50, "radius": 1.8, "scale": 4.0, "max": 2, "boss": true,
		"ai": [], "specials": ["summon", "broadside"], "summon": "untote_matrose", "sound": "e_untote",
		"look": "Zombie-Kapitän mit Steuerrad-Schild", "text": "Ruft Matrosen aus dem Sand und feuert Breitseiten."},
	{"key": "boss_mutanten", "family": "mutanten", "role": "boss", "name": "Der Schlund", "hp": 2500.0, "speed": 0.9, "dmg": 70.0, "interval": 1.6, "armor": 2.0, "coins": 50, "radius": 2.2, "scale": 4.8, "max": 2, "boss": true,
		"ai": ["pull"], "pull": 14.0, "pull_cd": 8.0, "specials": ["spawn_spit", "slam"], "summon": "mutanten_giftkroete", "sound": "e_mutanten",
		"look": "riesiges Maul im Fabrikbecken mit Fangarmen aus Rohren", "text": "Saugt den Helden an und spuckt Giftkröten."},
	{"key": "boss_eis", "family": "eis", "role": "boss", "name": "Frostbrocken", "hp": 2600.0, "speed": 1.2, "dmg": 75.0, "interval": 1.7, "armor": 3.0, "coins": 50, "radius": 2.0, "scale": 4.6, "max": 2, "boss": true,
		"ai": [], "specials": ["freeze_ground", "summon"], "summon": "eis_lawinenroller", "summon_n": 2, "sound": "e_eis",
		"look": "Eisgolem mit Kristallkrone", "text": "Friert den Boden ein und ruft Lawinenroller."},
	{"key": "boss_daemonen", "family": "daemonen", "role": "boss", "name": "Schleimkönig", "hp": 1600.0, "speed": 1.5, "dmg": 80.0, "interval": 1.5, "armor": 2.0, "coins": 60, "radius": 1.9, "scale": 4.4, "max": 2, "boss": true,
		"ai": [], "fly": false, "specials": ["summon", "spit", "slam"], "summon": "daemonen_hoellenwichtel", "phase_of": "schleim_boss", "sound": "e_daemonen",
		"look": "erst Schleimriese, dann ein Dämon mit Flügeln", "text": "Zwei Phasen: Ist der Schleimriese besiegt, bricht ein Dämon mit Flügeln aus ihm hervor."},
	# ---- Objekte der Bausteine
	{"key": "daemonen_portal", "family": "daemonen", "role": "object", "name": "Höllenportal", "hp": 40.0, "speed": 0.0, "dmg": 0.0, "interval": 1.0, "armor": 0.0, "coins": 0, "radius": 0.8, "scale": 1.6, "max": 12,
		"ai": [], "sound": "e_daemonen", "look": "Kreis aus Runen", "text": "Aus ihm kommen Höllenwichtel, bis es zerstört ist."},
	# ---- Paket G2 (6.3): neue Rollen je Familie – Heiler, Schildträger, Tunnelgräber, Turmstörer, Dieb, Brutmutter – und je ein Miniboss.
	##   healer:  heal_pct (Anteil der Lebensleiste je Puls), heal_r, heal_cd, keep (hält so viel Abstand zum Helden)
	##   shield_front: frontaler Schild blockt alle Treffer von vorn außer Explosionen und Bogenwürfen (shield_k = Anteil, der durchgeht)
	##   tunnel:  gräbt sich an Mauern ein und taucht erst im Inneren der Basis wieder auf (Fallen und Explosionen holen ihn heraus)
	##   jammer:  jam (vine | emp | lava | frost), jam_t (Turm so lange aus), jam_cd, jam_r (Reichweite)
	##   thief:   steal_amt (je Rohstoff), läuft zum Lager, flieht mit der Beute; besiegt gibt er alles zurück
	##   brood:   brood_key ("" = Junge der eigenen Art), brood_n, brood_cd
	##   miniboss: mini_skill (slam | roots | acid | ring | toxic | frost_ring | chain), mini_cd, mini_r – eigene Lebensleiste
	{"key": "schleim_brutschleim", "family": "schleim", "role": "brood", "name": "Brutschleim", "hp": 70.0, "speed": 1.4, "dmg": 6.0, "interval": 1.2, "armor": 0.0, "coins": 6, "radius": 0.8, "scale": 1.8, "max": 16,
		"ai": ["brood"], "brood_key": "schleim_schleimling", "brood_n": 3, "brood_cd": 5.0, "sound": "e_schleim", "anims": {"brood": "brood"}, "counter": "Zuerst töten – sonst wird die Horde immer größer.",
		"look": "dicker, durchsichtiger Schleim, in dem kleine Schleimlinge schwimmen", "text": "Spuckt alle 5 s drei kleine Schleimlinge aus."},
	{"key": "schleim_deckel", "family": "schleim", "role": "shield", "name": "Deckelschild", "hp": 26.0, "speed": 2.0, "dmg": 6.0, "interval": 1.0, "armor": 0.0, "coins": 3, "radius": 0.5, "scale": 1.1, "max": 60,
		"ai": ["shield_front"], "shield_k": 0.0, "sound": "e_schleim", "anims": {"block": "block"}, "counter": "Von der Seite angreifen, Explosionen oder Bogenwürfe.",
		"look": "grüner Schleim mit Mülltonnendeckel als Schild", "text": "Der Deckel fängt alle Treffer von vorn ab."},
	{"key": "schleim_klauschleim", "family": "schleim", "role": "thief", "name": "Klauschleim", "hp": 18.0, "speed": 3.4, "dmg": 2.0, "interval": 1.0, "armor": 0.0, "coins": 4, "radius": 0.42, "scale": 0.95, "max": 30,
		"ai": ["thief"], "steal_amt": 40.0, "sound": "e_schleim", "anims": {"grab": "grab"}, "counter": "Schnelle Türme am Lager aufstellen.",
		"look": "kleiner Schleim mit Ganovenmaske und Beutesack", "text": "Schleicht zum Lager, klaut Rohstoffe und flieht. Besiegt gibt er die Beute zurück."},
	{"key": "wald_druide", "family": "wald", "role": "healer", "name": "Waldgeist-Druide", "hp": 40.0, "speed": 2.0, "dmg": 4.0, "interval": 1.2, "armor": 0.0, "coins": 5, "radius": 0.46, "scale": 1.3, "max": 20,
		"ai": ["healer"], "heal_pct": 0.06, "heal_r": 6.0, "heal_cd": 1.5, "keep": 9.0, "sound": "e_wald", "anims": {"heal": "heal"}, "counter": "Ihn zuerst ins Visier nehmen; Gift verhindert die Heilung.",
		"look": "Moosgestalt mit Hirschgeweih und Laternenstab", "text": "Heilt alle Gegner im Umkreis von 6 m und bleibt dabei auf Abstand."},
	{"key": "wald_spinnenmutter", "family": "wald", "role": "brood", "name": "Moosspinnen-Mutter", "hp": 90.0, "speed": 1.6, "dmg": 8.0, "interval": 1.1, "armor": 1.0, "coins": 7, "radius": 0.85, "scale": 1.8, "max": 16,
		"ai": ["brood"], "brood_key": "", "brood_n": 4, "brood_cd": 6.0, "sound": "e_wald", "anims": {"brood": "brood"}, "counter": "Zuerst töten – die Jungen sind schwach, aber viele.",
		"look": "große Spinne mit Moospelz und Eiersack auf dem Rücken", "text": "Lässt alle 6 s vier junge Spinnen schlüpfen."},
	{"key": "wald_rankenwerfer", "family": "wald", "role": "jammer", "name": "Rankenschleuderer", "hp": 30.0, "speed": 2.2, "dmg": 6.0, "interval": 1.4, "armor": 0.0, "coins": 4, "radius": 0.44, "scale": 1.1, "max": 30,
		"ai": ["jammer"], "jam": "vine", "jam_t": 3.5, "jam_cd": 7.0, "jam_r": 9.0, "sound": "e_wald", "anims": {"jam": "jam"}, "counter": "Schildgenerator halbiert die Störung; schnell töten.",
		"look": "Kobold aus Ästen mit einer Rankenschleuder", "text": "Überwuchert einen Turm mit Ranken – er schießt 3,5 s nicht."},
	{"key": "wueste_maulwurf", "family": "wueste", "role": "digger", "name": "Rostmaulwurf", "hp": 60.0, "speed": 2.6, "dmg": 10.0, "interval": 1.0, "armor": 1.0, "coins": 5, "radius": 0.55, "scale": 1.2, "max": 30,
		"ai": ["tunnel"], "burrow": "tunnel", "sound": "e_wueste", "anims": {"dig": "dig", "under": "under", "rise": "rise"}, "counter": "Fallen im Inneren der Basis; Explosionen erschüttern ihn aus dem Boden.",
		"look": "Maulwurf mit Bohrer-Nase und Schweißerbrille", "text": "Bohrt sich unter Mauern hindurch und taucht mitten in der Basis auf."},
	{"key": "wueste_waschbaer", "family": "wueste", "role": "thief", "name": "Schrott-Waschbär", "hp": 22.0, "speed": 3.8, "dmg": 3.0, "interval": 0.9, "armor": 0.0, "coins": 3, "radius": 0.42, "scale": 1.0, "max": 40,
		"ai": ["thief"], "swarm": [2, 3], "steal_amt": 30.0, "sound": "e_wueste", "anims": {"grab": "grab"}, "counter": "Schnelle Türme am Lager; die Bande einzeln abfangen.",
		"look": "Waschbär mit Räubermaske, Schraubenschlüssel und Rucksack", "text": "Kommt als Bande, plündert das Lager und flieht. Besiegt gibt er die Beute zurück."},
	{"key": "wueste_radkappe", "family": "wueste", "role": "shield", "name": "Radkappen-Schildkröte", "hp": 50.0, "speed": 1.6, "dmg": 9.0, "interval": 1.2, "armor": 1.0, "coins": 4, "radius": 0.7, "scale": 1.4, "max": 40,
		"ai": ["shield_front"], "shield_k": 0.0, "sound": "e_wueste", "anims": {"block": "block"}, "counter": "Von der Seite angreifen, Explosionen oder Bogenwürfe.",
		"look": "Schildkröte mit einer Radkappe als Schild vor dem Kopf", "text": "Hält eine Radkappe vor sich, die Treffer von vorn abprallen lässt."},
	{"key": "untote_schildmatrose", "family": "untote", "role": "shield", "name": "Schildmatrose", "hp": 34.0, "speed": 1.7, "dmg": 7.0, "interval": 1.1, "armor": 0.0, "coins": 3, "radius": 0.5, "scale": 1.6, "max": 60,
		"ai": ["shield_front"], "shield_k": 0.0, "sound": "e_untote", "anims": {"block": "block"}, "counter": "Von der Seite angreifen, Explosionen oder Bogenwürfe.",
		"look": "Zombie-Matrose, der eine Kajütentür als Schild trägt", "text": "Die Kajütentür blockt alle Treffer von vorn."},
	{"key": "untote_seehexe", "family": "untote", "role": "healer", "name": "Seehexe", "hp": 44.0, "speed": 1.9, "dmg": 5.0, "interval": 1.2, "armor": 0.0, "coins": 5, "radius": 0.46, "scale": 1.5, "max": 20,
		"ai": ["healer"], "heal_pct": 0.07, "heal_r": 6.0, "heal_cd": 1.6, "keep": 9.0, "sound": "e_untote", "anims": {"heal": "heal"}, "counter": "Zuerst töten; Gift verhindert die Heilung.",
		"look": "Hexe mit Algenhaar, Muschelkette und Laterne", "text": "Heilt Untote im Umkreis von 6 m mit ihrem Meereslicht."},
	{"key": "untote_pluenderer", "family": "untote", "role": "thief", "name": "Plünderer", "hp": 24.0, "speed": 3.4, "dmg": 3.0, "interval": 0.9, "armor": 0.0, "coins": 5, "radius": 0.45, "scale": 1.4, "max": 30,
		"ai": ["thief"], "steal_amt": 50.0, "sound": "e_untote", "anims": {"grab": "grab"}, "counter": "Schnelle Türme am Lager aufstellen.",
		"look": "Skelett-Pirat mit Augenklappe und großem Beutesack", "text": "Plündert das Lager und rennt mit der Beute davon."},
	{"key": "mutanten_maulwurf", "family": "mutanten", "role": "digger", "name": "Maulwurf-Mutant", "hp": 70.0, "speed": 2.5, "dmg": 11.0, "interval": 1.0, "armor": 1.0, "coins": 5, "radius": 0.6, "scale": 1.3, "max": 30,
		"ai": ["tunnel"], "burrow": "tunnel", "sound": "e_mutanten", "anims": {"dig": "dig", "under": "under", "rise": "rise"}, "counter": "Fallen im Inneren der Basis; Explosionen erschüttern ihn aus dem Boden.",
		"look": "dreiäugiger Maulwurf mit Grabklauen und leuchtenden Warzen", "text": "Gräbt sich unter Mauern hindurch bis ins Innere der Basis."},
	{"key": "mutanten_stoerer", "family": "mutanten", "role": "jammer", "name": "EMP-Kriecher", "hp": 32.0, "speed": 2.3, "dmg": 6.0, "interval": 1.4, "armor": 0.0, "coins": 4, "radius": 0.46, "scale": 1.15, "max": 30,
		"ai": ["jammer"], "jam": "emp", "jam_t": 4.0, "jam_cd": 8.0, "jam_r": 10.0, "sound": "e_mutanten", "anims": {"jam": "jam"}, "counter": "Schildgenerator halbiert die Störung; schnell töten.",
		"look": "Mutant mit Satellitenschüssel auf dem Rücken", "text": "Schießt einen EMP-Ball, der einen Turm 4 s lahmlegt."},
	{"key": "mutanten_brutkessel", "family": "mutanten", "role": "brood", "name": "Brutkessel", "hp": 110.0, "speed": 1.3, "dmg": 9.0, "interval": 1.3, "armor": 2.0, "coins": 8, "radius": 0.9, "scale": 1.9, "max": 12,
		"ai": ["brood"], "brood_key": "mutanten_giftkroete", "brood_n": 2, "brood_cd": 6.0, "sound": "e_mutanten", "anims": {"brood": "brood"}, "counter": "Zuerst töten – sonst quellen immer mehr Kröten heraus.",
		"look": "laufender Kessel auf Stelzbeinen, aus dem Giftkröten springen", "text": "Brütet alle 6 s zwei Giftkröten aus."},
	{"key": "eis_schildwall", "family": "eis", "role": "shield", "name": "Eis-Schildwall", "hp": 60.0, "speed": 1.5, "dmg": 10.0, "interval": 1.3, "armor": 1.0, "coins": 4, "radius": 0.7, "scale": 1.5, "max": 40,
		"ai": ["shield_front"], "shield_k": 0.0, "sound": "e_eis", "anims": {"block": "block"}, "counter": "Von der Seite angreifen, Explosionen; Feuer +50 %.",
		"look": "Eiskrieger hinter einer großen Eisplatte", "text": "Seine Eisplatte hält alle Treffer von vorn ab."},
	{"key": "eis_frostschamanin", "family": "eis", "role": "healer", "name": "Frostschamanin", "hp": 40.0, "speed": 2.0, "dmg": 4.0, "interval": 1.2, "armor": 0.0, "coins": 5, "radius": 0.44, "scale": 1.3, "max": 20,
		"ai": ["healer"], "heal_pct": 0.06, "heal_r": 6.0, "heal_cd": 1.5, "keep": 9.0, "sound": "e_eis", "anims": {"heal": "heal"}, "counter": "Zuerst töten; Gift verhindert die Heilung.",
		"look": "Eiswesen in Fellmantel mit Kristallstab und Eulenmaske", "text": "Heilt Eiswesen im Umkreis von 6 m."},
	{"key": "eis_schneemutter", "family": "eis", "role": "brood", "name": "Schneemutter", "hp": 100.0, "speed": 1.4, "dmg": 8.0, "interval": 1.2, "armor": 1.0, "coins": 7, "radius": 0.85, "scale": 1.9, "max": 12,
		"ai": ["brood"], "brood_key": "eis_frostwichtel", "brood_n": 3, "brood_cd": 6.0, "sound": "e_eis", "anims": {"brood": "brood"}, "counter": "Zuerst töten – sie rollt immer neue Frostwichtel aus.",
		"look": "dicke Schneefrau mit Topf auf dem Kopf und Schneeball-Schürze", "text": "Formt alle 6 s drei Frostwichtel aus Schnee."},
	{"key": "daemonen_glutkobold", "family": "daemonen", "role": "jammer", "name": "Glutkobold", "hp": 34.0, "speed": 2.4, "dmg": 7.0, "interval": 1.3, "armor": 0.0, "coins": 4, "radius": 0.44, "scale": 1.1, "max": 30,
		"ai": ["jammer"], "jam": "lava", "jam_t": 4.0, "jam_cd": 7.0, "jam_r": 9.0, "sound": "e_daemonen", "anims": {"jam": "jam"}, "counter": "Schildgenerator halbiert die Störung; Wasser und Eis +30 %.",
		"look": "Kobold mit Lavaeimer auf dem Rücken und Kelle", "text": "Kippt glühenden Schleim über einen Turm – er schießt 4 s nicht."},
	{"key": "daemonen_gierteufel", "family": "daemonen", "role": "thief", "name": "Gierteufel", "hp": 30.0, "speed": 3.6, "dmg": 4.0, "interval": 0.9, "armor": 0.0, "coins": 6, "radius": 0.44, "scale": 1.1, "max": 30,
		"ai": ["thief"], "steal_amt": 60.0, "sound": "e_daemonen", "anims": {"grab": "grab"}, "counter": "Schnelle Türme am Lager aufstellen.",
		"look": "kleiner Teufel mit Geldsack, Zylinder und Monokel", "text": "Rafft Rohstoffe aus dem Lager und flieht. Besiegt gibt er die Beute zurück."},
	{"key": "daemonen_hoellengraeber", "family": "daemonen", "role": "digger", "name": "Höllengräber", "hp": 80.0, "speed": 2.6, "dmg": 12.0, "interval": 1.0, "armor": 1.0, "coins": 6, "radius": 0.6, "scale": 1.3, "max": 30,
		"ai": ["tunnel"], "burrow": "tunnel", "sound": "e_daemonen", "anims": {"dig": "dig", "under": "under", "rise": "rise"}, "counter": "Fallen im Inneren der Basis; Explosionen erschüttern ihn aus dem Boden.",
		"look": "gehörnter Gräber mit glühender Schaufel", "text": "Wühlt sich durch die Glut unter den Mauern hindurch."},
	# ---- Minibosse (eine je Familie): mitten in Wellen und Expeditionen, mit eigener Lebensleiste
	{"key": "schleim_koloss", "family": "schleim", "role": "miniboss", "name": "Glibberkoloss", "hp": 700.0, "speed": 1.3, "dmg": 30.0, "interval": 1.4, "armor": 2.0, "coins": 25, "radius": 1.3, "scale": 2.5, "max": 2,
		"ai": ["miniboss"], "mini_skill": "slam", "mini_cd": 7.0, "mini_r": 5.0, "sound": "e_schleim", "anims": {"skill": "skill"}, "counter": "Aus der roten Zone gehen; Fähigkeiten aufsparen.",
		"look": "turmhoher Wackelpudding mit Topfhelm", "text": "Springt hoch und landet mit einer Druckwelle (rote Zone)."},
	{"key": "wald_eichbart", "family": "wald", "role": "miniboss", "name": "Alter Eichbart", "hp": 820.0, "speed": 1.1, "dmg": 30.0, "interval": 1.5, "armor": 3.0, "coins": 25, "radius": 1.3, "scale": 3.0, "max": 2,
		"ai": ["miniboss"], "mini_skill": "roots", "mini_cd": 8.0, "mini_r": 3.0, "sound": "e_wald", "anims": {"skill": "skill"}, "counter": "Aus der roten Zone gehen, sonst halten Wurzeln fest.",
		"look": "knorriger Eichenriese mit Moosbart und Pilzen", "text": "Lässt Wurzeln unter dem Helden hervorbrechen, die ihn festhalten."},
	{"key": "wueste_skorpion", "family": "wueste", "role": "miniboss", "name": "Schrottskorpion", "hp": 900.0, "speed": 1.6, "dmg": 34.0, "interval": 1.4, "armor": 4.0, "coins": 25, "radius": 1.3, "scale": 3.0, "max": 2,
		"ai": ["miniboss"], "mini_skill": "acid", "mini_cd": 7.0, "mini_r": 3.0, "sound": "e_wueste", "anims": {"skill": "skill"}, "counter": "Säurefelder meiden; Explosionen +30 %.",
		"look": "Skorpion aus Autoteilen mit Zapfpistolen-Stachel", "text": "Sticht Säure in den Boden, die Helden und Mauern zerfrisst."},
	{"key": "untote_bootsmann", "family": "untote", "role": "miniboss", "name": "Bootsmann Knochenhand", "hp": 880.0, "speed": 1.3, "dmg": 32.0, "interval": 1.5, "armor": 2.0, "coins": 25, "radius": 1.3, "scale": 3.0, "max": 2,
		"ai": ["miniboss"], "mini_skill": "ring", "mini_cd": 7.0, "mini_r": 5.5, "sound": "e_untote", "anims": {"skill": "skill"}, "counter": "Abstand halten, wenn er den Anker kreisen lässt; Blitz +50 %.",
		"look": "riesiges Skelett mit Anker und Bootsmannspfeife", "text": "Lässt seinen Anker im Kreis sausen (rote Zone um ihn)."},
	{"key": "mutanten_panzerkroete", "family": "mutanten", "role": "miniboss", "name": "Panzerkröte", "hp": 950.0, "speed": 1.2, "dmg": 34.0, "interval": 1.5, "armor": 3.0, "coins": 25, "radius": 1.4, "scale": 3.0, "max": 2,
		"ai": ["miniboss"], "mini_skill": "toxic", "mini_cd": 7.5, "mini_r": 3.5, "sound": "e_mutanten", "anims": {"skill": "skill"}, "counter": "Giftfelder meiden; Eis +40 %.",
		"look": "Riesenkröte mit Panzerplatten und Rohren auf dem Rücken", "text": "Spuckt große Giftblasen, die am Boden zu Giftfeldern zerplatzen."},
	{"key": "eis_mammut", "family": "eis", "role": "miniboss", "name": "Frostmammut", "hp": 1000.0, "speed": 1.2, "dmg": 36.0, "interval": 1.6, "armor": 3.0, "coins": 25, "radius": 1.5, "scale": 3.2, "max": 2,
		"ai": ["miniboss"], "mini_skill": "frost_ring", "mini_cd": 8.0, "mini_r": 6.0, "sound": "e_eis", "anims": {"skill": "skill"}, "counter": "Türme verteilen; Feuer +50 %.",
		"look": "Mammut mit Eiszapfen-Stoßzähnen und Schneedecke", "text": "Stampft eine Frostwelle, die Türme in der Nähe einfriert."},
	{"key": "daemonen_kettenteufel", "family": "daemonen", "role": "miniboss", "name": "Kettenteufel", "hp": 1050.0, "speed": 1.4, "dmg": 38.0, "interval": 1.4, "armor": 3.0, "coins": 25, "radius": 1.3, "scale": 3.0, "max": 2,
		"ai": ["miniboss", "pull"], "pull": 10.0, "pull_cd": 9.0, "mini_skill": "chain", "mini_cd": 7.0, "mini_r": 4.0, "sound": "e_daemonen", "anims": {"skill": "skill", "pull": "throw"}, "counter": "Ausweichrolle reißt die Kette los; Wasser/Eis +30 %.",
		"look": "Dämon in Ketten mit glühendem Halsband", "text": "Zieht den Helden an der Kette heran und entfacht einen Feuerring."},
	# ---- Weltboss (Clan-Raids und Ereignisse; über das Admin-Menü startbar)
	{"key": "boss_leviathan", "family": "schleim", "role": "boss", "name": "Schleim-Leviathan", "hp": 30000.0, "speed": 0.8, "dmg": 90.0, "interval": 1.8, "armor": 4.0, "coins": 200, "radius": 3.2, "scale": 7.0, "max": 1, "boss": true, "world": true,
		"ai": [], "specials": ["tide", "rain", "summon"], "summon": "schleim_brutschleim", "summon_n": 2, "sound": "e_schleim", "counter": "Gemeinsam angreifen; rote Zonen meiden.",
		"look": "gewaltige Schleimschlange mit Krone aus Wrackteilen", "text": "Weltboss: Flutwelle, Schleimregen und Brutschleime. Für Clan-Raids und Ereignisse."},
	# ---- Vulkaninsel (Paket Z): Magma-Wesen – sechs Arten, drei Rollen aus G2, Miniboss und Boss
	##   lava_bath: in der Nähe fließender Lava (bath_r Meter) heilt die Art bath (Anteil Leben/s) und läuft 20 % schneller
	##   harden:    nach Treffern verhärtet die Kruste (harden_t Sekunden, nur harden_k des Schadens kommt durch); Wasser/Eis sprengt sie
	{"key": "magma_lavaschnecke", "family": "magma", "role": "mass", "name": "Lavaschnecke", "hp": 22.0, "speed": 1.9, "dmg": 6.0, "interval": 1.1, "armor": 0.0, "coins": 1, "radius": 0.45, "scale": 1.0, "max": 300,
		"ai": ["lava_bath"], "bath": 0.12, "bath_r": 4.0, "sound": "e_magma", "anims": {"bath": "steam"}, "counter": "Weg von der Lava locken – dort heilt sie nicht; Wasser +60 %.",
		"look": "Schnecke mit qualmendem Vulkanhaus auf dem Rücken", "text": "Kriecht in großen Mengen heran. Nahe der Lava badet sie im Glutdampf: Sie heilt und wird schneller."},
	{"key": "magma_feuerkaefer", "family": "magma", "role": "fast", "name": "Feuerkäfer", "hp": 18.0, "speed": 5.0, "dmg": 4.0, "interval": 0.7, "armor": 0.0, "coins": 1, "radius": 0.4, "scale": 0.9, "max": 100,
		"ai": ["pack", "pounce", "death_cloud"], "hunt": true, "swarm": [2, 3], "pounce": 4.5, "cloud": "fire", "cloud_r": 1.4, "cloud_t": 2.5, "sound": "e_magma", "anims": {"pounce": "pounce"},
		"counter": "Aus der Ferne erledigen – beim Tod lodert eine Stichflamme.",
		"look": "Käfer mit glühendem Hinterleib wie ein Kohlestück", "text": "Kommt im Schwarm, springt den Helden an und verpufft beim Tod in einer Stichflamme."},
	{"key": "magma_obsidiangolem", "family": "magma", "role": "tank", "name": "Obsidian-Golem", "hp": 340.0, "speed": 1.2, "dmg": 32.0, "interval": 1.7, "armor": 4.0, "coins": 9, "radius": 1.1, "scale": 2.6, "max": 30,
		"ai": ["siege", "harden"], "siege": 2.0, "harden_t": 2.5, "harden_k": 0.35, "harden_cd": 8.0, "sound": "e_magma", "anims": {"harden": "harden"},
		"counter": "Wasser oder Eis sprengen die Kruste; warten, bis sie wieder weich wird.",
		"look": "Riese aus schwarzem Glas mit Lavaadern und Basaltfäusten", "text": "Doppelter Schaden an Mauern. Wird er getroffen, verhärtet die Kruste 2,5 s (nur 35 % Schaden)."},
	{"key": "magma_glutspucker", "family": "magma", "role": "ranged", "name": "Glutspucker", "hp": 34.0, "speed": 1.9, "dmg": 12.0, "interval": 2.6, "armor": 0.0, "coins": 3, "radius": 0.5, "scale": 1.25, "max": 60,
		"ai": ["ranged_arc"], "range": 14.0, "splash": 2.0, "zone": "fire", "zone_t": 3.5, "siege_shot": true, "sound": "e_magma", "anims": {"aim": "erupt"},
		"counter": "Den roten Kreisen ausweichen; Fernkampf und Wasser.",
		"look": "kleiner Vulkan auf Stummelbeinen, der Glutbrocken spuckt", "text": "Spuckt Glutbrocken im hohen Bogen (14 m); der Boden brennt 3,5 s."},
	{"key": "magma_aschegeist", "family": "magma", "role": "air", "name": "Aschegeist", "hp": 18.0, "speed": 3.2, "dmg": 5.0, "interval": 1.0, "armor": 0.0, "coins": 2, "radius": 0.42, "scale": 1.1, "max": 60,
		"ai": ["blink", "death_cloud"], "fly": true, "blink": 6.0, "blink_cd": 5.0, "cloud": "spore", "cloud_r": 2.2, "cloud_t": 3.0, "sound": "e_magma", "anims": {"blink": "blink"},
		"counter": "Nicht in seine Aschewolke laufen – sie macht langsam.",
		"look": "schwebende Aschewolke mit zwei glühenden Augen", "text": "Fliegt über Mauern, springt alle 5 s 6 m weit und zerfällt beim Tod zu einer Aschewolke, die verlangsamt."},
	{"key": "magma_schlackenkriecher", "family": "magma", "role": "special", "name": "Schlackenkriecher", "hp": 70.0, "speed": 2.2, "dmg": 10.0, "interval": 1.1, "armor": 1.0, "coins": 5, "radius": 0.6, "scale": 1.2, "max": 40,
		"ai": ["split", "lava_bath"], "split": 2, "split_hp": 0.3, "bath": 0.06, "bath_r": 4.0, "sound": "e_magma", "anims": {"bath": "steam"},
		"counter": "Explosionen erwischen auch die Brocken, in die er zerfällt.",
		"look": "Raupe aus Schlackebrocken mit glühenden Fugen", "text": "Zerfällt beim Tod in zwei kleine Schlackebrocken. Heilt nahe der Lava."},
	{"key": "magma_glutpriesterin", "family": "magma", "role": "healer", "name": "Glutpriesterin", "hp": 44.0, "speed": 2.0, "dmg": 5.0, "interval": 1.2, "armor": 0.0, "coins": 5, "radius": 0.46, "scale": 1.35, "max": 20,
		"ai": ["healer"], "heal_pct": 0.07, "heal_r": 6.0, "heal_cd": 1.5, "keep": 9.0, "sound": "e_magma", "anims": {"heal": "heal"}, "counter": "Zuerst töten; Gift verhindert die Heilung.",
		"look": "Gestalt in Aschemantel mit Glutschale und Obsidianmaske", "text": "Heilt alle Magma-Wesen im Umkreis von 6 m mit ihrer Glutschale."},
	{"key": "magma_basaltschild", "family": "magma", "role": "shield", "name": "Basaltschildträger", "hp": 64.0, "speed": 1.5, "dmg": 11.0, "interval": 1.3, "armor": 1.0, "coins": 4, "radius": 0.7, "scale": 1.5, "max": 40,
		"ai": ["shield_front"], "shield_k": 0.0, "sound": "e_magma", "anims": {"block": "block"}, "counter": "Von der Seite angreifen, Explosionen oder Bogenwürfe; Wasser +60 %.",
		"look": "gedrungener Krieger mit sechseckiger Basaltplatte als Schild", "text": "Seine Basaltplatte hält alle Treffer von vorn ab."},
	{"key": "magma_lavamutter", "family": "magma", "role": "brood", "name": "Lavamutter", "hp": 110.0, "speed": 1.3, "dmg": 9.0, "interval": 1.3, "armor": 1.0, "coins": 8, "radius": 0.9, "scale": 1.9, "max": 12,
		"ai": ["brood"], "brood_key": "magma_lavaschnecke", "brood_n": 2, "brood_cd": 7.0, "sound": "e_magma", "anims": {"brood": "brood"}, "counter": "Zuerst töten – sonst kriechen immer mehr Lavaschnecken heraus.",
		"look": "riesige Schnecke mit brodelndem Kraterhaus voller Eier", "text": "Lässt alle 7 s zwei Lavaschnecken aus ihrem Krater schlüpfen."},
	{"key": "magma_glutbrecher", "family": "magma", "role": "miniboss", "name": "Glutbrecher", "hp": 1150.0, "speed": 1.4, "dmg": 40.0, "interval": 1.5, "armor": 4.0, "coins": 25, "radius": 1.4, "scale": 3.0, "max": 2,
		"ai": ["miniboss"], "mini_skill": "lava", "mini_cd": 7.0, "mini_r": 3.5, "sound": "e_magma", "anims": {"skill": "skill"}, "counter": "Aus der roten Zone gehen – dort bleibt flüssige Lava; Wasser +60 %.",
		"look": "Stier aus Basalt mit Magmahörnern und glühendem Nasenring", "text": "Stampft auf: Wo die rote Zone war, quillt Lava aus dem Boden."},
	{"key": "boss_magma", "family": "magma", "role": "boss", "name": "Magmafürst Brodel", "hp": 2800.0, "speed": 1.2, "dmg": 80.0, "interval": 1.7, "armor": 3.0, "coins": 60, "radius": 2.1, "scale": 4.8, "max": 2, "boss": true,
		"ai": [], "specials": ["eruption", "summon"], "summon": "magma_lavaschnecke", "summon_n": 4, "sound": "e_magma", "counter": "Bei rotem Boden laufen; nach dem Ausbruch glüht der Kern – dann zuschlagen.",
		"look": "Vulkanriese mit Obsidiankrone, Lavabart und glühendem Kern in der Brust", "text": "Lässt Lavabomben regnen (rote Zonen), ruft Lavaschnecken und stampft ab Phase 2. Unter 30 % rast er."},
	# ---- Stadtruinen (Paket Z2): Maschinen – sechs Arten, drei Rollen aus G2, Miniboss und Boss
	##   climb:  klettert an Fassaden hoch und erreicht den Helden auch auf einem Dach (exp_stadt.gd); andere Nahkämpfer nicht
	##   signal: schaltet alle signal_cd Sekunden um – Grün: Maschinen im Umkreis signal_r werden schneller, Rot: der Held wird langsamer
	##   scoop:  schaufelt Schutt und schleudert ihn im Bogen (rote Zone, scoop_r Meter weit)
	{"key": "maschinen_maeher", "family": "maschinen", "role": "mass", "name": "Rasenmäher-Bot", "hp": 24.0, "speed": 2.1, "dmg": 6.0, "interval": 1.0, "armor": 0.5, "coins": 1, "radius": 0.45, "scale": 1.0, "max": 300,
		"ai": ["charge", "zigzag"], "charge": 5.5, "charge_cd": 8.0, "sound": "e_maschinen", "anims": {"charge_start": "rev", "charge": "mow"},
		"counter": "Zur Seite treten, wenn der Motor aufheult – der Mähsturm geht nur geradeaus; Blitz +50 %.",
		"look": "roter Rasenmäher mit Kameraaugen, Grasfangkorb und Schiebebügel als Antennen", "text": "Rattert im Zickzack heran, heult auf und mäht dann 5,5 m geradeaus durch alles hindurch."},
	{"key": "maschinen_funkenspinne", "family": "maschinen", "role": "fast", "name": "Funkenspinne", "hp": 18.0, "speed": 5.2, "dmg": 4.0, "interval": 0.7, "armor": 0.0, "coins": 1, "radius": 0.42, "scale": 0.95, "max": 100,
		"ai": ["pack", "pounce"], "hunt": true, "swarm": [2, 3], "pounce": 4.5, "climb": true, "sound": "e_maschinen", "anims": {"pounce": "pounce", "climb": "climb"},
		"counter": "Auch auf dem Dach nicht sicher: Sie klettert die Wand hoch. Aus der Ferne erledigen.",
		"look": "Stahlspinne mit Warnstreifen, roten Leuchtaugen und einer Teslaspule auf dem Rücken", "text": "Kommt in kleinen Rudeln, springt den Helden an und klettert sogar Fassaden hoch."},
	{"key": "maschinen_baggergolem", "family": "maschinen", "role": "tank", "name": "Bagger-Golem", "hp": 360.0, "speed": 1.2, "dmg": 34.0, "interval": 1.8, "armor": 4.5, "coins": 9, "radius": 1.1, "scale": 2.6, "max": 30,
		"ai": ["siege", "scoop"], "siege": 2.0, "scoop_cd": 8.0, "scoop_r": 12.0, "scoop_min": 4.0, "scoop_zone": 2.6, "sound": "e_maschinen", "anims": {"scoop": "scoop"},
		"counter": "Aus der roten Zone gehen, wenn er schaufelt; Blitz und Wasser lassen ihn kurzschließen.",
		"look": "Bagger auf zwei Kettenbeinen mit Schaufelarm, Hydraulikklaue und Fahrerkabine als Kopf", "text": "Doppelter Schaden an Mauern. Schaufelt Schutt und schleudert ihn bis 12 m weit (rote Zone)."},
	{"key": "maschinen_ampelwaechter", "family": "maschinen", "role": "ranged", "name": "Ampelwächter", "hp": 36.0, "speed": 1.9, "dmg": 10.0, "interval": 2.2, "armor": 0.5, "coins": 3, "radius": 0.5, "scale": 1.3, "max": 60,
		"ai": ["ranged_line", "signal"], "range": 11.0, "signal_cd": 9.0, "signal_r": 8.0, "sound": "e_maschinen", "anims": {"signal": "signal"},
		"counter": "Bei Rot aus seinem Kreis gehen; schnell ausschalten, sonst bekommen die anderen Maschinen grüne Welle.",
		"look": "Wachmann mit Ampelkopf und Signalkellen", "text": "Schießt rote Lichtstrahlen (11 m). Schaltet um: Grün macht Maschinen schneller, Rot bremst den Helden."},
	{"key": "maschinen_drohne", "family": "maschinen", "role": "air", "name": "Drohnenschwarm", "hp": 14.0, "speed": 3.8, "dmg": 4.0, "interval": 1.2, "armor": 0.0, "coins": 1, "radius": 0.38, "scale": 0.9, "max": 90,
		"ai": ["ranged_line", "strafe"], "fly": true, "range": 7.0, "swarm": [3, 4], "sound": "e_maschinen", "anims": {"shot": "zap"},
		"counter": "Flächenschaden trifft den ganzen Schwarm; Blitz +50 %.",
		"look": "kleine Quadrokopter mit Kamera-Auge und Elektroschocker", "text": "Kommt im Schwarm, fliegt über Mauern und Dächer, schockt aus 7 m und weicht nach jedem Schuss aus."},
	{"key": "maschinen_muellpresse", "family": "maschinen", "role": "special", "name": "Müllpresse", "hp": 80.0, "speed": 1.6, "dmg": 12.0, "interval": 1.4, "armor": 2.0, "coins": 5, "radius": 0.75, "scale": 1.5, "max": 40,
		"ai": ["pull", "siege"], "pull": 9.0, "pull_cd": 8.0, "siege": 1.6, "sound": "e_maschinen", "anims": {"pull": "grab"},
		"counter": "Ausweichrolle reißt den Greifarm los; nicht vor ihrem Maul stehen bleiben.",
		"look": "grüner Pressbehälter auf Ketten mit Zahnmaul und Greifarm", "text": "Packt den Helden mit dem Greifarm aus 9 m und zieht ihn vor ihr Pressmaul."},
	{"key": "maschinen_reparaturbot", "family": "maschinen", "role": "healer", "name": "Reparatur-Bot", "hp": 42.0, "speed": 2.0, "dmg": 4.0, "interval": 1.2, "armor": 0.0, "coins": 5, "radius": 0.46, "scale": 1.3, "max": 20,
		"ai": ["healer"], "heal_pct": 0.07, "heal_r": 6.0, "heal_cd": 1.5, "keep": 9.0, "sound": "e_maschinen", "anims": {"heal": "repair"},
		"counter": "Zuerst ausschalten – Blitz und Wasser lassen ihn kurzschließen.",
		"look": "Werkzeugkiste auf Rollen mit Schweißerhelm, Schraubenschlüssel und grünem Kreuz", "text": "Schweißt alle Maschinen im Umkreis von 6 m wieder heil."},
	{"key": "maschinen_schildbot", "family": "maschinen", "role": "shield", "name": "Schild-Bot", "hp": 66.0, "speed": 1.5, "dmg": 11.0, "interval": 1.3, "armor": 1.0, "coins": 4, "radius": 0.7, "scale": 1.5, "max": 40,
		"ai": ["shield_front"], "shield_k": 0.0, "sound": "e_maschinen", "anims": {"block": "block"},
		"counter": "Von der Seite oder von oben (Dach) angreifen, Explosionen oder Bogenwürfe; Blitz +50 %.",
		"look": "Panzer-Roboter mit rot-weißer Absperrschranke als Schild", "text": "Seine Absperrschranke hält alle Treffer von vorn ab."},
	{"key": "maschinen_stoersender", "family": "maschinen", "role": "jammer", "name": "Störsender", "hp": 32.0, "speed": 2.3, "dmg": 6.0, "interval": 1.4, "armor": 0.0, "coins": 4, "radius": 0.46, "scale": 1.15, "max": 30,
		"ai": ["jammer"], "jam": "emp", "jam_t": 4.0, "jam_cd": 8.0, "jam_r": 10.0, "sound": "e_maschinen", "anims": {"jam": "jam"},
		"counter": "Schildgenerator halbiert die Störung; schnell ausschalten.",
		"look": "Funkkasten auf zwei Beinen mit Parabolschüssel und Störscheibe", "text": "Schleudert Störscheiben auf Türme: 4 s Funkstille."},
	{"key": "maschinen_abrisskran", "family": "maschinen", "role": "miniboss", "name": "Abrisskran", "hp": 1200.0, "speed": 1.3, "dmg": 42.0, "interval": 1.6, "armor": 4.0, "coins": 25, "radius": 1.4, "scale": 3.0, "max": 2,
		"ai": ["miniboss"], "mini_skill": "abriss", "mini_cd": 7.0, "mini_r": 3.8, "sound": "e_maschinen", "anims": {"skill": "skill"},
		"counter": "Aus der roten Zone gehen – die Abrissbirne trifft Mauern doppelt; Blitz +50 %.",
		"look": "Kettenkran mit gelbem Ausleger und schwarzer Abrissbirne", "text": "Schwingt die Abrissbirne über sich und schmettert sie in die rote Zone: Mauern bekommen doppelten Schaden."},
	{"key": "boss_maschinen", "family": "maschinen", "role": "boss", "name": "Bürgermeister Bolzen", "hp": 3000.0, "speed": 1.2, "dmg": 84.0, "interval": 1.7, "armor": 3.0, "coins": 65, "radius": 2.1, "scale": 4.8, "max": 2, "boss": true,
		"ai": [], "specials": ["spannung", "summon"], "summon": "maschinen_maeher", "summon_n": 4, "sound": "e_maschinen",
		"counter": "Den blauen Blitzlinien ausweichen; nach dem Stromstoß ist der Akku in der Brust offen – dann zuschlagen.",
		"look": "Straßenbahnwagen auf Beinen mit Uhrengesicht, Bürstenbart, Blech-Zylinder und Amtskette", "text": "Jagt Stromstöße in Linien über den Boden (rote Zonen), läutet nach Rasenmäher-Bots und stampft ab Phase 2. Unter 30 % rast er."},
]
const ENEMY_INDEX := {"schleim_schleimling": 0, "schleim_flitzer": 1, "schleim_fass": 2, "schleim_brocken": 3, "schleim_spucker": 4, "schleim_helm": 5, "schleim_flatter": 6, "schleim_schamane": 7, "schleim_boss": 8,
	"wald_pilzling": 9, "wald_dornenwolf": 10, "wald_baumhueter": 11, "wald_zapfenwerfer": 12, "wald_irrlicht": 13, "wald_wurzelkriecher": 14,
	"wueste_schrottkaefer": 15, "wueste_staubteufel": 16, "wueste_rostbulle": 17, "wueste_kaktusschuetze": 18, "wueste_geier": 19, "wueste_sandwurm": 20,
	"untote_matrose": 21, "untote_deckratte": 22, "untote_taucher": 23, "untote_kanonier": 24, "untote_qualle": 25, "untote_krabbe": 26,
	"mutanten_giftkroete": 27, "mutanten_egelschwarm": 28, "mutanten_schlammgolem": 29, "mutanten_rohrspucker": 30, "mutanten_werksdrohne": 31, "mutanten_seuchenarzt": 32,
	"eis_frostwichtel": 33, "eis_eiswolf": 34, "eis_yeti": 35, "eis_kristallschuetze": 36, "eis_eisgeist": 37, "eis_lawinenroller": 38,
	"daemonen_hoellenwichtel": 39, "daemonen_hund": 40, "daemonen_waechter": 41, "daemonen_feuerspeier": 42, "daemonen_schattenschwinge": 43, "daemonen_beschwoerer": 44,
	"boss_wald": 45, "boss_wueste": 46, "boss_untote": 47, "boss_mutanten": 48, "boss_eis": 49, "boss_daemonen": 50, "daemonen_portal": 51,
	"schleim_brutschleim": 52, "schleim_deckel": 53, "schleim_klauschleim": 54, "wald_druide": 55, "wald_spinnenmutter": 56, "wald_rankenwerfer": 57, "wueste_maulwurf": 58, "wueste_waschbaer": 59, "wueste_radkappe": 60, "untote_schildmatrose": 61, "untote_seehexe": 62, "untote_pluenderer": 63, "mutanten_maulwurf": 64, "mutanten_stoerer": 65, "mutanten_brutkessel": 66, "eis_schildwall": 67, "eis_frostschamanin": 68, "eis_schneemutter": 69, "daemonen_glutkobold": 70, "daemonen_gierteufel": 71, "daemonen_hoellengraeber": 72, "schleim_koloss": 73, "wald_eichbart": 74, "wueste_skorpion": 75, "untote_bootsmann": 76, "mutanten_panzerkroete": 77, "eis_mammut": 78, "daemonen_kettenteufel": 79, "boss_leviathan": 80,
	"magma_lavaschnecke": 81, "magma_feuerkaefer": 82, "magma_obsidiangolem": 83, "magma_glutspucker": 84, "magma_aschegeist": 85, "magma_schlackenkriecher": 86, "magma_glutpriesterin": 87, "magma_basaltschild": 88, "magma_lavamutter": 89, "magma_glutbrecher": 90, "boss_magma": 91,
	"maschinen_maeher": 92, "maschinen_funkenspinne": 93, "maschinen_baggergolem": 94, "maschinen_ampelwaechter": 95, "maschinen_drohne": 96, "maschinen_muellpresse": 97, "maschinen_reparaturbot": 98, "maschinen_schildbot": 99, "maschinen_stoersender": 100, "maschinen_abrisskran": 101, "boss_maschinen": 102}
## Boss je Gebiet (Schlüssel) – Gebiet 7 beginnt als Schleimriese, aus dem der Dämon hervorbricht (phase_of)
const AREA_BOSS := ["schleim_boss", "boss_wald", "boss_wueste", "boss_untote", "boss_mutanten", "boss_eis", "boss_daemonen", "boss_magma", "boss_maschinen"]
const BOSSES := [
	{"name": "Dicker Bert", "special": "summon"}, {"name": "Mooskönigin", "special": "spit"}, {"name": "Rostbrocken", "special": "slam"},
	{"name": "Kapitän Glibber", "special": "spit"}, {"name": "Der Schlund", "special": "summon"}, {"name": "Frostbrocken", "special": "slam"},
	{"name": "Schleimkönig", "special": "all"}, {"name": "Magmafürst Brodel", "special": "cycle"}, {"name": "Bürgermeister Bolzen", "special": "cycle"},
]
## Bosse (Paket G2, 6.5): Phasen nach Lebensanteil. Phase 2 bringt einen weiteren Sonderangriff, unter 30 % folgt die Wutphase
## (schneller, stärker, Sonderangriffe öfter). Nach jedem großen Angriff ist der Boss kurz erschöpft: die Schwachstelle leuchtet
## (doppelter Schaden). intro = Untertitel beim Auftritt, weak = wo die Schwachstelle sitzt (nur Anzeige), trophy = Deko-Gebäude.
const BOSS_RAGE_AT := 0.3
const BOSS_RAGE := {"speed": 1.35, "dmg": 1.3, "special": 0.6}
const BOSS_EXPOSE_T := 2.4
const BOSS_EXPOSE_DMG := 2.0
const BOSS_PHASES := {
	"schleim_boss": {"intro": "Der Herr der Schleimlinge", "weak": "die Krone", "p2": 0.66, "add": "slam", "trophy": "trophy_bert"},
	"boss_wald": {"intro": "Herrin des Kiefernforsts", "weak": "der Pilzhut", "p2": 0.66, "add": "slam", "trophy": "trophy_moos"},
	"boss_wueste": {"intro": "Schrottgolem der Staubebene", "weak": "der Kessel im Bauch", "p2": 0.66, "add": "summon", "summon": "wueste_schrottkaefer", "trophy": "trophy_rost"},
	"boss_untote": {"intro": "Schrecken der Schrottküste", "weak": "das Steuerrad", "p2": 0.66, "add": "slam", "trophy": "trophy_glibber"},
	"boss_mutanten": {"intro": "Das Maul des Sumpfwerks", "weak": "das Ventil", "p2": 0.66, "add": "spores", "trophy": "trophy_schlund"},
	"boss_eis": {"intro": "Wächter des Frostpasses", "weak": "die Kristallkrone", "p2": 0.66, "add": "slam", "trophy": "trophy_frost"},
	"boss_daemonen": {"intro": "König des Schleimkraters", "weak": "das Herz aus Glut", "p2": 0.0, "add": "", "trophy": "trophy_koenig"},
	"boss_leviathan": {"intro": "Weltboss", "weak": "die Kiemen", "p2": 0.66, "add": "slam", "trophy": ""},
	"boss_magma": {"intro": "Herrscher der Vulkaninsel", "weak": "der Glutkern in der Brust", "p2": 0.66, "add": "slam", "trophy": "trophy_brodel"},
	"boss_maschinen": {"intro": "Herrscher der Stadtruinen", "weak": "der Sternsplitter-Akku in der Brust", "p2": 0.66, "add": "slam", "trophy": "trophy_bolzen"},
}
## Elite-Gegner (6.2): sichtbar mit Krone, Aura und Namensschild; in der Flut ab ELITE_WEEK je Welle (ab Welle 2) einige.
const ELITE_HP := 2.5
const ELITE_COLOR := Color(1.25, 1.05, 0.55)
const ELITE_WEEK := 4
## Minibosse in der Flut ab Woche MINI_WEEK in der mittleren Welle; Expedition: der MINI_EXP_EVERY-te Gegner eines Großangriffs (einmal)
const MINI_WEEK := 5
const MINI_EXP_HP := 0.4                         # Miniboss im Großangriff der Expedition: Anteil am Leben
const MINI_EXP_EVERY := 30
const MAX_ALIVE := [200, 300, 420]                  # je Qualitätsstufe (Niedrig, Mittel, Hoch)
const BESTIARY_TIERS := [10, 100, 1000]             # Monsterbuch: so viele Besiegte …
const BESTIARY_GEMS := [2, 5, 15]                   # … geben so viele Juwelen


## Eintrag einer Gegnerart über ihren Schlüssel.
static func enemy(key: String) -> Dictionary:
	return ENEMIES[int(ENEMY_INDEX[key])]


## Nummern aller Arten einer Familie (ohne Bosse und Objekte), in der Reihenfolge der Rollen.
static func family_enemies(fam: String) -> Array:
	var out: Array = []
	for i in ENEMIES.size():
		var e: Dictionary = ENEMIES[i]
		if e.family == fam and ROLES.has(String(e.role)):
			out.append(i)
	return out


## Alle Arten einer Familie, die in gemischten Gruppen vorkommen: die sechs Grundrollen und die neuen Rollen (ohne Miniboss).
static func family_all(fam: String) -> Array:
	var out: Array = []
	for i in ENEMIES.size():
		var e: Dictionary = ENEMIES[i]
		if e.family == fam and (ROLES.has(String(e.role)) or ROLES_EXTRA.has(String(e.role))):
			out.append(i)
	return out


## Miniboss einer Familie (Nummer) oder -1.
static func family_mini(fam: String) -> int:
	for i in ENEMIES.size():
		if ENEMIES[i].family == fam and ENEMIES[i].role == "miniboss":
			return i
	return -1


## Paket G2: Symbol je Element (Monsterbuch: Schwächen-Symbole)
const ELEMENT_ICON := {"kugel": "ui_bullet", "feuer": "ui_fire", "wasser": "ui_water", "eis": "ui_snow", "blitz": "ui_bolt", "explosion": "ui_bomb", "gift": "ui_poison"}
const ELEMENT_NAME := {"kugel": "Kugeln", "feuer": "Feuer", "wasser": "Wasser", "eis": "Eis", "blitz": "Blitz", "explosion": "Explosion", "gift": "Gift"}
## Ab dieser Woche kommen die Schleimlinge 0–7 in der Flut vor (wie flood_mix)
const FLOOD_WEEK := [1, 2, 3, 3, 4, 6, 8, 12]


## Fundorte einer Art (Monsterbuch): Gebiet der Expedition, Flut (Grundlage oder Gast), Bosse und Weltboss.
static func enemy_places(key: String) -> Array:
	var e: Dictionary = enemy(key)
	var fam := String(e.family)
	var ai: int = AREA_FAMILY.find(fam)
	var area := String(AREAS[ai].name) if ai >= 0 else ""
	var role := String(e.role)
	var t: int = int(ENEMY_INDEX[key])
	var out: Array = []
	if e.get("world", false):
		return ["Weltboss: Ereignisse und Clan-Raids"]
	if role == "boss":
		out.append("Boss in %s (Expedition)" % area)
		out.append("Flut: Boss der letzten Welle ab Woche 3" + ("" if fam == "schleim" else " (als Gast)"))
		return out
	if role == "object":
		return ["Kommt mit dem Beschwörer (%s)" % area]
	if role == "miniboss":
		out.append("%s: Großangriff der Expedition" % area)
		out.append("Flut: mittlere Welle ab Woche %d" % MINI_WEEK + ("" if fam == "schleim" else " (als Gast)"))
		return out
	if fam == "schleim":
		out.append("Grüntal (Expedition)")
		if t < FLOOD_WEEK.size():
			out.append("Flut ab Woche %d" % int(FLOOD_WEEK[t]))
		elif FLOOD_EXTRA.has(key):
			out.append("Flut ab Woche %d" % int(FLOOD_EXTRA[key][0]))
		return out
	out.append("%s (Expedition)" % area)
	out.append("Flut: als Gastfamilie ab Woche 3")
	return out


## Schadens-Faktor einer Familie gegen ein Element ("" = neutral).
static func weak_factor(fam: String, element: String) -> float:
	if element == "":
		return 1.0
	return float(FAMILIES[fam].weak.get(element, 1.0))

# ---------------------------------------------------------------- Flut (Sieben-Tage-Zyklus)
const DAY_SECONDS := 86400
const DAY_SHIFT_HOURS := 4                          # Tageswechsel um 4:00 Uhr
const FLOOD_DAY := 7
const WAVE_BREAK := 10.0
const FLOOD_LOSS := 0.2
const PRACTICE_STRENGTH := 0.4

## Stärke der Flut in Woche w (ab 1): Wellen, Gegner gesamt, Lebens-Faktor.
static func flood_def(week: int, bunker: int) -> Dictionary:
	var w := maxi(1, week)
	var waves := mini(12, 4 + int(w / 2) + (1 if w > 1 else 0))
	var total := 130.0 * pow(1.22, mini(w, 12) - 1)
	if w > 12:
		total *= pow(1.08, w - 12)
	# die Bunker-Stufe begrenzt, wie groß die Flut werden kann
	total = minf(total, 160.0 * pow(1.45, bunker))
	return {"waves": waves, "total": int(round(total / 10.0) * 10), "hp": 1.0 + 0.12 * (w - 1), "dmg": 1.0 + 0.08 * (w - 1), "boss": w >= 3}

## Anteil je Gegnertyp in Woche w (nur Schleimlinge, Nummern 0–7). Gastfamilien mischt flood_guest_share dazu.
static func flood_mix(week: int) -> Array:
	var m := [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	if week >= 2:
		m[E_RUNNER] = 0.12
	if week >= 3:
		m[E_BARREL] = 0.05
		m[E_BRUTE] = 0.03
	if week >= 4:
		m[E_SPITTER] = 0.05
	if week >= 6:
		m[E_HELM] = 0.12
	if week >= 8:
		m[E_FLYER] = 0.08
	if week >= 12:
		m[E_SHAMAN] = 0.02
	return m


## Neue Schleim-Rollen (Paket G2) in der Flut: Schlüssel -> [ab Woche, Anteil].
const FLOOD_EXTRA := {"schleim_deckel": [4, 0.05], "schleim_brutschleim": [5, 0.015], "schleim_klauschleim": [6, 0.02]}


## Elite-Gegner je Welle (ab Welle 2) in Woche w.
static func flood_elites(week: int) -> int:
	return 0 if week < ELITE_WEEK else 1 + int((week - ELITE_WEEK) / 4)


## Flut-Gäste (Kapitel 11.4): ab Woche 3 eine Gastfamilie mit 25 %, ab Woche 10 zwei mit zusammen 40 %.
static func flood_guest_count(week: int) -> int:
	return 0 if week < 3 else (1 if week < 10 else 2)


static func flood_guest_share(week: int) -> float:
	return 0.0 if week < 3 else (0.25 if week < 10 else 0.4)

# ---------------------------------------------------------------- Spielerstufe
const MAX_LEVEL := 60
static func xp_need(level: int) -> int:
	return int(round(80.0 * pow(level, 1.6) / 10.0) * 10)

const LEVEL_UNLOCKS := {3: "Garage", 5: "Kiefernforst, Freunde", 8: "Clans", 10: "Staubebene", 16: "Schrottküste", 24: "Sumpfwerk", 34: "Frostpass", 45: "Schleimkrater", 55: "Vulkaninsel", 60: "Stadtruinen, Meister-Rang"}

## Kommandanten-Fähigkeiten: je Zweig fünf Fähigkeiten mit bis zu fünf Rängen. stat -> Wert je Rang.
const COMMANDER := [
	{"key": "builder", "name": "Baumeister", "skills": [
		{"key": "wall_hp", "name": "Dicke Mauern", "val": 0.06, "text": "+6 % Leben für Mauern"},
		{"key": "build_time", "name": "Schnelle Drohnen", "val": 0.04, "text": "−4 % Bauzeit"},
		{"key": "tower_dmg", "name": "Zielhilfe", "val": 0.03, "text": "+3 % Turmschaden"},
		{"key": "bunker_heal", "name": "Notfallplan", "val": 0.05, "text": "Bunker heilt einmal pro Flut 5 %"},
		{"key": "trap_dmg", "name": "Fallensteller", "val": 0.1, "text": "+10 % Fallenschaden"}]},
	{"key": "explorer", "name": "Entdecker", "skills": [
		{"key": "carry", "name": "Großer Rucksack", "val": 0.08, "text": "+8 % Tragemenge"},
		{"key": "fuel", "name": "Sparfuchs", "val": 0.05, "text": "−5 % Treibstoff"},
		{"key": "luck", "name": "Glückspilz", "val": 0.02, "text": "+2 % Chance auf bessere Stücke"},
		{"key": "loot", "name": "Spürnase", "val": 0.05, "text": "+5 % Rohstoffe aus Expeditionen"},
		{"key": "vehicle", "name": "Vollgas", "val": 0.05, "text": "+5 % Fahrzeugtempo"}]},
	{"key": "leader", "name": "Anführer", "skills": [
		{"key": "hero_hp", "name": "Abgehärtet", "val": 0.04, "text": "+4 % Heldenleben"},
		{"key": "reload", "name": "Schnelle Hände", "val": 0.04, "text": "−4 % Nachladezeit"},
		{"key": "hero_dmg", "name": "Scharfes Auge", "val": 0.03, "text": "+3 % Heldenschaden"},
		{"key": "cdr", "name": "Kühler Kopf", "val": 0.03, "text": "Fähigkeiten laden 3 % schneller"},
		{"key": "xp", "name": "Schnell gelernt", "val": 0.04, "text": "+4 % Erfahrung"}]},
]
const CMD_ACTIVES := {
	"airstrike": {"name": "Luftschlag", "cd": 90.0, "level": 4, "text": "Fünf Bomben auf die dichteste Gruppe"},
	"supply": {"name": "Versorgungskiste", "cd": 75.0, "level": 9, "text": "Heilt den Helden um 60 % und füllt die Waffe"},
	"barrier": {"name": "Schutzschirm", "cd": 120.0, "level": 15, "text": "Alle Gebäude nehmen 6 Sekunden keinen Schaden"},
	"backup": {"name": "Verstärkung", "cd": 120.0, "level": 22, "text": "Vier Siedler kämpfen 20 Sekunden mit"},
}
const CMD_ORDER := ["airstrike", "supply", "barrier", "backup"]

# ---------------------------------------------------------------- Waffen der Helden
## mode: hitscan | cone | proj | chain | swing | multi | homing
const WEAPONS := {
	"j_rifle": {"name": "Dienstgewehr", "kind": "Sturmgewehr", "hero": "jona", "damage": 9.0, "rpm": 420.0, "mag": 30, "reload": 1.8, "range": 16.0, "mode": "hitscan", "pierce": 1, "spread": 2.0, "sound": "w_rifle", "len": 0.9, "element": "kugel"},
	"j_parcel": {"name": "Postbote", "kind": "Paketwerfer", "hero": "jona", "damage": 30.0, "rpm": 70.0, "mag": 6, "reload": 2.2, "range": 16.0, "mode": "proj", "splash": 2.6, "knock": 2.5, "sound": "w_parcel", "len": 0.8, "element": "explosion"},
	"j_burst": {"name": "Sternbanner-Karabiner", "kind": "Salvengewehr", "hero": "jona", "damage": 12.0, "rpm": 480.0, "mag": 24, "reload": 1.9, "range": 18.0, "mode": "hitscan", "pierce": 0, "spread": 1.0, "mark_every": 3, "sound": "w_burst", "len": 1.0, "element": "kugel"},
	"m_flame": {"name": "Brenner", "kind": "Flammenwerfer", "hero": "mika", "damage": 3.5, "rpm": 900.0, "mag": 120, "reload": 2.6, "range": 6.5, "mode": "cone", "cone": 34.0, "burn": 3.0, "sound": "flame_loop", "len": 0.9, "element": "feuer"},
	"m_water": {"name": "Löschkanone", "kind": "Wasserwerfer", "hero": "mika", "damage": 1.5, "rpm": 900.0, "mag": 110, "reload": 2.4, "range": 8.5, "mode": "cone", "cone": 26.0, "knock": 1.6, "slow": 1.0, "water": true, "sound": "water_loop", "len": 0.9, "element": "wasser"},
	"m_fireball": {"name": "Feuerball-Schleuder", "kind": "Werfer", "hero": "mika", "damage": 20.0, "rpm": 60.0, "mag": 5, "reload": 2.4, "range": 15.0, "mode": "proj", "splash": 2.6, "zone": "fire", "zone_t": 3.0, "sound": "w_fireball", "len": 0.8, "element": "feuer"},
	"b_nailer": {"name": "Nagler", "kind": "Schrotkanone", "hero": "bruno", "damage": 6.0, "pellets": 8, "rpm": 75.0, "mag": 6, "reload": 2.2, "range": 8.5, "mode": "hitscan", "pierce": 0, "spread": 14.0, "knock": 1.0, "sound": "w_nailer", "len": 0.8, "element": "kugel"},
	"b_ball": {"name": "Abrissbirne", "kind": "Kettenkugel", "hero": "bruno", "damage": 22.0, "rpm": 110.0, "mag": 0, "reload": 0.0, "range": 3.4, "mode": "swing", "knock": 0.8, "sound": "w_ball_swing", "len": 0.5, "element": "kugel"},
	"b_cement": {"name": "Betonmischer", "kind": "Schwerer Werfer", "hero": "bruno", "damage": 26.0, "rpm": 50.0, "mag": 4, "reload": 2.8, "range": 14.0, "mode": "proj", "splash": 3.0, "root": 3.0, "sound": "w_cement", "len": 0.85, "element": "explosion"},
	"a_spark": {"name": "Funkenstab", "kind": "Blitzwerfer", "hero": "ada", "damage": 11.0, "rpm": 150.0, "mag": 20, "reload": 1.8, "range": 12.0, "mode": "chain", "chain": 3, "sound": "w_spark", "len": 0.9, "element": "blitz"},
	"a_shrink": {"name": "Schrumpfstrahl", "kind": "Strahlwaffe", "hero": "ada", "damage": 5.0, "rpm": 420.0, "mag": 60, "reload": 2.0, "range": 13.0, "mode": "hitscan", "pierce": 0, "spread": 0.0, "shrink": true, "beam": true, "sound": "w_shrink", "len": 0.8, "element": "blitz"},
	"a_cloud": {"name": "Wetterkanone", "kind": "Wolkenwerfer", "hero": "ada", "damage": 14.0, "rpm": 28.0, "mag": 3, "reload": 3.0, "range": 15.0, "mode": "proj", "splash": 0.0, "zone": "storm", "zone_t": 6.0, "sound": "w_cloud", "len": 0.9, "element": "blitz"},
	"y_rifle": {"name": "Weitblick", "kind": "Präzisionsgewehr", "hero": "yuki", "damage": 48.0, "rpm": 50.0, "mag": 5, "reload": 2.4, "range": 26.0, "mode": "hitscan", "pierce": 4, "spread": 0.0, "elite": true, "sound": "w_sniper", "len": 1.3, "element": "kugel"},
	"y_bow": {"name": "Federbogen", "kind": "Bogen", "hero": "yuki", "damage": 32.0, "rpm": 95.0, "mag": 12, "reload": 1.4, "range": 20.0, "mode": "hitscan", "pierce": 1, "spread": 0.5, "crit": 0.2, "arrow": true, "sound": "w_bow", "len": 0.7, "element": "kugel"},
	"y_swarm": {"name": "Schwarmpfeil", "kind": "Spezialbogen", "hero": "yuki", "damage": 24.0, "rpm": 60.0, "mag": 8, "reload": 2.0, "range": 18.0, "mode": "multi", "targets": 5, "arrow": true, "sound": "w_swarm", "len": 0.7, "element": "kugel"},
	"g_cracker": {"name": "Kracher", "kind": "Granatwerfer", "hero": "greta", "damage": 40.0, "rpm": 45.0, "mag": 4, "reload": 2.8, "range": 17.0, "mode": "proj", "splash": 3.0, "sound": "w_cracker", "len": 0.8, "element": "explosion"},
	"g_sparkler": {"name": "Wunderkerze", "kind": "Raketenstab", "hero": "greta", "damage": 28.0, "rpm": 100.0, "mag": 8, "reload": 2.4, "range": 18.0, "mode": "homing", "splash": 1.8, "sound": "w_sparkler", "len": 0.9, "element": "explosion"},
	"g_cake": {"name": "Tortenheber", "kind": "Kuchenwerfer", "hero": "greta", "damage": 18.0, "rpm": 50.0, "mag": 5, "reload": 2.4, "range": 15.0, "mode": "proj", "splash": 3.2, "slow": 3.0, "zone": "heal", "zone_t": 3.0, "sound": "w_cake", "len": 0.8, "element": "explosion"},
	# V4 Waffen-Arsenal: Jona
	"j_pistol": {"name": "Stempelpistole", "kind": "Pistole", "hero": "jona", "damage": 14.0, "rpm": 300.0, "mag": 12, "reload": 1.2, "range": 13.0, "mode": "hitscan", "pierce": 0, "spread": 1.5, "crit": 0.1, "pose": "pistol", "element": "kugel", "sound": "w_pistol", "sound_alt": "w_burst", "len": 0.55, "lvl": 3, "get": "craft", "text": "Handliche Dienstpistole, die jeden Treffer abstempelt.", "special": "+10 % Volltreffer-Chance"},
	"j_shotgun": {"name": "Eilbrief-Flinte", "kind": "Schrotflinte", "hero": "jona", "damage": 13.0, "rpm": 70.0, "mag": 5, "reload": 2.0, "range": 8.0, "mode": "hitscan", "pellets": 6, "pierce": 0, "spread": 12.0, "knock": 1.2, "recoil": 1.0, "pose": "heavy", "element": "kugel", "sound": "w_shotgun", "sound_alt": "w_nailer", "len": 0.85, "lvl": 5, "get": "find", "text": "Sechs Schrotkugeln auf einmal – und ein ordentlicher Rückstoß.", "special": "Rückstoß-Sprung: jeder Schuss schiebt Jona 1 m zurück"},
	"j_boomerang": {"name": "Rückschein-Bumerang", "kind": "Bumerang", "hero": "jona", "damage": 24.0, "rpm": 62.0, "mag": 0, "reload": 0.0, "range": 12.0, "mode": "bolt", "ret": true, "pierce": 99, "speed": 16.0, "spin": true, "pose": "toss", "element": "kugel", "sound": "w_boomerang", "sound_alt": "whoosh", "len": 0.5, "lvl": 11, "get": "both", "text": "Fliegt hinaus, trifft alles auf dem Weg und kommt zurück.", "special": "Kommt zurück: trifft auf Hin- und Rückweg"},
	"j_mortar": {"name": "Feldpost-Mörser", "kind": "Kleinmörser", "hero": "jona", "damage": 24.0, "rpm": 40.0, "mag": 4, "reload": 2.6, "range": 18.0, "mode": "proj", "splash": 1.8, "cluster": 4, "pose": "heavy", "element": "explosion", "sound": "w_mortar", "sound_alt": "t_mortar", "len": 0.8, "lvl": 13, "get": "craft", "text": "Verschickt ein Päckchen, das in vier Streubomben zerfällt.", "special": "Streubomben: 4 kleine Explosionen"},
	"j_smg": {"name": "Rohrpost-MP", "kind": "Maschinenpistole", "hero": "jona", "damage": 7.0, "rpm": 720.0, "mag": 40, "reload": 1.6, "range": 12.0, "mode": "hitscan", "pierce": 0, "spread": 5.0, "pose": "rifle", "element": "kugel", "sound": "w_smg", "sound_alt": "w_rifle", "len": 0.7, "lvl": 19, "get": "find", "text": "Rattert los wie die Rohrpost im Hauptamt.", "special": "Sehr hohe Feuerrate"},
	"j_mine": {"name": "Paketbombe", "kind": "Minenleger", "hero": "jona", "damage": 58.0, "rpm": 45.0, "mag": 5, "reload": 2.5, "range": 9.0, "mode": "mine", "splash": 2.8, "stun": 0.8, "mines": 6, "pose": "toss", "element": "explosion", "sound": "w_mine_drop", "sound_alt": "build_place", "len": 0.45, "lvl": 22, "get": "craft", "text": "Legt Pakete aus, die beim ersten Schleimling hochgehen.", "special": "Minen: bis zu 6 liegen bereit, betäuben 0,8 s"},
	"j_flare": {"name": "Signalpistole", "kind": "Leuchtpistole", "hero": "jona", "damage": 30.0, "rpm": 55.0, "mag": 3, "reload": 1.8, "range": 18.0, "mode": "proj", "splash": 2.2, "mark": 4.0, "zone": "fire", "zone_t": 3.0, "pose": "pistol", "areas": [1, 5], "element": "feuer", "sound": "w_flare", "sound_alt": "w_fireball", "len": 0.6, "lvl": 25, "get": "find", "text": "Schießt eine Leuchtkugel, die Gegner markiert und den Boden anzündet.", "special": "Markiert: getroffene Gegner nehmen 4 s lang +40 % Schaden"},
	"j_harpoon": {"name": "Ankerharpune", "kind": "Harpune", "hero": "jona", "damage": 66.0, "rpm": 50.0, "mag": 4, "reload": 2.2, "range": 16.0, "mode": "bolt", "pierce": 3, "speed": 30.0, "pull": 2.0, "pose": "rifle", "areas": [3], "element": "kugel", "sound": "w_harpoon", "sound_alt": "w_sniper", "len": 1.0, "lvl": 28, "get": "both", "text": "Ein Anker an der Leine – durchbohrt drei Gegner und zieht sie heran.", "special": "Durchschlag 3, zieht Gegner zu Jona"},
	"j_tesla": {"name": "Störsender", "kind": "Funkgerät", "hero": "jona", "damage": 22.0, "rpm": 140.0, "mag": 18, "reload": 2.0, "range": 13.0, "mode": "chain", "chain": 4, "stun_ch": 0.25, "stun": 1.0, "pose": "rifle", "areas": [3], "element": "blitz", "sound": "w_jammer", "sound_alt": "w_spark", "len": 0.8, "lvl": 31, "get": "find", "text": "Ein umgebautes Funkgerät, dessen Störfunk von Gegner zu Gegner springt.", "special": "Kettenblitz 4, 25 % Chance zu betäuben"},
	"j_turret": {"name": "Wachposten im Paket", "kind": "Geschütz", "hero": "jona", "damage": 1.0, "rpm": 6.0, "mag": 0, "reload": 0.0, "range": 7.0, "mode": "turret", "tower": "mg", "life": 18.0, "towers": 2, "power": 2.4, "pose": "toss", "element": "kugel", "sound": "w_turret_deploy", "sound_alt": "tower_spawn", "len": 0.5, "lvl": 34, "get": "craft", "text": "Ein Paket, aus dem ein MG-Turm springt.", "special": "Geschütz aufstellen: MG-Turm für 18 s, höchstens 2"},
	"j_rocket": {"name": "Expressrakete", "kind": "Raketenwerfer", "hero": "jona", "damage": 45.0, "rpm": 40.0, "mag": 6, "reload": 2.6, "range": 20.0, "mode": "seek", "splash": 2.0, "count": 3, "pose": "heavy", "areas": [5, 6], "element": "explosion", "sound": "w_rocket", "sound_alt": "t_rocket", "len": 1.0, "lvl": 37, "get": "find", "text": "Drei kleine Raketen suchen sich selbst ihre Empfänger.", "special": "Zielsuchend: 3 Raketen auf verschiedene Gegner"},
	"j_railgun": {"name": "Kapitänsbüchse", "kind": "Ladegewehr", "hero": "jona", "damage": 120.0, "rpm": 60.0, "mag": 6, "reload": 2.4, "range": 30.0, "mode": "charge", "charge": 1.2, "pierce": 8, "pose": "sniper", "element": "kugel", "sound": "w_rail", "sound_alt": "w_sniper", "len": 1.3, "lvl": 40, "get": "both", "text": "Lädt sich auf und schießt dann quer durch die ganze Horde.", "special": "Aufladen 1,2 s (halten = stärker), Durchschlag 8"},
	# V4 Waffen-Arsenal: Mika
	"m_axe": {"name": "Feuerwehraxt", "kind": "Axt", "hero": "mika", "damage": 20.0, "rpm": 90.0, "mag": 0, "reload": 0.0, "range": 3.2, "mode": "swing", "arc": 70.0, "burn": 2.0, "leech": 0.06, "pose": "melee", "element": "kugel", "sound": "w_axe", "sound_alt": "w_ball_swing", "len": 0.65, "lvl": 3, "get": "craft", "text": "Die rote Axt aus dem Löschzug – heiß geschliffen.", "special": "Setzt Gegner in Brand, 6 % Lebensraub"},
	"m_extinguisher": {"name": "Schaumlöscher", "kind": "Feuerlöscher", "hero": "mika", "damage": 3.0, "rpm": 900.0, "mag": 90, "reload": 2.2, "range": 6.0, "mode": "cone", "cone": 30.0, "slow": 2.0, "knock": 0.8, "water": true, "pose": "spray", "element": "wasser", "sound": "w_foam_loop", "sound_alt": "water_loop", "len": 0.7, "lvl": 5, "get": "find", "text": "Klebriger Schaum: Gegner rutschen und kommen kaum voran.", "special": "Verlangsamt stark (2 s)"},
	"m_hose": {"name": "Druckschlauch", "kind": "Wasserstrahl", "hero": "mika", "damage": 5.5, "rpm": 600.0, "mag": 100, "reload": 2.2, "range": 11.0, "mode": "beam", "knock": 0.6, "pierce": 1, "beam_col": "7FD3FF", "pose": "spray", "areas": [6], "element": "wasser", "sound": "w_jet_loop", "sound_alt": "water_loop", "len": 0.95, "lvl": 11, "get": "both", "text": "Ein harter Wasserstrahl, der Gegner zurückschiebt.", "special": "Strahl: Dauerschaden, schiebt zurück"},
	"m_molotov": {"name": "Brandflasche", "kind": "Wurfflasche", "hero": "mika", "damage": 20.0, "rpm": 55.0, "mag": 6, "reload": 2.2, "range": 13.0, "mode": "proj", "splash": 2.4, "zone": "fire", "zone_t": 4.0, "pose": "toss", "areas": [1, 5], "element": "feuer", "sound": "w_bottle", "sound_alt": "w_fireball", "len": 0.45, "lvl": 13, "get": "craft", "text": "Eine Flasche Lampenöl – fliegt im Bogen und brennt lange.", "special": "Brandfläche 4 s"},
	"m_halligan": {"name": "Brecheisen", "kind": "Hebelwerkzeug", "hero": "mika", "damage": 45.0, "rpm": 80.0, "mag": 0, "reload": 0.0, "range": 3.6, "mode": "thrust", "pierce": 3, "stun_ch": 0.3, "stun": 0.8, "pose": "spear", "element": "kugel", "sound": "w_thrust", "sound_alt": "w_ball_swing", "len": 1.0, "lvl": 19, "get": "find", "text": "Das Werkzeug zum Türenöffnen – stößt durch drei Gegner.", "special": "Stoß mit Durchschlag 3, 30 % Chance zu betäuben"},
	"m_napalm": {"name": "Glutwerfer", "kind": "Brandmörser", "hero": "mika", "damage": 22.0, "rpm": 40.0, "mag": 4, "reload": 2.6, "range": 15.0, "mode": "proj", "splash": 2.0, "cluster": 3, "zone": "fire", "zone_t": 2.5, "pose": "thrower", "areas": [1, 5], "element": "feuer", "sound": "w_mortar", "sound_alt": "w_fireball", "len": 0.85, "lvl": 22, "get": "find", "text": "Wirft Glutklumpen, die in drei Feuerstellen zerplatzen.", "special": "Streufeuer: 3 kleine Brandflächen"},
	"m_ice": {"name": "Kältelöscher", "kind": "CO₂-Löscher", "hero": "mika", "damage": 4.5, "rpm": 900.0, "mag": 100, "reload": 2.6, "range": 7.0, "mode": "cone", "cone": 34.0, "slow": 1.5, "freeze": 0.1, "frost": true, "pose": "spray", "areas": [4, 6], "element": "eis", "sound": "w_frost_loop", "sound_alt": "water_loop", "len": 0.75, "lvl": 25, "get": "craft", "text": "Eiskalter Nebel aus dem Kohlendioxid-Löscher.", "special": "Frost: verlangsamt, 10 % Chance je Stoß einzufrieren"},
	"m_ladder": {"name": "Leiterramme", "kind": "Leiter", "hero": "mika", "damage": 55.0, "rpm": 55.0, "mag": 0, "reload": 0.0, "range": 4.0, "mode": "swing", "arc": 120.0, "knock": 2.0, "pose": "hammer", "element": "kugel", "sound": "w_heavy_swing", "sound_alt": "w_ball_swing", "len": 1.1, "lvl": 28, "get": "both", "text": "Eine Feuerwehrleiter, quer durch die Reihen geschwungen.", "special": "Breiter Schwung (120°), starker Rückstoß"},
	"m_siren": {"name": "Sirenenhorn", "kind": "Schallkanone", "hero": "mika", "damage": 75.0, "rpm": 30.0, "mag": 0, "reload": 0.0, "range": 6.0, "mode": "nova", "stun": 1.2, "knock": 2.0, "pose": "staff", "element": "kugel", "sound": "w_siren", "sound_alt": "flood_horn", "len": 0.6, "lvl": 31, "get": "find", "text": "So laut, dass alle Gegner rundum taumeln.", "special": "Schallwelle rundum (6 m), betäubt 1,2 s"},
	"m_inferno": {"name": "Hitzestrahler", "kind": "Hitzestrahl", "hero": "mika", "damage": 8.0, "rpm": 600.0, "mag": 120, "reload": 2.4, "range": 9.0, "mode": "beam", "ramp": 0.6, "burn": 2.0, "pierce": 0, "beam_col": "FF8A1F", "pose": "spray", "areas": [1, 5], "element": "feuer", "sound": "w_heat_loop", "sound_alt": "flame_loop", "len": 0.9, "lvl": 34, "get": "craft", "text": "Ein gebündelter Hitzestrahl – je länger er auf einem Ziel bleibt, desto heißer.", "special": "Strahl: Schaden steigt beim Halten bis +60 %, setzt in Brand"},
	"m_hammer": {"name": "Brandmeister-Hammer", "kind": "Sprunghammer", "hero": "mika", "damage": 130.0, "rpm": 24.0, "mag": 0, "reload": 0.0, "range": 9.0, "mode": "slam", "splash": 3.2, "burn": 3.0, "pose": "hammer", "areas": [5], "element": "feuer", "sound": "w_slam", "sound_alt": "boss_slam", "len": 0.95, "lvl": 37, "get": "find", "text": "Mika springt ins Getümmel und schlägt einen Feuerring in den Boden.", "special": "Sprungangriff: Feuerring 3,2 m, setzt in Brand"},
	"m_dragon": {"name": "Drachenschlauch", "kind": "Feuerdrache", "hero": "mika", "damage": 30.0, "rpm": 36.0, "mag": 5, "reload": 2.8, "range": 18.0, "mode": "seek", "splash": 2.0, "count": 4, "zone": "fire", "zone_t": 1.5, "pose": "thrower", "areas": [5, 6], "element": "feuer", "sound": "w_dragon", "sound_alt": "w_fireball", "len": 0.9, "lvl": 40, "get": "both", "text": "Vier Feuerbälle schlängeln sich wie Drachen zu ihren Zielen.", "special": "Zielsuchend: 4 Feuerbälle mit kleinen Brandflächen"},
	# V4 Waffen-Arsenal: Bruno
	"b_shovel": {"name": "Spaten", "kind": "Schaufel", "hero": "bruno", "damage": 22.0, "rpm": 85.0, "mag": 0, "reload": 0.0, "range": 3.0, "mode": "swing", "arc": 90.0, "knock": 1.0, "pose": "melee", "element": "kugel", "sound": "w_shovel", "sound_alt": "w_ball_swing", "len": 0.75, "lvl": 3, "get": "craft", "text": "Ein ehrlicher Spaten. Schiebt Schleim beiseite.", "special": "Breiter Schwung (90°) mit Rückstoß"},
	"b_hammer": {"name": "Vorschlaghammer", "kind": "Hammer", "hero": "bruno", "damage": 42.0, "rpm": 55.0, "mag": 0, "reload": 0.0, "range": 3.2, "mode": "swing", "arc": 60.0, "stun_ch": 0.35, "stun": 1.0, "knock": 1.4, "pose": "hammer", "element": "kugel", "sound": "w_heavy_swing", "sound_alt": "w_ball_swing", "len": 0.85, "lvl": 5, "get": "find", "text": "Schwer, langsam, unaufhaltsam.", "special": "35 % Chance zu betäuben (1 s)"},
	"b_rivet": {"name": "Nietkanone", "kind": "Nietpistole", "hero": "bruno", "damage": 18.0, "rpm": 150.0, "mag": 16, "reload": 2.0, "range": 15.0, "mode": "bolt", "pierce": 1, "bounce": 2, "speed": 28.0, "pose": "heavy", "element": "kugel", "sound": "w_rivet", "sound_alt": "w_nailer", "len": 0.8, "lvl": 11, "get": "both", "text": "Glühende Nieten, die von Gegner zu Gegner springen.", "special": "Abpraller: springt zu 2 weiteren Gegnern"},
	"b_drill": {"name": "Bohrhammer", "kind": "Bohrer", "hero": "bruno", "damage": 11.0, "rpm": 360.0, "mag": 0, "reload": 0.0, "range": 3.0, "mode": "thrust", "pierce": 2, "pose": "spear", "areas": [2], "element": "kugel", "sound": "w_drill_loop", "sound_alt": "w_nailer", "len": 0.9, "lvl": 13, "get": "craft", "text": "Rattert sich durch alles, was vor dem Bohrer steht.", "special": "Schneller Stoß, Durchschlag 2"},
	"b_brick": {"name": "Ziegelschleuder", "kind": "Wurfschleuder", "hero": "bruno", "damage": 40.0, "rpm": 70.0, "mag": 6, "reload": 2.2, "range": 13.0, "mode": "proj", "splash": 1.6, "stun": 1.0, "pose": "toss", "areas": [2], "element": "explosion", "sound": "w_toss", "sound_alt": "w_cement", "len": 0.5, "lvl": 19, "get": "find", "text": "Ein Ziegel im hohen Bogen. Wer getroffen wird, sieht Sterne.", "special": "Betäubt 1 s im Umkreis"},
	"b_wrecker": {"name": "Baggerschaufel", "kind": "Schaufelarm", "hero": "bruno", "damage": 55.0, "rpm": 45.0, "mag": 0, "reload": 0.0, "range": 3.6, "mode": "swing", "arc": 180.0, "knock": 2.2, "leech": 0.04, "pose": "hammer", "element": "kugel", "sound": "w_heavy_swing", "sound_alt": "w_ball_swing", "len": 1.0, "lvl": 22, "get": "craft", "text": "Bertas kleine Schwester: ein Rundumschlag mit der Schaufel.", "special": "Rundumschlag (360°), 4 % Lebensraub"},
	"b_plate": {"name": "Rüttelplatte", "kind": "Stampfer", "hero": "bruno", "damage": 65.0, "rpm": 35.0, "mag": 0, "reload": 0.0, "range": 5.0, "mode": "nova", "stun": 0.8, "knock": 1.5, "pose": "hammer", "areas": [2, 4], "element": "explosion", "sound": "w_stomp", "sound_alt": "boss_slam", "len": 0.7, "lvl": 25, "get": "find", "text": "Bruno stampft – und der Boden bebt rundherum.", "special": "Erdstoß rundum (5 m), betäubt 0,8 s"},
	"b_crane": {"name": "Kranhaken", "kind": "Hakenwurf", "hero": "bruno", "damage": 40.0, "rpm": 55.0, "mag": 0, "reload": 0.0, "range": 13.0, "mode": "bolt", "ret": true, "pierce": 99, "pull": 1.6, "speed": 15.0, "spin": false, "pose": "toss", "element": "kugel", "sound": "w_chain", "sound_alt": "w_ball_swing", "len": 0.7, "lvl": 28, "get": "both", "text": "Wirft den Kranhaken aus und holt ihn mit allen Gegnern zurück.", "special": "Kommt zurück, zieht getroffene Gegner heran"},
	"b_turret": {"name": "Baustellen-Geschütz", "kind": "Geschütz", "hero": "bruno", "damage": 1.0, "rpm": 5.0, "mag": 0, "reload": 0.0, "range": 7.0, "mode": "turret", "tower": "cannon", "life": 20.0, "towers": 2, "power": 1.8, "pose": "toss", "element": "explosion", "sound": "w_turret_deploy", "sound_alt": "tower_spawn", "len": 0.5, "lvl": 31, "get": "craft", "text": "Eine Kanone auf Rädern, schnell aufgestellt.", "special": "Geschütz aufstellen: Kanone für 20 s, höchstens 2"},
	"b_tar": {"name": "Teerkocher", "kind": "Teerspritze", "hero": "bruno", "damage": 6.0, "rpm": 900.0, "mag": 100, "reload": 2.6, "range": 7.0, "mode": "cone", "cone": 30.0, "slow": 2.0, "burn": 2.0, "tar": true, "pose": "spray", "areas": [1, 5], "element": "feuer", "sound": "w_tar_loop", "sound_alt": "flame_loop", "len": 0.85, "lvl": 34, "get": "find", "text": "Heißer Straßenteer: klebt und brennt.", "special": "Verlangsamt und setzt in Brand"},
	"b_pile": {"name": "Rammbär", "kind": "Sprungramme", "hero": "bruno", "damage": 190.0, "rpm": 20.0, "mag": 0, "reload": 0.0, "range": 10.0, "mode": "slam", "splash": 3.5, "stun": 1.5, "pose": "hammer", "areas": [2, 6], "element": "explosion", "sound": "w_slam", "sound_alt": "boss_slam", "len": 1.0, "lvl": 37, "get": "find", "text": "Bruno springt mit dem Rammbär mitten in die Horde.", "special": "Sprungangriff: Erdbeben 3,5 m, betäubt 1,5 s"},
	"b_demolition": {"name": "Abrisskanone", "kind": "Sprengkanone", "hero": "bruno", "damage": 100.0, "rpm": 50.0, "mag": 4, "reload": 3.0, "range": 18.0, "mode": "charge", "charge": 1.0, "splash": 4.5, "shot": "proj", "pose": "heavy", "areas": [2, 6], "element": "explosion", "sound": "w_demolish", "sound_alt": "explosion_big", "len": 1.0, "lvl": 40, "get": "both", "text": "Lädt eine Abrissladung auf, die ganze Gruppen wegfegt.", "special": "Aufladen 1 s (halten = stärker), Explosion 4,5 m"},
	# V4 Waffen-Arsenal: Ada
	"a_zapper": {"name": "Taschenzapper", "kind": "Blitzpistole", "hero": "ada", "damage": 12.0, "rpm": 200.0, "mag": 16, "reload": 1.4, "range": 11.0, "mode": "chain", "chain": 2, "pose": "pistol", "element": "blitz", "sound": "w_zap", "sound_alt": "w_spark", "len": 0.55, "lvl": 3, "get": "craft", "text": "Klein, handlich, kribbelt ordentlich.", "special": "Kettenblitz 2"},
	"a_magnet": {"name": "Magnetwerfer", "kind": "Magnetscheibe", "hero": "ada", "damage": 18.0, "rpm": 110.0, "mag": 10, "reload": 1.8, "range": 14.0, "mode": "bolt", "pierce": 0, "bounce": 3, "speed": 22.0, "pose": "rifle", "element": "kugel", "sound": "w_disc", "sound_alt": "w_spark", "len": 0.8, "lvl": 5, "get": "find", "text": "Magnetische Scheiben, die von Gegner zu Gegner springen.", "special": "Abpraller: springt zu 3 weiteren Gegnern"},
	"a_laser": {"name": "Laserstrahl", "kind": "Strahlwaffe", "hero": "ada", "damage": 6.5, "rpm": 600.0, "mag": 90, "reload": 2.2, "range": 14.0, "mode": "beam", "ramp": 1.0, "leech": 0.03, "pierce": 0, "beam_col": "FF4D6D", "pose": "staff", "areas": [3], "element": "blitz", "sound": "w_laser_loop", "sound_alt": "w_shrink", "len": 0.85, "lvl": 11, "get": "both", "text": "Ein feiner roter Strahl – je länger, desto heißer.", "special": "Strahl: Schaden steigt beim Halten bis +100 %, 3 % Lebensraub"},
	"a_drone": {"name": "Pieps’ Cousin", "kind": "Geschützdrohne", "hero": "ada", "damage": 1.0, "rpm": 6.0, "mag": 0, "reload": 0.0, "range": 7.0, "mode": "turret", "tower": "mini", "life": 22.0, "towers": 2, "power": 1.6, "pose": "toss", "element": "blitz", "sound": "w_turret_deploy", "sound_alt": "sk_turret", "len": 0.5, "lvl": 13, "get": "craft", "text": "Ein kleiner Blitzturm zum Aufstellen.", "special": "Geschütz aufstellen: Blitzturm für 22 s, höchstens 2"},
	"a_coil": {"name": "Teslaspule", "kind": "Spule", "hero": "ada", "damage": 45.0, "rpm": 50.0, "mag": 0, "reload": 0.0, "range": 5.5, "mode": "nova", "slow": 1.5, "knock": 0.6, "pose": "staff", "areas": [3], "element": "blitz", "sound": "w_nova", "sound_alt": "t_tesla", "len": 0.6, "lvl": 19, "get": "find", "text": "Entlädt sich mit einem Knall in alle Richtungen.", "special": "Blitzring rundum (5,5 m), verlangsamt"},
	"a_freeze": {"name": "Frostkanone", "kind": "Kältestrahler", "hero": "ada", "damage": 20.0, "rpm": 180.0, "mag": 20, "reload": 2.0, "range": 14.0, "mode": "hitscan", "pierce": 0, "spread": 1.0, "chill": 2.0, "freeze": 0.15, "beam": true, "beam_col": "9FE8FF", "pose": "rifle", "areas": [4, 6], "element": "eis", "sound": "w_freeze", "sound_alt": "t_ice", "len": 0.9, "lvl": 22, "get": "craft", "text": "Schießt Eiskristalle. Wer zu viele abbekommt, friert ein.", "special": "Frost: verlangsamt 2 s, 15 % Chance einzufrieren"},
	"a_gravity": {"name": "Schwerkraftbombe", "kind": "Sogwerfer", "hero": "ada", "damage": 50.0, "rpm": 30.0, "mag": 3, "reload": 2.8, "range": 15.0, "mode": "proj", "splash": 3.0, "zone": "vortex", "zone_t": 3.0, "pose": "thrower", "areas": [4], "element": "blitz", "sound": "w_vortex", "sound_alt": "w_cloud", "len": 0.85, "lvl": 25, "get": "find", "text": "Eine Kugel, die alle Gegner in der Nähe zu sich zieht.", "special": "Sog: zieht Gegner 3 s lang zur Mitte"},
	"a_railgun": {"name": "Gaußkanone", "kind": "Ladekanone", "hero": "ada", "damage": 65.0, "rpm": 60.0, "mag": 5, "reload": 2.5, "range": 28.0, "mode": "charge", "charge": 1.0, "pierce": 10, "pose": "heavy", "areas": [3], "element": "blitz", "sound": "w_rail", "sound_alt": "w_sniper", "len": 1.2, "lvl": 28, "get": "both", "text": "Magnetspulen beschleunigen einen Bolzen auf irrsinnige Geschwindigkeit.", "special": "Aufladen 1 s (halten = stärker), Durchschlag 10"},
	"a_mine": {"name": "Haftmine", "kind": "Blitzmine", "hero": "ada", "damage": 85.0, "rpm": 50.0, "mag": 6, "reload": 2.4, "range": 10.0, "mode": "mine", "splash": 3.0, "stun": 1.2, "mines": 6, "pose": "toss", "element": "blitz", "sound": "w_mine_drop", "sound_alt": "mine_beep", "len": 0.45, "lvl": 31, "get": "craft", "text": "Klebt am Boden und wartet geduldig.", "special": "Minen: bis zu 6, betäuben 1,2 s"},
	"a_plasma": {"name": "Plasmawerfer", "kind": "Plasmakanone", "hero": "ada", "damage": 46.0, "rpm": 90.0, "mag": 10, "reload": 2.2, "range": 16.0, "mode": "bolt", "pierce": 0, "splash": 2.0, "speed": 20.0, "pose": "heavy", "areas": [3, 6], "element": "blitz", "sound": "w_plasma", "sound_alt": "w_shrink", "len": 1.0, "lvl": 34, "get": "find", "text": "Leuchtende Plasmakugeln, die beim Aufprall zerplatzen.", "special": "Explodiert beim Treffer (2 m)"},
	"a_swarm": {"name": "Mikrodrohnen", "kind": "Drohnenschwarm", "hero": "ada", "damage": 30.0, "rpm": 45.0, "mag": 6, "reload": 2.6, "range": 18.0, "mode": "seek", "splash": 1.4, "count": 5, "pose": "staff", "areas": [5, 6], "element": "blitz", "sound": "w_seek", "sound_alt": "t_rocket", "len": 0.7, "lvl": 37, "get": "find", "text": "Fünf winzige Drohnen stürzen sich auf verschiedene Ziele.", "special": "Zielsuchend: 5 Drohnen auf verschiedene Gegner"},
	"a_storm": {"name": "Gewittermacher", "kind": "Kettenstrahl", "hero": "ada", "damage": 9.0, "rpm": 600.0, "mag": 120, "reload": 2.4, "range": 13.0, "mode": "beam", "chain": 3, "pierce": 0, "beam_col": "B9A4FF", "pose": "staff", "areas": [3, 6], "element": "blitz", "sound": "w_storm_loop", "sound_alt": "w_spark", "len": 0.9, "lvl": 40, "get": "both", "text": "Ein Blitzstrahl, der zu drei weiteren Gegnern überspringt.", "special": "Strahl mit Kettenblitz 3"},
	# V4 Waffen-Arsenal: Yuki
	"y_sling": {"name": "Steinschleuder", "kind": "Schleuder", "hero": "yuki", "damage": 30.0, "rpm": 100.0, "mag": 10, "reload": 1.4, "range": 16.0, "mode": "bolt", "pierce": 0, "speed": 26.0, "stun_ch": 0.15, "stun": 0.8, "pose": "pistol", "element": "kugel", "sound": "w_sling", "sound_alt": "w_bow", "len": 0.55, "lvl": 3, "get": "craft", "text": "Ein flacher Bachkiesel trifft genauer, als man denkt.", "special": "15 % Chance zu betäuben"},
	"y_crossbow": {"name": "Federarmbrust", "kind": "Armbrust", "hero": "yuki", "damage": 34.0, "rpm": 70.0, "mag": 6, "reload": 1.8, "range": 20.0, "mode": "hitscan", "pierce": 2, "spread": 0.5, "arrow": true, "pose": "rifle", "element": "kugel", "sound": "w_crossbow", "sound_alt": "w_bow", "len": 0.8, "lvl": 5, "get": "find", "text": "Kurze Bolzen mit Falkenfedern.", "special": "Durchschlag 2"},
	"y_spear": {"name": "Windspeer", "kind": "Speer", "hero": "yuki", "damage": 42.0, "rpm": 75.0, "mag": 0, "reload": 0.0, "range": 4.2, "mode": "thrust", "pierce": 4, "knock": 1.2, "pose": "spear", "element": "kugel", "sound": "w_thrust", "sound_alt": "w_ball_swing", "len": 1.3, "lvl": 11, "get": "both", "text": "Ein leichter Speer, der wie der Wind durch die Reihen fährt.", "special": "Langer Stoß mit Durchschlag 4"},
	"y_boomerang": {"name": "Falkenbumerang", "kind": "Bumerang", "hero": "yuki", "damage": 22.0, "rpm": 65.0, "mag": 0, "reload": 0.0, "range": 14.0, "mode": "bolt", "ret": true, "pierce": 99, "speed": 17.0, "crit": 0.15, "spin": true, "pose": "toss", "element": "kugel", "sound": "w_boomerang", "sound_alt": "whoosh", "len": 0.5, "lvl": 13, "get": "craft", "text": "Geschnitzt wie ein Falkenflügel – kommt immer zurück.", "special": "Kommt zurück, +15 % Volltreffer-Chance"},
	"y_blowpipe": {"name": "Giftpfeil-Blasrohr", "kind": "Blasrohr", "hero": "yuki", "damage": 40.0, "rpm": 130.0, "mag": 8, "reload": 1.6, "range": 18.0, "mode": "hitscan", "pierce": 0, "spread": 0.5, "poison": 6.0, "arrow": true, "pose": "rifle", "areas": [3], "element": "gift", "sound": "w_blowpipe", "sound_alt": "w_bow", "len": 0.9, "lvl": 19, "get": "find", "text": "Ein langes Rohr und Pfeile mit Sumpfgift.", "special": "Vergiftet 6 s"},
	"y_fan": {"name": "Sturmfächer", "kind": "Windfächer", "hero": "yuki", "damage": 5.0, "rpm": 600.0, "mag": 60, "reload": 2.0, "range": 7.0, "mode": "cone", "cone": 50.0, "knock": 2.6, "slow": 1.0, "wind": true, "pose": "pistol", "element": "kugel", "sound": "w_wind_loop", "sound_alt": "whoosh", "len": 0.6, "lvl": 22, "get": "craft", "text": "Ein Fächer aus Federn, der echte Sturmböen macht.", "special": "Bläst Gegner weit weg und bremst sie"},
	"y_frostbow": {"name": "Frostbogen", "kind": "Bogen", "hero": "yuki", "damage": 36.0, "rpm": 85.0, "mag": 10, "reload": 1.6, "range": 20.0, "mode": "hitscan", "pierce": 1, "spread": 0.5, "chill": 2.0, "freeze": 0.2, "arrow": true, "pose": "bow", "areas": [4, 6], "element": "eis", "sound": "w_bow_ice", "sound_alt": "w_bow", "len": 0.75, "lvl": 25, "get": "find", "text": "Pfeile mit Eisspitzen vom Frostpass.", "special": "Frost: verlangsamt 2 s, 20 % Chance einzufrieren"},
	"y_rain": {"name": "Pfeilregen", "kind": "Salvenbogen", "hero": "yuki", "damage": 40.0, "rpm": 40.0, "mag": 4, "reload": 2.4, "range": 20.0, "mode": "proj", "splash": 1.4, "cluster": 6, "rain": true, "pose": "bow", "element": "kugel", "sound": "w_arrow_rain", "sound_alt": "w_swarm", "len": 0.75, "lvl": 28, "get": "both", "text": "Ein Pfeil in den Himmel – sechs kommen herunter.", "special": "Pfeilregen: 6 Einschläge"},
	"y_hawk": {"name": "Kikos Krallen", "kind": "Falkenruf", "hero": "yuki", "damage": 70.0, "rpm": 40.0, "mag": 4, "reload": 2.2, "range": 22.0, "mode": "seek", "splash": 1.0, "count": 2, "elite": true, "pose": "toss", "element": "kugel", "sound": "w_hawk", "sound_alt": "bird_flap", "len": 0.5, "lvl": 31, "get": "craft", "text": "Kikos Geschwister stoßen auf zwei Gegner herab.", "special": "Zielsuchend: 2 Falken, bevorzugen starke Gegner"},
	"y_longbow": {"name": "Großer Kranichbogen", "kind": "Langbogen", "hero": "yuki", "damage": 75.0, "rpm": 60.0, "mag": 6, "reload": 2.0, "range": 30.0, "mode": "charge", "charge": 0.9, "pierce": 6, "crit": 0.25, "arrow": true, "pose": "bow", "areas": [5], "element": "kugel", "sound": "w_longbow", "sound_alt": "w_bow", "len": 0.85, "lvl": 34, "get": "find", "text": "So lang wie Yuki selbst. Gespannt trifft er durch alles.", "special": "Aufladen 0,9 s (halten = stärker), Durchschlag 6, +25 % Volltreffer"},
	"y_stars": {"name": "Federsterne", "kind": "Wurfsterne", "hero": "yuki", "damage": 16.0, "rpm": 120.0, "mag": 12, "reload": 1.8, "range": 15.0, "mode": "bolt", "pierce": 0, "bounce": 2, "count": 3, "fan": 14.0, "speed": 24.0, "spin": true, "pose": "toss", "areas": [6], "element": "kugel", "sound": "w_star", "sound_alt": "whoosh", "len": 0.45, "lvl": 37, "get": "find", "text": "Drei Wurfsterne im Fächer, die von Gegner zu Gegner springen.", "special": "3 Sterne im Fächer, Abpraller 2"},
	"y_tornado": {"name": "Wirbelsturmbogen", "kind": "Sturmbogen", "hero": "yuki", "damage": 60.0, "rpm": 40.0, "mag": 4, "reload": 2.4, "range": 20.0, "mode": "proj", "splash": 2.6, "zone": "vortex", "zone_t": 3.0, "pose": "bow", "areas": [5, 6], "element": "kugel", "sound": "w_vortex", "sound_alt": "w_swarm", "len": 0.8, "lvl": 40, "get": "both", "text": "Ein Pfeil, der einen kleinen Wirbelsturm entfacht.", "special": "Sog: zieht Gegner 3 s lang in den Wirbel"},
	# V4 Waffen-Arsenal: Greta
	"g_popper": {"name": "Partyknaller", "kind": "Konfettiflinte", "hero": "greta", "damage": 14.0, "rpm": 80.0, "mag": 6, "reload": 1.8, "range": 7.0, "mode": "hitscan", "pellets": 5, "pierce": 0, "spread": 18.0, "stun_ch": 0.1, "stun": 0.8, "confetti": true, "pose": "pistol", "element": "explosion", "sound": "w_popper", "sound_alt": "pop_small", "len": 0.55, "lvl": 3, "get": "craft", "text": "Konfetti mit Wumms!", "special": "5 Ladungen auf einmal, 10 % Chance zu betäuben"},
	"g_balloon": {"name": "Wasserbomben", "kind": "Ballonwerfer", "hero": "greta", "damage": 28.0, "rpm": 60.0, "mag": 6, "reload": 2.0, "range": 14.0, "mode": "proj", "splash": 2.2, "slow": 2.0, "pose": "toss", "areas": [0, 6], "element": "wasser", "sound": "w_balloon", "sound_alt": "splash", "len": 0.45, "lvl": 5, "get": "find", "text": "Bunte Luftballons voller Bachwasser.", "special": "Verlangsamt im Umkreis 2 s"},
	"g_roman": {"name": "Römische Kerze", "kind": "Feuerwerksrohr", "hero": "greta", "damage": 12.0, "rpm": 240.0, "mag": 12, "reload": 2.4, "range": 16.0, "mode": "bolt", "pierce": 0, "splash": 1.2, "speed": 18.0, "pose": "rifle", "areas": [2], "element": "explosion", "sound": "w_roman", "sound_alt": "w_sparkler", "len": 0.9, "lvl": 11, "get": "both", "text": "Bunte Kugeln, eine nach der anderen. Jede zerplatzt.", "special": "Kugeln explodieren beim Treffer (1,2 m)"},
	"g_pinata": {"name": "Piñata-Bombe", "kind": "Überraschungsmine", "hero": "greta", "damage": 50.0, "rpm": 50.0, "mag": 5, "reload": 2.4, "range": 9.0, "mode": "mine", "splash": 3.0, "slow": 2.5, "mines": 5, "pose": "toss", "element": "explosion", "sound": "w_mine_drop", "sound_alt": "pop_big", "len": 0.5, "lvl": 13, "get": "craft", "text": "Ein Esel aus Pappe. Wer ihn anstupst, bekommt Bonbons ab.", "special": "Minen: bis zu 5, kleben Gegner fest (Verlangsamen)"},
	"g_umbrella": {"name": "Omas Regenschirm", "kind": "Schirm", "hero": "greta", "damage": 36.0, "rpm": 80.0, "mag": 0, "reload": 0.0, "range": 3.4, "mode": "swing", "arc": 90.0, "knock": 1.6, "leech": 0.08, "pose": "melee", "element": "kugel", "sound": "w_umbrella", "sound_alt": "w_ball_swing", "len": 0.9, "lvl": 19, "get": "find", "text": "Der gute Schirm mit dem Entenkopf.", "special": "Schwung mit Rückstoß, 8 % Lebensraub"},
	"g_battery": {"name": "Raketenbatterie", "kind": "Raketenkiste", "hero": "greta", "damage": 30.0, "rpm": 30.0, "mag": 4, "reload": 2.8, "range": 18.0, "mode": "seek", "splash": 1.2, "count": 6, "pose": "heavy", "areas": [2], "element": "explosion", "sound": "w_seek", "sound_alt": "w_sparkler", "len": 0.7, "lvl": 22, "get": "craft", "text": "Sechs kleine Raketen auf einmal. Zündschnur nicht vergessen!", "special": "Zielsuchend: 6 Raketen"},
	"g_kettle": {"name": "Dampfkessel", "kind": "Teekessel", "hero": "greta", "damage": 5.0, "rpm": 900.0, "mag": 100, "reload": 2.4, "range": 6.5, "mode": "cone", "cone": 36.0, "burn": 2.0, "steam": true, "pose": "spray", "areas": [5], "element": "feuer", "sound": "w_steam_loop", "sound_alt": "flame_loop", "len": 0.6, "lvl": 25, "get": "find", "text": "Omas Teekessel – kocht seit vierzig Jahren.", "special": "Brühend heißer Dampf, setzt in Brand"},
	"g_wheel": {"name": "Feuerrad", "kind": "Wurfrad", "hero": "greta", "damage": 36.0, "rpm": 60.0, "mag": 0, "reload": 0.0, "range": 12.0, "mode": "bolt", "ret": true, "pierce": 99, "burn": 2.0, "speed": 15.0, "spin": true, "pose": "toss", "areas": [1], "element": "feuer", "sound": "w_wheel", "sound_alt": "w_sparkler", "len": 0.5, "lvl": 28, "get": "both", "text": "Ein sprühendes Feuerrad, das hin und zurück rollt.", "special": "Kommt zurück, setzt in Brand"},
	"g_candy": {"name": "Bonbonkanone", "kind": "Zuckerkanone", "hero": "greta", "damage": 26.0, "rpm": 200.0, "mag": 20, "reload": 2.0, "range": 15.0, "mode": "hitscan", "pierce": 0, "spread": 2.0, "chill": 1.5, "candy": true, "pose": "rifle", "element": "kugel", "sound": "w_candy", "sound_alt": "pop_small", "len": 0.85, "lvl": 31, "get": "craft", "text": "Harte Bonbons, die alles verkleben.", "special": "Klebt: verlangsamt 1,5 s"},
	"g_bigrocket": {"name": "Neujahrsrakete", "kind": "Großrakete", "hero": "greta", "damage": 150.0, "rpm": 40.0, "mag": 3, "reload": 3.0, "range": 20.0, "mode": "charge", "charge": 1.2, "splash": 5.0, "shot": "proj", "pose": "heavy", "areas": [2, 6], "element": "explosion", "sound": "w_bigrocket", "sound_alt": "t_rocket", "len": 1.0, "lvl": 34, "get": "find", "text": "Die größte Rakete aus Omas Keller. Erst zünden, dann staunen.", "special": "Aufladen 1,2 s (halten = stärker), Explosion 5 m"},
	"g_disco": {"name": "Diskokugel", "kind": "Glitzerkugel", "hero": "greta", "damage": 85.0, "rpm": 30.0, "mag": 0, "reload": 0.0, "range": 7.0, "mode": "nova", "stun": 1.0, "knock": 0.4, "pose": "staff", "areas": [3], "element": "blitz", "sound": "w_disco", "sound_alt": "t_tesla", "len": 0.6, "lvl": 37, "get": "find", "text": "Glitzerlicht in alle Richtungen – alle müssen tanzen.", "special": "Lichtring rundum (7 m), betäubt 1 s"},
	"g_finale": {"name": "Großes Finale", "kind": "Feuerwerksbatterie", "hero": "greta", "damage": 55.0, "rpm": 30.0, "mag": 3, "reload": 3.0, "range": 20.0, "mode": "proj", "splash": 2.0, "cluster": 8, "pose": "heavy", "areas": [6], "element": "explosion", "sound": "w_finale", "sound_alt": "w_cracker", "len": 0.9, "lvl": 40, "get": "both", "text": "Der Höhepunkt jedes Talfestes: acht Explosionen in allen Farben.", "special": "Streufeuerwerk: 8 Explosionen"},
	# V6 Paket H: Nele, die Taucherin (drei Startwaffen, zwölf weitere)
	"n_harpoon": {"name": "Tauchharpune", "kind": "Harpunengewehr", "hero": "nele", "damage": 34.0, "rpm": 75.0, "mag": 6, "reload": 1.8, "range": 16.0, "mode": "bolt", "pierce": 2, "speed": 30.0, "pull": 0.8, "pose": "rifle", "element": "kugel", "sound": "w_harpoon", "len": 0.95},
	"n_bubble": {"name": "Blubberkanone", "kind": "Blasenwerfer", "hero": "nele", "damage": 24.0, "rpm": 80.0, "mag": 8, "reload": 2.0, "range": 14.0, "mode": "proj", "splash": 2.4, "slow": 2.0, "pose": "thrower", "element": "wasser", "sound": "w_bubble", "len": 0.85},
	"n_ice": {"name": "Eisharpune", "kind": "Frostharpune", "hero": "nele", "damage": 36.0, "rpm": 120.0, "mag": 10, "reload": 2.0, "range": 18.0, "mode": "hitscan", "pierce": 1, "spread": 0.5, "chill": 2.0, "freeze": 0.12, "arrow": true, "beam_col": "BFF2FF", "pose": "rifle", "element": "eis", "sound": "w_ice_harpoon", "len": 1.0},
	"n_shell": {"name": "Muschelschleuder", "kind": "Schleuder", "hero": "nele", "damage": 20.0, "rpm": 110.0, "mag": 10, "reload": 1.5, "range": 15.0, "mode": "bolt", "pierce": 0, "bounce": 1, "speed": 24.0, "pose": "pistol", "element": "kugel", "sound": "w_sling", "sound_alt": "w_bow", "len": 0.55, "lvl": 3, "get": "craft", "text": "Flache Muscheln vom Strand, die von Gegner zu Gegner hüpfen.", "special": "Abpraller: springt zu einem weiteren Gegner"},
	"n_squid": {"name": "Tintenspritze", "kind": "Tintenwerfer", "hero": "nele", "damage": 3.0, "rpm": 900.0, "mag": 100, "reload": 2.2, "range": 7.0, "mode": "cone", "cone": 32.0, "slow": 2.0, "ink": true, "pose": "spray", "areas": [3], "element": "wasser", "sound": "w_ink_loop", "sound_alt": "water_loop", "len": 0.7, "lvl": 5, "get": "find", "text": "Eine Spritze voll Tintenfischtinte. Wer sie abbekommt, sieht nichts und tappt langsam herum.", "special": "Tintenwolke: verlangsamt stark (2 s)"},
	"n_anchor": {"name": "Bootsanker", "kind": "Ankerwurf", "hero": "nele", "damage": 26.0, "rpm": 58.0, "mag": 0, "reload": 0.0, "range": 13.0, "mode": "bolt", "ret": true, "pierce": 99, "pull": 1.4, "speed": 15.0, "spin": true, "pose": "toss", "areas": [3], "element": "kugel", "sound": "w_chain", "sound_alt": "w_ball_swing", "len": 0.5, "lvl": 11, "get": "both", "text": "Der kleine Anker vom Rettungsboot – an der Leine hinaus und mit allen Gegnern zurück.", "special": "Kommt zurück, zieht getroffene Gegner heran"},
	"n_torpedo": {"name": "Mini-Torpedo", "kind": "Torpedowerfer", "hero": "nele", "damage": 40.0, "rpm": 45.0, "mag": 6, "reload": 2.4, "range": 20.0, "mode": "seek", "splash": 1.8, "count": 2, "pose": "heavy", "areas": [3, 4], "element": "explosion", "sound": "w_torpedo", "sound_alt": "t_rocket", "len": 0.95, "lvl": 13, "get": "craft", "text": "Zwei kleine Torpedos, die sich ihre Ziele selbst suchen.", "special": "Zielsuchend: 2 Torpedos auf verschiedene Gegner"},
	"n_trident": {"name": "Dreizack", "kind": "Speer", "hero": "nele", "damage": 44.0, "rpm": 75.0, "mag": 0, "reload": 0.0, "range": 4.0, "mode": "thrust", "pierce": 3, "knock": 1.0, "pose": "spear", "areas": [3, 4], "element": "wasser", "sound": "w_thrust", "sound_alt": "w_ball_swing", "len": 1.25, "lvl": 19, "get": "find", "text": "Ein Fischer-Dreizack aus dem Wrack – stößt durch drei Gegner.", "special": "Stoß mit Durchschlag 3"},
	"n_geyser": {"name": "Geysirpumpe", "kind": "Wasserstrahl", "hero": "nele", "damage": 8.5, "rpm": 600.0, "mag": 100, "reload": 2.2, "range": 12.0, "mode": "beam", "knock": 0.8, "pierce": 1, "beam_col": "4FD8FF", "pose": "spray", "areas": [4], "element": "wasser", "sound": "w_jet_loop", "sound_alt": "water_loop", "len": 0.95, "lvl": 22, "get": "craft", "text": "Eine Lenzpumpe, die einen Geysir aus der Düse schießt.", "special": "Strahl: Dauerschaden, schiebt zurück"},
	"n_frostnet": {"name": "Frostnetz", "kind": "Netzwerfer", "hero": "nele", "damage": 55.0, "rpm": 50.0, "mag": 4, "reload": 2.4, "range": 14.0, "mode": "proj", "splash": 2.8, "root": 2.0, "pose": "thrower", "areas": [5], "element": "eis", "sound": "w_net", "sound_alt": "w_cement", "len": 0.85, "lvl": 25, "get": "find", "text": "Ein vereistes Fischernetz, das ganze Gruppen festhält.", "special": "Hält Gegner 2 s fest (Fläche 2,8 m)"},
	"n_whirl": {"name": "Strudelbombe", "kind": "Sogwerfer", "hero": "nele", "damage": 60.0, "rpm": 30.0, "mag": 3, "reload": 2.8, "range": 15.0, "mode": "proj", "splash": 3.0, "zone": "vortex", "zone_t": 3.0, "pose": "thrower", "areas": [4, 6], "element": "wasser", "sound": "w_vortex", "sound_alt": "w_bubble", "len": 0.85, "lvl": 28, "get": "both", "text": "Eine Flasche Meerwasser, die beim Aufprall zum Strudel wird.", "special": "Sog: zieht Gegner 3 s lang zur Mitte"},
	"n_jelly": {"name": "Quallenmine", "kind": "Blitzmine", "hero": "nele", "damage": 80.0, "rpm": 50.0, "mag": 6, "reload": 2.4, "range": 10.0, "mode": "mine", "splash": 3.0, "stun": 1.0, "mines": 6, "pose": "toss", "areas": [3, 6], "element": "blitz", "sound": "w_mine_drop", "sound_alt": "w_spark", "len": 0.45, "lvl": 31, "get": "craft", "text": "Eine leuchtende Qualle aus Glas. Wer drauftritt, bekommt einen Schlag.", "special": "Minen: bis zu 6, betäuben 1 s"},
	"n_icebreaker": {"name": "Eisbrecher", "kind": "Eispickel", "hero": "nele", "damage": 170.0, "rpm": 22.0, "mag": 0, "reload": 0.0, "range": 9.0, "mode": "slam", "splash": 3.2, "chill": 2.0, "pose": "hammer", "areas": [5], "element": "eis", "sound": "w_slam", "sound_alt": "t_ice", "len": 0.95, "lvl": 34, "get": "find", "text": "Nele springt mit dem Eispickel in die Horde und bricht das Eis.", "special": "Sprungangriff: Eisring 3,2 m, verlangsamt 2 s"},
	"n_kraken": {"name": "Krakenruf", "kind": "Muschelhorn", "hero": "nele", "damage": 42.0, "rpm": 40.0, "mag": 5, "reload": 2.6, "range": 18.0, "mode": "seek", "splash": 1.4, "count": 4, "pose": "staff", "areas": [6], "element": "wasser", "sound": "w_kraken", "sound_alt": "w_seek", "len": 0.7, "lvl": 37, "get": "find", "text": "Ein Ruf ins Muschelhorn – vier Wasserarme schnellen aus dem Boden.", "special": "Zielsuchend: 4 Wasserarme auf verschiedene Gegner"},
	"n_tsunami": {"name": "Flutwelle", "kind": "Wellenkanone", "hero": "nele", "damage": 95.0, "rpm": 60.0, "mag": 5, "reload": 2.5, "range": 18.0, "mode": "charge", "charge": 1.1, "splash": 4.0, "shot": "proj", "knock": 2.0, "pose": "heavy", "areas": [5, 6], "element": "wasser", "sound": "w_wave", "sound_alt": "explosion_big", "len": 1.0, "lvl": 40, "get": "both", "text": "Lädt eine ganze Welle auf und lässt sie auf die Horde krachen.", "special": "Aufladen 1,1 s (halten = stärker), Welle 4 m"},
}
const WEAPON_UNLOCK_LEVELS := [1, 8, 16]

# ---------------------------------------------------------------- V4 Waffen-Arsenal: Herkunft, Texte, Herstellen
## Jede Waffe (außer den drei Startwaffen je Held) trägt lvl (ab Heldenstufe), get (craft = herstellen mit Bauplan,
## find = Beute, both = beides), text (Beschreibung), special (Besonderheit), pose (Haltung, humanoid.gd) und optional
## areas (Gebiete, in denen sie bevorzugt gefunden wird; sonst nach Stufe). Neue Schussarten: bolt (sichtbares Geschoss,
## ret = Bumerang, bounce = Abpraller), beam (Strahl), charge (Aufladen), thrust (Stoß), slam (Sprungangriff), nova
## (Ring um den Helden), mine (Minen legen), turret (Geschütz aufstellen), seek (zielsuchende Geschosse). Wirkungen beim
## Treffer: burn, poison, chill (verlangsamen), freeze / stun_ch (betäuben), leech (Lebensraub), pull, recoil, crit.
const WEAPON_INFO := {
	"j_rifle": ["Das treue Dienstgewehr aus dem Bunker.", "Durchschlag 1"],
	"j_parcel": ["Verschickt Pakete mit Knalleffekt.", "Explosion (2,6 m) mit Rückstoß"],
	"j_burst": ["Schnelle Salven unter dem Sternenbanner.", "Jeder dritte Schuss markiert (+40 % Schaden)"],
	"m_flame": ["Mikas umgebauter Löschschlauch – in die andere Richtung.", "Flammenkegel, setzt in Brand"],
	"m_water": ["Ein kräftiger Wasserstrahl.", "Kegel, verlangsamt und schiebt zurück"],
	"m_fireball": ["Schleudert Feuerbälle im hohen Bogen.", "Explosion mit Brandfläche"],
	"b_nailer": ["Acht Nägel auf einen Streich.", "Schrot mit Rückstoß"],
	"b_ball": ["Die Abrissbirne an der Kette.", "Nahkampf-Schwung, trifft bis zu 10 Gegner"],
	"b_cement": ["Frischer Beton, der Gegner festhält.", "Explosion, hält Gegner 3 s fest"],
	"a_spark": ["Ein Stab voller Blitze.", "Kettenblitz 3"],
	"a_shrink": ["Macht Gegner klein und verwundbar.", "Geschrumpfte Gegner nehmen +30 % Schaden"],
	"a_cloud": ["Verschießt eine kleine Gewitterwolke.", "Gewitterfläche 6 s"],
	"y_rifle": ["Präzisionsgewehr für weite Schüsse.", "Durchschlag 4, zielt auf starke Gegner"],
	"y_bow": ["Ein leichter Bogen mit Falkenfedern.", "Durchschlag 1, +20 % Volltreffer-Chance"],
	"y_swarm": ["Fünf Pfeile auf einmal.", "Trifft 5 Gegner gleichzeitig"],
	"g_cracker": ["Omas Kracher aus dem Keller.", "Große Explosion (3 m)"],
	"g_sparkler": ["Eine Rakete am Stiel, die ihr Ziel findet.", "Zielsuchende Rakete"],
	"g_cake": ["Torte mit Sahne – für Freund und Feind.", "Verlangsamt, Heilfläche für Greta"],
	"n_harpoon": ["Die Harpune aus Neles Tauchschule.", "Durchschlag 2, zieht Gegner etwas heran"],
	"n_bubble": ["Dicke Seifenblasen voller Meerwasser.", "Platzen im Umkreis (2,4 m), verlangsamen 2 s"],
	"n_ice": ["Harpunenpfeile mit Eisspitze.", "Frost: verlangsamt 2 s, 12 % Chance einzufrieren"],
}
const WEAPON_GET_NAME := {"start": "Startwaffe", "craft": "Herstellen", "find": "Fund", "both": "Fund oder Herstellen"}
const WEAPON_MODE_NAME := {"hitscan": "Schuss", "proj": "Bogenwurf", "homing": "Zielsuchend", "chain": "Kettenblitz", "swing": "Nahkampf",
	"multi": "Mehrfachschuss", "cone": "Kegel", "bolt": "Geschoss", "beam": "Strahl", "charge": "Aufladen", "thrust": "Stoß",
	"slam": "Sprungangriff", "nova": "Rundumschlag", "mine": "Minen", "turret": "Geschütz", "seek": "Zielsuchend"}
## Fundquellen: Chance auf eine Waffe oder einen Bauplan je Ereignis
const ARSENAL_DROP := {"exp_chest": 0.35, "exp_nest": 0.2, "exp_bounty": 1.0, "exp_rescue": 0.5, "exp_race": 0.5, "boss_first": 1.0,
	"chest": 0.1, "chest_boss": 0.45, "chest_flood_gold": 0.3, "chest_flood_silver": 0.18, "chest_level": 0.2, "achievement": 1.0}
const BLUEPRINT_SHARE := 0.55        # Anteil Baupläne bei Waffen, die sich herstellen lassen ("both")


## Ab welcher Heldenstufe eine Waffe benutzt werden kann.
static func weapon_level(key: String) -> int:
	var w: Dictionary = WEAPONS[key]
	if w.has("lvl"):
		return int(w.lvl)
	var i: int = (HEROES[w.hero].weapons as Array).find(key)
	return int(WEAPON_UNLOCK_LEVELS[maxi(i, 0)])


## Wie man eine Waffe bekommt: start | craft | find | both.
static func weapon_get(key: String) -> String:
	return String(WEAPONS[key].get("get", "start"))


static func weapon_text(key: String) -> String:
	var w: Dictionary = WEAPONS[key]
	return String(w.get("text", WEAPON_INFO.get(key, ["", ""])[0]))


static func weapon_special(key: String) -> String:
	var w: Dictionary = WEAPONS[key]
	return String(w.get("special", WEAPON_INFO.get(key, ["", ""])[1]))


static var _hw_cache := {}

## Alle Waffen eines Helden, nach Freischalt-Stufe sortiert (die drei Startwaffen zählen mit).
static func hero_weapons(hk: String) -> Array:
	if _hw_cache.has(hk):
		return _hw_cache[hk]
	var out: Array = []
	for k in WEAPONS:
		if String(WEAPONS[k].hero) == hk:
			out.append(k)
	out.sort_custom(func(a, b): return weapon_level(a) < weapon_level(b) or (weapon_level(a) == weapon_level(b) and String(a) < String(b)))
	_hw_cache[hk] = out
	return out


## Gebiete (0..6), in denen eine Waffe als Beute vorkommt: Angabe areas, sonst das Gebiet passend zur Stufe.
static func weapon_areas(key: String) -> Array:
	var w: Dictionary = WEAPONS[key]
	if w.has("areas"):
		return w.areas
	var lv := weapon_level(key)
	var a := 0
	for i in AREA_HERO_LEVEL.size():
		if lv >= int(AREA_HERO_LEVEL[i]):
			a = i
	return [a]


## Kosten zum Herstellen (Bauplan nötig).
static func craft_cost(key: String) -> Dictionary:
	var lv := weapon_level(key)
	var c := {"coins": 150 + 60 * lv, "parts": 4 + lv}
	if lv >= 5:
		c["metal"] = 10 * lv
	if lv >= 20:
		c["cells"] = lv
	if lv >= 30:
		c["shards"] = lv - 28
	return c


## Kampfwert zum Abgleich der Stufen: anhaltender Schaden je Sekunde gegen ein Ziel, mit Zuschlag für Flächen,
## Durchschlag, Ketten und Abpraller (ohne Seltenheit, Stufe und Talente). Geschütze: -1.
static func weapon_power(key: String) -> float:
	var d: Dictionary = WEAPONS[key]
	var m := String(d.mode)
	if m == "turret":
		return -1.0
	var k := 1.0
	if float(d.get("splash", 0.0)) > 0.0:
		k *= 1.0 + 0.35 * float(d.splash)
	if m == "nova":
		k *= 1.0 + 0.3 * float(d.range)
	if String(d.get("zone", "")) == "vortex":
		k *= 1.3
	if String(d.get("zone", "")) == "fire":
		k *= 1.25
	if int(d.get("pierce", 0)) >= 2:
		k *= 1.0 + 0.15 * mini(int(d.pierce), 6)
	if int(d.get("chain", 0)) > 1:
		k *= 1.0 + 0.3 * (int(d.chain) - 1)
	if m == "cone":
		k *= 1.5
	if m == "swing":
		k *= 1.0 + float(d.get("arc", 70.0)) / 120.0
	if int(d.get("bounce", 0)) > 0:
		k *= 1.0 + 0.4 * int(d.bounce)
	var rate := 0.0
	if m == "cone" or m == "beam":
		rate = float(d.damage) * float(d.rpm) / 60.0
		if m == "beam":
			rate *= 1.0 + float(d.get("ramp", 0.0)) * 0.5
		if int(d.mag) > 0:
			var ft := int(d.mag) * 60.0 / float(d.rpm)
			rate *= ft / (ft + float(d.reload))
		return rate * k
	var per := float(d.damage) * float(d.get("pellets", 1)) * float(d.get("count", 1))
	var cyc := 60.0 / float(d.rpm)
	if m == "charge":
		cyc += float(d.charge)
	if d.get("ret", false):
		per *= 2.0
	if d.has("cluster"):
		per = float(d.damage) * (1.0 + float(d.cluster)) * 0.5
	if m == "seek":
		per *= 0.7
	rate = per / cyc
	if int(d.mag) > 0:
		var ft2 := int(d.mag) * cyc
		rate *= ft2 / (ft2 + float(d.reload))
	return rate * k


## Richtwert des Kampfwerts je Heldenstufe (neue Waffen liegen zwischen 45 % und 160 % davon).
static func weapon_power_ref(lvl: int) -> float:
	return 45.0 * (1.0 + 0.035 * (lvl - 1))

# ---------------------------------------------------------------- Seltenheit und Gegenstände
const RARITY := [
	{"name": "Gewöhnlich", "color": Color("B4BCC8"), "mult": 1.0, "mods": 0, "max_level": 10},
	{"name": "Selten", "color": Color("38A9F5"), "mult": 1.15, "mods": 1, "max_level": 10},
	{"name": "Episch", "color": Color("B46CFF"), "mult": 1.32, "mods": 2, "max_level": 10},
	{"name": "Legendär", "color": Color("FFD23E"), "mult": 1.5, "mods": 3, "max_level": 10},
]
const LEVEL_DMG := 0.06
const WEAPON_MODS := [
	{"key": "damage", "name": "Wuchtig", "min": 0.05, "max": 0.12, "text": "+%d %% Schaden"},
	{"key": "rpm", "name": "Flink", "min": 0.05, "max": 0.12, "text": "+%d %% Feuerrate"},
	{"key": "mag", "name": "Dauerfeuer", "min": 0.1, "max": 0.25, "text": "+%d %% Magazin"},
	{"key": "reload", "name": "Griffig", "min": 0.08, "max": 0.18, "text": "−%d %% Nachladezeit"},
	{"key": "range", "name": "Treffsicher", "min": 0.05, "max": 0.12, "text": "+%d %% Reichweite"},
	{"key": "crit", "name": "Glückstreffer", "min": 0.04, "max": 0.1, "text": "+%d %% Volltreffer"},
	{"key": "double", "name": "Doppelschuss", "min": 0.08, "max": 0.14, "text": "%d %% Chance auf einen Gratis-Schuss"},
]
const GEAR := {
	"helmet": {"name": "Helm", "stat": "hp", "base": 0.08, "text": "+%d %% Leben"},
	"vest": {"name": "Weste", "stat": "carry", "base": 0.1, "text": "+%d %% Tragemenge"},
	"charm": {"name": "Glücksbringer", "stat": "cdr", "base": 0.06, "text": "Fähigkeiten laden %d %% schneller"},
}
const GEAR_NAMES := {
	"helmet": ["Blechtopf", "Bauhelm", "Fliegerkappe", "Sturmhaube"], "vest": ["Flickenweste", "Taschenweste", "Polsterjacke", "Panzerweste"],
	"charm": ["Glücksmünze", "Hasenpfote", "Vierblatt", "Sternanhänger"]}

static func upgrade_cost(item: Dictionary) -> Dictionary:
	var lv: int = item.level
	var r: int = item.rarity
	var k: float = load("res://src/story.gd").smith_k() if String(item.get("slot", "")) == "weapon" else 1.0     # V6 Paket E: Schmied
	return {"coins": int(40 * pow(1.28, lv) * (1.0 + r * 0.5) * k), "parts": int((3 + lv * 1.5 + r * 3) * k)}

static func dismantle_parts(item: Dictionary) -> int:
	return int([4, 12, 40, 120][item.rarity] + item.level * 2)

# ---------------------------------------------------------------- Helden
## stat-Schlüssel der Talente: dmg, hp, speed, cdr, reload, range, pickup, tower, heal, ult, crit, carry
const HERO_MAX_LEVEL := 40
const BADGE_GATES := {10: 10, 20: 30, 30: 80}
const HERO_HP_PER_LEVEL := 0.03
const HERO_DMG_PER_LEVEL := 0.02
const HERO_DODGE2_LEVEL := 3          # zweite Ladung der Ausweichrolle
const HERO_CHARM_LEVEL := 12          # Platz für Glücksbringer
const HERO_PASSIVE_LEVEL := 25        # Besonderheit wird verstärkt
const HERO_CHAPTER_LEVELS := [1, 5, 10, 20, 30]
const HERO_KILL_XP := [1.0, 5.0, 60.0]   # normaler Gegner, Elite (Brocken, Schamane), Boss
const ITEM_LEVEL_CAP := 10
const TRAIN_XP_PER_HOUR := 30.0
const TRAIN_XP_PER_LEVEL := 10.0
const AREA_HERO_LEVEL := [1, 5, 10, 16, 22, 28, 34]
const AREA_FACTOR := [1.0, 1.5, 2.2, 3.2, 4.5, 6.5, 9.0, 10.5, 12.0]

## Höchste Stufe, auf die ein Held seine Ausrüstung verbessern kann.
static func item_cap(hero_level: int) -> int:
	return mini(ITEM_LEVEL_CAP, 1 + int(hero_level / 3))
static func hero_xp_need(level: int) -> int:
	return int(round(60.0 * pow(level, 1.55) / 10.0) * 10)

const HERO_ORDER := ["jona", "mika", "bruno", "ada", "yuki", "greta", "nele"]
const HEROES := {
	"jona": {"name": "Jona Stern", "title": "Der Kapitän", "role": "Allrounder", "color": Color("5E9A2E"), "suit": Color("4C7426"), "hp": 110.0, "speed": 7.0,
		"weapons": ["j_rifle", "j_parcel", "j_burst"], "skills": ["rally", "roll", "delivery"], "unlock_area": -1,
		"passive": "Ortskundig: sammelt Münzen und Rohstoffe aus 30 % größerer Entfernung ein.",
		"look": "Grüner Helm mit gelber Schutzbrille, braune Haare, grünes Halstuch, Tarnanzug und Funkrucksack mit Antenne.",
		"story": "Jona war Briefträger und kannte im Tal jeden Weg und jede Haustür. Als die Flut kam, fuhr er weiter seine Runde, nur dass er jetzt Leute einsammelte statt Briefe auszuteilen. Den Bunker fand er, weil dort seit Jahren ein Paket ohne Empfänger lag. Er trägt es immer noch mit sich herum.",
		"trees": [
			{"name": "Anführer", "stats": [["tower", 0.04], ["tower", 0.04], ["cdr", 0.05], ["tower", 0.04], ["hp", 0.06], ["tower", 0.05], ["cdr", 0.05], ["ult", 0.15]]},
			{"name": "Schütze", "stats": [["dmg", 0.04], ["reload", 0.06], ["dmg", 0.04], ["range", 0.06], ["dmg", 0.05], ["crit", 0.05], ["reload", 0.08], ["dmg", 0.08]]},
			{"name": "Bote", "stats": [["speed", 0.03], ["pickup", 0.15], ["speed", 0.03], ["carry", 0.1], ["hp", 0.05], ["speed", 0.04], ["pickup", 0.2], ["carry", 0.15]]}],
		"chapters": [
			["Das Paket", "Im hintersten Regal des Bunkers lag ein Paket, verschnürt mit blauem Band. Kein Name, keine Adresse – nur ein Stempel: „Dringend“. Jona steckte es ein. Ein Briefträger lässt nichts liegen."],
			["Die letzte Runde", "Jona fuhr seine alte Route ab. An jeder Tür, an der noch jemand öffnete, sagte er dasselbe: „Packen Sie nur das Nötigste. Ich hole Sie in zehn Minuten ab.“ Er war noch nie unpünktlich gewesen."],
			["Funkstille", "Das Funkgerät im Bunker rauschte tagelang. Dann, mitten in der Nacht, eine Stimme: „… Paket … nicht öffnen … erst wenn …“. Danach wieder Rauschen. Jona schlief in dieser Nacht nicht mehr."],
			["Der Absender", "Auf einer Expedition fand Jona ein zweites Paket mit demselben blauen Band – und einen Zettel: „Für den, der die Flut aufhält.“ Die Handschrift kannte er. Es war die der alten Postmeisterin."],
			["Zugestellt", "Jona öffnete das Paket vor allen im Bunker. Darin lag die Glocke des alten Postamts. Er hängte sie über das Tor. Seitdem läutet sie, wenn die Flut besiegt ist – und jeder im Tal weiß: Die Post ist angekommen."]]},
	"mika": {"name": "Mika „Funke“ Brandt", "title": "Die Feuerwehrfrau", "role": "Nahbereich", "color": Color("D54144"), "suit": Color("E0B02E"), "hp": 130.0, "speed": 6.8,
		"weapons": ["m_flame", "m_water", "m_fireball"], "skills": ["firewall", "heatshield", "inferno"], "unlock_area": 0,
		"passive": "Feuerfest: nimmt 25 % weniger Schaden von brennenden Gegnern und keinen durch Feuer.",
		"look": "Roter Helm, zwei Tanks auf dem Rücken, Flammenwerfer. Rußfleck auf der Wange.",
		"story": "Mika war die Jüngste in der freiwilligen Feuerwehr von Grünbach und durfte nie ans Strahlrohr. Als die Schleimlinge kamen, stellte sich heraus, dass sie Wasser lieben und Hitze hassen. Mika baute den Löschschlauch um – in die andere Richtung. Sie sucht ihre alte Wehr und hebt für jeden einen Helm auf.",
		"trees": [
			{"name": "Brandmeisterin", "stats": [["dmg", 0.04], ["range", 0.05], ["dmg", 0.04], ["burn", 0.2], ["dmg", 0.05], ["range", 0.06], ["burn", 0.3], ["dmg", 0.08]]},
			{"name": "Retterin", "stats": [["hp", 0.06], ["heal", 0.1], ["hp", 0.06], ["cdr", 0.05], ["hp", 0.08], ["heal", 0.15], ["cdr", 0.06], ["hp", 0.1]]},
			{"name": "Draufgängerin", "stats": [["speed", 0.03], ["ult", 0.1], ["speed", 0.03], ["dmg", 0.04], ["cdr", 0.05], ["speed", 0.04], ["ult", 0.15], ["crit", 0.06]]}],
		"chapters": [
			["Das falsche Ende vom Schlauch", "„Wasser marsch!“, rief der Wehrführer – und die Schleimlinge wurden größer. Mika stand hinten bei den Schläuchen und dachte: Dann eben andersherum. Am Abend hatte sie aus einem Gasbrenner und zwei Tanks etwas gebaut, das niemand genehmigt hätte."],
			["Sechs Helme", "In der Wache hängen sechs Helme am Haken. Fünf davon sind nicht Mikas. Sie putzt sie jeden Sonntag, damit sie glänzen, wenn ihre Leute zurückkommen."],
			["Rauch über dem Forst", "Vom Wachturm aus sah Mika eine dünne Rauchsäule über dem Kiefernforst. Kein Waldbrand – ein Signalfeuer, genau so, wie man es in der Wehr lernt: drei kurze, drei lange Stöße."],
			["Die Wache", "Tief im Forst fand Mika das alte Löschfahrzeug, eingewachsen in Moos. Darin: ein Einsatztagebuch. Der letzte Eintrag: „Halten die Brücke am Sumpfwerk. Schickt Funke.“"],
			["Alle Mann zurück", "Fünf Gestalten winkten vom Dach der Fabrik. Mika brannte ihnen einen Weg frei, Meter für Meter. Zurück in der Wache hängte jeder seinen Helm selbst an den Haken. Mika bekam das Strahlrohr. Offiziell."]]},
	"bruno": {"name": "Bruno Bollwerk", "title": "Der Beschützer", "role": "Beschützer", "color": Color("F08A1E"), "suit": Color("5E7FB8"), "hp": 190.0, "speed": 6.2,
		"weapons": ["b_nailer", "b_ball", "b_cement"], "skills": ["shieldup", "patch", "berta"], "unlock_area": 1,
		"passive": "Fundament: Gebäude in seiner Nähe (8 Meter) nehmen 20 % weniger Schaden.",
		"look": "Der Größte der Gruppe, oranger Bauhelm, Schild aus einer Baggerschaufel, Werkzeuggürtel.",
		"story": "Bruno war Baggerfahrer und hat das halbe Tal gebaut: die Brücke, die Schule, den Spielplatz. Er redet wenig und repariert viel. Seinen Bagger „Berta“ musste er im Kiefernforst zurücklassen, als er einer Familie den Weg freihielt. Seitdem trägt er Bertas Schaufel als Schild.",
		"trees": [
			{"name": "Schutzmann", "stats": [["hp", 0.06], ["hp", 0.06], ["cdr", 0.05], ["hp", 0.08], ["heal", 0.1], ["hp", 0.08], ["cdr", 0.06], ["hp", 0.12]]},
			{"name": "Baumeister", "stats": [["tower", 0.04], ["heal", 0.1], ["tower", 0.04], ["cdr", 0.05], ["tower", 0.05], ["heal", 0.15], ["tower", 0.05], ["ult", 0.15]]},
			{"name": "Abrissunternehmer", "stats": [["dmg", 0.05], ["dmg", 0.05], ["range", 0.06], ["dmg", 0.05], ["speed", 0.04], ["dmg", 0.06], ["crit", 0.05], ["dmg", 0.1]]}],
		"chapters": [
			["Der Spielplatz", "Der Spielplatz am Bach war das Letzte, was Bruno vor der Flut gebaut hatte. Als die ersten Schleimlinge kamen, stellte er sich vor die Schaukel. Die Schaukel steht noch."],
			["Berta", "Berta war gelb, zwölf Tonnen schwer und sprang nur an, wenn man ihr gut zuredete. Bruno ließ sie mit laufendem Motor quer auf dem Waldweg stehen. So kam die Familie Lindner durch. Berta nicht."],
			["Schraube für Schraube", "Auf jeder Expedition hält Bruno Ausschau nach gelben Teilen. Eine Kette hier, ein Hydraulikzylinder dort. In der Garage wächst langsam etwas, das einmal ein Bagger war."],
			["Der Motor", "Der Motor lag im Sumpf, halb versunken. Bruno zog ihn mit bloßen Händen heraus und trug ihn drei Kilometer weit. Gefragt, ob er Hilfe brauche, sagte er: „Geht schon.“"],
			["Die neue Brücke", "Berta sprang beim ersten Versuch an. Bruno baute mit ihr eine neue Brücke über den Bach, breiter als die alte. Auf dem Geländer steht kein Name. Aber jeder weiß, wer sie gebaut hat."]]},
	"ada": {"name": "Dr. Ada Volt", "title": "Die Erfinderin", "role": "Unterstützung", "color": Color("9A5CE0"), "suit": Color("EDEDF2"), "hp": 100.0, "speed": 6.7,
		"weapons": ["a_spark", "a_shrink", "a_cloud"], "skills": ["turret", "overload", "pieps"], "unlock_area": 2,
		"passive": "Tüftlerin: Türme im Umkreis von 12 Metern schießen 15 % schneller.",
		"look": "Violette Fliegerkappe, übergroße Brille, Laborkittel, Rucksack mit zwei Tesla-Spulen, Drohne Pieps.",
		"story": "Ada wollte mit ihrer Wettermaschine den Regen im Tal gerechter verteilen. Die Maschine funktionierte – ein bisschen zu gut. Ob der große Regen etwas mit den Schleimlingen zu tun hat, weiß niemand, und Ada hat es noch keinem erzählt. Sie baut seitdem Tag und Nacht Geräte, um das Tal zu schützen.",
		"trees": [
			{"name": "Elektrikerin", "stats": [["dmg", 0.04], ["range", 0.05], ["dmg", 0.04], ["crit", 0.04], ["dmg", 0.05], ["range", 0.06], ["dmg", 0.06], ["dmg", 0.08]]},
			{"name": "Konstrukteurin", "stats": [["tower", 0.05], ["cdr", 0.05], ["tower", 0.05], ["tower", 0.05], ["cdr", 0.06], ["tower", 0.06], ["cdr", 0.06], ["tower", 0.1]]},
			{"name": "Forscherin", "stats": [["cdr", 0.04], ["ult", 0.1], ["hp", 0.05], ["cdr", 0.05], ["ult", 0.1], ["hp", 0.06], ["cdr", 0.06], ["ult", 0.2]]}],
		"chapters": [
			["Leichter Regen", "Der Wetterbericht hatte „leichten Regen“ gemeldet. Ada hatte ihn bestellt. Es regnete elf Tage. Am zwölften kroch etwas Grünes aus dem Krater am Rand des Tals."],
			["Das Labor", "Von Adas Labor in der Staubebene standen noch zwei Wände und der Kühlschrank. Im Kühlschrank: ihre Notizen, säuberlich beschriftet. Und ein halbes Käsebrot. Das Käsebrot ließ sie liegen."],
			["Pieps", "Pieps war eigentlich ein Rauchmelder. Dann ein Rauchmelder mit Propeller. Dann ein Rauchmelder mit Propeller und Meinung. Ada behauptet, sie habe ihm das Fliegen beigebracht. Pieps piepst dazu nur."],
			["Die Wahrheit", "Am Lagerfeuer legte Ada ihre Notizen auf den Tisch. „Es könnte meine Schuld sein“, sagte sie. Stille. Dann Oma Greta: „Kind, wer Regen machen kann, kann ihn auch abstellen. Iss erst mal was.“"],
			["Schönes Wetter", "Die neue Maschine ist kleiner, hat einen Aus-Knopf und Pieps passt auf sie auf. Am ersten Tag nach dem Einschalten schien die Sonne. Am Krater wurde das Grün ein kleines bisschen blasser."]]},
	"yuki": {"name": "Yuki Falke", "title": "Die Kundschafterin", "role": "Fernkampf", "color": Color("3FA35A"), "suit": Color("6B5A45"), "hp": 90.0, "speed": 7.6,
		"weapons": ["y_rifle", "y_bow", "y_swarm"], "skills": ["kiko", "smoke", "flock"], "unlock_area": 3,
		"passive": "Adlerauge: 15 % Chance auf Volltreffer mit doppeltem Schaden; sieht Fundkisten auf der Karte.",
		"look": "Grüne Kapuze mit Federn, Tuch vor dem Mund, langer Bogen. Auf der Schulter sitzt Falke Kiko.",
		"story": "Yuki war Vogelwartin an der Küste und zählte dort jedes Jahr die Zugvögel. Im Jahr der Flut kam kein einziger zurück – außer Kiko, der verletzt in ihrem Turm landete. Yuki glaubt, dass die Vögel etwas gesehen haben. Sie folgt ihrer alten Zugroute Gebiet für Gebiet.",
		"trees": [
			{"name": "Scharfschützin", "stats": [["crit", 0.04], ["dmg", 0.04], ["range", 0.06], ["crit", 0.05], ["dmg", 0.05], ["range", 0.06], ["crit", 0.06], ["dmg", 0.1]]},
			{"name": "Falknerin", "stats": [["cdr", 0.05], ["ult", 0.1], ["cdr", 0.05], ["dmg", 0.04], ["ult", 0.1], ["cdr", 0.06], ["dmg", 0.05], ["ult", 0.2]]},
			{"name": "Schatten", "stats": [["speed", 0.04], ["pickup", 0.15], ["speed", 0.04], ["hp", 0.05], ["speed", 0.04], ["carry", 0.1], ["hp", 0.06], ["speed", 0.06]]}],
		"chapters": [
			["Der leere Himmel", "Jedes Jahr am ersten Herbsttag zählte Yuki die Kraniche. Dieses Jahr stand in ihrem Buch nur eine Zahl: null. Sie unterstrich sie zweimal."],
			["Kiko", "Etwas Kleines, Rundes krachte durch das Fenster des Vogelturms und blieb im Papierkorb stecken. Ein Falke, kaum größer als eine Faust, mit einem angeknacksten Flügel und sehr beleidigtem Blick."],
			["Die Route", "Yuki hängte eine Karte auf und zog mit rotem Faden die alte Zugroute nach: Küste, Sumpf, Pass, Krater. An jedem Punkt, an dem sie Federn fand, steckte sie eine Nadel."],
			["Was die Vögel sahen", "Am Frostpass fand Yuki tausende Vögel, dicht gedrängt auf den Felsen, den Blick nach Süden. Sie warteten. Kiko flog eine Runde über ihnen und kam mit einer einzelnen grünen Feder zurück."],
			["Rückkehr", "Als der Krater still wurde, hob sich der Schwarm wie eine Wolke. Yuki stand auf ihrem Turm und zählte, bis es dunkel war. In ihrem Buch steht für dieses Jahr: „Alle.“"]]},
	"greta": {"name": "Oma Greta", "title": "Die Sprengmeisterin", "role": "Sprengmeisterin", "color": Color("F07AB4"), "suit": Color("8AA0C8"), "hp": 105.0, "speed": 6.1,
		"weapons": ["g_cracker", "g_sparkler", "g_cake"], "skills": ["crackers", "thermos", "festival"], "unlock_area": 4,
		"passive": "Lebenserfahrung: 10 % mehr Erfahrung aus allen Kämpfen.",
		"look": "Die Kleinste, rosa Kopftuch mit Blümchen, Strickjacke, Stahlhelm obendrauf, Einkaufstrolley voller Feuerwerk.",
		"story": "Greta hat vierzig Jahre lang das Feuerwerk für das Talfest gebaut und nebenbei den besten Apfelkuchen gebacken. Alle hielten sie für eine nette alte Dame. Das ist sie auch – nur dass ihr Keller voller Raketen war, als die Flut kam. Sie will das Talfest wieder feiern, mit allen.",
		"trees": [
			{"name": "Pyrotechnikerin", "stats": [["dmg", 0.04], ["range", 0.05], ["dmg", 0.05], ["ult", 0.1], ["dmg", 0.05], ["range", 0.06], ["ult", 0.15], ["dmg", 0.1]]},
			{"name": "Großmutter", "stats": [["heal", 0.1], ["hp", 0.06], ["heal", 0.1], ["cdr", 0.05], ["hp", 0.06], ["heal", 0.15], ["cdr", 0.06], ["hp", 0.1]]},
			{"name": "Schlitzohr", "stats": [["cdr", 0.05], ["crit", 0.04], ["speed", 0.04], ["cdr", 0.05], ["crit", 0.05], ["speed", 0.04], ["cdr", 0.06], ["crit", 0.08]]}],
		"chapters": [
			["Der Keller", "„Im Keller sind nur Einmachgläser“, hatte Greta vierzig Jahre lang gesagt. Als die Flut vor ihrer Tür stand, ging sie hinunter und kam mit einem Einkaufstrolley wieder herauf. Es waren keine Einmachgläser."],
			["Äpfel aus Grüntal", "Für den größten Kuchen der Welt braucht man die besten Äpfel. Die wachsen am alten Baum hinter dem Bach, und ja, da sind Schleimlinge. Greta nahm zwei Körbe mit: einen für die Äpfel."],
			["Zimt aus dem Sumpf", "Niemand weiß, warum in der alten Fabrik ein Fass Zimt lagerte. Greta fragte nicht. Sie fragte nur, wer ihr tragen hilft. Bruno hob die Hand."],
			["Die Gästeliste", "Greta schrieb jeden Namen auf, den sie kannte. Dann die, die sie nicht kannte. Dann, nach kurzem Zögern, ganz unten: „Schleimlinge (falls sie sich benehmen)“."],
			["Das Talfest", "Der Kuchen war so groß wie ein Scheunentor. Das Feuerwerk dauerte eine Stunde. Am Waldrand saßen drei kleine grüne Kugeln und sahen zu. Greta brachte ihnen ein Stück. „Aber nicht die Zäune anknabbern.“"]]},
	# V6 Paket H: Nele, die Taucherin – wird an der Schrottküste gerettet (zweite Rettung nach Yuki)
	"nele": {"name": "Nele Brandung", "title": "Die Taucherin", "role": "Kontrolle", "color": Color("1FA6B8"), "suit": Color("1F6E8C"), "hp": 115.0, "speed": 6.9,
		"weapons": ["n_harpoon", "n_bubble", "n_ice"], "skills": ["strudel", "luftblase", "springflut"], "unlock_area": 3,
		"passive": "Wasserratte: Wasser- und Eis-Waffen machen 15 % mehr Schaden (ab Stufe 25: 25 %).",
		"look": "Petrolfarbener Neoprenanzug, Tauchmaske auf der Stirn, Schnorchel, roter Zopf, gelbe Pressluftflasche und Flossenstiefel.",
		"story": "Nele war Rettungstaucherin an der Schrottküste und kannte jedes Wrack beim Namen. Als die Flut kam, tauchte sie drei Tage lang Leute aus gesunkenen Booten und versteckte sie im alten Leuchtturm. Dann ging ihr die Luft aus – und die Schleimlinge kamen die Treppe herauf. Seit ihrer Rettung taucht sie für das Tal nach allem, was die Flut verschluckt hat.",
		"trees": [
			{"name": "Harpunierin", "stats": [["dmg", 0.04], ["range", 0.05], ["crit", 0.04], ["dmg", 0.05], ["reload", 0.06], ["range", 0.06], ["crit", 0.05], ["dmg", 0.08]]},
			{"name": "Rettungsschwimmerin", "stats": [["hp", 0.06], ["heal", 0.1], ["cdr", 0.05], ["hp", 0.06], ["heal", 0.15], ["cdr", 0.06], ["hp", 0.08], ["heal", 0.2]]},
			{"name": "Wellenreiterin", "stats": [["speed", 0.03], ["ult", 0.1], ["cdr", 0.04], ["speed", 0.04], ["ult", 0.1], ["carry", 0.1], ["cdr", 0.05], ["ult", 0.2]]}],
		"chapters": [
			["Der Leuchtturm", "Siebzehn Leute saßen oben im Leuchtturm, als die Schleimlinge die Treppe heraufkamen. Nele hatte noch eine halbe Flasche Luft und eine Harpune. Sie verschloss die Luke und wartete. Am dritten Tag hörte sie einen Motor – und eine Stimme, die nach Briefträger klang."],
			["Die Wracks", "Unter der Schrottküste liegen zweiundvierzig Schiffe. Nele hat jedem einen Namen gegeben. In der „Möwe“ fand sie Konserven, in der „Alten Liese“ Werkzeug, und in der „Tante Grete“ eine Kiste Feuerwerk. Oma Greta wollte den Namen sofort ändern."],
			["Was unten leuchtet", "In zwanzig Metern Tiefe leuchtet der Meeresgrund grün. Nele schwamm hinunter und fand eine Spur aus Schleim, die vom Krater bis ins Meer führt. Etwas Großes ist hier entlanggekrochen. Sie hat es niemandem erzählt – nur Yuki, und Yuki hat es aufgeschrieben."],
			["Die Taucherglocke", "Bruno und Nele bauten aus einem alten Heizkessel eine Taucherglocke. Bei der ersten Fahrt nach unten sang Bruno, damit er die Angst nicht hörte. Unten lag der verlorene Leuchtturmspiegel – und daneben eine leere Schleimhülle, groß wie ein Bus."],
			["Das Licht kehrt zurück", "Nele schraubte den Spiegel zurück in den Leuchtturm. In der ersten Nacht wies das Licht siebzehn Booten den Weg in den Hafen. Auf jedem saß jemand, den sie damals heraufgeholt hatte. Sie zählte bis siebzehn und tauchte dann erst mal lange nicht."]]},
}

## Fähigkeiten der Helden. kind: s1 | s2 | ult
const SKILLS := {
	"rally": {"name": "Sammelruf", "cd": 20.0, "text": "Türme im Umkreis von 20 Metern schießen 6 Sekunden lang 30 % schneller; du selbst auch."},
	"roll": {"name": "Hechtrolle", "cd": 8.0, "text": "Schnelle Rolle in Laufrichtung, dabei unverwundbar. Lädt die Waffe sofort nach."},
	"delivery": {"name": "Eilzustellung", "cd": 70.0, "ult": true, "text": "Eine Kanone steht 15 Sekunden lang an deiner Position."},
	"firewall": {"name": "Feuerwand", "cd": 16.0, "text": "Zieht eine 12 Meter breite Flammenlinie, die 5 Sekunden brennt."},
	"heatshield": {"name": "Hitzeschild", "cd": 18.0, "text": "4 Sekunden lang 60 % weniger Schaden; Gegner in der Nähe fangen Feuer."},
	"inferno": {"name": "Großbrand", "cd": 60.0, "ult": true, "text": "Sprung mit Feuerring: 10 Meter Radius."},
	"shieldup": {"name": "Schaufel hoch", "cd": 14.0, "text": "3 Sekunden unverwundbar; Gegner im Umkreis greifen dich an."},
	"patch": {"name": "Flickwerk", "cd": 25.0, "text": "Repariert alle Gebäude im Umkreis von 10 Metern um 25 %."},
	"berta": {"name": "Berta kommt", "cd": 75.0, "ult": true, "text": "Eine Baggerschaufel schiebt alle Gegner in einer Linie 20 Meter weit weg."},
	"turret": {"name": "Geschütz Marke Eigenbau", "cd": 12.0, "text": "Stellt einen kleinen Blitzturm auf (20 Sekunden, höchstens zwei)."},
	"overload": {"name": "Überladung", "cd": 20.0, "text": "Der nächste Turm schießt 8 Sekunden doppelt so schnell."},
	"pieps": {"name": "Pieps’ großer Auftritt", "cd": 80.0, "ult": true, "text": "Die Drohne beschießt 12 Sekunden lang alles in der Nähe."},
	"kiko": {"name": "Kiko, los!", "cd": 15.0, "text": "Markiert den stärksten Gegner: 8 Sekunden lang +40 % Schaden von allen."},
	"smoke": {"name": "Rauchfeder", "cd": 18.0, "text": "4 Sekunden unsichtbar und 40 % schneller."},
	"flock": {"name": "Vogelzug", "cd": 70.0, "ult": true, "text": "Ein Schwarm trifft alles auf einer 40 Meter langen Linie."},
	"crackers": {"name": "Knallfrösche", "cd": 14.0, "text": "Acht Kracher betäuben Gegner im Umkreis für 2 Sekunden."},
	"thermos": {"name": "Thermoskanne", "cd": 22.0, "text": "Heilt dich um 30 % und repariert Gebäude in der Nähe um 10 %."},
	"festival": {"name": "Talfest", "cd": 80.0, "ult": true, "text": "Großes Feuerwerk über 11 Meter Radius, 4 Sekunden lang."},
	# V6 Paket H: Nele
	"strudel": {"name": "Strudel", "cd": 16.0, "text": "Ein Wasserwirbel vor dir zieht Gegner 4 Sekunden lang zusammen, verlangsamt und spült sie."},
	"luftblase": {"name": "Luftblase", "cd": 20.0, "text": "4 Sekunden lang 50 % weniger Schaden; heilt dich um 20 % und stößt nahe Gegner weg."},
	"springflut": {"name": "Springflut", "cd": 70.0, "ult": true, "text": "Eine Welle rollt 18 Meter nach vorn, schiebt alle Gegner zurück und macht Wasserschaden."},
}

# ---------------------------------------------------------------- Fahrzeuge
const VEHICLES := {
	"quad": {"name": "Flitzer", "kind": "Quad", "speed": 2.0, "carry": 0.5, "hp": 150.0, "bunker": 3, "cost": {"coins": 400, "metal": 80}, "text": "Wendig und schnell."},
	"bike": {"name": "Knatterkarre", "kind": "Motorrad mit Beiwagen", "speed": 2.3, "carry": 0.3, "hp": 130.0, "bunker": 4, "cost": {"coins": 800, "metal": 200, "fuel": 60}, "text": "Das schnellste Fahrzeug."},
	"buggy": {"name": "Dünenbuggy", "kind": "Buggy", "speed": 1.9, "carry": 1.0, "hp": 280.0, "bunker": 5, "cost": {"coins": 1500, "metal": 450, "fuel": 100}, "ram": true, "text": "Rammt kleine Gegner ohne Tempoverlust."},
	"pickup": {"name": "Pritsche", "kind": "Pickup mit Geschütz", "speed": 1.7, "carry": 2.0, "hp": 480.0, "bunker": 7, "cost": {"coins": 3500, "metal": 1000, "fuel": 250}, "turret": true, "ram": true, "text": "Das Geschütz auf der Ladefläche schießt selbstständig."},
	"hover": {"name": "Luftkissenboot", "kind": "Luftkissenboot", "speed": 1.85, "carry": 1.2, "hp": 300.0, "bunker": 8, "cost": {"coins": 5000, "metal": 1200, "cells": 120}, "water": true, "text": "Fährt über Wasser und erreicht gesperrte Bereiche."},
}
const VEHICLE_ORDER := ["quad", "bike", "buggy", "pickup", "hover"]
const VEHICLE_UPGRADES := [["motor", "Motor", "+6 % Tempo"], ["body", "Karosserie", "+15 % Leben"], ["bed", "Ladefläche", "+15 % Tragemenge"]]

# ---------------------------------------------------------------- Expeditionen
## theme: Farben und Kulissen des Gebiets. res: Rohstoffe, die dort liegen (Gewichtung).
const AREAS := [
	{"key": "gruental", "name": "Grüntal", "level": 1, "fuel": 10, "boss": 0, "res": {"wood": 3, "coins": 2, "stone": 1},
		"text": "Wiesen, Tannen und ein Bach mit Holzbrücke.", "enemies": [1.0, 0.15, 0.0, 0.02, 0.0, 0.0, 0.0, 0.0],
		"ground": Color("8FB02A"), "ground2": Color("6E9A2B"), "path": Color("EDA865"), "tree": "pine", "fog": Color("CFE6F5"), "sun": Color("FFF0CF"), "water": true},
	{"key": "forst", "name": "Kiefernforst", "level": 5, "fuel": 16, "boss": 1, "res": {"wood": 3, "stone": 2, "coins": 1},
		"text": "Dunkler Wald, Pilze und Nebel.", "enemies": [1.0, 0.1, 0.0, 0.03, 0.12, 0.0, 0.0, 0.0],
		"ground": Color("5C8A3A"), "ground2": Color("3F6B35"), "path": Color("B98A5A"), "tree": "pine_dense", "fog": Color("A9C6B5"), "sun": Color("E9F0CF"), "water": false},
	{"key": "staub", "name": "Staubebene", "level": 10, "fuel": 24, "boss": 2, "res": {"metal": 3, "fuel": 2, "coins": 1},
		"text": "Trockene Ebene mit Tankstelle und Autowracks.", "enemies": [1.0, 0.12, 0.1, 0.04, 0.05, 0.0, 0.0, 0.0],
		"ground": Color("E0B46A"), "ground2": Color("C99A52"), "path": Color("9A6B45"), "tree": "cactus", "fog": Color("F0D8A8"), "sun": Color("FFE6B0"), "water": false},
	{"key": "kueste", "name": "Schrottküste", "level": 16, "fuel": 32, "boss": 3, "res": {"metal": 3, "parts": 1, "coins": 2},
		"text": "Strand mit Schiffswracks und Containern.", "enemies": [1.0, 0.12, 0.08, 0.05, 0.06, 0.2, 0.0, 0.0],
		"ground": Color("EBD79A"), "ground2": Color("D6BE7C"), "path": Color("B99B6A"), "tree": "palm", "fog": Color("CFEAF5"), "sun": Color("FFF4D8"), "water": true},
	{"key": "sumpf", "name": "Sumpfwerk", "level": 24, "fuel": 42, "boss": 4, "res": {"fuel": 3, "cells": 2, "metal": 1},
		"text": "Überflutete Fabrik, Rohre und grüne Tümpel.", "enemies": [1.0, 0.1, 0.1, 0.06, 0.1, 0.2, 0.05, 0.02],
		"ground": Color("6F8A4A"), "ground2": Color("55703E"), "path": Color("7A6A52"), "tree": "dead", "fog": Color("A8C89A"), "sun": Color("DDEBB8"), "water": true},
	{"key": "frost", "name": "Frostpass", "level": 34, "fuel": 55, "boss": 5, "res": {"stone": 3, "cells": 2, "coins": 1},
		"text": "Verschneites Gebirge und Eishöhlen.", "enemies": [1.0, 0.15, 0.08, 0.08, 0.1, 0.25, 0.1, 0.03],
		"ground": Color("DCE7F2"), "ground2": Color("BFD2E6"), "path": Color("B8C8DA"), "tree": "snowpine", "fog": Color("E6F0FA"), "sun": Color("F4F8FF"), "water": false},
	{"key": "krater", "name": "Schleimkrater", "level": 45, "fuel": 70, "boss": 6, "res": {"shards": 1, "cells": 2, "metal": 2, "coins": 3},
		"text": "Leuchtend grüner Krater, Ursprung der Flut.", "enemies": [1.0, 0.2, 0.12, 0.1, 0.12, 0.3, 0.15, 0.05],
		"ground": Color("7FB23A"), "ground2": Color("5E9A30"), "path": Color("A6D24A"), "tree": "crystal", "fog": Color("C8F09A"), "sun": Color("EAFFC0"), "water": true},
	{"key": "vulkan", "name": "Vulkaninsel", "level": 55, "fuel": 85, "boss": 7, "res": {"stone": 2, "cells": 2, "shards": 1, "coins": 3},
		"text": "Schwarze Lavafelder, Obsidian und ein rauchender Vulkan. Lavaströme wandern, die Hitze steigt.", "enemies": [1.0, 0.2, 0.12, 0.1, 0.12, 0.3, 0.15, 0.05],
		"ground": Color("4C4648"), "ground2": Color("37302F"), "path": Color("7A5E4C"), "tree": "lava", "fog": Color("A8948C"), "sun": Color("FFE0B8"), "water": false},
	{"key": "stadt", "name": "Stadtruinen", "level": 60, "fuel": 100, "boss": 8, "res": {"metal": 2, "cells": 2, "parts": 1, "coins": 3},
		"text": "Verfallene Straßen voller Unkraut, Hochhausruinen und Maschinen mit eigenem Kopf. Auf den Dächern bist du oben, im U-Bahn-Schacht schnell.", "enemies": [1.0, 0.2, 0.12, 0.1, 0.12, 0.3, 0.15, 0.05],
		"ground": Color("707868"), "ground2": Color("5C6654"), "path": Color("8A8478"), "tree": "city", "fog": Color("C4CCD2"), "sun": Color("F2EEE0"), "water": false},
]
const MISSIONS := {
	"sammeln": {"name": "Sammeln", "text": "Fülle deinen Rucksack mindestens zur Hälfte und kehre zurück."},
	"nest": {"name": "Schleimnest", "text": "Zerstöre alle drei Nester."},
	"kopfgeld": {"name": "Kopfgeld", "text": "Finde und besiege den Boss des Gebiets."},
	"aussenposten": {"name": "Außenposten", "text": "Halte den Posten drei Minuten. Stell dich auf Felder mit Zahl, um zu bauen."},
	"wettlauf": {"name": "Wettlauf", "text": "Fahre durch alle Tore, bevor die Zeit abläuft. Nur mit Fahrzeug."},
	"rettung": {"name": "Rettung", "text": "Befreie den gefangenen Helden und bringt euch in Sicherheit."},
	"expedition": {"name": "Expedition", "text": "Sammle, baue die Außenbasis und erkunde das Gebiet."},
	"befreiung": {"name": "Befreiung", "text": "Die Außenbasis wird belagert: wehre drei Wellen in vier Minuten ab."},
	"haendler": {"name": "Händler", "text": "Ein fahrender Händler tauscht Feldmünzen gegen seltene Rohstoffe."},
	"truhe": {"name": "Versteckte Truhe", "text": "Irgendwo liegt eine gut versteckte Truhe."},
}
const DIFFS := [{"name": "Normal", "hp": 1.0, "loot": 1.0, "count": 1.0}, {"name": "Schwer", "hp": 1.8, "loot": 1.6, "count": 1.35}, {"name": "Albtraum", "hp": 3.2, "loot": 2.4, "count": 1.7}]
const BACKPACK := 220.0
const RES_WEIGHT := {"coins": 0.2, "wood": 1.0, "stone": 1.2, "metal": 1.2, "fuel": 1.5, "cells": 2.0, "parts": 3.0, "shards": 6.0}
const AUTO_HOURS := [1, 4, 8]
const AUTO_SHARE := 0.3
const EXPEDITION_BUILD_SKIP := 900.0                # jede Expedition zieht 15 Minuten von laufenden Bauten ab

# ---------------------------------------------------------------- Expedition V3: Karte, Phasen, Quellen, Bauplätze
const EXP_N := 120                                  # Kartenfelder je Seite (2 m): 240 × 240 m
const EXP_HALF := 120.0
const EXP_RING_LAND := 45.0                         # Landezone (Radius um den Start)
const EXP_RING_MID := 85.0                          # Mittelring bis hier, danach Außenring
const EXP_RING_W := 4.0                             # Dicke der natürlichen Sperre
const EXP_PASSAGES := 3
const EXP_PASSAGE_W := 8.0
const EXP_OUTPOST_DIST := [22, 30]                  # Abstand Start – Mitte der Außenbasis
const EXP_FOG_RADIUS := 30.0
const EXP_FOG_CELL := 10.0
const EXP_MINE_IDLE := 0.3                          # so lange stillstehen, dann beginnt die Arbeit (Ladekreis)
const EXP_MINE_MOVE := 0.9                          # langsamer als das zählt als Stehen
const EXP_MINE_RANGE := 2.2
const EXP_HIT_TIME := 0.42
const EXP_HIT_LEVEL := 0.01                         # je Heldenstufe schneller
const EXP_PAD_RADIUS := 1.6
const EXP_PAY_TICK := 0.08
const EXP_GROW_TIME := 1.2
const EXP_MAT_BOOST := 4.0                          # Kristall/Batterie geben als Baustoff des Gebiets (Krater) viermal so viel
const EXP_RESERVE := 1.3                            # die Landezone hält Pflichtpreise + 30 %
const EXP_RICH := [2.0, 3.0]                        # Quellen im Mittel- und Außenring
const EXP_RAID_EVERY := 50.0
const EXP_RAID_WARN := 5.0
const EXP_RAID_BASE := 6
const EXP_RAID_PER_PAD := 2
const EXP_SIEGE_TIME := 75.0
const EXP_MAX_GUARDS := 80                         # Wachen und Streuner höchstens (Logikzeit)
const EXP_MAX_ALIVE := 140                          # mit Angreifern höchstens
const EXP_ELITE_HP := 4.0                           # Elitegegner am Ende des Großangriffs (Leben × Brocken), falls Paket 11 keinen liefert
const EXP_SIEGE_EVERY := 9.0                        # neue Gruppe je Richtung im Großangriff
const EXP_RUBBLE_TIME := 20.0
const EXP_REBUILD_SHARE := 0.5
const EXP_RESPAWN_TIME := 6.0
const EXP_RESPAWNS := 3
const EXP_DUSK_AFTER := 720.0
const EXP_DUSK_STEP := 60.0
const EXP_DUSK_POWER := 0.15
const EXP_DUSK_LOOT := 0.10
const EXP_DEPOT_KEEP := 86400.0                     # Überschuss bleibt 24 Stunden im Depot der Außenbasis
const EXP_FIRE_HEAL := 0.04
const EXP_FIRE_RADIUS := 5.0
const EXP_PARK_REPAIR := 0.05
const EXP_HOME_RADIUS := 7.0                        # „Heimkehren“ erscheint so nah an Zentrale oder Fahrzeug
const EXP_XP := {"pad": 10, "outpost": 150, "nest": 40, "bounty": 120, "rescue": 80, "race": 60, "trader": 0, "chest": 40}
const EXP_DONE_XP := [80, 12]                       # Expedition abgeschlossen: 80 + 12 × Gebietsstufe
const EXP_ABORT_XP := 0.3
const EXP_COIN_K := 0.6                             # Münzen aus Gegnern in der Expedition (je Gebietsfaktor)
const EXP_HERO_LEVEL := [1, 4, 8, 13, 18, 25, 32, 38, 40]    # empfohlene Heldenstufe je Gebiet (Weltkarte)
## Je Gebiet (Reihenfolge wie AREAS): Preisfaktor, Baustoffe (ersetzen Holz/Stein), Sperre, Quellen mit Gewicht.
const EXP_AREAS := [
	{"factor": 1.0, "mats": ["wood", "stone"], "barrier": "Dornenhecke", "nodes": {"tree_small": 3, "tree_big": 2, "rock": 2, "coinpile": 1}},
	{"factor": 1.5, "mats": ["wood", "stone"], "barrier": "umgestürzte Stämme", "nodes": {"tree_small": 2, "tree_big": 3, "rock": 2, "coinpile": 1}},
	{"factor": 2.2, "mats": ["metal", "stone"], "barrier": "Schrottwall", "nodes": {"scrap": 3, "wreck": 1, "barrel": 2, "pump": 1, "rock": 2, "coinpile": 1}},
	{"factor": 3.2, "mats": ["metal", "wood"], "barrier": "Containerwand", "nodes": {"scrap": 3, "wreck": 2, "tree_small": 2, "tree_big": 1, "coinpile": 1}},
	{"factor": 4.5, "mats": ["metal", "fuel"], "barrier": "Giftnebel", "nodes": {"scrap": 3, "wreck": 1, "barrel": 2, "pump": 1, "crystal": 1, "battery": 1, "coinpile": 1}},
	{"factor": 6.5, "mats": ["stone", "metal"], "barrier": "Eisbarriere", "nodes": {"rock": 4, "scrap": 2, "crystal": 1, "battery": 1, "coinpile": 1}},
	{"factor": 9.0, "mats": ["metal", "cells"], "barrier": "Schleimwand", "nodes": {"scrap": 3, "wreck": 1, "crystal": 2, "battery": 1, "shard": 1, "coinpile": 1}},
	{"factor": 10.5, "mats": ["stone", "cells"], "barrier": "Lavastrom", "nodes": {"obsidian": 4, "rock": 1, "sulfur": 2, "crystal": 1, "battery": 1, "scrap": 1, "shard": 1, "coinpile": 1}},
	{"factor": 12.0, "mats": ["metal", "cells"], "barrier": "Schuttberg", "nodes": {"ewaste": 4, "copper": 2, "akku": 2, "wreck": 1, "scrap": 1, "shard": 1, "coinpile": 1}},
]
## Rohstoffquellen: Modell (stages = Größen _1.._3), Ertrag min/max (× Gebietsfaktor), Hiebe, Animation, seltene Beigabe.
const EXP_NODES := {
	"tree_small": {"name": "Baum", "model": "n_tree_small", "res": "wood", "min": 12, "max": 12, "hits": 3, "clip": "chop", "fall": true},
	"tree_big": {"name": "Großer Baum", "model": "n_tree_big", "res": "wood", "min": 30, "max": 30, "hits": 6, "clip": "chop", "fall": true},
	"rock": {"name": "Felsbrocken", "model": "n_rock", "stages": 3, "res": "stone", "min": 10, "max": 25, "hits": 4, "clip": "mine"},
	"scrap": {"name": "Schrotthaufen", "model": "n_scrap", "stages": 3, "res": "metal", "min": 10, "max": 30, "hits": 4, "clip": "mine", "rare": "parts", "rare_p": 0.15},
	"wreck": {"name": "Autowrack", "model": "n_wreck", "res": "metal", "min": 10, "max": 30, "hits": 4, "clip": "mine", "rare": "parts", "rare_p": 0.3},
	"barrel": {"name": "Fass", "model": "n_barrel_fuel", "res": "fuel", "min": 8, "max": 20, "hits": 2, "clip": "pick_up"},
	"pump": {"name": "Zapfsäule", "model": "n_pump", "res": "fuel", "min": 8, "max": 20, "hits": 2, "clip": "pick_up"},
	"crystal": {"name": "Kristall", "model": "n_crystal", "stages": 3, "res": "cells", "min": 3, "max": 8, "hits": 5, "clip": "mine"},
	"battery": {"name": "Batterie", "model": "n_battery", "res": "cells", "min": 3, "max": 8, "hits": 5, "clip": "mine"},
	"shard": {"name": "Scherbenader", "model": "n_shard_vein", "res": "shards", "min": 1, "max": 1, "hits": 8, "clip": "mine", "max_n": 2, "no_factor": true},
	"coinpile": {"name": "Münzhaufen", "model": "n_coinpile", "res": "coins", "min": 25, "max": 45, "hits": 2, "clip": "pick_up"},
	# Vulkaninsel (Paket Z): Obsidian ist eine gebietseigene Quelle für Stein (selten mit Sternsplittern), Schwefel gibt Treibstoff
	"obsidian": {"name": "Obsidianbrocken", "model": "n_obsidian", "stages": 3, "res": "stone", "min": 18, "max": 34, "hits": 4, "clip": "mine", "rare": "shards", "rare_p": 0.08},
	"sulfur": {"name": "Schwefelquelle", "model": "n_sulfur", "res": "fuel", "min": 10, "max": 22, "hits": 3, "clip": "pick_up"},
	# Stadtruinen (Paket Z2): Elektroschrott gibt Metall (selten Bauteile), Kupferkabel gibt Bauteile, Akkus geben Energiezellen
	"ewaste": {"name": "Elektroschrott", "model": "n_ewaste", "stages": 3, "res": "metal", "min": 16, "max": 32, "hits": 4, "clip": "mine", "rare": "parts", "rare_p": 0.2},
	"copper": {"name": "Kupferkabel", "model": "n_copper", "res": "parts", "min": 0.6, "max": 1.4, "hits": 4, "clip": "pick_up"},
	"akku": {"name": "Akkustapel", "model": "n_akku", "res": "cells", "min": 3, "max": 8, "hits": 4, "clip": "mine"},
}
## Bauplätze der Außenbasis (Grüntal-Preise; Holz/Stein werden durch die Baustoffe des Gebiets ersetzt, alles × Faktor).
## at: Lage in Metern (+z zeigt zur Landestelle), line: Mauer von–bis, level: ab dieser Ausbaustufe (1 = Erstaufbau).
const OUTPOST_PADS := [
	{"key": "zentrale", "name": "Zentrale", "kind": "zentrale", "at": [0, 0], "size": [5.6, 5.6], "price": {"coins": 40}, "must": true, "level": 1},
	{"key": "depot", "name": "Depot", "kind": "depot", "at": [-5, -4.5], "size": [3.2, 3.6], "price": {"coins": 30, "wood": 40}, "must": true, "level": 1},
	{"key": "feuer", "name": "Lagerfeuer", "kind": "feuer", "at": [-5, 4.5], "size": [2.4, 2.4], "price": {"wood": 20}, "must": false, "level": 1},
	{"key": "park", "name": "Parkplatz", "kind": "park", "at": [5, 4.5], "size": [3.2, 3.2], "price": {"coins": 20}, "must": false, "level": 1},
	{"key": "wall_n", "name": "Mauer Nord", "kind": "wall", "line": [[-5, -9], [5, -9]], "price": {"wood": 25}, "must": true, "level": 1},
	{"key": "wall_o", "name": "Mauer Ost", "kind": "wall", "line": [[9, -5], [9, 5]], "price": {"wood": 25}, "must": true, "level": 1},
	{"key": "wall_s", "name": "Mauer Süd", "kind": "wall", "line": [[-5, 9], [5, 9]], "gap": true, "price": {"wood": 25}, "must": true, "level": 1},
	{"key": "wall_w", "name": "Mauer West", "kind": "wall", "line": [[-9, -5], [-9, 5]], "price": {"wood": 25}, "must": true, "level": 1},
	{"key": "t1", "name": "Turm 1", "kind": "tower", "at": [-8, -8], "price": {"coins": 60, "wood": 30, "stone": 20}, "must": true, "level": 1},
	{"key": "t2", "name": "Turm 2", "kind": "tower", "at": [8, -8], "price": {"coins": 60, "wood": 30, "stone": 20}, "must": true, "level": 1},
	{"key": "tor", "name": "Tor", "kind": "tor", "at": [0, 9], "price": {"coins": 30, "wood": 20}, "must": true, "level": 1, "walls": true},
	{"key": "special", "name": "Spezialbau", "kind": "special", "at": [5, -4.5], "size": [3.4, 4.0], "price": {"coins": 120, "wood": 80, "stone": 40}, "must": true, "level": 1, "walls": true},
	{"key": "t3", "name": "Turm 3", "kind": "tower", "at": [-8, 8], "price": {"coins": 60, "wood": 30, "stone": 20}, "level": 2},
	{"key": "special_2", "name": "Spezialbau Stufe 2", "kind": "special_up", "at": [5, -1.2], "price": {"coins": 120, "wood": 80, "stone": 40}, "level": 2},
	{"key": "special_3", "name": "Spezialbau Stufe 3", "kind": "special_up", "at": [5, -1.2], "price": {"coins": 120, "wood": 80, "stone": 40}, "level": 3},
	{"key": "walls_3", "name": "Stärkere Mauern", "kind": "walls_up", "at": [0, -6.6], "price": {"wood": 100}, "level": 3},
	{"key": "special_4", "name": "Spezialbau Stufe 4", "kind": "special_up", "at": [5, -1.2], "price": {"coins": 120, "wood": 80, "stone": 40}, "level": 4},
	{"key": "t4", "name": "Turm 4", "kind": "tower", "at": [8, 8], "price": {"coins": 60, "wood": 30, "stone": 20}, "level": 4},
	{"key": "special_5", "name": "Spezialbau Stufe 5", "kind": "special_up", "at": [5, -1.2], "price": {"coins": 120, "wood": 80, "stone": 40}, "level": 5},
	{"key": "depot_5", "name": "Größeres Depot", "kind": "depot_up", "at": [-5, -1.2], "price": {"coins": 30, "wood": 40}, "level": 5},
]
const OUTPOST_LEVEL_COST := 2.2                     # Preis je Ausbaustufe = Vorstufe × 2,2
const OUTPOST_WALL_HP := 900.0                      # Leben eines Mauerstücks der Außenbasis (× Gebietsstärke)
const OUTPOST_HP := {"zentrale": 1600.0, "depot": 700.0, "feuer": 300.0, "park": 400.0, "special": 1000.0}
const EXP_PHASE_NAME := {"land": "Ankommen", "build": "Aufbauen", "siege": "Großangriff", "explore": "Erkunden", "relief": "Befreiung"}

# ---------------------------------------------------------------- Beutekisten
## table: Chance in Prozent für Gewöhnlich, Selten, Episch, Legendär
const CHESTS := {
	"daily": {"name": "Tageskiste", "count": 3, "table": [70.0, 24.0, 5.5, 0.5], "items": 0.25, "color": Color("B8742F")},
	"find": {"name": "Fundkiste", "count": 2, "table": [70.0, 24.0, 5.5, 0.5], "items": 0.25, "color": Color("9C9A4A")},
	"quest": {"name": "Auftragskiste", "count": 4, "table": [58.0, 32.0, 9.0, 1.0], "items": 0.35, "color": Color("3C5CA4")},
	"level": {"name": "Stufenkiste", "count": 5, "table": [58.0, 32.0, 9.0, 1.0], "items": 0.4, "color": Color("0469CC")},
	"flood_wood": {"name": "Flutkiste Holz", "count": 4, "table": [58.0, 32.0, 9.0, 1.0], "items": 0.35, "color": Color("A9622F")},
	"flood_silver": {"name": "Flutkiste Silber", "count": 6, "table": [40.0, 42.0, 15.0, 3.0], "items": 0.45, "color": Color("C9CED8")},
	"boss": {"name": "Bosskiste", "count": 5, "table": [40.0, 42.0, 15.0, 3.0], "items": 0.5, "min_rarity": 1, "color": Color("9D2A35")},
	"flood_gold": {"name": "Flutkiste Gold", "count": 8, "table": [25.0, 45.0, 24.0, 6.0], "items": 0.5, "min_rarity": 2, "color": Color("FDCA14")},
	"clan": {"name": "Clankiste", "count": 6, "table": [25.0, 45.0, 24.0, 6.0], "items": 0.45, "color": Color("B46CFF")},
	"gift": {"name": "Geschenkkiste", "count": 2, "table": [70.0, 24.0, 5.5, 0.5], "items": 0.2, "color": Color("F07AB4")},
}
const PITY_EPIC := 10
const PITY_LEGEND := 40

# ---------------------------------------------------------------- Tagesaufträge
const QUESTS := [
	{"key": "kills", "text": "Besiege %d Schleimlinge", "amount": 150},
	{"key": "expeditions", "text": "Schließe %d Expeditionen ab", "amount": 2},
	{"key": "wood", "text": "Sammle %d Holz", "amount": 250},
	{"key": "chests", "text": "Öffne %d Kisten", "amount": 2},
	{"key": "builds", "text": "Baue oder verbessere %d Gebäude", "amount": 2},
	{"key": "coins", "text": "Sammle %d Münzen", "amount": 300},
	{"key": "skills", "text": "Setze %d Fähigkeiten ein", "amount": 8},
	{"key": "practice", "text": "Bestehe %d Übungsalarm", "amount": 1},
]

# ---------------------------------------------------------------- Gemeinsam spielen
const LEAGUES := ["Bronze", "Silber", "Gold", "Platin", "Diamant", "Meister"]
const LEAGUE_SIZE := 50
const SEND_PER_DAY := 5
const SEND_SHARE := 0.05
const CLAN_SIZE := 30
const CLAN_MIN_LEVEL := 8
const SHOUTS := ["Hallo!", "Danke!", "Gut gemacht!", "Hilfe!", "Los geht’s!", "Bis später!", "Wer spendet Holz?", "Flut geschafft!"]
## Vorschläge für Bunkernamen (Teil 1 + Teil 2), auch für die simulierten Mitspieler
const BUNKER_NAME_PARTS := ["Rost", "Eisen", "Nebel", "Sturm", "Moos", "Kupfer", "Funken", "Asche", "Frost", "Sonnen", "Wolken", "Kessel", "Dachs", "Falken", "Anker", "Rauch"]
const BUNKER_NAME_ENDS := ["burg", "wall", "hafen", "feste", "nest", "werk", "horst", "tal", "warte", "hof", "bau", "schanze"]
const BOT_NAMES := ["Mutiger Dachs", "Flinker Fuchs", "Kleine Eule", "Starker Bär", "Schlauer Rabe", "Wilder Luchs", "Froher Otter", "Tapferer Igel", "Roter Milan",
	"Stiller Wolf", "Lustiger Specht", "Blauer Reiher", "Kecker Spatz", "Goldener Hirsch", "Schneller Hase", "Listiger Marder", "Sanfter Biber", "Bunter Fink",
	"Großer Uhu", "Wacher Falke", "Zäher Steinbock", "Leiser Kauz", "Freche Elster", "Treuer Hund", "Kluge Krähe", "Munterer Zeisig", "Dicker Hamster", "Langer Storch"]
const CLAN_NAMES := ["Talwächter", "Bunkerbande", "Die Laternen", "Schleimjäger", "Grünbacher", "Sternbanner", "Die Baumeister", "Kiefernbund", "Funkenflug", "Brückenbauer"]

# ---------------------------------------------------------------- Bewohner (Paket 2)
const NPC_NAMES := ["Lotte", "Karl", "Frieda", "Emil", "Hanna", "Oskar", "Ida", "Paul", "Berta", "Fritz", "Mia", "Anton", "Lene", "Willi", "Erna", "Kurt"]
const NPC_JOBS := {"bau": "Baumeister", "holz": "Holzfäller", "stein": "Steinmetz", "schrott": "Schrottsammler", "technik": "Techniker",
	"traeger": "Träger", "hand": "Handwerker", "wache": "Wache", "gaertner": "Gärtner", "held": "Held"}
const NPC_REPAIR_RATE := 0.02        # Handwerker: Anteil Leben je Sekunde und Handwerker (statt Sofortheilung nach der Flut)
const NPC_RUBBLE_HP := 0.10          # zerstörte Gebäude stehen nach der Flut mit diesem Anteil Leben wieder
