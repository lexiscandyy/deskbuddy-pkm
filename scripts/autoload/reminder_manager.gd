extends Node
## Single reminder channel shared by Supervisor and Ambient modes.
## At most one reminder is visible; a lower-priority reminder never replaces
## a higher one, and mode switches clear everything, so nothing stacks.

## reminder: {"kind": String, "text": String, "can_snooze": bool}
signal reminder_shown(reminder: Dictionary)
## reason: "dismissed" | "snoozed" | "timeout" | "replaced" | "cleared"
signal reminder_cleared(kind: String, reason: String)

const PRIORITY := {"session": 3, "distraction": 2, "eye": 1, "test": 0}

var current: Dictionary = {}

var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(func() -> void: _finish("timeout"))
	add_child(_timer)


func has_reminder() -> bool:
	return not current.is_empty()


func current_kind() -> String:
	return str(current.get("kind", ""))


## Returns false when a higher-priority reminder is already visible.
func show_reminder(kind: String, text: String, duration := 15.0, can_snooze := false) -> bool:
	if has_reminder():
		if int(PRIORITY.get(current_kind(), 0)) > int(PRIORITY.get(kind, 0)):
			return false
		_finish("replaced")
	current = {"kind": kind, "text": text, "can_snooze": can_snooze}
	if is_inside_tree():
		_timer.start(maxf(1.0, duration))
	reminder_shown.emit(current)
	return true


func dismiss() -> void:
	_finish("dismissed")


func snooze() -> void:
	if bool(current.get("can_snooze", false)):
		_finish("snoozed")


## Clears without user action. Empty kind clears whatever is visible.
func clear(kind := "") -> void:
	if has_reminder() and (kind == "" or current_kind() == kind):
		_finish("cleared")


func _finish(reason: String) -> void:
	if not has_reminder():
		return
	var kind := current_kind()
	current = {}
	if _timer != null:
		_timer.stop()
	reminder_cleared.emit(kind, reason)
