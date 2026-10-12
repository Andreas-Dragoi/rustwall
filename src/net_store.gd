extends Node
## Laufzeit der Käufe (Paket O): spricht mit dem Laden-Plugin und lässt jeden Beleg vom Server prüfen.
##
## iOS:     Godot-Plugin "InAppStore" (godot-ios-plugins, StoreKit). Ereignisse werden abgefragt
##          (get_pending_event_count / pop_pending_event). Automatisches Abschließen ist aus: erst nach der
##          Bestätigung durch den Server wird finish_transaction() aufgerufen.
## Android: Godot-Plugin "GodotGooglePlayBilling" (Google Play Billing Library). Signale purchases_updated usw.;
##          nach der Bestätigung durch den Server consumePurchase() (Juwelen sind Verbrauchsgüter).
## Ohne Plugin: test_purchase() schickt einen Testbeleg an den Server (nur wenn der Server Testkäufe erlaubt).
##
## HINWEIS: Die Plugin-Aufrufe folgen der Dokumentation der Plugins, konnten hier aber ohne Apple-/Google-Gerät
## nicht ausprobiert werden. Vor der Veröffentlichung im TestFlight bzw. in der internen Testspur prüfen.

const D = preload("res://src/data.gd")
const PREFIX := "rustwall."              # wie Store.PRODUCT_PREFIX
const STARTER := "rustwall.starter"

var ios: Object
var gp: Object
var busy: Dictionary = {}               # Produkt -> true, solange ein Kauf läuft
var _gp_ready := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Engine.has_singleton("InAppStore"):
		ios = Engine.get_singleton("InAppStore")
		ios.set_auto_finish_transaction(false)
		var ids: Array = []
		for p in D.GEM_PACKS:
			ids.append(PREFIX + String(p.key))
		ids.append(STARTER)
		ios.request_product_info({"product_ids": ids})
	elif Engine.has_singleton("GodotGooglePlayBilling"):
		gp = Engine.get_singleton("GodotGooglePlayBilling")
		gp.connected.connect(_gp_connected)
		gp.purchases_updated.connect(_gp_purchases)
		gp.purchase_error.connect(func(code, msg): _fail("Kauf abgebrochen (%s): %s" % [str(code), str(msg)]))
		if gp.has_signal("query_purchases_response"):
			gp.query_purchases_response.connect(func(resp): _gp_purchases(resp.get("purchases", []) if resp is Dictionary else resp))
		gp.startConnection()


func _process(_dt: float) -> void:
	if ios == null:
		return
	while ios.get_pending_event_count() > 0:
		var ev: Dictionary = ios.pop_pending_event()
		var t := String(ev.get("type", ""))
		if t == "purchase" or t == "restore":
			if String(ev.get("result", "")) == "ok":
				_verify("apple", String(ev.get("product_id", "")), String(ev.get("receipt", "")), String(ev.get("transaction_id", "")), func(): ios.finish_transaction(String(ev.get("product_id", ""))))
			else:
				busy.erase(String(ev.get("product_id", "")))
				_fail("Kauf nicht abgeschlossen: %s" % String(ev.get("message", ev.get("result", ""))))


# ================================================================= Kaufen
func purchase(pid: String) -> String:
	if busy.get(pid, false):
		return "Dieser Kauf läuft schon."
	busy[pid] = true
	if ios != null:
		if ios.purchase({"product_id": pid}) != OK:
			busy.erase(pid)
			return "Der App Store ist gerade nicht erreichbar."
		return ""
	if gp != null:
		if not _gp_ready:
			busy.erase(pid)
			gp.startConnection()
			return "Google Play ist noch nicht verbunden. Bitte gleich noch einmal versuchen."
		gp.purchase(pid)
		return ""
	busy.erase(pid)
	return "Kein Laden verfügbar."


func test_purchase(pid: String) -> String:
	_verify("test", pid, "TEST", "test-%d-%d" % [Time.get_ticks_usec(), randi()], Callable())
	return ""


## Beleg vom Server prüfen lassen; erst danach gutschreiben und beim Laden abschließen.
func _verify(store: String, pid: String, receipt: String, transaction: String, finish: Callable) -> void:
	var net: Node = get_parent()
	var r: Dictionary = await net.rpc_call("rw_purchase", {"store": store, "product": pid, "receipt": receipt, "transaction": transaction})
	busy.erase(pid)
	if not r.ok:
		_fail("Kauf wird geprüft, sobald der Server erreichbar ist.")        # Beleg bleibt offen und kommt beim nächsten Start wieder
		return
	if not bool(r.data.get("ok", false)):
		_fail(String(r.data.get("why", "Kauf nicht bestätigt.")))
		if finish.is_valid():
			finish.call()               # ungültiger Beleg: trotzdem abschließen, sonst kommt er immer wieder
		return
	var added := int(r.data.get("gems_added", 0))
	if added > 0:
		net.bypass = true
		P.add_gems(added, "Kauf: %s" % pid.trim_prefix(PREFIX))
		net.bypass = false
		P.toast.emit("Danke für deinen Kauf! +%d Juwelen" % added)
	if finish.is_valid():
		finish.call()
	P.save()


func _fail(text: String) -> void:
	P.toast.emit(text)


# ================================================================= Wiederherstellen
func restore() -> void:
	if ios != null:
		ios.restore_purchases()
	elif gp != null and _gp_ready:
		gp.queryPurchases("inapp")
	var r: Dictionary = await get_parent().rpc_call("rw_restore", {})
	if r.ok:
		P.toast.emit("Käufe geprüft: %d bisherige Käufe auf diesem Konto." % r.data.get("purchases", []).size())


# ================================================================= Google Play
func _gp_connected() -> void:
	_gp_ready = true
	gp.queryPurchases("inapp")                  # offene (unterbrochene) Käufe nachholen


func _gp_purchases(list) -> void:
	if not (list is Array):
		return
	for pu in list:
		if not (pu is Dictionary):
			continue
		var ids: Array = pu.get("products", pu.get("product_ids", pu.get("skus", [])))
		var pid := String(ids[0]) if ids.size() > 0 else String(pu.get("product_id", pu.get("sku", "")))
		var token := String(pu.get("purchase_token", pu.get("purchaseToken", "")))
		if token == "" or int(pu.get("purchase_state", 1)) != 1:
			continue
		# Der Server (Nakama purchaseValidateGoogle) braucht den Original-Beleg (JSON von Google Play)
		var receipt := String(pu.get("original_json", pu.get("originalJson", token)))
		_verify("google", pid, receipt, String(pu.get("order_id", token)), func(): gp.consumePurchase(token))


# ================================================================= Anmelden mit Apple / Google
func sign_in(kind: String, single: String) -> void:
	var plugin := Engine.get_singleton(single)
	# Erwartet ein Plugin mit sign_in() und Signal "signed_in"(token) – siehe docs/APPS.md (noch nicht eingebaut).
	if plugin.has_signal("signed_in"):
		plugin.signed_in.connect(func(token: String):
			var why: String = await get_parent().link(kind, token)
			P.toast.emit(why if why != "" else "Konto verknüpft."), CONNECT_ONE_SHOT)
	if plugin.has_method("sign_in"):
		plugin.sign_in()
