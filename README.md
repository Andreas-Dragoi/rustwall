# Rustwall (Version 2)

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
- Nicht umgesetzt aus dem Konzept: gemeinsame Kämpfe (Koop, Clan-Flut),
  Sprachausgabe, Übersetzungen (alles ist deutsch).

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

Weitere Ordner: `blender/` (Modell-Skripte und .blend-Dateien), `tools/` (Musik- und Ton-Erzeugung), `models/`, `icons/`, `audio/`.

Der Ordner `scripts/` und `shaders/horde.gdshader` stammen aus Version 1, werden nicht mehr verwendet
und können gelöscht werden.
