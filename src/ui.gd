extends RefCounted
## Oberflächen-Baukasten im Stil der Vorlagen "Werkstatt" und "Garage":
## tiefblaue Verlaufsflächen, Tafeln mit hellblauem Rand und weichem Schein, große runde Ecken,
## glänzende Knöpfe mit heller Oberkante und dunkler Unterlippe, dicke weiße Schrift mit dunkler
## Kontur, goldene Zahlen, überall Bildzeichen.
## Alle Bildschirme und das HUD bauen ihre Elemente ausschließlich hierüber.
##
## Bilder: UI.pic("name", größe) lädt res://icons/<name>.png, wenn es die Datei gibt, und zeichnet
## sonst ein einfaches Ersatzzeichen. Es stürzt nie ab und zeigt nie "nichts".

const D = preload("res://src/data.gd")

# ---------------------------------------------------------------- Farben
const NAVY := Color("12305F")
const NAVY_L := Color("1B427C")
const NAVY_D := Color("0B2148")
const BG_TOP := Color("163C78")
const BG_BOT := Color("0A1D42")
const EDGE := Color("3B7BD0")          # Rand der Tafeln
const SKY := Color("4AB0FF")
const GOLD := Color("FFD23E")
const WHITE := Color("FFFFFF")
const GREY := Color("9FB6D8")
const TEXT := Color("DCE8F8")
const GREEN := Color("6FE03A")
const RED := Color("FF4D62")
const ORANGE := Color("FFA12E")
const PURPLE := Color("B67BFF")
const OUTLINE := Color("06142E")

const BTN_BLUE := Color("2F8DEB")
const BTN_GREEN := Color("4CC224")
const BTN_RED := Color("F0384F")
const BTN_GOLD := Color("F5B41E")
const BTN_DARK := Color("24508F")
const BTN_PURPLE := Color("9658E8")
const BTN_OFF := Color("3A5788")

static var _font: Font
static var _font_bold: Font
static var _theme: Theme
static var _tex := {}
static var _bar_mem := {}
static var _exit_hooked := false
static var _closing := false
## true während des ersten Aufbaus nach dem Öffnen eines Bildschirms (Balken laufen dann von 0 hoch)
static var fresh := false


static func font(bold := true) -> Font:
	if _font == null:
		var base: Font = load("res://fonts/fredoka.ttf")
		var sym = load("res://fonts/rustwall_symbols.ttf")   # Pfeile, Haken, Sterne … fehlen in Fredoka (Untermenge von DejaVu Sans, siehe fonts/rustwall_symbols_LICENSE.txt)
		if sym is Font and base.fallbacks.is_empty():
			base.fallbacks = [sym]
		var ts := TextServerManager.get_primary_interface()
		var a := FontVariation.new()
		a.base_font = base
		a.variation_opentype = {ts.name_to_tag("wght"): 500}
		_font = a
		var b := FontVariation.new()
		b.base_font = base
		b.variation_opentype = {ts.name_to_tag("wght"): 700}
		_font_bold = b
	return _font_bold if bold else _font


## Ton mit Ausweichklang: spielt "name", wenn es ihn gibt, sonst "fallback".
static func sfx(name: String, fallback := "", vol := -4.0, pitch := 1.0) -> void:
	if Sfx.has(name):
		Sfx.play(name, vol, pitch)
	elif fallback != "":
		Sfx.play(fallback, vol, pitch)


# ================================================================= Kästen
## Einfarbiger abgerundeter Kasten.
static func box(bg: Color, border := Color(0, 0, 0, 0), radius := 18, bw := 0, pad := 0, shadow := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(bw)
	s.border_color = border
	s.set_content_margin_all(pad)
	s.anti_aliasing = true
	if shadow > 0:
		s.shadow_size = shadow
		s.shadow_color = Color(border.r, border.g, border.b, 0.3) if bw > 0 else Color(0, 0, 0, 0.35)
	return s


## Kasten mit senkrechtem Farbverlauf, Rand, Schein, Glanz und Unterlippe.
## Wird als Vektor gezeichnet (ein Vieleck mit Eckfarben), also in jeder Auflösung scharf und billig.
class Grad extends StyleBox:
	var top := Color.WHITE
	var bot := Color.WHITE
	var radius := 16.0
	var bw := 2.0
	var lip := 0.0
	var shine := 0.0
	var press := 0.0
	var _edge: StyleBoxFlat
	var _glow: StyleBoxFlat
	var _lip: StyleBoxFlat
	var _inner: StyleBoxFlat

	func _draw(ci: RID, rect: Rect2) -> void:
		var r := rect
		if press > 0.0:
			r.position.y += press
			r.size.y -= press
		if r.size.x < 2.0 or r.size.y < 2.0:
			return
		if _glow:
			_glow.draw(ci, r)
		var body := r
		if lip > 0.0 and r.size.y > lip * 2.0:
			_lip.draw(ci, r)
			body.size.y -= lip
		var rad := minf(radius, minf(body.size.x, body.size.y) * 0.5)
		_poly(ci, body.grow(-0.8), maxf(rad - 0.8, 0.0), top, bot, false)
		if shine > 0.0 and body.size.y > 16.0:
			var sr := Rect2(body.position.x + bw + 2.0, body.position.y + bw + 1.0, body.size.x - (bw + 2.0) * 2.0, body.size.y * 0.46)
			if sr.size.x > 4.0:
				_poly(ci, sr, maxf(rad - bw - 2.0, 0.0), Color(1, 1, 1, shine), Color(1, 1, 1, shine * 0.15), true)
		if _inner and body.size.x > bw * 4.0 and body.size.y > bw * 4.0:
			_inner.draw(ci, body.grow(-bw))
		if _edge:
			_edge.draw(ci, body)

	func _poly(ci: RID, r: Rect2, rad: float, c0: Color, c1: Color, top_only: bool) -> void:
		rad = minf(rad, minf(r.size.x * 0.5, r.size.y if top_only else r.size.y * 0.5))
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var corners := [Vector2(r.position.x + rad, r.position.y + rad), Vector2(r.end.x - rad, r.position.y + rad),
			Vector2(r.end.x - rad, r.end.y - rad), Vector2(r.position.x + rad, r.end.y - rad)]
		for k in 4:
			if top_only and k >= 2:
				var p := Vector2(r.end.x, r.end.y) if k == 2 else Vector2(r.position.x, r.end.y)
				pts.append(p)
				cols.append(c1)
				continue
			if rad < 0.5:
				var q: Vector2 = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)][k]
				pts.append(q)
				cols.append(c0.lerp(c1, (q.y - r.position.y) / r.size.y))
				continue
			for i in 6:
				var a := PI + PI * 0.5 * k + PI * 0.5 * i / 5.0
				var p2: Vector2 = corners[k] + Vector2(cos(a), sin(a)) * rad
				pts.append(p2)
				cols.append(c0.lerp(c1, clampf((p2.y - r.position.y) / r.size.y, 0.0, 1.0)))
		# gewölbtes Vieleck als Fächer aus Dreiecken (braucht keine Zerlegung)
		var idx := PackedInt32Array()
		for i in range(1, pts.size() - 1):
			idx.append(0)
			idx.append(i)
			idx.append(i + 1)
		RenderingServer.canvas_item_add_triangle_array(ci, idx, pts, cols)


static func grad(top: Color, bot: Color, border := Color(0, 0, 0, 0), radius := 18, bw := 2, pad := 0,
		glow := 0, glow_col := Color(0, 0, 0, 0.3), lip := 0, lip_col := Color.BLACK, shine := 0.0, inner := Color(0, 0, 0, 0)) -> Grad:
	var s := Grad.new()
	s.top = top
	s.bot = bot
	s.radius = radius
	s.bw = bw
	s.lip = lip
	s.shine = shine
	s.set_content_margin_all(pad)
	if lip > 0:
		s.content_margin_bottom = pad + lip
	var e := StyleBoxFlat.new()
	e.draw_center = false
	e.set_corner_radius_all(radius)
	e.set_border_width_all(maxi(bw, 1))
	e.border_color = border if (bw > 0 and border.a > 0.0) else top.lerp(bot, 0.5)
	e.anti_aliasing = true
	s._edge = e
	if glow > 0:
		var g := StyleBoxFlat.new()
		g.draw_center = false
		g.set_corner_radius_all(radius)
		g.shadow_size = glow
		g.shadow_color = glow_col
		s._glow = g
	if lip > 0:
		s._lip = box(lip_col, Color(0, 0, 0, 0), radius)
	if inner.a > 0.0:
		var i := StyleBoxFlat.new()
		i.draw_center = false
		i.set_corner_radius_all(maxi(radius - bw, 0))
		i.set_border_width_all(2)
		i.border_color = inner
		i.anti_aliasing = true
		s._inner = i
	return s


## Tafel-Stil: Verlauf aus einer Grundfarbe, Rand, weicher Schein außen, heller Strich innen.
static func panel_style(bg := NAVY, border := EDGE, radius := 22, pad := 18, glow := 10) -> Grad:
	var top := bg.lightened(0.07)
	top.a = bg.a
	var bot := bg.darkened(0.16)
	bot.a = bg.a
	var has := border.a > 0.0
	return grad(top, bot, border, radius, 3 if has else 0, pad, glow if has else 0, Color(border.r, border.g, border.b, 0.28), 0, Color.BLACK, 0.0,
		Color(1, 1, 1, 0.07) if has else Color(0, 0, 0, 0))


## Karten-Stil (Listeneinträge, Kästen in Tafeln).
static func card_style(bg := NAVY_L, border := Color(0, 0, 0, 0), radius := 16, pad := 14) -> Grad:
	var top := bg.lightened(0.05)
	top.a = bg.a
	var bot := bg.darkened(0.12)
	bot.a = bg.a
	var bc := border if border.a > 0.0 else Color(bg.lightened(0.22), 0.9 * bg.a)
	return grad(top, bot, bc, radius, 3 if border.a > 0.0 else 2, pad)


static func gold_style(radius := 16, pad := 0, lip := 0) -> Grad:
	var s := grad(Color("FFE25A"), Color("F6A313"), Color("FFF1A6"), radius, 3, pad, 8, Color(1.0, 0.8, 0.2, 0.35), lip, Color("A8660A"), 0.22)
	return s


static func _btn_style(col: Color, state: int) -> Grad:
	# state: 0 normal, 1 hover, 2 gedrückt, 3 aus
	var c := col
	var shine := 0.2
	if state == 1:
		c = col.lightened(0.1)
	elif state == 2:
		c = col.darkened(0.1)
		shine = 0.1
	elif state == 3:
		c = BTN_OFF
		shine = 0.05
	var lipc := c.darkened(0.48)
	var s := grad(c.lightened(0.2), c.darkened(0.1), c.lightened(0.42), 16, 2, 0, 3, Color(0, 0, 0, 0.3), 3 if state == 2 else 7, lipc, shine)
	if state == 3:
		s._edge.border_color = Color("5B7CB0")
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 8
	s.content_margin_bottom = 15
	if state == 2:
		s.press = 4.0
		s.content_margin_top = 12
		s.content_margin_bottom = 11
	return s


static func _btn_styles(th: Theme, type: String, col: Color) -> void:
	th.set_stylebox("normal", type, _btn_style(col, 0))
	th.set_stylebox("hover", type, _btn_style(col, 1))
	th.set_stylebox("pressed", type, _btn_style(col, 2))
	th.set_stylebox("disabled", type, _btn_style(col, 3))
	th.set_stylebox("focus", type, StyleBoxEmpty.new())
	_btn_text(th, type)


static func _btn_text(th: Theme, type: String) -> void:
	th.set_color("font_color", type, WHITE)
	th.set_color("font_hover_color", type, WHITE)
	th.set_color("font_pressed_color", type, WHITE)
	th.set_color("font_focus_color", type, WHITE)
	th.set_color("font_hover_pressed_color", type, WHITE)
	th.set_color("font_disabled_color", type, Color("A3B9DA"))
	th.set_color("font_outline_color", type, OUTLINE)
	th.set_constant("outline_size", type, 6)
	th.set_font("font", type, font(true))
	th.set_font_size("font_size", type, 28)


static func _row_style(sel: bool, state: int, radius := 16) -> Grad:
	var s: Grad
	if sel:
		s = gold_style(radius, 0)
		if state == 2:
			s.top = s.top.darkened(0.06)
	else:
		var c := Color("19407A")
		if state == 1:
			c = c.lightened(0.08)
		elif state == 2:
			c = c.darkened(0.12)
		elif state == 3:
			c = Color("152F5A")
		s = grad(c.lightened(0.05), c.darkened(0.14), Color("3470C0") if state != 1 else Color("5C9BEA"), radius, 2, 0, 0, Color.BLACK, 0, Color.BLACK, 0.05)
	return s


## Gemeinsames Theme. Einmal am obersten Control setzen: node.theme = UI.theme()
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var th := Theme.new()
	th.default_font = font(true)
	th.default_font_size = 26
	_btn_styles(th, "Button", BTN_BLUE)
	for v in [["BtnGreen", BTN_GREEN], ["BtnRed", BTN_RED], ["BtnGold", BTN_GOLD], ["BtnDark", BTN_DARK], ["BtnPurple", BTN_PURPLE]]:
		th.set_type_variation(v[0], "Button")
		_btn_styles(th, v[0], v[1])
	# Listenzeilen und Reiter
	for v in [["Row", false], ["RowOn", true]]:
		var type: String = v[0]
		th.set_type_variation(type, "Button")
		th.set_stylebox("normal", type, _row_style(v[1], 0))
		th.set_stylebox("hover", type, _row_style(v[1], 1))
		th.set_stylebox("pressed", type, _row_style(v[1], 2))
		th.set_stylebox("disabled", type, _row_style(v[1], 3))
		th.set_stylebox("focus", type, StyleBoxEmpty.new())
		_btn_text(th, type)
	for v in [["Tab", false], ["TabOn", true]]:
		var type2: String = v[0]
		th.set_type_variation(type2, "Button")
		for st in [["normal", 0], ["hover", 1], ["pressed", 2], ["disabled", 3]]:
			var sb := _row_style(v[1], st[1], 14)
			sb.content_margin_left = 20
			sb.content_margin_right = 20
			sb.content_margin_top = 8
			sb.content_margin_bottom = 8
			th.set_stylebox(st[0], type2, sb)
		th.set_stylebox("focus", type2, StyleBoxEmpty.new())
		_btn_text(th, type2)
	th.set_stylebox("panel", "PanelContainer", panel_style())
	th.set_stylebox("panel", "Panel", panel_style())
	th.set_color("font_color", "Label", WHITE)
	th.set_color("font_outline_color", "Label", OUTLINE)
	th.set_constant("outline_size", "Label", 6)
	th.set_color("default_color", "RichTextLabel", WHITE)
	th.set_font("normal_font", "RichTextLabel", font(false))
	th.set_font("bold_font", "RichTextLabel", font(true))
	th.set_font_size("normal_font_size", "RichTextLabel", 26)
	th.set_font_size("bold_font_size", "RichTextLabel", 26)
	# Fortschrittsbalken
	th.set_stylebox("background", "ProgressBar", box(Color("071833"), Color("04102A"), 10, 3))
	th.set_stylebox("fill", "ProgressBar", _fill_style(D.C_BAR_BLUE))
	# Rollbalken
	var sb2 := box(Color(1, 1, 1, 0.07), Color(0, 0, 0, 0), 6)
	sb2.content_margin_left = 6
	sb2.content_margin_right = 6
	th.set_stylebox("scroll", "VScrollBar", sb2)
	th.set_stylebox("grabber", "VScrollBar", box(EDGE, Color(0, 0, 0, 0), 6))
	th.set_stylebox("grabber_highlight", "VScrollBar", box(SKY, Color(0, 0, 0, 0), 6))
	th.set_stylebox("grabber_pressed", "VScrollBar", box(GOLD, Color(0, 0, 0, 0), 6))
	th.set_stylebox("scroll", "HScrollBar", sb2)
	th.set_stylebox("grabber", "HScrollBar", box(EDGE, Color(0, 0, 0, 0), 6))
	th.set_stylebox("grabber_highlight", "HScrollBar", box(SKY, Color(0, 0, 0, 0), 6))
	th.set_stylebox("grabber_pressed", "HScrollBar", box(GOLD, Color(0, 0, 0, 0), 6))
	# Eingabefeld
	th.set_stylebox("normal", "LineEdit", box(Color("081A3A"), EDGE, 14, 3, 14))
	th.set_stylebox("focus", "LineEdit", box(Color("081A3A"), GOLD, 14, 3, 14))
	th.set_color("font_color", "LineEdit", WHITE)
	th.set_color("font_placeholder_color", "LineEdit", Color("6F88B0"))
	th.set_font("font", "LineEdit", font(false))
	# Schieberegler
	th.set_stylebox("slider", "HSlider", box(Color("071833"), Color("04102A"), 9, 3, 7))
	th.set_stylebox("grabber_area", "HSlider", _fill_style(SKY))
	th.set_stylebox("grabber_area_highlight", "HSlider", _fill_style(SKY.lightened(0.15)))
	# Hinweis-Blase
	th.set_stylebox("panel", "TooltipPanel", box(Color("081A3A"), EDGE, 10, 2, 10))
	th.set_color("font_color", "TooltipLabel", WHITE)
	th.set_font_size("font_size", "TooltipLabel", 20)
	_theme = th
	return th


static func _fill_style(col: Color) -> Grad:
	return grad(col.lightened(0.3), col.darkened(0.05), col.lightened(0.5), 8, 2, 0, 0, Color.BLACK, 0, Color.BLACK, 0.25)


# ================================================================= Bausteine
static func label(text: String, size := 26, col := WHITE, bold := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(bold))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", maxi(4, int(size * 0.22)) if bold else maxi(3, int(size * 0.14)))
	return l


## Mehrzeiliger Text mit Umbruch (Beschreibungen, Geschichten).
static func text(t: String, size := 24, col := TEXT, min_width := 0.0) -> Label:
	var l := label(t, size, col, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_constant_override("line_spacing", 4)
	if min_width > 0.0:
		l.custom_minimum_size.x = min_width
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## Kleine Unterzeile einer Listenzeile; auf der goldenen (ausgewählten) Zeile weiß mit kräftiger Kontur.
static func sub_label(t: String, size := 19, col := TEXT, on_gold := false) -> Label:
	if not on_gold:
		return label(t, size, col, false)
	var l := label(t, size, WHITE, true)
	l.add_theme_color_override("font_outline_color", Color("7A4A08"))
	l.add_theme_constant_override("outline_size", 5)
	return l


static func gold(t: String, size := 30) -> Label:
	return label(t, size, GOLD)


static func _variation(kind: String) -> String:
	match kind:
		"green":
			return "BtnGreen"
		"red":
			return "BtnRed"
		"gold":
			return "BtnGold"
		"dark":
			return "BtnDark"
		"purple":
			return "BtnPurple"
		"row":
			return "Row"
		"row_on":
			return "RowOn"
		"tab":
			return "Tab"
		"tab_on":
			return "TabOn"
	return ""


## kind: "" (blau) | "green" | "red" | "gold" | "dark" | "purple"
## icon_name: Bildzeichen links vom Text (Name wie bei pic(), z. B. "ui_hammer"). Der Text steht dann in
## einem eigenen Label; zum Ändern UI.btn_text(b, "…") benutzen, zum Lesen UI.btn_get_text(b).
static func button(t: String, cb := Callable(), kind := "", size := 28, icon_name := "") -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	var tv := _variation(kind)
	if tv != "":
		b.theme_type_variation = tv
	b.add_theme_font_size_override("font_size", size)
	b.text = t
	if icon_name != "":
		# Der eigene Text des Knopfs bleibt unsichtbar und sorgt nur für die richtige Breite;
		# sichtbar sind Bild und Label darüber.
		for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color", "font_outline_color"]:
			b.add_theme_color_override(cn, Color(0, 0, 0, 0))
		var isz := size * 1.45
		if t != "":
			b.icon = _blank(int(ceil(isz)))
			b.add_theme_constant_override("h_separation", int(size * 0.35))
		var l := label(t, size)
		var row := hbox(int(size * 0.35))
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(pic(icon_name, isz))
		row.add_child(l)
		l.visible = t != ""
		var m := MarginContainer.new()
		m.set_anchors_preset(Control.PRESET_FULL_RECT)
		m.add_theme_constant_override("margin_left", 8)
		m.add_theme_constant_override("margin_right", 8)
		m.add_theme_constant_override("margin_top", 2)
		m.add_theme_constant_override("margin_bottom", 9)
		m.add_child(row)
		b.add_child(m)
		ignore_mouse(m)
		b.set_meta("label", l)
		b.set_meta("content", m)
		b.button_down.connect(func(): m.add_theme_constant_override("margin_top", 8))
		b.button_up.connect(func(): m.add_theme_constant_override("margin_top", 2))
	if cb.is_valid():
		b.pressed.connect(func():
			Sfx.play("click", -8.0)
			cb.call())
	squash(b)
	return b


static func _blank(w: int) -> Texture2D:
	var key := "#blank%d" % w
	tex("")
	if _closing:
		return null
	if not _tex.has(key):
		var img := Image.create(w, 2, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		_tex[key] = ImageTexture.create_from_image(img)
	return _tex[key]


## Text eines Knopfs ändern (auch bei Knöpfen mit Bild).
static func btn_text(b: Button, t: String) -> void:
	if b.text != t:
		b.text = t
	if b.has_meta("label"):
		var l: Label = b.get_meta("label")
		if l.text != t:
			l.text = t
			l.visible = t != ""


static func btn_get_text(b: BaseButton) -> String:
	return String(b.get("text")) if b is Button else ""


static func btn_kind(b: Button, kind: String) -> void:
	var tv := _variation(kind)
	if String(b.theme_type_variation) != tv:
		b.theme_type_variation = tv


## Reiter mit Bildzeichen; ausgewählt = goldener Verlauf.
static func tab_button(t: String, icon_name: String, selected: bool, cb: Callable, size := 24) -> Button:
	var b := button(t, cb, "tab_on" if selected else "tab", size, icon_name)
	b.custom_minimum_size.y = 68.0
	b.set_meta("tab", true)
	return b


## Listenzeile zum Antippen mit eigenem Inhalt; ausgewählt = goldener Verlauf.
static func row_button(selected: bool, cb: Callable, content: Control, min_h := 88.0, kind := "") -> Button:
	var b := button("", cb, kind if kind != "" else ("row_on" if selected else "row"))
	b.custom_minimum_size = Vector2(0, min_h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_contents = true
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	var lip := 0 if kind == "" else 8
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 6 + lip)
	m.add_child(content)
	b.add_child(m)
	b.set_meta("content", m)
	ignore_mouse(m)
	return b


## Knopf sperren; bei Knöpfen mit eigenem Inhalt wird auch der Inhalt blass.
static func disable(b: BaseButton, off := true) -> void:
	b.disabled = off
	if b.has_meta("content"):
		var m: Control = b.get_meta("content")
		m.modulate = Color(0.72, 0.8, 0.95, 0.7) if off else Color.WHITE


static func ignore_mouse(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		ignore_mouse(c)


static func panel(inner: Control = null, bg := NAVY, border := EDGE, radius := 22, pad := 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg, border, radius, pad))
	if inner:
		p.add_child(inner)
	return p


## Karte ohne Leuchtrand (Kästen innerhalb einer Tafel).
static func card(inner: Control = null, bg := NAVY_L, pad := 14, border := Color(0, 0, 0, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", card_style(bg, border, 16, pad))
	if inner:
		p.add_child(inner)
	return p


## Dunkle Pille (Rohstoffanzeige in der Kopfzeile).
static func pill(inner: Control, pad_x := 14, pad_y := 5) -> PanelContainer:
	var p := PanelContainer.new()
	var s := box(Color(0.02, 0.07, 0.18, 0.55), Color(1, 1, 1, 0.08), 24, 2)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x + 2
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	p.add_theme_stylebox_override("panel", s)
	p.add_child(inner)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


static func hbox(sep := 12, children: Array = []) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	for c in children:
		h.add_child(c)
	return h


static func vbox(sep := 12, children: Array = []) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	for c in children:
		v.add_child(c)
	return v


static func grid(cols: int, sep := 12) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", sep)
	g.add_theme_constant_override("v_separation", sep)
	return g


static func flow(sep := 8) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", sep)
	f.add_theme_constant_override("v_separation", sep)
	return f


static func margin(inner: Control, l := 0, t := 0, r := 0, b := 0) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(inner)
	return m


static func spacer(expand := true, min_size := Vector2.ZERO) -> Control:
	var c := Control.new()
	c.custom_minimum_size = min_size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## Dünne Trennlinie (waagrecht; senkrecht mit vertical = true).
static func sep(vertical := false, col := Color(EDGE, 0.55)) -> ColorRect:
	var c := ColorRect.new()
	c.color = col
	c.custom_minimum_size = Vector2(3, 0) if vertical else Vector2(0, 3)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func scroll(inner: Control, min_size := Vector2.ZERO) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.custom_minimum_size = min_size
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(inner)
	return s


## Fortschrittsbalken. Mit key merkt er sich den letzten Wert und läuft sanft zum neuen;
## ohne key läuft er nur beim ersten Aufbau eines Bildschirms (UI.fresh) von 0 hoch.
static func bar(ratio: float, col := D.C_BAR_BLUE, min_size := Vector2(200, 26), key := "") -> ProgressBar:
	var b := ProgressBar.new()
	b.min_value = 0.0
	b.max_value = 1.0
	b.step = 0.0
	var to := clampf(ratio, 0.0, 1.0)
	b.value = to
	b.show_percentage = false
	b.custom_minimum_size = min_size
	var rad := int(minf(10.0, min_size.y * 0.5))
	b.add_theme_stylebox_override("background", box(Color("071833"), Color("04102A"), rad, 3 if min_size.y >= 16.0 else 2))
	var f := _fill_style(col)
	f.radius = maxf(rad - 2.0, 2.0)
	f._edge.set_corner_radius_all(int(f.radius))
	b.add_theme_stylebox_override("fill", f)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var from := to
	if key != "":
		from = float(_bar_mem.get(key, 0.0))
		_bar_mem[key] = to
	elif fresh:
		from = 0.0
	if not is_equal_approx(from, to):
		b.value = from
		var tw := b.create_tween()
		tw.tween_property(b, "value", to, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return b


## Gemerkte Balkenwerte vergessen (beim Schließen eines Bildschirms).
static func forget() -> void:
	_bar_mem.clear()
	fresh = false


# ================================================================= Bilder
static func tex(name: String) -> Texture2D:
	if _closing:
		return null
	if _tex.has(name):
		return _tex[name]
	if not _exit_hooked:
		# beim Beenden den Bildspeicher leeren, sonst meldet die Engine übrig gebliebene Texturen
		_exit_hooked = true
		P.tree_exiting.connect(_drop_cache)
	var t: Texture2D = null
	var path := "res://icons/%s.png" % name
	if name != "" and ResourceLoader.exists(path):
		var src = load(path)
		if src is Texture2D:
			t = src
			# Mipmaps selbst erzeugen: große Bilder bleiben auch stark verkleinert glatt
			if DisplayServer.get_name() != "headless":
				var img: Image = src.get_image()
				if img != null and not img.is_empty() and not img.is_compressed() and not img.has_mipmaps() and img.get_width() > 96:
					img.generate_mipmaps()
					t = ImageTexture.create_from_image(img)
	_tex[name] = t
	return t


static func _drop_cache() -> void:
	# ab jetzt keine Bilder mehr laden: was beim Beenden noch gebaut wird, bekommt Zeichnungen
	_closing = true
	_tex.clear()
	_theme = null
	_font = null
	_font_bold = null


static func has_pic(name: String) -> bool:
	return tex(name) != null


static func _fallback_kind(name: String) -> String:
	if name.begins_with("res_") or name.begins_with("ui_"):
		return name.substr(name.find("_") + 1)
	if name.begins_with("w_"):
		return "sword"
	if name.begins_with("gear_helmet"):
		return "helmet"
	if name.begins_with("gear_vest"):
		return "vest"
	if name.begins_with("gear_charm"):
		return "clover"
	if name.begins_with("v_"):
		return "garage"
	if name.begins_with("hero_"):
		return "helmet"
	if name.begins_with("b_"):
		return "build"
	if name.begins_with("chest_"):
		return "chest"
	if name.begins_with("e_"):
		return "slime"
	return "dot"


## Bild aus res://icons/<name>.png; fehlt es, ein gezeichnetes Ersatzzeichen (fallback = Art wie bei icon()).
static func pic(name: String, size := 48.0, fallback := "", col := WHITE) -> Control:
	var t := tex(name)
	if t == null:
		return _drawn(fallback if fallback != "" else _fallback_kind(name), size, col)
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.custom_minimum_size = Vector2(size, size)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func _drawn(kind: String, size: float, col: Color) -> Control:
	var i := Icon.new()
	i.kind = kind
	i.col = col
	i.custom_minimum_size = Vector2(size, size)
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


## Bildzeichen. Nimmt automatisch das Bild res_<kind> bzw. ui_<kind>, wenn vorhanden, sonst die Zeichnung.
## Graue/dunkle Farben dunkeln das Bild ab (gesperrt, leerer Stern); bunte Farben gelten nur für die Zeichnung.
static func icon(kind: String, size := 36.0, col := WHITE) -> Control:
	var name := ""
	if D.RES.has(kind):
		name = "res_" + kind
	elif kind == "slime":
		name = "e_0"
	elif kind != "dot":
		name = "ui_" + kind
	if name != "" and tex(name) != null:
		var r := pic(name, size)
		if col.s < 0.45 and col.v < 0.9:
			r.modulate = Color(col.v * 0.9, col.v * 0.95, minf(1.0, col.v * 1.1))
		return r
	return _drawn(kind, size, col)


## Abgerundete Kachel mit Zeichen (Ersatz für fehlende Gegenstands- und Gebäudebilder).
static func tile(kind: String, size := 64.0, col := NAVY_L) -> Control:
	var p := PanelContainer.new()
	var c := col.darkened(0.35)
	p.add_theme_stylebox_override("panel", grad(c.lightened(0.25), c.darkened(0.2), col.lightened(0.25), int(size * 0.22), 3, int(size * 0.14), 0, Color.BLACK, 0, Color.BLACK, 0.18))
	p.custom_minimum_size = Vector2(size, size)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := icon(kind, size * 0.6, WHITE)
	ic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(ic)
	return p


static func item_pic_name(it: Dictionary) -> String:
	if String(it.get("slot", "")) == "weapon":
		return "w_" + String(it.get("key", ""))
	return "gear_%s_%d" % [String(it.get("slot", "")), int(it.get("rarity", 0))]


## Bild eines Gegenstands (Waffe: w_<key>, Ausrüstung: gear_<slot>_<seltenheit>).
static func item_pic(it: Dictionary, size := 72.0) -> Control:
	var name := item_pic_name(it)
	if tex(name) != null:
		if String(it.get("slot", "")) == "weapon" and D.WEAPONS.has(it.get("key", "")):
			# Waffen: weicher Schein in der Farbe des Helden, dem sie gehört
			var halo := Halo.new()
			halo.col = D.HEROES[D.WEAPONS[it.key].hero].color
			halo.custom_minimum_size = Vector2(size, size)
			halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var p := pic(name, size)
			p.set_anchors_preset(Control.PRESET_FULL_RECT)
			halo.add_child(p)
			return halo
		return pic(name, size)
	var rc: Color = D.RARITY[clampi(int(it.get("rarity", 0)), 0, 3)].color
	return tile(_fallback_kind(name), size, rc)


static func chest_pic(type: String, size := 64.0) -> Control:
	var col := Color("B8742F")
	if D.CHESTS.has(type):
		col = D.CHESTS[type].color
	return pic("chest_" + type, size, "chest", col)


## Gebäudebild (Bunker je nach Ausbaustufe).
static func building_pic(key: String, size := 96.0, level := 1) -> Control:
	var name := "b_" + key
	if key == "bunker":
		name = "b_bunker_%d" % clampi(1 + int((level - 1) / 2), 1, 5)
	if key == "tor":
		name = "b_tor_%d" % clampi(level - 1, 0, 2)
	elif D.BUILDINGS.has(key) and D.BUILDINGS[key].has("prop"):
		name = String(D.BUILDINGS[key].prop)
	if key == "wall" and level > 1 and tex("wall_link_%d" % clampi(level - 1, 0, 2)) != null:
		name = "wall_link_%d" % clampi(level - 1, 0, 2)
	elif key == "wall" and tex(name) == null:
		# Mauer: Bild je nach Ausbau (Holz, Stein, Metall), falls es kein b_wall gibt
		for cand in ["wall_link_%d" % P.wall_tier(), "wall_link_0", "wall_post_0"]:
			if tex(cand) != null:
				name = cand
				break
	if tex(name) != null:
		return pic(name, size)
	var cat := String(D.BUILDINGS[key].cat) if D.BUILDINGS.has(key) else ""
	var kind := "build"
	var col := Color("3C6CB8")
	match cat:
		"def":
			kind = "target"
			col = Color("C0483E")
		"wall":
			kind = "shield"
			col = Color("8A6A3A")
		"trap":
			kind = "alarm"
			col = Color("B46CFF")
		"prod":
			kind = "gear"
			col = Color("3FAE2A")
		"deco":
			kind = "flag"
			col = Color("E08A2E")
		"core":
			kind = "shield"
			col = Color("3C5CA4")
	if D.BUILDINGS.has(key) and D.BUILDINGS[key].has("prod"):
		kind = String(D.BUILDINGS[key].prod)
	return tile(kind, size, col)


static func hero_pic(key: String, size := 72.0) -> Control:
	if tex("hero_" + key) != null:
		return pic("hero_" + key, size)
	var col := Color("3C6CB8")
	if D.HEROES.has(key):
		col = D.HEROES[key].color
	return tile("helmet", size, col)


static func vehicle_pic(key: String, size := 96.0) -> Control:
	if key == "":
		return pic("ui_walk", size)
	if tex("v_" + key) != null:
		return pic("v_" + key, size)
	return tile("garage", size, Color("E08A2E"))


static func enemy_pic(idx: int, size := 48.0) -> Control:
	var def: Dictionary = D.ENEMIES[clampi(idx, 0, D.ENEMIES.size() - 1)]
	# eigenes Symbol der Art (icons/e_<key>.png); sonst das alte Schleim-Symbol bzw. das Ersatzbild der Rolle in Familienfarbe
	if tex("e_" + String(def.key)) != null:
		return pic("e_" + String(def.key), size)
	if idx < D.E_FIRST_NEW:
		return pic("e_%d" % idx, size, "skull" if idx == D.E_BOSS else "slime", RED)
	var p := pic("e_%d" % int(D.ROLE_FALLBACK.get(def.role, 0)), size, "skull" if def.role == "boss" else "slime", RED)
	p.modulate = D.FAMILY_TINT.get(def.family, Color.WHITE)
	return p


## Rohstoff-Symbol + Zahl. check: rot, wenn zu wenig vorhanden ist.
static func res_chip(r: String, amount: int, size := 26, check := false) -> HBoxContainer:
	var h := hbox(int(size * 0.25))
	h.add_child(icon(r, size * 1.35))
	var col := GOLD
	if check and P.res(r) < amount:
		col = RED
	h.add_child(label(fmt(amount), size, col))
	return h


static func cost_row(cost: Dictionary, size := 24, check := true) -> HBoxContainer:
	var h := hbox(int(size * 0.6))
	for r in D.RES:
		if cost.has(r) and int(cost[r]) > 0:
			h.add_child(res_chip(r, int(cost[r]), size, check))
	return h


## Kleine farbige Plakette (Seltenheit, Zähler, "NEU").
static func badge(t: String, col: Color, size := 20) -> PanelContainer:
	var l := label(t, size)
	var p := PanelContainer.new()
	var s := grad(col.lightened(0.18), col.darkened(0.08), col.lightened(0.4), int(size * 0.5), 2)
	s.content_margin_left = size * 0.55
	s.content_margin_right = size * 0.55
	s.content_margin_top = 1
	s.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", s)
	p.add_child(l)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Rotes "NEU"-Schild, das ab und zu wackelt.
static func new_tag(size := 17) -> Control:
	var b := badge("NEU", Color("E8324A"), size)
	wiggle(b)
	return b


## Farbiger Punkt für die Seltenheit.
static func rarity_dot(col: Color, size := 24.0) -> Panel:
	var c := Panel.new()
	c.custom_minimum_size = Vector2(size, size)
	c.add_theme_stylebox_override("panel", grad(col.lightened(0.35), col.darkened(0.1), Color(0.03, 0.08, 0.2, 0.9), int(size * 0.5), 3, 0, 0, Color.BLACK, 0, Color.BLACK, 0.3))
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Punktreihe für Stufen (n von mx), z. B. fünf grüne Punkte.
static func pips(n: int, mx: int, col := GREEN, size := 26.0) -> HBoxContainer:
	var h := hbox(int(maxf(3.0, size * 0.22)))
	for i in mx:
		var c := Panel.new()
		c.custom_minimum_size = Vector2(size, size)
		if i < n:
			c.add_theme_stylebox_override("panel", grad(col.lightened(0.3), col.darkened(0.15), Color("0A2A10") if col == GREEN else col.darkened(0.7), int(size * 0.5), 3, 0, 0, Color.BLACK, 0, Color.BLACK, 0.35))
		else:
			c.add_theme_stylebox_override("panel", box(Color("0A1F45"), Color("31598F"), int(size * 0.5), 3))
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(c)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return h


## Wertzeile: Bild, Name, rechts die goldene Zahl.
static func stat_row(icon_name: String, name: String, value: String, size := 26, vcol := GOLD) -> HBoxContainer:
	var l := label(name, size)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	var h := hbox(int(size * 0.6))
	if icon_name != "":
		h.add_child(pic(icon_name, size * 1.5))
	h.add_child(l)
	h.add_child(label(value, size + 2, vcol))
	return h


## Hinweiskasten mit (i).
static func info_box(t: String, size := 20, icon_name := "ui_info") -> PanelContainer:
	var ic := pic(icon_name, size * 1.9, "", SKY)
	var tx := text(t, size, Color("C5D6EE"))
	tx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return card(hbox(14, [ic, tx]), Color("14356B"), 14)


## Fußzeile "N Stücke | Tipp: …".
static func footer(left: String, tip := "", size := 20) -> HBoxContainer:
	var h := hbox(14)
	h.add_child(label(left, size, WHITE))
	if tip != "":
		var bar_ := ColorRect.new()
		bar_.color = Color(1, 1, 1, 0.35)
		bar_.custom_minimum_size = Vector2(2, size)
		bar_.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(bar_)
		h.add_child(label("Tipp:", size, WHITE))
		var t := label(tip, size, Color("B9CBE6"), false)
		t.clip_text = true
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
	return h


## Sockel: großes Bild auf einer runden blauen Scheibe; das Bild schwebt sanft auf und ab.
static func pedestal(picture: Control, size := 260.0) -> Control:
	var p := Pedestal.new()
	p.custom_minimum_size = Vector2(size, size)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_picture(picture)
	return p


## Abgerundeter Bilderrahmen: inner wird auf die runde Form beschnitten, darüber liegt der Rand.
## bg: z. B. UI.scenery("water") als Hintergrund hinter dem Inhalt.
static func frame(inner: Control, bg: Control = null, radius := 22, border := EDGE) -> Control:
	var clip := PanelContainer.new()
	clip.add_theme_stylebox_override("panel", box(Color("0B2148"), Color(0, 0, 0, 0), radius))
	clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	if bg:
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.add_child(bg)
	if inner:
		clip.add_child(inner)
	var rim := Panel.new()
	var rs := StyleBoxFlat.new()
	rs.draw_center = false
	rs.set_corner_radius_all(radius)
	rs.set_border_width_all(4)
	rs.border_color = border
	rs.anti_aliasing = true
	rs.shadow_size = 8
	rs.shadow_color = Color(border.r, border.g, border.b, 0.25)
	rim.add_theme_stylebox_override("panel", rs)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hold := PanelContainer.new()
	hold.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	hold.add_child(clip)
	hold.add_child(rim)
	return hold


## Gemalte Kulisse (Himmel, Hügel, Wasser/Wiese/Sand/Schnee) als Hintergrund für Vorschaubilder.
static func scenery(kind := "meadow") -> Control:
	var s := Scenery.new()
	s.kind = kind
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


static func fmt(n: float) -> String:
	var a := absf(n)
	if a >= 1000000.0:
		return "%.1f Mio" % (n / 1000000.0)
	if a >= 10000.0:
		return "%.1fk" % (n / 1000.0)
	return str(int(n))


static func time_text(sec: float) -> String:
	var s := int(maxf(0.0, ceil(sec)))
	if s >= 86400:
		return "%d T %d Std" % [int(s / 86400), int((s % 86400) / 3600)]
	if s >= 3600:
		return "%d Std %d Min" % [int(s / 3600), int((s % 3600) / 60)]
	if s >= 60:
		return "%d Min %d s" % [int(s / 60), s % 60]
	return "%d s" % s


static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


# ================================================================= Bewegung (nur kurze Tweens)
## Fenster springt auf: leicht vergrößern und einblenden.
static func pop_in(c: Control, from := 0.92, dur := 0.16) -> void:
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_method(func(k: float):
		c.pivot_offset = c.size * 0.5
		c.scale = Vector2.ONE * lerpf(from, 1.0, k)
		c.modulate.a = minf(1.0, k * 1.6), 0.0, 1.0, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		c.scale = Vector2.ONE
		c.modulate.a = 1.0)


## Knopf gibt beim Drücken leicht nach.
static func squash(b: BaseButton) -> void:
	b.button_down.connect(func():
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.965, 0.94), 0.06))
	b.button_up.connect(func():
		b.pivot_offset = b.size * 0.5
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


## Einmal kurz aufpumpen (frisch ausgewählte Zeile, Belohnung).
static func pulse(c: Control, amount := 1.05, delay := 0.0) -> void:
	var tw := c.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(func(): c.pivot_offset = c.size * 0.5)
	tw.tween_property(c, "scale", Vector2.ONE * amount, 0.09).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Wackelt alle paar Sekunden kurz (Schild "NEU").
static func wiggle(c: Control) -> void:
	var tw := c.create_tween().set_loops()
	tw.tween_interval(1.6 + randf() * 1.2)
	tw.tween_callback(func(): c.pivot_offset = c.size * 0.5)
	tw.tween_property(c, "rotation", 0.14, 0.07)
	tw.tween_property(c, "rotation", -0.12, 0.1)
	tw.tween_property(c, "rotation", 0.08, 0.08)
	tw.tween_property(c, "rotation", 0.0, 0.08)


## Zahl zählt hoch (Belohnungen). text_fn: func(wert: int) -> String, sonst UI.fmt.
static func count_up(l: Label, to: float, dur := 0.7, text_fn := Callable(), delay := 0.0) -> void:
	var show := func(v: float):
		l.text = String(text_fn.call(int(round(v)))) if text_fn.is_valid() else fmt(round(v))
	show.call(0.0)
	var tw := l.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(show, 0.0, to, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Sanft einblenden und von unten hereinrutschen (Listen, Karten).
static func fade_in(c: Control, delay := 0.0, dur := 0.18) -> void:
	c.modulate.a = 0.0
	var tw := c.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(c, "modulate:a", 1.0, dur)


# ================================================================= Sockel
class Pedestal extends Control:
	var picture: Control
	var bob := 0.0:
		set(v):
			bob = v
			_place()
	var glow := Color("4AB0FF")

	func set_picture(p: Control) -> void:
		picture = p
		p.set_anchors_preset(Control.PRESET_TOP_LEFT)
		p.size_flags_vertical = 0
		add_child(p)
		resized.connect(_place)
		_place()
		var tw := create_tween().set_loops()
		tw.tween_property(self, "bob", 1.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(self, "bob", 0.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	func _place() -> void:
		if picture == null or not is_instance_valid(picture):
			return
		var s := minf(size.x, size.y)
		var ps := s * 0.92
		picture.custom_minimum_size = Vector2.ZERO
		picture.size = Vector2(ps, ps)
		picture.position = Vector2((size.x - ps) * 0.5, (size.y - s) * 0.5 - s * 0.01 - bob * s * 0.03)

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var c := Vector2(size.x * 0.5, (size.y - s) * 0.5 + s * 0.83)
		var rx := s * 0.37
		var ry := s * 0.115
		# Schein, Sockelwand, Deckel
		_ell(c + Vector2(0, s * 0.03), rx * 1.18, ry * 1.25, Color(glow.r, glow.g, glow.b, 0.12))
		_ell(c + Vector2(0, s * 0.055), rx, ry, Color("0C2A5E"))
		draw_rect(Rect2(c.x - rx, c.y, rx * 2.0, s * 0.055), Color("123C82"))
		_ell(c + Vector2(0, s * 0.055), rx, ry, Color("123C82"))
		_ell(c, rx, ry, Color("3F8AE6"))
		_ell(c, rx * 0.93, ry * 0.9, Color("2466C2"))
		_ell(c + Vector2(0, ry * 0.12), rx * 0.7, ry * 0.62, Color("1A52A6"))

	func _ell(c: Vector2, rx: float, ry: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 40:
			var a := TAU * i / 40.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		draw_colored_polygon(pts, col)


# ================================================================= Kulisse
class Scenery extends Control:
	var kind := "meadow"

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _grad(r: Rect2, c0: Color, c1: Color) -> void:
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), PackedColorArray([c0, c0, c1, c1]))

	func _blob(c: Vector2, rx: float, ry: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 21:
			var a := PI + PI * i / 20.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		draw_colored_polygon(pts, col)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w < 4.0 or h < 4.0:
			return
		var hz := h * 0.5
		var sky0 := Color("3E9BEA")
		var sky1 := Color("BFE6FF")
		var g0 := Color("8FCB3A")
		var g1 := Color("5E9A2C")
		var hill := Color("4E9A4A")
		var hill2 := Color("6FB85A")
		match kind:
			"water":
				g0 = Color("59C7F2")
				g1 = Color("1F7FD0")
			"sand":
				sky0 = Color("5AA9E8")
				sky1 = Color("FFE9C0")
				g0 = Color("F0CC82")
				g1 = Color("CF9E55")
				hill = Color("C98F55")
				hill2 = Color("E0AE6C")
			"snow":
				sky0 = Color("6FA8E0")
				sky1 = Color("E6F3FF")
				g0 = Color("F2F8FF")
				g1 = Color("B9D2EC")
				hill = Color("9DBADB")
				hill2 = Color("D5E6F6")
			"forest":
				sky0 = Color("3F86C8")
				sky1 = Color("B9E0D0")
				g0 = Color("5F9A3C")
				g1 = Color("3A6B30")
				hill = Color("2F6A3A")
				hill2 = Color("3F8246")
			"swamp":
				sky0 = Color("4F8F8A")
				sky1 = Color("C6E0B0")
				g0 = Color("7C9A4E")
				g1 = Color("4C6A38")
				hill = Color("47704A")
				hill2 = Color("5F8A58")
			"crater":
				sky0 = Color("3A8A7A")
				sky1 = Color("D8FFB0")
				g0 = Color("9ADB45")
				g1 = Color("4E9A2A")
				hill = Color("3F8A3A")
				hill2 = Color("6FC04A")
			"night":
				sky0 = Color("14306A")
				sky1 = Color("3F7FD0")
				g0 = Color("2A5FA8")
				g1 = Color("143A78")
				hill = Color("1C4A8C")
				hill2 = Color("2A5FA8")
		_grad(Rect2(0, 0, w, hz + 2.0), sky0, sky1)
		# Wolken
		for cl in [[0.2, 0.2, 0.11], [0.62, 0.13, 0.08], [0.86, 0.27, 0.1]]:
			var cc := Vector2(w * cl[0], h * cl[1])
			var cr: float = w * cl[2]
			_blob(cc, cr, cr * 0.34, Color(1, 1, 1, 0.5))
			_blob(cc + Vector2(cr * 0.5, cr * 0.05), cr * 0.6, cr * 0.24, Color(1, 1, 1, 0.5))
		# ferne Hügel / Inseln
		_blob(Vector2(w * 0.16, hz), w * 0.2, h * 0.16, hill)
		_blob(Vector2(w * 0.8, hz), w * 0.26, h * 0.22, hill)
		_blob(Vector2(w * 0.9, hz), w * 0.16, h * 0.13, hill2)
		_blob(Vector2(w * 0.3, hz), w * 0.12, h * 0.08, hill2)
		_grad(Rect2(0, hz, w, h - hz), g0, g1)
		if kind == "water":
			for i in 7:
				var y := hz + (h - hz) * (0.12 + 0.13 * i)
				var x := w * fposmod(0.13 + i * 0.37, 1.0)
				var len := w * (0.1 + 0.03 * (i % 3))
				draw_line(Vector2(x, y), Vector2(x + len, y), Color(1, 1, 1, 0.3), maxf(2.0, h * 0.012), true)
				draw_line(Vector2(x - w * 0.45, y + h * 0.03), Vector2(x - w * 0.45 + len * 0.7, y + h * 0.03), Color(1, 1, 1, 0.2), maxf(2.0, h * 0.01), true)
		else:
			# weicher Schatten unter dem Fahrzeug / Helden
			var pts := PackedVector2Array()
			for i in 32:
				var a := TAU * i / 32.0
				pts.append(Vector2(w * 0.5 + cos(a) * w * 0.3, h * 0.8 + sin(a) * h * 0.09))
			draw_colored_polygon(pts, Color(0, 0, 0, 0.14))
		# heller Streifen am Horizont
		draw_line(Vector2(0, hz), Vector2(w, hz), Color(1, 1, 1, 0.25), 2.0)


# ================================================================= gezeichnete Symbole (Ersatz)
class Icon extends Control:
	var kind := "coins"
	var col := Color.WHITE

	func _p(c: Vector2, r: float, a: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in range(0, a.size(), 2):
			out.append(c + Vector2(a[i], a[i + 1]) * r)
		return out

	func _ring(c: Vector2, r: float, w: float, colr: Color) -> void:
		draw_arc(c, r, 0.0, TAU, 32, colr, w, true)

	func _rr(rect: Rect2, colr: Color, rad: float) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = colr
		sb.set_corner_radius_all(int(rad))
		sb.anti_aliasing = true
		draw_style_box(sb, rect)

	func _gear(c: Vector2, r: float, colr: Color, hole: Color) -> void:
		for i in 8:
			var a := TAU * i / 8.0
			draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.74, r * 0.2, colr)
		draw_circle(c, r * 0.7, colr)
		draw_circle(c, r * 0.3, hole)

	func _star(c: Vector2, r: float, colr: Color) -> void:
		var pts := PackedVector2Array()
		for i in 10:
			var a2 := -PI * 0.5 + TAU * i / 10.0
			pts.append(c + Vector2(cos(a2), sin(a2)) * r * (0.95 if i % 2 == 0 else 0.44))
		draw_colored_polygon(pts, colr)

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var c := size * 0.5
		var r := s * 0.5
		var dk := Color("081526")
		match kind:
			"coins":
				draw_circle(c, r * 0.95, Color("B87A0C"))
				draw_circle(c, r * 0.82, Color("FDCA14"))
				draw_circle(c, r * 0.6, Color("F0AE0A"))
				draw_circle(c - Vector2(r * 0.12, r * 0.12), r * 0.5, Color("FFE56A"))
			"wood":
				draw_set_transform(c, -0.5, Vector2.ONE)
				draw_rect(Rect2(-r * 0.9, -r * 0.38, r * 1.8, r * 0.76), Color("8A4F22"))
				draw_rect(Rect2(-r * 0.9, -r * 0.38, r * 1.8, r * 0.3), Color("B8742F"))
				draw_circle(Vector2(r * 0.9, 0), r * 0.38, Color("E2B36F"))
				draw_circle(Vector2(r * 0.9, 0), r * 0.16, Color("B8742F"))
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			"stone":
				draw_colored_polygon(_p(c, r, [-0.9, 0.5, -0.6, -0.5, 0.1, -0.8, 0.85, -0.2, 0.9, 0.6, 0.0, 0.8]), Color("7C84A0"))
				draw_colored_polygon(_p(c, r, [-0.6, -0.5, 0.1, -0.8, 0.85, -0.2, 0.0, 0.0]), Color("C3C9DE"))
			"metal":
				draw_colored_polygon(_p(c, r, [-0.9, 0.55, -0.55, -0.45, 0.55, -0.45, 0.9, 0.55]), Color("4F6FA6"))
				draw_colored_polygon(_p(c, r, [-0.55, -0.45, 0.55, -0.45, 0.4, -0.1, -0.4, -0.1]), Color("A9C2EA"))
			"fuel":
				_rr(Rect2(c.x - r * 0.6, c.y - r * 0.55, r * 1.2, r * 1.4), Color("B92A2A"), r * 0.15)
				draw_rect(Rect2(c.x - r * 0.6, c.y - r * 0.4, r * 0.4, r * 1.1), Color("E0473C"))
				draw_rect(Rect2(c.x + r * 0.05, c.y - r * 0.9, r * 0.45, r * 0.38), Color("23262E"))
				draw_rect(Rect2(c.x - r * 0.3, c.y - r * 0.05, r * 0.6, r * 0.4), Color("FFD23E"))
			"cells":
				_rr(Rect2(c.x - r * 0.45, c.y - r * 0.7, r * 0.9, r * 1.55), Color("243248"), r * 0.15)
				draw_rect(Rect2(c.x - r * 0.2, c.y - r * 0.92, r * 0.4, r * 0.25), Color("9FB3CC"))
				draw_rect(Rect2(c.x - r * 0.3, c.y - r * 0.3, r * 0.6, r * 1.0), Color("3FD2F5"))
			"parts":
				_gear(c, r, Color("C9CED8"), Color("26365A"))
			"gear":
				_gear(c, r, col, Color("1B3260"))
			"shards":
				_star(c, r, Color("C99A12"))
				_star(c, r * 0.8, Color("FFE98A"))
			"star":
				_star(c, r, col.darkened(0.3))
				_star(c, r * 0.8, col)
			"heart":
				var hc := col if col != Color.WHITE else Color("FF4D62")
				draw_circle(c + Vector2(-r * 0.38, -r * 0.2), r * 0.46, hc)
				draw_circle(c + Vector2(r * 0.38, -r * 0.2), r * 0.46, hc)
				draw_colored_polygon(_p(c, r, [-0.8, 0.0, 0.8, 0.0, 0.0, 0.9]), hc)
				draw_circle(c + Vector2(-r * 0.42, -r * 0.3), r * 0.14, Color(1, 1, 1, 0.45))
			"skull":
				draw_circle(c + Vector2(0, -r * 0.15), r * 0.72, col)
				_rr(Rect2(c.x - r * 0.4, c.y + r * 0.3, r * 0.8, r * 0.45), col, r * 0.1)
				draw_circle(c + Vector2(-r * 0.28, -r * 0.1), r * 0.2, dk)
				draw_circle(c + Vector2(r * 0.28, -r * 0.1), r * 0.2, dk)
			"slime", "flood":
				draw_circle(c + Vector2(0, r * 0.15), r * 0.8, Color("94B128"))
				draw_circle(c + Vector2(-r * 0.15, -r * 0.05), r * 0.5, Color("C4DB45"))
				draw_circle(c + Vector2(-r * 0.25, r * 0.1), r * 0.14, dk)
				draw_circle(c + Vector2(r * 0.25, r * 0.1), r * 0.14, dk)
			"clock":
				draw_circle(c, r * 0.92, col.darkened(0.25))
				draw_circle(c, r * 0.74, Color("F4F8FF") if col == Color.WHITE else dk)
				var hand := Color("1B3260") if col == Color.WHITE else col
				draw_line(c, c + Vector2(0, -r * 0.5), hand, r * 0.16, true)
				draw_line(c, c + Vector2(r * 0.35, 0), hand, r * 0.16, true)
			"lock":
				var lc := col if col != Color.WHITE else Color("FFD23E")
				draw_arc(c + Vector2(0, -r * 0.2), r * 0.42, PI, TAU, 16, lc.darkened(0.2), r * 0.22, true)
				_rr(Rect2(c.x - r * 0.62, c.y - r * 0.15, r * 1.24, r * 0.98), lc, r * 0.18)
				draw_circle(c + Vector2(0, r * 0.3), r * 0.15, dk)
			"chest":
				var cc := col if col != Color.WHITE else Color("B8742F")
				_rr(Rect2(c.x - r * 0.88, c.y - r * 0.62, r * 1.76, r * 1.34), cc.darkened(0.35), r * 0.2)
				_rr(Rect2(c.x - r * 0.8, c.y - r * 0.56, r * 1.6, r * 0.5), cc.lightened(0.15), r * 0.14)
				draw_rect(Rect2(c.x - r * 0.8, c.y + r * 0.02, r * 1.6, r * 0.62), cc)
				draw_rect(Rect2(c.x - r * 0.88, c.y - r * 0.1, r * 1.76, r * 0.14), Color("FFD23E"))
				_rr(Rect2(c.x - r * 0.17, c.y - r * 0.24, r * 0.34, r * 0.44), Color("FFE98A"), r * 0.08)
			"shield", "body", "clan":
				var sc := col if col != Color.WHITE else Color("4A9BF0")
				draw_colored_polygon(_p(c, r, [-0.78, -0.72, 0.78, -0.72, 0.78, 0.1, 0.0, 0.92, -0.78, 0.1]), sc.darkened(0.3))
				draw_colored_polygon(_p(c, r, [-0.6, -0.56, 0.6, -0.56, 0.6, 0.05, 0.0, 0.7, -0.6, 0.05]), sc)
				draw_colored_polygon(_p(c, r, [-0.6, -0.56, 0.0, -0.56, 0.0, 0.7, -0.6, 0.05]), sc.lightened(0.2))
			"bolt":
				var bc := col if col != Color.WHITE else Color("FFD23E")
				draw_colored_polygon(_p(c, r, [0.2, -0.95, -0.55, 0.1, -0.05, 0.1, -0.2, 0.95, 0.55, -0.15, 0.05, -0.15]), bc)
			"drone":
				_rr(Rect2(c.x - r * 0.4, c.y - r * 0.2, r * 0.8, r * 0.55), col, r * 0.15)
				draw_line(c + Vector2(-r * 0.9, -r * 0.4), c + Vector2(r * 0.9, -r * 0.4), col, r * 0.14, true)
				draw_line(c + Vector2(-r * 0.55, -r * 0.4), c + Vector2(-r * 0.3, -r * 0.15), col, r * 0.1, true)
				draw_line(c + Vector2(r * 0.55, -r * 0.4), c + Vector2(r * 0.3, -r * 0.15), col, r * 0.1, true)
				draw_circle(c + Vector2(0, r * 0.08), r * 0.13, Color("FB3D54"))
			"badge":
				draw_colored_polygon(_p(c, r, [-0.45, 0.2, -0.6, 0.95, 0.0, 0.6, 0.6, 0.95, 0.45, 0.2]), Color("E0473C"))
				draw_circle(c + Vector2(0, -r * 0.15), r * 0.75, Color("8A4FD6"))
				draw_circle(c + Vector2(0, -r * 0.15), r * 0.52, Color("D9B8FF"))
				_star(c + Vector2(0, -r * 0.15), r * 0.36, Color("8A4FD6"))
			"pack", "vest":
				var pc := Color("8A6A3A") if kind == "pack" else Color("5C8A3A")
				_rr(Rect2(c.x - r * 0.62, c.y - r * 0.5, r * 1.24, r * 1.35), pc, r * 0.25)
				_rr(Rect2(c.x - r * 0.42, c.y + r * 0.05, r * 0.84, r * 0.5), pc.lightened(0.25), r * 0.1)
				draw_arc(c + Vector2(0, -r * 0.5), r * 0.3, PI, TAU, 12, pc.darkened(0.2), r * 0.16, true)
			"up":
				var uc := col if col != Color.WHITE else Color("6FE03A")
				draw_colored_polygon(_p(c, r, [0.0, -0.9, 0.8, 0.0, 0.3, 0.0, 0.3, 0.85, -0.3, 0.85, -0.3, 0.0, -0.8, 0.0]), uc)
			"speed":
				draw_arc(c + Vector2(0, r * 0.25), r * 0.8, PI, TAU, 24, Color("FFD23E"), r * 0.26, true)
				draw_arc(c + Vector2(0, r * 0.25), r * 0.8, PI * 1.7, TAU, 12, Color("FB3D54"), r * 0.26, true)
				draw_line(c + Vector2(0, r * 0.25), c + Vector2(r * 0.42, -r * 0.3), Color.WHITE, r * 0.14, true)
				draw_circle(c + Vector2(0, r * 0.25), r * 0.16, Color.WHITE)
			"crate", "bed":
				_rr(Rect2(c.x - r * 0.8, c.y - r * 0.75, r * 1.6, r * 1.55), Color("8A4F22"), r * 0.12)
				draw_rect(Rect2(c.x - r * 0.62, c.y - r * 0.57, r * 1.24, r * 1.19), Color("D08A3E"))
				draw_line(c + Vector2(-r * 0.6, -r * 0.55), c + Vector2(r * 0.6, r * 0.6), Color("8A4F22"), r * 0.16, true)
				draw_line(c + Vector2(r * 0.6, -r * 0.55), c + Vector2(-r * 0.6, r * 0.6), Color("8A4F22"), r * 0.16, true)
			"water":
				for i in 3:
					var y := c.y - r * 0.45 + i * r * 0.45
					var pts := PackedVector2Array()
					for k in 13:
						pts.append(Vector2(c.x - r * 0.85 + r * 1.7 * k / 12.0, y + sin(k * PI / 3.0) * r * 0.12))
					draw_polyline(pts, Color("4AB0FF"), r * 0.16, true)
			"hammer", "build":
				draw_line(c + Vector2(-r * 0.55, r * 0.7), c + Vector2(r * 0.2, -r * 0.2), Color("B8742F"), r * 0.24, true)
				draw_set_transform(c + Vector2(r * 0.22, -r * 0.3), -0.8, Vector2.ONE)
				_rr(Rect2(-r * 0.3, -r * 0.55, r * 0.6, r * 1.1), Color("C9D2E2") if col == Color.WHITE else col, r * 0.1)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			"wrench":
				draw_line(c + Vector2(-r * 0.6, r * 0.6), c + Vector2(r * 0.3, -r * 0.3), col.darkened(0.15), r * 0.28, true)
				draw_circle(c + Vector2(r * 0.42, -r * 0.42), r * 0.42, col.darkened(0.15))
				draw_circle(c + Vector2(r * 0.6, -r * 0.6), r * 0.22, Color("1B3260"))
				draw_circle(c + Vector2(-r * 0.6, r * 0.6), r * 0.2, col.darkened(0.15))
			"sword":
				draw_line(c + Vector2(-r * 0.4, r * 0.4), c + Vector2(r * 0.75, -r * 0.75), col, r * 0.24, true)
				draw_line(c + Vector2(-r * 0.7, r * 0.15), c + Vector2(-r * 0.15, r * 0.7), Color("FFD23E"), r * 0.2, true)
				draw_line(c + Vector2(-r * 0.45, r * 0.45), c + Vector2(-r * 0.8, r * 0.8), Color("B8742F"), r * 0.22, true)
			"helmet":
				var hc2 := col if col != Color.WHITE else Color("B4BCC8")
				draw_arc(c + Vector2(0, r * 0.1), r * 0.5, PI, TAU, 20, hc2, r * 0.75, true)
				_rr(Rect2(c.x - r * 0.95, c.y + r * 0.1, r * 1.9, r * 0.3), hc2.darkened(0.2), r * 0.12)
			"clover":
				for a in [0.0, PI * 0.5, PI, PI * 1.5]:
					draw_circle(c + Vector2(cos(a + 0.78), sin(a + 0.78)) * r * 0.42 + Vector2(0, -r * 0.1), r * 0.38, Color("3FCB3A"))
				draw_line(c + Vector2(0, r * 0.1), c + Vector2(r * 0.25, r * 0.9), Color("2E8A22"), r * 0.14, true)
			"grid":
				var gc := col if col != Color.WHITE else Color("7A4A12")
				for gy in 2:
					for gx in 2:
						_rr(Rect2(c.x - r * 0.75 + gx * r * 0.82, c.y - r * 0.75 + gy * r * 0.82, r * 0.68, r * 0.68), gc, r * 0.14)
			"recycle":
				for i in 3:
					var a0 := TAU * i / 3.0 - PI * 0.5
					draw_arc(c, r * 0.62, a0 + 0.25, a0 + TAU / 3.0 - 0.35, 10, col, r * 0.22, true)
					var tip := c + Vector2(cos(a0 + TAU / 3.0 - 0.1), sin(a0 + TAU / 3.0 - 0.1)) * r * 0.62
					draw_circle(tip, r * 0.2, col)
			"merge":
				draw_circle(c + Vector2(-r * 0.4, -r * 0.35), r * 0.3, col)
				draw_circle(c + Vector2(r * 0.4, -r * 0.35), r * 0.3, col)
				draw_circle(c + Vector2(0, r * 0.45), r * 0.42, Color("FFD23E"))
				draw_line(c + Vector2(-r * 0.4, -r * 0.35), c + Vector2(0, r * 0.4), col, r * 0.12, true)
				draw_line(c + Vector2(r * 0.4, -r * 0.35), c + Vector2(0, r * 0.4), col, r * 0.12, true)
			"info":
				var ic := col if col != Color.WHITE else Color("4AB0FF")
				draw_circle(c, r * 0.9, ic)
				draw_circle(c, r * 0.72, Color("12305F"))
				draw_circle(c + Vector2(0, -r * 0.38), r * 0.12, ic)
				draw_line(c + Vector2(0, -r * 0.12), c + Vector2(0, r * 0.45), ic, r * 0.2, true)
			"check":
				draw_circle(c, r * 0.9, col.darkened(0.1))
				draw_polyline(_p(c, r, [-0.42, 0.02, -0.12, 0.34, 0.45, -0.32]), Color("12305F"), r * 0.22, true)
			"close":
				draw_line(c + Vector2(-r * 0.6, -r * 0.6), c + Vector2(r * 0.6, r * 0.6), col, r * 0.34, true)
				draw_line(c + Vector2(r * 0.6, -r * 0.6), c + Vector2(-r * 0.6, r * 0.6), col, r * 0.34, true)
			"flag":
				draw_line(c + Vector2(-r * 0.55, -r * 0.85), c + Vector2(-r * 0.55, r * 0.9), Color("C9D2E2"), r * 0.16, true)
				draw_colored_polygon(_p(c, r, [-0.5, -0.8, 0.8, -0.5, -0.5, -0.05]), Color("FB3D54") if col == Color.WHITE else col)
			"map", "expedition":
				draw_colored_polygon(_p(c, r, [-0.9, -0.6, -0.3, -0.8, 0.3, -0.6, 0.9, -0.8, 0.9, 0.6, 0.3, 0.8, -0.3, 0.6, -0.9, 0.8]), Color("F0DCA0"))
				draw_colored_polygon(_p(c, r, [-0.3, -0.8, 0.3, -0.6, 0.3, 0.8, -0.3, 0.6]), Color("D9C07A"))
				draw_circle(c + Vector2(r * 0.5, -r * 0.1), r * 0.18, Color("FB3D54"))
				draw_line(c + Vector2(-r * 0.6, r * 0.3), c + Vector2(-r * 0.1, -r * 0.1), Color("8A6A3A"), r * 0.08, true)
			"trophy":
				draw_arc(c + Vector2(0, -r * 0.3), r * 0.62, 0.2, PI - 0.2, 10, Color("C99A12"), r * 0.14, true)
				draw_colored_polygon(_p(c, r, [-0.5, -0.8, 0.5, -0.8, 0.35, 0.1, -0.35, 0.1]), Color("FFD23E"))
				draw_rect(Rect2(c.x - r * 0.1, c.y + r * 0.1, r * 0.2, r * 0.4), Color("C99A12"))
				_rr(Rect2(c.x - r * 0.45, c.y + r * 0.5, r * 0.9, r * 0.3), Color("C99A12"), r * 0.08)
			"mail":
				_rr(Rect2(c.x - r * 0.9, c.y - r * 0.6, r * 1.8, r * 1.2), Color("F4F0E0"), r * 0.14)
				draw_polyline(_p(c, r, [-0.85, -0.5, 0.0, 0.15, 0.85, -0.5]), Color("C9A96A"), r * 0.12, true)
			"friends":
				draw_circle(c + Vector2(-r * 0.35, -r * 0.35), r * 0.3, Color("4AB0FF"))
				draw_arc(c + Vector2(-r * 0.35, r * 0.75), r * 0.3, PI, TAU, 12, Color("4AB0FF"), r * 0.55, true)
				draw_circle(c + Vector2(r * 0.4, -r * 0.2), r * 0.26, Color("6FE03A"))
				draw_arc(c + Vector2(r * 0.4, r * 0.8), r * 0.26, PI, TAU, 12, Color("6FE03A"), r * 0.48, true)
			"quest":
				_rr(Rect2(c.x - r * 0.65, c.y - r * 0.8, r * 1.3, r * 1.7), Color("F4F0E0"), r * 0.12)
				_rr(Rect2(c.x - r * 0.3, c.y - r * 0.95, r * 0.6, r * 0.3), Color("8A6A3A"), r * 0.08)
				for i in 3:
					draw_line(c + Vector2(-r * 0.4, -r * 0.35 + i * r * 0.38), c + Vector2(r * 0.4, -r * 0.35 + i * r * 0.38), Color("8A9AB0"), r * 0.1)
			"target":
				draw_circle(c, r * 0.9, Color("F4F8FF"))
				draw_circle(c, r * 0.68, Color("FB3D54"))
				draw_circle(c, r * 0.44, Color("F4F8FF"))
				draw_circle(c, r * 0.2, Color("FB3D54"))
			"boot":
				draw_colored_polygon(_p(c, r, [-0.5, -0.85, 0.1, -0.85, 0.15, 0.1, 0.85, 0.35, 0.85, 0.75, -0.5, 0.75]), Color("8A4F22") if col == Color.WHITE else col)
				draw_rect(Rect2(c.x - r * 0.55, c.y + r * 0.62, r * 1.45, r * 0.2), Color("3A2A1A"))
			"fire":
				draw_colored_polygon(_p(c, r, [0.0, -0.95, 0.65, 0.05, 0.5, 0.65, 0.0, 0.9, -0.5, 0.65, -0.65, 0.05, -0.25, -0.3]), Color("FB6A2C"))
				draw_colored_polygon(_p(c, r, [0.0, -0.3, 0.35, 0.3, 0.2, 0.7, 0.0, 0.8, -0.2, 0.7, -0.35, 0.3]), Color("FFD23E"))
			"snow":
				for i in 3:
					var a3 := PI * i / 3.0
					draw_line(c - Vector2(cos(a3), sin(a3)) * r * 0.85, c + Vector2(cos(a3), sin(a3)) * r * 0.85, Color("BFE6FF"), r * 0.16, true)
			"walk":
				var wc := col if col != Color.WHITE else Color("FFA12E")
				draw_circle(c + Vector2(0, -r * 0.68), r * 0.24, wc)
				draw_line(c + Vector2(0, -r * 0.4), c + Vector2(0, r * 0.2), wc, r * 0.3, true)
				draw_line(c + Vector2(0, r * 0.2), c + Vector2(-r * 0.3, r * 0.85), wc, r * 0.2, true)
				draw_line(c + Vector2(0, r * 0.2), c + Vector2(r * 0.35, r * 0.8), wc, r * 0.2, true)
				draw_line(c + Vector2(0, -r * 0.25), c + Vector2(-r * 0.4, r * 0.1), wc, r * 0.16, true)
				draw_line(c + Vector2(0, -r * 0.25), c + Vector2(r * 0.4, 0.0), wc, r * 0.16, true)
			"garage":
				_rr(Rect2(c.x - r * 0.85, c.y - r * 0.2, r * 1.7, r * 0.6), Color("F59A2E") if col == Color.WHITE else col, r * 0.18)
				_rr(Rect2(c.x - r * 0.45, c.y - r * 0.6, r * 0.9, r * 0.5), Color("FFC46A"), r * 0.14)
				draw_circle(c + Vector2(-r * 0.48, r * 0.45), r * 0.26, Color("23262E"))
				draw_circle(c + Vector2(r * 0.48, r * 0.45), r * 0.26, Color("23262E"))
			"alarm":
				draw_arc(c + Vector2(0, r * 0.05), r * 0.38, PI, TAU, 16, Color("FFD23E"), r * 0.78, true)
				_rr(Rect2(c.x - r * 0.8, c.y + r * 0.2, r * 1.6, r * 0.26), Color("C99A12"), r * 0.1)
				draw_circle(c + Vector2(0, r * 0.68), r * 0.18, Color("C99A12"))
			"pause":
				_rr(Rect2(c.x - r * 0.6, c.y - r * 0.7, r * 0.45, r * 1.4), col, r * 0.12)
				_rr(Rect2(c.x + r * 0.15, c.y - r * 0.7, r * 0.45, r * 1.4), col, r * 0.12)
			"play":
				draw_colored_polygon(_p(c, r, [-0.5, -0.8, 0.8, 0.0, -0.5, 0.8]), col)
			"motor":
				_rr(Rect2(c.x - r * 0.75, c.y - r * 0.45, r * 1.5, r * 1.1), Color("8E99AE"), r * 0.15)
				_rr(Rect2(c.x - r * 0.5, c.y - r * 0.8, r * 1.0, r * 0.4), Color("E0473C"), r * 0.1)
				draw_circle(c + Vector2(0, r * 0.1), r * 0.3, Color("3A4660"))
			_:
				draw_circle(c, r * 0.85, col.darkened(0.25))
				draw_circle(c, r * 0.68, col)


## Weicher farbiger Schein hinter einem Bild (Heldenfarbe hinter Waffen).
class Halo extends Control:
	var col := Color.WHITE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		for i in 6:
			var k := 1.0 - float(i) / 6.0
			draw_circle(c, r * (0.55 + 0.45 * k), Color(col.r, col.g, col.b, 0.05 + 0.05 * (1.0 - k)))
