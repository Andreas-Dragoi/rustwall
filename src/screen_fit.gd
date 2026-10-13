extends RefCounted
## Handy-Oberfläche und Akku (Paket F, Kapitel 3.3 und 7.3):
##   sichere Ränder (Notch, Dynamic Island, Home-Leiste) aus DisplayServer.get_display_safe_area(),
##   größere Oberfläche auf kleinen Handys (iPhone quer ≈ 844 × 390 Punkte), Bildrate im Akku-Sparmodus.
## Testhilfen: --pt_scale=2 (Bildpunkte je Punkt, wie ein Retina-Handy), --safe=links,oben,rechts,unten (Bildpunkte).

const DF = preload("res://src/data_fuehrung.gd")


## Höhe des Fensters in Punkten (iOS/Web: Bildpunkte / Bildschirmfaktor, Android: dpi / 160).
static func points_height() -> float:
	var h := float(DisplayServer.window_get_size().y)
	var sc := 1.0
	if G.arg("pt_scale") != "":
		sc = float(G.arg("pt_scale"))
	elif OS.has_feature("android"):
		sc = maxf(1.0, float(DisplayServer.screen_get_dpi()) / 160.0)
	elif OS.has_feature("ios") or OS.has_feature("web") or OS.has_feature("macos"):
		sc = maxf(1.0, DisplayServer.screen_get_scale())
	return h / maxf(sc, 0.1)


static func small_screen() -> bool:
	var mobile := G.is_touch or OS.has_feature("mobile") or G.web_mobile()
	return mobile and points_height() < DF.SMALL_PT


## Faktor für das HUD: Einstellung „Oberflächengröße“, sonst automatisch.
static func hud_scale() -> float:
	var i := int(P.d.get("settings", {}).get("ui_size", 0)) if not P.d.is_empty() else 0
	if i > 0 and i < DF.UI_SIZES.size():
		return float(DF.UI_SIZES[i][1])
	return DF.UI_SMALL if small_screen() else 1.0


## Faktor für die Vollbild-Menüs (etwas kleiner als das HUD, sie haben mehr Inhalt und rollen).
static func screen_scale() -> float:
	var s := hud_scale()
	if s <= 1.0:
		return 1.0
	return maxf(1.0, 1.0 + (s - 1.0) * (DF.SCREEN_SMALL - 1.0) / (DF.UI_SMALL - 1.0)) if DF.UI_SMALL > 1.0 else 1.0


## Sichere Ränder in Koordinaten der Oberfläche (Viewport): Vector4(links, oben, rechts, unten).
static func safe_margins(vp: Viewport) -> Vector4:
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or win.y <= 0.0:
		return Vector4.ZERO
	var l := 0.0
	var t := 0.0
	var r := 0.0
	var b := 0.0
	if G.arg("safe") != "":
		var p := G.arg("safe").split(",")
		if p.size() == 4:
			l = float(p[0])
			t = float(p[1])
			r = float(p[2])
			b = float(p[3])
	elif OS.has_feature("mobile") or G.web_mobile():
		var safe := Rect2(DisplayServer.get_display_safe_area())
		var scr := Rect2(Vector2(DisplayServer.screen_get_position()), Vector2(DisplayServer.screen_get_size()))
		if safe.size.x > 0.0 and safe.size.y > 0.0:
			var wpos := Vector2(DisplayServer.window_get_position())
			var wr := Rect2(wpos if wpos != Vector2.ZERO else scr.position, win)
			l = maxf(0.0, safe.position.x - wr.position.x)
			t = maxf(0.0, safe.position.y - wr.position.y)
			r = maxf(0.0, wr.end.x - safe.end.x)
			b = maxf(0.0, wr.end.y - safe.end.y)
	var k := vp.get_visible_rect().size / win
	return Vector4(l * k.x, t * k.y, r * k.x, b * k.y)


## Legt eine Oberflächen-Wurzel (Control direkt unter einer CanvasLayer) in den sicheren Bereich und skaliert sie.
static func fit(c: Control, scale: float) -> void:
	if c == null or not c.is_inside_tree():
		return
	var vp := c.get_viewport()
	var m := safe_margins(vp)
	var full := vp.get_visible_rect().size
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.position = Vector2(m.x, m.y)
	c.scale = Vector2(scale, scale)
	c.size = Vector2(full.x - m.x - m.z, full.y - m.y - m.w) / scale
	# Hintergründe (Meta "fill_screen") reichen bis an den Bildschirmrand
	for ch in c.get_children():
		if ch is Control and bool(ch.get_meta("fill_screen", false)):
			ch.offset_left = -m.x / scale
			ch.offset_top = -m.y / scale
			ch.offset_right = m.z / scale
			ch.offset_bottom = m.w / scale


# ================================================================= Bildrate (Akku-Sparmodus)
## Akku-Sparmodus an? Einstellung "akku": true/false; ohne Einstellung an Handys und im Handy-Browser an, am PC aus.
static func battery_saver() -> bool:
	if P.d.is_empty():
		return false
	var s: Dictionary = P.d.settings
	if s.has("akku"):
		return bool(s.akku)
	return OS.has_feature("mobile") or G.web_mobile() or G.is_touch


## 60 im Kampf, 30 in Basis und Menüs (Akku-Sparmodus). Die Einstellung „60 Bilder pro Sekunde“ begrenzt immer auf 30, wenn aus.
static func fps_target() -> int:
	if G.autotest != "":
		return 0
	if preload("res://src/auto_quality.gd").measuring:          # Paket Q: Messung der Grafikstufe ohne Bremse
		return 0
	var user: int = preload("res://src/pc_input.gd").fps_cap()  # Paket Q: Bildratenbegrenzung am PC
	if user >= 0 and not battery_saver():
		return user
	var mx := 60 if P.d.get("settings", {}).get("fps60", not G.web_mobile()) else 30
	if not battery_saver():
		return mx
	var battle: bool = G.game != null and is_instance_valid(G.game) and String(G.game.mode) != "peace" and not bool(G.game.ended)
	if G.main != null and G.main.screens != null and G.main.screens.is_open():
		battle = false
	return mini(mx, DF.FPS_BATTLE if battle else DF.FPS_CALM)
