extends RefCounted
## Bildschirm "Clan": beitreten, gründen, Mitglieder, Wochenziel, Spenden, Zurufe.
## Mitspieler sind simuliert (siehe social.gd). Es gibt bewusst keinen freien Text-Chat.

const D = preload("res://src/data.gd")
const UI = preload("res://src/ui.gd")

const TABS := ["Mitglieder", "Spenden", "Zurufe"]
const TAB_KEYS := ["members", "donate", "shouts"]
const TAB_ICONS := ["ui_friends", "ui_crate", "ui_mail"]

var S
var _name_edit: LineEdit


func setup(arg) -> void:
	if not S.st.has("tab"):
		S.st["tab"] = 0
	if arg is String and TAB_KEYS.has(arg):
		S.st["tab"] = TAB_KEYS.find(arg)


func build() -> Control:
	var v := UI.vbox(10)
	v.add_child(S.notice_sim())
	if P.social.has_clan():
		_clan(v)
	else:
		_no_clan(v)
	return v


# ----------------------------------------------------------------- ohne Clan
func _no_clan(c: VBoxContainer) -> void:
	var soc = P.social
	var lvl := int(P.d.level)
	if lvl < D.CLAN_MIN_LEVEL:
		c.add_child(UI.card(UI.hbox(12, [UI.icon("lock", 44.0, UI.GOLD), UI.label("Clans gibt es ab Spielerstufe %d. Du bist Stufe %d." % [D.CLAN_MIN_LEVEL, lvl], 25, UI.GOLD)]), Color("4A3A1C"), 12, UI.GOLD))
	var cols := UI.hbox(16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := UI.vbox(8)
	for e in soc.clan_list():
		var entry: Dictionary = e
		var t := UI.vbox(0, [UI.label(String(entry.name), 25), UI.label("Clan-Stufe %d · %d/%d Mitglieder · ab Spielerstufe %d" % [int(entry.level), int(entry.members), D.CLAN_SIZE, int(entry.min_level)], 19, UI.GREY, false)])
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := UI.button("Beitreten", S.act(func():
			if S.say(soc.join_clan(entry), "Willkommen bei %s!" % String(entry.name)):
				UI.sfx("ui_claim", "upgrade", -4.0)), "green", 24)
		b.custom_minimum_size = Vector2(190, 72)
		UI.disable(b, lvl < D.CLAN_MIN_LEVEL or lvl < int(entry.min_level))
		list.add_child(UI.card(UI.hbox(14, [UI._drawn("shield", 64.0, Color.from_hsv(float(int(entry.seed) % 6) / 6.0, 0.6, 0.95)), t, b]), UI.NAVY_L, 10))
	var left := UI.vbox(6, [S.head("Clans in deiner Nähe", 26), S.scroll(list, "clan_list")])
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.7
	cols.add_child(left)

	var cr := UI.vbox(10, [S.head("Eigenen Clan gründen", 26)])
	cr.add_child(UI.text("Such dir einen Namen mit 3 bis 16 Zeichen aus. Bitte freundlich bleiben.", 21))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Clan-Name"
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(0, 70)
	_name_edit.text = String(S.st.get("clan_name", ""))
	_name_edit.text_changed.connect(func(t2: String): S.st["clan_name"] = t2)
	cr.add_child(_name_edit)
	cr.add_child(UI.hbox(10, [UI.label("Kosten:", 23), UI.cost_row({"coins": 500}, 23)]))
	var gb := UI.button("Gründen", S.act(func():
		if S.say(soc.create_clan(_name_edit.text), "Clan gegründet!"):
			S.st["clan_name"] = ""
			UI.sfx("ui_buy", "upgrade", -4.0)), "gold", 30, "ui_clan")
	gb.custom_minimum_size = Vector2(0, 84)
	UI.disable(gb, lvl < D.CLAN_MIN_LEVEL)
	cr.add_child(gb)
	cr.add_child(S.hint("Im Clan helft ihr euch mit Rohstoffen, sammelt Punkte für das Wochenziel und bekommt dafür eine Clankiste.", 20))
	var right := UI.panel(cr, UI.NAVY, UI.EDGE, 22, 20)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	cols.add_child(right)
	c.add_child(cols)


# ----------------------------------------------------------------- mit Clan
func _clan(c: VBoxContainer) -> void:
	var soc = P.social
	var cl: Dictionary = soc.s.clan
	var pts: int = soc.clan_points()
	var goal: int = soc.clan_goal()
	var done := int(cl.chest_week) == int(soc.abs_week())
	var head := UI.hbox(16)
	head.add_child(UI._drawn("shield", 84.0, Color.from_hsv(float(int(cl.color) % 6) / 6.0, 0.6, 0.95)))
	var nm := UI.vbox(0, [UI.label(String(cl.name), 38), UI.label("Clan-Stufe %d · %d/%d Mitglieder · Clan-Bonus: +%d %%" % [int(cl.level), cl.members.size() + 1, D.CLAN_SIZE, int(round(float(soc.clan_bonus()) * 100.0))], 20, UI.GREY, false)])
	head.add_child(nm)
	var goal_box := UI.vbox(2)
	goal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_box.add_child(UI.hbox(8, [UI.label("Wochenziel", 22), UI.label("%s / %s" % [UI.fmt(pts), UI.fmt(goal)], 22, UI.GOLD), UI.label("geschafft – Clankiste kam per Post" if done else "Belohnung: Clankiste für alle", 18, UI.GREEN if done else UI.GREY, false)]))
	var bar := UI.bar(float(pts) / maxf(1.0, goal), UI.GREEN if done else D.C_BAR_BLUE, Vector2(200, 28), "clan_goal")
	goal_box.alignment = BoxContainer.ALIGNMENT_CENTER
	goal_box.add_child(bar)
	head.add_child(goal_box)
	head.add_child(UI.chest_pic("clan", 76.0))
	c.add_child(UI.card(head, UI.NAVY_L, 12))
	c.add_child(S.tabs(TABS, "tab", 23, TAB_ICONS))
	match int(S.st.tab):
		0:
			_members(c, cl)
		1:
			_donate(c, cl)
		2:
			_shouts(c)


func _members(c: VBoxContainer, cl: Dictionary) -> void:
	var soc = P.social
	var rows: Array = []
	for m in cl.members:
		rows.append({"name": m.name, "level": int(m.level), "points": int(m.points), "role": m.role, "me": false})
	rows.append({"name": P.d.name, "level": int(P.d.level), "points": int(cl.my_points), "role": "Anführer" if cl.own else "Mitglied", "me": true})
	rows.sort_custom(func(a, b): return int(a.points) > int(b.points))
	var list := UI.vbox(4)
	for i in rows.size():
		var e: Dictionary = rows[i]
		var rank := UI.label("%d." % (i + 1), 22)
		rank.custom_minimum_size = Vector2(54, 0)
		var n := UI.label(String(e.name) + ("  (du)" if e.me else ""), 22, UI.GOLD if e.me else UI.WHITE)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.clip_text = true
		var role := UI.label(String(e.role), 19, UI.SKY if String(e.role) != "Mitglied" else UI.GREY, false)
		role.custom_minimum_size = Vector2(170, 0)
		var lv := UI.label("Stufe %d" % int(e.level), 19, UI.GREY, false)
		lv.custom_minimum_size = Vector2(110, 0)
		var p := UI.label(UI.fmt(float(e.points)), 22, UI.GOLD)
		p.custom_minimum_size = Vector2(110, 0)
		p.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		list.add_child(UI.card(UI.hbox(10, [rank, n, role, lv, p]), Color("5A4A14") if e.me else UI.NAVY_L, 8, UI.GOLD if e.me else Color(0, 0, 0, 0)))
	var m2 := MarginContainer.new()
	m2.add_theme_constant_override("margin_right", 2)
	m2.add_child(list)
	c.add_child(S.scroll(m2, "clan_members"))
	var lb := UI.button("Clan verlassen", func():
		S.confirm("Den Clan „%s“ wirklich verlassen?" % String(cl.name), func(): soc.leave_clan(), "Verlassen"), "red", 22)
	lb.custom_minimum_size = Vector2(0, 70)
	lb.size_flags_horizontal = Control.SIZE_SHRINK_END
	lb.set_meta("danger", true)
	c.add_child(lb)


func _donate(c: VBoxContainer, cl: Dictionary) -> void:
	var soc = P.social
	var cols := UI.hbox(16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Bitten der anderen
	var list := UI.vbox(8)
	var asks: Array = cl.asks
	if asks.is_empty():
		list.add_child(S.hint("Gerade bittet niemand um etwas. Schau später wieder vorbei."))
	for i in asks.size():
		var a: Dictionary = asks[i]
		var r := String(a.res)
		var t := UI.vbox(0, [UI.label(String(a.name), 23), UI.label("bittet um %s" % String(D.RES_NAME[r]), 19, UI.GREY, false)])
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var chip := UI.res_chip(r, int(a.amount), 24, true)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var b := UI.button("Spenden", S.act(func():
			if S.say(soc.donate(i), "Gespendet! Dein Clan dankt dir."):
				UI.sfx("ui_claim", "pay", -4.0)), "green", 24)
		b.custom_minimum_size = Vector2(180, 72)
		UI.disable(b, P.res(r) <= 0)
		list.add_child(UI.card(UI.hbox(14, [UI.hero_pic("settler", 64.0), t, chip, b]), UI.NAVY_L, 10))
	var left := UI.vbox(6, [S.head("Bitten aus dem Clan", 25), S.scroll(list, "clan_asks")])
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.3
	cols.add_child(left)
	# eigene Bitte
	var own := UI.vbox(10, [S.head("Deine Bitte", 25)])
	var rq: Dictionary = soc.s.request
	if not rq.is_empty():
		var r2 := String(rq.res)
		own.add_child(UI.hbox(10, [UI.icon(r2, 36.0), UI.label("%d / %d %s" % [int(rq.filled), int(rq.amount), String(D.RES_NAME[r2])], 24, UI.GOLD)]))
		own.add_child(UI.bar(float(rq.filled) / maxf(1.0, float(rq.amount)), UI.GREEN, Vector2(200, 24), "clan_request"))
		own.add_child(S.hint("Spenden kommen per Post im Funkturm an.", 19))
	if soc.can_request():
		own.add_child(UI.text("Worum möchtest du bitten? (%d Stück, alle 8 Stunden)" % (80 + 20 * P.bunker_level()), 21))
		var g := UI.grid(2, 8)
		for r3 in D.SENDABLE:
			var rb: Button = S.card_button(false, S.act(func():
				if soc.request(r3):
					S.toast("Bitte um %s gesendet." % String(D.RES_NAME[r3]))), UI.hbox(10, [UI.icon(r3, 48.0), UI.label(String(D.RES_NAME[r3]), 23)]), 78.0, "")
			rb.custom_minimum_size = Vector2(200, 78)
			g.add_child(rb)
		own.add_child(g)
	else:
		var tl := UI.label("", 21, UI.GREY, false)
		S.live(tl, func() -> String: return "Nächste Bitte möglich in: " + UI.time_text(8 * 3600.0 - (P.now() - float(rq.get("at", 0.0)))))
		own.add_child(tl)
	var right := UI.panel(own, UI.NAVY, UI.EDGE, 22, 18)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	c.add_child(cols)


func _shouts(c: VBoxContainer) -> void:
	var soc = P.social
	var list := UI.vbox(4)
	var shouts: Array = soc.s.shouts
	if shouts.is_empty():
		list.add_child(S.hint("Noch ist es still. Ruf deinem Clan etwas zu!"))
	var from := maxi(0, shouts.size() - 20)
	for i in range(from, shouts.size()):
		var sh: Dictionary = shouts[i]
		var mine := String(sh.who) == String(P.d.name)
		var who := UI.label(String(sh.who) + ":", 21, UI.GOLD if mine else UI.SKY)
		who.custom_minimum_size = Vector2(250, 0)
		who.clip_text = true
		list.add_child(UI.card(UI.hbox(10, [who, UI.text(String(sh.text), 21, UI.WHITE)]), UI.NAVY_L, 8))
	var sc: ScrollContainer = S.scroll(list, "clan_shouts")
	c.add_child(sc)
	# beim Aufbau ans Ende rollen
	sc.ready.connect(func():
		await sc.get_tree().process_frame
		if is_instance_valid(sc):
			sc.scroll_vertical = 100000)
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 8)
	f.add_theme_constant_override("v_separation", 8)
	for i in D.SHOUTS.size():
		var b := UI.button(String(D.SHOUTS[i]), S.act(func(): soc.shout(i)), "", 22)
		b.custom_minimum_size = Vector2(0, 70)
		f.add_child(b)
	c.add_child(f)
	c.add_child(S.hint("Im Clan gibt es nur feste Zurufe und keinen freien Chat.", 18))
