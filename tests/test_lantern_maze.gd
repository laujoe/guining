extends SceneTree
const Core = preload("res://scripts/game_core.gd")
var failures: Array = []
var checks = 0
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("FAIL MAZE: ", message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var c = Core.new()
	c.save_path = "res://.test-output/maze-rule-save.json"
	c.state.route = "ding_lamp"
	expect(not c.finish_lantern_maze(), "cannot skip exploration")
	var before = c.state.lantern_maze.duplicate()
	c.state.lantern_maze.yaw = 0
	for i in range(200): c.step_lantern_maze(1, 0, 0.1)
	expect(c.state.lantern_maze.z >= Core.MAZE_CELL + Core.MAZE_RADIUS - 0.001, "solid wall blocks walking")
	expect(c.maze_clear(Vector2(c.state.lantern_maze.x, c.state.lantern_maze.z)), "player never penetrates a wall")
	c.reset_lantern_maze()
	c.step_lantern_maze(1, 0, 1000)
	expect(abs(c.state.lantern_maze.x - before.x) < 0.18, "large delta cannot tunnel")
	c.reset_lantern_maze()
	# Discover the route from topology, then WALK it through production movement/collision.
	var start = Vector2i(1, 1)
	var queue: Array[Vector2i] = [start]
	var parents = {start: start}
	while not queue.is_empty():
		var cell = queue.pop_front()
		for dir in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var next: Vector2i = cell + dir
			if c.maze_wall(next) or parents.has(next): continue
			parents[next] = cell
			queue.append(next)
	expect(parents.has(Core.MAZE_EXIT), "exit is connected")
	var path: Array[Vector2i] = [Core.MAZE_EXIT]
	while path[0] != start: path.push_front(parents[path[0]])
	expect(path.size() > 15, "maze has multiple turns and meaningful exploration")
	for cell in path.slice(1):
		var target = (Vector2(cell) + Vector2(0.5, 0.5)) * Core.MAZE_CELL
		for step in range(250):
			var m: Dictionary = c.state.lantern_maze
			var offset = target - Vector2(m.x, m.z)
			if offset.length() < 0.04 or m.phase != "explore": break
			m.yaw = atan2(offset.x, -offset.y)
			c.step_lantern_maze(1, 0, minf(1.0 / 60, offset.length() / 1.7))
			expect(c.maze_clear(Vector2(m.x, m.z)), "walked path remains collision free")
	expect(c.state.lantern_maze.phase == "echo", "crossing exit triggers memory")
	var exit_state = c.state.lantern_maze.duplicate()
	c.step_lantern_maze(-1, 1, 0.1)
	expect(c.state.lantern_maze == exit_state, "memory locks movement")
	c.tick_lantern_echo(3)
	expect(not c.finish_lantern_maze(), "cannot skip unfinished memory")
	expect(c.save_game(), "mid-memory snapshot saves")
	var loaded = Core.new()
	loaded.save_path = c.save_path
	expect(loaded.load_game() and loaded.state.lantern_maze.echo_time == 3, "mid-memory resumes exact time")
	c.tick_lantern_echo(4)
	expect(c.state.lantern_maze.phase == "recovered", "memory fades back to first person")
	expect(c.finish_lantern_maze() and c.state.route == "ding_graph", "next stage unlocked after recovery")
	expect(not c.finish_lantern_maze(), "completion is one shot")
	var legacy = Core.new().state.duplicate(true)
	legacy.erase("lantern_maze")
	expect(c.valid_save(legacy), "old schema 1 saves remain accepted")
	var migrated = c.prepare_snapshot(legacy)
	expect(migrated.has("lantern_maze"), "old saves receive maze without changing other progress")
	var bad = migrated.duplicate(true)
	bad.lantern_maze.x = NAN
	expect(not c.valid_save(bad), "invalid maze position rejected")
	bad = migrated.duplicate(true)
	bad.lantern_maze.x = 0
	expect(not c.valid_save(bad), "wall position rejected")
	print("MAZE: ", checks, " checks; ", failures.size(), " failures; route cells ", path.size())
	quit(0 if failures.is_empty() else 1)
