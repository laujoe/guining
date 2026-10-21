extends SceneTree
## Render authored story beats against isolated data, including large text.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.test-output")
	var app = load("res://scenes/main.tscn").instantiate()
	app.core.save_path = "res://.test-output/ding-story-visual-save.json"
	app.core.settings_path = "res://.test-output/ding-story-visual-settings.json"
	root.add_child(app)
	await process_frame
	if root.focus_exited.is_connected(app._on_focus_lost):
		root.focus_exited.disconnect(app._on_focus_lost)
	app.close_modal()
	app.set_process(false)
	app.stage.set_process(false)
	app.core.reset_state()
	app.core.state.memory = "Ding"
	app.core.settings.reduced_motion = false
	root.size = Vector2i(1280, 720)
	var records: Array = []
	for sample in [
		{"name":"entry", "route":"ding_table", "id":"", "age":3.0, "text":1.0},
		{"name":"offer", "route":"ding_place", "id":"", "age":6.0, "text":1.0},
		{"name":"rest", "route":"dialogue", "id":"DingDinner", "age":2.0, "text":1.0},
		{"name":"past130", "route":"dialogue", "id":"DingPastChoice", "age":2.0, "text":1.3},
		{"name":"empty", "route":"dialogue", "id":"DingReflection", "age":2.0, "text":1.0},
		{"name":"rain", "route":"dialogue", "id":"DingShardEcho", "age":2.0, "text":1.0}]:
		app.core.settings.text_scale = sample.text
		if sample.id != "":
			app.say(sample.id, "ding_seat")
			app.dialogue_label.visible_characters = -1
		else:
			app.go(sample.route, false)
		app.scene_age = sample.age
		app.stage.clock = 12.0
		app.transition_view.visible = false
		app.stage.ding_story.sync(app)
		app.stage.queue_redraw()
		for frame in range(5): await process_frame
		var picture = root.get_texture().get_image()
		var path = "res://.test-output/ding-story-" + sample.name + ".png"
		var error = picture.save_png(path)
		records.append({"file":path, "size":str(picture.get_size()), "error":error, "shot":app.stage.ding_story.shot_state.duplicate()})
	var report = FileAccess.open("res://.test-output/ding-story-visual-results.json", FileAccess.WRITE)
	var motion_checks: Array = []
	for still in [false, true]:
		app.core.settings.reduced_motion = still
		app.stage.clock = 12.0
		app.stage.ding_story.sync(app)
		for frame in range(3): await process_frame
		var before: PackedByteArray = root.get_texture().get_image().get_data()
		app.stage.clock = 16.0
		app.stage.ding_story.sync(app)
		for frame in range(3): await process_frame
		var after: PackedByteArray = root.get_texture().get_image().get_data()
		motion_checks.append({"reduced_motion":still, "passed":(before == after) == still})
	app.core.settings.reduced_motion = false
	app.paused = true
	var paused_clock: float = app.stage.clock
	app.stage._process(3.0)
	motion_checks.append({"pause":true, "passed":app.stage.clock == paused_clock})
	report.store_string(JSON.stringify({"captures":records, "motion_checks":motion_checks}, "\t"))
	report.close()
	app.audio_player.stop()
	app.note_player.stop()
	app.queue_free()
	await process_frame
	print("DING STORY CAPTURES: ", records.size(), " MOTION: ", JSON.stringify(motion_checks))
	var failed = false
	for check in motion_checks: failed = failed or not check.passed
	quit(1 if failed else 0)
