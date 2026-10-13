extends Node3D
## Boss als echte, einzelne Figur: Teile-Hierarchie aus Blender mit Objekt-Animationen (AnimationPlayer),
## exportiert von blender/vat_bake.py → export_boss(). Alle Clips liegen hintereinander auf EINER Zeitleiste;
## models/e_<key>.json nennt Anfang und Dauer jedes Clips. Die Horde führt die Figur über follow().

const Models = preload("res://src/models.gd")

var info := {}
var ap: AnimationPlayer
var cur := "idle"
var t := 0.0
var once := false
var hold := ""
var dead := false
var _sink := 0.0
var _prev := ""
var _blend := 0.0
var auto := false                    # Vorschau (Monsterbuch): spielt von selbst idle, ab und zu einen Angriff
var _auto_t := 0.0


func setup(key: String, bi: Dictionary) -> void:
	info = bi
	var model := Models.glb("e_" + key)
	add_child(model)
	ap = _find_ap(model)
	if ap != null:
		var names := ap.get_animation_list()
		if names.size() > 1:
			# Blender exportiert je Körperteil eine eigene Animation (arm_l, head, …) auf derselben Zeitleiste; jede enthält
			# Spuren für alle Teile, bewegt aber nur ihr eigenes. Ein AnimationPlayer spielt nur eine davon – sonst bewegte sich
			# nur ein Teil. Darum je Teil die Spur nehmen, die sich wirklich bewegt, und alles zu einer Animation zusammenlegen.
			var lib := AnimationLibrary.new()
			lib.add_animation("all", _merged(String(model.scene_file_path), ap))
			ap.add_animation_library("rw", lib)
			ap.play("rw/all")
			ap.pause()
		elif names.size() > 0:
			ap.play(names[0])
			ap.pause()
	_seek()


static var _merge_cache := {}


## Wie stark sich eine Spur bewegt (Summe der Abstände aufeinanderfolgender Schlüssel).
static func _motion(a: Animation, ti: int) -> float:
	var n := a.track_get_key_count(ti)
	var m := 0.0
	for k in range(1, n):
		var v0 = a.track_get_key_value(ti, k - 1)
		var v1 = a.track_get_key_value(ti, k)
		if v0 is Vector3:
			m += (v1 - v0).length()
		elif v0 is Quaternion:
			m += (v0 as Quaternion).angle_to(v1)
		elif v0 is float or v0 is int:
			m += absf(float(v1) - float(v0))
		elif v0 != v1:
			m += 1.0
	return m


## Je Teil (Pfad + Spurart) die bewegteste Spur aller Teil-Animationen, als eine Animation (je Modell nur einmal gebaut).
static func _merged(key: String, player: AnimationPlayer) -> Animation:
	if key != "" and _merge_cache.has(key):
		return _merge_cache[key]
	var best := {}                       # "pfad|art" -> [Animation, Spur, Bewegung]
	var length := 0.0
	for nm in player.get_animation_list():
		if String(nm) == "RESET":
			continue
		var a: Animation = player.get_animation(nm)
		length = maxf(length, a.length)
		for ti in a.get_track_count():
			var k := "%s|%d" % [str(a.track_get_path(ti)), a.track_get_type(ti)]
			var mv := _motion(a, ti)
			if not best.has(k) or mv > float(best[k][2]):
				best[k] = [a, ti, mv]
	var out := Animation.new()
	for k in best:
		(best[k][0] as Animation).copy_track(int(best[k][1]), out)
	out.length = length
	if key != "":
		_merge_cache[key] = out
	return out


func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_ap(c)
		if r != null:
			return r
	return null


func has_clip(clip: String) -> bool:
	return info.clips.has(clip)


func clip_len(clip: String) -> float:
	return float(info.clips[clip].dur) if has_clip(clip) else 0.0


func hit_time(clip: String) -> float:
	if not has_clip(clip):
		return -1.0
	var hgt := float(info.clips[clip].get("hit", -1.0))
	return hgt if hgt >= 0.0 else clip_len(clip) * 0.5


## Einmaliger Clip. Rückgabe: Dauer oder 0, wenn es ihn nicht gibt.
func play(clip: String) -> float:
	if dead or not has_clip(clip):
		return 0.0
	cur = clip
	t = 0.0
	once = true
	return clip_len(clip)


func loop(clip: String) -> void:
	hold = clip if has_clip(clip) else ""


func die() -> void:
	if has_clip("death"):
		cur = "death"
		t = 0.0
		once = true
	dead = true


func _seek() -> void:
	if ap == null or not has_clip(cur):
		return
	var c: Dictionary = info.clips[cur]
	var dur := float(c.dur)
	var lt := fposmod(t, dur) if (bool(c.loop) and not once) else minf(t, dur - 0.001)
	ap.seek(float(c.start) + lt, true)


func _process(dt: float) -> void:
	if not auto:
		return
	_auto_t += dt
	if once and t >= clip_len(cur):
		once = false
		cur = "idle"
		t = 0.0
	if not once and _auto_t > 5.0:
		_auto_t = 0.0
		play("attack")
	t += dt
	_seek()


func follow(e, dt: float) -> void:
	position = Vector3(e.p.x, e.alt - _sink, e.p.y)
	rotation.y = e.yaw
	scale = Vector3.ONE * e.vs * (0.6 if e.shrink > 0.0 else 1.0)
	var rate := 1.0
	if once:
		if t >= clip_len(cur):
			if dead:
				_sink += dt * 1.2                    # liegt kurz, dann versinkt er
				return
			once = false
	if not once:
		var want := "idle"
		if hold != "":
			want = hold
		elif e.v.length_squared() > 0.05 and has_clip("walk"):
			want = "walk"
			var stride := float(info.clips.walk.get("stride", 0.0))
			if stride > 0.0:
				rate = e.v.length() / (stride * e.vs) * clip_len("walk")
		if want != cur:
			cur = want
			t = 0.0
	t += dt * rate
	_seek()
