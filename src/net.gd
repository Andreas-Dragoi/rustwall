extends Node
## Online-Anbindung (Paket O): Verbindung zum Rustwall-Server (Nakama, REST-Schnittstelle über HTTPRequest).
##
## Wird von social.gd einmal als Kind von P angelegt (Knoten "Net") und bleibt über Stadtwechsel bestehen.
## Ohne Server-Adresse (Einstellungen → Online) passiert hier nichts: das Spiel läuft wie bisher allein auf dem Gerät.
##
## Mit Server-Adresse:
## - Konto: anonym über eine zufällige Geräte-Kennung (keine Hardware-ID), später mit E-Mail/Apple/Google verknüpfbar.
## - Serverzeit: P.now() wird um den gemessenen Unterschied zur Serveruhr korrigiert (P.server_offset).
## - Cloud-Speicher: alle 30 s (wenn sich etwas geändert hat) und beim Schließen; Feld "rev" fortlaufend,
##   Konfliktregel siehe decide(): der neuere Stand gewinnt, bei großem Unterschied wird gefragt.
## - Juwelen und Kisten aus Belohnungen werden erst nach Serverbestätigung gutgeschrieben (hold() / flush_rewards()).
## - Telemetrie und Fehlerberichte nur mit Einwilligung (net_telemetry.gd, net_logger.gd).
##
## Alle Anfragen sind Koroutinen (await). Aufrufer, die kein Ergebnis brauchen, rufen sie ohne await auf.

const Telemetry = preload("res://src/net_telemetry.gd")
const NetUi = preload("res://src/net_ui.gd")

const CFG_PATH := "user://rustwall_net.json"
const SYNC_EVERY := 30.0              # Cloud-Speicher höchstens alle 30 s
const SOCIAL_EVERY := 60.0            # Freunde, Post, Clan, Ranglisten neu laden
const TIME_EVERY := 600.0             # Serverzeit neu abgleichen
const RETRY_EVERY := 30.0             # nach Verbindungsfehler erneut versuchen
const BIG_LEVEL_DIFF := 2             # Konflikt: ab so viel Stufen Unterschied wird gefragt
const WALLET_INIT_MAX := 5000         # einmalige Übernahme des Geräte-Guthabens beim ersten Verbinden
const DEFAULT_KEY := "defaultkey"     # Server-Schlüssel (öffentlich, kein Geheimnis – siehe server/README.md)

signal status_changed
signal social_updated

var cfg: Dictionary = {}
var status := "aus"                   # aus | verbinde | online | offline | fehler
var status_text := "Kein Server eingestellt – Rustwall läuft allein auf diesem Gerät."
var user_id := ""
var account: Dictionary = {}          # Antwort von GET /v2/account (verknüpfte Anmeldungen)
var bunker_ok := true
var bunker_why := ""
var bypass := false                   # true, während bestätigte Belohnungen gutgeschrieben werden
var tel: RefCounted                   # Telemetrie (net_telemetry.gd)
var ui: RefCounted                    # Dialoge (net_ui.gd)
var testing := false                  # Tests: kein Schreiben der Gerätedatei, Speichern auch mit P.no_save
var last_error := ""

var _dirty := false
var _uploading := false
var _flushing := false
var _connecting := false
var _t_sync := 0.0
var _t_social := 0.0
var _t_time := 0.0
var _t_retry := 0.0
var _created := false
var _last_slot := -1
var _hold_note := -100000
var quiet := false                    # true: Änderungen am Spielstand nicht als "neu hochladen" zählen


func _ready() -> void:
	name = "Net"
	process_mode = Node.PROCESS_MODE_ALWAYS
	testing = G.selftest or G.autotest != "" or G.shots_dir != ""
	_load_cfg()
	P.server_offset = float(cfg.get("offset", 0.0)) if enabled() else 0.0
	P.changed.connect(func():
		if not quiet:
			_dirty = true)
	P.city_changed.connect(_on_city_changed)
	tel = Telemetry.new(self)
	ui = NetUi.new(self)
	if enabled() and not testing:
		connect_now.call_deferred()
	if not testing:
		ui.consent_when_ready.call_deferred()
	if G.arg("netserver") != "":       # Tests/Bilder: mit diesem (Test-)Server verbinden
		set_server.call_deferred(G.arg("netserver"))
	match G.arg("netui"):              # Bilder der Dialoge: --netui=consent | consent2 | young | conflict
		"consent":
			ui.show_consent.call_deferred(0)
		"consent2":
			ui.show_consent.call_deferred(1)
		"young":
			ui._young.call_deferred()
		"conflict":
			ui.ask_conflict.call_deferred({"level": 12, "bunker": 4, "server_time": 1791700000.0}, {"level": 15, "bunker": 5, "server_time": 1791750000.0})


# ================================================================= Einstellungen dieses Geräts
func _load_cfg() -> void:
	cfg = {"url": "", "key": DEFAULT_KEY, "device": "", "token": "", "refresh": "", "consent": -1, "crash": false, "age": "",
		"offset": 0.0, "sentry": "", "wallet_init": false, "user_id": ""}
	if testing or not FileAccess.file_exists(CFG_PATH):
		return
	var v = JSON.parse_string(FileAccess.get_file_as_string(CFG_PATH))
	if v is Dictionary:
		for k in v:
			cfg[k] = v[k]
	cfg.consent = int(cfg.consent)


func save_cfg() -> void:
	if testing:
		return
	var f := FileAccess.open(CFG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(cfg, "\t"))


func enabled() -> bool:
	return String(cfg.get("url", "")).strip_edges() != ""


func online() -> bool:
	return status == "online"


## Zufällige Geräte-Kennung (keine Hardware-Nummer – Datenschutz).
func device_id() -> String:
	if String(cfg.device).length() < 16:
		var r := RandomNumberGenerator.new()
		r.randomize()
		var s := "rw-"
		for i in 32:
			s += "0123456789abcdef"[r.randi() % 16]
		cfg.device = s
		save_cfg()
	return String(cfg.device)


## Server-Adresse setzen ("" = aus). Verbindet sofort neu.
func set_server(url: String) -> String:
	url = url.strip_edges().rstrip("/")
	if url != "" and not (url.begins_with("http://") or url.begins_with("https://")):
		url = "https://" + url
	if url != "" and url.begins_with("http://") and not (url.contains("://localhost") or url.contains("://127.0.0.1") or url.contains("://192.168.") or url.contains("://10.")):
		return "Bitte eine sichere Adresse (https://…) angeben."
	if url != String(cfg.url):
		cfg.token = ""
		cfg.refresh = ""
		cfg.wallet_init = false
	cfg.url = url
	save_cfg()
	if url == "":
		_set_status("aus", "Kein Server eingestellt – Rustwall läuft allein auf diesem Gerät.")
		P.server_offset = 0.0
		release_pending()
		return ""
	connect_now()
	return ""


func _set_status(s: String, text: String) -> void:
	var changed_now := s != status or text != status_text
	status = s
	status_text = text
	_set_quit_mode()
	if changed_now:
		status_changed.emit()


# ================================================================= HTTP
## Eine Anfrage. auth: "" | "basic" (Server-Schlüssel) | "bearer" (Sitzung). Rückgabe {ok, code, data, why, net}.
func http(method: int, path: String, body, auth: String) -> Dictionary:
	var url := String(cfg.url).rstrip("/") + path
	var req := HTTPRequest.new()
	req.timeout = 12.0
	req.accept_gzip = true
	add_child(req)
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	if auth == "basic":
		headers.append("Authorization: Basic " + Marshalls.utf8_to_base64(String(cfg.key) + ":"))
	elif auth == "bearer":
		headers.append("Authorization: Bearer " + String(cfg.token))
	var data := "" if body == null else JSON.stringify(body)
	var err := req.request(url, headers, method, data)
	if err != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "data": {}, "why": "Anfrage nicht möglich (%d)" % err, "net": true}
	var res: Array = await req.request_completed
	req.queue_free()
	var result: int = res[0]
	var code: int = res[1]
	var raw: PackedByteArray = res[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "code": 0, "data": {}, "why": "Server nicht erreichbar", "net": true}
	var parsed = JSON.parse_string(raw.get_string_from_utf8()) if raw.size() > 0 else {}
	if not (parsed is Dictionary):
		parsed = {}
	var ok := code >= 200 and code < 300
	return {"ok": ok, "code": code, "data": parsed, "why": "" if ok else String(parsed.get("message", "Fehler %d" % code)), "net": false}


## Serverfunktion aufrufen (Nakama-RPC). Fügt die Nummer der Stadt hinzu. Rückgabe {ok, data, why}.
func rpc_call(fn: String, payload: Dictionary = {}) -> Dictionary:
	if not enabled():
		return {"ok": false, "data": {}, "why": "Kein Server eingestellt."}
	if not payload.has("city"):
		payload["city"] = P.slot
	if not await _ensure_session():
		return {"ok": false, "data": {}, "why": last_error}
	var r := await http(HTTPClient.METHOD_POST, "/v2/rpc/" + fn, JSON.stringify(payload), "bearer")
	if int(r.code) == 401 and await _ensure_session(true):
		r = await http(HTTPClient.METHOD_POST, "/v2/rpc/" + fn, JSON.stringify(payload), "bearer")
	if not r.ok:
		_failed(r)
		return {"ok": false, "data": {}, "why": String(r.why)}
	var pl = JSON.parse_string(String(r.data.get("payload", "{}")))
	return {"ok": true, "data": pl if pl is Dictionary else {}, "why": ""}


func _failed(r: Dictionary) -> void:
	last_error = String(r.why)
	if bool(r.get("net", false)):
		_set_status("offline", "Server nicht erreichbar – du spielst offline weiter. Fortschritt wird später übertragen.")
		_t_retry = 0.0


# ================================================================= Sitzung (Konto)
static func token_exp(tok: String) -> float:
	var parts := tok.split(".")
	if parts.size() != 3:
		return 0.0
	var b := parts[1].replace("-", "+").replace("_", "/")
	while b.length() % 4 != 0:
		b += "="
	var v = JSON.parse_string(Marshalls.base64_to_utf8(b))
	return float(v.get("exp", 0)) if v is Dictionary else 0.0


func _token_ok(tok: String) -> bool:
	return tok != "" and token_exp(tok) > Time.get_unix_time_from_system() + P.server_offset + 60.0


func _set_session(d: Dictionary) -> void:
	cfg.token = String(d.get("token", ""))
	cfg.refresh = String(d.get("refresh_token", cfg.refresh))
	save_cfg()


func _ensure_session(force := false) -> bool:
	if not force and _token_ok(String(cfg.token)):
		return true
	if _token_ok(String(cfg.refresh)):
		var r := await http(HTTPClient.METHOD_POST, "/v2/account/session/refresh", {"token": cfg.refresh}, "basic")
		if r.ok:
			_set_session(r.data)
			return true
	var r2 := await http(HTTPClient.METHOD_POST, "/v2/account/authenticate/device?create=true", {"id": device_id()}, "basic")
	if r2.ok:
		_set_session(r2.data)
		_created = bool(r2.data.get("created", false))
		return true
	_failed(r2)
	if not bool(r2.get("net", false)):
		_set_status("fehler", "Anmeldung am Server fehlgeschlagen: %s" % String(r2.why))
	return false


## Mit E-Mail und Passwort anmelden (z. B. auf einem neuen Gerät). Danach Spielstände mit restore_cities() holen.
func login_email(email: String, password: String) -> String:
	var r := await http(HTTPClient.METHOD_POST, "/v2/account/authenticate/email?create=false", {"email": email.strip_edges(), "password": password}, "basic")
	if not r.ok:
		return "Anmeldung fehlgeschlagen: %s" % String(r.why)
	_set_session(r.data)
	cfg.wallet_init = true                # das Konto hat schon ein Guthaben
	save_cfg()
	await connect_now()
	return ""


## Konto mit E-Mail (oder Apple/Google: token aus dem jeweiligen Anmelde-Plugin) verknüpfen.
func link(kind: String, a: String, b := "") -> String:
	if not online():
		return "Dafür muss eine Verbindung zum Server bestehen."
	var body := {"email": a.strip_edges(), "password": b} if kind == "email" else {"token": a}
	var r := await http(HTTPClient.METHOD_POST, "/v2/account/link/" + kind, body, "bearer")
	if not r.ok:
		return "Verknüpfen fehlgeschlagen: %s" % String(r.why)
	await load_account()
	return ""


func load_account() -> void:
	var r := await http(HTTPClient.METHOD_GET, "/v2/account", null, "bearer")
	if r.ok:
		account = r.data
		status_changed.emit()


func linked(kind: String) -> bool:
	return bool(account.get("linked", {}).get(kind, false)) or (kind == "email" and String(account.get("email", "")) != "")


# ================================================================= Verbinden
func hello_payload() -> Dictionary:
	return {"city": P.slot, "bunker_name": P.bunker_name(), "name": String(P.d.get("name", "Kommandant")), "level": int(P.d.get("level", 1)),
		"bunker": P.bunker_level(), "code": String(P.social.friend_code()) if P.social else ""}


func connect_now() -> void:
	if _connecting or not enabled():
		return
	_connecting = true
	_set_status("verbinde", "Verbinde mit %s …" % String(cfg.url))
	var t0 := Time.get_unix_time_from_system()
	_last_slot = P.slot
	var r := await rpc_call("rw_hello", hello_payload())
	_connecting = false
	if not r.ok:
		if status == "verbinde":
			_set_status("fehler" if last_error != "Server nicht erreichbar" else "offline", "Keine Verbindung: %s" % r.why)
		return
	var t1 := Time.get_unix_time_from_system()
	_apply_time(float(r.data.get("now", t1)), (t0 + t1) * 0.5)
	user_id = String(r.data.get("user_id", ""))
	cfg.user_id = user_id
	save_cfg()
	_apply_hello(r.data)
	_set_status("online", "Verbunden mit %s" % String(cfg.url))
	_t_sync = SYNC_EVERY
	_t_social = SOCIAL_EVERY
	_t_time = 0.0
	if (_created or not bool(cfg.wallet_init)):
		await _wallet_init()
	load_account()
	await upload()
	await flush_rewards()
	P.social.net_refresh()
	preload("res://src/liveops.gd").net_refresh()           # Paket L: Ereignis-Zeitplan, Nachrichten, Saison
	tel.track("session_online", {})


func _apply_hello(d: Dictionary) -> void:
	var code := String(d.get("code", ""))
	if code != "" and P.social and P.social.s.get("code", "") != code:
		P.social.s.code = code
		P.mark()
	var bn: Dictionary = d.get("bunker", {"ok": true, "why": ""})
	bunker_ok = bool(bn.get("ok", true))
	bunker_why = String(bn.get("why", ""))
	if not bunker_ok and bunker_why != "":
		P.toast.emit(bunker_why)
	if P.social and d.has("league"):
		P.social.s.league = int(d.league)


func _apply_time(server_now: float, local_mid: float) -> void:
	P.server_offset = server_now - local_mid
	cfg.offset = P.server_offset
	save_cfg()


## Einmalig: das bisherige Juwelen-Guthaben dieses Geräts auf das neue Konto übernehmen (gedeckelt).
func _wallet_init() -> void:
	var r := await rpc_call("rw_wallet_init", {"gems": mini(P.gems(), WALLET_INIT_MAX)})
	if r.ok:
		cfg.wallet_init = true
		save_cfg()


func _on_city_changed() -> void:
	if enabled() and P.slot != _last_slot:
		_dirty = true
		connect_now()


func rename_bunker() -> void:
	if not online():
		return
	var r := await rpc_call("rw_rename", {"bunker_name": P.bunker_name()})
	if r.ok:
		bunker_ok = bool(r.data.get("ok", false))
		bunker_why = String(r.data.get("why", ""))
		if not bunker_ok:
			P.toast.emit(bunker_why)
		status_changed.emit()


# ================================================================= Takt
func _process(dt: float) -> void:
	tel.process(dt)
	if not enabled():
		return
	if status != "online":
		if status in ["offline", "fehler"] and not _connecting:
			_t_retry += dt
			if _t_retry >= RETRY_EVERY:
				_t_retry = 0.0
				connect_now()
		return
	_t_sync += dt
	_t_social += dt
	_t_time += dt
	if _t_sync >= SYNC_EVERY:
		_t_sync = 0.0
		upload()
		flush_rewards()
		tel.flush()
	if _t_social >= SOCIAL_EVERY:
		_t_social = 0.0
		if P.social:
			P.social.net_refresh()
	if _t_time >= TIME_EVERY:
		_t_time = 0.0
		sync_time()


## Fenster schließen (PC): erst den Spielstand hochladen (höchstens 3 s warten), dann beenden.
func _quit_after_upload() -> void:
	tel.session_end()
	_dirty = true
	var state := {"done": false}
	var job := func():
		await upload()
		await tel.flush()
		state.done = true
	job.call()
	for i in 30:
		if state.done:
			break
		await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit()


func _set_quit_mode() -> void:
	# Solange eine Verbindung besteht, beendet sich das Fenster erst nach dem letzten Hochladen (_quit_after_upload).
	if not testing:
		get_tree().set_auto_accept_quit(not online())


func sync_time() -> void:
	var t0 := Time.get_unix_time_from_system()
	var r := await rpc_call("rw_time", {})
	if r.ok:
		_apply_time(float(r.data.now), (t0 + Time.get_unix_time_from_system()) * 0.5)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and online() and not testing:
		_quit_after_upload()
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		tel.session_end()
		if online():
			_dirty = true
			upload()
			tel.flush()
	if what == NOTIFICATION_APPLICATION_RESUMED and enabled():
		tel.session_start()
		if online():
			sync_time()
			P.social.net_refresh()


# ================================================================= Cloud-Speicher
## Lädt den Spielstand der aktiven Stadt hoch (nur wenn sich etwas geändert hat oder force).
func upload(force := false) -> Dictionary:
	if not online() or (P.no_save and not testing):
		return {}
	while _uploading:
		await get_tree().process_frame
	if not _dirty and not force:
		return {}
	_uploading = true
	_dirty = false
	var base := int(P.d.get("rev", 0))
	P.d.server_time = P.now()
	var r := await rpc_call("rw_save_put", {"city": P.slot, "base": base, "data": P.d, "force": force})
	_uploading = false
	if not r.ok:
		_dirty = true
		return r
	if bool(r.data.get("ok", false)):
		P.d.rev = int(r.data.rev)
		P.d.server_time = float(r.data.get("server_time", P.now()))
		if not P.no_save:
			P.save()
		return r
	if bool(r.data.get("conflict", false)):
		var r2: Dictionary = await _conflict(r.data.get("summary", {}))
		if not r2.is_empty():
			return r2
	return r


## Zusammenfassung eines Spielstands für die Konfliktregel.
static func summary(d: Dictionary) -> Dictionary:
	var b := 1
	for x in d.get("buildings", []):
		if String(x.get("key", "")) == "bunker":
			b = int(x.get("level", 1))
	return {"level": int(d.get("level", 1)), "bunker": b, "server_time": float(d.get("server_time", 0.0)), "rev": int(d.get("rev", 0)),
		"bunker_name": String(d.get("bunker_name", ""))}


## Konfliktregel: "local" (dieses Gerät gewinnt), "remote" (Server gewinnt) oder "ask" (Rückfrage).
## Der neuere Stand gewinnt; bei großem Unterschied (2+ Spielerstufen oder andere Bunkerstufe) wird gefragt.
static func decide(local: Dictionary, remote: Dictionary) -> String:
	if absi(int(local.level) - int(remote.level)) >= BIG_LEVEL_DIFF or int(local.bunker) != int(remote.bunker):
		return "ask"
	return "local" if float(local.server_time) >= float(remote.server_time) else "remote"


## Rückgabe: Ergebnis des erzwungenen Uploads ("local"), sonst {}.
func _conflict(remote: Dictionary) -> Dictionary:
	var local := summary(P.d)
	match decide(local, remote):
		"local":
			return await upload(true)
		"remote":
			await take_remote()
		"ask":
			if not testing:
				ui.ask_conflict(local, remote)
	return {}


## Spielstand der aktiven Stadt vom Server übernehmen.
func take_remote(city := -1) -> String:
	var r := await rpc_call("rw_save_get", {"city": P.slot if city < 0 else city})
	if not r.ok:
		return r.why
	var data = r.data.get("data")
	if not (data is Dictionary) or data.is_empty():
		return "Auf dem Server liegt kein Spielstand."
	if int(data.get("version", 0)) > P.VERSION:
		return "Dieser Spielstand stammt aus einer neueren Version. Bitte zuerst das Spiel aktualisieren."
	P.d = data
	P._switched()
	_dirty = false
	if not P.no_save:
		P.save()
	P.toast.emit("Spielstand vom Server geladen.")
	return ""


## Liste der Städte dieses Kontos auf dem Server: [{city, level, bunker, bunker_name, saved_at}]
func server_cities() -> Array:
	var r := await rpc_call("rw_save_list", {})
	return r.data.get("cities", []) if r.ok else []


# ================================================================= Belohnungen erst nach Bestätigung
## Hält Juwelen ("gems") oder Kisten ("chest", why = Kistenart) zurück, bis der Server sie bestätigt.
## Rückgabe true: zurückgehalten (der Aufrufer schreibt nichts gut).
func hold(kind: String, n: int, why: String) -> bool:
	if bypass or not enabled() or n <= 0:
		return false
	var q: Array = pending()
	q.append({"kind": kind, "n": n, "reason": why})
	P.mark()
	if online():
		flush_rewards.call_deferred()
	elif Time.get_ticks_msec() - _hold_note > 60000:
		_hold_note = Time.get_ticks_msec()
		P.toast.emit("Belohnung wird gutgeschrieben, sobald der Server wieder erreichbar ist.")
	return true


func pending() -> Array:
	if not (P.d.get("net_pending") is Array):
		P.d["net_pending"] = []
	return P.d.net_pending


func pending_gems() -> int:
	var n := 0
	for it in pending():
		if String(it.kind) == "gems":
			n += int(it.n)
	return n


func flush_rewards() -> void:
	if not online():
		return
	while _flushing:
		await get_tree().process_frame
	var q: Array = pending()
	var spent := int(P.d.get("net_spent", 0))
	if q.is_empty() and spent <= 0:
		return
	_flushing = true
	var batch: Array = q.duplicate(true)
	if spent > 0:
		var rs := await rpc_call("rw_spend", {"n": spent})
		if rs.ok:
			P.d.net_spent = maxi(0, int(P.d.get("net_spent", 0)) - spent)
	var r := await rpc_call("rw_reward", {"items": batch})
	_flushing = false
	if not r.ok:
		return
	# die verschickten Einträge aus der Warteschlange nehmen (neue, die inzwischen kamen, bleiben)
	for i in batch.size():
		q.pop_front()
	var acc: Array = r.data.get("accepted", [])
	var seeds: Array = r.data.get("seeds", [])
	bypass = true
	for i in batch.size():
		var it: Dictionary = batch[i]
		if float(i) in acc or i in acc:
			if String(it.kind) == "gems":
				P.add_gems(int(it.n), String(it.reason))
			elif String(it.kind) == "chest":
				P.add_chest(String(it.reason), int(it.n))
		else:
			P.toast.emit("Der Server hat eine Belohnung nicht bestätigt (%s)." % String(it.reason))
	bypass = false
	for sd in seeds:
		add_chest_seed(String(sd[0]), int(sd[1]))
	if q.is_empty() and int(P.d.get("net_spent", 0)) == 0:
		reconcile_gems(int(r.data.get("gems", P.gems())))
	P.mark()


## Ohne Server: noch wartende Belohnungen sofort gutschreiben (sonst gingen sie verloren).
func release_pending() -> void:
	var q: Array = pending().duplicate(true)
	pending().clear()
	P.d.net_spent = 0
	bypass = true
	for it in q:
		if String(it.kind) == "gems":
			P.add_gems(int(it.n), String(it.reason))
		elif String(it.kind) == "chest":
			P.add_chest(String(it.reason), int(it.n))
	bypass = false
	P.mark()


## Juwelen-Stand an den Server angleichen (der Server entscheidet).
func reconcile_gems(server_gems: int) -> void:
	var diff := server_gems - P.gems()
	if diff == 0:
		return
	bypass = true
	if diff > 0:
		P.add_gems(diff, "Abgleich mit Server")
	else:
		P.spend_gems(-diff, "Abgleich mit Server")
	bypass = false


## Ausgegebene Juwelen merken (werden beim nächsten Abgleich dem Server gemeldet).
func note_spend(n: int) -> void:
	if enabled() and not bypass and n > 0:
		P.d["net_spent"] = int(P.d.get("net_spent", 0)) + n


## Vom Server gezogene Zufallszahl für eine Kiste (Kisten-Ziehung entscheidet der Server).
func add_chest_seed(type: String, seed_val: int) -> void:
	if not (P.d.get("chest_seeds") is Dictionary):
		P.d["chest_seeds"] = {}
	var l: Array = P.d.chest_seeds.get(type, [])
	l.append(seed_val)
	P.d.chest_seeds[type] = l


func take_chest_seed(type: String) -> int:
	var cs = P.d.get("chest_seeds")
	if not (cs is Dictionary) or not cs.has(type) or cs[type].is_empty():
		return -1
	return int(cs[type].pop_front())


# ================================================================= Konto löschen
## Löscht das Konto und alle Daten auf dem Server. Die Spielstände auf diesem Gerät bleiben (außer wipe_local).
func delete_account(wipe_local := false) -> String:
	if not enabled():
		return "Es ist kein Server eingestellt – es gibt kein Konto, das gelöscht werden könnte."
	var r := await rpc_call("rw_account_delete", {})
	if not r.ok:
		return "Löschen fehlgeschlagen: %s. Bitte später erneut versuchen." % r.why
	cfg.token = ""
	cfg.refresh = ""
	cfg.device = ""
	cfg.user_id = ""
	cfg.wallet_init = false
	cfg.url = ""
	save_cfg()
	user_id = ""
	account = {}
	P.server_offset = 0.0
	_set_status("aus", "Konto gelöscht. Rustwall läuft jetzt wieder allein auf diesem Gerät.")
	release_pending()
	if wipe_local:
		P.reset_all()
	return ""


# ================================================================= Einwilligung
func consent_analytics() -> bool:
	return int(cfg.consent) == 1 and String(cfg.age) != "u16"


func consent_crash() -> bool:
	return bool(cfg.crash) and String(cfg.age) != "u16"


func set_consent(analytics: bool, crash: bool, age := "") -> void:
	cfg.consent = 1 if analytics else 0
	cfg.crash = crash
	if age != "":
		cfg.age = age
	save_cfg()
	status_changed.emit()


func child_mode() -> bool:
	return String(cfg.age) == "u16"
