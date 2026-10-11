extends RefCounted
## Bildschirm "Aufträge und Flut": drei Tagesaufträge und die Übersicht zur Wochenflut.

const D = preload("res://src/data.gd")
const UI = preload("res://src/ui.gd")

const DIRS := ["Norden", "Osten", "Süden", "Westen"]

var S


func build() -> Control:
	var row := UI.hbox(20)
	var a := _quests()
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(a)
	var b := _flood()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = 1.15
	row.add_child(b)
	return row


func _quests() -> Control:
	var v := UI.vbox(10, [UI.hbox(14, [UI.pic("ui_quest", 52.0), S.head("Tagesaufträge", 34)])])
	var list: Array = P.d.quests.list
	for q in list:
		var prog := int(q.progress)
		var amt := int(q.amount)
		var done := prog >= amt
		var t := UI.text(String(q.text), 23, UI.WHITE)
		var bar := UI.bar(float(prog) / maxf(1.0, amt), UI.GREEN if done else D.C_BAR_BLUE, Vector2(160, 26))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var pl := UI.label("Erledigt" if done else "%s / %s" % [UI.fmt(prog), UI.fmt(amt)], 21, UI.GREEN if done else UI.GOLD)
		var qb := UI.vbox(6, [t, UI.hbox(12, [bar, pl])])
		qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.card(UI.hbox(14, [UI.pic("ui_check" if done else "ui_target", 52.0, "", UI.GREEN if done else UI.WHITE), qb]), Color("1F5A34") if done else UI.NAVY_L, 12, UI.GREEN if done else Color(0, 0, 0, 0)))
	if list.is_empty():
		v.add_child(S.hint("Heute gibt es keine Aufträge."))
	v.add_child(UI.spacer(true))
	var claimed := bool(P.d.quests.claimed)
	var all_done: bool = P.quests_done()
	var b: Button
	if claimed:
		b = UI.button("Schon abgeholt", Callable(), "dark", 28, "ui_check")
		UI.disable(b)
	else:
		b = UI.button("Auftragskiste abholen", S.act(func():
			if P.claim_quests():
				UI.sfx("ui_claim", "chest", -2.0)
				S.toast("Auftragskiste erhalten! Sie wartet im Kistenlager.")), "green", 28, "ui_chest")
		UI.disable(b, not all_done)
	b.custom_minimum_size = Vector2(0, 88)
	v.add_child(UI.hbox(14, [UI.chest_pic("quest", 84.0), UI.text("Alle drei Aufträge erfüllen bringt eine Auftragskiste.", 22)]))
	v.add_child(b)
	var tl := UI.label("", 20, UI.GREY, false)
	S.live(tl, func() -> String: return "Neue Aufträge in: " + UI.time_text(P.seconds_to_next_day()))
	v.add_child(tl)
	return UI.panel(v, UI.NAVY, UI.EDGE, 24, 20)


func _flood() -> Control:
	var wk: Dictionary = P.d.week
	var num := int(wk.number)
	var day: int = P.week_day()
	var fd: Dictionary = D.flood_def(num, P.bunker_level())
	var v := UI.vbox(8)
	v.add_child(UI.hbox(14, [UI.pic("ui_flood", 56.0), S.head("Wochenflut – Woche %d" % num, 34)]))
	# Tage
	var days := UI.hbox(6)
	for i in range(1, 8):
		var col := UI.GREEN if i < day else (UI.GOLD if i == day else UI.NAVY_L)
		if i == 7:
			col = UI.RED if day == 7 else Color("7A2A38")
		var l := UI.label("Flut" if i == 7 else str(i), 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var p := UI.card(l, col.darkened(0.3), 8, col.lightened(0.15))
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		days.add_child(p)
	v.add_child(days)
	var tl := UI.label("", 25, UI.GOLD)
	if bool(wk.flood_done):
		S.live(tl, func() -> String: return "Flut dieser Woche erledigt. Nächste Woche in: " + UI.time_text(P.flood_seconds_left()))
	elif day >= D.FLOOD_DAY:
		tl.add_theme_color_override("font_color", UI.RED)
		S.live(tl, func() -> String: return "Die Flut ist da! Noch Zeit: " + UI.time_text(P.flood_seconds_left()))
	else:
		S.live(tl, func() -> String: return "Tag %d von 7 · Die Flut kommt in: %s" % [P.week_day(), UI.time_text(P.flood_seconds_left())])
	v.add_child(tl)

	var g := UI.vbox(4)
	g.add_child(UI.stat_row("ui_flag", "Wellen", str(int(fd.waves)), 23))
	g.add_child(UI.stat_row("e_0", "Schleimlinge insgesamt", UI.fmt(float(fd.total)), 23))
	if P.flood_guest_text() != "":
		g.add_child(UI.stat_row("ui_alarm", P.flood_guest_text(), "", 23, UI.ORANGE))
	g.add_child(UI.stat_row("e_8", "Boss", "Ja" if fd.boss else "Nein", 23, UI.RED if fd.boss else UI.GREEN))
	g.add_child(UI.stat_row("ui_skull", "Stärke der Gegner", "×" + ("%.2f" % float(fd.hp)).replace(".", ","), 23))
	var dirs: Array = wk.dirs
	var names: Array = []
	for d in dirs:
		names.append(String(DIRS[clampi(int(d), 0, 3)]))
	g.add_child(UI.stat_row("ui_map", "Sie kommen aus", " und ".join(names), 23, UI.ORANGE))
	if wk.get("easier", false):
		g.add_child(S.hint("Nach der letzten Niederlage fällt diese Flut etwas schwächer aus.", 19, UI.GREEN))
	v.add_child(UI.card(g, UI.NAVY_L, 12))

	# eigene Verteidigung
	var score: float = P.defense_score()
	var need := float(fd.total) * float(fd.hp) * 0.55
	var ratio := score * 0.8 / maxf(need, 1.0)
	var verdict := "stark genug"
	var vcol := UI.GREEN
	if ratio < 0.7:
		verdict = "zu schwach – baue Türme und Mauern"
		vcol = UI.RED
	elif ratio < 1.0:
		verdict = "knapp – mit deinem Helden schaffbar"
		vcol = UI.ORANGE
	var dv := UI.vbox(4)
	dv.add_child(UI.stat_row("ui_shield", "Deine Verteidigung", UI.fmt(score), 23))
	dv.add_child(UI.bar(clampf(ratio, 0.0, 1.0), vcol, Vector2(200, 20)))
	dv.add_child(UI.label("Einschätzung: " + verdict, 21, vcol))
	v.add_child(UI.card(dv, UI.NAVY_L, 12))

	# letztes Ergebnis
	var last: Dictionary = wk.last
	var lv := UI.vbox(4, [UI.label("Letzte Flut", 23)])
	if last.is_empty():
		lv.add_child(S.hint("Noch keine Flut erlebt.", 21))
	else:
		var win := bool(last.get("win", false))
		var r := UI.hbox(8, [UI.label("Abgewehrt" if win else "Verloren", 24, UI.GREEN if win else UI.RED)])
		for i in int(last.get("stars", 0)):
			r.add_child(UI.icon("star", 34.0, UI.GOLD))
		r.add_child(UI.spacer(true))
		r.add_child(UI.label("%s Punkte" % UI.fmt(float(last.get("points", 0))), 22, UI.GOLD))
		lv.add_child(r)
		var ck := String(last.get("chest", ""))
		if D.CHESTS.has(ck):
			lv.add_child(UI.hbox(10, [UI.chest_pic(ck, 48.0), UI.label("Belohnung: " + String(D.CHESTS[ck].name), 21, UI.TEXT, false)]))
		var lost = last.get("lost", {})
		if lost is Dictionary and not lost.is_empty():
			lv.add_child(UI.hbox(8, [UI.label("Verloren:", 21, UI.RED, false), UI.cost_row(lost, 21, false)]))
	v.add_child(UI.card(lv, UI.NAVY_L, 12))
	v.add_child(S.hint("Am 7. Tag greift die Flut an. Startest du sie nicht selbst, verteidigt sich die Basis allein. An den Tagen davor kannst du einen Übungsalarm spielen.", 19))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_right", 2)
	m.add_child(v)
	return UI.panel(S.scroll(m, "flood"), UI.NAVY, UI.EDGE, 24, 20)
