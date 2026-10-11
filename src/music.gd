extends Node
## Musik (Autoload "Music"). Spielt zuerst das eigene Lied des Spielers; kurz vor dessen Ende setzt
## das nächste Stück ein und beide werden fünf Sekunden lang gleich laut überblendet (Kosinus/Sinus,
## die Summe der Leistung bleibt gleich). Danach geht es reihum weiter:
##   castle_defense -> meadow_march -> evening_base -> castle_defense …
## Music.set_mood("peace" | "battle" | "boss" | "menu") färbt Lautstärke und Auswahl leicht.
## Lautstärke: P.d.settings.music (0..1, Standard 0,6); bei 0 wird die Musik angehalten.

const DIR := "res://audio/music/"
const FADE := 5.0                # Dauer der Überblendung in Sekunden
const TAIL := 0.8                # so viel vor Dateiende gilt ein Stück als "musikalisch zu Ende"

## end: Zeitpunkt, an dem die Musik wirklich endet (Stille danach), für die mitgelieferte Datei gemessen
## (ffmpeg silencedetect). Wird die Datei ersetzt und ist anders lang, zählt Dateilänge - TAIL.
const TRACKS := [
	{"key": "castle_defense", "file": "castle_defense.mp3", "len": 359.66, "end": 359.2, "calm": false},
	{"key": "meadow_march", "file": "meadow_march.ogg", "len": 0.0, "end": 0.0, "calm": false},
	{"key": "evening_base", "file": "evening_base.ogg", "len": 0.0, "end": 0.0, "calm": true},
]
const MOOD_DB := {"peace": -1.5, "battle": 0.0, "boss": 1.0}

var _pl: Array[AudioStreamPlayer] = []
var _streams: Array = [null, null, null]
var _ends: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0])
var _req: Array[bool] = [false, false, false]
var _a := 0                      # Nummer des führenden Players
var _cur := -1                   # laufendes Stück
var _nxt := -1                   # einblendendes Stück (-1 = keine Überblendung)
var _pos := 0.0                  # eigene Uhr des laufenden Stücks (echte Sekunden)
var _pos_n := 0.0
var _fade_t := 0.0
var _fade_len := FADE
var _mood := "peace"
var _menu_req := false
var _menu := false
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus = Sfx.ensure_bus("Music")
	Sfx.ensure_bus("SFX")
	_lp = AudioEffectLowPassFilter.new()
	_lp.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(_bus, _lp)
	AudioServer.set_bus_effect_enabled(_bus, AudioServer.get_bus_effect_count(_bus) - 1, false)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		# Browser: Musik als Datenstrom abspielen. Im Standard („Sample“) würde das ganze Stück vorab
		# entpackt (über 100 MB) – auf dem iPhone kommt dann keine Musik; Lautstärke-Blenden gehen nur so.
		if OS.has_feature("web"):
			p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		add_child(p)
		_pl.append(p)
	_last_us = Time.get_ticks_usec()
	# Hinweis-Ton für Einblendungen; spielt die Oberfläche "ui_toast" selbst, wird der doppelte verschluckt
	P.toast.connect(func(_t: String): Sfx.play("ui_toast", -11.0, 1.0, 0.35))
	_request(0)
	if OS.get_cmdline_user_args().has("--musictest"):
		_test = true
		_run_test.call_deferred()


# ---------------------------------------------------------------- Öffentlich
## "peace", "battle", "boss" oder "menu". "menu" gilt nur, solange ein Menü offen ist
## (wird zusätzlich von selbst erkannt); die anderen Stimmungen bleiben, bis eine neue gesetzt wird.
func set_mood(mood: String) -> void:
	if mood == "menu":
		_menu_req = true
		return
	_menu_req = false
	if not MOOD_DB.has(mood) or mood == _mood:
		return
	_mood = mood
	# Kampf beginnt, während das ruhige Stück läuft: weich zum Marsch wechseln
	if mood != "peace" and _cur >= 0 and _nxt < 0 and TRACKS[_cur].calm and _pos > 4.0:
		_begin_fade(_pick_next(), 3.0)


func mood() -> String:
	return "menu" if _menu else _mood


func current() -> String:
	return TRACKS[_cur].key if _cur >= 0 else ""


func debug_state() -> String:
	var a := _pl[_a]
	var b := _pl[1 - _a]
	return "track=%s pos=%.1f/%.1f volA=%.1fdB volB=%.1fdB next=%s fade=%.2f bus=%.1fdB mood=%s master=%.2f playingA=%s playingB=%s" % [
		current(), _pos, _ends[_cur] if _cur >= 0 else 0.0, a.volume_db, b.volume_db,
		TRACKS[_nxt].key if _nxt >= 0 else "-", clampf(_fade_t / _fade_len, 0.0, 1.0) if _nxt >= 0 else 0.0,
		_bus_db, mood(), _master, a.playing and not a.stream_paused, b.playing and not b.stream_paused]


## Testhilfe: springt im laufenden Stück auf "seconds_before_end" vor dessen musikalischem Ende.
func debug_seek_to_end(seconds_before_end: float) -> void:
	if _cur < 0 or _nxt >= 0:
		return
	_pos = maxf(0.0, _ends[_cur] - seconds_before_end)
	_pl[_a].seek(_pos)
	_sync_block = 1.0


# ---------------------------------------------------------------- Ablauf
func _request(i: int) -> void:
	if _req[i]:
		return
	_req[i] = true
	var path: String = DIR + TRACKS[i].file
	if ResourceLoader.exists(path):
		ResourceLoader.load_threaded_request(path)


## Liefert das Stück, sobald es geladen ist (sonst null).
func _stream(i: int) -> AudioStream:
	if _streams[i] != null:
		return _streams[i]
	_request(i)
	var path: String = DIR + TRACKS[i].file
	if not ResourceLoader.exists(path):
		return null
	var st := ResourceLoader.load_threaded_get_status(path)
	if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return null
	var s = ResourceLoader.load_threaded_get(path) if st == ResourceLoader.THREAD_LOAD_LOADED else load(path)
	if not (s is AudioStream):
		return null
	if s is AudioStreamMP3 or s is AudioStreamOggVorbis:
		s.loop = false
	_streams[i] = s
	var length: float = s.get_length()
	var e := float(TRACKS[i].end)
	if e <= 0.0 or absf(length - float(TRACKS[i].len)) > 1.0:
		e = length - TAIL
	_ends[i] = maxf(e, 1.0)
	return s


func _pick_next() -> int:
	var n := TRACKS.size()
	var i := (_cur + 1) % n
	if _mood != "peace" and TRACKS[i].calm:        # im Kampf das ruhige Stück überspringen
		i = (i + 1) % n
	return i


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


func _start_first() -> void:
	var s := _stream(0)
	if s == null:
		return
	_wait_start = false
	_cur = 0
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
			_cur = _nxt
			_nxt = -1
			_pos = _pos_n
			_sync_block = 1.0
		return
	var left := _ends[_cur] - _pos
	if left <= FADE + 10.0:
		_request(_pick_next())                     # rechtzeitig im Hintergrund laden
	if left <= FADE:
		_begin_fade(_pick_next(), maxf(left, 0.5))


## Viermal pro Sekunde: Lautstärke-Einstellung, Menü/Pause erkennen, Uhr nachstellen, Flut-Alarm.
func _poll_state() -> void:
	var v := 0.6
	if P.d.has("settings"):
		v = clampf(float(P.d.settings.get("music", 0.6)), 0.0, 1.0)
	if not is_equal_approx(v, _master):
		_master = v
		var silent := v <= 0.005
		if silent != _silent:
			_silent = silent
			for p in _pl:
				if p.playing or p.stream_paused:
					p.stream_paused = silent
	var tree := get_tree()
	_paused = tree.paused
	_menu = _menu_req
	if G.main != null and G.main.screens != null and G.main.hud != null:
		_menu = G.main.ui_blocked()
	# Uhr an die tatsächliche Wiedergabe anlehnen (z. B. nach einer Unterbrechung der App)
	_sync_block -= 0.25
	if not _silent and _cur >= 0 and _pl[_a].playing and _sync_block <= 0.0 and _nxt < 0:
		var pp := _pl[_a].get_playback_position()
		if pp > 0.05 and absf(pp - _pos) > 0.35:
			_pos = pp
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


func _update_bus(dt: float) -> void:
	var target := -80.0
	if _master > 0.005:
		target = linear_to_db(_master) + float(MOOD_DB[_mood])
		if _paused:
			target -= 6.0
		elif _menu:
			target -= 2.5
	if absf(target - _bus_db) > 0.01:
		_bus_db = move_toward(_bus_db, target, dt * 30.0) if _bus_db > -60.0 and target > -60.0 else target
		AudioServer.set_bus_volume_db(_bus, _bus_db)
	# im Pausenmenü klingt die Musik gedämpft "wie hinter einer Tür" (Filter nur dann eingeschaltet)
	var want := 1.0 if _paused else 0.0
	if _lp_k != want:
		_lp_k = move_toward(_lp_k, want, dt * 3.0)
		var fx_i := AudioServer.get_bus_effect_count(_bus) - 1
		AudioServer.set_bus_effect_enabled(_bus, fx_i, _lp_k > 0.0)
		_lp.cutoff_hz = 20000.0 * pow(1400.0 / 20000.0, _lp_k)


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
