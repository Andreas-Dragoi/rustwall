extends RefCounted
## Bildschirm „Begleiter“ (Paket B): alle zwölf Begleiter mit Bild, Werten, Besonderheiten, Stufe und wie man sie
## bekommt. Aktiven Begleiter wählen, herstellen, kaufen. Aufbau wie die Garage: links die Liste, rechts die große
## Vorschau des Modells (dreht sich, lässt sich drehen) und die Werte.

const D = preload("res://src/data.gd")
const UI = preload("res://src/ui.gd")
const CD = preload("res://src/companion_data.gd")
const Models = preload("res://src/models.gd")
const CompanionPose = preload("res://src/companion_pose.gd")
const DW = preload("res://src/data_welt.gd")
const WS = preload("res://src/welt_state.gd")

const ABIL_ICON := {"coins": "res_coins", "heavy": "ui_pack", "protect": "ui_shield", "mine": "ui_hammer", "dig": "ui_hammer",
	"chop": "res_wood", "scout": "ui_map", "luck": "ui_clover", "chests": "ui_chest", "fight": "ui_sword", "run": "ui_boot",
	"glow": "ui_star", "heal": "ui_heart", "area": "ui_map"}
const SCENE := {"kistenbein": "meadow", "esel": "sand", "schnecke": "meadow", "kaefer": "sand", "ziege": "meadow", "drohne": "meadow",
	"biber": "water", "waschbaer": "forest", "golem": "forest", "husky": "meadow", "eule": "forest", "gluehwurm": "forest"}

var S


func setup(arg) -> void:
	if arg is String and CD.COMPANIONS.has(arg):
		S.st["sel"] = arg
	if not S.st.has("sel"):
		var cur := CD.active()
		S.st["sel"] = cur if cur != "" else String(CD.ORDER[0])
	CD.state()["hello"] = true


func build() -> Control:
	var sel := String(S.st.sel)
	var row := UI.hbox(22)
	row.add_child(_list(sel))
	var right := UI.vbox(14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if sel == "":
		_alone(right)
	else:
		_detail(right, sel)
	row.add_child(right)
	return row


func _status(k: String) -> Array:
	if k == CD.active():
		return ["Dabei · Stufe %d" % CD.level(k), UI.GREEN]
	if CD.owned(k):
		return ["Stufe %d" % CD.level(k), UI.TEXT]
	var g: Dictionary = CD.def(k).get("get", {})
	if g.has("craft") and CD.can_craft(k) == "":
		return ["Herstellbar!", UI.GOLD]
	if g.has("buy"):
		return ["Zu kaufen", UI.GOLD]
	if g.has("craft"):
		return ["Herstellen", UI.GREY]
	if g.has("find"):
		return ["Finden: %s" % String(D.AREAS[int(g.find)].name), UI.GREY]
	return ["?", UI.GREY]


func _list(sel: String) -> Control:
	var v := UI.vbox(10)
	var head := UI.label("%d von %d in deiner Truppe" % [CD.owned_count(), CD.ORDER.size()], 22, UI.TEXT)
	v.add_child(head)
	var keys: Array = [""]
	keys.append_array(CD.ORDER)
	for k in keys:
		var nm_text := "Ohne Begleiter"
		var sub := "Der Held trägt selbst (Kraxe)"
		var col := UI.TEXT
		var owned := true
		if k != "":
			owned = CD.owned(k)
			nm_text = String(CD.def(k).name)
			var stt: Array = _status(k)
			sub = String(stt[0])
			col = stt[1]
		elif CD.active() == "":
			sub = "Ausgewählt"
			col = UI.GREEN
		var nm := UI.label(nm_text, 27)
		nm.clip_text = true
		var sl := UI.sub_label(sub, 20, col, k == sel)
		sl.clip_text = true
		var txt := UI.vbox(-2, [nm, sl])
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic: Control = UI.pic("comp_" + k, 88.0, "star") if k != "" else UI.pic("cg_kraxe", 88.0, "walk")
		if not owned:
			ic.modulate = Color(0.45, 0.52, 0.68)
		var content := UI.hbox(12, [ic, txt])
		if not owned:
			content.add_child(UI.icon("lock", 30.0, UI.GOLD))
		v.add_child(S.card_button(k == sel, S.set_st("sel", k), content, 102.0))
	var sc: ScrollContainer = S.scroll(v, "comp_list", Vector2(430, 0))
	sc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return sc


func _select_button(key: String) -> Button:
	var b: Button
	if CD.active() == key:
		b = UI.button("Ist dabei", Callable(), "dark", 30, "ui_check")
		UI.disable(b)
	else:
		b = UI.button("Mitnehmen" if key != "" else "Allein gehen", S.act(func():
			CD.set_active(key)
			UI.sfx("comp_select", "click", -4.0)
			if key != "":
				Sfx.play("comp_" + key, -6.0)), "green", 30, "ui_check")
	b.custom_minimum_size = Vector2(440, 82)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b


func _alone(c: VBoxContainer) -> void:
	var top := UI.hbox(22)
	var cc := CenterContainer.new()
	cc.add_child(UI.pedestal(UI.pic("cg_kraxe", 250.0, "walk"), 300.0))
	var fr := UI.frame(cc, UI.scenery("meadow"))
	fr.custom_minimum_size = Vector2(620, 400)
	top.add_child(UI.vbox(12, [fr, _select_button("")]))
	var info := UI.vbox(10)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UI.label("Ohne Begleiter", 56)
	nm.add_theme_constant_override("outline_size", 13)
	info.add_child(nm)
	info.add_child(UI.text("Dein Held trägt alles selbst in seiner Holz-Kraxe. Ein Begleiter trägt mehr, läuft hinter dir her und hat eine Besonderheit.", 26, UI.WHITE))
	var stats := UI.vbox(12)
	stats.add_child(UI.stat_row("ui_crate", "Tragkraft", "+0", 30))
	info.add_child(UI.card(stats, UI.NAVY, 20, Color(UI.EDGE, 0.8)))
	top.add_child(info)
	c.add_child(top)


func _detail(c: VBoxContainer, key: String) -> void:
	var def: Dictionary = CD.def(key)
	var owned := CD.owned(key)
	var top := UI.hbox(22)
	# ---- Vorschau
	var fly: bool = String(def.move) == "fly"
	var big: bool = key in ["golem", "husky", "schnecke"]
	# Paket Welt: die Vorschau bewegt sich (läuft auf der Stelle, schaut, wedelt, flattert)
	var pv: Control = S.preview_model("comp:" + key, func() -> Node3D: return CompanionPose.new().setup(key), 3.3 if big else 2.6, 1.15 if fly else (0.6 if big else 0.45))
	pv.custom_minimum_size = Vector2(620, 400)
	var inner: Control = pv
	if not owned:
		var hold := PanelContainer.new()
		hold.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		hold.add_child(pv)
		var shade := ColorRect.new()
		shade.color = Color(0.03, 0.08, 0.2, 0.35)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hold.add_child(shade)
		inner = hold
	var fr := UI.frame(inner, UI.scenery(String(SCENE.get(key, "meadow"))))
	var under: Control
	if owned:
		under = _select_button(key)
	else:
		under = _get_button(key)
	top.add_child(UI.vbox(12, [fr, under]))
	# ---- Name, Werte, Besonderheiten
	var info := UI.vbox(8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UI.label(String(def.name), 52 if String(def.name).length() <= 16 else 42)
	nm.add_theme_constant_override("outline_size", 13)
	nm.clip_text = true
	info.add_child(nm)
	info.add_child(UI.label(String(def.kind), 27, Color("8FB8F0")))
	info.add_child(UI.text(String(def.text), 23, UI.WHITE))
	var stats := UI.vbox(8)
	var lv := CD.level(key)
	stats.add_child(UI.stat_row("ui_crate", "Tragkraft", "+%d" % int(round(CD.carry(key))), 27))
	stats.add_child(UI.stat_row("ui_speed", "Tempo", ("%.1f m/s" % float(def.speed)).replace(".", ","), 27))
	stats.add_child(UI.stat_row("ui_heart", "Leben", str(int(round(CD.max_hp(key)))), 27))
	if owned:
		var pr: Array = CD.xp_progress(key)
		var lvr := UI.hbox(12, [UI.pic("ui_star", 36.0), UI.label("Stufe %d / %d" % [lv, CD.MAX_LEVEL], 25)])
		var bar := UI.bar(float(pr[0]) / maxf(float(pr[1]), 1.0), UI.GOLD, Vector2(220, 22))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lvr.add_child(bar)
		stats.add_child(lvr)
	stats.add_child(UI.sep(false, Color(UI.EDGE, 0.4)))
	var abil: Dictionary = def.get("abil", {})
	var i := 0
	for line in CD.abil_lines(key):
		var an := String(abil.keys()[i])
		var t := UI.vbox(-2, [UI.label(String(line[0]), 24, UI.SKY), UI.text(String(line[1]), 20, UI.TEXT)])
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(UI.hbox(12, [UI.pic(String(ABIL_ICON.get(an, "ui_star")), 40.0, "star", UI.SKY), t]))
		i += 1
	# Paket Welt: Köder (alle Begleiter ab Stufe 3) und Sammeln in der Basis
	var lure_ok := owned and lv >= DW.LURE_LEVEL
	var lt := UI.vbox(-2, [UI.label("Köder" + ("" if lure_ok else " (ab Stufe %d)" % DW.LURE_LEVEL), 24, UI.SKY if lure_ok else UI.GREY),
		UI.text("Wird es eng, lockt er die Gegner für %d s von dir weg." % int(DW.LURE_TIME), 20, UI.TEXT)])
	lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_child(UI.hbox(12, [UI.pic("ui_target", 40.0, "star", UI.SKY if lure_ok else UI.GREY), lt]))
	info.add_child(UI.card(stats, UI.NAVY, 18, Color(UI.EDGE, 0.8)))
	top.add_child(info)
	c.add_child(top)
	# ---- So bekommst du ihn
	var how := UI.vbox(4)
	for l in CD.how_lines(key):
		how.add_child(UI.label("• " + String(l), 21, UI.TEXT, false))
	var hb := UI.hbox(14, [UI.pic("ui_info", 40.0), how])
	if owned:
		hb.add_child(UI.spacer(true))
		hb.add_child(UI.badge("in deiner Truppe", Color("2F8D4E"), 20))
	c.add_child(UI.card(hb, UI.NAVY_L, 12))
	_nest(c)


## Paket Welt: Brutnest mit Begleiter-Eiern (aus Schleimnestern, seltenen Kisten und von der Karawane).
func _nest(c: VBoxContainer) -> void:
	var eggs: Array = WS.eggs()
	var v := UI.vbox(8)
	v.add_child(UI.hbox(12, [UI.pic("p_egg_nest", 48.0, "ui_heart"), UI.label("Brutnest – %d von %d Eiern" % [eggs.size(), DW.EGG_MAX], 25, UI.GOLD)]))
	if eggs.is_empty():
		v.add_child(UI.text("Eier findest du in Schleimnestern der Expeditionen, in seltenen Kisten und bei der Händler-Karawane. Sie schlüpfen nach %d Stunden." % int(DW.EGG_HATCH_HOURS), 20, UI.TEXT))
	for i in eggs.size():
		var left := WS.egg_left(i)
		var k := String(eggs[i].key)
		var known := CD.owned(k)
		var nm := UI.label("Ei: %s" % ("ein " + String(CD.def(k).name) if known else "Überraschung!"), 22)
		var bar := UI.bar(1.0 - left / (DW.EGG_HATCH_HOURS * 3600.0), UI.GOLD if left <= 0.0 else D.C_BAR_BLUE, Vector2(220, 20))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var row := UI.hbox(12, [UI.pic("p_egg", 48.0, "ui_heart"), nm, bar])
		var idx := i
		if left <= 0.0:
			var b := UI.button("Schlüpfen lassen", S.act(func():
				var txt := WS.hatch(idx)
				if txt != "":
					Sfx.play("egg_hatch", -3.0)
					S.toast(txt)), "green", 22, "ui_star")
			b.custom_minimum_size = Vector2(230, 56)
			row.add_child(b)
		else:
			row.add_child(UI.label(UI.time_text(left), 22, UI.TEXT))
		v.add_child(row)
	c.add_child(UI.card(v, UI.NAVY_L, 12))


## Knopf unter der Vorschau, wenn der Begleiter noch fehlt: herstellen, kaufen oder Hinweis zum Finden.
func _get_button(key: String) -> Control:
	var g: Dictionary = CD.def(key).get("get", {})
	var box := UI.vbox(8)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if g.has("craft"):
		var why := CD.can_craft(key)
		var b := UI.button("Herstellen", S.act(func():
			var r := CD.craft(key)
			if r == "":
				UI.sfx("comp_craft", "upgrade", -2.0)
				S.preview_cheer()
				S.toast("%s ist fertig gebaut!" % String(CD.def(key).name))
			else:
				UI.sfx("ui_error", "error", -6.0)
				S.say(r)), "green", 28, "ui_hammer")
		b.custom_minimum_size = Vector2(250, 72)
		UI.disable(b, why != "")
		box.add_child(UI.hbox(12, [UI.cost_row(g.craft, 24), b]))
	if g.has("buy"):
		var why2 := CD.can_buy(key)
		var cost: Dictionary = g.buy
		var gem := cost.has("gems")
		var label := str(int(cost.gems)) if gem else "Kaufen"
		var b2 := UI.button(label, S.act(func():
			var r := CD.buy(key)
			if r == "":
				UI.sfx("ui_buy", "pay", -2.0)
				S.toast("%s gehört jetzt dir!" % String(CD.def(key).name))
			else:
				UI.sfx("ui_error", "error", -6.0)
				S.say(r)), "gold" if gem else "green", 28, "res_gems" if gem else "res_coins")
		b2.custom_minimum_size = Vector2(250, 72)
		UI.disable(b2, why2 != "")
		var row := UI.hbox(12)
		if not gem:
			row.add_child(UI.cost_row(cost, 24))
		else:
			row.add_child(UI.label("Kaufen für Juwelen", 24))
		row.add_child(b2)
		box.add_child(row)
	if g.has("find") and not g.has("craft") and not g.has("buy"):
		var lb := UI.button("Auf Expedition finden: %s" % String(D.AREAS[int(g.find)].name), Callable(), "dark", 24, "ui_expedition")
		UI.disable(lb)
		lb.custom_minimum_size = Vector2(440, 72)
		box.add_child(lb)
	return box
