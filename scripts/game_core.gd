extends RefCounted
## Authoritative narrative, puzzle and persistence rules. No UI dependencies.

const MEMORY_IDS = ["Ding", "Student", "Wife"]
const MAZE_CELL = 2.8
const MAZE_RADIUS = 0.28
const MAZE = [
	"#############",
	"#S....#.....#",
	"###.#.#.###.#",
	"#...#...#...#",
	"#.#######.#.#",
	"#.....#...#.#",
	"#.###.#.###.#",
	"#.#...#.#...#",
	"#.#.###.#.#.#",
	"#...#.....#E#",
	"#############"
]
const MAZE_EXIT = Vector2i(11, 9)
const PREREQUISITES = {
	"Ding": ["ManuscriptPlaced", "DinnerMemorySeen", "DingReflectionHeard"],
	"Student": ["BoardCleared", "ArmyCleared", "DragonCleared", "ReviewStroke", "StudentReflectionSeen"],
	"Wife": ["RunnerFinished", "LetterRead", "LetterFolded", "WifeFarewellSeen"]
}
const ROUTES = ["hub", "dialogue", "report", "ding_lamp", "ding_graph", "ding_place", "ding_seat", "ding_reflection", "ding_shard", "board", "army", "dragon", "review", "student_shard", "runner", "letter_open", "wife_reflection", "letter_fold", "wife_shard", "jade", "flip", "accident_prompt", "accident", "body", "release", "dinner_call", "reply", "seat", "literacy", "credits", "fragment"]
var config: Dictionary
var narrative: Dictionary
var graph: Dictionary
var board_config: Dictionary
var runner_config: Dictionary
var dialogue: Dictionary = {}
var cards: Dictionary = {}
var state: Dictionary
var settings: Dictionary = {"text_scale": 1.0, "text_speed": 36.0, "volume": 0.45, "assist": false, "reduced_motion": false, "click_release": false}
var save_path = "user://slot01.json"
var settings_path = "user://settings.json"
var save_error = ""
var write_blocked = false
var recovered_backup = false

func _init() -> void:
	config = read_json("res://data/game_config.json")
	narrative = read_json("res://data/narrative.json")
	graph = read_json("res://data/shadow_graph.json")
	board_config = read_json("res://data/manuscript_board.json")
	runner_config = read_json("res://data/runner_timeline.json")
	for seq in read_json("res://data/dialogue_main.json").get("sequences", []):
		dialogue[seq.sequenceId] = seq
	for card in board_config.get("cards", []):
		cards[card.id] = card
	reset_state()

func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return parser.data if parser.data is Dictionary else {}

func reset_state() -> void:
	state = {"schema": 1, "script_revision": 2, "completed": [], "events": [], "route": "hub", "prologue": false,
		"dialogue": {}, "memory": "", "shadow": {"node": "A", "view": 0, "lamp": 0.15},
		"lamp1": 0.15, "board": {}, "season": 0, "stumbles": 0,
		"jade": [], "inscription": false, "released": false, "finished": false, "log": []}
	state["story_id"] = new_id()
	state["branch_id"] = new_id()
	state["parent_memory_id"] = ""
	state["memory_markers"] = []
	reset_lantern_maze()

func reset_lantern_maze() -> void:
	state["lantern_maze"] = {"x": MAZE_CELL * 1.5, "z": MAZE_CELL * 1.5, "yaw": PI / 2, "phase": "explore", "echo_time": 0.0}

func maze_wall(cell: Vector2i) -> bool:
	return cell.y < 0 or cell.y >= MAZE.size() or cell.x < 0 or cell.x >= MAZE[0].length() or MAZE[cell.y][cell.x] == "#"

func maze_clear(p: Vector2) -> bool:
	# Circle against the SAME solid cells used by the 3D renderer. Substeps prevent tunnelling.
	var cell = Vector2i(floori(p.x / MAZE_CELL), floori(p.y / MAZE_CELL))
	for y in range(cell.y - 1, cell.y + 2):
		for x in range(cell.x - 1, cell.x + 2):
			if not maze_wall(Vector2i(x, y)): continue
			var nearest = p.clamp(Vector2(x, y) * MAZE_CELL, Vector2(x + 1, y + 1) * MAZE_CELL)
			if p.distance_to(nearest) < MAZE_RADIUS: return false
	return true

func maze_exit_path() -> Array:
	var m: Dictionary = state.lantern_maze
	var start = Vector2i(floori(m.x / MAZE_CELL), floori(m.z / MAZE_CELL))
	var queue = [start]
	var parents = {start: start}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == MAZE_EXIT: break
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next: Vector2i = cell + direction
			if not maze_wall(next) and not parents.has(next):
				parents[next] = cell
				queue.append(next)
	if not parents.has(MAZE_EXIT): return []
	var path = [MAZE_EXIT]
	while path[0] != start: path.push_front(parents[path[0]])
	return path

func valid_lantern_maze(m) -> bool:
	if not m is Dictionary: return false
	for key in ["x", "z", "yaw", "echo_time"]:
		if not (m.get(key) is float or m.get(key) is int) or not is_finite(float(m[key])): return false
	if not m.get("phase") in ["explore", "echo", "recovered", "complete"]: return false
	if m.echo_time < 0 or m.echo_time > 7: return false
	if not maze_clear(Vector2(m.x, m.z)): return false
	if m.phase != "explore" and Vector2i(floori(m.x / MAZE_CELL), floori(m.z / MAZE_CELL)) != MAZE_EXIT: return false
	return true

func step_lantern_maze(forward: float, turn: float, delta: float) -> bool:
	if state.route != "ding_lamp": return false
	if not state.has("lantern_maze"): reset_lantern_maze()
	var m: Dictionary = state.lantern_maze
	if m.phase != "explore": return false
	var dt = clampf(delta, 0, 0.1)
	m.yaw = wrapf(m.yaw + clampf(turn, -1, 1) * dt * 1.35, -PI, PI)
	var displacement = Vector2(sin(m.yaw), -cos(m.yaw)) * clampf(forward, -1, 1) * 1.7 * dt
	var count = maxi(1, ceili(displacement.length() / 0.08))
	var before = Vector2(m.x, m.z)
	var p = before
	for i in range(count):
		var step = displacement / count
		if maze_clear(p + Vector2(step.x, 0)): p.x += step.x
		if maze_clear(p + Vector2(0, step.y)): p.y += step.y
	m.x = p.x
	m.z = p.y
	if Vector2i(floori(p.x / MAZE_CELL), floori(p.y / MAZE_CELL)) == MAZE_EXIT:
		m.phase = "echo"
		m.echo_time = 0.0
	return p.distance_to(before) > 0.001

func tick_lantern_echo(delta: float) -> void:
	if state.route != "ding_lamp" or not state.has("lantern_maze"): return
	var m: Dictionary = state.lantern_maze
	if m.phase != "echo": return
	m.echo_time = minf(7.0, m.echo_time + maxf(0, delta))
	if m.echo_time >= 7:
		m.phase = "recovered"
		event("LanternOilMemorySeen")

func finish_lantern_maze() -> bool:
	if state.route != "ding_lamp" or not state.has("lantern_maze") or state.lantern_maze.phase != "recovered": return false
	state.lantern_maze.phase = "complete"
	state.route = "ding_graph"
	return true

func new_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

func ensure_memory_identity() -> void:
	# Old saves acquire a stable identity without writing the source file on import.
	if not state.has("story_id"):
		state["story_id"] = JSON.stringify(state).sha256_text().substr(0, 32)
	if not state.has("branch_id"): state["branch_id"] = state.story_id
	if not state.has("parent_memory_id"): state["parent_memory_id"] = ""
	if not state.has("memory_markers"): state["memory_markers"] = []

func prepare_snapshot(data: Dictionary) -> Dictionary:
	if not valid_save(data): return {}
	var previous = state
	state = data.duplicate(true)
	normalize_loaded()
	ensure_memory_identity()
	var candidate = state
	state = previous
	return candidate if valid_save(candidate) else {}

func archive_current() -> bool:
	var stamp = new_id()
	for suffix in ["", ".bak"]:
		if FileAccess.file_exists(save_path + suffix):
			if DirAccess.copy_absolute(save_path + suffix, save_path + ".archive_" + stamp + suffix) != OK:
				save_error = "当前进度无法保留，尚未读取记忆。"
				return false
	return true

func restore_memory(candidate: Dictionary, memory_id: String) -> bool:
	var ready = prepare_snapshot(candidate)
	if ready.is_empty():
		save_error = "这卷记忆的进度无法恢复，当前故事未改动。"
		return false
	if not archive_current(): return false
	var previous = state
	var previous_blocked = write_blocked
	ready["branch_id"] = new_id()
	ready["parent_memory_id"] = memory_id
	state = ready
	write_blocked = false
	if save_game(): return true
	state = previous
	write_blocked = previous_blocked
	return false

func memory_checkpoint() -> String:
	if state.route == "credits" and state.finished: return "ending"
	if state.route in ["jade", "flip"] and state.jade.size() == 3: return "jade"
	if state.route == "fragment" and state.memory in state.completed: return "memory_" + state.memory
	if state.route == "hub" and state.prologue and state.completed.is_empty(): return "arrival"
	return ""

func new_story() -> bool:
	# Explicit UI confirmation precedes this. Preserve both old files, even corrupt ones.
	var stamp = str(Time.get_unix_time_from_system()).replace(".", "_")
	for suffix in ["", ".bak"]:
		if FileAccess.file_exists(save_path + suffix):
			var err = DirAccess.copy_absolute(save_path + suffix, save_path + ".archive_" + stamp + suffix)
			if err != OK:
				save_error = "旧进度未能归档，尚未开始新故事。"
				return false
	write_blocked = false
	reset_state()
	return save_game()

func valid_save(data: Dictionary) -> bool:
	if data.has("lantern_maze") and not valid_lantern_maze(data.lantern_maze): return false
	if data.get("schema") != 1:
		return false
	if not is_whole(data.get("script_revision", 1), 1, 2): return false
	for key in ["story_id", "branch_id", "parent_memory_id"]:
		if data.has(key) and (not data[key] is String or data[key].length() > 128): return false
	if data.has("memory_markers"):
		if not data.memory_markers is Array: return false
		for marker in data.memory_markers:
			if not marker is String: return false
	for key in ["completed", "events", "jade", "log"]:
		if not data.get(key) is Array:
			return false
	for key in ["dialogue", "shadow", "board"]:
		if not data.get(key) is Dictionary:
			return false
	for key in ["prologue", "inscription", "released", "finished"]:
		if not data.get(key) is bool:
			return false
	if not data.get("memory") in ["", "Ding", "Student", "Wife"]:
		return false
	if not is_whole(data.get("stumbles"), 0, 1000000):
		return false
	if not (data.get("lamp1") is float or data.get("lamp1") is int):
		return false
	if not is_finite(float(data.lamp1)) or data.lamp1 < 0 or data.lamp1 > 1:
		return false
	for item in data.events + data.log:
		if not item is String:
			return false
	if not data.shadow.get("node") is String or not is_whole(data.shadow.get("view"), -100, 100):
		return false
	if not (data.shadow.get("lamp") is float or data.shadow.get("lamp") is int) or not is_finite(float(data.shadow.lamp)):
		return false
	if not data.get("route", "") in ROUTES + ["wife_arrival", "ding_table", "release_echo", "finale"] or not is_whole(data.get("season"), 0, 3):
		return false
	var unique: Array = []
	for id in data.completed:
		if not id in MEMORY_IDS or id in unique:
			return false
		unique.append(id)
	var pieces: Array = []
	for id in data.jade:
		if not is_whole(id, 0, 2) or int(id) in pieces:
			return false
		pieces.append(int(id))
	if data.inscription and (pieces.size() != 3 or unique.size() != 3):
		return false
	if data.released and not data.inscription:
		return false
	if data.finished and not data.released:
		return false
	if data.route in ["jade", "flip", "accident_prompt", "accident", "body", "release", "dinner_call", "reply", "seat", "literacy", "credits"] and unique.size() != 3:
		return false
	if data.route in ["accident_prompt", "accident", "body", "release", "dinner_call", "reply", "seat", "literacy", "credits"] and not data.inscription:
		return false
	if data.route in ["dinner_call", "reply", "seat", "literacy", "credits", "release_echo", "finale"] and (not data.released or not data.inscription or unique.size() != 3):
		return false
	if data.route == "dialogue":
		var d: Dictionary = data.dialogue
		if not dialogue.has(d.get("id", "")) or not d.get("next", "") in ROUTES + ["wife_arrival", "ding_table", "release_echo", "finale"]:
			return false
		if not d.get("index") is float and not d.get("index") is int:
			return false
		var legacy_letter = data.get("script_revision", 1) == 1 and d.id == "WifeLetter" and d.index < 3
		if d.index < 0 or (d.index >= dialogue[d.id].lines.size() and not legacy_letter):
			return false
		if dialogue[d.id].requiresInscriptionSeen and not data.inscription:
			return false
	if not data.board.is_empty() and not valid_board(data.board):
		return false
	return true

func is_whole(value, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == int(value) and int(value) >= low and int(value) <= high

func normalize_loaded() -> void:
	if not state.has("lantern_maze"): reset_lantern_maze()
	# Migrate narrative checkpoints in memory only; never erase or reset a save.
	if state.get("script_revision", 1) < 2:
		if state.route == "dialogue" and state.dialogue.id == "WifeLetter":
			state.dialogue.index = 0
			state.dialogue.next = "letter_fold"
		if state.route == "dialogue" and state.dialogue.id == "WifeReflection":
			state.dialogue.next = "wife_shard"
		if state.route == "wife_shard" and not "WifeFarewellSeen" in state.events:
			state.route = "wife_reflection"
		if state.route == "dialogue" and state.dialogue.id in ["FinalDinner", "FinalLiteracy"]:
			state.route = "finale"
			state.dialogue = {}
		if state.route == "literacy": state.route = "finale"
		state["script_revision"] = 2
	# Older saves can stop after the farewell while the final shard remains unclaimed.
	# Only reconcile the completed farewell; never count an unfinished memory.
	if state.memory == "Wife" and state.route in ["wife_shard", "fragment"]:
		complete_memory("Wife")
	state.season = int(state.season)
	for i in range(state.jade.size()):
		state.jade[i] = int(state.jade[i])
	if not state.board.is_empty():
		state.board.undo_left = int(state.board.undo_left)
	if not state.shadow.get("node", "") in ["A", "B", "C", "D", "E", "F"]:
		state.shadow = {"node": "A", "view": 0, "lamp": 0.15}
	state.shadow.view = posmod(int(state.shadow.get("view", 0)), 4)
	state.shadow.lamp = clampf(float(state.shadow.get("lamp", 0.15)), 0, 1)
	if state.shadow.node == "D":
		state.shadow.view = 2
	ensure_memory_identity()

func load_game() -> bool:
	save_error = ""
	recovered_backup = false
	if not FileAccess.file_exists(save_path):
		return false
	var primary = read_json(save_path)
	if primary.has("schema") and (primary.schema != 1 or (is_whole(primary.get("script_revision", 1), 3, 1000000))):
		write_blocked = true
		save_error = "这是其他版本的存档。原文件已保留，请选择新故事另行归档。"
		return false
	if valid_save(primary):
		state = primary
		normalize_loaded()
		return true
	var backup = read_json(save_path + ".bak")
	if valid_save(backup):
		var preserved = save_path + ".damaged_" + str(Time.get_unix_time_from_system()).replace(".", "_")
		if DirAccess.copy_absolute(save_path, preserved) != OK:
			write_blocked = true
			save_error = "存档损坏，且无法保留损坏文件；原文件未更改。"
			return false
		state = backup
		normalize_loaded()
		recovered_backup = true
		save_error = "已从上一份备份恢复，损坏的原文件也已保留。"
		return true
	write_blocked = true
	save_error = "存档无法读取，原文件已保留。新故事会先将它归档。"
	return false

func save_game() -> bool:
	if write_blocked:
		return false
	ensure_memory_identity()
	state["updated_utc"] = Time.get_datetime_string_from_system(true)
	var tmp = save_path + ".tmp"
	var file = FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		save_error = "这一刻尚未记下，重试保存。"
		return false
	file.store_string(JSON.stringify(state, "\t"))
	file.close()
	if not valid_save(read_json(tmp)):
		save_error = "保存校验失败，旧存档未改动。"
		return false
	if FileAccess.file_exists(save_path) and valid_save(read_json(save_path)):
		if DirAccess.copy_absolute(save_path, save_path + ".bak") != OK:
			save_error = "无法创建备份，旧存档未改动。"
			return false
	if DirAccess.rename_absolute(tmp, save_path) != OK:
		save_error = "无法替换存档，旧存档与临时文件均已保留。"
		return false
	save_error = ""
	return true

func load_settings() -> void:
	var stored = read_json(settings_path)
	for key in settings:
		if stored.has(key) and typeof(stored[key]) == typeof(settings[key]):
			settings[key] = stored[key]
	settings.text_scale = clampf(settings.text_scale, 1.0, 1.3)
	settings.text_speed = clampf(settings.text_speed, 15.0, 100.0)
	settings.volume = clampf(settings.volume, 0.0, 1.0)

func save_settings() -> bool:
	var file = FileAccess.open(settings_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(settings))
	return true

func event(id: String) -> void:
	if not id.is_empty() and not id in state.events:
		state.events.append(id)
	# The farewell already places the jade in Ye's palm. Commit its progress at
	# that narrative boundary, before drawing the receipt screen or saving it.
	if id == "WifeFarewellSeen": complete_memory("Wife")

func complete_memory(id: String) -> bool:
	if not PREREQUISITES.has(id):
		return false
	for required in PREREQUISITES[id]:
		if not required in state.events:
			return false
	if not id in state.completed:
		state.completed.append(id)
	return true

func lamp_valid(u: float) -> bool:
	var p: Dictionary = config.lamp1
	return p.lengthBase + p.lengthSlope * u >= p.gapMeters - 0.00001 and maxf(0.0, u - p.heightStartsAt) * p.heightSlope <= p.maxHeightError + 0.00001

func shadow_edges(node: String, view: int, lamp: float) -> Array:
	var result: Array = []
	for edge in graph.edges:
		if int(edge.viewIndex) != view or not node in [edge.fromNode, edge.toNode]:
			continue
		if edge.requiresLamp and (lamp < edge.lampMin or lamp > edge.lampMax):
			continue
		if shadow_seam_error(edge, node, view, lamp) > float(graph.maxScreenErrorPixels):
			continue
		if shadow_seam_tangent_error(edge, node, view, lamp) > float(graph.maxTangentErrorDegrees):
			continue
		result.append(edge.toNode if edge.fromNode == node else edge.fromNode)
	return result

func shadow_position(id: String) -> Vector3:
	var xyz: Array = graph.spatial.positions[id]
	return Vector3(xyz[0], xyz[1], xyz[2])

func shadow_camera_position(node: String, angle: float) -> Vector3:
	return shadow_position(node) + Vector3(sin(angle) * graph.spatial.cameraRadius, graph.spatial.eyeHeight, cos(angle) * graph.spatial.cameraRadius)

func shadow_edge_points(edge: Dictionary, lamp: float = 0.52) -> Dictionary:
	# Two physically separate depths lie on one sightline at the designed viewpoint.
	# Their solid supports NEVER change with the camera or with the lamp.
	var angle = float(edge.viewIndex) * PI / 2
	var a = shadow_camera_position(edge.fromNode, angle)
	var b = shadow_camera_position(edge.toNode, angle)
	var axis = (b - a).normalized()
	var lateral = axis.cross(Vector3.UP).normalized()
	var near_end = a.lerp(b, 0.45)
	var far_end = a.lerp(b, 0.55)
	if edge.requiresLamp:
		var focal = 450.0 / tan(deg_to_rad(float(graph.spatial.fov)) / 2)
		near_end += lateral * (lamp - 0.52) * 100.0 * a.distance_to(near_end) / focal
	return {"a": near_end, "b": far_end, "lateral": lateral}

func shadow_camera_focus(node: String, view: int) -> Vector3:
	var selected: Dictionary = {}
	for edge in graph.edges:
		if not node in [edge.fromNode, edge.toNode]: continue
		if selected.is_empty() or edge.fromNode == node: selected = edge
		if int(edge.viewIndex) == view:
			selected = edge
			break
	var points = shadow_edge_points(selected)
	return (points.a + points.b) * 0.5 + Vector3(0, 0.35, 0)

func shadow_project(point: Vector3, node: String, view: int) -> Vector2:
	var eye = shadow_camera_position(node, float(view) * PI / 2)
	var forward = (shadow_camera_focus(node, view) - eye).normalized()
	var right = forward.cross(Vector3.UP).normalized()
	var up = right.cross(forward)
	var relative = point - eye
	var depth = relative.dot(forward)
	if depth <= 0.05: return Vector2(INF, INF)
	var focal = 450.0 / tan(deg_to_rad(float(graph.spatial.fov)) / 2)
	return Vector2(800 + relative.dot(right) * focal / depth, 450 - relative.dot(up) * focal / depth)

func shadow_seam_error(edge: Dictionary, node: String, view: int, lamp: float) -> float:
	var points = shadow_edge_points(edge, lamp)
	var a = shadow_project(points.a, node, view)
	var b = shadow_project(points.b, node, view)
	if not a.is_finite() or not b.is_finite(): return INF
	return a.distance_to(b)

func set_shadow_lamp(value: float) -> bool:
	if state.shadow.node != "E" or not is_finite(value): return false
	state.shadow.lamp = clampf(value, 0, 1)
	return true

func shadow_seam_tangent_error(edge: Dictionary, node: String, view: int, lamp: float) -> float:
	var p = shadow_edge_points(edge,lamp)
	var fixed = shadow_edge_points(edge)
	var a = shadow_project(p.a,node,view) - shadow_project(fixed.a-fixed.lateral*2.5,node,view)
	var b = shadow_project(fixed.b+fixed.lateral*2.5,node,view) - shadow_project(p.b,node,view)
	if not a.is_finite() or not b.is_finite() or a.length() < 0.01 or b.length() < 0.01: return INF
	return absf(rad_to_deg(a.angle_to(b)))

func rotate_shadow(direction: int) -> bool:
	if state.shadow.node in ["D", "F"]:
		return false
	state.shadow.view = posmod(int(state.shadow.view) + direction, 4)
	return true

func traverse_shadow(target: String) -> bool:
	var s: Dictionary = state.shadow
	if not target in shadow_edges(s.node, int(s.view), s.lamp):
		return false
	s.node = target
	return true

func new_board() -> void:
	state.board = {"table": cards.keys(), "tray": [], "reserve": [], "cleared": [], "history": [], "undo_left": 3, "reserve_used": false, "seen": []}
	var order = ["A", "B", "C", "D", "E", "F"]
	order.shuffle()
	state.board["layout_order"] = order
	state.board["layout_seed"] = randi_range(1, 1000000)
	for attempt in range(64):
		deal_board_types()
		var exposed: Dictionary = {}
		for pile in order:
			var kind: String = card_type(pile + "1")
			exposed[kind] = exposed.get(kind, 0) + 1
		if exposed.values().max() <= 2: break

func deal_board_types() -> void:
	# Interleave six piles, then deal overlapping pairs of triples along a legal
	# removal path. Every deal has a solution with at most four waiting cards;
	# the visible piles no longer share the same type at the same depth.
	var depths = [0, 0, 0, 0, 0, 0]
	var solution: Array = []
	for step in range(30):
		var available: Array = []
		for pile in range(6):
			if depths[pile] < 5: available.append(pile)
		var pile: int = available.pick_random()
		depths[pile] += 1
		solution.append(["A", "B", "C", "D", "E", "F"][pile] + str(depths[pile]))
	var kinds = ["Soldier", "InkArrow", "Brush", "Kite", "Inkstone"]
	kinds.shuffle()
	var dealt: Dictionary = {}
	var cursor = 0
	for pair in range(5):
		var a: String = kinds[pair]
		var b: String = kinds[(pair + 1) % 5]
		for kind in [a, b, a, b, a, b]:
			dealt[solution[cursor]] = kind
			cursor += 1
	for pile in state.board.layout_order:
		var id: String = pile + "6"
		dealt[id] = "Dragon"
		solution.append(id)
	state.board["types"] = dealt
	state.board["solution"] = solution

func card_type(id: String) -> String:
	return state.board.get("types", {}).get(id, cards[id].type)

func board_solution() -> Array:
	return state.board.get("solution", board_config.knownSolution)

func dragon_open() -> bool:
	var b: Dictionary = state.board
	for id in b.table + b.tray + b.reserve:
		if card_type(id) != "Dragon":
			return false
	return true

func can_pick(id: String) -> bool:
	var b: Dictionary = state.board
	if not id in b.table or b.tray.size() >= 7:
		return false
	for other in b.table:
		if id in cards[other].blocks:
			return false
	return not cards[id].requiresNonDragonCleared or dragon_open()

func board_snapshot() -> void:
	var b: Dictionary = state.board
	b.history.append({"table": b.table.duplicate(), "tray": b.tray.duplicate(), "reserve": b.reserve.duplicate(), "cleared": b.cleared.duplicate()})
	if b.history.size() > 3:
		b.history.pop_front()

func resolve_triples() -> void:
	var b: Dictionary = state.board
	for kind in ["Soldier", "InkArrow", "Brush", "Kite", "Inkstone", "Dragon"]:
		var group: Array = []
		for id in b.tray:
			if card_type(id) == kind:
				group.append(id)
		if group.size() >= 3:
			for id in group.slice(0, 3):
				b.tray.erase(id)
				b.cleared.append(id)
			if not kind in b.seen:
				b.seen.append(kind)

func pick(id: String) -> bool:
	if not can_pick(id):
		return false
	board_snapshot()
	state.board.table.erase(id)
	state.board.tray.append(id)
	resolve_triples()
	return true

func undo() -> bool:
	var b: Dictionary = state.board
	if b.undo_left <= 0 or b.history.is_empty():
		return false
	var snapshot: Dictionary = b.history.pop_back()
	for key in snapshot:
		b[key] = snapshot[key]
	b.undo_left -= 1
	return true

func reserve_cards() -> bool:
	var b: Dictionary = state.board
	if b.reserve_used or not b.reserve.is_empty() or b.tray.is_empty():
		return false
	board_snapshot()
	b.reserve_used = true
	for i in range(mini(3, b.tray.size())):
		b.reserve.append(b.tray.pop_front())
	return true

func return_card(id: String) -> bool:
	var b: Dictionary = state.board
	if not id in b.reserve or b.tray.size() >= 7:
		return false
	board_snapshot()
	b.reserve.erase(id)
	b.tray.append(id)
	resolve_triples()
	return true

func board_won() -> bool:
	var b: Dictionary = state.board
	return b.table.is_empty() and b.tray.is_empty() and b.reserve.is_empty() and b.cleared.size() == 36

func valid_board(b: Dictionary) -> bool:
	if b.has("types"):
		if not b.types is Dictionary or b.types.size() != 36: return false
		var counts: Dictionary = {}
		for id in cards:
			var kind = b.types.get(id, "")
			if kind not in ["Soldier", "InkArrow", "Brush", "Kite", "Inkstone", "Dragon"]: return false
			if (kind == "Dragon") != bool(cards[id].requiresNonDragonCleared): return false
			counts[kind] = counts.get(kind, 0) + 1
		if counts.size() != 6: return false
		for count in counts.values():
			if count != 6: return false
		if not b.get("solution") is Array or b.solution.size() != 36: return false
		for id in cards:
			if b.solution.count(id) != 1: return false
	if b.has("layout_order"):
		if not b.layout_order is Array or b.layout_order.size() != 6: return false
		for id in ["A", "B", "C", "D", "E", "F"]:
			if b.layout_order.count(id) != 1: return false
		if not is_whole(b.get("layout_seed"), 1, 1000000): return false
	for key in ["table", "tray", "reserve", "cleared", "history", "seen"]:
		if not b.get(key) is Array:
			return false
	if b.tray.size() > 7 or b.reserve.size() > 3 or not b.get("reserve_used") is bool:
		return false
	if not is_whole(b.get("undo_left"), 0, 3):
		return false
	if b.history.size() > 3:
		return false
	for snapshot in b.history:
		if not snapshot is Dictionary or not valid_inventory(snapshot):
			return false
	return valid_inventory(b)

func valid_inventory(b: Dictionary) -> bool:
	for key in ["table", "tray", "reserve", "cleared"]:
		if not b.get(key) is Array:
			return false
	if b.tray.size() > 7 or b.reserve.size() > 3:
		return false
	var all: Array = b.table + b.tray + b.reserve + b.cleared
	var unique: Dictionary = {}
	for id in all:
		if not cards.has(id) or unique.has(id):
			return false
		unique[id] = true
	return unique.size() == 36

func next_card_hint() -> String:
	# Prefer matching the current tray, then exposed triples; never automatically moves cards.
	var b: Dictionary = state.board
	for held in b.tray + b.reserve:
		for id in b.table:
			if can_pick(id) and card_type(id) == card_type(held):
				return id
	for id in board_solution():
		if can_pick(id):
			return id
	return ""

func place_jade(id: int) -> bool:
	if state.completed.size() != 3 or id not in [0, 1, 2]:
		return false
	if not id in state.jade:
		state.jade.append(id)
	return true

func flip_jade() -> bool:
	if state.completed.size() != 3 or state.jade.size() != 3:
		return false
	state.inscription = true
	return true

func release_report() -> bool:
	if not state.inscription or not "DeathAcknowledged" in state.events:
		return false
	state.released = true
	event("ReleasedReport")
	return true

func finish_game() -> bool:
	if not state.released or not "ReplyChosen" in state.events or not "SatDown" in state.events or not "FinalDinnerCompleted" in state.events:
		return false
	state.finished = true
	return true
