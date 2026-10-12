extends Node3D
## Fund-Ort eines Begleiters auf der Expeditionskarte (Paket B): ein gefangener Begleiter im Käfig, bewacht von
## einer kleinen Gruppe. Neben dem Käfig stehen bleiben öffnet ihn (wie „Rettung“); danach gehört der Begleiter dir.
## Benimmt sich wie ein Ort aus poi.gd (kind, p, done, title, reward, status_text, target, tick) und steht in
## expedition.pois – erscheint also in der Aufgabenliste und auf der Karte (Phase „Erkunden“).
## Nur in Gebieten, in denen es noch einen Begleiter zu finden gibt (companion_data.gd, get.find).

const D = preload("res://src/data.gd")
const CD = preload("res://src/companion_data.gd")
const Models = preload("res://src/models.gd")

const OPEN_TIME := 2.5
const OPEN_RADIUS := 3.6

var w: Node3D
var kind := "pet"
var p := Vector2.ZERO
var done := false
var failed := false
var title := ""
var reward := ""
var who := ""                    # Schlüssel des Begleiters
var cage: Node3D
var pet: Node3D
var open_k := 0.0
var _snd_t := 0.0
var _t := 0.0
var _gone_t := -1.0
var guards := 6                  # Wachen um den Käfig (in der Landezone weniger)


## Legt (höchstens) einen Fund-Ort in die Expedition, wenn es dort noch einen Begleiter zu finden gibt.
static func place(ex: Node3D) -> Node3D:
	var keys: Array = CD.findable(int(ex.area))
	if keys.is_empty() or ex.mission == "befreiung":
		return null
	var rng := RandomNumberGenerator.new()          # eigener Zufall: die übrige Karte bleibt unverändert
	rng.seed = hash("rustwall-pet|%d|%d" % [int(ex.area), P.day_index()])
	var taken: Array = [Vector2.ZERO]
	for q in ex.pois:
		taken.append(q.p)
	# Paket Welt: steht die Außenbasis noch nicht, liegt der Käfig in der Landezone – sonst sähe man ihn
	# beim ersten Besuch nie (die Sperren fallen erst nach dem Großangriff).
	var first: bool = P.outpost_level(String(ex.adef.key)) < 1
	var at = null
	if first:
		at = ex._pick(16.0, 10.0, taken + [ex.outpost.C], D.EXP_RING_LAND - 6.0, rng)
	if at == null:
		first = false
		at = ex._pick(D.EXP_RING_LAND + 14.0, 20.0, taken, D.EXP_RING_MID + 10.0, rng)
	if at == null:
		at = ex._pick(D.EXP_RING_LAND + 8.0, 10.0, taken, 999.0, rng)
	if at == null:
		return null
	var f = load("res://src/companion_find.gd").new()
	f.guards = 3 if first else 6
	ex.add_child(f)
	f.setup(ex, String(keys[rng.randi() % keys.size()]), at)
	ex.pois.append(f)
	return f


func setup(world: Node3D, key: String, pos: Vector2) -> void:
	w = world
	who = key
	p = pos
	position = Vector3(pos.x, 0, pos.y)
	var def: Dictionary = CD.def(key)
	title = "Gefangener Begleiter"
	reward = String(def.name)
	cage = Models.cage()
	add_child(cage)
	if Models.has_glb("comp_" + key):
		pet = Models.glb("comp_" + key)
		add_child(pet)
		pet.rotation.y = 0.6
	w.group(pos, guards, 7.0)


func status_text() -> String:
	if done:
		return "%s ✓" % title
	if open_k > 0.0:
		return "%s: %d %%" % [title, int(open_k * 100.0)]
	return "%s → %s" % [title, reward]


func target() -> Vector2:
	return p


func tick(dt: float, pp: Vector2) -> void:
	_t += dt
	if pet != null and is_instance_valid(pet):
		var body := Models.find(pet, "body")
		if body != null and not done:
			body.rotation.z = sin(_t * 1.3) * 0.06            # traurig hin und her
	if done:
		return
	if p.distance_to(pp) < OPEN_RADIUS and w.hero.alive:
		open_k += dt / OPEN_TIME
		_snd_t -= dt
		if _snd_t <= 0.0:
			_snd_t = 0.45
			Sfx.play("cage_rattle", -9.0, 0.9 + open_k * 0.3)
		if open_k >= 1.0:
			free_pet()
	else:
		open_k = maxf(0.0, open_k - dt)


## Käfig auf: der Begleiter gehört jetzt dem Spieler.
func free_pet() -> void:
	if done:
		return
	done = true
	open_k = 1.0
	if cage != null:
		cage.visible = false
	var fresh := CD.give(who, "find")
	if w.fx != null:
		w.fx.ring(Vector3(p.x, 0, p.y), 5.0, D.C_GOLD, 0.6)
		w.fx.confetti(Vector3(p.x, 1.0, p.y), 3)
	Sfx.play("cage_open", -3.0)
	Sfx.play("comp_free", -3.0)
	if pet != null:
		pet.visible = false
		if w.fx != null:
			w.fx.puff(Vector3(p.x, 0.6, p.y), Color(1.0, 0.95, 0.7), 12, 1.0)
	var nm := String(CD.def(who).name)
	if fresh:
		w.poi_done(self, "Befreit! %s gehört jetzt zu deiner Truppe (Bildschirm „Begleiter“)." % nm)
	else:
		w.poi_done(self, "Befreit! %s läuft fröhlich davon." % nm)
