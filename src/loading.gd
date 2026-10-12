extends CanvasLayer
## Ladebildschirm mit Tipps beim Wechsel zwischen Basis und Expedition (Paket F, Kapitel 7.3).
## main.gd ruft vor dem Aufbau der neuen Welt show_for() auf (wartet zwei Bilder, damit der Bildschirm zu sehen ist)
## und danach done() (blendet nach einer Mindestzeit aus). In Tests wird nichts gezeigt.

const D = preload("res://src/data.gd")
const DF = preload("res://src/data_fuehrung.gd")
const UI = preload("res://src/ui.gd")
const ScreenFit = preload("res://src/screen_fit.gd")

var _root: Control
var _shown_at := 0
var _gear: Control
var _tip_i := -1


func _ready() -> void:
	layer = 29
	process_mode = Node.PROCESS_MODE_ALWAYS


func wanted() -> bool:
	return (G.autotest == "" and not G.selftest and G.shots_dir == "") or G.arg("loading") != ""


## Zeigt den Ladebildschirm. dest: "base" oder "exp"; area: Gebiet der Expedition.
func show_for(dest: String, area := 0) -> void:
	if not wanted():
		return
	_build(dest, area)
	_shown_at = Time.get_ticks_msec()
	Sfx.play("loading_whoosh", -8.0)
	await get_tree().process_frame
	await get_tree().process_frame


## Nach dem Aufbau: ausblenden (frühestens nach DF.LOAD_MIN_TIME).
func done() -> void:
	if _root == null:
		return
	var r := _root
	_root = null
	var wait := maxf(0.0, DF.LOAD_MIN_TIME - (Time.get_ticks_msec() - _shown_at) / 1000.0)
	var tw := r.create_tween()
	tw.tween_interval(wait)
	tw.tween_property(r, "modulate:a", 0.0, 0.35)
	tw.tween_callback(r.queue_free)


func _build(dest: String, area: int) -> void:
	if _root != null:
		_root.queue_free()
	_root = Control.new()
	_root.theme = UI.theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var g := Gradient.new()
	g.set_color(0, UI.BG_TOP)
	g.set_color(1, UI.BG_BOT)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 8
	gt.height = 128
	gt.fill_to = Vector2(0, 1)
	var bg := TextureRect.new()
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.set_meta("fill_screen", true)
	_root.add_child(bg)
	ScreenFit.fit(_root, ScreenFit.screen_scale())
	var title := "Zurück in die Basis"
	var icon := "b_bunker_1"
	if dest == "exp":
		var a: Dictionary = D.AREAS[clampi(area, 0, D.AREAS.size() - 1)]
		title = "Auf zur Expedition: %s" % String(a.name)
		icon = "area_" + String(a.key)
	var head := UI.label(title, 50, UI.GOLD)
	head.add_theme_constant_override("outline_size", 12)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pic := UI.pic(icon, 180.0, "ui_expedition")
	pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tip_i = (_tip_i + 1 + randi() % 3) % DF.TIPS.size() if _tip_i >= 0 else randi() % DF.TIPS.size()
	var tip_t := String(DF.TIPS[_tip_i])
	if dest == "exp":                     # Paket Z: Gebiete mit eigenen Tipps (Vulkaninsel) zeigen meist einen davon
		var at: Array = preload("res://src/data_welt.gd").AREA_TIPS.get(String(D.AREAS[clampi(area, 0, D.AREAS.size() - 1)].key), [])
		if not at.is_empty() and randi() % 3 != 0:
			tip_t = String(at[randi() % at.size()])
	var tip := UI.text(tip_t, 28, UI.WHITE, 900.0)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tp := UI.panel(UI.vbox(8, [UI.label("Tipp", 26, UI.SKY), tip]), Color(0.07, 0.19, 0.37, 0.94), UI.EDGE, 24, 22)
	tp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_gear = UI.pic("ui_gear", 70.0)
	_gear.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var v := UI.vbox(26, [pic, head, tp, _gear])
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.add_child(v)
	_root.add_child(cc)


func _process(dt: float) -> void:
	if _gear != null and is_instance_valid(_gear):
		_gear.pivot_offset = _gear.size * 0.5
		_gear.rotation += dt * 3.0
