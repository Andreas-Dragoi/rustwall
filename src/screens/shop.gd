extends RefCounted
## Bildschirm "Laden": Juwelen-Pakete, zusätzliche Baudrohnen, Flaggenfarben – und woher es Juwelen ohne Geld gibt.
## Juwelen kaufen nur Zeit, Baudrohnen und Aussehen. Kisten, Waffen und Rohstoffe gibt es dafür nicht.

const D = preload("res://src/data.gd")
const UI = preload("res://src/ui.gd")
const Store = preload("res://src/store.gd")
const CD = preload("res://src/companion_data.gd")

const FREE := [
	["ui_shield", "Tägliches Geschenk am Bunker", "5 bis 25, jeden Tag"],
	["ui_quest", "Tagesaufträge", "3 je Auftrag, 10 für alle drei"],
	["ui_recycle", "Gestrüpp, Stümpfe und Steine wegräumen", "1 bis 3"],
	["ui_flood", "Flut gewonnen / Übungsalarm gewonnen", "20 / 3"],
	["ui_star", "Spielerstufe steigt", "10"],
	["ui_helmet", "Heldenstufe 5, 10, 15 …", "5"],
	["ui_trophy", "Erfolge", "10 bis 100"],
]

var S


func build() -> Control:
	var row := UI.hbox(22)
	# ---- links: Pakete
	var left := UI.vbox(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.5
	left.add_child(UI.hbox(14, [UI.pic("res_gems", 56.0), S.head("Juwelen", 34), UI.spacer(true), UI.pill(UI.hbox(8, [UI.pic("res_gems", 34.0), UI.label(UI.fmt(P.gems()), 28, Color("9FDCFF"))]))]))
	var g := UI.grid(3, 12)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in D.GEM_PACKS.size():
		g.add_child(_pack(D.GEM_PACKS[i], i))
	left.add_child(S.scroll(g, "packs"))
	left.add_child(UI.info_box(Store.note(), 20))
	row.add_child(left)
	# ---- rechts: wofür und woher
	var right := UI.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var use := UI.vbox(10, [S.head("Dafür sind Juwelen da", 28)])
	use.add_child(UI.hbox(12, [UI.pic("ui_clock", 40.0), UI.text("Bauten, Verbesserungen und Auto-Expeditionen sofort fertigstellen. Die letzte Minute ist immer gratis.", 21, UI.TEXT, 480)]))
	var dp: int = P.drone_price()
	var dtxt := UI.vbox(0, [UI.label("Zusätzliche Baudrohne", 24), UI.label("Du hast %d. Eine mehr baut ein Gebäude mehr gleichzeitig." % P.drones_total(), 19, UI.TEXT, false)])
	dtxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var drow := UI.hbox(12, [UI.pic("ui_drone", 52.0), dtxt])
	if dp > 0:
		var db := UI.button(str(dp), S.act(func():
			if P.buy_drone():
				UI.sfx("ui_buy", "upgrade", -4.0)
			else:
				UI.sfx("ui_error", "error", -6.0)), "gold", 26, "res_gems")
		db.custom_minimum_size = Vector2(170, 70)
		drow.add_child(db)
	else:
		drow.add_child(UI.badge("alle gekauft", Color("2F8D4E"), 20))
	use.add_child(UI.card(drow, UI.NAVY_L, 10))
	# Flaggenfarbe
	var fl := UI.flow(8)
	var owned: Array = P.d.flags_owned
	for i in D.FLAG_COLORS.size():
		var fc: Array = D.FLAG_COLORS[i]
		var has: bool = i in owned or float(i) in owned
		var cur: bool = int(P.d.flag_color) == i
		var idx: int = i
		var inner := UI.vbox(2, [S.swatch(Color(String(fc[1])), 46.0), UI.label(String(fc[0]) if has else str(int(fc[2])), 18, UI.WHITE if has else Color("9FDCFF"))])
		var fb: Button = S.card_button(cur, S.act(func():
			if P.pick_flag(idx):
				UI.sfx("ui_equip", "click", -6.0)), inner, 84.0)
		fb.custom_minimum_size = Vector2(92, 88)
		fb.tooltip_text = "Flaggenfarbe %s" % String(fc[0])
		fl.add_child(fb)
	use.add_child(UI.card(UI.vbox(6, [UI.hbox(10, [UI.pic("ui_flag", 40.0), UI.label("Farbe deiner Flaggen", 24)]), fl]), UI.NAVY_L, 10))
	use.add_child(_companions())
	use.add_child(UI.info_box("Kisten, Waffen und Rohstoffe gibt es nicht für Juwelen. Stärke wird erspielt.", 19, "ui_lock"))
	right.add_child(UI.panel(use, UI.NAVY, UI.EDGE, 22, 18))
	var free := UI.vbox(6, [S.head("Juwelen ohne Geld", 28)])
	for f in FREE:
		free.add_child(UI.stat_row(String(f[0]), String(f[1]), String(f[2]), 21, Color("9FDCFF")))
	var eb := UI.button("Erfolge ansehen", func(): S.open("erfolge"), "dark", 24, "ui_trophy")
	eb.custom_minimum_size = Vector2(0, 66)
	free.add_child(eb)
	var fp := UI.panel(S.scroll(free, "free"), UI.NAVY, UI.EDGE, 22, 18)
	fp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(fp)
	row.add_child(right)
	return row


func _pack(p: Dictionary, i: int) -> Control:
	var v := UI.vbox(6)
	var pic := UI.pic("res_gems", 70.0 + i * 12.0)
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, 136)
	holder.add_child(pic)
	v.add_child(holder)
	var n := UI.label(UI.fmt(float(p.gems)), 38, Color("9FDCFF"))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var nm := UI.label(String(p.name), 22, UI.TEXT)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	var key := String(p.key)
	var b := UI.button(String(p.price) if not Store.test_mode() else "Testkauf", S.act(func():
		var why := Store.buy(key)
		if why == "":
			UI.sfx("ui_buy", "upgrade", -2.0)
			S.toast("+%s Juwelen" % UI.fmt(float(p.gems)))
		else:
			S.say(why)), "green", 26)
	b.custom_minimum_size = Vector2(0, 70)
	b.tooltip_text = "Im Laden später: %s" % String(p.price)
	v.add_child(b)
	if Store.test_mode():
		var pl := UI.label("später %s" % String(p.price), 17, UI.GREY, false)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(pl)
	var c := UI.card(v, UI.NAVY_L, 14, Color(UI.EDGE, 0.6))
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## Begleiter zu kaufen (Paket B): Bild, Name, Preis, Knopf; gekaufte zeigen einen Haken.
func _companions() -> Control:
	var v := UI.vbox(6, [UI.hbox(10, [UI.pic("comp_kistenbein", 40.0), UI.label("Begleiter", 24)])])
	var fl := UI.grid(6, 6)
	for k in CD.ORDER:
		var g: Dictionary = CD.def(k).get("get", {})
		if not g.has("buy"):
			continue
		var key := String(k)
		var cost: Dictionary = g.buy
		var gem := cost.has("gems")
		var own := CD.owned(key)
		var inner := UI.vbox(2, [UI.pic("comp_" + key, 56.0, "star"), UI.label(String(CD.def(key).name).split(" ")[-1], 17, UI.WHITE, false)])
		var price := UI.hbox(4, [UI.pic("res_gems" if gem else "res_coins", 22.0), UI.label(UI.fmt(float(cost.gems if gem else cost.get("coins", 0))), 17, Color("9FDCFF") if gem else UI.GOLD)])
		inner.add_child(price if not own else UI.label("✓ dabei", 17, UI.GREEN))
		var b: Button = S.card_button(false, S.act(func():
			if CD.owned(key):
				S.open("begleiter", key)
				return
			var why := CD.buy(key)
			if why == "":
				UI.sfx("ui_buy", "upgrade", -2.0)
				S.toast("%s gehört jetzt dir!" % String(CD.def(key).name))
			else:
				UI.sfx("ui_error", "error", -6.0)
				S.say(why)), inner, 120.0)
		b.custom_minimum_size = Vector2(96, 118)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = "%s – %s" % [String(CD.def(key).name), String(CD.def(key).kind)]
		fl.add_child(b)
	v.add_child(fl)
	var more := UI.button("Alle Begleiter ansehen", func(): S.open("begleiter"), "dark", 22, "ui_star")
	more.custom_minimum_size = Vector2(0, 56)
	v.add_child(more)
	return UI.card(v, UI.NAVY_L, 10)
