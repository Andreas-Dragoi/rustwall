extends RefCounted
## Bildschirm „Spielmodi“ (V6 Paket M): Turm der Prüfungen (50 Stockwerke, Sterne, Belohnungen, Wochen-Rangliste),
## Überleben (endlose Wellen, Verstärkungen, Bestwerte, Wochen-Rangliste) und Clan-Raid (Schleim-Leviathan des Clans,
## Angriffe je Tag, Beiträge der Mitglieder, Belohnungsstufen). Dazu eine Seite zu Höhlen und Ladefläche.
## arg: {"tab": n, "floor": f} (0 Turm, 1 Überleben, 2 Clan-Raid, 3 Höhlen)

const D = preload("res://src/data.gd")
const DM = preload("res://src/data_modi.gd")
const DL = preload("res://src/data_liveops.gd")
const Modi = preload("res://src/modi.gd")
const ModiUI = preload("res://src/modi_ui.gd")
const UI = preload("res://src/ui.gd")

const TABS := ["Turm der Prüfungen", "Überleben", "Clan-Raid", "Höhlen"]
const TAB_ICONS := ["ui_tower", "ui_survival", "ui_raid", "ui_cave"]

var S


func setup(_arg) -> void:
	Modi.net_refresh()


func build() -> Control:
	var v := UI.vbox(12)
	var names: Array = TABS.duplicate()
	if Modi.star_rewards_open() > 0:
		names[0] = "%s (%d)" % [TABS[0], Modi.star_rewards_open()]
	if Modi.has_clan() and Modi.raid_open() > 0:
		names[2] = "%s (%d)" % [TABS[2], Modi.raid_open()]
	v.add_child(S.tabs(names, "tab", 22, TAB_ICONS))
	var body: Control
	match clampi(int(S.st.get("tab", 0)), 0, TABS.size() - 1):
		0:
			body = _tower()
		1:
			body = _surv()
		2:
			body = _raid()
		_:
			body = _caves()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	return v


func _in_base() -> bool:
	var w = G.main.world if G.main != null else null
	return w != null and w.get("mode") == "peace" and not (G.main != null and bool(G.main.get_meta("menu_open", false)) and G.main.menu.visible)


func _start_btn(text: String, cb: Callable, kind := "green") -> Button:
	var b := UI.button(text, func():
		if not _in_base():
			S.say("Starten kannst du nur in deiner Basis.")
			return
		UI.sfx("ui_play", "click", -4.0)
		cb.call(), kind, 30, "ui_play")
	b.custom_minimum_size = Vector2(0, 84)
	return b


func _board_box(kind: String, title: String, unit: String) -> Control:
	var v := UI.vbox(4, [S.head(title, 26)])
	var b := Modi.board(kind)
	var rank := Modi.my_rank(kind)
	for i in mini(10, b.size()):
		var e: Dictionary = b[i]
		v.add_child(_board_row(i + 1, e, unit))
	if rank > 10 and rank <= b.size():
		v.add_child(UI.label("…", 18, UI.TEXT, false))
		v.add_child(_board_row(rank, b[rank - 1], unit))
	var online: bool = P.social != null and P.social.online()
	v.add_child(S.hint("Rangliste vom Server – wird jeden Montag zurückgesetzt." if online else "Ohne Server sind die Mitspieler simuliert. Die Rangliste beginnt jeden Montag neu.", 17))
	var tl := UI.label("", 19, UI.TEXT, false)
	S.live(tl, func() -> String: return "Neue Woche in " + UI.time_text(preload("res://src/liveops.gd").week_left()))
	v.add_child(tl)
	return v


func _board_row(rank: int, e: Dictionary, unit: String) -> Control:
	var me := bool(e.me)
	var l := UI.label("%d." % rank, 21, UI.GOLD if rank <= 3 else UI.TEXT)
	l.custom_minimum_size = Vector2(46, 0)
	var nm := UI.label(String(e.name), 21, UI.GREEN if me else UI.WHITE, me)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	var row := UI.hbox(8, [l, nm, UI.label("%s %s" % [UI.fmt(int(e.score)), unit], 21, UI.GOLD)])
	return UI.card(row, Color("1F4A2A") if me else UI.NAVY_L, 6)


# ================================================================= Turm
func _tower() -> Control:
	var row := UI.hbox(18)
	var f := clampi(int(S.st.get("floor", Modi.next_floor())), 1, DM.TOWER_FLOORS)
	# ---- links: Stockwerk-Liste
	var list := UI.vbox(6)
	for b in DM.TOWER_BLOCKS.size():
		var bd: Dictionary = DM.TOWER_BLOCKS[b]
		list.add_child(UI.hbox(10, [UI.pic("mt_pillar_%d" % (b + 1), 44.0, "ui_tower"), UI.label("Stockwerke %d–%d · %s" % [b * 10 + 1, b * 10 + 10, String(bd.name)], 23, (bd.col as Color).lightened(0.2))]))
		var g := UI.grid(5, 6)
		for k in 10:
			var fl := b * 10 + k + 1
			g.add_child(_floor_btn(fl, fl == f))
		list.add_child(g)
	var lp := UI.panel(S.scroll(list, "floors"), UI.NAVY, UI.EDGE, 24, 16)
	lp.custom_minimum_size = Vector2(520, 0)
	row.add_child(lp)
	# ---- Mitte: gewähltes Stockwerk
	var fd := Modi.floor_def(f)
	var mid := UI.vbox(10)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bdef: Dictionary = DM.TOWER_BLOCKS[Modi.block_of(f)]
	mid.add_child(UI.hbox(12, [UI.pic("mt_pillar_%d" % (Modi.block_of(f) + 1), 76.0, "ui_tower"), UI.vbox(0, [UI.label("Stockwerk %d" % f, 38, UI.GOLD), UI.label(String(fd.name), 28, UI.WHITE)])]))
	var task_icon: String = {"survive": "ui_clock", "defend": "mt_generator", "timed": "ui_speed", "boss": "ui_skull"}.get(String(fd.task), "ui_sword")
	mid.add_child(UI.card(UI.hbox(10, [UI.pic(String(task_icon), 52.0, "ui_target"), UI.text(Modi.floor_text(f), 23, UI.WHITE, 440)]), UI.NAVY_L, 10))
	var fam_txt := String(D.FAMILIES[String(fd.fam)].name) if D.FAMILIES.has(String(fd.fam)) else ""
	mid.add_child(S.kv("Gegner", fam_txt, 21))
	mid.add_child(S.kv("Empfohlene Heldenstufe", str(DM.floor_level(f)), 21))
	mid.add_child(S.kv("Saal", String(bdef.name), 21))
	var stars := Modi.floor_stars(f)
	var srow := UI.hbox(6)
	for i in 3:
		srow.add_child(UI.icon("star", 44, UI.GOLD if i < stars else Color(0.28, 0.31, 0.38)))
	mid.add_child(srow)
	var rules := Modi.star_rules(f)
	for i in rules.size():
		mid.add_child(UI.label(("★ " if i < stars else "☆ ") + String(rules[i]), 20, UI.GOLD if i < stars else UI.TEXT, false))
	if Modi.floor_best_time(f) > 0.0:
		mid.add_child(S.kv("Bestzeit", ("%.1f s" % Modi.floor_best_time(f)).replace(".", ","), 21))
	var rw := DM.floor_reward(f)
	if stars == 0:
		mid.add_child(UI.label("Erste Belohnung: %s" % Modi.bundle_text(rw), 21, UI.SKY))
	else:
		mid.add_child(UI.label("Erste Belohnung abgeholt. Läufe zählen weiter für die Wochenwertung.", 19, UI.TEXT, false))
	if Modi.floor_unlocked(f):
		var ff: int = f
		mid.add_child(_start_btn("Stockwerk %d starten" % f, func(): ModiUI.start_tower(ff)))
	else:
		mid.add_child(UI.info_box("Erst Stockwerk %d schaffen." % (f - 1), 21, "ui_lock"))
	var hl := UI.text("Fällt dein Held, ist die Prüfung verloren. Du kannst jedes Stockwerk beliebig oft versuchen.", 19, UI.TEXT, 440)
	mid.add_child(hl)
	row.add_child(UI.panel(S.scroll(mid, "floor_mid"), UI.NAVY, (bdef.col as Color).darkened(0.25), 24, 18))
	# ---- rechts: Sterne-Belohnungen und Rangliste
	var right := UI.vbox(10)
	right.custom_minimum_size = Vector2(430, 0)
	right.add_child(UI.hbox(10, [UI.icon("star", 44, UI.GOLD), UI.label("%d / %d Sterne" % [Modi.total_stars(), DM.TOWER_FLOORS * 3], 28, UI.GOLD)]))
	right.add_child(UI.label("Höchstes Stockwerk: %d" % Modi.best_floor(), 21, UI.TEXT, false))
	for i in DM.STAR_REWARDS.size():
		var e: Array = DM.STAR_REWARDS[i]
		var done := Modi.star_reward_claimed(i)
		var ready := Modi.star_reward_ready(i)
		var idx: int = i
		var b: Button
		if done:
			b = UI.button("Abgeholt", Callable(), "dark", 18, "ui_check")
			UI.disable(b)
		else:
			b = UI.button("Abholen", S.act(func():
				if S.say(Modi.claim_star_reward(idx)):
					UI.sfx("ui_claim", "chest", -2.0)), "green" if ready else "dark", 18, "ui_chest" if ready else "ui_lock")
			UI.disable(b, not ready)
		var info := UI.vbox(0, [UI.label("%d Sterne" % int(e[0]), 20, UI.GOLD), UI.label(Modi.bundle_text(e[1]), 17, UI.WHITE, false)])
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.add_child(UI.card(UI.hbox(8, [info, b]), Color("1F5A34") if done else UI.NAVY_L, 8, UI.GREEN if ready else Color(0, 0, 0, 0)))
	right.add_child(UI.sep(false))
	right.add_child(UI.label("Deine Wochenwertung: %s Punkte" % UI.fmt(Modi.tower_week_score()), 21, UI.GOLD))
	right.add_child(_board_box("tower", "Wochen-Rangliste", "P."))
	row.add_child(UI.panel(S.scroll(right, "tower_right"), UI.NAVY, UI.EDGE, 24, 16))
	return row


func _floor_btn(f: int, sel: bool) -> Control:
	var stars := Modi.floor_stars(f)
	var open := Modi.floor_unlocked(f)
	var v := UI.vbox(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var num := UI.label(str(f), 26, UI.GOLD if open else UI.GREY)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(num)
	if not open:
		var lk := UI.pic("ui_lock", 22.0)
		lk.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(lk)
	else:
		var sr := UI.hbox(0)
		sr.alignment = BoxContainer.ALIGNMENT_CENTER
		for i in 3:
			sr.add_child(UI.icon("star", 18, UI.GOLD if i < stars else Color(0.28, 0.31, 0.38)))
		v.add_child(sr)
	if f % 10 == 0:
		num.add_theme_color_override("font_color", UI.RED if open else UI.GREY)
	var b: Button = S.card_button(sel, S.set_st("floor", f), v, 74.0)
	b.custom_minimum_size = Vector2(88, 74)
	b.tooltip_text = "%d: %s" % [f, String(Modi.floor_def(f).name)]
	return b


# ================================================================= Überleben
func _surv() -> Control:
	var row := UI.hbox(18)
	var left := UI.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := Modi.surv()
	left.add_child(UI.hbox(14, [UI.pic("ui_survival", 84.0, "ui_clock"), UI.vbox(0, [UI.label("Überleben", 40, UI.GOLD), UI.label("Schrottplatz – endlose Wellen", 22, UI.WHITE)])]))
	left.add_child(UI.text("Halte auf dem Schrottplatz so viele Wellen durch wie möglich. Jede Welle wird stärker, alle fünf Wellen kommt eine neue Familie und alle zehn ein Boss. Nach jeder fünften Welle wählst du eine von drei Verstärkungen – sie gilt bis zum Ende des Laufs.", 21, UI.WHITE, 620))
	left.add_child(S.kv("Bestwert", "%s Punkte" % UI.fmt(int(s.best)), 22))
	left.add_child(S.kv("Weiteste Welle", str(int(s.best_wave)), 22))
	left.add_child(S.kv("Diese Woche", "%s Punkte" % UI.fmt(int(s.week_best)), 22))
	left.add_child(S.kv("Läufe", str(int(s.runs)), 22))
	left.add_child(S.head("Belohnungen für Wellen (einmalig)", 24))
	for i in DM.SURV_WAVE_REWARDS.size():
		var e: Array = DM.SURV_WAVE_REWARDS[i]
		var done: bool = i in s.claimed or float(i) in s.claimed
		left.add_child(UI.hbox(10, [UI.pic("ui_check" if done else "ui_flag", 30.0, "", UI.GREEN if done else UI.WHITE), UI.label("Welle %d: %s" % [int(e[0]), Modi.bundle_text(e[1])], 20, UI.GREEN if done else UI.WHITE, false)]))
	left.add_child(UI.label("Münzen am Ende: %d %% der Punkte" % int(DM.SURV_COIN_K * 100.0), 19, UI.TEXT, false))
	left.add_child(_start_btn("Überleben starten", func(): ModiUI.start_surv()))
	row.add_child(UI.panel(S.scroll(left, "surv_left"), UI.NAVY, UI.EDGE, 24, 18))
	var mid := UI.vbox(8, [S.head("Verstärkungen", 26)])
	mid.custom_minimum_size = Vector2(420, 0)
	for k in DM.UPGRADE_ORDER:
		var ud: Dictionary = DM.UPGRADES[k]
		mid.add_child(UI.hbox(10, [UI.pic(String(ud.icon), 40.0, "ui_star"), UI.vbox(-2, [UI.label("%s (bis %d×)" % [String(ud.name), int(ud.max)], 20, UI.GOLD), UI.label(String(ud.text), 17, UI.WHITE, false)])]))
	row.add_child(UI.panel(S.scroll(mid, "surv_mid"), UI.NAVY, UI.EDGE, 24, 16))
	var right := _board_box("surv", "Wochen-Rangliste", "P.")
	right.custom_minimum_size = Vector2(420, 0)
	row.add_child(UI.panel(S.scroll(right, "surv_right"), UI.NAVY, UI.EDGE, 24, 16))
	return row


# ================================================================= Clan-Raid
func _raid() -> Control:
	var row := UI.hbox(18)
	var left := UI.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lev := int(D.ENEMY_INDEX["boss_leviathan"])
	left.add_child(UI.hbox(14, [UI.enemy_pic(lev, 96.0), UI.vbox(0, [UI.label("Clan-Raid", 40, UI.GOLD), UI.label("Schleim-Leviathan", 26, UI.RED)])]))
	left.add_child(UI.text("Jede Woche taucht für jeden Clan ein eigener Leviathan auf – mit riesigem Leben. Jedes Mitglied hat %d Angriffe am Tag zu je %d Sekunden; der Schaden aller Mitglieder zählt zusammen. Je weiter ihr ihn schafft, desto besser die Belohnung für alle, die mitgekämpft haben." % [DM.RAID_TRIES, int(DL.BOSS_TIME)], 21, UI.WHITE, 620))
	if not Modi.has_clan():
		left.add_child(UI.info_box("Du bist in keinem Clan. Tritt einem Clan bei oder gründe einen (Clanhalle).", 22, "ui_clan"))
		var cb := UI.button("Zum Clan", func(): S.open("clan"), "gold", 26, "ui_clan")
		cb.custom_minimum_size = Vector2(0, 76)
		left.add_child(cb)
		row.add_child(UI.panel(S.scroll(left, "raid_left"), UI.NAVY, UI.EDGE, 24, 18))
		return row
	var pr := Modi.raid_progress()
	left.add_child(UI.label("Clan %s" % Modi.clan_name(), 28, UI.SKY))
	var bar := UI.bar(pr, UI.RED, Vector2(400, 30))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(bar)
	left.add_child(UI.label("%s / %s Schaden (%d %%)" % [UI.fmt(Modi.raid_total()), UI.fmt(Modi.raid_hp()), int(pr * 100.0)], 22, UI.GOLD))
	var r := Modi.raid()
	left.add_child(S.kv("Dein Schaden diese Woche", UI.fmt(int(r.dmg)), 21))
	left.add_child(S.kv("Bester Angriff", UI.fmt(int(r.best)), 21))
	var tl := UI.label("", 20, UI.TEXT, false)
	S.live(tl, func() -> String: return "Der Leviathan zieht weiter in " + UI.time_text(preload("res://src/liveops.gd").week_left()))
	left.add_child(tl)
	var go := UI.button("Angreifen! (%d/%d heute)" % [Modi.raid_tries_left(), DM.RAID_TRIES], func():
		var why := Modi.start_raid()
		if why == "":
			S.close()
		else:
			S.say(why), "red", 28, "ui_skull")
	go.custom_minimum_size = Vector2(0, 80)
	UI.disable(go, Modi.raid_tries_left() <= 0 or not _in_base() or pr >= 1.0)
	left.add_child(go)
	if not _in_base():
		left.add_child(S.hint("Angreifen geht nur in deiner Basis.", 18, UI.ORANGE))
	left.add_child(S.head("Belohnungen für den Clan", 24))
	for i in DM.RAID_TIERS.size():
		var done := Modi.raid_tier_claimed(i)
		var ready := Modi.raid_tier_ready(i)
		var idx: int = i
		var b: Button
		if done:
			b = UI.button("Abgeholt", Callable(), "dark", 18, "ui_check")
			UI.disable(b)
		else:
			b = UI.button("Abholen", S.act(func():
				if S.say(Modi.raid_claim(idx)):
					UI.sfx("ui_claim", "chest", -2.0)), "green" if ready else "dark", 18, "ui_chest" if ready else "ui_lock")
			UI.disable(b, not ready)
		var info := UI.vbox(0, [UI.label("Stufe %d · %d %%" % [i + 1, int(DM.RAID_TIERS[i])], 20, UI.GOLD), UI.label(Modi.bundle_text(DM.RAID_REWARDS[i]), 17, UI.WHITE, false)])
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_child(UI.card(UI.hbox(8, [info, b]), Color("1F5A34") if done else UI.NAVY_L, 8, UI.GREEN if ready else Color(0, 0, 0, 0)))
	left.add_child(S.hint("Belohnungen gibt es, wenn du diese Woche mindestens einmal angegriffen hast.", 17))
	row.add_child(UI.panel(S.scroll(left, "raid_left"), UI.NAVY, UI.RED.darkened(0.3), 24, 18))
	var right := UI.vbox(4, [S.head("Beiträge der Mitglieder", 26)])
	right.custom_minimum_size = Vector2(460, 0)
	var ms := Modi.raid_members()
	var top := maxi(1, int(ms[0].dmg)) if not ms.is_empty() else 1
	for i in ms.size():
		var m: Dictionary = ms[i]
		var me := bool(m.me)
		var nm := UI.label("%d. %s" % [i + 1, String(m.name)], 19, UI.GREEN if me else UI.WHITE, me)
		nm.clip_text = true
		nm.custom_minimum_size = Vector2(210, 0)
		var mb := UI.bar(float(m.dmg) / float(top), UI.RED if not me else UI.GREEN, Vector2(110, 14))
		mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		right.add_child(UI.hbox(8, [nm, mb, UI.label(UI.fmt(int(m.dmg)), 19, UI.GOLD)]))
	var online: bool = P.social != null and P.social.online()
	right.add_child(S.hint("Schaden der Mitglieder vom Server." if online else "Ohne Server kämpfen die anderen Clanmitglieder simuliert mit.", 17))
	row.add_child(UI.panel(S.scroll(right, "raid_right"), UI.NAVY, UI.EDGE, 24, 16))
	return row


# ================================================================= Höhlen und Ladefläche
func _caves() -> Control:
	var row := UI.hbox(18)
	var left := UI.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(UI.hbox(14, [UI.pic("ui_cave", 84.0, "ui_map"), UI.vbox(0, [UI.label("Höhlen", 40, UI.GOLD), UI.label("in der Expedition ab %s" % String(D.AREAS[DM.CAVE_FROM_AREA].name), 22, UI.WHITE)])]))
	left.add_child(UI.text("Ab dem zweiten Gebiet liegen bei jedem Besuch ein bis zwei Höhleneingänge auf der Karte. Drinnen warten mehrere dunkle Räume mit Fackeln, Gegnern der Gebietsfamilie, eine Truhe und eine Erzader am Ende. Der Rückweg führt zur Leiter am Eingang. Alles, was du findest, landet im Rucksack der Expedition.", 21, UI.WHITE, 620))
	var c: Dictionary = Modi.st().caves
	left.add_child(S.kv("Erkundete Höhlen", str(int(c.done)), 22))
	left.add_child(S.kv("Geöffnete Truhen", str(int(c.chests)), 22))
	left.add_child(S.kv("Abgebaute Erzadern", str(int(c.ore)), 22))
	var th := UI.flow(14)
	for t in DM.CAVE_THEMES:
		th.add_child(UI.vbox(2, [UI.pic("cv_%s_entry" % t, 110.0, "ui_cave"), UI.label(String(DM.CAVE_THEMES[t].name), 19, UI.GOLD)]))
	left.add_child(th)
	row.add_child(UI.panel(S.scroll(left, "cave_left"), UI.NAVY, UI.EDGE, 24, 18))
	var right := UI.vbox(10)
	right.custom_minimum_size = Vector2(520, 0)
	right.add_child(UI.hbox(14, [UI.vehicle_pic("pickup", 110.0), UI.vbox(0, [UI.label("Ladefläche", 34, UI.GOLD), UI.label(String(D.VEHICLES.pickup.name), 22, UI.WHITE)])]))
	right.add_child(UI.text("Die Pritsche hat eine Ladefläche als zweiten Rucksack. Stehst du mit vollem Rucksack neben dem Fahrzeug, lädt dein Held alles auf die Ladefläche – die Ladung ist auf dem Fahrzeug zu sehen. Fährst du die Pritsche ans Depot der Außenbasis, wird sie abgeladen.", 21, UI.WHITE, 480))
	var lv := 0
	if P.d.vehicles.has("pickup"):
		lv = int(P.d.vehicles.pickup.get("bed", 0))
	right.add_child(S.kv("Tragkraft der Ladefläche", str(int(DM.BED_CAP * (1.0 + 0.15 * lv))), 22))
	right.add_child(S.hint("Mehr Tragkraft: Garage → Pritsche → Ausbau „Ladefläche“.", 18))
	row.add_child(UI.panel(S.scroll(right, "cave_right"), UI.NAVY, UI.EDGE, 24, 16))
	return row
