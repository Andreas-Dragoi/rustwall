extends RefCounted
## Paket Q (Kapitel 7.3): Untertitel für wichtige Töne. Sfx.play/play_at melden jeden Ton über heard();
## steht er in TEXTS, erscheint unten in der Bildmitte eine kurze Zeile – auch bei stummgeschaltetem Ton.
## Töne mit Ort (Explosionen, Einschläge) nur in der Nähe des Helden, mit Richtungspfeil.

const TEXTS := {
	"flood_alarm": "Alarm: Die Flut kommt!", "flood_horn": "Horn: Die Flut beginnt", "siege_horn": "Horn: Großangriff",
	"raid_horn": "Horn: Angriff", "worldboss_horn": "Horn: Der Weltboss greift an", "wave": "Signal: Neue Welle",
	"boss_arrive": "Grollen: Ein Boss naht", "boss_intro": "Ein Boss betritt das Feld", "boss_roar": "Brüllen: Boss",
	"boss_rage": "Wutschrei: Der Boss tobt", "boss_phase": "Der Boss wechselt die Taktik", "boss_summon": "Ruf: Der Boss holt Hilfe",
	"boss_slam": "Stampfen: Boss", "miniboss_arrive": "Grollen: Ein Miniboss naht", "boss_defeat": "Der Boss ist besiegt",
	"explosion_small": "Explosion", "explosion": "Explosion", "explosion_big": "Große Explosion", "ev_lavabomb_impact": "Einschlag: Lavabombe",
	"ev_lavabomb_fall": "Pfeifen: Lavabombe im Anflug", "ev_eruption": "Ausbruch: Der Vulkan spuckt", "lava_burst": "Zischen: Lava bricht hervor",
	"thunder": "Donner", "alarm": "Alarm", "bunker_hit": "Der Bunker wird angegriffen",
}
const I18N = preload("res://src/i18n.gd")
const NEAR := 16.0                 # Meter: Töne mit Ort nur so nah am Helden
const GAP := 1.2                   # gleicher Ton frühestens nach so vielen Sekunden wieder
const SHOW := 2.6                  # Sekunden sichtbar
const MAX_LINES := 3

static var enabled := false
static var shown := 0              # für Tests: so viele Untertitel wurden gezeigt
static var last_text := ""
static var _last := {}
static var _layer: CanvasLayer = null
static var _box: VBoxContainer = null


## Aus Sfx: ein Ton wurde abgespielt (pos = Vector3.INF ohne Ort).
static func heard(sound: String, pos: Vector3 = Vector3.INF) -> void:
	if not enabled or not TEXTS.has(sound):
		return
	var now := Time.get_ticks_msec() * 0.001
	if now - float(_last.get(sound, -100.0)) < GAP:
		return
	var arrow := ""
	if pos != Vector3.INF:
		var pl = G.player
		if pl == null or not is_instance_valid(pl):
			return
		var d := Vector2(pos.x - pl.global_position.x, pos.z - pl.global_position.z)
		if d.length() > NEAR:
			return
		arrow = _arrow(pos)
	_last[sound] = now
	show_text(String(TEXTS[sound]), arrow)


## Richtungspfeil vom Helden zum Ort (in Bildschirmrichtung).
static func _arrow(pos: Vector3) -> String:
	var cam := G.main.get_viewport().get_camera_3d() if G.main != null else null
	var pl = G.player
	if cam == null or pl == null:
		return ""
	var a: Vector2 = cam.unproject_position(pos)
	var b: Vector2 = cam.unproject_position(pl.global_position)
	var v := a - b
	if v.length() < 60.0:
		return "●"
	var ang := v.angle()
	var arrows := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
	var i := int(round(ang / (PI / 4.0))) % 8
	return arrows[(i + 8) % 8]


static func show_text(text: String, arrow := "") -> void:
	shown += 1
	last_text = text
	if G.main == null or not is_instance_valid(G.main):
		return
	if _layer == null or not is_instance_valid(_layer):
		_layer = CanvasLayer.new()
		_layer.layer = 28
		_layer.name = "Untertitel"
		var cc := MarginContainer.new()
		cc.set_anchors_preset(Control.PRESET_FULL_RECT)
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_theme_constant_override("margin_bottom", 170)
		cc.theme = preload("res://src/ui.gd").theme()          # Spielschrift
		_box = VBoxContainer.new()
		_box.alignment = BoxContainer.ALIGNMENT_END
		_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.add_theme_constant_override("separation", 6)
		cc.add_child(_box)
		_layer.add_child(cc)
		G.main.add_child(_layer)
	while _box.get_child_count() >= MAX_LINES:
		var old := _box.get_child(0)
		_box.remove_child(old)
		old.queue_free()
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.05, 0.1, 0.78)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = text if arrow == "" else "%s  %s" % [arrow, I18N.t(text)]
	if arrow != "":
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED     # schon übersetzt (Pfeil davor)
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	p.add_child(l)
	_box.add_child(p)
	var tw := p.create_tween()
	tw.tween_interval(SHOW)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)

