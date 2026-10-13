extends CanvasLayer
## Admin-Menü zum Testen. Öffnen und schließen mit der Taste "-" (Minus) oder "," (Komma).
## Schalter gelten nur für die laufende Sitzung (G.cheat) und werden nicht gespeichert;
## Aktionen wie "Gegenstände geben" oder "Alles freischalten" ändern den Spielstand dauerhaft.

const D = preload("res://src/data.gd")
const UI = preload("res://src/ui.gd")
const Weather = preload("res://src/weather.gd")

const TOGGLES := [
	["god", "Gottmodus (Held unverwundbar)"],
	["god_base", "Basis unverwundbar"],
	["onehit", "Ein Treffer genügt"],
	["ammo", "Unendlich Munition"],
	["nocd", "Fähigkeiten ohne Abklingzeit (alle frei)"],
	["fast", "Held doppelt so schnell"],
	["free", "Keine Ressourcen nötig (alles kostenlos)"],
	["instant", "Sofort bauen (keine Bauzeit, auch Mauern und Schmuck)"],
	["freegems", "Beschleunigen kostet nichts"],
	["store_test", "Laden im Testbetrieb (Käufe ohne Geld)"],
	["nolimit", "Keine Grenzen (Bunker-Stufe, Höchstzahl, Drohnen, Gebiete)"],
]

var _root: Control
var _box: VBoxContainer
var _sc: ScrollContainer
var _spawn_type := 0
var _rarity := 3
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()


func is_open() -> bool:
	return _root != null


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k == KEY_MINUS or k == KEY_COMMA or k == KEY_KP_SUBTRACT or event.unicode == 45 or event.unicode == 44:
			if get_viewport().gui_get_focus_owner() is LineEdit:
				return
			toggle()
			get_viewport().set_input_as_handled()
		elif k == KEY_B and _root != null and not (get_viewport().gui_get_focus_owner() is LineEdit):
			finish_under_mouse()
			_refill()


func toggle() -> void:
	if _root != null:
		_root.queue_free()
		_root = null
		return
	_root = MarginContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UI.theme()
	for m in ["margin_left", "margin_top", "margin_bottom"]:
		_root.add_theme_constant_override(m, 20)
	add_child(_root)
	_box = UI.vbox(8)
	var sc := UI.scroll(_box, Vector2(600, 0))
	_sc = sc
	var head := UI.hbox(10, [UI.label("Admin-Menü", 34, UI.GOLD), UI.spacer(true), UI.button("X", toggle, "red", 24)])
	var p := UI.panel(UI.vbox(8, [head, UI.label("Taste - oder , schließt · Schalter gelten bis zum Beenden", 18, UI.GREY), sc]), Color(0.06, 0.15, 0.26, 0.96), UI.PURPLE, 22, 14)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.custom_minimum_size = Vector2(640, 0)
	_root.add_child(p)
	_fill()


func _say(t: String) -> void:
	P.toast.emit("Admin: " + t)


func _section(t: String) -> void:
	_box.add_child(UI.label(t, 24, UI.SKY))


func _row(items: Array) -> void:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 8)
	h.add_theme_constant_override("v_separation", 8)
	for i in items:
		h.add_child(i)
	_box.add_child(h)


func _btn(t: String, cb: Callable, kind := "dark") -> Button:
	return UI.button(t, func():
		cb.call()
		_refill(), kind, 20)


func _refill() -> void:
	if _root != null:
		_fill.call_deferred()


func _fill() -> void:
	if _root == null:
		return
	var keep := _sc.scroll_vertical
	UI.clear(_box)
	var w = G.main.world
	_section("Schalter")
	for t in TOGGLES:
		var key: String = t[0]
		var on := G.ch(key)
		_row([_btn(("AN   " if on else "AUS  ") + t[1], func(): set_cheat(key, not G.ch(key)), "green" if on else "dark")])
	_row([_btn("Alle an", func(): all_cheats(true), "green"), _btn("Alle aus", func(): all_cheats(false), "red")])
	_section("Zeit")
	var sp: Array = []
	for s in [0.5, 1.0, 2.0, 4.0, 8.0]:
		var sv: float = s
		sp.append(_btn("Tempo ×%s" % str(sv), func(): set_speed(sv), "gold" if is_equal_approx(Engine.time_scale, sv) else "dark"))
	_row(sp)
	_row([_btn("+1 Stunde", func(): skip(3600.0)), _btn("+1 Tag", func(): skip(86400.0)), _btn("Zum Fluttag", to_flood_day), _btn("Alle laufenden Bauten fertigstellen", func(): P.speed_up_builds(1.0e9), "green")])
	_row([UI.label("Taste B: Bau unter dem Mauszeiger fertigstellen", 18, UI.GREY)])
	_section("Kampf")
	_row([_btn("Flut jetzt", func(): start_flood(false), "red"), _btn("Übung jetzt", func(): start_flood(true), "red"), _btn("Kampf gewinnen", win_now, "green"), _btn("Alle Gegner besiegen", kill_all)])
	# Arten nach Familie gruppiert (je Familie eine Zeile, Boss am Ende)
	for fam in D.AREA_FAMILY:
		var types: Array = [UI.label(String(D.FAMILIES[fam].name).split(" ")[0], 18, UI.GREY)]
		for i in D.ENEMIES.size():
			if String(D.ENEMIES[i].family) != fam or String(D.ENEMIES[i].role) == "object":
				continue
			var ti: int = i
			types.append(_btn(D.ENEMIES[i].name, func(): _spawn_type = ti, "gold" if i == _spawn_type else "dark"))
		_row(types)
	_row([_btn("1 spawnen", func(): spawn(_spawn_type, 1)), _btn("10 spawnen", func(): spawn(_spawn_type, 10)), _btn("50 spawnen", func(): spawn(_spawn_type, 50)), _btn("Gemischte Horde (80)", func(): spawn(-1, 80))])
	_row([_btn("Held heilen", heal), _btn("Münzen regnen", func(): rain_coins())])
	_row([_btn("Weltboss: Schleim-Leviathan", world_boss, "red"), _btn("Miniboss rufen", func(): special_spawn("mini")), _btn("Elite rufen", func(): special_spawn("elite"))])
	if w != null and w.mode == "exp":
		_row([_btn("Rucksack füllen", fill_pack), _btn("Heimkehren (Sieg)", win_now, "green"), _btn("Phase überspringen", skip_phase), _btn("Außenbasis fertig", outpost_done, "gold")])
		_row([_btn("Gebiets-Ereignis an/aus", func():           # Paket Welt
			w.admin_event()
			_say("Ereignis: %s" % (w.welt.event_key() if w.welt.event_active() else "aus"))), _btn("Alle Werkzeuge", func():
			for tk in preload("res://src/data_welt.gd").TOOLS:
				preload("res://src/welt_state.gd").give_tool(tk)
			_say("Alle Werkzeuge"))])
	_section("Außenbasen")
	var sg := P.outpost_besieged()
	_row([_btn("Belagerung AN" if sg != "" else "Belagerung aus", toggle_siege, "red" if sg != "" else "dark"), _btn("Alle Außenbasen Stufe 1", func(): outposts_all(1)), _btn("Alle Außenbasen Stufe 5", func(): outposts_all(5), "gold"), _btn("Lieferung jetzt", deliver_now)])
	_section("Ressourcen und Stufen")
	_row([_btn("Alle Ressourcen voll", fill_res, "gold"), _btn("+10 000 Münzen", func(): give_res("coins", 10000)), _btn("+500 Bauteile", func(): give_res("parts", 500)), _btn("+100 Sternsplitter", func(): give_res("shards", 100))])
	_row([_btn("+100 Juwelen", func(): P.add_gems(100, "Admin")), _btn("+1 000 Juwelen", func(): P.add_gems(1000, "Admin")), _btn("Tägliches Geschenk zurücksetzen", reset_daily), _btn("Hindernisse wachsen lassen", func(): P._grow_obstacles(true))])
	_row([_btn("Spielerstufe +1", func(): add_levels(1)), _btn("Spielerstufe +10", func(): add_levels(10)), _btn("Held +1 Stufe", func(): hero_levels(1)), _btn("Held +5 Stufen", func(): hero_levels(5)), _btn("Alle Helden Höchststufe", heroes_max), _btn("+100 Abzeichen", badges)])
	_row([_btn("Bunker +1", func(): bunker(P.bunker_level() + 1)), _btn("Bunker Stufe 10", func(): bunker(10)), _btn("Alle Gebäude +1 Stufe", buildings_up)])
	_section("Gegenstände")
	var rr: Array = []
	for i in D.RARITY.size():
		var ri: int = i
		rr.append(_btn(D.RARITY[i].name, func(): _rarity = ri, "gold" if i == _rarity else "dark"))
	_row(rr)
	_row([_btn("Waffen des Helden", give_weapons), _btn("Waffen aller Helden", func(): give_weapons(true)), _btn("Ausrüstung", give_gear), _btn("Gegenstände auf Höchststufe", max_items)])
	_row([_btn("+3 von jeder Kiste", give_chests, "gold"), _btn("Alle Waffen + Baupläne", give_arsenal, "gold")])
	_section("Freischalten")
	_row([_btn("ALLES freischalten", unlock_all, "purple"), _btn("Alle Helden", unlock_heroes), _btn("Alle Fahrzeuge", unlock_vehicles), _btn("Alle Gebiete", unlock_areas)])
	_row([_btn("Aufträge erfüllen", finish_quests), _btn("Testbasis (Bunker 6)", func(): test_base(6)), _btn("Testbasis (Bunker 10)", func(): test_base(10))])
	_row([_btn("Tageszeit: " + (Weather.force if Weather.force != "" else "Uhr"), cycle_daytime), _btn("Regen jetzt / aus", toggle_rain)])
	_row([_btn("Alle Begleiter geben", give_companions, "gold"), _btn("Begleiter +1 Stufe", companion_level)])
	preload("res://src/liveops_admin.gd").fill(self)        # Paket L: Live-Betrieb
	preload("res://src/basis_admin.gd").fill(self)          # V6 Paket B: Forschung, Wetter, Schäden, Verletzte
	_sc.set_deferred("scroll_vertical", keep)


# ================================================================= Aktionen
func set_cheat(key: String, on: bool) -> void:
	G.cheat[key] = on
	if G.main.hud != null:
		G.main.hud._rebuild()


func all_cheats(on: bool) -> void:
	for t in TOGGLES:
		G.cheat[t[0]] = on
	G.main.hud._rebuild()
	_say("alle Schalter " + ("an" if on else "aus"))


func set_speed(s: float) -> void:
	Engine.time_scale = s
	Engine.max_physics_steps_per_frame = 40 if s > 1.0 else 8
	_say("Tempo ×%s" % str(s))


func skip(sec: float) -> void:
	P.skip_time(sec)
	_say("Uhr vorgestellt um " + UI.time_text(sec))


func to_flood_day() -> void:
	if bool(P.d.week.flood_done):
		P.d.week.flood_done = false
	var days := D.FLOOD_DAY - P.week_day()
	if days > 0:
		P.skip_time(days * 86400.0)
	_say("Tag %d – die Flut kann gestartet werden" % P.week_day())


func start_flood(practice: bool) -> void:
	var w = G.main.world
	if w == null or w.mode != "peace":
		_say("geht nur in der Basis im Friedensbetrieb")
		return
	if not practice:
		P.d.week.flood_done = false
	w.start_flood(practice)


func win_now() -> void:
	var w = G.main.world
	if w == null or w.mode == "peace" or w.ended:
		_say("es läuft kein Kampf")
		return
	if w.mode == "exp":
		w._finish(true)
	else:
		w._queue.clear()
		kill_all()
		w.wave_idx = w.wave_count
		w._finish(true)


func kill_all() -> void:
	var w = G.main.world
	if w == null or w.horde == null:
		return
	var n := 0
	for e in w.horde.list.duplicate():
		if e.st != 2:
			e.shield = 0
			e.revived = true
			e.no_split = true
			e.inv = 0.0
			e.under = false
			e.next_phase = ""
			w.horde.damage(e, 1.0e9, Vector2.ZERO, true, true)
			n += 1
	_say("%d Gegner besiegt" % n)


## t = -1: gemischt. Spawnt rund um den Helden; in der Basis laufen sie zum Bunker.
func spawn(t: int, n: int) -> void:
	var w = G.main.world
	if w == null or w.mode == "peace" or w.ended:
		_say("Gegner gibt es nur im Kampf – starte „Flut jetzt“, „Übung jetzt“ oder eine Expedition")
		return
	var pp: Vector2 = w.hero.pos2()
	var made := 0
	for i in n:
		var tt := t
		if tt < 0:
			tt = _rng.randi() % D.E_BOSS
		var a := _rng.randf() * TAU
		var q := pp + Vector2(cos(a), sin(a)) * _rng.randf_range(10.0, 16.0)
		if w.field.is_solid(q) or not w.field.in_bounds(q, 4.0):
			q = pp + Vector2(cos(a), sin(a)) * 5.0
			if w.field.is_solid(q):
				continue
		var e = w.horde.spawn(tt, q, 1.0, 1.0, 1.0)
		if tt == D.E_BOSS:
			e.special = ["summon", "spit", "slam"][_rng.randi() % 3]
		if w.mode == "exp" and w.goal_structure == null:
			e.home = pp
			e.leash = 12.0
			e.aggro = true
		made += 1
	_say("%d × %s" % [made, D.ENEMIES[t].name if t >= 0 else "gemischt"])


func heal() -> void:
	var w = G.main.world
	if w != null and w.hero != null:
		if not w.hero.alive:
			w.hero._do_respawn()
		w.hero.hp = w.hero.max_hp
		w.hero.refill()


func rain_coins() -> void:
	var w = G.main.world
	if w != null and w.coins != null:
		for i in 12:
			w.coins.drop(w.hero.pos2() + Vector2(_rng.randf_range(-5, 5), _rng.randf_range(-5, 5)), 10)


func fill_pack() -> void:
	var w = G.main.world
	if w == null or w.mode != "exp":
		return
	w.fill_pack()
	_say("Rucksack voll")


## Expedition: zur nächsten Phase springen (Ankommen → Aufbauen → Großangriff → Erkunden).
func skip_phase() -> void:
	var w = G.main.world
	if w == null or w.mode != "exp" or w.ended:
		return
	w.admin_skip_phase()
	_say("Phase: %s" % w.phase_name())
	_refill()


## Außenbasis des laufenden Gebiets (in der Basis: Grüntal) sofort auf Stufe 1 bzw. eine Stufe höher.
func outpost_done() -> void:
	var w = G.main.world
	if w != null and w.mode == "exp" and not w.ended:
		w.admin_outpost_done()
		_say("Außenbasis fertig")
		return
	var ak := String(D.AREAS[0].key)
	P.outpost_set_level(ak, P.outpost_level(ak) + 1)
	_say("Außenbasis Grüntal: Stufe %d" % P.outpost_level(ak))


func outposts_all(lv: int) -> void:
	for a in D.AREAS:
		P.outpost_set_level(String(a.key), lv)
	_say("Alle Außenbasen Stufe %d" % lv)


## Belagerung an (am höchsten ausgebaute Außenbasis) bzw. aus.
func toggle_siege() -> void:
	var sg := P.outpost_besieged()
	if sg != "":
		P.outpost_relieve(sg)
		_say("Belagerung beendet")
	else:
		var k := P.outpost_flood(false, int(P.d.week.number), 0.0)
		_say("Belagert: %s" % (k if k != "" else "keine Außenbasis vorhanden"))
	_refill()


func deliver_now() -> void:
	for ak in P.d.outposts:
		P.d.outposts[ak].last_delivery = P.day_index() - 1
	P.outpost_deliveries()
	_say("Lieferungen am Lager")


func fill_res() -> void:
	for r in D.RES:
		if r == "gems":
			continue
		P.d.res[r] = P.cap(r) if (D.CAP_BASE.has(r) or r == "coins") else maxi(P.res(r), 9999)
	P.resources_changed.emit()
	P.mark()
	_say("alle Ressourcen aufgefüllt")


func give_res(r: String, n: int) -> void:
	P.d.res[r] = P.res(r) + n
	P.resources_changed.emit()
	P.mark()


func add_levels(n: int) -> void:
	for i in n:
		if int(P.d.level) >= D.MAX_LEVEL:
			break
		P.add_xp(D.xp_need(int(P.d.level)) - float(P.d.xp) + 1.0)
	_say("Spielerstufe %d" % int(P.d.level))
	P.changed.emit()


func hero_levels(n: int) -> void:
	var hk := String(P.d.hero_sel)
	var h: Dictionary = P.d.heroes[hk]
	h.level = mini(D.HERO_MAX_LEVEL, int(h.level) + n)
	h.xp = 0
	P._grant_start_weapons(hk)
	P.mark()
	G.main.reload_hero()
	_say("%s ist Stufe %d" % [D.HEROES[hk].name, int(h.level)])


func heroes_max() -> void:
	for hk in D.HERO_ORDER:
		P.d.heroes[hk].level = D.HERO_MAX_LEVEL
		P.d.heroes[hk].xp = 0
		P._grant_start_weapons(hk)
	P.mark()
	G.main.reload_hero()
	_say("alle Helden auf Stufe %d" % D.HERO_MAX_LEVEL)


func reset_daily() -> void:
	P.d.daily_gift.day = -1
	for p in P.d.pickups.duplicate():
		if p.kind == "daily":
			P.d.pickups.erase(p)
	P._check_daily()
	_say("tägliches Geschenk liegt am Bunker")


## Taste B (bei offenem Admin-Menü): stellt den Bau unter dem Mauszeiger fertig.
func finish_under_mouse() -> void:
	var w = G.main.world
	if w == null or w.mode != "peace":
		return
	var g = w.cam.mouse_ground()
	if g == null:
		return
	var c: Vector2i = w.world_to_cell(Vector2(g.x, g.z))
	var occ: Dictionary = P.occupancy()
	var k := c.x + c.y * 64
	if occ.has(k):
		var b: Dictionary = P.get_building(int(occ[k]))
		if P.is_building(b):
			for p in (P.job_pieces(int(b.get("job", 0))) if int(b.get("job", 0)) > 0 else [b]):
				p.done_at = P.now()
			P._time_passed()
			_say("%s fertiggestellt" % D.BUILDINGS[b.key].name)


func badges() -> void:
	for hk in D.HERO_ORDER:
		P.d.badges[hk] = int(P.d.badges[hk]) + 100
	P.mark()


func bunker(lv: int) -> void:
	var b := P.bunker()
	b.level = clampi(lv, 1, 10)
	b.done_at = 0.0
	b.up = false
	P.buildings_changed.emit()
	P.resources_changed.emit()
	P.mark()
	G.main.hud._rebuild()
	_say("Bunker Stufe %d" % int(b.level))


func buildings_up() -> void:
	for b in P.d.buildings:
		var cat: String = D.BUILDINGS[b.key].cat
		if cat in ["def", "prod", "special", "trap"] and int(b.level) < 10:
			if cat in ["special", "trap"] and int(b.level) >= 5:
				continue
			b.level = int(b.level) + 1
		b.done_at = 0.0
		b.up = false
	P.buildings_changed.emit()
	P.mark()


func give_weapons(all := false) -> void:
	var n := 0
	for hk in D.HERO_ORDER:
		if not all and hk != String(P.d.hero_sel):
			continue
		for wk in D.HEROES[hk].weapons:
			P.make_item("weapon", wk, _rarity)
			n += 1
	_say("%d Waffen (%s) – ausrüsten im Helden-Menü" % [n, D.RARITY[_rarity].name])


## V4: jede Waffe aller Helden (fehlende in der gewählten Seltenheit) und alle Baupläne.
func give_arsenal() -> void:
	var n: int = preload("res://src/arsenal_rules.gd").grant_all(_rarity)
	_say("%d Waffen und alle Baupläne – ausrüsten in der Werkstatt (Heldenstufe beachten)" % n)


func give_gear() -> void:
	for slot in D.GEAR:
		P.make_item(slot, "", _rarity)
	_say("Helm, Weste und Glücksbringer (%s)" % D.RARITY[_rarity].name)


func max_items() -> void:
	for it in P.d.items:
		it.level = int(D.RARITY[int(it.rarity)].max_level)
	P.mark()
	G.main.reload_hero()
	_say("alle Gegenstände auf Höchststufe")


func give_chests() -> void:
	for c in D.CHESTS:
		P.add_chest(c, 3)
	_say("Kisten hinzugefügt")
	P.changed.emit()


func unlock_heroes() -> void:
	for hk in D.HERO_ORDER:
		P.d.heroes[hk].unlocked = true
		P._grant_start_weapons(hk)
	P.mark()
	_say("alle Helden frei")


func unlock_vehicles() -> void:
	for vk in D.VEHICLES:
		P.d.vehicles[vk].owned = true
	if String(P.d.vehicle_sel) == "":
		P.d.vehicle_sel = "quad"
	P.mark()
	_say("alle Fahrzeuge frei")


func unlock_areas() -> void:
	for i in D.AREAS.size():
		for dd in 3:
			P.d.areas.boss[i][dd] = true
	if int(P.d.level) < 45:
		P.d.level = 45
	P.mark()
	P.changed.emit()
	_say("alle Gebiete und Schwierigkeiten frei")


func unlock_all() -> void:
	unlock_heroes()
	unlock_vehicles()
	unlock_areas()
	P.d.level = D.MAX_LEVEL
	# Heldenstufen werden NICHT angehoben: jeder Held wird einzeln gelevelt (eigener Knopf "Alle Helden Höchststufe")
	if String(P.d.cmd_active) == "":
		P.d.cmd_active = "airstrike"
	bunker(10)
	fill_res()
	G.main.reload_hero()
	_say("alles freigeschaltet")


func finish_quests() -> void:
	for q in P.d.quests.list:
		q.progress = int(q.amount)
	P.mark()
	_say("Tagesaufträge erfüllt – Belohnung unter „Aufträge“ abholen")


func test_base(lv: int) -> void:
	var w = G.main.world
	if w == null or w.mode != "peace":
		_say("geht nur in der Basis im Friedensbetrieb")
		return
	var save := P.no_save
	P.debug_setup(lv)
	P.no_save = save
	P.mark()
	G.main.goto_base()
	_say("Testbasis gebaut (ersetzt deine Basis!)")


## Lebendige Basis: Tageszeit durchschalten (Geräte-Uhr → Morgen → Tag → Abend → Nacht → Geräte-Uhr).
func cycle_daytime() -> void:
	var order := ["", "morgen", "tag", "abend", "nacht"]
	Weather.force = order[(order.find(Weather.force) + 1) % order.size()]
	_say("Tageszeit: " + (Weather.force if Weather.force != "" else "nach Geräte-Uhr"))
	_refill()


## Lebendige Basis: Regen sofort beginnen oder beenden.
func toggle_rain() -> void:
	var w = G.main.world
	var raining: bool = w != null and w.get("weather") != null and w.weather.raining
	Weather.force_rain = 0 if raining else 1
	_say("Regen endet" if raining else "Regen beginnt")


## Begleiter (Paket B): alle zwölf in die Truppe.
func give_companions() -> void:
	var CD = preload("res://src/companion_data.gd")
	var n := 0
	for k in CD.ORDER:
		if CD.give(String(k), "admin"):
			n += 1
	_say("%d Begleiter dazu (jetzt %d)" % [n, CD.owned_count()])
	_refill()


## Begleiter (Paket B): aktiver Begleiter eine Stufe höher.
func companion_level() -> void:
	var CD = preload("res://src/companion_data.gd")
	var k: String = CD.active()
	if k == "":
		_say("Kein Begleiter dabei")
		return
	var lv: int = CD.level(k)
	if lv < CD.MAX_LEVEL:
		CD.add_xp(float(CD.XP_NEED[lv]) - CD.xp(k) + 0.01, k)
	_say("%s Stufe %d" % [String(CD.def(k).name), CD.level(k)])


# ---------------------------------------------------------------- Paket G2: Weltboss, Miniboss, Elite
## Weltboss „Schleim-Leviathan“ (für spätere Clan-Raids und Ereignisse): in der Basis startet erst eine Übungsflut ohne Wellen.
func world_boss() -> void:
	var w = G.main.world
	if w == null:
		return
	if w.mode == "peace":
		w.start_flood(true)
		w._queue.clear()
		w.flood.total = 0
		w.wave_count = 1
	if w.mode == "peace" or w.ended:
		_say("es läuft kein Kampf")
		return
	var pp: Vector2 = w.hero.pos2()
	var q := pp + Vector2(0, -18)
	if w.field.is_solid(q):
		q = pp + Vector2(0, 18)
	var e = w.horde.spawn(int(D.ENEMY_INDEX["boss_leviathan"]), q, float(G.arg("raid_hp", "0.15")), 1.0, 1.0)
	e.special = "cycle"
	w.horde.boss = e
	w.horde.boss_name = String(D.enemy("boss_leviathan").name)
	if w.mode == "exp":
		e.home = q
		e.leash = 20.0
		e.aggro = true
	_say("Weltboss gerufen (Leben ×%s für einen Spieler)" % G.arg("raid_hp", "0.15"))


## Miniboss oder Elite der gewählten Familie (Familie der gewählten Art).
func special_spawn(kind: String) -> void:
	var w = G.main.world
	if w == null or w.mode == "peace" or w.ended:
		_say("Gegner gibt es nur im Kampf – starte „Flut jetzt“, „Übung jetzt“ oder eine Expedition")
		return
	var fam := String(D.ENEMIES[maxi(_spawn_type, 0)].family)
	var pp: Vector2 = w.hero.pos2()
	var q := pp + Vector2(12, 0)
	if w.field.is_solid(q):
		q = pp + Vector2(-12, 0)
	var e
	if kind == "mini":
		e = w.horde.spawn_planned(2000 + D.family_mini(fam), q, 1.0, 1.0)
	else:
		e = w.horde.spawn_planned(1000 + w.horde.strongest_type(fam), q, 1.0, 1.0)
	if w.mode == "exp":
		e.home = pp
		e.leash = 14.0
		e.aggro = true
	_say("%s: %s" % ["Miniboss" if kind == "mini" else "Elite", D.ENEMIES[e.t].name])
