extends RefCounted
## Zahlen und Texte für Spielerführung und Komfort (Paket F): Tutorial, Ziele-Leiste, Rückkehr-Zusammenfassung,
## Ladebildschirm-Tipps, Hilfe-Seiten, Flut-Schwierigkeit, Turmziele, Bildrate, Handy-Oberfläche.
## Eingebunden als const DF = preload("res://src/data_fuehrung.gd").

# ---------------------------------------------------------------- Geführtes Tutorial (Kapitel 8.2)
## Reihenfolge der Schritte. Jeder Schritt lässt sich einzeln überspringen; Fortschritt steht in P.d.tut.
## target: Bedienelement, auf das der Zeigefinger zeigt (Meta "guide" im HUD), "" = kein Finger.
const TUT_STEPS := [
	{"key": "laufen", "title": "Laufen", "icon": "ui_walk", "target": "stick",
		"text": "Beweg deinen Helden ein Stück durch die Basis.", "pc": "Laufe mit W A S D oder den Pfeiltasten ein Stück durch die Basis.",
		"touch": "Lege den linken Daumen auf den Bildschirm und schiebe – so läuft dein Held."},
	{"key": "blase", "title": "Sammelblase abholen", "icon": "ui_crate", "target": "bubble",
		"text": "Über dem Bunker schwebt eine Blase mit deinem Geschenk. Lauf hin oder tippe sie an."},
	{"key": "bauen", "title": "Gebäude bauen", "icon": "ui_build", "target": "bauen",
		"text": "Baue ein Sägewerk: „Bauen“ → Reiter „Produktion“ → Sägewerk, dann ein freies Feld wählen."},
	{"key": "beschleunigen", "title": "Beschleunigen", "icon": "ui_speed", "target": "speed",
		"text": "Bauten brauchen Zeit. Unter einer Minute Restzeit stellst du sie gratis fertig – tippe auf „Gratis“."},
	{"key": "uebung", "title": "Erste Flut (Übung)", "icon": "ui_flood", "target": "flood",
		"text": "Erlebe die Flut! Die Übungsflut ist leicht – du verlierst nichts. Tippe auf „Übungsflut“."},
	{"key": "expedition", "title": "Erste Expedition", "icon": "ui_expedition", "target": "expedition",
		"text": "Zieh hinaus ins Grüntal: sammle Rohstoffe und baue eine Außenbasis. Tippe auf „Expedition“."},
]
const TUT_WALK_DIST := 6.0                  # so weit muss der Held laufen (Meter)

## Tutorial-Flut am ersten Tag: leicht und ohne Verlust (zählt nicht als Wochenflut).
const TUT_FLOOD := {"waves": 2, "total": 26, "hp": 0.6, "dmg": 0.5}
const TUT_FLOOD_REWARD := {"coins": 200, "gems": 10}

# ---------------------------------------------------------------- Ziele-Leiste (Kapitel 8.2)
## Kette bis Bunker 6. Art: built (fertige Gebäude dieser Art), level (höchste Stufe, bunker = Bunkerstufe),
## stat (P.stat(key), z. B. expeditions, floods_won, collected, practice, vehicles, hero_level, heroes, outposts, level).
## reward: Rohstoffe, "gems", "chest" (Kistenart).
const GOALS := [
	{"t": "built", "key": "saege", "n": 1, "text": "Baue ein Sägewerk", "reward": {"coins": 150}},
	{"t": "built", "key": "mg", "n": 1, "text": "Baue einen MG-Turm", "reward": {"coins": 150, "wood": 100}},
	{"t": "stat", "key": "collected", "n": 100, "text": "Hole %d Rohstoffe aus Sammelblasen", "reward": {"gems": 5}},
	{"t": "built", "key": "wall", "n": 10, "text": "Setze %d Mauerstücke", "reward": {"wood": 150}},
	{"t": "stat", "key": "practice", "n": 1, "text": "Bestehe einen Übungsalarm", "reward": {"gems": 10}},
	{"t": "level", "key": "bunker", "n": 2, "text": "Baue den Bunker auf Stufe %d aus", "reward": {"coins": 300}},
	{"t": "built", "key": "lager", "n": 1, "text": "Baue ein Lager", "reward": {"stone": 100}},
	{"t": "stat", "key": "expeditions", "n": 1, "text": "Schließe eine Expedition ab", "reward": {"fuel": 40, "gems": 10}},
	{"t": "built", "key": "steinbruch", "n": 1, "text": "Baue einen Steinbruch", "reward": {"coins": 300}},
	{"t": "built", "key": "kanone", "n": 1, "text": "Baue eine Kanone", "reward": {"wood": 200, "stone": 100}},
	{"t": "level", "key": "saege", "n": 3, "text": "Bringe das Sägewerk auf Stufe %d", "reward": {"gems": 10}},
	{"t": "built", "key": "werkstatt", "n": 1, "text": "Baue die Werkstatt", "reward": {"parts": 10}},
	{"t": "level", "key": "mg", "n": 3, "text": "Bringe einen MG-Turm auf Stufe %d", "reward": {"coins": 400}},
	{"t": "built", "key": "stachel", "n": 2, "text": "Lege %d Stachelfallen", "reward": {"stone": 150}},
	{"t": "stat", "key": "chests", "n": 3, "text": "Öffne %d Beutekisten", "reward": {"gems": 10}},
	{"t": "level", "key": "bunker", "n": 3, "text": "Baue den Bunker auf Stufe %d aus", "reward": {"chest": "gift", "coins": 300}},
	{"t": "built", "key": "garage", "n": 1, "text": "Baue die Garage", "reward": {"fuel": 60}},
	{"t": "stat", "key": "vehicles", "n": 1, "text": "Kaufe dein erstes Fahrzeug", "reward": {"gems": 15}},
	{"t": "built", "key": "wachturm", "n": 1, "text": "Baue einen Wachturm", "reward": {"coins": 400}},
	{"t": "built", "key": "training", "n": 1, "text": "Baue den Trainingsplatz", "reward": {"wood": 300}},
	{"t": "stat", "key": "hero_level", "n": 5, "text": "Bringe einen Helden auf Stufe %d", "reward": {"gems": 10}},
	{"t": "stat", "key": "expeditions", "n": 3, "text": "Schließe %d Expeditionen ab", "reward": {"fuel": 60}},
	{"t": "built", "key": "funkturm", "n": 1, "text": "Baue den Funkturm", "reward": {"coins": 500}},
	{"t": "level", "key": "lager", "n": 3, "text": "Bringe das Lager auf Stufe %d", "reward": {"stone": 300}},
	{"t": "level", "key": "bunker", "n": 4, "text": "Baue den Bunker auf Stufe %d aus", "reward": {"chest": "gift", "gems": 15}},
	{"t": "built", "key": "flammenturm", "n": 1, "text": "Baue einen Flammenturm", "reward": {"metal": 100}},
	{"t": "built", "key": "presse", "n": 1, "text": "Baue eine Schrottpresse", "reward": {"coins": 600}},
	{"t": "stat", "key": "floods_won", "n": 1, "text": "Überstehe eine echte Flut", "reward": {"gems": 20}},
	{"t": "level", "key": "kanone", "n": 4, "text": "Bringe eine Kanone auf Stufe %d", "reward": {"metal": 150}},
	{"t": "built", "key": "wall", "n": 30, "text": "Setze %d Mauerstücke", "reward": {"stone": 300}},
	{"t": "stat", "key": "level", "n": 10, "text": "Erreiche Spielerstufe %d", "reward": {"gems": 15}},
	{"t": "level", "key": "bunker", "n": 5, "text": "Baue den Bunker auf Stufe %d aus", "reward": {"gems": 25}},
	{"t": "built", "key": "moerser", "n": 1, "text": "Baue einen Mörser", "reward": {"coins": 800}},
	{"t": "built", "key": "raffinerie", "n": 1, "text": "Baue eine Raffinerie", "reward": {"metal": 200}},
	{"t": "built", "key": "kleb", "n": 1, "text": "Lege eine Klebefalle", "reward": {"stone": 300}},
	{"t": "built", "key": "clanhalle", "n": 1, "text": "Baue die Clanhalle", "reward": {"gems": 15}},
	{"t": "stat", "key": "heroes", "n": 2, "text": "Befreie einen zweiten Helden", "reward": {"chest": "gift", "gems": 15}},
	{"t": "stat", "key": "outposts", "n": 1, "text": "Errichte eine Außenbasis", "reward": {"gems": 20}},
	{"t": "level", "key": "mg", "n": 5, "text": "Bringe einen MG-Turm auf Stufe %d", "reward": {"metal": 250}},
	{"t": "level", "key": "bunker", "n": 6, "text": "Baue den Bunker auf Stufe %d aus", "reward": {"chest": "gift", "gems": 40}},
]
## Nach der Kette: erzeugte Ziele (ein Muster nach dem anderen). step = Zuwachs gegenüber dem Stand beim Erzeugen.
const GOAL_GEN := [
	{"t": "stat", "key": "kills", "step": 500, "text": "Besiege %d weitere Gegner", "reward": {"coins": 600, "gems": 5}},
	{"t": "stat", "key": "expeditions", "step": 2, "text": "Schließe %d weitere Expeditionen ab", "reward": {"fuel": 80, "gems": 5}},
	{"t": "stat", "key": "builds", "step": 4, "text": "Baue oder verbessere %d Gebäude", "reward": {"wood": 400, "stone": 300}},
	{"t": "stat", "key": "floods_won", "step": 1, "text": "Überstehe die nächste Flut", "reward": {"gems": 15}},
	{"t": "stat", "key": "chests", "step": 3, "text": "Öffne %d weitere Beutekisten", "reward": {"chest": "gift"}},
	{"t": "stat", "key": "collected", "step": 1500, "text": "Hole %d Rohstoffe aus Sammelblasen", "reward": {"coins": 500, "gems": 5}},
]

# ---------------------------------------------------------------- Rückkehr-Zusammenfassung (Kapitel 8.2)
const RETURN_DAYS := 2.0                    # ab so vielen Tagen Abwesenheit
const RETURN_GIFT_PER_DAY := 5              # Juwelen je Tag Abwesenheit (höchstens 7 Tage)
const RETURN_GIFT_MAX_DAYS := 7

# ---------------------------------------------------------------- Ladebildschirm (Kapitel 7.3)
const TIPS := [
	"Unter einer Minute Restzeit stellst du jeden Bau gratis fertig.",
	"Mauern lenken die Schleimlinge: Ziehe mit dem Finger über mehrere Felder, um eine ganze Reihe zu setzen.",
	"Tore öffnen sich für dich, deine Fahrzeuge und Bewohner – Gegner müssen sie einreißen.",
	"Ist eine Drohne beschäftigt, kannst du den nächsten Bau vormerken. Er startet von selbst.",
	"Jede Gegnerfamilie hat Schwächen. Waldgeister brennen gut, Eiswesen auch.",
	"Ein Turm lässt sich auf ein Ziel einstellen: nächster, stärkster, fliegend oder Boss.",
	"Im Rucksack zählt das Gewicht. Stein und Metall sind schwer, Münzen leicht.",
	"Das Depot der Außenbasis bringt seine Ladung sicher heim – auch wenn dein Held fällt.",
	"Der Übungsalarm kostet nichts und zeigt dir, wo deine Mauer schwach ist.",
	"Begleiter tragen Beute und helfen im Kampf. Jeder kann etwas anderes.",
	"Eine schwerere Flut bringt mehr Beute – wähle sie, wenn deine Türme stark sind.",
	"Die Ziele-Leiste links zeigt dir immer, was als Nächstes sinnvoll ist.",
	"Fällt der Bunker, gehen bis zu 20 % der gelagerten Rohstoffe verloren – Gebäude bleiben stehen.",
	"Helden lernen Waffen mit ihrer Stufe. Die Helden-Seite zeigt alle 15 Waffen und wo es sie gibt.",
	"Nach der Flut reparieren die Handwerker beschädigte Gebäude nach und nach.",
	"Unter „Hilfe“ findest du alles über Elemente, Waffenarten, Begleiter und Wartezeiten.",
]
const LOAD_MIN_TIME := 0.6                  # so lange bleibt der Ladebildschirm mindestens sichtbar (Sekunden)

# ---------------------------------------------------------------- Flut: Schwierigkeit gegen Beute (Kapitel 4.2)
const FLOOD_DIFFS := [
	{"name": "Normal", "count": 1.0, "hp": 1.0, "loot": 0.0, "text": "Die Flut, wie sie kommt."},
	{"name": "Schwer", "count": 1.3, "hp": 1.25, "loot": 0.5, "text": "+30 % Gegner, +25 % Leben · +50 % Beute"},
	{"name": "Albtraum", "count": 1.6, "hp": 1.6, "loot": 1.0, "text": "+60 % Gegner, +60 % Leben · doppelte Beute"},
]
const FLOOD_DIFF_SHARDS := [0, 2, 5]        # Sternsplitter bei Sieg zusätzlich

# ---------------------------------------------------------------- Turmziel je Turm (Kapitel 4.1)
const TOWER_AIMS := [["", "Automatisch", "ui_star"], ["near", "Nächster", "ui_target"], ["strong", "Stärkster", "ui_sword"],
	["fly", "Fliegend", "ui_drone"], ["boss", "Boss", "ui_skull"]]

# ---------------------------------------------------------------- Akku und Bildrate (Kapitel 3.3)
const FPS_CALM := 30                        # Basis und Menüs im Akku-Sparmodus
const FPS_BATTLE := 60                      # Flut, Übung, Expedition
const VIBRATE := {"build": 40, "chest": 60, "level": 120, "hero_level": 90}

# ---------------------------------------------------------------- Handy-Oberfläche (Kapitel 7.3)
## Größe der Oberfläche: 0 = automatisch, sonst fester Faktor. Automatisch: kleine Handys (Höhe unter SMALL_PT Punkten) bekommen UI_SMALL.
const UI_SIZES := [["Automatisch", 0.0], ["Normal", 1.0], ["Groß", 1.2], ["Sehr groß", 1.4]]
const SMALL_PT := 500.0
const UI_SMALL := 1.3                       # HUD auf kleinen Handys (iPhone quer ≈ 390 pt hoch)
const SCREEN_SMALL := 1.1                   # Vollbild-Menüs auf kleinen Handys

# ---------------------------------------------------------------- Hilfe / Wiki im Spiel (Kapitel 8.2)
## Seiten des Bildschirms „Hilfe“. Abschnitte: [Überschrift, Text]. Einige Seiten ergänzt hilfe.gd mit Tabellen aus data.gd.
const HELP := [
	{"key": "start", "title": "Erste Schritte", "icon": "ui_info", "sections": [
		["Worum geht es?", "Du bist Kommandant eines Bunkers. Baue deine Basis aus, sammle Rohstoffe auf Expeditionen und halte an jedem siebten Tag die Flut der Schleimlinge auf."],
		["Ziele-Leiste", "Links oben steht immer dein nächstes Ziel mit Belohnung. Ist es erfüllt, tippe auf „Abholen“ – danach erscheint das nächste."],
		["Tutorial", "Das Tutorial führt dich mit einem Zeigefinger durch die ersten Schritte. Jeden Schritt kannst du einzeln überspringen und unter „Bedienung“ neu starten."],
		["Steuerung am Handy", "Linker Daumen: laufen. Gebäude antippen: verbessern, verschieben, abholen. Zwei Finger oder die Knöpfe + und −: zoomen."],
		["Steuerung am PC", "W A S D: laufen · Q, E, R: Fähigkeiten · F: Kommandant · Leertaste: ausweichen · T: Fahrzeug · N: nächste Welle · Esc: Pause."]]},
	{"key": "elemente", "title": "Elemente und Schwächen", "icon": "ui_fire", "sections": [
		["Elemente", "Viele Waffen und Türme tragen ein Element: Feuer, Eis, Blitz, Gift, Wasser oder Explosion. Jede Gegnerfamilie reagiert anders darauf."],
		["Stark und schwach", "+50 % heißt: der Treffer zählt anderthalbfach. „Wirkungslos“ heißt: dieses Element richtet keinen Schaden an. Die Tabelle unten zeigt jede Familie."],
		["Brennen und Gift", "Feuer setzt in Brand, Gift wirkt über einige Sekunden. Beides stapelt sich nicht, wird aber erneuert."]]},
	{"key": "waffen", "title": "Waffenarten", "icon": "ui_sword", "sections": [
		["15 Waffen je Held", "Jeder Held hat 15 Waffen: drei Startwaffen (Heldenstufe 1, 8, 16) und zwölf weitere aus Funden oder Bauplänen. Die Helden-Seite zeigt alle – auch die gesperrten mit Hinweis, wo es sie gibt."],
		["Schnellwechsel", "Auf der Helden-Seite unter „Waffen“ wechselst du mit einem Tipp auf das Bild die Waffe."],
		["Seltenheit und Stufe", "Gewöhnlich, Selten, Episch, Legendär: höhere Seltenheit bringt mehr Schaden und Zusatzwerte. In der Werkstatt verbesserst und verschmilzt du Stücke (drei gleiche → eines der nächsten Seltenheit)."]]},
	{"key": "begleiter", "title": "Begleiter", "icon": "comp_kistenbein", "sections": [
		["Was sie tun", "Ein Begleiter folgt deinem Helden auf Expeditionen, trägt Beute und hilft je nach Art beim Kämpfen, Heilen oder Sammeln."],
		["Bekommen", "Manche Begleiter sitzen gefangen auf Expeditionen (Phase „Erkunden“) – befreie sie. Andere baust du aus Rohstoffen oder kaufst sie im Bildschirm „Begleiter“."],
		["Stufen", "Begleiter sammeln Erfahrung mit jeder Ladung und jedem Kampf. Höhere Stufen tragen mehr und kämpfen besser."]]},
	{"key": "warten", "title": "Wartezeiten", "icon": "ui_clock", "sections": [
		["Bauzeiten", "Jeder Bau braucht eine Baudrohne und Zeit. Die ersten Bauten dauern unter einer Minute, späte Stufen Stunden."],
		["Gratis fertig", "Liegt die Restzeit unter einer Minute, stellst du den Bau gratis fertig. Sonst kostet das Juwelen – je länger, desto mehr."],
		["Bau-Warteschlange", "Sind alle Drohnen beschäftigt, kannst du den nächsten Auftrag vormerken. Er startet von selbst, sobald eine Drohne frei ist und die Rohstoffe reichen."],
		["Expedition spart Zeit", "Jede Expedition zieht 15 Minuten von laufenden Bauten ab."],
		["Juwelen", "Juwelen gehören deinem Konto und gelten in allen deinen Städten."]]},
	{"key": "flut", "title": "Die Flut", "icon": "ui_flood", "sections": [
		["Jeden siebten Tag", "Am siebten Tag der Woche kommt die Flut aus zwei Richtungen. Startest du sie nicht, verteidigt sich die Basis allein (Berechnung)."],
		["Wellen", "Die Flut kommt in Wellen. Zwischen den Wellen zeigt eine Vorschau, welche Gegnerarten als Nächstes kommen."],
		["Schwierigkeit", "Vor dem Start wählst du Normal, Schwer oder Albtraum. Schwerer heißt: mehr und zähere Gegner, aber deutlich mehr Beute."],
		["Verlieren", "Fällt der Bunker, gehen bis zu 20 % der gelagerten Rohstoffe verloren. Gebäude bleiben stehen, beschädigte reparieren die Handwerker."],
		["Übung", "Der Übungsalarm (einmal am Tag) ist schwächer und kostet nichts."],
		["Turmziele", "Tippe einen Turm an und wähle sein Ziel: nächster, stärkster, fliegend oder Boss."]]},
	{"key": "expedition", "title": "Expedition", "icon": "ui_expedition", "sections": [
		["Ablauf", "Ankommen → Aufbauen → Großangriff überstehen → Erkunden. Wer alle Pflichtplätze baut und den Großangriff übersteht, bekommt eine Außenbasis mit dauerhaftem Vorteil."],
		["Rucksack", "Stell dich neben Bäume, Felsen oder Schrott, dann sammelt dein Held. Der Rucksack hat ein Gewicht; bring Ladungen ins Depot."],
		["Heimkehren", "An der Zentrale oder am Fahrzeug erscheint „Heimkehren“. Fällt dein Held, kommen Depot und halber Rucksack heim."],
		["Gebiete", "Jedes Gebiet hat seine eigene Gegnerfamilie. Je weiter, desto stärker die Gegner – und desto wertvoller die Beute."]]},
	{"key": "forschung", "title": "Forschung und Belagerung", "icon": "ui_research", "sections": [      # V6 Paket B
		["Forschung", "Drei Äste mit je elf Knoten: Türme und Mauern, Wirtschaft, Helden und Expedition. Jeder Knoten kostet Rohstoffe (ab der zweiten Reihe auch Sternsplitter) und Zeit; es läuft immer eine Forschung. Die Wirkung gilt sofort und dauerhaft."],
		["Tüftelecke und Labor", "Die erste Reihe jedes Astes erforschst du schon in der Werkstatt. Das Labor (ab Bunker 8) öffnet den Rest; höhere Laborstufen öffnen tiefere Reihen und forschen schneller."],
		["Wetter der Flut", "Regen macht Türme langsamer und Feuer schwächer, Nebel kürzt die Reichweite, nachts sind die Gegner zäher – dafür gibt es mehr Beute. Die Vorschau zeigt das Wetter vor dem Start."],
		["Kluge Belagerer", "Brocken suchen gemeinsam die schwächste Stelle der Mauer, Flieger fliegen um die Luftabwehr herum, und ab Woche 3 tragen einzelne Schleimlinge Leitern und klettern über die Mauer."],
		["Rückblick und Reparatur", "Nach jeder Flut zeigt der Rückblick, wo die Mauer brach und welche Türme am meisten geleistet haben. Mauern behalten ihren Schaden – „Alle reparieren“ macht sie wieder heil."],
		["Aufbauten teilen und testen", "Im Bunker unter „Aufbauten“ kopierst du einen Aufbau als Code, fügst fremde Codes ein und schickst die Flut der Woche gegen einen gespeicherten Aufbau – ohne Verlust."],
		["Verletzte Bewohner", "Nach einer verlorenen oder harten Flut tragen einige Bewohner einen Verband und gehen langsamer. Sie heilen mit der Zeit und lassen sich im Bunker verarzten; das Feldlazarett halbiert die Heilzeit."]]},
	{"key": "bedienung", "title": "Bedienung", "icon": "ui_gear", "sections": []},
]
