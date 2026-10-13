extends Node
## V6 Paket M – Server-Anbindung der Spielmodi (Knoten "Modi" unter dem Netz-Knoten, angelegt von Modi.net_node()).
## Serverfunktionen (server/mock_server.py und server/modules/src/main.ts):
##   rw_modi_score {board, score}  -> {ok, best}                         Wochenwert (Turm: Summe der besten Läufe, Überleben: bester Lauf)
##   rw_modi_board {board}         -> {entries[], rank, week}            wöchentliche Rangliste (Montag 0:00 UTC zurückgesetzt)
##   rw_raid_hit   {dmg}           -> {hp, dmg, members[], week}         Clan-Raid: Schaden eintragen (3 Angriffe je Tag, Server prüft)
##   rw_raid_get   {}              -> {hp, dmg, members[], week}         Clan-Raid: Stand des eigenen Clans
## Ohne Verbindung rechnet src/modi.gd alles selbst (simulierte Ranglisten und Clanmitglieder).

const Modi = preload("res://src/modi.gd")

var busy := false
var last_ok := 0.0


func _net() -> Node:
	return get_parent()


func _srv() -> Dictionary:
	return Modi.st().srv


## Wochenwerte schicken, die der Server noch nicht kennt.
func push() -> void:
	if not _net().online():
		return
	var t := Modi.tower()
	var ts := Modi.tower_week_score()
	if ts > int(t.sent):
		var r: Dictionary = await _net().rpc_call("rw_modi_score", {"board": "tower", "score": ts})
		if r.ok:
			t.sent = ts
	var s := Modi.surv()
	if int(s.week_best) > int(s.sent):
		var r2: Dictionary = await _net().rpc_call("rw_modi_score", {"board": "surv", "score": int(s.week_best)})
		if r2.ok:
			s.sent = int(s.week_best)
	P.mark()


## Ranglisten und Raid-Stand holen (beim Öffnen des Bildschirms „Modi“).
func pull() -> void:
	if busy or not _net().online():
		return
	busy = true
	await push()
	for kind in ["tower", "surv"]:
		var r: Dictionary = await _net().rpc_call("rw_modi_board", {"board": kind})
		if r.ok and r.data.get("entries") is Array:
			_srv()[kind] = {"week": int(r.data.get("week", Modi.week())), "entries": r.data.entries, "rank": int(r.data.get("rank", 0)), "t": P.now()}
	if Modi.has_clan():
		var r3: Dictionary = await _net().rpc_call("rw_raid_get", {})
		if r3.ok:
			_apply_raid(r3.data)
	last_ok = P.now()
	busy = false
	P.changed.emit()


func raid_hit(dmg: int) -> void:
	if dmg <= 0 or not _net().online():
		return
	var r: Dictionary = await _net().rpc_call("rw_raid_hit", {"dmg": dmg})
	if r.ok:
		_apply_raid(r.data)


func _apply_raid(d: Dictionary) -> void:
	if not d.has("hp"):
		return
	_srv()["raid"] = {"week": int(d.get("week", Modi.week())), "hp": int(d.hp), "dmg": int(d.get("dmg", 0)), "members": d.get("members", []), "t": P.now()}
	P.mark()
