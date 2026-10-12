extends "res://src/world.gd"
## Übungsplatz (Paket Welt, Kapitel 5.3): Waffen-Testmodus, geöffnet vom Trainingsplatz-Gebäude.
## Eine kleine Wiese mit Trainingspuppen (ruhende, unsichtbare Gegner mit sehr viel Leben unter dem Modell p_dummy).
## Jeder Treffer erscheint als Zahl über der Puppe; rechts stehen Schaden pro Sekunde, Gesamtschaden, Treffer und
## die Waffenliste des Helden (auch Waffen, die er noch nicht besitzt – zum Ausprobieren). Kein Verlust, keine Beute.
## Fähigkeiten laden sofort nach. Für die Kampf-Anzeige (hud.gd) gibt es dieselben Felder wie bei der Flut.

const DW = preload("res://src/data_welt.gd")
const UI = preload("res://src/ui.gd")

const SIZE := 30.0

signal state_changed
signal battle_ended

var wave_idx := 0
var wave_count := 0
var break_left := 0.0
var flood := {}
var result := {}
var bunker_node: Object
var dummies: Array = []          # {e, n (Modell), p, last, acc, acc_t, shake}
var total := 0.0
var hits := 0
var dps := 0.0
var best_dps := 0.0
var trial := ""                  # Schlüssel der gerade getesteten Waffe
var _win: Array = []             # [Zeit, Schaden] der letzten 5 Sekunden
var _panel: Control
var _dps_l: Label
var _tot_l: Label
var _hit_l: Label
var _best_l: Label
var _panel_sig := ""


class FakeBunker:
	var hp := 1.0
	var max_hp := 1.0
	var alive := true


func _ready() -> void:
	mode = "practice"
	var th: Dictionary = D.AREAS[0].duplicate()
	setup_common(th, Vector2(-SIZE, -SIZE), int(SIZE), int(SIZE), 2.0)
	bunker_node = FakeBunker.new()
	field.set_goal(Vector2(0, -20))
	make_ground(Vector2(-SIZE, -SIZE), Vector2(SIZE * 2, SIZE * 2), [PackedVector2Array([Vector2(0, 8), Vector2(0, -16)])], 1.6)
	_scenery()
	spawn_hero(String(P.d.hero_sel), Vector2(0, 3))
	hero.died.connect(func(): hero._respawn = 1.0)
	for i in DW.TRAIN_DUMMIES:
		var x := (i - (DW.TRAIN_DUMMIES - 1) * 0.5) * 3.2
		_add_dummy(Vector2(x, -4.0 - absf(x) * 0.3))
	trial = String(hero.weapon_key)
	running = true
	Music.set_mood("peace")
	Sfx.play("train_start", -4.0)
	_make_panel.call_deferred()
	_hide_flood_rows.call_deferred()
	P.toast.emit("Übungsplatz: Probiere deine Waffen an den Puppen aus. Nichts geht verloren.")


func _scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 70:
		var a := rng.randf() * TAU
		var r := rng.randf_range(SIZE * 0.72, SIZE * 1.4)
		var p := Vector2(cos(a), sin(a)) * r
		scatter_var("p_tree_pine", 3, Vector3(p.x, 0, p.y), rng, 0.9, 1.3)
		field.block_circle(p, 1.0)
	for i in 160:
		var q := Vector2(rng.randf_range(-SIZE, SIZE), rng.randf_range(-SIZE, SIZE))
		if q.length() < SIZE * 0.68 and absf(q.x) > 2.0:
			scatter_var("p_grass", 2, Vector3(q.x, 0, q.y), rng, 0.8, 1.3)
	for i in 14:
		var a2 := TAU * i / 14.0
		var p2 := Vector2(cos(a2), sin(a2)) * SIZE * 0.62
		place_model("p_fence", Vector3(p2.x, 0, p2.y), a2 + PI * 0.5)
	if Models.has_glb("b_training"):
		place_model("b_training", Vector3(-11, 0, 6), 0.6)
	place_model("p_flag_exit", Vector3(4.0, 0, 8.0))
	scatter_commit()
	make_ambient("gruental")
	cam.bounds = Rect2(-SIZE * 0.6, -SIZE * 0.6, SIZE * 1.2, SIZE * 1.2)


func _add_dummy(p: Vector2) -> void:
	var e = horde.spawn(D.E_BRUTE, p, 1.0, 1.0, 1.0)
	e.stat = true
	e.hide = true
	e.r = 0.7
	e.coins = 0
	e.mhp = DW.TRAIN_DUMMY_HP
	e.hp = e.mhp
	var n: Node3D = place_model("p_dummy", Vector3(p.x, 0, p.y), 0.0, 1.5) if Models.has_glb("p_dummy") else Node3D.new()
	var sway := Models.find(n, "sway_dummy")
	field.block_circle(p, 0.6)
	dummies.append({"e": e, "n": n, "sway": sway, "p": p, "last": e.hp, "acc": 0.0, "acc_t": 0.0, "shake": 0.0})


func _physics_process(dt: float) -> void:
	tick_common(dt)
	if ended or hero == null:
		return
	for sl in hero.skills.slots:
		sl.left = minf(float(sl.left), 1.0)          # Fähigkeiten laden auf dem Übungsplatz schnell nach
	var now := time
	for d in dummies:
		var e = d.e
		if e.st == 2:                                  # sollte nie passieren – dann neue Puppe
			var ne = horde.spawn(D.E_BRUTE, d.p, 1.0, 1.0, 1.0)
			ne.stat = true
			ne.hide = true
			ne.r = 0.7
			ne.coins = 0
			ne.mhp = DW.TRAIN_DUMMY_HP
			ne.hp = ne.mhp
			d.e = ne
			d.last = ne.hp
			continue
		var lost: float = float(d.last) - float(e.hp)
		if lost > 0.01:
			d.acc = float(d.acc) + lost
			total += lost
			hits += 1
			_win.append([now, lost])
			d.shake = 0.35
			if int(hits) % 3 == 0:
				Sfx.play_at("dummy_hit", Vector3(d.p.x, 1.0, d.p.y), -10.0, 1.0, 0.08)
		d.acc_t = float(d.acc_t) - dt
		if float(d.acc) > 0.0 and float(d.acc_t) <= 0.0:
			d.acc_t = 0.18
			var big: bool = float(d.acc) > hero.dmg * 1.6
			fx.float_text(Vector3(d.p.x + randf_range(-0.4, 0.4), 2.6 + randf_range(0.0, 0.5), d.p.y), str(int(round(float(d.acc)))), D.C_GOLD if big else Color.WHITE)
			d.acc = 0.0
		if e.hp < e.mhp * 0.3:
			e.hp = e.mhp
			Sfx.play_at("dummy_reset", Vector3(d.p.x, 1.0, d.p.y), -8.0, 1.0, 0.5)
		d.last = e.hp
		e.slow = 0.0
		e.burn = 0.0
		e.poison = 0.0
		if d.shake > 0.0:
			d.shake = maxf(0.0, float(d.shake) - dt)
			if d.sway != null:
				(d.sway as Node3D).rotation.x = sin(float(d.shake) * 40.0) * float(d.shake) * 0.5
	while _win.size() > 0 and now - float(_win[0][0]) > 5.0:
		_win.remove_at(0)
	var s := 0.0
	for x in _win:
		s += float(x[1])
	dps = s / 5.0
	best_dps = maxf(best_dps, dps)
	if Engine.get_physics_frames() % 6 == 0:
		_update_panel()


# ---------------------------------------------------------------- Anzeige
func _hud_root() -> Control:
	return G.main.hud.root if G.main != null and G.main.hud != null else null


## Die Zeilen für Welle und Bunker gehören zur Flut – auf dem Übungsplatz ausblenden.
func _hide_flood_rows() -> void:
	var hud = G.main.hud if G.main != null else null
	if hud == null:
		return
	for nm in ["_wave_label", "_bunker_bar"]:
		var c = hud.get(nm)
		if c != null and is_instance_valid(c) and c.get_parent() != null:
			c.get_parent().visible = false


func weapons() -> Array:
	var out: Array = []
	for wk in D.WEAPONS:
		if String(D.WEAPONS[wk].hero) == String(hero.key):
			out.append(wk)
	return out


func owned_weapon(wk: String) -> Dictionary:
	for it in P.d.items:
		if String(it.slot) == "weapon" and String(it.key) == wk:
			return it
	return {}


## Waffe zum Testen in die Hand (eigene, sonst eine Probewaffe Stufe 1 ohne Module).
func try_weapon(wk: String) -> void:
	var it := owned_weapon(wk)
	if it.is_empty():
		it = {"key": wk, "rarity": 0, "level": 1, "mods": []}
	hero.set_weapon(it)
	trial = wk
	reset_meter()
	Sfx.play("ui_equip", -6.0)
	_panel_sig = ""


func reset_meter() -> void:
	total = 0.0
	hits = 0
	dps = 0.0
	best_dps = 0.0
	_win.clear()


func _make_panel() -> void:
	var root := _hud_root()
	if root == null:
		return
	var v := UI.vbox(6)
	v.add_child(UI.hbox(10, [UI.pic("p_dummy", 44.0, "ui_target"), UI.label("Übungsplatz", 26, UI.GOLD)]))
	_dps_l = UI.label("", 24)
	_best_l = UI.label("", 20, UI.TEXT, false)
	_tot_l = UI.label("", 20, UI.TEXT, false)
	_hit_l = UI.label("", 20, UI.TEXT, false)
	v.add_child(_dps_l)
	v.add_child(_best_l)
	v.add_child(_tot_l)
	v.add_child(_hit_l)
	var list := UI.vbox(4)
	list.name = "Waffen"
	v.add_child(UI.label("Waffe wählen", 21, UI.SKY))
	v.add_child(list)
	var rb := UI.button("Zurücksetzen", func(): reset_meter(), "dark", 20, "ui_recycle")
	var eb := UI.button("Beenden", func(): _finish(false), "red", 20, "ui_close")
	v.add_child(UI.hbox(8, [rb, eb]))
	var p := UI.panel(v, UI.NAVY, UI.EDGE, 16, 12)
	p.custom_minimum_size = Vector2(330, 0)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(350, 560)
	sc.add_child(p)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top", 110)
	sc.size_flags_horizontal = Control.SIZE_SHRINK_END
	sc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	m.add_child(sc)
	root.add_child(m)
	_panel = m
	_update_panel()


func _update_panel() -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	_dps_l.text = "Schaden pro Sekunde: %d" % int(round(dps))
	_best_l.text = "Bester Wert: %d" % int(round(best_dps))
	_tot_l.text = "Gesamtschaden: %s" % UI.fmt(int(total))
	_hit_l.text = "Treffer: %d" % hits
	var sig := trial
	if sig == _panel_sig:
		return
	_panel_sig = sig
	var list: VBoxContainer = _panel.find_child("Waffen", true, false)
	if list == null:
		return
	UI.clear(list)
	for wk in weapons():
		var owned := not owned_weapon(wk).is_empty()
		var nm := String(D.WEAPONS[wk].name) + ("" if owned else " (Probe)")
		var b := UI.button(nm, func(): try_weapon(wk), "gold" if wk == trial else "dark", 18, "")
		b.custom_minimum_size = Vector2(300, 44)
		list.add_child(b)


# ---------------------------------------------------------------- wie die Flut (für hud.gd)
func enemies_left() -> int:
	return dummies.size()


func skip_break() -> void:
	pass


func back_to_peace() -> void:
	G.main.goto_base()


func can_respawn() -> bool:
	return true


func respawn_point() -> Vector2:
	return Vector2(0, 3)


## Übung beenden: zurück in die Basis (kein Ergebnisfenster).
func _finish(_win_: bool = false) -> void:
	if ended:
		return
	ended = true
	running = false
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	hero.refresh_stats()                 # eigene Waffe wieder in die Hand
	G.main.goto_base.call_deferred()


func leave() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	super.leave()
