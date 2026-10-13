extends RefCounted
## V6 Paket B (Basis- und Flut-Tiefe): alle Zahlen und Texte dieses Pakets.
## Forschungsbaum, Wetter der Flut, Belagerung (Brecher, Flieger, Leitern), Flut-Rückblick, Layout-Codes,
## Mauer-Reparatur, Funde beim Räumen, verletzte Bewohner, Wasser-Spritzer, Mitteilungen und Bewertung.

# ================================================================= Forschung (Labor)
## Drei Äste. Jeder Ast hat 11 Knoten in sechs Reihen (tier 0–5); col 0 = links, 1 = Mitte, 2 = rechts.
## req: alle genannten Knoten müssen fertig sein. stat/val: Wirkung (Research.bonus(stat) summiert alle fertigen Knoten).
const BRANCHES := [
	{"key": "tuerme", "name": "Türme und Mauern", "icon": "ui_target", "color": Color("E0654A"), "res": ["stone", "metal"]},
	{"key": "wirtschaft", "name": "Wirtschaft", "icon": "ui_gear", "color": Color("E8B23A"), "res": ["wood", "stone"]},
	{"key": "helden", "name": "Helden und Expedition", "icon": "ui_helmet", "color": Color("4FB0E8"), "res": ["fuel", "cells"]},
]
const NODES := {
	# ---- Türme und Mauern
	"t_optik": {"branch": "tuerme", "tier": 0, "col": 1, "name": "Zielfernrohre", "stat": "tower_range", "val": 0.06, "text": "Türme schießen 6 % weiter.", "icon": "ui_target", "req": []},
	"t_lader": {"branch": "tuerme", "tier": 1, "col": 0, "name": "Schnellladung", "stat": "tower_rate", "val": 0.06, "text": "Türme feuern 6 % schneller.", "icon": "ui_speed", "req": ["t_optik"]},
	"t_mauer": {"branch": "tuerme", "tier": 1, "col": 2, "name": "Dicke Mauern", "stat": "wall_hp", "val": 0.10, "text": "Mauern und Tore halten 10 % mehr aus.", "icon": "ui_shield", "req": ["t_optik"]},
	"t_munition": {"branch": "tuerme", "tier": 2, "col": 0, "name": "Hohlspitz-Munition", "stat": "tower_dmg", "val": 0.06, "text": "Türme machen 6 % mehr Schaden.", "icon": "ui_bullet", "req": ["t_lader"]},
	"t_fallen": {"branch": "tuerme", "tier": 2, "col": 2, "name": "Fallenbau", "stat": "trap_dmg", "val": 0.15, "text": "Fallen machen 15 % mehr Schaden.", "icon": "ui_alarm", "req": ["t_mauer"]},
	"t_praezision": {"branch": "tuerme", "tier": 3, "col": 0, "name": "Präzisionsoptik", "stat": "tower_range", "val": 0.08, "text": "Türme schießen weitere 8 % weiter.", "icon": "ui_target", "req": ["t_munition"]},
	"t_wetter": {"branch": "tuerme", "tier": 3, "col": 1, "name": "Wetterschutz", "stat": "weather_resist", "val": 0.5, "text": "Regen, Nebel und Nacht schwächen deine Verteidigung nur halb so stark.", "icon": "ui_water", "req": ["t_munition", "t_fallen"]},
	"t_moertel": {"branch": "tuerme", "tier": 3, "col": 2, "name": "Mörtel", "stat": "wall_hp", "val": 0.15, "text": "Mauern und Tore halten weitere 15 % mehr aus.", "icon": "ui_shield", "req": ["t_fallen"]},
	"t_doppel": {"branch": "tuerme", "tier": 4, "col": 0, "name": "Doppellader", "stat": "tower_rate", "val": 0.08, "text": "Türme feuern weitere 8 % schneller.", "icon": "ui_speed", "req": ["t_praezision"]},
	"t_panzer": {"branch": "tuerme", "tier": 4, "col": 2, "name": "Bunkerpanzer", "stat": "bunker_hp", "val": 0.20, "text": "Der Bunker hält 20 % mehr aus.", "icon": "ui_heart", "req": ["t_moertel"]},
	"t_meister": {"branch": "tuerme", "tier": 5, "col": 1, "name": "Meisterschützen", "stat": "tower_dmg", "val": 0.12, "text": "Türme machen 12 % mehr Schaden.", "icon": "ui_star", "req": ["t_doppel", "t_panzer"]},
	# ---- Wirtschaft
	"w_lager": {"branch": "wirtschaft", "tier": 0, "col": 1, "name": "Ordnung im Lager", "stat": "cap", "val": 0.10, "text": "Lager fassen 10 % mehr.", "icon": "ui_crate", "req": []},
	"w_saegen": {"branch": "wirtschaft", "tier": 1, "col": 0, "name": "Schärfere Sägen", "stat": "prod_basic", "val": 0.10, "text": "Holz und Stein: 10 % mehr Produktion.", "icon": "res_wood", "req": ["w_lager"]},
	"w_drohnen": {"branch": "wirtschaft", "tier": 1, "col": 2, "name": "Drohnen-Tuning", "stat": "build_time", "val": 0.06, "text": "Bauen geht 6 % schneller.", "icon": "ui_drone", "req": ["w_lager"]},
	"w_schrott": {"branch": "wirtschaft", "tier": 2, "col": 0, "name": "Schrottkunde", "stat": "prod_adv", "val": 0.10, "text": "Metall, Treibstoff und Energiezellen: 10 % mehr Produktion.", "icon": "res_metal", "req": ["w_saegen"]},
	"w_reparatur": {"branch": "wirtschaft", "tier": 2, "col": 2, "name": "Reparaturtrupp", "stat": "repair_cost", "val": 0.30, "text": "Reparieren kostet 30 % weniger.", "icon": "ui_wrench", "req": ["w_drohnen"]},
	"w_grosslager": {"branch": "wirtschaft", "tier": 3, "col": 0, "name": "Großlager", "stat": "cap", "val": 0.15, "text": "Lager fassen weitere 15 % mehr.", "icon": "ui_crate", "req": ["w_schrott"]},
	"w_lazarett": {"branch": "wirtschaft", "tier": 3, "col": 1, "name": "Feldlazarett", "stat": "heal_speed", "val": 1.0, "text": "Verletzte Bewohner werden doppelt so schnell gesund.", "icon": "ui_heart", "req": ["w_schrott", "w_reparatur"]},
	"w_schatz": {"branch": "wirtschaft", "tier": 3, "col": 2, "name": "Schatzsucher", "stat": "find_luck", "val": 1.0, "text": "Doppelte Chance auf seltene Funde beim Räumen.", "icon": "ui_clover", "req": ["w_reparatur"]},
	"w_band": {"branch": "wirtschaft", "tier": 4, "col": 0, "name": "Fließband", "stat": "prod_all", "val": 0.10, "text": "Alle Produktion: weitere 10 %.", "icon": "ui_gear", "req": ["w_grosslager"]},
	"w_bauleitung": {"branch": "wirtschaft", "tier": 4, "col": 2, "name": "Bauleitung", "stat": "build_time", "val": 0.10, "text": "Bauen geht weitere 10 % schneller.", "icon": "ui_build", "req": ["w_schatz"]},
	"w_beute": {"branch": "wirtschaft", "tier": 5, "col": 1, "name": "Plünderer", "stat": "flood_loot", "val": 0.20, "text": "Fluten bringen 20 % mehr Münzen.", "icon": "res_coins", "req": ["w_band", "w_bauleitung"]},
	# ---- Helden und Expedition
	"h_gurte": {"branch": "helden", "tier": 0, "col": 1, "name": "Tragegurte", "stat": "carry", "val": 0.08, "text": "Rucksack fasst 8 % mehr.", "icon": "ui_pack", "req": []},
	"h_ration": {"branch": "helden", "tier": 1, "col": 0, "name": "Feldration", "stat": "hero_hp", "val": 0.05, "text": "Helden haben 5 % mehr Leben.", "icon": "ui_heart", "req": ["h_gurte"]},
	"h_motor": {"branch": "helden", "tier": 1, "col": 2, "name": "Sparmotor", "stat": "fuel", "val": 0.08, "text": "Expeditionen brauchen 8 % weniger Treibstoff.", "icon": "ui_fuel", "req": ["h_gurte"]},
	"h_pflege": {"branch": "helden", "tier": 2, "col": 0, "name": "Waffenpflege", "stat": "hero_dmg", "val": 0.05, "text": "Helden machen 5 % mehr Schaden.", "icon": "ui_sword", "req": ["h_ration"]},
	"h_nase": {"branch": "helden", "tier": 2, "col": 2, "name": "Spürnase", "stat": "loot", "val": 0.08, "text": "8 % mehr Rohstoffe aus Expeditionen.", "icon": "ui_expedition", "req": ["h_motor"]},
	"h_polster": {"branch": "helden", "tier": 3, "col": 0, "name": "Schutzpolster", "stat": "hero_hp", "val": 0.08, "text": "Helden haben weitere 8 % mehr Leben.", "icon": "ui_vest", "req": ["h_pflege"]},
	"h_karte": {"branch": "helden", "tier": 3, "col": 1, "name": "Kartenkunde", "stat": "xp", "val": 0.10, "text": "10 % mehr Erfahrung.", "icon": "ui_map", "req": ["h_pflege", "h_nase"]},
	"h_esel": {"branch": "helden", "tier": 3, "col": 2, "name": "Lastesel", "stat": "carry", "val": 0.12, "text": "Rucksack fasst weitere 12 % mehr.", "icon": "ui_pack", "req": ["h_nase"]},
	"h_haende": {"branch": "helden", "tier": 4, "col": 0, "name": "Schnelle Hände", "stat": "reload", "val": 0.06, "text": "Nachladen geht 6 % schneller.", "icon": "ui_bullet", "req": ["h_polster"]},
	"h_profi": {"branch": "helden", "tier": 4, "col": 2, "name": "Expeditionsprofi", "stat": "fuel", "val": 0.10, "text": "Expeditionen brauchen weitere 10 % weniger Treibstoff.", "icon": "ui_fuel", "req": ["h_esel"]},
	"h_mut": {"branch": "helden", "tier": 5, "col": 1, "name": "Heldenmut", "stat": "hero_dmg", "val": 0.10, "text": "Helden machen weitere 10 % mehr Schaden.", "icon": "ui_star", "req": ["h_haende", "h_profi"]},
}
## Kosten je Reihe: Münzen, Menge der beiden Ast-Rohstoffe, Sternsplitter. Zeit in Sekunden.
const TIER_COST := [
	{"coins": 250, "a": 150, "b": 0, "shards": 0, "time": 180.0},
	{"coins": 800, "a": 350, "b": 120, "shards": 1, "time": 1200.0},
	{"coins": 1600, "a": 700, "b": 250, "shards": 2, "time": 3600.0},
	{"coins": 3200, "a": 1200, "b": 450, "shards": 3, "time": 10800.0},
	{"coins": 6000, "a": 2000, "b": 800, "shards": 5, "time": 28800.0},
	{"coins": 12000, "a": 3200, "b": 1300, "shards": 8, "time": 57600.0},
]
## Ab dieser Laborstufe ist eine Reihe erforschbar (Reihe 0 geht auch ohne Labor über die Werkstatt).
const TIER_LAB := [0, 1, 1, 2, 3, 4]
const LAB_SPEED := 0.08                 # je Laborstufe über 1: Forschung 8 % schneller
const PRELAB_BUILDING := "werkstatt"    # Vorraum: die ersten drei Knoten (Reihe 0) über die Tüftelecke der Werkstatt

# ================================================================= Wetter der Flut
## Beim Flutstart festgelegt (Vorhersage im Flut-Dialog). chance = Anteil bei der Auswahl, Nacht kommt von der Tageszeit.
const WEATHER := {
	"klar": {"name": "Klar", "icon": "ui_sun", "chance": 0.5, "text": "Keine Wirkung."},
	"regen": {"name": "Regen", "icon": "ui_rain", "chance": 0.3, "rate": 0.10, "fire": 0.30, "text": "Türme feuern 10 % langsamer, Feuer brennt 30 % schwächer."},
	"nebel": {"name": "Nebel", "icon": "ui_fog", "chance": 0.2, "range": 0.20, "fog": 0.0075, "text": "Türme sehen 20 % weniger weit."},
}
const NIGHT := {"name": "Nacht", "icon": "ui_moon", "hp": 0.10, "loot": 0.10, "text": "Gegner haben 10 % mehr Leben, dafür 10 % mehr Beute."}

# ================================================================= Belagerung
const BREACH_REFRESH := 5.0             # Brecher-Feld (Wegsuche zur schwächsten Mauerstelle) so oft neu (s)
const BREACH_SLICE_US := 450            # Rechenzeit je Bild für die Felder der Belagerung (µs)
const BREACH_WALL_BASE := 6.0           # Kosten einer Mauerzelle für Brecher: Grundwert …
const BREACH_WALL_HP := 0.06            # … plus je Lebenspunkt (Holz voll ~22, Metall voll ~92, angeschlagen weniger)
const BREACH_BUILDING := 60.0           # Gebäude meiden Brecher (sie wollen durch die Mauer)
const AIR_AVOID := 7.0                  # Zusatzkosten je Feld in Reichweite der Luftabwehr (Umweg lohnt bis etwa 7 Felder je Feld)
const AIR_MARGIN := 2.0                 # Sicherheitsabstand zur Reichweite (m)
const LADDER_WEEK := 3                  # ab dieser Woche tragen Schleimlinge Leitern
const LADDER_CHANCE := 0.06
const LADDER_MAX := [2, 8]              # je Welle: 2 + Woche/3, höchstens 8
const LADDER_TIME := [0.7, 2.6, 0.7]    # anlegen, klettern, abspringen (s)
const LADDER_STAY := 6.0                # so lange lehnt die Leiter danach noch an der Mauer
const LADDER_POOL := 10

# ================================================================= Flut-Rückblick
const REPLAY_KEEP := 3

# ================================================================= Mauer-Reparatur, Funde, Verletzte, Wasser
const WALL_DMG_KEEP := true             # Mauern behalten nach der Flut ihren Schaden
const WALL_RUBBLE := 0.12               # zerstörte Mauerstücke stehen danach mit so viel Leben
const REPAIR_WALL := [{"wood": 12}, {"stone": 20}, {"metal": 20}]     # volle Reparatur eines Stücks je Bauart
const REPAIR_BUILDING_COINS := 0.25     # Gebäude: Anteil der Münzkosten der Stufe × fehlender Anteil
const FIND_CHANCE := 0.12               # Hindernis enthält einen Fund (glitzert)
const FIND_KINDS := [["chest", 0.4], ["gems", 0.4], ["bp", 0.2]]
const FIND_GEMS := [5, 12]
const BP_FRAGS := 3                     # so viele Bauplan-Splitter ergeben einen Bauplan
const INJURY_TIME := 1800.0             # Heilzeit eines verletzten Bewohners (s, Feldlazarett halbiert)
const INJURY_SPEED := 0.55              # verletzt: so viel Lauftempo
const INJURY_CARE_GAP := 150.0          # so oft geht ein Verletzter zum Verarzten in den Bunker (s)
const INJURY_CARE := 0.15               # jeder Besuch verkürzt die Restzeit um diesen Anteil der Heilzeit
const INJURY_HARD_HP := 0.5             # harte Flut: Bunker unter diesem Anteil Leben …
const INJURY_HARD_LOST := 3             # … oder so viele Gebäude zerstört …
const INJURY_HARD_WALLS := 12           # … oder so viele Mauerstücke gebrochen

# ================================================================= Mitteilungen, Bewertung
const NOTIFY_KINDS := [["build", "Bau fertig"], ["flood", "Flut in 1 Stunde"], ["gift", "Tagesgeschenk"], ["research", "Forschung fertig"]]
const NOTIFY_TEXT := {
	"build": ["Rustwall", "%s ist fertig gebaut!"],
	"flood": ["Rustwall", "Die Flut kommt in einer Stunde – sind die Mauern bereit?"],
	"gift": ["Rustwall", "Dein Tagesgeschenk wartet im Bunker."],
	"research": ["Rustwall", "Forschung fertig: %s"],
}
const RATE_MAX_ASK := 2
