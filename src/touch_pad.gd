extends Control
## Steuerung auf dem Bildschirm: schwebender Stick links (Touch), Fähigkeiten-Knöpfe mit
## Abklingzeit rechts unten (Touch) bzw. als Leiste unten in der Mitte (PC, mit Tastenhinweis).
## Zwei-Finger-Zoom auf freier Fläche. Mehrere Finger gleichzeitig werden unterstützt.

const D = preload("res://src/data.gd")
const UI = preload("res://src/ui.gd")

const JOY_R := 120.0
const DEAD := 0.12
const KEYS := ["Q", "E", "R", "F", "Leer", "T"]

var _joy_idx := -1
var _joy_origin := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _free := {}
var _pinch_d := 0.0
var _btns: Array = []        # {c, r, slot}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _sz() -> Vector2:
	return get_viewport_rect().size


func reset() -> void:
	_joy_idx = -1
	_free.clear()
	G.touch_move = Vector2.ZERO


func _battle() -> bool:
	return G.game != null and G.game.mode != "peace" and G.player != null and not G.game.ended


## Knöpfe: 0..3 Fähigkeiten, 4 Ausweichen, 5 Fahrzeug
func _layout() -> void:
	_btns.clear()
	if not _battle():
		return
	var s := _sz()
	var has_veh: bool = G.player.veh_node != null
	if G.is_touch:
		var base := Vector2(s.x - 150.0, s.y - 150.0)
		_btns.append({"c": base, "r": 84.0, "slot": 2})
		_btns.append({"c": base + Vector2(-190, 30), "r": 66.0, "slot": 0})
		_btns.append({"c": base + Vector2(-130, -150), "r": 66.0, "slot": 1})
		_btns.append({"c": base + Vector2(30, -200), "r": 60.0, "slot": 3})
		_btns.append({"c": base + Vector2(-340, 60), "r": 56.0, "slot": 4})
		if has_veh:
			_btns.append({"c": base + Vector2(-300, -110), "r": 52.0, "slot": 5})
	else:
		var n := 6 if has_veh else 5
		var x0 := s.x * 0.5 - (n - 1) * 55.0
		for i in n:
			_btns.append({"c": Vector2(x0 + i * 110.0, s.y - 70.0), "r": 46.0, "slot": i})


func over_button(p: Vector2) -> bool:
	for b in _btns:
		if p.distance_to(b.c) < b.r * 1.1:
			return true
	return false


func _press(slot: int) -> void:
	if slot < 4:
		G.skill_pressed.emit(slot)
	elif slot == 4:
		G.dodge_pressed.emit()
	else:
		G.use_pressed.emit()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or G.main == null or G.main.ui_blocked() or get_tree().paused:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not G.is_touch:
		for b in _btns:
			if event.position.distance_to(b.c) < b.r:
				_press(b.slot)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			for b in _btns:
				if p.distance_to(b.c) < b.r * 1.15:
					_press(b.slot)
					return
			# zweiter Finger kurz nach dem ersten, Stick kaum bewegt: Zwei-Finger-Zoom statt Laufen
			if _joy_idx != -1 and _free.is_empty() and _joy_pos.distance_to(_joy_origin) < 24.0:
				_free[_joy_idx] = _joy_pos
				_joy_idx = -1
				G.touch_move = Vector2.ZERO
				_free[event.index] = p
				_pinch_d = 0.0
				return
			if p.x < _sz().x * 0.45 and p.y > 200.0 and _joy_idx == -1 and not G.main.touch_on_ui(p):
				_joy_idx = event.index
				_joy_origin = p
				_joy_pos = p
			elif p.y > 150.0:
				_free[event.index] = p
				_pinch_d = 0.0
		else:
			if event.index == _joy_idx:
				_joy_idx = -1
				G.touch_move = Vector2.ZERO
			_free.erase(event.index)
			_pinch_d = 0.0
	elif event is InputEventScreenDrag:
		if event.index == _joy_idx:
			_joy_pos = event.position
			var d := _joy_pos - _joy_origin
			if d.length() > JOY_R:
				_joy_origin = _joy_pos - d.normalized() * JOY_R
				d = _joy_pos - _joy_origin
			var v := d / JOY_R
			var l := v.length()
			G.touch_move = Vector2.ZERO if l < DEAD else v / l * ((l - DEAD) / (1.0 - DEAD))
		elif _free.has(event.index):
			_free[event.index] = event.position
			if _free.size() == 2:
				var k := _free.keys()
				var dist: float = _free[k[0]].distance_to(_free[k[1]])
				if _pinch_d > 0.0 and G.cam:
					G.cam.zoom((_pinch_d - dist) * 0.06)
				_pinch_d = dist


func _process(_dt: float) -> void:
	_layout()
	queue_redraw()


func _draw() -> void:
	if G.main == null or G.main.ui_blocked():
		return
	var font := UI.font(true)
	if G.is_touch and G.game != null and not G.game.ended:
		if _joy_idx != -1:
			draw_circle(_joy_origin, JOY_R + 14.0, Color(0.05, 0.14, 0.32, 0.4))
			draw_arc(_joy_origin, JOY_R + 14.0, 0, TAU, 48, Color(0.29, 0.69, 1.0, 0.85), 5.0, true)
			draw_arc(_joy_origin, JOY_R + 6.0, 0, TAU, 48, Color(1, 1, 1, 0.12), 3.0, true)
			_gloss(_joy_pos, 54.0, Color("2F8DEB"))
		else:
			var hp := Vector2(240.0, _sz().y - 250.0)
			draw_arc(hp, JOY_R, 0, TAU, 48, Color(1, 1, 1, 0.22), 5.0, true)
			draw_circle(hp, 44.0, Color(1, 1, 1, 0.14))
	if _btns.is_empty():
		return
	var pl = G.player
	var hcol: Color = D.HEROES[pl.key].color
	for b in _btns:
		var slot: int = b.slot
		var ratio := 1.0
		var locked := false
		var text := ""
		var col := hcol
		if slot < 4:
			var s: Dictionary = pl.skills.slots[slot]
			ratio = pl.skills.ratio(slot)
			locked = s.locked
			text = s.name
			if slot == 2:
				col = UI.GOLD.darkened(0.1)
			elif slot == 3:
				col = UI.PURPLE
		elif slot == 4:
			ratio = pl.dodge_ratio()
			text = "Ausweichen"
			col = Color("3FAE2A")
		else:
			text = "Absteigen" if pl.mounted else "Aufsteigen"
			col = Color("7C879C")
		var c: Vector2 = b.c
		var r: float = b.r
		if locked:
			_gloss(c, r, Color("3A5788"), 0.35)
		elif ratio >= 1.0:
			_gloss(c, r, col)
			draw_arc(c, r + 4.0, 0, TAU, 48, Color(1, 1, 1, 0.55 + 0.25 * sin(Time.get_ticks_msec() * 0.006 + slot)), 3.0, true)
		else:
			_gloss(c, r, col.darkened(0.55), 0.4)
			draw_arc(c, (r - 5.0) * 0.5, -PI * 0.5, -PI * 0.5 + TAU * ratio, 40, Color(col, 0.9), r - 5.0, true)
			draw_arc(c, r - 2.0, 0, TAU, 48, col.lightened(0.3), 3.0, true)
		var fs := int(clampf(r * 0.3, 15.0, 24.0))
		var words := text.split(" ")
		var line := words[0] if words[0].length() <= 11 else words[0].substr(0, 10) + "."
		var w := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(font, c + Vector2(-w * 0.5, fs * 0.35), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, UI.OUTLINE)
		draw_string(font, c + Vector2(-w * 0.5, fs * 0.35), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE if not locked else Color(1, 1, 1, 0.4))
		if slot < 4 and not locked and ratio < 1.0:
			var left := "%d" % int(ceil(pl.skills.slots[slot].left))
			var w2 := font.get_string_size(left, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string_outline(font, c + Vector2(-w2 * 0.5, -r * 0.35), left, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, UI.OUTLINE)
			draw_string(font, c + Vector2(-w2 * 0.5, -r * 0.35), left, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.GOLD)
		if not G.is_touch:
			var kt: String = KEYS[slot]
			var w3 := font.get_string_size(kt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			draw_style_box(_key_box(), Rect2(c.x - w3 * 0.5 - 9, c.y + r - 10, w3 + 18, 28))
			draw_string(font, c + Vector2(-w3 * 0.5, r + 10), kt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UI.GOLD)


var _kb: StyleBox


func _key_box() -> StyleBox:
	if _kb == null:
		_kb = UI.box(Color("0B2148"), UI.EDGE, 10, 2)
	return _kb


## Runder glänzender Knopf wie die Knöpfe der Menüs: dunkler Rand, Unterlippe, heller Verlauf, Glanzlicht.
func _gloss(c: Vector2, r: float, col: Color, shine := 1.0) -> void:
	draw_circle(c + Vector2(0, 5.0), r + 5.0, Color(0, 0, 0, 0.28))
	draw_circle(c, r + 5.0, UI.OUTLINE)
	draw_circle(c + Vector2(0, 2.0), r, col.darkened(0.45))
	draw_circle(c - Vector2(0, r * 0.05), r * 0.95, col)
	draw_circle(c - Vector2(0, r * 0.2), r * 0.72, col.lightened(0.14))
	# Glanzlicht oben (flache Ellipse)
	draw_set_transform(c - Vector2(0, r * 0.5), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, r * 0.52, Color(1, 1, 1, 0.22 * shine))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_arc(c - Vector2(0, r * 0.05), r * 0.95, PI * 1.1, PI * 1.9, 24, Color(1, 1, 1, 0.45 * shine), 3.0, true)
