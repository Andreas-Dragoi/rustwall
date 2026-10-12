extends RefCounted
## Bildschirm "Profil": Name, Stufe, Statistik, Freischaltungen und Kommandanten-Fähigkeiten.

const D = preload("res://src/data.gd")
const UI = preload("res://src/ui.gd")

const TABS := ["Profil", "Kommandant"]
const TAB_KEYS := ["profile", "commander"]
const TAB_ICONS := ["ui_badge", "ui_star"]
const STAT_ICONS := {"kills": "e_0", "expeditions": "ui_expedition", "floods_won": "ui_shield", "floods_lost": "ui_flood", "chests": "ui_chest"}
const STAT_NAMES := [["kills", "Besiegte Schleimlinge"], ["expeditions", "Expeditionen geschafft"], ["floods_won", "Fluten abgewehrt"], ["floods_lost", "Fluten verloren"], ["chests", "Kisten geöffnet"]]

var S
var _name_edit: LineEdit


func setup(arg) -> void:
	if not S.st.has("tab"):
		S.st["tab"] = 0
	if arg is String and TAB_KEYS.has(arg):
		S.st["tab"] = TAB_KEYS.find(arg)


func build() -> Control:
	var v := UI.vbox(12)
	v.add_child(S.tabs(TABS, "tab", 24, TAB_ICONS))
	if int(S.st.tab) == 0:
		_profile(v)
	else:
		_commander(v)
	return v


func _save_name() -> void:
	var n := _name_edit.text.strip_edges()
	if n.length() < 3:
		S.say("Der Name braucht mindestens 3 Zeichen.")
		return
	P.d.name = n
	P.mark()
	S.toast("Name gespeichert.")
	S.refresh()


func _profile(c: VBoxContainer) -> void:
	var lvl := int(P.d.level)
	var cols := UI.hbox(16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := UI.vbox(12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Name
	_name_edit = LineEdit.new()
	_name_edit.text = String(P.d.name) if String(P.d.name) != "Kommandant" else preload("res://src/i18n.gd").t("Kommandant")     # Paket S: Vorgabename in der Sprache
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(0, 70)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_submitted.connect(func(_t: String): _save_name())
	var sb := UI.button("Speichern", _save_name, "green", 24, "ui_check")
	sb.custom_minimum_size = Vector2(0, 72)
	left.add_child(UI.hbox(12, [UI.hero_pic(String(P.d.hero_sel), 84.0), UI.label("Name:", 26), _name_edit, sb]))
	# Monsterbuch (Paket 11)
	var open_n: int = P.bestiary_open_rewards()
	var mb := UI.button("Monsterbuch" + (" (%d)" % open_n if open_n > 0 else ""), func(): S.open("bestiary"), "green" if open_n > 0 else "gold", 26, "e_0")
	mb.custom_minimum_size = Vector2(0, 76)
	left.add_child(UI.hbox(12, [mb, UI.text("%d Gegnerarten entdeckt" % P.stat("bestiary"), 22, UI.SKY)]))
	# Stufe
	var xp_row := UI.hbox(12, [UI.pic("ui_badge", 52.0), UI.label("Stufe %d" % lvl, 38)])
	if lvl >= D.MAX_LEVEL:
		xp_row.add_child(UI.label("Meister-Rang erreicht", 24, UI.GREEN))
	else:
		var need: int = D.xp_need(lvl)
		var bar := UI.bar(float(P.d.xp) / maxf(1.0, need), D.C_BAR_BLUE, Vector2(240, 32))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		xp_row.add_child(bar)
		xp_row.add_child(UI.label("%d / %d" % [int(P.d.xp), need], 23, UI.GOLD))
	left.add_child(xp_row)
	left.add_child(S.hint("Jede Stufe bringt eine Stufenkiste, einen Kommandanten-Punkt und füllt die Lager um ein Viertel.", 20))
	# Statistik
	var sv := UI.vbox(6, [S.head("Statistik", 25)])
	var stats: Dictionary = P.d.stats
	for e in STAT_NAMES:
		var sl := UI.label("0", 26, UI.GOLD)
		UI.count_up(sl, float(stats.get(e[0], 0)), 0.8)
		var nl := UI.label(String(e[1]), 24)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sv.add_child(UI.hbox(14, [UI.pic(String(STAT_ICONS.get(e[0], "ui_star")), 38.0), nl, sl]))
	sv.add_child(UI.stat_row("b_bunker_%d" % clampi(1 + int((P.bunker_level() - 1) / 2), 1, 5), "Bunker-Stufe", str(P.bunker_level()), 24))
	sv.add_child(UI.stat_row("ui_clock", "Woche", str(int(P.d.week.number)), 24))
	var sc := UI.panel(sv, UI.NAVY, UI.EDGE, 22, 18)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sc)
	cols.add_child(left)
	# Freischaltungen
	var un := UI.vbox(6)
	var keys: Array = D.LEVEL_UNLOCKS.keys()
	keys.sort()
	for k in keys:
		var got := lvl >= int(k)
		var lv_l := UI.label("Stufe %d" % int(k), 22, UI.GREEN if got else UI.GOLD)
		lv_l.custom_minimum_size = Vector2(120, 0)
		var ic: Control = UI.pic("ui_check", 36.0, "", UI.GREEN) if got else UI.icon("lock", 34.0, UI.GOLD)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		un.add_child(UI.card(UI.hbox(10, [ic, lv_l, UI.text(String(D.LEVEL_UNLOCKS[k]), 22, UI.WHITE if got else UI.TEXT)]), UI.NAVY_L if got else UI.NAVY_D, 10))
	var right := UI.vbox(6, [S.head("Freischaltungen", 25), S.scroll(un, "unlocks")])
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	c.add_child(cols)


func _commander(c: VBoxContainer) -> void:
	var total: int = P.cmd_points_total()
	var spent: int = P.cmd_points_spent()
	var free := total - spent
	var top := UI.hbox(14)
	top.add_child(UI.icon("star", 44.0, UI.GOLD))
	top.add_child(UI.label("Freie Punkte: %d" % free, 30, UI.GOLD if free > 0 else UI.GREY))
	top.add_child(UI.label("(%d von %d verteilt)" % [spent, total], 20, UI.GREY, false))
	top.add_child(UI.spacer(true))
	var rb := UI.button("Zurücksetzen", func():
		S.confirm("Alle Kommandanten-Punkte zurückholen?", func(): P.cmd_reset(), "Zurücksetzen"), "dark", 22)
	rb.custom_minimum_size = Vector2(0, 70)
	UI.disable(rb, spent <= 0)
	top.add_child(rb)
	c.add_child(top)
	var body := UI.vbox(12)
	var cols := UI.hbox(10)
	for br in D.COMMANDER:
		var box := UI.vbox(6, [UI.label(String(br.name), 26, UI.GOLD)])
		for sk in br.skills:
			var key := String(sk.key)
			var rank: int = P.cmd_rank(key)
			var t := UI.vbox(0)
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var nm := UI.label(String(sk.name), 21)
			nm.clip_text = true
			t.add_child(nm)
			var tx := UI.label(String(sk.text), 17, UI.TEXT, false)
			tx.clip_text = true
			t.add_child(tx)
			t.add_child(S.pips(rank, 5, UI.GREEN, 20.0))
			var b := UI.button("+", S.act(func():
				if P.cmd_raise(key):
					UI.sfx("ui_upgrade", "upgrade", -6.0)), "green", 30)
			b.custom_minimum_size = Vector2(74, 70)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.disabled = free <= 0 or rank >= 5
			box.add_child(UI.card(UI.hbox(8, [t, b]), UI.NAVY_D, 8))
		var card := UI.card(box, UI.NAVY_L, 12)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(300, 0)
		cols.add_child(card)
	body.add_child(cols)
	# aktive Fähigkeit
	body.add_child(S.head("Kommandanten-Fähigkeit (eine auswählen, Taste F)", 25))
	var ag := UI.grid(2, 10)
	for k in D.CMD_ORDER:
		var a: Dictionary = D.CMD_ACTIVES[k]
		var open: bool = P.cmd_active_unlocked(k)
		var active: bool = String(P.d.cmd_active) == String(k)
		var t2 := UI.vbox(2)
		t2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t2.add_child(UI.hbox(10, [UI.label(String(a.name), 24, UI.WHITE if open else UI.GREY), UI.icon("clock", 22.0, UI.SKY), UI.label("%d s" % int(a.cd), 20, UI.SKY)]))
		t2.add_child(UI.text(String(a.text), 20))
		var b2: Button
		if not open:
			b2 = UI.button("Ab Stufe %d" % int(a.level), Callable(), "dark", 20)
			b2.disabled = true
		elif active:
			b2 = UI.button("Aktiv", Callable(), "dark", 22)
			b2.disabled = true
		else:
			b2 = UI.button("Wählen", S.act(func():
				P.d.cmd_active = k
				UI.sfx("ui_equip", "", -6.0)
				P.mark()), "green", 22)
		b2.custom_minimum_size = Vector2(150, 64)
		b2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var card2 := UI.card(UI.hbox(14, [UI.tile(String({"airstrike": "target", "supply": "crate", "barrier": "shield", "backup": "friends"}.get(k, "bolt")), 76.0, Color("3FAE2A") if active else (Color("2F8DEB") if open else Color("4A5A78"))), t2, b2]), Color("1F5A34") if active else UI.NAVY_L, 12, UI.GREEN if active else Color(0, 0, 0, 0))
		card2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ag.add_child(card2)
	body.add_child(ag)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_right", 2)
	m.add_child(body)
	c.add_child(S.scroll(m, "commander"))
