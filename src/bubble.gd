extends Node3D
## Sammelblase über einem Gebäude: runde Scheibe mit Symbol und Menge, immer zur Kamera gedreht.
## Zustände: 0 normal (weißer Rand) · 1 fast voll (goldener Rand, pulsiert) · 2 voll (roter Rand, Ausrufezeichen).

const UI = preload("res://src/ui.gd")

const RIM := [Color(1, 1, 1), Color("FFD23E"), Color("FF4D62")]

static var _disc: ImageTexture
static var _ring: ImageTexture

var state := 0
var icon_name := ""
var amount_text := ""
var tag = null                  # frei belegbar (Gebäude-ID, Abholung …)
var base_y := 0.0
var _bg: Sprite3D
var _rim: Sprite3D
var _icon: Sprite3D
var _label: Label3D
var _mark: Label3D
var _t := 0.0
var _pop := 0.0


static func _textures() -> void:
	if _disc != null:
		return
	var n := 96
	var a := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var b := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n * 0.5 - 0.5, n * 0.5 - 0.5)
	for y in n:
		for x in n:
			var r := Vector2(x, y).distance_to(c)
			# Scheibe: innen hell, zum Rand leicht bläulich
			var fill := clampf(42.0 - r, 0.0, 1.0)
			var shade := 1.0 - 0.1 * smoothstep(20.0, 42.0, r)
			a.set_pixel(x, y, Color(shade, shade, 1.0, fill * 0.96))
			var ring := clampf(46.5 - r, 0.0, 1.0) * clampf(r - 38.5, 0.0, 1.0)
			b.set_pixel(x, y, Color(1, 1, 1, ring))
	_disc = ImageTexture.create_from_image(a)
	_ring = ImageTexture.create_from_image(b)
	# beim Beenden freigeben, sonst meldet die Engine übrig gebliebene Texturen
	P.tree_exiting.connect(func():
		_disc = null
		_ring = null)


func _init() -> void:
	_textures()
	_bg = _sprite(_disc, 0.02, 10)
	_rim = _sprite(_ring, 0.02, 11)
	_icon = _sprite(null, 0.0048, 12)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.render_priority = 13
	_label.outline_render_priority = 12
	_label.font = UI.font(true)
	_label.font_size = 72
	_label.outline_size = 22
	_label.pixel_size = 0.0075
	_label.modulate = Color("FFD23E")
	_label.outline_modulate = Color("06142E")
	_label.position = Vector3(0, -1.25, 0)
	add_child(_label)
	_mark = Label3D.new()
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.no_depth_test = true
	_mark.render_priority = 14
	_mark.outline_render_priority = 13
	_mark.font = UI.font(true)
	_mark.font_size = 96
	_mark.outline_size = 26
	_mark.pixel_size = 0.0075
	_mark.text = "!"
	_mark.modulate = Color("FF4D62")
	_mark.outline_modulate = Color.WHITE
	_mark.position = Vector3(0.85, 0.75, 0)
	_mark.visible = false
	add_child(_mark)
	visible = false


func _sprite(tex: Texture2D, px: float, prio: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = px
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.no_depth_test = true
	s.render_priority = prio
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(s)
	return s


## icon: Name in res://icons (z. B. "res_wood"). text: Menge. st: Zustand 0..2.
func show_as(icon: String, text: String, st: int) -> void:
	if icon != icon_name:
		icon_name = icon
		var path := "res://icons/%s.png" % icon
		_icon.texture = load(path) if ResourceLoader.exists(path) else null
		if _icon.texture != null:
			_icon.pixel_size = 1.2 / maxf(64.0, float(_icon.texture.get_width()))
	if text != amount_text:
		amount_text = text
		_label.text = text
	state = clampi(st, 0, 2)
	_rim.modulate = RIM[state]
	_mark.visible = state == 2
	if not visible:
		visible = true
		_pop = 1.0
		set_process(true)


func hide_now() -> void:
	visible = false


## Punkt auf dem Bildschirm (für Antippen und fliegende Symbole).
func screen_pos(cam: Camera3D) -> Vector2:
	return cam.unproject_position(global_position)


func _process(dt: float) -> void:
	if not visible:
		set_process(false)
		return
	_t += dt
	position.y = base_y + sin(_t * 2.6) * 0.22
	var s := 1.0
	if _pop > 0.0:
		_pop = maxf(0.0, _pop - dt * 3.0)
		s = 1.0 + sin((1.0 - _pop) * PI * 2.0) * 0.25 * _pop - _pop * _pop
	if state >= 1:
		s *= 1.0 + 0.07 * sin(_t * (7.0 if state == 2 else 4.5))
	scale = Vector3(s, s, s)
