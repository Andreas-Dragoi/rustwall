extends CanvasLayer
## Anzeige im Spiel, im Stil des Referenzbildes (dunkelblaue Tafeln, hellblauer Rand, goldene Zahlen).
## Friedensbetrieb: Rohstoffe, Wochenanzeige, Baumenü, Gebäude-Auswahl.
## Kampf (Flut, Übung, Expedition): Welle, Bunker- und Heldenleben, Aufgabe, Karte, Ergebnis.

const D = preload("res://src/data.gd")
const UI = preload("res://src/ui.gd")

var root: Control
var world: Node3D
var _peace: Control
var _battle: Control
var _res_labels := {}
var _lvl_label: Label
var _xp_bar: ProgressBar
var _week_label: Label
var _week_sub: Label
var _drone_label: Label
var _flood_btn: Button
var _chest_btn: Button
var _mail_btn: Button
var _quest_btn: Button
var _tip: Label
var _sel_box: Control
var _build_box: Control
var _edit_box: Control
var _modal: Control
var _toasts: VBoxContainer
var _flash: ColorRect
var _flash_a := 0.0
var _t := 0.0
var _build_cat := "def"
var _sel_timer: Label
var _sel_sig := ""
# Kampf
var _wave_label: Label
var _left_label: Label
var _bunker_bar: ProgressBar
var _hero_bar: ProgressBar
var _ammo_bar: ProgressBar
var _hero_label: Label
var _break_box: Control
var _break_label: Label
var _boss_box: Control
var _boss_bar: ProgressBar
var _boss_label: Label
var _obj_label: Label
var _pack_bar: ProgressBar
var _pack_label: Label
var _pack_box: HFlowContainer
var _pack_sig := ""
var _coin_label: Label
var _map: Control
var _veh_bar: ProgressBar
var _respawn_label: Label
var _hold_bar: ProgressBar
var _exp_title: Label               # Expedition: Gebiet · Phase
var _field_coins: Label
var _life_label: Label
var _quest_box: VBoxContainer
var _quest_sig := ""
var _home_btn: Button
var _arrow: Control
var _outpost_btn: Button
var _smooth := {}                  # Balken -> Zielwert (laufen im Kampf weich nach)
var _build_scroll := {}
var after_screen := ""
var _jobs_box: VBoxContainer
var _jobs_sig := ""
var _job_rows: Array = []           # [Label Zeit, ProgressBar, Auftrag]
var _all_btn: Button
var _warn: Control
var _fly: Control
var _xp_hero: ProgressBar
var _hero_lv: Label
var _gem_label: Label

const MENU_ICON := {"heroes": "ui_helmet", "chests": "ui_chest", "quests": "ui_quest", "workshop": "ui_hammer", "garage": "ui_garage",
	"social": "ui_mail", "clan": "ui_clan", "settings": "ui_gear", "begleiter": "comp_kistenbein"}
const CAT_ICON := {"def": "ui_target", "wall": "ui_shield", "trap": "ui_alarm", "prod": "ui_gear", "special": "ui_star", "deco": "ui_flag"}
const GLASS := Color(0.07, 0.19, 0.37, 0.94)


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	add_child(root)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 0.1, 0.1, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)
	_toasts = UI.vbox(8)
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.position = Vector2(-400, 132)
	_toasts.custom_minimum_size = Vector2(800, 0)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(_toasts)
	P.toast.connect(toast)
	P.resources_changed.connect(_update_res)
	P.level_up.connect(_level_banner)
	P.changed.connect(func(): _sel_sig = "")
	G.pause_pressed.connect(_on_pause)


func modal_open() -> bool:
	return _modal != null


func damage_flash() -> void:
	_flash_a = 0.3


func toast(text: String) -> void:
	if G.main != null and G.main.screens.is_open():
		return
	_push_toast(text, UI.EDGE, 28, "ui_info")
	UI.sfx("ui_toast", "", -10.0)


func _push_toast(text: String, border: Color, size: int, icon_name: String) -> void:
	if _toasts.get_child_count() >= 4:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var l := UI.label(text, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var p := UI.panel(UI.hbox(12, [UI.pic(icon_name, size * 1.4, "", UI.GOLD), l]), GLASS, border, 20, 12)
	UI.ignore_mouse(p)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toasts.add_child(p)
	UI.pulse(p, 1.08)
	var tw := p.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


## Großes goldenes Band beim Stufenaufstieg.
func _level_banner(level: int) -> void:
	UI.sfx("level_up", "upgrade", -4.0)
	if G.main != null and G.main.screens.is_open():
		return
	_push_toast("Stufe %d erreicht!" % level, UI.GOLD, 40, "ui_star")


# ---------------------------------------------------------------- Welt wechseln
func set_world(w: Node3D) -> void:
	world = w
	_close_modal()
	w.state_changed.connect(_rebuild)
	w.battle_ended.connect(_show_result)
	if w.has_signal("selection_changed"):
		w.selection_changed.connect(_update_selection)
	_rebuild()


func _rebuild() -> void:
	if _peace:
		_peace.queue_free()
		_peace = null
	if _battle:
		_battle.queue_free()
		_battle = null
	_sel_box = null
	_build_box = null
	_edit_box = null
	_res_labels.clear()
	_smooth.clear()
	_coin_label = null
	_map = null
	_veh_bar = null
	_sel_timer = null
	_jobs_box = null
	_jobs_sig = ""
	_job_rows.clear()
	_all_btn = null
	_warn = null
	_xp_hero = null
	_hero_lv = null
	if world == null:
		return
	if world.mode == "peace":
		_build_peace()
	else:
		_build_battle()
	root.move_child(_toasts, -1)


func _layer_root() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	root.move_child(c, 1)
	return c


func _anchor(c: Control, preset: int, offset: Vector2) -> void:
	# Das Element sitzt in einem bildschirmfüllenden Rand-Container und richtet sich darin aus.
	var parent := c.get_parent()
	parent.remove_child(c)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := Control.SIZE_SHRINK_CENTER
	var v := Control.SIZE_SHRINK_CENTER
	if preset in [Control.PRESET_TOP_LEFT, Control.PRESET_BOTTOM_LEFT]:
		h = Control.SIZE_SHRINK_BEGIN
	elif preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_RIGHT]:
		h = Control.SIZE_SHRINK_END
	if preset in [Control.PRESET_TOP_LEFT, Control.PRESET_TOP_RIGHT, Control.PRESET_CENTER_TOP]:
		v = Control.SIZE_SHRINK_BEGIN
	elif preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM]:
		v = Control.SIZE_SHRINK_END
	c.size_flags_horizontal = h
	c.size_flags_vertical = v
	m.add_theme_constant_override("margin_left", int(maxf(offset.x, 0.0)))
	m.add_theme_constant_override("margin_right", int(maxf(-offset.x, 0.0)))
	m.add_theme_constant_override("margin_top", int(maxf(offset.y, 0.0)))
	m.add_theme_constant_override("margin_bottom", int(maxf(-offset.y, 0.0)))
	m.add_child(c)
	parent.add_child(m)


# ================================================================= Friedensbetrieb
func _build_peace() -> void:
	_peace = _layer_root()
	_res_labels.clear()
	# ---- oben links: Spieler (Stufe im goldenen Kreis, Name, Erfahrung)
	_lvl_label = UI.label(str(int(P.d.level)), 36)
	_lvl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ring := PanelContainer.new()
	ring.add_theme_stylebox_override("panel", UI.gold_style(37, 0))
	ring.custom_minimum_size = Vector2(74, 74)
	ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ring.add_child(_lvl_label)
	_xp_bar = UI.bar(0.0, UI.GREEN, Vector2(230, 20))
	var name_l := UI.label(String(P.d.name), 28)
	name_l.clip_text = true
	name_l.custom_minimum_size = Vector2(230, 0)
	var pbtn := Button.new()
	pbtn.flat = true
	pbtn.focus_mode = Control.FOCUS_NONE
	pbtn.set_anchors_preset(Control.PRESET_FULL_RECT)
	pbtn.pressed.connect(func():
		Sfx.play("click", -8.0)
		_open("profile"))
	var pp := UI.panel(UI.hbox(14, [ring, UI.vbox(6, [name_l, _xp_bar])]), GLASS, UI.EDGE, 24, 12)
	pp.add_child(pbtn)
	# ---- Woche
	_week_label = UI.label("", 25)
	_week_sub = UI.gold("", 24)
	_drone_label = UI.label("", 21, UI.TEXT)
	var wk_top := UI.hbox(12, [UI.pic("ui_flood", 56.0), UI.vbox(0, [_week_label, _week_sub])])
	var wk := UI.panel(UI.vbox(6, [wk_top, UI.sep(false, Color(UI.EDGE, 0.4)), UI.hbox(10, [UI.icon("drone", 32, UI.SKY), _drone_label])]), GLASS, UI.EDGE, 24, 12)
	_jobs_box = UI.vbox(6)
	# ---- Tipp (unter der Liste der laufenden Bauten)
	_tip = UI.label("", 23, UI.TEXT)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(400, 0)
	var tp := UI.panel(UI.hbox(12, [UI.pic("ui_info", 40, "", UI.GOLD), _tip]), GLASS, Color(UI.EDGE, 0.8), 20, 12)
	UI.ignore_mouse(tp)
	# Außenbasen: Zahl der stehenden, Antippen zeigt alle wirksamen Vorteile
	var sieged := P.outpost_besieged() != ""
	_outpost_btn = UI.button("Außenbasen %d/%d%s" % [P.outpost_count(), D.AREAS.size(), " · belagert!" if sieged else ""], _show_outposts, "red" if sieged else "dark", 22, "ui_flag")
	_outpost_btn.custom_minimum_size = Vector2(0, 56)
	_outpost_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var left := UI.vbox(12, [pp, _outpost_btn, wk, _jobs_box, tp])
	_peace.add_child(left)
	_anchor(left, Control.PRESET_TOP_LEFT, Vector2(24, 24))
	# ---- oben Mitte: Rohstoffe mit Bildern
	var rh := UI.hbox(18)
	for r in ["coins", "wood", "stone", "metal", "fuel", "cells", "parts", "shards"]:
		if r in ["metal", "fuel", "cells", "shards"] and P.res(r) <= 0 and P.bunker_level() < 4:
			continue
		if r == "parts" and P.res(r) <= 0:
			continue
		var l := UI.gold("0", 26)
		_res_labels[r] = l
		var chip := UI.hbox(6, [UI.icon(r, 40), l])
		chip.tooltip_text = D.RES_NAME[r]
		rh.add_child(chip)
	# Juwelen mit Plus-Knopf (öffnet den Laden)
	_gem_label = UI.label("0", 26, Color("9FDCFF"))
	_res_labels["gems"] = _gem_label
	var plus := UI.button("+", func(): _open("shop"), "green", 24)
	plus.custom_minimum_size = Vector2(46, 44)
	plus.tooltip_text = "Juwelen-Laden"
	rh.add_child(UI.hbox(6, [UI.pic("res_gems", 40.0), _gem_label, plus]))
	var rp := UI.panel(rh, GLASS, UI.EDGE, 28, 8)
	(rp.get_theme_stylebox("panel") as StyleBox).content_margin_left = 20
	(rp.get_theme_stylebox("panel") as StyleBox).content_margin_right = 22
	_peace.add_child(rp)
	_anchor(rp, Control.PRESET_CENTER_TOP, Vector2(0, 24))
	# ---- rechts: Menü als Knöpfe mit Bild und Namen
	var col := UI.vbox(6)
	_quest_btn = _menu_btn("Aufträge", "quests", "")
	_chest_btn = _menu_btn("Kisten", "chests", "kistenlager")
	_mail_btn = _menu_btn("Funk", "social", "funkturm")
	col.add_child(_menu_btn("Helden", "heroes", "quartier"))
	col.add_child(_chest_btn)
	col.add_child(_quest_btn)
	col.add_child(_menu_btn("Werkstatt", "workshop", "werkstatt"))
	col.add_child(_menu_btn("Garage", "garage", "garage"))
	col.add_child(_menu_btn("Begleiter", "begleiter", ""))
	col.add_child(_mail_btn)
	col.add_child(_menu_btn("Clan", "clan", "clanhalle"))
	col.add_child(_menu_btn("Optionen", "settings", ""))
	_peace.add_child(col)
	_anchor(col, Control.PRESET_TOP_RIGHT, Vector2(-24, 24))
	# ---- unten: große Knöpfe mit Bild
	_flood_btn = UI.button("Übungsalarm", _ask_flood, "red", 34, "ui_alarm")
	_flood_btn.custom_minimum_size = Vector2(340, 96)
	var build := UI.button("Bauen", _toggle_build, "gold", 34, "ui_build")
	build.custom_minimum_size = Vector2(250, 96)
	var exp := UI.button("Expedition", func(): _open("expedition"), "green", 34, "ui_expedition")
	exp.custom_minimum_size = Vector2(320, 96)
	var bh := UI.hbox(16, [build, exp, _flood_btn])
	# "Alles einsammeln": erscheint ab Bunker 4, sobald drei Sammelblasen offen sind
	_all_btn = UI.button("Alles einsammeln", func():
		UI.sfx("ui_claim", "", -6.0)
		world.collect_all(), "gold", 26, "ui_crate")
	_all_btn.custom_minimum_size = Vector2(0, 70)
	_all_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_all_btn.visible = false
	# Warnung, wenn die Basis ohne Tor zugemauert ist
	_warn = UI.panel(UI.hbox(10, [UI.pic("ui_lock", 34.0, "", UI.RED), UI.label("Kein Ausgang – setze ein Tor (Mauer antippen → „Zu Tor machen“)", 22, UI.RED)]), GLASS, UI.RED, 18, 10)
	_warn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_warn.visible = false
	UI.ignore_mouse(_warn)
	var bv := UI.vbox(10, [_warn, _all_btn, bh])
	_peace.add_child(bv)
	_anchor(bv, Control.PRESET_BOTTOM_RIGHT, Vector2(-24, -24))
	_update_res()
	_update_peace()
	_update_selection()
	if world.editing():
		_show_edit_bar()
	if int(P.d.get("guide", 0)) == 0 and G.autotest == "" and not G.selftest and G.shots_dir == "":
		_welcome()


## Liste aller wirksamen Vorteile der Außenbasen (mit Zahlenwert).
func _show_outposts() -> void:
	Sfx.play("click", -8.0)
	var v := UI.vbox(10)
	v.custom_minimum_size = Vector2(760, 0)
	var t := UI.label("Außenbasen %d/%d" % [P.outpost_count(), D.AREAS.size()], 44, UI.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var list: Array = P.outpost_overview()
	if list.is_empty():
		v.add_child(UI.info_box("Noch keine Außenbasis. Baue auf einer Expedition alle Pflichtplätze und überstehe den Großangriff.", 22, "ui_expedition"))
	for o in list:
		var ak := String(D.AREAS[int(o.area)].key)
		var lines := UI.vbox(0)
		lines.add_child(UI.label("%s – %s (Stufe %d)%s" % [String(D.AREAS[int(o.area)].name), String(o.special), int(o.level), " · BELAGERT, Vorteil ruht" if o.siege else ""], 24, UI.RED if o.siege else UI.WHITE))
		for l in o.lines:
			lines.add_child(UI.label(String(l), 21, UI.GREY if o.siege else UI.GOLD, false))
		v.add_child(UI.card(UI.hbox(14, [UI.pic("o_special_%s%s" % [ak, "" if int(o.level) >= 5 else "_1"], 72.0, "ui_flag"), lines]), UI.NAVY_L, 10))
	var common := "Für alle: Rucksack +%d %% · Auto-Expeditionen dorthin +%d %%" % [int(minf(D.OUTPOST_PACK_MAX, D.OUTPOST_PACK_BONUS * P.outpost_count()) * 100.0), int(D.OUTPOST_AUTO_BONUS * 100.0)]
	v.add_child(UI.label(common, 21, UI.TEXT, false))
	if P.outpost_talbund():
		v.add_child(UI.label("Titel „Talbund“: Belohnung der Flut +%d %%" % int(D.OUTPOST_TALBUND_FLOOD * 100.0), 23, UI.GREEN))
	var ok := UI.button("Schließen", _close_modal, "green", 30, "ui_check")
	ok.custom_minimum_size = Vector2(300, 96)
	var hb := UI.hbox(10, [ok])
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(hb)
	_show_modal(v, 0.5)


func _welcome() -> void:
	P.d.guide = 1
	P.mark()
	var v := UI.vbox(14)
	var t := UI.label("Willkommen in Rustwall!", 50, UI.GOLD)
	t.add_theme_constant_override("outline_size", 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var story := UI.text("Seit dem großen Regen hüpfen überall Schleimlinge durchs Tal. Du bist der neue Kommandant dieses Bunkers. Baue deine Basis aus, schicke deine Helden auf Expeditionen – und sei bereit: An jedem siebten Tag kommt die Flut!", 26, UI.WHITE, 640)
	v.add_child(UI.hbox(20, [UI.pedestal(UI.hero_pic(String(P.d.hero_sel), 200.0), 220.0), story]))
	var help := "Bewegen: WASD oder Pfeiltasten · Zielen: automatisch (linke Maustaste zielt selbst)\nFähigkeiten: Q, E, R · Kommandant: F · Ausweichen: Leertaste · Fahrzeug: T"
	if G.is_touch:
		help = "Bewegen: linker Daumen · Fähigkeiten: Knöpfe rechts unten\nGebäude antippen, um sie zu verbessern oder zu verschieben."
	v.add_child(UI.info_box(help, 22))
	var go := UI.button("Los geht’s!", _close_modal, "green", 36, "ui_play")
	go.custom_minimum_size = Vector2(340, 92)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(go)
	_show_modal(v)


func _menu_btn(text: String, screen: String, need: String) -> Button:
	var locked: bool = need != "" and not P.has_built(need)
	var b := UI.button(text, func():
		if need != "" and not P.has_built(need):
			toast("Baue zuerst: %s" % D.BUILDINGS[need].name)
			UI.sfx("ui_error", "error", -6.0)
		else:
			_open(screen), "dark", 25, "ui_lock" if locked else String(MENU_ICON.get(screen, "ui_star")))
	b.custom_minimum_size = Vector2(236, 62)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var m: Control = b.get_meta("content")
	(m.get_child(0) as BoxContainer).alignment = BoxContainer.ALIGNMENT_BEGIN
	m.add_theme_constant_override("margin_left", 16)
	if locked:
		m.modulate = Color(0.75, 0.82, 0.95, 0.65)
	return b


func _open(screen: String, arg = null) -> void:
	if world != null and world.mode == "peace":
		world.cancel_edit()
	_close_build()
	G.main.screens.open(screen, arg)


func _update_res() -> void:
	for r in _res_labels:
		var l: Label = _res_labels[r]
		if not is_instance_valid(l):
			continue
		var v := P.res(r)
		l.text = UI.fmt(v)
		if r == "gems":
			continue
		l.add_theme_color_override("font_color", UI.RED if D.CAP_BASE.has(r) and v >= P.cap(r) else UI.GOLD)
		l.get_parent().tooltip_text = "%s: %d / %d" % [D.RES_NAME[r], v, P.cap(r)]
	if _coin_label != null and is_instance_valid(_coin_label):
		_coin_label.text = UI.fmt(P.res("coins"))


func _tip_text() -> String:
	if world != null and world.enclosed:
		return "Deine Basis ist zugemauert. Tippe ein Mauerstück an und wähle „Zu Tor machen“."
	if P.has_pickup("daily"):
		return "Am Bunker liegt dein tägliches Geschenk. Lauf hin oder tippe die Blase an."
	if P.chest_count() > 0:
		return "Du hast eine Beutekiste! Öffne sie unter „Kisten“."
	if P.count("saege") == 0:
		return "Baue ein Sägewerk, damit Holz nachwächst (Bauen → Produktion)."
	if P.count("mg") == 0:
		return "Baue einen MG-Turm in die Nähe des Bunkers (Bauen → Verteidigung)."
	if int(P.d.stats.expeditions) == 0:
		return "Starte eine Expedition ins Grüntal und sammle Rohstoffe."
	if P.count("wall") < 8:
		return "Mauern lenken die Schleimlinge. Zieh mit der Maus oder tippe, um mehrere zu setzen."
	if P.flood_available():
		return "Heute kommt die Flut! Starte sie, wenn du bereit bist."
	if P.practice_available():
		return "Teste deine Basis mit dem Übungsalarm – ohne Risiko."
	if P.count("lager") == 0:
		return "Ein Lager erhöht, wie viele Rohstoffe du aufbewahren kannst."
	if P.can_upgrade(int(P.bunker().id)) == "":
		return "Du kannst den Bunker ausbauen: Tippe ihn an → Verbessern."
	return "Tippe ein Gebäude an, um es zu verbessern oder zu verschieben."


func _update_peace() -> void:
	if _peace == null:
		return
	_lvl_label.text = str(int(P.d.level))
	_smooth[_xp_bar] = float(P.d.xp) / maxf(1.0, D.xp_need(int(P.d.level)))
	var day := P.week_day()
	_week_label.text = "Woche %d · Tag %d von 7" % [int(P.d.week.number), day]
	if P.flood_available():
		_week_sub.text = "Die Flut ist da! Noch %s" % UI.time_text(P.flood_seconds_left())
		_week_sub.add_theme_color_override("font_color", UI.RED)
		UI.btn_text(_flood_btn, "FLUT STARTEN")
		_flood_btn.disabled = false
		_flood_btn.modulate = Color(1, 1, 1).lerp(Color(1.4, 1.1, 1.1), 0.5 + 0.5 * sin(_t * 5.0))
	else:
		_week_sub.add_theme_color_override("font_color", UI.GOLD)
		if bool(P.d.week.flood_done):
			_week_sub.text = "Flut überstanden · neue Woche in %s" % UI.time_text(P.seconds_to_next_day())
		else:
			_week_sub.text = "Flut in %s" % UI.time_text(P.flood_seconds_left())
		UI.btn_text(_flood_btn, "Übungsalarm")
		UI.disable(_flood_btn, not P.practice_available())
		_flood_btn.modulate = Color.WHITE
	_drone_label.text = "Baudrohnen frei: %d von %d" % [maxi(0, P.drones_total() - P.drones_busy()), P.drones_total()]
	_update_jobs()
	_all_btn.visible = world.bubbles_open >= 3 and P.bunker_level() >= 4 and not world.editing() and _build_box == null
	_warn.visible = world.enclosed and _build_box == null
	var cc := P.chest_count()
	UI.btn_text(_chest_btn, "Kisten (%d)" % cc if cc > 0 else "Kisten")
	UI.btn_kind(_chest_btn, "gold" if cc > 0 else "dark")
	var mc: int = P.social.mail_count()
	UI.btn_text(_mail_btn, "Funk (%d)" % mc if mc > 0 else "Funk")
	UI.btn_kind(_mail_btn, "gold" if mc > 0 else "dark")
	UI.btn_kind(_quest_btn, "green" if P.quests_done() and not bool(P.d.quests.claimed) else "dark")
	_tip.text = _tip_text()
	if _sel_timer != null and is_instance_valid(_sel_timer):
		var b: Dictionary = world.selected()
		if not b.is_empty() and P.is_building(b):
			_sel_timer.text = "Fertig in %s" % UI.time_text((float(b.done_at) - P.now()))
	var b2: Dictionary = world.selected()
	var sg := ""
	if not b2.is_empty():
		sg = _sig_of(b2)
	if sg != _sel_sig:
		_update_selection()


# ---------------------------------------------------------------- Gebäude-Auswahl
func _update_selection() -> void:
	if _peace == null:
		return
	if _sel_box:
		_sel_box.get_parent().queue_free()
		_sel_box = null
		_sel_timer = null
	var b: Dictionary = world.selected()
	_sel_sig = ""
	if b.is_empty() or world.editing():
		return
	var id := int(b.id)
	_sel_sig = _sig_of(b)
	_sel_box = _sel_window(b)
	_peace.add_child(_sel_box)
	_anchor(_sel_box, Control.PRESET_BOTTOM_LEFT, Vector2(24, -24))
	if _build_box:
		_sel_box.visible = false


## Fenster zum ausgewählten Gebäude: Bild, Stufe, Werte, Ausbaukosten und Knöpfe.
func _sel_window(b: Dictionary) -> Control:
	var id := int(b.id)
	var key := String(b.key)
	var def: Dictionary = D.BUILDINGS[key]
	var lv := int(b.level)
	var busy: bool = P.is_building(b)
	var v := UI.vbox(10)
	v.custom_minimum_size = Vector2(700, 0)
	# ---- Kopf: Bild auf dem Sockel, Name, Stufe, Beschreibung
	var name_text := String(def.name)
	if key == "wall":
		name_text = String(D.WALL_TIERS[clampi(lv - 1, 0, 2)].name)
	elif key == "tor":
		name_text = ["Holztor", "Steintor", "Metalltor"][clampi(lv - 1, 0, 2)]
	var nm := UI.label(name_text, 38)
	nm.add_theme_constant_override("outline_size", 10)
	var title := UI.hbox(14, [nm])
	if def.cat != "wall" and def.cat != "obstacle" and def.cat != "deco":
		title.add_child(UI.badge("Stufe %d" % lv, Color("2F8DEB"), 23))
	title.add_child(UI.spacer(true))
	var x := UI.button("", func(): world.select(-1), "red", 22, "ui_close")
	x.custom_minimum_size = Vector2(64, 58)
	x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	title.add_child(x)
	var head_txt := UI.vbox(6, [title, UI.text(String(def.desc), 22, UI.TEXT, 420)])
	head_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UI.hbox(18, [UI.pedestal(UI.building_pic(key, 170.0, lv), 180.0), head_txt]))
	# ---- Werte
	var stats := UI.vbox(8)
	if def.has("prod"):
		var res := String(def.prod)
		var rate := int(P.prod_rate(b))
		var stored: int = P.prod_stored(b)
		var cap := maxi(1, int(round(float(rate) * D.PROD_STORE_HOURS)))
		stats.add_child(UI.stat_row("res_" + res, "%s pro Stunde" % String(D.RES_NAME[res]), "+%d" % rate, 24))
		var sb := UI.bar(float(stored) / cap, UI.GOLD, Vector2(180, 22), "sel_store_%d" % id)
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		stats.add_child(UI.hbox(14, [UI.pic("ui_crate", 36.0), UI.label("Im Speicher", 24), sb, UI.label("%s / %s" % [UI.fmt(stored), UI.fmt(cap)], 24, UI.GOLD)]))
	if def.has("tower"):
		var t: Dictionary = D.TOWERS[def.tower]
		var dps: float = float(t.damage) * float(t.rpm) / 60.0 * pow(D.TOWER_DMG_GROWTH, lv - 1)
		stats.add_child(UI.stat_row("ui_sword", "Schaden pro Sekunde", str(int(dps)), 24))
		stats.add_child(UI.stat_row("ui_target", "Reichweite", "%d m" % int(t.range), 24))
	if float(def.get("hp", 0.0)) > 0.0 and key != "bunker":
		var hp := float(def.hp) * pow(1.18, lv - 1)
		if def.cat == "wall":
			hp = float(def.hp) * float(D.WALL_TIERS[clampi(lv - 1, 0, 2)].hp) * (1.0 + P.cmd_bonus("wall_hp")) * (1.0 + P.outpost_bonus("wall_hp"))
		stats.add_child(UI.stat_row("ui_heart", "Haltbarkeit", str(int(round(hp))), 24))
	if key == "tor":
		stats.add_child(UI.hbox(14, [UI.pic("ui_info", 34.0, "", UI.GOLD), UI.text("Öffnet sich für dich, deine Fahrzeuge und Bewohner. Gegner müssen es einreißen.", 21, UI.TEXT, 520)]))
	if def.cat == "obstacle":
		var gm: Array = def.gems
		stats.add_child(UI.stat_row("res_gems", "Wegräumen bringt", "%d–%d Juwelen" % [int(gm[0]), int(gm[1])], 24, Color("9FDCFF")))
	if key == "training":
		stats.add_child(UI.stat_row("ui_star", "Erfahrung pro Stunde", "+%d" % int(P.train_rate()), 24))
	if key == "bunker":
		stats.add_child(UI.stat_row("ui_heart", "Haltbarkeit", str(int(D.bunker_hp(lv))), 24))
		var dprice := P.drone_price()
		var drow := UI.stat_row("ui_drone", "Baudrohnen", str(P.drones_total()), 24)
		if dprice > 0:
			var db := UI.button("+1 für %d" % dprice, func(): _buy_drone(dprice), "dark", 21, "res_gems")
			db.custom_minimum_size = Vector2(0, 52)
			drow.add_child(db)
		stats.add_child(drow)
		if lv < 10:
			stats.add_child(UI.hbox(14, [UI.pic("ui_lock", 36.0, "", UI.GOLD), UI.text("Stufe %d schaltet frei: %s" % [lv + 1, D.BUNKER_UNLOCK_TEXT[lv]], 21, UI.GOLD)]))
	if stats.get_child_count() > 0:
		v.add_child(UI.card(stats, UI.NAVY, 14, Color(UI.EDGE, 0.7)))
	# ---- Bauzeit oder Ausbau
	var btns := UI.hbox(10)
	if key == "training" and not (busy and not b.get("up", false)):
		v.add_child(_trainee_row())
	if busy:
		_sel_timer = UI.gold("", 28)
		var what := "Wird weggeräumt …" if b.get("clear", false) else ("Wird verbessert – arbeitet weiter" if b.get("up", false) else "Baudrohne arbeitet …")
		v.add_child(UI.card(UI.hbox(12, [UI.icon("clock", 44, UI.GOLD), UI.label(what, 24), UI.spacer(true), _sel_timer]), Color("4A3A1C"), 12, Color(UI.GOLD, 0.8)))
		btns.add_child(_speed_button(id))
	elif def.cat == "obstacle":
		var ocost := P.cost_for(key, 1)
		var orow := UI.hbox(14, [UI.pic("ui_recycle", 40.0), UI.label("Wegräumen:", 24), UI.cost_row(ocost, 24), UI.spacer(true), UI.icon("clock", 30, UI.WHITE), UI.label(UI.time_text(P.time_for(key, 1)), 22, UI.TEXT)])
		v.add_child(UI.card(orow, UI.NAVY_L, 12))
		btns.add_child(UI.button("Wegräumen", func():
			var why2 := P.clear_obstacle(id)
			if why2 != "":
				toast(why2)
				UI.sfx("ui_error", "error", -6.0), "green", 27, "ui_recycle"))
	else:
		if lv < P.max_level(key) or (key != "bunker" and P.max_level(key) < 10 and def.cat not in ["wall", "deco"]):
			if lv < P.max_level(key):
				var cost := P.cost_for(key, lv + 1)
				var why := P.can_upgrade(id)
				var up := UI.hbox(14, [UI.pic("ui_up", 40.0), UI.label("Stufe %d:" % (lv + 1), 24), UI.cost_row(cost, 24), UI.spacer(true), UI.icon("clock", 30, UI.WHITE), UI.label(UI.time_text(P.time_for(key, lv + 1)), 22, UI.TEXT)])
				var ubox := UI.vbox(4, [up])
				if why != "":
					ubox.add_child(UI.label(why, 20, UI.RED))
				v.add_child(UI.card(ubox, UI.NAVY_L, 12))
				var ub := UI.button("Verbessern", func():
					if P.upgrade(id):
						UI.sfx("ui_upgrade", "build", -4.0), "green", 27, "ui_up")
				UI.disable(ub, why != "")
				ub.tooltip_text = why
				btns.add_child(ub)
			else:
				v.add_child(UI.info_box("Für die nächste Stufe erst den Bunker ausbauen.", 21, "ui_lock"))
		elif def.cat == "wall" and lv < 3:
			v.add_child(UI.info_box("%s ab Bunker-Stufe %d." % ["Stein" if lv == 1 else "Metall", 4 if lv == 1 else 7], 21, "ui_lock"))
		if key == "wall":
			var nw := P.upgradable_walls().size()
			if nw > 1:
				var ab := UI.button("Alle verbessern (%d)" % nw, func():
					var n := P.upgrade_walls()
					if n > 0:
						UI.sfx("ui_upgrade", "build", -4.0)
						toast("%d Mauerstücke werden verbessert" % n)
					else:
						toast("Keine Drohne frei oder zu wenig Rohstoffe")
						UI.sfx("ui_error", "error", -6.0), "green", 24, "ui_up")
				btns.add_child(ab)
			var gcost := P.gate_swap_cost()
			var gb := UI.button("Zu Tor machen", func():
				var g: Dictionary = P.wall_to_gate(id)
				if g.is_empty():
					UI.sfx("ui_error", "error", -6.0)
				else:
					UI.sfx("ui_upgrade", "build", -4.0)
					world.select(int(g.id)), "gold", 24, "ui_shield")
			gb.tooltip_text = "Ersetzt dieses und das Nachbarstück durch ein Tor"
			btns.add_child(gb)
			v.add_child(UI.hbox(10, [UI.label("Tor statt zwei Mauerstücken:", 20, UI.TEXT), UI.cost_row(gcost, 20)]))
		if def.has("prod") and P.prod_stored(b) > 0:
			btns.add_child(UI.button("Einsammeln", func():
				UI.sfx("ui_claim", "", -6.0)
				world._collect(b, world.nodes[id]), "gold", 27, "res_" + String(def.prod)))
		if def.has("screen"):
			btns.add_child(UI.button("Öffnen", func(): _open(def.screen), "", 27, String(MENU_ICON.get(String(def.screen), "ui_play"))))
	if def.cat != "obstacle":
		btns.add_child(UI.button("Verschieben", func(): world.begin_move(id), "dark", 25))
	if key == "bunker":
		var lay := UI.hbox(8, [UI.label("Aufbau der Basis:", 20, UI.TEXT)])
		for slot in 3:
			var sl: int = slot
			lay.add_child(UI.button("%d sichern" % (sl + 1), func(): P.save_layout(sl), "dark", 20))
			var lb := UI.button("laden", func(): P.load_layout(sl), "dark", 20)
			lb.disabled = P.d.layouts[sl] == null
			lay.add_child(lb)
		v.add_child(lay)
	if def.cat in ["wall", "deco", "trap"]:
		btns.add_child(UI.button("Entfernen", func():
			world.select(-1)
			P.remove(id), "red", 25, "ui_recycle"))
	for bb in btns.get_children():
		bb.custom_minimum_size.y = 76
	v.add_child(btns)
	var win := SelWin.new()
	win.world = world
	win.add_theme_stylebox_override("panel", UI.panel_style(GLASS, UI.EDGE, 26, 18))
	win.add_child(v)
	return win


func _sig_of(b: Dictionary) -> String:
	var id := int(b.id)
	return "%d|%d|%s|%s|%d|%s|%d" % [id, int(b.level), P.is_building(b), P.can_upgrade(id) == "", P.speed_cost(id), P.trainee(), P.drones_total()]


## Knopf zum Fertigstellen: unter einer Minute gratis, sonst für Juwelen.
func _speed_button(id: int) -> Button:
	var cost := P.speed_cost(id)
	if cost <= 0:
		return UI.button("Fertigstellen – gratis", func(): _speed_up(id), "green", 26, "ui_check")
	return UI.button("Beschleunigen  %d" % cost, func(): _speed_up(id), "gold", 26, "res_gems")


## Stellt einen Bau sofort fertig. Ab 50 Juwelen wird einmal nachgefragt.
func _speed_up(id: int) -> void:
	var cost := P.speed_cost(id)
	var go := func():
		_close_modal()
		if P.finish_now(id):
			UI.sfx("ui_upgrade", "upgrade", -4.0)
		else:
			UI.sfx("ui_error", "error", -6.0)
			if P.gems() < cost:
				_open("shop")
	if cost >= D.GEM_CONFIRM and not G.ch("freegems"):
		var b := P.get_building(id)
		_ask("%s für %d Juwelen sofort fertigstellen?" % [String(D.BUILDINGS[b.key].name), cost], "Ja, beschleunigen", go, "res_gems")
	else:
		go.call()


func _buy_drone(price: int) -> void:
	_ask("Eine weitere Baudrohne für %d Juwelen kaufen? Sie bleibt für immer." % price, "Kaufen", func():
		_close_modal()
		if P.buy_drone():
			UI.sfx("ui_buy", "upgrade", -4.0)
		elif P.gems() < price:
			_open("shop"), "ui_drone")


## Kleine Rückfrage mit Ja / Abbrechen.
func _ask(text: String, yes_text: String, yes: Callable, icon_name := "ui_info") -> void:
	var t := UI.text(text, 30, UI.WHITE, 640.0)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var yb := UI.button(yes_text, yes, "green", 30, icon_name)
	yb.custom_minimum_size = Vector2(300, 84)
	var nb := UI.button("Abbrechen", _close_modal, "dark", 28)
	nb.custom_minimum_size = Vector2(240, 84)
	var row := UI.hbox(20, [nb, yb])
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_show_modal(UI.vbox(24, [t, row]), 0.55, UI.GOLD)


## Alle Drohnen beschäftigt: warten oder einen laufenden Bau beschleunigen.
func _ask_drones() -> void:
	var v := UI.vbox(14)
	var t := UI.label("Alle Drohnen beschäftigt", 44, UI.GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UI.text("Warte, bis ein Bau fertig ist, oder stelle einen sofort fertig.", 24, UI.TEXT, 700))
	for j in P.jobs():
		var jid := int(j.id)
		if not P.needs_drone(String(j.key)):
			continue
		var nm := UI.label(String(j.name), 26)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		var sb := _speed_button(jid)
		sb.custom_minimum_size = Vector2(330, 70)
		v.add_child(UI.card(UI.hbox(14, [UI.building_pic(String(j.key), 60.0), nm, UI.label(UI.time_text(float(j.end) - P.now()), 24, UI.GOLD), sb]), UI.NAVY_L, 10))
	var dp := P.drone_price()
	var row := UI.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var wb := UI.button("Warten", _close_modal, "dark", 28)
	wb.custom_minimum_size = Vector2(240, 80)
	row.add_child(wb)
	if dp > 0:
		var db := UI.button("Weitere Drohne  %d" % dp, func(): _buy_drone(dp), "gold", 26, "res_gems")
		db.custom_minimum_size = Vector2(360, 80)
		row.add_child(db)
	v.add_child(row)
	_show_modal(v)


## Held, der am Trainingsplatz Erfahrung sammelt.
func _trainee_row() -> Control:
	var row := UI.hbox(8, [UI.label("Trainiert:", 22, UI.TEXT)])
	for hk in D.HERO_ORDER:
		if not P.hero_unlocked(hk):
			continue
		var k: String = hk
		var on: bool = P.trainee() == hk
		var hb := UI.row_button(on, func():
			UI.sfx("ui_select", "", -8.0)
			P.set_trainee("" if P.trainee() == k else k)
			_sel_sig = "", UI.vbox(-2, [UI.hero_pic(hk, 56.0), UI.label("St. %d" % int(P.hero(hk).level), 17, UI.TEXT)]), 84.0)
		hb.custom_minimum_size = Vector2(84, 88)
		hb.tooltip_text = String(D.HEROES[hk].name)
		row.add_child(hb)
	var note := "Der gewählte Held sammelt Erfahrung, solange er nicht gespielt wird und nicht unterwegs ist."
	if P.trainee() != "" and P.trainee() == String(P.d.hero_sel):
		note = "%s wird gerade gespielt – das Training ruht." % P.trainee().capitalize()
	return UI.card(UI.vbox(6, [row, UI.label(note, 19, UI.GREY, false)]), UI.NAVY_L, 10)


## Liste der laufenden Bauten unter der Wochentafel. Antippen springt mit der Kamera dorthin.
func _update_jobs() -> void:
	if _jobs_box == null:
		return
	var jobs: Array = P.jobs()
	var sg := ""
	for j in jobs:
		sg += "%d:%d:%d," % [int(j.id), int(j.count), 1 if float(j.end) - P.now() <= D.GEM_FREE_SECONDS else 0]
	if sg != _jobs_sig:
		_jobs_sig = sg
		_job_rows.clear()
		UI.clear(_jobs_box)
		var shown := 0
		for j in jobs:
			if shown >= 4:
				_jobs_box.add_child(UI.label("… und %d weitere" % (jobs.size() - shown), 18, UI.TEXT))
				break
			shown += 1
			var jid := int(j.id)
			var nm := UI.label(String(j.name), 20)
			nm.clip_text = true
			nm.custom_minimum_size = Vector2(170, 0)
			var tl := UI.label("", 20, UI.GOLD)
			tl.custom_minimum_size = Vector2(84, 0)
			tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			var bar := UI.bar(0.0, UI.GOLD, Vector2(170, 8))
			var content := UI.hbox(8, [UI.building_pic(String(j.key), 40.0), UI.vbox(2, [nm, bar]), tl])
			var rb := UI.row_button(false, func(): world.focus(jid), content, 54.0)
			rb.custom_minimum_size = Vector2(330, 56)
			var free: bool = float(j.end) - P.now() <= D.GEM_FREE_SECONDS
			var sb := UI.button("Gratis" if free else "", func(): _speed_up(jid), "green" if free else "gold", 18, "" if free else "res_gems")
			sb.custom_minimum_size = Vector2(86 if free else 56, 54)
			sb.tooltip_text = "Sofort fertigstellen"
			_jobs_box.add_child(UI.hbox(6, [rb, sb]))
			_job_rows.append([tl, bar, j])
	for r in _job_rows:
		if not is_instance_valid(r[0]):
			continue
		var j2: Dictionary = r[2]
		var left := float(j2.end) - P.now()
		r[0].text = UI.time_text(maxf(left, 0.0))
		var total := float(j2.end) - float(j2.t0)
		r[1].value = clampf(1.0 - left / total, 0.0, 1.0) if total > 0.0 else 0.0


func _fly_done(tr: Control, res: String) -> void:
	if is_instance_valid(tr):
		tr.queue_free()
	var lab = _res_labels.get(res)
	if lab != null and is_instance_valid(lab):
		UI.pulse(lab, 1.25)
	UI.sfx("coin", "", -16.0, 1.2)


## Symbole springen von einer Stelle im Bild zur Rohstoffanzeige; die Zahl dort blitzt auf.
func fly_icons(icon_name: String, from: Vector2, res: String, n: int) -> void:
	var tex := UI.tex(icon_name)
	if tex == null or _peace == null:
		return
	if _fly == null or not is_instance_valid(_fly):
		_fly = Control.new()
		_fly.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(_fly)
	var target := Vector2(root.size.x * 0.5, 50.0)
	var lab: Label = _res_labels.get(res)
	if lab != null and is_instance_valid(lab):
		target = lab.get_global_rect().get_center() - Vector2(34, 0)
	# die Flugbahn rechnet in den Koordinaten des HUD (skaliert), nicht des Fensters
	var inv := root.get_global_transform().affine_inverse()
	var a: Vector2 = inv * from
	var b: Vector2 = inv * target
	for i in n:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size = Vector2(44, 44)
		tr.pivot_offset = Vector2(22, 22)
		tr.position = a - Vector2(22, 22)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fly.add_child(tr)
		var ang := randf() * TAU
		var burst := a + Vector2(cos(ang), sin(ang)) * randf_range(30.0, 90.0) - Vector2(22, 22)
		var tw := tr.create_tween()
		tw.tween_property(tr, "position", burst, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_interval(0.04 * i)
		tw.tween_property(tr, "position", b - Vector2(22, 22), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(tr, "scale", Vector2(0.6, 0.6), 0.42)
		tw.tween_callback(_fly_done.bind(tr, res))


# ---------------------------------------------------------------- Baumenü
func _toggle_build() -> void:
	if _build_box:
		_close_build()
	else:
		world.cancel_edit()
		world.select(-1)
		UI.sfx("ui_open", "", -8.0)
		_show_build()
		UI.pop_in(_build_box, 0.96, 0.14)


func _close_build() -> void:
	if _build_box:
		_build_box.get_parent().queue_free()
		_build_box = null
		if _sel_box and is_instance_valid(_sel_box):
			_sel_box.visible = true


## Baumenü: Reiter mit Bildzeichen, darunter Karten mit Gebäudebild, Name, Anzahl, Kosten und Bauzeit.
func _show_build() -> void:
	_close_build()
	var tabs := UI.hbox(10)
	for c in D.BUILD_CATS:
		var ck: String = c[0]
		var tb := UI.tab_button(String(c[1]), String(CAT_ICON.get(ck, "ui_star")), ck == _build_cat, func():
			if _build_cat != ck:
				UI.sfx("ui_tab", "", -8.0)
			_build_cat = ck
			_show_build(), 24)
		tabs.add_child(tb)
	tabs.add_child(UI.spacer(true))
	var x := UI.button("", _close_build, "red", 24, "ui_close")
	x.custom_minimum_size = Vector2(76, 66)
	tabs.add_child(x)
	var row := UI.hbox(12)
	for key in D.BUILDINGS:
		var def: Dictionary = D.BUILDINGS[key]
		if def.cat != _build_cat:
			continue
		var locked: bool = int(def.unlock) > P.bunker_level() and not G.ch("nolimit")
		var why := P.can_build(key)
		var have := P.count(key)
		var mx := P.max_count(key)
		var v := UI.vbox(2)
		var pic := UI.building_pic(key, 104.0)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var nm := UI.label(def.name, 25)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.clip_text = true
		v.add_child(pic)
		v.add_child(nm)
		if locked:
			pic.modulate = Color(0.4, 0.47, 0.65)
			var lr := UI.hbox(8, [UI.icon("lock", 30, UI.GOLD), UI.label("Ab Bunker %d" % int(def.unlock), 22, UI.GOLD)])
			lr.alignment = BoxContainer.ALIGNMENT_CENTER
			v.add_child(lr)
		else:
			var cr := UI.cost_row(P.cost_for(key, 1), 22)
			cr.alignment = BoxContainer.ALIGNMENT_CENTER
			v.add_child(cr)
			var info := UI.hbox(8)
			info.alignment = BoxContainer.ALIGNMENT_CENTER
			info.add_child(UI.label("%d / %d" % [have, mx], 21, UI.ORANGE if have >= mx else UI.TEXT))
			var tm := P.time_for(key, 1)
			if tm > 0.0:
				info.add_child(UI.icon("clock", 24, UI.WHITE))
				info.add_child(UI.label(UI.time_text(tm), 20, UI.TEXT, false))
			v.add_child(info)
		var k: String = key
		var card := UI.row_button(false, func():
			_close_build()
			if P.can_build(k) == "Alle Baudrohnen sind beschäftigt":
				_ask_drones()
			else:
				world.begin_place(k), v, 228.0)
		card.custom_minimum_size = Vector2(250, 228)
		card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		card.tooltip_text = String(def.desc) + ("\n" + why if why != "" else "")
		if why != "" and not locked:
			(card.get_meta("content") as Control).modulate = Color(0.8, 0.85, 0.95, 0.7)
		row.add_child(card)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 246)
	sc.add_child(row)
	var cat := _build_cat
	sc.scroll_horizontal = int(_build_scroll.get(cat, 0))
	sc.get_h_scroll_bar().value_changed.connect(func(val: float): _build_scroll[cat] = int(val))
	_build_box = UI.panel(UI.vbox(12, [tabs, sc]), GLASS, UI.EDGE, 26, 16)
	_peace.add_child(_build_box)
	_anchor(_build_box, Control.PRESET_CENTER_BOTTOM, Vector2(0, -136))
	_build_box.size_flags_horizontal = Control.SIZE_FILL
	(_build_box.get_parent() as MarginContainer).add_theme_constant_override("margin_left", 24)
	(_build_box.get_parent() as MarginContainer).add_theme_constant_override("margin_right", 24)
	if _sel_box:
		_sel_box.visible = false


func _show_edit_bar() -> void:
	var key: String = world._edit_key()
	var hint := "Klicke auf ein freies Feld. R dreht, Rechtsklick beendet." if not G.is_touch else "Tippe auf ein Feld, dann „Hier bauen“. Der Stick bewegt die Kamera."
	if key == "wall" and not G.is_touch:
		hint = "Klicken und ziehen, um Mauern zu setzen. Rechtsklick beendet."
	var h := UI.hbox(14)
	h.add_child(UI.building_pic(key, 64.0))
	var etxt := UI.vbox(-2, [UI.label(D.BUILDINGS[key].name, 28), UI.label(hint, 20, UI.TEXT, false)])
	if world.enclosed:
		etxt.add_child(UI.label("Kein Ausgang – setze ein Tor!", 20, UI.RED))
	h.add_child(etxt)
	var b1 := UI.button("Drehen", world.rotate_ghost, "dark", 26, "ui_recycle")
	var b2 := UI.button("Hier bauen" if world.move_id < 0 else "Hierhin", world.confirm_edit, "green", 26, "ui_check")
	var b3 := UI.button("Fertig", world.cancel_edit, "red", 26, "ui_close")
	_edit_box = UI.panel(h, GLASS, UI.EDGE, 24, 12)
	# die Leiste selbst lässt Klicks durch (man kann auch dahinter bauen); nur die Knöpfe fangen sie ab
	UI.ignore_mouse(_edit_box)
	for bb in [b1, b2, b3]:
		bb.custom_minimum_size.y = 66
		h.add_child(bb)
	_peace.add_child(_edit_box)
	_anchor(_edit_box, Control.PRESET_CENTER_BOTTOM, Vector2(0, -136))


# ---------------------------------------------------------------- Dialoge
func _close_modal() -> void:
	if _modal:
		_modal.queue_free()
		_modal = null


func _show_modal(inner: Control, dim := 0.55, border := UI.EDGE) -> void:
	_close_modal()
	_modal = Control.new()
	_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.12, dim)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var win := UI.panel(inner, UI.NAVY, border, 30, 32)
	cc.add_child(win)
	_modal.add_child(cc)
	root.add_child(_modal)
	UI.pop_in(win, 0.9, 0.18)


func _ask_flood() -> void:
	var practice := not P.flood_available()
	if practice and not P.practice_available():
		return
	var fd: Dictionary = world.flood_preview(practice)
	var dirs: Array = P.d.week.dirs
	var v := UI.vbox(14)
	var t := UI.label("Übungsalarm" if practice else "Die Flut – Woche %d" % int(P.d.week.number), 50, UI.GOLD)
	t.add_theme_constant_override("outline_size", 12)
	var head := UI.hbox(16, [UI.pic("ui_alarm" if practice else "ui_flood", 76.0), t])
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(head)
	var stats := UI.vbox(10)
	stats.add_child(UI.stat_row("ui_flag", "Wellen", str(int(fd.waves)), 27))
	stats.add_child(UI.stat_row("e_0", "Schleimlinge", "etwa %d" % int(fd.total), 27))
	stats.add_child(UI.stat_row("ui_map", "Sie kommen aus", "%s und %s" % [world.DIR_NAME[int(dirs[0])], world.DIR_NAME[int(dirs[1])]], 27, UI.ORANGE))
	if String(fd.get("guest_text", "")) != "":
		stats.add_child(UI.stat_row("ui_alarm", String(fd.guest_text), "", 27, UI.ORANGE))
	if fd.boss:
		stats.add_child(UI.hbox(14, [UI.enemy_pic(D.E_BOSS, 52.0), UI.label("In der letzten Welle kommt ein Boss!", 27, UI.RED)]))
	var sc := UI.card(stats, UI.NAVY_L, 18)
	sc.custom_minimum_size = Vector2(700, 0)
	v.add_child(sc)
	if practice:
		v.add_child(UI.info_box("Die Übung ist schwächer als die echte Flut. Du verlierst nichts und bekommst Münzen und Erfahrung.", 23))
	else:
		v.add_child(UI.info_box("Hält der Bunker, gibt es eine Flutkiste. Fällt er, gehen bis zu 20 % der gelagerten Rohstoffe verloren – Gebäude bleiben erhalten.", 23))
	var go := UI.button("Los!", func():
		_close_modal()
		world.start_flood(practice), "red", 38, "ui_play")
	go.custom_minimum_size = Vector2(300, 92)
	var back := UI.button("Noch nicht", _close_modal, "dark", 30)
	back.custom_minimum_size = Vector2(260, 92)
	var hb := UI.hbox(18, [back, go])
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(hb)
	_show_modal(v)


func _on_pause() -> void:
	if G.main.screens.is_open() or world == null:
		return
	if world.mode == "peace":
		if world.editing():
			world.cancel_edit()
		elif _build_box:
			_close_build()
		elif _modal:
			_close_modal()
		elif world.selected_id >= 0:
			world.select(-1)
		return
	if world.ended:
		return
	if _modal:
		_resume()
		return
	get_tree().paused = true
	var v := UI.vbox(16)
	var t := UI.label("Pause", 58, UI.GOLD)
	t.add_theme_constant_override("outline_size", 12)
	var head := UI.hbox(16, [UI.pic("ui_pause", 64.0), t])
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(head)
	var b1 := UI.button("Weiterspielen", _resume, "green", 34, "ui_play")
	b1.custom_minimum_size = Vector2(520, 92)
	v.add_child(b1)
	var b2 := UI.button("Optionen", func():
		_resume(false)
		get_tree().paused = true
		G.main.screens.open("settings"), "dark", 30, "ui_gear")
	b2.custom_minimum_size = Vector2(520, 84)
	v.add_child(b2)
	var txt := "Expedition abbrechen (nur das Depot kommt heim)" if world.mode == "exp" else ("Übung beenden" if world.mode == "practice" else "Aufgeben")
	var b3 := UI.button(txt, func():
		_resume()
		if world.mode == "exp":
			world.abort()
		else:
			world._finish(false), "red", 28, "ui_flag")
	b3.custom_minimum_size = Vector2(520, 84)
	v.add_child(b3)
	_show_modal(v)


func _resume(unpause := true) -> void:
	_close_modal()
	if unpause:
		get_tree().paused = false


# ================================================================= Kampf
func _build_battle() -> void:
	_battle = _layer_root()
	var exp: bool = world.mode == "exp"
	var hero = world.hero
	var hdef: Dictionary = D.HEROES[hero.key]
	# ---- oben links: Welle / Aufgabe
	var v := UI.vbox(10)
	if exp:
		_exp_title = UI.label("%s · %s" % [world.adef.name, world.phase_name()], 28)
		v.add_child(UI.hbox(12, [UI.pic("area_" + String(world.adef.key), 56.0, "ui_expedition"), _exp_title]))
		_obj_label = UI.gold("", 24)
		_obj_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_obj_label.custom_minimum_size = Vector2(460, 0)
		v.add_child(_obj_label)
		_pack_bar = UI.bar(0.0, UI.ORANGE, Vector2(250, 28))
		_pack_label = UI.label("", 23, UI.GOLD)
		_pack_label.custom_minimum_size = Vector2(70, 0)
		_field_coins = UI.gold("0", 24)
		_field_coins.tooltip_text = "Feldmünzen: bezahlen Bauplätze, der Rest geht bei der Heimkehr in die Kasse"
		v.add_child(UI.hbox(10, [UI.icon("pack", 46), _pack_bar, _pack_label, UI.icon("coins", 36), _field_coins]))
		_pack_box = UI.flow(6)
		_pack_box.custom_minimum_size = Vector2(460, 0)
		_pack_sig = "-"
		v.add_child(_pack_box)
		_life_label = UI.label("", 19, UI.TEXT, false)
		v.add_child(_life_label)
		_hold_bar = UI.bar(0.0, UI.GREEN, Vector2(460, 18))
		_hold_bar.visible = false
		v.add_child(_hold_bar)
		_quest_box = UI.vbox(2)
		_quest_sig = ""
		v.add_child(_quest_box)
	else:
		_wave_label = UI.gold("", 42)
		_left_label = UI.label("", 30)
		v.add_child(UI.hbox(12, [UI.pic("ui_flood", 52.0), UI.label("Welle", 30), _wave_label, UI.spacer(true, Vector2(16, 0)), UI.pill(UI.hbox(8, [UI.enemy_pic(0, 40.0), _left_label]))]))
		_bunker_bar = UI.bar(1.0, D.C_BAR_BLUE, Vector2(380, 32))
		v.add_child(UI.hbox(10, [UI.building_pic("bunker", 56.0, P.bunker_level()), _bunker_bar]))
	v.add_child(UI.sep(false, Color(UI.EDGE, 0.4)))
	# Held
	_hero_bar = UI.bar(1.0, D.C_BAR_RED, Vector2(320, 28))
	_ammo_bar = UI.bar(1.0, UI.GOLD, Vector2(320, 14))
	_hero_label = UI.label(hdef.name, 23)
	_hero_lv = UI.label("", 21, UI.GOLD)
	_xp_hero = UI.bar(0.0, UI.GOLD, Vector2(320, 8))
	v.add_child(UI.hbox(12, [UI.hero_pic(String(hero.key), 84.0), UI.vbox(4, [UI.hbox(10, [_hero_label, UI.spacer(true), _hero_lv]), _hero_bar, _xp_hero, _ammo_bar])]))
	if hero.veh_node != null:
		_veh_bar = UI.bar(1.0, UI.SKY, Vector2(300, 16))
		_veh_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		v.add_child(UI.hbox(10, [UI.vehicle_pic(String(hero.veh_key), 48.0), _veh_bar]))
	var tl := UI.panel(v, GLASS, UI.EDGE, 24, 16)
	UI.ignore_mouse(tl)
	_battle.add_child(tl)
	_anchor(tl, Control.PRESET_TOP_LEFT, Vector2(24, 24))
	# ---- oben rechts: Münzen, Pause, Karte
	_coin_label = UI.gold(UI.fmt(P.res("coins")), 30)
	var pause := UI.button("", _on_pause, "dark", 28, "ui_pause")
	pause.custom_minimum_size = Vector2(84, 76)
	var tr := UI.vbox(10)
	var top := UI.hbox(12)
	top.alignment = BoxContainer.ALIGNMENT_END
	if not exp:
		var cp := UI.panel(UI.hbox(8, [UI.icon("coins", 42), _coin_label]), GLASS, UI.EDGE, 24, 10)
		cp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(cp)
	top.add_child(pause)
	tr.add_child(top)
	if exp:
		_map = MiniMap.new()
		_map.world = world
		_map.custom_minimum_size = Vector2(240, 240)
		_map.size_flags_horizontal = Control.SIZE_SHRINK_END
		_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.add_child(_map)
	_battle.add_child(tr)
	_anchor(tr, Control.PRESET_TOP_RIGHT, Vector2(-24, 24))
	# ---- Boss
	_boss_label = UI.label("", 30, UI.GOLD)
	_boss_bar = UI.bar(1.0, Color("7FC12A"), Vector2(560, 30))
	_boss_box = UI.panel(UI.hbox(14, [UI.enemy_pic(D.E_BOSS, 76.0), UI.vbox(4, [_boss_label, _boss_bar])]), GLASS, UI.RED, 24, 10)
	UI.ignore_mouse(_boss_box)
	_boss_box.visible = false
	_battle.add_child(_boss_box)
	_anchor(_boss_box, Control.PRESET_CENTER_TOP, Vector2(0, 24))
	# ---- Pause zwischen Wellen
	_break_label = UI.label("", 30)
	var skip := UI.button("Sofort weiter (N)" if not G.is_touch else "Sofort weiter", world.skip_break if not exp else Callable(), "green", 26, "ui_play")
	skip.custom_minimum_size.y = 76
	_break_box = UI.panel(UI.hbox(16, [UI.pic("ui_check", 48.0, "", UI.GREEN), _break_label, skip]), GLASS, UI.EDGE, 24, 12)
	_break_box.visible = false
	_battle.add_child(_break_box)
	_anchor(_break_box, Control.PRESET_CENTER_TOP, Vector2(0, 130))
	_respawn_label = UI.label("", 44, UI.RED)
	_respawn_label.visible = false
	_battle.add_child(_respawn_label)
	_anchor(_respawn_label, Control.PRESET_CENTER_TOP, Vector2(0, 280))
	if exp:
		# Heimkehren: erscheint an der Zentrale und am Fahrzeug in der Außenbasis
		_home_btn = UI.button("Heimkehren", func(): world.go_home(), "green", 32, "ui_check")
		_home_btn.custom_minimum_size = Vector2(340, 96)
		_home_btn.visible = false
		_battle.add_child(_home_btn)
		_anchor(_home_btn, Control.PRESET_CENTER_BOTTOM, Vector2(0, -40))
		_arrow = EdgeArrow.new()
		_arrow.world = world
		_arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
		_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_battle.add_child(_arrow)
	_update_battle()
	# beim Aufbau stehen die Balken sofort richtig
	for bar in _smooth:
		if is_instance_valid(bar):
			bar.value = float(_smooth[bar])


func _update_battle() -> void:
	if _battle == null or world == null or world.hero == null:
		return
	var hero = world.hero
	_smooth[_hero_bar] = hero.hp / hero.max_hp
	_smooth[_ammo_bar] = hero.ammo_ratio()
	var hd: Dictionary = P.hero(String(hero.key))
	_hero_lv.text = "Stufe %d" % int(hd.level)
	_smooth[_xp_hero] = 1.0 if int(hd.level) >= D.HERO_MAX_LEVEL else float(hd.xp) / maxf(1.0, D.hero_xp_need(int(hd.level)))
	if _veh_bar:
		_smooth[_veh_bar] = hero.veh_hp / maxf(hero.veh_max, 1.0)
	var horde = world.horde
	if horde.boss != null:
		_boss_box.visible = true
		_boss_label.text = horde.boss_name
		if int(_boss_box.get_meta("t", D.E_BOSS)) != horde.boss.t:      # Bild der Boss-Art nachziehen
			_boss_box.set_meta("t", horde.boss.t)
			var hb: Node = _boss_label.get_parent().get_parent()
			var old: Node = hb.get_child(0)
			hb.remove_child(old)
			old.queue_free()
			hb.add_child(UI.enemy_pic(horde.boss.t, 76.0))
			hb.move_child(hb.get_child(hb.get_child_count() - 1), 0)
		_smooth[_boss_bar] = horde.boss.hp / horde.boss.mhp
	else:
		_boss_box.visible = false
	if world.mode == "exp":
		_exp_title.text = "%s · %s" % [world.adef.name, world.phase_name()]
		_obj_label.text = world.objective_text()
		_smooth[_pack_bar] = world.weight / world.cap
		_pack_label.text = "%d %%" % int(world.weight / world.cap * 100.0)
		_field_coins.text = UI.fmt(world.field_coins())
		_refresh_pack()
		_life_label.text = "Wiedereinstiege: %d · Depot: %d Ladungen" % [maxi(world.respawns_left, 0), world.loads]
		_hold_bar.visible = false
		var qs: Array = world.side_quests()
		var sig := str(qs)
		if sig != _quest_sig:
			_quest_sig = sig
			UI.clear(_quest_box)
			if qs.size() > 0:
				_quest_box.add_child(UI.label("Nebenaufgaben", 21, UI.SKY))
			for q in qs:
				_quest_box.add_child(UI.label(("✓ " if q[1] else "• ") + String(q[0]), 19, UI.GREEN if q[1] else UI.TEXT, false))
		_home_btn.visible = world.can_go_home()
		_respawn_label.visible = not hero.alive and not world.ended and world.respawns_left >= 0
		if _respawn_label.visible:
			_respawn_label.text = "Wiedereinstieg in %d …" % int(ceil(hero.respawn_left()))
		_arrow.queue_redraw()
		_map.queue_redraw()
	else:
		_wave_label.text = "%d/%d" % [world.wave_idx, world.wave_count]
		_left_label.text = str(world.enemies_left())
		var bk = world.bunker_node
		_smooth[_bunker_bar] = bk.hp / bk.max_hp
		_break_box.visible = world.break_left > 0.0 and not world.ended
		if _break_box.visible:
			_break_label.text = "Welle geschafft! Nächste in %d s" % int(ceil(world.break_left))
		_respawn_label.visible = not hero.alive and not world.ended
		if _respawn_label.visible:
			_respawn_label.text = "Zurück in %d …" % int(ceil(hero.respawn_left()))


# ---------------------------------------------------------------- Ergebnis
func _show_result() -> void:
	var r: Dictionary = world.result
	var exp: bool = world.mode == "exp"
	var win: bool = r.get("success", r.get("win", false))
	var practice: bool = not exp and r.get("practice", false)
	var v := UI.vbox(14)
	v.custom_minimum_size = Vector2(820, 0)
	var title := "Geschafft!" if win else ("Zurück zur Basis" if exp else "Der Bunker ist gefallen")
	if practice:
		title = "Übung bestanden!" if win else "Übung verloren"
	var t := UI.label(title, 62, UI.GOLD if win else UI.RED)
	t.add_theme_constant_override("outline_size", 14)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if not exp and win and not practice:
		# Sterne springen der Reihe nach auf
		var stars := UI.hbox(14)
		stars.alignment = BoxContainer.ALIGNMENT_CENTER
		for i in 3:
			var got := i < int(r.stars)
			var st := UI.icon("star", 96 if i == 1 else 80, UI.GOLD if got else Color("33455E"))
			stars.add_child(st)
			if got:
				st.modulate.a = 0.0
				var tw := st.create_tween()
				tw.tween_interval(0.35 + 0.3 * i)
				tw.tween_callback(func():
					st.modulate.a = 1.0
					UI.sfx("ui_claim", "click", -6.0, 1.0 + 0.15 * i))
				UI.pulse(st, 1.5, 0.35 + 0.3 * i)
		v.add_child(stars)
	var body := UI.vbox(10)
	var kl := UI.label("0", 29, UI.GOLD)
	UI.count_up(kl, float(r.get("kills", 0)), 0.9, Callable(), 0.2)
	var kn := UI.label("Besiegte Schleimlinge", 27)
	kn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(UI.hbox(14, [UI.enemy_pic(0, 48.0), kn, kl]))
	if exp:
		if not win:
			var how := String(r.get("how", ""))
			v.add_child(UI.info_box("Abgebrochen: nur der Inhalt des Depots kommt heim." if how == "abort" else "Dein Held ist gefallen: Depot und halber Rucksack kommen heim.", 23))
		if int(r.get("outpost_level", 0)) >= 1:
			var ol := int(r.outpost_level)
			var ak := String(D.AREAS[int(r.area)].key)
			body.add_child(UI.hbox(12, [UI.pic("o_special_%s%s" % [ak, "_1" if ol < 5 else ""], 56.0, "ui_flag"), UI.label("Außenbasis %s: Stufe %d" % [String(D.OUTPOSTS[ak].special), ol], 26, UI.GOLD)]))
		var kept: Dictionary = r.get("kept", {})
		if kept.size() > 0:
			body.add_child(UI.label("Bleibt 24 Stunden im Depot der Außenbasis (Lager voll):", 21, UI.TEXT, false))
			body.add_child(_loot_row(kept, UI.SKY))
		var lt: Dictionary = r.loot
		var got2 := 0
		for k in lt:
			got2 += int(lt[k])
		if got2 > 0:
			body.add_child(UI.sep(false, Color(UI.EDGE, 0.4)))
			body.add_child(UI.label("Beute", 26, UI.SKY))
			body.add_child(_loot_row(lt, UI.GOLD))
		if float(r.get("time", 0.0)) > 0.0:
			body.add_child(UI.stat_row("ui_clock", "Wettlauf", ("%.1f s" % float(r.time)).replace(".", ","), 27))
		if String(r.get("unlocked", "")) != "":
			var hk: String = r.unlocked
			var hl := UI.label("Neuer Held: %s!" % D.HEROES[hk].name, 34, D.HEROES[hk].color.lightened(0.35))
			var hrow := UI.hbox(16, [UI.hero_pic(hk, 110.0), hl, UI.new_tag(20)])
			hrow.alignment = BoxContainer.ALIGNMENT_CENTER
			v.add_child(UI.card(hrow, Color("1F5A34"), 12, UI.GREEN))
		body.add_child(_xp_row(int(r.xp), int(r.hero_xp)))
		for ap in r.get("arsenal", []):        # V4: gefundene Waffen und Baupläne
			var apic := UI.pic("w_" + (String(ap.key) if ap.has("key") else String(P.item(int(ap.get("item", 0))).get("key", ""))), 56.0, "sword")
			if String(ap.kind) == "blueprint":
				apic.modulate = Color(0.55, 0.8, 1.0)
			body.add_child(UI.hbox(12, [apic, UI.label(String(ap.text), 24, UI.GOLD)]))
		var ch: Array = r.chests
		if ch.size() > 0:
			var crow := UI.hbox(12)
			for c in ch:
				crow.add_child(UI.chest_pic(String(c), 64.0))
				crow.add_child(UI.label(String(D.CHESTS[c].name), 25, UI.GOLD))
			body.add_child(crow)
	elif practice:
		body.add_child(_loot_row({"coins": int(r.coins)}, UI.GOLD))
		body.add_child(_xp_row(int(r.xp), 0))
	else:
		var cn := UI.label(String(D.CHESTS[r.chest].name), 28, UI.GOLD)
		cn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pl := UI.label("0", 28, UI.GOLD)
		UI.count_up(pl, float(r.points), 1.0, func(n: int) -> String: return "%s Ranglistenpunkte" % UI.fmt(n), 0.3)
		body.add_child(UI.hbox(14, [UI.chest_pic(String(r.chest), 84.0), cn, pl]))
		body.add_child(_xp_row(int(r.xp), 0))
		var lost: Dictionary = r.lost
		if lost.size() > 0:
			body.add_child(UI.sep(false, Color(UI.RED, 0.5)))
			body.add_child(UI.label("Verloren", 26, UI.RED))
			body.add_child(_loot_row(lost, UI.RED))
			v.add_child(UI.info_box("Die nächste Flut fällt etwas schwächer aus. Verbessere Türme und Mauern!", 23))
	v.add_child(UI.card(body, UI.NAVY_L, 18))
	v.move_child(v.get_child(v.get_child_count() - 1), 2 if (not exp and win and not practice) else 1)
	var go := UI.button("Weiter", func(): _leave_result(""), "green", 36, "ui_check")
	go.custom_minimum_size = Vector2(320, 92)
	var hb := UI.hbox(18, [go])
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	if P.chest_count() > 0:
		var cb := UI.button("Kisten öffnen", func(): _leave_result("chests"), "gold", 32, "ui_chest")
		cb.custom_minimum_size = Vector2(340, 92)
		hb.add_child(cb)
	v.add_child(hb)
	_show_modal(v, 0.45, UI.GOLD if win else UI.RED)


## Rohstoffe mit Bild; die Zahlen zählen hoch.
## Rucksack-Inhalt als Knöpfe: Antippen wirft den Rohstoff hinter den Helden (später wieder aufsammelbar).
func _refresh_pack() -> void:
	if _pack_box == null or not is_instance_valid(_pack_box):
		return
	var keys: Array = []
	for r in D.RES:
		if r != "coins" and float(world.loot.get(r, 0.0)) >= 1.0:
			keys.append([r, int(world.loot[r])])
	var sig := str(keys)
	if sig == _pack_sig:
		return
	_pack_sig = sig
	UI.clear(_pack_box)
	if keys.is_empty():
		_pack_box.add_child(UI.label("Rucksack leer – stell dich neben Bäume, Felsen oder Schrott", 18, UI.TEXT, false))
		return
	for kv in keys:
		var r: String = kv[0]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", UI.box(Color(UI.NAVY_L, 0.92), Color(D.RES_COLOR[r], 0.8), 12, 2, 4))
		b.add_theme_stylebox_override("hover", UI.box(Color(UI.NAVY_L.lightened(0.15), 0.95), D.RES_COLOR[r], 12, 2, 4))
		b.add_theme_stylebox_override("pressed", UI.box(Color(UI.RED, 0.6), UI.RED, 12, 2, 4))
		var hb := UI.hbox(4, [UI.icon(r, 34.0), UI.label(UI.fmt(int(kv[1])), 20), UI.label("✕", 16, Color("FF8A8A"))])
		UI.ignore_mouse(hb)
		b.add_child(hb)
		b.custom_minimum_size = hb.get_combined_minimum_size() + Vector2(10, 6)
		hb.position = Vector2(5, 3)
		b.tooltip_text = "%s abwerfen (liegt danach auf dem Boden, du kannst es wieder aufheben)" % D.RES_NAME[r]
		b.pressed.connect(_drop_res.bind(r))
		_pack_box.add_child(b)
	if keys.size() > 1:
		var all := UI.button("Alles abwerfen", func(): _drop_res(""), "red", 18)
		_pack_box.add_child(all)


func _drop_res(r: String) -> void:
	if world == null or world.mode != "exp" or world.pack == null:
		return
	if r == "":
		world.pack.drop_all()
	else:
		world.pack.drop(r)
	_pack_sig = "-"


func _loot_row(res: Dictionary, col: Color) -> Control:
	var f := UI.flow(22)
	var i := 0
	for r in D.RES:
		if not res.has(r) or int(res[r]) <= 0:
			continue
		var l := UI.label("0", 30, col)
		UI.count_up(l, float(res[r]), 0.8, Callable(), 0.25 + 0.12 * i)
		var ic := UI.icon(String(r), 52)
		ic.tooltip_text = String(D.RES_NAME[r])
		f.add_child(UI.hbox(8, [ic, l]))
		i += 1
	return f


func _xp_row(xp: int, hero_xp: int) -> Control:
	var xl := UI.label("0", 27, UI.GOLD)
	UI.count_up(xl, float(xp), 0.8, func(n: int) -> String: return "+%d" % n, 0.4)
	var row := UI.hbox(12, [UI.pic("ui_star", 44.0, "", UI.GOLD), UI.label("Erfahrung", 26), xl])
	if hero_xp > 0:
		var hl := UI.label("0", 27, UI.GOLD)
		UI.count_up(hl, float(hero_xp), 0.8, func(n: int) -> String: return "+%d" % n, 0.5)
		row.add_child(UI.spacer(false, Vector2(24, 0)))
		row.add_child(UI.pic("ui_helmet", 44.0))
		row.add_child(UI.label("Held", 26))
		row.add_child(hl)
	return row


func _leave_result(screen: String) -> void:
	_close_modal()
	if world.mode == "exp":
		G.main.goto_base(screen)
	else:
		world.back_to_peace()
		if screen != "":
			_open(screen)


func _process(dt: float) -> void:
	_t += dt
	if _flash_a > 0.0:
		_flash_a = maxf(0.0, _flash_a - dt * 0.8)
		_flash.color.a = _flash_a
	# Balken laufen weich zu ihrem Zielwert (nur Werte setzen, nichts neu aufbauen)
	for bar in _smooth:
		if is_instance_valid(bar):
			var to := float(_smooth[bar])
			if absf(bar.value - to) > 0.002:
				bar.value = lerpf(bar.value, to, minf(1.0, dt * 9.0))
	if world == null or not is_instance_valid(world):
		return
	if world.mode == "peace":
		if _peace == null:
			_rebuild()
		if world.editing() and _edit_box == null:
			_rebuild()
		elif not world.editing() and _edit_box != null:
			_rebuild()
		if int(_t * 4.0) != int((_t - dt) * 4.0):
			_update_peace()
	else:
		if int(_t * 10.0) != int((_t - dt) * 10.0):
			_update_battle()


# ---------------------------------------------------------------- Auswahlfenster
## Sobald gebaut oder verschoben wird, lässt das Fenster Klicks sofort durch (es verschwindet erst im nächsten Bild).
class SelWin extends PanelContainer:
	var world: Node3D

	func _has_point(point: Vector2) -> bool:
		if world != null and is_instance_valid(world) and world.editing():
			return false
		return Rect2(Vector2.ZERO, size).has_point(point)


# ---------------------------------------------------------------- Übersichtskarte (Expedition)
class MiniMap extends Control:
	var world: Node3D

	func _draw() -> void:
		var s := size
		draw_style_box(load("res://src/ui.gd").panel_style(Color(0.07, 0.19, 0.37, 0.9), Color("3B7BD0"), 22, 0, 8), Rect2(Vector2.ZERO, s))
		if world == null or world.hero == null:
			return
		var k: float = (s.x - 20.0) / (float(world.HALFM) * 2.0)
		var c := s * 0.5
		# Nebel: Unerforschtes bleibt dunkel
		var fn: int = world.fog_n
		var fc: float = (s.x - 20.0) / fn
		for z in fn:
			for x in fn:
				if world.fog[x + z * fn] == 0:
					draw_rect(Rect2(Vector2(10 + x * fc, 10 + z * fc), Vector2(fc + 0.5, fc + 0.5)), Color(0.02, 0.06, 0.14, 0.85))
		draw_arc(c, float(D.EXP_RING_LAND) * k, 0.0, TAU, 48, Color(1, 1, 1, 0.25), 1.5)
		for p in world.map_points():
			var q: Vector2 = c + p[0] * k
			match p[1]:
				"base":
					draw_rect(Rect2(q - Vector2(7, 7), Vector2(14, 14)), Color("38A9F5"))
					draw_rect(Rect2(q - Vector2(3, 3), Vector2(6, 6)), Color.WHITE)
				"pile":
					draw_circle(q, 3.0, p[2] if p.size() > 2 else Color("FDCA14"))
				"pad":
					draw_circle(q, 3.5, Color("FFD23E"))
				"barrier":
					draw_circle(q, 5.0, Color("FB3D54"))
				"raid":
					draw_circle(q, 9.0, Color(1, 0.2, 0.2, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)))
				"chest":
					draw_rect(Rect2(q - Vector2(5, 4), Vector2(10, 8)), Color("FF9A3E"))
				"goal":
					draw_circle(q, 9.0, Color("FB3D54"))
					draw_circle(q, 5.0, Color("FFD23E"))
				"vehicle":
					draw_rect(Rect2(q - Vector2(4, 4), Vector2(8, 8)), Color("9FB3CC"))
		var hp: Vector2 = c + world.hero.pos2() * k
		var f: Vector2 = world.hero.facing()
		draw_colored_polygon(PackedVector2Array([hp + f * 10.0, hp + f.orthogonal() * 6.0 - f * 5.0, hp - f.orthogonal() * 6.0 - f * 5.0]), Color.WHITE)


# ---------------------------------------------------------------- Pfeil am Bildrand (Expedition)
## Zeigt zur nächsten passenden Quelle (fehlt am Bauplatz ein Rohstoff) oder rot zur Richtung eines Angriffs.
class EdgeArrow extends Control:
	var world: Node3D

	func _draw() -> void:
		if world == null or world.ended or world.hero == null or world.cam == null:
			return
		var h: Array = world.hint_arrow()
		if h.is_empty():
			return
		var cam: Camera3D = world.cam.cam
		var tp: Vector2 = h[0]
		var w3 := Vector3(tp.x, 0.5, tp.y)
		var vs := size
		var sp: Vector2
		if cam.is_position_behind(w3):
			sp = vs - cam.unproject_position(w3)
		else:
			sp = cam.unproject_position(w3)
		var mid := vs * 0.5
		var m := 70.0
		if sp.x > m and sp.y > m and sp.x < vs.x - m and sp.y < vs.y - m:
			# im Bild: kleiner Pfeil über dem Ziel
			_tri(sp - Vector2(0, 40), Vector2(0, 1), h[1])
			return
		var d := (sp - mid).normalized()
		var kx := (vs.x * 0.5 - m) / maxf(absf(d.x), 0.001)
		var ky := (vs.y * 0.5 - m) / maxf(absf(d.y), 0.001)
		_tri(mid + d * minf(kx, ky), d, h[1])

	func _tri(p: Vector2, d: Vector2, col: Color) -> void:
		var o := d.orthogonal()
		var pts := PackedVector2Array([p + d * 26.0, p - d * 14.0 + o * 20.0, p - d * 14.0 - o * 20.0])
		draw_colored_polygon(pts, Color(0.03, 0.08, 0.16, 0.8))
		var pts2 := PackedVector2Array([p + d * 20.0, p - d * 10.0 + o * 14.0, p - d * 10.0 - o * 14.0])
		draw_colored_polygon(pts2, col)
