extends Node3D
## Animierte Vorschau eines Begleiters (Bildschirm „Begleiter“, Paket Welt): läuft auf der Stelle, schaut sich um,
## wedelt, flattert, hüpft ab und zu vor Freude. Bewegt dieselben Teile wie companion.gd (Beine, Flügel, Kopf,
## Schwanz, Rotoren) – nur ohne Welt, Weg und Ladung.

const CD = preload("res://src/companion_data.gd")
const Models = preload("res://src/models.gd")
const LEG_PHASE := {"leg_fl": 1.0, "leg_br": 1.0, "leg_mr": 1.0, "leg_fr": -1.0, "leg_bl": -1.0, "leg_ml": -1.0, "leg_l": 1.0, "leg_r": -1.0}

var key := ""
var model: Node3D
var body: Node3D
var head: Node3D
var tail: Node3D
var legs: Array = []
var wings: Array = []
var arms: Array = []
var rotors: Array = []
var fly := false
var t := 0.0
var ph := 0.0
var _body_y := 0.0
var _joy := 0.0
var _next_joy := 2.5
var frames := 0                 # (Test) so oft bewegt


func setup(k: String) -> Node3D:
	key = k
	model = Models.glb("comp_" + k)
	add_child(model)
	fly = String(CD.def(k).get("move", "")) == "fly"
	body = Models.find(model, "body")
	head = Models.find(model, "head")
	tail = Models.find(model, "tail")
	for nm in LEG_PHASE:
		var l := Models.find(model, nm)
		if l != null:
			legs.append([l, float(LEG_PHASE[nm])])
	for nm in ["wing_l", "wing_r"]:
		var wg := Models.find(model, nm)
		if wg != null:
			wings.append([wg, -1.0 if nm == "wing_l" else 1.0])
	for nm in ["arm_l", "arm_r"]:
		var a := Models.find(model, nm)
		if a != null:
			arms.append([a, -1.0 if nm == "arm_l" else 1.0])
	for n in model.find_children("spin_*", "Node3D", true, false):
		rotors.append(n)
	if body != null:
		_body_y = body.position.y
	return self


## Kurzer Freudensprung (z. B. beim Auswählen).
func cheer() -> void:
	_joy = 1.0


func _process(dt: float) -> void:
	t += dt
	frames += 1
	ph += dt * 6.5
	_next_joy -= dt
	if _next_joy <= 0.0:
		_next_joy = 5.0
		_joy = 1.0
	_joy = maxf(0.0, _joy - dt)
	var sw := sin(ph)
	var hop := absf(sin(_joy * PI * 3.0)) * 0.18 * minf(_joy * 2.0, 1.0) if _joy > 0.0 else 0.0
	model.position.y = hop
	if body != null:
		body.position.y = _body_y + (sin(t * 2.4) * 0.06 if fly else absf(sin(ph)) * 0.03)
		body.rotation.x = sin(ph * 2.0) * 0.03
	for l in legs:
		(l[0] as Node3D).rotation.x = sw * 0.5 * float(l[1])
	for a in arms:
		(a[0] as Node3D).rotation.x = -sw * 0.45 * float(a[1]) - (1.1 if _joy > 0.0 else 0.0)
	for wg in wings:
		(wg[0] as Node3D).rotation.z = sin(t * (30.0 if key == "gluehwurm" else 11.0)) * (0.25 if key == "gluehwurm" else 0.5) * float(wg[1])
	for r in rotors:
		(r as Node3D).rotate_y(dt * 30.0)
	if tail != null:
		var wag := sin(t * (13.0 if _joy > 0.0 else 3.0)) * (0.5 if _joy > 0.0 else 0.2)
		if key == "biber":
			tail.rotation.x = wag * 0.6
		else:
			tail.rotation.y = wag
	if head != null:
		head.rotation = Vector3(-0.3 if _joy > 0.0 else sin(ph * 2.0) * 0.05, sin(t * 0.7) * 0.4, 0.0)
