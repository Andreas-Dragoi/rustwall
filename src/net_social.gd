extends RefCounted
## Server-Umsetzung der Mitspieler-Funktionen aus social.gd (Paket O).
##
## social.gd ruft diese Funktionen auf, sobald ein Server verbunden ist – mit denselben Namen und Rückgabewerten
## wie die simulierte Fassung. Die Daten vom Server werden in dieselben Felder geschrieben (s.friends, s.mail,
## s.clan, s.request, s.shouts), die die Bildschirme schon lesen. Deshalb musste kein Bildschirm umgebaut werden.
##
## Anfragen laufen im Hintergrund: Aktionen werden sofort angezeigt (z. B. Rohstoffe abgezogen) und, falls der
## Server ablehnt, rückgängig gemacht und mit einer Meldung erklärt. Gutschriften (Post, Spenden) kommen erst nach
## Bestätigung durch den Server.

const D = preload("res://src/data.gd")

var soc: RefCounted                   # social.gd
var net: Node
var search: Dictionary = {}           # Suchtext -> Ergebnisse
var suggest: Array = []
var clans: Array = []
var boards: Dictionary = {}           # Art -> Einträge
var times: Dictionary = {}            # Gebiet -> Bestzeiten
var meta: Dictionary = {"sends_left": D.SEND_PER_DAY, "helps_left": 5, "giftbox_left": 1, "item_left": 1}
var _busy: Dictionary = {}
var _last_sig := ""


func _init(social: RefCounted, n: Node) -> void:
	soc = social
	net = n


func p() -> Node:
	return soc.p


func s() -> Dictionary:
	return soc.s


# ================================================================= Laden
## Alles neu laden (alle 60 s und beim Verbinden).
func refresh() -> void:
	await load_friends()
	await load_mail()
	await load_clan()
	_notify()


func _notify() -> void:
	var sig := str(JSON.stringify([s().friends, s().mail, s().clan, s().request, s().shouts, clans, boards, search, suggest]).hash())
	if sig == _last_sig:
		return
	_last_sig = sig
	net.social_updated.emit()
	if G.main != null and G.main.get("screens") != null:
		var sc = G.main.screens
		if sc.is_open() and sc.screen in ["social", "clan"]:
			sc.refresh()
	net.quiet = true                    # nur Anzeige auffrischen (Post-Zähler im HUD), kein neuer Upload
	p().changed.emit()
	net.quiet = false


func _once(key: String) -> bool:
	if _busy.get(key, false):
		return false
	_busy[key] = true
	return true


func _done(key: String) -> void:
	_busy.erase(key)


func load_friends() -> void:
	if not _once("friends"):
		return
	var r: Dictionary = await net.rpc_call("rw_friends", {})
	_done("friends")
	if not r.ok:
		return
	var out: Array = []
	for f in r.data.get("friends", []):
		out.append({"code": String(f.code), "name": String(f.name), "bunker_name": String(f.bunker_name), "level": int(f.level), "bunker": int(f.bunker),
			"since": int(f.since), "online": bool(f.get("online", false)), "score": int(f.get("score", 0)), "seed": 0})
	s().friends = out
	for k in ["sends_left", "helps_left", "giftbox_left", "item_left"]:
		meta[k] = int(r.data.get(k, meta[k]))


func load_mail() -> void:
	if not _once("mail"):
		return
	var r: Dictionary = await net.rpc_call("rw_mail", {})
	_done("mail")
	if not r.ok:
		return
	var out: Array = []
	for m in r.data.get("mail", []):
		out.append(_mail_entry(m))
	s().mail = out


func _mail_entry(m: Dictionary) -> Dictionary:
	var res: Dictionary = {}
	for k in m.get("res", {}):
		res[String(k)] = int(m.res[k])
	var text := String(m.get("text", ""))
	var kind := String(m.get("kind", ""))
	if kind in ["send", "donate"] and res.size() == 1:
		var r: String = res.keys()[0]
		text = "%s %d %s" % ["schickt dir" if kind == "send" else "spendet", int(res[r]), D.RES_NAME.get(r, r)]
	return {"id": int(m.id), "from": String(m.get("from", "")), "from_code": String(m.get("from_code", "")), "text": text, "res": res,
		"chest": String(m.get("chest", "")), "item": m.get("item", {}), "expire": float(m.get("expire", 0.0)), "kind": kind}


func load_clan() -> void:
	if not _once("clan"):
		return
	var r: Dictionary = await net.rpc_call("rw_clan_get", {})
	_done("clan")
	if not r.ok:
		return
	_apply_clan(r.data.get("clan", {}))


func _apply_clan(c: Dictionary) -> void:
	if c.is_empty():
		s().clan = {}
		s().request = {}
		s().shouts = []
		return
	var members: Array = []
	var my_points := 0
	for m in c.get("members", []):
		if bool(m.get("me", false)):
			my_points = int(m.points)
			continue
		members.append({"name": String(m.name), "code": String(m.get("code", "")), "level": int(m.level), "points": int(m.points),
			"role": String(m.role), "online": bool(m.get("online", false))})
	var asks: Array = []
	for a in c.get("asks", []):
		asks.append({"id": String(a.id), "name": String(a.name), "res": String(a.res), "amount": int(a.amount) - int(a.get("filled", 0))})
	s().clan = {"id": String(c.id), "name": String(c.name), "level": int(c.level), "own": String(c.get("my_role", "")) == "Anführer",
		"my_role": String(c.get("my_role", "Mitglied")), "members": members, "my_points": my_points, "chest_week": _week_local(int(c.get("chest_week", -1))),
		"asks": asks, "color": int(c.get("color", 0))}
	var rq: Dictionary = c.get("request", {})
	s().request = {} if rq.is_empty() else {"res": String(rq.res), "amount": int(rq.amount), "filled": int(rq.filled), "at": float(rq.at)}
	var sh: Array = []
	for x in c.get("shouts", []):
		sh.append({"who": String(x.who), "code": String(x.get("code", "")), "text": String(x.text), "t": float(x.t)})
	s().shouts = sh


## Die Clan-Ansicht vergleicht chest_week mit soc.abs_week(); Serverwoche (ab Montag) auf die örtliche umrechnen.
func _week_local(server_week: int) -> int:
	if server_week < 0:
		return -1
	return soc.abs_week() if server_week == int(floor((floor(p().now() / 86400.0) + 3) / 7.0)) else server_week


func load_clans() -> void:
	if not _once("clans"):
		return
	var r: Dictionary = await net.rpc_call("rw_clan_list", {})
	_done("clans")
	if r.ok:
		var out: Array = []
		for c in r.data.get("clans", []):
			out.append({"id": String(c.id), "name": String(c.name), "level": int(c.level), "members": int(c.members), "min_level": int(c.min_level), "seed": 0})
		clans = out
		_notify()


func load_board(kind: String) -> void:
	if not _once("board_" + kind):
		return
	var r: Dictionary = await net.rpc_call("rw_board", {"board": kind})
	_done("board_" + kind)
	if r.ok:
		var out: Array = []
		for e in r.data.get("entries", []):
			out.append({"name": String(e.name), "score": int(e.score), "me": bool(e.me)})
		boards[kind] = {"t": p().now(), "rows": out}
		s().league = int(r.data.get("league", s().league))
		_notify()


func load_suggest() -> void:
	if not _once("suggest"):
		return
	var r: Dictionary = await net.rpc_call("rw_suggest", {})
	_done("suggest")
	if r.ok:
		suggest = r.data.get("results", [])
		_notify()


# ================================================================= Post
func mail_claim(id: int) -> bool:
	return mail_claim_ids([id]) > 0


func mail_claim_all() -> int:
	var ids: Array = []
	for m in s().mail:
		ids.append(int(m.id))
	return mail_claim_ids(ids)


## Nimmt die Post sofort aus der Liste; gutgeschrieben wird, was der Server bestätigt.
func mail_claim_ids(ids: Array) -> int:
	var n := 0
	for i in range(s().mail.size() - 1, -1, -1):
		if int(s().mail[i].id) in ids:
			s().mail.remove_at(i)
			n += 1
	if n > 0:
		_claim(ids)
	return n


func _claim(ids: Array) -> void:
	var r: Dictionary = await net.rpc_call("rw_mail_claim", {"ids": ids})
	if not r.ok:
		p().toast.emit("Post konnte nicht abgeholt werden: %s" % r.why)
		load_mail()
		return
	net.bypass = true
	for m in r.data.get("claimed", []):
		for k in m.get("res", {}):
			p().add(String(k), float(m.res[k]))
		if String(m.get("chest", "")) != "":
			p().add_chest(String(m.chest))
		var it: Dictionary = m.get("item", {})
		if not it.is_empty() and it.has("slot"):
			p().make_item(String(it.slot), String(it.get("key", "")), int(it.get("rarity", 0)))
	net.bypass = false
	p().resources_changed.emit()
	p().mark()


# ================================================================= Freunde
func add_friend(code: String) -> String:
	code = code.strip_edges().to_upper()
	if code.length() != 8:
		return "Ein Freundescode hat acht Zeichen."
	if code == soc.friend_code():
		return "Das ist dein eigener Code."
	for f in s().friends:
		if f.code == code:
			return "Ihr seid schon befreundet."
	_add_friend(code)
	return ""


func _add_friend(code: String) -> void:
	var r: Dictionary = await net.rpc_call("rw_friend_add", {"code": code})
	if not r.ok or not bool(r.data.get("ok", false)):
		p().toast.emit(String(r.data.get("why", r.why)) if r.ok else "Freund hinzufügen fehlgeschlagen: %s" % r.why)
		return
	await load_friends()
	_notify()


func remove_friend(code: String) -> void:
	for i in s().friends.size():
		if s().friends[i].code == code:
			s().friends.remove_at(i)
			break
	net.rpc_call("rw_friend_remove", {"code": code})
	p().mark()


func find_bases(query: String) -> Array:
	var q := query.strip_edges().to_lower()
	if q.length() < 2:
		return []
	if search.has(q):
		return search[q]
	_find(q)
	return []


func _find(q: String) -> void:
	if not _once("find"):
		return
	var r: Dictionary = await net.rpc_call("rw_find", {"query": q})
	_done("find")
	if r.ok:
		search[q] = r.data.get("results", [])
		while search.size() > 20:
			search.erase(search.keys()[0])
		_notify()


func suggestions() -> Array:
	if suggest.is_empty():
		load_suggest()
	var out: Array = []
	for e in suggest:
		var known := false
		for f in s().friends:
			if f.code == e.code:
				known = true
		if not known:
			out.append(e)
	return out


## Schickt im Hintergrund; lehnt der Server ab, wird die Zahlung erstattet.
func send(target_code: String, kind: String, extra: Dictionary, refund: Dictionary) -> void:
	var body := {"to": target_code, "kind": kind}
	body.merge(extra)
	var r: Dictionary = await net.rpc_call("rw_send", body)
	var ok: bool = r.ok and bool(r.data.get("ok", false))
	if not ok:
		for k in refund:
			p().add(String(k), float(refund[k]))
		p().toast.emit(String(r.data.get("why", "")) if r.ok else "Nicht verschickt: %s" % r.why)
		load_friends()


func code_of(target_name: String) -> String:
	for f in s().friends:
		if String(f.name) == target_name or String(f.get("bunker_name", "")) == target_name:
			return String(f.code)
	return ""


func send_resource(target_name: String, r: String) -> String:
	if not r in D.SENDABLE:
		return "Das lässt sich nicht verschicken."
	if int(meta.sends_left) <= 0:
		return "Heute sind alle fünf Sendungen verbraucht."
	var amt: int = soc.send_amount(r)
	if amt <= 0:
		return "Davon hast du zu wenig."
	var code := code_of(target_name)
	if code == "":
		return "Ihr seid nicht befreundet."
	meta.sends_left = int(meta.sends_left) - 1
	p().pay({r: amt})
	p().add_xp(8)
	send(code, "res", {"res": r, "amount": amt}, {r: amt})
	p().mark()
	return ""


func send_giftbox(target_name: String) -> bool:
	if int(meta.giftbox_left) <= 0:
		return false
	var code := code_of(target_name)
	if code == "":
		return false
	meta.giftbox_left = 0
	p().add_xp(10)
	send(code, "giftbox", {}, {})
	return true


func help_friend(f: Dictionary) -> bool:
	if int(meta.helps_left) <= 0:
		return false
	meta.helps_left = int(meta.helps_left) - 1
	p().add_xp(6)
	p().add("coins", 15)
	send(String(f.code), "help", {}, {})
	p().mark()
	return true


func send_item(f: Dictionary, item_id: int) -> String:
	var it: Dictionary = p().item(item_id)
	if it.is_empty() or int(it.rarity) > 1:
		return "Nur gewöhnliche und seltene Stücke lassen sich verschicken."
	if p().equipped_by(item_id) != "":
		return "Das Stück ist ausgerüstet."
	if int(meta.item_left) <= 0:
		return "Heute wurde schon ein Stück verschickt."
	p().d.items.erase(it)
	meta.item_left = 0
	_send_item(String(f.code), it)
	p().mark()
	return ""


func _send_item(code: String, it: Dictionary) -> void:
	var r: Dictionary = await net.rpc_call("rw_send", {"to": code, "kind": "item", "item": it})
	if not (r.ok and bool(r.data.get("ok", false))):
		p().d.items.append(it)          # zurück ins Inventar
		p().toast.emit(String(r.data.get("why", "")) if r.ok else "Nicht verschickt: %s" % r.why)
		p().mark()


# ================================================================= Clan
func clan_list() -> Array:
	if clans.is_empty():
		load_clans()
	return clans


func join_clan(entry: Dictionary) -> String:
	if int(p().d.level) < D.CLAN_MIN_LEVEL:
		return "Clans gibt es ab Spielerstufe %d." % D.CLAN_MIN_LEVEL
	if int(p().d.level) < int(entry.min_level):
		return "Dieser Clan nimmt ab Stufe %d auf." % int(entry.min_level)
	_clan_action("rw_clan_join", {"id": entry.get("id", "")}, {})
	return ""


func create_clan(clan_name: String) -> String:
	clan_name = clan_name.strip_edges()
	if int(p().d.level) < D.CLAN_MIN_LEVEL:
		return "Clans gibt es ab Spielerstufe %d." % D.CLAN_MIN_LEVEL
	if clan_name.length() < 3 or clan_name.length() > 16:
		return "Der Name braucht 3 bis 16 Zeichen."
	if not p().pay({"coins": 500}):
		return "Gründen kostet 500 Münzen."
	_clan_action("rw_clan_create", {"name": clan_name}, {"coins": 500})
	return ""


func _clan_action(fn: String, body: Dictionary, refund: Dictionary) -> void:
	var r: Dictionary = await net.rpc_call(fn, body)
	if r.ok and bool(r.data.get("ok", false)):
		if r.data.has("clan"):
			_apply_clan(r.data.clan)
		else:
			await load_clan()
	else:
		for k in refund:
			p().add(String(k), float(refund[k]))
		p().toast.emit(String(r.data.get("why", "")) if r.ok else "Clan: %s" % r.why)
	_notify()


func leave_clan() -> void:
	s().clan = {}
	s().request = {}
	s().shouts = []
	net.rpc_call("rw_clan_leave", {})
	clans = []
	p().mark()


func donate(index: int) -> String:
	if not soc.has_clan() or index >= s().clan.asks.size():
		return "?"
	var a: Dictionary = s().clan.asks[index]
	var amt := mini(int(a.amount), p().res(String(a.res)))
	if amt <= 0:
		return "Davon hast du nichts."
	p().pay({a.res: amt})
	s().clan.asks.remove_at(index)
	s().clan.my_points = int(s().clan.my_points) + int(amt / 4) + 5
	p().add_xp(10 + int(amt / 10))
	p().quest_progress("donate", 1)
	_donate(String(a.get("id", "")), amt, {a.res: amt})
	p().mark()
	return ""


func _donate(ask_id: String, amt: int, refund: Dictionary) -> void:
	var r: Dictionary = await net.rpc_call("rw_clan_donate", {"ask": ask_id, "amount": amt})
	if not (r.ok and bool(r.data.get("ok", false))):
		for k in refund:
			p().add(String(k), float(refund[k]))
		p().toast.emit(String(r.data.get("why", "")) if r.ok else "Spende nicht angekommen: %s" % r.why)
	await load_clan()
	_notify()


func can_request() -> bool:
	return soc.has_clan() and (s().request.is_empty() or p().now() - float(s().request.get("at", 0.0)) > 8 * 3600.0)


func request(r: String) -> bool:
	if not can_request():
		return false
	var amount: int = 80 + 20 * p().bunker_level()
	s().request = {"res": r, "amount": amount, "filled": 0, "at": p().now()}
	_clan_action("rw_clan_request", {"res": r, "amount": amount}, {})
	p().mark()
	return true


func shout_text(text: String) -> void:
	if not soc.has_clan():
		return
	s().shouts.append({"who": String(p().d.name), "text": text, "t": p().now()})
	_chat(text)


func _chat(text: String) -> void:
	var r: Dictionary = await net.rpc_call("rw_clan_chat", {"text": text})
	if r.ok and not bool(r.data.get("ok", false)):
		p().toast.emit(String(r.data.get("why", "")))
	await load_clan()
	_notify()


# ================================================================= Ranglisten
func add_points(board: String, n: int) -> void:
	net.rpc_call("rw_score", {"board": board, "add": n})


func add_clan_points(n: int) -> void:
	if soc.has_clan():
		s().clan.my_points = int(s().clan.my_points) + n
	net.rpc_call("rw_score", {"clan": n})


func submit_time(area: int, t: float) -> void:
	net.rpc_call("rw_score", {"area": area, "time": t})


func board(kind: String) -> Array:
	var b: Dictionary = boards.get(kind, {})
	if b.is_empty() or p().now() - float(b.t) > 60.0:
		load_board(kind)
	return b.get("rows", [])


func best_times(area: int) -> Array:
	var b: Dictionary = boards.get("time%d" % area, {})
	if b.is_empty() or p().now() - float(b.t) > 120.0:
		_load_times(area)
	var out: Array = []
	for e in b.get("rows", []):
		out.append({"name": e.name, "score": float(e.score), "me": e.me})
	return out


func _load_times(area: int) -> void:
	var key := "time%d" % area
	if not _once(key):
		return
	var r: Dictionary = await net.rpc_call("rw_board", {"board": "time", "area": area})
	_done(key)
	if r.ok:
		var out: Array = []
		for e in r.data.get("entries", []):
			out.append({"name": String(e.name), "score": float(e.score), "me": bool(e.me)})
		boards[key] = {"t": p().now(), "rows": out}


# ================================================================= Moderation
## Bunker melden (Grund z. B. "Name", "Chat", "Sonstiges"); auf Wunsch zugleich sperren.
func report(code: String, reason: String, block_too: bool) -> void:
	await net.rpc_call("rw_report", {"code": code, "reason": reason})
	if block_too:
		await net.rpc_call("rw_block", {"code": code})
		for i in range(s().friends.size() - 1, -1, -1):
			if s().friends[i].code == code:
				s().friends.remove_at(i)
	p().toast.emit("Danke! Die Meldung wird geprüft.")
	_notify()


func report_clan(clan_id: String, reason: String) -> void:
	await net.rpc_call("rw_report", {"clan": clan_id, "reason": reason})
	p().toast.emit("Danke! Die Meldung wird geprüft.")
