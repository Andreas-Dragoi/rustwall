extends RefCounted
## Bildschirm "Erfolge": Ziele mit mehreren Schwellen. Jede erreichte Schwelle bringt einmal Juwelen.

const D = preload("res://src/data.gd")
const UI = preload("res://src/ui.gd")

var S


func build() -> Control:
	var list: Array = P.achievements()
	# abholbare zuerst, erledigte zuletzt
	list.sort_custom(func(a, b):
		var ka := 0 if a.ready else (2 if a.done else 1)
		var kb := 0 if b.ready else (2 if b.done else 1)
		return ka < kb)
	var total := 0
	var got := 0
	for a in list:
		total += (a.def.tiers as Array).size()
		got += int(a.tier)
	var v := UI.vbox(12)
	var pb := UI.bar(float(got) / maxf(1.0, total), UI.GOLD, Vector2(360, 24))
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_child(UI.hbox(14, [UI.pic("ui_trophy", 52.0), S.head("%d von %d Erfolgen" % [got, total], 32), pb, UI.spacer(true), UI.pill(UI.hbox(8, [UI.pic("res_gems", 34.0), UI.label(UI.fmt(P.gems()), 28, Color("9FDCFF"))]))]))
	var g := UI.grid(2, 12)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for a in list:
		g.add_child(_row(a))
	v.add_child(S.scroll(g, "list"))
	return v


func _row(a: Dictionary) -> Control:
	var def: Dictionary = a.def
	var tiers: Array = def.tiers
	var done: bool = a.done
	var ready: bool = a.ready
	var nm := UI.label(String(def.name), 27, UI.GOLD if not done else UI.GREEN)
	var goal := String(def.text) % UI.fmt(float(a.need))
	var t := UI.label("Alle Stufen geschafft" if done else goal, 21, UI.TEXT, false)
	t.clip_text = true
	var bar := UI.bar(1.0 if done else clampf(float(a.value) / maxf(1.0, float(a.need)), 0.0, 1.0), UI.GREEN if (ready or done) else D.C_BAR_BLUE, Vector2(160, 18))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pl := UI.label("%s / %s" % [UI.fmt(float(mini(int(a.value), int(a.need)))), UI.fmt(float(a.need))], 19, UI.TEXT, false)
	var mid := UI.vbox(2, [UI.hbox(10, [nm, UI.pips(int(a.tier), tiers.size(), UI.GOLD, 16.0)]), t, UI.hbox(10, [bar, pl])])
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right: Control
	if done:
		right = UI.pic("ui_check", 52.0, "", UI.GREEN)
	else:
		var key := String(def.key)
		var b := UI.button(str(int(a.gems)), S.act(func():
			var n: int = P.claim_achievement(key)
			if n > 0:
				S.toast("+%d Juwelen" % n)), "green" if ready else "dark", 26, "res_gems")
		b.custom_minimum_size = Vector2(150, 70)
		UI.disable(b, not ready)
		right = b
	var c := UI.card(UI.hbox(14, [UI.pic("ui_trophy", 56.0, "", UI.GOLD if (ready or done) else UI.GREY), mid, right]), Color("1F5A34") if ready else UI.NAVY_L, 12, UI.GREEN if ready else Color(0, 0, 0, 0))
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c
