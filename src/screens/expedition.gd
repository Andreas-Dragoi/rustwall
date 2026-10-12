extends RefCounted
## Bildschirm "Expedition" (V3): Weltkarte mit den acht Gebieten. Je Gebiet: Zustand der Außenbasis
## (nicht gebaut / Stufe 1–5 / belagert), empfohlene Heldenstufe, Treibstoff, Vorteil und Preis der nächsten Stufe.
## Schwierigkeit bleibt wählbar. Eine belagerte Außenbasis blinkt rot; Los startet dann die Befreiung.

const D = preload("res://src/data.gd")
const UI = preload("res://src/ui.gd")

## Lage der Gebiete auf der Karte (Anteile der Kartenfläche), von unten links nach oben rechts.
const MAP_POS := [Vector2(0.15, 0.86), Vector2(0.45, 0.74), Vector2(0.18, 0.54), Vector2(0.50, 0.42), Vector2(0.82, 0.56), Vector2(0.80, 0.24), Vector2(0.42, 0.11), Vector2(0.12, 0.25)]
const MAP_SIZE := Vector2(760, 860)
const NODE := Vector2(176, 156)

var S


func setup(arg) -> void:
	if arg is int or arg is float:
		S.st["area"] = clampi(int(arg), 0, D.AREAS.size() - 1)
	if not S.st.has("area"):
		var best := 0
		for i in D.AREAS.size():
			if P.area_unlocked(i):
				best = i
		var sg := P.outpost_besieged()
		for i in D.AREAS.size():
			if String(D.AREAS[i].key) == sg:
				best = i
		S.st["area"] = best
	if not S.st.has("diff"):
		S.st["diff"] = 0


func _diff_open(area: int, diff: int) -> bool:
	if diff <= 0:
		return true
	return bool(P.d.areas.boss[area][diff - 1])


func build() -> Control:
	var area := clampi(int(S.st.area), 0, D.AREAS.size() - 1)
	var row := UI.hbox(20)
	row.add_child(_map(area))
	var v := UI.vbox(10)
	var right := UI.vbox(10, [S.scroll(v, "exp_detail")])
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var def: Dictionary = D.AREAS[area]
	var ak := String(def.key)
	var unlocked: bool = P.area_unlocked(area)
	var o: Dictionary = P.outpost(ak)
	var lv := int(o.level)
	var sieged := bool(o.siege)
	var diff := clampi(int(S.st.diff), 0, D.DIFFS.size() - 1)
	while diff > 0 and not _diff_open(area, diff):
		diff -= 1
	S.st["diff"] = diff
	# ---- Kopf: Bild, Name, Stufe
	var nm := UI.label(String(def.name), 46)
	nm.add_theme_constant_override("outline_size", 12)
	var pic := UI.frame(UI.pic("area_" + ak, 150.0, "ui_expedition"), null, 16, Color("8FC0FF"))
	pic.custom_minimum_size = Vector2(170, 150)
	var head := UI.vbox(4, [UI.hbox(12, [nm, UI.badge("Gebiet %d" % (area + 1), Color("24508F"), 20)]), UI.text(String(def.text), 22, UI.WHITE)])
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.hbox(16, [pic, head]))
	if not unlocked:
		v.add_child(UI.card(UI.hbox(12, [UI.icon("lock", 40.0, UI.GOLD), UI.label(String(P.area_lock_text(area)), 23, UI.GOLD)]), Color("4A3A1C"), 12, UI.GOLD))
	# ---- Fakten
	var fam: Dictionary = D.FAMILIES[D.AREA_FAMILY[area]]
	var facts := UI.flow(10)
	facts.add_child(UI.pill(UI.hbox(8, [UI.pic("ui_helmet", 32.0), UI.label("Empfohlen: Heldenstufe %d" % int(D.EXP_HERO_LEVEL[area]), 20)])))
	facts.add_child(UI.pill(UI.hbox(8, [UI.label("Treibstoff:", 20, UI.TEXT, false), UI.cost_row({"fuel": P.fuel_cost(area)}, 22)])))
	var rr := UI.hbox(6, [UI.label("Baustoffe:", 20, UI.TEXT, false)])
	for r in D.EXP_AREAS[area].mats:
		rr.add_child(UI.icon(String(r), 34.0))
	facts.add_child(UI.pill(rr))
	var WS = preload("res://src/welt_state.gd")         # Paket Welt: Tagebuch des Gebiets
	var jb := UI.button("Tagebuch %d/%d" % [WS.pages(ak).size(), preload("res://src/data_welt.gd").JOURNAL[ak].size()], func(): S.open("tagebuch", {"tab": area}), "dark", 20, "p_journal")
	jb.custom_minimum_size = Vector2(0, 52)
	facts.add_child(jb)
	v.add_child(facts)
	v.add_child(UI.hbox(10, [UI.enemy_pic(0, 44.0), UI.label("%s – %s" % [String(fam.name), String(fam.weak_text)], 21, UI.TEXT, false)]))
	# ---- Außenbasis
	v.add_child(S.head("Außenbasis: %s" % String(D.OUTPOSTS[ak].special), 25))
	var state := "nicht gebaut"
	var scol := UI.GREY
	if lv >= 1:
		state = "Stufe %d von %d" % [lv, D.OUTPOST_MAX_LEVEL]
		scol = UI.GREEN
	if sieged:
		state = "BELAGERT – Vorteil ruht"
		scol = UI.RED
	var ob := UI.vbox(4, [UI.label(state, 26, scol)])
	var show_lv := maxi(lv, 1)
	ob.add_child(UI.label("Vorteil%s:" % (" (ab Stufe 1)" if lv < 1 else ""), 20, UI.TEXT, false))
	for e in D.OUTPOSTS[ak].effects:
		ob.add_child(UI.label("• " + P.outpost_effect_text(e, show_lv), 21, UI.GOLD if lv >= 1 and not sieged else UI.WHITE))
	var next_cost := _next_cost(area, lv)
	if lv >= 3:
		ob.add_child(UI.label(preload("res://src/liveops.gd").challenge_text(ak), 19, Color("FFB0A0"), false))     # Paket L: Gebietsboss-Herausforderung
	if lv < D.OUTPOST_MAX_LEVEL:
		ob.add_child(UI.hbox(8, [UI.label("Preis %s:" % ("Aufbau" if lv < 1 else "Stufe %d" % (lv + 1)), 20, UI.TEXT, false), UI.cost_row(next_cost, 21, false)]))
		ob.add_child(S.hint("Bezahlt wird vor Ort aus dem Rucksack; Teilzahlungen bleiben erhalten.", 18))
	var spic := UI.pic("o_special_%s%s" % [ak, "" if lv >= 5 else "_1"], 110.0, "ui_flag")
	var oc := UI.card(UI.hbox(14, [spic, ob]), Color("4A1C24") if sieged else UI.NAVY_L, 12, UI.RED if sieged else Color(0, 0, 0, 0))
	v.add_child(oc)
	if sieged:
		v.add_child(UI.info_box("Befreiung: kurze Expedition zum halben Treibstoffpreis. Wehre drei Wellen in vier Minuten ab.", 21, "ui_alarm"))
	# ---- Boss und Schwierigkeit
	var boss_row := UI.hbox(10, [UI.icon("skull", 32.0, UI.RED), UI.label("Boss: %s" % String(D.BOSSES[int(def.boss)].name), 22)])
	for dd in D.DIFFS.size():
		var beaten := bool(P.d.areas.boss[area][dd])
		boss_row.add_child(UI.badge("%s: %s" % [String(D.DIFFS[dd].name), "besiegt" if beaten else "offen"], Color("2E8A22") if beaten else Color("3A5788"), 16))
	v.add_child(boss_row)
	var df := UI.hbox(10)
	for dd in D.DIFFS.size():
		var open := _diff_open(area, dd)
		var db: Button = S.choice(String(D.DIFFS[dd].name), dd == diff, S.set_st("diff", dd), 22, "ui_skull" if open else "ui_lock")
		db.custom_minimum_size = Vector2(170, 64)
		UI.disable(db, not open)
		df.add_child(db)
	var dinfo: Dictionary = D.DIFFS[diff]
	df.add_child(UI.pill(UI.label(("Gegner ×%.1f · Beute ×%.1f" % [float(dinfo.hp), float(dinfo.loot)]).replace(".", ","), 20, UI.GOLD)))
	v.add_child(df)
	v.add_child(preload("res://src/liveops_ui.gd").nightmare_box(S, area, diff))     # Paket L: Albtraum+
	# ---- Aufstellung und Start (bleibt unten stehen)
	var hk := String(P.d.hero_sel)
	var vk: String = P.vehicle_sel()
	var busy: bool = P.hero_busy(hk)
	var lo := UI.hbox(12)
	var hb: Button = S.card_button(false, func(): S.open("heroes"), UI.hbox(10, [UI.hero_pic(hk, 76.0),
		UI.vbox(-2, [UI.label(String(D.HEROES[hk].name), 22), UI.label("Unterwegs!" if busy else "Stufe %d" % int(P.hero(hk).level), 18, UI.RED if busy else UI.TEXT, false)])]), 96.0)
	hb.custom_minimum_size = Vector2(250, 96)
	lo.add_child(hb)
	var vb: Button = S.card_button(false, func(): S.open("garage"), UI.hbox(10, [UI.vehicle_pic(vk, 76.0),
		UI.vbox(-2, [UI.label(String(D.VEHICLES[vk].name) if vk != "" else "Zu Fuß", 22), UI.label("Fahrzeug", 18, UI.TEXT, false)])]), 96.0)
	vb.custom_minimum_size = Vector2(230, 96)
	lo.add_child(vb)
	lo.add_child(UI.spacer(true))
	var mission := "befreiung" if sieged else "expedition"
	var go := UI.button("Befreien!" if sieged else "Los!", func(): _go(area, mission, diff), "red" if sieged else "green", 40, "ui_expedition")
	go.custom_minimum_size = Vector2(240, 96)
	UI.disable(go, not unlocked or busy)
	go.set_meta("go", true)
	lo.add_child(go)
	right.add_child(lo)
	return row


## Restpreis der nächsten Ausbaustufe (bzw. des Erstaufbaus: alle Pflichtplätze).
func _next_cost(area: int, lv: int) -> Dictionary:
	var ak := String(D.AREAS[area].key)
	var out := {}
	for pd in D.OUTPOST_PADS:
		var pl := int(pd.level)
		if (lv < 1 and pl == 1 and bool(pd.get("must", false))) or (lv >= 1 and pl == lv + 1):
			var price := P.outpost_pad_price(area, pd)
			var paid := P.outpost_paid(ak, String(pd.key))
			for r in price:
				var rest := int(price[r]) - int(float(paid.get(r, 0.0)))
				if rest > 0:
					out[r] = int(out.get(r, 0)) + rest
	return out


func _go(area: int, mission: String, diff: int) -> void:
	var cost := {"fuel": P.fuel_cost(area)}
	if not P.pay(cost):
		S.say(P.missing_text(cost))
		return
	UI.sfx("ui_buy", "pay", -2.0)
	S.request_expedition(area, mission, diff)


## Weltkarte: Gebiete als Knöpfe auf einer gezeichneten Landschaft, verbunden durch einen Pfad.
func _map(sel: int) -> Control:
	var m := MapBack.new()
	m.custom_minimum_size = MAP_SIZE
	m.clip_contents = true
	m.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for i in D.AREAS.size():
		m.pts.append(MAP_POS[i] * MAP_SIZE)
		m.open.append(P.area_unlocked(i))
	for i in D.AREAS.size():
		var def: Dictionary = D.AREAS[i]
		var ak := String(def.key)
		var unlocked: bool = P.area_unlocked(i)
		var o: Dictionary = P.outpost(ak)
		var lv := int(o.level)
		var img := UI.pic("area_" + ak, 78.0, "ui_expedition")
		if not unlocked:
			img.modulate = Color(0.45, 0.52, 0.7)
		var nm := UI.label(String(def.name), 19)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var st := "–" if lv < 1 else "Stufe %d" % lv
		var col := UI.GREY if lv < 1 else UI.GREEN
		if bool(o.siege):
			st = "belagert!"
			col = UI.RED
		if not unlocked:
			st = "gesperrt"
		var sl := UI.label(st, 16, col)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var content := UI.vbox(-2, [img, nm, sl])
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		var b: Button = S.card_button(i == sel, S.set_st("area", i), content, NODE.y)
		b.custom_minimum_size = NODE
		b.size = NODE
		b.position = MAP_POS[i] * MAP_SIZE - NODE * 0.5
		b.position = b.position.clamp(Vector2.ZERO, MAP_SIZE - NODE)
		b.tooltip_text = "%s – %s" % [String(def.name), String(D.OUTPOSTS[ak].special)]
		if bool(o.siege):
			var tw := b.create_tween().set_loops()
			tw.tween_property(b, "modulate", Color(1.0, 0.45, 0.45), 0.45)
			tw.tween_property(b, "modulate", Color.WHITE, 0.45)
		m.add_child(b)
	var sum := UI.label("Außenbasen %d/%d%s" % [P.outpost_count(), D.AREAS.size(), " · Talbund" if P.outpost_talbund() else ""], 20, UI.GOLD)
	sum.position = Vector2(14, MAP_SIZE.y - 34)
	m.add_child(sum)
	return m


class MapBack extends Control:
	var pts: Array = []
	var open: Array = []

	func _draw() -> void:
		var s := size
		draw_style_box(load("res://src/ui.gd").panel_style(Color("1E4D3A"), Color("3B7BD0"), 22, 0, 8), Rect2(Vector2.ZERO, s))
		# Landschaft: Flecken für Wald, Wüste, Küste, Schnee, Krater (grob, nur zur Stimmung)
		var cols := [Color("5E8F3A"), Color("3F6B35"), Color("C99A52"), Color("D6BE7C"), Color("55703E"), Color("BFD2E6"), Color("7FB23A"), Color("4A3A3A")]
		if pts.size() > 7:                       # Vulkaninsel: Meer rund um die Insel
			draw_circle(pts[7], 165.0, Color(0.2, 0.45, 0.75, 0.45))
		for i in pts.size():
			draw_circle(pts[i], 150.0 if i < 7 else 118.0, Color(cols[i % cols.size()], 0.45 if i < 7 else 0.8))
		draw_rect(Rect2(Vector2(s.x * 0.88, 0), Vector2(s.x * 0.12, s.y)), Color(0.2, 0.45, 0.75, 0.35))
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b2: Vector2 = pts[i + 1]
			var n := int(a.distance_to(b2) / 14.0)
			for k in n:
				if k % 2 == 0:
					draw_line(a.lerp(b2, float(k) / n), a.lerp(b2, float(k + 1) / n), Color(1, 0.95, 0.75, 0.9 if open[i + 1] else 0.35), 4.0)
