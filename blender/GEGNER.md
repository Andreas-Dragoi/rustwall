# Rustwall – einen neuen Gegner bauen (Paket 11)

Diese Anleitung genügt, um eine Gegnerart von der leeren Datei bis ins laufende Spiel zu bringen.
Muster für alles: `blender/enemies_untote.py` (sechs Arten + Boss) und `blender/enemies_schleim.py` (ein Bauplan für neun Arten).

**Was schon fertig ist und du NICHT anfassen musst:** Werte und Verhalten aller 36 Arten (`src/data.gd`, `src/enemy_ai.gd`),
die Horde (`src/horde.gd`), der Shader (`shaders/vat.gdshader`), das Monsterbuch, die Tests. Solange zu einer Art kein Modell
existiert, läuft sie im Spiel als eingefärbter Schleimling ihrer Rolle. **Sobald die drei Dateien `models/e_<key>.glb`,
`models/e_<key>_vat.png` und `models/e_<key>.json` da sind, benutzt das Spiel sie von selbst – ohne Code-Änderung.**
Für einen Boss sind es zwei Dateien: `models/e_<key>.glb` (mit Animationen) und `models/e_<key>.json`.

## 1. Dateien und Namen

| Was | Wo |
|---|---|
| Skript, eine Datei je Familie | `blender/enemies_<familie>.py` – `schleim`, `wald`, `wueste`, `untote`, `mutanten`, `eis`, `daemonen` (Dämonen-Arten in `enemies_daemonen_arten.py`, das Portal in `enemies_daemonen.py`) – alle 36 Arten + 6 Bosse sind gebaut |
| Schlüssel der Art | genau wie in `src/data.gd` → `ENEMIES[..].key`, z. B. `wald_pilzling`, `eis_yeti`, Boss `boss_wald` |
| Ergebnis | `models/e_<key>.glb`, `models/e_<key>_vat.png`, `models/e_<key>.json`, `icons/e_<key>.png`, `blender/blend/e_<key>.blend` |
| Bildtafel für die Abnahme | `<Ordner neben dem Projekt>/shots_<Projektordner>/tafel_<key>.png` und `umriss_<key>.png` (anderer Ort: Umgebungsvariable `RW_TAFEL_DIR`) |

Aufruf: `python3 blender/enemies_<familie>.py [key ...] [--notafel]` – ohne Namen werden alle Arten der Datei gebaut;
`--notafel` lässt die (langsame) Bildtafel weg. Eine Art dauert etwa 10–40 Sekunden.

Aussehen, Verhalten, Leben und Tempo jeder Art stehen im Auftrag, Kapitel 11.2, und als `look`/`text` in `src/data.gd`.

## 2. Aufbau eines Skripts

```python
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from animkit import *            # bringt kit.py (Part, col, shade, mix, rot …) und rw_util.py (T, S, MPart, face_to, star …) mit

def wald_pilzling():
    rig = Rig("wald_pilzling", role="mass")          # role: mass | fast | tank | ranged | air | special | boss
    # --- Teile ---
    p = Part(); lathe(p, [...]); p.ball(...)
    rig.add("body", p, pivot=(0, 0, 0.2))
    p = Part(); ...
    rig.add("cap", p, parent="body", pivot=(0, 0, 0.55))
    # --- Clips ---
    with rig.clip("idle", 36, loop=True) as c: ...
    with rig.clip("walk", 18, loop=True, stride=0.8) as c: ...
    with rig.clip("attack", 15, hit=8) as c: ...
    with rig.clip("hit", 9) as c: ...
    with rig.clip("death", 27) as c: ...
    with rig.clip("...besonderer Clip...", 20) as c: ...
    rig.finish()                                      # .blend, Animations-Textur, .glb, .json, Symbol, Bildtafel

TABLE = {"wald_pilzling": wald_pilzling}
if __name__ == "__main__":
    run(TABLE, [a for a in sys.argv if not a.startswith("--")])
```

### Achsen und Größe
- Z ist oben, die **Vorderseite zeigt nach −Y**, der Ursprung liegt am Boden unter der Mitte. Einheit Meter.
- Baue in **echter Spielgröße**. Der Held ist 2,6 m groß (die graue Figur auf der Bildtafel). Richtwerte: Masse 0,9–2,0 m,
  Flitzer klein und lang, Brocken 2,8–3,4 m, Boss 4–5,5 m. Wirkt die Figur auf der Tafel zu klein oder zu groß: `Rig(..., size=1.3)`.
- Läuft die Art seitwärts (Krabbe): `Rig(..., yaw=90)` – gebaut wird sie trotzdem mit dem Gesicht nach −Y.
- Flieger: so bauen, dass die Figur knapp über dem Boden schwebt; die Flughöhe (2,4 m) gibt das Spiel dazu.

### Teile
- Ein Gegner besteht aus **starren Teilen** (Rumpf, Kopf, Arme, Beine, Schwanz, Waffe, Hut …). Jedes Teil ist ein `Part` aus dem Baukasten
  und wird mit `rig.add(name, part, parent=..., pivot=(x, y, z))` zu einem eigenen Blender-Objekt.
- Die **Geometrie** gibst du in Modell-Koordinaten an (so, wie die Figur in Ruhe dasteht) – auch bei Kind-Teilen.
  `pivot` ist der **Drehpunkt** des Teils, ebenfalls in Modell-Koordinaten (Schulter, Hüfte, Halsansatz).
- `rig.node(name, parent, pivot)` ist ein Gelenk ohne Geometrie (z. B. eine Hüfte, an der Rumpf und Beine hängen).
- `"root"` ist immer da und bewegt die ganze Figur (Sprung, Umfallen).
- Besondere Teile:
  - `glow=True` – leuchtet (Augen, Glut, Laternen),
  - `look=True` – Pupillen: im Spiel wandern sie zum Helden (das Teil nur aus den Pupillen bauen, vorn auf den Augen),
  - `ghost=True` – durchscheinend (Geister, Quallen),
  - `hide=True` – Zubehör, das das Spiel ausblenden kann (Helm des Helm-Schleims).
- Helfer in `animkit.py`, die wenig Eckpunkte kosten:
  - `lathe(p, [(radius, z, farbe), ...], sides=10, sx=, sy=)` – Drehkörper mit Farbringen (Bäuche, Hüte, Fässer, Stiefel, Rohre),
  - `capsule(p, a, b, r1, r2, farbe, sides=6)` – Glied von Punkt a nach Punkt b (Arme, Beine, Knochen),
  - `paint(p, farbe, zmin=, zmax=, …)` – färbt Flächen in einem Bereich um.
  - Dazu alles aus `kit.py` (`box`, `cyl`, `cone`, `ball`, `torus`) und `rw_util.py` (`MPart(matrix)` für schräg gebaute Teile, `star`, `face_to`, `T`, `rot`).
- Stil: rund, bunt, Spielzeug – lustig-gruselig, nicht eklig. Charakter kommt aus Umriss, Gesicht, Zubehör und Bewegung.
  **Jede Art muss an ihrem Umriss aus der Spielkamera (55° von oben) von den anderen ihres Gebiets zu unterscheiden sein** –
  prüfe das auf der Bildtafel (Feld „Umriss“).

### Grenzen (das Skript bricht ab, wenn sie überschritten werden)
| Rolle | Eckpunkte höchstens |
|---|---|
| mass, fast | 900 |
| ranged, air, special | 1 600 |
| tank | 2 800 |
| boss | 8 000 Dreiecke (echte Figur, keine Animations-Textur) |

Gezählt wird, was die Grafikkarte sieht: Ecken mit harter Kante oder Farbwechsel zählen doppelt. Sparen: `subdiv=1` bei kleinen Kugeln,
`sides=5…6` bei dünnen Gliedern, `bevel=0` bei kleinen Quadern, lieber `lathe` als mehrere Zylinder.
Die Textur darf höchstens 1024 × 512 werden (10 Bilder je Sekunde; alle Clips einer Art zusammen etwa 6–16 Sekunden).

## 3. Clips (echte Blender-Keyframes)

Gezählt wird in Bildern, **30 Bilder = 1 Sekunde** (Längen werden auf Vielfache von 3 gerundet; gespeichert werden 10 Bilder/s,
der Shader rechnet weich dazwischen und blendet beim Wechsel 0,1 s über).

```python
with rig.clip("attack", 24, hit=13) as c:
    c.key(0, body=dict(rot=(10, 0, 0)), arm_r=dict(rot=(-8, 0, -4)))
    c.key(8, body=dict(rot=(-12, 0, -8)), arm_r=dict(rot=(-165, 0, -16)), root=dict(loc=(0, 0.06, 0)))
    c.key(13, ...)
```

- `c.key(bild, teil=dict(loc=…, rot=…, scale=…), …)`:
  `loc` = **Versatz** gegenüber der Ruhelage in Metern, `rot` = Euler-Winkel XYZ in **Grad** (0 = Ruhelage), `scale` = Zahl oder `(x, y, z)`.
  Kanäle, die du nicht nennst, werden weich zwischen ihren Nachbar-Keys gerechnet.
- Drehrichtung um X: Bei einem Teil, das **nach unten hängt** (Bein, Arm), schwingt `rot=(−30, 0, 0)` nach **vorn**;
  bei einem Teil, das **nach oben ragt** (Rumpf, Kopf), neigt `rot=(+20, 0, 0)` nach **vorn**.
- `loop=True`: Die Pose von Bild 0 wird am Ende automatisch wiederholt – die Schleife ist nahtlos. Kein Key am letzten Bild nötig.
- `c.wave(teil, rot=(…), loc=(…), scale=(…), n=1, phase=0.0, base_rot=…)` – gleichmäßiges Schwingen über den ganzen Clip
  (Laufzyklus: linkes Bein `phase=0`, rechtes `phase=0.5`; Schwanz, Tentakel, Flügel).
- `_i="LINEAR"` oder `_i="CONSTANT"` als Zusatz in `c.key(...)` für harte Bewegungen (Aufprall, Verschwinden).
- Praktisch: ein Wörterbuch `rest = dict(root=dict(loc=(0,0,0), rot=(0,0,0)), body=dict(...), ...)` mit der Grundhaltung aller Teile,
  das du am Anfang und Ende der einmaligen Clips setzt (`c.key(0, **rest)`).

### Pflicht-Clips (Namen genau so)
| Clip | Art | Hinweise |
|---|---|---|
| `idle` | Schleife | atmen, umsehen, Zubehör wippt |
| `walk` | Schleife | **`stride=` setzen: der Weg in Metern, den die Figur in EINEM Durchlauf zurücklegt.** Faustregel: `stride = Tempo × Dauer des Clips`. Das Spiel spielt den Clip mit Geschwindigkeit ÷ Schrittlänge ab – dann rutschen die Füße nicht. |
| `attack` | einmal | `hit=` = Bild, in dem der Schlag trifft / das Geschoss losfliegt. Das Spiel startet den Clip so, dass der Schaden genau dann fällt. |
| `hit` | einmal | kurz (9 Bilder): Zucken, Hüpfer |
| `death` | einmal | endet in einer **liegenden oder aufgelösten Pose**; danach versinkt die Figur von selbst. Flieger fallen von selbst zu Boden. |

### Besondere Clips (1–2 je Art; die Namen ruft das Spiel)
Das Spiel spielt diese Clips ab, **wenn es sie gibt** – fehlt einer, passiert nur das Verhalten ohne eigene Bewegung.
Welche Namen eine Art braucht, steht in `src/data.gd` im Feld `anims` der Art und in dieser Liste:

| Clip | wann | Arten |
|---|---|---|
| `revive` | steht wieder auf (einmal; beginnt in der letzten Pose von `death`) | untote_matrose |
| `busy` | Schleife, während ein Gebäude bearbeitet wird | untote_deckratte |
| `throw` | Wurf (Anker, Felsbrocken); der Zug beginnt nach der Hälfte | untote_taucher |
| `zap`, `freeze` | Sonderangriff auf Türme | untote_qualle, eis_eisgeist |
| `hide` | einmal, letzte Pose wird gehalten (in der Kiste) | untote_krabbe |
| `spawn` | taucht auf / steigt aus dem Boden (wenn ein Boss ihn ruft) | alle, freiwillig |
| `pounce` | Sprung auf den Helden (0,45 s) | wald_dornenwolf, eis_eiswolf |
| `root` | Schleife: festgewurzelt und heilend | wald_baumhueter |
| `blink` | nach dem Teleport | wald_irrlicht |
| `dig`, `under`, `rise` | eingraben (einmal), unter der Erde (Schleife: nur Buckel/Sandspur sichtbar), auftauchen (einmal) | wald_wurzelkriecher, wueste_sandwurm |
| `windup`, `charge`, `dazed` | Anlauf (einmal), Sturm (Schleife), benommen (Schleife) | wueste_rostbulle; `charge` auch daemonen_hund |
| `roll` | Schleife beim Rollen (das Spiel vergrößert die Figur dabei) | eis_lawinenroller |
| `howl` | Geheul (einmal) | eis_eiswolf |
| `dive` | Sturzflug (0,7 s hinab) | daemonen_schattenschwinge |
| `summon` | Portal öffnen / Diener rufen | daemonen_beschwoerer, Bosse |
| `special`, `slam`, `broadside` | Sonderangriffe der Bosse (siehe `specials` in data.gd) | Bosse |

Der Fernangriff (Schleuder, Bogen, Spucken, „kniet zum Schuss“, „bläht sich auf“) gehört in den Clip `attack`.

## 4. Bosse

`Rig("boss_<familie>", role="boss")` – derselbe Aufbau, dieselben Clips. `rig.finish()` exportiert die Teile **mit** Objekt-Animationen
(Godot: `AnimationPlayer`, alle Clips hintereinander auf einer Zeitleiste; Anfang und Dauer stehen in der `.json`). Höchstens 8 000 Dreiecke.
Teile mit `glow=True` leuchten auch hier. Das Spiel (`src/boss_fig.gd`) spielt `idle`, `walk` (mit `stride`), `attack`, `hit`, `death`
und die Sonder-Clips aus der Tabelle oben.

## 5. Bildtafel ansehen und nachbessern

`rig.finish()` rendert `tafel_<key>.png`: oben das Modell von vorn, von der Seite und von oben neben der 2,6-m-Figur,
dazu die Spielkamera und der schwarze Umriss; darunter jeder Clip als Bildfolge (7 Bilder). **Sieh sie dir an**:
- Größe im Vergleich zur Figur? Umriss eindeutig?
- Stehen die Füße auf dem Boden (auch in `death`)? Fliegt nichts unter die Erde?
- Ist jede Bewegung auf den kleinen Bildern zu erkennen? Wenn nicht: größere Ausschläge.

Alle Umrisse einer Familie nebeneinander (für die Abnahme):
`python3 -c "import sys; sys.path.insert(0,'blender'); import vat_bake; vat_bake.umriss_tafel('wald', ['wald_pilzling', ...])"`

## 6. Im Spiel testen

1. Einmal importieren (legt die Godot-Importdateien an): `godot --headless --import` im Projektordner.
2. Starten und ansehen:
   - **Admin-Menü** (Taste `-`) → **Kampf** → „Flut jetzt“ oder „Übung jetzt“ → Art in der Zeile ihrer Familie wählen → „1 / 10 / 50 spawnen“.
   - oder per Kommandozeile (Bildschirmfotos):
     `godot -- --setup=6 --week=2 --do=flood --spawn=wald_pilzling:20,wald_dornenwolf:4 --shots=<ordner> --name=test --at=2,5`
     (`--spawn=<key>:<anzahl>,…` stellt die Gegner rund um den Helden auf, `--spawn_r=` Abstand, `--spawn_hp=` Lebens-Faktor).
   - Flut mit der Familie als Gast: `-- --autotest=flood --bunker=5 --week=6 --fast=8 --guest=wald`
   - Expedition im Gebiet der Familie: `-- --autotest=exp --setup=6 --area=<1..6> --mission=nest --fast=8`
3. Prüfungen: `-- --autotest=gegner` (alle Tests von Paket 11; gibt `SELFTEST GEGNER OK` aus). Für jedes Modell wird dabei geprüft:
   Pflicht-Clips vorhanden, mindestens ein besonderer Clip, Eckpunkt-Grenze, Texturgröße.
4. Monsterbuch: Profil → „Monsterbuch“. Sobald das Modell da ist, verschwindet der Hinweis „Modell folgt“ von selbst.

## 7. Wie es technisch funktioniert (zum Nachschlagen)

- `animkit.Rig` schreibt die Posen als Keyframes auf die Blender-Zeitleiste (Clips hintereinander, 12 Bilder Abstand) und merkt die
  Clip-Liste in `scene["rw_clips"]` und als Marker. Die `.blend`-Datei enthält die animierte Figur.
- `vat_bake.bake_vat(key)` stellt jedes dritte Bild ein (`scene.frame_set`), wertet alle Objekte aus (Keyframes, Eltern-Ketten,
  Modifikatoren, auch Armaturen) und schreibt
  - `e_<key>.glb`: ein Mesh `body` in Ruhepose, Vertex-Farben, UV 1 = (Leuchten, Kennung), UV 2 = Spalte/Zeile des Eckpunkts in der Textur,
  - `e_<key>_vat.png`: RGB, 8 Bit, drei Blöcke untereinander (Position obere 8 Bit, untere 8 Bit, Normale); eine Spalte je Eckpunkt,
    eine Zeile je gespeichertem Bild (bei mehr als 1024 Eckpunkten mehrere Zeilen je Bild). Ohne Alpha – so übersteht die Datei den
    Standard-Import von Godot verlustfrei (keine Kompression, keine Mipmaps),
  - `e_<key>.json`: Clips (erste Zeile, Bildzahl, Dauer, Schleife, Schrittlänge, Treffer-Zeit), Wertebereich der Positionen, Größe.
- `src/vat.gd` lädt das Bild, schneidet es in drei Texturen (je höchstens 1024 × 512) und baut das Material.
  `shaders/vat.gdshader` liest je Eckpunkt mit `texelFetch` zwei Bilder des Clips, rechnet dazwischen und blendet zum vorigen Clip über.
- `src/horde.gd` übergibt je Figur über `INSTANCE_CUSTOM` Clip A + Blickrichtung + „Zubehör weg“, Fortschritt A, Clip B + Mischung,
  Fortschritt B und über die Instanzfarbe Zustandsfärbung und Trefferblitz.

## 8. Paket G2: neue Rollen, Minibosse, Weltboss (Kapitel 6.3 / 6.5)

| Skript | Arten |
|---|---|
| `enemies2_kit.py` | gemeinsame Abläufe: `biped(...)` (Zweibeiner) und `quad(...)` (Vierbeiner/Krabbler) mit allen Pflicht-Clips und dem Rollen-Clip, `mound()` (Erdhügel der Tunnelgräber) |
| `enemies2_schleim.py` | Brutschleim, Deckelschild, Klauschleim, Miniboss Glibberkoloss (mit `slime()` aus `enemies_schleim.py`, Parameter `more=` für Zusatz-Clips) |
| `enemies2_wald.py` · `_wueste.py` · `_untote.py` · `_mutanten.py` · `_eis.py` · `_daemonen.py` | je drei neue Rollen + Miniboss der Familie |
| `enemies2_leviathan.py` | Weltboss `boss_leviathan` (echte Boss-Figur) |

Rollen-Clips (das Spiel ruft sie über `anims` in `src/data.gd`):

| Rolle (`role`) | Clip | wann |
|---|---|---|
| `healer` | `heal` | Heilpuls |
| `shield` | `block` | ein Treffer prallt am Schild ab (Teil `shield` bzw. Zubehör vorn) |
| `digger` | `dig`, `under` (Schleife, nur der Erdhügel `mound` ist sichtbar), `rise` | unter Mauern hindurch |
| `jammer` | `jam` | Wurf auf einen Turm |
| `thief` | `grab` | greift in das Lager |
| `brood` | `brood` | Junge schlüpfen |
| `miniboss` | `skill` | Fähigkeit mit roter Bodenmarkierung |

Grenzen: die neuen Rollen wie Fernkämpfer (1 600 Eckpunkte), Minibosse wie Brocken (2 800).
Weitere Clips in Paket G2: `kneel` (Kanonier) und `puff` (Feuerspeier) spielt das Spiel vor jedem Schuss (`anims.aim`),
der Yeti wirft mit `throw` (`anims.shot` = eigener Clip für Fernschüsse).
