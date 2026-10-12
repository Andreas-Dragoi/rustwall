extends RefCounted
## Bildschirm "Garderobe" (Paket L): Helden-Skins, Waffen-Skins, Bunker-Skins, Fahnen und Begleiter-Hüte mit
## 3D-Vorschau anlegen; dazu der täglich wechselnde Kosmetik-Shop (Juwelen). Alles nur Aussehen – keine Stärke.
## arg: {"tab": n} (0 Helden, 1 Waffen, 2 Bunker, 3 Fahnen, 4 Hüte, 5 Shop)

const D = preload("res://src/data.gd")
const DL = preload("res://src/data_liveops.gd")
const Models = preload("res://src/models.gd")
const LO = preload("res://src/liveops.gd")
const LOW = preload("res://src/liveops_world.gd")
const UI = preload("res://src/ui.gd")
const CD = preload("res://src/companion_data.gd")
const CompanionPose = preload("res://src/companion_pose.gd")

const TABS := ["Helden", "Waffen", "Bunker", "Fahnen", "Hüte", "Shop"]
const TAB_ICONS := ["ui_helmet", "lo_wskin_gold", "b_bunker_1", "ui_flag", "lo_hat_zylinder", "res_gems"]
const KINDS := ["skin", "wskin", "bskin", "flag", "hat", "shop"]

var S


func build() -> Control:
	var v := UI.vbox(12)
	var shop_n := 0
	for id in LO.shop_offers():
		if not LO.owned(String(id)):
			shop_n += 1
	var names: Array = TABS.duplicate()
	names[5] = "Shop (%d)" % shop_n if shop_n > 0 else "Shop"
	v.add_child(S.tabs(names, "tab", 22, TAB_ICONS))
	var tab := clampi(int(S.st.get("tab", 0)), 0, TABS.size() - 1)
	var kind: String = KINDS[tab]
	if not S.st.has("hero"):
		S.st["hero"] = String(P.d.hero_sel)
	var hk := String(S.st.hero)
	var row := UI.hbox(20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# ---- Liste
	var items: Array = []
	if kind == "shop":
		items = LO.shop_offers().duplicate()
		var deal := LO.shop_deal()
		if deal != "":
			items.push_front(deal)
	else:
		items = [""] + LO.list_kind(kind, hk if kind == "skin" else "")
	var sel := String(S.st.get("sel_" + kind + (hk if kind == "skin" else ""), "~"))
	if sel == "~" or not (sel in items):
		sel = LO.equipped(kind, hk) if kind != "shop" else (String(items[0]) if not items.is_empty() else "")
	var left := UI.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.35
	if kind == "skin":
		var hr := UI.flow(8)
		for h in D.HERO_ORDER:
			var hkey := String(h)
			var b: Button = S.choice(String(D.HEROES[hkey].name).split(" ")[0], hkey == hk, S.set_st("hero", hkey), 20, "hero_" + hkey)
			b.custom_minimum_size = Vector2(0, 58)
			hr.add_child(b)
		left.add_child(hr)
	if kind == "shop":
		var tl := UI.label("", 21, UI.GOLD)
		S.live(tl, func() -> String: return "Neue Angebote in " + UI.time_text(LO.shop_left()))
		left.add_child(UI.hbox(12, [UI.pic("res_gems", 44.0), S.head("Kosmetik-Shop", 30), UI.spacer(true), tl]))
	var g := UI.grid(4, 10)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in items:
		g.add_child(_card(String(id), kind, hk, String(id) == sel))
	left.add_child(S.scroll(g, "list_" + kind))
	var note := "Kosmetik ist nur Aussehen – sie macht nicht stärker. Quellen: Saison-Pass, Ereignisse, Erfolge, Feiertage und der Shop."
	if kind == "shop":
		note = "Der Shop wechselt jeden Tag; das Angebot der Woche ist %d %% günstiger. Bezahlt wird mit Juwelen." % int(round((1.0 - DL.SHOP_DEAL) * 100.0))
	left.add_child(S.hint(note, 18))
	var lp := UI.panel(left, UI.NAVY, UI.EDGE, 22, 16)
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lp.size_flags_stretch_ratio = 1.15
	row.add_child(lp)
	# ---- Vorschau und Knopf
	var right := UI.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pk := LO.cos_kind(sel) if sel != "" else kind
	var pv: Control = _preview(pk, sel, hk)
	pv.custom_minimum_size = Vector2(520, 420)
	pv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var fr := UI.frame(pv, UI.scenery("meadow"), 18, Color("8FC0FF"))
	fr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(fr)
	right.add_child(_action(sel, kind, hk))
	row.add_child(right)
	v.add_child(row)
	return v


func _card(id: String, kind: String, hk: String, selected: bool) -> Control:
	var icon := ""
	var name := "Standard"
	if id == "":
		match kind:
			"skin":
				icon = "hero_" + hk
			"wskin":
				icon = "w_" + String(D.HEROES[String(P.d.hero_sel)].weapons[0])
			"bskin":
				icon = "b_bunker_%d" % clampi(int((P.bunker_level() + 1) / 2), 1, 5)
			"flag":
				icon = "ui_flag"
				name = "Keine Fahne"
			"hat":
				icon = "ui_close"
				name = "Kein Hut"
	else:
		icon = LO.cos_icon(id)
		name = LO.cos_name(id)
	var own := id == "" or LO.owned(id)
	var on := (LO.equipped(LO.cos_kind(id) if id != "" else kind, hk) == id) and kind != "shop"
	var pic := UI.pic(icon, 96.0, "ui_star")
	if not own:
		pic.modulate = Color(0.6, 0.65, 0.78)
	var hold := CenterContainer.new()
	hold.add_child(pic)
	var nl := UI.label(name, 19, UI.GOLD if on else UI.WHITE)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var inner := UI.vbox(2, [hold, nl])
	if kind == "shop":
		var kl := UI.label(String(DL.KIND_NAME[LO.cos_kind(id)]), 15, UI.TEXT, false)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(kl)
	var st := ""
	var col := UI.TEXT
	if on:
		st = "angelegt"
		col = UI.GREEN
	elif own and kind != "shop":
		st = "im Schrank"
	elif own:
		st = "✓ gekauft"
		col = UI.GREEN
	elif int(DL.COSMETICS[id].get("price", 0)) > 0 and (kind == "shop" or id in LO.shop_offers() or id == LO.shop_deal()):
		st = "%d Juwelen%s" % [LO.shop_price(id), " · Angebot!" if id == LO.shop_deal() else ""]
		col = Color("9FDCFF")
	else:
		st = "gesperrt"
		col = UI.GREY
	var sl := UI.label(st, 16, col, false)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(sl)
	var key := "sel_" + kind + (hk if kind == "skin" else "")
	var b: Button = S.card_button(selected, S.set_st(key, id), inner, 170.0)
	b.custom_minimum_size = Vector2(150, 176)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if id == LO.shop_deal() and kind == "shop":
		b.modulate = Color(1.05, 1.0, 0.85)
	return b


func _preview(kind: String, id: String, hk: String) -> Control:
	match kind:
		"skin":
			return S.preview_skin(hk, LO.cos_key(id) if id != "" else "", "-")
		"wskin":
			return S.preview_skin(String(P.d.hero_sel), "-", id)
		"bskin":
			var lv: int = P.bunker_level()
			return S.preview_model("bskin:%s:%d" % [id, lv], func() -> Node3D:
				var n := Models.building("bunker", lv)
				LO.apply_bunker_skin(n, id)
				return n, 17.0, 2.6)
		"flag":
			if id == "":
				return S.preview_model("flag:none", func() -> Node3D: return Node3D.new(), 6.0, 1.8)
			return S.preview_model("flag:" + id, func() -> Node3D: return Models.glb("lo_flag_" + LO.cos_key(id)), 7.5, 2.0)
		"hat":
			var ck: String = CD.active()
			if ck == "":
				if id == "":
					return S.preview_model("hat:none", func() -> Node3D: return Node3D.new(), 2.0, 0.3)
				return S.preview_model("hat:" + id, func() -> Node3D: return Models.glb("lo_hat_" + LO.cos_key(id)), 1.6, 0.25)
			var big: bool = ck in ["golem", "husky", "schnecke"]
			return S.preview_model("hat:%s:%s" % [ck, id], func() -> Node3D:
				var n: Node3D = CompanionPose.new().setup(ck)
				if id != "":
					LOW.put_hat(n, id)
				return n, 3.3 if big else 2.6, 0.6 if big else 0.45)
	return S.preview_model("none", func() -> Node3D: return Node3D.new(), 3.0, 1.0)


func _action(id: String, kind: String, hk: String) -> Control:
	var v := UI.vbox(8)
	if id == "":
		var on := LO.equipped(kind, hk) == ""
		var b := UI.button("Angelegt" if on else "Standard anlegen", S.act(func():
			LO.unequip(kind, hk)
			UI.sfx("ui_equip", "click", -6.0)), "dark" if on else "green", 26, "ui_check")
		UI.disable(b, on)
		b.custom_minimum_size = Vector2(0, 80)
		v.add_child(b)
		return v
	var def: Dictionary = DL.COSMETICS[id]
	var t := "%s „%s“" % [String(DL.KIND_NAME[LO.cos_kind(id)]), LO.cos_name(id)]
	if LO.cos_kind(id) == "skin":
		t += " für " + String(D.HEROES[String(def.hero)].name)
	v.add_child(UI.label(t, 26, UI.GOLD))
	if LO.owned(id):
		var on2 := LO.equipped(LO.cos_kind(id), String(def.get("hero", ""))) == id
		var b2 := UI.button("Angelegt" if on2 else "Anlegen", S.act(func():
			var why := LO.equip(id)
			if why != "":
				S.say(why)
			else:
				UI.sfx("ui_equip", "click", -4.0)
				S.preview_cheer()), "dark" if on2 else "green", 28, "ui_check")
		UI.disable(b2, on2)
		b2.custom_minimum_size = Vector2(0, 80)
		v.add_child(b2)
	elif id in LO.shop_offers() or id == LO.shop_deal():
		var price := LO.shop_price(id)
		var b3 := UI.button("Kaufen: %d" % price, func():
			S.confirm("%s für %d Juwelen kaufen?\nNur Aussehen – kein Vorteil im Kampf." % [t, price], func():
				var why := LO.shop_buy(id)
				if why == "":
					UI.sfx("ui_buy", "upgrade", -2.0)
					S.refresh()
				else:
					S.say(why), "Kaufen"), "gold", 28, "res_gems")
		b3.custom_minimum_size = Vector2(0, 80)
		UI.disable(b3, P.gems() < price and not G.ch("freegems"))
		v.add_child(b3)
	else:
		var src := String(def.get("src", ""))
		if src == "" and int(def.get("price", 0)) > 0:
			src = "Kosmetik-Shop (wenn es im Angebot ist), %d Juwelen" % int(def.price)
		v.add_child(UI.info_box("Noch nicht freigeschaltet. Quelle: %s" % src, 20, "ui_lock"))
	return v
