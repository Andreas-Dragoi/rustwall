extends RefCounted
## V6 Paket B: Bausteine der Anzeige im Spiel (hud.gd ruft sie an wenigen Stellen auf).
##  - Wetter der Flut in der Wellen-Vorschau, Zusatzbeute/Verletzte/Rückblick im Ergebnis
##  - Leiste unten rechts: „Alle reparieren (Kosten)“ und „Flut-Rückblick“ (neu), Bewertungs-Hinweis nach dem ersten Flut-Sieg
##  - Gebäudefenster: Schaden mit Reparieren, Glitzer-Hinweis bei Hindernissen, Tüftelecke der Werkstatt
##  - Bunker: „Aufbauten“ – Code teilen/einfügen, gegen die Flut testen
##  - Optionen: Mitteilungen (Handy)

const D = preload("res://src/data.gd")
const DB = preload("res://src/data_basis.gd")
const UI = preload("res://src/ui.gd")
const FW = preload("res://src/flood_weather.gd")
const BState = preload("res://src/basis_state.gd")
const Replay = preload("res://src/flood_replay.gd")
const LayoutCode = preload("res://src/layout_code.gd")
const Notify = preload("res://src/notify.gd")
const R = preload("res://src/research.gd")


# ================================================================= Flut-Dialog und Ergebnis
## Wetter der Flut als Zeilen in der Wellen-Vorschau.
static func weather_rows(stats: VBoxContainer, fd: Dictionary) -> void:
	var kind := String(fd.get("weather", "klar"))
	var night := bool(fd.get("night", false))
	var rows := FW.rows(kind, night)
	var box := UI.vbox(2, [UI.label("Wetter der Flut", 21, UI.SKY)])
	for r in rows:
		var t := UI.label("%s – %s" % [String(r[1]), String(r[2])], 19, UI.TEXT if String(r[1]) == "Klar" else UI.ORANGE, false)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(UI.hbox(10, [UI.pic(String(r[0]), 34.0, "ui_info"), t]))
	box.set_meta("weather", kind)
	stats.add_child(box)


## Kampfanzeige: kleines Wetter-Schild unter dem Bunker-Balken (nur bei Regen, Nebel oder Nacht).
static func battle_weather(v: VBoxContainer, world) -> void:
	var fd: Dictionary = world.flood
	var kind := String(fd.get("weather", "klar"))
	var night := bool(fd.get("night", false))
	if kind == "klar" and not night:
		return
	var icon := String(DB.WEATHER.get(kind, {}).get("icon", "ui_sun")) if kind != "klar" else String(DB.NIGHT.icon)
	var row := UI.hbox(8, [UI.pic(icon, 38.0, "ui_info"), UI.label(FW.label(kind, night), 22, UI.SKY)])
	if night and kind != "klar":
		row.add_child(UI.pic(String(DB.NIGHT.icon), 30.0, "ui_info"))
	row.set_meta("weather", kind)
	v.add_child(row)


## Ergebnis: Zusatzbeute (Nacht, Plünderer), Verletzte, Knopf „Rückblick“.
static func result_extra(hud, body: VBoxContainer, buttons: HBoxContainer, r: Dictionary) -> void:
	if r.has("extra"):
		var ex: Dictionary = r.extra
		body.add_child(UI.hbox(10, [UI.pic("res_coins", 34.0), UI.label("+%s Münzen (%s)" % [UI.fmt(float(ex.coins)), String(ex.why)], 22, UI.GOLD)]))
	if int(r.get("injured", 0)) > 0:
		body.add_child(UI.hbox(10, [UI.pic("ui_heart", 34.0, "", UI.RED), UI.label("%d Bewohner verletzt – sie heilen im Bunker." % int(r.injured), 21, UI.ORANGE, false)]))
	if bool(r.get("replay", false)) and hud.world != null and hud.world.mode != "exp":
		var rb := UI.button("Rückblick", func(): hud._leave_result("rueckblick"), "dark", 28, "ui_replay")
		rb.custom_minimum_size = Vector2(250, 92)
		buttons.add_child(rb)
		buttons.move_child(rb, 0)


## Nach dem Ergebnis zurück in der Basis: Bewertungs-Hinweis nach dem ersten Flut-Sieg.
static func after_result(hud) -> void:
	if not bool(P.d.get("rate", {}).get("pending", false)) or G.selftest or G.autotest != "":
		return
	ask_rating(hud)


static func ask_rating(hud) -> void:
	var rate: Dictionary = P.d.rate
	rate.pending = false
	rate.asked = int(rate.get("asked", 0)) + 1
	P.mark()
	var t := UI.label("Gefällt dir Rustwall?", 44, UI.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := UI.text("Du hast deine erste Flut gehalten! Wenn dir das Spiel Spaß macht, hilft uns eine Bewertung im Store sehr.", 24, UI.WHITE, 640.0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var yes := UI.button("Ja, sehr!", func():
		rate.answer = "ja"
		P.mark()
		var ok := Notify.request_review()
		hud._close_modal()
		hud.toast("Danke! Die Bewertung im Store folgt in der Handy-Fassung." if not ok else "Danke für deine Bewertung!"), "green", 30, "ui_heart")
	yes.custom_minimum_size = Vector2(240, 84)
	var meh := UI.button("Geht so", func():
		rate.answer = "meh"
		P.mark()
		hud._close_modal()
		hud.toast("Danke! Schreib uns gern, was besser werden soll (Optionen → Hilfe)."), "dark", 28)
	meh.custom_minimum_size = Vector2(200, 84)
	var later := UI.button("Später", func():
		rate.answer = ""
		P.mark()
		hud._close_modal(), "dark", 26)
	later.custom_minimum_size = Vector2(180, 84)
	var row := UI.hbox(16, [later, meh, yes])
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	hud._show_modal(UI.vbox(22, [UI.pic("ui_trophy", 96.0), t, sub, row]), 0.55, UI.GOLD)


# ================================================================= Leiste unten rechts
## Knopf, der sich selbst aktualisiert (zweimal je Sekunde).
class LiveButton extends Button:
	var fn: Callable
	var _t := 0.0

	func _process(dt: float) -> void:
		_t -= dt
		if _t <= 0.0:
			_t = 0.5
			fn.call(self)


static func bar(hud) -> Control:
	var h := UI.hbox(10)
	h.size_flags_horizontal = Control.SIZE_SHRINK_END
	var rep := _live_button("Alle reparieren", "ui_wrench", "dark", func(b: Button):
		var w = hud.world
		if w == null or w.mode != "peace" or w.editing():
			b.visible = false
			return
		var q := BState.repair_quote()
		var n := int(q.walls) + int(q.buildings)
		b.visible = n > 0 and hud._build_box == null
		if b.visible:
			var cs: Array = []
			for r in q.cost:
				cs.append("%s %s" % [UI.fmt(float(q.cost[r])), String(D.RES_NAME[r])])
			UI.btn_text(b, "Alle reparieren (%s)" % ", ".join(cs))
			UI.btn_kind(b, "green" if P.can_pay(q.cost) else "dark"), func():
		var w2 = hud.world
		if w2 == null or w2.get("life") == null:
			return
		var why: String = w2.life.repair_all()
		if why != "":
			hud.toast(why)
			UI.sfx("ui_error", "error", -6.0)
		else:
			hud.toast("Alles repariert!"))
	rep.set_meta("guide", "repair")
	h.add_child(rep)
	var rp := _live_button("Flut-Rückblick", "ui_replay", "gold", func(b: Button):
		var w = hud.world
		b.visible = w != null and w.mode == "peace" and Replay.unseen() > 0 and hud._build_box == null and not w.editing(), func():
		hud._open("rueckblick"))
	h.add_child(rp)
	return h


static func _live_button(text: String, icon_name: String, kind: String, upd: Callable, cb: Callable) -> Button:
	var b := LiveButton.new()
	b.fn = upd
	b.focus_mode = Control.FOCUS_NONE
	var tv := UI._variation(kind)
	if tv != "":
		b.theme_type_variation = tv
	b.add_theme_font_size_override("font_size", 24)
	b.text = text
	b.icon = UI.tex(icon_name)
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", 36)
	b.custom_minimum_size = Vector2(0, 70)
	b.visible = false
	b.pressed.connect(func():
		Sfx.play("click", -8.0)
		cb.call())
	UI.squash(b)
	return b


# ================================================================= Gebäudefenster
## Zusatz-Zeilen im Fenster eines gewählten Gebäudes (Schaden, Fund, Tüftelecke).
static func sel_rows(hud, v: VBoxContainer, btns: HBoxContainer, b: Dictionary) -> void:
	var key := String(b.key)
	var id := int(b.id)
	var miss := float(b.get("dmg", 0.0))
	if miss > 0.0 and not P.is_building(b):
		var q := _quote_one(b)
		var row := UI.hbox(10, [UI.pic("ui_wrench", 34.0, "", UI.ORANGE), UI.label("Beschädigt: %d %%" % int(round(miss * 100.0)), 23, UI.ORANGE), UI.spacer(true), UI.cost_row(q, 22)])
		v.add_child(UI.card(row, Color("4A2A1C"), 10, Color(UI.ORANGE, 0.7)))
		var rb := UI.button("Reparieren", func():
			var why := repair_one(hud.world, id)
			if why != "":
				hud.toast(why)
				UI.sfx("ui_error", "error", -6.0)
			hud._sel_sig = "", "green", 25, "ui_wrench")
		UI.disable(rb, not P.can_pay(q))
		btns.add_child(rb)
	if String(D.BUILDINGS.get(key, {}).get("cat", "")) == "obstacle" and String(b.get("find", "")) != "":
		v.add_child(UI.info_box("Hier glitzert etwas! Wegräumen bringt einen seltenen Fund.", 21, "ui_star"))
	if key == DB.PRELAB_BUILDING and not P.is_building(b):
		var cur := R.current()
		var t := "Tüftelecke: forschen (erste Reihe)" if R.labor_level() <= 0 else "Forschung"
		var fb := UI.button(t, func(): hud._open("forschung"), "gold" if cur == "" else "dark", 22, "ui_research")
		btns.add_child(fb)


static func _quote_one(b: Dictionary) -> Dictionary:
	var k := maxf(0.0, 1.0 - R.bonus("repair_cost"))
	var miss := float(b.get("dmg", 0.0))
	var out := {}
	var key := String(b.key)
	if key == "wall" or key == "tor":
		var rc: Dictionary = DB.REPAIR_WALL[clampi(int(b.level) - 1, 0, 2)]
		for r in rc:
			out[r] = maxi(1, int(ceil(float(rc[r]) * miss * k * (3.0 if key == "tor" else 1.0))))
	else:
		var cc: Dictionary = P.cost_for(key, int(b.level))
		out["coins"] = maxi(1, int(ceil(float(cc.get("coins", 50)) * DB.REPAIR_BUILDING_COINS * miss * k)))
	return out


## Ein einzelnes Teil reparieren.
static func repair_one(w, id: int) -> String:
	var b := P.get_building(id)
	if b.is_empty() or not b.has("dmg"):
		return ""
	var q := _quote_one(b)
	if not P.pay(q):
		return P.missing_text(q)
	b.erase("dmg")
	if w != null:
		var s = w.nodes.get(id)
		if s != null:
			s.hp = s.max_hp
			s._update_damage()
		if w.fx != null:
			var c: Vector2 = w.cell_min(int(b.x), int(b.y)) + Vector2(1, 1)
			w.fx.puff(Vector3(c.x, 1.2, c.y), Color(1.0, 0.9, 0.6), 8, 0.8)
	Sfx.play("repair_all", -6.0, 1.15)
	P.mark()
	P.buildings_changed.emit()
	return ""


# ================================================================= Aufbauten: teilen, einfügen, testen
static func layouts_dialog(hud, msg := "", code := "") -> void:
	var v := UI.vbox(14)
	var t := UI.label("Aufbauten der Basis", 42, UI.GOLD)
	v.add_child(UI.hbox(14, [UI.pic("ui_map", 60.0), t]))
	var g := UI.vbox(10)
	for slot in 3:
		var sl: int = slot
		var has: bool = P.d.layouts[sl] != null
		var row := UI.hbox(8, [UI.label("Speicher %d" % (sl + 1), 24, UI.WHITE if has else UI.GREY)])
		row.get_child(0).custom_minimum_size = Vector2(110, 0)
		row.add_child(UI.button("Sichern", func():
			P.save_layout(sl)
			layouts_dialog(hud, "Aufbau %d gesichert." % (sl + 1)), "dark", 20, "ui_check"))
		var lb := UI.button("Übernehmen", func():
			if P.load_layout(sl):
				hud._close_modal(), "dark", 20, "ui_up")
		UI.disable(lb, not has)
		row.add_child(lb)
		var cb := UI.button("Code", func():
			var c := LayoutCode.encode(sl)
			DisplayServer.clipboard_set(c)
			layouts_dialog(hud, "Code von Speicher %d kopiert (%d Zeichen)." % [sl + 1, c.length()], c), "dark", 20, "ui_mail")
		UI.disable(cb, not has)
		row.add_child(cb)
		var tb := UI.button("Gegen Flut testen", func():
			hud._close_modal()
			var why := LayoutCode.test_start(hud.world, sl)
			if why != "":
				hud.toast(why)
				UI.sfx("ui_error", "error", -6.0), "red", 20, "ui_flood")
		UI.disable(tb, not has or hud.world == null or hud.world.mode != "peace")
		row.add_child(tb)
		for c in row.get_children():
			if c is Button:
				c.custom_minimum_size = Vector2(0, 60)
		g.add_child(row)
	v.add_child(UI.card(g, UI.NAVY_L, 14))
	# Code anzeigen / einfügen
	var le := LineEdit.new()
	le.placeholder_text = "Layout-Code hier einfügen (RW1-…)"
	le.text = code
	le.custom_minimum_size = Vector2(820, 62)
	le.select_all_on_focus = true
	le.set_meta("layout_code", true)
	v.add_child(le)
	var pr := UI.hbox(8, [UI.label("Einfügen in:", 21, UI.TEXT)])
	for slot in 3:
		var sl2: int = slot
		var pb := UI.button("Speicher %d" % (sl2 + 1), func():
			var res := LayoutCode.paste(le.text, sl2)
			if bool(res.ok):
				UI.sfx("ui_claim", "", -6.0)
				layouts_dialog(hud, "Speicher %d: %s" % [sl2 + 1, String(res.why)])
			else:
				UI.sfx("ui_error", "error", -6.0)
				layouts_dialog(hud, String(res.why), le.text), "green", 20, "ui_check")
		pb.custom_minimum_size = Vector2(0, 58)
		pr.add_child(pb)
	var chk := UI.button("Prüfen", func():
		var res2 := LayoutCode.check(le.text)
		layouts_dialog(hud, String(res2.why), le.text), "dark", 20, "ui_info")
	chk.custom_minimum_size = Vector2(0, 58)
	pr.add_child(chk)
	v.add_child(pr)
	if msg != "":
		var ml := UI.text(msg, 21, UI.GOLD, 820.0)
		v.add_child(ml)
	v.add_child(UI.info_box("Ein Code beschreibt, wo jedes Gebäude steht. Beim Einfügen bekommen deine Gebäude derselben Art diese Plätze. Der Layout-Test schickt die Flut dieser Woche gegen den Aufbau – ohne Verlust; danach steht alles wieder wie vorher.", 19))
	var close := UI.button("Schließen", hud._close_modal, "red", 26, "ui_close")
	close.custom_minimum_size = Vector2(260, 72)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(close)
	hud._show_modal(v, 0.55)


# ================================================================= Optionen: Mitteilungen
static func notify_settings(S) -> Control:
	var n: Dictionary = P.d.notify
	var v := UI.vbox(10, [UI.hbox(12, [UI.pic("ui_alarm", 44.0), S.head("Mitteilungen (Handy)", 30)])])
	v.add_child(_tog(S, "Mitteilungen erlauben", n, "on"))
	if bool(n.get("on", true)):
		for k in DB.NOTIFY_KINDS:
			v.add_child(_tog(S, String(k[1]), n, String(k[0])))
	var txt := "Mitteilungen werden geplant, wenn das Spiel in den Hintergrund geht." if Notify.available() else "Auf diesem Gerät gibt es keine Mitteilungen (Web/PC). In der Handy-Fassung erinnert Rustwall an fertige Bauten, die Flut und das Tagesgeschenk."
	v.add_child(S.hint(txt, 18))
	return v


static func _tog(S, text: String, dict: Dictionary, key: String) -> Control:
	var on := bool(dict.get(key, true))
	var l := UI.label(text, 24)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := UI.button("An" if on else "Aus", S.act(func():
		dict[key] = not on
		UI.sfx("ui_toggle", "", -6.0, 1.2 if not on else 0.9)
		P.mark()), "green" if on else "dark", 24, "ui_check" if on else "ui_close")
	b.custom_minimum_size = Vector2(150, 68)
	b.set_meta("notify", key)
	return UI.hbox(12, [l, b])
