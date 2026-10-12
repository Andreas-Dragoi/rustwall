extends RefCounted
## Bosskämpfe (Paket G2, Kapitel 6.5): Auftritt, Phasen, Wutphase und Schwachstelle – für alle Bosse gleich,
## die Stellwerte stehen in D.BOSS_PHASES / D.BOSS_RAGE.
##  - Auftritt: großer Name mit Untertitel, die Kamera schwenkt kurz zum Boss.
##  - Phase 2 (unter D.BOSS_PHASES[key].p2 Leben): ein weiterer Sonderangriff kommt in den Wechsel.
##  - Wutphase (unter D.BOSS_RAGE_AT): schneller, stärker, Sonderangriffe öfter, rot glühend.
##  - Schwachstelle: nach jedem großen Angriff ist der Boss D.BOSS_EXPOSE_T Sekunden erschöpft, steht still und nimmt
##    doppelten Schaden; ein leuchtendes Zielzeichen (models/fx_weakspot.glb) schwebt über ihm.
## Die Horde ruft on_spawn(), tick() (jeden Schritt), expose_now() (nach großen Angriffen) und on_defeat().

const D = preload("res://src/data.gd")
const Models = preload("res://src/models.gd")
const MK = preload("res://src/mk.gd")

var h: Node3D
var _banner: CanvasLayer
var _title: Label
var _sub: Label
var _banner_t := 0.0
var _cam_t := 0.0
var _cam_pos = null
var _weak: Node3D                  # Zielzeichen der Schwachstelle
var _rage_fx: Node3D               # Wut-Aura (models/fx_boss_rage.glb)
var log_intro := 0                 # für Tests: so viele Auftritte wurden gezeigt
var log_phase := 0
var log_rage := 0
var log_expose := 0


func _init(horde: Node3D) -> void:
	h = horde


func _cfg(e) -> Dictionary:
	return D.BOSS_PHASES.get(String(D.ENEMIES[e.t].key), {})


## Auftritt eines Bosses. Die zweite Gestalt des Schleimkönigs (bricht aus der Hülle hervor) bekommt nur „Phase 2“.
func on_spawn(e) -> void:
	var def: Dictionary = D.ENEMIES[e.t]
	e.phase = 1
	e.specs = Array(def.get("specials", [])).duplicate()
	var cfg := _cfg(e)
	if h.list.size() > 1 and _is_breakout(e):
		e.phase = 2
		_show_banner(String(def.name), "Phase 2 – " + String(cfg.get("intro", "")), Color(1.0, 0.45, 0.35))
		log_phase += 1
		return
	_show_banner(String(def.name), String(cfg.get("intro", "Boss")), Color("FFD23E"))
	_cam_pos = Vector3(e.p.x, 0, e.p.y)
	_cam_t = 2.2
	log_intro += 1
	Sfx.play("boss_intro", -3.0)


func _is_breakout(e) -> bool:
	for o in h.list:
		if o != e and o.next_phase == String(D.ENEMIES[e.t].key) and o.st == 2:
			return true
	return false


## Jeder Schritt eines Bosses. Rückgabe true: der Boss ist erschöpft und tut nichts.
func tick(e, dt: float) -> bool:
	if e.next_phase != "":
		return false                         # die Hülle des Schleimkönigs hat keine eigenen Phasen
	var cfg := _cfg(e)
	var k: float = e.hp / maxf(e.mhp, 1.0)
	if e.phase == 1 and float(cfg.get("p2", 0.0)) > 0.0 and k < float(cfg.p2):
		_phase2(e, cfg)
	if not e.rage and k < D.BOSS_RAGE_AT:
		_enrage(e)
	if _weak != null and is_instance_valid(_weak) and _weak.get_meta("e", null) == e:
		_weak.visible = e.expose > 0.0
		if e.expose > 0.0:
			var top: float = 2.0 * e.sc * 0.55 + 2.4
			_weak.position = Vector3(e.p.x, e.alt + top + sin(h.time * 6.0) * 0.15, e.p.y)
			_weak.rotation.y += dt * 3.0
	if _rage_fx != null and is_instance_valid(_rage_fx) and _rage_fx.get_meta("e", null) == e:
		_rage_fx.position = Vector3(e.p.x, 0.05, e.p.y)
		_rage_fx.rotation.y += dt * 1.6
		var pul := 1.0 + sin(h.time * 5.0) * 0.06
		_rage_fx.scale = Vector3.ONE * e.r * 1.5 * pul
	if e.expose > 0.0:
		e.expose -= dt
		e.v = Vector2.ZERO
		if e.expose <= 0.0 and _weak != null and is_instance_valid(_weak):
			_weak.visible = false
		return true
	return false


func _phase2(e, cfg: Dictionary) -> void:
	e.phase = 2
	log_phase += 1
	var add := String(cfg.get("add", ""))
	var def: Dictionary = D.ENEMIES[e.t]
	if add != "":
		if e.specs.is_empty():
			e.specs = [e.special] if e.special != "" and e.special != "cycle" and e.special != "all" else ["summon", "spit", "slam"]
		if not e.specs.has(add):
			e.specs.append(add)
		e.special = "cycle"
	e.sp_t = minf(e.sp_t, 1.5)
	var c3 := Vector3(e.p.x, 0, e.p.y)
	G.fx.explosion(c3 + Vector3(0, 1.5, 0), e.r + 3.0, Color(1.0, 0.8, 0.3))
	G.cam.shake(0.35)
	Sfx.play("boss_phase", -2.0)
	_show_banner(String(def.name), "Phase 2!", Color(1.0, 0.75, 0.3))


func _enrage(e) -> void:
	e.rage = true
	e.dm *= float(D.BOSS_RAGE.dmg)
	e.dp *= float(D.BOSS_RAGE.dmg)
	e.tint = Color(minf(e.tint.r * 1.35, 1.8), e.tint.g * 0.7, e.tint.b * 0.6)
	e.phase = maxi(e.phase, 2) + 1
	log_rage += 1
	var c3 := Vector3(e.p.x, 0, e.p.y)
	G.fx.explosion(c3 + Vector3(0, 1.5, 0), e.r + 4.0, Color(1.0, 0.25, 0.15))
	G.cam.shake(0.45)
	Sfx.play("boss_rage", -1.0)
	_show_banner(String(D.ENEMIES[e.t].name), "Wutphase!", Color(1.0, 0.3, 0.25))
	if e.fig != null:
		e.fig.play("special")
	if Models.has_glb("fx_boss_rage"):
		if _rage_fx == null or not is_instance_valid(_rage_fx):
			_rage_fx = Models.glb("fx_boss_rage")
			h.add_child(_rage_fx)
		_rage_fx.set_meta("e", e)
		_rage_fx.visible = true


## Nach einem großen Angriff: Schwachstelle offen.
func expose_now(e) -> void:
	if e == null or e.st == 2 or e.next_phase != "":
		return
	e.expose = D.BOSS_EXPOSE_T
	log_expose += 1
	if Models.has_glb("fx_weakspot"):
		if _weak == null or not is_instance_valid(_weak):
			_weak = Models.glb("fx_weakspot")
			h.add_child(_weak)
		_weak.set_meta("e", e)
		_weak.visible = true
	var cfg := _cfg(e)
	G.fx.float_text(Vector3(e.p.x, 2.0 * e.sc * 0.6 + 2.0, e.p.y), "Schwachstelle: %s!" % String(cfg.get("weak", "jetzt")), Color(1.0, 0.9, 0.3))
	Sfx.play_at("boss_weak", Vector3(e.p.x, 0, e.p.y), -4.0)


## Besiegt (letzte Gestalt): Zähler für die Trophäe, Effekte aufräumen.
func on_defeat(e) -> void:
	var key := String(D.ENEMIES[e.t].key)
	P.count_up("boss_win_" + key, 1)
	if _weak != null and is_instance_valid(_weak):
		_weak.visible = false
	if _rage_fx != null and is_instance_valid(_rage_fx):
		_rage_fx.visible = false
	var tk := String(D.BOSS_PHASES.get(key, {}).get("trophy", ""))
	if tk != "" and int(P.d.counters.get("boss_win_" + key, 0)) == 1:
		P.toast.emit("Neue Trophäe: %s – jetzt im Baumenü unter Schmuck!" % String(D.BUILDINGS[tk].name))


# ---------------------------------------------------------------- Einblendung und Kamera
func _show_banner(title: String, sub: String, col: Color) -> void:
	if _banner == null or not is_instance_valid(_banner):
		_banner = CanvasLayer.new()
		_banner.layer = 6
		h.add_child(_banner)
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		box.offset_top = 230.0
		box.offset_bottom = 430.0
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		_banner.add_child(box)
		_title = Label.new()
		_sub = Label.new()
		for l in [_title, _sub]:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			l.add_theme_color_override("font_outline_color", Color("06142E"))
			box.add_child(l)
		var UI = load("res://src/ui.gd")
		_title.add_theme_font_override("font", UI.font(true))
		_title.add_theme_font_size_override("font_size", 76)
		_title.add_theme_constant_override("outline_size", 22)
		_sub.add_theme_font_override("font", UI.font(true))
		_sub.add_theme_font_size_override("font_size", 38)
		_sub.add_theme_constant_override("outline_size", 14)
	_title.text = title
	_title.add_theme_color_override("font_color", col)
	_sub.text = sub
	_sub.add_theme_color_override("font_color", Color.WHITE)
	_banner.visible = true
	_banner_t = 2.6
	(_title.get_parent() as Control).modulate.a = 1.0


func tick_ui(dt: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= dt
		if _banner != null and is_instance_valid(_banner):
			(_title.get_parent() as Control).modulate.a = clampf(_banner_t / 0.6, 0.0, 1.0)
			if _banner_t <= 0.0:
				_banner.visible = false
	if _cam_t > 0.0:
		_cam_t -= dt
		if G.cam != null:
			if _cam_t > 0.0:
				G.cam.override_target = _cam_pos
			elif G.cam.override_target == _cam_pos:
				G.cam.override_target = null


func clear() -> void:
	if _cam_t > 0.0 and G.cam != null and G.cam.override_target == _cam_pos:
		G.cam.override_target = null
	_cam_t = 0.0
	_banner_t = 0.0
	if _banner != null and is_instance_valid(_banner):
		_banner.visible = false
	if _weak != null and is_instance_valid(_weak):
		_weak.visible = false
	if _rage_fx != null and is_instance_valid(_rage_fx):
		_rage_fx.visible = false
