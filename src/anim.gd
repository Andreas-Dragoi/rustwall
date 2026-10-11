extends RefCounted
## Kleine Dauer-Animationen für Modelle aus Blender. Objektnamen steuern die Bewegung:
## spin_* dreht sich, bob_* schwebt, sway_* wiegt sich, pulse_* pulsiert;
## Leerobjekte fx_smoke*, fx_spark*, fx_steam* bekommen Partikel (nicht fx_shell und fx_smoke_dmg: die bedienen
## tower.gd und structure.gd selbst).


## Sammelt alle animierten Knoten unter root. Rückgabe: Liste für tick().
static func collect(root: Node, with_fx := true) -> Array:
	var out: Array = []
	_walk(root, out, with_fx)
	return out


static func _walk(n: Node, out: Array, with_fx: bool) -> void:
	if n is Node3D:
		var nm := String(n.name)
		var ph: float = float(hash(nm) % 628) * 0.01 + (n as Node3D).position.x
		if nm.begins_with("spin_"):
			out.append([0, n, 0.0, ph])
		elif nm.begins_with("bob_"):
			out.append([1, n, n.position.y, ph])
		elif nm.begins_with("sway_"):
			var flag: bool = nm.contains("cloth") or nm.contains("flag") or nm.contains("banner")
			out.append([2 if flag else 3, n, n.rotation.y if flag else n.rotation.z, ph])
		elif nm.begins_with("pulse_"):
			out.append([4, n, n.scale.x, ph])
		elif nm == "fx_shell" or nm.begins_with("fx_smoke_dmg"):
			pass       # Hülsenauswurf (tower.gd) und Schadensrauch (structure.gd) werden dort bedient
		elif with_fx and nm.begins_with("fx_") and G.fx != null:
			var kind := "smoke"
			if nm.begins_with("fx_spark"):
				kind = "spark"
			elif nm.begins_with("fx_steam"):
				kind = "steam"
			G.fx.make_emitter(n, kind)
	for c in n.get_children():
		_walk(c, out, with_fx)


static func tick(list: Array, t: float, dt: float) -> void:
	for e in list:
		var n: Node3D = e[1]
		match e[0]:
			0:
				n.rotate_object_local(Vector3.UP, dt * 3.2)
			1:
				n.position.y = e[2] + sin(t * 2.2 + e[3]) * 0.09 - 0.05
			2:
				n.rotation.y = G.game.flag_yaw(n, e[2], t, e[3]) if G.game != null else e[2] + sin(t * 2.6 + e[3]) * 0.22
			3:
				n.rotation.z = e[2] + sin(t * 1.5 + e[3]) * 0.09
			4:
				var s: float = e[2] * (1.0 + 0.14 * sin(t * 4.5 + e[3]))
				n.scale = Vector3(s, s, s)
