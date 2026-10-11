extends RefCounted
## Laden-Schnittstelle für Juwelen-Käufe.
##
## In dieser Ausbaustufe gibt es nur den TESTKAUF: Er schreibt die Juwelen sofort gut und kostet kein Geld.
## Er ist nur im Testbetrieb aktiv (Start aus dem Godot-Editor, Admin-Schalter oder automatische Tests).
##
## Für echte Käufe wird hier später das Bezahl-Modul des jeweiligen Ladens eingesetzt (Google Play Billing,
## Apple StoreKit). Dann ersetzt buy() den Testkauf durch: Kauf starten -> Beleg vom Laden -> Beleg auf dem
## eigenen Server prüfen -> erst danach P.add_gems(). Solange der Spielstand nur auf dem Gerät liegt, dürfen
## Juwelen nicht verkauft werden (sie ließen sich durch Ändern der Datei erschleichen).

const D = preload("res://src/data.gd")


static func test_mode() -> bool:
	return OS.is_debug_build() or G.ch("store_test") or G.selftest


static func available() -> bool:
	return test_mode()


static func note() -> String:
	if test_mode():
		return "Testbetrieb: Käufe kosten kein Geld und schreiben die Juwelen sofort gut."
	return "Käufe mit echtem Geld sind in dieser Version noch nicht eingerichtet."


## Kauft ein Paket aus D.GEM_PACKS. Rückgabe: "" bei Erfolg, sonst der Grund.
static func buy(pack_key: String) -> String:
	for p in D.GEM_PACKS:
		if String(p.key) == pack_key:
			if not test_mode():
				return "Käufe sind in dieser Version noch nicht eingerichtet."
			P.add_gems(int(p.gems), "Testkauf: %s" % String(p.name))
			return ""
	return "Unbekanntes Paket"
