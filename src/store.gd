extends RefCounted
## Laden-Schnittstelle für Juwelen-Käufe (Paket O).
##
## Ablauf eines echten Kaufs: Kauf im Laden starten (iOS: Plugin "InAppStore" / StoreKit, Android: Plugin
## "GodotGooglePlayBilling") -> Beleg vom Laden -> Beleg auf dem eigenen Server prüfen (rw_purchase) -> erst dann
## Juwelen gutschreiben -> Kauf beim Laden abschließen (finish/consume). Die Laufzeit-Logik steckt in net_store.gd.
##
## Ohne Laden-Plugin gibt es nur den deutlich gekennzeichneten TESTKAUF (Entwickler-Fassung, Admin-Schalter
## "store_test" oder automatische Tests). Mit eingestelltem Server geht auch der Testkauf über den Server
## (er wird dort nur angenommen, wenn der Server Testkäufe erlaubt).
## Echte Käufe gibt es nur mit Server – sonst ließen sich Juwelen durch Ändern der Spielstand-Datei erschleichen.

const D = preload("res://src/data.gd")
const NetStore = preload("res://src/net_store.gd")

const PRODUCT_PREFIX := "rustwall."       # Produkt-ID im App Store / Play Store: rustwall.gems_500 usw.
const STARTER := "rustwall.starter"       # Startangebot (einmalig je Konto, siehe server/modules/regeln.json)


static func test_mode() -> bool:
	return (OS.is_debug_build() or G.ch("store_test") or G.selftest) and platform() == ""


## "apple", "google" oder "" (kein Laden-Plugin vorhanden).
static func platform() -> String:
	if Engine.has_singleton("InAppStore"):
		return "apple"
	if Engine.has_singleton("GodotGooglePlayBilling"):
		return "google"
	return ""


static func rt() -> Node:
	var net: Node = P.social.net
	var n := net.get_node_or_null("Store")
	if n == null:
		n = NetStore.new()
		n.name = "Store"
		net.add_child(n)
	return n


## Echte Käufe möglich? (Laden-Plugin da und Server verbunden)
static func real() -> bool:
	return platform() != "" and P.social.online()


static func available() -> bool:
	return test_mode() or real()


static func note() -> String:
	if real():
		return "Käufe laufen über den %s. Juwelen werden gutgeschrieben, sobald unser Server den Kauf bestätigt hat." % ("App Store" if platform() == "apple" else "Google Play Store")
	if test_mode():
		return "TESTBETRIEB: Testkäufe kosten kein Geld und sind nur zum Ausprobieren da."
	if platform() != "":
		return "Käufe sind nur mit Verbindung zum Server möglich."
	return "Käufe mit echtem Geld sind in dieser Version nicht eingerichtet."


static func product_id(pack_key: String) -> String:
	return PRODUCT_PREFIX + pack_key


## Text für die Kaufbestätigung (mit Hinweis für Kinder und zum Widerrufsrecht).
static func confirm_text(pack: Dictionary) -> String:
	var t := "%s Juwelen (%s) für %s kaufen?" % [String(pack.name), str(int(pack.gems)), String(pack.price) if not test_mode() else "0 € (Testkauf)"]
	if P.social.net.child_mode():
		t += "\n\nBitte nur kaufen, wenn deine Eltern es erlaubt haben!"
	else:
		t += "\n\nJuwelen sind Spielgeld ohne Geldwert. Mit dem Kauf beginnt die Lieferung sofort; dein Widerrufsrecht erlischt damit."
	return t


## Kauft ein Paket aus D.GEM_PACKS. Rückgabe: "" = erledigt bzw. gestartet (siehe pending_text()), sonst der Grund.
static func buy(pack_key: String) -> String:
	for p in D.GEM_PACKS:
		if String(p.key) == pack_key:
			if real():
				return rt().purchase(product_id(pack_key))
			if not test_mode():
				return note()
			if P.social.server_set():
				return rt().test_purchase(product_id(pack_key))
			P.add_gems(int(p.gems), "Testkauf: %s" % String(p.name))
			return ""
	return "Unbekanntes Paket"


## Läuft der Kauf im Hintergrund (Juwelen kommen erst nach Bestätigung)?
static func is_async() -> bool:
	return real() or (test_mode() and P.social.server_set())


## Unterbrochene Käufe erneut prüfen und Kaufverlauf vom Server holen.
static func restore() -> String:
	if not P.social.online():
		return "Zum Wiederherstellen muss eine Verbindung zum Server bestehen."
	rt().restore()
	return ""


## "Mit Apple/Google anmelden": braucht ein Anmelde-Plugin, das ein Token liefert (siehe docs/APPS.md).
static func sign_in(kind: String) -> String:
	if not P.social.online():
		return "Dafür muss eine Verbindung zum Server bestehen."
	var single := "AppleSignIn" if kind == "apple" else "GodotGoogleSignIn"
	if not Engine.has_singleton(single):
		return "Die Anmeldung mit %s ist in dieser Fassung noch nicht eingebaut (Plugin fehlt, siehe docs/APPS.md). Nimm solange die E-Mail." % ("Apple" if kind == "apple" else "Google")
	rt().sign_in(kind, single)
	return ""
