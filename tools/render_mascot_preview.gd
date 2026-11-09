extends Node2D
## Visual QA: draws the critter in each state plus the control panel and saves
## PNGs. Needs a GPU (do not pass --headless):
##   godot --path . res://tools/render_mascot_preview.tscn -- <output dir>

const Mascot := preload("res://scripts/overlay/mascot.gd")
const ControlPanel := preload("res://scripts/ui/control_panel.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://preview"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var win := get_window()
	win.size = Vector2i(1500, 360)
	win.borderless = true
	var bg := ColorRect.new()
	bg.color = Color("dfe7ef")
	bg.size = Vector2(win.size)
	add_child(bg)

	var states := [
		["idle", "pink", 1], ["walk", "peach", 1], ["chat", "mint", 1],
		["remind", "pink", 1], ["sleepy", "lilac", 1], ["small", "sky", 0], ["big", "lemon", 2],
	]
	var mascots: Array = []
	for i in states.size():
		var m: Node2D = Mascot.new()
		add_child(m)
		var x := 110.0 + i * 205.0
		m.set_walk_area(x, x, 345.0)
		m.set_color_name(states[i][1])
		m.set_size_level(states[i][2])
		m.set("_state_time", 999.0)
		mascots.append(m)
	await get_tree().process_frame
	mascots[1].behavior = Mascot.Behavior.WALK
	mascots[1].set("_target_x", 5000.0)
	mascots[1].set_walk_area(-10000, 10000, 345.0)
	mascots[2].say("Ngoding di VS Code? Semangat!", 999.0)
	mascots[3].show_message("Waktu fokus selesai! Saatnya istirahat.")
	mascots[4].sleepy = true
	await _frames(50)
	mascots[1].position.x = 110.0 + 205.0
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join("critter_states.png"))
	print("saved critter_states.png")

	var panel: Window = ControlPanel.new()
	add_child(panel)
	panel.show_panel()
	await _frames(20)
	await RenderingServer.frame_post_draw
	panel.get_texture().get_image().save_png(out_dir.path_join("panel_sesi.png"))
	var tabs: TabContainer = panel.find_children("*", "TabContainer", true, false)[0]
	for i in [1, 2]:
		tabs.current_tab = i
		await _frames(10)
		await RenderingServer.frame_post_draw
		panel.get_texture().get_image().save_png(out_dir.path_join("panel_tab%d.png" % i))
	print("saved panel")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
