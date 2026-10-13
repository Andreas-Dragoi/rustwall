extends RefCounted
## Bildschirm „Auto-Expeditionen“ (V6 Paket E, Kapitel 4.3): alle Helden auf einen Blick – mehrere gleichzeitig losschicken,
## Restzeiten, Abholen mit Ergebnisbericht (Bild des Gebiets mit dem Helden, Ereignisliste, Beute, Verletzung),
## verletzte Helden heilen, die letzten Berichte nachlesen. Geöffnet aus „Expedition“ oder aus dem Helden-Reiter.

const D = preload("res://src/data.gd")
const DG = preload("res://src/data_geschichte.gd")
const UI = preload("res://src/ui.gd")
const Story = preload("res://src/story.gd")
const AutoRep = preload("res://src/auto_report.gd")

var S


func setup(_arg) -> void:
	Story.demo()


func build() -> Control:
	var v := UI.vbox(12)
	var away := 0
	var back := 0
	var hurt := 0
	for hk in D.HERO_ORDER:
		if not P.hero_unlocked(hk):
			continue
		if P.auto_ready(hk):
			back += 1
		elif P.hero_busy(hk):
			away += 1
		if Story.injured(hk):
			hurt += 1
	v.add_child(UI.hbox(14, [UI.pic("ui_expedition", 50.0), S.head("Auto-Expeditionen", 30), UI.spacer(true),
		UI.label("Unterwegs: %d · Zurück: %d · Verletzt: %d" % [away, back, hurt], 22, UI.TEXT, false)]))
	v.add_child(S.tabs(["Helden", "Berichte %d" % AutoRep.reports().size()], "tab", 22, ["ui_helmet", "ui_report"]))
	var body := UI.vbox(10)
	if int(S.st.get("tab", 0)) == 1:
		var reps := AutoRep.reports()
		if reps.is_empty():
			body.add_child(S.hint("Noch keine Berichte. Schicke einen Helden los – nach seiner Rückkehr erzählt er hier, was passiert ist."))
		for rep in reps:
			body.add_child(AutoRep.card(rep))
		AutoRep.mark_read()
	else:
		var shown = S.st.get("report", null)
		if shown is Dictionary and not (shown as Dictionary).is_empty():
			body.add_child(AutoRep.card(shown))
		body.add_child(S.hint("Helden, die gerade nicht gespielt werden, ziehen allein los und bringen Rohstoffe mit. Je höher die Gefahr, desto eher kommt jemand verletzt zurück und muss sich eine Weile erholen.", 20))
		for hk in D.HERO_ORDER:
			if P.hero_unlocked(hk):
				body.add_child(_hero_card(hk))
	v.add_child(S.scroll(body, "auto_%d" % int(S.st.get("tab", 0))))
	return v


func _free_others(hk: String) -> int:
	var n := 0
	for k in D.HERO_ORDER:
		if k != hk and P.hero_unlocked(k) and not P.hero_busy(k):
			n += 1
	return n


func _hero_card(hk: String) -> Control:
	var h: Dictionary = P.hero(hk)
	var name_l := UI.label("%s · Stufe %d" % [String(D.HEROES[hk].name), int(h.level)], 25, UI.WHITE)
	var col := UI.vbox(6, [name_l])
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UI.hbox(14, [UI.hero_pic(hk, 96.0), col])
	if P.auto_ready(hk):
		var area := int(h.auto_area)
		col.add_child(UI.label("Zurück aus %s!" % String(D.AREAS[clampi(area, 0, D.AREAS.size() - 1)].name), 22, UI.GREEN))
		var b := UI.button("Abholen", S.act(func():
			var got: Dictionary = P.collect_auto(hk)
			var rep := AutoRep.latest(hk)
			S.st["report"] = rep
			UI.sfx("ui_claim", "pay", -4.0)
			Sfx.play("auto_back", -4.0)
			if got.is_empty() and rep.is_empty():
				S.toast("Nichts mitgebracht – die Lager waren voll.")), "green", 26, "ui_chest")
		b.custom_minimum_size = Vector2(220, 74)
		row.add_child(b)
	elif P.hero_busy(hk):
		var area2 := int(h.auto_area)
		var tl := UI.label("", 24, UI.GOLD)
		S.live(tl, func() -> String: return UI.time_text(float(h.auto_until) - P.now()))
		S.every_second(tl, func():
			if P.auto_ready(hk):
				S.refresh())
		col.add_child(UI.hbox(10, [UI.label("Unterwegs: %s (%d Std) · zurück in" % [String(D.AREAS[clampi(area2, 0, D.AREAS.size() - 1)].name), int(h.auto_hours)], 21, UI.TEXT, false), tl]))
		var gc: int = P.auto_speed_cost(hk)
		var sb := UI.button("Sofort zurück" if gc <= 0 else "Sofort zurück  %d" % gc, S.act(func():
			if P.finish_auto(hk):
				UI.sfx("ui_buy", "upgrade", -4.0)
			else:
				UI.sfx("ui_error", "error", -6.0)), "green" if gc <= 0 else "gold", 22, "" if gc <= 0 else "res_gems")
		sb.custom_minimum_size = Vector2(240, 66)
		row.add_child(sb)
	elif Story.injured(hk):
		var tl2 := UI.label("", 22, UI.RED)
		S.live(tl2, func() -> String: return "Verletzt – erholt sich noch %s" % UI.time_text(Story.injury_left(hk)))
		S.every_second(tl2, func():
			if not Story.injured(hk):
				S.refresh())
		col.add_child(tl2)
		var hc := Story.heal_cost(hk)
		var hb := UI.button("Heilen" if hc <= 0 else "Heilen  %d" % hc, S.act(func():
			if hc > 0 and not P.spend_gems(hc, "Held geheilt"):
				UI.sfx("ui_error", "error", -6.0)
				return
			Story.heal(hk)
			UI.sfx("ui_buy", "upgrade", -4.0)), "gold" if hc > 0 else "green", 22, "res_gems" if hc > 0 else "ui_heart")
		hb.custom_minimum_size = Vector2(200, 66)
		row.add_child(hb)
	else:
		# Ziel und Dauer wählen, Gefahr ansehen, losschicken
		var areas: Array = []
		for i in D.AREAS.size():
			if P.area_unlocked(i):
				areas.append(i)
		if areas.is_empty():
			col.add_child(S.hint("Noch kein Gebiet freigeschaltet."))
			return UI.card(row, UI.NAVY_L, 12)
		var area3 := int(S.st.get("a_" + hk, areas[areas.size() - 1]))
		if not areas.has(area3):
			area3 = int(areas[areas.size() - 1])
		var hours := int(S.st.get("h_" + hk, D.AUTO_HOURS[0]))
		var nav := UI.hbox(8)
		var ai := areas.find(area3)
		var prev := UI.button("‹", S.set_st("a_" + hk, int(areas[(ai - 1 + areas.size()) % areas.size()])), "dark", 22)
		var nxt := UI.button("›", S.set_st("a_" + hk, int(areas[(ai + 1) % areas.size()])), "dark", 22)
		prev.custom_minimum_size = Vector2(56, 56)
		nxt.custom_minimum_size = Vector2(56, 56)
		var an := UI.label(String(D.AREAS[area3].name), 22, UI.GOLD)
		an.custom_minimum_size = Vector2(170, 0)
		an.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nav.add_child(prev)
		nav.add_child(an)
		nav.add_child(nxt)
		for hh in D.AUTO_HOURS:
			var cb: Button = S.choice("%d Std" % int(hh), int(hh) == hours, S.set_st("h_" + hk, int(hh)), 20)
			cb.custom_minimum_size = Vector2(96, 56)
			nav.add_child(cb)
		col.add_child(nav)
		col.add_child(UI.hbox(10, [AutoRep.danger_chip(hk, area3, hours), UI.cost_row({"fuel": P.fuel_cost(area3)}, 22)]))
		var go := UI.button("Losschicken", S.act(func():
			S.st.erase("report")
			if P.start_auto(hk, area3, hours):
				UI.sfx("ui_buy", "pay", -4.0)
				S.toast("%s ist losgezogen." % String(D.HEROES[hk].name))), "green", 24, "ui_expedition")
		go.custom_minimum_size = Vector2(220, 74)
		UI.disable(go, _free_others(hk) == 0)
		row.add_child(go)
		if _free_others(hk) == 0:
			col.add_child(UI.label("Ein Held muss in der Basis bleiben.", 19, UI.ORANGE, false))
	return UI.card(row, UI.NAVY_L, 12)


## Zusätze im Bildschirm „Expedition“ (Fakten des Gebiets): Knopf zu den Auto-Expeditionen, Hinweis auf eine Rettung.
static func exp_extras(S, facts: Control, area: int) -> void:
	var n := 0
	for hk in D.HERO_ORDER:
		if P.hero_unlocked(hk) and (P.hero_busy(hk) or Story.injured(hk)):
			n += 1
	var ab := UI.button("Auto-Expeditionen%s" % (" (%d)" % n if n > 0 else ""), func(): S.open("auto"), "dark", 20, "ui_report")
	ab.custom_minimum_size = Vector2(0, 52)
	facts.add_child(ab)
	for k in DG.RESCUE_ORDER:
		var r: Dictionary = DG.RESCUES[k]
		if int(r.area) == area and not Story.rescued(k):
			facts.add_child(UI.pill(UI.hbox(8, [UI.hero_pic(k, 40.0), UI.label("Gefangen: %s (%s)" % [String(r.title), String(r.event)], 20, UI.ORANGE)])))
