extends RefCounted
## Ambient mode logic: accumulates estimated screen time (only while the
## computer is ACTIVE) and decides when a 20-20-20 eye reminder is due.

const ActivityProvider := preload("res://scripts/activity/activity_provider.gd")

var active_seconds := 0.0
var eye_enabled := true
var eye_interval := 1200.0
## Active seconds since the last acknowledged eye reminder.
var since_eye := 0.0
## Wall-clock seconds left on a snooze.
var snooze_left := 0.0
## True while an eye reminder is on screen (prevents re-triggering).
var pending := false


func advance(dt: float, activity_state: int) -> void:
	if dt <= 0.0:
		return
	if snooze_left > 0.0:
		snooze_left = maxf(0.0, snooze_left - dt)
	# Idle and unknown never count as screen time.
	if activity_state != ActivityProvider.State.ACTIVE:
		return
	active_seconds += dt
	if eye_enabled and not pending:
		since_eye += dt


func is_due() -> bool:
	return eye_enabled and not pending and snooze_left <= 0.0 and since_eye >= eye_interval


func seconds_until_due() -> float:
	return maxf(0.0, eye_interval - since_eye)


## Reminder was seen / dismissed / timed out: start a new 20-minute cycle.
func acknowledge() -> void:
	pending = false
	since_eye = 0.0
	snooze_left = 0.0


## Postpone the reminder. since_eye is kept, so it fires again after the snooze.
func snooze(seconds: float) -> void:
	pending = false
	snooze_left = maxf(0.0, seconds)


func reset_cycle() -> void:
	since_eye = 0.0
