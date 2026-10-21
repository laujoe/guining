extends SceneTree
## Rendered checks, isolated from all player data.
var app
var records: Array = []
func _initialize() -> void:
	call_deferred("run")
func shot(name_value: String) -> void:
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	var path = "res://.test-output/lantern-" + name_value + ".png"
	image.save_png(path)
	records.append({"file":path, "size":str(image.get_size()), "phase":app.core.state.lantern_maze.phase})
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.test-output")
	app = load("res://scenes/main.tscn").instantiate()
	app.core.save_path = "res://.test-output/lantern-window-save.json"
	app.core.settings_path = "res://.test-output/lantern-window-settings.json"
	root.add_child(app)
	await process_frame
	if root.focus_exited.is_connected(app._on_focus_lost): root.focus_exited.disconnect(app._on_focus_lost)
	app.close_modal()
	app.set_process(false)
	app.core.reset_state()
	app.core.state.memory = "Ding"
	app.core.settings.reduced_motion = true
	root.mode = Window.MODE_WINDOWED
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1920,1080)]:
		root.size = dimensions
		app.core.settings.text_scale = 1.3 if dimensions.x == 960 else 1.0
		app.go("ding_lamp", false)
		app.transition_view.visible = false
		await shot("maze-" + str(dimensions.x))
	root.size = Vector2i(1280,720)
	app.core.state.lantern_maze.x = 3.5 * app.core.MAZE_CELL
	app.core.state.lantern_maze.yaw = PI
	await shot("maze-turn")
	app.core.state.lantern_maze.x = 11.5 * app.core.MAZE_CELL
	app.core.state.lantern_maze.z = 9 * app.core.MAZE_CELL - 0.02
	app.core.step_lantern_maze(1,0,0.1)
	for age in [1.3, 2.8, 4.3, 6.2]:
		app.core.state.lantern_maze.echo_time = age
		app.refresh_lamp_feedback()
		await shot("memory-" + str(age))
	app.core.tick_lantern_echo(1)
	app.refresh_lamp_feedback()
	await shot("maze-recovered")
	var report = FileAccess.open("res://.test-output/lantern-visual-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(records, "\t"))
	report.close()
	app.queue_free()
	await process_frame
	print("LANTERN CAPTURES: ", records.size())
	quit()
