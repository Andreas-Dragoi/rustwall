extends RefCounted
## Bildschirm "Einstellungen": Ton, Grafik, Steuerungshilfe, Testmodus und (Paket O) Online, Konto und Datenschutz.

const D = preload("res://src/data.gd")
const UI = preload("res://src/ui.gd")
const Legal = preload("res://src/screens/legal.gd")
const Store = preload("res://src/store.gd")
const I18N = preload("res://src/i18n.gd")

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
			P.social.net.rename_bunker()
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
	a.add_child(_slider("Umgebung", "amb", 0.8, "ui_clover"))
	a.add_child(_slider("Stimmen", "voice", 0.8, "ui_heart"))
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
	a.add_child(_lang_row())
	a.add_child(_toggle("Bildschirm wackelt bei Treffern", "shake", false))
	a.add_child(_toggle("Vibration (Handy)", "vibrate", false))
	a.add_child(_toggle("60 Bilder pro Sekunde", "fps60", true))
	a.add_child(_toggle("Regen in der Basis", "rain", false))
	a.add_child(S.hint("Bei schwächeren Geräten helfen „Niedrig“ und 30 Bilder pro Sekunde. Das schont auch den Akku.", 18))
	left.add_child(UI.panel(a, UI.NAVY, UI.EDGE, 22, 20))

	# ---- Testmodus (mit Server nur in Entwickler-Fassungen: sonst ließe sich die Zeit vorspulen)
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
	if not P.social.server_set() or OS.is_debug_build() or G.ch("store_test"):
		left.add_child(UI.panel(t, UI.NAVY, UI.EDGE, 22, 20))
	var lm := MarginContainer.new()
	lm.add_theme_constant_override("margin_right", 2)
	lm.add_child(left)
	var lsc: ScrollContainer = S.scroll(lm, "set_left")
	lsc.size_flags_stretch_ratio = 1.25
	cols.add_child(lsc)

	# ---- Steuerung
	var right := UI.vbox(12)
	right.add_child(UI.panel(_online(), UI.NAVY, UI.EDGE, 22, 20))
	right.add_child(UI.panel(_privacy(), UI.NAVY, UI.EDGE, 22, 20))
	right.add_child(UI.panel(_keys("Steuerung am PC", KEYS_PC), UI.NAVY, UI.EDGE, 22, 20))
	right.add_child(UI.panel(_keys("Steuerung am Handy", KEYS_TOUCH), UI.NAVY, UI.EDGE, 22, 20))
	right.add_child(UI.info_box(Store.note() + (" Mitspieler sind echt (Server verbunden)." if P.social.online() else " Ohne Server sind die Mitspieler simuliert."), 20))
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
			Sfx.play("click", -4.0)
		elif key == "voice":
			Sfx.voice(String(P.d.hero_sel), "cheer", -4.0))
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


## Paket S: Sprachwahl (wird auf dem Gerät gemerkt, gilt für alle Städte). Wirkt sofort, offene Menüs werden neu gebaut.
func _lang_row() -> Control:
	var row := UI.hbox(10, [_name("Sprache")])
	for code in I18N.LANGS:
		var lb: Button = S.choice(String(I18N.LANG_NAMES[code]), I18N.lang() == code, S.act(func():
			if I18N.lang() != code:
				I18N.set_lang(code)
				if G.hud != null and G.hud.has_method("refresh_language"):
					G.hud.refresh_language()), 24)
		lb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED     # Sprachnamen nie übersetzen
		lb.custom_minimum_size = Vector2(170, 68)
		lb.set_meta("lang", code)
		row.add_child(lb)
	return row


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


# ================================================================= Online und Konto (Paket O)
const STATUS_COL := {"aus": Color("9FB6D8"), "verbinde": Color("FFD23E"), "online": Color("6FE03A"), "offline": Color("FFA12E"), "fehler": Color("FF4D62")}
const STATUS_NAME := {"aus": "Aus (nur dieses Gerät)", "verbinde": "Verbinde …", "online": "Verbunden", "offline": "Offline – spielt lokal weiter", "fehler": "Fehler"}


func _online() -> Control:
	var net = P.social.net
	var v := UI.vbox(10, [UI.hbox(12, [UI.pic("ui_friends", 44.0), S.head("Online-Spiel und Konto", 30)])])
	var dot := UI.label("●", 30, STATUS_COL.get(net.status, UI.GREY))
	var st_l := UI.label(String(STATUS_NAME.get(net.status, net.status)), 24, STATUS_COL.get(net.status, UI.GREY))
	S.every_second(st_l, func():
		st_l.text = String(STATUS_NAME.get(net.status, net.status))
		st_l.add_theme_color_override("font_color", STATUS_COL.get(net.status, UI.GREY))
		dot.add_theme_color_override("font_color", STATUS_COL.get(net.status, UI.GREY)))
	v.add_child(UI.hbox(10, [dot, st_l]))
	v.add_child(S.hint(String(net.status_text), 18))
	# Server-Adresse
	var ue := LineEdit.new()
	ue.text = String(net.cfg.get("url", ""))
	ue.placeholder_text = "Server-Adresse, z. B. https://rustwall.example.de"
	ue.custom_minimum_size = Vector2(360, 62)
	ue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cb := UI.button("Verbinden", func():
		var why: String = net.set_server(ue.text)
		S.say(why, "Verbinde mit dem Server …")
		S.refresh(), "green", 22)
	cb.custom_minimum_size = Vector2(0, 62)
	cb.set_meta("danger", true)
	var row := UI.hbox(8, [ue, cb])
	if net.enabled():
		var off := UI.button("Trennen", func():
			S.confirm("Vom Server trennen? Rustwall läuft dann wieder allein auf diesem Gerät. Dein Konto bleibt bestehen.", func():
				net.set_server("")
				S.toast("Getrennt."), "Trennen"), "dark", 22)
		off.custom_minimum_size = Vector2(0, 62)
		off.set_meta("danger", true)
		row.add_child(off)
	v.add_child(row)
	if not net.enabled():
		v.add_child(S.hint("Ohne Server läuft alles auf diesem Gerät: Spielstand, Juwelen, simulierte Mitspieler. Einen eigenen Server aufsetzen: siehe server/README.md.", 18))
		return v
	if net.user_id != "":
		v.add_child(S.kv("Konto", String(net.user_id).substr(0, 8) + " …", 21, UI.SKY))
	if not net.bunker_ok:
		v.add_child(UI.text("Bunkername: %s Bitte oben einen anderen wählen." % net.bunker_why, 20, UI.RED))
	# Verknüpfen (für Gerätewechsel)
	var linked := []
	for k in [["email", "E-Mail"], ["apple", "Apple"], ["google", "Google"]]:
		if net.linked(k[0]):
			linked.append(k[1])
	v.add_child(S.kv("Verknüpft mit", "nichts" if linked.is_empty() else ", ".join(PackedStringArray(linked)), 21, UI.GOLD))
	v.add_child(S.hint("Verknüpfe dein Konto, damit du es auf einem neuen Gerät wiederfindest. Sonst hängt es nur an diesem Gerät.", 18))
	var em := LineEdit.new()
	em.placeholder_text = "E-Mail"
	em.custom_minimum_size = Vector2(260, 60)
	em.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pw := LineEdit.new()
	pw.placeholder_text = "Passwort (mind. 8 Zeichen)"
	pw.secret = true
	pw.custom_minimum_size = Vector2(220, 60)
	pw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.hbox(8, [em, pw]))
	var lb := UI.button("E-Mail verknüpfen", func():
		var why: String = await net.link("email", em.text, pw.text)
		S.say(why, "E-Mail verknüpft.")
		S.refresh(), "green", 21)
	var li := UI.button("Mit E-Mail anmelden", func():
		S.confirm("Mit diesem Konto anmelden? Danach kannst du die Spielstände dieses Kontos vom Server laden.", func():
			var why: String = await net.login_email(em.text, pw.text)
			S.say(why, "Angemeldet.")
			S.refresh(), "Anmelden"), "dark", 21)
	li.set_meta("danger", true)
	var fl := UI.flow(8)
	for b in [lb, li]:
		b.custom_minimum_size = Vector2(0, 60)
		fl.add_child(b)
	for k in [["apple", "Mit Apple verknüpfen"], ["google", "Mit Google verknüpfen"]]:
		var kind: String = k[0]
		var sign := func(): S.say(Store.sign_in(kind))
		var b2 := UI.button(String(k[1]), sign, "dark", 21)
		b2.custom_minimum_size = Vector2(0, 60)
		fl.add_child(b2)
	var pull := UI.button("Spielstand vom Server laden", func():
		S.confirm("Den Spielstand dieser Stadt durch den Stand auf dem Server ersetzen?", func():
			var why: String = await net.take_remote()
			S.say(why, "Spielstand vom Server geladen.")
			S.refresh(), "Laden"), "dark", 21)
	pull.custom_minimum_size = Vector2(0, 60)
	pull.set_meta("danger", true)
	fl.add_child(pull)
	var rs := UI.button("Käufe wiederherstellen", func(): S.say(Store.restore(), "Käufe werden geprüft …"), "dark", 21)
	rs.custom_minimum_size = Vector2(0, 60)
	fl.add_child(rs)
	v.add_child(fl)
	return v


func _privacy() -> Control:
	var net = P.social.net
	var v := UI.vbox(10, [UI.hbox(12, [UI.pic("ui_shield", 44.0), S.head("Datenschutz und Rechtliches", 30)])])
	var age := String(net.cfg.get("age", ""))
	var ar := UI.hbox(10, [_name("Alter")])
	for a in [["u16", "Unter 16"], ["16+", "16 oder älter"]]:
		var key: String = a[0]
		var b: Button = S.choice(String(a[1]), age == key, S.act(func(): net.set_consent(net.consent_analytics() and key != "u16", net.consent_crash() and key != "u16", key)), 22)
		b.custom_minimum_size = Vector2(190, 62)
		ar.add_child(b)
	v.add_child(ar)
	if net.child_mode():
		v.add_child(S.hint("Unter 16: Es werden keine Spieldaten und keine Fehlerberichte gesendet. Käufe nur mit Erlaubnis der Eltern.", 18, UI.ORANGE))
	else:
		v.add_child(_consent_toggle("Anonyme Spieldaten senden", net.consent_analytics(), func(on: bool): net.set_consent(on, net.consent_crash())))
		v.add_child(_consent_toggle("Fehlerberichte senden", net.consent_crash(), func(on: bool): net.set_consent(net.consent_analytics(), on)))
		v.add_child(S.hint("Hilft uns, Fehler zu finden und das Spiel zu verbessern. Keine Namen, kein Standort, keine Werbung.", 18))
	var fl := UI.flow(8)
	var lb := UI.button("Rechtliches", func(): S.open("legal"), "", 22, "ui_info")
	var pb := UI.button("Datenschutzerklärung", func(): S.open("legal", "datenschutz"), "dark", 22)
	var db := UI.button("Konto löschen", func(): Legal.confirm_delete(S), "red", 22)
	db.set_meta("danger", true)
	for b in [lb, pb, db]:
		b.custom_minimum_size = Vector2(0, 62)
		fl.add_child(b)
	v.add_child(fl)
	return v


func _consent_toggle(text: String, on: bool, cb: Callable) -> Control:
	var l := UI.label(text, 23)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var b := UI.button("An" if on else "Aus", S.act(func():
		cb.call(not on)
		UI.sfx("ui_toggle", "", -6.0, 1.2 if not on else 0.9)), "green" if on else "dark", 23, "ui_check" if on else "ui_close")
	b.custom_minimum_size = Vector2(150, 64)
	return UI.hbox(12, [l, b])
