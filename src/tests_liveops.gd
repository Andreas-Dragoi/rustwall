extends RefCounted
## Prüfungen für Paket L (Live-Betrieb): Wochen-Ereignisse mit Spielwirkung, Weltboss-Kampf, Feiertage (Deko, Schnee,
## Kürbis-Schleime, Eiersuche), Saison und Saison-Pass (Testkauf), Saison-Ende und Rangliste, Kosmetik (Skins am Modell,
## Waffen- und Bunker-Farbe, Fahne, Hut) und Kosmetik-Shop, Wochenaufgaben, Login-Kalender, Nachrichten-Brett,
## Endspiel (Prestige, Albtraum+, Gebietsboss-Herausforderung der Außenbasen), Server-Anbindung (Testserver), Bildschirme.
## Aufruf aus tests.gd (--selftest) oder allein mit --autotest=liveops.

const D = preload("res://src/data.gd")
const DL = preload("res://src/data_liveops.gd")
const LO = preload("res://src/liveops.gd")
const LOW = preload("res://src/liveops_world.gd")
const Models = preload("res://src/models.gd")
const CD = preload("res://src/companion_data.gd")
const CompanionPose = preload("res://src/companion_pose.gd")
const Humanoid = preload("res://src/humanoid.gd")
const PORT := 7594

var T: Node


func _init(tests: Node) -> void:
	T = tests


func run() -> void:
	if G.arg("lo_only") == "world":                  # Kurzlauf beim Entwickeln: nur die Welt-Teile
		await _raid()
		await _holiday_world()
		await _nightmare()
		await _outpost()
		await _net()
		return
	_data()
	_fresh()
	_events()
	_season()
	_cosmetics()
	_weekly_calendar_news()
	_prestige()
	_holiday_dates()
	await _raid()
	await _holiday_world()
	await _nightmare()
	await _outpost()
	await _screens()
	await _net()
	LO.force_event = ""
	LO.set_holiday_force("")
	_fresh()
	G.main.goto_base()
	await T._wait(0.3)


func _fresh() -> void:
	P.new_game()
	P.no_save = true
	P._ensure_fields()
	LO.force_event = ""


# ---------------------------------------------------------------- Daten und Modelle
func _data() -> void:
	T._check(DL.EVENTS.size() >= 6 and DL.EVENT_ORDER.size() >= 6, "L: mindestens 6 Wochen-Ereignisse")
	for k in DL.EVENTS:
		T._check(DL.EVENT_REWARDS.has(k) and DL.EVENT_REWARDS[k].size() == DL.EVENTS[k].tiers.size(), "L: Belohnungsstufen für %s" % k)
		T._check(k in DL.EVENT_ORDER, "L: %s im Kalender" % k)
	var n := {"skin": 0, "wskin": 0, "bskin": 0, "flag": 0, "hat": 0}
	var per_hero := {}
	for id in DL.COSMETICS:
		var kind := LO.cos_kind(String(id))
		n[kind] = int(n[kind]) + 1
		if kind == "skin":
			var hk := String(DL.COSMETICS[id].hero)
			per_hero[hk] = int(per_hero.get(hk, 0)) + 1
			T._check(Models.has_glb("hero_" + LO.cos_key(String(id))), "L: Modell hero_%s" % LO.cos_key(String(id)))
		elif kind in ["bskin", "flag", "hat"]:
			var m := LO.cos_icon(String(id))
			T._check(Models.has_glb(m), "L: Modell %s" % m)
		T._check(ResourceLoader.exists("res://icons/%s.png" % LO.cos_icon(String(id))), "L: Symbol %s" % LO.cos_icon(String(id)))
		var src := String(DL.COSMETICS[id].get("src", ""))
		T._check(src != "" or int(DL.COSMETICS[id].get("price", 0)) > 0, "L: Quelle für %s" % id)
	T._check(int(n.skin) >= 12 and int(n.bskin) >= 3 and int(n.flag) >= 6 and int(n.hat) >= 6 and int(n.wskin) >= 6, "L: Kosmetik-Mengen %s" % str(n))
	for hk in D.HERO_ORDER:
		T._check(int(per_hero.get(hk, 0)) >= 2, "L: zwei Skins für %s" % hk)
	for m in ["lo_pumpkin", "lo_pumpkins", "lo_pumpkin_hat", "lo_gift", "lo_gifts", "lo_xmas_tree", "lo_snowman", "lo_snowpile", "lo_egg_1", "lo_egg_4"]:
		T._check(Models.has_glb(m), "L: Feiertags-Modell %s" % m)
	for ic in ["ui_season", "ui_wardrobe", "ui_event", "ui_news", "ui_calendar", "ui_prestige", "ui_nightmare", "ui_boost"]:
		T._check(ResourceLoader.exists("res://icons/%s.png" % ic), "L: Symbol %s" % ic)
	T._check(DL.HOLIDAYS.size() == 3 and DL.PASS_TIERS == 40 and DL.CALENDAR.size() == 28 and DL.WEEKLY_N == 5 and DL.NEWS.size() >= 3, "L: Feiertage, Pass, Kalender, Wochenaufgaben, Nachrichten")
	T._check(DL.NIGHTMARE_MODS.size() >= 3 and DL.OUTPOST_CHALLENGE.has(4) and DL.OUTPOST_CHALLENGE.has(5), "L: Albtraum+ und Herausforderungen")
	# kein Pay-to-win: der Pass enthält nur Aussehen und Komfort
	var bad := false
	for t in range(1, DL.PASS_TIERS + 1):
		for tr in ["free", "paid"]:
			for k in LO.pass_reward(tr, t):
				if not (String(k) in ["gems", "coins", "chest", "boost", "cos"]):
					bad = true
	T._check(not bad, "L: Pass-Belohnungen nur Aussehen und Komfort")


# ---------------------------------------------------------------- Wochen-Ereignisse
func _events() -> void:
	_fresh()
	LO.force_event = ""
	T._check(DL.EVENTS.has(LO.event_key()) and LO.week_left() > 0.0 and LO.week_left() <= DL.WEEK_S, "L: Ereignis der Woche aus dem Kalender (%s)" % LO.event_key())
	T._check(LO.event_of_week(DL.EPOCH_WEEK) == String(DL.EVENT_ORDER[0]) and LO.event_of_week(DL.EPOCH_WEEK + DL.EVENT_ORDER.size()) == String(DL.EVENT_ORDER[0]), "L: Kalender wiederholt sich")
	T._check(LO.build_mult() == 1.0 and LO.kill_coins(10, "schleim", false) == 10, "L: in Tests ohne Vorgabe neutral")
	LO.force_event = "schleimregen"
	T._check(LO.kill_coins(10, "schleim", false) == 20 and LO.kill_coins(10, "wald", false) == 10, "L: Schleimregen verdoppelt Schleimbeute")
	LO.force_event = "goldrausch"
	T._check(LO.kill_coins(10, "wald", false) == 15, "L: Goldrausch +50 % Münzen")
	LO.force_event = "eliteflut"
	T._check(LO.extra_elites() == DL.EVENT_ELITES and LO.kill_coins(10, "wald", true) == 20, "L: Elite-Flut: mehr Elite, doppelte Elite-Beute")
	LO.force_event = "bauwoche"
	var t1: float = P.time_for("mg", 3)
	LO.force_event = "goldrausch"
	var t0: float = P.time_for("mg", 3)
	T._check(absf(t1 - t0 * DL.EVENT_BUILD) < 0.01, "L: Bauwoche −25 %% Bauzeit (%.0f statt %.0f s)" % [t1, t0])
	LO.force_event = "haendlerwoche"
	T._check(LO.caravan_mult() == DL.EVENT_CARAVAN_PRICE and LO.caravan_after(40.0) == DL.EVENT_CARAVAN_AFTER, "L: Händlerwoche: Karawane günstiger und früher")
	# Punkte und Stufen
	LO.force_event = "schleimregen"
	T._check(LO.event_points() == 0 and not LO.event_tier_ready(0), "L: Ereignis beginnt bei 0")
	P.quest_progress("kills", int(DL.EVENTS.schleimregen.tiers[0]))
	T._check(LO.event_points() >= int(DL.EVENTS.schleimregen.tiers[0]) and LO.event_tier_ready(0) and LO.event_claimable() == 1, "L: Stufe 1 erreicht")
	var g0 := P.gems()
	T._check(LO.event_claim(0) == "" and P.gems() > g0 and LO.event_claim(0) != "", "L: Stufe einmal abholbar")
	P.quest_progress("kills", 10000)
	LO.event_claim(1)
	LO.event_claim(2)
	T._check(LO.event_claim(3) == "" and LO.owned("flag:schleim"), "L: letzte Stufe gibt Kosmetik")
	# Weltboss: Gemeinschaft
	LO.force_event = "weltboss"
	var pr := LO.boss_progress()
	T._check(pr >= 0.0 and pr <= 1.0 and LO.boss_tries_left() == DL.BOSS_TRIES, "L: Weltboss-Fortschritt %d %%" % int(pr * 100))
	T._check(not LO.event_tier_ready(0), "L: Weltboss-Belohnung nur nach eigenem Angriff")


# ---------------------------------------------------------------- Saison und Pass
func _season() -> void:
	_fresh()
	var Store = load("res://src/store.gd")
	T._check(LO.season_n() >= 1 and LO.season_left() > 0.0 and LO.season_left() <= DL.SEASON_WEEKS * DL.WEEK_S, "L: Saison %d läuft" % LO.season_n())
	T._check(LO.pass_tier() == 0, "L: Pass beginnt bei Stufe 0")
	P.flood_result(true, 1.0, false, 50)
	T._check(LO.season_points() >= int(DL.SP.flood_win), "L: Flut gibt Saisonpunkte (%d)" % LO.season_points())
	var p0 := LO.season_points()
	P.expedition_end(0, 0, "jona", true, {}, {"kills": 3})
	T._check(LO.season_points() >= p0 + int(DL.SP.expeditions), "L: Expedition gibt Saisonpunkte")
	p0 = LO.season_points()
	P._ensure_quests()
	for q in P.d.quests.list:
		P.quest_progress(String(q.key), int(q.amount))
	T._check(LO.season_points() >= p0 + 3 * int(DL.SP.daily), "L: Tagesaufträge geben Saisonpunkte")
	p0 = LO.season_points()
	P.claim_quests()
	T._check(LO.season_points() >= p0 + int(DL.SP.daily_all), "L: alle Tagesaufträge geben Saisonpunkte")
	LO.season().pts = DL.PASS_POINTS * 12 + 10
	T._check(LO.pass_tier() == 12, "L: Stufe aus Punkten")
	T._check(LO.pass_claim("free", 1) == "" and LO.pass_got("free", 1) and LO.pass_claim("free", 1) != "", "L: Gratis-Stufe abholen")
	T._check(LO.pass_claim("paid", 1) != "" and not LO.owned("skin:jona_marine"), "L: bezahlte Spur gesperrt")
	T._check(LO.pass_claim("free", 13) != "", "L: zu hohe Stufe gesperrt")
	T._check(Store.test_mode() and LO.buy_pass() == "" and LO.pass_paid(), "L: Pass-Spur per Testkauf")
	T._check(LO.pass_confirm_text().contains("Testkauf"), "L: Kaufbestätigung nennt den Testkauf")
	var got := LO.pass_claim_all()
	T._check(got >= 20 and LO.owned("skin:jona_marine") and LO.owned("hat:party") and LO.pass_open() == 0, "L: alle offenen Stufen abgeholt (%d)" % got)
	# Rangliste und Saison-Ende
	var b := LO.board()
	var sorted_ok := true
	for i in range(1, b.size()):
		if int(b[i].score) > int(b[i - 1].score):
			sorted_ok = false
	T._check(b.size() == DL.BOARD_SIZE and sorted_ok and LO.season_rank() >= 1, "L: Saison-Rangliste (simuliert), Platz %d" % LO.season_rank())
	var n := LO.season_n()
	LO.season().pts = 999999
	P.d.pickups.clear()
	var off0 := float(P.d.time_offset)
	P.d.time_offset = off0 + DL.SEASON_WEEKS * DL.WEEK_S
	LO.season()
	T._check(P.has_pickup("season") and int(LO.season().n) == n + 1 and int(LO.season().pts) == 0 and not LO.pass_paid(), "L: Saison-Ende: Belohnung nach Rang, neue Saison")
	P.d.time_offset = off0
	T._check(not (LO.st().titles as Array).is_empty(), "L: Titel für Platz 1")


# ---------------------------------------------------------------- Kosmetik und Shop
func _cosmetics() -> void:
	_fresh()
	T._check(LO.equip("skin:mika_glutwehr") != "", "L: fremdes Teil nicht anlegbar")
	T._check(LO.give("skin:mika_glutwehr") and not LO.give("skin:mika_glutwehr"), "L: Kosmetik einmal vergeben")
	T._check(LO.equip("skin:mika_glutwehr") == "" and LO.hero_skin("mika") == "mika_glutwehr" and LO.hero_skin("jona") == "", "L: Helden-Skin angelegt")
	var h = Humanoid.new()
	T.add_child(h)
	h.build({"kind": "mika", "skin": LO.hero_skin("mika")})
	var mdl: Node = h.get_node_or_null("P/M")
	T._check(mdl != null and String(mdl.scene_file_path).contains("hero_mika_glutwehr"), "L: Figur nutzt das Skin-Modell")
	h.queue_free()
	LO.give("wskin:neon")
	LO.equip("wskin:neon")
	var wpn := LO.tint_weapon(Models.weapon("j_rifle"))
	var tinted := false
	for mi in wpn.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).material_override is ShaderMaterial and (mi as MeshInstance3D).material_override == LO.weapon_mat("wskin:neon"):
			tinted = true
	T._check(tinted, "L: Waffen-Skin färbt die Waffe")
	wpn.free()
	var bk := Models.building("bunker", 3)
	LO.apply_bunker_skin(bk, "bskin:goldpalast")
	T._check(bk.get_node_or_null("LoSkin") != null and String(bk.get_meta("lo_skin", "")) == "bskin:goldpalast", "L: Bunker-Skin: Anbauten und Farbe")
	LO.apply_bunker_skin(bk, "")
	T._check(String(bk.get_meta("lo_skin", "x")) == "", "L: Bunker-Skin wieder entfernt")
	bk.free()
	var pose: Node3D = CompanionPose.new().setup("kistenbein")
	T.add_child(pose)
	var hat := LOW.put_hat(pose, "hat:zylinder")
	T._check(hat != null and hat.get_parent() != null, "L: Hut sitzt auf dem Begleiter")
	pose.queue_free()
	# Shop
	var offers := LO.shop_offers()
	var deal := LO.shop_deal()
	T._check(offers.size() == DL.SHOP_SLOTS and not (deal in offers) and deal != "", "L: Shop mit %d Angeboten und Angebot der Woche" % offers.size())
	T._check(LO.shop_price(deal) < int(DL.COSMETICS[deal].price), "L: Angebot der Woche günstiger")
	var id := String(offers[0])
	P.d.res.gems = 0
	T._check(LO.shop_buy(id) != "" and not LO.owned(id), "L: ohne Juwelen kein Kauf")
	P.d.res.gems = 2000
	T._check(LO.shop_buy(id) == "" and LO.owned(id) and P.gems() == 2000 - LO.shop_price(id), "L: Shop-Kauf mit Juwelen")
	T._check(LO.shop_buy(id) != "", "L: nicht doppelt kaufen")
	# Erfolge als Quelle
	P.d.stats.floods_won = 20
	LO.check_ach_cosmetics()
	T._check(LO.owned("skin:bruno_rostschmied"), "L: Kosmetik aus Erfolg")


# ---------------------------------------------------------------- Wochenaufgaben, Kalender, Nachrichten
func _weekly_calendar_news() -> void:
	_fresh()
	var wk := LO.weekly()
	T._check(wk.list.size() == DL.WEEKLY_N and LO.weekly_done() == 0, "L: fünf Wochenaufgaben")
	var g0 := P.gems()
	var s0 := LO.season_points()
	var q: Dictionary = wk.list[0]
	LO.on_progress(String(q.key), int(q.amount))
	T._check(bool(q.done) and P.gems() > g0 and LO.season_points() >= s0 + int(DL.SP.weekly), "L: Wochenaufgabe erfüllt: Belohnung und Saisonpunkte")
	for qq in wk.list:
		LO.on_progress(String(qq.key), int(qq.amount))
	T._check(LO.weekly_done() == DL.WEEKLY_N and bool(wk.bonus) and int(LO.st().boost) >= 1, "L: alle fünf: große Belohnung")
	var w2 := LO.weekly()
	T._check(w2 == LO.st().weekly, "L: Wochenaufgaben bleiben die Woche über")
	# Kalender
	P.d.pickups.clear()
	P.d.daily_gift.day = -1
	P._check_daily()
	T._check(P.has_pickup("daily") and String(P.d.pickups[0].text).contains("Tag 1 von 28") and LO.cal_done() == 1, "L: Kalender Tag 1 als Blase am Bunker")
	for i in 5:
		P.d.pickups.clear()
		P.d.daily_gift.day = -1
		P._check_daily()
	P.d.pickups.clear()
	P.d.daily_gift.day = -1
	P._check_daily()
	T._check(LO.cal_done() == 7 and String(P.d.pickups[0].text).contains("Höhepunkt") and P.d.pickups[0].bundle.has("chest"), "L: Tag 7 ist ein Höhepunkt")
	var b0 := int(LO.st().boost)
	for i in 4:
		P.d.pickups.clear()
		P.d.daily_gift.day = -1
		P._check_daily()
	T._check(LO.cal_done() == 11 and int(LO.st().boost) == b0 + 1, "L: Zeitschub aus dem Kalender sofort gutgeschrieben")
	LO.st().cal.idx = 27
	P.d.pickups.clear()
	P.d.daily_gift.day = -1
	P._check_daily()
	T._check(LO.cal_done() == 28 and LO.owned("wskin:frost") and LO.cal_next() == 1, "L: Tag 28 mit Kosmetik, dann von vorn")
	# Zeitschub
	P.add_many({"coins": 5000, "wood": 2000, "stone": 2000})
	var c := int(D.GRID_MAX / 2)
	P.bunker().level = 3
	var sg := P.place("saege", c - 9, c + 2)
	P.speed_up_builds(1.0e9)
	P.upgrade(int(sg.id))
	var left0: float = P.build_left(int(sg.id))
	LO.st().boost = 1
	T._check(LO.use_boost() == "" and P.build_left(int(sg.id)) < left0 - 100.0 and int(LO.st().boost) == 0, "L: Zeitschub verkürzt laufende Bauten")
	T._check(LO.use_boost() != "", "L: ohne Zeitschub nichts")
	# Nachrichten
	T._check(LO.news().size() >= 3 and LO.news_unread() == LO.news().size(), "L: Nachrichten ungelesen")
	LO.news_read()
	T._check(LO.news_unread() == 0, "L: Nachrichten gelesen")


# ---------------------------------------------------------------- Prestige
func _prestige() -> void:
	_fresh()
	var h: Dictionary = P.d.heroes.jona
	h.level = D.HERO_MAX_LEVEL
	var dmg0 := float(P.hero_stats("jona").m.dmg)
	var g0 := P.gems()
	P.add_hero_xp("jona", DL.PRESTIGE_XP * 2.5)
	T._check(LO.stars("jona") == 2 and absf(LO.prestige_xp_now("jona") - DL.PRESTIGE_XP * 0.5) < 600.0 and int(h.level) == D.HERO_MAX_LEVEL, "L: Prestige-Sterne über Stufe 40 (%d)" % LO.stars("jona"))
	T._check(absf(float(P.hero_stats("jona").m.dmg) - dmg0 - 2 * DL.PRESTIGE_DMG) < 0.0001, "L: Sterne geben Dauerbonus")
	P.add_hero_xp("jona", DL.PRESTIGE_XP * 3.0)
	T._check(LO.stars("jona") == 5 and P.gems() >= g0 + DL.PRESTIGE_GEMS, "L: 5 Sterne geben Juwelen")
	P.d.heroes.mika.level = 10
	P.add_hero_xp("mika", 100.0)
	T._check(LO.stars("mika") == 0, "L: unter Stufe 40 kein Prestige")


func _holiday_dates() -> void:
	var e: Array = LO.easter(2027)
	var e2: Array = LO.easter(2026)
	T._check(int(e[0]) == 3 and int(e[1]) == 28 and int(e2[0]) == 4 and int(e2[1]) == 5, "L: Ostersonntag 2026/2027")
	T._check(LO.holiday() == "", "L: in Tests keine Feiertage ohne Vorgabe")
	LO.set_holiday_force("halloween")
	T._check(LO.holiday() == "halloween", "L: Feiertag über Admin erzwingbar")
	P.d.pickups.clear()
	LO.holiday_gift()
	T._check(P.has_pickup("holiday") and LO.owned("hat:kuerbis"), "L: Feiertags-Geschenk")
	P.d.pickups.clear()
	LO.holiday_gift()
	T._check(not P.has_pickup("holiday"), "L: Feiertags-Geschenk einmal je Jahr")
	P.quest_progress("kills", 400)
	T._check(LO.owned("flag:kuerbis"), "L: Halloween-Ziel gibt Fahne")
	LO.set_holiday_force("")


# ---------------------------------------------------------------- Weltboss-Kampf in der Basis
func _raid() -> void:
	_fresh()
	P.debug_setup(4)
	LO.force_event = "weltboss"
	G.main.goto_base()
	await T._wait(0.6)
	var w = G.main.world
	T._check(LO.start_raid() == "", "L: Weltboss-Angriff startet")
	await T._wait(0.2)
	var b = w.horde.boss
	T._check(b != null and int(b.t) == int(D.ENEMY_INDEX["boss_leviathan"]) and w.flood.get("raid", false), "L: Schleim-Leviathan erscheint")
	if b != null:
		b.inv = 0.0                                   # Auftritt des Bosses überspringen
		w.horde.damage(b, 6000.0, Vector2.ZERO, true)
	await T._wait(0.2)
	w.set_meta("raid_t", DL.BOSS_TIME - 0.05)
	await T._wait(0.6)
	T._check(w.ended and bool(w.result.get("raid", false)) and int(LO.boss_state().dmg) >= 5000, "L: Angriff endet nach der Zeit, Schaden gezählt (%d)" % int(LO.boss_state().dmg))
	T._check(LO.boss_tries_left() == DL.BOSS_TRIES - 1 and LO.event_tier_ratio(0) >= 0.0, "L: ein Angriff verbraucht")
	T._check(int(P.d.week.practice_day) != P.day_index(), "L: Weltboss verbraucht nicht den Übungsalarm")
	await T._wait(0.3)
	G.main.hud._leave_result("")
	T.get_tree().paused = false
	G.main.goto_base()
	await T._wait(0.4)
	LO.force_event = ""


# ---------------------------------------------------------------- Feiertage in der Welt
func _holiday_world() -> void:
	_fresh()
	P.debug_setup(4)
	LO.set_holiday_force("weihnachten")
	G.main.goto_base()
	await T._wait(0.6)
	var low: Node = G.main.world.get_node_or_null("LiveOps")
	T._check(low != null and low.hol == "weihnachten" and low._snow != null and low.get_child_count() >= 6, "L: Weihnachten: Schnee und Deko in der Basis (%d)" % (low.get_child_count() if low else 0))
	# Fahne und Bunker-Skin in der Basis
	LO.give("flag:sturm")
	LO.equip("flag:sturm")
	LO.give("bskin:polarstation")
	LO.equip("bskin:polarstation")
	await T._wait(1.4)
	T._check(low._flag_node != null and is_instance_valid(low._flag_node), "L: Fahne steht am Bunker")
	var bn = G.main.world.bunker_node
	T._check(bn.model.get_node_or_null("LoSkin") != null, "L: Bunker trägt den Skin")
	LO.set_holiday_force("halloween")
	G.main.goto_base()
	await T._wait(0.6)
	low = G.main.world.get_node_or_null("LiveOps")
	T._check(low != null and low._hats != null and low.get_child_count() >= 5, "L: Halloween: Kürbisse und Hut-MultiMesh")
	G.main.world.start_flood(true)
	await T._wait(1.2)
	var orange := false
	for e in G.main.world.horde.list:
		if String(D.ENEMIES[e.t].family) == "schleim" and e.tint.r > e.tint.g * 1.4:
			orange = true
	low._place_hats()
	T._check(orange and low._hats.multimesh.visible_instance_count > 0, "L: Kürbis-Schleime mit Hut")
	G.main.goto_base()
	await T._wait(0.3)
	# Ostern: Eiersuche
	LO.set_holiday_force("ostern")
	G.autotest = ""
	G.main.start_expedition(0, "expedition", 0)
	await T._wait(0.8)
	var ex = G.main.world
	low = ex.get_node_or_null("LiveOps")
	T._check(low != null and low.eggs_left() == DL.EGGS_PER_EXP, "L: Ostern: %d Eier versteckt" % (low.eggs_left() if low else 0))
	if low != null and low.eggs_left() > 0:
		var e0 := int(LO.st().eggs)
		var p: Vector2 = low.egg_pos(0)
		ex.hero.global_position = Vector3(p.x, 0, p.y)
		await T._wait(0.3)
		T._check(int(LO.st().eggs) == e0 + 1 and low.eggs_left() == DL.EGGS_PER_EXP - 1, "L: Ei gefunden")
	LO.set_holiday_force("")
	G.main.goto_base()
	await T._wait(0.3)


# ---------------------------------------------------------------- Albtraum+
func _nightmare() -> void:
	_fresh()
	for i in D.AREAS.size():
		for dd in 3:
			P.d.areas.boss[i][dd] = true
	for k in ["explode", "noheal", "doubleboss"]:
		LO.nm_toggle(k)
	T._check(LO.nm_mods().size() == 3 and absf(LO.nm_loot(LO.nm_mods()) - 1.9) < 0.001, "L: Albtraum+ mit drei Modifikatoren")
	G.autotest = ""
	G.main.start_expedition(0, "expedition", 2)
	await T._wait(0.8)
	var ex = G.main.world
	T._check(ex.has_meta("nm") and LO.nm_explode and LO.nm_noheal and LO.nm_double, "L: Albtraum+ aktiv in der Expedition")
	T._check(absf(float(ex.loot_bonus) - float(D.DIFFS[2].loot) * 1.9) < 0.01, "L: Albtraum+ erhöht die Beute")
	var h = ex.hero
	h.hp = h.max_hp * 0.5
	h.heal(h.max_hp)
	T._check(absf(h.hp - h.max_hp * 0.5) < 0.01, "L: Keine Heilung")
	h.invuln = 0.0
	var hp0: float = h.hp
	var e = ex.horde.spawn(0, h.pos2() + Vector2(1.0, 0), 1.0, 1.0, 1.0)
	ex.horde.damage(e, 1.0e9, Vector2.ZERO, true)
	T._check(h.hp < hp0, "L: Gegner explodieren beim Tod")
	var n0 := 0
	for e2 in ex.horde.list:
		if e2.st != 2:
			n0 += 1
	ex.spawn_boss_at(h.pos2() + Vector2(20, 0))
	var n1 := 0
	for e3 in ex.horde.list:
		if e3.st != 2:
			n1 += 1
	T._check(n1 >= n0 + 2, "L: Doppelte Bosse (%d neue Gegner)" % (n1 - n0))
	G.main.goto_base()
	await T._wait(0.4)
	T._check(not LO.nm_explode and not LO.nm_noheal, "L: Albtraum+ endet mit der Expedition")
	for k in ["explode", "noheal", "doubleboss"]:
		LO.nm_toggle(k)


# ---------------------------------------------------------------- Außenbasis Stufe 4: Gebietsboss-Herausforderung
func _outpost() -> void:
	_fresh()
	LO.force_challenge = true
	P.outpost_set_level("gruental", 3)
	G.autotest = ""
	G.main.start_expedition(0, "expedition", 0)
	await T._wait(0.8)
	var ex = G.main.world
	ex.admin_outpost_done()
	await T._wait(0.4)
	T._check(ex.has_meta("op_ch") and P.outpost_level("gruental") == 3, "L: Stufe 4 wartet auf den Gebietsboss")
	var b = ex.horde.boss
	T._check(b != null and b.mhp > 0.0, "L: Gebietsboss erscheint an der Außenbasis")
	var g0 := P.gems()
	for i in 3:
		if ex.horde.boss != null and ex.horde.boss.st != 2:
			var bb = ex.horde.boss
			bb.next_phase = ""
			ex.horde.damage(bb, 1.0e9, Vector2.ZERO, true, true)
		await T._wait(0.3)
	T._check(P.outpost_level("gruental") == 4 and int(LO.st().op_ch.get("gruental", 0)) == 4 and P.gems() > g0, "L: nach dem Sieg Stufe 4 (Stufe %d)" % P.outpost_level("gruental"))
	LO.force_challenge = false
	G.main.goto_base()
	await T._wait(0.4)


# ---------------------------------------------------------------- Bildschirme und HUD
func _screens() -> void:
	_fresh()
	P.debug_setup(4)
	G.main.goto_base()
	await T._wait(0.6)
	var hud = G.main.hud
	T._check(hud.root.find_child("LoBanner", true, false) != null, "L: Ereignis-Banner im HUD")
	var s = G.main.screens
	for tab in 7:
		s.open("saison", {"tab": tab})
		await T._wait(0.15)
		T._check(s.is_open() and s.screen == "saison", "L: Saison-Seite Reiter %d" % tab)
	s.close()
	for id in DL.COSMETICS:
		LO.give(String(id))
	for tab in 6:
		s.open("garderobe", {"tab": tab})
		await T._wait(0.15)
		T._check(s.is_open() and s.screen == "garderobe", "L: Garderobe Reiter %d" % tab)
	s.close()
	s.open("expedition", {"diff": 2})
	await T._wait(0.15)
	s.close()


# ---------------------------------------------------------------- Server (Testserver mock_server.py)
func _net() -> void:
	_fresh()
	P.social.s = P.d.social
	P.social.ensure()
	var net: Node = P.social.net
	var script := ProjectSettings.globalize_path("res://server/mock_server.py")
	var pid := -1
	for exe in ["python3", "python"]:
		pid = OS.create_process(exe, [script, "--port", str(PORT), "--quit-after", "300"])
		if pid > 0:
			break
	if pid <= 0:
		print("HINWEIS: Server-Prüfungen von Paket L übersprungen (python3 fehlt)")
		return
	var keep: Dictionary = net.cfg.duplicate()
	await _real(1.5)                                   # Testserver starten lassen (echte Zeit)
	net.set_server("http://127.0.0.1:%d" % PORT)
	for i in 100:
		if net.online():
			break
		await _real(0.1)
	T._check(net.online(), "L: mit dem Testserver verbunden")
	if net.online():
		LO.season_add("flood_win")
		var node := LO.net_node()
		for i in 60:
			if not node.busy:
				break
			await _real(0.1)
		await node.pull()
		var srv: Dictionary = LO.st().srv
		T._check(int(srv.get("week", -1)) == LO.week_index() and DL.EVENTS.has(String(srv.get("event", ""))), "L: Ereignis-Zeitplan vom Server (%s)" % String(srv.get("event", "")))
		T._check(srv.get("news") is Array and (srv.news as Array).size() >= 1 and LO.news() == srv.news, "L: Nachrichten vom Server")
		T._check(int(LO.season().get("sent", 0)) == LO.season_points() and LO.season_points() > 0, "L: Saisonpunkte zum Server übertragen")
		var sb: Dictionary = LO.st().srv_board
		T._check(sb.get("entries") is Array and (sb.entries as Array).size() >= 1 and LO.season_rank() >= 1, "L: Saison-Rangliste vom Server")
	net.cfg = keep
	net.cfg.url = ""
	net.status = "aus"
	P.server_offset = 0.0
	OS.kill(pid)
	LO.st().srv = {}
	LO.st().srv_board = {}


func _real(sec: float) -> void:
	await T.get_tree().create_timer(sec, true, false, true).timeout
