extends RefCounted
## Run by Godot AI MCP against the real rendered game. All saves are isolated.
func run(app) -> Dictionary:
	app.core.save_path = "res://.test-output/visual-save.json"
	app.core.settings_path = "res://.test-output/visual-settings.json"
	var old_settings: Dictionary = app.core.settings.duplicate(true)
	if app.get_window().focus_exited.is_connected(app._on_focus_lost):
		app.get_window().focus_exited.disconnect(app._on_focus_lost)
	app.close_modal()
	app.set_process(false)
	app.core.reset_state()
	app.core.settings.text_scale = 1.0
	var captures: Array = []
	app.go("hub")
	captures.append(await capture(app, "hub-final"))
	app.core.state.memory = "Wife"
	app.say("WifeDeparture", "runner")
	app.dialogue_label.visible_characters = -1
	captures.append(await capture(app, "dialogue-final"))
	app.core.state.memory = "Student"
	app.core.new_board()
	app.go("board")
	captures.append(await capture(app, "board-final"))
	app.core.state.memory = "Ding"
	app.core.state.lamp1 = 0.5
	app.go("ding_lamp")
	captures.append(await capture(app, "lamp-final"))
	app.core.state.shadow = {"node":"E", "view":1, "lamp":0.52}
	app.go("ding_graph")
	captures.append(await capture(app, "shadow-final"))
	app.core.state.memory = "Student"
	app.go("dragon")
	app.bullets = [{"p":Vector2(700, 400), "v":Vector2(-208,0), "reflected":false,"target":0}]
	captures.append(await capture(app, "battle-final"))
	app.core.state.memory = "Wife"
	app.core.state.season = 3
	app.go("runner")
	app.season_time = 20
	app.bracing = true
	captures.append(await capture(app, "winter-final"))
	app.core.state.completed = ["Ding", "Student", "Wife"]
	app.go("jade")
	captures.append(await capture(app, "jade-final"))
	app.core.settings.text_scale = 1.3
	app.core.state.memory = "Wife"
	app.say("WifeDeparture", "runner")
	app.dialogue_label.visible_characters = -1
	captures.append(await capture(app, "text130-final"))
	app.get_window().size = Vector2i(1280, 800)
	captures.append(await capture(app, "aspect16x10-final"))
	app.get_window().size = Vector2i(1920, 1080)
	captures.append(await capture(app, "1080-final"))
	app.get_window().size = Vector2i(1280, 720)
	app.open_settings()
	captures.append(await capture(app, "settings130-final"))
	app.close_modal()
	app.core.settings = old_settings
	app.core.reset_state()
	app.has_save = false
	app.show_menu()
	app.set_process(true)
	app.get_window().focus_exited.connect(app._on_focus_lost)
	var result = {"captures":captures,"failures":[]}
	var file = FileAccess.open("res://.test-output/visual-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	return result

func capture(app, filename: String) -> Dictionary:
	await app.get_tree().process_frame
	await app.get_tree().process_frame
	var image = app.get_viewport().get_texture().get_image()
	var path = "res://.test-output/" + filename + ".png"
	var error = image.save_png(path)
	return {"file":path,"error":error,"size":str(image.get_size())}
