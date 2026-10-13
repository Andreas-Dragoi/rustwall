extends Node
## Test der Menü-Bildschirme (res://scenes/ui_test.tscn).
##   --screen=<name> [--tab=<n>] [--hero=<key>] [--st=key:wert,key:wert] [--profile=rich|fresh]
##       [--press=<Knopftext>[,<Knopftext>]] [--wait=<Bilder>] [--shot=<datei.png>]
##   --hud=sel --key=<Gebäude> [--level=<n>] [--stored=<Stunden>]   zeigt nur das Auswahlfenster eines Gebäudes
##   --monkey    öffnet jeden Bildschirm und drückt alle Knöpfe (reiches und frisches Profil)
## Immer mit --selftest starten, dann wird kein Spielstand geschrieben.

const D = preload("res://src/data.gd")
const Screens = preload("res://src/screens.gd")
const UI = preload("res://src/ui.gd")
const Hud = preload("res://src/hud.gd")

const TAB_COUNT := {"heroes": 7, "chests": 1, "workshop": 1, "garage": 1, "social": 3, "clan": 3, "profile": 2, "quests": 1, "expedition": 1, "settings": 1, "shop": 1, "erfolge": 1, "bestiary": 7, "begleiter": 1, "hilfe": 9, "legal": 4, "tagebuch": 7, "saison": 7, "garderobe": 6, "forschung": 3, "rueckblick": 3, "chronik": 2, "tausch": 1, "auto": 2, "modi": 4}
const ORDER := ["heroes", "chests", "workshop", "garage", "social", "clan", "profile", "quests", "expedition", "settings", "shop", "erfolge", "bestiary", "begleiter", "hilfe", "legal", "tagebuch", "saison", "garderobe", "forschung", "rueckblick", "chronik", "tausch", "auto", "modi"]

var scr: CanvasLayer
var presses := 0
var closed_count := 0
var exp_count := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("6E9A2B")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	scr = Screens.new()
	add_child(scr)
	scr.closed.connect(func(): closed_count += 1)
	scr.expedition_requested.connect(func(_a: int, _m: String, _d: int): exp_count += 1)
	if OS.get_cmdline_user_args().has("--monkey"):
		_monkey()
	elif G.arg("hud") != "":
		_hud_window()
	else:
		_single()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# ================================================================= Profile
func _rich() -> void:
	P.debug_setup(6)
	P.social.ensure()
	for t in ["daily", "find", "quest", "level", "boss", "flood_gold", "clan", "gift"]:
		P.add_chest(t, 3)
	for i in 3:
		P.make_item("weapon", "j_rifle", 0)
		P.make_item("weapon", "m_flame", 1)
		P.make_item("helmet", "", 0)
		P.make_item("vest", "", 1)
	P.make_item("weapon", "j_parcel", 2)
	P.make_item("weapon", "y_bow", 3)
	P.make_item("charm", "", 2)
	P.make_item("charm", "", 3)
	P.equip("jona", int(P.d.items[P.d.items.size() - 1].id))
	P.d.badges["jona"] = 12
	P.d.heroes["jona"].talents = [3, 2, 0]
	P.d.cmd = {"wall_hp": 2, "carry": 1}
	P.d.cmd_active = "airstrike"
	P.d.areas.boss[0] = [true, true, false]
	P.d.areas.boss[1] = [true, false, false]
	P.d.stats.kills = 12345
	P.skip_time(0.0)
	P.d.week.last = {"win": true, "stars": 2, "chest": "flood_silver", "lost": {}, "points": 1180, "xp": 200}
	for q in P.d.quests.list:
		q.progress = int(q.amount)
	P.d.quests.list[0].progress = int(int(P.d.quests.list[0].amount) / 2)
	var soc = P.social
	for s in soc.suggestions():
		soc.add_friend(String(s.code))
	soc.join_clan(soc.clan_list()[0])
	soc.s.clan.asks.append({"name": "Flinker Fuchs 22", "res": "wood", "amount": 120})
	soc.s.clan.asks.append({"name": "Kleine Eule 47", "res": "metal", "amount": 80})
	soc.shout(0)
	soc.shout_add("Starker Bär 31", "Gut gemacht!")
	soc._mail("Flinker Fuchs 22", "schickt dir 90 Holz", {"wood": 90}, "", 0)
	soc._mail("Kleine Eule 47", "schickt dir eine Geschenkkiste", {}, "gift", 0)
	soc._mail("Rangliste", "Flut-Rangliste: Platz 7 in Liga Bronze. Aufstieg!", {"shards": 6}, "", 0)
	soc.add_points("flood", 900)
	soc.add_points("explorer", 400)
	soc.submit_time(0, 71.5)
	P.start_auto("mika", 0, 4)
	preload("res://src/tests_basis6.gd").ui_rich()       # V6 Paket B: Werkstatt, Labor, Forschung, Rückblicke
	preload("res://src/tests_modi.gd").ui_rich()         # V6 Paket M: Turm, Überleben, Clan-Raid
	var b: Dictionary = P.d.heroes["bruno"]
	b.auto_until = P.now() - 5.0
	b.auto_area = 1
	b.auto_hours = 4
	P.mark()


func _fresh() -> void:
	P.new_game()
	P.social.ensure()
	P.mark()


# ================================================================= Einzelner Bildschirm
func _single() -> void:
	if G.arg("profile", "rich") == "fresh":
		_fresh()
	else:
		_rich()
	var st := {}
	if G.arg("tab") != "":
		st["tab"] = int(G.arg("tab"))
	if G.arg("hero") != "":
		st["hero"] = G.arg("hero")
	for kv in G.arg("st").split(",", false):
		var p := kv.split(":")
		if p.size() == 2:
			st[p[0]] = int(p[1]) if p[1].is_valid_int() else p[1]
	for kv2 in G.arg("scroll").split(",", false):           # Paket Q: --scroll=set_left:900 (Rollposition für Bilder)
		var p2 := kv2.split(":")
		if p2.size() == 2:
			scr._scroll_pos["%s/%s" % [G.arg("screen", "heroes"), p2[0]]] = int(p2[1])
	scr.open(G.arg("screen", "heroes"), st if not st.is_empty() else null)
	await _frames(3)
	for text in G.arg("press").split(",", false):
		for b in _buttons():
			if UI.btn_get_text(b) == text:
				b.pressed.emit()
				break
		await _frames(3)
	var shot := G.arg("shot")
	if shot == "":
		return
	await _frames(int(G.arg("wait", "20")))
	get_viewport().get_texture().get_image().save_png(shot)
	print("SHOT ", shot, " ", get_viewport().get_visible_rect().size)
	get_tree().quit()


# ================================================================= Auswahlfenster eines Gebäudes (ohne Spielwelt)
func _hud_window() -> void:
	_rich()
	var key := G.arg("key", "saege")
	var b: Dictionary = P._add_building(key, 0, 0, 0, int(G.arg("level", "3")))
	b["last_collect"] = P.now() - float(G.arg("stored", "5")) * 3600.0
	var hud: CanvasLayer = Hud.new()
	add_child(hud)
	var win: Control = hud._sel_window(b)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_bottom", 24)
	win.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	win.size_flags_vertical = Control.SIZE_SHRINK_END
	m.add_child(win)
	hud.root.add_child(m)
	var shot := G.arg("shot")
	if shot == "":
		return
	await _frames(int(G.arg("wait", "40")))
	get_viewport().get_texture().get_image().save_png(shot)
	print("SHOT ", shot, " ", get_viewport().get_visible_rect().size)
	get_tree().quit()


# ================================================================= Affentest
func _collect(n: Node, out: Array) -> void:
	if n is BaseButton and n.is_visible_in_tree() and not n.disabled:
		out.append(n)
	if n is LineEdit and n.text == "":
		n.text = "TESTAB23" if n.max_length == 8 else "Testname"
		n.text_changed.emit(n.text)
	for c in n.get_children():
		_collect(c, out)


func _buttons() -> Array:
	var out: Array = []
	_collect(scr, out)
	return out


func _press(b: BaseButton) -> void:
	presses += 1
	b.pressed.emit()
	await _frames(2)


func _walk(screen: String, st: Dictionary, with_danger: bool) -> void:
	scr.open(screen, st)
	await _frames(2)
	var i := 0
	var guard := 0
	while guard < 300:
		guard += 1
		if not scr.is_open() or scr.screen != screen:
			scr.open(screen, st)
			await _frames(2)
		var bs: Array = []
		for b in _buttons():
			if b.has_meta("tab") or b.has_meta("close"):
				continue
			if b.has_meta("danger") and not with_danger:
				continue
			bs.append(b)
		if i >= bs.size():
			break
		await _press(bs[i])
		i += 1


func _pass(label: String) -> void:
	# 1) jeder Bildschirm, jeder Reiter, alle Knöpfe der Reihe nach
	for screen in ORDER:
		for tab in int(TAB_COUNT[screen]):
			if screen == "heroes":
				for hk in D.HERO_ORDER:
					await _walk(screen, {"tab": tab, "hero": hk}, false)
			else:
				await _walk(screen, {"tab": tab}, false)
		# Reiterknöpfe und Schließen
		scr.open(screen)
		await _frames(2)
		var n_tabs := 0
		for b in _buttons():
			if b.has_meta("tab"):
				n_tabs += 1
		for t in n_tabs:
			var k := 0
			for b in _buttons():
				if b.has_meta("tab"):
					if k == t:
						await _press(b)
						break
					k += 1
		for b in _buttons():
			if b.has_meta("close"):
				await _press(b)
				break
		assert(not scr.is_open(), "Schließen-Knopf schließt nicht")
		await _frames(2)
		assert(scr.get_child_count() == 0, "Nach dem Schließen sind noch Knoten da")
		print("  ", label, " ", screen, " ok, Drücke bisher: ", presses)
	# 2) Argumente als Text
	for e in [["social", "mail"], ["social", "boards"], ["heroes", "greta"], ["heroes", "talents"], ["clan", "shouts"], ["profile", "commander"], ["chests", "boss"], ["garage", "pickup"], ["expedition", 2]]:
		scr.open(String(e[0]), e[1])
		await _frames(2)
	# 3) wildes Drücken quer durch alles, auch Reiter, Schließen und Rückfragen
	scr.open("heroes")
	await _frames(2)
	for i in 500:
		if not scr.is_open():
			scr.open(String(ORDER[_rng.randi() % ORDER.size()]), {"tab": _rng.randi() % 3})
			await _frames(2)
		var bs: Array = []
		for b in _buttons():
			if b.has_meta("close") and _rng.randf() > 0.05:
				continue
			if b.has_meta("danger") and _rng.randf() > 0.02:
				continue
			bs.append(b)
		if bs.is_empty():
			scr.close()
			continue
		await _press(bs[_rng.randi() % bs.size()])
	# 4) gefährliche Knöpfe gezielt (Clan verlassen, Spielstand löschen) samt Rückfrage
	await _walk("clan", {"tab": 0}, true)
	await _walk("settings", {}, true)
	scr.close()
	await _frames(2)


func _monkey() -> void:
	_rng.seed = 4711
	print("MONKEY start")
	_rich()
	await _pass("reich")
	_fresh()
	await _pass("frisch")
	# Esc schließt
	scr.open("quests")
	await _frames(2)
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(3)
	assert(not scr.is_open(), "Esc schließt nicht")
	print("MONKEY OK presses=%d closed=%d expeditions=%d" % [presses, closed_count, exp_count])
	get_tree().quit()
