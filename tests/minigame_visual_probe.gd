extends SceneTree
## Real rendered captures, UI geometry and pointer picking; isolated test saves.
var app
var failures: Array = []
var captures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr("FAIL VISUAL: ", message)

func shot(id: String) -> void:
	app.update_transition(10)
	for frame in range(8): await process_frame
	var file = "res://.test-output/minigame-" + id + ".png"
	check(root.get_texture().get_image().save_png(file) == OK, "capture " + id)
	captures.append(file)
	for control in app.ui.get_children():
		if control is Button or control is Label:
			check(Rect2(0, 0, 1600, 900).encloses(control.get_rect()), "UI fits " + str(control.name) + " at " + id)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.test-output")
	app = load("res://scenes/main.tscn").instantiate()
	app.core.save_path = "res://.test-output/minigame-visual-save.json"
	app.core.settings_path = "res://.test-output/minigame-visual-settings.json"
	root.add_child(app)
	await process_frame
	if root.focus_exited.is_connected(app._on_focus_lost): root.focus_exited.disconnect(app._on_focus_lost)
	app.close_modal()
	app.set_process(false)
	app.core.reset_state()
	app.core.settings.reduced_motion = true
	root.size = Vector2i(1600, 900)
	app.core.state.memory = "Ding"
	for sample in [{"node":"A", "view":0, "lamp":0.15}, {"node":"A", "view":1, "lamp":0.15}, {"node":"E", "view":1, "lamp":0.15}, {"node":"E", "view":1, "lamp":0.52}]:
		app.core.state.shadow = sample.duplicate()
		app.go("ding_graph", false)
		await shot("graph-" + sample.node + "-" + str(sample.view) + "-" + str(sample.lamp))
	app.core.state.memory = "Student"
	app.core.new_board()
	app.go("board", false)
	await shot("board")
	# Use actual pointer events at each topmost card centre, then verify core state.
	for step in range(2):
		var id: String = app.core.next_card_hint()
		var rect: Rect2 = app.stage.card_rect(id)
		var before: int = app.core.state.board.table.size()
		for pressed in [true, false]:
			var event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			event.position = rect.get_center()
			root.push_input(event, true)
			await process_frame
		check(app.core.state.board.table.size() == before - 1, "pointer picks visible card " + id)
	await shot("board-tray")
	check(app.core.state.board.tray.size() == 2, "two cards in tray before reserve")
	app.core.reserve_cards()
	check(app.core.state.board.reserve.size() == 2, "reserve contains two cards")
	app.board_changed()
	await shot("board-reserve")
	for id in app.core.state.board.reserve.duplicate():
		var hit = app.ui.get_node("Return_" + id)
		check(hit.get_rect() == app.stage.MemoryGamesArt.reserve_rect(app.core.state.board.reserve.find(id)), "reserve hit target matches drawing")
	app.core.settings.text_scale = 1.3
	root.size = Vector2i(1280, 720)
	app.board_changed()
	await shot("board-text130-720")
	app.core.state.shadow = {"node":"E", "view":1, "lamp":0.52}
	app.go("ding_graph", false)
	await shot("graph-text130-720")
	var report = FileAccess.open("res://.test-output/minigame-visual-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"captures":captures, "failures":failures}, "\t"))
	report.close()
	print("MINIGAME VISUAL: ", captures.size(), " captures; ", failures.size(), " failures")
	app.audio_player.stop()
	app.note_player.stop()
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
