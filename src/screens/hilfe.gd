extends RefCounted
## Bildschirm "Hilfe" (Paket F, Kapitel 8.2): Erklärseiten zu Elementen und Schwächen, Waffenarten, Begleitern,
## Wartezeiten, Flut und Expedition; dazu „Bedienung“ (Akku-Sparmodus, Oberflächengröße, Tutorial neu starten).
## Texte in data_fuehrung.gd (HELP), Tabellen kommen aus data.gd.

const D = preload("res://src/data.gd")
const DF = preload("res://src/data_fuehrung.gd")
const UI = preload("res://src/ui.gd")
const Guide = preload("res://src/guide.gd")
const ScreenFit = preload("res://src/screen_fit.gd")
const CD = preload("res://src/companion_data.gd")

const ELEMENTS := [["feuer", "Feuer", "ui_fire"], ["eis", "Eis", "ui_snow"], ["blitz", "Blitz", "ui_bolt"], ["gift", "Gift", "ui_skull"],
	["wasser", "Wasser", "ui_water"], ["explosion", "Explosion", "ui_alarm"]]

var S


func setup(arg) -> void:
	if not S.st.has("tab"):
		S.st["tab"] = 0
	if arg is String:
		for i in DF.HELP.size():
			if String(DF.HELP[i].key) == arg:
				S.st["tab"] = i


func build() -> Control:
	var page := clampi(int(S.st.tab), 0, DF.HELP.size() - 1)
	var row := UI.hbox(20)
	# ---- links: Seiten
	var list := UI.vbox(8)
	for i in DF.HELP.size():
		var p: Dictionary = DF.HELP[i]
		var nm := UI.label(String(p.title), 24)
		nm.clip_text = true
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(S.card_button(i == page, S.set_st("tab", i), UI.hbox(12, [UI.pic(String(p.icon), 48.0), nm]), 72.0))
	var ls: ScrollContainer = S.scroll(list, "help_pages", Vector2(380, 0))
	ls.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	row.add_child(ls)
	# ---- rechts: Inhalt
	var c := UI.vbox(12)
	var p2: Dictionary = DF.HELP[page]
	c.add_child(UI.hbox(14, [UI.pic(String(p2.icon), 64.0), S.head(String(p2.title), 38)]))
	for sec in p2.sections:
		var box := UI.vbox(4, [UI.label(String(sec[0]), 25, UI.GOLD), UI.text(String(sec[1]), 22)])
		c.add_child(UI.card(box, UI.NAVY_L, 14))
	match String(p2.key):
		"elemente":
			_elements(c)
		"waffen":
			_weapon_kinds(c)
		"begleiter":
			_companions(c)
		"warten":
			_times(c)
		"bedienung":
			_controls(c)
	var sc: ScrollContainer = S.scroll(c, "help_%d" % page)
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sc)
	return row


# ----------------------------------------------------------------- Tabellen
func _elements(c: VBoxContainer) -> void:
	var legend := UI.flow(14)
	for e in ELEMENTS:
		legend.add_child(UI.hbox(6, [UI.pic(String(e[2]), 34.0), UI.label(String(e[1]), 21)]))
	c.add_child(UI.card(legend, UI.NAVY_D, 10))
	for i in D.AREA_FAMILY.size():
		var fk := String(D.AREA_FAMILY[i])
		var fam: Dictionary = D.FAMILIES[fk]
		var a: Dictionary = D.AREAS[i]
		var nm := UI.label(String(fam.name), 23)
		var wt := UI.label(String(fam.weak_text), 21, UI.GOLD, false)
		wt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var txt := UI.vbox(0, [nm, UI.label(String(a.name), 18, UI.SKY, false), wt])
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_child(UI.card(UI.hbox(12, [UI.pic("area_" + String(a.key), 60.0, "ui_map"), txt]), UI.NAVY_L, 10))


func _weapon_kinds(c: VBoxContainer) -> void:
	var by := {}
	for wk in D.WEAPONS:
		var m := String(D.WEAPONS[wk].get("mode", ""))
		if not D.WEAPON_MODE_NAME.has(m):
			continue
		if not by.has(m):
			by[m] = []
		by[m].append(wk)
	var g := UI.grid(2, 10)
	for m in D.WEAPON_MODE_NAME:
		if not by.has(m):
			continue
		var list: Array = by[m]
		var names: Array = []
		for wk in list.slice(0, 3):
			names.append(String(D.WEAPONS[wk].name))
		var pic := UI.pic("w_" + String(list[0]), 52.0, "sword")
		var t := UI.vbox(0, [UI.label("%s (%d)" % [String(D.WEAPON_MODE_NAME[m]), list.size()], 22, UI.GOLD), UI.label(", ".join(names), 18, UI.TEXT, false)])
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(t.get_child(1) as Label).clip_text = true
		var card := UI.card(UI.hbox(10, [pic, t]), UI.NAVY_L, 8)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(card)
	c.add_child(g)


func _companions(c: VBoxContainer) -> void:
	for ck in CD.ORDER:
		var def: Dictionary = CD.COMPANIONS[ck]
		var ab: Array = []
		for a in def.abil:
			if CD.ABIL.has(a) and a != "area":
				ab.append(String(CD.ABIL[a][0]))
		var how: Array = []
		var gt: Dictionary = def.get("get", {})
		if gt.has("start"):
			how.append("von Anfang an")
		if gt.has("find"):
			how.append("befreien (%s)" % String(D.AREAS[clampi(int(gt.find), 0, D.AREAS.size() - 1)].name))
		if gt.has("craft"):
			how.append("bauen")
		if gt.has("buy"):
			how.append("kaufen")
		var t := UI.vbox(0, [UI.hbox(10, [UI.label(String(def.name), 23), UI.label(String(def.kind), 18, UI.SKY, false)]),
			UI.label("Kann: %s · Trägt %d" % [", ".join(ab), int(def.carry)], 19, UI.GOLD, false), UI.label("Bekommen: " + ", ".join(how), 18, UI.TEXT, false)])
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_child(UI.card(UI.hbox(12, [UI.pic("comp_" + ck, 60.0, "ui_pack"), t]), UI.NAVY_L, 10))


func _times(c: VBoxContainer) -> void:
	var g := UI.grid(2, 6)
	g.add_theme_constant_override("h_separation", 30)
	for lv in [2, 3, 4, 5, 6, 8, 10]:
		g.add_child(S.kv("Bunker Stufe %d" % lv, UI.time_text(D.build_time("bunker", lv)), 21))
	c.add_child(UI.card(UI.vbox(6, [UI.label("Bauzeiten (Beispiele)", 23, UI.GOLD), g]), UI.NAVY_L, 12))
	var g2 := UI.grid(2, 6)
	g2.add_theme_constant_override("h_separation", 30)
	for sec in [60, 300, 3600, 14400, 86400]:
		g2.add_child(S.kv("Restzeit %s" % UI.time_text(float(sec)), "%d Juwelen" % D.gem_cost(float(sec)) if D.gem_cost(float(sec)) > 0 else "gratis", 21))
	c.add_child(UI.card(UI.vbox(6, [UI.label("Sofort fertigstellen kostet", 23, UI.GOLD), g2]), UI.NAVY_L, 12))


# ----------------------------------------------------------------- Bedienung (Einstellungen von Paket F)
func _controls(c: VBoxContainer) -> void:
	var st: Dictionary = P.d.settings
	# Akku-Sparmodus
	var on := ScreenFit.battery_saver()
	var l := UI.text("Akku-Sparmodus: 30 Bilder pro Sekunde in der Basis und in Menüs, 60 im Kampf", 23, UI.WHITE, 0.0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := UI.button("An" if on else "Aus", S.act(func():
		st["akku"] = not on
		UI.sfx("ui_toggle", "", -6.0, 1.2 if not on else 0.9)
		P.mark()), "green" if on else "dark", 24, "ui_check" if on else "ui_close")
	b.custom_minimum_size = Vector2(150, 68)
	c.add_child(UI.card(UI.hbox(12, [UI.pic("ui_battery", 48.0), l, b]), UI.NAVY_L, 12))
	# Oberflächengröße
	var cur := int(st.get("ui_size", 0))
	var f := UI.flow(8)
	for i in DF.UI_SIZES.size():
		var k: int = i
		f.add_child(S.choice(String(DF.UI_SIZES[i][0]), i == cur, func():
			st["ui_size"] = k
			P.mark()
			if G.hud != null and G.hud.get("guide") != null:
				G.hud.guide.fit_root()
			S.refresh(), 22))
	var auto := "Automatisch: %s (Höhe etwa %d Punkte)" % ["groß" if ScreenFit.small_screen() else "normal", int(ScreenFit.points_height())]
	c.add_child(UI.card(UI.vbox(8, [UI.label("Größe der Anzeige im Spiel", 24, UI.GOLD), f, UI.label(auto, 19, UI.GREY, false)]), UI.NAVY_L, 12))
	# Tutorial und Ziele
	var tk := Guide.tut_key()
	var tt := "Tutorial: fertig" if tk == "" else "Tutorial: Schritt %d von %d" % [Guide.tut_step() + 1, DF.TUT_STEPS.size()]
	var rb := UI.button("Tutorial neu starten", S.act(func():
		Guide.tut_restart()
		S.toast("Das Tutorial beginnt von vorn.")), "dark", 22, "ui_recycle")
	rb.custom_minimum_size = Vector2(0, 64)
	var gl := UI.label("Ziele geschafft: %d" % int(P.d.goals.get("claimed", 0)), 21, UI.TEXT, false)
	c.add_child(UI.card(UI.vbox(8, [UI.label(tt, 24, UI.GOLD), gl, rb]), UI.NAVY_L, 12))
