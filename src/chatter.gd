extends Node
## V6 Paket E – Bewohner-Sprechblasen in der Hauptbasis (Kapitel 7.1 / 8.2).
## Alle paar Sekunden sagt ein sichtbarer Bewohner (oder eine gerettete Figur) einen kurzen Satz, passend zur Lage:
## Flut heute / bald, Lob nach einem Flut-Sieg, Klage nach Schaden, Regen / schönes Wetter, Morgen / Mittag / Abend / Nacht,
## offener Wunsch, Beruf, Stand der Geschichte – sonst etwas Allgemeines. Sparsam: höchstens DG.CHAT_MAX Blasen,
## kein Satz zweimal kurz hintereinander, nichts während Flut, Menüs oder Szenen.
## tap_line(npc, board) liefert den Satz beim Antippen (npc_board.tap, story_town.tap).

const D = preload("res://src/data.gd")
const DG = preload("res://src/data_geschichte.gd")
const Story = preload("res://src/story.gd")

var w: Node3D                        # base_world
var speech: CanvasLayer
var town                             # story_town.gd (gerettete Figuren) oder null
var _t := 4.0
var _rng := RandomNumberGenerator.new()
var spoken := 0                      # (Test)
var last_cat := ""                   # (Test) Art des letzten Satzes
static var _recent: Array = []


func _ready() -> void:
	_rng.randomize()
	_t = _rng.randf_range(3.0, 6.0)


func _process(dt: float) -> void:
	if w == null or not is_instance_valid(w) or w.get("npc_board") == null:
		return
	_t -= dt
	if _t > 0.0:
		return
	_t = _rng.randf_range(DG.CHAT_EVERY[0], DG.CHAT_EVERY[1])
	speak_once()


## Ein Satz von einem passenden Sprecher. Rückgabe: gesagter Text oder "".
func speak_once(force := false) -> String:
	if not force and not _allowed():
		return ""
	if speech.count() >= DG.CHAT_MAX:
		return ""
	var cand := _speakers()
	if cand.is_empty():
		return ""
	var n = cand[_rng.randi() % cand.size()]
	var key := String(n.get_meta("story", "")) if n.has_meta("story") else ""
	var line := ""
	if key != "" and DG.FIG_LINES.has(key) and _rng.randf() < 0.7:
		line = _pick(DG.FIG_LINES[key])
		last_cat = "figur"
	else:
		line = line_for(n, w.npc_board, _rng)
	if line == "":
		return ""
	speech.say(n.h, line, DG.CHAT_TIME + 0.03 * line.length())
	spoken += 1
	return line


func _allowed() -> bool:
	if w.mode != "peace" or get_tree().paused or Story.playing():
		return false
	if G.main != null and (G.main.screens.is_open() or G.main.hud.modal_open() or G.main.menu.visible):
		return false
	return true


## Sichtbare Sprecher nahe der Kamera (Bewohner und Gerettete), die gerade keine Blase haben.
func _speakers() -> Array:
	var cam: Camera3D = w.get_viewport().get_camera_3d()
	var out: Array = []
	var all: Array = []
	all.append_array(w.npc_board.npcs)
	if town != null:
		all.append_array(town.npcs)
	for n in all:
		if n.hidden or not is_instance_valid(n.h) or not n.h.visible or speech.has_speaker(n.h):
			continue
		if cam != null:
			var p3: Vector3 = n.h.global_position + Vector3(0, 1.5, 0)
			if cam.is_position_behind(p3) or cam.global_position.distance_to(p3) > DG.CHAT_DIST * 2.5:
				continue
			var sp := cam.unproject_position(p3)
			var vs := w.get_viewport().get_visible_rect().size
			# nur in der Bildmitte: links und rechts stehen die Tafeln und Knöpfe des HUD
			if sp.x < vs.x * 0.24 or sp.y < vs.y * 0.22 or sp.x > vs.x * 0.74 or sp.y > vs.y * 0.86:
				continue
		out.append(n)
	return out


static func _pick(list: Array, rng: RandomNumberGenerator = null) -> String:
	if list.is_empty():
		return ""
	var r := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var free: Array = list.filter(func(s): return not _recent.has(s))
	if free.is_empty():
		free = list
	var s: String = free[r.randi() % free.size()]
	_recent.append(s)
	while _recent.size() > DG.CHAT_RECENT:
		_recent.pop_front()
	return s


## Arten mit Gewicht für die Lage dieses Bewohners: [[art, gewicht], ...]
static func moods(n, board) -> Array:
	var out: Array = []
	var w = board.w if board != null else null
	if P.flood_available():
		out.append(["flut_heute", 5.0])
	elif P.flood_seconds_left() < 2.0 * D.DAY_SECONDS:
		out.append(["flut_bald", 3.0])
	var s := Story.st()
	if not s.is_empty() and P.now() - float(s.get("win_t", -99999.0)) < DG.CHAT_WIN_TIME:
		out.append(["sieg", 5.0])
	if board != null and bool(board.get("repair_mode")):
		out.append(["schaden", 4.0])
	if n != null and n.get("wish") is Dictionary and not (n.wish as Dictionary).is_empty():
		out.append(["wunsch", 4.0])
	if w != null and w.get("weather") != null and w.weather != null:
		if bool(w.weather.raining) or float(w.weather.rain_k) > 0.3:
			out.append(["regen", 3.0])
		elif float(w.weather.night_k) < 0.3:
			out.append(["schoen", 1.2])
	var night: bool = w != null and w.has_method("is_night") and w.is_night()
	if night:
		out.append(["nacht", 3.0])
	elif board != null and String(board.get("phase")) in ["morgen", "mittag", "abend"]:
		out.append([String(board.phase), 2.5])
	if n != null and DG.CHAT.has(String(n.get("job"))):
		out.append([String(n.job), 2.0])
	if Story.progress() >= 0:
		out.append(["geschichte", 1.5])
	out.append(["allgemein", 2.0])
	return out


static func line_for(n, board, rng: RandomNumberGenerator = null) -> String:
	var r := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var ms := moods(n, board)
	var tot := 0.0
	for m in ms:
		tot += float(m[1])
	var x := r.randf() * tot
	var cat := "allgemein"
	for m in ms:
		x -= float(m[1])
		if x <= 0.0:
			cat = String(m[0])
			break
	if cat == "geschichte":
		var pr := clampi(Story.progress(), 0, DG.CHAT_STORY.size() - 1)
		return _pick(DG.CHAT_STORY[pr], r)
	return _pick(DG.CHAT.get(cat, DG.CHAT.allgemein), r)


## Satz beim Antippen eines Bewohners (npc_board.tap).
static func tap_line(n, board) -> String:
	var r := RandomNumberGenerator.new()
	r.randomize()
	if n != null and n.has_meta("story") and DG.FIG_LINES.has(String(n.get_meta("story"))):
		return _pick(DG.FIG_LINES[String(n.get_meta("story"))], r)
	if r.randf() < 0.45:
		return _pick(DG.CHAT.tippen, r)
	return line_for(n, board, r)
