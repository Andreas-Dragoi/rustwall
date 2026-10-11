extends CanvasLayer
## Alle bildschirmfüllenden Menüs (Helden, Kisten, Werkstatt, Garage, Funkturm, Clan, Profil,
## Aufträge, Expedition, Einstellungen). Wird komplett im Code gebaut.
##
## Aufbau: Diese Datei ist der Rahmen (Abdunklung, Tafel, Kopfzeile, Meldungen, Hilfsbausteine).
## Der Inhalt jedes Bildschirms steckt in einer kleinen Datei unter res://src/screens/.
## Solange kein Bildschirm offen ist, existiert kein einziger Knoten und nichts läuft pro Bild.

signal closed
signal expedition_requested(area: int, mission: String, diff: int)

const D = preload("res://src/data.gd")
const UI = preload("res://src/ui.gd")
const Preview = preload("res://src/screens/preview.gd")

const BUILDERS := {
	"heroes": preload("res://src/screens/heroes.gd"),
	"chests": preload("res://src/screens/chests.gd"),
	"workshop": preload("res://src/screens/workshop.gd"),
	"garage": preload("res://src/screens/garage.gd"),
	"social": preload("res://src/screens/social.gd"),
	"clan": preload("res://src/screens/clan.gd"),
	"profile": preload("res://src/screens/profile.gd"),
	"quests": preload("res://src/screens/quests.gd"),
	"expedition": preload("res://src/screens/expedition.gd"),
	"settings": preload("res://src/screens/settings.gd"),
	"shop": preload("res://src/screens/shop.gd"),
	"erfolge": preload("res://src/screens/erfolge.gd"),
	"bestiary": preload("res://src/screens/bestiary.gd"),
	"begleiter": preload("res://src/screens/begleiter.gd"),
}
const TITLES := {"heroes": "Helden", "chests": "Beutekisten", "workshop": "Werkstatt", "garage": "Garage", "social": "Funkturm",
	"clan": "Clan", "profile": "Profil", "quests": "Aufträge und Flut", "expedition": "Expedition", "settings": "Einstellungen", "shop": "Laden", "erfolge": "Erfolge", "bestiary": "Monsterbuch", "begleiter": "Begleiter"}
## Kopfzeile: Münzen, Bauteile, Sternsplitter und dazu alles, was der Bildschirm ausgibt.
const STRIP_BASE := ["coins", "parts", "shards", "gems"]
const STRIP_EXTRA := {"heroes": ["fuel"], "garage": ["metal", "fuel", "cells"], "social": ["wood", "stone", "metal", "fuel"],
	"clan": ["wood", "stone", "metal", "fuel"], "expedition": ["fuel"], "settings": ["wood", "stone", "metal", "fuel", "cells"],
	"begleiter": ["wood", "stone", "metal", "fuel", "cells"]}
const PANEL_MAX_W := 2040.0
## Bildzeichen in der Kopfzeile
const HEAD_ICON := {"heroes": "ui_helmet", "chests": "ui_chest", "workshop": "ui_hammer", "garage": "ui_garage", "social": "ui_mail",
	"clan": "ui_clan", "profile": "ui_badge", "quests": "ui_quest", "expedition": "ui_expedition", "settings": "ui_gear", "shop": "res_gems", "erfolge": "ui_trophy", "bestiary": "e_0", "begleiter": "comp_kistenbein"}
const SIM_NOTICE := "Mitspieler sind in dieser Version simuliert. Für echtes Online-Spiel wird ein Server benötigt."

var screen := ""
var st: Dictionary = {}            # Zustand des offenen Bildschirms (Reiter, Auswahl ...)

var _root: Control
var _margin: MarginContainer
var _body: MarginContainer
var _strip: HBoxContainer
var _toasts: VBoxContainer
var _overlay: Control
var _builder: RefCounted
var _preview: Control
var _live: Array = []
var _scroll_pos: Dictionary = {}
var _refresh_queued := false
var _strip_queued := false
var _frame: Control
var _head_margin: MarginContainer
var _pulse_next := false            # die gerade angetippte Listenzeile pulsiert nach dem Neuaufbau einmal
var _fresh_next := false            # nach Reiterwechsel laufen Balken wieder von 0 hoch


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(false)


# ================================================================= Öffentliche Schnittstelle
## screen: heroes | chests | workshop | garage | social | clan | profile | quests | expedition | settings
## arg: Reitername oder Schlüssel (z. B. "mail", Heldenschlüssel) oder ein Dictionary mit Zustandswerten.
func open(screen_name: String, arg = null) -> void:
	if not BUILDERS.has(screen_name):
		push_warning("Unbekannter Bildschirm: " + screen_name)
		return
	_teardown()
	screen = screen_name
	st = {}
	if arg is Dictionary:
		st = arg.duplicate()
	_build_shell()
	set_process_input(true)
	_builder = BUILDERS[screen].new()
	_builder.S = self
	if _builder.has_method("setup"):
		_builder.setup(arg)
	P.toast.connect(toast)
	P.resources_changed.connect(_update_strip)
	P.changed.connect(_update_strip)
	UI.sfx("ui_open", "", -6.0)
	_fresh_next = true
	_do_refresh()
	UI.pop_in(_frame, 0.95, 0.18)


func close() -> void:
	if not is_open():
		return
	UI.sfx("ui_close", "", -8.0)
	_teardown()
	screen = ""
	set_process_input(false)
	closed.emit()


func is_open() -> bool:
	return _root != null


# ================================================================= Rahmen
func _teardown() -> void:
	if _root == null:
		return
	if P.toast.is_connected(toast):
		P.toast.disconnect(toast)
		P.resources_changed.disconnect(_update_strip)
		P.changed.disconnect(_update_strip)
	if _preview and is_instance_valid(_preview):
		if _preview.get_parent() == null:
			_preview.free()
		_preview = null
	_live.clear()
	_scroll_pos.clear()
	_builder = null
	_overlay = null
	_refresh_queued = false
	_strip_queued = false
	_strip = null
	_frame = null
	_head_margin = null
	_pulse_next = false
	UI.forget()
	remove_child(_root)
	_root.queue_free()
	_root = null


func _build_shell() -> void:
	_root = Control.new()
	_root.theme = UI.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	# tiefblauer Verlauf über die ganze Fläche
	var g := Gradient.new()
	g.set_color(0, UI.BG_TOP)
	g.set_color(1, UI.BG_BOT)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 8
	gt.height = 128
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var bg := TextureRect.new()
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(bg)

	_frame = UI.vbox(0)
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_frame)
	# ---- Kopfzeile: Bild, großer Titel, Rohstoffe, rotes X
	var head_row := UI.hbox(18)
	var hi := UI.pic(String(HEAD_ICON.get(screen, "ui_star")), 76.0)
	head_row.add_child(hi)
	var title := UI.label(String(TITLES[screen]), 62)
	title.add_theme_constant_override("outline_size", 12)
	head_row.add_child(title)
	head_row.add_child(UI.spacer(true))
	_strip = UI.hbox(12)
	_strip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head_row.add_child(_strip)
	var x := UI.button("", close, "red", 30, "ui_close")
	x.custom_minimum_size = Vector2(96, 82)
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	x.set_meta("close", true)
	head_row.add_child(x)
	_head_margin = UI.margin(head_row, 24, 8, 24, 8)
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", UI.grad(Color("1D4C92"), Color("123469"), Color(0, 0, 0, 0), 0, 0))
	head.custom_minimum_size = Vector2(0, 104)
	head.add_child(_head_margin)
	_frame.add_child(head)
	_frame.add_child(UI.sep(false, Color(UI.SKY, 0.55)))
	_margin = MarginContainer.new()
	_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_frame.add_child(_margin)
	_body = MarginContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_margin.add_child(_body)

	_toasts = UI.vbox(8)
	_toasts.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toasts.offset_bottom = -34
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(_toasts)

	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_tick_live)
	_root.add_child(timer)
	_root.resized.connect(_fit)
	_fit()
	_do_update_strip()


## Der Bildschirm füllt die ganze Fläche; auf sehr breiten Bildflächen bleibt der Inhalt mittig.
func _fit() -> void:
	if _root == null:
		return
	var vs := _root.size
	var mx := int(maxf(22.0, (vs.x - PANEL_MAX_W) * 0.5))
	_margin.add_theme_constant_override("margin_left", mx)
	_margin.add_theme_constant_override("margin_right", mx)
	_margin.add_theme_constant_override("margin_top", 16)
	_margin.add_theme_constant_override("margin_bottom", 16)
	_head_margin.add_theme_constant_override("margin_left", mx)
	_head_margin.add_theme_constant_override("margin_right", mx)


func _update_strip() -> void:
	if _root == null or _strip_queued:
		return
	_strip_queued = true
	_do_update_strip.call_deferred()


func _do_update_strip() -> void:
	_strip_queued = false
	if _root == null:
		return
	UI.clear(_strip)
	var list: Array = STRIP_BASE.duplicate()
	list.append_array(STRIP_EXTRA.get(screen, []))
	for r in list:
		var chip := UI.pill(UI.res_chip(String(r), P.res(String(r)), 28))
		chip.tooltip_text = String(D.RES_NAME[r])
		_strip.add_child(chip)


func _input(ev: InputEvent) -> void:
	if _root == null:
		return
	if ev.is_action_pressed("pause") or ev.is_action_pressed("ui_cancel"):
		# beim Tippen in ein Eingabefeld gehört "P" zum Text
		var foc := _root.get_viewport().gui_get_focus_owner()
		if foc is LineEdit and ev is InputEventKey and ev.physical_keycode != KEY_ESCAPE:
			return
		get_viewport().set_input_as_handled()
		if _overlay and is_instance_valid(_overlay):
			_close_overlay()
		else:
			close()


func _tick_live() -> void:
	for i in range(_live.size() - 1, -1, -1):
		var e: Array = _live[i]
		if not is_instance_valid(e[0]):
			_live.remove_at(i)
			continue
		var r = e[1].call()
		if r is String:
			e[0].text = r


# ================================================================= Inhalt neu aufbauen
## Baut den Inhalt im nächsten Bild neu auf (mehrere Aufrufe werden zusammengefasst).
func refresh() -> void:
	if _root == null or _refresh_queued:
		return
	_refresh_queued = true
	_do_refresh.call_deferred()


func _do_refresh() -> void:
	_refresh_queued = false
	if _root == null or _builder == null:
		return
	_live.clear()
	if _preview and is_instance_valid(_preview) and _preview.get_parent():
		_preview.get_parent().remove_child(_preview)
	UI.clear(_body)
	UI.fresh = _fresh_next
	var content: Control = _builder.build()
	UI.fresh = false
	_fresh_next = false
	_pulse_next = false
	if content:
		_body.add_child(content)
	if _preview and is_instance_valid(_preview) and _preview.get_parent() == null:
		_preview.free()
		_preview = null
	_update_strip()


## Liefert eine Funktion, die erst cb ausführt und dann den Inhalt neu aufbaut.
func act(cb: Callable) -> Callable:
	return func():
		cb.call()
		refresh()


func set_st(key: String, val) -> Callable:
	return func():
		st[key] = val
		refresh()


# ================================================================= Meldungen und Rückfragen
func toast(text: String) -> void:
	if _root == null or text == "":
		return
	while _toasts.get_child_count() >= 3:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var p := UI.panel(UI.hbox(12, [UI.pic("ui_info", 34.0, "", UI.GOLD), UI.label(text, 26)]), UI.NAVY_D, UI.GOLD, 18, 14)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.ignore_mouse(p)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toasts.add_child(p)
	UI.sfx("ui_toast", "", -10.0)
	UI.pulse(p, 1.06)
	var tw := p.create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


## Zeigt das Ergebnis einer Aktion: leerer Text = Erfolg (ok_text), sonst der Grund.
func say(why: String, ok_text := "") -> bool:
	if why != "":
		UI.sfx("ui_error", "error", -6.0)
		toast(why)
		return false
	if ok_text != "":
		toast(ok_text)
	return true


func confirm(text: String, yes_cb: Callable, yes_text := "Ja") -> void:
	if _root == null:
		return
	_close_overlay()
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(cc)
	var t := UI.text(text, 30, UI.WHITE, 620.0)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var yes := UI.button(yes_text, func():
		_close_overlay()
		yes_cb.call()
		refresh(), "red")
	yes.custom_minimum_size = Vector2(220, 72)
	var no := UI.button("Abbrechen", _close_overlay, "dark")
	no.custom_minimum_size = Vector2(220, 72)
	var row := UI.hbox(24, [no, yes])
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var box := UI.panel(UI.vbox(26, [t, row]), UI.NAVY, UI.GOLD, 26, 34)
	cc.add_child(box)
	_root.add_child(_overlay)
	UI.pop_in(box, 0.9, 0.16)


func _close_overlay() -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


## Schließt den Bildschirm (Signal "closed") und meldet danach die gewünschte Expedition.
func request_expedition(area: int, mission: String, diff: int) -> void:
	close()
	expedition_requested.emit(area, mission, diff)


# ================================================================= Bausteine für die Bildschirme
## Reiterleiste mit Bildzeichen. Die Auswahl steht in st[key]. icons: Namen wie bei UI.pic().
func tabs(names: Array, key := "tab", size := 24, icons: Array = []) -> HFlowContainer:
	var f := UI.flow(10)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cur := int(st.get(key, 0))
	for i in names.size():
		var b := UI.tab_button(String(names[i]), String(icons[i]) if i < icons.size() else "", i == cur, func():
			if int(st.get(key, 0)) != i:
				UI.sfx("ui_tab", "", -8.0)
				_fresh_next = true
			st[key] = i
			refresh(), size)
		f.add_child(b)
	return f


## Auswahlknöpfe in einer Reihe (Schwierigkeit, Dauer …): ausgewählt = Gold.
func choice(text: String, selected: bool, cb: Callable, size := 22, icon_name := "") -> Button:
	var b := UI.button(text, func():
		UI.sfx("ui_select", "", -8.0)
		cb.call(), "tab_on" if selected else "tab", size, icon_name)
	b.custom_minimum_size.y = 64
	return b


## Rollbereich, der seine Position über Neuaufbauten hinweg behält.
func scroll(inner: Control, key: String, min_size := Vector2.ZERO) -> ScrollContainer:
	# rechts Platz für den Rollbalken lassen
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_right", 12)
	wrap.add_child(inner)
	var sc := UI.scroll(wrap, min_size)
	var full_key := "%s/%s" % [screen, key]
	var want := int(_scroll_pos.get(full_key, 0))
	sc.get_v_scroll_bar().value_changed.connect(func(v: float): _scroll_pos[full_key] = int(v))
	if want > 0:
		sc.ready.connect(func():
			await sc.get_tree().process_frame
			if is_instance_valid(sc):
				sc.scroll_vertical = want)
	return sc


## Text, der jede Sekunde neu berechnet wird (Restzeiten).
func live(l: Label, fn: Callable) -> Label:
	l.text = String(fn.call())
	_live.append([l, fn])
	return l


## Wie live(), aber fn darf alles tun (z. B. neu aufbauen, wenn eine Zeit abgelaufen ist).
func every_second(owner_node: Node, fn: Callable) -> void:
	_live.append([owner_node, fn])


func head(text: String, size := 30) -> Label:
	return UI.label(text, size, UI.GOLD)


func hint(text: String, size := 22, col := UI.GREY) -> Label:
	return UI.text(text, size, col)


func kv(k: String, v: String, size := 24, vcol := UI.GOLD) -> HBoxContainer:
	var a := UI.label(k, size, UI.TEXT, false)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return UI.hbox(12, [a, UI.label(v, size, vcol)])


func notice_sim() -> Control:
	var l := UI.text(SIM_NOTICE, 20, Color("FFE2A8"))
	return UI.card(UI.hbox(12, [UI.pic("ui_info", 30.0, "", UI.ORANGE), l]), Color("4A3A1C"), 8, Color(UI.ORANGE, 0.7))


func rarity_color(r: int) -> Color:
	return D.RARITY[clampi(r, 0, 3)].color


## Punktreihe für Ränge (n von mx).
func pips(n: int, mx: int, col := UI.GREEN, size := 16.0) -> HBoxContainer:
	return UI.pips(n, mx, col, size)


## Große Schaltfläche mit eigenem Inhalt (Listeneinträge zum Antippen). Ausgewählt = goldener Verlauf.
func card_button(selected: bool, cb: Callable, content: Control, min_h := 88.0, kind := "dark") -> Button:
	var b := UI.row_button(selected, func():
		if not selected:
			UI.sfx("ui_select", "", -8.0)
			_pulse_next = true
		cb.call(), content, min_h, "" if kind == "dark" else kind)
	if selected and _pulse_next:
		UI.pulse(b, 1.035)
	return b


func _ignore_mouse(n: Node) -> void:
	UI.ignore_mouse(n)


## Farbiger Punkt / Kästchen als einfaches Bildzeichen.
func swatch(col: Color, size := 44.0, radius := 12) -> Panel:
	var c := Panel.new()
	c.custom_minimum_size = Vector2(size, size)
	c.add_theme_stylebox_override("panel", UI.grad(col.lightened(0.2), col.darkened(0.12), col.lightened(0.45), radius, 3, 0, 0, Color.BLACK, 0, Color.BLACK, 0.25))
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Name, Seltenheit, Stufe und Werte eines Gegenstands.
func item_info(it: Dictionary, size := 24) -> VBoxContainer:
	var r := int(it.rarity)
	var v := UI.vbox(2)
	var nm := UI.label(P.item_name(it), size, rarity_color(r))
	nm.clip_text = true
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(nm)
	var lines: Array = P.item_lines(it)
	var sub := "%s · Stufe %d/%d" % [String(D.RARITY[r].name), int(it.level), int(D.RARITY[r].max_level)]
	v.add_child(UI.label(sub, size - 5, UI.GREY, false))
	var lt := UI.label(", ".join(lines), size - 5, Color("DCE8F5"), false)
	lt.clip_text = true
	lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(lt)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v


func slot_name(it: Dictionary) -> String:
	if it.slot == "weapon":
		return String(D.WEAPONS[it.key].kind)
	return String(D.GEAR[it.slot].name)


# ----------------------------------------------------------------- 3D-Vorschau (höchstens eine)
func _get_preview(sig: String) -> Control:
	if _preview and is_instance_valid(_preview):
		if _preview.get_parent():
			_preview.get_parent().remove_child(_preview)
		if _preview.sig == sig:
			return _preview
	else:
		_preview = Preview.new()
	_preview.sig = ""
	return _preview


func preview_hero(key: String) -> Control:
	var h: Dictionary = P.hero(key)
	var tier := clampi(int(int(h.level) / 10), 0, 3)
	var wk := ""
	var it: Dictionary = P.item(int(h.weapon))
	if not it.is_empty():
		wk = String(it.key)
	var sig := "hero:%s:%d:%s" % [key, tier, wk]
	var pv := _get_preview(sig)
	if pv.sig != sig:
		pv.show_hero(key, tier, wk)
		pv.sig = sig
	return pv


## Wie preview_hero(), aber der Held hält eine bestimmte Waffe (Werkstatt).
func preview_hero_with(key: String, weapon_key: String) -> Control:
	var tier := clampi(int(int(P.hero(key).level) / 10), 0, 3)
	var sig := "hero:%s:%d:%s" % [key, tier, weapon_key]
	var pv := _get_preview(sig)
	if pv.sig != sig:
		pv.show_hero(key, tier, weapon_key)
		pv.sig = sig
	return pv


func preview_model(sig: String, maker: Callable, dist: float, height: float) -> Control:
	var pv := _get_preview(sig)
	if pv.sig != sig:
		pv.show_model(maker.call(), dist, height)
		pv.sig = sig
	return pv


func preview_cheer() -> void:
	if _preview and is_instance_valid(_preview):
		_preview.cheer()
