extends RefCounted
## V6 Paket E – Geschichte: alle Zahlen und Texte der Hauptgeschichte, der Zwischenszenen, der Geretteten,
## der Story-Ziele, der Bewohner-Sprechblasen, der Helden-Gespräche und der Auto-Expeditions-Berichte.
## Eingebunden als const DG = preload("res://src/data_geschichte.gd"). Handlung: docs/geschichte.md.

# ---------------------------------------------------------------- Die Geretteten (Kapitel 4.3)
## area: Gebiet der Rettung, kind: camp (Gegnerlager) | cocoon (Schleimfalle) | ice (Käfig aus Eis),
## model: Figur (hero_<schlüssel>), home: Gebäude, an dem sie in der Basis arbeitet, clip: Arbeit dort.
const RESCUES := {
	"haendlerin": {"name": "Rosa Kramer", "title": "Die Händlerin", "area": 2, "kind": "camp", "color": Color("E07A2E"),
		"event": "Gegnerlager", "home": "tauschladen", "home2": "bunker", "clip": "pay", "work": "Feilscht am Tauschladen",
		"unlock": "Baut den Tauschladen: jeden Tag neue Tauschangebote, einmal in der Woche ein Begleiter-Ei.",
		"story": "Rosa fuhr mit der Karawane durch die Staubebene und verkaufte alles – Werkzeuge, Ersatzteile, sogar Eier, aus denen seltsame Tiere schlüpfen. Dann haben die Waschbär-Diebe ihren Karren überfallen. Mitsamt Rosa.",
		"look": "Breiter Sonnenhut mit Blume, orange Bluse, türkises Halstuch und eine riesige Kraxe voller Töpfe."},
	"forscher": {"name": "Professor Theo Moosbach", "title": "Der Forscher", "area": 4, "kind": "cocoon", "color": Color("8A6A44"),
		"event": "Schleimfalle", "home": "labor", "home2": "werkstatt", "clip": "pick_up", "work": "Forscht und macht Notizen",
		"unlock": "Hilft im Labor: Forschung geht 25 % schneller.",
		"story": "Theo Moosbach war Adas Lehrer an der Uni. Er wollte den Schleim im Sumpfwerk erforschen. Der Schleim hat zurückgeforscht und ihn in einen Kokon gewickelt. Er hat trotzdem weiter Notizen gemacht.",
		"look": "Tropenhelm, runde Brille, weißer Bart, Tweedjacke mit Fliege und eine Ledertasche voller Notizbücher."},
	"schmied": {"name": "Knut Amboss", "title": "Der Schmied", "area": 5, "kind": "ice", "color": Color("B03A2E"),
		"event": "Käfig aus Eis", "home": "werkstatt", "home2": "bunker", "clip": "hammer", "work": "Hämmert an einer Klinge",
		"unlock": "Arbeitet in der Werkstatt: Waffen verbessern kostet 20 % weniger.",
		"story": "Knut hat einen Deckel aus Stahl geschmiedet, so groß wie ein Scheunentor, um den Krater einfach zuzumachen. Er kam bis zum Frostpass. Dort haben ihn die Eiswesen eingefroren – mitsamt Deckel.",
		"look": "Roter Bart, rotes Kopftuch, Lederschürze und ein Schmiedehammer auf dem Rücken."},
}
const RESCUE_ORDER := ["haendlerin", "forscher", "schmied"]
const RESEARCH_K := 0.75                     # Forscher: Forschungszeit × 0,75
const SMITH_K := 0.8                         # Schmied: Waffen verbessern × 0,8 (Münzen und Bauteile)
## Ereignis in der Expedition: Wachen, Lebenspunkte des Kokons (× Gebiets-Lebensfaktor), Haltezeit am Käfig.
const CAMP_GUARDS := 10
const CAMP_CLEAR_R := 11.0                   # erst wenn hier kein Gegner mehr steht, lässt sich der Käfig öffnen
const CAMP_OPEN_TIME := 2.5
const COCOON_HP := 900.0
const COCOON_GUARDS := 6
const ICE_OPEN_TIME := 6.0                   # so lange neben dem Eiskäfig stehen (Eis aufhacken)
const ICE_WAVE_EVERY := 2.0                  # beim Aufhacken greifen Eiswesen an (je so viele Sekunden eine kleine Gruppe)
const ICE_GUARDS := 6
const RESCUE_R := 3.6
const RESCUE_XP := 120

# ---------------------------------------------------------------- Tauschladen (Rosa)
## Tauschangebote: je Tag 4 aus dieser Liste (fester Zufall je Tag), jedes höchstens n-mal am Tag.
const TRADES := [
	{"give": {"wood": 300}, "get": {"stone": 200}, "n": 3},
	{"give": {"stone": 300}, "get": {"wood": 220}, "n": 3},
	{"give": {"coins": 800}, "get": {"metal": 120}, "n": 2},
	{"give": {"metal": 150}, "get": {"fuel": 60}, "n": 2},
	{"give": {"fuel": 80}, "get": {"cells": 20}, "n": 2},
	{"give": {"coins": 1500}, "get": {"parts": 12}, "n": 2},
	{"give": {"wood": 500, "stone": 500}, "get": {"parts": 8}, "n": 1},
	{"give": {"cells": 40}, "get": {"shards": 2}, "n": 1},
	{"give": {"metal": 300}, "get": {"parts": 10}, "n": 1},
	{"give": {"coins": 600}, "get": {"wood": 250, "stone": 150}, "n": 3},
	{"give": {"parts": 10}, "get": {"coins": 1600}, "n": 2},
	{"give": {"shards": 3}, "get": {"cells": 60, "fuel": 60}, "n": 1},
]
const TRADES_PER_DAY := 4
const TRADE_EGG := {"coins": 2500, "parts": 15}     # einmal je Woche: ein Begleiter-Ei
const TAUSCH_BUILDING := "tauschladen"

# ---------------------------------------------------------------- Zwischenszenen
## Kameraposen der Bühne (story_stage.gd): [Ziel, Drehung (rad), Neigung (rad), Abstand]. Die Gruppe steht um (0,0,0)
## und schaut nach +Z, das Wahrzeichen steht hinten (0, 0, -14), Gegner rechts hinten (5, 0, -6).
const SHOTS := {
	"wide": [Vector3(0, 2.0, -5), 0.35, 0.28, 24.0],
	"group": [Vector3(0, 1.4, 0), -0.25, 0.14, 11.0],
	"close": [Vector3(0, 1.7, 0.3), 0.15, 0.06, 7.0],
	"low": [Vector3(0, 2.0, 0), 0.6, -0.02, 9.5],
	"lm": [Vector3(0, 3.2, -14), 0.5, 0.16, 15.0],
	"enemy": [Vector3(4.5, 1.6, -6), 0.75, 0.16, 11.0],
	"enemy_l": [Vector3(-5.5, 1.2, -6.5), -0.8, 0.16, 10.0],
	"high": [Vector3(0, 0, -4), 0.1, 0.95, 26.0],
	"sky": [Vector3(0, 6.0, -17), -0.2, -0.12, 14.0],
	"heart": [Vector3(0, 3.0, -10.5), 0.9, 0.1, 10.0],
}
const PANEL_MIN := 3.4                       # Sekunden je Tafel mindestens …
const PANEL_PER_CHAR := 0.045                # … plus so viel je Zeichen (große + kleine Zeile)
const PANEL_MAX := 8.5

## Darsteller: [rolle, x, z, blick (rad, 0 = zur Kamera), dauer-clip, extra]
##   lead = gespielter Held, ally/ally2 = weitere gerettete Helden, jona = Jona, settler = Bewohner,
##   haendlerin/forscher/schmied = Gerettete (extra "trapped": im Käfig / Kokon / Eis), boss = Gebietsboss (extra "down": besiegt),
##   slime = Gegner der Gebietsfamilie (extra = Zahl), heart = das Sternherz, prop = Modell (extra = Name).
## Tafeln: [große Zeile, kleine Zeile, Kamerapose, {rolle: clip}]
const SCENES := {
	# ---------------------------------------------------------------- Akt 1
	"a0_in": {"area": 0, "kind": "in", "title": "Grüne Bäche",
		"cast": [["lead", 0.0, 0.0, 0.2, ""], ["ally", -1.7, 0.6, 0.5, ""], ["settler", 2.0, 1.2, -0.7, "wave"], ["slime", 5.0, -6.0, 0.4, "", 5]],
		"panels": [
			["Kapitel 1: Grüntal", "Hier fing alles an – mit elf Tagen Regen.", "wide", {}],
			["Der Bach ist grün und schmatzt über die Steine.", "Frieda von der Mühle sagt: Erst kam der Regen, dann kamen die Kleckse.", "lm", {"settler": "wave"}],
			["Überall Schleimspuren – und alle laufen bergauf.", "Nach Süden, zum Rand des Tals. Dorthin, wo der Krater liegt.", "enemy", {}],
			["Wer die Flut aufhalten will, muss wissen, woher sie kommt.", "Also los: das Grüntal sichern, dann der Spur folgen.", "group", {"lead": "cheer"}]]},
	"a0_boss": {"area": 0, "kind": "boss", "title": "Die Krone",
		"cast": [["lead", 0.0, 0.0, -0.5, ""], ["ally", -1.6, 0.8, -0.3, ""], ["boss", 4.0, -4.5, -0.6, "", "down"], ["prop", 2.2, -2.2, 0.3, "", "fx_elite_crown"]],
		"panels": [
			["Dicker Bert ist geplatzt!", "Zurück bleiben eine Pfütze, ein beleidigter Blick – und seine Krone.", "enemy", {"lead": "cheer"}],
			["In der Krone steckt ein Stein, der von innen leuchtet.", "Ein Sternsplitter. Er wird warm, wenn man ihn nach Süden hält.", "close", {"lead": "pick_up"}],
			["Ein Stein, der den Weg zeigt.", "Wie ein Brief mit Adresse, sagt Jona. Absender: der Krater.", "group", {}],
			["Die Spur führt in den Kiefernforst.", "Dort wachsen seit dem Regen die Bäume über die Straßen.", "wide", {"ally": "wave"}]]},
	"a1_in": {"area": 1, "kind": "in", "title": "Nebel im Forst",
		"cast": [["lead", 0.0, 0.0, 0.3, ""], ["ally", 1.6, 0.9, -0.4, ""], ["slime", -5.0, -6.0, 0.6, "", 4], ["boss", 6.0, -9.0, -0.4, ""]],
		"panels": [
			["Kapitel 2: Kiefernforst", "Der Wald ist dichter als vor dem Regen. Viel dichter.", "wide", {}],
			["Irrlichter tanzen über den Wegen.", "Wer rennt, hat bald den ganzen Wald am Hals. Wer leise geht, kommt durch.", "low", {}],
			["Riesige Kettenspuren im Schlamm.", "Hier ist ein Bagger durchgefahren. Ein gelber. Mit Namen.", "high", {"ally": "pick_up"}],
			["Tief im Forst sitzt die Mooskönigin.", "Sie lässt den Wald wuchern – und der Wald riecht nach Krater.", "enemy", {"boss": "attack"}]]},
	"a1_boss": {"area": 1, "kind": "boss", "title": "Das Moos weicht",
		"cast": [["lead", 0.0, 0.0, -0.4, ""], ["ally", -1.5, 0.7, -0.2, ""], ["boss", 4.5, -5.0, -0.6, "", "down"]],
		"panels": [
			["Die Mooskönigin sinkt in sich zusammen.", "Aus ihrem Pilzhut rieseln Sternsplitter wie Sporen.", "enemy", {"lead": "cheer"}],
			["Der Nebel hebt sich.", "Zum ersten Mal seit Monaten fällt Sonne auf den alten Waldweg.", "sky", {}],
			["An der Riesenkiefer hängt die Karte des Försters.", "Alle grünen Linien darauf laufen an einem Punkt zusammen: dem Krater.", "lm", {"lead": "pick_up"}],
			["Hinter dem Wald beginnt die Staubebene.", "Dort, sagt man, hatte eine Erfinderin ihr Labor.", "group", {"ally": "wave"}]]},
	"a2_in": {"area": 2, "kind": "in", "title": "Staub und Schrott",
		"cast": [["lead", 0.0, 0.0, 0.2, ""], ["ally", -1.6, 0.8, 0.4, ""], ["haendlerin", -5.0, -5.5, 0.4, "", "trapped"], ["boss", 6.0, -8.0, -0.5, ""], ["slime", -3.0, -3.0, 0.6, "", 3]],
		"panels": [
			["Kapitel 3: Staubebene", "Eine Tankstelle, ein Wasserturm und sehr, sehr viel Sand.", "wide", {}],
			["Die Karawane kommt nicht mehr.", "Waschbär-Diebe haben sie überfallen – und die Händlerin Rosa Kramer gleich mit.", "group", {}],
			["Zwischen den Autowracks stapft etwas Großes.", "Der Rostbrocken: ein Golem aus Schrott, mit einem Kessel im Bauch.", "enemy", {"boss": "attack"}],
			["Und der Kessel … regnet.", "Mitten in der Wüste fällt aus seinem Bauch ein kleiner, grüner Schauer.", "close", {"lead": "wipe_brow"}]]},
	"a2_boss": {"area": 2, "kind": "boss", "title": "Der Wetterkessel",
		"cast": [["lead", 0.0, 0.0, -0.4, ""], ["ally", -1.6, 0.6, -0.2, ""], ["boss", 4.0, -4.5, -0.6, "", "down"]],
		"panels": [
			["Der Rostbrocken fällt auseinander.", "Schrauben, Radkappen, ein Kühlschrank – und der Kessel.", "enemy", {"lead": "cheer"}],
			["Auf dem Kessel steht: Dr. A. Volt – Wettermaschine Nr. 1.", "Das Herz der Maschine, die den großen Regen gemacht hat.", "close", {}],
			["Der Regen hat etwas tief unter dem Krater geweckt.", "Und der Kessel hat es seitdem gefüttert. Tropfen für Tropfen.", "group", {}],
			["Einen Aus-Knopf hat der Kessel nicht.", "Also bekommt er eine Delle. Er hustet, tröpfelt – und hört auf zu regnen.", "low", {"lead": "hammer"}],
			["Doch der Schleim ist längst unterwegs – bis ans Meer.", "Nächster Halt: die Schrottküste.", "wide", {"ally": "wave"}]]},
	"a3_in": {"area": 3, "kind": "in", "title": "Das Leuchtfeuer",
		"cast": [["lead", 0.0, 0.0, 0.3, ""], ["ally", 1.5, 0.8, -0.3, ""], ["ally2", -1.6, 0.9, 0.5, ""], ["slime", 5.0, -6.0, 0.4, "", 5]],
		"panels": [
			["Kapitel 4: Schrottküste", "Zweiundvierzig Wracks, ein Leuchtturm und Möwen, die verdächtig still sind.", "wide", {}],
			["Eine Schleimspur führt vom Land ins Meer.", "Breit wie eine Straße. Etwas Großes ist hier hineingekrochen.", "high", {}],
			["Nachts stehen Matrosen am Strand und starren aufs Wasser.", "Die Mannschaft der Möwe. Ihr Kapitän heißt jetzt Glibber.", "enemy", {}],
			["Im Leuchtturm sollen noch Leute sein.", "Und ganz oben: jemand mit einer halben Flasche Luft.", "lm", {"lead": "wave"}]]},
	"a3_boss": {"area": 3, "kind": "boss", "title": "Glibber geht von Bord",
		"cast": [["lead", 0.0, 0.0, -0.4, ""], ["ally", -1.6, 0.6, -0.2, ""], ["boss", 4.2, -4.8, -0.6, "", "down"], ["settler", 2.2, -1.5, 0.6, "wave"]],
		"panels": [
			["Kapitän Glibber zerfließt zu einer Pfütze mit Hut.", "Seine Mannschaft nimmt die Mützen ab – und wird wieder zu Seeleuten.", "enemy", {"lead": "cheer"}],
			["Der Steuermann zeigt aufs Meer.", "„Da unten liegt eine leere Haut, groß wie ein Bus. Was sie abgestreift hat, ist größer.“", "lm", {"settler": "wave"}],
			["Etwas wächst im Meer.", "Aber der Schleim im Meer kam vom Land. Die Quelle liegt im Krater.", "group", {}],
			["Im Hinterland raucht ein Schlot.", "Das alte Sumpfwerk pumpt wieder. Nur weiß keiner, was.", "wide", {}]]},
	"a4_in": {"area": 4, "kind": "in", "title": "Das Werk pumpt",
		"cast": [["lead", 0.0, 0.0, 0.2, ""], ["ally", -1.6, 0.7, 0.4, ""], ["forscher", -4.5, -5.0, 0.4, "", "trapped"], ["slime", 5.0, -6.0, 0.4, "", 5]],
		"panels": [
			["Kapitel 5: Sumpfwerk", "Eine Fabrik im Sumpf, voller Rohre, voller Tümpel, voller grünem Zeug.", "wide", {}],
			["Der Schlot raucht, obwohl niemand heizt.", "Und in den Rohren klopft es. Von innen.", "lm", {}],
			["Im Kesselhaus liegt ein Notizbuch von Ada.", "Daneben ein Kokon aus Schleim, mit einem Tropenhelm obendrauf.", "group", {"lead": "pick_up"}],
			["Das ist Professor Theo Moosbach!", "Er wollte den Schleim erforschen. Der Schleim hat zurückgeforscht.", "close", {}]]},
	"a4_boss": {"area": 4, "kind": "boss", "title": "Der Schlund schweigt",
		"cast": [["lead", 0.0, 0.0, -0.4, ""], ["ally", -1.6, 0.6, -0.2, ""], ["boss", 4.5, -5.0, -0.6, "", "down"]],
		"panels": [
			["Der Schlund verschluckt sich an seinem letzten Bissen.", "Die Pumpen stottern – und stehen still.", "enemy", {"lead": "cheer"}],
			["Die Rohre führten alle an einen Ort.", "Zum Krater. Das Werk hat Wasser hineingepumpt, Woche für Woche.", "high", {}],
			["Was immer im Krater wohnt: Es liebt Wasser.", "Und es wird größer, je mehr es bekommt.", "group", {}],
			["Der Weg zum Krater führt über den Frostpass.", "Dort oben, erzählen die Vögel, wartet etwas.", "wide", {"ally": "wave"}]]},
	"a5_in": {"area": 5, "kind": "in", "title": "Die Vögel warten",
		"cast": [["lead", 0.0, 0.0, 0.2, ""], ["ally", 1.6, 0.8, -0.4, ""], ["schmied", -4.5, -5.0, 0.4, "", "trapped"], ["slime", 5.0, -6.0, 0.4, "", 4]],
		"panels": [
			["Kapitel 6: Frostpass", "Mitten im Sommer ist der Wasserfall zu Eis erstarrt.", "wide", {}],
			["Tausende Zugvögel sitzen auf den Felsen.", "Alle schauen nach Süden. Keiner fliegt.", "sky", {}],
			["Unter dem Eisbogen leuchtet etwas blau.", "Kalt und hell – wie ein Stern, der hier heruntergefallen ist.", "lm", {}],
			["Ein Schmied steckt im Eis fest.", "Knut Amboss wollte den Krater mit einem Stahldeckel zumachen. Er kam nur bis hier.", "group", {"lead": "wipe_brow"}]]},
	"a5_boss": {"area": 5, "kind": "boss", "title": "Der Pass ist frei",
		"cast": [["lead", 0.0, 0.0, -0.4, ""], ["ally", -1.6, 0.6, -0.2, ""], ["boss", 4.5, -5.0, -0.6, "", "down"], ["prop", -3.0, -4.0, 0.3, "", "n_crystal_3"]],
		"panels": [
			["Der Frostbrocken zerspringt in tausend Eiswürfel.", "Die Eiswesen ziehen sich zurück – nach Süden, als würden sie gerufen.", "enemy", {"lead": "cheer"}],
			["Unter dem Eis liegt ein Sternsplitter, groß wie ein Haus.", "Er ist vom Himmel gefallen. Vor langer Zeit. Zusammen mit dem Krater.", "lm", {}],
			["Der Krater ist kein Loch im Boden.", "Er ist der Abdruck eines Sterns – und der Stern liegt noch drin.", "group", {}],
			["Die Vögel heben die Köpfe.", "Der Weg in den Schleimkrater ist offen.", "sky", {"ally": "wave"}]]},
	"a6_in": {"area": 6, "kind": "in", "title": "Das Sternherz",
		"cast": [["lead", 0.0, 0.0, 0.2, ""], ["ally", -1.6, 0.7, 0.4, ""], ["ally2", 1.6, 0.8, -0.3, ""], ["heart", 0.0, -11.2, 0.0, ""], ["boss", 0.0, -5.8, 0.0, ""], ["slime", 5.0, -5.0, 0.4, "", 5]],
		"panels": [
			["Kapitel 7: Schleimkrater", "Alles leuchtet grün. Der Boden summt. Die Luft schmeckt nach Brause.", "wide", {}],
			["In der Mitte steht ein Ring aus Stein.", "Darin pulsiert etwas wie ein Herz. Einmal in der Woche schlägt es ganz laut.", "heart", {}],
			["Das Sternherz.", "Vor langer Zeit fiel es vom Himmel und schlief tief unter dem Tal. Bis der Regen kam.", "lm", {}],
			["Doch es schlägt nicht von allein.", "Vor dem Ring thront der Schleimkönig – und drückt jede Woche zu.", "enemy", {"boss": "attack"}],
			["Jeder Herzschlag ist eine Flut.", "Wer das Tal retten will, muss den König vom Thron holen.", "low", {"lead": "cheer"}]]},
	"a6_boss": {"area": 6, "kind": "boss", "title": "Der König fällt",
		"cast": [["lead", 0.0, 0.0, -0.3, ""], ["ally", -1.6, 0.7, -0.2, ""], ["ally2", 1.6, 0.8, -0.4, ""], ["boss", 0.0, -5.8, 0.0, ""], ["heart", 0.0, -11.2, 0.0, ""]],
		"panels": [
			["Die Schleimhülle des Königs platzt.", "Darunter: Hörner, Glut und ein sehr überraschter Dämon.", "enemy", {"boss": "hit"}],
			["Er flieht in den Ring – und der Ring färbt sich rot.", "Ein Feuerstrahl schießt über das Meer, bis zu einer Insel am Horizont.", "sky", {"boss": "flee"}],
			["Das Sternherz ist weg!", "Der Dämon hat es mitgerissen. Der König war nur ein Statthalter.", "heart", {"heart": "gone"}],
			["Der Krater wird still.", "Ein paar Zugvögel wagen sich in die Luft. Das Grün wird ein bisschen blasser.", "wide", {"lead": "wipe_brow"}]]},
	"end1": {"area": 0, "kind": "end", "title": "Ein Funke im Süden",
		"cast": [["lead", 0.0, 0.0, 0.0, "cheer"], ["ally", -1.8, 0.6, 0.4, "cheer"], ["ally2", 1.8, 0.7, -0.4, "cheer"], ["settler", -3.2, -1.6, 0.8, "warm_hands"],
			["settler", 3.0, -1.8, -0.8, "cheer"], ["prop", 0.0, -2.6, 0.0, "", "p_campfire"], ["haendlerin", -4.4, 1.0, 0.6, "wave"], ["forscher", 4.5, 0.8, -0.6, ""], ["schmied", 4.0, -3.4, -0.5, "hammer"]],
		"panels": [
			["Ende von Akt 1", "Das Tal atmet auf. Die Fluten werden kleiner – aber sie hören nicht auf.", "wide", {}],
			["In der Basis wird gefeiert.", "Am Tor läutet eine Glocke, und die Bewohner tanzen ums Lagerfeuer.", "group", {"all": "cheer"}],
			["Doch am Horizont raucht die Vulkaninsel.", "Dort schürt jemand ein Feuer – mit einem gestohlenen Herzen.", "sky", {}],
			["Magmafürst Brodel.", "Der Herr des Schleimkönigs. Und er hat gerade erst angefangen.", "low", {}],
			["Weiter in Akt 2: Vulkaninsel", "Obsidian, wandernde Lava und ein sehr heißer Fürst warten.", "high", {"lead": "wave"}]]},
	# ---------------------------------------------------------------- Akt 2
	"a7_in": {"area": 7, "kind": "in", "title": "Die Insel brennt",
		"cast": [["lead", 0.0, 0.0, 0.2, ""], ["ally", -1.6, 0.7, 0.4, ""], ["schmied", 1.7, 0.9, -0.4, ""], ["boss", 0.0, -6.0, 0.0, ""], ["heart", 0.0, -11.2, 0.0, "", "red"], ["slime", 5.0, -5.5, 0.4, "", 5]],
		"panels": [
			["Akt 2 · Kapitel 8: Vulkaninsel", "Schwarze Felder, wandernde Lava und eine Hitze, die die Stiefel weich macht.", "wide", {}],
			["Seit das Herz hier ist, raucht der Vulkan.", "Magmafürst Brodel schürt sein Feuer damit – Tag und Nacht.", "lm", {"boss": "attack"}],
			["Bricht der Vulkan aus, regnet Asche auf das ganze Tal.", "Dann gibt es kein Talfest mehr. Nie wieder.", "enemy", {}],
			["Obsidian ist härter als jeder Stein.", "Knut sagt, damit hält man sogar Lava auf. Hoffentlich hat er recht.", "group", {"schmied": "hammer"}]]},
	"a7_boss": {"area": 7, "kind": "boss", "title": "Das Herz kehrt heim",
		"cast": [["lead", 0.0, 0.0, -0.3, ""], ["ally", -1.6, 0.7, -0.2, ""], ["ally2", 1.6, 0.8, -0.4, ""], ["boss", 0.0, -6.0, 0.0, "", "down"], ["heart", 0.0, -6.0, 0.0, "", "rise"]],
		"panels": [
			["Magmafürst Brodel stolpert in seine eigene Lava.", "Zischend geht seine Krone aus.", "enemy", {"lead": "cheer"}],
			["Aus der Glut steigt ein kleines Licht.", "Das Sternherz. Kleiner als gedacht – und ziemlich müde.", "heart", {"heart": "rise"}],
			["Es fliegt nicht davon.", "Es kreist einmal um den Trupp und zieht dann heim ins Tal, in den stillen Krater.", "group", {"heart": "circle"}],
			["Ein Herz, das schlafen will.", "Ohne König, ohne Fürst. Nur noch ein leises Leuchten unter dem Tal.", "sky", {}]]},
	"end2": {"area": 0, "kind": "end", "title": "Das Talfest",
		"cast": [["lead", 0.0, 0.0, 0.0, "cheer"], ["ally", -1.8, 0.6, 0.4, "cheer"], ["ally2", 1.8, 0.7, -0.4, "cheer"], ["settler", -3.2, -1.6, 0.8, "eat"],
			["settler", 3.0, -1.8, -0.8, "cheer"], ["prop", 0.0, -2.6, 0.0, "", "p_campfire"], ["haendlerin", -4.4, 1.0, 0.6, "pay"], ["forscher", 4.5, 0.8, -0.6, "eat"],
			["schmied", 4.0, -3.4, -0.5, "cheer"], ["slime", -5.5, -6.5, 0.6, "", 3]],
		"panels": [
			["Ende von Akt 2", "Der Vulkan schläft. Der Krater schläft. Und das Tal feiert.", "wide", {}],
			["Das Talfest!", "Ein Kuchen so groß wie ein Scheunentor und ein Feuerwerk bis zum Frostpass.", "group", {"all": "cheer"}],
			["Am Waldrand sitzen drei kleine Schleimlinge und schauen zu.", "Sie bekommen auch ein Stück. Sie benehmen sich. Meistens.", "enemy_l", {}],
			["Doch tief im Meer bewegt sich etwas.", "Die Haut, so groß wie ein Bus, war nur der Anfang.", "sky", {}],
			["Die Wellen werden kleiner – aber sie kommen noch.", "Halte die Mauern stark. Die Geschichte geht weiter.", "high", {"lead": "wave"}]]},
	# ---------------------------------------------------------------- Akt 3 (Paket Z2): Stadtruinen
	"a8_in": {"area": 8, "kind": "in", "title": "Lichter in der Stadt",
		"cast": [["lead", 0.0, 0.0, 0.2, ""], ["ally", -1.6, 0.7, 0.4, ""], ["forscher", 1.7, 0.9, -0.4, ""], ["boss", 0.0, -6.2, 0.0, ""],
			["prop", -3.4, -2.4, 0.6, "", "p_st_ampel"], ["prop", 3.6, -3.2, -0.5, "", "p_st_car_1"], ["slime", 5.0, -5.5, 0.4, "", 4]],
		"panels": [
			["Akt 3 · Kapitel 9: Stadtruinen", "Nach dem Talfest knackt das Funkgerät: „Die Stadtverwaltung bittet um Ruhe.“", "wide", {}],
			["Im Norden gehen die Lichter an.", "Zum ersten Mal seit Jahren – Ampeln schalten, Rasenmäher mähen Asphalt.", "lm", {}],
			["Sternsplitter im Schleim sind bis ins alte Kraftwerk geflossen.", "Seitdem hat die Stadt Strom – und ihre Maschinen einen eigenen Kopf.", "group", {"forscher": "pick_up"}],
			["Bürgermeister Bolzen.", "Ein Straßenbahnwagen mit Zylinder. Er sammelt Splitter, damit die Lichter nie ausgehen.", "enemy", {"boss": "attack"}],
			["Auf die Dächer, in die Schächte!", "Oben kommt kein Mäher hin. Und unten fährt die U-Bahn – wenn jemand Strom macht.", "high", {"lead": "wave"}]]},
	"a8_boss": {"area": 8, "kind": "boss", "title": "Feierabend",
		"cast": [["lead", 0.0, 0.0, -0.3, ""], ["ally", -1.6, 0.7, -0.2, ""], ["ally2", 1.6, 0.8, -0.4, ""], ["boss", 0.0, -6.2, 0.0, "", "down"],
			["prop", -3.6, -2.6, 0.6, "", "p_st_ampel"], ["slime", 4.8, -5.2, 0.4, "", 3]],
		"panels": [
			["Bürgermeister Bolzen setzt sich hin.", "Aus seinem Akku kullert ein Sternsplitter. Der Zylinder rollt hinterher.", "enemy", {"lead": "cheer"}],
			["Aus allen Lautsprechern knackt es ein letztes Mal:", "„Die Stadtverwaltung wünscht einen schönen Feierabend.“", "sky", {}],
			["Die Maschinen bleiben stehen. Die Lichter bleiben an.", "Jetzt leuchten sie für alle, die hier wieder wohnen wollen.", "group", {"all": "cheer"}],
			["Doch unter der Stadt führen die Schächte tiefer als jede Karte.", "Dort unten leuchtet etwas Blaues. Riecht nach Pilzen. Die Geschichte geht weiter.", "low", {"lead": "wave"}]]},
}
## Reihenfolge in der Chronik: [Szene, Kapitel-Überschrift]
const CHRONICLE := [
	["a0_in", "Kapitel 1 · Grüntal"], ["a0_boss", ""], ["a1_in", "Kapitel 2 · Kiefernforst"], ["a1_boss", ""],
	["a2_in", "Kapitel 3 · Staubebene"], ["a2_boss", ""], ["a3_in", "Kapitel 4 · Schrottküste"], ["a3_boss", ""],
	["a4_in", "Kapitel 5 · Sumpfwerk"], ["a4_boss", ""], ["a5_in", "Kapitel 6 · Frostpass"], ["a5_boss", ""],
	["a6_in", "Kapitel 7 · Schleimkrater"], ["a6_boss", ""], ["end1", "Ende von Akt 1"],
	["a7_in", "Kapitel 8 · Vulkaninsel"], ["a7_boss", ""], ["end2", "Ende von Akt 2"],
	["a8_in", "Kapitel 9 · Stadtruinen"], ["a8_boss", ""],
]
const KIND_NAME := {"in": "Ankunft", "boss": "Nach dem Bosssieg", "end": "Abschluss"}

# ---------------------------------------------------------------- Story-Ziele (zweite Zeile der Ziele-Leiste)
## t: visit (Gebiet betreten) | boss (Gebietsboss besiegt) | rescue (Figur befreit) | scene (Szene gesehen)
const GOALS := [
	{"t": "visit", "a": 0, "text": "Kapitel 1: Brich ins Grüntal auf", "reward": {"coins": 200, "gems": 5}},
	{"t": "boss", "a": 0, "text": "Besiege Dicker Bert im Grüntal", "reward": {"coins": 400, "gems": 10}},
	{"t": "visit", "a": 1, "text": "Kapitel 2: Folge der Spur in den Kiefernforst", "reward": {"wood": 300, "gems": 5}},
	{"t": "boss", "a": 1, "text": "Besiege die Mooskönigin im Kiefernforst", "reward": {"coins": 600, "gems": 10}},
	{"t": "visit", "a": 2, "text": "Kapitel 3: Durchquere die Staubebene", "reward": {"metal": 150, "gems": 5}},
	{"t": "rescue", "k": "haendlerin", "text": "Befreie Rosa, die Händlerin, aus dem Lager der Waschbär-Diebe (Staubebene)", "reward": {"coins": 800, "gems": 15}},
	{"t": "boss", "a": 2, "text": "Besiege den Rostbrocken in der Staubebene", "reward": {"metal": 300, "gems": 10}},
	{"t": "visit", "a": 3, "text": "Kapitel 4: Erreiche die Schrottküste", "reward": {"parts": 10, "gems": 5}},
	{"t": "boss", "a": 3, "text": "Besiege Kapitän Glibber an der Schrottküste", "reward": {"coins": 1000, "gems": 10}},
	{"t": "visit", "a": 4, "text": "Kapitel 5: Dringe ins Sumpfwerk vor", "reward": {"fuel": 100, "gems": 5}},
	{"t": "rescue", "k": "forscher", "text": "Befreie Professor Moosbach aus dem Schleim-Kokon (Sumpfwerk)", "reward": {"cells": 40, "gems": 15}},
	{"t": "boss", "a": 4, "text": "Besiege den Schlund im Sumpfwerk", "reward": {"fuel": 200, "gems": 10}},
	{"t": "visit", "a": 5, "text": "Kapitel 6: Steige auf den Frostpass", "reward": {"stone": 500, "gems": 5}},
	{"t": "rescue", "k": "schmied", "text": "Hacke Knut, den Schmied, aus dem Eis (Frostpass)", "reward": {"parts": 20, "gems": 15}},
	{"t": "boss", "a": 5, "text": "Besiege den Frostbrocken am Frostpass", "reward": {"cells": 60, "gems": 10}},
	{"t": "visit", "a": 6, "text": "Kapitel 7: Betritt den Schleimkrater", "reward": {"shards": 3, "gems": 10}},
	{"t": "boss", "a": 6, "text": "Stürze den Schleimkönig vom Thron", "reward": {"chest": "boss", "gems": 25}},
	{"t": "visit", "a": 7, "text": "Akt 2: Setze auf die Vulkaninsel über", "reward": {"shards": 4, "gems": 10}},
	{"t": "boss", "a": 7, "text": "Besiege Magmafürst Brodel und befreie das Sternherz", "reward": {"chest": "boss", "gems": 40}},
	{"t": "visit", "a": 8, "text": "Akt 3: Folge der Durchsage in die Stadtruinen", "reward": {"parts": 30, "gems": 10}},
	{"t": "boss", "a": 8, "text": "Schick Bürgermeister Bolzen in den Feierabend", "reward": {"chest": "boss", "gems": 40}},
]

# ---------------------------------------------------------------- Sprechblasen der Bewohner (Kapitel 7.1 / 8.2)
const CHAT_EVERY := [7.0, 13.0]              # so oft (s) spricht jemand in der Basis
const CHAT_MAX := 2                          # höchstens so viele Blasen gleichzeitig
const CHAT_TIME := 4.2                       # so lange steht eine Blase (s), plus etwas je Zeichen
const CHAT_RECENT := 24                      # so viele zuletzt gesagte Sätze werden nicht wiederholt
const CHAT_WIN_TIME := 900.0                 # so lange (s Spielzeit) nach einem Flut-Sieg wird gelobt
const CHAT_DIST := 34.0                      # nur Bewohner bis zum 2,5-fachen dieser Entfernung zur Kamera sprechen
const CHAT := {
	"morgen": [
		"Guten Morgen! Wer hat den Kaffee ausgetrunken?",
		"Die Sonne ist wach. Ich noch nicht ganz.",
		"Frühstück vor dem Bunker – das Beste am ganzen Tag.",
		"Hat jemand die Hühner gezählt? Ich komme immer auf elf.",
		"Heute baue ich was Großes. Nach dem zweiten Brötchen.",
		"Der Tau glitzert auf den Mauern. Fast schön.",
		"Morgens riecht das Tal fast wieder wie früher.",
		"Wer zuerst am Lagerfeuer ist, kriegt die warme Bank!",
	],
	"mittag": [
		"Mittagspause! Endlich die Füße hochlegen.",
		"Am Lagerfeuer schmeckt sogar Rübensuppe.",
		"Noch zehn Minuten, dann geht’s weiter. Vielleicht zwanzig.",
		"Wer hat mein Butterbrot? Es war genau hier!",
		"Die Sonne steht hoch. Die Schleimlinge halten Mittagsschlaf.",
		"Einmal Pause, bitte mit extra viel Pause.",
		"Erzählt mir keiner, dass Mauern bauen nicht hungrig macht.",
		"Ich träume von Gretas Apfelkuchen.",
	],
	"abend": [
		"Die Laternen gehen an. Jetzt ist es gemütlich.",
		"Was für ein Tag. Morgen wird es noch besser.",
		"Seht ihr den Himmel? Ganz orange.",
		"Wer hält heute Nachtwache? Ich nicht!",
		"Noch schnell die Werkzeuge wegräumen.",
		"Abends höre ich das Tal atmen. Klingt friedlich.",
		"Gute Arbeit heute, Leute!",
		"Gleich gibt’s Abendbrot. Ich rieche Bratkartoffeln.",
	],
	"nacht": [
		"Psst! Die anderen schlafen schon.",
		"Ich hab da draußen was glucksen hören …",
		"Sterne über dem Bunker. Wie früher.",
		"Ich dreh noch eine Runde an der Mauer.",
		"Gähn. Noch eine Runde, dann ins Bett.",
		"Nachts sind die Mauern höher. Glaube ich.",
	],
	"regen": [
		"Regen! Hoffentlich nicht wieder elf Tage.",
		"Meine Socken sind nass. Alle beide.",
		"Schleimlinge lieben Regen. Ich nicht.",
		"Wer hat das Fenster offen gelassen?",
		"Pitsch, patsch – die Pfützen werden immer größer.",
		"Wenigstens müssen die Blumen nicht gegossen werden.",
		"Ich hoffe, Ada hat ihre Maschine ausgeschaltet.",
		"Regen auf dem Blechdach klingt wie Applaus.",
		"Schnell, unter das Vordach!",
		"Ein Regenbogen wäre jetzt das Mindeste.",
	],
	"schoen": [
		"Was für ein Wetter! Da baut es sich gleich doppelt so gut.",
		"Die Bienen sind zurück. Das ist ein gutes Zeichen.",
		"Bei Sonne glänzen sogar die alten Mauern.",
		"Heute ist ein Tag zum Wäscheaufhängen.",
		"Hörst du die Vögel? Früher war es hier so still.",
		"Sonne auf der Nase – herrlich.",
		"Bei dem Wetter kommt kein Schleimling aus seinem Loch.",
		"Ich glaube, heute wird ein guter Tag.",
	],
	"flut_bald": [
		"Die Flut kommt bald. Sind die Mauern dicht?",
		"Ich habe die Türme dreimal geputzt. Sicher ist sicher.",
		"Noch ein, zwei Tage. Dann schwappt es wieder.",
		"Mein Bauch sagt: Flut. Mein Kopf sagt: Mauern!",
		"Wer noch Steine hat, bitte zur Mauer bringen!",
		"Ich habe schon mal Platz im Bunker gemacht.",
		"Die Hühner sind so unruhig. Die spüren das.",
		"Lass uns noch einen Turm bauen. Nur zur Sicherheit.",
		"Diesmal halten wir sie auf. Ganz bestimmt.",
		"Ich hab die Sandsäcke gezählt. Es könnten mehr sein.",
	],
	"flut_heute": [
		"Heute ist Fluttag! Alle auf ihre Plätze!",
		"Hörst du das Schmatzen? Sie kommen!",
		"Ich verstecke mich im Bunker. Rein strategisch.",
		"Zeig’s ihnen! Wir halten dir den Rücken frei.",
		"Die Glocke! Alle Mann an die Mauern!",
		"Mutig sein. Und dann ganz schnell in den Bunker.",
		"Heute brauchen die Türme jede Kugel.",
		"Viel Glück! Wir zählen auf dich!",
	],
	"sieg": [
		"Gewonnen! Habt ihr die Schleimlinge rennen sehen?",
		"Das war knapp. Aber wir stehen noch!",
		"Hoch lebe der Bunker! Hoch lebe unser Held!",
		"Ich hab nicht gezittert. Höchstens ein bisschen.",
		"So eine Flut steckt unsere Mauer locker weg.",
		"Heute Abend wird gefeiert!",
		"Die Glocke hat geläutet – die Post ist angekommen!",
		"Unglaublich, wie du die abgewehrt hast!",
		"Die Türme haben gesungen. Bumm, bumm, bumm!",
		"Nächste Woche gleich noch mal? Na gut.",
	],
	"schaden": [
		"Oje, die Mauer hat ein Loch. Ein großes.",
		"Wer repariert das? Ach so, ich.",
		"Mein schönes Gebäude! Ganz verbeult.",
		"Schleim überall. Das dauert, bis das sauber ist.",
		"Hammer und Nägel her – wir flicken das!",
		"Die haben ganz schön zugebissen.",
		"Nächstes Mal bauen wir die Mauer doppelt.",
		"Das sieht schlimmer aus, als es ist. Hoffe ich.",
		"Ein paar Bretter, ein bisschen Mut – wird schon.",
		"Wer hat hier draufgesabbert? Ach, die Schleimlinge.",
	],
	"wunsch": [
		"Ich hätte da einen kleinen Wunsch …",
		"Wenn du mal Zeit hast: Ich wünsche mir was!",
		"Nur ein kleiner Wunsch. Ganz klein. Versprochen.",
		"Hast du meinen Wunsch gesehen? Das Herz über mir!",
		"Ein Wunsch, und ich bin der glücklichste Bewohner im Tal.",
		"Ich träume von etwas Schönem für unsere Basis.",
	],
	"holz": [
		"Holz vor der Hütte! Na ja, vor dem Sägewerk.",
		"Achtung, Baum fällt! Kleiner Scherz.",
		"Jeder Baum wächst nach. Ich pass auf.",
		"Sägespäne im Haar – das ist mein Duft.",
	],
	"stein": [
		"Stein auf Stein, so muss das sein.",
		"Diese Schubkarre quietscht wie ein Schleimling.",
		"Aus diesem Stein wird mal eine Mauer. Eine schöne.",
		"Granit, Basalt, Kiesel – ich liebe sie alle.",
	],
	"schrott": [
		"Das ist kein Müll, das ist ein Ersatzteil!",
		"Aus drei kaputten Dingen mach ich ein ganzes.",
		"Die Presse frisst alles. Fast so wie die Schleimlinge.",
		"Ich habe eine Radkappe gefunden. Meine neue Lieblingsradkappe.",
	],
	"technik": [
		"Wenn es summt, ist es gut. Wenn es brummt, ist es schlecht.",
		"Ich hab die Kabel sortiert. Nach Farben.",
		"Ohne Zellen keine Türme. Ohne mich keine Zellen.",
		"Puh. Wer hat den Generator so warm gemacht?",
	],
	"traeger": [
		"Kisten tragen ist wie Sport. Nur ohne Pause.",
		"Links, rechts, Lager. Links, rechts, Lager.",
		"Wer hat das so schwer gepackt?",
		"Ich trage alles. Außer schlechte Laune.",
	],
	"wache": [
		"Ich halte die Augen offen. Alle beide.",
		"Nichts zu sehen. Gut so.",
		"Da hinten! … Ach, nur ein Busch.",
		"Wache halten ist wichtig. Und langweilig.",
		"Keiner kommt hier durch. Außer dir natürlich.",
	],
	"gaertner": [
		"Blumen machen Mut. Glaub mir.",
		"Die Tulpen wachsen schneller als die Mauern.",
		"Ein bisschen Grün tut dem Bunker gut. Das gute Grün.",
		"Wer hat in mein Beet getreten? Schleimspuren!",
	],
	"bau": [
		"Das hier wird mein Meisterwerk.",
		"Erst messen, dann bauen. Oder umgekehrt?",
		"Noch ein Brett, noch ein Nagel, fertig.",
		"Die Drohnen sind fleißig. Ich auch!",
	],
	"hand": [
		"Kaputt? Gib her, das krieg ich hin.",
		"Ein bisschen Kleber, ein bisschen Liebe.",
		"Reparieren ist wie Bauen, nur mit mehr Seufzen.",
		"Wieder heile. Na ja, fast.",
	],
	"allgemein": [
		"Schön, dass du da bist!",
		"Ich habe gehört, im Krater wohnt ein Stern.",
		"Wenn das hier vorbei ist, feiern wir das Talfest.",
		"Hast du schon die neuen Mauern gesehen?",
		"Jona hat mir einen Brief gebracht. Von mir an mich.",
		"Weißt du, was ich vermisse? Langeweile.",
		"Früher war hier ein Spielplatz. Bruno baut ihn wieder auf.",
		"Ich übe schon mal fürs Feuerwerk. Nur mit Wunderkerzen.",
		"Unser Bunker ist der schönste im ganzen Tal.",
		"Manchmal winke ich den Schleimlingen. Die winken nie zurück.",
		"Ich glaube, die Hühner planen etwas.",
		"Wenn ich groß bin, werde ich Held. Ich bin schon groß.",
		"Wer pfeift da? Ach, der Wind in der Antenne.",
		"Rohstoffe, Rohstoffe, Rohstoffe. Ich träume schon davon.",
		"Danke, dass du auf uns aufpasst!",
	],
	"tippen": [
		"Oh, hallo! Ich hab dich gar nicht kommen sehen.",
		"Ja? Brauchst du was?",
		"Keine Sorge, ich arbeite. Ganz bestimmt.",
		"Nicht kitzeln!",
		"Alles bestens hier. Wirklich.",
		"Du bist der Chef. Sag einfach, was zu tun ist.",
		"Ich halte hier die Stellung!",
		"Schön, dich zu sehen!",
		"Hast du Neuigkeiten von draußen?",
		"Pass auf dich auf da draußen.",
		"Ich hab heute schon drei Schleimlinge gesehen. Von Weitem.",
		"Wenn du einen Wunsch frei hättest – ich hätte drei.",
	],
}
## Sätze, sobald der Boss des Gebiets (Index) besiegt ist – die Bewohner erzählen von der Geschichte.
const CHAT_STORY := [
	["Dicker Bert ist geplatzt? Endlich!", "Ein Sternsplitter, der nach Süden zeigt? Unheimlich."],
	["Der Nebel im Forst ist weg, sagt man.", "Bruno sucht immer noch nach Teilen von Berta."],
	["Ein Kessel, der regnet? Hab ich’s doch gewusst!", "Ada sagt, sie baut nie wieder ohne Aus-Knopf."],
	["Die Matrosen von der Möwe sind wieder nett.", "Was liegt wohl auf dem Meeresgrund?"],
	["Die Pumpen im Sumpfwerk stehen still. Gut so!", "Der Krater liebt Wasser? Dann bekommt er keins mehr."],
	["Die Zugvögel sind unterwegs! Ich hab sie gesehen!", "Ein Stern im Krater … wie der wohl aussieht?"],
	["Der Schleimkönig ist weg! Aber wo ist das Herz?", "Am Horizont raucht die Vulkaninsel. Gefällt mir nicht."],
	["Das Sternherz ist zurück! Ganz leise leuchtet es.", "Talfest! Talfest! Ich hab schon den Kuchen bestellt."],
	["In der Stadt gehen die Lichter an – für uns!", "Ein Bürgermeister mit Zylinder? Und ich dachte, ich hab schon alles gesehen."],
]
## Eigene Sätze der Geretteten
const FIG_LINES := {
	"haendlerin": [
		"Alles hat seinen Preis – außer Freundschaft. Die kostet extra.",
		"Heute im Angebot: Holz gegen Stein! Fast geschenkt!",
		"Ich hab da noch ein Ei. Frag nicht, was drin ist.",
		"Die Waschbären haben meine besten Töpfe. Ich will sie zurück!",
		"Handeln ist wie Tanzen. Einer tritt dem anderen auf die Füße.",
		"Für dich mache ich einen Sonderpreis. Den gleichen wie immer.",
		"Die Karawane fährt wieder, sobald die Straßen sicher sind.",
		"Ein Bunker mit Laden – jetzt seid ihr eine richtige Stadt!",
		"Wer nicht feilscht, zahlt zu viel. Merk dir das.",
		"Danke, dass du mich da rausgeholt hast. Der Tee geht aufs Haus.",
	],
	"forscher": [
		"Faszinierend! Der Schleim besteht zu einem Teil aus Sternenstaub.",
		"Ada war meine beste Studentin. Und meine lauteste.",
		"Bitte nicht stören, ich zähle Sporen.",
		"Mit meinen Notizen geht die Forschung viel schneller.",
		"Im Kokon hatte ich viel Zeit zum Nachdenken. Und keinen Bleistift.",
		"Der Krater ist ein Sternabdruck. Ich wusste es!",
		"Hypothese: Schleimlinge mögen Musik. Versuch läuft.",
		"Wissenschaft ist, wenn man trotzdem weitermacht.",
		"Hast du schon einmal einen Schleimling von innen gesehen? Ich schon.",
		"Ein Labor im Bunker – herrlich! Fast wie zu Hause.",
	],
	"schmied": [
		"Gutes Eisen. Gutes Feuer. Gute Waffe.",
		"Bring mir deine Waffen. Ich mache sie besser. Und billiger.",
		"Mein Deckel liegt noch am Frostpass. Er war zu groß.",
		"Kalt war’s im Eis. Jetzt ist mir warm.",
		"Hm.",
		"Ein Hammer löst die meisten Probleme. Der Rest braucht zwei.",
		"Obsidian. Damit baue ich dir eine Mauer, die hält.",
		"Ich rede nicht viel. Ich schmiede.",
		"Danke. Für das mit dem Eis.",
		"Der Amboss singt heute. Hörst du?",
	],
}

# ---------------------------------------------------------------- Helden-Gespräche beim Expeditionsstart
## [vor Ort, per Funk]: Zeilen abwechselnd; "a" = der gespielte Held, "b" = der Held in der Basis (Funk).
## Paare passen zu bestimmten Helden; area = nur in diesem Gebiet (-1 = überall).
const TALKS := [
	{"a": "jona", "b": "mika", "area": -1, "lines": [["b", "Jona, hast du den Helm auf?"], ["a", "Ich trag doch einen."], ["b", "Den richtigen! Mit Brille!"]]},
	{"a": "mika", "b": "jona", "area": -1, "lines": [["b", "Funke, bitte nichts anzünden, was wir noch brauchen."], ["a", "Ich zünde nur an, was schleimt."], ["b", "Das ist fast alles."]]},
	{"a": "bruno", "b": "ada", "area": -1, "lines": [["b", "Bruno, Pieps sagt, du hast dein Butterbrot vergessen."], ["a", "Geht schon."], ["b", "Er bringt es dir. Er fliegt schon los."]]},
	{"a": "ada", "b": "bruno", "area": -1, "lines": [["b", "Ada, bitte keine neuen Erfindungen unterwegs."], ["a", "Nur eine kleine."], ["b", "Ich hol schon mal den Werkzeugkasten."]]},
	{"a": "yuki", "b": "jona", "area": -1, "lines": [["b", "Yuki, siehst du was?"], ["a", "Drei Nester, zwei Kisten und einen sehr dicken Schleimling."], ["b", "Ich hab nur gefragt, ob du was siehst."]]},
	{"a": "greta", "b": "mika", "area": -1, "lines": [["b", "Oma Greta, hast du genug Raketen dabei?"], ["a", "Kind, ich hab immer genug Raketen dabei."], ["b", "Das macht mir ein bisschen Angst."]]},
	{"a": "nele", "b": "yuki", "area": -1, "lines": [["b", "Nele, Kiko hat Möwen gezählt. Vierzehn."], ["a", "Und Schleimlinge?"], ["b", "Die hat er aufgegeben."]]},
	{"a": "jona", "b": "greta", "area": -1, "lines": [["b", "Jona, bring Äpfel mit, wenn du welche siehst."], ["a", "Ich bin Held, nicht Gemüsehändler."], ["b", "Kein Apfel, kein Kuchen."], ["a", "… Ich schau mal."]]},
	{"a": "mika", "b": "bruno", "area": 1, "lines": [["b", "Mika, im Forst nichts abfackeln. Da steht Berta."], ["a", "Ich pass auf deinen Bagger auf."], ["b", "Danke."]]},
	{"a": "bruno", "b": "mika", "area": 1, "lines": [["b", "Bruno, hörst du was?"], ["a", "Ein Motor. Ganz leise."], ["b", "Das ist dein Herz, Bruno."], ["a", "… Vielleicht beides."]]},
	{"a": "ada", "b": "jona", "area": 2, "lines": [["b", "Ada, ist das nicht die Gegend, wo dein Labor stand?"], ["a", "Zwei Wände und ein Kühlschrank."], ["b", "Und das Käsebrot?"], ["a", "Lass es bitte liegen."]]},
	{"a": "yuki", "b": "nele", "area": 3, "lines": [["b", "Yuki, die Spur ins Meer – hast du sie aufgeschrieben?"], ["a", "Jede Feder, jede Pfütze."], ["b", "Gut. Irgendwann tauchen wir da runter."]]},
	{"a": "nele", "b": "bruno", "area": 3, "lines": [["b", "Nele, die Taucherglocke ist fertig."], ["a", "Singst du wieder, wenn wir runterfahren?"], ["b", "Nur, wenn du nicht zuhörst."]]},
	{"a": "greta", "b": "jona", "area": 4, "lines": [["b", "Greta, im Sumpfwerk soll ein Fass Zimt stehen."], ["a", "Ich weiß. Ich hole es."], ["b", "Für den Kuchen?"], ["a", "Für den größten Kuchen der Welt."]]},
	{"a": "mika", "b": "greta", "area": 4, "lines": [["b", "Mika, deine Wehr wartet auf dem Fabrikdach!"], ["a", "Fünf Helme, Oma Greta. Ich hab sie alle geputzt."], ["b", "Dann hol sie heim, Kind."]]},
	{"a": "yuki", "b": "ada", "area": 5, "lines": [["b", "Yuki, Pieps misst minus zwanzig Grad."], ["a", "Die Vögel frieren nicht. Sie warten."], ["b", "Worauf?"], ["a", "Auf uns, glaube ich."]]},
	{"a": "jona", "b": "ada", "area": 6, "lines": [["b", "Jona … falls es meine Schuld ist …"], ["a", "Ada. Wer Regen machen kann, kann ihn auch abstellen."], ["b", "Das hat Greta auch gesagt."]]},
	{"a": "ada", "b": "greta", "area": 6, "lines": [["b", "Ada, Kind, du schaffst das."], ["a", "Und wenn nicht?"], ["b", "Dann backe ich trotzdem einen Kuchen."]]},
	{"a": "greta", "b": "nele", "area": 7, "lines": [["b", "Greta, da drüben ist Obsidian. Für Mauern."], ["a", "Und für Raketen-Startrampen."], ["b", "Natürlich."]]},
	{"a": "bruno", "b": "greta", "area": 7, "lines": [["b", "Bruno, es ist heiß da draußen. Trink was!"], ["a", "Geht schon."], ["b", "Bruno!"], ["a", "… Ich trink was."]]},
	{"a": "ada", "b": "jona", "area": 8, "lines": [["b", "Ada, kriegst du die Generatoren wieder an?"], ["a", "Ich hab schon ganz andere Sachen angekriegt."], ["b", "Genau das macht mir Sorgen."]]},
	{"a": "jona", "b": "bruno", "area": 8, "lines": [["b", "Jona, da drüben steht ein Bagger auf zwei Beinen."], ["a", "Ist das Berta?"], ["b", "Nein. Berta hat Manieren."]]},
]
## Wenn kein passendes Paar da ist: ein Bewohner funkt aus der Basis. Je Gebiet ein Hinweis, dazu allgemeine.
const TALK_RADIO := [
	"Hier Bunker! Pass auf dich auf da draußen!",
	"Funkcheck: Hörst du mich? Gut. Viel Glück!",
	"Bring was Schönes mit – und dich selbst in einem Stück!",
	"Wir halten hier die Stellung. Du schaffst das!",
]
const TALK_AREA := [
	"Im Grüntal laufen alle Schleimspuren nach Süden. Folg ihnen!",
	"Im Kiefernforst: leise gehen, nicht rennen!",
	"Staubebene: Halt Ausschau nach dem Lager der Waschbär-Diebe!",
	"Schrottküste: Die Matrosen tun nichts. Meistens.",
	"Im Sumpfwerk soll ein Professor im Schleim stecken. Hol ihn raus!",
	"Am Frostpass ist ein Schmied eingefroren. Nimm was zum Hacken mit!",
	"Der Krater … sei vorsichtig. Wirklich vorsichtig.",
	"Vulkaninsel: Schau auf die Risse – die glühen, bevor die Lava kommt!",
	"Stadtruinen: Auf den Dächern bist du sicher vor den Mähern. Und halt an roten Ampeln – die Maschinen tun es auch!",
]
const TALK_LEAD := [
	"Verstanden. Ich bin unterwegs!",
	"Alles klar. Bis später!",
	"Mach dir keine Sorgen. Ich komme heil zurück.",
	"Wird gemacht!",
]
const TALK_GAP := 2.6                        # Sekunden zwischen zwei Zeilen

# ---------------------------------------------------------------- Auto-Expeditionen (Kapitel 4.3)
## Gefahr: Grundwert je Dauer (1/4/8 Std), +RISK_UNDER je Stufe unter der Empfehlung (D.EXP_HERO_LEVEL), höchstens RISK_MAX.
const RISK_BASE := {1: 0.05, 4: 0.1, 8: 0.16}
const RISK_UNDER := 0.025
const RISK_OVER := 0.01                      # je Stufe über der Empfehlung weniger (höchstens bis RISK_MIN)
const RISK_MIN := 0.02
const RISK_MAX := 0.6
const INJURY_MIN := [20.0, 35.0, 50.0]       # Verletzung (Minuten) je Dauer 1/4/8 Std
const EVENTS_N := {1: 2, 4: 3, 8: 4}         # Ereignisse je Dauer
const REPORTS_KEEP := 12
const DANGER_NAME := ["Gering", "Mittel", "Hoch"]
## Ereignisse: text, gain (Wirkung: chest = Fundkiste, res = Gebietsrohstoff +%, xp = Erfahrung +%, egg = Begleiter-Ei), Gewicht
const AUTO_EVENTS := [
	{"text": "Ein Schleimnest umgangen", "gain": {}, "w": 3.0},
	{"text": "Eine Fundkiste geborgen", "gain": {"chest": 1}, "w": 1.5},
	{"text": "Ein Rudel Schleimlinge vertrieben", "gain": {"xp": 0.2}, "w": 2.5},
	{"text": "Am Lagerfeuer übernachtet und gut geschlafen", "gain": {}, "w": 1.5},
	{"text": "Einen Rastplatz voller Rohstoffe gefunden", "gain": {"res": 0.25}, "w": 2.0},
	{"text": "Einem verirrten Bewohner den Heimweg gezeigt", "gain": {"xp": 0.1}, "w": 1.2},
	{"text": "Eine alte Vorratskammer geplündert", "gain": {"res": 0.15}, "w": 1.5},
	{"text": "Zwei Fundkisten hinter einem Felsen entdeckt", "gain": {"chest": 2}, "w": 0.6},
	{"text": "Ein Begleiter-Ei in einem verlassenen Nest gefunden", "gain": {"egg": 1}, "w": 0.15},
]
const AUTO_AREA_EVENTS := [
	["Äpfel am alten Baum hinter dem Bach gepflückt", "Die Mühle läuft wieder – Frieda hat Brot mitgegeben"],
	["Im Nebel verlaufen – aber wieder herausgefunden", "Ein gelbes Baggerteil für Bruno gefunden"],
	["Sandsturm überstanden", "Kaktuswasser gezapft und schneller gelaufen"],
	["Bei Ebbe ein Wrack durchsucht", "Die Matrosen der Möwe haben freundlich gewunken"],
	["Giftnebel ausgewichen", "Ein Fass mit seltsamem Zimt gefunden"],
	["Einer Lawine entkommen", "Mit den Zugvögeln auf dem Pass gerastet"],
	["Meteorschauer überstanden", "Sternsplitter aus einem Geysir gefischt"],
	["Über einen Lavastrom gesprungen", "Im Schatten eines Obsidianfelsens abgekühlt"],
	["Mit der U-Bahn quer durch die Stadt gefahren", "Von einem Dach aus die Mäher gezählt"],
]
const AUTO_DANGER := [
	"Vom Dicken Bert überrascht", "Von der Mooskönigin umrankt", "Vom Rostbrocken umgerannt", "Von Kapitän Glibber über Bord geworfen",
	"Vom Schlund angeknabbert", "Vom Frostbrocken eingeschneit", "Vom Schleimkönig angefaucht", "Von Magmafürst Brodel angesengt",
	"Von Bürgermeister Bolzen verwarnt",
]
