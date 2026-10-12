extends RefCounted
## Bildschirm "Rechtliches" (Paket O): Datenschutzerklärung, Nutzungsbedingungen, Impressum, Mitwirkende und Lizenzen.
## Die Texte stammen aus docs/legal/*.md (über tools/legal_to_gd.py nach src/legal_texts.gd übertragen).
## Es sind ENTWÜRFE mit Platzhaltern – vor der Veröffentlichung von einem Anwalt prüfen lassen.

const UI = preload("res://src/ui.gd")
const Legal = preload("res://src/legal_texts.gd")
const NetUi = preload("res://src/net_ui.gd")
const I18N = preload("res://src/i18n.gd")

const ICONS := ["ui_shield", "ui_quest", "ui_info", "ui_star"]

var S


func setup(arg) -> void:
	if arg is String and Legal.ORDER.has(arg):
		S.st["tab"] = Legal.ORDER.find(arg)


func build() -> Control:
	var v := UI.vbox(12)
	var names: Array = []
	for k in Legal.ORDER:
		names.append(String(docs()[k].title))
	v.add_child(S.tabs(names, "tab", 24, ICONS))
	var key: String = Legal.ORDER[clampi(int(S.st.get("tab", 0)), 0, Legal.ORDER.size() - 1)]
	var row := UI.hbox(16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.selection_enabled = true
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rt.custom_minimum_size = Vector2(600, 400)
	rt.add_theme_font_size_override("normal_font_size", 22)
	rt.add_theme_font_size_override("bold_font_size", 23)
	rt.add_theme_color_override("default_color", UI.TEXT)
	rt.add_theme_font_override("normal_font", UI.font(false))
	rt.add_theme_font_override("bold_font", UI.font(true))
	var text := NetUi.md_to_bbcode(String(docs()[key].text))
	if I18N.is_en():
		rt.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED     # eigene englische Fassung, nicht stückweise übersetzen
	if key == "mitwirkende":
		text += "\n\n[font_size=26][color=#FFD23E][b]%s[/b][/color][/font_size]\n" % I18N.t("Godot Engine – Lizenz") + _plain(Engine.get_license_text())
		text += "\n\n[font_size=26][color=#FFD23E][b]%s[/b][/color][/font_size]\n" % I18N.t("Schrift Fredoka – SIL Open Font License 1.1") + _plain(Legal.FONT_LICENSE)
		text += "\n\n[font_size=26][color=#FFD23E][b]%s[/b][/color][/font_size]\n" % I18N.t("Bestandteile der Godot Engine") + _plain(_copyright())
	rt.text = text
	var tp := UI.panel(rt, UI.NAVY, UI.EDGE, 22, 18)
	tp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tp.size_flags_stretch_ratio = 2.6
	row.add_child(tp)
	# rechts: Hinweise und Konto
	var side := UI.vbox(12)
	side.custom_minimum_size = Vector2(420, 0)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(UI.info_box("Entwurf mit Platzhaltern (rot). Vor der Veröffentlichung von einem Anwalt prüfen lassen.", 20))
	var net = P.social.net
	var acc := UI.vbox(10, [S.head("Deine Daten", 28)])
	acc.add_child(UI.text("Spieldaten senden: %s\nFehlerberichte senden: %s" % ["ja" if net.consent_analytics() else "nein", "ja" if net.consent_crash() else "nein"], 20))
	var cb := UI.button("Einwilligung ändern", func(): S.open("settings"), "dark", 21, "ui_gear")
	cb.custom_minimum_size = Vector2(0, 62)
	acc.add_child(cb)
	acc.add_child(UI.text("Konto und alle Daten auf dem Server kannst du jederzeit löschen.", 20, UI.GREY))
	var db := UI.button("Konto löschen", func(): confirm_delete(S), "red", 22)
	db.custom_minimum_size = Vector2(0, 66)
	db.set_meta("danger", true)
	acc.add_child(db)
	side.add_child(UI.panel(acc, UI.NAVY, UI.EDGE, 22, 18))
	row.add_child(side)
	v.add_child(row)
	return v


## Paket S: Rechtstexte in der gewählten Sprache (Englisch hat eine eigene Fassung).
static func docs() -> Dictionary:
	if I18N.is_en() and not Legal.DOCS_EN.is_empty():
		return Legal.DOCS_EN
	return Legal.DOCS


## Rückfrage und Löschen des Kontos (auch aus den Einstellungen benutzt).
static func confirm_delete(scr) -> void:
	var net = P.social.net
	if not net.enabled():
		scr.toast("Es ist kein Online-Konto angelegt. Spielstände auf diesem Gerät löschst du über „Diese Stadt zurücksetzen“.")
		return
	scr.confirm("Konto wirklich löschen? Dabei werden dein Online-Konto, die Spielstände auf dem Server, Freunde, Post, Clan und Ranglisten gelöscht. Das lässt sich nicht rückgängig machen. Die Spielstände auf diesem Gerät bleiben erhalten.", func():
		var why: String = await net.delete_account(false)
		if why == "":
			scr.toast("Konto gelöscht.")
		else:
			scr.toast(why)
		scr.refresh(), "Löschen")


func _plain(t: String) -> String:
	return t.replace("[", "[lb]").replace("]", "[rb]")


func _copyright() -> String:
	var out := PackedStringArray()
	for part in Engine.get_copyright_info():
		var lines := PackedStringArray()
		for p in part.get("parts", []):
			lines.append("%s (%s)" % [", ".join(PackedStringArray(p.get("copyright", []))), String(p.get("license", ""))])
		out.append("• %s: %s" % [String(part.get("name", "")), "; ".join(lines)])
	return "\n".join(out)
