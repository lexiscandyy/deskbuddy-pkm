extends SceneTree
## Unit tests for pure logic. Run:
##   godot --headless --path . --script res://tests/unit_tests.gd
## Exit code 0 = all passed.

const PomodoroTimer := preload("res://scripts/core/pomodoro_timer.gd")
const AmbientTracker := preload("res://scripts/core/ambient_tracker.gd")
const DistractionDetector := preload("res://scripts/core/distraction_detector.gd")
const ActivityProvider := preload("res://scripts/activity/activity_provider.gd")
const MockActivityProvider := preload("res://scripts/activity/mock_activity_provider.gd")
const SettingsStore := preload("res://scripts/autoload/settings_store.gd")
const AppChatter := preload("res://scripts/core/app_chatter.gd")
const NativeActivityProvider := preload("res://scripts/activity/native_activity_provider.gd")

const ACTIVE := ActivityProvider.State.ACTIVE
const IDLE := ActivityProvider.State.IDLE
const UNKNOWN := ActivityProvider.State.UNKNOWN

var _checks := 0
var _failures := 0


func _initialize() -> void:
	_run("Pomodoro: demo 30 dtk fokus / 10 dtk jeda dengan pause-resume", _test_pomodoro_demo)
	_run("Pomodoro: kontrol tidak valid diabaikan", _test_pomodoro_controls)
	_run("Ambient: hanya menghitung saat aktif", _test_ambient_counting)
	_run("Ambient: 20-20-20 tunda & matikan", _test_ambient_eye)
	_run("Distraksi: hanya aplikasi pilihan, saat fokus, dengan cooldown", _test_distraction)
	_run("Mock provider", _test_mock)
	_run("Komentar aplikasi: nama, abaikan sistem, cooldown", _test_app_chatter)
	_run("Native provider: aman tanpa Windows/headless", _test_native_headless)
	_run("Settings: tersimpan, tervalidasi, statistik bisa dihapus", _test_settings)
	print("\n%d pemeriksaan, %d gagal" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _run(title: String, fn: Callable) -> void:
	print("\n== " + title)
	fn.call()


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if cond:
		print("  ok    " + msg)
	else:
		_failures += 1
		printerr("  GAGAL " + msg)


func _step(obj: Object, seconds: int, extra: Array = []) -> void:
	for i in seconds:
		obj.callv("advance", [1.0] + extra)


func _test_pomodoro_demo() -> void:
	var p := PomodoroTimer.new()
	p.focus_duration = 30.0
	p.break_duration = 10.0
	var completed: Array[int] = []
	p.phase_completed.connect(func(ph: int) -> void: completed.append(ph))
	p.start("Bab 2")
	check(p.phase == PomodoroTimer.Phase.FOCUS and is_equal_approx(p.remaining, 30.0), "mulai -> fokus 30 dtk")
	_step(p, 10)
	check(is_equal_approx(p.remaining, 20.0), "10 dtk berjalan -> sisa 20")
	check(p.pause(), "pause berhasil")
	_step(p, 100)
	check(is_equal_approx(p.remaining, 20.0), "saat dijeda waktu tidak berkurang")
	check(p.resume(), "resume berhasil")
	_step(p, 20)
	check(p.phase == PomodoroTimer.Phase.BREAK and is_equal_approx(p.remaining, 10.0), "fokus habis -> jeda 10 dtk")
	check(completed == [PomodoroTimer.Phase.FOCUS], "event fokus selesai sekali")
	check(p.pause() and p.resume(), "pause/resume juga bekerja saat jeda")
	_step(p, 10)
	check(p.phase == PomodoroTimer.Phase.NONE, "jeda habis -> tanpa sesi")
	check(completed == [PomodoroTimer.Phase.FOCUS, PomodoroTimer.Phase.BREAK], "event jeda selesai sekali")
	check(p.completed_focus_count == 1, "satu sesi fokus tercatat")
	p.start("")
	p.advance(500.0)
	check(p.phase == PomodoroTimer.Phase.BREAK, "dt besar tidak melompati fase jeda")


func _test_pomodoro_controls() -> void:
	var p := PomodoroTimer.new()
	check(not p.pause(), "pause tanpa sesi ditolak")
	check(not p.resume(), "resume tanpa sesi ditolak")
	p.start("x")
	check(not p.resume(), "resume saat tidak dijeda ditolak")
	p.pause()
	p.stop()
	check(p.phase == PomodoroTimer.Phase.NONE and not p.paused, "akhiri mereset fase dan pause")


func _test_ambient_counting() -> void:
	var a := AmbientTracker.new()
	_step(a, 10, [ACTIVE])
	check(is_equal_approx(a.active_seconds, 10.0), "10 dtk aktif dihitung")
	_step(a, 50, [IDLE])
	check(is_equal_approx(a.active_seconds, 10.0), "idle tidak dihitung")
	_step(a, 5, [UNKNOWN])
	check(is_equal_approx(a.active_seconds, 10.0), "tidak diketahui tidak dihitung")
	_step(a, 5, [ACTIVE])
	check(is_equal_approx(a.active_seconds, 15.0), "kembali aktif -> menghitung lagi")


func _test_ambient_eye() -> void:
	var a := AmbientTracker.new()
	a.eye_interval = 20.0
	_step(a, 19, [ACTIVE])
	check(not a.is_due(), "belum jatuh tempo pada 19 dtk")
	_step(a, 30, [IDLE])
	check(not a.is_due(), "idle tidak memajukan pengingat")
	_step(a, 1, [ACTIVE])
	check(a.is_due(), "jatuh tempo pada 20 dtk aktif")
	a.pending = true
	check(not a.is_due(), "tidak dipicu ulang saat sedang tampil")
	a.snooze(15.0)
	_step(a, 14, [ACTIVE])
	check(not a.is_due(), "selama tunda tidak muncul")
	_step(a, 1, [ACTIVE])
	check(a.is_due(), "muncul lagi setelah tunda selesai")
	a.acknowledge()
	check(not a.is_due() and is_zero_approx(a.since_eye), "ditutup -> siklus baru")
	a.eye_enabled = false
	_step(a, 100, [ACTIVE])
	check(not a.is_due(), "dimatikan -> tidak pernah jatuh tempo")


func _test_distraction() -> void:
	var d := DistractionDetector.new()
	d.enabled = true
	d.delay = 5.0
	d.cooldown = 60.0
	d.set_apps_from_text("Game.exe, discord ;")
	check(d.apps == PackedStringArray(["game", "discord"]), "daftar dinormalisasi")
	var hits := func(seconds: int, focus: bool, fg: String) -> Array:
		var out := []
		for i in seconds:
			var h := d.advance(1.0, focus, fg)
			if h != "":
				out.append(h)
		return out
	check(hits.call(10, false, "game.exe").is_empty(), "tidak ada peringatan di luar fokus")
	check(hits.call(10, true, "notepad.exe").is_empty(), "aplikasi yang tidak ditandai diabaikan")
	check(hits.call(10, true, "chrome.exe").is_empty(), "browser tidak dihitung bila tidak ada di daftar")
	check(hits.call(10, true, "").is_empty(), "foreground tidak diketahui diabaikan")
	check(hits.call(4, true, "GAME.EXE").is_empty(), "belum memicu sebelum 5 dtk")
	check(hits.call(1, true, "game.exe") == ["game"], "memicu pada 5 dtk")
	check(hits.call(50, true, "game.exe").is_empty(), "cooldown mencegah pengulangan")
	check(hits.call(15, true, "game.exe").size() == 1, "memicu lagi setelah cooldown")
	d.enabled = false
	check(hits.call(200, true, "game.exe").is_empty(), "fitur mati -> tidak ada peringatan")


func _test_mock() -> void:
	var m := MockActivityProvider.new()
	check(m.is_available() and m.get_label() == "Simulasi", "mock tersedia dan berlabel Simulasi")
	check(is_zero_approx(m.get_idle_seconds()), "default aktif")
	m.set_idle(true)
	check(m.get_idle_seconds() > 1000.0, "simulasi idle")
	m.foreground_process = "  game.exe "
	check(m.get_foreground_process() == "game.exe", "foreground simulasi")


func _test_settings() -> void:
	var sp := "user://unit_test_settings.cfg"
	var tp := "user://unit_test_stats.cfg"
	var s: Node = SettingsStore.new()
	s.settings_path = sp
	s.stats_path = tp
	s.load_settings()
	s.load_stats()
	s.set_value("focus_min", 40)
	s.set_value("mascot_color", "lilac")
	s.set_value("demo_mode", true)
	s.set_value("focus_min", "bukan angka")
	s.set_value("unknown_key", 1)
	s.add_focus_session()
	s.free()

	var s2: Node = SettingsStore.new()
	s2.settings_path = sp
	s2.stats_path = tp
	s2.load_settings()
	s2.load_stats()
	check(s2.get_value("focus_min") == 40.0, "durasi fokus bertahan (int dikonversi ke float)")
	check(s2.get_value("mascot_color") == "lilac", "warna bertahan")
	check(s2.focus_seconds() == 30.0 and s2.break_seconds() == 10.0, "durasi demo 30/10 dtk")
	check(int(s2.stats["focus_sessions"]) == 1, "statistik sesi bertahan")
	var cfg := ConfigFile.new()
	cfg.load(sp)
	check(not cfg.has_section_key("settings", "unknown_key"), "kunci asing tidak disimpan")
	check(Array(cfg.get_section_keys("settings")).all(func(k: String) -> bool: return SettingsStore.DEFAULTS.has(k)), "hanya kunci whitelist di settings.cfg")
	var st := ConfigFile.new()
	st.load(tp)
	check(Array(st.get_section_keys("stats")) == SettingsStore.STATS_KEYS, "stats.cfg hanya berisi agregat")
	s2.clear_stats()
	check(not FileAccess.file_exists(tp) and int(s2.stats["focus_sessions"]) == 0, "hapus statistik menghapus file")
	s2.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sp))


func _test_app_chatter() -> void:
	check(AppChatter.normalize(" Code ") == "code.exe", "normalisasi nama proses")
	check(AppChatter.friendly_name("code.exe") == "VS Code", "nama ramah aplikasi dikenal")
	check(AppChatter.friendly_name("my_cool-app.exe") == "My Cool App", "nama ramah aplikasi tak dikenal")
	var c := AppChatter.new(7)
	c.intensity = 1
	var first := c.on_foreground("code.exe", "deskbuddy.exe")
	check(first != "", "buka VS Code -> ada komentar")
	check(c.on_foreground("code.exe") == "", "aplikasi sama -> diam")
	check(c.on_foreground("explorer.exe") == "", "explorer/desktop diabaikan")
	check(c.on_foreground("deskbuddy.exe", "DeskBuddy.exe") == "", "aplikasi DeskBuddy sendiri diabaikan")
	check(c.on_foreground("chrome.exe") == "", "jeda global (8 dtk) -> diam")
	c.advance(9.0)
	check(c.on_foreground("code.exe") == "", "aplikasi sama dalam 5 menit -> diam")
	var chrome := c.on_foreground("chrome.exe")
	check(chrome != "", "aplikasi baru setelah jeda global -> komentar")
	c.advance(9.0)
	check(c.on_foreground("game.exe", "", true) == "", "aplikasi distraksi saat fokus -> diserahkan ke peringatan")
	c.advance(300.0)
	check(c.on_foreground("code.exe") != "", "setelah 5 menit boleh komentar lagi")
	check(c.on_foreground("") == "", "foreground tidak diketahui -> diam")
	for cat: String in AppChatter.LINES:
		for line: String in AppChatter.LINES[cat]:
			check(line.length() <= 60, "kalimat pendek: " + line)


func _test_native_headless() -> void:
	var n := NativeActivityProvider.new()
	check(not n.is_supported(), "headless -> native tidak didukung")
	n.ensure_running(true)
	check(not n.is_running() and not n.is_available(), "tidak menjalankan helper saat headless")
	check(n.get_idle_seconds() < 0.0 and n.get_foreground_process() == "", "data tidak diketahui")
	var src := FileAccess.get_file_as_string("res://native/probe/deskbuddy_probe.c")
	check(src.contains("GetLastInputInfo") and not src.contains("GetWindowText") and not src.contains("fopen"), "helper tidak membaca judul jendela / menulis file")
	check(NativeActivityProvider.probe_path() != "", "deskbuddy_probe.exe tersedia")
