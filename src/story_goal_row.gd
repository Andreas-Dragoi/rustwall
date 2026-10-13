extends VBoxContainer
## V6 Paket E – zweite Zeile der Ziele-Leiste (hud_guide.gd GoalBox): das nächste Ziel der Geschichte mit eigener Belohnung.
## Ist das Ziel erreicht, erscheint „Abholen“; ist das Gebiet noch gesperrt, steht der Grund darunter. Antippen der Zeile
## öffnet die Chronik.

const UIx = preload("res://src/ui.gd")
const Gd = preload("res://src/guide.gd")
const Story = preload("res://src/story.gd")

var _sig := "-"
var _head: Label
var _txt: Label
var _lock: Label
var _btn: Button
var _t := 0.0


func _init() -> void:
	name = "StoryGoal"
	add_theme_constant_override("separation", 2)
	var sep := ColorRect.new()
	sep.color = Color(UIx.GOLD, 0.35)
	sep.custom_minimum_size = Vector2(0, 2)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sep)
	_head = UIx.label("", 17, Color("F2B05A"))
	_txt = UIx.label("", 20)
	_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_txt.custom_minimum_size = Vector2(300, 0)
	_lock = UIx.label("", 17, UIx.ORANGE, false)
	_lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lock.custom_minimum_size = Vector2(300, 0)
	var chron := UIx.button("", func(): G.main.screens.open("chronik"), "dark", 18, "ui_chronik")
	chron.custom_minimum_size = Vector2(52, 44)
	chron.tooltip_text = "Chronik"
	var top := UIx.hbox(6, [UIx.pic("ui_chronik", 26.0, "ui_quest"), _head, UIx.spacer(true), chron])
	add_child(top)
	add_child(_txt)
	add_child(_lock)
	_btn = UIx.button("Abholen", _claim, "gold", 20, "ui_check")
	_btn.custom_minimum_size = Vector2(0, 54)
	_btn.visible = false
	add_child(_btn)


func update() -> void:
	var g: Dictionary = Gd.story_goal()
	if g.is_empty():
		visible = false
		return
	var ready := Gd.story_goal_ready()
	var sig := "%d|%d|%s" % [int(Story.st().get("goal", 0)), 1 if ready else 0, TranslationServer.get_locale()]
	if sig == _sig:
		if ready:
			_t += 0.25
			_btn.modulate = Color(1, 1, 1).lerp(Color(1.3, 1.25, 1.0), 0.5 + 0.5 * sin(_t * 6.0))
		return
	_sig = sig
	visible = true
	_head.text = "Geschichte · Kapitel %d" % Story.chapter()
	_txt.text = Gd.story_goal_text()
	var lk := Story.goal_lock(g)
	_lock.text = lk
	_lock.visible = lk != "" and not ready
	_btn.visible = ready
	if ready:
		UIx.pulse(_btn, 1.06)


func _claim() -> void:
	var rw: Dictionary = Gd.story_goal_claim()
	if rw.is_empty():
		return
	P.toast.emit("Geschichte: Ziel geschafft! " + Gd.reward_text(rw))
	UIx.sfx("ui_claim", "", -4.0)
	_sig = "-"
	update()
