extends SceneTree
var app
var records: Array = []

func _initialize() -> void:
	call_deferred("run")

func shot(id: String, time = 4.0) -> void:
	app.scene_age = time
	app.line_age = time
	app.dialogue_entrance = 1
	app.update_transition(10)
	if is_instance_valid(app.dialogue_label): app.dialogue_label.visible_characters = app.current_text.length()
	for frame in range(3): await process_frame
	var image = root.get_texture().get_image()
	var file = "res://.test-output/revision-" + id + ".png"
	records.append({"file": file, "result": image.save_png(file), "size": str(image.get_size())})

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.core.save_path = "res://.test-output/revision-visual-save.json"
	app.core.settings_path = "res://.test-output/revision-visual-settings.json"
	root.add_child(app)
	await process_frame
	root.focus_exited.disconnect(app._on_focus_lost)
	root.size = Vector2i(1600, 900)
	app.close_modal()
	app.set_process(false)
	app.core.reset_state()
	app.go("hub")
	await shot("hub")
	app.core.state.memory = "Ding"
	app.go("ding_table")
	await shot("table", 5)
	app.core.state.shadow = {"node":"E", "view":1, "lamp":0.52}
	app.go("ding_graph")
	await shot("lamp2")
	app.core.state.memory = "Student"
	app.core.new_board()
	app.go("board")
	await shot("board")
	app.go("army")
	app.bullets = [{"p":Vector2(680, 430), "v":Vector2(-208, 0), "reflected":false, "target":0}]
	await shot("battle")
	app.core.state.memory = "Wife"
	app.say("WifeLetter", "letter_fold")
	app.core.settings.text_scale = 1.3
	app.clear_layer(app.ui)
	app.build_dialogue()
	await shot("letter130")
	app.say("WifeReflection", "wife_shard")
	app.core.state.dialogue.index = 6
	app.clear_layer(app.ui)
	app.build_dialogue()
	await shot("wife-snow", 2)
	app.core.state.completed = ["Ding", "Student", "Wife"]
	app.go("jade")
	await shot("jade")
	for i in range(3): app.core.place_jade(i)
	app.go("flip")
	app.core.flip_jade()
	app.jade_flip = 1
	await shot("inscription")
	app.core.event("DeathAcknowledged")
	app.go("accident")
	app.accident_time = 20
	await shot("water", 20)
	app.go("body")
	await shot("body", 14)
	app.core.release_report()
	app.core.event("ReplyChosen")
	app.go("finale")
	await shot("dinner", 21)
	app.core.event("SatDown")
	app.core.event("FinalDinnerCompleted")
	app.core.finish_game()
	app.show_codex()
	app.overlay.get_node("Person_3").pressed.emit()
	await shot("codex130")
	app.close_modal()
	var file = FileAccess.open("res://.test-output/revision-captures.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	file.close()
	print("REVISION CAPTURES: ", records.size())
	app.audio_player.stop()
	app.note_player.stop()
	app.audio_player.stream = null
	app.note_player.stream = null
	await create_timer(0.2).timeout
	app.queue_free()
	await process_frame
	quit()
