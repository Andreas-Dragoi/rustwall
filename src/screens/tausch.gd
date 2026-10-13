extends RefCounted
## Bildschirm „Tauschladen“ (V6 Paket E): Rosa, die gerettete Händlerin, tauscht Rohstoffe. Jeden Tag vier Angebote
## (feste Auswahl je Tag aus DG.TRADES, jedes einige Male), einmal in der Woche ein Begleiter-Ei.
## Geöffnet durch Antippen des Gebäudes „Tauschladen“ (D.BUILDINGS.tauschladen.screen).

const D = preload("res://src/data.gd")
const DG = preload("res://src/data_geschichte.gd")
const DW = preload("res://src/data_welt.gd")
const UI = preload("res://src/ui.gd")
const Story = preload("res://src/story.gd")

var S


func setup(_arg) -> void:
	Story.demo()


## Heutige Angebote: Liste von Indizes in DG.TRADES.
static func offers() -> Array:
	var di := P.day_index()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("tausch|%d" % di)
	var idx: Array = range(DG.TRADES.size())
	for i in range(idx.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = idx[i]
		idx[i] = idx[j]
		idx[j] = t
	return idx.slice(0, DG.TRADES_PER_DAY)


static func _state() -> Dictionary:
	var s := Story.st()
	if s.is_empty():
		return {}
	var ts: Dictionary = s.trade
	if int(ts.get("day", -1)) != P.day_index():
		ts["day"] = P.day_index()
		ts["used"] = {}
	return ts


static func left(i: int) -> int:
	var ts := _state()
	return int(DG.TRADES[i].n) - int((ts.get("used", {}) as Dictionary).get(str(i), 0))


## Tauschen. Rückgabe: "" = geklappt, sonst der Grund.
static func trade(i: int) -> String:
	if not Story.rescued("haendlerin"):
		return "Rosa ist noch nicht in deiner Basis"
	if not offers().has(i):
		return "Dieses Angebot gibt es heute nicht"
	if left(i) <= 0:
		return "Für heute ausverkauft"
	var t: Dictionary = DG.TRADES[i]
	if not P.pay(t.give):
		return P.missing_text(t.give)
	for r in t.get:
		P.add(String(r), int(t.get[r]))
	var ts := _state()
	ts.used[str(i)] = int((ts.used as Dictionary).get(str(i), 0)) + 1
	P.count_up("trades", 1)
	Sfx.play("trade_deal", -3.0)
	P.resources_changed.emit()
	P.mark()
	return ""


static func egg_ready() -> bool:
	return int(Story.st().get("egg_week", -1)) != int(P.d.week.number)


static func buy_egg() -> String:
	if not Story.rescued("haendlerin"):
		return "Rosa ist noch nicht in deiner Basis"
	if not egg_ready():
		return "Das Ei dieser Woche ist schon verkauft"
	var WS = load("res://src/welt_state.gd")
	if WS.eggs().size() >= DW.EGG_MAX:
		return "Dein Nest ist voll (höchstens %d Eier)" % DW.EGG_MAX
	if not P.pay(DG.TRADE_EGG):
		return P.missing_text(DG.TRADE_EGG)
	WS.add_egg("tausch", "")
	Story.st().egg_week = int(P.d.week.number)
	Sfx.play("egg_found", -3.0)
	P.mark()
	return ""


func build() -> Control:
	var v := UI.vbox(12)
	var r: Dictionary = DG.RESCUES.haendlerin
	var talk := UI.text("„%s“" % String(DG.FIG_LINES.haendlerin[P.day_index() % DG.FIG_LINES.haendlerin.size()]), 23, UI.WHITE, 820)
	v.add_child(UI.card(UI.hbox(16, [UI.hero_pic("haendlerin", 120.0), UI.vbox(4, [UI.label("%s · %s" % [String(r.name), String(r.title)], 28, UI.GOLD), talk,
		UI.label("Neue Angebote jeden Tag. Jedes Angebot nur ein paar Mal.", 19, UI.TEXT, false)])]), Color("3A2A1C"), 14, Color("E07A2E")))
	if not Story.rescued("haendlerin"):
		v.add_child(S.hint("Rosa ist noch nicht gerettet. Sie steckt im Lager der Waschbär-Diebe in der Staubebene.", 24, UI.ORANGE))
		return v
	var grid := UI.grid(2, 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in offers():
		var t: Dictionary = DG.TRADES[i]
		var n := left(i)
		var arrow := UI.label("→", 34, UI.GOLD)
		var row := UI.hbox(12, [UI.cost_row(t.give, 26), arrow, UI.cost_row(t.get, 26, false), UI.spacer(true)])
		var b := UI.button("Tauschen", S.act(func(): S.say(trade(i), "Getauscht!")), "green" if n > 0 and P.can_pay(t.give) else "dark", 22, "ui_trade")
		b.custom_minimum_size = Vector2(200, 66)
		UI.disable(b, n <= 0)
		row.add_child(b)
		var col := UI.vbox(4, [row, UI.label("Heute noch %d×" % n if n > 0 else "Für heute ausverkauft", 18, UI.TEXT if n > 0 else UI.GREY, false)])
		var c := UI.card(col, UI.NAVY_L, 14)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(c)
	v.add_child(grid)
	# Wochenangebot: Begleiter-Ei
	var ready := egg_ready()
	var eb := UI.button("Kaufen", S.act(func(): S.say(buy_egg(), "Ein Ei! Es liegt jetzt in deinem Nest.")), "gold" if ready else "dark", 22, "p_egg_nest")
	eb.custom_minimum_size = Vector2(200, 66)
	UI.disable(eb, not ready)
	var erow := UI.hbox(14, [UI.pic("p_egg_nest", 70.0, "ui_heart"), UI.vbox(2, [UI.label("Angebot der Woche: Begleiter-Ei", 25, UI.GOLD),
		UI.label("Was drin ist? Rosa weiß es auch nicht." if ready else "Nächste Woche gibt es ein neues Ei.", 19, UI.TEXT, false)]), UI.spacer(true), UI.cost_row(DG.TRADE_EGG, 24), eb])
	v.add_child(UI.card(erow, Color("2A3A1C"), 14, UI.GOLD if ready else Color(0, 0, 0, 0)))
	return v
