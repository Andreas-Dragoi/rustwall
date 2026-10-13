extends Control
## Spielerführung im HUD (Paket F): Tutorial-Tafel mit Zeigefinger und Hervorhebung, Ziele-Leiste (GoalBox),
## Rückkehr-Zusammenfassung, Bildrate im Akku-Sparmodus, Vibration bei Bau/Kiste/Stufe, Pause, wenn die App
## in den Hintergrund geht, gespeicherter Gebäudeschaden. Liegt als durchsichtige Ebene über dem HUD (hud.root).

const D = preload("res://src/data.gd")
const DF = preload("res://src/data_fuehrung.gd")
const UI = preload("res://src/ui.gd")
const Guide = preload("res://src/guide.gd")
const ScreenFit = preload("res://src/screen_fit.gd")

const GLASS := Color(0.07, 0.19, 0.37, 0.94)
## Menü im kompakten Modus (kleine Handys): [Name, Bildschirm, nötiges Gebäude] – wie die rechte Spalte in hud.gd
const MENU := [["Helden", "heroes", "quartier"], ["Kisten", "chests", "kistenlager"], ["Aufträge", "quests", ""], ["Werkstatt", "workshop", "werkstatt"], ["Forschung", "forschung", ""],
	["Garage", "garage", "garage"], ["Begleiter", "begleiter", ""], ["Funk", "social", "funkturm"], ["Clan", "clan", "clanhalle"],
	["Hilfe", "hilfe", ""], ["Optionen", "settings", ""], ["Saison", "saison", ""], ["Garderobe", "garderobe", ""],
	["Chronik", "chronik", ""], ["Modi", "modi", ""]]

var hud: CanvasLayer
var _tut: PanelContainer
var _tut_sig := ""
var _finger: TextureRect
var _ring: Panel
var _t := 0.0
var _slow := 0.0
var _chests := -1
var _return_checked := false
var _aim := Rect2()              # Ziel des Fingers in eigenen Koordinaten (leer = kein Finger)
var _aim_down := false
var _ring_on := false


func _init(h: CanvasLayer) -> void:
	hud = h
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finger = TextureRect.new()
	_finger.texture = UI.tex("ui_finger")
	_finger.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_finger.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_finger.size = Vector2(104, 104)
	_finger.pivot_offset = Vector2(52, 52)
	_finger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finger.visible = false
	add_child(_finger)
	_ring = Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1, 0.85, 0.2, 0.08)
	st.border_color = UI.GOLD
	st.set_border_width_all(5)
	st.set_corner_radius_all(18)
	st.shadow_color = Color(1, 0.8, 0.1, 0.45)
	st.shadow_size = 14
	_ring.add_theme_stylebox_override("panel", st)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.visible = false
	add_child(_ring)


func _ready() -> void:
	P.building_done.connect(_on_built)
	P.level_up.connect(func(_l: int): G.vibrate(int(DF.VIBRATE.level)))
	P.hero_level_up.connect(func(_k: String, _l: int): G.vibrate(int(DF.VIBRATE.hero_level)))
	get_viewport().size_changed.connect(fit_root)
	fit_root.call_deferred()


## HUD in den sicheren Bereich legen und auf kleinen Handys vergrößern.
func fit_root() -> void:
	if hud != null and hud.root != null:
		ScreenFit.fit(hud.root, ScreenFit.hud_scale())


func _on_built(id: int) -> void:
	var b: Dictionary = P.get_building(id)
	if not b.is_empty() and String(b.key) != "wall":
		G.vibrate(int(DF.VIBRATE.build))


## Kompakte Anzeige (HUD vergrößert, also kleiner Bildschirm oder große Schrift gewählt)?
static func compact() -> bool:
	return ScreenFit.hud_scale() > 1.05


## Rechte Menüspalte im kompakten Modus: nur „Menü“ (öffnet ein Raster mit großen Knöpfen) und „Kisten“.
static func compact_menu(h: CanvasLayer, col: VBoxContainer) -> void:
	for c in col.get_children():
		(c as Control).visible = c == h._chest_btn
	var mb := UI.button("Menü", func(): _open_menu(h), "dark", 27, "ui_grid")
	mb.custom_minimum_size = Vector2(236, 76)
	mb.set_meta("guide", "menu")
	col.add_child(mb)
	col.move_child(mb, 0)


static func _open_menu(h: CanvasLayer) -> void:
	var g := UI.grid(3, 12)
	for e in MENU:
		var b: Button = h._menu_btn(String(e[0]), String(e[1]), String(e[2]))
		b.custom_minimum_size = Vector2(300, 92)
		b.pressed.connect(h._close_modal)
		g.add_child(b)
	var close := UI.button("Schließen", h._close_modal, "red", 28, "ui_close")
	close.custom_minimum_size = Vector2(300, 84)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var t := UI.label("Menü", 44, UI.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h._show_modal(UI.vbox(18, [t, g, close]), 0.5)


## Tutorial sichtbar? In Tests nur mit --tut=1.
static func tut_visible() -> bool:
	if Guide.tut_key() == "":
		return false
	return not Guide.quiet()


func _process(dt: float) -> void:
	_t += dt
	_slow -= dt
	if _slow <= 0.0:
		_slow = 0.25
		_update()
	# Finger wippt zum Ziel hin, Ring pulsiert
	if _finger.visible:
		var bob := (sin(_t * 6.0) * 0.5 + 0.5) * 16.0
		var sway := sin(_t * 2.5) * 70.0 if _aim.size.x < 4.0 else 0.0      # Laufen: Finger wischt hin und her
		if _aim_down:
			_finger.rotation = PI
			_finger.position = Vector2(_aim.get_center().x - 52.0 + 10.0 + sway, _aim.position.y - 108.0 - bob)
		else:
			_finger.rotation = 0.0
			_finger.position = Vector2(_aim.get_center().x - 52.0 + 10.0 + sway, _aim.end.y + 4.0 + bob)
	if _ring.visible:
		_ring.modulate.a = 0.55 + 0.45 * sin(_t * 5.0)


func _update() -> void:
	var f := ScreenFit.fps_target()
	if Engine.max_fps != f:
		Engine.max_fps = f
	var ch := int(P.d.stats.get("chests", 0)) if not P.d.is_empty() else 0
	if _chests >= 0 and ch > _chests:
		G.vibrate(int(DF.VIBRATE.chest))
	_chests = ch
	var world: Node3D = hud.world
	if world == null or not is_instance_valid(world):
		_hide_tut()
		return
	if world.mode == "peace" and world.get("nodes") != null and int(_t * 4.0) % 4 == 0:
		Guide.store_damage(world)
	var blocked: bool = G.main == null or G.main.screens.is_open() or hud.modal_open() or (G.main.menu != null and G.main.menu.visible)
	if tut_visible():
		Guide.tut_check(world)
	if not blocked and world.mode == "peace" and not _return_checked and hud._peace != null:
		_return_checked = true
		var rep := Guide.away_report()
		if not rep.is_empty() and G.autotest == "" and not G.selftest:
			_show_return(rep)
			return
	if blocked or not tut_visible() or (world.mode != "peace" and Guide.tut_key() != "expedition"):
		_hide_tut()
		return
	_show_tut(world)


# ================================================================= Tutorial
func _hide_tut() -> void:
	if _tut != null:
		_tut.queue_free()
		_tut = null
		_tut_sig = ""
	_finger.visible = false
	_ring.visible = false


func _show_tut(world: Node3D) -> void:
	var def: Dictionary = Guide.tut_def()
	if def.is_empty() or world.mode != "peace":
		_hide_tut()
		return
	var txt := String(def.text)
	if def.has("touch") and G.is_touch:
		txt = String(def.touch)
	elif def.has("pc") and not G.is_touch:
		txt = String(def.pc)
	if String(def.key) == "bauen" and world.editing():
		txt = "Tippe auf ein freies Feld und dann auf „Hier bauen“." if G.is_touch else "Klicke auf ein freies Feld, um das Sägewerk zu setzen."
	var sig := "%d|%s" % [Guide.tut_step(), txt]
	if sig != _tut_sig:
		_tut_sig = sig
		if _tut != null:
			_tut.queue_free()
		var n := DF.TUT_STEPS.size()
		var head := UI.label("Tutorial %d/%d · %s" % [Guide.tut_step() + 1, n, String(def.title)], 25, UI.GOLD)
		var body := UI.text(txt, 23, UI.WHITE, 560.0)
		var skip := UI.button("Überspringen", func():
			Guide.tut_next(true)
			_tut_sig = "", "dark", 21)
		skip.custom_minimum_size = Vector2(0, 58)
		var stop := UI.button("Tutorial beenden", func():
			Guide.tut_skip_all()
			_hide_tut(), "dark", 18)
		stop.custom_minimum_size = Vector2(0, 50)
		stop.modulate.a = 0.85
		var row: BoxContainer
		if compact():
			body.custom_minimum_size.x = 400.0
			head.add_theme_font_size_override("font_size", 23)
			var br := UI.hbox(8, [skip, stop])
			row = UI.hbox(12, [UI.pic(String(def.icon), 52.0), UI.vbox(4, [head, body, br])])
		else:
			var btns := UI.vbox(6, [skip, stop])
			btns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row = UI.hbox(14, [UI.pic(String(def.icon), 60.0), UI.vbox(2, [head, body]), btns])
		_tut = UI.panel(row, GLASS, UI.GOLD, 22, 12)
		_tut.position.y = 180.0
		add_child(_tut)
		move_child(_tut, 0)
		UI.pop_in(_tut, 0.9, 0.2)
	# kompakt (Handy): rechts unter „Menü“, damit der Held in der Mitte frei bleibt; sonst mittig neben der linken Spalte
	if compact():
		_tut.position = Vector2(size.x - _tut.size.x - 24.0, 196.0)
		_point(world, String(def.target))
		return
	var x := (size.x - _tut.size.x) * 0.5
	if hud._goal != null and is_instance_valid(hud._goal) and hud._goal.is_visible_in_tree():
		var edge: float = (get_global_transform().affine_inverse() * hud._goal.get_global_rect().end).x + 14.0
		x = maxf(x, edge)
	_tut.position.x = minf(x, size.x - _tut.size.x - 8.0)
	_point(world, String(def.target))


## Finger und Ring auf ein Ziel legen.
func _point(world: Node3D, target: String) -> void:
	var r := Rect2()
	var ring := true
	match target:
		"stick":
			if G.is_touch:
				r = Rect2(Vector2(size.x * 0.33, size.y * 0.6), Vector2(2, 2))
				ring = false
		"bubble":
			var bk = world.bunker_node
			if bk != null and bk.gift != null and bk.gift.visible:
				var sp: Vector2 = bk.gift.screen_pos(world.cam.cam)
				var lp: Vector2 = get_global_transform().affine_inverse() * sp
				r = Rect2(lp - Vector2(50, 50), Vector2(100, 100))
		"bauen":
			if world.editing():
				r = _rect_of("confirm") if G.is_touch else Rect2()
			elif hud._build_box != null:
				r = _rect_of("build_saege")
				if r.size == Vector2.ZERO:
					r = _rect_of("tab_prod")
			else:
				r = _rect_of("bauen")
		_:
			r = _rect_of(target)
	_aim = r
	_finger.visible = r.size != Vector2.ZERO
	_aim_down = r.get_center().y > size.y * 0.55
	_ring.visible = _finger.visible and ring
	if _ring.visible:
		_ring.position = r.position - Vector2(8, 8)
		_ring.size = r.size + Vector2(16, 16)


func _rect_of(key: String) -> Rect2:
	var c := _find(hud.root, key)
	if c == null:
		return Rect2()
	var g := c.get_global_rect()
	var inv := get_global_transform().affine_inverse()
	var a: Vector2 = inv * g.position
	var b: Vector2 = inv * g.end
	return Rect2(a, b - a)


func _find(n: Node, key: String) -> Control:
	if n is Control:
		if not (n as Control).visible:
			return null
		if String(n.get_meta("guide", "")) == key:
			return n
	for c in n.get_children():
		if c == self:
			continue
		var f := _find(c, key)
		if f != null:
			return f
	return null


# ================================================================= Rückkehr-Zusammenfassung
func _show_return(rep: Dictionary) -> void:
	var gift := int(rep.get("gift", 0))
	if gift > 0:
		P.add_pickup("return", "bunker", {"gems": gift}, "Rückkehr-Geschenk: %d Juwelen" % gift)
	var v := UI.vbox(12)
	v.custom_minimum_size = Vector2(760, 0)
	var t := UI.label("Willkommen zurück!", 48, UI.GOLD)
	t.add_theme_constant_override("outline_size", 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var days := float(rep.days)
	var dtxt := "%d Tage" % int(floor(days)) if days < 14.0 else "über zwei Wochen"
	var sub := UI.label("Während du weg warst (%s) …" % dtxt, 26, UI.TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var lines := UI.vbox(8)
	for l in rep.lines:
		lines.add_child(UI.hbox(12, [UI.pic(String(l[0]), 40.0), UI.text(String(l[1]), 23, UI.WHITE, 600.0)]))
	if gift > 0:
		lines.add_child(UI.hbox(12, [UI.pic("res_gems", 40.0), UI.text("Rückkehr-Geschenk: %d Juwelen liegen am Bunker." % gift, 23, Color("9FDCFF"), 600.0)]))
	if (rep.lines as Array).is_empty() and gift <= 0:
		lines.add_child(UI.label("Alles ruhig. Deine Basis hat auf dich gewartet.", 23, UI.TEXT))
	v.add_child(UI.card(lines, UI.NAVY_L, 16))
	var all := UI.button("Alles abholen", func():
		hud._close_modal()
		if hud.world != null and hud.world.mode == "peace":
			hud.world.collect_all()
			UI.sfx("ui_claim", "", -6.0), "gold", 30, "ui_crate")
	all.custom_minimum_size = Vector2(320, 88)
	var ok := UI.button("Weiter", hud._close_modal, "green", 30, "ui_check")
	ok.custom_minimum_size = Vector2(260, 88)
	var row := UI.hbox(18, [all, ok])
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	Sfx.play("return_summary", -4.0)
	hud._show_modal(v, 0.5, UI.GOLD)


# ================================================================= App im Hintergrund: Kampf pausieren
func _notification(what: int) -> void:
	var bg := what == NOTIFICATION_APPLICATION_PAUSED
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and (OS.has_feature("mobile") or G.web_mobile()):
		bg = true
	if bg:
		pause_battle()


## Öffnet das Pausenmenü einer laufenden Flut, Übung oder Expedition (nicht in Tests).
func pause_battle() -> bool:
	var w: Node3D = hud.world
	if w == null or not is_instance_valid(w) or w.mode == "peace" or w.ended or get_tree().paused:
		return false
	if G.main == null or G.main.screens.is_open() or hud.modal_open():
		return false
	hud._on_pause()
	return get_tree().paused


# ================================================================= Ziele-Leiste
## Immer sichtbares nächstes Ziel mit Belohnung (links unter den laufenden Bauten).
class GoalBox extends PanelContainer:
	const UIx = preload("res://src/ui.gd")
	const Gd = preload("res://src/guide.gd")
	var _sig := ""
	var _txt: Label
	var _bar: ProgressBar
	var _num: Label
	var _rw: Label
	var _btn: Button
	var _t := 0.0
	var _story: Control              # V6 Paket E: zweite Zeile „Geschichte“ (story_goal_row.gd)

	func _init() -> void:
		add_theme_stylebox_override("panel", UIx.panel_style(Color(0.07, 0.19, 0.37, 0.94), UIx.GOLD, 20, 10))
		set_meta("guide", "goal")
		_txt = UIx.label("", 22)
		_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_txt.custom_minimum_size = Vector2(300, 0)
		_bar = UIx.bar(0.0, UIx.GOLD, Vector2(200, 12))
		_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_num = UIx.label("", 19, UIx.GOLD)
		_rw = UIx.label("", 18, UIx.TEXT, false)
		_rw.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_rw.custom_minimum_size = Vector2(300, 0)
		_btn = UIx.button("Abholen", _claim, "green", 22, "ui_check")
		_btn.custom_minimum_size = Vector2(0, 60)
		_btn.visible = false
		var head := UIx.hbox(8, [UIx.label("Nächstes Ziel", 18, UIx.SKY), UIx.spacer(true), _num])
		var col := UIx.vbox(3, [head, _txt, _bar, _rw, _btn])
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_story = load("res://src/story_goal_row.gd").new()
		col.add_child(_story)
		add_child(UIx.hbox(10, [UIx.pic("ui_target", 46.0, "", UIx.GOLD), col]))
		custom_minimum_size = Vector2(420, 0)
		update()

	func update() -> void:
		if _story != null:
			_story.update()
		var g: Dictionary = Gd.goal()
		var pr: Array = Gd.goal_progress(g)
		var ready: bool = int(pr[0]) >= int(pr[1])
		var sig := "%d|%d|%d" % [int(P.d.goals.idx), int(pr[0]), 1 if ready else 0]
		if sig == _sig:
			if ready:
				_t += 0.25
				_btn.modulate = Color(1, 1, 1).lerp(Color(1.3, 1.3, 1.0), 0.5 + 0.5 * sin(_t * 6.0))
			return
		_sig = sig
		_txt.text = Gd.goal_text(g)
		_bar.value = float(pr[0]) / maxf(1.0, float(pr[1]))
		_num.text = "%s / %s" % [UIx.fmt(int(pr[0])), UIx.fmt(int(pr[1]))]
		_rw.text = "Belohnung: " + Gd.reward_text(g.reward)
		_btn.visible = ready
		_bar.visible = not ready
		if ready:
			UIx.pulse(self, 1.05)

	func _claim() -> void:
		var rw: Dictionary = Gd.goal_claim()
		if rw.is_empty():
			return
		P.toast.emit("Ziel geschafft! " + Gd.reward_text(rw))
		UIx.sfx("ui_claim", "", -4.0)
		if G.hud != null:
			for r in rw:
				if r != "chest" and D_has(r):
					G.hud.fly_icons("res_" + String(r), get_global_rect().get_center(), String(r), 8)
		_sig = ""
		update()

	func D_has(r: String) -> bool:
		return preload("res://src/data.gd").RES.has(r)
