extends SkeletonModifier3D
## Richtet den Waffen-Knochen (prop_r) genau auf einen Weltpunkt aus – auf kürzestem Weg aus der animierten Haltung,
## damit die Waffe nicht um ihre Längsachse kippt. Läuft nach den LookAtModifier3D für Brust und Kopf.
## Bei großem Fehlwinkel (Ziel seitlich oder hinter der Figur) bleibt die Waffe in der animierten Haltung.

var bone := -1
var target := Vector3.ZERO           # Weltkoordinaten
var weight := 0.0                    # 0..1
var max_deg := 38.0                  # darüber keine Korrektur (weich ausgeblendet ab 75 % davon)
var error_deg := 0.0                 # Fehlwinkel vor der Korrektur (für Tests)


func _process_modification_with_delta(_delta: float) -> void:
	if weight <= 0.001 or bone < 0:
		return
	var sk := get_skeleton()
	if sk == null:
		return
	var xf := sk.get_bone_global_pose(bone)
	var gt := sk.global_transform
	var dir := gt.basis.inverse() * (target - gt * xf.origin)
	if dir.length() < 0.05:
		return
	dir = dir.normalized()
	var fwd := xf.basis.z.normalized()
	var ang := rad_to_deg(fwd.angle_to(dir))
	error_deg = ang
	var w := weight * clampf((max_deg - ang) / (max_deg * 0.25), 0.0, 1.0)
	if w <= 0.001 or ang < 0.01:
		return
	var axis := fwd.cross(dir)
	if axis.length() < 0.00001:
		return
	xf.basis = Basis(axis.normalized(), deg_to_rad(ang) * w) * xf.basis
	sk.set_bone_global_pose(bone, xf)
