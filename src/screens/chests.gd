extends RefCounted
## Bildschirm "Beutekisten": Kisten öffnen, Chancen und Garantie-Zähler ansehen.

const D = preload("res://src/data.gd")
const UI = preload("res://src/ui.gd")
const Models = preload("res://src/models.gd")

const OPEN_ALL_MAX := 20

var S


func setup(arg) -> void:
	if arg is String and D.CHESTS.has(arg):
		S.st["sel"] = arg
	if not S.st.has("sel"):
		S.st["sel"] = ""
		for k in D.CHESTS:
			if P.chest_count(k) > 0:
				S.st["sel"] = k
				break
		if S.st.sel == "":
			S.st["sel"] = "daily"


func build() -> Control:
	var sel := String(S.st.sel)
	var row := UI.hbox(20)
	row.add_child(_list(sel))
	var right := UI.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var results = S.st.get("results", null)
	if results is Array and not results.is_empty():
		_results(right, results)
	else:
		_detail(right, sel)
	return row


func _list(sel: String) -> Control:
	var v := UI.vbox(10)
	var keys: Array = D.CHESTS.keys()
	# Kisten im Besitz zuerst
	keys.sort_custom(func(a, b):
		var ca := 1 if P.chest_count(a) > 0 else 0
		var cb := 1 if P.chest_count(b) > 0 else 0
		if ca != cb:
			return ca > cb
		return D.CHESTS.keys().find(a) < D.CHESTS.keys().find(b))
	for k in keys:
		var def: Dictionary = D.CHESTS[k]
		var n: int = P.chest_count(k)
		var nm := UI.label(String(def.name), 25)
		nm.clip_text = true
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cnt := UI.label("×%d" % n, 30, UI.GOLD if n > 0 else UI.GREY)
		var cp := UI.chest_pic(k, 80.0)
		if n <= 0:
			cp.modulate = Color(0.5, 0.56, 0.72)
			nm.add_theme_color_override("font_color", UI.GREY)
		var b: Button = S.card_button(k == sel, func():
			S.st["sel"] = k
			S.st.erase("results")
			S.st.erase("shown")
			S.refresh(), UI.hbox(12, [cp, nm, cnt]), 96.0)
		v.add_child(b)
	var sc: ScrollContainer = S.scroll(v, "chest_list", Vector2(420, 0))
	sc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return sc


func _open(type: String, all: bool) -> void:
	var out: Array = []
	var opened := 0
	while P.chest_count(type) > 0 and opened < (OPEN_ALL_MAX if all else 1):
		out.append_array(P.open_chest(type))
		opened += 1
	if opened == 0:
		S.toast("Davon hast du gerade keine Kiste.")
		return
	UI.sfx("chest_open", "chest", -2.0)
	S.st["results"] = out
	S.st["opened"] = opened


func _detail(c: VBoxContainer, sel: String) -> void:
	var def: Dictionary = D.CHESTS[sel]
	var n: int = P.chest_count(sel)
	var top := UI.hbox(18)
	var pv: Control = S.preview_model("chest:" + sel, func() -> Node3D: return Models.chest(def.color), 3.3, 0.36)
	pv.custom_minimum_size = Vector2(340, 270)
	pv.modulate = Color.WHITE
	top.add_child(UI.frame(pv, UI.scenery("night")))
	var info := UI.vbox(8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UI.label(String(def.name), 52)
	nm.add_theme_constant_override("outline_size", 12)
	info.add_child(UI.hbox(18, [nm, UI.label("×%d" % n, 52, UI.GOLD if n > 0 else UI.GREY)]))
	var t := "Enthält %d Stücke." % int(def.count)
	if def.has("min_rarity"):
		t += " Das erste Stück ist mindestens „%s“." % String(D.RARITY[int(def.min_rarity)].name)
	info.add_child(UI.text(t, 25, UI.WHITE))
	info.add_child(UI.spacer(false, Vector2(0, 6)))
	var btns := UI.hbox(14)
	var ob := UI.button("Öffnen", S.act(func(): _open(sel, false)), "green", 34, "ui_chest")
	ob.custom_minimum_size = Vector2(280, 92)
	UI.disable(ob, n <= 0)
	btns.add_child(ob)
	if n > 1:
		var ab := UI.button("Alle öffnen (%d)" % mini(n, OPEN_ALL_MAX), S.act(func(): _open(sel, true)), "gold", 28)
		ab.custom_minimum_size = Vector2(280, 92)
		btns.add_child(ab)
	info.add_child(btns)
	if n <= 0:
		info.add_child(UI.info_box("Du hast gerade keine Kiste dieser Art.", 21))
	top.add_child(info)
	c.add_child(top)

	var low := UI.hbox(14)
	low.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Chancen
	var ch := UI.vbox(6, [S.head("Chancen je Stück", 25)])
	var table: Array = def.table
	for r in 4:
		var rc: Color = S.rarity_color(r)
		var pct := float(table[r])
		var pt := ("%.1f %%" % pct).replace(".", ",") if pct != floorf(pct) else "%d %%" % int(pct)
		ch.add_child(UI.hbox(12, [UI.rarity_dot(rc, 26.0), _expand(UI.label(String(D.RARITY[r].name), 24, rc)), UI.label(pt, 25, UI.GOLD)]))
	ch.add_child(S.hint("%d %% der Stücke sind Waffen oder Ausrüstung, der Rest Rohstoffe, Bauteile und Abzeichen." % int(round(float(def.items) * 100.0)), 19))
	ch.add_child(S.head("Garantie", 25))
	var pe := int(P.d.pity_epic)
	var pl := int(P.d.pity_legend)
	ch.add_child(_pity_row("Episch spätestens in", D.PITY_EPIC - pe, float(pe) / D.PITY_EPIC, S.rarity_color(2)))
	ch.add_child(_pity_row("Legendär spätestens in", D.PITY_LEGEND - pl, float(pl) / D.PITY_LEGEND, S.rarity_color(3)))
	var chc := UI.card(S.scroll(ch, "chest_odds"), UI.NAVY, 18, Color(UI.EDGE, 0.8))
	chc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chc.size_flags_stretch_ratio = 1.0
	low.add_child(chc)
	# Herkunft
	var src := UI.vbox(4, [S.head("So bekommst du Kisten", 25)])
	var src_pic := ["daily", "quest", "level", "flood_gold", "find", "boss", "clan", "gift"]
	var src_lines := ["Tageskiste: erste Expedition des Tages", "Auftragskiste: alle drei Tagesaufträge", "Stufenkiste: bei jedem Stufenaufstieg",
			"Flutkisten: nach der Wochenflut (Holz, Silber, Gold)", "Fundkiste: unterwegs in Expeditionen", "Bosskiste: erster Sieg über einen Boss",
			"Clankiste: Wochenziel des Clans", "Geschenkkiste: von Freunden"]
	for li in src_lines.size():
		var parts: PackedStringArray = String(src_lines[li]).split(": ")
		var l := UI.text(parts[1], 20)
		var nl := UI.label(parts[0] + ":", 21, UI.WHITE)
		nl.custom_minimum_size = Vector2(190, 0)
		src.add_child(UI.hbox(10, [UI.chest_pic(String(src_pic[li]), 40.0), nl, l]))
	src.add_child(S.hint("Kisten kann man nicht kaufen. Alles im Spiel wird erspielt.", 20, UI.GREEN))
	var srcc := UI.card(S.scroll(src, "chest_src"), UI.NAVY, 18, Color(UI.EDGE, 0.8))
	srcc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srcc.size_flags_stretch_ratio = 1.25
	low.add_child(srcc)
	c.add_child(low)


func _expand(n: Control) -> Control:
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return n


func _pity_row(text: String, left: int, ratio: float, col: Color) -> Control:
	var v := UI.vbox(2)
	v.add_child(UI.hbox(8, [_expand(UI.label(text, 20, UI.TEXT, false)), UI.label("%d Kisten" % maxi(1, left), 21, col)]))
	v.add_child(UI.bar(ratio, col, Vector2(120, 18), "pity_" + text))
	return v


# ----------------------------------------------------------------- Ergebnis mit aufspringenden Karten
func _results(c: VBoxContainer, results: Array) -> void:
	var opened := int(S.st.get("opened", 1))
	var sel := String(S.st.sel)
	var title := "Das war drin:" if opened == 1 else "%d Kisten geöffnet – das war drin:" % opened
	var th := UI.label(title, 44)
	th.add_theme_constant_override("outline_size", 10)
	c.add_child(UI.hbox(16, [UI.chest_pic(sel, 84.0), th]))
	var g := UI.flow(14)
	var animate: bool = not S.st.get("shown", false)
	for i in results.size():
		g.add_child(_piece_card(results[i], i, animate))
	S.st["shown"] = true
	c.add_child(S.scroll(g, "chest_results"))
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var done := func():
		S.st.erase("results")
		S.st.erase("shown")
	var ok := UI.button("Weiter", S.act(done), "", 30, "ui_check")
	ok.custom_minimum_size = Vector2(260, 86)
	row.add_child(ok)
	var n: int = P.chest_count(sel)
	if n > 0:
		var again := UI.button("Noch eine öffnen (%d)" % n, S.act(func():
			S.st.erase("shown")
			_open(sel, false)), "green", 28, "ui_chest")
		again.custom_minimum_size = Vector2(380, 86)
		row.add_child(again)
	c.add_child(row)


func _piece_card(p: Dictionary, index: int, animate: bool) -> Control:
	var r := int(p.rarity)
	var rc: Color = S.rarity_color(r)
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(250, 236)
	var ic: Control
	match String(p.kind):
		"res":
			ic = UI.pic("res_" + String(p.res), 104.0)
		"badge":
			ic = UI.pic("ui_badge", 104.0)
		"blueprint":                         # V4: Bauplan einer Waffe (bläulich wie eine Blaupause)
			ic = UI.pic("w_" + String(p.get("key", "")), 104.0, "sword")
			ic.modulate = Color(0.55, 0.8, 1.0)
		_:
			var it: Dictionary = P.item(int(p.get("item", 0)))
			ic = UI.item_pic(it, 112.0) if not it.is_empty() else UI.tile("sword", 104.0, rc)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var t := UI.label(String(p.text), 22, rc.lightened(0.25) if String(p.kind) == "item" else UI.WHITE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sub_text := String(p.get("sub", ""))
	if sub_text == "":
		sub_text = String(D.RARITY[r].name)
	var sub := UI.badge(sub_text, rc.darkened(0.3) if r > 0 else Color("5F7399"), 16)
	sub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := UI.vbox(4, [ic, t, sub])
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var card := PanelContainer.new()
	var base := rc.darkened(0.62).lerp(UI.NAVY, 0.7 if r == 0 else 0.35)
	card.add_theme_stylebox_override("panel", UI.grad(base.lightened(0.12), base.darkened(0.2), rc, 20, 3, 10, 10 if r >= 2 else 0, Color(rc.r, rc.g, rc.b, 0.4), 0, Color.BLACK, 0.08))
	card.add_child(box)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	var anim := Control.new()
	anim.set_anchors_preset(Control.PRESET_FULL_RECT)
	anim.add_child(card)
	slot.add_child(anim)
	if String(p.kind) == "item":
		var nb := UI.new_tag(18)
		nb.position = Vector2(10, 10)
		anim.add_child(nb)
		# Waffen tragen die Farbe ihres Helden: "Für Yuki!"
		var wit: Dictionary = P.item(int(p.get("item", 0)))
		if not wit.is_empty() and wit.slot == "weapon":
			var hk := String(D.WEAPONS[wit.key].hero)
			var tag := UI.badge("Für %s!" % hk.capitalize(), D.HEROES[hk].color.darkened(0.15), 17)
			var face := UI.hero_pic(hk, 40.0)
			var who := UI.hbox(4, [face, tag])
			who.position = Vector2(86, 6)
			anim.add_child(who)
	if animate:
		anim.pivot_offset = slot.custom_minimum_size * 0.5
		anim.scale = Vector2(0.2, 0.2)
		anim.modulate.a = 0.0
		var tw := anim.create_tween()
		tw.tween_interval(0.25 + minf(0.13 * index, 3.0))
		tw.tween_callback(func(): UI.sfx("chest_item_%d" % clampi(r, 0, 3), "click", -10.0 + r * 3.0, 1.0 + r * 0.15))
		tw.set_parallel(true)
		tw.tween_property(anim, "modulate:a", 1.0, 0.12)
		tw.tween_property(anim, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return slot
