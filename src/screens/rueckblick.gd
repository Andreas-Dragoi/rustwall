extends RefCounted
## Bildschirm „Flut-Rückblick“ (V6 Paket B, Kapitel 4.2): Zusammenfassung der letzten Fluten mit kleiner Karte der Basis.
## Karte: Gebäude als Flächen, Mauern als Punkte, rote Kreuze = Mauerbrüche (Zahl = Welle), rot umrandet = verlorene Gebäude,
## goldene Ringe = die drei Türme mit dem meisten Schaden, Pfeile = aus diesen Richtungen kam die Flut.
## Rechts: Ergebnis, Wetter, beste Türme, Welle für Welle. Oben: Wahl der Flut (neueste zuerst) und der Welle.

const D = preload("res://src/data.gd")
const DB = preload("res://src/data_basis.gd")
const UI = preload("res://src/ui.gd")
const FW = preload("res://src/flood_weather.gd")
const I18N = preload("res://src/i18n.gd")

var S

const CAT_COL := {"def": Color("C0504D"), "prod": Color("D9A441"), "special": Color("5B8FD9"), "deco": Color("6FAE5A"), "trap": Color("8E6FC2"), "wall": Color("A7ADC6")}
const WALL_COL := [Color("B8742F"), Color("A7ADC6"), Color("6F8FC0")]


class MiniMap extends Control:
	var rec: Dictionary = {}
	var wave := 0                      # 0 = alle Wellen, sonst nur diese

	func _draw() -> void:
		var g: Array = rec.get("grid", [0, 44])
		var o := float(g[0])
		var n := float(g[1])
		var sz := minf(size.x, size.y)
		var cs := sz / (n + 4.0)
		var off := Vector2((size.x - sz) * 0.5, (size.y - sz) * 0.5) + Vector2(2, 2) * cs
		var cell := func(x: float, y: float) -> Vector2: return off + Vector2(x - o, y - o) * cs
		draw_rect(Rect2(off - Vector2(2, 2) * cs, Vector2(n + 4, n + 4) * cs), Color("2E5A2A"))
		draw_rect(Rect2(off, Vector2(n, n) * cs), Color("4F7A34"))
		var m: Dictionary = rec.get("map", {})
		var lost := {}
		var br: Array = []
		var wl: Array = rec.get("waves", [])
		for i in wl.size():
			if wave != 0 and i + 1 != wave:
				continue
			for e in wl[i].get("lost", []):
				lost["%d:%d" % [int(e[1]), int(e[2])]] = i + 1
			for e in wl[i].get("br", []):
				br.append([int(e[0]), int(e[1]), i + 1])
		for b in m.get("b", []):
			var cat := String(D.BUILDINGS.get(String(b[0]), {}).get("cat", "special"))
			var col: Color = CAT_COL.get(cat, Color("5B8FD9"))
			if String(b[0]) == "bunker":
				col = Color("FFD23E")
			var r := Rect2(cell.call(float(b[1]), float(b[2])), Vector2(float(b[3]), float(b[4])) * cs).grow(-cs * 0.08)
			draw_rect(r, col)
			draw_rect(r, Color(0, 0, 0, 0.35), false, maxf(1.0, cs * 0.08))
			if lost.has("%d:%d" % [int(b[1]), int(b[2])]):
				draw_rect(r.grow(cs * 0.12), Color("FF4D62"), false, maxf(2.0, cs * 0.28))
		for wv in m.get("w", []):
			var c: Vector2 = cell.call(float(wv[0]) + 0.5, float(wv[1]) + 0.5)
			draw_rect(Rect2(c - Vector2(0.42, 0.42) * cs, Vector2(0.84, 0.84) * cs), WALL_COL[clampi(int(wv[2]), 0, 2)])
		# beste Türme
		var tl: Array = rec.get("towers", [])
		for i in mini(3, tl.size()):
			var t: Array = tl[i]
			if int(t[5]) <= 0:
				continue
			var c2: Vector2 = cell.call(float(t[1]) + float(t[3]) * 0.5, float(t[2]) + float(t[4]) * 0.5)
			draw_arc(c2, cs * (float(t[3]) * 0.5 + 0.9), 0.0, TAU, 32, Color("FFD23E"), maxf(2.0, cs * 0.3), true)
			_text(c2 + Vector2(cs * 1.2, -cs * 1.2), str(i + 1), Color("FFD23E"), int(cs * 1.6))
		# Mauerbrüche
		for e in br:
			var c3: Vector2 = cell.call(float(e[0]) + 0.5, float(e[1]) + 0.5)
			var k := cs * 0.75
			draw_line(c3 - Vector2(k, k), c3 + Vector2(k, k), Color("FF4D62"), maxf(2.0, cs * 0.35))
			draw_line(c3 - Vector2(k, -k), c3 + Vector2(k, -k), Color("FF4D62"), maxf(2.0, cs * 0.35))
			if wave == 0:
				_text(c3 + Vector2(cs * 0.6, cs * 1.4), str(int(e[2])), Color.WHITE, int(cs * 1.1))
		# Richtungen der Flut
		var dv := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
		var ctr := off + Vector2(n, n) * cs * 0.5
		for d in rec.get("dirs", []):
			var v: Vector2 = dv[int(d)]
			var tip := ctr + v * (n * 0.5 + 0.6) * cs
			var tail := ctr + v * (n * 0.5 + 1.9) * cs
			draw_line(tail, tip, Color("FF8A3D"), maxf(3.0, cs * 0.45))
			var side := v.orthogonal() * cs * 0.7
			draw_colored_polygon(PackedVector2Array([tip, tip - v * cs + side, tip - v * cs - side]), Color("FF8A3D"))

	func _text(p: Vector2, t: String, col: Color, fs: int) -> void:
		var f := ThemeDB.fallback_font
		var th := get_theme_default_font()
		if th != null:
			f = th
		draw_string_outline(f, p, I18N.t(t), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(fs, 12), 4, Color(0, 0, 0, 0.8))
		draw_string(f, p, I18N.t(t), HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(fs, 12), col)


func setup(_arg) -> void:
	var l: Array = P.d.get("replays", [])
	for r in l:
		r["seen"] = true
	P.mark()


func build() -> Control:
	var l: Array = P.d.get("replays", [])
	if l.is_empty():
		return UI.vbox(14, [UI.label("Noch keine Flut", 32, UI.GOLD), UI.text("Nach jeder Flut – auch einer verpassten – steht hier, wo die Mauer brach und welche Türme am meisten geleistet haben.", 24, UI.TEXT, 900)])
	var idx := clampi(int(S.st.get("tab", 0)), 0, l.size() - 1)
	var rec: Dictionary = l[idx]
	var names: Array = []
	var icons: Array = []
	for i in l.size():
		var r: Dictionary = l[i]
		names.append("%s · Woche %d" % [_mode_name(r), int(r.get("week", 0))])
		icons.append("ui_check" if bool(r.get("win", false)) else "ui_skull")
	var v := UI.vbox(10)
	v.add_child(S.tabs(names, "tab", 22, icons))
	var row := UI.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Karte mit Wellen-Wahl
	var wl: Array = rec.get("waves", [])
	var wave := clampi(int(S.st.get("wave", 0)), 0, wl.size())
	var mm := MiniMap.new()
	mm.rec = rec
	mm.wave = wave
	mm.custom_minimum_size = Vector2(640, 640)
	mm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var wrow := UI.flow(6)
	wrow.add_child(S.choice("Alle Wellen", wave == 0, func():
		S.st["wave"] = 0
		S.refresh(), 18))
	for i in wl.size():
		var ii: int = i + 1
		wrow.add_child(S.choice(str(ii), wave == ii, func():
			S.st["wave"] = ii
			S.refresh(), 18))
	var legend := UI.flow(14)
	for e in [["ui_close", "Mauerbruch", UI.RED], ["ui_star", "Beste Türme", UI.GOLD], ["ui_skull", "Verloren", UI.RED], ["ui_map", "Flut kam von", UI.ORANGE]]:
		legend.add_child(UI.hbox(6, [UI.pic(String(e[0]), 24.0, "", e[2]), UI.label(String(e[1]), 17, UI.TEXT, false)]))
	var left := UI.vbox(8, [wrow, mm, legend])
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(UI.panel(left, UI.NAVY, UI.EDGE, 22, 12))
	row.add_child(S.scroll(_info(rec, wave), "info"))
	row.get_child(1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	return v


func _mode_name(r: Dictionary) -> String:
	match String(r.get("mode", "")):
		"auto":
			return "Verpasste Flut"
		"practice":
			return "Übung"
		"test":
			return "Layout-Test"
	return "Flut"


func _info(rec: Dictionary, wave: int) -> Control:
	var v := UI.vbox(10)
	var win := bool(rec.get("win", false))
	var head := UI.label("Gehalten!" if win else "Der Bunker ist gefallen", 34, UI.GREEN if win else UI.RED)
	v.add_child(UI.hbox(12, [UI.pic("ui_flood", 54.0), UI.vbox(0, [head, UI.label("%s · Woche %d" % [_mode_name(rec), int(rec.get("week", 0))], 20, UI.GREY, false)])]))
	if bool(rec.get("calc", false)):
		v.add_child(UI.info_box("Du warst nicht da: Die Basis hat sich allein verteidigt. Dieser Rückblick ist aus der Berechnung.", 19))
	var stats := UI.vbox(6)
	stats.add_child(UI.stat_row("e_0", "Besiegt", UI.fmt(float(rec.get("kills", 0))), 23))
	if win and int(rec.get("stars", 0)) > 0:
		stats.add_child(UI.stat_row("ui_star", "Sterne", "%d / 3" % int(rec.stars), 23))
	stats.add_child(UI.stat_row("ui_heart", "Bunker am Ende", "%d %%" % int(round(float(rec.get("hp", 0.0)) * 100.0)), 23))
	var wn := String(rec.get("weather", "klar"))
	var night := bool(rec.get("night", false))
	stats.add_child(UI.stat_row(String(DB.NIGHT.icon) if night and wn == "klar" else String(DB.WEATHER.get(wn, DB.WEATHER.klar).icon), "Wetter", FW.label(wn, night), 23, UI.SKY))
	var nbr := 0
	var nlost := 0
	for w in rec.get("waves", []):
		nbr += (w.br as Array).size()
		nlost += (w.lost as Array).size()
	stats.add_child(UI.stat_row("ui_shield", "Mauerbrüche", str(nbr), 23, UI.RED if nbr > 0 else UI.GREEN))
	stats.add_child(UI.stat_row("ui_build", "Verlorene Gebäude", str(nlost), 23, UI.RED if nlost > 0 else UI.GREEN))
	v.add_child(UI.card(stats, UI.NAVY_L, 12))
	# beste Türme
	var tl: Array = rec.get("towers", [])
	if tl.size() > 0:
		v.add_child(UI.label("Türme mit dem meisten Schaden", 22, UI.SKY))
		var top := maxf(1.0, float(tl[0][5]))
		for i in mini(5, tl.size()):
			var t: Array = tl[i]
			var b := UI.bar(float(t[5]) / top, UI.GOLD if i < 3 else D.C_BAR_BLUE, Vector2(160, 18))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var nm := UI.label("%d. %s" % [i + 1, String(D.BUILDINGS.get(String(t[0]), {}).get("name", String(t[0])))], 21, UI.WHITE, false)
			nm.custom_minimum_size = Vector2(220, 0)
			v.add_child(UI.hbox(10, [UI.building_pic(String(t[0]), 40.0), nm, b, UI.label(UI.fmt(float(t[5])), 21, UI.GOLD)]))
	# Welle für Welle
	v.add_child(UI.label("Welle für Welle", 22, UI.SKY))
	var wl: Array = rec.get("waves", [])
	for i in wl.size():
		if wave != 0 and i + 1 != wave:
			continue
		var w: Dictionary = wl[i]
		var parts: Array = ["%d Gegner" % int(w.get("n", 0)), "%d besiegt" % int(w.get("k", 0))]
		if (w.br as Array).size() > 0:
			parts.append("1 Mauerbruch" if (w.br as Array).size() == 1 else "%d Mauerbrüche" % (w.br as Array).size())
		var ln: Array = []
		for e in w.get("lost", []):
			ln.append(String(D.BUILDINGS.get(String(e[0]), {}).get("name", String(e[0]))))
		if ln.size() > 0:
			parts.append("verloren: %s" % ", ".join(ln))
		var bad: bool = (w.br as Array).size() > 0 or ln.size() > 0
		var txt := UI.label(" · ".join(parts), 19, UI.TEXT, false)
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hp := UI.bar(float(w.get("hp", 1.0)), UI.GREEN if float(w.get("hp", 1.0)) > 0.5 else UI.RED, Vector2(90, 14))
		hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		v.add_child(UI.card(UI.hbox(10, [UI.label("Welle %d" % (i + 1), 21, UI.RED if bad else UI.GOLD), txt, hp]), UI.NAVY_L, 8))
	return UI.panel(v, UI.NAVY, UI.EDGE, 22, 16)
