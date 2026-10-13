extends RefCounted
## V6 Paket M – Spielmodi: alle Zahlen und Texte für den Turm der Prüfungen (50 Stockwerke), den Überlebensmodus
## (endlose Wellen, Verstärkungen), den Clan-Raid (Schleim-Leviathan), die Höhlen der Expedition und die Ladefläche
## der Pritsche. Die Regeln stehen in src/modi.gd, die Kampfwelt in src/modi_arena.gd, die Höhle in src/cave_world.gd.

# ================================================================= Turm der Prüfungen (Kap. 5.3)
const TOWER_FLOORS := 50
## Je 10 Stockwerke ein eigener Saal (Blender: mt_floor_<n>, mt_wall_<n>, mt_pillar_<n>).
const TOWER_BLOCKS := [
	{"name": "Moosgewölbe", "col": Color("8BE04A"), "fog": Color("2E3A2C"), "ground": Color("5E6A54"), "ground2": Color("4A5644"), "sun": Color("FFF0CF"), "amb": "forst"},
	{"name": "Sandsteinhalle", "col": Color("FFC93E"), "fog": Color("4A3A26"), "ground": Color("B9874A"), "ground2": Color("9A6E3C"), "sun": Color("FFE6B0"), "amb": "staub"},
	{"name": "Frostkammer", "col": Color("6FE6FF"), "fog": Color("2A3A52"), "ground": Color("8FAFD0"), "ground2": Color("6F8FB4"), "sun": Color("F4F8FF"), "amb": "frost"},
	{"name": "Rostschmiede", "col": Color("FF9A3A"), "fog": Color("3A2E2A"), "ground": Color("5E5048"), "ground2": Color("4A3E38"), "sun": Color("FFD8B0"), "amb": "staub"},
	{"name": "Glutspitze", "col": Color("FF5A2A"), "fog": Color("2A1A1C"), "ground": Color("2A2228"), "ground2": Color("1E181C"), "sun": Color("FFC8A0"), "amb": "vulkan"},
]
const TOWER_RADIUS := 15.0            # Spielfläche (Meter)
const TOWER_GATES := 4                # Tore, aus denen die Gegner kommen
const TOWER_START_LEVEL := 1          # Heldenstufe für Stockwerk 1
const TOWER_ELITE_HP := 0.6
const TOWER_ELITE_DMG := 0.8
const TOWER_MELEE_R := 6.0            # „Nur Nahkampf“: Gegner sind nur so nah am Helden verwundbar
const TOWER_NOHEAL_HP := 0.6          # „Ohne Heilung“: der Held beginnt mit so viel Leben
const TOWER_FAST := 1.25              # „Flink“: Tempo der Gegner
const TOWER_GEN_HP := 900.0           # Leben des Generators auf Stockwerk 1 (wächst je Stockwerk um 10 %)
const TOWER_BREAK := 3.0              # Pause zwischen zwei Wellen
const TOWER_STAR2_HP := 0.5           # Stern 2: mindestens so viel Leben am Ende
const TOWER_STAR3_HP := 0.8           # Stern 3 bei Aufgaben ohne Zeitvorgabe (Überleben): so viel Leben am Ende

## Aufgaben: clear (alle Wellen besiegen), survive (t Sekunden überleben), defend (Generator schützen), timed (in t Sekunden
## besiegen), boss (Endgegner des Saals). waves: je Welle [[Rolle, Anzahl(, Familie)], ...]. Rollen: mass, fast, tank, ranged,
## air, special, healer, shield, brood, miniboss, elite. mods: noskill (keine Fähigkeiten), melee (nur Nahkampf), noheal
## (ohne Heilung), fast (flinke Gegner). par: Zeit für den dritten Stern (Sekunden). survive: spawn = Rollen, rate = Gegner/s.
const FLOORS := [
	# ---- 1–10 Moosgewölbe (Schleime)
	{"name": "Erste Schritte", "task": "clear", "fam": "schleim", "waves": [[["mass", 8]]], "par": 30},
	{"name": "Flinke Füße", "task": "survive", "fam": "schleim", "t": 40, "spawn": ["fast"], "rate": 0.8, "max": 12},
	{"name": "Doppelschlag", "task": "clear", "fam": "schleim", "waves": [[["mass", 8]], [["mass", 8], ["fast", 3]]], "par": 50},
	{"name": "Spuckerhalle", "task": "clear", "fam": "schleim", "waves": [[["ranged", 4], ["mass", 6]], [["ranged", 6], ["mass", 6]]], "par": 60},
	{"name": "Der erste Generator", "task": "defend", "fam": "schleim", "waves": [[["mass", 10]], [["mass", 8], ["fast", 4]], [["mass", 10], ["tank", 1]]], "par": 80},
	{"name": "Faustkampf", "task": "clear", "fam": "schleim", "waves": [[["mass", 5]], [["mass", 6], ["shield", 2]]], "mods": ["melee"], "par": 55},
	{"name": "Flitzerjagd", "task": "timed", "fam": "schleim", "t": 40, "waves": [[["fast", 14]]], "par": 25},
	{"name": "Schamanen-Zirkel", "task": "clear", "fam": "schleim", "waves": [[["special", 2], ["mass", 10]], [["special", 3], ["mass", 8], ["air", 3]]], "par": 70},
	{"name": "Koloss ohne Tricks", "task": "clear", "fam": "schleim", "waves": [[["miniboss", 1], ["mass", 6]]], "mods": ["noskill"], "par": 70},
	{"name": "Dicker Bert", "task": "boss", "fam": "schleim", "boss": "schleim_boss", "waves": [[["mass", 6]]], "par": 120},
	# ---- 11–20 Sandsteinhalle (Waldgeister, Wüstenmonster)
	{"name": "Pilzgarten", "task": "clear", "fam": "wald", "waves": [[["mass", 10]], [["mass", 8], ["ranged", 3]]], "par": 55},
	{"name": "Wolfsrudel", "task": "survive", "fam": "wald", "t": 45, "spawn": ["fast", "mass", "mass"], "rate": 0.8, "max": 10},
	{"name": "Zapfenregen", "task": "clear", "fam": "wald", "waves": [[["ranged", 6], ["mass", 6]], [["ranged", 8], ["healer", 1]]], "par": 60},
	{"name": "Generator im Wald", "task": "defend", "fam": "wald", "waves": [[["mass", 10]], [["mass", 8], ["fast", 5]], [["tank", 2], ["mass", 8]]], "par": 85},
	{"name": "Eichbart ohne Tricks", "task": "clear", "fam": "wald", "waves": [[["miniboss", 1], ["mass", 8]]], "mods": ["noskill"], "par": 75},
	{"name": "Käferschwarm", "task": "timed", "fam": "wueste", "t": 60, "waves": [[["mass", 16]], [["mass", 10], ["fast", 4]]], "par": 40},
	{"name": "Nahkampf im Sand", "task": "clear", "fam": "wueste", "waves": [[["mass", 8]], [["tank", 2], ["mass", 6]]], "mods": ["melee"], "par": 65},
	{"name": "Geier am Himmel", "task": "clear", "fam": "wueste", "waves": [[["air", 6], ["mass", 6]], [["air", 8], ["ranged", 3]]], "par": 60},
	{"name": "Gekrönte Wüste", "task": "clear", "fam": "wueste", "waves": [[["elite", 1], ["mass", 4]], [["elite", 2], ["mass", 4]]], "par": 70},
	{"name": "Rostbrocken", "task": "boss", "fam": "wueste", "boss": "boss_wueste", "waves": [[["mass", 6], ["ranged", 2]]], "par": 130},
	# ---- 21–30 Frostkammer (Untote, Eiswesen)
	{"name": "Deckratten", "task": "survive", "fam": "untote", "t": 60, "spawn": ["fast", "fast", "mass"], "rate": 1.2, "max": 16},
	{"name": "Kanonendeck", "task": "clear", "fam": "untote", "waves": [[["ranged", 4], ["mass", 8]], [["ranged", 5], ["tank", 2]]], "par": 70},
	{"name": "Bootsmann ohne Tricks", "task": "clear", "fam": "untote", "waves": [[["miniboss", 1], ["mass", 10]]], "mods": ["noskill"], "par": 80},
	{"name": "Generator im Nebel", "task": "defend", "fam": "untote", "waves": [[["mass", 12]], [["fast", 8], ["mass", 6]], [["tank", 2], ["shield", 3], ["mass", 8]]], "par": 90},
	{"name": "Eiswölfe", "task": "timed", "fam": "eis", "t": 45, "waves": [[["fast", 18]]], "par": 30, "mods": ["fast"]},
	{"name": "Frostfaust", "task": "clear", "fam": "eis", "waves": [[["mass", 8]], [["mass", 6], ["tank", 1]]], "mods": ["melee"], "par": 70},
	{"name": "Lawine", "task": "survive", "fam": "eis", "t": 70, "spawn": ["mass", "special", "fast"], "rate": 1.3, "max": 18, "mods": ["fast"]},
	{"name": "Kristallschützen", "task": "clear", "fam": "eis", "waves": [[["ranged", 8]], [["ranged", 6], ["shield", 3], ["mass", 6]]], "par": 70},
	{"name": "Mammut ohne Tricks", "task": "clear", "fam": "eis", "waves": [[["miniboss", 1], ["mass", 10]]], "mods": ["noskill"], "par": 85},
	{"name": "Frostbrocken", "task": "boss", "fam": "eis", "boss": "boss_eis", "waves": [[["mass", 8], ["ranged", 2]]], "par": 140},
	# ---- 31–40 Rostschmiede (Mutanten, Magma-Wesen)
	{"name": "Giftkröten", "task": "clear", "fam": "mutanten", "waves": [[["mass", 14]], [["mass", 10], ["ranged", 4]]], "par": 70},
	{"name": "Egelschwarm", "task": "survive", "fam": "mutanten", "t": 70, "spawn": ["fast", "mass"], "rate": 1.5, "max": 20},
	{"name": "Generator in der Schmiede", "task": "defend", "fam": "mutanten", "waves": [[["mass", 12]], [["fast", 8], ["mass", 6]], [["tank", 2], ["air", 4]], [["mass", 12], ["special", 2]]], "par": 110},
	{"name": "Ohne Heilung", "task": "clear", "fam": "mutanten", "waves": [[["mass", 12]], [["tank", 3], ["mass", 8]]], "mods": ["noheal"], "par": 75},
	{"name": "Panzerkröte ohne Tricks", "task": "clear", "fam": "mutanten", "waves": [[["miniboss", 1], ["mass", 10]]], "mods": ["noskill"], "par": 90},
	{"name": "Lavaschnecken", "task": "clear", "fam": "magma", "waves": [[["mass", 14]], [["mass", 10], ["tank", 2]]], "par": 75},
	{"name": "Glutspucker-Halle", "task": "timed", "fam": "magma", "t": 60, "waves": [[["ranged", 8], ["mass", 8]]], "par": 40},
	{"name": "Glutfaust", "task": "clear", "fam": "magma", "waves": [[["mass", 10]], [["mass", 8], ["tank", 3]]], "mods": ["melee"], "par": 80},
	{"name": "Elite-Schmiede", "task": "clear", "fam": "magma", "waves": [[["elite", 3]], [["elite", 3], ["healer", 1]]], "par": 85},
	{"name": "Der Schlund", "task": "boss", "fam": "mutanten", "boss": "boss_mutanten", "waves": [[["mass", 8], ["ranged", 3]]], "par": 150},
	# ---- 41–50 Glutspitze (Dämonen und alle Familien)
	{"name": "Höllenwichtel", "task": "survive", "fam": "daemonen", "t": 75, "spawn": ["mass", "fast"], "rate": 1.6, "max": 22, "mods": ["fast"]},
	{"name": "Feuerspeier", "task": "clear", "fam": "daemonen", "waves": [[["ranged", 8], ["mass", 8]], [["ranged", 10], ["tank", 2]]], "par": 80},
	{"name": "Generator in der Glut", "task": "defend", "fam": "daemonen", "waves": [[["mass", 12]], [["fast", 8]], [["tank", 2], ["air", 3]], [["mass", 10], ["special", 2]]], "par": 120},
	{"name": "Kettenteufel ohne Tricks", "task": "clear", "fam": "daemonen", "waves": [[["miniboss", 1], ["mass", 12]]], "mods": ["noskill"], "par": 95},
	{"name": "Faust ohne Heilung", "task": "clear", "fam": "daemonen", "waves": [[["mass", 10]], [["mass", 10], ["tank", 2]]], "mods": ["melee", "noheal"], "par": 85},
	{"name": "Gemischte Garde", "task": "clear", "fam": "wald", "waves": [[["mass", 8, "wald"]], [["mass", 8, "eis"], ["ranged", 3, "eis"]], [["mass", 8, "daemonen"], ["tank", 2, "magma"]]], "par": 100},
	{"name": "Zeitrennen", "task": "timed", "fam": "schleim", "t": 50, "waves": [[["fast", 12, "schleim"]], [["fast", 12, "eis"]], [["fast", 10, "daemonen"]]], "par": 38, "mods": ["fast"]},
	{"name": "Elite-Gipfel", "task": "clear", "fam": "daemonen", "waves": [[["elite", 3, "daemonen"]], [["elite", 3, "magma"]], [["elite", 2, "eis"], ["healer", 2, "eis"]]], "par": 110},
	{"name": "Letzte Wacht", "task": "defend", "fam": "magma", "waves": [[["mass", 12, "magma"]], [["fast", 10, "eis"]], [["tank", 3, "untote"], ["air", 5, "wueste"]], [["mass", 12, "daemonen"]], [["miniboss", 1, "magma"], ["mass", 8, "magma"]]], "par": 150},
	{"name": "Der Schleimkönig", "task": "boss", "fam": "daemonen", "boss": "boss_daemonen", "waves": [[["miniboss", 1], ["mass", 8]]], "par": 170},
]

## Belohnung beim ersten Abschluss eines Stockwerks (Münzen immer, dazu je nach Stockwerk mehr).
static func floor_reward(f: int) -> Dictionary:
	var out := {"coins": 150 + 60 * f}
	if f % 3 == 0:
		out["parts"] = 10 + f
	if f % 10 == 0:
		out["gems"] = 25
		out["chest"] = "boss"
	elif f % 5 == 0:
		out["gems"] = 10
	return out


## Sternstufen: so viele Sterne insgesamt -> Belohnung (einmalig).
const STAR_REWARDS := [[20, {"gems": 15}], [45, {"gems": 25, "chest": "level"}], [75, {"gems": 35}], [105, {"gems": 50, "chest": "flood_silver"}], [150, {"gems": 100, "chest": "flood_gold"}]]

static func floor_hp(f: int) -> float:
	return 1.0 + 0.13 * (f - 1)                 # Stockwerk 50: × 7,4 (etwa Schleimkrater/Vulkaninsel)


static func floor_dmg(f: int) -> float:
	return 1.0 + 0.03 * (f - 1)


## Empfohlene Heldenstufe (nur Anzeige).
static func floor_level(f: int) -> int:
	return clampi(int(round(f * 0.8)), TOWER_START_LEVEL, 40)


## Wochenpunkte für einen Lauf: je Stockwerk zählt der beste Lauf der Woche.
static func floor_points(f: int, stars: int) -> int:
	return f * 10 + stars * 20


# ================================================================= Überlebensmodus (Kap. 5.3)
const SURV_HALF := 30.0               # Karte 60 × 60 m
const SURV_BREAK := 7.0               # Pause zwischen den Wellen
const SURV_PICK_EVERY := 5            # alle 5 Wellen eine Verstärkung wählen
const SURV_FAMS := ["schleim", "wald", "wueste", "untote", "mutanten", "eis", "daemonen", "magma", "maschinen"]
const SURV_START_LIVES := 0           # Wiedereinstiege zu Beginn (mehr nur über Verstärkungen)
const SURV_MAX_ALIVE := 70
## Punkte je besiegtem Gegner (normal, Elite, Miniboss, Boss) und je geschaffter Welle (× Wellennummer)
const SURV_PTS := {"kill": 10, "elite": 60, "miniboss": 200, "boss": 600, "wave": 50}
## Belohnung beim ersten Erreichen dieser Welle (einmalig)
const SURV_WAVE_REWARDS := [[5, {"gems": 5}], [10, {"gems": 10, "chest": "level"}], [15, {"gems": 15}], [20, {"gems": 25, "chest": "boss"}], [30, {"gems": 40, "chest": "flood_gold"}]]
const SURV_COIN_K := 0.25             # Münzen am Ende = Punkte × 0,25

## Verstärkungen (roguelike): max = so oft wählbar. Wirkung siehe modi_arena.gd (_apply_buffs).
const UPGRADES := {
	"wucht": {"name": "Wucht", "text": "+20 % Schaden", "icon": "ui_sword", "max": 5},
	"panzer": {"name": "Panzerung", "text": "+25 % Leben, heilt sofort voll", "icon": "ui_heart", "max": 4},
	"tempo": {"name": "Sprinter", "text": "+10 % Lauftempo", "icon": "ui_boot", "max": 3},
	"salve": {"name": "Salve", "text": "+15 % Feuerrate", "icon": "ui_bullet", "max": 4},
	"fokus": {"name": "Fokus", "text": "Fähigkeiten laden 30 % schneller", "icon": "ui_bolt", "max": 3},
	"vampir": {"name": "Lebensraub", "text": "Jeder besiegte Gegner heilt 2 % Leben", "icon": "ui_clover", "max": 3},
	"krit": {"name": "Scharfes Auge", "text": "+8 % kritische Treffer", "icon": "ui_target", "max": 3},
	"geschuetz": {"name": "Geschütz", "text": "Ein MG-Turm hilft in jeder Welle", "icon": "ui_drone", "max": 2},
	"frost": {"name": "Frostaura", "text": "Gegner sind 12 % langsamer", "icon": "ui_snow", "max": 3},
	"leben": {"name": "Zweites Leben", "text": "+1 Wiedereinstieg", "icon": "ui_shield", "max": 2},
	"gold": {"name": "Goldfieber", "text": "+25 % Punkte", "icon": "ui_star", "max": 3},
}
const UPGRADE_ORDER := ["wucht", "panzer", "tempo", "salve", "fokus", "vampir", "krit", "geschuetz", "frost", "leben", "gold"]

static func surv_count(w: int) -> int:
	return mini(6 + 3 * w, 60)


static func surv_hp(w: int) -> float:
	return 0.9 + 0.14 * (w - 1) + 0.004 * pow(float(w - 1), 2.0)


static func surv_dmg(w: int) -> float:
	return 1.0 + 0.05 * (w - 1)


static func surv_fam(w: int) -> String:
	return String(SURV_FAMS[int((w - 1) / 5) % SURV_FAMS.size()])


# ================================================================= Clan-Raid (Kap. 5.3 / 14)
const RAID_HP_PER_MEMBER := 260000    # Leben des Leviathans je Clanmitglied (mit dir)
const RAID_TRIES := 3                 # Angriffe je Tag und Mitglied
const RAID_HIT_MAX := 400000          # höchster anrechenbarer Schaden eines Angriffs (Schutz gegen Fehler)
const RAID_TIERS := [25, 50, 75, 100] # Prozent des Lebens
const RAID_REWARDS := [{"coins": 1500, "gems": 10}, {"chest": "clan", "gems": 15}, {"parts": 80, "gems": 20}, {"chest": "boss", "gems": 40}]
## Simulierte Mitglieder: Schaden je Angriff = Grundwert + Stufe × Faktor; Teilnahme 40–100 %
const RAID_SIM_BASE := 9000.0
const RAID_SIM_LEVEL := 450.0

# ================================================================= Höhlen (Kap. 4.3)
const CAVE_FROM_AREA := 1             # ab Gebiet 2 (Kiefernforst)
const CAVE_MAX := 2                   # 1–2 Eingänge je Besuch
## Raum-Thema je Gebiet (die übrigen Gebiete nutzen das nächstliegende Thema)
const CAVE_THEME := {"gruental": "wurzel", "forst": "wurzel", "staub": "sand", "kueste": "sand", "sumpf": "wurzel", "frost": "eis", "krater": "glut", "vulkan": "glut", "stadt": "sand"}
const CAVE_THEMES := {
	"wurzel": {"name": "Wurzelhöhle", "fog": Color("1A1612"), "amb": Color(0.55, 0.5, 0.42), "torch": Color(1.0, 0.72, 0.38), "ground": Color("4E4438"), "ore": {"wood": 30.0, "shards": 2.0}},
	"sand": {"name": "Sandsteingrotte", "fog": Color("201810"), "amb": Color(0.6, 0.52, 0.4), "torch": Color(1.0, 0.78, 0.45), "ground": Color("8A6A44"), "ore": {"metal": 26.0, "parts": 6.0}},
	"eis": {"name": "Eisgrotte", "fog": Color("101826"), "amb": Color(0.45, 0.55, 0.7), "torch": Color(0.75, 0.9, 1.0), "ground": Color("5F84B0"), "ore": {"cells": 14.0, "shards": 2.0}},
	"glut": {"name": "Glutstollen", "fog": Color("1A0E0C"), "amb": Color(0.6, 0.4, 0.35), "torch": Color(1.0, 0.55, 0.3), "ground": Color("2E2628"), "ore": {"cells": 10.0, "shards": 3.0, "metal": 12.0}},
}
const CAVE_ROOMS := [3, 5]            # Räume je Höhle (Eingangsraum mitgezählt)
const CAVE_ROOM := 14.0               # Kantenlänge eines Raums (Meter)
const CAVE_HALL := 6.0                # Länge eines Gangs
const CAVE_HALL_W := 4.0
const CAVE_GUARDS := [3, 5]           # Gegner je Raum (ohne Eingangsraum), × Schwierigkeit
const CAVE_ENTER_HOLD := 1.0          # so lange im Eingang stehen, bis es hineingeht
const CAVE_ORE_TIME := 3.0            # so lange an der Erzader stehen
const CAVE_CHEST_COINS := 120.0       # Feldmünzen der Truhe (× Gebietsfaktor)
const CAVE_CHEST_FIND := 0.5          # Chance auf eine Fundkiste aus der Truhe
const CAVE_HP := 1.15                 # Leben der Höhlengegner gegenüber draußen

# ================================================================= Ladefläche der Pritsche (Kap. 4.3)
const BED_CAP := 400.0                # Tragkraft der Ladefläche (Gewicht wie im Rucksack, Grundrucksack 220), +15 % je Ausbau „Ladefläche“
const BED_REACH := 4.5                # so nah am Fahrzeug lädt der Held den Rucksack um
const BED_DEPOT := 7.0                # so nah am Depot (Fahrzeug) wird die Ladefläche abgeladen
const BED_SLOTS := [1, 4, 3, 0.33]    # je Seite des Geschützes: 1 Spalte × 4 Reihen × 3 Lagen
