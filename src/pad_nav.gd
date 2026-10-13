extends Node
## Paket Q: Gamepad in Menüs und in der Basis (Kind von G, läuft immer).
##  - Sobald das Gamepad benutzt wird, bekommen alle Knöpfe des obersten offenen Menüs (Vollbild-Menü, Dialog,
##    Hauptmenü, Auswahlfenster eines Gebäudes, Baumenü) Fokus; Steuerkreuz/linker Stick bewegen ihn, A drückt,
##    B schließt. Ein goldener Rahmen zeigt den Fokus (das Spiel selbst zeichnet keinen).
##  - Basis: Select wählt das nächste Gebäude am Helden, im Bau-/Verschiebemodus folgt das Baufeld der Bildmitte
##    (linker Stick schiebt die Kamera), A setzt, B bricht ab, Y dreht.
##  - Maus, Tastatur oder Berührung schalten zurück: Fokus und Rahmen verschwinden wieder.

var active := false                # zuletzt wurde das Gamepad benutzt
var _layer: CanvasLayer
var _frame: Panel
var _touched: Array = []           # Knöpfe, deren focus_mode wir geändert haben (weakref)
var _root_id := 0
var _scan_t := 0.0
var _last_focus: Control = null
var hud_nav := false              # Select ohne Gebäude in der Nähe: Knöpfe des HUD (Bauen, Menüs) bedienen


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 120
	add_child(_layer)
	_frame = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.82, 0.24, 0.10)
	sb.border_color = Color("FFD23E")
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	_frame.add_theme_stylebox_override("panel", sb)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.visible = false
	_layer.add_child(_frame)


func _input(e: InputEvent) -> void:
	if e is InputEventJoypadButton or (e is InputEventJoypadMotion and absf(e.axis_value) > 0.5):
		if not active:
			active = true
			_root_id = 0
	elif active and (e is InputEventMouseButton or e is InputEventScreenTouch or (e is InputEventMouseMotion and e.relative.length() > 6.0) or e is InputEventKey):
		set_active(false)
		return
	if not active:
		return
	var w = G.main.world if G.main != null else null
	# Basis: Bau-/Verschiebemodus mit dem Gamepad
	if w != null and is_instance_valid(w) and String(w.mode) == "peace" and w.has_method("editing") and w.editing() and not G.main.ui_blocked():
		if e is InputEventJoypadButton and e.pressed:
			match e.button_index:
				JOY_BUTTON_A:
					w.confirm_edit()
					get_viewport().set_input_as_handled()
				JOY_BUTTON_B:
					w.cancel_edit()
					get_viewport().set_input_as_handled()
				JOY_BUTTON_Y:
					w.rotate_ghost()
					get_viewport().set_input_as_handled()
		return
	var root := nav_root()
	if root != null and e is InputEventJoypadButton and e.pressed:
		# in Menüs gehören A/B/X/Y den Menüs, nicht dem Helden
		if e.button_index == JOY_BUTTON_B:
			get_viewport().set_input_as_handled()
			_back()
		elif e.button_index in [JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			get_viewport().set_input_as_handled()
		elif e.button_index == JOY_BUTTON_A:
			# A drückt den fokussierten Knopf (ui_accept), Ausweichen soll dabei nicht auslösen
			var f := get_viewport().gui_get_focus_owner()
			if f is BaseButton and f.is_visible_in_tree() and not f.disabled:
				get_viewport().set_input_as_handled()
				f.pressed.emit()
				if f.toggle_mode:
					f.button_pressed = not f.button_pressed
		return
	# Basis ohne offenes Menü: Select wählt das Gebäude am Helden
	if e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_BACK and w != null and is_instance_valid(w) and String(w.mode) == "peace":
		get_viewport().set_input_as_handled()
		select_near()


func set_active(on: bool) -> void:
	active = on
	if not on:
		hud_nav = false
		_release()


## Wählt das Gebäude, das dem Helden am nächsten liegt (höchstens 9 m), und öffnet sein Auswahlfenster.
func select_near() -> bool:
	var w = G.main.world
	if w == null or w.hero == null or not ("nodes" in w):
		return false
	var hp: Vector2 = w.hero.pos2()
	var best := -1
	var bd := 81.0
	for id in w.nodes:
		var s = w.nodes[id]
		if s == null or not is_instance_valid(s) or s.b.is_empty():
			continue
		var d := Vector2(s.global_position.x, s.global_position.z).distance_squared_to(hp)
		if d < bd:
			bd = d
			best = int(id)
	if best >= 0:
		w.select(best)
		Sfx.play("ui_select", -8.0)
		return true
	hud_nav = true                      # nichts in der Nähe: HUD-Knöpfe bedienen
	Sfx.play("ui_select", -8.0)
	return false


## Oberstes offenes Menü, das mit dem Gamepad bedient wird (oder null im Spiel).
func nav_root() -> Control:
	if G.main == null:
		return null
	var hud = G.hud
	var sc = G.main.screens
	if sc != null and sc.is_open() and sc._root != null and is_instance_valid(sc._root) and sc._root.is_visible_in_tree():
		var ov = sc.get("_overlay")              # Rückfrage im Menü
		if ov is Control and is_instance_valid(ov):
			return ov
		return sc._root
	if hud != null and is_instance_valid(hud) and hud.modal_open() and is_instance_valid(hud._modal) and hud._modal.is_visible_in_tree():
		return hud._modal
	var mm = G.main.menu
	if mm != null and mm.visible:
		for c in mm.get_children():
			if c is Control and c.visible:
				return c
	var w = G.main.world
	if hud != null and is_instance_valid(hud) and w != null and is_instance_valid(w) and String(w.mode) == "peace":
		# Auswahlfenster eines Gebäudes bzw. Baumenü (Teile des HUD)
		var sel = hud.get("_sel_box")
		if sel is Control and is_instance_valid(sel) and sel.is_visible_in_tree():
			return sel
		var bb = hud.get("_build_box")
		if bb is Control and is_instance_valid(bb) and bb.is_visible_in_tree():
			return bb
		if hud_nav and hud.get("root") is Control:
			return hud.root
	return null


func _back() -> void:
	var hud = G.hud
	if hud_nav and not hud.modal_open() and not G.main.screens.is_open():
		hud_nav = false
		_release()
		return
	if hud != null and hud.modal_open():
		hud._close_modal()
		return
	if G.main.screens.is_open():
		G.main.screens.close()
		return
	var w = G.main.world
	if w != null and String(w.mode) == "peace":
		if hud.get("_build_box") != null and is_instance_valid(hud._build_box):
			hud._close_build()
		elif int(w.selected_id) >= 0:
			w.select(-1)


func _process(dt: float) -> void:
	if not active:
		return
	var w = G.main.world if G.main != null else null
	# Bau-/Verschiebemodus: Baufeld folgt der Bildmitte
	if w != null and is_instance_valid(w) and String(w.mode) == "peace" and w.has_method("editing") and w.editing():
		var c = w.cam.ground_at(get_viewport().get_visible_rect().size * 0.5)
		if c != null:
			var cell: Vector2i = w.world_to_cell(Vector2(c.x, c.z))
			if cell != w.ghost_cell:
				w.set_ghost(cell)
		_frame.visible = false
		return
	var root := nav_root()
	if root == null:
		_release()
		return
	_scan_t -= dt
	if root.get_instance_id() != _root_id or _scan_t <= 0.0:
		_scan_t = 0.4
		_prepare(root, root.get_instance_id() != _root_id)
		_root_id = root.get_instance_id()
	var f := get_viewport().gui_get_focus_owner()
	if f == null or not f.is_visible_in_tree() or not root.is_ancestor_of(f):
		var first := _first_button(root)
		if first != null:
			first.grab_focus()
			f = first
	_draw_frame(f)


## Alle sichtbaren Knöpfe im Menü fokussierbar machen, Rollbereiche folgen dem Fokus.
func _prepare(root: Control, fresh: bool) -> void:
	for c in _all(root):
		if c is BaseButton or c is Slider:
			if c.focus_mode == Control.FOCUS_NONE:
				c.focus_mode = Control.FOCUS_ALL
				_touched.append(weakref(c))
		elif c is ScrollContainer:
			c.follow_focus = true
	if fresh:
		var f := get_viewport().gui_get_focus_owner()
		if f != null and not root.is_ancestor_of(f):
			f.release_focus()


func _first_button(root: Control) -> Control:
	var best: Control = null
	var bp := Vector2(1e9, 1e9)
	for c in _all(root):
		if (c is BaseButton or c is Slider) and c.is_visible_in_tree() and c.focus_mode != Control.FOCUS_NONE and not (c is BaseButton and c.disabled):
			var p: Vector2 = c.get_global_transform_with_canvas().origin
			if p.y < bp.y - 4.0 or (absf(p.y - bp.y) <= 4.0 and p.x < bp.x):
				bp = p
				best = c
	return best


func _all(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Control:
			if not c.visible:
				continue
			out.append(c)
		out.append_array(_all(c))
	return out


func _draw_frame(f: Control) -> void:
	if f == null or not f.is_visible_in_tree():
		_frame.visible = false
		return
	var xf := f.get_global_transform_with_canvas()
	var sz := f.size * xf.get_scale()
	_frame.visible = true
	_frame.position = xf.origin - Vector2(6, 6)
	_frame.size = sz + Vector2(12, 12)
	if f != _last_focus:
		_last_focus = f
		Sfx.play("ui_hover", -14.0)


func _release() -> void:
	_frame.visible = false
	_root_id = 0
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if f != null and not (f is LineEdit):
		f.release_focus()
	for r in _touched:
		var c = r.get_ref()
		if c != null and is_instance_valid(c):
			c.focus_mode = Control.FOCUS_NONE
	_touched.clear()
	_last_focus = null
