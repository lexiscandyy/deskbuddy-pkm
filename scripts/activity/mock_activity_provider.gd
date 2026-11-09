extends "res://scripts/activity/activity_provider.gd"
## Simulated activity for demos and tests. Must be enabled explicitly by the
## user; the UI labels it "Simulasi" whenever it is the active provider.

const SIMULATED_IDLE_SECONDS := 3600.0

var simulated_idle := false
## Simulated foreground executable name. Kept in memory only.
var foreground_process := ""


func get_label() -> String:
	return "Simulasi"


func is_available() -> bool:
	return true


func get_status_text() -> String:
	return "Simulasi: %s" % ("idle" if simulated_idle else "aktif")


func set_idle(idle: bool) -> void:
	simulated_idle = idle


func get_idle_seconds() -> float:
	return SIMULATED_IDLE_SECONDS if simulated_idle else 0.0


func get_foreground_process() -> String:
	return foreground_process.strip_edges()
