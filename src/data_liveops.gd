extends RefCounted
## Paket L – Live-Betrieb: alle Zahlen und Texte für Wochen-Ereignisse, Feiertage, Saison und Saison-Pass, Kosmetik,
## Kosmetik-Shop, Wochenaufgaben, Login-Kalender, Nachrichten-Brett und Endspiel (Prestige, Albtraum+,
## Gebietsboss-Herausforderung der Außenbasen). Die Regeln stehen in src/liveops.gd.

# ---------------------------------------------------------------- Kalender (Wochen wie am Server: Montag 0:00 UTC)
const EPOCH_WEEK := 2962                    # Woche, die am Montag, 5.10.2026 beginnt (Start von Saison 1)
const WEEK_S := 604800.0

# ---------------------------------------------------------------- Wochen-Ereignisse (Kap. 13)
## Reihenfolge des festen Kalenders ohne Server (wiederholt sich).
const EVENT_ORDER := ["goldrausch", "schleimregen", "bauwoche", "eliteflut", "haendlerwoche", "weltboss"]
## points: Ereignispunkte je Fortschritt (Schlüssel wie P.quest_progress, dazu flood_win, elite_kill, caravan, boss_dmg)
## tiers: Punkte je Belohnungsstufe; rewards: je Stufe {gems, coins, chest, boost, cos}
const EVENTS := {
	"schleimregen": {"name": "Schleimregen", "icon": "e_0", "col": Color("7FC43A"),
		"text": "Es regnet Schleim! Alle Schleim-Gegner lassen doppelte Beute fallen.",
		"effect": "Beute der Schleim-Familie ×2", "points": {"kills": 1, "flood_win": 150},
		"tiers": [250, 800, 2000, 4000]},
	"haendlerwoche": {"name": "Händlerwoche", "icon": "ui_crate", "col": Color("E0A82E"),
		"text": "Die Karawanen ziehen öfter durch die Gebiete und verkaufen alles günstiger.",
		"effect": "Karawane −30 % Preis · kommt nach 15 s statt 40 s", "points": {"expeditions": 120, "caravan": 80, "kills": 0},
		"tiers": [200, 600, 1200, 2400]},
	"eliteflut": {"name": "Elite-Flut", "icon": "ui_skull", "col": Color("F5B41E"),
		"text": "In jeder Welle kommen mehr Elite-Gegner mit Krone – und sie tragen doppelte Beute.",
		"effect": "+3 Elite-Gegner je Welle · Elite-Beute ×2", "points": {"elite_kill": 40, "flood_win": 200, "practice": 60},
		"tiers": [200, 600, 1400, 2800]},
	"goldrausch": {"name": "Goldrausch", "icon": "res_coins", "col": Color("FDCA14"),
		"text": "Gold liegt in der Luft: Besiegte Gegner lassen 50 % mehr Münzen fallen.",
		"effect": "Münzen aus Kämpfen +50 %", "points": {"coins": 1},
		"tiers": [1500, 5000, 12000, 25000]},
	"bauwoche": {"name": "Bauwoche", "icon": "ui_build", "col": Color("38A9F5"),
		"text": "Die Bautrupps legen Sonderschichten ein: Alle Bauten und Verbesserungen sind schneller fertig.",
		"effect": "Bauzeit −25 %", "points": {"builds": 60, "walls": 0},
		"tiers": [180, 600, 1200, 2400]},
	"weltboss": {"name": "Weltboss-Woche", "icon": "ui_event", "col": Color("D54144"),
		"text": "Der Schleim-Leviathan ist erwacht! Alle Kommandanten greifen ihn gemeinsam an. Jeder Angriff zählt für den Gemeinschafts-Fortschritt.",
		"effect": "Gemeinschaftskampf gegen den Schleim-Leviathan", "points": {"boss_dmg": 1},
		"tiers": [25, 50, 75, 100], "community": true},
}
## Belohnungen je Ereignis und Stufe (die letzte Stufe enthält ein Kosmetik-Teil)
const EVENT_REWARDS := {
	"schleimregen": [{"gems": 10}, {"coins": 1500, "gems": 10}, {"chest": "level", "gems": 20}, {"gems": 30, "cos": "flag:schleim"}],
	"haendlerwoche": [{"gems": 10}, {"fuel": 120, "gems": 10}, {"chest": "level", "gems": 20}, {"gems": 30, "cos": "hat:cowboy"}],
	"eliteflut": [{"gems": 10}, {"parts": 60, "gems": 10}, {"chest": "boss", "gems": 20}, {"gems": 30, "cos": "flag:schaedel"}],
	"goldrausch": [{"gems": 10}, {"coins": 3000, "gems": 10}, {"chest": "level", "gems": 20}, {"gems": 30, "cos": "wskin:gold"}],
	"bauwoche": [{"gems": 10}, {"boost": 1, "gems": 10}, {"boost": 2, "gems": 20}, {"gems": 30, "cos": "flag:zahnrad"}],
	"weltboss": [{"gems": 15}, {"coins": 2000, "gems": 15}, {"chest": "boss", "gems": 25}, {"gems": 40, "cos": "hat:wikinger"}],
}
const EVENT_SLIME_LOOT := 2.0
const EVENT_GOLD := 1.5
const EVENT_BUILD := 0.75
const EVENT_ELITES := 3
const EVENT_ELITE_LOOT := 2.0
const EVENT_CARAVAN_PRICE := 0.7
const EVENT_CARAVAN_AFTER := 15.0

# ---------------------------------------------------------------- Weltboss (Gemeinschaftskampf, simuliert bis zum Server)
const BOSS_COMMUNITY_HP := 40000000         # Leben des Leviathans für alle Spieler zusammen
const BOSS_HP_MULT := 4.0                    # Leben im Einzelkampf (× 30 000) – in 90 s nicht zu besiegen
const BOSS_TIME := 90.0                      # Dauer eines Angriffs in Sekunden
const BOSS_TRIES := 3                        # Angriffe je Tag
const BOSS_SIM_PACE := 1.12                  # simulierte Gemeinschaft: so viel Prozent der Lebensleiste bis Wochenende (×100)

# ---------------------------------------------------------------- Feiertage (nach Datum, über Admin erzwingbar)
## from/to: [Monat, Tag]; Ostern: Tage um den Ostersonntag
const HOLIDAYS := {
	"halloween": {"name": "Halloween", "from": [10, 24], "to": [11, 2], "icon": "lo_pumpkin",
		"text": "Kürbis-Schleime mit Hut kriechen durchs Tal, Kürbislaternen leuchten in der Basis.",
		"gift": {"gems": 25, "cos": "hat:kuerbis"}, "gift2": "flag:kuerbis"},
	"weihnachten": {"name": "Weihnachten", "from": [12, 18], "to": [1, 6], "icon": "lo_xmas_tree",
		"text": "Schnee fällt auf die Basis, Geschenke liegen unter dem Baum.",
		"gift": {"gems": 40, "cos": "hat:weihnacht"}, "gift2": "flag:flocke"},
	"ostern": {"name": "Ostern", "days": 7, "icon": "lo_egg_1",
		"text": "Auf jeder Expedition sind bunte Eier versteckt – finde alle!",
		"gift": {"gems": 25}, "gift2": "hat:party"},
}
const EGGS_PER_EXP := 8
const EGG_REWARD := {"coins": 60, "gems": 1}
const EGG_ALL_REWARD := {"gems": 15, "chest": "gift"}
const EGG_RADIUS := 2.4
const HALLOWEEN_TINT := Color(2.2, 0.78, 0.16)        # grüner Schleim × Tönung = Kürbis-Orange
const PUMPKIN_HATS := 48                     # so viele Schleime tragen gleichzeitig einen Kürbishut

# ---------------------------------------------------------------- Saison und Saison-Pass (Kap. 13, 9.2)
const SEASON_WEEKS := 8
const SEASONS := [
	{"name": "Rostflut", "text": "Aus dem Meer der Schrottküste steigt rostiger Schleim. Wer die meisten Fluten hält, wird Rostkönig.", "col": Color("C8642E"), "icon": "lo_flag_saison"},
	{"name": "Frostfeuer", "text": "Ein seltsamer Winter: Eis und Glut zugleich. Die Dämonen frieren, die Eiswesen schwitzen.", "col": Color("66C4F2"), "icon": "lo_flag_flocke"},
	{"name": "Sternschnuppen", "text": "Sternsplitter regnen vom Himmel – und mit ihnen Schleime aus dem All.", "col": Color("8C5DF2"), "icon": "lo_flag_krone"},
]
const PASS_TIERS := 40
const PASS_POINTS := 450                     # Saisonpunkte je Stufe
const PASS_PRICE := "4,99 €"                 # später im Laden; hier nur Testkauf über store.gd
const PASS_PRODUCT := "rustwall.season_pass"
## Saisonpunkte je Quelle
const SP := {"flood_win": 150, "flood_loss": 50, "practice": 25, "expeditions": 80, "daily": 20, "daily_all": 40, "weekly": 150, "weekly_all": 300,
	"event_tier": 100, "raid": 60, "nightmare": 120}
## Sonderbelohnungen (Kosmetik) des Passes: Stufe -> Kosmetik
const PASS_FREE_COS := {10: "hat:party", 20: "flag:sturm", 30: "wskin:chrom", 40: "flag:saison"}
const PASS_PAID_COS := {1: "skin:jona_marine", 4: "wskin:neon", 8: "hat:propeller", 12: "skin:mika_glutwehr", 16: "flag:flamme",
	20: "bskin:rostfestung", 24: "skin:ada_neon", 28: "wskin:obsidian", 32: "hat:krone", 35: "skin:greta_sternennacht", 38: "wskin:lava", 40: "bskin:goldpalast"}
## Belohnung nach Rang am Saison-Ende: [bis Platz, Juwelen, Titel]
const SEASON_RANK_REWARDS := [[1, 150, "Saisonsieger"], [3, 120, "Saison-Held"], [10, 80, "Saison-Elite"], [25, 40, ""], [50, 20, ""]]     # höchstens 150 je Gutschrift (Server-Regel)
const BOARD_SIZE := 50
const BOT_NAMES := ["Rostbart", "Kessel-Kai", "Mauerliese", "Schraubi", "Funkfee", "Bunkerbär", "Deichgraf", "Klingen-Kim", "Tankwart Tom",
	"Schleimjägerin", "Nebelnora", "Kurbel-Kurt", "Ölprinz", "Zahnradzora", "Frostfritz", "Lampen-Lea", "Hammerhans", "Wellenwilli",
	"Piratin Pia", "Turm-Theo", "Kistenkönig", "Moorhexe", "Schrottschmied", "Ankeranna", "Dampfdieter", "Sandsturm-Sam", "Krater-Karl",
	"Funkenflo", "Brückenbert", "Waldwächter", "Rattenrudi", "Eisenella", "Pfeil-Paula", "Riegel-Ralf", "Drohnendani", "Glut-Gerda",
	"Muschelmia", "Salzsiggi", "Kettenkarin", "Blitzbodo", "Torwächter", "Seilbahn-Sepp", "Kompass-Kira", "Laterne-Lu", "Bolzen-Ben",
	"Schaufel-Sven", "Kanonen-Kalle", "Wirbelwanda", "Sternensucherin"]

# ---------------------------------------------------------------- Komfort: Zeitschub (aus Pass, Ereignissen, Kalender)
const BOOST_SECONDS := 1800.0                # ein Zeitschub: alle laufenden Bauten 30 Minuten weiter

# ---------------------------------------------------------------- Kosmetik (4.4, 9.2, 17)
## Kennung "art:schlüssel". kind: skin (Held), wskin (Waffen-Farbe), bskin (Bunker), flag (Fahne am Bunker), hat (Begleiter-Hut)
## price: Juwelen im Kosmetik-Shop (0 = nicht im Shop); src: Text, woher es kommt
const COSMETICS := {
	"skin:jona_wuestenfuchs": {"name": "Wüstenfuchs", "hero": "jona", "price": 300},
	"skin:jona_marine": {"name": "Marine", "hero": "jona", "price": 0, "src": "Saison-Pass (bezahlt), Stufe 1"},
	"skin:mika_glutwehr": {"name": "Glutwehr", "hero": "mika", "price": 0, "src": "Saison-Pass (bezahlt), Stufe 12"},
	"skin:mika_frostwehr": {"name": "Frostwehr", "hero": "mika", "price": 300},
	"skin:bruno_rostschmied": {"name": "Rostschmied", "hero": "bruno", "price": 0, "src": "Erfolg: 15 Fluten gewonnen"},
	"skin:bruno_goldgraeber": {"name": "Goldgräber", "hero": "bruno", "price": 300},
	"skin:ada_neon": {"name": "Neon", "hero": "ada", "price": 0, "src": "Saison-Pass (bezahlt), Stufe 24"},
	"skin:ada_mitternacht": {"name": "Mitternacht", "hero": "ada", "price": 300},
	"skin:yuki_schneeeule": {"name": "Schneeeule", "hero": "yuki", "price": 0, "src": "Erfolg: 40 Expeditionen"},
	"skin:yuki_herbstlaub": {"name": "Herbstlaub", "hero": "yuki", "price": 300},
	"skin:greta_rosengarten": {"name": "Rosengarten", "hero": "greta", "price": 300},
	"skin:greta_sternennacht": {"name": "Sternennacht", "hero": "greta", "price": 0, "src": "Saison-Pass (bezahlt), Stufe 35"},
	"wskin:gold": {"name": "Gold", "tint": Color("FFC93A"), "metal": 0.7, "price": 0, "src": "Ereignis Goldrausch"},
	"wskin:chrom": {"name": "Chrom", "tint": Color("DCE6F4"), "metal": 0.8, "price": 0, "src": "Saison-Pass, Stufe 30"},
	"wskin:tarn": {"name": "Tarnung", "tint": Color("6E8A3A"), "metal": 0.0, "price": 200},
	"wskin:neon": {"name": "Neon", "tint": Color("FF4FD8"), "metal": 0.0, "glow": 0.35, "price": 0, "src": "Saison-Pass (bezahlt), Stufe 4"},
	"wskin:obsidian": {"name": "Obsidian", "tint": Color("3A3450"), "metal": 0.4, "price": 0, "src": "Saison-Pass (bezahlt), Stufe 28"},
	"wskin:frost": {"name": "Frost", "tint": Color("9FDCFF"), "metal": 0.2, "price": 200},
	"wskin:lava": {"name": "Lava", "tint": Color("FF6A2A"), "metal": 0.0, "glow": 0.3, "price": 0, "src": "Saison-Pass (bezahlt), Stufe 38"},
	"bskin:rostfestung": {"name": "Rostfestung", "model": "lo_bskin_rostfestung", "tint": Color(1.15, 0.82, 0.62), "price": 0, "src": "Saison-Pass (bezahlt), Stufe 20"},
	"bskin:polarstation": {"name": "Polarstation", "model": "lo_bskin_polarstation", "tint": Color(0.9, 1.0, 1.18), "price": 500},
	"bskin:goldpalast": {"name": "Goldpalast", "model": "lo_bskin_goldpalast", "tint": Color(1.2, 1.08, 0.72), "price": 0, "src": "Saison-Pass (bezahlt), Stufe 40"},
	"flag:sturm": {"name": "Sturmbanner", "price": 0, "src": "Saison-Pass, Stufe 20"},
	"flag:schaedel": {"name": "Totenkopf", "price": 0, "src": "Ereignis Elite-Flut"},
	"flag:schleim": {"name": "Schleimwappen", "price": 0, "src": "Ereignis Schleimregen"},
	"flag:zahnrad": {"name": "Zahnrad", "price": 0, "src": "Ereignis Bauwoche"},
	"flag:krone": {"name": "Krone", "price": 160, "src": "Erfolg: Talbund (7 Außenbasen)"},
	"flag:flamme": {"name": "Flamme", "price": 0, "src": "Saison-Pass (bezahlt), Stufe 16"},
	"flag:flocke": {"name": "Schneeflocke", "price": 0, "src": "Weihnachten"},
	"flag:kuerbis": {"name": "Kürbis", "price": 0, "src": "Halloween"},
	"flag:saison": {"name": "Saisonstern", "price": 0, "src": "Saison-Pass, Stufe 40"},
	"hat:zylinder": {"name": "Zylinder", "price": 150},
	"hat:party": {"name": "Partyhut", "price": 0, "src": "Saison-Pass, Stufe 10 · Ostern"},
	"hat:krone": {"name": "Krone", "price": 0, "src": "Saison-Pass (bezahlt), Stufe 32"},
	"hat:kuerbis": {"name": "Kürbishut", "price": 0, "src": "Halloween"},
	"hat:weihnacht": {"name": "Weihnachtsmütze", "price": 0, "src": "Weihnachten"},
	"hat:cowboy": {"name": "Cowboyhut", "price": 0, "src": "Ereignis Händlerwoche"},
	"hat:wikinger": {"name": "Wikingerhelm", "price": 0, "src": "Ereignis Weltboss-Woche"},
	"hat:propeller": {"name": "Propellermütze", "price": 0, "src": "Saison-Pass (bezahlt), Stufe 8"},
}
const KIND_NAME := {"skin": "Helden-Skin", "wskin": "Waffen-Skin", "bskin": "Bunker-Skin", "flag": "Fahne", "hat": "Begleiter-Hut"}
## Kosmetik aus Erfolgen: [Kennung, Zähler (P.stat), Schwelle]
const ACH_COSMETICS := [["skin:bruno_rostschmied", "floods_won", 15], ["skin:yuki_schneeeule", "expeditions", 40], ["flag:krone", "outposts", 7], ["hat:zylinder", "kills", 20000]]
const SHOP_SLOTS := 4                        # täglich wechselnde Angebote
const SHOP_DEAL := 0.7                       # Angebot der Woche: 30 % günstiger

# ---------------------------------------------------------------- Wochenaufgaben (Kap. 13)
const WEEKLY_POOL := [
	{"key": "kills", "text": "Besiege %d Gegner", "amount": 2500},
	{"key": "expeditions", "text": "Schließe %d Expeditionen ab", "amount": 10},
	{"key": "flood_win", "text": "Gewinne die Wochenflut", "amount": 1},
	{"key": "builds", "text": "Baue oder verbessere %d Gebäude", "amount": 15},
	{"key": "chests", "text": "Öffne %d Kisten", "amount": 12},
	{"key": "coins", "text": "Sammle %d Münzen", "amount": 6000},
	{"key": "skills", "text": "Setze %d Fähigkeiten ein", "amount": 80},
	{"key": "practice", "text": "Bestehe %d Übungsalarme", "amount": 4},
	{"key": "daily_all", "text": "Erfülle an %d Tagen alle Tagesaufträge", "amount": 4},
]
const WEEKLY_N := 5
const WEEKLY_REWARD := {"gems": 15, "chest": "quest"}
const WEEKLY_ALL_REWARD := {"gems": 30, "chest": "level", "boost": 1}

# ---------------------------------------------------------------- Login-Kalender (28 Tage; ersetzt das Tagesgeschenk)
## Tag 1–28; Höhepunkte an Tag 7, 14, 21, 28. gems und chest liegen als Blase am Bunker, boost und cos gibt es sofort.
const CALENDAR := [
	{"gems": 5}, {"gems": 5, "coins": 200}, {"gems": 8}, {"gems": 8, "wood": 200}, {"gems": 10}, {"gems": 10, "coins": 400},
	{"gems": 25, "chest": "quest"},
	{"gems": 6}, {"gems": 6, "stone": 200}, {"gems": 8}, {"gems": 8, "boost": 1}, {"gems": 10}, {"gems": 10, "coins": 600},
	{"gems": 40, "chest": "level"},
	{"gems": 8}, {"gems": 8, "metal": 150}, {"gems": 10}, {"gems": 10, "fuel": 100}, {"gems": 12}, {"gems": 12, "parts": 40},
	{"gems": 50, "boost": 2, "chest": "level"},
	{"gems": 10}, {"gems": 10, "coins": 800}, {"gems": 12}, {"gems": 12, "shards": 2}, {"gems": 15}, {"gems": 15, "boost": 1},
	{"gems": 80, "chest": "clan", "cos": "wskin:frost"},
]
const CAL_HIGHLIGHT := [7, 14, 21, 28]

# ---------------------------------------------------------------- Nachrichten-Brett (Kap. 13): eingebaut, sonst vom Server
const NEWS := [
	{"date": "12.10.2026", "title": "Saison 1: Rostflut beginnt", "text": "Acht Wochen, 40 Stufen im Saison-Pass, neue Helden-Skins, Fahnen und Begleiter-Hüte. Saisonpunkte gibt es für Fluten, Expeditionen, Tages- und Wochenaufgaben."},
	{"date": "12.10.2026", "title": "Wochen-Ereignisse", "text": "Jede Woche gilt ein anderes Ereignis: Schleimregen, Händlerwoche, Elite-Flut, Goldrausch, Bauwoche und die Weltboss-Woche mit dem Schleim-Leviathan."},
	{"date": "12.10.2026", "title": "Garderobe und Kosmetik-Shop", "text": "Neu im Menü: die Garderobe. Hier ziehst du deinen Helden um, färbst Waffen, schmückst den Bunker und setzt deinem Begleiter einen Hut auf. Der Shop wechselt täglich."},
	{"date": "12.10.2026", "title": "Endspiel: Prestige und Albtraum+", "text": "Helden auf Stufe 40 sammeln jetzt Prestige-Sterne mit kleinen Dauerboni. Albtraum+ mit Modifikatoren bringt mehr Beute. Außenbasen Stufe 4 und 5 verlangen einen Sieg gegen den Gebietsboss."},
	{"date": "05.10.2026", "title": "Login-Kalender", "text": "Das tägliche Geschenk folgt jetzt einem 28-Tage-Kalender mit großen Belohnungen an Tag 7, 14, 21 und 28."},
	{"date": "28.09.2026", "title": "Version 3.4", "text": "Tagebuch, Händler-Karawane, Werkzeuge und Begleiter-Eier (Welt). Neue Gegnerrollen, Elite-Gegner und Minibosse."},
]

# ---------------------------------------------------------------- Endspiel (5.4)
## Prestige: Sterne über Heldenstufe 40
const PRESTIGE_XP := 26000.0                # Erfahrung je Stern
const PRESTIGE_MAX := 30
const PRESTIGE_DMG := 0.005                 # je Stern +0,5 % Schaden
const PRESTIGE_HP := 0.005                  # je Stern +0,5 % Leben
const PRESTIGE_GEMS := 20                   # alle 5 Sterne
## Albtraum+: Modifikatoren für die Schwierigkeit Albtraum (Beute-Zuschlag je Modifikator)
const NIGHTMARE_MODS := {
	"explode": {"name": "Explosive Gegner", "text": "Besiegte Gegner explodieren (Schaden im Umkreis)", "loot": 0.25, "icon": "ui_bomb"},
	"noheal": {"name": "Keine Heilung", "text": "Dein Held heilt nicht", "loot": 0.3, "icon": "ui_heart"},
	"doubleboss": {"name": "Doppelte Bosse", "text": "Jeder Boss kommt zu zweit", "loot": 0.35, "icon": "ui_skull"},
	"armored": {"name": "Panzerhaut", "text": "Gegner haben 50 % mehr Leben", "loot": 0.25, "icon": "ui_shield"},
	"swift": {"name": "Hast", "text": "Gegner sind 20 % schneller", "loot": 0.2, "icon": "ui_speed"},
}
const NIGHTMARE_ORDER := ["explode", "noheal", "doubleboss", "armored", "swift"]
const NM_EXPLODE_R := 2.6
const NM_EXPLODE_DMG := 0.12                 # Anteil am Leben des Helden
const NM_SHARDS := 2                         # Sternsplitter je aktivem Modifikator bei Erfolg
## Außenbasen Stufe 4 und 5: Gebietsboss-Herausforderung (Leben-Faktor, Belohnung)
const OUTPOST_CHALLENGE := {4: {"hp": 1.6, "gems": 40, "chest": "boss"}, 5: {"hp": 2.4, "gems": 60, "chest": "clan"}}
