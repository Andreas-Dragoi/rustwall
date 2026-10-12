extends Node
## Paket L – Server-Anbindung des Live-Betriebs (Knoten "LiveOps" unter dem Netz-Knoten, angelegt von LO.net_node()).
## Serverfunktionen (server/mock_server.py und server/modules/src/main.ts):
##   rw_liveops      -> {week, event, event_end, season, news[], boss_hp, boss_dmg}   Zeitplan und Nachrichten
##   rw_season_add   {season, add} -> {pts}                                           Pass-Fortschritt am Server
##   rw_season_board {season, pts} -> {entries[], rank}                               Saison-Rangliste
##   rw_boss_hit     {dmg} -> {boss_dmg, boss_hp}                                     Weltboss-Gemeinschaftsschaden
## Ohne Verbindung rechnet src/liveops.gd alles selbst (fester Kalender, simulierte Rangliste und Gemeinschaft).

const LO = preload("res://src/liveops.gd")

var busy := false
var last_ok := 0.0


func _net() -> Node:
	return get_parent()


func pull() -> void:
	if busy or not _net().online():
		return
	busy = true
	var r: Dictionary = await _net().rpc_call("rw_liveops", {})
	if r.ok:
		var d: Dictionary = r.data
		var srv := {"week": int(d.get("week", -1)), "event": String(d.get("event", "")), "t": P.now()}
		if d.get("news") is Array:
			srv["news"] = d.news
		if d.has("boss_dmg"):
			srv["boss_dmg"] = float(d.boss_dmg)
			srv["boss_hp"] = float(d.get("boss_hp", 1.0))
		if d.has("season"):
			srv["season"] = int(d.season)
		LO.st().srv = srv
		last_ok = P.now()
		await push_season()
		await pull_board()
		P.changed.emit()
	busy = false


## Saisonpunkte, die der Server noch nicht kennt, nachreichen.
func push_season() -> void:
	var s: Dictionary = LO.season()
	var delta := int(s.pts) - int(s.get("sent", 0))
	if delta <= 0:
		return
	var r: Dictionary = await _net().rpc_call("rw_season_add", {"season": int(s.n), "add": delta})
	if r.ok:
		s["sent"] = int(s.pts)
		P.mark()


func pull_board() -> void:
	var s: Dictionary = LO.season()
	var r: Dictionary = await _net().rpc_call("rw_season_board", {"season": int(s.n), "pts": int(s.pts)})
	if r.ok and r.data.get("entries") is Array:
		LO.st().srv_board = {"season": int(s.n), "entries": r.data.entries, "rank": int(r.data.get("rank", 0)), "t": P.now()}


func boss_hit(dmg: int) -> void:
	if dmg <= 0 or not _net().online():
		return
	var r: Dictionary = await _net().rpc_call("rw_boss_hit", {"dmg": dmg})
	if r.ok and r.data.has("boss_dmg"):
		var srv: Dictionary = LO.st().srv
		srv["week"] = LO.week_index()
		srv["boss_dmg"] = float(r.data.boss_dmg)
		srv["boss_hp"] = float(r.data.get("boss_hp", 1.0))
