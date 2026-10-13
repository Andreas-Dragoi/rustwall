extends Node3D
## V6 Paket E – Geschichte in der laufenden Welt (wird von main._swap an jede neue Welt gehängt, Story.attach).
##   Basis:      gerettete Figuren mit Tagesablauf (story_town.gd), Bewohner-Sprechblasen (chatter.gd), Lob nach Flut-Sieg,
##               Antippen der Geretteten (base_world._tap_npc → tap)
##   Expedition: Szene beim ersten Betreten des Gebiets, Szene nach dem ersten Sieg über den Gebietsboss (im Krater und auf der
##               Vulkaninsel danach die Abschlussszene des Akts), Rettung einer Figur (story_rescue.gd),
##               Helden-Gespräch beim Start (gespielter Held vor Ort, ein zweiter Held per Funk)

const D = preload("res://src/data.gd")
const DG = preload("res://src/data_geschichte.gd")
const Story = preload("res://src/story.gd")
const Speech = preload("res://src/speech.gd")
const Chatter = preload("res://src/chatter.gd")
const Town = preload("res://src/story_town.gd")
const Rescue = preload("res://src/story_rescue.gd")

var w: Node3D
var speech: CanvasLayer
var chatter: Node
var town                             # story_town.gd
var rescue_poi: Node3D
var is_exp := false
var _sec := 0.0
var _town_t := 0.0
var _boss_seen := false
var _talk: Array = []                # offene Zeilen des Helden-Gesprächs [[wer, held, text]]
var _talk_t := -1.0
var talk_lines := 0                  # (Test) gezeigte Zeilen
var scene_started := ""              # (Test) zuletzt von hier gestartete Szene


func _ready() -> void:
	speech = Speech.new()
	add_child(speech)
	_setup.call_deferred()


func _setup() -> void:
	if not is_instance_valid(w):
		return
	Story.demo()
	is_exp = String(w.get("mode")) == "exp" and w.get("area") != null
	if is_exp:
		_setup_exp()
	elif w.get("npc_board") != null and w.npc_board != null:
		_setup_base()
	# Bilder: --story_scene=<szene> --story_panel=<n> zeigt eine Szene (bleibt auf der Tafel stehen)
	if G.arg("story_scene") != "" and DG.SCENES.has(G.arg("story_scene")) and not Story.playing():
		var sc = Story.play(G.arg("story_scene"), Callable(), true)
		if sc != null:
			sc.hold_panel(int(G.arg("story_panel", "0")))


# ================================================================= Basis
func _setup_base() -> void:
	var s := Story.st()
	if not s.is_empty() and int(s.wins) < 0:
		s.wins = P.stat("floods_won") if P.d.has("stats") else 0
	# Boss-Szene verpasst (Expedition vorher beendet)? Dann jetzt in der Basis zeigen.
	if not Story.quiet():
		var pend := pending_scenes()
		if not pend.is_empty():
			_play_chain.call_deferred(pend)
	chatter = Chatter.new()
	chatter.name = "Chatter"
	chatter.w = w
	chatter.speech = speech
	chatter.town = town
	add_child(chatter)


## Szenen, die laut Fortschritt schon dran gewesen wären, aber nicht liefen (Boss besiegt, Szene nicht gesehen).
static func pending_scenes() -> Array:
	var out: Array = []
	for a in D.AREAS.size():
		if Story.boss_done(a) and Story.visited(a) and not Story.seen("a%d_boss" % a):
			out.append("a%d_boss" % a)
	if Story.boss_done(6) and Story.seen("a6_boss") and not Story.seen("end1"):
		out.append("end1")
	if Story.boss_done(7) and Story.seen("a7_boss") and not Story.seen("end2"):
		out.append("end2")
	if out.has("a6_boss") and not out.has("end1"):
		out.insert(out.find("a6_boss") + 1, "end1")
	if out.has("a7_boss") and not out.has("end2"):
		out.insert(out.find("a7_boss") + 1, "end2")
	return out


func _play_chain(ids: Array) -> void:
	if ids.is_empty() or not is_instance_valid(w):
		return
	var rest := ids.slice(1)
	_play(String(ids[0]), func(): _play_chain(rest))


## Antippen einer geretteten Figur (aus base_world._tap_npc).
func tap(sp: Vector2) -> bool:
	return town != null and town.tap(sp)


# ================================================================= Expedition
func _setup_exp() -> void:
	var a := int(w.area)
	var first := not Story.seen("a%d_in" % a) and not Story.visited(a)
	Story.mark_visited(a)
	rescue_poi = Rescue.place(w)
	if rescue_poi != null and G.arg("story_goto") != "":          # Bilder: Held neben die Rettung stellen
		w.hero.global_position = Vector3(rescue_poi.p.x + 5.0, 0, rescue_poi.p.y + 6.0)
		w.cam.snap()
	_boss_seen = Story.boss_done(a) or Story.seen("a%d_boss" % a)
	if first and not Story.quiet():
		_play.call_deferred("a%d_in" % a, _start_talk)
	elif not Story.quiet() or G.arg("talk") != "":
		_start_talk.call_deferred()


func _play(id: String, after := Callable()) -> void:
	if not is_instance_valid(w) or w.get("ended") == true:
		return
	scene_started = id
	Story.play(id, after)


## Helden-Gespräch: passendes Paar (gespielter Held + Held in der Basis), sonst Funk eines Bewohners mit Gebietshinweis.
func _start_talk() -> void:
	if not is_instance_valid(w) or w.hero == null:
		return
	_talk = build_talk(String(w.hero.key), int(w.area))
	_talk_t = 1.2


static func build_talk(lead: String, area: int, rng: RandomNumberGenerator = null) -> Array:
	var r := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var home: Array = []
	for hk in D.HERO_ORDER:
		if hk != lead and P.hero_unlocked(hk):
			home.append(hk)
	var fits: Array = []
	for t in DG.TALKS:
		if String(t.a) == lead and home.has(String(t.b)) and (int(t.area) < 0 or int(t.area) == area):
			fits.append(t)
	var area_fits: Array = fits.filter(func(t): return int(t.area) == area)
	var out: Array = []
	if not area_fits.is_empty() and r.randf() < 0.75:
		fits = area_fits
	if not fits.is_empty():
		var t: Dictionary = fits[r.randi() % fits.size()]
		for ln in t.lines:
			out.append(["a" if String(ln[0]) == "a" else "b", lead if String(ln[0]) == "a" else String(t.b), String(ln[1])])
		return out
	var who := String(home[r.randi() % home.size()]) if not home.is_empty() else ""
	var first := String(DG.TALK_AREA[clampi(area, 0, DG.TALK_AREA.size() - 1)]) if r.randf() < 0.7 else String(DG.TALK_RADIO[r.randi() % DG.TALK_RADIO.size()])
	out.append(["b", who, first])
	out.append(["a", lead, String(DG.TALK_LEAD[r.randi() % DG.TALK_LEAD.size()])])
	return out


func _tick_talk(dt: float) -> void:
	if _talk_t < 0.0 or _talk.is_empty():
		return
	if get_tree().paused or Story.playing():
		return
	_talk_t -= dt
	if _talk_t > 0.0:
		return
	var ln: Array = _talk.pop_front()
	if String(ln[0]) == "a":
		if w.hero != null and is_instance_valid(w.hero):
			speech.say(w.hero, String(ln[2]), DG.TALK_GAP + 1.4, 2.7)
	else:
		speech.radio(String(ln[1]), String(ln[2]), DG.TALK_GAP + 1.6)
	talk_lines += 1
	_talk_t = DG.TALK_GAP
	if _talk.is_empty():
		_talk_t = -1.0


## Sieg über den Gebietsboss: Szene (und danach Abschluss des Akts).
func _check_boss() -> void:
	if _boss_seen or not bool(w.get("bounty_done")):
		return
	_boss_seen = true
	var a := int(w.area)
	Story.mark_boss(a)
	if Story.quiet():
		return
	var id := "a%d_boss" % a
	var after := Callable()
	if a == 6:
		after = func(): _play("end1")
	elif a == 7:
		after = func(): _play("end2")
	get_tree().create_timer(2.2).timeout.connect(func():
		if is_instance_valid(self) and not Story.seen(id):
			_play(id, after))


func _process(dt: float) -> void:
	if not is_instance_valid(w):
		return
	if is_exp:
		_tick_talk(dt)
		_sec -= dt
		if _sec <= 0.0:
			_sec = 0.5
			_check_boss()
		return
	if town == null and chatter != null:
		_town_t += dt
		if _town_t > 0.5:                # erst wenn alle Gebäude in der Welt stehen (Türen, Arbeitspunkte)
			town = Town.new(w)
			chatter.town = town
	if town != null:
		town.update(dt)
		_sec -= dt
		if _sec <= 0.0:
			_sec = 1.0
			_check_win()
			_bandages()
			if town.npcs.size() != Story.rescued_list().size():
				town.sync()


## Von einer Auto-Expedition verletzte Helden laufen mit Kopfverband durch die Basis (Modell aus Paket B).
var _bandaged := {}


func _bandages() -> void:
	if w.get("life") == null or w.life == null or not w.life.has_method("_bandage"):
		return
	for n in w.npc_board.npcs:
		if n.hero_key == "":
			continue
		var want := Story.injured(String(n.hero_key))
		if want != bool(_bandaged.get(n.hero_key, false)):
			_bandaged[n.hero_key] = want
			w.life._bandage(n, want)


func _check_win() -> void:
	var s := Story.st()
	if s.is_empty() or not P.d.has("stats"):
		return
	var won := P.stat("floods_won")
	if won > int(s.wins):
		s.wins = won
		s.win_t = P.now()
