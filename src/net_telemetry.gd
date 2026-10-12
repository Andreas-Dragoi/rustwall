extends RefCounted
## Telemetrie und Fehlerberichte (Paket O, PDF Kap. 2.6). Alles NUR mit Einwilligung (net.consent_analytics() /
## net.consent_crash()); ohne Einwilligung wird nichts gesammelt und nichts gesendet.
##
## Ereignisse: session_start/session_end (Länge), fps (Mittel/Minimum je Minute), device (Gerät, System, Bildschirm),
## tutorial (Schritt – Paket F ruft P.social.track("tutorial", {"step": n, "skip": false})), flood (Sieg/Sterne/Woche),
## expedition, gems (verdient/ausgegeben), chest. Gesendet an rw_telemetry (Server speichert ohne Konto-Bezug).
## Fehlerberichte: net_logger.gd fängt Godot-Fehler ab; gesendet an einen Sentry-kompatiblen Endpunkt
## (Einstellung "sentry" = DSN https://<schlüssel>@<host>/<projekt>) oder sonst an rw_crash auf dem eigenen Server.

const NetLogger = preload("res://src/net_logger.gd")
const QUEUE_PATH := "user://rustwall_tel.json"
const MAX_QUEUE := 400
const VERSION := "0.5.0"

var net: Node
var queue: Array = []
var logger: Logger
var _session_t0 := 0.0
var _fps_sum := 0.0
var _fps_min := 999.0
var _fps_n := 0
var _fps_t := 0.0
var _flushing := false
var _crash_flushing := false
var _started := false


func _init(n: Node) -> void:
	net = n
	if ClassDB.class_exists("Logger"):
		logger = NetLogger.new()
		OS.add_logger(logger)
	if not net.testing and FileAccess.file_exists(QUEUE_PATH):
		var v = JSON.parse_string(FileAccess.get_file_as_string(QUEUE_PATH))
		if v is Array:
			queue = v
	P.gems_changed.connect(func(delta: int): track("gems", {"n": delta}))
	if not net.testing:
		session_start.call_deferred()


func track(event: String, props := {}) -> void:
	if not net.consent_analytics():
		return
	queue.append({"e": event, "p": props, "t": P.now()})
	while queue.size() > MAX_QUEUE:
		queue.pop_front()


func session_start() -> void:
	_session_t0 = Time.get_ticks_msec() / 1000.0
	_started = true
	var scr := DisplayServer.screen_get_size() if DisplayServer.get_name() != "headless" else Vector2i.ZERO
	track("session_start", {"ver": VERSION, "os": OS.get_name(), "model": OS.get_model_name(), "renderer": String(RenderingServer.get_current_rendering_method()),
		"screen": "%dx%d" % [scr.x, scr.y], "locale": OS.get_locale_language(), "web_mobile": G.web_mobile(), "quality": G.quality()})


func session_end() -> void:
	if not _started:
		return
	_started = false
	track("session_end", {"secs": int(Time.get_ticks_msec() / 1000.0 - _session_t0)})
	_save_queue()


func _save_queue() -> void:
	if net.testing or not net.consent_analytics():
		return
	var f := FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(queue))


## Jedes Bild: Bildrate sammeln (eine Meldung je Minute), Fehler weiterreichen.
func process(dt: float) -> void:
	if net.consent_analytics() and _started:
		var f := Engine.get_frames_per_second()
		_fps_sum += f
		_fps_n += 1
		_fps_min = minf(_fps_min, f)
		_fps_t += dt
		if _fps_t >= 60.0:
			var mode := "menu"
			if G.game != null:
				mode = String(G.game.get("mode")) if G.game.get("mode") != null else "spiel"
			track("fps", {"avg": snappedf(_fps_sum / maxi(_fps_n, 1), 0.1), "min": _fps_min, "mode": mode})
			_fps_t = 0.0
			_fps_sum = 0.0
			_fps_n = 0
			_fps_min = 999.0
	if logger != null and Engine.get_process_frames() % 30 == 0:
		var errs: Array = logger.take()
		if not errs.is_empty() and net.consent_crash():
			for e in errs:
				crash_queue.append(e)
			flush_crashes()


var crash_queue: Array = []


## Gesammelte Ereignisse an den Server schicken.
func flush() -> void:
	if _flushing or queue.is_empty() or not net.online() or not net.consent_analytics():
		return
	_flushing = true
	var batch := queue.slice(0, 200)
	var r: Dictionary = await net.rpc_call("rw_telemetry", {"events": batch})
	_flushing = false
	if r.ok:
		queue = queue.slice(batch.size())
		_save_queue()


## Fehlerberichte senden: an Sentry (falls eingestellt) oder an den eigenen Server.
func flush_crashes() -> void:
	if _crash_flushing or crash_queue.is_empty() or not net.consent_crash():
		return
	var dsn := String(net.cfg.get("sentry", ""))
	if dsn == "" and not net.online():
		return
	_crash_flushing = true
	while not crash_queue.is_empty():
		var e: Dictionary = crash_queue.pop_front()
		var ev := sentry_event(e)
		if dsn != "":
			await _send_sentry(dsn, ev)
		else:
			await net.rpc_call("rw_crash", {"event": ev})
	_crash_flushing = false


## Ein Fehler im Sentry-Ereignisformat (https://develop.sentry.dev/sdk/event-payloads/).
func sentry_event(e: Dictionary) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.randomize()
	var id := ""
	for i in 32:
		id += "0123456789abcdef"[r.randi() % 16]
	var frames: Array = []
	for f in e.get("frames", []):
		frames.push_front({"function": f.function, "filename": f.filename, "lineno": f.lineno})
	if frames.is_empty():
		frames.append({"function": String(e.get("function", "")), "filename": String(e.get("file", "")), "lineno": int(e.get("line", 0))})
	return {"event_id": id, "timestamp": float(e.get("t", Time.get_unix_time_from_system())), "platform": "other", "level": "error",
		"logger": "godot", "release": "rustwall@" + VERSION, "environment": "debug" if OS.is_debug_build() else "release",
		"tags": {"os": OS.get_name(), "model": OS.get_model_name(), "renderer": String(RenderingServer.get_current_rendering_method())},
		"exception": {"values": [{"type": String(e.get("type", "Fehler")) + ": " + String(e.get("code", "")), "value": String(e.get("text", "")),
			"stacktrace": {"frames": frames}}]}}


## DSN "https://<schlüssel>@<host>/<projekt>" -> {url, key}
static func parse_dsn(dsn: String) -> Dictionary:
	var m := RegEx.create_from_string("^(https?)://([^@]+)@([^/]+)/(.+)$").search(dsn.strip_edges())
	if m == null:
		return {}
	return {"url": "%s://%s/api/%s/store/" % [m.get_string(1), m.get_string(3), m.get_string(4)], "key": m.get_string(2).split(":")[0]}


func _send_sentry(dsn: String, ev: Dictionary) -> bool:
	var d := parse_dsn(dsn)
	if d.is_empty():
		return false
	var req := HTTPRequest.new()
	req.timeout = 10.0
	net.add_child(req)
	var h := PackedStringArray(["Content-Type: application/json",
		"X-Sentry-Auth: Sentry sentry_version=7, sentry_client=rustwall-godot/%s, sentry_key=%s" % [VERSION, d.key]])
	if req.request(String(d.url), h, HTTPClient.METHOD_POST, JSON.stringify(ev)) != OK:
		req.queue_free()
		return false
	var res: Array = await req.request_completed
	req.queue_free()
	return int(res[0]) == HTTPRequest.RESULT_SUCCESS and int(res[1]) < 300
