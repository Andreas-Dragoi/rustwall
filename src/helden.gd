extends RefCounted
## Paket H (V6): Spielregeln für Ausrüstungs-Sets, Waffenmodule (Sockel), Gift, Wurfwaffen und das Aussehen der Helden
## (Ausrüstung und Module am Modell). Zahlen und Texte in src/data_helden.gd.
## Spielstand: Ausrüstung bleibt in P.d.items (slot helmet/vest/charm, key = Set-Schlüssel), Waffen tragen
## it.sockets = ["scope", "", ...] (Länge nach Seltenheit), freie Module liegen in P.d.modules = {schlüssel: Anzahl}.

const D = preload("res://src/data.gd")
const DH = preload("res://src/data_helden.gd")

const MOD_SLOT_POS := {"muzzle": 0, "top": 1, "under": 2, "side": 3, "core": 4, "head": 5}


# ================================================================= Spielstand
## Neue Felder und Umstellungen für alte Stände (aus P._ensure_fields).
static func ensure(d: Dictionary) -> void:
	if not d.has("modules") or not (d.modules is Dictionary):
		d["modules"] = {}
	for k in d.modules.keys():
		d.modules[k] = int(d.modules[k])
	# neue Heldin (Nele) und künftige Helden: Eintrag wie in P.new_game
	if d.has("heroes") and d.heroes is Dictionary:
		for hk in D.HERO_ORDER:
			if not d.heroes.has(hk):
				d.heroes[hk] = {"unlocked": false, "level": 1, "xp": 0, "talents": [0, 0, 0], "weapon": 0, "gear": {"helmet": 0, "vest": 0, "charm": 0},
					"chapter": 0, "auto_until": 0.0, "auto_area": -1, "auto_hours": 0}
			if d.has("badges") and not d.badges.has(hk):
				d.badges[hk] = 0
	if not d.has("items"):
		return
	for it in d.items:
		var slot := String(it.get("slot", ""))
		if slot == "weapon":
			if it.has("sockets"):
				var arr: Array = []
				for m in it.sockets:
					arr.append(str(m))
				it.sockets = arr
		elif DH.SET_LEGACY and String(it.get("key", "")) == "" and D.GEAR.has(slot):
			it.key = DH.SET_ORDER[int(it.get("id", 0)) % DH.SET_ORDER.size()]


# ================================================================= Ausrüstungs-Sets
static func set_of(it: Dictionary) -> String:
	if it.is_empty() or not D.GEAR.has(String(it.get("slot", ""))):
		return ""
	var k := String(it.get("key", ""))
	return k if DH.SETS.has(k) else ""


static func set_name(k: String) -> String:
	return String(DH.SETS[k].name) if DH.SETS.has(k) else ""


## Name eines Ausrüstungsteils eines Sets ("Feuerwehrhelm"); "" für Teile ohne Set.
static func piece_name(it: Dictionary) -> String:
	var k := set_of(it)
	if k == "":
		return ""
	return String(DH.SETS[k].pieces[String(it.slot)])


## Angelegte Teile je Set für einen Helden: {set: Anzahl}. Der Glücksbringer zählt erst ab seiner Heldenstufe.
static func set_counts(hero_key: String) -> Dictionary:
	var out := {}
	if not P.d.heroes.has(hero_key):
		return out
	var h: Dictionary = P.d.heroes[hero_key]
	for slot in h.gear:
		if slot == "charm" and int(h.level) < D.HERO_CHARM_LEVEL:
			continue
		var k := set_of(P.item(int(h.gear[slot])))
		if k != "":
			out[k] = int(out.get(k, 0)) + 1
	return out


## Rechnet die Set-Boni in die Werte m (aus P.hero_stats) ein.
static func apply_sets(hero_key: String, m: Dictionary) -> void:
	var cnt := set_counts(hero_key)
	for k in cnt:
		var n := int(cnt[k])
		var def: Dictionary = DH.SETS[k]
		if n >= 2:
			_add_stats(m, def.b2)
		if n >= 3:
			_add_stats(m, def.b3)


static func _add_stats(m: Dictionary, add: Dictionary) -> void:
	for s in add:
		m[s] = float(m.get(s, 0.0)) + float(add[s])


## Text der aktiven Boni, z. B. ["Löschzug (2/3): +25 % Brenndauer"].
static func set_lines(hero_key: String) -> Array:
	var out: Array = []
	var cnt := set_counts(hero_key)
	for k in DH.SET_ORDER:
		if not cnt.has(k):
			continue
		var n := int(cnt[k])
		var def: Dictionary = DH.SETS[k]
		var t := "%s (%d/3)" % [String(def.name), n]
		if n >= 2:
			t += ": " + String(def.t2)
		if n >= 3:
			t += " · " + String(def.t3)
		out.append(t)
	return out


## Zufälliges Set für ein neues Ausrüstungsteil (Kisten).
static func roll_set(rng: RandomNumberGenerator) -> String:
	return String(DH.SET_ORDER[rng.randi() % DH.SET_ORDER.size()])


# ================================================================= Waffenmodule
## Sockel einer Waffe (Länge nach Seltenheit); legt it.sockets bei Bedarf an.
static func sockets(it: Dictionary) -> Array:
	if it.is_empty() or String(it.get("slot", "")) != "weapon":
		return []
	var n: int = DH.SOCKETS[clampi(int(it.get("rarity", 0)), 0, 3)]
	if not it.has("sockets") or not (it.sockets is Array):
		it["sockets"] = []
	var arr: Array = it.sockets
	while arr.size() < n:
		arr.append("")
	while arr.size() > n:                            # nur nach einer Datenänderung: überzählige Module zurück ins Lager
		var m := String(arr.pop_back())
		if m != "":
			add_module(m, 1)
	return arr


static func modules_of(it: Dictionary) -> Array:
	var out: Array = []
	for m in sockets(it):
		if String(m) != "" and DH.MODULES.has(String(m)):
			out.append(String(m))
	return out


static func module_count(key: String) -> int:
	return int(P.d.get("modules", {}).get(key, 0))


static func add_module(key: String, n := 1) -> void:
	if not P.d.has("modules"):
		P.d["modules"] = {}
	P.d.modules[key] = maxi(0, module_count(key) + n)
	P.mark()


## Passt ein Modul in eine Waffe? Rückgabe: "" oder der Grund.
static func fits(mod_key: String, weapon_key: String) -> String:
	if not DH.MODULES.has(mod_key) or not D.WEAPONS.has(weapon_key):
		return "Unbekannt"
	var md: Dictionary = DH.MODULES[mod_key]
	var w: Dictionary = D.WEAPONS[weapon_key]
	var mode := String(w.mode)
	if mode == "turret":
		return "Geschütze haben keine Sockel für Module"
	if md.get("mag", false) and int(w.get("mag", 0)) <= 0:
		return "Nur für Waffen mit Magazin"
	var modes: Array = md.get("modes", [])
	if not modes.is_empty() and not modes.has(mode):
		return "Passt nicht zu dieser Waffenart"
	return ""


## Setzt ein Modul aus dem Lager in Sockel idx der Waffe item_id. Rückgabe: Erfolg.
static func insert(item_id: int, idx: int, mod_key: String) -> bool:
	var it: Dictionary = P.item(item_id)
	var arr := sockets(it)
	if idx < 0 or idx >= arr.size():
		return false
	var why := fits(mod_key, String(it.key))
	if why != "":
		P.toast.emit(why)
		return false
	if module_count(mod_key) <= 0:
		P.toast.emit("Kein %s im Lager" % String(DH.MODULES[mod_key].name))
		return false
	for i in arr.size():
		var other := String(arr[i])
		if i == idx or other == "":
			continue
		if other == mod_key:
			P.toast.emit("Dieses Modul steckt schon in der Waffe")
			return false
		if DH.MODULES[mod_key].has("core") and DH.MODULES.has(other) and DH.MODULES[other].has("core"):
			P.toast.emit("Nur ein Element-Kern je Waffe")
			return false
	if String(arr[idx]) != "":
		add_module(String(arr[idx]), 1)
	add_module(mod_key, -1)
	arr[idx] = mod_key
	P.count_up("modules_fitted", 1)
	Sfx.play("module_fit", -4.0)
	P.mark()
	return true


## Baut das Modul aus Sockel idx aus (zurück ins Lager).
static func remove(item_id: int, idx: int) -> bool:
	var it: Dictionary = P.item(item_id)
	var arr := sockets(it)
	if idx < 0 or idx >= arr.size() or String(arr[idx]) == "":
		return false
	add_module(String(arr[idx]), 1)
	arr[idx] = ""
	Sfx.play("module_remove", -6.0)
	P.mark()
	return true


## Alle Module einer Waffe zurück ins Lager (vor dem Zerlegen oder Verschmelzen).
static func release_modules(it: Dictionary) -> int:
	var n := 0
	if it.is_empty() or not it.has("sockets"):
		return 0
	for i in (it.sockets as Array).size():
		var m := String(it.sockets[i])
		if m != "":
			add_module(m, 1)
			it.sockets[i] = ""
			n += 1
	return n


static func craft_module(key: String) -> bool:
	if not DH.MODULES.has(key):
		return false
	var c: Dictionary = DH.MODULES[key].cost
	if not P.pay(c):
		P.toast.emit(P.missing_text(c))
		return false
	add_module(key, 1)
	P.count_up("modules_crafted", 1)
	Sfx.play("module_craft", -3.0)
	P.toast.emit("Hergestellt: %s" % String(DH.MODULES[key].name))
	return true


## Modul als Fund (Kisten). Rückgabe: Stück wie bei Kisten.
static func give_module(key: String) -> Dictionary:
	add_module(key, 1)
	Sfx.play("module_found", -4.0)
	return {"rarity": 1, "kind": "module", "key": key, "text": String(DH.MODULES[key].name), "sub": "Waffenmodul"}


## Fund in einer Beutekiste (P.open_chest): mit der Chance aus DH.MODULE_DROP ein zufälliges Modul, sonst {}.
static func chest_module(type: String, rng: RandomNumberGenerator) -> Dictionary:
	var ch := float(DH.MODULE_DROP.get("chest_" + type, DH.MODULE_DROP.chest))
	if rng.randf() >= ch:
		return {}
	return give_module(String(DH.MODULE_ORDER[rng.randi() % DH.MODULE_ORDER.size()]))


## Summe der Modul-Werte einer Waffe (Schlüssel wie in DH.MODULES[...].fx).
static func module_fx(it: Dictionary) -> Dictionary:
	var out := {}
	for m in modules_of(it):
		var fx: Dictionary = DH.MODULES[m].fx
		for k in fx:
			if k == "stun":
				out[k] = maxf(float(out.get(k, 0.0)), float(fx[k]))
			else:
				out[k] = float(out.get(k, 0.0)) + float(fx[k])
	return out


## Waffen-Eintrag mit den Wirkungen der Module (Kopie von D.WEAPONS[key]): Element-Kerne geben Brennen, Gift, Frost oder
## Betäuben beim Treffer; Schalldämpfer macht genauer, Wuchtgewicht stärkeren Rückstoß. Werte wie Schaden, Feuerrate,
## Reichweite, Magazin und Nachladen rechnet hero.gd aus module_fx().
static func weapon_with_modules(key: String, it: Dictionary) -> Dictionary:
	var w: Dictionary = (D.WEAPONS[key] as Dictionary).duplicate()
	var fx := module_fx(it)
	if fx.is_empty():
		return w
	if fx.has("spread") and w.has("spread"):
		w["spread"] = float(w.spread) * maxf(0.0, 1.0 + float(fx.spread))
	if fx.has("knock"):
		w["knock"] = float(w.get("knock", 0.4)) * (1.0 + float(fx.knock))
	for k in ["burn", "poison", "chill"]:
		if fx.has(k):
			w[k] = maxf(float(w.get(k, 0.0)), float(fx[k]))
	if fx.has("freeze"):
		w["freeze"] = float(w.get("freeze", 0.0)) + float(fx.freeze)
	if fx.has("stun_ch"):
		w["stun_ch"] = float(w.get("stun_ch", 0.0)) + float(fx.stun_ch)
		w["stun"] = maxf(float(w.get("stun", 0.0)), float(fx.get("stun", 0.5)))
	return w


## Kurztext der eingesetzten Module ("Zielfernrohr, Element-Kern Feuer").
static func modules_text(it: Dictionary) -> String:
	var names: Array = []
	for m in modules_of(it):
		names.append(String(DH.MODULES[m].name))
	return ", ".join(names)


# ================================================================= Gift
## Giftschaden je Sekunde für eine Waffe (Stück it) bei Heldenstärke hero_scale (wie beim Brennen: Stufe und Talente).
static func poison_dps(it: Dictionary, hero_scale: float) -> float:
	var wm := 1.0
	if not it.is_empty():
		wm = P.weapon_mult(it)
	return DH.POISON_DPS * wm * maxf(hero_scale, 0.1)


# ================================================================= Aussehen am Modell
## Modellnamen der angelegten Ausrüstung eines Helden: {helmet: "gear_feuerwehr_helmet", ...} (nur Teile mit Set).
static func gear_models(hero_key: String) -> Dictionary:
	var out := {}
	if not P.d.heroes.has(hero_key):
		return out
	var h: Dictionary = P.d.heroes[hero_key]
	for slot in h.gear:
		if slot == "charm" and int(h.level) < D.HERO_CHARM_LEVEL:
			continue
		var k := set_of(P.item(int(h.gear[slot])))
		if k != "":
			out[slot] = "gear_%s_%s" % [k, slot]
	return out


## Kennung für die Vorschau (neu bauen, wenn sich Ausrüstung oder Module ändern).
static func look_sig(hero_key: String) -> String:
	var g := gear_models(hero_key)
	var parts: Array = []
	for s in ["helmet", "vest", "charm"]:
		parts.append(String(g.get(s, "")))
	if P.d.heroes.has(hero_key):
		parts.append(",".join(modules_of(P.item(int(P.d.heroes[hero_key].weapon)))))
	return "|".join(parts)


## Zieht einer Figur (humanoid.gd) die Ausrüstung des Helden an und steckt die Module der Waffe it an das Waffenmodell.
static func dress(body: Node3D, hero_key: String, it := {}) -> void:
	if body == null or not body.has_method("set_gear"):
		return
	var g := gear_models(hero_key)
	var vest_k := 1.25 if hero_key == "bruno" else 1.0                # Bruno ist breiter gebaut
	for slot in ["helmet", "vest", "charm"]:
		body.set_gear(slot, String(g.get(slot, "")), vest_k if slot == "vest" else 1.0)
	if not it.is_empty():
		show_modules(body, it)


## Module der Waffe it am Waffenmodell der Figur.
static func show_modules(body: Node3D, it: Dictionary) -> void:
	if body == null or not body.has_method("set_modules"):
		return
	var list: Array = []
	for m in modules_of(it):
		var vis := String(DH.MODULES[m].get("vis", ""))
		if vis != "":
			list.append([m, vis])
	body.set_modules(list)


## Haltung "toss": Waffe in der Hand größer.
static func hand_scale(weapon_key: String) -> float:
	if not D.WEAPONS.has(weapon_key):
		return 1.0
	var w: Dictionary = D.WEAPONS[weapon_key]
	return DH.TOSS_SCALE if String(w.get("pose", "")) == "toss" else 1.0
