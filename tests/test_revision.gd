extends SceneTree
## Can run against the development project OR an exported pack using two user args.
var checks = 0
var failures: Array = []
var app
var output = "res://.test-output"
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL REVISION: ", message)
func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() == 2:
		output = args[1]
		if not ProjectSettings.load_resource_pack(args[0]): quit(1); return
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	app = load("res://scenes/main.tscn").instantiate()
	var c = app.core
	c.save_path = output.path_join("revision-" + str(Time.get_ticks_usec()) + ".json")
	c.settings_path = output.path_join("revision-settings.json")
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.close_modal()
	app.core.settings.reduced_motion = true
	# Check speaker identity for every line, including illustration dialogue badges.
	for seq in ["Prologue", "DingIntro", "DingDinner", "DingPastChoice", "DingReflection", "DingShardEcho"]:
		c.state.memory = "Ding"
		for i in range(c.dialogue[seq].lines.size()):
			c.state.dialogue = {"id":seq, "index":i, "next":"hub"}
			app.go("dialogue", false)
			expect(app.dialogue_portrait_id() == c.dialogue[seq].lines[i].speakerId, "speaker and portrait " + seq + str(i))
			if app.ui.has_node("SpeakingPortrait"):
				expect(app.ui.get_node("SpeakingPortrait").get_meta("speaker_id") == app.current_speaker, "illustration badge matches speaker")
				expect(app.ui.get_node("SpeakingPortrait").size == Vector2(79,119), "portrait fits inside dialogue panel")
	# Navigation must work from every corridor and dead end, with no wall crossings.
	for y in range(c.MAZE.size()):
		for x in range(c.MAZE[y].length()):
			if c.maze_wall(Vector2i(x, y)): continue
			c.state.lantern_maze.x = (x + 0.5) * c.MAZE_CELL
			c.state.lantern_maze.z = (y + 0.5) * c.MAZE_CELL
			var path: Array = c.maze_exit_path()
			expect(not path.is_empty() and path[0] == Vector2i(x,y) and path[-1] == c.MAZE_EXIT, "map reaches exit from " + str(Vector2i(x,y)))
			for i in range(1, path.size()):
				expect(not c.maze_wall(path[i]) and (path[i] - path[i-1]).length_squared() == 1, "route respects collision")
	c.reset_lantern_maze()
	app.go("ding_lamp", false)
	app.maze_forward = 1
	app.ui.get_node("MazeMap").pressed.emit()
	expect(app.paused and app.maze_forward == 0 and app.overlay.has_node("MazeMapView"), "map pauses motion")
	app.overlay.get_node("MazeRoute").pressed.emit()
	expect(app.overlay.get_node("MazeMapView").show_route, "exit route is optional")
	app.overlay.get_node("CloseMazeMap").pressed.emit()
	expect(not app.paused and app.mode == "ding_lamp", "map closes to first person")
	# Randomized boards are solvable, conserved, and persist exactly across save/load.
	var layouts = {}
	for trial in range(100):
		c.new_board()
		var top: Dictionary = {}
		for pile in ["A", "B", "C", "D", "E", "F"]:
			var kind: String = c.card_type(pile + "1")
			top[kind] = top.get(kind, 0) + 1
		expect(top.values().max() <= 2, "opening requires planning below top cards")
		layouts[JSON.stringify(c.state.board.types)] = true
		for id in c.board_solution(): expect(c.pick(id), "random deal has legal solution")
		expect(c.board_won() and c.valid_board(c.state.board), "random deal clears all cards")
	expect(layouts.size() > 90, "deals change actual card types, not just pile positions")
	c.new_board()
	c.state.route = "board"
	c.state.dialogue = {}
	var before = c.state.board.duplicate(true)
	expect(c.save_game(), "save random board")
	var restored = load("res://scripts/game_core.gd").new()
	restored.save_path = c.save_path
	expect(restored.load_game() and restored.state.board.types == before.types and restored.state.board.solution == before.solution, "resume never rerolls cards")
	var bad: Dictionary = before.duplicate(true)
	bad.types.A1 = "Dragon"
	expect(not c.valid_board(bad), "reject invalid type maps")
	# Wife last: final dialogue commits 3/3 BEFORE receipt screen and survives reload.
	c.reset_state()
	for id in ["Ding", "Student"]:
		for event in c.PREREQUISITES[id]: c.event(event)
		c.complete_memory(id)
	c.state.memory = "Wife"
	for event in ["RunnerFinished", "LetterRead", "LetterFolded"]: c.event(event)
	app.say("WifeReflection", "wife_shard")
	while app.mode == "dialogue":
		app.line_age = 10
		app.advance_dialogue()
	expect(app.mode == "wife_shard" and c.state.completed.size() == 3, "final farewell immediately records 3/3")
	expect(restored.load_game() and restored.state.completed.size() == 3, "3/3 persists before confirm button")
	app.ui.get_node("ClaimShard").pressed.emit()
	expect(c.state.completed.size() == 3 and app.ui.get_node("ContinueMemory").text == "拼合玉佩", "receipt is idempotent and opens assembly")
	c.state.completed.erase("Wife")
	c.state.route = "wife_shard"
	c.normalize_loaded()
	expect(c.state.completed.size() == 3, "old pending farewell checkpoints reconcile")
	# Every route has its intended score; actual audio streams and ending images load.
	for pair in [["menu","mist"],["ding_lamp","night"],["ding_graph","lantern"],["board","ink"],["army","battle"],["dragon","battle"],["runner","letter"],["accident","storm"],["body","night"],["release","farewell"],["finale","home"]]:
		app.mode = pair[0]
		expect(app.music_for_scene() == pair[1], "scene music " + pair[0])
		var audio = app.MusicLibrary.stream_for(app.MusicLibrary.track_for(pair[1]))
		expect(audio != null and audio.loop and audio.get_length() >= 120, "full looping music available " + pair[1])
	for art in app.stage.EndingSequence.ART: expect(art.get_width() > 0, "ending image is packaged")
	app.mode = "accident"; app.accident_time = 15
	app.stage.ending_sequence.sync(app)
	expect(app.stage.ending_sequence.visible and app.stage.ending_sequence.shot_b == 8, "fall plays first-person river shot")
	app.mode = "finale"
	for pair in [[4,6],[12,5],[19,4],[24,7]]:
		app.scene_age = pair[0]
		app.stage.ending_sequence.sync(app)
		expect(app.stage.ending_sequence.shot_b == pair[1], "reunion shot " + str(pair[1]))
	var report = FileAccess.open(output.path_join("revision-results.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures}, "\t")); report.close()
	print("REVISION: ", checks, " checks; ", failures.size(), " failures")
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
