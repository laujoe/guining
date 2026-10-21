extends SceneTree
const Core = preload("res://scripts/game_core.gd")
var failures: Array = []
var checks = 0

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.test-output")
	var c = Core.new()
	c.save_path = "res://.test-output/rules-save.json"
	c.settings_path = "res://.test-output/settings.json"
	expect(c.cards.size() == 36, "36 unique cards imported")
	expect(c.dialogue.size() == 22, "all dialogue sequences imported")
	var ids: Array = []
	for seq in c.dialogue.values():
		for line in seq.lines:
			expect(not line.lineId in ids, "unique dialogue line " + line.lineId)
			ids.append(line.lineId)
	# All six orders; prerequisites prevent a dialogue-only shard; replay is idempotent.
	var orders = [["Ding", "Student", "Wife"], ["Ding", "Wife", "Student"], ["Student", "Ding", "Wife"], ["Student", "Wife", "Ding"], ["Wife", "Ding", "Student"], ["Wife", "Student", "Ding"]]
	for order in orders:
		c.reset_state()
		for id in order:
			expect(not c.complete_memory(id), "shard requires interactions " + id)
			for event in c.PREREQUISITES[id]: c.event(event)
			expect(c.complete_memory(id), "complete " + id)
			var n = c.state.completed.size()
			expect(c.complete_memory(id) and c.state.completed.size() == n, "replay does not duplicate")
		expect(c.state.completed.size() == 3, "three distinct memories for " + str(order))
		expect(not c.flip_jade(), "unassembled jade cannot reveal inscription")
		for i in range(3): c.place_jade(i)
		expect(c.flip_jade(), "all orders can flip")
		expect(not c.release_report(), "death must be acknowledged")
		c.event("DeathAcknowledged")
		expect(c.release_report(), "release after reveal")
		expect(not c.finish_game(), "reply and sit are mandatory")
		for event in ["ReplyChosen", "SatDown", "LiteracyStroke", "FinalDinnerCompleted"]: c.event(event)
		expect(c.finish_game(), "ending reachable")
	# Lamp formula boundaries, not a separately hand-authored legal flag.
	for u in [0.0, 0.374, 0.651, 1.0]: expect(not c.lamp_valid(u), "invalid lamp " + str(u))
	for u in [0.375, 0.5, 0.65]: expect(c.lamp_valid(u), "valid lamp " + str(u))
	c.reset_state()
	expect(not c.traverse_shadow("B"), "A-B closed at zero degrees")
	c.rotate_shadow(1)
	expect(c.traverse_shadow("B"), "A to B")
	c.rotate_shadow(1)
	expect(c.traverse_shadow("D"), "optional dead end reachable")
	expect(not c.rotate_shadow(1), "no handle at D")
	expect(c.traverse_shadow("B"), "D always returns along same edge")
	c.rotate_shadow(1)
	expect(c.traverse_shadow("C"), "B to C at 270")
	c.rotate_shadow(1)
	expect(c.traverse_shadow("E"), "C to E at zero")
	c.rotate_shadow(1)
	expect(not c.traverse_shadow("F"), "E-F needs lamp")
	c.state.shadow.lamp = 0.52
	expect(c.traverse_shadow("F"), "E to dinner")
	# Fixed manuscript solution, conserved identifiers, triple before overflow.
	c.new_board()
	for id in c.board_solution():
		expect(c.pick(id), "solution legal " + id)
		expect(c.valid_board(c.state.board), "conservation after " + id)
	expect(c.board_won(), "all 36 clear")
	c.new_board()
	c.state.board.erase("types"); c.state.board.erase("solution")
	c.pick("A1"); c.pick("B1"); c.pick("C1")
	expect(c.state.board.cleared.size() == 3, "triple removed")
	expect(c.undo(), "undo elimination")
	expect(c.state.board.table.has("C1") and c.state.board.tray.size() == 2, "undo restores exact ids")
	expect(c.state.board.seen.has("Soldier"), "seen animation remains deduplicated")
	expect(c.reserve_cards(), "reserve earliest cards")
	expect(c.return_card("A1"), "return reserved")
	expect(c.undo(), "undo return")
	expect(c.state.board.reserve.has("A1") and c.state.board.reserve_used, "assist cost not refunded")
	expect(c.valid_board(c.state.board), "reserve/undo conservation")
	c.new_board()
	c.state.board.erase("types"); c.state.board.erase("solution")
	for id in ["A1", "A2", "A3", "A4", "B1", "A5"]: expect(c.pick(id), "seventh-card setup")
	expect(c.state.board.tray.size() == 6, "six held before decisive card")
	expect(c.pick("C1"), "seventh card accepted")
	expect(c.state.board.tray.size() == 4, "seventh triple resolves before full")
	# Random legal transactions catch hidden duplication across undo/reserve.
	seed(260118)
	for game in range(20):
		c.new_board()
		for step in range(100):
			var action = randi_range(0, 9)
			if action == 0: c.undo()
			elif action == 1: c.reserve_cards()
			elif action == 2 and not c.state.board.reserve.is_empty(): c.return_card(c.state.board.reserve[0])
			else:
				var available: Array = []
				for id in c.state.board.table:
					if c.can_pick(id): available.append(id)
				if not available.is_empty(): c.pick(available.pick_random())
			expect(c.valid_board(c.state.board), "random transaction conservation")
	# Runner schedule is authored with visible warnings and no punitive failure path.
	for season in c.runner_config.seasons:
		var last_contact = -10.0
		for obstacle in season.obstacles:
			expect(obstacle.contactAt - obstacle.spawnAt >= 1.3, "runner warning >= 1.3s")
			expect(obstacle.contactAt - last_contact >= 1.2, "runner action separation")
			last_contact = obstacle.contactAt
	# Saving after assembly never implies that the jade has been flipped.
	c.reset_state()
	for id in c.MEMORY_IDS:
		for event in c.PREREQUISITES[id]: c.event(event)
		c.complete_memory(id)
	for i in range(3): c.place_jade(i)
	c.state.route = "flip"
	expect(c.save_game(), "atomic first save")
	var other = Core.new()
	other.save_path = c.save_path
	expect(other.load_game(), "reload assembled jade")
	expect(other.state.jade.size() == 3 and not other.state.inscription, "unflipped stays hidden")
	expect(c.save_game(), "second save creates backup")
	var file = FileAccess.open(c.save_path, FileAccess.WRITE)
	file.store_string("{corrupt"); file.close()
	expect(other.load_game() and other.recovered_backup, "corruption recovery from backup")
	file = FileAccess.open(c.save_path, FileAccess.WRITE)
	file.store_string('{"schema":99}'); file.close()
	expect(not other.load_game() and other.write_blocked, "future version protected")
	expect(not other.save_game(), "future save cannot be overwritten")
	expect(FileAccess.get_file_as_string(c.save_path) == '{"schema":99}', "future save unchanged")
	var bad = c.state.duplicate(true)
	bad.completed.append("Ding")
	expect(not c.valid_save(bad), "reject duplicate memories")
	# The supplied revision is a text contract, independent of presentation code.
	var farewell = ["收好了，别再丢了。", "你看，下雪了。", "我这次回来，有个好消息——", "我听着。陪我去檐下站一会儿吧。", "外头冷，等我说完。", "……好。", "分明写在这里……怎么会看不清？", "你等等，我这就……", "说好陪我看的。"]
	expect(c.dialogue.WifeReflection.lines.size() == farewell.size(), "snow farewell contains exactly nine authored lines")
	for i in range(farewell.size()): expect(c.dialogue.WifeReflection.lines[i].text == farewell[i], "verbatim farewell line " + str(i))
	expect(c.dialogue.WifeLetter.lines.size() == 1, "letter is one complete page")
	expect(c.dialogue.WifeLetter.lines[0].text == "功名若得，我替你欢喜；一时未得，也不必觉无颜以归。\n\n只盼春来与你种花，夏夜共坐檐下，秋时添衣，冬日同扫庭前雪。", "letter matches latest supplied script exactly")
	expect(c.dialogue.WifeDeparture.lines[0].text == "家书刚写好尚未来得及寄出", "returning home replaces old departure story")
	# Old three-page letters migrate without losing memories or discarding a valid save.
	c.reset_state()
	c.state.erase("script_revision")
	c.state.memory = "Wife"
	c.state.route = "dialogue"
	c.state.dialogue = {"id":"WifeLetter", "index":2, "next":"wife_reflection"}
	expect(c.valid_save(c.state), "legacy third letter page remains loadable")
	c.normalize_loaded()
	expect(c.state.dialogue.index == 0 and c.state.dialogue.next == "letter_fold", "legacy letter maps to complete page")
	c.state.erase("script_revision")
	c.state.route = "wife_shard"
	c.normalize_loaded()
	expect(c.state.route == "wife_reflection", "legacy pending wife shard first plays new farewell")
	# Shuffling changes presentation, never the dependency graph or known solvability.
	var layouts: Dictionary = {}
	for trial in range(24):
		c.new_board()
		layouts[str(c.state.board.layout_order)] = true
		var before_layout = c.state.board.layout_order.duplicate()
		for id in c.board_solution(): expect(c.pick(id), "shuffled board remains solvable")
		expect(c.board_won() and c.valid_board(c.state.board), "shuffled board conserves all cards")
		expect(c.state.board.layout_order == before_layout, "layout stable through picks")
	expect(layouts.size() > 1, "new games do not always arrange cards identically")
	print("GUINING RULES: ", checks, " checks, ", failures.size(), " failures")
	var report = FileAccess.open("res://.test-output/rules-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	report.close()
	quit(0 if failures.is_empty() else 1)
