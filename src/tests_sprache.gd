extends RefCounted
## Prüfungen von Paket S (Sprachen): Abdeckung von locale/en.po, gleiche Platzhalter in Deutsch und Englisch,
## Umschalten ohne Neustart, zusammengesetzte Texte, englische Rechtstexte und ein Durchlauf aller Bildschirme
## in Englisch. Aufruf aus tests.gd (--selftest) oder allein mit --autotest=sprache.

const I18N = preload("res://src/i18n.gd")
const Legal = preload("res://src/legal_texts.gd")
const Screens = preload("res://src/screens.gd")
const UI = preload("res://src/ui.gd")

var T: Node                      # tests.gd (für _check und _wait)


func _init(tests: Node) -> void:
	T = tests


func run() -> void:
	var was := I18N.lang()
	_po()
	await _switch()
	_legal()
	await _screens()
	I18N.set_lang(was, false)
	T._check(I18N.lang() == was, "Sprache zurückgestellt (%s)" % was)


# ---------------------------------------------------------------- en.po: Abdeckung und Platzhalter
func _po() -> void:
	var txt := FileAccess.get_file_as_string(I18N.PO_PATH)
	T._check(txt.length() > 10000, "locale/en.po vorhanden")
	var pairs := {}
	var mid := ""
	var mstr := ""
	var cur := ""
	for raw in txt.split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("msgid "):
			if mid != "":
				pairs[mid] = mstr
			mid = I18N._unq(line.substr(6))
			mstr = ""
			cur = "id"
		elif line.begins_with("msgstr "):
			mstr = I18N._unq(line.substr(7))
			cur = "str"
		elif line.begins_with("\""):
			if cur == "id":
				mid += I18N._unq(line)
			else:
				mstr += I18N._unq(line)
		elif line == "" or line.begins_with("#"):
			if mid != "":
				pairs[mid] = mstr
			mid = ""
			cur = ""
	var total := pairs.size()
	var done := 0
	var bad: Array = []
	var re := RegEx.create_from_string("%(?:%|[-+0]*\\d*(?:\\.\\d+)?[sdifxXc])")
	for k in pairs:
		var v: String = pairs[k]
		if v == "":
			continue
		done += 1
		if _ph(re, k) != _ph(re, v):
			bad.append(k)
	var cov := 100.0 * done / maxf(1.0, total)
	T._check(total > 3000 and cov >= 98.0, "Übersetzt: %d von %d Texten (%.1f %%)" % [done, total, cov])
	T._check(bad.is_empty(), "Platzhalter gleich in Deutsch und Englisch (%d abweichend: %s)" % [bad.size(), str(bad.slice(0, 3))])


func _ph(re: RegEx, s: String) -> Array:
	var out: Array = []
	for m in re.search_all(s):
		if m.get_string() != "%%":
			out.append(m.get_string())
	out.sort()
	return out


# ---------------------------------------------------------------- Umschalten und zusammengesetzte Texte
func _switch() -> void:
	I18N.set_lang("de", false)
	T._check(TranslationServer.translate("Sägewerk") == "Sägewerk" and tr_("Stufe 7") == "Stufe 7", "Deutsch: Texte bleiben unverändert")
	I18N.set_lang("en", false)
	T._check(I18N.is_en() and TranslationServer.get_locale() == "en", "auf Englisch umgeschaltet")
	var cases := {
		"Sägewerk": "Sawmill",
		"Stufe 7": "Level 7",
		"Besiege 5 Schleimlinge": "Defeat 5 slimelings",
		"Woche 2 · Tag 3 von 7": "Week 2 · Day 3 of 7",
		"Flut in 2 Std 4 Min": "Flood in 2 h 4 min",
		"FLUT STARTEN": "START FLOOD",
		"Bunker heißt jetzt „Moosburg“.": "The bunker is now called “Moosburg”.",
		"+12 Holz": "+12 Wood",
		"1 Juwelen": "1 gem",
		"5 Juwelen": "5 gems",
		"Gekauft: Eispickel. Bricht Eiskristalle: Energiezellen.": "Bought: Ice Pick. Breaks ice crystals: energy cells.",
	}
	for de in cases:
		var got := tr_(de)
		T._check(got == String(cases[de]), "englisch: „%s“ → „%s“ (ist „%s“)" % [de, cases[de], got])
	# Controls übersetzen ihren Text selbst; .text bleibt der deutsche Quelltext
	var l := Label.new()
	l.text = "Energiezellen"
	T.add_child(l)
	await T._wait(0.05)
	var w_en := l.get_minimum_size().x
	T._check(l.text == "Energiezellen" and l.atr(l.text) == "Energy Cells", "Label übersetzt automatisch")
	I18N.set_lang("de", false)
	await T._wait(0.05)
	var w_de := l.get_minimum_size().x
	T._check(absf(w_en - w_de) > 1.0, "Label wechselt mit der Sprache ohne Neustart (Breite %d → %d)" % [int(w_en), int(w_de)])
	l.queue_free()


func tr_(s: String) -> String:
	return TranslationServer.translate(s)


# ---------------------------------------------------------------- Rechtstexte
func _legal() -> void:
	for k in Legal.ORDER:
		T._check(Legal.DOCS_EN.has(k) and String(Legal.DOCS_EN[k].text).contains("DRAFT"), "englischer Rechtstext %s vorhanden" % k)
	I18N.set_lang("en", false)
	T._check(preload("res://src/screens/legal.gd").docs() == Legal.DOCS_EN, "Englisch zeigt die englischen Rechtstexte")
	I18N.set_lang("de", false)
	T._check(preload("res://src/screens/legal.gd").docs() == Legal.DOCS, "Deutsch zeigt die deutschen Rechtstexte")


# ---------------------------------------------------------------- alle Bildschirme in Englisch
func _screens() -> void:
	if G.main == null or G.main.get("screens") == null:
		return
	I18N.set_lang("en", false)
	var inst = I18N.inst
	var old_log: bool = inst.log_misses
	inst.log_misses = true
	inst.misses.clear()
	var scr = G.main.screens
	var n := 0
	for name in Screens.BUILDERS:
		scr.open(name)
		await T._wait(0.1)
		var ok: bool = scr.is_open()
		# jeden Reiter einmal zeigen
		for tab in 8:
			if not scr.is_open():
				break
			scr.st["tab"] = tab
			scr.refresh()
			await T._wait(0.05)
		T._check(ok, "Englisch: Bildschirm %s" % name)
		n += 1
		scr.close()
		await T._wait(0.05)
	# Wie viele deutsch wirkende Texte blieben unübersetzt? (Namen von Spielern/Städten sind erlaubt)
	var ger := RegEx.create_from_string("[äöüÄÖÜß]|\\b(der|die|das|und|ist|nicht|mit|für|auf|von|noch|jetzt|alle|keine?|dein|deine|wird|oder|wenn|auch|nur|schon|Stufe|Welle|Gegner|Helden?|Juwelen|Münzen)\\b")
	var left: Array = []
	for k in inst.misses:
		if ger.search(String(k)) != null:
			left.append(k)
	print("SPRACHE: %d Bildschirme in Englisch, %d deutsch wirkende Reste: %s" % [n, left.size(), str(left.slice(0, 8))])
	T._check(left.size() <= 15, "Englisch: höchstens 15 unübersetzte Reste in allen Bildschirmen (%d)" % left.size())
	inst.log_misses = old_log
	if not old_log:
		inst.misses.clear()
