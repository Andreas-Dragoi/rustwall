extends RefCounted
## Paket Z2 – Verhalten der Maschinen (Stadtruinen). Wird von src/enemy_ai.gd gerufen (nur statische Funktionen; ai = enemy_ai):
##   signal   Ampelwächter: schaltet alle signal_cd Sekunden um (Clip „signal“). Grün: Maschinen im Umkreis signal_r laufen
##            SIGNAL_HASTE Sekunden schneller; Rot: der Held im Umkreis wird SIGNAL_SLOW_T Sekunden gebremst.
##   scoop    Bagger-Golem: schaufelt Schutt (Clip „scoop“) und schleudert ihn auf den Helden (scoop_min…scoop_r Meter):
##            rote Zone scoop_zone, dann Einschlag (Schaden am Helden und an Gebäuden).
##   abriss   Miniboss Abrisskran: die Abrissbirne schmettert in die rote Zone, Mauern bekommen doppelten Schaden.
##   spannung Boss Bürgermeister Bolzen: Stromstöße laufen in drei Linien (Wut: fünf) über den Boden auf den Helden zu,
##            jede Stelle mit roter Vorwarnung; danach ist der Akku in der Brust offen (Schwachstelle).

const D = preload("res://src/data.gd")

const S_SCOOP := 30
const S_SIGNAL := 31
const SIGNAL_HASTE := 3.0
const SIGNAL_SLOW := 0.6
const SIGNAL_SLOW_T := 2.0
const SCOOP_FLIGHT := 0.8
const SPANNUNG_LINES := 3
const SPANNUNG_STEPS := 6
const SPANNUNG_R := 1.9
const ZAP_COL := Color(0.45, 0.85, 1.0)


## Laufende Zustände (S_SCOOP, S_SIGNAL). Rückgabe true: der Schritt ist erledigt.
static func run(ai, e, def: Dictionary, dt: float, pp: Vector2, p_ok: bool) -> bool:
	e.v = Vector2.ZERO
	e.ai_t -= dt
	if e.ai_t > 0.0:
		return true
	if e.ai_s == S_SCOOP:
		_scoop_throw(ai, e, def)
	e.ai_s = 0
	return true


## Neue Aktion beginnen? (aus enemy_ai.pre; die Abklingzeit e.ai_c zählt dort schon herunter)
static func start(ai, e, def: Dictionary, fl: int, dt: float, pp: Vector2, p_ok: bool, d2p: float) -> bool:
	if e.ai_s != 0 or e.ai_c > 0.0 or e.st == 2 or not p_ok:
		return false
	if fl & ai.F_SIGNAL != 0:
		var sr: float = float(def.get("signal_r", 8.0))
		if d2p < (sr + 6.0) * (sr + 6.0):
			_signal(ai, e, def, pp, d2p < sr * sr)
			return true
	if fl & ai.F_SCOOP != 0:
		var mn: float = float(def.get("scoop_min", 4.0))
		var mx: float = float(def.get("scoop_r", 12.0))
		if d2p > mn * mn and d2p < mx * mx and e.st == 0:
			_scoop_start(ai, e, def, pp)
			return true
	return false


# ---------------------------------------------------------------- Ampelwächter
static func _signal(ai, e, def: Dictionary, pp: Vector2, _hero_in: bool) -> void:
	var h = ai.h
	e.ai_c = float(def.get("signal_cd", 9.0)) * ai._rng.randf_range(0.85, 1.15)
	e.ai_s = S_SIGNAL
	e.ai_t = maxf(0.5, h.play(e, String(def.get("anims", {}).get("signal", "signal"))) * 0.6)
	e.st = 0
	e.tgt = null
	e.tgt_player = false
	var sr: float = float(def.get("signal_r", 8.0))
	var c3 := Vector3(e.p.x, 0, e.p.y)
	# abwechselnd Rot und Grün (Rot zuerst); Rot bremst nur, wenn der Held im Kreis steht
	var red: bool = e.ai_n % 2 == 0
	e.ai_n += 1
	if red:
		G.fx.ring(c3, sr, Color(1.0, 0.25, 0.2, 0.7), 0.6)
		G.fx.float_text(c3 + Vector3(0, 3.2 * e.sc * 0.6 + 1.2, 0), "Rot!", Color("FF4A3A"))
		Sfx.play_at("ampel_red", c3, -6.0)
		if G.player != null and G.player.alive and G.player.pos2().distance_to(e.p) < sr:
			G.player.slow(SIGNAL_SLOW, SIGNAL_SLOW_T)
	else:
		G.fx.ring(c3, sr, Color(0.3, 1.0, 0.45, 0.7), 0.6)
		G.fx.float_text(c3 + Vector3(0, 3.2 * e.sc * 0.6 + 1.2, 0), "Grüne Welle!", Color("5AFF7A"))
		Sfx.play_at("ampel_green", c3, -6.0)
		for o in h.near(e.p, sr):
			if o != e and String(D.ENEMIES[o.t].family) == "maschinen":
				o.haste = maxf(o.haste, SIGNAL_HASTE)


# ---------------------------------------------------------------- Bagger-Golem
static func _scoop_start(ai, e, def: Dictionary, pp: Vector2) -> void:
	var h = ai.h
	e.ai_c = float(def.get("scoop_cd", 8.0)) * ai._rng.randf_range(0.9, 1.1)
	e.ai_s = S_SCOOP
	var dur: float = h.play(e, String(def.get("anims", {}).get("scoop", "scoop")))
	e.ai_t = maxf(0.6, dur * 0.62)
	e.st = 0
	e.tgt = null
	e.tgt_player = false
	var to: Vector2 = pp - e.p
	e.yaw = atan2(to.x, to.y)
	e.ai_v = pp
	var zone: float = float(def.get("scoop_zone", 2.6))
	var dmg: float = float(def.dmg) * e.dp * 0.55
	var dm: float = float(def.dmg) * e.dm * 0.5
	var c: Vector2 = pp
	h.sound(e, "special", -6.0)
	ai.telegraph(c, zone, e.ai_t + SCOOP_FLIGHT, func():
		var c3 := Vector3(c.x, 0, c.y)
		G.fx.puff(c3 + Vector3(0, 0.4, 0), Color(0.7, 0.68, 0.62), 18, 2.0)
		G.cam.shake(0.15)
		Sfx.play_at("scoop_impact", c3, -4.0, 1.0, 0.2)
		G.game.damage_structures(c, zone, dm)
		if G.player != null and G.player.alive and G.player.pos2().distance_to(c) < zone + 0.3:
			G.player.hurt(dmg, null)
			G.player.slow(0.6, 1.2))


static func _scoop_throw(ai, e, def: Dictionary) -> void:
	var from := Vector3(e.p.x, 2.6 * e.sc * 0.5 + 1.0, e.p.y)
	var c: Vector2 = e.ai_v
	G.game.launch(from, Vector3(c.x, 0.3, c.y), SCOOP_FLIGHT, 5.0, Color(0.6, 0.58, 0.52), func(): pass)
	Sfx.play_at("scoop_throw", from, -6.0, 1.0, 0.2)


# ---------------------------------------------------------------- Miniboss Abrisskran
static func mini_abriss(at: Vector2, r: float, dmg: float, dp: float, dm: float, self_e) -> void:
	var c3 := Vector3(at.x, 0, at.y)
	var pl = G.player
	G.cam.shake(0.4)
	G.fx.ring(c3, r, Color(1.0, 0.8, 0.3), 0.5)
	G.fx.puff(c3 + Vector3(0, 0.4, 0), Color(0.7, 0.66, 0.6), 22, 2.2)
	Sfx.play_at("wrecking_ball", c3, -2.0, 1.0, 0.1)
	G.game.damage_structures(at, r, dmg * dm * 1.6)
	if pl != null and pl.alive and pl.pos2().distance_to(at) < r + 0.4:
		pl.hurt(dmg * dp * 1.0, self_e)
		pl.push((pl.pos2() - at).normalized(), 3.5)


# ---------------------------------------------------------------- Boss Bürgermeister Bolzen
static func boss_spannung(ai, e, def: Dictionary, tg: Vector2) -> void:
	var h = ai.h
	e.sp_t = 7.0
	h.play(e, "special")
	var pos3 := Vector3(e.p.x, 0, e.p.y)
	Sfx.play_at("boss_zap", pos3, -2.0, 0.9)
	G.cam.shake(0.2)
	var n: int = SPANNUNG_LINES + (2 if e.rage else 0)
	var base: Vector2 = (tg - e.p).normalized() if tg.distance_squared_to(e.p) > 1.0 else Vector2(sin(e.yaw), cos(e.yaw))
	var dmg: float = float(def.dmg) * 0.42 * e.dp
	var dm: float = float(def.dmg) * 0.35 * e.dm
	for li in n:
		var dir: Vector2 = base.rotated((li - (n - 1) * 0.5) * 0.42)
		for k in SPANNUNG_STEPS:
			var q: Vector2 = e.p + dir * (e.r + 1.6 + k * 2.7)
			if not G.field.in_bounds(q, 1.0):
				break
			ai.telegraph(q, SPANNUNG_R, 0.9 + k * 0.12, func():
				var q3 := Vector3(q.x, 0, q.y)
				G.fx.lightning(q3 + Vector3(0, 7.0, 0), q3 + Vector3(0, 0.2, 0))
				G.fx.ring(q3, SPANNUNG_R, ZAP_COL, 0.35)
				G.game.damage_structures(q, SPANNUNG_R, dm)
				if G.player != null and G.player.alive and G.player.pos2().distance_to(q) < SPANNUNG_R + 0.2:
					G.player.hurt(dmg, null)
					G.player.slow(0.7, 1.0))
	# Türme in der Nähe flackern kurz
	for tw in G.game.towers:
		if is_instance_valid(tw) and tw.active and tw.pos2().distance_to(e.p) < 14.0:
			tw.stun(1.5, "emp")
	h.bossctl.expose_now(e)
