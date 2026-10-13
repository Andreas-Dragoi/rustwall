extends RefCounted
## Layouts teilen und testen (V6 Paket B, Kapitel 4.1).
##
## Layout-Code: kurzer Text „RW1-…“ (Base64, URL-sicher) aus gepackten Einträgen [Gebäudeart+Drehung, Δx, Δy] (Felder des
## größten Rasters, Abstand zum vorigen Eintrag gleicher Art – Mauerreihen werden so sehr kurz), gepackt und mit Prüfsumme. Einfügen prüft: lesbar, Prüfsumme, bekannte Gebäude, alles im Baufeld, keine
## Überschneidung – und ordnet die Einträge den EIGENEN Gebäuden gleicher Art zu (nach Nummer). Eigene Gebäude ohne
## Eintrag behalten ihren Platz, wenn er frei bleibt; sonst passt der Code nicht. Ergebnis landet in einem Speicherplatz
## (P.d.layouts, Format wie P.save_layout: [id, x, y, rot]).
##
## Layout gegen Flut testen: der Aufbau eines Speicherplatzes wird kurz übernommen (der eigene gesichert in
## P.d.layout_test.backup), dann läuft eine Übungsflut in der Stärke der echten Flut dieser Woche – ohne Verlust,
## ohne Belohnung, ohne den Übungsalarm des Tages zu verbrauchen. Danach steht der eigene Aufbau wieder da.

const D = preload("res://src/data.gd")

const PREFIX := "RW1-"
## Feste Reihenfolge der Gebäudearten im Code (neue Arten nur hinten anhängen, dann bleiben alte Codes gültig).
const KEYS := ["bunker", "mg", "kanone", "wachturm", "flammenturm", "moerser", "tesla", "rakete", "schild", "eis", "luftabwehr",
	"wall", "tor", "stachel", "kleb", "mine", "saege", "steinbruch", "presse", "raffinerie", "generator", "lager", "quartier",
	"kistenlager", "werkstatt", "garage", "funkturm", "clanhalle", "labor", "training", "laterne", "flagge", "blumen", "statue",
	"teer", "feder", "koeder", "zaun", "eisfalle", "bank", "gartenzaun", "platte", "holzstapel", "heu", "waesche", "beet", "kuebel",
	"vogelhaus", "picknick", "windrad", "brunnen", "trophy_bert", "trophy_moos", "trophy_rost", "trophy_glibber", "trophy_schlund",
	"trophy_frost", "trophy_koenig", "trophy_brodel", "tauschladen", "trophy_bolzen"]


# ================================================================= Code erzeugen
## Code aus einem Speicherplatz (slot >= 0) oder dem aktuellen Aufbau (slot = -1).
static func encode(slot := -1) -> String:
	var pos := {}
	if slot >= 0:
		var l = P.d.layouts[slot]
		if l == null:
			return ""
		for e in l:
			pos[int(e[0])] = e
	var bytes := PackedByteArray()
	bytes.append(1)                                    # Fassung
	bytes.append(P.grid_size())
	var list: Array = []
	for b in P.d.buildings:
		var ki: int = KEYS.find(String(b.key))
		if ki < 0:
			continue                                   # Hindernisse und Unbekanntes gehören nicht zum Layout
		var x := int(b.x)
		var y := int(b.y)
		var r := int(b.rot)
		if pos.has(int(b.id)):
			x = int(pos[int(b.id)][1])
			y = int(pos[int(b.id)][2])
			r = int(pos[int(b.id)][3])
		list.append([ki, x, y, r, int(b.id)])
	# je Art nach Nummer: beim Einfügen in dieselbe Basis bekommt jedes Gebäude genau seinen Platz zurück
	list.sort_custom(func(a, c): return a[0] < c[0] or (a[0] == c[0] and a[4] < c[4]))
	var pk := -1
	var px := 0
	var py := 0
	for e in list:
		if int(e[0]) != pk:
			pk = int(e[0])
			px = 0
			py = 0
		bytes.append(int(e[0]) | ((int(e[3]) & 3) << 6))
		bytes.append((int(e[1]) - px + 128) & 255)
		bytes.append((int(e[2]) - py + 128) & 255)
		px = int(e[1])
		py = int(e[2])
	var packed := bytes.compress(FileAccess.COMPRESSION_DEFLATE)
	var body := PackedByteArray()
	body.append(bytes.size() & 255)
	body.append((bytes.size() >> 8) & 255)
	body.append_array(packed)
	var sum := _sum(bytes)
	body.append(sum & 255)
	body.append((sum >> 8) & 255)
	return PREFIX + Marshalls.raw_to_base64(body).replace("+", "-").replace("/", "_").replace("=", "")


static func _sum(b: PackedByteArray) -> int:
	var a := 1
	var c := 0
	for v in b:
		a = (a + v) % 251
		c = (c + a) % 251
	return a + c * 256


# ================================================================= Code lesen und prüfen
## Liest einen Code. Rückgabe {"ok": bool, "why": Text, "entries": [[key, x, y, rot]], "grid": n}
static func decode(code: String) -> Dictionary:
	var t := code.strip_edges().replace(" ", "").replace("\n", "")
	if not t.begins_with(PREFIX):
		return {"ok": false, "why": "Das ist kein Layout-Code (er beginnt mit „RW1-“)."}
	t = t.substr(PREFIX.length()).replace("-", "+").replace("_", "/")
	while t.length() % 4 != 0:
		t += "="
	var body := Marshalls.base64_to_raw(t)
	if body.size() < 6:
		return {"ok": false, "why": "Der Code ist unvollständig."}
	var n := int(body[0]) | (int(body[1]) << 8)
	if n < 2 or n > 4000:
		return {"ok": false, "why": "Der Code ist beschädigt."}
	var bytes := body.slice(2, body.size() - 2).decompress(n, FileAccess.COMPRESSION_DEFLATE)
	if bytes.size() != n:
		return {"ok": false, "why": "Der Code ist beschädigt."}
	var sum := int(body[body.size() - 2]) | (int(body[body.size() - 1]) << 8)
	if sum != _sum(bytes):
		return {"ok": false, "why": "Prüfsumme stimmt nicht – ist der Code vollständig kopiert?"}
	if int(bytes[0]) != 1:
		return {"ok": false, "why": "Dieser Code stammt aus einer neueren Fassung."}
	var out: Array = []
	var i := 2
	var pk := -1
	var px := 0
	var py := 0
	while i + 2 < bytes.size():
		var ki := int(bytes[i]) & 63
		if ki >= KEYS.size():
			return {"ok": false, "why": "Der Code enthält unbekannte Gebäude."}
		if ki != pk:
			pk = ki
			px = 0
			py = 0
		px += int(bytes[i + 1]) - 128
		py += int(bytes[i + 2]) - 128
		out.append([String(KEYS[ki]), px, py, (int(bytes[i]) >> 6) & 3])
		i += 3
	return {"ok": true, "why": "", "entries": out, "grid": int(bytes[1])}


## Prüft einen Code gegen die eigene Basis und rechnet die Plätze aus.
## Rückgabe {"ok", "why", "layout": [[id, x, y, rot]], "placed", "missing": {key: n}, "kept"}
static func check(code: String) -> Dictionary:
	var dc := decode(code)
	if not bool(dc.ok):
		return dc
	var entries: Array = dc.entries
	# Einträge je Art, eigene Gebäude je Art
	var want := {}
	for e in entries:
		if not want.has(e[0]):
			want[e[0]] = []
		want[e[0]].append(e)
	var mine := {}
	for b in P.d.buildings:
		var k := String(b.key)
		if KEYS.find(k) < 0:
			continue
		if not mine.has(k):
			mine[k] = []
		mine[k].append(b)
	for k in mine:
		mine[k].sort_custom(func(a, c): return int(a.id) < int(c.id))
	var occ := {}
	var layout: Array = []
	var missing := {}
	var placed := 0
	var leftover: Array = []
	for k in want:
		var have: Array = mine.get(k, [])
		var wl: Array = want[k]
		for i in wl.size():
			if i >= have.size():
				missing[k] = int(missing.get(k, 0)) + 1
				continue
			var e: Array = wl[i]
			var s := P.size_of(k, int(e[3]))
			var x := int(e[1])
			var y := int(e[2])
			if not P.in_grid(x, y, s.x, s.y):
				return {"ok": false, "why": "Der Aufbau ist größer als dein Baufeld (%s liegt außerhalb)." % String(D.BUILDINGS[k].name)}
			if not _mark(occ, x, y, s):
				return {"ok": false, "why": "Im Code überschneiden sich Gebäude."}
			layout.append([int(have[i].id), x, y, int(e[3])])
			placed += 1
		for i in range(wl.size(), have.size()):
			leftover.append(have[i])
	for k in mine:
		if not want.has(k):
			leftover.append_array(mine[k])
	# eigene Gebäude ohne Eintrag bleiben stehen, wenn ihr Platz frei ist
	var kept := 0
	for b in leftover:
		var s2 := P.size_of(String(b.key), int(b.rot))
		if not _mark(occ, int(b.x), int(b.y), s2):
			return {"ok": false, "why": "%s steht im Weg und hat im Code keinen Platz." % String(D.BUILDINGS[String(b.key)].name)}
		layout.append([int(b.id), int(b.x), int(b.y), int(b.rot)])
		kept += 1
	# Hindernisse auf belegten Feldern verhindern den Aufbau
	for b in P.d.buildings:
		if String(D.BUILDINGS.get(String(b.key), {}).get("cat", "")) == "obstacle":
			if occ.has(int(b.x) + int(b.y) * 64):
				return {"ok": false, "why": "Ein Hindernis liegt im Weg – erst wegräumen."}
	var txt := "Passt: %d Gebäude bekommen ihren Platz." % placed
	if kept > 0:
		txt += " %d behalten ihren Platz." % kept
	if not missing.is_empty():
		var ml: Array = []
		for k in missing:
			ml.append("%d× %s" % [int(missing[k]), String(D.BUILDINGS[k].name)])
		txt += " Dir fehlen: %s." % ", ".join(ml)
	return {"ok": true, "why": txt, "layout": layout, "placed": placed, "missing": missing, "kept": kept, "grid": int(dc.grid)}


static func _mark(occ: Dictionary, x: int, y: int, s: Vector2i) -> bool:
	for yy in s.y:
		for xx in s.x:
			var k := (x + xx) + (y + yy) * 64
			if occ.has(k):
				return false
	for yy in s.y:
		for xx in s.x:
			occ[(x + xx) + (y + yy) * 64] = true
	return true


## Code prüfen und in einen Speicherplatz übernehmen. Rückgabe wie check().
static func paste(code: String, slot: int) -> Dictionary:
	var c := check(code)
	if bool(c.ok):
		P.d.layouts[slot] = c.layout
		P.mark()
	return c


# ================================================================= Layout gegen Flut testen
## Übernimmt den Aufbau aus dem Speicherplatz und startet die Testflut. Rückgabe: "" oder der Grund.
static func test_start(world, slot: int) -> String:
	if world == null or world.mode != "peace" or world.bunker_node == null:
		return "Gerade nicht möglich"
	if P.d.layouts[slot] == null:
		return "Aufbau %d ist leer" % (slot + 1)
	var backup: Array = []
	for b in P.d.buildings:
		backup.append([int(b.id), int(b.x), int(b.y), int(b.rot)])
	P.d.layout_test = {"backup": backup, "slot": slot}
	if not P.load_layout(slot):
		P.d.layout_test = {}
		return "Aufbau %d passt nicht mehr (neue Gebäude im Weg)" % (slot + 1)
	world.layout_test = true
	world.start_flood(true)
	if world.mode == "peace":
		world.layout_test = false
		test_restore()
		return "Gerade nicht möglich"
	P.toast.emit("Layout-Test: Aufbau %d gegen die Flut von Woche %d – ohne Verlust" % [slot + 1, int(P.d.week.number)])
	return ""


## Aus base_world.flood_preview: Stärke der echten Flut dieser Woche (mit Boss), höchstens 6 Wellen.
static func test_flood(fd: Dictionary) -> void:
	var real := D.flood_def(int(P.d.week.number), P.bunker_level())
	fd.total = int(real.total)
	fd.hp = float(real.hp)
	fd.dmg = float(real.dmg)
	fd.waves = mini(int(real.waves), 6)
	fd.boss = bool(real.boss)
	fd["test"] = true


static func test_result(win: bool, kills: int) -> Dictionary:
	return {"win": win, "coins": 0, "xp": 0, "practice": true, "test": true, "kills": kills,
		"title": "Layout-Test bestanden!" if win else "Layout-Test: der Bunker ist gefallen"}


## Eigenen Aufbau wiederherstellen (nach dem Test oder nach einem Absturz).
static func test_restore() -> void:
	var lt: Dictionary = P.d.get("layout_test", {})
	if lt.has("backup"):
		preload("res://src/basis_state.gd").restore_backup(P.d, lt.backup)
	P.d.layout_test = {}
	P.mark()
	P.buildings_changed.emit()
