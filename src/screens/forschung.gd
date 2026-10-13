extends RefCounted
## Bildschirm „Forschung“ (V6 Paket B): Forschungsbaum mit drei Ästen als Baumansicht – Knoten mit Linien zu ihren
## Voraussetzungen, Zustand farbig (fertig grün, läuft gold, verfügbar in der Farbe des Asts, gesperrt grau).
## Rechts die Einzelheiten des gewählten Knotens mit Kosten, Zeit und Start; oben der laufende Auftrag (Beschleunigen).
## Erreichbar über das Labor, die Werkstatt (Tüftelecke, nur die erste Reihe) und das Menü.

const D = preload("res://src/data.gd")
const DB = preload("res://src/data_basis.gd")
const UI = preload("res://src/ui.gd")
const R = preload("res://src/research.gd")

const ROW_H := 112.0
const NODE := Vector2(300, 86)
const GAP := 70.0

var S


## Zeichnet die Linien zwischen den Knoten (unter den Knöpfen).
class TreeView extends Control:
	var lines: Array = []             # [Vector2 von, Vector2 nach, Color, bool fertig]

	func _draw() -> void:
		for l in lines:
			var a: Vector2 = l[0]
			var b: Vector2 = l[1]
			var col: Color = l[2]
			var mid := (a.y + b.y) * 0.5
			var pts := PackedVector2Array([a, Vector2(a.x, mid), Vector2(b.x, mid), b])
			draw_polyline(pts, Color(0.02, 0.06, 0.14, 0.7), 13.0, true)
			draw_polyline(pts, col, 7.0 if bool(l[3]) else 5.0, true)


func setup(arg) -> void:
	if arg is String and String(arg) != "":
		for i in DB.BRANCHES.size():
			if String(DB.BRANCHES[i].key) == String(arg):
				S.st["tab"] = i
	if not S.st.has("sel") and not S.st.has("tab"):
		var cur := R.current()
		if cur != "":
			S.st["sel"] = cur
			S.st["tab"] = _branch_index(String(DB.NODES[cur].branch))


func _branch_index(key: String) -> int:
	for i in DB.BRANCHES.size():
		if String(DB.BRANCHES[i].key) == key:
			return i
	return 0


func build() -> Control:
	var v := UI.vbox(10)
	v.add_child(_status())
	var names: Array = []
	var icons: Array = []
	for br in DB.BRANCHES:
		var n := 0
		var tot := 0
		for k in DB.NODES:
			if String(DB.NODES[k].branch) == String(br.key):
				tot += 1
				if R.is_done(k):
					n += 1
		names.append("%s %d/%d" % [String(br.name), n, tot])
		icons.append(String(br.icon))
	v.add_child(S.tabs(names, "tab", 23, icons))
	var tab := clampi(int(S.st.get("tab", 0)), 0, DB.BRANCHES.size() - 1)
	var br: Dictionary = DB.BRANCHES[tab]
	var sel := String(S.st.get("sel", ""))
	if sel == "" or String(DB.NODES.get(sel, {}).get("branch", "")) != String(br.key):
		sel = _first_open(String(br.key))
		S.st["sel"] = sel
	var row := UI.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tree := _tree(br, sel)
	var tp := UI.panel(tree, UI.NAVY, Color(br.color, 0.7), 22, 14)
	tp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(S.scroll(tp, "tree_%d" % tab))
	row.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.get_child(0).size_flags_stretch_ratio = 2.2
	var det := _details(sel)
	var ds: ScrollContainer = S.scroll(det, "det")
	ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ds)
	v.add_child(row)
	return v


func _first_open(bk: String) -> String:
	var best := ""
	var bt := 99
	for k in DB.NODES:
		var n: Dictionary = DB.NODES[k]
		if String(n.branch) != bk:
			continue
		var st := R.state(k)
		if (st == "open" or st == "running") and int(n.tier) < bt:
			bt = int(n.tier)
			best = k
	if best == "":
		for k in DB.NODES:
			if String(DB.NODES[k].branch) == bk and int(DB.NODES[k].tier) == 0:
				return k
	return best


# ---------------------------------------------------------------- oben: laufende Forschung, Labor
func _status() -> Control:
	var cur := R.current()
	var lv := R.labor_level()
	var lab_txt := ""
	if lv > 0:
		var top := 0
		for t in DB.TIER_LAB.size():
			if int(DB.TIER_LAB[t]) <= lv:
				top = t
		lab_txt = "Labor Stufe %d: Reihen 1–%d" % [lv, top + 1]
		if lv > 1:
			lab_txt += " · " + "%d %% schneller" % int(round(minf(0.6, DB.LAB_SPEED * (lv - 1)) * 100.0))
	elif R.prelab_ok():
		lab_txt = "Tüftelecke in der Werkstatt: nur die erste Reihe. Das Labor (ab Bunker 8) öffnet den ganzen Baum."
	else:
		lab_txt = "Forschung beginnt mit der Werkstatt (ab Bunker 2) – das Labor folgt ab Bunker 8."
	var h := UI.hbox(14, [UI.pic("ui_research", 58.0, "ui_gear")])
	if cur != "":
		var n: Dictionary = DB.NODES[cur]
		var col := UI.vbox(4)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UI.hbox(10, [UI.label("Forscht: %s" % String(n.name), 27, UI.GOLD), UI.label(String(n.text), 20, UI.TEXT, false)]))
		var bar := UI.bar(R.progress(), UI.GOLD, Vector2(300, 22))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tl := UI.label(UI.time_text(R.left()), 24, UI.WHITE)
		S.live(tl, func():
			if R.current() == "":
				S.refresh()
				return ""
			bar.value = R.progress() * bar.max_value
			return UI.time_text(R.left()))
		col.add_child(UI.hbox(12, [bar, UI.icon("clock", 28, UI.WHITE), tl]))
		h.add_child(col)
		var cost := R.speed_cost()
		var sb := UI.button("Fertigstellen – gratis" if cost <= 0 else "Beschleunigen  %d" % cost, S.act(func():
			if R.finish_now():
				S.toast("Forschung fertig!")), "green" if cost <= 0 else "gold", 24, "ui_check" if cost <= 0 else "res_gems")
		sb.custom_minimum_size = Vector2(0, 70)
		h.add_child(sb)
	else:
		var l := UI.vbox(2, [UI.label("Kein Forschungsauftrag", 27, UI.WHITE), UI.label("Wähle einen Knoten im Baum und starte ihn. Es läuft immer eine Forschung zugleich.", 20, UI.GREY, false)])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
	var lb := UI.label(lab_txt, 20, UI.SKY, false)
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.custom_minimum_size = Vector2(420, 0)
	h.add_child(lb)
	if lv > 0:
		var pb := UI.button("Talente neu verteilen", func(): S.open("profile"), "dark", 20, "ui_badge")
		pb.custom_minimum_size = Vector2(0, 64)
		h.add_child(pb)
	return UI.card(h, UI.NAVY_L, 12)


# ---------------------------------------------------------------- Baum
func _tree(br: Dictionary, sel: String) -> Control:
	var tv := TreeView.new()
	var w := 3.0 * (NODE.x + GAP)
	tv.custom_minimum_size = Vector2(w, 6.0 * ROW_H + 10.0)
	var pos := {}
	for k in DB.NODES:
		var n: Dictionary = DB.NODES[k]
		if String(n.branch) != String(br.key):
			continue
		var c := Vector2((float(n.col) + 0.5) * (NODE.x + GAP), float(n.tier) * ROW_H + NODE.y * 0.5 + 6.0)
		pos[k] = c
	# Reihen-Beschriftung (Labor-Stufe)
	for t in 6:
		var why := R.tier_why(t)
		if why != "":
			var ll := UI.label("Reihe %d · %s" % [t + 1, why], 16, Color(UI.GREY, 0.8), false)
			ll.position = Vector2(8, t * ROW_H + NODE.y + 2.0)
			tv.add_child(ll)
	for k in pos:
		for r in DB.NODES[k].get("req", []):
			if pos.has(String(r)):
				var dn := R.is_done(String(r))
				var a: Vector2 = pos[String(r)] + Vector2(0, NODE.y * 0.5)
				var b: Vector2 = pos[k] - Vector2(0, NODE.y * 0.5)
				tv.lines.append([a, b, Color("6FE03A") if dn else Color(0.42, 0.52, 0.68, 0.9), dn])
	for k in pos:
		var nd := _node(k, br, k == sel)
		nd.position = pos[k] - NODE * 0.5
		nd.size = NODE
		tv.add_child(nd)
	return tv


func _node(key: String, br: Dictionary, selected: bool) -> Control:
	var n: Dictionary = DB.NODES[key]
	var st := R.state(key)
	var bcol: Color = br.color
	var bg := Color("17365F")
	var border := Color(bcol, 0.85)
	var name_col := UI.WHITE
	var badge := ""
	match st:
		"done":
			bg = Color("1F5A34")
			border = UI.GREEN
			badge = "ui_check"
		"running":
			bg = Color("5A4718")
			border = UI.GOLD
			badge = "ui_clock"
		"locked":
			bg = Color("1A2840")
			border = Color(0.35, 0.42, 0.55, 0.8)
			name_col = UI.GREY
			badge = "ui_lock"
	if selected:
		border = UI.WHITE
	var ic := UI.pic(String(n.icon), 50.0, "ui_star")
	if st == "locked":
		ic.modulate = Color(0.55, 0.6, 0.7, 0.8)
	var nm := UI.label(String(n.name), 22, name_col)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(190, 0)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UI.hbox(8, [ic, nm])
	if badge != "":
		row.add_child(UI.pic(badge, 30.0, "", UI.GREEN if st == "done" else UI.WHITE))
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var p := UI.panel(row, bg, border, 18, 10)
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	UI.ignore_mouse(p)
	b.add_child(p)
	if st == "running":
		var bar := UI.bar(R.progress(), UI.GOLD, Vector2(NODE.x - 30, 8))
		bar.position = Vector2(15, NODE.y - 16)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bar)
	b.pressed.connect(func():
		UI.sfx("ui_select", "click", -8.0)
		S.st["sel"] = key
		S.refresh())
	b.set_meta("research", key)
	return b


# ---------------------------------------------------------------- rechts: Einzelheiten
func _details(key: String) -> Control:
	var v := UI.vbox(12)
	if key == "" or not DB.NODES.has(key):
		v.add_child(UI.label("Wähle einen Knoten.", 24, UI.GREY))
		return UI.panel(v, UI.NAVY, UI.EDGE, 22, 18)
	var n: Dictionary = DB.NODES[key]
	var br := R.branch_of(key)
	var st := R.state(key)
	v.add_child(UI.hbox(12, [UI.pic(String(n.icon), 70.0, "ui_star"), UI.vbox(2, [UI.label(String(n.name), 32, UI.GOLD), UI.label("%s · Reihe %d" % [String(br.name), int(n.tier) + 1], 20, Color(br.color).lightened(0.3), false)])]))
	var eff := UI.text(String(n.text), 24, UI.WHITE, 380)
	v.add_child(UI.card(UI.hbox(10, [UI.pic("ui_up", 34.0), eff]), Color("1F4A2A") if st == "done" else UI.NAVY_L, 12))
	var reqs: Array = n.get("req", [])
	if reqs.size() > 0:
		var rl := UI.vbox(4, [UI.label("Voraussetzung", 21, UI.SKY)])
		for r in reqs:
			var ok := R.is_done(String(r))
			rl.add_child(UI.hbox(8, [UI.pic("ui_check" if ok else "ui_lock", 26.0, "", UI.GREEN if ok else UI.GREY), UI.label(String(DB.NODES[String(r)].name), 21, UI.GREEN if ok else UI.TEXT, false)]))
		v.add_child(rl)
	match st:
		"done":
			v.add_child(UI.info_box("Erforscht – die Wirkung gilt schon.", 21, "ui_check"))
		"running":
			v.add_child(UI.info_box("Wird gerade erforscht.", 21, "ui_clock"))
		_:
			var cost := R.cost(key)
			v.add_child(UI.label("Kosten", 21, UI.SKY))
			v.add_child(UI.cost_row(cost, 24))
			v.add_child(UI.hbox(10, [UI.icon("clock", 30, UI.WHITE), UI.label("Forschungszeit: %s" % UI.time_text(R.time_for(key)), 22, UI.TEXT)]))
			var why := R.why_not(key)
			if why != "":
				var wl := UI.label(why, 21, UI.RED if st == "open" else UI.GREY, false)
				wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				wl.custom_minimum_size = Vector2(380, 0)
				v.add_child(wl)
			var go := UI.button("Erforschen", S.act(func():
				var w2 := R.start(key)
				if w2 != "":
					S.toast(w2)
					UI.sfx("ui_error", "error", -6.0)
				else:
					S.toast("Forschung gestartet: %s" % String(n.name))), "green", 30, "ui_research")
			go.custom_minimum_size = Vector2(0, 84)
			UI.disable(go, why != "")
			go.set_meta("research_go", key)
			v.add_child(go)
	var done_all := R.summary()
	if done_all.size() > 0:
		v.add_child(UI.sep(false, Color(UI.EDGE, 0.4)))
		v.add_child(UI.label("Erforscht (%d)" % done_all.size(), 21, UI.SKY))
		for t in done_all:
			v.add_child(UI.label("· " + String(t), 18, UI.TEXT, false))
	return UI.panel(v, UI.NAVY, UI.EDGE, 22, 18)
