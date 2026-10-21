extends RefCounted

func run(app) -> Dictionary:
	app.core.save_path = "res://.test-output/paper-save.json"
	app.core.settings_path = "res://.test-output/paper-settings.json"
	if app.get_window().focus_exited.is_connected(app._on_focus_lost):
		app.get_window().focus_exited.disconnect(app._on_focus_lost)
	app.close_modal()
	app.set_process(false)
	app.stage.set_process(false)
	app.stage.clock = 0.23
	app.core.reset_state()
	app.core.state.memory = "Ding"
	app.go("ding_lamp")
	await capture(app, "paper-lamp")
	app.go("ding_graph")
	await capture(app, "paper-graph")
	app.core.state.memory = "Student"
	app.core.new_board()
	app.go("board")
	await capture(app, "paper-board")
	app.go("army")
	app.brush_time = 0.25
	app.facing = Vector2.RIGHT
	await capture(app, "paper-brush")
	app.facing = Vector2.LEFT
	await capture(app, "paper-brush-left")
	app.core.state.memory = "Wife"
	app.core.state.season = 0
	app.go("runner")
	await capture(app, "paper-run")
	app.jump_height = 100
	await capture(app, "paper-jump")
	app.jump_height = 0
	app.slide_time = 0.4
	await capture(app, "paper-slide")
	app.slide_time = 0
	app.bracing = true
	app.core.state.season = 3
	app.season_time = 20
	await capture(app, "paper-brace")
	app.go("body")
	await capture(app, "paper-body")
	app.core.reset_state()
	app.has_save = false
	app.show_menu()
	app.set_process(true)
	app.stage.set_process(true)
	app.get_window().focus_exited.connect(app._on_focus_lost)
	return {"captures":10,"status":"complete"}

func capture(app, filename: String) -> void:
	app.stage.queue_redraw()
	await app.get_tree().process_frame
	await RenderingServer.frame_post_draw
	app.get_viewport().get_texture().get_image().save_png("res://.test-output/" + filename + ".png")
