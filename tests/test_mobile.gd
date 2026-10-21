extends SceneTree

var checks = 0
var failures: Array = []
var app

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ", description)

func touch(index: int, pressed: bool, point: Vector2) -> void:
	var event = InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = point
	Input.parse_input_event(event)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.test-output")
	root.size = Vector2i(1600, 900)
	root.content_scale_size = Vector2i(1600, 900)
	Input.use_accumulated_input = false
	app = load("res://scenes/main.tscn").instantiate()
	app.core.save_path = "res://.test-output/mobile-save.json"
	app.core.settings_path = "res://.test-output/mobile-settings.json"
	app.touch_controls = true
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.close_modal()
	app.core.settings.reduced_motion = true
	app.go("army", false)
	await process_frame
	# Exercise the engine's multi-finger input dispatch, not just signal callbacks.
	touch(0, true, Vector2(310, 820))
	await process_frame
	expect(app.keyboard_vector().x > 0, "first finger holds battle movement")
	touch(1, true, Vector2(1190, 820))
	await process_frame
	expect(app.brush_time > 0 and app.keyboard_vector().x > 0, "second finger brushes while moving")
	touch(1, false, Vector2(1190, 820))
	await process_frame
	expect(app.keyboard_vector().x > 0, "releasing action retains movement finger")
	app.open_pause()
	expect(app.touch_actions.is_empty() and app.keyboard_vector() == Vector2.ZERO, "pause clears held touch state")
	expect(not app.ui.get_node("TouchBrush/Touch").is_processing_input(), "touch controls cannot swallow modal input")
	app.close_modal()
	expect(app.keyboard_vector() == Vector2.ZERO, "resume does not revive stale fingers")
	expect(app.ui.get_node("TouchBrush/Touch").is_processing_input(), "touch controls resume after modal")
	touch(0, false, Vector2(310, 820))
	app.core.reset_lantern_maze()
	app.go("ding_lamp", false)
	await process_frame
	touch(0, true, Vector2(280, 840))
	touch(1, true, Vector2(420, 840))
	await process_frame
	expect(app.touch_axis("MazeForward", "MazeBack") == 1 and app.touch_axis("MazeRight", "MazeLeft") == 1, "maze accepts forward and turn together")
	touch(1, false, Vector2(420, 840))
	await process_frame
	expect(app.touch_axis("MazeForward", "MazeBack") == 1 and app.touch_axis("MazeRight", "MazeLeft") == 0, "maze fingers release independently")
	app.show_maze_map()
	expect(app.touch_actions.is_empty(), "map clears movement")
	app.close_modal()
	touch(0, false, Vector2(280, 840))
	app.go("runner", false)
	await process_frame
	app.runner_tutorial = true
	app.tutorial_time = 8
	touch(0, true, Vector2(1050, 780))
	await process_frame
	app.update_runner(0.01)
	expect(app.bracing, "touch brace works in wind")
	touch(1, true, Vector2(400, 780))
	await process_frame
	expect(app.jump_buffer > 0 and app.touch_actions.has("brace"), "jump does not release brace finger")
	touch(0, false, Vector2(1050, 780))
	touch(1, false, Vector2(400, 780))
	app.go("hub", false)
	expect(app.touch_actions.is_empty(), "scene changes clear touch state")
	app.show_menu()
	expect(app.ui.has_node("ProjectLicense"), "main menu includes project licensing")
	app.show_project_license()
	expect(app.paused and app.overlay.has_node("CloseProjectLicense"), "license dialog opens")
	expect(FileAccess.file_exists("res://assets/legal/CODE-LICENSE.txt"), "offline code license exists")
	expect(FileAccess.file_exists("res://assets/legal/CC-BY-NC-SA-4.0.txt"), "offline content license exists")
	var report = FileAccess.open("res://.test-output/mobile-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks, "failures":failures}, "\t"))
	report.close()
	app.queue_free()
	await process_frame
	print("MOBILE: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
