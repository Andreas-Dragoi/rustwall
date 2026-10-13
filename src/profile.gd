extends Node
## Spielstand und Spielregeln außerhalb des Kampfes (Autoload "P"):
## Rohstoffe, Gebäude auf dem Raster, Bauzeiten, Helden, Inventar, Kisten, Stufen,
## Sieben-Tage-Zyklus, Tagesaufträge. Wird als JSON gespeichert.
##
## Hinweis: Diese Version läuft ohne Server. Zeit kommt von der Geräteuhr. Für einen
## fairen Online-Betrieb gehört alles in dieser Datei auf einen Server (Konzept Kapitel 17).

const D = preload("res://src/data.gd")
const Social = preload("res://src/social.gd")
const MK = preload("res://src/mk.gd")
const Arsenal = preload("res://src/arsenal_rules.gd")
const Guide = preload("res://src/guide.gd")              # Paket F: Spielerführung und Komfort
const LO = preload("res://src/liveops.gd")               # Paket L: Live-Betrieb (Ereignisse, Saison, Kosmetik, Endspiel)
const Research = preload("res://src/research.gd")         # V6 Paket B: Forschung im Labor
const BState = preload("res://src/basis_state.gd")        # V6 Paket B: Funde, Verletzte, Rückblick, Mitteilungen
const HS = preload("res://src/helden.gd")                # Paket H: Ausrüstungs-Sets, Waffenmodule, neue Heldin

const SAVE_PATH := "user://rustwall_v2.json"
const VERSION := 3
const BACKUP_PATH := "user://rustwall_v2_backup.json"
## Mehrere Städte: Stadt 1 liegt (wie bisher) in SAVE_PATH, weitere in rustwall_city_<n>.json.
## Das Verzeichnis merkt sich die Liste und welche Stadt zuletzt gespielt wurde.
const CITIES_PATH := "user://rustwall_cities.json"
const MAX_CITIES := 5
const BUNKER_NAME_MIN := 3
const BUNKER_NAME_MAX := 20

signal changed                    # irgendetwas am Spielstand hat sich geändert
signal resources_changed
signal buildings_changed
signal toast(text: String)
signal level_up(level: int)
signal building_done(id: int)
signal hero_level_up(key: String, level: int)
signal gems_changed(delta: int)
signal pickups_changed
signal city_changed               # andere Stadt geladen (neu, gewechselt)

var d: Dictionary = {}
var social: RefCounted
var no_save := false              # Tests speichern nicht
var _rng := RandomNumberGenerator.new()
var _tick := 0.0
var _dirty := false
var _save_t := 0.0
var _needs_migration := false
var _sync_pending := false
var slot := 1                      # aktive Stadt
var cities: Dictionary = {}        # Verzeichnis: {"current": n, "list": {"n": {name, bunker_name, level, bunker, played}}}
var server_offset := 0.0           # Paket O: Serveruhr minus Geräteuhr (net.gd misst das beim Verbinden)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autotest") or a == "--selftest" or a.begins_with("--shot="):
			no_save = true
	_read_cities()
	if no_save or not _load():
		new_game()
		if not no_save and FileAccess.file_exists(slot_path(slot)):
			push_warning("Spielstand der Stadt %d nicht lesbar – neue Stadt begonnen" % slot)
	social = Social.new(self)
	social.ensure()
	_after_load()


# ================================================================= Zeit
func now() -> float:
	return Time.get_unix_time_from_system() + float(d.get("time_offset", 0.0)) + server_offset


func day_index(t := -1.0) -> int:
	if t < 0.0:
		t = now()
	var bias: int = Time.get_time_zone_from_system().bias * 60
	return int(floor((t + bias - D.DAY_SHIFT_HOURS * 3600.0) / D.DAY_SECONDS))


func seconds_to_next_day() -> float:
	var bias: int = Time.get_time_zone_from_system().bias * 60
	var t := now() + bias - D.DAY_SHIFT_HOURS * 3600.0
	return D.DAY_SECONDS - fmod(t, D.DAY_SECONDS)


## Testhilfe: springt in der Zeit vorwärts (Einstellungen -> Testmodus).
func skip_time(seconds: float) -> void:
	d.time_offset = float(d.get("time_offset", 0.0)) + seconds
	_time_passed()
	mark()


func build_speed() -> float:
	return 60.0 if d.settings.get("fast_build", false) else 1.0


# ================================================================= Neues Spiel / Laden / Speichern
func new_game() -> void:
	d = {
		"version": VERSION, "created": Time.get_unix_time_from_system(), "time_offset": 0.0,
		"name": "Kommandant", "res": D.START_RES.duplicate(), "level": 1, "xp": 0,
		"cmd": {}, "cmd_active": "", "buildings": [], "next_id": 1, "layouts": [null, null, null],
		"heroes": {}, "hero_sel": "jona", "badges": {}, "items": [], "next_item": 1,
		"vehicles": {}, "vehicle_sel": "", "chests": {}, "pity_epic": 0, "pity_legend": 0,
		"week": {"start_day": 0, "number": 1, "flood_done": false, "practice_day": -1, "last": {}, "dirs": [0, 1]},
		"quests": {"day": -1, "list": [], "claimed": false, "daily_day": -1},
		"areas": {"boss": [], "runs": 0}, "stats": {"kills": 0, "expeditions": 0, "floods_won": 0, "floods_lost": 0, "chests": 0},
		"settings": {"sfx": 0.8, "shake": true, "vibrate": true, "quality": 1, "fast_build": false, "fps60": true},
		"guide": 0, "social": {}, "bunker_name": "", "intro_seen": false,
	}
	_ensure_fields()
	d.week.start_day = day_index()
	for i in D.AREAS.size():
		d.areas.boss.append([false, false, false])
	for k in D.HERO_ORDER:
		d.heroes[k] = {"unlocked": k == "jona", "level": 1, "xp": 0, "talents": [0, 0, 0], "weapon": 0, "gear": {"helmet": 0, "vest": 0, "charm": 0},
			"chapter": 0, "auto_until": 0.0, "auto_area": -1, "auto_hours": 0}
		d.badges[k] = 0
	for k in D.VEHICLES:
		d.vehicles[k] = {"owned": false, "motor": 0, "body": 0, "bed": 0}
	# Startbasis: Bunker in der Mitte, Quartier und Kistenlager daneben
	var c := int(D.GRID_MAX / 2)
	_add_building("bunker", c - 2, c - 2, 0, 1)
	_add_building("quartier", c + 4, c - 1, 0, 1)
	_add_building("kistenlager", c - 5, c - 1, 0, 1)
	# ein kurzes Mauerstück mit Tor, damit man Tore sofort kennenlernt
	for i in 3:
		_add_building("wall", c - 4 + i, c + 10, 0, 1)
		_add_building("wall", c + 1 + i, c + 10, 0, 1)
	_add_building("tor", c - 1, c + 10, 0, 1)
	_grant_start_weapons("jona")
	d.chests["daily"] = 1
	_roll_week_dirs()
	if social:
		social.s = d.social
		social.ensure()


func _grant_start_weapons(hero: String) -> void:
	var h: Dictionary = d.heroes[hero]
	var wkeys: Array = D.HEROES[hero].weapons
	for i in wkeys.size():
		if int(h.level) >= D.WEAPON_UNLOCK_LEVELS[i] and not _has_weapon_key(wkeys[i]):
			var it := make_item("weapon", wkeys[i], 0)
			if int(h.weapon) == 0:
				h.weapon = it.id


func _has_weapon_key(key: String) -> bool:
	for it in d.items:
		if it.slot == "weapon" and it.key == key:
			return true
	return false


func _load() -> bool:
	var path := slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var v = JSON.parse_string(f.get_as_text())
	if not (v is Dictionary) or int(v.get("version", 0)) < 2 or int(v.get("version", 0)) > VERSION:
		return false
	d = v
	if int(d.version) < 3:
		# Sicherheitskopie des alten Stands, dann umstellen (siehe _migrate_v3)
		var bf := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
		if bf:
			bf.store_string(f.get_as_text())
		_needs_migration = true
	return true


func _after_load() -> void:
	# JSON kennt nur Kommazahlen: Zähler wieder zu Ganzzahlen machen
	_ensure_fields()
	_wallet_pull()
	for b in d.buildings:
		for k in ["id", "x", "y", "rot", "level"]:
			b[k] = int(b[k])
		if b.has("job"):
			b.job = int(b.job)
	for it in d.items:
		it.id = int(it.id)
		it.rarity = int(it.rarity)
		it.level = int(it.level)
	d.level = int(d.level)
	d.next_id = int(d.next_id)
	d.next_item = int(d.next_item)
	for k in d.heroes:
		var h: Dictionary = d.heroes[k]
		h.level = int(h.level)
		h.weapon = int(h.weapon)
		for s in h.gear:
			h.gear[s] = int(h.gear[s])
	if _needs_migration:
		_needs_migration = false
		_migrate_v3()
	_time_passed()


func mark() -> void:
	_dirty = true
	changed.emit()


func save() -> void:
	_dirty = false
	if no_save:
		return
	_wallet_push()
	d["last_seen"] = now()
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
	_note_city()


func reset_all() -> void:
	var keep_name := bunker_name()
	new_game()
	_wallet_pull()
	d.bunker_name = keep_name
	social = Social.new(self)
	social.ensure()
	save()
	buildings_changed.emit()
	resources_changed.emit()
	changed.emit()


func _process(dt: float) -> void:
	_tick += dt
	if _tick >= 1.0:
		_tick = 0.0
		_time_passed()
	if _dirty:
		_save_t += dt
		if _save_t > 2.0:
			_save_t = 0.0
			save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save()
	preload("res://src/notify.gd").on_app(what)              # V6 Paket B: Mitteilungen planen (Handy)


## Wird jede Sekunde und nach Zeitsprüngen aufgerufen.
func _time_passed() -> void:
	var t := now()
	var any := false
	for b in d.buildings.duplicate():
		if float(b.get("done_at", 0.0)) > 0.0 and t >= float(b.done_at):
			_complete(b, t)
			any = true
	if any:
		buildings_changed.emit()
		mark()
	_check_week()
	_ensure_quests()
	_check_daily()
	outpost_deliveries()
	_grow_obstacles()
	_train_tick(t)
	if social:
		social.tick(t)
	Guide.tick(t)
	LO.tick(t)                                                # Paket L: Wochenwechsel, Saison-Ende, Feiertage
	Research.tick(t)                                          # V6 Paket B: Forschung fertig?


## Ein Bau, eine Verbesserung oder das Wegräumen eines Hindernisses ist fertig.
func _complete(b: Dictionary, t: float) -> void:
	var def: Dictionary = D.BUILDINGS[b.key]
	b.done_at = 0.0
	b.erase("job")
	b.erase("t0")
	if b.get("clear", false):
		d.buildings.erase(b)
		var g: Array = def.gems
		var n := _rng.randi_range(int(g[0]), int(g[1]))
		add_gems(n, "Hindernis")
		count_up("obstacles", 1)
		BState.obstacle_cleared(b)                            # V6 Paket B: seltener Fund (Truhe, Juwelen, Bauplan-Splitter)
		toast.emit("%s weggeräumt: +%d Juwelen" % [def.name, n])
		Sfx.play("build_remove", -6.0, 1.0, 0.1)
		building_done.emit(int(b.id))
		return
	var up: bool = b.get("up", false)
	if up:
		b.level = int(b.level) + 1
		b.up = false
	else:
		b.last_collect = t
	var small: bool = def.cat == "wall" or def.cat == "deco"
	if b.key == "wall":
		Sfx.play("build_place", -12.0, 1.2, 0.15)
		add_xp(1)
	else:
		Sfx.play("upgrade_done" if up else "build_done", -4.0, 1.0, 0.6)
		toast.emit("%s fertig" % def.name if small else "%s fertig (Stufe %d)" % [def.name, int(b.level)])
		add_xp(3 if small else 10 + 6 * int(b.level))
		quest_progress("builds", 1)
		count_up("builds", 1)
	building_done.emit(int(b.id))


# ================================================================= Rohstoffe
func res(r: String) -> int:
	return int(d.res.get(r, 0))


func cap(r: String) -> int:
	var bl := bunker_level()
	if r == "coins":
		return int(4000.0 * pow(1.9, bl - 1))
	if not D.CAP_BASE.has(r):
		return 999999
	var lag := 0.0
	for b in d.buildings:
		if b.key == "lager" and not is_building(b):
			lag += int(b.level)
	return int(D.CAP_BASE[r] * (1.0 + 0.6 * lag + 0.5 * (bl - 1)) * (1.0 + Research.bonus("cap")))


func can_pay(cost: Dictionary) -> bool:
	if G.ch("free"):
		return true
	for r in cost:
		if res(r) < int(cost[r]):
			return false
	return true


func pay(cost: Dictionary) -> bool:
	if not can_pay(cost):
		return false
	if G.ch("free"):
		return true
	for r in cost:
		d.res[r] = res(r) - int(cost[r])
	resources_changed.emit()
	mark()
	return true


## Fügt Rohstoffe hinzu (begrenzt durch das Lager). Rückgabe: tatsächlich gutgeschriebene Menge.
func add(r: String, amount: float) -> int:
	var a := int(round(amount))
	if a <= 0:
		return 0
	var room := maxi(0, cap(r) - res(r))
	var got := mini(a, room)
	d.res[r] = res(r) + got
	if r == "coins":
		quest_progress("coins", got)
	elif r == "wood":
		quest_progress("wood", got)
	resources_changed.emit()
	mark()
	return got


func add_many(bundle: Dictionary) -> void:
	for r in bundle:
		add(r, float(bundle[r]))


func missing_text(cost: Dictionary) -> String:
	var parts: Array = []
	for r in cost:
		var miss := int(cost[r]) - res(r)
		if miss > 0:
			parts.append("%d %s" % [miss, D.RES_NAME[r]])
	return "Es fehlen: " + ", ".join(parts)


# ================================================================= Spielerstufe
func add_xp(n: float) -> void:
	if int(d.level) >= D.MAX_LEVEL:
		return
	n *= 1.0 + cmd_bonus("xp")
	d.xp = float(d.xp) + n
	while int(d.level) < D.MAX_LEVEL and float(d.xp) >= D.xp_need(int(d.level)):
		d.xp = float(d.xp) - D.xp_need(int(d.level))
		d.level = int(d.level) + 1
		add_chest("level")
		add_gems(int(D.GEM_REWARD.level), "Spielerstufe")
		for r in D.CAP_BASE:
			add(r, cap(r) * 0.25)
		level_up.emit(int(d.level))
		toast.emit("Stufe %d erreicht!" % int(d.level))
	mark()


func cmd_points_total() -> int:
	return int(d.level) - 1


func cmd_points_spent() -> int:
	var s := 0
	for k in d.cmd:
		s += int(d.cmd[k])
	return s


func cmd_rank(key: String) -> int:
	return int(d.cmd.get(key, 0))


func cmd_bonus(key: String) -> float:
	var rb := Research.bonus(key)                             # V6 Paket B: Forschung mit gleichem Schlüssel zählt dazu
	var r := cmd_rank(key)
	if r <= 0:
		return rb
	for br in D.COMMANDER:
		for s in br.skills:
			if s.key == key:
				return float(s.val) * r + rb
	return rb


func cmd_raise(key: String) -> bool:
	if cmd_points_spent() >= cmd_points_total() or cmd_rank(key) >= 5:
		return false
	d.cmd[key] = cmd_rank(key) + 1
	mark()
	return true


func cmd_reset() -> void:
	d.cmd = {}
	mark()


func cmd_active_unlocked(key: String) -> bool:
	return int(d.level) >= int(D.CMD_ACTIVES[key].level)


# ================================================================= Gebäude und Raster
func bunker() -> Dictionary:
	for b in d.buildings:
		if b.key == "bunker":
			return b
	return {}


func bunker_level() -> int:
	var b := bunker()
	return int(b.get("level", 1))


func grid_size() -> int:
	return D.GRID_BY_BUNKER[clampi(bunker_level(), 1, 10) - 1]


func is_building(b: Dictionary) -> bool:
	return float(b.get("done_at", 0.0)) > 0.0


func get_building(id: int) -> Dictionary:
	for b in d.buildings:
		if int(b.id) == id:
			return b
	return {}


func count(key: String) -> int:
	var n := 0
	for b in d.buildings:
		if b.key == key:
			n += 1
	return n


func has_built(key: String) -> bool:
	for b in d.buildings:
		if b.key == key and (not is_building(b) or b.get("up", false)):
			return true
	return false


func max_count(key: String) -> int:
	if D.BUILDINGS[key].has("trophy"):
		return 1 if boss_beaten(String(D.BUILDINGS[key].trophy)) else 0
	if D.BUILDINGS[key].has("story") and not preload("res://src/story.gd").building_allowed(key):
		return 0                                              # V6 Paket E: erst nach der Rettung
	return int(D.BUILDINGS[key].max[clampi(bunker_level(), 1, 10) - 1])


## Paket G2: Boss schon einmal besiegt (Flut oder Expedition)? Schaltet seine Trophäe frei.
func boss_beaten(boss_key: String) -> bool:
	if int(d.counters.get("boss_win_" + boss_key, 0)) > 0:
		return true
	var ai: int = D.AREA_BOSS.find(boss_key)
	if ai >= 0 and ai < d.areas.boss.size():
		for v in d.areas.boss[ai]:
			if bool(v):
				return true
	return false


## Beste Mauerart, die der Bunker erlaubt (0 Holz, 1 Stein, 2 Metall). Jedes Mauerstück hat seine eigene Art: level - 1.
func wall_tier() -> int:
	var bl := bunker_level()
	return 2 if bl >= 7 else (1 if bl >= 4 else 0)


## Häufigste Mauerart der Basis (für Töne und das Aussehen des Bunkers).
func wall_tier_built() -> int:
	var n := [0, 0, 0]
	for b in d.buildings:
		if b.key == "wall":
			n[clampi(int(b.level) - 1, 0, 2)] += 1
	if n[2] >= n[1] and n[2] >= n[0] and n[2] > 0:
		return 2
	return 1 if n[1] >= n[0] and n[1] > 0 else 0


func size_of(key: String, rot: int) -> Vector2i:
	var s: Array = D.BUILDINGS[key].size
	return Vector2i(int(s[1]), int(s[0])) if rot % 2 == 1 else Vector2i(int(s[0]), int(s[1]))


## Raster-Offset: das Raster wächst mit dem Bunker, bleibt aber um die Mitte zentriert.
## Gespeicherte Koordinaten beziehen sich immer auf das größte Raster (GRID_MAX).
func grid_origin() -> int:
	return int((D.GRID_MAX - grid_size()) / 2)


func in_grid(x: int, y: int, w: int, h: int) -> bool:
	var o := grid_origin()
	var n := grid_size()
	return x >= o and y >= o and x + w <= o + n and y + h <= o + n


func occupancy(ignore_id := -1) -> Dictionary:
	var occ := {}
	for b in d.buildings:
		if int(b.id) == ignore_id:
			continue
		var s := size_of(b.key, int(b.rot))
		for yy in s.y:
			for xx in s.x:
				occ[(int(b.x) + xx) + (int(b.y) + yy) * 64] = int(b.id)
	return occ


func cells_free(x: int, y: int, w: int, h: int, ignore_id := -1, occ = null) -> bool:
	if not in_grid(x, y, w, h):
		return false
	if occ == null:
		occ = occupancy(ignore_id)
	for yy in h:
		for xx in w:
			if occ.has((x + xx) + (y + yy) * 64):
				return false
	return true


func cost_for(key: String, level: int) -> Dictionary:
	if key == "bunker":
		return D.bunker_cost(level)
	if (key == "wall" or key == "tor") and level > 1:
		var wc: Dictionary = D.WALL_UP_COST[clampi(level - 1, 0, 2)]
		var o := {}
		for r in wc:
			o[r] = int(wc[r]) * (4 if key == "tor" else 1)
		return o
	var base: Dictionary = D.BUILDINGS[key].get("cost", {})
	var out := {}
	var k := pow(D.COST_GROWTH, level - 1)
	for r in base:
		out[r] = int(round(float(base[r]) * k / 5.0) * 5) if level > 1 else int(base[r])
	return out


## Bauzeit in Sekunden für die Zielstufe (Kommandanten-Bonus und Testmodus eingerechnet).
func time_for(key: String, level: int) -> float:
	if G.ch("instant"):
		return 0.0
	return D.build_time(key, level) * (1.0 - cmd_bonus("build_time")) / build_speed() * LO.build_mult()     # Paket L: Bauwoche


func max_level(key: String) -> int:
	var cat: String = D.BUILDINGS[key].cat
	if key == "bunker":
		return 10
	if cat == "wall":
		return wall_tier() + 1
	if cat == "deco" or cat == "obstacle":
		return 1
	if cat == "trap" or cat == "special":
		return mini(5, bunker_level())
	return bunker_level()


func needs_drone(key: String) -> bool:
	return not (key in D.NO_DRONE)


func drones_total() -> int:
	return int(D.DRONES_BY_BUNKER[clampi(bunker_level(), 1, 10) - 1]) + int(d.get("drones_bought", 0))


## Laufende Aufträge. Ein Mauerauftrag (mehrere Stücke) belegt nur eine Drohne.
func drones_busy() -> int:
	var jobs := {}
	var n := 0
	for b in d.buildings:
		if is_building(b) and needs_drone(b.key):
			var j := int(b.get("job", 0))
			if j > 0:
				if not jobs.has(j):
					jobs[j] = true
					n += 1
			else:
				n += 1
	return n


func _new_job() -> int:
	d.next_job = int(d.get("next_job", 1)) + 1
	return int(d.next_job) - 1


func job_pieces(job: int) -> Array:
	var out: Array = []
	for b in d.buildings:
		if int(b.get("job", 0)) == job and is_building(b):
			out.append(b)
	return out


func _job_end(job: int) -> float:
	var e := 0.0
	for b in job_pieces(job):
		e = maxf(e, float(b.done_at))
	return e


## Offener Mauer-Bauauftrag (neue Stücke hängen sich an) oder 0.
func open_wall_job() -> int:
	var best := 0
	for b in d.buildings:
		if b.key == "wall" and is_building(b) and not b.get("up", false):
			best = maxi(best, int(b.get("job", 0)))
	return best


## Alle laufenden Aufträge für die Anzeige: {id, job, name, key, count, t0, end, level}
func jobs() -> Array:
	var out: Array = []
	var seen := {}
	for b in d.buildings:
		if not is_building(b):
			continue
		var j := int(b.get("job", 0))
		if j > 0:
			if seen.has(j):
				var e: Dictionary = seen[j]
				e.count += 1
				e.t0 = minf(e.t0, float(b.get("t0", b.done_at)))
				e.end = maxf(e.end, float(b.done_at))
				continue
			var e2 := {"id": int(b.id), "job": j, "key": String(b.key), "count": 1, "t0": float(b.get("t0", b.done_at)), "end": float(b.done_at), "name": "", "level": int(b.level)}
			seen[j] = e2
			out.append(e2)
		else:
			out.append({"id": int(b.id), "job": 0, "key": String(b.key), "count": 1, "t0": float(b.get("t0", b.done_at)), "end": float(b.done_at), "name": "", "level": int(b.level)})
	for e in out:
		var def: Dictionary = D.BUILDINGS[e.key]
		var b2 := get_building(int(e.id))
		if b2.get("clear", false):
			e.name = "%s wegräumen" % def.name
		elif e.key == "wall":
			e.name = "%d × %s" % [e.count, D.WALL_TIERS[clampi(int(e.level) - (0 if b2.get("up", false) else 1), 0, 2)].name]
		elif b2.get("up", false):
			e.name = "%s → Stufe %d" % [def.name, int(e.level) + 1]
		else:
			e.name = String(def.name)
	out.sort_custom(func(a, b3): return a.end < b3.end)
	return out


func _add_building(key: String, x: int, y: int, rot: int, level: int) -> Dictionary:
	var b := {"id": int(d.next_id), "key": key, "x": x, "y": y, "rot": rot, "level": level, "done_at": 0.0, "up": false, "last_collect": now()}
	d.next_id = int(d.next_id) + 1
	d.buildings.append(b)
	return b


## Prüft, ob ein neues Gebäude dieser Art gebaut werden darf. Rückgabe: "" oder Grund.
func can_build(key: String) -> String:
	var def: Dictionary = D.BUILDINGS[key]
	var nl := G.ch("nolimit")
	if not nl and int(def.unlock) > bunker_level():
		return "Ab Bunker-Stufe %d" % int(def.unlock)
	if not nl and count(key) >= max_count(key):
		return "Höchstzahl erreicht (%d)" % max_count(key)
	var c := cost_for(key, 1)
	if not can_pay(c):
		return missing_text(c)
	if def.cat == "obstacle":
		return "Kann nicht gebaut werden"
	if not nl and time_for(key, 1) > 0.0 and needs_drone(key) and drones_busy() >= drones_total() and not (key == "wall" and open_wall_job() > 0):
		return "Alle Baudrohnen sind beschäftigt"
	return ""


func place(key: String, x: int, y: int, rot := 0) -> Dictionary:
	var why := can_build(key)
	if why != "":
		toast.emit(why)
		return {}
	var s := size_of(key, rot)
	if not cells_free(x, y, s.x, s.y):
		return {}
	pay(cost_for(key, 1))
	var b := _add_building(key, x, y, rot, 1)
	var t := time_for(key, 1)
	if t > 0.0:
		var start := now()
		if key == "wall":
			# Mauern eines Zuges bilden einen Auftrag: die Stücke werden nacheinander fertig
			var j := open_wall_job()
			if j > 0:
				start = maxf(start, _job_end(j))
			else:
				j = _new_job()
			b.job = j
		b.t0 = start
		b.done_at = start + t
	elif D.BUILDINGS[key].cat != "wall":
		quest_progress("builds", 1)
		count_up("builds", 1)
	if key == "wall":
		count_up("walls", 1)
	buildings_changed.emit()
	mark()
	return b


func move(id: int, x: int, y: int, rot: int) -> bool:
	var b := get_building(id)
	if b.is_empty():
		return false
	var s := size_of(b.key, rot)
	if not cells_free(x, y, s.x, s.y, id):
		return false
	b.x = x
	b.y = y
	b.rot = rot
	buildings_changed.emit()
	mark()
	return true


func can_upgrade(id: int) -> String:
	var b := get_building(id)
	if b.is_empty():
		return "?"
	if is_building(b):
		return "Wird gerade gebaut"
	if D.BUILDINGS[b.key].cat == "obstacle":
		return "Kann nicht verbessert werden"
	var nl := int(b.level) + 1
	var free_lv: bool = G.ch("nolimit") and nl <= 10 and D.BUILDINGS[b.key].cat in ["def", "prod", "core"]
	if nl > max_level(b.key) and not free_lv:
		if b.key == "bunker" or D.BUILDINGS[b.key].cat == "deco" or (D.BUILDINGS[b.key].cat == "wall" and nl > 3):
			return "Höchste Stufe erreicht"
		return "Erst den Bunker ausbauen" if max_level(b.key) < 10 else "Höchste Stufe erreicht"
	var c := cost_for(b.key, nl)
	if not can_pay(c):
		return missing_text(c)
	if drones_busy() >= drones_total() and not G.ch("nolimit"):
		return "Alle Baudrohnen sind beschäftigt"
	return ""


func upgrade(id: int) -> bool:
	var why := can_upgrade(id)
	if why != "":
		toast.emit(why)
		return false
	var b := get_building(id)
	var nl := int(b.level) + 1
	pay(cost_for(b.key, nl))
	if G.ch("instant"):
		b.level = nl
		buildings_changed.emit()
		mark()
		return true
	# während der Verbesserung arbeitet das Gebäude auf seiner alten Stufe weiter
	b.t0 = now()
	b.done_at = now() + maxf(time_for(b.key, nl), 1.0)
	if b.key == "wall":
		b.job = _new_job()
	Sfx.play("upgrade_start", -6.0, 1.0, 0.2)
	b.up = true
	buildings_changed.emit()
	mark()
	return true


## Mauerstücke, die sich auf die nächste Art verbessern lassen.
func upgradable_walls() -> Array:
	var out: Array = []
	var mx := wall_tier() + 1
	for b in d.buildings:
		if b.key == "wall" and not is_building(b) and int(b.level) < mx:
			out.append(b)
	out.sort_custom(func(a, c): return int(a.level) < int(c.level) or (int(a.level) == int(c.level) and int(a.id) < int(c.id)))
	return out


## Verbessert so viele Mauern wie möglich: Aufträge zu je höchstens 25 Stück, jeder belegt eine Drohne.
## Rückgabe: Zahl der gestarteten Stücke.
func upgrade_walls() -> int:
	var list := upgradable_walls()
	var started := 0
	var i := 0
	while i < list.size():
		if drones_busy() >= drones_total() and not G.ch("nolimit"):
			break
		var lvl := int(list[i].level)
		var per := time_for("wall", lvl + 1)
		var cost := cost_for("wall", lvl + 1)
		var job := _new_job()
		var start := now()
		var n := 0
		while i < list.size() and n < D.WALL_JOB_MAX and int(list[i].level) == lvl:
			if not pay(cost):
				i = list.size()
				break
			var b: Dictionary = list[i]
			if per <= 0.0:
				b.level = lvl + 1
			else:
				b.job = job
				b.up = true
				b.t0 = start
				start += per
				b.done_at = start
			n += 1
			started += 1
			i += 1
	if started > 0:
		Sfx.play("upgrade_start", -6.0, 1.0, 0.2)
		buildings_changed.emit()
		mark()
	return started


## Wandelt ein Mauerstück (und das Nachbarstück) in ein Tor um. free: ohne Kosten und sofort (Umstellung alter Spielstände).
func wall_to_gate(id: int, free := false) -> Dictionary:
	var b := get_building(id)
	if b.is_empty() or b.key != "wall" or is_building(b):
		return {}
	var x := int(b.x)
	var y := int(b.y)
	var other := {}
	var gx := x
	var gy := y
	var rot := 0
	for o in [[1, 0, 0, 0, 0], [-1, 0, -1, 0, 0], [0, 1, 0, 0, 1], [0, -1, 0, -1, 1]]:
		for w in d.buildings:
			if w.key == "wall" and not is_building(w) and int(w.x) == x + int(o[0]) and int(w.y) == y + int(o[1]):
				other = w
				gx = x + int(o[2])
				gy = y + int(o[3])
				rot = int(o[4])
				break
		if not other.is_empty():
			break
	if other.is_empty():
		if not free:
			toast.emit("Ein Tor braucht zwei Mauerstücke nebeneinander")
		return {}
	if not free:
		if count("tor") >= max_count("tor") and not G.ch("nolimit"):
			toast.emit("Höchstzahl an Toren erreicht (%d)" % max_count("tor"))
			return {}
		if drones_busy() >= drones_total() and not G.ch("nolimit") and time_for("tor", 1) > 0.0:
			toast.emit("Alle Baudrohnen sind beschäftigt")
			return {}
		var cost := gate_swap_cost()
		if not pay(cost):
			toast.emit(missing_text(cost))
			return {}
	var lvl := mini(int(b.level), int(other.level))
	d.buildings.erase(b)
	d.buildings.erase(other)
	var g := _add_building("tor", gx, gy, rot, lvl)
	var t := 0.0 if free else time_for("tor", 1)
	if t > 0.0:
		g.t0 = now()
		g.done_at = now() + t
	buildings_changed.emit()
	mark()
	return g


## Aufpreis für die Umwandlung zweier Mauerstücke in ein Tor.
func gate_swap_cost() -> Dictionary:
	var gc := cost_for("tor", 1)
	var wc := cost_for("wall", 1)
	var out := {}
	for r in gc:
		var v := int(gc[r]) - 2 * int(wc.get(r, 0))
		if v > 0:
			out[r] = v
	return out


## Gibt es vom Bunker-Eingang einen Weg zum Rand des Baufelds? Tore zählen als frei.
func enclosed() -> bool:
	var bk := bunker()
	if bk.is_empty():
		return false
	var o := grid_origin()
	var n := grid_size()
	var blocked := {}
	for b in d.buildings:
		if b.key == "tor":
			continue
		var s := size_of(b.key, int(b.rot))
		for yy in s.y:
			for xx in s.x:
				blocked[(int(b.x) + xx) + (int(b.y) + yy) * 64] = true
	var start := Vector2i(int(bk.x) + 2, int(bk.y) + 5)
	# liegt der Eingang selbst zu, beginnt die Suche rund um den Bunker
	var open: Array = []
	if not blocked.has(start.x + start.y * 64):
		open.append(start)
	else:
		for yy in range(-1, 5):
			for xx in range(-1, 5):
				var q := Vector2i(int(bk.x) + xx, int(bk.y) + yy)
				if (xx == -1 or xx == 4 or yy == -1 or yy == 4) and not blocked.has(q.x + q.y * 64):
					open.append(q)
	var seen := {}
	for q in open:
		seen[q.x + q.y * 64] = true
	var i := 0
	while i < open.size():
		var c: Vector2i = open[i]
		i += 1
		if c.x <= o or c.y <= o or c.x >= o + n - 1 or c.y >= o + n - 1:
			return false
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q2: Vector2i = c + dv
			var k := q2.x + q2.y * 64
			if not seen.has(k) and not blocked.has(k):
				seen[k] = true
				open.append(q2)
	return open.size() > 0


## Entfernt Mauern, Fallen und Schmuck (halbe Kosten zurück). Andere Gebäude bleiben.
func remove(id: int) -> bool:
	var b := get_building(id)
	if b.is_empty():
		return false
	var cat: String = D.BUILDINGS[b.key].cat
	if cat != "wall" and cat != "deco" and cat != "trap":
		return false
	var c := cost_for(b.key, 1)
	for r in c:
		add(r, int(c[r]) * 0.5)
	Sfx.play("build_remove", -6.0, 1.0, 0.08)
	d.buildings.erase(b)
	buildings_changed.emit()
	mark()
	return true


func speed_up_builds(seconds: float) -> void:
	for b in d.buildings:
		if is_building(b):
			b.done_at = float(b.done_at) - seconds / build_speed()
			if b.has("t0"):
				b.t0 = float(b.t0) - seconds / build_speed()
	_time_passed()


## Räumt ein Hindernis weg (kostet etwas Holz oder Stein und Zeit einer Drohne, bringt Juwelen).
func clear_obstacle(id: int) -> String:
	var b := get_building(id)
	if b.is_empty() or D.BUILDINGS[b.key].cat != "obstacle":
		return "?"
	if is_building(b):
		return "Wird schon weggeräumt"
	if drones_busy() >= drones_total() and not G.ch("nolimit") and not G.ch("instant"):
		return "Alle Baudrohnen sind beschäftigt"
	var c := cost_for(b.key, 1)
	if not pay(c):
		return missing_text(c)
	b.clear = true
	b.t0 = now()
	b.done_at = now() + maxf(time_for(b.key, 1), 0.01)
	Sfx.play("upgrade_start", -8.0, 1.2, 0.1)
	buildings_changed.emit()
	mark()
	if G.ch("instant"):
		_time_passed()
	return ""


## Jeden Tag wachsen bis zu zwei Hindernisse nach (höchstens zwölf gleichzeitig).
func _grow_obstacles(force := false) -> void:
	var di := day_index()
	if int(d.get("obstacle_day", -1)) == di and not force:
		return
	d.obstacle_day = di
	if no_save and not force:
		return
	var have := 0
	for b in d.buildings:
		if D.BUILDINGS[b.key].cat == "obstacle":
			have += 1
	var o := grid_origin()
	var n := grid_size()
	var bk := bunker()
	var added := 0
	var tries := 0
	while added < 2 and have + added < 12 and tries < 60:
		tries += 1
		var x := _rng.randi_range(o + 1, o + n - 2)
		var y := _rng.randi_range(o + 1, o + n - 2)
		# nicht direkt am Bunker und nicht vor dessen Eingang
		if not bk.is_empty() and absi(x - int(bk.x) - 2) < 5 and absi(y - int(bk.y) - 2) < 6:
			continue
		if not cells_free(x, y, 1, 1):
			continue
		var r := _rng.randf()
		BState.roll_find(_add_building("hind_busch" if r < 0.5 else ("hind_stumpf" if r < 0.8 else "hind_stein"), x, y, _rng.randi() % 4, 1))
		added += 1
	if added > 0:
		buildings_changed.emit()
		mark()


func save_layout(slot: int) -> void:
	var l: Array = []
	for b in d.buildings:
		l.append([int(b.id), int(b.x), int(b.y), int(b.rot)])
	d.layouts[slot] = l
	mark()
	toast.emit("Aufbau %d gespeichert" % (slot + 1))


func load_layout(slot: int) -> bool:
	var l = d.layouts[slot]
	if l == null:
		toast.emit("Aufbau %d ist leer" % (slot + 1))
		return false
	# erst prüfen, ob alles noch passt
	var backup: Array = []
	for b in d.buildings:
		backup.append([b, int(b.x), int(b.y), int(b.rot)])
	var known := {}
	for e in l:
		known[int(e[0])] = e
	var occ := {}
	var ok := true
	for b in d.buildings:
		if known.has(int(b.id)):
			var e: Array = known[int(b.id)]
			b.x = int(e[1])
			b.y = int(e[2])
			b.rot = int(e[3])
	for b in d.buildings:
		var s := size_of(b.key, int(b.rot))
		if not in_grid(int(b.x), int(b.y), s.x, s.y):
			ok = false
		for yy in s.y:
			for xx in s.x:
				var k := (int(b.x) + xx) + (int(b.y) + yy) * 64
				if occ.has(k):
					ok = false
				occ[k] = true
	if not ok:
		for e in backup:
			e[0].x = e[1]
			e[0].y = e[2]
			e[0].rot = e[3]
		toast.emit("Aufbau passt nicht mehr (neue Gebäude im Weg)")
		return false
	buildings_changed.emit()
	mark()
	return true


# ----------------------------------------------------------------- Produktion
func prod_rate(b: Dictionary) -> float:
	var def: Dictionary = D.BUILDINGS[b.key]
	if not def.has("prod"):
		return 0.0
	return float(def.rate) * pow(1.3, int(b.level) - 1) * (1.0 + outpost_bonus("prod_" + String(def.prod))) * (1.0 + deco_bonus()) * (1.0 + Research.prod_bonus(String(def.prod)))


## Paket G2: Deko-Punkte aller fertigen Schmuck-Gebäude (Bewohner-Zufriedenheit).
func deco_points() -> int:
	var n := 0
	for b in d.buildings:
		var def: Dictionary = D.BUILDINGS.get(String(b.key), {})
		if def.get("cat", "") != "deco" or (is_building(b) and not b.get("up", false)):
			continue
		n += int(def.get("deco", D.DECO_POINTS_OLD.get(String(b.key), 0)))
	return n


## Produktions-Bonus aus den Deko-Punkten (0 … D.DECO_BONUS_MAX).
func deco_bonus() -> float:
	return minf(float(deco_points()) * D.DECO_BONUS_PER, D.DECO_BONUS_MAX)


func prod_stored(b: Dictionary) -> int:
	if (is_building(b) and not b.get("up", false)) or prod_rate(b) <= 0.0:
		return 0
	var hours := clampf((now() - float(b.get("last_collect", now()))) / 3600.0, 0.0, D.PROD_STORE_HOURS)
	return int(prod_rate(b) * hours)


## Fassungsvermögen des Speichers eines Produktionsgebäudes.
func prod_cap(b: Dictionary) -> int:
	return maxi(1, int(round(prod_rate(b) * D.PROD_STORE_HOURS)))


## Ab dieser Menge erscheint die Sammelblase: 15 Minuten Produktion oder 5 % des Speichers (der kleinere Wert).
func prod_bubble_min(b: Dictionary) -> int:
	return maxi(1, int(minf(prod_rate(b) * 0.25, prod_cap(b) * 0.05)))


func collect(id: int) -> int:
	var b := get_building(id)
	if b.is_empty():
		return 0
	var amt := prod_stored(b)
	if amt <= 0:
		return 0
	var r: String = D.BUILDINGS[b.key].prod
	var got := add(r, amt)
	if got <= 0:
		toast.emit("%s-Lager ist voll" % D.RES_NAME[r])
		return 0
	# nur so viel Zeit abziehen, wie tatsächlich eingelagert wurde
	b.last_collect = now() - (amt - got) / maxf(prod_rate(b), 0.01) * 3600.0
	count_up("collected", got)
	mark()
	return got


# ================================================================= Helden
func hero(key := "") -> Dictionary:
	return d.heroes[key if key != "" else String(d.hero_sel)]


func hero_unlocked(key: String) -> bool:
	return bool(d.heroes[key].unlocked)


func unlock_hero(key: String) -> void:
	if hero_unlocked(key):
		return
	d.heroes[key].unlocked = true
	_grant_start_weapons(key)
	toast.emit("%s schließt sich dir an!" % D.HEROES[key].name)
	Sfx.play("hero_unlock", -2.0)
	mark()


func select_hero(key: String) -> void:
	if hero_unlocked(key) and not hero_busy(key) and not preload("res://src/story.gd").injured(key):      # V6 Paket E: verletzt
		d.hero_sel = key
		mark()


func hero_busy(key: String) -> bool:
	return float(d.heroes[key].auto_until) > 0.0


func add_hero_xp(key: String, n: float) -> void:
	var h: Dictionary = d.heroes[key]
	if key == "greta":
		n *= 1.2 if int(h.level) >= D.HERO_PASSIVE_LEVEL else 1.1
	n *= 1.0 + outpost_bonus("hero_xp")
	h.xp = float(h.xp) + n
	while int(h.level) < D.HERO_MAX_LEVEL and float(h.xp) >= D.hero_xp_need(int(h.level)):
		var nl := int(h.level) + 1
		if D.BADGE_GATES.has(nl) and int(d.badges[key]) < int(D.BADGE_GATES[nl]):
			h.xp = float(D.hero_xp_need(int(h.level)))      # wartet auf Abzeichen
			break
		if D.BADGE_GATES.has(nl):
			d.badges[key] = int(d.badges[key]) - int(D.BADGE_GATES[nl])
		h.xp = float(h.xp) - D.hero_xp_need(int(h.level))
		h.level = nl
		_grant_start_weapons(key)
		if nl % 5 == 0:
			add_gems(int(D.GEM_REWARD.hero5), "Heldenstufe")
		toast.emit("%s erreicht Stufe %d%s" % [D.HEROES[key].name, nl, hero_unlock_text(nl)])
		Sfx.play("hero_level_up", -4.0, 1.0, 0.8)
		hero_level_up.emit(key, nl)
	if int(h.level) >= D.HERO_MAX_LEVEL:
		h.xp = LO.prestige_xp(key, float(h.xp))               # Paket L: Erfahrung über Stufe 40 wird zu Prestige-Sternen
	mark()


## Was eine Heldenstufe freischaltet (für Meldungen), sonst "".
func hero_unlock_text(level: int) -> String:
	match level:
		D.HERO_DODGE2_LEVEL:
			return " – zweite Ausweichrolle"
		5:
			return " – zweite Fähigkeit"
		8:
			return " – zweite Waffe"
		10:
			return " – Spezialfähigkeit"
		D.HERO_CHARM_LEVEL:
			return " – Platz für Glücksbringer"
		16:
			return " – dritte Waffe"
		D.HERO_PASSIVE_LEVEL:
			return " – Besonderheit verstärkt"
	return ""


## Wartet der Held auf Abzeichen für die nächste Stufe? Rückgabe: fehlende Abzeichen oder 0.
func hero_badges_missing(key: String) -> int:
	var h: Dictionary = d.heroes[key]
	var nl := int(h.level) + 1
	if D.BADGE_GATES.has(nl):
		return maxi(0, int(D.BADGE_GATES[nl]) - int(d.badges[key]))
	return 0


## Kampfkraft: eine Zahl aus Stufe, Waffe, Ausrüstung und Talenten.
func hero_power(key: String) -> int:
	var h: Dictionary = d.heroes[key]
	var st := hero_stats(key)
	var wm := 1.0
	var it := item(int(h.weapon))
	if not it.is_empty():
		wm = weapon_mult(it)
	var off: float = (1.0 + float(st.m.dmg)) * wm * (1.0 + float(st.m.crit) * 0.5) * (1.0 + float(st.m.reload) * 0.5 + float(st.m.cdr) * 0.4)
	var def: float = (1.0 + float(st.m.hp)) * (1.0 + float(st.m.speed))
	return int(round(100.0 * off * sqrt(def)))


func area_danger(area: int, key: String) -> int:
	return int(D.AREA_HERO_LEVEL[area]) - int(d.heroes[key].level)


# ----------------------------------------------------------------- Trainingsplatz
func training_building() -> Dictionary:
	for b in d.buildings:
		if b.key == "training" and (not is_building(b) or b.get("up", false)):
			return b
	return {}


func train_rate() -> float:
	var b := training_building()
	if b.is_empty():
		return 0.0
	return D.TRAIN_XP_PER_HOUR + D.TRAIN_XP_PER_LEVEL * (int(b.level) - 1)


func trainee() -> String:
	return String(d.training.hero)


func set_trainee(key: String) -> void:
	_train_tick(now(), true)
	d.training.hero = key
	d.training.since = now()
	mark()


## Schreibt Trainings-Erfahrung gut (alle zehn Minuten), solange der Held nicht gespielt wird und nicht unterwegs ist.
func _train_tick(t: float, force := false) -> void:
	var key := String(d.training.hero)
	if key == "" or not d.heroes.has(key):
		return
	var dt := t - float(d.training.since)
	if dt < 600.0 and not force:
		return
	d.training.since = t
	if train_rate() <= 0.0 or key == String(d.hero_sel) or hero_busy(key) or not hero_unlocked(key):
		return
	add_hero_xp(key, train_rate() * minf(dt, 86400.0 * 3.0) / 3600.0)


func talent_points_free(key: String) -> int:
	var h: Dictionary = d.heroes[key]
	var spent := 0
	for t in h.talents:
		spent += int(t)
	return int(h.level) - 1 - spent


func talent_raise(key: String, tree: int) -> bool:
	var h: Dictionary = d.heroes[key]
	if talent_points_free(key) <= 0 or int(h.talents[tree]) >= 8:
		return false
	h.talents[tree] = int(h.talents[tree]) + 1
	mark()
	return true


func talent_reset(key: String) -> void:
	d.heroes[key].talents = [0, 0, 0]
	mark()


func chapters_open(key: String) -> int:
	var n := 0
	for lv in D.HERO_CHAPTER_LEVELS:
		if int(d.heroes[key].level) >= int(lv):
			n += 1
	return clampi(n, 1, 5)


## Fertige Kampfwerte eines Helden: Stufe, Talente, Ausrüstung und Kommandanten-Fähigkeiten eingerechnet.
func hero_stats(key: String) -> Dictionary:
	var def: Dictionary = D.HEROES[key]
	var h: Dictionary = d.heroes[key]
	var m := {"dmg": 0.0, "hp": 0.0, "speed": 0.0, "cdr": 0.0, "reload": 0.0, "range": 0.0, "pickup": 0.0, "tower": 0.0, "heal": 0.0, "ult": 0.0, "crit": 0.0, "carry": 0.0, "burn": 0.0}
	for t in 3:
		var stats: Array = def.trees[t].stats
		for i in int(h.talents[t]):
			m[stats[i][0]] += float(stats[i][1])
	var lv := int(h.level)
	for slot in h.gear:
		if slot == "charm" and lv < D.HERO_CHARM_LEVEL:
			continue
		var it := item(int(h.gear[slot]))
		if not it.is_empty():
			m[D.GEAR[slot].stat] += gear_value(it)
	HS.apply_sets(key, m)                                     # Paket H: Set-Boni (2 und 3 Teile)
	m.dmg += D.HERO_DMG_PER_LEVEL * (lv - 1) + cmd_bonus("hero_dmg")
	m.hp += D.HERO_HP_PER_LEVEL * (lv - 1) + cmd_bonus("hero_hp")
	m.reload += cmd_bonus("reload")
	m.cdr += cmd_bonus("cdr")
	m.carry += cmd_bonus("carry")
	var strong := lv >= D.HERO_PASSIVE_LEVEL
	if key == "jona":
		m.pickup += 0.5 if strong else 0.3
	if key == "yuki":
		m.crit += 0.25 if strong else 0.15
	LO.prestige_bonus(key, m)                                 # Paket L: Prestige-Sterne
	return {"hp": float(def.hp) * (1.0 + m.hp), "speed": float(def.speed) * (1.0 + m.speed), "m": m, "level": lv}


# ================================================================= Gegenstände
func item(id: int) -> Dictionary:
	if id <= 0:
		return {}
	for it in d.items:
		if int(it.id) == id:
			return it
	return {}


func make_item(slot: String, key: String, rarity: int) -> Dictionary:
	var it := {"id": int(d.next_item), "slot": slot, "key": key, "rarity": rarity, "level": 1, "mods": [], "new": true}
	d.next_item = int(d.next_item) + 1
	if slot == "weapon":
		var pool: Array = D.WEAPON_MODS.duplicate()
		pool.shuffle()
		for i in int(D.RARITY[rarity].mods):
			var md: Dictionary = pool[i]
			it.mods.append({"key": md.key, "val": snappedf(_rng.randf_range(md.min, md.max), 0.01)})
	d.items.append(it)
	mark()
	return it


func item_name(it: Dictionary) -> String:
	if it.slot == "weapon":
		var n: String = D.WEAPONS[it.key].name
		if it.mods.size() > 0:
			for md in D.WEAPON_MODS:
				if md.key == it.mods[0].key:
					n += " „%s“" % md.name
		return n
	var pn := HS.piece_name(it)                               # Paket H: Teil eines Sets
	if pn != "":
		return pn
	return D.GEAR_NAMES[it.slot][int(it.rarity)]


func item_lines(it: Dictionary) -> Array:
	var out: Array = []
	if it.slot == "weapon":
		out.append("Schaden ×%.2f" % weapon_mult(it))
		for m in it.mods:
			for md in D.WEAPON_MODS:
				if md.key == m.key:
					out.append(md.text % int(round(float(m.val) * 100.0)))
	else:
		out.append(D.GEAR[it.slot].text % int(round(gear_value(it) * 100.0)))
		if HS.set_of(it) != "":
			out.append("Set „%s“" % HS.set_name(HS.set_of(it)))      # Paket H
	return out


func weapon_mult(it: Dictionary) -> float:
	return float(D.RARITY[int(it.rarity)].mult) * (1.0 + D.LEVEL_DMG * (int(it.level) - 1))


func gear_value(it: Dictionary) -> float:
	return float(D.GEAR[it.slot].base) * [1.0, 1.5, 2.2, 3.0][int(it.rarity)] * (1.0 + 0.05 * (int(it.level) - 1))


func item_mod(it: Dictionary, key: String) -> float:
	for m in it.get("mods", []):
		if m.key == key:
			return float(m.val)
	return 0.0


func equipped_by(id: int) -> String:
	for k in d.heroes:
		var h: Dictionary = d.heroes[k]
		if int(h.weapon) == id:
			return k
		for s in h.gear:
			if int(h.gear[s]) == id:
				return k
	return ""


func equip(hero_key: String, id: int) -> bool:
	var it := item(id)
	if it.is_empty():
		return false
	var h: Dictionary = d.heroes[hero_key]
	if it.slot == "weapon":
		if D.WEAPONS[it.key].hero != hero_key:
			return false
		if int(h.level) < D.weapon_level(String(it.key)):
			toast.emit("%s ab Heldenstufe %d" % [String(D.WEAPONS[it.key].name), D.weapon_level(String(it.key))])
			return false
		h.weapon = id
	else:
		if it.slot == "charm" and int(h.level) < D.HERO_CHARM_LEVEL:
			toast.emit("Glücksbringer ab Heldenstufe %d" % D.HERO_CHARM_LEVEL)
			return false
		var other := equipped_by(id)
		if other != "" and other != hero_key:
			d.heroes[other].gear[it.slot] = 0
		h.gear[it.slot] = id
	it.new = false
	mark()
	return true


## Welcher Held bestimmt die Höchststufe dieses Stücks? Waffen: ihr Held. Ausrüstung: der Träger, sonst der beste Held.
func item_hero(it: Dictionary) -> String:
	if it.slot == "weapon":
		return String(D.WEAPONS[it.key].hero)
	var who := equipped_by(int(it.id))
	if who != "":
		return who
	var best := "jona"
	for hk in D.HERO_ORDER:
		if hero_unlocked(hk) and int(d.heroes[hk].level) > int(d.heroes[best].level):
			best = hk
	return best


## Höchste Stufe, auf die dieses Stück im Moment verbessert werden kann (hängt an der Heldenstufe).
func item_cap(it: Dictionary) -> int:
	return mini(int(D.RARITY[int(it.rarity)].max_level), D.item_cap(int(d.heroes[item_hero(it)].level)))


## Heldenstufe, die für die nächste Verbesserung nötig ist (0 = keine Sperre durch die Heldenstufe).
func item_need_level(it: Dictionary) -> int:
	if int(it.level) >= int(D.RARITY[int(it.rarity)].max_level) or int(it.level) < item_cap(it):
		return 0
	return int(it.level) * 3


func upgrade_item(id: int) -> bool:
	var it := item(id)
	if it.is_empty() or int(it.level) >= int(D.RARITY[int(it.rarity)].max_level):
		return false
	if int(it.level) >= item_cap(it):
		toast.emit("%s braucht Stufe %d für die nächste Verbesserung" % [item_hero(it).capitalize(), item_need_level(it)])
		return false
	var c := D.upgrade_cost(it)
	if not pay(c):
		toast.emit(missing_text(c))
		return false
	it.level = int(it.level) + 1
	mark()
	return true


func dismantle(id: int) -> int:
	var it := item(id)
	if it.is_empty() or equipped_by(id) != "":
		return 0
	# das letzte Exemplar einer Waffe bleibt erhalten
	if it.slot == "weapon":
		var n := 0
		for o in d.items:
			if o.slot == "weapon" and o.key == it.key:
				n += 1
		if n <= 1:
			toast.emit("Die letzte Waffe dieser Art kann nicht zerlegt werden")
			return 0
	var p := D.dismantle_parts(it)
	HS.release_modules(it)                                    # Paket H: Module zurück ins Lager
	d.items.erase(it)
	add("parts", p)
	mark()
	return p


## Drei gleiche Stücke derselben Seltenheit ergeben eines der nächsthöheren.
func merge_candidates(id: int) -> Array:
	var it := item(id)
	var out: Array = []
	if it.is_empty() or int(it.rarity) >= 3:
		return out
	for o in d.items:
		if o.slot == it.slot and o.key == it.key and int(o.rarity) == int(it.rarity) and int(o.id) != id and equipped_by(int(o.id)) == "":
			out.append(int(o.id))
	return out


func merge(id: int) -> Dictionary:
	var c := merge_candidates(id)
	if c.size() < 2:
		toast.emit("Dafür braucht es drei gleiche Stücke")
		return {}
	var it := item(id)
	var lvl := int(it.level)
	HS.release_modules(it)                                    # Paket H: Module zurück ins Lager
	for i in 2:
		HS.release_modules(item(c[i]))
		d.items.erase(item(c[i]))
	var owner := equipped_by(id)
	d.items.erase(it)
	var nw := make_item(it.slot, it.key, int(it.rarity) + 1)
	nw.level = lvl
	count_up("merges", 1)
	if owner != "":
		equip(owner, int(nw.id))
	mark()
	return nw


# ================================================================= Kisten
func chest_count(type := "") -> int:
	if type != "":
		return int(d.chests.get(type, 0))
	var n := 0
	for k in d.chests:
		n += int(d.chests[k])
	return n


func add_chest(type: String, n := 1) -> void:
	if social and social.hold("chest", n, type):          # Paket O: mit Server erst nach Bestätigung
		return
	d.chests[type] = chest_count(type) + n
	mark()


func _roll_rarity(table: Array, min_r: int) -> int:
	var luck := cmd_bonus("luck") * 100.0
	var t: Array = table.duplicate()
	# Glück verschiebt Anteile von Gewöhnlich nach oben
	var shift := minf(luck, float(t[0]) * 0.5)
	t[0] = float(t[0]) - shift
	t[1] = float(t[1]) + shift * 0.6
	t[2] = float(t[2]) + shift * 0.3
	t[3] = float(t[3]) + shift * 0.1
	var x := _rng.randf() * 100.0
	var r := 0
	var acc := 0.0
	for i in 4:
		acc += float(t[i])
		if x < acc:
			r = i
			break
	return maxi(r, min_r)


## Öffnet eine Kiste. Rückgabe: Liste der Stücke {rarity, text, kind, ...}; alles ist bereits gutgeschrieben.
func open_chest(type: String) -> Array:
	if chest_count(type) <= 0:
		return []
	d.chests[type] = chest_count(type) - 1
	var seed_v: int = social.chest_seed(type) if social else -1       # Paket O: Ziehung vom Server
	if seed_v >= 0:
		_rng.seed = seed_v
	var def: Dictionary = D.CHESTS[type]
	var out: Array = []
	var got_epic := false
	var got_legend := false
	var ap := Arsenal.chest_loot(type, _roll_rarity(def.table, 0))      # V4: Waffe oder Bauplan ersetzt ein Stück
	var egg: Dictionary = preload("res://src/welt_state.gd").chest_egg(type, null)   # Paket Welt: Begleiter-Ei ersetzt ein Stück (eigener Zufall)
	var md: Dictionary = {}                                   # Paket H: Waffenmodul ersetzt ein Stück (eines bleibt immer)
	if int(def.count) - (0 if ap.is_empty() else 1) - (0 if egg.is_empty() else 1) >= 2:
		md = HS.chest_module(type, _rng)
	for i in int(def.count) - (0 if ap.is_empty() else 1) - (0 if egg.is_empty() else 1) - (0 if md.is_empty() else 1):
		var min_r := 0
		if i == 0 and def.has("min_rarity"):
			min_r = int(def.min_rarity)
		if i == 0 and int(d.pity_legend) >= D.PITY_LEGEND:
			min_r = 3
		elif i == 0 and int(d.pity_epic) >= D.PITY_EPIC:
			min_r = maxi(min_r, 2)
		var r := _roll_rarity(def.table, min_r)
		if r >= 2:
			got_epic = true
		if r >= 3:
			got_legend = true
		out.append(_grant_piece(r, float(def.items)))
	if not ap.is_empty():
		out.append(ap)
	if not egg.is_empty():
		out.append(egg)
	if not md.is_empty():
		out.append(md)
	d.pity_epic = 0 if got_epic else int(d.pity_epic) + 1
	d.pity_legend = 0 if got_legend else int(d.pity_legend) + 1
	d.stats.chests = int(d.stats.chests) + 1
	if seed_v >= 0:
		_rng.randomize()
	quest_progress("chests", 1)
	add_xp(15)
	mark()
	return out


func _grant_piece(r: int, item_chance: float) -> Dictionary:
	var lvl := int(d.level)
	var scale: float = [1.0, 2.5, 6.0, 15.0][r] * (1.0 + 0.12 * lvl)
	if _rng.randf() < item_chance:
		var slot := "weapon"
		var key := ""
		if _rng.randf() < 0.3:
			slot = ["helmet", "vest", "charm"][_rng.randi() % 3]
			key = HS.roll_set(_rng)                               # Paket H: jedes neue Teil gehört zu einem Set
		else:
			var pool: Array = []
			var sel: String = d.hero_sel
			for hk in D.HERO_ORDER:
				if hero_unlocked(hk):
					var wk: Array = D.HEROES[hk].weapons
					for i in wk.size():
						if int(d.heroes[hk].level) >= D.WEAPON_UNLOCK_LEVELS[i]:
							pool.append(wk[i])
							if hk == sel:
								pool.append(wk[i])
								pool.append(wk[i])
			key = pool[_rng.randi() % pool.size()]
		var it := make_item(slot, key, r)
		return {"rarity": r, "kind": "item", "item": int(it.id), "text": item_name(it), "sub": D.RARITY[r].name}
	var x := _rng.randf()
	if x < 0.3:
		var amt := int(50 * scale)
		add("coins", amt)
		return {"rarity": r, "kind": "res", "res": "coins", "text": "%d Münzen" % amt, "sub": ""}
	elif x < 0.62:
		var opts: Array = ["wood", "stone"]
		var bl := bunker_level()
		if bl >= 3:
			opts.append("metal")
		if bl >= 4:
			opts.append("fuel")
		if bl >= 6:
			opts.append("cells")
		var rr: String = opts[_rng.randi() % opts.size()]
		var amt2 := int(40 * scale * (0.25 if rr == "cells" or rr == "fuel" else 1.0))
		add(rr, amt2)
		return {"rarity": r, "kind": "res", "res": rr, "text": "%d %s" % [amt2, D.RES_NAME[rr]], "sub": ""}
	elif x < 0.82:
		var amt3 := int([4, 10, 28, 80][r])
		add("parts", amt3)
		return {"rarity": r, "kind": "res", "res": "parts", "text": "%d Bauteile" % amt3, "sub": ""}
	elif x < 0.96 or r < 2:
		var heroes: Array = []
		for hk in D.HERO_ORDER:
			if hero_unlocked(hk):
				heroes.append(hk)
		var hk2: String = heroes[_rng.randi() % heroes.size()]
		var amt4 := int([2, 5, 12, 30][r])
		d.badges[hk2] = int(d.badges[hk2]) + amt4
		return {"rarity": r, "kind": "badge", "hero": hk2, "text": "%d Abzeichen" % amt4, "sub": D.HEROES[hk2].name}
	var amt5 := int([0, 0, 3, 10][r])
	add("shards", amt5)
	return {"rarity": r, "kind": "res", "res": "shards", "text": "%d Sternsplitter" % amt5, "sub": ""}


# ================================================================= Sieben-Tage-Zyklus
func week_day() -> int:
	return clampi(day_index() - int(d.week.start_day) + 1, 1, 7)


func flood_available() -> bool:
	return week_day() >= D.FLOOD_DAY and not bool(d.week.flood_done)


func flood_seconds_left() -> float:
	# Zeit bis zum Fluttag bzw. bis das Flutfenster endet
	var days_left := D.FLOOD_DAY - week_day()
	return seconds_to_next_day() + maxf(0.0, days_left - 1.0) * D.DAY_SECONDS


func practice_available() -> bool:
	return week_day() < D.FLOOD_DAY and int(d.week.practice_day) != day_index()


func _roll_week_dirs() -> void:
	var a := _rng.randi() % 4
	var b := (a + 1 + _rng.randi() % 3) % 4
	d.week.dirs = [a, b]


func _check_week() -> void:
	var di := day_index()
	# Fenster des Fluttags abgelaufen, ohne dass gestartet wurde: Basis verteidigt allein
	if di - int(d.week.start_day) + 1 > D.FLOOD_DAY:
		if not bool(d.week.flood_done):
			_auto_flood()
		_next_week(di)


func _next_week(di: int) -> void:
	d.week.number = int(d.week.number) + 1
	d.week.start_day = di
	d.week.flood_done = false
	_roll_week_dirs()
	roll_flood_guest()
	# Tag 1: kostenlose halbe Reparatur ist im Kampf-Code abgebildet (Gebäude starten voll)
	toast.emit("Woche %d beginnt" % int(d.week.number))
	mark()


func defense_score() -> float:
	var s := 0.0
	for b in d.buildings:
		var def: Dictionary = D.BUILDINGS[b.key]
		if def.cat == "def" and not is_building(b):
			var w := 1.0
			if def.has("tower"):
				var t: Dictionary = D.TOWERS[def.tower]
				w = float(t.damage) * float(t.rpm) / 60.0 * (1.0 + float(t.get("splash", 0.0)))
			s += w * pow(D.TOWER_DMG_GROWTH, int(b.level) - 1)
		elif def.cat == "wall":
			s += float(int(b.level)) * (2.0 if b.key == "tor" else 1.0)
		elif def.cat == "trap":
			s += 8.0
	return s


func _auto_flood() -> void:
	var fd := D.flood_def(int(d.week.number), bunker_level())
	var need := float(fd.total) * float(fd.hp) * 0.55
	var ratio := defense_score() * 0.8 / maxf(need, 1.0)
	var win := ratio >= 1.0
	var out := flood_result(win, clampf(ratio - 0.6, 0.1, 0.8) if win else 0.0, true, 0)
	BState.auto_flood(out, fd, ratio)                         # V6 Paket B: berechneter Rückblick, Verletzte
	toast.emit("Die Basis hat die Flut allein %s." % ("abgewehrt" if win else "nicht gehalten"))


## Trägt das Ergebnis der Wochenflut ein und vergibt Belohnungen.
func flood_result(win: bool, hp_ratio: float, auto: bool, kills: int) -> Dictionary:
	var out := {"win": win, "stars": 0, "chest": "", "lost": {}, "points": 0, "xp": 0}
	var wk := int(d.week.number)
	out["outpost"] = outpost_flood(win, wk, hp_ratio)
	d.week.easier = false
	if win:
		out.stars = 3 if hp_ratio >= 0.999 else (2 if hp_ratio >= 0.5 else 1)
		out.chest = "flood_gold" if out.stars == 3 and not auto else "flood_silver"
		out.points = int((300 + 200 * out.stars + 400 * hp_ratio) * (1.0 + 0.1 * wk) * (0.6 if auto else 1.0))
		d.stats.floods_won = int(d.stats.floods_won) + 1
		add("coins", 100 * wk + 50 * out.stars)
		add_gems(int(D.GEM_REWARD.flood), "Flut gewonnen")
		if out.stars == 3:
			add("shards", 2)
	else:
		out.chest = "flood_wood"
		out.points = int(80 * (1.0 + 0.1 * wk))
		d.stats.floods_lost = int(d.stats.floods_lost) + 1
		# Verlust: 20 % der gelagerten Rohstoffe, gedeckelt je Bunker-Stufe
		var limit := 300 * bunker_level()
		for r in ["coins", "wood", "stone", "metal"]:
			var loss := mini(int(res(r) * D.FLOOD_LOSS), limit)
			if loss > 0:
				d.res[r] = res(r) - loss
				out.lost[r] = loss
		# nach einer Niederlage wird die nächste Flut 15 % schwächer
		d.week.easier = true
	add_chest(out.chest)
	out.xp = int((120 + 40 * wk) * (1.0 if win else 0.4))
	add_xp(out.xp)
	d.week.flood_done = true
	d.week.last = out.duplicate()
	d.stats.kills = int(d.stats.kills) + kills
	quest_progress("kills", kills)
	if social:
		social.add_points("flood", int(out.points))
		social.add_clan_points(int(out.stars) * 40 + 20)
	LO.on_flood(win, out)                                     # Paket L: Saisonpunkte, Ereignis, Wochenaufgabe
	resources_changed.emit()
	mark()
	return out


func practice_done(win: bool, kills: int) -> Dictionary:
	d.week.practice_day = day_index()
	var coins := 40 + 15 * bunker_level() if win else 10
	add("coins", coins)
	var xp := 40 if win else 15
	add_xp(xp)
	if win:
		quest_progress("practice", 1)
		add_gems(int(D.GEM_REWARD.practice), "Übungsalarm")
	d.stats.kills = int(d.stats.kills) + kills
	quest_progress("kills", kills)
	mark()
	return {"win": win, "coins": coins, "xp": xp}


# ================================================================= Tagesaufträge
func _ensure_quests() -> void:
	var di := day_index()
	if int(d.quests.day) == di:
		return
	d.quests.day = di
	d.quests.claimed = false
	var pool: Array = D.QUESTS.duplicate()
	pool.shuffle()
	d.quests.list = []
	for i in 3:
		var q: Dictionary = pool[i]
		var amt := int(q.amount)
		if q.key in ["kills", "wood", "coins"]:
			amt = int(amt * (1.0 + 0.08 * int(d.level)))
		d.quests.list.append({"key": q.key, "text": q.text % amt, "amount": amt, "progress": 0})
	mark()


func quest_progress(key: String, n: int) -> void:
	LO.on_progress(key, n)                                    # Paket L: Ereignis, Wochenaufgaben, Saison
	if not d.has("quests"):
		return
	for q in d.quests.list:
		if q.key == key and int(q.progress) < int(q.amount):
			q.progress = mini(int(q.amount), int(q.progress) + n)
			if int(q.progress) >= int(q.amount):
				add_gems(int(D.GEM_REWARD.quest), "Tagesauftrag")
				LO.on_daily_quest()                            # Paket L: Saisonpunkte
				toast.emit("Auftrag erfüllt: " + String(q.text))
				Sfx.play("quest_done", -4.0, 1.0, 0.5)


func quests_done() -> bool:
	for q in d.quests.list:
		if int(q.progress) < int(q.amount):
			return false
	return d.quests.list.size() > 0


func claim_quests() -> bool:
	if not quests_done() or bool(d.quests.claimed):
		return false
	d.quests.claimed = true
	add_gems(int(D.GEM_REWARD.quests_all), "Alle Tagesaufträge")
	LO.on_daily_all()                                         # Paket L: Saisonpunkte, Wochenaufgabe
	add_chest("quest")
	add_xp(60)
	mark()
	return true


# ================================================================= Expeditionen
func area_unlocked(i: int) -> bool:
	if G.ch("nolimit"):
		return true
	if int(d.level) < int(D.AREAS[i].level):
		return false
	if i > 0 and not bool(d.areas.boss[i - 1][0]):
		return false
	return true


func area_lock_text(i: int) -> String:
	if int(d.level) < int(D.AREAS[i].level):
		return "Ab Spielerstufe %d" % int(D.AREAS[i].level)
	if i > 0 and not bool(d.areas.boss[i - 1][0]):
		return "Besiege zuerst %s (%s)" % [D.BOSSES[int(D.AREAS[i - 1].boss)].name, D.AREAS[i - 1].name]
	return ""


func fuel_cost(area: int) -> int:
	var k := D.OUTPOST_SIEGE_FUEL if outpost_besieged() == String(D.AREAS[area].key) else 1.0
	return int(ceil(float(D.AREAS[area].fuel) * k * (1.0 - cmd_bonus("fuel")) * (1.0 - outpost_bonus("fuel"))))


## Seit V3 gibt es je Gebiet nur noch die Expedition (Nebenaufgaben sind Orte auf der Karte) bzw. die Befreiung.
func missions_for(area: int) -> Array:
	if outpost_besieged() == String(D.AREAS[area].key):
		return ["befreiung"]
	return ["expedition"]


func backpack_cap(hero_key: String, vehicle_key: String) -> float:
	var c: float = D.BACKPACK * (1.0 + float(hero_stats(hero_key).m.carry))
	if vehicle_key != "":
		var v: Dictionary = d.vehicles[vehicle_key]
		c *= 1.0 + float(D.VEHICLES[vehicle_key].carry) * (1.0 + 0.15 * int(v.bed))
	c *= 1.0 + minf(D.OUTPOST_PACK_MAX, D.OUTPOST_PACK_BONUS * outpost_count())
	return c


## Schließt eine Expedition ab. loot: eingesammelte Rohstoffe. Rückgabe: Zusammenfassung für den Ergebnisbildschirm.
func expedition_finish(area: int, mission: String, diff: int, hero_key: String, success: bool, loot: Dictionary, chests_found: int, kills: int, time_s: float) -> Dictionary:
	var out := {"success": success, "loot": {}, "chests": [], "xp": 0, "hero_xp": 0, "unlocked": "", "first_daily": false}
	var share := 1.0 if success else 0.5
	var bonus := 1.0 + cmd_bonus("loot")
	for r in loot:
		var amt := int(float(loot[r]) * share * bonus)
		if amt > 0:
			out.loot[r] = add(r, amt)
	if success:
		for i in chests_found:
			add_chest("find")
			out.chests.append("find")
		if mission == "kopfgeld":
			if not bool(d.areas.boss[area][diff]):
				d.areas.boss[area][diff] = true
				add_chest("boss")
				out.chests.append("boss")
			else:
				add_chest("find")
				out.chests.append("find")
		if mission == "rettung":
			for hk in D.HERO_ORDER:
				if int(D.HEROES[hk].unlock_area) == area and not hero_unlocked(hk):
					unlock_hero(hk)
					out.unlocked = hk
					break                                         # Paket H: je Rettung ein Held
		if int(d.quests.daily_day) != day_index():
			d.quests.daily_day = day_index()
			add_chest("daily")
			out.chests.append("daily")
			out.first_daily = true
		quest_progress("expeditions", 1)
		d.stats.expeditions = int(d.stats.expeditions) + 1
		speed_up_builds(D.EXPEDITION_BUILD_SKIP)
	var lvl := int(D.AREAS[area].level)
	out.xp = int((60 + 8 * lvl) * (1.0 + 0.5 * diff) * (1.0 if success else 0.3))
	out.hero_xp = int((80 + 12 * lvl) * (1.0 + 0.5 * diff) * (1.0 if success else 0.3))
	add_xp(out.xp)
	add_hero_xp(hero_key, out.hero_xp)
	d.stats.kills = int(d.stats.kills) + kills
	quest_progress("kills", kills)
	if social and success:
		var pts := int((100 + 12 * lvl) * (1.0 + 0.6 * diff))
		social.add_points("explorer", pts)
		social.add_clan_points(10 + 5 * diff)
		if mission == "wettlauf":
			social.submit_time(area, time_s)
	mark()
	return out


## V3: Ende einer Expedition. home_loot = was heimkommt (Depot, bei Heimkehr auch Rucksack und Feldmünzen).
## info: bounty (Boss besiegt), rescued (Held befreit), race_time, chests (Fundkisten), outpost_lvl, relief (Belagerung beendet).
func expedition_end(area: int, diff: int, hero_key: String, success: bool, home_loot: Dictionary, info: Dictionary) -> Dictionary:
	var ak := String(D.AREAS[area].key)
	var o := outpost(ak)
	var out := {"success": success, "loot": {}, "kept": {}, "chests": [], "xp": 0, "hero_xp": 0, "unlocked": "", "first_daily": false}
	# alter Überschuss im Depot der Außenbasis (höchstens 24 Stunden) kommt zuerst
	var bundle := {}
	if float(o.get("depot_until", 0.0)) > now():
		for r in o.depot:
			bundle[r] = float(bundle.get(r, 0.0)) + float(o.depot[r])
	o.depot = {}
	o.depot_until = 0.0
	var bonus := 1.0 + cmd_bonus("loot")
	for r in home_loot:
		bundle[r] = float(bundle.get(r, 0.0)) + float(home_loot[r]) * (bonus if r != "coins" else 1.0)
	for r in bundle:
		var amt := int(float(bundle[r]))
		if amt <= 0:
			continue
		var got := add(r, amt)
		if got > 0:
			out.loot[r] = got
		if amt - got > 0:
			o.depot[r] = amt - got
			out.kept[r] = amt - got
	if not o.depot.is_empty():
		o.depot_until = now() + D.EXP_DEPOT_KEEP
	if success:
		Arsenal.expedition_loot(area, diff, hero_key, info, bool(info.get("bounty", false)) and not bool(d.areas.boss[area][diff]), out)
		for i in int(info.get("chests", 0)):
			add_chest("find")
			out.chests.append("find")
		if bool(info.get("bounty", false)):
			if not bool(d.areas.boss[area][diff]):
				d.areas.boss[area][diff] = true
				add_chest("boss")
				out.chests.append("boss")
			else:
				add_chest("find")
				out.chests.append("find")
		if bool(info.get("rescued", false)):
			for hk in D.HERO_ORDER:
				if int(D.HEROES[hk].unlock_area) == area and not hero_unlocked(hk):
					unlock_hero(hk)
					out.unlocked = hk
					break                                         # Paket H: je Rettung ein Held (Schrottküste: erst Yuki, dann Nele)
		if int(d.quests.daily_day) != day_index():
			d.quests.daily_day = day_index()
			add_chest("daily")
			out.chests.append("daily")
			out.first_daily = true
		quest_progress("expeditions", 1)
		d.stats.expeditions = int(d.stats.expeditions) + 1
		speed_up_builds(D.EXPEDITION_BUILD_SKIP)
	var lvl := int(D.AREAS[area].level)
	var share := 1.0 if success else D.EXP_ABORT_XP
	out.xp = int((60 + 8 * lvl) * (1.0 + 0.5 * diff) * share)
	out.hero_xp = int((D.EXP_DONE_XP[0] + D.EXP_DONE_XP[1] * lvl) * (1.0 + 0.5 * diff) * share)
	add_xp(out.xp)
	add_hero_xp(hero_key, out.hero_xp)
	var kills := int(info.get("kills", 0))
	d.stats.kills = int(d.stats.kills) + kills
	quest_progress("kills", kills)
	if social and success:
		social.add_points("explorer", int((100 + 12 * lvl) * (1.0 + 0.6 * diff)))
		social.add_clan_points(10 + 5 * diff)
		if float(info.get("race_time", 0.0)) > 0.0:
			social.submit_time(area, float(info.race_time))
	LO.on_expedition(area, diff, success, out)                # Paket L: Albtraum+
	out["outpost_level"] = int(o.level)
	resources_changed.emit()
	mark()
	return out


func start_auto(hero_key: String, area: int, hours: int) -> bool:
	if hero_busy(hero_key) or not hero_unlocked(hero_key) or not area_unlocked(area) or preload("res://src/story.gd").injured(hero_key):
		return false
	var other := ""
	for hk in D.HERO_ORDER:
		if hk != hero_key and hero_unlocked(hk) and not hero_busy(hk):
			other = hk
			break
	if other == "":
		toast.emit("Ein Held muss in der Basis bleiben")
		return false
	var cost := {"fuel": fuel_cost(area)}
	if not pay(cost):
		toast.emit(missing_text(cost))
		return false
	var h: Dictionary = d.heroes[hero_key]
	h.auto_until = now() + hours * 3600.0 / build_speed()
	h.auto_area = area
	h.auto_hours = hours
	if String(d.hero_sel) == hero_key:
		for hk in D.HERO_ORDER:
			if hero_unlocked(hk) and not hero_busy(hk):
				d.hero_sel = hk
				break
	mark()
	return true


func auto_ready(hero_key: String) -> bool:
	var h: Dictionary = d.heroes[hero_key]
	return float(h.auto_until) > 0.0 and now() >= float(h.auto_until)


func collect_auto(hero_key: String) -> Dictionary:
	if not auto_ready(hero_key):
		return {}
	var h: Dictionary = d.heroes[hero_key]
	var area := int(h.auto_area)
	var hours := int(h.auto_hours)
	var res_w: Dictionary = D.AREAS[area].res
	var tot := 0.0
	for r in res_w:
		tot += float(res_w[r])
	var loot := {}
	# 30 % einer selbst gespielten Expedition je 15 Minuten Abwesenheit, begrenzt
	var runs := hours * 1.6
	for r in res_w:
		var base := 260.0 * (1.0 + 0.1 * int(D.AREAS[area].level)) / float(D.RES_WEIGHT.get(r, 1.0))
		loot[r] = add(r, base * float(res_w[r]) / tot * D.AUTO_SHARE * runs * (1.0 + outpost_auto_bonus(area)))
	add_hero_xp(hero_key, 60.0 * hours)
	var t_end := float(h.auto_until)
	h.auto_until = 0.0
	h.auto_area = -1
	preload("res://src/auto_report.gd").finish(hero_key, area, hours, loot, t_end)     # V6 Paket E: Bericht, Ereignisse, Verletzung
	mark()
	return loot


# ================================================================= Fahrzeuge
func vehicle_sel() -> String:
	var k := String(d.vehicle_sel)
	if k != "" and bool(d.vehicles[k].owned):
		return k
	return ""


func buy_vehicle(key: String) -> bool:
	var def: Dictionary = D.VEHICLES[key]
	if bool(d.vehicles[key].owned):
		return false
	if not has_built("garage") and not G.ch("nolimit"):
		toast.emit("Baue zuerst eine Garage")
		return false
	if bunker_level() < int(def.bunker) and not G.ch("nolimit"):
		toast.emit("Ab Bunker-Stufe %d" % int(def.bunker))
		return false
	if not pay(def.cost):
		toast.emit(missing_text(def.cost))
		return false
	d.vehicles[key].owned = true
	d.vehicle_sel = key
	mark()
	return true


func vehicle_upgrade_cost(key: String, part: String) -> Dictionary:
	var lv := int(d.vehicles[key][part])
	return {"coins": int(300 * pow(1.7, lv)), "metal": int(120 * pow(1.6, lv))}


func upgrade_vehicle(key: String, part: String) -> bool:
	var v: Dictionary = d.vehicles[key]
	if not bool(v.owned) or int(v[part]) >= 5:
		return false
	var c := vehicle_upgrade_cost(key, part)
	if not pay(c):
		toast.emit(missing_text(c))
		return false
	v[part] = int(v[part]) + 1
	mark()
	return true


func vehicle_stats(key: String) -> Dictionary:
	var def: Dictionary = D.VEHICLES[key]
	var v: Dictionary = d.vehicles[key]
	return {"speed": float(def.speed) * (1.0 + 0.06 * int(v.motor)) * (1.0 + cmd_bonus("vehicle")) * (1.0 + outpost_bonus("vehicle_speed")), "hp": float(def.hp) * (1.0 + 0.15 * int(v.body))}


# ================================================================= Juwelen
func gems() -> int:
	return res("gems")


func add_gems(n: int, reason: String) -> void:
	if social and social.hold("gems", n, reason):          # Paket O: mit Server erst nach Bestätigung
		return
	if n <= 0:
		return
	d.res.gems = res("gems") + n
	_wallet_push()
	_gem_log(n, reason)
	Sfx.play("gem_get", -8.0, 1.0, 0.3)
	gems_changed.emit(n)
	resources_changed.emit()
	mark()


func spend_gems(n: int, reason: String) -> bool:
	if n <= 0 or G.ch("freegems"):
		return true
	if res("gems") < n:
		toast.emit("Es fehlen %d Juwelen" % (n - res("gems")))
		return false
	d.res.gems = res("gems") - n
	_wallet_push()
	if social:
		social.note_spend(n)                               # Paket O: Abgleich mit dem Server
	_gem_log(-n, reason)
	Sfx.play("gem_spend", -6.0)
	gems_changed.emit(-n)
	resources_changed.emit()
	mark()
	return true


func _gem_log(n: int, reason: String) -> void:
	var l: Array = d.gems_log
	l.append([int(now()), n, reason])
	while l.size() > 50:
		l.pop_front()


## Restzeit eines Baus in Sekunden; bei Mauern die des ganzen Auftrags.
func build_left(id: int) -> float:
	var b := get_building(id)
	if b.is_empty() or not is_building(b):
		return 0.0
	var e := float(b.done_at)
	var j := int(b.get("job", 0))
	if j > 0:
		e = _job_end(j)
	return maxf(0.0, e - now())


## Preis in Juwelen, um diesen Bau sofort fertigzustellen (0 = gratis: Restzeit unter einer Minute).
func speed_cost(id: int) -> int:
	if G.ch("freegems"):
		return 0
	return D.gem_cost(build_left(id))


func finish_now(id: int) -> bool:
	var b := get_building(id)
	if b.is_empty() or not is_building(b):
		return false
	if not spend_gems(speed_cost(id), "Bau beschleunigt: %s" % D.BUILDINGS[b.key].name):
		return false
	var j := int(b.get("job", 0))
	if j > 0:
		for p in job_pieces(j):
			p.done_at = now()
	else:
		b.done_at = now()
	Sfx.play("ui_buy", -4.0)
	_time_passed()
	return true


func drone_price() -> int:
	var n := int(d.get("drones_bought", 0))
	return int(D.GEM_DRONE_COST[n]) if n < D.GEM_DRONE_COST.size() else -1


func buy_drone() -> bool:
	var c := drone_price()
	if c < 0 or not spend_gems(c, "Baudrohne"):
		return false
	d.drones_bought = int(d.get("drones_bought", 0)) + 1
	toast.emit("Neue Baudrohne! Jetzt %d." % drones_total())
	mark()
	return true


func flag_color() -> Color:
	return Color(String(D.FLAG_COLORS[clampi(int(d.get("flag_color", 0)), 0, D.FLAG_COLORS.size() - 1)][1]))


func pick_flag(i: int) -> bool:
	var owned: Array = d.flags_owned
	if not (i in owned) and not (float(i) in owned):
		if not spend_gems(int(D.FLAG_COLORS[i][2]), "Flaggenfarbe"):
			return false
		owned.append(i)
	d.flag_color = i
	MK.set_flag_color(flag_color())
	mark()
	return true


func auto_speed_cost(hero_key: String) -> int:
	if G.ch("freegems"):
		return 0
	return D.gem_cost(maxf(0.0, float(d.heroes[hero_key].auto_until) - now()))


func finish_auto(hero_key: String) -> bool:
	if not hero_busy(hero_key) or auto_ready(hero_key):
		return false
	if not spend_gems(auto_speed_cost(hero_key), "Auto-Expedition beschleunigt"):
		return false
	d.heroes[hero_key].auto_until = now()
	mark()
	return true


# ----------------------------------------------------------------- Dinge, die in der Welt liegen und abgeholt werden
## at: Gebäudeschlüssel, über dem die Blase schwebt. bundle: {rohstoff: menge} (auch "gems"), optional "chest": Kistenart.
func add_pickup(kind: String, at: String, bundle: Dictionary, text: String) -> void:
	d.next_pickup = int(d.get("next_pickup", 1)) + 1
	d.pickups.append({"id": int(d.next_pickup) - 1, "kind": kind, "at": at, "bundle": bundle, "text": text})
	pickups_changed.emit()
	mark()


func has_pickup(kind: String) -> bool:
	for p in d.pickups:
		if p.kind == kind:
			return true
	return false


func claim_pickup(id: int) -> Dictionary:
	for p in d.pickups:
		if int(p.id) == id:
			var bundle: Dictionary = p.bundle
			for r in bundle:
				if r == "gems":
					add_gems(int(bundle[r]), String(p.text))
				elif r == "chest":
					add_chest(String(bundle[r]))
				else:
					add(String(r), float(bundle[r]))
			d.pickups.erase(p)
			pickups_changed.emit()
			mark()
			return p
	return {}


## Tägliches Geschenk: liegt als Blase am Bunker (Reihe über sieben Tage, dann von vorn).
func _check_daily() -> void:
	var di := day_index()
	if int(d.daily_gift.day) == di:
		return
	d.daily_gift.day = di
	if has_pickup("daily"):
		return
	LO.daily_gift()                                           # Paket L: 28-Tage-Login-Kalender statt der 7-Tage-Reihe


# ----------------------------------------------------------------- Zähler und Erfolge
func count_up(key: String, n: int) -> void:
	d.counters[key] = int(d.counters.get(key, 0)) + n


func stat(key: String) -> int:
	match key:
		"kills", "floods_won", "expeditions", "chests":
			return int(d.stats.get(key, 0))
		"bunker":
			return bunker_level()
		"level":
			return int(d.level)
		"heroes", "hero_level", "hero_levels":
			var n := 0
			var mx := 0
			var sum := 0
			for hk in D.HERO_ORDER:
				if hero_unlocked(hk):
					n += 1
					mx = maxi(mx, int(d.heroes[hk].level))
					sum += int(d.heroes[hk].level)
			return n if key == "heroes" else (mx if key == "hero_level" else sum)
		"vehicles":
			var v := 0
			for vk in d.vehicles:
				if bool(d.vehicles[vk].owned):
					v += 1
			return v
		"outposts":
			var o := 0
			for ak in d.outposts:
				if int(d.outposts[ak].get("level", 0)) >= 1:
					o += 1
			return o
		"bestiary":
			return d.bestiary.size()
	return int(d.counters.get(key, 0))


## Liste für die Anzeige: {def, tier, value, need, gems, ready, done}
func achievements() -> Array:
	var out: Array = []
	for a in D.ACHIEVEMENTS:
		var got := int(d.achievements.get(a.key, 0))
		var tiers: Array = a.tiers
		var done: bool = got >= tiers.size()
		var need := int(tiers[mini(got, tiers.size() - 1)])
		var v := stat(String(a.key))
		out.append({"def": a, "tier": got, "value": v, "need": need, "gems": int(a.gems[mini(got, tiers.size() - 1)]), "ready": not done and v >= need, "done": done})
	return out


func achievements_ready() -> int:
	var n := 0
	for a in achievements():
		if a.ready:
			n += 1
	return n


func claim_achievement(key: String) -> int:
	for a in achievements():
		if a.def.key == key and a.ready:
			d.achievements[key] = int(a.tier) + 1
			add_gems(int(a.gems), "Erfolg: %s" % String(a.def.name))
			var bp := Arsenal.roll("achievement", -1, "", 0, true, true)       # V4: jeder Erfolg bringt einen Bauplan
			if not bp.is_empty():
				toast.emit(String(bp.text))
			Sfx.play("ui_claim", -4.0)
			mark()
			return int(a.gems)
	return 0


# ----------------------------------------------------------------- Außenbasen (Vorteile; die Tabelle steht in data.gd)
## Summe eines Vorteils über alle Außenbasen, die stehen und nicht belagert sind. stat z. B. "prod_wood", "fuel", "hero_xp".
func outpost_bonus(stat_key: String) -> float:
	if not d.has("outposts"):
		return 0.0
	var sum := 0.0
	for ak in d.outposts:
		var o: Dictionary = d.outposts[ak]
		var lv := int(o.get("level", 0))
		if lv < 1 or bool(o.get("siege", false)) or not D.OUTPOSTS.has(ak):
			continue
		for e in D.OUTPOSTS[ak].effects:
			if String(e.stat) == stat_key:
				sum += float(e.base) + float(e.step) * (lv - 1)
	return sum


## Stand einer Außenbasis (legt ihn bei Bedarf an). Form: {level, paid: {platz: {rohstoff: menge}}, siege, depot, last_delivery}.
func outpost(ak: String) -> Dictionary:
	if not d.has("outposts"):
		d["outposts"] = {}
	if not d.outposts.has(ak):
		d.outposts[ak] = {}
	var o: Dictionary = d.outposts[ak]
	for k in [["level", 0], ["paid", {}], ["siege", false], ["depot", {}], ["depot_until", 0.0], ["last_delivery", -1], ["carry", {}], ["built_day", -1]]:
		if not o.has(k[0]):
			o[k[0]] = k[1]
	o.level = int(o.level)
	o.last_delivery = int(o.last_delivery)
	return o


func outpost_level(ak: String) -> int:
	return int(outpost(ak).level)


## Zahl der stehenden Außenbasen (Stufe 1 oder mehr).
func outpost_count() -> int:
	var n := 0
	for a in D.AREAS:
		if outpost_level(String(a.key)) >= 1:
			n += 1
	return n


func outpost_besieged() -> String:
	if not d.has("outposts"):
		return ""
	for ak in d.outposts:
		if bool(d.outposts[ak].get("siege", false)):
			return String(ak)
	return ""


func outpost_talbund() -> bool:
	for a in D.AREAS:
		if outpost_level(String(a.key)) < D.OUTPOST_TALBUND_LEVEL:
			return false
	return true


func outpost_auto_bonus(area: int) -> float:
	var ak := String(D.AREAS[area].key)
	var o := outpost(ak)
	return D.OUTPOST_AUTO_BONUS if int(o.level) >= 1 and not bool(o.siege) else 0.0


## Faktor für Schaden gegen Bosse (Forschungsstation).
func boss_dmg_mult() -> float:
	return 1.0 + outpost_bonus("boss_dmg")


## Preis eines Bauplatzes in diesem Gebiet (Baustoffe ersetzt, × Gebietsfaktor, × 2,2 je Ausbaustufe).
func outpost_pad_price(area: int, pad: Dictionary) -> Dictionary:
	var ea: Dictionary = D.EXP_AREAS[area]
	var k: float = float(ea.factor) * pow(D.OUTPOST_LEVEL_COST, int(pad.get("level", 1)) - 1)
	var out := {}
	for r in pad.price:
		var rr := String(r)
		if rr == "wood":
			rr = String(ea.mats[0])
		elif rr == "stone":
			rr = String(ea.mats[1])
		out[rr] = int(out.get(rr, 0)) + int(ceil(float(pad.price[r]) * k))
	return out


func outpost_paid(ak: String, pad_key: String) -> Dictionary:
	var o := outpost(ak)
	if not o.paid.has(pad_key):
		o.paid[pad_key] = {}
	return o.paid[pad_key]


## Eine Teilzahlung an einem Bauplatz verbuchen (bleibt auch nach Abbruch erhalten).
func outpost_pay(ak: String, pad_key: String, r: String, n: float) -> void:
	var pd := outpost_paid(ak, pad_key)
	pd[r] = float(pd.get(r, 0.0)) + n
	mark()


func outpost_pad_done(area: int, pad: Dictionary) -> bool:
	var pd := outpost_paid(String(D.AREAS[area].key), String(pad.key))
	var price := outpost_pad_price(area, pad)
	for r in price:
		if float(pd.get(r, 0.0)) < float(price[r]) - 0.001:
			return false
	return true


## Hebt die Stufe der Außenbasis (gibt Juwelen). Rückgabe: neue Stufe.
func outpost_set_level(ak: String, lvl: int) -> int:
	var o := outpost(ak)
	lvl = clampi(lvl, 0, D.OUTPOST_MAX_LEVEL)
	if lvl <= int(o.level):
		return int(o.level)
	var first: bool = int(o.level) == 0
	o.level = lvl
	if first:
		o.last_delivery = day_index()
		o.built_day = day_index()
		add_gems(int(D.GEM_REWARD.outpost), "Außenbasis fertig")
	else:
		add_gems(int(D.GEM_REWARD.outpost_up), "Außenbasis ausgebaut")
	count_up("outposts", 1)
	changed.emit()
	mark()
	return lvl


## Text eines Vorteils, z. B. "Holzproduktion +10 %".
func outpost_effect_text(e: Dictionary, lvl: int) -> String:
	var v := float(e.base) + float(e.step) * (maxi(lvl, 1) - 1)
	var td: Array = D.OUTPOST_STAT_TEXT.get(String(e.stat), [String(e.stat), "num"])
	match String(td[1]):
		"pct":
			return ("%s +%s %%" % [td[0], _num(v * 100.0)])
		"minus":
			return ("%s −%s %%" % [td[0], _num(v * 100.0)])
		"rate":
			return ("%s %s" % [td[0], _num(v)])
	return "%s: %s" % [td[0], _num(v)]


func _num(v: float) -> String:
	if absf(v - roundf(v)) < 0.01:
		return str(int(roundf(v)))
	return ("%.1f" % v).replace(".", ",")


## Alle wirksamen Vorteile (für die Liste in der Hauptbasis): [{area, special, level, siege, lines}]
func outpost_overview() -> Array:
	var out: Array = []
	for i in D.AREAS.size():
		var ak := String(D.AREAS[i].key)
		var o := outpost(ak)
		if int(o.level) < 1:
			continue
		var lines: Array = []
		for e in D.OUTPOSTS[ak].effects:
			lines.append(outpost_effect_text(e, int(o.level)))
		out.append({"area": i, "special": String(D.OUTPOSTS[ak].special), "level": int(o.level), "siege": bool(o.siege), "lines": lines})
	return out


## Tägliche Lieferung der Außenbasen: liegt als Kiste am Lager (höchstens drei Tage sammeln sich an).
func outpost_deliveries() -> void:
	if not d.has("outposts"):
		return
	var di := day_index()
	for ak in d.outposts:
		var o := outpost(String(ak))
		if int(o.level) < 1:
			continue
		var last := int(o.last_delivery)
		if last < 0:
			o.last_delivery = di
			continue
		if di <= last:
			continue
		var days := mini(di - last, D.OUTPOST_DELIVER_DAYS)
		o.last_delivery = di
		if bool(o.siege):
			continue
		var bundle := {}
		var maxb := {}
		for e in D.OUTPOSTS[ak].effects:
			if D.OUTPOST_DELIVER.has(String(e.stat)):
				var r: String = D.OUTPOST_DELIVER[String(e.stat)]
				var per := float(e.base) + float(e.step) * (int(o.level) - 1)
				var total := per * days + float(o.carry.get(r, 0.0))
				var whole := floorf(total)
				o.carry[r] = total - whole
				if whole > 0.0:
					bundle[r] = int(whole)
				maxb[r] = int(ceil(per * D.OUTPOST_DELIVER_DAYS))
		if bundle.is_empty():
			continue
		var kind := "outpost_" + String(ak)
		var merged := false
		for p in d.pickups:
			if p.kind == kind:
				for r in bundle:
					p.bundle[r] = mini(int(p.bundle.get(r, 0)) + int(bundle[r]), int(maxb.get(r, 999999)))
				merged = true
		if not merged:
			add_pickup(kind, "lager", bundle, "Lieferung aus %s" % String(D.OUTPOSTS[ak].special))
		else:
			pickups_changed.emit()
		mark()


## Nach der Flut: verlorene Flut belagert die am höchsten ausgebaute Außenbasis (nie mehr als eine).
## Gewonnene Flut mit „Talbund“: +10 % Münzen. Rückgabe: Schlüssel der neu belagerten Außenbasis oder "".
func outpost_flood(win: bool, wk: int, hp_ratio: float) -> String:
	if win:
		if outpost_talbund():
			var stars := 3 if hp_ratio >= 0.999 else (2 if hp_ratio >= 0.5 else 1)
			add("coins", (100 * wk + 50 * stars) * D.OUTPOST_TALBUND_FLOOD)
		return ""
	if outpost_besieged() != "":
		return ""
	var best := ""
	var bl := 0
	for a in D.AREAS:
		var lv := outpost_level(String(a.key))
		if lv > bl:
			bl = lv
			best = String(a.key)
	if best != "":
		outpost(best).siege = true
		toast.emit("Die Außenbasis %s wird belagert – ihr Vorteil ruht!" % String(D.OUTPOSTS[best].special))
		mark()
	return best


func outpost_relieve(ak: String) -> void:
	outpost(ak).siege = false
	changed.emit()
	mark()


# ================================================================= Gegner: Gastfamilien der Flut und Monsterbuch (Paket 11)
## Würfelt die Gastfamilien dieser Woche (Kapitel 11.4): Gebiete mit Außenbasis, sonst freigeschaltete Gebiete (ohne Grüntal).
func roll_flood_guest() -> void:
	var wk := int(d.week.number)
	var n := D.flood_guest_count(wk)
	var cands: Array = []
	for i in range(1, D.AREAS.size()):
		var o = d.outposts.get(String(D.AREAS[i].key))
		if o is Dictionary and int(o.get("level", 0)) >= 1:
			cands.append(String(D.AREAS[i].key))
	if cands.is_empty():
		for i in range(1, D.AREAS.size()):
			if area_unlocked(i):
				cands.append(String(D.AREAS[i].key))
	cands.shuffle()
	d["flood_guest"] = {"week": wk, "areas": cands.slice(0, n)}
	mark()


## Gastfamilien der laufenden Woche als Liste von Familien-Schlüsseln (D.FAMILIES).
func flood_guests() -> Array:
	if not d.has("flood_guest") or not (d.flood_guest is Dictionary) or int(d.flood_guest.get("week", -1)) != int(d.week.number):
		roll_flood_guest()
	var out: Array = []
	for ak in d.flood_guest.areas:
		for i in D.AREAS.size():
			if String(D.AREAS[i].key) == String(ak):
				out.append(String(D.AREA_FAMILY[i]))
	return out


## Text für die Ankündigung („Diese Woche: Untote Seeleute“) oder "".
func flood_guest_text() -> String:
	var names: Array = []
	for f in flood_guests():
		names.append(String(D.FAMILIES[f].name))
	return "" if names.is_empty() else "Diese Woche: " + " und ".join(names)


func bestiary_entry(key: String) -> Dictionary:
	if not d.bestiary.has(key):
		return {"seen": false, "kills": 0, "claimed": 0}
	var e: Dictionary = d.bestiary[key]
	return {"seen": bool(e.get("seen", true)), "kills": int(e.get("kills", 0)), "claimed": int(e.get("claimed", 0))}


## Gebündelt aus dem Kampf: besiegte Gegner je Art und neu gesehene Arten.
func bestiary_add(kills: Dictionary, seen: Array) -> void:
	for key in seen:
		if not d.bestiary.has(key):
			d.bestiary[key] = {"seen": true, "kills": 0, "claimed": 0}
	for key in kills:
		if not d.bestiary.has(key):
			d.bestiary[key] = {"seen": true, "kills": 0, "claimed": 0}
		d.bestiary[key]["kills"] = int(d.bestiary[key].get("kills", 0)) + int(kills[key])
	if not kills.is_empty() or not seen.is_empty():
		mark()


## Nächste offene Belohnung einer Art: Stufe 0..2 oder -1.
func bestiary_claimable(key: String) -> int:
	var e := bestiary_entry(key)
	var c := int(e.claimed)
	if c < D.BESTIARY_TIERS.size() and int(e.kills) >= int(D.BESTIARY_TIERS[c]):
		return c
	return -1


func bestiary_open_rewards() -> int:
	var n := 0
	for key in d.bestiary:
		if bestiary_claimable(String(key)) >= 0:
			n += 1
	return n


## Holt die nächste Belohnung ab (2 / 5 / 15 Juwelen). Rückgabe: Juwelen oder 0.
func bestiary_claim(key: String) -> int:
	var c := bestiary_claimable(key)
	if c < 0:
		return 0
	d.bestiary[key]["claimed"] = c + 1
	var g := int(D.BESTIARY_GEMS[c])
	add_gems(g, "Monsterbuch")
	mark()
	return g


# ================================================================= Felder ergänzen und alte Spielstände umstellen
## Ergänzt Felder, die neuere Versionen brauchen (schadet vorhandenen Werten nicht).
func _ensure_fields() -> void:
	d.version = VERSION
	if not d.res.has("gems"):
		d.res["gems"] = int(D.START_RES.gems)
	for k in [["gems_log", []], ["pickups", []], ["outposts", {}], ["bestiary", {}], ["achievements", {}], ["counters", {}], ["flags_owned", [0]]]:
		if not d.has(k[0]):
			d[k[0]] = k[1]
	for k in [["next_pickup", 1], ["next_job", 1], ["drones_bought", 0], ["flag_color", 0], ["obstacle_day", -1]]:
		if not d.has(k[0]):
			d[k[0]] = k[1]
		d[k[0]] = int(d[k[0]])
	if not d.settings.has("rain"):
		d.settings["rain"] = true
	if not d.has("daily_gift"):
		d["daily_gift"] = {"idx": 0, "day": -1}
	if not d.has("training"):
		d["training"] = {"hero": "", "since": 0.0}
	if not d.has("bunker_name") or String(d.bunker_name).strip_edges() == "":
		d["bunker_name"] = default_bunker_name()
	if not d.has("intro_seen"):
		d["intro_seen"] = true          # alte Stände: Intro nicht erzwingen
	if not d.has("blueprints"):
		d["blueprints"] = {}            # V4 Waffen-Arsenal: gefundene Baupläne
	HS.ensure(d)                        # Paket H: Waffenmodule, Sets für alte Ausrüstung, neue Heldin
	if not d.has("flood_guest"):
		d["flood_guest"] = {"week": -1, "areas": []}
	for k in [["rev", 0], ["server_time", 0.0], ["net_pending", []], ["net_spent", 0], ["chest_seeds", {}]]:     # Paket O: Cloud-Speicher, Serverbestätigung
		if not d.has(k[0]):
			d[k[0]] = k[1]
	for a in D.AREAS:
		outpost(String(a.key))
	for p in d.pickups:
		p.id = int(p.id)
	preload("res://src/companion_data.gd").ensure(d)        # Begleiter (Paket B)
	Guide.ensure(d)                                           # Spielerführung und Komfort (Paket F)
	preload("res://src/welt_state.gd").ensure(d)             # Welt: Tagebuch, Werkzeuge, Eier, Wünsche (Paket Welt)
	if d.areas.boss.size() > 0:                              # Paket Z: alte Stände bekommen das achte Gebiet (Vulkaninsel)
		while d.areas.boss.size() < D.AREAS.size():
			d.areas.boss.append([false, false, false])
	LO.ensure(d)                                              # Paket L: Live-Betrieb
	BState.ensure(d)                                          # V6 Paket B: Forschung, Rückblick, Verletzte, Mitteilungen
	preload("res://src/story.gd").ensure(d)                   # V6 Paket E: Geschichte, Gerettete, Berichte
	preload("res://src/modi.gd").ensure(d)                   # V6 Paket M: Turm, Überleben, Clan-Raid, Höhlen


## Einmalige Umstellung eines Stands der Version 2 (eine Kopie liegt in rustwall_v2_backup.json).
func _migrate_v3() -> void:
	# Mauern hatten eine gemeinsame Art nach Bunkerstufe; jetzt trägt jedes Stück seine eigene
	var tier := wall_tier()
	for b in d.buildings:
		if b.key == "wall":
			b.level = tier + 1
	# geschlossene Mauerringe bekommen ein Tor
	var made := ensure_gate()
	_grow_obstacles(true)
	_grow_obstacles(true)
	if made:
		toast.emit.call_deferred("Deine Mauer hat jetzt ein Tor.")
	mark()
	save()


## Ist die Basis ohne Ausgang zugemauert, wird das Mauerstück, das dem Weg vom Bunker zum unteren Rand am
## nächsten liegt, kostenlos durch ein Tor ersetzt. Rückgabe: wurde ein Tor gesetzt?
func ensure_gate() -> bool:
	if not enclosed():
		return false
	var bk := bunker()
	var bx := int(bk.x) + 2
	var by := int(bk.y) + 2
	var cands: Array = []
	for b in d.buildings:
		if b.key == "wall" and not is_building(b):
			var below := 0.0 if int(b.y) > by else 40.0
			cands.append([absf(int(b.x) - bx) + below + absf(int(b.y) - by) * 0.01, int(b.id)])
	cands.sort_custom(func(a, c): return a[0] < c[0])
	for i in mini(cands.size(), 120):
		var snap: Array = d.buildings.duplicate(true)
		var nid := int(d.next_id)
		var g := wall_to_gate(int(cands[i][1]), true)
		if not g.is_empty() and not enclosed():
			return true
		d.buildings = snap
		d.next_id = nid
	return false


# ================================================================= Testhilfe
## Baut eine brauchbare Basis für automatische Tests (und für den Testmodus in den Einstellungen).
func debug_setup(bl: int) -> void:
	new_game()
	no_save = true
	# das Start-Mauerstück weicht dem Ring der Testbasis
	for b0 in d.buildings.duplicate():
		if b0.key == "wall" or b0.key == "tor":
			d.buildings.erase(b0)
	d.level = clampi(bl * 5, 1, 60)
	var bk := bunker()
	bk.level = bl
	for r in D.RES:
		d.res[r] = cap(r) if D.CAP_BASE.has(r) or r == "coins" else 500
	var n := grid_size()
	var o := grid_origin()
	var c := o + int(n / 2)
	# Verteidigung in einem Ring um den Bunker, Mauer außen herum
	var ring: Array = [[-5, -5], [4, -5], [-5, 4], [4, 4], [-1, -6], [-1, 5], [-6, -1], [5, -1], [-8, -8], [7, -8], [-8, 7], [7, 7]]
	var keys: Array = ["mg", "mg", "kanone", "kanone", "mg", "mg", "wachturm", "wachturm", "flammenturm", "moerser", "tesla", "rakete"]
	var ri := 0
	for i in keys.size():
		var k: String = keys[i]
		if int(D.BUILDINGS[k].unlock) > bl or count(k) >= max_count(k):
			continue
		var s := size_of(k, 0)
		var x: int = c + int(ring[ri][0])
		var y: int = c + int(ring[ri][1])
		ri += 1
		if cells_free(x, y, s.x, s.y):
			var b := _add_building(k, x, y, 0, maxi(1, bl - 1))
			b.done_at = 0.0
	var r := 10
	var walls := 0
	var wmax := max_count("wall")
	for i in range(-r, r + 1):
		for p in [[c + i, c - r], [c + i, c + r], [c - r, c + i], [c + r, c + i]]:
			if walls < wmax and absi(i) > 1 and cells_free(int(p[0]), int(p[1]), 1, 1):
				_add_building("wall", int(p[0]), int(p[1]), 0, wall_tier() + 1)
				walls += 1
	for hk in D.HERO_ORDER:
		d.heroes[hk].unlocked = true
		d.heroes[hk].level = clampi(bl * 3, 1, D.HERO_MAX_LEVEL)
		_grant_start_weapons(hk)
	for vk in D.VEHICLES:
		d.vehicles[vk].owned = true
	d.vehicle_sel = "quad"
	buildings_changed.emit()
	resources_changed.emit()


# ================================================================= Städte (mehrere Spielstände) und Bunkername
func slot_path(n: int) -> String:
	return SAVE_PATH if n == 1 else "user://rustwall_city_%d.json" % n


func _read_cities() -> void:
	cities = {"current": 1, "list": {}}
	if FileAccess.file_exists(CITIES_PATH):
		var v = JSON.parse_string(FileAccess.get_file_as_string(CITIES_PATH))
		if v is Dictionary and v.has("list"):
			cities = v
	# Stände ohne Eintrag (z. B. aus Version 2) aufnehmen
	for n in range(1, MAX_CITIES + 1):
		if FileAccess.file_exists(slot_path(n)) and not cities.list.has(str(n)):
			cities.list[str(n)] = {"name": "Kommandant", "bunker_name": "Stadt %d" % n, "level": 1, "bunker": 1, "played": 0.0}
	slot = clampi(int(cities.get("current", 1)), 1, MAX_CITIES)
	_wallet_init()


func _write_cities() -> void:
	if no_save:
		return
	cities.current = slot
	var f := FileAccess.open(CITIES_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(cities, "\t"))


func _note_city() -> void:
	if no_save or d.is_empty():
		return
	cities.list[str(slot)] = {"name": String(d.get("name", "Kommandant")), "bunker_name": String(d.get("bunker_name", "")),
		"level": int(d.get("level", 1)), "bunker": bunker_level() if d.has("buildings") else 1, "played": Time.get_unix_time_from_system(),
		"code": String(d.social.get("code", "")) if d.get("social") is Dictionary else ""}
	_write_cities()


## Alle Städte, sortiert nach Platz: [{slot, name, bunker_name, level, bunker, played, current}]
func city_list() -> Array:
	var out: Array = []
	cities.list[str(slot)] = {"name": String(d.get("name", "Kommandant")), "bunker_name": bunker_name(), "level": int(d.get("level", 1)),
		"bunker": bunker_level(), "played": Time.get_unix_time_from_system()}
	for k in cities.list:
		var n := int(k)
		if n == slot or FileAccess.file_exists(slot_path(n)):
			var e: Dictionary = cities.list[k].duplicate()
			e.slot = n
			e.current = n == slot
			out.append(e)
	out.sort_custom(func(a, b): return int(a.slot) < int(b.slot))
	return out


func free_slot() -> int:
	for n in range(1, MAX_CITIES + 1):
		if n != slot and not cities.list.has(str(n)) and not FileAccess.file_exists(slot_path(n)):
			return n
	return -1


func check_bunker_name(nm: String, for_new := false) -> String:
	nm = nm.strip_edges()
	if nm.length() < BUNKER_NAME_MIN:
		return "Der Bunkername braucht mindestens %d Zeichen." % BUNKER_NAME_MIN
	if nm.length() > BUNKER_NAME_MAX:
		return "Der Bunkername darf höchstens %d Zeichen haben." % BUNKER_NAME_MAX
	for c in nm:
		if not (c.is_valid_identifier() or c in " -_.'!äöüÄÖÜß0123456789"):
			return "Erlaubt sind Buchstaben, Ziffern, Leerzeichen und - _ . ' !"
	for e in city_list():
		if (for_new or int(e.slot) != slot) and String(e.bunker_name).to_lower() == nm.to_lower():
			return "Eine deiner Städte heißt schon so."
	return ""


func default_bunker_name() -> String:
	var parts: Array = D.BUNKER_NAME_PARTS
	var h := absi(int(d.get("created", 0.0)) * 7919 + slot * 31)
	return "%s%s" % [parts[h % parts.size()], D.BUNKER_NAME_ENDS[(h / 7) % D.BUNKER_NAME_ENDS.size()]]


func rename_bunker(nm: String) -> String:
	var why := check_bunker_name(nm)
	if why != "":
		return why
	d.bunker_name = nm.strip_edges()
	mark()
	save()
	changed.emit()
	return ""


func bunker_name() -> String:
	return String(d.get("bunker_name", ""))


func _switched() -> void:
	social = Social.new(self)
	social.ensure()
	_after_load()
	_note_city()
	buildings_changed.emit()
	resources_changed.emit()
	changed.emit()
	city_changed.emit()


## Neue Stadt anlegen und sofort spielen. Rückgabe: Fehlertext oder "".
func create_city(bname: String) -> String:
	var n := free_slot()
	if n < 0:
		return "Es sind schon %d Städte angelegt. Lösche zuerst eine." % MAX_CITIES
	var why := check_bunker_name(bname, true)
	if why != "":
		return why
	save()
	slot = n
	new_game()
	d.bunker_name = bname.strip_edges()
	d.intro_seen = false
	_switched()
	save()
	return ""


func switch_city(n: int) -> String:
	if n == slot:
		return ""
	if not FileAccess.file_exists(slot_path(n)):
		return "Diese Stadt gibt es nicht mehr."
	save()
	var old := slot
	slot = n
	if not _load():
		slot = old
		_load()
		return "Diese Stadt konnte nicht geladen werden."
	_switched()
	return ""


## Stadt löschen (endgültig). Die gerade gespielte Stadt kann nicht gelöscht werden.
func delete_city(n: int) -> String:
	if n == slot:
		return "Die gerade gespielte Stadt kann nicht gelöscht werden. Wechsle zuerst in eine andere Stadt."
	var path := slot_path(n)
	if FileAccess.file_exists(path) and not no_save:
		var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		if err != OK:
			return "Löschen hat nicht geklappt (Fehler %d)." % err
	cities.list.erase(str(n))
	_write_cities()
	return ""


# ================================================================= Juwelen auf Konto-Ebene (Paket F, Kapitel 9.2)
## Juwelen gehören allen Städten gemeinsam: das Guthaben steht im Städte-Verzeichnis (Feld "wallet").
## d.res.gems ist nur die Kopie für die gerade gespielte Stadt (damit res("gems") überall weiter stimmt).
## Eine neue Stadt bekommt keine neuen Start-Juwelen. Alte Stände: Guthaben = höchster Stand einer Stadt (nicht die Summe).
func _wallet_init() -> void:
	if cities.has("wallet"):
		cities.wallet = int(cities.wallet)
		return
	var best := -1
	for n in range(1, MAX_CITIES + 1):
		var path := slot_path(n)
		if not FileAccess.file_exists(path):
			continue
		var v = JSON.parse_string(FileAccess.get_file_as_string(path))
		if v is Dictionary and v.get("res") is Dictionary:
			best = maxi(best, int(v.res.get("gems", 0)))
	cities["wallet"] = best if best >= 0 else int(D.START_RES.gems)
	cities["wallet_from"] = "max" if best >= 0 else "start"
	_write_cities()


## Konto-Guthaben in die gespielte Stadt übernehmen (nach Laden, Wechsel, neuer Stadt). Tests ohne Speichern: unverändert.
func _wallet_pull() -> void:
	if no_save or not cities.has("wallet") or d.is_empty():
		return
	d.res["gems"] = int(cities.wallet)


func _wallet_push() -> void:
	if no_save or d.is_empty():
		return
	cities["wallet"] = res("gems")
