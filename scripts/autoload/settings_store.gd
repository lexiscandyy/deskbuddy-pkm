extends Node
## Local preferences + aggregate statistics (ConfigFile under user://).
##
## Privacy: only whitelisted keys are ever written. No keystrokes, window
## titles, URLs, screenshots or per-app history are stored. Stats are daily
## aggregates (estimated active seconds, completed focus sessions).

signal changed(key: String)
signal stats_cleared

const DEFAULTS := {
	"mode": "supervisor",
	"focus_min": 25.0,
	"break_min": 5.0,
	"demo_mode": false,
	"monitoring_enabled": true,
	"simulation_enabled": false,
	"idle_threshold_sec": 60.0,
	"distraction_enabled": false,
	"distraction_apps": "",
	"distraction_delay_sec": 5.0,
	"distraction_cooldown_sec": 60.0,
	"app_chat_enabled": true,
	"eye_enabled": true,
	"eye_interval_min": 20.0,
	"eye_snooze_min": 5.0,
	"mascot_color": "pink",
	"intensity": 1,
	"mascot_size": 1,
	"mascot_visible": true,
	"window_mode": "overlay",
}
const STATS_KEYS := ["date", "ambient_active_sec", "focus_sessions"]

# Short durations used by "Durasi demo" so the full flow fits in a short demo.
const DEMO_FOCUS_SEC := 30.0
const DEMO_BREAK_SEC := 10.0
const DEMO_EYE_INTERVAL_SEC := 45.0
const DEMO_EYE_SNOOZE_SEC := 15.0
const DEMO_IDLE_THRESHOLD_SEC := 5.0
const DEMO_DISTRACTION_COOLDOWN_SEC := 20.0

var settings_path := "user://settings.cfg"
var stats_path := "user://stats.cfg"
var stats: Dictionary = {}

var _values: Dictionary = {}


func _ready() -> void:
	load_settings()
	load_stats()


# ---------------------------------------------------------------- settings

func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		push_warning("Settings: unknown key '%s' ignored" % key)
		return
	var v: Variant = _coerce(key, value)
	if v == null or get_value(key) == v:
		return
	_values[key] = v
	save_settings()
	changed.emit(key)


func reset_defaults() -> void:
	_values = {}
	save_settings()
	changed.emit("*")


func load_settings() -> void:
	_values = {}
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	for key: String in DEFAULTS:
		if cfg.has_section_key("settings", key):
			var v: Variant = _coerce(key, cfg.get_value("settings", key))
			if v != null:
				_values[key] = v


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key: String in DEFAULTS:
		cfg.set_value("settings", key, get_value(key))
	var err := cfg.save(settings_path)
	if err != OK:
		push_error("Settings: gagal menyimpan %s (%s)" % [settings_path, error_string(err)])


func _coerce(key: String, value: Variant) -> Variant:
	var d: Variant = DEFAULTS[key]
	match typeof(d):
		TYPE_FLOAT:
			if value is float or value is int:
				return maxf(0.0, float(value))
		TYPE_INT:
			if value is int or value is float:
				return int(value)
		TYPE_BOOL:
			if value is bool:
				return value
		TYPE_STRING:
			if value is String:
				return value
	return null


# ------------------------------------------------- effective durations (s)

func is_demo() -> bool:
	return bool(get_value("demo_mode"))


func focus_seconds() -> float:
	return DEMO_FOCUS_SEC if is_demo() else maxf(1.0, get_value("focus_min")) * 60.0


func break_seconds() -> float:
	return DEMO_BREAK_SEC if is_demo() else maxf(1.0, get_value("break_min")) * 60.0


func eye_interval_seconds() -> float:
	return DEMO_EYE_INTERVAL_SEC if is_demo() else maxf(1.0, get_value("eye_interval_min")) * 60.0


func eye_snooze_seconds() -> float:
	return DEMO_EYE_SNOOZE_SEC if is_demo() else maxf(1.0, get_value("eye_snooze_min")) * 60.0


func idle_threshold_seconds() -> float:
	return DEMO_IDLE_THRESHOLD_SEC if is_demo() else maxf(5.0, get_value("idle_threshold_sec"))


func distraction_cooldown_seconds() -> float:
	return DEMO_DISTRACTION_COOLDOWN_SEC if is_demo() else maxf(5.0, get_value("distraction_cooldown_sec"))


# ------------------------------------------------------------------- stats

func _today() -> String:
	return Time.get_date_string_from_system()


func _empty_stats() -> Dictionary:
	return {"date": _today(), "ambient_active_sec": 0.0, "focus_sessions": 0}


func load_stats() -> void:
	stats = _empty_stats()
	var cfg := ConfigFile.new()
	if cfg.load(stats_path) != OK:
		return
	if str(cfg.get_value("stats", "date", "")) != stats["date"]:
		return  # previous day: start fresh
	stats["ambient_active_sec"] = maxf(0.0, float(cfg.get_value("stats", "ambient_active_sec", 0.0)))
	stats["focus_sessions"] = maxi(0, int(cfg.get_value("stats", "focus_sessions", 0)))


func save_stats() -> void:
	var cfg := ConfigFile.new()
	for key: String in STATS_KEYS:
		cfg.set_value("stats", key, stats[key])
	var err := cfg.save(stats_path)
	if err != OK:
		push_error("Settings: gagal menyimpan %s (%s)" % [stats_path, error_string(err)])


## Resets the daily aggregates when the date changed. Returns true if reset.
func roll_day_if_needed() -> bool:
	if stats.get("date", "") == _today():
		return false
	stats = _empty_stats()
	save_stats()
	return true


func add_focus_session() -> void:
	roll_day_if_needed()
	stats["focus_sessions"] = int(stats["focus_sessions"]) + 1
	save_stats()


func clear_stats() -> void:
	stats = _empty_stats()
	if FileAccess.file_exists(stats_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(stats_path))
	stats_cleared.emit()
