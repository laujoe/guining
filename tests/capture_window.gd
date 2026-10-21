extends SceneTree
## Separate rendered window verifies real sizes; editor embedding overrides Window.size.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	app.core.save_path = "res://.test-output/window-save.json"
	app.core.settings_path = "res://.test-output/window-settings.json"
	root.add_child(app)
	await process_frame
	root.focus_exited.disconnect(app._on_focus_lost)
	root.mode = Window.MODE_WINDOWED
	app.close_modal()
	app.set_process(false)
	app.core.reset_state()
	app.core.state.memory = "Wife"
	app.core.settings.text_scale = 1.3
	app.say("WifeLetter", "wife_reflection")
	app.core.state.dialogue.index = 0
	app.clear_layer(app.ui)
	app.build_dialogue()
	app.dialogue_label.visible_characters = -1
	var records: Array = []
	for size in [Vector2i(1280,720), Vector2i(1280,800), Vector2i(1920,1080), Vector2i(2100,900)]:
		root.size = size
		for frame in range(8):
			await process_frame
		var image = root.get_texture().get_image()
		var path = "res://.test-output/window-%dx%d.png" % [size.x, size.y]
		var result = image.save_png(path)
		records.append({"requested":str(size),"window":str(root.size),"display_window":str(DisplayServer.window_get_size()),"viewport":str(image.get_size()),"file":path,"error":result})
	var report = FileAccess.open("res://.test-output/window-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(records,"\t"))
	report.close()
	app.audio_player.stop()
	app.note_player.stop()
	app.audio_player.stream = null
	app.note_player.stream = null
	await create_timer(0.2).timeout
	app.queue_free()
	await process_frame
	print("WINDOW CAPTURES: ", JSON.stringify(records))
	quit()
