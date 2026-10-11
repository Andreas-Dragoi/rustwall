extends Node3D
## Rohstoffquelle der Expedition (Baum, Fels, Schrott, Fass, Kristall, Scherbenader, Münzhaufen).
## Der Held steht still daneben und arbeitet sie mit Schlägen ab; jeder Schlag gibt einen Teil des Ertrags.
## Werte stehen in D.EXP_NODES. Gezeichnet wird das Blender-Modell n_<art>; Bäume kippen und lassen einen Stumpf stehen,
## Felsen, Schrott und Kristalle werden in drei Stufen kleiner.

const D = preload("res://src/data.gd")
const Models = preload("res://src/models.gd")
const MK = preload("res://src/mk.gd")

var kind := ""
var def: Dictionary
var res := ""
var p := Vector2.ZERO
var total := 0.0
var left := 0.0
var hits := 1
var hits_done := 0
var ring := 0                    # 0 Landezone, 1 Mittelring, 2 Außenring
var model: Node3D
var stage := 1
var gone := false
var _shake := 0.0
var _fall := -1.0
var _fall_dir := Vector2.RIGHT
var _crown: Node3D
var cells := PackedInt32Array()   # vom Richtungsfeld gesperrte Felder; nach dem Abbau wieder frei


func setup(node_kind: String, pos: Vector2, amount: float, ring_idx: int, yaw: float) -> void:
	kind = node_kind
	def = D.EXP_NODES[kind]
	res = String(def.res)
	p = pos
	total = maxf(1.0, amount)
	left = total
	hits = int(def.hits)
	ring = ring_idx
	position = Vector3(pos.x, 0, pos.y)
	rotation.y = yaw
	_make_model()
	set_process(false)


func _ready() -> void:
	set_process(_shake > 0.0 or _fall >= 0.0)


func _model_name() -> String:
	if def.has("stages"):
		return "%s_%d" % [String(def.model), stage]
	return String(def.model)


func _make_model() -> void:
	if model != null:
		model.queue_free()
	model = Models.glb(_model_name())
	add_child(model)
	_crown = Models.find(model, "sway_crown")
	# weit entfernte Quellen werden nicht gezeichnet (Zeichenaufrufe)
	for mi in model.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).visibility_range_end = 75.0


## Wie weit darf der Held entfernt stehen?
func reach() -> float:
	return D.EXP_MINE_RANGE + (1.4 if kind == "tree_big" or kind == "wreck" else 1.1)


## Ein Schlag: gibt die Menge zurück, die herausspringt (0, wenn nichts mehr da ist).
func hit() -> float:
	if gone or left <= 0.0:
		return 0.0
	hits_done += 1
	var take := total / float(hits)
	if hits_done >= hits:
		take = left
	take = minf(take, left)
	left -= take
	_shake = 0.35
	set_process(true)
	if def.has("stages"):
		var k := left / total
		var st := 1 if k > 0.66 else (2 if k > 0.33 else 3)
		if st != stage and left > 0.0:
			stage = st
			_make_model()
	if left <= 0.001:
		left = 0.0
		_deplete()
	return take


func _deplete() -> void:
	gone = true
	if G.field != null and cells.size() > 0:
		G.field.release_cells(cells)    # Stumpf und Reste sind begehbar
		cells = PackedInt32Array()
	if bool(def.get("fall", false)):
		_fall = 0.0
		var hp: Vector2 = G.player.pos2() if G.player != null else p + Vector2.LEFT
		_fall_dir = (p - hp).normalized()
		if _fall_dir == Vector2.ZERO:
			_fall_dir = Vector2.RIGHT
		Sfx.play_at("tree_fall", global_position, -4.0, 1.0, 0.1)
	else:
		if G.fx:
			G.fx.puff(global_position + Vector3(0, 0.6, 0), D.RES_COLOR.get(res, Color.WHITE).lightened(0.3), 14, 1.2)
		Sfx.play_at("node_break", global_position, -5.0, 1.0, 0.1)
		visible = false


func _process(dt: float) -> void:
	if _shake <= 0.0 and _fall < 0.0:
		set_process(false)
		return
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - dt)
		var a := sin(_shake * 60.0) * _shake * 0.25
		if _crown != null:
			_crown.rotation.z = a
		else:
			model.rotation.z = a * 0.4
	if _fall >= 0.0:
		_fall += dt
		var k := minf(_fall / 1.1, 1.0)
		var ang := k * k * PI * 0.48
		var axis := Vector3(_fall_dir.y, 0, -_fall_dir.x)
		model.transform.basis = Basis(axis.normalized(), ang) if axis.length() > 0.01 else Basis.IDENTITY
		if _fall >= 1.1 and _fall - dt < 1.1 and G.fx:
			var tip := global_position + Vector3(_fall_dir.x, 0, _fall_dir.y) * 4.0
			G.fx.puff(tip + Vector3(0, 0.3, 0), Color(0.75, 0.65, 0.45), 18, 1.4)
			if G.cam:
				G.cam.shake(0.15)
		if _fall > 1.8:
			_fall = -1.0
			model.queue_free()
			model = Models.glb("n_stump")
			add_child(model)
