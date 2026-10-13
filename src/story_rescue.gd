extends Node3D
## V6 Paket E – Rettung einer Figur der Geschichte als Ereignis in der Expedition (Kapitel 4.3). Benimmt sich wie ein Ort
## aus poi.gd (kind, p, done, title, reward, status_text, target, tick) und steht in expedition.pois – erscheint also in der
## Aufgabenliste und auf der Karte (Phase „Erkunden“), wie die anderen Orte.
##   camp    Gegnerlager (Staubebene): erst alle Wachen im Lager vertreiben, dann am Käfig stehen bleiben
##   cocoon  Schleimfalle (Sumpfwerk): den Kokon zerschießen (unbewegliches Ziel mit Lebenspunkten)
##   ice     Käfig aus Eis (Frostpass): lange am Käfig stehen bleiben und Eis aufhacken, während Eiswesen angreifen
## Danach ist die Figur gerettet (Story.rescue) und zieht in die Basis; vor Ort jubelt sie und winkt dem Helden nach.

const D = preload("res://src/data.gd")
const DG = preload("res://src/data_geschichte.gd")
const Models = preload("res://src/models.gd")
const Humanoid = preload("res://src/humanoid.gd")
const Story = preload("res://src/story.gd")

var w: Node3D                    # Expedition
var kind := "story"
var who := ""                    # Schlüssel aus DG.RESCUES
var mode := ""                   # camp | cocoon | ice
var p := Vector2.ZERO
var done := false
var failed := false
var title := ""
var reward := ""
var open_k := 0.0
var enemy = null                 # Kokon (unbewegliches Ziel)
var fig: Node3D                  # die Figur
var cage: Node3D
var prop: Node3D
var _snd_t := 0.0
var _wave_t := 0.0
var _t := 0.0
var _after := -1.0


## Legt (höchstens) eine Rettung in die Expedition, wenn hier noch eine Figur der Geschichte gefangen ist.
static func place(ex: Node3D) -> Node3D:
	if String(ex.get("mission")) == "befreiung":
		return null
	var key := ""
	for k in DG.RESCUE_ORDER:
		if int(DG.RESCUES[k].area) == int(ex.area) and not Story.rescued(k):
			key = k
			break
	if key == "":
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("rustwall-story|%s|%d" % [key, P.day_index()])
	var taken: Array = [Vector2.ZERO]
	for q in ex.pois:
		taken.append(q.p)
	var at = _spot(ex, taken, rng)
	if at == null:
		return null
	var n = load("res://src/story_rescue.gd").new()
	ex.add_child(n)
	n.setup(ex, key, at)
	ex.pois.append(n)
	return n


## Freier Platz im Mittelring (hinter den Sperren: erreichbar in der Phase „Erkunden“), mit Abstand zu den anderen Orten.
## Eigene Suche, weil die erreichbaren Felder der Karte beim ersten Besuch nur die Landezone umfassen.
static func _spot(ex: Node3D, taken: Array, rng: RandomNumberGenerator):
	var solid_map: PackedByteArray = ex._outer_solid if not ex._outer_solid.is_empty() else ex.field.solid
	for k in 400:
		var near: float = 22.0 if k < 150 else (14.0 if k < 300 else 8.0)
		var a := rng.randf() * TAU
		var r := rng.randf_range(D.EXP_RING_LAND + 12.0, D.EXP_RING_MID - 6.0)
		var p := Vector2(cos(a), sin(a)) * r
		if absf(p.x) > ex.HALFM - 10.0 or absf(p.y) > ex.HALFM - 10.0:
			continue
		if p.distance_to(ex.outpost.C) < 16.0 or ex._near_passage(p, 7.0):
			continue
		var ok := true
		for o in taken:
			if p.distance_to(o) < near:
				ok = false
				break
		if not ok:
			continue
		var solid := false
		for d in [Vector2.ZERO, Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
			if solid_map[ex.field.idx(p + d)] != 0:          # beim ersten Besuch gilt alles hinter den Sperren als fest: echte Karte nehmen
				solid = true
		if not solid:
			return p
	return null


func setup(world: Node3D, key: String, pos: Vector2) -> void:
	w = world
	who = key
	p = pos
	position = Vector3(pos.x, 0, pos.y)
	var r: Dictionary = DG.RESCUES[key]
	mode = String(r.kind)
	title = "%s: %s" % [String(r.event), String(r.name)]
	reward = "zieht in die Basis"
	w.field.clear_rect(pos - Vector2(4, 4), pos + Vector2(4, 4))
	fig = Humanoid.new()
	add_child(fig)
	fig.build({"kind": key})
	fig.scale = Vector3.ONE * D.CHAR_SCALE
	match mode:
		"camp":
			if Models.has_glb("st_camp"):
				prop = Models.glb("st_camp")
				add_child(prop)
			cage = Models.cage()
			add_child(cage)
			fig.play("sit", true)
			fig.set_face("pain", 9999.0)
			_guards(pos, DG.CAMP_GUARDS, 6.0, false)
		"cocoon":
			if Models.has_glb("st_cocoon"):
				prop = Models.glb("st_cocoon")
				add_child(prop)
			fig.visible = false
			var e = w.spawn_enemy("nest", pos, 1.0)
			e.stat = true
			e.hide = true
			e.r = 1.4
			e.mhp = DG.COCOON_HP * float(w.hp_mult)
			e.hp = e.mhp
			e.coins = 0
			enemy = e
			e.on_death = func(): _free_now()
			_guards(pos + Vector2(3, 3), DG.COCOON_GUARDS, 6.0, false)
		"ice":
			if Models.has_glb("st_icecage"):
				prop = Models.glb("st_icecage")
				add_child(prop)
			fig.set_face("strain", 9999.0)
			_guards(pos, DG.ICE_GUARDS, 7.0, false)
	if prop != null:
		var an := preload("res://src/anim.gd").collect(prop)
		if w.get("_anims") != null:
			w._anims.append_array(an)


## Wachen um den Ort. Wie expedition.group(), aber mit der echten Karte (beim ersten Besuch gilt alles hinter den
## Sperren für das Richtungsfeld als fest – dort würde group() niemanden aufstellen).
func _guards(c: Vector2, n: int, leash: float, aggro: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("story-guards|%s|%d" % [who, int(_t * 10.0)])
	var solid_map: PackedByteArray = w._outer_solid if not w._outer_solid.is_empty() else w.field.solid
	n = int(ceil(n * float(D.DIFFS[int(w.diff)].count)))
	for i in n:
		if w.horde.alive >= G.max_alive() - 10:
			return
		var q := c + Vector2(rng.randf_range(-leash, leash), rng.randf_range(-leash, leash)) * 0.7
		var ix: int = w.field.idx(q)
		if ix < 0 or solid_map[ix] != 0 or q.distance_to(p) < 1.6:
			continue
		var e = w.spawn_enemy("guard", q)
		e.home = c
		e.leash = leash
		e.aggro = aggro


func status_text() -> String:
	if done:
		return "%s ✓" % title
	match mode:
		"camp":
			var left := guards_left()
			if left > 0:
				return "%s: noch %d Wachen" % [title, left]
			if open_k > 0.0:
				return "%s: %d %%" % [title, int(open_k * 100.0)]
		"cocoon":
			if enemy != null and enemy.hp < enemy.mhp:
				return "%s: Kokon %d %%" % [title, int(100.0 * enemy.hp / maxf(1.0, enemy.mhp))]
		"ice":
			if open_k > 0.0:
				return "%s: Eis %d %%" % [title, int(open_k * 100.0)]
	return "%s → %s" % [title, reward]


func target() -> Vector2:
	return p


func guards_left() -> int:
	if w == null or w.horde == null:
		return 0
	var n := 0
	for e in w.horde.in_radius(p, DG.CAMP_CLEAR_R):
		if e != enemy:
			n += 1
	return n


func tick(dt: float, pp: Vector2) -> void:
	_t += dt
	if done:
		return
	if fig != null and fig.visible:
		fig.tick(dt)
		fig.look_target = Vector3(pp.x, 1.5, pp.y) if p.distance_to(pp) < 12.0 else null
	match mode:
		"camp":
			if p.distance_to(pp) < DG.RESCUE_R and w.hero.alive:
				if guards_left() > 0:
					_snd_t -= dt
					if _snd_t <= 0.0:
						_snd_t = 3.0
						P.toast.emit("Erst die Wachen im Lager vertreiben!")
					return
				_hold(dt, DG.CAMP_OPEN_TIME, "cage_rattle")
			else:
				open_k = maxf(0.0, open_k - dt)
		"ice":
			if p.distance_to(pp) < DG.RESCUE_R and w.hero.alive:
				_hold(dt, DG.ICE_OPEN_TIME, "ice_hack")
				_wave_t -= dt
				if _wave_t <= 0.0:
					_wave_t = DG.ICE_WAVE_EVERY
					if w.horde.alive < G.max_alive() - 20:
						var a := _t * 1.7
						_guards(p + Vector2(cos(a), sin(a)) * 9.0, 2, 3.0, true)
			else:
				open_k = maxf(0.0, open_k - dt * 0.5)
		"cocoon":
			if prop != null and enemy != null:
				var k := 1.0 - 0.25 * (1.0 - float(enemy.hp) / maxf(1.0, float(enemy.mhp)))
				prop.scale = Vector3.ONE * k


func _hold(dt: float, total: float, snd: String) -> void:
	open_k += dt / total
	_snd_t -= dt
	if _snd_t <= 0.0:
		_snd_t = 0.45
		Sfx.play(snd, -8.0, 0.9 + open_k * 0.3)
		if mode == "ice" and w.fx != null:
			w.fx.puff(Vector3(p.x, 1.2, p.y), Color(0.85, 0.95, 1.0), 6, 1.2)
	if open_k >= 1.0:
		_free_now()


## Die Figur ist frei.
func _free_now() -> void:
	if done:
		return
	done = true
	open_k = 1.0
	if cage != null:
		cage.visible = false
	if mode in ["cocoon", "ice"] and prop != null:
		if w.fx != null:
			var col := Color(0.6, 0.9, 0.25) if mode == "cocoon" else Color(0.8, 0.95, 1.0)
			w.fx.explosion(Vector3(p.x, 1.2, p.y), 3.0, col)
			w.fx.puff(Vector3(p.x, 1.0, p.y), col, 18, 1.6)
		prop.visible = false
		Sfx.play("rescue_cocoon_pop" if mode == "cocoon" else "rescue_ice_break", -2.0)
	if fig != null:
		fig.visible = true
		fig.stop_clip()
		fig.set_face("joy", 4.0)
		fig.cheer(2.5)
	if w.fx != null:
		w.fx.ring(Vector3(p.x, 0, p.y), 5.0, D.C_GOLD, 0.6)
		w.fx.confetti(Vector3(p.x, 1.2, p.y), 3)
	Sfx.play("cage_open", -3.0)
	Sfx.play("rescue_cheer", -3.0)
	Story.rescue(who)
	P.add_hero_xp(w.hero.key, DG.RESCUE_XP)
	var r: Dictionary = DG.RESCUES[who]
	w.poi_done(self, "Befreit! %s zieht in deine Basis." % String(r.name))
	_after = 0.0


func _process(dt: float) -> void:
	if _after < 0.0 or fig == null or not is_instance_valid(fig):
		return
	_after += dt
	fig.tick(dt)
	if _after > 3.0 and _after < 4.0:
		fig.play("wave", false)
	if _after > 6.5:
		# macht sich auf den Weg zur Außenbasis (verblasst)
		fig.position += Vector3(0, 0, -1).rotated(Vector3.UP, fig.rotation.y) * dt * 2.0
		fig.move_amount = 0.35
		if _after > 9.0:
			fig.visible = false
			set_process(false)
