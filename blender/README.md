# Rustwall – Modelle aus Blender

Alle Modelle des Spiels werden mit Python-Skripten in Blender gebaut (`bpy`, getestet mit Blender 5.2).
Jedes Skript erzeugt je Modell:

- `blender/blend/<name>.blend` – die Blender-Datei des einzelnen Modells (wird beim Ausführen erzeugt;
  `python3 blender/collect.py` fasst sie zu den mitgelieferten `blender/rustwall_<gruppe>.blend` zusammen),
- `models/<name>.glb` – das Modell, das Godot lädt,
- `icons/<name>.png` – ein freigestelltes Symbol für die Menüs (mit Cycles gerendert).

Ausführen: `python3 blender/<skript>.py` (mit installiertem `bpy`) oder `blender -b -P blender/<skript>.py`.

## Regeln (gelten für jedes Modell)

- **Baukasten:** nur `kit.py` benutzen (`Part` mit `box`, `cyl`, `cone`, `ball`, `torus`, `voxels`; `empty`, `save`, `icon`, `col`, `shade`, `mix`, `rot`).
  Farben sind Vertex-Farben; es gibt genau ein Material. Keine Texturen, keine weiteren Materialien.
- **Achsen:** Z ist oben. Die Vorderseite zeigt nach **-Y** (in Godot wird daraus +Z). Einheit Meter.
  Der Ursprung des Wurzelobjekts liegt am Boden in der Mitte der Grundfläche.
- **Stil:** rundes, buntes Spielzeug – kräftige Farben, großzügig abgerundete Kanten (`bevel`), gedrungene Proportionen,
  wenige klare Formen statt Kleinkram. Helden und Siedler sind Voxel-Figuren (`heroes.py`).
- **Größe:** 1 Rasterfeld = 2 m. Ein Gebäude mit 3x3 Feldern darf höchstens ca. 5,6 x 5,6 m Grundfläche haben.
- **Sparsam:** Ziel höchstens ca. 6 000 Dreiecke je Gebäude, 2 500 je Kulisse, 1 500 je Gegner/Waffe. Wenige Objekte je Modell
  (jedes Objekt ist in Godot ein Zeichenaufruf): statische Teile in EIN Objekt `body` zusammenfassen.

## Namen von Objekten, die Godot auswertet

| Name | Wirkung in Godot |
|---|---|
| `*_glow` (z. B. `win_glow`) | leuchtet unbeleuchtet (Fenster, Lampen, Displays) |
| `lvN_*` (z. B. `lv4_trim`) | erst ab Gebäudestufe N sichtbar |
| `spin_*` | dreht sich dauerhaft um die eigene lokale Z-Achse (Sägeblatt, Rotor, Radar) |
| `bob_*` | schwebt sanft auf und ab |
| `sway_*` | wiegt sich leicht hin und her (Fahnen, Schilder) |
| `pulse_*` | pulsiert in der Größe (Energiekugeln) |
| Leerobjekt `fx_smoke*` | Rauch steigt auf (Schornstein) |
| Leerobjekt `fx_spark*` | Funken sprühen |
| Leerobjekt `fx_steam*` | weißer Dampf |

Die Kombination ist erlaubt, z. B. `spin_blade_glow`. Der Ursprung eines `spin_`-Objekts muss in der Drehachse liegen
(`Part.build(name, parent, loc=...)` setzt den Ursprung; die Geometrie wird relativ dazu gebaut).

## Dateinamen

| Art | Name |
|---|---|
| Held / Siedler | `hero_<schlüssel>`: Skelett `rw_human` + ein Mesh `body` (Teile starr an je einen Knochen gebunden), bei Ada/Yuki zusätzlich `extra` (Begleiter) |
| Animationen | `anim_human` (nur Skelett + alle Clips), dazu die Tabelle `src/anim_human_data.gd` |
| Fahrzeug | `v_<schlüssel>` (body, wheel_*, fan, Leerobjekt seat) |
| Gebäude | `b_<schlüssel>`; Bunker in fünf Ausbaustufen `b_bunker_1` … `b_bunker_5` |
| Mauer | `wall_post_<0..2>`, `wall_link_<0..2>` (Verbindung entlang X, genau 2 m lang, mittig) |
| Turm | `t_<schlüssel>`: Objekte `base`, `head` (dreht um Z), `pitch` (Kind von head, neigt um X), Leerobjekte `muzzle`, `muzzle2`, … (Kinder von pitch) |
| Kulisse | `p_<name>` |
| Gegner | `e_<nummer>` (ein Objekt `body`, Vorderseite -Y, Radius ca. 0,5 m, steht auf dem Boden) |
| Waffe | `w_<schlüssel>`: Lauf zeigt nach -Y, Griff im Ursprung, Leerobjekt `muzzle` an der Mündung |
| Ausrüstung | `gear_<helmet|vest|charm>_<0..3>` (Seltenheit) |
| Rohstoff-Symbol | `res_<coins|wood|stone|metal|fuel|cells|parts|shards>` |

## Figuren: Skelett und Animationen

- `rig_human.py` baut das gemeinsame Skelett `rw_human` (root, hips, spine, chest, neck, head, je Seite shoulder, upper_arm,
  fore_arm, hand, thigh, shin, foot, dazu prop_r für die Waffe und prop_back für den Rucksack). Alle Knochen zeigen in der
  Ruhelage nach oben und sind gleich ausgerichtet; "_r" ist die Seite +X (Waffenhand).
- `heroes.py` bindet jedes Voxel-Teil mit `kit.bind(objekt, knochen)` starr an genau einen Knochen (Gewicht 1,0) und fügt alles
  mit `kit.skin(teile, armature)` zu einem Mesh zusammen. Zubehör, das nachschwingen soll, bekommt einen Knochen `spring_*`
  (Antenne, Federn, Spulen) – Godot hängt daran einen SpringBoneSimulator3D. Export mit `kit.save_rigged(name)`.
- `anim_human.py` erzeugt alle Clips als Actions (je Action eine NLA-Spur) und exportiert `models/anim_human.glb`.
  Posen werden als Drehungen um Weltachsen beschrieben; Beine und Waffenhand über eine Zwei-Glieder-Lösung, damit Füße am
  Boden bleiben und die Waffe genau nach vorn zeigt. Schrittlängen: walk 1,1 m, run 2,0 m je Zyklus (Figur im Spielmaßstab 1,5),
  alle Lauf-Clips sind 0,8 s lang. Ereignisse `foot_l` / `foot_r` stehen als Pose-Marker in der Action und in
  `src/anim_human_data.gd` (wird vom Skript geschrieben, nicht von Hand ändern).
- Achtung: Godot streicht beim Import die Endung `_loop` aus Animationsnamen (`fire_spray_loop` heißt in der GLB `fire_spray`);
  `humanoid.gd` gleicht das aus.
- Ansehen und prüfen: `res://scenes/anim_test.tscn` (Held läuft über ein Schachbrett, Tasten siehe `src/anim_test.gd`).

## Gebäude nach dem Detail-Katalog (Auftrag V3, Kapitel 6)

Bunker, Produktion, Lager und besondere Gebäude entstehen in `blender/geb.py` (Aufruf: `python3 blender/geb.py [namen...]`):
`geb_kit.py` (Baukasten: Fundament mit Fugen, Wände aus Brettern/Ziegeln/Quadern/Wellblech/Betonplatten, Dächer mit Ziegel- und
Blechreihen, First, Dachrinne, Türen, Fenster, Lampen, Gebrauchsspuren, Schadens-Teile, Klasse `Model`), `geb_prod.py`
(Sägewerk, Steinbruch, Schrottpresse, Raffinerie, Generator, Lager), `geb_special.py` (Quartier, Kistenlager, Werkstatt, Garage,
Funkturm, Clanhalle, Labor, Schildgenerator, Trainingsplatz), `geb_bunker.py` (`b_bunker_1` … `b_bunker_5`).
`python3 blender/buildings.py <name>` leitet für diese Namen dorthin weiter.

- Maßstab: Tür 2,6 x 1,4 m, Stockwerk 3,2 m, Hofplatte 0,25 m hoch; Grenze 12 000 Dreiecke je Gebäude, Bunker 18 000.
- `GEB_SHOTS=<ordner>` rendert zusätzlich Prüfbilder (`<name>_sicht.png`: vorn, rechts, hinten, links, Spielsicht;
  `<name>_stufen.png`: Ausbau-Aussehen und beide Schadensstufen). `GEB_NOICON=1` / `GEB_NOAO=1` für schnelle Probeläufe.
- `python3 blender/check_models.py` prüft alle `models/b_*.glb`: Dreiecke, Objekte, Grundfläche, Pflicht-Leerobjekte, bewegte Teile.
- Die Spielkamera sieht Vorderseite (-Y) und rechte Seite (+X): Funktions-Teile gehören nach vorn und rechts, Hohes nach hinten links.
- Die Umgebungsverschattung (`kit.bake_ao()`) wird je Ausbau-Aussehen getrennt gerechnet (`Model.bake()`), damit sich
  Teile, die nie zusammen sichtbar sind, nicht gegenseitig verdunkeln. Drehende Teile und Fahnentücher bleiben unverschattet.

### Weitere Objektnamen dieser Gebäude

| Name | Wirkung in Godot |
|---|---|
| `body` | alles Statische, das in jeder Stufe sichtbar ist |
| `win_glow`, `lamp_glow`, `panel_glow`, `gauge_glow`, `esse_glow`, `innen_glow`, `pump_glow`, `funk_glow`, `kuppel_glow` | Fenster, Außenlampen, Lämpchen, Glut: leuchten |
| `lv4_*`, `lv7_*` | erst ab Gebäudestufe 4 bzw. 7 sichtbar (auch leuchtende Teile: `lv7_win_glow`, `lv4_lamp_glow`) |
| `lvmax3_*`, `lvmax6_*` | nur bis Gebäudestufe 3 bzw. 6 sichtbar (werden danach durch `lv4_*` / `lv7_*` ersetzt) |
| `lv<2k>_extra` (nur Bunker-Modell k) | kleiner Zwischenausbau auf der geraden Bunkerstufe (Modell k gilt für Stufe 2k-1 und 2k) |
| `dmg1_*` | sichtbar unter 60 % Leben: Risse, Ruß, aufgenagelte Bretter |
| `dmg2_*` | sichtbar unter 30 % Leben: Löcher, Stützbalken, Trümmer |
| Leerobjekt `fx_smoke_dmg` | Ort des Rauchs bei schwerem Schaden (nur zusammen mit `dmg2_*` einschalten) |
| `fill1_*` … `fill4_*` | Füllstand: `b_lager` vier Gruppen Kistenstapel im Hof, `b_saege` drei Gruppen Stämme (`fill1_logs` … `fill3_logs`) |
| Leerobjekte `door`, `work_1`, `work_2`, `drop` | am Boden: vor der Tür, zwei Arbeitsplätze, Ablage für Getragenes |
| Leerobjekt `bubble` | über dem Dach: Ort der Sammelblase |
| Leerobjekt `veh_slot` (`b_garage`) | Stellplatz in der Halle hinter dem halb offenen Rolltor; das Fahrzeug blickt nach -Y (Godot +Z) |
| `sway_flag*`, `sway_banner_*` | Tuch in der Palettenfarbe `flag` (026AED): bekommt die Farbe des Spielers |

Bewegte Teile je Gebäude (das Spiel hält `spin_/bob_/pulse_` der Produktionsgebäude an, wenn der Speicher voll ist):
`b_saege` spin_blade, spin_wheel · `b_steinbruch` sway_block, spin_brecher · `b_presse` bob_stempel, spin_rolle, spin_rolle2, sway_magnet ·
`b_raffinerie` spin_ventil, spin_ventil2, pulse_flamme_glow · `b_generator` spin_rad, pulse_spule_glow, pulse_spule2_glow ·
`b_lager` sway_haken, sway_schild · `b_quartier` spin_wetterhahn, sway_waesche, sway_flag · `b_kistenlager` sway_haken, bob_kiste, pulse_schein_glow ·
`b_werkstatt` spin_zahnrad, spin_stein, sway_flag · `b_garage` spin_luefter, bob_buehne, sway_flag · `b_funkturm` spin_schuessel, pulse_lampe_glow, sway_flag ·
`b_clanhalle` sway_banner_l, sway_banner_r, sway_glocke, pulse_feuer_glow, pulse_feuer2_glow · `b_labor` pulse_tank_glow, spin_antenne, spin_ventil, pulse_spitze_glow, sway_flag ·
`b_schild` pulse_kern_glow, spin_ring, spin_ring2_glow, pulse_spule_glow, pulse_spule2_glow, sway_flag · `b_training` spin_puppe, sway_sack, sway_flag ·
`b_bunker_*` spin_schuessel, sway_scheinwerfer, sway_flag (Modell 5 zusätzlich sway_banner_l/r, pulse_stern_glow).

## Paket 6 – Verteidigung, Mauern, Tore, Gerüste, Fallen, Schmuck (`def_*.py`)

Diese Modelle entstehen **nicht mehr** in `towers.py`, `buildings.py` (Abschnitte wall, stachel, kleb, mine, laterne, flagge,
blumen, statue) und `v3_assets.py` (tor, wall_site), sondern in:

| Skript | Modelle |
|---|---|
| `def_towers.py` | `t_mg`, `t_watch`, `t_cannon`, `t_flame`, `t_mortar`, `t_tesla`, `t_rocket`, `t_ice`, `t_aa`, `t_mini` |
| `def_walls.py` | `wall_post_0..2`, `wall_link_0..2`, `wall_site`, `b_tor_0..2`, `b_scaffold_2x2 / 3x3 / 4x4 / 3x2 / 4x3 / 2x1` |
| `def_small.py` | `b_stachel`, `b_kleb`, `b_mine`, `b_laterne`, `b_flagge`, `b_blumen`, `b_statue` |
| `def_kit.py` | gemeinsame Helfer; `python3 blender/def_kit.py check` druckt die Prüfliste (Dreiecke, Objekte, Pflichtteile) |

Achtung: Wer `towers.py`, `python3 blender/buildings.py` ohne Namen oder `v3_assets.py` ohne Namen laufen lässt, überschreibt
diese Dateien mit den alten Modellen – danach `def_towers.py`, `def_walls.py`, `def_small.py` erneut ausführen.

Verschattung: `def_kit.finish()` ruft `kit.bake_ao()` in drei Durchgängen auf (Grundmodell, dann `lvmax*`/`dmg*`/`fill*`, dann `lv*`),
damit ausgeblendete Zustands-Objekte das Grundmodell nicht verdunkeln; Flaggen bleiben unverschattet (Godot erkennt sie am
genauen Flaggenblau `026AED`). Die Symbole zeigen Stufe 1 ohne Schaden.

### Weitere Objektnamen, die Godot auswertet (neu in Paket 6)

| Name | Wirkung in Godot |
|---|---|
| `lvmaxN_*` | nur **bis** Stufe N sichtbar (Teile, die ein späterer Ausbau ersetzt; z. B. `lvmax3_wood`, `lvmax6_roof`) |
| `dmg1_*` | sichtbar unter 60 % Leben (Ruß, Brocken) |
| `dmg2_*` | sichtbar unter 30 % Leben; dazu Rauch am Leerobjekt `fx_smoke_dmg`, Lampen (`*_glow`) flackern |
| `fill1_*` … `fillN_*` | Füllstand: Stufe k zeigt `fill1..k` (Lager: Anteil gefüllter Lagerkapazität; Produktion: eigener Rohstoff) |
| Leerobjekt `fx_shell` (Kind von `pitch`) | Hülsenauswurf beim Schießen (nur MG, Wachturm, Luftabwehr) |
| Leerobjekt `work_1` | hier bringt ein Bewohner Munition (am Boden neben den Munitionskisten) |
| Leerobjekt `gunner` (Kind von `head`, nur `t_watch`) | Platz des Schützen |
| Leerobjekt `veh_slot` (Garage) | hierhin stellt das Spiel das gewählte Fahrzeug |
| Leerobjekt `statue_slot` + Objekt `statue_default` (Statue) | Figur des gewählten Helden, versteinert; sonst bleibt die neutrale Figur |
| `lamp_glow` an `b_mine` | blinkt (structure.gd) |
| `sway_flag*`, `*banner*` | Tuch in der Flaggenfarbe des Spielers (`MK.mat_flag()`); `sway_tarp*` = Planen am Gerüst |

### Türme: Aufbau und Ausbau-Aussehen

`base` (fest) · `head` (dreht um Z, Ursprung auf dem Sockel) · `pitch` (Kind von head) · `muzzle`, `muzzle2`, `muzzle3` (Kinder von pitch).
Stufe 1–3: Holzverkleidung `lvmax3_wood`; ab 4: Steinkranz `lv4_stone` und Schutzschild am Geschütz; bis 6: Holzleiter `lvmax6_ladder`
(Wachturm zusätzlich rotes Schindeldach `lvmax6_roof`); ab 7: Stahlleiter, Panzerplatten und Gold `lv7_*`.
Schaden: `dmg1_base`/`dmg2_base` am Sockel, `dmg1_head`/`dmg2_head` am Geschütz.
Grundflächen: MG, Wachturm, Flammenturm, Tesla, Luftabwehr höchstens 3,6 m; Kanone, Mörser, Rakete, Eis höchstens 5,6 m. Höchstens 6 000 Dreiecke.

### Mauern, Tore, Gerüste

- `wall_post_N` steht in der Feldmitte, `wall_link_N` ist entlang X genau 2 m lang (x = −1 … +1) und nie tiefer als der Pfosten;
  je ein Mesh `body`, höchstens 500 Dreiecke. Neben einem Tor zeichnet `base_world._update_walls` ein halbes Verbindungsstück
  (X-Maßstab 0,5) bis zur Torkante – die Tor-Pfosten reichen deshalb außen genau bis x = ±2,0.
- `b_tor_N`: 4 m × 2 m, Durchfahrt 2,68 m breit und 3,05 m hoch; `door_l`/`door_r` haben den Ursprung am Scharnier (x = ∓1,34).
- `b_scaffold_<w>x<h>`: Stangen 6 cm innerhalb der Feldgrenze, innen frei, vorn nur ein Riegel je Etage; `body` + `sway_tarp1..3`.
  Das Spiel streckt das Gerüst in der Höhe bis knapp über das Gebäude (höchstens 1,45-fach).

## Expedition und Außenbasen (V3, Pakete 3 und 4)

Skript: `python3 blender/outpost.py [namen…]` (ohne Namen: alles; `list` zeigt die Namen). Die Modelle stehen in
`outpost.py` (Zubehör der Außenbasis), `exp_special.py` (Spezialbauten), `exp_barriers.py` (Sperren), `exp_nodes.py`
(Rohstoffquellen) und `exp_areas.py` (Schaubilder); gemeinsame Helfer in `exp_common.py`. Vor dem Speichern wird
`kit.bake_ao()` je Ausbaustufe aufgerufen (`ao_staged()`), damit spätere Anbauten die Stufe 1 nicht verschatten.

| Name | Bedeutung | Objekte mit Wirkung |
|---|---|---|
| `o_zentrale` | Zentrale der Außenbasis (höchstens 5,6 × 5,6 m) | `spin_dish`, `sway_flag`, `win_glow`, `lamp_glow`; Leerobjekte `door`, `bubble` |
| `o_depot` | Depot, offener Unterstand (3,2 × 3,6 m) | `lamp_glow`; Leerobjekte `drop` (Abladestelle vorn), `bubble` |
| `o_feuer` | Lagerfeuer mit Kessel und Sitzstämmen | `fire_glow`; Leerobjekt `fx_smoke` |
| `o_parkplatz` | Park-/Wartungsplatz 3,2 × 3,2 m (Mitte frei für das Fahrzeug) | `lamp_glow`; Leerobjekt `bubble` |
| `o_special_<gebiet>` | Spezialbau je Gebiet (`gruental` Holzfällerlager, `forst` Jägerhütte, `staub` Tankstelle, `kueste` Schrotthafen, `sumpf` Pumpwerk, `frost` Bergwacht, `krater` Forschungsstation), höchstens 3,4 × 4 m | Stufen über `lv2_annex`, `lv3_upper` (+ `lv3_win_glow`), `lv4_armor`, `lv5_gold`; je zwei bewegte Teile (`spin_*`, `sway_*`, `bob_*`, `pulse_*`), ein `fx_*`-Punkt, `win_glow`; Leerobjekte `door`, `bubble` |
| `o_pad` | Bodenplatte eines Bauplatzes, Radius 1,6 m | `ring_glow` (Ring am Rand) |
| `o_truck` | Lieferwagen der täglichen Lieferung | `wheel_fl/fr/bl/br`, `lamp_glow`; Leerobjekt `seat` |
| `o_trader` | Karren des fahrenden Händlers | `lamp_glow`; Leerobjekt `bubble` |
| `x_barrier_<gebiet>` | Sperre eines Durchgangs: 8 m entlang X, ca. 3,3 m tief, ca. 3,5 m hoch, blickdicht | `sumpf`: `ooze_glow`, Leerobjekte `fx_steam1`…`fx_steam4`; `krater`: `pulse_bubble1`…`3` |
| `n_tree_small`, `n_tree_big` | Laubbaum (4 m) und Tanne (7 m) zum Fällen | Stamm = `body`, Krone = `sway_crown` (Ursprung am Kronenansatz) |
| `n_stump` | Baumstumpf mit Axtkerbe (bleibt nach dem Fällen stehen) | – |
| `n_rock_1…3`, `n_scrap_1…3`, `n_crystal_1…3` | Felsbrocken, Schrotthaufen, Energiekristalle: dieselbe Quelle in drei Größen (voll → fast abgebaut) | Kristalle: `crystal_glow` |
| `n_wreck`, `n_barrel_fuel`, `n_pump`, `n_battery`, `n_shard_vein`, `n_coinpile` | Autowrack, Fassgruppe mit Zapfhahn, alte Zapfsäule, Batteriestapel, Scherbenader, Münzhaufen | `globe_glow` (Zapfsäule), `lamp_glow` (Batterien), `vein_glow` (Scherbenader) |
| `icons/area_<gebiet>.png` | Schaubild des Gebiets für die Weltkarte (nur Bild; die `.glb` wird nach dem Rendern gelöscht) | – |

Symbole: jedes Modell hat `icons/<name>.png`; die Spezialbauten zeigen dort Stufe 5 und zusätzlich
`icons/o_special_<gebiet>_1.png` die Stufe 1.

## V4 Waffen-Arsenal (Paket W)

72 weitere Heldenwaffen (je Held 12, zusammen mit den drei Startwaffen 15) entstehen in `weapons_v4_<held>.py`
(`jona`, `mika`, `bruno`, `ada`, `yuki`, `greta`) mit den Helfern aus `weapons_v4_kit.py`, der wiederum `weapons.py`
benutzt (gleicher Einheitsraum, gleiche Hilfsformen). Die Länge jeder Waffe (`len`) liest das Skript aus `src/data.gd`.
Aufruf: `python3 blender/weapons_v4_jona.py [j_pistol ...]` (ohne Namen: alle des Helden). Ergebnis wie gehabt:
`models/w_<schlüssel>.glb` (body + Leerobjekt muzzle) und `icons/w_<schlüssel>.png`.
Wurfwaffen mit `spin` in `data.gd` (Bumerang, Feuerrad, Wurfsterne) fliegen im Spiel als dieses Modell.
Neue Haltungen in `anim_human.py`: `aim_/hold_` für pistol, spear, hammer, toss, staff und die Abläufe
`fire_thrust`, `fire_slam`, `fire_toss`, `fire_cast`.
## Begleiter und Ladung (Paket B)

Skripte: `python3 blender/companions.py [comp_esel …]` (zwölf Begleiter) und `python3 blender/cargo.py [cg_wood …]`
(Ladungsstücke und Kraxe). Begleiter sind in echter Größe gebaut; Godot zeigt sie 1,5-fach (`companion_data.gd`, `MODEL_SCALE`).
Animiert wird im Code (`src/companion.gd`) über bewegliche Teile – läuft so im Mobile- und im OpenGL-Renderer.

| Name | Bedeutung | Objekte mit Wirkung |
|---|---|---|
| `comp_<schlüssel>` | Begleiter: kistenbein, esel, schnecke, kaefer, ziege, drohne, biber, waschbaer, golem, husky, eule, gluehwurm | `body` (Ursprung in Hüfthöhe), `head` (Kind von body, Ursprung am Hals), `tail`, Beine `leg_fl/fr/bl/br` (Käfer zusätzlich `leg_ml/mr`, Golem `leg_l/r` und `arm_l/r`), Flügel `wing_l/r`, Rotoren `spin_rotor_1..4`, Schlitten `sled` (Husky); Leerobjekt `cargo` = Boden der Ladefläche; `*_glow` leuchtet |
| `cg_<rohstoff>` | Ladungsstück (wood, stone, metal, fuel, cells, parts, shards), ca. 0,32 m breit, Ursprung unten Mitte | `band_glow` (Zelle), `crystal_glow` (Splitter) |
| `cg_kraxe` | Holz-Kraxe des Helden (hängt am Knochen `prop_back`); Gurte vorn (-Y), Ladefläche hinten | Leerobjekt `load` |

Gelenk-Ursprünge: Beine an der Hüfte (drehen um X), Flügel an der Schulter (drehen um die Längsachse), Rotoren in der Achse
(drehen um die eigene Z-Achse). Flieger (Drohne, Eule, Glühwürmchen) haben `body` in Flughöhe (1,2 – 1,5 m).
