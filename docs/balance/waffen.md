# Waffen-Balance (Paket H, V6)

Gemessen im Spiel mit `godot --headless --path . -- --autotest=dps` (src/tests_helden.gd): jede der 105 Waffen gegen jede der 8 Familien,
je ein Einzelziel und eine Gruppe aus 6 Zielen, 4 Spielsekunden je Messung (Nachladen, Aufladen, Brennen, Gift, Flächen,
Geschütze, Schwächen/Resistenzen und Panzerung wirken wie im Spiel). Rohdaten: `dps_roh.csv`, Tabelle: `waffen.csv`,
Auswertung mit allen Werten: `waffen_messung.md`. Begleiter: `begleiter_kennzahlen.md` / `begleiter.csv`.

## Regel

Kennzahl = (½ · Einzel-DPS + ½ · Gruppen-DPS ÷ 3) ÷ Richtwert der Heldenstufe (D.weapon_power_ref), gemittelt über die Familien.
Verglichen wird mit dem Mittel der Waffen derselben Stufen-Spanne (1–10, 11–20, 21–30, 31–40) und Klasse (Einzelziel, Fläche, Geschütz).
Ausreißer: mehr als ±35 % neben diesem Mittel. Angepasst wurde nur der Schaden je Treffer; Besonderheiten (Betäuben, Sog, Heilung ...) bleiben.

## Ergebnis

- Erster Messlauf: 43 Ausreißer. Nach drei Anpassungsrunden mit Nachmessung: **2**, beide bewusst so belassen:
  - **Löschkanone (m_water), −81 %**: reine Kontrollwaffe (verlangsamt, schiebt zurück), richtet fast keinen Schaden an – Mikas Startwaffe 2 gegen Brände/Schleim, gewollt.
  - **Tortenheber (g_cake), −48 %**: Hauptzweck ist die Heilfläche für Greta (wird hier nicht gemessen); Schaden von 12 auf 18 angehoben.
- Alle Waffen bleiben im alten Kampfwert-Rahmen (45–160 % des Richtwerts, Prüfung in tests_waffen.gd).
- Auffällig, aber gewollt: Gegen **Wüstenmonster** (Panzerung) verlieren schwache Kugel-Treffer bis zu 75 % – Explosionen sind dort stark.
  Feuerwaffen machen gegen **Dämonen und Magma-Wesen** nichts, Gift gegen **Mutanten** nichts (Familienregeln).
- Aufladewaffen (Kapitänsbüchse, Gaußkanone, Kranichbogen, Abrisskanone, Flutwelle) waren im Messlauf am stärksten überzogen, weil der Bot
  ohne Pause voll auflädt; sie liegen jetzt 19–29 % über dem Mittel ihrer Spanne (Lohn fürs Stillhalten).

## Änderungen am Schaden je Treffer (src/data.gd)

| Waffe | alt | neu | Grund (Abweichung vorher) | Abweichung jetzt |
|---|---|---|---|---|
| j_shotgun | 7 | 13 | Schrot streut auf Kampfentfernung zu weit; Einzel-DPS lag 59 % unter dem Mittel | -24 % |
| j_boomerang | 20 | 24 | trifft im Mittel nur einmal (Rückweg verfehlt oft); −35 % | -19 % |
| j_mortar | 18 | 24 | Streubomben verteilen sich zu weit; −41 % | -26 % |
| m_siren | 40 | 75 | Betäuben allein trägt die Waffe nicht; −68 % | -31 % |
| m_hammer | 90 | 130 | Sprungangriff mit langer Pause; −50 % | -24 % |
| b_cement | 20 | 26 | Festhalten bleibt, Schaden zu niedrig; −42 % | -25 % |
| b_plate | 50 | 65 | −39 % | -17 % |
| b_crane | 30 | 40 | Heranziehen bleibt, Schaden zu niedrig; −49 % | -25 % |
| b_pile | 140 | 190 | −49 % | -25 % |
| a_shrink | 4 | 5 | Schwächungswaffe (+30 % Schaden für alle), trotzdem −44 % | -25 % |
| y_sling | 24 | 30 | −36 % | -22 % |
| y_swarm | 16 | 24 | fünf Pfeile verteilen sich auf viele Ziele; −43 % | -12 % |
| y_blowpipe | 26 | 40 | Gift wirkt gegen Waldgeister halb und gegen Mutanten gar nicht; −49 % | -15 % |
| y_rain | 22 | 40 | sechs Einschläge treffen selten dasselbe Ziel; −64 % | -24 % |
| g_popper | 9 | 14 | −54 % | -24 % |
| g_balloon | 22 | 28 | Verlangsamen bleibt; −40 % | -20 % |
| g_cake | 12 | 18 | Heilfläche ist der eigentliche Zweck; −66 % → −48 % (bewusst niedrig) | -48 % |
| g_battery | 18 | 30 | kleine Raketen, kleine Fläche; −58 % | -24 % |
| g_wheel | 26 | 36 | −45 % | -25 % |
| g_disco | 60 | 85 | −49 % | -17 % |
| g_finale | 30 | 55 | acht Einschläge zu weit verteilt; −60 % | -17 % |
| n_anchor | 20 | 26 | Neue Waffe, zu niedrig angesetzt; −48 % (Grenze Kampfwert 160 % beachtet) | -30 % |
| n_icebreaker | 120 | 170 | Neue Waffe, Sprungangriff wie m_hammer; −49 % | -15 % |
| m_axe | 30 | 20 | Nahkampf-Schwung trifft die ganze Gruppe; +71 % | 32 % |
| b_shovel | 28 | 22 | wie Axt; +50 % | 12 % |
| b_hammer | 48 | 42 | +36 % | 17 % |
| m_ladder | 70 | 55 | 120°-Schwung; +51 % | 26 % |
| g_umbrella | 45 | 36 | +55 % | 24 % |
| m_fireball | 26 | 20 | Brandfläche plus Explosion; +53 % | 18 % |
| m_halligan | 55 | 45 | Durchschlag 3; +44 % | 13 % |
| j_mine | 70 | 58 | +40 % | 26 % |
| b_rivet | 22 | 18 | Abpraller treffen fast immer; +48 % | 25 % |
| y_rifle | 60 | 48 | Startwaffe mit Durchschlag 4; +53 % | 27 % |
| a_plasma | 55 | 46 | +39 % | 34 % |
| g_pinata | 60 | 50 | +42 % | 11 % |
| n_squid | 3.5 | 3 | Neue Waffe; +36 % | 15 % |
| y_longbow | 170 | 75 | Aufladen mit Durchschlag 6 und Volltreffer; +153 % | 26 % |
| a_railgun | 150 | 65 | Aufladen mit Durchschlag 10; +179 % | 29 % |
| b_demolition | 160 | 100 | Explosion 4,5 m; +78 % | 26 % |
| n_tsunami | 160 | 95 | Neue Waffe, Welle 4 m; +90 % | 28 % |
| m_dragon | 50 | 30 | vier Feuerbälle mit Brandflächen; +86 % | 31 % |
| j_railgun | 150 | 120 | zweiter Durchgang; +41 % | 19 % |
| m_flame | 4 | 3.5 | +39 % | 26 % |
| g_bigrocket | 170 | 150 | zweiter Durchgang; +39 % | 25 % |
| n_whirl | 70 | 60 | Neue Waffe; +38 % | 21 % |
| j_harpoon | 75 | 66 | dritter Durchgang (Mittel hatte sich verschoben); +37 % | 20 % |

## Gift (Paket H)

Gift wirkt nicht mehr fest mit 4/s, sondern mit 5/s × Waffenstärke (Seltenheit und Stufe des Stücks) × Heldenstärke
(wie Brennen: +6 % je Heldenstufe). Gewöhnlich auf Stufe 1: 5/s; legendär Stufe 10 bei Heldenstufe 40: rund 38/s.

## Begleiter

Nur der Mini-Golem kämpft (14 Schaden/s × Stufenbonus); die übrigen Begleiter haben Tragkraft und Hilfsfähigkeiten.
Die Kennzahlen (Tragkraft und Leben auf Stufe 1 und 10, Tempo, Besonderheiten) stehen in `begleiter_kennzahlen.md`.
Ausreißer nach oben: keiner; die Spanne ist gewollt (Kaufpreis/Fundort). Keine Änderung.
