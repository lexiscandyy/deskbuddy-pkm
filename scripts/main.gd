extends Node2D
## Overlay root. The main window is a transparent, borderless, always-on-top,
## non-focusable strip that sits on top of the taskbar edge of the work area
## (DisplayServer.screen_get_usable_rect). The mascot walks along its bottom.
##
## Click-through: the window's mouse_passthrough_polygon is kept to the
## mascot's bounding box, so clicks anywhere else reach the apps behind it.
## On Windows the area outside that polygon is also not drawn, which is fine
## because it is transparent anyway.
##
## Fallback "Jendela biasa": a normal decorated window with a background, for
## setups where per-pixel transparency does not work.

const Mascot := preload("res://scripts/overlay/mascot.gd")
const ControlPanel := preload("res://scripts/ui/control_panel.gd")
const ActivityProvider := preload("res://scripts/activity/activity_provider.gd")
const AppChatter := preload("res://scripts/core/app_chatter.gd")
const DistractionDetector := preload("res://scripts/core/distraction_detector.gd")
const PomodoroTimer := preload("res://scripts/core/pomodoro_timer.gd")

## Largest critter + hop + speech bubble + margin.
const OVERLAY_HEIGHT := 330
const WINDOW_MODE_SIZE := Vector2i(960, 450)
const SIDE_MARGIN := 50.0
const GROUND_OFFSET := 4.0
const REGION_SNAP := 32.0

var mascot: Node2D
var panel: Window

var _bg: ColorRect
var _tray: StatusIndicator
var _overlay_active := false
var _last_poly := PackedVector2Array()
var _chatter := AppChatter.new()
var _own_exe := OS.get_executable_path().get_file()


func _ready() -> void:
	_bg = ColorRect.new()
	_bg.color = Color("fff0f5")
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	mascot = Mascot.new()
	add_child(mascot)

	panel = ControlPanel.new()
	add_child(panel)

	_setup_tray()
	_apply_appearance()
	apply_window_mode()

	Settings.changed.connect(_on_setting_changed)
	Reminders.reminder_shown.connect(func(r: Dictionary) -> void: mascot.show_message(str(r["text"])))
	Reminders.reminder_cleared.connect(func(_k: String, _r: String) -> void: mascot.hide_message())
	Activity.state_changed.connect(func(s: int) -> void: mascot.sleepy = s == ActivityProvider.State.IDLE)
	Activity.foreground_changed.connect(_on_foreground_changed)
	panel.test_chat_requested.connect(func() -> void: mascot.say("Halo! Aku bakal komentar kalau kamu buka aplikasi~"))
	get_window().size_changed.connect(_layout)
	panel.show_panel()
	# `godot --path . -- --test-reminder` shows a sample bubble (for demo/QA).
	if "--test-reminder" in OS.get_cmdline_user_args():
		Reminders.show_reminder("test", "Halo! Ini contoh pengingat DeskBuddy.", 60.0)
	# `-- --test-sleepy` puts the mascot in the dozing state (for demo/QA).
	if "--test-sleepy" in OS.get_cmdline_user_args():
		mascot.sleepy = true


func apply_window_mode() -> void:
	var win := get_window()
	var usable := DisplayServer.screen_get_usable_rect(win.current_screen)
	_overlay_active = Settings.get_value("window_mode") == "overlay"
	if _overlay_active:
		win.borderless = true
		win.transparent = true
		get_viewport().transparent_bg = true
		win.always_on_top = true
		win.unfocusable = true
		win.size = Vector2i(usable.size.x, OVERLAY_HEIGHT)
		win.position = Vector2i(usable.position.x, usable.end.y - OVERLAY_HEIGHT)
		_last_poly = PackedVector2Array()
	else:
		win.mouse_passthrough_polygon = PackedVector2Array()
		win.transparent = false
		get_viewport().transparent_bg = false
		win.always_on_top = false
		win.unfocusable = false
		win.borderless = false
		win.title = "DeskBuddy - Maskot (mode jendela biasa)"
		win.size = WINDOW_MODE_SIZE
		@warning_ignore("integer_division")
		win.position = Vector2i(usable.position.x + (usable.size.x - WINDOW_MODE_SIZE.x) / 2, usable.end.y - WINDOW_MODE_SIZE.y - 80)
	_bg.visible = not _overlay_active
	_layout()


func _layout() -> void:
	var s := Vector2(get_window().size)
	_bg.size = s
	mascot.set_walk_area(SIDE_MARGIN, s.x - SIDE_MARGIN, s.y - GROUND_OFFSET)


func _process(delta: float) -> void:
	_chatter.advance(delta)
	if _overlay_active:
		_update_passthrough()


func _update_passthrough() -> void:
	var poly: PackedVector2Array
	if mascot.visible:
		var r: Rect2 = mascot.get_bounds().grow(12.0)
		# Snap to a coarse grid so the native window region is not rebuilt every frame.
		var x0 := floorf(r.position.x / REGION_SNAP) * REGION_SNAP
		var y0 := floorf(r.position.y / REGION_SNAP) * REGION_SNAP
		var x1 := ceilf(r.end.x / REGION_SNAP) * REGION_SNAP
		var y1 := ceilf(r.end.y / REGION_SNAP) * REGION_SNAP
		poly = PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
	else:
		# Hidden mascot: a 1 px region, i.e. nothing visible and everything clicks through.
		poly = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	if poly != _last_poly:
		_last_poly = poly
		get_window().mouse_passthrough_polygon = poly


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mascot.visible:
		if mascot.get_bounds().has_point(mb.position):
			mascot.poke()
			panel.show_panel()


func _apply_appearance() -> void:
	mascot.set_color_name(str(Settings.get_value("mascot_color")))
	mascot.set_intensity(int(Settings.get_value("intensity")))
	_chatter.intensity = int(Settings.get_value("intensity"))
	mascot.set_size_level(int(Settings.get_value("mascot_size")))
	mascot.visible = bool(Settings.get_value("mascot_visible"))


func _on_setting_changed(key: String) -> void:
	if key == "window_mode" or key == "*":
		apply_window_mode()
	if key in ["mascot_color", "intensity", "mascot_size", "mascot_visible", "*"]:
		_apply_appearance()


## Comment bubble when the user switches to / opens an app.
func _on_foreground_changed(process_name: String) -> void:
	if not bool(Settings.get_value("app_chat_enabled")) or not mascot.visible or Reminders.has_reminder():
		return
	# During focus, listed distraction apps get the distraction warning instead.
	var focus := AppState.pomodoro.phase == PomodoroTimer.Phase.FOCUS
	var listed := AppState.distraction.enabled and AppState.distraction.apps.has(DistractionDetector.normalize(process_name))
	var text := _chatter.on_foreground(process_name, _own_exe, focus and listed)
	if text != "":
		mascot.say(text)


func _setup_tray() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR):
		return
	_tray = StatusIndicator.new()
	_tray.tooltip = "DeskBuddy"
	_tray.icon = load("res://icon.svg")
	add_child(_tray)
	var menu := PopupMenu.new()
	menu.add_item("Buka panel kontrol", 0)
	menu.add_item("Tampilkan / sembunyikan maskot", 1)
	menu.add_separator()
	menu.add_item("Keluar", 2)
	menu.id_pressed.connect(_on_tray_menu)
	add_child(menu)
	_tray.menu = _tray.get_path_to(menu)
	_tray.pressed.connect(func(button: int, _pos: Vector2i) -> void:
		if button == MOUSE_BUTTON_LEFT:
			panel.show_panel())


func _on_tray_menu(id: int) -> void:
	match id:
		0:
			panel.show_panel()
		1:
			Settings.set_value("mascot_visible", not bool(Settings.get_value("mascot_visible")))
		2:
			get_tree().quit()
