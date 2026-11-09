extends Node
## Samples the active ActivityProvider once per second (never per frame) and
## turns raw idle seconds into ACTIVE / IDLE / UNKNOWN.
##
## This is the *computer activity* signal only. It is independent from the
## DeskBuddy session phase (focus / break / none) owned by AppState.
##
## The foreground process name is read only when the user enabled distraction
## warnings or the app comment bubble, lives in memory for matching, and is
## never persisted.

signal state_changed(state: int)
signal foreground_changed(process_name: String)

const ActivityProvider := preload("res://scripts/activity/activity_provider.gd")
const MockActivityProvider := preload("res://scripts/activity/mock_activity_provider.gd")
const NativeActivityProvider := preload("res://scripts/activity/native_activity_provider.gd")

const SAMPLE_INTERVAL := 1.0

var mock := MockActivityProvider.new()
var native := NativeActivityProvider.new()
var provider: ActivityProvider
var state: int = ActivityProvider.State.UNKNOWN
var foreground := ""
var idle_seconds := -1.0

var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = SAMPLE_INTERVAL
	_timer.autostart = true
	_timer.timeout.connect(sample)
	add_child(_timer)
	Settings.changed.connect(func(_key: String) -> void: apply_settings())
	apply_settings()


func apply_settings() -> void:
	if Settings.get_value("simulation_enabled"):
		provider = mock
	else:
		provider = native
	sample()


func is_simulation() -> bool:
	return provider == mock


func monitoring_enabled() -> bool:
	return bool(Settings.get_value("monitoring_enabled"))


func wants_foreground() -> bool:
	return bool(Settings.get_value("distraction_enabled")) or bool(Settings.get_value("app_chat_enabled"))


func sample() -> void:
	var new_state: int = ActivityProvider.State.UNKNOWN
	var fg := ""
	idle_seconds = -1.0
	if monitoring_enabled() and provider == native:
		native.ensure_running(wants_foreground())
	else:
		native.stop()
	if monitoring_enabled() and provider != null and provider.is_available():
		idle_seconds = provider.get_idle_seconds()
		if idle_seconds >= 0.0:
			if idle_seconds >= Settings.idle_threshold_seconds():
				new_state = ActivityProvider.State.IDLE
			else:
				new_state = ActivityProvider.State.ACTIVE
		if wants_foreground():
			fg = provider.get_foreground_process()
	if new_state != state:
		state = new_state
		state_changed.emit(state)
	if fg != foreground:
		foreground = fg
		foreground_changed.emit(fg)


func _exit_tree() -> void:
	native.stop()


func state_name(s: int) -> String:
	match s:
		ActivityProvider.State.ACTIVE:
			return "Aktif"
		ActivityProvider.State.IDLE:
			return "Idle"
	return "Tidak diketahui"


func status_text() -> String:
	if not monitoring_enabled():
		return "Pemantauan dimatikan oleh pengguna. Status aktivitas: tidak diketahui."
	if is_simulation():
		return "SIMULASI: data aktivitas berasal dari tombol simulasi, bukan dari Windows."
	return native.get_status_text()
