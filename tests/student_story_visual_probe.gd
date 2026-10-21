extends SceneTree
## Real GPU captures and motion checks; all save paths remain under .test-output.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(45).timeout.connect(func(): printerr("STUDENT STORY: probe timed out"); quit(1))
	DirAccess.make_dir_recursive_absolute("res://.test-output")
	var app = load("res://scenes/main.tscn").instantiate()
	var run_id = str(Time.get_ticks_usec())
	app.core.save_path = "res://.test-output/student-story-" + run_id + ".json"
	app.core.settings_path = "res://.test-output/student-story-settings-" + run_id + ".json"
	root.add_child(app)
	await process_frame
	if root.focus_exited.is_connected(app._on_focus_lost):
		root.focus_exited.disconnect(app._on_focus_lost)
	app.close_modal()
	app.set_process(false)
	app.stage.set_process(false)
	app.core.reset_state()
	app.core.state.memory = "Student"
	root.size = Vector2i(1280, 720)
	var records: Array = []
	var motion_checks: Array = []
	for sample in [
		{"name":"intro", "route":"dialogue", "id":"StudentIntro", "text":1.0},
		{"name":"writing", "route":"dialogue", "id":"StudentReview", "text":1.0},
		{"name":"annotation", "route":"review", "id":"", "text":1.0},
		{"name":"unroll130", "route":"dialogue", "id":"StudentReflection", "text":1.3},
		{"name":"shard", "route":"student_shard", "id":"", "text":1.0},
		{"name":"farewell", "route":"dialogue", "id":"StudentShardEcho", "text":1.0},
		{"name":"fragment", "route":"fragment", "id":"", "text":1.0}]:
		app.core.settings.text_scale = sample.text
		app.core.settings.reduced_motion = false
		if sample.id != "":
			app.say(sample.id, "review")
			app.dialogue_label.visible_characters = -1
		else:
			if sample.route == "fragment":
				app.core.state.completed.append("Student")
			app.go(sample.route, false)
		app.scene_age = 2.0
		app.stage.clock = 12.0
		app.transition_view.visible = false
		app.stage.student_story.sync(app)
		app.stage.queue_redraw()
		for frame in range(5): await process_frame
		var picture = root.get_texture().get_image()
		var path = "res://.test-output/student-story-" + sample.name + ".png"
		records.append({"file":path, "error":picture.save_png(path), "size":str(picture.get_size()), "shot":app.stage.student_story.shot_state.duplicate()})
		if sample.id == "": continue
		for still in [false, true]:
			app.core.settings.reduced_motion = still
			app.stage.clock = 12.0
			app.stage.student_story.sync(app)
			for frame in range(3): await process_frame
			var before = root.get_texture().get_image().get_data()
			app.stage.clock = 16.0
			app.stage.student_story.sync(app)
			for frame in range(3): await process_frame
			var after = root.get_texture().get_image().get_data()
			motion_checks.append({"shot":sample.name, "reduced_motion":still, "passed":(before == after) == still})
	app.paused = true
	var clock_before: float = app.stage.clock
	app.stage._process(4.0)
	motion_checks.append({"pause":true, "passed":app.stage.clock == clock_before})
	var report = FileAccess.open("res://.test-output/student-story-visual-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"captures":records, "motion_checks":motion_checks}, "\t"))
	report.close()
	app.audio_player.stop()
	app.note_player.stop()
	app.queue_free()
	await process_frame
	var failed = false
	for check in motion_checks: failed = failed or not check.passed
	print("STUDENT STORY CAPTURES: ", records.size(), " MOTION: ", JSON.stringify(motion_checks))
	quit(1 if failed else 0)
