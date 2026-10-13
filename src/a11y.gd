extends RefCounted
## Paket Q (Kapitel 7.3): Barrierefreiheit. Einstellungen gelten für das Gerät (device_cfg), nicht je Stadt.
##  - Farbfilter für Farbfehlsichtigkeit (Rot-Grün: Deuteranopie/Protanopie, Blau-Gelb: Tritanopie). Ein Vollbild-Shader
##    („Daltonisierung“) verschiebt die Farbunterschiede, die das Auge nicht sieht, in sichtbare Kanäle – das wirkt auf alles:
##    Lebensleisten (rot/blau), Elementfarben, Marker, Gut/Schlecht-Farben der Oberfläche, Gegnerfarben.
##  - Untertitel für wichtige Töne (Flut-Alarm, Boss, Explosion in der Nähe mit Richtung) – captions.gd.
##  - Blitze abschwächen: roter Bildschirmblitz bei Treffern und Lichtblitze von Explosionen schwächer.
##  - Textgröße: die vorhandene Oberflächengröße (Paket F, P.d.settings.ui_size) – hier nur mit angeboten.
## Einstieg: apply(main) beim Start und nach jeder Änderung.

const Dev = preload("res://src/device_cfg.gd")

const CB_MODES := [["Aus", 0], ["Rot-Grün (Deuteranopie)", 1], ["Rot-Grün (Protanopie)", 2], ["Blau-Gelb (Tritanopie)", 3]]
const SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform int mode = 1;
uniform float strength = 1.0;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float L = 17.8824 * c.r + 43.5161 * c.g + 4.11935 * c.b;
	float M = 3.45565 * c.r + 27.1554 * c.g + 3.86714 * c.b;
	float S = 0.0299566 * c.r + 0.184309 * c.g + 1.46709 * c.b;
	if (mode == 2) {
		L = 2.02344 * M - 2.52581 * S;
	} else if (mode == 1) {
		M = 0.494207 * L + 1.24827 * S;
	} else {
		S = -0.395913 * L + 0.801109 * M;
	}
	vec3 sim = vec3(0.0809444479 * L - 0.130504409 * M + 0.116721066 * S,
		-0.0102485335 * L + 0.0540193266 * M - 0.113614708 * S,
		-0.000365296938 * L - 0.00412161469 * M + 0.693511405 * S);
	vec3 err = c - sim;
	vec3 shift = vec3(0.0, 0.7 * err.r + err.g, 0.7 * err.r + err.b);
	if (mode == 3) {
		shift = vec3(err.r + 0.7 * err.b, err.g + 0.7 * err.b, 0.0);
	}
	COLOR = vec4(clamp(c + shift * strength, 0.0, 1.0), 1.0);
}
"""

static var _layer: CanvasLayer = null
static var _rect: ColorRect = null
static var flash_k := 1.0          # Faktor für Bildschirm- und Lichtblitze (1 = normal)


static func cb_mode() -> int:
	return clampi(int(Dev.get_v("cb_mode", 0)), 0, CB_MODES.size() - 1)


static func set_cb_mode(m: int) -> void:
	Dev.set_v("cb_mode", m)
	apply(G.main)


static func calm() -> bool:
	return bool(Dev.get_v("calm", false))


static func set_calm(on: bool) -> void:
	Dev.set_v("calm", on)
	apply(G.main)


static func apply(main: Node) -> void:
	flash_k = 0.3 if calm() else 1.0
	preload("res://src/captions.gd").enabled = bool(Dev.get_v("captions", false))
	var m := cb_mode()
	if main == null or not is_instance_valid(main):
		return
	if m == 0:
		if _layer != null and is_instance_valid(_layer):
			_layer.visible = false
		return
	if _layer == null or not is_instance_valid(_layer):
		_layer = CanvasLayer.new()
		_layer.layer = 126                    # über allem (auch Menüs und Ladebildschirm), unter dem Gamepad-Rahmen nicht nötig
		_layer.name = "Farbfilter"
		_rect = ColorRect.new()
		_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = SHADER
		var mat := ShaderMaterial.new()
		mat.shader = sh
		_rect.material = mat
		_layer.add_child(_rect)
		main.add_child(_layer)
	_layer.visible = true
	(_rect.material as ShaderMaterial).set_shader_parameter("mode", m)


## Für Tests: ist der Filter an?
static func filter_on() -> bool:
	return _layer != null and is_instance_valid(_layer) and _layer.visible
