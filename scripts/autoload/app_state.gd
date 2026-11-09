extends Node
## Single source of truth for DeskBuddy: operating mode, Pomodoro session,
## Ambient tracker and distraction detection. UI and mascot only read from
## here and call its methods; they never run timers of their own.
##
## Timing: a 0.25 s Timer measures real elapsed time with Time.get_ticks_msec()
## and cross-checks the wall clock. A gap > GAP_THRESHOLD (sleep/hibernate,
## a frozen process) is never counted: a running Pomodoro is auto-paused and
## Ambient screen time is not increased. See README "Perilaku setelah sleep".

signal changed
signal mode_changed(mode: int)

enum Mode { SUPERVISOR, AMBIENT }

const ActivityProvider := preload("res://scripts/activity/activity_provider.gd")
const PomodoroTimer := preload("res://scripts/core/pomodoro_timer.gd")
const AmbientTracker := preload("res://scripts/core/ambient_tracker.gd")
const DistractionDetector := preload("res://scripts/core/distraction_detector.gd")

const TICK_INTERVAL := 0.25
const GAP_THRESHOLD := 5.0
## A gap at least this long also counts as an eye rest (new 20-20-20 cycle).
const GAP_EYE_REST := 60.0
const STATS_SAVE_INTERVAL := 30.0
const EYE_TEXT := "Arahkan pandangan ke objek sekitar 6 meter selama 20 detik."

var mode: int = Mode.SUPERVISOR
var pomodoro := PomodoroTimer.new()
var ambient := AmbientTracker.new()
var distraction := DistractionDetector.new()
## Shown in the panel after an automatic pause (sleep/wake).
var gap_notice := ""

var _tick_timer: Timer
var _last_ticks_ms := 0
var _last_unix := 0.0
var _stats_accum := 0.0


func _ready() -> void:
	mode = Mode.AMBIENT if Settings.get_value("mode") == "ambient" else Mode.SUPERVISOR
	ambient.active_seconds = float(Settings.stats.get("ambient_active_sec", 0.0))
	pomodoro.phase_changed.connect(_on_phase_changed)
	pomodoro.phase_completed.connect(_on_phase_completed)
	Settings.changed.connect(func(_key: String) -> void: _apply_settings())
	Settings.stats_cleared.connect(_on_stats_cleared)
	Reminders.reminder_cleared.connect(_on_reminder_cleared)
	Activity.state_changed.connect(func(_s: int) -> void: changed.emit())
	_apply_settings()
	_reset_clock()
	_tick_timer = Timer.new()
	_tick_timer.wait_time = TICK_INTERVAL
	_tick_timer.autostart = true
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)


func _exit_tree() -> void:
	_save_stats()


## Stops automatic ticking (used by tests that drive advance() directly).
func set_auto_tick(enabled: bool) -> void:
	if _tick_timer == null:
		return
	if enabled:
		_reset_clock()
		_tick_timer.start()
	else:
		_tick_timer.stop()


# ------------------------------------------------------------ public API

func set_mode(new_mode: int) -> void:
	if new_mode == mode:
		return
	if pomodoro.phase != PomodoroTimer.Phase.NONE:
		pomodoro.stop()
	distraction.reset()
	gap_notice = ""
	Reminders.clear()
	mode = new_mode
	Settings.set_value("mode", "ambient" if mode == Mode.AMBIENT else "supervisor")
	mode_changed.emit(mode)
	changed.emit()


func start_session(goal: String) -> void:
	if mode != Mode.SUPERVISOR:
		set_mode(Mode.SUPERVISOR)
	_apply_settings()
	Reminders.clear()
	gap_notice = ""
	pomodoro.start(goal)
	changed.emit()


func pause_session() -> void:
	if pomodoro.pause():
		distraction.reset()
		Reminders.clear("distraction")
		changed.emit()


func resume_session() -> void:
	if pomodoro.resume():
		gap_notice = ""
		_reset_clock()
		changed.emit()


func end_session() -> void:
	pomodoro.stop()
	gap_notice = ""
	Reminders.clear()
	changed.emit()


func snooze_eye() -> void:
	if Reminders.current_kind() == "eye":
		Reminders.snooze()
	else:
		ambient.snooze(Settings.eye_snooze_seconds())
	changed.emit()


## Advance all logic by dt seconds of real, uninterrupted time.
func advance(dt: float) -> void:
	if dt <= 0.0:
		return
	if mode == Mode.SUPERVISOR:
		pomodoro.advance(dt)
		var focus_active := pomodoro.phase == PomodoroTimer.Phase.FOCUS and not pomodoro.paused
		var hit := distraction.advance(dt, focus_active, Activity.foreground)
		if hit != "":
			var target := pomodoro.goal if pomodoro.goal != "" else "sesi fokusmu"
			Reminders.show_reminder("distraction",
				"Aplikasi yang kamu tandai (%s) sedang terbuka. Yuk kembali ke: %s" % [hit, target], 10.0)
	else:
		ambient.advance(dt, Activity.state)
		if ambient.is_due() and Reminders.show_reminder("eye", EYE_TEXT, 30.0, true):
			ambient.pending = true
		_stats_accum += dt
		if _stats_accum >= STATS_SAVE_INTERVAL:
			_stats_accum = 0.0
			_save_stats()
	changed.emit()


## Called when time jumped (sleep/wake, frozen process). Never counts the gap.
func handle_gap(seconds: float) -> void:
	if pomodoro.is_running():
		pomodoro.pause()
		gap_notice = "Timer dijeda otomatis: komputer sleep/tidak merespons sekitar %d detik. Tekan Lanjut untuk meneruskan." % int(seconds)
	distraction.reset()
	Reminders.clear("distraction")
	if seconds >= GAP_EYE_REST and not ambient.pending:
		ambient.reset_cycle()
	changed.emit()


# ------------------------------------------------------------- text helpers

@warning_ignore("integer_division")
func format_countdown(seconds: float) -> String:
	var s := int(ceil(maxf(seconds, 0.0)))
	return "%02d:%02d" % [s / 60, s % 60]


@warning_ignore("integer_division")
func format_duration(seconds: float) -> String:
	var s := int(floor(maxf(seconds, 0.0)))
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


func mode_name() -> String:
	return "Ambient" if mode == Mode.AMBIENT else "Supervisor"


func phase_text() -> String:
	var t := "Tanpa sesi"
	match pomodoro.phase:
		PomodoroTimer.Phase.FOCUS:
			t = "Fokus"
		PomodoroTimer.Phase.BREAK:
			t = "Jeda"
	if pomodoro.paused:
		t += " (dijeda)"
	return t


func eye_status_text() -> String:
	if not ambient.eye_enabled:
		return "Pengingat 20-20-20 nonaktif."
	if ambient.pending:
		return "Pengingat 20-20-20 sedang tampil."
	if ambient.snooze_left > 0.0:
		return "Ditunda, muncul lagi dalam %s." % format_countdown(maxf(ambient.snooze_left, ambient.seconds_until_due()))
	return "Pengingat berikutnya setelah %s waktu aktif lagi." % format_countdown(ambient.seconds_until_due())


# ---------------------------------------------------------------- internals

func _apply_settings() -> void:
	pomodoro.focus_duration = Settings.focus_seconds()
	pomodoro.break_duration = Settings.break_seconds()
	ambient.eye_enabled = bool(Settings.get_value("eye_enabled"))
	ambient.eye_interval = Settings.eye_interval_seconds()
	distraction.enabled = bool(Settings.get_value("distraction_enabled")) and bool(Settings.get_value("monitoring_enabled"))
	distraction.set_apps_from_text(str(Settings.get_value("distraction_apps")))
	distraction.delay = maxf(1.0, float(Settings.get_value("distraction_delay_sec")))
	distraction.cooldown = Settings.distraction_cooldown_seconds()
	if not ambient.eye_enabled:
		Reminders.clear("eye")
	if not distraction.enabled:
		Reminders.clear("distraction")
	changed.emit()


func _reset_clock() -> void:
	_last_ticks_ms = Time.get_ticks_msec()
	_last_unix = Time.get_unix_time_from_system()


func _on_tick() -> void:
	var now_ms := Time.get_ticks_msec()
	var now_unix := Time.get_unix_time_from_system()
	var dt := (now_ms - _last_ticks_ms) / 1000.0
	var wall := now_unix - _last_unix
	_last_ticks_ms = now_ms
	_last_unix = now_unix
	if dt > GAP_THRESHOLD or wall > GAP_THRESHOLD:
		handle_gap(maxf(dt, wall))
		return
	advance(dt)


func _on_phase_changed(_new_phase: int, _old_phase: int) -> void:
	distraction.reset()
	Reminders.clear("distraction")
	changed.emit()


func _on_phase_completed(finished: int) -> void:
	if finished == PomodoroTimer.Phase.FOCUS:
		Settings.add_focus_session()
		Reminders.show_reminder("session",
			"Waktu fokus selesai! Istirahat %s: berdiri, regangkan bahu dan leher, lalu minum air." % format_countdown(pomodoro.break_duration),
			20.0)
	else:
		Reminders.show_reminder("session", "Jeda selesai. Siap lanjut? Tekan Mulai untuk sesi fokus berikutnya.", 20.0)


func _on_reminder_cleared(kind: String, reason: String) -> void:
	if kind == "eye":
		if reason == "snoozed":
			ambient.snooze(Settings.eye_snooze_seconds())
		else:
			ambient.acknowledge()
	changed.emit()


func _on_stats_cleared() -> void:
	ambient.active_seconds = 0.0
	_stats_accum = 0.0
	changed.emit()


func _save_stats() -> void:
	if Settings.roll_day_if_needed():
		ambient.active_seconds = 0.0
	Settings.stats["ambient_active_sec"] = snappedf(ambient.active_seconds, 0.1)
	Settings.save_stats()
