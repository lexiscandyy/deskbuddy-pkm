extends RefCounted
## Decides when to show a gentle distraction warning. Only apps the user
## listed count; an empty/unknown foreground resets the dwell timer.
## Nothing here is persisted.

var enabled := false
var apps := PackedStringArray()
## Seconds a listed app must stay in the foreground before warning.
var delay := 5.0
## Minimum seconds between two warnings.
var cooldown := 60.0

var _dwell := 0.0
var _current := ""
var _cooldown_left := 0.0


static func normalize(process_name: String) -> String:
	var n := process_name.strip_edges().to_lower()
	if n.ends_with(".exe"):
		n = n.trim_suffix(".exe")
	return n


func set_apps_from_text(text: String) -> void:
	apps = PackedStringArray()
	for part in text.replace("\n", ",").replace(";", ",").split(",", false):
		var n := normalize(part)
		if n != "" and not apps.has(n):
			apps.append(n)


func reset() -> void:
	_dwell = 0.0
	_current = ""


## Returns the matched (normalized) app name when a warning should fire now,
## otherwise "". focus_active must be true only during an unpaused focus phase.
func advance(dt: float, focus_active: bool, foreground: String) -> String:
	_cooldown_left = maxf(0.0, _cooldown_left - dt)
	if not enabled or not focus_active or foreground.strip_edges() == "":
		reset()
		return ""
	var n := normalize(foreground)
	if not apps.has(n):
		reset()
		return ""
	if n != _current:
		_current = n
		_dwell = 0.0
	_dwell += dt
	if _dwell >= delay and _cooldown_left <= 0.0:
		_cooldown_left = cooldown
		_dwell = 0.0
		return n
	return ""
