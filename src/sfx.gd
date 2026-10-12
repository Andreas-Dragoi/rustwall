extends Node
## Ton (Autoload "Sfx"). Alle Geräusche liegen als WAV-Dateien in res://audio/sfx/ (erzeugt von
## tools/make_sfx.py, jederzeit durch eigene Dateien gleichen Namens ersetzbar) und werden erst
## beim ersten Abspielen geladen.
##   Sfx.play("pop")                       – einfacher Klang; gibt es pop_1.wav, pop_2.wav …, wird gewürfelt
##   Sfx.play_at("pop", pos)               – wie play, aber leiser mit Abstand zur Bildmitte
##   Sfx.loop("engine", "engine_quad")     – Dauerschleife unter einer Kennung; loop_set / stop
## Unbekannte Namen werden still übergangen.

const DIR := "res://audio/sfx/"
const VOICES := 24
const MAX_SAME := 3            # so viele Stimmen darf derselbe Klang gleichzeitig belegen
const MAX_PER_FRAME := 6
const NEAR := 9.0              # bis hier volle Lautstärke (Meter um die Bildmitte)
const FAR := 46.0              # ab hier stumm
const LOOP_FADE := 0.18

## Alte Namen (und Sammelnamen), für die es keine eigene Datei gibt.
const ALIAS := {
	"shot_light": "w_burst", "shot_mg": "w_rifle", "shotgun": "w_nailer", "sniper": "w_sniper", "launcher": "w_parcel",
	"flame": "fire_whoosh", "water": "splash", "bow": "w_bow", "cannon": "t_cannon", "rocket": "t_rocket", "zap": "w_spark",
	"melee": "w_ball_swing", "hit": "slime_hit", "explosion": "explosion_small", "pop": "pop_small", "coin": "coin",
	"hurt": "hurt", "spit": "spit", "wall_hit": "wall_hit_wood", "wall_break": "wall_break_stone", "engine": "veh_mount",
	"skill": "skill_ready", "coin_drop": "coin_drop", "step": "step_grass",
}

## Wird nach dem Start nebenbei vorgeladen (eine Datei pro Bild), damit im Kampf nichts ruckelt.
const WARM := ["click", "w_rifle", "w_burst", "slime_hit", "pop_small", "pop_big", "coin", "coin_drop", "step_grass", "hurt",
	"reload", "reload_done", "explosion_small", "explosion_big", "t_mg", "t_cannon", "wall_hit_wood", "struct_hit", "spit", "wave"]

var _cache := {}                       # Name -> Array der Varianten (leer = gibt es nicht)
var _jitter := {}                      # Name -> bool: Tonhöhe leicht würfeln (nur kurze Klänge)
var _pick := {}                        # Name -> zuletzt gespielte Variante
var _last := {}                        # Name -> Zeit des letzten Abspielens
var _players: Array[AudioStreamPlayer] = []
var _p_name: Array[String] = []
var _p_time: PackedFloat64Array = PackedFloat64Array()
var _loops := {}                       # Kennung -> Loop
var _loop_free: Array[AudioStreamPlayer] = []
var _rng := RandomNumberGenerator.new()
var _frame := -1
var _frame_n := 0
var _vol := -1.0
var _poll := 0.0
var _warm_i := 0
var _bus := 0
var _bus_amb := 0                      # Mischpult (V5): Umgebung und Stimmen haben eigene Regler
var _bus_voice := 0
var _vol_amb := -1.0
var _vol_voice := -1.0
var _voice_t := {}                     # Held -> Zeit des letzten Rufs
var _vw := {}                          # beobachteter Held: Werte vom letzten Blick (Rufe ohne Eingriff in hero.gd)
var _vw_t := 0.0
var _log_on := false                   # Testhilfe: -- --sfxlog zählt mit, was gespielt wurde
var _log := {}


class Loop:
	var p: AudioStreamPlayer
	var sound := ""
	var vol := 0.0
	var pitch := 1.0
	var k := 0.0            # Einblendung 0..1
	var ttl := 0.0          # > 0: endet von selbst, wenn nicht aufgefrischt
	var dying := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 12345
	_bus = ensure_bus("SFX")
	_bus_amb = ensure_bus("Ambient")
	_bus_voice = ensure_bus("Voice")
	_log_on = OS.get_cmdline_user_args().has("--sfxlog")
	_p_time.resize(VOICES)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
		_p_name.append("")
		_p_time[i] = 0.0


## Legt einen Mischpult-Kanal an, falls es ihn noch nicht gibt, und gibt seine Nummer zurück.
func ensure_bus(bus_name: String) -> int:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, "Master")
	return i


## Schrittgeräusch passend zum Boden des Gebiets (D.AREAS-Eintrag).
func ground(theme: Dictionary) -> String:
	match String(theme.get("key", "")):
		"staub", "kueste":
			return "step_sand"
		"frost":
			return "step_snow"
		"vulkan":
			return "step_sand"                 # Asche und Lavakies
	return "step_grass"


## Umgebungs-Schleife passend zum Gebiet.
func ambience(theme: Dictionary) -> String:
	match String(theme.get("key", "")):
		"forst":
			return "amb_forest"
		"staub":
			return "amb_desert"
		"kueste":
			return "amb_coast"
		"sumpf":
			return "amb_swamp"
		"frost":
			return "amb_snow"
		"krater":
			return "amb_crater"
		"vulkan":
			return "amb_x_vulkan" if has("amb_x_vulkan") else "amb_crater"
	return "amb_meadow"


func has(sound: String) -> bool:
	return not _snd(sound).is_empty()


func play(sound: String, vol_db := 0.0, pitch := 1.0, min_gap := 0.045) -> void:
	if (sound == "win" or sound == "lose") and Music.has_stinger(sound):
		if _log_on:
			_log[sound] = int(_log.get(sound, 0)) + 1
		Music.stinger(sound)                   # Sieg/Niederlage: kurzes Musikstück statt Klang
		return
	var arr: Array = _snd(sound)
	if arr.is_empty():
		return
	if _vol < 0.0:
		_read_volume()
	if _vol <= 0.01:
		return
	var now := Time.get_ticks_msec() * 0.001
	if now - float(_last.get(sound, -10.0)) < min_gap:
		return
	var f := Engine.get_process_frames()
	if f != _frame:
		_frame = f
		_frame_n = 0
	_frame_n += 1
	if _frame_n > MAX_PER_FRAME:
		return
	_last[sound] = now
	if _log_on:
		_log[sound] = int(_log.get(sound, 0)) + 1
	# Stimme wählen: freie zuerst; spielt derselbe Klang schon oft genug, wird seine älteste ersetzt
	var free_i := -1
	var same := 0
	var same_old := -1
	var old_i := 0
	for i in VOICES:
		if not _players[i].playing:
			if free_i < 0:
				free_i = i
			continue
		if _p_name[i] == sound:
			same += 1
			if same_old < 0 or _p_time[i] < _p_time[same_old]:
				same_old = i
		if _p_time[i] < _p_time[old_i] or not _players[old_i].playing:
			old_i = i
	var idx := free_i
	if same >= MAX_SAME:
		idx = same_old
	elif idx < 0:
		idx = old_i
	var n := arr.size()
	var v := 0
	if n > 1:
		v = _rng.randi() % n
		if v == int(_pick.get(sound, -1)):
			v = (v + 1) % n
		_pick[sound] = v
	var p := _players[idx]
	p.bus = _bus_name_for(sound)
	p.stream = arr[v]
	p.volume_db = vol_db
	p.pitch_scale = pitch * (_rng.randf_range(0.95, 1.05) if _jitter.get(sound, false) else 1.0)
	p.play()
	_p_name[idx] = sound
	_p_time[idx] = now


## Klang an einem Ort der Welt: je weiter von der Bildmitte entfernt, desto leiser; weit weg gar nicht.
func play_at(sound: String, pos: Vector3, vol_db := 0.0, pitch := 1.0, min_gap := 0.045) -> void:
	var cam = G.cam
	if cam == null or not is_instance_valid(cam):
		play(sound, vol_db, pitch, min_gap)
		return
	var c: Vector3 = cam.focus
	var dx := pos.x - c.x
	var dz := pos.z - c.z
	var d := sqrt(dx * dx + dz * dz)
	if d > FAR:
		return
	if d > NEAR:
		vol_db -= (d - NEAR) * 0.5
	play(sound, vol_db, pitch, min_gap)


## Startet (oder aktualisiert) eine Dauerschleife. ttl > 0: sie verstummt von selbst, wenn sie nicht
## innerhalb dieser Zeit erneut aufgerufen wird (praktisch für "solange gefeuert wird").
func loop(id: String, sound: String, vol_db := 0.0, pitch := 1.0, ttl := 0.0) -> void:
	var l: Loop = _loops.get(id)
	if l != null and l.sound == sound:
		l.vol = vol_db
		l.pitch = pitch
		l.ttl = ttl
		l.dying = false
		return
	var arr: Array = _snd(sound)
	if arr.is_empty():
		return
	if l != null:
		_release(l)
	if _log_on:
		_log["loop:" + sound] = int(_log.get("loop:" + sound, 0)) + 1
	l = Loop.new()
	l.sound = sound
	l.vol = vol_db
	l.pitch = pitch
	l.ttl = ttl
	var p: AudioStreamPlayer = _loop_free.pop_back() if _loop_free.size() > 0 else null
	if p == null:
		p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		p.finished.connect(_on_loop_finished.bind(p))
	p.bus = _bus_name_for(id if _is_amb(id) else sound)
	var st: AudioStream = arr[0]
	if st is AudioStreamOggVorbis:
		st.loop = true
	if st is AudioStreamWAV and st.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = int(st.get_length() * st.mix_rate)
	p.stream = st
	p.volume_db = -60.0
	p.pitch_scale = pitch
	p.play(_rng.randf() * maxf(st.get_length() - 0.05, 0.0))
	l.p = p
	_loops[id] = l


## Wie loop, aber ortsabhängig: weit weg von der Bildmitte startet die Schleife gar nicht.
## Rufen mehrere Quellen im selben Bild dieselbe Kennung auf, zählt die lauteste.
func loop_at(id: String, sound: String, pos: Vector3, vol_db := 0.0, pitch := 1.0, ttl := 0.3) -> void:
	var cam = G.cam
	if cam != null and is_instance_valid(cam):
		var c: Vector3 = cam.focus
		var d := sqrt((pos.x - c.x) * (pos.x - c.x) + (pos.z - c.z) * (pos.z - c.z))
		if d > FAR:
			return
		if d > NEAR:
			vol_db -= (d - NEAR) * 0.5
	var l: Loop = _loops.get(id)
	if l != null and l.sound == sound and not l.dying and l.ttl >= ttl:
		vol_db = maxf(vol_db, l.vol)
	loop(id, sound, vol_db, pitch, ttl)


func loop_set(id: String, vol_db: float, pitch := 1.0) -> void:
	var l: Loop = _loops.get(id)
	if l != null:
		l.vol = vol_db
		l.pitch = pitch


func looping(id: String) -> bool:
	var l: Loop = _loops.get(id)
	return l != null and not l.dying


## Beendet eine Schleife (weich ausgeblendet).
func stop(id: String) -> void:
	var l: Loop = _loops.get(id)
	if l != null:
		l.dying = true


## Beendet alle Schleifen (Weltwechsel).
func stop_all() -> void:
	for id in _loops:
		_loops[id].dying = true


func _exit_tree() -> void:
	if _log_on:
		var names: Array = _log.keys()
		names.sort()
		var parts := PackedStringArray()
		for n in names:
			parts.append("%s=%d" % [n, _log[n]])
		print("SFXLOG %d Namen: %s" % [names.size(), " ".join(parts)])


func _release(l: Loop) -> void:
	l.p.stop()
	_loop_free.append(l.p)


func _on_loop_finished(p: AudioStreamPlayer) -> void:
	# falls eine Datei ohne Schleifenpunkte eingesetzt wurde: einfach wieder von vorn
	for id in _loops:
		var l: Loop = _loops[id]
		if l.p == p and not l.dying:
			p.play()
			return


## Lautstärke aus den Einstellungen auf den Kanal "SFX" übertragen (0 = stumm).
func _read_volume() -> void:
	var v := 0.8
	if P.d.has("settings"):
		v = clampf(float(P.d.settings.get("sfx", 0.8)), 0.0, 1.0)
	if not is_equal_approx(v, _vol):
		_vol = v
		AudioServer.set_bus_mute(_bus, v <= 0.01)
		AudioServer.set_bus_volume_db(_bus, linear_to_db(maxf(v, 0.01)))


func _process(dt: float) -> void:
	dt = minf(dt / maxf(Engine.time_scale, 0.01), 0.1)
	_poll -= dt
	if _poll <= 0.0:
		_poll = 0.3
		_read_volume()
		_read_mixer()
	_vw_t -= dt
	if _vw_t <= 0.0:
		_vw_t = 0.1
		_watch_hero()
	if _warm_i < WARM.size():
		_snd(WARM[_warm_i])
		_warm_i += 1
	if _loops.is_empty():
		return
	var dead := ""
	for id in _loops:
		var l: Loop = _loops[id]
		if l.ttl > 0.0 and not l.dying:
			l.ttl -= dt
			if l.ttl <= 0.0:
				l.dying = true
		l.k = move_toward(l.k, 0.0 if l.dying else 1.0, dt / LOOP_FADE)
		if l.dying and l.k <= 0.0:
			dead = id
			continue
		l.p.volume_db = l.vol + linear_to_db(maxf(l.k * l.k, 0.001))
		l.p.pitch_scale = lerpf(l.p.pitch_scale, l.pitch, minf(1.0, dt * 8.0))
	if dead != "":
		_release(_loops[dead])
		_loops.erase(dead)


# ---------------------------------------------------------------- Laden
func _snd(sound: String) -> Array:
	var arr = _cache.get(sound)
	if arr != null:
		return arr
	var out: Array = []
	if ResourceLoader.exists(DIR + sound + ".ogg"):        # lange Klänge und Schleifen als OGG (kleiner fürs Web); OGG vor WAV, falls alte WAV liegen geblieben sind
		out.append(load(DIR + sound + ".ogg"))
	elif ResourceLoader.exists(DIR + sound + ".wav"):
		out.append(load(DIR + sound + ".wav"))
	else:
		for i in range(1, 9):
			var path := "%s%s_%d.ogg" % [DIR, sound, i]
			if not ResourceLoader.exists(path):
				path = "%s%s_%d.wav" % [DIR, sound, i]
				if not ResourceLoader.exists(path):
					break
			out.append(load(path))
	if out.is_empty() and ALIAS.has(sound) and ALIAS[sound] != sound:
		out = _snd(ALIAS[sound])
	_cache[sound] = out
	if not out.is_empty():
		_jitter[sound] = out.size() > 1 or (out[0] as AudioStream).get_length() < 0.45
	return out


# ---------------------------------------------------------------- Mischpult und Stimmen (V5)
const VOICE_KINDS := ["start", "skill", "dodge", "hurt", "down", "cheer", "win"]
const VOICE_GAP := {"start": 3.0, "skill": 6.0, "dodge": 5.0, "hurt": 3.5, "down": 1.0, "cheer": 2.0, "win": 1.0}


## Umgebungsschleifen (amb…, nat_…, wx_…) laufen über den Kanal "Ambient", Rufe (v_…) über "Voice".
func _is_amb(n: String) -> bool:
	return n == "amb" or n.begins_with("amb_") or n.begins_with("nat_") or n.begins_with("wx_") or n.begins_with("ev_amb")


func _bus_name_for(n: String) -> String:
	if n.begins_with("v_"):
		return "Voice"
	if _is_amb(n):
		return "Ambient"
	return "SFX"


func _read_mixer() -> void:
	if not P.d.has("settings"):
		return
	var a := clampf(float(P.d.settings.get("amb", 0.8)), 0.0, 1.0)
	if not is_equal_approx(a, _vol_amb):
		_vol_amb = a
		AudioServer.set_bus_mute(_bus_amb, a <= 0.01)
		AudioServer.set_bus_volume_db(_bus_amb, linear_to_db(maxf(a, 0.01)))
	var v := clampf(float(P.d.settings.get("voice", 0.8)), 0.0, 1.0)
	if not is_equal_approx(v, _vol_voice):
		_vol_voice = v
		AudioServer.set_bus_mute(_bus_voice, v <= 0.01)
		AudioServer.set_bus_volume_db(_bus_voice, linear_to_db(maxf(v, 0.01)))


## Comic-Ruf eines Helden (v_<held>_<art>, mehrere Fassungen werden gewürfelt). Jede Art hat eine Pause.
func voice(hero_key: String, kind: String, vol_db := -4.0) -> void:
	var now := Time.get_ticks_msec() * 0.001
	var k := hero_key + ":" + kind
	if now - float(_voice_t.get(k, -99.0)) < float(VOICE_GAP.get(kind, 2.0)):
		return
	if now - float(_voice_t.get(hero_key, -99.0)) < 0.8 and kind != "down" and kind != "win":   # nie zwei Rufe übereinander
		return
	_voice_t[k] = now
	_voice_t[hero_key] = now
	if kind == "start" or kind == "win" or kind == "down":
		# beim Start und Sieg klingt gerade viel gleichzeitig: den Ruf kurz danach (sonst fällt er unter die Grenze je Bild)
		get_tree().create_timer(0.7, true, false, true).timeout.connect(func(): play("v_%s_%s" % [hero_key, kind], vol_db, 1.0, 0.2))
		return
	play("v_%s_%s" % [hero_key, kind], vol_db, 1.0, 0.2)


## Beobachtet den gesteuerten Helden (zehnmal je Sekunde) und ruft passend: Treffer, Ausweichen, Fähigkeit,
## Stufenaufstieg, Fallen, Sieg, Start. So braucht hero.gd keine eigenen Aufrufe.
func _watch_hero() -> void:
	var h = G.player
	var w = G.game
	if h == null or not is_instance_valid(h) or w == null or not is_instance_valid(w) or not ("key" in h):
		_vw = {}
		return
	var key := String(h.key)
	var sk_left := 0.0
	if h.skills != null:
		for sl in h.skills.slots:
			sk_left += float(sl.left)
	var cur := {"id": h.get_instance_id(), "hp": float(h.hp), "alive": bool(h.alive), "lv": int(h.level), "dodge": int(h.dodge_n),
		"sk": sk_left, "ended": bool(w.ended), "mode": String(w.mode)}
	if _vw.is_empty() or int(_vw.id) != int(cur.id) or String(_vw.mode) != String(cur.mode):
		_vw = cur
		if cur.mode != "peace":
			voice(key, "start", -5.0)
		return
	if cur.mode != "peace" and cur.alive:
		if float(cur.hp) < float(_vw.hp) - maxf(4.0, float(h.max_hp) * 0.06):
			voice(key, "hurt", -6.0)
		if int(cur.dodge) < int(_vw.dodge):
			voice(key, "dodge", -7.0)
		if float(cur.sk) > float(_vw.sk) + 1.0:
			voice(key, "skill", -5.0)
	if bool(_vw.alive) and not cur.alive:
		voice(key, "down", -4.0)
	if int(cur.lv) > int(_vw.lv):
		voice(key, "cheer", -4.0)
	if cur.ended and not bool(_vw.ended) and cur.mode != "peace":
		var r: Dictionary = w.result if "result" in w else {}
		if bool(r.get("win", r.get("success", false))):
			voice(key, "win", -3.0)
	_vw = cur
