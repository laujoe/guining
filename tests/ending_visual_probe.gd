extends RefCounted
## MCP visual probe. Never reads/writes a player save.
func prepare(app) -> void:
	app.core.save_path = "res://.test-output/ending-preview-save.json"
	app.core.settings_path = "res://.test-output/ending-preview-settings.json"
	app.close_modal()
	app.set_process(false)
	if app.get_window().focus_exited.is_connected(app._on_focus_lost):
		app.get_window().focus_exited.disconnect(app._on_focus_lost)
	app.core.reset_state()
	app.core.state.completed = ["Ding", "Student", "Wife"]
	app.core.state.jade = [0, 1, 2]
	app.core.state.inscription = true
	app.core.settings.reduced_motion = false
	app.core.settings.text_scale = 1.0

func capture(app, route: String, age: float, filename: String) -> Dictionary:
	app.go(route, false)
	app.scene_age = age
	app.accident_time = age
	app.transition_left = 0
	app.transition_view.visible = false
	app.stage.ending_sequence.sync(app)
	app.stage.queue_redraw()
	await app.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture = app.get_viewport().get_texture().get_image()
	var path = "res://.test-output/" + filename + ".png"
	return {"path": path, "error": picture.save_png(path), "size": str(picture.get_size())}

func play(app) -> void:
	prepare(app)
	app.go("accident_prompt", false)
	app.set_process(true)
