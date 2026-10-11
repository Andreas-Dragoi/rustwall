extends RefCounted
## V4 Waffen-Arsenal: Spielregeln außerhalb des Kampfes (Besitz, Baupläne, Herstellen, Funde).
## Der Spielstand liegt in P.d: Waffen sind wie bisher Gegenstände (P.d.items), Baupläne in P.d.blueprints {schlüssel: true}.
## Freischalten: jede Waffe hat eine Heldenstufe (D.weapon_level) UND einen Weg (D.weapon_get):
##   start = kommt mit der Stufe von selbst, craft = Bauplan finden + in der Werkstatt herstellen,
##   find = Beute (Expedition: Fundkisten, Nester, Kopfgeld-Boss, Rettung, Wettlauf; Beutekisten), both = beides.

const D = preload("res://src/data.gd")


static func owned(key: String) -> bool:
	for it in P.d.items:
		if String(it.slot) == "weapon" and String(it.key) == key:
			return true
	return false


static func has_blueprint(key: String) -> bool:
	return P.d.has("blueprints") and (P.d.blueprints as Dictionary).has(key)


static func hero_level(key: String) -> int:
	return int(P.d.heroes[String(D.WEAPONS[key].hero)].level)


## Zustand einer Waffe für die Werkstatt: owned | craft (jetzt herstellbar) | craft_level (Bauplan da, Stufe fehlt) |
## blueprint (Bauplan fehlt) | find (nur als Fund) | level (Startwaffe, Stufe fehlt)
static func status(key: String) -> String:
	if owned(key):
		return "owned"
	var g := D.weapon_get(key)
	var lv_ok := hero_level(key) >= D.weapon_level(key)
	if g == "start":
		return "level"
	if (g == "craft" or g == "both") and has_blueprint(key):
		return "craft" if lv_ok else "craft_level"
	if g == "craft":
		return "blueprint"
	return "find"


static func can_craft(key: String) -> bool:
	return status(key) == "craft" and P.can_pay(D.craft_cost(key))


static func area_names(key: String) -> String:
	var out: Array = []
	for a in D.weapon_areas(key):
		out.append(String(D.AREAS[int(a)].name))
	return " / ".join(out)


## Hinweis, wo und ab wann es die Waffe gibt (für gesperrte Waffen).
static func hint(key: String) -> String:
	var lv := D.weapon_level(key)
	var low := hero_level(key) < lv
	var where := ""
	match D.weapon_get(key):
		"start":
			return "kommt mit Heldenstufe %d" % lv
		"craft":
			where = "Bauplan aus Expeditionen (%s), Kisten und Erfolgen" % area_names(key)
		"find":
			where = "Fund in Expeditionen (%s) und Beutekisten" % area_names(key)
		"both":
			where = "Fund oder Bauplan in Expeditionen (%s) und Kisten" % area_names(key)
	match status(key):
		"craft":
			return "Bauplan vorhanden – jetzt herstellen"
		"craft_level":
			return "Bauplan vorhanden – herstellbar ab Heldenstufe %d" % lv
	if low:
		return "ab Heldenstufe %d · %s" % [lv, where]
	return where


## Stellt eine Waffe her: Bauplan + Heldenstufe + Kosten. Rückgabe: der neue Gegenstand (sonst leer).
static func craft(key: String) -> Dictionary:
	var st := status(key)
	if st == "craft_level":
		P.toast.emit("%s braucht Heldenstufe %d" % [String(D.WEAPONS[key].hero).capitalize(), D.weapon_level(key)])
		return {}
	if st != "craft":
		P.toast.emit("Dafür fehlt der Bauplan")
		return {}
	var c := D.craft_cost(key)
	if not P.pay(c):
		P.toast.emit(P.missing_text(c))
		return {}
	var it: Dictionary = P.make_item("weapon", key, 0)
	P.count_up("weapons_crafted", 1)
	Sfx.play("craft_weapon" if Sfx.has("craft_weapon") else "upgrade_done", -3.0)
	P.toast.emit("Hergestellt: %s" % String(D.WEAPONS[key].name))
	P.mark()
	return it


static func give_blueprint(key: String, why := "") -> Dictionary:
	if not P.d.has("blueprints"):
		P.d["blueprints"] = {}
	P.d.blueprints[key] = true
	Sfx.play("blueprint_found" if Sfx.has("blueprint_found") else "chest_found", -4.0)
	var txt := "Bauplan: %s" % String(D.WEAPONS[key].name)
	if why != "":
		P.toast.emit("%s (%s)" % [txt, why])
	P.mark()
	return {"rarity": 1, "kind": "blueprint", "key": key, "text": txt, "sub": "für %s" % String(D.WEAPONS[key].hero).capitalize()}


static func give_weapon(key: String, rarity: int, why := "") -> Dictionary:
	var it: Dictionary = P.make_item("weapon", key, clampi(rarity, 0, 3))
	Sfx.play("weapon_found" if Sfx.has("weapon_found") else "chest_found", -4.0)
	if why != "":
		P.toast.emit("Waffe gefunden: %s (%s)" % [String(D.WEAPONS[key].name), why])
	return {"rarity": int(it.rarity), "kind": "item", "item": int(it.id), "text": P.item_name(it), "sub": String(D.RARITY[int(it.rarity)].name)}


## Würfelt einen Fund. source = Schlüssel in D.ARSENAL_DROP; area = Gebiet (-1 = egal); hero_key bevorzugt diesen Helden;
## force = ohne Zufallsprobe; only_bp = nur Baupläne. Rückgabe: Stück wie bei Kisten oder {}.
static func roll(source: String, area := -1, hero_key := "", rarity := 0, force := false, only_bp := false, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	if not force and rng.randf() >= float(D.ARSENAL_DROP.get(source, 0.0)):
		return {}
	if hero_key == "":
		hero_key = String(P.d.hero_sel)
	var cands: Array = []          # [gewicht, schlüssel, bauplan?]
	var total := 0.0
	for hk in D.HERO_ORDER:
		if not P.hero_unlocked(hk):
			continue
		var hl := int(P.d.heroes[hk].level)
		for key in D.hero_weapons(hk):
			var g := D.weapon_get(key)
			if g == "start":
				continue
			var lv := D.weapon_level(key)
			var wa: Array = D.weapon_areas(key)
			var aw := 1.0
			if area >= 0:
				if wa.has(area):
					aw = 4.0
				elif int(wa.min()) < area:
					aw = 1.0
				elif int(wa.min()) == area + 1:
					aw = 0.5               # ein Gebiet voraus: selten
				else:
					aw = 0.0
			if aw <= 0.0:
				continue
			if hk == hero_key:
				aw *= 3.0
			var bp_ok: bool = (g == "craft" or g == "both") and not has_blueprint(key) and not owned(key) and lv <= hl + 10
			var w_ok: bool = (g == "find" or g == "both") and lv <= hl and not only_bp
			if bp_ok:
				var wb := aw * (D.BLUEPRINT_SHARE if g == "both" and w_ok else 1.0)
				cands.append([wb, key, true])
				total += wb
			if w_ok:
				var ww := aw * (0.35 if owned(key) else 1.0) * (1.0 - D.BLUEPRINT_SHARE if bp_ok else 1.0)
				cands.append([ww, key, false])
				total += ww
	if total <= 0.0:
		if force and area >= 0:
			return roll(source, -1, hero_key, rarity, true, only_bp, rng)     # sicherer Fund: dann aus allen Gebieten
		return {}
	var x := rng.randf() * total
	for c in cands:
		x -= float(c[0])
		if x <= 0.0:
			return give_blueprint(String(c[1])) if c[2] else give_weapon(String(c[1]), rarity)
	var last: Array = cands[cands.size() - 1]
	return give_blueprint(String(last[1])) if last[2] else give_weapon(String(last[1]), rarity)


## Funde am Ende einer erfolgreichen Expedition (P.expedition_end). Schreibt out["arsenal"] = [Stücke].
static func expedition_loot(area: int, diff: int, hero_key: String, info: Dictionary, first_boss: bool, out: Dictionary) -> void:
	var got: Array = []
	var r := clampi(diff, 0, 2)
	for i in int(info.get("chests", 0)):
		var p := roll("exp_chest", area, hero_key, r)
		if not p.is_empty():
			got.append(p)
	if bool(info.get("bounty", false)):
		var p2 := roll("boss_first" if first_boss else "exp_bounty", area, hero_key, mini(r + 1, 3), first_boss)
		if not p2.is_empty():
			got.append(p2)
	if bool(info.get("rescued", false)):
		var p3 := roll("exp_rescue", area, hero_key, r)
		if not p3.is_empty():
			got.append(p3)
	if float(info.get("race_time", 0.0)) > 0.0:
		var p4 := roll("exp_race", area, hero_key, r)
		if not p4.is_empty():
			got.append(p4)
	out["arsenal"] = got
	for p in got:
		P.toast.emit(("Neu: " if String(p.kind) == "item" else "") + String(p.text))


## Fund in einer Beutekiste (P.open_chest).
static func chest_loot(type: String, rarity: int) -> Dictionary:
	var src := "chest_" + type
	if not D.ARSENAL_DROP.has(src):
		src = "chest"
	return roll(src, -1, "", rarity)


## Admin: alle Waffen und Baupläne.
static func grant_all(rarity := 0) -> int:
	var n := 0
	if not P.d.has("blueprints"):
		P.d["blueprints"] = {}
	for key in D.WEAPONS:
		var g := D.weapon_get(key)
		if g == "craft" or g == "both":
			P.d.blueprints[key] = true
		if not owned(key):
			P.make_item("weapon", key, rarity)
			n += 1
	P.mark()
	return n
