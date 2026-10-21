extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var app = load("res://scenes/main.tscn").instantiate()
	app.core.save_path = "res://.test-output/mobile-visual-save.json"
	app.core.settings_path = "res://.test-output/mobile-visual-settings.json"
	app.touch_controls = true
	root.add_child(app)
	await process_frame
	if root.focus_exited.is_connected(app._on_focus_lost):
		root.focus_exited.disconnect(app._on_focus_lost)
	app.close_modal()
	app.set_process(false)
	app.core.reset_state()
	for route in ["menu", "army", "ding_lamp", "runner"]:
		if route == "menu": app.show_menu()
		else: app.go(route, false)
		app.transition_left = 0
		app.transition_view.visible = false
		for i in range(8): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.test-output/mobile-" + route + ".png")
	app.queue_free()
	await process_frame
	print("MOBILE_VISUAL: 4 captures")
	quit()
