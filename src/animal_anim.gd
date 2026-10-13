extends RefCounted
## Paket H (V6): Blender-Clips für Hund, Katze und Singvögel der Basis (models/a_<tier>_rig.glb aus blender/animals_rig.py).
## src/wildlife.gd steuert Ort und Zustand wie bisher; hier wird je Bild der passende Clip gewählt (mit weicher Überblendung).
## Ohne das Modell bleibt alles beim alten Verfahren (bewegte Teile).

const Models = preload("res://src/models.gd")
const RIGGED := {"dog": "a_dog_rig", "cat": "a_cat_rig", "bird": "a_bird_rig"}
const FADE := 0.2


## Modellname für eine Tierart: die Fassung mit Skelett, wenn es sie gibt.
static func model_for(kind: String, fallback: String) -> String:
	if RIGGED.has(kind) and Models.has_glb(String(RIGGED[kind])):
		return String(RIGGED[kind])
	return fallback


static func player_of(n: Node) -> AnimationPlayer:
	return n.find_child("AnimationPlayer", true, false) as AnimationPlayer


## Wählt den Clip nach Zustand und gemessenem Tempo; a = Eintrag aus wildlife.animals (mit a.ap).
static func update(a: Dictionary, dt: float) -> void:
	var ap: AnimationPlayer = a.get("ap")
	if ap == null or not is_instance_valid(ap) or dt <= 0.0:
		return
	var n: Node3D = a.n
	var p: Vector3 = n.position
	var lp: Vector3 = a.get("lp", p)
	a["lp"] = p
	var v := Vector2(p.x - lp.x, p.z - lp.z).length() / dt
	a["v"] = lerpf(float(a.get("v", 0.0)), v, minf(1.0, dt * 8.0))
	var sp := float(a.v)
	var st := String(a.st)
	var clip := "idle"
	match String(a.kind):
		"dog":
			if st == "sit":
				clip = "sit"
			elif st == "bark":
				clip = "bark"
			elif sp > 3.6:
				clip = "run"
			elif sp > 0.3:
				clip = "walk"
		"cat":
			if st == "sleep":
				clip = "sleep"
			elif st == "sit":
				clip = "sit"
			elif sp > 3.0:
				clip = "run"
			elif sp > 0.2 or st == "rub":
				clip = "walk"
		"bird":
			if st == "fly":
				clip = "fly"
			elif st == "peck":
				clip = "peck"
	if not ap.has_animation(clip):
		return
	if String(a.get("clip", "")) != clip:
		a["clip"] = clip
		ap.play(clip, FADE)
	# Tempo der Gangart an die Bewegung anpassen (rutscht weniger)
	if clip == "walk":
		ap.speed_scale = clampf(sp / (1.6 if a.kind == "dog" else 1.2), 0.6, 1.6)
	elif clip == "run":
		ap.speed_scale = clampf(sp / (5.5 if a.kind == "dog" else 4.5), 0.7, 1.5)
	else:
		ap.speed_scale = 1.0
