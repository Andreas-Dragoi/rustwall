# Waffen-Balance – gemessener Schaden je Sekunde

Erzeugt mit `godot --headless --path . -- --autotest=dps` (src/tests_helden.gd). Jona trägt jede Waffe (gewöhnlich, Stufe 1)
auf der Heldenstufe, ab der die Waffe nutzbar ist, ohne Talente, Ausrüstung und Module. Ziele: die Masse-Art jeder Familie,
festgehalten an ihrem Platz, 4 Sekunden Messzeit (Nachladen eingerechnet). **Einzel** = ein Ziel, **Gruppe** = 6 Ziele dicht beieinander.
Schwächen und Resistenzen der Familien, Brennen, Gift, Flächen und Geschütze wirken wie im Spiel.

**Kennzahl** = (½ · Einzel-DPS + ½ · Gruppen-DPS ÷ 3) ÷ Richtwert der Stufe (D.weapon_power_ref), Mittel über alle Familien.
Verglichen wird mit dem Mittel derselben Stufen-Spanne und Klasse (Einzelziel / Fläche / Geschütz); **Ausreißer** liegen mehr als ±35 % daneben.

## Ausreißer (2)

| Waffe | Held | Stufe | Klasse | Abweichung |
|---|---|---|---|---|
| Löschkanone (m_water) | mika | 8 | Fläche | -81 % |
| Tortenheber (g_cake) | greta | 16 | Fläche | -48 % |

## Alle Waffen (Mittel über die Familien)

Spalten je Familie: Einzel-DPS. Gruppe Ø = Gruppen-DPS (alle 6 Ziele zusammen) im Mittel über die Familien.

| Waffe | Held | Stufe | Klasse | Element | Schleimlinge | Waldgeister | Wüstenmonster | Untote | Mutanten | Eiswesen | Dämonen | Magma-Wesen | Gruppe Ø | Kennzahl | Abw. |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Dienstgewehr | jona | 1 | Einzelziel | Kugeln | 63 | 56 | 17 | 56 | 56 | 56 | 56 | 56 | 106 | 0.97 | +3 % |
| Stempelpistole | jona | 3 | Einzelziel | Kugeln | 80 | 66 | 69 | 69 | 66 | 66 | 66 | 69 | 69 | 0.95 | +1 % |
| Eilbrief-Flinte | jona | 5 | Einzelziel | Kugeln | 63 | 49 | 12 | 81 | 60 | 46 | 53 | 35 | 72 | 0.72 | -24 % |
| Postbote | jona | 8 | Fläche | Explosion | 51 | 51 | 56 | 39 | 39 | 39 | 39 | 39 | 190 | 0.96 | +20 % |
| Rückschein-Bumerang | jona | 11 | Fläche | Kugeln | 43 | 36 | 36 | 36 | 36 | 36 | 36 | 36 | 134 | 0.67 | -19 % |
| Feldpost-Mörser | jona | 13 | Fläche | Explosion | 30 | 22 | 47 | 35 | 30 | 32 | 44 | 38 | 129 | 0.61 | -26 % |
| Sternbanner-Karabiner | jona | 16 | Einzelziel | Kugeln | 120 | 104 | 104 | 104 | 104 | 104 | 104 | 104 | 104 | 1.02 | -7 % |
| Rohrpost-MP | jona | 19 | Einzelziel | Kugeln | 81 | 81 | 81 | 81 | 81 | 81 | 81 | 81 | 81 | 0.74 | -33 % |
| Paketbombe | jona | 22 | Fläche | Explosion | 62 | 78 | 101 | 78 | 78 | 78 | 78 | 78 | 375 | 1.30 | +26 % |
| Signalpistole | jona | 25 | Fläche | Feuer | 81 | 129 | 53 | 86 | 86 | 130 | 0 | 0 | 281 | 0.99 | -4 % |
| Ankerharpune | jona | 28 | Fläche | Kugeln | 76 | 102 | 30 | 102 | 102 | 102 | 102 | 102 | 380 | 1.24 | +20 % |
| Störsender | jona | 31 | Fläche | Blitz | 88 | 88 | 88 | 132 | 88 | 88 | 88 | 88 | 374 | 1.18 | -14 % |
| Wachposten im Paket | jona | 34 | Geschütz | Kugeln | 222 | 208 | 208 | 208 | 208 | 208 | 208 | 208 | 208 | 1.44 | -7 % |
| Expressrakete | jona | 37 | Fläche | Explosion | 150 | 141 | 150 | 109 | 150 | 160 | 135 | 141 | 523 | 1.55 | +13 % |
| Kapitänsbüchse | jona | 40 | Fläche | Kugeln | 160 | 160 | 48 | 160 | 160 | 160 | 160 | 160 | 613 | 1.65 | +19 % |
| Brenner | mika | 1 | Fläche | Feuer | 47 | 71 | 33 | 47 | 47 | 71 | 0 | 0 | 153 | 1.01 | +26 % |
| Feuerwehraxt | mika | 3 | Einzelziel | Kugeln | 42 | 45 | 15 | 42 | 42 | 45 | 36 | 36 | 245 | 1.24 | +32 % |
| Schaumlöscher | mika | 5 | Fläche | Wasser | 39 | 39 | 39 | 39 | 39 | 39 | 51 | 62 | 166 | 0.96 | +20 % |
| Löschkanone | mika | 8 | Fläche | Wasser | 21 | 21 | 21 | 0 | 0 | 0 | 0 | 0 | 27 | 0.15 | -81 % |
| Druckschlauch | mika | 11 | Einzelziel | Wasser | 53 | 53 | 16 | 53 | 53 | 53 | 69 | 84 | 108 | 0.74 | -32 % |
| Brandflasche | mika | 13 | Fläche | Feuer | 56 | 104 | 47 | 70 | 70 | 100 | 0 | 0 | 253 | 1.10 | +33 % |
| Feuerball-Schleuder | mika | 16 | Fläche | Feuer | 54 | 99 | 38 | 67 | 66 | 93 | 0 | 0 | 244 | 0.97 | +18 % |
| Brecheisen | mika | 19 | Fläche | Kugeln | 92 | 92 | 23 | 92 | 92 | 76 | 92 | 92 | 167 | 0.93 | +13 % |
| Glutwerfer | mika | 22 | Fläche | Feuer | 47 | 87 | 40 | 67 | 67 | 93 | 0 | 0 | 244 | 0.84 | -19 % |
| Kältelöscher | mika | 25 | Fläche | Eis | 89 | 80 | 80 | 80 | 112 | 0 | 104 | 104 | 306 | 1.11 | +7 % |
| Leiterramme | mika | 28 | Einzelziel | Kugeln | 85 | 85 | 25 | 85 | 85 | 85 | 85 | 85 | 493 | 1.38 | +26 % |
| Sirenenhorn | mika | 31 | Fläche | Kugeln | 42 | 63 | 63 | 63 | 63 | 63 | 63 | 63 | 348 | 0.96 | -31 % |
| Hitzestrahler | mika | 34 | Einzelziel | Feuer | 179 | 269 | 125 | 179 | 179 | 269 | 0 | 0 | 140 | 1.01 | -7 % |
| Brandmeister-Hammer | mika | 37 | Fläche | Feuer | 106 | 160 | 57 | 106 | 106 | 160 | 0 | 0 | 379 | 1.05 | -24 % |
| Drachenschlauch | mika | 40 | Fläche | Feuer | 194 | 309 | 134 | 175 | 212 | 294 | 0 | 0 | 661 | 1.81 | +31 % |
| Nagler | bruno | 1 | Einzelziel | Kugeln | 46 | 39 | 10 | 44 | 40 | 40 | 34 | 44 | 62 | 0.65 | -31 % |
| Spaten | bruno | 3 | Einzelziel | Kugeln | 34 | 40 | 10 | 34 | 40 | 34 | 34 | 40 | 204 | 1.05 | +12 % |
| Vorschlaghammer | bruno | 5 | Einzelziel | Kugeln | 45 | 45 | 14 | 45 | 45 | 45 | 45 | 45 | 215 | 1.10 | +17 % |
| Abrissbirne | bruno | 8 | Einzelziel | Kugeln | 50 | 50 | 50 | 50 | 50 | 50 | 50 | 50 | 256 | 1.21 | +29 % |
| Nietkanone | bruno | 11 | Fläche | Kugeln | 59 | 59 | 59 | 59 | 59 | 59 | 59 | 59 | 199 | 1.04 | +25 % |
| Bohrhammer | bruno | 13 | Einzelziel | Kugeln | 89 | 89 | 89 | 89 | 89 | 89 | 89 | 89 | 170 | 1.14 | +4 % |
| Betonmischer | bruno | 16 | Fläche | Explosion | 34 | 34 | 44 | 34 | 34 | 34 | 34 | 34 | 150 | 0.62 | -25 % |
| Ziegelschleuder | bruno | 19 | Fläche | Explosion | 68 | 68 | 88 | 68 | 68 | 68 | 68 | 68 | 184 | 0.90 | +9 % |
| Baggerschaufel | bruno | 22 | Einzelziel | Kugeln | 78 | 78 | 23 | 78 | 78 | 78 | 78 | 78 | 441 | 1.40 | +27 % |
| Rüttelplatte | bruno | 25 | Fläche | Explosion | 50 | 50 | 20 | 50 | 50 | 51 | 50 | 50 | 286 | 0.86 | -17 % |
| Kranhaken | bruno | 28 | Fläche | Kugeln | 62 | 62 | 62 | 62 | 62 | 62 | 62 | 62 | 222 | 0.77 | -25 % |
| Baustellen-Geschütz | bruno | 31 | Geschütz | Explosion | 120 | 120 | 156 | 120 | 120 | 120 | 120 | 120 | 538 | 1.65 | +7 % |
| Teerkocher | bruno | 34 | Fläche | Feuer | 141 | 211 | 98 | 141 | 141 | 211 | 0 | 0 | 471 | 1.42 | +3 % |
| Rammbär | bruno | 37 | Fläche | Explosion | 93 | 93 | 36 | 93 | 93 | 93 | 93 | 93 | 376 | 1.04 | -25 % |
| Abrisskanone | bruno | 40 | Fläche | Explosion | 134 | 134 | 174 | 134 | 134 | 134 | 134 | 134 | 690 | 1.73 | +26 % |
| Funkenstab | ada | 1 | Fläche | Blitz | 30 | 28 | 28 | 41 | 28 | 28 | 28 | 28 | 96 | 0.69 | -14 % |
| Taschenzapper | ada | 3 | Fläche | Blitz | 44 | 44 | 44 | 66 | 44 | 44 | 44 | 44 | 99 | 0.83 | +3 % |
| Magnetwerfer | ada | 5 | Fläche | Kugeln | 34 | 39 | 39 | 39 | 39 | 39 | 39 | 39 | 150 | 0.86 | +8 % |
| Schrumpfstrahl | ada | 8 | Einzelziel | Blitz | 56 | 56 | 56 | 83 | 56 | 56 | 56 | 56 | 59 | 0.70 | -25 % |
| Laserstrahl | ada | 11 | Einzelziel | Blitz | 113 | 113 | 113 | 169 | 113 | 113 | 113 | 113 | 120 | 1.32 | +20 % |
| Pieps’ Cousin | ada | 13 | Geschütz | Blitz | 53 | 53 | 53 | 79 | 53 | 53 | 53 | 53 | 112 | 0.73 | +0 % |
| Wetterkanone | ada | 16 | Einzelziel | Blitz | 27 | 55 | 56 | 87 | 55 | 56 | 58 | 55 | 425 | 1.44 | +31 % |
| Teslaspule | ada | 19 | Fläche | Blitz | 59 | 43 | 43 | 64 | 43 | 43 | 43 | 43 | 245 | 0.88 | +7 % |
| Frostkanone | ada | 22 | Einzelziel | Eis | 92 | 92 | 92 | 92 | 129 | 0 | 120 | 120 | 92 | 0.79 | -28 % |
| Schwerkraftbombe | ada | 25 | Fläche | Blitz | 74 | 60 | 60 | 90 | 60 | 60 | 60 | 60 | 313 | 1.03 | -1 % |
| Gaußkanone | ada | 28 | Fläche | Blitz | 100 | 100 | 30 | 150 | 100 | 100 | 100 | 100 | 408 | 1.33 | +29 % |
| Haftmine | ada | 31 | Fläche | Blitz | 102 | 102 | 102 | 153 | 102 | 102 | 102 | 102 | 473 | 1.44 | +5 % |
| Plasmawerfer | ada | 34 | Fläche | Blitz | 197 | 197 | 67 | 295 | 197 | 197 | 197 | 197 | 498 | 1.85 | +34 % |
| Mikrodrohnen | ada | 37 | Fläche | Blitz | 140 | 108 | 62 | 153 | 106 | 148 | 96 | 77 | 299 | 1.04 | -25 % |
| Gewittermacher | ada | 40 | Einzelziel | Blitz | 128 | 128 | 128 | 192 | 128 | 128 | 128 | 128 | 395 | 1.26 | +15 % |
| Weitblick | yuki | 1 | Fläche | Kugeln | 36 | 48 | 48 | 48 | 48 | 48 | 48 | 48 | 136 | 1.02 | +27 % |
| Steinschleuder | yuki | 3 | Einzelziel | Kugeln | 55 | 55 | 55 | 55 | 55 | 55 | 47 | 55 | 51 | 0.73 | -22 % |
| Federarmbrust | yuki | 5 | Einzelziel | Kugeln | 46 | 46 | 46 | 46 | 46 | 46 | 46 | 46 | 130 | 0.87 | -8 % |
| Federbogen | yuki | 8 | Einzelziel | Kugeln | 82 | 91 | 73 | 82 | 73 | 73 | 73 | 73 | 149 | 1.14 | +21 % |
| Windspeer | yuki | 11 | Fläche | Kugeln | 76 | 76 | 23 | 76 | 76 | 76 | 76 | 76 | 192 | 1.09 | +33 % |
| Falkenbumerang | yuki | 13 | Fläche | Kugeln | 41 | 48 | 48 | 41 | 34 | 48 | 34 | 34 | 153 | 0.72 | -13 % |
| Schwarmpfeil | yuki | 16 | Fläche | Kugeln | 39 | 39 | 39 | 39 | 39 | 39 | 39 | 39 | 181 | 0.72 | -12 % |
| Giftpfeil-Blasrohr | yuki | 19 | Einzelziel | Gift | 135 | 61 | 135 | 135 | 0 | 135 | 135 | 122 | 88 | 0.93 | -15 % |
| Sturmfächer | yuki | 22 | Fläche | Kugeln | 57 | 57 | 57 | 57 | 57 | 57 | 57 | 57 | 336 | 1.08 | +5 % |
| Frostbogen | yuki | 25 | Einzelziel | Eis | 80 | 80 | 28 | 80 | 112 | 0 | 104 | 104 | 164 | 0.77 | -30 % |
| Pfeilregen | yuki | 28 | Fläche | Kugeln | 23 | 39 | 54 | 23 | 77 | 57 | 47 | 77 | 263 | 0.79 | -24 % |
| Kikos Krallen | yuki | 31 | Fläche | Kugeln | 141 | 141 | 91 | 137 | 110 | 138 | 140 | 127 | 247 | 1.14 | -17 % |
| Großer Kranichbogen | yuki | 34 | Fläche | Kugeln | 156 | 124 | 37 | 156 | 218 | 156 | 156 | 124 | 587 | 1.73 | +26 % |
| Federsterne | yuki | 37 | Fläche | Kugeln | 76 | 55 | 76 | 76 | 69 | 69 | 62 | 69 | 445 | 1.07 | -23 % |
| Wirbelsturmbogen | yuki | 40 | Fläche | Kugeln | 113 | 120 | 115 | 113 | 120 | 115 | 113 | 120 | 545 | 1.40 | +1 % |
| Kracher | greta | 1 | Fläche | Explosion | 40 | 28 | 29 | 28 | 28 | 28 | 28 | 28 | 118 | 0.77 | -4 % |
| Partyknaller | greta | 3 | Einzelziel | Explosion | 67 | 36 | 52 | 36 | 36 | 55 | 36 | 40 | 71 | 0.71 | -24 % |
| Wasserbomben | greta | 5 | Fläche | Wasser | 38 | 28 | 17 | 28 | 28 | 28 | 36 | 45 | 103 | 0.64 | -20 % |
| Wunderkerze | greta | 8 | Fläche | Explosion | 53 | 53 | 47 | 53 | 53 | 53 | 53 | 53 | 146 | 0.90 | +12 % |
| Römische Kerze | greta | 11 | Fläche | Explosion | 43 | 46 | 51 | 47 | 47 | 46 | 46 | 47 | 65 | 0.56 | -32 % |
| Piñata-Bombe | greta | 13 | Fläche | Explosion | 46 | 46 | 60 | 46 | 46 | 46 | 46 | 46 | 206 | 0.91 | +11 % |
| Tortenheber | greta | 16 | Fläche | Explosion | 22 | 23 | 30 | 23 | 23 | 23 | 23 | 23 | 104 | 0.43 | -48 % |
| Omas Regenschirm | greta | 19 | Einzelziel | Kugeln | 73 | 61 | 22 | 73 | 61 | 73 | 73 | 61 | 412 | 1.36 | +24 % |
| Raketenbatterie | greta | 22 | Fläche | Explosion | 88 | 71 | 76 | 53 | 56 | 70 | 75 | 72 | 156 | 0.78 | -24 % |
| Dampfkessel | greta | 25 | Fläche | Feuer | 105 | 157 | 73 | 105 | 105 | 157 | 0 | 0 | 346 | 1.23 | +19 % |
| Feuerrad | greta | 28 | Fläche | Feuer | 54 | 107 | 50 | 72 | 72 | 107 | 0 | 0 | 233 | 0.77 | -25 % |
| Bonbonkanone | greta | 31 | Einzelziel | Kugeln | 156 | 156 | 47 | 156 | 156 | 156 | 156 | 156 | 134 | 1.01 | -7 % |
| Neujahrsrakete | greta | 34 | Fläche | Explosion | 124 | 124 | 162 | 124 | 124 | 124 | 124 | 124 | 617 | 1.73 | +25 % |
| Diskokugel | greta | 37 | Fläche | Blitz | 77 | 77 | 77 | 115 | 77 | 77 | 77 | 77 | 451 | 1.14 | -17 % |
| Großes Finale | greta | 40 | Fläche | Explosion | 98 | 87 | 69 | 80 | 77 | 93 | 92 | 37 | 496 | 1.15 | -17 % |
| Tauchharpune | nele | 1 | Einzelziel | Kugeln | 51 | 51 | 51 | 51 | 51 | 51 | 51 | 51 | 149 | 1.12 | +19 % |
| Muschelschleuder | nele | 3 | Fläche | Kugeln | 42 | 36 | 12 | 42 | 42 | 36 | 36 | 42 | 77 | 0.64 | -20 % |
| Tintenspritze | nele | 5 | Fläche | Wasser | 39 | 39 | 12 | 39 | 39 | 39 | 51 | 62 | 163 | 0.92 | +15 % |
| Blubberkanone | nele | 8 | Fläche | Wasser | 41 | 41 | 25 | 41 | 41 | 39 | 53 | 66 | 162 | 0.87 | +9 % |
| Bootsanker | nele | 11 | Fläche | Kugeln | 23 | 31 | 31 | 31 | 31 | 31 | 31 | 31 | 120 | 0.58 | -30 % |
| Mini-Torpedo | nele | 13 | Fläche | Explosion | 65 | 65 | 35 | 65 | 68 | 67 | 68 | 67 | 217 | 1.06 | +28 % |
| Eisharpune | nele | 16 | Einzelziel | Eis | 105 | 105 | 28 | 105 | 147 | 0 | 137 | 137 | 201 | 1.18 | +8 % |
| Dreizack | nele | 19 | Fläche | Wasser | 75 | 90 | 27 | 90 | 90 | 90 | 117 | 144 | 200 | 1.07 | +29 % |
| Geysirpumpe | nele | 22 | Einzelziel | Wasser | 97 | 97 | 97 | 97 | 97 | 97 | 126 | 154 | 215 | 1.15 | +4 % |
| Frostnetz | nele | 25 | Fläche | Eis | 81 | 81 | 81 | 81 | 114 | 0 | 106 | 106 | 342 | 1.18 | +14 % |
| Strudelbombe | nele | 28 | Fläche | Wasser | 62 | 75 | 75 | 75 | 75 | 75 | 98 | 120 | 409 | 1.25 | +21 % |
| Quallenmine | nele | 31 | Fläche | Blitz | 104 | 96 | 96 | 144 | 96 | 96 | 96 | 96 | 334 | 1.16 | -16 % |
| Eisbrecher | nele | 34 | Fläche | Eis | 88 | 88 | 88 | 88 | 123 | 0 | 114 | 114 | 416 | 1.17 | -15 % |
| Krakenruf | nele | 37 | Fläche | Wasser | 157 | 172 | 126 | 136 | 155 | 132 | 150 | 232 | 477 | 1.56 | +13 % |
| Flutwelle | nele | 40 | Fläche | Wasser | 127 | 127 | 127 | 127 | 127 | 127 | 165 | 203 | 701 | 1.76 | +28 % |
