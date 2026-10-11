extends Node3D
## Rucksack der Expedition, sichtbar gemacht:
##  - Kraxe auf dem Rücken des Helden mit Teil-Modellen je Rohstoff – oder die Ladung auf dem Begleiter (companion.gd)
##  - Ladekreis um die Quelle, die gerade abgebaut wird (füllt sich beim Anlaufen, zeigt dann den Abbau-Fortschritt)
##  - Abwerfen: ein Haufen auf dem Boden, den man später wieder einsammeln kann
## Die Zahlen (Gewicht, Platz) bleiben in expedition.gd; hier wird nur gezeigt und abgeworfen.

const D = preload("res://src/data.gd")
const Models = preload("res://src/models.gd")

const KRAXE_SLOTS := [2, 1, 4, 0.25]   # Ladung auf der Kraxe: 2 nebeneinander, 4 Lagen (Abstand im Figurenmaß); voll etwa bis zum Scheitel
const PILE_DELAY := 1.6               # so lange liegt ein abgeworfener Haufen, bevor man ihn wieder aufnimmt
const PILE_RADIUS := 1.5
const CD = preload("res://src/companion_data.gd")

const RING_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform vec4 col : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform float alpha = 1.0;
uniform float pulse = 0.0;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float a = atan(q.x, -q.y) / 6.2831853 + 0.5;
	float band = smoothstep(0.80, 0.83, r) * (1.0 - smoothstep(0.95, 0.98, r));
	float inner = smoothstep(0.70, 0.73, r) * (1.0 - smoothstep(0.77, 0.80, r));
	float fill = step(a, progress);
	vec3 c = mix(vec3(0.08, 0.1, 0.16), col.rgb, fill);
	float ia = inner * step(a, charge);
	vec3 outc = c * band + vec3(1.0) * ia;
	ALBEDO = outc + col.rgb * pulse * band;
	ALPHA = (band * (0.55 + 0.45 * fill) + ia) * alpha;
}
"""

var ex: Node3D                         # die Expedition
var _stack: Node3D                    # BoneAttachment3D am Knochen prop_back
var _kraxe: Node3D
var _load: Node3D
var _stack_sig := ""
var _ring: MeshInstance3D
var _mat: ShaderMaterial
var _pulse := 0.0
var _last_hits := -1
var piles: Array = []                 # {n: Node3D, p: Vector2, res: String, amt: float, t: float}


func setup(expedition: Node3D) -> void:
	ex = expedition
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = RING_SHADER
	_mat.shader = sh
	_ring = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	_ring.mesh = pm
	_ring.material_override = _mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)


# ================================================================= Kraxe auf dem Rücken
## Ohne Begleiter trägt der Held eine Holz-Kraxe (cg_kraxe) am Knochen prop_back; darauf liegen die Teil-Modelle
## je Rohstoff (blender/cargo.py), höchstens KRAXE_SLOTS Stück – nie höher als etwa eine Kopflänge über dem Kopf.
## Mit Begleiter trägt der Begleiter alles (companion.gd) und die Kraxe bleibt unsichtbar.
func _ensure_stack() -> void:
	var h = ex.hero
	if h == null or h.body == null or h.body.skel == null:
		return
	if _stack != null and is_instance_valid(_stack) and _stack.get_parent() == h.body.skel:
		return
	var ba := BoneAttachment3D.new()
	ba.name = "BackStack"
	h.body.skel.add_child(ba)
	ba.bone_name = "prop_back"
	_stack = ba
	_kraxe = Models.glb("cg_kraxe")
	ba.add_child(_kraxe)
	_kraxe.position = Vector3(0, -0.02, -0.12)
	for gi in _kraxe.find_children("*", "GeometryInstance3D", true, false):
		(gi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ld: Node3D = Models.find(_kraxe, "load")
	_load = Node3D.new()
	_load.name = "Load"
	(ld if ld != null else _kraxe).add_child(_load)
	_stack_sig = ""


## Wer trägt? Der aktive Begleiter (wenn es ihn gibt), sonst der Held.
func companion():
	var c = ex.get("companion")
	if c != null and is_instance_valid(c) and String(c.key) != "":
		return c
	return null


## Hier landen Abbau-Brocken: auf der Ladefläche des Begleiters oder auf der Kraxe.
func load_point() -> Vector3:
	var c = companion()
	if c != null:
		return c.load_point()
	if _load != null and is_instance_valid(_load) and _load.is_inside_tree():
		return _load.global_position + Vector3(0, 0.3, 0)
	return ex.hero.global_position + Vector3(0, 1.6, 0)


## Wie viele Teile von jedem Rohstoff liegen auf der Kraxe? (nach Gewichtsanteil am Rucksack)
func stack_counts() -> Dictionary:
	return CD.cargo_counts(ex.loot, ex.weight, ex.cap, CD.slot_count(KRAXE_SLOTS), ex.unit_weight)


func _rebuild_stack() -> void:
	var counts := stack_counts()
	var sig := str(counts)
	if sig == _stack_sig:
		return
	_stack_sig = sig
	CD.build_cargo(_load, counts, KRAXE_SLOTS)


# ================================================================= Abwerfen und wieder aufnehmen
## Wirft amt Einheiten von r ab (alles, wenn amt < 0). Rückgabe: abgeworfene Menge.
func drop(r: String, amt := -1.0) -> float:
	var have := float(ex.loot.get(r, 0.0))
	if r == "coins" or have < 1.0:
		return 0.0
	var n := have if amt < 0.0 else minf(amt, have)
	ex.loot[r] = have - n
	if float(ex.loot[r]) < 0.5:
		ex.loot.erase(r)
	ex._recalc_weight()
	var hp: Vector2 = ex.hero.pos2()
	var back := Vector2(sin(ex.hero.rotation.y), cos(ex.hero.rotation.y)) * -1.1
	var at := hp + back + Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
	for pl in piles:          # auf einen nahen Haufen derselben Art legen
		if pl.res == r and (pl.p as Vector2).distance_to(at) < 1.2:
			pl.amt = float(pl.amt) + n
			pl.t = 0.0
			pl.armed = false
			_pile_label(pl)
			_drop_fx(at, r, n)
			return n
	var node := Node3D.new()
	add_child(node)
	node.position = Vector3(at.x, 0, at.y)
	var heap := Node3D.new()
	node.add_child(heap)
	heap.rotation.y = randf() * TAU
	CD.build_cargo(heap, {r: 4}, [2, 2, 1, 0.5])            # Haufen aus den Teil-Modellen des Rohstoffs
	var lb := Label3D.new()
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.pixel_size = 0.012
	lb.font_size = 44
	lb.outline_size = 12
	lb.position = Vector3(0, 1.2, 0)
	lb.no_depth_test = true
	node.add_child(lb)
	var pl2 := {"n": node, "p": at, "res": r, "amt": n, "t": 0.0, "label": lb}
	_pile_label(pl2)
	piles.append(pl2)
	_drop_fx(at, r, n)
	return n


func drop_all() -> float:
	var total := 0.0
	for r in ex.loot.keys():
		if String(r) != "coins":
			total += drop(String(r))
	return total


func _pile_label(pl: Dictionary) -> void:
	var lb: Label3D = pl.label
	lb.text = "%d %s" % [int(pl.amt), D.RES_NAME.get(pl.res, pl.res)]
	lb.modulate = D.RES_COLOR.get(pl.res, Color.WHITE).lightened(0.35)


func _drop_fx(at: Vector2, r: String, n: float) -> void:
	if ex.fx:
		ex.fx.puff(Vector3(at.x, 0.4, at.y), D.RES_COLOR.get(r, Color.WHITE), 8, 0.8)
		ex.fx.float_text(Vector3(at.x, 2.0, at.y), "-%d %s" % [int(n), D.RES_NAME.get(r, r)], Color("FFB24A"))
	Sfx.play("depot_drop", -8.0, 1.2, 0.1)


func _tick_piles(dt: float, pp: Vector2) -> void:
	for i in range(piles.size() - 1, -1, -1):
		var pl: Dictionary = piles[i]
		pl.t = float(pl.t) + dt
		(pl.n as Node3D).position.y = 0.0
		var dist: float = (pl.p as Vector2).distance_to(pp)
		if dist > PILE_RADIUS + 0.6:
			pl.armed = true            # erst wieder aufnehmen, wenn der Held einmal weggegangen ist
		if not bool(pl.get("armed", false)) or float(pl.t) < PILE_DELAY or ex.hero.mounted:
			continue
		if dist > PILE_RADIUS:
			continue
		var got: float = ex.add_pack(String(pl.res), float(pl.amt))
		if got <= 0.0:
			continue
		pl.amt = float(pl.amt) - got
		if ex.fx:
			ex.fx.float_text(ex.hero.global_position + Vector3(0, 2.6, 0), "+%d %s" % [int(got), D.RES_NAME.get(pl.res, pl.res)], D.C_GOLD)
		Sfx.play("coin", -10.0, 0.8, 0.1)
		if float(pl.amt) < 0.5:
			(pl.n as Node3D).queue_free()
			piles.remove_at(i)
		else:
			pl.t = 0.0
			pl.armed = false
			_pile_label(pl)


# ================================================================= Ladekreis
## charge: 0..1 Anlaufen, node: die Quelle (oder null), hint: nur andeuten (Quelle in Reichweite, Held läuft)
func show_ring(node, charge: float, hint: bool) -> void:
	if node == null or node.gone:
		_ring.visible = false
		_last_hits = -1
		return
	_ring.visible = true
	var rad: float = node.reach() * 0.75
	_ring.scale = Vector3(rad, 1.0, rad)
	_ring.position = Vector3(node.p.x, 0.06, node.p.y)
	var col: Color = D.RES_COLOR.get(node.res, Color.WHITE)
	_mat.set_shader_parameter("col", col.lightened(0.15))
	_mat.set_shader_parameter("progress", 1.0 - float(node.left) / maxf(float(node.total), 0.001))
	_mat.set_shader_parameter("charge", charge)
	_mat.set_shader_parameter("alpha", 0.45 if hint else 1.0)
	if int(node.hits_done) != _last_hits:
		if _last_hits >= 0:
			_pulse = 1.0
		_last_hits = int(node.hits_done)


func tick(dt: float, pp: Vector2) -> void:
	_ensure_stack()
	if _stack != null and is_instance_valid(_stack):
		var on_hero: bool = companion() == null
		_stack.visible = on_hero and not ex.hero.mounted
		if on_hero:
			_rebuild_stack()
		elif _stack_sig != "{}":
			_stack_sig = "{}"
			CD.build_cargo(_load, {}, KRAXE_SLOTS)
	_tick_piles(dt, pp)
	_pulse = maxf(0.0, _pulse - dt * 4.0)
	_mat.set_shader_parameter("pulse", _pulse)
