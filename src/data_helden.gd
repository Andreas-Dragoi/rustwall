extends RefCounted
## Paket H (V6): Zahlen und Texte für Ausrüstungs-Sets, Waffenmodule, Gift, Wurfwaffen, Gesichter und Laufstile.
## Die Spielregeln dazu stehen in src/helden.gd, die Modelle in blender/gear_sets.py und blender/weapon_mods.py.

# ---------------------------------------------------------------- Ausrüstungs-Sets
## Jedes Set hat drei Teile (Helm, Weste, Glücksbringer). Ein Teil gibt wie bisher den Wert seines Platzes
## (D.GEAR: Helm = Leben, Weste = Tragemenge, Glücksbringer = Fähigkeiten laden schneller); dazu kommen Set-Boni
## ab zwei (b2) und drei (b3) angelegten Teilen desselben Sets. Boni nutzen die Talent-Schlüssel aus P.hero_stats
## (dmg, hp, speed, cdr, reload, range, pickup, tower, heal, ult, crit, carry, burn) und zusätzlich:
##   elem_<element> = Schaden mit Waffen dieses Elements, dr = weniger Schaden, leech = Lebensraub.
## hero = der Held, zu dem das Set am besten passt (nur Hinweis), color/trim = Farben des Modells.
const SET_ORDER := ["bote", "feuerwehr", "bau", "erfinder", "jaeger", "fest", "tiefsee"]
const SETS := {
	"bote": {"name": "Postbote", "hero": "jona", "color": Color("2E6EB8"), "trim": Color("FFD23E"),
		"pieces": {"helmet": "Postmütze", "vest": "Posttaschen-Weste", "charm": "Posthorn"},
		"b2": {"pickup": 0.2}, "b3": {"speed": 0.06, "dmg": 0.06},
		"t2": "+20 % Sammelradius", "t3": "+6 % Tempo und +6 % Schaden"},
	"feuerwehr": {"name": "Löschzug", "hero": "mika", "color": Color("D54144"), "trim": Color("E0B02E"),
		"pieces": {"helmet": "Feuerwehrhelm", "vest": "Brandschutzjacke", "charm": "Florian-Medaille"},
		"b2": {"burn": 0.25}, "b3": {"elem_feuer": 0.15, "hp": 0.08},
		"t2": "+25 % Brenndauer", "t3": "Feuer-Waffen +15 % Schaden, +8 % Leben"},
	"bau": {"name": "Baustelle", "hero": "bruno", "color": Color("F08A1E"), "trim": Color("F4F6FA"),
		"pieces": {"helmet": "Bauhelm mit Lampe", "vest": "Warnweste", "charm": "Wasserwaage"},
		"b2": {"tower": 0.1}, "b3": {"hp": 0.12, "heal": 0.15},
		"t2": "+10 % Turmschaden in der Nähe", "t3": "+12 % Leben, +15 % Heilung"},
	"erfinder": {"name": "Tüftlerin", "hero": "ada", "color": Color("9A5CE0"), "trim": Color("7FE3FF"),
		"pieces": {"helmet": "Schweißerhaube", "vest": "Laborkittel", "charm": "Zahnrad-Anhänger"},
		"b2": {"cdr": 0.08}, "b3": {"ult": 0.2, "elem_blitz": 0.1},
		"t2": "Fähigkeiten laden 8 % schneller", "t3": "+20 % Spezialfähigkeit, Blitz-Waffen +10 % Schaden"},
	"jaeger": {"name": "Kundschafter", "hero": "yuki", "color": Color("3FA35A"), "trim": Color("8A6A4A"),
		"pieces": {"helmet": "Federhut", "vest": "Tarnweste", "charm": "Falkenfeder"},
		"b2": {"crit": 0.05}, "b3": {"range": 0.1, "dmg": 0.06},
		"t2": "+5 % Volltreffer", "t3": "+10 % Reichweite und +6 % Schaden"},
	"fest": {"name": "Talfest", "hero": "greta", "color": Color("F07AB4"), "trim": Color("FFD23E"),
		"pieces": {"helmet": "Partyhut", "vest": "Glitzerweste", "charm": "Glückskeks"},
		"b2": {"reload": 0.08}, "b3": {"elem_explosion": 0.12, "cdr": 0.05},
		"t2": "−8 % Nachladezeit", "t3": "Explosions-Waffen +12 % Schaden, Fähigkeiten 5 % schneller"},
	"tiefsee": {"name": "Tiefsee", "hero": "nele", "color": Color("1FA6B8"), "trim": Color("C8A24A"),
		"pieces": {"helmet": "Taucherhelm", "vest": "Bleiweste", "charm": "Muschelkette"},
		"b2": {"elem_wasser": 0.1, "elem_eis": 0.1}, "b3": {"dr": 0.1, "hp": 0.08},
		"t2": "Wasser- und Eis-Waffen +10 % Schaden", "t3": "10 % weniger Schaden, +8 % Leben"},
}
## Altstände: Ausrüstung ohne Set bekommt beim Laden ein Set (gleichmäßig nach Nummer verteilt).
const SET_LEGACY := true
## Rüstet ein Held einen Helm aus, verschwindet seine eigene Kopfbedeckung (Mesh "hat" im Heldenmodell).
const HIDE_HAT := true

# ---------------------------------------------------------------- Waffenmodule
## Sockel je Seltenheit (Gewöhnlich, Selten, Episch, Legendär).
const SOCKETS := [1, 1, 2, 3]
## Module: fx wirkt auf die Waffe (hero.gd/helden.gd): damage/rpm/range/mag = Anteil mehr, reload = Anteil weniger,
## spread = Anteil mehr (negativ = genauer), crit = zusätzliche Volltreffer-Chance, knock = Anteil mehr Rückstoß;
## burn, poison, chill (Sekunden), freeze, stun_ch (Chance), stun (Sekunden) = Wirkung beim Treffer.
## modes = Schussarten, in die das Modul passt ([] = alle außer Geschützen); mag = nur Waffen mit Magazin.
## core = Element-Kern (höchstens einer je Waffe). vis = wo es am Modell sitzt (muzzle, top, under, side, core, head, "").
## cost = Herstellen in der Werkstatt.
const MODULE_ORDER := ["silencer", "scope", "loader", "drum", "grip", "weight", "core_feuer", "core_eis", "core_gift", "core_blitz"]
const MODULES := {
	"silencer": {"name": "Schalldämpfer", "text": "Streut halb so stark, +6 % Volltreffer", "fx": {"spread": -0.5, "crit": 0.06},
		"modes": ["hitscan", "bolt", "charge", "multi"], "vis": "muzzle", "cost": {"coins": 450, "parts": 14, "metal": 40}},
	"scope": {"name": "Zielfernrohr", "text": "+15 % Reichweite, +4 % Volltreffer", "fx": {"range": 0.15, "crit": 0.04},
		"modes": ["hitscan", "bolt", "charge", "multi", "proj", "seek", "homing", "chain", "beam"], "vis": "top", "cost": {"coins": 500, "parts": 16, "metal": 30}},
	"loader": {"name": "Schnelllader", "text": "−25 % Nachladezeit", "fx": {"reload": 0.25}, "mag": true, "vis": "side",
		"cost": {"coins": 400, "parts": 12, "wood": 60}},
	"drum": {"name": "Trommelmagazin", "text": "+50 % Magazin, −5 % Feuerrate", "fx": {"mag": 0.5, "rpm": -0.05}, "mag": true, "vis": "under",
		"cost": {"coins": 550, "parts": 18, "metal": 60}},
	"grip": {"name": "Stabilisator", "text": "+8 % Feuerrate", "fx": {"rpm": 0.08}, "vis": "",
		"cost": {"coins": 350, "parts": 10, "stone": 60}},
	"weight": {"name": "Wuchtgewicht", "text": "+15 % Schaden, +30 % Rückstoß", "fx": {"damage": 0.15, "knock": 0.3},
		"modes": ["swing", "thrust", "slam", "nova"], "vis": "head", "cost": {"coins": 450, "parts": 14, "stone": 120}},
	"core_feuer": {"name": "Element-Kern Feuer", "text": "Treffer setzen 2 s in Brand", "fx": {"burn": 2.0}, "core": "feuer", "vis": "core",
		"cost": {"coins": 700, "parts": 20, "fuel": 60}},
	"core_eis": {"name": "Element-Kern Eis", "text": "Treffer verlangsamen 1,5 s, 5 % Chance einzufrieren", "fx": {"chill": 1.5, "freeze": 0.05}, "core": "eis", "vis": "core",
		"cost": {"coins": 700, "parts": 20, "cells": 20}},
	"core_gift": {"name": "Element-Kern Gift", "text": "Treffer vergiften 4 s", "fx": {"poison": 4.0}, "core": "gift", "vis": "core",
		"cost": {"coins": 700, "parts": 20, "fuel": 40, "wood": 80}},
	"core_blitz": {"name": "Element-Kern Blitz", "text": "8 % Chance zu betäuben (0,5 s)", "fx": {"stun_ch": 0.08, "stun": 0.5}, "core": "blitz", "vis": "core",
		"cost": {"coins": 700, "parts": 20, "cells": 30}},
}
const MODULE_COL := {"feuer": Color("FF7A1F"), "eis": Color("7FE3FF"), "gift": Color("8FE04A"), "blitz": Color("FFE24A")}
## Fund: Chance auf ein Modul je geöffneter Beutekiste bzw. Fundkiste der Expedition
const MODULE_DROP := {"chest": 0.12, "chest_boss": 0.5, "chest_flood_gold": 0.35, "chest_flood_silver": 0.2, "chest_find": 0.25, "chest_level": 0.25}
## Module lassen sich jederzeit wieder ausbauen (sie kommen zurück ins Lager).
const MODULE_REMOVE_FREE := true

# ---------------------------------------------------------------- Gift
## Gift wirkt je Sekunde POISON_DPS × Waffenstärke (Seltenheit und Stufe des Stücks) × Heldenstärke (wie Brennen).
const POISON_DPS := 5.0

# ---------------------------------------------------------------- Wurfwaffen
## Waffen mit Haltung "toss" sind in der Hand größer (sonst kaum zu sehen); Wurfbahn als Punktlinie beim Zielen.
const TOSS_SCALE := 1.7
const ARC_DOTS := 14
const ARC_MODES := ["proj", "mine"]

# ---------------------------------------------------------------- Gesichter
## Gesichts-Teile im Heldenmodell (blender/heroes.py): face_normal, face_blink, face_joy, face_pain, face_strain.
const FACES := ["normal", "blink", "joy", "pain", "strain"]
const BLINK_EVERY := [2.2, 5.5]          # Sekunden zwischen zwei Lidschlägen (zufällig)
const BLINK_TIME := 0.13
## Clip -> Gesicht, solange der Clip läuft
const FACE_OF_CLIP := {"cheer": "joy", "victory": "joy", "level_up": "joy", "wave": "joy", "eat": "joy",
	"hit_light": "pain", "hit_heavy": "pain", "down": "pain", "defeat": "pain",
	"chop": "strain", "mine": "strain", "hammer": "strain", "pick_up": "strain", "dodge_roll": "strain",
	"skill_1": "strain", "skill_2": "strain", "special": "strain", "sleep": "blink"}
## Haltungen, bei denen jeder Schuss/Schlag kurz „Anstrengung“ zeigt
const STRAIN_POSES := ["heavy", "hammer", "spear", "melee", "toss", "thrower", "sniper"]

# ---------------------------------------------------------------- Laufstil je Persönlichkeit
## Additive Haltung beim Gehen/Rennen (Clips gait_<held> in anim_human.py); Stärke je Tempo.
const GAIT_HEROES := ["jona", "mika", "bruno", "ada", "yuki", "greta", "nele"]
const GAIT_STAND := 0.35                 # im Stand wirkt die Haltung schwächer
const GAIT_TEXT := {"jona": "aufrecht wie ein Briefträger auf Runde", "mika": "vorgebeugt und drängend", "bruno": "breitschultrig, schwer",
	"ada": "Kopf voraus, verträumt", "yuki": "leicht, aufrecht, wachsam", "greta": "klein und gebückt, aber flott", "nele": "locker, wiegend"}

# ---------------------------------------------------------------- Nachschwingen (Haare, Mäntel, Tücher)
## spring_*-Knochen der Heldenmodelle; Einstellungen nach Namensanfang: Steifigkeit, Dämpfung, Schwerkraft, Länge, Richtung (+1 hoch / -1 hängt)
const SPRINGS := {"spring_hair": [1.6, 0.45, 0.9, 0.28, -1], "spring_coat": [2.4, 0.5, 0.5, 0.3, -1], "spring_scarf": [1.8, 0.4, 0.8, 0.25, -1],
	"spring_belt": [2.6, 0.5, 0.6, 0.2, -1], "spring_": [3.2, 0.35, 0.0, 0.3, 1]}
