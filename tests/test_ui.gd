extends SceneTree
var app
var checks = 0
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL UI: ", message)

func click(id: String, modal = false) -> void:
	var parent: Control = app.overlay if modal else app.ui
	var b = parent.find_child(id, true, false)
	expect(b != null, "button exists " + id + " at " + app.mode)
	if b != null:
		expect(not b.disabled, "button enabled " + id)
		b.pressed.emit()

func read_dialogue() -> void:
	var guard = 0
	while app.mode == "dialogue" and guard < 100:
		app.line_age = 10
		app.advance_dialogue()
		guard += 1
	expect(guard < 100, "dialogue terminates at its intended interaction")

func wait_animation() -> void:
	if app.active_tween != null and app.active_tween.is_valid():
		app.active_tween.set_speed_scale(50)
	for frame in range(200):
		if not app.busy: return
		await process_frame
	expect(not app.busy, "animation completes within bounded wait")

func reflect_phase() -> void:
	var old_mode: String = app.mode
	for target in range(5 if old_mode == "dragon" else 4):
		app.brush_cooldown = 0
		app.bullets.clear()
		app.attack_warning = 0
		app.shot_timer = 100
		app.facing = Vector2.RIGHT
		app.bullets.append({"p": app.player_pos + Vector2(100, 0), "v": Vector2(-208, 0), "reflected": false, "target": target})
		app.brush()
		for frame in range(210):
			if app.mode != old_mode: break
			app.update_battle(1.0 / 60)
			if app.battle_hits > target: break
		expect(app.battle_hits > target or app.mode != old_mode, "reflection reaches target")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.test-output")
	app = load("res://scenes/main.tscn").instantiate()
	var run_id = str(Time.get_ticks_usec())
	app.core.save_path = "res://.test-output/ui-revision-" + run_id + ".json"
	app.core.settings_path = "res://.test-output/ui-settings-" + run_id + ".json"
	create_timer(45).timeout.connect(func(): printerr("FAIL UI: suite timed out"); quit(1))
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.core.settings.reduced_motion = true
	app.start_new()
	expect(app.mode == "report", "new story starts with report")
	click("OpenReport")
	read_dialogue()
	expect(app.mode == "hub", "prologue reaches hub")
	# Wife first proves no implicit dependency on the suggested order.
	click("Memory_Wife")
	click("EnterMemory", true)
	expect(app.mode == "wife_arrival", "wife arrives through authored horse transition")
	app._process(app.stage.WifeArrival.DURATION + 0.1)
	read_dialogue()
	expect(app.mode == "runner", "wife starts four seasons")
	expect(app.runner_tutorial, "first chase includes safe ten-second tutorial")
	for i in range(7810):
		if app.mode != "runner": break
		app.update_runner(1.0 / 60)
	expect(app.mode == "letter_open", "all collisions and no input still catch letter")
	expect(app.core.state.stumbles >= 8, "runner test actually collided")
	click("ReadLetter")
	expect(app.dialogue_label.visible_characters == app.current_text.length(), "letter displays entire authored text immediately")
	read_dialogue()
	expect(app.mode == "letter_fold", "must fold letter after reading")
	expect(app.core.state.completed.is_empty(), "dialogue alone grants no fragment")
	click("FoldLetter")
	expect(app.core.state.dialogue.id == "WifeReflection", "folding leads to supplied snow farewell")
	read_dialogue()
	click("ClaimShard")
	expect(app.mode == "fragment" and app.core.state.completed.size() == 1, "wife shard claimed from object")
	click("ReturnHub")
	click("Memory_Student")
	click("EnterMemory", true)
	app.stage.student_story.sync(app)
	expect(app.stage.student_story.visible and app.stage.student_story.shot_state.a == 0, "second chapter opens with the supplied door handover image")
	expect(not app.Stage.StudentStory.dialogue_handles("StudentScroll"), "late chapter pictures do not replace the pre-battle scene")
	expect(not app.core.complete_memory("Student"), "opening illustration cannot grant student fragment")
	read_dialogue()
	expect(app.mode == "board", "student begins manuscript")
	for id in app.core.board_solution():
		click("Card_" + id)
	read_dialogue()
	expect(app.mode == "army", "board enters actual paper army")
	reflect_phase()
	expect(app.mode == "dragon", "army advances to dragon")
	reflect_phase()
	read_dialogue()
	expect(app.mode == "review", "dragon leads to review gesture")
	app.stage.student_story.sync(app)
	expect(app.stage.student_story.shot_state.a == 1, "review gesture stays on the supplied writing scene")
	expect(app.stroke_rect().has_point(Vector2(800, 700)) and not app.stroke_rect().has_point(Vector2(800, 400)), "only paper accepts review strokes, not faces")
	expect(not app.core.complete_memory("Student"), "winning battle alone cannot grant student fragment")
	click("StrokeAccessible")
	await wait_animation()
	app.scene_age = 2.0
	app.stage.student_story.sync(app)
	expect(app.core.state.dialogue.id == "StudentReflection" and app.stage.student_story.shot_state.b == 2, "finishing annotation opens the unrolled painting reflection")
	expect(not app.core.complete_memory("Student"), "annotation still requires hearing the student's reflection")
	read_dialogue()
	click("ClaimShard")
	app.scene_age = 2.0
	app.stage.student_story.sync(app)
	expect(app.core.state.dialogue.id == "StudentShardEcho" and app.stage.student_story.shot_state.b == 3, "the remembered teaching ends with a glance back at the doorway")
	read_dialogue()
	expect(app.core.state.completed.size() == 2, "student shard unique")
	click("ReturnHub")
	click("Memory_Ding")
	click("EnterMemory", true)
	read_dialogue()
	expect(app.mode == "ding_lamp", "Ding starts lamp puzzle")
	app.cross_lamp()
	expect(app.mode == "ding_lamp", "cannot skip maze from entrance")
	app.maze_forward = 1
	var maze_x = app.core.state.lantern_maze.x
	app._process(0.1)
	expect(app.core.state.lantern_maze.x > maze_x, "forward input walks first person")
	app.open_pause()
	maze_x = app.core.state.lantern_maze.x
	app._process(0.1)
	expect(app.core.state.lantern_maze.x == maze_x and app.maze_forward == 0, "pause freezes maze and clears held movement")
	app.close_modal()
	# Full traversal is tested separately; test the UI at the physical exit boundary.
	app.core.state.lantern_maze.x = 11.5 * app.core.MAZE_CELL
	app.core.state.lantern_maze.z = 9 * app.core.MAZE_CELL - 0.02
	app.core.state.lantern_maze.yaw = PI
	app.maze_forward = 1
	app.update_lantern_maze(0.1)
	expect(app.core.state.lantern_maze.phase == "echo", "exit starts wall memory")
	expect(not app.ui.get_node("LeaveMaze").visible, "next stage hidden during memory")
	app.core.tick_lantern_echo(7)
	app.refresh_lamp_feedback()
	expect(app.ui.get_node("LeaveMaze").visible, "first person restored before continue")
	click("LeaveMaze")
	expect(app.mode == "ding_graph", "maze memory leads to graph")
	for solution in app.core.graph.solution:
		while int(app.core.state.shadow.view) != int(solution.viewIndex):
			click("RotateRight")
			await wait_animation()
		if solution.has("lampU"):
			app.core.state.shadow.lamp = solution.lampU
			app.refresh_graph()
		var edge: Dictionary = {}
		for candidate in app.core.graph.edges:
			if candidate.id == solution.edge: edge = candidate
		click("Traverse_" + edge.toNode)
		await wait_animation()
	expect(app.mode == "ding_table", "graph opens independent dinner tableau")
	app.stage.ding_story.sync(app)
	expect(app.stage.ding_story.visible and app.stage.ding_story.shot_state.a == 2, "first memory enters the supplied empty supper room")
	app._process(6.1)
	expect(app.mode == "ding_place", "tableau slowly reveals before manuscript interaction")
	app.stage.ding_story.sync(app)
	expect(app.stage.ding_story.shot_state.a == 0, "entry resolves to manuscript handover without another background")
	click("PlaceManuscript")
	app._process(1.6)
	app.stage.ding_story.sync(app)
	expect(app.stage.ding_story.shot_state.b == 1 and app.stage.ding_story.shot_state.blend == 1.0, "manuscript settles on the table during dinner dialogue")
	expect(app.dialogue_label.position.y >= 790, "dinner dialogue leaves hands and rice bowl visible")
	app.open_pause()
	var story_clock: float = app.stage.clock
	app.stage._process(2.0)
	expect(app.stage.clock == story_clock, "pause freezes first-memory shader motion")
	app.close_modal()
	read_dialogue()
	click("RememberDinner")
	read_dialogue()
	click("ClaimShard")
	read_dialogue()
	expect(app.core.state.completed.size() == 3, "all three memories can complete")
	click("ContinueMemory")
	expect(app.mode == "jade", "last fragment returns through hub to jade")
	for i in range(3):
		app.selected_jade = i
		app.jade_positions[i] = Vector2(800, 430)
		app.place_selected_jade()
	expect(app.mode == "flip" and not app.core.state.inscription, "assembly does not reveal writing")
	var reloaded = app.Core.new()
	reloaded.save_path = app.core.save_path
	expect(reloaded.load_game() and not reloaded.state.inscription, "reload before flip preserves suspense")
	click("FlipJade")
	await wait_animation()
	read_dialogue()
	app._process(2.1)
	var swim_early: float = app.accident_swim_speed()
	app._process(34.9)
	expect(app.accident_swim_speed() < swim_early * 0.4, "soaked scroll reduces swimming speed")
	expect(app.mode == "accident", "accident not over before 35 seconds")
	app._process(0.11)
	expect(app.mode == "body", "accident resolves without input")
	app._process(9.1)
	expect(app.mode == "body" and not "DeathAcknowledged" in app.core.state.events, "soul reveal finishes before recognition is granted")
	app.stage.ending_sequence.sync(app)
	app.open_pause()
	var reveal_age: float = app.scene_age
	app._process(20)
	expect(app.scene_age == reveal_age and app.mode == "body", "pause freezes the illustrated revelation")
	app.close_modal()
	app._process(app.Stage.EndingSequence.BODY_DURATION - app.scene_age + 0.1)
	var checkpoint = app.Core.new()
	checkpoint.save_path = app.core.save_path
	expect(checkpoint.load_game() and checkpoint.state.route == "release", "death recognition saves before release")
	expect(app.mode == "release", "release only after death recognition")
	app.mouse_hold = true
	app._process(1.0)
	app.mouse_hold = false
	app._process(0.2)
	expect(app.mode == "release" and app.hold_progress > 0.9, "interrupted hold preserves progress briefly")
	app.mouse_hold = true
	app._process(0.6)
	expect(app.mode == "release_echo", "release shows the three everyday echoes")
	app._process(9.1)
	read_dialogue()
	expect(app.mode == "reply", "dinner waits for active reply")
	app._process(100)
	expect(app.mode == "reply" and not app.core.state.finished, "reply never automatically selected")
	click("Reply")
	expect(app.mode == "finale" and not app.ui.has_node("SitDown"), "reply begins uninterrupted final film")
	app._process(4.1)
	expect("SatDown" in app.core.state.events and not app.core.state.finished, "film seats observer before ending")
	app.open_pause()
	var film_time: float = app.scene_age
	app._process(20)
	expect(app.scene_age == film_time, "pause freezes final film")
	app.close_modal()
	app._process(26)
	expect(app.mode == "credits" and app.core.state.finished, "complete ending unlocks codex")
	var memories: Dictionary = app.memory_saves.list_memories()
	var checkpoints: Array = []
	for memory in memories.entries:
		if memory.get("source") == "auto": checkpoints.append(memory.checkpoint_id)
	for expected_checkpoint in ["arrival", "memory_Ding", "memory_Student", "memory_Wife", "jade", "ending"]:
		expect(expected_checkpoint in checkpoints, "real UI journey recorded " + expected_checkpoint)
	click("AfterCodex")
	expect(app.overlay.has_node("Person_3"), "all four character entries available")
	app.close_modal()
	# Modal pause freezes every gameplay timer.
	app.go("runner")
	app.open_pause()
	var before: float = app.season_time
	app._process(10)
	expect(app.season_time == before, "pause freezes runner")
	app.close_modal()
	app.go("hub")
	# Secondary attacks warn before moving, melee folding is not a substitute for reflected victory.
	app.core.state.memory = "Student"
	app.go("army")
	app.battle_hits = 1
	app.begin_secondary_attack()
	expect(app.hazard_kind == "charge" and app.hazard_warning >= 0.85, "paper charge is visibly telegraphed")
	expect(app.charge_from.distance_to(app.player_pos) >= 96, "charging soldier never appears on player")
	app.hazard_warning = 0
	app.hazard_active = 0.6
	app.charge_pos = app.player_pos + Vector2(50, 0)
	app.facing = Vector2.RIGHT
	app.brush()
	app.update_battle(0.08)
	expect(app.folded_time > 1.9 and app.battle_hits == 1, "nearby soldier folds without crediting drum")
	app.go("dragon")
	app.battle_hits = 2
	app.begin_secondary_attack()
	expect(app.hazard_kind == "wave" and absf(app.player_pos.y - app.hazard_y) < 80, "wave always leaves a two-meter safe gap")
	app.hazard_warning = 0
	app.hazard_active = 3
	app.hazard_x = app.player_pos.x + 1
	app.update_battle(0.01)
	expect(app.battle_mistakes == 0, "standing inside wave gap is safe")
	app.go("hub")
	expect(app.core.valid_save(app.core.read_json(app.core.save_path)), "complete UI journey persists valid state")
	print("GUINING UI: ", checks, " checks, ", failures.size(), " failures")
	var file = FileAccess.open("res://.test-output/ui-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	file.close()
	app.audio_player.stop()
	app.note_player.stop()
	app.audio_player.stream = null
	app.note_player.stream = null
	await create_timer(0.15).timeout
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
