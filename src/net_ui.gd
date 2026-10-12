extends RefCounted
## Dialoge der Online-Anbindung (Paket O): Einwilligung beim ersten Start, Rückfrage bei Speicher-Konflikt.
## Liegen auf einer eigenen Ebene (CanvasLayer 50) über allen Menüs.

const UI = preload("res://src/ui.gd")
const Legal = preload("res://src/legal_texts.gd")

var net: Node
var _layer: CanvasLayer
var _box: Control


func _init(n: Node) -> void:
	net = n


func is_open() -> bool:
	return _layer != null and is_instance_valid(_layer)


func close() -> void:
	if is_open():
		_layer.queue_free()
	_layer = null
	_box = null


## Grundgerüst: abgedunkelter Hintergrund, Tafel in der Mitte.
func _open(min_w := 900.0) -> VBoxContainer:
	close()
	_layer = CanvasLayer.new()
	_layer.layer = 50
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	net.get_tree().root.add_child(_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cc)
	var v := UI.vbox(18)
	v.custom_minimum_size = Vector2(min_w, 0)
	var p := UI.panel(v, UI.NAVY, UI.GOLD, 26, 30)
	cc.add_child(p)
	_box = v
	UI.pop_in(p, 0.92, 0.18)
	return v


# ================================================================= Einwilligung (erster Start)
## Zeigt den Einwilligungs-Dialog, sobald das Spiel läuft – nur wenn noch nie gefragt wurde.
func consent_when_ready() -> void:
	if int(net.cfg.consent) != -1:
		return
	for i in 600:
		await net.get_tree().process_frame
		if G.main != null and i > 30:
			break
	if G.main == null or int(net.cfg.consent) != -1:
		return
	show_consent()


func show_consent(step := 0) -> void:
	var v := _open(940.0)
	v.add_child(UI.hbox(14, [UI.pic("ui_shield", 56.0), UI.label("Willkommen bei Rustwall!", 36, UI.GOLD)]))
	if step == 0:
		v.add_child(UI.text("Bevor es losgeht, eine kurze Frage, damit wir die richtigen Einstellungen wählen:", 25, UI.TEXT, 860.0))
		v.add_child(UI.label("Wie alt bist du?", 30))
		var a := UI.button("Unter 16 Jahre", func(): _young(), "dark", 28)
		var b := UI.button("16 Jahre oder älter", func(): show_consent(1), "green", 28)
		for x in [a, b]:
			x.custom_minimum_size = Vector2(380, 80)
		var row := UI.hbox(24, [a, b])
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(row)
		v.add_child(UI.text("Die Angabe bleibt auf diesem Gerät. Du kannst sie in Einstellungen → Online und Datenschutz ändern.", 19, UI.GREY, 860.0))
		return
	v.add_child(UI.text("Dürfen wir anonyme Spieldaten und Fehlerberichte senden? Damit sehen wir, wo das Spiel zu schwer ist, " +
		"wo es ruckelt und wo es abstürzt. Wir erfassen keine Namen, keine Kontakte und keinen Standort und geben nichts an Werbefirmen weiter.", 24, UI.TEXT, 860.0))
	var more := UI.vbox(6)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = false
	rt.custom_minimum_size = Vector2(860, 300)
	rt.add_theme_font_size_override("normal_font_size", 20)
	rt.add_theme_font_size_override("bold_font_size", 22)
	rt.text = md_to_bbcode(String(preload("res://src/screens/legal.gd").docs().datenschutz.text))     # Paket S: Sprache
	if preload("res://src/i18n.gd").is_en():
		rt.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	rt.visible = false
	more.add_child(UI.button("Datenschutzerklärung lesen", func(): rt.visible = not rt.visible, "dark", 22, "ui_info"))
	more.add_child(rt)
	v.add_child(more)
	var no := UI.button("Nur Notwendiges", func():
		net.set_consent(false, false, "16+")
		close(), "dark", 26)
	var yes := UI.button("Erlauben", func():
		net.set_consent(true, true, "16+")
		net.tel.session_start()
		close(), "green", 26, "ui_check")
	for x in [no, yes]:
		x.custom_minimum_size = Vector2(360, 80)
	var row2 := UI.hbox(24, [no, yes])
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row2)
	v.add_child(UI.text("„Nur Notwendiges“: Das Spiel funktioniert genauso. Änderbar unter Einstellungen → Online und Datenschutz.", 19, UI.GREY, 860.0))


func _young() -> void:
	net.set_consent(false, false, "u16")
	var v := _open(900.0)
	v.add_child(UI.hbox(14, [UI.pic("ui_shield", 56.0), UI.label("Alles klar!", 36, UI.GOLD)]))
	v.add_child(UI.text("Wir senden keine Spieldaten. Im Laden fragt das Spiel vor jedem Kauf extra nach – " +
		"bitte kaufe nur, wenn deine Eltern es erlaubt haben. Viel Spaß in Rustwall!", 25, UI.TEXT, 820.0))
	var ok := UI.button("Los geht’s", close, "green", 28, "ui_play")
	ok.custom_minimum_size = Vector2(320, 80)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ok)


# ================================================================= Speicher-Konflikt
func ask_conflict(local: Dictionary, remote: Dictionary) -> void:
	var v := _open(960.0)
	v.add_child(UI.hbox(14, [UI.pic("ui_info", 52.0, "", UI.ORANGE), UI.label("Zwei verschiedene Spielstände", 34, UI.GOLD)]))
	v.add_child(UI.text("Auf dem Server liegt für diese Stadt ein anderer Spielstand als auf diesem Gerät (zum Beispiel, weil du auf zwei Geräten gespielt hast). Welchen möchtest du behalten? Der andere wird überschrieben.", 23, UI.TEXT, 900.0))
	var row := UI.hbox(20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_save_card("Dieses Gerät", local, func():
		close()
		net.upload(true)))
	row.add_child(_save_card("Server", remote, func():
		close()
		net.take_remote()))
	v.add_child(row)


func _save_card(title: String, s: Dictionary, cb: Callable) -> Control:
	var t := float(s.get("server_time", 0.0))
	var when := "unbekannt" if t <= 0.0 else Time.get_datetime_string_from_unix_time(int(t + Time.get_time_zone_from_system().bias * 60), true)
	var v := UI.vbox(8, [UI.label(title, 30, UI.GOLD), UI.label("Spielerstufe %d" % int(s.get("level", 1)), 24),
		UI.label("Bunker Stufe %d" % int(s.get("bunker", 1)), 24), UI.label("Gespeichert: %s" % when, 19, UI.GREY, false)])
	var b := UI.button("Diesen behalten", cb, "green", 24, "ui_check")
	b.custom_minimum_size = Vector2(0, 72)
	v.add_child(b)
	var c := UI.card(v, UI.NAVY_L, 18)
	c.custom_minimum_size = Vector2(420, 0)
	return c


# ================================================================= Text-Hilfe
## Wandelt die einfachen Markdown-Texte (Überschriften, fett, Listen, Links) in BBCode für RichTextLabel um.
static func md_to_bbcode(md: String) -> String:
	var out := PackedStringArray()
	var bold := RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
	var link := RegEx.create_from_string("\\[([^\\]]+)\\]\\(([^)]+)\\)")
	for line in md.split("\n"):
		var l := line.replace("[", "[lb]").replace("]", "[rb]") if not line.contains("](") else line
		l = bold.sub(l, "[b]$1[/b]", true)
		l = link.sub(l, "[u]$1[/u] ($2)", true)
		l = l.replace("{{", "[color=#FF7A88][b]{{").replace("}}", "}}[/b][/color]")      # Platzhalter rot
		if l.begins_with("# "):
			out.append("[font_size=34][color=#FFD23E][b]%s[/b][/color][/font_size]" % l.substr(2))
		elif l.begins_with("## "):
			out.append("\n[font_size=28][color=#FFD23E][b]%s[/b][/color][/font_size]" % l.substr(3))
		elif l.begins_with("### "):
			out.append("[font_size=24][b]%s[/b][/font_size]" % l.substr(4))
		elif l.begins_with("- ") or l.begins_with("* "):
			out.append("  •  " + l.substr(2))
		elif l.begins_with("> "):
			out.append("[color=#FFA12E][b]%s[/b][/color]" % l.substr(2))
		else:
			out.append(l)
	return "\n".join(out)
