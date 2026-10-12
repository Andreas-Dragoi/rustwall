extends RefCounted
## Bildschirm "Tagebuch" (Paket Welt): je Gebiet die gefundenen Tagebuchseiten, das Wahrzeichen, das Werkzeug der
## gebietseigenen Quelle und die Nebenquest. Geöffnet von der Weltkarte (Expedition) oder mit arg {"area": n}.

const D = preload("res://src/data.gd")
const DW = preload("res://src/data_welt.gd")
const WS = preload("res://src/welt_state.gd")
const UI = preload("res://src/ui.gd")

const HINT := ["liegt am Wahrzeichen des Gebiets", "liegt irgendwo im Gebiet (Phase Erkunden)", "liegt irgendwo im Gebiet (Phase Erkunden)", "gibt es als Lohn der Nebenquest"]

var S


func build() -> Control:
	if not S.st.has("tab"):
		S.st["tab"] = int(S.st.get("area", 0))
	WS.st().new_pages = 0
	var area := clampi(int(S.st.tab), 0, D.AREAS.size() - 1)
	var ak := String(D.AREAS[area].key)
	var v := UI.vbox(12)
	var names: Array = []
	var icons: Array = []
	for a in D.AREAS:
		names.append("%s %d/%d" % [String(a.name), WS.pages(String(a.key)).size(), DW.JOURNAL[String(a.key)].size()])
		icons.append("area_" + String(a.key))
	var head := UI.hbox(14, [UI.pic("p_journal", 52.0, "ui_quest"), S.head("Tagebuch – %d von %d Seiten" % [WS.page_total(), WS.page_max()], 30)])
	v.add_child(head)
	v.add_child(S.tabs(names, "tab", 21, icons))
	var body := UI.vbox(12)
	# ---- Wahrzeichen, Werkzeug, Nebenquest
	var facts := UI.flow(10)
	var lm: Dictionary = DW.LANDMARKS[ak]
	var seen := WS.landmark_seen(ak)
	facts.add_child(UI.pill(UI.hbox(8, [UI.pic(String(lm.model), 40.0, "ui_map"), UI.label("Wahrzeichen: %s" % (String(lm.name) if seen else "noch nicht entdeckt"), 21, UI.GOLD if seen else UI.GREY)])))
	var tk := WS.tool_for_area(area)
	if tk != "":
		var td: Dictionary = DW.TOOLS[tk]
		var has := WS.has_tool(tk)
		facts.add_child(UI.pill(UI.hbox(8, [UI.pic(String(td.icon), 40.0, "ui_wrench"), UI.label("%s%s" % [String(td.name), " ✓" if has else " – Karawane oder Nebenquest"], 21, UI.GREEN if has else UI.TEXT)])))
	var qd: Dictionary = DW.QUESTS.get(ak, {})
	if not qd.is_empty():
		var q := WS.quest(ak)
		var qt: String = ["Nebenquest: %s (%s wartet in der Landezone)" % [String(qd.title), String(qd.giver)], "Nebenquest: %s – %d/%d %s" % [String(qd.title), int(q.got), int(qd.n), String(qd.item)], "Nebenquest: %s ✓" % String(qd.title)][clampi(int(q.state), 0, 2)]
		facts.add_child(UI.pill(UI.hbox(8, [UI.pic("ui_quest", 36.0), UI.label(qt, 21, UI.GREEN if int(q.state) == 2 else UI.TEXT)])))
	body.add_child(facts)
	# ---- Seiten
	var src: Array = DW.JOURNAL[ak]
	for i in src.size():
		var got := WS.has_page(ak, i)
		var title := UI.label(String(src[i][0]) if got else "Seite %d – noch nicht gefunden" % (i + 1), 26, UI.GOLD if got else UI.GREY)
		var txt := UI.text(String(src[i][1]) if got else "Diese Seite %s." % HINT[i], 22, UI.WHITE if got else UI.GREY, 900)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card := UI.card(UI.hbox(14, [UI.pic("p_journal" if got else "ui_lock", 54.0, "ui_quest", UI.WHITE if got else UI.GREY), UI.vbox(4, [title, txt])]), Color("3A3324") if got else UI.NAVY_L, 14, Color("C9A86A") if got else Color(0, 0, 0, 0))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(card)
	v.add_child(S.scroll(body, "pages"))
	return v
