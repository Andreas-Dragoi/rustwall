extends RefCounted
## Bildschirm "Garage": Fahrzeuge kaufen, auswählen und verbessern.
## Aufbau wie in der Vorlage: links die Liste mit Bildern, in der Mitte die große Vorschau im runden
## Rahmen vor einer Landschaft, rechts die Werte, darunter die Ausbauzeilen mit fünf Punkten.

const D = preload("res://src/data.gd")
const UI = preload("res://src/ui.gd")
const Models = preload("res://src/models.gd")

const CAM := {"quad": [5.2, 0.8], "bike": [5.6, 0.8], "buggy": [6.8, 1.0], "pickup": [8.0, 1.2], "hover": [6.6, 1.1]}
const SCENE := {"quad": "meadow", "bike": "forest", "buggy": "sand", "pickup": "meadow", "hover": "water"}
const UP_ICON := {"motor": "ui_motor", "body": "ui_body", "bed": "ui_bed"}

var S


func setup(arg) -> void:
	if arg is String and D.VEHICLES.has(arg):
		S.st["sel"] = arg
	if not S.st.has("sel"):
		var cur: String = P.vehicle_sel()
		S.st["sel"] = cur if cur != "" else String(D.VEHICLE_ORDER[0])


func build() -> Control:
	var sel := String(S.st.sel)
	var row := UI.hbox(22)
	row.add_child(_list(sel))
	var right := UI.vbox(14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if sel == "":
		_on_foot(right)
	else:
		_vehicle(right, sel)
	row.add_child(right)
	return row


func _list(sel: String) -> Control:
	var v := UI.vbox(10)
	var cur: String = P.vehicle_sel()
	var keys: Array = [""]
	keys.append_array(D.VEHICLE_ORDER)
	for k in keys:
		var nm_text := "Zu Fuß"
		var sub := "Ohne Fahrzeug"
		var col := UI.TEXT
		var owned := true
		var locked := false
		if k != "":
			var def: Dictionary = D.VEHICLES[k]
			owned = bool(P.d.vehicles[k].owned)
			nm_text = String(def.name)
			sub = String(def.kind)
			if not owned:
				locked = P.bunker_level() < int(def.bunker)
				sub = "Ab Bunker-Stufe %d" % int(def.bunker) if locked else "Zu kaufen"
				col = UI.GREY if locked else UI.GOLD
		if k == cur:
			sub = "Ausgewählt"
			col = UI.GREEN
		var nm := UI.label(nm_text, 31)
		nm.clip_text = true
		var sl := UI.sub_label(sub, 22, col, k == sel)
		sl.clip_text = true
		var txt := UI.vbox(-2, [nm, sl])
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic: Control = UI.vehicle_pic(k, 104.0)
		if not owned:
			ic.modulate = Color(0.55, 0.62, 0.78)
		var content := UI.hbox(14, [ic, txt])
		if locked:
			content.add_child(UI.icon("lock", 34.0, UI.GOLD))
		v.add_child(S.card_button(k == sel, S.set_st("sel", k), content, 118.0))
	var sc: ScrollContainer = S.scroll(v, "garage_list", Vector2(440, 0))
	sc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return sc


func _select_button(key: String) -> Button:
	var b: Button
	if P.vehicle_sel() == key:
		b = UI.button("Ausgewählt", Callable(), "dark", 30, "ui_check")
		UI.disable(b)
	else:
		b = UI.button("Auswählen", S.act(func():
			P.d.vehicle_sel = key
			P.mark()
			UI.sfx("ui_equip", "", -6.0)), "green", 30, "ui_check")
	b.custom_minimum_size = Vector2(440, 82)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b


func _on_foot(c: VBoxContainer) -> void:
	var top := UI.hbox(22)
	var cc := CenterContainer.new()
	cc.add_child(UI.pedestal(UI.pic("ui_walk", 250.0), 300.0))
	var fr := UI.frame(cc, UI.scenery("meadow"))
	fr.custom_minimum_size = Vector2(660, 410)
	var leftc := UI.vbox(12, [fr, _select_button("")])
	top.add_child(leftc)
	var info := UI.vbox(10)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UI.label("Zu Fuß", 62)
	nm.add_theme_constant_override("outline_size", 13)
	info.add_child(nm)
	info.add_child(UI.label("Ohne Fahrzeug", 29, Color("8FB8F0")))
	info.add_child(UI.text("Ohne Fahrzeug bist du langsamer und trägst weniger, brauchst aber keins zu besitzen.", 27, UI.WHITE))
	var stats := UI.vbox(12)
	stats.add_child(UI.stat_row("ui_speed", "Tempo", "×1,00", 30))
	stats.add_child(UI.stat_row("ui_crate", "Tragemenge", "+0 %", 30))
	stats.add_child(UI.sep(false, Color(UI.EDGE, 0.4)))
	stats.add_child(UI.hbox(14, [UI.pic("ui_info", 38.0, "", UI.SKY), UI.text("Der Auftrag „Wettlauf“ geht nur mit Fahrzeug.", 23, UI.SKY)]))
	info.add_child(UI.card(stats, UI.NAVY, 20, Color(UI.EDGE, 0.8)))
	top.add_child(info)
	c.add_child(top)


func _vehicle(c: VBoxContainer, key: String) -> void:
	var def: Dictionary = D.VEHICLES[key]
	var v: Dictionary = P.d.vehicles[key]
	var owned := bool(v.owned)
	var top := UI.hbox(22)
	# ---- Vorschau im runden Rahmen vor einer Landschaft
	var cam: Array = CAM.get(key, [9.0, 1.0])
	var pv: Control = S.preview_model("vehicle:" + key, func() -> Node3D: return Models.vehicle(key), float(cam[0]), float(cam[1]))
	pv.custom_minimum_size = Vector2(660, 410)
	pv.modulate = Color.WHITE
	var inner: Control = pv
	if not owned:
		# gesperrt: Vorschau abgedunkelt, großes Schloss darüber
		var hold := PanelContainer.new()
		hold.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		hold.add_child(pv)
		var shade := ColorRect.new()
		shade.color = Color(0.03, 0.08, 0.2, 0.45)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hold.add_child(shade)
		var cc := CenterContainer.new()
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(UI.icon("lock", 130.0, UI.GOLD))
		hold.add_child(cc)
		inner = hold
	var fr := UI.frame(inner, UI.scenery(String(SCENE.get(key, "meadow"))))
	var under: Control
	if owned:
		under = _select_button(key)
	else:
		var why := ""
		if not P.has_built("garage"):
			why = "Baue zuerst eine Garage"
		elif P.bunker_level() < int(def.bunker):
			why = "Ab Bunker-Stufe %d" % int(def.bunker)
		var lb := UI.button(why if why != "" else "Noch nicht gekauft", Callable(), "dark", 28, "ui_lock")
		UI.disable(lb)
		lb.custom_minimum_size = Vector2(440, 82)
		lb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		under = lb
	top.add_child(UI.vbox(12, [fr, under]))
	# ---- Name und Werte
	var info := UI.vbox(8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UI.label(String(def.name), 62 if String(def.name).length() <= 13 else 52)
	nm.add_theme_constant_override("outline_size", 13)
	nm.clip_text = true
	info.add_child(nm)
	info.add_child(UI.label(String(def.kind), 29, Color("8FB8F0")))
	info.add_child(UI.text(String(def.text), 27, UI.WHITE))
	var speed := float(def.speed)
	var hp := float(def.hp)
	if owned:
		var vs: Dictionary = P.vehicle_stats(key)
		speed = float(vs.speed)
		hp = float(vs.hp)
	var carry := float(def.carry) * (1.0 + 0.15 * int(v.bed))
	var stats := UI.vbox(8)
	stats.add_child(UI.stat_row("ui_speed", "Tempo", ("×%.2f" % speed).replace(".", ","), 30))
	stats.add_child(UI.stat_row("ui_heart", "Leben", str(int(round(hp))), 30))
	stats.add_child(UI.stat_row("ui_crate", "Tragemenge", "+%d %%" % int(round(carry * 100.0)), 30))
	var extras: Array = []
	var ex_icon := "ui_star"
	if def.get("ram", false):
		extras.append("rammt kleine Gegner")
		ex_icon = "ui_bolt"
	if def.get("turret", false):
		extras.append("eigenes Geschütz")
		ex_icon = "ui_target"
	if def.get("water", false):
		extras.append("fährt über Wasser")
		ex_icon = "ui_water"
	if not extras.is_empty():
		stats.add_child(UI.sep(false, Color(UI.EDGE, 0.4)))
		var el := UI.label("Besonders: " + ", ".join(extras), 26, UI.SKY)
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		el.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(UI.hbox(16, [UI.pic(ex_icon, 46.0, "", UI.SKY), el]))
	var sbox := UI.card(stats, UI.NAVY, 20, Color(UI.EDGE, 0.8))
	info.add_child(UI.spacer(false, Vector2(0, 4)))
	info.add_child(sbox)
	top.add_child(info)
	c.add_child(top)

	if not owned:
		# ---- Kaufen
		var cost: Dictionary = def.cost
		var blocked: bool = not P.has_built("garage") or P.bunker_level() < int(def.bunker)
		var b := UI.button("Kaufen", S.act(func():
			if P.buy_vehicle(key):
				UI.sfx("ui_buy", "pay", -2.0)
				S.toast("%s gehört jetzt dir!" % String(def.name))
			else:
				UI.sfx("ui_error", "error", -6.0)), "green", 34)
		b.custom_minimum_size = Vector2(300, 92)
		UI.disable(b, blocked)
		var pl := UI.vbox(0, [UI.label("Preis", 30), UI.label("Einmal kaufen, für immer behalten", 20, UI.GREY, false)])
		pl.custom_minimum_size = Vector2(330, 0)
		var cr := UI.cost_row(cost, 30)
		cr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := UI.hbox(22, [UI.pic("res_coins", 84.0), pl, UI.sep(true), cr, b])
		c.add_child(UI.card(row, UI.NAVY_L, 16))
		c.add_child(UI.info_box("Im Kampf steigst du mit T (oder dem Knopf) ein und aus. Jedes Fahrzeug lässt sich später dreifach ausbauen: Motor, Karosserie und Ladefläche.", 21))
		return

	# ---- Ausbau: Bild, Name, Wirkung, fünf Punkte, Kosten, Knopf
	var ups := UI.vbox(10)
	for up in D.VEHICLE_UPGRADES:
		var part := String(up[0])
		var lv := int(v[part])
		var nm2 := UI.vbox(-2, [UI.label(String(up[1]), 32), UI.label(String(up[2]) + " je Stufe", 23, UI.TEXT, false)])
		nm2.custom_minimum_size = Vector2(310, 0)
		nm2.alignment = BoxContainer.ALIGNMENT_CENTER
		var r := UI.hbox(22, [UI.pic(String(UP_ICON.get(part, "ui_gear")), 92.0), nm2, UI.pips(lv, 5, UI.GREEN, 34.0)])
		r.add_child(UI.spacer(true))
		if lv >= 5:
			r.add_child(UI.hbox(10, [UI.pic("ui_check", 40.0, "", UI.GREEN), UI.label("Voll ausgebaut", 26, UI.GREEN)]))
		else:
			var cost2: Dictionary = P.vehicle_upgrade_cost(key, part)
			var line := UI.sep(true, Color(UI.EDGE, 0.5))
			line.custom_minimum_size = Vector2(3, 56)
			line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			r.add_child(line)
			var cr2 := UI.cost_row(cost2, 30)
			cr2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			cr2.custom_minimum_size = Vector2(330, 0)
			r.add_child(cr2)
			var ub := UI.button("Verbessern", S.act(func():
				if P.upgrade_vehicle(key, part):
					UI.sfx("ui_upgrade", "upgrade", -4.0)
				else:
					UI.sfx("ui_error", "error", -6.0)), "green", 33)
			ub.custom_minimum_size = Vector2(290, 90)
			ub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			r.add_child(ub)
		var card := UI.card(r, UI.NAVY_L, 12)
		card.custom_minimum_size = Vector2(0, 118)
		ups.add_child(card)
	c.add_child(S.scroll(ups, "garage_ups"))
