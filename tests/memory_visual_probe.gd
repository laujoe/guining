extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var directory = "res://.test-output/memory-visual-" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	var app = load("res://scenes/main.tscn").instantiate()
	app.core.save_path = directory + "/current.json"
	app.core.settings_path = directory + "/settings.json"
	root.add_child(app)
	await process_frame
	if root.focus_exited.is_connected(app._on_focus_lost): root.focus_exited.disconnect(app._on_focus_lost)
	app.set_process(false)
	app.core.settings.reduced_motion = true
	app.core.state.prologue = true
	app.core.save_game()
	app.has_save = true
	for title in ["初到渡口", "灯下留席", "记起一句被记住的教导", "记起一封未读的家书"]:
		app.memory_saves.save_memory(app.core.state, {"title": title, "source": "test"})
	root.mode = Window.MODE_WINDOWED
	var report: Array = []
	for sample in [{"name": "1280", "size": Vector2i(1280, 720), "scale": 1.0}, {"name": "960-text130", "size": Vector2i(960, 540), "scale": 1.3}]:
		root.size = sample.size
		app.core.settings.text_scale = sample.scale
		app.show_memory_atlas()
		for frame in range(12): await process_frame
		var picture = root.get_texture().get_image()
		var path = "res://.test-output/memory-atlas-" + sample.name + ".png"
		report.append({"path": path, "size": str(picture.get_size()), "error": picture.save_png(path)})
		if sample.scale > 1:
			var atlas = app.ui.get_node("MemoryAtlas")
			atlas.request_delete(atlas.entries[0].id)
			for frame in range(8): await process_frame
			root.get_texture().get_image().save_png("res://.test-output/memory-atlas-confirm.png")
			atlas.modal.hide()
			app.show_menu()
			for frame in range(8): await process_frame
			root.get_texture().get_image().save_png("res://.test-output/memory-menu-text130.png")
	var file = FileAccess.open("res://.test-output/memory-visual-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("MEMORY_VISUAL ", JSON.stringify(report))
	app.queue_free()
	await process_frame
	quit()
