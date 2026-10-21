extends SceneTree
## Isolated rendering and motion checks; never touches the player's save.
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL ARRIVAL: ", message)

func run() -> void:
	create_timer(30.0).timeout.connect(func(): printerr("FAIL ARRIVAL: probe timed out"); quit(1))
	DirAccess.make_dir_recursive_absolute("res://.test-output")
	var app = load("res://scenes/main.tscn").instantiate()
	app.core.save_path = "res://.test-output/wife-arrival-probe-save.json"
	app.core.settings_path = "res://.test-output/wife-arrival-probe-settings.json"
	root.add_child(app)
	await process_frame
	if root.focus_exited.is_connected(app._on_focus_lost): root.focus_exited.disconnect(app._on_focus_lost)
	app.close_modal()
	app.set_process(false)
	app.stage.set_process(false)
	app.core.reset_state()
	app.core.settings.reduced_motion = false
	app.core.state.memory = "Wife"
	root.size = Vector2i(1280, 720)
	var records: Array = []
	var wind_pixels = PackedByteArray()
	for sample in [
		{"name":"homeward", "age":3.0},
		{"name":"reunion", "age":9.0},
		{"name":"wind", "age":15.0},
		{"name":"wind-motion", "age":16.0},
		{"name":"dialogue130", "age":2.0},
		{"name":"still", "age":15.0}]:
		app.core.settings.reduced_motion = sample.name == "still"
		if sample.name == "dialogue130":
			app.core.settings.text_scale = 1.3
			app.say("WifeDeparture", "runner")
			app.dialogue_label.visible_characters = -1
		else: app.go("wife_arrival", false)
		app.scene_age = sample.age
		app.transition_view.visible = false
		app.stage.wife_arrival.sync(app)
		app.stage.queue_redraw()
		for frame in range(4): await process_frame
		var picture = root.get_texture().get_image()
		if sample.name == "wind": wind_pixels = picture.get_data()
		if sample.name == "wind-motion": check(picture.get_data() != wind_pixels, "wind effects change rendered pixels")
		if sample.name == "still":
			app.scene_age += 0.5
			app.stage.wife_arrival.sync(app)
			app.stage.queue_redraw()
			for frame in range(4): await process_frame
			check(root.get_texture().get_image().get_data() == picture.get_data(), "reduced motion freezes rendered scene")
		var path = "res://.test-output/wife-arrival-" + sample.name + ".png"
		check(picture.save_png(path) == OK, "capture " + sample.name)
		records.append({"file":path, "size":str(picture.get_size()), "shot":app.stage.wife_arrival.shot_state.duplicate()})
	# Pause must freeze scene time and therefore every shader effect.
	app.go("wife_arrival", false)
	app.scene_age = 9.0
	app.open_pause()
	app._process(3.0)
	check(is_equal_approx(app.scene_age, 9.0), "pause freezes shot clock")
	app.close_modal()
	app._process(app.stage.WifeArrival.DURATION)
	check(app.mode == "dialogue" and app.core.state.dialogue.id == "WifeDeparture", "film reaches authored dialogue")
	check(not app.transition_view.visible, "film to dialogue has no stale frame overlay")
	app.go("wife_arrival", false)
	app.ui.get_node("SkipArrival").pressed.emit()
	check(app.mode == "dialogue", "skip preserves dialogue")
	app.line_age = 10.0
	app.advance_dialogue()
	app.advance_dialogue()
	check(app.mode == "runner" and app.runner_tutorial, "dialogue enters chase tutorial")
	check(app.core.state.completed.is_empty(), "presentation grants no shards")
	app.stage.wife_arrival.sync(app)
	check(not app.stage.wife_arrival.visible, "film hides during gameplay")
	var report = FileAccess.open("res://.test-output/wife-arrival-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"captures":records, "failures":failures}, "\t"))
	report.close()
	app.audio_player.stop()
	app.note_player.stop()
	app.queue_free()
	await process_frame
	print("WIFE ARRIVAL: ", records.size(), " captures, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
