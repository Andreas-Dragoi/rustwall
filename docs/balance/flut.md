# Flut-Schwierigkeit (Paket Q)

Messreihe mit dem Flut-Bot (`--autotest=flood_q`, Tempo 8) auf einer Basis, die dem **normalen Spieler (45 min/Tag)** der
Wirtschaftssimulation (`wirtschaft.md`) in dieser Woche entspricht: Bunker-Stufe, Ø Turmstufe, Heldenstufe, Mauerart und
Spielerstufe. Aufstellung der Türme wie die Testbasis (`P.debug_setup`): Ring um den Bunker, Mauerring außen.
Ziel (Kapitel 12.2): **70–85 % Siege** bei normalem Ausbau.

Neu messen: `python3 tools/flut_reihe.py --godot <Godot> --weeks 1-16 --reps 3`

## Normaler Ausbau (Simulation, 45 min/Tag)

| Woche | Bunker | Türme | Held | Mauer | Gegner | Läufe | Siege | Quote | Ø Bunker-Leben | Ø Sterne |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 5 | 2 | 6 | Stein | 130 | 3 | 3 | 100 % ▲ | 100 % | 3.0 |
| 2 | 6 | 2 | 8 | Stein | 160 | 3 | 3 | 100 % ▲ | 100 % | 3.0 |
| 3 | 7 | 2 | 10 | Metall | 190 | 3 | 3 | 100 % ▲ | 99 % | 2.3 |
| 4 | 7 | 2 | 12 | Metall | 240 | 3 | 3 | 100 % ▲ | 96 % | 2.0 |
| 5 | 8 | 2 | 13 | Metall | 290 | 3 | 3 | 100 % ▲ | 98 % | 2.0 |
| 6 | 8 | 2 | 14 | Metall | 350 | 3 | 3 | 100 % ▲ | 94 % | 2.0 |
| 7 | 8 | 2 | 15 | Metall | 430 | 3 | 3 | 100 % ▲ | 90 % | 2.0 |
| 8 | 8 | 2 | 16 | Metall | 520 | 3 | 3 | 100 % ▲ | 94 % | 2.0 |
| 9 | 9 | 2 | 17 | Metall | 640 | 3 | 3 | 100 % ▲ | 92 % | 2.0 |
| 10 | 9 | 2 | 18 | Metall | 780 | 3 | 3 | 100 % ▲ | 83 % | 2.0 |
| 11 | 9 | 2 | 19 | Metall | 950 | 3 | 3 | 100 % ▲ | 94 % | 2.0 |
| 12 | 9 | 2 | 20 | Metall | 1160 | 3 | 3 | 100 % ▲ | 70 % | 2.0 |
| 13 | 9 | 2 | 21 | Metall | 1250 | 3 | 3 | 100 % ▲ | 50 % | 1.3 |
| 14 | 10 | 3 | 22 | Metall | 1350 | 3 | 3 | 100 % ▲ | 84 % | 2.0 |
| 15 | 10 | 4 | 23 | Metall | 1460 | 3 | 3 | 100 % ▲ | 77 % | 2.0 |
| 16 | 10 | 4 | 23 | Metall | 1580 | 3 | 3 | 100 % ▲ | 56 % | 1.7 |
| **gesamt** | | | | | | 48 | 48 | **100 %** | | |

## Vorsichtiger Spieler: Held bleibt am Bunker (gleicher Ausbau)

| Woche | Bunker | Türme | Held | Mauer | Gegner | Läufe | Siege | Quote | Ø Bunker-Leben | Ø Sterne |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 5 | 2 | 6 | Stein | 130 | 2 | 2 | 100 % ▲ | 100 % | 3.0 |
| 2 | 6 | 2 | 8 | Stein | 160 | 2 | 2 | 100 % ▲ | 100 % | 3.0 |
| 3 | 7 | 2 | 10 | Metall | 190 | 2 | 2 | 100 % ▲ | 98 % | 2.0 |
| 4 | 7 | 2 | 12 | Metall | 240 | 2 | 2 | 100 % ▲ | 93 % | 2.0 |
| 5 | 8 | 2 | 13 | Metall | 290 | 2 | 2 | 100 % ▲ | 99 % | 2.5 |
| 6 | 8 | 2 | 14 | Metall | 350 | 2 | 2 | 100 % ▲ | 91 % | 2.0 |
| 7 | 8 | 2 | 15 | Metall | 430 | 2 | 2 | 100 % ▲ | 83 % | 2.0 |
| 8 | 8 | 2 | 16 | Metall | 520 | 2 | 2 | 100 % ▲ | 93 % | 2.0 |
| 9 | 9 | 2 | 17 | Metall | 640 | 2 | 2 | 100 % ▲ | 93 % | 2.0 |
| 10 | 9 | 2 | 18 | Metall | 780 | 2 | 2 | 100 % ▲ | 75 % | 2.0 |
| 11 | 9 | 2 | 19 | Metall | 950 | 2 | 2 | 100 % ▲ | 87 % | 2.0 |
| 12 | 9 | 2 | 20 | Metall | 1160 | 2 | 2 | 100 % ▲ | 57 % | 2.0 |
| 13 | 9 | 2 | 21 | Metall | 1250 | 2 | 2 | 100 % ▲ | 47 % | 1.5 |
| 14 | 10 | 3 | 22 | Metall | 1350 | 2 | 2 | 100 % ▲ | 63 % | 1.5 |
| 15 | 10 | 4 | 23 | Metall | 1460 | 2 | 2 | 100 % ▲ | 78 % | 2.0 |
| 16 | 10 | 4 | 23 | Metall | 1580 | 2 | 2 | 100 % ▲ | 55 % | 1.5 |
| **gesamt** | | | | | | 32 | 32 | **100 %** | | |

## Gelegenheitsspieler (Simulation 15 min/Tag), Held bleibt am Bunker

| Woche | Bunker | Türme | Held | Mauer | Gegner | Läufe | Siege | Quote | Ø Bunker-Leben | Ø Sterne |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 4 | 1 | 3 | Stein | 130 | 2 | 2 | 100 % ▲ | 100 % | 3.0 |
| 2 | 5 | 2 | 5 | Stein | 160 | 2 | 2 | 100 % ▲ | 100 % | 3.0 |
| 3 | 6 | 2 | 6 | Stein | 190 | 2 | 2 | 100 % ▲ | 90 % | 2.0 |
| 4 | 6 | 2 | 7 | Stein | 240 | 2 | 2 | 100 % ▲ | 80 % | 2.0 |
| 5 | 7 | 2 | 7 | Metall | 290 | 2 | 2 | 100 % ▲ | 97 % | 2.0 |
| 6 | 7 | 2 | 8 | Metall | 350 | 2 | 2 | 100 % ▲ | 87 % | 2.0 |
| 7 | 7 | 2 | 9 | Metall | 430 | 2 | 2 | 100 % ▲ | 73 % | 2.0 |
| 8 | 8 | 2 | 9 | Metall | 520 | 2 | 2 | 100 % ▲ | 89 % | 2.0 |
| 9 | 8 | 2 | 10 | Metall | 640 | 2 | 2 | 100 % ▲ | 79 % | 2.0 |
| 10 | 8 | 2 | 10 | Metall | 780 | 2 | 2 | 100 % ▲ | 68 % | 2.0 |
| 11 | 8 | 2 | 11 | Metall | 950 | 2 | 2 | 100 % ▲ | 89 % | 2.0 |
| 12 | 8 | 2 | 11 | Metall | 1160 | 2 | 2 | 100 % ▲ | 41 % | 1.5 |
| 13 | 8 | 2 | 12 | Metall | 1250 | 2 | 1 | 50 % ▼ | 4 % | 0.5 |
| 14 | 9 | 2 | 12 | Metall | 1350 | 2 | 2 | 100 % ▲ | 58 % | 2.0 |
| 15 | 9 | 2 | 13 | Metall | 1460 | 2 | 1 | 50 % ▼ | 6 % | 0.5 |
| 16 | 9 | 2 | 13 | Metall | 1580 | 2 | 0 | 0 % ▼ | 0 % | 0.0 |
| **gesamt** | | | | | | 32 | 28 | **87 %** | | |

## Normaler Ausbau, Schwierigkeit „Schwer“ (mehr und zähere Gegner), Held bleibt am Bunker

| Woche | Bunker | Türme | Held | Mauer | Gegner | Läufe | Siege | Quote | Ø Bunker-Leben | Ø Sterne |
|---|---|---|---|---|---|---|---|---|---|---|
| 2 | 6 | 2 | 8 | Stein | 160 | 2 | 2 | 100 % ▲ | 100 % | 3.0 |
| 4 | 7 | 2 | 12 | Metall | 240 | 2 | 2 | 100 % ▲ | 95 % | 2.0 |
| 6 | 8 | 2 | 14 | Metall | 350 | 2 | 2 | 100 % ▲ | 89 % | 2.0 |
| 8 | 8 | 2 | 16 | Metall | 520 | 2 | 2 | 100 % ▲ | 77 % | 2.0 |
| 10 | 9 | 2 | 18 | Metall | 780 | 2 | 2 | 100 % ▲ | 62 % | 2.0 |
| 12 | 9 | 2 | 20 | Metall | 1160 | 2 | 1 | 50 % ▼ | 23 % | 0.5 |
| 14 | 10 | 3 | 22 | Metall | 1350 | 2 | 2 | 100 % ▲ | 43 % | 1.0 |
| 16 | 10 | 4 | 23 | Metall | 1580 | 2 | 2 | 100 % ▲ | 5 % | 1.0 |
| **gesamt** | | | | | | 16 | 15 | **93 %** | | |

▲ = leichter als das Ziel, ▼ = schwerer als das Ziel.

## Auswertung

- **Kein Ausreißer:** Über die Wochen sinkt das verbliebene Bunker-Leben gleichmäßig (Woche 1–9 meist über 80 %, Woche 12–16
  um 50–80 %). Sprünge nach oben gibt es nur in Wochen, in denen der simulierte Spieler eine neue Bunker-Stufe erreicht
  (mehr Leben, Woche 14). Einzelne Wochen, die aus der Reihe fallen, gibt es nicht – deshalb wurde keine Woche einzeln verändert.
- **Insgesamt leichter als das Ziel 70–85 %:** Der normale Spieler gewinnt jede gemessene Flut, auch wenn der Held nur am
  Bunker steht. Auf „Schwer“ gewinnt er bis Woche 10 sicher, Woche 12 nur 1 von 2, Woche 16 sehr knapp (5 % Bunker-Leben). Erst der Gelegenheitsspieler (15 min/Tag, Türme meist Stufe 2,
  Bunker 8–9) verliert ab Woche 13 (Woche 13: 1 von 2, Woche 15: 1 von 2, Woche 16: 2 von 2) – das ist die gewollte
  Rückmeldung „Türme ausbauen“, und nach einer Niederlage wird die nächste Flut 15 % schwächer.
- **Warum trotzdem keine Änderung an `D.flood_def`:** Die Testbasis ist günstiger als eine echte Basis (geschlossener
  Mauerring mit der Höchstzahl an Mauern, alle Türme dicht am Bunker, keine Lücken, kein Bauen während der Flut nötig).
  Menschen bauen Lücken, vergessen Tore und reparieren nicht – deshalb darf die Bot-Messung allein die Flut nicht schwerer
  machen; sonst wird der Einstieg (Woche 1–4) für echte Anfänger unfair. Wer mehr Herausforderung will, hat „Schwer“ und
  „Albtraum“ (mehr Beute).
- **Empfehlung für den Spieltest mit Menschen (Kapitel 12.2):** Siegquote je Woche mit der Telemetrie messen (Ereignis „Flut“
  liefert Sieg, Sterne und Woche). Liegt sie bei Menschen in Woche 4–11 über 90 %, den Lebens-Zuwachs je Woche in
  `D.flood_def` von 0,12 auf 0,16 anheben (nur ab Woche 4) und mit `tools/flut_reihe.py` erneut messen.

