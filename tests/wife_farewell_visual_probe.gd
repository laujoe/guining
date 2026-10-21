extends SceneTree
## Real framebuffer checks. Saves and captures are isolated from player data.
var app
var checks = 0
var failures: Array = []
var captures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL FAREWELL: ", message)

func sync_frame() -> void:
	app.transition_view.visible = false
	app.stage.wife_arrival.sync(app)
	app.stage.wife_farewell.sync(app)
	app.stage.queue_redraw()
	for frame in range(4): await process_frame

func capture(label_text: String) -> Image:
	await sync_frame()
	var picture = root.get_texture().get_image()
	var path = "res://.test-output/wife-farewell-" + label_text + ".png"
	check(picture.save_png(path) == OK, "capture " + label_text)
	captures.append({"file":path, "size":str(picture.get_size()), "shot":app.stage.wife_farewell.shot_state.duplicate()})
	return picture

func select_line(index: int) -> void:
	app.core.state.dialogue = {"id":"WifeReflection", "index":index, "next":"wife_shard"}
	app.go("dialogue", false)
	app.line_age = 3.0
	app.dialogue_label.visible_characters = app.current_text.length()

func run() -> void:
	create_timer(45).timeout.connect(func(): printerr("FAIL FAREWELL: timeout"); quit(1))
	DirAccess.make_dir_recursive_absolute("res://.test-output")
	app = load("res://scenes/main.tscn").instantiate()
	app.core.save_path = "res://.test-output/wife-farewell-probe-save.json"
	app.core.settings_path = "res://.test-output/wife-farewell-probe-settings.json"
	root.add_child(app)
	await process_frame
	if root.focus_exited.is_connected(app._on_focus_lost): root.focus_exited.disconnect(app._on_focus_lost)
	app.close_modal()
	app.set_process(false)
	app.stage.set_process(false)
	app.core.reset_state()
	app.core.state.memory = "Wife"
	app.core.settings.reduced_motion = false
	app.core.settings.text_scale = 1.3
	root.size = Vector2i(1280, 720)
	var expected = [3, 4, 0, 0, 1, 1, 1, 2, 5]
	var names = ["jade", "snow", "report", "eaves", "ink", "waiting", "blur", "dissolve", "empty"]
	for index in range(9):
		select_line(index)
		app.stage.clock = 12.0
		await capture(names[index])
		check(app.stage.wife_farewell.shot_state.b == expected[index], "artwork for " + names[index])
		check(app.stage.wife_farewell.visible and not app.stage.wife_arrival.visible, "final act owns frame")
		check(app.core.state.completed.is_empty(), "dialogue frame grants no fragment")
	select_line(7)
	var animated = await capture("motion-a")
	app.stage.clock += 0.7
	await sync_frame()
	check(root.get_texture().get_image().get_data() != animated.get_data(), "snow and paper glints animate")
	app.core.settings.reduced_motion = true
	var still = await capture("still")
	app.stage.clock += 1.0
	await sync_frame()
	check(root.get_texture().get_image().get_data() == still.get_data(), "reduced motion freezes pixels")
	app.core.settings.reduced_motion = false
	app.open_pause()
	var time_before: float = app.stage.clock
	var line_before: float = app.line_age
	app._process(2.0)
	app.stage._process(2.0)
	check(app.stage.clock == time_before and app.line_age == line_before, "pause freezes all clocks")
	app.close_modal()
	select_line(7)
	app.commit()
	check(app.core.load_game(), "isolated save reload")
	app.go(app.core.state.route, false)
	app.line_age = 3.0
	await sync_frame()
	check(app.stage.wife_farewell.shot_state.b == 2, "saved dissolution resumes correct shot")
	app.core.reset_state()
	app.core.state.memory = "Wife"
	app.core.event("RunnerFinished")
	app.core.event("LetterRead")
	app.core.event("LetterFolded")
	app.say("WifeReflection", "wife_shard")
	for index in range(9):
		app.line_age = 4.0
		app.dialogue_label.visible_characters = app.current_text.length()
		await sync_frame()
		app.advance_dialogue()
	check(app.mode == "wife_shard", "dialogue reaches claim")
	check("WifeFarewellSeen" in app.core.state.events, "farewell event fires")
	check(app.core.state.completed.is_empty(), "no automatic claim")
	check(not app.core.state.inscription, "jade inscription remains gated")
	root.size = Vector2i(1920, 1080)
	await capture("claim1080")
	app.ui.get_node("ClaimShard").pressed.emit()
	check(app.mode == "fragment" and app.core.state.completed.size() == 1, "claim grants exactly one shard")
	await capture("fragment1080")
	check(app.stage.wife_farewell.shot_state.b == 5, "empty courtyard remains after claim")
	app.ui.get_node("ReturnHub").pressed.emit()
	await sync_frame()
	check(not app.stage.wife_farewell.visible, "final act releases frame at hub")
	var report = FileAccess.open("res://.test-output/wife-farewell-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks, "failures":failures, "captures":captures}, "\t"))
	report.close()
	app.audio_player.stop()
	app.note_player.stop()
	app.queue_free()
	await process_frame
	print("WIFE FAREWELL: ", checks, " checks, ", captures.size(), " captures, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
