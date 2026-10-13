extends Translation
## Sprachen (Paket S): Deutsch ist die Quellsprache (msgid = deutscher Text), Englisch steht in locale/en.po.
##
## Godot übersetzt feste Texte in Labels/Buttons von selbst (auto_translate). Diese Klasse ist zusätzlich als
## englische Übersetzung angemeldet und übernimmt alles, was nicht wörtlich in en.po steht:
##  - zusammengesetzte Texte nach Vorlagen aus en.po ("Stufe %d" erkennt "Stufe 7" → "Level 7"),
##    eingesetzte Teile werden ebenfalls übersetzt ("%s fertig" + "Sägewerk" → "Sawmill done"),
##  - Texte aus mehreren Teilen (Zeilen, " · ", " – ", ": ", BBCode-Marken, Zahlen davor, Satzzeichen danach),
##  - GROSS geschriebene Texte.
## Mit Deutsch als Sprache wird nichts davon aufgerufen – das Spiel bleibt genau wie vorher.
##
## Benutzung: I18N.setup() (in G._ready), I18N.set_lang("en"), I18N.lang(), I18N.is_en().
## Zum Prüfen: --lang=en wählt Englisch ohne zu speichern; --i18n_log=<datei> schreibt nicht übersetzte Texte.

const PO_PATH := "res://locale/en.po"
const LANG_FILE := "user://rustwall_lang.txt"
const LANGS := ["de", "en"]
const LANG_NAMES := {"de": "Deutsch", "en": "English"}
## Englische Mehrzahl nach "1" in die Einzahl (Vorlagen wie "%d gems" → "1 gem")
const SINGULAR := {"gems": "gem", "coins": "coin", "crates": "crate", "waves": "wave", "items": "item", "enemies": "enemy",
	"days": "day", "hours": "hour", "points": "point", "parts": "part", "badges": "badge", "seconds": "second", "loads": "load",
	"floods": "flood", "expeditions": "expedition", "slimelings": "slimeling", "shards": "shard", "members": "member",
	"pieces": "piece", "rewards": "reward", "eggs": "egg", "blueprints": "blueprint", "weapons": "weapon", "heroes": "hero",
	"buildings": "building", "jobs": "job", "shipments": "shipment", "skills": "skill", "levels": "level", "cities": "city",
	"pages": "page", "drones": "drone", "achievements": "achievement", "vehicles": "vehicle", "walls": "wall", "nests": "nest",
	"traps": "trap", "outposts": "outpost", "practice alarms": "practice alarm", "loot crates": "loot crate", "talent points": "talent point"}
const SEPS := ["\n", " · ", " – ", " — ", " | ", " → ", " / ", ". ", "! ", "? ", "; ", ", ", ": ", " + "]     # " + ": Paket Q (Wellen-Vorschau)

static var inst: Translation = null
static var _lang := "de"
static var _no_save := false

var _exact: Dictionary = {}       # deutscher Text -> englischer Text
var _upper: Dictionary = {}       # GROSS -> GROSS
var _capd: Dictionary = {}        # "Wort Für Wort" (String.capitalize) -> englisch
var _tpl: Array = []              # [RegEx, need(String), out_parts(Array), kinds(Array), Länge fester Text, Anfang]
var _tpl_by: Dictionary = {}      # erste zwei Zeichen des festen Anfangs -> Vorlagen
var _tpl_wild: Array = []         # Vorlagen, die mit einem Platzhalter beginnen
var _cache: Dictionary = {}
var _cmiss: Dictionary = {}       # Text -> Zahl unübersetzter Stücke im Ergebnis
var _ret_miss := 0
var _loaded := false
var misses: Dictionary = {}       # nicht übersetzte (deutsch wirkende) Texte -> Anzahl
var log_misses := false
var _re_tag: RegEx
var _re_lead: RegEx
var _re_trail: RegEx
var _re_paren: RegEx
var _re_tailnum: RegEx
var _re_quote: RegEx
var _re_one: RegEx
var _re_dec: RegEx
var _re_thou: RegEx
var _re_german: RegEx
var _re_letters: RegEx
var _depth := 0


# ------------------------------------------------------------------ öffentlich (statisch)
static func setup() -> void:
	var want := ""
	var forced := G.arg("lang")
	if forced != "":
		want = forced
		_no_save = true
	elif G.selftest or G.autotest != "":
		want = "de"                     # Tests laufen ohne Angabe immer auf Deutsch
		_no_save = true
	else:
		want = _read_saved()
		if want == "":
			# Erster Start: Systemsprache, Rückfall Englisch für alle Nicht-Deutschen
			want = "de" if OS.get_locale_language() == "de" else "en"
	_apply(want)
	if inst != null and G.arg("i18n_log") != "":
		inst.log_misses = true


static func lang() -> String:
	return _lang


static func is_en() -> bool:
	return _lang == "en"


## Sprache wechseln (und merken). Offene Texte übersetzen sich selbst neu; Menüs baut der Aufrufer neu.
static func set_lang(code: String, save := true) -> void:
	if not LANGS.has(code):
		code = "en"
	_apply(code)
	if save and not _no_save:
		var f := FileAccess.open(LANG_FILE, FileAccess.WRITE)
		if f != null:
			f.store_string(code)


## Übersetzt einen Text (auch zusammengesetzt) in die aktuelle Sprache – für Stellen ohne Control (draw_string).
static func t(s: String) -> String:
	if _lang == "de" or s == "":
		return s
	return TranslationServer.translate(s)


## Nicht übersetzte Texte (nur mit Protokoll) als Liste.
static func miss_list() -> Array:
	if inst == null:
		return []
	var out: Array = inst.misses.keys()
	out.sort()
	return out


static func dump_misses(path: String) -> void:
	if inst == null or path == "":
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	for k in miss_list():
		f.store_line(JSON.stringify(k))


## Beim Beenden abmelden (sonst räumt Godot die Übersetzung erst nach GDScript ab und stürzt beim Beenden).
static func shutdown() -> void:
	if inst != null:
		TranslationServer.remove_translation(inst)
		inst = null


static func _read_saved() -> String:
	if not FileAccess.file_exists(LANG_FILE):
		return ""
	var s := FileAccess.get_file_as_string(LANG_FILE).strip_edges()
	return s if LANGS.has(s) else ""


static func _apply(code: String) -> void:
	_lang = code
	if code == "en" and inst == null:
		inst = load("res://src/i18n.gd").new()
		inst.locale = "en"
		inst._load()
		TranslationServer.add_translation(inst)
	TranslationServer.set_locale(code)


# ------------------------------------------------------------------ Laden
func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_re_tag = RegEx.create_from_string("\\[[^\\[\\]]*\\]")
	_re_lead = RegEx.create_from_string("^([\\s+\\-−±×•·✓●›‹#№]*[\\d.,]*\\s*[%×]?\\s*)(\\S.*)$")
	_re_trail = RegEx.create_from_string("^(.*?)([\\s.!?:;…,]+)$")
	_re_paren = RegEx.create_from_string("^(.*?)\\s*\\((.+)\\)$")
	_re_tailnum = RegEx.create_from_string("^(.*\\S)(\\s+[-+−]?[\\d.,/:%×x]+[:!.]?)$")
	_re_quote = RegEx.create_from_string("„([^“„]*)“")
	_re_dec = RegEx.create_from_string("(?<![\\d.,])(\\d+),(\\d{1,2})(?![\\d.,])")      # 5,5 → 5.5
	_re_thou = RegEx.create_from_string("(?<![\\d.,])(\\d{1,3})\\.(\\d{3})(?![\\d.,])")   # 1.500 → 1,500
	_re_one = RegEx.create_from_string("(?<![\\d.,])1 ((?:[a-z]+ )?(?:" + "|".join(PackedStringArray(SINGULAR.keys())) + "))\\b")
	_re_german = RegEx.create_from_string("[äöüÄÖÜß]|[a-zäöü]{3,}")
	_re_letters = RegEx.create_from_string("[A-Za-zÄÖÜäöüß]")
	var pairs: Dictionary = _read_po()
	var tmp: Array = []
	for k in pairs:
		var v: String = pairs[k]
		if v == "":
			continue
		_exact[k] = v
		var up: String = k.to_upper()
		if up != k and not _exact.has(up):
			_upper[up] = v.to_upper()
		if k.length() < 48 and k.contains(" "):
			var cp: String = k.capitalize()
			if cp != k and not _exact.has(cp):
				_capd[cp] = v.capitalize()
		if k.contains("%"):
			var tp := _compile(k, v)
			if not tp.is_empty():
				tmp.append(tp)
	# spezifischere Vorlagen (mehr fester Text) zuerst
	tmp.sort_custom(func(a, b): return int(a[4]) > int(b[4]))
	_tpl = tmp
	for tp in _tpl:
		var head: String = tp[5]
		if head.length() >= 2:
			var key := head.left(2)
			if not _tpl_by.has(key):
				_tpl_by[key] = []
			_tpl_by[key].append(tp)
		else:
			_tpl_wild.append(tp)


func _read_po() -> Dictionary:
	var res := {}
	var txt := ""
	if FileAccess.file_exists(PO_PATH):
		txt = FileAccess.get_file_as_string(PO_PATH)
	if txt == "":
		# Rückfall (Export ohne .po-Rohdatei): Meldungsliste der importierten Übersetzung
		var tr_res = load(PO_PATH)
		if tr_res is Translation:
			for m in tr_res.get_message_list():
				res[String(m)] = String(tr_res.get_message(m))
		return res
	var cur := ""
	var mid := ""
	var mstr := ""
	for raw in txt.split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("msgid "):
			if mid != "":
				res[mid] = mstr
			mid = _unq(line.substr(6))
			mstr = ""
			cur = "id"
		elif line.begins_with("msgstr "):
			mstr = _unq(line.substr(7))
			cur = "str"
		elif line.begins_with("\""):
			if cur == "id":
				mid += _unq(line)
			elif cur == "str":
				mstr += _unq(line)
		elif line == "" or line.begins_with("#"):
			if cur == "str" and mid != "":
				res[mid] = mstr
				mid = ""
				mstr = ""
			cur = ""
	if mid != "":
		res[mid] = mstr
	return res


static func _unq(s: String) -> String:
	s = s.strip_edges()
	if s.length() >= 2 and s.begins_with("\"") and s.ends_with("\""):
		s = s.substr(1, s.length() - 2)
	return s.c_unescape()


## Vorlage "Stufe %d von %s" → [RegEx, längstes festes Stück, Ausgabe-Teile, Arten, Länge des festen Texts]
func _compile(src: String, dst: String) -> Array:
	var re_ph := RegEx.create_from_string("%(%|[-+0]*\\d*(?:\\.\\d+)?[sdifxXc])")
	var pat := "^"
	var lit_all := ""
	var need := ""
	var kinds: Array = []
	var pos := 0
	for m in re_ph.search_all(src):
		var lit := src.substr(pos, m.get_start() - pos)
		pos = m.get_end()
		var ph := m.get_string(1)
		if ph == "%":
			lit += "%"
			pat += _esc(lit)
			lit_all += lit
			if lit.strip_edges().length() > need.length():
				need = lit.strip_edges()
			continue
		pat += _esc(lit)
		lit_all += lit
		if lit.strip_edges().length() > need.length():
			need = lit.strip_edges()
		var kind := ph.right(1)
		if kind == "s":
			pat += "(.*?)"
		elif kind == "f":
			pat += "([-+−]?\\d+(?:[.,]\\d+)?)"
		else:
			pat += "([-+−]?\\d[\\d.,]*)"
		kinds.append(kind)
	var tail := src.substr(pos)
	pat += _esc(tail) + "$"
	lit_all += tail
	if tail.strip_edges().length() > need.length():
		need = tail.strip_edges()
	if kinds.is_empty():
		return []
	# Mindestens zwei Buchstaben fester Text, sonst zu beliebig ("%s: %s" erledigen die Trenner)
	if _re_letters.search_all(lit_all).size() < 2:
		return []
	var re := RegEx.new()
	if re.compile(pat) != OK:
		return []
	# Ausgabe: feste Stücke und Platzhalter-Nummern
	var out: Array = []
	pos = 0
	var idx := 0
	for m in re_ph.search_all(dst):
		out.append(dst.substr(pos, m.get_start() - pos))
		pos = m.get_end()
		if m.get_string(1) == "%":
			out[out.size() - 1] = String(out[out.size() - 1]) + "%"
			continue
		out.append(idx)
		idx += 1
	out.append(dst.substr(pos))
	var first := re_ph.search(src)
	var head := src.substr(0, first.get_start()) if first != null else src
	return [re, need, out, kinds, lit_all.length(), head]


static func _esc(s: String) -> String:
	var o := ""
	for ch in s:
		if "\\^$.|?*+()[]{}".contains(ch):
			o += "\\" + ch
		else:
			o += ch
	return o


# ------------------------------------------------------------------ Übersetzen
func _get_message(src: StringName, _ctx: StringName) -> StringName:
	var s := String(src)
	var r := xl(s)
	# deutsche Zahlen (5,5 · 1.500) in englische Schreibweise
	var base := r if r != "" else s
	if base.contains(",") or base.contains("."):
		var n := _numbers(base)
		if n != base:
			r = n
	if r == "":
		if log_misses and _looks_german(s):
			misses[s] = int(misses.get(s, 0)) + 1
		return &""
	return StringName(r)


## Übersetzung oder "" (= unverändert lassen).
func xl(s: String) -> String:
	if s.length() < 2:
		return ""
	if _cache.has(s):
		return _cache[s]
	var r := _xl_raw(s)
	if _cache.size() > 8000:
		_cache.clear()
		_cmiss.clear()
	_cache[s] = r
	_cmiss[s] = _ret_miss
	return r


## Zahl der unübersetzten Stücke im letzten Ergebnis für s (nach xl(s)).
func _mof(s: String) -> int:
	return int(_cmiss.get(s, 0))


func _xl_raw(s: String) -> String:
	_ret_miss = 0
	var e = _exact.get(s)
	if e != null:
		return e
	if _re_letters == null or _re_letters.search(s) == null:
		return ""
	if _depth > 6:
		_ret_miss = 1
		return ""
	_depth += 1
	var r := _xl_inner(s)
	_depth -= 1
	return r


func _xl_inner(s: String) -> String:
	# Rand-Leerraum
	var t := s.strip_edges()
	if t != s:
		if t == "":
			_ret_miss = 0
			return ""
		var rt := xl(t)
		_ret_miss = _mof(t)
		if rt == "":
			return ""
		var a := s.find(t)
		return s.substr(0, a) + rt + s.substr(a + t.length())
	var up = _upper.get(s)
	if up != null:
		_ret_miss = 0
		return up
	var cpv = _capd.get(s)
	if cpv != null:
		_ret_miss = 0
		return cpv
	# Vorlagen
	var r := _match_tpl(s)
	if r != "":
		_ret_miss = 0
		return r
	# Sonst Kandidaten sammeln; der mit den wenigsten unübersetzten Stücken gewinnt (bei Gleichstand der erste).
	var cands: Array = []          # [Text, unübersetzte Stücke, Liste der Stücke]
	# Zahl/Zeichen davor: "+12 Holz", "• Clankiste: …", "3× Zeitschub"
	var ml := _re_lead.search(s)
	if ml != null and ml.get_string(1) != "":
		var q2 := xl(ml.get_string(2))
		if q2 != "":
			cands.append([ml.get_string(1) + q2, _mof(ml.get_string(2)), []])
	# Zahl dahinter: "Großer Uhu 13", "Grüntal 0/4"
	if not _done(cands):
		var mn := _re_tailnum.search(s)
		if mn != null:
			var q4 := xl(mn.get_string(1))
			if q4 != "":
				cands.append([q4 + mn.get_string(2), _mof(mn.get_string(1)), []])
	# Zerlegen: BBCode-Marken, Trenner (Zeilen, Mittelpunkte, Sätze …), Anführungszeichen
	if not _done(cands) and s.contains("[") and s.contains("]"):
		cands.append(_split_keep(s, _re_tag, false))
	if not _done(cands):
		cands.append(_split_seps(s))
	if not _done(cands) and s.contains("„"):
		cands.append(_split_keep(s, _re_quote, true))
	# Klammer am Ende: "Sägewerk (Stufe 3)"
	if not _done(cands):
		var mp := _re_paren.search(s)
		if mp != null and mp.get_string(1) != "":
			var a1 := _piece(mp.get_string(1))
			var a2 := _piece(mp.get_string(2))
			if a1 != "" or a2 != "":
				var pm := (_mof(mp.get_string(1)) if a1 != "" else 1) + (_mof(mp.get_string(2)) if a2 != "" else 1)
				var pl: Array = [mp.get_string(1)] if a1 == "" else ([mp.get_string(2)] if a2 == "" else [])
				cands.append([(a1 if a1 != "" else mp.get_string(1)) + " (" + (a2 if a2 != "" else mp.get_string(2)) + ")", pm, pl])
	# Satzzeichen danach: "Holz:", "Los!"
	if not _done(cands):
		var mt := _re_trail.search(s)
		if mt != null and mt.get_string(1) != "":
			var q3 := xl(mt.get_string(1))
			if q3 != "":
				cands.append([q3 + mt.get_string(2), _mof(mt.get_string(1)), []])
	var best := ""
	var best_miss := 1 << 30
	var best_list: Array = []
	for c in cands:
		if String(c[0]) != "" and int(c[1]) < best_miss:
			best = c[0]
			best_miss = c[1]
			best_list = c[2]
	if best == "":
		_ret_miss = 1 if _is_words(s) else 0
		return ""
	if log_misses:
		for p in best_list:
			_log_miss(p)
	_ret_miss = best_miss
	return best


## Gibt es schon einen vollständig übersetzten Kandidaten?
static func _done(cands: Array) -> bool:
	for c in cands:
		if String(c[0]) != "" and int(c[1]) == 0:
			return true
	return false


## Zerlegt s an den Treffern von re (BBCode-Marken bzw. „Zitate“) und übersetzt die Stücke dazwischen.
## quotes = true: der Inhalt der Anführungszeichen wird mit übersetzt und in “englische” Zeichen gesetzt.
## Ergebnis: [Text oder "", Zahl der unübersetzten Stücke]
func _split_keep(s: String, re: RegEx, quotes: bool) -> Array:
	var ms := re.search_all(s)
	if ms.is_empty():
		return ["", 0, []]
	var out := ""
	var pos := 0
	var any := false
	var miss := 0
	var lst: Array = []
	for m in ms:
		var piece := s.substr(pos, m.get_start() - pos)
		var q := _piece(piece) if piece.strip_edges().length() > 1 else ""
		out += q if q != "" else piece
		any = any or q != ""
		if q == "" and _is_words(piece):
			miss += 1
			lst.append(piece)
		elif q != "":
			miss += _mof(piece)
		if quotes:
			var inner := m.get_string(1)
			var whole = _exact.get("„" + inner + "“")
			if whole != null:
				out += String(whole)
				any = true
			else:
				var qi := xl(inner)
				out += "“" + (qi if qi != "" else inner) + "”"
				any = any or qi != ""
				if qi == "" and _is_words(inner):
					miss += 1
					lst.append(inner)
				elif qi != "":
					miss += _mof(inner)
		else:
			out += m.get_string()
		pos = m.get_end()
	var last := s.substr(pos)
	var ql := _piece(last) if last.strip_edges().length() > 1 else ""
	out += ql if ql != "" else last
	any = any or ql != ""
	if ql == "" and _is_words(last):
		miss += 1
		lst.append(last)
	elif ql != "":
		miss += _mof(last)
	return [out if any else "", miss, lst]


## Zerlegt s an Trennern (der erste vorkommende Trenner zählt). Ergebnis: [Text oder "", unübersetzte Stücke]
func _split_seps(s: String) -> Array:
	for sep in SEPS:
		if s.contains(sep):
			var parts := s.split(sep)
			var sentence: bool = sep in [". ", "! ", "? "]
			if sentence:
				for i in parts.size() - 1:
					parts[i] = parts[i] + sep.strip_edges()
			var any := false
			var miss := 0
			var lst: Array = []
			for i in parts.size():
				var q := _piece(parts[i])
				if q != "":
					miss += _mof(parts[i])
					parts[i] = q
					any = true
				elif _is_words(parts[i]):
					miss += 1
					lst.append(parts[i])
			if any:
				return [" ".join(parts) if sentence else sep.join(parts), miss, lst]
	return ["", 0, []]


## Enthält das Stück Wörter (nicht nur Zahlen/Zeichen)?
func _is_words(p: String) -> bool:
	return _re_letters != null and _re_letters.search_all(p).size() >= 2


func _piece(p: String) -> String:
	if p.strip_edges() == "":
		return ""
	return xl(p)


func _log_miss(p: String) -> void:
	var k := p.strip_edges()
	if _looks_german(k):
		misses[k] = int(misses.get(k, 0)) + 1


func _match_tpl(s: String) -> String:
	var r := _match_list(_tpl_by.get(s.left(2), []), s)
	if r != "":
		return r
	return _match_list(_tpl_wild, s)


func _match_list(lst: Array, s: String) -> String:
	for tp in lst:
		var need: String = tp[1]
		if need != "" and not s.contains(need):
			continue
		var m: RegExMatch = (tp[0] as RegEx).search(s)
		if m == null:
			continue
		# Vorlagen mit wenig festem Text ("%s und %s") nur, wenn der feste Text einen guten Teil ausmacht
		var lit_len := int(tp[4])
		if String(tp[5]).length() < 3 and lit_len < 10 and float(lit_len) < 0.25 * float(s.length()):
			continue
		var out := ""
		for part in tp[2]:
			if part is int:
				var g := int(part) + 1
				var cap := m.get_string(g) if g <= m.get_group_count() else ""
				var is_s: bool = int(part) < tp[3].size() and String(tp[3][int(part)]) == "s"
				if is_s:
					var tc := xl(cap)
					if tc != "":
						cap = tc
				out += cap
			else:
				out += String(part)
		return _one(out)
	return ""


## Deutsche Zahlenschreibweise in englische: "5,5" → "5.5", "1.500" → "1,500".
func _numbers(s: String) -> String:
	var t := _re_thou.sub(s, "$1\u0001$2", true)
	t = _re_dec.sub(t, "$1.$2", true)
	return t.replace("\u0001", ",") if t != s else s


## "1 gems" → "1 gem"
func _one(s: String) -> String:
	if not s.contains("1 "):
		return s
	var m := _re_one.search(s)
	var guard := 0
	while m != null and guard < 4:
		guard += 1
		var w := m.get_string(1)
		var rep := w
		for k in SINGULAR:
			if w.ends_with(String(k)):
				rep = w.substr(0, w.length() - String(k).length()) + String(SINGULAR[k])
				break
		s = s.substr(0, m.get_start(1)) + rep + s.substr(m.get_end(1))
		m = _re_one.search(s, m.get_start(1) + rep.length())
	return s


func _looks_german(s: String) -> bool:
	if _re_german == null or s.length() < 3:
		return false
	return _re_german.search(s) != null
