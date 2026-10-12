extends RefCounted
## Zahlen und Texte des Pakets Welt (V5): Gebiets-Ereignisse, Wahrzeichen, gebietseigene Quellen und Werkzeuge,
## Tagebuchseiten, Händler-Karawane, Nebenquests, Tageslauf in der Expedition, Begleiter-Eier, Köder,
## Bewohner-Wünsche und der Übungsplatz.
## Eingebunden als const DW = preload("res://src/data_welt.gd"). Gebiets-Schlüssel wie in D.AREAS.

const AREA_KEYS := ["gruental", "forst", "staub", "kueste", "sumpf", "frost", "krater", "vulkan"]

# ---------------------------------------------------------------- Tageslauf in der Expedition
## Stimmungen wie in der Basis (weather.gd MOOD); die Farben werden zur Hälfte mit dem Gebietslicht gemischt.
## Ankunft am Morgen, nach EXP_MORNING Sekunden Tag; zwei Minuten vor der Dämmerung Abend; ab Dämmerung Nacht.
const EXP_MORNING := 90.0
const EXP_EVENING_LEAD := 120.0
const EXP_MOOD_BLEND := 0.5

# ---------------------------------------------------------------- Gebiets-Ereignisse (Kapitel 5.1 / 4.3)
## Nur in der Phase „Erkunden“: das erste nach EVENT_FIRST Sekunden, dann alle EVENT_EVERY [von, bis], dur: Dauer.
## Wirkung je Art in exp_world.gd; die Zahlen hier.
const EVENT_FIRST := 150.0
const EVENT_EVERY := [200.0, 260.0]
const EVENTS := {
	"gruental": {"key": "regen", "name": "Regenschauer", "dur": 50.0, "icon": "ui_water",
		"text": "Regenschauer! Bäume geben jetzt 50 % mehr Holz. Danach zeigt der Regenbogen auf einen Münztopf.", "wood_k": 1.5},
	"forst": {"key": "nebel", "name": "Dichter Nebel", "dur": 55.0, "icon": "ui_snow",
		"text": "Dichter Nebel zieht auf: Du siehst weniger – aber die Waldgeister bemerken dich erst spät.", "reveal_k": 0.45, "aggro": 7.0},
	"staub": {"key": "sandsturm", "name": "Sandsturm", "dur": 45.0, "icon": "ui_speed",
		"text": "Sandsturm! Außerhalb der Außenbasis läufst du langsamer und siehst weniger weit.", "slow": 0.72, "reveal_k": 0.55, "safe_r": 16.0},
	"kueste": {"key": "ebbe", "name": "Ebbe und Flut", "dur": 60.0, "icon": "ui_water",
		"text": "Ebbe! Das Meer gibt Schätze frei – hol sie, bevor die Flut zurückkommt.", "bonus": 4, "flood_slow": 0.7},
	"sumpf": {"key": "giftnebel", "name": "Giftnebel", "dur": 50.0, "icon": "ui_skull",
		"text": "Giftnebel treibt durch das Sumpfwerk – meide die grünen Wolken!", "clouds": 4, "radius": 4.5, "dps": 0.035},
	"frost": {"key": "lawine", "name": "Lawine", "dur": 30.0, "icon": "ui_snow",
		"text": "Es grollt am Berg – Lawinen! Weg aus den weißen Kreisen!", "count": 4, "radius": 4.5, "warn": 2.6, "dmg": 0.22},
	"krater": {"key": "meteor", "name": "Meteoritenschauer", "dur": 35.0, "icon": "ui_fire",
		"text": "Meteoriten! Weich den roten Kreisen aus – die Brocken enthalten wertvolle Splitter.", "count": 6, "radius": 4.0, "warn": 2.2, "dmg": 0.2},
	"vulkan": {"key": "ausbruch", "name": "Vulkanausbruch", "dur": 40.0, "icon": "ui_fire",
		"text": "Der Vulkan bricht aus! Ascheregen, Lavabomben (rote Kreise) – und alle Lavaströme fließen. Such Schatten!", "count": 7, "radius": 3.6, "warn": 2.4, "dmg": 0.16,
		"reveal_k": 0.6, "heat_k": 1.8},
}

# ---------------------------------------------------------------- Wahrzeichen
## dist: Abstand zum Start (fester Ort je Gebiet), r: gesperrter Radius, see: so nah = entdeckt.
const LANDMARKS := {
	"gruental": {"name": "Alte Mühle", "model": "lm_gruental", "dist": [58.0, 70.0], "r": 3.6},
	"forst": {"name": "Uralte Riesenkiefer", "model": "lm_forst", "dist": [58.0, 72.0], "r": 3.0},
	"staub": {"name": "Rostiger Wasserturm", "model": "lm_staub", "dist": [58.0, 72.0], "r": 3.2},
	"kueste": {"name": "Leuchtturm", "model": "lm_kueste", "dist": [60.0, 74.0], "r": 3.4},
	"sumpf": {"name": "Alter Fabrikschlot", "model": "lm_sumpf", "dist": [58.0, 72.0], "r": 3.6},
	"frost": {"name": "Eisbogen", "model": "lm_frost", "dist": [58.0, 72.0], "r": 3.8},
	"krater": {"name": "Schleimportal", "model": "lm_krater", "dist": [58.0, 72.0], "r": 3.8},
	"vulkan": {"name": "Feuerschlund", "model": "lm_vulkan", "dist": [60.0, 74.0], "r": 3.8},
}
const LANDMARK_SEE := 10.0
const LANDMARK_XP := 40
const LANDMARK_SCALE := 1.6                        # Modelle sind in Spielzeuggröße gebaut; im Gebiet wirken sie so groß

# ---------------------------------------------------------------- Gebietseigene Quellen und Werkzeuge
## Quelle wie D.EXP_NODES (Modell, Rohstoff, Ertrag, Hiebe, Animation) und dazu: tool (nötiges Werkzeug), snd (Schlagklang),
## buff (Wirkung je Schlag: heal = Anteil Leben, speed = Tempo-Schub [Faktor, Sekunden]), per_visit: so viele je Besuch.
const SOURCES := {
	"src_gruental": {"name": "Bienenstock", "model": "n_src_gruental", "res": "coins", "min": 40, "max": 60, "hits": 3, "clip": "pick_up",
		"tool": "smoker", "snd": "hit_honey", "buff": {"heal": 0.08}, "no_factor": false},
	"src_forst": {"name": "Harzkiefer", "model": "n_src_forst", "res": "fuel", "min": 14, "max": 22, "hits": 3, "clip": "chop", "tool": "tapper", "snd": "hit_resin"},
	"src_staub": {"name": "Wasserkaktus", "model": "n_src_staub", "res": "coins", "min": 30, "max": 45, "hits": 2, "clip": "pick_up", "tool": "tap",
		"snd": "hit_tap", "buff": {"heal": 0.25, "speed": [1.15, 45.0]}},
	"src_kueste": {"name": "Muschelbank", "model": "n_src_kueste", "res": "shards", "min": 1, "max": 2, "hits": 4, "clip": "mine", "tool": "knife",
		"snd": "hit_shell", "no_factor": true},
	"src_sumpf": {"name": "Ölquelle", "model": "n_src_sumpf", "res": "fuel", "min": 30, "max": 45, "hits": 3, "clip": "pick_up", "tool": "pump", "snd": "hit_pump"},
	"src_frost": {"name": "Eiskristall", "model": "n_src_frost", "res": "cells", "min": 6, "max": 10, "hits": 4, "clip": "mine", "tool": "icepick", "snd": "hit_ice"},
	"src_krater": {"name": "Schleimgeysir", "model": "n_src_krater", "res": "shards", "min": 1, "max": 2, "hits": 5, "clip": "pick_up", "tool": "canister",
		"snd": "hit_geyser", "no_factor": true, "rare": "cells", "rare_p": 0.6},
	"src_vulkan": {"name": "Glutgeode", "model": "n_src_vulkan", "res": "cells", "min": 8, "max": 14, "hits": 4, "clip": "mine", "tool": "tongs",
		"snd": "hit_geode", "no_factor": true, "rare": "shards", "rare_p": 0.5},
	# Funde aus Ereignissen (ohne Werkzeug)
	"meteor": {"name": "Meteorit", "model": "n_meteor", "res": "shards", "min": 1, "max": 1, "hits": 4, "clip": "mine", "snd": "hit_ice", "no_factor": true, "rare": "cells", "rare_p": 0.8},
	"pot": {"name": "Münztopf", "model": "n_coinpile", "res": "coins", "min": 90, "max": 130, "hits": 2, "clip": "pick_up"},
	"lavabomb": {"name": "Lavabombe", "model": "n_lavabomb", "res": "stone", "min": 20, "max": 32, "hits": 3, "clip": "mine", "snd": "hit_geode", "rare": "shards", "rare_p": 0.25},
}
const SOURCES_PER_VISIT := 3                       # gebietseigene Quellen je Besuch (Mittel- und Außenring)
const TOOLS := {
	"smoker": {"name": "Imker-Smoker", "area": 0, "icon": "tool_smoker", "price": 70, "text": "Beruhigt die Bienen: Honig aus Bienenstöcken."},
	"tapper": {"name": "Harz-Zapfmesser", "area": 1, "icon": "tool_tapper", "price": 70, "text": "Ritzt Harzkiefern an: Harz als Treibstoff."},
	"tap": {"name": "Kaktus-Zapfhahn", "area": 2, "icon": "tool_tap", "price": 70, "text": "Zapft Wasserkakteen an: heilt und macht schnell."},
	"knife": {"name": "Muschelmesser", "area": 3, "icon": "tool_knife", "price": 80, "text": "Öffnet Perlmuscheln: Sternsplitter."},
	"pump": {"name": "Handpumpe", "area": 4, "icon": "tool_pump", "price": 70, "text": "Pumpt Öl aus kleinen Quellen: viel Treibstoff."},
	"icepick": {"name": "Eispickel", "area": 5, "icon": "tool_icepick", "price": 80, "text": "Bricht Eiskristalle: Energiezellen."},
	"canister": {"name": "Schleimkanister", "area": 6, "icon": "tool_canister", "price": 90, "text": "Fängt Schleim aus Geysiren: Sternsplitter und Zellen."},
	"tongs": {"name": "Glutzange", "area": 7, "icon": "tool_tongs", "price": 100, "text": "Bricht glühende Geoden auf: Energiezellen und Sternsplitter."},
}

# ---------------------------------------------------------------- Tagebuchseiten (Gebietsgeschichte)
## Seite 0 liegt am Wahrzeichen, Seiten 1 und 2 irgendwo im Gebiet (eine je Besuch), Seite 3 gibt es für die Nebenquest.
const JOURNAL := {
	"gruental": [
		["Die Mühle", "Tagebuch der Müllerin Frieda: Seit der große Regen kam, mahlt die Mühle Tag und Nacht. Das Wasser im Bach ist grün geworden, und es schmatzt, wenn es über die Steine läuft."],
		["Die ersten Schleimlinge", "Heute hüpfte ein grüner Klecks in den Hühnerstall. Die Hühner haben ihn verjagt – er schien eher neugierig als böse. Am Abend waren es zwanzig."],
		["Der Bunker", "Karl sagt, unter dem alten Wasserwerk gibt es einen Bunker aus der Zeit der Großeltern. Dicke Wände, ein Tor aus Stahl. Wir sollten ihn aufschließen, bevor es zu spät ist."],
		["Talfest", "Wenn das hier vorbei ist, feiern wir das Talfest. Greta hat versprochen, ein Feuerwerk zu bauen, das man bis zum Frostpass sieht. Ich backe die Kuchen."],
	],
	"forst": [
		["Die Riesenkiefer", "Notizen eines Försters: Die alte Kiefer ist älter als das Dorf. Im Baumhaus darüber haben wir als Kinder Sterne gezählt. Jetzt zählen wir Irrlichter."],
		["Waldgeister", "Die Pilzlinge tun nichts, solange man leise ist. Wer im Nebel ruhig geht, kommt an ihnen vorbei. Wer rennt, hat bald den ganzen Wald am Hals."],
		["Bertas Spur", "Im Schlamm am Weg sind Kettenspuren, groß wie ein Haus. Bruno sagt, das ist Berta, sein Bagger. Er sagt es jeden Tag, und jeden Tag wird er stiller."],
		["Holzfällerlager", "Das Lager im Norden steht leer. Die Äxte hängen noch an der Wand, die Suppe steht noch auf dem Herd. Wer hier wohnte, ist sehr schnell gegangen."],
	],
	"staub": [
		["Der Wasserturm", "Logbuch der Tankstelle: Der Wasserturm ist das Einzige, was hier noch Wasser hat. Das Windrad quietscht, aber es pumpt. Solange es pumpt, leben wir."],
		["Sandstürme", "Wenn der Himmel gelb wird, rein in die Hütte. Draußen sieht man die Hand nicht vor Augen, und der Sand frisst sich in jede Ritze. Die Wüstenmonster lieben das."],
		["Kaktuswasser", "Ein alter Trick der Fernfahrer: Ein Zapfhahn im Kaktus, und man hat frisches Wasser. Schmeckt grün, macht aber Beine wie ein Hase."],
		["Die Karawane", "Jeden zweiten Tag kommt die Karawane vorbei. Sie verkaufen alles – Werkzeuge, Ersatzteile, sogar Eier, aus denen seltsame Tiere schlüpfen."],
	],
	"kueste": [
		["Das Leuchtfeuer", "Tagebuch der Leuchtturmwärterin: Das Licht brennt noch. Ich weiß nicht, wem es den Weg zeigt – Schiffe kommen keine mehr. Aber die Untoten meiden es."],
		["Ebbe", "Bei Ebbe liegt der halbe Hafen frei: Kisten, Wracks, Muschelbänke voller Perlen. Bei Flut muss man weg sein, sonst holt einen das Wasser."],
		["Yukis Vögel", "Eine junge Frau mit einem Falken kam vorbei. Sie fragte, ob ich Zugvögel gesehen habe. Ich habe keinen einzigen gesehen, seit dem großen Regen."],
		["Die Matrosen", "Die Mannschaft der Möwe ging an Land und kam nicht zurück. Jetzt stehen sie nachts am Strand und schauen aufs Meer. Ich glaube, sie warten auf ihr Schiff."],
	],
	"sumpf": [
		["Der Schlot", "Werksbuch: Der große Schlot raucht wieder, obwohl niemand heizt. Die Rohre sind voller grünem Zeug, und manchmal klopft es von innen."],
		["Giftnebel", "Wenn der Wind dreht, kommen grüne Wolken aus den Tümpeln. Wer hineingerät, hustet tagelang. Am besten zieht man weiter, bis sie vorbei sind."],
		["Die Pumpen", "Ada Volt war hier, vor dem großen Regen. Sie hat sich die Pumpen angesehen und viel geschrieben. Ihr Notizbuch liegt noch im Kesselhaus."],
		["Mutanten", "Die Kröten sind so groß wie Hunde geworden, die Egel so groß wie Schlangen. Was immer im Schleim steckt, es lässt die Dinge wachsen."],
	],
	"frost": [
		["Der Eisbogen", "Bergwacht, Wachbuch: Der Wasserfall ist mitten im Sommer gefroren. Unter dem Eis leuchtet etwas – kalt und blau, wie ein Stern."],
		["Lawinen", "Wenn es am Berg grollt, sind es die Lawinenroller. Sie lösen den Schnee absichtlich. Weg aus den Rinnen, sofort!"],
		["Eiskristalle", "Die Kristalle hier speichern Energie wie Batterien. Mit einem Pickel kommt man dran – aber vorsichtig, sie splittern scharf."],
		["Die Spur nach oben", "Alle Spuren der Eiswesen führen nach Süden, zum Krater. Als würden sie von dort gerufen."],
	],
	"krater": [
		["Das Portal", "Letzte Seite eines Forschers: Im Krater steht ein Ring aus Stein, und in seiner Mitte pulsiert der Schleim wie ein Herz. Hier beginnt die Flut."],
		["Adas Maschine", "Die Wettermaschine hat den großen Regen gebracht, und der Regen hat den Schleim aus der Tiefe gespült. Niemand ist schuld – aber jemand muss es beenden."],
		["Meteore", "Die Brocken, die hier vom Himmel fallen, sind voller Sternsplitter. Ich glaube, der Schleim kam einst mit ihnen. Er wollte nur nach Hause."],
		["Hoffnung", "Wenn das Portal geschlossen ist, kommt der Regen wieder normal, und die Vögel kehren zurück. Dann feiern wir das Talfest. Alle zusammen."],
	],
	"vulkan": [
		["Der Feuerschlund", "Logbuch der Inselwache: Seit das Portal im Krater zittert, raucht der alte Vulkan wieder. Aus dem Schlund steigt nachts ein rotes Leuchten, als würde dort unten jemand Feuer schüren."],
		["Wandernde Lava", "Die Lavaströme suchen sich jeden Tag einen neuen Weg. Wo gestern noch ein Pfad war, glüht heute der Boden. Wer hier lebt, schaut zuerst auf die Risse – die färben sich rot, bevor die Lava kommt."],
		["Hitze", "Regel Nummer eins auf der Insel: Nie zu lange in der Sonne und nie zu nah an der Glut. Im Schatten der Felsen und an den kühlen Quellen kommt man wieder zu Atem."],
		["Obsidian", "Das schwarze Glas ist härter als jeder Stein. Greta sagt, aus Obsidian ließen sich Mauern bauen, an denen sich selbst der Schleimkönig die Zähne ausbeißt. Wir schmieden schon die ersten Platten."],
	],
}
const JOURNAL_PICK_R := 2.2
const JOURNAL_XP := 15

# ---------------------------------------------------------------- Händler-Karawane
## Fährt im Mittelring im Kreis, hält alle stop_every Sekunden für stop_time. Preise in Feldmünzen × Gebietsfaktor.
const CARAVAN_SPEED := 3.2
const CARAVAN_STOP_EVERY := 22.0
const CARAVAN_STOP_TIME := 16.0
const CARAVAN_AFTER := 40.0                        # erscheint so viele Sekunden nach Beginn des Erkundens
const CARAVAN_TRADE_R := 5.5
const CARAVAN_OFFERS := {"egg": 150, "rare": 70, "fuel": 40}

# ---------------------------------------------------------------- Nebenquests mit Geschichte
## giver: Name und Kleidungsfarbe, items: Fundstücke im Gebiet (Modell), reward: Feldmünzen × Faktor, Werkzeug, Tagebuchseite 3.
const QUESTS := {
	"gruental": {"title": "Mehl für die Mühle", "giver": "Müllerin Frieda", "suit": "E6D2A4", "item": "Mehlsack", "model": "c_crate", "n": 3, "coins": 80,
		"intro": "„Die Schleimlinge haben meine drei Mehlsäcke verschleppt! Ohne Mehl kein Kuchen fürs Talfest.“", "done": "„Danke! Nimm meinen alten Smoker – die Bienen mögen dich jetzt.“"},
	"forst": {"title": "Bertas Schaufel", "giver": "Förster Emil", "suit": "4F7A2A", "item": "Werkzeugkiste", "model": "c_crate", "n": 3, "coins": 100,
		"intro": "„Im Wald liegen Kisten aus dem Holzfällerlager verstreut. Bring sie mir, dann zeig ich dir, wie man Harz zapft.“", "done": "„Gut gemacht! Hier, mein Zapfmesser.“"},
	"staub": {"title": "Ersatzteile für das Windrad", "giver": "Tankwart Kurt", "suit": "C99A52", "item": "Zahnrad", "model": "c_scrap", "n": 3, "coins": 120,
		"intro": "„Das Windrad am Wasserturm hat drei Zahnräder verloren. Ohne die verdursten wir!“", "done": "„Es dreht sich wieder! Nimm den Zapfhahn – Kaktuswasser hilft unterwegs.“"},
	"kueste": {"title": "Die Flaschenpost", "giver": "Wärterin Ida", "suit": "3E7FD8", "item": "Flaschenpost", "model": "c_can", "n": 3, "coins": 140,
		"intro": "„Am Strand liegen Flaschen mit Briefen. Vielleicht weiß einer, wo die Vögel sind?“", "done": "„Ein Brief von Yukis Vogelwarte! Hier, mein Muschelmesser.“"},
	"sumpf": {"title": "Adas Notizbuch", "giver": "Werkmeister Oskar", "suit": "6F8A4A", "item": "Notizseite", "model": "c_crate", "n": 3, "coins": 160,
		"intro": "„Adas Notizen sind im ganzen Werk verteilt. Hilf mir, sie zu finden – sie erklären vielleicht alles.“", "done": "„Jetzt verstehe ich die Pumpen. Nimm die Handpumpe!“"},
	"frost": {"title": "Verirrte Kletterer", "giver": "Bergwächterin Lene", "suit": "D54144", "item": "Seilrolle", "model": "c_log", "n": 3, "coins": 180,
		"intro": "„Drei Seilrollen sind uns bei der Lawine verloren gegangen. Ohne Seil kommen wir nicht zur Hütte.“", "done": "„Danke! Mein Eispickel gehört jetzt dir.“"},
	"krater": {"title": "Splitter für das Siegel", "giver": "Forscherin Hanna", "suit": "9658E8", "item": "Siegelstein", "model": "cg_shards", "n": 3, "coins": 220,
		"intro": "„Mit drei Siegelsteinen können wir das Portal schwächen. Sie liegen verstreut im Krater.“", "done": "„Das Portal zittert! Hier, der Schleimkanister – sammle den Schleim, bevor er sich wieder sammelt.“"},
	"vulkan": {"title": "Kühlwasser für die Schmiede", "giver": "Schmiedin Erna", "suit": "B8542A", "item": "Wasserkanne", "model": "c_watering", "n": 3, "coins": 260,
		"intro": "„Meine Schmiede braucht Kühlwasser, sonst springt das Obsidian. Die Inselwache hat drei Kannen verloren, als die Lava kam.“", "done": "„Zischt wunderbar! Nimm meine Glutzange – damit knackst du die glühenden Geoden.“"},
}
const QUEST_TALK_R := 3.0
const QUEST_TALK_TIME := 1.2
const QUEST_PICK_R := 2.4
const QUEST_XP := 60

# ---------------------------------------------------------------- Begleiter: Eier, Nester, Köder, Sammeln in der Basis
const EGG_HATCH_HOURS := 2.0                       # so lange braucht ein Ei im Nest der Basis
const EGG_NEST_P := 0.35                           # Chance auf ein Ei beim Zerstören eines Schleimnests (sonst Fundkiste wie bisher)
const EGG_CHEST := {"flood_silver": 0.06, "boss": 0.12, "flood_gold": 0.15, "clan": 0.1}   # Chance auf ein Ei je seltener Kiste (ersetzt ein Stück)
const EGG_MAX := 3                                 # so viele Eier höchstens gleichzeitig
const EGG_DUP_XP := 120.0                          # schlüpft ein Begleiter, den man schon hat: so viel Erfahrung für ihn
const LURE_CD := 22.0                              # Köder: Abklingzeit
const LURE_TIME := 6.0                             # so lange lockt der Begleiter Gegner an
const LURE_RADIUS := 14.0
const LURE_LEVEL := 3                              # ab Begleiter-Stufe
const PET_COLLECT_RADIUS := 26.0                   # Begleiter sammelt Sammelblasen in der Basis bis hier
const PET_COLLECT_EVERY := 14.0

# ---------------------------------------------------------------- Bewohner (Kapitel 16 / 7.1)
## Tagesablauf: Morgen (Frühstück am Bunker), Mittag (Pause am Lagerfeuer), Abend (Laternen anzünden), Nacht (schlafen).
const NPC_TREE_RANGE := 34.0                       # Holzfäller suchen Bäume bis so weit vom Sägewerk
const NPC_TREE_REGROW := 240.0                     # gefällter Baum wächst nach so vielen Sekunden nach
const NPC_WISH_EVERY := [150.0, 260.0]             # ein Bewohner äußert einen Wunsch
const NPC_WISH_REWARD := {"coins": 120}
const NPC_WISH_TIME := 600.0                       # so lange gilt ein Wunsch
const NPC_WISHES := [
	{"key": "flowers", "text": "Ich wünsche mir Blumen vor dem Quartier!", "need": "blumen", "icon": "ui_clover"},
	{"key": "lamp", "text": "Nachts ist es so dunkel – eine Laterne wäre schön.", "need": "laterne", "icon": "ui_bolt"},
	{"key": "visit", "text": "Kommst du mich mal besuchen?", "need": "", "icon": "ui_heart"},
	{"key": "coins", "text": "Kannst du mir 50 Münzen leihen? Ich zahle es doppelt zurück!", "need": "coins50", "icon": "res_coins"},
]

# ---------------------------------------------------------------- Übungsplatz (Kapitel 5.3)
const TRAIN_DUMMIES := 5
const TRAIN_DUMMY_HP := 4000.0
const TRAIN_SIZE := 30.0

# ---------------------------------------------------------------- Vulkaninsel (Paket Z): Lavaströme und Hitze
## Lavaströme: LAVA_STREAMS Ströme im Mittel- und Außenring, je zwei Arme (Wege); alle LAVA_SHIFT [von, bis] Sekunden wechselt ein
## Strom seinen Arm (LAVA_WARN Sekunden vorher glühen die Risse auf). Aktive Lava sperrt den Weg (wie ein Fels) und brennt
## LAVA_DPS (Anteil Leben je Sekunde) bis LAVA_EDGE Meter neben dem Strom.
const LAVA_STREAMS := 4
const LAVA_WIDTH := 3.6
const LAVA_SHIFT := [55.0, 80.0]
const LAVA_WARN := 6.0
const LAVA_EDGE := 1.2
const LAVA_DPS := 0.08
## Hitze-Leiste 0..100: steigt nahe Lava (HEAT_LAVA je s bei 0 m, linear bis HEAT_LAVA_R) und am Tag (HEAT_DAY je s), sinkt im
## Schatten (Felsen/Bäume bis HEAT_SHADE_R, Außenbasis) um HEAT_COOL und an kühlen Quellen (HEAT_SPRING_R) um HEAT_SPRING je s.
## Voll: HEAT_DOT (Anteil Leben je Sekunde), bis sie unter HEAT_RELEASE fällt.
const HEAT_MAX := 100.0
const HEAT_LAVA := 16.0
const HEAT_LAVA_R := 9.0
const HEAT_DAY := 1.4
const HEAT_COOL := 6.0
const HEAT_SHADE_R := 2.6
const HEAT_SPRING := 30.0
const HEAT_SPRING_R := 4.0
const HEAT_SPRINGS := 4
const HEAT_DOT := 0.04
const HEAT_RELEASE := 80.0
const HEAT_WARN := 75.0
## Tipps für den Ladebildschirm vor einer Expedition in dieses Gebiet
const AREA_TIPS := {
	"vulkan": ["Auf der Vulkaninsel steigt die Hitze nahe der Lava und am Tag. Im Schatten von Felsen und an den blauen Quellen kühlst du ab.",
		"Glühen die Risse neben einem Lavastrom auf, wechselt er gleich seinen Weg – geh rechtzeitig zur Seite.",
		"Magma-Wesen fürchten Wasser (+60 %). Feuer kann ihnen nichts anhaben."],
}
