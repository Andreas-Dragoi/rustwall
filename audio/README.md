# Ton von Rustwall

## Ordner

- `audio/music/` – die Musik.
  - `castle_defense.mp3` – **dein eigenes Lied** („Colorful Castle Defense“), unverändert übernommen. Es läuft immer zuerst.
  - `meadow_march.ogg` – munterer Marsch für den Kampf (C-Dur, 114 Schläge pro Minute, passend zu deinem Lied).
  - `evening_base.ogg` – ruhiges Abendstück für die Basis (F-Dur, 76 Schläge pro Minute).
- `audio/sfx/` – alle Geräusche als WAV (16 Bit, mono; kurze Effekte 44,1 kHz, längere Klänge und Schleifen 22,05 kHz, Umgebung 16 kHz).
- `tools/` (neben diesem Ordner, wird von Godot nicht eingelesen) – die Skripte, die alles außer deinem Lied erzeugen:
  - `python3 tools/make_music.py` rendert die beiden Folgestücke (braucht numpy, scipy, ffmpeg).
  - `python3 tools/make_sfx.py` rendert alle Geräusche (numpy, scipy).
  - `python3 tools/check_sounds.py` prüft, ob es für jeden im Code benutzten Namen eine Datei gibt.

## Wie die Musik läuft

Reihenfolge: dein Lied → `meadow_march` → `evening_base` → dein Lied → … Kurz vor dem Ende eines Stücks setzt das
nächste ein, beide werden fünf Sekunden lang weich überblendet; bei deinem Lied endet die Überblendung genau am
gemessenen Schluss (359,2 s). Im Kampf wird das ruhige Stück übersprungen, im Pausenmenü klingt die Musik gedämpft.
Lautstärke: Einstellung `music` (0 bis 1, Standard 0,6; bei 0 hält die Musik an), Geräusche: Einstellung `sfx`.
Zuständig sind `src/music.gd` (Autoload `Music`) und `src/sfx.gd` (Autoload `Sfx`).

## Etwas austauschen

Einfach eine Datei **mit demselben Namen** in den Ordner legen und Godot neu importieren lassen – am Code muss nichts
geändert werden. Ein anderes Lied als `castle_defense.mp3` funktioniert genauso (ist es anders lang, endet die
Überblendung 0,8 s vor dem Dateiende). Gibt es von einem Geräusch mehrere Fassungen (`name_1.wav`, `name_2.wav` …),
wird bei jedem Abspielen gewürfelt; man kann also jederzeit weitere Fassungen dazulegen. Schleifen (`*_loop`, `engine_*`,
`amb_*`) sollten nahtlos sein.

## Namen der Geräusche

**Oberfläche:** click, ui_open, ui_close, ui_tab, ui_select, ui_equip, ui_upgrade, ui_buy, ui_dismantle, ui_merge, ui_claim,
ui_error, ui_toggle, ui_slider, ui_toast, pay, error, chest, chest_open, chest_item_0 … chest_item_3 (Seltenheit),
level_up, hero_level_up, hero_unlock, quest_done

**Held:** step_grass / step_sand / step_snow (je 3), hop, dash, hurt (2), hero_down, respawn, heartbeat, reload,
reload_done, empty, crit

**Waffen:** w_rifle (3), w_parcel, w_burst (3), flame_loop, water_loop, w_fireball, w_nailer (2), w_ball_swing, w_ball_thud,
w_cement, w_spark (2), w_shrink, w_cloud, w_sniper, w_bow (2), w_swarm, w_cracker, w_sparkler, w_cake

**Fähigkeiten:** sk_rally, sk_roll, sk_delivery, sk_firewall, sk_heatshield, sk_inferno, sk_shieldup, sk_patch, sk_berta,
sk_turret, sk_overload, sk_pieps, sk_kiko, sk_smoke, sk_flock, sk_crackers, sk_thermos, sk_festival;
Kommandant: sk_airstrike, sk_supply, sk_barrier, sk_backup; skill_ready

**Türme:** t_mg (3), t_watch, t_cannon, t_mortar, t_tesla, t_rocket, t_ice, t_aa (2), t_mini, (Flammenturm: flame_loop),
tower_buff, tower_spawn

**Geschosse und Einschläge:** whoosh, rocket_fly, explosion_small (2), explosion_big, ice_shatter, splash, glue_splat,
cake_splat, fire_whoosh, thunder, heal, zone_heal

**Schleimlinge:** slime_hop (3), slime_hit (3), pop_small (3), pop_big (2), pop_boss, spit (2), spit_land, fuse, barrel_boom,
shield_clank (2), shaman_heal, boss_arrive, boss_roar, boss_slam, boss_summon, boss_defeat

**Münzen und Rohstoffe:** coin (3), coin_drop (2), pickup, res_coins, res_wood, res_stone, res_metal, res_fuel, res_cells,
res_parts, res_shards, backpack_full

**Bauen und Gebäude:** build, build_place, build_done, build_move, build_remove, upgrade, upgrade_start, upgrade_done,
wall_hit_wood / _stone / _metal (je 2), wall_break_wood / _stone / _metal, struct_hit (2), struct_destroy, repair,
trap_spike, glue_step, mine_beep, shield_hum

**Flut:** flood_alarm (Tag 7), flood_horn, wave, wave_clear, win, lose, practice_done

**Expedition:** chest_found, nest_destroyed, cage_rattle, cage_open, rescue_cheer, gate_pass, race_beep, race_beep_last,
pad_build, outpost_alarm, extract_loop, extract_success

**Fahrzeuge:** veh_mount, veh_dismount, veh_broken, ram_bump, engine_quad, engine_bike, engine_buggy, engine_pickup,
engine_hover (Schleifen, Tonhöhe folgt dem Tempo)

**Umgebung (Schleifen):** amb_meadow, amb_forest, amb_desert, amb_coast, amb_swamp, amb_snow, amb_crater

Ältere Namen aus dem Code (z. B. `shot_mg`, `explosion`, `pop`, `zap`) werden in `src/sfx.gd` (Tabelle `ALIAS`) auf die
neuen Dateien umgeleitet.

## Paket Welt (V5): Musik je Ort, Ton-Prüfung, Mischpult, Rufe

**Musik** (`python3 tools/make_music.py [name|areas]`, Stil je Gebiet, nahtlose Schleifen, 32 kHz, OGG):
`area_<gebiet>.ogg` (Ruhe-Lage) und `area_<gebiet>_fight.ogg` (Gefahr-Lage: Schlagzeug, Bass, Bläser) für alle
Gebiete, dazu `boss.ogg`, `menu.ogg`, `win.ogg`, `lose.ogg` (Stinger). Die beiden Lagen laufen im Spiel synchron
(`AudioStreamSynchronized`); die Gefahr-Lage wird nach der Zahl der Gegner um den Helden eingeblendet (Großangriff: ganz).
Boss-Stimmung (Expedition und Flut) spielt `boss.ogg`, das Hauptmenü nach dem ersten Durchlauf des eigenen Lieds
`menu.ogg`. Die Klänge `win` und `lose` werden durch die Stinger ersetzt (die übrige Musik wird dafür kurz leiser).
In der Basis läuft die Wiedergabeliste wie bisher. Lautheit: Ruhe-Lage −16,5 LUFS, Gefahr-Lage 2,5 dB leiser.

**Ton-Prüfung ohne Ohren:** `python3 tools/check_audio.py [--fix] [--music]` misst jede Datei (Kurzzeit-Lautheit wie
make_sfx, Spitze, übersteuerte Werte, Stille am Anfang/Ende, Gleichanteil, Sprung an der Schleifen-Naht) und vergleicht
mit dem Ziel der Gruppe (Oberfläche, Waffen, Einschläge, Gegner, Ereignisse, Begleiter, Held, Umgebung, Stimmen …).
`make_sfx.py` hält jeden Klang höchstens 70 % der erlaubten Abweichung vom Gruppenziel entfernt. Gefunden und behoben:
`gate_open` (Gleichanteil statt Ton, 10 dB zu leise) und die Motorschleifen `engine_*` (Knacks an der Naht alle 0,5 s).

**OGG:** Einzelklänge über 1,2 s und Schleifen ab 4 s schreibt `make_sfx.py` als OGG (bitgenau, `sfx.gd` lädt beides).

**Mischpult:** vier Regler in den Einstellungen – Musik (Kanal `Music`), Geräusche (`SFX`), Umgebung (`Ambient`: alle
Schleifen `amb…`, `nat_…`, `wx_…`) und Stimmen (`Voice`: alle `v_…`).

**Neu:** lange Gebiets-Umgebung `amb_x_<gebiet>` und `amb_x_night`; Ereignisse `ev_amb_*` (Sandsturm, Schneesturm,
Giftnebel, Nebel, Brandung, Regen, Meteoritenglut) und `ev_*`; Quellen `hit_tap/ice/pump/shell/resin/honey/geyser`;
`landmark_discover`, `journal_page`, `tool_get`, `tool_missing`, `caravan_bell`, `caravan_trade`, `quest_new`,
`quest_step`, `egg_found/crack/hatch`, `comp_lure`, `comp_collect`, `dummy_hit`, `dummy_reset`, `train_start`,
`npc_wish(_done)`, `npc_shoo`, `npc_sigh`, `tree_chop_base`, `barrow_squeak`, `lamp_on`; Helden-Rufe
`v_<held>_<start|skill|dodge|hurt|down|cheer|win>` (Formant-Stimme, je Held eigene Stimmlage und Worte).
