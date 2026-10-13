# Rustwall – Die Hauptgeschichte

Stand: Version 6, Paket E (Geschichte, Zwischenszenen, Rettungen, Sprechblasen).
Diese Datei ist die Grundlage für alle Texte in `src/data_geschichte.gd`. Sie widerspricht den Helden-Kapiteln in
`src/data.gd` (`HEROES[*].chapters`) und den Tagebuchseiten in `src/data_welt.gd` (`JOURNAL`) nicht, sondern bindet sie ein.

## Der Ton

Comic, freundlich, ein bisschen schräg – ein Kinderspiel mit Herz. Niemand stirbt, Gegner „platzen“, „zerfließen“ oder
„gehen von Bord“. Die Bösen sind eher eitel und laut als grausam. Jede Szene hat höchstens fünf Tafeln, jede Tafel eine
große Zeile (höchstens etwa 60 Zeichen) und eine kleine Zeile (höchstens etwa 120 Zeichen).

## Die rote Linie in einem Satz

Vor langer Zeit fiel ein Stern ins Tal und schlief als **Sternherz** tief unter dem heutigen Schleimkrater – bis Adas
Wettermaschine elf Tage Regen machte, das Herz weckte und der **Schleimkönig**, ein Dämon aus dem Feuer unter der Welt,
sich auf seinen Thron setzte und es jede Woche zu einem Schlag zwang: Jeder Herzschlag ist eine Flut.

## Die drei Fragen und ihre Antworten

| Frage | Antwort | Wo der Spieler es erfährt |
|---|---|---|
| Woher kommt der Schleim? | Aus dem Sternherz unter dem Krater. Der große Regen (Adas Wettermaschine) hat es geweckt, der Schleim quoll aus der Tiefe. | Grüntal (Spur nach Süden), Staubebene (der Wetterkessel), Sumpfwerk (Pumpen zum Krater) |
| Was ist im Krater? | Ein Ring aus Stein, darin das Sternherz. Der Krater ist der Abdruck eines Sterns – Sternsplitter beweisen es. Auf dem Ring thront der Schleimkönig. | Frostpass (Riesensplitter unter dem Eis), Schleimkrater |
| Was hat es mit der Vulkaninsel auf sich? | Der Schleimkönig war nur Statthalter von **Magmafürst Brodel**. Als der König fällt, flieht er durch den Ring und reißt das Herz mit auf die Insel. Brodel will damit den Vulkan zum Ausbruch bringen. | Ende von Akt 1, Vulkaninsel |

Warum kommen die Fluten jede Woche? Das Herz schlägt einmal in der Woche – der König drückt zu, der Schleim schwappt über
das Tal. Nach Akt 1 werden die Fluten kleiner, hören aber nicht auf: Der Schleim steckt längst im ganzen Land und im Meer
(dort wächst der Schleim-Leviathan – Ausblick nach Akt 2). So bleibt die Wochenflut im Spiel erklärt.

## Figuren

### Der Trupp (Helden, siehe `data.gd`)
- **Jona Stern**, der Briefträger – immer dabei (Start-Held). Er „liest“ Spuren wie Adressen. In den Szenen der Erzähler-Freund.
- **Mika „Funke“ Brandt** (Grüntal), **Bruno Bollwerk** (Kiefernforst), **Dr. Ada Volt** (Staubebene), **Yuki Falke** und
  **Nele Brandung** (Schrottküste), **Oma Greta** (Sumpfwerk). Szenen zeigen den gerade gespielten Helden und bis zu zwei weitere
  gerettete Helden. Die Texte nennen nur Jona und die Figuren, die sicher bekannt sind; Adas Schuld wird über den Kessel mit
  ihrem Namen erzählt (Ada selbst gesteht es am Lagerfeuer – Kapitel 4 ihrer eigenen Geschichte).

### Die Geretteten (neu)
| Figur | Gebiet | Ereignis | Zieht in die Basis und … |
|---|---|---|---|
| **Rosa Kramer**, die Händlerin | Staubebene | **Gegnerlager**: Waschbär-Diebe halten sie mit ihrem Karren gefangen. Erst die Wachen vertreiben, dann den Käfig öffnen. | … baut den **Tauschladen** (neues Gebäude): täglich wechselnde Tauschangebote, einmal je Woche ein Begleiter-Ei. |
| **Professor Theo Moosbach**, der Forscher | Sumpfwerk | **Falle**: Er steckt in einem Schleim-Kokon im Kesselhaus. Den Kokon zerschießen. | … hilft im Labor: **Forschung 25 % schneller**. |
| **Knut Amboss**, der Schmied | Frostpass | **Käfig aus Eis**: festgefroren auf dem Weg zum Krater. Neben ihm stehen bleiben und das Eis aufhacken, während Eiswesen angreifen. | … arbeitet in der Werkstatt: **Waffen verbessern 20 % günstiger**. |

- **Rosa** ist die Händlerin der Karawane („Jeden zweiten Tag kommt die Karawane vorbei“ – Tagebuch Staubebene). Redet viel,
  feilscht um alles, hat ein Herz aus Gold („Alles hat seinen Preis – außer Freundschaft. Die kostet extra.“). Breiter
  Sonnenhut, orange Kleidung, riesige Kraxe mit Töpfen.
- **Professor Moosbach** war Adas Lehrer. Er wollte den Schleim erforschen – „der Schleim hat zurückgeforscht“. Tropenhelm,
  runde Brille, weißer Bart, Tweedjacke, Ledertasche voller Notizbücher. Er erklärt, dass Sternsplitter im Schleim stecken.
- **Knut Amboss** hat den Stahldeckel geschmiedet, mit dem er den Krater „zumachen“ wollte. Kam nur bis zum Frostpass. Roter
  Bart, Kopftuch, Lederschürze, Schmiedehammer auf dem Rücken. Wortkarg, aber jeder Satz sitzt.

### Die Gegenseite
- **Das Sternherz**: kein Bösewicht. Ein müdes, leuchtendes Wesen aus Sternenstaub, das schlafen will. Schleim ist sein „Echo“.
- **Die Gebietsbosse** sind vom Schleim des Herzens aufgeblähte Wesen des Gebiets (Dicker Bert, Mooskönigin, Rostbrocken,
  Kapitän Glibber, Der Schlund, Frostbrocken). Nach dem Sieg bleibt jeweils ein Hinweis zurück.
- **Der Schleimkönig**: ein Dämon in einer Schleimhülle (deshalb bricht im Kampf der Dämon aus dem Schleimriesen hervor).
  Eitel, laut, Statthalter Brodels.
- **Magmafürst Brodel**: der Herr des Königs, schürt das Feuer der Vulkaninsel mit dem gestohlenen Herzen.

## Akt 1 – Die Spur zum Krater

### Kapitel 1: Grüntal
- **Beim ersten Betreten („Grüne Bäche“)**: Der Bach ist grün, die Müllerin Frieda erzählt vom Regen. Alle Schleimspuren laufen
  bergauf, nach Süden – zum Krater.
- **Nach dem ersten Sieg über Dicker Bert („Die Krone“)**: In Berts Krone steckt ein Sternsplitter, der warm wird, wenn man ihn
  nach Süden hält. „Ein Brief mit Adresse“, sagt Jona. Absender: Krater.

### Kapitel 2: Kiefernforst
- **Betreten („Nebel im Forst“)**: Irrlichter, Kettenspuren (Brunos Berta), die Mooskönigin lässt den Wald über die Straßen wachsen.
- **Sieg („Das Moos weicht“)**: Aus dem Pilzhut rieseln Sternsplitter wie Sporen; der Nebel hebt sich. Die Karte des Försters
  an der Riesenkiefer: Alle grünen Linien laufen zum Krater.

### Kapitel 3: Staubebene
- **Betreten („Staub und Schrott“)**: Die Karawane ist überfallen, Rosa gefangen. Der Rostbrocken stapft durch die Wracks –
  mit einem Kessel im Bauch, aus dem es regnet.
- **Sieg („Der Wetterkessel“)**: Auf dem Kessel steht „Dr. A. Volt – Wettermaschine Nr. 1“. Der Regen hat etwas unter dem Krater
  geweckt, und der Kessel hat es seitdem gefüttert. Einen Aus-Knopf hat er nicht – er bekommt eine Delle und hört auf.
- **Rettung**: Rosa (Gegnerlager) → Tauschladen.

### Kapitel 4: Schrottküste
- **Betreten („Das Leuchtfeuer“)**: Eine Schleimspur, breit wie eine Straße, führt ins Meer (Neles Kapitel 3). Die Mannschaft der
  Möwe steht nachts am Strand, ihr Kapitän heißt jetzt Glibber.
- **Sieg („Glibber geht von Bord“)**: Die Matrosen werden wieder Seeleute. Der Steuermann erzählt von einer Haut, groß wie ein
  Bus, auf dem Meeresgrund (Neles Kapitel 4) – etwas wächst im Meer. Aber die Quelle liegt im Krater.

### Kapitel 5: Sumpfwerk
- **Betreten („Das Werk pumpt“)**: Der Schlot raucht, in den Rohren klopft es. Im Kesselhaus Adas Notizbuch und ein Kokon mit
  Tropenhelm: Professor Moosbach.
- **Sieg („Der Schlund schweigt“)**: Die Pumpen stehen still. Alle Rohre führten zum Krater: Das Werk hat Woche für Woche Wasser
  hineingepumpt. Was im Krater wohnt, liebt Wasser und wächst davon.
- **Rettung**: Professor Moosbach (Schleimfalle) → Forschung schneller.

### Kapitel 6: Frostpass
- **Betreten („Die Vögel warten“)**: Tausende Zugvögel sitzen auf den Felsen und schauen nach Süden (Yukis Kapitel 4). Unter dem
  Eisbogen leuchtet etwas blau. Knut steckt im Eis.
- **Sieg („Der Pass ist frei“)**: Unter dem Eis liegt ein Sternsplitter, groß wie ein Haus. Der Krater ist der Abdruck eines Sterns –
  und der Stern liegt noch drin.
- **Rettung**: Knut Amboss (Eiskäfig) → Waffen verbessern günstiger.

### Kapitel 7: Schleimkrater
- **Betreten („Das Sternherz“)**: Der Ring aus Stein, darin das pulsierende Herz. Es fiel vor langer Zeit vom Himmel und schlief,
  bis der Regen kam. Auf dem Ring thront der Schleimkönig und drückt jede Woche zu – jeder Herzschlag eine Flut.
- **Sieg („Der König fällt“)**: Die Hülle platzt, ein Dämon flieht in den Ring, der Ring färbt sich rot, ein Feuerstrahl schießt zur
  Insel am Horizont. Das Herz ist weg – der König war nur Statthalter. Der Krater wird still, ein paar Vögel steigen auf
  (Yukis Kapitel 5), das Grün wird blasser (Adas Kapitel 5).
- **Abschlussszene Akt 1 („Ein Funke im Süden“)**: Das Tal feiert, die Fluten werden kleiner. Am Horizont raucht die Vulkaninsel:
  Magmafürst Brodel. Ausblick auf Akt 2.

## Akt 2 – Das Feuer im Süden

### Kapitel 8: Vulkaninsel
- **Betreten („Die Insel brennt“)**: Seit das Herz hier ist, raucht der Vulkan, die Lava wandert (passt zum Tagebuch der Inselwache).
  Bricht er aus, regnet Asche auf das Tal – kein Talfest mehr. Obsidian hält Lava auf (Knut, Tagebuch).
- **Sieg („Das Herz kehrt heim“)**: Brodel stolpert in die eigene Lava. Aus der Glut steigt das Sternherz, klein und müde, kreist
  einmal um den Trupp und kehrt in den stillen Krater zurück – nur noch ein leises Leuchten unter dem Tal.
- **Abschlussszene Akt 2 („Das Talfest“)**: Das Talfest (Gretas Kapitel 5) – Kuchen, Feuerwerk, drei Schleimlinge am Waldrand.
  Ausblick: Tief im Meer bewegt sich etwas (Schleim-Leviathan). Die Wellen werden kleiner, aber sie kommen noch.

## Akt 3 – Die Stadt der Maschinen (Paket Z2)

### Kapitel 9: Stadtruinen
- **Hintergrund:** Die Sternsplitter im Schleim sind über die Jahre bis ins alte Kraftwerk der Stadt im Norden geflossen. Seitdem
  hat die Stadt wieder Strom – und ihre Maschinen einen eigenen Kopf. **Bürgermeister Bolzen**, der alte Rathaus-Automat (ein
  aufrechter Straßenbahnwagen mit Uhrengesicht, Bürstenbart und Blech-Zylinder), sammelt Splitter, „damit die Lichter nie ausgehen“.
  Er ist kein Bösewicht im eigentlichen Sinn: pedantisch, ordnungsliebend, er hält Durchsagen und lässt Rasenmäher Asphalt mähen.
- **Betreten („Lichter in der Stadt“)**: Nach dem Talfest knackt das Funkgerät – „Die Stadtverwaltung bittet um Ruhe.“ Im Norden
  gehen die Lichter an. Professor Moosbach erklärt die Splitter im Kraftwerk. Auf die Dächer, in die Schächte!
- **Sieg („Feierabend“)**: Bolzen setzt sich hin, ein Sternsplitter kullert aus seinem Akku, der Zylinder rollt hinterher. Letzte
  Durchsage: „Die Stadtverwaltung wünscht einen schönen Feierabend.“ Die Maschinen bleiben stehen, die Lichter bleiben an – für alle,
  die hier wieder wohnen wollen. Ausblick: Unter der Stadt führen die Schächte tiefer als jede Karte, dort leuchtet etwas Blaues und
  riecht nach Pilzen (Pilzwald-Unterwelt, Kapitel 5.2 der PDF).
- **Tagebuch** (`data_welt.gd`, `JOURNAL.stadt`): Fernsehturm, Durchsage, Ampeln, Unter der Stadt – passt dazu.
- Story-Ziele: „Akt 3: Folge der Durchsage in die Stadtruinen“, „Schick Bürgermeister Bolzen in den Feierabend“.

## Umsetzung im Spiel

- **Zwischenszenen** (`src/story_scene.gd`, Bühne `src/story_stage.gd`): Texttafeln mit schwarzen Balken wie das Intro, darunter
  eine eigene kleine 3D-Bühne des Gebiets (Boden in Gebietsfarben, Bäume, Felsen, Wahrzeichen, Helden, Gerettete, Boss,
  Schleimlinge) mit Kamerafahrt. Überspringbar („Überspringen ›“, Esc/Leertaste), eine Tafel weiter mit Tippen.
  - erstes Betreten eines Gebiets → Szene „Betreten“ (zu Beginn der Expedition),
  - erster Sieg über den Gebietsboss (Kopfgeld) → Szene „Sieg“, im Schleimkrater danach Abschluss Akt 1, auf der Vulkaninsel
    Abschluss Akt 2.
- **Chronik** (neuer Bildschirm): alle Kapitel mit Bild, gesehene Szenen wieder ansehen, Prolog (= Intro), die Geretteten,
  das nächste Story-Ziel.
- **Story-Ziele** in der Ziele-Leiste (`guide.gd`): eine zweite Zeile „Geschichte“ mit eigener Belohnung (Kapitel betreten,
  Boss besiegen, Figur retten).
- **Bewohner-Sprechblasen**: Sätze je nach Lage (Wetter, Tageszeit, Flut naht, Wunsch, Lob nach Sieg, Klage nach Schaden,
  Fortschritt der Geschichte) und beim Antippen. Die Geretteten haben eigene Sätze.
- **Auto-Expeditionen**: Ergebnisbericht mit Gebietsbild und Held, Ereignisliste, Gefahr und Verletzung, Übersicht aller
  Helden unterwegs.
- **Helden-Gespräche**: beim Start einer Expedition ein kurzer Wortwechsel – der gespielte Held vor Ort, ein zweiter Held per Funk
  aus der Basis.
