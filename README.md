# Rustwall (Version 6)

Umsetzung des Spielkonzepts „Rustwall_Spielkonzept_V2.pdf“ in Godot 4.6 (GDScript, Mobile-Renderer).

- **Modelle:** alle in Blender gebaut (per Python-Skript, Ordner `blender/`), als `.glb` in `models/`,
  dazu gerenderte Symbole in `icons/`. Die Blender-Dateien liegen als `blender/rustwall_*.blend` bei.
- **Musik:** dein Lied `audio/music/castle_defense.mp3`, danach zwei eigens erzeugte Stücke im Wechsel,
  jeweils mit weicher Überblendung (`src/music.gd`).
- **Töne:** über 200 vorab erzeugte Klänge in `audio/sfx/` (`src/sfx.gd`), siehe `audio/README.md`.
- **Schrift:** „Fredoka“ (Open Font License, `fonts/OFL.txt`).

## Starten

1. Projektordner in Godot 4.6 öffnen. Beim ersten Öffnen importiert Godot rund 600 Dateien (Modelle, Symbole, Töne) –
   das dauert ein bis zwei Minuten; erst danach starten.
2. **F5** drücken. Hauptszene ist `scenes/main.tscn`.

Der Spielstand liegt unter `user://rustwall_v2.json` und wird automatisch gespeichert.

## Steuerung

| | PC | Smartphone |
|---|---|---|
| Bewegen | WASD / Pfeiltasten, oder rechte Maustaste halten | linker Daumen (Stick erscheint, wo du tippst) |
| Schießen | automatisch auf den nächsten Gegner; linke Maustaste halten = selbst zielen | automatisch |
| Fähigkeiten | Q, E · Spezial R · Kommandant F | Knöpfe rechts unten |
| Ausweichen | Leertaste | grüner Knopf |
| Fahrzeug auf-/absteigen | T | grauer Knopf |
| Nächste Welle sofort | N | Knopf „Sofort weiter“ |
| Zoom | Mausrad | zwei Finger |
| Pause / Zurück | Esc | Knopf „II“ |
| Vollbild | F11 | – |

**Bauen:** „Bauen“ → Karte wählen → Feld anklicken. `R` dreht, Rechtsklick beendet. Mauern lassen sich durch
Klicken und Ziehen „malen“. Im Baumodus bewegt WASD / der Stick die Kamera.
**Gebäude antippen:** verbessern, verschieben, einsammeln, öffnen. Der Bunker hat drei Speicherplätze für den Aufbau.

## Was drin ist

- **Hauptbasis** mit freiem Raster (24×24 bis 44×44 Felder, wächst mit dem Bunker), 32 Gebäudearten,
  Bauzeiten mit Baudrohnen, Produktion über Zeit (auch während das Spiel aus ist), Lager-Obergrenzen.
- **Sieben-Tage-Zyklus** nach der Uhr des Geräts: Tag 1–6 Vorbereitung und täglicher Übungsalarm,
  Tag 7 die Flut (bis zu 12 Wellen, ab Woche 3 mit Boss). Wird die Flut verpasst, verteidigt sich die Basis allein.
- **Expeditionen** in 7 Gebiete mit zufällig erzeugten Karten und 6 Aufgaben
  (Sammeln, Schleimnest, Kopfgeld, Außenposten, Wettlauf, Rettung), 3 Schwierigkeiten, Rucksack, Fundkisten,
  Auto-Expeditionen für Helden, die gerade nicht gespielt werden.
- **6 Helden** mit je 3 Waffen, 3 Fähigkeiten, 3 Talentbäumen, Besonderheit und Geschichte in 5 Kapiteln.
- **36 Gegnerarten** in 7 Familien und 7 Bosse, 10 Turmarten, 3 Fallen, 5 Fahrzeuge.
- **Beutekisten** (nur erspielbar, kein Echtgeld), Seltenheiten, Waffen verbessern / zerlegen / verschmelzen.
- **Spielerstufe**, Kommandanten-Fähigkeiten (3 Zweige) und 4 aktive Kommandanten-Aktionen.
- **Tagesaufträge**, Ranglisten, Freunde, Post, Clans – siehe Hinweis unten.

### Neu in Version 3 (Entwicklungsauftrag V3)

- **Waffen-Arsenal:** 15 Waffen je Held (90), neue Schussarten (Strahl, Aufladen, Bumerang, Minen, Geschütz, Zielsuche …),
  freigeschaltet über Heldenstufe + Herstellen (Baupläne, Werkstatt-Reiter „Herstellen“) oder Finden (Expedition, Kisten).
- **Begleiter:** 12 Begleiter (kaufen, herstellen, in Expeditionen befreien), tragen die Ladung sichtbar, erhöhen die Tragkraft,
  haben Besonderheiten und steigen bis Stufe 10 auf. Bildschirm „Begleiter“ im Menü der Basis. Ohne Begleiter trägt der Held eine Kraxe.

- **Hauptmenü und Intro** (`src/main_menu.gd`): Spielen, Städte, Intro, Optionen. Bis zu 5 **Städte** (eigene
  Spielstände) anlegen, wechseln und löschen. Jede Stadt hat einen **Bunkernamen**, unter dem man im Funkturm
  gefunden wird (umbenennen in den Optionen).
- **Expedition:** Abbau startet nach 0,3 s mit **Ladekreis** um die Quelle; Rucksack-Inhalt steht im Kampfbild,
  Antippen **wirft** den Rohstoff ab (Haufen, später wieder aufsammelbar); die Ladung ist als **Stapel auf dem Rücken**
  zu sehen (`src/backpack.gd`).

- **Wartezeiten für alles** (auch Mauern): anfangs Sekunden, später mehrere Stunden. Beschleunigen mit **Kristallen**
  (Premium-Währung). Kristalle gibt es täglich als Geschenk, für Erfolge, Stufen und Fluten – und im Shop.
  **Der Shop-Kauf ist nur ein Testkauf** (`src/store.gd`); für echtes Geld muss ein Bezahldienst
  (Google Play Billing / App Store) angebunden werden. Admins überspringen Wartezeiten im Admin-Menü.
- **Tore und Mauern**, durch die niemand läuft; Tore öffnen sich für Held und Bewohner.
- **Produktion als Blasen** über den Gebäuden, die man einsammelt (Antippen oder hinlaufen).
- **Jeder Held hat eigene Stufe** (bis 40); die Werkstatt ist nach Held → Waffe sortiert.
- **Neue Animationen** der Figuren (Skelett-Rig, Clips in `src/anim_human_data.gd`).
- **Kluge Bewohner** mit Berufen, Wegsuche, Baustellen, Alarm/Bunker, Reparatur nach der Flut (`src/npc*.gd`, `src/nav_grid.gd`).
- **Expeditionen** wie im Video: Münzen/Rohstoffe sammeln, vorbereitete Bauplätze, Außenbasen mit Boni
  (`src/expedition.gd`, `outpost.gd`, `pad.gd`).
- **Lebendige Basis:** Wiese, Wege, Blumen, Bäume, Küste, Bach, Tiere, Wind, Tageszeit, Regen
  (`src/base_nature.gd`, `wildlife.gd`, `weather.gd`).
- **Detailreichere Gebäude, Türme, Mauern** und **36 Gegnerarten in 7 Familien + 7 Bosse** mit eigenen Modellen
  und Animationen (Schleim, Untote, Waldgeister, Wüstenmonster, Mutanten, Eiswesen, Dämonen).

### Neu in Version 5 (Umsetzung der PDF „Was dem Spiel noch fehlt“)
- **Online-Grundlage:** Konto, Cloud-Spielstand, Serverzeit, Freunde/Clans/Post über einen Server (`src/net*.gd`,
  Nakama-Modul und Test-Server in `server/`), Rechtstexte und Einwilligung, Store-Texte (`docs/`), iOS/Android-Exporte.
- **Spielerführung:** Tutorial mit Zeigefinger, Tutorial-Flut, Ziele-Leiste, Rückkehr-Zusammenfassung, Hilfe/Wiki,
  Bau-Warteschlange, Mauern ziehen, Turmziele, Wellen-Vorschau, Akku-Sparmodus. Juwelen gelten kontoweit.
- **Gegner:** 21 neue Rollen-Arten (Heiler, Schildträger, Tunnelgräber, Turmstörer, Dieb, Brutmutter), 7 Minibosse,
  Elite mit Krone, Bosse mit Phasen/Intro/Schwachstelle, Weltboss Schleim-Leviathan, 5 neue Fallen, 12 Deko-Teile.
- **Welt:** Musik je Gebiet mit Gefahr-Lage, Umgebungston, Wahrzeichen, Tag/Nacht und Wetter in Expeditionen,
  Gebiets-Ereignisse, Werkzeug-Quellen, Tagebuch, Karawane, Nebenquests, Übungsplatz, Begleiter-Köder und -Eier,
  Tagesablauf der Bewohner.
- **Gebiet 8 „Vulkaninsel“** mit Lavaströmen, Hitze-Leiste, Ausbruch und der Familie Magma-Wesen.
- **Live-Betrieb:** Wochen-Ereignisse, Feiertage, Saison 1 mit Pass (bezahlte Spur nur als Testkauf), Garderobe und
  Kosmetik-Shop, Wochenaufgaben, 28-Tage-Kalender, Nachrichten, Prestige, Außenbasis Stufe 4–5, Albtraum+.
- **Englisch** als zweite Sprache (`locale/en.po`, Wahl in den Optionen).

### Neu in Version 6 – Paket H (Helden, Waffen, Ausrüstung, Figuren)
- **Neue Heldin Nele, die Taucherin** (Wasser/Eis, Harpunen): 15 Waffen, 3 Fähigkeiten (Strudel, Luftblase, Springflut),
  Geschichte in 5 Kapiteln, Comic-Rufe; wird als zweite Rettung an der Schrottküste befreit (erst Yuki, dann Nele).
- **Ausrüstungs-Sets:** 7 Sets zu je Helm, Weste, Glücksbringer mit Boni ab 2 und 3 Teilen; Helm, Weste und Glücksbringer
  sind **am Modell sichtbar** (Helm ersetzt die eigene Kopfbedeckung). Alte Ausrüstung bekommt beim Laden ein Set.
- **Waffenmodule:** Sockel je Waffe (1–3 nach Seltenheit), 10 Module (Schalldämpfer, Zielfernrohr, Schnelllader,
  Trommelmagazin, Stabilisator, Wuchtgewicht, Element-Kerne Feuer/Eis/Gift/Blitz) – herstellen in der Werkstatt (Reiter
  „Module“), Fund in Beutekisten, sichtbar am Waffenmodell.
- **Waffen-Feinschliff:** Gift skaliert mit Stufe und Seltenheit, Schüsse kommen aus der Mündung des Modells, Überkopf-Schlag
  für Hämmer, Wurfwaffen größer in der Hand, Wurfbahn als Punktlinie beim Zielen, Leuchtspur hinter Bumerang & Co.,
  neue Symbole für Ziegelschleuder, Falkenruf, Magnetwerfer.
- **Figuren:** Gesichter (Blinzeln, Jubel, Schmerz, Anstrengung), Siegerpose je Held (nach Flut-/Expeditionssieg und in der
  Vorschau), Laufstil je Persönlichkeit, nachschwingende Haare, Tücher, Kittel. Hund, Katze und Vögel mit Blender-Clips.
- **Waffen-Balance:** Messlauf `--autotest=dps` (Schaden/s jeder Waffe gegen jede Familie, Einzelziel und Gruppe) →
  `docs/balance/`. Prüfungen: `--autotest=helden`.

### Neu in Version 6 – Paket E (Geschichte, Zwischenszenen, Rettungen, Sprechblasen)
- **Hauptgeschichte** über alle Gebiete (`docs/geschichte.md`): Woher kommt der Schleim (das Sternherz unter dem Krater,
  geweckt von Adas Regen), was ist im Krater (Ring aus Stein, Schleimkönig), was ist mit der Vulkaninsel (Magmafürst Brodel).
  Je Gebiet eine **Zwischenszene** beim ersten Betreten und eine nach dem ersten Bosssieg, **Abschlussszenen** nach
  Schleimkönig (Akt 1) und Magmafürst (Akt 2): Texttafeln mit Kamerafahrt über eine eigene 3D-Bühne des Gebiets mit Helden,
  Geretteten, Boss und Schleimlingen (`src/story_scene.gd`, `src/story_stage.gd`). Überspringbar, wieder ansehbar im
  neuen Bildschirm **Chronik** (Menü „Chronik“). **Story-Ziele** als zweite Zeile der Ziele-Leiste.
- **Rettungen:** Rosa, die Händlerin (Gegnerlager in der Staubebene → **Tauschladen**), Professor Moosbach (Schleim-Kokon im
  Sumpfwerk → Forschung 25 % schneller), Knut, der Schmied (Käfig aus Eis am Frostpass → Waffen verbessern 20 % günstiger).
  Sie ziehen mit eigenem Aussehen in die Basis und haben einen Tagesablauf wie die Bewohner.
- **Sprechblasen:** Bewohner und Gerettete sagen je nach Lage etwas (Wetter, Tageszeit, Flut naht, Wunsch, Lob nach Sieg,
  Klage nach Schaden, Stand der Geschichte), sparsam; beim Antippen ein Satz. Über 200 Sätze, Deutsch und Englisch.
- **Auto-Expeditionen:** Bericht mit Gebietsbild und Held, Ereignisliste (Kisten, Rohstoffe, Erfahrung, selten ein Ei),
  Gefahr und Verletzung (Held kurz nicht einsetzbar, heilbar mit Juwelen), Übersicht aller Helden (Bildschirm
  „Auto-Expeditionen“) – mehrere gleichzeitig unterwegs.
- **Helden-Gespräche** beim Expeditionsstart: der gespielte Held vor Ort, ein zweiter per Funk aus der Basis.
- Prüfungen: `--autotest=geschichte`. Bilder einer Szene: `--story_scene=<szene> --story_panel=<n>`.
### Neu in Version 6 – Paket M (Spielmodi)
- **Bildschirm „Spielmodi“** im Menü (Knopf „Modi“) und im Bunker-Fenster: Reiter Turm, Überleben, Clan-Raid, Höhlen.
- **Turm der Prüfungen:** 50 handgemachte Stockwerke in 5 Hallen (Moosgewölbe, Sandsteinhalle, Frostkammer, Rostschmiede,
  Glutspitze) mit Aufgaben „Überlebe“, „Räume die Halle“, „Zeitdruck“, „Generator verteidigen“, „Ohne Fähigkeiten“,
  „Nur Nahkampf“, „Ohne Heilung“ und einem Gebietsboss auf jedem 10. Stockwerk. Bis zu 3 Sterne (geschafft, Leben, Zeit),
  erstmalige Belohnungen, Sterne-Truhen, Wochenwertung mit Rangliste (Server oder simuliert).
- **Überlebensmodus:** endlose Wellen auf dem Schrottplatz mit Deckung, alle 5 Wellen Wahl aus 3 Verstärkungen
  (11 Arten), Punkte, Bestwert, Wochenrangliste, Belohnungen für erstmals erreichte Wellen.
- **Clan-Raid:** Leviathan der Woche mit Leben je Clanmitglied, 3 Angriffe pro Tag, Schaden des Clans wird summiert
  (Server: `rw_raid_hit`, `rw_raid_get`; ohne Server simulierte Mitglieder), Belohnungsstufen 25/50/75/100 %.
- **Höhlen** ab Gebiet 2: 1–2 Eingänge je Expedition, eigene dunkle Höhlenwelt aus Räumen und Gängen mit Fackeln,
  Wächtern der Gebietsfamilie, Truhe und Erzader; Beute, Münzen und Besiegte zählen zur Expedition.
- **Ladefläche der Pritsche:** zweiter Rucksack, der sichtbar beladen wird; am Depot (oder an der Außenbasis) abladen.
- Prüfungen: `--autotest=modi`; Bots: `--autotest=turm --floor=1-10 --level=12`, `--autotest=ueberleben --waves=10`,
  `--autotest=hoehle --area=1` (je mit `--fast=8`).

### Neu in Version 6 – Paket Z2 (Gebiet 9 „Stadtruinen“)
- **Gebiet 9 „Stadtruinen“** (ab Stufe 60, Weltkarte oben links): Straßenraster mit Kreuzungen, Autowracks, Bushaltestellen,
  Litfaßsäulen, Laternen, Unkraut, Hochhausruinen; Quellen Elektroschrott (Metall), Kupferkabel (Bauteile), Akkus (Zellen),
  Umspannkasten mit Bolzenschneider; Wahrzeichen „Gestürzter Fernsehturm“; Sperre Schuttberg; Außenbasis-Sonderbau
  **Umspannwerk** (Stufen 1–5: Zellen-Produktion, tägliche Bauteile); Tagebuch, Nebenquest „Sicherungen für die Notrufsäule“.
- **Dächer als Wege:** Dachhäuser mit Feuertreppe. Oben erreichen den Helden nur Flieger, Schützen und kletternde Funkenspinnen;
  Reichweite +30 %, Schaden +15 %. Über die Kante springt man hinunter (`src/exp_stadt.gd`, `field.deck`, `hero.perch`).
- **U-Bahn und Notstrom:** zwei Linien (Landezone/Mittelring ↔ Außenring), nur mit eingeschaltetem Generator und nach dem
  Großangriff; Gegner fahren nicht mit. **Ampeln** an den Kreuzungen halten Maschinen bei Rot an.
- **Blitzgewitter** (Gebiets-Ereignis): Stromausfall, Blitze in roten Kreisen, getroffene Maschinen gehen kurz aus.
- **Gegnerfamilie „Maschinen“**: Rasenmäher-Bot, Funkenspinne, Bagger-Golem, Ampelwächter, Drohnenschwarm, Müllpresse,
  Rollen Reparatur-Bot, Schild-Bot, Störsender, Miniboss Abrisskran, Boss **Bürgermeister Bolzen** (Stromstoß-Linien,
  Phasen, Schwachstelle Akku). Schwäche Blitz/Wasser, Gift wirkungslos (`src/maschinen_ai.gd`).
- **Akt 3** der Geschichte (Szenen „Lichter in der Stadt“, „Feierabend“), Musik `area_stadt` mit Gefahr-Lage, Umgebungston.
- Prüfungen: `--autotest=zone2`; Bot: `--autotest=exp --setup=10 --area=8 --mission=nest --fast=8`;
  Bilder: `--stadt=roof|stair|subway|gen|ampel|power|storm`.

### Neu in Version 6 – Paket B (Basis und Flut)
- Forschungsbaum im Labor (3 Äste × 11 Knoten, erste Knoten schon über die Werkstatt), Bildschirm „Forschung“.
- Klügere Belagerung: Brecher suchen die schwächste Mauer, Flieger umgehen Luftabwehr, Leiterträger klettern über Mauern.
- Wetter verändert die Flut (Regen, Nebel, Nacht), Flut-Rückblick mit Karte (auch für verpasste Fluten).
- Layout-Code zum Teilen, „Layout gegen Flut testen“, sichtbare Mauerschäden mit „Alle reparieren“, seltene Funde, verletzte Bewohner,
  Tümpel mit Spritzern, lokale Mitteilungen (vorbereitet) und Bewertungs-Hinweis.

### Neu in Version 6 – Paket Q (Qualität)
- Wirtschaftssimulation (`tools/wirtschaft_sim.py`, `docs/balance/wirtschaft.md`) und Flut-Messreihe (`docs/balance/flut.md`); Bunker 10 ist jetzt bezahlbar.
- Web-Fassung über `tools/web_build.py` deutlich kleiner (verlustbehaftete Symbole, leichtere Musik nur fürs Web).
- Automatische Qualitätsstufe, Farbfilter für Farbenblinde, Untertitel für wichtige Töne, Blitze abschwächen.
- PC: Tasten umbelegen, Fenster-/Vollbild-Optionen; Gamepad inkl. Menüs. Store-Bilder und Vorschau-Video in `docs/store/`.
- `.github/workflows/tests.yml`: Selbsttest und Bots bei jedem Hochladen.

## Wichtig: Was (noch) nicht echt ist

- **Mitspieler sind simuliert.** Freunde, Clans, Ranglisten und Post laufen über `src/social.gd` mit erfundenen
  Mitspielern, damit alle Abläufe spielbar sind. Für echtes Online-Spiel braucht es einen Server
  (im Konzept empfohlen: Nakama). Die Schnittstelle ist bewusst in dieser einen Datei gebündelt.
- **Die Zeit kommt von der Geräte-Uhr.** Wer die Uhr verstellt, kann schummeln; ein Server würde das verhindern.
- **Modelle sind per Skript in Blender gebaut**, nicht von Hand modelliert. Figuren sind Voxel-Figuren mit einzelnen
  Gliedern; ihre Bewegung berechnet Godot im Code (`src/humanoid.gd`), es gibt keine Blender-Animationen.
  Zum Ändern: Skript in `blender/` anpassen und ausführen (siehe `blender/README.md`) oder die `.glb` ersetzen.
- **Die beiden Folge-Musikstücke und alle Töne sind am Rechner erzeugt** (Skripte in `tools/`) und nicht von
  Menschen abgehört worden – austauschbar durch Dateien mit gleichem Namen.
- **Server:** Ohne laufenden Nakama-Server (siehe `server/README.md`) bleiben Mitspieler simuliert; echte Käufe
  (App Store / Google Play) sind vorbereitet, aber nur als Testkauf aktiv.
- Nicht umgesetzt: gemeinsame Kämpfe (Koop, Clan-Flut), weitere Sprachen außer Englisch.

## Testmodus (Optionen → Testmodus)

Zeit vorspulen (+1 Stunde, +1 Tag), Schnellbau, Bauten fertigstellen, Testbasis, Rohstoffe auffüllen,
Spielstand löschen. Damit lässt sich der Sieben-Tage-Zyklus in Minuten durchspielen.

## Admin-Menü (Taste `-` oder `,`)

Öffnet links ein Menü zum Testen: Gottmodus, Basis unverwundbar, ein Treffer genügt, unendlich Munition,
Fähigkeiten ohne Abklingzeit, kostenlos bauen/kaufen, Sofortbau, keine Grenzen, Spieltempo ×0,5 bis ×8,
Uhr vorstellen, Flut/Übung sofort starten, Kampf gewinnen, Gegner jeder Art spawnen, Ressourcen, Stufen,
Gegenstände und Kisten geben, alles freischalten. Schalter gelten bis zum Beenden des Spiels; gegebene
Dinge bleiben im Spielstand. Vor einer Veröffentlichung in `src/main.gd` die Zeile mit `Admin.new()` entfernen.

## Leistung

- Gegner sind keine Nodes, sondern Datenobjekte; gezeichnet wird je Art mit einem MultiMesh, die Bewegung
  (Hüpfen, Wabbeln, Platzen) rechnet der Shader `shaders/slime.gdshader`.
- Wegfindung über ein Richtungsfeld (`src/field.gd`), das nur neu berechnet wird, wenn sich die Basis ändert.
- Mauern und Münzen sind ebenfalls MultiMeshes; jedes Gebäude ist zu wenigen Meshes verschmolzen.
- Grafikstufe in den Optionen: Niedrig (70 % Auflösung, keine Schatten, höchstens 200 Gegner),
  Mittel (85 %, Schatten, 300), Hoch (100 %, MSAA, 420). Bildrate 60 oder 30.
- Gemessen im Test (ohne Grafik): Gegner-Logik rund 2–3 ms pro Schritt bei 250–280 Schleimlingen.

## Aufbau des Codes (`src/`)

| Datei | Inhalt |
|---|---|
| `data.gd` | alle Zahlen und Texte (Gebäude, Türme, Gegner, Helden, Waffen, Gebiete, Kisten …) |
| `profile.gd` | Spielstand und Spielregeln (Autoload `P`) |
| `social.gd` | simulierte Mitspieler |
| `g.gd` | Eingabe und globale Verweise (Autoload `G`) · `sfx.gd` erzeugte Töne (Autoload `Sfx`) |
| `main.gd` | wechselt zwischen Basis und Expedition |
| `world.gd` | gemeinsame Grundlage: Umgebung, Geschosse, Bodenflächen |
| `base_world.gd` | Hauptbasis, Baumodus, Flut |
| `expedition.gd` | Kartenerzeugung und Aufgaben |
| `horde.gd`, `hero.gd`, `skills.gd`, `tower.gd`, `structure.gd`, `coins.gd`, `fx.gd`, `field.gd` | Kampf |
| `hud.gd`, `touch_pad.gd`, `ui.gd` | Anzeige im Spiel und Oberflächen-Baukasten |
| `screens.gd`, `screens/*.gd` | Menüs (Helden, Kisten, Werkstatt, Garage, Funk, Clan, Profil, Aufträge, Expedition, Optionen) |
| `music.gd`, `sfx.gd` | Musik mit Überblendung, Töne |
| `anim.gd` | Daueranimationen der Blender-Modelle (Namen `spin_`, `bob_`, `sway_`, `pulse_`, `fx_`) |
| `admin.gd` | Admin-Menü |
| `tests.gd`, `ui_test.gd` | automatische Tests |

## Sprachen (Deutsch / English)

- **Wahl:** Optionen → Ton und Grafik → Sprache. Beim ersten Start gilt die Systemsprache (Deutsch für deutsche Geräte,
  sonst Englisch); die Wahl wird auf dem Gerät gemerkt (`user://rustwall_lang.txt`) und gilt für alle Städte.
  Umschalten wirkt sofort, offene Menüs werden neu gebaut. Zum Testen: `--lang=en`.
- **Quelle ist der deutsche Text** im Code (msgid = deutscher Text); Englisch steht in `locale/en.po`
  (in `project.godot` angemeldet, Rückfallsprache Deutsch). Labels und Knöpfe übersetzen sich selbst.
  `src/i18n.gd` übersetzt zusätzlich zusammengesetzte Texte über Vorlagen aus `en.po` („Stufe %d“ erkennt „Stufe 7“),
  Texte aus mehreren Teilen (Zeilen, „ · “, Sätze, BBCode, „Zitate“), Zahlen (5,5 → 5.5) und „1 gems“ → „1 gem“.
- **Neue Texte übersetzen:** `python3 tools/i18n_extract.py --missing` findet alle Texte, schreibt
  `locale/rustwall.pot` + `locale/en.po` (vorhandene Übersetzungen bleiben) und listet, was fehlt. Übersetzungen direkt
  in `locale/en.po` eintragen (oder `--set datei.json` mit `{"deutsch": "english"}`). Hilfsvorlagen für Teilstücke stehen in
  `tools/i18n_extra.json`. Gezeichnete Texte (`draw_string`) brauchen `I18N.t(text)`.
- **Rechtstexte** haben eine eigene englische Fassung in `docs/legal/en/` (→ `python3 tools/legal_to_gd.py`),
  Store-Texte englisch in `docs/store/description_en.md`. Das Admin-Menü bleibt deutsch.
- **Prüfen:** `--autotest=sprache` (Abdeckung, Platzhalter, Umschalten, alle Bildschirme in Englisch);
  `--lang=en --i18n_log=<datei>` schreibt beim Beenden alle Texte, die deutsch geblieben sind.

## Automatische Tests

```
godot --headless --path . -- --selftest
godot --headless --path . -- --autotest=flood --bunker=5 --week=6 --fast=8
godot --headless --path . -- --autotest=exp --setup=10 --fast=8 --limit=2400
godot --headless --path . -- --autotest=npc --fast=8 --limit=900
godot --headless --path . -- --autotest=gegner
godot --headless --path . res://scenes/ui_test.tscn -- --selftest --monkey
```

`--selftest` prüft Spielregeln, Speichern/Laden, echte Mausklicks im Baumodus, alle Menüs, Übung, Flut
(Sieg und Niederlage) und alle sechs Aufgaben, jede mit einem anderen Helden und Fahrzeug. Tests schreiben keinen Spielstand.

Bei jedem Hochladen laufen Selbsttest (Deutsch und Englisch), Flut-Bot und Expeditions-Bot automatisch
(`.github/workflows/tests.yml`). Messwerkzeuge für Wirtschaft, Flut-Schwierigkeit, Web-Größe und Store-Material: siehe
`docs/qualitaet.md` (Paket Q). Barrierefreiheit, Tastenbelegung, Fenster und Gamepad stehen in den Einstellungen.

Weitere Ordner: `blender/` (Modell-Skripte und .blend-Dateien), `tools/` (Musik- und Ton-Erzeugung), `models/`, `icons/`, `audio/`.

Der Ordner `scripts/` und `shaders/horde.gdshader` stammen aus Version 1, werden nicht mehr verwendet
und können gelöscht werden.
