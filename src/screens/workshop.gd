extends RefCounted
## Bildschirm "Werkstatt": Waffen und Ausrüstung, geordnet nach Held > Platz > Waffe.
## Links die Helden-Reiter in Heldenfarbe, in der Mitte die Liste des gewählten Helden mit festen
## Abschnitten (Waffen, Helm, Weste, Glücksbringer), rechts die Einzelheiten: der Held hält die Waffe,
## Werte im Vergleich zur ausgerüsteten, Ausrüsten, Verbessern, Verschmelzen, Zerlegen.
## V4: je Held alle 15 Waffen (besessen / herstellbar mit Kosten / gesperrt mit Hinweis), Reiter „Herstellen“ mit allen
## Bauplänen; eine noch fehlende Waffe zeigt rechts Beschreibung, Besonderheit, Herkunft und den Knopf „Herstellen“.

const D = preload("res://src/data.gd")
const UI = preload("res://src/ui.gd")
const Arsenal = preload("res://src/arsenal_rules.gd")

const SLOTS := ["weapon", "helmet", "vest", "charm"]
const SLOT_NAMES := {"weapon": "Waffen", "helmet": "Helm", "vest": "Weste", "charm": "Glücksbringer"}
const SLOT_ICONS := {"weapon": "ui_sword", "helmet": "ui_helmet", "vest": "ui_vest", "charm": "ui_clover"}
const FREE_COL := Color("7C879C")
const TIP := "Drei gleiche Stücke derselben Seltenheit lassen sich zu einem besseren verschmelzen."

var S


func setup(arg) -> void:
	if not S.st.has("hero"):
		S.st["hero"] = String(P.d.hero_sel)
	if not S.st.has("slot"):
		S.st["slot"] = ""
	if not S.st.has("item"):
		S.st["item"] = int(arg) if (arg is int or arg is float) else 0
	if int(S.st.item) > 0:
		var it: Dictionary = P.item(int(S.st.item))
		if not it.is_empty():
			S.st["hero"] = owner_of(it) if owner_of(it) != "" else "free"


# ================================================================= Ordnung
## Zu welchem Helden gehört ein Stück in der Liste? Waffen: ihr Held. Ausrüstung: der Träger, sonst "" (frei).
static func owner_of(it: Dictionary) -> String:
	if it.slot == "weapon":
		return String(D.WEAPONS[it.key].hero)
	return P.equipped_by(int(it.id))


## Sortierschlüssel: Held > Platz > Waffenart > ausgerüstet zuerst > Seltenheit absteigend > Stufe absteigend.
static func sort_key(it: Dictionary) -> Array:
	var who := owner_of(it)
	var hi: int = D.HERO_ORDER.find(who) if who != "" else 99
	var si: int = SLOTS.find(String(it.slot))
	var wi := 0
	if it.slot == "weapon":
		wi = D.hero_weapons(who).find(String(it.key))
	var eq := 0 if P.equipped_by(int(it.id)) != "" else 1
	return [hi, si, wi, eq, -int(it.rarity), -int(it.level), int(it.id)]


static func sort_items(list: Array) -> Array:
	var out: Array = list.duplicate()
	out.sort_custom(func(a, b):
		var ka := sort_key(a)
		var kb := sort_key(b)
		for i in ka.size():
			if ka[i] != kb[i]:
				return ka[i] < kb[i]
		return false)
	return out


## Fasst gleiche Stücke (gleiche Art, Seltenheit, Stufe, nicht ausgerüstet) zu Stapeln zusammen.
static func stacks(sorted: Array) -> Array:
	var out: Array = []
	for it in sorted:
		var eq: bool = P.equipped_by(int(it.id)) != ""
		if out.size() > 0 and not eq:
			var last: Dictionary = out[out.size() - 1]
			var f: Dictionary = last.items[0]
			if not last.equipped and f.slot == it.slot and String(f.key) == String(it.key) and int(f.rarity) == int(it.rarity) and int(f.level) == int(it.level) and owner_of(f) == owner_of(it):
				last.items.append(it)
				continue
		out.append({"items": [it], "equipped": eq})
	return out


static func dps(it: Dictionary) -> float:
	if it.slot != "weapon":
		return 0.0
	var w: Dictionary = D.WEAPONS[it.key]
	return float(w.damage) * float(w.get("pellets", 1)) * P.weapon_mult(it) * (1.0 + P.item_mod(it, "damage")) * float(w.rpm) / 60.0 * (1.0 + P.item_mod(it, "rpm"))


func _can_upgrade(it: Dictionary) -> bool:
	return int(it.level) < P.item_cap(it) and P.can_pay(D.upgrade_cost(it))


func _can_merge(it: Dictionary) -> bool:
	return P.merge_candidates(int(it.id)).size() >= 2


func _todo(hero: String) -> bool:
	for it in P.d.items:
		var who := owner_of(it)
		if (who == hero or (hero == "free" and who == "")) and (_can_upgrade(it) or _can_merge(it)):
			return true
	return false


# ================================================================= Aufbau
func build() -> Control:
	var hero := String(S.st.hero)
	var sel: Dictionary = P.item(int(S.st.item))
	var row := UI.hbox(16)
	row.add_child(_hero_tabs(hero))
	var mid := UI.vbox(10)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_stretch_ratio = 1.5
	mid.add_child(_filters())
	var list := UI.vbox(8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shown: Array = []
	if String(S.st.slot) == "craft":
		for hk in D.HERO_ORDER:
			if (hero == "all" or hero == "free" or hero == hk) and P.hero_unlocked(hk):
				_craft_section(list, hk, hero == "all" or hero == "free")
	elif hero == "all":
		for hk in D.HERO_ORDER:
			if P.hero_unlocked(hk):
				_hero_sections(list, hk, shown, true)
		_free_section(list, shown, true)
	elif hero == "free":
		_free_section(list, shown, false)
	else:
		_hero_sections(list, hero, shown, false)
	if (sel.is_empty() or not shown.has(sel)) and String(S.st.get("craft", "")) == "":
		sel = shown[0] if shown.size() > 0 else {}
		S.st["item"] = int(sel.get("id", 0))
		# die Zeile der neuen Auswahl soll gleich golden sein
		if not sel.is_empty():
			S.refresh.call_deferred()
	if not sel.is_empty() and sel.get("new", false):
		sel["new"] = false
	mid.add_child(S.scroll(list, "ws_%s_%s" % [hero, String(S.st.slot)]))
	if S.st.get("multi", false):
		mid.add_child(_multi_bar())
	else:
		mid.add_child(UI.footer("%d Stücke" % shown.size(), TIP, 20))
	row.add_child(mid)
	var ck := String(S.st.get("craft", ""))
	var det: Control = _craft_detail(ck) if ck != "" and D.WEAPONS.has(ck) else _detail(sel)
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det.size_flags_stretch_ratio = 1.0
	row.add_child(det)
	return row


# ----------------------------------------------------------------- links: Helden-Reiter
func _hero_tabs(cur: String) -> Control:
	var v := UI.vbox(6)
	v.custom_minimum_size = Vector2(236, 0)
	v.add_child(_tab("all", "Alle", "ui_grid", UI.EDGE, cur == "all", "", false))
	for hk in D.HERO_ORDER:
		var def: Dictionary = D.HEROES[hk]
		var unlocked: bool = P.hero_unlocked(hk)
		v.add_child(_tab(hk, hk.capitalize(), "", def.color, cur == hk, "Stufe %d" % int(P.hero(hk).level) if unlocked else "gesperrt", not unlocked))
	v.add_child(_tab("free", "Frei", "ui_crate", FREE_COL, cur == "free", "ohne Träger", false))
	return v


func _tab(key: String, name: String, icon_name: String, col: Color, selected: bool, sub: String, locked: bool) -> Control:
	var stripe := ColorRect.new()
	stripe.color = col if not locked else Color(col, 0.35)
	stripe.custom_minimum_size = Vector2(8, 0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic: Control
	if icon_name != "":
		pic = UI.pic(icon_name, 50.0)
	elif locked:
		pic = UI.pic("ui_lock", 46.0, "", UI.GREY)
	else:
		pic = UI.hero_pic(key, 56.0)
	var nm := UI.label(name, 25, UI.WHITE if not locked else UI.GREY)
	var txt := UI.vbox(-4, [nm])
	if sub != "":
		txt.add_child(UI.sub_label(sub, 18, UI.TEXT, selected))
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.alignment = BoxContainer.ALIGNMENT_CENTER
	var content := UI.hbox(10, [stripe, pic, txt])
	if not locked and _todo(key):
		var dot := UI.rarity_dot(UI.RED, 16.0)
		dot.tooltip_text = "Hier lässt sich etwas verbessern oder verschmelzen"
		content.add_child(dot)
	var b: Button = S.card_button(selected, func():
		if locked:
			S.say("Diesen Helden hast du noch nicht befreit.")
			return
		S.st["hero"] = key
		S.st["item"] = 0
		S.st.erase("open")
		S.st.erase("craft")
		S._fresh_next = true
		S.refresh(), content, 70.0)
	b.custom_minimum_size = Vector2(236, 72)
	return b


# ----------------------------------------------------------------- Mitte: Filter
func _filters() -> Control:
	var f := UI.flow(8)
	var cur := String(S.st.slot)
	f.add_child(_chip("Alles", "ui_grid", cur == "", func(): S.st["slot"] = ""))
	for s in SLOTS:
		var sk: String = s
		f.add_child(_chip(String(SLOT_NAMES[s]) if s != "helmet" else "Helme", String(SLOT_ICONS[s]), cur == s, func(): S.st["slot"] = sk))
	f.add_child(_chip("Herstellen", "ui_hammer", cur == "craft", func():
		S.st["slot"] = "craft"
		S.st.erase("craft")))
	f.add_child(_chip("nur verbesserbar", "ui_up", S.st.get("only_up", false), func(): S.st["only_up"] = not S.st.get("only_up", false)))
	f.add_child(_chip("nur doppelte", "ui_merge", S.st.get("only_dup", false), func(): S.st["only_dup"] = not S.st.get("only_dup", false)))
	return f


func _chip(text: String, icon_name: String, on: bool, cb: Callable) -> Button:
	var b := UI.tab_button(text, icon_name, on, func():
		UI.sfx("ui_tab", "", -8.0)
		cb.call()
		S.refresh(), 20)
	return b


func _keep(it: Dictionary) -> bool:
	var slot := String(S.st.slot)
	if slot != "" and String(it.slot) != slot:
		return false
	if S.st.get("only_up", false) and not _can_upgrade(it):
		return false
	if S.st.get("only_dup", false) and P.merge_candidates(int(it.id)).size() < 1:
		return false
	return true


# ----------------------------------------------------------------- Mitte: Abschnitte
func _hero_sections(c: VBoxContainer, hk: String, shown: Array, with_head: bool) -> void:
	var def: Dictionary = D.HEROES[hk]
	var h: Dictionary = P.hero(hk)
	var mine: Array = []
	for it in P.d.items:
		if owner_of(it) == hk:
			mine.append(it)
	mine = sort_items(mine)
	if with_head:
		var hl := UI.label("%s · %s · Stufe %d" % [String(def.name), String(def.role), int(h.level)], 23)
		hl.clip_text = true
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var head := PanelContainer.new()
		head.add_theme_stylebox_override("panel", UI.grad(def.color.lightened(0.05), def.color.darkened(0.25), Color(0, 0, 0, 0), 12, 0, 8))
		head.add_child(UI.hbox(10, [UI.hero_pic(hk, 40.0), hl, UI.label("Kampfkraft %d" % P.hero_power(hk), 20, UI.WHITE, false)]))
		c.add_child(head)
	var slot_f := String(S.st.slot)
	# ---- Waffen in der Reihenfolge des Helden; fehlende Arten als Schatten
	if slot_f == "" or slot_f == "weapon":
		c.add_child(_section_head("weapon", def.color))
		var wkeys: Array = D.hero_weapons(hk)
		for wi in wkeys.size():
			var wk := String(wkeys[wi])
			var of_kind: Array = []
			for it in mine:
				if it.slot == "weapon" and String(it.key) == wk and _keep(it):
					of_kind.append(it)
			if of_kind.is_empty():
				if not S.st.get("only_up", false) and not S.st.get("only_dup", false):
					var has_any := false
					for it in mine:
						if it.slot == "weapon" and String(it.key) == wk:
							has_any = true
					if not has_any:
						c.add_child(_ghost_row(wk, D.weapon_level(wk), int(h.level), def.color))
				continue
			for st in stacks(of_kind):
				_stack_rows(c, st, def.color, shown)
	# ---- Ausrüstung, die dieser Held trägt
	for s in ["helmet", "vest", "charm"]:
		if slot_f != "" and slot_f != s:
			continue
		var got := false
		for it in mine:
			if String(it.slot) == s and _keep(it):
				if not got:
					c.add_child(_section_head(s, def.color))
					got = true
				_stack_rows(c, {"items": [it], "equipped": true}, def.color, shown)
		if not got and not with_head and not S.st.get("only_up", false) and not S.st.get("only_dup", false):
			c.add_child(_section_head(s, def.color))
			var why := "nichts ausgerüstet – unter „Frei“ findest du Stücke ohne Träger"
			if s == "charm" and int(h.level) < D.HERO_CHARM_LEVEL:
				why = "Platz ab Heldenstufe %d" % D.HERO_CHARM_LEVEL
			c.add_child(UI.label("   " + why, 19, UI.GREY, false))


func _free_section(c: VBoxContainer, shown: Array, with_head: bool) -> void:
	var free: Array = []
	for it in P.d.items:
		if owner_of(it) == "" and _keep(it):
			free.append(it)
	free = sort_items(free)
	if with_head and free.is_empty():
		return
	if with_head:
		var head := PanelContainer.new()
		head.add_theme_stylebox_override("panel", UI.grad(FREE_COL.lightened(0.05), FREE_COL.darkened(0.25), Color(0, 0, 0, 0), 12, 0, 8))
		head.add_child(UI.hbox(10, [UI.pic("ui_crate", 40.0), UI.label("Frei · Ausrüstung ohne Träger", 23)]))
		c.add_child(head)
	if free.is_empty():
		c.add_child(UI.info_box("Hier liegt Ausrüstung, die gerade niemand trägt. Im Moment ist nichts da.", 21))
		return
	var last_slot := ""
	for st in stacks(free):
		var s := String(st.items[0].slot)
		if s != last_slot:
			last_slot = s
			c.add_child(_section_head(s, FREE_COL))
		_stack_rows(c, st, FREE_COL, shown)


func _section_head(slot: String, col: Color) -> Control:
	var line := ColorRect.new()
	line.color = Color(col, 0.6)
	line.custom_minimum_size = Vector2(0, 3)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return UI.hbox(10, [UI.pic(String(SLOT_ICONS[slot]), 30.0, "", UI.GOLD), UI.label(String(SLOT_NAMES[slot]).to_upper(), 20, UI.GOLD), line])


## Eine Waffenart, die der Held noch nicht besitzt: dunkler Schatten mit Hinweis (herstellbar: hell mit Kosten).
## Antippen zeigt rechts Beschreibung, Herkunft und – wenn möglich – den Knopf „Herstellen“.
func _ghost_row(wkey: String, need: int, level: int, col: Color) -> Control:
	var w: Dictionary = D.WEAPONS[wkey]
	var st := Arsenal.status(wkey)
	var ready := st == "craft"
	var pic := UI.pic("w_" + wkey, 84.0)
	if not ready:
		pic.modulate = Color(0.05, 0.08, 0.16, 0.85) if level < need else Color(0.32, 0.38, 0.55, 0.9)
	var why := Arsenal.hint(wkey)
	var why_col: Color = UI.ORANGE if level < need else (UI.GREEN if ready else UI.GREY)
	var why_l := UI.label(why, 18, why_col, false)
	why_l.clip_text = true
	var head := UI.hbox(8, [UI.label(String(w.name), 25, UI.WHITE if ready else UI.GREY), UI.label("Stufe %d" % need, 18, UI.GREY, false)])
	var txt := UI.vbox(-4, [head, UI.label("%s · %s" % [String(w.kind), String(D.WEAPON_GET_NAME[D.weapon_get(wkey)])], 19, UI.GREY, false), why_l])
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stripe := ColorRect.new()
	stripe.color = Color(col, 0.35)
	stripe.custom_minimum_size = Vector2(8, 0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UI.hbox(12, [stripe, pic, txt])
	if ready:
		var cr := UI.cost_row(D.craft_cost(wkey), 18)
		row.add_child(UI.vbox(2, [UI.badge("herstellbar", Color("2F8D4E"), 16), cr]))
	elif st == "craft_level":
		row.add_child(UI.badge("Bauplan", Color("2F6DB8"), 16))
	else:
		row.add_child(UI.pic("ui_lock", 36.0, "", UI.GREY))
	var b: Button = S.card_button(String(S.st.get("craft", "")) == wkey, func():
		S.st["craft"] = wkey
		S.st["item"] = 0
		S.refresh(), row, 96.0)
	return b


## Reiter „Herstellen“: alle Waffen eines Helden, die sich herstellen lassen (Bauplan vorhanden oder nicht).
func _craft_section(c: VBoxContainer, hk: String, with_head: bool) -> void:
	var def: Dictionary = D.HEROES[hk]
	var h: Dictionary = P.hero(hk)
	if with_head:
		var head := PanelContainer.new()
		head.add_theme_stylebox_override("panel", UI.grad(def.color.lightened(0.05), def.color.darkened(0.25), Color(0, 0, 0, 0), 12, 0, 8))
		head.add_child(UI.hbox(10, [UI.hero_pic(hk, 40.0), UI.label("%s · Stufe %d" % [String(def.name), int(h.level)], 23)]))
		c.add_child(head)
	var n_bp := 0
	var n := 0
	for wk in D.hero_weapons(hk):
		var g := D.weapon_get(wk)
		if g != "craft" and g != "both":
			continue
		n += 1
		if Arsenal.has_blueprint(wk):
			n_bp += 1
		if Arsenal.owned(wk):
			var w: Dictionary = D.WEAPONS[wk]
			var done := UI.hbox(12, [UI.pic("w_" + wk, 64.0), UI.label(String(w.name), 22, UI.WHITE), UI.spacer(true), UI.badge("im Besitz", Color("2F8D4E"), 16)])
			var bt: Button = S.card_button(String(S.st.get("craft", "")) == wk, func():
				S.st["craft"] = wk
				S.st["item"] = 0
				S.refresh(), done, 72.0)
			c.add_child(bt)
		else:
			c.add_child(_ghost_row(wk, D.weapon_level(wk), int(h.level), def.color))
	c.add_child(UI.label("   %d von %d Bauplänen gefunden" % [n_bp, n], 19, UI.GREY, false))


## Rechte Seite für eine (noch) nicht besessene Waffe: Bild, Werte, Beschreibung, Herkunft, Herstellen.
func _craft_detail(wkey: String) -> Control:
	var w: Dictionary = D.WEAPONS[wkey]
	var hk := String(w.hero)
	var col: Color = D.HEROES[hk].color
	var v := UI.vbox(10)
	var card := UI.panel(v, UI.NAVY, UI.EDGE, 24, 18)
	card.custom_minimum_size = Vector2(600, 0)
	var hl := UI.label("Waffe von %s" % String(D.HEROES[hk].name), 24)
	hl.clip_text = true
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", UI.grad(col.lightened(0.08), col.darkened(0.28), Color(0, 0, 0, 0), 14, 0, 10))
	head.add_child(UI.hbox(12, [UI.hero_pic(hk, 44.0), hl, UI.label("Stufe %d" % int(P.hero(hk).level), 20, UI.WHITE, false)]))
	v.add_child(head)
	var visual: Control = S.preview_hero_with(hk, wkey)
	visual.custom_minimum_size = Vector2(230, 290)
	visual.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var info := UI.vbox(5)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UI.label(String(w.name), 32 if String(w.name).length() <= 16 else 25)
	nm.add_theme_constant_override("outline_size", 8)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(nm)
	info.add_child(UI.hbox(8, [UI.badge(String(w.kind), col.darkened(0.3), 18), UI.label(String(D.WEAPON_MODE_NAME.get(String(w.mode), "")), 19, UI.TEXT, false)]))
	info.add_child(UI.label("Ab Heldenstufe %d" % D.weapon_level(wkey), 21, UI.GOLD if int(P.hero(hk).level) >= D.weapon_level(wkey) else UI.ORANGE))
	var dp := D.weapon_power(wkey)
	if dp >= 0.0:
		info.add_child(_cmp("ui_sword", "Kampfwert", dp, -1.0, ""))
	info.add_child(_cmp("ui_target", "Reichweite", float(w.range), -1.0, " m"))
	v.add_child(UI.hbox(14, [visual, info]))
	var tx := UI.label(D.weapon_text(wkey), 21, UI.TEXT, false)
	tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tx)
	var sp := UI.label("Besonderheit: " + D.weapon_special(wkey), 21, Color("FFE9A0"), false)
	sp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sp)
	v.add_child(UI.sep())
	var st := Arsenal.status(wkey)
	if st == "owned":
		v.add_child(UI.card(UI.hbox(10, [UI.pic("ui_check", 34.0, "", UI.GREEN), UI.label("Im Besitz – unter „Waffen“ ausrüsten", 22, UI.GREEN)]), Color("14356B"), 9))
		return card
	var g := D.weapon_get(wkey)
	if g == "craft" or g == "both":
		var cost := D.craft_cost(wkey)
		var cl := UI.label("Herstellen", 30)
		cl.add_theme_constant_override("outline_size", 8)
		cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cr := UI.cost_row(cost, 24)
		var go: Button = UI.row_button(false, S.act(func():
			var it: Dictionary = Arsenal.craft(wkey)
			if not it.is_empty():
				S.st.erase("craft")
				S.st["item"] = int(it.id)
				S.st["slot"] = ""
				S.st["bump"] = true
			else:
				UI.sfx("ui_error", "error", -6.0)), UI.hbox(12, [cl, cr]), 84.0, "green")
		UI.disable(go, not Arsenal.can_craft(wkey))
		v.add_child(go)
	var hint := UI.info_box(Arsenal.hint(wkey), 20, "ui_map" if st != "craft" else "ui_hammer")
	v.add_child(hint)
	return card


func _sig(st: Dictionary) -> String:
	var f: Dictionary = st.items[0]
	return "%s|%s|%d|%d|%s" % [String(f.slot), String(f.key), int(f.rarity), int(f.level), owner_of(f)]


func _stack_rows(c: VBoxContainer, st: Dictionary, col: Color, shown: Array) -> void:
	var items: Array = st.items
	var n := items.size()
	var open: bool = n > 1 and String(S.st.get("open", "")) == _sig(st)
	var sel_id := int(S.st.item)
	var head_it: Dictionary = items[0]
	# im zugeklappten Stapel steht das ausgewählte Stück vorn
	for it in items:
		shown.append(it)
		if int(it.id) == sel_id and not open:
			head_it = it
	c.add_child(_item_row(head_it, col, n, st, false))
	if open:
		for it in items:
			c.add_child(UI.margin(_item_row(it, col, 1, st, true), 44, 0, 0, 0))


func _item_row(it: Dictionary, col: Color, count: int, st: Dictionary, child: bool) -> Control:
	var id := int(it.id)
	var r := int(it.rarity)
	var rc: Color = S.rarity_color(r)
	var selected: bool = id == int(S.st.item) and (child or count == 1 or String(S.st.get("open", "")) != _sig(st))
	var stripe := ColorRect.new()
	stripe.color = col
	stripe.custom_minimum_size = Vector2(8, 0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Bild im Rahmen der Seltenheitsfarbe
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UI.box(Color(rc.darkened(0.6), 0.9), rc, 14, 3, 4))
	frame.add_child(UI.item_pic(it, 64.0 if child else 84.0))
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nm := UI.label(P.item_name(it), 23 if child else 26)
	nm.clip_text = true
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := UI.hbox(8, [nm])
	if count > 1:
		title.add_child(UI.badge("× %d" % count, Color("2F6DB8"), 20))
	var kind := UI.sub_label("%s · %s" % [S.slot_name(it), String(D.RARITY[r].name)], 19, UI.TEXT, selected)
	kind.clip_text = true
	var lv := UI.hbox(8, [UI.sub_label("Stufe %d" % int(it.level), 19, UI.TEXT, selected), UI.pips(int(it.level), D.ITEM_LEVEL_CAP, rc if r > 0 else UI.SKY, 11.0)])
	var txt := UI.vbox(-3, [title, kind, lv])
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.alignment = BoxContainer.ALIGNMENT_CENTER
	var row := UI.hbox(12, [stripe, frame, txt])
	# Kampfkraft-Zahl
	var power := UI.vbox(-4)
	power.alignment = BoxContainer.ALIGNMENT_CENTER
	if it.slot == "weapon":
		power.add_child(UI.label(str(int(round(dps(it)))), 26, UI.GOLD))
		power.add_child(UI.sub_label("Schaden/s", 16, UI.TEXT, selected))
	else:
		power.add_child(UI.label("+%d %%" % int(round(P.gear_value(it) * 100.0)), 24, UI.GOLD))
	row.add_child(power)
	# Marken
	var marks := UI.vbox(2)
	marks.alignment = BoxContainer.ALIGNMENT_CENTER
	if P.equipped_by(id) != "":
		marks.add_child(UI.badge("ausgerüstet", Color("2F8D4E"), 16))
	if it.get("new", false):
		marks.add_child(UI.new_tag(16))
	var any_merge := false
	var any_up := false
	for o in (st.items if not child else [it]):
		any_merge = any_merge or _can_merge(o)
		any_up = any_up or _can_upgrade(o)
	if any_merge:
		marks.add_child(UI.badge("verschmelzbar", Color("7A48C8"), 16))
	if any_up:
		marks.add_child(UI.badge("verbesserbar", Color("2F6DB8"), 16))
	if marks.get_child_count() > 0:
		row.add_child(marks)
	if S.st.get("multi", false):
		var on: bool = (S.st.get("marks", {}) as Dictionary).has(id)
		row.add_child(UI.pic("ui_check" if on else "ui_close", 40.0, "", UI.GREEN if on else Color(1, 1, 1, 0.25)))
	var sig := _sig(st)
	return S.card_button(selected, func():
		if S.st.get("multi", false):
			_toggle_mark(it, st, child)
		else:
			S.st["item"] = id
			S.st.erase("craft")
			if count > 1:
				# Stapel auf- und zuklappen
				S.st["open"] = "" if String(S.st.get("open", "")) == sig else sig
		S.refresh(), row, 84.0 if child else 104.0)


# ----------------------------------------------------------------- mehrere zerlegen
func _toggle_mark(it: Dictionary, st: Dictionary, child: bool) -> void:
	var marks: Dictionary = S.st.get("marks", {})
	var list: Array = [it] if child else st.items
	var all_on := true
	for o in list:
		if not marks.has(int(o.id)) and _can_dismantle(o):
			all_on = false
	for o in list:
		if all_on:
			marks.erase(int(o.id))
		elif _can_dismantle(o):
			marks[int(o.id)] = true
	S.st["marks"] = marks


func _can_dismantle(it: Dictionary) -> bool:
	if P.equipped_by(int(it.id)) != "":
		return false
	if it.slot == "weapon":
		# das letzte Stück einer Waffenart bleibt immer erhalten
		var left := 0
		var marks: Dictionary = S.st.get("marks", {})
		for o in P.d.items:
			if o.slot == "weapon" and String(o.key) == String(it.key) and not marks.has(int(o.id)) and int(o.id) != int(it.id):
				left += 1
		return left >= 1
	return true


func _multi_bar() -> Control:
	var marks: Dictionary = S.st.get("marks", {})
	var parts := 0
	for id in marks:
		var it: Dictionary = P.item(int(id))
		if not it.is_empty():
			parts += D.dismantle_parts(it)
	var go := UI.button("Auswahl zerlegen (+%d Bauteile)" % parts, func():
		S.confirm("%d Stücke zerlegen? Du bekommst %d Bauteile." % [marks.size(), parts], func():
			var got := 0
			for id in marks.keys():
				got += P.dismantle(int(id))
			S.st["marks"] = {}
			S.st["multi"] = false
			UI.sfx("ui_dismantle", "build", -4.0)
			S.toast("+%d Bauteile" % got), "Zerlegen"), "red", 24, "ui_recycle")
	go.custom_minimum_size = Vector2(0, 70)
	UI.disable(go, marks.is_empty())
	var cancel := UI.button("Abbrechen", S.act(func():
		S.st["multi"] = false
		S.st["marks"] = {}), "dark", 24)
	cancel.custom_minimum_size = Vector2(0, 70)
	var l := UI.label("%d ausgewählt – tippe Stücke an" % marks.size(), 21, UI.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return UI.hbox(12, [l, cancel, go])


# ================================================================= rechts: Einzelheiten
func _detail(it: Dictionary) -> Control:
	var v := UI.vbox(10)
	var card := UI.panel(v, UI.NAVY, UI.EDGE, 24, 18)
	card.custom_minimum_size = Vector2(600, 0)
	if it.is_empty():
		v.add_child(UI.info_box("Wähle links ein Stück aus. Waffen und Ausrüstung findest du in Beutekisten.", 22))
		return card
	var id := int(it.id)
	var r := int(it.rarity)
	var rc: Color = S.rarity_color(r)
	var max_lv := int(D.RARITY[r].max_level)
	var who: String = P.equipped_by(id)
	var owner := owner_of(it)
	var tab_hero := String(S.st.hero)
	var col: Color = D.HEROES[owner].color if owner != "" else FREE_COL
	# ---- Kopfzeile in Heldenfarbe: wem gehört das Stück?
	var head_text := "Ohne Träger"
	if it.slot == "weapon":
		head_text = "Waffe von %s" % String(D.HEROES[owner].name)
	elif who != "":
		head_text = "%s – getragen von %s" % [String(D.GEAR[it.slot].name), String(D.HEROES[who].name)]
	var hl := UI.label(head_text, 24)
	hl.clip_text = true
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", UI.grad(col.lightened(0.08), col.darkened(0.28), Color(0, 0, 0, 0), 14, 0, 10))
	var hrow := UI.hbox(12, [UI.hero_pic(owner, 44.0) if owner != "" else UI.pic("ui_crate", 40.0), hl])
	if owner != "":
		hrow.add_child(UI.label("Stufe %d" % int(P.hero(owner).level), 20, UI.WHITE, false))
	head.add_child(hrow)
	v.add_child(head)
	# ---- Bild: der Held hält die Waffe; Ausrüstung auf dem Sockel
	var visual: Control
	if it.slot == "weapon":
		visual = S.preview_hero_with(owner, String(it.key))
		visual.custom_minimum_size = Vector2(230, 290)
	else:
		visual = UI.pedestal(UI.item_pic(it, 190.0), 220.0)
	visual.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if S.st.get("bump", false):
		S.st.erase("bump")
		UI.pulse(visual, 1.08)
	var info := UI.vbox(5)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var full_name: String = P.item_name(it)
	var nm := UI.label(full_name, 34 if full_name.length() <= 14 else (28 if full_name.length() <= 22 else 23))
	nm.add_theme_constant_override("outline_size", 8)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(nm)
	info.add_child(UI.hbox(10, [UI.badge(String(D.RARITY[r].name), rc.darkened(0.3) if r > 0 else Color("5F7399"), 20), UI.label(S.slot_name(it), 21, UI.TEXT, false)]))
	var cap: int = P.item_cap(it)
	info.add_child(UI.label("Stufe %d / %d" % [int(it.level), max_lv], 24))
	info.add_child(UI.bar(float(it.level) / max_lv, D.C_BAR_BLUE if r == 0 else rc, Vector2(120, 16), "ws_lv_%d" % id))
	# ---- Werte mit Vergleich zum ausgerüsteten Stück
	var other := {}
	if it.slot == "weapon":
		other = P.item(int(P.hero(owner).weapon))
	elif tab_hero != "all" and tab_hero != "free":
		other = P.item(int(P.hero(tab_hero).gear[it.slot]))
	elif who != "":
		other = it
	if not other.is_empty() and int(other.id) == id:
		other = {}
	if it.slot == "weapon":
		var w: Dictionary = D.WEAPONS[it.key]
		info.add_child(_cmp("ui_sword", "Schaden pro Sekunde", dps(it), dps(other) if not other.is_empty() else -1.0, ""))
		var rg := float(w.range) * (1.0 + P.item_mod(it, "range"))
		var rg2 := -1.0
		if not other.is_empty():
			rg2 = float(D.WEAPONS[other.key].range) * (1.0 + P.item_mod(other, "range"))
		info.add_child(_cmp("ui_target", "Reichweite", rg, rg2, " m"))
		for m in it.mods:
			for md in D.WEAPON_MODS:
				if md.key == m.key:
					info.add_child(UI.label("+ " + (String(md.text) % int(round(float(m.val) * 100.0))).trim_prefix("+"), 19, Color("FFE9A0"), false))
		var spl := UI.label(D.weapon_special(String(it.key)), 18, Color("BFE3FF"), false)
		spl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(spl)
	else:
		var gv: float = P.gear_value(it) * 100.0
		info.add_child(_cmp("ui_star", String(D.GEAR[it.slot].text).replace("%d %%", "").replace("+", "").strip_edges().capitalize(), gv, P.gear_value(other) * 100.0 if not other.is_empty() else -1.0, " %"))
	var top := UI.hbox(14, [visual, info])
	v.add_child(top)
	v.add_child(UI.sep())
	# ---- Ausrüsten
	var target := owner if it.slot == "weapon" else (tab_hero if tab_hero != "all" and tab_hero != "free" else String(P.d.hero_sel))
	if who == "" or (it.slot != "weapon" and who != target):
		var tname := target.capitalize()
		var eb := UI.button("Ausrüsten: %s" % tname, S.act(func():
			if P.equip(target, id):
				UI.sfx("ui_equip", "click", -4.0)
				S.st["bump"] = true
				if G.main != null:
					G.main.reload_hero()
			else:
				UI.sfx("ui_error", "error", -6.0)), "", 26, "ui_check")
		eb.custom_minimum_size = Vector2(0, 74)
		var locked: bool = not P.hero_unlocked(target) or (it.slot == "charm" and int(P.hero(target).level) < D.HERO_CHARM_LEVEL)
		UI.disable(eb, locked)
		if it.slot == "charm" and int(P.hero(target).level) < D.HERO_CHARM_LEVEL:
			eb.tooltip_text = "Glücksbringer ab Heldenstufe %d" % D.HERO_CHARM_LEVEL
		v.add_child(eb)
	else:
		v.add_child(UI.card(UI.hbox(10, [UI.pic("ui_check", 34.0, "", UI.GREEN), UI.label("Ausgerüstet bei %s" % String(D.HEROES[who].name), 22, UI.GREEN)]), Color("14356B"), 9))
	# ---- Verbessern (die Höchststufe hängt an der Heldenstufe)
	if int(it.level) >= max_lv:
		var mb := UI.button("Höchststufe erreicht", Callable(), "dark", 26, "ui_check")
		UI.disable(mb)
		mb.custom_minimum_size = Vector2(0, 80)
		v.add_child(mb)
	elif int(it.level) >= cap:
		var hname := P.item_hero(it).capitalize()
		var lb := UI.button("%s braucht Stufe %d" % [hname, P.item_need_level(it)], Callable(), "dark", 24, "ui_lock")
		UI.disable(lb)
		lb.custom_minimum_size = Vector2(0, 80)
		lb.tooltip_text = "Die nächste Verbesserung braucht eine höhere Heldenstufe"
		v.add_child(lb)
	else:
		var cost: Dictionary = D.upgrade_cost(it)
		var ul := UI.label("Verbessern", 32)
		ul.add_theme_constant_override("outline_size", 8)
		ul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ul.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cr := UI.cost_row(cost, 26)
		cr.alignment = BoxContainer.ALIGNMENT_CENTER
		var cbox := PanelContainer.new()
		var cs := UI.box(Color(0.05, 0.25, 0.05, 0.55), Color(0, 0, 0, 0), 12)
		cs.content_margin_left = 14
		cs.content_margin_right = 14
		cbox.add_theme_stylebox_override("panel", cs)
		cbox.add_child(cr)
		cbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ub: Button = UI.row_button(false, S.act(func():
			if P.upgrade_item(id):
				UI.sfx("ui_upgrade", "upgrade", -4.0)
				S.st["bump"] = true
				if G.main != null and who != "":
					G.main.reload_hero()
			else:
				UI.sfx("ui_error", "error", -6.0)), UI.hbox(12, [ul, cbox]), 84.0, "green")
		v.add_child(ub)
		v.add_child(UI.label("Bis Stufe %d möglich (Heldenstufe %d)" % [cap, int(P.hero(P.item_hero(it)).level)], 18, UI.GREY, false))
	# ---- Verschmelzen und Zerlegen nebeneinander
	var two := UI.hbox(10)
	if r < 3:
		var cand: Array = P.merge_candidates(id)
		var have := mini(cand.size(), 2) + 1
		var mg := UI.button("Verschmelzen %d/3" % have, func():
			var nr := String(D.RARITY[r + 1].name)
			S.confirm("Drei Stücke „%s“ (%s) werden zu einem der Seltenheit „%s“. Die Stufe bleibt erhalten." % [P.item_name(it), String(D.RARITY[r].name), nr], func():
				var nw: Dictionary = P.merge(id)
				if not nw.is_empty():
					S.st["item"] = int(nw.id)
					S.st["bump"] = true
					UI.sfx("ui_merge", "upgrade", -2.0, 0.8)
					S.toast("Neu: %s (%s)" % [P.item_name(nw), String(D.RARITY[int(nw.rarity)].name)])
					if G.main != null:
						G.main.reload_hero(), "Verschmelzen"), "purple", 23, "ui_merge")
		mg.custom_minimum_size = Vector2(0, 74)
		mg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.disable(mg, cand.size() < 2)
		two.add_child(mg)
	var parts: int = D.dismantle_parts(it)
	var db := UI.button("Zerlegen +%d" % parts, func():
		var go := func():
			var got: int = P.dismantle(id)
			if got > 0:
				UI.sfx("ui_dismantle", "build", -4.0)
				S.toast("+%d Bauteile" % got)
		if r >= 1:
			S.confirm("„%s“ wirklich zerlegen? Du bekommst %d Bauteile." % [P.item_name(it), parts], go, "Zerlegen")
		else:
			go.call()
			S.refresh(), "red", 23, "ui_recycle")
	db.custom_minimum_size = Vector2(0, 74)
	db.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.disable(db, who != "")
	two.add_child(db)
	v.add_child(two)
	if not S.st.get("multi", false):
		var mb2 := UI.button("Mehrere zerlegen …", S.act(func():
			S.st["multi"] = true
			S.st["marks"] = {}), "dark", 21, "ui_recycle")
		mb2.custom_minimum_size = Vector2(0, 56)
		v.add_child(mb2)
	return card


## Wertzeile mit Vergleich: grün mit Pfeil nach oben = besser als das ausgerüstete Stück, rot = schlechter.
func _cmp(icon_name: String, name: String, val: float, other: float, unit: String) -> Control:
	var row := UI.hbox(8, [UI.pic(icon_name, 30.0, "", UI.GOLD), UI.label(name, 20, UI.TEXT, false), UI.spacer(true), UI.label("%d%s" % [int(round(val)), unit], 23, UI.GOLD)])
	if other >= 0.0:
		var d := int(round(val)) - int(round(other))
		if d != 0:
			var arrow := UI.pic("ui_up", 24.0, "", UI.GREEN if d > 0 else UI.RED)
			if d < 0:
				arrow.pivot_offset = Vector2(12, 12)
				arrow.scale = Vector2(1, -1)
			row.add_child(arrow)
			row.add_child(UI.label("%s%d" % ["+" if d > 0 else "−", absi(d)], 20, UI.GREEN if d > 0 else UI.RED))
		else:
			row.add_child(UI.label("=", 20, UI.GREY))
	return row
