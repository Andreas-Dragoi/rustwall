# Paket Q – Qualität, Messung, Web, Barrierefreiheit, Store

Überblick über die Werkzeuge und Schalter aus Paket Q (V6). Details zu Zahlen: `docs/balance/wirtschaft.md`, `docs/balance/flut.md`.

## Wirtschaft und Flut (Kapitel 9.2, 12.2)

| Werkzeug | Zweck |
|---|---|
| `godot --headless -- --autotest=econ_dump` | schreibt alle Zahlen der Wirtschaft nach `docs/balance/wirtschaft_daten.json` (Kosten/Zeiten über die echten Funktionen, Kisten als Mittel aus 400 echten Öffnungen) |
| `python3 tools/wirtschaft_sim.py` | rechnet 100 Tage für 15/45/120 min Spielzeit → `docs/balance/wirtschaft.md` + Diagramme in `docs/balance/bilder/` |
| `python3 tools/wirtschaft_sim.py --parse-exp LOGS…` | Expeditions-Bot-Protokolle → `docs/balance/expedition_beute.json` (Beute je Gebiet) |
| `python3 tools/flut_reihe.py --godot G --weeks 1-16 --reps 3 [--passive]` | Flut-Bot gegen die „normal ausgebaute“ Basis jeder Woche (`--autotest=flood_q`) → `docs/balance/flut.md` |

Änderung an Spielzahlen: `D.bunker_cost` – Holz/Stein ab Bunker 8 × 0,7 je Stufe (`D.BUNKER_LATE_RES`), sonst war Bunker 10 nicht
bezahlbar (Kosten größer als jedes mögliche Lager). Begründung und Vorher/Nachher in `wirtschaft.md`.

## Web kleiner (Kapitel 3.2)

`python3 tools/web_build.py --godot G --out build/web` baut die Web-Fassung in einer Kopie (`build/web_src`) mit
verlustbehafteten Symbolen (WebP 0,9), Modellen ohne eigene Schatten-Meshes und Musik in geringerer Bitrate (OGG q0, MP3 80k).
Am PC und in den Handy-Apps ändert sich nichts (die Quell-Dateien und `.import` des Projekts bleiben unberührt).
Der Workflow `.github/workflows/web.yml` benutzt das Werkzeug. `python3 tools/web_messung.py build/web` misst Download, Ladezeit
und Speicher im Browser (Playwright, iPhone-13-Profil quer).

| Messung (iPhone 13 quer, Chromium/SwiftShader, Hauptmenü nach 45 s) | vorher | nachher |
|---|---|---|
| `index.pck` | 106,4 MB | 63,3 MB |
| Download gesamt (pck + wasm + js + Bilder) | 143,2 MB | 99,7 MB |
| WASM-Speicher (HEAP) | 166 MB | 166 MB |
| JS-Speicher (performance.memory, enthält das geladene pck) | 305 MB | 254 MB |
| Zeit bis das Spiel läuft (lokal, Rechner ausgelastet) | 18,0 s | 17,8 s |

`index.wasm` (36 MB, die Engine selbst) lässt sich nur mit einer eigenen, abgespeckten Godot-Vorlage verkleinern.

## Grafikstufe automatisch (Kapitel 3.2)

`src/auto_quality.gd`: beim ersten Start einige Sekunden Bildrate in der Basis messen (Bremse aus), dann Stufe wählen
(PC: ≥55 Hoch, ≥35 Mittel, sonst Niedrig; Handy/Web höchstens Mittel). Ergebnis je Gerät (`user://rustwall_device.cfg`),
eigene Wahl des Spielers geht vor. „Neu messen“ in den Einstellungen.

## Barrierefreiheit (Kapitel 7.3)

Einstellungen → Barrierefreiheit (je Gerät): Farbfilter (Deuteranopie, Protanopie, Tritanopie; Vollbild-Shader in `src/a11y.gd`),
Textgröße (= Oberflächengröße aus Paket F), Untertitel für wichtige Töne (`src/captions.gd`, mit Richtungspfeil bei Explosionen),
Blitze abschwächen (Trefferblitz, Explosionslicht ×0,3). Kamerawackeln/Vibration: vorhandene Schalter unter „Ton und Grafik“.

## PC und Gamepad (Kapitel 3.2)

`src/pc_input.gd`, `src/pad_nav.gd`, Tafeln in `src/screens/settings_q.gd`: Tasten umbelegen (Tausch bei Doppelbelegung,
Standard wiederherstellen), Fenster/Vollbild/Randlos, Auflösung, VSync, Bildratenbegrenzung. Gamepad: linker Stick laufen,
rechter Stick zielen, A/B/X/Y/LB/RB/Start/Select belegt, Menüs mit Fokusrahmen (Steuerkreuz/Stick, A drückt, B zurück),
in der Basis Select = Gebäude am Helden wählen (oder HUD-Knöpfe bedienen), Baumodus: Baufeld folgt der Bildmitte, A setzt, Y dreht.

## Store-Material (Kapitel 7.4)

`python3 tools/store_material.py --godot G` rendert 5 Motive × 5 Formate × 2 Sprachen nach `docs/store/screenshots/<sprache>/<format>/`
und das Vorschau-Video (26,5 s + Endtafel, 1920×1080, 30 Bilder/s) nach `docs/store/video/`. Braucht Linux mit xvfb-run und ffmpeg.

## Automatische Tests (Kapitel 12.2)

`.github/workflows/tests.yml`: bei jedem Push Selbsttest Deutsch und Englisch, Flut-Bot, Expeditions-Bot.
Eigene Prüfungen: `--autotest=qualitaet` (`src/tests_qualitaet.gd`, auch Teil von `--selftest`).
