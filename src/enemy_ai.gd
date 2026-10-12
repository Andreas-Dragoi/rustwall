extends RefCounted
## Verhaltens-Bausteine der Gegner (Kapitel 11.5). Jede Art nennt in D.ENEMIES[t].ai ihre Bausteine;
## die Stellwerte stehen als weitere Felder im selben Eintrag. Die Horde (src/horde.gd) ruft:
##   pre()            vor Angriff und Bewegung – true heißt: der Baustein hat den Schritt übernommen
##   strike()         statt des gewöhnlichen Schlags – true heißt: erledigt
##   modify_damage()  ändert eingehenden Schaden (Frontpanzer, Teil-Leben, Flughöhe)
##   on_hit() / on_death() / tick_down() / tick_portal() / boss_special()
## Außerdem verwaltet diese Datei die feindlichen Bodenflächen (Sporen, Gift, Feuer, Säure, Eis).
##
## Bausteine: charge, pounce, pack, burrow, ranged_arc, ranged_line, front_armor, revive, split, steal, pull,
## freeze_tower, stun_tower, aura_buff, heal, summon_portal, dive, roll_grow, trail_fire, death_cloud, flee –
## dazu siege, regen, blink, push, zigzag, shell, tower_hunter, leap, latch, segments, chill, howl, ice_slide,
## knockback, double_freeze, strafe, shockwave, laugh.
## Paket Z (Vulkaninsel): lava_bath (heilt nahe fließender Lava), harden (Kruste verhärtet nach Treffern), Miniboss-Fähigkeit
## „lava“ und Boss-Sonderangriff „eruption“ (Lavabomben mit roten Bodenmarkern).

const D = preload("res://src/data.gd")
const MK = preload("res://src/mk.gd")

const F_CHARGE := 1 << 0
const F_POUNCE := 1 << 1
const F_PACK := 1 << 2
const F_BURROW := 1 << 3
const F_ARC := 1 << 4
const F_LINE := 1 << 5
const F_FRONT := 1 << 6
const F_REVIVE := 1 << 7
const F_SPLIT := 1 << 8
const F_STEAL := 1 << 9
const F_PULL := 1 << 10
const F_FREEZE_T := 1 << 11
const F_STUN_T := 1 << 12
const F_AURA := 1 << 13
const F_HEAL := 1 << 14
const F_PORTAL := 1 << 15
const F_DIVE := 1 << 16
const F_ROLL := 1 << 17
const F_TRAIL := 1 << 18
const F_CLOUD := 1 << 19
const F_FLEE := 1 << 20
const F_SIEGE := 1 << 21
const F_REGEN := 1 << 22
const F_BLINK := 1 << 23
const F_PUSH := 1 << 24
const F_ZIGZAG := 1 << 25
const F_SHELL := 1 << 26
const F_TOWERHUNT := 1 << 27
const F_LEAP := 1 << 28
const F_LATCH := 1 << 29
const F_SEGMENTS := 1 << 30
const F_CHILL := 1 << 31
const F_HOWL := 1 << 32
const F_ICESLIDE := 1 << 33
const F_KNOCKBACK := 1 << 34
const F_DFREEZE := 1 << 35
const F_STRAFE := 1 << 36
const F_SHOCKWAVE := 1 << 37
const F_LAUGH := 1 << 38
# Paket G2 (6.3): neue Rollen
const F_HEALER := 1 << 39
const F_SHIELD := 1 << 40
const F_TUNNEL := 1 << 41
const F_JAMMER := 1 << 42
const F_THIEF := 1 << 43
const F_BROOD := 1 << 44
const F_MINI := 1 << 45
# Paket Z: Magma-Wesen
const F_LAVABATH := 1 << 46
const F_HARDEN := 1 << 47

const NAMES := {"charge": F_CHARGE, "pounce": F_POUNCE, "pack": F_PACK, "burrow": F_BURROW, "ranged_arc": F_ARC, "ranged_line": F_LINE,
	"front_armor": F_FRONT, "revive": F_REVIVE, "split": F_SPLIT, "steal": F_STEAL, "pull": F_PULL, "freeze_tower": F_FREEZE_T,
	"stun_tower": F_STUN_T, "aura_buff": F_AURA, "heal": F_HEAL, "summon_portal": F_PORTAL, "dive": F_DIVE, "roll_grow": F_ROLL,
	"trail_fire": F_TRAIL, "death_cloud": F_CLOUD, "flee": F_FLEE, "siege": F_SIEGE, "regen": F_REGEN, "blink": F_BLINK, "push": F_PUSH,
	"zigzag": F_ZIGZAG, "shell": F_SHELL, "tower_hunter": F_TOWERHUNT, "leap": F_LEAP, "latch": F_LATCH, "segments": F_SEGMENTS,
	"chill": F_CHILL, "howl": F_HOWL, "ice_slide": F_ICESLIDE, "knockback": F_KNOCKBACK, "double_freeze": F_DFREEZE, "strafe": F_STRAFE,
	"shockwave": F_SHOCKWAVE, "laugh": F_LAUGH,
	"healer": F_HEALER, "shield_front": F_SHIELD, "tunnel": F_TUNNEL, "jammer": F_JAMMER, "thief": F_THIEF, "brood": F_BROOD, "miniboss": F_MINI,
	"lava_bath": F_LAVABATH, "harden": F_HARDEN}

const PRE_MASK := F_CHARGE | F_POUNCE | F_PACK | F_BURROW | F_STEAL | F_PULL | F_FREEZE_T | F_STUN_T | F_AURA | F_PORTAL | F_DIVE | F_ROLL \
	| F_TRAIL | F_FLEE | F_REGEN | F_BLINK | F_SHELL | F_TOWERHUNT | F_LEAP | F_LATCH | F_HOWL | F_ICESLIDE | F_STRAFE \
	| F_HEALER | F_TUNNEL | F_JAMMER | F_THIEF | F_BROOD | F_MINI | F_LAVABATH | F_HARDEN
const START_MASK := F_ROLL | F_REGEN | F_CHARGE | F_POUNCE | F_BURROW | F_PULL | F_DIVE | F_SHELL | F_HOWL | F_BLINK
const TICK_MASK := F_AURA | F_PORTAL | F_TRAIL | F_LEAP | F_ICESLIDE
const GOAL_MASK := F_FLEE | F_PACK | F_TOWERHUNT | F_STEAL | F_FREEZE_T | F_STUN_T
const STRIKE_MASK := F_ARC | F_LINE | F_SIEGE | F_CHILL | F_KNOCKBACK | F_SHOCKWAVE | F_LAUGH | F_LATCH | F_PUSH | F_TOWERHUNT | F_STRAFE | F_THIEF
const DMG_MASK := F_FRONT | F_SEGMENTS | F_DIVE | F_SHIELD | F_TUNNEL | F_HARDEN
const HIT_MASK := F_SHELL | F_LATCH | F_HARDEN
const DEATH_MASK := F_SPLIT | F_STEAL | F_CLOUD | F_LATCH | F_THIEF
const G2_MASK := F_HEALER | F_JAMMER | F_THIEF | F_BROOD | F_MINI
## Bausteine, die nur Laufziele und Zeitgeber pflegen: die Horde ruft pre() für sie nur jedes vierte Bild (solange kein Zustand läuft)
const LIGHT_MASK := F_TOWERHUNT | F_HEALER | F_JAMMER | F_THIEF | F_BROOD | F_MINI | F_LAVABATH

# Zustände (E.ai_s)
const S_NONE := 0
const S_WINDUP := 1
const S_CHARGE := 2
const S_DAZED := 3
const S_POUNCE := 4
const S_DIG := 5
const S_UNDER := 6
const S_RISE := 7
const S_SHELL := 8
const S_THROW := 9
const S_DRAG := 10
const S_DIVE := 11
const S_CLIMB := 12
const S_LATCH := 13
const S_FLEE := 14
const S_ROLL := 15
const S_WARN := 16
const S_STRAFE := 17
const S_HOWL := 18
const S_ROOT := 19
const S_JAM := 20               # Turmstörer zielt auf einen Turm
const S_LOOT := 21              # Dieb flieht mit der Beute
const S_SKILL := 22             # Miniboss holt zu seiner Fähigkeit aus
const S_HARD := 23              # Paket Z: Obsidian-Kruste verhärtet

const HAZ_COL := {"spore": Color(0.75, 0.6, 0.9, 0.38), "poison": Color(0.5, 0.95, 0.2, 0.4), "fire": Color(1.0, 0.4, 0.1, 0.42),
	"acid": Color(0.75, 1.0, 0.2, 0.42), "ice": Color(0.7, 0.9, 1.0, 0.45)}
const HAZ_MAX := 40
const ST_MOVE := 0
const ST_ATTACK := 1
const ST_DEAD := 2
const ST_DOWN := 3

var h: Node3D                  # die Horde
var hazards: Array = []        # {kind, c, r, r2, t, dps, n}
var chill_n := 0               # Frostwichtel: Stufen der Verlangsamung
var chill_t := 0.0
var cryst_t := -99.0           # Kristallschütze: Zeitpunkt des letzten Treffers
var _haz_t := 0.0
var _haz_pool: Array = []
var _rng := RandomNumberGenerator.new()
var _ice := false              # gibt es gerade Eisflächen?
var tele: Array = []           # angekündigte Angriffe: {c, r, t, t0, cb, a, b} (rote Bodenmarkierung, danach Wirkung)
var _tele_pool: Array = []
var _vk = null                 # Paket Z: exp_vulkan.gd der laufenden Expedition (sonst null)
var incoming: Array = []       # anfliegende Bogenschüsse: [Ziel, Radius, Restzeit] – für dodge() (Ausweichen, z. B. Testbot)


func _init(horde: Node3D) -> void:
	h = horde
	_rng.seed = 815


static func flags_of(def: Dictionary) -> int:
	var f := 0
	for a in def.get("ai", []):
		f |= int(NAMES.get(String(a), 0))
	return f


func clear() -> void:
	for z in hazards:
		_free_haz(z)
	hazards.clear()
	for m in tele:
		_free_tele(m)
	tele.clear()
	chill_n = 0
	_ice = false


# ================================================================= feindliche Bodenflächen
## kind: spore (verlangsamt den Helden) | poison | fire (Schaden am Helden) | acid (schädigt Gebäude) | ice (Held rutscht langsam, Eiswölfe schnell)
func hazard(kind: String, c: Vector2, radius: float, t: float, dps: float) -> void:
	if hazards.size() >= HAZ_MAX:
		_free_haz(hazards[0])
		hazards.remove_at(0)
	var n: MeshInstance3D
	if _haz_pool.size() > 0:
		n = _haz_pool.pop_back()
	else:
		n = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 0.06
		cm.radial_segments = 18
		cm.rings = 1
		n.mesh = cm
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		h.add_child(n)
	n.material_override = MK.glow(HAZ_COL[kind], true)
	n.scale = Vector3(radius, 1.0, radius)
	n.position = Vector3(c.x, 0.07 + 0.002 * (hazards.size() % 7), c.y)
	n.visible = true
	hazards.append({"kind": kind, "c": c, "r": radius, "r2": radius * radius, "t": t, "dps": dps, "n": n})
	if kind == "ice":
		_ice = true


func _free_haz(z: Dictionary) -> void:
	if z.n != null and is_instance_valid(z.n):
		z.n.visible = false
		_haz_pool.append(z.n)


func on_ice(p: Vector2) -> bool:
	if not _ice:
		return false
	for z in hazards:
		if z.kind == "ice" and p.distance_squared_to(z.c) < z.r2:
			return true
	return false


## Einmal je Physik-Schritt, vor den Gegnern.
func tick(dt: float, pp: Vector2, p_ok: bool) -> void:
	_vk = G.game.get("vulkan") if G.game != null else null      # Paket Z: Lavaströme (nur Vulkaninsel)
	if chill_n > 0:
		chill_t -= dt
		if chill_t <= 0.0:
			chill_n = 0
	if not tele.is_empty() or not incoming.is_empty():
		_tick_tele(dt)
	if hazards.is_empty():
		return
	_haz_t -= dt
	var pulse := _haz_t <= 0.0
	if pulse:
		_haz_t = 0.25
	var pl = G.player
	var ice := false
	var i := hazards.size() - 1
	while i >= 0:
		var z: Dictionary = hazards[i]
		z.t -= dt
		if z.t <= 0.0:
			_free_haz(z)
			hazards.remove_at(i)
			i -= 1
			continue
		if z.kind == "ice":
			ice = true
		if pulse:
			if z.t < 1.0:
				z.n.scale = Vector3(z.r * z.t, 1.0, z.r * z.t)
			if pl != null and pl.alive and pp.distance_squared_to(z.c) < z.r2:
				match z.kind:
					"spore":
						pl.slow(0.6, 0.5)
					"poison", "fire":
						pl.hurt(z.dps * 0.25, null)
					"ice":
						pl.slow(0.7, 0.5)
			if z.kind == "acid":
				G.game.damage_structures(z.c, z.r, z.dps * 0.25)
			if _rng.randf() < 0.25:
				var a := _rng.randf() * TAU
				var q: Vector2 = z.c + Vector2(cos(a), sin(a)) * z.r * sqrt(_rng.randf())
				var col: Color = HAZ_COL[z.kind]
				col.a = 1.0
				G.fx.puff(Vector3(q.x, 0.3, q.y), col, 3, 0.6)
		i -= 1
	_ice = ice


# ================================================================= vor Angriff und Bewegung
func pre(e, def: Dictionary, fl: int, dt: float, pp: Vector2, p_ok: bool, d2p: float, speed: float) -> bool:
	e.ai_c -= dt
	# ---- laufende Zustände zuerst
	match e.ai_s:
		S_NONE:
			pass
		S_WINDUP, S_CHARGE, S_DAZED:
			return _charge_run(e, def, fl, dt, pp, p_ok, speed)
		S_POUNCE:
			return _pounce_run(e, def, dt, pp, p_ok)
		S_DIG, S_UNDER, S_RISE, S_WARN:
			return _burrow_run(e, def, dt, pp, p_ok, speed)
		S_SHELL:
			e.ai_t -= dt
			e.v = Vector2.ZERO
			if e.ai_t <= 0.0:
				e.ai_s = S_NONE
				h.loop_clip(e, "")
			return true
		S_THROW, S_DRAG:
			return _pull_run(e, def, dt, pp, p_ok)
		S_DIVE, S_CLIMB:
			return _dive_run(e, def, dt, pp, p_ok)
		S_LATCH:
			return _latch_run(e, def, dt, pp, p_ok)
		S_FLEE:
			return _steal_flee(e, dt, speed)
		S_ROLL:
			return _roll_run(e, def, dt, pp, p_ok)
		S_STRAFE:
			e.ai_t -= dt
			var np: Vector2 = e.p + e.ai_v * speed * 1.6 * dt
			if G.field.in_bounds(np, 1.0):
				e.p = np
			e.v = e.ai_v * speed
			if e.ai_t <= 0.0:
				e.ai_s = S_NONE
			return true
		S_HOWL:
			e.ai_t -= dt
			e.v = Vector2.ZERO
			if e.ai_t <= 0.0:
				e.ai_s = S_NONE
			return true
		S_JAM:
			return _jam_run(e, def, dt)
		S_LOOT:
			return _loot_run(e, def, dt, speed)
		S_SKILL:
			e.v = Vector2.ZERO
			e.ai_t -= dt
			if e.ai_t <= 0.0:
				e.ai_s = S_NONE
			return true
		S_HARD:
			# verhärtet: steht still und glüht, bis die Zeit um ist
			e.v = Vector2.ZERO
			e.ai_t -= dt
			if e.ai_t <= 0.0:
				_harden_end(e)
			return true
		S_ROOT:
			# Baumhüter: festgewurzelt und heilend, bis er voll ist oder getroffen wird
			e.v = Vector2.ZERO
			e.hp = minf(e.mhp, e.hp + e.mhp * float(def.regen) * dt)
			if e.hit_t < 0.5 or e.hp >= e.mhp:
				e.ai_s = S_NONE
				h.loop_clip(e, "")
			return true
	# ---- neue Aktionen beginnen
	if fl & START_MASK != 0:
		if fl & F_ROLL != 0:
			_roll_start(e, def, pp, p_ok, d2p)
			return true
		if fl & F_REGEN != 0 and e.hit_t > float(def.regen_wait) and e.hp < e.mhp * 0.98 and e.st == ST_MOVE:
			e.ai_s = S_ROOT
			h.loop_clip(e, String(def.get("anims", {}).get("regen", "root")))
			G.fx.ring(Vector3(e.p.x, 0, e.p.y), e.r + 1.2, Color(0.4, 0.9, 0.4), 0.6)
			return true
		if fl & F_CHARGE != 0 and e.ai_c <= 0.0 and _charge_start(e, def, pp, p_ok, d2p):
			return true
		if fl & F_POUNCE != 0 and e.ai_c <= 0.0 and p_ok and d2p < float(def.pounce) ** 2 and d2p > 5.0 and e.st == ST_MOVE:
			e.ai_s = S_POUNCE
			e.ai_t = 0.0
			e.ai_v = e.p
			e.goal = pp
			h.play(e, String(def.get("anims", {}).get("pounce", "pounce")))
			h.sound(e, "special", -11.0)
			return true
		if fl & F_BURROW != 0 and String(def.burrow) == "ambush" and e.ai_c <= 0.0 and p_ok and d2p < 196.0 and d2p > 9.0 and e.st == ST_MOVE:
			start_burrow(e, def, (pp - e.p).normalized())
			return true
		if fl & F_PULL != 0 and e.ai_c <= 0.0 and p_ok and d2p < float(def.pull) ** 2 and d2p > 9.0:
			e.ai_s = S_THROW
			e.ai_t = maxf(0.45, h.play(e, String(def.get("anims", {}).get("pull", "throw"))) * 0.5)
			e.st = ST_MOVE
			e.tgt = null
			e.tgt_player = false
			h.sound(e, "special", -8.0, "whoosh")
			return true
		if fl & F_DIVE != 0:
			if _dive_cruise(e, def, dt, pp, p_ok, d2p):
				return true
		if fl & F_SHELL != 0:
			pass                                    # beginnt in on_hit
		if fl & F_HOWL != 0 and e.ai_c <= 0.0 and e.chase and e.st == ST_MOVE:
			e.ai_c = float(def.howl_cd) * _rng.randf_range(0.8, 1.3)
			e.ai_s = S_HOWL
			e.ai_t = maxf(0.6, h.play(e, "howl"))
			h.sound(e, "special", -8.0)
			G.fx.ring(Vector3(e.p.x, 0, e.p.y), 6.0, Color(0.8, 0.95, 1.0, 0.6), 0.6)
			for o in h.in_radius(e.p, 12.0):
				if o.t == e.t:
					o.haste = 4.0
					if o != e:
						o.ai_c = maxf(o.ai_c, 4.0)      # nur einer heult
			return true
		if fl & F_BLINK != 0 and e.ai_c <= 0.0:
			_blink(e, def, pp, p_ok)
	if fl & TICK_MASK != 0:
		if fl & F_AURA != 0:
			e.ai_t -= dt
			if e.ai_t <= 0.0:
				e.ai_t = 0.5
				for o in h.near(e.p, float(def.aura)):
					if o != e:
						o.buff = 1.0
				if _rng.randf() < 0.3:
					G.fx.ring(Vector3(e.p.x, 0, e.p.y), float(def.aura), Color(0.7, 1.0, 0.3, 0.5), 0.5)
		if fl & F_PORTAL != 0:
			e.sp_t -= dt
			# Paket G2: ein Wächter (Expedition) beschwört nur, wenn der Held in der Nähe ist – sonst füllten
			# ferne Beschwörer die Karte mit Wichteln bis zur Höchstzahl (Gebiet 7: kaum Gegner beim Helden)
			if e.sp_t <= 0.0 and (e.leash <= 0.0 or e.aggro or (p_ok and d2p < 900.0)):
				_open_portal(e, def)
		if fl & F_TRAIL != 0 and e.st == ST_MOVE:
			e.ai_t -= dt
			if e.ai_t <= 0.0:
				e.ai_t = float(def.trail)
				if e.v.length_squared() > 1.0:
					hazard("fire", e.p, 0.75, 2.5, float(def.dmg) * 0.8 * e.dp)
		if fl & F_LEAP != 0 and e.st == ST_MOVE:
			_leap(e, def, dt)
		if fl & F_ICESLIDE != 0 and _ice and e.st == ST_MOVE and on_ice(e.p):
			var qi: Vector2 = e.p + e.v * dt     # doppelt so schnell über Eis
			if not G.field.is_solid(qi) and G.field.structure_at(qi) == null:
				e.p = qi
	# ---- Magma-Wesen (Paket Z): nahe der Lava heilen und schneller werden
	if fl & F_LAVABATH != 0:
		_lava_bath(e, def, dt)
	# ---- neue Rollen (Paket G2)
	if fl & G2_MASK != 0:
		if _g2_pre(e, def, fl, dt, pp, p_ok, d2p):
			return true
	# ---- eigene Laufziele
	if fl & GOAL_MASK != 0:
		if fl & F_FLEE != 0 and e.ai_s == S_NONE and def.has("flee") and p_ok and d2p < float(def.flee) ** 2:
			var away: Vector2 = (e.p - pp).normalized()
			var q: Vector2 = e.p + away * 4.0
			if not G.field.is_solid(q) and G.field.in_bounds(q, 3.0):
				e.goal = q
				e.g_on = true
				if e.st == ST_ATTACK:
					e.st = ST_MOVE
					e.tgt = null
					e.tgt_player = false
		if fl & F_PACK != 0 and p_ok and e.st == ST_MOVE and e.chase and e.ai_c > 0.0 and d2p < 100.0 and not e.g_on:
			# umkreisen, bis der Sprung wieder bereit ist
			var side := 1.0 if e.ph > PI else -1.0
			var rel: Vector2 = (e.p - pp).normalized()
			e.goal = pp + rel.rotated(side * 0.8) * 4.2
			e.g_on = true
		if fl & F_TOWERHUNT != 0:
			_tower_hunt(e, def, dt)
		if fl & F_STEAL != 0:
			if _steal(e, def, dt):
				return true
		if fl & F_FREEZE_T != 0:
			_freeze_tower(e, def, dt)
		if fl & F_STUN_T != 0:
			_stun_tower(e, def, dt, pp, p_ok, d2p)
	return false


# ---------------------------------------------------------------- charge (Rostbulle, Dämonenhund)
func _charge_start(e, def: Dictionary, pp: Vector2, p_ok: bool, d2p: float) -> bool:
	if e.st != ST_MOVE:
		return false
	var dist: float = def.charge
	var dir := Vector2.ZERO
	if p_ok and d2p < dist * dist and d2p > 6.0:
		dir = (pp - e.p).normalized()
	elif not def.get("hunt", false) and e.leash <= 0.0:
		var fd: Vector2 = G.field.dir_at(e.p)
		for k in [3.0, 5.5, dist]:
			var s = G.field.structure_at(e.p + fd * k)
			if s != null and not s.passable:
				dir = fd
				break
	if dir == Vector2.ZERO:
		e.ai_c = 0.4
		return false
	e.ai_s = S_WINDUP
	var an: Dictionary = def.get("anims", {})
	e.ai_t = maxf(0.55, h.play(e, String(an.get("charge_start", "windup"))))
	e.ai_v = dir
	e.ai_d = dist + 1.0
	h.sound(e, "special", -8.0)
	G.fx.puff(Vector3(e.p.x, 0.3, e.p.y), Color(0.8, 0.75, 0.6), 8, 1.0)
	return true


func _charge_run(e, def: Dictionary, fl: int, dt: float, pp: Vector2, p_ok: bool, speed: float) -> bool:
	var an: Dictionary = def.get("anims", {})
	match e.ai_s:
		S_WINDUP:
			e.ai_t -= dt
			e.v = Vector2.ZERO
			e.yaw = lerp_angle(e.yaw, atan2(e.ai_v.x, e.ai_v.y), minf(1.0, dt * 10.0))
			if e.ai_t <= 0.0:
				e.ai_s = S_CHARGE
				h.loop_clip(e, String(an.get("charge", "charge")))
		S_CHARGE:
			var sp := maxf(speed * 4.0, 9.0)
			var step := sp * dt
			var np: Vector2 = e.p + e.ai_v * step
			e.ai_d -= step
			e.v = e.ai_v * sp
			var stop: bool = e.ai_d <= 0.0
			var crash := false
			if G.field.is_solid(np):
				crash = true
			else:
				var s = G.field.structure_at(np)
				if s != null and not s.passable:
					s.hurt(float(def.dmg) * e.dm * 2.0, true)
					crash = true
					G.fx.puff(Vector3(np.x, 0.8, np.y), Color(0.7, 0.65, 0.6), 14, 1.6)
					G.cam.shake(0.15)
			if not crash:
				e.p = np
				if p_ok and np.distance_squared_to(pp) < (e.r + 0.9) ** 2:
					G.player.hurt(float(def.dmg) * e.dp * 1.4, e)
					if fl & F_LATCH != 0:
						h.loop_clip(e, "")
						_latch_begin(e, def)
						return true
					G.player.push(e.ai_v, 2.5)
					stop = true
			if crash and def.has("charge_stun"):
				e.ai_s = S_DAZED
				e.ai_t = float(def.charge_stun)
				e.v = Vector2.ZERO
				h.loop_clip(e, String(an.get("dazed", "dazed")))
				h.sound(e, "hit", -6.0, "shield_clank")
				e.ai_c = float(def.get("charge_cd", 6.0))
			elif crash or stop:
				e.ai_s = S_NONE
				e.ai_c = float(def.get("charge_cd", 6.0))
				h.loop_clip(e, "")
		S_DAZED:
			e.ai_t -= dt
			e.v = Vector2.ZERO
			if e.ai_t <= 0.0:
				e.ai_s = S_NONE
				h.loop_clip(e, "")
	return true


# ---------------------------------------------------------------- pounce (Dornenwolf, Eiswolf)
func _pounce_run(e, def: Dictionary, dt: float, pp: Vector2, p_ok: bool) -> bool:
	e.ai_t += dt
	var k: float = minf(1.0, e.ai_t / 0.45)
	var to: Vector2 = e.goal
	var np: Vector2 = e.ai_v.lerp(to, k)
	if not G.field.is_solid(np):
		e.p = np
	e.alt = sin(k * PI) * 1.2
	var d: Vector2 = to - e.ai_v
	e.v = d / 0.45
	if d.length_squared() > 0.01:
		e.yaw = atan2(d.x, d.y)
	if k >= 1.0:
		e.alt = 0.0
		e.ai_s = S_NONE
		e.ai_c = _rng.randf_range(2.5, 4.0)
		if p_ok and e.p.distance_squared_to(pp) < 2.2:
			G.player.hurt(float(def.dmg) * e.dp * 1.5, e)
	return true


# ---------------------------------------------------------------- leap (Giftkröte): Sätze von 3 m
func _leap(e, def: Dictionary, dt: float) -> void:
	var hop: float = 0.6
	var rest: float = maxf(float(def.leap) / maxf(e.sp, 0.5) - hop, 0.2)
	e.ai_d += dt
	var q: Vector2 = e.p
	if e.ai_d < hop:
		e.alt = sin(e.ai_d / hop * PI) * 0.8
		var l: float = e.v.length()
		if l > 0.3:
			q += e.v / l * (float(def.leap) / hop - l) * dt
	else:
		e.alt = 0.0
		q -= e.v * dt * 0.95                   # sitzt und sammelt Kraft
		if e.ai_d >= hop + rest:
			e.ai_d = 0.0
	if not G.field.is_solid(q) and G.field.structure_at(q) == null:
		e.p = q


# ---------------------------------------------------------------- burrow (Wurzelkriecher, Sandwurm)
## Beginnt das Eingraben. Rückgabe false, wenn es gerade nicht geht.
func start_burrow(e, def: Dictionary, dir: Vector2) -> bool:
	if e.ai_s != S_NONE or (String(def.burrow) != "ambush" and e.ai_c > 0.0):
		return false
	var an: Dictionary = def.get("anims", {})
	e.ai_s = S_DIG
	e.ai_t = maxf(0.5, h.play(e, String(an.get("dig", "dig"))))
	e.ai_v = dir.normalized()
	e.ai_d = 0.0
	e.ai_n = 0
	e.st = ST_MOVE
	e.tgt = null
	e.tgt_player = false
	G.fx.puff(Vector3(e.p.x, 0.2, e.p.y), Color(0.6, 0.5, 0.35), 10, 1.0)
	h.sound(e, "special", -10.0)
	return true


func _burrow_run(e, def: Dictionary, dt: float, pp: Vector2, p_ok: bool, speed: float) -> bool:
	var an: Dictionary = def.get("anims", {})
	var ambush: bool = String(def.burrow) == "ambush"
	match e.ai_s:
		S_DIG:
			e.ai_t -= dt
			e.v = Vector2.ZERO
			if e.ai_t <= 0.0:
				e.ai_s = S_UNDER
				e.under = true
				e.ai_t = 6.0
				h.loop_clip(e, String(an.get("under", "under")))
		S_UNDER:
			e.ai_t -= dt
			var sp := speed * 1.3
			if ambush:
				if p_ok:
					e.ai_v = (pp - e.p).normalized()
				var np: Vector2 = e.p + e.ai_v * sp * dt
				if not G.field.is_solid(np):
					e.p = np
				e.v = e.ai_v * sp
				if _rng.randf() < 0.2:
					G.fx.puff(Vector3(e.p.x, 0.1, e.p.y), Color(0.85, 0.72, 0.45), 2, 0.4)   # Sandspur
				if (p_ok and e.p.distance_squared_to(pp) < 1.0) or e.ai_t <= 0.0:
					e.ai_s = S_WARN
					e.ai_t = 1.0
					e.ai_v = e.p
					e.v = Vector2.ZERO
					G.fx.ring(Vector3(e.p.x, 0, e.p.y), 2.0, Color(1.0, 0.3, 0.2), 1.0)     # Warnkreis
					h.sound(e, "special", -8.0)
			elif String(def.burrow) == "tunnel":
				_tunnel_run(e, def, dt, sp)
			else:
				var np2: Vector2 = e.p + e.ai_v * sp * dt
				if G.field.is_solid(np2):
					e.ai_t = 0.0
				else:
					e.p = np2
					e.ai_d += sp * dt
				e.v = e.ai_v * sp
				var clear: bool = G.field.structure_at(e.p) == null and G.field.structure_at(e.p + e.ai_v * 1.2) == null
				if (e.ai_d > 2.0 and clear) or e.ai_t <= 0.0:
					_rise(e, def)
		S_WARN:
			e.ai_t -= dt
			if e.ai_t <= 0.0:
				var c: Vector2 = e.p
				G.fx.puff(Vector3(c.x, 0.5, c.y), Color(0.85, 0.72, 0.45), 20, 2.0)
				G.cam.shake(0.15)
				if G.player.alive and G.player.pos2().distance_squared_to(c) < 4.0:
					G.player.hurt(float(def.dmg) * e.dp * 1.5, e)
					G.player.push((G.player.pos2() - c).normalized(), 1.5)
				_rise(e, def)
		S_RISE:
			e.ai_t -= dt
			e.v = Vector2.ZERO
			if e.ai_t <= 0.0:
				e.ai_s = S_NONE
	return true


func _rise(e, def: Dictionary) -> void:
	var an: Dictionary = def.get("anims", {})
	e.under = false
	h.loop_clip(e, "")
	e.ai_s = S_RISE
	e.ai_t = maxf(0.4, h.play(e, String(an.get("rise", "rise"))))
	e.ai_c = 6.0 if String(def.burrow) == "ambush" else (8.0 if String(def.burrow) == "tunnel" else 1.5)
	e.v = Vector2.ZERO
	G.fx.puff(Vector3(e.p.x, 0.3, e.p.y), Color(0.6, 0.5, 0.35), 12, 1.4)
	if String(def.burrow) == "tunnel":
		_tunnel_trap_check(e)


# ---------------------------------------------------------------- pull (Ertrunkener Taucher)
func _pull_run(e, def: Dictionary, dt: float, pp: Vector2, p_ok: bool) -> bool:
	e.v = Vector2.ZERO
	var to: Vector2 = pp - e.p
	if to.length_squared() > 0.01:
		e.yaw = lerp_angle(e.yaw, atan2(to.x, to.y), minf(1.0, dt * 10.0))
	e.ai_t -= dt
	var from := Vector3(e.p.x, 1.2 * e.sc * 0.5, e.p.y)
	if e.ai_s == S_THROW:
		if e.ai_t <= 0.0:
			if p_ok and to.length() < float(def.pull) + 2.5 and G.player.dash_t <= 0.0:
				e.ai_s = S_DRAG
				e.ai_t = 0.8
				Sfx.play_at("shield_clank", Vector3(pp.x, 0, pp.y), -8.0, 0.7)
				G.fx.puff(Vector3(pp.x, 1.0, pp.y), Color(0.7, 0.75, 0.8), 8, 1.0)
			else:
				e.ai_s = S_NONE
				e.ai_c = float(def.pull_cd) * 0.5
	else:
		# Kette straff: der Held wird herangezogen (Ausweichrolle reißt ihn los)
		G.fx.tracer(from, Vector3(pp.x, 1.2, pp.y), Color(0.55, 0.6, 0.68), 0.09, 0.05)
		if not p_ok or G.player.dash_t > 0.0 or e.ai_t <= 0.0 or to.length() < e.r + 1.3:
			e.ai_s = S_NONE
			e.ai_c = float(def.pull_cd)
		else:
			G.player.pull_to(e.p, 13.0 * dt)
	return true


# ---------------------------------------------------------------- dive (Schattenschwinge)
func _dive_cruise(e, def: Dictionary, dt: float, pp: Vector2, p_ok: bool, d2p: float) -> bool:
	e.alt = lerpf(e.alt, 3.6, minf(1.0, dt * 2.0))
	if not p_ok:
		return false
	if e.ai_c <= 0.0 and d2p < float(def.dive) ** 2 and e.st == ST_MOVE:
		e.ai_s = S_DIVE
		e.ai_t = 0.0
		e.ai_v = e.p
		e.goal = pp
		e.ai_d = e.alt
		h.play(e, "dive")
		h.sound(e, "special", -9.0)
		return true
	if d2p < 64.0:
		# kreist über dem Helden, bis der nächste Sturzflug bereit ist
		var side := 1.0 if e.ph > PI else -1.0
		e.goal = pp + (e.p - pp).normalized().rotated(side * 0.7) * 6.0
		e.g_on = true
	return false


func _dive_run(e, def: Dictionary, dt: float, pp: Vector2, p_ok: bool) -> bool:
	e.ai_t += dt
	if e.ai_s == S_DIVE:
		var k: float = minf(1.0, e.ai_t / 0.7)
		e.p = e.ai_v.lerp(e.goal, k)
		e.alt = lerpf(e.ai_d, 0.5, k * k)
		var d: Vector2 = e.goal - e.ai_v
		e.v = d / 0.7
		if d.length_squared() > 0.01:
			e.yaw = atan2(d.x, d.y)
		if k >= 1.0:
			if p_ok and e.p.distance_squared_to(pp) < 3.0:
				G.player.hurt(float(def.dmg) * e.dp, e)
			e.ai_s = S_CLIMB
			e.ai_t = 0.0
			e.ai_v = e.v.normalized()
	else:
		e.alt = lerpf(0.5, 3.6, minf(1.0, e.ai_t / 1.1))
		var np: Vector2 = e.p + e.ai_v * e.sp * dt
		if G.field.in_bounds(np, 1.0):
			e.p = np
		if e.ai_t >= 1.1:
			e.ai_s = S_NONE
			e.ai_c = float(def.dive_cd)
	return true


# ---------------------------------------------------------------- latch (Blutegel: verlangsamt · Dämonenhund: beißt)
func _latch_begin(e, def: Dictionary) -> void:
	e.ai_s = S_LATCH
	e.ai_t = 0.0
	e.ai_d = _rng.randf() * TAU
	e.st = ST_MOVE
	e.tgt_player = false
	h.sound(e, "special", -10.0)


func _latch_run(e, def: Dictionary, dt: float, pp: Vector2, p_ok: bool) -> bool:
	var pl = G.player
	if not pl.alive or pl.dash_t > 0.0 or pl.mounted:
		# abgeschüttelt (Ausweichrolle)
		e.ai_s = S_NONE
		e.ai_c = 3.0
		e.stun = 0.8
		e.kn = Vector2(cos(e.ai_d), sin(e.ai_d)) * 14.0
		return true
	e.p = pp + Vector2(cos(e.ai_d), sin(e.ai_d)) * 0.55
	e.v = Vector2.ZERO
	e.yaw = e.ai_d + PI * 0.5
	e.ai_t -= dt
	if String(def.latch) == "slow":
		pl.slow(0.55, 0.3)
	if e.ai_t <= 0.0:
		e.ai_t = float(def.interval)
		pl.hurt(float(def.dmg) * e.dp, e)
	return true


# ---------------------------------------------------------------- roll_grow (Lawinenroller)
func _roll_start(e, def: Dictionary, pp: Vector2, p_ok: bool, d2p: float) -> void:
	var dir: Vector2
	if p_ok and (d2p < 400.0 or e.leash > 0.0):
		dir = (pp - e.p).normalized()
	else:
		dir = G.field.dir_at(e.p)
		if dir.length_squared() < 0.01:
			dir = Vector2(cos(e.ph), sin(e.ph))
	e.ai_v = dir.normalized()
	e.ai_s = S_ROLL
	e.ai_d = e.vs
	e.ai_t = e.r
	e.st = ST_MOVE
	h.loop_clip(e, "roll")


func _roll_run(e, def: Dictionary, dt: float, pp: Vector2, p_ok: bool) -> bool:
	e.grow = minf(1.0, e.grow + dt * 0.28)
	var sp := lerpf(e.sp, e.sp * float(def.roll_max) / maxf(float(def.speed), 0.1), e.grow)
	if e.slow > 0.0:
		sp *= 0.7
	var k: float = 1.0 + e.grow * float(def.roll_grow)
	e.vs = e.ai_d * k
	e.r = e.ai_t * k
	var np: Vector2 = e.p + e.ai_v * sp * dt
	e.v = e.ai_v * sp
	e.yaw = atan2(e.ai_v.x, e.ai_v.y)
	var s = G.field.structure_at(np)
	var hit_hero: bool = p_ok and np.distance_squared_to(pp) < (e.r + 0.6) ** 2
	if G.field.is_solid(np) or (s != null and not s.passable) or hit_hero or not G.field.in_bounds(np, 1.0):
		var rad: float = float(def.splash) * (1.0 + e.grow * 0.5)
		var dmg: float = float(def.dmg) * (1.0 + e.grow * 2.0)
		G.fx.explosion(Vector3(e.p.x, 0.6, e.p.y), rad, Color(0.85, 0.95, 1.0))
		Sfx.play_at("ice_shatter", Vector3(e.p.x, 0, e.p.y), -5.0)
		G.game.damage_structures(e.p, rad, dmg * e.dm)
		if G.player.alive and G.player.pos2().distance_squared_to(e.p) < rad * rad:
			G.player.hurt(dmg * e.dp * 0.7, e)
		h._kill(e, Vector2.ZERO, "explosion")
		return true
	e.p = np
	return true


# ---------------------------------------------------------------- blink (Irrlicht)
func _blink(e, def: Dictionary, pp: Vector2, p_ok: bool) -> void:
	e.ai_c = float(def.blink_cd)
	var dir: Vector2 = e.v.normalized() if e.v.length_squared() > 0.1 else Vector2(cos(e.ph), sin(e.ph))
	var q: Vector2 = e.p + dir * float(def.blink)
	if not G.field.in_bounds(q, 2.0):
		return
	G.fx.puff(Vector3(e.p.x, e.alt, e.p.y), Color(0.5, 0.8, 1.0), 8, 0.8)
	e.p = q
	G.fx.puff(Vector3(q.x, e.alt, q.y), Color(0.5, 0.8, 1.0), 8, 0.8)
	h.play(e, "blink")
	h.sound(e, "special", -12.0)


# ---------------------------------------------------------------- tower_hunter (Deckratte)
func _tower_hunt(e, def: Dictionary, dt: float) -> void:
	e.g_t -= dt
	if e.g_t <= 0.0:
		e.g_t = 1.0 + _rng.randf() * 0.4
		e.ai_n = 0
		var best := float(def.tower_range) ** 2
		for tw in G.game.towers:
			if is_instance_valid(tw) and tw.active and tw.life < 0.0:
				var d: float = tw.pos2().distance_squared_to(e.p)
				if d < best:
					best = d
					e.goal = tw.pos2()
					e.ai_n = 1
	if e.ai_n == 1 and e.st == ST_MOVE and not e.chase:
		e.g_on = true


# ---------------------------------------------------------------- steal (Geier trägt davon · Staubteufel reißt mit)
func _steal(e, def: Dictionary, dt: float) -> bool:
	if G.coins == null:
		return false
	e.g_t -= dt
	var carry_mode: bool = String(def.steal) == "carry"
	if e.g_t <= 0.0:
		e.g_t = 0.35
		var got: float = G.coins.take(e.p, 1.3 if carry_mode else 2.2)
		if got > 0.0:
			e.carry += got
			G.fx.puff(Vector3(e.p.x, 0.5, e.p.y), Color(1.0, 0.85, 0.2), 4, 0.6)
			h.sound(e, "special", -12.0, "coin")
		if carry_mode:
			e.ai_n = 0
			if e.carry >= 5.0:
				# genug Beute: ab zum Kartenrand
				e.ai_s = S_FLEE
				var out: Vector2 = e.p - (G.game.goal_structure.mid if G.game.goal_structure != null else G.player.pos2())
				e.ai_v = out.normalized() if out.length_squared() > 0.1 else Vector2(1, 0)
				e.st = ST_MOVE
				e.tgt = null
				e.tgt_player = false
				return true
			var c = G.coins.nearest_ground(e.p, 26.0)
			if c != null:
				e.goal = c
				e.ai_n = 1
	if carry_mode and e.ai_n == 1 and e.st == ST_MOVE:
		e.g_on = true
		e.alt = lerpf(e.alt, 0.9 if e.p.distance_squared_to(e.goal) < 9.0 else 2.4, minf(1.0, dt * 4.0))
	elif carry_mode:
		e.alt = lerpf(e.alt, 2.4, minf(1.0, dt * 3.0))
	return false


func _steal_flee(e, dt: float, speed: float) -> bool:
	var np: Vector2 = e.p + e.ai_v * speed * 1.25 * dt
	e.v = e.ai_v * speed
	e.yaw = atan2(e.ai_v.x, e.ai_v.y)
	e.alt = lerpf(e.alt, 3.2, minf(1.0, dt * 2.0))
	e.ai_d += dt
	if not G.field.in_bounds(np, 2.0) or e.ai_d > 14.0:
		# entkommen: die Beute ist weg
		G.fx.float_text(Vector3(e.p.x, 3.0, e.p.y), "Beute weg!", Color(1.0, 0.5, 0.4))
		h.despawn(e)
		return true
	e.p = np
	return true


# ---------------------------------------------------------------- freeze_tower (Eisgeist), stun_tower (Geisterqualle)
func _freeze_tower(e, def: Dictionary, dt: float) -> void:
	e.g_t -= dt
	if e.g_t <= 0.0:
		e.g_t = 1.0
		e.ai_n = 0
		var best := -1.0
		for tw in G.game.towers:
			if is_instance_valid(tw) and tw.active and tw.stun_t <= 0.0:
				var pw: float = float(tw.def.damage) * float(tw.def.rpm) * tw.dmg_mult      # bevorzugt den stärksten Turm
				if pw > best and tw.pos2().distance_squared_to(e.p) < 3600.0:
					best = pw
					e.goal = tw.pos2()
					e.ai_n = 1
	if e.ai_n == 1:
		if e.st == ST_MOVE:
			e.g_on = true
		if e.ai_c <= 0.0 and e.p.distance_squared_to(e.goal) < 9.0:
			for tw in G.game.towers:
				if is_instance_valid(tw) and tw.pos2().distance_squared_to(e.goal) < 0.5:
					tw.stun(float(def.freeze_tower), "ice")
			e.ai_c = float(def.freeze_cd)
			e.ai_n = 0
			e.g_t = 0.0
			h.play(e, "freeze")
			h.sound(e, "special", -8.0, "ice_shatter")
			G.fx.ring(Vector3(e.goal.x, 0, e.goal.y), 2.5, Color(0.7, 0.9, 1.0), 0.6)


func _stun_tower(e, def: Dictionary, dt: float, pp: Vector2, p_ok: bool, d2p: float) -> void:
	e.g_t -= dt
	if e.g_t <= 0.0:
		e.g_t = 1.0
		e.ai_n = 0
		var best := 484.0
		for tw in G.game.towers:
			if is_instance_valid(tw) and tw.active:
				var d: float = tw.pos2().distance_squared_to(e.p)
				if d < best:
					best = d
					e.goal = tw.pos2()
					e.ai_n = 1
	if e.ai_n == 1 and e.st == ST_MOVE and not e.chase:
		e.g_on = true
	if e.ai_c > 0.0:
		return
	var zr: float = def.zap
	var zr2 := zr * zr
	var hit_any: bool = p_ok and d2p < zr2
	var tws: Array = []
	for tw in G.game.towers:
		if is_instance_valid(tw) and tw.active and tw.pos2().distance_squared_to(e.p) < zr2:
			tws.append(tw)
	if not hit_any and tws.is_empty():
		return
	e.ai_c = float(def.zap_cd)
	h.play(e, "zap")
	h.sound(e, "special", -7.0, "t_tesla")
	var from := Vector3(e.p.x, e.alt + 0.5, e.p.y)
	G.fx.ring(Vector3(e.p.x, 0, e.p.y), zr, Color(0.6, 0.85, 1.0), 0.4)
	for tw in tws:
		tw.stun(float(def.zap_stun), "zap")
		G.fx.lightning(from, tw.global_position + Vector3(0, 1.5, 0))
	if hit_any:
		G.fx.lightning(from, Vector3(pp.x, 1.2, pp.y))
		G.player.hurt(float(def.dmg) * e.dp, e)


# ---------------------------------------------------------------- summon_portal (Beschwörer)
func _open_portal(e, def: Dictionary) -> void:
	e.sp_t = float(def.portal_cd)
	if h.alive >= G.max_alive() - 8:
		return
	var dir := Vector2(sin(e.yaw), cos(e.yaw))
	var q: Vector2 = e.p + dir * 2.4
	if G.field.is_solid(q) or G.field.structure_at(q) != null:
		q = e.p
	h.play(e, String(def.get("anims", {}).get("summon", "summon")))
	h.sound(e, "special", -7.0, "boss_summon")
	var p = h.spawn(int(D.ENEMY_INDEX["daemonen_portal"]), q, e.hm, e.dm, e.dp)
	p.stat = true
	p.ai_n = int(def.portal_n)
	p.ai_d = float(D.ENEMY_INDEX[String(def.portal_key)])
	p.sp_t = 0.8
	p.home = e.home
	p.leash = e.leash
	p.coins = 0
	p.yaw = 0.0
	h.play(p, "spawn")
	G.fx.ring(Vector3(q.x, 0, q.y), 2.0, Color(1.0, 0.3, 0.6), 0.6)


## Das Portal: spuckt nacheinander seine Wichtel aus und erlischt dann. Wird es vorher zerstört, kommt nichts mehr.
func tick_portal(e, dt: float) -> void:
	e.sp_t -= dt
	if e.sp_t > 0.0:
		return
	if e.ai_n <= 0:
		h.despawn(e)
		G.fx.puff(Vector3(e.p.x, 0.8, e.p.y), Color(1.0, 0.3, 0.6), 10, 1.0)
		return
	e.sp_t = 0.7
	e.ai_n -= 1
	if h.alive < G.max_alive():
		var a := _rng.randf() * TAU
		var m = h.spawn(int(e.ai_d), e.p + Vector2(cos(a), sin(a)) * 0.8, e.hm, e.dm, e.dp)
		m.home = e.home
		m.leash = e.leash
		m.aggro = true
		m.coins = 0
		h.play(e, "attack")
		G.fx.puff(Vector3(e.p.x, 0.8, e.p.y), Color(1.0, 0.4, 0.2), 6, 1.0)
	if e.ai_n <= 0:
		e.sp_t = 1.0


# ================================================================= Schlag
func strike(e, def: Dictionary, fl: int, pp: Vector2, weak: float) -> bool:
	var pl = G.player
	if fl & F_THIEF != 0 and not e.tgt_player and e.tgt != null and _is_store(e.tgt) and e.loot.is_empty():
		_steal_store(e, def, e.tgt)
		return true
	if fl & (F_ARC | F_LINE) != 0 and e.rng > 0.0:
		var far: bool = false
		var tp := pp
		if e.tgt_player:
			far = e.p.distance_squared_to(pp) > (e.r + 1.6) ** 2
		elif e.tgt != null:
			tp = e.tgt.mid
			far = fl & F_ARC != 0 and e.p.distance_squared_to(tp) > (e.r + e.tgt.radius + 1.2) ** 2
		if far:
			if fl & F_ARC != 0:
				_shoot_arc(e, def, tp, weak)
			else:
				_shoot_line(e, def, fl, tp, weak)
			if fl & F_STRAFE != 0:
				# weicht nach dem Schuss seitlich aus
				var side: Vector2 = (tp - e.p).normalized().orthogonal() * (1.0 if _rng.randf() < 0.5 else -1.0)
				e.ai_s = S_STRAFE
				e.ai_t = 0.55
				e.ai_v = side
			return true
	if e.tgt_player:
		var d: float = float(def.dmg) * e.dp * weak
		if fl & F_LATCH != 0 and e.ai_c <= 0.0 and e.ai_s == S_NONE:
			pl.hurt(d, e)
			_latch_begin(e, def)
			return true
		if fl & (F_CHILL | F_KNOCKBACK | F_LAUGH | F_PUSH | F_SHOCKWAVE) == 0:
			return false
		pl.hurt(d, e)
		var dir: Vector2 = (pp - e.p).normalized()
		if fl & F_CHILL != 0:
			_chill(def)
		if fl & F_KNOCKBACK != 0:
			pl.push(dir, float(def.knockback))
			G.fx.puff(Vector3(pp.x, 0.8, pp.y), Color(0.9, 0.95, 1.0), 10, 1.5)
		if fl & F_PUSH != 0:
			pl.push(dir, float(def.push))
		if fl & F_LAUGH != 0:
			h.sound(e, "laugh", -9.0)
		if fl & F_SHOCKWAVE != 0:
			_shockwave(e, def, dir, weak)
		return true
	if e.tgt != null:
		var sd: float = float(def.dmg) * e.dm * weak
		if fl & F_SIEGE != 0 and "owner_ref" in e.tgt:
			sd *= float(def.siege)                      # doppelter Schaden an Mauern
		if fl & F_TOWERHUNT != 0 and e.tgt.get("tower") != null:
			sd *= float(def.tower_dmg)                  # knabbert bevorzugt an Türmen
		e.tgt.hurt(sd, false)
		if fl & F_SHOCKWAVE != 0:
			_shockwave(e, def, (e.tgt.mid - e.p).normalized(), weak)
		return true
	return false


func _chill(def: Dictionary) -> void:
	chill_n = mini(chill_n + 1, int(round(float(def.chill_max) / float(def.chill))))
	chill_t = 3.0
	G.player.slow(1.0 - float(def.chill) * chill_n, 3.0)


func _proj_col(def: Dictionary) -> Color:
	match String(def.family):
		"wald": return Color(0.5, 0.35, 0.2)
		"wueste": return Color(0.5, 0.8, 0.3)
		"untote": return Color(0.15, 0.15, 0.18)
		"mutanten": return Color(0.7, 1.0, 0.2)
		"eis": return Color(0.8, 0.95, 1.0)
		"daemonen": return Color(1.0, 0.45, 0.1)
	return Color(0.7, 0.9, 0.2)


## Geschoss im Bogen mit Flächenschaden (Kanonier, Rohrspucker, Yeti, Feuerspeier); über Mauern hinweg.
func _shoot_arc(e, def: Dictionary, target: Vector2, weak: float, spread := 0.0) -> void:
	var from := Vector3(e.p.x, 0.9 * e.sc, e.p.y)
	if spread > 0.0:
		target += Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-spread, spread))
	var to := Vector3(target.x, 0.2, target.y)
	var rad: float = def.get("splash", 2.0)
	var dmg: float = float(def.dmg) * weak
	var dp: float = e.dp
	var dm: float = e.dm
	var col := _proj_col(def)
	var zone: String = def.get("zone", "")
	var zt: float = def.get("zone_t", 0.0)
	var dist: float = from.distance_to(to)
	h.sound(e, "shot", -7.0, "t_cannon" if String(def.family) == "untote" else "spit")
	G.fx.ring(to, rad, Color(1.0, 0.3, 0.2, 0.7), 0.5)                       # Einschlag kündigt sich an
	if incoming.size() < 48:
		incoming.append([target, rad, clampf(dist / 14.0, 0.6, 1.2) + 0.1])
	G.game.launch(from, to, clampf(dist / 14.0, 0.6, 1.2), 2.5 + dist * 0.22, col, func():
		G.fx.explosion(to + Vector3(0, 0.3, 0), rad * 0.8, col.lightened(0.3))
		Sfx.play_at("explosion_small" if zone == "" else "spit_land", to, -9.0, 1.0, 0.08)
		if G.player != null and G.player.alive and G.player.pos2().distance_to(Vector2(to.x, to.z)) < rad:
			G.player.hurt(dmg * dp, e)
		G.game.damage_structures(Vector2(to.x, to.z), rad, dmg * dm * 0.6)
		if zone != "" and G.horde != null:
			G.horde.ai.hazard(zone, Vector2(to.x, to.z), rad, zt, dmg * (dm if zone == "acid" else dp) * 0.5))


## Gerades Geschoss (Zapfen, Stacheln, Schneeball, Eispfeil, Drohnenschuss): trifft den Helden nur, wenn er noch dort steht.
func _shoot_line(e, def: Dictionary, fl: int, target: Vector2, weak: float) -> void:
	var n: int = int(def.get("shots", 1))
	var base: Vector2 = target - e.p
	var dist: float = maxf(base.length(), 1.0)
	var bdir: Vector2 = base / dist
	var dmg: float = float(def.dmg) * weak * e.dp
	var col := _proj_col(def)
	var y0: float = 0.9 * e.sc + e.alt
	h.sound(e, "shot", -10.0, "whoosh")
	for k in n:
		var ang: float = 0.0 if n == 1 else deg_to_rad(-16.0 + 32.0 * k / float(n - 1))
		var dir: Vector2 = bdir.rotated(ang)
		var q: Vector2 = e.p + dir * dist
		_line_seg(e, def, fl, Vector3(e.p.x, y0, e.p.y), q, dir, dmg, col, int(def.get("bounce", 0)))


func _line_seg(e, def: Dictionary, fl: int, from: Vector3, q: Vector2, dir: Vector2, dmg: float, col: Color, bounce: int) -> void:
	var to := Vector3(q.x, 0.9, q.y)
	var dur: float = clampf(from.distance_to(to) / 16.0, 0.12, 1.2)
	if incoming.size() < 48:
		incoming.append([q, 1.0, dur])
	G.game.launch(from, to, dur, 0.25, col, func():
		var pl = G.player
		var hit: bool = pl != null and pl.alive and pl.pos2().distance_squared_to(q) < 1.0
		if hit:
			pl.hurt(dmg, e)
			if G.horde != null:
				var a = G.horde.ai
				if fl & F_CHILL != 0:
					a._chill(def)
				if fl & F_DFREEZE != 0:
					if G.horde.time - a.cryst_t < float(def.freeze_window):
						pl.root(float(def.freeze))
						G.fx.ring(pl.global_position, 1.6, Color(0.7, 0.9, 1.0), 0.6)
						Sfx.play_at("ice_shatter", pl.global_position, -8.0, 1.3)
						a.cryst_t = -99.0
					else:
						a.cryst_t = G.horde.time
		if G.fx != null:
			G.fx.puff(to, col, 4, 0.6)
		if bounce > 0 and not hit and G.horde != null:
			# prallt einmal weiter
			G.horde.ai._line_seg(e, def, fl, to, q + dir * 4.5, dir, dmg, col, bounce - 1))


## Druckwelle des Gehörnten Wächters: 5 m gerade Linie, springt über Mauern.
func _shockwave(e, def: Dictionary, dir: Vector2, weak: float) -> void:
	var ln: float = def.wave
	var dmg: float = float(def.dmg) * weak
	G.cam.shake(0.18)
	Sfx.play_at("boss_slam", Vector3(e.p.x, 0, e.p.y), -8.0, 1.3, 0.2)
	var k := 1.5
	while k <= ln:
		var q: Vector2 = e.p + dir * (e.r + k)
		G.fx.ring(Vector3(q.x, 0, q.y), 1.3, Color(1.0, 0.45, 0.15), 0.35)
		G.fx.puff(Vector3(q.x, 0.3, q.y), Color(1.0, 0.5, 0.2), 6, 1.2)
		G.game.damage_structures(q, 1.3, dmg * e.dm * 0.5)
		k += 1.75
	var pl = G.player
	if pl.alive:
		var rel: Vector2 = pl.pos2() - e.p
		var along: float = rel.dot(dir)
		if along > 0.0 and along < e.r + ln + 1.0 and absf(rel.x * dir.y - rel.y * dir.x) < 1.3:
			pl.hurt(dmg * e.dp * 0.7, e)


# ================================================================= Schaden, Treffer, Tod
func modify_damage(e, def: Dictionary, fl: int, amt: float, from: Vector2, element := "") -> float:
	if fl & F_SHIELD != 0 and from != Vector2.ZERO and not h._aoe and element != "explosion" and amt < 1.0e8 and e.st != ST_DEAD:
		# frontaler Schild: Treffer, die der Blickrichtung entgegenfliegen, prallen ab (Flanke, Explosion und Bogenwurf gehen durch)
		if from.normalized().dot(Vector2(sin(e.yaw), cos(e.yaw))) < -0.3:
			_block(e, def)
			return amt * float(def.get("shield_k", 0.0)) - (1.0 if float(def.get("shield_k", 0.0)) <= 0.0 else 0.0)
	if fl & F_TUNNEL != 0 and e.under and amt < 1.0e8:
		# Erschütterung: eine Explosion trifft doppelt und holt ihn aus dem Boden
		amt *= 2.0
		_rise(e, def)
		e.stun = maxf(e.stun, 1.5)
		G.fx.float_text(Vector3(e.p.x, 2.0, e.p.y), "Erschüttert!", Color(1.0, 0.8, 0.4))
	if fl & F_FRONT != 0 and from != Vector2.ZERO:
		# von vorn: der Treffer fliegt der Blickrichtung entgegen
		if from.dot(Vector2(sin(e.yaw), cos(e.yaw))) < -0.25:
			amt *= 1.0 - float(def.front_armor)
			e.inv = 0.0
	if fl & F_SEGMENTS != 0 and amt < 1.0e8:
		amt = minf(amt, e.mhp / float(def.segments))     # ein Treffer nimmt höchstens ein Teil
	if fl & F_DIVE != 0 and e.alt > 2.0 and amt < 1.0e8:
		amt *= float(def.high_k)                         # hoch oben kaum zu treffen
	if fl & F_HARDEN != 0 and e.ai_s == S_HARD and amt < 1.0e8:
		if element == "wasser" or element == "eis":
			_harden_end(e, true)                          # Wasser und Eis sprengen die Kruste
		else:
			amt *= float(def.harden_k)
	return amt


func on_hit(e, def: Dictionary, fl: int) -> void:
	if fl & F_SHELL != 0 and e.ai_s == S_NONE and e.ai_c <= 0.0:
		e.ai_s = S_SHELL
		e.ai_t = float(def.shell)
		e.inv = float(def.shell)
		e.ai_c = float(def.shell) + float(def.shell_cd)
		e.st = ST_MOVE
		e.tgt = null
		e.tgt_player = false
		h.loop_clip(e, String(def.get("anims", {}).get("shell", "hide")))
		h.sound(e, "special", -9.0, "shield_clank")
	if fl & F_HARDEN != 0 and e.ai_s == S_NONE and e.ai_c <= 0.0 and e.st != ST_DEAD and e.hp < e.mhp * 0.9:
		e.ai_s = S_HARD
		e.ai_t = float(def.harden_t)
		e.ai_c = float(def.harden_t) + float(def.harden_cd)
		e.st = ST_MOVE
		e.tgt = null
		e.tgt_player = false
		h.loop_clip(e, String(def.get("anims", {}).get("harden", "harden")))
		h.sound(e, "special", -8.0, "shield_clank")
		G.fx.ring(Vector3(e.p.x, 0, e.p.y), e.r + 0.8, Color(1.0, 0.45, 0.1, 0.7), 0.5)
	if fl & F_LATCH != 0 and e.ai_s == S_LATCH and String(def.latch) == "bite":
		# der Dämonenhund lässt los, sobald er selbst Schaden nimmt
		e.ai_s = S_NONE
		e.ai_c = 2.5
		e.kn = Vector2(cos(e.ai_d), sin(e.ai_d)) * 10.0


func on_death(e, def: Dictionary, fl: int) -> void:
	if fl & F_CLOUD != 0:
		hazard(String(def.cloud), e.p, float(def.cloud_r), float(def.cloud_t), float(def.dmg) * e.dp)
		G.fx.puff(Vector3(e.p.x, 0.6, e.p.y), HAZ_COL[String(def.cloud)], 14, 1.2)
	if fl & F_THIEF != 0:
		_loot_return(e)
	if fl & F_STEAL != 0 and e.carry > 0.0 and G.coins != null:
		G.coins.drop(e.p, int(ceil(e.carry)))            # abschießen gibt alles zurück
		e.carry = 0.0
	if fl & F_SPLIT != 0 and not e.no_split:
		for k in int(def.split):
			if h.alive >= G.max_alive():
				break
			var a: float = e.yaw + PI * k + 0.6
			var q: Vector2 = e.p + Vector2(cos(a), sin(a)) * e.r * 0.7
			if G.field.is_solid(q):
				q = e.p
			var m = h.spawn(e.t, q, e.hm * float(def.split_hp), e.dm * 0.6, e.dp * 0.6)
			m.no_split = true
			m.sc *= 0.6
			m.vs *= 0.6
			m.r *= 0.6
			m.sp *= 1.25
			m.coins = 1
			m.home = e.home
			m.leash = e.leash
			m.aggro = true
			m.kn = Vector2(cos(a), sin(a)) * 6.0


# ================================================================= revive (Matrosen-Zombie)
func go_down(e, def: Dictionary) -> void:
	e.st = 3                        # ST_DOWN
	e.hp = 1.0
	e.revived = true
	e.tgt = null
	e.tgt_player = false
	e.v = Vector2.ZERO
	e.ai_t = float(def.revive_wait)
	e.ai_s = S_NONE
	e.act = 0.0
	e.bl = 0.0
	h.play(e, "death")
	h._snd(e, "death", -13.0, 0.05, "pop_small")


func tick_down(e, def: Dictionary, dt: float) -> void:
	e.ai_t -= dt
	if e.ai_t > 0.0:
		return
	# steht wieder auf
	e.st = ST_MOVE
	e.hp = e.mhp * float(def.revive)
	e.coins = maxi(0, e.coins - 1)
	e.fl = 0.6
	var d: float = h.play(e, String(def.get("anims", {}).get("revive", "revive")))
	e.stun = maxf(d, 0.4)
	h.sound(e, "special", -12.0)
	G.fx.puff(Vector3(e.p.x, 0.4, e.p.y), Color(0.5, 0.9, 0.7), 6, 0.8)


# ================================================================= Sonderangriffe der neuen Bosse
func boss_special(e, def: Dictionary, kind: String, pp: Vector2, p_ok: bool) -> void:
	var pos3 := Vector3(e.p.x, 0, e.p.y)
	var tg: Vector2 = pp
	if not p_ok or e.p.distance_to(pp) > 26.0:
		var gs = G.game.goal_structure
		tg = gs.mid if gs != null else e.p + Vector2(sin(e.yaw), cos(e.yaw)) * 8.0
	match kind:
		"broadside":
			# Kapitän Glibber: Breitseite – fünf Kugeln im Fächer
			e.sp_t = 6.0
			h.play(e, "broadside")
			Sfx.play_at("t_cannon", pos3, -3.0, 0.8)
			var base: Vector2 = tg - e.p
			var dist: float = clampf(base.length(), 6.0, 20.0)
			var bd: Vector2 = base.normalized()
			var shot := {"family": def.family, "dmg": float(def.dmg) * 0.35, "splash": 2.4}
			for k in 5:
				var dir: Vector2 = bd.rotated(deg_to_rad(-30.0 + 15.0 * k))
				_shoot_arc(e, shot, e.p + dir * dist, 1.0, 0.8)
				telegraph(e.p + dir * dist, 2.4, clampf(dist / 14.0, 0.6, 1.2), Callable())
			h.bossctl.expose_now(e)
		"spores":
			# Mooskönigin: Sporenfelder
			e.sp_t = 7.0
			h.play(e, "special")
			for k in 3:
				var a := _rng.randf() * TAU
				var q: Vector2 = tg + Vector2(cos(a), sin(a)) * _rng.randf_range(0.0, 4.0)
				telegraph(q, 3.0, 0.9, func(): hazard("spore", q, 3.0, 6.0, 0.0))
			G.fx.ring(pos3, 5.0, HAZ_COL.spore, 0.6)
		"wreck":
			# Rostbrocken: wirft ein Autowrack
			e.sp_t = 5.5
			h.play(e, "special")
			_shoot_arc(e, {"family": def.family, "dmg": float(def.dmg) * 0.7, "splash": 3.6}, tg, 1.0)
			telegraph(tg, 3.6, clampf(e.p.distance_to(tg) / 14.0, 0.6, 1.2), Callable())
			h.bossctl.expose_now(e)
		"spawn_spit":
			# Der Schlund: spuckt Giftkröten
			e.sp_t = 6.0
			h.play(e, "special")
			var st: int = int(D.ENEMY_INDEX[String(def.summon)])
			for k in 3:
				var a2 := _rng.randf() * TAU
				var q: Vector2 = tg + Vector2(cos(a2), sin(a2)) * _rng.randf_range(1.0, 4.0)
				var to := Vector3(q.x, 0.2, q.y)
				telegraph(q, 1.4, 0.9, Callable())
				var hm: float = e.hm * 0.45
				var dm: float = e.dm
				var dp: float = e.dp
				var home: Vector2 = e.home
				var leash: float = e.leash
				G.game.launch(Vector3(e.p.x, 2.0, e.p.y), to, 0.9, 5.0, Color(0.5, 0.9, 0.2), func():
					if G.horde != null and G.horde.alive < G.max_alive() and not G.field.is_solid(q):
						var m = G.horde.spawn(st, q, hm, dm, dp)
						m.home = home
						m.leash = leash
						m.aggro = true
						m.coins = 0
						G.fx.puff(to, Color(0.5, 0.9, 0.2), 8, 1.0))
		"freeze_ground":
			# Frostbrocken: friert den Boden ein
			e.sp_t = 7.0
			h.play(e, "special")
			Sfx.play_at("ice_shatter", pos3, -3.0, 0.7)
			var c0: Vector2 = e.p
			var dm0: float = float(def.dmg) * e.dp * 0.4
			telegraph(c0, 5.0, 1.0, func():
				hazard("ice", c0, 5.0, 7.0, 0.0)
				if G.player.alive and G.player.pos2().distance_to(c0) < 5.0:
					G.player.hurt(dm0, null)
					G.player.slow(0.5, 2.0))
			for k in 3:
				var a3 := _rng.randf() * TAU
				var q3: Vector2 = tg + Vector2(cos(a3), sin(a3)) * _rng.randf_range(0.0, 3.0)
				telegraph(q3, 3.2, 1.0, func(): hazard("ice", q3, 3.2, 7.0, 0.0))
			h.bossctl.expose_now(e)
		"tide":
			# Schleim-Leviathan: Flutwelle in einer Linie auf den Helden zu (rote Zonen nacheinander)
			e.sp_t = 7.0
			h.play(e, "special")
			var dir2: Vector2 = (tg - e.p).normalized() if tg.distance_squared_to(e.p) > 1.0 else Vector2(sin(e.yaw), cos(e.yaw))
			var dmg2: float = float(def.dmg) * 0.6
			var dp2: float = e.dp
			var dm2: float = e.dm
			for k in 7:
				var q4: Vector2 = e.p + dir2 * (e.r + 1.5 + k * 2.6)
				telegraph(q4, 2.2, 1.0 + k * 0.12, func():
					G.fx.puff(Vector3(q4.x, 0.5, q4.y), Color(0.55, 0.85, 0.25), 10, 1.8)
					G.game.damage_structures(q4, 2.2, dmg2 * dm2 * 0.5)
					if G.player.alive and G.player.pos2().distance_to(q4) < 2.4:
						G.player.hurt(dmg2 * dp2, null)
						G.player.push(dir2, 3.0))
			Sfx.play_at("boss_slam", pos3, -2.0, 0.6)
			h.bossctl.expose_now(e)
		"eruption":
			# Paket Z (Magmafürst Brodel): Lavabomben regnen rund um den Helden (rote Zonen), danach brennt der Boden;
			# in der Wutphase fallen mehr Bomben. Nach dem Ausbruch ist der Glutkern offen (Schwachstelle).
			e.sp_t = 7.0
			h.play(e, "special")
			Sfx.play_at("lava_burst", pos3, -2.0, 0.8)
			G.cam.shake(0.25)
			var dmg6: float = float(def.dmg) * 0.45 * e.dp
			var dm6: float = float(def.dmg) * 0.4 * e.dm
			var n6: int = 9 if e.rage else 6
			for k in n6:
				var a6 := _rng.randf() * TAU
				var q6: Vector2 = tg + Vector2(cos(a6), sin(a6)) * (0.0 if k == 0 else _rng.randf_range(2.0, 7.0))
				telegraph(q6, 2.2, 1.0 + k * 0.12, func():
					G.fx.explosion(Vector3(q6.x, 0.4, q6.y), 2.2, Color(1.0, 0.45, 0.1))
					Sfx.play_at("ev_lavabomb_impact", Vector3(q6.x, 0, q6.y), -6.0, 1.0, 0.3)
					hazard("fire", q6, 1.8, 3.5, dmg6 * 0.4)
					G.game.damage_structures(q6, 2.2, dm6)
					if G.player.alive and G.player.pos2().distance_to(q6) < 2.4:
						G.player.hurt(dmg6, null))
			h.bossctl.expose_now(e)
		"rain":
			# Schleim-Leviathan: Schleimregen – viele kleine Einschläge rund um den Helden, Giftpfützen
			e.sp_t = 6.5
			h.play(e, "special")
			var dmg3: float = float(def.dmg) * 0.35 * e.dp
			for k in 8:
				var a5 := _rng.randf() * TAU
				var q5: Vector2 = tg + Vector2(cos(a5), sin(a5)) * _rng.randf_range(0.0, 6.0)
				telegraph(q5, 1.8, 1.0 + _rng.randf() * 0.6, func():
					G.fx.splat(Vector3(q5.x, 0.3, q5.y), Color(0.6, 0.85, 0.2), false)
					hazard("poison", q5, 1.6, 3.0, dmg3 * 0.5)
					if G.player.alive and G.player.pos2().distance_to(q5) < 1.9:
						G.player.hurt(dmg3, null))
			Sfx.play_at("spit", pos3, -3.0, 0.5)


# ================================================================= Paket G2: neue Rollen (Kapitel 6.3)
func _g2_pre(e, def: Dictionary, fl: int, dt: float, pp: Vector2, p_ok: bool, d2p: float) -> bool:
	if fl & F_HEALER != 0:
		e.ai_t -= dt
		if e.ai_t <= 0.0:
			e.ai_t = float(def.heal_cd) * _rng.randf_range(0.9, 1.1)
			_heal_pulse(e, def)
		# hält Abstand zum Helden und bleibt hinter den anderen
		if p_ok and d2p < float(def.keep) ** 2 and e.st == ST_MOVE:
			var away: Vector2 = (e.p - pp).normalized()
			var q: Vector2 = e.p + away * 4.0
			if not G.field.is_solid(q) and G.field.in_bounds(q, 3.0) and G.field.structure_at(q) == null:
				e.goal = q
				e.g_on = true
	if fl & F_BROOD != 0 and not e.kid:
		e.ai_t -= dt
		if e.ai_t <= 0.0:
			e.ai_t = float(def.brood_cd) * _rng.randf_range(0.9, 1.15)
			_brood(e, def)
	if fl & F_JAMMER != 0:
		if _jam_seek(e, def, dt):
			return true
	if fl & F_THIEF != 0:
		if _thief_seek(e, def, dt, pp, p_ok):
			return true
	if fl & F_MINI != 0:
		e.sp_t -= dt
		if e.sp_t <= 0.0 and e.st != ST_DEAD:
			var near_goal: bool = G.game.goal_structure != null and e.p.distance_squared_to(G.game.goal_structure.mid) < 400.0
			if (p_ok and d2p < 324.0) or near_goal:
				e.sp_t = float(def.mini_cd) * _rng.randf_range(0.9, 1.1)
				_mini_skill(e, def, pp, p_ok)
				return true
			e.sp_t = 0.5
	return false


## Heiler: heilt alle Gegner im Umkreis um einen Anteil ihres Lebens. Vergiftete heilen nicht – und ein vergifteter Heiler heilt gar nicht.
func _heal_pulse(e, def: Dictionary) -> void:
	var c3 := Vector3(e.p.x, 0, e.p.y)
	if e.poison > 0.0:
		G.fx.puff(c3 + Vector3(0, 1.4, 0), Color(0.5, 0.95, 0.2), 5, 0.6)
		return
	var n := 0
	for o in h.near(e.p, float(def.heal_r)):
		if o != e and o.hp < o.mhp and o.poison <= 0.0 and o.st != ST_DOWN:
			o.hp = minf(o.mhp, o.hp + o.mhp * float(def.heal_pct))
			n += 1
			if n <= 4:
				G.fx.puff(Vector3(o.p.x, 1.0 * o.sc + o.alt, o.p.y), Color(0.45, 1.0, 0.55), 3, 0.5)
	if n > 0:
		h.play(e, String(def.get("anims", {}).get("heal", "heal")))
		G.fx.ring(c3, float(def.heal_r), Color(0.45, 1.0, 0.55, 0.6), 0.6)
		h.sound(e, "special", -12.0, "shaman_heal")


## Brutmutter: lässt Junge schlüpfen (andere Art oder kleine Ausgabe der eigenen).
func _brood(e, def: Dictionary) -> void:
	if h.alive >= G.max_alive() - 8 or e.st == ST_DEAD:
		return
	# Expedition: nur im Kampf (aufgescheucht oder Held in der Nähe) – sonst füllen ferne Mütter das Gebiet mit Jungen
	if e.leash > 0.0 and not e.aggro and (G.player == null or G.player.pos2().distance_squared_to(e.p) > 900.0):
		return
	var kids := 0
	for o in h.near(e.p, 10.0):
		if o.kid:
			kids += 1
	if kids >= int(def.brood_n) * 3:
		return
	var key := String(def.get("brood_key", ""))
	var own: bool = key == ""
	var t: int = e.t if own else int(D.ENEMY_INDEX[key])
	var n: int = int(def.brood_n)
	var made := 0
	for k in n:
		var a: float = e.yaw + PI + (k - (n - 1) * 0.5) * 0.7
		var q: Vector2 = e.p + Vector2(sin(a), cos(a)) * (e.r + 0.6)
		if G.field.is_solid(q) or G.field.structure_at(q) != null:
			q = e.p
		var m = h.spawn(t, q, e.hm * (0.08 if own else 0.6), e.dm * (0.5 if own else 1.0), e.dp * (0.5 if own else 1.0))
		m.kid = true
		m.coins = 0
		m.home = e.home
		m.leash = e.leash
		m.aggro = e.aggro
		m.no_split = true
		m.kn = Vector2(sin(a), cos(a)) * 5.0
		if own:
			m.vs *= 0.4
			m.sc *= 0.4
			m.r *= 0.45
			m.sp *= 1.4
			m.ai_t = 999.0
		made += 1
	if made > 0:
		h.play(e, String(def.get("anims", {}).get("brood", "brood")))
		h.sound(e, "special", -10.0, "boss_summon")
		G.fx.puff(Vector3(e.p.x, 0.6, e.p.y), Color(0.85, 0.95, 0.6), 10, 1.2)


# ---------------------------------------------------------------- Turmstörer: legt einen Turm kurz lahm (EMP, Ranken, Lava, Frost)
func _jam_seek(e, def: Dictionary, dt: float) -> bool:
	if e.ai_c > 0.0 or e.st != ST_MOVE or e.chase:
		return false
	e.g_t -= dt
	if e.g_t <= 0.0:
		e.g_t = 0.8 + _rng.randf() * 0.4
		e.jam_tw = null
		var best := 1600.0
		for tw in G.game.towers:
			if is_instance_valid(tw) and tw.active and tw.stun_t <= 0.0:
				var d: float = tw.pos2().distance_squared_to(e.p)
				if d < best:
					best = d
					e.jam_tw = tw
	var tw = e.jam_tw
	if tw == null or not is_instance_valid(tw) or not tw.active:
		e.jam_tw = null
		return false
	var tp: Vector2 = tw.pos2()
	if e.p.distance_squared_to(tp) < float(def.jam_r) ** 2:
		e.ai_s = S_JAM
		e.ai_t = maxf(0.45, h.play(e, String(def.get("anims", {}).get("jam", "jam"))) * 0.6)
		e.v = Vector2.ZERO
		h.sound(e, "special", -10.0)
		return true
	e.goal = tp
	e.g_on = true
	return false


const JAM_COL := {"vine": Color(0.35, 0.8, 0.25), "emp": Color(0.55, 0.85, 1.0), "lava": Color(1.0, 0.45, 0.1), "frost": Color(0.8, 0.95, 1.0)}


func _jam_run(e, def: Dictionary, dt: float) -> bool:
	e.v = Vector2.ZERO
	var tw = e.jam_tw
	if tw != null and is_instance_valid(tw):
		var to: Vector2 = tw.pos2() - e.p
		e.yaw = lerp_angle(e.yaw, atan2(to.x, to.y), minf(1.0, dt * 10.0))
	e.ai_t -= dt
	if e.ai_t > 0.0:
		return true
	e.ai_s = S_NONE
	e.ai_c = float(def.jam_cd) * _rng.randf_range(0.9, 1.1)
	if tw == null or not is_instance_valid(tw):
		return true
	var kind := String(def.jam)
	var col: Color = JAM_COL.get(kind, Color.WHITE)
	var from := Vector3(e.p.x, 1.0 * e.sc + e.alt, e.p.y)
	var to3: Vector3 = tw.global_position + Vector3(0, 1.6, 0)
	var t_off: float = float(def.jam_t)
	G.game.launch(from, to3, clampf(from.distance_to(to3) / 14.0, 0.4, 1.0), 2.0, col, func():
		if not is_instance_valid(tw):
			return
		var k := 1.0
		var st = tw.get_parent()
		if st != null and "shielded" in st and st.shielded:
			k = 0.5                                          # der Schildgenerator halbiert die Störung
		tw.stun(t_off * k, "ice" if kind == "frost" else "zap")
		if G.fx != null:
			G.fx.ring(tw.global_position, 2.4, col, 0.6)
			G.fx.puff(to3, col, 14, 1.4)
			if kind == "emp":
				G.fx.lightning(to3 + Vector3(0, 1.5, 0), to3 - Vector3(0, 1.2, 0))
		Sfx.play_at("tower_jam_" + kind, to3, -6.0, 1.0, 0.2))
	h.sound(e, "shot", -9.0, "spit")
	return true


# ---------------------------------------------------------------- Dieb: läuft zum Lager, klaut Rohstoffe, flieht
func _is_store(s) -> bool:
	return s != null and "key" in s and (s.key == "lager" or s.key == "bunker" or s.key == "o_zentrale" or s.key == "kistenlager")


func _thief_seek(e, def: Dictionary, dt: float, pp: Vector2, p_ok: bool) -> bool:
	if not e.loot.is_empty() or e.carry > 0.0:
		return false
	if G.game.mode == "exp":
		# Expedition: rafft liegende Münzen zusammen und flieht damit
		e.g_t -= dt
		if e.g_t <= 0.0 and G.coins != null:
			e.g_t = 0.35
			var got: float = G.coins.take(e.p, 1.6)
			if got > 0.0:
				e.carry += got
				h.play(e, String(def.get("anims", {}).get("grab", "grab")))
				h.sound(e, "special", -11.0, "coin")
				if e.carry >= 4.0:
					_loot_begin(e)
					return true
			var c = G.coins.nearest_ground(e.p, 22.0)
			if c != null:
				e.goal = c
				e.ai_n = 1
			else:
				e.ai_n = 0
		if e.ai_n == 1 and e.st == ST_MOVE:
			e.g_on = true
		return false
	# Basis: zum nächsten Lager (sonst Bunker)
	e.g_t -= dt
	if e.g_t <= 0.0:
		e.g_t = 1.0 + _rng.randf() * 0.3
		e.jam_tw = null
		var best := 1.0e9
		for s in G.game.structures:
			if s.alive and "key" in s and (s.key == "lager" or s.key == "kistenlager"):
				var d: float = s.mid.distance_squared_to(e.p)
				if d < best:
					best = d
					e.jam_tw = s
		if e.jam_tw == null:
			e.jam_tw = G.game.goal_structure
	var st = e.jam_tw
	if st != null and is_instance_valid(st) and st.alive and e.st == ST_MOVE and not e.chase:
		# leise: geht über die Wege des Richtungsfelds, nur in der Nähe direkt auf das Lager zu
		if e.p.distance_squared_to(st.mid) < (st.radius + 7.0) ** 2:
			e.goal = st.mid
			e.g_on = true
	return false


## Beute aus dem Lager: zwei Rohstoffe, von denen am meisten da ist. In der Übungsflut wird nichts abgezogen.
func _steal_store(e, def: Dictionary, s) -> void:
	var amt: float = float(def.steal_amt) * sqrt(maxf(e.hm, 1.0))
	var cands: Array = []
	for r in ["wood", "stone", "metal", "fuel"]:
		if P.res(r) > 0:
			cands.append(r)
	cands.sort_custom(func(a, b): return P.res(a) > P.res(b))
	var real: bool = G.game.mode == "flood"
	var parts: Array = []
	for r in cands.slice(0, 2):
		var n := mini(P.res(r), int(amt))
		if n <= 0:
			continue
		if real:
			P.d.res[r] = P.res(r) - n
		e.loot[r] = n
		parts.append("%d %s" % [n, D.RES_NAME[r]])
	if real and not e.loot.is_empty():
		P.resources_changed.emit()
	h.play(e, String(def.get("anims", {}).get("grab", "grab")))
	h.sound(e, "special", -6.0, "coin")
	var c3 := Vector3(e.p.x, 2.2, e.p.y)
	G.fx.float_text(c3, "Geklaut: " + (", ".join(parts) if not parts.is_empty() else "nichts"), Color(1.0, 0.55, 0.35))
	G.fx.puff(c3, Color(1.0, 0.85, 0.3), 8, 1.0)
	_loot_begin(e)


func _loot_begin(e) -> void:
	e.ai_s = S_LOOT
	e.ai_d = 0.0
	e.st = ST_MOVE
	e.tgt = null
	e.tgt_player = false
	var from: Vector2 = G.game.goal_structure.mid if G.game.goal_structure != null else G.player.pos2()
	var out: Vector2 = e.p - from
	e.ai_v = out.normalized() if out.length_squared() > 0.1 else Vector2(1, 0)


func _loot_run(e, def: Dictionary, dt: float, speed: float) -> bool:
	var sp: float = speed * 1.3
	var dir: Vector2 = e.ai_v
	var np: Vector2 = e.p + dir * sp * dt
	if G.field.is_solid(np):
		for a in [0.6, -0.6, 1.2, -1.2, 2.0, -2.0]:
			var d2: Vector2 = dir.rotated(a)
			if not G.field.is_solid(e.p + d2 * sp * dt * 3.0):
				e.ai_v = d2
				dir = d2
				break
		np = e.p + dir * sp * dt
	e.ai_d += dt
	if not G.field.in_bounds(np, 2.0) or e.ai_d > 25.0:
		_loot_escape(e)
		return true
	if not G.field.is_solid(np):
		# springt flink über Mauern hinweg
		var over: bool = G.field.structure_at(np) != null
		e.alt = lerpf(e.alt, 1.6 if over else 0.0, minf(1.0, dt * 10.0))
		e.p = np
	e.v = dir * sp
	e.yaw = atan2(dir.x, dir.y)
	return true


func _loot_escape(e) -> void:
	var parts: Array = []
	for r in e.loot:
		parts.append("%d %s" % [int(e.loot[r]), D.RES_NAME[r]])
	if e.carry > 0.0:
		parts.append("%d Münzen" % int(e.carry))
	if not parts.is_empty():
		P.toast.emit("Ein Dieb ist entkommen: " + ", ".join(parts))
		G.fx.float_text(Vector3(e.p.x, 3.0, e.p.y), "Beute weg!", Color(1.0, 0.5, 0.4))
	e.loot = {}
	e.carry = 0.0
	h.despawn(e)


## Besiegt: die Beute kommt zurück (in der Übungsflut wurde nichts abgezogen).
func _loot_return(e) -> void:
	if e.loot.is_empty():
		return
	var real: bool = G.game.mode == "flood"
	var parts: Array = []
	for r in e.loot:
		if real:
			P.add(r, float(e.loot[r]))
		parts.append("+%d %s" % [int(e.loot[r]), D.RES_NAME[r]])
	G.fx.float_text(Vector3(e.p.x, 2.4, e.p.y), "Beute zurück: " + ", ".join(parts), Color(0.5, 1.0, 0.5))
	Sfx.play_at("coin", Vector3(e.p.x, 0, e.p.y), -6.0, 1.2)
	e.loot = {}


# ---------------------------------------------------------------- Tunnelgräber: unter Mauern hindurch ins Innere
func _tunnel_run(e, def: Dictionary, dt: float, sp: float) -> void:
	var gs = G.game.goal_structure
	var goal: Vector2 = gs.mid if gs != null else G.field.goal
	var to: Vector2 = goal - e.p
	if to.length_squared() > 0.25:
		e.ai_v = e.ai_v.lerp(to.normalized(), minf(1.0, dt * 3.0)).normalized()
	var np: Vector2 = e.p + e.ai_v * sp * dt
	if G.field.is_solid(np):
		var side: Vector2 = e.ai_v.orthogonal()
		np = e.p + side * sp * dt
		if G.field.is_solid(np):
			np = e.p
	e.p = np
	e.ai_d += sp * dt
	e.v = e.ai_v * sp
	var below = G.field.structure_at(e.p)
	if below != null:
		e.ai_n = 1                                         # ist unter einem Gebäude oder einer Mauer durch
	if _rng.randf() < 0.25:
		G.fx.puff(Vector3(e.p.x, 0.1, e.p.y), Color(0.55, 0.45, 0.32), 2, 0.4)   # Erdspur verrät ihn
	var clear: bool = below == null and G.field.structure_at(e.p + e.ai_v * 1.2) == null
	var near: bool = gs != null and to.length() < gs.radius + 3.0
	if clear and ((e.ai_n == 1 and e.ai_d > 3.0) or near or e.ai_t <= 0.0):
		_rise(e, def)
	elif e.ai_t <= -6.0:
		_rise(e, def)                                       # Notbremse: nicht ewig unter der Erde


## Taucht der Tunnelgräber in einer Falle auf, sitzt er fest.
func _tunnel_trap_check(e) -> void:
	var hit := false
	for z in G.game.zones:
		if (z.kind == "spike" or z.kind == "glue") and e.p.distance_squared_to(z.c) < (sqrt(z.r2) + 1.2) ** 2:
			hit = true
	var tr2 = G.game.get_node_or_null("Traps2")
	if not hit and tr2 != null and tr2.near(e.p, 2.2):
		hit = true
	if hit:
		e.stun = maxf(e.stun, 2.5)
		e.hp -= e.mhp * 0.25
		G.fx.float_text(Vector3(e.p.x, 2.0, e.p.y), "In die Falle!", Color(1.0, 0.8, 0.4))
		G.fx.puff(Vector3(e.p.x, 0.5, e.p.y), Color(0.9, 0.85, 0.7), 12, 1.6)
		Sfx.play_at("trap_spike", Vector3(e.p.x, 0, e.p.y), -6.0)


# ---------------------------------------------------------------- Schildträger
func _block(e, def: Dictionary) -> void:
	e.fl = 0.5
	if h.time - e.blk_t > 0.6:
		e.blk_t = h.time
		if e.act <= 0.0 and e.st != ST_ATTACK:
			h.play(e, String(def.get("anims", {}).get("block", "block")))
		Sfx.play_at("shield_clank", Vector3(e.p.x, 0, e.p.y), -11.0, 1.1, 0.08)
		var f := Vector2(sin(e.yaw), cos(e.yaw))
		G.fx.puff(Vector3(e.p.x + f.x * e.r, 0.9 * e.sc, e.p.y + f.y * e.r), Color(1.0, 0.95, 0.7), 4, 0.8)


# ---------------------------------------------------------------- Miniboss: angekündigte Fähigkeit
func _mini_skill(e, def: Dictionary, pp: Vector2, p_ok: bool) -> void:
	var kind := String(def.mini_skill)
	var r: float = float(def.mini_r)
	var dmg: float = float(def.dmg)
	var dp: float = e.dp
	var dm: float = e.dm
	var tg: Vector2 = pp if p_ok else (G.game.goal_structure.mid if G.game.goal_structure != null else e.p)
	e.ai_s = S_SKILL
	e.ai_t = maxf(1.1, h.play(e, String(def.get("anims", {}).get("skill", "skill"))))
	e.st = ST_MOVE
	e.tgt = null
	e.tgt_player = false
	h.sound(e, "special", -5.0, "boss_roar")
	var at: Vector2 = e.p if kind in ["slam", "ring", "frost_ring", "chain"] else tg
	var self_e = e
	match kind:
		"toxic":
			for k in 3:
				var a := _rng.randf() * TAU
				var q: Vector2 = tg + Vector2(cos(a), sin(a)) * (0.0 if k == 0 else _rng.randf_range(2.5, 4.5))
				telegraph(q, 2.2, 1.1, func():
					hazard("poison", q, 2.2, 5.0, dmg * dp * 0.35)
					G.fx.puff(Vector3(q.x, 0.4, q.y), HAZ_COL.poison, 12, 1.2)
					Sfx.play_at("spit_land", Vector3(q.x, 0, q.y), -7.0, 0.7))
			return
	telegraph(at, r, 1.1, _mini_effect.bind(kind, at, r, dmg, dp, dm, self_e))


func _mini_effect(kind: String, at: Vector2, r: float, dmg: float, dp: float, dm: float, self_e) -> void:
	var c3 := Vector3(at.x, 0, at.y)
	var pl = G.player
	var in_r: bool = pl != null and pl.alive and pl.pos2().distance_to(at) < r + 0.4
	match kind:
		"slam", "ring":
			G.cam.shake(0.3)
			G.fx.ring(c3, r, Color(1.0, 0.8, 0.4), 0.5)
			G.fx.puff(c3 + Vector3(0, 0.3, 0), Color(0.7, 0.6, 0.5), 18, 2.0)
			Sfx.play_at("boss_slam", c3, -3.0, 1.2)
			G.game.damage_structures(at, r, dmg * dm * 0.8)
			if in_r:
				pl.hurt(dmg * dp * 1.1, self_e)
				pl.push((pl.pos2() - at).normalized(), 4.0)
		"roots":
			G.fx.puff(c3 + Vector3(0, 0.4, 0), Color(0.45, 0.32, 0.2), 16, 1.6)
			Sfx.play_at("vine_burst", c3, -5.0)
			if in_r:
				pl.hurt(dmg * dp * 0.5, self_e)
				pl.root(1.6)
		"acid":
			hazard("acid", at, r, 6.0, dmg * dm * 0.4)
			hazard("poison", at, r * 0.8, 6.0, dmg * dp * 0.3)
			Sfx.play_at("spit_land", c3, -4.0, 0.6)
			if in_r:
				pl.hurt(dmg * dp * 0.6, self_e)
		"frost_ring":
			hazard("ice", at, r, 6.0, 0.0)
			G.fx.ring(c3, r + 4.0, Color(0.8, 0.95, 1.0), 0.7)
			Sfx.play_at("ice_shatter", c3, -3.0, 0.7)
			for tw in G.game.towers:
				if is_instance_valid(tw) and tw.active and tw.pos2().distance_to(at) < r + 4.0:
					tw.stun(3.0, "ice")
			if in_r:
				pl.hurt(dmg * dp * 0.6, self_e)
				pl.slow(0.5, 2.5)
		"chain":
			hazard("fire", at, r, 3.5, dmg * dp * 0.5)
			G.fx.explosion(c3 + Vector3(0, 0.5, 0), r, Color(1.0, 0.4, 0.1))
			Sfx.play_at("fire_whoosh", c3, -4.0)
			if in_r:
				pl.hurt(dmg * dp * 0.8, self_e)
		"lava":
			# Paket Z (Glutbrecher): Stampfer – an der roten Zone quillt Lava aus dem Boden (brennt 5 s)
			G.cam.shake(0.3)
			G.fx.explosion(c3 + Vector3(0, 0.4, 0), r, Color(1.0, 0.45, 0.1))
			hazard("fire", at, r, 5.0, dmg * dp * 0.45)
			Sfx.play_at("lava_burst", c3, -3.0)
			G.game.damage_structures(at, r, dmg * dm * 0.6)
			if in_r:
				pl.hurt(dmg * dp * 0.9, self_e)
				pl.push((pl.pos2() - at).normalized(), 3.0)

# ---------------------------------------------------------------- Bodenmarkierung: angekündigte Angriffe (rote Zone füllt sich, dann Wirkung)
const TELE_COL := Color(1.0, 0.18, 0.12, 0.28)
const TELE_FILL := Color(1.0, 0.3, 0.15, 0.42)


func telegraph(c: Vector2, radius: float, delay: float, cb: Callable) -> void:
	var m := {"c": c, "r": radius, "t": delay, "t0": maxf(delay, 0.05), "cb": cb}
	var a: MeshInstance3D
	var b: MeshInstance3D
	if _tele_pool.size() >= 2:
		b = _tele_pool.pop_back()
		a = _tele_pool.pop_back()
	else:
		a = _disc(TELE_COL)
		b = _disc(TELE_FILL)
	a.scale = Vector3(radius, 1.0, radius)
	a.position = Vector3(c.x, 0.09, c.y)
	b.scale = Vector3(0.01, 1.0, 0.01)
	b.position = Vector3(c.x, 0.1, c.y)
	a.visible = true
	b.visible = true
	m["a"] = a
	m["b"] = b
	tele.append(m)


func _disc(col: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.04
	cm.radial_segments = 24
	cm.rings = 1
	n.mesh = cm
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.material_override = MK.glow(col, true)
	h.add_child(n)
	return n


func _free_tele(m: Dictionary) -> void:
	for k in ["a", "b"]:
		var n = m.get(k)
		if n != null and is_instance_valid(n):
			n.visible = false
			_tele_pool.append(n)


## Druckwelle angekündigt (Hammer holt aus): die Linie gilt bis zum Schlag als Gefahr (für dodge()).
func warn_line(from: Vector2, dir: Vector2, r: float, ln: float, t: float) -> void:
	var k := 0.0
	while k <= ln + 1.0 and incoming.size() < 48:
		incoming.append([from + dir * (r + k), 1.4, t])
		k += 1.2


## Ausweichrichtung für Punkt p: weg von angekündigten Einschlägen, Bodenmarkern und Gefahrenflächen (Vector2.ZERO = sicher).
func dodge(p: Vector2, margin := 0.8) -> Vector2:
	var out := Vector2.ZERO
	for m in incoming:
		var d: Vector2 = p - m[0]
		var rr: float = m[1] + margin
		if d.length_squared() < rr * rr:
			out += (d.normalized() if d.length_squared() > 0.01 else Vector2.RIGHT) * (rr - d.length())
	for m in tele:
		var d2: Vector2 = p - m.c
		var r2: float = m.r + margin
		if d2.length_squared() < r2 * r2:
			out += (d2.normalized() if d2.length_squared() > 0.01 else Vector2.RIGHT) * (r2 - d2.length())
	for z in hazards:
		if z.dps <= 0.0:
			continue
		var d3: Vector2 = p - z.c
		var r3: float = z.r + margin * 0.5
		if d3.length_squared() < r3 * r3:
			out += (d3.normalized() if d3.length_squared() > 0.01 else Vector2.RIGHT) * (r3 - d3.length())
	return out


func _tick_tele(dt: float) -> void:
	var j := incoming.size() - 1
	while j >= 0:
		incoming[j][2] -= dt
		if incoming[j][2] <= 0.0:
			incoming.remove_at(j)
		j -= 1
	if tele.is_empty():
		return
	var i := tele.size() - 1
	while i >= 0:
		var m: Dictionary = tele[i]
		m.t -= dt
		var k: float = clampf(1.0 - m.t / m.t0, 0.0, 1.0)
		m.b.scale = Vector3(m.r * k, 1.0, m.r * k)
		if m.t <= 0.0:
			tele.remove_at(i)
			_free_tele(m)
			if m.cb.is_valid():
				m.cb.call()
		i -= 1


# ================================================================= Paket Z: Magma-Wesen
## lava_bath: nahe fließender Lava (Vulkaninsel) heilt die Art und läuft schneller (Geheul-Tempo).
func _lava_bath(e, def: Dictionary, dt: float) -> void:
	if _vk == null or e.st == ST_DEAD or not _vk.near_lava(e.p, float(def.get("bath_r", 4.0))):
		return
	e.haste = maxf(e.haste, 0.6)
	if e.hp < e.mhp:
		e.hp = minf(e.mhp, e.hp + e.mhp * float(def.bath) * dt)
		if _rng.randf() < dt * 1.5:
			G.fx.puff(Vector3(e.p.x, 0.7 * e.sc, e.p.y), Color(1.0, 0.55, 0.2), 3, 0.6)
			if e.act <= 0.0 and e.st == ST_MOVE:
				h.play(e, String(def.get("anims", {}).get("bath", "steam")))


## harden: Kruste wird wieder weich (gesprengt = mit Funken und kurzem Taumeln).
func _harden_end(e, broken := false) -> void:
	e.ai_s = S_NONE
	h.loop_clip(e, "")
	if broken:
		e.stun = maxf(e.stun, 0.8)
		G.fx.puff(Vector3(e.p.x, 1.2 * e.sc, e.p.y), Color(0.75, 0.85, 1.0), 10, 1.4)
		G.fx.float_text(Vector3(e.p.x, 2.4 * e.sc, e.p.y), "Kruste gesprengt!", Color(0.6, 0.85, 1.0))
		Sfx.play_at("ice_shatter", Vector3(e.p.x, 0, e.p.y), -6.0, 0.8)
