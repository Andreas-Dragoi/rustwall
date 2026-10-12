extends RefCounted
## Bildschirm "Helden": Liste links, Vorschau und Reiter rechts.

const D = preload("res://src/data.gd")
const UI = preload("res://src/ui.gd")
const Arsenal = preload("res://src/arsenal_rules.gd")

const TABS := ["Übersicht", "Waffen", "Ausrüstung", "Talente", "Fähigkeiten", "Geschichte", "Auto-Expedition"]
const TAB_ICONS := ["ui_info", "ui_sword", "ui_helmet", "ui_star", "ui_bolt", "ui_quest", "ui_expedition"]
const TAB_KEYS := ["overview", "weapons", "gear", "talents", "skills", "story", "auto"]
const MALE := ["jona", "bruno"]
const STAT_NAME := {"dmg": "Schaden", "hp": "Leben", "speed": "Tempo", "cdr": "Fähigkeiten laden schneller", "reload": "Nachladezeit", "range": "Reichweite",
	"pickup": "Sammelradius", "tower": "Turmschaden in der Nähe", "heal": "Heilung", "ult": "Spezialfähigkeit", "crit": "Volltreffer", "carry": "Tragemenge", "burn": "Brenndauer"}
const STAT_ICON := {"dmg": "ui_sword", "hp": "ui_heart", "speed": "ui_boot", "cdr": "ui_clock", "reload": "ui_recycle", "range": "ui_target", "pickup": "ui_pack",
	"tower": "ui_build", "heal": "ui_heart", "ult": "ui_bolt", "crit": "ui_star", "carry": "ui_crate", "burn": "ui_fire"}
const GEAR_HINT := {"helmet": "gibt mehr Leben", "vest": "erhöht die Tragemenge", "charm": "Fähigkeiten laden schneller"}
const SCENES := {"jona": "meadow", "mika": "sand", "bruno": "forest", "ada": "night", "yuki": "snow", "greta": "crater"}
const SKILL_KEYS := ["Q", "E", "R"]
const SKILL_LEVELS := [1, 5, 10]

var S


func setup(arg) -> void:
	if not S.st.has("hero"):
		S.st["hero"] = String(P.d.hero_sel)
	if not S.st.has("tab"):
		S.st["tab"] = 0
	if arg is String:
		if D.HEROES.has(arg):
			S.st["hero"] = arg
		elif TAB_KEYS.has(arg):
			S.st["tab"] = TAB_KEYS.find(arg)


func build() -> Control:
	var key := String(S.st.hero)
	var row := UI.hbox(20)
	row.add_child(_hero_list(key))
	var right := UI.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var unlocked: bool = P.hero_unlocked(key)
	if unlocked:
		right.add_child(S.tabs(TABS, "tab", 21, TAB_ICONS))
	var main := UI.hbox(16)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(main)
	main.add_child(_preview_col(key, unlocked))
	var content := UI.vbox(12)
	var tab := int(S.st.tab) if unlocked else 0
	match tab:
		0:
			_overview(content, key, unlocked)
		1:
			_weapons(content, key)
		2:
			_gear(content, key)
		3:
			_talents(content, key)
		4:
			_skills(content, key)
		5:
			_story(content, key)
		6:
			_auto(content, key)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_right", 2)
	m.add_child(content)
	main.add_child(S.scroll(m, "hero_tab_%d" % tab))
	return row


# ----------------------------------------------------------------- Liste links
func _hero_list(sel: String) -> Control:
	var v := UI.vbox(10)
	for hk in D.HERO_ORDER:
		var def: Dictionary = D.HEROES[hk]
		var h: Dictionary = P.hero(hk)
		var unlocked: bool = P.hero_unlocked(hk)
		var name_l := UI.label(String(def.name), 25)
		name_l.clip_text = true
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sub := "Stufe %d · %s" % [int(h.level), String(def.role)]
		var sub_col := UI.TEXT
		if not unlocked:
			sub = "Rette %s in: %s" % ["ihn" if MALE.has(hk) else "sie", String(D.AREAS[int(def.unlock_area)].name)]
			sub_col = UI.GREY
		elif P.auto_ready(hk):
			sub = "Zurück! Beute abholen"
			sub_col = UI.GREEN
		elif P.hero_busy(hk):
			sub = "Unterwegs"
			sub_col = UI.ORANGE
		elif String(P.d.hero_sel) == hk:
			sub = "Stufe %d · Ausgewählt" % int(h.level)
			sub_col = UI.GREEN
		var sub_l := UI.sub_label(sub, 19, sub_col, hk == sel)
		sub_l.clip_text = true
		sub_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var txt := UI.vbox(-2, [name_l, sub_l])
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.alignment = BoxContainer.ALIGNMENT_CENTER
		var face := UI.hero_pic(hk, 96.0)
		var content := UI.hbox(12, [face, txt])
		if not unlocked:
			face.modulate = Color(0.35, 0.42, 0.6)
			content.add_child(UI.icon("lock", 34.0, UI.GOLD))
		elif P.auto_ready(hk):
			content.add_child(UI.new_tag(15))
		v.add_child(S.card_button(hk == sel, S.set_st("hero", hk), content, 116.0))
	var sc: ScrollContainer = S.scroll(v, "hero_list", Vector2(400, 0))
	sc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return sc


# ----------------------------------------------------------------- Vorschau mit Auswahlknopf
func _preview_col(key: String, unlocked: bool) -> Control:
	var def: Dictionary = D.HEROES[key]
	var v := UI.vbox(8)
	v.custom_minimum_size = Vector2(320, 0)
	var pv: Control = S.preview_hero(key)
	pv.custom_minimum_size = Vector2(320, 300)
	pv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if not unlocked:
		pv.modulate = Color(0.45, 0.5, 0.6)
	else:
		pv.modulate = Color.WHITE
	v.add_child(UI.frame(pv, UI.scenery(String(SCENES.get(key, "meadow")))))
	v.get_child(0).size_flags_vertical = Control.SIZE_EXPAND_FILL
	var nm := UI.label(String(def.name), 28)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	var btn: Button
	if not unlocked:
		btn = UI.button("Noch nicht gerettet", Callable(), "dark", 24, "ui_lock")
		UI.disable(btn)
	elif P.auto_ready(key):
		btn = UI.button("Beute abholen", S.set_st("tab", 6), "gold", 26, "ui_chest")
	elif P.hero_busy(key):
		btn = UI.button("Unterwegs", Callable(), "dark", 26, "ui_clock")
		UI.disable(btn)
	elif String(P.d.hero_sel) == key:
		btn = UI.button("Ausgewählt", Callable(), "dark", 26, "ui_check")
		UI.disable(btn)
	else:
		btn = UI.button("Auswählen", S.act(func():
			P.select_hero(key)
			UI.sfx("ui_equip", "", -6.0)
			S.preview_cheer()), "green", 28, "ui_check")
	btn.custom_minimum_size = Vector2(0, 82)
	v.add_child(btn)
	return v


# ----------------------------------------------------------------- Übersicht
func _overview(c: VBoxContainer, key: String, unlocked: bool) -> void:
	var def: Dictionary = D.HEROES[key]
	var h: Dictionary = P.hero(key)
	var lv := int(h.level)
	var top := UI.hbox(12, [S.head(String(def.title), 34), UI.badge(String(def.role), def.color.darkened(0.25), 22)])
	if unlocked:
		top.add_child(UI.spacer(true))
		top.add_child(UI.pill(UI.hbox(8, [UI.pic("ui_sword", 30.0, "", UI.GOLD), UI.label("Kampfkraft %d" % P.hero_power(key), 23, UI.GOLD)])))
	c.add_child(top)
	if not unlocked:
		var area: Dictionary = D.AREAS[int(def.unlock_area)]
		var t := "%s ist noch nicht bei dir. Rette %s in der Expedition „%s“ (Auftrag „Rettung“)." % [String(def.name), "ihn" if MALE.has(key) else "sie", String(area.name)]
		c.add_child(UI.card(UI.hbox(14, [UI.icon("lock", 48.0, UI.GOLD), UI.text(t, 24, UI.WHITE)]), Color("4A3A1C"), 14, UI.GOLD))
	else:
		var need: int = D.hero_xp_need(lv)
		var xp_row := UI.hbox(12)
		xp_row.add_child(UI.label("Stufe %d" % lv, 30))
		if lv >= D.HERO_MAX_LEVEL:
			xp_row.add_child(UI.label("Höchststufe erreicht", 22, UI.GREEN))
		else:
			var bar := UI.bar(float(h.xp) / maxf(1.0, need), D.C_BAR_BLUE, Vector2(240, 28), "hero_xp_" + key)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			xp_row.add_child(bar)
			xp_row.add_child(UI.label("%d / %d" % [int(h.xp), need], 22, UI.GOLD))
		c.add_child(xp_row)
		# Abzeichen und nächste Schranke
		var badges := int(P.d.badges[key])
		var gate_text := "Alle Stufen-Schranken geschafft."
		var gates: Array = D.BADGE_GATES.keys()
		gates.sort()
		for g in gates:
			if int(g) > lv:
				gate_text = "Für Stufe %d braucht %s %d Abzeichen (aus Beutekisten)." % [int(g), key.capitalize(), int(D.BADGE_GATES[g])]
				break
		c.add_child(UI.card(UI.hbox(12, [UI.icon("badge", 44.0), UI.label("%d Abzeichen" % badges, 25, UI.GOLD), UI.text(gate_text, 21)]), UI.NAVY_L, 10))
		# Was die Heldenstufe freischaltet: jeder Held wird einzeln gelevelt
		var ladder := UI.flow(8)
		for e in [[1, "1. Waffe, 1. Fähigkeit"], [D.HERO_DODGE2_LEVEL, "2. Ausweichrolle"], [5, "2. Fähigkeit"], [8, "2. Waffe"], [10, "Spezialfähigkeit"], [D.HERO_CHARM_LEVEL, "Glücksbringer"], [16, "3. Waffe"], [D.HERO_PASSIVE_LEVEL, "Besonderheit +"]]:
			var got: bool = lv >= int(e[0])
			var chip := UI.hbox(6, [UI.pic("ui_check" if got else "ui_lock", 22.0, "", UI.GREEN if got else UI.GREY), UI.label("%d · %s" % [int(e[0]), String(e[1])], 18, UI.WHITE if got else UI.GREY, false)])
			ladder.add_child(UI.card(chip, Color("1F5A34") if got else UI.NAVY_D, 6))
		c.add_child(ladder)
		c.add_child(UI.label("Jede Stufe: +3 % Leben, +2 % Schaden und ein Talentpunkt. Erfahrung bekommt nur der Held, der kämpft." , 18, UI.GREY, false))
		# Werte
		var stats: Dictionary = P.hero_stats(key)
		var g2 := UI.grid(2, 10)
		g2.add_theme_constant_override("h_separation", 36)
		g2.add_child(UI.stat_row("ui_heart", "Leben", str(int(round(float(stats.hp)))), 23))
		g2.add_child(UI.stat_row("ui_boot", "Lauftempo", ("%.1f m/s" % float(stats.speed)).replace(".", ","), 23))
		var m: Dictionary = stats.m
		for sk in ["dmg", "crit", "reload", "range", "cdr", "ult", "tower", "heal", "carry", "pickup", "burn"]:
			var val := float(m.get(sk, 0.0))
			if val > 0.001:
				var sign := "−" if sk == "reload" else "+"
				g2.add_child(UI.stat_row(String(STAT_ICON.get(sk, "ui_up")), String(STAT_NAME[sk]), "%s%d %%" % [sign, int(round(val * 100.0))], 23))
		for ch in g2.get_children():
			ch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_child(UI.card(g2, UI.NAVY_L, 14))
	c.add_child(S.head("Besonderheit", 24))
	c.add_child(UI.text(String(def.passive), 23))
	c.add_child(S.head("Aussehen", 24))
	c.add_child(UI.text(String(def.look), 23))
	if not unlocked:
		c.add_child(S.head("Geschichte", 24))
		c.add_child(UI.text(String(def.story), 23))


# ----------------------------------------------------------------- Waffen
func _owned(slot: String, wkey := "") -> Array:
	var out: Array = []
	for it in P.d.items:
		if it.slot == slot and (wkey == "" or it.key == wkey):
			out.append(it)
	out.sort_custom(func(a, b):
		if int(a.rarity) != int(b.rarity):
			return int(a.rarity) > int(b.rarity)
		if int(a.level) != int(b.level):
			return int(a.level) > int(b.level)
		return int(a.id) < int(b.id))
	return out


func _item_row(it: Dictionary, right: Control) -> Control:
	var r := int(it.rarity)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := UI.hbox(14, [UI.item_pic(it, 76.0), S.item_info(it, 23), UI.rarity_dot(S.rarity_color(r), 24.0), right])
	return UI.card(row, UI.NAVY_D, 10, Color(S.rarity_color(r), 0.55))


## Alle 15 Waffen des Helden (wie in der Werkstatt): besessen mit Ausrüsten, gesperrt mit Hinweis, wo es sie gibt.
## Oben der Schnellwechsel: jede besessene Waffenart als Bild, ein Tipp rüstet das beste Stück davon aus (Paket F).
func _weapons(c: VBoxContainer, key: String) -> void:
	var def: Dictionary = D.HEROES[key]
	var h: Dictionary = P.hero(key)
	var wkeys: Array = D.hero_weapons(key)
	var cur: Dictionary = P.item(int(h.weapon))
	var cur_key := String(cur.get("key", ""))
	# ---- Schnellwechsel
	var quick := UI.flow(8)
	var owned_n := 0
	for wk in wkeys:
		var items := _owned("weapon", String(wk))
		if items.is_empty():
			continue
		owned_n += 1
		var best: Dictionary = items[0]
		var on: bool = cur_key == String(wk)
		var pic := UI.pic("w_" + String(wk), 64.0, "sword")
		var qb: Button = S.card_button(on, S.act(func():
			if int(h.weapon) != int(best.id):
				P.equip(key, int(best.id))
				UI.sfx("ui_equip", "", -6.0)
				S.preview_cheer()), UI.vbox(0, [pic]), 78.0)
		qb.custom_minimum_size = Vector2(88, 84)
		qb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		qb.tooltip_text = "%s (%s)" % [String(D.WEAPONS[wk].name), String(D.RARITY[int(best.rarity)].name)]
		quick.add_child(qb)
	var qhead := UI.hbox(10, [UI.pic("ui_speed", 34.0), UI.label("Schnellwechsel", 25, UI.GOLD), UI.spacer(true), UI.label("%d von %d Waffen im Besitz" % [owned_n, wkeys.size()], 20, UI.TEXT, false)])
	c.add_child(UI.card(UI.vbox(8, [qhead, quick]), UI.NAVY_L, 12, Color(UI.GOLD, 0.5)))
	# ---- alle Waffen
	for i in wkeys.size():
		var wk := String(wkeys[i])
		var w: Dictionary = D.WEAPONS[wk]
		var need := D.weapon_level(wk)
		var st := Arsenal.status(wk)
		var box := UI.vbox(6)
		var info := "Schaden %d · %d Schuss/Min · Reichweite %d m" % [int(w.damage), int(w.rpm), int(w.range)]
		if int(w.get("mag", 0)) > 0:
			info += " · Magazin %d" % int(w.mag)
		var wp := UI.pic("w_" + wk, 80.0, "sword")
		var nm := UI.label(String(w.name), 26, UI.WHITE if st == "owned" else UI.GREY)
		var tt := UI.vbox(0, [UI.hbox(10, [nm, UI.label(String(w.kind), 19, UI.SKY, false), UI.label("Stufe %d" % need, 17, UI.GREY, false)]), UI.label(info, 18, UI.TEXT, false)])
		tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tt.alignment = BoxContainer.ALIGNMENT_CENTER
		var title := UI.hbox(12, [wp, tt])
		box.add_child(title)
		if st == "owned":
			# höchstens zwei Stücke je Art (das ausgerüstete und das beste), der Rest steht in der Werkstatt
			var all_it := _owned("weapon", wk)
			var show: Array = []
			for it0 in all_it:
				if int(it0.id) == int(h.weapon):
					show.append(it0)
			for it0 in all_it:
				if show.size() < 2 and not show.has(it0):
					show.append(it0)
			for it in show:
				var id := int(it.id)
				var right: Control
				if int(h.weapon) == id:
					right = UI.badge("Ausgerüstet", Color("2E8A22"), 20)
				else:
					right = UI.button("Ausrüsten", S.act(func():
						P.equip(key, id)
						UI.sfx("ui_equip", "", -6.0)), "green", 22)
					right.custom_minimum_size = Vector2(170, 64)
				box.add_child(_item_row(it, right))
			if all_it.size() > show.size():
				box.add_child(UI.label("   + %d weitere Stücke (Werkstatt: verbessern, verschmelzen)" % (all_it.size() - show.size()), 18, UI.GREY, false))
		else:
			wp.modulate = Color(0.05, 0.08, 0.16, 0.85) if int(h.level) < need else Color(0.32, 0.38, 0.55, 0.9)
			var hint := UI.label(Arsenal.hint(wk), 19, UI.ORANGE if int(h.level) < need else (UI.GREEN if st == "craft" else UI.GREY), false)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var lrow := UI.hbox(10, [UI.pic("ui_lock" if st != "craft" else "ui_hammer", 30.0, "", UI.GOLD), UI.badge(String(D.WEAPON_GET_NAME[D.weapon_get(wk)]), Color("2F6DB8"), 16), hint])
			if st == "craft":
				var cb := UI.button("Herstellen", S.act(func():
					if not Arsenal.craft(wk).is_empty():
						S.preview_cheer()), "green", 22, "ui_hammer")
				cb.custom_minimum_size = Vector2(0, 60)
				UI.disable(cb, not Arsenal.can_craft(wk))
				lrow.add_child(UI.cost_row(D.craft_cost(wk), 18))
				lrow.add_child(cb)
			box.add_child(lrow)
		c.add_child(UI.card(box, UI.NAVY_L if st == "owned" else UI.NAVY_D, 12))
	c.add_child(S.hint("Neue Waffen gibt es als Fund oder Bauplan auf Expeditionen und in Beutekisten. In der Werkstatt lassen sie sich verbessern und verschmelzen."))


# ----------------------------------------------------------------- Ausrüstung
func _gear(c: VBoxContainer, key: String) -> void:
	var h: Dictionary = P.hero(key)
	for slot in ["helmet", "vest", "charm"]:
		var g: Dictionary = D.GEAR[slot]
		var box := UI.vbox(8)
		var cur := int(h.gear[slot])
		var title := UI.hbox(12, [UI.pic("ui_" + ("clover" if slot == "charm" else String(slot)), 44.0), UI.label(String(g.name), 29)])
		title.add_child(UI.label(String(GEAR_HINT[slot]), 21, UI.SKY, false))
		box.add_child(title)
		if slot == "charm" and int(h.level) < D.HERO_CHARM_LEVEL:
			box.add_child(UI.hbox(10, [UI.pic("ui_lock", 34.0, "", UI.GOLD), UI.label("Dieser Platz öffnet sich ab Heldenstufe %d." % D.HERO_CHARM_LEVEL, 22, UI.GOLD)]))
			c.add_child(UI.card(box, UI.NAVY_L, 14))
			continue
		var items := _owned(slot)
		if items.is_empty():
			box.add_child(S.hint("Noch nichts im Besitz. Ausrüstung steckt in Beutekisten."))
		for it in items:
			var id := int(it.id)
			var right: Control
			if cur == id:
				right = UI.button("Ablegen", S.act(func():
					h.gear[slot] = 0
					P.mark()), "dark", 22)
			else:
				var other: String = P.equipped_by(id)
				var t := "Anlegen"
				if other != "" and other != key:
					t = "Von %s holen" % other.capitalize()
				right = UI.button(t, S.act(func():
					P.equip(key, id)
					UI.sfx("ui_equip", "", -6.0)), "green", 22)
			right.custom_minimum_size = Vector2(180, 70)
			var rowc := _item_row(it, right)
			if cur == id:
				rowc.add_theme_stylebox_override("panel", UI.card_style(Color("1F5A34"), UI.GREEN, 16, 10))
			box.add_child(rowc)
		c.add_child(UI.card(box, UI.NAVY_L, 14))


# ----------------------------------------------------------------- Talente
func _talent_text(stat: String, val: float) -> String:
	var pct := int(round(val * 100.0))
	if stat == "reload":
		return "−%d %% Nachladezeit" % pct
	if stat == "cdr":
		return "Fähigkeiten +%d %% schneller" % pct
	if stat == "tower":
		return "+%d %% Turmschaden" % pct
	return "+%d %% %s" % [pct, String(STAT_NAME.get(stat, stat))]


func _talents(c: VBoxContainer, key: String) -> void:
	var def: Dictionary = D.HEROES[key]
	var h: Dictionary = P.hero(key)
	var free: int = P.talent_points_free(key)
	var top := UI.hbox(14)
	top.add_child(UI.icon("star", 44.0, UI.GOLD))
	top.add_child(UI.label("Freie Punkte: %d" % free, 30, UI.GOLD if free > 0 else UI.GREY))
	top.add_child(UI.spacer(true))
	var rb := UI.button("Zurücksetzen", func():
		S.confirm("Alle Talentpunkte von %s zurückholen?" % String(def.name), func(): P.talent_reset(key), "Zurücksetzen"), "dark", 22)
	rb.custom_minimum_size = Vector2(0, 64)
	top.add_child(rb)
	c.add_child(top)
	c.add_child(S.hint("Jede Heldenstufe bringt einen Punkt. Die Talente eines Baums werden der Reihe nach gelernt.", 20))
	var cols := UI.hbox(10)
	for t in 3:
		var tree: Dictionary = def.trees[t]
		var rank := int(h.talents[t])
		var box := UI.vbox(5)
		var nm := UI.label(String(tree.name), 25, UI.GOLD)
		nm.clip_text = true
		box.add_child(nm)
		box.add_child(UI.hbox(8, [S.pips(rank, 8, UI.GREEN, 20.0)]))
		var stats: Array = tree.stats
		for i in stats.size():
			var col := UI.GREEN if i < rank else (UI.WHITE if i == rank else Color("6F829C"))
			var l := UI.label(_talent_text(String(stats[i][0]), float(stats[i][1])), 19, col, false)
			l.clip_text = true
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			box.add_child(UI.hbox(8, [UI.pic("ui_check" if i < rank else ("ui_up" if i == rank else "ui_lock"), 22.0, "", col), l]))
		var b: Button
		if rank >= 8:
			b = UI.button("Fertig gelernt", Callable(), "dark", 21)
			b.disabled = true
		else:
			b = UI.button("Lernen", S.act(func():
				if P.talent_raise(key, t):
					UI.sfx("ui_upgrade", "upgrade", -6.0)), "green", 23, "ui_up")
			b.disabled = free <= 0
		b.custom_minimum_size = Vector2(0, 64)
		box.add_child(b)
		var card := UI.card(box, UI.NAVY_L, 12)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(190, 0)
		cols.add_child(card)
	c.add_child(cols)


# ----------------------------------------------------------------- Fähigkeiten
func _skills(c: VBoxContainer, key: String) -> void:
	var def: Dictionary = D.HEROES[key]
	var lv := int(P.hero(key).level)
	var cdr := float(P.hero_stats(key).m.cdr)
	var keys: Array = def.skills
	for i in keys.size():
		var sk: Dictionary = D.SKILLS[keys[i]]
		var open := lv >= int(SKILL_LEVELS[i])
		var title := UI.hbox(10)
		title.add_child(UI.badge(String(SKILL_KEYS[i]), Color("1B3A5E"), 22))
		title.add_child(UI.label(String(sk.name), 27, UI.WHITE if open else UI.GREY))
		if sk.get("ult", false):
			title.add_child(UI.badge("Spezial", Color("8A4FD6"), 19))
		title.add_child(UI.spacer(true))
		title.add_child(UI.icon("clock", 26.0, UI.SKY))
		var cd_text := "%d s" % int(sk.cd)
		if cdr > 0.001:
			cd_text += " (−%d %%)" % int(round(cdr * 100.0))
		title.add_child(UI.label(cd_text, 22, UI.SKY))
		var box := UI.vbox(6, [title, UI.text(String(sk.text), 23)])
		if not open:
			box.add_child(UI.hbox(8, [UI.icon("lock", 26.0, UI.GOLD), UI.label("Ab Heldenstufe %d" % int(SKILL_LEVELS[i]), 22, UI.GOLD)]))
		var sic := UI.tile("bolt" if sk.get("ult", false) else ["target", "shield", "fire"][i % 3], 84.0, def.color if open else Color("4A5A78"))
		sic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card := UI.card(UI.hbox(16, [sic, box]), UI.NAVY_L if open else UI.NAVY_D, 14)
		c.add_child(card)
	c.add_child(S.hint("Am Handy liegen die Fähigkeiten als Knöpfe rechts unten, am PC auf Q, E und R."))


# ----------------------------------------------------------------- Geschichte
func _story(c: VBoxContainer, key: String) -> void:
	var def: Dictionary = D.HEROES[key]
	c.add_child(S.head(String(def.title), 30))
	c.add_child(UI.text(String(def.story), 24))
	var open: int = P.chapters_open(key)
	var chapters: Array = def.chapters
	for i in chapters.size():
		var ch: Array = chapters[i]
		if i < open:
			var box := UI.vbox(6, [UI.label("Kapitel %d: %s" % [i + 1, String(ch[0])], 25, UI.GOLD), UI.text(String(ch[1]), 23)])
			c.add_child(UI.card(box, UI.NAVY_L, 14))
		else:
			var row := UI.hbox(12, [UI.icon("lock", 32.0, UI.GOLD), UI.label("Kapitel %d" % (i + 1), 24, UI.GREY), UI.label("Ab Heldenstufe %d" % int(D.HERO_CHAPTER_LEVELS[i]), 22, UI.GREY, false)])
			c.add_child(UI.card(row, UI.NAVY_D, 14))


# ----------------------------------------------------------------- Auto-Expedition
func _auto(c: VBoxContainer, key: String) -> void:
	var def: Dictionary = D.HEROES[key]
	var h: Dictionary = P.hero(key)
	var first := key.capitalize()
	c.add_child(S.head("Auto-Expedition", 30))
	c.add_child(UI.text("%s zieht allein los und bringt Rohstoffe mit. Das bringt weniger als eine selbst gespielte Expedition, läuft aber auch, wenn du nicht spielst. Solange ist %s nicht spielbar." % [first, first], 22))
	var loot = S.st.get("auto_loot", null)
	if loot is Dictionary and String(S.st.get("auto_hero", "")) == key:
		var lb := UI.vbox(8, [UI.label("%s ist zurück und hat mitgebracht:" % first, 25, UI.GREEN)])
		if loot.is_empty():
			lb.add_child(S.hint("Nichts – die Lager waren voll."))
		else:
			lb.add_child(UI.cost_row(loot, 26, false))
		c.add_child(UI.card(lb, Color("1F4A2A"), 14, UI.GREEN))
	if P.auto_ready(key):
		var area_n := String(D.AREAS[clampi(int(h.auto_area), 0, D.AREAS.size() - 1)].name)
		var b := UI.button("Abholen", S.act(func():
			var got: Dictionary = P.collect_auto(key)
			S.st["auto_loot"] = got
			S.st["auto_hero"] = key
			UI.sfx("ui_claim", "pay", -4.0)
			S.preview_cheer()), "green", 30, "ui_chest")
		b.custom_minimum_size = Vector2(300, 84)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		c.add_child(UI.card(UI.vbox(10, [UI.label("%s ist aus %s zurück!" % [first, area_n], 26), b]), UI.NAVY_L, 14))
		return
	if P.hero_busy(key):
		var area_n2 := String(D.AREAS[clampi(int(h.auto_area), 0, D.AREAS.size() - 1)].name)
		var tl := UI.label("", 30, UI.GOLD)
		S.live(tl, func() -> String: return UI.time_text(float(h.auto_until) - P.now()))
		S.every_second(tl, func():
			if P.auto_ready(key):
				S.refresh())
		var row := UI.hbox(12, [UI.icon("clock", 44.0, UI.SKY), UI.label("Zurück in:", 26), tl, UI.spacer(true)])
		var gc: int = P.auto_speed_cost(key)
		var sb := UI.button("Sofort zurück – gratis" if gc <= 0 else "Sofort zurück  %d" % gc, S.act(func():
			if P.finish_auto(key):
				UI.sfx("ui_buy", "upgrade", -4.0)
			else:
				UI.sfx("ui_error", "error", -6.0)), "green" if gc <= 0 else "gold", 22, "" if gc <= 0 else "res_gems")
		sb.custom_minimum_size = Vector2(0, 66)
		row.add_child(sb)
		c.add_child(UI.card(UI.vbox(8, [UI.label("%s ist unterwegs: %s (%d Std)" % [first, area_n2, int(h.auto_hours)], 25), row]), UI.NAVY_L, 14))
		return
	# Gebiet wählen
	var areas: Array = []
	for i in D.AREAS.size():
		if P.area_unlocked(i):
			areas.append(i)
	if areas.is_empty():
		c.add_child(S.hint("Noch kein Gebiet freigeschaltet."))
		return
	var area := int(S.st.get("auto_area", areas[areas.size() - 1]))
	if not areas.has(area):
		area = int(areas[areas.size() - 1])
	var hours := int(S.st.get("auto_hours", D.AUTO_HOURS[0]))
	c.add_child(UI.label("Wohin?", 24))
	var af := HFlowContainer.new()
	af.add_theme_constant_override("h_separation", 8)
	af.add_theme_constant_override("v_separation", 8)
	for i in areas:
		af.add_child(S.choice(String(D.AREAS[i].name), i == area, S.set_st("auto_area", i), 22))
	c.add_child(af)
	c.add_child(UI.label("Wie lange?", 24))
	var hf := UI.hbox(8)
	for hh in D.AUTO_HOURS:
		var hb: Button = S.choice("%d Std" % int(hh), int(hh) == hours, S.set_st("auto_hours", int(hh)), 22, "ui_clock")
		hf.add_child(hb)
	c.add_child(hf)
	var res_row := UI.hbox(8, [UI.label("Bringt:", 22, UI.TEXT, false)])
	for r in D.AREAS[area].res:
		res_row.add_child(UI.icon(String(r), 30.0))
	res_row.add_child(UI.spacer(false, Vector2(16, 0)))
	res_row.add_child(UI.label("Kostet:", 22, UI.TEXT, false))
	res_row.add_child(UI.cost_row({"fuel": P.fuel_cost(area)}, 24))
	c.add_child(res_row)
	var go := UI.button("Losschicken", S.act(func():
		S.st.erase("auto_loot")
		if P.start_auto(key, area, hours):
			UI.sfx("ui_buy", "pay", -4.0)
			S.toast("%s ist losgezogen." % first)), "green", 30, "ui_expedition")
	go.custom_minimum_size = Vector2(320, 84)
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# ein Held muss zum Spielen dableiben
	var others := 0
	for hk in D.HERO_ORDER:
		if hk != key and P.hero_unlocked(hk) and not P.hero_busy(hk):
			others += 1
	go.disabled = others == 0
	c.add_child(go)
	if others == 0:
		c.add_child(S.hint("Mindestens ein Held muss bei dir bleiben. Rette weitere Helden, um jemanden loszuschicken.", 20, UI.GOLD))
