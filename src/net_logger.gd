extends Logger
## Fängt Godot-Fehlermeldungen ab (Skriptfehler, Engine-Fehler) für Fehlerberichte (Paket O).
## Wird mit OS.add_logger() angemeldet. Kann aus jedem Thread aufgerufen werden: hier wird nur gesammelt,
## gesendet wird im Hauptthread (net_telemetry.gd), und nur mit Einwilligung.

const MAX_PER_SESSION := 25

var _mutex := Mutex.new()
var _queue: Array = []
var _seen: Dictionary = {}
var _count := 0


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	var key := "%s:%d:%s" % [file, line, code]
	var frames: Array = []
	for bt in script_backtraces:
		if bt == null:
			continue
		for i in bt.get_frame_count():
			frames.append({"function": bt.get_frame_function(i), "filename": bt.get_frame_file(i), "lineno": bt.get_frame_line(i)})
	_mutex.lock()
	if not _seen.has(key) and _count < MAX_PER_SESSION:
		_seen[key] = true
		_count += 1
		_queue.append({"type": ["Fehler", "Warnung", "Skriptfehler", "Shaderfehler"][clampi(error_type, 0, 3)], "function": function, "file": file,
			"line": line, "code": code, "text": rationale, "frames": frames, "t": Time.get_unix_time_from_system()})
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass


## Gesammelte Fehler abholen (Hauptthread).
func take() -> Array:
	_mutex.lock()
	var out := _queue
	_queue = []
	_mutex.unlock()
	return out
