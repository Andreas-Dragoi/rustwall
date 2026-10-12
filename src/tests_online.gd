extends RefCounted
## Prüfungen für Paket O (Online, Konto, Käufe, Recht) gegen den Testserver server/mock_server.py.
## Aufruf aus tests.gd (--selftest) oder allein mit --autotest=online.
## Startet den Testserver selbst (python3). Fehlt Python, werden die Server-Prüfungen übersprungen (mit Hinweis);
## die Prüfungen ohne Server (Konfliktregel, Rechtstexte, Einwilligung, Sentry-Format) laufen immer.

const D = preload("res://src/data.gd")
const NetNode = preload("res://src/net.gd")
const Store = preload("res://src/store.gd")
const Legal = preload("res://src/legal_texts.gd")
const NetTel = preload("res://src/net_telemetry.gd")
const PORT := 7593

var T: Node
var net: Node
var base := "http://127.0.0.1:%d" % PORT
var pid := -1
var b_tok := ""                       # Sitzung des zweiten Spielers (Gerät B)
var b_code := ""


func _init(tests: Node) -> void:
	T = tests


func run() -> void:
	P.new_game()
	P.no_save = true
	P.social.s = P.d.social
	P.social.ensure()
	net = P.social.net
	_offline()
	if not await _start_server():
		print("HINWEIS: Online-Prüfungen übersprungen – python3 fehlt oder der Testserver startet nicht.")
		return
	var keep: Dictionary = net.cfg.duplicate()
	await _account()
	await _time()
	await _save()
	await _conflict()
	await _friends_mail()
	await _clan()
	await _boards()
	await _rewards()
	await _purchase()
	await _telemetry()
	await _moderation()
	await _delete()
	# aufräumen: Gerät wieder ohne Server
	net.cfg = keep
	net.cfg.url = ""
	net.status = "aus"
	P.server_offset = 0.0
	OS.kill(pid)
	P.new_game()
	P.no_save = true
	P.social.s = P.d.social
	P.social.ensure()


# ================================================================= ohne Server
func _offline() -> void:
	T._check(not net.enabled() and not P.social.online(), "ohne Server-Adresse: simuliert wie bisher")
	var g0 := P.gems()
	P.add_gems(5, "Test")
	T._check(P.gems() == g0 + 5, "ohne Server: Juwelen sofort gutgeschrieben")
	# Konfliktregel
	var a := {"level": 10, "bunker": 3, "server_time": 2000.0}
	T._check(NetNode.decide(a, {"level": 10, "bunker": 3, "server_time": 1000.0}) == "local", "Konflikt: neuerer lokaler Stand gewinnt")
	T._check(NetNode.decide(a, {"level": 11, "bunker": 3, "server_time": 3000.0}) == "remote", "Konflikt: neuerer Server-Stand gewinnt")
	T._check(NetNode.decide(a, {"level": 13, "bunker": 3, "server_time": 3000.0}) == "ask", "Konflikt: großer Unterschied -> Rückfrage")
	T._check(NetNode.decide(a, {"level": 10, "bunker": 4, "server_time": 1.0}) == "ask", "Konflikt: andere Bunkerstufe -> Rückfrage")
	# Rechtstexte und Lizenzen
	for k in Legal.ORDER:
		T._check(String(Legal.DOCS[k].text).length() > 300 and String(Legal.DOCS[k].text).contains("ENTWURF"), "Rechtstext %s vorhanden und als Entwurf markiert" % k)
	T._check(String(Legal.DOCS.datenschutz.text).contains("Konto löschen"), "Datenschutz nennt Konto löschen")
	T._check(Legal.FONT_LICENSE.contains("Open Font License") and Engine.get_license_text().contains("Permission is hereby granted"), "Lizenztexte Godot und Schrift")
	# Einwilligung: ohne Einwilligung wird nichts gesammelt
	net.cfg.consent = 0
	var n0: int = net.tel.queue.size()
	net.tel.track("test", {})
	T._check(net.tel.queue.size() == n0, "ohne Einwilligung keine Telemetrie")
	net.set_consent(true, true, "u16")
	net.tel.track("test", {})
	T._check(net.tel.queue.size() == n0 and not net.consent_crash(), "unter 16: keine Telemetrie, keine Fehlerberichte")
	net.set_consent(false, false, "16+")
	# Sentry-Format
	var dsn := NetTel.parse_dsn("https://abc123@o1.ingest.sentry.io/4507")
	T._check(dsn.get("url", "") == "https://o1.ingest.sentry.io/api/4507/store/" and dsn.get("key", "") == "abc123", "Sentry-DSN wird gelesen")
	var ev: Dictionary = net.tel.sentry_event({"type": "Skriptfehler", "code": "X", "text": "kaputt", "file": "res://a.gd", "line": 3, "frames": []})
	T._check(String(ev.event_id).length() == 32 and ev.exception.values[0].stacktrace.frames.size() == 1, "Fehlerbericht im Sentry-Format")
	# Laden ohne Plugin: Testkauf deutlich gekennzeichnet
	T._check(Store.platform() == "" and Store.test_mode() and Store.note().contains("TEST"), "ohne Laden-Plugin: Testkauf gekennzeichnet")
	T._check(Store.confirm_text(D.GEM_PACKS[0]).contains("Widerrufsrecht"), "Kaufbestätigung mit Hinweis")
	net.cfg.age = "u16"
	T._check(Store.confirm_text(D.GEM_PACKS[0]).contains("Eltern"), "Kaufbestätigung: Hinweis für Kinder")
	net.cfg.age = "16+"
	T._check(String(net.device_id()).begins_with("rw-") and String(net.device_id()).length() == 35, "zufällige Geräte-Kennung")


# ================================================================= Testserver
func _start_server() -> bool:
	var script := ProjectSettings.globalize_path("res://server/mock_server.py")
	if not FileAccess.file_exists("res://server/mock_server.py"):
		return false
	for exe in ["python3", "python"]:
		pid = OS.create_process(exe, [script, "--port", str(PORT), "--allow-test-purchases", "--quit-after", "900"])
		if pid > 0:
			break
	if pid <= 0:
		return false
	for i in 80:
		await T.get_tree().create_timer(0.1, true, false, true).timeout
		var r := await _req(HTTPClient.METHOD_GET, "/healthcheck", null, "")
		if r.ok:
			return true
	return false


## Anfrage an den Testserver ohne net.gd (für Gerät B und /mock/…).
func _req(method: int, path: String, body, auth: String) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 5.0
	T.add_child(req)
	var h := PackedStringArray(["Content-Type: application/json"])
	if auth == "basic":
		h.append("Authorization: Basic " + Marshalls.utf8_to_base64("defaultkey:"))
	elif auth != "":
		h.append("Authorization: Bearer " + auth)
	if req.request(base + path, h, method, "" if body == null else JSON.stringify(body)) != OK:
		req.queue_free()
		return {"ok": false, "data": {}}
	var res: Array = await req.request_completed
	req.queue_free()
	var v = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8()) if (res[3] as PackedByteArray).size() > 0 else {}
	return {"ok": int(res[0]) == 0 and int(res[1]) < 300, "data": v if v is Dictionary else {}}


func _b(fn: String, payload: Dictionary) -> Dictionary:
	payload["city"] = 1
	var r := await _req(HTTPClient.METHOD_POST, "/v2/rpc/" + fn, JSON.stringify(payload), b_tok)
	var pl = JSON.parse_string(String(r.data.get("payload", "{}")))
	return pl if pl is Dictionary else {}


func _state() -> Dictionary:
	return (await _req(HTTPClient.METHOD_GET, "/mock/state", null, "")).data


func _until(cond: Callable, secs := 10.0) -> bool:
	for i in int(secs / 0.05):
		if cond.call():
			return true
		await T.get_tree().create_timer(0.05, true, false, true).timeout
	return cond.call()


# ================================================================= Konto
func _account() -> void:
	P.d.bunker_name = "Testburg"
	P.d.level = 10
	T._check(net.set_server(base) == "", "Server-Adresse übernommen")
	await _until(func(): return net.online())
	T._check(net.online() and P.social.online(), "verbunden (Status %s: %s)" % [net.status, net.status_text])
	T._check(String(net.user_id).length() > 10 and NetNode.token_exp(String(net.cfg.token)) > Time.get_unix_time_from_system(), "anonymes Konto mit gültiger Sitzung")
	T._check(net.bunker_ok, "Bunkername auf dem Server reserviert")
	T._check(String(P.social.friend_code()).length() == 8, "Freundescode vom Server")
	# Gerät B
	var r := await _req(HTTPClient.METHOD_POST, "/v2/account/authenticate/device?create=true", {"id": "rw-testgeraet-b-0000000001"}, "basic")
	b_tok = String(r.data.get("token", ""))
	var h := await _b("rw_hello", {"bunker_name": "Testburg", "name": "Bea", "level": 12})
	T._check(not bool(h.get("bunker", {}).get("ok", true)), "Bunkername ist weltweit eindeutig")
	h = await _b("rw_hello", {"bunker_name": "Beafeste", "name": "Bea", "level": 12})
	b_code = String(h.get("code", ""))
	T._check(b_code.length() == 8 and bool(h.bunker.ok), "zweiter Spieler angemeldet")
	var bad := await _b("rw_rename", {"bunker_name": "Arschburg"})
	T._check(not bool(bad.get("ok", true)), "Wortfilter sperrt anstößigen Bunkernamen")
	# E-Mail verknüpfen
	var why: String = await net.link("email", "test@example.org", "geheim12345")
	T._check(why == "" and net.linked("email"), "Konto mit E-Mail verknüpft (%s)" % why)


func _time() -> void:
	await _req(HTTPClient.METHOD_POST, "/mock/time", {"offset": 3600.0}, "")
	await net.sync_time()
	T._check(absf(P.server_offset - 3600.0) < 30.0, "Serverzeit übernommen (Abweichung %.0f s)" % P.server_offset)
	T._check(absf(P.now() - Time.get_unix_time_from_system() - float(P.d.get("time_offset", 0.0)) - 3600.0) < 30.0, "P.now() nutzt die Serverzeit")
	await _req(HTTPClient.METHOD_POST, "/mock/time", {"offset": 0.0}, "")
	await net.sync_time()
	T._check(absf(P.server_offset) < 30.0, "Serverzeit zurück")


func _save() -> void:
	net._dirty = true
	await net.upload()
	var rev1 := int(P.d.rev)
	T._check(rev1 >= 1 and float(P.d.server_time) > 0.0, "Spielstand hochgeladen (rev %d)" % rev1)
	P.d.level = 11
	P.mark()
	await net.upload()
	T._check(int(P.d.rev) == rev1 + 1, "rev zählt weiter")
	await net.upload()
	T._check(int(P.d.rev) == rev1 + 1, "ohne Änderung kein neuer Upload")
	var g: Dictionary = await net.rpc_call("rw_save_get", {})
	T._check(g.ok and int(g.data.data.level) == 11 and int(g.data.rev) == rev1 + 1, "Spielstand vom Server lesbar")
	var lst: Array = await net.server_cities()
	T._check(lst.size() == 1 and int(lst[0].city) == P.slot, "Städte-Liste des Kontos")


func _conflict() -> void:
	# ein anderes Gerät (gleiches Konto) speichert einen viel weiter fortgeschrittenen Stand
	var other: Dictionary = P.d.duplicate(true)
	other.level = 15
	var w: Dictionary = await net.rpc_call("rw_save_put", {"base": int(P.d.rev), "data": other})
	T._check(w.ok and bool(w.data.ok), "zweites Gerät speichert")
	P.d.level = 12
	P.mark()
	var r: Dictionary = await net.upload()
	T._check(r.ok and bool(r.data.get("conflict", false)), "Konflikt wird erkannt")
	T._check(NetNode.decide(NetNode.summary(P.d), r.data.summary) == "ask", "großer Unterschied -> Rückfrage")
	T._check(int(P.d.level) == 12, "ohne Antwort bleibt der lokale Stand")
	var why: String = await net.take_remote()
	T._check(why == "" and int(P.d.level) == 15, "Server-Stand übernommen")
	P.d.level = 16
	P.mark()
	r = await net.upload()
	T._check(r.ok and bool(r.data.get("ok", false)), "danach wieder normal speichern")
	# kleiner Unterschied: der neuere gewinnt automatisch (hier der lokale)
	other = P.d.duplicate(true)
	other.server_time = P.now() - 500.0
	await net.rpc_call("rw_save_put", {"base": int(P.d.rev), "data": other})
	P.mark()
	r = await net.upload()
	T._check(r.ok and bool(r.data.get("ok", false)) and int(P.d.level) == 16, "kleiner Unterschied: neuerer Stand gewinnt ohne Rückfrage")


# ================================================================= Freunde und Post
func _friends_mail() -> void:
	var soc = P.social
	T._check(soc.find_bases("beaf").is_empty(), "Suche läuft im Hintergrund")
	await _until(func(): return not soc.find_bases("beaf").is_empty())
	var hits: Array = soc.find_bases("beaf")
	T._check(hits.size() == 1 and String(hits[0].code) == b_code, "Suche nach Bunkername findet den Spieler")
	T._check(soc.add_friend(b_code) == "", "Freund hinzufügen")
	await _until(func(): return soc.s.friends.size() == 1)
	T._check(soc.s.friends.size() == 1 and String(soc.s.friends[0].bunker_name) == "Beafeste", "Freundesliste vom Server")
	T._check(soc.add_friend("ZZZZZZZZ") == "", "unbekannter Code wird erst vom Server abgelehnt")
	# Senden: 5 % Holz, Limit 5 am Tag
	P.d.res.wood = 1000
	var fname := String(soc.s.friends[0].name)
	T._check(soc.send_resource(fname, "wood") == "" and P.res("wood") == 950, "Holz verschickt")
	for i in 4:
		soc.send_resource(fname, "wood")
	T._check(soc.send_resource(fname, "wood") != "" and soc.sends_left() == 0, "Limit: fünf Sendungen am Tag")
	await T.get_tree().create_timer(0.5, true, false, true).timeout
	var bm := await _b("rw_mail", {})
	var got := 0
	for m in bm.get("mail", []):
		got += int(m.get("res", {}).get("wood", 0))
	T._check(got > 0, "Sendungen liegen in der Post des Freundes (%d Holz)" % got)
	var extra := await _b("rw_send", {"to": soc.friend_code(), "kind": "res", "res": "wood", "amount": 30})
	T._check(bool(extra.get("ok", false)), "Freund schickt Holz")
	for i in 5:
		await _b("rw_send", {"to": soc.friend_code(), "kind": "res", "res": "wood", "amount": 30})
	var over := await _b("rw_send", {"to": soc.friend_code(), "kind": "res", "res": "wood", "amount": 30})
	T._check(not bool(over.get("ok", true)), "Server setzt das Tageslimit durch")
	var gift := await _b("rw_send", {"to": soc.friend_code(), "kind": "giftbox"})
	var gift2 := await _b("rw_send", {"to": soc.friend_code(), "kind": "giftbox"})
	T._check(bool(gift.get("ok", false)) and not bool(gift2.get("ok", true)), "Geschenkkiste: eine pro Woche")
	await soc.o.load_mail()
	var wood_mail := 0
	for m in soc.s.mail:
		wood_mail += int(m.res.get("wood", 0))
	T._check(wood_mail == 150 and soc.mail_count() >= 6, "Post vom Server (%d Holz)" % wood_mail)
	var w0 := P.res("wood")
	var ch0 := P.chest_count("gift")
	var n: int = soc.mail_claim_all()
	T._check(n >= 6 and soc.mail_count() == 0, "Post abholen")
	await _until(func(): return P.res("wood") > w0)
	T._check(P.res("wood") == w0 + 150 and P.chest_count("gift") == ch0 + 1, "Inhalt erst nach Serverbestätigung gutgeschrieben")


# ================================================================= Clan
func _clan() -> void:
	var soc = P.social
	P.d.res.coins = 3000
	P.d.level = maxi(int(P.d.level), 10)
	T._check(soc.create_clan("Testclan") == "", "Clan gründen")
	await _until(func(): return soc.has_clan())
	T._check(soc.has_clan() and String(soc.s.clan.name) == "Testclan" and bool(soc.s.clan.own), "Clan vom Server, Rolle Anführer")
	var cl := await _b("rw_clan_list", {})
	var cid := String(cl.clans[0].id) if cl.get("clans", []).size() > 0 else ""
	var j := await _b("rw_clan_join", {"id": cid})
	T._check(bool(j.get("ok", false)), "zweiter Spieler tritt bei")
	await _b("rw_clan_chat", {"text": "Hallo du Arschloch"})
	await _b("rw_clan_request", {"res": "stone", "amount": 50})
	await soc.o.load_clan()
	T._check(soc.s.clan.members.size() == 1 and String(soc.s.clan.members[0].role) == "Mitglied", "Mitgliederliste mit Rollen")
	var filtered := false
	for x in soc.s.shouts:
		if String(x.text).contains("*****"):
			filtered = true
		T._check(not String(x.text).to_lower().contains("arschloch"), "Chat-Filter")
	T._check(filtered, "Schimpfwort im Clan-Chat ersetzt")
	var role: Dictionary = await net.rpc_call("rw_clan_role", {"code": b_code, "action": "promote"})
	T._check(role.ok and bool(role.data.ok), "Anführer befördert zum Stellvertreter")
	T._check(soc.s.clan.asks.size() == 1, "Spendenbitte sichtbar")
	P.d.res.stone = 500
	T._check(soc.donate(0) == "" and P.res("stone") == 450, "gespendet")
	await T.get_tree().create_timer(0.4, true, false, true).timeout
	var bm := await _b("rw_mail", {})
	var stone := 0
	for m in bm.get("mail", []):
		stone += int(m.get("res", {}).get("stone", 0))
	T._check(stone == 50, "Spende kommt beim Clan-Mitglied an")


# ================================================================= Ranglisten
func _boards() -> void:
	var soc = P.social
	soc.add_points("flood", 500)
	await T.get_tree().create_timer(0.3, true, false, true).timeout
	await soc.o.load_board("flood")
	var rows: Array = soc.board("flood")
	T._check(rows.size() >= 1 and bool(rows[0].me) and int(rows[0].score) == 500, "Flut-Rangliste vom Server")
	await soc.o.load_board("clans")
	T._check(soc.board("clans").size() == 1, "Clan-Rangliste")
	# Wochenwechsel: eine Woche später rechnet der Server ab
	await _req(HTTPClient.METHOD_POST, "/mock/time", {"offset": 8 * 86400.0}, "")
	await soc.o.load_mail()
	var up := false
	for m in soc.s.mail:
		if String(m.text).contains("Aufstieg"):
			up = true
	await soc.o.load_board("flood")
	T._check(up and int(soc.s.league) == 1, "Wochen-Reset: Abrechnung und Aufstieg (Post %s, Liga %d)" % [str(up), int(soc.s.league)])
	T._check(int(soc.board("flood")[0].score) == 0, "neue Woche beginnt bei 0")
	await _req(HTTPClient.METHOD_POST, "/mock/time", {"offset": 0.0}, "")
	soc.mail_claim_all()


# ================================================================= Belohnungen erst nach Bestätigung
func _rewards() -> void:
	await T.get_tree().create_timer(0.3, true, false, true).timeout
	await net.flush_rewards()
	var g0 := P.gems()
	P.add_gems(20, "Flut gewonnen")
	T._check(P.gems() == g0 and net.pending_gems() == 20, "Juwelen warten auf den Server")
	await net.flush_rewards()
	T._check(P.gems() == g0 + 20 and net.pending().is_empty(), "nach Bestätigung gutgeschrieben")
	P.add_gems(20, "Flut gewonnen")
	await net.flush_rewards()
	T._check(P.gems() == g0 + 20, "zweite Flut-Belohnung derselben Woche abgelehnt")
	P.add_gems(9999, "Schummelei")
	await net.flush_rewards()
	T._check(P.gems() == g0 + 20, "zu große Belohnung abgelehnt")
	# offline: Belohnung wartet und kommt nach dem Wiederverbinden
	net.status = "offline"
	var g2 := P.gems()
	P.add_gems(5, "Tagesauftrag")
	T._check(P.gems() == g2 and net.pending_gems() == 5, "offline: Belohnung wartet")
	net.status = "online"
	await net.flush_rewards()
	T._check(P.gems() == g2 + 5, "nach dem Verbinden gutgeschrieben")
	var c0 := P.chest_count("flood_gold")
	P.add_chest("flood_gold")
	T._check(P.chest_count("flood_gold") == c0, "Kiste wartet auf den Server")
	await net.flush_rewards()
	T._check(P.chest_count("flood_gold") == c0 + 1 and P.d.chest_seeds.get("flood_gold", []).size() == 1, "Kiste bestätigt, Ziehung vom Server")
	var got: Array = P.open_chest("flood_gold")
	T._check(got.size() > 0 and P.d.chest_seeds.get("flood_gold", []).is_empty(), "Kiste mit Server-Ziehung geöffnet")
	# ausgegebene Juwelen gleicht der Server ab (vorher alles Ausstehende anderer Pakete gutschreiben)
	await net.flush_rewards()
	var g1 := P.gems()
	P.spend_gems(10, "Test")
	await net.flush_rewards()
	P.add_gems(3, "Erfolg")
	await net.flush_rewards()
	var wal: Dictionary = await net.rpc_call("rw_wallet", {})
	T._check(int(wal.data.gems) == P.gems() and P.gems() == g1 - 7, "Juwelen-Konto stimmt mit dem Server überein (%d / %d)" % [int(wal.data.get("gems", -1)), P.gems()])


# ================================================================= Käufe
func _purchase() -> void:
	var g0 := P.gems()
	T._check(Store.is_async() and Store.buy("gems_500") == "", "Testkauf über den Server gestartet")
	T._check(P.gems() == g0, "Juwelen erst nach Prüfung")
	await _until(func(): return P.gems() == g0 + 500)
	T._check(P.gems() == g0 + 500, "Testkauf vom Server bestätigt")
	var bad: Dictionary = await net.rpc_call("rw_purchase", {"store": "apple", "product": "rustwall.gems_80", "receipt": "GEFAELSCHT", "transaction": "x1"})
	T._check(bad.ok and not bool(bad.data.ok), "gefälschter Beleg abgelehnt")
	var ok1: Dictionary = await net.rpc_call("rw_purchase", {"store": "google", "product": "rustwall.gems_80", "receipt": "MOCK-GOOGLE-OK-1", "transaction": "g1"})
	var ok2: Dictionary = await net.rpc_call("rw_purchase", {"store": "google", "product": "rustwall.gems_80", "receipt": "MOCK-GOOGLE-OK-1", "transaction": "g1"})
	T._check(bool(ok1.data.ok) and int(ok1.data.gems_added) == 80 and int(ok2.data.gems_added) == 0, "gültiger Beleg einmal gutgeschrieben, doppelt nicht")
	var st1: Dictionary = await net.rpc_call("rw_purchase", {"store": "apple", "product": "rustwall.starter", "receipt": "MOCK-APPLE-OK-s1", "transaction": "s1"})
	var st2: Dictionary = await net.rpc_call("rw_purchase", {"store": "apple", "product": "rustwall.starter", "receipt": "MOCK-APPLE-OK-s2", "transaction": "s2"})
	T._check(bool(st1.data.ok) and not bool(st2.data.ok), "Startangebot nur einmal")
	await net.flush_rewards()
	var rs: Dictionary = await net.rpc_call("rw_restore", {})
	T._check(rs.ok and rs.data.purchases.size() == 3, "Käufe wiederherstellen: Verlauf vom Server")


# ================================================================= Telemetrie und Fehlerberichte
func _telemetry() -> void:
	net.set_consent(true, true, "16+")
	net.tel.track("tutorial", {"step": 1})
	P.social.track("tutorial", {"step": 2})
	await net.tel.flush()
	var st := await _state()
	T._check(st.get("telemetry", []).size() >= 2 and net.tel.queue.is_empty(), "Telemetrie mit Einwilligung gesendet")
	var anon := true
	for e in st.get("telemetry", []):
		if str(e).contains(String(net.user_id)):
			anon = false
	T._check(anon, "Telemetrie ohne Konto-Nummer gespeichert")
	if net.tel.logger != null:
		var bts: Array[ScriptBacktrace] = []
		net.tel.logger._log_error("test_funktion", "res://src/test.gd", 7, "TESTFEHLER", "absichtlich ausgelöst", false, 2, bts)
		await T.get_tree().process_frame
		for i in 40:
			net.tel.process(0.0)
			await T.get_tree().process_frame
		await _until(func(): return not net.tel._crash_flushing)
		st = await _state()
		T._check(st.get("crashes", []).size() >= 1, "Fehlerbericht an den Server gesendet")
	else:
		T._check(false, "Logger-Klasse fehlt")
	net.set_consent(false, false, "16+")


# ================================================================= Melden, Sperren, Löschen
func _moderation() -> void:
	var soc = P.social
	await soc.o.report(b_code, "Name", true)
	T._check(soc.s.friends.is_empty(), "gemeldeter Bunker ist gesperrt und aus der Liste")
	var st := await _state()
	T._check(st.get("reports", []).size() == 1, "Meldung liegt auf dem Server")
	var s2 := await _b("rw_send", {"to": soc.friend_code(), "kind": "res", "res": "wood", "amount": 10})
	T._check(not bool(s2.get("ok", true)), "gesperrter Spieler kann nichts mehr schicken")


func _delete() -> void:
	var uid := String(net.user_id)
	net.status = "offline"
	var g7 := P.gems()
	P.add_gems(7, "Erfolg")
	net.status = "online"
	var why: String = await net.delete_account()
	T._check(P.gems() == g7 + 7 and net.pending().is_empty(), "wartende Belohnungen bleiben beim Löschen erhalten")
	T._check(why == "" and not net.enabled() and net.status == "aus", "Konto gelöscht, Gerät wieder ohne Server")
	var st := await _state()
	T._check(not st.get("users", {}).has(uid) and st.get("users", {}).size() == 1, "Konto auf dem Server entfernt")
	var left := true
	for k in st.get("cities", {}):
		if String(k).begins_with(uid):
			left = false
	T._check(left and not st.get("names", {}).has("testburg"), "Spielstände und Bunkername entfernt")
	var g0 := P.gems()
	P.add_gems(4, "Test")
	T._check(P.gems() == g0 + 4, "nach dem Löschen: wieder sofort gutgeschrieben")
