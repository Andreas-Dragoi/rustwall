extends RefCounted
## Paket H (V6): Waffenmodule in der Werkstatt – Reiter „Module“ (herstellen, Lager) und die Sockel einer Waffe
## (einsetzen, ausbauen). Wird von src/screens/workshop.gd und src/screens/heroes.gd benutzt.

const D = preload("res://src/data.gd")
const DH = preload("res://src/data_helden.gd")
const HS = preload("res://src/helden.gd")
const UI = preload("res://src/ui.gd")


## Mitte: alle Module mit Bestand und Herstellen.
static func module_list(S, c: VBoxContainer) -> void:
	c.add_child(S.hint("Module stecken in den Sockeln einer Waffe (Gewöhnlich und Selten 1, Episch 2, Legendär 3). Sie lassen sich jederzeit wieder ausbauen.", 20))
	var sel := String(S.st.get("mod", DH.MODULE_ORDER[0]))
	for mk in DH.MODULE_ORDER:
		var md: Dictionary = DH.MODULES[mk]
		var n := HS.module_count(mk)
		var nm := UI.label(String(md.name), 24)
		nm.clip_text = true
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tx := UI.label(String(md.text), 18, Color("DCE8F5"), false)
		tx.clip_text = true
		tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var txt := UI.vbox(0, [nm, tx])
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cnt := UI.badge("× %d" % n, Color("2E8A22") if n > 0 else Color("4A5A78"), 20)
		var content := UI.hbox(12, [UI.pic("mod_" + mk, 64.0, "ui_build"), txt, cnt])
		var mkey: String = mk
		c.add_child(S.card_button(mk == sel, func():
			S.st["mod"] = mkey
			S.refresh(), content, 78.0))


## Rechts: Einzelheiten und Herstellen.
static func module_detail(S) -> Control:
	var mk := String(S.st.get("mod", DH.MODULE_ORDER[0]))
	if not DH.MODULES.has(mk):
		mk = DH.MODULE_ORDER[0]
	var md: Dictionary = DH.MODULES[mk]
	var v := UI.vbox(12)
	var card := UI.panel(v, UI.NAVY, UI.EDGE, 24, 18)
	card.custom_minimum_size = Vector2(600, 0)
	var title := UI.label(String(md.name), 32)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var info := UI.vbox(6, [title, UI.text(String(md.text), 22), UI.label("Im Lager: %d" % HS.module_count(mk), 22, UI.GOLD)])
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.hbox(14, [UI.pedestal(UI.pic("mod_" + mk, 160.0, "ui_build"), 180.0), info]))
	var fits := "Passt in alle Waffen außer Geschützen."
	if md.has("modes"):
		var names: Array = []
		for m in md.modes:
			names.append(String(D.WEAPON_MODE_NAME.get(m, m)))
		fits = "Passt in: " + ", ".join(names)
	elif md.get("mag", false):
		fits = "Passt in Waffen mit Magazin."
	if md.has("core"):
		fits += " Nur ein Element-Kern je Waffe."
	var fl := UI.label(fits, 19, Color("BFE3FF"), false)
	fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(fl)
	v.add_child(UI.sep())
	var cost: Dictionary = md.cost
	var cr := UI.cost_row(cost, 26)
	var b := UI.button("Herstellen", S.act(func():
		if HS.craft_module(mk):
			UI.sfx("ui_upgrade", "upgrade", -4.0)
		else:
			UI.sfx("ui_error", "error", -6.0)), "green", 26, "ui_hammer")
	b.custom_minimum_size = Vector2(0, 76)
	UI.disable(b, not P.can_pay(cost))
	v.add_child(UI.hbox(12, [cr, UI.spacer(true), b]))
	v.add_child(S.hint("Module gibt es auch als Fund in Beutekisten (öfter in Boss- und Flutkisten).", 19))
	return card


## Sockel einer Waffe mit Einsetzen/Ausbauen. it = Waffen-Gegenstand. Nach einer Änderung lädt der Held neu.
static func sockets_box(S, it: Dictionary) -> Control:
	var v := UI.vbox(6)
	var arr := HS.sockets(it)
	var id := int(it.id)
	v.add_child(UI.hbox(8, [UI.pic("ui_build", 30.0, "", UI.GOLD), UI.label("Sockel für Module (%d)" % arr.size(), 22, UI.GOLD)]))
	var open_i := int(S.st.get("sock", -1)) if int(S.st.get("sock_item", 0)) == id else -1
	for i in arr.size():
		var m := String(arr[i])
		var row := UI.hbox(10)
		var idx: int = i
		if m != "" and DH.MODULES.has(m):
			row.add_child(UI.pic("mod_" + m, 46.0, "ui_build"))
			var l := UI.label(String(DH.MODULES[m].name), 20)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.clip_text = true
			row.add_child(l)
			var rb := UI.button("Ausbauen", S.act(func():
				HS.remove(id, idx)
				_reload()), "dark", 19)
			rb.custom_minimum_size = Vector2(0, 52)
			row.add_child(rb)
		else:
			row.add_child(UI.tile("build", 46.0, Color("2A3A5A")))
			var l2 := UI.label("frei", 20, UI.GREY)
			l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l2)
			var ib := UI.button("Einsetzen …", func():
				S.st["sock"] = idx if open_i != idx else -1
				S.st["sock_item"] = id
				S.refresh(), "green", 19)
			ib.custom_minimum_size = Vector2(0, 52)
			row.add_child(ib)
		v.add_child(row)
		if open_i == i and m == "":
			v.add_child(_chooser(S, it, i))
	return UI.card(v, Color("15284A"), 10)


static func _chooser(S, it: Dictionary, idx: int) -> Control:
	var f := UI.flow(6)
	var any := false
	var id := int(it.id)
	for mk in DH.MODULE_ORDER:
		if HS.module_count(mk) <= 0 or HS.fits(mk, String(it.key)) != "":
			continue
		any = true
		var key: String = mk
		var b := UI.button("%s (%d)" % [String(DH.MODULES[mk].name), HS.module_count(mk)], S.act(func():
			if HS.insert(id, idx, key):
				UI.sfx("ui_equip", "click", -4.0)
				S.st["sock"] = -1
				_reload()), "", 18, "mod_" + mk)
		b.custom_minimum_size = Vector2(0, 50)
		f.add_child(b)
	if not any:
		return S.hint("Kein passendes Modul im Lager – in der Werkstatt unter „Module“ herstellen.", 19, UI.ORANGE)
	return f


static func _reload() -> void:
	if G.main != null and G.main.has_method("reload_hero"):
		G.main.reload_hero()
