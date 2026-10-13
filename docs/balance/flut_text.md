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
