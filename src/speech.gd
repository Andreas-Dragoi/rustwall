extends CanvasLayer
## V6 Paket E – Sprechblasen: kurze Textblasen über Figuren in der Welt (Bewohner, Gerettete, Held) und Funk-Blasen
## mit Bild eines Helden oben links (Gespräch per Funk aus der Basis). Liegt unter dem HUD (Ebene 8).
## say(ziel, text, dauer)      Blase über einem Node3D (folgt ihm, verschwindet hinter der Kamera)
## radio(held, text, dauer)    Funk-Blase oben links
## count()                     Zahl der Blasen über Figuren (für „nicht zu viele gleichzeitig“)

const UI = preload("res://src/ui.gd")

const BG := Color("FFF8E6")
const INK := Color("1E2A44")
const EDGE := Color("2E3A5C")
const RADIO_BG := Color("E6F4FF")

var _items: Array = []              # {c: Control, n: Node3D, t: float, dur: float, head: float, radio: bool}
var _radio_box: VBoxContainer
var said := 0                        # (Test) Zahl aller gezeigten Blasen


func _init() -> void:
	name = "Speech"
	layer = 8


func _ready() -> void:
	_radio_box = UI.vbox(8)
	_radio_box.anchor_left = 0.5                   # oben in der Mitte (links oben steht im Kampf die Anzeige des Helden)
	_radio_box.anchor_right = 0.5
	_radio_box.offset_top = 118.0
	_radio_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_radio_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_radio_box)


func _style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = EDGE
	s.set_border_width_all(3)
	s.set_corner_radius_all(18)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 9
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 3)
	return s


func _label(text: String, maxw: float) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UI.font(true))
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var w := minf(maxw, 14.0 * float(tr(text).length()) + 20.0)
	l.custom_minimum_size = Vector2(maxf(w, 90.0), 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func count() -> int:
	var n := 0
	for it in _items:
		if not bool(it.radio):
			n += 1
	return n


func has_speaker(n: Node3D) -> bool:
	for it in _items:
		if is_instance_valid(it.n) and it.n == n:
			return true
	return false


func say(target: Node3D, text: String, dur := 4.0, head := 2.45) -> Control:
	if target == null or not is_instance_valid(target):
		return null
	for it in _items.duplicate():
		if is_instance_valid(it.n) and it.n == target:
			_drop(it)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _style(BG))
	pc.add_child(_label(text, 380.0))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tail := Polygon2D.new()
	tail.color = BG
	tail.polygon = PackedVector2Array([Vector2(-11, -3), Vector2(11, -3), Vector2(0, 15)])
	var tail_edge := Polygon2D.new()
	tail_edge.color = EDGE
	tail_edge.polygon = PackedVector2Array([Vector2(-14, -3), Vector2(14, -3), Vector2(0, 19)])
	pc.add_child(tail_edge)
	pc.add_child(tail)
	pc.modulate.a = 0.0
	pc.visible = false
	add_child(pc)
	var it := {"c": pc, "n": target, "t": 0.0, "dur": dur, "head": head, "radio": false, "tail": [tail_edge, tail]}
	_items.append(it)
	said += 1
	Sfx.play("speech_pop", -14.0, 1.0 + randf() * 0.15)
	return pc


func radio(hero_key: String, text: String, dur := 4.0) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _style(RADIO_BG))
	var row := UI.hbox(10)
	if hero_key != "":
		row.add_child(UI.hero_pic(hero_key, 64.0))
	else:
		row.add_child(UI.pic("ui_mail", 52.0))
	var col := UI.vbox(0)
	var who := UI.label("Funk", 17, Color("3B6FD0"))
	col.add_child(who)
	var l := _label(text, 360.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(l)
	row.add_child(col)
	pc.add_child(row)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.ignore_mouse(pc)
	pc.modulate.a = 0.0
	_radio_box.add_child(pc)
	_items.append({"c": pc, "n": null, "t": 0.0, "dur": dur, "head": 0.0, "radio": true})
	said += 1
	Sfx.play("radio_blip", -10.0)
	return pc


func clear() -> void:
	for it in _items.duplicate():
		_drop(it)


func _drop(it: Dictionary) -> void:
	_items.erase(it)
	if is_instance_valid(it.c):
		it.c.queue_free()


func _process(dt: float) -> void:
	if _items.is_empty():
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	var vs := get_viewport().get_visible_rect().size
	for it in _items.duplicate():
		it.t = float(it.t) + dt
		if not is_instance_valid(it.c) or float(it.t) > float(it.dur):
			_drop(it)
			continue
		var c: Control = it.c
		var a := clampf(minf(float(it.t) * 6.0, (float(it.dur) - float(it.t)) * 3.0), 0.0, 1.0)
		c.modulate.a = a
		if bool(it.radio):
			continue
		if it.n == null or not is_instance_valid(it.n) or cam == null:
			_drop(it)
			continue
		var n: Node3D = it.n
		if not n.is_visible_in_tree():
			_drop(it)
			continue
		var p3: Vector3 = n.global_position + Vector3(0, float(it.head), 0)
		if cam.is_position_behind(p3):
			c.visible = false
			continue
		var sp := cam.unproject_position(p3)
		var sz := c.get_combined_minimum_size()
		c.size = sz
		var pos := sp - Vector2(sz.x * 0.5, sz.y + 16.0)
		pos.x = clampf(pos.x, 8.0, vs.x - sz.x - 8.0)
		pos.y = clampf(pos.y, 8.0, vs.y - sz.y - 8.0)
		c.position = pos
		c.visible = sp.x > -40.0 and sp.x < vs.x + 40.0 and sp.y > -40.0 and sp.y < vs.y + 40.0
		# Spitze zeigt auf die Figur
		var tx := clampf(sp.x - pos.x, 20.0, sz.x - 20.0)
		for t in it.tail:
			(t as Polygon2D).position = Vector2(tx, sz.y - 1.0)
