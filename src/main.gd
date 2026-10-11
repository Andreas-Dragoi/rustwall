extends Node
## Einstieg: hält die laufende Welt (Hauptbasis oder Expedition), das HUD und die Menü-Bildschirme
## und wechselt zwischen ihnen.

const BaseWorld = preload("res://src/base_world.gd")
const Expedition = preload("res://src/expedition.gd")
const Hud = preload("res://src/hud.gd")
const Screens = preload("res://src/screens.gd")
const TouchPad = preload("res://src/touch_pad.gd")
const Tests = preload("res://src/tests.gd")
const Admin = preload("res://src/admin.gd")
const MainMenu = preload("res://src/main_menu.gd")

var world: Node3D
var hud: CanvasLayer
var screens: CanvasLayer
var pad: Control
var _fade: ColorRect
var _tests: Node
var admin: CanvasLayer
var menu: CanvasLayer


func _ready() -> void:
	G.main = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	G.apply_quality()
	get_viewport().size_changed.connect(G.apply_quality)
	hud = Hud.new()
	add_child(hud)
	G.hud = hud
	var pl := CanvasLayer.new()
	pl.layer = 9
	add_child(pl)
	pad = TouchPad.new()
	pl.add_child(pad)
	screens = Screens.new()
	add_child(screens)
	screens.expedition_requested.connect(start_expedition)
	screens.closed.connect(_on_screen_closed)
	admin = Admin.new()
	add_child(admin)
	menu = MainMenu.new()
	add_child(menu)
	menu.visible = false
	var fl := CanvasLayer.new()
	fl.layer = 30
	add_child(fl)
	_fade = ColorRect.new()
	_fade.color = Color("0A1B30")
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(_fade)
	G.input_mode_changed.connect(func(): hud._rebuild())
	if G.autotest != "" or G.selftest or G.shots_dir != "" or G.arg("setup") != "":
		_tests = Tests.new()
		add_child(_tests)
		_tests.prepare()
	if world == null:
		goto_base()
	if _tests:
		_tests.begin()
	elif G.arg("menu") != "0":
		menu.show_menu()
	if G.arg("memdbg") != "":
		_memdbg()


## Testhilfe: Speicherverbrauch ausgeben (--memdbg=1)
func _memdbg() -> void:
	for i in 6:
		await get_tree().create_timer(5.0).timeout
		print("MEM peak=%.0fMB static=%.0fMB vid=%.0fMB tex=%.0fMB buf=%.0fMB objs=%d res=%d" % [OS.get_static_memory_peak_usage() / 1048576.0, OS.get_static_memory_usage() / 1048576.0,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)])
	if G.arg("memdbg") == "quit":
		get_tree().quit()


## Zurück ins Hauptmenü (aus den Optionen). Eine laufende Expedition oder Flut wird vorher beendet.
func open_menu() -> void:
	screens.close()
	if world == null or world.mode != "peace":
		goto_base()
	get_tree().paused = false
	menu.show_menu()


func ui_blocked() -> bool:
	return screens.is_open() or hud.modal_open()


func pointer_over_ui() -> bool:
	var vp := get_viewport()
	return vp.gui_get_hovered_control() != null or pad.over_button(vp.get_mouse_position())


## Liegt an dieser Stelle ein Bedienelement? (damit der Stick nicht unter Knöpfen startet)
func touch_on_ui(p: Vector2) -> bool:
	return _hit(hud.root, p)


func _hit(c: Control, p: Vector2) -> bool:
	if not c.visible:
		return false
	if c.mouse_filter == Control.MOUSE_FILTER_STOP and c.get_global_rect().has_point(p):
		return true
	for ch in c.get_children():
		if ch is Control and _hit(ch, p):
			return true
	return false


func _on_screen_closed() -> void:
	if menu != null and bool(get_meta("menu_open", false)) and not menu.visible:
		menu.visible = true                  # aus dem Hauptmenü geöffnet: zurück ins Menü
		return
	# Einstellungen aus dem Pausenmenü: danach weiterspielen
	if get_tree().paused and not hud.modal_open():
		get_tree().paused = false
	if world != null and world.mode == "peace":
		hud._rebuild()
		if world.hero != null and world.hero.key != String(P.d.hero_sel):
			reload_hero()


## Tauscht den Helden in der Basis aus (anderer Held gewählt, neue Werte).
func reload_hero() -> void:
	if world == null or world.mode != "peace" or world.hero == null:
		return
	var p: Vector2 = world.hero.pos2()
	world.hero.queue_free()
	world.spawn_hero(String(P.d.hero_sel), p)


func _swap(w: Node3D) -> void:
	get_tree().paused = false
	pad.reset()
	if world != null:
		world.leave()
		remove_child(world)
		world.queue_free()
	world = w
	add_child(w)
	move_child(w, 0)
	hud.set_world(w)
	_fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.45)


func goto_base(open_screen := "") -> void:
	_swap(BaseWorld.new())
	if open_screen != "":
		screens.open(open_screen)


func start_expedition(area: int, mission: String, diff: int) -> void:
	var e := Expedition.new()
	e.init(area, mission, diff)
	_swap(e)
	P.toast.emit("%s: %s" % [D_name(area), P.D.MISSIONS[e.mission].text])


func D_name(area: int) -> String:
	return P.D.AREAS[area].name
