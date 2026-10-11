"""Rustwall – Gebäude nach dem Detail-Katalog (Auftrag V3, Paket 6, Teil 1): Bunker, Produktion, Lager, besondere Gebäude.
Aufruf: python3 blender/geb.py [namen...]   (ohne Namen: alle bauen)
Umgebungsvariablen: GEB_SHOTS=<ordner> rendert Prüfbilder (vier Richtungen + Spielsicht, Ausbau- und Schadensstufen),
GEB_NOICON=1 lässt das Symbol aus, GEB_NOAO=1 die Verschattung (schneller Probelauf)."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
MODELS = {}
for _m in ("geb_bunker", "geb_prod", "geb_special"):
    try:
        MODELS.update(__import__(_m).MODELS)
    except ModuleNotFoundError as e:
        if _m not in str(e):
            raise

if __name__ == "__main__":
    for n in (sys.argv[1:] or list(MODELS)):
        MODELS[n]()
