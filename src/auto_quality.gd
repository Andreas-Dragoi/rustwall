extends Node
## Paket Q (Kapitel 3.2): Grafikstufe beim ersten Start automatisch wählen.
## Misst einige Sekunden lang die Bildrate in der Basis (Bildratenbremse aus, Stufe „Mittel“) und wählt dann:
##   PC:          ab 55 Bildern/s „Hoch“, ab 35 „Mittel“, darunter „Niedrig“
##   Handy/Web:   ab 50 Bildern/s „Mittel“, darunter „Niedrig“ (Hoch nur von Hand – Akku und Wärme)
## Das Ergebnis gilt für das Gerät (device_cfg: auto_q, auto_fps); wählt der Spieler selbst eine Stufe
## (P.d.settings.quality_user), gilt seine Wahl. „Neu messen“ in den Einstellungen startet die Messung erneut.

const Dev = preload("res://src/device_cfg.gd")
const QUALITY_NAMES := ["Niedrig", "Mittel", "Hoch"]
const WARMUP := 1.5
const MEASURE := 5.0

static var measuring := false
static var node: Node = null

var _t := 0.0
var _frames := 0
var _time := 0.0
var _started := false
var _forced := false
var _last_us := 0.0


## Startet die Messung, wenn noch nie gemessen wurde (oder force).
static func maybe_start(main: Node, force := false) -> void:
	if main == null or not is_instance_valid(main):
		return
	if (G.selftest or G.autotest != "") and not force:
		return
	if Dev.has("auto_q") and not force:
		return
	if node != null and is_instance_valid(node):
		return
	node = new()
	node._forced = force
	main.add_child(node)


## Grafikstufe aus der automatischen Messung, -1 = nicht gemessen.
static func auto_quality() -> int:
	return int(Dev.get_v("auto_q", -1))


## Entscheidung aus der gemessenen Bildrate (auch für Tests).
static func choose(fps: float, pc: bool) -> int:
	if pc:
		return 2 if fps >= 55.0 else (1 if fps >= 35.0 else 0)
	return 1 if fps >= 50.0 else 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready_to_measure() -> bool:
	if G.main == null or G.main.world == null or not is_instance_valid(G.main.world):
		return false
	if String(G.main.world.get("mode")) != "peace":
		return false
	if G.main.menu != null and G.main.menu.visible:
		return false
	if G.main.loading != null and G.main.loading.get("_root") != null:      # Ladebildschirm noch zu sehen
		return false
	return DisplayServer.window_is_focused() or _forced


func _process(_dt: float) -> void:
	# echte Zeit (nicht Engine.time_scale)
	var now := Time.get_ticks_usec() * 0.000001
	var dt := clampf(now - _last_us, 0.0, 0.5) if _last_us > 0.0 else 0.0
	_last_us = now
	if not _started:
		if not _ready_to_measure():
			return
		_started = true
		measuring = true
		_t = 0.0
	_t += dt
	if _t < WARMUP:
		return
	if get_tree().paused or not (DisplayServer.window_is_focused() or _forced):
		return
	_frames += 1
	_time += dt
	if _time >= MEASURE:
		_finish(float(_frames) / maxf(_time, 0.001))


func _finish(fps: float) -> void:
	measuring = false
	var pc := preload("res://src/pc_input.gd").is_pc()
	var q := choose(fps, pc)
	Dev.set_v("auto_q", q)
	Dev.set_v("auto_fps", int(round(fps)))
	G.apply_quality()
	if not P.d.get("settings", {}).get("quality_user", false):
		P.toast.emit("Grafik automatisch auf „%s“ gestellt (%d Bilder/s gemessen). Änderbar in den Einstellungen." % [QUALITY_NAMES[q], int(round(fps))])
	node = null
	queue_free()
