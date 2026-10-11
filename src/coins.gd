extends Node3D
## Münzen: fallen aus besiegten Schleimlingen, liegen am Boden und fliegen zum Helden,
## sobald er in die Nähe kommt. Alle Münzen werden mit EINEM MultiMesh gezeichnet.

const D = preload("res://src/data.gd")
const MK = preload("res://src/mk.gd")

const MAX_ITEMS := 260
const LIFETIME := 45.0

class Item:
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var value := 1.0
	var age := 0.0
	var st := 0          # 0 fliegt heraus, 1 liegt, 2 fliegt zum Helden
	var spin := 0.0

var items: Array = []
var radius := 3.4
var _mm: MultiMesh
var _rng := RandomNumberGenerator.new()
var _combo := 0.0


func _ready() -> void:
	var st := MK.begin()
	MK.cyl(st, Vector3(0, -0.05, 0), 0.26, 0.26, 0.1, 10, D.C_COIN)
	MK.cyl(st, Vector3(0, -0.06, 0), 0.17, 0.17, 0.12, 8, Color("FFE56A"))
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	var Models = load("res://src/models.gd")
	var from_glb: bool = Models.has_glb("p_coin")
	_mm.mesh = Models.glb_mesh("p_coin") if from_glb else st.commit()
	_mm.instance_count = MAX_ITEMS
	_mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = _mm
	mi.material_override = MK.mat_lin_metal() if from_glb else MK.mat_metal()
	mi.custom_aabb = AABB(Vector3(-140, -6, -140), Vector3(280, 24, 280))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func clear() -> void:
	items.clear()
	_mm.visible_instance_count = 0


## Lässt Münzen im Wert "value" an der Stelle p (x, z) fallen.
func drop(p: Vector2, value: int) -> void:
	var pieces := mini(value, 6)
	var per := float(value) / pieces
	Sfx.play_at("coin_drop", Vector3(p.x, 0, p.y), -15.0, 1.0, 0.12)
	for i in pieces:
		if items.size() >= MAX_ITEMS:
			var o: Item = items[_rng.randi() % items.size()]
			o.value += per
			continue
		var it := Item.new()
		it.p = Vector3(p.x, 0.7, p.y)
		var a := _rng.randf() * TAU
		var s := _rng.randf_range(0.8, 2.6)
		it.v = Vector3(cos(a) * s, _rng.randf_range(3.5, 5.5), sin(a) * s)
		it.value = per
		it.spin = _rng.randf() * TAU
		items.append(it)


func nearest_ground(p: Vector2, max_d: float) -> Variant:
	var best = null
	var bd := max_d * max_d
	for it: Item in items:
		if it.st == 1:
			var d := Vector2(it.p.x - p.x, it.p.z - p.y).length_squared()
			if d < bd:
				bd = d
				best = Vector2(it.p.x, it.p.z)
	return best


## Sammelt alles sofort ein (Ende einer Welle).
func collect_all() -> void:
	for it: Item in items:
		if it.st <= 1:
			it.st = 2
			it.age = 1.0


func _physics_process(dt: float) -> void:
	if G.game == null or not G.game.is_active() or G.player == null:
		return
	var pl = G.player
	var pp: Vector3 = pl.global_position
	var pr2: float = radius * radius * pl.pickup_mult * pl.pickup_mult
	_combo = maxf(0.0, _combo - dt * 4.0)
	var i := items.size() - 1
	while i >= 0:
		var it: Item = items[i]
		it.age += dt
		it.spin += dt * 4.0
		var remove := false
		match it.st:
			0:
				it.v.y -= 20.0 * dt
				it.p += it.v * dt
				if it.p.y <= 0.25:
					it.p.y = 0.25
					if it.v.y < -3.0:
						it.v = Vector3(it.v.x * 0.4, -it.v.y * 0.35, it.v.z * 0.4)
					else:
						it.st = 1
						it.age = 0.0
			1:
				if it.age > LIFETIME:
					remove = true
				elif pl.alive and Vector2(it.p.x - pp.x, it.p.z - pp.z).length_squared() < pr2:
					it.st = 2
					it.age = 0.0
			2:
				var to := pp + Vector3(0, 1.0, 0) - it.p
				var l := to.length()
				if l < 0.6:
					G.game.collect_coin(it.value)
					_combo = minf(_combo + 1.0, 14.0)
					Sfx.play("coin", -13.0, 1.0 + _combo * 0.045, 0.04)
					remove = true
				else:
					it.p += to / l * minf(l, (16.0 + it.age * 30.0) * dt)
		if remove:
			items[i] = items[items.size() - 1]
			items.pop_back()
		i -= 1


func _process(_dt: float) -> void:
	var n := mini(items.size(), MAX_ITEMS)
	for i in n:
		var it: Item = items[i]
		var s := 1.0
		if it.st == 1 and it.age > LIFETIME - 5.0:
			s = 0.55 + 0.45 * absf(sin(it.age * 9.0))
		var b := Basis(Vector3.UP, it.spin) * Basis(Vector3.RIGHT, 1.2)
		_mm.set_instance_transform(i, Transform3D(b.scaled(Vector3(s, s, s)), it.p))
	_mm.visible_instance_count = n


## Nimmt alle liegenden Münzen im Umkreis weg (Geier, Staubteufel) und liefert ihren Wert.
func take(p: Vector2, radius: float) -> float:
	var sum := 0.0
	var r2 := radius * radius
	var i := items.size() - 1
	while i >= 0:
		var it: Item = items[i]
		if it.st == 1 and Vector2(it.p.x - p.x, it.p.z - p.y).length_squared() < r2:
			sum += it.value
			items[i] = items[items.size() - 1]
			items.pop_back()
		i -= 1
	return sum

