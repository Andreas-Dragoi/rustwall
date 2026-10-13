extends RefCounted
## Paket Q: Zusätzliche Tafeln im Bildschirm „Einstellungen“ (settings.gd ruft die statischen Funktionen auf):
##   access(S)    Barrierefreiheit: Farbfilter, Textgröße, Untertitel, Blitze, Kamerawackeln
##   auto_q(S)    Grafikstufe automatisch messen
##   keys(S)      Steuerung am PC mit Tastenbelegung ändern
##   window(S)    Fenster, Auflösung, VSync, Bildratenbegrenzung (nur PC)
##   pad(S)       Gamepad-Belegung

const UI = preload("res://src/ui.gd")
const DF = preload("res://src/data_fuehrung.gd")
const Dev = preload("res://src/device_cfg.gd")
const A11y = preload("res://src/a11y.gd")
const Pc = preload("res://src/pc_input.gd")
const AutoQ = preload("res://src/auto_quality.gd")
const Captions = preload("res://src/captions.gd")


## Wartet auf eine Taste für die Umbelegung (Esc bricht ab).
class Catcher extends Control:
	var action := ""
	var S = null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _input(e: InputEvent) -> void:
		if not (e is InputEventKey) or not e.pressed or e.echo:
			return
		get_viewport().set_input_as_handled()
		var k := int(e.physical_keycode)
		if k == KEY_ESCAPE and action != "pause":
			S.toast("Abgebrochen.")
		elif k != 0:
			var sw: String = Pc.set_key(action, k)
			S.toast("%s: %s" % [_name(action), Pc.key_name(k)] + ("" if sw == "" else " (getauscht mit „%s“)" % sw))
		S.set_meta("q_capture", "")
		S.refresh()
		queue_free()

	func _name(a: String) -> String:
		for r in Pc.ACTIONS:
			if r[0] == a:
				return String(r[1])
		return a



static func _head(S, icon: String, title: String) -> Control:
	return UI.hbox(12, [UI.pic(icon, 44.0), S.head(title, 30)])


static func _toggle(S, text: String, on: bool, cb: Callable) -> Control:
	var l := UI.label(text, 24)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var b := UI.button("An" if on else "Aus", S.act(func():
		cb.call(not on)
		UI.sfx("ui_toggle", "", -6.0, 1.2 if not on else 0.9)), "green" if on else "dark", 24, "ui_check" if on else "ui_close")
	b.custom_minimum_size = Vector2(150, 68)
	return UI.hbox(12, [l, b])


# ================================================================= Barrierefreiheit
static func access(S) -> Control:
	var v := UI.vbox(12, [_head(S, "ui_help", "Barrierefreiheit")])
	# Farbfilter
	v.add_child(UI.label("Farbfilter bei Farbfehlsichtigkeit", 24, UI.GOLD))
	var f := UI.flow(8)
	var cur := A11y.cb_mode()
	for i in A11y.CB_MODES.size():
		var k: int = i
		var b: Button = S.choice(String(A11y.CB_MODES[i][0]), i == cur, S.act(func(): A11y.set_cb_mode(k)), 21)
		b.set_meta("cb_mode", k)
		f.add_child(b)
	v.add_child(f)
	# Farbmuster zum Vergleichen (Lebensleisten, Gut/Schlecht, Elemente)
	var sw := UI.flow(6)
	for c in [["Gegner", UI.RED], ["Bunker", Color("02A6FD")], ["Gut", UI.GREEN], ["Schlecht", UI.RED], ["Feuer", Color("FD932C")], ["Gift", Color("8FD14F")], ["Wasser", Color("5DB2EA")]]:
		var chip := UI.badge(String(c[0]), c[1], 18)
		sw.add_child(chip)
	v.add_child(sw)
	v.add_child(S.hint("Der Filter verschiebt Farbunterschiede, die schwer zu sehen sind, in gut sichtbare Farben – für Lebensleisten, Marker, Elemente und die ganze Spielwelt.", 18))
	# Textgröße (gleiche Einstellung wie Hilfe → Bedienung)
	v.add_child(UI.label("Textgröße der Anzeige im Spiel", 24, UI.GOLD))
	var tf := UI.flow(8)
	var st: Dictionary = P.d.settings
	var us := int(st.get("ui_size", 0))
	for i in DF.UI_SIZES.size():
		var k2: int = i
		tf.add_child(S.choice(String(DF.UI_SIZES[i][0]), i == us, S.act(func():
			st["ui_size"] = k2
			P.mark()
			if G.hud != null and G.hud.get("guide") != null:
				G.hud.guide.fit_root()), 21))
	v.add_child(tf)
	v.add_child(_toggle(S, "Untertitel für wichtige Töne (Flut-Alarm, Boss, Explosion in der Nähe)", Captions.enabled, func(on: bool):
		Dev.set_v("captions", on)
		A11y.apply(G.main)
		if on:
			Captions.show_text("Untertitel sind an")))
	v.add_child(_toggle(S, "Blitze abschwächen (roter Trefferblitz, Explosionslicht)", A11y.calm(), func(on: bool): A11y.set_calm(on)))
	v.add_child(S.hint("Kamerawackeln und Vibration lassen sich oben unter „Ton und Grafik“ abschalten.", 18))
	return v


# ================================================================= Grafikstufe automatisch
static func auto_q(S) -> Control:
	var v := UI.vbox(10, [_head(S, "ui_speed", "Grafikstufe automatisch")])
	var aq := AutoQ.auto_quality()
	var txt := "Noch nicht gemessen."
	if aq >= 0:
		txt = "Gemessen: %d Bilder pro Sekunde → „%s“." % [int(Dev.get_v("auto_fps", 0)), AutoQ.QUALITY_NAMES[aq]]
	if bool(P.d.settings.get("quality_user", false)):
		txt += " Du hast selbst eine Stufe gewählt – sie gilt."
	v.add_child(UI.text(txt, 21, UI.TEXT))
	var row := UI.flow(8)
	var mb := UI.button("Neu messen", S.act(func():
		P.d.settings["quality_user"] = false
		P.mark()
		S.toast("Messung läuft einige Sekunden in der Basis …")
		AutoQ.maybe_start(G.main, true)), "dark", 22, "ui_replay")
	mb.custom_minimum_size = Vector2(0, 64)
	row.add_child(mb)
	v.add_child(row)
	return v


# ================================================================= Tastenbelegung
static func keys(S) -> Control:
	var v := UI.vbox(8, [_head(S, "ui_finger", "Steuerung am PC")])
	v.add_child(S.hint("Taste antippen, dann die neue Taste drücken (Esc bricht ab). Ist sie schon vergeben, tauschen beide.", 18))
	var capturing := String(S.get_meta("q_capture", ""))
	if capturing != "" and (S._root == null or S._root.get_node_or_null("QCatcher") == null):
		capturing = ""                    # Menü wurde zwischendurch geschlossen
		S.set_meta("q_capture", "")
	for a in Pc.ACTIONS:
		var act: String = a[0]
		var waiting := capturing == act
		var kb := UI.button("Taste drücken …" if waiting else Pc.key_name(Pc.key_of(act)), func():
			if String(S.get_meta("q_capture", "")) != "":
				return
			S.set_meta("q_capture", act)
			var c := Catcher.new()
			c.name = "QCatcher"
			c.action = act
			c.S = S
			S._root.add_child(c)
			S.refresh(), "tab_on" if waiting else "tab", 20)
		kb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		kb.custom_minimum_size = Vector2(190, 54)
		kb.set_meta("key_action", act)
		var l := UI.text(String(a[1]), 21)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.hbox(12, [kb, l]))
	for r in [["Maus", "Zielen (linke Taste halten: selbst zielen), rechte Taste: hinlaufen"], ["Mausrad", "Kamera näher/weiter"], ["F11", "Vollbild an/aus"]]:
		var k := UI.badge(String(r[0]), Color("24508F"), 20)
		k.custom_minimum_size = Vector2(190, 0)
		k.get_child(0).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(UI.hbox(12, [k, UI.text(String(r[1]), 21)]))
	var rb := UI.button("Standardbelegung", S.act(func():
		Pc.reset_keys()
		S.toast("Tasten zurückgesetzt.")), "dark", 22, "ui_recycle")
	rb.custom_minimum_size = Vector2(0, 62)
	rb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(rb)
	return v


# ================================================================= Fenster (PC)
static func window(S) -> Control:
	var v := UI.vbox(10, [_head(S, "ui_grid", "Fenster und Bildrate")])
	var m := Pc.win_mode()
	var mf := UI.flow(8)
	for wm in Pc.WIN_MODES:
		var key: String = wm[1]
		mf.add_child(S.choice(String(wm[0]), m == key, S.act(func(): Pc.set_window(key)), 21))
	v.add_child(UI.hbox(10, [_lab("Darstellung"), _grow(mf)]))
	if m == "window":
		var rf := UI.flow(8)
		var cur := Pc.resolution()
		for r in Pc.resolutions():
			var rr: Vector2i = r
			var b: Button = S.choice("%d × %d" % [rr.x, rr.y], rr == cur, S.act(func(): Pc.set_window("window", rr)), 20)
			b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			rf.add_child(b)
		v.add_child(UI.hbox(10, [_lab("Auflösung"), _grow(rf)]))
	v.add_child(_toggle(S, "VSync (Bild an den Monitor angleichen, verhindert Reißen)", Pc.vsync(), func(on: bool): Pc.set_vsync(on)))
	var ff := UI.flow(8)
	var fc := Pc.fps_cap()
	var std: Button = S.choice("Spiel", fc < 0, S.act(func(): Pc.set_fps_cap(-1)), 20)
	ff.add_child(std)
	for c in Pc.FPS_CAPS:
		var cc: int = c
		ff.add_child(S.choice("unbegrenzt" if cc == 0 else str(cc), fc == cc, S.act(func(): Pc.set_fps_cap(cc)), 20))
	v.add_child(UI.hbox(10, [_lab("Bilder/s höchstens"), _grow(ff)]))
	v.add_child(S.hint("„Spiel“: 60 (oder 30 mit dem Schalter oben bzw. im Akku-Sparmodus).", 18))
	return v


static func _grow(f: Control) -> Control:
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f


static func _lab(t: String) -> Label:
	var l := UI.label(t, 22)
	l.custom_minimum_size = Vector2(170, 0)
	return l


# ================================================================= Gamepad
static func pad(S) -> Control:
	var v := UI.vbox(8, [_head(S, "ui_play", "Gamepad")])
	var pads := Input.get_connected_joypads()
	v.add_child(UI.text("Verbunden: %s" % (Input.get_joy_name(pads[0]) if pads.size() > 0 else "keins"), 21, UI.GOLD if pads.size() > 0 else UI.GREY))
	for r in Pc.PAD_HELP:
		var k := UI.badge(String(r[0]), Color("2E6B3A"), 20)
		k.custom_minimum_size = Vector2(190, 0)
		k.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		k.get_child(0).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(UI.hbox(12, [k, UI.text(String(r[1]), 21)]))
	return v
