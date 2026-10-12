extends RefCounted
## Bildschirm "Saison und Ereignisse" (Paket L): Wochen-Ereignis mit Restzeit und Belohnungsstufen (Weltboss mit
## Gemeinschafts-Fortschritt), Saison-Pass (40 Stufen, kostenlose und bezahlte Spur), Wochenaufgaben, Login-Kalender,
## Saison-Rangliste, Nachrichten-Brett und Endspiel (Prestige, Albtraum+, Außenbasen Stufe 4–5).
## arg: {"tab": n} (0 Ereignis, 1 Pass, 2 Aufgaben, 3 Kalender, 4 Rangliste, 5 Neuigkeiten, 6 Endspiel)

const D = preload("res://src/data.gd")
const DL = preload("res://src/data_liveops.gd")
const LO = preload("res://src/liveops.gd")
const UI = preload("res://src/ui.gd")

const TABS := ["Ereignis", "Saison-Pass", "Wochenaufgaben", "Kalender", "Rangliste", "Neuigkeiten", "Endspiel"]
const TAB_ICONS := ["ui_event", "ui_season", "ui_quest", "ui_calendar", "ui_trophy", "ui_news", "ui_prestige"]
const PAGE := 8

var S


func setup(_arg) -> void:
	LO.net_refresh()


func build() -> Control:
	var v := UI.vbox(12)
	# ---- Kopf: Saison, Zeitschub, Garderobe
	var sd := LO.season_def()
	var sl := UI.label("", 22, UI.TEXT, false)
	S.live(sl, func() -> String: return "noch " + UI.time_text(LO.season_left()))
	var head := UI.hbox(12, [UI.pic(String(sd.icon), 54.0, "ui_season"), UI.vbox(-4, [UI.label("Saison %d „%s“" % [LO.season_n(), String(sd.name)], 30, (sd.col as Color).lightened(0.3)), sl])])
	head.add_child(UI.spacer(true))
	var bst := UI.button("Zeitschub (%d)" % int(LO.st().boost), S.act(func():
		var why := LO.use_boost()
		if why == "":
			S.toast("Zeitschub: alle laufenden Bauten 30 Minuten weiter!")
		else:
			S.say(why)), "dark", 22, "ui_boost")
	bst.tooltip_text = "Komfort aus Pass, Ereignissen und Kalender: alle laufenden Bauten 30 Minuten weiter"
	bst.custom_minimum_size = Vector2(0, 62)
	head.add_child(bst)
	var gb := UI.button("Garderobe", func(): S.open("garderobe"), "gold", 24, "ui_wardrobe")
	gb.custom_minimum_size = Vector2(0, 62)
	head.add_child(gb)
	v.add_child(head)
	var names: Array = TABS.duplicate()
	if LO.event_claimable() > 0:
		names[0] = "Ereignis (%d)" % LO.event_claimable()
	if LO.pass_open() > 0:
		names[1] = "Saison-Pass (%d)" % LO.pass_open()
	if LO.news_unread() > 0:
		names[5] = "Neuigkeiten (%d)" % LO.news_unread()
	v.add_child(S.tabs(names, "tab", 22, TAB_ICONS))
	var body: Control
	match clampi(int(S.st.get("tab", 0)), 0, TABS.size() - 1):
		0:
			body = _event()
		1:
			body = _pass()
		2:
			body = _weekly()
		3:
			body = _calendar()
		4:
			body = _board()
		5:
			body = _news()
		_:
			body = _endgame()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	return v


# ================================================================= Hilfen
func _reward_pic(b: Dictionary, size := 56.0) -> Control:
	if b.has("cos"):
		return UI.pic(LO.cos_icon(String(b.cos)), size, "ui_star")
	if b.has("chest"):
		return UI.chest_pic(String(b.chest), size)
	if b.has("boost"):
		return UI.pic("ui_boost", size, "ui_clock")
	if b.has("gems"):
		return UI.pic("res_gems", size)
	for k in b:
		return UI.icon(String(k), size)
	return UI.pic("ui_star", size)


func _claim_btn(text: String, can: bool, done: bool, cb: Callable, size := 20) -> Button:
	var b: Button
	if done:
		b = UI.button("Abgeholt", Callable(), "dark", size, "ui_check")
		UI.disable(b)
	else:
		b = UI.button(text, S.act(cb), "green" if can else "dark", size, "ui_chest" if can else "ui_lock")
		UI.disable(b, not can)
	b.custom_minimum_size = Vector2(0, 56)
	return b


# ================================================================= Ereignis
func _event() -> Control:
	var row := UI.hbox(20)
	var def := LO.event_def()
	var k := LO.event_key()
	var left := UI.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col: Color = def.col
	left.add_child(UI.hbox(14, [UI.pic(String(def.icon), 84.0, "ui_event"), UI.vbox(0, [UI.label(String(def.name), 40, col.lightened(0.3)), UI.label("Wochen-Ereignis", 20, UI.TEXT, false)])]))
	left.add_child(UI.text(String(def.text), 23, UI.WHITE, 560))
	left.add_child(UI.pill(UI.hbox(8, [UI.pic("ui_star", 30.0), UI.label(String(def.effect), 21, UI.GOLD)])))
	var tl := UI.label("", 24, UI.GOLD)
	S.live(tl, func() -> String: return "Endet in " + UI.time_text(LO.week_left()))
	left.add_child(tl)
	if bool(def.get("community", false)):
		left.add_child(_boss_box())
	else:
		var pts: Dictionary = def.points
		var src: Array = []
		var names := {"kills": "je besiegtem Gegner", "flood_win": "je gewonnener Flut", "expeditions": "je Expedition", "elite_kill": "je Elite-Gegner",
			"practice": "je Übungsalarm", "coins": "je gesammelter Münze", "builds": "je Bau oder Verbesserung", "caravan": "je Karawanen-Kauf"}
		for pk in pts:
			if int(pts[pk]) > 0:
				src.append("%d %s" % [int(pts[pk]), String(names.get(pk, pk))])
		left.add_child(UI.card(UI.vbox(4, [UI.label("Deine Ereignispunkte: %s" % UI.fmt(LO.event_points()), 26, UI.GOLD), S.hint("Punkte: " + ", ".join(src), 19)]), UI.NAVY_L, 12))
	var nxt := LO.event_of_week(LO.week_index() + 1)
	left.add_child(S.hint("Nächste Woche: %s – %s" % [String(DL.EVENTS[nxt].name), String(DL.EVENTS[nxt].effect)], 19))
	var srv: Dictionary = LO.st().srv
	left.add_child(S.hint("Zeitplan vom Server." if int(srv.get("week", -1)) == LO.week_index() and String(srv.get("event", "")) != "" else "Ohne Server gilt der feste Ereigniskalender.", 17))
	var hk := LO.holiday()
	if hk != "":
		var hd: Dictionary = DL.HOLIDAYS[hk]
		var goal: Array = LO.HOLIDAY_GOAL[hk]
		var gtxt := String(goal[2]) % int(goal[1])
		left.add_child(UI.card(UI.hbox(12, [UI.pic(String(hd.icon), 64.0, "ui_star"), UI.vbox(2, [UI.label("Feiertag: %s" % String(hd.name), 26, UI.GOLD), UI.text(String(hd.text), 20, UI.WHITE, 440),
			UI.label("%s: %d/%d → %s" % [gtxt, mini(LO.holiday_goal_progress(hk), int(goal[1])), int(goal[1]), LO.cos_name(String(hd.gift2))], 19, UI.TEXT, false)])]), Color("3A2A5E"), 12, UI.GOLD))
	row.add_child(UI.panel(S.scroll(left, "ev_left"), UI.NAVY, col.darkened(0.2), 24, 20))
	# ---- Belohnungsstufen
	var right := UI.vbox(10, [S.head("Belohnungsstufen", 28)])
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in def.tiers.size():
		var rw: Dictionary = DL.EVENT_REWARDS[k][i]
		var ratio := LO.event_tier_ratio(i)
		var done: bool = i in LO.ev_state().claimed or float(i) in LO.ev_state().claimed
		var need := ("%d %% Gemeinschaft" % int(def.tiers[i])) if bool(def.get("community", false)) else ("%s Punkte" % UI.fmt(float(def.tiers[i])))
		var bar := UI.bar(ratio, UI.GREEN if ratio >= 1.0 else D.C_BAR_BLUE, Vector2(160, 20))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var info := UI.vbox(4, [UI.label("Stufe %d · %s" % [i + 1, need], 22, UI.GOLD), UI.text(LO.bundle_text(rw), 19, UI.WHITE, 300), bar])
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx: int = i
		var cb := _claim_btn("Abholen", LO.event_tier_ready(i), done, func():
			var why := LO.event_claim(idx)
			if why != "":
				S.say(why)
			else:
				UI.sfx("ui_claim", "chest", -2.0))
		right.add_child(UI.card(UI.hbox(12, [_reward_pic(rw, 60.0), info, cb]), Color("1F5A34") if done else UI.NAVY_L, 12, UI.GREEN if LO.event_tier_ready(i) else Color(0, 0, 0, 0)))
	if bool(def.get("community", false)):
		right.add_child(S.hint("Belohnungen gibt es für den Fortschritt aller Kommandanten – wenn du mindestens einmal angegriffen hast.", 18))
	var rp := UI.panel(S.scroll(right, "ev_right"), UI.NAVY, UI.EDGE, 24, 20)
	rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rp)
	return row


func _boss_box() -> Control:
	var b := LO.boss_state()
	var v := UI.vbox(6)
	var pr := LO.boss_progress()
	v.add_child(UI.hbox(10, [UI.enemy_pic(int(D.ENEMY_INDEX["boss_leviathan"]), 60.0), UI.vbox(0, [UI.label("Schleim-Leviathan", 26, UI.RED), UI.label("Gemeinschaft: %d %% besiegt" % int(pr * 100.0), 21, UI.GOLD)])]))
	var bar := UI.bar(pr, UI.RED, Vector2(300, 26))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(bar)
	v.add_child(UI.label("Dein Schaden diese Woche: %s · bester Angriff: %s" % [UI.fmt(float(b.dmg)), UI.fmt(float(b.best))], 20, UI.TEXT, false))
	var online: bool = P.social != null and P.social.online()
	v.add_child(S.hint("Gemeinschafts-Fortschritt vom Server." if online else "Ohne Server sind die anderen Kommandanten simuliert.", 17))
	var left := LO.boss_tries_left()
	var w = G.main.world if G.main != null else null
	var in_base: bool = w != null and w.get("mode") == "peace"
	var go := UI.button("Angreifen! (%d/%d heute)" % [left, DL.BOSS_TRIES], func():
		var why := LO.start_raid()
		if why == "":
			S.close()
		else:
			S.say(why), "red", 26, "ui_skull")
	go.custom_minimum_size = Vector2(0, 76)
	UI.disable(go, left <= 0 or not in_base)
	v.add_child(go)
	if not in_base:
		v.add_child(S.hint("Angreifen geht nur in deiner Basis.", 18, UI.ORANGE))
	v.add_child(S.hint("Ein Angriff dauert %d Sekunden. Der Leviathan ist für einen allein zu stark – zähle jeden Treffer!" % int(DL.BOSS_TIME), 18))
	return UI.card(v, Color("3A1C24"), 12, UI.RED)


# ================================================================= Saison-Pass
func _pass() -> Control:
	var v := UI.vbox(10)
	var sd := LO.season_def()
	var tier := LO.pass_tier()
	var pts := LO.season_points()
	var into := pts - tier * DL.PASS_POINTS
	var top := UI.hbox(16)
	var info := UI.vbox(4, [UI.label("Stufe %d von %d" % [tier, DL.PASS_TIERS], 32, UI.GOLD), UI.text(String(sd.text), 19, UI.TEXT, 620)])
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar := UI.bar(1.0 if tier >= DL.PASS_TIERS else float(into) / DL.PASS_POINTS, D.C_BAR_BLUE, Vector2(300, 24))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UI.hbox(10, [bar, UI.label("%s / %s Punkte" % [UI.fmt(float(mini(into, DL.PASS_POINTS) if tier < DL.PASS_TIERS else DL.PASS_POINTS)), UI.fmt(float(DL.PASS_POINTS))], 19, UI.TEXT, false)]))
	top.add_child(info)
	var Store = load("res://src/store.gd")
	if LO.pass_paid():
		top.add_child(UI.badge("Pass-Spur aktiv", Color("2F8D4E"), 22))
	else:
		var buy := UI.button("Pass-Spur %s" % ("Testkauf" if Store.test_mode() else DL.PASS_PRICE), func():
			S.confirm(LO.pass_confirm_text(), func():
				var why := LO.buy_pass()
				if why == "":
					UI.sfx("ui_buy", "upgrade", -2.0)
					S.refresh()
				else:
					S.say(why), "Freischalten"), "gold", 24, "ui_season")
		buy.custom_minimum_size = Vector2(0, 70)
		top.add_child(buy)
	var n := LO.pass_open()
	var all := UI.button("Alles abholen (%d)" % n, S.act(func():
		var got := LO.pass_claim_all()
		if got > 0:
			UI.sfx("ui_claim", "chest", -2.0)
			S.toast("%d Belohnungen abgeholt" % got)), "green", 24, "ui_chest")
	all.custom_minimum_size = Vector2(0, 70)
	UI.disable(all, n <= 0)
	top.add_child(all)
	v.add_child(UI.panel(top, UI.NAVY, UI.EDGE, 20, 14))
	# Seiten zu je 8 Stufen
	if not S.st.has("page"):
		S.st["page"] = clampi(int(maxi(tier, 1) - 1) / PAGE, 0, DL.PASS_TIERS / PAGE - 1)
	var pg := clampi(int(S.st.page), 0, DL.PASS_TIERS / PAGE - 1)
	var pages := UI.hbox(8, [UI.label("Stufen:", 20, UI.TEXT, false)])
	for i in DL.PASS_TIERS / PAGE:
		var pi: int = i
		var pb: Button = S.choice("%d–%d" % [i * PAGE + 1, i * PAGE + PAGE], i == pg, S.set_st("page", pi), 19)
		pb.custom_minimum_size = Vector2(100, 50)
		pages.add_child(pb)
	pages.add_child(UI.spacer(true))
	pages.add_child(S.hint("Saisonpunkte: Flut %d · Expedition %d · Tagesauftrag %d · Wochenaufgabe %d" % [int(DL.SP.flood_win), int(DL.SP.expeditions), int(DL.SP.daily), int(DL.SP.weekly)], 17))
	v.add_child(pages)
	var g := UI.grid(PAGE + 1, 8)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(UI.label("", 18))
	for t in range(pg * PAGE + 1, pg * PAGE + PAGE + 1):
		var l := UI.label("Stufe %d" % t, 20, UI.GOLD if t <= tier else UI.GREY)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(l)
	for track in ["free", "paid"]:
		var tl := UI.vbox(2, [UI.pic("ui_season" if track == "paid" else "ui_star", 44.0), UI.label("Pass" if track == "paid" else "Gratis", 19, UI.GOLD if track == "paid" else UI.TEXT)])
		g.add_child(tl)
		for t in range(pg * PAGE + 1, pg * PAGE + PAGE + 1):
			g.add_child(_pass_cell(track, t, tier))
	v.add_child(S.scroll(g, "pass_grid"))
	v.add_child(S.hint("Der Pass bringt nur Aussehen und Komfort. Am Saison-Ende gibt es Juwelen nach Rang (Rangliste).", 18))
	return v


func _pass_cell(track: String, t: int, tier: int) -> Control:
	var rw := LO.pass_reward(track, t)
	var got := LO.pass_got(track, t)
	var can := LO.pass_can(track, t)
	var locked := track == "paid" and not LO.pass_paid()
	var pic := _reward_pic(rw, 64.0)
	if locked or t > tier:
		pic.modulate = Color(0.6, 0.65, 0.75)
	var txt := UI.text(LO.bundle_text(rw), 16, UI.WHITE, 150)
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hold := CenterContainer.new()
	hold.add_child(pic)
	var inner := UI.vbox(4, [hold, txt])
	if got:
		inner.add_child(UI.label("✓", 22, UI.GREEN))
	elif can:
		var tr := track
		var b := UI.button("Holen", S.act(func():
			if LO.pass_claim(tr, t) == "":
				UI.sfx("ui_claim", "chest", -4.0)), "green", 18)
		b.custom_minimum_size = Vector2(0, 46)
		inner.add_child(b)
	elif locked:
		inner.add_child(UI.icon("lock", 26.0, UI.GOLD))
	var bg := Color("2A3E66") if track == "paid" else UI.NAVY_L
	if got:
		bg = Color("1F5A34")
	var c := UI.card(inner, bg, 8, UI.GOLD if can else (Color("8C5DF2") if rw.has("cos") else Color(0, 0, 0, 0)))
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size = Vector2(150, 190)
	return c


# ================================================================= Wochenaufgaben
func _weekly() -> Control:
	var wk := LO.weekly()
	var v := UI.vbox(10, [UI.hbox(14, [UI.pic("ui_quest", 52.0), S.head("Wochenaufgaben – %d von %d erfüllt" % [LO.weekly_done(), wk.list.size()], 32)])])
	for q in wk.list:
		var prog := int(q.progress)
		var amt := int(q.amount)
		var done := bool(q.done)
		var bar := UI.bar(float(prog) / maxf(1.0, amt), UI.GREEN if done else D.C_BAR_BLUE, Vector2(200, 24))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var qb := UI.vbox(6, [UI.text(String(q.text), 23, UI.WHITE), UI.hbox(12, [bar, UI.label("Erledigt" if done else "%s / %s" % [UI.fmt(prog), UI.fmt(amt)], 20, UI.GREEN if done else UI.GOLD)])])
		qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UI.card(UI.hbox(14, [UI.pic("ui_check" if done else "ui_target", 50.0, "", UI.GREEN if done else UI.WHITE), qb, UI.vbox(0, [UI.label(LO.bundle_text(DL.WEEKLY_REWARD), 18, UI.TEXT, false), UI.label("+%d Saisonpunkte" % int(DL.SP.weekly), 18, UI.SKY, false)])]),
			Color("1F5A34") if done else UI.NAVY_L, 12, UI.GREEN if done else Color(0, 0, 0, 0)))
	var all_done := bool(wk.get("bonus", false))
	v.add_child(UI.card(UI.hbox(14, [UI.chest_pic(String(DL.WEEKLY_ALL_REWARD.chest), 70.0), UI.vbox(2, [UI.label("Alle fünf erfüllt" + (" ✓" if all_done else ""), 24, UI.GREEN if all_done else UI.GOLD), UI.text(LO.bundle_text(DL.WEEKLY_ALL_REWARD) + " · +%d Saisonpunkte" % int(DL.SP.weekly_all), 19, UI.WHITE, 600)])]), UI.NAVY_L, 12, UI.GOLD))
	var tl := UI.label("", 20, UI.GREY, false)
	S.live(tl, func() -> String: return "Neue Wochenaufgaben in: " + UI.time_text(LO.week_left()))
	v.add_child(tl)
	var qb2 := UI.button("Tagesaufträge ansehen", func(): S.open("quests"), "dark", 22, "ui_quest")
	qb2.custom_minimum_size = Vector2(0, 60)
	qb2.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(qb2)
	return UI.panel(S.scroll(v, "weekly"), UI.NAVY, UI.EDGE, 24, 20)


# ================================================================= Login-Kalender
func _calendar() -> Control:
	var v := UI.vbox(10)
	var done := LO.cal_done()
	var nxt := LO.cal_next()
	v.add_child(UI.hbox(14, [UI.pic("ui_calendar", 52.0), S.head("Login-Kalender – Tag %d von %d" % [done, DL.CALENDAR.size()], 32), UI.spacer(true),
		S.hint("Jeden Tag liegt das Geschenk als Blase am Bunker. Höhepunkte an Tag 7, 14, 21 und 28.", 19)]))
	var g := UI.grid(7, 8)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in DL.CALENDAR.size():
		var day := i + 1
		var r: Dictionary = DL.CALENDAR[i]
		var hl: bool = day in DL.CAL_HIGHLIGHT
		var got := day <= done
		var is_next := day == nxt and not got
		var pic := _reward_pic(r, 54.0 if not hl else 66.0)
		if got:
			pic.modulate = Color(0.55, 0.6, 0.7)
		var hold := CenterContainer.new()
		hold.add_child(pic)
		var t := UI.text(LO.bundle_text(r), 15, UI.WHITE, 120)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var head := UI.label(("Tag %d ✓" % day) if got else "Tag %d" % day, 19, UI.GREEN if got else (UI.GOLD if hl else UI.TEXT))
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var c := UI.card(UI.vbox(2, [head, hold, t]), Color("4A3A1C") if hl else (Color("1F5A34") if got else UI.NAVY_L), 8, UI.GOLD if (hl or is_next) else Color(0, 0, 0, 0))
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.custom_minimum_size = Vector2(130, 150)
		g.add_child(c)
	v.add_child(S.scroll(g, "cal"))
	var tl := UI.label("", 20, UI.GREY, false)
	S.live(tl, func() -> String: return "Nächster Tag (%d) in: %s" % [LO.cal_next(), UI.time_text(P.seconds_to_next_day())])
	v.add_child(tl)
	return v


# ================================================================= Rangliste
func _board() -> Control:
	var row := UI.hbox(20)
	var list := UI.vbox(4)
	var b := LO.board()
	var rank := LO.season_rank()
	for i in mini(b.size(), DL.BOARD_SIZE):
		var e: Dictionary = b[i]
		var me := bool(e.me)
		var r := UI.hbox(12, [UI.label("%d." % (i + 1), 22, UI.GOLD if i < 3 else UI.TEXT), UI.label(String(e.name), 22, UI.WHITE if not me else UI.GOLD)])
		r.get_child(0).custom_minimum_size = Vector2(60, 0)
		r.add_child(UI.spacer(true))
		r.add_child(UI.label(UI.fmt(float(e.score)), 22, UI.SKY))
		list.add_child(UI.card(r, Color("4A3A1C") if me else UI.NAVY_L, 6, UI.GOLD if me else Color(0, 0, 0, 0)))
	var lp := UI.panel(UI.vbox(8, [S.head("Saison-Rangliste", 28), S.scroll(list, "board")]), UI.NAVY, UI.EDGE, 24, 18)
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lp.size_flags_stretch_ratio = 1.4
	row.add_child(lp)
	var right := UI.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(UI.label("Dein Platz: %d von %d" % [rank, b.size()], 32, UI.GOLD))
	right.add_child(UI.label("%s Saisonpunkte" % UI.fmt(float(LO.season_points())), 24, UI.SKY))
	var online: bool = P.social != null and P.social.online() and int(LO.st().srv_board.get("season", -1)) == LO.season_n()
	right.add_child(S.hint("Rangliste vom Server." if online else "Ohne Server sind die Mitspieler simuliert.", 18))
	var rw := UI.vbox(4, [UI.label("Belohnung am Saison-Ende", 24)])
	var lo_rank := 1
	for r in DL.SEASON_RANK_REWARDS:
		var txt := "Platz %d" % int(r[0]) if int(r[0]) == lo_rank else "Platz %d–%d" % [lo_rank, int(r[0])]
		var cur: bool = rank >= lo_rank and rank <= int(r[0])
		rw.add_child(UI.stat_row("res_gems", txt, "%d" % int(r[1]), 21, UI.GOLD if cur else UI.TEXT))
		if String(r[2]) != "":
			rw.add_child(S.hint("   Titel „%s“" % String(r[2]), 17))
		lo_rank = int(r[0]) + 1
	right.add_child(UI.card(rw, UI.NAVY_L, 12))
	var titles: Array = LO.st().titles
	if not titles.is_empty():
		right.add_child(UI.card(UI.vbox(4, [UI.label("Deine Titel", 22, UI.GOLD), UI.text(", ".join(titles), 20, UI.WHITE, 400)]), UI.NAVY_L, 12))
	var rpn := UI.panel(right, UI.NAVY, UI.EDGE, 24, 18)
	rpn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rpn)
	return row


# ================================================================= Neuigkeiten
func _news() -> Control:
	var v := UI.vbox(10)
	var unread := LO.news_unread()
	var nw: Array = LO.news()
	for i in nw.size():
		var n: Dictionary = nw[i]
		var fresh := i < unread
		var title := UI.label(String(n.get("title", "")), 26, UI.GOLD)
		var hr := UI.hbox(10, [title])
		if fresh:
			hr.add_child(UI.new_tag(18))
		hr.add_child(UI.spacer(true))
		hr.add_child(UI.label(String(n.get("date", "")), 18, UI.GREY, false))
		var txt := UI.text(String(n.get("text", "")), 21, UI.WHITE, 900)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var c := UI.card(UI.hbox(14, [UI.pic("ui_news", 52.0, "ui_info"), UI.vbox(4, [hr, txt])]), UI.NAVY_L, 14, UI.GOLD if fresh else Color(0, 0, 0, 0))
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(c)
	var online: bool = P.social != null and P.social.online() and LO.st().srv.get("news") is Array
	v.add_child(S.hint("Nachrichten vom Server." if online else "Eingebaute Nachrichten – mit Server kommen neue automatisch.", 18))
	LO.news_read()
	return UI.panel(S.scroll(v, "news"), UI.NAVY, UI.EDGE, 24, 20)


# ================================================================= Endspiel
func _endgame() -> Control:
	var row := UI.hbox(20)
	# ---- Prestige
	var pv := UI.vbox(8, [UI.hbox(12, [UI.pic("ui_prestige", 52.0), S.head("Prestige", 30)]),
		S.hint("Ab Heldenstufe %d wird Erfahrung zu Prestige-Sternen: je Stern +%s %% Schaden und Leben (höchstens %d Sterne), alle 5 Sterne %d Juwelen." % [D.HERO_MAX_LEVEL, str(DL.PRESTIGE_DMG * 100.0).replace(".", ","), DL.PRESTIGE_MAX, DL.PRESTIGE_GEMS], 18)])
	for hk in D.HERO_ORDER:
		if not P.hero_unlocked(hk):
			continue
		var lv := int(P.hero(hk).level)
		var stars := LO.stars(hk)
		var r := UI.hbox(10, [UI.hero_pic(hk, 54.0), UI.vbox(0, [UI.label(String(D.HEROES[hk].name), 21), UI.label("Stufe %d" % lv, 18, UI.TEXT, false)])])
		r.get_child(1).custom_minimum_size = Vector2(170, 0)
		if lv >= D.HERO_MAX_LEVEL:
			var bar := UI.bar(LO.prestige_xp_now(hk) / DL.PRESTIGE_XP, UI.GOLD, Vector2(150, 18))
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(UI.vbox(2, [UI.label("★ %d" % stars, 22, UI.GOLD), bar]))
			r.get_child(2).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(UI.label("+%s %%" % str(stars * DL.PRESTIGE_DMG * 100.0).replace(".", ","), 20, UI.GREEN))
		else:
			r.add_child(UI.label("ab Stufe %d" % D.HERO_MAX_LEVEL, 19, UI.GREY, false))
		pv.add_child(UI.card(r, UI.NAVY_L, 8))
	var pp := UI.panel(S.scroll(pv, "prestige"), UI.NAVY, UI.EDGE, 22, 16)
	pp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pp)
	# ---- Albtraum+ und Außenbasen
	var nv := UI.vbox(8, [UI.hbox(12, [UI.pic("ui_nightmare", 52.0, "ui_skull"), S.head("Albtraum+", 30)]),
		S.hint("Auf der Schwierigkeit Albtraum (nach dem Albtraum-Boss eines Gebiets) kannst du Modifikatoren zuschalten. Jeder bringt mehr Beute und bei Erfolg %d Sternsplitter." % DL.NM_SHARDS, 18)])
	var mods: Array = LO.nm_mods()
	for k in DL.NIGHTMARE_ORDER:
		var md: Dictionary = DL.NIGHTMARE_MODS[k]
		var key := String(k)
		var on: bool = key in mods
		var b: Button = S.choice("%s  (+%d %% Beute)" % [String(md.name), int(float(md.loot) * 100.0)], on, S.act(func(): LO.nm_toggle(key)), 20, String(md.icon))
		b.custom_minimum_size = Vector2(0, 56)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nv.add_child(UI.hbox(10, [b, S.hint(String(md.text), 18)]))
	nv.add_child(UI.label(("Beute ×%.2f · Albtraum+-Siege: %d" % [LO.nm_loot(mods), int(LO.st().nm_wins)]).replace(".", ","), 22, UI.GOLD))
	nv.add_child(UI.sep(false))
	nv.add_child(UI.hbox(12, [UI.pic("ui_flag", 44.0), S.head("Außenbasen Stufe 4 und 5", 26)]))
	nv.add_child(S.hint("Sind alle Bauplätze der nächsten Stufe bezahlt, erscheint der Gebietsboss an der Außenbasis (Stufe 4: Leben ×%s, Stufe 5: ×%s). Erst nach dem Sieg steigt die Stufe." % [str(DL.OUTPOST_CHALLENGE[4].hp).replace(".", ","), str(DL.OUTPOST_CHALLENGE[5].hp).replace(".", ",")], 18))
	var fl := UI.flow(8)
	for a in D.AREAS:
		var ak := String(a.key)
		var won := int(LO.st().op_ch.get(ak, 0))
		var lv := P.outpost_level(ak)
		var t := "%s: Stufe %d%s" % [String(a.name), lv, " · Boss ✓%d" % won if won >= 4 else ""]
		fl.add_child(UI.pill(UI.label(t, 18, UI.GOLD if won >= 4 else UI.TEXT)))
	nv.add_child(fl)
	var np := UI.panel(S.scroll(nv, "nightmare"), UI.NAVY, Color("8C5DF2"), 22, 16)
	np.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(np)
	return row
