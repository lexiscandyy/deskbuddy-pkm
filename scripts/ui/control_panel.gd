extends Window
## Separate, focusable control window with the cartoon theme (cartoon_theme.gd).
## Reads state from AppState / Activity / Settings and writes back only
## through their public methods. Closing the window minimizes it;
## "Keluar DeskBuddy" quits the app.

signal test_chat_requested

const ActivityProvider := preload("res://scripts/activity/activity_provider.gd")
const PomodoroTimer := preload("res://scripts/core/pomodoro_timer.gd")
const CartoonTheme := preload("res://scripts/ui/cartoon_theme.gd")
const CritterArt := preload("res://scripts/overlay/critter_art.gd")

const INTENSITY_NAMES := ["Tenang", "Sedang", "Aktif"]
const SIZE_NAMES := ["Kecil", "Sedang", "Besar"]
const INK := CartoonTheme.INK
const MUTED := CartoonTheme.MUTED

var _status_label: Label
var _sim_badge: Label
var _icon: CritterIcon
var _banner: PanelContainer
var _banner_label: Label
var _banner_snooze: Button

var _mode_option: OptionButton
var _supervisor_box: VBoxContainer
var _ambient_box: VBoxContainer
var _goal_edit: LineEdit
var _focus_spin: SpinBox
var _break_spin: SpinBox
var _demo_check: CheckBox
var _countdown_label: Label
var _phase_label: Label
var _start_btn: Button
var _pause_btn: Button
var _resume_btn: Button
var _end_btn: Button
var _gap_label: Label

var _ambient_time_label: Label
var _ambient_activity_label: Label
var _eye_check: CheckBox
var _eye_interval_spin: SpinBox
var _eye_next_label: Label

var _monitor_check: CheckBox
var _sim_check: CheckBox
var _provider_label: Label
var _activity_label: Label
var _idle_spin: SpinBox
var _sim_box: PanelContainer
var _sim_fg_edit: LineEdit
var _chat_check: CheckBox
var _distraction_check: CheckBox
var _apps_edit: LineEdit
var _delay_spin: SpinBox
var _cooldown_spin: SpinBox

var _color_buttons: Array[Button] = []
var _intensity_option: OptionButton
var _size_option: OptionButton
var _visible_check: CheckBox
var _window_mode_option: OptionButton
var _stats_label: Label
var _confirm: ConfirmationDialog

var _loading := false


## Small animated critter for the header.
class CritterIcon extends Control:
	var color := Color("ff9ec4")
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(64, 64)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		# Only animate while the panel is on screen (saves redraws when minimized).
		var w := get_window()
		if w == null or not w.visible or w.mode == Window.MODE_MINIMIZED:
			return
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var s := 0.56
		var squash := 1.0 + sin(_t * 2.4) * 0.03
		draw_set_transform(Vector2(size.x * 0.5, size.y - 2.0), 0.0, Vector2(s / sqrt(squash), s * squash))
		var blink := fmod(_t, 3.7) < 0.12
		CritterArt.draw(self, {"color": color, "t": _t, "eyes": "blink" if blink else "open"})


func _init() -> void:
	title = "DeskBuddy - Panel Kontrol"
	size = Vector2i(540, 780)
	min_size = Vector2i(460, 560)
	visible = false
	theme = CartoonTheme.get_theme()
	close_requested.connect(func() -> void: mode = Window.MODE_MINIMIZED)


func _ready() -> void:
	_build()
	_load_from_settings()
	AppState.changed.connect(_refresh)
	Activity.state_changed.connect(func(_s: int) -> void: _refresh())
	Reminders.reminder_shown.connect(_on_reminder_shown)
	Reminders.reminder_cleared.connect(func(_k: String, _r: String) -> void: _banner.visible = false)
	Settings.changed.connect(func(key: String) -> void:
		if key == "*":
			_load_from_settings()
		elif key == "mascot_color":
			_icon.color = CritterArt.color_for(str(Settings.get_value("mascot_color"))))
	Settings.stats_cleared.connect(_refresh)
	_refresh()


func show_panel() -> void:
	if not visible:
		var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		position = usable.position + Vector2i(usable.size.x - size.x - 40, 40)
		show()
	if mode == Window.MODE_MINIMIZED:
		mode = Window.MODE_WINDOWED
	grab_focus()


# ------------------------------------------------------------------ build

func _build() -> void:
	var bg := PanelContainer.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = CartoonTheme.BG
	sb.set_content_margin_all(16)
	bg.add_theme_stylebox_override("panel", sb)
	add_child(bg)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	bg.add_child(root)

	# header
	var head_card := PanelContainer.new()
	head_card.theme_type_variation = "TimerCard"
	root.add_child(head_card)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head_card.add_child(head)
	_icon = CritterIcon.new()
	head.add_child(_icon)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	head.add_child(titles)
	var title_label := _label("DeskBuddy", titles)
	title_label.add_theme_font_override("font", CartoonTheme.font(900))
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_constant_override("outline_size", 9)
	_status_label = _label("", titles)
	_status_label.add_theme_font_size_override("font_size", 13)
	_sim_badge = _label("SIMULASI", head)
	_sim_badge.theme_type_variation = "Badge"
	_sim_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sim_badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	_sim_badge.tooltip_text = "Data aktivitas berasal dari tombol simulasi, bukan dari Windows."
	_sim_badge.mouse_filter = Control.MOUSE_FILTER_PASS

	# reminder banner (sticky note)
	_banner = PanelContainer.new()
	_banner.theme_type_variation = "NoteCard"
	var bbox := VBoxContainer.new()
	_banner.add_child(bbox)
	_banner_label = _label("", bbox)
	_banner_label.add_theme_font_override("font", CartoonTheme.font(800))
	var bbtn := HBoxContainer.new()
	bbox.add_child(bbtn)
	_banner_snooze = _button("Tunda", bbtn, func() -> void: Reminders.snooze(), "LemonButton")
	_button("Tutup", bbtn, func() -> void: Reminders.dismiss())
	_banner.visible = false
	root.add_child(_banner)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)
	_build_session_tab(_tab(tabs, "Sesi"))
	_build_activity_tab(_tab(tabs, "Aktivitas"))
	_build_appearance_tab(_tab(tabs, "Tampilan"))
	_build_privacy_tab(_tab(tabs, "Privasi"))

	var quit_btn := _button("Keluar DeskBuddy", root, func() -> void: get_tree().quit(), "CoralButton")
	quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_END

	_confirm = ConfirmationDialog.new()
	_confirm.title = "Hapus statistik"
	_confirm.dialog_text = "Hapus semua statistik lokal (waktu aktif dan jumlah sesi fokus)? Tindakan ini tidak bisa dibatalkan."
	_confirm.ok_button_text = "Hapus"
	_confirm.cancel_button_text = "Batal"
	_confirm.confirmed.connect(func() -> void: Settings.clear_stats())
	add_child(_confirm)


func _build_session_tab(t: VBoxContainer) -> void:
	var mode_card := _card(t, "Mode")
	_mode_option = OptionButton.new()
	_mode_option.add_item("Supervisor (Pomodoro + target)", 0)
	_mode_option.add_item("Ambient (waktu layar + 20-20-20)", 1)
	_mode_option.item_selected.connect(func(i: int) -> void: AppState.set_mode(i))
	mode_card.add_child(_mode_option)
	_hint("Berpindah mode akan mengakhiri sesi yang sedang berjalan.", mode_card)

	# --- Supervisor
	_supervisor_box = VBoxContainer.new()
	_supervisor_box.add_theme_constant_override("separation", 12)
	t.add_child(_supervisor_box)

	var timer_card := PanelContainer.new()
	timer_card.theme_type_variation = "TimerCard"
	_supervisor_box.add_child(timer_card)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	timer_card.add_child(tv)
	_countdown_label = _label("25:00", tv)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_override("font", CartoonTheme.font(900))
	_countdown_label.add_theme_font_size_override("font_size", 64)
	_countdown_label.add_theme_color_override("font_color", Color.WHITE)
	_countdown_label.add_theme_constant_override("outline_size", 14)
	_phase_label = _label("", tv)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.add_theme_font_override("font", CartoonTheme.font(800))
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 8)
	tv.add_child(btns)
	_start_btn = _button("Mulai", btns, func() -> void: AppState.start_session(_goal_edit.text), "MintButton")
	_pause_btn = _button("Jeda", btns, func() -> void: AppState.pause_session(), "LemonButton")
	_resume_btn = _button("Lanjut", btns, func() -> void: AppState.resume_session(), "SkyButton")
	_end_btn = _button("Akhiri", btns, func() -> void: AppState.end_session(), "CoralButton")
	_gap_label = _label("", tv)
	_gap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var plan := _card(_supervisor_box, "Rencana sesi")
	_goal_edit = LineEdit.new()
	_goal_edit.placeholder_text = "mis. Menulis Bab 2 proposal PKM"
	_goal_edit.max_length = 120
	_row(plan, "Target sesi", _goal_edit)
	_focus_spin = _spin(1, 180, 1, " menit")
	_focus_spin.value_changed.connect(func(v: float) -> void: _save_setting("focus_min", v))
	_row(plan, "Durasi fokus", _focus_spin)
	_break_spin = _spin(1, 60, 1, " menit")
	_break_spin.value_changed.connect(func(v: float) -> void: _save_setting("break_min", v))
	_row(plan, "Durasi jeda", _break_spin)
	_demo_check = _check("Durasi demo (fokus 30 dtk, jeda 10 dtk, 20-20-20 tiap 45 dtk, idle 5 dtk)", plan,
		func(b: bool) -> void: _save_setting("demo_mode", b))
	_hint("Perubahan durasi berlaku mulai fase berikutnya.", plan)

	# --- Ambient
	_ambient_box = VBoxContainer.new()
	_ambient_box.add_theme_constant_override("separation", 12)
	t.add_child(_ambient_box)
	var amb_card := PanelContainer.new()
	amb_card.theme_type_variation = "TimerCard"
	_ambient_box.add_child(amb_card)
	var av := VBoxContainer.new()
	amb_card.add_child(av)
	var amb_title := _label("Waktu aktif hari ini", av)
	amb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amb_title.add_theme_font_override("font", CartoonTheme.font(800))
	_ambient_time_label = _label("", av)
	_ambient_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ambient_time_label.add_theme_font_override("font", CartoonTheme.font(900))
	_ambient_time_label.add_theme_font_size_override("font_size", 40)
	_ambient_time_label.add_theme_color_override("font_color", Color.WHITE)
	_ambient_time_label.add_theme_constant_override("outline_size", 12)
	_ambient_activity_label = _label("", av)
	_ambient_activity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint("Perkiraan. Waktu aktif hanya bertambah saat komputer aktif. Idle atau status tidak diketahui tidak dihitung.", _ambient_box)
	var eye := _card(_ambient_box, "Istirahat mata 20-20-20")
	_eye_check = _check("Ingatkan aku", eye, func(b: bool) -> void: _save_setting("eye_enabled", b))
	_eye_interval_spin = _spin(1, 120, 1, " menit")
	_eye_interval_spin.value_changed.connect(func(v: float) -> void: _save_setting("eye_interval_min", v))
	_row(eye, "Interval", _eye_interval_spin)
	_eye_next_label = _label("", eye)
	_button("Tunda pengingat mata", eye, func() -> void: AppState.snooze_eye(), "LemonButton")


func _build_activity_tab(t: VBoxContainer) -> void:
	var mon := _card(t, "Pemantauan")
	_monitor_check = _check("Pemantauan aktivitas aktif", mon, func(b: bool) -> void: _save_setting("monitoring_enabled", b))
	_sim_check = _check("Mode Simulasi (untuk demo, bukan data Windows)", mon, func(b: bool) -> void: _save_setting("simulation_enabled", b))
	_activity_label = _label("", mon)
	_activity_label.add_theme_font_override("font", CartoonTheme.font(800))
	_provider_label = _hint("", mon)
	_idle_spin = _spin(5, 3600, 5, " detik")
	_idle_spin.value_changed.connect(func(v: float) -> void: _save_setting("idle_threshold_sec", v))
	_row(mon, "Dianggap idle setelah", _idle_spin)

	_sim_box = PanelContainer.new()
	_sim_box.theme_type_variation = "NoteCard"
	t.add_child(_sim_box)
	var sim := VBoxContainer.new()
	sim.add_theme_constant_override("separation", 8)
	_sim_box.add_child(sim)
	_label("Kontrol simulasi", sim).theme_type_variation = "Heading"
	var sb := HBoxContainer.new()
	sim.add_child(sb)
	_button("Simulasikan aktif", sb, func() -> void:
		Activity.mock.set_idle(false)
		Activity.sample(), "MintButton")
	_button("Simulasikan idle", sb, func() -> void:
		Activity.mock.set_idle(true)
		Activity.sample(), "SkyButton")
	_sim_fg_edit = LineEdit.new()
	_sim_fg_edit.placeholder_text = "mis. code.exe lalu Enter"
	var apply_fg := func(s: String) -> void:
		Activity.mock.foreground_process = s
		Activity.sample()
	_sim_fg_edit.text_submitted.connect(apply_fg)
	_sim_fg_edit.focus_exited.connect(func() -> void: apply_fg.call(_sim_fg_edit.text))
	_row(sim, "Aplikasi aktif", _sim_fg_edit)

	var chat := _card(t, "Komentar aplikasi")
	_chat_check = _check("Maskot berkomentar saat aku membuka aplikasi", chat,
		func(b: bool) -> void: _save_setting("app_chat_enabled", b))
	_hint("Contoh: buka VS Code, lalu maskot bilang \"Ngoding di VS Code? Semangat!\". Hanya nama .exe aplikasi aktif yang dibaca, dipakai sesaat, dan tidak disimpan. Seberapa sering ia berkomentar mengikuti Intensitas interaksi di tab Tampilan.", chat)
	_button("Tes komentar", chat, func() -> void: test_chat_requested.emit(), "SkyButton")

	var dis := _card(t, "Peringatan distraksi")
	_distraction_check = _check("Ingatkan saat aplikasi pilihanku terbuka selama sesi fokus", dis,
		func(b: bool) -> void: _save_setting("distraction_enabled", b))
	_apps_edit = LineEdit.new()
	_apps_edit.placeholder_text = "mis. game.exe, discord.exe"
	_apps_edit.text_submitted.connect(func(s: String) -> void: _save_setting("distraction_apps", s))
	_apps_edit.focus_exited.connect(func() -> void: _save_setting("distraction_apps", _apps_edit.text))
	_row(dis, "Daftar aplikasi", _apps_edit)
	_hint("Pisahkan dengan koma, tekan Enter untuk menyimpan. Browser hanya dihitung jika kamu sendiri menambahkannya (mis. chrome.exe).", dis)
	_delay_spin = _spin(1, 120, 1, " detik")
	_delay_spin.value_changed.connect(func(v: float) -> void: _save_setting("distraction_delay_sec", v))
	_row(dis, "Ingatkan setelah", _delay_spin)
	_cooldown_spin = _spin(10, 3600, 5, " detik")
	_cooldown_spin.value_changed.connect(func(v: float) -> void: _save_setting("distraction_cooldown_sec", v))
	_row(dis, "Jarak antar-pengingat", _cooldown_spin)


func _build_appearance_tab(t: VBoxContainer) -> void:
	var look := _card(t, "Maskot")
	_label("Warna", look)
	var swatches := HBoxContainer.new()
	swatches.add_theme_constant_override("separation", 10)
	look.add_child(swatches)
	var group := ButtonGroup.new()
	for i in CritterArt.COLOR_ORDER.size():
		var key: String = CritterArt.COLOR_ORDER[i]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(42, 42)
		b.tooltip_text = CritterArt.COLOR_LABELS[i]
		var col := CritterArt.color_for(key)
		var normal := CartoonTheme.box(col, 21, 3, 3, 0.0)
		var sel := CartoonTheme.box(col, 21, 3, 6, 0.0)
		var hover := CartoonTheme.box(col.lightened(0.15), 21, 3, 3, 0.0)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", sel)
		b.add_theme_stylebox_override("hover_pressed", sel)
		b.add_theme_font_override("font", CartoonTheme.font(900))
		b.toggled.connect(func(on: bool) -> void:
			b.text = "✓" if on else ""
			if on:
				_save_setting("mascot_color", key))
		swatches.add_child(b)
		_color_buttons.append(b)
	_size_option = OptionButton.new()
	for i in SIZE_NAMES.size():
		_size_option.add_item(SIZE_NAMES[i], i)
	_size_option.item_selected.connect(func(i: int) -> void: _save_setting("mascot_size", i))
	_row(look, "Ukuran", _size_option)
	_intensity_option = OptionButton.new()
	for i in INTENSITY_NAMES.size():
		_intensity_option.add_item(INTENSITY_NAMES[i], i)
	_intensity_option.item_selected.connect(func(i: int) -> void: _save_setting("intensity", i))
	_row(look, "Intensitas interaksi", _intensity_option)
	_visible_check = _check("Tampilkan maskot", look, func(b: bool) -> void: _save_setting("mascot_visible", b))

	var win := _card(t, "Jendela maskot")
	_window_mode_option = OptionButton.new()
	_window_mode_option.add_item("Overlay transparan di atas taskbar", 0)
	_window_mode_option.add_item("Jendela biasa (cadangan demo)", 1)
	_window_mode_option.item_selected.connect(func(i: int) -> void: _save_setting("window_mode", "overlay" if i == 0 else "window"))
	win.add_child(_window_mode_option)
	_hint("Pakai \"Jendela biasa\" jika overlay transparan tidak tampil di komputer ini. Klik maskot atau ikon tray untuk membuka panel ini.", win)
	var tests := HBoxContainer.new()
	win.add_child(tests)
	_button("Tes pengingat", tests, func() -> void:
		Reminders.show_reminder("test", "Halo! Ini contoh pengingat DeskBuddy.", 6.0), "PinkButton")
	_button("Tes komentar", tests, func() -> void: test_chat_requested.emit(), "SkyButton")


func _build_privacy_tab(t: VBoxContainer) -> void:
	var stored := _card(t, "Disimpan di komputer ini saja")
	_label("• Preferensi (mode, durasi, warna, daftar aplikasi pilihanmu).\n• Statistik agregat hari ini: perkiraan waktu aktif dan jumlah sesi fokus selesai.", stored)
	var never := _card(t, "Tidak pernah disimpan")
	_label("Isi ketikan, judul jendela, URL, screenshot, atau riwayat aplikasi. Nama aplikasi aktif hanya dipakai sesaat untuk komentar maskot dan peringatan distraksi.", never)
	var data := _card(t, "Statistik")
	_stats_label = _label("", data)
	var row := HBoxContainer.new()
	data.add_child(row)
	_button("Hapus statistik lokal", row, func() -> void: _confirm.popup_centered(), "CoralButton")
	_button("Buka folder data", row, func() -> void: OS.shell_open(ProjectSettings.globalize_path("user://")))


# --------------------------------------------------------------- helpers

func _tab(tabs: TabContainer, tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 6)
	scroll.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)
	tabs.add_child(scroll)
	return vb


## White sticker card with a heading; returns its content box.
func _card(parent: Node, heading: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	parent.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)
	if heading != "":
		_label(heading, vb).theme_type_variation = "Heading"
	return vb


func _label(text: String, parent: Node) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _hint(text: String, parent: Node) -> Label:
	var l := _label(text, parent)
	l.theme_type_variation = "Hint"
	return l


func _button(text: String, parent: Node, cb: Callable, variation := "") -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _check(text: String, parent: Node, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.toggled.connect(cb)
	parent.add_child(c)
	return c


func _spin(min_v: float, max_v: float, step: float, suffix: String) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.suffix = suffix
	return s


func _row(parent: Node, text: String, control: Control) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(150, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(control)
	parent.add_child(hb)


func _save_setting(key: String, value: Variant) -> void:
	if not _loading:
		Settings.set_value(key, value)


# --------------------------------------------------------------- sync

func _load_from_settings() -> void:
	_loading = true
	_focus_spin.value = float(Settings.get_value("focus_min"))
	_break_spin.value = float(Settings.get_value("break_min"))
	_demo_check.button_pressed = bool(Settings.get_value("demo_mode"))
	_eye_check.button_pressed = bool(Settings.get_value("eye_enabled"))
	_eye_interval_spin.value = float(Settings.get_value("eye_interval_min"))
	_monitor_check.button_pressed = bool(Settings.get_value("monitoring_enabled"))
	_sim_check.button_pressed = bool(Settings.get_value("simulation_enabled"))
	_idle_spin.value = float(Settings.get_value("idle_threshold_sec"))
	_chat_check.button_pressed = bool(Settings.get_value("app_chat_enabled"))
	_distraction_check.button_pressed = bool(Settings.get_value("distraction_enabled"))
	_apps_edit.text = str(Settings.get_value("distraction_apps"))
	_delay_spin.value = float(Settings.get_value("distraction_delay_sec"))
	_cooldown_spin.value = float(Settings.get_value("distraction_cooldown_sec"))
	var color_key := str(Settings.get_value("mascot_color"))
	var ci := maxi(0, CritterArt.COLOR_ORDER.find(color_key))
	_color_buttons[ci].button_pressed = true
	_icon.color = CritterArt.color_for(color_key)
	_intensity_option.select(clampi(int(Settings.get_value("intensity")), 0, INTENSITY_NAMES.size() - 1))
	_size_option.select(clampi(int(Settings.get_value("mascot_size")), 0, SIZE_NAMES.size() - 1))
	_visible_check.button_pressed = bool(Settings.get_value("mascot_visible"))
	_window_mode_option.select(0 if Settings.get_value("window_mode") == "overlay" else 1)
	_loading = false
	_refresh()


func _refresh() -> void:
	if _status_label == null:
		return
	var p := AppState.pomodoro
	var supervisor := AppState.mode == AppState.Mode.SUPERVISOR
	var act := Activity.state_name(Activity.state)
	var sim := Activity.is_simulation()

	_mode_option.select(AppState.mode)
	_supervisor_box.visible = supervisor
	_ambient_box.visible = not supervisor
	_sim_badge.visible = sim
	_status_label.text = "%s  •  %s  •  Komputer: %s%s" % [
		AppState.mode_name(), AppState.phase_text(), act, " (Simulasi)" if sim else ""]

	# Supervisor
	var none := p.phase == PomodoroTimer.Phase.NONE
	_countdown_label.text = AppState.format_countdown(Settings.focus_seconds() if none else p.remaining)
	_phase_label.text = AppState.phase_text() + ("" if none or p.goal == "" else "  -  " + p.goal)
	_goal_edit.editable = none
	_start_btn.disabled = not none
	_pause_btn.disabled = not p.is_running()
	_resume_btn.disabled = not p.paused
	_end_btn.disabled = none
	_gap_label.text = AppState.gap_notice
	_gap_label.visible = AppState.gap_notice != ""

	# Ambient
	_ambient_time_label.text = AppState.format_duration(AppState.ambient.active_seconds)
	_ambient_activity_label.text = "Aktivitas komputer: %s%s" % [act, " (Simulasi)" if sim else ""]
	_eye_next_label.text = AppState.eye_status_text()

	# Activity tab
	_provider_label.text = Activity.status_text()
	_activity_label.text = "Status saat ini: %s" % act
	_sim_box.visible = sim

	# Privacy
	_stats_label.text = "Hari ini (%s): waktu aktif %s, sesi fokus selesai %d." % [
		Settings.stats.get("date", "-"), AppState.format_duration(AppState.ambient.active_seconds),
		int(Settings.stats.get("focus_sessions", 0))]


func _on_reminder_shown(r: Dictionary) -> void:
	_banner_label.text = str(r["text"])
	_banner_snooze.visible = bool(r.get("can_snooze", false))
	_banner.visible = true
