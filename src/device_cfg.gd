extends RefCounted
## Paket Q: Einstellungen, die zum Gerät gehören und für alle Städte gelten (wie die Sprache):
## Barrierefreiheit (Farbfilter, Untertitel, Blitze), Tastenbelegung, Fenster (PC) und die automatisch gemessene
## Grafikstufe. Datei user://rustwall_device.cfg (ConfigFile, Abschnitt "dev").
## In Tests (--selftest, --autotest) wird nichts gelesen oder geschrieben – alles bleibt im Speicher.

const PATH := "user://rustwall_device.cfg"

static var _cfg: ConfigFile = null
static var _mem := false


static func _ensure() -> void:
	if _cfg != null:
		return
	_cfg = ConfigFile.new()
	_mem = G.selftest or G.autotest != "" or G.arg("devcfg") == "mem"
	if not _mem and FileAccess.file_exists(PATH):
		_cfg.load(PATH)


static func get_v(key: String, def: Variant = null) -> Variant:
	_ensure()
	return _cfg.get_value("dev", key, def)


static func has(key: String) -> bool:
	_ensure()
	return _cfg.has_section_key("dev", key)


static func set_v(key: String, v: Variant) -> void:
	_ensure()
	_cfg.set_value("dev", key, v)
	if not _mem:
		_cfg.save(PATH)


static func erase(key: String) -> void:
	_ensure()
	if _cfg.has_section_key("dev", key):
		_cfg.erase_section_key("dev", key)
		if not _mem:
			_cfg.save(PATH)


## Nur für Tests: alles vergessen (frisches Gerät).
static func reset_mem() -> void:
	_cfg = ConfigFile.new()
	_mem = true
