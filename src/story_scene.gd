extends CanvasLayer
## V6 Paket E – Zwischenszene: Texttafeln mit schwarzen Balken wie das Intro (main_menu.gd), darunter die Bühne des Gebiets
## (story_stage.gd, eigene 3D-Welt in einem SubViewport) mit Kamerafahrt und Figuren.
## Tippen = nächste Tafel, „Überspringen ›“ / Esc / Leertaste = Szene beenden. Das Spiel ist solange angehalten.
## Start über Story.play(id, on_done, replay).

const D = preload("res://src/data.gd")
const DG = preload("res://src/data_geschichte.gd")
const UI = preload("res://src/ui.gd")
const Stage = preload("res://src/story_stage.gd")
const Story = preload("res://src/story.gd")

signal finished(id: String)

var id := ""
var def: Dictionary = {}
var stage: Node3D
var panel := -1
var _t := 0.0
var _dur := 4.0
var _bars: Array = []
var _big: Label
var _small: Label
var _dots: HBoxContainer
var _root: Control
var _vpc: SubViewportContainer
var _on_done := Callable()
var _replay := false
var _was_paused := false
var _world_vis := true
var _mood := ""
var _ending := -1.0
var _fade: ColorRect
var _tap_t := 0.0
var done := false
var auto_t := 0.0                    # Tests: Sekunden je Tafel erzwingen (0 = normal)
var _hold := false                   # Bilder: auf einer Tafel stehen bleiben


func _init() -> void:
	name = "StoryScene"
	layer = 26
	process_mode = Node.PROCESS_MODE_ALWAYS


func start(scene_id: String, on_done := Callable(), replay := false) -> void:
	id = scene_id
	def = DG.SCENES[id]
	_on_done = on_done
	_replay = replay
	_was_paused = get_tree().paused
	get_tree().paused = true
	if G.main != null and G.main.world != null:
		_world_vis = G.main.world.visible
		G.main.world.visible = false            # die Welt dahinter muss nicht gezeichnet werden
	_mood = String(Music.get("_mood")) if Music.get("_mood") != null else ""
	Music.set_mood("menu")
	_build()
	Sfx.play("story_open", -4.0)
	if not replay:
		Story.mark_seen(id)
	_next()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UI.theme()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_input)
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Color("0A1B30")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)
	_vpc = SubViewportContainer.new()
	_vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vpc.stretch = true
	_vpc.stretch_shrink = 2 if G.web_mobile() else 1
	_vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_vpc)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED if G.web_mobile() else Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vpc.add_child(vp)
	stage = Stage.new()
	vp.add_child(stage)
	stage.build(int(def.area), def.cast)
	# schwarze Balken oben und unten
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 1.0
		bar.anchor_bottom = 0.0 if top else 1.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(bar)
		_bars.append(bar)
	# Titel der Szene oben links
	var tag := UI.label("%s · %s" % [_chapter_name(), String(def.title)], 24, UI.GOLD)
	tag.add_theme_constant_override("outline_size", 8)
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	tag.position = Vector2(40, 34)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(tag)
	# Text unten
	var box := UI.vbox(8)
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 60
	box.offset_right = -60
	box.offset_top = -300
	box.offset_bottom = -126
	box.alignment = BoxContainer.ALIGNMENT_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big = UI.label("", 46, UI.WHITE)
	_small = UI.label("", 28, UI.GOLD, false)
	for l in [_big, _small]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_constant_override("outline_size", 12)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.88))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
	_root.add_child(box)
	# Fortschritt (Punkte) und Hinweis unten rechts
	_dots = UI.hbox(8)
	_dots.anchor_left = 0.5
	_dots.anchor_right = 0.5
	_dots.anchor_top = 1.0
	_dots.anchor_bottom = 1.0
	_dots.offset_left = -120
	_dots.offset_right = 120
	_dots.offset_top = -86
	_dots.offset_bottom = -66
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in (def.panels as Array).size():
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(18, 8)
		d.color = Color(1, 1, 1, 0.3)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dots.add_child(d)
	_root.add_child(_dots)
	var hint := UI.label("Tippen: weiter ›", 20, Color(1, 1, 1, 0.65), false)
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -300
	hint.offset_right = -40
	hint.offset_top = -92
	hint.offset_bottom = -60
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hint)
	var skip := UI.button("Überspringen ›", _skip, "dark", 24)
	skip.name = "Skip"
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.offset_left = -300
	skip.offset_right = -40
	skip.offset_top = 30
	skip.offset_bottom = 100
	_root.add_child(skip)
	_fade = ColorRect.new()
	_fade.color = Color(0.04, 0.1, 0.19, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.5)


func _chapter_name() -> String:
	match String(def.kind):
		"end":
			return "Abschluss"
	var a := int(def.area)
	return "Kapitel %d" % (a + 1)


func _next() -> void:
	panel += 1
	var panels: Array = def.panels
	if panel >= panels.size():
		_end()
		return
	var pd: Array = panels[panel]
	_big.text = String(pd[0])
	_small.text = String(pd[1])
	_big.modulate.a = 0.0
	_small.modulate.a = 0.0
	stage.shot(String(pd[2]), panel == 0)
	var acts: Dictionary = pd[3] if pd.size() > 3 else {}
	for r in acts:
		stage.act(String(r), String(acts[r]))
	_t = 0.0
	_tap_t = 0.0
	_dur = clampf(DG.PANEL_MIN + DG.PANEL_PER_CHAR * (String(pd[0]).length() + String(pd[1]).length()), DG.PANEL_MIN, DG.PANEL_MAX)
	if auto_t > 0.0:
		_dur = auto_t
	for i in _dots.get_child_count():
		(_dots.get_child(i) as ColorRect).color = UI.GOLD if i == panel else Color(1, 1, 1, 0.3 if i > panel else 0.7)
	if panel > 0:
		Sfx.play("story_page", -9.0)


func _process(dt: float) -> void:
	dt = minf(dt / maxf(Engine.time_scale, 0.01), 0.25)     # echte Zeit (Spieltempo egal); nach dem Aufbau nicht springen
	if done:
		return
	if stage != null:
		stage.tick(dt)
	if _ending >= 0.0:
		_ending += dt
		_fade.color.a = clampf(_ending / 0.45, 0.0, 1.0)
		if _ending >= 0.5:
			_finish()
		return
	_t += dt
	_tap_t += dt
	var bh := minf((_t + (0.0 if panel == 0 else 1.0)) * 400.0, 110.0)
	(_bars[0] as ColorRect).offset_bottom = bh
	(_bars[1] as ColorRect).offset_top = -bh
	var k := _t / _dur if not _hold else 0.5
	_big.modulate.a = clampf(minf(k * 5.0, (1.0 - k) * 8.0 + 0.2), 0.0, 1.0)
	_small.modulate.a = clampf(minf(k * 5.0 - 0.5, (1.0 - k) * 8.0 + 0.2), 0.0, 1.0)
	if _t >= _dur:
		_next()


func _on_input(ev: InputEvent) -> void:
	if done or _ending >= 0.0:
		return
	var tap: bool = (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed)
	if tap and _tap_t > 0.5:
		_next()
		_root.accept_event()


func _unhandled_input(ev: InputEvent) -> void:
	if done or not (ev is InputEventKey and ev.pressed):
		return
	match ev.keycode:
		KEY_ESCAPE, KEY_SPACE:
			_skip()
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_RIGHT, KEY_KP_ENTER:
			if _tap_t > 0.3:
				_next()
			get_viewport().set_input_as_handled()


func _skip() -> void:
	if _ending < 0.0 and not done:
		Sfx.play("story_page", -9.0, 0.8)
		_end()


func _end() -> void:
	if _ending < 0.0:
		_ending = 0.0


## Bilder und Tests: zu Tafel n springen und dort stehen bleiben.
func hold_panel(n: int) -> void:
	auto_t = 9999.0
	while panel < n and panel < (def.panels as Array).size() - 1:
		_next()
	_dur = 9999.0
	_t = 1.0
	_hold = true


## Szene sofort beenden (Tests, Weltwechsel).
func stop() -> void:
	_finish()


func _finish() -> void:
	if done:
		return
	done = true
	get_tree().paused = _was_paused
	if G.main != null and G.main.world != null and is_instance_valid(G.main.world):
		G.main.world.visible = _world_vis
	if _mood != "":
		Music.set_mood(_mood)
	finished.emit(id)
	var cb := _on_done
	name = "StorySceneDone"                  # Name frei machen: eine Folgeszene heißt wieder „StoryScene“ (Story.playing)
	queue_free()
	if cb.is_valid():
		cb.call()
