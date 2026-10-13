extends RefCounted
## V6 Paket E – Berichte der Auto-Expeditionen (Kapitel 4.3): Was ist unterwegs passiert?
## P.collect_auto() ruft finish() auf: Ereignisliste (zum Gebiet passend, mit Wirkung: Fundkisten, mehr Rohstoffe, Erfahrung,
## selten ein Begleiter-Ei), Gefahr und Verletzung (Held danach kurz nicht einsetzbar, Story.injure).
## Dazu die Bausteine für die Anzeige: Bild des Gebiets mit dem Helden (icons/scene_<gebiet>.png + Heldenbild), Berichtskarte,
## Gefahren-Anzeige beim Losschicken.

const D = preload("res://src/data.gd")
const DG = preload("res://src/data_geschichte.gd")
const UI = preload("res://src/ui.gd")
const Story = preload("res://src/story.gd")


# ================================================================= Gefahr
## Wahrscheinlichkeit einer Verletzung für diesen Helden, dieses Gebiet und diese Dauer.
static func risk(hk: String, area: int, hours: int) -> float:
	var base := float(DG.RISK_BASE.get(hours, 0.1))
	var lv := int(P.d.heroes[hk].level) if P.d.has("heroes") and P.d.heroes.has(hk) else 1
	var rec := int(D.EXP_HERO_LEVEL[clampi(area, 0, D.EXP_HERO_LEVEL.size() - 1)])
	var diff := rec - lv
	if diff > 0:
		base += DG.RISK_UNDER * diff
	else:
		base = maxf(DG.RISK_MIN, base - DG.RISK_OVER * (-diff))
	return clampf(base, DG.RISK_MIN, DG.RISK_MAX)


static func danger_level(r: float) -> int:
	return 0 if r < 0.1 else (1 if r < 0.22 else 2)


static func injury_minutes(hours: int) -> float:
	var i := [1, 4, 8].find(hours)
	return float(DG.INJURY_MIN[maxi(i, 0)])


# ================================================================= Bericht
## Würfelt die Ereignisse einer zurückgekehrten Auto-Expedition aus und wendet sie an. loot = schon gutgeschriebene Rohstoffe.
## Rückgabe: der Bericht (steht danach auch in P.d.story.reports, neuester zuerst).
static func finish(hk: String, area: int, hours: int, loot: Dictionary, seed_t: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("auto|%s|%d|%d|%d" % [hk, area, hours, int(seed_t)])
	if G.arg("auto_seed") != "":
		rng.seed = int(G.arg("auto_seed"))
	var events: Array = []
	var extra := {}
	var n := int(DG.EVENTS_N.get(hours, 3))
	# ein Ereignis passt immer zum Gebiet
	var ae: Array = DG.AUTO_AREA_EVENTS[clampi(area, 0, DG.AUTO_AREA_EVENTS.size() - 1)]
	events.append([String(ae[rng.randi() % ae.size()]), "area"])
	var tot := 0.0
	for e in DG.AUTO_EVENTS:
		tot += float(e.w)
	var used := {}
	var guard := 0
	while events.size() < n and guard < 40:
		guard += 1
		var x := rng.randf() * tot
		var pick: Dictionary = DG.AUTO_EVENTS[0]
		for e in DG.AUTO_EVENTS:
			x -= float(e.w)
			if x <= 0.0:
				pick = e
				break
		if used.has(pick.text):
			continue
		used[pick.text] = true
		var gain: Dictionary = pick.gain
		var kind := "info"
		if gain.has("chest"):
			var c := int(gain.chest)
			extra["chests"] = int(extra.get("chests", 0)) + c
			P.add_chest("find", c)
			kind = "chest"
		elif gain.has("res"):
			var res_w: Dictionary = D.AREAS[area].res
			for r in res_w:
				var amt := int(float(loot.get(r, 0)) * float(gain.res))
				if amt > 0:
					var got := P.add(String(r), amt)
					loot[r] = int(loot.get(r, 0)) + got
					extra[r] = int(extra.get(r, 0)) + got
			kind = "res"
		elif gain.has("xp"):
			var xp := 60.0 * hours * float(gain.xp)
			P.add_hero_xp(hk, xp)
			extra["xp"] = int(extra.get("xp", 0)) + int(xp)
			kind = "xp"
		elif gain.has("egg"):
			var WS = load("res://src/welt_state.gd")
			if WS.add_egg("auto", "", rng) != "":
				extra["egg"] = 1
				kind = "egg"
			else:
				P.add_chest("find", 1)
				extra["chests"] = int(extra.get("chests", 0)) + 1
				kind = "chest"
		events.append([String(pick.text), kind])
	# Gefahr
	var rk := risk(hk, area, hours)
	var hurt := 0.0
	if rng.randf() < rk or G.arg("auto_hurt") == "1":
		hurt = injury_minutes(hours)
		Story.injure(hk, hurt)
		events.append([String(DG.AUTO_DANGER[clampi(area, 0, DG.AUTO_DANGER.size() - 1)]) + " – verletzt", "hurt"])
	else:
		events.append(["Heil zurückgekehrt", "ok"])
	var rep := {"hero": hk, "area": area, "hours": hours, "t": P.now(), "events": events, "loot": loot.duplicate(), "extra": extra,
		"hurt": hurt, "danger": danger_level(rk), "new": true}
	var s := Story.st()
	if not s.is_empty():
		(s.reports as Array).push_front(rep)
		while (s.reports as Array).size() > DG.REPORTS_KEEP:
			(s.reports as Array).pop_back()
	P.count_up("auto_reports", 1)
	P.mark()
	return rep


static func reports() -> Array:
	return Story.st().get("reports", [])


static func latest(hk: String) -> Dictionary:
	for r in reports():
		if String(r.hero) == hk:
			return r
	return {}


static func unseen() -> int:
	var n := 0
	for r in reports():
		if bool(r.get("new", false)):
			n += 1
	return n


static func mark_read() -> void:
	for r in reports():
		r["new"] = false


# ================================================================= Anzeige
## Bild: das vorgerenderte Gebiet mit dem Helden davor (unten links), dazu der Name des Gebiets.
static func picture(area: int, hk: String, size := Vector2(480, 270), hurt := false) -> Control:
	var ak := String(D.AREAS[clampi(area, 0, D.AREAS.size() - 1)].key)
	var root := Control.new()
	root.custom_minimum_size = size
	root.clip_contents = true
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var img := TextureRect.new()
	img.texture = UI.tex("scene_" + ak) if UI.has_pic("scene_" + ak) else UI.tex("area_" + ak)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(img)
	if hk != "":
		var hp := UI.hero_pic(hk, size.y * 0.78)
		hp.position = Vector2(size.x * 0.04, size.y * 0.2)
		if hurt:
			hp.modulate = Color(1.0, 0.82, 0.82)
		root.add_child(hp)
	var tag := UI.label(String(D.AREAS[clampi(area, 0, D.AREAS.size() - 1)].name), 22, UI.WHITE)
	tag.add_theme_constant_override("outline_size", 8)
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	tag.position = Vector2(size.x - 10.0 - 12.0 * float(String(D.AREAS[area].name).length()), 8)
	root.add_child(tag)
	var frame := Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0)
	st.border_color = UI.EDGE
	st.set_border_width_all(3)
	st.set_corner_radius_all(14)
	frame.add_theme_stylebox_override("panel", st)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	return root


const EV_ICON := {"area": "ui_map", "info": "ui_check", "chest": "chest_find", "res": "ui_crate", "xp": "ui_up", "egg": "p_egg_nest", "hurt": "ui_skull", "ok": "ui_heart"}
const EV_COL := {"hurt": Color("FF7A7A"), "chest": Color("FFD23E"), "egg": Color("FFD23E"), "ok": Color("8FE07A")}


## Berichtskarte: Bild links, rechts Kopf, Ereignisliste, Beute, Verletzung.
static func card(rep: Dictionary, wide := true) -> Control:
	var hk := String(rep.hero)
	var area := int(rep.area)
	var hurt := float(rep.get("hurt", 0.0)) > 0.0
	var pic := picture(area, hk, Vector2(420, 236) if wide else Vector2(360, 202), hurt)
	var col := UI.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hname := String(D.HEROES[hk].name) if D.HEROES.has(hk) else hk
	col.add_child(UI.label("%s ist aus %s zurück (%d Std)" % [hname, String(D.AREAS[area].name), int(rep.hours)], 24, UI.GOLD))
	for ev in rep.events:
		var k := String(ev[1])
		var row := UI.hbox(8, [UI.pic(String(EV_ICON.get(k, "ui_check")), 30.0, "ui_check"), UI.label(String(ev[0]), 21, EV_COL.get(k, UI.TEXT), false)])
		col.add_child(row)
	var lt := {}
	for r in rep.loot:
		if int(rep.loot[r]) > 0:
			lt[r] = int(rep.loot[r])
	if not lt.is_empty():
		col.add_child(UI.hbox(8, [UI.label("Beute:", 21, UI.TEXT, false), UI.cost_row(lt, 22, false)]))
	if hurt:
		var left := Story.injury_left(hk)
		var t := "Verletzt: %s Pause" % UI.time_text(left) if left > 0.0 else "Wieder gesund"
		col.add_child(UI.label(t, 21, UI.RED if left > 0.0 else UI.GREEN))
	var body: BoxContainer = UI.hbox(14, [pic, col]) if wide else UI.vbox(10, [pic, col])
	return UI.card(body, Color("1C3A66"), 14, Color("C9A86A") if bool(rep.get("new", false)) else Color(0, 0, 0, 0))


## Gefahren-Anzeige für das Losschicken (gering / mittel / hoch und Prozent).
static func danger_chip(hk: String, area: int, hours: int) -> Control:
	var r := risk(hk, area, hours)
	var lv := danger_level(r)
	var cols := [UI.GREEN, UI.ORANGE, UI.RED]
	var t := "Gefahr: %s (%d %% Verletzung)" % [String(DG.DANGER_NAME[lv]), int(round(r * 100.0))]
	return UI.pill(UI.hbox(8, [UI.pic("ui_skull", 26.0, "", cols[lv]), UI.label(t, 20, cols[lv], false)]))
