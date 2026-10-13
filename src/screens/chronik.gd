extends RefCounted
## Bildschirm „Chronik“ (V6 Paket E): die Hauptgeschichte zum Nachlesen und Wiederansehen.
##   Reiter „Kapitel“:   Akt und Kapitel, nächstes Story-Ziel (mit Belohnung), Prolog (Intro) und alle Zwischenszenen –
##                       gesehene lassen sich wieder ansehen, ungesehene zeigen, wie man sie freischaltet.
##   Reiter „Gerettete“: Rosa, Professor Moosbach und Knut – wo man sie findet, was sie in der Basis tun.
## Geöffnet aus dem Basismenü (Knopf „Chronik“).

const D = preload("res://src/data.gd")
const DG = preload("res://src/data_geschichte.gd")
const UI = preload("res://src/ui.gd")
const Story = preload("res://src/story.gd")

var S


func setup(_arg) -> void:
	Story.demo()


func build() -> Control:
	var v := UI.vbox(12)
	var head := UI.hbox(14, [UI.pic("ui_chronik", 52.0, "ui_quest"), S.head("Akt %d · Kapitel %d von %d" % [Story.act(), Story.chapter(), D.AREAS.size()], 30), UI.spacer(true),
		UI.label("%d von %d Szenen gesehen" % [_seen_count(), DG.CHRONICLE.size()], 22, UI.TEXT, false)])
	v.add_child(head)
	v.add_child(S.tabs(["Kapitel", "Gerettete %d/%d" % [Story.rescued_list().size(), DG.RESCUE_ORDER.size()]], "tab", 22, ["ui_chronik", "ui_heart"]))
	if int(S.st.get("tab", 0)) == 1:
		v.add_child(S.scroll(_rescued(), "fig"))
	else:
		v.add_child(S.scroll(_chapters(), "chap"))
	return v


func _seen_count() -> int:
	var n := 0
	for e in DG.CHRONICLE:
		if Story.seen(String(e[0])):
			n += 1
	return n


# ----------------------------------------------------------------- Kapitel
func _chapters() -> Control:
	var body := UI.vbox(10)
	body.add_child(_goal_card())
	# Prolog: das Intro aus dem Hauptmenü
	var pro := UI.hbox(14, [_thumb(0, true), UI.vbox(4, [UI.label("Prolog · Die Flut", 26, UI.GOLD), UI.text("Wie alles anfing: der große Regen, die Schleimlinge und dein Bunker.", 21, UI.TEXT, 700)]), UI.spacer(true),
		_btn("Ansehen", func():
			if G.main == null:
				return
			S.close()
			G.main.menu.start_intro())])
	body.add_child(UI.card(pro, UI.NAVY_L, 12))
	for e in DG.CHRONICLE:
		var id := String(e[0])
		if String(e[1]) != "":
			body.add_child(UI.label(String(e[1]), 24, Color("8FB8F0")))
		body.add_child(_scene_card(id))
	return body


func _goal_card() -> Control:
	var g := Story.goal()
	if g.is_empty():
		return UI.card(UI.hbox(12, [UI.pic("ui_trophy", 44.0), UI.label("Die Geschichte ist (vorerst) zu Ende erzählt. Fortsetzung folgt!", 23, UI.GOLD)]), Color("2A4A1C"), 14)
	var ready := Story.goal_done(g)
	var lock := Story.goal_lock(g)
	var col := UI.vbox(4, [UI.label("Nächstes Ziel der Geschichte", 19, UI.SKY), UI.text(String(g.text), 24, UI.WHITE, 640),
		UI.label("Belohnung: " + preload("res://src/guide.gd").reward_text(g.reward), 19, UI.TEXT, false)])
	if lock != "" and not ready:
		col.add_child(UI.label(lock, 19, UI.ORANGE, false))
	var row := UI.hbox(14, [UI.pic("ui_target", 48.0, "", UI.GOLD), col, UI.spacer(true)])
	if ready:
		var b := UI.button("Abholen", S.act(func():
			var rw: Dictionary = Story.goal_claim()
			if not rw.is_empty():
				S.toast("Belohnung: " + preload("res://src/guide.gd").reward_text(rw))), "green", 24, "ui_check")
		b.custom_minimum_size = Vector2(200, 70)
		row.add_child(b)
	return UI.card(row, Color("1F3F6E"), 14, UI.GOLD if ready else UI.EDGE)


func _thumb(area: int, prolog := false) -> Control:
	var ak := String(D.AREAS[clampi(area, 0, D.AREAS.size() - 1)].key)
	var t := TextureRect.new()
	t.texture = UI.tex("scene_" + ak) if UI.has_pic("scene_" + ak) else UI.tex("area_" + ak)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.custom_minimum_size = Vector2(176, 99)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if prolog:
		t.modulate = Color(0.85, 0.95, 1.0)
	return t


func _scene_card(id: String) -> Control:
	var sd: Dictionary = DG.SCENES[id]
	var seen := Story.seen(id) or G.ch("nolimit")          # Admin „keine Grenzen“: alle Szenen ansehen
	var th := _thumb(int(sd.area))
	if not seen:
		th.modulate = Color(0.18, 0.24, 0.36)
	var name_t := String(sd.title) if seen else "???"
	var sub := String(DG.KIND_NAME.get(String(sd.kind), ""))
	var info := UI.vbox(2, [UI.label(name_t, 25, UI.WHITE if seen else UI.GREY), UI.label(sub, 19, UI.SKY if seen else UI.GREY, false)])
	if seen:
		info.add_child(UI.text(String(sd.panels[0][1]), 19, UI.TEXT, 620))
	else:
		info.add_child(UI.label(_unlock_hint(id), 19, UI.ORANGE, false))
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UI.hbox(14, [th, info])
	if seen:
		row.add_child(_btn("Ansehen", func():
			if G.main == null:
				return
			S.close()
			Story.play(id, func(): G.main.screens.open("chronik"), true)))
	else:
		row.add_child(UI.pic("ui_lock", 40.0, "", UI.GREY))
	return UI.card(row, UI.NAVY_L if seen else UI.NAVY_D, 12)


func _unlock_hint(id: String) -> String:
	var sd: Dictionary = DG.SCENES[id]
	var a := int(sd.area)
	match String(sd.kind):
		"in":
			return "Betritt zum ersten Mal: %s" % String(D.AREAS[a].name)
		"boss":
			return "Besiege %s (%s)" % [String(D.BOSSES[int(D.AREAS[a].boss)].name), String(D.AREAS[a].name)]
	return "Besiege %s" % ("den Schleimkönig" if id == "end1" else "Magmafürst Brodel")


func _btn(t: String, cb: Callable) -> Button:
	var b := UI.button(t, cb, "gold", 22, "ui_play")
	b.custom_minimum_size = Vector2(190, 66)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b


# ----------------------------------------------------------------- Gerettete
func _rescued() -> Control:
	var body := UI.vbox(12)
	body.add_child(S.hint("In drei Gebieten wartet jemand auf Rettung. Befreit ziehen sie in deine Basis, haben dort ihren eigenen Tagesablauf und helfen dir.", 21))
	for k in DG.RESCUE_ORDER:
		var r: Dictionary = DG.RESCUES[k]
		var got := Story.rescued(k)
		var pic := UI.hero_pic(k, 150.0)
		if not got:
			pic.modulate = Color(0.25, 0.3, 0.42)
		var col := UI.vbox(4)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UI.label("%s · %s" % [String(r.name), String(r.title)] if got else "%s · ???" % String(r.title), 27, UI.GOLD if got else UI.GREY))
		var where := "%s – %s" % [String(D.AREAS[int(r.area)].name), String(r.event)]
		col.add_child(UI.label(("Gerettet: %s" if got else "Gefangen: %s") % where, 20, UI.GREEN if got else UI.ORANGE, false))
		col.add_child(UI.text(String(r.story) if got else _rescue_hint(k), 21, UI.TEXT, 760))
		col.add_child(UI.pill(UI.hbox(8, [UI.pic("ui_star", 26.0, "", UI.GOLD), UI.label(String(r.unlock), 19, UI.WHITE if got else UI.GREY, false)])))
		if got:
			col.add_child(UI.label(String(r.look), 18, Color("8FB8F0"), false))
		body.add_child(UI.card(UI.hbox(16, [pic, col]), UI.NAVY_L if got else UI.NAVY_D, 14, Color(r.color, 0.8) if got else Color(0, 0, 0, 0)))
	return body


func _rescue_hint(k: String) -> String:
	var r: Dictionary = DG.RESCUES[k]
	var a := int(r.area)
	var t := "Irgendwo in %s (Phase „Erkunden“) – auf der Karte und in der Aufgabenliste." % String(D.AREAS[a].name)
	if not P.area_unlocked(a):
		t += " " + P.area_lock_text(a) + "."
	return t
