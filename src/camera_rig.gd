extends Node3D
## Kamera: feste Schrägsicht wie im Referenzbild (55° Neigung, 45° gedreht), folgt dem Helden weich,
## Zoom per Mausrad oder Zwei-Finger-Geste, Wackeln bei Explosionen.

const YAW := PI * 0.25
const PITCH := 0.9599      # 55 Grad

var cam: Camera3D
var dist := 40.0
var focus := Vector3.ZERO
var bounds := Rect2(-60, -60, 120, 120)
var look_ahead := true
var override_target = null   # Vector3: fester Blickpunkt (Baumodus, Ergebnis)
var yaw_off := 0.0           # Hauptmenü und Intro: Kamera kreist um die Basis
var pitch_off := 0.0
var _shake := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 35.0
	cam.near = 1.0
	cam.far = 240.0
	add_child(cam)
	cam.current = true
	dist = 26.0 if G.is_touch else 29.0
	_apply(0.0)


func cam_basis() -> Basis:
	return cam.global_basis


## Bildschirmrichtung (x rechts, y unten) -> Richtung auf dem Boden (x, z).
func screen_to_world_dir(v: Vector2) -> Vector2:
	var right := Vector2(cos(YAW), -sin(YAW))
	var down := Vector2(sin(YAW), cos(YAW))
	return right * v.x + down * v.y


## Punkt auf dem Boden unter einer Bildschirmposition (oder null).
func ground_at(sp: Vector2):
	var o := cam.project_ray_origin(sp)
	var d := cam.project_ray_normal(sp)
	if d.y > -0.01:
		return null
	return o + d * (-o.y / d.y)


func mouse_ground():
	return ground_at(get_viewport().get_mouse_position())


func shake(amount: float) -> void:
	if P.d.settings.get("shake", true):
		_shake = maxf(_shake, amount)


func zoom(delta: float) -> void:
	dist = clampf(dist + delta, 16.0, 66.0)


func snap() -> void:
	_apply(0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom(-2.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(2.5)


func _process(dt: float) -> void:
	_apply(dt)


func _apply(dt: float) -> void:
	var target := focus
	if override_target != null:
		target = override_target
	elif G.player != null and is_instance_valid(G.player):
		target = G.player.global_position
		if look_ahead:
			var v: Vector3 = G.player.vel
			target += Vector3(v.x, 0, v.z).limit_length(6.0) * 0.3
	target.x = clampf(target.x, bounds.position.x, bounds.end.x)
	target.z = clampf(target.z, bounds.position.y, bounds.end.y)
	target.y = 0.0
	if dt <= 0.0:
		focus = target
	else:
		focus = focus.lerp(target, 1.0 - exp(-dt / 0.14))
	var d := dist
	if G.test_view == "close":
		d = 20.0
	elif G.test_view == "wide":
		d = 90.0
	var vp := get_viewport().get_visible_rect().size
	if vp.y > 0.0 and vp.x / vp.y < 1.5:
		d *= 1.15
	var yw := YAW + yaw_off
	var pt := PITCH + pitch_off
	var dir := Vector3(sin(yw) * cos(pt), sin(pt), cos(yw) * cos(pt))
	cam.global_position = focus + dir * d
	cam.look_at(focus, Vector3.UP)
	if _shake > 0.001:
		_shake = maxf(0.0, _shake - dt * 1.4)
		cam.global_position += cam.global_basis * Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), 0) * _shake
