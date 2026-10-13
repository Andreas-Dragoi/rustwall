extends RefCounted
## Lokale Mitteilungen und Store-Bewertung (V6 Paket B, Kapitel 3.3) – eine dünne Schicht über einem Plugin.
##
## Auf Android/iOS würde ein Plugin die Mitteilungen planen (Singleton „LocalNotification“ bzw. „GodotLocalNotification“;
## erwartete Aufrufe: show(text, title, sekunden, tag) und cancel(tag) – Namen siehe PLUGINS). Im Web und am PC gibt es
## kein Plugin: dann ist die Schicht still und merkt sich die geplanten Mitteilungen nur in pending (für Tests und Anzeige).
## Geplant wird, wenn das Spiel in den Hintergrund geht oder schließt (P._notification → on_app); beim Zurückkehren
## werden alle wieder gelöscht. Einstellungen: P.d.notify {"on", "build", "flood", "gift", "research"}.
##
## Bewertung: request_review() öffnet auf dem Handy den Store-Dialog des Plugins (Singleton „StoreReview“/„GodotAppReview“),
## sonst passiert nichts. Der eigene Hinweis „Gefällt dir Rustwall?“ steht in basis_ui.gd.

const D = preload("res://src/data.gd")
const DB = preload("res://src/data_basis.gd")

const PLUGINS := ["LocalNotification", "GodotLocalNotification", "NotificationScheduler"]
const REVIEW_PLUGINS := ["StoreReview", "GodotAppReview", "InappReviewPlugin"]
const FLOOD_LEAD := 3600.0              # „Flut in 1 Stunde“

static var pending: Array = []          # [{tag, kind, title, text, at}] – zuletzt geplant
static var reviews := 0                 # (Test) wie oft der Store-Dialog angefragt wurde


static func plugin():
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return null
	for n in PLUGINS:
		if Engine.has_singleton(n):
			return Engine.get_singleton(n)
	return null


static func available() -> bool:
	return plugin() != null


## Aus P._notification: in den Hintergrund → planen, zurück → löschen.
static func on_app(what: int) -> void:
	if what == Node.NOTIFICATION_APPLICATION_PAUSED or what == Node.NOTIFICATION_WM_CLOSE_REQUEST:
		schedule_all()
	elif what == Node.NOTIFICATION_APPLICATION_RESUMED:
		cancel_all()


## Alle anstehenden Mitteilungen ausrechnen (Bau fertig, Flut in 1 h, Tagesgeschenk, Forschung) und planen.
static func plan() -> Array:
	var out: Array = []
	if P.d.is_empty() or not bool(P.d.get("notify", {}).get("on", true)):
		return out
	var now := P.now()
	var BState = preload("res://src/basis_state.gd")
	# Bau fertig: der nächste fertige Bau (Hindernisse und Mauern nicht einzeln)
	if BState.notify_on("build"):
		var best := 1.0e18
		var name := ""
		for b in P.d.buildings:
			if P.is_building(b) and not b.get("clear", false) and String(b.key) != "wall":
				var t := float(b.done_at)
				if t > now + 30.0 and t < best:
					best = t
					name = String(D.BUILDINGS[String(b.key)].name)
		if name != "":
			out.append({"tag": 701, "kind": "build", "title": DB.NOTIFY_TEXT.build[0], "text": String(DB.NOTIFY_TEXT.build[1]) % name, "at": best})
	# Flut in 1 Stunde (Fluttag beginnt)
	if BState.notify_on("flood") and not P.flood_available() and not bool(P.d.week.get("flood_done", false)):
		var start := now + P.flood_seconds_left() if P.week_day() < D.FLOOD_DAY else 0.0
		if start > now + FLOOD_LEAD + 60.0:
			out.append({"tag": 702, "kind": "flood", "title": DB.NOTIFY_TEXT.flood[0], "text": String(DB.NOTIFY_TEXT.flood[1]), "at": start - FLOOD_LEAD})
	# Tagesgeschenk am nächsten Tag
	if BState.notify_on("gift"):
		out.append({"tag": 703, "kind": "gift", "title": DB.NOTIFY_TEXT.gift[0], "text": String(DB.NOTIFY_TEXT.gift[1]), "at": now + P.seconds_to_next_day() + 600.0})
	# Forschung fertig
	if BState.notify_on("research"):
		var R = preload("res://src/research.gd")
		if R.current() != "" and R.left() > 30.0:
			out.append({"tag": 704, "kind": "research", "title": DB.NOTIFY_TEXT.research[0],
				"text": String(DB.NOTIFY_TEXT.research[1]) % String(DB.NODES[R.current()].name), "at": now + R.left()})
	return out


static func schedule_all() -> void:
	cancel_all()
	pending = plan()
	var pl = plugin()
	if pl == null:
		return                                         # Web/PC: still
	var I18N = preload("res://src/i18n.gd")
	for n in pending:
		var secs := int(maxf(1.0, float(n.at) - P.now()))
		var title := I18N.t(String(n.title))
		var text := I18N.t(String(n.text))
		if pl.has_method("show"):
			pl.call("show", text, title, secs, int(n.tag))
		elif pl.has_method("schedule"):
			pl.call("schedule", title, text, secs, int(n.tag))


static func cancel_all() -> void:
	var pl = plugin()
	if pl != null:
		for tag in [701, 702, 703, 704]:
			if pl.has_method("cancel"):
				pl.call("cancel", tag)
	pending = []


## Store-Bewertung anfragen (nur mit Plugin auf dem Handy; sonst nur gezählt).
static func request_review() -> bool:
	reviews += 1
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return false
	for n in REVIEW_PLUGINS:
		if Engine.has_singleton(n):
			var pl = Engine.get_singleton(n)
			for m in ["request_review", "requestReview", "launch"]:
				if pl.has_method(m):
					pl.call(m)
					return true
	return false
