extends "res://scripts/activity/activity_provider.gd"
## Windows provider (Milestone 2).
##
## A tiny helper program (native/bin/deskbuddy_probe.exe, C source in
## native/probe/) runs next to DeskBuddy without a window and calls the Win32
## API once per second:
##  - GetLastInputInfo         -> milliseconds since the last keyboard/mouse input
##  - GetForegroundWindow +
##    GetWindowThreadProcessId -> executable name of the active app
## It prints one line "idle_ms|name.exe" per second on stdout. Nothing else is
## read (no window titles, URLs, keystrokes or screenshots) and nothing is
## written to disk. The app name is only queried when want_foreground is true
## (comment bubble or distraction warning enabled).
##
## The helper exits by itself when DeskBuddy's process is gone. A GDExtension
## can replace it later behind the same interface.

## Data older than this is treated as unknown.
const STALE_MS := 5000

const PROBE_NAME := "deskbuddy_probe.exe"
const PROBE_DEV_PATH := "res://native/bin/deskbuddy_probe.exe"

var _pid := -1
var _pipe: FileAccess
var _err_pipe: FileAccess
var _thread: Thread
var _mutex := Mutex.new()
var _running_fg := false
var _idle_ms := -1
var _fg := ""
var _last_ms := -STALE_MS
var _error := ""


func get_label() -> String:
	return "Windows"


## Native monitoring needs Windows and a real display (not the headless test runner).
func is_supported() -> bool:
	return OS.get_name() == "Windows" and DisplayServer.get_name() != "headless"


func is_running() -> bool:
	return _pid > 0


func is_available() -> bool:
	return is_running() and _fresh()


func get_status_text() -> String:
	if not is_supported():
		return "Integrasi Windows tidak tersedia di sistem/mode ini. Status aktivitas: tidak diketahui."
	if _error != "":
		return "Integrasi Windows gagal dijalankan (%s). Status aktivitas: tidak diketahui." % _error
	if not is_running():
		return "Integrasi Windows tidak berjalan."
	if not _fresh():
		return "Menyiapkan integrasi Windows..."
	if _running_fg:
		return "Windows: membaca waktu idle dan nama aplikasi aktif (hanya nama .exe, tidak disimpan)."
	return "Windows: membaca waktu idle saja."


func get_idle_seconds() -> float:
	_mutex.lock()
	var v := _idle_ms
	_mutex.unlock()
	if v < 0 or not _fresh():
		return -1.0
	return v / 1000.0


func get_foreground_process() -> String:
	if not _running_fg or not _fresh():
		return ""
	_mutex.lock()
	var v := _fg
	_mutex.unlock()
	return v


## Starts the helper (or restarts it when the foreground flag changes).
func ensure_running(want_foreground: bool) -> void:
	if not is_supported():
		return
	if is_running() and OS.is_process_running(_pid) and want_foreground == _running_fg:
		return
	if is_running() and not OS.is_process_running(_pid) and _error == "":
		_error = "helper berhenti"
	stop()
	_start(want_foreground)


func stop() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	if _pipe != null:
		_pipe.close()
		_pipe = null
	if _err_pipe != null:
		_err_pipe.close()
		_err_pipe = null
	_mutex.lock()
	_idle_ms = -1
	_fg = ""
	_last_ms = -STALE_MS
	_mutex.unlock()


## Exported build: next to DeskBuddy.exe. Editor / source run: native/bin.
static func probe_path() -> String:
	var beside := OS.get_executable_path().get_base_dir().path_join(PROBE_NAME)
	if FileAccess.file_exists(beside):
		return beside
	var dev := ProjectSettings.globalize_path(PROBE_DEV_PATH)
	if FileAccess.file_exists(dev):
		return dev
	return ""


func _start(want_foreground: bool) -> void:
	var path := probe_path()
	if path == "":
		_error = PROBE_NAME + " tidak ditemukan, jalankan native/probe/build.bat"
		return
	var info := OS.execute_with_pipe(path, [str(OS.get_process_id()), "1" if want_foreground else "0"], true)
	if info.is_empty():
		_error = PROBE_NAME + " tidak bisa dijalankan"
		return
	_error = ""
	_pid = int(info["pid"])
	_pipe = info["stdio"]
	_err_pipe = info.get("stderr")
	_running_fg = want_foreground
	_thread = Thread.new()
	_thread.start(_read_loop.bind(_pipe))


func _read_loop(pipe: FileAccess) -> void:
	while true:
		var line := pipe.get_line()
		if line == "" and pipe.get_error() != OK:
			break
		var parts := line.strip_edges().split("|")
		if parts.size() < 2 or not parts[0].is_valid_int():
			continue
		_mutex.lock()
		_idle_ms = parts[0].to_int()
		_fg = parts[1].strip_edges().to_lower()
		_last_ms = Time.get_ticks_msec()
		_mutex.unlock()


func _fresh() -> bool:
	_mutex.lock()
	var t := _last_ms
	_mutex.unlock()
	return Time.get_ticks_msec() - t < STALE_MS
