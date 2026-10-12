extends Node
## Musik (Autoload "Music"). Zwei Player überblenden weich (Kosinus/Sinus, die Summe der Leistung bleibt gleich).
##
## Wiedergabeliste der Hauptbasis (wie bisher): zuerst das eigene Lied des Spielers, kurz vor dessen Ende setzt das
## nächste Stück ein:  castle_defense -> meadow_march -> evening_base -> castle_defense …  (im Kampf ohne das ruhige Stück)
##
## Orte mit eigenem Stück (V5, tools/make_music.py), jeweils nahtlose Schleife:
##   Expedition   area_<gebiet>.ogg + area_<gebiet>_fight.ogg laufen synchron (AudioStreamSynchronized). Die Gefahr-Lage
##                wird je nach Kampfstärke um den Helden eingeblendet (Ruhe -> Gefahr), im Großangriff ganz.
##   Bosskampf    boss.ogg (Stimmung "boss" in Expedition und Flut)
##   Hauptmenü    menu.ogg (beim allerersten Start läuft zuerst das eigene Lied; danach im Hauptmenü dieses Stück)
## Stinger: win.ogg / lose.ogg ersetzen die Klänge "win" und "lose" (sfx.gd leitet sie hierher); die übrige Musik
## wird dafür kurz leiser.
## Music.set_mood("peace" | "battle" | "boss" | "menu") färbt Lautstärke und Auswahl.
## Lautstärke: P.d.settings.music (0..1, Standard 0,6; bei 0 wird die Musik angehalten).
## Web: alle Player spielen als Datenstrom (sonst würde das ganze Stück vorab entpackt).

const DIR := "res://audio/music/"
const FADE := 5.0                # Dauer der Überblendung in Sekunden (Wiedergabeliste)
const SWITCH := 2.5              # Überblendung beim Ortswechsel
const TAIL := 0.8                # so viel vor Dateiende gilt ein Stück als "musikalisch zu Ende"
const AREAS := ["gruental", "forst", "staub", "kueste", "sumpf", "frost", "krater", "vulkan"]
const LAYER_OFF := -40.0         # Gefahr-Lage ganz leise (dB)
const DUCK_DB := -14.0           # so viel leiser während eines Stingers

## end: Zeitpunkt, an dem die Musik wirklich endet (Stille danach), für die mitgelieferte Datei gemessen
## (ffmpeg silencedetect). Wird die Datei ersetzt und ist anders lang, zählt Dateilänge - TAIL.
## list: gehört zur Wiedergabeliste der Basis. loop: Schleife (Ort). layer: zweite, synchron laufende Lage.
const TRACKS := [
	{"key": "castle_defense", "file": "castle_defense.mp3", "len": 359.66, "end": 359.2, "calm": false, "list": true},
	{"key": "meadow_march", "file": "meadow_march.ogg", "len": 0.0, "end": 0.0, "calm": false, "list": true},
	{"key": "evening_base", "file": "evening_base.ogg", "len": 0.0, "end": 0.0, "calm": true, "list": true},
	{"key": "menu", "file": "menu.ogg", "loop": true},
	{"key": "boss", "file": "boss.ogg", "loop": true},
	{"key": "area_gruental", "file": "area_gruental.ogg", "layer": "area_gruental_fight.ogg", "loop": true},
	{"key": "area_forst", "file": "area_forst.ogg", "layer": "area_forst_fight.ogg", "loop": true},
	{"key": "area_staub", "file": "area_staub.ogg", "layer": "area_staub_fight.ogg", "loop": true},
	{"key": "area_kueste", "file": "area_kueste.ogg", "layer": "area_kueste_fight.ogg", "loop": true},
	{"key": "area_sumpf", "file": "area_sumpf.ogg", "layer": "area_sumpf_fight.ogg", "loop": true},
	{"key": "area_frost", "file": "area_frost.ogg", "layer": "area_frost_fight.ogg", "loop": true},
	{"key": "area_krater", "file": "area_krater.ogg", "layer": "area_krater_fight.ogg", "loop": true},
	{"key": "area_vulkan", "file": "area_vulkan.ogg", "layer": "area_vulkan_fight.ogg", "loop": true},
]
const STINGERS := {"win": "win.ogg", "lose": "lose.ogg"}
const MOOD_DB := {"peace": -1.5, "battle": 0.0, "boss": 1.0}

var _pl: Array[AudioStreamPlayer] = []
var _sting: AudioStreamPlayer
var _streams: Array = []
var _ends: PackedFloat32Array = PackedFloat32Array()
var _req: Array[bool] = []
var _a := 0                      # Nummer des führenden Players
var _cur := -1                   # laufendes Stück
var _nxt := -1                   # einblendendes Stück (-1 = keine Überblendung)
var _pos := 0.0                  # eigene Uhr des laufenden Stücks (echte Sekunden)
var _pos_n := 0.0
var _fade_t := 0.0
var _fade_len := FADE
var _mood := "peace"
var _menu_req := false           # Hauptmenü offen (set_mood("menu"))
var _menu := false               # irgendein Menü offen (dämpft)
var _paused := false
var _master := -1.0
var _silent := false
var _bus := 0
var _bus_db := -80.0
var _lp: AudioEffectLowPassFilter
var _lp_k := 0.0
var _poll := 0.0
var _sec := 0.0
var _last_us := 0
var _flood_av := false
var _flood_init := false
var _wait_start := true
var _test := false
var _sync_block := 0.0
var _first_done := false         # das eigene Lied hat einmal gespielt (danach darf das Hauptmenü sein Stück spielen)
var danger := 0.0                # 0..1 Kampfstärke um den Helden (Gefahr-Lage)
var _danger_target := 0.0
var _layer_db := LAYER_OFF
var _duck := 0.0                 # 0..1 Stinger-Dämpfung
var _duck_t := 0.0
var _ended_seen := false
var _place := ""                 # gewünschtes Ortsstück (Schlüssel) oder "" = Wiedergabeliste
var _list_last := -1             # zuletzt gespielte Nummer der Wiedergabeliste (nach einem Ortsstück geht es dort weiter)
var stingers_played: Array[String] = []    # (Test) gespielte Stinger


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus = Sfx.ensure_bus("Music")
	Sfx.ensure_bus("SFX")
	_streams.resize(TRACKS.size())
	_ends.resize(TRACKS.size())
	for i in TRACKS.size():
		_req.append(false)
	_lp = AudioEffectLowPassFilter.new()
	_lp.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(_bus, _lp)
	AudioServer.set_bus_effect_enabled(_bus, AudioServer.get_bus_effect_count(_bus) - 1, false)
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		# Browser: Musik als Datenstrom abspielen. Im Standard („Sample“) würde das ganze Stück vorab
		# entpackt (über 100 MB) – auf dem iPhone kommt dann keine Musik; Lautstärke-Blenden gehen nur so.
		if OS.has_feature("web"):
			p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		add_child(p)
		if i < 2:
			_pl.append(p)
		else:
			_sting = p
	_last_us = Time.get_ticks_usec()
	# Hinweis-Ton für Einblendungen; spielt die Oberfläche "ui_toast" selbst, wird der doppelte verschluckt
	P.toast.connect(func(_t: String): Sfx.play("ui_toast", -11.0, 1.0, 0.35))
	_request(0)
	if OS.get_cmdline_user_args().has("--musictest"):
		_test = true
		_run_test.call_deferred()


# ---------------------------------------------------------------- Öffentlich
## "peace", "battle", "boss" oder "menu". "menu" gilt nur, solange das Hauptmenü offen ist; die anderen
## Stimmungen bleiben, bis eine neue gesetzt wird.
func set_mood(mood: String) -> void:
	if mood == "menu":
		_menu_req = true
		return
	_menu_req = false
	if not MOOD_DB.has(mood) or mood == _mood:
		return
	_mood = mood
	# Kampf beginnt, während das ruhige Stück läuft: weich zum Marsch wechseln
	if mood != "peace" and _cur >= 0 and _nxt < 0 and bool(TRACKS[_cur].get("calm", false)) and _pos > 4.0:
		_begin_fade(_pick_next(), 3.0)


func mood() -> String:
	return "menu" if _menu else _mood


func current() -> String:
	return TRACKS[_cur].key if _cur >= 0 else ""


## Gibt es den Stinger als Datei? (sfx.gd fragt vor "win"/"lose")
func has_stinger(name: String) -> bool:
	return STINGERS.has(name) and ResourceLoader.exists(DIR + String(STINGERS[name]))


## Kurzes Siegel- oder Niederlagen-Stück; die laufende Musik wird solange leiser.
func stinger(name: String) -> void:
	if not has_stinger(name):
		return
	var s = load(DIR + String(STINGERS[name]))
	if s is AudioStreamOggVorbis:
		s.loop = false
	_sting.stream = s
	_sting.volume_db = 0.0
	_sting.play()
	_sting.stream_paused = _silent
	_duck_t = (s as AudioStream).get_length() - 1.0 if s is AudioStream else 6.0
	stingers_played.append(name)


func debug_state() -> String:
	var a := _pl[_a]
	var b := _pl[1 - _a]
	return "track=%s pos=%.1f/%.1f volA=%.1fdB volB=%.1fdB next=%s fade=%.2f bus=%.1fdB mood=%s master=%.2f playingA=%s playingB=%s layer=%.1fdB danger=%.2f" % [
		current(), _pos, _ends[_cur] if _cur >= 0 else 0.0, a.volume_db, b.volume_db,
		TRACKS[_nxt].key if _nxt >= 0 else "-", clampf(_fade_t / _fade_len, 0.0, 1.0) if _nxt >= 0 else 0.0,
		_bus_db, mood(), _master, a.playing and not a.stream_paused, b.playing and not b.stream_paused, _layer_db, danger]


## Lautstärke der Gefahr-Lage des laufenden Stücks (dB), -80 ohne Lage.
func layer_db() -> float:
	return _layer_db if _cur >= 0 and TRACKS[_cur].has("layer") else -80.0


## Testhilfe: springt im laufenden Stück auf "seconds_before_end" vor dessen musikalischem Ende.
func debug_seek_to_end(seconds_before_end: float) -> void:
	if _cur < 0 or _nxt >= 0:
		return
	_pos = maxf(0.0, _ends[_cur] - seconds_before_end)
	_pl[_a].seek(_pos)
	_sync_block = 1.0


func track_index(key: String) -> int:
	for i in TRACKS.size():
		if TRACKS[i].key == key:
			return i
	return -1


# ---------------------------------------------------------------- Ablauf
func _request(i: int) -> void:
	if _req[i]:
		return
	_req[i] = true
	for f in [TRACKS[i].file, TRACKS[i].get("layer", "")]:
		var path: String = DIR + String(f)
		if String(f) != "" and ResourceLoader.exists(path):
			ResourceLoader.load_threaded_request(path)


func _load_one(path: String):
	if not ResourceLoader.exists(path):
		return null
	var st := ResourceLoader.load_threaded_get_status(path)
	if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return false
	var s = ResourceLoader.load_threaded_get(path) if st == ResourceLoader.THREAD_LOAD_LOADED else load(path)
	return s if s is AudioStream else null


## Liefert das Stück, sobald es geladen ist (sonst null).
func _stream(i: int) -> AudioStream:
	if _streams[i] != null:
		return _streams[i]
	_request(i)
	var t: Dictionary = TRACKS[i]
	var s = _load_one(DIR + String(t.file))
	if s == null or s is bool:
		return null
	var loop := bool(t.get("loop", false))
	if s is AudioStreamMP3 or s is AudioStreamOggVorbis:
		s.loop = loop
	if t.has("layer"):
		var l = _load_one(DIR + String(t.layer))
		if l is bool:
			return null
		if l != null:
			if l is AudioStreamOggVorbis or l is AudioStreamMP3:
				l.loop = true
			var sy := AudioStreamSynchronized.new()
			sy.stream_count = 2
			sy.set_sync_stream(0, s)
			sy.set_sync_stream(1, l)
			sy.set_sync_stream_volume(0, 0.0)
			sy.set_sync_stream_volume(1, LAYER_OFF)
			s = sy
	_streams[i] = s
	if loop:
		_ends[i] = 1.0e9
	else:
		var length: float = s.get_length()
		var e := float(t.get("end", 0.0))
		if e <= 0.0 or absf(length - float(t.get("len", 0.0))) > 1.0:
			e = length - TAIL
		_ends[i] = maxf(e, 1.0)
	return s


func _pick_next() -> int:
	var n := TRACKS.size()
	var base := _cur if _cur >= 0 and bool(TRACKS[_cur].get("list", false)) else _list_last
	var i := (base + 1) % n if base >= 0 else 0
	for k in n:
		var t: Dictionary = TRACKS[i]
		if bool(t.get("list", false)) and not (_mood != "peace" and bool(t.get("calm", false))):   # im Kampf das ruhige Stück überspringen
			return i
		i = (i + 1) % n
	return 0


## Welches Ortsstück gerade gewünscht ist (-1 = Wiedergabeliste der Basis).
func _wanted() -> int:
	if _place != "":
		return track_index(_place)
	var w = G.main.world if G.main != null and "world" in G.main else null
	if _menu_req and _first_done:
		return track_index("menu")
	if w == null or not is_instance_valid(w):
		return -1
	if _mood == "boss" and w.mode != "peace" and not w.ended:
		return track_index("boss")
	if w.mode == "exp" and "adef" in w:
		return track_index("area_" + String(w.adef.key))
	return -1


func _begin_fade(next: int, length: float) -> void:
	var s := _stream(next)
	if s == null:
		return                                     # noch nicht geladen: nächstes Bild erneut
	var p := _pl[1 - _a]
	p.stream = s
	p.volume_db = -80.0
	p.stream_paused = false
	p.play(0.0)
	p.stream_paused = _silent
	_nxt = next
	_pos_n = 0.0
	_fade_t = 0.0
	_fade_len = maxf(length, 0.05)
	if TRACKS[next].has("layer"):
		_layer_db = LAYER_OFF
		danger = 0.0


func _start_first() -> void:
	# beginnt das Spiel gleich an einem Ort mit eigenem Stück (Expedition, Tests), läuft gleich dieses
	var first := _wanted() if not _test else -1
	if first < 0 or (_menu_req and not _first_done):
		first = 0
	var s := _stream(first)
	if s == null:
		return
	_wait_start = false
	_cur = first
	_pos = 0.0
	var p := _pl[_a]
	p.stream = s
	p.volume_db = 0.0
	p.play(0.0)
	p.stream_paused = _silent


func _process(_dt: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := minf((now - _last_us) * 0.000001, 0.25)      # echte Zeit, unabhängig vom Spieltempo
	_last_us = now
	_poll -= dt
	if _poll <= 0.0:
		_poll = 0.25
		_poll_state()
	_update_bus(dt)
	_update_layer(dt)
	if _wait_start:
		_start_first()
		return
	if _silent or _cur < 0:
		return
	_pos += dt
	if _nxt >= 0:
		_pos_n += dt
		_fade_t += dt
		var k := clampf(_fade_t / _fade_len, 0.0, 1.0)
		_pl[_a].volume_db = linear_to_db(maxf(cos(k * PI * 0.5), 0.0001))
		_pl[1 - _a].volume_db = linear_to_db(maxf(sin(k * PI * 0.5), 0.0001))
		if k >= 1.0:
			_pl[_a].stop()
			_pl[_a].volume_db = -80.0
			_a = 1 - _a
			_pl[_a].volume_db = 0.0
			if _cur == 0:
				_first_done = true
			if bool(TRACKS[_cur].get("list", false)):
				_list_last = _cur
			_cur = _nxt
			_nxt = -1
			_pos = _pos_n
			_sync_block = 1.0
		return
	if bool(TRACKS[_cur].get("loop", false)):
		return
	var left := _ends[_cur] - _pos
	if left <= FADE + 10.0:
		_request(_pick_next())                     # rechtzeitig im Hintergrund laden
	if left <= FADE:
		_begin_fade(_pick_next(), maxf(left, 0.5))


## Ortswechsel: das gewünschte Stück weich einblenden (oder zurück zur Wiedergabeliste).
func _check_place() -> void:
	if _cur < 0 or _nxt >= 0 or _wait_start:
		return
	var want := _wanted()
	if want >= 0:
		_request(want)
		if want != _cur:
			_begin_fade(want, SWITCH)
	elif not bool(TRACKS[_cur].get("list", false)):
		_begin_fade(_pick_next(), SWITCH)


## Viermal pro Sekunde: Lautstärke-Einstellung, Menü/Pause erkennen, Uhr nachstellen, Ort, Kampfstärke, Flut-Alarm.
func _poll_state() -> void:
	var v := 0.6
	if P.d.has("settings"):
		v = clampf(float(P.d.settings.get("music", 0.6)), 0.0, 1.0)
	if not is_equal_approx(v, _master):
		_master = v
		var silent := v <= 0.005
		if silent != _silent:
			_silent = silent
			for p in _pl + [_sting]:
				if p.playing or p.stream_paused:
					p.stream_paused = silent
	var tree := get_tree()
	_paused = tree.paused
	_menu = _menu_req
	if G.main != null and G.main.screens != null and G.main.hud != null:
		_menu = _menu_req or G.main.ui_blocked()
	# Uhr an die tatsächliche Wiedergabe anlehnen (z. B. nach einer Unterbrechung der App)
	_sync_block -= 0.25
	if not _silent and _cur >= 0 and _pl[_a].playing and _sync_block <= 0.0 and _nxt < 0 and not bool(TRACKS[_cur].get("loop", false)):
		var pp := _pl[_a].get_playback_position()
		if pp > 0.05 and absf(pp - _pos) > 0.35:
			_pos = pp
	if not _test or _place != "":
		_check_place()
	_danger_target = _measure_danger()
	_check_end()
	_sec += 0.25
	if _sec >= 1.0:
		_sec = 0.0
		var av: bool = P.d.has("week") and P.flood_available()
		if av and not _flood_av and _flood_init and G.main != null and G.main.world != null and G.main.world.mode == "peace":
			Sfx.play("flood_alarm", -2.0)
		if av and not _flood_init and G.main != null and G.main.world != null:
			Sfx.play("flood_alarm", -6.0)              # beim Start: die Flut steht schon bereit
		if G.main != null and G.main.world != null:
			_flood_init = true
			_flood_av = av


## Kampfstärke um den Helden: Gegner im Umkreis von 18 m (sechs zählen voll); Großangriff und Angriffe ganz.
func _measure_danger() -> float:
	if _place != "":
		return danger if _test else 0.0
	var w = G.main.world if G.main != null and "world" in G.main else null
	if w == null or not is_instance_valid(w) or w.mode != "exp" or w.ended or w.horde == null or w.hero == null:
		return 0.0
	var k := 0.0
	if "phase" in w and (w.phase == "siege" or w.phase == "relief"):
		k = 1.0
	elif "raid_warn" in w and w.raid_warn > 0.0:
		k = 0.7
	var n: int = w.horde.in_radius(w.hero.pos2(), 18.0).size()
	return maxf(k, clampf(float(n) / 6.0, 0.0, 1.0))


## Weiche Blende der Gefahr-Lage: schnell hoch (1,5 s), langsam herunter (5 s).
func _update_layer(dt: float) -> void:
	if danger < _danger_target:
		danger = minf(_danger_target, danger + dt / 1.5)
	else:
		danger = maxf(_danger_target, danger - dt / 5.0)
	var target := LAYER_OFF if danger <= 0.01 else lerpf(-14.0, 0.0, sqrt(danger))
	if absf(target - _layer_db) > 0.05:
		_layer_db = target
		for i in [_cur, _nxt]:
			if i >= 0 and _streams[i] is AudioStreamSynchronized:
				(_streams[i] as AudioStreamSynchronized).set_sync_stream_volume(1, _layer_db)


## Kampf zu Ende (Flut oder Expedition): Stinger spielt sfx.gd über "win"/"lose"; hier nur die Boss-Stimmung lösen.
func _check_end() -> void:
	var w = G.main.world if G.main != null and "world" in G.main else null
	var ended: bool = w != null and is_instance_valid(w) and w.mode != "peace" and w.ended
	if ended and not _ended_seen and _mood == "boss":
		_mood = "battle"
	_ended_seen = ended


func _update_bus(dt: float) -> void:
	if _duck_t > 0.0:
		_duck_t -= dt
		_duck = minf(1.0, _duck + dt / 0.3)
	else:
		_duck = maxf(0.0, _duck - dt / 1.5)
	var target := -80.0
	if _master > 0.005:
		target = linear_to_db(_master) + float(MOOD_DB[_mood])
		if _paused:
			target -= 6.0
		elif _menu:
			target -= 2.5
	# Stinger: der ganze Kanal wird leiser, der Stinger selbst gleicht das aus und bleibt voll
	var plain := target
	if target > -60.0:
		target += DUCK_DB * _duck
	if absf(target - _bus_db) > 0.01:
		_bus_db = move_toward(_bus_db, target, dt * 60.0) if _bus_db > -60.0 and target > -60.0 else target
		AudioServer.set_bus_volume_db(_bus, _bus_db)
	_sting.volume_db = clampf(plain - _bus_db, 0.0, 20.0) if plain > -60.0 else 0.0
	# im Pausenmenü klingt die Musik gedämpft "wie hinter einer Tür" (Filter nur dann eingeschaltet)
	var want := 1.0 if _paused else 0.0
	if _lp_k != want:
		_lp_k = move_toward(_lp_k, want, dt * 3.0)
		var fx_i := AudioServer.get_bus_effect_count(_bus) - 1
		AudioServer.set_bus_effect_enabled(_bus, fx_i, _lp_k > 0.0)
		_lp.cutoff_hz = 20000.0 * pow(1400.0 / 20000.0, _lp_k)


# ---------------------------------------------------------------- Testhilfen
## Test: Ortsstück erzwingen ("" = wieder automatisch).
func debug_place(key: String) -> void:
	_place = key
	if key != "":
		var i := track_index(key)
		if i >= 0 and i != _cur:
			_request(i)
			for k in 40:
				if _stream(i) != null:
					break
				OS.delay_msec(25)
			_begin_fade(i, 0.3)


func debug_danger(v: float) -> void:
	_danger_target = v
	danger = v


# ---------------------------------------------------------------- Selbsttest (-- --musictest)
func _run_test() -> void:
	var tree := get_tree()
	print("MUSICTEST start driver=%s" % AudioServer.get_driver_name())
	var t0 := Time.get_ticks_msec()
	while _cur < 0 and Time.get_ticks_msec() - t0 < 10000:
		await tree.process_frame
	print("MUSIC ", debug_state())
	var ok := _cur == 0
	var order := [0, 1, 2, 0]
	for step in 3:
		await tree.create_timer(1.0, true, false, true).timeout
		debug_seek_to_end(6.5)
		print("MUSIC seek ", debug_state())
		for i in 16:
			await tree.create_timer(0.5, true, false, true).timeout
			print("MUSIC ", debug_state())
		if _cur != order[step + 1] or _nxt >= 0:
			ok = false
			print("MUSICTEST FAIL: erwartet %s" % TRACKS[order[step + 1]].key)
	# Stimmung: Kampf überspringt das ruhige Stück
	set_mood("battle")
	await tree.create_timer(0.6, true, false, true).timeout
	print("MUSIC battle ", debug_state(), " next_pick=", TRACKS[_pick_next()].key)
	if _pick_next() != 1:
		ok = false
	set_mood("peace")
	# Ortsstück mit Gefahr-Lage
	debug_place("area_staub")
	await tree.create_timer(1.0, true, false, true).timeout
	debug_danger(1.0)
	await tree.create_timer(1.0, true, false, true).timeout
	print("MUSIC area ", debug_state())
	if current() != "area_staub" or layer_db() < -1.0:
		ok = false
		print("MUSICTEST FAIL: Gebietsstück mit Gefahr-Lage")
	debug_danger(0.0)
	debug_place("")
	# Lautstärke 0 hält an, danach geht es an derselben Stelle weiter
	P.d.settings["music"] = 0.0
	await tree.create_timer(0.8, true, false, true).timeout
	var p0 := _pos
	print("MUSIC silent ", debug_state())
	await tree.create_timer(0.8, true, false, true).timeout
	if absf(_pos - p0) > 0.01 or not _pl[_a].stream_paused:
		ok = false
		print("MUSICTEST FAIL: läuft trotz Lautstärke 0 weiter")
	P.d.settings["music"] = 0.6
	await tree.create_timer(0.8, true, false, true).timeout
	print("MUSIC resumed ", debug_state())
	if _pl[_a].stream_paused or _pos <= p0:
		ok = false
	# Pause dämpft
	tree.paused = true
	await tree.create_timer(1.0, true, false, true).timeout
	print("MUSIC paused ", debug_state(), " lowpass=%.0fHz" % _lp.cutoff_hz)
	tree.paused = false
	await tree.create_timer(0.6, true, false, true).timeout
	print("MUSICTEST OK" if ok else "MUSICTEST FAIL")
	tree.quit()
