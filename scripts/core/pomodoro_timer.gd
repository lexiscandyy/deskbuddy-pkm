extends RefCounted
## Pure Pomodoro state machine. It never reads the clock: the owner feeds
## elapsed seconds through advance(), which keeps it deterministic and testable.

signal phase_changed(new_phase: int, old_phase: int)
signal phase_completed(phase: int)

enum Phase { NONE, FOCUS, BREAK }

var focus_duration := 1500.0
var break_duration := 300.0
var phase: int = Phase.NONE
var paused := false
var remaining := 0.0
var goal := ""
var completed_focus_count := 0


func start(p_goal: String = "") -> void:
	goal = p_goal.strip_edges()
	paused = false
	_enter(Phase.FOCUS)


func pause() -> bool:
	if phase == Phase.NONE or paused:
		return false
	paused = true
	return true


func resume() -> bool:
	if phase == Phase.NONE or not paused:
		return false
	paused = false
	return true


func stop() -> void:
	paused = false
	if phase != Phase.NONE:
		_enter(Phase.NONE)


func is_running() -> bool:
	return phase != Phase.NONE and not paused


## Advances the countdown. Overshoot past zero is discarded (at most one tick),
## so a long dt can never skip a whole phase.
func advance(dt: float) -> void:
	if not is_running() or dt <= 0.0:
		return
	remaining -= dt
	if remaining > 0.0:
		return
	var finished := phase
	if finished == Phase.FOCUS:
		completed_focus_count += 1
		_enter(Phase.BREAK)
	else:
		_enter(Phase.NONE)
	phase_completed.emit(finished)


func _enter(new_phase: int) -> void:
	var old := phase
	phase = new_phase
	match new_phase:
		Phase.FOCUS:
			remaining = focus_duration
		Phase.BREAK:
			remaining = break_duration
		_:
			remaining = 0.0
			paused = false
	phase_changed.emit(new_phase, old)
