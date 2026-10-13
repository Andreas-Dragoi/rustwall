extends RefCounted
## Paket L – kleine Oberflächen-Bausteine des Live-Betriebs, die in fremden Menüs sitzen:
## Knopf „Saison“ in der rechten Spalte des HUD, Ereignis-Banner unter den Rohstoffen, Banner im Hauptmenü,
## Albtraum+-Auswahl im Expeditions-Bildschirm.

const D = preload("res://src/data.gd")
const DL = preload("res://src/data_liveops.gd")
const LO = preload("res://src/liveops.gd")
const UI = preload("res://src/ui.gd")


## Offene Belohnungen (Ereignis-Stufen, Pass-Stufen) – für Zähler an Knöpfen.
static func open_count() -> int:
	return LO.event_claimable() + LO.pass_open()


## Ein Knopf, der sich jede Sekunde selbst beschriftet (Timer als Kind).
static func _ticker(c: Control, fn: Callable) -> void:
	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	t.timeout.connect(fn)
	c.add_child(t)
	fn.call()


static func season_button(hud: CanvasLayer) -> Button:
	var b: Button = hud._menu_btn("Saison", "saison", "")
	b.set_meta("guide", "saison")
	_ticker(b, func():
		if not is_instance_valid(b):
			return
		var n := open_count()
		UI.btn_text(b, "Saison (%d)" % n if n > 0 else "Saison")
		UI.btn_kind(b, "gold" if n > 0 else "dark"))
	return b


## Banner mit dem Ereignis der Woche (und dem Feiertag) – Antippen öffnet die Saison-Seite.
static func hud_banner(hud: CanvasLayer, parent: Control) -> void:
	var def := LO.event_def()
	var title := UI.label(String(def.name), 23, (def.col as Color).lightened(0.25))
	var sub := UI.label("", 19, UI.TEXT, false)
	var row := UI.hbox(10, [UI.pic(String(def.icon), 40.0, "ui_star"), UI.vbox(-4, [title, sub])])
	var hk := LO.holiday()
	if hk != "":
		row.add_child(UI.pill(UI.hbox(6, [UI.pic(String(DL.HOLIDAYS[hk].icon), 30.0, "ui_star"), UI.label(String(DL.HOLIDAYS[hk].name), 18, UI.GOLD)]), 10, 3))
	var bang := UI.badge("!", UI.RED, 20)
	row.add_child(bang)
	var p := UI.panel(row, Color(0.07, 0.19, 0.37, 0.9), (def.col as Color).darkened(0.1), 18, 8)
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(func():
		Sfx.play("click", -8.0)
		hud._open("saison", {"tab": 0}))
	p.add_child(btn)
	p.name = "LoBanner"
	parent.add_child(p)
	hud._anchor(p, Control.PRESET_CENTER_TOP, Vector2(0, 104))
	_ticker(p, func():
		if not is_instance_valid(sub):
			return
		var extra := ""
		if bool(LO.event_def().get("community", false)):
			extra = " · %d %%" % int(LO.boss_progress() * 100.0)
		sub.text = ("%s · noch %s" % [String(LO.event_def().effect), UI.time_text(LO.week_left())]) + extra     # keine zwei %s direkt hintereinander (stört die englische Vorlagen-Erkennung)
		bang.visible = LO.event_claimable() > 0)


## Hauptmenü: Ereignis, Saison und neueste Nachricht.
static func menu_banner(menu: CanvasLayer) -> Control:
	var def := LO.event_def()
	var v := UI.vbox(4)
	v.add_child(UI.hbox(10, [UI.pic(String(def.icon), 36.0, "ui_star"), UI.label("%s · noch %s" % [String(def.name), UI.time_text(LO.week_left())], 22, (def.col as Color).lightened(0.3))]))
	var sd := LO.season_def()
	v.add_child(UI.hbox(10, [UI.pic("ui_season", 36.0, "ui_star"), UI.label("Saison %d „%s“ · Pass-Stufe %d · noch %s" % [LO.season_n(), String(sd.name), LO.pass_tier(), UI.time_text(LO.season_left())], 20, UI.TEXT, false)]))
	var nw: Array = LO.news()
	if not nw.is_empty():
		var unread := LO.news_unread()
		v.add_child(UI.hbox(10, [UI.pic("ui_news", 36.0, "ui_info"), UI.label(("Neu: " if unread > 0 else "") + String(nw[0].get("title", "")), 20, UI.GOLD if unread > 0 else UI.TEXT, false)]))
	var p := UI.panel(v, Color(0.05, 0.13, 0.26, 0.85), UI.EDGE, 16, 10)
	p.custom_minimum_size = Vector2(500, 0)
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(func():
		Sfx.play("click", -8.0)
		menu.visible = false
		G.main.screens.open("saison", {"tab": 5}))
	p.add_child(btn)
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.offset_right = -40.0
	p.offset_bottom = -40.0
	return p


## Expeditions-Bildschirm: Albtraum+ (Modifikatoren) unter der Wahl der Schwierigkeit.
static func nightmare_box(S, area: int, diff: int) -> Control:
	var box := UI.vbox(6)
	if diff < 2:
		return box
	if not LO.nm_open(area):
		box.add_child(S.hint("Albtraum+ (Modifikatoren für mehr Beute) gibt es, sobald du den Boss dieses Gebiets auf Albtraum besiegt hast.", 18))
		return box
	var mods: Array = LO.nm_mods()
	var head := UI.hbox(10, [UI.pic("ui_nightmare", 40.0, "ui_skull"), UI.label("Albtraum+", 24, Color("C9A2FF")),
		UI.pill(UI.label(("Beute ×%.2f" % LO.nm_loot(mods)).replace(".", ","), 19, UI.GOLD))])
	box.add_child(head)
	var fl := UI.flow(8)
	for k in DL.NIGHTMARE_ORDER:
		var md: Dictionary = DL.NIGHTMARE_MODS[k]
		var on: bool = k in mods
		var key := String(k)
		var b: Button = S.choice("%s +%d %%" % [String(md.name), int(float(md.loot) * 100.0)], on, S.act(func(): LO.nm_toggle(key)), 19, String(md.icon))
		b.tooltip_text = String(md.text)
		b.custom_minimum_size = Vector2(0, 54)
		fl.add_child(b)
	box.add_child(fl)
	if not mods.is_empty():
		var txt: Array = []
		for k in mods:
			txt.append(String(DL.NIGHTMARE_MODS[k].text))
		box.add_child(S.hint(" · ".join(txt) + " · Erfolg: +%d Sternsplitter" % (DL.NM_SHARDS * mods.size()), 18, Color("C9A2FF")))
	return UI.card(box, Color("2A1E44"), 10, Color("8C5DF2"))
