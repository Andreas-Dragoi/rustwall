extends RefCounted
## Bildschirm "Funkturm": Freunde, Post, Ranglisten. Mitspieler sind simuliert (siehe social.gd).

const D = preload("res://src/data.gd")
const UI = preload("res://src/ui.gd")

const TABS := ["Freunde", "Post", "Ranglisten"]
const TAB_KEYS := ["friends", "mail", "boards"]
const TAB_ICONS := ["ui_friends", "ui_mail", "ui_trophy"]
const BOARD_ICONS := ["ui_flood", "ui_map", "ui_friends", "ui_clan"]
const BOARDS := [["flood", "Flut"], ["explorer", "Entdecker"], ["friends", "Freunde"], ["clans", "Clans"]]

var S
var _code_edit: LineEdit


func setup(arg) -> void:
	if not S.st.has("tab"):
		S.st["tab"] = 0
	if arg is String and TAB_KEYS.has(arg):
		S.st["tab"] = TAB_KEYS.find(arg)
	if not S.st.has("board"):
		S.st["board"] = 0


func build() -> Control:
	var v := UI.vbox(10)
	var names: Array = TABS.duplicate()
	var mc: int = P.social.mail_count()
	if mc > 0:
		names[1] = "Post (%d)" % mc
	v.add_child(S.tabs(names, "tab", 24, TAB_ICONS))
	v.add_child(S.notice_sim())
	match int(S.st.tab):
		0:
			_friends(v)
		1:
			_mail(v)
		2:
			_boards(v)
	return v


# ----------------------------------------------------------------- Freunde
func _friends(c: VBoxContainer) -> void:
	var soc = P.social
	var head := UI.hbox(12)
	head.add_child(UI.pic("ui_friends", 48.0))
	head.add_child(UI.vbox(2, [UI.label("Dein Bunker: %s" % P.bunker_name(), 25, UI.GOLD), UI.label("Andere finden dich über diesen Namen oder den Code", 18, UI.GREY, false)]))
	head.add_child(UI.badge(String(soc.friend_code()), Color("24508F"), 30))
	head.add_child(UI.spacer(true))
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "Bunkername oder Code"
	_code_edit.max_length = 20
	_code_edit.custom_minimum_size = Vector2(280, 70)
	_code_edit.text = String(S.st.get("code_text", ""))
	_code_edit.text_changed.connect(func(t: String): S.st["code_text"] = t)
	_code_edit.text_submitted.connect(func(_t: String): _add_friend(_code_edit.text))
	head.add_child(_code_edit)
	var ab := UI.button("Suchen", func(): _add_friend(_code_edit.text), "green", 25, "ui_friends")
	ab.custom_minimum_size = Vector2(0, 72)
	head.add_child(ab)
	c.add_child(head)
	var info := UI.hbox(12)
	info.add_child(UI.pill(UI.hbox(8, [UI.pic("ui_crate", 30.0), UI.label("Sendungen übrig: %d/%d" % [int(soc.sends_left()), D.SEND_PER_DAY], 21, UI.GOLD)])))
	info.add_child(UI.pill(UI.hbox(8, [UI.pic("ui_hammer", 30.0), UI.label("Hilfen übrig: %d/5" % int(soc.helps_left()), 21, UI.GOLD)])))
	info.add_child(UI.pill(UI.hbox(8, [UI.chest_pic("gift", 30.0), UI.label("Geschenkkiste diese Woche: %s" % ("frei" if soc.can_send_giftbox() else "verschickt"), 21, UI.GOLD)])))
	c.add_child(info)

	var cols := UI.hbox(14)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Freundesliste
	var fl := UI.vbox(8)
	var friends: Array = soc.s.friends
	if friends.is_empty():
		fl.add_child(S.hint("Noch keine Freunde. Gib einen Freundescode ein oder nimm einen Vorschlag an."))
	for f in friends:
		fl.add_child(_friend_card(f))
	var left := UI.vbox(6, [S.head("Freunde (%d/100)" % friends.size(), 25), S.scroll(fl, "friends")])
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.9
	cols.add_child(left)
	# Vorschläge bzw. Suchergebnisse
	var sg := UI.vbox(8)
	var q := String(S.st.get("code_text", "")).strip_edges()
	var found: Array = soc.find_bases(q) if q.length() >= 2 else []
	var list: Array = found if q.length() >= 2 else soc.suggestions()
	if q.length() >= 2 and found.is_empty():
		sg.add_child(S.hint("Kein Bunker mit „%s“ gefunden." % q))
	for e in list:
		if bool(e.get("own", false)):
			sg.add_child(UI.card(UI.hbox(12, [UI.pic("b_bunker_1", 64.0), UI.vbox(0, [UI.label(String(e.bunker_name), 22, UI.GOLD), UI.label("Das ist deine Stadt", 18, UI.GREY, false)])]), UI.NAVY_L, 10))
			continue
		var code := String(e.code)
		var t := UI.vbox(0, [UI.label(String(e.get("bunker_name", e.name)), 22), UI.label("%s · Stufe %d" % [String(e.name), int(e.level)], 18, UI.GREY, false)])
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var b := UI.button("+", func(): _add_friend(code), "green", 32)
		b.custom_minimum_size = Vector2(78, 70)
		sg.add_child(UI.card(UI.hbox(12, [UI.hero_pic("settler", 64.0), t, b]), UI.NAVY_L, 10))
	if sg.get_child_count() == 0:
		sg.add_child(S.hint("Gerade gibt es keine neuen Vorschläge. Schau morgen wieder vorbei."))
	var right := UI.vbox(6, [S.head("Suchergebnisse" if q.length() >= 2 else "Vorschläge", 25), S.scroll(sg, "suggest")])
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	cols.add_child(right)
	c.add_child(cols)


func _add_friend(code: String) -> void:
	code = code.strip_edges()
	if code.length() != 8 or code.contains(" "):         # kein Code: nach Bunkernamen suchen
		var hits: Array = P.social.find_bases(code)
		if hits.size() == 1 and not bool(hits[0].get("own", false)):
			code = String(hits[0].code)
		else:
			S.refresh()
			return
	var why: String = P.social.add_friend(code)
	if S.say(why, "Freund hinzugefügt!"):
		S.st["code_text"] = ""
		UI.sfx("ui_claim", "pay", -6.0)
	S.refresh()


func _friend_card(f: Dictionary) -> Control:
	var soc = P.social
	var code := String(f.code)
	var fname := String(f.name)
	var days: int = P.day_index() - int(f.since)
	var title := UI.hbox(12, [UI.label(String(f.get("bunker_name", fname)), 26)])
	if f.has("bunker_name"):
		title.add_child(UI.label(fname, 19, UI.SKY, false))
	title.add_child(UI.label("Stufe %d · Bunker %d · %s" % [int(f.level), int(f.bunker), "seit heute" if days <= 0 else "seit %d Tagen" % days], 19, UI.GREY, false))
	var box := UI.vbox(8, [title])
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btns := UI.hbox(8)
	var open := String(S.st.get("send_to", "")) == code
	var sb := UI.button("Senden", S.set_st("send_to", "" if open else code), "gold" if open else "", 21)
	sb.disabled = int(soc.sends_left()) <= 0
	var gb := UI.button("Geschenk", S.act(func():
		if soc.send_giftbox(fname):
			UI.sfx("ui_buy", "pay", -6.0)
			S.toast("Geschenkkiste an %s verschickt." % fname)
		else:
			S.say("Diese Woche wurde schon eine Geschenkkiste verschickt.")), "purple", 21)
	gb.disabled = not soc.can_send_giftbox()
	var hb := UI.button("Helfen", S.act(func():
		if soc.help_friend(f):
			S.toast("Du hilfst %s beim Bauen. +15 Münzen" % fname)
		else:
			S.say("Heute hast du schon fünfmal geholfen.")), "green", 21)
	hb.disabled = int(soc.helps_left()) <= 0
	var rb := UI.button("Entfernen", func():
		S.confirm("%s aus der Freundesliste entfernen?" % fname, func(): soc.remove_friend(code), "Entfernen"), "dark", 21)
	var all_b: Array = [sb, gb, hb, rb]
	if soc.online():                    # Paket O: echte Mitspieler melden und sperren
		var mb := UI.button("Melden", func():
			S.confirm("%s melden (z. B. anstößiger Name) und sperren? Ihr seid dann nicht mehr befreundet." % fname, func(): soc.report(code, "Name", true), "Melden"), "dark", 21)
		mb.set_meta("danger", true)
		all_b.append(mb)
		if bool(f.get("online", false)):
			title.add_child(UI.label("● online", 19, UI.GREEN, false))
	for b in all_b:
		b.custom_minimum_size = Vector2(0, 64)
		btns.add_child(b)
	box.add_child(btns)
	if open:
		var sr := HFlowContainer.new()
		sr.add_theme_constant_override("h_separation", 8)
		sr.add_theme_constant_override("v_separation", 8)
		for r in D.SENDABLE:
			var amt: int = soc.send_amount(r)
			var rb2: Button = S.card_button(false, S.act(func():
				if S.say(soc.send_resource(fname, r), "%d %s an %s geschickt." % [amt, String(D.RES_NAME[r]), fname]):
					UI.sfx("ui_buy", "pay", -6.0)), UI.res_chip(r, amt, 22), 70.0, "")
			rb2.custom_minimum_size = Vector2(170, 70)
			rb2.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			UI.disable(rb2, amt <= 0)
			sr.add_child(rb2)
		box.add_child(S.hint("Eine Sendung sind 5 % deines Vorrats:", 18))
		box.add_child(sr)
	var face := UI.hero_pic("settler", 96.0)
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return UI.card(UI.hbox(14, [face, box]), UI.NAVY_L, 12)


# ----------------------------------------------------------------- Post
func _mail(c: VBoxContainer) -> void:
	var soc = P.social
	var mails: Array = soc.s.mail
	var head := UI.hbox(12, [UI.pic("ui_mail", 48.0), S.head("Post (%d)" % mails.size(), 30)])
	head.add_child(UI.spacer(true))
	var all := UI.button("Alle abholen", S.act(func():
		var n: int = soc.mail_claim_all()
		UI.sfx("ui_claim", "pay", -4.0)
		S.toast("%d Sendungen abgeholt." % n)), "green", 25, "ui_check")
	all.custom_minimum_size = Vector2(0, 72)
	UI.disable(all, mails.is_empty())
	head.add_child(all)
	c.add_child(head)
	var list := UI.vbox(8)
	if mails.is_empty():
		list.add_child(S.hint("Keine Post. Freunde und dein Clan schicken dir hier Rohstoffe und Kisten.", 23))
	for i in range(mails.size() - 1, -1, -1):
		var m: Dictionary = mails[i]
		var id := int(m.id)
		var t := UI.vbox(2, [UI.label(String(m.from), 23, UI.GOLD), UI.text(String(m.text), 21)])
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mic: Control = UI.chest_pic(String(m.chest), 68.0) if String(m.chest) != "" else UI.pic("ui_mail", 68.0)
		var row := UI.hbox(14, [mic, t])
		var res: Dictionary = m.res
		if not res.is_empty():
			var cr := UI.cost_row(res, 22, false)
			cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(cr)
		if String(m.chest) != "" and D.CHESTS.has(String(m.chest)):
			var cb := UI.badge(String(D.CHESTS[String(m.chest)].name), Color("8A4FD6"), 19)
			cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(cb)
		var left_l := UI.label("noch %d T" % maxi(1, int(ceil((float(m.expire) - P.now()) / 86400.0))), 17, UI.GREY, false)
		left_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(left_l)
		var b := UI.button("Abholen", S.act(func():
			if soc.mail_claim(id):
				UI.sfx("ui_claim", "pay", -6.0)), "green", 24)
		b.custom_minimum_size = Vector2(170, 72)
		row.add_child(b)
		list.add_child(UI.card(row, UI.NAVY_L, 10))
	c.add_child(S.scroll(list, "mail"))


# ----------------------------------------------------------------- Ranglisten
func _boards(c: VBoxContainer) -> void:
	var soc = P.social
	var names: Array = []
	for b in BOARDS:
		names.append(b[1])
	var bi := clampi(int(S.st.board), 0, BOARDS.size() - 1)
	var kind := String(BOARDS[bi][0])
	var rows: Array = soc.board(kind)
	var head := UI.hbox(14)
	head.add_child(S.tabs(names, "board", 22, BOARD_ICONS))
	var has_me := false
	for e in rows:
		if e.me:
			has_me = true
	var info := UI.vbox(0)
	if kind == "flood" or kind == "explorer":
		info.add_child(UI.hbox(8, [UI.pic("ui_trophy", 36.0), UI.label("Liga: %s" % String(soc.league_name()), 25, UI.GOLD)]))
	if has_me:
		info.add_child(UI.label("Dein Platz: %d von %d" % [int(soc.my_rank(kind)), rows.size()], 22))
	elif kind == "clans":
		info.add_child(UI.label("Du bist in keinem Clan", 22, UI.GREY))
	head.add_child(info)
	c.add_child(head)
	var hint_text := ""
	match kind:
		"flood":
			hint_text = "Punkte aus der Wochenflut. Am Wochenende steigen die besten zehn auf, die letzten zehn ab. Alle bekommen Sternsplitter."
		"explorer":
			hint_text = "Punkte aus Expeditionen dieser Woche. Die besten 25 bekommen eine Fundkiste."
		"friends":
			hint_text = "Flut-Punkte von dir und deinen Freunden in dieser Woche."
		"clans":
			hint_text = "Wochenpunkte aller Clans."
	c.add_child(S.hint(hint_text, 20))
	var list := UI.vbox(4)
	var me_card: Control = null
	for i in rows.size():
		var e: Dictionary = rows[i]
		var me := bool(e.me)
		var rank := UI.label("%d." % (i + 1), 23, [UI.GOLD, Color("C9CED8"), Color("D08A4A")][i] if i < 3 else UI.WHITE)
		rank.custom_minimum_size = Vector2(64, 0)
		var nm := UI.label(String(e.name) + ("  (du)" if me and kind != "clans" else ("  (dein Clan)" if me else "")), 23, UI.GOLD if me else UI.WHITE)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		var row := UI.hbox(10, [rank, nm, UI.label(UI.fmt(float(e.score)), 24, UI.GOLD)])
		if i < 3:
			row.add_child(UI.pic("ui_trophy", 34.0))
			row.move_child(row.get_child(row.get_child_count() - 1), 1)
		var card := UI.card(row, Color("5A4A14") if me else UI.NAVY_L, 8, UI.GOLD if me else Color(0, 0, 0, 0))
		list.add_child(card)
		if me:
			me_card = card
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_right", 2)
	m.add_child(list)
	var sc: ScrollContainer = S.scroll(m, "board_" + kind)
	c.add_child(sc)
	# die eigene Zeile soll gleich zu sehen sein
	if me_card:
		sc.ready.connect(func():
			await sc.get_tree().process_frame
			await sc.get_tree().process_frame
			if is_instance_valid(sc) and is_instance_valid(me_card):
				sc.ensure_control_visible(me_card))
