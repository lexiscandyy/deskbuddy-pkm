extends Node
## End-to-end scenario through the real autoloads (Settings, Activity,
## Reminders, AppState) using the MockActivityProvider. Time is driven
## manually via AppState.advance() so the run is fast and deterministic.
## Run:
##   godot --headless --path . res://tests/integration_test.tscn

const PomodoroTimer := preload("res://scripts/core/pomodoro_timer.gd")
const ActivityProvider := preload("res://scripts/activity/activity_provider.gd")

const TEST_SETTINGS := "user://it_settings.cfg"
const TEST_STATS := "user://it_stats.cfg"

var _checks := 0
var _failures := 0


func _ready() -> void:
	AppState.set_auto_tick(false)
	Settings.settings_path = TEST_SETTINGS
	Settings.stats_path = TEST_STATS
	Settings.clear_stats()
	Settings.reset_defaults()
	AppState.end_session()
	AppState.set_mode(AppState.Mode.SUPERVISOR)

	_section("Simulasi harus diaktifkan eksplisit")
	check(not Activity.is_simulation(), "default: bukan simulasi")
	check(Activity.state == ActivityProvider.State.UNKNOWN, "tanpa native & tanpa simulasi -> tidak diketahui")
	Settings.set_value("simulation_enabled", true)
	Settings.set_value("demo_mode", true)
	Activity.mock.set_idle(false)
	Activity.sample()
	check(Activity.is_simulation() and Activity.status_text().begins_with("SIMULASI"), "berlabel SIMULASI")
	check(Activity.state == ActivityProvider.State.ACTIVE, "simulasi aktif")

	_section("Skenario demo 30 dtk fokus / 10 dtk jeda")
	AppState.start_session("Bab 2 proposal")
	var p := AppState.pomodoro
	check(p.phase == PomodoroTimer.Phase.FOCUS and is_equal_approx(p.remaining, 30.0), "fokus 30 dtk dimulai")
	_advance(10)
	AppState.pause_session()
	_advance(15)
	check(is_equal_approx(p.remaining, 20.0) and p.paused, "pause menahan hitung mundur di 00:20")
	AppState.resume_session()
	_advance(20)
	check(p.phase == PomodoroTimer.Phase.BREAK, "masuk fase jeda")
	check(Reminders.current_kind() == "session", "maskot memberi pengingat istirahat")
	_advance(10)
	check(p.phase == PomodoroTimer.Phase.NONE, "jeda selesai -> sesi berakhir")
	check(int(Settings.stats["focus_sessions"]) == 1, "statistik sesi fokus bertambah")
	Reminders.dismiss()

	_section("Peringatan distraksi")
	Settings.set_value("app_chat_enabled", false)
	Settings.set_value("distraction_apps", "game.exe")
	Activity.mock.foreground_process = "game.exe"
	Activity.sample()
	check(Activity.foreground == "", "foreground tidak dibaca saat distraksi & komentar mati")
	Settings.set_value("app_chat_enabled", true)
	Activity.sample()
	check(Activity.foreground == "game.exe", "komentar aplikasi aktif -> nama .exe dibaca (di memori)")
	Settings.set_value("app_chat_enabled", false)
	Activity.sample()
	AppState.start_session("Latihan soal")
	_advance(10)
	check(not Reminders.has_reminder(), "fitur mati -> tidak ada peringatan")
	Settings.set_value("distraction_enabled", true)
	Activity.sample()
	_advance(6)
	check(Reminders.current_kind() == "distraction", "aplikasi bertanda di foreground saat fokus -> peringatan")
	AppState.pause_session()
	check(not Reminders.has_reminder(), "pause menghapus peringatan distraksi")
	_advance(30)
	check(not Reminders.has_reminder(), "tidak ada peringatan saat timer dijeda")
	AppState.resume_session()
	check(is_equal_approx(p.remaining, 14.0), "resume melanjutkan dari sisa 14 dtk")
	_advance(14)
	check(p.phase == PomodoroTimer.Phase.BREAK, "fokus selesai -> jeda")
	Reminders.dismiss()
	_advance(8)
	check(not Reminders.has_reminder(), "tidak ada peringatan distraksi saat jeda")
	AppState.end_session()
	Activity.mock.foreground_process = "chrome.exe"
	Activity.sample()
	AppState.start_session("Membaca")
	_advance(25)
	check(not Reminders.has_reminder(), "browser tidak dianggap distraksi bila tidak ada di daftar")
	AppState.end_session()

	_section("Mode Ambient")
	Activity.mock.foreground_process = ""
	AppState.start_session("akan dihentikan")
	AppState.set_mode(AppState.Mode.AMBIENT)
	check(p.phase == PomodoroTimer.Phase.NONE and not Reminders.has_reminder(), "pindah mode mengakhiri sesi dan membersihkan pengingat")
	var base := AppState.ambient.active_seconds
	_advance(5)
	check(is_equal_approx(AppState.ambient.active_seconds, base + 5.0), "aktif -> waktu bertambah 5 dtk")
	Activity.mock.set_idle(true)
	Activity.sample()
	check(Activity.state == ActivityProvider.State.IDLE, "simulasi idle terdeteksi")
	_advance(20)
	check(is_equal_approx(AppState.ambient.active_seconds, base + 5.0), "idle -> waktu berhenti")
	Activity.mock.set_idle(false)
	Activity.sample()
	_advance(5)
	check(is_equal_approx(AppState.ambient.active_seconds, base + 10.0), "aktif lagi -> menghitung lagi")
	Settings.set_value("monitoring_enabled", false)
	_advance(5)
	check(Activity.state == ActivityProvider.State.UNKNOWN and is_equal_approx(AppState.ambient.active_seconds, base + 10.0), "pemantauan mati -> tidak diketahui, tidak dihitung")
	Settings.set_value("monitoring_enabled", true)

	_section("Pengingat 20-20-20 (interval demo 45 dtk)")
	AppState.ambient.acknowledge()
	_advance(44)
	check(not Reminders.has_reminder(), "belum muncul sebelum 45 dtk aktif")
	_advance(1)
	check(Reminders.current_kind() == "eye", "pengingat mata muncul")
	check(Reminders.current["text"] == AppState.EYE_TEXT, "teks 20-20-20 benar")
	Reminders.snooze()
	_advance(14)
	check(not Reminders.has_reminder(), "ditunda 15 dtk")
	_advance(1)
	check(Reminders.current_kind() == "eye", "muncul lagi setelah tunda")
	AppState.set_mode(AppState.Mode.SUPERVISOR)
	check(not Reminders.has_reminder(), "pindah mode -> pengingat Ambient tidak ikut menumpuk")
	AppState.set_mode(AppState.Mode.AMBIENT)
	_advance(100)
	check(Reminders.current_kind() == "eye", "satu pengingat saja setelah kembali ke Ambient")
	Settings.set_value("eye_enabled", false)
	check(not Reminders.has_reminder(), "mematikan 20-20-20 menutup pengingat")
	_advance(100)
	check(not Reminders.has_reminder(), "tidak muncul saat dimatikan")

	_section("Sleep / wake")
	AppState.set_mode(AppState.Mode.SUPERVISOR)
	AppState.start_session("tes sleep")
	_advance(3)
	var before := p.remaining
	AppState.handle_gap(1800.0)
	check(p.paused and is_equal_approx(p.remaining, before), "setelah sleep: timer dijeda, waktu sleep tidak dihitung")
	check(AppState.gap_notice != "", "pemberitahuan sleep ditampilkan")
	AppState.resume_session()
	check(AppState.gap_notice == "" and p.is_running(), "lanjut menghapus pemberitahuan")
	AppState.end_session()

	_section("Privasi penyimpanan lokal")
	AppState._save_stats()
	var stats_text := FileAccess.get_file_as_string(TEST_STATS)
	var settings_text := FileAccess.get_file_as_string(TEST_SETTINGS)
	check(not stats_text.contains("game") and not stats_text.contains("chrome"), "stats tidak berisi nama aplikasi")
	check(not settings_text.contains("chrome") and not settings_text.contains("Bab 2"), "settings tidak berisi foreground/target sesi")
	Settings.clear_stats()
	check(not FileAccess.file_exists(TEST_STATS) and is_zero_approx(AppState.ambient.active_seconds), "hapus statistik")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	print("\n%d pemeriksaan, %d gagal" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _advance(seconds: int) -> void:
	for i in seconds:
		AppState.advance(1.0)


func _section(title: String) -> void:
	print("\n== " + title)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if cond:
		print("  ok    " + msg)
	else:
		_failures += 1
		printerr("  GAGAL " + msg)
