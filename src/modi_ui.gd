extends RefCounted
## V6 Paket M – Oberflächen-Teile der Spielmodi außerhalb des Bildschirms „Modi“:
##   start_tower / start_surv   Kampfwelt (modi_arena.gd) starten
##   result_extra               Zusatz im Ergebnisfenster (hud.gd ruft es nach BasisUI.result_extra auf): Sterne, Zeit,
##                              erste Belohnung, Wochenpunkte, Punkte, Wellen-Belohnungen, Clan-Raid-Fortschritt,
##                              Knöpfe „Nochmal“ und „Nächstes Stockwerk“

const D = preload("res://src/data.gd")
const DM = preload("res://src/data_modi.gd")
const Modi = preload("res://src/modi.gd")
const UI = preload("res://src/ui.gd")
const Arena = preload("res://src/modi_arena.gd")


static func start_tower(f: int) -> void:
	await _start("tower", f)


static func start_surv() -> void:
	await _start("surv", 1)


static func _start(k: String, f: int) -> void:
	var m = G.main
	if m == null:
		return
	if m.screens.is_open():
		m.screens.close()
	if m.hud.modal_open():
		m.hud._close_modal()
	if m.loading.wanted():
		await m.loading.show_for("base")
	var w = Arena.new()
	w.init(k, f)
	m._swap(w)
	m.loading.done()


static func result_extra(hud, body: VBoxContainer, buttons: HBoxContainer, r: Dictionary) -> void:
	if r.has("tower"):
		_tower_extra(hud, body, buttons, r.tower)
	elif r.has("surv"):
		_surv_extra(hud, body, buttons, r.surv)
	elif bool(r.get("clan_raid", false)):
		var pr := float(r.get("progress", 0.0))
		body.add_child(UI.hbox(10, [UI.pic("ui_raid", 40.0, "ui_skull"), UI.label("Schaden: %s" % UI.fmt(float(r.get("dmg", 0))), 26, UI.GOLD)]))
		var bar := UI.bar(pr, UI.RED, Vector2(420, 24))
		body.add_child(UI.hbox(10, [UI.label("Clan %s:" % Modi.clan_name(), 21, UI.TEXT, false), bar, UI.label("%d %%" % int(pr * 100.0), 21, UI.GOLD)]))


static func _tower_extra(hud, body: VBoxContainer, buttons: HBoxContainer, tr: Dictionary) -> void:
	var f := int(tr.floor)
	var stars := int(tr.stars)
	var row := UI.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in 3:
		var got := i < stars
		var st := UI.icon("star", 72 if i == 1 else 60, UI.GOLD if got else Color(0.28, 0.31, 0.38))
		row.add_child(st)
		if got:
			st.modulate.a = 0.0
			var tw := st.create_tween()
			tw.tween_interval(0.3 + 0.3 * i)
			tw.tween_callback(func():
				st.modulate.a = 1.0
				UI.sfx("ui_claim", "click", -6.0, 1.0 + 0.15 * i))
	body.add_child(row)
	var rules := Modi.star_rules(f)
	var lines := UI.vbox(0)
	for i in rules.size():
		lines.add_child(UI.label(("✓ " if i < stars else "• ") + String(rules[i]), 19, UI.GREEN if i < stars else UI.TEXT, false))
	body.add_child(lines)
	var t := float(tr.get("time", 0.0))
	var tl := "Zeit: %s s" % ("%.1f" % t).replace(".", ",")
	if bool(tr.get("record", false)):
		tl += " · neue Bestzeit!"
	elif float(tr.get("best_time", 0.0)) > 0.0:
		tl += " · Bestzeit: %s s" % ("%.1f" % float(tr.best_time)).replace(".", ",")
	body.add_child(UI.stat_row("ui_clock", "Stockwerk %d" % f, tl, 23))
	if bool(tr.get("first", false)):
		body.add_child(UI.label("Erstmals geschafft – Belohnung:", 23, UI.SKY))
		body.add_child(UI.hbox(10, [UI.pic("ui_chest", 40.0), UI.label(Modi.bundle_text(tr.reward), 23, UI.GOLD)]))
	if int(tr.get("pts", 0)) > 0:
		body.add_child(UI.label("Wochenwertung: %s Punkte · Platz %d" % [UI.fmt(int(tr.get("week_score", 0))), Modi.my_rank("tower")], 21, UI.TEXT, false))
	var again := UI.button("Nochmal", func():
		hud._close_modal()
		start_tower(f), "dark", 28, "ui_replay")
	again.custom_minimum_size = Vector2(230, 92)
	buttons.add_child(again)
	if stars > 0 and f < DM.TOWER_FLOORS:
		var nx := UI.button("Stockwerk %d" % (f + 1), func():
			hud._close_modal()
			start_tower(f + 1), "gold", 28, "ui_up")
		nx.custom_minimum_size = Vector2(280, 92)
		buttons.add_child(nx)


static func _surv_extra(hud, body: VBoxContainer, buttons: HBoxContainer, sr: Dictionary) -> void:
	var sl := UI.label("0", 40, UI.GOLD)
	UI.count_up(sl, float(sr.score), 1.0, func(n: int) -> String: return "%s Punkte" % UI.fmt(n), 0.2)
	var hb := UI.hbox(14, [UI.pic("ui_survival", 64.0, "ui_star"), sl])
	if bool(sr.get("record", false)):
		hb.add_child(UI.new_tag(20))
		hb.add_child(UI.label("Neuer Bestwert!", 24, UI.GREEN))
	body.add_child(hb)
	body.add_child(UI.label("Welle %d erreicht · Bestwert: %s · Platz %d der Woche" % [int(sr.wave), UI.fmt(int(Modi.surv().best)), Modi.my_rank("surv")], 21, UI.TEXT, false))
	for e in sr.get("rewards", []):
		body.add_child(UI.hbox(10, [UI.pic("ui_chest", 36.0), UI.label("Welle %d erstmals erreicht: %s" % [int(e[0]), Modi.bundle_text(e[1])], 21, UI.GOLD)]))
	var again := UI.button("Nochmal", func():
		hud._close_modal()
		start_surv(), "dark", 28, "ui_replay")
	again.custom_minimum_size = Vector2(230, 92)
	buttons.add_child(again)
