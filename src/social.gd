extends RefCounted
## Gemeinsam spielen: Freunde, Clan, Verschicken, Post, Ranglisten.
##
## WICHTIG: Ohne Server gibt es keine echten Mitspieler. Diese Datei bildet alle Regeln aus
## dem Konzept (Kapitel 13) vollständig ab, aber die anderen Spieler sind SIMULIERT.
## Sie ist bewusst als eine abgeschlossene Schicht gebaut: Für den echten Online-Betrieb
## werden die Funktionen hier durch Server-Anfragen (z. B. Nakama) ersetzt; die Oberfläche
## und der Rest des Spiels bleiben unverändert.

const D = preload("res://src/data.gd")

var p: Node                       # Profil (Autoload P)
var s: Dictionary                 # p.d.social
var _rng := RandomNumberGenerator.new()


func _init(profile: Node) -> void:
	p = profile
	_rng.randomize()


func ensure() -> void:
	if not p.d.has("social") or not (p.d.social is Dictionary) or p.d.social.is_empty():
		p.d.social = {
			"code": _make_code(_rng.randi()), "friends": [], "clan": {}, "mail": [], "next_mail": 1,
			"send_day": -1, "send_count": 0, "item_day": -1, "giftbox_week": -1, "help_day": -1, "help_count": 0,
			"league": 0, "week": -1, "points": {"flood": 0, "explorer": 0}, "seed": _rng.randi() % 100000,
			"times": {}, "last_tick": 0.0, "request": {}, "shouts": [], "season_best": 0,
		}
	s = p.d.social
	if int(s.week) < 0:
		s.week = abs_week()
	s.league = int(s.league)


func abs_week() -> int:
	return int(floor(p.day_index() / 7.0))


func week_progress() -> float:
	return clampf((p.day_index() % 7 + 1.0 - p.seconds_to_next_day() / 86400.0) / 7.0, 0.0, 1.0)


func _make_code(n: int) -> String:
	var chars := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var out := ""
	var v := absi(n) + 7919
	for i in 8:
		out += chars[v % chars.length()]
		v = int(v / chars.length()) + (i + 3) * 7331
	return out


func _bot_name(seed_val: int) -> String:
	return "%s %d" % [D.BOT_NAMES[absi(seed_val) % D.BOT_NAMES.size()], absi(seed_val * 31 + 7) % 90 + 10]


func _hash(text: String) -> int:
	return absi(text.hash())


# ================================================================= Zeit
func tick(t: float) -> void:
	if s.is_empty():
		return
	# Wochenwechsel der Ranglisten
	var w := abs_week()
	if int(s.week) != w:
		_week_rollover()
		s.week = w
	var last := float(s.last_tick)
	if last <= 0.0:
		s.last_tick = t
		return
	var dt := t - last
	if dt < 60.0:
		return
	s.last_tick = t
	var steps := mini(int(dt / 600.0) + 1, 60)
	for i in steps:
		_simulate_step()
	# abgelaufene Post entfernen
	for i in range(s.mail.size() - 1, -1, -1):
		if float(s.mail[i].expire) < t:
			s.mail.remove_at(i)
	p.mark()


## Ein Simulationsschritt entspricht etwa zehn Minuten.
func _simulate_step() -> void:
	# Freunde schicken gelegentlich etwas
	for f in s.friends:
		if _rng.randf() < 0.004:
			var r: String = D.SENDABLE[_rng.randi() % 2]
			var amt := 30 + int(f.level) * 6
			_mail(String(f.name), "schickt dir %d %s" % [amt, D.RES_NAME[r]], {r: amt}, "", 0)
		elif _rng.randf() < 0.0008:
			_mail(String(f.name), "schickt dir eine Geschenkkiste", {}, "gift", 0)
	# offene Spendenbitte wird von Clan-Mitgliedern gefüllt
	if has_clan() and not s.request.is_empty():
		var rq: Dictionary = s.request
		if int(rq.filled) < int(rq.amount) and _rng.randf() < 0.5:
			var give := mini(int(rq.amount) - int(rq.filled), int(int(rq.amount) * _rng.randf_range(0.15, 0.4)) + 1)
			rq.filled = int(rq.filled) + give
			var who: Dictionary = s.clan.members[_rng.randi() % s.clan.members.size()]
			_mail(String(who.name), "spendet %d %s" % [give, D.RES_NAME[rq.res]], {rq.res: give}, "", 0)
			if int(rq.filled) >= int(rq.amount):
				s.request = {}
	# Clan lebt: Zurufe und Punkte
	if has_clan():
		var c: Dictionary = s.clan
		for m in c.members:
			if _rng.randf() < 0.3:
				m.points = int(m.points) + _rng.randi_range(2, 14) * int(1 + int(m.level) / 12)
		if _rng.randf() < 0.12:
			var m2: Dictionary = c.members[_rng.randi() % c.members.size()]
			shout_add(String(m2.name), D.SHOUTS[_rng.randi() % D.SHOUTS.size()])
		if c.asks.size() < 3 and _rng.randf() < 0.25:
			var m3: Dictionary = c.members[_rng.randi() % c.members.size()]
			var r2: String = D.SENDABLE[_rng.randi() % D.SENDABLE.size()]
			c.asks.append({"name": m3.name, "res": r2, "amount": 40 + int(m3.level) * 4})
		_check_clan_goal()


func _mail(from: String, text: String, res: Dictionary, chest: String, item_id: int) -> void:
	s.mail.append({"id": int(s.next_mail), "from": from, "text": text, "res": res, "chest": chest, "item": item_id, "expire": p.now() + 7 * 86400.0})
	s.next_mail = int(s.next_mail) + 1
	if s.mail.size() > 40:
		s.mail.pop_front()


func mail_count() -> int:
	return s.mail.size()


func mail_claim(id: int) -> bool:
	for i in s.mail.size():
		var m: Dictionary = s.mail[i]
		if int(m.id) == id:
			for r in m.res:
				p.add(r, float(m.res[r]))
			if String(m.chest) != "":
				p.add_chest(String(m.chest))
			s.mail.remove_at(i)
			p.mark()
			return true
	return false


func mail_claim_all() -> int:
	var n := 0
	while s.mail.size() > 0:
		mail_claim(int(s.mail[0].id))
		n += 1
	return n


# ================================================================= Freunde
func friend_code() -> String:
	return String(s.code)


func add_friend(code: String) -> String:
	code = code.strip_edges().to_upper()
	if code.length() != 8:
		return "Ein Freundescode hat acht Zeichen."
	if code == friend_code():
		return "Das ist dein eigener Code."
	if s.friends.size() >= 100:
		return "Freundesliste ist voll."
	for f in s.friends:
		if f.code == code:
			return "Ihr seid schon befreundet."
	var h := _hash(code)
	var lvl := clampi(int(p.d.level) + (h % 9) - 4, 1, 60)
	s.friends.append({"code": code, "name": _bot_name(h), "bunker_name": bot_bunker(h), "level": lvl, "bunker": clampi(1 + int(lvl / 6), 1, 10), "since": p.day_index(), "seed": h % 100000})
	p.mark()
	return ""


func suggestions() -> Array:
	var out: Array = []
	for i in 5:
		var code := _make_code(int(s.seed) * 13 + i * 977 + p.day_index())
		var taken := false
		for f in s.friends:
			if f.code == code:
				taken = true
		if not taken:
			var h := _hash(code)
			out.append({"code": code, "name": _bot_name(h), "level": clampi(int(p.d.level) + (h % 9) - 4, 1, 60)})
	return out


## Bunkername eines simulierten Mitspielers (fest aus seinem Code abgeleitet).
func bot_bunker(h: int) -> String:
	return "%s%s" % [D.BUNKER_NAME_PARTS[h % D.BUNKER_NAME_PARTS.size()], D.BUNKER_NAME_ENDS[int(h / 13) % D.BUNKER_NAME_ENDS.size()]] + ("" if h % 3 == 0 else " %d" % (h % 97 + 2))


## Bunker suchen: nach Name (Teil reicht) oder genauem Freundescode.
## Ohne Server werden die simulierten Mitspieler durchsucht (immer dieselben 400 Bunker).
func find_bases(query: String) -> Array:
	var q := query.strip_edges().to_lower()
	var out: Array = []
	if q.length() < 2:
		return out
	if q.to_upper() == friend_code().to_upper() or q == p.bunker_name().to_lower():
		out.append({"code": friend_code(), "name": String(p.d.name), "bunker_name": p.bunker_name(), "level": int(p.d.level), "own": true})
	for i in 400:
		var code := _make_code(i * 104729 + 17)
		var h := _hash(code)
		var bn := bot_bunker(h)
		if bn.to_lower().contains(q) or code.to_lower() == q:
			out.append({"code": code, "name": _bot_name(h), "bunker_name": bn, "level": clampi(3 + h % 50, 1, 60), "own": false})
			if out.size() >= 12:
				break
	return out


func remove_friend(code: String) -> void:
	for i in s.friends.size():
		if s.friends[i].code == code:
			s.friends.remove_at(i)
			p.mark()
			return


func friend_score(f: Dictionary) -> int:
	return _bot_score(int(f.seed), int(f.level), "flood")


func sends_left() -> int:
	if int(s.send_day) != p.day_index():
		return D.SEND_PER_DAY
	return maxi(0, D.SEND_PER_DAY - int(s.send_count))


func send_amount(r: String) -> int:
	return int(p.res(r) * D.SEND_SHARE)


## Schickt 5 % des eigenen Bestands eines Rohstoffs. Rückgabe: "" oder Grund für die Ablehnung.
func send_resource(target_name: String, r: String) -> String:
	if not r in D.SENDABLE:
		return "Das lässt sich nicht verschicken."
	if sends_left() <= 0:
		return "Heute sind alle fünf Sendungen verbraucht."
	var amt := send_amount(r)
	if amt <= 0:
		return "Davon hast du zu wenig."
	if int(s.send_day) != p.day_index():
		s.send_day = p.day_index()
		s.send_count = 0
	s.send_count = int(s.send_count) + 1
	p.pay({r: amt})
	p.add_xp(8)
	add_clan_points(4)
	if _rng.randf() < 0.5:
		_mail(target_name, "sagt: Danke!", {}, "", 0)
	p.mark()
	return ""


func can_send_item(f: Dictionary) -> String:
	if p.day_index() - int(f.since) < 7:
		return "Erst nach 7 Tagen Freundschaft."
	if int(s.item_day) == p.day_index():
		return "Heute wurde schon ein Stück verschickt."
	return ""


func send_item(f: Dictionary, item_id: int) -> String:
	var why := can_send_item(f)
	if why != "":
		return why
	var it: Dictionary = p.item(item_id)
	if it.is_empty() or int(it.rarity) > 1:
		return "Nur gewöhnliche und seltene Stücke lassen sich verschicken."
	if p.equipped_by(item_id) != "":
		return "Das Stück ist ausgerüstet."
	p.d.items.erase(it)
	s.item_day = p.day_index()
	p.mark()
	return ""


func can_send_giftbox() -> bool:
	return int(s.giftbox_week) != abs_week()


func send_giftbox(target_name: String) -> bool:
	if not can_send_giftbox():
		return false
	s.giftbox_week = abs_week()
	p.add_xp(10)
	if _rng.randf() < 0.6:
		_mail(target_name, "schickt eine Geschenkkiste zurück", {}, "gift", 0)
	p.mark()
	return true


func helps_left() -> int:
	if int(s.help_day) != p.day_index():
		return 5
	return maxi(0, 5 - int(s.help_count))


func help_friend(_f: Dictionary) -> bool:
	if helps_left() <= 0:
		return false
	if int(s.help_day) != p.day_index():
		s.help_day = p.day_index()
		s.help_count = 0
	s.help_count = int(s.help_count) + 1
	p.add_xp(6)
	p.add("coins", 15)
	p.mark()
	return true


# ================================================================= Clan
func has_clan() -> bool:
	return not s.clan.is_empty()


func clan_list() -> Array:
	var out: Array = []
	for i in D.CLAN_NAMES.size():
		var seed_val := int(s.seed) + i * 131
		out.append({"name": D.CLAN_NAMES[i], "level": 1 + (seed_val % 12), "members": 12 + (seed_val % 17), "min_level": 8 + (seed_val % 4) * 4, "seed": seed_val})
	return out


func _make_members(seed_val: int, n: int, avg_level: int) -> Array:
	var out: Array = []
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	for i in n:
		var lvl := clampi(avg_level + r.randi_range(-6, 8), 1, 60)
		out.append({"name": _bot_name(seed_val * 17 + i * 53), "level": lvl, "points": int(week_progress() * r.randi_range(200, 900) * (1.0 + lvl / 20.0)),
			"role": "Anführer" if i == 0 else ("Stellvertreter" if i < 3 else "Mitglied")})
	return out


func join_clan(entry: Dictionary) -> String:
	if int(p.d.level) < D.CLAN_MIN_LEVEL:
		return "Clans gibt es ab Spielerstufe %d." % D.CLAN_MIN_LEVEL
	if int(p.d.level) < int(entry.min_level):
		return "Dieser Clan nimmt ab Stufe %d auf." % int(entry.min_level)
	s.clan = {"name": entry.name, "level": int(entry.level), "own": false, "members": _make_members(int(entry.seed), int(entry.members), int(p.d.level)),
		"my_points": 0, "chest_week": -1, "asks": [], "color": int(entry.seed) % 6}
	shout_add("Clan", "%s ist beigetreten" % String(p.d.name))
	p.mark()
	return ""


func create_clan(clan_name: String) -> String:
	clan_name = clan_name.strip_edges()
	if int(p.d.level) < D.CLAN_MIN_LEVEL:
		return "Clans gibt es ab Spielerstufe %d." % D.CLAN_MIN_LEVEL
	if clan_name.length() < 3 or clan_name.length() > 16:
		return "Der Name braucht 3 bis 16 Zeichen."
	if not p.pay({"coins": 500}):
		return "Gründen kostet 500 Münzen."
	s.clan = {"name": clan_name, "level": 1, "own": true, "members": _make_members(_hash(clan_name), 9, int(p.d.level)),
		"my_points": 0, "chest_week": -1, "asks": [], "color": _hash(clan_name) % 6}
	s.clan.members[0].role = "Stellvertreter"
	p.mark()
	return ""


func leave_clan() -> void:
	s.clan = {}
	s.request = {}
	p.mark()


func clan_points() -> int:
	if not has_clan():
		return 0
	var t := int(s.clan.my_points)
	for m in s.clan.members:
		t += int(m.points)
	return t


func clan_goal() -> int:
	if not has_clan():
		return 1
	return (s.clan.members.size() + 1) * (260 + 40 * int(s.clan.level))


func add_clan_points(n: int) -> void:
	if has_clan():
		s.clan.my_points = int(s.clan.my_points) + n
		_check_clan_goal()


func _check_clan_goal() -> void:
	var c: Dictionary = s.clan
	if int(c.chest_week) != abs_week() and clan_points() >= clan_goal():
		c.chest_week = abs_week()
		c.level = mini(20, int(c.level) + 1)
		if int(c.my_points) > 0:
			_mail("Clan " + String(c.name), "Wochenziel erreicht! Clankiste für alle.", {}, "clan", 0)
		shout_add("Clan", "Wochenziel erreicht – Clan-Stufe %d" % int(c.level))


func clan_bonus() -> float:
	return 0.02 * int(s.clan.level) if has_clan() else 0.0


func donate(index: int) -> String:
	if not has_clan() or index >= s.clan.asks.size():
		return "?"
	var a: Dictionary = s.clan.asks[index]
	var amt := mini(int(a.amount), p.res(String(a.res)))
	if amt <= 0:
		return "Davon hast du nichts."
	p.pay({a.res: amt})
	s.clan.asks.remove_at(index)
	add_clan_points(int(amt / 4) + 5)
	p.add_xp(10 + int(amt / 10))
	p.quest_progress("donate", 1)
	shout_add(String(a.name), "Danke!")
	p.mark()
	return ""


func can_request() -> bool:
	return has_clan() and (s.request.is_empty() or p.now() - float(s.request.get("at", 0.0)) > 8 * 3600.0)


func request(r: String) -> bool:
	if not can_request():
		return false
	s.request = {"res": r, "amount": 80 + 20 * p.bunker_level(), "filled": 0, "at": p.now()}
	shout_add(String(p.d.name), "Wer spendet %s?" % D.RES_NAME[r])
	p.mark()
	return true


func shout_add(who: String, text: String) -> void:
	s.shouts.append({"who": who, "text": text, "t": p.now()})
	while s.shouts.size() > 30:
		s.shouts.pop_front()


func shout(index: int) -> void:
	if has_clan():
		shout_add(String(p.d.name), D.SHOUTS[index])
		p.mark()


# ================================================================= Ranglisten
func add_points(board: String, n: int) -> void:
	s.points[board] = int(s.points.get(board, 0)) + n
	p.mark()


func _bot_score(seed_val: int, level: int, board: String) -> int:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val * 7 + abs_week() * 101 + (3 if board == "flood" else 11)
	var skill := r.randf_range(0.5, 1.3)
	if board == "flood":
		# die Flut bringt Punkte in einem Schub; Bots "spielen" sie an verschiedenen Wochentagen
		var day := r.randi_range(0, 6)
		var done := week_progress() * 7.0 > day
		return int((300 + level * 40) * skill) if done else 0
	return int((level * 30 + 200) * skill * week_progress() * 4.0)


## Rangliste als sortierte Liste von {name, score, me}.
func board(kind: String) -> Array:
	var out: Array = []
	if kind == "friends":
		for f in s.friends:
			out.append({"name": f.name, "score": friend_score(f), "me": false})
		out.append({"name": p.d.name, "score": int(s.points.flood), "me": true})
	elif kind == "clans":
		for c in clan_list():
			var r := RandomNumberGenerator.new()
			r.seed = int(c.seed) + abs_week() * 7
			out.append({"name": c.name, "score": int(int(c.members) * (260 + 40 * int(c.level)) * week_progress() * r.randf_range(0.7, 1.5)), "me": false})
		if has_clan():
			var found := false
			for e in out:
				if e.name == s.clan.name:
					e.score = clan_points()
					e.me = true
					found = true
			if not found:
				out.append({"name": s.clan.name, "score": clan_points(), "me": true})
	else:
		var lg := int(s.league)
		for i in D.LEAGUE_SIZE - 1:
			var sd := int(s.seed) + i * 97 + lg * 1009
			var lvl := clampi(int(p.d.level) + lg * 3 + (sd % 11) - 5, 1, 60)
			out.append({"name": _bot_name(sd), "score": _bot_score(sd, lvl, kind), "me": false})
		out.append({"name": p.d.name, "score": int(s.points.get(kind, 0)), "me": true})
	out.sort_custom(func(a, b): return int(a.score) > int(b.score))
	return out


func my_rank(kind: String) -> int:
	var b := board(kind)
	for i in b.size():
		if b[i].me:
			return i + 1
	return b.size()


func league_name() -> String:
	return D.LEAGUES[clampi(int(s.league), 0, D.LEAGUES.size() - 1)]


func _week_rollover() -> void:
	# Abrechnung der Flut-Liga: beste zehn steigen auf, letzte zehn steigen ab
	if int(s.points.flood) > 0 or int(s.points.explorer) > 0:
		var rank := my_rank("flood")
		var lg := int(s.league)
		var shards := maxi(1, 6 - int(rank / 10)) + lg
		var text := "Flut-Rangliste: Platz %d in Liga %s." % [rank, league_name()]
		if rank <= 10 and lg < D.LEAGUES.size() - 1 and int(s.points.flood) > 0:
			s.league = lg + 1
			text += " Aufstieg!"
		elif rank > 40 and lg > 0:
			s.league = lg - 1
			text += " Abstieg."
		_mail("Rangliste", text, {"shards": shards}, "", 0)
		var er := my_rank("explorer")
		if int(s.points.explorer) > 0 and er <= 25:
			_mail("Rangliste", "Entdecker-Rangliste: Platz %d." % er, {}, "find", 0)
	s.points = {"flood": 0, "explorer": 0}
	if has_clan():
		s.clan.my_points = 0
		for m in s.clan.members:
			m.points = 0


func submit_time(area: int, t: float) -> void:
	var k := str(area)
	if not s.times.has(k) or t < float(s.times[k]):
		s.times[k] = t
		p.mark()


func best_times(area: int) -> Array:
	var out: Array = []
	for i in 9:
		var sd := int(s.seed) + i * 59 + area * 401
		var r := RandomNumberGenerator.new()
		r.seed = sd
		out.append({"name": _bot_name(sd), "score": 55.0 + area * 6.0 + r.randf_range(0.0, 40.0), "me": false})
	if s.times.has(str(area)):
		out.append({"name": p.d.name, "score": float(s.times[str(area)]), "me": true})
	out.sort_custom(func(a, b): return float(a.score) < float(b.score))
	return out
