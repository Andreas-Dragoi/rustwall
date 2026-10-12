extends RefCounted
## Bildschirm "Monsterbuch" (Paket 11): je Familie die Arten mit drehbarem Modell, Werten, Schwäche und dem
## Zähler „besiegt“. Bei 10 / 100 / 1 000 Besiegten gibt es 2 / 5 / 15 Juwelen. Nur begegnete Arten sind aufgedeckt.

const D = preload("res://src/data.gd")
const UI = preload("res://src/ui.gd")
const Vat = preload("res://src/vat.gd")
const Models = preload("res://src/models.gd")
const BossFig = preload("res://src/boss_fig.gd")

var S


func setup(_arg) -> void:
	if not S.st.has("tab"):
		S.st["tab"] = 0
	if not S.st.has("sel"):
		S.st["sel"] = ""
	if S.st.has("demo") and G.selftest:
		# nur für Bildschirmfotos im Test (--st=demo:1): alle Arten aufgedeckt, mit Beispiel-Zählern
		var kd := {}
		var seen: Array = []
		for i in D.ENEMIES.size():
			seen.append(String(D.ENEMIES[i].key))
			kd[String(D.ENEMIES[i].key)] = (i * 37) % 140
		P.bestiary_add(kd, seen)
		S.st.erase("demo")


func _family_list(fam: String) -> Array:
	var out: Array = []
	for i in D.ENEMIES.size():
		var e: Dictionary = D.ENEMIES[i]
		if String(e.family) == fam and String(e.role) != "object" and not (e.has("phase_of") and false):
			out.append(i)
	return out


func build() -> Control:
	var names: Array = []
	for f in D.AREA_FAMILY:
		names.append(String(D.FAMILIES[f].name).split(" ")[0])
	var v := UI.vbox(12)
	v.add_child(S.tabs(names, "tab", 22))
	var fam := String(D.AREA_FAMILY[clampi(int(S.st.tab), 0, D.AREA_FAMILY.size() - 1)])
	var fd: Dictionary = D.FAMILIES[fam]
	var list := _family_list(fam)
	var sel := String(S.st.sel)
	var found := false
	for i in list:
		if String(D.ENEMIES[i].key) == sel:
			found = true
	if not found:
		sel = String(D.ENEMIES[list[0]].key)
		S.st["sel"] = sel
	# Kopf: Familie, Stimmung, Schwäche, Fortschritt
	var seen_n := 0
	for i in list:
		if bool(P.bestiary_entry(String(D.ENEMIES[i].key)).seen):
			seen_n += 1
	var area_i: int = D.AREA_FAMILY.find(fam)
	var head := UI.hbox(14, [S.head(String(fd.name), 30), UI.label("· " + String(D.AREAS[area_i].name), 24, UI.SKY), UI.spacer(true),
		UI.pic("ui_target", 34.0), UI.label(String(fd.weak_text), 24, UI.ORANGE), UI.pill(UI.label("%d von %d entdeckt" % [seen_n, list.size()], 22, UI.GOLD))])
	v.add_child(head)
	var cols := UI.hbox(16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# ---- links: Arten der Familie
	var g := UI.grid(2, 10)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in list:
		g.add_child(_card(i, sel))
	var left: Control = S.scroll(g, "list")
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	cols.add_child(left)
	# ---- rechts: gewählte Art
	var right: Control = _detail(int(D.ENEMY_INDEX[sel]), fd)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.15
	cols.add_child(right)
	v.add_child(cols)
	return v


func _card(i: int, sel: String) -> Control:
	var def: Dictionary = D.ENEMIES[i]
	var key := String(def.key)
	var en: Dictionary = P.bestiary_entry(key)
	var seen := bool(en.seen)
	var active := key == sel
	var pic: Control = UI.enemy_pic(i, 72.0)
	if not seen:
		pic.modulate = Color(0.05, 0.08, 0.15, 0.9)          # unbekannt: nur der Umriss
	var nm := UI.label(String(def.name) if seen else "???", 24, UI.WHITE if seen else UI.GREY)
	nm.clip_text = true
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sub := UI.sub_label(("%s · %s besiegt" % [String(D.ROLE_NAME.get(def.role, "")), UI.fmt(float(en.kills))]) if seen else "noch nicht begegnet", 19, UI.TEXT, active)
	var mid := UI.vbox(2, [nm, sub])
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UI.hbox(12, [pic, mid])
	if P.bestiary_claimable(key) >= 0:
		row.add_child(UI.pic("res_gems", 40.0))
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func():
		UI.sfx("ui_tap", "", -8.0)
		S.st["sel"] = key
		S.refresh())
	var c := UI.card(row, Color("7A5A12") if active else (UI.NAVY_L if seen else UI.NAVY_D), 10, UI.GOLD if active else Color(0, 0, 0, 0))
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.ignore_mouse(row)
	c.add_child(b)
	return c


## Das Modell für die Vorschau: eigenes Modell mit Animations-Textur (Clip „walk“), Boss-Figur oder das vorläufige Ersatzmodell.
static func model(i: int) -> Node3D:
	var def: Dictionary = D.ENEMIES[i]
	var key := String(def.key)
	if def.role == "boss" and not Vat.boss_info(key).is_empty():
		var fig := BossFig.new()
		fig.setup(key, Vat.boss_info(key))
		fig.auto = true
		return fig
	if Vat.has(key):
		return Vat.preview(key, "walk")
	var src := int(D.ROLE_FALLBACK.get(def.role, 0)) if i >= D.E_FIRST_NEW else i
	var skey := String(D.ENEMIES[src].key)
	var tint: Color = D.FAMILY_TINT.get(def.family, Color.WHITE) if i >= D.E_FIRST_NEW else Color.WHITE
	var n: Node3D
	var s := float(def.scale) * D.CHAR_SCALE
	if Vat.has(skey):
		n = Vat.preview(skey, "walk", tint)
		s = float(def.scale) / float(D.ENEMIES[src].scale)
	else:
		n = Models.glb("e_%d" % src)
	n.scale = Vector3(s, s, s)
	return n


static func has_own_model(i: int) -> bool:
	var def: Dictionary = D.ENEMIES[i]
	var key := String(def.key)
	return Vat.has(key) or not Vat.boss_info(key).is_empty() or i < D.E_FIRST_NEW


func _detail(i: int, fd: Dictionary) -> Control:
	var def: Dictionary = D.ENEMIES[i]
	var key := String(def.key)
	var en: Dictionary = P.bestiary_entry(key)
	var seen := bool(en.seen)
	var v := UI.vbox(10)
	var top := UI.hbox(16)
	# Vorschau
	var hgt := float(def.scale) * 1.3
	var pv: Control = S.preview_model("enemy:" + key, func() -> Node3D: return model(i), 2.6 + hgt * 2.3, hgt * 0.5)
	pv.custom_minimum_size = Vector2(430, 430)
	pv.modulate = Color.WHITE if seen else Color(0.02, 0.04, 0.1, 1.0)
	var fr := UI.frame(pv, UI.scenery("meadow"))
	fr.custom_minimum_size = Vector2(430, 430)
	top.add_child(fr)
	var info := UI.vbox(8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UI.label(String(def.name) if seen else "???", 44)
	nm.add_theme_constant_override("outline_size", 10)
	info.add_child(nm)
	info.add_child(UI.label(String(D.ROLE_NAME.get(def.role, "")), 25, Color("8FB8F0")))
	if seen:
		info.add_child(UI.text(String(def.look).capitalize() if false else String(def.look), 22, UI.SKY))
		info.add_child(UI.text(String(def.text), 23, UI.WHITE))
		if not has_own_model(i):
			info.add_child(UI.pill(UI.label("Modell folgt", 20, UI.ORANGE)))
	else:
		info.add_child(UI.text("Dieser Art bist du noch nicht begegnet. Du findest sie hier: %s." % String(D.AREAS[D.AREA_FAMILY.find(String(def.family))].name), 23, UI.GREY))
	top.add_child(info)
	v.add_child(top)
	# Werte
	if seen:
		var st := UI.grid(2, 8)
		st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for r in [["ui_heart", "Leben", UI.fmt(float(def.hp))], ["ui_speed", "Tempo", ("%.1f m/s" % float(def.speed)).replace(".", ",")],
				["ui_target", "Schaden", UI.fmt(float(def.dmg))], ["res_coins", "Münzen", str(int(def.coins))]]:
			var sr := UI.stat_row(String(r[0]), String(r[1]), String(r[2]), 24)
			sr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			st.add_child(sr)
		v.add_child(UI.card(st, UI.NAVY, 14, Color(UI.EDGE, 0.8)))
		v.add_child(_weak_row(fd))
		if def.has("counter"):
			v.add_child(UI.hbox(12, [UI.pic("ui_info", 34.0, "", UI.ORANGE), UI.text("Tipp: " + String(def.counter), 22, UI.ORANGE)]))
	# Fundorte (auch für unbekannte Arten: man weiß, wo man suchen muss)
	var places: Array = D.enemy_places(key)
	v.add_child(UI.hbox(12, [UI.pic("ui_map", 34.0, "", UI.SKY), UI.text("Fundort: " + " · ".join(places), 21, UI.SKY)]))
	# Zähler und Belohnungen
	var kills := int(en.kills)
	var claimed := int(en.claimed)
	var rw := UI.hbox(10)
	for t in D.BESTIARY_TIERS.size():
		var need := int(D.BESTIARY_TIERS[t])
		var got := claimed > t
		var ready := not got and kills >= need and claimed == t
		var lbl := UI.label("%s besiegt" % UI.fmt(float(need)), 20, UI.GREEN if got else UI.WHITE)
		var inner: Control
		if got:
			inner = UI.hbox(8, [UI.pic("ui_check", 34.0, "", UI.GREEN), lbl])
		else:
			var b := UI.button(str(int(D.BESTIARY_GEMS[t])), S.act(func():
				var n: int = P.bestiary_claim(key)
				if n > 0:
					UI.sfx("ui_claim", "", -4.0)
					S.toast("+%d Juwelen" % n)), "green" if ready else "dark", 24, "res_gems")
			b.custom_minimum_size = Vector2(120, 62)
			UI.disable(b, not ready)
			inner = UI.vbox(4, [lbl, b])
		var c := UI.card(inner, Color("1F5A34") if (got or ready) else UI.NAVY_L, 10, UI.GREEN if ready else Color(0, 0, 0, 0))
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rw.add_child(c)
	var nxt := claimed if claimed < D.BESTIARY_TIERS.size() else D.BESTIARY_TIERS.size() - 1
	var bar := UI.bar(clampf(float(kills) / float(D.BESTIARY_TIERS[nxt]), 0.0, 1.0), UI.GOLD, Vector2(200, 22))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(UI.hbox(12, [UI.enemy_pic(i, 44.0), UI.label("Besiegt: %s" % UI.fmt(float(kills)), 26, UI.GOLD), bar]))
	v.add_child(rw)
	return UI.panel(v, UI.NAVY, UI.EDGE, 22, 18)


## Paket G2: Schwächen als Symbole (Element + Faktor), grün = verwundbar, rot = widerstandsfähig.
func _weak_row(fd: Dictionary) -> Control:
	var row := UI.hbox(10, [UI.label("Schwäche:", 22, UI.ORANGE)])
	var wk: Dictionary = fd.get("weak", {})
	if wk.is_empty():
		row.add_child(UI.label("keine", 22, UI.GREY))
	for el in wk:
		var k := float(wk[el])
		var txt := "immun" if k <= 0.0 else ("%+d %%" % int(round((k - 1.0) * 100.0)))
		var col: Color = UI.GREEN if k > 1.0 else UI.RED
		var chip := UI.hbox(4, [UI.pic(String(D.ELEMENT_ICON.get(el, "ui_target")), 34.0, "", col), UI.label(txt, 21, col)])
		chip.tooltip_text = String(D.ELEMENT_NAME.get(el, el))
		row.add_child(UI.pill(chip, 8, 3))
	if fd.has("slow"):
		row.add_child(UI.pill(UI.hbox(4, [UI.pic("ui_snow", 30.0, "", UI.RED), UI.label("Bremsen halb", 20, UI.RED)]), 8, 3))
	return row
