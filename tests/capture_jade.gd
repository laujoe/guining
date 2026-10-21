extends SceneTree
var app

func _initialize() -> void:
	call_deferred("run")

func shot(id: String) -> void:
	app.dialogue_entrance = 1.0
	app.update_transition(10)
	if is_instance_valid(app.dialogue_label): app.dialogue_label.visible_characters = -1
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var result = root.get_texture().get_image().save_png("res://.test-output/jade-" + id + ".png")
	assert(result == OK)

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.core.save_path = "res://.test-output/jade-capture-save.json"
	app.core.settings_path = "res://.test-output/jade-capture-settings.json"
	root.add_child(app)
	await process_frame
	if root.focus_exited.is_connected(app._on_focus_lost): root.focus_exited.disconnect(app._on_focus_lost)
	root.size = Vector2i(1600, 900)
	app.close_modal()
	app.set_process(false)
	app.core.reset_state()
	app.core.state.completed = ["Ding", "Student", "Wife"]
	app.go("hub")
	await shot("hud")
	app.go("jade")
	await shot("pieces")
	for id in range(3):
		app.selected_jade = id
		app.jade_positions[id] = Vector2(800, 430)
		app.place_selected_jade()
	await shot("assembled")
	assert(not app.core.state.inscription)
	app.core.flip_jade()
	app.jade_flip = 1.0
	await shot("back")
	app.core.state.memory = "Wife"
	app.say("WifeReflection", "wife_shard")
	for i in range(app.core.dialogue.WifeReflection.lines.size()):
		if app.core.dialogue.WifeReflection.lines[i].get("cue", "") == "jade": app.core.state.dialogue.index = i
	app.clear_layer(app.ui)
	app.build_dialogue()
	app.line_age = 4.0
	await shot("gift")
	for id in range(3):
		app.core.state.memory = app.core.MEMORY_IDS[id]
		app.go("fragment")
		await shot("fragment-" + str(id))
	app.audio_player.stop()
	app.note_player.stop()
	app.audio_player.stream = null
	app.note_player.stream = null
	app.queue_free()
	await process_frame
	print("JADE CAPTURE: 8 screenshots; isolated saves")
	quit()
