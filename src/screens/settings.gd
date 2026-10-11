extends RefCounted
## Bildschirm "Einstellungen": Ton, Grafik, Steuerungshilfe und Testmodus.

const D = preload("res://src/data.gd")
const UI = preload("res://src/ui.gd")

const QUALITY := ["Niedrig", "Mittel", "Hoch"]
const KEYS_PC := [["W A S D", "Laufen"], ["Maus", "Zielen (linke Taste halten: selbst zielen)"], ["Q  E  R", "Fähigkeiten"], ["F", "Kommandanten-Fähigkeit"],
	["Leertaste", "Ausweichen"], ["T", "Fahrzeug ein- und aussteigen"], ["N", "Nächste Welle rufen"], ["Esc", "Pause"], ["F11", "Vollbild"]]
const KEYS_TOUCH := [["Linker Daumen", "Steuerknüppel zum Laufen"], ["Rechts", "Knöpfe für Fähigkeiten, Ausweichen, Fahrzeug und Kommandant"]]

var S


func build() -> Control:
	var st: Dictionary = P.d.settings
	var cols := UI.hbox(16)
	var left := UI.vbox(12)
	# ---- Stadt: Bunkername und Hauptmenü
	var cv := UI.vbox(10, [UI.hbox(12, [UI.pic("ui_shield", 44.0), S.head("Deine Stadt", 30)])])
	var ne := LineEdit.new()
	ne.text = P.bunker_name()
	ne.max_length = P.BUNKER_NAME_MAX
	ne.placeholder_text = "Bunkername"
	ne.custom_minimum_size = Vector2(380, 66)
	var save_name := func():
		var why: String = P.rename_bunker(ne.text)
		if S.say(why, "Bunker heißt jetzt „%s“." % P.bunker_name()):
			P.buildings_changed.emit()
	ne.text_submitted.connect(func(_t: String): save_name.call())
	var nb := UI.button("Umbenennen", save_name, "green", 23)
	nb.custom_minimum_size = Vector2(0, 66)
	cv.add_child(UI.hbox(10, [_name("Bunkername"), ne, nb]))
	cv.add_child(S.hint("Unter diesem Namen (oder deinem Freundescode %s) finden dich andere im Funkturm." % String(P.social.friend_code()), 18))
	if G.main != null and G.main.has_method("open_menu") and G.autotest == "" and not G.selftest:
		var mb := UI.button("Zum Hauptmenü (Städte wechseln, neue Stadt)", func(): G.main.open_menu(), "dark", 23, "ui_map")
		mb.custom_minimum_size = Vector2(0, 66)
		cv.add_child(mb)
	left.add_child(UI.panel(cv, UI.NAVY, UI.EDGE, 22, 20))
	# ---- Ton und Grafik
	var a := UI.vbox(12, [UI.hbox(12, [UI.pic("ui_gear", 44.0), S.head("Ton und Grafik", 30)])])
	a.add_child(_slider("Geräusche", "sfx", 0.8, "ui_alarm"))
	a.add_child(_slider("Musik", "music", 0.6, "ui_play"))
	var qrow := UI.hbox(10, [_name("Grafik")])
	var q := G.quality()
	for i in 3:
		var qb: Button = S.choice(String(QUALITY[i]), i == q, S.act(func():
			st["quality"] = i
			st["quality_user"] = true
			G.apply_quality()
			P.mark()), 24)
		qb.custom_minimum_size = Vector2(150, 68)
		qrow.add_child(qb)
	a.add_child(qrow)
	a.add_child(_toggle("Bildschirm wackelt bei Treffern", "shake", false))
	a.add_child(_toggle("Vibration (Handy)", "vibrate", false))
	a.add_child(_toggle("60 Bilder pro Sekunde", "fps60", true))
	a.add_child(_toggle("Regen in der Basis", "rain", false))
	a.add_child(S.hint("Bei schwächeren Geräten helfen „Niedrig“ und 30 Bilder pro Sekunde. Das schont auch den Akku.", 18))
	left.add_child(UI.panel(a, UI.NAVY, UI.EDGE, 22, 20))

	# ---- Testmodus
	var t := UI.vbox(10, [UI.hbox(12, [UI.pic("ui_wrench", 44.0), S.head("Testmodus", 30)]), S.hint("Nur zum Ausprobieren: Zeit vorspulen und Spielstände vorbereiten.", 18)])
	var tf := UI.flow(10)
	tf.add_child(_test_btn("+1 Stunde", func():
		P.skip_time(3600.0)
		S.toast("Eine Stunde vorgespult.")))
	tf.add_child(_test_btn("+1 Tag", func():
		P.skip_time(86400.0)
		S.toast("Einen Tag vorgespult.")))
	tf.add_child(_test_btn("Bauten fertigstellen", func():
		P.speed_up_builds(1e9)
		S.toast("Alle Bauten sind fertig.")))
	tf.add_child(_test_btn("+ Rohstoffe", func():
		for r in D.RES:
			var cap: int = P.cap(r)
			P.d.res[r] = cap if cap < 999999 else P.res(r) + 500
		P.resources_changed.emit()
		P.mark()
		S.toast("Lager gefüllt.")))
	tf.add_child(_test_btn("Testbasis (Bunker 6)", func():
		S.confirm("Den jetzigen Spielstand durch eine Testbasis ersetzen? In diesem Durchgang wird danach nicht mehr gespeichert.", func():
			P.debug_setup(6)
			P.social.ensure()
			P.mark()
			S.toast("Testbasis aufgebaut."), "Ersetzen")))
	t.add_child(tf)
	t.add_child(_toggle("Schnellbau (60-fach)", "fast_build", false))
	var del := UI.button("Diese Stadt zurücksetzen", func():
		S.confirm("Wirklich den Spielstand dieser Stadt löschen und hier neu anfangen? Das lässt sich nicht rückgängig machen.", func():
			P.reset_all()
			S.toast("Neues Spiel begonnen."), "Löschen"), "red", 23)
	del.custom_minimum_size = Vector2(0, 70)
	del.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	del.set_meta("danger", true)
	t.add_child(del)
	left.add_child(UI.panel(t, UI.NAVY, UI.EDGE, 22, 20))
	var lm := MarginContainer.new()
	lm.add_theme_constant_override("margin_right", 2)
	lm.add_child(left)
	var lsc: ScrollContainer = S.scroll(lm, "set_left")
	lsc.size_flags_stretch_ratio = 1.25
	cols.add_child(lsc)

	# ---- Steuerung
	var right := UI.vbox(12)
	right.add_child(UI.panel(_keys("Steuerung am PC", KEYS_PC), UI.NAVY, UI.EDGE, 22, 20))
	right.add_child(UI.panel(_keys("Steuerung am Handy", KEYS_TOUCH), UI.NAVY, UI.EDGE, 22, 20))
	right.add_child(UI.info_box("Rustwall kommt ohne Käufe mit echtem Geld aus. Mitspieler sind in dieser Version simuliert.", 20))
	var rm := MarginContainer.new()
	rm.add_theme_constant_override("margin_right", 2)
	rm.add_child(right)
	cols.add_child(S.scroll(rm, "set_right"))
	return cols


## Lautstärke-Regler (key in P.d.settings, 0..1) mit Bild, Name und Prozentanzeige.
func _slider(text: String, key: String, def_val: float, icon_name: String) -> Control:
	var st: Dictionary = P.d.settings
	var val := clampf(float(st.get(key, def_val)), 0.0, 1.0)
	var vol_l := UI.label("%d %%" % int(round(val * 100.0)), 25, UI.GOLD)
	vol_l.custom_minimum_size = Vector2(90, 0)
	vol_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = val
	sl.custom_minimum_size = Vector2(260, 60)
	var knob := _knob()
	sl.add_theme_icon_override("grabber", knob)
	sl.add_theme_icon_override("grabber_highlight", knob)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.value_changed.connect(func(v: float):
		st[key] = v
		vol_l.text = "%d %%" % int(round(v * 100.0))
		P.mark()
		if key == "music":
			P.changed.emit()
		UI.sfx("ui_slider", "", -12.0, 0.8 + v * 0.5))
	sl.drag_ended.connect(func(_c: bool):
		if key == "sfx":
			Sfx.play("click", -4.0))
	var ic := UI.pic(icon_name, 44.0)
	var nm := _name(text)
	return UI.hbox(12, [ic, nm, sl, vol_l])


## Großer runder Griff für den Schieberegler (gut mit dem Finger zu treffen).
func _knob() -> ImageTexture:
	var n := 52
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var col := Color(0, 0, 0, 0)
			if d < 17.0:
				col = Color.WHITE.lerp(Color("CFE4FF"), float(y) / n)
			elif d < 24.0:
				col = Color(Color("2F8DEB").lerp(Color("123C82"), float(y) / n), clampf(24.0 - d, 0.0, 1.0))
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _name(text: String) -> Label:
	var l := UI.label(text, 25)
	l.custom_minimum_size = Vector2(170, 0)
	return l


func _toggle(text: String, key: String, apply: bool) -> Control:
	var st: Dictionary = P.d.settings
	var on := bool(st.get(key, false))
	var l := UI.label(text, 24)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var b := UI.button("An" if on else "Aus", S.act(func():
		st[key] = not on
		UI.sfx("ui_toggle", "", -6.0, 1.2 if not on else 0.9)
		if apply:
			G.apply_quality()
		P.mark()), "green" if on else "dark", 24, "ui_check" if on else "ui_close")
	b.custom_minimum_size = Vector2(150, 68)
	return UI.hbox(12, [l, b])


func _test_btn(text: String, cb: Callable) -> Button:
	var b := UI.button(text, S.act(cb), "purple", 22)
	b.custom_minimum_size = Vector2(0, 68)
	return b


func _keys(title: String, rows: Array) -> Control:
	var v := UI.vbox(8, [S.head(title, 30)])
	for r in rows:
		var k := UI.badge(String(r[0]), Color("24508F"), 20)
		k.custom_minimum_size = Vector2(170, 0)
		k.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		k.get_child(0).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(UI.hbox(12, [k, UI.text(String(r[1]), 21)]))
	return v
