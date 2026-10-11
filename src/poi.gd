extends Node3D
## Ort einer Nebenaufgabe auf der Expeditionskarte (Phase „Erkunden“). Früher waren das getrennte Aufgaben;
## jetzt liegen sie alle auf derselben Karte und sind freiwillig:
##   nest     Schleimnest zerstören (gibt eine Fundkiste)
##   bounty   Kopfgeld: Boss des Gebiets im Außenring
##   rescue   gefangener Held oder Bewohner (Käfig öffnen; der Gerettete folgt)
##   race     Rennstrecke mit Toren (nur im Fahrzeug, auf Zeit)
##   trader   fahrender Händler: tauscht Feldmünzen gegen seltene Rohstoffe
##   chest    versteckte Truhe (erst aus der Nähe sichtbar)

const D = preload("res://src/data.gd")
const Models = preload("res://src/models.gd")
const Humanoid = preload("res://src/humanoid.gd")

var w: Node3D                    # Expedition
var kind := ""
var p := Vector2.ZERO
var done := false
var failed := false
var title := ""
var reward := ""
var enemy = null
var gates: Array = []            # Wettlauf: {p, n}
var gate_idx := 0
var race_left := 0.0
var race_time := 0.0
var race_on := false
var who := ""                    # Rettung: Heldenschlüssel oder ""
var npc: Node3D
var cage: Node3D
var cage_k := 0.0
var trade_k := 0.0
var _spawn_t := 0.0
var _model: Node3D
var _snd_t := 0.0
var _ring: MeshInstance3D


func setup(world: Node3D, poi_kind: String, pos: Vector2, rng: RandomNumberGenerator) -> void:
	w = world
	kind = poi_kind
	p = pos
	position = Vector3(pos.x, 0, pos.y)
	var f: float = float(D.EXP_AREAS[w.area].factor)
	match kind:
		"nest":
			title = "Schleimnest"
			reward = "Fundkiste"
			_model = Models.nest()
			add_child(_model)
			var e = w.spawn_enemy("nest", pos, 1.0)
			e.stat = true
			e.hide = true
			e.r = 2.0
			e.mhp = 320.0 * w.hp_mult
			e.hp = e.mhp
			e.coins = int(12 * f)
			enemy = e
			e.on_death = func():
				done = true
				_model.visible = false
				w.fx.explosion(Vector3(p.x, 1.5, p.y), 5.0, Color(0.6, 0.9, 0.2))
				Sfx.play("nest_destroyed", -2.0)
				w.poi_done(self, "Nest zerstört – Fundkiste!")
			w.group(pos, 5, 6.0)
		"bounty":
			var bd: Dictionary = D.BOSSES[int(w.adef.boss)]
			title = "Kopfgeld: %s" % bd.name
			reward = "Bosskiste"
			w.group(pos, 5, 9.0)       # der Boss selbst erscheint erst, wenn der Held näher als 50 m kommt
		"rescue":
			for hk in D.HERO_ORDER:
				if int(D.HEROES[hk].unlock_area) == w.area and not P.hero_unlocked(hk):
					who = hk
			title = "Rettung: %s" % (String(D.HEROES[who].name) if who != "" else "Bewohner")
			reward = "neuer Held" if who != "" else "Münzen"
			cage = Models.cage()
			add_child(cage)
			npc = Humanoid.new()
			w.add_child(npc)
			var look := {"helm": D.C_HELM_BLUE, "suit": D.C_OLIVE, "kind": "settler", "tier": 0}
			if who != "":
				look = {"helm": D.HEROES[who].color, "suit": D.HEROES[who].suit, "kind": who, "tier": 0}
			npc.build(look)
			npc.scale = Vector3.ONE * D.CHAR_SCALE
			npc.position = Vector3(pos.x, 0.2, pos.y)
			w.group(pos, 9, 8.0)
		"race":
			title = "Wettlauf (Fahrzeug)"
			reward = "Bestzeit, Münzen"
			var pts: Array = []
			var a0 := rng.randf() * TAU
			for i in 6:
				var a := a0 + i * TAU / 6.0
				var r := rng.randf_range(D.EXP_RING_LAND + 14.0, D.EXP_RING_MID + 15.0)
				var q := Vector2(cos(a), sin(a)) * r
				if w.field.is_solid(q):
					w.field.clear_rect(q - Vector2(3, 3), q + Vector2(3, 3))
				pts.append(q)
			var prev: Vector2 = pts[-1]
			var length := 0.0
			for q2 in pts:
				var g := Models.race_gate(D.C_RED)
				g.position = Vector3(q2.x, 0, q2.y)
				var dir: Vector2 = q2 - prev
				g.rotation.y = atan2(dir.x, dir.y)
				w.add_child(g)
				gates.append({"p": q2, "n": g})
				length += prev.distance_to(q2)
				prev = q2
			p = pts[0]
			position = Vector3(p.x, 0, p.y)
			race_left = length * 1.5 / 9.0 + 20.0
			_ring = w.ring_mesh(4.0, D.C_GOLD)
			_ring.position = Vector3(p.x, 0.15, p.y)
		"trader":
			title = "Fahrender Händler"
			reward = "seltene Rohstoffe"
			_model = Models.glb("o_trader")
			add_child(_model)
			w.field.clear_rect(pos - Vector2(3, 3), pos + Vector2(3, 3))
		"chest":
			title = "Versteckte Truhe"
			reward = "Münzen, Fundkiste"
			_model = Models.chest(D.CHESTS.find.color)
			_model.scale = Vector3.ONE * 1.4
			add_child(_model)
			_model.visible = false


## Kurzer Stand für die Aufgabenliste.
func status_text() -> String:
	if done:
		return "%s ✓" % title
	match kind:
		"race":
			if race_on:
				return "%s: Tor %d/%d – %d s" % [title, gate_idx + 1, gates.size(), int(ceil(race_left))]
		"rescue":
			if cage_k > 0.0:
				return "%s: %d %%" % [title, int(cage_k * 100.0)]
	return "%s → %s" % [title, reward]


func target() -> Vector2:
	if kind == "race" and gate_idx < gates.size():
		return gates[gate_idx].p
	if kind == "bounty" and enemy != null and enemy.st != 2:
		return enemy.p
	return p


func _spawn_boss() -> void:
	var bd: Dictionary = D.BOSSES[int(w.adef.boss)]
	enemy = w.spawn_boss_at(p)
	enemy.on_death = func():
		done = true
		Music.set_mood("battle")
		w.poi_done(self, "%s besiegt!" % bd.name)
	Sfx.play("boss_arrive", -3.0)
	Music.set_mood("boss")


func tick(dt: float, pp: Vector2) -> void:
	match kind:
		"bounty":
			if enemy == null and not done and p.distance_squared_to(pp) < 2500.0:
				_spawn_boss()
		"nest":
			if done:
				return
			_spawn_t -= dt
			if _spawn_t <= 0.0:
				_spawn_t = 6.0
				var d := p.distance_to(pp)
				if d < 28.0 and w.horde.in_radius(p, 12.0).size() < 12:
					w.group(p, 2, 4.0, d < 16.0)
		"rescue":
			if npc == null:
				return
			if not done:
				if p.distance_to(pp) < 4.0 and w.hero.alive:
					cage_k += dt / 2.5
					_snd_t -= dt
					if _snd_t <= 0.0:
						_snd_t = 0.45
						Sfx.play("cage_rattle", -9.0, 0.9 + cage_k * 0.3)
					if cage_k >= 1.0:
						done = true
						cage.visible = false
						npc.cheer(1.5)
						w.fx.ring(Vector3(p.x, 0, p.y), 5.0, D.C_GOLD, 0.6)
						Sfx.play("cage_open", -3.0)
						Sfx.play("rescue_cheer", -3.0)
						if who == "":
							w.add_pack("coins", 60.0 * float(D.EXP_AREAS[w.area].factor))
						w.poi_done(self, "Befreit! %s folgt dir." % ("Der Held" if who != "" else "Der Bewohner"))
				else:
					cage_k = maxf(0.0, cage_k - dt)
				npc.tick(dt)
			else:
				var np2 := Vector2(npc.position.x, npc.position.z)
				var to := pp - np2
				var sp := 0.0
				if to.length() > 3.0:
					sp = minf(to.length() * 2.0, 9.0)
					np2 += to.normalized() * sp * dt
					npc.rotation.y = atan2(to.x, to.y)
				if to.length() > 25.0:
					np2 = pp - to.normalized() * 3.0
				npc.position = Vector3(np2.x, 0, np2.y)
				npc.move_amount = sp / 5.5
				npc.tick(dt)
		"race":
			if done:
				return
			if not race_on:
				if w.hero.mounted and gates[0].p.distance_to(pp) < 4.5:
					race_on = true
					gate_idx = 1
					race_time = 0.0
					Sfx.play("gate_pass", -2.0)
					P.toast.emit("Wettlauf gestartet – fahre durch alle Tore!")
					_update_ring()
				return
			race_time += dt
			race_left -= dt
			if gate_idx < gates.size() and gates[gate_idx].p.distance_to(pp) < 4.5:
				gate_idx += 1
				Sfx.play("gate_pass", -2.0, 1.0 + gate_idx * 0.06)
				w.fx.ring(w.hero.global_position, 5.0, D.C_GOLD, 0.5)
				_update_ring()
				if gate_idx >= gates.size():
					done = true
					w.race_time = race_time
					w.add_pack("coins", 80.0 * float(D.EXP_AREAS[w.area].factor))
					w.poi_done(self, ("Wettlauf geschafft: %.1f s" % race_time).replace(".", ","))
					return
			if race_left <= 0.0:
				race_on = false
				gate_idx = 0
				_reset_race()
				P.toast.emit("Zeit abgelaufen – fahre erneut durch das erste Tor.")
		"trader":
			if done:
				return
			if p.distance_to(pp) < 4.0 and w.hero.alive:
				trade_k += dt / 2.0
				if trade_k >= 1.0:
					var f: float = float(D.EXP_AREAS[w.area].factor)
					var price := 60.0 * f
					if float(w.loot.get("coins", 0.0)) >= price:
						w.loot["coins"] = float(w.loot.coins) - price
						var r := "shards" if w.area >= 5 else "parts"
						w.add_pack(r, 2.0)
						done = true
						Sfx.play("trade", -4.0)
						w.poi_done(self, "Getauscht: %d Feldmünzen gegen 2 %s" % [int(price), D.RES_NAME[r]])
					else:
						trade_k = 0.0
						P.toast.emit("Der Händler will %d Feldmünzen." % int(price))
			else:
				trade_k = 0.0
		"chest":
			if done:
				return
			var d2 := p.distance_squared_to(pp)
			_model.visible = d2 < 81.0 or w.hero.key == "yuki"
			if d2 < 5.0:
				done = true
				_model.visible = false
				w.chests_found += 1
				w.add_pack("coins", 40.0 * float(D.EXP_AREAS[w.area].factor))
				w.fx.ring(Vector3(p.x, 0, p.y), 3.0, D.C_GOLD, 0.6)
				Sfx.play("chest_found", -2.0)
				w.poi_done(self, "Versteckte Truhe gefunden!")


func _update_ring() -> void:
	for i in gates.size():
		gates[i].n.visible = i >= gate_idx or not race_on
	if gate_idx < gates.size():
		_ring.position = Vector3(gates[gate_idx].p.x, 0.15, gates[gate_idx].p.y)
		_ring.visible = true
	else:
		_ring.visible = false


func _reset_race() -> void:
	var length := 0.0
	var prev: Vector2 = gates[-1].p
	for g in gates:
		length += prev.distance_to(g.p)
		prev = g.p
	race_left = length * 1.5 / 9.0 + 20.0
	_update_ring()
